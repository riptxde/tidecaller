# API Reference

Complete documentation for all Tidecaller plugin API functions.

## Overview

Plugins access Tidecaller functionality through the global table:

```lua
local G = type(getgenv) == 'function' and getgenv() or (_G or {})
repeat task.wait() until G.Tidecaller and G.Tidecaller.Loaded

-- Access API functions
local RegisterCommand = G.Tidecaller.RegisterCommand
local Notify = G.Tidecaller.Notify
-- ... etc
```

## Functions

### RegisterCommand

Registers a new command with Tidecaller.

#### Signature

```lua
RegisterCommand({
    Category = string,
    Name = string,
    Args = table,
    Aliases = table,
    Description = string,
    Execute = function
})
```

#### Parameters

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Category | string | Yes | Category name (UPPERCASE by convention) |
| Name | string | Yes | Primary command name (lowercase) |
| Args | table | Yes | Array of argument specifications (can be empty) |
| Aliases | table | Yes | Array of alternative command names (can be empty) |
| Description | string | Yes | User-facing description shown in palette |
| Execute | function | Yes | Function called when command executes |

#### Argument Specification Format

Arguments in the `Args` table use these patterns:

```lua
-- Required argument
{'argtype', 'argname'}

-- Optional argument (auto-determined default)
{'argtype', 'argname', true}

-- Optional argument with specific default value
{'argtype', 'argname', true, default_value}
```

**Examples:**
```lua
-- Required string argument
{'string', 'message'}

-- Required player argument
{'player', 'target'}

-- Optional number (auto-determined)
{'number', 'count', true}

-- Optional string with default "Hello"
{'string', 'greeting', true, 'Hello'}

-- Optional number with default 0
{'number', 'offset', true, 0}
```

#### Execute Function

The Execute function receives arguments in the order specified:

```lua
Execute = function(Arg1, Arg2, Arg3)
    -- Arg1 = first argument value
    -- Arg2 = second argument value (may be nil if optional and omitted)
    -- Arg3 = third argument value (or default if optional)
end
```

#### Example

```lua
RegisterCommand({
    Category = 'TELEPORT',
    Name = 'goto',
    Args = {
        {'player', 'target'},           -- Required
        {'number', 'offset', true, 0}   -- Optional, defaults to 0
    },
    Aliases = {'tp', 'teleport'},
    Description = 'Teleport to a player with optional offset',
    Execute = function(Player, Offset)
        local Char, Root = GetLocalPlayerInfo()
        if not Root then
            Notify('Error', 'Goto', 'Could not find your character')
            return
        end

        local _, PChar, PRoot = GetTargetPlayerInfo(Player)
        if not PRoot then
            Notify('Error', 'Goto', 'Could not find target player')
            return
        end

        Root.CFrame = PRoot.CFrame * CFrame.new(0, Offset, 0)
        Notify('Success', 'Teleported', ('Teleported to %s'):format(Player.DisplayName))
    end
})
```

#### Notes

- Category is auto-created if this is the first command of its category
- Command names must be unique (will not override if duplicate)
- Execute receives arguments in order specified in Args
- Optional arguments with no default pass `nil` if omitted

---

### RegisterArgType

Registers a custom argument type for use in commands.

#### Signature

```lua
RegisterArgType('typename', {
    Color = Color3,
    GetValue = function,
    GetSuggestions = function,  -- Optional
    BuildPaletteItem = function  -- Optional
})
```

#### Parameters

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| typename | string | Yes (first param) | Unique identifier for this type |
| Color | Color3 | Yes | UI color for this type (use `Colors.ColorName`) |
| GetValue | function | Yes | Validates and transforms string input |
| GetSuggestions | function | No | Returns array of suggestions (for autocomplete) |
| BuildPaletteItem | function | No | Creates UI elements for suggestion (for autocomplete) |

#### GetValue Function

```lua
GetValue = function(Str)
    -- Str: string - Raw user input from command

    -- Return: transformed value, or nil if invalid
    return tonumber(Str)  -- Example: parse as number
end
```

**Parameters:**
- `Str` - Raw string input from the command

**Return:**
- The transformed/validated value to pass to the command Execute function
- Return `nil` if the input is invalid (will show error notification)

!> This function is called when a command is executed to validate and transform the raw string input into the actual value passed to the command's Execute function. If you return `nil`, Tidecaller will display an error notification and prevent the command from executing.

#### GetSuggestions Function

```lua
GetSuggestions = function(Query, PreviousArgs)
    -- Query: string - User's current input
    -- PreviousArgs: table - Previously entered arguments (array)

    -- Return: table - Array of suggestion strings
    return {'suggestion1', 'suggestion2', 'suggestion3'}
end
```

**Parameters:**
- `Query` - What the user has typed so far
- `PreviousArgs` - Arguments already entered (may be empty)

**Return:**
- Array of strings that match the query

#### BuildPaletteItem Function

