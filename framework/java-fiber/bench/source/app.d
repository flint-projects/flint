// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
module app;

import core.stdc.stdio : fputc, stdout;
import flint.java.lang.threadlocal : ThreadLocal;
import flint.java.fiber : installFiberThreadLocalStoreProvider;

@safe:

int main(string[] arguments)
{
    if (!installFiberThreadLocalStoreProvider())
        return 1;

    auto local = new ThreadLocal!int;
    const count = cast(int) arguments.length;
    local.set(count);
    const read = local.get();
    local.remove();
    if (read != count || local.get() != 0)
        return 1;

    fputc('0' + (read - 1) % 10, stdout);
    fputc('\n', stdout);
    return 0;
}
