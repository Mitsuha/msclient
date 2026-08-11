package tui

import (
	"fmt"
	"io"
	"strconv"
	"strings"

	"github.com/charmbracelet/bubbles/list"
	tea "github.com/charmbracelet/bubbletea"

	"github.com/mirrorstages/mstages/internal/models"
)

// PayAsYouGoPackID is the sentinel pack id for 按量计费, matching
// desktop/lib/features/dashboard/billing_dialog.dart.
const PayAsYouGoPackID = 0

type packItem struct {
	id     int
	name   string
	detail string
}

func (i packItem) FilterValue() string { return i.name }

// packItems builds the selectable rows: 按量计费 first, then one per pack.
func packItems(packs []models.UserPack) []packItem {
	items := make([]packItem, 0, len(packs)+1)
	items = append(items, packItem{id: PayAsYouGoPackID, name: "按量计费"})
	for _, p := range packs {
		items = append(items, packItem{id: p.ID, name: packName(p), detail: packDetail(p)})
	}
	return items
}

// packName falls back to the pack id when the product carries no name.
func packName(p models.UserPack) string {
	if name := strings.TrimSpace(p.Product.Name); name != "" {
		return name
	}
	return "套餐 #" + strconv.Itoa(p.ID)
}

// packDetail is the dimmed suffix: remaining balance and expiry date.
func packDetail(p models.UserPack) string {
	parts := make([]string, 0, 2)
	if p.Status == models.PackExhausted {
		parts = append(parts, "已用尽")
	} else {
		parts = append(parts, "剩余 "+trimAmount(p.RemainAmount))
	}
	if day := datePart(p.ExpireAt); day != "" {
		parts = append(parts, "至 "+day)
	}
	return strings.Join(parts, " · ")
}

// trimAmount prints a balance without trailing zeros (12.50 -> 12.5, 12.00 -> 12).
func trimAmount(v float64) string {
	s := strconv.FormatFloat(v, 'f', 2, 64)
	s = strings.TrimRight(s, "0")
	return strings.TrimSuffix(s, ".")
}

// datePart keeps the date half of a timestamp, accepting both "2026-09-01"
// and "2026-09-01T00:00:00Z" style values.
func datePart(ts string) string {
	ts = strings.TrimSpace(ts)
	if len(ts) < 10 {
		return ""
	}
	return ts[:10]
}

type packDelegate struct{ selectedID int }

func (d packDelegate) Height() int                         { return 1 }
func (d packDelegate) Spacing() int                        { return 0 }
func (d packDelegate) Update(tea.Msg, *list.Model) tea.Cmd { return nil }
func (d packDelegate) Render(w io.Writer, m list.Model, index int, item list.Item) {
	it, ok := item.(packItem)
	if !ok {
		return
	}
	cursor, name := "  ", itemStyle.Render(it.name)
	if index == m.Index() {
		cursor = focusedStyle.Bold(true).Render("▸ ")
		name = focusedStyle.Bold(true).Render(it.name)
	}
	if it.detail != "" {
		name += "  " + blurredStyle.Render(it.detail)
	}
	if it.id == d.selectedID {
		name += successStyle.Render(" ✓")
	}
	fmt.Fprint(w, cursor+name)
}

type packModel struct {
	list     list.Model
	chosen   *packItem
	canceled bool
}

func (m packModel) Init() tea.Cmd { return nil }

func (m packModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.Type {
		case tea.KeyCtrlC, tea.KeyEsc:
			m.canceled = true
			return m, tea.Quit
		case tea.KeyEnter:
			if it, ok := m.list.SelectedItem().(packItem); ok {
				m.chosen = &it
			}
			return m, tea.Quit
		}
	case tea.WindowSizeMsg:
		m.list.SetWidth(msg.Width)
		// A narrower width can wrap the help line, so re-fit to keep one page.
		fitAllItems(&m.list, len(m.list.Items()))
	}
	var cmd tea.Cmd
	m.list, cmd = m.list.Update(msg)
	return m, cmd
}

func (m packModel) View() string {
	if m.chosen != nil || m.canceled {
		return ""
	}
	return "\n" + m.list.View()
}

// PackChoice is the billing option the user picked.
type PackChoice struct {
	ID   int
	Name string
}

// PromptPack shows the billing options and returns the chosen one. currentID
// is marked as the active option and starts under the cursor.
func PromptPack(packs []models.UserPack, currentID int) (*PackChoice, error) {
	options := packItems(packs)
	items := make([]list.Item, len(options))
	startIndex := 0
	for i, o := range options {
		items[i] = o
		if o.id == currentID {
			startIndex = i
		}
	}

	l := list.New(items, packDelegate{selectedID: currentID}, 48, len(options)+2)
	l.Title = "选择计费方式"
	l.Styles.Title = titleStyle
	l.SetShowStatusBar(false)
	l.SetFilteringEnabled(false)
	l.SetShowPagination(false)
	l.SetShowHelp(true)
	l.Help.Styles.ShortKey = focusedStyle
	l.Help.Styles.ShortDesc = helpStyle
	l.Help.Styles.ShortSeparator = helpStyle
	l.Help.Styles.FullKey = focusedStyle
	l.Help.Styles.FullDesc = helpStyle
	l.Help.Styles.FullSeparator = helpStyle
	l.Select(startIndex)
	fitAllItems(&l, len(options))

	final, err := tea.NewProgram(packModel{list: l}).Run()
	if err != nil {
		return nil, err
	}
	m := final.(packModel)
	if m.canceled || m.chosen == nil {
		return nil, ErrCancelled
	}
	return &PackChoice{ID: m.chosen.id, Name: m.chosen.name}, nil
}
