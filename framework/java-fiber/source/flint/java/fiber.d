// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
/// Flint composition of Java ThreadLocal bindings with engine reactor fibers.
module flint.java.fiber;

import core.exception : onInvalidMemoryOperationError;
import core.thread.osthread : Thread;
import flint.engine.reactor : FiberLocal;
import flint.java.lang.internal.threadlocalbindings : ThreadLocalBindings;
import flint.java.lang.internal.threadlocalprovider : installThreadLocalStoreProvider;

@safe:

private shared FiberLocal!ThreadLocalBindings bindings;

/// Flint extension for application composition. Install before any ThreadLocal operation.
/// Reinstalling this provider preserves existing bindings.
bool installFiberThreadLocalStoreProvider() nothrow @nogc
{
    // Claim the process-wide slot before worker fibers can race to use it.
    // Writing back the current value also preserves bindings on repeated startup.
    return bindings.set(bindings.get()).code == 0 && installThreadLocalStoreProvider(&currentBindings);
}

private ThreadLocalBindings currentBindings(bool create)
{
    if (Thread.getThis() is null)
        onInvalidMemoryOperationError();

    auto current = bindings.get();
    if (current !is null || !create)
        return current;

    current = new ThreadLocalBindings;
    // The ThreadLocal caller reports an unavailable creating lookup.
    return bindings.set(current).code == 0 ? current : null;
}
