import 'dart:typed_data';

/// Callback that captures a local PNG or JPEG snapshot of the active VR surface.
typedef VrAssistantCapture = Future<Uint8List?> Function();

/// An opaque lease that prevents an older route from clearing a newer surface.
class VrAssistantCaptureLease {
  VrAssistantCaptureLease();
}
