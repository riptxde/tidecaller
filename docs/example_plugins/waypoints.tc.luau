--[[
    Example Plugin: Waypoints System (waypoints)

    This plugin demonstrates:
    - Creating a complex custom argument type with dynamic data
    - Having an optional argument, but having custom logic for the default value
    - Command aliases

    Commands:
    - savewaypoint <name> (alias: savewp) - Saves your current position as a waypoint
    - deletewaypoint <waypoint> (alias: delwp) - Deletes a saved waypoint
    - gotowaypoint <waypoint> (alias: gotowp) - Teleports to a saved waypoint
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
local RegisterCategory = G.Tidecaller.RegisterCategory
local GetLocalPlayerInfo = G.Tidecaller.GetLocalPlayerInfo
local GetTargetPlayerInfo = G.Tidecaller.GetTargetPlayerInfo
local Colors = G.Tidecaller.Colors
local Fonts = G.Tidecaller.Fonts
local MonoFonts = G.Tidecaller.MonoFonts
local Notify = G.Tidecaller.Notify

--/ Services /--
local HttpService = game:GetService('HttpService')
local TweenService = game:GetService('TweenService')

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

--/ Constants /--
local WAYPOINTS_FILE = 'waypoints.json'
local WAYPOINTS_FOLDER = 'tidecaller'

--/ State /--
local Waypoints = {} -- {[name] = {X = number, Y = number, Z = number}}

--/ File Operations /--
local function LoadWaypoints()
    -- Ensure folder exists
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

        local WaypointsCount = 0
        for _, Waypoint in next, Waypoints do
            WaypointsCount = WaypointsCount + 1
        end

        print(('[Tidecaller Waypoints] Loaded %d waypoints'):format(WaypointsCount))
    else
        Waypoints = {}
        Notify('Warning', 'Waypoints Corrupted', 'Could not load waypoints file. Starting fresh.')
        print('[Tidecaller Waypoints] Failed to load waypoints:', Result)
    end
end

local function SaveWaypoints()
    -- Ensure folder exists
    if not isfolder(WAYPOINTS_FOLDER) then
        makefolder(WAYPOINTS_FOLDER)
    end

    local FilePath = WAYPOINTS_FOLDER .. '/' .. WAYPOINTS_FILE

    -- Try to save the file
    local Success, Error = pcall(function()
        local JsonData = HttpService:JSONEncode(Waypoints)
        writefile(FilePath, JsonData)
    end)

    if not Success then
        Notify('Error', 'Save Failed', 'Could not save waypoints to file')
        print('[Tidecaller Waypoints] Failed to save waypoints:', Error)
        return false
    end

    return true
end

--/ Custom Argument Types /--
RegisterArgType('waypoint', {
    Color = Colors.Mauve, -- Use mauve for waypoint-related items
    GetSuggestions = function(Query, PreviousArgs)
        local Suggestions = {}

        -- Filter waypoints based on query
        for WaypointName, Position in next, Waypoints do
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
    BuildPaletteItem = function(Suggestion)
        -- Create padding for the item
        local Padding = Create('UIPadding', {
            PaddingLeft = UDim.new(0, 12)
        })

        -- Create main label for waypoint name
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

        -- Create smaller label for coordinates
        local Position = Waypoints[Suggestion]
        local CoordinateText = ('(%d, %d, %d)'):format(
            math.floor(Position.X),
            math.floor(Position.Y),
            math.floor(Position.Z)
        )

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
RegisterCommand({
    Category = 'TELEPORT',
    Name = 'savewaypoint',
    Args = {
        -- Argument of type 'string', with name 'name', optional: true
        -- Since the fourth argument (the default value), is not provided, then it defaults to nil, and you can set the value yourself in the code
        -- Here, we have the code automatically generate a name (pos1, pos2, etc.) if the value is nil
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
        if not WaypointName then
            local Counter = 1
            while Waypoints['pos' .. Counter] do
                Counter = Counter + 1
            end
            WaypointName = 'pos' .. Counter
        end

        -- Get current position
        local Position = Root.Position

        -- Save to waypoints table
        Waypoints[WaypointName] = {
            X = Position.X,
            Y = Position.Y,
            Z = Position.Z
        }

        -- Save to file
        if SaveWaypoints() then
            local CoordinateText = ('(%d, %d, %d)'):format(
                math.floor(Position.X),
                math.floor(Position.Y),
                math.floor(Position.Z)
            )
            Notify('Success', 'Waypoint Saved', ('Saved "%s" at %s'):format(WaypointName, CoordinateText))
        end
    end
})

RegisterCommand({
    Category = 'TELEPORT',
    Name = 'deletewaypoint',
    Args = {
        -- Argument of type 'waypoint', with name 'waypoint'
        -- The third and fourth arguments are omitted which means this is a required argument with no default value
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

        -- Remove from waypoints table
        Waypoints[WaypointName] = nil

        -- Save to file
        if SaveWaypoints() then
            Notify('Success', 'Waypoint Deleted', ('Deleted waypoint "%s"'):format(WaypointName))
        end
    end
})

RegisterCommand({
    Category = 'TELEPORT',
    Name = 'gotowaypoint',
    Args = {
        -- Argument of type 'waypoint', with name 'waypoint'
        -- The third and fourth arguments are omitted which means this is a required argument with no default value
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
        local TargetPosition = Vector3.new(Position.X, Position.Y, Position.Z)

        Root.CFrame = CFrame.new(TargetPosition)

        Notify('Success', 'Teleported', ('Teleporting to waypoint "%s"'):format(WaypointName))
    end
})

--/ Initialize /--
LoadWaypoints()

-- Preferably, remove unnecessary prints when you're done. This is just helpful to know that the plugin loaded successfully
print('[Tidecaller Plugin] waypoints example loaded successfully')
