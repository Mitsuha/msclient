import 'dart:io';

import 'package:desktop/app/app_view_model.dart';
import 'package:desktop/app/models/nav_section.dart';
import 'package:desktop/features/auth/login_overlay.dart';
import 'package:desktop/features/dashboard/dashboard_page.dart';
import 'package:desktop/features/settings/settings_page.dart';
import 'package:desktop/features/shell/app_sidebar.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

/// The main window: sidebar, section switching, login overlay, and the
/// Windows title bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AppViewModel>();
    final snapshot = viewModel.snapshot;
    final content = Stack(
      children: [
        ColoredBox(
          color: CupertinoColors.white,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSidebar(
                selectedSection: viewModel.selectedSection,
                onSelectSection: viewModel.selectSection,
                onOpenAccount: viewModel.openAdminConsole,
                onLogout: viewModel.logout,
                account: snapshot?.account,
              ),
              Expanded(
                child: snapshot == null
                    ? const _LoadingContent()
                    : switch (viewModel.selectedSection) {
                        NavSection.dashboard => DashboardPage(
                          snapshot: snapshot,
                          isWorking: viewModel.isWorking,
                          errorMessage: viewModel.errorMessage,
                          onRefresh: viewModel.refresh,
                          onApplyCodexBilling: viewModel.applyCodexBilling,
                          onApplyClaudeBilling: viewModel.applyClaudeBilling,
                          onInstallRootCertificate:
                              viewModel.installRootCertificate,
                        ),
                        NavSection.settings => SettingsPage(
                          snapshot: snapshot,
                          isWorking: viewModel.isWorking,
                          errorMessage: viewModel.errorMessage,
                          onRefresh: viewModel.refresh,
                          onInstallRootCertificate:
                              viewModel.installRootCertificate,
                          onRestoreCodexConfig: viewModel.restoreCodexConfig,
                          onRestoreClaudeConfig: viewModel.restoreClaudeConfig,
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
