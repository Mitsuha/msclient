// Command mstages is the MirrorStages CLI. It is a single binary that changes
// behavior based on the name it is invoked as:
//
//	mstages   — the management CLI (auth login, switch node)
//	mcodex    — initialize + launch `codex` through the MirrorStages proxy
//	mclaude   — initialize + launch `claude` through the MirrorStages proxy
//
// Install mcodex/mclaude as symlinks to the mstages binary; identity is
// resolved from os.Args[0]'s basename.
package main

import (
	"context"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"

	"github.com/mirrorstages/mstages/internal/cli"
	"github.com/mirrorstages/mstages/internal/tools"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	switch invokedName() {
	case "mcodex":
		os.Exit(tools.Run(ctx, tools.Codex))
	case "mclaude":
		os.Exit(tools.Run(ctx, tools.Claude))
	default:
		cli.Execute(ctx)
	}
}

// invokedName returns the lowercase basename of the executable without any
// platform extension, used to decide which persona to run as.
func invokedName() string {
	base := filepath.Base(os.Args[0])
	base = strings.TrimSuffix(base, filepath.Ext(base))
	return strings.ToLower(base)
}
