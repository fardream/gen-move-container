# gen-move-container

Containers for [move-lang](https://github.com/move-language/move).

This module contains a golang binary to generate containers for move-lang.

```shell
go run github.com/fardream/gen-move-container --help
generate container types for move

base on GNU libavl https://adtinfo.org/
- vanilla binary tree
- avl tree
- red black tree

based on http://github.com/agl/critbit
- critbit tree

Usage:
  gen-move-container [command]

Available Commands:
  avl         generate avl tree
  bst         generate vanilla (b)inary (s)earch (t)ree
  completion  Generate the autocompletion script for the specified shell
  critbit     generate critbit tree
  help        Help about any command
  red-black   generate red-black tree

Flags:
  -h, --help   help for gen-move-container

Use "gen-move-container [command] --help" for more information about a command.
```

A copy of the generated code can be found at [containter](./container). The code is not deployed on chain yet.

## Red Black Tree, AVL Tree, and Binary Search Tree

Vanilla binary search tree, AVL tree, and red black tree based on [GNU libavl](https://adtinfo.org).

The versions implemented here are libavl's version with parent pointers. The pointers are replaced by indices that index into a vector.

The key is right now always `u128` or 128 bit unsigned integer, but supporting other types are trivial.

## Critbit Tree

Critbit Tree based on [agl/critbit](http://github.com/agl/critbit), but with some differences:

- Instead of infinite length strings, the key implemented here is fixed width integer.
- Instead of setting critbit 0 and other bits 1, we use inverse of that. So the masking operation is not bitwise or, but bitwise and.

The tree splits at the most significant bit, 0-bit is always left sub tree, and 1-bit is always right sub tree, therefore the tree is also a binary search tree, albeit with following differences:

- the internal nodes of the tree don't contain data.
- the internal nodes always have two child nodes.
- the data nodes are the leaf nodes, and they never have data nodes as parent.

## Aptos Storage Gas

On [aptos blockchain](https://aptoslabs.com), reading (`borrow_global`) and writing (`borrow_global_mut`) all cost gas. For binary search trees, this will be extremely costly if a whole tree needs to be read only to look up one value. In a perfectly balanced tree of 1024 nodes, only 10 nodes are needed to look up a value and loading other 1014 nodes is quite wasteful.

Luckily, aptos provides a solution in [`table`](https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-stdlib/sources/table.move), where the each entry of the data can be borrowed individually. Although creating and borrowing entries in table are more costly than adding/removing elements from a vector, the amount of data borrowed will be much smaller. In the above example of perfect balanced tree of 1024 nodes, table based tree only needs to load 10 entries.

To turn on aptos table, use `--use-aptos-table` option for all the code generation command. A copy of the generated code is provided in [container-aptos-table](./container-aptos-table).

On drawback of the table in aptos is that the table structure is an extension of aptos to the standard move library. From off-chain, the data is not directly obtainable by reading the resources of the owning address. Instead, there is a special table api for aptos node.

Table right now doesn't support iterators, there is no way for onchain or offchain users to get some or all of the keys in the table. To simplify onchain and offchain access, the trees are keyed by the index as if they are stored in a vector. The length of the table is available by reading the resource, and the keys of the tables will be 0-(length - 1).
