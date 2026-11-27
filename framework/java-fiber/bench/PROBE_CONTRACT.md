# flint:java-fiber probe

Both programs store the number of command-line arguments plus one, read it, remove the binding and check that the next read returns zero. Both print the argument count modulo ten and exit successfully. With no arguments the output is `0`. With one argument the output is `1`.

The fixture uses Java `ThreadLocal` with the explicitly installed fiber provider. The baseline uses a raw `FiberLocal` slot for the same operations. Both probes run off fiber. The reactor request tests cover the separate case of interleaved fibers.
