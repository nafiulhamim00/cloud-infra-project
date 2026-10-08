package docker

import (
	"os"
	"testing"
)

// TestFilesExist is a basic smoke test students can run locally: it checks
// that the four files graded by QuickFeed exist.
func TestFilesExist(t *testing.T) {
	files := []string{
		"app/Dockerfile",
		"stack/compose.yaml",
		"stack/compose.dev.yaml",
		"stack/compose.prod.yaml",
	}
	for _, f := range files {
		if _, err := os.Stat(f); os.IsNotExist(err) {
			t.Errorf("missing required file: %s", f)
		}
	}
}

// TestFilesParse checks that the Dockerfile and compose files are at least
// syntactically valid.
func TestFilesParse(t *testing.T) {
	if _, err := parseDockerfile("app/Dockerfile"); err != nil {
		t.Errorf("could not parse app/Dockerfile: %v", err)
	}

	composeFiles := []string{
		"stack/compose.yaml",
		"stack/compose.dev.yaml",
		"stack/compose.prod.yaml",
	}
	for _, f := range composeFiles {
		if _, err := loadCompose(f); err != nil {
			t.Errorf("could not parse %s: %v", f, err)
		}
	}
}
