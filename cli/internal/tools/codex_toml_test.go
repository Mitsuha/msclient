package tools

import "testing"

// Only the four managed assignments go; everything else — comments, blank
// lines, unrelated keys, spacing — has to survive byte for byte.
func TestPruneTOMLKeysRemovesOnlyManagedKeys(t *testing.T) {
	in := "# my codex config\n" +
		"model_provider = \"openai\"\n" +
		"model= \"gpt-5\"\n" +
		"  model_reasoning_effort = \"high\"\n" +
		"disable_response_storage = true\n" +
		"approval_policy = \"on-request\"\n" +
		"sandbox_mode = \"workspace-write\"\n"
	want := "# my codex config\n" +
		"approval_policy = \"on-request\"\n" +
		"sandbox_mode = \"workspace-write\"\n"

	if got := pruneTOMLKeys(in); got != want {
		t.Errorf("pruneTOMLKeys() =\n%q\nwant\n%q", got, want)
	}
}

// A key inside the user's own table is not a top-level override, so the shallow
// line scan must stop claiming lines once a [table] header appears.
func TestPruneTOMLKeysLeavesTablesAlone(t *testing.T) {
	in := "model = \"gpt-5\"\n" +
		"\n" +
		"[model_providers.custom]\n" +
		"model = \"local-llama\"\n" +
		"base_url = \"http://localhost:1234\"\n"
	want := "\n" +
		"[model_providers.custom]\n" +
		"model = \"local-llama\"\n" +
		"base_url = \"http://localhost:1234\"\n"

	if got := pruneTOMLKeys(in); got != want {
		t.Errorf("pruneTOMLKeys() =\n%q\nwant\n%q", got, want)
	}
}

// A commented-out assignment is documentation, not configuration.
func TestPruneTOMLKeysKeepsComments(t *testing.T) {
	in := "# model = \"gpt-5\"\nmodel = \"gpt-5\"\n"
	if got := pruneTOMLKeys(in); got != "# model = \"gpt-5\"\n" {
		t.Errorf("pruneTOMLKeys() = %q", got)
	}
}

// Nothing to prune must leave the content identical, so pruneProviderConfig can
// skip the write entirely.
func TestPruneTOMLKeysUntouchedContent(t *testing.T) {
	in := "approval_policy = \"never\"\n[profiles.work]\nmodel = \"gpt-5\"\n"
	if got := pruneTOMLKeys(in); got != in {
		t.Errorf("pruneTOMLKeys() = %q, want it unchanged", got)
	}
}
