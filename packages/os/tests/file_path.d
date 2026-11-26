module flint.os.file_path_test;

import flint.arena : Status;
import flint.os.path : FileAccess, fileStatus, checkFileAccess, PathFailure, PathKind, PathLinkMode;

version (Posix)
{
    import core.sys.posix.stdlib : mkdtemp;
    import core.sys.posix.sys.stat : chmod, S_IRWXU;
    import core.sys.posix.unistd : getuid;
    import std.file : mkdir, rmdirRecurse, symlink, tempDir, write;
    import std.path : buildPath;
    import std.string : toStringz;

    private string temporaryRoot()
    {
        auto path = buildPath(tempDir(), "flint-os-path-XXXXXX").dup ~ '\0';
        assert(mkdtemp(path.ptr) !is null);
        return path[0 .. $ - 1].idup;
    }

    @("file status follows the final link only when requested")
    unittest
    {
        const root = temporaryRoot();
        scope (exit)
            rmdirRecurse(root);
        const file = buildPath(root, "file");
        const link = buildPath(root, "link");
        write(file, "abc");
        symlink("file", link);
        PathFailure failure;
        const target = fileStatus(link, PathLinkMode.follow, failure);
        assert(target.ok && failure == PathFailure.none);
        assert(target.value.kind == PathKind.regular && target.value.size == 3);
        assert(target.value.modifiedNanoseconds < 1_000_000_000);
        const direct = fileStatus(link, PathLinkMode.noFollow, failure);
        assert(direct.ok && failure == PathFailure.none);
        assert(direct.value.kind == PathKind.symbolicLink && direct.value.size == 4);
        const directory = fileStatus(root, PathLinkMode.follow, failure);
        assert(directory.ok && directory.value.kind == PathKind.directory);
    }

    version (linux)
    {
        @("file status preserves the 64-bit size and the full pre-epoch timestamp")
        unittest
        {
            import core.sys.posix.fcntl : AT_FDCWD;
            import core.sys.posix.sys.stat : utimensat;
            import core.sys.posix.time : timespec;
            import std.stdio : File;

            const root = temporaryRoot();
            scope (exit)
                rmdirRecurse(root);
            const file = buildPath(root, "sparse");
            enum size = 3_221_225_473L;
            {
                auto sparse = File(file, "wb");
                sparse.seek(size - 1);
                immutable ubyte[1] content = [1];
                sparse.rawWrite(content[]);
            }
            const nativePath = file.toStringz;
            const timespec stamp = timespec(-1, 999_999_999);
            const timespec[2] times = [stamp, stamp];
            assert(utimensat(AT_FDCWD, nativePath, times, 0) == 0);

            PathFailure failure;
            const result = fileStatus(file, PathLinkMode.follow, failure);
            assert(result.ok && failure == PathFailure.none);
            assert(result.value.size == size);
            assert(result.value.modifiedSeconds == -1 && result.value.modifiedNanoseconds == 999_999_999);
        }
    }

    @("metadata and access distinguish missing paths from indeterminate paths")
    unittest
    {
        const root = temporaryRoot();
        scope (exit)
            rmdirRecurse(root);
        const file = buildPath(root, "file");
        const dangling = buildPath(root, "dangling");
        const cycle = buildPath(root, "cycle");
        write(file, "abc");
        symlink("missing", dangling);
        symlink("cycle", cycle);
        PathFailure failure;
        assert(fileStatus(dangling, PathLinkMode.follow, failure).error.code == Status.notFound);
        assert(failure == PathFailure.notFound);
        const direct = fileStatus(dangling, PathLinkMode.noFollow, failure);
        assert(direct.ok && failure == PathFailure.none && direct.value.kind == PathKind.symbolicLink);
        assert(!fileStatus(cycle, PathLinkMode.follow, failure).ok && failure == PathFailure.loop);
        const child = buildPath(file, "child");
        assert(fileStatus(child, PathLinkMode.follow, failure).error.code == Status.ioError);
        assert(failure == PathFailure.notDirectory);
        assert(!checkFileAccess(child, FileAccess.exists, failure).ok && failure == PathFailure.notDirectory);
        assert(!checkFileAccess(dangling, FileAccess.read, failure).ok && failure == PathFailure.notFound);
        assert(!checkFileAccess(cycle, FileAccess.exists, failure).ok && failure == PathFailure.loop);
        const readable = checkFileAccess(file, FileAccess.read, failure);
        assert(readable.ok && readable.value && failure == PathFailure.none);
    }

    @("path validation rejects embedded NUL and paths exceeding the native buffer")
    unittest
    {
        PathFailure failure;
        assert(fileStatus("file\0rest", PathLinkMode.follow, failure).error.code == Status.invalidArgument);
        assert(failure == PathFailure.invalid);
        auto tooLong = new char[8192];
        tooLong[] = 'a';
        assert(!fileStatus(tooLong, PathLinkMode.follow, failure).ok && failure == PathFailure.nameTooLong);
        assert(!checkFileAccess("", FileAccess.read, failure).ok && failure == PathFailure.invalid);
        assert(!checkFileAccess("file\0rest", FileAccess.exists, failure).ok && failure == PathFailure.invalid);
        assert(!checkFileAccess(tooLong, FileAccess.exists, failure).ok && failure == PathFailure.nameTooLong);
    }

    @("read permission and path existence are independent")
    unittest
    {
        if (getuid() == 0)
            return;
        const root = temporaryRoot();
        scope (exit)
            rmdirRecurse(root);
        const file = buildPath(root, "file");
        const directory = buildPath(root, "directory");
        const child = buildPath(directory, "child");
        mkdir(directory);
        write(child, "");
        write(file, "abc");
        assert(chmod(file.toStringz, 0) == 0);
        assert(chmod(directory.toStringz, 0) == 0);
        scope (exit)
            assert(chmod(directory.toStringz, S_IRWXU) == 0);
        PathFailure failure;
        assert(fileStatus(file, PathLinkMode.follow, failure).ok && failure == PathFailure.none);
        assert(checkFileAccess(file, FileAccess.exists, failure).ok && failure == PathFailure.none);
        assert(checkFileAccess(file, FileAccess.read, failure).error.code == Status.permissionDenied);
        assert(failure == PathFailure.accessDenied);
        assert(fileStatus(child, PathLinkMode.follow, failure).error.code == Status.permissionDenied);
        assert(failure == PathFailure.accessDenied);
    }
}
else
{
    @("file metadata reports an explicit unsupported result")
    unittest
    {
        PathFailure failure;
        assert(fileStatus("file", PathLinkMode.follow, failure).error.code == Status.unsupported);
        assert(failure == PathFailure.unsupported);
        assert(checkFileAccess("file", FileAccess.exists, failure).error.code == Status.unsupported);
        assert(failure == PathFailure.unsupported);
    }
}
