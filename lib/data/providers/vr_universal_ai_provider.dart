import 'dart:convert';
import 'dart:io';

import '../../domain/models/vr_ai_provider_config.dart';
import '../../domain/models/vr_assistant_reply.dart';
import '../../domain/models/vr_assistant_request.dart';
import '../../domain/services/vr_assistant_provider.dart';
import '../../domain/services/vr_assistant_tool_registry.dart';
import '../../domain/services/vr_neomage_agent_bridge.dart';
import '../../utils/constants/vr_assistant_constants.dart';
import '../../utils/constants/vr_assistant_translation_constants.dart';
import '../../utils/enums/vr_ai_provider_type.dart';

/// Injectable HTTP transport signature for testing or custom host proxies.
typedef VrAiHttpHandler =
    Future<({int statusCode, String body})> Function(
      Uri uri,
      Map<String, String> headers,
      String body,
    );

/// Ready-to-use universal AI provider supporting OpenAI-compatible APIs
/// (OpenAI, Groq, DeepSeek, etc.), Google Gemini, Anthropic Claude, and Ollama.
class VrUniversalAiProvider implements VrAssistantProvider {
  VrUniversalAiProvider({
    required this.config,
    this.toolRegistry,
    VrAiHttpHandler? httpHandler,
    HttpClient? httpClient,
  }) : _httpHandler = httpHandler,
       _httpClient = httpHandler == null ? (httpClient ?? HttpClient()) : null,
       _ownsHttpClient = httpHandler == null && httpClient == null;

  final VrAiProviderConfig config;
  final VrAssistantToolRegistry? toolRegistry;
  final VrAiHttpHandler? _httpHandler;
  final HttpClient? _httpClient;
  final bool _ownsHttpClient;
  bool _disposed = false;

