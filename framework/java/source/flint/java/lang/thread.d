// Ported from openjdk 21.0.13: src/java.base/share/classes/java/lang/Thread.java
/*
 * Copyright (c) 1994, 2023, Oracle and/or its affiliates. All rights reserved.
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
 *
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.  Oracle designates this
 * particular file as subject to the "Classpath" exception as provided
 * by Oracle in the LICENSE file that accompanied this code.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
 * or visit www.oracle.com if you need additional information or have any
 * questions.
 */
// Modified by the Flint authors: a logical thread is a reactor fiber or a native thread, the identity comes from
// an installable provider (native fallback in flint:java-sys, fiber in flint:java-fiber), and the interrupt state
// is a small cross-thread facade.
module flint.java.lang.thread;

import core.atomic : atomicExchange, atomicLoad, atomicOp, atomicStore;
import core.sync.mutex : Mutex;

@safe:

/++
A wait that an interrupt ends.

The code that parks installs one before its final flag check, then retires it after it wakes. `wake` runs at
most once per installed wait, on the thread that called `interrupt`, and must not throw, allocate or block. It
may run after the waiter retired the wait, so the waiter re-checks `ThreadState.isInterrupted` after waking.
+/
package(flint.java) struct InterruptSink
{
    /// Ends the registered wait. Null when no wait is installed.
    void delegate() @safe nothrow @nogc wake;
}

/++
One logical thread's interrupt state. Java's `Thread.interrupt`, `isInterrupted` and `interrupted` read and
write it; `java.util.concurrent`'s synchronizers install a wait around a park.

The waiter's protocol, in this order:

1. `token = state.install(InterruptSink(&waiter.wake));`
2. `if (state.isInterrupted()) { state.retire(token); /* handle */ }`
3. park
4. `state.retire(token);`
5. `if (state.isInterrupted()) /* handle */`

An interrupt between steps 1 and 4 either finds the installed sink or is seen by the check at step 2 or 5.
+/
package(flint.java) final class ThreadState
{
    private shared bool interrupted_;
    private Mutex gate;
    private ulong lastToken;
    private ulong activeToken;
    private InterruptSink sink;

    this()
    {
        gate = new Mutex;
    }

    /// Whether the flag is set, without clearing it. Java's `Thread.isInterrupted`.
    bool isInterrupted() nothrow @nogc
    {
        return atomicLoad(interrupted_);
    }

    /// Clear the flag and return its previous value. Java's static `Thread.interrupted`.
    bool clearInterrupted() nothrow @nogc
    {
        return atomicExchange(&interrupted_, false);
    }

    /// Set the flag, then end the installed wait, if any. Java's `Thread.interrupt`.
    void interrupt() nothrow @nogc
    {
        atomicStore(interrupted_, true);
        gate.lock_nothrow();
        const pending = sink;
        gate.unlock_nothrow();
        if (pending.wake !is null)
            pending.wake();
    }

    /// Install one wait. Returns its token, or zero when a wait is already installed.
    ulong install(InterruptSink candidate) nothrow @nogc
    {
        gate.lock_nothrow();
        scope (exit)
            gate.unlock_nothrow();
        if (activeToken != 0)
            return 0;
        activeToken = ++lastToken;
        sink = candidate;
        return activeToken;
    }

    /// Retire the wait named by `token`; a stale or empty token changes nothing.
    bool retire(ulong token) nothrow @nogc
    {
        gate.lock_nothrow();
        scope (exit)
            gate.unlock_nothrow();
        if (token == 0 || activeToken != token)
            return false;
        activeToken = 0;
        sink = InterruptSink.init;
        return true;
    }
}

/++
Java's `Thread` over a logical thread: a reactor task fiber when `flint:java-fiber` installs its identity
provider, and a native thread otherwise. `currentThread` returns the calling logical thread's one object.

`start`, `join`, `sleep` and the deprecated suspension methods are not ported yet; this facade carries the
identity and the interrupt state that `java.util.concurrent` needs.
+/
class Thread
{
    private ThreadState state_;
    private string name_;
    private long id_;

    private this()
    {
        state_ = new ThreadState;
        id_ = atomicOp!"+="(nextThreadId, 1L) + 1;
        name_ = defaultName(id_);
    }

    /// The calling logical thread's `Thread`; the same object on every call from that logical thread.
    static Thread currentThread()
    {
        import flint.java.lang.internal.threadcontrol : selectThreadIdentityProvider;
        import flint.java.lang.sys.threadslot : threadSlot;

        return threadSlot!Thread(selectThreadIdentityProvider(&nativeIdentity)(true, &makeCurrentThread));
    }

    /// Set this logical thread's interrupt flag and end its installed wait, if any.
    void interrupt() nothrow @nogc
    {
        state_.interrupt();
    }

    /// Whether this logical thread's flag is set, without clearing it.
    bool isInterrupted() nothrow @nogc
    {
        return state_.isInterrupted();
    }

    /// Java's static `Thread.interrupted()`: the calling thread's flag, cleared.
    static bool interrupted()
    {
        return currentThread().state_.clearInterrupted();
    }

    /// Java's `threadId()`.
    long threadId() pure nothrow @nogc
    {
        return id_;
    }

    /// Java's deprecated `getId()`, the same value as `threadId()`.
    long getId() pure nothrow @nogc
    {
        return id_;
    }

    /// The thread's name; `Thread-<id>` until `setName` changes it.
    string getName() pure nothrow @nogc
    {
        return name_;
    }

    /// Java's `setName`: a null name throws `NullPointerException`.
    void setName(string name)
    {
        if (name is null)
            throwNullPointerException();
        name_ = name;
    }

    /// The interrupt state, for `java.util.concurrent`'s park protocol.
    package(flint.java) ThreadState state() pure nothrow @nogc
    {
        return state_;
    }
}

// The native fallback: flint:java-sys keeps one identity per native thread. A fiber provider installed by
// flint:java-fiber replaces it before any fiber calls currentThread.
private Object nativeIdentity(bool create, Object function() @safe makeValue)
{
    import flint.java.nativethreadidentity : nativeThreadIdentity;

    return nativeThreadIdentity(create, makeValue);
}

private Object makeCurrentThread()
{
    return new Thread();
}

private shared long nextThreadId;

private string defaultName(long id)
{
    char[20] digits;
    size_t start = digits.length;
    ulong value = cast(ulong) id;
    do
    {
        digits[--start] = cast(char)('0' + value % 10);
        value /= 10;
    }
    while (value);
    return "Thread-" ~ digits[start .. $].idup;
}

private noreturn throwNullPointerException()
{
    pragma(inline, false);
    import flint.java.lang : NullPointerException;

    throw new NullPointerException();
}
