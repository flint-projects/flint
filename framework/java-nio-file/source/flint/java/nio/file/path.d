/*
 * Copyright (c) 2007, 2023, Oracle and/or its affiliates. All rights reserved.
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
 *
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.  Oracle designates this
 * particular file as subject to the "Classpath" exception as provided
 * by Oracle in the LICENSE file that accompanied this code.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
 * or visit www.oracle.com if you need additional information or have any
 * questions.
 */
/*
 * Copyright (c) 2008, 2023, Oracle and/or its affiliates. All rights reserved.
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
 *
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.  Oracle designates this
 * particular file as subject to the "Classpath" exception as provided
 * by Oracle in the LICENSE file that accompanied this code.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
 * or visit www.oracle.com if you need additional information or have any
 * questions.
 */
/*
 * Copyright (c) 2008, 2022, Oracle and/or its affiliates. All rights reserved.
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
 *
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.  Oracle designates this
 * particular file as subject to the "Classpath" exception as provided
 * by Oracle in the LICENSE file that accompanied this code.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
 * or visit www.oracle.com if you need additional information or have any
 * questions.
 */
// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
// Ported from openjdk 21.0.13: src/java.base/share/classes/java/nio/file/Path.java
// Ported from openjdk 21.0.13: src/java.base/unix/classes/sun/nio/fs/UnixPath.java
// Ported from openjdk 21.0.13: src/java.base/windows/classes/sun/nio/fs/WindowsPathParser.java
// Ported from openjdk 21.0.13: src/java.base/windows/classes/sun/nio/fs/WindowsPath.java
// Modified by the Flint authors.
module flint.java.nio.file.path;

import flint.java.lang : ClassCastException, Comparable, IllegalArgumentException, JavaObject, NullPointerException;
import flint.java.nio.file.invalidpathexception : InvalidPathException;

@safe:

private template arePathParts(Parts...)
{
    static if (Parts.length)
        enum arePathParts = is(Parts[0] == string) && arePathParts!(Parts[1 .. $]);
    else
        enum arePathParts = true;
}

version (unittest)
{
    private enum includeUnixPath = true;
    private enum includeWindowsPath = true;
}
else version (Windows)
{
    private enum includeUnixPath = false;
    private enum includeWindowsPath = true;
}
else
{
    private enum includeUnixPath = true;
    private enum includeWindowsPath = false;
}

/// A path described by a root and a sequence of names.
interface Path : Comparable!Path
{
    /// Joins the nonempty path parts using the default provider's separator.
    /// Null strings and an array of additional parts that is null count as empty (R26).
    static Path of(string first, scope const(string)[] more = null)
    {
        version (Windows)
            return windowsPath(joinPath(first, more, '\\'));
        else
            return unixPath(joinPath(first, more, '/'));
    }

    /// Joins path parts supplied as separate string arguments (R7).
    static Path of(Parts...)(string first, Parts parts) if (Parts.length && arePathParts!Parts)
    {
        string[Parts.length] arguments = [parts];
        return of(first, arguments[]);
    }

    /// Returns whether the path denotes a complete location in its filesystem.
    bool isAbsolute();

    /// Returns the root component, or null if the path has no root.
    Path getRoot();

    /// Returns the parent, or null if there is none.
    Path getParent();

    /// Returns the last name element, or null for a path consisting solely of a root.
    Path getFileName();

    /// Returns the number of name elements.
    int getNameCount();

    /// Returns the name at the given zero-based index.
    Path getName(int index);

    /// Returns the relative sequence of names in the half-open interval.
    Path subpath(int beginIndex, int endIndex);

    /// Orders paths from the same provider by its lexical rules.
    /// Throws NullPointerException for a null path and ClassCastException for a different provider.
    override int compareTo(Path other);

    /// Returns whether the other object is an equal path from the same provider.
    bool equals(Object other);

    /// Compares another path interface reference (R11).
    bool equals(T)(T other) if (is(T == interface) && is(T : Path))
    {
        return equals(cast(Object) other);
    }

    /// Returns the provider's hash of the path spelling.
    int hashCode();

    /// Returns the path spelling.
    string toString();
}

