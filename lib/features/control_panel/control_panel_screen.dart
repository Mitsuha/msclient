import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'package:desktop/features/control_panel/control_panel_models.dart';
import 'package:desktop/features/control_panel/control_panel_view_model.dart';

class ControlPanelScreen extends StatelessWidget {
  const ControlPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ControlPanelViewModel>();
    final snapshot = viewModel.snapshot;

    return CupertinoPageScaffold(
      child: SafeArea(
        child: ColoredBox(
          color: const Color(0xFFEDEDF0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980, maxHeight: 640),
              child: Container(
                margin: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD7D7DB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    const _Sidebar(),
                    Expanded(
                      child: snapshot == null
                          ? const _LoadingContent()
                          : _ContentArea(
                              snapshot: snapshot,
                              isWorking: viewModel.isWorking,
                              errorMessage: viewModel.errorMessage,
                              onRefresh: viewModel.refresh,
                              onInitialize: viewModel.initialize,
                              onTerminate: viewModel.terminateConflicts,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      decoration: const BoxDecoration(
        color: Color(0xFFF4F4F6),
        border: Border(right: BorderSide(color: Color(0xFFD7D7DB))),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrafficLights(),
          SizedBox(height: 18),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'MirrorStages',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(height: 18),
          _SidebarItem(
            icon: CupertinoIcons.slider_horizontal_3,
            label: '控制面板',
            selected: true,
          ),
          _SidebarItem(
            icon: CupertinoIcons.person_crop_circle,
            label: '账户',
            selected: false,
          ),
          _SidebarItem(icon: CupertinoIcons.gear, label: '设置', selected: false),
          Spacer(),
          Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Text(
              'Desktop Client',
              style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrafficLights extends StatelessWidget {
  const _TrafficLights();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Row(
        children: [
          _TrafficDot(color: Color(0xFFFF5F57)),
          SizedBox(width: 8),
          _TrafficDot(color: Color(0xFFFFBD2E)),
          SizedBox(width: 8),
          _TrafficDot(color: Color(0xFF28C840)),
        ],
      ),
    );
  }
}

class _TrafficDot extends StatelessWidget {
  const _TrafficDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox(width: 12, height: 12),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE5E5EA) : null,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFF3A3A3C)),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF1D1D1F),
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CupertinoActivityIndicator(radius: 12));
  }
}

class _ContentArea extends StatelessWidget {
  const _ContentArea({
    required this.snapshot,
    required this.isWorking,
    required this.onRefresh,
    required this.onInitialize,
    required this.onTerminate,
    this.errorMessage,
  });

  final ControlPanelSnapshot snapshot;
  final bool isWorking;
  final String? errorMessage;
  final VoidCallback onRefresh;
  final VoidCallback onInitialize;
  final VoidCallback onTerminate;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Toolbar(isWorking: isWorking, onRefresh: onRefresh),
          const SizedBox(height: 18),
          _StatusAlert(snapshot: snapshot, errorMessage: errorMessage),
          const SizedBox(height: 18),
          _Section(
            title: '账户',
            child: _AccountTable(account: snapshot.account),
          ),
          const SizedBox(height: 18),
          _Section(
            title: '订阅',
            child: _SubscriptionSummary(account: snapshot.account),
          ),
          const Spacer(),
          _FooterActions(
            snapshot: snapshot,
            isWorking: isWorking,
            onRefresh: onRefresh,
            onInitialize: onInitialize,
            onTerminate: onTerminate,
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 520) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: content,
            ),
          );
        }
        return content;
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.isWorking, required this.onRefresh});

  final bool isWorking;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '控制面板',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        if (isWorking) ...[
          const CupertinoActivityIndicator(radius: 9),
          const SizedBox(width: 10),
        ],
        _ToolbarButton(
          icon: CupertinoIcons.arrow_clockwise,
          label: '刷新',
          onPressed: isWorking ? null : onRefresh,
        ),
      ],
    );
  }
}

class _StatusAlert extends StatelessWidget {
  const _StatusAlert({required this.snapshot, this.errorMessage});

  final ControlPanelSnapshot snapshot;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final style = _StatusStyle.fromState(snapshot.state);
    final message = errorMessage ?? snapshot.message ?? _messageFor(snapshot);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(style.icon, color: style.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  style.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF3A3A3C),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            style.badge,
            style: TextStyle(
              color: style.color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _messageFor(ControlPanelSnapshot snapshot) {
    return switch (snapshot.state) {
      RuntimeState.conflict =>
        '检测到 ${snapshot.conflicts.length} 个 cc-switch 进程正在运行，请结束后刷新状态。',
      RuntimeState.uninitialized => '本机 Codex 授权或代理环境变量尚未完成初始化。',
      RuntimeState.running => '配置完整，当前客户端可以正常工作。',
      RuntimeState.error => '状态检测失败，请刷新后重试。',
      RuntimeState.loading => '正在读取本机状态。',
    };
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF6E6E73),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFBFBFD),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E5EA)),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _AccountTable extends StatelessWidget {
  const _AccountTable({required this.account});

  final AccountSummary account;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TableRow(label: '账号', value: account.account),
        _Divider(),
        _TableRow(label: '昵称', value: account.nickname),
        _Divider(),
        _TableRow(label: '账户余额', value: account.balance),
      ],
    );
  }
}

