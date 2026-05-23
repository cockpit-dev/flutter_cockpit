import 'package:dart_mcp/server.dart';

import 'cockpit_mcp_prompt.dart';

final class CockpitMcpPromptAdapter {
  const CockpitMcpPromptAdapter._();

  static Prompt protocolPromptFor(CockpitMcpPrompt prompt) {
    final definition = prompt.definition;
    return Prompt(
      name: definition.name,
      description: definition.description,
      arguments: definition.arguments
          .map(
            (argument) => PromptArgument(
              name: argument.name,
              description: argument.description,
              required: argument.required,
            ),
          )
          .toList(growable: false),
    );
  }

  static Future<GetPromptResult> invoke(
    CockpitMcpPrompt prompt,
    GetPromptRequest request,
  ) async {
    final result = await prompt.build(
      request.arguments ?? const <String, Object?>{},
    );
    return GetPromptResult(
      description: result.description,
      messages: result.messages
          .map(
            (message) => PromptMessage(
              role: switch (message.role) {
                CockpitMcpPromptRole.user => Role.user,
                CockpitMcpPromptRole.assistant => Role.assistant,
              },
              content: Content.text(text: message.text),
            ),
          )
          .toList(growable: false),
    );
  }
}
