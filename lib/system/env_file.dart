/// Parsing and serialization for simple `KEY=value` env files
/// (such as `~/.codex/.env`).
Map<String, String> parseEnvLines(List<String> lines) {
  final values = <String, String>{};
  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }

    final separator = line.indexOf('=');
    if (separator <= 0) {
      continue;
    }

    final key = line.substring(0, separator).trim();
    var value = line.substring(separator + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    values[key] = value;
  }

  return values;
}

String serializeEnv(Map<String, String> values) {
  final lines = values.entries.map((entry) => '${entry.key}=${entry.value}');
  return '${lines.join('\n')}\n';
}
