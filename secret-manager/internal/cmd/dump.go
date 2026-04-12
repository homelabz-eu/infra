package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/homelabz-eu/infra/secret-manager/internal/sops"
	"github.com/homelabz-eu/infra/secret-manager/internal/store"
	"github.com/spf13/cobra"
	"gopkg.in/yaml.v3"
)

func dumpCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "dump",
		Short: "Decrypt all secrets and output flattened JSON for OpenTofu",
		RunE:  runDump,
	}

	cmd.Flags().String("secrets-dir", "../secrets", "base directory for secrets")
	cmd.Flags().String("output", "tmp/secrets.json", "output file path")
	cmd.Flags().String("environment", "all", "environment to load (dev, stg, prod, common, all)")

	return cmd
}

func runDump(cmd *cobra.Command, args []string) error {
	secretsDir, _ := cmd.Flags().GetString("secrets-dir")
	output, _ := cmd.Flags().GetString("output")
	environment, _ := cmd.Flags().GetString("environment")

	allSecrets := make(map[string]map[string]string)

	if environment == "all" {
		for _, env := range []string{"dev", "stg", "prod", "common"} {
			envDir := filepath.Join(secretsDir, env)
			if info, err := os.Stat(envDir); err != nil || !info.IsDir() {
				continue
			}
			fmt.Fprintf(os.Stderr, "Processing %s environment...\n", env)
			if err := processSecretsDir(envDir, allSecrets); err != nil {
				return fmt.Errorf("failed processing %s: %w", env, err)
			}
		}
	} else {
		envDir := filepath.Join(secretsDir, environment)
		if info, err := os.Stat(envDir); err != nil || !info.IsDir() {
			return fmt.Errorf("environment directory not found: %s", envDir)
		}
		fmt.Fprintf(os.Stderr, "Processing %s environment...\n", environment)
		if err := processSecretsDir(envDir, allSecrets); err != nil {
			return err
		}
	}

	if err := os.MkdirAll(filepath.Dir(output), 0755); err != nil {
		return fmt.Errorf("failed to create output directory: %w", err)
	}

	jsonData, err := json.MarshalIndent(allSecrets, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal JSON: %w", err)
	}

	if err := os.WriteFile(output, jsonData, 0644); err != nil {
		return fmt.Errorf("failed to write output: %w", err)
	}

	fmt.Fprintf(os.Stderr, "Secrets processed and saved to %s\n", output)
	return nil
}

func processSecretsDir(dir string, allSecrets map[string]map[string]string) error {
	return filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}
		ext := strings.ToLower(filepath.Ext(path))
		if ext != ".yaml" && ext != ".yml" && ext != ".json" {
			return nil
		}

		fmt.Fprintf(os.Stderr, "Processing %s...\n", path)

		data, err := sops.DecryptFile(path)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error decrypting %s: %v\n", path, err)
			return nil
		}

		var parsed map[string]interface{}
		if err := yaml.Unmarshal(data, &parsed); err != nil {
			fmt.Fprintf(os.Stderr, "Error parsing %s: %v\n", path, err)
			return nil
		}

		flattened := store.FlattenVaultStructure(parsed)
		for k, v := range flattened {
			if _, exists := allSecrets[k]; !exists {
				allSecrets[k] = make(map[string]string)
			}
			for fk, fv := range v {
				allSecrets[k][fk] = fv
			}
		}

		return nil
	})
}
