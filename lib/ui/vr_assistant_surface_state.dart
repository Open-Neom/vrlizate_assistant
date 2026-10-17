import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../domain/models/vr_assistant_capture_lease.dart';
import '../domain/services/vr_assistant_capture_controller.dart';
import '../utils/constants/vr_assistant_constants.dart';
import 'vr_assistant_boundary.dart';
import 'vr_assistant_render_boundary.dart';
import 'vr_assistant_surface.dart';

/// State implementation for [VrAssistantSurface] managing lifecycle-aware
/// capture lease registration and left-eye stereo bounding.
class VrAssistantSurfaceState extends State<VrAssistantSurface>
    with WidgetsBindingObserver {
  final GlobalKey _key = GlobalKey();
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
    if (boundary is! VrAssistantRenderBoundary ||
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
    final maxDim = VrAssistantConstants.maxCaptureDimension;
    final ratio = math.min(
      1.0,
      math.min(maxDim / bounds.width, maxDim / bounds.height),
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
      VrAssistantBoundary(key: _key, child: widget.child);
}
