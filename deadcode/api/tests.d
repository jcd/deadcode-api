module deadcode.api.tests;

import deadcode.api;

version (unittest)
{
    mixin registerCommands;
    import std.stdio;
    import deadcode.command.command : Command;

    void testFunctionCmd()
    {
    }

    class testClassCmd : Command
    {
        void run()
        {
        }
    }

    import std.typecons;
    alias TestApplication = WhiteHole!IApplication;
}

unittest
{
    import deadcode.api.commandautoregister;
    import deadcode.test;
    import poodinis;
    import std.algorithm : any;
    import std.format;

    auto context = new shared DependencyContainer();
    context.register!(IApplication,TestApplication)();
    
    auto cmds = initCommands(context);
    Assert(4, cmds.length, "Three commands are registered");        
    enum cmdNames = [ "test.functionCmd", "test.classCmd", "test.log", "test.coverage" ];
    foreach (cmdName; cmdNames)
        Assert(cmds.any!(a => a.command.name == cmdName), format("Command %s is registered", cmdName));        
    
    import std.stdio;
    printStats(stdout,  true);
}
