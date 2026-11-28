// Flint conformance cases for java.lang.InheritableThreadLocal, checked against pinned Temurin 21.0.13+9.
module java_inheritablethreadlocal_test;

import core.thread.osthread : Thread;
import flint.java.lang : InheritableThreadLocal, ThreadLocal;

@safe:

private final class DefaultChildValue(T) : InheritableThreadLocal!T
{
    T inherit(T parentValue)
    {
        return childValue(parentValue);
    }
}

private final class DoublingChildValue : InheritableThreadLocal!int
{
    int calls;

    override protected int childValue(int parentValue)
    {
        ++calls;
        return parentValue * 2;
    }

    int inherit(int parentValue)
    {
        return childValue(parentValue);
    }
}

private final class NullInitial : InheritableThreadLocal!Object
{
    int initializations;

    override protected Object initialValue()
    {
        ++initializations;
        return null;
    }
}

@("InheritableThreadLocal.childValue returns the parent value by default") unittest
{
    auto text = new DefaultChildValue!string;
    assert(text.inherit("parent") == "parent");
    assert(text.inherit(null) is null);

    auto number = new DefaultChildValue!int;
    assert(number.inherit(41) == 41);
}

@("InheritableThreadLocal.childValue may map the parent value, and get does not call it") unittest
{
    auto local = new DoublingChildValue;
    assert(local.inherit(21) == 42 && local.calls == 1);
    local.set(21);
    assert(local.get() == 21 && local.calls == 1);
    local.remove();
}

@("InheritableThreadLocal records null as an initialized value until remove") unittest
{
    auto local = new NullInitial;
    local.set(null);
    assert(local.get() is null && local.initializations == 0);
    local.remove();
    assert(local.get() is null && local.initializations == 1);
    local.remove();
}

@("InheritableThreadLocal keeps a binding separate from an ordinary ThreadLocal") unittest
{
    auto ordinary = new ThreadLocal!string;
    auto inheritable = new InheritableThreadLocal!string;
    ordinary.set("ordinary");
    inheritable.set("inheritable");
    assert(ordinary.get() == "ordinary" && inheritable.get() == "inheritable");
    ordinary.remove();
    assert(inheritable.get() == "inheritable");
    inheritable.remove();
}

@("InheritableThreadLocal gives each attached native thread its own bindings") @system unittest
{
    auto local = new InheritableThreadLocal!int;
    local.set(41);

    auto worker = new Thread(() {
        assert(local.get() == 0);
        local.set(73);
        assert(local.get() == 73);
        // The native table hook must retire this worker's store on exit.
    });
    worker.start();
    worker.join();

    assert(local.get() == 41);
    local.remove();
}
