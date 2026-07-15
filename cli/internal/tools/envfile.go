package tools

import (
	"os"
	"sort"
	"strings"
)

// parseEnv reads KEY=value lines from a .env file into a map. Missing files
// yield an empty map. Blank lines and comments are ignored.
func parseEnv(path string) (map[string]string, error) {
	env := map[string]string{}
	raw, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return env, nil
		}
		return nil, err
	}
	for _, line := range strings.Split(string(raw), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, val, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		env[strings.TrimSpace(key)] = strings.TrimSpace(val)
	}
	return env, nil
}

// serializeEnv renders a map as sorted KEY=value lines with a trailing newline.
func serializeEnv(env map[string]string) []byte {
	keys := make([]string, 0, len(env))
	for k := range env {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	var b strings.Builder
	for _, k := range keys {
		b.WriteString(k)
		b.WriteByte('=')
		b.WriteString(env[k])
		b.WriteByte('\n')
	}
	return []byte(b.String())
}
