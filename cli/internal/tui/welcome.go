package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"

	"github.com/mirrorstages/mstages/internal/models"
)

var (
	welcomeBox = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("63")).
			Padding(1, 3)

	welcomeCmd = lipgloss.NewStyle().Bold(true).Foreground(colorAccent)
)

type usage struct {
	cmd  string
	desc string
}

var usages = []usage{
	{"mstages switch node", "切换服务节点"},
	{"mclaude", "启动 Claude Code"},
	{"mcodex", "启动 Codex"},
}

// LoginSuccess renders the post-login welcome panel. It only shows the masked
// account and nickname — never the token or any other sensitive field.
func LoginSuccess(user models.UserProfile) string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("✓ 登录成功"))
	b.WriteString("\n\n")

	who := MaskAccount(user.DisplayAccount())
	if user.Nickname != "" {
		who = fmt.Sprintf("%s (%s)", user.Nickname, who)
	}
	b.WriteString(itemStyle.Render("账号  ") + successStyle.Render(who))
	b.WriteString("\n\n")

	b.WriteString(helpStyle.Render("接下来可使用："))
	b.WriteString("\n")

	width := 0
	for _, u := range usages {
		if len(u.cmd) > width {
			width = len(u.cmd)
		}
	}
	for i, u := range usages {
		if i > 0 {
			b.WriteString("\n")
		}
		pad := strings.Repeat(" ", width-len(u.cmd))
		b.WriteString("  " + welcomeCmd.Render(u.cmd) + pad + "   " + itemStyle.Render(u.desc))
	}

	return "\n" + welcomeBox.Render(b.String()) + "\n"
}

// MaskAccount hides the middle of an email or phone number so it is safe to
// show on a shared screen.
func MaskAccount(account string) string {
	if account == "" {
		return "—"
	}
	if at := strings.LastIndex(account, "@"); at > 0 {
		return maskPart(account[:at]) + account[at:]
	}
	return maskPart(account)
}

func maskPart(s string) string {
	r := []rune(s)
	if len(r) <= 2 {
		return strings.Repeat("*", len(r))
	}
	if len(r) <= 4 {
		return string(r[0]) + strings.Repeat("*", len(r)-1)
	}
	return string(r[:2]) + strings.Repeat("*", len(r)-4) + string(r[len(r)-2:])
}
