module flint.os.sys.file_path;

@safe:

version (linux)
    version = NativePathQueries;
else version (OSX)
    version = NativePathQueries;

version (NativePathQueries)
{
    import core.stdc.errno : EACCES, EINVAL, ELOOP, ENAMETOOLONG, ENOENT, ENOTDIR, errno;
    import core.sys.posix.sys.stat : S_IFDIR, S_IFLNK, S_IFMT, S_IFREG, lstat, stat, stat_t;
    import core.sys.posix.unistd : F_OK, R_OK, access;
    import flint.arena : Error, Result, Status;
    import flint.os.path.types : FileAccess, PathFailure, PathInfo, PathKind, PathLinkMode;

    // PATH_MAX counts the terminator on both supported POSIX targets.
    version (OSX)
        private enum nativePathCapacity = 1024;
    else
        private enum nativePathCapacity = 4096;

    private alias NativePath = char[nativePathCapacity];

package(flint.os):

    Result!PathInfo queryFileStatus(scope const(char)[] path, PathLinkMode links, out PathFailure failure) nothrow @nogc
    {
        NativePath nativePath = void;
        const validation = preparePath(path, nativePath, failure);
        if (validation.code != Status.ok)
            return Result!PathInfo(PathInfo.init, validation);
        stat_t attributes;
        const code = readStatus(nativePath[0 .. path.length + 1], links, attributes);
        if (code != 0)
            return Result!PathInfo(PathInfo.init, pathError(code, failure));

        version (OSX)
            const modified = attributes.st_mtimespec;
        else
            const modified = attributes.st_mtim;
        return Result!PathInfo(PathInfo(fileKind(attributes.st_mode & S_IFMT), attributes.st_size,
                modified.tv_sec, cast(uint) modified.tv_nsec));
    }

    Result!bool queryFileAccess(scope const(char)[] path, FileAccess mode, out PathFailure failure) nothrow @nogc
    {
        NativePath nativePath = void;
        const validation = preparePath(path, nativePath, failure);
        if (validation.code != Status.ok)
            return Result!bool(false, validation);
        const code = readAccess(nativePath[0 .. path.length + 1], mode);
        if (code != 0)
            return Result!bool(false, pathError(code, failure));
        return Result!bool(true);
    }

    private Error preparePath(scope const(char)[] path, scope char[] buffer, out PathFailure failure) nothrow @nogc
    {
        if (path.length >= buffer.length)
            return pathError(ENAMETOOLONG, failure);
        if (path.length == 0)
            return pathError(EINVAL, failure);
        foreach (byteValue; path)
            if (byteValue == '\0')
                return pathError(EINVAL, failure);
        buffer[0 .. path.length] = path;
        buffer[path.length] = '\0';
        return Error.init;
    }

    private PathKind fileKind(int mode) pure nothrow @nogc
    {
        switch (mode)
        {
        case S_IFREG:
            return PathKind.regular;
        case S_IFDIR:
            return PathKind.directory;
        case S_IFLNK:
            return PathKind.symbolicLink;
        default:
            return PathKind.other;
        }
    }

    private Error pathError(int code, out PathFailure failure) pure nothrow @nogc
    {
        switch (code)
        {
        case ENOENT:
            failure = PathFailure.notFound;
            return Error(Status.notFound, "file path does not exist");
        case ENOTDIR:
            failure = PathFailure.notDirectory;
            return Error(Status.ioError, "file path descends through a non-directory");
        case EACCES:
            failure = PathFailure.accessDenied;
            return Error(Status.permissionDenied, "file path access denied");
        case ELOOP:
            failure = PathFailure.loop;
            return Error(Status.ioError, "file path exceeds the symbolic-link resolution limit");
        case ENAMETOOLONG:
            failure = PathFailure.nameTooLong;
            return Error(Status.invalidArgument, "file path is too long");
        case EINVAL:
            failure = PathFailure.invalid;
            return Error(Status.invalidArgument, "invalid file path");
        default:
            failure = PathFailure.ioError;
            return Error(Status.ioError, "file path query failed");
        }
    }

    // SAFETY: The checked slice must end in NUL. Neither call retains it, and the output is a live stat_t.
    private int readStatus(scope const(char)[] path, PathLinkMode links, out stat_t attributes) @trusted nothrow @nogc
    {
        if (path.length == 0 || path[$ - 1] != '\0')
            return EINVAL;
        const code = links == PathLinkMode.follow ? stat(path.ptr, &attributes) : lstat(path.ptr, &attributes);
        return code == 0 ? 0 : errno;
    }

    // SAFETY: The checked slice must end in NUL. access reads it synchronously without retaining it.
    private int readAccess(scope const(char)[] path, FileAccess mode) @trusted nothrow @nogc
    {
        if (path.length == 0 || path[$ - 1] != '\0')
            return EINVAL;
        const code = access(path.ptr, mode == FileAccess.read ? R_OK : F_OK);
        return code == 0 ? 0 : errno;
    }

    version (unittest)
    {
        @("native path wrappers reject slices without a NUL terminator")
        unittest
        {
            stat_t attributes;
            assert(readStatus("", PathLinkMode.follow, attributes) == EINVAL);
            assert(readAccess("", FileAccess.exists) == EINVAL);
            immutable char[1] unterminated = ['x'];
            assert(readStatus(unterminated[], PathLinkMode.follow, attributes) == EINVAL);
            assert(readAccess(unterminated[], FileAccess.exists) == EINVAL);
        }
    }
}
