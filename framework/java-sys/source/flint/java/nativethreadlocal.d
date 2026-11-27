// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
/// Native thread storage for Flint's Java runtime.
/// The Java facade owns the type of the value stored for each thread.
module flint.java.nativethreadlocal;

public import flint.java.lang.sys.threadtable : nativeThreadLocalValue;

@safe:
