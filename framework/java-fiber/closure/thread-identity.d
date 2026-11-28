// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
module app;

import flint.java.fiberthreadidentity : installFiberThreadIdentityProvider;

@safe:

int main()
{
    return installFiberThreadIdentityProvider() ? 0 : 1;
}
