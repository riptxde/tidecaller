# Example: waypoints (Advanced System)

A complete waypoint system with save, load, delete, and file persistence.

## Overview

**File:** `waypoints.tc.luau`

### What It Does

Creates a complete waypoint management system:
1. **savewaypoint** - Save current position (auto-generates name if not provided)
2. **deletewaypoint** - Delete a saved waypoint
3. **gotowaypoint** - Teleport to a saved waypoint
4. Persists data to `workspace/tidecaller/waypoints.json`
5. Loads saved waypoints on startup
6. Handles corrupted files gracefully

### What You'll Learn

- Dynamic custom argument types
- File I/O operations (read/write JSON)
- Multiple related commands
- State management across commands
- Auto-generated default values (nil handling)
- Error recovery from corrupted files
- Data validation
- Folder creation and management
- Initialization patterns
- Complex BuildPaletteItem layouts

## Architecture

```
┌─────────────────────────────────────┐
│           Waypoint System           │
├─────────────────────────────────────┤
│ State:                              │
│  - Waypoints = {}  (in-memory)      │
│  - waypoints.json  (on disk)        │
├─────────────────────────────────────┤
│ Operations:                         │
│  - LoadWaypoints() -> Read file     │
│  - SaveWaypoints() -> Write file    │
│  - Add/Delete waypoints             │
├─────────────────────────────────────┤
│ Custom Type: 'waypoint'             │
│  - Dynamic suggestions from state   │
│  - Shows name + coordinates         │
└─────────────────────────────────────┘
```

## Complete Code with Annotations

