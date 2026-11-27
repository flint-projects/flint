# Native thread storage probe

Both programs retrieve the calling druntime thread and verify its identity.
The package fixture stores that reference in a native thread entry and reads
it back. The control reads the same druntime thread reference directly.
