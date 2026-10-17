import '../../utils/constants/vr_assistant_constants.dart';
import '../../utils/constants/vr_assistant_translation_constants.dart';

/// A detached snapshot of information the host has chosen to share.
///
/// Details accept JSON-like scalar values, maps with string keys and lists.
/// Copying nested collections prevents world updates from changing an in-flight
/// request. This is a context declaration, not an authorization mechanism.
class VrAssistantContext {
  VrAssistantContext({
    required this.experienceId,
    required this.title,
    Map<String, Object?> details = const {},
    Set<String> allowedActions = const {},
  }) : details = snapshotMap(details),
       allowedActions = Set<String>.unmodifiable(allowedActions);

  final String experienceId;
  final String title;
  final Map<String, Object?> details;
  final Set<String> allowedActions;

  /// Returns a serializable JSON map representation of this spatial context.
  Map<String, Object?> toJson() => <String, Object?>{
    VrAssistantConstants.keyExperienceId: experienceId,
    VrAssistantConstants.keyTitle: title,
    VrAssistantConstants.keyDetails: details,
    VrAssistantConstants.keyAllowedActions: allowedActions.toList(
      growable: false,
    ),
  };

  /// Deep-copies and freezes a JSON-like map within bounded depth and size.
  static Map<String, Object?> snapshotMap(Map<String, Object?> source) {
    var entries = 0;
    Object? copy(Object? value, int depth) {
      if (++entries > VrAssistantConstants.maxContextEntries ||
          depth > VrAssistantConstants.maxContextDepth) {
        throw ArgumentError(
          VrAssistantTranslationConstants.argErrorContextLimits,
        );
      }
      if (value == null || value is bool || value is String || value is int) {
        return value;
      }
      if (value is double && value.isFinite) return value;
      if (value is List) {
        return List<Object?>.unmodifiable([
          for (final entry in value) copy(entry, depth + 1),
        ]);
      }
      if (value is Map) {
        final result = <String, Object?>{};
        for (final entry in value.entries) {
          if (entry.key is! String) {
            throw ArgumentError(
              VrAssistantTranslationConstants.argErrorContextMapKeys,
            );
          }
          result[entry.key as String] = copy(entry.value, depth + 1);
        }
        return Map<String, Object?>.unmodifiable(result);
      }
      throw ArgumentError(
        VrAssistantTranslationConstants.argErrorContextFiniteValues,
      );
    }

    return copy(source, 0)! as Map<String, Object?>;
  }
}
