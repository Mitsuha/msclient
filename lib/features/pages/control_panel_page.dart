import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'package:desktop/features/components/account_table.dart';
import 'package:desktop/features/components/app_button.dart';
import 'package:desktop/features/components/app_sidebar.dart';
import 'package:desktop/features/components/login_overlay.dart';
import 'package:desktop/features/components/section_card.dart';
import 'package:desktop/features/components/status_alert.dart';
import 'package:desktop/features/components/subscription_summary.dart';
import 'package:desktop/features/models/control_panel_models.dart';
import 'package:desktop/features/pages/settings_page.dart';
import 'package:desktop/features/view_models/control_panel_view_model.dart';

class ControlPanelPage extends StatelessWidget {
  const ControlPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ControlPanelViewModel>();
    final snapshot = viewModel.snapshot;
    final content = Stack(
      children: [
        ColoredBox(
          color: CupertinoColors.white,
          child: Row(
            children: [
              AppSidebar(
                selectedSection: viewModel.selectedSection,
                onSelectSection: viewModel.selectSection,
                onLogout: viewModel.logout,
              ),
              Expanded(
                child: snapshot == null
                    ? const _LoadingContent()
                    : switch (viewModel.selectedSection) {
                        ControlPanelSection.dashboard => _ContentArea(
                          snapshot: snapshot,
                          isWorking: viewModel.isWorking,
                          errorMessage: viewModel.errorMessage,
                          onRefresh: viewModel.refresh,
                          onInitialize: viewModel.initialize,
                          onInstallRootCertificate:
                              viewModel.installRootCertificate,
                        ),
                        ControlPanelSection.settings => SettingsPage(
                          snapshot: snapshot,
                          isWorking: viewModel.isWorking,
                          onRefresh: viewModel.refresh,
                          onInstallRootCertificate:
                              viewModel.installRootCertificate,
                          onOpenAdminConsole: () {
                            viewModel.openAdminConsole();
                          },
                          onLogout: viewModel.logout,
                        ),
                      },
              ),
            ],
          ),
        ),
        if (viewModel.shouldShowLogin)
          LoginOverlay(
            isLoading: viewModel.isLoggingIn,
            errorMessage: viewModel.loginErrorMessage,
            onLogin: viewModel.login,
            onExit: windowManager.destroy,
          ),
      ],
    );

    return CupertinoPageScaffold(
      child: Platform.isWindows
          ? Column(
              children: [
                const _WindowsTitleBar(),
                Expanded(child: content),
              ],
            )
          : content,
    );
  }
}

class _WindowsTitleBar extends StatelessWidget {
  const _WindowsTitleBar();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: kWindowCaptionHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Row(
            children: [
              SizedBox(
                width: 190,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFF4F4F6),
                    border: Border(right: BorderSide(color: Color(0xFFD7D7DB))),
                  ),
                ),
              ),
              Expanded(child: ColoredBox(color: CupertinoColors.white)),
            ],
          ),
          WindowCaption(
            backgroundColor: Color(0x00000000),
            brightness: Brightness.light,
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
    required this.onInstallRootCertificate,
    this.errorMessage,
  });

  final ControlPanelSnapshot snapshot;
  final bool isWorking;
  final String? errorMessage;
  final VoidCallback onRefresh;
  final VoidCallback onInitialize;
  final VoidCallback onInstallRootCertificate;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Toolbar(isWorking: isWorking, onRefresh: onRefresh),
          const SizedBox(height: 18),
          StatusAlert(
            snapshot: snapshot,
            isWorking: isWorking,
            errorMessage: errorMessage,
            onRefresh: onRefresh,
            onInitialize: onInitialize,
            onInstallRootCertificate: onInstallRootCertificate,
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: '账户',
            child: AccountTable(account: snapshot.account),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: '订阅',
            child: SubscriptionSummary(
              packs: snapshot.dashboard?.packs ?? const [],
            ),
          ),
          const Spacer(),
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
        AppButton(
          icon: CupertinoIcons.arrow_clockwise,
          label: '刷新',
          compact: true,
          color: const Color(0xFFE9E9ED),
          textColor: const Color(0xFF1D1D1F),
          onPressed: isWorking ? null : onRefresh,
        ),
      ],
    );
  }
}
