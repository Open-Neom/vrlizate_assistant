import 'dart:async';
import 'dart:typed_data';

import '../../utils/constants/vr_assistant_constants.dart';
import '../../utils/constants/vr_assistant_translation_constants.dart';
import '../models/vr_assistant_capture_lease.dart';

/// Holds exactly one local image source and one real capture operation.
///
/// The most recently registered surface wins. There is intentionally no stack
/// fallback: closing an account/dialog route cannot reveal a stale source.
/// No network server, external screenshot API or periodic capture is started.
class VrAssistantCaptureController {
  VrAssistantCaptureController({
    this.timeout = VrAssistantConstants.defaultCaptureTimeout,
  }) {
    if (timeout <= Duration.zero) {
      throw ArgumentError(
        VrAssistantTranslationConstants.argErrorPositiveCaptureTimeout,
      );
    }
  }

  final Duration timeout;
  VrAssistantCapture? _source;
  VrAssistantCaptureLease? _lease;
  ({int revision, Completer<Uint8List?> result, Timer timer})? _operation;
  int _revision = 0;
  bool _disposed = false;

  bool get hasSource => !_disposed && _source != null;
  bool get busy => _operation != null;

  VrAssistantCaptureLease registerSource(VrAssistantCapture source) {
    final lease = VrAssistantCaptureLease();
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
    operation?.timer.cancel();
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
    final completer = Completer<Uint8List?>();
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete();
    });
    final operation = (revision: _revision, result: completer, timer: timer);
    _operation = operation;
    unawaited(_read(operation, source));
    return operation.result.future;
  }

  Future<void> _read(
    ({int revision, Completer<Uint8List?> result, Timer timer}) operation,
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
      operation.timer.cancel();
      if (!operation.result.isCompleted) operation.result.complete();
      if (identical(_operation?.result, operation.result)) {
        _operation = null;
      }
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
