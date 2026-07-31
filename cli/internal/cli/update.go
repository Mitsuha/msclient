package cli

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/mirrorstages/mstages/internal/app"
	"github.com/mirrorstages/mstages/internal/download"
	"github.com/mirrorstages/mstages/internal/tui"
	"github.com/mirrorstages/mstages/internal/update"
)

// UpdateGate runs the startup update check and reports whether the process
// should stop here.
//
// The check is silent: when the CLI is current — or the network is down, or the
// manifest is unreadable — nothing is printed and the caller carries on. Only a
// published newer version puts anything on screen.
//
// The update is always installed; cli_forced only decides what happens next.
// A forced release stops the run, because this process is still the old binary
// and the release was flagged as one nobody should keep running — the panel
// tells the user to run their command again. An unforced release lets the run
// continue on the old binary; the new one takes over at the next launch.
func UpdateGate(ctx context.Context) bool {
	if os.Getenv("MSTAGES_NO_UPDATE") != "" {
		return false
	}
	manifest, err := update.Check(ctx)
	if err != nil || manifest == nil {
		return false
	}
	version := manifest.ReleaseVersion()

	// A local build or a copy outside install.sh's layout is not ours to
	// replace; say how to upgrade and let the user get on with their work.
	if !update.SelfManaged() {
		fmt.Fprint(os.Stderr, tui.UpdateUnmanaged(version, app.InstallCommand))
		return false
	}

	fmt.Fprint(os.Stderr, tui.UpdateAvailable(update.Current(), version))
	err = tui.Download("下载 MirrorStages CLI "+version,
		func(report download.ProgressFunc) error {
			return update.Apply(ctx, manifest, report)
		})
	if err != nil {
		// The previous version is still linked and working, so a failed update
		// is a warning, not a reason to stop.
		fmt.Fprintf(os.Stderr, "mstages: 更新失败，继续使用当前版本: %v\n", err)
		return false
	}

	if manifest.IsForced() {
		fmt.Fprint(os.Stderr, tui.UpdateSuccess(version, invokedCommand()))
		return true
	}
	fmt.Fprint(os.Stderr, tui.UpdateInstalled(version))
	return false
}

// invokedCommand rebuilds the command line to re-run, with the persona name as
// the user typed it rather than the absolute path of the symlink.
func invokedCommand() string {
	parts := append([]string{filepath.Base(os.Args[0])}, os.Args[1:]...)
	return strings.Join(parts, " ")
}
