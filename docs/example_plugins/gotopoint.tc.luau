--[[
    Example Plugin: Go to Point (gotopoint)

    This plugin demonstrates:
    - Creating a simple custom argument type
    - Having a default value for an optional argument
    - Building palette items with multiple UI elements

    Commands:
    - gotopoint <point> - Teleports your character to a predefined point
    - Defaults to "Point A"
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

--/ Predefined Points /--
local Points = {
    ['Point A'] = Vector3.new(100, 0, 0),
    ['Point B'] = Vector3.new(-100, 0, 0),
    ['Point C'] = Vector3.new(0, 0, 0)
}

--/ Custom Argument Types /--
RegisterArgType('point', {
    Color = Colors.Green, -- Using green to indicate location/position
    GetSuggestions = function(Query, PreviousArgs)
        local Suggestions = {}

        -- Filter points based on query
        for PointName, Position in next, Points do
            if Query == '' or PointName:lower():find(Query:lower(), 1, true) then
                Suggestions[#Suggestions + 1] = PointName
            end
        end

        return Suggestions
    end,
    BuildPaletteItem = function(Suggestion)
        -- Create padding for the item
        local Padding = Create('UIPadding', {
            PaddingLeft = UDim.new(0, 12)
        })

        -- Create main label for point name
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
        local Position = Points[Suggestion]
        local CoordinateText = ('(%d, %d, %d)'):format(Position.X, Position.Y, Position.Z)

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
    Name = 'gotopoint',
    Args = {
        -- Argument of type 'point', with name 'point_name', optional: true, defaults to "Point A"
        {'point', 'point_name', true, 'Point A'}
    },
    Aliases = {},
    Description = 'Teleports your character to a predefined point',
    Execute = function(PointName)
        -- Get local player's character information
        local Char, Root, Humanoid, Head, Part = GetLocalPlayerInfo()
        if not Root then
            Notify('Error', 'Goto Point', 'Could not find your character\'s root part')
            return
        end

        -- Get the position for the selected point
        local Position = Points[PointName]
        if not Position then
            Notify('Error', 'Goto Point', 'Could not find the specified point')
            return
        end

        Root.CFrame = CFrame.new(Position)

        Notify('Success', 'Goto Point', ('Teleporting to %s'):format(PointName))
    end
})

-- Preferably, remove unnecessary prints when you're done. This is just helpful to know that the plugin loaded successfully
print('[Tidecaller Plugin] gotopoint example loaded successfully')
