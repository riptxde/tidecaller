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

--/ Commands /--
RegisterCommand({
    Category = 'TELEPORT',
    Name = 'tgoto',
    Args = {
        -- Argument of type 'player' with name 'target'
        -- The third and fourth arguments are omitted which means this is a required argument with no default value
        {'player', 'target'}
    },
    Aliases = {},
    Description = 'Teleports your character to the target player',
    Execute = function(TargetPlayer)
        -- Get local player's character information
        local Char, Root, Humanoid, Head, Part = GetLocalPlayerInfo()
        if not Root then
            Notify('Error', 'Tween Goto', 'Could not find your character\'s root part')
            return
        end

        -- Get target player's character information
        local Player, PChar, PRoot, PHumanoid, PHead, PPart = GetTargetPlayerInfo(TargetPlayer)
        if not PPart then
            Notify('Error', 'Tween Goto', 'Could not find a valid part in the target player\'s character')
            return
        end

        -- Create smooth tween to target position
        local TweenInfo = TweenInfo.new(
            0.5, -- Duration (0.5 seconds)
            Enum.EasingStyle.Quad, -- Easing style
            Enum.EasingDirection.Out -- Easing direction
        )

        local Goal = {CFrame = PRoot.CFrame}
        local Tween = TweenService:Create(Root, TweenInfo, Goal)

        Tween:Play()

        Notify('Success', 'Teleported', ('Teleporting to %s'):format(Player.DisplayName))
    end
})

-- Preferably, remove unnecessary prints when you're done. This is just helpful to know that the plugin loaded successfully
print('[Tidecaller Plugin] tgoto example loaded successfully')
