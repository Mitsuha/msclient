// Package tui holds the Bubble Tea interfaces: login form, download progress,
// and node selection.
package tui

import (
	"context"
	"fmt"

	"github.com/charmbracelet/bubbles/progress"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"github.com/mirrorstages/mstages/internal/singbox"
)

type progressMsg struct {
	downloaded int64
	total      int64
}

type doneMsg struct{ err error }

type progressModel struct {
	bar        progress.Model
	downloaded int64
	total      int64
	done       bool
	err        error
}

func (m progressModel) Init() tea.Cmd { return nil }

func (m progressModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case progressMsg:
		m.downloaded = msg.downloaded
		m.total = msg.total
		return m, nil
	case doneMsg:
		m.done = true
		m.err = msg.err
		return m, tea.Quit
	case tea.WindowSizeMsg:
		m.bar.Width = min(msg.Width-4, 60)
		return m, nil
	case tea.KeyMsg:
		if msg.Type == tea.KeyCtrlC {
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m progressModel) View() string {
	title := lipgloss.NewStyle().Bold(true).Render("下载 sing-box 代理内核")
	var body string
	if m.total > 0 {
		ratio := float64(m.downloaded) / float64(m.total)
		body = m.bar.ViewAs(ratio) + fmt.Sprintf("  %s / %s", humanBytes(m.downloaded), humanBytes(m.total))
	} else {
		body = fmt.Sprintf("已下载 %s…", humanBytes(m.downloaded))
	}
	return fmt.Sprintf("\n  %s\n\n  %s\n\n", title, body)
}

// DownloadSingbox downloads the sing-box binary showing a progress bar, and
// returns its path. Callers should only invoke this when the binary is missing.
func DownloadSingbox(ctx context.Context) (string, error) {
	m := progressModel{bar: progress.New(progress.WithDefaultGradient())}
	p := tea.NewProgram(m)

	var resultPath string
	var resultErr error
	go func() {
		path, err := singbox.EnsureInstalled(ctx, func(d, t int64) {
			p.Send(progressMsg{downloaded: d, total: t})
		})
		resultPath = path
		resultErr = err
		p.Send(doneMsg{err: err})
	}()

	if _, err := p.Run(); err != nil {
		return "", err
	}
	return resultPath, resultErr
}

func humanBytes(n int64) string {
	const unit = 1024
	if n < unit {
		return fmt.Sprintf("%d B", n)
	}
	div, exp := int64(unit), 0
	for x := n / unit; x >= unit; x /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(n)/float64(div), "KMGT"[exp])
}
