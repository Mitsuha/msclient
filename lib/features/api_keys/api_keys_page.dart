import 'dart:async';

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
    required this.onManage,
    required this.onActivate,
    required this.isInUse,
    required this.isCodexInitialized,
    required this.isClaudeInitialized,
    this.errorMessage,
  });

  final List<ApiKey> apiKeys;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRefresh;

  /// Opens the web console, where keys are created and revoked.
  final VoidCallback onManage;

  /// Writes [ApiKeyActivation] into the local tool configs for the given key.
  final void Function(ApiKey apiKey, ApiKeyActivation activation) onActivate;

  /// Whether a tool's config already points at this key — read from disk, not
  /// from the server's own `enabled` flag.
  final bool Function(ApiKey apiKey) isInUse;
  final bool isCodexInitialized;
  final bool isClaudeInitialized;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 26, 30, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Toolbar(
              isLoading: isLoading,
              onRefresh: onRefresh,
              onManage: onManage,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(message: errorMessage!),
            ],
            const SizedBox(height: 22),
            const _DirectConnectionTip(),
            if (isCodexInitialized || isClaudeInitialized) ...[
              const SizedBox(height: 8),
              _DirectConnectionWarning(
                isCodexInitialized: isCodexInitialized,
                isClaudeInitialized: isClaudeInitialized,
              ),
            ],
            const SizedBox(height: 14),
            const _SectionLabel('API keys'),
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

class _DirectConnectionWarning extends StatelessWidget {
  const _DirectConnectionWarning({
    required this.isCodexInitialized,
    required this.isClaudeInitialized,
  });

  final bool isCodexInitialized;
  final bool isClaudeInitialized;

  @override
  Widget build(BuildContext context) {
    final tools = [
      if (isCodexInitialized) 'Codex',
      if (isClaudeInitialized) 'Claude Code',
    ].join('和');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.orangeTintBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.orangeTintBorder),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: AppColors.orange,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '目前 $tools 是直连状态，切换为 API 模式会可能会丢失账号的直连',
              style: const TextStyle(color: AppColors.orange, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two halves of the same advice, shown one at a time: account mode is the
/// recommended path, and API keys are the fallback. Rotating them keeps the
/// banner one line tall instead of a paragraph nobody reads.
const List<String> _tips = [
  '推荐使用账号直连，价格更低更稳定，请在『控制面板』获取账号',
  'API Key 仅在直连不满足需求时以传统的方式配置 Codex、Claude Code',
];

/// How long each tip holds before the next one slides in.
const Duration _tipInterval = Duration(seconds: 5);

/// Blue-tinted advisory above the key list, cycling through [_tips].
class _DirectConnectionTip extends StatefulWidget {
  const _DirectConnectionTip();

  @override
  State<_DirectConnectionTip> createState() => _DirectConnectionTipState();
}

class _DirectConnectionTipState extends State<_DirectConnectionTip> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tipInterval, (_) {
      setState(() => _index = (_index + 1) % _tips.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.info_circle_fill,
            color: AppColors.blue,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              // The outgoing tip leaves upward while the incoming one rises
              // into place, so the banner reads as one line being replaced
              // rather than two lines briefly overlapping.
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.6),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              // Both tips occupy the same slot; without this the default Stack
              // centers them and the text drifts as lengths change.
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              child: Text(
                _tips[_index],
                key: ValueKey(_index),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.blue, fontSize: 12),
              ),
            ),
          ),
        ],
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
    required this.isLoading,
    required this.onRefresh,
    required this.onManage,
  });

  final bool isLoading;
  final VoidCallback onRefresh;
  final VoidCallback onManage;

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
                '使用类似 CC Switch 的方式来配置 Codex/Claude Code，在直连不满足需求时候使用。',
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
              if (isLoading) ...[
                const CupertinoActivityIndicator(radius: 8),
                const SizedBox(width: 10),
              ],
              _ManageIcon(onPressed: onManage),
              const SizedBox(width: 12),
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

/// A bare icon — no fill, no border, no press animation — that tints light blue
/// on hover. Deliberately quieter than [GhostButton]: managing keys happens on
/// the web, so this is a pointer, not an action the page owns.
class _ManageIcon extends StatefulWidget {
  const _ManageIcon({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_ManageIcon> createState() => _ManageIconState();
}

class _ManageIconState extends State<_ManageIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 16,
          child: Center(
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                end: _hovered
                    ? AppColors.blue.withValues(alpha: 0.65)
                    : AppColors.secondaryLabel,
              ),
              duration: const Duration(milliseconds: 130),
              curve: Curves.easeOut,
              builder: (context, color, _) =>
                  Icon(CupertinoIcons.square_pencil, size: 16, color: color),
            ),
          ),
        ),
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
