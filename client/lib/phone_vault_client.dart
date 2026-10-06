import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class UploadInfo {
  final String uploadId;
  final int chunkSize;
  final int receivedBytes;
  final int size;
  final String status;
  const UploadInfo({required this.uploadId, required this.chunkSize, required this.receivedBytes, required this.size, required this.status});
  factory UploadInfo.fromJson(Map<String, dynamic> json) => UploadInfo(
    uploadId: json['upload_id'] as String,
    chunkSize: (json['chunk_size'] as num?)?.toInt() ?? 4 * 1024 * 1024,
    receivedBytes: (json['received_bytes'] as num?)?.toInt() ?? 0,
    size: (json['size'] as num?)?.toInt() ?? 0,
    status: json['status'] as String,
  );
}

class PhoneVaultClient {
  final Uri baseUri;
  final http.Client _http;
  PhoneVaultClient(String baseUrl, {http.Client? client})
      : baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
        _http = client ?? http.Client();

  Uri _uri(String path) => baseUri.resolve(path);

  Future<bool> health() async {
    final response = await _http.get(_uri('api/v1/health'));
    return response.statusCode == 200 && jsonDecode(response.body)['status'] == 'ok';
  }

  Future<String> pair(String deviceName) async {
    final response = await _http.post(_uri('api/v1/devices/pair'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'name': deviceName}));
    _expect(response, 200);
    return jsonDecode(response.body)['device_id'] as String;
  }

  Future<UploadInfo> createUpload({required String deviceId, required String filename, required int size, String sourcePath = '', String? sha256, String? mimeType}) async {
    final body = <String, dynamic>{'device_id': deviceId, 'filename': filename, 'source_path': sourcePath, 'size': size, if (sha256 != null) 'sha256': sha256, if (mimeType != null) 'mime_type': mimeType};
    final response = await _http.post(_uri('api/v1/uploads'), headers: {'content-type': 'application/json'}, body: jsonEncode(body));
    _expect(response, 200);
    return UploadInfo.fromJson(jsonDecode(response.body));
  }

  Future<UploadInfo> status(String uploadId) async {
    final response = await _http.get(_uri('api/v1/uploads/$uploadId'));
    _expect(response, 200);
    return UploadInfo.fromJson(jsonDecode(response.body));
  }

  Future<UploadInfo> uploadChunk({required String uploadId, required int chunkNumber, required int offset, required List<int> bytes}) async {
    final response = await _http.put(_uri('api/v1/uploads/$uploadId/chunks/$chunkNumber'), headers: {'X-Upload-Offset': offset.toString()}, body: bytes);
    if (response.statusCode == 409) {
      throw UploadOffsetException(offset: (jsonDecode(response.body)['received_bytes'] as num).toInt());
    }
    _expect(response, 200);
    return UploadInfo.fromJson(jsonDecode(response.body));
  }

  Future<String> complete(String uploadId) async {
    final response = await _http.post(_uri('api/v1/uploads/$uploadId/complete'));
    _expect(response, 200);
    return jsonDecode(response.body)['file_id'] as String;
  }

  Future<String> uploadFile({required String deviceId, required File file, String? mimeType, String? sha256, void Function(int sent, int total)? onProgress}) async {
    final length = await file.length();
    final info = await createUpload(deviceId: deviceId, filename: file.uri.pathSegments.last, sourcePath: file.path, size: length, sha256: sha256, mimeType: mimeType);
    var offset = info.receivedBytes;
    var chunkNumber = offset ~/ info.chunkSize;
    final handle = await file.open();
    try {
      while (offset < length) {
        await handle.setPosition(offset);
        final count = (length - offset) < info.chunkSize ? (length - offset) : info.chunkSize;
        final bytes = await handle.read(count);
        if (bytes.isEmpty) throw StateError('Unexpected EOF at offset $offset');
        try {
          final next = await uploadChunk(uploadId: info.uploadId, chunkNumber: chunkNumber, offset: offset, bytes: bytes);
          offset = next.receivedBytes;
        } on UploadOffsetException catch (e) {
          offset = e.offset;
        }
        onProgress?.call(offset, length);
        chunkNumber = offset ~/ info.chunkSize;
      }
    } finally {
      await handle.close();
    }
    return complete(info.uploadId);
  }

  void close() => _http.close();

  static void _expect(http.Response response, int expected) {
    if (response.statusCode != expected) {
      throw HttpException('Phone Vault HTTP ${response.statusCode}: ${response.body}', uri: response.request?.url);
    }
  }
}

class UploadOffsetException implements Exception {
  final int offset;
  const UploadOffsetException({required this.offset});
}
