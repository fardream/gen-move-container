package main

import (
	"bytes"
	_ "embed"
	"os"
	"text/template"

	"github.com/spf13/cobra"
)

//go:embed ordered_tree.move.template
var orderedTreeTemplate string

type OrderedTreeData struct {
	Address string
}

func getOrderedTreeCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "gen-move-container",
		Short: "generate missing containers for move",
		Args:  cobra.NoArgs,
	}

	output := "./sources/ordered_tree.move"
	address := "container"

	cmd.Flags().StringVarP(&output, "out", "o", output, "output file. this should be the in the sources folder of your move package module")
	cmd.MarkFlagFilename("out")
	cmd.Flags().StringVarP(&address, "address", "p", address, "(named) address")

	cmd.Run = func(_ *cobra.Command, _ []string) {
		tmpl, err := template.New("temp").Parse(orderedTreeTemplate)
		if err != nil {
			panic(err)
		}

		data := OrderedTreeData{Address: address}

		var buf bytes.Buffer

		err = tmpl.Execute(&buf, &data)

		if err != nil {
			panic(err)
		}

		os.WriteFile(output, buf.Bytes(), 0o666)
	}

	return cmd
}
