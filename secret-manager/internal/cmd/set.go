package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/homelabz-eu/infra/secret-manager/internal/sops"
	"github.com/homelabz-eu/infra/secret-manager/internal/store"
	"github.com/spf13/cobra"
)

func setCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "set <name> <field> <value>",
		Short: "Create or update a secret field",
		Args:  cobra.ExactArgs(3),
		RunE: func(cmd *cobra.Command, args []string) error {
			name, field, value := args[0], args[1], args[2]

			root, err := resolveRoot()
			if err != nil {
				return err
			}

			filePath := store.ResolvePath(root, flagEnv, flagPath, name)

			if _, err := os.Stat(filePath); os.IsNotExist(err) {
				return createNewSecret(filePath, flagPath, name, field, value)
			}

			return updateExistingSecret(filePath, flagPath, name, field, value)
		},
	}
}

func createNewSecret(filePath, secretPath, name, field, value string) error {
	if err := os.MkdirAll(filepath.Dir(filePath), 0755); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}

	data, err := store.BuildNewSecretYAML(secretPath, name, field, value)
	if err != nil {
		return err
	}

	if err := os.WriteFile(filePath, data, 0644); err != nil {
		return fmt.Errorf("failed to write file: %w", err)
	}

	if err := sops.EncryptFileInPlace(filePath); err != nil {
		os.Remove(filePath)
		return err
	}

	fmt.Fprintf(os.Stderr, "created: %s\n", filePath)
	return nil
}

func updateExistingSecret(filePath, secretPath, name, field, value string) error {
	data, err := sops.DecryptFile(filePath)
	if err != nil {
		return err
	}

	updated, err := store.SetFieldInYAML(data, secretPath, name, field, value)
	if err != nil {
		return err
	}

	if err := os.WriteFile(filePath, updated, 0644); err != nil {
		return fmt.Errorf("failed to write file: %w", err)
	}

	if err := sops.EncryptFileInPlace(filePath); err != nil {
		return err
	}

	fmt.Fprintf(os.Stderr, "updated: %s [%s]\n", filePath, field)
	return nil
}
