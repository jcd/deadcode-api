module deadcode.api.tests;

import deadcode.api;

version (unittest)
{
    mixin registerCommands;
    import std.stdio;
    import deadcode.command.command : Command;

    void testFunctionCmd()
    {
        writeln("Hello from ", __FUNCTION__);
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
    Assert(3, cmds.length, "Three commands are registered");        
    enum cmdNames = [ "test.functionCmd", "test.classCmd", "test.log" ];
    foreach (cmdName; cmdNames)
        Assert(cmds.any!(a => a.command.name == cmdName), format("Command %s is registered", cmdName));        
    
    import std.stdio;
    printStats(stdout,  true);
}
