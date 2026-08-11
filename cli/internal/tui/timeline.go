package tui

import (
	"fmt"
	"io"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/charmbracelet/lipgloss"
)

var spinnerFrames = []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}

// Timeline draws a launch sequence as a vertical timeline: one node per step,
// a spinner on the step currently running, and indented detail rows beneath it.
//
// Everything goes to stderr, leaving stdout to the tool we eventually hand the
// terminal to. When stderr is not a terminal the spinner is dropped and each
// node prints as a single plain line once it completes.
type Timeline struct {
	w   io.Writer
	tty bool

	title   lipgloss.Style
	rail    lipgloss.Style
	pending lipgloss.Style
	ok      lipgloss.Style
	bad     lipgloss.Style
	label   lipgloss.Style
	key     lipgloss.Style

	// mu guards writes to w: the spinner goroutine and the caller both write.
	mu      sync.Mutex
	stop    chan struct{}
	wg      sync.WaitGroup
	current string
	active  bool
}

// NewTimeline prints the header and returns a timeline ready for its first
// step.
func NewTimeline(title string) *Timeline {
	return newTimeline(os.Stderr, isTerminal(os.Stderr), title)
}

func newTimeline(w io.Writer, tty bool, title string) *Timeline {
	r := lipgloss.NewRenderer(os.Stderr)
	t := &Timeline{
		w:       w,
		tty:     tty,
		title:   r.NewStyle().Bold(true).Foreground(lipgloss.Color("63")),
		rail:    r.NewStyle().Foreground(colorMuted),
		pending: r.NewStyle().Foreground(colorAccent),
		ok:      r.NewStyle().Foreground(colorSuccess),
		bad:     r.NewStyle().Foreground(colorDanger),
		label:   r.NewStyle().Foreground(colorText),
		key:     r.NewStyle().Foreground(colorMuted),
	}
	fmt.Fprintf(t.w, "\n  %s\n", t.title.Render("◆ "+title))
	return t
}

// Start opens a node. The label may be replaced when the step completes, so
// nothing is committed to the screen yet on a dumb terminal.
func (t *Timeline) Start(label string) {
	t.mu.Lock()
	t.current = label
	t.active = true
	t.railLine()
	t.mu.Unlock()

	if !t.tty {
		return
	}
	t.stop = make(chan struct{})
	t.wg.Add(1)
	go t.animate()
}

// Done closes the current node as successful. An optional label replaces the
// one given to Start, so a step can report what it actually did ("使用账号"
// versus "已申请到账号") only once it knows.
func (t *Timeline) Done(label ...string) {
	t.settle(t.ok, "●", label...)
}

// Fail closes the current node as failed, leaving the reason to the caller. It
// is a no-op when no node is open, so callers can route every error through it.
func (t *Timeline) Fail() {
	t.mu.Lock()
	open := t.active
	t.mu.Unlock()
	if !open {
		return
	}
	t.settle(t.bad, "✖")
}

// Details prints aligned key/value rows hanging off the last node. Callers pass
// display text only — never tokens or other secrets.
func (t *Timeline) Details(rows ...[2]string) {
	width := 0
	for _, row := range rows {
		if w := lipgloss.Width(row[0]); w > width {
			width = w
		}
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	for _, row := range rows {
		if row[1] == "" {
			continue
		}
		pad := strings.Repeat(" ", width-lipgloss.Width(row[0]))
		fmt.Fprintf(t.w, "  %s    %s%s   %s\n",
			t.rail.Render("│"), t.key.Render(row[0]), pad, t.label.Render(row[1]))
	}
}

// Finish closes the rail with a final line and a trailing blank line.
func (t *Timeline) Finish(msg string) {
	t.mu.Lock()
	defer t.mu.Unlock()
	fmt.Fprintf(t.w, "  %s\n  %s\n\n", t.rail.Render("│"), t.rail.Render("╰─ ")+t.label.Render(msg))
}

// railLine draws the connector above a node, linking it to the header or to
// the previous node. The caller holds mu.
func (t *Timeline) railLine() {
	fmt.Fprintf(t.w, "  %s\n", t.rail.Render("│"))
}

// settle stops the spinner and commits the node's final line.
func (t *Timeline) settle(marker lipgloss.Style, glyph string, label ...string) {
	if t.tty && t.stop != nil {
		close(t.stop)
		t.wg.Wait()
		t.stop = nil
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	t.active = false
	if len(label) > 0 && label[0] != "" {
		t.current = label[0]
	}
	if t.tty {
		fmt.Fprint(t.w, "\r\033[K")
	}
	fmt.Fprintf(t.w, "  %s  %s\n", marker.Render(glyph), t.label.Render(t.current))
}

// animate redraws the pending node in place until settle closes stop.
func (t *Timeline) animate() {
	defer t.wg.Done()
	ticker := time.NewTicker(90 * time.Millisecond)
	defer ticker.Stop()
	for i := 0; ; i++ {
		t.mu.Lock()
		fmt.Fprintf(t.w, "\r  %s  %s",
			t.pending.Render(spinnerFrames[i%len(spinnerFrames)]), t.label.Render(t.current))
		t.mu.Unlock()
		select {
		case <-t.stop:
			return
		case <-ticker.C:
		}
	}
}

// isTerminal reports whether f is attached to a terminal, so the timeline knows
// whether in-place redraws are safe.
func isTerminal(f *os.File) bool {
	info, err := f.Stat()
	if err != nil {
		return false
	}
	return info.Mode()&os.ModeCharDevice != 0
}
