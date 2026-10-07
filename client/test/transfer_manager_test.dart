import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phone_vault_client/phone_vault_client.dart';
import 'package:phone_vault_client/sync_policy.dart';
import 'package:phone_vault_client/transfer_manager.dart';
import 'package:phone_vault_client/transfer_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('manager persists an enqueued file task', () async {
    final file = File('${Directory.systemTemp.path}/phone-vault-test.bin');
    await file.writeAsBytes(List<int>.filled(16, 7));
    try {
      final manager = TransferManager(
        client: PhoneVaultClient('http://127.0.0.1:1'),
      );
      await manager.enqueueFile(
        file: file,
        sha256: 'a' * 64,
      );

      final restored = await manager.persistence.load();
      expect(restored, hasLength(1));
      expect(restored.single.sourcePath, file.path);
      expect(restored.single.size, 16);
    } finally {
      await file.delete();
    }
  });

  test('blocked policy does not start queued work', () async {
    final manager = TransferManager(
      client: PhoneVaultClient('http://127.0.0.1:1'),
      policy: const SyncPolicy(automatic: true),
    );

    final result = await manager.runNext(const SyncContext(
      trustedServer: false,
      network: SyncNetwork.wifi,
      batteryPercent: 100,
      charging: true,
    ));

    expect(result, isNull);
    expect(manager.queue.items, isEmpty);
  });

  test('restore converts interrupted running task to queued', () async {
    final manager = TransferManager(
      client: PhoneVaultClient('http://127.0.0.1:1'),
    );
    final task = TransferTask(
      id: 'resume',
      sourcePath: 'missing',
      filename: 'missing',
      size: 0,
      sha256: 'b' * 64,
      state: TransferState.running,
      attempt: 1,
    );
    await manager.persistence.save([task]);

    await manager.restore();

    expect(manager.queue.items.single.state, TransferState.queued);
    expect(manager.queue.items.single.attempt, 1);
  });
}
