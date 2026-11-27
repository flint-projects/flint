// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
/// Native fallback leaf. Keep imports independent of flint.java.lang so module initialization has no cycle.
module flint.java.lang.sys.threadtable;

import core.exception : onInvalidMemoryOperationError;
import core.sync.mutex : Mutex;
import core.thread.osthread : Thread;
import core.thread.types : ThreadID;

@safe:

private final class Entry
{
    ThreadID id;
    Thread owner;
    Object value;
    Entry next;

    this(ThreadID id, Thread owner, Object value)
    {
        this.id = id;
        this.owner = owner;
        this.value = value;
    }
}

private struct Change
{
    Object value;
    Entry detached;
}

private final class ThreadTable
{
    private shared(Mutex) gate;
    private Entry first;

    this() shared
    {
        gate = new shared Mutex;
    }

    Object current(Thread owner, ThreadID id, bool create, Object function() @safe makeValue) shared
    {
        if (auto stored = access(owner, id).value)
            return stored;

        if (!create || makeValue is null)
            return null;

        // Call the factory and allocate before acquiring the registry lock.
        auto value = makeValue();
        if (value is null)
            return null;
        auto change = access(owner, id, new Entry(id, owner, value));
        clearDetached(change.detached);
        return change.value;
    }

    void retire(Thread owner, ThreadID id) shared nothrow @nogc
    {
        clearDetached(access(owner, id, null, true).detached);
    }

private:

    // SAFETY: gate serializes access to the table. Only the calling thread's value or an unlinked
    // entry leave the locked region. No link into the live table or reference to its fields escapes.
    @trusted Change access(Thread owner, ThreadID id, Entry fresh = null, bool retiring = false) shared nothrow @nogc
    {
        gate.lock_nothrow();
        scope (exit)
            gate.unlock_nothrow();

        auto table = cast(ThreadTable) this;
        auto link = &table.first;
        while (*link !is null && (*link).id != id)
            link = &(*link).next;

        auto entry = *link;
        if (entry !is null && entry.owner is owner)
        {
            if (!retiring)
                return Change(entry.value);
            *link = entry.next;
            entry.next = null;
            return Change(null, entry);
        }

        if (fresh is null)
            return Change.init;

        if (entry !is null)
        {
            fresh.next = entry.next;
            entry.next = null;
        }
        *link = fresh;
        return Change(fresh.value, entry);
    }

    static void clearDetached(Entry entry) nothrow @nogc
    {
        if (entry !is null)
        {
            entry.value = null;
            entry.owner = null;
        }
    }
}

private shared(ThreadTable) registry;

shared static this()
{
    registry = new shared ThreadTable;
}

/// flint.java.lang.threadlocal is the sole owner of this native fallback slot on each thread.
/// A foreign detach that skips module destructors retains its entry until ID reuse or process exit.
package(flint.java) Object nativeThreadLocalValue(bool create, Object function() @safe makeValue)
{
    auto owner = Thread.getThis();
    // An unattached thread cannot allocate an exception on the GC.
    if (owner is null)
        onInvalidMemoryOperationError();
    return registry.current(owner, owner.id, create, makeValue);
}

static ~this()
{
    if (auto owner = Thread.getThis())
        registry.retire(owner, owner.id);
}
