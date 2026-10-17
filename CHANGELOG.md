## 1.0.0

- First stable release of `vrlizate_assistant` for Open Neom VRlizate SDK v1.0.0.
- Adopted strict Open Neom modular architecture (`utils/constants`, `utils/enums`, `domain/models`, `domain/services`, `data/providers`, `ui`) with one declaration per file and backward-compatible `lib/src/` barrel exports.
- Added `VrUniversalAiProvider` and `VrAiProviderConfig` with presets for OpenAI-compatible APIs (OpenAI, Groq, DeepSeek), Google Gemini, Anthropic Claude, and Ollama, including multimodal base64 scene snapshot support.
- Added `VrNeomageAssistantProvider` and `VrNeomageAgentBridge` to connect VRlizate spatial experiences directly with Open Neom's `neomage` agentic engine (`Message`, `ContentBlock`, `ToolUseBlock`, `ImageBlock`, and `ToolDefinition` formats).
- Added `VrAssistantToolRegistry` and `VrAssistantToolDefinition` for registering, advertising, validating, and executing spatial tool actions.
- Added `VrAssistantState` lifecycle enum (`idle`, `capturingContext`, `thinking`, `responding`, `executingAction`, `error`) and centralized constants in `VrAssistantConstants` and `VrAssistantTranslationConstants`.

## 0.1.0-beta.1

- Contratos opcionales de proveedor y contexto inmutable para asistencia.
- Consultas limitadas con cancelación lógica y descarte de respuestas tardías.
- Captura local PNG de la experiencia activa, monocular y sin transporte de red.
- Pruebas de límites, ciclo de vida y captura de la capa compuesta de Flutter.
- El host suministra Itzli/SAIA u otro proveedor y conserva la ejecución de acciones.
