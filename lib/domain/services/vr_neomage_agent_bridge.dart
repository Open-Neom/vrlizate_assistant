import 'dart:convert';

import '../../utils/constants/vr_assistant_constants.dart';
import '../../utils/constants/vr_assistant_translation_constants.dart';
import '../models/vr_ai_provider_config.dart';
import '../models/vr_assistant_reply.dart';
import '../models/vr_assistant_request.dart';
import 'vr_assistant_tool_registry.dart';

/// Callback signature for invoking a `neomage` agent/session without tight
/// compile-time coupling.
typedef VrNeomageQueryCallback =
    Future<Map<String, Object?>> Function(Map<String, Object?> payload);

/// Bridge interface and format adapter connecting VRlizate Assistant to
/// Open Neom's `neomage` agentic engine (`Message`, `ContentBlock`, `ToolUseBlock`,
/// `ImageBlock`, and `ToolDefinition` schemas).
abstract interface class VrNeomageAgentBridge {
  /// Sends a structured `neomage` spatial query payload and returns the
  /// agent's response map (`Message.toApiMap()` or `{text, action, arguments}`).
  Future<Map<String, Object?>> sendSpatialQuery(Map<String, Object?> payload);

  /// Releases any resources held by this bridge.
  void dispose();

  /// Builds a `neomage`-compatible user `Message` map (`role: 'user'`, `content: [...]`)
  /// including spatial context and optional base64 `ImageBlock`.
  static Map<String, Object?> buildNeomageMessageMap(
    VrAssistantRequest request, {
    VrAssistantToolRegistry? toolRegistry,
  }) {
    final contextJson = jsonEncode(request.context.toJson());
    final promptBuffer = StringBuffer()
      ..writeln('${VrAssistantConstants.contextHeaderPrefix}$contextJson');
    if (request.context.allowedActions.isNotEmpty) {
      promptBuffer.writeln(
        '${VrAssistantConstants.allowedActionsHeaderPrefix}'
        '${request.context.allowedActions.join(', ')}',
      );
    }
    if (toolRegistry != null) {
      final instructions = toolRegistry.buildPromptInstructions(
        allowedActions: request.context.allowedActions,
      );
      if (instructions.isNotEmpty) {
        promptBuffer.writeln(instructions);
      }
    }
    promptBuffer.write(
      '${VrAssistantConstants.userPromptHeaderPrefix}${request.text}',
    );

    final contentBlocks = <Map<String, Object?>>[
      <String, Object?>{
        VrAssistantConstants.keyType: VrAssistantConstants.keyTypeText,
        VrAssistantConstants.keyText: promptBuffer.toString(),
      },
    ];

    if (request.hasImage) {
      contentBlocks.add(<String, Object?>{
        VrAssistantConstants.keyType: VrAssistantConstants.keyTypeImage,
        VrAssistantConstants.keySource: <String, Object?>{
          VrAssistantConstants.keyType: VrAssistantConstants.keyBase64,
          VrAssistantConstants.keyMediaType: request.imageMimeType,
          VrAssistantConstants.keyData: base64Encode(request.imageBytes!),
        },
      });
    }

    return <String, Object?>{
      VrAssistantConstants.keyRole: VrAssistantConstants.keyRoleUser,
      VrAssistantConstants.keyContent: contentBlocks,
    };
  }

  /// Builds the full request payload sent to a `neomage` session or query engine.
  static Map<String, Object?> buildNeomagePayload({
    required VrAssistantRequest request,
    required VrAiProviderConfig config,
    VrAssistantToolRegistry? toolRegistry,
  }) {
    final activeTools =
        toolRegistry?.toNeomageTools(
          allowedActions: request.context.allowedActions,
        ) ??
        const <Map<String, Object?>>[];

    return <String, Object?>{
      VrAssistantConstants.keyModel: config.modelId,
      VrAssistantConstants.keySystemPrompt: config.systemPrompt,
      VrAssistantConstants.keyTemperature: config.temperature,
      VrAssistantConstants.keyMaxTokens: config.maxTokens,
      VrAssistantConstants.keyContext: request.context.toJson(),
      VrAssistantConstants.keyMessages: <Map<String, Object?>>[
        buildNeomageMessageMap(request, toolRegistry: toolRegistry),
      ],
      if (activeTools.isNotEmpty) VrAssistantConstants.keyTools: activeTools,
    };
  }

