import 'package:desktop/domain/api_keys/api_key_activation.dart';
import 'package:desktop/ui/app_colors.dart';
import 'package:flutter/cupertino.dart';

/// Asks which tools the key should be wired into and with which models.
/// Resolves to the chosen [ApiKeyActivation], or null when the user cancels.
Future<ApiKeyActivation?> showApiKeyActivationDialog(
  BuildContext context, {
  required String keyName,
}) {
  return showCupertinoDialog<ApiKeyActivation>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ActivationDialog(keyName: keyName),
  );
}

class _ActivationDialog extends StatefulWidget {
  const _ActivationDialog({required this.keyName});

  final String keyName;

  @override
  State<_ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends State<_ActivationDialog> {
  static const _initial = ApiKeyActivation.defaults();

  bool _codexEnabled = _initial.codexEnabled;
  bool _claudeEnabled = _initial.claudeEnabled;

  final _codexModel = TextEditingController(text: _initial.codexModel);
  final _opusModel = TextEditingController(text: _initial.opusModel);
  final _sonnetModel = TextEditingController(text: _initial.sonnetModel);
  final _haikuModel = TextEditingController(text: _initial.haikuModel);

  @override
  void dispose() {
    _codexModel.dispose();
    _opusModel.dispose();
    _sonnetModel.dispose();
    _haikuModel.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.of(context).pop(
      ApiKeyActivation(
        codexEnabled: _codexEnabled,
        codexModel: _codexModel.text,
        claudeEnabled: _claudeEnabled,
        opusModel: _opusModel.text,
        sonnetModel: _sonnetModel.text,
        haikuModel: _haikuModel.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: AppColors.barrier,
              blurRadius: 40,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(keyName: widget.keyName),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ToolSection(
                      title: 'Codex',
                      enabled: _codexEnabled,
                      onChanged: (value) =>
                          setState(() => _codexEnabled = value),
                      // Show model fields only while this tool is enabled.
                      fields: [
                        _ModelField(
                          label: 'Codex 模型',
                          controller: _codexModel,
                          placeholder: ApiKeyActivation.defaultCodexModel,
                        ),
                      ],
                    ),
                    _ToolSection(
                      title: 'Claude Code',
                      enabled: _claudeEnabled,
                      onChanged: (value) =>
                          setState(() => _claudeEnabled = value),
                      fields: [
                        _ModelField(
                          label: 'Opus 模型',
                          controller: _opusModel,
                          placeholder: ApiKeyActivation.defaultOpusModel,
                        ),
                        _ModelField(
                          label: 'Sonnet 模型',
                          controller: _sonnetModel,
                          placeholder: ApiKeyActivation.defaultSonnetModel,
                        ),
                        _ModelField(
                          label: 'Haiku 模型',
                          controller: _haikuModel,
                          placeholder: ApiKeyActivation.defaultHaikuModel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const _Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: '取消',
                      color: AppColors.secondaryButtonBackground,
                      textColor: AppColors.label,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogButton(
                      label: '确定',
                      color: AppColors.blue,
                      textColor: CupertinoColors.white,
                      // Both tools off would write nothing at all.
                      onPressed: _codexEnabled || _claudeEnabled
                          ? _confirm
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.keyName});

  final String keyName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '启用 $keyName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.label,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            '选中的工具会改用这个 API Key，本地配置将被覆盖。',
            style: TextStyle(fontSize: 12, color: AppColors.tertiaryLabel),
          ),
        ],
      ),
    );
  }
}

/// Shared width keeps switches and fields in one aligned column.
const double _controlWidth = 196;

/// A tool toggle and its conditionally visible model fields.
class _ToolSection extends StatelessWidget {
  const _ToolSection({
    required this.title,
    required this.enabled,
    required this.onChanged,
    required this.fields,
  });

  final String title;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingRow(
          label: title,
          control: Align(
            alignment: Alignment.centerRight,
            child: Transform.scale(
              scale: 0.75,
              alignment: Alignment.centerRight,
              child: CupertinoSwitch(value: enabled, onChanged: onChanged),
            ),
          ),
        ),
        // Animate both field visibility and section height.
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Column(children: fields),
          crossFadeState: enabled
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeOutCubic,
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeIn,
          alignment: Alignment.topLeft,
        ),
      ],
    );
  }
}

/// A label and its control on one line — the single row shape this dialog is
/// built from.
class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.control});

  final String label;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // Identical for every row, so nothing here reads as a title over
              // a subtitle.
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.label,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: _controlWidth, child: control),
        ],
      ),
    );
  }
}

class _ModelField extends StatelessWidget {
  const _ModelField({
    required this.label,
    required this.controller,
    required this.placeholder,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      label: label,
      control: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        style: const TextStyle(fontSize: 12.5),
        placeholderStyle: const TextStyle(
          fontSize: 12.5,
          color: AppColors.placeholderText,
        ),
        autocorrect: false,
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.strongBorder),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onPressed == null
                ? AppColors.disabledButtonBackground
                : color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1,
      child: ColoredBox(color: AppColors.divider),
    );
  }
}
