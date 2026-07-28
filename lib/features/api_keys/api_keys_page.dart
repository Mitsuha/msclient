import 'package:desktop/data/models/api_key_models.dart';
import 'package:desktop/domain/api_keys/api_key_activation.dart';
import 'package:desktop/features/api_keys/api_key_activation_dialog.dart';
import 'package:desktop/features/api_keys/api_key_row.dart';
import 'package:desktop/ui/app_colors.dart';
import 'package:desktop/ui/widgets/error_banner.dart';
import 'package:desktop/ui/widgets/ghost_button.dart';
import 'package:flutter/cupertino.dart';

/// The "API Keys" section: every key issued to the account, the pack it bills
/// against, the providers it is bound to, and whether it is enabled.
class ApiKeysPage extends StatelessWidget {
  const ApiKeysPage({
    super.key,
    required this.apiKeys,
    required this.isLoading,
    required this.onRefresh,
    required this.onActivate,
    required this.isInUse,
    this.errorMessage,
  });

  final List<ApiKey> apiKeys;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRefresh;

  /// Writes [ApiKeyActivation] into the local tool configs for the given key.
  final void Function(ApiKey apiKey, ApiKeyActivation activation) onActivate;

  /// Whether a tool's config already points at this key — read from disk, not
  /// from the server's own `enabled` flag.
  final bool Function(ApiKey apiKey) isInUse;

  @override
  Widget build(BuildContext context) {
    final enabledCount = apiKeys.where((apiKey) => apiKey.enabled).length;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 26, 30, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Toolbar(
              total: apiKeys.length,
              enabledCount: enabledCount,
              isLoading: isLoading,
              onRefresh: onRefresh,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(message: errorMessage!),
            ],
            const SizedBox(height: 22),
            const _SectionLabel('密钥列表'),
            const SizedBox(height: 10),
            // The skeleton only replaces the list on the very first load; a
            // refresh keeps the current cards on screen.
            if (apiKeys.isEmpty && isLoading)
              const _LoadingList()
            else
              _ApiKeyList(
                apiKeys: apiKeys,
                onActivate: onActivate,
                isInUse: isInUse,
              ),
          ],
        ),
      ),
    );
  }
}

/// The overline above a group — small, spaced, and quiet, so the card below it
/// carries the weight.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.tertiaryLabel,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
      ),
    );
  }
}

/// The vertical gap between two cards in the list.
const double _cardGap = 8;

/// A single white panel, used where the list itself is not a list — the empty
/// state. Individual keys carry their own surface (see [ApiKeyRow]).
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.total,
    required this.enabledCount,
    required this.isLoading,
    required this.onRefresh,
  });

  final int total;
  final int enabledCount;
  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'API Keys',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '使用 API Key 的方式来配置 Codex/Claude Code',
                style: TextStyle(
                  color: AppColors.secondaryLabel,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Padding(
          // Optically centers the controls against the title's cap height
          // rather than the whole two-line block.
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              if (total > 0) ...[
                _CountPill(enabledCount: enabledCount, total: total),
                const SizedBox(width: 10),
              ],
              if (isLoading) ...[
                const CupertinoActivityIndicator(radius: 8),
                const SizedBox(width: 10),
              ],
              GhostButton(
                label: '刷新',
                icon: CupertinoIcons.arrow_clockwise,
                onPressed: isLoading ? null : onRefresh,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "● 6/13 已启用" — a status pill rather than loose gray text, with a live dot
/// that goes green once at least one key is on.
class _CountPill extends StatelessWidget {
  const _CountPill({required this.enabledCount, required this.total});

  final int enabledCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    final active = enabledCount > 0;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.hoverBackground,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.green : AppColors.placeholderText,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '$enabledCount/$total 已启用',
            style: const TextStyle(
              color: AppColors.secondaryLabel,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiKeyList extends StatelessWidget {
  const _ApiKeyList({
    required this.apiKeys,
    required this.onActivate,
    required this.isInUse,
  });

  final List<ApiKey> apiKeys;
  final void Function(ApiKey apiKey, ApiKeyActivation activation) onActivate;
  final bool Function(ApiKey apiKey) isInUse;

  @override
  Widget build(BuildContext context) {
    if (apiKeys.isEmpty) {
      return const _Panel(child: _EmptyList());
    }

    return Column(
      children: [
        for (var i = 0; i < apiKeys.length; i++) ...[
          if (i > 0) const SizedBox(height: _cardGap),
          ApiKeyRow(
            key: ValueKey(apiKeys[i].id),
            apiKey: apiKeys[i],
            isInUse: isInUse(apiKeys[i]),
            onEnable: () => _enable(context, apiKeys[i]),
          ),
        ],
      ],
    );
  }

  Future<void> _enable(BuildContext context, ApiKey apiKey) async {
    final activation = await showApiKeyActivationDialog(
      context,
      keyName: apiKey.name.isEmpty ? 'API Key' : apiKey.name,
    );
    if (activation != null) {
      onActivate(apiKey, activation);
    }
  }
}

/// Skeleton cards shaped like the real ones, gently pulsing — the first load
/// then reads as "this list is arriving" rather than "something is spinning".
class _LoadingList extends StatefulWidget {
  const _LoadingList();

  @override
  State<_LoadingList> createState() => _LoadingListState();
}

class _LoadingListState extends State<_LoadingList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: _cardGap),
            const _Panel(child: _SkeletonRow()),
          ],
        ],
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          _SkeletonBox(width: 30, height: 30, radius: 7),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 124, height: 10),
                SizedBox(height: 7),
                _SkeletonBox(width: 188, height: 9),
              ],
            ),
          ),
          SizedBox(width: 14),
          _SkeletonBox(width: 58, height: 28, radius: 7),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 4,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.mutedBackground,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Centered empty state — the modern shape for "nothing here yet", with the
/// icon carried in a soft tinted circle instead of a flat square.
class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 46),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.hoverBackground,
            ),
            child: const Icon(
              CupertinoIcons.lock_shield,
              size: 24,
              color: AppColors.tertiaryLabel,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '暂无 API Key',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.label,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            '在 MirrorStages 后台创建密钥后会在这里显示。',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.tertiaryLabel, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
