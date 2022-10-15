package main

import (
	"fmt"

	"github.com/spf13/cobra"
)

const longDescription = `generate container types for move

base on GNU libavl https://adtinfo.org/
- vanilla binary tree
- avl tree
- red black tree

based on http://github.com/agl/critbit
- critbit tree
`

type Shared struct {
	Address        string
	ModuleName     string
	UseAptosTable  bool
	OutputFileName string
	NoTest         bool
}

func NewShared(moduleName, outputFileName string) *Shared {
	return &Shared{
		Address:        "container",
		ModuleName:     moduleName,
		UseAptosTable:  false,
		OutputFileName: fmt.Sprintf("sources/%s.move", outputFileName),
	}
}

func (shared *Shared) SetCmd(cmd *cobra.Command) {
	cmd.Args = cobra.NoArgs

	cmd.Flags().StringVarP(&shared.Address, "address", "p", shared.Address, "(named) address of the generated codes.")
	cmd.Flags().StringVarP(&shared.ModuleName, "module", "m", shared.ModuleName, "module name for the generated codes.")
	cmd.Flags().BoolVar(&shared.NoTest, "no-test", shared.NoTest, "turn off test")
	cmd.Flags().BoolVar(&shared.UseAptosTable, "use-aptos-table", shared.UseAptosTable, "use aptos table instead of vector.")

	cmd.Flags().StringVarP(&shared.OutputFileName, "output", "o", shared.OutputFileName, "output file")
	cmd.MarkFlagFilename("output")
}

func (shared *Shared) DoTest() bool {
	return !shared.NoTest && !shared.UseAptosTable
}

func (shared *Shared) UnderlyingModule() string {
	if shared.UseAptosTable {
		return "table"
	} else {
		return "vector"
	}
}
