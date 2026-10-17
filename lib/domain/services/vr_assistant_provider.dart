import '../models/vr_assistant_reply.dart';
import '../models/vr_assistant_request.dart';

/// Contract for any spatial AI assistant provider (`neomage`, OpenAI, Gemini,
/// Anthropic Claude, Ollama, or custom host adapter).
abstract interface class VrAssistantProvider {
  Future<VrAssistantReply> respond(VrAssistantRequest request);
  void dispose();
}
