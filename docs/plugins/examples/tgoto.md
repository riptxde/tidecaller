# Example: tgoto (Simple Command)

A simple plugin that teleports your character to a target player with smooth animation.

## Overview

**File:** `tgoto.tc.luau`

### What It Does

Creates a `tgoto` command that:
1. Takes a player name as input
2. Finds the target player
3. Smoothly teleports you to their position
4. Shows success/error notifications

### What You'll Learn

- Basic plugin structure with boilerplate
- Using built-in `player` argument type
- GetLocalPlayerInfo() - Getting your character
- GetTargetPlayerInfo() - Getting target player
- Error handling and validation
- Using Notify() for feedback
- TweenService integration for smooth movement

## Complete Code with Annotations

```lua
--[[
    Example Plugin: Player Teleport (tgoto)

    This plugin demonstrates:
    - Using built-in argument types (player)
    - Working with GetLocalPlayerInfo and GetTargetPlayerInfo
    - Basic error handling and validation
    - Providing user feedback with Notify

    Commands:
    - tgoto <player> - Teleports your character to the target player
]]

--[[
    --/ Boilerplate /--

    This section contains the boilerplate code for the Tidecaller plugin
    Please include it in your plugin
]]

-- Get reference to global environment (works across different executors)
local G = type(getgenv) == 'function' and getgenv() or (_G or {})

-- Wait for Tidecaller to finish loading
-- This ensures all API functions are available
repeat task.wait() until G.Tidecaller and G.Tidecaller.Loaded

-- Import Tidecaller API functions
-- These give us access to plugin functionality
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
-- Get TweenService for smooth teleportation animation
local TweenService = game:GetService('TweenService')

--/ Commands /--
RegisterCommand({
    -- Category groups related commands together in the palette
    -- Use UPPERCASE by convention
    Category = 'TELEPORT',

    -- Command name - what users type to invoke it
    -- Use lowercase for command names
    Name = 'tgoto',

    -- Arguments: Array of {type, name, optional, default}
    -- Here we have one required argument of type 'player' named 'target'
    -- The 'player' type is built-in and provides player selection with autocomplete
    Args = {
        {'player', 'target'}
    },

    -- Aliases: Alternative names for the command
    -- Empty array means no aliases
    Aliases = {},

    -- Description shown in the command palette
    -- Be clear and concise about what the command does
    Description = 'Teleports your character to the target player',

    -- Execute: Function called when command runs
    -- Receives arguments in the order specified in Args
    Execute = function(TargetPlayer)
        -- Get local player's character information
        -- Returns: Char, Root, Humanoid, Head, Part
        -- All values are nil if character doesn't exist
        local Char, Root, Humanoid, Head, Part = GetLocalPlayerInfo()

        -- Validate that we found the local player's root part
        -- Always check for nil before using!
        if not Root then
            -- Show error notification if character not found
            -- Format: Notify(Type, Title, Message, Duration)
            Notify('Error', 'Tween Goto', 'Could not find your character\'s root part')
            return  -- Exit early
        end

        -- Get target player's character information
        -- Returns: Player, PChar, PRoot, PHumanoid, PHead, PPart
        -- Player is always returned, others are nil if character doesn't exist
        local Player, PChar, PRoot, PHumanoid, PHead, PPart = GetTargetPlayerInfo(TargetPlayer)

        -- Validate that we found a valid part in target's character
        -- PPart is the most reliable (tries Root first, then Head)
        if not PPart then
            -- Show error if target player has no valid character parts
            Notify('Error', 'Tween Goto', 'Could not find a valid part in the target player\'s character')
            return  -- Exit early
        end

        -- Create smooth tween animation for teleportation
        -- TweenInfo: new(duration, easing style, easing direction)
        local TweenInfo = TweenInfo.new(
            0.5,                      -- Duration: 0.5 seconds
            Enum.EasingStyle.Quad,    -- Easing: Smooth acceleration/deceleration
            Enum.EasingDirection.Out  -- Ease out: Fast start, slow end
        )

        -- Goal: What property to animate to what value
        -- We want to move Root's CFrame to target's position
        local Goal = {CFrame = PRoot.CFrame}

        -- Create the tween
        local Tween = TweenService:Create(Root, TweenInfo, Goal)

        -- Start the animation
        Tween:Play()

        -- Show success notification
        -- Use Player.DisplayName for user-friendly name
        -- :format() substitutes %s with the player name
        Notify('Success', 'Teleported', ('Teleporting to %s'):format(Player.DisplayName))
    end
})

-- Confirmation message that plugin loaded successfully
-- Helps with debugging - you'll see this in the console
-- Preferably, remove these unnecessary print statements when you're finished testing
print('[Tidecaller Plugin] tgoto example loaded successfully')
```

