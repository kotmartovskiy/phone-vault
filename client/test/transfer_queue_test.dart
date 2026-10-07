import 'package:flutter_test/flutter_test.dart';
import 'package:phone_vault_client/transfer_queue.dart';

TransferTask task(String id) => TransferTask(
      id: id,
      sourcePath: 'DCIM/$id.jpg',
      filename: '$id.jpg',
      size: 10,
      sha256: id.padRight(64, '0'),
    );

void main() {
  test('queue preserves FIFO order and marks task running', () {
    final queue = TransferQueue();
    queue
      ..enqueue(task('a'))
      ..enqueue(task('b'));

    final first = queue.nextReady(DateTime(2026, 1, 1));
    expect(first?.id, 'a');
    expect(first?.state, TransferState.running);

    final second = queue.nextReady(DateTime(2026, 1, 1));
    expect(second?.id, 'b');
  });

  test('retry uses exponential backoff and eventually fails', () {
    final queue = TransferQueue();
    queue.enqueue(task('a'));
    final start = DateTime(2026, 1, 1);
    final running = queue.nextReady(start)!;

    queue.fail(running.id, 'network', now: start);
    expect(queue.items.single.state, TransferState.queued);
    expect(queue.items.single.nextAttemptAt, start.add(const Duration(seconds: 2)));

    final retry = queue.nextReady(start.add(const Duration(seconds: 2)))!;
    queue.fail(retry.id, 'network', maxAttempts: 2, now: start);

    expect(queue.items.single.state, TransferState.failed);
  });

  test('non-retryable failure stays failed', () {
    final queue = TransferQueue();
    queue.enqueue(task('a'));
    final running = queue.nextReady()!;
    queue.fail(running.id, 'bad hash', retryable: false);
    expect(queue.items.single.state, TransferState.failed);
    expect(queue.items.single.error, 'bad hash');
  });

  test('finished tasks can be removed without touching queued work', () {
    final queue = TransferQueue();
    queue
      ..enqueue(task('a'))
      ..enqueue(task('b'));
    final first = queue.nextReady()!;
    queue.complete(first.id);
    queue.removeFinished();

    expect(queue.items.map((item) => item.id), ['b']);
  });
}
