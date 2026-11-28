module app;

import flint.java.lang.inheritablethreadlocal : InheritableThreadLocal;

@safe:

// Use the inherited default childValue through a wrapper, then an override.
private final class DefaultChild(T) : InheritableThreadLocal!T
{
    T inherit(T parentValue)
    {
        return childValue(parentValue);
    }
}

private final class Doubling : InheritableThreadLocal!int
{
    override protected int childValue(int parentValue)
    {
        return parentValue * 2;
    }

    int inheritValue(int parentValue)
    {
        return childValue(parentValue);
    }
}

int main(string[] args)
{
    const count = cast(int) args.length;
    auto text = new DefaultChild!string;
    if (text.inherit("parent") != "parent")
        return 1;

    auto local = new Doubling;
    if (local.get() != 0)
        return 2;
    local.set(count);
    if (local.get() != count || local.inheritValue(count) != count * 2)
        return 3;
    local.remove();
    return local.get() == 0 ? 0 : 4;
}
