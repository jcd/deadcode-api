module deadcode.api.rpcclient;

import deadcode.api : IApplication, CommandParameter, deadcodeListenPort;
import deadcode.core.command : CommandManager;
import poodinis : DependencyContainer, existingInstance;

/**
    Mixin this template get a default main() function that will result in an 
    executable taking optional <host> <port> as arguments which should point to a
    deadcode editor running instance. If arguments are not provided then localhost
    and default port is used.

    The main function will scan and register all commands found in the executable
    and make them available out-of-processs to the deadcode editor.

    Example:
    ---
import deadcode.api;
mixin rpcClient;
mixin registerCommands;
string myCommand(string a) { return "Got " ~ a; }
    ---

    Example:
    ---
// set compiler version flag DeadcodeOutOfProcess
import deadcode.api;
mixin registerCommands;
string myCommand(string a) { return "Got " ~ a; }
    ---
}
*/
template rpcClient()
{
    int main(string[] args)
    {
        return _dummy.runRpcClient(args);
    }
}

class _dummy
{
    static int runRpcClient(string[] args, void function(shared DependencyContainer) initializeFunction = null)
    {
        import std.conv;
        import std.stdio;
        import deadcode.core.command;
        import deadcode.rpc;

        registerCommandParameterMsgPackHandlers();

        string ip = "127.0.0.1";
        ushort port = deadcodeListenPort;
        
        if (args.length > 1)
            ip = args[1];
        
        if (args.length > 2)
            port = args[2].to!ushort;

        auto loop = new RPCLoop;
        auto context = new shared DependencyContainer();

        loop.onConnected.connectTo( (RPC rpc, bool incoming) {
            
            writeln("Connected");

            import deadcode.api.commandautoregister : initCommands, finiCommands;
            import deadcode.core.log;

            auto app = rpc.createReference!IApplication();
            auto remoteLog = cast(RPCProxy!ILog)app.log;
            auto commandManager = cast(RPCProxy!ICommandManager)app.commandManager;

            context.register!(IApplication, typeof(app)).existingInstance(app);
            context.register!(ILog, typeof(remoteLog)).existingInstance(remoteLog);
            context.register!(ICommandManager, typeof(commandManager)).existingInstance(commandManager);
            context.register!RPC.existingInstance(rpc);
            
            auto cmds = initCommands(context);

            int nextCommandID = 100;

            foreach (idx, c; cmds)
            {
                if (c.initException !is null)
                {
                    remoteLog.error(c.initException.toString());
                }
                else if (c.command is null)
                {
                    remoteLog.error("Couldn't instantiate command %s",c.typeInfo.toString());
                }
                else
                {
                    remoteLog.verbose("Register command in deadcode %s", c.command.name);
                    app.addCommand(c.command);
                    //auto service = rpc.publish!(ICommand)(c.command, c.command.name);
                    //commandManager.add(service);
                }

                // c.initialize();

                //auto paramDefs = c.getCommandParameterDefinitions().asArray();
                //loop.registrar.addRemoteCommand(c.name, paramDefs);
                //writeln("Done");
                //app.addMenuItem(c.name, c.menuItem);
                //app.addCommandShortcuts(c.name, c.shortcuts);
            }

            if (initializeFunction !is null)
                initializeFunction(context);

            // rpc.kill();

            finiCommands(cmds);
        });
        
        writeln("Connecting to " ~ ip ~ ":" ~ port.to!string);

        import std.socket;
        try
            loop.connect(ip, port);
        catch (SocketOSException e)
        {
            writeln("Error connecting to editor:");
            writeln(e);
            return 2;
        }

        
        while (loop.select() != 0) {}

        return 0;
    }
}

version (unittest)
{
    import deadcode.api;
    import deadcode.core.log;
    mixin registerCommands;
    void testLogCommand(ILog log, string a) { import std.stdio; writeln("client: local test.logCommand('" ~ a ~ "')"); }
}

///
unittest
{
    import std.concurrency;
    import std.stdio;

    enum testPort = 17654;

    enum userDataDir = "The user data dir from server";

    static class TestApplication : IApplication
    {
        ILog _log;
        ICommandManager _commandManager;

        void logMessage(LogLevel level, string message) { assert(0); }
        void setLogFile(string path)  { assert(0); }
        void bufferViewParamTest(IBufferView b) { assert(0); }
        void addCommand(ICommand c) { _commandManager.add(c); }
        string[] findCommands(string pattern) { assert(0); }
        void runCommand(string commanName) { assert(0); }
        void scheduleCommand(string commanName) { assert(0); }
        // void addMenuItem(string commandName, MenuItem menuItem);
        // void addCommandShortcuts(string commandName, Shortcut[] shortcuts);
        void onFileDropped(string path) { assert(0); }
        void quit() { assert(0); }
        string hello(string yourName) { assert(0); }

        void startExtension(string path) { assert(0); }
        void scheduleCommand(string commandName, string arg1) { assert(0); }
       
        void buildExtension(string name) { assert(0); }
        void loadExtension(string name) { assert(0); }
        void unloadExtension(string name) { assert(0); }
        void scanExtensions(bool onlyChanged = true) { assert(0); }

        @property ICommandManager commandManager() { return _commandManager; }
        @property ILog log() { return _log; }
        @property ITextEditor currentTextEditor() { assert(0); }
        @property void currentTextEditor(ITextEditor) { assert(0); }
        @property IBufferView previousBuffer() { assert(0); }
        @property IBufferView currentBuffer() { assert(0); }
        @property void currentBuffer(IBufferView) { assert(0); }
        @property string userDataDir() { return userDataDir; }
        @property string executableDir() { assert(0); }
    }

    static class TestLog : ILog
    {
        void log(LogLevel level, string message)
        {
            writeln("server: ", level, " ", message);
        }
    }

    static void runServer()
    {
        import deadcode.core.command;
        import deadcode.rpc;
        auto server = new RPCLoop;
        server.listen(testPort);
        
        CommandManager commandManager = new CommandManager();
        registerCommandParameterMsgPackHandlers();
        static class MockCommandManager : ICommandManager
        {    
            ICommand lookup(string commandName)
            {
                assert(0);
            }
            
            void add(ICommand command)
            {
                writefln("MockCommandManager: add %s", command.name);
            }

            void execute(string commandName, CommandParameter[] params)
            {
                writefln("MockCommandManager: execute %s %s", commandName, params.length);
            }
        }

        server.onConnected.connectTo( (RPC rpc, bool incoming) {
            writeln("server: rpcClient connected");
            auto app = new TestApplication();
            app._log = new TestLog();
            app._commandManager = commandManager;
            rpc.publish(app);
            server.stopListening();
        });

        while (server.select() != 0) {}

        writeln("server: end.");
    }
    spawn(&runServer);

    static void initializeTestClient(shared DependencyContainer context)
    {
        auto log = context.resolve!ILog;
        log.info("Hello from client");

        //auto app = context.resolve!IApplication;
        //writefln("client: server.app.getUserDataDir() == '%s'", app.getUserDataDir());

        auto commandManager = context.resolve!ICommandManager;
        commandManager.execute("test.log", [ CommandParameter("foo") ]);

        log.info("Hello again from client");
    
        import deadcode.rpc;
        auto rpc = context.resolve!RPC;
        rpc.kill();
    }

    import std.conv;
    _dummy.runRpcClient([ "app", "localhost", testPort.to!string ] , &initializeTestClient);
    writeln("client: end.");
}
