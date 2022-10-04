// Tree based on GNU libavl https://adtinfo.org/
module container::red_black_tree {
    use std::vector;
    use std::option::{Self, Option};

    const E_INVALID_ARGUMENT: u64 = 1;

    // NULL_INDEX is 1 << 64 - 1 (all 1s for the 64 bits);
    const NULL_INDEX: u64 = 18446744073709551615;

    // check if the index is NULL_INDEX
    public fun is_null_index(index: u64): bool {
        index == NULL_INDEX
    }

    const RB_RED: u8 = 128;
    const RB_BLACK: u8 = 129;

    const METADATA_DEFAULT: u8 = 128;

    /// Entry is the internal RedBlackTree element.
    struct Entry<V> has store, copy, drop {
        // key
        key: u128,
        // value
        value: V,
        // parent
        parent: u64,
        // left child
        left_child: u64,
        // right child.
        right_child: u64,
        // metadata
        metadata: u8,
    }

    fun new_entry<V>(key: u128, value: V): Entry<V> {
        Entry<V> {
            key,
            value,
            parent: NULL_INDEX,
            left_child: NULL_INDEX,
            right_child: NULL_INDEX,
            metadata: METADATA_DEFAULT,
        }
    }

    #[test_only]
    fun new_entry_for_test<V>(key: u128, value: V, parent: u64, left_child: u64, right_child: u64, metadata: u8): Entry<V> {
        Entry {
            key,
            value,
            parent,
            left_child,
            right_child,
            metadata,
        }
    }

    /// RedBlackTree contains a vector of Entry<V>, which is triple-linked binary search tree.
    struct RedBlackTree<V> has store, copy, drop {
        root: u64,
        entries: vector<Entry<V>>,
        min_index: u64,
        max_index: u64,
    }

    /// create new tree
    public fun new<V>(): RedBlackTree<V> {
        RedBlackTree {
            root: NULL_INDEX,
            entries: vector::empty<Entry<V>>(),
            min_index: NULL_INDEX,
            max_index: NULL_INDEX,
        }
    }

    ///////////////
    // Accessors //
    ///////////////

    /// find returns the element index in the RedBlackTree, or none if not found.
    public fun find<V>(tree: &RedBlackTree<V>, key: u128): Option<u64> {
        let current = tree.root;

        while(current != NULL_INDEX) {
            assert!(current < size(tree), current);
            let node = vector::borrow(&tree.entries, current);
            if (node.key == key) {
                return option::some(current)
            } else if(node.key < key) {
                current = node.right_child;
            } else {
                current = node.left_child;
            };
        };

        option::none()
    }

    /// borrow returns a reference to the element with its key at the given index
    public fun borrow_at_index<V>(tree: &RedBlackTree<V>, index: u64): (u128, &V) {
        let entry = vector::borrow(&tree.entries, index);
        (entry.key, &entry.value)
    }

    /// borrow_mut returns a mutable reference to the element with its key at the given index
    public fun borrow_at_index_mut<V>(tree: &mut RedBlackTree<V>, index: u64): (u128, &mut V) {
        let entry = vector::borrow_mut(&mut tree.entries, index);
        (entry.key, &mut entry.value)
    }

    /// size returns the number of elements in the RedBlackTree.
    public fun size<V>(tree: &RedBlackTree<V>): u64 {
        vector::length(&tree.entries)
    }

    /// empty returns true if the RedBlackTree is empty.
    public fun empty<V>(tree: &RedBlackTree<V>): bool {
        vector::length(&tree.entries) == 0
    }

    /// returns a reference to the RedBlackTree's entries.
    public fun borrow_entries<V>(tree: &RedBlackTree<V>): &vector<Entry<V>> {
        &tree.entries
    }

    /// get index of the min of the tree.
    public fun get_min_index<V>(tree: &RedBlackTree<V>): u64 {
        let current = tree.min_index;
        assert!(current != NULL_INDEX, current);
        current
    }

    /// get index of the min of the subtree with root at index.
    public fun get_min_index_from<V>(tree: &RedBlackTree<V>, index: u64): u64 {
        let current = index;
        let left_child = vector::borrow(&tree.entries, current).left_child;

        while (left_child != NULL_INDEX) {
            current = left_child;
            left_child = vector::borrow(&tree.entries, current).left_child;
        };

        current
    }

    /// get index of the max of the tree.
    public fun get_max_index<V>(tree: &RedBlackTree<V>): u64 {
        let current = tree.max_index;
        assert!(current != NULL_INDEX, current);
        current
    }

    /// get index of the max of the subtree with root at index.
    public fun get_max_index_from<V>(tree: &RedBlackTree<V>, index: u64): u64 {
        let current = index;
        let right_child = vector::borrow(&tree.entries, current).right_child;

        while (right_child != NULL_INDEX) {
            current = right_child;
            right_child = vector::borrow(&tree.entries, current).right_child;
        };

        current
    }

