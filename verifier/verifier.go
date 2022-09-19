package verifier

import (
	"fmt"
	"io"
)

type Entry struct {
	Key        uint64
	Value      uint64
	Parent     uint64
	LeftChild  uint64
	RightChild uint64
	Metadata   uint64
}

type EntryWithExtraInfo struct {
	Entry

	Height     int
	AvlBalance int
}

type Tree struct {
	Entries []*EntryWithExtraInfo
	Root    int
}

func ItoS(i uint64) string {
	if i == NULL_INDEX {
		return "XX"
	} else {
		return fmt.Sprintf("%2d", i)
	}
}

const NULL_INDEX = 18446744073709551615

func NewTree(entries []Entry) *Tree {
	r := &Tree{}

	for i, v := range entries {
		c := EntryWithExtraInfo{Entry: v}
		r.Entries = append(r.Entries, &c)
		if c.Parent == NULL_INDEX {
			r.Root = i
		}
	}

	r.PostfixVisit(uint64(r.Root), func(node *EntryWithExtraInfo, index uint64) bool {
		leftHeight := r.GetHeightAt(node.LeftChild)
		rightHeight := r.GetHeightAt(node.RightChild)
		if leftHeight > rightHeight {
			node.Height = leftHeight + 1
		} else {
			node.Height = rightHeight + 1
		}

		node.AvlBalance = rightHeight - leftHeight

		return true
	})
	return r
}

func (tree *Tree) IsValidIndex(i uint64) bool {
	switch {
	case i == NULL_INDEX, i >= uint64(len(tree.Entries)):
		return false
	default:
		return true
	}
}

func (tree *Tree) GetHeightAt(i uint64) int {
	if !tree.IsValidIndex(i) {
		return 0
	}
	return tree.Entries[i].Height
}

func NodeToString(node *EntryWithExtraInfo, index int) string {
	return fmt.Sprintf("{k: %s, i: %s, m: %s: avl: %s}", ItoS(node.Key), ItoS(uint64(index)), ItoS(node.Metadata), ItoS(uint64(node.AvlBalance+128)))
}

func (tree *Tree) VerifyAvlBalance() bool {
	r := true
	for i, v := range tree.Entries {
		if v.AvlBalance <= -2 || v.AvlBalance >= 2 {
			fmt.Printf("avl balance at %d is impossible: %s %d\n", i, NodeToString(v, i), v.AvlBalance)
		}
		if int(v.Metadata) == v.AvlBalance+128 {
			continue
		}

		fmt.Printf("avl balance at %d not right: %s %d\n", i, NodeToString(v, i), v.AvlBalance)

		r = r && false
	}

	return r
}

func (tree *Tree) VerifyChild(index uint64) bool {
	if !tree.IsValidIndex(uint64(index)) {
		return false
	}
	node := tree.Entries[index]

	leftChild := node.LeftChild
	rightChild := node.RightChild

	if leftChild != NULL_INDEX && !tree.IsValidIndex(leftChild) {
		return false
	}

	if tree.IsValidIndex(leftChild) && index != tree.Entries[leftChild].Parent {
		fmt.Printf("left child %s doesnt match parent %s",
			NodeToString(tree.Entries[leftChild], int(leftChild)),
			NodeToString(node, int(index)))
		return false
	}

	if rightChild != NULL_INDEX && !tree.IsValidIndex(rightChild) {
		return false
	}

	if tree.IsValidIndex(rightChild) && index != tree.Entries[rightChild].Parent {
		fmt.Printf("right child %s doesnt match parent %s",
			NodeToString(tree.Entries[rightChild], int(rightChild)),
			NodeToString(node, int(index)))
		return false
	}

	return true
}

const (
	prefix1 = "├── "
	prefix2 = "└── "
	prefix3 = "    "
	prefix4 = "│   "
)

func (tree *Tree) Print(out io.Writer) {
	tree.PrintFrom(uint64(tree.Root), out, "", "")
}

// adpated from https://stackoverflow.com/a/8948691
func (tree *Tree) PrintFrom(index uint64, out io.Writer, indent string, childIndent string) {
	if !tree.IsValidIndex(index) {
		return
	}

	node := tree.Entries[index]

	fmt.Fprint(out, indent)
	fmt.Fprint(out, NodeToString(node, int(index)))
	fmt.Fprintln(out)

	hasRightChild := tree.IsValidIndex(node.RightChild)

	if hasRightChild && tree.IsValidIndex(node.LeftChild) {
		tree.PrintFrom(node.LeftChild, out, childIndent+prefix1, childIndent+prefix4)
	} else {
		tree.PrintFrom(node.LeftChild, out, childIndent+prefix2, childIndent+prefix3)
	}
	if hasRightChild {
		tree.PrintFrom(node.RightChild, out, childIndent+prefix2, childIndent+prefix3)
	}
}

func (tree *Tree) PrefixVisit(index uint64, visitor func(node *EntryWithExtraInfo, index uint64) bool) {
	if !tree.IsValidIndex(index) {
		return
	}

	node := tree.Entries[index]
	if !visitor(node, index) {
		return
	}

	tree.PrefixVisit(node.LeftChild, visitor)
	tree.PrefixVisit(node.RightChild, visitor)
}

func (tree *Tree) InfixVisit(index uint64, visitor func(node *EntryWithExtraInfo, index uint64) bool) {
	if !tree.IsValidIndex(index) {
		return
	}

	node := tree.Entries[index]

	tree.InfixVisit(node.LeftChild, visitor)
	tree.InfixVisit(node.RightChild, visitor)

	if !visitor(node, index) {
		return
	}

	tree.InfixVisit(node.RightChild, visitor)
}

func (tree *Tree) PostfixVisit(index uint64, visitor func(node *EntryWithExtraInfo, index uint64) bool) {
	if !tree.IsValidIndex(index) {
		return
	}

	node := tree.Entries[index]

	tree.PostfixVisit(node.LeftChild, visitor)
	tree.PostfixVisit(node.RightChild, visitor)

	if !visitor(node, index) {
		return
	}
}
