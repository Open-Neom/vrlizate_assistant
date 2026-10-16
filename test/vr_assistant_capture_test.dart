import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vrlizate_assistant/vrlizate_assistant.dart';

void main() {
  testWidgets(
    'new lease invalidates pending bytes and older lease cannot clear it',
    (tester) async {
      final controller = VrAssistantCaptureController();
      addTearDown(controller.dispose);
      final oldImage = Completer<Uint8List?>();
      final oldLease = controller.registerSource(() => oldImage.future);
      final first = controller.capture();
      expect(await controller.capture(), isNull);
      final newLease = controller.registerSource(
        () async => Uint8List.fromList([2]),
      );
      expect(await first, isNull);
      controller.unregisterSource(oldLease);
      expect(controller.hasSource, isTrue);
      expect(await controller.capture(), isNull);
      oldImage.complete(Uint8List.fromList([1]));
      await tester.pump();
      expect(await controller.capture(), [2]);
      controller.unregisterSource(newLease);
      expect(controller.hasSource, isFalse);
      expect(await controller.capture(), isNull);
    },
  );

  testWidgets('timeout returns null while retaining single actual readback', (
    tester,
  ) async {
    final controller = VrAssistantCaptureController(
      timeout: const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);
    final image = Completer<Uint8List?>();
    var captures = 0;
    controller.registerSource(() {
      captures++;
      return image.future;
    });
    final pending = controller.capture();
    await tester.pump(const Duration(seconds: 2));
    expect(await pending, isNull);
    expect(controller.busy, isTrue);
    expect(await controller.capture(), isNull);
    expect(captures, 1);
    image.complete(Uint8List.fromList([1]));
    await tester.pump();
    expect(controller.busy, isFalse);
  });

  testWidgets(
    'disposal invalidates active capture and source exceptions are bounded',
    (tester) async {
      final controller = VrAssistantCaptureController();
      controller.registerSource(() async => throw StateError('sensitive'));
      expect(await controller.capture(), isNull);
      expect(controller.busy, isFalse);
      final image = Completer<Uint8List?>();
      controller.registerSource(() => image.future);
      final pending = controller.capture();
      controller.dispose();
      expect(await pending, isNull);
      image.complete(Uint8List.fromList([1]));
      await tester.pump();
      expect(controller.hasSource, isFalse);
      expect(await controller.capture(), isNull);
    },
  );
}
