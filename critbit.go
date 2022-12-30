package main

import (
	"bytes"
	_ "embed"
	"fmt"
	"math/big"
	"os"
	"text/template"

	"github.com/spf13/cobra"
)

//go:embed critbit.move.template
var critbitTreeTemplate string

type UnrolledLeadingZero struct {
	Width uint
	Ones  string
}

// value 1 in big.Int
var one = big.NewInt(1)

// UnrollLeadingZero creates an unrolled
func UnrollLeadingZero(n uint, w uint) UnrolledLeadingZero {
	return UnrolledLeadingZero{
		Width: n,
		Ones:  big.NewInt(0).Lsh(big.NewInt(0).Sub(big.NewInt(0).Lsh(one, n), one), w-n).String(),
	}
}

type CritbitTreeData struct {
	*Shared

	KeyIntWidth int
}

func GetCritbitTreeCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "critbit",
		Short: "generate critbit tree",
		Long:  "generate critbit tree based on  based on http://github.com/agl/critbit",
	}

	critbit := CritbitTreeData{
		Shared:      NewShared("critbit", "critbit"),
		KeyIntWidth: 128,
	}

	critbit.SetCritibitData(cmd)

	return cmd
}

func (critbit *CritbitTreeData) SetCritibitData(cmd *cobra.Command) {
	critbit.SetCmd(cmd)
	cmd.Flags().IntVar(&critbit.KeyIntWidth, "key-width", critbit.KeyIntWidth, "int width for keys")

	cmd.Run = critbit.Run
}

func (critbit *CritbitTreeData) KeyType() string {
	return fmt.Sprintf("u%d", critbit.KeyIntWidth)
}

func (critbit *CritbitTreeData) UnrolledLeadingZeros() []UnrolledLeadingZero {
	result := make([]UnrolledLeadingZero, 0)
	w := uint(critbit.KeyIntWidth)
	for n := w >> 1; n > 0; n = n >> 1 {
		result = append(result, UnrollLeadingZero(n, w))
	}
	return result
}

func (critbit *CritbitTreeData) Run(_ *cobra.Command, _ []string) {
	tmpl, err := template.New("temp").Parse(critbitTreeTemplate)
	if err != nil {
		panic(err)
	}

	var buf bytes.Buffer

	err = tmpl.Execute(&buf, critbit)
	if err != nil {
		panic(err)
	}

	err = os.WriteFile(critbit.OutputFileName, buf.Bytes(), 0o666)
	if err != nil {
		panic(err)
	}
}
