import 'cockpit_mcp_prompt_definition.dart';

enum CockpitMcpPromptRole { user, assistant }

final class CockpitMcpPromptMessage {
  const CockpitMcpPromptMessage({
    required this.role,
    required this.text,
  });

  const CockpitMcpPromptMessage.user(String text)
      : this(role: CockpitMcpPromptRole.user, text: text);

  const CockpitMcpPromptMessage.assistant(String text)
      : this(role: CockpitMcpPromptRole.assistant, text: text);

  final CockpitMcpPromptRole role;
  final String text;
}

final class CockpitMcpPromptResult {
  const CockpitMcpPromptResult({
    this.description,
    required this.messages,
  });

  final String? description;
  final List<CockpitMcpPromptMessage> messages;
}

abstract base class CockpitMcpPrompt {
  const CockpitMcpPrompt();

  CockpitMcpPromptDefinition get definition;

  Future<CockpitMcpPromptResult> build(Map<String, Object?> arguments);
}
