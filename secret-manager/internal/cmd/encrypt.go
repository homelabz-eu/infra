package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/homelabz-eu/infra/secret-manager/internal/sops"
	"github.com/spf13/cobra"
)

func encryptCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "encrypt",
		Short: "Batch-encrypt all unencrypted secrets",
		RunE: func(cmd *cobra.Command, args []string) error {
			root, err := resolveRoot()
			if err != nil {
				return err
			}

			keyFile := os.Getenv("SOPS_AGE_KEY_FILE")
			if keyFile == "" {
				return fmt.Errorf("SOPS_AGE_KEY_FILE environment variable is not set")
			}
			if _, err := os.Stat(keyFile); os.IsNotExist(err) {
				return fmt.Errorf("age key file not found: %s", keyFile)
			}

			sopsConfig := filepath.Join(root, ".sops.yaml")
			if _, err := os.Stat(sopsConfig); os.IsNotExist(err) {
				return fmt.Errorf(".sops.yaml not found in %s", root)
			}

			secretsDir := filepath.Join(root, "secrets")
			var encrypted, skipped int

			err = filepath.Walk(secretsDir, func(path string, info os.FileInfo, err error) error {
				if err != nil {
					return err
				}
				if info.IsDir() {
					return nil
				}
				ext := strings.ToLower(filepath.Ext(path))
				if ext != ".yaml" && ext != ".yml" {
					return nil
				}

				isEnc, err := sops.IsEncrypted(path)
				if err != nil {
					return fmt.Errorf("failed to check %s: %w", path, err)
				}

				if isEnc {
					fmt.Fprintf(os.Stderr, "skipped (encrypted): %s\n", path)
					skipped++
					return nil
				}

				fmt.Fprintf(os.Stderr, "encrypting: %s\n", path)
				if err := sops.EncryptFileInPlace(path); err != nil {
					return err
				}
				encrypted++
				return nil
			})

			if err != nil {
				return err
			}

			fmt.Fprintf(os.Stderr, "done: %d encrypted, %d skipped\n", encrypted, skipped)
			return nil
		},
	}
}
