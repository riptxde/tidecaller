# Getting Started with Plugins

Create your first Tidecaller plugin in minutes.

## Prerequisites

Before you start, make sure you have:
- Tidecaller installed and working via a script executor
- Basic Lua/Luau knowledge
- A text editor for writing Lua/Luau code

## Your First Plugin

Let's create a simple "hello" command that greets users by name.

### Step 1: Create Plugin File

Create a new file in your auto-execute folder:

```
autoexec/hello.tc.luau
```

?> Use the `.tc.luau` extension to make your script easily identifiable as a Tidecaller plugin.

### Step 2: Add Boilerplate

Every Tidecaller plugin starts with this boilerplate code:

```lua
--[[
    --/ Boilerplate /--

    This section contains the boilerplate code for the Tidecaller plugin.
    Please include it in your plugin.
]]
local G = type(getgenv) == 'function' and getgenv() or (_G or {})

repeat task.wait() until G.Tidecaller and G.Tidecaller.Loaded

local RegisterArgType = G.Tidecaller.RegisterArgType
local RegisterCommand = G.Tidecaller.RegisterCommand
local RegisterCategory = G.Tidecaller.RegisterCategory
local GetLocalPlayerInfo = G.Tidecaller.GetLocalPlayerInfo
local GetTargetPlayerInfo = G.Tidecaller.GetTargetPlayerInfo
local Colors = G.Tidecaller.Colors
local Fonts = G.Tidecaller.Fonts
local MonoFonts = G.Tidecaller.MonoFonts
local Notify = G.Tidecaller.Notify
```

**What this does:**
- Gets reference to global environment
- Waits for Tidecaller to finish loading
- Imports all API functions for use in your plugin

### Step 3: Register Your Command

Add this code after the boilerplate:

```lua
--/ Commands /--
RegisterCommand({
    Category = 'CUSTOM',
    Name = 'hello',
    Args = {{'string', 'name'}},
    Aliases = {'hi'},
    Description = 'Greets someone or something by name',
    Execute = function(Name)
        Notify('Success', 'Hello', ('Hello, %s!'):format(Name))
    end
})

print('[Tidecaller Plugin] Hello plugin loaded successfully')
```

**What this does:**
- Creates a command named `hello` with alias `hi`
- Takes one argument: `name` (string type)
- Shows a notification when executed
- Prints confirmation that plugin loaded

### Step 4: Save and Test

1. **Save** the file as `hello.tc.luau`
2. **Reload** Tidecaller:
   - Run `quit` command
   - Re-execute `tidecaller.luau`
3. **Test** your command:
   - Press hotkey to open palette
   - Type: `hello World`
   - Press Enter

You should see a "Hello, World!" notification!

## Understanding the Command Structure

Let's break down each part of `RegisterCommand`:

```lua
RegisterCommand({
    Category = 'CUSTOM',           -- Command category
    Name = 'hello',                -- Command name (what users type)
    Args = {{'string', 'name'}},   -- Arguments: {type, name}
    Aliases = {'hi'},              -- Alternative names
    Description = '...',           -- Shown in command palette
    Execute = function(Name)       -- Function that runs
        -- Your code here
    end
})
```

### Category
Groups related commands together. Use UPPERCASE by convention:
- `CUSTOM` - Your custom commands
- `TELEPORT` - Teleportation commands
- `UTILITY` - Utility commands

### Name
The primary command name. Use lowercase:
- Must be unique
- No spaces allowed
- Use descriptive names

### Args
Array of arguments, each specified as `{type, argname}`:

```lua
-- One required argument
Args = {{'string', 'message'}}

-- Multiple required arguments
Args = {{'player', 'target'}, {'number', 'distance'}}

-- Optional argument (third value = true)
Args = {{'string', 'name', true}}

-- Optional with default value (fourth value = default)
Args = {{'string', 'greeting', true, 'Hello'}}

-- No arguments
Args = {}
```

### Aliases
Alternative command names (optional):

```lua
Aliases = {'hi', 'greet'}  -- Can use hello, hi, or greet
Aliases = {}               -- No aliases
```

### Description
User-facing description shown in the command palette. Be clear and concise.

### Execute
Function called when command runs. Receives arguments in order:

```lua
Execute = function(Arg1, Arg2, Arg3)
    -- Arg1 = first argument value
    -- Arg2 = second argument value
    -- etc.
end
```

?> This receives the arguments as their true type. If the first argument is a `number`, then Arg1 is a `number`. If the first argument is a `player`, then Arg1 is a Roblox `Player`.

## Adding More Complexity

Let's expand our plugin with an optional greeting type:

```lua
RegisterCommand({
    Category = 'CUSTOM',
    Name = 'hello',
    Args = {
        {'string', 'name'},
        {'string', 'greeting', true, 'Hello'}
    },
    Aliases = {'hi'},
    Description = 'Greets the user by name with a custom greeting',
    Execute = function(Name, Greeting)
        local Message = ('%s, %s!'):format(Greeting, Name)
        Notify('Success', 'Greeting', Message)
    end
})
```

Now you can use:
```
hello World
hello World Howdy
```

## Using Player Information

Let's create a command that teleports to your saved position:

