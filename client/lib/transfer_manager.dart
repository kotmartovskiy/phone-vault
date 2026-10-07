import 'dart:io';

import 'persistent_transfer_queue.dart';
import 'phone_vault_client.dart';
import 'sync_policy.dart';
import 'transfer_queue.dart';

class SyncContext {
  final bool trustedServer;
  final SyncNetwork network;
  final int batteryPercent;
  final bool charging;

  const SyncContext({
    required this.trustedServer,
    required this.network,
    required this.batteryPercent,
    required this.charging,
  });
}

class TransferManager {
  final PhoneVaultClient client;
  final TransferQueue queue;
  final TransferQueuePersistence persistence;
  final SyncPolicy policy;

  TransferManager({
    required this.client,
    TransferQueue? queue,
    TransferQueuePersistence? persistence,
    this.policy = const SyncPolicy(),
  })  : queue = queue ?? TransferQueue(),
        persistence = persistence ?? const TransferQueuePersistence();

  Future<void> restore() async {
    final tasks = await persistence.load();
    for (final task in tasks) {
      queue.enqueue(task);
    }
  }

  Future<void> enqueueFile({
    required File file,
    required String sha256,
    String? filename,
  }) async {
    final size = await file.length();
    queue.enqueue(TransferTask(
      id: '${sha256}_${size}',
      sourcePath: file.path,
      filename: filename ?? file.uri.pathSegments.last,
      size: size,
      sha256: sha256,
    ));
    await _save();
  }

  Future<TransferTask?> runNext(SyncContext context) async {
    if (!policy.canTransfer(
      trustedServer: context.trustedServer,
      network: context.network,
      batteryPercent: context.batteryPercent,
      charging: context.charging,
    )) {
      return null;
    }

    final task = queue.nextReady();
    if (task == null) return null;
    await _save();

    try {
      final file = File(task.sourcePath);
      if (!await file.exists()) {
        queue.fail(task.id, 'Source file no longer exists', retryable: false);
      } else {
        final exists =
            await client.hasStoredFile(sha256: task.sha256, size: task.size);
        if (exists) {
          queue.skip(task.id);
        } else {
          if (client.deviceId == null) {
            throw StateError('Client is not paired');
          }
          await client.uploadFile(
            deviceId: client.deviceId!,
            file: file,
            sha256: task.sha256,
          );
          queue.complete(task.id);
        }
      }
    } catch (error) {
      queue.fail(task.id, error);
    }

    await _save();
    return queue.items.firstWhere((item) => item.id == task.id);
  }

  Future<void> removeFinished() async {
    queue.removeFinished();
    await _save();
  }

  Future<void> _save() => persistence.save(queue.items);
}
