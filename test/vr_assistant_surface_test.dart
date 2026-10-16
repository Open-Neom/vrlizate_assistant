import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vrlizate_assistant/vrlizate_assistant.dart';

Widget _surface(
  VrAssistantCaptureController controller, {
  bool active = true,
  bool stereo = true,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: VrAssistantSurface(
    captureController: controller,
    active: active,
    stereo: stereo,
    child: const Row(
      children: [
        Expanded(
          child: ColoredBox(color: Color(0xFFFF0000), child: SizedBox.expand()),
        ),
        Expanded(
          child: ColoredBox(color: Color(0xFF0000FF), child: SizedBox.expand()),
        ),
      ],
    ),
  ),
);

Future<Uint8List?> _capture(
  WidgetTester tester,
  VrAssistantCaptureController controller,
) async {
  late Future<Uint8List?> pending;
  await tester.runAsync(() async {
    pending = controller.capture();
  });
  await tester.pump();
  return tester.runAsync<Uint8List?>(() => pending);
}

void main() {
  testWidgets('real composed PNG contains only the left eye', (tester) async {
    final controller = VrAssistantCaptureController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(800, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_surface(controller));
    final bytes = await _capture(tester, controller);
    expect(bytes, isNotNull);
    expect(bytes!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      try {
        expect(frame.image.width, 400);
        expect(frame.image.height, 360);
        final raw = (await frame.image.toByteData())!;
        final pixelOffset = (180 * 400 + 200) * 4;
        expect(raw.getUint8(pixelOffset), greaterThan(220));
        expect(raw.getUint8(pixelOffset + 2), lessThan(50));
      } finally {
        frame.image.dispose();
        codec.dispose();
      }
    });
    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.hasSource, isFalse);
  });

  testWidgets('mono source preserves both sides and bounds allocation to 768', (
    tester,
  ) async {
    final controller = VrAssistantCaptureController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_surface(controller, stereo: false));
    final bytes = await _capture(tester, controller);
    expect(bytes, isNotNull);
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes!);
      final frame = await codec.getNextFrame();
      try {
        expect(frame.image.width, 768);
        expect(frame.image.height, 432);
        final raw = (await frame.image.toByteData())!;
        final leftOffset = (216 * 768 + 100) * 4;
        final rightOffset = (216 * 768 + 668) * 4;
        expect(raw.getUint8(leftOffset), greaterThan(220));
        expect(raw.getUint8(rightOffset + 2), greaterThan(220));
      } finally {
        frame.image.dispose();
        codec.dispose();
      }
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('inactive, background and disposed surfaces cannot be captured', (
    tester,
  ) async {
    final controller = VrAssistantCaptureController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_surface(controller));
    expect(controller.hasSource, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(controller.hasSource, isFalse);
    expect(await controller.capture(), isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.hasSource, isTrue);
    await tester.pumpWidget(_surface(controller, active: false));
    expect(controller.hasSource, isFalse);
    await tester.pumpWidget(_surface(controller));
    expect(controller.hasSource, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.hasSource, isFalse);
  });
}
