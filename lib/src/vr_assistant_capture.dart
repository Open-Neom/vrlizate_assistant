import 'dart:async';
import 'dart:typed_data';

typedef VrAssistantCapture = Future<Uint8List?> Function();

/// An opaque lease prevents an older route from clearing a newer surface.
class VrAssistantCaptureLease {
  VrAssistantCaptureLease._();
}

/// Holds exactly one local image source and one real capture operation.
///
/// The most recently registered surface wins. There is intentionally no stack
/// fallback: closing an account/dialog route cannot reveal a stale source.
/// No network server, external screenshot API or periodic capture is started.
class VrAssistantCaptureController {
  VrAssistantCaptureController({this.timeout = const Duration(seconds: 3)}) {
    if (timeout <= Duration.zero) {
      throw ArgumentError('Capture timeout must be positive.');
    }
  }

  final Duration timeout;
  VrAssistantCapture? _source;
  VrAssistantCaptureLease? _lease;
  _CaptureOperation? _operation;
  int _revision = 0;
  bool _disposed = false;

  bool get hasSource => !_disposed && _source != null;
  bool get busy => _operation != null;

  VrAssistantCaptureLease registerSource(VrAssistantCapture source) {
    final lease = VrAssistantCaptureLease._();
    if (_disposed) return lease;
    _invalidate();
    _lease = lease;
    _source = source;
    return lease;
  }

  void unregisterSource(VrAssistantCaptureLease lease) {
    if (!identical(lease, _lease)) return;
    _invalidate();
    _lease = null;
    _source = null;
  }

  void _invalidate() {
    _revision++;
    final operation = _operation;
    operation?.timer?.cancel();
    if (operation != null && !operation.result.isCompleted) {
      operation.result.complete();
    }
  }

  /// Null means unavailable, overlapping, expired or invalidated capture.
  Future<Uint8List?> capture() {
    final source = _source;
    if (_disposed || source == null || _operation != null) {
      return Future.value();
    }
    final operation = _CaptureOperation(_revision);
    _operation = operation;
    operation.timer = Timer(timeout, () {
      if (!operation.result.isCompleted) operation.result.complete();
    });
    unawaited(_read(operation, source));
    return operation.result.future;
  }

  Future<void> _read(
    _CaptureOperation operation,
    VrAssistantCapture source,
  ) async {
    try {
      final bytes = await source();
      if (!_disposed &&
          operation.revision == _revision &&
          !operation.result.isCompleted) {
        operation.result.complete(bytes);
      }
    } catch (_) {
      if (!operation.result.isCompleted) operation.result.complete();
    } finally {
      operation.timer?.cancel();
      if (!operation.result.isCompleted) operation.result.complete();
      if (identical(_operation, operation)) _operation = null;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _invalidate();
    _source = null;
    _lease = null;
  }
}

class _CaptureOperation {
  _CaptureOperation(this.revision);
  final int revision;
  final result = Completer<Uint8List?>();
  Timer? timer;
}
