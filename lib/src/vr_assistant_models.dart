import 'dart:typed_data';

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
  }) : details = _snapshotMap(details),
       allowedActions = Set<String>.unmodifiable(allowedActions);

  final String experienceId;
  final String title;
  final Map<String, Object?> details;
  final Set<String> allowedActions;
}

class VrAssistantRequest {
  VrAssistantRequest({
    required this.text,
    required this.context,
    Uint8List? imageBytes,
    this.imageMimeType,
  }) : imageBytes = imageBytes == null
           ? null
           : Uint8List.fromList(imageBytes).asUnmodifiableView() {
    if ((imageBytes == null) != (imageMimeType == null)) {
      throw ArgumentError(
        'Image bytes and MIME type must be supplied together.',
      );
    }
    if (imageMimeType != null &&
        imageMimeType != 'image/png' &&
        imageMimeType != 'image/jpeg') {
      throw ArgumentError('Only PNG and JPEG images are supported.');
    }
  }

  final String text;
  final VrAssistantContext context;
  final Uint8List? imageBytes;
  final String? imageMimeType;
}

/// A provider's answer and optional proposed action.
///
/// The host must validate [action] and [arguments] against its current session
/// and access rules. The assistant package never executes the proposal.
class VrAssistantReply {
  VrAssistantReply({
    required this.text,
    this.action,
    Map<String, Object?> arguments = const {},
    this.isError = false,
  }) : arguments = _snapshotMap(arguments);

  final String text;
  final String? action;
  final Map<String, Object?> arguments;
  final bool isError;
}

/// The host supplies an implementation, credentials and any network transport.
abstract interface class VrAssistantProvider {
  Future<VrAssistantReply> respond(VrAssistantRequest request);
  void dispose();
}

Map<String, Object?> _snapshotMap(Map<String, Object?> source) {
  var entries = 0;
  Object? copy(Object? value, int depth) {
    if (++entries > 4096 || depth > 12) {
      throw ArgumentError('Assistant context exceeds collection limits.');
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
          throw ArgumentError('Assistant context map keys must be strings.');
        }
        result[entry.key as String] = copy(entry.value, depth + 1);
      }
      return Map<String, Object?>.unmodifiable(result);
    }
    throw ArgumentError('Assistant context requires finite JSON-like values.');
  }

  return copy(source, 0)! as Map<String, Object?>;
}
