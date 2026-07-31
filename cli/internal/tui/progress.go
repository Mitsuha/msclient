// Package tui holds the Bubble Tea interfaces: login form, download progress,
// and node selection.
package tui

import (
	"context"
	"fmt"

	"github.com/charmbracelet/bubbles/progress"
	tea "github.com/charmbracelet/bubbletea"

	"github.com/mirrorstages/mstages/internal/download"
	"github.com/mirrorstages/mstages/internal/singbox"
)

type progressMsg struct {
	downloaded int64
	total      int64
}

type doneMsg struct{ err error }

type progressModel struct {
	title      string
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
	title := titleStyle.Render(m.title)
	var body string
	if m.total > 0 {
		ratio := float64(m.downloaded) / float64(m.total)
		counts := fmt.Sprintf("  %s / %s", humanBytes(m.downloaded), humanBytes(m.total))
		body = m.bar.ViewAs(ratio) + helpStyle.Render(counts)
	} else {
		body = helpStyle.Render(fmt.Sprintf("已下载 %s…", humanBytes(m.downloaded)))
	}
	return fmt.Sprintf("\n  %s\n\n  %s\n\n", title, body)
}

// DownloadSingbox downloads the sing-box binary showing a progress bar, and
// returns its path. Callers should only invoke this when the binary is missing.
func DownloadSingbox(ctx context.Context) (string, error) {
	var path string
	err := Download("下载 sing-box 代理内核", func(report download.ProgressFunc) error {
		var err error
		path, err = singbox.EnsureInstalled(ctx, singbox.ProgressFunc(report))
		return err
	})
	return path, err
}

// Download runs work under a progress bar titled title. work reports progress
// through the callback it is given; the bar closes when work returns.
func Download(title string, work func(report download.ProgressFunc) error) error {
	m := progressModel{
		title: title,
		bar:   progress.New(progress.WithScaledGradient("#155E75", "#22D3EE")),
	}
	p := tea.NewProgram(m)

	var workErr error
	go func() {
		workErr = work(func(d, t int64) {
			p.Send(progressMsg{downloaded: d, total: t})
		})
		p.Send(doneMsg{err: workErr})
	}()

	if _, err := p.Run(); err != nil {
		return err
	}
	return workErr
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
