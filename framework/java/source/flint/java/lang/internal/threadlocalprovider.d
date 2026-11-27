module flint.java.lang.internal.threadlocalprovider;

import core.atomic : atomicLoad, cas;
import flint.java.lang.internal.threadlocalbindings : ThreadLocalBindings;

@safe:

/// Return the calling logical thread's owned store, or null when no store is available.
package(flint.java) alias ThreadLocalStoreProvider = ThreadLocalBindings function(bool create) @safe;

private shared ThreadLocalStoreProvider selected;

/// Install before the first operation. Repeating the same provider preserves the existing selection.
package(flint.java) bool installThreadLocalStoreProvider(ThreadLocalStoreProvider provider) nothrow @nogc
{
    if (provider is null)
        return false;
    return cas(&selected, ThreadLocalStoreProvider.init, provider) || atomicLoad(selected) is provider;
}

package(flint.java.lang):

ThreadLocalStoreProvider selectThreadLocalStoreProvider(ThreadLocalStoreProvider fallback) nothrow @nogc
{
    auto provider = atomicLoad(selected);
    if (provider is null)
    {
        if (cas(&selected, ThreadLocalStoreProvider.init, fallback))
            provider = fallback;
        else
            provider = atomicLoad(selected);
    }
    return provider;
}
