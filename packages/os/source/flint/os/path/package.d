/// Scoped filesystem status and access probes.
module flint.os.path;

import flint.arena : Error, Result, Status;

public import flint.os.path.types : FileAccess, PathFailure, PathInfo, PathKind, PathLinkMode;

@safe:

version (linux)
    version = NativePathQueries;
else version (OSX)
    version = NativePathQueries;

version (NativePathQueries) import flint.os.sys.file_path : queryFileStatus, queryFileAccess;

/// Read the current metadata for a borrowed, nonempty native path.
Result!PathInfo fileStatus(scope const(char)[] path, PathLinkMode links, out PathFailure failure) nothrow @nogc
{
    version (NativePathQueries)
        return queryFileStatus(path, links, failure);
    else
    {
        failure = PathFailure.unsupported;
        return Result!PathInfo(PathInfo.init, Error(Status.unsupported,
                "file status is unavailable on this platform"));
    }
}

/// Check existence or read access. Returns true on success and a typed failure otherwise.
Result!bool checkFileAccess(scope const(char)[] path, FileAccess mode, out PathFailure failure) nothrow @nogc
{
    version (NativePathQueries)
        return queryFileAccess(path, mode, failure);
    else
    {
        failure = PathFailure.unsupported;
        return Result!bool(false, Error(Status.unsupported, "file access is unavailable on this platform"));
    }
}
