import 'dart:ui';

import 'package:desktop/ui/app_colors.dart';
import 'package:desktop/ui/widgets/app_button.dart';
import 'package:flutter/cupertino.dart';

class LoginOverlay extends StatefulWidget {
  const LoginOverlay({
    super.key,
    required this.isLoading,
    required this.onLogin,
    required this.onRegister,
    required this.onExit,
    this.errorMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function({
    required String account,
    required String password,
  })
  onLogin;
  final VoidCallback onRegister;
  final VoidCallback onExit;

  @override
  State<LoginOverlay> createState() => _LoginOverlayState();
}

class _LoginOverlayState extends State<LoginOverlay> {
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: ColoredBox(
            color: AppColors.loginBarrier,
            child: Center(
              child: Container(
                width: 360,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.strongBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.overlayCardShadow,
                      blurRadius: 28,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '登录 MirrorStages',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '连接你的账户，同步余额、套餐与本机运行状态。',
                      style: TextStyle(
                        color: AppColors.secondaryLabel,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    CupertinoTextField(
                      controller: _accountController,
                      enabled: !widget.isLoading,
                      placeholder: '邮箱或手机号',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                    CupertinoTextField(
                      controller: _passwordController,
                      enabled: !widget.isLoading,
                      obscureText: true,
                      placeholder: '密码',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    if (widget.errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        widget.errorMessage!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RegisterLink(
                          onPressed: widget.isLoading
                              ? null
                              : widget.onRegister,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppButton(
                              label: '退出',
                              color: AppColors.neutralButtonBackground,
                              textColor: AppColors.label,
                              onPressed: widget.isLoading
                                  ? null
                                  : widget.onExit,
                            ),
                            const SizedBox(width: 10),
                            AppButton(
                              label: '登录',
                              color: AppColors.blue,
                              onPressed: widget.isLoading ? null : _submit,
                              child: widget.isLoading
                                  ? const CupertinoActivityIndicator(
                                      color: CupertinoColors.white,
                                      radius: 8,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ],
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

  void _submit() {
    final account = _accountController.text.trim();
    final password = _passwordController.text;
    if (account.isEmpty || password.isEmpty) {
      return;
    }
    widget.onLogin(account: account, password: password);
  }
}

/// A text link that opens the registration page in the browser.
class _RegisterLink extends StatelessWidget {
  const _RegisterLink({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onPressed == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onPressed,
        child: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '还没有账户？',
                style: TextStyle(color: AppColors.secondaryLabel, fontSize: 13),
              ),
              TextSpan(
                text: '注册',
                style: TextStyle(
                  color: AppColors.blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