version (unittest)
{
    package(flint.java.nio.file) Path lexicalPath(string first, scope const(string)[] more, bool windows)
    {
        return windows ? windowsPath(joinPath(first, more, '\\')) : unixPath(joinPath(first, more, '/'));
    }
}

private string joinPath(string first, scope const(string)[] more, char separator)
{
    string input = first.length ? first : "";
    foreach (part; more)
    {
        if (part.length == 0)
            continue;
        if (input.length)
            input ~= separator;
        input ~= part;
    }
    return input;
}

// R8 keeps explicit null reference failures out of the common path.
pragma(inline, false) package(flint.java.nio.file) noreturn throwNullPathReference()
{
    throw new NullPointerException;
}

static if (includeUnixPath)
{
    private Path unixPath(string input)
    {
        bool normalize = input.length > 1 && input[$ - 1] == '/';
        char previous;
        foreach (ch; input)
        {
            if (ch == '\0')
                throw new InvalidPathException(input, "Nul character not allowed");
            normalize |= ch == '/' && previous == '/';
            previous = ch;
        }

        bool absolute = input.length > 0 && input[0] == '/';
        if (!normalize)
            return new LexicalPath(input, absolute ? 1 : 0, absolute, '/');

        string path = "";
        foreach (ch; input)
            if (ch != '/' || path.length == 0 || path[$ - 1] != '/')
                path ~= ch;
        if (path.length > 1 && path[$ - 1] == '/')
            path = path[0 .. $ - 1];
        return new LexicalPath(path, absolute ? 1 : 0, absolute, '/');
    }

    private int compareUnixPaths(string first, string second) pure nothrow @nogc
    {
        auto length = first.length < second.length ? first.length : second.length;
        foreach (i; 0 .. length)
        {
            int difference = cast(ubyte) first[i] - cast(ubyte) second[i];
            if (difference)
                return difference;
        }
        return cast(int) first.length - cast(int) second.length;
    }

    private int unixPathHash(string path) pure nothrow @nogc
    {
        uint hash;
        foreach (ch; path)
            hash = 31 * hash + cast(ubyte) ch;
        return cast(int) hash;
    }
}

