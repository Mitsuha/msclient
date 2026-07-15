// Package cli wires the `mstages` management commands (auth, switch) with cobra.
package cli

import (
	"context"
	"os"

	"github.com/spf13/cobra"
)

// Execute runs the mstages root command.
func Execute(ctx context.Context) {
	root := &cobra.Command{
		Use:           "mstages",
		Short:         "MirrorStages CLI — 登录并通过代理运行 AI 命令行工具",
		SilenceUsage:  true,
		SilenceErrors: false,
	}
	root.AddCommand(newAuthCmd(), newSwitchCmd())

	if err := root.ExecuteContext(ctx); err != nil {
		os.Exit(1)
	}
}
