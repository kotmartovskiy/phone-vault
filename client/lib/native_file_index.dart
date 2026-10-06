import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class PhoneFile {
  final String path, name, category, folderLabel, mime;
  final int size;
  final DateTime modified;
  const PhoneFile({required this.path, required this.name, required this.category, required this.folderLabel, required this.mime, required this.size, required this.modified});
  String get humanSize {
    if (size < 1024) return size.toString() + ' B';
    if (size < 1024 * 1024) return (size / 1024).toStringAsFixed(1) + ' KB';
    if (size < 1024 * 1024 * 1024) return (size / (1024 * 1024)).toStringAsFixed(1) + ' MB';
    return (size / (1024 * 1024 * 1024)).toStringAsFixed(2) + ' GB';
  }
  IconData get icon {
    switch (category) {
      case 'Images': return Icons.image_outlined;
      case 'Video': return Icons.video_file_outlined;
      case 'Audio': return Icons.audio_file_outlined;
      case 'Archives': return Icons.archive_outlined;
      case 'Documents': return Icons.description_outlined;
      default: return Icons.insert_drive_file_outlined;
    }
  }
}

class NativeFileIndex {
  static const _channel = MethodChannel('phone_vault/file_index');
  static Future<bool> requestPermission() async => (await _channel.invokeMethod<bool>('requestPermission')) ?? false;
  static Future<List<PhoneFile>> listFiles() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('listFiles') ?? const [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return PhoneFile(
        path: m['path'] as String,
        name: m['name'] as String,
        category: m['category'] as String,
        folderLabel: m['folder'] as String,
        mime: m['mime'] as String? ?? '',
        size: (m['size'] as num).toInt(),
        modified: DateTime.fromMillisecondsSinceEpoch((m['modified'] as num).toInt()),
      );
    }).toList();
  }
}
