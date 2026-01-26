# Example: gotopoint (Custom Argument Type)

A plugin demonstrating custom argument types by teleporting to predefined points.

## Overview

**File:** `gotopoint.tc.luau`

### What It Does

Creates a `gotopoint` command that:
1. Defines several predefined teleport points
2. Creates a custom `point` argument type
3. Shows rich UI with coordinates
4. Uses a default value ("Point A")
5. Teleports to the selected point

### What You'll Learn

- Creating custom argument types
- RegisterArgType structure
- GetSuggestions function
- BuildPaletteItem with multi-line layout
- Using Fonts and MonoFonts
- Color selection for types
- Default argument values
- Static suggestion lists
- UI padding and layout

## Complete Code with Annotations

```lua
--[[
    Example Plugin: Go to Point (gotopoint)

    This plugin demonstrates:
    - Creating a simple custom argument type
    - Having a default value for an optional argument
    - Building palette items with multiple UI elements

    Commands:
    - gotopoint <point: Point A> - Teleports your character to a predefined point
      (Defaults to "Point A" if no argument provided)
]]

--[[
    --/ Boilerplate /--

    This section contains the boilerplate code for the Tidecaller plugin
    Please include it in your plugin
]]
local G = type(getgenv) == 'function' and getgenv() or (_G or {})

repeat task.wait() until G.Tidecaller and G.Tidecaller.Loaded

local RegisterArgType = G.Tidecaller.RegisterArgType
local RegisterCommand = G.Tidecaller.RegisterCommand
local GetLocalPlayerInfo = G.Tidecaller.GetLocalPlayerInfo
local GetTargetPlayerInfo = G.Tidecaller.GetTargetPlayerInfo
local Colors = G.Tidecaller.Colors
local Fonts = G.Tidecaller.Fonts
local MonoFonts = G.Tidecaller.MonoFonts
local Notify = G.Tidecaller.Notify

--/ Services /--
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

--/ Predefined Points /--
-- Dictionary mapping point names to Vector3 positions
-- In a real plugin, these might be game-specific locations
local Points = {
    ['Point A'] = Vector3.new(100, 0, 0),   -- East
    ['Point B'] = Vector3.new(-100, 0, 0),  -- West
    ['Point C'] = Vector3.new(0, 0, 0)      -- Origin
}

--/ Custom Argument Types /--
RegisterArgType('point', {
    -- Color: Defines the visual color in the UI
    -- Using Green to indicate location/position
    -- Choose colors that match semantic meaning
    Color = Colors.Green,

    -- GetSuggestions: Returns array of suggestions based on user input
    -- Called every time the user types
    -- Must be FAST (< 100ms)
    GetSuggestions = function(Query, PreviousArgs)
        -- Query: string - What the user has typed so far
        -- PreviousArgs: table - Previously entered arguments (not used here)

        local Suggestions = {}

        -- Filter points based on query
        -- Case-insensitive substring matching
        for PointName, Position in next, Points do
            -- Show all points if query is empty
            -- Otherwise, check if point name contains the query
            if Query == '' or PointName:lower():find(Query:lower(), 1, true) then
                Suggestions[#Suggestions + 1] = PointName
            end
        end

        return Suggestions
    end,

    -- BuildPaletteItem: Creates UI elements for displaying a suggestion
    -- Called for each suggestion that needs to be displayed
    -- Returns: value (what gets passed to command), {children (UI elements)}
    BuildPaletteItem = function(Suggestion)
        -- Suggestion: string - One of the suggestions from GetSuggestions

        -- Create padding for the item
        -- Adds left padding so text doesn't touch the edge
        local Padding = Create('UIPadding', {
            PaddingLeft = UDim.new(0, 12)  -- 12 pixels from left
        })

        -- Create main label for point name (top 60% of item)
        local Label = Create('TextLabel', {
            Name = 'Label',
            Size = UDim2.new(1, 0, 0.6, 0),  -- Full width, 60% height
            Position = UDim2.new(0, 0, 0, 0), -- Top-left corner
            BackgroundTransparency = 1,        -- Invisible background
            FontFace = Fonts.Bold,             -- Bold font for emphasis
            Text = Suggestion,                 -- Display the point name
            TextColor3 = Colors.Text,          -- Primary text color from theme
            TextSize = 16,                     -- Larger text for main label
            TextXAlignment = Enum.TextXAlignment.Left,   -- Left-aligned
            TextYAlignment = Enum.TextYAlignment.Center  // Vertically centered
        })

        -- Get the position for this point from our Points dictionary
        local Position = Points[Suggestion]

        -- Format coordinates as (X, Y, Z) with no decimal places
        local CoordinateText = ('(%d, %d, %d)'):format(Position.X, Position.Y, Position.Z)

        -- Create smaller label for coordinates (bottom 40% of item)
        local CoordinateLabel = Create('TextLabel', {
            Name = 'CoordinateLabel',
            Size = UDim2.new(1, 0, 0.4, 0),    // Full width, 40% height
            Position = UDim2.new(0, 0, 0.5, 0), // Start at 50% down (below main label)
            BackgroundTransparency = 1,          // Invisible background
            FontFace = MonoFonts.Regular,        // Monospace font for coordinates
            Text = CoordinateText,               // Display formatted coordinates
            TextColor3 = Colors.Subtext1,        // Dimmer text color for secondary info
            TextSize = 12,                       // Smaller text for subtitle
            TextXAlignment = Enum.TextXAlignment.Left,   // Left-aligned
            TextYAlignment = Enum.TextYAlignment.Center  // Vertically centered
        })

        -- Return the value and UI elements
        // Value: What gets passed to the command (same as Suggestion here)
        // Elements: Array of Instances to parent to the palette item
        return Suggestion, {Padding, Label, CoordinateLabel}
    end
})

--/ Commands /--
RegisterCommand({
    Category = 'TELEPORT',
    Name = 'gotopoint',

    Args = {
        -- Argument of type 'point', with name 'point_name'
        // Third parameter: true = optional argument
        // Fourth parameter: 'Point A' = default value
        // User will see: <point_name: Point A>
        // If omitted, command receives 'Point A'
        {'point', 'point_name', true, 'Point A'}
    },

    Aliases = {},
    Description = 'Teleports your character to a predefined point',

    Execute = function(PointName)
        // PointName will be 'Point A' if user didn't provide an argument
        // Otherwise, it's the point name the user selected

        -- Get local player's character information
        local Char, Root, Humanoid, Head, Part = GetLocalPlayerInfo()

        // Always validate before using
        if not Root then
            Notify('Error', 'Goto Point', 'Could not find your character\'s root part')
            return
        end

        -- Get the position for the selected point from our dictionary
        local Position = Points[PointName]

        // Validate that the point exists
        // (Should always exist since suggestions come from Points dictionary)
        if not Position then
            Notify('Error', 'Goto Point', 'Could not find the specified point')
            return
        end

        -- Teleport instantly (no animation in this example)
        // CFrame.new creates a CFrame at the position with no rotation
        Root.CFrame = CFrame.new(Position)

        -- Show success notification with point name
        Notify('Success', 'Goto Point', ('Teleporting to %s'):format(PointName))
    end
})

-- Confirmation that plugin loaded
-- Preferably, remove these unnecessary print statements when you're finished testing
print('[Tidecaller Plugin] gotopoint example loaded successfully')
```

