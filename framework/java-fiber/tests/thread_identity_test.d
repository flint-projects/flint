// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
module flint.java.fiberthreadidentity_test;

import flint.java.fiberthreadidentity : installFiberThreadIdentityProvider;
import flint.java.lang.thread : Thread;

@safe:

@("The fiber Thread identity provider is stable and keeps the interrupt state") unittest
{
    assert(installFiberThreadIdentityProvider());
    auto first = Thread.currentThread();
    auto second = Thread.currentThread();
    assert(first is second);
    assert(first.threadId() > 0);
    assert(!first.isInterrupted());
    first.interrupt();
    assert(first.isInterrupted());
    assert(Thread.interrupted());
    assert(!first.isInterrupted());
    assert(installFiberThreadIdentityProvider());
    assert(Thread.currentThread() is first);
}
