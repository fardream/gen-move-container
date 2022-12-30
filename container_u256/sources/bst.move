// Code generated from github.com/fardream/gen-move-container
// Caution when editing manually.
// Tree based on GNU libavl https://adtinfo.org/
module container::vanilla_binary_search_tree {
    use std::vector::{Self, swap, is_empty, push_back, pop_back};

    const E_INVALID_ARGUMENT: u64 = 1;
    const E_KEY_ALREADY_EXIST: u64 = 2;
    const E_EMPTY_TREE: u64 = 3;
    const E_INVALID_INDEX: u64 = 4;
    const E_TREE_TOO_BIG: u64 = 5;
    const E_TREE_NOT_EMPTY: u64 = 6;
    const E_PARENT_NULL: u64 = 7;
    const E_PARENT_INDEX_OUT_OF_RANGE: u64 = 8;
    const E_RIGHT_ROTATE_LEFT_CHILD_NULL: u64 = 9;
    const E_LEFT_ROTATE_RIGHT_CHILD_NULL: u64 = 10;

    // NULL_INDEX is 1 << 64 - 1 (all 1s for the 64 bits);
    const NULL_INDEX: u64 = 18446744073709551615;

    // check if the index is NULL_INDEX
    public fun is_null_index(index: u64): bool {
        index == NULL_INDEX
    }

    public fun null_index_value(): u64 {
        NULL_INDEX
    }


    /// Entry is the internal BinarySearchTree element.
    struct Entry<V> has store, copy, drop {
        // key
        key: u256,
        // value
        value: V,
        // parent
        parent: u64,
        // left child
        left_child: u64,
        // right child.
        right_child: u64,
    }

    fun new_entry<V>(key: u256, value: V): Entry<V> {
        Entry<V> {
            key,
            value,
            parent: NULL_INDEX,
            left_child: NULL_INDEX,
            right_child: NULL_INDEX,
        }
    }

    #[test_only]
    fun new_entry_for_test<V>(key: u256, value: V, parent: u64, left_child: u64, right_child: u64): Entry<V> {
        Entry {
            key,
            value,
            parent,
            left_child,
            right_child,
        }
    }

    /// BinarySearchTree contains a vector of Entry<V>, which is triple-linked binary search tree.
    struct BinarySearchTree<V> has store, copy, drop {
        root: u64,
        entries: vector<Entry<V>>,
        min_index: u64,
        max_index: u64,
    }

    /// create new tree
    public fun new<V>(): BinarySearchTree<V> {
        BinarySearchTree {
            root: NULL_INDEX,
            entries: vector::empty<Entry<V>>(),
            min_index: NULL_INDEX,
            max_index: NULL_INDEX,
        }
    }

    ///////////////
    // Accessors //
    ///////////////

    /// find returns the element index in the BinarySearchTree, or none if not found.
    public fun find<V>(tree: &BinarySearchTree<V>, key: u256): u64 {
        let current = tree.root;

        while(current != NULL_INDEX) {
            let node = vector::borrow(&tree.entries, current);
            if (node.key == key) {
                return current
            };
            let is_smaller = ((node.key < key));
            if(is_smaller) {
                current = node.right_child;
            } else {
                current = node.left_child;
            };
        };

        NULL_INDEX
    }

    /// borrow returns a reference to the element with its key at the given index
    public fun borrow_at_index<V>(tree: &BinarySearchTree<V>, index: u64): (u256, &V) {
        let entry = vector::borrow(&tree.entries, index);
        (entry.key, &entry.value)
    }

    /// borrow_mut returns a mutable reference to the element with its key at the given index
    public fun borrow_at_index_mut<V>(tree: &mut BinarySearchTree<V>, index: u64): (u256, &mut V) {
        let entry = vector::borrow_mut(&mut tree.entries, index);
        (entry.key, &mut entry.value)
    }

    /// size returns the number of elements in the BinarySearchTree.
    public fun size<V>(tree: &BinarySearchTree<V>): u64 {
        vector::length(&tree.entries)
    }

