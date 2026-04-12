package cmd

import (
	"fmt"
	"sort"

	"github.com/homelabz-eu/infra/secret-manager/internal/sops"
	"github.com/homelabz-eu/infra/secret-manager/internal/store"
	"github.com/spf13/cobra"
)

func getCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "get <name> [field]",
		Short: "View a secret or a specific field",
		Args:  cobra.RangeArgs(1, 2),
		RunE: func(cmd *cobra.Command, args []string) error {
			name := args[0]
			var field string
			if len(args) == 2 {
				field = args[1]
			}

			root, err := resolveRoot()
			if err != nil {
				return err
			}

			filePath := store.ResolvePath(root, flagEnv, flagPath, name)
			data, err := sops.DecryptFile(filePath)
			if err != nil {
				return err
			}

			fields, err := store.NavigateToFields(data, flagPath, name)
			if err != nil {
				return err
			}

			if field != "" {
				val, ok := fields[field]
				if !ok {
					return fmt.Errorf("field '%s' not found in secret '%s'", field, name)
				}
				fmt.Println(val)
				return nil
			}

			keys := make([]string, 0, len(fields))
			for k := range fields {
				keys = append(keys, k)
			}
			sort.Strings(keys)

			for _, k := range keys {
				fmt.Printf("%s: %s\n", k, fields[k])
			}
			return nil
		},
	}
}
