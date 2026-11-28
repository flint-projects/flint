// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
module flint.java.nativethreadidentityprobe;

import flint.java.nativethreadidentity : nativeThreadIdentity;

@safe:

int main()
{
    auto first = nativeThreadIdentity(true, () => new Object);
    return first !is null && nativeThreadIdentity(false, null) is first ? 0 : 1;
}
