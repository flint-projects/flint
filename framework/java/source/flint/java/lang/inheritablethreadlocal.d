// Ported from openjdk 21.0.13: src/java.base/share/classes/java/lang/InheritableThreadLocal.java
/*
 * Copyright (c) 1998, 2022, Oracle and/or its affiliates. All rights reserved.
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
// Modified by the Flint authors: a logical thread is a reactor fiber or a native thread, so a value belongs to the
// current fiber (D-JDK-6) and a fiber starts without the parent's values, as Java's virtual threads do. `childValue`
// is the hook a later platform-thread start uses; Flint's fibers never call it.
module flint.java.lang.inheritablethreadlocal;

import flint.java.lang.threadlocal : ThreadLocal;

@safe:

/++
Java's `InheritableThreadLocal`: a `ThreadLocal` whose value a child thread may derive from its parent's.

Flint's logical threads are reactor fibers, which have Java's virtual-thread semantics: a new fiber starts with
`T.init` and does not receive the parent's values, matching D-JDK-6. `get`, `set`, `remove` and `initialValue`
are `ThreadLocal`'s and use its installed provider. The inheritance path of a platform thread is not ported yet;
when it is, it reads `childValue` on the parent.
+/
class InheritableThreadLocal(T) : ThreadLocal!T
{
    /// Compute a child logical thread's initial value from the parent's value.
    /// The default returns the parent value; an override may map it.
    protected T childValue(T parentValue)
    {
        return parentValue;
    }
}