## Code Breakdown

### 1. Predefined Points

```lua
local Points = {
    ['Point A'] = Vector3.new(100, 0, 0),
    ['Point B'] = Vector3.new(-100, 0, 0),
    ['Point C'] = Vector3.new(0, 0, 0)
}
```

**Dictionary structure:**
- Keys: Point names (strings)
- Values: Vector3 positions

**Why?**
- Easy to look up position by name
- Easy to add/remove points
- Can iterate with `for Name, Pos in next, Points`

### 2. RegisterArgType Structure

```lua
RegisterArgType('typename', {
    Color = Colors.SomeColor,
    GetSuggestions = function(Query, PreviousArgs)
        return {}
    end,
    BuildPaletteItem = function(Suggestion)
        return Suggestion, {}
    end
})
```

**Three required fields:**
- **Color** - Visual color in UI
- **GetSuggestions** - Returns suggestion array
- **BuildPaletteItem** - Creates UI for each suggestion

### 3. GetSuggestions Implementation

```lua
GetSuggestions = function(Query, PreviousArgs)
    local Suggestions = {}

    for PointName, Position in next, Points do
        if Query == '' or PointName:lower():find(Query:lower(), 1, true) then
            Suggestions[#Suggestions + 1] = PointName
        end
    end

    return Suggestions
end
```

**Flow:**
1. Create empty suggestions array
2. Loop through all points
3. Check if point name matches query (case-insensitive)
4. Add matching points to suggestions
5. Return suggestions array

**Filtering:**
- Empty query (`''`) - Show all points
- Has query - Show only matching points
- Uses `string:find` for substring matching
- Fourth parameter `true` = plain text search (faster)

### 4. BuildPaletteItem Multi-line Layout

```lua
BuildPaletteItem = function(Suggestion)
    local Padding = Create('UIPadding', {...})

    -- Main label (60% height, top)
    local Label = Create('TextLabel', {
        Size = UDim2.new(1, 0, 0.6, 0),
        Position = UDim2.new(0, 0, 0, 0),
        ...
    })

    -- Subtitle (40% height, bottom)
    local CoordLabel = Create('TextLabel', {
        Size = UDim2.new(1, 0, 0.4, 0),
        Position = UDim2.new(0, 0, 0.5, 0),  -- Start at 50% down
        ...
    })

    return Suggestion, {Padding, Label, CoordLabel}
end
```

**Layout technique:**
- Main label: 60% height, position Y = 0
- Subtitle: 40% height, position Y = 0.5 (50% down)
- Together they fill 100% of the item height

**Visual result:**
```
┌─────────────────────┐
│ Point A             │ <- Main label (60%)
│ (100, 0, 0)         │ <- Subtitle (40%)
└─────────────────────┘
```

### 5. Using Fonts and MonoFonts

```lua
-- Main label: Bold font for emphasis
FontFace = Fonts.Bold,

-- Coordinate label: Monospace for aligned numbers
FontFace = MonoFonts.Regular,
```

**Why monospace for coordinates?**
- All digits have same width
- Numbers align properly
- Looks cleaner and more technical

**Comparison:**
```
Regular font:
(1, 1, 1)
(100, 100, 100)

Monospace font:
(  1,   1,   1)
(100, 100, 100)
```

### 6. Using Theme Colors

```lua
-- Type color
Color = Colors.Green,

-- Main text
TextColor3 = Colors.Text,

-- Secondary text (dimmer)
TextColor3 = Colors.Subtext1,
```

**Benefits:**
- Consistent with theme
- Updates when theme changes
- Semantic color choices

### 7. Default Argument Value

```lua
Args = {
    {'point', 'point_name', true, 'Point A'}
}
```

**Format:** `{type, name, optional, default}`

**What user sees:**
```
gotopoint <point_name: Point A>
```

**Behavior:**
- No argument provided -> `PointName = 'Point A'`
- Argument provided -> `PointName = user's choice`

## Usage Examples

### Using Default

```
gotopoint
```

Teleports to "Point A" (the default).

### Selecting a Point

```
gotopoint "Point B"
```

Teleports to "Point B".

### Autocomplete

1. Type: `gotopoint`
2. Palette shows all points with coordinates
3. Type: `p` - Filters to points containing "p"
4. Select with arrow keys + Enter
