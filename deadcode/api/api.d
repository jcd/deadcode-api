module deadcode.api.api;

// NOTE: Make sure to name interface method parameters or things will not compile.

public import deadcode.core.commandparameter : CommandParameter, CommandParameterDefinition, CommandParameterDefinitions;
public import deadcode.core.command : ICommand, ICommandManager;
public import deadcode.core.log : LogLevel, ILog;

enum deadcodeListenPort = 12345;

/** Attribute to specify a shortcut for for a Command or command function

    In a module that has a  "mixin registerCommands":
    A class derived from class Command or a public function use the @Shortcut attribute to 
    set the default shortcut for the command.

    Example:
    @Shortcut("<ctrl> + h")                 // Shortcut that will prompt for missing command argument
    @Shortcut("<ctrl> + m", "Hello world")  // Shortcut that with the command argument set in advance
    class SayHelloCommand : Command
    {
        this() { super(createParams("")); }

        void run(Log log, string txt)
        {
            log.info(txt);
        }
    }

    Example:
    @Shortcut("<ctrl> + u")
    void textUppercase(Application app, string dummy)
    {
        app.currentBuffer.map!(std.uni.toUpper)(RegionQuery.selectionOrWord);
    }
*/
struct Shortcut
{
    string keySequence;
    string argument;
}

struct CommandShortcuts
{
    string commandName;
    Shortcut[] shortcuts;
}

/** Attribute to specify a menut item for for a Command or command function

    In a module that has a  "mixin registerCommands":
    A class derived from class Command or a public function use the @MenuItem attribute to 
    set the default menu item for the command.

    Example:
    @MenuItem("Tools/Log text")              
    class SayHelloCommand : Command
    {
        this() { super(createParams("")); }

        void run(Log log, string txt)
        {
            log.info(txt);
        }
    }

    Example:
    @MenuItem("Tools/Log text")
    void textUppercase(Application app, string dummy)
    {
        app.currentBuffer.map!(std.uni.toUpper)(RegionQuery.selectionOrWord);
    }
*/
struct MenuItem
{
    string path;
    string argument;
}

struct CommandMenuItem
{
    string commandName;
    MenuItem menuItem;
}

interface IBufferView 
{
    string name();
    void beginUndoGroup();
    void endUndoGroup();
}

interface IApplication 
{
    void logMessage(LogLevel level, string msg);
    void setLogFile(string path);
    void bufferViewParamTest(IBufferView b);
    void addCommand(ICommand c);
    string[] findCommands(string pattern);
    void runCommand(string commandName);
    void scheduleCommand(string commandName);

    void buildExtension(string name);
    void loadExtension(string name);
    void unloadExtension(string name);
    void scanExtensions(bool onlyChanged = true);

    // IBufferView newBuffer();

    // void addMenuItem(string commandName, MenuItem menuItem);
    // void addCommandShortcuts(string commandName, Shortcut[] shortcuts);
    void onFileDropped(string path);
    void quit();
    void startExtension(string path);

    @property ICommandManager commandManager();
    @property ILog log();
    @property ITextEditor currentTextEditor();
    // @property void currentTextEditor(ITextEditor e);
    @property IBufferView previousBuffer();
    @property IBufferView currentBuffer();
    @property void currentBuffer(IBufferView b);
    @property string userDataDir();
    @property string executableDir();
}

interface IDirectoryChangeListener
{
    void handleChange(string[] filesAdded, string[] filesRemoved, string[] filesModified);
}

interface IRemoteCommandRegistrar 
{
    void addRemoteCommand(string name, CommandParameterDefinition[] paramDefs);
}

interface ITextEditor 
{
    void value(string txt);
}
