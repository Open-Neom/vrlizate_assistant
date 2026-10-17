/// Supported AI provider families for VRlizate spatial assistance.
enum VrAiProviderType {
  /// Open Neom's `neomage` agentic engine and session format.
  neomage,

  /// OpenAI-compatible Chat Completions API (OpenAI, Groq, DeepSeek, etc.).
  openAiCompatible,

  /// Google Gemini `generateContent` REST API.
  gemini,

  /// Anthropic Claude Messages REST API.
  anthropic,

  /// Local or remote Ollama `/api/chat` REST API.
  ollama,

  /// Custom HTTP endpoint using the standard OpenAI-compatible JSON payload.
  custom,
}