```lua
local SavedPosition = nil

RegisterCommand({
    Category = 'CUSTOM',
    Name = 'savepos',
    Args = {},
    Aliases = {},
    Description = 'Saves your current position',
    Execute = function()
        local Char, Root = GetLocalPlayerInfo()

        if not Root then
            Notify('Error', 'Save Position', 'Could not find your character')
            return
        end

        SavedPosition = Root.Position
        Notify('Success', 'Position Saved', ('Saved at %.0f, %.0f, %.0f'):format(
            SavedPosition.X, SavedPosition.Y, SavedPosition.Z
        ))
    end
})

RegisterCommand({
    Category = 'CUSTOM',
    Name = 'loadpos',
    Args = {},
    Aliases = {},
    Description = 'Teleports to your saved position',
    Execute = function()
        if not SavedPosition then
            Notify('Error', 'Load Position', 'No position saved')
            return
        end

        local Char, Root = GetLocalPlayerInfo()

        if not Root then
            Notify('Error', 'Load Position', 'Could not find your character')
            return
        end

        Root.CFrame = CFrame.new(SavedPosition)
        Notify('Success', 'Position Loaded', 'Teleported to saved position')
    end
})
```

Now you have `savepos` and `loadpos` commands!

## Error Handling Best Practices

Always validate your inputs and handle errors:

```lua
Execute = function(PlayerArg)
    -- Get player info
    local Player, PChar, PRoot = GetTargetPlayerInfo(PlayerArg)

    -- Check if player exists
    if not Player then
        Notify('Error', 'Command Failed', 'Player not found')
        return
    end

    -- Check if character exists
    if not PChar then
        Notify('Error', 'Command Failed', 'Player has no character')
        return
    end

    -- Safe to use PRoot now
    local Position = PRoot.Position
    Notify('Success', 'Success', ('Player is at %.0f, %.0f, %.0f'):format(
        Position.X, Position.Y, Position.Z
    ))
end
```

?> **Always check for nil** - GetLocalPlayerInfo and GetTargetPlayerInfo return nil if character/parts don't exist.

## Full Plugin Template

Here's a complete template for new plugins:

```lua
--[[
    Plugin Name: My Plugin
    Description: What this plugin does
    Commands:
    - command1 - Description
    - command2 - Description
]]

--[[
    --/ Boilerplate /--
]]
local G = type(getgenv) == 'function' and getgenv() or (_G or {})

repeat task.wait() until G.Tidecaller and G.Tidecaller.Loaded

local RegisterArgType = G.Tidecaller.RegisterArgType
local RegisterCommand = G.Tidecaller.RegisterCommand
local RegisterCategory = G.Tidecaller.RegisterCategory
local GetLocalPlayerInfo = G.Tidecaller.GetLocalPlayerInfo
local GetTargetPlayerInfo = G.Tidecaller.GetTargetPlayerInfo
local Colors = G.Tidecaller.Colors
local Fonts = G.Tidecaller.Fonts
local MonoFonts = G.Tidecaller.MonoFonts
local Notify = G.Tidecaller.Notify

--/ Services /--
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')

--/ Helper Functions /--
local function Create(ClassName, Properties)
    Properties = Properties or {}

    local Obj = Instance.new(ClassName)
    local HasParent = false

    for Property, Value in next, Properties do
        if Property == 'Parent' then
            HasParent = true
            continue
        else
            Obj[Property] = Value
        end
    end

    if HasParent then
        Obj.Parent = Properties.Parent
    end

    return Obj
end

--/ State /--
-- Add your plugin's state variables here

--/ Commands /--
RegisterCommand({
    Category = 'CUSTOM',
    Name = 'mycommand',
    Args = {{'string', 'arg'}},
    Aliases = {},
    Description = 'My command description',
    Execute = function(Arg)
        -- Command logic here
        Notify('Info', 'Command', 'Executed!')
    end
})

print('[Tidecaller Plugin] My plugin loaded successfully')
```

## Built-in Argument Types

Tidecaller includes several built-in argument types you can use without defining them yourself.

### player

Selects a player in the game. Shows display names and usernames, filtered as you type.

```lua
Args = {{'player', 'target'}}
```

Use `@username` to search by username specifically when multiple players have similar display names.

### number

Numeric input with validation. Provides common presets (0, 1, 16, 50, 100) and accepts custom values.

```lua
Args = {{'number', 'speed'}}
Args = {{'number', 'amount', true, 50}}  -- Optional with default
```

### string

Freeform text input. Supports spaces when quoted.

```lua
Args = {{'string', 'message'}}
Args = {{'string', 'name', true, 'DefaultName'}}  -- Optional with default
```

### boolean

Boolean toggle with "true" and "false" suggestions.

```lua
Args = {{'boolean', 'enabled'}}

Execute = function(State)
    if State == true then
        -- Enable feature
    else
        -- Disable feature
    end
end
```

### keycode

Keyboard key selection. Shows common keycodes and validates against Roblox `Enum.KeyCode`.

```lua
Args = {{'keycode', 'hotkey'}}
```

Common values: `Quote`, `Backslash`, `Semicolon`, `F1`-`F12`

### theme

Theme selection from available themes in `workspace/tidecaller/themes/`.

```lua
Args = {{'theme', 'theme_name'}}
```

Shows both built-in themes (catppuccin_mocha, catppuccin_latte) and custom themes.