```lua
BuildPaletteItem = function(Suggestion)
    -- Suggestion: string - The suggestion to build UI for

    -- Return: value, {children}
    --   value: The actual value to pass to command (often same as Suggestion)
    --   children: Array of Instance objects to parent to palette item

    local Label = Create('TextLabel', {
        -- Properties
    })

    return Suggestion, {Label}
end
```

**Parameters:**
- `Suggestion` - One of the suggestions from GetSuggestions

**Return:** Two values:
1. The actual value to use (can differ from display)
2. Array of Instance objects to display in palette

#### Example

```lua
RegisterArgType('direction', {
    Color = Colors.Blue,
    GetValue = function(Str)
        -- Validate the direction
        local Directions = {'North', 'South', 'East', 'West'}
        for I = 1, #Directions do
            if Directions[I]:lower() == Str:lower() then
                return Directions[I]  -- Return normalized value
            end
        end
        return nil  -- Invalid direction
    end,
    GetSuggestions = function(Query, PreviousArgs)
        local Directions = {'North', 'South', 'East', 'West'}
        local Filtered = {}

        -- Filter based on query
        for I = 1, #Directions do
            local Dir = Directions[I]
            if Query == '' or Dir:lower():find(Query:lower(), 1, true) then
                Filtered[#Filtered + 1] = Dir
            end
        end

        return Filtered
    end,
    BuildPaletteItem = function(Suggestion)
        local Padding = Create('UIPadding', {
            PaddingLeft = UDim.new(0, 12)
        })

        local Label = Create('TextLabel', {
            Name = 'Label',
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            FontFace = Fonts.Bold,
            Text = Suggestion,
            TextColor3 = Colors.Text,
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center
        })

        return Suggestion, {Padding, Label}
    end
})
```

#### Notes

- `GetValue` is always required for validation/transformation
- `GetSuggestions` and `BuildPaletteItem` are optional (for autocomplete)
- If you omit `GetSuggestions`/`BuildPaletteItem`, users must type values manually
- GetSuggestions should be fast (< 100ms)
- Limit suggestions to reasonable count (< 50)
- BuildPaletteItem must return valid Instances
- Color helps users visually distinguish types

---

### GetLocalPlayerInfo

Gets information about the local player's character.

#### Signature

```lua
local Char, Root, Humanoid, Head, Part = GetLocalPlayerInfo()
```

#### Parameters

None

#### Return Values

| Value | Type | Description |
|-------|------|-------------|
| Char | Model \| nil | Character model |
| Root | BasePart \| nil | HumanoidRootPart |
| Humanoid | Humanoid \| nil | Humanoid instance |
| Head | BasePart \| nil | Head part |
| Part | BasePart \| nil | First available part (Root -> Head preference) |

#### Example

```lua
Execute = function()
    local Char, Root, Humanoid, Head, Part = GetLocalPlayerInfo()

    if not Root then
        Notify('Error', 'No Character', 'Could not find your character')
        return
    end

    -- Safe to use Root
    Root.CFrame = CFrame.new(0, 50, 0)
    Notify('Success', 'Teleported', 'Moved to 0, 50, 0')
end
```

#### Notes

- Returns nil for all values if character doesn't exist
- Always check for nil before using
- `Part` is most reliable (tries multiple sources)
- `Root` preferred for movement/teleportation
- `Humanoid` useful for state checks (health, etc.)

---

### GetTargetPlayerInfo

Gets information about a target player's character.

#### Signature

```lua
local Player, PChar, PRoot, PHumanoid, PHead, PPart = GetTargetPlayerInfo(PlayerInstance)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| PlayerInstance | Player | The target Player instance |

#### Return Values

| Value | Type | Description |
|-------|------|-------------|
| Player | Player | The input player (for convenience) |
| PChar | Model \| nil | Target's character model |
| PRoot | BasePart \| nil | Target's HumanoidRootPart |
| PHumanoid | Humanoid \| nil | Target's Humanoid |
| PHead | BasePart \| nil | Target's Head |
| PPart | BasePart \| nil | First available part (PRoot -> PHead preference) |

#### Example

```lua
Execute = function(TargetPlayer)
    local Player, PChar, PRoot, PHumanoid, PHead, PPart = GetTargetPlayerInfo(TargetPlayer)

    if not Player then
        Notify('Error', 'Invalid Player', 'Player not found')
        return
    end

    if not PPart then
        Notify('Error', 'No Character', 'Player has no character')
        return
    end

    -- Teleport to target
    local Char, Root = GetLocalPlayerInfo()
    if Root then
        Root.CFrame = PRoot.CFrame
        Notify('Success', 'Teleported', ('Teleported to %s'):format(Player.DisplayName))
    end
