import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../utils/constants/vr_assistant_constants.dart';
import '../../utils/constants/vr_assistant_translation_constants.dart';
import '../../utils/enums/vr_assistant_state.dart';
import '../models/vr_assistant_context.dart';
import '../models/vr_assistant_reply.dart';
import '../models/vr_assistant_request.dart';
import 'vr_assistant_provider.dart';
import 'vr_assistant_tool_registry.dart';

/// Owns one provider and bounds assistance outside the rendering frame loop.
///
/// A timeout or [cancel] invalidates the result immediately. Because the
/// provider interface cannot forcibly stop native work or network I/O, [busy]
/// remains true until that real operation finishes; a second allocation/request
/// is never started in the meantime. Dispose this controller with its host.
class VrAssistantController extends ChangeNotifier {
  VrAssistantController({
    required VrAssistantProvider provider,
    this.toolRegistry,
    this.requestTimeout = VrAssistantConstants.defaultRequestTimeout,
    this.captureTimeout = VrAssistantConstants.defaultCaptureTimeout,
  }) : _provider = provider {
    if (requestTimeout <= Duration.zero || captureTimeout <= Duration.zero) {
      throw ArgumentError(
        VrAssistantTranslationConstants.argErrorPositiveTimeouts,
      );
    }
  }

  static const int maxPromptCharacters =
      VrAssistantConstants.maxPromptCharacters;
  static const int maxPromptBytes = VrAssistantConstants.maxPromptBytes;
  static const int maxImageBytes = VrAssistantConstants.maxImageBytes;

  final VrAssistantProvider _provider;
  final VrAssistantToolRegistry? toolRegistry;
  final Duration requestTimeout;
  final Duration captureTimeout;

  ({int generation, Completer<VrAssistantReply?> result})? _operation;
  Timer? _operationTimer;
  int _generation = 0;
  bool _disposed = false;
  String _status = VrAssistantTranslationConstants.statusReady;
  VrAssistantState _state = VrAssistantState.idle;
  VrAssistantReply? _lastReply;

  bool get busy => _operation != null;
  String get status => _status;
  VrAssistantState get state => _state;
  VrAssistantReply? get lastReply => _lastReply;

  /// Returns null on overlap, cancellation or disposal.
  ///
  /// An explicit image request fails visibly if no current capture is available;
  /// it never silently sends a stale image or starts the provider without it.
  /// Capture callbacks must return a PNG or JPEG, not arbitrary binary data.
  Future<VrAssistantReply?> ask(
    String text, {
    required VrAssistantContext context,
    Future<Uint8List?> Function()? capture,
    bool includeImage = false,
  }) {
    if (_disposed || busy) return Future.value();
    final prompt = text.trim();
    if (prompt.isEmpty ||
        prompt.length > maxPromptCharacters ||
        utf8.encode(prompt).length > maxPromptBytes) {
      return Future.value(
        _reportInvalid(
          VrAssistantTranslationConstants.promptLengthError(
            maxPromptCharacters,
          ),
        ),
      );
    }
    if (includeImage && capture == null) {
      return Future.value(
        _reportInvalid(
          VrAssistantTranslationConstants.errorNoCaptureAvailable,
        ),
      );
    }
    final operation = (
      generation: ++_generation,
      result: Completer<VrAssistantReply?>(),
    );
    _operation = operation;
    _lastReply = null;
    if (includeImage) {
      _status = VrAssistantTranslationConstants.statusCapturingView;
      _state = VrAssistantState.capturingContext;
    } else {
      _status = VrAssistantTranslationConstants.statusConsultingAssistant;
      _state = VrAssistantState.thinking;
    }
    notifyListeners();
    final enrichedContext = toolRegistry != null
        ? toolRegistry!.enrichContext(context)
        : context;
    unawaited(
      _perform(operation, prompt, enrichedContext, capture, includeImage),
    );
    return operation.result.future;
  }

  /// Executes the proposed action on [lastReply] through [toolRegistry] if
  /// registered and allowed by [allowedActions].
  Future<Object?> executeLastAction({Set<String>? allowedActions}) async {
    final reply = _lastReply;
    final registry = toolRegistry;
    if (_disposed || reply == null || !reply.hasAction || registry == null) {
      return null;
    }
    _state = VrAssistantState.executingAction;
    _status = VrAssistantTranslationConstants.statusExecutingAction;
    notifyListeners();
    try {
      final result = await registry.executeReplyAction(
        reply,
        allowedActions: allowedActions,
      );
      if (!_disposed) {
        _state = VrAssistantState.responding;
        _status = VrAssistantTranslationConstants.statusActionExecuted;
        notifyListeners();
      }
      return result;
    } catch (_) {
      if (!_disposed) {
        _state = VrAssistantState.error;
        _status = VrAssistantTranslationConstants.errorActionNotAllowed;
        notifyListeners();
      }
      rethrow;
    }
  }

