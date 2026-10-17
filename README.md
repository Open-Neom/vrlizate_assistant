# vrlizate_assistant

Módulo de asistencia espacial contextual e inteligencia artificial del **Open Neom VRlizate SDK (`1.0.0`)**.

Proporciona contratos inmutables de contexto 3D, capturas visuales locales del viewport (estéreo/mono), un registro de herramientas espaciales (`VrAssistantToolRegistry`), integración nativa con **`neomage`** (`VrNeomageAssistantProvider` / `VrNeomageAgentBridge`) y un proveedor universal de modelos de lenguaje (`VrUniversalAiProvider`) compatible con **OpenAI, Google Gemini, Anthropic Claude, Ollama, Groq y DeepSeek**.

## Arquitectura (`neom_modules`)

- `lib/utils/constants/`
  - `VrAssistantConstants`: límites, firmas MIME, cabeceras HTTP, claves JSON y endpoints predeterminados.
  - `VrAssistantTranslationConstants`: textos de estado y mensajes de validación.
- `lib/utils/enums/`
  - `VrAiProviderType`: `neomage`, `openAiCompatible`, `gemini`, `anthropic`, `ollama`, `custom`.
  - `VrAssistantState`: `idle`, `capturingContext`, `thinking`, `responding`, `executingAction`, `error`.
- `lib/domain/models/`
  - `VrAssistantContext`: copia inmutable de la escena activa (`experienceId`, `title`, `details`, `allowedActions`).
  - `VrAssistantRequest`: pregunta del usuario + `VrAssistantContext` + captura PNG/JPEG opcional.
  - `VrAssistantReply`: respuesta textual y propuesta opcional de acción espacial (`action`, `arguments`).
  - `VrAiProviderConfig`: configuración inmutable con presets `.neomage()`, `.gemini()`, `.openAi()`, `.anthropic()` y `.ollama()`.
  - `VrAssistantToolDefinition`: esquema JSON y manejador para herramientas/acciones espaciales.
  - `VrAssistantCaptureLease`: concesión opaca de superficie activa.
- `lib/domain/services/`
  - `VrAssistantProvider`: interfaz para cualquier proveedor de asistencia espacial.
  - `VrAssistantController`: orquestación con exclusión de consultas en vuelo, cancelación lógica, timeouts y estado reactivo (`ChangeNotifier`).
  - `VrAssistantCaptureController`: gestor de captura local de una sola fuente activa.
  - `VrAssistantToolRegistry`: registro, generación de esquemas de herramientas, validación de `allowedActions` y ejecución segura de acciones espaciales.
  - `VrNeomageAgentBridge`: puente y adaptador de formato para sesiones y agentes `neomage`.
- `lib/data/providers/`
  - `VrUniversalAiProvider`: cliente listo para usar con OpenAI, Gemini, Anthropic Claude y Ollama (texto + imagen base64 + llamadas a herramientas).
  - `VrNeomageAssistantProvider`: adaptador directo para conectar agentes `neomage` como asistente espacial VR.
- `lib/ui/`
  - `VrAssistantSurface`: widget de captura puntual de la capa compuesta de Flutter (recorte del ojo izquierdo en estéreo, límite de 768 px por dimensión).

## Uso con `neomage` o Proveedores Universales (Gemini, OpenAI, Claude, Ollama)

```dart
import 'package:vrlizate_assistant/vrlizate_assistant.dart';

final tools = VrAssistantToolRegistry(
  initialTools: [
    VrAssistantToolDefinition(
      name: 'openRoom',
      description: 'Abre una sala espacial por su identificador.',
      parameterSchema: {
        'type': 'object',
        'properties': {
          'room': {'type': 'string'},
        },
        'required': ['room'],
      },
      handler: (args) async => 'Opened ${args['room']}',
    ),
  ],
);

// Opción A: Proveedor universal (Gemini, OpenAI, Anthropic, Ollama)
final provider = VrUniversalAiProvider(
  config: VrAiProviderConfig.gemini(apiKey: '<GEMINI_API_KEY>'),
  toolRegistry: tools,
);

// Opción B: Puente directo con el motor agéntico `neomage`
final neomageProvider = VrNeomageAssistantProvider(
  toolRegistry: tools,
  onQuery: (payload) async {
    // Enviar payload (compatible con Message y ToolDefinition de neomage)
    return {
      'role': 'assistant',
      'content': [
        {'type': 'text', 'text': 'Abriendo la sala de cine.'},
        {
          'type': 'tool_use',
          'id': 'call_1',
          'name': 'openRoom',
          'input': {'room': 'cinema'},
        },
      ],
    };
  },
);

final captures = VrAssistantCaptureController();
final assistant = VrAssistantController(
  provider: provider,
  toolRegistry: tools,
);

final reply = await assistant.ask(
  '¿Qué puedo hacer aquí?',
  context: VrAssistantContext(
    experienceId: 'home',
    title: 'Plaza VRlizate',
    details: {'room': 'lobby', 'availableControls': ['play', 'back']},
    allowedActions: {'openRoom'},
  ),
  capture: captures.capture,
  includeImage: true,
);

if (reply != null && reply.hasAction) {
  await assistant.executeLastAction(allowedActions: {'openRoom'});
}
```

## Límites y Ciclo de Vida

- Preguntas limitadas a 4000 caracteres UTF-16 y 16000 bytes UTF-8.
- Capturas limitadas a 4 MiB, verificando firma PNG o JPEG antes de enviarse al proveedor.
- Timeouts predeterminados: captura 3 segundos y consulta 30 segundos.
- `VrAssistantSurface` se desregistra automáticamente al pasar a segundo plano, desactivarse o desmontarse.

## Validación

```sh
flutter pub get
flutter test
flutter analyze
```
