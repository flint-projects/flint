module flint.java.lang.internal.threadlocalbindings;

import flint.engine.aot.any : Any;

@safe:

/// Bindings accessed exclusively by one logical thread.
package(flint.java) final class ThreadLocalBindings
{
    private struct Entry
    {
        Object key;
        Any value;
    }

    private Entry[] entries;

    private size_t find(scope Object key) const nothrow @nogc
    {
        foreach (index, ref const entry; entries)
            if (entry.key is key)
                return index;
        return entries.length;
    }

    bool lookup(scope Object key, out Any value) nothrow @nogc
    {
        const index = find(key);
        if (index == entries.length)
            return false;
        value = entries[index].value;
        return true;
    }

    // Emit array growth only where ThreadLocal binds a value.
    void bind()(Object key, Any value)
    {
        const index = find(key);
        if (index == entries.length)
            entries ~= Entry(key, value);
        else
            entries[index].value = value;
    }

    void remove(scope Object key) nothrow @nogc
    {
        const index = find(key);
        if (index == entries.length)
            return;
        entries[index] = entries[$ - 1];
        // The GC scans the backing allocation even after the slice is shortened.
        entries[$ - 1] = Entry.init;
        entries = entries[0 .. $ - 1];
    }
}
