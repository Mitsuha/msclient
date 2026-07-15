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
	return authCmd
}

func newLoginCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "login",
		Short: "登录并保存凭据到 ~/.mstages/credentials.json",
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
			fmt.Printf("✓ 已登录：%s\n", creds.User.DisplayAccount())
			return nil
		},
	}
}
