module flint.java.lang.threadlocal;

@safe:

/// A value private to each logical thread, with a separate binding for each ThreadLocal identity.
class ThreadLocal(T)
{
    import flint.java.util.function_.supplier : Supplier;

    /// Initial value. An override may call get, set or remove on this local.
    protected T initialValue()
    {
        return T.init;
    }

    /// Get the current value, initializing the binding if it is absent.
    T get()
    {
        import flint.engine.aot.any : Any;

        auto bindings = requiredBindings();
        Any bound;
        if (bindings.lookup(this, bound))
            return bound.get!T();

        auto value = initialValue();
        bindings.bind(this, Any.of!T(value));
        return value;
    }

    /// Replace the calling logical thread's binding.
    void set(T value)
    {
        import flint.engine.aot.any : Any;

        auto bindings = requiredBindings();
        bindings.bind(this, Any.of!T(value));
    }

    /// Clear the binding so the next get initializes it again.
    void remove()
    {
        if (auto bindings = currentBindings(false))
            bindings.remove(this);
    }

    /// Construct a local whose initial value comes from a Java Supplier.
    static ThreadLocal!T withInitial(Supplier!T supplier)
    {
        if (supplier is null)
            throwNullPointerException();
        return withInitial(supplier.asDelegate());
    }

    /// Construct a local from a supplier whose result is a subtype of T.
    static ThreadLocal!T withInitial(S)(Supplier!S supplier)
            if (!is(S == T) && (is(S == class) || is(S == interface)) && (is(T == class) || is(T == interface))
                && is(S : T))
    {
        if (supplier is null)
            throwNullPointerException();
        return new SuppliedThreadLocal!(T, S)(supplier.asDelegate());
    }

    /// Route untyped null through the Java Supplier overload under R7.
    static ThreadLocal!T withInitial(typeof(null) supplier)
    {
        return withInitial(cast(Supplier!T) supplier);
    }

    /// R9 delegate overload.
    static ThreadLocal!T withInitial(T delegate() @safe supplier)
    {
        if (supplier is null)
            throwNullPointerException();
        return new SuppliedThreadLocal!T(supplier);
    }

    private static auto currentBindings(bool create)
    {
        import flint.java.lang.internal.threadlocalprovider : selectThreadLocalStoreProvider;

        return selectThreadLocalStoreProvider(&nativeBindings)(create);
    }

    private static auto nativeBindings(bool create)
    {
        import flint.java.lang.internal.threadlocalbindings : ThreadLocalBindings;
        import flint.java.nativethreadlocal : nativeThreadLocalValue;

        return cast(ThreadLocalBindings) nativeThreadLocalValue(create, () => new ThreadLocalBindings);
    }

    private static auto requiredBindings()
    {
        import flint.java.lang : IllegalStateException;

        auto bindings = currentBindings(true);
        if (bindings is null)
            throw new IllegalStateException("ThreadLocal provider did not supply a store");
        return bindings;
    }
}

private final class SuppliedThreadLocal(T, S = T) : ThreadLocal!T
{
    private S delegate() @safe supplier;

    this(S delegate() @safe supplier)
    {
        this.supplier = supplier;
    }

    override protected T initialValue()
    {
        return supplier();
    }
}

private noreturn throwNullPointerException()
{
    pragma(inline, false);
    import flint.java.lang : NullPointerException;

    throw new NullPointerException();
}