  VrAssistantReply _reportInvalid(String message) {
    final reply = VrAssistantReply(text: message, isError: true);
    _lastReply = reply;
    _status = message;
    _state = VrAssistantState.error;
    notifyListeners();
    return reply;
  }

  bool _current(
    ({int generation, Completer<VrAssistantReply?> result}) operation,
  ) =>
      !_disposed &&
      identical(_operation?.result, operation.result) &&
      operation.generation == _generation &&
      !operation.result.isCompleted;

  void _armTimeout(
    ({int generation, Completer<VrAssistantReply?> result}) operation,
    Duration duration,
    String message,
  ) {
    _operationTimer?.cancel();
    _operationTimer = Timer(duration, () {
      if (!_current(operation)) return;
      _publish(operation, VrAssistantReply(text: message, isError: true));
      // _perform still owns the lock until the real asynchronous call resolves.
      _generation++;
    });
  }

  Future<void> _perform(
    ({int generation, Completer<VrAssistantReply?> result}) operation,
    String text,
    VrAssistantContext context,
    Future<Uint8List?> Function()? capture,
    bool includeImage,
  ) async {
    try {
      if (!_current(operation)) return;
      Uint8List? bytes;
      String? mime;
      if (includeImage) {
        _armTimeout(
          operation,
          captureTimeout,
          VrAssistantTranslationConstants.errorCaptureTimeout,
        );
        bytes = await capture!();
        _operationTimer?.cancel();
        if (!_current(operation)) return;
        if (bytes == null || bytes.isEmpty || bytes.length > maxImageBytes) {
          _publish(
            operation,
            VrAssistantReply(
              text: VrAssistantTranslationConstants.errorInvalidCapture,
              isError: true,
            ),
          );
          return;
        }
        mime = _imageMimeType(bytes);
        if (mime == null) {
          _publish(
            operation,
            VrAssistantReply(
              text: VrAssistantTranslationConstants.errorCaptureFormat,
              isError: true,
            ),
          );
          return;
        }
      }
      if (!_current(operation)) return;
      _status = VrAssistantTranslationConstants.statusConsultingAssistant;
      _state = VrAssistantState.thinking;
      notifyListeners();
      if (!_current(operation)) return;
      _armTimeout(
        operation,
        requestTimeout,
        VrAssistantTranslationConstants.errorRequestTimeout,
      );
      final reply = await _provider.respond(
        VrAssistantRequest(
          text: text,
          context: context,
          imageBytes: bytes,
          imageMimeType: mime,
        ),
      );
      _operationTimer?.cancel();
      if (_current(operation)) _publish(operation, reply);
    } catch (_) {
      if (_current(operation)) {
        // Provider errors may contain credentials, prompts or image URLs.
        _publish(
          operation,
          VrAssistantReply(
            text: VrAssistantTranslationConstants.errorRequestFailed,
            isError: true,
          ),
        );
      }
    } finally {
      _operationTimer?.cancel();
      if (!operation.result.isCompleted) operation.result.complete();
      if (identical(_operation?.result, operation.result)) {
        _operation = null;
        if (!_disposed) notifyListeners();
      }
    }
  }

  void _publish(
    ({int generation, Completer<VrAssistantReply?> result}) operation,
    VrAssistantReply reply,
  ) {
    if (!_current(operation)) return;
    _lastReply = reply;
    _status = reply.isError
        ? reply.text
        : VrAssistantTranslationConstants.statusReplyReady;
    _state = reply.isError
        ? VrAssistantState.error
        : VrAssistantState.responding;
    operation.result.complete(reply);
    notifyListeners();
  }

  void cancel() {
    if (_disposed) return;
    final operation = _operation;
    _generation++;
    _operationTimer?.cancel();
    if (operation != null && !operation.result.isCompleted) {
      operation.result.complete();
    }
    _lastReply = null;
    _state = VrAssistantState.idle;
    _status = operation == null
        ? VrAssistantTranslationConstants.statusCancelled
        : VrAssistantTranslationConstants.statusCancellingInFlight;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _operationTimer?.cancel();
    final result = _operation?.result;
    if (result != null && !result.isCompleted) result.complete();
    _lastReply = null;
    try {
      _provider.dispose();
    } finally {
      super.dispose();
    }
  }

  static String? _imageMimeType(Uint8List bytes) {
    const png = VrAssistantConstants.pngSignature;
    if (bytes.length >= png.length) {
      var match = true;
      for (var i = 0; i < png.length; i++) {
        if (bytes[i] != png[i]) match = false;
      }
      if (match) return VrAssistantConstants.mimePng;
    }
    const jpeg = VrAssistantConstants.jpegSignature;
    if (bytes.length >= jpeg.length &&
        bytes[0] == jpeg[0] &&
        bytes[1] == jpeg[1] &&
        bytes[2] == jpeg[2]) {
      return VrAssistantConstants.mimeJpeg;
    }
    return null;
  }
}
