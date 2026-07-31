package cli

import (
	"errors"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/mirrorstages/mstages/internal/api"
	"github.com/mirrorstages/mstages/internal/auth"
	"github.com/mirrorstages/mstages/internal/tui"
)

func newAuthCmd() *cobra.Command {
	authCmd := &cobra.Command{
		Use:   "auth",
		Short: "账号认证",
	}
	authCmd.AddCommand(newLoginCmd())
	authCmd.AddCommand(newLogoutCmd())
	return authCmd
}

func newLogoutCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "logout",
		Short: "退出登录",
		RunE: func(_ *cobra.Command, _ []string) error {
			creds, err := auth.Load()
			if errors.Is(err, auth.ErrNotLoggedIn) {
				fmt.Println("当前未登录")
				return nil
			}
			if err != nil {
				return err
			}
			if err := auth.Clear(); err != nil {
				return err
			}
			fmt.Printf("✓ 已退出登录：%s\n", tui.MaskAccount(creds.User.DisplayAccount()))
			return nil
		},
	}
}

func newLoginCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "login",
		Short: "登录 Mirror stages",
		RunE: func(cmd *cobra.Command, _ []string) error {
			account, password, err := tui.PromptLogin()
			if errors.Is(err, tui.ErrCancelled) {
				return nil
			}
			if err != nil {
				return err
			}

			creds, err := auth.Login(cmd.Context(), account, password)
			if err != nil {
				var apiErr *api.Error
				if errors.As(err, &apiErr) && apiErr.Unauthorized() {
					return fmt.Errorf("账号或密码错误")
				}
				return err
			}
			fmt.Println(tui.LoginSuccess(creds.User))
			return nil
		},
	}
}
