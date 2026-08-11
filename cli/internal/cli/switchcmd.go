package cli

import (
	"errors"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/mirrorstages/mstages/internal/api"
	"github.com/mirrorstages/mstages/internal/auth"
	"github.com/mirrorstages/mstages/internal/config"
	"github.com/mirrorstages/mstages/internal/singbox"
	"github.com/mirrorstages/mstages/internal/tui"
)

func newSwitchCmd() *cobra.Command {
	switchCmd := &cobra.Command{
		Use:   "switch",
		Short: "切换设置",
	}
	switchCmd.AddCommand(newSwitchNodeCmd(), newSwitchBillingCmd())
	return switchCmd
}

func newSwitchBillingCmd() *cobra.Command {
	return &cobra.Command{
		Use:     "billing",
		Short:   "选择计费方式（按量计费或某个套餐）并持久化到 ~/.mstages/config.json",
		Aliases: []string{"pack"},
		RunE: func(cmd *cobra.Command, _ []string) error {
			ctx := cmd.Context()

			creds, err := auth.Load()
			if err != nil {
				return err
			}

			packs, err := api.New().UserPacks(ctx, creds.Token)
			if err != nil {
				var apiErr *api.Error
				if errors.As(err, &apiErr) && apiErr.Unauthorized() {
					_ = auth.Clear()
					return fmt.Errorf("登录已失效，请重新运行 `mstages auth login`")
				}
				return fmt.Errorf("获取套餐列表失败: %w", err)
			}

			cfg, err := config.Load()
			if err != nil {
				return err
			}

			chosen, err := tui.PromptPack(packs, cfg.UserPackID)
			if errors.Is(err, tui.ErrCancelled) {
				return nil
			}
			if err != nil {
				return err
			}

			if chosen.ID == cfg.UserPackID {
				fmt.Printf("✓ 计费方式未变：%s\n", chosen.Name)
				return nil
			}
			if err := config.SelectPack(chosen.ID); err != nil {
				return err
			}

			// The account on disk is billed against the old pack, so it is
			// replaced on the next launch rather than here: a running session
			// keeps the credentials it started with.
			fmt.Printf("✓ 已切换计费方式：%s\n", chosen.Name)
			fmt.Println("  下次启动 mcodex / mclaude 时生效")
			return nil
		},
	}
}

func newSwitchNodeCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "node",
		Short: "选择代理节点并持久化到 ~/.mstages/config.json",
		RunE: func(cmd *cobra.Command, _ []string) error {
			ctx := cmd.Context()

			options, err := api.New().ClientProxyOptions(ctx)
			if err != nil {
				return fmt.Errorf("获取节点列表失败: %w", err)
			}

			cfg, err := config.Load()
			if err != nil {
				return err
			}

			chosen, err := tui.PromptNode(options, cfg.SelectedNodeURL)
			if errors.Is(err, tui.ErrCancelled) {
				return nil
			}
			if err != nil {
				return err
			}

			if err := config.SelectNode(chosen.URL); err != nil {
				return err
			}

			// If sing-box is running, switch the selector live.
			if singbox.ClashHealthy(ctx) {
				if built, err := singbox.BuildConfig(options, chosen.URL); err == nil {
					_ = singbox.SelectOutbound(ctx, built.DefaultTag)
				}
			}

			fmt.Printf("✓ 已切换节点：%s\n", chosen.Name)
			return nil
		},
	}
}
