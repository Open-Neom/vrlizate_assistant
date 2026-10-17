import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// Render object that captures a bounded region of the composed layer tree.
class VrAssistantRenderBoundary extends RenderRepaintBoundary {
  Future<ui.Image> capture(Rect bounds, {required double pixelRatio}) {
    assert(!debugNeedsPaint);
    return (layer! as OffsetLayer).toImage(bounds, pixelRatio: pixelRatio);
  }
}