```lua
--[[
    Example Plugin: Waypoints System (waypoints)

    This plugin demonstrates:
    - Creating a complex custom argument type with dynamic data
    - Having an optional argument, but having custom logic for the default value
    - Command aliases

    Commands:
    - savewaypoint [savewp] <name: auto> - Saves your current position as a waypoint
    - deletewaypoint [delwp] <waypoint> - Deletes a saved waypoint
    - gotowaypoint [gotowp] <waypoint> - Teleports to a saved waypoint
]]

--[[
    --/ Boilerplate /--

    This section contains the boilerplate code for the Tidecaller plugin
    Please include it in your plugin
]]

-- Get reference to global environment (works across different executors)
local G = type(getgenv) == 'function' and getgenv() or (_G or {})

-- Wait for Tidecaller to finish loading
repeat task.wait() until G.Tidecaller and G.Tidecaller.Loaded

-- Import Tidecaller API functions
local RegisterArgType = G.Tidecaller.RegisterArgType
local RegisterCommand = G.Tidecaller.RegisterCommand
local GetLocalPlayerInfo = G.Tidecaller.GetLocalPlayerInfo
local Colors = G.Tidecaller.Colors
local Fonts = G.Tidecaller.Fonts
local MonoFonts = G.Tidecaller.MonoFonts
local Notify = G.Tidecaller.Notify

--/ Services /--
local HttpService = game:GetService('HttpService')
local TweenService = game:GetService('TweenService')

--/ Helper Functions /--
-- Create function: Utility for creating instances with properties
-- Parent is set last to avoid premature rendering
local function Create(ClassName, Properties)
    Properties = Properties or {}
    local Obj = Instance.new(ClassName)
    local HasParent = false

    -- Set all properties except Parent
    for Property, Value in next, Properties do
        if Property == 'Parent' then
            HasParent = true
            continue
        else
            Obj[Property] = Value
        end
    end

    -- Set Parent last
    if HasParent then
        Obj.Parent = Properties.Parent
    end

    return Obj
end

--/ Constants /--
-- File system paths for persistent storage
local WAYPOINTS_FILE = 'waypoints.json'
local WAYPOINTS_FOLDER = 'tidecaller'

--/ State /--
-- In-memory waypoint storage
-- Structure: {[name] = {X = number, Y = number, Z = number}}
-- We store as table instead of Vector3 for JSON serialization
local Waypoints = {}

--/ File Operations /--
-- LoadWaypoints: Reads waypoints from disk on startup
local function LoadWaypoints()
    -- Ensure folder exists before trying to read
    if not isfolder(WAYPOINTS_FOLDER) then
        makefolder(WAYPOINTS_FOLDER)
    end

    local FilePath = WAYPOINTS_FOLDER .. '/' .. WAYPOINTS_FILE

    -- Check if file exists
    if not isfile(FilePath) then
        -- First run - no waypoints saved yet
        Waypoints = {}
        return
    end

    -- Try to load and parse the file
    -- Using pcall to catch any errors (corrupted file, invalid JSON, etc.)
    local Success, Result = pcall(function()
        local FileContent = readfile(FilePath)
        return HttpService:JSONDecode(FileContent)
    end)

    if Success and type(Result) == 'table' then
        -- Successfully loaded valid data
        Waypoints = Result

        -- Count waypoints for confirmation message
        local WaypointsCount = 0
        for _, Waypoint in next, Waypoints do
            WaypointsCount = WaypointsCount + 1
        end

        print(('[Tidecaller Waypoints] Loaded %d waypoints'):format(WaypointsCount))
    else
        -- Failed to load or invalid data
        Waypoints = {}
        Notify('Warning', 'Waypoints Corrupted', 'Could not load waypoints file. Starting fresh.')
        print('[Tidecaller Waypoints] Failed to load waypoints:', Result)
    end
end

-- SaveWaypoints: Writes waypoints to disk
local function SaveWaypoints()
    -- Ensure folder exists
    if not isfolder(WAYPOINTS_FOLDER) then
        makefolder(WAYPOINTS_FOLDER)
    end

    local FilePath = WAYPOINTS_FOLDER .. '/' .. WAYPOINTS_FILE

    -- Try to save the file
    -- Using pcall to catch permission errors, disk full, etc.
    local Success, Error = pcall(function()
        -- Encode waypoints table to JSON string
        local JsonData = HttpService:JSONEncode(Waypoints)
        -- Write to file
        writefile(FilePath, JsonData)
    end)

    if not Success then
        -- Failed to save - notify user
        Notify('Error', 'Save Failed', 'Could not save waypoints to file')
        print('[Tidecaller Waypoints] Failed to save waypoints:', Error)
        return false
    end

    return true
end

--/ Custom Argument Types /--
RegisterArgType('waypoint', {
    -- Color: Defines the visual color in the UI
    -- Using Mauve (purple) for special/saved items
    Color = Colors.Mauve,

    -- GetSuggestions: Returns array of suggestions based on user input
    -- This is DYNAMIC - updates as waypoints are added/deleted
    GetSuggestions = function(Query, PreviousArgs)
        -- Query: string - What the user has typed so far
        -- PreviousArgs: table - Previously entered arguments (not used here)

        local Suggestions = {}

        -- Filter waypoints based on query
        -- Unlike gotopoint, suggestions come from runtime data
        for WaypointName, Position in next, Waypoints do
            -- Case-insensitive filtering
            if Query == '' or WaypointName:lower():find(Query:lower(), 1, true) then
                Suggestions[#Suggestions + 1] = WaypointName
            end
        end

        -- Sort alphabetically for consistent ordering
        table.sort(Suggestions, function(A, B)
            return A:lower() < B:lower()
        end)

        return Suggestions
    end,

    -- BuildPaletteItem: Creates UI elements for displaying a suggestion
    -- Same layout as gotopoint (name + coordinates)
    BuildPaletteItem = function(Suggestion)
        -- Suggestion: string - One of the suggestions from GetSuggestions

        -- Create padding for the item
        local Padding = Create('UIPadding', {
            PaddingLeft = UDim.new(0, 12)
        })

        -- Create main label for waypoint name (top 60%)
        local Label = Create('TextLabel', {
            Name = 'Label',
            Size = UDim2.new(1, 0, 0.6, 0),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            FontFace = Fonts.Bold,
            Text = Suggestion,
            TextColor3 = Colors.Text,
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center
        })

        -- Get position data for this waypoint
        local Position = Waypoints[Suggestion]

        -- Format coordinates with floor (no decimals)
        local CoordinateText = ('(%d, %d, %d)'):format(
            math.floor(Position.X),
            math.floor(Position.Y),
            math.floor(Position.Z)
        )

        -- Create smaller label for coordinates (bottom 40%)
        local CoordinateLabel = Create('TextLabel', {
            Name = 'CoordinateLabel',
            Size = UDim2.new(1, 0, 0.4, 0),
            Position = UDim2.new(0, 0, 0.5, 0),
            BackgroundTransparency = 1,
            FontFace = MonoFonts.Regular,
            Text = CoordinateText,
            TextColor3 = Colors.Subtext1,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center
        })

        return Suggestion, {Padding, Label, CoordinateLabel}
    end
})

--/ Commands /--

-- Command 1: Save Waypoint
RegisterCommand({
    Category = 'TELEPORT',
    Name = 'savewaypoint',
    Args = {
        -- Optional string argument with no default value specified
        -- The FOURTH parameter is omitted, so it passes nil if not provided
        -- We handle the nil case with custom logic (auto-generate name)
        {'string', 'name', true}
    },
    Aliases = {'savewp'},
    Description = 'Saves your current position as a waypoint',
    Execute = function(WaypointName)
        -- Get local player's character information
        local Char, Root, Humanoid, Head, Part = GetLocalPlayerInfo()
        if not Root then
            Notify('Error', 'Save Waypoint', 'Could not find your character\'s root part')
            return
        end

        -- Auto-generate name if not provided
        -- This demonstrates handling optional arg with custom default logic
        if not WaypointName then
            local Counter = 1
            -- Find next available "pos1", "pos2", etc.
            while Waypoints['pos' .. Counter] do
                Counter = Counter + 1
            end
            WaypointName = 'pos' .. Counter
        end

        -- Get current position
        local Position = Root.Position

        -- Save to waypoints table (in-memory)
        -- Store as table for JSON serialization
        Waypoints[WaypointName] = {
            X = Position.X,
            Y = Position.Y,
            Z = Position.Z
        }

        -- Save to file (persistent)
        if SaveWaypoints() then
            -- Format coordinates for notification
            local CoordinateText = ('(%d, %d, %d)'):format(
                math.floor(Position.X),
                math.floor(Position.Y),
                math.floor(Position.Z)
            )
            Notify('Success', 'Waypoint Saved', ('Saved "%s" at %s'):format(WaypointName, CoordinateText))
        end
    end
})

-- Command 2: Delete Waypoint
RegisterCommand({
    Category = 'TELEPORT',
    Name = 'deletewaypoint',
    Args = {
        -- Required waypoint argument
        -- Uses our custom 'waypoint' type with dynamic suggestions
        {'waypoint', 'waypoint'}
    },
    Aliases = {'delwp'},
    Description = 'Deletes a saved waypoint',
    Execute = function(WaypointName)
        -- Check if waypoint exists
        if not Waypoints[WaypointName] then
            Notify('Error', 'Delete Waypoint', 'Waypoint does not exist')
            return
        end

        -- Remove from waypoints table (in-memory)
        Waypoints[WaypointName] = nil

        -- Save to file (update persistent storage)
        if SaveWaypoints() then
            Notify('Success', 'Waypoint Deleted', ('Deleted waypoint "%s"'):format(WaypointName))
        end
    end
})

-- Command 3: Goto Waypoint
RegisterCommand({
    Category = 'TELEPORT',
    Name = 'gotowaypoint',
    Args = {
        -- Required waypoint argument
        {'waypoint', 'waypoint'}
    },
    Aliases = {'gotowp'},
    Description = 'Teleports to a saved waypoint',
    Execute = function(WaypointName)
        -- Get local player's character information
        local Char, Root, Humanoid, Head, Part = GetLocalPlayerInfo()
        if not Root then
            Notify('Error', 'Goto Waypoint', 'Could not find your character\'s root part')
            return
        end

        -- Check if waypoint exists
        local Position = Waypoints[WaypointName]
        if not Position then
            Notify('Error', 'Goto Waypoint', 'Waypoint does not exist')
            return
        end

        -- Convert position table to Vector3
        -- Waypoints stored as {X, Y, Z} for JSON
        local TargetPosition = Vector3.new(Position.X, Position.Y, Position.Z)

        -- Teleport (instant, no animation)
        Root.CFrame = CFrame.new(TargetPosition)

        Notify('Success', 'Teleported', ('Teleporting to waypoint "%s"'):format(WaypointName))
    end
})

--/ Initialize /--
-- Load waypoints from file on startup
LoadWaypoints()

-- Confirmation message that plugin loaded successfully
-- Preferably, remove these unnecessary print statements when you're finished testing
print('[Tidecaller Plugin] waypoints example loaded successfully')
```

