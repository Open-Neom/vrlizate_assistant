import 'dart:async';

import '../../utils/constants/vr_assistant_constants.dart';
import '../../utils/constants/vr_assistant_translation_constants.dart';
import 'vr_assistant_context.dart';

/// Callback executed when a validated spatial tool action is invoked.
typedef VrAssistantToolHandler =
    FutureOr<Object?> Function(Map<String, Object?> arguments);

/// Schema and optional execution handler for a spatial action/tool exposed to
/// `neomage` or a universal AI provider.
class VrAssistantToolDefinition {
  VrAssistantToolDefinition({
    required this.name,
    required this.description,
    Map<String, Object?> parameterSchema = const <String, Object?>{
      VrAssistantConstants.keySchemaType:
          VrAssistantConstants.keySchemaTypeObject,
      VrAssistantConstants.keySchemaProperties: <String, Object?>{},
    },
    this.handler,
  }) : parameterSchema = VrAssistantContext.snapshotMap(parameterSchema) {
    if (name.trim().isEmpty) {
      throw ArgumentError(
        VrAssistantTranslationConstants.argErrorToolNameEmpty,
      );
    }
  }

  final String name;
  final String description;
  final Map<String, Object?> parameterSchema;
  final VrAssistantToolHandler? handler;

  /// Converts this tool definition to `neomage` / Anthropic `ToolDefinition` map format.
  Map<String, Object?> toNeomageToolMap() => <String, Object?>{
    VrAssistantConstants.keyName: name,
    VrAssistantConstants.keyDescription: description,
    VrAssistantConstants.keyInputSchema: parameterSchema,
  };

  /// Converts this tool definition to OpenAI `tools` function schema format.
  Map<String, Object?> toOpenAiToolMap() => <String, Object?>{
    VrAssistantConstants.keyType: VrAssistantConstants.keyTypeFunction,
    VrAssistantConstants.keyFunction: <String, Object?>{
      VrAssistantConstants.keyName: name,
      VrAssistantConstants.keyDescription: description,
      VrAssistantConstants.keyParameters: parameterSchema,
    },
  };

  /// Converts this tool definition to Gemini `functionDeclarations` item format.
  Map<String, Object?> toGeminiFunctionDeclaration() => <String, Object?>{
    VrAssistantConstants.keyName: name,
    VrAssistantConstants.keyDescription: description,
    VrAssistantConstants.keyParameters: parameterSchema,
  };
}
