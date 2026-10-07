enum TransferState { queued, running, completed, skipped, failed, cancelled }

class TransferTask {
  final String id;
  final String sourcePath;
  final String filename;
  final int size;
  final String sha256;
  final int attempt;
  final TransferState state;
  final DateTime? nextAttemptAt;
  final String? error;

  const TransferTask({
    required this.id,
    required this.sourcePath,
    required this.filename,
    required this.size,
    required this.sha256,
    this.attempt = 0,
    this.state = TransferState.queued,
    this.nextAttemptAt,
    this.error,
  });

  TransferTask copyWith({
    int? attempt,
    TransferState? state,
    DateTime? nextAttemptAt,
    String? error,
    bool clearNextAttempt = false,
    bool clearError = false,
  }) =>
      TransferTask(
        id: id,
        sourcePath: sourcePath,
        filename: filename,
        size: size,
        sha256: sha256,
        attempt: attempt ?? this.attempt,
        state: state ?? this.state,
        nextAttemptAt:
            clearNextAttempt ? null : (nextAttemptAt ?? this.nextAttemptAt),
        error: clearError ? null : (error ?? this.error),
      );
}

class TransferQueue {
  final List<TransferTask> _items = [];

  List<TransferTask> get items => List.unmodifiable(_items);

  void enqueue(TransferTask task) {
    if (_items.any((item) => item.id == task.id)) return;
    _items.add(task);
  }

  TransferTask? nextReady([DateTime? now]) {
    final current = now ?? DateTime.now();
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.state == TransferState.queued &&
          (item.nextAttemptAt == null ||
              !item.nextAttemptAt!.isAfter(current))) {
        final running = item.copyWith(
          state: TransferState.running,
          attempt: item.attempt + 1,
          clearNextAttempt: true,
          clearError: true,
        );
        _items[i] = running;
        return running;
      }
    }
    return null;
  }

  void complete(String id) => _replace(
      id, (task) => task.copyWith(state: TransferState.completed));

  void skip(String id) =>
      _replace(id, (task) => task.copyWith(state: TransferState.skipped));

  void cancel(String id) =>
      _replace(id, (task) => task.copyWith(state: TransferState.cancelled));

  void fail(String id, Object error,
      {bool retryable = true,
      int maxAttempts = 5,
      DateTime? now}) {
    _replace(id, (task) {
      if (!retryable || task.attempt >= maxAttempts) {
        return task.copyWith(
            state: TransferState.failed, error: error.toString());
      }
      final exponent = (task.attempt - 1).clamp(0, 5).toInt();
      final base = 2 << exponent;
      final delay = Duration(seconds: base > 60 ? 60 : base);
      return task.copyWith(
        state: TransferState.queued,
        nextAttemptAt: (now ?? DateTime.now()).add(delay),
        error: error.toString(),
      );
    });
  }

  void removeFinished() {
    _items.removeWhere((task) =>
        task.state == TransferState.completed ||
        task.state == TransferState.skipped ||
        task.state == TransferState.cancelled);
  }

  void _replace(String id, TransferTask Function(TransferTask) update) {
    final index = _items.indexWhere((task) => task.id == id);
    if (index >= 0) _items[index] = update(_items[index]);
  }
}
