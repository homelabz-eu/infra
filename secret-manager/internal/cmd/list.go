package cmd

import (
	"fmt"

	"github.com/homelabz-eu/infra/secret-manager/internal/store"
	"github.com/spf13/cobra"
)

func listCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "List secret names",
		RunE: func(cmd *cobra.Command, args []string) error {
			root, err := resolveRoot()
			if err != nil {
				return err
			}

			names, err := store.List(root, flagEnv, flagPath)
			if err != nil {
				return err
			}

			for _, n := range names {
				fmt.Println(n)
			}
			return nil
		},
	}
}
