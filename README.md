# vrlizate_assistant

Módulo opcional de asistencia contextual del VRlizate SDK, `0.1.0-beta.1`.
Incluye contratos de proveedor, consultas con límites y capturas locales de la
experiencia. **No incluye un modelo de IA, credenciales, reconocimiento de voz,
síntesis de voz ni una conexión propia a Itzli/SAIA.** El anfitrión suministra el
adaptador que reutiliza esos servicios cuando están disponibles.

## Responsabilidades

- `VrAssistantContext`: copia inmutable de experiencia, título, datos de contexto
  y acciones propuestas que el anfitrión desea ofrecer. Los datos aceptan valores
  JSON finitos, mapas con claves de texto y listas; máximo 4096 entradas y doce
  niveles. No se retienen referencias mutables al mundo.
- `VrAssistantProvider`: recibe una pregunta con contexto y, opcionalmente, una
  imagen PNG/JPEG. Devuelve texto y una propuesta de acción. El anfitrión conserva
  la validación de permisos, argumentos y vigencia de la sesión.
- `VrAssistantController`: una consulta real a la vez, cancelación lógica,
  descarte de resultados antiguos y estado para la interfaz. No ejecuta acciones.
- `VrAssistantCaptureController`: una fuente activa y una captura real a la vez.
  Las concesiones impiden que una sala anterior desregistre la actual.
- `VrAssistantSurface`: captura puntual de la capa Flutter ya compuesta. En
  estéreo recorta el ojo izquierdo antes de reservar la imagen; en mono conserva
  toda la vista. PNG, máximo 768 píxeles por dimensión y sin escalado hacia arriba.

No se activa un servidor LAN ni se abre el micrófono. No se captura por frame.
El anfitrión pide una captura explícitamente mediante `includeImage: true`, y
debe informar al usuario si su proveedor la enviará a un servicio remoto.

## Uso

```dart
final captures = VrAssistantCaptureController();
final assistant = VrAssistantController(provider: myItzliAdapter);

final view = VrAssistantSurface(
  captureController: captures,
  active: experienceActive && routeIsCurrent,
  stereo: true,
  child: experience,
);

final reply = await assistant.ask(
  '¿Qué puedo hacer aquí?',
  context: VrAssistantContext(
    experienceId: 'home',
    title: 'Plaza VRlizate',
    details: {'room': 'cinema', 'availableControls': ['play', 'back']},
    allowedActions: {'openRoom'},
  ),
  capture: captures.capture,
  includeImage: true,
);
// El host muestra reply.text y valida reply.action antes de actuar.
```

`allowedActions` es contexto para el proveedor; no concede permisos. Una respuesta
no debe abrir rutas, ejecutar código ni modificar datos sin pasar por las reglas
del anfitrión. Las capturas son contexto visual y tampoco conceden autoridad.

El controlador es dueño de su proveedor y llama `provider.dispose()` al cerrarse.
Un adaptador de un servicio compartido debe implementar `dispose()` liberando
solo sus propios recursos, sin cerrar el servicio global de Open Neom.

## Límites y ciclo de vida

La pregunta admite hasta 4000 unidades UTF-16 y 16000 bytes UTF-8. Las imágenes se
limitan a 4 MiB. Se verifica su firma PNG/JPEG antes de enviar al proveedor; el
adaptador conserva la responsabilidad de validación específica de su API.
Timeouts predeterminados: captura tres segundos y consulta treinta segundos.

`cancel()` y los timeouts resuelven al llamador y descartan respuestas tardías.
No pueden detener por la fuerza una captura GPU o una solicitud del proveedor:
`busy` sigue activo hasta que termina la operación real, evitando solicitudes
solapadas. El adaptador debe tener sus propios límites de transporte. Se devuelve
`null` al pedir mientras hay otra operación, al cancelar o después de `dispose()`.

La superficie se desregistra al pasar a segundo plano, quedar inactiva o cerrarse.
El anfitrión debe desactivarla también para rutas privadas o modales que oculten
la experiencia; el paquete no inspecciona su navegación. Las imágenes no se
almacenan en disco ni se mantienen como caché del controlador.

La captura de texturas externas, vídeo protegido o vistas nativas requiere
verificación en cada plataforma. No se promete que toda textura aparezca ni que
la captura sea gratuita para el rendimiento. Utilizar contexto estructurado como
primera opción y capturas puntuales cuando aporten información.

## Validación

Las pruebas incluidas verifican cancelación, timeout, exclusión de solicitudes,
inmutabilidad, concesiones de captura, ciclo de vida y captura PNG real de la
capa Flutter, incluido el recorte de un ojo. Ejecutar desde este paquete:

```sh
flutter pub get
flutter test
flutter analyze
```

La existencia de estas pruebas no acredita una ejecución física ni una consulta
a un proveedor remoto. Integración de voz, conectividad, calidad de respuestas y
coste GPU requieren validación del anfitrión con su adaptador y dispositivos.
