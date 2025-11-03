--/ Config /--
local PREFIX, HOTKEY = ';', 'Semicolon'

--/ Globals /--
local INF = 1 / 0
local wait, spawn, delay = task.wait, task.spawn, task.delay
local G = type(getgenv) == 'function' and getgenv() or (_G or {})
local _C, C = {}, {} -- Create a table named C for weak references to objects that should be discarded once no longer needed
setmetatable(C, _C)
_C.__mode = 'k'

if G.Tidecaller then
    local Error = 'Tidecaller is already running'
    G.Tidecaller.Notify('Error', 'Failed to Load', Error)
    error(Error)
end

G.Tidecaller = { -- API functions and resources to be set later
    Notify = nil,
    Colors = nil,
    Fonts = nil,
    RegisterArgType = nil,
    RegisterCommand = nil,
    RegisterCategory = nil,
    Loaded = false,
}

--/ Services /--
if not game.Loaded then
	game.Loaded:Wait()
end

local HttpService = game:GetService('HttpService')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local UserInputService = game:GetService('UserInputService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local CoreGui = game:GetService('CoreGui')
local Players = game:GetService('Players')

--/ Objects /--
local LP = Players.LocalPlayer
local Stepped = RunService.Stepped
local RenderStepped = RunService.RenderStepped
local Heartbeat = RunService.Heartbeat
local Rand = Random.new()

while not LP do
    Players.PlayerAdded:Wait()
    LP = Players.LocalPlayer
end

--/ Generic Helper Functions /--

-- Parse command input with support for quoted arguments
local function ParseCommandInput(Input)
    -- Returns: CompletedParts, CurrentArgIndex, CurrentArgText, InQuote
    -- CompletedParts: Table of fully parsed arguments (doesn't include CurrentArgText)
    -- CurrentArgIndex: The index of the argument being typed (0 means typing command name)
    -- CurrentArgText: The text of the current argument being typed
    -- InQuote: Whether we're currently inside an unclosed quote

    local CompletedParts = {}
    local CurrentPart = ''
    local InQuote = false
    local QuoteChar = nil
    local IsEscaped = false

    for I = 1, #Input do
        local Char = Input:sub(I, I)

        if IsEscaped then
            -- Previous character was backslash - add this character literally
            CurrentPart = CurrentPart .. Char
            IsEscaped = false
        elseif Char == '\\' then
            -- Escape next character
            IsEscaped = true
        elseif not InQuote and (Char == '"' or Char == "'") then
            -- Start a quoted section
            InQuote = true
            QuoteChar = Char
        elseif InQuote and Char == QuoteChar then
            -- End the quoted section
            InQuote = false
            QuoteChar = nil
        elseif not InQuote and Char == ' ' then
            -- Space outside quotes - finish current part
            if #CurrentPart > 0 then
                CompletedParts[#CompletedParts + 1] = CurrentPart
                CurrentPart = ''
            end
        else
            -- Regular character - add to current part
            CurrentPart = CurrentPart .. Char
        end
    end

    -- Determine current state
    local EndsWithSpace = #Input > 0 and Input:sub(#Input, #Input) == ' ' and not InQuote
    local CurrentArgIndex
    local CurrentArgText

    if EndsWithSpace then
        -- Just finished typing an argument - save it and start new one
        if #CurrentPart > 0 then
            CompletedParts[#CompletedParts + 1] = CurrentPart
        end
        CurrentArgIndex = #CompletedParts
        CurrentArgText = ''
    else
        -- Still typing current argument
        CurrentArgIndex = #CompletedParts
        CurrentArgText = CurrentPart
    end

    return CompletedParts, CurrentArgIndex, CurrentArgText, InQuote
end

-- Quote a value if it contains spaces or quotes
local function QuoteIfNeeded(Value)
    if Value:find(' ') or Value:find('"') or Value:find("'") then
        -- Prefer double quotes, but use single if value contains double quotes
        if Value:find('"') and not Value:find("'") then
            return ("'%s'"):format(Value)
        else
            -- Escape any double quotes in the value
            local Escaped = Value:gsub('"', '\\"')
            return ('"%s"'):format(Escaped)
        end
    end
    return Value
end

local function Create(ClassName, Properties)
    Properties = Properties or {}

    local Obj = Instance.new(ClassName)

    for Property, Value in next, Properties do
        Obj[Property] = Value
    end

    return Obj
end

local function FindPlayerByName(Name)
    local SearchUsername = false
    local SearchName = Name

    -- Check if searching for username specifically
    if SearchName:sub(1, 1) == '@' then
        SearchUsername = true
        SearchName = SearchName:sub(2) -- Remove the @ prefix
    end

    SearchName = SearchName:lower()

    -- Try display name first (if not forced username search)
    if not SearchUsername then
        for I = 1, #Players:GetPlayers() do
            local Player = Players:GetPlayers()[I]
            if Player.DisplayName:lower():sub(1, #SearchName) == SearchName then
                return Player
            end
        end
    end

    -- Try username
    for I = 1, #Players:GetPlayers() do
        local Player = Players:GetPlayers()[I]
        if Player.Name:lower():sub(1, #SearchName) == SearchName then
            return Player
        end
    end

    return nil
end

local function CreateAsset(Definition)
    -- Definition structure: {ClassName, Properties, Children}
    -- ClassName: string - the instance type to create
    -- Properties: table (optional) - properties to set on the instance
    -- Children: table (optional) - array of child definitions

    local ClassName = Definition[1]
    local Properties = Definition[2] or {}
    local Children = Definition[3] or {}

    -- Create the instance
    local Instance = Create(ClassName, Properties)

    -- Create and parent all children
    for I = 1, #Children do
        local ChildDefinition = Children[I]
        local ChildInstance = CreateAsset(ChildDefinition)
        ChildInstance.Parent = Instance
    end

    return Instance
end

local function WaitForChildOfClass(Parent, ClassName, Timeout)
    local ExistingChild = Parent:FindFirstChildOfClass(ClassName)
    if ExistingChild then
        return ExistingChild
    end

    local Connection
    local ChildFound = false
    local FoundChild = nil

    local Bindable = Create('BindableEvent')

    Connection = Parent.ChildAdded:Connect(function(Child)
        if Child:IsA(ClassName) then
            ChildFound = true
            FoundChild = Child
            Bindable:Fire()
        end
    end)

    if Timeout then
        delay(Timeout, function()
            if not ChildFound then
                Bindable:Fire()
            end
        end)
    end

    Bindable.Event:Wait()

    Connection:Disconnect()
    Bindable:Destroy()

    return FoundChild
end

local function Tween(Obj, Time, Style, Direction, Reverses, Properties)
    local T = TweenService:Create(
        Obj,
        TweenInfo.new(
            Time,
            Enum.EasingStyle[Style],
            Enum.EasingDirection[Direction],
            0,
            Reverses,
            0
        ),
        Properties
    )
    T:Play()
    return T
end

--/ UI Settings /--
local Colors = {
    Base = Color3.fromRGB(30, 30, 46),         -- #1e1e2e
    Mantle = Color3.fromRGB(24, 24, 37),       -- #181825
    Crust = Color3.fromRGB(17, 17, 27),        -- #11111b
    Surface0 = Color3.fromRGB(49, 50, 68),     -- #313244
    Surface1 = Color3.fromRGB(69, 71, 90),     -- #45475a
    Surface2 = Color3.fromRGB(88, 91, 112),    -- #585b70
    Overlay0 = Color3.fromRGB(108, 112, 134),  -- #6c7086
    Overlay1 = Color3.fromRGB(127, 132, 156),  -- #7f849c
    Overlay2 = Color3.fromRGB(147, 153, 178),  -- #9399b2
    Text = Color3.fromRGB(205, 214, 244),      -- #cdd6f4
    Subtext1 = Color3.fromRGB(186, 194, 222),  -- #bac2de
    Subtext0 = Color3.fromRGB(166, 173, 200),  -- #a6adc8
    Blue = Color3.fromRGB(137, 180, 250),      -- #89b4fa
    Lavender = Color3.fromRGB(180, 190, 254),  -- #b4befe
    Sapphire = Color3.fromRGB(116, 199, 236),  -- #74c7ec
    Sky = Color3.fromRGB(137, 220, 235),       -- #89dceb
    Teal = Color3.fromRGB(148, 226, 213),      -- #94e2d5
    Green = Color3.fromRGB(166, 227, 161),     -- #a6e3a1
    Yellow = Color3.fromRGB(249, 226, 175),    -- #f9e2af
    Peach = Color3.fromRGB(250, 179, 135),     -- #fab387
    Maroon = Color3.fromRGB(235, 160, 172),    -- #eba0ac
    Red = Color3.fromRGB(243, 139, 168),       -- #f38ba8
    Mauve = Color3.fromRGB(203, 166, 247),     -- #cba6f7
    Pink = Color3.fromRGB(245, 194, 231),      -- #f5c2e7
    Flamingo = Color3.fromRGB(242, 205, 205),  -- #f2cdcd
    Rosewater = Color3.fromRGB(245, 224, 220), -- #f5e0dc
}

local FontFamily = 'rbxasset://fonts/families/BuilderSans.json'
local FontRegular = Font.new(FontFamily, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local FontMedium = Font.new(FontFamily, Enum.FontWeight.Medium, Enum.FontStyle.Normal)
local FontBold = Font.new(FontFamily, Enum.FontWeight.Bold, Enum.FontStyle.Normal)

local MonoFontFamily = 'rbxasset://fonts/families/Inconsolata.json'
local MonoFontRegular = Font.new(MonoFontFamily, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local MonoFontMedium = Font.new(MonoFontFamily, Enum.FontWeight.Medium, Enum.FontStyle.Normal)
local MonoFontBold = Font.new(MonoFontFamily, Enum.FontWeight.Bold, Enum.FontStyle.Normal)

local BaseZIndex = 1000

-- Expose Colors and Fonts to API
G.Tidecaller.Colors = Colors
G.Tidecaller.Fonts = {
    FontFamily = FontFamily,
    FontRegular = FontRegular,
    FontMedium = FontMedium,
    FontBold = FontBold,
    MonoFontFamily = MonoFontFamily,
    MonoFontRegular = MonoFontRegular,
    MonoFontMedium = MonoFontMedium,
    MonoFontBold = MonoFontBold,
}

--/ Extensible Command System /--
local ArgTypes = {}
local Commands = {}
local Categories = {}

local RebuildCommandList -- Forward declaration

local function RegisterArgType(Name, Config)
    -- Config structure:
    -- {
    --     Color = Color3,
    --     GetSuggestions = function(Query, PreviousArgs) -> {Suggestions}
    --     BuildPaletteItem = function(Suggestion) -> Value, {ChildrenToAdd}
    --         Returns: The value to store, and array of instances to parent to the base item
    -- }
    ArgTypes[Name] = Config
    RebuildCommandList()
end

local function RegisterCategory(Name, Config)
    -- Config structure:
    -- {
    --     Order = number (optional, for sorting)
    --     CustomView = {
    --         BuildPaletteItem = function(Data, Order) -> Frame,
    --         GetSuggestions = function(Query, CommandData, PreviousArgs) -> {Suggestions},
    --         GetValue = function(PaletteItem) -> string
    --     } (optional)
    -- }
    Categories[Name] = Config or {}
    RebuildCommandList()
end

local function RegisterCommand(Config)
    -- Config structure:
    -- {
    --     Category = string,
    --     Name = string,
    --     Args = {{ArgType, ArgName}, ...},
    --     Aliases = {string, ...},
    --     Description = string,
    --     Execute = function(Args)
    -- }
    Commands[#Commands + 1] = Config
    RebuildCommandList()
end

-- Base PaletteItem builder - creates the standard frame
local function CreateBasePaletteItem(Order)
    local BaseFrame = Create('Frame', {
        Name = 'PaletteItem',
        Size = UDim2.new(1, -10, 0, 60),
        BackgroundColor3 = Colors.Base,
        BorderSizePixel = 0,
        LayoutOrder = Order,
        AutomaticSize = Enum.AutomaticSize.Y
    })

    Create('UICorner', {
        CornerRadius = UDim.new(0, 6),
        Parent = BaseFrame
    })

    return BaseFrame
end

-- Expose registration functions to API
G.Tidecaller.RegisterArgType = RegisterArgType
G.Tidecaller.RegisterCommand = RegisterCommand
G.Tidecaller.RegisterCategory = RegisterCategory

--/ UI Creation /--
local UIAssets = {
    ScreenGui = {
        'ScreenGui',
        {
            Name = 'TidecallerGui',
            ResetOnSpawn = false,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        },
        {
            {
                'Frame',
                {
                    Name = 'CommandPalette',
                    AnchorPoint = Vector2.new(0.5, 0),
                    Position = UDim2.new(0.5, 0, -0.5, 0),
                    Size = UDim2.new(0, 600, 0, 400),
                    BackgroundColor3 = Colors.Mantle,
                    BorderSizePixel = 0,
                    Visible = false,
                    ZIndex = BaseZIndex
                },
                {
                    {'UICorner', {CornerRadius = UDim.new(0, 8)}},
                    {
                        'Frame',
                        {
                            Name = 'AccentLine',
                            AnchorPoint = Vector2.new(0.5, 0),
                            Position = UDim2.new(0.5, 0, 0, 0),
                            Size = UDim2.new(1, -12, 0, 5),
                            BorderSizePixel = 0,
                            ZIndex = BaseZIndex + 2
                        },
                        {
                            {'UIGradient', {
                                Color = ColorSequence.new({
                                    ColorSequenceKeypoint.new(0, Colors.Mantle),
                                    ColorSequenceKeypoint.new(0.4, Colors.Blue),
                                    ColorSequenceKeypoint.new(0.5, Colors.Blue),
                                    ColorSequenceKeypoint.new(0.6, Colors.Blue),
                                    ColorSequenceKeypoint.new(1, Colors.Mantle)
                                })
                            }}
                        }
                    },
                    {
                        'TextBox',
                        {
                            Name = 'InputBox',
                            Position = UDim2.new(0, 0, 0, 0),
                            Size = UDim2.new(1, 0, 0, 50),
                            BackgroundColor3 = Colors.Crust,
                            BorderSizePixel = 0,
                            FontFace = MonoFontMedium,
                            PlaceholderText = ('[%s] Type a command...'):format(PREFIX),
                            PlaceholderColor3 = Colors.Overlay0,
                            Text = '',
                            TextColor3 = Colors.Text,
                            TextSize = 15,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            ClearTextOnFocus = false,
                            TextTruncate = Enum.TextTruncate.AtEnd,
                            ZIndex = BaseZIndex + 1
                        },
                        {
                            {'UIPadding', {
                                PaddingLeft = UDim.new(0, 15),
                                PaddingRight = UDim.new(0, 15)
                            }},
                            {'UICorner', {CornerRadius = UDim.new(0, 8)}}
                        }
                    },
                    {
                        'Frame',
                        {
                            Name = 'Divider',
                            Position = UDim2.new(0, 0, 0, 50),
                            Size = UDim2.new(1, 0, 0, 1),
                            BackgroundColor3 = Colors.Surface0,
                            BorderSizePixel = 0,
                            ZIndex = BaseZIndex + 1
                        }
                    },
                    {
                        'ScrollingFrame',
                        {
                            Name = 'CommandsList',
                            Position = UDim2.new(0, 0, 0, 51),
                            Size = UDim2.new(1, 0, 1, -51),
                            BackgroundColor3 = Colors.Mantle,
                            BorderSizePixel = 0,
                            ScrollBarThickness = 6,
                            ScrollBarImageColor3 = Colors.Surface1,
                            CanvasSize = UDim2.new(0, 0, 0, 0),
                            AutomaticCanvasSize = Enum.AutomaticSize.Y,
                            ZIndex = BaseZIndex + 1
                        },
                        {
                            {'UICorner', {CornerRadius = UDim.new(0, 8)}},
                            {'UIListLayout', {
                                SortOrder = Enum.SortOrder.LayoutOrder,
                                Padding = UDim.new(0, 2)
                            }},
                            {'UIPadding', {
                                PaddingTop = UDim.new(0, 5),
                                PaddingBottom = UDim.new(0, 5),
                                PaddingLeft = UDim.new(0, 5),
                                PaddingRight = UDim.new(0, 5)
                            }}
                        }
                    }
                }
            },
            {
                'Frame',
                {
                    Name = 'NotificationContainer',
                    AnchorPoint = Vector2.new(1, 1),
                    Position = UDim2.new(1, 0, 1, -20),
                    Size = UDim2.new(0, 400, 1, 0),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    ClipsDescendants = false,
                    ZIndex = BaseZIndex
                }
            }
        }
    },

    CategoryHeader = {
        'Frame',
        {
            Name = 'CategoryHeader',
            Size = UDim2.new(1, -10, 0, 24),
            BackgroundTransparency = 1,
            BorderSizePixel = 0
        },
        {
            {'TextLabel', {
                Name = 'CategoryLabel',
                Position = UDim2.new(0.5, 0, 0, 0),
                Size = UDim2.new(0, 120, 1, 0),
                BackgroundTransparency = 1,
                FontFace = MonoFontBold,
                TextColor3 = Colors.Subtext0,
                TextSize = 11,
                AnchorPoint = Vector2.new(0.5, 0),
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center
            }}
        }
    },

    Notification = {
        'Frame',
        {
            Name = 'Notification',
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Colors.Base,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = BaseZIndex + 1
        },
        {
            {'UICorner', {CornerRadius = UDim.new(0, 8)}},
            {'UIPadding', {
                PaddingLeft = UDim.new(0, 15),
                PaddingRight = UDim.new(0, 15),
                PaddingTop = UDim.new(0, 12),
                PaddingBottom = UDim.new(0, 12)
            }},
            {
                'Frame',
                {
                    Name = 'AccentBar',
                    AnchorPoint = Vector2.new(0.5, 1),
                    Position = UDim2.new(0.5, 0, 1, 12),
                    Size = UDim2.new(1, -30, 0, 5),
                    BorderSizePixel = 0,
                    ZIndex = BaseZIndex + 2
                },
                {
                    {'UIGradient', {
                        Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, Colors.Surface0),
                            ColorSequenceKeypoint.new(0.5, Colors.Blue),
                            ColorSequenceKeypoint.new(1, Colors.Surface0)
                        })
                    }}
                }
            },
            {'TextLabel', {
                Name = 'Timestamp',
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, 0, 0, 0),
                Size = UDim2.new(0, 70, 0, 14),
                BackgroundTransparency = 1,
                FontFace = MonoFontBold,
                Text = '[12:34:56]',
                TextColor3 = Colors.Overlay1,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextYAlignment = Enum.TextYAlignment.Top
            }},
            {'TextLabel', {
                Name = 'Title',
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(1, -75, 0, 0),
                BackgroundTransparency = 1,
                FontFace = FontBold,
                Text = 'Notification Title',
                TextColor3 = Colors.Text,
                TextSize = 18,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                AutomaticSize = Enum.AutomaticSize.Y
            }},
            {
                'TextLabel',
                {
                    Name = 'Message',
                    Position = UDim2.new(0, 0, 0, 25),
                    Size = UDim2.new(1, 0, 0, 0),
                    BackgroundTransparency = 1,
                    FontFace = FontRegular,
                    TextWrapped = true,
                    Text = 'Notification message',
                    TextColor3 = Colors.Subtext1,
                    TextSize = 16,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    AutomaticSize = Enum.AutomaticSize.Y
                },
                {
                    {'UIPadding', {PaddingBottom = UDim.new(0, 8)}}
                }
            }
        }
    }
}

--/ UI Initialization /--
local Container = type(gethui) == 'function' and gethui() or CoreGui

local ScreenGui = CreateAsset(UIAssets.ScreenGui)
ScreenGui.Parent = Container

local CommandPalette = ScreenGui:WaitForChild('CommandPalette')
local AccentLineTopGradient = CommandPalette:WaitForChild('AccentLine'):WaitForChild('UIGradient')
local InputBox = CommandPalette:WaitForChild('InputBox')
local CommandsList = CommandPalette:WaitForChild('CommandsList')
local NotificationContainer = ScreenGui:WaitForChild('NotificationContainer')

--/ UI Helper Functions /--
-- Create a PaletteItem for a command
local function CreateCommandPaletteItem(CommandData, Order)
    local CommandNameColor = Colors.Blue
    if #CommandData.Args > 0 then
        local FirstArgType = CommandData.Args[1][1]
        local ArgType = ArgTypes[FirstArgType]
        if ArgType then
            CommandNameColor = ArgType.Color
        end
    end

    local BaseItem = CreateBasePaletteItem(Order)
    BaseItem.Name = 'CommandPaletteItem'

    Create('UIPadding', {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
        Parent = BaseItem
    })

    local CommandNameContainer = Create('Frame', {
        Name = 'CommandNameContainer',
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = BaseItem
    })

    Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Parent = CommandNameContainer
    })

    local CommandDescription = Create('TextLabel', {
        Name = 'CommandDescription',
        Position = UDim2.new(0, 0, 0, 28),
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        FontFace = FontRegular,
        TextColor3 = Colors.Subtext1,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = CommandData.Description,
        Parent = BaseItem
    })

    -- Command name block
    local NameBlock = Create('Frame', {
        Name = 'CommandNameBlock',
        Size = UDim2.new(0, 0, 0, 20),
        BackgroundColor3 = Colors.Crust,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = 1,
        Parent = CommandNameContainer
    })

    Create('UICorner', {
        CornerRadius = UDim.new(0, 4),
        Parent = NameBlock
    })

    Create('UIPadding', {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 2),
        Parent = NameBlock
    })

    Create('TextLabel', {
        Name = 'CommandName',
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 1,
        FontFace = MonoFontBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutomaticSize = Enum.AutomaticSize.X,
        Text = CommandData.Name,
        TextColor3 = CommandNameColor,
        Parent = NameBlock
    })

    -- Aliases block
    if #CommandData.Aliases > 0 then
        local AliasBlock = Create('Frame', {
            Name = 'AliasBlock',
            Size = UDim2.new(0, 0, 0, 20),
            BackgroundColor3 = Colors.Mantle,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = 2,
            Parent = CommandNameContainer
        })

        Create('UICorner', {
            CornerRadius = UDim.new(0, 4),
            Parent = AliasBlock
        })

        Create('UIPadding', {
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 2),
            PaddingBottom = UDim.new(0, 2),
            Parent = AliasBlock
        })

        Create('TextLabel', {
            Name = 'AliasLabel',
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundTransparency = 1,
            FontFace = MonoFontMedium,
            TextColor3 = Colors.Overlay1,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutomaticSize = Enum.AutomaticSize.X,
            Text = ('[%s]'):format(table.concat(CommandData.Aliases, ', ')),
            Parent = AliasBlock
        })
    end

    -- Argument blocks
    for ArgI = 1, #CommandData.Args do
        local ArgData = CommandData.Args[ArgI]
        local ArgType = ArgData[1]
        local ArgName = ArgData[2]
        local IsOptional = ArgData[3]
        local DefaultValue = ArgData[4]
        local ArgTypeConfig = ArgTypes[ArgType]
        local ArgColor = ArgTypeConfig and ArgTypeConfig.Color or Colors.Sapphire

        local ArgBlock = Create('Frame', {
            Name = 'ArgBlock',
            Size = UDim2.new(0, 0, 0, 20),
            BackgroundColor3 = Colors.Mantle,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = 10 + ArgI,
            Parent = CommandNameContainer
        })

        Create('UICorner', {
            CornerRadius = UDim.new(0, 4),
            Parent = ArgBlock
        })

        Create('UIPadding', {
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 2),
            PaddingBottom = UDim.new(0, 2),
            Parent = ArgBlock
        })

        -- Determine argument display text
        local ArgText
        if IsOptional then
            if DefaultValue ~= nil then
                -- Has a default value - show "<argname: default>"
                ArgText = ('<%s: %s>'):format(ArgName, tostring(DefaultValue))
            else
                -- Optional but no default - show "<argname: auto>"
                ArgText = ('<%s: auto>'):format(ArgName)
            end
        else
            -- Required argument - show "<argname>"
            ArgText = ('<%s>'):format(ArgName)
        end

        Create('TextLabel', {
            Name = 'ArgLabel',
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundTransparency = 1,
            FontFace = MonoFontMedium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutomaticSize = Enum.AutomaticSize.X,
            Text = ArgText,
            TextColor3 = ArgColor,
            Parent = ArgBlock
        })
    end

    return BaseItem
