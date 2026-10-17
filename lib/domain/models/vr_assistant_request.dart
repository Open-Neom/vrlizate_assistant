import 'dart:typed_data';

import '../../utils/constants/vr_assistant_constants.dart';
import '../../utils/constants/vr_assistant_translation_constants.dart';
import 'vr_assistant_context.dart';

/// An immutable spatial query combining user prompt, 3D scene context, and
/// an optional PNG/JPEG viewport snapshot.
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
        VrAssistantTranslationConstants.argErrorImageBytesAndMimeTogether,
      );
    }
    if (imageMimeType != null &&
        imageMimeType != VrAssistantConstants.mimePng &&
        imageMimeType != VrAssistantConstants.mimeJpeg) {
      throw ArgumentError(
        VrAssistantTranslationConstants.argErrorSupportedImageFormats,
      );
    }
  }

  final String text;
  final VrAssistantContext context;
  final Uint8List? imageBytes;
  final String? imageMimeType;

  bool get hasImage => imageBytes != null && imageMimeType != null;
}
