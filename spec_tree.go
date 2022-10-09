package main

import (
	"bytes"
	_ "embed"
	"fmt"
	"os"
	"text/template"

	"github.com/spf13/cobra"
)

//go:embed spec.move.template
var specTreeTemplate string

type Key struct {
	KeyName      string
	More         bool
	EqualsBefore []*Key
}

type SpecTreeData struct {
	IsAvl        bool
	IsRb         bool
	Address      string
	ModuleName   string
	TreeType     string
	NeedMetadata bool
	DoAssert     bool
	Keys         []Key
	DoTest       bool
}

func genKeyList(keyCount int) []Key {
	if keyCount < 1 {
		panic(fmt.Errorf("less than 1 key is requested: %d", keyCount))
	}

	if keyCount == 1 {
		return []Key{{KeyName: "key", More: false}}
	}

	result := []Key{}

	for i := 0; i < keyCount; i++ {
		key := Key{
			KeyName: fmt.Sprintf("key%d_%d", i, keyCount),
			More:    i != keyCount-1,
		}
		for j := 0; j < i; j++ {
			key.EqualsBefore = append(key.EqualsBefore, &Key{
				KeyName: fmt.Sprintf("key%d_%d", j, keyCount),
				More:    j != i-1,
			})
		}
		result = append(result, key)
	}

	return result
}

func getModuleName(modulePostfix, defaultName string) string {
	if modulePostfix == "" {
		return defaultName
	}
	return fmt.Sprintf("%s_%s", defaultName, modulePostfix)
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
	keyCount := 1
	modulePostfix := ""

	cmd.Flags().StringVarP(&output, "out", "o", output, "output file. this should be the in the sources folder of your move package module")
	cmd.MarkFlagFilename("out")
	cmd.Flags().StringVarP(&address, "address", "p", address, "(named) address")
	cmd.Flags().BoolVar(&doVanilla, "include-vanilla-tree", doVanilla, "include vanila tree")
	cmd.Flags().BoolVar(&noRb, "no-red-black-tree", noRb, "turn off red/black tree")
	cmd.Flags().BoolVar(&noAvl, "no-avl", noAvl, "turn off avl tree")
	cmd.Flags().BoolVar(&noAssert, "no-assert", noAssert, "turn off assert")
	cmd.Flags().IntVar(&keyCount, "key-count", keyCount, "number of keys for the tree")
	cmd.Flags().StringVar(&modulePostfix, "module-postfix", modulePostfix, "postfix for module name")

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
				ModuleName:   getModuleName(modulePostfix, "red_black_tree"),
				TreeType:     "RedBlackTree",
				NeedMetadata: true,
				DoAssert:     !noAssert,
				Keys:         genKeyList(keyCount),
				DoTest:       keyCount == 1,
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
				ModuleName:   getModuleName(modulePostfix, "avl_tree"),
				TreeType:     "AvlTree",
				NeedMetadata: true,
				DoAssert:     !noAssert,
				Keys:         genKeyList(keyCount),
				DoTest:       keyCount == 1,
			}

			err = tmpl.Execute(&buf, &data)

			if err != nil {
				panic(err)
			}
		}

		if doVanilla {
			data := SpecTreeData{
				Address:    address,
				ModuleName: getModuleName(modulePostfix, "vanilla_tree"),
				TreeType:   "VanillaTree",
				DoAssert:   !noAssert,
				Keys:       genKeyList(keyCount),
				DoTest:     keyCount == 1,
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