    /// empty returns true if the BinarySearchTree is empty.
    public fun empty<V>(tree: &BinarySearchTree<V>): bool {
        vector::length(&tree.entries) == 0
    }

    /// get index of the min of the tree.
    public fun get_min_index<V>(tree: &BinarySearchTree<V>): u64 {
        let current = tree.min_index;
        assert!(current != NULL_INDEX, E_EMPTY_TREE);
        current
    }

    /// get index of the min of the subtree with root at index.
    public fun get_min_index_from<V>(tree: &BinarySearchTree<V>, index: u64): u64 {
        let current = index;
        let left_child = vector::borrow(&tree.entries, current).left_child;

        while (left_child != NULL_INDEX) {
            current = left_child;
            left_child = vector::borrow(&tree.entries, current).left_child;
        };

        current
    }

    /// get index of the max of the tree.
    public fun get_max_index<V>(tree: &BinarySearchTree<V>): u64 {
        let current = tree.max_index;
        assert!(current != NULL_INDEX, E_EMPTY_TREE);
        current
    }

    /// get index of the max of the subtree with root at index.
    public fun get_max_index_from<V>(tree: &BinarySearchTree<V>, index: u64): u64 {
        let current = index;
        let right_child = vector::borrow(&tree.entries, current).right_child;

        while (right_child != NULL_INDEX) {
            current = right_child;
            right_child = vector::borrow(&tree.entries, current).right_child;
        };

        current
    }

    /// find next value in order (the key is increasing)
    public fun next_in_order<V>(tree: &BinarySearchTree<V>, index: u64): u64 {
        assert!(index != NULL_INDEX, E_INVALID_INDEX);
        let node = vector::borrow(&tree.entries, index);
        let right_child = node.right_child;
        let parent = node.parent;

        if (right_child != NULL_INDEX) {
            // first, check if right child is null.
            // then go to right child, and check if there is left child.
            let next = right_child;
            let next_left = vector::borrow(&tree.entries, next).left_child;
            while (next_left != NULL_INDEX) {
                next = next_left;
                next_left = vector::borrow(&tree.entries, next).left_child;
            };

           next
        } else if (parent != NULL_INDEX) {
            // there is no right child, check parent.
            // if current is the left child of the parent, parent is then next.
            // if current is the right child of the parent, set current to parent
            let current = index;
            while(parent != NULL_INDEX && is_right_child(tree, current, parent)) {
                current = parent;
                parent = vector::borrow(&tree.entries, current).parent;
            };

            parent
        } else {
            NULL_INDEX
        }
    }

    /// find next value in reverse order (the key is decreasing)
    public fun next_in_reverse_order<V>(tree: &BinarySearchTree<V>, index: u64): u64 {
        assert!(index != NULL_INDEX, E_INVALID_INDEX);
        let node = vector::borrow(&tree.entries, index);
        let left_child = node.left_child;
        let parent = node.parent;
        if (left_child != NULL_INDEX) {
            // first, check if left child is null.
            // then go to left child, and check if there is right child.
            let next = left_child;
            let next_right = vector::borrow(&tree.entries, next).right_child;
            while (next_right != NULL_INDEX) {
                next = next_right;
                next_right = vector::borrow(&tree.entries, next).right_child;
            };

           next
        } else if (parent != NULL_INDEX) {
            // there is no left child, check parent.
            // if current is the right child of the parent, parent is then next.
            // if current is the left child of the parent, set current to parent
            let current = index;
            while(parent != NULL_INDEX && is_left_child(tree, current, parent)) {
                current = parent;
                parent = vector::borrow(&tree.entries, current).parent;
            };

            parent
        } else {
            NULL_INDEX
        }
    }

    ///////////////
    // Modifiers //
    ///////////////

