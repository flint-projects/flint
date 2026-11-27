// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
module app;

import flint.engine.reactor : FiberLocal;

@safe:

private shared FiberLocal!Object slot;

int main()
{
    return slot.set(slot.get()).code != 0 ? 1 : 0;
}
