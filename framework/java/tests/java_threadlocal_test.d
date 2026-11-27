// Flint conformance cases checked against pinned Temurin ThreadLocal.
module java_threadlocal_test;

import core.thread.osthread : Thread;
import flint.java.lang : NullPointerException, ThreadLocal;
import flint.java.util.function_.supplier : Supplier;

@safe:

private final class NullLocal : ThreadLocal!Object
{
    int initializations;

    override protected Object initialValue()
    {
        ++initializations;
        return null;
    }
}

private final class EquivalentLocal : ThreadLocal!string
{
    override bool opEquals(Object other) const
    {
        return (cast(const EquivalentLocal) other) !is null;
    }

    override size_t toHash() const nothrow
    {
        return 1;
    }
}

private final class ReentrantLocal : ThreadLocal!string
{
    int initializations;
    int explicitSets;

    override protected string initialValue()
    {
        if (++initializations != 1)
            return "inner";
        assert(get() == "inner");
        set("explicit");
        assert(get() == "explicit");
        return "outer";
    }

    override void set(string value)
    {
        ++explicitSets;
        super.set(value);
    }
}

private final class FailingLocal : ThreadLocal!string
{
    int initializations;
    private bool bindBeforeFailure;

    this(bool bindBeforeFailure)
    {
        this.bindBeforeFailure = bindBeforeFailure;
    }

    override protected string initialValue()
    {
        if (++initializations != 1)
            return "retried";
        if (bindBeforeFailure)
            set("saved");
        throw new Exception("expected initialization failure");
    }
}

private void expectInitializationFailure(FailingLocal local)
{
    try
        local.get();
    catch (Exception error)
    {
        assert(error.msg == "expected initialization failure");
        return;
    }
    assert(false, "initializer should throw");
}

@("ThreadLocal records null as an initialized value until remove") unittest
{
    auto local = new NullLocal;
    local.set(null);
    assert(local.get() is null && local.initializations == 0);
    local.remove();
    assert(local.get() is null);
    assert(local.get() is null && local.initializations == 1);
    local.remove();
    assert(local.get() is null && local.initializations == 2);
    local.remove();
}

@("ThreadLocal distinguishes equal keys by identity") unittest
{
    auto first = new EquivalentLocal;
    auto second = new EquivalentLocal;
    assert(first == second);
    first.set("one");
    second.set("two");
    assert(first.get() == "one" && second.get() == "two");
    first.remove();
    assert(second.get() == "two");
    second.remove();
}

@("ThreadLocal initialization reentry commits the outer result without calling virtual set") unittest
{
    auto local = new ReentrantLocal;
    assert(local.get() == "outer");
    assert(local.get() == "outer");
    assert(local.initializations == 2 && local.explicitSets == 1);
    local.remove();
}

@("ThreadLocal retries failed initialization only when still unbound") unittest
{
    auto retry = new FailingLocal(false);
    expectInitializationFailure(retry);
    assert(retry.get() == "retried" && retry.initializations == 2);
    retry.remove();

    auto retained = new FailingLocal(true);
    expectInitializationFailure(retained);
    assert(retained.get() == "saved" && retained.initializations == 1);
    retained.remove();
}

@("ThreadLocal.withInitial accepts the canonical Supplier and a D delegate") unittest
{
    int calls;
    string supply() @safe
    {
        ++calls;
        return "supplier";
    }

    auto fromSupplier = ThreadLocal!string.withInitial(Supplier!string.of(&supply));
    auto fromDelegate = ThreadLocal!string.withInitial(&supply);
    assert(calls == 0);
    assert(fromSupplier.get() == "supplier");
    assert(fromSupplier.get() == "supplier" && calls == 1);
    fromSupplier.remove();
    assert(fromSupplier.get() == "supplier" && fromDelegate.get() == "supplier" && calls == 3);
    fromSupplier.remove();
    fromDelegate.remove();

    expectNullInitializer(() { ThreadLocal!string.withInitial(cast(Supplier!string) null); });
    expectNullInitializer(() { ThreadLocal!string.withInitial(cast(string delegate() @safe) null); });
    expectNullInitializer(() { ThreadLocal!string.withInitial(null); });
}

private void expectNullInitializer(scope void delegate() @safe construct)
{
    try
        construct();
    catch (NullPointerException)
        return;
    assert(false, "null initializer must fail at construction");
}

private interface FactoryValue
{
}

private class FactoryBase : FactoryValue
{
}

private final class FactoryChild : FactoryBase
{
}

private struct FactoryValueWrapper
{
    FactoryChild child;
    alias child this;
}

@("ThreadLocal accepts covariant reference suppliers") unittest
{
    auto child = new FactoryChild;
    auto supplier = Supplier!FactoryChild.of(() => child);
    auto classLocal = ThreadLocal!FactoryBase.withInitial(supplier);
    auto interfaceLocal = ThreadLocal!FactoryValue.withInitial(supplier);
    assert(classLocal.get() is child);
    assert(interfaceLocal.get() is cast(FactoryValue) child);
    classLocal.remove();
    interfaceLocal.remove();

    expectNullInitializer(() {
        ThreadLocal!FactoryBase.withInitial(cast(Supplier!FactoryChild) null);
    });
    static assert(!__traits(compiles, ThreadLocal!string.withInitial(supplier)));
    static assert(!__traits(compiles, ThreadLocal!long.withInitial(Supplier!int.init)));
    static assert(!__traits(compiles, ThreadLocal!FactoryBase.withInitial(Supplier!FactoryValueWrapper.init)));
}

@("ThreadLocal gives each attached native thread its own bindings") @system unittest
{
    auto local = new ThreadLocal!int;
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
