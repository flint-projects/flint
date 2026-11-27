// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
module app;

import core.stdc.stdio : fputc, stdout;
import flint.engine.reactor : FiberLocal;

@safe:

private shared FiberLocal!int value;

int main(string[] arguments)
{
    const count = cast(int) arguments.length;
    if (value.set(count).code != 0)
        return 1;
    const read = value.get();
    value.remove();
    if (read != count || value.get() != 0)
        return 1;

    fputc('0' + (read - 1) % 10, stdout);
    fputc('\n', stdout);
    return 0;
}
