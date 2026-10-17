class VrAssistantConstants {
  const VrAssistantConstants._();

  static const int maxPromptCharacters = 4000;
  static const int maxPromptBytes = 16000;
  static const int maxImageBytes = 4 * 1024 * 1024;
  static const int maxContextEntries = 4096;
  static const int maxContextDepth = 12;
  static const double maxCaptureDimension = 768.0;

  static const Duration defaultRequestTimeout = Duration(seconds: 30);
  static const Duration defaultCaptureTimeout = Duration(seconds: 3);

  static const String mimePng = 'image/png';
  static const String mimeJpeg = 'image/jpeg';
  static const String mimeJson = 'application/json';
  static const String mimeJsonUtf8 = 'application/json; charset=utf-8';

  static const List<int> pngSignature = <int>[
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
  ];
  static const List<int> jpegSignature = <int>[255, 216, 255];

  static const String defaultOpenAiEndpoint =
      'https://api.openai.com/v1/chat/completions';
  static const String defaultOpenAiModel = 'gpt-4o-mini';

  static const String defaultGeminiEndpointPrefix =
      'https://generativelanguage.googleapis.com/v1beta/models/';
  static const String defaultGeminiEndpointSuffix = ':generateContent';
  static const String defaultGeminiModel = 'gemini-2.5-flash';

  static const String defaultAnthropicEndpoint =
      'https://api.anthropic.com/v1/messages';
  static const String defaultAnthropicModel = 'claude-3-5-sonnet-latest';
  static const String defaultAnthropicVersion = '2023-06-01';

  static const String defaultOllamaEndpoint =
      'http://localhost:11434/api/chat';
  static const String defaultOllamaModel = 'llama3.2';

  static const String defaultNeomageEndpoint = 'neomage://local/session';
  static const String defaultNeomageModel = 'neomage-spatial-v1';

  static const double defaultTemperature = 0.2;
  static const int defaultMaxTokens = 1024;

  static const String headerContentType = 'content-type';
  static const String headerAccept = 'accept';
  static const String headerAuthorization = 'authorization';
  static const String bearerPrefix = 'Bearer ';
  static const String headerAnthropicApiKey = 'x-api-key';
  static const String headerAnthropicVersion = 'anthropic-version';
  static const String headerGeminiApiKey = 'x-goog-api-key';
  static const String queryKeyParam = 'key';

  static const String keyModel = 'model';
  static const String keyMessages = 'messages';
  static const String keySystem = 'system';
  static const String keySystemPrompt = 'systemPrompt';
  static const String keySystemInstruction = 'systemInstruction';
  static const String keyRole = 'role';
  static const String keyRoleSystem = 'system';
  static const String keyRoleUser = 'user';
  static const String keyRoleAssistant = 'assistant';
  static const String keyContent = 'content';
  static const String keyParts = 'parts';
  static const String keyText = 'text';
  static const String keyType = 'type';
  static const String keyTypeText = 'text';
  static const String keyTypeImageUrl = 'image_url';
  static const String keyTypeImage = 'image';
  static const String keyTypeToolUse = 'tool_use';
  static const String keyTypeFunction = 'function';
  static const String keyImageUrl = 'image_url';
  static const String keyUrl = 'url';
  static const String keySource = 'source';
  static const String keyBase64 = 'base64';
  static const String keyMediaType = 'media_type';
  static const String keyData = 'data';
  static const String keyInlineData = 'inlineData';
  static const String keyMimeType = 'mimeType';
  static const String keyImages = 'images';
  static const String keyStream = 'stream';
  static const String keyTemperature = 'temperature';
  static const String keyMaxTokens = 'max_tokens';
  static const String keyMaxOutputTokens = 'maxOutputTokens';
  static const String keyGenerationConfig = 'generationConfig';
  static const String keyOptions = 'options';
  static const String keyNumPredict = 'num_predict';
  static const String keyContents = 'contents';
  static const String keyChoices = 'choices';
  static const String keyMessage = 'message';
  static const String keyCandidates = 'candidates';
  static const String keyToolCalls = 'tool_calls';
  static const String keyFunction = 'function';
  static const String keyFunctionCall = 'functionCall';
  static const String keyFunctionDeclarations = 'functionDeclarations';
  static const String keyId = 'id';
  static const String keyName = 'name';
  static const String keyDescription = 'description';
  static const String keyParameters = 'parameters';
  static const String keyInputSchema = 'input_schema';
  static const String keyInput = 'input';
  static const String keyArgs = 'args';
  static const String keyArguments = 'arguments';
  static const String keyAction = 'action';
  static const String keyReply = 'reply';
  static const String keyResponse = 'response';
  static const String keyIsError = 'isError';
  static const String keyContext = 'context';
  static const String keyExperienceId = 'experienceId';
  static const String keyTitle = 'title';
  static const String keyDetails = 'details';
  static const String keyAllowedActions = 'allowedActions';
  static const String keyTools = 'tools';
  static const String keySchemaType = 'type';
  static const String keySchemaTypeObject = 'object';
  static const String keySchemaProperties = 'properties';
  static const String keySchemaRequired = 'required';

  static const String dataUriPrefix = 'data:';
  static const String dataUriBase64Separator = ';base64,';
  static const String jsonFenceStart = '```json';
  static const String codeFence = '```';
  static const String defaultToolUseIdPrefix = 'vr_tool_';

  static const String defaultSystemPrompt =
      'You are the VRlizate Spatial Assistant inside an Open Neom XR '
      'experience. Answer concisely and helpfully. When proposing an action '
      'from allowedActions, return a JSON object with keys "text", "action", '
      'and "arguments", or plain text when no action is needed.';

  static const String contextHeaderPrefix = 'Spatial Context: ';
  static const String allowedActionsHeaderPrefix = 'Allowed Spatial Actions: ';
  static const String registeredToolsHeaderPrefix = 'Registered Spatial Tools: ';
  static const String userPromptHeaderPrefix = 'User Question: ';
}
