package tui

import (
	"fmt"
	"io"

	"github.com/charmbracelet/bubbles/list"
	tea "github.com/charmbracelet/bubbletea"

	"github.com/mirrorstages/mstages/internal/models"
)

type nodeItem struct {
	option models.ClientProxyOption
}

func (i nodeItem) FilterValue() string { return i.option.Name }

type nodeDelegate struct{ selectedURL string }

func (d nodeDelegate) Height() int                         { return 1 }
func (d nodeDelegate) Spacing() int                        { return 0 }
func (d nodeDelegate) Update(tea.Msg, *list.Model) tea.Cmd { return nil }
func (d nodeDelegate) Render(w io.Writer, m list.Model, index int, item list.Item) {
	it, ok := item.(nodeItem)
	if !ok {
		return
	}
	name := it.option.Name
	if it.option.URL == d.selectedURL {
		name += " ✓"
	}
	line := "  " + name
	if index == m.Index() {
		line = focusedStyle.Render("▸ " + name)
	}
	fmt.Fprint(w, line)
}

type nodeModel struct {
	list     list.Model
	chosen   *models.ClientProxyOption
	canceled bool
}

func (m nodeModel) Init() tea.Cmd { return nil }

func (m nodeModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.Type {
		case tea.KeyCtrlC, tea.KeyEsc:
			m.canceled = true
			return m, tea.Quit
		case tea.KeyEnter:
			if it, ok := m.list.SelectedItem().(nodeItem); ok {
				opt := it.option
				m.chosen = &opt
			}
			return m, tea.Quit
		}
	case tea.WindowSizeMsg:
		m.list.SetWidth(msg.Width)
	}
	var cmd tea.Cmd
	m.list, cmd = m.list.Update(msg)
	return m, cmd
}

func (m nodeModel) View() string {
	if m.chosen != nil || m.canceled {
		return ""
	}
	return "\n" + m.list.View()
}

// PromptNode shows the node list and returns the chosen option. currentURL, if
// non-empty, is marked as the active node.
func PromptNode(options []models.ClientProxyOption, currentURL string) (*models.ClientProxyOption, error) {
	items := make([]list.Item, len(options))
	startIndex := 0
	for i, o := range options {
		items[i] = nodeItem{option: o}
		if o.URL == currentURL {
			startIndex = i
		}
	}

	l := list.New(items, nodeDelegate{selectedURL: currentURL}, 40, min(len(options)+2, 14))
	l.Title = "选择代理节点"
	l.Styles.Title = titleStyle
	l.SetShowStatusBar(false)
	l.SetFilteringEnabled(false)
	l.SetShowHelp(true)
	l.Select(startIndex)

	final, err := tea.NewProgram(nodeModel{list: l}).Run()
	if err != nil {
		return nil, err
	}
	m := final.(nodeModel)
	if m.canceled || m.chosen == nil {
		return nil, ErrCancelled
	}
	return m.chosen, nil
}
