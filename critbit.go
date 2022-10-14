package main

import (
	"bytes"
	_ "embed"
	"os"
	"text/template"

	"github.com/spf13/cobra"
)

//go:embed critbit.move.template
var critbitTreeTemplate string

type CritbitTreeData struct {
	*Shared
}

func GetCritbitTreeCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "critbit",
		Short: "generate critbit tree",
		Long:  "generate critbit tree based on  based on http://github.com/agl/critbit",
	}

	critbit := CritbitTreeData{
		Shared: NewShared("critbit", "critbit"),
	}

	critbit.SetCritibitData(cmd)

	cmd.Run = critbit.Run

	return cmd
}

func (critbit *CritbitTreeData) SetCritibitData(cmd *cobra.Command) {
	critbit.SetCmd(cmd)
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
