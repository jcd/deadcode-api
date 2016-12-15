module deadcode.api;

public import deadcode.api.api;

// Convenience public imports (not used by this module itself)
public import deadcode.math.rect;
public import deadcode.math.region;
public import deadcode.math.smallvector;
public import core.thread;
public import std.variant;

/** Register all public module functions and classes as commands

  Functions are registered by wrapping them in a class derived from Command
  Classes being registered must derive from Command and will also be wrapped by a dependency
  injecting class

  Note: this template doesn't work for package modules ie. package.d files.
*/
template registerCommands(string Mod = __MODULE__)
{
    import deadcode.api.commandautoregisterhelper;

    version (none)
    {
        import std.typetuple;
        pragma(msg, "Registering command functions: ", Mod, " ", staticMap!(getCommandFunctionFunction, extensionCommandFunctions!(mixin(Mod))));
        pragma(msg, "Registering command classes  : ", Mod, " ", TypeTuple!(extensionCommandClasses!(mixin(Mod))));
    }
    version (all)
    {
        struct CTRegister
        {
            alias _commandFunctionsCTRegister = commandFunctionsCTRegister!(mixin(Mod));
            alias _commandClassesCTRegister = commandClassesCTRegister!(mixin(Mod));
        }
    }
    version (DeadcodeOutOfProcess)
    {
        import deadcode.api.rpcclient;
        mixin rpcClient;
    }
}
