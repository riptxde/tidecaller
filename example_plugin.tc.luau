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
local Notify = G.Tidecaller.Notify

--/ Services /--
local Players = game:GetService('Players')

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

--/ Custom Argument Type: Animation /--
RegisterArgType('animation', {
    Color = Colors.Mauve,
    GetValue = function(Str)
        -- Return the animation name as-is
        return Str
    end,
    GetSuggestions = function(Query, PreviousArgs)
        -- Complex animation names to test escaping:
        -- 1. Names with spaces
        -- 2. Names with single quotes
        -- 3. Names with double quotes
        -- 4. Names with both quotes and spaces
        local Animations = {
            'Breakdance',                           -- Simple name
            'Rat Dance',                            -- Name with space
            "Bob's Shuffle",                        -- Name with single quote
            'The "Cool" Move',                      -- Name with double quotes
            'My Friend\'s Dance',                   -- Name with escaped single quote
            'Say "Hello World"',                    -- Name with double quotes and space
            'It\'s "The Best" Move',                -- Name with both quotes and spaces
            'Dance \\o/ Emote',                     -- Name with backslashes
            'Multi  Space  Dance',                  -- Name with multiple spaces
        }

        local Filtered = {}
        local LowerQuery = Query:lower()

        for I = 1, #Animations do
            local Animation = Animations[I]
            if LowerQuery == '' or Animation:lower():find(LowerQuery, 1, true) then
                Filtered[#Filtered + 1] = Animation
            end
        end

        return Filtered
    end,
    BuildPaletteItem = function(AnimName)
        -- Use exposed Colors and Fonts from Tidecaller API
        local FontBold = Fonts.FontBold

        -- Create UI elements
        local Padding = Create('UIPadding', {
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12)
        })

        local Label = Create('TextLabel', {
            Name = 'AnimName',
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            FontFace = FontBold,
            Text = AnimName,
            TextColor3 = Colors.Text,
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center
        })

        -- Return the value to store and children to parent to base item
        return AnimName, {Padding, Label}
    end
})

--/ Commands /--
RegisterCommand({
    Category = 'FUN',
    Name = 'anim',
    Args = {{'animation', 'animation'}},
    Aliases = {'animate', 'dance'},
    Description = 'Play an animation (tests quote escaping)',
    Execute = function(AnimName)
        print('Playing animation:', AnimName)
        print('Animation type:', type(AnimName))
        print('Animation length:', #AnimName)

        -- Show a notification with the animation name
        if Notify then
            Notify('Success', 'Animation Selected', ('Playing: %s'):format(AnimName))
        end
    end
})

RegisterCommand({
    Category = 'FUN',
    Name = 'animtest',
    Args = {{'animation', 'first'}, {'animation', 'second'}},
    Aliases = {},
    Description = 'Test multiple animation arguments with escaping',
    Execute = function(FirstAnim, SecondAnim)
        print('First animation:', FirstAnim)
        print('Second animation:', SecondAnim)

        if Notify then
            Notify(
                'Info',
                'Animation Test',
                ('First: %s\nSecond: %s'):format(FirstAnim, SecondAnim)
            )
        end
    end
})

print('[Tidecaller Plugin] Animation commands loaded successfully')
