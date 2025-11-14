# Custom Argument Types

Creating custom argument types for your Tidecaller plugins.

## What are Argument Types?

Argument types define how command arguments behave:
- **Validation** - Ensure correct input format
- **Suggestions** - Show relevant options as user types
- **UI Display** - Rich visual presentation in palette
- **Type Safety** - Catch errors before execution

## Why Create Custom Types?

### Game-Specific Data
Create types for game-specific objects:
- Locations/zones in the game
- Items/weapons
- Teams or factions
- Types of NPCs or enemies

### Dynamic Suggestions
Provide context-aware suggestions for real-time data (similar to the player argument), or data created dynamically by the user, such as waypoints.

### Enhanced UX
Improve user experience with visual previews, so users can quickly understand the data they're selecting.

## Basic Structure

Every argument type requires two components, with two optional components for autocomplete:

```lua
RegisterArgType('typename', {
    -- Required
    Color = Colors.SomeColor,
    GetValue = function(Str)
        return Str  -- Or transformed value
    end,

    -- Optional (for autocomplete support)
    GetSuggestions = function(Query, PreviousArgs)
        return {'suggestion1', 'suggestion2'}
    end,
    BuildPaletteItem = function(Suggestion)
        local Padding = Create('UIPadding', {
            PaddingLeft = UDim.new(0, 12)
        })

        local Label = Create('TextLabel', {
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

### Required Components

#### 1. Color

The `Color` field defines the visual color in the UI:

```lua
-- Examples
Color = Colors.Blue
Color = Colors.Green
Color = Colors.Mauve
Color = Colors.Yellow
Color = Colors.Red
```

#### 2. GetValue

Validates and transforms string input into the actual value passed to the command:

```lua
GetValue = function(Str)
    -- Str: string - Raw user input
    -- Return: transformed value, or nil if invalid

    -- Example: Parse a number
    return tonumber(Str)
end
```

**Important:** Return `nil` if the input is invalid. This will cause an error notification to show.

### Optional Components (For Autocomplete)

#### 3. GetSuggestions

Returns an array of suggestions based on user input:

```lua
GetSuggestions = function(Query, PreviousArgs)
    -- Query: string - What user has typed
    -- PreviousArgs: table - Arguments already entered

    local Suggestions = {}
    -- Build your suggestions array
    return Suggestions
end
```

#### 4. BuildPaletteItem

Creates UI elements for displaying each suggestion:

```lua
BuildPaletteItem = function(Suggestion)
    -- Suggestion: string - One suggestion to display

    local Padding = Create('UIPadding', {
        PaddingLeft = UDim.new(0, 12)
    })

    local Label = Create('TextLabel', {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        FontFace = Fonts.Bold,
        Text = Suggestion,
        TextColor3 = Colors.Text,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center
    })

    -- Return value and UI elements
    return Suggestion, {Padding, Label}
