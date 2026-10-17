import 'package:flutter/widgets.dart';

import 'vr_assistant_render_boundary.dart';

/// Single-child render object widget that hosts a [VrAssistantRenderBoundary].
class VrAssistantBoundary extends SingleChildRenderObjectWidget {
  const VrAssistantBoundary({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      VrAssistantRenderBoundary();
}
