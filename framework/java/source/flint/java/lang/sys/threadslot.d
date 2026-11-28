// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
/// Unchecked recovery of the logical-thread object from the provider's GC-scanned slot.
module flint.java.lang.sys.threadslot;

@safe:

/// Recover a `T` from an `Object` slot that the caller knows holds a `T`. This is the unchecked cast the
/// linker needs to keep a leaf out of every probe: a checked downcast emits the leaf's class TypeInfo
/// reference, which under ThinLTO pulls the whole leaf into unrelated programs.
// SAFETY: `value` is the object Thread.currentThread created and the identity provider stored in a
// GC-scanned slot, so the slot keeps it alive; `value` is null or that exact `T` and no other producer writes it.
package(flint.java) @trusted T threadSlot(T)(Object value)
{
    return cast(T) cast(void*) value;
}
