import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phone_vault_client/persistent_transfer_queue.dart';
import 'package:phone_vault_client/transfer_queue.dart';

TransferTask task(
  String id, {
  TransferState state = TransferState.queued,
  int attempt = 0,
}) =>
    TransferTask(
      id: id,
      sourcePath: 'DCIM/$id.jpg',
      filename: '$id.jpg',
      size: 10,
      sha256: id.padRight(64, '0'),
      state: state,
      attempt: attempt,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persistence round-trips queue metadata', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final store = const TransferQueuePersistence();
    final original = task('a', attempt: 2).copyWith(
      nextAttemptAt: DateTime(2026, 1, 1, 12),
      error: 'network',
    );

    await store.save([original]);
    final restored = await store.load();

    expect(restored, hasLength(1));
    expect(restored.single.id, 'a');
    expect(restored.single.attempt, 2);
    expect(restored.single.nextAttemptAt, DateTime(2026, 1, 1, 12));
    expect(restored.single.error, 'network');
  });

  test('running tasks are recovered as queued after restart', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final store = const TransferQueuePersistence();
    await store.save([task('a', state: TransferState.running, attempt: 1)]);

    final restored = await store.load();

    expect(restored.single.state, TransferState.queued);
    expect(restored.single.attempt, 1);
  });

  test('corrupt persisted data is ignored safely', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'phone_vault.transfer_queue.v1',
      '{not-json',
    );

    final restored = await const TransferQueuePersistence().load();
    expect(restored, isEmpty);
  });
}
