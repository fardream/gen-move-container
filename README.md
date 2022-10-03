# gen-move-container

Containers for move-lang

- Vanilla binary search tree, AVL tree, and red black tree based on [GNU libavl](https://adtinfo.org).

  The versions implemented here are libavl's version with parent pointers. The pointers are replaced by indices that index into a vector.

  The key is right now always `u128` or 128 bit unsigned integer, but supporting other types are trivial.

- Critbit Tree based on [agl/critbit](http://github.com/agl/critbit).

  - Instead of infinite length strings, the key implemented here is fixed width integer.
  - Instead of setting critbit 0 and other bits 1, we use inverse of that. So the masking operation is not bitwise or, but bitwise and.

  The tree splits at the most significant bit, 0-bit is always left sub tree, and 1-bit is always right sub tree, therefore the tree is also a binary search tree, albeit with following differences:

  - the internal nodes of the tree don't contain data.
  - the internal nodes always have two child nodes.
  - the data nodes are the leaf nodes, and they never have data nodes as parent.
