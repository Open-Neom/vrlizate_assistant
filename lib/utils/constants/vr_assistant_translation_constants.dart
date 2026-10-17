class VrAssistantTranslationConstants {
  const VrAssistantTranslationConstants._();

  static const String statusReady = 'Listo';
  static const String statusCapturingView = 'Capturando la vista…';
  static const String statusConsultingAssistant = 'Consultando al asistente…';
  static const String statusReplyReady = 'Respuesta lista';
  static const String statusCancelled = 'Cancelado';
  static const String statusCancellingInFlight =
      'Cancelado. Finalizando la consulta…';
  static const String statusExecutingAction = 'Ejecutando acción espacial…';
  static const String statusActionExecuted = 'Acción ejecutada';

  static const String errorNoCaptureAvailable =
      'No hay una captura disponible en esta experiencia.';
  static const String errorCaptureTimeout =
      'La captura tardó demasiado. Espera a que termine antes de reintentar.';
  static const String errorInvalidCapture =
      'No se pudo obtener una captura válida de esta experiencia.';
  static const String errorCaptureFormat = 'La captura debe ser PNG o JPEG.';
  static const String errorRequestTimeout =
      'El asistente tardó demasiado. Espera a que termine antes de reintentar.';
  static const String errorRequestFailed =
      'No se pudo completar la consulta. Inténtalo de nuevo.';
  static const String errorEmptyProviderReply =
      'El proveedor de IA devolvió una respuesta vacía.';
  static const String errorActionNotAllowed =
      'La acción propuesta no está permitida en esta experiencia.';
  static const String errorToolNotFound =
      'La herramienta espacial solicitada no está registrada.';
  static const String errorNeomageBridgeNotConfigured =
      'El puente de Neomage no está configurado.';

  static const String errorInvalidPromptPrefix =
      'Escribe una pregunta de hasta ';
  static const String errorInvalidPromptSuffix = ' caracteres.';

  static const String argErrorPositiveTimeouts =
      'Assistant timeouts must be positive.';
  static const String argErrorPositiveCaptureTimeout =
      'Capture timeout must be positive.';
  static const String argErrorImageBytesAndMimeTogether =
      'Image bytes and MIME type must be supplied together.';
  static const String argErrorSupportedImageFormats =
      'Only PNG and JPEG images are supported.';
  static const String argErrorContextLimits =
      'Assistant context exceeds collection limits.';
  static const String argErrorContextMapKeys =
      'Assistant context map keys must be strings.';
  static const String argErrorContextFiniteValues =
      'Assistant context requires finite JSON-like values.';
  static const String argErrorToolNameEmpty = 'Tool name must not be empty.';
  static const String argErrorEndpointEmpty =
      'Provider endpoint URL must not be empty.';
  static const String argErrorModelIdEmpty =
      'Provider model ID must not be empty.';
  static const String argErrorNeomageHandlerRequired =
      'Either a VrNeomageAgentBridge or an onQuery callback must be supplied.';

  static String promptLengthError(int maxCharacters) =>
      '$errorInvalidPromptPrefix$maxCharacters$errorInvalidPromptSuffix';
}