  /// Parses a `neomage` response map (`Message.toApiMap()` with `TextBlock` and
  /// `ToolUseBlock` items, or direct `{text, action, arguments}`) into a
  /// [VrAssistantReply].
  static VrAssistantReply parseNeomageResponse(Map<String, Object?> response) {
    if (response[VrAssistantConstants.keyIsError] == true) {
      final errText =
          response[VrAssistantConstants.keyText]?.toString() ??
          VrAssistantTranslationConstants.errorRequestFailed;
      return VrAssistantReply(text: errText, isError: true);
    }

    String? extractedAction;
    Map<String, Object?> extractedArgs = const <String, Object?>{};
    final textParts = <String>[];

    final content = response[VrAssistantConstants.keyContent];
    if (content is List) {
      for (final block in content) {
        if (block is Map) {
          final blockType = block[VrAssistantConstants.keyType];
          if (blockType == VrAssistantConstants.keyTypeText) {
            final text = block[VrAssistantConstants.keyText]?.toString() ?? '';
            if (text.isNotEmpty) textParts.add(text);
          } else if (blockType == VrAssistantConstants.keyTypeToolUse) {
            final toolName = block[VrAssistantConstants.keyName]?.toString();
            if (toolName != null && toolName.isNotEmpty) {
              extractedAction = toolName;
              final rawInput = block[VrAssistantConstants.keyInput];
              if (rawInput is Map) {
                extractedArgs = <String, Object?>{
                  for (final entry in rawInput.entries)
                    if (entry.key is String) entry.key as String: entry.value,
                };
              }
            }
          }
        }
      }
    } else if (content is String && content.trim().isNotEmpty) {
      textParts.add(content.trim());
    }

    if (textParts.isEmpty) {
      final directText =
          response[VrAssistantConstants.keyText] ??
          response[VrAssistantConstants.keyReply] ??
          response[VrAssistantConstants.keyResponse];
      if (directText is String && directText.trim().isNotEmpty) {
        textParts.add(directText.trim());
      }
    }

    if (extractedAction == null) {
      final directAction = response[VrAssistantConstants.keyAction];
      if (directAction is String && directAction.trim().isNotEmpty) {
        extractedAction = directAction.trim();
        final rawArgs =
            response[VrAssistantConstants.keyArguments] ??
            response[VrAssistantConstants.keyArgs] ??
            response[VrAssistantConstants.keyInput];
        if (rawArgs is Map) {
          extractedArgs = <String, Object?>{
            for (final entry in rawArgs.entries)
              if (entry.key is String) entry.key as String: entry.value,
          };
        }
      }
    }

    final combinedText = textParts.join('\n').trim();
    if (combinedText.isNotEmpty && extractedAction == null) {
      final structured = tryParseStructuredJsonReply(combinedText);
      if (structured != null) return structured;
    }

    if (combinedText.isEmpty && extractedAction == null) {
      return VrAssistantReply(
        text: VrAssistantTranslationConstants.errorEmptyProviderReply,
        isError: true,
      );
    }

    return VrAssistantReply(
      text: combinedText.isEmpty ? extractedAction! : combinedText,
      action: extractedAction,
      arguments: extractedArgs,
    );
  }

  /// Attempts to parse a JSON object or fenced ```json block into [VrAssistantReply].
  static VrAssistantReply? tryParseStructuredJsonReply(String rawText) {
    var candidate = rawText.trim();
    if (candidate.startsWith(VrAssistantConstants.jsonFenceStart)) {
      candidate = candidate
          .substring(VrAssistantConstants.jsonFenceStart.length)
          .trim();
      if (candidate.endsWith(VrAssistantConstants.codeFence)) {
        candidate = candidate
            .substring(
              0,
              candidate.length - VrAssistantConstants.codeFence.length,
            )
            .trim();
      }
    } else if (candidate.startsWith(VrAssistantConstants.codeFence) &&
        candidate.endsWith(VrAssistantConstants.codeFence) &&
        candidate.length > VrAssistantConstants.codeFence.length * 2) {
      candidate = candidate
          .substring(
            VrAssistantConstants.codeFence.length,
            candidate.length - VrAssistantConstants.codeFence.length,
          )
          .trim();
    }

    if (!candidate.startsWith('{') || !candidate.endsWith('}')) {
      return null;
    }

    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map) {
        final jsonMap = <String, Object?>{
          for (final entry in decoded.entries)
            if (entry.key is String) entry.key as String: entry.value,
        };
        if (jsonMap.containsKey(VrAssistantConstants.keyText) ||
            jsonMap.containsKey(VrAssistantConstants.keyAction) ||
            jsonMap.containsKey(VrAssistantConstants.keyReply)) {
          return VrAssistantReply.fromJson(jsonMap);
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
