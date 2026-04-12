package cmd

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/homelabz-eu/infra/secret-manager/internal/sops"
	"github.com/homelabz-eu/infra/secret-manager/internal/store"
	"github.com/spf13/cobra"
)

func editCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "edit <name>",
		Short: "Open a secret in SOPS editor",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			name := args[0]

			root, err := resolveRoot()
			if err != nil {
				return err
			}

			filePath := store.ResolvePath(root, flagEnv, flagPath, name)
			if _, err := os.Stat(filePath); os.IsNotExist(err) {
				return fmt.Errorf("secret file not found: %s", filePath)
			}

			encrypted, err := sops.IsEncrypted(filePath)
			if err != nil {
				return fmt.Errorf("failed to check encryption: %w", err)
			}

			if encrypted {
				return sops.EditFile(filePath)
			}

			editor := os.Getenv("EDITOR")
			if editor == "" {
				editor = "vim"
			}

			fmt.Fprintf(os.Stderr, "warning: file is not encrypted, opening with %s\n", editor)
			editorCmd := exec.Command(editor, filePath)
			editorCmd.Stdin = os.Stdin
			editorCmd.Stdout = os.Stdout
			editorCmd.Stderr = os.Stderr
			if err := editorCmd.Run(); err != nil {
				return fmt.Errorf("editor failed: %w", err)
			}

			fmt.Fprintf(os.Stderr, "encrypt now? [Y/n] ")
			reader := bufio.NewReader(os.Stdin)
			answer, _ := reader.ReadString('\n')
			answer = strings.TrimSpace(strings.ToLower(answer))
			if answer == "" || answer == "y" || answer == "yes" {
				return sops.EncryptFileInPlace(filePath)
			}

			return nil
		},
	}
}
