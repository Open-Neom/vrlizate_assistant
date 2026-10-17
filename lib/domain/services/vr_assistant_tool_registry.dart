import 'dart:convert';

import '../../utils/constants/vr_assistant_constants.dart';
import '../../utils/constants/vr_assistant_translation_constants.dart';
import '../models/vr_assistant_context.dart';
import '../models/vr_assistant_reply.dart';
import '../models/vr_assistant_tool_definition.dart';

/// Registry for spatial tools and actions that an AI assistant or `neomage`
/// agent can propose and execute within a VRlizate experience.
class VrAssistantToolRegistry {
  VrAssistantToolRegistry({
    Iterable<VrAssistantToolDefinition> initialTools = const [],
  }) {
    for (final tool in initialTools) {
      register(tool);
    }
  }

  final Map<String, VrAssistantToolDefinition> _tools =
      <String, VrAssistantToolDefinition>{};

  /// Registers or replaces a spatial tool definition.
  void register(VrAssistantToolDefinition tool) {
    _tools[tool.name] = tool;
  }

  /// Unregisters a spatial tool by name.
  bool unregister(String name) => _tools.remove(name) != null;

  /// Clears all registered spatial tools.
  void clear() => _tools.clear();

  /// Looks up a spatial tool definition by [name].
  VrAssistantToolDefinition? get(String name) => _tools[name];

  /// Whether a tool with [name] is registered.
  bool contains(String name) => _tools.containsKey(name);

  /// Unmodifiable list of all registered tool definitions.
  List<VrAssistantToolDefinition> get tools =>
      List<VrAssistantToolDefinition>.unmodifiable(_tools.values);

  /// Unmodifiable set of all registered tool names.
  Set<String> get allowedActions => Set<String>.unmodifiable(_tools.keys);

  /// Returns a copy of [context] whose `allowedActions` includes all tools
  /// registered in this registry.
  VrAssistantContext enrichContext(VrAssistantContext context) =>
      VrAssistantContext(
        experienceId: context.experienceId,
        title: context.title,
        details: context.details,
        allowedActions: <String>{...context.allowedActions, ..._tools.keys},
      );

  /// Filters registered tools by [allowedActions] when provided.
  List<VrAssistantToolDefinition> resolveTools({Set<String>? allowedActions}) {
    if (allowedActions == null || allowedActions.isEmpty) {
      return tools;
    }
    return List<VrAssistantToolDefinition>.unmodifiable(
      _tools.values.where((tool) => allowedActions.contains(tool.name)),
    );
  }

  /// Converts active tools to `neomage` / Anthropic `ToolDefinition` maps.
  List<Map<String, Object?>> toNeomageTools({Set<String>? allowedActions}) =>
      List<Map<String, Object?>>.unmodifiable(
        resolveTools(
          allowedActions: allowedActions,
        ).map((tool) => tool.toNeomageToolMap()),
      );

  /// Converts active tools to OpenAI function tool maps.
  List<Map<String, Object?>> toOpenAiTools({Set<String>? allowedActions}) =>
      List<Map<String, Object?>>.unmodifiable(
        resolveTools(
          allowedActions: allowedActions,
        ).map((tool) => tool.toOpenAiToolMap()),
      );

  /// Converts active tools to Gemini `functionDeclarations` maps.
  List<Map<String, Object?>> toGeminiFunctionDeclarations({
    Set<String>? allowedActions,
  }) => List<Map<String, Object?>>.unmodifiable(
    resolveTools(
      allowedActions: allowedActions,
    ).map((tool) => tool.toGeminiFunctionDeclaration()),
  );

  /// Builds a concise prompt section describing available spatial tools.
  String buildPromptInstructions({Set<String>? allowedActions}) {
    final activeTools = resolveTools(allowedActions: allowedActions);
    if (activeTools.isEmpty) return '';
    final serialized = jsonEncode(
      activeTools
          .map(
            (tool) => <String, Object?>{
              VrAssistantConstants.keyName: tool.name,
              VrAssistantConstants.keyDescription: tool.description,
              VrAssistantConstants.keyParameters: tool.parameterSchema,
            },
          )
          .toList(growable: false),
    );
    return '${VrAssistantConstants.registeredToolsHeaderPrefix}$serialized';
  }

  /// Validates whether [reply.action] is registered and permitted by [allowedActions].
  bool isActionAllowed(VrAssistantReply reply, {Set<String>? allowedActions}) {
    final action = reply.action;
    if (action == null || action.isEmpty) return false;
    if (!_tools.containsKey(action)) return false;
    if (allowedActions != null && !allowedActions.contains(action)) {
      return false;
    }
    return true;
  }

  /// Validates and executes the tool proposed in [reply].
  ///
  /// Throws [StateError] if the action is not allowed or has no handler.
  Future<Object?> executeReplyAction(
    VrAssistantReply reply, {
    Set<String>? allowedActions,
  }) async {
    final action = reply.action;
    if (action == null || action.isEmpty) {
      throw StateError(VrAssistantTranslationConstants.errorToolNotFound);
    }
    if (allowedActions != null && !allowedActions.contains(action)) {
      throw StateError(VrAssistantTranslationConstants.errorActionNotAllowed);
    }
    final tool = _tools[action];
    if (tool == null || tool.handler == null) {
      throw StateError(VrAssistantTranslationConstants.errorToolNotFound);
    }
    return await tool.handler!(reply.arguments);
  }

  /// Safely attempts to execute [reply.action], returning `true` when executed.
  Future<bool> tryExecuteReplyAction(
    VrAssistantReply reply, {
    Set<String>? allowedActions,
  }) async {
    if (!isActionAllowed(reply, allowedActions: allowedActions)) return false;
    final tool = _tools[reply.action!];
    if (tool?.handler == null) return false;
    await tool!.handler!(reply.arguments);
    return true;
  }
}
