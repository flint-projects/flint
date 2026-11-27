module flint.java.util.regex.pattern_test;

import flint.java.lang : IllegalArgumentException;
import flint.java.util.regex.pattern : Matcher, Pattern, PatternSyntaxException;

@safe:

version (Windows)
{
    private enum eol = "\r\n";
}
else
{
    private enum eol = "\n";
}

@("a Pattern is reusable while each Matcher binds its own input")
unittest
{
    auto digits = Pattern.compile("([a-z]+)([0-9]{2})", Pattern.CASE_INSENSITIVE);
    Matcher first = digits.matcher("AbC09");
    Matcher second = digits.matcher("abc9");
    assert(first.pattern() is digits && second.pattern() is digits);
    assert(first.matches() && !second.matches() && first.matches());
    assert(first.groupCount() == 2 && second.groupCount() == 2);
    assert(digits.pattern() == "([a-z]+)([0-9]{2})");
    assert(digits.toString() == digits.pattern());
    assert(digits.flags() == Pattern.CASE_INSENSITIVE);
    assert(Pattern.matches("a.*b", "a--b"));
    assert(!Pattern.matches("a.*b", "a\nb"));
    assert(Pattern.matches("", ""));
}

@("embedded flags affect the Pattern flags outside groups")
unittest
{
    assert(Pattern.compile("a(?i)b").flags() == Pattern.CASE_INSENSITIVE);
    assert(Pattern.compile("(?i:a)b").flags() == 0);
    assert(Pattern.compile("(?-i)a", Pattern.CASE_INSENSITIVE).flags() == 0);
}

@("the internal Pattern helper matches the entire input without a Matcher allocation")
unittest
{
    import core.memory : GC;

    struct Case
    {
        string expression;
        string text;
        bool expected;
        int flags;
    }

    foreach (example; [
        Case("pet", "pet", true), Case("pet", "carpet", false), Case("^pet$", "pet\n", false),
        Case("^pet$", "pet", true), Case("^$", "", true), Case("pet", "", false),
        Case("a.b", "a.b", true, Pattern.LITERAL), Case("a.b", "axb", false, Pattern.LITERAL),
    ])
    {
        auto pattern = Pattern.compile(example.expression, example.flags);
        assert(pattern.matcher(example.text).matches() == example.expected);

        const Pattern compiled = pattern;
        char[6] buffer;
        scope input = buffer[0 .. example.text.length];
        input[] = example.text[];
        const before = GC.stats().allocatedInCurrentThread;
        const matched = compiled.matches(input);
        assert(GC.stats().allocatedInCurrentThread == before);
        assert(matched == example.expected);
    }
}

@("Pattern rejects unknown flags and reports Java syntax exceptions")
unittest
{
    try
    {
        Pattern.compile("abc", 1 << 9);
        assert(0, "expected invalid flags to throw");
    }
    catch (IllegalArgumentException)
    {
    }

    try
    {
        Pattern.compile("(");
        assert(0, "expected an unclosed group to throw");
    }
    catch (PatternSyntaxException failure)
    {
        assert(failure.getDescription().get == "Unclosed group");
        assert(failure.getPattern().get == "(");
        assert(failure.getIndex() == 1);
        assert(failure.getMessage() == "Unclosed group near index 1" ~ eol ~ "(");
    }
}

@("LITERAL matches the expression verbatim and never creates capturing groups")
unittest
{
    const expression = "[abc\\Q\\E]#$";
    auto compiled = Pattern.compile(expression, Pattern.LITERAL);
    assert(compiled.pattern() == expression && compiled.flags() == Pattern.LITERAL);
    auto match = compiled.matcher(expression);
    assert(match.matches() && match.groupCount() == 0);
    assert(!compiled.matcher("abc").matches());
    assert(Pattern.compile("a.b", Pattern.LITERAL).matcher("a.b").matches());
    assert(!Pattern.compile("a.b", Pattern.LITERAL).matcher("axb").matches());
    assert(!Pattern.compile("(?i)A", Pattern.LITERAL).matcher("(?i)a").matches());
    assert(Pattern.compile("", Pattern.LITERAL).matcher("").matches());
    assert(!Pattern.compile("", Pattern.LITERAL).matcher("x").matches());
    assert(Pattern.compile("a\0b", Pattern.LITERAL).matcher("a\0b").matches());
}

@("LITERAL preserves flags and uses only applicable matching options")
unittest
{
    enum literal = Pattern.LITERAL;
    enum ignored = Pattern.COMMENTS | Pattern.MULTILINE | Pattern.DOTALL | Pattern.UNIX_LINES;
    auto pattern = Pattern.compile(" x#\n^A$", literal | ignored);
    assert(pattern.flags() == (literal | ignored));
    assert(pattern.matcher(" x#\n^A$").matches());
    pattern = Pattern.compile("aä😀", literal | Pattern.CASE_INSENSITIVE);
    assert(pattern.matcher("Aä😀").matches());
    assert(!pattern.matcher("AÄ😀").matches());
    assert(!Pattern.compile("å", literal | Pattern.CANON_EQ).matcher("a\u030a").matches());
    pattern = Pattern.compile("\\w", literal | Pattern.UNICODE_CHARACTER_CLASS);
    assert(pattern.flags() == (literal | Pattern.UNICODE_CHARACTER_CLASS | Pattern.UNICODE_CASE));
    assert(pattern.matcher("\\w").matches());
}

@("PatternSyntaxException keeps absent and empty text distinct")
unittest
{
    import std.typecons : Nullable;

    auto exception = new PatternSyntaxException(Nullable!string.init, Nullable!string(""), -2);
    assert(exception.getDescription().isNull);
    assert(!exception.getPattern().isNull && exception.getPattern().get == "");
    assert(exception.getIndex() == -2);
    assert(exception.getMessage() == "null" ~ eol);

    exception = new PatternSyntaxException("", "\t😀x", 2);
    assert(!exception.getDescription().isNull);
    assert(exception.getPattern().get == "\t😀x");
    assert(exception.getMessage() == " near index 2" ~ eol ~ "\t😀x" ~ eol ~ "\t ^");

    exception = new PatternSyntaxException(Nullable!string("bad"), Nullable!string.init, 0);
    assert(exception.getPattern().isNull);
    assert(exception.getMessage() == "bad near index 0" ~ eol ~ "null");

    exception = new PatternSyntaxException("bad", "x", int.max);
    assert(exception.getMessage() == "bad near index 2147483647" ~ eol ~ "x");
}
