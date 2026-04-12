package cmd

import (
	"fmt"
	"os"

	"github.com/homelabz-eu/infra/secret-manager/internal/store"
	"github.com/spf13/cobra"
)

var (
	flagEnv  string
	flagPath string
	flagRoot string
)

func rootCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "secret-manager",
		Short: "CRUD operations on SOPS-encrypted secrets",
		SilenceUsage: true,
	}

	cmd.PersistentFlags().StringVar(&flagEnv, "env", store.DefaultEnv, "environment")
	cmd.PersistentFlags().StringVar(&flagPath, "path", store.DefaultPath, "vault sub-path")
	cmd.PersistentFlags().StringVar(&flagRoot, "root", "", "repository root (default: auto-detect via git)")

	cmd.AddCommand(listCmd())
	cmd.AddCommand(getCmd())
	cmd.AddCommand(setCmd())
	cmd.AddCommand(deleteCmd())
	cmd.AddCommand(editCmd())
	cmd.AddCommand(encryptCmd())
	cmd.AddCommand(dumpCmd())

	return cmd
}

func Execute() {
	if err := rootCmd().Execute(); err != nil {
		os.Exit(1)
	}
}

func resolveRoot() (string, error) {
	if flagRoot != "" {
		return flagRoot, nil
	}
	root, err := store.RepoRoot()
	if err != nil {
		return "", fmt.Errorf("cannot detect repo root (use --root): %w", err)
	}
	return root, nil
}