## Code Breakdown

### 1. Boilerplate

```lua
local G = type(getgenv) == 'function' and getgenv() or (_G or {})
repeat task.wait() until G.Tidecaller and G.Tidecaller.Loaded
```

**Why?**
- Works across different executors (some have `getgenv`, some use `_G`)
- Waits for Tidecaller to initialize before running plugin code
- Essential for all plugins!

### 2. Importing API Functions

```lua
local RegisterCommand = G.Tidecaller.RegisterCommand
local GetLocalPlayerInfo = G.Tidecaller.GetLocalPlayerInfo
-- etc.
```

**Why?**
- Shorter, cleaner code
- Access to Tidecaller functionality
- Import only what you need

### 3. RegisterCommand Structure

```lua
RegisterCommand({
    Category = 'TELEPORT',
    Name = 'tgoto',
    Args = {{'player', 'target'}},
    Aliases = {},
    Description = '...',
    Execute = function(TargetPlayer)
        -- ...
    end
})
```

**Parts:**
- **Category** - Groups commands in palette (UPPERCASE)
- **Name** - Command name users type (lowercase)
- **Args** - Argument specifications
- **Aliases** - Alternative command names
- **Description** - User-facing help text
- **Execute** - Function that runs when command is called

### 4. Getting Character Information

```lua
local Char, Root, Humanoid, Head, Part = GetLocalPlayerInfo()
```

**Returns:**
- `Char` - Character Model
- `Root` - HumanoidRootPart (use for teleportation)
- `Humanoid` - Humanoid instance
- `Head` - Head part
- `Part` - First available part (Root -> Head)

**Always check for nil!**
```lua
if not Root then
    Notify('Error', 'Title', 'Message')
    return
end
```

### 5. Getting Target Player

```lua
local Player, PChar, PRoot, PHumanoid, PHead, PPart = GetTargetPlayerInfo(TargetPlayer)
```

**Returns:**
- `Player` - The Player instance (always returned)
- `PChar` - Target's Character Model
- `PRoot` - Target's HumanoidRootPart
- `PHumanoid` - Target's Humanoid
- `PHead` - Target's Head
- `PPart` - First available part (PRoot -> PHead)

### 6. Error Handling Pattern

```lua
if not Root then
    Notify('Error', 'Title', 'Descriptive error message')
    return
end

// More operations...

if not PPart then
    Notify('Error', 'Title', 'Different error message')
    return
end
```

**Key Points:**
- Check each critical value
- Return early on error
- Provide clear error messages
- Use appropriate notification type

### 7. TweenService Integration

```lua
local TweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Goal = {CFrame = PRoot.CFrame}
local Tween = TweenService:Create(Root, TweenInfo, Goal)
Tween:Play()
```

**Creates smooth animation instead of instant teleport.**

**Parameters:**
- Duration: How long the animation takes
- Easing Style: Animation curve
- Easing Direction: In/Out/InOut

## Usage Examples

### Basic Usage

```
tgoto Player123
```

Teleports you to Player123 with a smooth 0.5-second animation.

### With Display Names

```
tgoto John
```

Searches by display name. If multiple players have the same display name, you might teleport to the wrong one.

### With Username Search

```
tgoto @actualusername
```

Use `@` prefix to search by exact username instead of display name.