end

local function CreateCategoryHeader(CategoryName, Order)
    local Template = UIAssets.CategoryHeader
    local CategoryHeader = CreateAsset(Template)
    CategoryHeader.Parent = CommandsList
    CategoryHeader.LayoutOrder = Order

    local CategoryLabel = CategoryHeader:WaitForChild('CategoryLabel')
    CategoryLabel.Text = ('⸺ [ %s ] ⸺'):format(CategoryName)

    return CategoryHeader
end

RebuildCommandList = function()
    -- Only rebuild if CommandsList exists (UI is initialized)
    if not CommandsList then return end

    -- Clear all existing command items and category headers
    local Children = CommandsList:GetChildren()
    for I = 1, #Children do
        local Child = Children[I]
        if Child:IsA('Frame') and (Child.Name == 'CommandPaletteItem' or Child.Name == 'CategoryHeader') then
            Child:Destroy()
        end
    end

    -- Build command list from Commands array
    local LastCategory = nil
    local LayoutOrder = 0

    for I = 1, #Commands do
        local CommandData = Commands[I]

        if CommandData.Category ~= LastCategory then
            LastCategory = CommandData.Category
            LayoutOrder = LayoutOrder + 1
            CreateCategoryHeader(CommandData.Category, LayoutOrder)
        end

        LayoutOrder = LayoutOrder + 1
        local PaletteItem = CreateCommandPaletteItem(CommandData, LayoutOrder)
        PaletteItem.Parent = CommandsList
    end

    -- Update visible commands list
    if UpdateVisibleCommands then
        UpdateVisibleCommands()
    end
