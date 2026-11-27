// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
module app;

import core.thread.osthread : Thread;

@safe:

int main()
{
    const owner = Thread.getThis();
    return owner !is null && Thread.getThis() is owner ? 0 : 1;
}