class _SubscriptionSummary extends StatelessWidget {
  const _SubscriptionSummary({required this.account});

  final AccountSummary account;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              CupertinoIcons.sparkles,
              color: Color(0xFF007AFF),
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.planName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '有效期至 ${account.planExpiresAt}',
                  style: const TextStyle(
                    color: Color(0xFF6E6E73),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '已购买',
            style: TextStyle(
              color: Color(0xFF34C759),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6E6E73), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 14),
      child: SizedBox(height: 1, child: ColoredBox(color: Color(0xFFE5E5EA))),
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.snapshot,
    required this.isWorking,
    required this.onRefresh,
    required this.onInitialize,
    required this.onTerminate,
  });

  final ControlPanelSnapshot snapshot;
  final bool isWorking;
  final VoidCallback onRefresh;
  final VoidCallback onInitialize;
  final VoidCallback onTerminate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _statusHint(snapshot),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        if (snapshot.state == RuntimeState.conflict)
          _ActionButton(
            label: '结束进程',
            onPressed: isWorking ? null : onTerminate,
            destructive: true,
          ),
        if (snapshot.state == RuntimeState.uninitialized)
          _ActionButton(
            label: '初始化',
            onPressed: isWorking ? null : onInitialize,
          ),
        if (snapshot.state == RuntimeState.running)
          _ActionButton(label: '刷新状态', onPressed: isWorking ? null : onRefresh),
      ],
    );
  }

  String _statusHint(ControlPanelSnapshot snapshot) {
    return switch (snapshot.state) {
      RuntimeState.conflict =>
        '冲突进程: ${snapshot.conflicts.map((item) => item.pid).join(', ')}',
      RuntimeState.uninitialized => snapshot.initialization.envPath,
      RuntimeState.running => '最后状态: 本机配置正常',
      RuntimeState.error => '检测失败',
      RuntimeState.loading => '正在检测',
    };
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: const Size(30, 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: const Color(0xFFE9E9ED),
      borderRadius: BorderRadius.circular(6),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1D1D1F)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF1D1D1F), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: const Size(32, 32),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      color: destructive ? const Color(0xFFFF3B30) : const Color(0xFF007AFF),
      disabledColor: const Color(0xFFC7C7CC),
      borderRadius: BorderRadius.circular(6),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(color: CupertinoColors.white, fontSize: 13),
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.title,
    required this.badge,
    required this.icon,
    required this.color,
    required this.background,
    required this.border,
  });

  final String title;
  final String badge;
  final IconData icon;
  final Color color;
  final Color background;
  final Color border;

  static _StatusStyle fromState(RuntimeState state) {
    return switch (state) {
      RuntimeState.conflict => const _StatusStyle(
        title: '有冲突软件正在运行',
        badge: '需要处理',
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        color: Color(0xFFFF3B30),
        background: Color(0xFFFFF4F3),
        border: Color(0xFFFFD2CC),
      ),
      RuntimeState.uninitialized => const _StatusStyle(
        title: '未初始化',
        badge: '待初始化',
        icon: CupertinoIcons.info_circle_fill,
        color: Color(0xFFFF9500),
        background: Color(0xFFFFF8E8),
        border: Color(0xFFFFE1A8),
      ),
      RuntimeState.running => const _StatusStyle(
        title: '正在运行',
        badge: '正常',
        icon: CupertinoIcons.check_mark_circled_solid,
        color: Color(0xFF34C759),
        background: Color(0xFFF1FAF3),
        border: Color(0xFFCFEED5),
      ),
      RuntimeState.error => const _StatusStyle(
        title: '检测失败',
        badge: '错误',
        icon: CupertinoIcons.xmark_circle_fill,
        color: Color(0xFFFF3B30),
        background: Color(0xFFFFF4F3),
        border: Color(0xFFFFD2CC),
      ),
      RuntimeState.loading => const _StatusStyle(
        title: '正在检测',
        badge: '读取中',
        icon: CupertinoIcons.clock_fill,
        color: Color(0xFF007AFF),
        background: Color(0xFFF1F7FF),
        border: Color(0xFFCFE3FF),
      ),
    };
  }
}
