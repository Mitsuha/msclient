package cli

import (
	"errors"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/mirrorstages/mstages/internal/api"
	"github.com/mirrorstages/mstages/internal/config"
	"github.com/mirrorstages/mstages/internal/singbox"
	"github.com/mirrorstages/mstages/internal/tui"
)

func newSwitchCmd() *cobra.Command {
	switchCmd := &cobra.Command{
		Use:   "switch",
		Short: "切换设置",
	}
	switchCmd.AddCommand(newSwitchNodeCmd())
	return switchCmd
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