static if (includeWindowsPath)
{
    import flint.engine.aot.text : decodeUtf8;
    import flint.java.character : toUpperCase;

    // WindowsPath compares Java char units. Case folding must leave each surrogate unit separate.
    private struct WindowsPathUnits
    {
        string text;
        size_t offset;
        wchar pending = 0;

        bool empty() const pure nothrow @nogc
        {
            return offset == text.length && pending == 0;
        }

        wchar next() pure nothrow @nogc
        {
            if (pending)
            {
                wchar unit = pending;
                pending = 0;
                return unit;
            }

            auto codePoint = decodeUtf8(text, offset);
            if (codePoint <= 0xFFFF)
                return cast(wchar) codePoint;

            auto supplementary = codePoint - 0x10000;
            pending = cast(wchar)(0xDC00 + (supplementary & 0x3FF));
            return cast(wchar)(0xD800 + (supplementary >> 10));
        }

        int remainingLength() pure nothrow @nogc
        {
            int length;
            while (!empty())
            {
                next();
                ++length;
            }
            return length;
        }
    }

    private int compareWindowsPaths(string first, string second) pure nothrow @nogc
    {
        auto left = WindowsPathUnits(first);
        auto right = WindowsPathUnits(second);
        while (!left.empty() && !right.empty())
        {
            auto a = left.next();
            auto b = right.next();
            if (a != b)
            {
                auto difference = cast(int) cast(wchar) toUpperCase(a) - cast(wchar) toUpperCase(b);
                if (difference)
                    return difference;
            }
        }
        return left.remainingLength() - right.remainingLength();
    }

    private int windowsPathHash(string text) pure nothrow @nogc
    {
        auto units = WindowsPathUnits(text);
        uint hash;
        while (!units.empty())
            hash = 31 * hash + cast(wchar) toUpperCase(units.next());
        return cast(int) hash;
    }

    private enum WindowsKind
    {
        relative,
        absolute,
        unc,
        directoryRelative,
        driveRelative,
    }

    private Path windowsPath(string input)
    {
        auto expected = WindowsKind.relative;
        if (hasPrefix(input, "\\\\?\\UNC\\"))
        {
            expected = WindowsKind.unc;
            input = "\\\\" ~ input[8 .. $];
        }
        else if (hasPrefix(input, "\\\\?\\"))
        {
            expected = WindowsKind.absolute;
            input = input[4 .. $];
        }

        auto root = windowsRoot(input);
        if (expected != WindowsKind.relative && expected != root.kind)
        {
            auto reason = expected == WindowsKind.unc ? "Long UNC path prefix can only be used with a UNC path"
                : "Long path prefix can only be used with an absolute path";
            throw new InvalidPathException(input, reason);
        }

        auto path = normalizeWindowsNames(input, root.text, root.end);
        bool absolute = root.kind == WindowsKind.absolute || root.kind == WindowsKind.unc;
        return new LexicalPath(path, root.text.length, absolute, '\\');
    }

    private struct WindowsRoot
    {
        string text;
        size_t end;
        WindowsKind kind;
    }

    private WindowsRoot windowsRoot(string input)
    {
        if (input.length > 1)
        {
            if (isWindowsSeparator(input[0]) && isWindowsSeparator(input[1]))
                return uncRoot(input);
            if (isDriveLetter(input[0]) && input[1] == ':')
            {
                if (input.length > 2 && isWindowsSeparator(input[2]))
                    return WindowsRoot(input[0 .. 2] ~ '\\', 3, WindowsKind.absolute);
                return WindowsRoot(input[0 .. 2], 2, WindowsKind.driveRelative);
            }
        }
        if (input.length && isWindowsSeparator(input[0]))
            return WindowsRoot("\\", 0, WindowsKind.directoryRelative);
        return WindowsRoot("", 0, WindowsKind.relative);
    }

    private WindowsRoot uncRoot(string input)
    {
        auto host = skipWindowsSeparators(input, 2);
        auto hostEnd = windowsRootPartEnd(input, host);
        if (hostEnd == host)
            throw new InvalidPathException(input, "UNC path is missing hostname");

        auto share = skipWindowsSeparators(input, hostEnd);
        auto shareEnd = windowsRootPartEnd(input, share);
        if (shareEnd == share)
            throw new InvalidPathException(input, "UNC path is missing sharename");

        auto root = "\\\\" ~ input[host .. hostEnd] ~ "\\" ~ input[share .. shareEnd] ~ "\\";
        return WindowsRoot(root, shareEnd, WindowsKind.unc);
    }

    private string normalizeWindowsNames(string input, string root, size_t offset)
    {
        string path = root;
        offset = skipWindowsSeparators(input, offset);
        bool first = true;
        while (offset < input.length)
        {
            size_t start = offset;
            while (offset < input.length && !isWindowsSeparator(input[offset]))
            {
                auto ch = input[offset];
                if (invalidWindowsCharacter(ch))
                    throw windowsFailure(input, "Illegal char <" ~ ch ~ ">", offset);
                ++offset;
            }
            if (input[offset - 1] == ' ')
                throw windowsFailure(input, "Trailing char < >", offset - 1);
            if (!first)
                path ~= '\\';
            path ~= input[start .. offset];
            first = false;
            offset = skipWindowsSeparators(input, offset);
        }
        return path;
    }

    private size_t windowsRootPartEnd(string input, size_t offset)
    {
        while (offset < input.length && !isWindowsSeparator(input[offset]))
        {
            auto ch = input[offset];
            if (invalidWindowsCharacter(ch))
                throw windowsFailure(input, "Illegal character [" ~ ch ~ "] in path", offset);
            ++offset;
        }
        return offset;
    }

    private InvalidPathException windowsFailure(string input, string reason, size_t offset)
    {
        int index;
        foreach (dchar ch; input[0 .. offset])
            index += ch > 0xFFFF ? 2 : 1;
        return new InvalidPathException(input, reason, index);
    }

    private size_t skipWindowsSeparators(string input, size_t offset) pure nothrow @nogc
    {
        while (offset < input.length && isWindowsSeparator(input[offset]))
            ++offset;
        return offset;
    }

    private bool hasPrefix(string input, string prefix) pure nothrow @nogc
    {
        return input.length >= prefix.length && input[0 .. prefix.length] == prefix;
    }

    private bool isWindowsSeparator(char ch) pure nothrow @nogc
    {
        return ch == '\\' || ch == '/';
    }

    private bool isDriveLetter(char ch) pure nothrow @nogc
    {
        return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
    }

    private bool invalidWindowsCharacter(char ch) pure nothrow @nogc
    {
        if (ch < ' ')
            return true;
        switch (ch)
        {
        case '<', '>', ':', '"', '|', '?', '*':
            return true;
        default:
            return false;
        }
    }
}

