package tui

import (
	"bytes"
	"strings"
	"testing"
)

// newTestTimeline builds a timeline writing to a buffer with the spinner off,
// which is what a piped stderr gets.
func newTestTimeline(buf *bytes.Buffer) *Timeline {
	tl := newTimeline(buf, false, "MirrorStages")
	tl.minStep = 0
	buf.Reset() // drop the header; the tests are about the nodes
	return tl
}

func TestTimelineRendersNodesInOrder(t *testing.T) {
	var buf bytes.Buffer
	tl := newTestTimeline(&buf)
	tl.Start("正在启动服务")
	tl.Done("服务已就绪")
	tl.Start("正在获取账号")
	tl.Done("已申请到账号")
	tl.Details([2]string{"邮箱", "a@b.com"}, [2]string{"用户名", "Someone"}, [2]string{"套餐", ""})
	tl.Finish("正在启动 Codex")

	out := buf.String()
	if strings.Contains(out, "\r") || strings.Contains(out, "\033[K") {
		t.Error("a non-terminal writer must not receive in-place redraws")
	}
	// The pending label is replaced, not printed alongside the final one.
	if strings.Contains(out, "正在启动服务") {
		t.Error("pending label leaked into the committed output")
	}
	for _, want := range []string{"服务已就绪", "已申请到账号", "a@b.com", "正在启动 Codex"} {
		if !strings.Contains(out, want) {
			t.Errorf("output is missing %q:\n%s", want, out)
		}
	}
	if strings.Contains(out, "套餐") {
		t.Error("a detail row with an empty value should be skipped")
	}
	if i, j := strings.Index(out, "服务已就绪"), strings.Index(out, "已申请到账号"); i > j {
		t.Error("nodes are out of order")
	}
}

// Fail outside a node would otherwise re-commit the previous node's label with
// a cross next to it.
func TestTimelineFailWithoutOpenNode(t *testing.T) {
	var buf bytes.Buffer
	tl := newTestTimeline(&buf)
	tl.Start("正在备份配置")
	tl.Done("配置已备份")
	buf.Reset()
	tl.Fail()
	if buf.Len() != 0 {
		t.Errorf("expected no output, got %q", buf.String())
	}
}

func TestTimelineFailMarksOpenNode(t *testing.T) {
	var buf bytes.Buffer
	tl := newTestTimeline(&buf)
	tl.Start("正在启动服务")
	tl.Fail()
	if !strings.Contains(buf.String(), "✖") {
		t.Errorf("expected a failure marker:\n%s", buf.String())
	}
}
