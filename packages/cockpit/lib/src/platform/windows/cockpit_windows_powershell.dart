import 'dart:convert';
import 'dart:typed_data';

List<String> cockpitWindowsPowerShellCommand(
  String script, {
  List<String> arguments = const <String>[],
}) {
  return <String>[
    '-NoProfile',
    '-NonInteractive',
    '-EncodedCommand',
    cockpitEncodeWindowsPowerShellCommand(
      cockpitWindowsPowerShellBody(script, arguments: arguments),
    ),
  ];
}

String cockpitWindowsPowerShellBody(
  String script, {
  List<String> arguments = const <String>[],
}) {
  if (arguments.isEmpty) {
    return script;
  }
  return '& {\n$script\n} ${arguments.map(_powershellSingleQuoted).join(' ')}';
}

String cockpitEncodeWindowsPowerShellCommand(String script) {
  final codeUnits = script.codeUnits;
  final bytes = Uint8List(codeUnits.length * 2);
  final view = ByteData.view(bytes.buffer);
  for (var index = 0; index < codeUnits.length; index += 1) {
    view.setUint16(index * 2, codeUnits[index], Endian.little);
  }
  return base64.encode(bytes);
}

String _powershellSingleQuoted(String value) {
  return "'${value.replaceAll("'", "''")}'";
}
