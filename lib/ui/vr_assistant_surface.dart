import 'package:flutter/widgets.dart';

import '../domain/services/vr_assistant_capture_controller.dart';
import 'vr_assistant_surface_state.dart';

/// A local, opt-in snapshot source for the host's currently visible experience.
///
/// The host must set [active] to false when another route/modal owns the view.
/// Stereo surfaces capture the left eye before GPU readback allocation. Both
/// dimensions are bounded to 768 pixels, without upscaling or adding a camera.
/// Native/external textures still require validation on each target platform.
class VrAssistantSurface extends StatefulWidget {
  const VrAssistantSurface({
    super.key,
    required this.captureController,
    required this.child,
    this.active = true,
    this.stereo = true,
  });

  final VrAssistantCaptureController captureController;
  final Widget child;
  final bool active;
  final bool stereo;

  @override
  State<VrAssistantSurface> createState() => VrAssistantSurfaceState();
}
