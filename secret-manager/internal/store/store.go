package store

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

const (
	DefaultEnv  = "common"
	DefaultPath = "cluster-secret-store/secrets"
)

func RepoRoot() (string, error) {
	out, err := exec.Command("git", "rev-parse", "--show-toplevel").Output()
	if err != nil {
		return "", fmt.Errorf("not in a git repository: %w", err)
	}
	return strings.TrimSpace(string(out)), nil
}

func ResolvePath(root, env, secretPath, name string) string {
	return filepath.Join(root, "secrets", env, secretPath, name+".yaml")
}

func ResolveDir(root, env, secretPath string) string {
	return filepath.Join(root, "secrets", env, secretPath)
}

func List(root, env, secretPath string) ([]string, error) {
	dir := ResolveDir(root, env, secretPath)
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("cannot read directory %s: %w", dir, err)
	}

	var names []string
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		n := e.Name()
		if strings.HasSuffix(n, ".yaml") || strings.HasSuffix(n, ".yml") {
			names = append(names, strings.TrimSuffix(strings.TrimSuffix(n, ".yaml"), ".yml"))
		}
	}
	return names, nil
}

func BuildNewSecretYAML(secretPath, name, field, value string) ([]byte, error) {
	parts := strings.Split(secretPath, "/")

	leaf := &yaml.Node{
		Kind: yaml.MappingNode,
		Content: []*yaml.Node{
			{Kind: yaml.ScalarNode, Value: field},
			{Kind: yaml.ScalarNode, Value: value, Style: yaml.DoubleQuotedStyle},
		},
	}

	current := &yaml.Node{
		Kind: yaml.MappingNode,
		Content: []*yaml.Node{
			{Kind: yaml.ScalarNode, Value: name},
			leaf,
		},
	}

	for i := len(parts) - 1; i >= 0; i-- {
		current = &yaml.Node{
			Kind: yaml.MappingNode,
			Content: []*yaml.Node{
				{Kind: yaml.ScalarNode, Value: parts[i]},
				current,
			},
		}
	}

	root := &yaml.Node{
		Kind: yaml.DocumentNode,
		Content: []*yaml.Node{
			{
				Kind: yaml.MappingNode,
				Content: []*yaml.Node{
					{Kind: yaml.ScalarNode, Value: "vault"},
					{
						Kind: yaml.MappingNode,
						Content: []*yaml.Node{
							{Kind: yaml.ScalarNode, Value: "kv"},
							current,
						},
					},
				},
			},
		},
	}

	var buf strings.Builder
	enc := yaml.NewEncoder(&buf)
	enc.SetIndent(4)
	if err := enc.Encode(root); err != nil {
		return nil, fmt.Errorf("failed to encode YAML: %w", err)
	}
	enc.Close()
	return []byte(buf.String()), nil
}

func NavigateToFields(data []byte, secretPath, name string) (map[string]string, error) {
	var root map[string]interface{}
	if err := yaml.Unmarshal(data, &root); err != nil {
		return nil, fmt.Errorf("failed to parse YAML: %w", err)
	}

	current, ok := root["vault"]
	if !ok {
		return nil, fmt.Errorf("missing 'vault' key in secret")
	}

	currentMap, ok := current.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("invalid structure under 'vault'")
	}

	current, ok = currentMap["kv"]
	if !ok {
		return nil, fmt.Errorf("missing 'kv' key in secret")
	}

	parts := strings.Split(secretPath, "/")
	path := []string{"vault", "kv"}

	for _, part := range parts {
		m, ok := current.(map[string]interface{})
		if !ok {
			return nil, fmt.Errorf("invalid structure at %s", strings.Join(path, "."))
		}
		current, ok = m[part]
		if !ok {
			return nil, fmt.Errorf("key '%s' not found at %s", part, strings.Join(path, "."))
		}
		path = append(path, part)
	}

	m, ok := current.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("invalid structure at %s", strings.Join(path, "."))
	}

	nameData, ok := m[name]
	if !ok {
		return nil, fmt.Errorf("secret '%s' not found", name)
	}

	fieldsMap, ok := nameData.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("secret '%s' has unexpected structure", name)
	}

	result := make(map[string]string, len(fieldsMap))
	for k, v := range fieldsMap {
		result[k] = fmt.Sprintf("%v", v)
	}
	return result, nil
}

