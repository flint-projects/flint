module flint.os.path.types;

@safe:

/// Whether to resolve the final symbolic link during a metadata query.
enum PathLinkMode : ubyte
{
    follow,
    noFollow,
}

/// Access to check using the platform's process identity.
enum FileAccess : ubyte
{
    exists,
    read,
}

/// Type of filesystem entry returned by a metadata query.
enum PathKind : ubyte
{
    other,
    regular,
    directory,
    symbolicLink,
}

/// The status of one native filesystem entry.
struct PathInfo
{
    /// Entry type.
    PathKind kind;
    /// Raw native size, including for directory entries.
    long size;
    /// Signed seconds since the Unix epoch.
    long modifiedSeconds;
    /// Fractional nanoseconds in [0, 1_000_000_000).
    uint modifiedNanoseconds;
}

/// A reason for a failed query. Only notFound confirms absence.
enum PathFailure : ubyte
{
    none,
    notFound,
    /// A path component is not a directory; this is an indeterminate I/O failure, not absence.
    notDirectory,
    accessDenied,
    loop,
    nameTooLong,
    invalid,
    ioError,
    unsupported,
}
