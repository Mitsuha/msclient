/// Tool and model choices from the API-key activation dialog.
/// Disabled tools are left untouched on disk.
class ApiKeyActivation {
  const ApiKeyActivation({
    required this.codexEnabled,
    required this.codexModel,
    required this.claudeEnabled,
    required this.opusModel,
    required this.sonnetModel,
    required this.haikuModel,
  });

  /// Starts with both tools off and default model values pre-filled.
  const ApiKeyActivation.defaults()
    : codexEnabled = false,
      codexModel = defaultCodexModel,
      claudeEnabled = false,
      opusModel = defaultOpusModel,
      sonnetModel = defaultSonnetModel,
      haikuModel = defaultHaikuModel;

  static const String defaultCodexModel = 'gpt-5.6-luna';
  static const String defaultOpusModel = 'claude-opus-5';
  static const String defaultSonnetModel = 'claude-sonnet-4-5-20250929';
  static const String defaultHaikuModel = 'claude-haiku-4-5-20251001';

  final bool codexEnabled;
  final String codexModel;

  final bool claudeEnabled;

  /// Claude model overrides; blank values are omitted from `settings.json`.
  final String opusModel;
  final String sonnetModel;
  final String haikuModel;

  /// Whether anything at all would be written.
  bool get isEmpty => !codexEnabled && !claudeEnabled;
}
