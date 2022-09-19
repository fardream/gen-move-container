// gen-move-container
//
// generate containers for move.
// - binary search tree with AVL rebalance.
package main

import (
	"bytes"
	_ "embed"
	"os"
	"text/template"

	"github.com/spf13/cobra"
)

//go:embed bst.move.template
var bstTemplate string

type BstData struct {
	Address string
}

func main() {
	cmd := &cobra.Command{
		Use:   "gen-move-container",
		Short: "generate missing containers for move",
		Args:  cobra.NoArgs,
	}

	output := "./sources/bst.move"
	address := "container"

	cmd.Flags().StringVarP(&output, "out", "o", output, "output file. this should be the in the sources folder of your move package module")
	cmd.MarkFlagFilename("out")
	cmd.Flags().StringVarP(&address, "address", "p", address, "(named) address")

	cmd.Run = func(cmd *cobra.Command, args []string) {
		tmpl, err := template.New("temp").Parse(bstTemplate)
		if err != nil {
			panic(err)
		}

		data := BstData{Address: address}

		var buf bytes.Buffer

		err = tmpl.Execute(&buf, &data)

		if err != nil {
			panic(err)
		}

		os.WriteFile(output, []byte(buf.String()), 0x666)
	}

	cmd.Execute()
}
