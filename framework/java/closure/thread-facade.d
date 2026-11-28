module app;

import flint.java.lang.thread : Thread;

@safe:

int main(string[] args)
{
    auto self = Thread.currentThread();
    if (self !is Thread.currentThread())
        return 1;
    self.interrupt();
    if (!self.isInterrupted())
        return 2;
    if (!Thread.interrupted())
        return 3;
    if (args.length > 1)
        self.setName(args[1]);
    return self.getName().length != 0 ? 0 : 4;
}
