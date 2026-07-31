// Package tools implements the mcodex/mclaude personas: initialize a local AI
// CLI tool with MirrorStages credentials and proxy settings, launch it with
// stdio passed through, and restore the user's original config once the last
// mstages process on the machine exits.
package tools

import "context"

// Kind identifies which downstream tool a persona wraps.
type Kind int

const (
	// Codex wraps the `codex` CLI.
	Codex Kind = iota
	// Claude wraps the `claude` CLI.
	Claude
)

// tool abstracts the codex/claude specific configuration behavior.
type tool interface {
	// name is the persona label used in log messages.
	name() string
	// displayName is the product name shown to the user.
	displayName() string
	// executable is the downstream command to launch (e.g. "codex").
	executable() string
	// account reports the MirrorStages account currently configured on disk.
	// It returns nil when there is no config, or when the config was not
	// issued by MirrorStages and a fresh account must be requested.
	account() (*accountInfo, error)
	// performBackup snapshots the user's original config. It only runs when
	// the on-disk config is about to be replaced, so reusing an account never
	// overwrites the snapshot of the user's own setup.
	performBackup() error
	// restoreBackup puts the user's original config back. It is idempotent and
	// reads its manifest from disk, so it works even when the backup was taken
	// by a different mstages process.
	restoreBackup() error
	// requestAccount asks the backend for an account. It performs no disk
	// writes, so the caller can back up the user's config in between.
	requestAccount(ctx context.Context, token string) (*pendingAccount, error)
	// writeAccount persists a previously requested account.
	writeAccount(pending *pendingAccount) error
	// applyProxy writes the loopback proxy and CA settings. It is idempotent
	// and runs on every launch, including when the account is reused.
	applyProxy() error
}

// newTool constructs the tool implementation for a Kind.
func newTool(kind Kind) tool {
	switch kind {
	case Claude:
		return &claudeTool{}
	default:
		return &codexTool{}
	}
}

// allTools returns one implementation per Kind. The cleanup path uses it to
// restore every tool's leftover backup, not just the one this process ran.
func allTools() []tool {
	return []tool{newTool(Claude), newTool(Codex)}
}
