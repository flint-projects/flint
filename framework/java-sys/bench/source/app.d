// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
module flint.java.nativethreadlocalprobe;

import core.thread.osthread : Thread;
import flint.java.nativethreadlocal : nativeThreadLocalValue;

@safe:

int main()
{
    const owner = Thread.getThis();
    auto first = nativeThreadLocalValue(true, &Thread.getThis);
    return first !is null && first is owner && nativeThreadLocalValue(false, null) is first ? 0 : 1;
}
