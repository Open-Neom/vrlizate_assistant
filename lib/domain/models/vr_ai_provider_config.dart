import '../../utils/constants/vr_assistant_constants.dart';
import '../../utils/constants/vr_assistant_translation_constants.dart';
import '../../utils/enums/vr_ai_provider_type.dart';

/// Immutable configuration for connecting VRlizate Assistant to `neomage` or
/// any universal LLM provider (OpenAI, Gemini, Anthropic Claude, Ollama, etc.).
class VrAiProviderConfig {
  VrAiProviderConfig({
    required this.providerType,
    required this.endpointUrl,
    required this.modelId,
    this.apiKey,
    this.systemPrompt = VrAssistantConstants.defaultSystemPrompt,
    this.temperature = VrAssistantConstants.defaultTemperature,
    this.maxTokens = VrAssistantConstants.defaultMaxTokens,
    Map<String, String> headers = const {},
  }) : headers = Map<String, String>.unmodifiable(headers) {
    if (endpointUrl.trim().isEmpty) {
      throw ArgumentError(
        VrAssistantTranslationConstants.argErrorEndpointEmpty,
      );
    }
    if (modelId.trim().isEmpty) {
      throw ArgumentError(VrAssistantTranslationConstants.argErrorModelIdEmpty);
    }
  }

  /// Preset configuration for Google Gemini (`generateContent`).
  factory VrAiProviderConfig.gemini({
    String? apiKey,
    String modelId = VrAssistantConstants.defaultGeminiModel,
    String? endpointUrl,
    String systemPrompt = VrAssistantConstants.defaultSystemPrompt,
    double temperature = VrAssistantConstants.defaultTemperature,
    int maxTokens = VrAssistantConstants.defaultMaxTokens,
    Map<String, String> headers = const {},
  }) => VrAiProviderConfig(
    providerType: VrAiProviderType.gemini,
    endpointUrl:
        endpointUrl ??
        '${VrAssistantConstants.defaultGeminiEndpointPrefix}$modelId${VrAssistantConstants.defaultGeminiEndpointSuffix}',
    apiKey: apiKey,
    modelId: modelId,
    systemPrompt: systemPrompt,
    temperature: temperature,
    maxTokens: maxTokens,
    headers: headers,
  );

  /// Preset configuration for OpenAI and OpenAI-compatible APIs (Groq, DeepSeek, etc.).
  factory VrAiProviderConfig.openAi({
    String? apiKey,
    String modelId = VrAssistantConstants.defaultOpenAiModel,
    String endpointUrl = VrAssistantConstants.defaultOpenAiEndpoint,
    String systemPrompt = VrAssistantConstants.defaultSystemPrompt,
    double temperature = VrAssistantConstants.defaultTemperature,
    int maxTokens = VrAssistantConstants.defaultMaxTokens,
    Map<String, String> headers = const {},
  }) => VrAiProviderConfig(
    providerType: VrAiProviderType.openAiCompatible,
    endpointUrl: endpointUrl,
    apiKey: apiKey,
    modelId: modelId,
    systemPrompt: systemPrompt,
    temperature: temperature,
    maxTokens: maxTokens,
    headers: headers,
  );

  /// Preset configuration for Anthropic Claude (`v1/messages`).
  factory VrAiProviderConfig.anthropic({
    String? apiKey,
    String modelId = VrAssistantConstants.defaultAnthropicModel,
    String endpointUrl = VrAssistantConstants.defaultAnthropicEndpoint,
    String systemPrompt = VrAssistantConstants.defaultSystemPrompt,
    double temperature = VrAssistantConstants.defaultTemperature,
    int maxTokens = VrAssistantConstants.defaultMaxTokens,
    Map<String, String> headers = const {},
  }) => VrAiProviderConfig(
    providerType: VrAiProviderType.anthropic,
    endpointUrl: endpointUrl,
    apiKey: apiKey,
    modelId: modelId,
    systemPrompt: systemPrompt,
    temperature: temperature,
    maxTokens: maxTokens,
    headers: headers,
  );

  /// Preset configuration for local or self-hosted Ollama (`/api/chat`).
  factory VrAiProviderConfig.ollama({
    String modelId = VrAssistantConstants.defaultOllamaModel,
    String endpointUrl = VrAssistantConstants.defaultOllamaEndpoint,
    String systemPrompt = VrAssistantConstants.defaultSystemPrompt,
    double temperature = VrAssistantConstants.defaultTemperature,
    int maxTokens = VrAssistantConstants.defaultMaxTokens,
    Map<String, String> headers = const {},
  }) => VrAiProviderConfig(
    providerType: VrAiProviderType.ollama,
    endpointUrl: endpointUrl,
    modelId: modelId,
    systemPrompt: systemPrompt,
    temperature: temperature,
    maxTokens: maxTokens,
    headers: headers,
  );

  /// Preset configuration for Open Neom's `neomage` agent bridge.
  factory VrAiProviderConfig.neomage({
    String modelId = VrAssistantConstants.defaultNeomageModel,
    String endpointUrl = VrAssistantConstants.defaultNeomageEndpoint,
    String? apiKey,
    String systemPrompt = VrAssistantConstants.defaultSystemPrompt,
    double temperature = VrAssistantConstants.defaultTemperature,
    int maxTokens = VrAssistantConstants.defaultMaxTokens,
    Map<String, String> headers = const {},
  }) => VrAiProviderConfig(
    providerType: VrAiProviderType.neomage,
    endpointUrl: endpointUrl,
    apiKey: apiKey,
    modelId: modelId,
    systemPrompt: systemPrompt,
    temperature: temperature,
    maxTokens: maxTokens,
    headers: headers,
  );

  final VrAiProviderType providerType;
  final String endpointUrl;
  final String? apiKey;
  final String modelId;
  final String systemPrompt;
  final double temperature;
  final int maxTokens;
  final Map<String, String> headers;
}
