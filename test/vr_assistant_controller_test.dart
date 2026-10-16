import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vrlizate_assistant/vrlizate_assistant.dart';

class _Provider implements VrAssistantProvider {
  final requests = <VrAssistantRequest>[];
  final pending = <Completer<VrAssistantReply>>[];
  int disposals = 0;

  @override
  Future<VrAssistantReply> respond(VrAssistantRequest request) {
    requests.add(request);
    final response = Completer<VrAssistantReply>();
    pending.add(response);
    return response.future;
  }

  @override
  void dispose() => disposals++;
}

VrAssistantContext _context() => VrAssistantContext(
  experienceId: 'home',
  title: 'Plaza',
  allowedActions: {'openRoom'},
);

void main() {
  test('context and requests detach mutable nested state and image bytes', () {
    final position = <Object?>[1, 2, 3];
    final world = <String, Object?>{'position': position};
    final actions = {'openRoom'};
    final context = VrAssistantContext(
      experienceId: 'home',
      title: 'Plaza',
      details: {'world': world},
      allowedActions: actions,
    );
    position[0] = 99;
    world.clear();
    actions.clear();
    final storedWorld = context.details['world']! as Map<String, Object?>;
    expect(storedWorld['position'], [1, 2, 3]);
    expect(context.allowedActions, {'openRoom'});
    expect(() => context.details.clear(), throwsUnsupportedError);
    expect(() => storedWorld.clear(), throwsUnsupportedError);
    expect(
      () => (storedWorld['position']! as List<Object?>).clear(),
      throwsUnsupportedError,
    );
    final bytes = Uint8List.fromList([1, 2, 3]);
    final request = VrAssistantRequest(
      text: 'Ayuda',
      context: context,
      imageBytes: bytes,
      imageMimeType: 'image/png',
    );
    bytes[0] = 9;
    expect(request.imageBytes, [1, 2, 3]);
    expect(() => request.imageBytes![0] = 8, throwsUnsupportedError);
  });

  testWidgets(
    'only one provider request is in flight and actions stay proposals',
    (tester) async {
      final provider = _Provider();
      final controller = VrAssistantController(provider: provider);
      addTearDown(controller.dispose);
      final first = controller.ask('Ayúdame', context: _context());
      expect(controller.busy, isTrue);
      expect(
        await controller.ask('Otra consulta', context: _context()),
        isNull,
      );
      expect(provider.requests, hasLength(1));
      final reply = VrAssistantReply(
        text: 'Puedes ir al cine',
        action: 'openRoom',
        arguments: {'room': 'cinema'},
      );
      provider.pending.single.complete(reply);
      await tester.pump();
      expect(await first, same(reply));
      expect(controller.lastReply, same(reply));
      expect(controller.busy, isFalse);
      expect(controller.status, 'Respuesta lista');
    },
  );

  testWidgets('cancel discards late results but keeps real operation bounded', (
    tester,
  ) async {
    final provider = _Provider();
    final controller = VrAssistantController(provider: provider);
    addTearDown(controller.dispose);
    final first = controller.ask('Primera', context: _context());
    controller.cancel();
    expect(await first, isNull);
    expect(controller.busy, isTrue);
    expect(await controller.ask('Solapada', context: _context()), isNull);
    provider.pending.first.complete(VrAssistantReply(text: 'Respuesta vieja'));
    await tester.pump();
    expect(controller.lastReply, isNull);
    expect(controller.busy, isFalse);
    final second = controller.ask('Nueva', context: _context());
    provider.pending.last.complete(VrAssistantReply(text: 'Respuesta nueva'));
    await tester.pump();
    expect((await second)!.text, 'Respuesta nueva');
    expect(provider.requests, hasLength(2));
  });

  testWidgets('request timeout never starts a second underlying request', (
    tester,
  ) async {
    final provider = _Provider();
    final controller = VrAssistantController(
      provider: provider,
      requestTimeout: const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);
    final pending = controller.ask('Ayuda', context: _context());
    await tester.pump(const Duration(seconds: 2));
    final timeoutReply = await pending;
    expect(timeoutReply!.isError, isTrue);
    expect(controller.busy, isTrue);
    expect(await controller.ask('De nuevo', context: _context()), isNull);
    provider.pending.single.complete(VrAssistantReply(text: 'Demasiado tarde'));
    await tester.pump();
    expect(controller.busy, isFalse);
    expect(controller.lastReply, same(timeoutReply));
    expect(provider.requests, hasLength(1));
  });

  testWidgets('capture timeout discards image and never calls the provider', (
    tester,
  ) async {
    final provider = _Provider();
    final controller = VrAssistantController(
      provider: provider,
      captureTimeout: const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);
    final image = Completer<Uint8List?>();
    final pending = controller.ask(
      '¿Qué veo?',
      context: _context(),
      includeImage: true,
      capture: () => image.future,
    );
    await tester.pump(const Duration(seconds: 2));
    expect((await pending)!.isError, isTrue);
    expect(controller.busy, isTrue);
    image.complete(Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]));
    await tester.pump();
    expect(controller.busy, isFalse);
    expect(provider.requests, isEmpty);
  });

  testWidgets(
    'text-only does not capture; explicit visual request includes PNG',
    (tester) async {
      final provider = _Provider();
      final controller = VrAssistantController(provider: provider);
      addTearDown(controller.dispose);
      var captures = 0;
      Future<Uint8List?> capture() async {
        captures++;
        return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      }

      final textOnly = controller.ask(
        'Ayuda',
        context: _context(),
        capture: capture,
      );
      expect(captures, 0);
      expect(provider.requests.single.imageBytes, isNull);
      provider.pending.single.complete(VrAssistantReply(text: 'Lista'));
      await tester.pump();
      await textOnly;
      final visual = controller.ask(
        '¿Qué veo?',
        context: _context(),
        capture: capture,
        includeImage: true,
      );
      await tester.pump();
      expect(captures, 1);
      expect(provider.requests.last.imageMimeType, 'image/png');
      expect(provider.requests.last.imageBytes, isNotEmpty);
      provider.pending.last.complete(VrAssistantReply(text: 'La plaza'));
      await tester.pump();
      expect((await visual)!.text, 'La plaza');
    },
  );

  testWidgets('invalid prompts and oversized images never reach provider', (
    tester,
  ) async {
    final provider = _Provider();
    final controller = VrAssistantController(provider: provider);
    addTearDown(controller.dispose);
    expect((await controller.ask('  ', context: _context()))!.isError, isTrue);
    expect(
      (await controller.ask('x' * 4001, context: _context()))!.isError,
      isTrue,
    );
    final image = controller.ask(
      'Ver',
      context: _context(),
      includeImage: true,
      capture: () async => Uint8List(VrAssistantController.maxImageBytes + 1),
    );
    await tester.pump();
    expect((await image)!.isError, isTrue);
    expect(provider.requests, isEmpty);
  });

  testWidgets('dispose resolves caller and suppresses late notifications', (
    tester,
  ) async {
    final provider = _Provider();
    final controller = VrAssistantController(provider: provider);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final pending = controller.ask('Ayuda', context: _context());
    controller.dispose();
    final countAfterDispose = notifications;
    expect(await pending, isNull);
    provider.pending.single.completeError(
      StateError('sensitive provider error'),
    );
    await tester.pump();
    expect(notifications, countAfterDispose);
    expect(provider.disposals, 1);
    expect(await controller.ask('Después', context: _context()), isNull);
  });
}
