// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
module native_provider_test;

import flint.java.lang.threadlocal : ThreadLocal;
import flint.java.fiber : installFiberThreadLocalStoreProvider;

@safe:

@("Repeated fiber provider installation preserves the native caller's local") unittest
{
    assert(installFiberThreadLocalStoreProvider());
    auto local = new ThreadLocal!int;
    local.remove();
    assert(local.get() == 0);
    local.set(47);
    assert(installFiberThreadLocalStoreProvider());
    assert(local.get() == 47);
    local.remove();
    assert(local.get() == 0);
    local.remove();
}
