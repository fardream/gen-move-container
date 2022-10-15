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
	*Shared
	IsAvl         bool
	IsRb          bool
	NoAssert      bool
	KeyCount      int
	ModulePostfix string

	Keys []Key
}

func (data *SpecTreeData) SetSpecTreeData(cmd *cobra.Command) {
	data.SetCmd(cmd)

	cmd.Flags().StringVar(&data.ModulePostfix, "module-postfilx", data.ModulePostfix, "post fix for module name")
	cmd.Flags().IntVar(&data.KeyCount, "key-count", data.KeyCount, "number of keys for the tree")
	cmd.Flags().BoolVar(&data.NoAssert, "no-ssert", data.NoAssert, "turn off assert")

	cmd.Run = data.Run
}

func (data *SpecTreeData) NeedMetadata() bool {
	return data.IsAvl || data.IsRb
}

func (data *SpecTreeData) DoAssert() bool {
	return !data.NoAssert
}

func (data *SpecTreeData) TreeType() string {
	switch {
	case data.IsRb:
		return "RedBlackTree"
	case data.IsAvl:
		return "AvlTree"
	default:
		return "BinarySearchTree"
	}
}

func (data *SpecTreeData) Run(cmd *cobra.Command, _ []string) {
	keyCount := data.KeyCount

	if keyCount < 1 {
		panic(fmt.Errorf("less than 1 key is requested: %d", keyCount))
	}

	if keyCount == 1 {
		data.Keys = []Key{{KeyName: "key", More: false}}
	} else {
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
			data.Keys = append(data.Keys, key)
		}
	}

	if data.ModulePostfix != "" {
		data.ModuleName = fmt.Sprintf("%s_%s", data.ModuleName, data.ModulePostfix)
	}

	tmpl, err := template.New("temp").Parse(specTreeTemplate)
	if err != nil {
		panic(err)
	}

	var buf bytes.Buffer
	err = tmpl.Execute(&buf, data)

	if err != nil {
		panic(err)
	}

	if err := os.WriteFile(data.OutputFileName, buf.Bytes(), 0o666); err != nil {
		panic(err)
	}
}

func GetRedBlackCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "red-black",
		Short: "generate red-black tree",
		Long: `Generate red black tree based on GNU libavl https://adtinfo.org/
`,
	}
	shared := SpecTreeData{
		Shared:   NewShared("red_black", "red-black"),
		IsRb:     true,
		IsAvl:    false,
		KeyCount: 1,
	}

	shared.SetSpecTreeData(cmd)

	return cmd
}

func GetAvlCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "avl",
		Short: "generate avl tree",
		Long: `Generate avl tree based on GNU libavl https://adtinfo.org/
`,
	}
	shared := SpecTreeData{
		Shared:   NewShared("avl", "avl"),
		IsRb:     false,
		IsAvl:    true,
		KeyCount: 1,
	}

	shared.SetSpecTreeData(cmd)

	return cmd
}

func GetVanillaBinarySearchTreeCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "bst",
		Short: "generate vanilla (b)inary (s)earch (t)ree",
		Long: `Generate vanilla binary search tree based on GNU libavl https://adtinfo.org/
`,
	}
	shared := SpecTreeData{
		Shared:   NewShared("vanilla_binary_search_tree", "bst"),
		IsRb:     false,
		IsAvl:    false,
		KeyCount: 1,
	}

	shared.SetSpecTreeData(cmd)

	return cmd
}