end
```

**Return Values:**
1. **Value** - What gets stored as the argument value
2. **Elements** - Array of Instance objects to display

**Note:** If you omit `GetSuggestions` or `BuildPaletteItem`, autocomplete will not be available for this type. This is fine for types where autocomplete isn't necessary (like `number` or `string`).

## Simple Example: Boolean Without Autocomplete

```lua
RegisterArgType('boolean', {
    Color = Colors.Mauve,
    GetValue = function(Str)
        local Lower = Str:lower()
        if Lower == 't' or Lower == 'true' or Lower == '1' then
            return true
        elseif Lower == 'f' or Lower == 'false' or Lower == '0' then
            return false
        end
        return nil  -- Invalid input
    end
})
```

## Simple Example: Direction With Autocomplete

Let's create a basic `direction` type with autocomplete:

```lua
RegisterArgType('direction', {
    Color = Colors.Sky,
    GetValue = function(Str)
        -- Validate the direction
        local Directions = {'North', 'South', 'East', 'West'}
        for I = 1, #Directions do
            if Directions[I]:lower() == Str:lower() then
                return Directions[I]
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

**Usage in command:**
```lua
RegisterCommand({
    Category = 'MOVEMENT',
    Name = 'move',
    Args = {{'direction', 'dir'}, {'number', 'distance'}},
    Aliases = {},
    Description = 'Move in a direction',
    Execute = function(Direction, Distance)
        -- Direction will be 'North', 'South', 'East', or 'West'
        -- Distance will be a number
    end
})
```

## Advanced GetValue Techniques

### Type Validation

```lua
GetValue = function(Str)
    local Num = tonumber(Str)

    -- Validate range
    if Num and Num >= 0 and Num <= 100 then
        return Num
    end

    return nil  -- Out of range or not a number
end
```

### Enum Validation

```lua
GetValue = function(Str)
    -- Validate the keycode exists
    local Success = pcall(function()
        local _ = Enum.KeyCode[Str]
    end)
    if Success then
        return Str
    end
    return nil
end
```

### Object Resolution

```lua
GetValue = function(Str)
    -- Let's pretend we have some function that gets some Instance or Object by its name
    local Object = FindObjectByName(Str)
    if Object then
        return Object
    end
    return nil
end
```

## Advanced GetSuggestions Techniques

### Filtering by Query

Always filter suggestions based on user input:

```lua
GetSuggestions = function(Query, PreviousArgs)
    local AllItems = {'Apple', 'Banana', 'Cherry', 'Date'}
    local Filtered = {}

    local QueryLower = Query:lower()

    for I = 1, #AllItems do
        local Item = AllItems[I]
        -- Case-insensitive substring match
        if QueryLower == '' or Item:lower():find(QueryLower, 1, true) then
            Filtered[#Filtered + 1] = Item
        end
    end

    return Filtered
end
```

### Using PreviousArgs

Access previously entered arguments for context:

```lua
GetSuggestions = function(Query, PreviousArgs)
    -- PreviousArgs[1] = first argument value
    -- PreviousArgs[2] = second argument value, etc.

    local FirstArg = PreviousArgs[1]

    if FirstArg == 'weapon' then
        return {'Sword', 'Bow', 'Staff'}
    elseif FirstArg == 'armor' then
        return {'Helmet', 'Chestplate', 'Boots'}
    else
        return {'weapon', 'armor'}
    end
end
```

### Dynamic Game Data

Pull suggestions from game state:

```lua
GetSuggestions = function(Query, PreviousArgs)
    local Workspace = game:GetService('Workspace')
    local Suggestions = {}

    -- Get all parts in workspace
    local Parts = Workspace:GetChildren()
    for I = 1, #Parts do
        local Part = Parts[I]
        if Part:IsA('BasePart') then
            local Name = Part.Name
            if Query == '' or Name:lower():find(Query:lower(), 1, true) then
                Suggestions[#Suggestions + 1] = Name
            end
        end
    end

    return Suggestions
end
```

### Sorting Suggestions

Provide consistent ordering:

```lua
GetSuggestions = function(Query, PreviousArgs)
    local Items = {'Zebra', 'Apple', 'Mango', 'Banana'}
    local Filtered = {}

    -- Filter
    for I = 1, #Items do
        local Item = Items[I]
        if Query == '' or Item:lower():find(Query:lower(), 1, true) then
            Filtered[#Filtered + 1] = Item
        end
    end

    -- Sort alphabetically
    table.sort(Filtered, function(A, B)
        return A:lower() < B:lower()
    end)

    return Filtered
end
```

## Advanced BuildPaletteItem Techniques

### Simple Label (Recommended)

Most types should use a simple padding + label pattern:

```lua
BuildPaletteItem = function(Suggestion)
    local Padding = Create('UIPadding', {
        PaddingLeft = UDim.new(0, 12)
    })

    local Label = Create('TextLabel', {
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
```

### Multi-line Layout

Create rich displays with multiple text elements:

```lua
BuildPaletteItem = function(Suggestion)
    local Padding = Create('UIPadding', {
        PaddingLeft = UDim.new(0, 12)
    })

    -- Main label (top 60%)
    local MainLabel = Create('TextLabel', {
        Name = 'MainLabel',
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

    -- Subtitle (bottom 40%)
    local SubLabel = Create('TextLabel', {
        Name = 'SubLabel',
        Size = UDim2.new(1, 0, 0.4, 0),
        Position = UDim2.new(0, 0, 0.6, 0),
        BackgroundTransparency = 1,
        FontFace = MonoFonts.Regular,
        Text = 'Additional info here',
        TextColor3 = Colors.Subtext1,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center
    })

    return Suggestion, {Padding, MainLabel, SubLabel}
end
```

### With Coordinates

Display position data using monospace fonts:

```lua
BuildPaletteItem = function(Suggestion)
    -- Assume Suggestion is a waypoint name
    local Position = Waypoints[Suggestion]  -- Get position data

    local Padding = Create('UIPadding', {
        PaddingLeft = UDim.new(0, 12)
    })

    local NameLabel = Create('TextLabel', {
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

    -- Format coordinates
    local CoordText = ('(%d, %d, %d)'):format(
        math.floor(Position.X),
        math.floor(Position.Y),
        math.floor(Position.Z)
    )

    local CoordLabel = Create('TextLabel', {
        Size = UDim2.new(1, 0, 0.4, 0),
        Position = UDim2.new(0, 0, 0.6, 0),
        BackgroundTransparency = 1,
        FontFace = MonoFonts.Regular,
        Text = CoordText,
        TextColor3 = Colors.Subtext1,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center
    })

    return Suggestion, {Padding, NameLabel, CoordLabel}
end
```

## Performance Considerations

### Keep GetSuggestions Fast

```lua
-- Bad: Expensive operation
GetSuggestions = function(Query, PreviousArgs)
    local Suggestions = {}

    -- Searching entire workspace every frame!
    for _, Descendant in ipairs(game:GetDescendants()) do
        -- This is too slow!
    end

    return Suggestions
end

-- Good: Cache expensive operations
local CachedItems = {}
local LastCacheTime = 0

GetSuggestions = function(Query, PreviousArgs)
    -- Refresh cache every 5 seconds
    if tick() - LastCacheTime > 5 then
        CachedItems = GetExpensiveData()
        LastCacheTime = tick()
    end

    -- Filter cached items (fast)
    local Filtered = {}
    for I = 1, #CachedItems do
        if CachedItems[I]:lower():find(Query:lower(), 1, true) then
            Filtered[#Filtered + 1] = CachedItems[I]
        end
    end

    return Filtered
end
```

### Avoid Heavy UI

```lua
-- Bad: Creating many objects per item
BuildPaletteItem = function(Suggestion)
    local Elements = {}

    -- Creating 20+ UI objects per suggestion
    for I = 1, 20 do
        Elements[#Elements + 1] = Create('Frame', {...})
    end

    return Suggestion, Elements
end

-- Good: Minimal UI objects
BuildPaletteItem = function(Suggestion)
    local Padding = Create('UIPadding', {
        PaddingLeft = UDim.new(0, 12)
    })

    local Label = Create('TextLabel', {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        FontFace = Fonts.Bold,
        Text = Suggestion,
        TextColor3 = Colors.Text,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center
    })

    -- Only 2 objects
    return Suggestion, {Padding, Label}
end
```

## Common Patterns

### Enum-like Types Without Autocomplete

```lua
RegisterArgType('myenum', {
    Color = Colors.Blue,
    GetValue = function(Str)
        local Options = {'Option1', 'Option2', 'Option3'}
        for I = 1, #Options do
            if Options[I]:lower() == Str:lower() then
                return Options[I]
            end
        end
        return nil
    end
})
```

### Enum-like Types With Autocomplete

```lua
local Options = {'Option1', 'Option2', 'Option3'}

RegisterArgType('myenum', {
    Color = Colors.Blue,
    GetValue = function(Str)
        for I = 1, #Options do
            if Options[I]:lower() == Str:lower() then
                return Options[I]
            end
        end
        return nil
    end,
    GetSuggestions = function(Query, PreviousArgs)
        local Filtered = {}
        for I = 1, #Options do
            if Query == '' or Options[I]:lower():find(Query:lower(), 1, true) then
                Filtered[#Filtered + 1] = Options[I]
            end
        end
        return Filtered
    end,
    BuildPaletteItem = function(Suggestion)
        local Padding = Create('UIPadding', {
            PaddingLeft = UDim.new(0, 12)
        })

        local Label = Create('TextLabel', {
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

### File-based Types

Load from saved data:

```lua
local SavedData = {}

-- Load on startup
if isfile('mydata.json') then
    SavedData = HttpService:JSONDecode(readfile('mydata.json'))
end

RegisterArgType('saveditem', {
    Color = Colors.Mauve,
    GetValue = function(Str)
        if SavedData[Str] then
            return Str
        end
        return nil
    end,
    GetSuggestions = function(Query, PreviousArgs)
        local Items = {}
        for Name, Data in next, SavedData do
            if Query == '' or Name:lower():find(Query:lower(), 1, true) then
                Items[#Items + 1] = Name
            end
        end
        return Items
    end,
    BuildPaletteItem = function(Suggestion)
        local Padding = Create('UIPadding', {
            PaddingLeft = UDim.new(0, 12)
        })

        local Label = Create('TextLabel', {
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
