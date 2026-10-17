import '../../domain/models/vr_ai_provider_config.dart';
import '../../domain/models/vr_assistant_reply.dart';
import '../../domain/models/vr_assistant_request.dart';
import '../../domain/services/vr_assistant_provider.dart';
import '../../domain/services/vr_assistant_tool_registry.dart';
import '../../domain/services/vr_neomage_agent_bridge.dart';
import '../../utils/constants/vr_assistant_translation_constants.dart';

/// Spatial assistant provider that connects VRlizate Assistant directly to
/// Open Neom's `neomage` agentic engine (via [VrNeomageAgentBridge] or an
/// [onQuery] callback) using `neomage`'s native `Message`, `ContentBlock`,
/// `ToolUseBlock`, `ImageBlock`, and `ToolDefinition` schemas.
class VrNeomageAssistantProvider implements VrAssistantProvider {
  VrNeomageAssistantProvider({
    this.bridge,
    this.onQuery,
    VrAiProviderConfig? config,
    this.toolRegistry,
    this.disposeBridge = false,
  }) : config = config ?? VrAiProviderConfig.neomage() {
    if (bridge == null && onQuery == null) {
      throw ArgumentError(
        VrAssistantTranslationConstants.argErrorNeomageHandlerRequired,
      );
    }
  }

  final VrNeomageAgentBridge? bridge;
  final VrNeomageQueryCallback? onQuery;
  final VrAiProviderConfig config;
  final VrAssistantToolRegistry? toolRegistry;
  final bool disposeBridge;
  bool _disposed = false;

  @override
  Future<VrAssistantReply> respond(VrAssistantRequest request) async {
    if (_disposed) {
      return VrAssistantReply(
        text: VrAssistantTranslationConstants.errorRequestFailed,
        isError: true,
      );
    }

    try {
      final payload = VrNeomageAgentBridge.buildNeomagePayload(
        request: request,
        config: config,
        toolRegistry: toolRegistry,
      );

      final Map<String, Object?> responseMap;
      if (bridge != null) {
        responseMap = await bridge!.sendSpatialQuery(payload);
      } else if (onQuery != null) {
        responseMap = await onQuery!(payload);
      } else {
        return VrAssistantReply(
          text: VrAssistantTranslationConstants.errorNeomageBridgeNotConfigured,
          isError: true,
        );
      }

      return VrNeomageAgentBridge.parseNeomageResponse(responseMap);
    } catch (_) {
      return VrAssistantReply(
        text: VrAssistantTranslationConstants.errorRequestFailed,
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (disposeBridge) {
      bridge?.dispose();
    }
  }
}
