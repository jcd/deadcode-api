module deadcode.api.api;

// NOTE: Make sure to name interface method parameters or things will not compile.

public import deadcode.command : CommandParameter, CommandParameterDefinition, CommandParameterDefinitions, ICommand, ICommandManager, CompletionEntry;
public import deadcode.core.log : LogLevel, ILog;
public import deadcode.edit.buffer : TextBoundary;
public import deadcode.edit.bufferview : IBufferView, RegionQuery;
public import deadcode.math.region : Region;

enum deadcodeListenPort = 13456;

interface IExtension 
{ 
	void stop();
	@property string uuidString();
}

interface IExtensionRegistrar
{
	void registerLoadedExtension(string uuid, IExtension extension);
}

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

//class PromptQuery
//{
//    this(string q, string a, Promise!PromptResult p, bool delegate(string) _validationDlg, CompletionEntry[] delegate(string) _getCompletionsDlg)
//    {
//        question = q;
//        answer = a;
//        promise = p;
//        validationDlg = _validationDlg;
//        getCompletionsDlg = _getCompletionsDlg;
//    }
//
//    string question;
//    string answer;
//    Promise!PromptResult promise;
//    bool delegate(string) validationDlg;
//    CompletionEntry[] delegate(string) getCompletionsDlg;
//}

struct PromptResult
{
	string answer;
	bool success;
}

interface IApplication 
{
	void quit();
    void showErrorMessage(string msg);
    void showMessageDialog(string msg);
    bool showOkCancelDialog(string msg, string okButtonText);
    bool showYesNoCancelDialog(string msg, string yesButtonText, string noButtonText);
    // loadresource?
    // settings?
    @property IWindow[] windows();
    @property IWindow activeWindow();
    @property void activeWindow(IWindow win);
    @property string[] extensionPaths();
    void addExtensionsPath(string p);
    void removeExtensionPath(string p);
    @property string clipboard();
    @property void clipboard(string c);
    // scoreSelector(scope, selector) ?
    // void logCommands(flag);
    // void logInput(flags)
    // void logResultRegex(flag);
    @property string ver();
    @property string platform();
    @property string architecture();

	//void yield(IFuture f);
	//
	//FutureType.ResultType yield(FutureType)(FutureType f)
	//{
	//    f.yield;
	//    f.get();
	//}

	//void prompt(string question, string defaultAnswer = "",  ICallback!string completedDlg = null, ICallbackReturn!(bool, string) validationDlg = null, ICallbackReturn!(CompletionEntry[], string) getCompletionsDlg = null);

	void prompt(string question, string defaultAnswer = "",  void delegate(bool,string) completedDlg = null, bool delegate(string) validationDlg = null, CompletionEntry[] delegate(string) getCompletionsDlg = null);
	//{
	//    promptImpl(question, defaultAnswer, createCallback(completedDlg), createCallbackReturn(validationDlg), createCallbackReturn(getCompletionsDlg));
	//}
/*
	Future!PromptResult prompt(string question, string defaultAnswer = "", bool delegate(string) validationDlg = null, CompletionEntry[] delegate(string) getCompletionsDlg = null)
	{
		Promise!PromptResult result;
		prompt(question, defaultAnswer, (string r) { result.setValue(r); } , validationDlg, getCompletionsDlg);
		auto f = result.getFuture();
		return f;
	}

	PromptResult yieldPrompt(string question, string defaultAnswer = "", bool delegate(string) validationDlg = null, CompletionEntry[] delegate(string) getCompletionsDlg = null)
	{
		auto f = prompt(question, defaultAnswer, validationDlg, getCompletionsDlg);
		yield(f);
		return f.get();
	}
*/
    void logMessage(string area, LogLevel level, string msg);
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
	
    IBufferView newBufferView();
    IBufferView openFile(string path);

    // void addMenuItem(string commandName, MenuItem menuItem);
    // void addCommandShortcuts(string commandName, Shortcut[] shortcuts);
    void onFileDropped(string path);
    void startExtension(string path);

    void focusWindow();

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

enum OpenFileFlags
{
	none,
    encodedPosition, // search filename for ":row" or  ":row:col" suffix
    transient // Open as preview ie. don't open a tab for it
}

enum QuickPanelFlags
{
    monoSpaceFont,
    keepOpenOnFocusLost
}

struct Location
{
    string absolutePath;
    string projectRelativePath;
    int row;
    int column;
}

alias point = int;

interface IWindow
{
    void focus();
    
    IBufferView newBuffer();
    IBufferView newBufferHidden(); 
	IBufferView openFile(string path, OpenFileFlags flags = OpenFileFlags.none);
    IBufferView findOpenFile(string path);
    IBufferView findBufferView(string name);
    void close(IBufferView bv);

    @property IBufferView activeBufferView();
    @property void activeBufferView(IBufferView bv);
    IBufferView activeBufferViewInGroup(int groupID);
    @property IBufferView[] viewsInGroup(int groupID);
    @property int numGroups();
    @property int activeGroup();
    @property void activeGroup(int idx);
	//int getBufferViewIndex(IBufferView bv);
	//int setBufferViewIndex(IBufferView bv);
    @property string statusMessage();
    @property void statusMessage(string msg);
    @property bool isMenuVisible();
    @property void isMenuVisible(bool v);
    @property bool isSidebarVisible();
    @property void isSidebarVisible(bool v);
    @property bool isMinimapVisible();
    @property void isMinimapVisible(bool v);
    @property bool isStatusbarVisible();
    @property void isStatusbarVisible(bool v);
    @property string[] folders();
    @property string projectFileName();
    @property string projectData();
    @property void projectData(string v);
    void runCommand(string cmd);

	void prompt(string question, string defaultAnswer = "",  void delegate(bool,string) completedDlg = null, bool delegate(string) validationDlg = null, CompletionEntry[] delegate(string) getCompletionsDlg = null, bool constrainResultToCompletions = true);
	void prompt(string question, string[] answers, void delegate(bool,string) completedDlg = null,int defaultAnswerIndex = -1);

    void showQuickPanel(string[] items, string onDone, int selectedIndex, string onChanged);
    IBufferView showInputPanel(string caption, string initialText, string onDone, string onChange, string onCancel);
    IBufferView createOutputPanel(string name, bool unlisted);
    IBufferView findOutputPanel(string name);
    void destroyOutputPanel(string name);
    @property string activePanel();
    @property string[] panels();
    Location lookupSymbolInIndex(string symbol);
    Location lookupSymbolInOpenFiles(string symbol);
    string[] extractVariables();

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