## Code Breakdown

Now let's break down the key sections to understand how they work:

### State Management

```lua
--/ Constants /--
local WAYPOINTS_FILE = 'waypoints.json'
local WAYPOINTS_FOLDER = 'tidecaller'

--/ State /--
local Waypoints = {}
```

**Why store as table?**
- Vector3 can't be directly JSON encoded
- Table with X, Y, Z is JSON-friendly
- Easy to reconstruct Vector3 when needed

### File Operations

```lua
local function LoadWaypoints()
    -- Ensure folder exists before trying to read
    if not isfolder(WAYPOINTS_FOLDER) then
        makefolder(WAYPOINTS_FOLDER)
    end

    local FilePath = WAYPOINTS_FOLDER .. '/' .. WAYPOINTS_FILE

    -- Check if file exists
    if not isfile(FilePath) then
        Waypoints = {}
        return
    end

    -- Try to load and parse the file
    local Success, Result = pcall(function()
        local FileContent = readfile(FilePath)
        return HttpService:JSONDecode(FileContent)
    end)

    if Success and type(Result) == 'table' then
        Waypoints = Result
        -- Count and log waypoints...
    else
        Waypoints = {}
        Notify('Warning', 'Waypoints Corrupted', 'Could not load waypoints file. Starting fresh.')
    end
end
```

