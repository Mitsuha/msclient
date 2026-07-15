package tui

import (
	"errors"
	"fmt"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// ErrCancelled is returned when the user aborts a TUI prompt.
var ErrCancelled = errors.New("cancelled")

var (
	focusedStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))
	blurredStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("240"))
	titleStyle   = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("63"))
	helpStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("240"))
)

type loginModel struct {
	inputs   []textinput.Model
	focus    int
	done     bool
	canceled bool
}

func newLoginModel() loginModel {
	account := textinput.New()
	account.Placeholder = "邮箱或手机号"
	account.Focus()
	account.PromptStyle = focusedStyle
	account.TextStyle = focusedStyle
	account.CharLimit = 128

	password := textinput.New()
	password.Placeholder = "密码"
	password.EchoMode = textinput.EchoPassword
	password.EchoCharacter = '•'
	password.CharLimit = 128

	return loginModel{inputs: []textinput.Model{account, password}}
}

func (m loginModel) Init() tea.Cmd { return textinput.Blink }

func (m loginModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyMsg); ok {
		switch key.Type {
		case tea.KeyCtrlC, tea.KeyEsc:
			m.canceled = true
			return m, tea.Quit
		case tea.KeyEnter:
			if m.focus == len(m.inputs)-1 {
				m.done = true
				return m, tea.Quit
			}
			m.focus++
			return m, m.refocus()
		case tea.KeyTab, tea.KeyDown:
			m.focus = (m.focus + 1) % len(m.inputs)
			return m, m.refocus()
		case tea.KeyShiftTab, tea.KeyUp:
			m.focus = (m.focus - 1 + len(m.inputs)) % len(m.inputs)
			return m, m.refocus()
		}
	}

	var cmd tea.Cmd
	m.inputs[m.focus], cmd = m.inputs[m.focus].Update(msg)
	return m, cmd
}

func (m *loginModel) refocus() tea.Cmd {
	var cmd tea.Cmd
	for i := range m.inputs {
		if i == m.focus {
			cmd = m.inputs[i].Focus()
			m.inputs[i].PromptStyle = focusedStyle
			m.inputs[i].TextStyle = focusedStyle
		} else {
			m.inputs[i].Blur()
			m.inputs[i].PromptStyle = blurredStyle
			m.inputs[i].TextStyle = blurredStyle
		}
	}
	return cmd
}

func (m loginModel) View() string {
	if m.done || m.canceled {
		return ""
	}
	s := "\n  " + titleStyle.Render("登录 MirrorStages") + "\n\n"
	labels := []string{"账号", "密码"}
	for i, in := range m.inputs {
		s += fmt.Sprintf("  %s\n  %s\n\n", labels[i], in.View())
	}
	s += "  " + helpStyle.Render("Tab 切换 · Enter 提交 · Esc 取消") + "\n"
	return s
}

// PromptLogin shows the login form and returns the entered account/password.
func PromptLogin() (account, password string, err error) {
	final, err := tea.NewProgram(newLoginModel()).Run()
	if err != nil {
		return "", "", err
	}
	m := final.(loginModel)
	if m.canceled || !m.done {
		return "", "", ErrCancelled
	}
	return m.inputs[0].Value(), m.inputs[1].Value(), nil
}
