package tui

import "github.com/charmbracelet/lipgloss"

// Shared palette. Adaptive colors keep the prompts readable on both light and
// dark terminals.
var (
	colorAccent  = lipgloss.AdaptiveColor{Light: "#0E7490", Dark: "#22D3EE"}
	colorSuccess = lipgloss.AdaptiveColor{Light: "#15803D", Dark: "#4ADE80"}
	colorText    = lipgloss.AdaptiveColor{Light: "#27272A", Dark: "#D4D4D8"}
	colorMuted   = lipgloss.AdaptiveColor{Light: "#71717A", Dark: "#7D8590"}
	colorDanger  = lipgloss.AdaptiveColor{Light: "#B91C1C", Dark: "#F87171"}
)

var (
	// titleStyle is the original purple heading used across every prompt.
	titleStyle = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("63"))

	focusedStyle = lipgloss.NewStyle().Foreground(colorAccent)
	blurredStyle = lipgloss.NewStyle().Foreground(colorMuted)
	itemStyle    = lipgloss.NewStyle().Foreground(colorText)
	successStyle = lipgloss.NewStyle().Foreground(colorSuccess)
	helpStyle    = lipgloss.NewStyle().Foreground(colorMuted)
)
