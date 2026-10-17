/// Lifecycle states of the VRlizate spatial assistant controller.
enum VrAssistantState {
  /// Idle and ready to accept a new spatial query.
  idle,

  /// Capturing the current 3D/VR scene visual snapshot.
  capturingContext,

  /// Waiting for the AI provider or `neomage` agent to respond.
  thinking,

  /// A valid reply (and optional proposed action) has been received.
  responding,

  /// Executing a validated spatial tool action.
  executingAction,

  /// The last request or capture failed or timed out.
  error,
}
