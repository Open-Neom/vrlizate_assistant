import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'vr_assistant_models.dart';

/// Owns one provider and bounds assistance outside the rendering frame loop.
///
/// A timeout or [cancel] invalidates the result immediately. Because the
/// provider interface cannot forcibly stop native work or network I/O, [busy]
/// remains true until that real operation finishes; a second allocation/request
/// is never started in the meantime. Dispose this controller with its host.
class VrAssistantController extends ChangeNotifier {
  VrAssistantController({
    required VrAssistantProvider provider,
    this.requestTimeout = const Duration(seconds: 30),
    this.captureTimeout = const Duration(seconds: 3),
  }) : _provider = provider {
    if (requestTimeout <= Duration.zero || captureTimeout <= Duration.zero) {
      throw ArgumentError('Assistant timeouts must be positive.');
    }
  }

  static const maxPromptCharacters = 4000;
  static const maxPromptBytes = 16000;
  static const maxImageBytes = 4 * 1024 * 1024;

  final VrAssistantProvider _provider;
  final Duration requestTimeout;
  final Duration captureTimeout;
  _AssistantOperation? _operation;
  int _generation = 0;
  bool _disposed = false;
  String _status = 'Listo';
  VrAssistantReply? _lastReply;

  bool get busy => _operation != null;
  String get status => _status;
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
          'Escribe una pregunta de hasta $maxPromptCharacters caracteres.',
        ),
      );
    }
    if (includeImage && capture == null) {
      return Future.value(
        _reportInvalid('No hay una captura disponible en esta experiencia.'),
      );
    }
    final operation = _AssistantOperation(++_generation);
    _operation = operation;
    _lastReply = null;
    _status = includeImage
        ? 'Capturando la vista…'
        : 'Consultando al asistente…';
    notifyListeners();
    unawaited(_perform(operation, prompt, context, capture, includeImage));
    return operation.result.future;
  }

  VrAssistantReply _reportInvalid(String message) {
    final reply = VrAssistantReply(text: message, isError: true);
    _lastReply = reply;
    _status = message;
    notifyListeners();
    return reply;
  }

  bool _current(_AssistantOperation operation) =>
      !_disposed &&
      identical(_operation, operation) &&
      operation.generation == _generation &&
      !operation.result.isCompleted;

  void _armTimeout(
    _AssistantOperation operation,
    Duration duration,
    String message,
  ) {
    operation.timer?.cancel();
    operation.timer = Timer(duration, () {
      if (!_current(operation)) return;
      _publish(operation, VrAssistantReply(text: message, isError: true));
      // _perform still owns the lock until the real asynchronous call resolves.
      _generation++;
    });
  }

  Future<void> _perform(
    _AssistantOperation operation,
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
          'La captura tardó demasiado. Espera a que termine antes de reintentar.',
        );
        bytes = await capture!();
        operation.timer?.cancel();
        if (!_current(operation)) return;
        if (bytes == null || bytes.isEmpty || bytes.length > maxImageBytes) {
          _publish(
            operation,
            VrAssistantReply(
              text:
                  'No se pudo obtener una captura válida de esta experiencia.',
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
              text: 'La captura debe ser PNG o JPEG.',
              isError: true,
            ),
          );
          return;
        }
      }
      if (!_current(operation)) return;
      _status = 'Consultando al asistente…';
      notifyListeners();
      if (!_current(operation)) return;
      _armTimeout(
        operation,
        requestTimeout,
        'El asistente tardó demasiado. Espera a que termine antes de reintentar.',
      );
      final reply = await _provider.respond(
        VrAssistantRequest(
          text: text,
          context: context,
          imageBytes: bytes,
          imageMimeType: mime,
        ),
      );
      operation.timer?.cancel();
      if (_current(operation)) _publish(operation, reply);
    } catch (_) {
      if (_current(operation)) {
        // Provider errors may contain credentials, prompts or image URLs.
        _publish(
          operation,
          VrAssistantReply(
            text: 'No se pudo completar la consulta. Inténtalo de nuevo.',
            isError: true,
          ),
        );
      }
    } finally {
      operation.timer?.cancel();
      if (!operation.result.isCompleted) operation.result.complete();
      if (identical(_operation, operation)) {
        _operation = null;
        if (!_disposed) notifyListeners();
      }
    }
  }

  void _publish(_AssistantOperation operation, VrAssistantReply reply) {
    if (!_current(operation)) return;
    _lastReply = reply;
    _status = reply.isError ? reply.text : 'Respuesta lista';
    operation.result.complete(reply);
    notifyListeners();
  }

  void cancel() {
    if (_disposed) return;
    final operation = _operation;
    _generation++;
    operation?.timer?.cancel();
    if (operation != null && !operation.result.isCompleted) {
      operation.result.complete();
    }
    _lastReply = null;
    _status = operation == null
        ? 'Cancelado'
        : 'Cancelado. Finalizando la consulta…';
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _operation?.timer?.cancel();
    final result = _operation?.result;
    if (result != null && !result.isCompleted) result.complete();
    _lastReply = null;
    try {
      _provider.dispose();
    } finally {
      super.dispose();
    }
  }
}

class _AssistantOperation {
  _AssistantOperation(this.generation);
  final int generation;
  final result = Completer<VrAssistantReply?>();
  Timer? timer;
}

String? _imageMimeType(Uint8List bytes) {
  const png = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length >= png.length) {
    var match = true;
    for (var i = 0; i < png.length; i++) {
      if (bytes[i] != png[i]) match = false;
    }
    if (match) return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255) {
    return 'image/jpeg';
  }
  return null;
}
