package main

import (
	"bytes"
	_ "embed"
	"os"
	"text/template"

	"github.com/spf13/cobra"
)

//go:embed linked_list.move.template
var linkdListTemplate string

type LinkedListData struct {
	*Shared
}

func GetLinkedListCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "linked-list",
		Short: "generate linked list",
	}

	linkedList := &LinkedListData{
		Shared: NewShared("linked_list", "linked_list"),
	}

	linkedList.SetCmd(cmd)

	cmd.Run = linkedList.Run

	return cmd
}

func (linkedListData *LinkedListData) Run(_ *cobra.Command, _ []string) {
	tmpl, err := template.New("temp").Parse(linkdListTemplate)
	if err != nil {
		panic(err)
	}

	var buf bytes.Buffer

	err = tmpl.Execute(&buf, linkedListData)
	if err != nil {
		panic(err)
	}

	err = os.WriteFile(linkedListData.OutputFileName, buf.Bytes(), 0o666)
	if err != nil {
		panic(err)
	}
}