  @override
  Future<VrAssistantReply> respond(VrAssistantRequest request) async {
    if (_disposed) {
      return VrAssistantReply(
        text: VrAssistantTranslationConstants.errorRequestFailed,
        isError: true,
      );
    }

    try {
      final uri = buildEndpointUri();
      final headers = buildHeaders();
      final payload = buildRequestPayload(request);
      final encodedBody = jsonEncode(payload);

      final response = _httpHandler != null
          ? await _httpHandler(uri, headers, encodedBody)
          : await _sendWithHttpClient(uri, headers, encodedBody);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return VrAssistantReply(
          text: VrAssistantTranslationConstants.errorRequestFailed,
          isError: true,
        );
      }

      return parseResponseBody(response.body);
    } catch (_) {
      return VrAssistantReply(
        text: VrAssistantTranslationConstants.errorRequestFailed,
        isError: true,
      );
    }
  }

  /// Resolves the target endpoint [Uri] for the configured provider.
  Uri buildEndpointUri() {
    final baseUri = Uri.parse(config.endpointUrl);
    if (config.providerType == VrAiProviderType.gemini &&
        config.apiKey != null &&
        config.apiKey!.isNotEmpty &&
        !baseUri.queryParameters.containsKey(
          VrAssistantConstants.queryKeyParam,
        )) {
      return baseUri.replace(
        queryParameters: <String, String>{
          ...baseUri.queryParameters,
          VrAssistantConstants.queryKeyParam: config.apiKey!,
        },
      );
    }
    return baseUri;
  }

  /// Builds HTTP headers for the configured provider type.
  Map<String, String> buildHeaders() {
    final headers = <String, String>{
      VrAssistantConstants.headerContentType: VrAssistantConstants.mimeJsonUtf8,
      VrAssistantConstants.headerAccept: VrAssistantConstants.mimeJson,
    };
    final apiKey = config.apiKey;
    switch (config.providerType) {
      case VrAiProviderType.openAiCompatible:
      case VrAiProviderType.custom:
      case VrAiProviderType.ollama:
        if (apiKey != null && apiKey.isNotEmpty) {
          headers[VrAssistantConstants.headerAuthorization] =
              '${VrAssistantConstants.bearerPrefix}$apiKey';
        }
      case VrAiProviderType.gemini:
        if (apiKey != null && apiKey.isNotEmpty) {
          headers[VrAssistantConstants.headerGeminiApiKey] = apiKey;
        }
      case VrAiProviderType.anthropic:
      case VrAiProviderType.neomage:
        if (apiKey != null && apiKey.isNotEmpty) {
          headers[VrAssistantConstants.headerAnthropicApiKey] = apiKey;
        }
        headers[VrAssistantConstants.headerAnthropicVersion] =
            VrAssistantConstants.defaultAnthropicVersion;
    }
    headers.addAll(config.headers);
    return headers;
  }

  /// Builds the provider-specific JSON payload including spatial context,
  /// optional base64 viewport snapshot, and registered spatial tools.
  Map<String, Object?> buildRequestPayload(VrAssistantRequest request) {
    final systemInstruction = _buildSystemInstruction(request);
    final base64Image = request.hasImage
        ? base64Encode(request.imageBytes!)
        : null;

    switch (config.providerType) {
      case VrAiProviderType.gemini:
        return _buildGeminiPayload(request, systemInstruction, base64Image);
      case VrAiProviderType.anthropic:
      case VrAiProviderType.neomage:
        return _buildAnthropicPayload(request, systemInstruction, base64Image);
      case VrAiProviderType.ollama:
        return _buildOllamaPayload(request, systemInstruction, base64Image);
      case VrAiProviderType.openAiCompatible:
      case VrAiProviderType.custom:
        return _buildOpenAiPayload(request, systemInstruction, base64Image);
    }
  }

  String _buildSystemInstruction(VrAssistantRequest request) {
    final contextJson = jsonEncode(request.context.toJson());
    final buffer = StringBuffer()
      ..writeln(config.systemPrompt)
      ..writeln('${VrAssistantConstants.contextHeaderPrefix}$contextJson');
    if (request.context.allowedActions.isNotEmpty) {
      buffer.writeln(
        '${VrAssistantConstants.allowedActionsHeaderPrefix}'
        '${request.context.allowedActions.join(', ')}',
      );
    }
    if (toolRegistry != null) {
      final toolInstructions = toolRegistry!.buildPromptInstructions(
        allowedActions: request.context.allowedActions,
      );
      if (toolInstructions.isNotEmpty) {
        buffer.writeln(toolInstructions);
      }
    }
    return buffer.toString().trim();
  }

  Map<String, Object?> _buildOpenAiPayload(
    VrAssistantRequest request,
    String systemInstruction,
    String? base64Image,
  ) {
    final Object userContent = base64Image == null
        ? request.text
        : <Map<String, Object?>>[
            <String, Object?>{
              VrAssistantConstants.keyType: VrAssistantConstants.keyTypeText,
              VrAssistantConstants.keyText: request.text,
            },
            <String, Object?>{
              VrAssistantConstants.keyType:
                  VrAssistantConstants.keyTypeImageUrl,
              VrAssistantConstants.keyImageUrl: <String, Object?>{
                VrAssistantConstants.keyUrl:
                    '${VrAssistantConstants.dataUriPrefix}${request.imageMimeType}'
                    '${VrAssistantConstants.dataUriBase64Separator}$base64Image',
              },
            },
          ];

    final activeTools =
        toolRegistry?.toOpenAiTools(
          allowedActions: request.context.allowedActions,
        ) ??
        const <Map<String, Object?>>[];

    return <String, Object?>{
      VrAssistantConstants.keyModel: config.modelId,
      VrAssistantConstants.keyTemperature: config.temperature,
      VrAssistantConstants.keyMaxTokens: config.maxTokens,
      VrAssistantConstants.keyMessages: <Map<String, Object?>>[
        <String, Object?>{
          VrAssistantConstants.keyRole: VrAssistantConstants.keyRoleSystem,
          VrAssistantConstants.keyContent: systemInstruction,
        },
        <String, Object?>{
          VrAssistantConstants.keyRole: VrAssistantConstants.keyRoleUser,
          VrAssistantConstants.keyContent: userContent,
        },
      ],
      if (activeTools.isNotEmpty) VrAssistantConstants.keyTools: activeTools,
    };
  }

  Map<String, Object?> _buildGeminiPayload(
    VrAssistantRequest request,
    String systemInstruction,
    String? base64Image,
  ) {
    final userParts = <Map<String, Object?>>[
      <String, Object?>{VrAssistantConstants.keyText: request.text},
      if (base64Image != null)
        <String, Object?>{
          VrAssistantConstants.keyInlineData: <String, Object?>{
            VrAssistantConstants.keyMimeType: request.imageMimeType,
            VrAssistantConstants.keyData: base64Image,
          },
        },
    ];

    final declarations =
        toolRegistry?.toGeminiFunctionDeclarations(
          allowedActions: request.context.allowedActions,
        ) ??
        const <Map<String, Object?>>[];

    return <String, Object?>{
      VrAssistantConstants.keySystemInstruction: <String, Object?>{
        VrAssistantConstants.keyParts: <Map<String, Object?>>[
          <String, Object?>{VrAssistantConstants.keyText: systemInstruction},
        ],
      },
      VrAssistantConstants.keyContents: <Map<String, Object?>>[
        <String, Object?>{
          VrAssistantConstants.keyRole: VrAssistantConstants.keyRoleUser,
          VrAssistantConstants.keyParts: userParts,
        },
      ],
      VrAssistantConstants.keyGenerationConfig: <String, Object?>{
        VrAssistantConstants.keyTemperature: config.temperature,
        VrAssistantConstants.keyMaxOutputTokens: config.maxTokens,
      },
      if (declarations.isNotEmpty)
        VrAssistantConstants.keyTools: <Map<String, Object?>>[
          <String, Object?>{
            VrAssistantConstants.keyFunctionDeclarations: declarations,
          },
        ],
    };
  }

  Map<String, Object?> _buildAnthropicPayload(
    VrAssistantRequest request,
    String systemInstruction,
    String? base64Image,
  ) {
    final contentBlocks = <Map<String, Object?>>[
      if (base64Image != null)
        <String, Object?>{
          VrAssistantConstants.keyType: VrAssistantConstants.keyTypeImage,
          VrAssistantConstants.keySource: <String, Object?>{
            VrAssistantConstants.keyType: VrAssistantConstants.keyBase64,
            VrAssistantConstants.keyMediaType: request.imageMimeType,
            VrAssistantConstants.keyData: base64Image,
          },
        },
      <String, Object?>{
        VrAssistantConstants.keyType: VrAssistantConstants.keyTypeText,
        VrAssistantConstants.keyText: request.text,
      },
    ];

    final activeTools =
        toolRegistry?.toNeomageTools(
          allowedActions: request.context.allowedActions,
        ) ??
        const <Map<String, Object?>>[];

    return <String, Object?>{
      VrAssistantConstants.keyModel: config.modelId,
      VrAssistantConstants.keySystem: systemInstruction,
      VrAssistantConstants.keyMaxTokens: config.maxTokens,
      VrAssistantConstants.keyTemperature: config.temperature,
      VrAssistantConstants.keyMessages: <Map<String, Object?>>[
        <String, Object?>{
          VrAssistantConstants.keyRole: VrAssistantConstants.keyRoleUser,
          VrAssistantConstants.keyContent: contentBlocks,
        },
      ],
      if (activeTools.isNotEmpty) VrAssistantConstants.keyTools: activeTools,
    };
  }

  Map<String, Object?> _buildOllamaPayload(
    VrAssistantRequest request,
    String systemInstruction,
    String? base64Image,
  ) {
    final activeTools =
        toolRegistry?.toOpenAiTools(
          allowedActions: request.context.allowedActions,
        ) ??
        const <Map<String, Object?>>[];

    return <String, Object?>{
      VrAssistantConstants.keyModel: config.modelId,
      VrAssistantConstants.keyStream: false,
      VrAssistantConstants.keyOptions: <String, Object?>{
        VrAssistantConstants.keyTemperature: config.temperature,
        VrAssistantConstants.keyNumPredict: config.maxTokens,
      },
      VrAssistantConstants.keyMessages: <Map<String, Object?>>[
        <String, Object?>{
          VrAssistantConstants.keyRole: VrAssistantConstants.keyRoleSystem,
          VrAssistantConstants.keyContent: systemInstruction,
        },
        <String, Object?>{
          VrAssistantConstants.keyRole: VrAssistantConstants.keyRoleUser,
          VrAssistantConstants.keyContent: request.text,
          if (base64Image != null)
            VrAssistantConstants.keyImages: <String>[base64Image],
        },
      ],
      if (activeTools.isNotEmpty) VrAssistantConstants.keyTools: activeTools,
    };
  }

  /// Parses the raw JSON response body from OpenAI, Gemini, Anthropic, or Ollama
  /// into a [VrAssistantReply].
  VrAssistantReply parseResponseBody(String rawBody) {
    final trimmed = rawBody.trim();
    if (trimmed.isEmpty) {
      return VrAssistantReply(
        text: VrAssistantTranslationConstants.errorEmptyProviderReply,
        isError: true,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return VrAssistantReply(text: trimmed);
    }

    if (decoded is! Map) {
      return VrAssistantReply(text: trimmed);
    }

    final jsonMap = <String, Object?>{
      for (final entry in decoded.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };

    switch (config.providerType) {
      case VrAiProviderType.gemini:
        return _parseGeminiResponse(jsonMap);
      case VrAiProviderType.anthropic:
      case VrAiProviderType.neomage:
        return VrNeomageAgentBridge.parseNeomageResponse(jsonMap);
      case VrAiProviderType.ollama:
        return _parseOllamaResponse(jsonMap);
      case VrAiProviderType.openAiCompatible:
      case VrAiProviderType.custom:
        return _parseOpenAiResponse(jsonMap);
    }
  }

  VrAssistantReply _parseOpenAiResponse(Map<String, Object?> jsonMap) {
    final choices = jsonMap[VrAssistantConstants.keyChoices];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final firstChoice = choices.first as Map;
      final message = firstChoice[VrAssistantConstants.keyMessage];
      if (message is Map) {
        return _parseMessageWithToolCalls(message);
      }
    }
    return VrNeomageAgentBridge.parseNeomageResponse(jsonMap);
  }

  VrAssistantReply _parseOllamaResponse(Map<String, Object?> jsonMap) {
    final message = jsonMap[VrAssistantConstants.keyMessage];
    if (message is Map) {
      return _parseMessageWithToolCalls(message);
    }
    final responseText = jsonMap[VrAssistantConstants.keyResponse];
    if (responseText is String && responseText.trim().isNotEmpty) {
      final structured = VrNeomageAgentBridge.tryParseStructuredJsonReply(
        responseText,
      );
      return structured ?? VrAssistantReply(text: responseText.trim());
    }
    return VrNeomageAgentBridge.parseNeomageResponse(jsonMap);
  }

  VrAssistantReply _parseMessageWithToolCalls(Map<dynamic, dynamic> message) {
    final rawContent = message[VrAssistantConstants.keyContent];
    final text = rawContent is String ? rawContent.trim() : '';

    String? toolName;
    Map<String, Object?> toolArgs = const <String, Object?>{};

    final toolCalls = message[VrAssistantConstants.keyToolCalls];
    if (toolCalls is List && toolCalls.isNotEmpty && toolCalls.first is Map) {
      final firstCall = toolCalls.first as Map;
      final function = firstCall[VrAssistantConstants.keyFunction];
      if (function is Map) {
        final name = function[VrAssistantConstants.keyName]?.toString();
        if (name != null && name.isNotEmpty) {
          toolName = name;
          toolArgs = _decodeArguments(
            function[VrAssistantConstants.keyArguments],
          );
        }
      }
    }

    if (text.isNotEmpty && toolName == null) {
      final structured = VrNeomageAgentBridge.tryParseStructuredJsonReply(text);
      if (structured != null) return structured;
    }

    if (text.isEmpty && toolName == null) {
      return VrAssistantReply(
        text: VrAssistantTranslationConstants.errorEmptyProviderReply,
        isError: true,
      );
    }

    return VrAssistantReply(
      text: text.isEmpty ? toolName! : text,
      action: toolName,
      arguments: toolArgs,
    );
  }

  VrAssistantReply _parseGeminiResponse(Map<String, Object?> jsonMap) {
    final candidates = jsonMap[VrAssistantConstants.keyCandidates];
    if (candidates is List &&
        candidates.isNotEmpty &&
        candidates.first is Map) {
      final firstCandidate = candidates.first as Map;
      final content = firstCandidate[VrAssistantConstants.keyContent];
      if (content is Map) {
        final parts = content[VrAssistantConstants.keyParts];
        if (parts is List) {
          final textSegments = <String>[];
          String? functionName;
          Map<String, Object?> functionArgs = const <String, Object?>{};

          for (final part in parts) {
            if (part is Map) {
              final partText = part[VrAssistantConstants.keyText];
              if (partText is String && partText.trim().isNotEmpty) {
                textSegments.add(partText.trim());
              }
              final fnCall = part[VrAssistantConstants.keyFunctionCall];
              if (fnCall is Map) {
                final name = fnCall[VrAssistantConstants.keyName]?.toString();
                if (name != null && name.isNotEmpty) {
                  functionName = name;
                  functionArgs = _decodeArguments(
                    fnCall[VrAssistantConstants.keyArgs] ??
                        fnCall[VrAssistantConstants.keyArguments],
                  );
                }
              }
            }
          }

          final combinedText = textSegments.join('\n').trim();
          if (combinedText.isNotEmpty && functionName == null) {
            final structured = VrNeomageAgentBridge.tryParseStructuredJsonReply(
              combinedText,
            );
            if (structured != null) return structured;
          }

          if (combinedText.isNotEmpty || functionName != null) {
            return VrAssistantReply(
              text: combinedText.isEmpty ? functionName! : combinedText,
              action: functionName,
              arguments: functionArgs,
            );
          }
        }
      }
    }
    return VrNeomageAgentBridge.parseNeomageResponse(jsonMap);
  }

  Map<String, Object?> _decodeArguments(Object? rawArgs) {
    if (rawArgs is Map) {
      return <String, Object?>{
        for (final entry in rawArgs.entries)
          if (entry.key is String) entry.key as String: entry.value,
      };
    }
    if (rawArgs is String && rawArgs.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawArgs);
        if (decoded is Map) {
          return <String, Object?>{
            for (final entry in decoded.entries)
              if (entry.key is String) entry.key as String: entry.value,
          };
        }
      } catch (_) {
        return const <String, Object?>{};
      }
    }
    return const <String, Object?>{};
  }

  Future<({int statusCode, String body})> _sendWithHttpClient(
    Uri uri,
    Map<String, String> headers,
    String body,
  ) async {
    final client = _httpClient!;
    final httpRequest = await client.postUrl(uri);
    headers.forEach(httpRequest.headers.set);
    final payloadBytes = utf8.encode(body);
    httpRequest.contentLength = payloadBytes.length;
    httpRequest.add(payloadBytes);
    final httpResponse = await httpRequest.close();
    final responseBody = await utf8.decodeStream(httpResponse);
    return (statusCode: httpResponse.statusCode, body: responseBody);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_ownsHttpClient) {
      _httpClient?.close(force: true);
    }
  }
}