end

--/ Script State /--
local PaletteOpen = false
local NotificationOrder = 0
local ActiveNotifications = {}
local NotificationGap = 10
local ActiveCloseTween = nil
local SelectedCommandIndex = 0
local VisibleCommands = {}
local CurrentlyHighlighted = nil
local IsNavigating = false
local IsArgMode = false
local CurrentCommand = nil
local CurrentArgType = nil

-- Delayed repeat state
local RepeatDelay = 0.5  -- Initial delay before repeat starts
local RepeatInterval = 0.033  -- Interval between repeats
local HeldKey = nil
local HoldStartTime = 0
local LastRepeatTime = 0
local RepeatActive = false

-- Update notification positions with tweening
local function UpdateNotificationPositions()
    local CurrentY = 0

    for I = 1, #ActiveNotifications do
        local NotifData = ActiveNotifications[I]
        local Notif = NotifData.Frame
        if Notif and Notif.Parent then
            Tween(Notif, 0.3, 'Quart', 'Out', false, {
                Position = UDim2.new(0, -20, 1, -CurrentY)
            })
            CurrentY = CurrentY + Notif.AbsoluteSize.Y + NotificationGap
        end
    end
end

--/ Notification Functions /--
local function Notify(Type, Title, Message, Duration)
    Duration = Duration or math.max(3, Message:len() * 0.05)
    NotificationOrder = NotificationOrder + 1

    local TypeColors = {
        Success = Colors.Green,
        Info = Colors.Blue,
        Warning = Colors.Yellow,
        Error = Colors.Red
    }
    local AccentColor = TypeColors[Type] or Colors.Blue

    local NotificationClone = CreateAsset(UIAssets.Notification)
    NotificationClone.Name = 'Notification_' .. NotificationOrder
    NotificationClone.AnchorPoint = Vector2.new(0, 1)
    NotificationClone.Visible = false

    local Time = os.date('*t')
    local Timestamp = ('[%02d:%02d:%02d]'):format(Time.hour, Time.min, Time.sec)
    NotificationClone.Timestamp.Text = Timestamp

    NotificationClone.Title.Text = Title
    NotificationClone.Message.Text = Message

    local AccentBar = NotificationClone:FindFirstChild('AccentBar')
    if AccentBar then
        local AccentGradient = AccentBar:FindFirstChild('UIGradient')
        if AccentGradient then
            AccentGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Colors.Surface0),
                ColorSequenceKeypoint.new(0.5, AccentColor),
                ColorSequenceKeypoint.new(1, Colors.Surface0)
            })
        end
    end

    -- Parent and wait for size calculation
    NotificationClone.Parent = NotificationContainer
    wait()

    -- Calculate Y position
    local CurrentY = 0
    for I = 1, #ActiveNotifications do
        local NotifData = ActiveNotifications[I]
        if NotifData.Frame and NotifData.Frame.Parent then
            CurrentY = CurrentY + NotifData.Frame.AbsoluteSize.Y + NotificationGap
        end
    end

    -- Position off-screen and make visible
    NotificationClone.Position = UDim2.new(1, 0, 1, -CurrentY)
    NotificationClone.Visible = true

    ActiveNotifications[#ActiveNotifications + 1] = {
        Frame = NotificationClone,
        Order = NotificationOrder
    }

    -- Slide in from right
    Tween(NotificationClone, 0.3, 'Quart', 'Out', false, {Position = UDim2.new(0, -20, 1, -CurrentY)})

    -- Auto-dismiss after duration
    delay(Duration, function()
        if NotificationClone and NotificationClone.Parent then
            local CurrentPos = NotificationClone.Position
            local SlideTween = Tween(
                NotificationClone, 0.3,
                'Quart',
                'In',
                false,
                {
                    Position = UDim2.new(0, 500, CurrentPos.Y.Scale, CurrentPos.Y.Offset)
                }
            )

            C[#C + 1] = SlideTween.Completed:Once(function()
                -- Remove from active notifications
                for I = 1, #ActiveNotifications do
                    if ActiveNotifications[I].Frame == NotificationClone then
                        for J = I, #ActiveNotifications - 1 do
                            ActiveNotifications[J] = ActiveNotifications[J + 1]
                        end
                        ActiveNotifications[#ActiveNotifications] = nil
                        break
                    end
                end
                NotificationClone:Destroy()

                UpdateNotificationPositions()
            end)
        end
    end)
end

-- Expose Notify
G.Tidecaller.Notify = Notify

--/ Command Palette Functions /--
local function UpdateVisibleCommands()
    VisibleCommands = {}
    local Children = CommandsList:GetChildren()

    for I = 1, #Children do
        local Child = Children[I]
        if Child:IsA('Frame') and Child.Name:match('PaletteItem$') and Child.Visible then
            VisibleCommands[#VisibleCommands + 1] = Child
        end
    end
end

local function ClearArgSuggestions()
    local Children = CommandsList:GetChildren()
    for I = 1, #Children do
        local Child = Children[I]
        if Child:IsA('Frame') and Child.Name ~= 'CommandPaletteItem' and Child.Name ~= 'CategoryHeader' then
            Child:Destroy()
        end
    end
end

local function ShowArgSuggestions(ArgType, Query, PreviousArgs)
    ClearArgSuggestions()

    local ArgTypeConfig = ArgTypes[ArgType]
    if not ArgTypeConfig then return end

    local Suggestions = ArgTypeConfig.GetSuggestions(Query, PreviousArgs)

    for I = 1, #Suggestions do
        local Value, Children = ArgTypeConfig.BuildPaletteItem(Suggestions[I])
        if Children then
            -- Create the base palette item automatically (autosizes to content)
            local BaseItem = CreateBasePaletteItem(1000 + I)
            BaseItem.Name = ArgType .. 'PaletteItem'

            -- Store the value as an attribute
            BaseItem:SetAttribute('ArgValue', Value)

            -- Parent all children to the base item
            for J = 1, #Children do
                Children[J].Parent = BaseItem
            end

            BaseItem.Parent = CommandsList
        end
    end

    UpdateVisibleCommands()
    SelectedCommandIndex = 0
    if CurrentlyHighlighted then
        Tween(CurrentlyHighlighted, 0.15, 'Quad', 'Out', false, {
            BackgroundColor3 = Colors.Base
        })
        CurrentlyHighlighted = nil
    end
end

-- Highlight PaletteItem
local function HighlightPaletteItem(Index)
    -- Remove previous highlight
    if CurrentlyHighlighted then
        Tween(CurrentlyHighlighted, 0.15, 'Quad', 'Out', false, {
            BackgroundColor3 = Colors.Base
        })
    end

    -- Reset if index is 0 or out of bounds
    if Index <= 0 or Index > #VisibleCommands then
        CurrentlyHighlighted = nil
        SelectedCommandIndex = 0
        return
    end

    -- Highlight new item
    local Item = VisibleCommands[Index]
    if Item then
        CurrentlyHighlighted = Item
        SelectedCommandIndex = Index

        Tween(Item, 0.15, 'Quad', 'Out', false, {
            BackgroundColor3 = Colors.Surface0
        })

        -- Scroll into view
        local ScrollPos = CommandsList.CanvasPosition.Y
        local ScrollHeight = CommandsList.AbsoluteSize.Y
        local ItemPos = Item.AbsolutePosition.Y - CommandsList.AbsolutePosition.Y + ScrollPos
        local ItemHeight = Item.AbsoluteSize.Y

        -- Check if item is above visible area
        if ItemPos < ScrollPos then
            CommandsList.CanvasPosition = Vector2.new(0, ItemPos - 5)
        -- Check if item is below visible area
        elseif ItemPos + ItemHeight > ScrollPos + ScrollHeight then
            CommandsList.CanvasPosition = Vector2.new(0, ItemPos + ItemHeight - ScrollHeight + 5)
        end

        IsNavigating = true

        if Item.Name == 'CommandPaletteItem' then
            -- Fill input with command name
            local CommandNameBlock = Item:FindFirstChild('CommandNameContainer')
            if CommandNameBlock then
                local NameBlock = CommandNameBlock:FindFirstChild('CommandNameBlock')
                if NameBlock then
                    local CommandNameLabel = NameBlock:FindFirstChild('CommandName')
                    if CommandNameLabel then
                        InputBox.Text = CommandNameLabel.Text
                        -- Move cursor to end
                        InputBox.CursorPosition = #InputBox.Text + 1
                    end
                end
            end
        else
            -- For any other PaletteItem type, get the value from the attribute
            local CurrentText = InputBox.Text
            local Parts, CurrentArgIndex, CurrentArgText, InQuote = ParseCommandInput(CurrentText)

            -- Get the value from the attribute
            local Value = Item:GetAttribute('ArgValue') or ''

            -- Quote the value if it contains spaces or special characters
            local QuotedValue = QuoteIfNeeded(Value)

            -- Build the new input with all COMPLETED arguments (Parts doesn't include current partial arg)
            -- Then add the selected value
            local NewText = ''
            for I = 1, #Parts do
                NewText = NewText .. QuoteIfNeeded(Parts[I]) .. ' '
            end
            NewText = NewText .. QuotedValue

            InputBox.Text = NewText
            -- Move cursor to end
            InputBox.CursorPosition = #InputBox.Text + 1
        end

        IsNavigating = false
    end
end

-- Navigate Up
local function NavigateUp()
    if #VisibleCommands == 0 then return end

    local NewIndex = SelectedCommandIndex - 1
    if NewIndex < 1 then
        NewIndex = #VisibleCommands
    end

    HighlightPaletteItem(NewIndex)
end

-- Navigate Down
local function NavigateDown()
    if #VisibleCommands == 0 then return end

    local NewIndex = SelectedCommandIndex + 1
    if NewIndex > #VisibleCommands then
        NewIndex = 1
    end

    HighlightPaletteItem(NewIndex)
end

local function OpenPalette()
    if PaletteOpen then return end
    PaletteOpen = true

    -- Cancel any active closing animation
    if ActiveCloseTween then
        ActiveCloseTween:Cancel()
        ActiveCloseTween = nil
    end

    UpdateVisibleCommands()

    CommandPalette.Visible = true
    Tween(CommandPalette, 0.3, 'Quart', 'Out', false, {Position = UDim2.new(0.5, 0, 0.15, 0)})

    Heartbeat:Wait()

    InputBox:CaptureFocus()
end

local function ClosePalette()
    if not PaletteOpen then return end
    PaletteOpen = false

    if InputBox:IsFocused() then
        InputBox:ReleaseFocus()
    end

    Heartbeat:Wait()

    ActiveCloseTween = Tween(CommandPalette, 0.3, 'Quart', 'In', false, {Position = UDim2.new(0.5, 0, -0.5, 0)})

    C[#C + 1] = ActiveCloseTween.Completed:Once(function()
        -- Only hide if this tween wasn't cancelled
        if ActiveCloseTween then
            CommandPalette.Visible = false
            InputBox.Text = ''
            ActiveCloseTween = nil
        end
    end)
end

local function TogglePalette()
    if PaletteOpen then
        ClosePalette()
    else
        OpenPalette()
    end
end

local function FilterCommands(Query)
    -- Remove prefix if present
    if Query:sub(1, #PREFIX) == PREFIX then
        Query = Query:sub(#PREFIX + 1)
    end

    -- Parse the query with quote support
    local Parts, ArgumentIndex, CurrentArgumentText, InQuote = ParseCommandInput(Query)

    -- Check if we're typing an argument
    local IsTypingArgument = ArgumentIndex >= 1

    -- If ArgumentIndex is 0, we're typing the command name itself
    local CommandName = ''
    if ArgumentIndex == 0 then
        CommandName = CurrentArgumentText:lower()
    else
        CommandName = (Parts[1] or ''):lower()
    end

    -- Find the command in Commands registry
    local MatchedCommand = nil
    if IsTypingArgument then
        for I = 1, #Commands do
            local Command = Commands[I]
            if Command.Name:lower() == CommandName then
                MatchedCommand = Command
                break
            end
            -- Check aliases
            for J = 1, #Command.Aliases do
                if Command.Aliases[J]:lower() == CommandName then
                    MatchedCommand = Command
                    break
                end
            end
            if MatchedCommand then break end
        end
    end

    -- Determine if we should show argument suggestions
    if MatchedCommand and ArgumentIndex >= 1 and ArgumentIndex <= #MatchedCommand.Args then
        local ArgType = MatchedCommand.Args[ArgumentIndex][1]
        local ArgTypeConfig = ArgTypes[ArgType]

        if ArgTypeConfig then
            -- Enter arg mode
            IsArgMode = true
            CurrentCommand = MatchedCommand
            CurrentArgType = ArgType

            -- Hide all command items and category headers
            local Children = CommandsList:GetChildren()
            for I = 1, #Children do
                local Child = Children[I]
                if Child:IsA('Frame') and (Child.Name == 'CommandPaletteItem' or Child.Name == 'CategoryHeader') then
                    Child.Visible = false
                end
            end

            -- Show argument suggestions
            ShowArgSuggestions(ArgType, CurrentArgumentText, Parts)
            return
        end
    end

    -- If not in arg mode, show commands
    IsArgMode = false
    CurrentCommand = nil
    CurrentArgType = nil
    ClearArgSuggestions()

    local Children = CommandsList:GetChildren()

    -- First pass: Filter all command items
    for I = 1, #Children do
        local Child = Children[I]

        if Child:IsA('Frame') and Child.Name == 'CommandPaletteItem' then
            -- Get command name from the CommandNameBlock
            local CommandNameBlock = Child:FindFirstChild('CommandNameContainer')
            if CommandNameBlock then
                local NameBlock = CommandNameBlock:FindFirstChild('CommandNameBlock')
                if NameBlock then
                    local CommandNameLabel = NameBlock:FindFirstChild('CommandName')
                    if CommandNameLabel then
                        local CommandNameText = CommandNameLabel.Text:lower()

                        -- Check if command name matches query
                        local Matches = CommandName == '' or CommandNameText:find(CommandName, 1, true) ~= nil

                        -- If not matched, check aliases
                        if not Matches then
                            local AliasBlock = CommandNameBlock:FindFirstChild('AliasBlock')
                            if AliasBlock then
                                local AliasLabel = AliasBlock:FindFirstChild('AliasLabel')
                                if AliasLabel then
                                    local AliasText = AliasLabel.Text:lower()
                                    Matches = AliasText:find(CommandName, 1, true) ~= nil
                                end
                            end
                        end

                        Child.Visible = Matches
                    end
                end
            end
        end
    end

    -- Second pass: Update category header visibility based on filtered commands
    for I = 1, #Children do
        local Child = Children[I]

        if Child:IsA('Frame') and Child.Name == 'CategoryHeader' then
            -- Look ahead to see if any commands after this header are visible
            local HasVisibleCommands = false

            for J = I + 1, #Children do
                local NextChild = Children[J]

                -- Stop if we hit another category header
                if NextChild:IsA('Frame') and NextChild.Name == 'CategoryHeader' then
                    break
                end

                -- Check if this command item is visible
                if NextChild:IsA('Frame') and NextChild.Name == 'CommandPaletteItem' and NextChild.Visible then
                    HasVisibleCommands = true
                    break
                end
            end

            Child.Visible = HasVisibleCommands
        end
    end

    -- Update visible commands list and reset selection
    UpdateVisibleCommands()
    SelectedCommandIndex = 0
    if CurrentlyHighlighted then
        Tween(CurrentlyHighlighted, 0.15, 'Quad', 'Out', false, {
            BackgroundColor3 = Colors.Base
        })
        CurrentlyHighlighted = nil
    end
end

--/ Cleanup Function /--
local function Cleanup()
	-- Destroy UI elements
	if ScreenGui and ScreenGui.Parent then
		pcall(function()
			ScreenGui:Destroy()
		end)
	end

	-- Disconnect and destroy all tracked connections/objects
	for I = 1, #C do
		local Obj = C[I]
		pcall(function()
			Obj:Disconnect()
		end)
		pcall(function()
			Obj:Destroy()
		end)
	end

	-- Reset global table
	G.Tidecaller = nil
end

--/ Animated Accent Line /--
local GradientColors = {
    Colors.Red,
    Colors.Peach,
    Colors.Green,
    Colors.Sky,
    Colors.Blue,
    Colors.Lavender,
    Colors.Pink,
    Colors.Mauve
}

local CurrentIndex = 1
local NextIndex = 2
local TransitionTime = 0.5
local Elapsed = 0

C[#C + 1] = RenderStepped:Connect(function(DeltaTime)
    Elapsed = Elapsed + DeltaTime

    if Elapsed >= TransitionTime then
        Elapsed = 0
        CurrentIndex = NextIndex
        NextIndex = CurrentIndex % #GradientColors + 1
    end

    local Alpha = Elapsed / TransitionTime

    local PrevIndex = (CurrentIndex - 2) % #GradientColors + 1
    local PrevColor = GradientColors[PrevIndex]
    local CurrentColor = GradientColors[CurrentIndex]
    local NextColor = GradientColors[NextIndex]
    local NextNextIndex = NextIndex % #GradientColors + 1
    local NextNextColor = GradientColors[NextNextIndex]

    local LeftColor = PrevColor:Lerp(CurrentColor, Alpha)
    local CenterColor = CurrentColor:Lerp(NextColor, Alpha)
    local RightColor = NextColor:Lerp(NextNextColor, Alpha)

    AccentLineTopGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Colors.Mantle),
        ColorSequenceKeypoint.new(0.4, LeftColor),
        ColorSequenceKeypoint.new(0.5, CenterColor),
        ColorSequenceKeypoint.new(0.6, RightColor),
        ColorSequenceKeypoint.new(1, Colors.Mantle)
    })

    -- Handle delayed repeat for navigation keys
    if HeldKey and PaletteOpen and InputBox:IsFocused() then
        local CurrentTime = tick()
        local HoldDuration = CurrentTime - HoldStartTime

        -- Check if we've passed the initial delay
        if not RepeatActive and HoldDuration >= RepeatDelay then
            RepeatActive = true
            LastRepeatTime = CurrentTime
        end

        -- If repeat is active, check if enough time has passed for next repeat
        if RepeatActive and (CurrentTime - LastRepeatTime) >= RepeatInterval then
            if HeldKey == Enum.KeyCode.Up then
                NavigateUp()
            elseif HeldKey == Enum.KeyCode.Down then
                NavigateDown()
            end
            LastRepeatTime = CurrentTime
        end
    end
end)

--/ Input Handling /--
C[#C + 1] = UserInputService.InputBegan:Connect(function(Input, GameProcessed)
    if Input.UserInputType == Enum.UserInputType.Keyboard then
        -- Handle hotkey (not processed by game)
        if not GameProcessed and Input.KeyCode == Enum.KeyCode[HOTKEY] then
            TogglePalette()
            return
        end

        -- Handle Up/Down arrows when palette is open and input is focused
        if PaletteOpen and InputBox:IsFocused() then
            if Input.KeyCode == Enum.KeyCode.Up then
                NavigateUp()
                -- Start tracking for delayed repeat
                HeldKey = Enum.KeyCode.Up
                HoldStartTime = tick()
                RepeatActive = false
            elseif Input.KeyCode == Enum.KeyCode.Down then
                NavigateDown()
                -- Start tracking for delayed repeat
                HeldKey = Enum.KeyCode.Down
                HoldStartTime = tick()
                RepeatActive = false
            end
        end
    end
end)

C[#C + 1] = UserInputService.InputEnded:Connect(function(Input, GameProcessed)
    if Input.UserInputType == Enum.UserInputType.Keyboard then
        -- Cancel repeat when key is released
        if Input.KeyCode == HeldKey then
            HeldKey = nil
            RepeatActive = false
        end
    end
end)

C[#C + 1] = InputBox:GetPropertyChangedSignal('Text'):Connect(function()
    if not IsNavigating then
        FilterCommands(InputBox.Text)
    end
end)

C[#C + 1] = InputBox.FocusLost:Connect(function(EnterPressed)
    if EnterPressed then
        -- Execute the command
        local Input = InputBox.Text
        local Parts, CurrentArgIndex, CurrentArgText = ParseCommandInput(Input)

        -- Add the current part if it's not empty
        -- Check if the input doesn't end with a space (meaning we're still typing an argument)
        if #CurrentArgText > 0 and Input:sub(#Input, #Input) ~= ' ' then
            Parts[#Parts + 1] = CurrentArgText
        end

        if #Parts > 0 then
            local CommandName = Parts[1]:lower()

            -- Find matching command
            local MatchedCommand = nil
            for I = 1, #Commands do
                local Command = Commands[I]
                if Command.Name:lower() == CommandName then
                    MatchedCommand = Command
                    break
                end

                -- Check aliases
                for J = 1, #Command.Aliases do
                    if Command.Aliases[J]:lower() == CommandName then
                        MatchedCommand = Command
                        break
                    end
                end

                if MatchedCommand then
                    break
                end
            end

            if MatchedCommand then
                -- Parse arguments using GetValue
                local ParsedArgs = {}
                local AllArgsParsed = true

                for I = 1, #MatchedCommand.Args do
                    local ArgTypeName = MatchedCommand.Args[I][1]
                    local ArgName = MatchedCommand.Args[I][2]
                    local IsOptional = MatchedCommand.Args[I][3]
                    local DefaultValue = MatchedCommand.Args[I][4]
                    local ArgType = ArgTypes[ArgTypeName]
                    local RawValue = Parts[I + 1]

                    if RawValue and ArgType and ArgType.GetValue then
                        local ParsedValue = ArgType.GetValue(RawValue)
                        if ParsedValue ~= nil then
                            ParsedArgs[I] = ParsedValue
                        else
                            AllArgsParsed = false
                            Notify('Error', ('%s: Argument Error'):format(MatchedCommand.Name), ('Failed to parse argument %d (%s) as %s'):format(I, ArgName, ArgTypeName))
                            break
                        end
                    elseif RawValue then
                        -- No GetValue function, use raw value
                        ParsedArgs[I] = RawValue
                    else
                        -- Missing argument - check if it's optional
                        if IsOptional then
                            -- Use default value if provided
                            ParsedArgs[I] = DefaultValue
                        else
                            -- Required argument is missing
                            AllArgsParsed = false
                            Notify('Error', ('%s: Missing Argument'):format(MatchedCommand.Name), ('Missing argument: %s'):format(ArgName))
                            break
                        end
                    end
                end

                if AllArgsParsed then
                    -- Execute the command
                    local Success, ErrorMsg = pcall(function()
                        MatchedCommand.Execute(unpack(ParsedArgs))
                    end)

                    if not Success then
                        Notify('Error', ('%s: Execution Error'):format(MatchedCommand.Name), tostring(ErrorMsg))
                    end
                end
            end
        end

        ClosePalette()
    else
        -- Unfocused without pressing enter
        ClosePalette()
    end
end)

--/ Argument Types /--
RegisterArgType('number', {
    Color = Colors.Yellow,
    GetValue = function(Str)
        return tonumber(Str)
    end,
    GetSuggestions = function(Query, PreviousArgs)
        return {} -- No suggestions for numbers
    end,
    BuildPaletteItem = function(Data)
        return nil, nil -- Numbers don't have suggestion items
    end
})

RegisterArgType('string', {
    Color = Colors.Pink,
    GetValue = function(Str)
        return Str
    end,
    GetSuggestions = function(Query, PreviousArgs)
        return {} -- No suggestions for strings
    end,
    BuildPaletteItem = function(Data)
        return nil, nil -- Strings don't have suggestion items
    end
})

RegisterArgType('boolean', {
    Color = Colors.Mauve,
    GetValue = function(Str)
        local Lower = Str:lower()
        if Lower == 't' or Lower == 'true' or Lower == '1' then
            return true
        elseif Lower == 'f' or Lower == 'false' or Lower == '0' then
            return false
        end
        return nil
    end,
    GetSuggestions = function(Query, PreviousArgs)
        return {} -- No suggestions for booleans
    end,
    BuildPaletteItem = function(Data)
        return nil, nil -- Booleans don't have suggestion items
    end
})

RegisterArgType('player', {
    Color = Colors.Green,
    GetValue = function(Str)
        return FindPlayerByName(Str)
    end,
    GetSuggestions = function(Query, PreviousArgs)
        local SearchUsername = false
        local SearchQuery = Query

        if SearchQuery:sub(1, 1) == '@' then
            SearchUsername = true
            SearchQuery = SearchQuery:sub(2)
        end

        SearchQuery = SearchQuery:lower()
        local AllPlayers = Players:GetPlayers()
        local MatchedPlayers = {}

        local function CalculateScore(Name)
            local LowerName = Name:lower()
            local StartPos = LowerName:find(SearchQuery, 1, true)

            if not StartPos then
                return INF
            end

            local PositionScore = StartPos
            local LengthRatio = #SearchQuery / #Name
            return PositionScore - (LengthRatio * 0.5)
        end

        if not SearchUsername then
            for I = 1, #AllPlayers do
                local Player = AllPlayers[I]
                if SearchQuery == '' or Player.DisplayName:lower():find(SearchQuery, 1, true) ~= nil then
                    local Score = SearchQuery == '' and 0 or CalculateScore(Player.DisplayName)
                    MatchedPlayers[#MatchedPlayers + 1] = {
                        Data = Player,
                        Score = Score,
                        SortName = Player.DisplayName:lower()
                    }
                end
            end
        end

        if SearchUsername then
            for I = 1, #AllPlayers do
                local Player = AllPlayers[I]
                if SearchQuery == '' or Player.Name:lower():find(SearchQuery, 1, true) ~= nil then
                    local Score = SearchQuery == '' and 0 or CalculateScore(Player.Name)
                    MatchedPlayers[#MatchedPlayers + 1] = {
                        Data = Player,
                        Score = Score,
                        SortName = Player.Name:lower()
                    }
                end
            end
        end

        table.sort(MatchedPlayers, function(A, B)
            if A.Score == B.Score then
                return A.SortName < B.SortName
            end
            return A.Score < B.Score
        end)

        local Results = {}
        for I = 1, #MatchedPlayers do
            Results[I] = MatchedPlayers[I].Data
        end

        return Results
    end,
    BuildPaletteItem = function(Player)
        local Padding = Create('UIPadding', {
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 12),
            PaddingTop = UDim.new(0, 8),
            PaddingBottom = UDim.new(0, 8)
        })

        local Avatar = Create('ImageLabel', {
            Name = 'Avatar',
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(0, 44, 0, 44),
            BackgroundColor3 = Colors.Surface0,
            BorderSizePixel = 0,
            Image = ('rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150'):format(Player.UserId)
        })

        Create('UICorner', {
            CornerRadius = UDim.new(0, 6),
            Parent = Avatar
        })

        local InfoContainer = Create('Frame', {
            Name = 'InfoContainer',
            Position = UDim2.new(0, 54, 0, 0),
            Size = UDim2.new(1, -54, 1, 0),
            BackgroundTransparency = 1
        })

        Create('TextLabel', {
            Name = 'DisplayName',
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
            FontFace = FontBold,
            Text = Player.DisplayName,
            TextColor3 = Colors.Text,
            TextSize = 18,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = InfoContainer
        })

        Create('TextLabel', {
            Name = 'Username',
            Position = UDim2.new(0, 0, 0, 22),
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            FontFace = MonoFontMedium,
            Text = ('@%s'):format(Player.Name),
            TextColor3 = Colors.Subtext0,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = InfoContainer
        })

        -- Return value to store, and children to be parented to base item
        return Player.Name, {Padding, Avatar, InfoContainer}
    end
})

--/ Commands /--
RegisterCommand({
    Category = 'CHARACTER',
    Name = 'fly',
    Args = {},
    Aliases = {},
    Description = 'Enter flight mode',
    Execute = function()
        print('fly')
    end
})

RegisterCommand({
    Category = 'CHARACTER',
    Name = 'unfly',
    Args = {},
    Aliases = {},
    Description = 'Exit flight mode',
    Execute = function()
        print('unfly')
    end
})

RegisterCommand({
    Category = 'CHARACTER',
    Name = 'speed',
    Args = {{'number', 'amount', true, 16}},
    Aliases = {'ws'},
    Description = 'Set your humanoid\'s walkspeed',
    Execute = function(Amount)
        print('speed', Amount, type(Amount))
    end
})

RegisterCommand({
    Category = 'CHARACTER',
    Name = 'jumppower',
    Args = {{'number', 'amount', true, 50}},
    Aliases = {'jp', 'jpower'},
    Description = 'Set your humanoid\'s jump power',
    Execute = function(Amount)
        print('jumppower', Amount, type(Amount))
    end
})

RegisterCommand({
    Category = 'CHARACTER',
    Name = 'hipheight',
    Args = {{'number', 'amount', true, 0}},
    Aliases = {'hh'},
    Description = 'Set your humanoid\'s hipheight',
    Execute = function(Amount)
        print('hipheight', Amount, type(Amount))
    end
})

RegisterCommand({
    Category = 'CAMERA',
    Name = 'spectate',
    Args = {{'player', 'target'}},
    Aliases = {'view'},
    Description = 'Specate a player',
    Execute = function(Target)
        print('spectate', Target, type(Target))
    end
})

RegisterCommand({
    Category = 'CAMERA',
    Name = 'unspectate',
    Args = {},
    Aliases = {'unview'},
    Description = 'Stop spectating any player',
    Execute = function()
        print('unspectate')
    end
})

RegisterCommand({
    Category = 'CAMERA',
    Name = 'thrucam',
    Args = {},
    Aliases = {},
    Description = 'Allows your camera to pass through objects and zoom out much further',
    Execute = function()
        print('thrucam')
    end
})

RegisterCommand({
    Category = 'CAMERA',
    Name = 'fixcam',
    Args = {},
    Aliases = {},
    Description = 'Undoes any changes made to the camera',
    Execute = function()
        print('fixcam')
    end
})

RegisterCommand({
    Category = 'TELEPORT',
    Name = 'goto',
    Args = {{'player', 'target'}},
    Aliases = {},
    Description = 'Teleport to player',
    Execute = function(Target)
        print('goto', Target, type(Target))
    end
})

RegisterCommand({
    Category = 'TELEPORT',
    Name = 'tp',
    Args = {{'number', 'x'}, {'number', 'y'}, {'number', 'z'}},
    Aliases = {},
    Description = 'Teleport to X Y Z coordinates',
    Execute = function(X, Y, Z)
        print('tp', X, Y, Z, type(X), type(Y), type(Z))
    end
})

RegisterCommand({
    Category = 'WORLD',
    Name = 'gravity',
    Args = {{'number', 'amount'}},
    Aliases = {},
    Description = 'Set the client\'s gravity',
    Execute = function(Amount)
        print('gravity', Amount, type(Amount))
    end
})

RegisterCommand({
    Category = 'WORLD',
    Name = 'resetgravity',
    Args = {},
    Aliases = {},
    Description = 'Reset the client\'s gravity to default',
    Execute = function()
        print('resetgravity')
    end
})

RegisterCommand({
    Category = 'SERVER',
    Name = 'rejoin',
    Args = {},
    Aliases = {'rj'},
    Description = 'Rejoin the server',
    Execute = function()
        print('rejoin')
    end
})

RegisterCommand({
    Category = 'SERVER',
    Name = 'serverhop',
    Args = {},
    Aliases = {'hop'},
    Description = 'Join a different server',
    Execute = function()
        print('serverhop')
    end
})

RegisterCommand({
    Category = 'TESTING',
    Name = 'brokencommand',
    Args = {},
    Aliases = {},
    Description = 'Command that does not work and errors for testing',
    Execute = function()
        error('you ran the brokencommand command')
    end
})

RegisterCommand({
    Category = 'TESTING',
    Name = 'notify',
    Args = {{'string', 'title'}, {'string', 'message'}, {'number', 'duration', true}},
    Aliases = {},
    Description = 'Command that does not work and errors for testing.',
    Execute = function(Title, Message, Duration)
        Notify('Info', Title, Message, Duration)
    end
})

RegisterCommand({
    Category = 'TESTING',
    Name = 'longdesc',
    Args = {},
    Aliases = {},
    Description = 'This description is also going to be super long so we can check and see whether the command items autosize and wrap this text automatically. Hopefully it does!',
    Execute = function()
        print('longdesc')
    end
})

--/ Main /--
G.Tidecaller.Loaded = true
Notify('Success', 'Script Loaded', ('Welcome to Tidecaller. Press %s to open the command palette'):format(HOTKEY))
wait(1)
Notify('Info', 'Credits', 'Script developed by riptxde.')