private final class LexicalPath : Path
{
    mixin JavaObject;

    private const string text;
    private const size_t rootLength;
    private const bool absolute;
    private const char separator;

    this(string text, size_t rootLength, bool absolute, char separator)
    {
        this.text = text;
        this.rootLength = rootLength;
        this.absolute = absolute;
        this.separator = separator;
    }

    override bool isAbsolute() nothrow @nogc
    {
        return absolute;
    }

    override Path getRoot()
    {
        return rootLength ? new LexicalPath(text[0 .. rootLength], rootLength, absolute, separator) : null;
    }

    override Path getParent()
    {
        if (text.length == rootLength)
            return null;
        auto begin = lastNameStart();
        return begin == rootLength ? getRoot() : new LexicalPath(text[0 .. begin - 1], rootLength, absolute, separator);
    }

    override Path getFileName()
    {
        if (rootLength && text.length == rootLength)
            return null;
        return new LexicalPath(text[lastNameStart() .. $], 0, false, separator);
    }

    override int getNameCount() nothrow @nogc
    {
        if (rootLength && text.length == rootLength)
            return 0;

        int count = 1;
        foreach (ch; text[rootLength .. $])
            count += ch == separator;
        return count;
    }

    override Path getName(int index)
    {
        auto begin = nameStart(index);
        return new LexicalPath(text[begin .. nameEnd(begin)], 0, false, separator);
    }

    override Path subpath(int beginIndex, int endIndex)
    {
        if (beginIndex >= endIndex)
            throw new IllegalArgumentException;
        auto begin = nameStart(beginIndex);
        auto last = nameStart(endIndex - 1);
        return new LexicalPath(text[begin .. nameEnd(last)], 0, false, separator);
    }

    override int compareTo(Path other)
    {
        if (other is null)
            throwNullPathReference();
        auto peer = cast(LexicalPath) other;
        if (peer is null || separator != peer.separator)
            throw new ClassCastException;
        return compareSpelling(peer.text);
    }

    override bool equals(Object other)
    {
        auto peer = cast(LexicalPath) other;
        return peer !is null && separator == peer.separator && compareSpelling(peer.text) == 0;
    }

    override int hashCode() nothrow @nogc
    {
        static if (includeUnixPath && includeWindowsPath)
            return separator == '\\' ? windowsPathHash(text) : unixPathHash(text);
        else static if (includeWindowsPath)
            return windowsPathHash(text);
        else
            return unixPathHash(text);
    }

    override string toString()
    {
        return text;
    }

    private int compareSpelling(string other) const pure nothrow @nogc
    {
        static if (includeUnixPath && includeWindowsPath)
            return separator == '\\' ? compareWindowsPaths(text, other) : compareUnixPaths(text, other);
        else static if (includeWindowsPath)
            return compareWindowsPaths(text, other);
        else
            return compareUnixPaths(text, other);
    }

    private size_t lastNameStart() const pure nothrow @nogc
    {
        size_t offset = text.length;
        while (offset > rootLength && text[offset - 1] != separator)
            --offset;
        return offset;
    }

    private size_t nameStart(int index) const
    {
        if (index < 0 || (rootLength && text.length == rootLength))
            throw new IllegalArgumentException;
        size_t begin = rootLength;
        foreach (_; 0 .. index)
        {
            auto end = nameEnd(begin);
            if (end == text.length)
                throw new IllegalArgumentException;
            begin = end + 1;
        }
        return begin;
    }

    private size_t nameEnd(size_t begin) const pure nothrow @nogc
    {
        while (begin < text.length && text[begin] != separator)
            ++begin;
        return begin;
    }
}
