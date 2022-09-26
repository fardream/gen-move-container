// gen-move-container
//
// generate containers for move.
// - binary search tree with AVL rebalance.
package main

func main() {
	cmd := getOrderedTreeCmd()

	cmd.AddCommand(getSpecTreeCmd())

	cmd.Execute()
}
