/** Java SE's checked exception for an unsupported encoding name. */
module flint.java.io.unsupportedencodingexception;

import flint.java.io : IOException;

@safe:

class UnsupportedEncodingException : IOException
{
    this(string message = null, string file = __FILE__, size_t line = __LINE__) pure nothrow
    {
        super(message, file, line);
    }
}
