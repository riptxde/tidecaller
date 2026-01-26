# Plugin System

Extend Tidecaller with custom commands, argument types, and functionality.

## What are Plugins?

Plugins are Lua scripts that extend Tidecaller by:
- **Adding custom commands** - Create game-specific or utility commands
- **Defining argument types** - Add custom argument validation and suggestions
- **Integrating with Tidecaller** - Access player info, notifications, and UI colors
- **Running automatically** - Load from auto-execute folder on startup

## Where to Put Plugins

### Auto-Execute Folder

Place plugins in your executor's auto-execute folder, for example:

```
autoexec/
├── tidecaller.luau  (main script)
├── mycommands.tc.luau
├── someplugin.tc.luau
└── waypoints.tc.luau
```

Plugins load automatically when the executor starts.

You can also execute plugins manually, which may be useful for debugging or testing. No additional setup is required for this as plugin boilerplate automatically checks for Tidecaller's loaded state.

?> Why do plugins go in the autoexec folder, instead of a standard workspace folder like the majority of other scripts which support plugins? **Because any script can write to any folder in your executor's workspace folder. This means malicious scripts can append untrusted code into existing plugins there. The autoexec folder is more secure in this regard.**

## How Plugins Work

### Load Order

1. Tidecaller script executes
2. Initializes UI and built-in commands
3. Sets `G.Tidecaller.Loaded = true`
4. Plugins in auto-execute detect loaded state
5. Plugins register commands and types
6. Commands become available in palette

### Integration

Plugins access Tidecaller through the global table:

```lua
local G = type(getgenv) == 'function' and getgenv() or (_G or {})

repeat task.wait() until G.Tidecaller and G.Tidecaller.Loaded

-- Access API functions
local RegisterArgType = G.Tidecaller.RegisterArgType
local RegisterCommand = G.Tidecaller.RegisterCommand
local GetLocalPlayerInfo = G.Tidecaller.GetLocalPlayerInfo
local GetTargetPlayerInfo = G.Tidecaller.GetTargetPlayerInfo
local Colors = G.Tidecaller.Colors
local Fonts = G.Tidecaller.Fonts
local MonoFonts = G.Tidecaller.MonoFonts
local Notify = G.Tidecaller.Notify
```

## Plugin File Structure

### Naming Convention

Use the `.tc.luau` extension to make a script easily identifiable as a Tidecaller plugin:

```
mycommands.tc.luau
teleports.tc.luau
utilities.tc.luau
```

## Available API Functions

Plugins have access to these functions:

| Function | Purpose |
|----------|---------|
| `RegisterCommand` | Register a new command |
| `RegisterArgType` | Create a custom argument type |
| `GetLocalPlayerInfo` | Get local player's character info |
| `GetTargetPlayerInfo` | Get target player's character info |
| `Notify` | Show notifications |
| `Colors` | Access theme colors |
| `Fonts` | Access theme fonts |
| `MonoFonts` | Access monospace fonts |

See [API Reference](/plugins/api-reference.md) for complete documentation.

## Game-Specific Plugins

To make a plugin which is only enabled for a specific game, simply add a check for the game's place ID at the very top of your plugin:

```lua
if game.PlaceId ~= 1234567890 then
    return
end
```