end
```

#### Notes

- `Player` is always returned (first value)
- Other values are nil if character/parts don't exist
- Always validate before using character parts
- `PPart` most reliable for general use
- `PRoot` preferred for position-based operations

---

### Notify

Displays a notification to the user.

#### Signature

```lua
Notify(Type, Title, Message, Duration)
```

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| Type | string | Yes | Notification type |
| Title | string | Yes | Notification title |
| Message | string | Yes | Notification message content |
| Duration | number | No | Display duration in seconds (auto-calculated if omitted) |

#### Notification Types

| Type | Description | Visual Style |
|------|-------------|--------------|
| `'Success'` | Successful operations | Green accent |
| `'Info'` | Informational messages | Blue accent |
| `'Warning'` | Warnings, non-critical issues | Yellow accent |
| `'Error'` | Errors, failed operations | Red accent |

#### Example

```lua
-- Success notification
Notify('Success', 'Command Complete', 'Operation successful')

-- Error with custom duration
Notify('Error', 'Failed', 'Something went wrong', 5)

-- Info with auto-duration
Notify('Info', 'Loading', 'Please wait...')

-- Warning
Notify('Warning', 'Beta Feature', 'This feature is experimental')
```

#### Notes

- Duration auto-calculated from message length if not provided
- Notifications stack on screen
- Multiple notifications can display simultaneously
- Type is case-sensitive

---

### Colors

Global table containing theme colors.

#### Type

`table<string, Color3>`

#### Usage

```lua
local Colors = G.Tidecaller.Colors

local BlueColor = Colors.Blue
local BackgroundColor = Colors.Base
```

#### Available Colors

**Background Colors:**
- `Base` - Main background
- `Mantle` - Secondary background
- `Crust` - Tertiary background

**Surface Colors:**
- `Surface0`, `Surface1`, `Surface2` - Layered surfaces

**Overlay Colors:**
- `Overlay0`, `Overlay1`, `Overlay2` - Overlay elements

**Text Colors:**
- `Text` - Primary text
- `Subtext1` - Secondary text
- `Subtext0` - Tertiary text

**Accent Colors:**
- `Blue`, `Lavender`, `Sapphire`, `Sky`, `Teal` - Cool tones
- `Green` - Success, positive
- `Yellow` - Warning, attention
- `Peach` - Warm accent
- `Maroon`, `Red` - Error, danger
- `Mauve` - Special elements
- `Pink`, `Flamingo`, `Rosewater` - Soft accents

#### Example

```lua
-- Use in custom argument type
RegisterArgType('mytype', {
    Color = Colors.Mauve,
    ...
})

-- Use in UI creation
local Frame = Create('Frame', {
    BackgroundColor3 = Colors.Base,
    BorderColor3 = Colors.Surface1
})

local Label = Create('TextLabel', {
    TextColor3 = Colors.Text,
    BackgroundColor3 = Colors.Surface0
})
```

#### Notes

- Colors reflect current theme
- Updated on theme change (requires reload)
- Use for consistent theming across plugins

---

### Fonts

Global table containing font faces.

#### Type

`table<string, Font>`

#### Usage

```lua
local Fonts = G.Tidecaller.Fonts

local BoldFont = Fonts.Bold
```

#### Available Fonts

- `Regular` - Regular weight
- `Medium` - Medium weight
- `Bold` - Bold weight

#### Example

```lua
local Label = Create('TextLabel', {
    FontFace = Fonts.Bold,
    Text = 'Hello World',
    TextSize = 16,
    TextColor3 = Colors.Text
})

local SubLabel = Create('TextLabel', {
    FontFace = Fonts.Regular,
    Text = 'Subtitle',
    TextSize = 14,
    TextColor3 = Colors.Subtext1
})
```

#### Notes

- Font family based on theme settings
- Default: BuilderSans
- Use for general UI text
- Weights: Regular (400), Medium (500), Bold (700)

---

### MonoFonts

Global table containing monospace font faces.

#### Type

`table<string, Font>`

#### Usage

```lua
local MonoFonts = G.Tidecaller.MonoFonts

local MonoFont = MonoFonts.Regular
```

#### Available Fonts

- `Regular` - Regular weight monospace
- `Medium` - Medium weight monospace
- `Bold` - Bold weight monospace

#### Example

```lua
local CodeLabel = Create('TextLabel', {
    FontFace = MonoFonts.Regular,
    Text = '(100, 50, 0)',
    TextSize = 14,
    TextColor3 = Colors.Subtext1
})

local CoordinateDisplay = Create('TextLabel', {
    FontFace = MonoFonts.Medium,
    Text = 'X: 123, Y: 45, Z: 678',
    TextSize = 12,
    TextColor3 = Colors.Text
})
```

#### Notes

- Font family based on theme settings
- Default: Inconsolata
- Use for coordinates, code, technical data
- Provides consistent character spacing

---

## Helper Functions

While not part of the official API, these patterns are commonly used in plugins.

### Create Helper

Utility for creating Roblox instances with properties:

```lua
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
```

**Usage:**
```lua
local Frame = Create('Frame', {
    Size = UDim2.new(1, 0, 0, 50),
    BackgroundColor3 = Colors.Base,
    BorderSizePixel = 0,
    Parent = SomeParent
})
```

**Why?**
- Sets Parent last to avoid premature rendering
- Clean, readable syntax
- Commonly used pattern

?> **Note:** Redefine this function in your plugin—it's not globally available.
