package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"

	"github.com/fardream/gen-move-container/verifier"
)

var isAvl *bool = flag.Bool("avl", false, "assume the tree is avl, otherwise red/black")

func main() {
	flag.Parse()

	cmd := exec.Command("move", "test")

	data, err := cmd.CombinedOutput()

	if _, isExitError := err.(*exec.ExitError); err != nil && !isExitError {
		panic(err)
	}

	vv, err := verifier.ParseMoveTestOut(string(data))
	if err != nil {
		panic(err)
	}

	for _, v := range vv {
		treeType := verifier.TreeType_RedBlack
		if *isAvl {
			treeType = verifier.TreeType_Avl
		}
		tree := verifier.NewTree(v, treeType)

		tree.VerifyAll()
		fmt.Printf("--------------------- %d ----------------------\n", len(tree.Entries))
		tree.Print(os.Stdout)
	}
}
