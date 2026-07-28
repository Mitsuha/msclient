import 'package:desktop/data/models/api_key_models.dart';
import 'package:desktop/features/api_keys/api_key_presentation.dart';
import 'package:desktop/ui/app_colors.dart';
import 'package:desktop/ui/widgets/ghost_button.dart';
import 'package:flutter/cupertino.dart';

/// An API-key card with metadata and an activation action.
class ApiKeyRow extends StatefulWidget {
  const ApiKeyRow({
    super.key,
    required this.apiKey,
    required this.isInUse,
    required this.onEnable,
  });

  final ApiKey apiKey;

  /// Replaces the activation button with 正在使用 when this key is active.
  final bool isInUse;

  final VoidCallback? onEnable;

  @override
  State<ApiKeyRow> createState() => _ApiKeyRowState();
}

class _ApiKeyRowState extends State<ApiKeyRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.optionBackground : CupertinoColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // A disabled key stays readable but visibly recedes; only the
            // button keeps full contrast so it still invites a click.
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: widget.apiKey.enabled ? 1 : 0.5,
                child: Row(
                  children: [
                    _MonogramBadge(apiKey: widget.apiKey),
                    const SizedBox(width: 12),
                    Expanded(child: _Details(apiKey: widget.apiKey)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            if (widget.isInUse)
              const _InUseLabel()
            else
              GhostButton(label: '启用', onPressed: widget.onEnable),
          ],
        ),
      ),
    );
  }
}

/// Status text where the 启用 button sits on every other row. It keeps the
/// button's height and horizontal padding, so a list mixing the two states has
/// one row rhythm and one right edge.
class _InUseLabel extends StatelessWidget {
  const _InUseLabel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 28,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 13),
        child: Center(
          child: Text(
            '正在使用',
            style: TextStyle(
              color: AppColors.tertiaryLabel,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.apiKey});

  final ApiKey apiKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                apiKey.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.label,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            const SizedBox(width: 7),
            _PackTag(label: packLabel(apiKey)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          detailLine(apiKey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.tertiaryLabel,
            fontSize: 11.5,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

/// The pack a key bills against, as an inline tag next to its name. Outlined
/// and gray rather than filled and colored: it is metadata, and should never
/// out-shout the key's own name.
class _PackTag extends StatelessWidget {
  const _PackTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Capped so a verbose pack name truncates instead of squeezing the key
      // name out of the row.
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.tertiaryLabel,
          fontSize: 9,
          fontWeight: FontWeight.w200,
        ),
      ),
    );
  }
}

/// Tinted tile carrying the key's initial — a monogram rather than a
/// per-vendor icon, so an unknown provider still renders sensibly.
class _MonogramBadge extends StatelessWidget {
  const _MonogramBadge({required this.apiKey});

  final ApiKey apiKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.hoverBackground,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        apiKeyMonogram(apiKey),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.secondaryLabel,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          // Even leading vertically centers both Latin and CJK glyphs.
          height: 1,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
    );
  }
}
