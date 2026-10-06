import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class PairInfo{
  final String deviceId;
  final String token;
  const PairInfo({required this.deviceId,required this.token});
}

class UploadInfo{
  final String uploadId;
  final int chunkSize;
  final int receivedBytes;
  final int size;
  final String status;
  const UploadInfo({required this.uploadId,required this.chunkSize,required this.receivedBytes,required this.size,required this.status});
  factory UploadInfo.fromJson(Map<String,dynamic> json)=>UploadInfo(
    uploadId:json['upload_id'] as String,
    chunkSize:(json['chunk_size'] as num?)?.toInt()??4*1024*1024,
    receivedBytes:(json['received_bytes'] as num?)?.toInt()??0,
    size:(json['size'] as num?)?.toInt()??0,
    status:json['status'] as String);
}

class PhoneVaultClient{
  final Uri baseUri;
  final http.Client _http;
  String? token;
  PhoneVaultClient(String baseUrl,{http.Client? client,this.token}):baseUri=Uri.parse(baseUrl.endsWith('/')?baseUrl:'$baseUrl/'),_http=client??http.Client();
  Uri _uri(String path)=>baseUri.resolve(path);
  Map<String,String> _headers([Map<String,String>? extra])=>{if(token!=null)'authorization':'Bearer $token',...?extra};

  Future<bool> health()async{
    final response=await _http.get(_uri('api/v1/health'));
    return response.statusCode==200&&jsonDecode(response.body)['status']=='ok';
  }

  Future<PairInfo> pair(String deviceName)async{
    final response=await _http.post(_uri('api/v1/devices/pair'),headers:{'content-type':'application/json'},body:jsonEncode({'name':deviceName}));
    _expect(response,200);
    final j=jsonDecode(response.body);
    return PairInfo(deviceId:j['device_id'] as String,token:j['token'] as String);
  }

  Future<UploadInfo> resumeOrCreateUpload({required String deviceId,required String filename,required int size,String sourcePath='',required String sha256,String? mimeType})async{
    final body=<String,dynamic>{'device_id':deviceId,'filename':filename,'source_path':sourcePath,'size':size,'sha256':sha256,if(mimeType!=null)'mime_type':mimeType};
    final response=await _http.post(_uri('api/v1/uploads/resume'),headers:_headers({'content-type':'application/json'}),body:jsonEncode(body));
    _expect(response,200);
    return UploadInfo.fromJson(jsonDecode(response.body));
  }

  Future<UploadInfo> uploadChunk({required String uploadId,required int chunkNumber,required int offset,required List<int> bytes})async{
    for(var attempt=0;attempt<3;attempt++){
      try{
        final response=await _http.put(_uri('api/v1/uploads/$uploadId/chunks/$chunkNumber'),headers:_headers({'X-Upload-Offset':offset.toString()}),body:bytes);
        if(response.statusCode==409)throw UploadOffsetException(offset:(jsonDecode(response.body)['received_bytes'] as num).toInt());
        _expect(response,200);
        return UploadInfo.fromJson(jsonDecode(response.body));
      }catch(e){
        if(e is UploadOffsetException||attempt==2)rethrow;
        await Future<void>.delayed(Duration(milliseconds:500*(attempt+1)));
      }
    }
    throw StateError('unreachable');
  }

  Future<String> complete(String uploadId)async{
    final response=await _http.post(_uri('api/v1/uploads/$uploadId/complete'),headers:_headers());
    _expect(response,200);
    return jsonDecode(response.body)['file_id'] as String;
  }

  Future<String> uploadFile({required String deviceId,required File file,required String sha256,String? mimeType,void Function(int sent,int total)? onProgress,bool Function()? isCancelled})async{
    final length=await file.length();
    final info=await resumeOrCreateUpload(deviceId:deviceId,filename:file.uri.pathSegments.last,sourcePath:file.path,size:length,sha256:sha256,mimeType:mimeType);
    var offset=info.receivedBytes;
    if(offset>length)throw StateError('Server offset exceeds local file size');
    var chunkNumber=offset~/info.chunkSize;
    final handle=await file.open();
    try{
      while(offset<length){
        if(isCancelled?.call()??false)return info.uploadId;
        await handle.setPosition(offset);
        final count=(length-offset)<info.chunkSize?(length-offset):info.chunkSize;
        final bytes=await handle.read(count);
        if(bytes.isEmpty)throw StateError('Unexpected EOF at offset $offset');
        try{
          final next=await uploadChunk(uploadId:info.uploadId,chunkNumber:chunkNumber,offset:offset,bytes:bytes);
          offset=next.receivedBytes;
        }on UploadOffsetException catch(e){
          offset=e.offset;
        }
        onProgress?.call(offset,length);
        chunkNumber=offset~/info.chunkSize;
        if(isCancelled?.call()??false)return info.uploadId;
      }
    }finally{await handle.close();}
    return complete(info.uploadId);
  }

  void close()=>_http.close();
  static void _expect(http.Response response,int expected){
    if(response.statusCode!=expected)throw HttpException('Phone Vault HTTP ${response.statusCode}: ${response.body}',uri:response.request?.url);
  }
}

class UploadOffsetException implements Exception{
  final int offset;
  const UploadOffsetException({required this.offset});
}
