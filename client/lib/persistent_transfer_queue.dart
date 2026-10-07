import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'transfer_queue.dart';

class TransferQueuePersistence {
  static const _key = 'phone_vault.transfer_queue.v1';

  const TransferQueuePersistence();

  Future<List<TransferTask>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => _decode(Map<String, dynamic>.from(item)))
          .map((task) => task.state == TransferState.running
              ? task.copyWith(state: TransferState.queued)
              : task)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(Iterable<TransferTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = tasks.map(_encode).toList(growable: false);
    await prefs.setString(_key, jsonEncode(encoded));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Map<String, dynamic> _encode(TransferTask task) => {
        'id': task.id,
        'sourcePath': task.sourcePath,
        'filename': task.filename,
        'size': task.size,
        'sha256': task.sha256,
        'attempt': task.attempt,
        'state': task.state.name,
        'nextAttemptAt': task.nextAttemptAt?.toIso8601String(),
        'error': task.error,
      };

  static TransferTask _decode(Map<String, dynamic> value) {
    final stateName = value['state'] as String? ?? 'queued';
    final state = TransferState.values.firstWhere(
      (item) => item.name == stateName,
      orElse: () => TransferState.queued,
    );
    final nextRaw = value['nextAttemptAt'] as String?;
    return TransferTask(
      id: value['id'] as String,
      sourcePath: value['sourcePath'] as String,
      filename: value['filename'] as String,
      size: (value['size'] as num).toInt(),
      sha256: value['sha256'] as String,
      attempt: (value['attempt'] as num?)?.toInt() ?? 0,
      state: state,
      nextAttemptAt:
          nextRaw == null ? null : DateTime.tryParse(nextRaw),
      error: value['error'] as String?,
    );
  }
}