func SetFieldInYAML(data []byte, secretPath, name, field, value string) ([]byte, error) {
	var root yaml.Node
	if err := yaml.Unmarshal(data, &root); err != nil {
		return nil, fmt.Errorf("failed to parse YAML: %w", err)
	}

	keys := []string{"vault", "kv"}
	keys = append(keys, strings.Split(secretPath, "/")...)
	keys = append(keys, name)

	node := root.Content[0]
	for _, key := range keys {
		node = findOrCreateMappingKey(node, key)
	}

	existing := findMappingKey(node, field)
	if existing != nil {
		existing.Value = value
	} else {
		node.Content = append(node.Content,
			&yaml.Node{Kind: yaml.ScalarNode, Value: field},
			&yaml.Node{Kind: yaml.ScalarNode, Value: value, Style: yaml.DoubleQuotedStyle},
		)
	}

	var buf strings.Builder
	enc := yaml.NewEncoder(&buf)
	enc.SetIndent(4)
	if err := enc.Encode(&root); err != nil {
		return nil, fmt.Errorf("failed to encode YAML: %w", err)
	}
	enc.Close()
	return []byte(buf.String()), nil
}

func findMappingKey(node *yaml.Node, key string) *yaml.Node {
	if node.Kind != yaml.MappingNode {
		return nil
	}
	for i := 0; i < len(node.Content)-1; i += 2 {
		if node.Content[i].Value == key {
			return node.Content[i+1]
		}
	}
	return nil
}

func findOrCreateMappingKey(node *yaml.Node, key string) *yaml.Node {
	if node.Kind != yaml.MappingNode {
		return node
	}
	for i := 0; i < len(node.Content)-1; i += 2 {
		if node.Content[i].Value == key {
			return node.Content[i+1]
		}
	}
	newMap := &yaml.Node{Kind: yaml.MappingNode}
	node.Content = append(node.Content,
		&yaml.Node{Kind: yaml.ScalarNode, Value: key},
		newMap,
	)
	return newMap
}

func FlattenVaultStructure(data map[string]interface{}) map[string]map[string]string {
	result := make(map[string]map[string]string)
	vault, ok := data["vault"]
	if !ok {
		return result
	}
	vaultMap, ok := vault.(map[string]interface{})
	if !ok {
		return result
	}
	for key, value := range vaultMap {
		if m, ok := value.(map[string]interface{}); ok {
			flattenPath(key, m, "", result)
		} else {
			result[key] = map[string]string{key: fmt.Sprintf("%v", value)}
		}
	}
	return result
}

func flattenPath(segment string, data map[string]interface{}, currentPath string, result map[string]map[string]string) {
	path := segment
	if currentPath != "" {
		path = currentPath + "/" + segment
	}

	hasNestedMap := false
	for _, v := range data {
		if _, ok := v.(map[string]interface{}); ok {
			hasNestedMap = true
			break
		}
	}

	if !hasNestedMap {
		fields := make(map[string]string, len(data))
		for k, v := range data {
			fields[k] = fmt.Sprintf("%v", v)
		}
		result[path] = fields
		return
	}

	for key, value := range data {
		if m, ok := value.(map[string]interface{}); ok {
			flattenPath(key, m, path, result)
		}
	}
}

func IsGitTracked(root, filePath string) bool {
	cmd := exec.Command("git", "-C", root, "ls-files", "--error-unmatch", filePath)
	return cmd.Run() == nil
}

func GitRemove(root, filePath string) error {
	cmd := exec.Command("git", "-C", root, "rm", filePath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
