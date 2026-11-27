// The nine module-record-only findings in each release profile follow the
// 17:03Z compile-policy decision (64f0653bc). Remove this probe's temporary
// baseline rows when Flint AOT runtime canonical names and the java.lang
// exception-family move make them unnecessary.
module app;

import flint.java.lang.threadlocal : ThreadLocal;

@safe:

int main(string[] args)
{
    const count = cast(int) args.length;
    auto local = ThreadLocal!int.withInitial(() => count);
    if (local.get() != count)
        return 1;
    local.set(count + 1);
    if (local.get() != count + 1)
        return 2;
    local.remove();
    return local.get() == count ? 0 : 3;
}
