// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
/// Native fallback leaf. Keep imports independent of flint.java.lang so module initialization has no cycle.
module flint.java.nativethreadidentity;

@safe:

// One identity per native thread. A fiber provider replaces this fallback before fibers call currentThread;
// without it, all fibers on one native thread share this identity, as they share the thread. This is a
// reviewed thread root (policy/safety-policy.json), not per-task state.
private Object identity;

package(flint.java) Object nativeThreadIdentity(bool create, Object function() @safe makeValue)
{
    if (identity !is null || !create || makeValue is null)
        return identity;
    identity = makeValue();
    return identity;
}
