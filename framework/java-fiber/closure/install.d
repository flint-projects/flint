// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
module app;

import flint.java.fiber : installFiberThreadLocalStoreProvider;

@safe:

int main()
{
    return installFiberThreadLocalStoreProvider() ? 0 : 1;
}
