package main

import "github.com/spf13/cobra"

func main() {
	cmd := &cobra.Command{
		Use:   "gen-move-container",
		Short: "generate container types for move",
		Long:  longDescription,
	}

	cmd.AddCommand(
		GetRedBlackCmd(),
		GetAvlCmd(),
		GetVanillaBinarySearchTreeCmd(),
		GetCritbitTreeCmd(),
	)

	cmd.Execute()
}
