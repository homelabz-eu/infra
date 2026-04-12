package cmd

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/homelabz-eu/infra/secret-manager/internal/store"
	"github.com/spf13/cobra"
)

func deleteCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "delete <name>",
		Short: "Delete a secret file",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			name := args[0]
			yes, _ := cmd.Flags().GetBool("yes")

			root, err := resolveRoot()
			if err != nil {
				return err
			}

			filePath := store.ResolvePath(root, flagEnv, flagPath, name)
			if _, err := os.Stat(filePath); os.IsNotExist(err) {
				return fmt.Errorf("secret file not found: %s", filePath)
			}

			if !yes {
				fmt.Fprintf(os.Stderr, "delete %s? [y/N] ", filePath)
				reader := bufio.NewReader(os.Stdin)
				answer, _ := reader.ReadString('\n')
				answer = strings.TrimSpace(strings.ToLower(answer))
				if answer != "y" && answer != "yes" {
					fmt.Fprintln(os.Stderr, "cancelled")
					return nil
				}
			}

			if store.IsGitTracked(root, filePath) {
				if err := store.GitRemove(root, filePath); err != nil {
					return fmt.Errorf("git rm failed: %w", err)
				}
			} else {
				if err := os.Remove(filePath); err != nil {
					return fmt.Errorf("failed to remove file: %w", err)
				}
			}

			fmt.Fprintf(os.Stderr, "deleted: %s\n", filePath)
			return nil
		},
	}

	cmd.Flags().BoolP("yes", "y", false, "skip confirmation prompt")
	return cmd
}
