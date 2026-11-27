// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
module flint.java.native_thread_store_test;

import flint.java.nativethreadlocal : nativeThreadLocalValue;

@safe:

@("Native thread storage calls the factory only when an entry is missing") unittest
{
    assert(nativeThreadLocalValue(false, null) is null);
    assert(nativeThreadLocalValue(true, null) is null);
    assert(nativeThreadLocalValue(true, () => cast(Object) null) is null);
    auto first = nativeThreadLocalValue(true, () => new Object);
    assert(first !is null);
    assert(nativeThreadLocalValue(false, null) is first);
    assert(nativeThreadLocalValue(true, () => new Object) is first);
}
