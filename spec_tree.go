package main

import (
	"bytes"
	_ "embed"
	"os"
	"text/template"

	"github.com/spf13/cobra"
)

//go:embed spec.move.template
var specTreeTemplate string

type SpecTreeData struct {
	IsAvl        bool
	IsRb         bool
	Address      string
	ModuleName   string
	TreeType     string
	NeedMetadata bool
	DoAssert     bool
}

func getSpecTreeCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "specific-tree",
		Short: "generate specific tree types",
		Args:  cobra.NoArgs,
	}

	output := "./sources/binary_search_trees.move"
	address := "container"
	doVanilla := false
	noRb := false
	noAvl := false
	noAssert := false

	cmd.Flags().StringVarP(&output, "out", "o", output, "output file. this should be the in the sources folder of your move package module")
	cmd.MarkFlagFilename("out")
	cmd.Flags().StringVarP(&address, "address", "p", address, "(named) address")
	cmd.Flags().BoolVar(&doVanilla, "include-vanilla-tree", doVanilla, "include vanila tree")
	cmd.Flags().BoolVar(&noRb, "no-red-black-tree", noRb, "turn off red/black tree")
	cmd.Flags().BoolVar(&noAvl, "no-avl", noAvl, "turn off avl tree")
	cmd.Flags().BoolVar(&noAssert, "no-assert", noAssert, "turn off assert")
	cmd.Run = func(_ *cobra.Command, _ []string) {
		if noRb && noAvl && !doVanilla {
			panic("all output tree types are turned off.")
		}

		tmpl, err := template.New("temp").Parse(specTreeTemplate)
		if err != nil {
			panic(err)
		}

		var buf bytes.Buffer

		if !noRb {
			data := SpecTreeData{
				Address:      address,
				IsRb:         true,
				ModuleName:   "red_black_tree",
				TreeType:     "RedBlackTree",
				NeedMetadata: true,
				DoAssert:     !noAssert,
			}

			err = tmpl.Execute(&buf, &data)

			if err != nil {
				panic(err)
			}
		}

		if !noAvl {
			data := SpecTreeData{
				Address:      address,
				IsAvl:        true,
				ModuleName:   "avl_tree",
				TreeType:     "AvlTree",
				NeedMetadata: true,
				DoAssert:     !noAssert,
			}

			err = tmpl.Execute(&buf, &data)

			if err != nil {
				panic(err)
			}
		}

		if doVanilla {
			data := SpecTreeData{
				Address:    address,
				ModuleName: "vanilla_tree",
				TreeType:   "VanillaTree",
				DoAssert:   !noAssert,
			}

			err = tmpl.Execute(&buf, &data)

			if err != nil {
				panic(err)
			}
		}

		os.WriteFile(output, buf.Bytes(), 0o666)
	}

	return cmd
}
