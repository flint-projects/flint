/// Java SE 21 regular-expression compilation and whole-input matching.
module flint.java.util.regex.pattern;

import flint.java.lang : IllegalArgumentException;
import std.typecons : Nullable;
import flint.java.util.regex.internal.engine : Regex, RegexFlag, RegexSyntaxException, compileRegex;

@safe:

/// An immutable compiled expression that can be shared across matchers.
final class Pattern
{
    enum int UNIX_LINES = RegexFlag.UNIX_LINES;
    enum int CASE_INSENSITIVE = RegexFlag.CASE_INSENSITIVE;
    enum int COMMENTS = RegexFlag.COMMENTS;
    enum int MULTILINE = RegexFlag.MULTILINE;
    enum int LITERAL = RegexFlag.LITERAL;
    enum int DOTALL = RegexFlag.DOTALL;
    enum int UNICODE_CASE = RegexFlag.UNICODE_CASE;
    enum int CANON_EQ = RegexFlag.CANON_EQ;
    enum int UNICODE_CHARACTER_CLASS = RegexFlag.UNICODE_CHARACTER_CLASS;

    private immutable string expression;
    private const Regex program;

    private this(string expression, Regex program)
    {
        this.expression = expression;
        this.program = program;
    }

    /// Compile with default flags.
    static Pattern compile(string regex)
    {
        return compile(regex, 0);
    }

    /// Compile with the specified Java flag bits.
    static Pattern compile(string regex, int flags)
    {
        enum allFlags = (UNICODE_CHARACTER_CLASS << 1) - 1;
        if (flags & ~allFlags)
            throw new IllegalArgumentException("Unknown regular expression flags");
        return new Pattern(regex, compilePattern(regex, flags));
    }

    /// Compile an expression and match the entire input once.
    static bool matches(string regex, scope const(char)[] input)
    {
        return compilePattern(regex, 0).matches(input);
    }

    /// Test the entire borrowed input against this pattern without constructing a Matcher.
    package(flint) bool matches(scope const(char)[] input) const
    {
        return program.matches(input);
    }

    /// Bind one input to the compiled expression.
    Matcher matcher(string input)
    {
        return new Matcher(this, input);
    }

    /// The flags in effect after compiling this expression.
    int flags() const pure nothrow @nogc
    {
        return program.flags();
    }

    /// The original expression.
    string pattern() const pure nothrow @nogc
    {
        return expression;
    }

    override string toString() const pure nothrow @nogc
    {
        return expression;
    }
}

/// Whole-input matching against a compiled Pattern.
final class Matcher
{
    private Pattern compiled;
    private string input;

    private this(Pattern compiled, string input)
    {
        this.compiled = compiled;
        this.input = input;
    }

    /// The compiled expression associated with this matcher.
    Pattern pattern() pure nothrow @nogc
    {
        return compiled;
    }

    /// Test the entire input against the pattern.
    bool matches()
    {
        return compiled.matches(input);
    }

    /// Count the capturing groups defined by the pattern.
    int groupCount() const pure nothrow @nogc
    {
        return compiled.program.groupCount();
    }
}

/// A malformed regular expression and the approximate position of the error.
class PatternSyntaxException : IllegalArgumentException
{
    private immutable Nullable!string description;
    private immutable Nullable!string expression;
    private immutable int index;

    /// Construct with present strings. An empty slice remains a present value.
    this(string description, string regex, int index)
    {
        this(Nullable!string(description), Nullable!string(regex), index);
    }

    /// Construct with nullable fields (R5).
    this(Nullable!string description, Nullable!string regex, int index)
    {
        super(syntaxMessage(description, regex, index));
        this.description = description;
        this.expression = regex;
        this.index = index;
    }

    Nullable!string getDescription() const pure nothrow @nogc
    {
        return description;
    }

    Nullable!string getPattern() const pure nothrow @nogc
    {
        return expression;
    }

    int getIndex() const pure nothrow @nogc
    {
        return index;
    }
}

private Regex compilePattern(string regex, int flags)
{
    try
        return compileRegex(regex, flags);
    catch (RegexSyntaxException failure)
        throw new PatternSyntaxException(failure.description, failure.pattern, cast(int) failure.index);
}

private string syntaxMessage(Nullable!string description, Nullable!string expression, int index)
{
    import flint.engine.aot.text : decimal, decodeUtf8;

    version (Windows)
        enum eol = "\r\n";
    else
        enum eol = "\n";

    const detail = description.isNull ? "null" : description.get;
    const pattern = expression.isNull ? "null" : expression.get;
    if (index < 0)
        return detail ~ eol ~ pattern;
    string message = detail ~ " near index " ~ decimal(index) ~ eol ~ pattern;
    if (expression.isNull)
        return message;

    size_t units;
    size_t cursor;
    while (cursor < pattern.length && units <= index)
        units += decodeUtf8(pattern, cursor) > wchar.max ? 2 : 1;
    if (units <= index)
        return message;

    auto indicator = new char[eol.length + cast(size_t) index + 1];
    indicator[0 .. eol.length] = eol;
    indicator[eol.length .. $ - 1] = ' ';
    indicator[$ - 1] = '^';
    cursor = 0;
    for (size_t indent = 0; indent < index;)
    {
        const codePoint = decodeUtf8(pattern, cursor);
        if (codePoint == '\t')
            indicator[eol.length + indent] = '\t';
        indent += codePoint > wchar.max ? 2 : 1;
    }
    message ~= indicator[];
    return message;
}
