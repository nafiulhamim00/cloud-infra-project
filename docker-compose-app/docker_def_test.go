package docker

import (
	"encoding/json"
	"os"
	"regexp"
	"strings"

	"sigs.k8s.io/yaml"
)

// instr is a single parsed Dockerfile instruction, e.g. {"FROM", "golang:1.26-alpine AS builder"}.
type instr struct {
	Instruction string
	Args        string
}

var lineContinuation = regexp.MustCompile(`\\\s*\r?\n`)

// parseDockerfile reads a Dockerfile, joins backslash line continuations,
// strips comments and blank lines, and splits each remaining line into an
// instruction and its arguments.
func parseDockerfile(path string) ([]instr, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	joined := lineContinuation.ReplaceAllString(string(data), " ")

	var instrs []instr
	for _, line := range strings.Split(joined, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		fields := strings.SplitN(line, " ", 2)
		ins := instr{Instruction: strings.ToUpper(fields[0])}
		if len(fields) > 1 {
			ins.Args = strings.TrimSpace(fields[1])
		}
		instrs = append(instrs, ins)
	}
	return instrs, nil
}

// findFirstIndex returns the index of the first instruction matching pred, or -1.
func findFirstIndex(instrs []instr, pred func(instr) bool) int {
	for i, ins := range instrs {
		if pred(ins) {
			return i
		}
	}
	return -1
}

// hasInstruction reports whether any instruction has the given name.
func hasInstruction(instrs []instr, name string) bool {
	for _, ins := range instrs {
		if ins.Instruction == name {
			return true
		}
	}
	return false
}

// composeFile is a typed, partial model of a docker compose file. Fields are
// typed (rather than map[string]any) so that, e.g., deploy.replicas decodes
// as a Go int instead of a float64.
type composeFile struct {
	Services map[string]composeService `json:"services"`
	Volumes  map[string]any            `json:"volumes"`
	Secrets  map[string]composeSecret  `json:"secrets"`
}

type composeService struct {
	Build       *composeBuild       `json:"build"`
	Image       string              `json:"image"`
	Environment json.RawMessage     `json:"environment"`
	Ports       []string            `json:"ports"`
	Networks    []string            `json:"networks"`
	DependsOn   json.RawMessage     `json:"depends_on"`
	Healthcheck *composeHealthcheck `json:"healthcheck"`
	Deploy      *composeDeploy      `json:"deploy"`
	Secrets     []string            `json:"secrets"`
}

type composeBuild struct {
	Context string `json:"context"`
}

type composeHealthcheck struct {
	Test        any    `json:"test"`
	Interval    string `json:"interval"`
	Timeout     string `json:"timeout"`
	Retries     int    `json:"retries"`
	StartPeriod string `json:"start_period"`
}

type composeDeploy struct {
	Replicas  int               `json:"replicas"`
	Resources *composeResources `json:"resources"`
}

type composeResources struct {
	Limits *composeResourceSpec `json:"limits"`
}

type composeResourceSpec struct {
	Memory string `json:"memory"`
	CPUs   string `json:"cpus"`
}

type composeSecret struct {
	File string `json:"file"`
}

// loadCompose reads and parses a docker compose YAML file into a composeFile.
func loadCompose(path string) (*composeFile, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cf composeFile
	if err := yaml.Unmarshal(data, &cf); err != nil {
		return nil, err
	}
	return &cf, nil
}

// dependsOnNames returns the service names referenced by a depends_on field,
// which may be either short-form (a list of names) or long-form (a map of
// name to {condition}).
func dependsOnNames(raw json.RawMessage) []string {
	if len(raw) == 0 {
		return nil
	}
	var list []string
	if err := json.Unmarshal(raw, &list); err == nil {
		return list
	}
	var m map[string]struct {
		Condition string `json:"condition"`
	}
	if err := json.Unmarshal(raw, &m); err != nil {
		return nil
	}
	names := make([]string, 0, len(m))
	for name := range m {
		names = append(names, name)
	}
	return names
}

// dependsOnCondition returns the long-form condition for the given service
// in a depends_on field, or "" if not present or if depends_on uses short form.
func dependsOnCondition(raw json.RawMessage, service string) string {
	var m map[string]struct {
		Condition string `json:"condition"`
	}
	if err := json.Unmarshal(raw, &m); err != nil {
		return ""
	}
	return m[service].Condition
}

// envContainsKey reports whether an environment field (short-form list of
// "KEY=VALUE" strings, or long-form map) defines the given key.
func envContainsKey(raw json.RawMessage, key string) bool {
	if len(raw) == 0 {
		return false
	}
	var list []string
	if err := json.Unmarshal(raw, &list); err == nil {
		for _, kv := range list {
			if strings.HasPrefix(kv, key+"=") {
				return true
			}
		}
		return false
	}
	var m map[string]any
	if err := json.Unmarshal(raw, &m); err == nil {
		_, ok := m[key]
		return ok
	}
	return false
}

// envKeyIsNull reports whether an environment map (long-form) explicitly
// sets key to null, e.g. to unset a value inherited from a base compose file.
func envKeyIsNull(raw json.RawMessage, key string) bool {
	var m map[string]any
	if err := json.Unmarshal(raw, &m); err != nil {
		return false
	}
	v, ok := m[key]
	return ok && v == nil
}