**Error handling:**
- Check folder exists before read/write
- Use pcall to catch errors
- Validate loaded data is a table
- Provide user feedback on failure
- Log errors to console for debugging

### Dynamic Argument Type

```lua
RegisterArgType('waypoint', {
    Color = Colors.Mauve,

    GetSuggestions = function(Query, PreviousArgs)
        local Suggestions = {}

        -- Filter waypoints based on query
        -- This is DYNAMIC - updates as waypoints are added/deleted
        for WaypointName, Position in next, Waypoints do
            if Query == '' or WaypointName:lower():find(Query:lower(), 1, true) then
                Suggestions[#Suggestions + 1] = WaypointName
            end
        end

        table.sort(Suggestions, function(A, B)
            return A:lower() < B:lower()
        end)

        return Suggestions
    end,

    BuildPaletteItem = function(Suggestion)
        -- Creates a two-line display:
        -- Line 1: Waypoint name (bold, large)
        -- Line 2: Coordinates (monospace, small, dimmed)
        -- ...
    end
})
```

**Key difference from gotopoint:**
- Suggestions come from `Waypoints` table (dynamic)
- Updates in real-time as waypoints added/removed
- Sorted alphabetically for predictable order

### Auto-Generated Defaults

```lua
Args = {{'string', 'name', true}}

Execute = function(WaypointName)
    if not WaypointName then
        -- Custom logic to generate name
        local Counter = 1
        while Waypoints['pos' .. Counter] do
            Counter = Counter + 1
        end
        WaypointName = 'pos' .. Counter
    end

    -- Use WaypointName...
end
```

