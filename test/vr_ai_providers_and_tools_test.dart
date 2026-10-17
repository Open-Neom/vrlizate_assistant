import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vrlizate_assistant/vrlizate_assistant.dart';

class _TestNeomageBridge implements VrNeomageAgentBridge {
  Map<String, Object?>? lastPayload;
  Map<String, Object?> nextResponse = const <String, Object?>{};
  int disposals = 0;

  @override
  Future<Map<String, Object?>> sendSpatialQuery(
    Map<String, Object?> payload,
  ) async {
    lastPayload = payload;
    return nextResponse;
  }

  @override
  void dispose() {
    disposals++;
  }
}

VrAssistantContext _sampleContext() => VrAssistantContext(
  experienceId: 'plaza_vr',
  title: 'Plaza Neom',
  details: const <String, Object?>{
    'room': 'lobby',
    'portals': <String>['cinema', 'studio'],
  },
  allowedActions: const <String>{'openRoom'},
);

Uint8List _samplePng() =>
    Uint8List.fromList(const <int>[137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]);

void main() {
  group('VrAssistantToolRegistry', () {
    test('registers tools, builds schemas, validates and executes actions', () async {
      String? openedRoom;
      final registry = VrAssistantToolRegistry(
        initialTools: <VrAssistantToolDefinition>[
          VrAssistantToolDefinition(
            name: 'openRoom',
            description: 'Opens a VR room by ID.',
            parameterSchema: const <String, Object?>{
              'type': 'object',
              'properties': <String, Object?>{
                'room': <String, Object?>{'type': 'string'},
              },
              'required': <String>['room'],
            },
            handler: (args) {
              openedRoom = args['room'] as String?;
              return 'opened:$openedRoom';
            },
          ),
          VrAssistantToolDefinition(
            name: 'muteAudio',
            description: 'Mutes spatial audio.',
            handler: (_) => 'muted',
          ),
        ],
      );

      expect(registry.contains('openRoom'), isTrue);
      expect(registry.allowedActions, <String>{'openRoom', 'muteAudio'});

      final openAiTools = registry.toOpenAiTools(
        allowedActions: const <String>{'openRoom'},
      );
      expect(openAiTools, hasLength(1));
      expect(openAiTools.single['type'], 'function');

      final neomageTools = registry.toNeomageTools(
        allowedActions: const <String>{'openRoom'},
      );
      expect(neomageTools, hasLength(1));
      expect(neomageTools.single['name'], 'openRoom');
      expect(neomageTools.single['input_schema'], isA<Map<String, Object?>>());

      final allowedReply = VrAssistantReply(
        text: 'Abriendo cine',
        action: 'openRoom',
        arguments: const <String, Object?>{'room': 'cinema'},
      );
      expect(
        registry.isActionAllowed(
          allowedReply,
          allowedActions: const <String>{'openRoom'},
        ),
        isTrue,
      );
      final result = await registry.executeReplyAction(
        allowedReply,
        allowedActions: const <String>{'openRoom'},
      );
      expect(result, 'opened:cinema');
      expect(openedRoom, 'cinema');

      final forbiddenReply = VrAssistantReply(
        text: 'Silenciando',
        action: 'muteAudio',
      );
      expect(
        registry.isActionAllowed(
          forbiddenReply,
          allowedActions: const <String>{'openRoom'},
        ),
        isFalse,
      );
      expect(
        () => registry.executeReplyAction(
          forbiddenReply,
          allowedActions: const <String>{'openRoom'},
        ),
        throwsStateError,
      );
    });
  });

  group('VrUniversalAiProvider', () {
    test(
      'formats OpenAI request with multimodal PNG snapshot and parses tool_calls',
      () async {
        Uri? capturedUri;
        Map<String, String>? capturedHeaders;
        Map<String, Object?>? capturedBody;

        final registry = VrAssistantToolRegistry(
          initialTools: <VrAssistantToolDefinition>[
            VrAssistantToolDefinition(
              name: 'openRoom',
              description: 'Opens a VR room.',
            ),
          ],
        );

        final provider = VrUniversalAiProvider(
          config: VrAiProviderConfig.openAi(
            apiKey: 'sk-test-openai',
            modelId: 'gpt-4o-mini',
          ),
          toolRegistry: registry,
          httpHandler: (uri, headers, body) async {
            capturedUri = uri;
            capturedHeaders = headers;
            capturedBody = jsonDecode(body) as Map<String, Object?>;
            return (
              statusCode: 200,
              body: jsonEncode(<String, Object?>{
                'choices': <Object?>[
                  <String, Object?>{
                    'message': <String, Object?>{
                      'content': 'Te llevo al cine.',
                      'tool_calls': <Object?>[
                        <String, Object?>{
                          'type': 'function',
                          'function': <String, Object?>{
                            'name': 'openRoom',
                            'arguments': jsonEncode(<String, Object?>{
                              'room': 'cinema',
                            }),
                          },
                        },
                      ],
                    },
                  },
                ],
              }),
            );
          },
        );
        addTearDown(provider.dispose);

        final png = _samplePng();
        final reply = await provider.respond(
          VrAssistantRequest(
            text: 'Llévame al cine',
            context: _sampleContext(),
            imageBytes: png,
            imageMimeType: VrAssistantConstants.mimePng,
          ),
        );

        expect(capturedUri.toString(), VrAssistantConstants.defaultOpenAiEndpoint);
        expect(
          capturedHeaders![VrAssistantConstants.headerAuthorization],
          'Bearer sk-test-openai',
        );
        expect(capturedBody!['model'], 'gpt-4o-mini');
        expect(capturedBody!['tools'], isA<List<Object?>>());

        final messages = capturedBody!['messages']! as List<Object?>;
        final userMessage = messages.last as Map<String, Object?>;
        final userContent = userMessage['content']! as List<Object?>;
        final imagePart = userContent.last as Map<String, Object?>;
        expect(imagePart['type'], 'image_url');
        final imageUrl =
            (imagePart['image_url']! as Map<String, Object?>)['url']! as String;
        expect(
          imageUrl,
          'data:image/png;base64,${base64Encode(png)}',
        );

        expect(reply.isError, isFalse);
        expect(reply.text, 'Te llevo al cine.');
        expect(reply.action, 'openRoom');
        expect(reply.arguments, const <String, Object?>{'room': 'cinema'});
      },
    );

    test(
      'formats Gemini request with inlineData snapshot and parses functionCall',
      () async {
        Uri? capturedUri;
        Map<String, String>? capturedHeaders;
        Map<String, Object?>? capturedBody;

        final provider = VrUniversalAiProvider(
          config: VrAiProviderConfig.gemini(
            apiKey: 'gem-key-123',
            modelId: 'gemini-2.5-flash',
          ),
          httpHandler: (uri, headers, body) async {
            capturedUri = uri;
            capturedHeaders = headers;
            capturedBody = jsonDecode(body) as Map<String, Object?>;
            return (
              statusCode: 200,
              body: jsonEncode(<String, Object?>{
                'candidates': <Object?>[
                  <String, Object?>{
                    'content': <String, Object?>{
                      'parts': <Object?>[
                        <String, Object?>{
                          'text': 'Veo la entrada al estudio.',
                        },
                        <String, Object?>{
                          'functionCall': <String, Object?>{
                            'name': 'openRoom',
                            'args': <String, Object?>{'room': 'studio'},
                          },
                        },
                      ],
                    },
                  },
                ],
              }),
            );
          },
        );
        addTearDown(provider.dispose);

        final png = _samplePng();
        final reply = await provider.respond(
          VrAssistantRequest(
            text: '¿Qué tengo enfrente?',
            context: _sampleContext(),
            imageBytes: png,
            imageMimeType: VrAssistantConstants.mimePng,
          ),
        );

        expect(capturedUri!.queryParameters['key'], 'gem-key-123');
        expect(
          capturedHeaders![VrAssistantConstants.headerGeminiApiKey],
          'gem-key-123',
        );
        final contents = capturedBody!['contents']! as List<Object?>;
        final parts =
            (contents.single as Map<String, Object?>)['parts']! as List<Object?>;
        final inlineData =
            (parts.last as Map<String, Object?>)['inlineData']!
                as Map<String, Object?>;
        expect(inlineData['mimeType'], 'image/png');
        expect(inlineData['data'], base64Encode(png));

        expect(reply.isError, isFalse);
        expect(reply.text, 'Veo la entrada al estudio.');
        expect(reply.action, 'openRoom');
        expect(reply.arguments, const <String, Object?>{'room': 'studio'});
      },
    );

    test(
      'formats Anthropic request with base64 image block and parses tool_use',
      () async {
        Map<String, String>? capturedHeaders;
        Map<String, Object?>? capturedBody;

        final provider = VrUniversalAiProvider(
          config: VrAiProviderConfig.anthropic(apiKey: 'ant-key-999'),
          httpHandler: (uri, headers, body) async {
            capturedHeaders = headers;
            capturedBody = jsonDecode(body) as Map<String, Object?>;
            return (
              statusCode: 200,
              body: jsonEncode(<String, Object?>{
                'content': <Object?>[
                  <String, Object?>{
                    'type': 'text',
                    'text': 'Abriendo la sala solicitada.',
                  },
                  <String, Object?>{
                    'type': 'tool_use',
                    'id': 'toolu_01',
                    'name': 'openRoom',
                    'input': <String, Object?>{'room': 'cinema'},
                  },
                ],
              }),
            );
          },
        );
        addTearDown(provider.dispose);

        final png = _samplePng();
        final reply = await provider.respond(
          VrAssistantRequest(
            text: 'Abre el cine',
            context: _sampleContext(),
            imageBytes: png,
            imageMimeType: VrAssistantConstants.mimePng,
          ),
        );

        expect(
          capturedHeaders![VrAssistantConstants.headerAnthropicApiKey],
          'ant-key-999',
        );
        expect(
          capturedHeaders![VrAssistantConstants.headerAnthropicVersion],
          VrAssistantConstants.defaultAnthropicVersion,
        );
        final messages = capturedBody!['messages']! as List<Object?>;
        final content =
            (messages.single as Map<String, Object?>)['content']!
                as List<Object?>;
        final imageBlock = content.first as Map<String, Object?>;
        expect(imageBlock['type'], 'image');
        final source = imageBlock['source']! as Map<String, Object?>;
        expect(source['type'], 'base64');
        expect(source['media_type'], 'image/png');
        expect(source['data'], base64Encode(png));

        expect(reply.isError, isFalse);
        expect(reply.text, 'Abriendo la sala solicitada.');
        expect(reply.action, 'openRoom');
        expect(reply.arguments, const <String, Object?>{'room': 'cinema'});
      },
    );

    test(
      'formats Ollama request with images array and parses JSON structured reply',
      () async {
        Map<String, Object?>? capturedBody;

        final provider = VrUniversalAiProvider(
          config: VrAiProviderConfig.ollama(modelId: 'llama3.2-vision'),
          httpHandler: (uri, headers, body) async {
            capturedBody = jsonDecode(body) as Map<String, Object?>;
            return (
              statusCode: 200,
              body: jsonEncode(<String, Object?>{
                'message': <String, Object?>{
                  'role': 'assistant',
                  'content':
                      '```json\n{"text":"Entrando al cine","action":"openRoom","arguments":{"room":"cinema"}}\n```',
                },
              }),
            );
          },
        );
        addTearDown(provider.dispose);

        final png = _samplePng();
        final reply = await provider.respond(
          VrAssistantRequest(
            text: 'Entrar al cine',
            context: _sampleContext(),
            imageBytes: png,
            imageMimeType: VrAssistantConstants.mimePng,
          ),
        );

        expect(capturedBody!['model'], 'llama3.2-vision');
        expect(capturedBody!['stream'], isFalse);
        final messages = capturedBody!['messages']! as List<Object?>;
        final userMessage = messages.last as Map<String, Object?>;
        expect(userMessage['images'], <String>[base64Encode(png)]);

        expect(reply.isError, isFalse);
        expect(reply.text, 'Entrando al cine');
        expect(reply.action, 'openRoom');
        expect(reply.arguments, const <String, Object?>{'room': 'cinema'});
      },
    );
  });

  group('VrNeomageAssistantProvider', () {
    test(
      'bridges spatial context, tools, and image snapshot into Neomage format and executes tool via controller',
      () async {
        final bridge = _TestNeomageBridge()
          ..nextResponse = <String, Object?>{
            'role': 'assistant',
            'content': <Object?>[
              <String, Object?>{
                'type': 'text',
                'text': 'Neomage te lleva al estudio.',
              },
              <String, Object?>{
                'type': 'tool_use',
                'id': 'neomage_call_1',
                'name': 'openRoom',
                'input': <String, Object?>{'room': 'studio'},
              },
            ],
          };

        String? executedRoom;
        final registry = VrAssistantToolRegistry(
          initialTools: <VrAssistantToolDefinition>[
            VrAssistantToolDefinition(
              name: 'openRoom',
              description: 'Opens a VR room.',
              handler: (args) {
                executedRoom = args['room'] as String?;
                return executedRoom;
              },
            ),
          ],
        );

        final provider = VrNeomageAssistantProvider(
          bridge: bridge,
          toolRegistry: registry,
          disposeBridge: true,
        );
        final controller = VrAssistantController(
          provider: provider,
          toolRegistry: registry,
        );

        final png = _samplePng();
        final reply = await controller.ask(
          'Vamos al estudio',
          context: _sampleContext(),
          includeImage: true,
          capture: () async => png,
        );

        expect(reply, isNotNull);
        expect(reply!.isError, isFalse);
        expect(reply.text, 'Neomage te lleva al estudio.');
        expect(reply.action, 'openRoom');
        expect(reply.arguments, const <String, Object?>{'room': 'studio'});
        expect(controller.state, VrAssistantState.responding);

        final payload = bridge.lastPayload!;
        expect(payload['model'], VrAssistantConstants.defaultNeomageModel);
        expect(payload['tools'], isA<List<Object?>>());
        final messages = payload['messages']! as List<Object?>;
        final userMessage = messages.single as Map<String, Object?>;
        final blocks = userMessage['content']! as List<Object?>;
        expect(blocks, hasLength(2));
        expect((blocks.last as Map<String, Object?>)['type'], 'image');

        final actionResult = await controller.executeLastAction(
          allowedActions: const <String>{'openRoom'},
        );
        expect(actionResult, 'studio');
        expect(executedRoom, 'studio');
        expect(controller.state, VrAssistantState.responding);

        controller.dispose();
        expect(bridge.disposals, 1);
      },
    );
  });
}