    /// find next value in order (the key is increasing)
    public fun next_in_order<V>(tree: &RedBlackTree<V>, index: u64): u64 {
        assert!(index != NULL_INDEX, index);
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
    public fun next_in_reverse_order<V>(tree: &RedBlackTree<V>, index: u64): u64 {
        assert!(index != NULL_INDEX, index);
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

    /// insert puts the value keyed at the input keys into the RedBlackTree.
    /// aborts if the key is already in the tree.
    public fun insert<V>(tree: &mut RedBlackTree<V>, key: u128, value: V) {
        // the max size of the tree is NULL_INDEX.
        assert!(size(tree) < NULL_INDEX, size(tree));
        vector::push_back(
            &mut tree.entries,
            new_entry(key, value)
        );

        let node = size(tree) - 1;

        let parent = NULL_INDEX;
        let insert = tree.root;
        let is_right_child = false;

        while (insert != NULL_INDEX) {
            let insert_node = vector::borrow(&tree.entries, insert);
            assert!(insert_node.key != key, E_INVALID_ARGUMENT);
            parent = insert;
            is_right_child = insert_node.key < key;
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
            if (vector::borrow(&tree.entries, tree.max_index).key < key) {
                tree.max_index = node;
            };
            if (vector::borrow(&tree.entries, tree.min_index).key > key) {
                tree.min_index = node;
            };
        } else {
            tree.root = node;
            tree.min_index = node;
            tree.max_index = node;
        };

        // updat red black tree metadata
        while (parent != NULL_INDEX) {
            let parent_metadata = vector::borrow(&tree.entries, parent).metadata;
            if (parent_metadata == RB_BLACK) {
                break
            };

            parent = rb_update_insert(tree, parent, is_right_child);
            parent_metadata = vector::borrow(&tree.entries, parent).metadata;
            if (parent_metadata == RB_BLACK) {
                break
            };
            let new_parent = vector::borrow(&tree.entries, parent).parent;
            if (new_parent == NULL_INDEX) {
                break
            };
            is_right_child = is_right_child(tree, parent, new_parent);
            parent = new_parent;
        };

        if (tree.root != NULL_INDEX) {
            let root = tree.root;
            vector::borrow_mut(&mut tree.entries, root).metadata = RB_BLACK;
        };
    }

    /// remove deletes and returns the element from the RedBlackTree.
    public fun remove<V>(tree: &mut RedBlackTree<V>, index: u64): (u128, V) {
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
        let is_right = if (parent != NULL_INDEX) {
            is_right_child(tree, index, parent)
        } else {
            false
        };

        let (rebalance_start, is_new_right) =
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
            (parent, is_right)
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
            (parent, is_right)
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

                let old_metadata = vector::borrow(&tree.entries, index).metadata;
                let replaced_metadata = vector::borrow(&tree.entries, right_child).metadata;
                vector::borrow_mut(&mut tree.entries, right_child).metadata = old_metadata;
                vector::borrow_mut(&mut tree.entries, index).metadata = replaced_metadata;

                (right_child, true)
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

                let old_metadata = vector::borrow(&tree.entries, index).metadata;
                let replaced_metadata = vector::borrow(&tree.entries, next_successor).metadata;
                vector::borrow_mut(&mut tree.entries, next_successor).metadata = old_metadata;
                vector::borrow_mut(&mut tree.entries, index).metadata = replaced_metadata;

                (successor_parent, false)
            }
        };

        let removal_metadata = vector::borrow(&tree.entries, index).metadata;
        while (rebalance_start != NULL_INDEX) {
            let (do_continue, new_start) = rb_update_remove(tree, rebalance_start, is_new_right, removal_metadata);
            if (!do_continue) {
                break
            };
            if (new_start == NULL_INDEX) {
                break
            };
            is_new_right = is_right_child(tree, rebalance_start, new_start);
            rebalance_start = new_start;
        };

        if (tree.root != NULL_INDEX) {
            let root = tree.root;
            vector::borrow_mut(&mut tree.entries, root).metadata = RB_BLACK;
        };

        // swap index for pop out.
        let last_index = size(tree) -1;
        if (index != last_index) {
            vector::swap(&mut tree.entries, last_index, index);
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
        let Entry { key, value, parent: _, left_child: _, right_child: _, metadata: _ } = vector::pop_back(&mut tree.entries);

        if (size(tree) == 0) {
            tree.root = NULL_INDEX;
        };

        (key, value)
    }

    /// destroys the tree if it's empty.
    public fun destroy_empty<V>(tree: RedBlackTree<V>) {
        let RedBlackTree { entries, root: _, min_index: _, max_index: _ } = tree;
        assert!(vector::is_empty(&entries), E_INVALID_ARGUMENT);
        vector::destroy_empty(entries);
    }

    /// check if index is the right child of parent.
    /// parent cannot be NULL_INDEX.
    fun is_right_child<V>(tree: &RedBlackTree<V>, index: u64, parent_index: u64): bool {
        assert!(parent_index != NULL_INDEX, E_INVALID_ARGUMENT);
        assert!(parent_index < size(tree), E_INVALID_ARGUMENT);
        vector::borrow(&tree.entries, parent_index).right_child == index
    }

    /// check if index is the left child of parent.
    /// parent cannot be NULL_INDEX.
    fun is_left_child<V>(tree: &RedBlackTree<V>, index: u64, parent_index: u64): bool {
        assert!(parent_index != NULL_INDEX, E_INVALID_ARGUMENT);
        assert!(parent_index < size(tree), E_INVALID_ARGUMENT);
        vector::borrow(&tree.entries, parent_index).left_child == index
    }

    /// Replace the child of parent if parent_index is not NULL_INDEX.
    /// also replace parent index of the child.
    fun replace_child<V>(tree: &mut RedBlackTree<V>, parent_index: u64, original_child: u64, new_child: u64) {
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
    fun replace_left_child<V>(tree: &mut RedBlackTree<V>, parent_index: u64, new_child: u64) {
        if (parent_index != NULL_INDEX) {
            vector::borrow_mut(&mut tree.entries, parent_index).left_child = new_child;
            if (new_child != NULL_INDEX) {
                vector::borrow_mut(&mut tree.entries, new_child).parent = parent_index;
            };
        }
    }

    /// replace right child.
    /// also replace parent index of the child.
    fun replace_right_child<V>(tree: &mut RedBlackTree<V>, parent_index: u64, new_child: u64) {
        if (parent_index != NULL_INDEX) {
            vector::borrow_mut(&mut tree.entries, parent_index).right_child = new_child;
                if (new_child != NULL_INDEX) {
                vector::borrow_mut(&mut tree.entries, new_child).parent = parent_index;
            };
        }
    }

    /// replace parent of index if index is not NULL_INDEX.
    fun replace_parent<V>(tree: &mut RedBlackTree<V>, index: u64, parent_index: u64) {
        if (index != NULL_INDEX) {
            vector::borrow_mut(&mut tree.entries, index).parent = parent_index;
        }
    }


    /// rotate_right (clockwise rotate)
    /// -----------------------------------------------------
    ///                 index
    ///          left            right
    ///        x      y
    /// -----------------------------------------------------
    ///                  left
    ///              x          index
    ///                       y       right
    fun rotate_right<V>(tree: &mut RedBlackTree<V>, index: u64) {
        let node = vector::borrow(&tree.entries, index);
        let left = node.left_child;
        assert!(
            left != NULL_INDEX,
            E_INVALID_ARGUMENT
        );
        let y = vector::borrow(&tree.entries, left).right_child;

        let parent = node.parent;

        // update index
        replace_left_child(tree, index, y);

        // update left
        if (parent != NULL_INDEX) {
            replace_child(tree, parent, index, left);
        } else {
            tree.root = left;
            replace_parent(tree, left, NULL_INDEX);
        };
        replace_right_child(tree, left, index);
    }

    /// rotate_left (counter-clockwis rotate)
    /// -----------------------------------------------------
    ///                 index
    ///          left            right
    ///                       x          y
    /// -----------------------------------------------------
    ///                  right
    ///          index             y
    ///      left        x
    fun rotate_left<V>(tree: &mut RedBlackTree<V>, index: u64) {
        let node = vector::borrow(&tree.entries, index);
        let right = node.right_child;
        assert!(
            right != NULL_INDEX,
            E_INVALID_ARGUMENT,
        );
        let x = vector::borrow(&tree.entries, right).left_child;

        let parent = node.parent;

        // update index
        replace_right_child(tree, index, x);

        // update right
        if (parent != NULL_INDEX) {
            replace_child(tree, parent, index, right);
        } else {
            tree.root = right;
            replace_parent(tree, right, NULL_INDEX);
        };
        replace_left_child(tree, right, index);
    }

    // update red black tree after an insertion of node as red.
    // - is_right indicates if right child is red, otherwise left child is red.
    // - index is a red node.
    // returns
    // - the parent tree.
    fun rb_update_insert<V>(tree: &mut RedBlackTree<V>, index: u64, is_right: bool): u64 {
        let node = vector::borrow(&tree.entries, index);
        // make sure the index right now is red
        assert!(
            node.metadata == RB_RED,
            E_INVALID_ARGUMENT,
        );

        // get the red child.
        let red_child = if (is_right) {
            node.right_child
        } else {
            node.left_child
        };

        assert!(
            vector::borrow(&tree.entries, red_child).metadata == RB_RED,
            E_INVALID_ARGUMENT,
        );

        // get the parent
        // since index is red, the parent must be black
        let parent = node.parent;
        assert!(
            parent != NULL_INDEX,
            E_INVALID_ARGUMENT,
        );

        assert!(
            vector::borrow(&tree.entries, parent).metadata == RB_BLACK,
            E_INVALID_ARGUMENT,
        );

        let is_index_right = is_right_child(tree, index, parent);

        if (!is_index_right) {
            // index is the left child of parent
            //
            let uncle = vector::borrow(&tree.entries, parent).right_child;
            if (uncle != NULL_INDEX && vector::borrow(&tree.entries, uncle).metadata == RB_RED) {
                // case 1, uncle is red
                // recolor parent, index, and uncle.
                //
                //        parent (b)
                //     /          \
                //  index (r)     uncle(r)
                //   /
                //  rec_child
                // --------------
                //        parent (r)
                //     /          \
                //  index (b)     uncle(b)
                //   /
                //  rec_child (r)
                vector::borrow_mut(&mut tree.entries, parent).metadata = RB_RED;
                vector::borrow_mut(&mut tree.entries, index).metadata = RB_BLACK;
                vector::borrow_mut(&mut tree.entries, uncle).metadata = RB_BLACK;
                parent
            } else if (!is_right) {
                // case 2, red_child is left child of index
                // rotate right at parent, recolor parent red, and recolor index black
                //           parent (b)
                //         /            \
                //       index(r)
                //       /      \
                // red_child(r)
                // ---------------
                //             index(b)
                //          /           \
                //     red_child(r)     parent(r)
                rotate_right(tree, parent);
                vector::borrow_mut(&mut tree.entries, parent).metadata = RB_RED;
                vector::borrow_mut(&mut tree.entries, index).metadata = RB_BLACK;
                index
            } else {
                // case 3, red_child is right child of the index
                // rotate left at index, the rotate right at parent, recolor parent red, and recolor index black
                //           parent (b)
                //         /            \
                //       index(r)
                //       /      \
                //           red_child(r)
                // ---------------
                //          red_child(b)
                //          /           \
                //     index(r)     parent(r)
                rotate_left(tree, index);
                rotate_right(tree, parent);
                vector::borrow_mut(&mut tree.entries, red_child).metadata = RB_BLACK;
                vector::borrow_mut(&mut tree.entries, parent).metadata = RB_RED;
                red_child
            }
        } else {
            let uncle = vector::borrow(&tree.entries, parent).left_child;
            if (uncle != NULL_INDEX && vector::borrow(&tree.entries, uncle).metadata == RB_RED) {
                // case 1, uncle is red
                // recolor parent, index, and uncle.
                //
                //        parent (b)
                //     /          \
                //  uncle(r)    index (r)
                //                /
                //            rec_child
                // --------------
                //        parent (r)
                //     /          \
                //  uncle(b)     index (b)
                //                 /
                //            rec_child (r)
                vector::borrow_mut(&mut tree.entries, parent).metadata = RB_RED;
                vector::borrow_mut(&mut tree.entries, index).metadata = RB_BLACK;
                vector::borrow_mut(&mut tree.entries, uncle).metadata = RB_BLACK;
                parent
            } else if (is_right) {
                // case 2, red_child is right child of index
                // rotate left at parent, recolor parent red, and recolor index black
                //           parent (b)
                //         /            \
                //                    index(r)
                //                    /      \
                //                        red_child(r)
                // ---------------
                //             index(b)
                //          /           \
                //      parent(r)      red_child(r)
                rotate_left(tree, parent);
                vector::borrow_mut(&mut tree.entries, parent).metadata = RB_RED;
                vector::borrow_mut(&mut tree.entries, index).metadata = RB_BLACK;
                index
            } else {
                // case 3, red_child is left child of the index
                // rotate right at index, the rotate left at parent, recolor parent red, and recolor index black
                //           parent (b)
                //         /            \
                //                   index(r)
                //       /            /     \
                //           red_child(r)
                // ---------------
                //          red_child(b)
                //          /           \
                //     parent(r)       index(r)
                rotate_right(tree, index);
                rotate_left(tree, parent);
                vector::borrow_mut(&mut tree.entries, red_child).metadata = RB_BLACK;
                vector::borrow_mut(&mut tree.entries, parent).metadata = RB_RED;
                red_child
            }
        }
    }

    // update red black tree after a removal of a node.
    fun rb_update_remove<V>(tree: &mut RedBlackTree<V>, index: u64, is_right: bool, metadata_removed: u8): (bool, u64) {
        // if the removed node is RED, we are good.
        if (metadata_removed == RB_RED) {
            return (false, index)
        };

        let node = vector::borrow(&tree.entries, index);
        // get the new child.
        let child = if (is_right) {
            node.right_child
        } else {
            node.left_child
        };

        // sibling
        let w = if (is_right) {
            node.left_child
        } else {
            node.right_child
        };

        let index_color = node.metadata;

        if (child != NULL_INDEX && vector::borrow(&tree.entries, child).metadata == RB_RED) {
            vector::borrow_mut(&mut tree.entries, child).metadata = RB_BLACK;
            return (false, index)
        };

        // Now child is either black or null.
        // recall a black node is removed from child side.
        // so the sibling must has at least one black node.
        // therefore sibling must exist.
        // w is sibling

        assert!(
            w != NULL_INDEX,
            E_INVALID_ARGUMENT,
        );
        if (!is_right) {
            // if sibling (w) is red
            // rotate left at index.
            //                index (b)
            //            /            \
            // child (null or b)        sibling (r)
            //                          /      \
            //                         B(b)     D(b)
            // ---------------
            //              sibling (b)
            //             /           \
            //          index(r)     D(b)
            //          /         \
            //   child(null or b) B(b)
            let sibling_color = vector::borrow(&tree.entries, w).metadata;
            if (sibling_color == RB_RED) {
                assert!(
                    index_color == RB_BLACK,
                    E_INVALID_ARGUMENT,
                );

                rotate_left(tree, index);
                vector::borrow_mut(&mut tree.entries, w).metadata = RB_BLACK;
                vector::borrow_mut(&mut tree.entries, index).metadata = RB_RED;
                index_color = RB_RED;

                w = vector::borrow(&tree.entries, index).right_child;
                assert!(
                    vector::borrow(&tree.entries, w).metadata == RB_BLACK,
                    E_INVALID_ARGUMENT,
                );
            };

            // Now both siblings are black
            let w_node = vector::borrow(&tree.entries, w);
            let w_left = w_node.left_child;
            let w_right = w_node.right_child;
            let w_left_not_red = w_left == NULL_INDEX || vector::borrow(&tree.entries, w_left).metadata == RB_BLACK;
            let w_right_not_red = w_right == NULL_INDEX || vector::borrow(&tree.entries, w_right).metadata == RB_BLACK;
            if (w_left_not_red && w_right_not_red) {
                // case 1, if both of w's child are not red, color it red
                //            index
                //           /     \
                //         child   w (b)
                vector::borrow_mut(&mut tree.entries, w).metadata = RB_RED;
                (true, vector::borrow(&tree.entries, index).parent)
            } else if (!w_right_not_red) {
                // case 2, w's right child is red, left rotate at index
                //           index
                //         /       \
                //      child     w(b)
                //                /  \
                //               E   D(r)
                // ----------------
                //           w ()
                //         /       \
                //     index(b)   D(b)
                //      /    \
                //    child  E
                rotate_left(tree, index);
                vector::borrow_mut(&mut tree.entries, w).metadata = index_color;
                vector::borrow_mut(&mut tree.entries, index).metadata = RB_BLACK;
                vector::borrow_mut(&mut tree.entries, w_right).metadata = RB_BLACK;
                (false, index)
            } else {
                // case 3, w's left child is red,
                // rotate right at w
                // then treat as case 2, rotate left at index
                //           index
                //          /      \
                //        child       w(b)
                //                /    \
                //              wl(r)   D
                // ---
                //            index
                //          /       \
                //       child     wl(b)
                //                    \
                //                   w(r)
                //                      \
                //                      D
                // ---
                //            wl ()
                //          /       \
                //       index (b)  w(b)
                //      /             \
                //   child              D
                rotate_right(tree, w);
                rotate_left(tree, index);
                vector::borrow_mut(&mut tree.entries, w_left).metadata = index_color;
                vector::borrow_mut(&mut tree.entries, index).metadata = RB_BLACK;
                (false, index)
            }
        } else {
            // if sibling (w) is red
            // rotate right at index.
            //                index (b)
            //            /            \
            //       sibling (r)     child (null or b)
            //        /      \
            //      B(b)     D(b)
            // ---------------
            //              sibling (b)
            //             /           \
            //         B(b)           index(r)
            //                        /      \
            //                      D(b)    child(null or b)
             let sibling_color = vector::borrow(&tree.entries, w).metadata;
             if (sibling_color == RB_RED) {
                assert!(
                    index_color == RB_BLACK,
                    E_INVALID_ARGUMENT,
                );

                rotate_right(tree, index);
                vector::borrow_mut(&mut tree.entries, w).metadata = RB_BLACK;
                vector::borrow_mut(&mut tree.entries, index).metadata = RB_RED;
                index_color = RB_RED;

                w = vector::borrow(&tree.entries, index).left_child;

                assert!(
                    vector::borrow(&tree.entries, w).metadata == RB_BLACK,
                    E_INVALID_ARGUMENT,
                );
             };

            // Now both siblings are black
            let w_node = vector::borrow(&tree.entries, w);
            let w_left = w_node.left_child;
            let w_right = w_node.right_child;
            let w_left_not_red = w_left == NULL_INDEX || vector::borrow(&tree.entries, w_left).metadata == RB_BLACK;
            let w_right_not_red = w_right == NULL_INDEX || vector::borrow(&tree.entries, w_right).metadata == RB_BLACK;
            if (w_left_not_red && w_right_not_red) {
                // case 1, if both of w's child are not red, color it red
                //            index
                //           /     \
                //        w (b)    child
                vector::borrow_mut(&mut tree.entries, w).metadata = RB_RED;
                (true, vector::borrow(&tree.entries, index).parent)
            } else if (!w_left_not_red) {
                // case 2, w's left child is red, right rotate at index
                //           index
                //         /       \
                //      w(b)       child
                //     /  \
                //   D(r)  E
                // ----------------
                //           w ()
                //         /       \
                //      D(b)      index(b)
                //                /   \
                //               E   child
                rotate_right(tree, index);
                vector::borrow_mut(&mut tree.entries, w).metadata = index_color;
                vector::borrow_mut(&mut tree.entries, index).metadata = RB_BLACK;
                vector::borrow_mut(&mut tree.entries, w_left).metadata = RB_BLACK;
                (false, index)
            } else {
                // case 3, w's right child is red,
                // rotate left at w
                // then treat as case 2, rotate right at index
                //           index
                //          /      \
                //       w(b)      child
                //     /    \
                //    D     wr(r)
                // ---
                //            index
                //          /       \
                //        wr(b)     child
                //       /
                //     w(r)
                //    /
                //   D
                // ---
                //            wr ()
                //          /       \
                //       w (b)   index(b)
                //      /             \
                //    D               child
                rotate_left(tree, w);
                rotate_right(tree, index);
                vector::borrow_mut(&mut tree.entries, w_right).metadata = index_color;
                vector::borrow_mut(&mut tree.entries, index).metadata = RB_BLACK;
                (false, index)
            }
        }
    }

    #[test]
    fun test_redblack() {
        let tree = new<u128>();
        insert(&mut tree, 6, 6);
        insert(&mut tree, 5, 5);
        insert(&mut tree, 4, 4);
        let v = vector<Entry<u128>> [
            new_entry_for_test<u128>(6, 6, 1, NULL_INDEX, NULL_INDEX, RB_RED),
            new_entry_for_test<u128>(5, 5, NULL_INDEX, 2, 0, RB_BLACK),
            new_entry_for_test<u128>(4, 4, 1, NULL_INDEX, NULL_INDEX, RB_RED),
        ];

        assert!(tree.root == 1, tree.root);
        assert!(&tree.entries == &v, 2);

        let v = vector<Entry<u128>> [
            new_entry_for_test<u128>(6, 6, 1, NULL_INDEX, NULL_INDEX, RB_BLACK),
            new_entry_for_test<u128>(5, 5, NULL_INDEX, 2, 0, RB_BLACK),
            new_entry_for_test<u128>(4, 4, 1, 3, NULL_INDEX, RB_BLACK),
            new_entry_for_test<u128>(1, 1, 2, NULL_INDEX, NULL_INDEX, RB_RED),
        ];

        insert(&mut tree, 1, 1);
        assert!(&tree.entries == &v, 3);

        let v = vector<Entry<u128>> [
            new_entry_for_test<u128>(6, 6, 1, NULL_INDEX, NULL_INDEX, RB_BLACK),
            new_entry_for_test<u128>(5, 5, NULL_INDEX, 4, 0, RB_BLACK),
            new_entry_for_test<u128>(4, 4, 4, NULL_INDEX, NULL_INDEX, RB_RED),
            new_entry_for_test<u128>(1, 1, 4, NULL_INDEX, NULL_INDEX, RB_RED),
            new_entry_for_test<u128>(3, 3, 1, 3, 2, RB_BLACK),
        ];
        insert(&mut tree, 3, 3);
        assert!(&tree.entries == &v, 4);

        let v = vector<Entry<u128>> [
            new_entry_for_test<u128>(6, 6, 1, NULL_INDEX, NULL_INDEX, RB_BLACK),
            new_entry_for_test<u128>(5, 5, NULL_INDEX, 4, 0, RB_BLACK),
            new_entry_for_test<u128>(4, 4, 4, NULL_INDEX, NULL_INDEX, RB_BLACK),
            new_entry_for_test<u128>(1, 1, 4, NULL_INDEX, 5, RB_BLACK),
            new_entry_for_test<u128>(3, 3, 1, 3, 2, RB_RED),
            new_entry_for_test<u128>(2, 2, 3, NULL_INDEX, NULL_INDEX, RB_RED), // 5
        ];

        insert(&mut tree, 2, 2);
        assert!(&tree.entries == &v, 5);
    }

    #[test]
    fun test_redblack_reverse() {
        let tree = new<u128>();
        insert(&mut tree, 6, 6);
        insert(&mut tree, 7, 7);
        insert(&mut tree, 8, 8);
        let v = vector<Entry<u128>> [
            new_entry_for_test<u128>(6, 6, 1, NULL_INDEX, NULL_INDEX, RB_RED),
            new_entry_for_test<u128>(7, 7, NULL_INDEX, 0, 2, RB_BLACK),
            new_entry_for_test<u128>(8, 8, 1, NULL_INDEX, NULL_INDEX, RB_RED),
        ];

        assert!(tree.root == 1, tree.root);
        assert!(&tree.entries == &v, 2);

        let v = vector<Entry<u128>> [
            new_entry_for_test<u128>(6, 6, 1, NULL_INDEX, NULL_INDEX, RB_BLACK),
            new_entry_for_test<u128>(7, 7, NULL_INDEX, 0, 2, RB_BLACK),
            new_entry_for_test<u128>(8, 8, 1, NULL_INDEX, 3, RB_BLACK),
            new_entry_for_test<u128>(11, 11, 2, NULL_INDEX, NULL_INDEX, RB_RED),
        ];

        insert(&mut tree, 11, 11);
        assert!(&tree.entries == &v, 3);

        let v = vector<Entry<u128>> [
            new_entry_for_test<u128>(6, 6, 1, NULL_INDEX, NULL_INDEX, RB_BLACK),
            new_entry_for_test<u128>(7, 7, NULL_INDEX, 0, 4, RB_BLACK),
            new_entry_for_test<u128>(8, 8, 4, NULL_INDEX, NULL_INDEX, RB_RED),
            new_entry_for_test<u128>(11, 11, 4, NULL_INDEX, NULL_INDEX, RB_RED),
            new_entry_for_test<u128>(9, 9, 1, 2, 3, RB_BLACK),
        ];
        insert(&mut tree, 9, 9);
        assert!(&tree.entries == &v, 4);

        let v = vector<Entry<u128>> [
            new_entry_for_test<u128>(6, 6, 1, NULL_INDEX, NULL_INDEX, RB_BLACK),
            new_entry_for_test<u128>(7, 7, NULL_INDEX, 0, 4, RB_BLACK),
            new_entry_for_test<u128>(8, 8, 4, NULL_INDEX, NULL_INDEX, RB_BLACK),
            new_entry_for_test<u128>(11, 11, 4, 5, NULL_INDEX, RB_BLACK),
            new_entry_for_test<u128>(9, 9, 1, 2, 3, RB_RED),
            new_entry_for_test<u128>(10, 10, 3, NULL_INDEX, NULL_INDEX, RB_RED), // 5
        ];

        insert(&mut tree, 10, 10);
        assert!(&tree.entries == &v, 5);
    }

    #[test]
    fun test_min_iter_redblack() {
        let tree = new<u128>();
        let idx: u128 = 9;
        while (idx > 0) {
            let v = idx * 2;
            insert(&mut tree, v, v);
            idx = idx - 1;
        };

        insert(&mut tree, 0, 0);

        while (idx < 10) {
            let v = idx * 2 + 1;
            insert(&mut tree, v, v);
            idx = idx + 1;
        };

        let idx = 0;
        while (idx < 20) {
            let v = find(&tree, idx);
            idx = idx + 1;
            assert!(option::is_some(&v), (idx as u64));
        };

        let idx: u128 = 0;
        let iter = get_min_index(&tree);
        while (idx < 20) {
            let (_, v) = borrow_at_index(&tree, iter);
            let v = *v;
            assert!(v == idx, (v as u64));
            idx = idx + 1;
            iter = next_in_order(&tree, iter);
        };

        assert!(iter == NULL_INDEX, iter);
        std::debug::print(&tree.entries);
        let min_index = get_min_index(&tree);
        remove(&mut tree, min_index);
        std::debug::print(&tree.entries);
        let i = find(&tree, 4);
        remove(&mut tree, std::option::extract(&mut i));
        std::debug::print(&tree.entries);
        remove(&mut tree, 12);
        std::debug::print(&tree.entries);
        remove(&mut tree, 13);
        while(!empty(&tree)) {
            std::debug::print(&tree.entries);

            let min_index = get_min_index(&tree);
            let (key, value) = borrow_at_index(&tree, min_index);
            let value = *value;
            assert!(key == value, (key as u64));
            remove(&mut tree, min_index);
        };

        std::debug::print(&tree.entries);

        destroy_empty(tree);
    }

    #[test]
    fun test_max_iter_redblack() {
        let tree = new<u128>();
        let idx: u128 = 9;
        while (idx > 0) {
            let v = idx * 2;
            insert(&mut tree, v, v);
            idx = idx - 1;
        };

        insert(&mut tree, 0, 0);

        while (idx < 10) {
            let v = idx * 2 + 1;
            insert(&mut tree, v, v);
            idx = idx + 1;
        };

        let idx = 0;
        while (idx < 20) {
            let v = find(&tree, idx);
            idx = idx + 1;
            assert!(option::is_some(&v), (idx as u64));
        };

        let idx: u128 = 20;
        let iter = get_max_index(&tree);
        while (idx > 0) {
            let (_, v) = borrow_at_index(&tree, iter);
            let v = *v;
            assert!(v == idx - 1, (v as u64));
            idx = idx - 1;
            iter = next_in_reverse_order(&tree, iter);
        };

        assert!(iter == NULL_INDEX, iter);
        std::debug::print(&tree.entries);
        let max_index = get_max_index(&tree);
        remove(&mut tree, max_index);
        std::debug::print(&tree.entries);
        let i = find(&tree, 4);
        remove(&mut tree, std::option::extract(&mut i));
        std::debug::print(&tree.entries);
        remove(&mut tree, 12);
        std::debug::print(&tree.entries);
        remove(&mut tree, 13);
        while(!empty(&tree)) {
            std::debug::print(&tree.entries);

            let max_index = get_max_index(&tree);
            let (key, value) = borrow_at_index(&tree, max_index);
            let value = *value;
            assert!(key == value, (key as u64));
            remove(&mut tree, max_index);
        };

        std::debug::print(&tree.entries);

        destroy_empty(tree);
    }
}
// Tree based on GNU libavl https://adtinfo.org/
module container::avl_tree {
    use std::vector;
    use std::option::{Self, Option};

    const E_INVALID_ARGUMENT: u64 = 1;

    // NULL_INDEX is 1 << 64 - 1 (all 1s for the 64 bits);
    const NULL_INDEX: u64 = 18446744073709551615;

    // check if the index is NULL_INDEX
    public fun is_null_index(index: u64): bool {
        index == NULL_INDEX
    }

    const AVL_ZERO: u8 = 128;
    const AVL_RIGHT_HIGH: u8 = 129;
    const AVL_RIGHT_HIGH_2: u8 = 130;
    const AVL_LEFT_HIGH: u8 = 127;
    const AVL_LEFT_HIGH_2: u8 = 126;

    const METADATA_DEFAULT: u8 = 128;

    /// Entry is the internal AvlTree element.
    struct Entry<V> has store, copy, drop {
        // key
        key: u128,
        // value
        value: V,
        // parent
        parent: u64,
        // left child
        left_child: u64,
        // right child.
        right_child: u64,
        // metadata
        metadata: u8,
    }

    fun new_entry<V>(key: u128, value: V): Entry<V> {
        Entry<V> {
            key,
            value,
            parent: NULL_INDEX,
            left_child: NULL_INDEX,
            right_child: NULL_INDEX,
            metadata: METADATA_DEFAULT,
        }
    }

    #[test_only]
    fun new_entry_for_test<V>(key: u128, value: V, parent: u64, left_child: u64, right_child: u64, metadata: u8): Entry<V> {
        Entry {
            key,
            value,
            parent,
            left_child,
            right_child,
            metadata,
        }
    }

    /// AvlTree contains a vector of Entry<V>, which is triple-linked binary search tree.
    struct AvlTree<V> has store, copy, drop {
        root: u64,
        entries: vector<Entry<V>>,
        min_index: u64,
        max_index: u64,
    }

    /// create new tree
    public fun new<V>(): AvlTree<V> {
        AvlTree {
            root: NULL_INDEX,
            entries: vector::empty<Entry<V>>(),
            min_index: NULL_INDEX,
            max_index: NULL_INDEX,
        }
    }

    ///////////////
    // Accessors //
    ///////////////

    /// find returns the element index in the AvlTree, or none if not found.
    public fun find<V>(tree: &AvlTree<V>, key: u128): Option<u64> {
        let current = tree.root;

        while(current != NULL_INDEX) {
            assert!(current < size(tree), current);
            let node = vector::borrow(&tree.entries, current);
            if (node.key == key) {
                return option::some(current)
            } else if(node.key < key) {
                current = node.right_child;
            } else {
                current = node.left_child;
            };
        };

        option::none()
    }

    /// borrow returns a reference to the element with its key at the given index
    public fun borrow_at_index<V>(tree: &AvlTree<V>, index: u64): (u128, &V) {
        let entry = vector::borrow(&tree.entries, index);
        (entry.key, &entry.value)
    }

    /// borrow_mut returns a mutable reference to the element with its key at the given index
    public fun borrow_at_index_mut<V>(tree: &mut AvlTree<V>, index: u64): (u128, &mut V) {
        let entry = vector::borrow_mut(&mut tree.entries, index);
        (entry.key, &mut entry.value)
    }

    /// size returns the number of elements in the AvlTree.
    public fun size<V>(tree: &AvlTree<V>): u64 {
        vector::length(&tree.entries)
    }

    /// empty returns true if the AvlTree is empty.
    public fun empty<V>(tree: &AvlTree<V>): bool {
        vector::length(&tree.entries) == 0
    }

    /// returns a reference to the AvlTree's entries.
    public fun borrow_entries<V>(tree: &AvlTree<V>): &vector<Entry<V>> {
        &tree.entries
    }

    /// get index of the min of the tree.
    public fun get_min_index<V>(tree: &AvlTree<V>): u64 {
        let current = tree.min_index;
        assert!(current != NULL_INDEX, current);
        current
    }

    /// get index of the min of the subtree with root at index.
    public fun get_min_index_from<V>(tree: &AvlTree<V>, index: u64): u64 {
        let current = index;
        let left_child = vector::borrow(&tree.entries, current).left_child;

        while (left_child != NULL_INDEX) {
            current = left_child;
            left_child = vector::borrow(&tree.entries, current).left_child;
        };

        current
    }

    /// get index of the max of the tree.
    public fun get_max_index<V>(tree: &AvlTree<V>): u64 {
        let current = tree.max_index;
        assert!(current != NULL_INDEX, current);
        current
    }

    /// get index of the max of the subtree with root at index.
    public fun get_max_index_from<V>(tree: &AvlTree<V>, index: u64): u64 {
        let current = index;
        let right_child = vector::borrow(&tree.entries, current).right_child;

        while (right_child != NULL_INDEX) {
            current = right_child;
            right_child = vector::borrow(&tree.entries, current).right_child;
        };

        current
    }

    /// find next value in order (the key is increasing)
    public fun next_in_order<V>(tree: &AvlTree<V>, index: u64): u64 {
        assert!(index != NULL_INDEX, index);
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
    public fun next_in_reverse_order<V>(tree: &AvlTree<V>, index: u64): u64 {
        assert!(index != NULL_INDEX, index);
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

    /// insert puts the value keyed at the input keys into the AvlTree.
    /// aborts if the key is already in the tree.
    public fun insert<V>(tree: &mut AvlTree<V>, key: u128, value: V) {
        // the max size of the tree is NULL_INDEX.
        assert!(size(tree) < NULL_INDEX, size(tree));
        vector::push_back(
            &mut tree.entries,
            new_entry(key, value)
        );

        let node = size(tree) - 1;

        let parent = NULL_INDEX;
        let insert = tree.root;
        let is_right_child = false;

        while (insert != NULL_INDEX) {
            let insert_node = vector::borrow(&tree.entries, insert);
            assert!(insert_node.key != key, E_INVALID_ARGUMENT);
            parent = insert;
            is_right_child = insert_node.key < key;
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
            if (vector::borrow(&tree.entries, tree.max_index).key < key) {
                tree.max_index = node;
            };
            if (vector::borrow(&tree.entries, tree.min_index).key > key) {
                tree.min_index = node;
            };
        } else {
            tree.root = node;
            tree.min_index = node;
            tree.max_index = node;
        };

        // update avl metadata
        while (parent != NULL_INDEX) {
            let (increased, new_parent) = avl_update_insert(tree, parent, is_right_child);
            if (!increased) {
                break
            };
            parent = vector::borrow(&tree.entries, new_parent).parent;
            if (parent == NULL_INDEX) {
                break
            };
            is_right_child = is_right_child(tree, new_parent, parent);
        }
    }

    /// remove deletes and returns the element from the AvlTree.
    public fun remove<V>(tree: &mut AvlTree<V>, index: u64): (u128, V) {
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
        let is_right = if (parent != NULL_INDEX) {
            is_right_child(tree, index, parent)
        } else {
            false
        };

        let (rebalance_start, is_new_right) =
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
            (parent, is_right)
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
            (parent, is_right)
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

                let old_metadata = vector::borrow(&tree.entries, index).metadata;
                let replaced_metadata = vector::borrow(&tree.entries, right_child).metadata;
                vector::borrow_mut(&mut tree.entries, right_child).metadata = old_metadata;
                vector::borrow_mut(&mut tree.entries, index).metadata = replaced_metadata;

                (right_child, true)
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

                let old_metadata = vector::borrow(&tree.entries, index).metadata;
                let replaced_metadata = vector::borrow(&tree.entries, next_successor).metadata;
                vector::borrow_mut(&mut tree.entries, next_successor).metadata = old_metadata;
                vector::borrow_mut(&mut tree.entries, index).metadata = replaced_metadata;

                (successor_parent, false)
            }
        };

        while (rebalance_start != NULL_INDEX) {
            let (decreased, new_start) = avl_update_remove(tree, rebalance_start, is_new_right);
            if (!decreased) {
                break
            };
            rebalance_start = vector::borrow(&tree.entries, new_start).parent;
            if (rebalance_start == NULL_INDEX) {
                break
            };

            is_new_right = is_right_child(tree, new_start, rebalance_start);
        };

        // swap index for pop out.
        let last_index = size(tree) -1;
        if (index != last_index) {
            vector::swap(&mut tree.entries, last_index, index);
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
        let Entry { key, value, parent: _, left_child: _, right_child: _, metadata: _ } = vector::pop_back(&mut tree.entries);

        if (size(tree) == 0) {
            tree.root = NULL_INDEX;
        };

        (key, value)
    }

    /// destroys the tree if it's empty.
    public fun destroy_empty<V>(tree: AvlTree<V>) {
        let AvlTree { entries, root: _, min_index: _, max_index: _ } = tree;
        assert!(vector::is_empty(&entries), E_INVALID_ARGUMENT);
        vector::destroy_empty(entries);
    }

    /// check if index is the right child of parent.
    /// parent cannot be NULL_INDEX.
    fun is_right_child<V>(tree: &AvlTree<V>, index: u64, parent_index: u64): bool {
        assert!(parent_index != NULL_INDEX, E_INVALID_ARGUMENT);
        assert!(parent_index < size(tree), E_INVALID_ARGUMENT);
        vector::borrow(&tree.entries, parent_index).right_child == index
    }

    /// check if index is the left child of parent.
    /// parent cannot be NULL_INDEX.
    fun is_left_child<V>(tree: &AvlTree<V>, index: u64, parent_index: u64): bool {
        assert!(parent_index != NULL_INDEX, E_INVALID_ARGUMENT);
        assert!(parent_index < size(tree), E_INVALID_ARGUMENT);
        vector::borrow(&tree.entries, parent_index).left_child == index
    }

    /// Replace the child of parent if parent_index is not NULL_INDEX.
    /// also replace parent index of the child.
    fun replace_child<V>(tree: &mut AvlTree<V>, parent_index: u64, original_child: u64, new_child: u64) {
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
    fun replace_left_child<V>(tree: &mut AvlTree<V>, parent_index: u64, new_child: u64) {
        if (parent_index != NULL_INDEX) {
            vector::borrow_mut(&mut tree.entries, parent_index).left_child = new_child;
            if (new_child != NULL_INDEX) {
                vector::borrow_mut(&mut tree.entries, new_child).parent = parent_index;
            };
        }
    }

    /// replace right child.
    /// also replace parent index of the child.
    fun replace_right_child<V>(tree: &mut AvlTree<V>, parent_index: u64, new_child: u64) {
        if (parent_index != NULL_INDEX) {
            vector::borrow_mut(&mut tree.entries, parent_index).right_child = new_child;
                if (new_child != NULL_INDEX) {
                vector::borrow_mut(&mut tree.entries, new_child).parent = parent_index;
            };
        }
    }

    /// replace parent of index if index is not NULL_INDEX.
    fun replace_parent<V>(tree: &mut AvlTree<V>, index: u64, parent_index: u64) {
        if (index != NULL_INDEX) {
            vector::borrow_mut(&mut tree.entries, index).parent = parent_index;
        }
    }


    /// rotate_right (clockwise rotate)
    /// -----------------------------------------------------
    ///                 index
    ///          left            right
    ///        x      y
    /// -----------------------------------------------------
    ///                  left
    ///              x          index
    ///                       y       right
    fun rotate_right<V>(tree: &mut AvlTree<V>, index: u64) {
        let node = vector::borrow(&tree.entries, index);
        let left = node.left_child;
        assert!(
            left != NULL_INDEX,
            E_INVALID_ARGUMENT
        );
        let y = vector::borrow(&tree.entries, left).right_child;

        let parent = node.parent;

        // update index
        replace_left_child(tree, index, y);

        // update left
        if (parent != NULL_INDEX) {
            replace_child(tree, parent, index, left);
        } else {
            tree.root = left;
            replace_parent(tree, left, NULL_INDEX);
        };
        replace_right_child(tree, left, index);
    }

    /// rotate_left (counter-clockwis rotate)
    /// -----------------------------------------------------
    ///                 index
    ///          left            right
    ///                       x          y
    /// -----------------------------------------------------
    ///                  right
    ///          index             y
    ///      left        x
    fun rotate_left<V>(tree: &mut AvlTree<V>, index: u64) {
        let node = vector::borrow(&tree.entries, index);
        let right = node.right_child;
        assert!(
            right != NULL_INDEX,
            E_INVALID_ARGUMENT,
        );
        let x = vector::borrow(&tree.entries, right).left_child;

        let parent = node.parent;

        // update index
        replace_right_child(tree, index, x);

        // update right
        if (parent != NULL_INDEX) {
            replace_child(tree, parent, index, right);
        } else {
            tree.root = right;
            replace_parent(tree, right, NULL_INDEX);
        };
        replace_left_child(tree, right, index);
    }

    // update the avl after an insertion resulted in height increase of sub tree of this sub tree at index.
    // - index is the element to be updated.
    // - is_right indicates if the insertion is from the right tree or left tree.
    // returns
    // - if the height of this sub tree is increased.
    // - the new index of the sub tree at this point.
    fun avl_update_insert<V>(tree: &mut AvlTree<V>, index: u64, is_right: bool): (bool, u64) {
        if (index == NULL_INDEX) {
            return (false, index)
        };
        let node = vector::borrow(&tree.entries, index);
        let metadata = node.metadata;

        // if the subtree is balanced, the height of the subtree is increased and the subtree becomes unbalance.
        if (metadata == AVL_ZERO) {
             let new_metadata = if (is_right) {
                AVL_RIGHT_HIGH
            } else {
                AVL_LEFT_HIGH
            };

            vector::borrow_mut(&mut tree.entries, index).metadata = new_metadata;

            return (true, index)
        };

        // if the left tree of this subtree is higher and the right sub tree is increased,
        // the subtree here is now balanced and the height stays the same.
        if (metadata == AVL_LEFT_HIGH && is_right) {
            vector::borrow_mut(&mut tree.entries, index).metadata = AVL_ZERO;
            return (false, index)
        };

        // similarly if the right sub tree of the this sub tree is higher and the left sub tree is increased,
        // the subtree here is now balanced and the height stays the same.
        if (metadata == AVL_RIGHT_HIGH && !is_right) {
            vector::borrow_mut(&mut tree.entries, index).metadata = AVL_ZERO;
            return (false, index)
        };

        // now the tree is unbalanced too much
        let new_metadata = if (metadata == AVL_LEFT_HIGH) {
            AVL_LEFT_HIGH_2
        } else {
            AVL_RIGHT_HIGH_2
        };

        vector::borrow_mut(&mut tree.entries, index).metadata = new_metadata;

        let (decreased, new_index) = avl_rebalance(tree, index, false);
        assert!(decreased, E_INVALID_ARGUMENT);

        (false, new_index)
    }

    // update the avl after a removal resulted in height decrease of sub tree of this sub tree at index.
    // - index is the element to be updated.
    // - is_right indicates if the removal is from the right tree or left tree.
    // returns
    // - if the height of this sub tree is decreased.
    // - the new index of the sub tree at this point.
    fun avl_update_remove<V>(tree: &mut AvlTree<V>, index: u64, is_right: bool): (bool, u64) {
        if (index == NULL_INDEX) {
            return (false, index)
        };

        let metadata = vector::borrow(&tree.entries, index).metadata;

        // sub tree is balanced, it becomes unbalanced but upper tree height doesn't decrease
        if (metadata == AVL_ZERO) {
            let new_metadata = if (is_right) {
                AVL_LEFT_HIGH
            } else {
                AVL_RIGHT_HIGH
            };

            vector::borrow_mut(&mut tree.entries, index).metadata = new_metadata;
            return (false, index)
        };

        // sub tree's left sub tree is high, decreasing its height set the sub tree to balanced.
        // but parent tree height decreases
        if (metadata == AVL_LEFT_HIGH && !is_right) {
            vector::borrow_mut(&mut tree.entries, index).metadata = AVL_ZERO;
            return (true, index)
        };

        // sub tree's right sub tree is high, decreasing its height set the sub tree to balanced.
        // but parent tree height decreases
        if (metadata == AVL_RIGHT_HIGH && is_right) {
            vector::borrow_mut(&mut tree.entries, index).metadata = AVL_ZERO;
            return (true, index)
        };

        let new_metadata = if (metadata == AVL_RIGHT_HIGH) {
            AVL_RIGHT_HIGH_2
        } else {
            AVL_LEFT_HIGH_2
        };

        vector::borrow_mut(&mut tree.entries, index).metadata = new_metadata;

        avl_rebalance(tree, index, true)
    }

    // AVL rebalances the sub tree at index.
    // returns:
    // - if the height of the subtree is decreased.
    // - the index of the new subtree.
    fun avl_rebalance<V>(tree: &mut AvlTree<V>, index: u64, is_remove: bool): (bool, u64) {
        let node = vector::borrow(&tree.entries, index);
        let metadata = node.metadata;

        assert!(metadata == AVL_LEFT_HIGH_2 || metadata == AVL_RIGHT_HIGH_2, E_INVALID_ARGUMENT);


        let left_child = node.left_child;
        let right_child = node.right_child;

        if (metadata == AVL_LEFT_HIGH_2) {
            // left subtree is higher
            let left_metadata = vector::borrow(&tree.entries, left_child).metadata;

            assert!(left_metadata != AVL_RIGHT_HIGH_2 && left_metadata != AVL_LEFT_HIGH_2, E_INVALID_ARGUMENT);
            assert!(is_remove || left_metadata != AVL_ZERO, E_INVALID_ARGUMENT);

            if (left_metadata != AVL_RIGHT_HIGH) {
                // case 1:
                //              index --
                //            /           \
                //         left (-/0)        right
                //        /   \
                //       a     b
                //      /     /
                //     c     (/e)
                // -------
                //               left (0/+)
                //              /      \
                //             a     index (0/-)
                //            /    /         \
                //           c    b          right
                //               /
                //              (/e)
                let old_left_meta = left_metadata;
                rotate_right(tree, index);
                if (old_left_meta == AVL_ZERO) {
                    vector::borrow_mut(&mut tree.entries, left_child).metadata = AVL_RIGHT_HIGH;
                    vector::borrow_mut(&mut tree.entries, index).metadata = AVL_LEFT_HIGH;
                } else {
                    vector::borrow_mut(&mut tree.entries, left_child).metadata = AVL_ZERO;
                    vector::borrow_mut(&mut tree.entries, index).metadata = AVL_ZERO;
                };

                (old_left_meta != AVL_ZERO, left_child)
            } else {
                // case 2:
                //              index --
                //            /          \
                //         left +       right
                //       /    \
                //      a      w (+/0/-)
                //           /   \
                //       (/b/b)  (c/c/)
                // --------
                //                   w 0
                //                /       \
                //       left (-1/0/0)    index (0/0/1)
                //       /    \           /     \
                //      a   (/b/b)   (c/c/)      right
                let w = vector::borrow(&tree.entries, left_child).right_child;
                let w_meta = vector::borrow(&tree.entries, w).metadata;
                rotate_left(tree, left_child);
                rotate_right(tree, index);
                vector::borrow_mut(&mut tree.entries, w).metadata = AVL_ZERO;
                vector::borrow_mut(&mut tree.entries, left_child).metadata = if(w_meta == AVL_RIGHT_HIGH) { AVL_LEFT_HIGH } else {AVL_ZERO};
                vector::borrow_mut(&mut tree.entries, index).metadata = if(w_meta == AVL_LEFT_HIGH) {AVL_RIGHT_HIGH} else {AVL_ZERO};

                (true, w)
            }
        } else {
            let right_metadata = vector::borrow(&tree.entries, right_child).metadata;

            assert!(right_metadata != AVL_RIGHT_HIGH_2 && right_metadata != AVL_LEFT_HIGH_2, E_INVALID_ARGUMENT);
            assert!(is_remove || right_metadata != AVL_ZERO, E_INVALID_ARGUMENT);

            if (right_metadata != AVL_LEFT_HIGH) {
                // case 1:
                //              index ++
                //            /           \
                //         left         right +/0
                //                       /   \
                //                      a     b
                //                     /       \
                //                    (/c)      d
                // -------
                //                 right 0/-1
                //              /          \
                //           index 0/1       b
                //         /        \         \
                //       left        a         d
                //                    \
                //                    (/c)
                let old_right_meta = right_metadata;
                rotate_left(tree, index);
                if (old_right_meta == AVL_ZERO) {
                    vector::borrow_mut(&mut tree.entries, right_child).metadata = AVL_LEFT_HIGH;
                    vector::borrow_mut(&mut tree.entries, index).metadata = AVL_RIGHT_HIGH;
                } else {
                    vector::borrow_mut(&mut tree.entries, right_child).metadata = AVL_ZERO;
                    vector::borrow_mut(&mut tree.entries, index).metadata = AVL_ZERO;
                };
                (old_right_meta != AVL_ZERO, right_child)
            } else {
                // case 2:
                //                index ++
                //            /             \
                //         left            right -
                //                     /          \
                //                   w (-/0/+)      a
                //                  /   \
                //               (b/b/) (/c/c)
                // --------
                //                    w 0
                //            /             \
                //      index (0/0/-1)    right (1/0/0)
                //       /    \           /     \
                //      left  (b/b/)  (/c/c)     a
                let w = vector::borrow(&tree.entries, right_child).left_child;
                let w_meta = vector::borrow(&tree.entries, w).metadata;
                rotate_right(tree, right_child);
                rotate_left(tree, index);
                vector::borrow_mut(&mut tree.entries, w).metadata = AVL_ZERO;
                vector::borrow_mut(&mut tree.entries, right_child).metadata = if (w_meta == AVL_LEFT_HIGH) {AVL_RIGHT_HIGH} else {AVL_ZERO};
                vector::borrow_mut(&mut tree.entries, index).metadata = if (w_meta == AVL_RIGHT_HIGH) {AVL_LEFT_HIGH} else {AVL_ZERO};

                (true, w)
            }
        }
    }

    #[test]
    fun test_avl() {
        let tree = new<u128>();
        insert(&mut tree, 6, 6);
        insert(&mut tree, 5, 5);
        insert(&mut tree, 4, 4);
        let v = vector<Entry<u128>> [
            new_entry_for_test<u128>(6, 6, 1, NULL_INDEX, NULL_INDEX, AVL_ZERO),
            new_entry_for_test<u128>(5, 5, NULL_INDEX, 2, 0, AVL_ZERO),
            new_entry_for_test<u128>(4, 4, 1, NULL_INDEX, NULL_INDEX, AVL_ZERO),
        ];

        assert!(tree.root == 1, tree.root);
        assert!(&tree.entries == &v, 2);

        let v = vector<Entry<u128>> [
            new_entry_for_test<u128>(6, 6, 1, NULL_INDEX, NULL_INDEX, AVL_ZERO),
            new_entry_for_test<u128>(5, 5, NULL_INDEX, 4, 0, AVL_LEFT_HIGH),
            new_entry_for_test<u128>(4, 4, 4, NULL_INDEX, NULL_INDEX, AVL_ZERO),
            new_entry_for_test<u128>(1, 1, 4, NULL_INDEX, NULL_INDEX, AVL_ZERO),
            new_entry_for_test<u128>(3, 3, 1, 3, 2, AVL_ZERO),
        ];

        insert(&mut tree, 1, 1);
        insert(&mut tree, 3, 3);
        assert!(&tree.entries == &v, 3);

        let v = vector<Entry<u128>> [
            new_entry_for_test<u128>(6, 6, 1, NULL_INDEX, NULL_INDEX, AVL_ZERO), // 0
            new_entry_for_test<u128>(5, 5, 4, 2, 0, AVL_ZERO), // 1
            new_entry_for_test<u128>(4, 4, 1, NULL_INDEX, NULL_INDEX, AVL_ZERO), // 2
            new_entry_for_test<u128>(1, 1, 4, NULL_INDEX, 5, AVL_RIGHT_HIGH), // 3
            new_entry_for_test<u128>(3, 3, NULL_INDEX, 3, 1, AVL_ZERO), // 4
            new_entry_for_test<u128>(2, 2, 3, NULL_INDEX, NULL_INDEX, AVL_ZERO), // 5
        ];

        insert(&mut tree, 2, 2);
        assert!(&tree.entries == &v, 4);
    }

    #[test]
    fun test_avl_reverse() {
        let tree = new<u128>();
        insert(&mut tree, 6, 6);
        insert(&mut tree, 7, 7);
        insert(&mut tree, 8, 8);
        let v = vector<Entry<u128>> [
            new_entry_for_test<u128>(6, 6, 1, NULL_INDEX, NULL_INDEX, AVL_ZERO),
            new_entry_for_test<u128>(7, 7, NULL_INDEX, 0, 2, AVL_ZERO),
            new_entry_for_test<u128>(8, 8, 1, NULL_INDEX, NULL_INDEX, AVL_ZERO),
        ];

        assert!(tree.root == 1, tree.root);
        assert!(&tree.entries == &v, 2);

        let v = vector<Entry<u128>> [
            new_entry_for_test<u128>(6, 6, 1, NULL_INDEX, NULL_INDEX, AVL_ZERO),
            new_entry_for_test<u128>(7, 7, NULL_INDEX, 0, 4, AVL_RIGHT_HIGH),
            new_entry_for_test<u128>(8, 8, 4, NULL_INDEX, NULL_INDEX, AVL_ZERO),
            new_entry_for_test<u128>(11, 11, 4, NULL_INDEX, NULL_INDEX, AVL_ZERO),
            new_entry_for_test<u128>(9, 9, 1, 2, 3, AVL_ZERO),
        ];

        insert(&mut tree, 11, 11);
        insert(&mut tree, 9, 9);
        assert!(&tree.entries == &v, 3);

        let v = vector<Entry<u128>> [
            new_entry_for_test<u128>(6, 6, 1, NULL_INDEX, NULL_INDEX, AVL_ZERO), // 0
            new_entry_for_test<u128>(7, 7, 4, 0, 2, AVL_ZERO), // 1
            new_entry_for_test<u128>(8, 8, 1, NULL_INDEX, NULL_INDEX, AVL_ZERO), // 2
            new_entry_for_test<u128>(11, 11, 4, 5, NULL_INDEX, AVL_LEFT_HIGH), // 3
            new_entry_for_test<u128>(9, 9, NULL_INDEX, 1, 3, AVL_ZERO), // 4
            new_entry_for_test<u128>(10, 10, 3, NULL_INDEX, NULL_INDEX, AVL_ZERO), // 5
        ];

        insert(&mut tree, 10, 10);
        assert!(&tree.entries == &v, 4);
    }

    #[test]
    fun test_min_iter_avl() {
        let tree = new<u128>();
        let idx: u128 = 9;
        while (idx > 0) {
            let v = idx * 2;
            insert(&mut tree, v, v);
            idx = idx - 1;
        };

        insert(&mut tree, 0, 0);

        while (idx < 10) {
            let v = idx * 2 + 1;
            insert(&mut tree, v, v);
            idx = idx + 1;
        };

        let idx = 0;
        while (idx < 20) {
            let v = find(&tree, idx);
            idx = idx + 1;
            assert!(option::is_some(&v), (idx as u64));
        };

        let idx: u128 = 0;
        let iter = get_min_index(&tree);
        while (idx < 20) {
            let (_, v) = borrow_at_index(&tree, iter);
            let v = *v;
            assert!(v == idx, (v as u64));
            idx = idx + 1;
            iter = next_in_order(&tree, iter);
        };

        assert!(iter == NULL_INDEX, iter);
        std::debug::print(&tree.entries);
        let min_index = get_min_index(&tree);
        remove(&mut tree, min_index);
        std::debug::print(&tree.entries);
        let i = find(&tree, 4);
        remove(&mut tree, std::option::extract(&mut i));
        std::debug::print(&tree.entries);
        remove(&mut tree, 12);
        std::debug::print(&tree.entries);
        remove(&mut tree, 13);
        while(!empty(&tree)) {
            std::debug::print(&tree.entries);

            let min_index = get_min_index(&tree);
            let (key, value) = borrow_at_index(&tree, min_index);
            let value = *value;
            assert!(key == value, (key as u64));
            remove(&mut tree, min_index);
        };

        std::debug::print(&tree.entries);

        destroy_empty(tree);
    }


    #[test]
    fun test_max_iter_avl() {
        let tree = new<u128>();
        let idx: u128 = 9;
        while (idx > 0) {
            let v = idx * 2;
            insert(&mut tree, v, v);
            idx = idx - 1;
        };

        insert(&mut tree, 0, 0);

        while (idx < 10) {
            let v = idx * 2 + 1;
            insert(&mut tree, v, v);
            idx = idx + 1;
        };

        let idx = 0;
        while (idx < 20) {
            let v = find(&tree, idx);
            idx = idx + 1;
            assert!(option::is_some(&v), (idx as u64));
        };

        let idx: u128 = 20;
        let iter = get_max_index(&tree);
        while (idx > 0) {
            let (_, v) = borrow_at_index(&tree, iter);
            let v = *v;
            assert!(v == idx - 1, (v as u64));
            idx = idx - 1;
            iter = next_in_reverse_order(&tree, iter);
        };

        assert!(iter == NULL_INDEX, iter);
        std::debug::print(&tree.entries);
        let max_index = get_max_index(&tree);
        remove(&mut tree, max_index);
        std::debug::print(&tree.entries);
        let i = find(&tree, 4);
        remove(&mut tree, std::option::extract(&mut i));
        std::debug::print(&tree.entries);
        remove(&mut tree, 12);
        std::debug::print(&tree.entries);
        remove(&mut tree, 13);
        while(!empty(&tree)) {
            std::debug::print(&tree.entries);

            let max_index = get_max_index(&tree);
            let (key, value) = borrow_at_index(&tree, max_index);
            let value = *value;
            assert!(key == value, (key as u64));
            remove(&mut tree, max_index);
        };

        std::debug::print(&tree.entries);

        destroy_empty(tree);
    }
}
