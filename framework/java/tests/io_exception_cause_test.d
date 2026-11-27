// SPDX-License-Identifier: GPL-2.0-only WITH Classpath-exception-2.0
/** Java's cause lifecycle for the checked IOException family: the (String) constructors leave it open. */
module flint.java.io_exception_cause_test;

import flint.java.io : FileNotFoundException, IOException;
import flint.java.lang : IllegalArgumentException, IllegalStateException, javaToString;

@safe:

private bool rejectsCause(IOException failure)
{
    try
        failure.initCause(new Exception("other"));
    catch (IllegalStateException)
        return true;
    return false;
}

@("IOException() and IOException(String) leave the cause open for one initCause")
unittest
{
    auto cause = new IOException("root");
    foreach (failure; [new IOException, new IOException("open"), new FileNotFoundException("missing")])
    {
        assert(failure.getCause() is null);
        assert(failure.initCause(cause) is failure && failure.getCause() is cause);
        assert(rejectsCause(failure));
    }
    auto closedByNull = new IOException("open");
    assert(closedByNull.initCause(null) is closedByNull && closedByNull.getCause() is null);
    assert(rejectsCause(closedByNull));
}

@("IOException(String, Throwable) and IOException(Throwable) initialize the cause, even to null")
unittest
{
    auto cause = new IOException("root");
    const withCause = new IOException("outer", cause);
    assert(withCause.getMessage() == "outer" && withCause.getCause() is cause);
    assert(rejectsCause(new IOException("outer", cause)));
    // A null literal selects the (String, Throwable) constructor, as in Java.
    auto explicitNull = new IOException("outer", null);
    assert(explicitNull.getMessage() == "outer" && explicitNull.getCause() is null);
    assert(rejectsCause(explicitNull));

    auto wrapped = new IOException(cast(Throwable) cause);
    assert(wrapped.getMessage() == javaToString(cause) && wrapped.getCause() is cause);
    assert(rejectsCause(wrapped));
    auto nullCause = new IOException(cast(Throwable) null);
    assert(nullCause.getMessage() is null && nullCause.getCause() is null);
    assert(rejectsCause(nullCause));
}

@("IOException.initCause rejects self-causation and names the rejected cause")
unittest
{
    auto failure = new IOException("open");
    bool selfRejected;
    try
        failure.initCause(failure);
    catch (IllegalArgumentException e)
        selfRejected = e.getMessage() == "Self-causation not permitted" && e.getCause() is failure;
    assert(selfRejected && failure.getCause() is null);

    auto closed = new IOException("closed", null);
    string message;
    Throwable reported;
    try
        closed.initCause(null);
    catch (IllegalStateException e)
    {
        message = e.getMessage();
        reported = e.getCause();
    }
    // As in Java, the rejection names the exception whose cause was already initialized.
    assert(message == "Can't overwrite cause with a null" && reported is closed);
}