**Why not use fourth parameter?**
- Default would always be the same (e.g., "pos1")
- Custom logic generates unique names (pos1, pos2, pos3...)
- More user-friendly

## Key Concepts

### 1. Dynamic Argument Types

```lua
GetSuggestions = function(Query, PreviousArgs)
    local Suggestions = {}

    -- Loop through CURRENT waypoints
    for WaypointName, Position in next, Waypoints do
        if Query == '' or WaypointName:lower():find(Query:lower(), 1, true) then
            Suggestions[#Suggestions + 1] = WaypointName
        end
    end

    return Suggestions
end
```

**Dynamic vs Static:**
- **Static** (gotopoint): Suggestions from fixed list
- **Dynamic** (waypoints): Suggestions from changing data

### 2. File Persistence Pattern

```lua
-- Load on startup
LoadWaypoints()

-- Save after modifications
SaveWaypoints()
```

**Flow:**
1. Plugin loads -> LoadWaypoints()
2. User adds waypoint -> Update Waypoints -> SaveWaypoints()
3. User deletes waypoint -> Update Waypoints -> SaveWaypoints()
4. Next time -> LoadWaypoints() restores state

### 3. Auto-Generated Defaults

```lua
Args = {{'string', 'name', true}}

Execute = function(WaypointName)
    if not WaypointName then
        -- Custom logic to generate name
        local Counter = 1
        while Waypoints['pos' .. Counter] do
            Counter = Counter + 1
        end
        WaypointName = 'pos' .. Counter
    end

    -- Use WaypointName...
end
```

**Why not use fourth parameter?**
- Default would always be the same (e.g., "pos1")
- Custom logic generates unique names (pos1, pos2, pos3...)
- More user-friendly

### 4. Data Structure

**In-memory (Lua table):**
```lua
Waypoints = {
    spawn = {X = 0, Y = 10, Z = 0},
    shop = {X = 100, Y = 5, Z = 50}
}
```

**On disk (JSON):**
```json
{
    "spawn": {"X": 0, "Y": 10, "Z": 0},
    "shop": {"X": 100, "Y": 5, "Z": 50}
}
```

**Why table instead of Vector3?**
- Vector3 can't be JSON encoded
- Table is JSON-friendly
- Convert to/from Vector3 as needed

### 5. Error Recovery

```lua
local Success, Result = pcall(function()
    return HttpService:JSONDecode(readfile(FilePath))
end)

if Success and type(Result) == 'table' then
    Waypoints = Result
else
    Waypoints = {}
    Notify('Warning', 'Corrupted', 'Starting fresh')
end
```

**Handles:**
- File doesn't exist -> Empty table
- Invalid JSON -> Empty table + warning
- File permissions -> Empty table + warning
- Corrupted data -> Empty table + warning

## Usage Examples

### Save Current Position

```
savewaypoint spawn
```

Saves current position as "spawn".

### Auto-Generated Name

```
savewaypoint
```

Generates name "pos1" (or "pos2" if "pos1" exists, etc.).

### Teleport to Waypoint

```
gotowaypoint spawn
```

Or use alias:
```
gotowp spawn
```

### Delete Waypoint

```
deletewaypoint spawn
```

Or use alias:
```
delwp spawn
```

## File Structure

**Location:** `workspace/tidecaller/waypoints.json`

**Example file:**
```json
{
    "spawn": {
        "X": 0,
        "Y": 10,
        "Z": 0
    },
    "shop": {
        "X": 100,
        "Y": 5,
        "Z": 50
    },
    "pos1": {
        "X": -50,
        "Y": 20,
        "Z": 100
    }
}
```