    /// insert puts the value keyed at the input keys into the BinarySearchTree.
    /// aborts if the key is already in the tree.
    public fun insert<V>(tree: &mut BinarySearchTree<V>, key: u256, value: V) {
        // the max size of the tree is NULL_INDEX.
        assert!(size(tree) < NULL_INDEX, E_TREE_TOO_BIG);
		push_back(
            &mut tree.entries,
            new_entry(key, value)
        );

        let node = size(tree) - 1;

        let parent = NULL_INDEX;
        let insert = tree.root;
        let is_right_child = false;

        while (insert != NULL_INDEX) {
            let insert_node = vector::borrow(&tree.entries, insert);
            assert!((insert_node.key != key), E_KEY_ALREADY_EXIST);
            parent = insert;
            is_right_child = ((insert_node.key < key));
            insert = if (is_right_child) {
                insert_node.right_child
            } else {
                insert_node.left_child
            };
        };

        replace_parent(tree, node, parent);

        if (parent != NULL_INDEX) {
            if (is_right_child) {
                replace_right_child(tree, parent, node);
            } else {
                replace_left_child(tree, parent, node);
            };
            let max_node = vector::borrow(&tree.entries, tree.max_index);
            let is_max_smaller = ((max_node.key < key));
            if (is_max_smaller) {
                tree.max_index = node;
            };
            let min_node = vector::borrow(&tree.entries, tree.min_index);
            let is_min_bigger = ((min_node.key > key));
            if (is_min_bigger) {
                tree.min_index = node;
            };
        } else {
            tree.root = node;
            tree.min_index = node;
            tree.max_index = node;
        };
    }

    /// remove deletes and returns the element from the BinarySearchTree.
    public fun remove<V>(tree: &mut BinarySearchTree<V>, index: u64): (u256, V) {
        if (tree.max_index == index) {
            tree.max_index = next_in_reverse_order(tree, index);
        };
        if (tree.min_index == index) {
            tree.min_index = next_in_order(tree, index);
        };

        let node = vector::borrow(&tree.entries, index);
        let parent = node.parent;
        let left_child = node.left_child;
        let right_child = node.right_child;
        if (right_child == NULL_INDEX) {
            // right child is null
            // replace with left child.
            // No need to swap metadata
            // - in AVL, left is balanced and new value is also balanced.
            // - in RB, left must be red and index must be black.
            //         index
            //       /       \
            //     left
            //  --
            //        left
            if (parent == NULL_INDEX) {
                replace_parent(tree, left_child, NULL_INDEX);
                tree.root = left_child;
            } else {
                replace_child(tree, parent, index, left_child);
            };
        } else if (left_child == NULL_INDEX){
            // left child is null.
            // replace with right child.
            // No need to swap metadata.
            // - in AVL, right is balanced and the new value is also balanced.
            // - in RB, right must be red and index must be black.
            //         index
            //       /       \
            //               right
            //  --
            //        right
            if (parent == NULL_INDEX) {
                replace_parent(tree, right_child, NULL_INDEX);
                tree.root = right_child;
            } else {
                replace_child(tree, parent, index, right_child);
            };
        } else {
            let right_child_s_left = vector::borrow(&tree.entries, right_child).left_child;
            if (right_child_s_left == NULL_INDEX) {
                // right child is not null, and right child's left child is null
                //              index
                //           /         \
                //        left         right
                //                        \
                //                         a
                // -------------
                //               right
                //            /       \
                //          left       a
                replace_left_child(tree, right_child, left_child);

                if (parent == NULL_INDEX) {
                    replace_parent(tree, right_child, NULL_INDEX);
                    tree.root = right_child;
                } else {
                    replace_child(tree, parent, index, right_child);
                };
            } else {
                // right child is not null, and right child's left child is not null either
                //                 index
                //               /       \
                //             left      right
                //                       /  \
                //                      *
                //                     /
                //                    min
                //                     \
                //                      a
                // -------------------------------------------------
                //                   min
                //               /       \
                //             left      right
                //                       /  \
                //                      *
                //                     /
                //                    a
                let next_successor = get_min_index_from(tree, right_child_s_left);
                let next_successor_node = vector::borrow(&tree.entries, next_successor);
                let successor_parent = next_successor_node.parent;
                let next_successor_right = next_successor_node.right_child;

                replace_left_child(tree, successor_parent, next_successor_right);
                replace_left_child(tree, next_successor, left_child);
                replace_right_child(tree, next_successor, right_child,);

                if (parent == NULL_INDEX) {
                    replace_parent(tree, next_successor, NULL_INDEX);
                    tree.root = next_successor;
                } else {
                    replace_child(tree, parent, index, next_successor);
                };
            }
        };

        // swap index for pop out.
        let last_index = size(tree) -1;
        if (index != last_index) {
            swap(&mut tree.entries, last_index, index);
            if (tree.root == last_index) {
                tree.root = index;
            };
            if (tree.max_index == last_index) {
                tree.max_index = index;
            };
            if (tree.min_index == last_index) {
                tree.min_index = index;
            };
            let node = vector::borrow(&tree.entries, index);
            let parent = node.parent;
            let left_child = node.left_child;
            let right_child = node.right_child;
            replace_child(tree, parent, last_index, index);
            replace_parent(tree, left_child, index);
            replace_parent(tree, right_child, index);
        };

        ////////// now clear up.
        let Entry { key,  value, parent: _, left_child: _, right_child: _ } = pop_back(&mut tree.entries);

        if (size(tree) == 0) {
            tree.root = NULL_INDEX;
        };

        (key,  value)
    }

