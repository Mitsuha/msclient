import 'package:desktop/app/app_view_model.dart';
import 'package:desktop/app/models/nav_section.dart';
import 'package:desktop/features/api_keys/api_keys_page.dart';
import 'package:desktop/features/auth/login_overlay.dart';
import 'package:desktop/features/dashboard/dashboard_page.dart';
import 'package:desktop/features/settings/settings_page.dart';
import 'package:desktop/features/shell/app_sidebar.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

/// The main window: sidebar, section switching, login overlay, and the
/// Windows title bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AppViewModel>();
    final snapshot = viewModel.snapshot;
    return CupertinoPageScaffold(
      child: Stack(
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
                          NavSection.apiKeys => ApiKeysPage(
                            apiKeys: viewModel.apiKeys,
                            isLoading: viewModel.isLoadingApiKeys,
                            errorMessage: viewModel.apiKeysErrorMessage,
                            onRefresh: viewModel.refreshApiKeys,
                            onActivate: viewModel.activateApiKey,
                            isInUse: viewModel.isApiKeyInUse,
                          ),
                          NavSection.settings => SettingsPage(
                            snapshot: snapshot,
                            isWorking: viewModel.isWorking,
                            errorMessage: viewModel.errorMessage,
                            onRefresh: viewModel.refresh,
                            onSelectProxy: viewModel.selectProxy,
                            onSetNetworkProxy: viewModel.setNetworkProxy,
                            onApplyCodexInitStep: viewModel.applyCodexInitStep,
                            onApplyClaudeInitStep:
                                viewModel.applyClaudeInitStep,
                            onRestoreCodexConfig: viewModel.restoreCodexConfig,
                            onRestoreClaudeConfig:
                                viewModel.restoreClaudeConfig,
                            onClearConfig: viewModel.clearProxyConfig,
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
              onRegister: viewModel.openRegister,
              onExit: onExit,
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
