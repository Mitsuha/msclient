package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

var updateVersion = lipgloss.NewStyle().Bold(true).Foreground(colorAccent)

// UpdateAvailable announces a newer release before the download starts.
func UpdateAvailable(current, latest string) string {
	return fmt.Sprintf("\n  %s  %s %s %s\n",
		titleStyle.Render("↑ 发现新版本"),
		helpStyle.Render(current),
		helpStyle.Render("→"),
		updateVersion.Render(latest))
}

// UpdateInstalled reports an unforced update that is already in place. The
// current run continues on the old binary, so the line says when the new one
// actually takes over.
func UpdateInstalled(version string) string {
	return fmt.Sprintf("  %s %s\n  %s\n\n",
		successStyle.Render("✓ 已更新到"),
		updateVersion.Render(version),
		helpStyle.Render("下次启动即为新版本，本次继续使用当前版本"))
}

// UpdateSuccess renders the panel shown after a forced update. The running
// binary is the old version, so the user has to run the command again — that
// instruction is the whole point of the panel.
func UpdateSuccess(version, command string) string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("✓ 更新完成"))
	b.WriteString("\n\n")
	b.WriteString(itemStyle.Render("版本  ") + successStyle.Render(version))
	b.WriteString("\n\n")
	b.WriteString(helpStyle.Render("请重新执行以下命令继续："))
	b.WriteString("\n  ")
	b.WriteString(welcomeCmd.Render(command))

	return "\n" + welcomeBox.Render(b.String()) + "\n"
}

// UpdateUnmanaged tells the user how to upgrade when this binary is not the one
// install.sh manages and so cannot replace itself.
func UpdateUnmanaged(latest, command string) string {
	return fmt.Sprintf("\n  %s %s\n  %s\n\n",
		titleStyle.Render("↑ 有新版本"),
		updateVersion.Render(latest),
		helpStyle.Render("当前程序不是由安装脚本管理的，请手动执行："+command))
}
