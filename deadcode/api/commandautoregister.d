module deadcode.api.commandautoregister;

import core.thread;

import deadcode.core.attr : hasAttribute, getAttributes, isType, isNotType;
import deadcode.api.api : IApplication, IBufferView, ITextEditor, IWindow, MenuItem, Shortcut;
import deadcode.command.command : ICommand, Command, CommandManager, CompletionEntry, Hints;
import deadcode.command.commandparameter : createParams, CommandCall, CommandParameter;
import deadcode.core.log;

import std.meta : AliasSeq, anySatisfy, Filter, Replace, staticIndexOf, staticMap;
import std.traits : FieldNameTuple, isSomeFunction, Identity, ParameterDefaults, ParameterIdentifierTuple, ParameterTypeTuple;

import poodinis;

/** Attribute to specify a that a command should be run in a fiber

In a module that has a  "mixin registerCommands":
A class derived from class Command or a public function use the @InFiber attribute to force
the command to be run in a fiber.

Another way to force running in a fiber is by setting one of the first parameters of the 
command to be of type Fiber. This will run the command in a fiber at pass the fiber as
argument.

Example:
@InFiber
class SayHelloCommand : Command
{
	this() { super(createParams("")); }

	void run(Log log, string txt)
	{
		log.info(txt);
	}
}

Example:
@InFiber
void textUppercase(Application app, string dummy)
{
	app.currentBuffer.map!(std.uni.toUpper)(RegionQuery.selectionOrWord);
}

Example:
void textUppercase(Fiber fiber, Application app, string dummy)
{
	// The fiber parameter is automatically provided to the function 
	// and the command is run in that fiber.
	app.currentBuffer.map!(std.uni.toUpper)(RegionQuery.selectionOrWord);
}
*/
struct InFiber
{
}

/** Attribute to Register a free function as a Command

This will create a new FunctionCommand!Func that wraps the function. The Command.execute will
inspect the function parameter types and extract values of those types at runtime from the
Command.execute arguments. Then it will call the free function with the arguments.

In case the free function needs context information such as active BufferView instance or Application instance
it can get that by setting the first parameter to the type of context it needs. Supported contexts are:

* BufferView  = the active buffer view currently having keyboard focus or null
* Application = the application instance
* Widget      = the widget that currently has focus
* Context     = A struct with all of the above.
*/
struct RegisterFunctionCommand(alias Func)
{
	alias Function = Func;
	alias FC = ExtensionCommandWrap!(Func, Command);
}

struct RegisterClassCommand(alias Cls)
{
	alias FC = ExtensionCommandWrap!(Cls, Cls);
}

interface Autowireable
{
	@property
	{
		void context(shared(DependencyContainer) context);
		shared(DependencyContainer) context();
	}
	void performAutowire();
}

// Wrapper for a function or a class derived from Command where it will
// automatically inject needed values to either the function or a .run method on the class instance
// when executed through e.g. the command manager.
class ExtensionCommandWrap(alias AttributeHolder, Base) : Base, Autowireable
{
	private shared(DependencyContainer) _context;

	alias InjectedTypes = AliasSeq!(IApplication, IWindow, ITextEditor, IBufferView, Fiber, ILog);
	alias InjectedObjects = AliasSeq!(resolveApplication, currentWindow, currentTextEditor, currentBuffer, Fiber.getThis, resolveLog);

	static if ( isSomeFunction!AttributeHolder )
		alias Func = AttributeHolder;
	else
		alias Func = run;
	
	static if (hasAttribute!(AttributeHolder, InFiber) || anySatisfy!(isType!Fiber, ParameterTypeTuple!Func))
		override bool mustRunInFiber() const pure nothrow @safe
		{
			return true;
		}

	private ILog resolveLog()
	{
		return resolveApplication().log;
	}

	private IApplication resolveApplication()
	{
		return _context.resolve!IApplication;
	}

	static this()
	{

		WrappedCommandInfo info;

		static if (hasAttribute!(AttributeHolder,MenuItem))
			info.menuItem = getAttributes!(AttributeHolder, MenuItem)[0];

		static if (hasAttribute!(AttributeHolder, Shortcut))
			info.shortcuts = getAttributes!(AttributeHolder, Shortcut);

		static if (hasAttribute!(AttributeHolder, Hints))
			info.hints = getAttributes!(AttributeHolder, Hints)[0];
		
		alias ThisType = ExtensionCommandWrap!(AttributeHolder, Base);
		info.typeInfo = typeid(ThisType);
		
		g_WrappedCommands ~= info;
	}

	@property 
	{
		void context(shared(DependencyContainer) context)
		{
			_context = context;
		}
		shared(DependencyContainer) context()
		{
			return _context;
		}
	}

	void performAutowire()
	{
		alias WrappedType = ExtensionCommandWrap!(AttributeHolder, Base);
		if (context is null)
			throw new Exception("Cannot autowire command when context is null");
		autowire!WrappedType(context, this);
	}

