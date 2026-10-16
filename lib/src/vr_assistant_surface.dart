import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'vr_assistant_capture.dart';

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
  State<VrAssistantSurface> createState() => _VrAssistantSurfaceState();
}

class _VrAssistantSurfaceState extends State<VrAssistantSurface>
    with WidgetsBindingObserver {
  final _key = GlobalKey();
  VrAssistantCaptureLease? _lease;
  bool _foreground = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    if (widget.active && _foreground) {
      _lease ??= widget.captureController.registerSource(_capture);
    } else {
      _unregister(widget.captureController);
    }
  }

  void _unregister(VrAssistantCaptureController controller) {
    _generation++;
    final lease = _lease;
    if (lease != null) controller.unregisterSource(lease);
    _lease = null;
  }

  @override
  void didUpdateWidget(VrAssistantSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.captureController != widget.captureController ||
        oldWidget.stereo != widget.stereo ||
        oldWidget.active != widget.active) {
      _unregister(oldWidget.captureController);
    }
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  bool _current(int generation) =>
      mounted && widget.active && _foreground && generation == _generation;

  Future<Uint8List?> _capture() async {
    final generation = _generation;
    if (!_current(generation)) return null;
    await WidgetsBinding.instance.endOfFrame;
    if (!_current(generation)) return null;
    final boundary = _key.currentContext?.findRenderObject();
    if (boundary is! _AssistantRenderBoundary ||
        !boundary.hasSize ||
        boundary.size.isEmpty) {
      return null;
    }
    final size = boundary.size;
    final bounds = Rect.fromLTWH(
      0,
      0,
      widget.stereo ? size.width / 2 : size.width,
      size.height,
    );
    final ratio = math.min(
      1.0,
      math.min(768 / bounds.width, 768 / bounds.height),
    );
    final image = await boundary.capture(bounds, pixelRatio: ratio);
    try {
      if (!_current(generation)) return null;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!_current(generation) || data == null) return null;
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unregister(widget.captureController);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _AssistantBoundary(key: _key, child: widget.child);
}

class _AssistantBoundary extends SingleChildRenderObjectWidget {
  const _AssistantBoundary({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _AssistantRenderBoundary();
}

class _AssistantRenderBoundary extends RenderRepaintBoundary {
  Future<ui.Image> capture(Rect bounds, {required double pixelRatio}) {
    assert(!debugNeedsPaint);
    return (layer! as OffsetLayer).toImage(bounds, pixelRatio: pixelRatio);
  }
}
