module flint.java.lang.internal.threadcontrol;

import core.atomic : atomicLoad, cas;

@safe:

/// Create the calling logical thread's `Thread` object on first use.
package(flint.java) alias ThreadFactory = Object function() @safe;

/// Resolve the calling logical thread's identity. The native provider is `flint.java.nativethreadidentity`;
/// `flint:java-fiber` installs a fiber provider before any fiber calls `Thread.currentThread`.
package(flint.java) alias ThreadIdentityProvider = Object function(bool create, ThreadFactory make) @safe;

private shared ThreadIdentityProvider selected;

/// Install before the first `Thread.currentThread`. Repeating the same provider preserves the selection.
package(flint.java) bool installThreadIdentityProvider(ThreadIdentityProvider provider) nothrow @nogc
{
    if (provider is null)
        return false;
    return cas(&selected, ThreadIdentityProvider.init, provider) || atomicLoad(selected) is provider;
}

package(flint.java):
ThreadIdentityProvider selectThreadIdentityProvider(ThreadIdentityProvider fallback) nothrow @nogc
{
    auto provider = atomicLoad(selected);
    if (provider is null)
    {
        if (cas(&selected, ThreadIdentityProvider.init, fallback))
            provider = fallback;
        else
            provider = atomicLoad(selected);
    }
    return provider;
}
