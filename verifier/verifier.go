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
	Metadata   uint8
}

type EntryWithExtraInfo struct {
	Entry

	Height               int
	AvlBalance           int
	BlackHeight          int
	BlackHeightInbalance int
	HasRightChild        bool
}

type TreeType uint8

//go:generate stringer -type=TreeType -linecomment
const (
	TreeType_Vanilla  TreeType = iota // Vanila
	TreeType_RedBlack                 // RedBlack
	TreeType_Avl                      // AVL
)

type RedBlackTreeColor uint8

//go:generate stringer -type=RedBlackTreeColor -linecomment
const (
	RedBlackTreeColor_Red   RedBlackTreeColor = 128 // Red
	RedBlackTreeColor_Black RedBlackTreeColor = 129 // Blk
)

type Tree struct {
	Entries []*EntryWithExtraInfo
	Root    int
	Type    TreeType
}

func ItoS(i uint64) string {
	if i == NULL_INDEX {
		return "XX"
	} else {
		return fmt.Sprintf("%2d", i)
	}
}

const NULL_INDEX = 18446744073709551615

func NewTree(entries []Entry, treeType TreeType) *Tree {
	r := &Tree{
		Type: treeType,
	}

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

		if treeType != TreeType_RedBlack {
			return true
		}

		leftBlackHeight := r.GetBlackHeight(node.LeftChild)
		rightBlackHeight := r.GetBlackHeight(node.RightChild)
		selfBlackHeight := 0
		if node.Metadata == uint8(RedBlackTreeColor_Black) {
			selfBlackHeight = 1
		}
		if leftBlackHeight > rightBlackHeight {
			node.BlackHeight = selfBlackHeight + leftBlackHeight
		} else {
			node.BlackHeight = selfBlackHeight + rightBlackHeight
		}

		node.BlackHeightInbalance = leftBlackHeight - rightBlackHeight

		node.HasRightChild = r.IsRed(node.LeftChild) || r.IsRed(node.RightChild)

		return true
	})

	return r
}

func (tree *Tree) IsRed(i uint64) bool {
	if !tree.IsValidIndex(i) {
		return false
	}

	return tree.Entries[i].Metadata == uint8(RedBlackTreeColor_Red)
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

func (tree *Tree) GetBlackHeight(i uint64) int {
	if !tree.IsValidIndex(i) {
		return 0
	}

	return tree.Entries[i].BlackHeight
}

func (tree *Tree) NodeToString(index uint64) string {
	if !tree.IsValidIndex(index) {
		return "(invalid index)"
	}

	node := tree.Entries[index]

	switch tree.Type {
	case TreeType_Avl:
		return fmt.Sprintf("{k: %s, i: %s, m: %s: avl: %s}",
			ItoS(node.Key),
			ItoS(index),
			ItoS(uint64(node.Metadata)),
			ItoS(uint64(node.AvlBalance+128)),
		)
	case TreeType_RedBlack:
		return fmt.Sprintf("{k: %s, i: %s, m: %s}",
			ItoS(node.Key),
			ItoS(index),
			RedBlackTreeColor(node.Metadata),
		)
	case TreeType_Vanilla:
	default:
	}
	return fmt.Sprintf("{k: %s, i: %s, m: %s}",
		ItoS(node.Key),
		ItoS(index),
		ItoS(uint64(node.Metadata)),
	)
}

func (tree *Tree) VerifyAvlBalance() bool {
	r := true
	for i, v := range tree.Entries {
		if v.AvlBalance <= -2 || v.AvlBalance >= 2 {
			fmt.Printf("avl balance at %d is impossible: %s %d\n", i, tree.NodeToString(uint64(i)), v.AvlBalance)
		}
		if int(v.Metadata) == v.AvlBalance+128 {
			continue
		}

		fmt.Printf("avl balance at %d not right: %s %d\n", i, tree.NodeToString(uint64(i)), v.AvlBalance)

		r = r && false
	}

	return r
}

func (tree *Tree) VerifyRedBlack() bool {
	r := true
	for i, node := range tree.Entries {
		if node.BlackHeightInbalance != 0 {
			fmt.Printf("%s has black height difference\n", tree.NodeToString(uint64(i)))
			r = false
		}
		if tree.IsRed(uint64(i)) && node.HasRightChild {
			fmt.Printf("red node %s has red child\n", tree.NodeToString(uint64(i)))
			r = false
		}
	}

	return r
}

func (tree *Tree) VerifyChild() bool {
	r := true

	tree.PrefixVisit(uint64(tree.Root), func(node *EntryWithExtraInfo, index uint64) bool {
		r = r && tree.verifyChild(index)
		return true
	})

	return r
}

func (tree *Tree) VerifyAll() bool {
	r := tree.VerifyChild()

	if !r {
		return r
	}

	switch tree.Type {
	case TreeType_Avl:
		return tree.VerifyAvlBalance()
	case TreeType_RedBlack:
		return tree.VerifyRedBlack()
	case TreeType_Vanilla:
	default:

	}
	return true
}

func (tree *Tree) verifyChild(index uint64) bool {
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
			tree.NodeToString(leftChild),
			tree.NodeToString(index))
		return false
	}

	if rightChild != NULL_INDEX && !tree.IsValidIndex(rightChild) {
		return false
	}

	if tree.IsValidIndex(rightChild) && index != tree.Entries[rightChild].Parent {
		fmt.Printf("right child %s doesnt match parent %s",
			tree.NodeToString(rightChild),
			tree.NodeToString(index))
		return false
	}

	return true
}

const (
	prefix1 = "├───"
	prefix2 = "└───"
	prefix3 = "    "
	prefix4 = "│   "
	prefix5 = "┌───"
)

func (tree *Tree) Print(out io.Writer) {
	tree.PrintFrom(uint64(tree.Root), out, "", "", "")
}

func (tree *Tree) getNodePrefixForPrint(node *EntryWithExtraInfo) string {
	hasLeftChild := tree.IsValidIndex(node.LeftChild)
	hasRightChild := tree.IsValidIndex(node.RightChild)
	switch {
	case hasLeftChild && hasRightChild:
		return "┼ "
	case hasLeftChild:
		return "┴ "
	case hasRightChild:
		return "┬ "
	default:
		return "─ "
	}
}

// adpated from https://stackoverflow.com/a/8948691
func (tree *Tree) PrintFrom(
	index uint64,
	out io.Writer,
	indent string,
	leftChildIndent string,
	rightChildIndent string,
) {
	if !tree.IsValidIndex(index) {
		return
	}

	node := tree.Entries[index]

	tree.PrintFrom(node.LeftChild, out, leftChildIndent+prefix5, leftChildIndent+prefix3, leftChildIndent+prefix4)

	fmt.Printf("%s%s%s\n", indent, tree.getNodePrefixForPrint(node), tree.NodeToString(index))

	tree.PrintFrom(node.RightChild, out, rightChildIndent+prefix2, rightChildIndent+prefix4, rightChildIndent+prefix3)
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