    /// destroys the tree if it's empty.
    public fun destroy_empty<V>(tree: BinarySearchTree<V>) {
        let BinarySearchTree { entries, root: _, min_index: _, max_index: _ } = tree;
        assert!(is_empty(&entries), E_TREE_NOT_EMPTY);
        vector::destroy_empty(entries);
    }

    /// check if index is the right child of parent.
    /// parent cannot be NULL_INDEX.
    fun is_right_child<V>(tree: &BinarySearchTree<V>, index: u64, parent_index: u64): bool {
        assert!(parent_index != NULL_INDEX, E_PARENT_NULL);
        assert!(parent_index < size(tree), E_PARENT_INDEX_OUT_OF_RANGE);
        vector::borrow(&tree.entries, parent_index).right_child == index
    }

    /// check if index is the left child of parent.
    /// parent cannot be NULL_INDEX.
    fun is_left_child<V>(tree: &BinarySearchTree<V>, index: u64, parent_index: u64): bool {
        assert!(parent_index != NULL_INDEX, E_PARENT_NULL);
        assert!(parent_index < size(tree), E_PARENT_INDEX_OUT_OF_RANGE);
        vector::borrow(&tree.entries, parent_index).left_child == index
    }

    /// Replace the child of parent if parent_index is not NULL_INDEX.
    /// also replace parent index of the child.
    fun replace_child<V>(tree: &mut BinarySearchTree<V>, parent_index: u64, original_child: u64, new_child: u64) {
        if (parent_index != NULL_INDEX) {
            if (is_right_child(tree, original_child, parent_index)) {
                replace_right_child(tree, parent_index, new_child);
            } else if (is_left_child(tree, original_child, parent_index)) {
                replace_left_child(tree, parent_index, new_child);
            }
        }
    }

    /// replace left child.
    /// also replace parent index of the child.
    fun replace_left_child<V>(tree: &mut BinarySearchTree<V>, parent_index: u64, new_child: u64) {
        if (parent_index != NULL_INDEX) {
            vector::borrow_mut(&mut tree.entries, parent_index).left_child = new_child;
            if (new_child != NULL_INDEX) {
                vector::borrow_mut(&mut tree.entries, new_child).parent = parent_index;
            };
        }
    }

    /// replace right child.
    /// also replace parent index of the child.
    fun replace_right_child<V>(tree: &mut BinarySearchTree<V>, parent_index: u64, new_child: u64) {
        if (parent_index != NULL_INDEX) {
            vector::borrow_mut(&mut tree.entries, parent_index).right_child = new_child;
                if (new_child != NULL_INDEX) {
                vector::borrow_mut(&mut tree.entries, new_child).parent = parent_index;
            };
        }
    }

    /// replace parent of index if index is not NULL_INDEX.
    fun replace_parent<V>(tree: &mut BinarySearchTree<V>, index: u64, parent_index: u64) {
        if (index != NULL_INDEX) {
            vector::borrow_mut(&mut tree.entries, index).parent = parent_index;
        }
    }

}