	this()
	{
        alias isInjectedType = isType!InjectedTypes;
		template getDefaultValues(alias F)
        {   
            alias Types = ParameterTypeTuple!F;
            alias DefaultValues = ParameterDefaults!F;
            template Each(int Idx)
            {
                static if (Types.length == Idx)
                    alias Each = AliasSeq!();
                else static if (isInjectedType!(Types[Idx]))
                    alias Each = Each!(Idx+1);
                else static if (is (DefaultValues[Idx] == void))
                    alias Each = AliasSeq!(Types[Idx].init, Each!(Idx+1));
                else 
                    alias Each = AliasSeq!(DefaultValues[Idx], Each!(Idx+1));
            }
            
            alias getDefaultValues = Each!0;
        }
		
        //alias p1 = Filter!(isNotType!InjectedTypes, ParameterTypeTuple!Func);
        //alias p2 = staticMap!(getDefaultValue!Func, p1);
        alias p2 = getDefaultValues!Func;

		enum names = [ParameterIdentifierTuple!Func];
		setCommandParameterDefinitions(createParams(names[$-p2.length..$], p2));
	}
	
	private IBufferView currentBuffer() { return resolveApplication().currentBuffer; }
	private ITextEditor currentTextEditor() { return resolveApplication().currentTextEditor; }
	private IWindow currentWindow() { return resolveApplication().activeWindow; }

	private auto call(alias F)(CommandParameter[] v)
	{
		enum count = Filter!(isType!InjectedTypes, ParameterTypeTuple!F).length;
		enum nonInjectedArgsCount = ParameterTypeTuple!F.length - count;
		
		template _replaceWithObject(T)
		{
			enum idx = staticIndexOf!(T, InjectedTypes);
			static if (idx == -1)
			{
				alias _replaceWithObject =  T; // Just put something there. It will not be used.
			}
			else
			{
				alias _replaceWithObject =  InjectedObjects[idx];
			}
		}

		alias t5 = staticMap!(_replaceWithObject, ParameterTypeTuple!F);
		alias injectedArgs = t5[0..count];

        // Save current active buffer since current buffer may be changed by the command
        static if ( anySatisfy!(isType!(IBufferView, ITextEditor), ParameterTypeTuple!F) )
        {
            auto bv = currentBuffer();
            bv.beginUndoGroup();
            scope (exit) bv.endUndoGroup();
        }

		alias parameterType(int idx) = ParameterTypeTuple!F[$-nonInjectedArgsCount+idx];

		static string _setupArgs(int count)
		{
			import std.conv;
			string res;
			string delim = ",";
			foreach (i; 0..count)
			{
				res ~= delim ~ "v[" ~ i.to!string ~ "].get!(parameterType!" ~ i.to!string ~ ")";
				delim = ",";
			}
			return res;
		}

		assert(v.length >= nonInjectedArgsCount);

		// Mixin magic to simply provide injected args and use v[0].get!parameterType!0 etc. for the rest or the args
		mixin("return F(injectedArgs" ~ _setupArgs(nonInjectedArgsCount) ~ ");");
	}

	override void execute(CommandParameter[] v)
	{
		call!Func(v);
	}

	static if (__traits(hasMember, Base, "complete") && isSomeFunction!(Base.complete))
	{
		override CompletionEntry[] getCompletions(CommandParameter[] v)
		{
			return call!complete(v);
		}
	}
}

/*
void registerCommandKeyBindings(CommandManager commandManager, IApplication app)
{
	Command[] commands = commandManager.commands.values;
	foreach (c; commands)
	{
		TypeInfo ti = typeid(c);
		TypeInfo_Class tic = cast(TypeInfo_Class) ti;
		string name = tic.name;
		WrappedCommandInfo* cmdInfo = ti in g_WrappedCommandInfo;
		if (cmdInfo !is null)
			app.addCommandShortcuts(c.name, cmdInfo.shortcuts);
	}
}
*/

private 
{
	struct WrappedCommandInfo
	{
		TypeInfo_Class typeInfo;
		MenuItem menuItem;
		Shortcut[] shortcuts;
		Hints	hints;
	}

	static WrappedCommandInfo[] g_WrappedCommands;
}

struct ExtensionCommandInstance
{
	Command command;
	TypeInfo_Class typeInfo;
	MenuItem menuItem;
	Shortcut[] shortcuts;
	Hints	hints;	
	Exception initException;
}

/** Instantiates all known extension commands and returns them as an array
*/
ExtensionCommandInstance[] initCommands(shared DependencyContainer context)
{
	import std.algorithm : partition, startsWith, SwapStrategy;

    ExtensionCommandInstance[] result;
	foreach (cmdInfo; g_WrappedCommands)
	{
		ExtensionCommandInstance inst;
		inst.typeInfo = cmdInfo.typeInfo;
        inst.menuItem = cmdInfo.menuItem;
        inst.shortcuts = cmdInfo.shortcuts;
        inst.hints = cmdInfo.hints;

		try
        {
        	Object o = cmdInfo.typeInfo.create();
        	Autowireable w = cast(Autowireable) o;
            w.context = context;
            w.performAutowire();
            inst.command = cast(Command) o;
            inst.command.onLoaded();
        }
        catch (Exception e)
        {
            inst.initException = e;
        }
        result ~= inst;
	}

    // Make sure stop commands are first and start commands last.
    // Because stop and start commands are executed at start/shutdown
    // that will ensure that all other commands are present when these
    // commands are executed.
    result.partition!(a => a.command.name.startsWith("stop."), SwapStrategy.stable);
    result.partition!(a => !a.command.name.startsWith("start."), SwapStrategy.stable);
	return result;
}

void finiCommands(ExtensionCommandInstance[] cmds)
{
	Exception ex;
	foreach (c; cmds)
	{
		try
		{
			c.command.onUnloaded();
		}
		catch (Exception e)
		{
			ex = e;
		}
	}
	if (ex !is null)
		throw ex;
}
