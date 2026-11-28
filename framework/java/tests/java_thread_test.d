// Flint conformance cases checked against pinned Temurin Thread.
module flint.java.lang.thread_test;

import core.sync.semaphore : Semaphore;
import core.thread.osthread : CoreThread = Thread;
import flint.java.lang : NullPointerException;
import flint.java.lang.thread : InterruptSink, Thread;

@safe:

private final class WakeCounter
{
    int count;

    void wake() @safe nothrow @nogc
    {
        ++count;
    }
}

@("currentThread is one stable object with Java's positive id and a default name") unittest
{
    auto first = Thread.currentThread();
    auto second = Thread.currentThread();
    assert(first is second);
    assert(first.threadId() > 0);
    assert(first.getId() == first.threadId());
    assert(first.getName() == "Thread-" ~ decimal(first.threadId()));
    assert(!first.isInterrupted());
    assert(!Thread.interrupted());
}

@("interrupt sets the flag and static interrupted clears it") unittest
{
    auto self = Thread.currentThread();
    self.interrupt();
    assert(self.isInterrupted());
    assert(Thread.interrupted());
    assert(!self.isInterrupted());
    assert(!Thread.interrupted());
}

@("interrupt ends the installed wait and leaves a stale token alone") unittest
{
    auto self = Thread.currentThread();
    self.interrupt();
    assert(Thread.interrupted());

    auto state = self.state();
    auto counter = new WakeCounter;
    const token = state.install(InterruptSink(&counter.wake));
    assert(token != 0);
    assert(state.install(InterruptSink(&counter.wake)) == 0, "a second wait was installed");

    self.interrupt();
    assert(counter.count == 1);
    assert(self.isInterrupted());
    assert(Thread.interrupted());

    assert(state.retire(token));
    assert(!state.retire(token), "a stale token retired the wait");
    self.interrupt();
    assert(counter.count == 1, "interrupt ran a retired wait");
    assert(Thread.interrupted());
}

@system @("interrupt reaches another native thread's flag") unittest
{
    __gshared Thread target;
    auto ready = new Semaphore;
    auto worker = new CoreThread({
        target = Thread.currentThread();
        ready.notify();
        while (!target.isInterrupted())
        {
        }
    });
    worker.start();
    ready.wait();
    target.interrupt();
    worker.join();
    assert(target.isInterrupted());
    assert(!Thread.interrupted(), "the main thread's flag changed");
}

@("setName rejects null as Java does and getName returns the new name") unittest
{
    auto self = Thread.currentThread();
    self.setName("main-worker");
    assert(self.getName() == "main-worker");
    bool threw;
    try
        self.setName(null);
    catch (NullPointerException)
        threw = true;
    assert(threw);
    assert(self.getName() == "main-worker");
}

private string decimal(long value) pure nothrow
{
    if (value == 0)
        return "0";
    char[20] buffer;
    size_t position = buffer.length;
    const negative = value < 0;
    ulong magnitude = negative ? -(cast(ulong) value) : cast(ulong) value;
    while (magnitude)
    {
        buffer[--position] = cast(char)('0' + magnitude % 10);
        magnitude /= 10;
    }
    return (negative ? "-" : "") ~ buffer[position .. $].idup;
}
