// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
module flint.java.nio.file.path_value_test;

import flint.java.lang : ClassCastException, Comparable, NullPointerException;
import flint.java.nio.file : Path;
import flint.java.nio.file.path : lexicalPath;
import std.exception : collectException;

@safe:

@("Path has value equality and associative array keys")
unittest
{
    auto first = Path.of("outer", "inner");
    auto second = Path.of("outer", "inner");
    assert(first !is second);
    assert(first.equals(second));
    assert(first.equals(cast(Object) second));
    assert(!first.equals(cast(Object) new Object) && !first.equals(null));
    assert(first.hashCode() == second.hashCode());
    Comparable!Path ordering = first;
    assert(ordering.compareTo(second) == 0);

    int[Path] values;
    values[first] = 17;
    assert(values[second] == 17);
    values[second] = 19;
    assert(values.length == 1 && values[first] == 19);
}

@("Unix Path compares unsigned encoded bytes and hashes those bytes")
unittest
{
    auto normalized = lexicalPath("a//b/", null, false);
    auto plain = lexicalPath("a/b", null, false);
    assert(normalized.equals(plain) && normalized.compareTo(plain) == 0);
    assert(plain.hashCode() == 94_772 && normalized.hashCode() == plain.hashCode());
    assert(lexicalPath("é", null, false).compareTo(lexicalPath("z", null, false)) == 73);
    assert(lexicalPath("café", null, false).hashCode() == 94_422_542);
    assert(lexicalPath("a/../b", null, false).hashCode() == -1_473_118_015);
    assert(lexicalPath("", null, false).compareTo(lexicalPath("/", null, false)) == -1);
    assert(!lexicalPath("A", null, false).equals(lexicalPath("a", null, false)));
}

@("Windows Path compares and hashes uppercase UTF-16 code units")
unittest
{
    auto first = lexicalPath("P:/Cafe//À", null, true);
    auto second = lexicalPath("p:\\cAFE\\à\\", null, true);
    assert(first.equals(second) && first.compareTo(second) == 0);
    assert(first.hashCode() == 1_462_612_083 && second.hashCode() == first.hashCode());

    auto i = lexicalPath("i", null, true);
    assert(i.compareTo(lexicalPath("İ", null, true)) == -231);
    assert(i.equals(lexicalPath("ı", null, true)) && i.hashCode() == 73);
    assert(lexicalPath("Ω", null, true).equals(lexicalPath("ω", null, true)));

    auto upper = lexicalPath("𐐀", null, true);
    auto lower = lexicalPath("𐐨", null, true);
    assert(!upper.equals(lower) && upper.compareTo(lower) == -40);
    assert(upper.hashCode() == 1_770_527 && lower.hashCode() == 1_770_567);
    assert(lexicalPath("abc", null, true).compareTo(lexicalPath("abcd", null, true)) == -1);
}

@("Path ordering rejects null and a different provider")
unittest
{
    auto unixPath = lexicalPath("a", null, false);
    auto windowsPath = lexicalPath("a", null, true);
    assert(!unixPath.equals(windowsPath));
    assert(collectException!NullPointerException(unixPath.compareTo(null)) !is null);
    assert(collectException!ClassCastException(unixPath.compareTo(windowsPath)) !is null);
}
