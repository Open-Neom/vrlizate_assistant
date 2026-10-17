import '../../utils/constants/vr_assistant_constants.dart';
import 'vr_assistant_context.dart';

/// A provider's answer and optional proposed action.
///
/// The host must validate [action] and [arguments] against its current session
/// and access rules. The assistant package never executes the proposal
/// automatically unless invoked through `VrAssistantToolRegistry`.
class VrAssistantReply {
  VrAssistantReply({
    required this.text,
    this.action,
    Map<String, Object?> arguments = const {},
    this.isError = false,
  }) : arguments = VrAssistantContext.snapshotMap(arguments);

  factory VrAssistantReply.fromJson(Map<String, Object?> json) {
    final textValue =
        json[VrAssistantConstants.keyText] ??
        json[VrAssistantConstants.keyReply] ??
        json[VrAssistantConstants.keyResponse] ??
        '';
    final rawAction = json[VrAssistantConstants.keyAction];
    final rawArgs =
        json[VrAssistantConstants.keyArguments] ??
        json[VrAssistantConstants.keyArgs] ??
        json[VrAssistantConstants.keyInput];
    final argsMap = rawArgs is Map
        ? <String, Object?>{
            for (final entry in rawArgs.entries)
              if (entry.key is String) entry.key as String: entry.value,
          }
        : const <String, Object?>{};
    return VrAssistantReply(
      text: textValue.toString(),
      action: rawAction is String && rawAction.trim().isNotEmpty
          ? rawAction.trim()
          : null,
      arguments: argsMap,
      isError: json[VrAssistantConstants.keyIsError] == true,
    );
  }

  final String text;
  final String? action;
  final Map<String, Object?> arguments;
  final bool isError;

  bool get hasAction => action != null && action!.isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    VrAssistantConstants.keyText: text,
    if (action != null) VrAssistantConstants.keyAction: action,
    if (arguments.isNotEmpty) VrAssistantConstants.keyArguments: arguments,
    VrAssistantConstants.keyIsError: isError,
  };
}
