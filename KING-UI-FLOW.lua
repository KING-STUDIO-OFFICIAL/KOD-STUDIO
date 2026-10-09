local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local Library = {}
Library.__index = Library

Library.Scheme = {
    AccentColor = Color3.fromRGB(160, 90, 255),
    AccentDark = Color3.fromRGB(90, 30, 160),
    AccentLight = Color3.fromRGB(200, 160, 255),
    Background = Color3.fromRGB(10, 10, 10),
    BackgroundSecondary = Color3.fromRGB(20, 20, 20),
    ButtonOff = Color3.fromRGB(30, 30, 30),
    ButtonHover = Color3.fromRGB(55, 45, 80),
    Text = Color3.fromRGB(255, 255, 255),
    TextDim = Color3.fromRGB(220, 220, 220),
}

Library.ColorPresets = {
    Purple = Color3.fromRGB(160, 90, 255),
    Pink = Color3.fromRGB(255, 105, 180),
    Red = Color3.fromRGB(255, 60, 60),
    Orange = Color3.fromRGB(255, 150, 60),
    Yellow = Color3.fromRGB(255, 220, 60),
    Green = Color3.fromRGB(60, 220, 100),
    Cyan = Color3.fromRGB(60, 220, 220),
    Blue = Color3.fromRGB(60, 130, 255),
    White = Color3.fromRGB(255, 255, 255),
    Rainbow = "rainbow",
}

Library.ColorPresetOrder = { "Purple", "Pink", "Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "White", "Rainbow" }

Library.Options = {}
Library.Toggles = {}
Library.Tabs = {}
Library.Groups = {}
Library.Dropdowns = {}
Library.Sliders = {}
Library.Inputs = {}
Library.Buttons = {}
Library.Labels = {}
Library.KeyPickers = {}

Library.ColorPreset = "Purple"
Library.CurrentColor = Library.Scheme.AccentColor
Library.RainbowColor = Library.Scheme.AccentColor
Library.Unloaded = false
Library.ShowCustomCursor = false
Library.IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
Library.ToggleKeybind = nil
Library.OnUnloadCallback = nil
Library.NotificationsEnabled = true
Library.NotifySide = "Right"
Library.Version = "1.0.0"
Library.DefaultWindowSize = UDim2.fromOffset(320, 560)
Library.MinWindowSize = Vector2.new(300, 400)
Library.MaxWindowSize = Vector2.new(700, 900)

local State = {
    Windows = {},
    ActiveNotifications = {},
    NotifyContainer = nil,
}

local function playClickSound()
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://6042053626"
        sound.Volume = 0.5
        sound.Parent = CoreGui
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 1)
    end)
end

local function safeTween(instance, info, properties)
    if not instance or not instance.Parent then return nil end
    local ok, tween = pcall(function()
        return TweenService:Create(instance, info, properties)
    end)
    if ok and tween then
        pcall(function() tween:Play() end)
        return tween
    end
    return nil
end

local function isRainbow()
    return Library.ColorPreset == "Rainbow"
end

function Library:GetActiveColor()
    if isRainbow() then
        return Library.RainbowColor or Library.Scheme.AccentColor
    end
    return Library.CurrentColor
end

function Library:SetAccentColor(color)
    Library.CurrentColor = color
    Library.Scheme.AccentColor = color
    Library:RefreshAllColors()
end

function Library:SetColorPreset(presetName)
    Library.ColorPreset = presetName
    if presetName == "Rainbow" then
        Library.CurrentColor = Library.Scheme.AccentColor
    else
        Library.CurrentColor = Library.ColorPresets[presetName] or Library.Scheme.AccentColor
        Library.Scheme.AccentColor = Library.CurrentColor
    end
    Library:RefreshAllColors()
end

function Library:RefreshAllColors()
    local color = Library:GetActiveColor()
    for _, win in ipairs(State.Windows) do
        if win.MainStroke then win.MainStroke.Color = color end
        if win.OpenStroke then win.OpenStroke.Color = color end
        if win.CreditsStroke then win.CreditsStroke.Color = color end
        if win.MinStroke then win.MinStroke.Color = color end
        if win.TitleGlowFrame then win.TitleGlowFrame.BackgroundColor3 = color end
        if win.GripCorner then win.GripCorner.BackgroundColor3 = color end
        for _, tab in ipairs(win.Tabs) do
            if tab.Button and tab.Button:GetAttribute("Active") then
                tab.Button.BackgroundColor3 = color
            end
        end
    end
    for _, toggle in pairs(Library.Toggles) do
        if toggle.Holder and toggle.Value then
            toggle.Holder.BackgroundColor3 = color
        end
    end
    for _, group in pairs(Library.Groups) do
        if group.Stroke then group.Stroke.Color = color end
    end
    for _, slider in pairs(Library.Sliders) do
        if slider.Fill then slider.Fill.BackgroundColor3 = color end
        if slider.Knob then slider.Knob.BackgroundColor3 = color end
    end
    Library:UpdateParticleColors()
end

function Library:UpdateParticleColors()
    for _, win in ipairs(State.Windows) do
        if win.Particles then
            local color = Library:GetActiveColor()
            for _, p in ipairs(win.Particles) do
                if p and p.Parent then
                    p.BackgroundColor3 = color
                    local glow = p:FindFirstChild("Glow")
                    if glow then glow.BackgroundColor3 = color end
                end
            end
        end
    end
end

function Library:Notify(data)
    if not Library.NotificationsEnabled then return end
    data = data or {}
    local Title = data.Title or "Notification"
    local Description = data.Description or data.Text or data.Content or ""
    local Duration = data.Time or data.Duration or 3
    local isError = data.Error == true or data.Type == "Error"

    local NotifyGui = State.NotifyContainer
    if not NotifyGui or not NotifyGui.Parent then
        NotifyGui = Instance.new("ScreenGui")
        NotifyGui.Name = "UILib_Notifications"
        NotifyGui.ResetOnSpawn = false
        NotifyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        if gethui then
            NotifyGui.Parent = gethui()
        elseif syn and syn.protect_gui then
            syn.protect_gui(NotifyGui)
            NotifyGui.Parent = CoreGui
        else
            NotifyGui.Parent = CoreGui
        end
        State.NotifyContainer = NotifyGui
    end

    local RightSide = Library.NotifySide == "Right"
    local StackIndex = #State.ActiveNotifications + 1

    local NotifFrame = Instance.new("Frame")
    NotifFrame.Name = "Notification"
    NotifFrame.AnchorPoint = Vector2.new(RightSide and 1 or 0, 1)
    NotifFrame.Size = UDim2.new(0, 300, 0, 60)
    NotifFrame.BackgroundColor3 = Library.Scheme.Background
    NotifFrame.BackgroundTransparency = 0.05
    NotifFrame.BorderSizePixel = 0
    NotifFrame.ZIndex = 100

    local startPosY = 1 - (StackIndex * 0.09)
    NotifFrame.Position = UDim2.new(RightSide and 1 or 0, RightSide and 320 or -320, startPosY, 0)
    NotifFrame.Parent = NotifyGui

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = NotifFrame

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = isError and Color3.fromRGB(255, 60, 60) or Library:GetActiveColor()
    Stroke.Thickness = 2
    Stroke.Transparency = 0.3
    Stroke.Parent = NotifFrame

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -20, 0, 22)
    TitleLabel.Position = UDim2.new(0, 10, 0, 6)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = Title
    TitleLabel.Font = Enum.Font.Arcade
    TitleLabel.TextSize = 14
    TitleLabel.TextColor3 = isError and Color3.fromRGB(255, 100, 100) or Library:GetActiveColor()
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.ZIndex = 101
    TitleLabel.Parent = NotifFrame

    local DescLabel = Instance.new("TextLabel")
    DescLabel.Size = UDim2.new(1, -20, 0, 24)
    DescLabel.Position = UDim2.new(0, 10, 0, 28)
    DescLabel.BackgroundTransparency = 1
    DescLabel.Text = Description
    DescLabel.Font = Enum.Font.Arcade
    DescLabel.TextSize = 12
    DescLabel.TextColor3 = Library.Scheme.TextDim
    DescLabel.TextXAlignment = Enum.TextXAlignment.Left
    DescLabel.TextWrapped = true
    DescLabel.ZIndex = 101
    DescLabel.Parent = NotifFrame

    local targetX = RightSide and -12 or 12
    safeTween(NotifFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(RightSide and 1 or 0, targetX, startPosY, 0)
    })

    local notifEntry = { Frame = NotifFrame, Stroke = Stroke, Title = TitleLabel, Index = StackIndex }
    table.insert(State.ActiveNotifications, notifEntry)

    task.delay(Duration, function()
        safeTween(NotifFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Position = UDim2.new(RightSide and 1 or 0, RightSide and 320 or -320, startPosY, 0)
        })
        task.wait(0.35)
        for i, entry in ipairs(State.ActiveNotifications) do
            if entry.Frame == NotifFrame then
                table.remove(State.ActiveNotifications, i)
                break
            end
        end
        if NotifFrame then NotifFrame:Destroy() end
    end)
end

local function createParticleBackground(parent, count)
    local ParticleHolder = Instance.new("Frame")
    ParticleHolder.Name = "ParticleHolder"
    ParticleHolder.Size = UDim2.fromScale(1, 1)
    ParticleHolder.BackgroundTransparency = 1
    ParticleHolder.BorderSizePixel = 0
    ParticleHolder.ZIndex = 0
    ParticleHolder.ClipsDescendants = true
    ParticleHolder.Parent = parent

    local particles = {}
    local color = Library:GetActiveColor()

    for i = 1, count do
        local size = math.random(2, 6)
        local p = Instance.new("Frame")
        p.Name = "Particle" .. i
        p.BackgroundColor3 = color
        p.BackgroundTransparency = math.random(60, 90) / 100
        p.BorderSizePixel = 0
        p.Size = UDim2.new(0, size, 0, size)
        p.Position = UDim2.new(math.random(0, 100) / 100, 0, math.random(0, 100) / 100, 0)
        p.ZIndex = 0
        p.Parent = ParticleHolder

        local pCorner = Instance.new("UICorner")
        pCorner.CornerRadius = UDim.new(1, 0)
        pCorner.Parent = p

        if i <= math.floor(count * 0.4) then
            local glow = Instance.new("Frame")
            glow.Name = "Glow"
            glow.AnchorPoint = Vector2.new(0.5, 0.5)
            glow.Position = UDim2.new(0.5, 0, 0.5, 0)
            glow.Size = UDim2.new(1, 4, 1, 4)
            glow.BackgroundColor3 = color
            glow.BackgroundTransparency = 0.9
            glow.BorderSizePixel = 0
            glow.ZIndex = 0
            glow.Parent = p

            local gCorner = Instance.new("UICorner")
            gCorner.CornerRadius = UDim.new(1, 0)
            gCorner.Parent = glow

            safeTween(glow,
                TweenInfo.new(math.random(2, 4), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { BackgroundTransparency = 0.95, Size = UDim2.new(1, 8, 1, 8) })
        end

        safeTween(p,
            TweenInfo.new(math.random(8, 25), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {
                Position = UDim2.new(math.random(0, 100) / 100, 0, math.random(0, 100) / 100, 0),
                BackgroundTransparency = math.random(40, 95) / 100,
                Rotation = math.random(-180, 180),
            })

        table.insert(particles, p)
    end

    return ParticleHolder, particles
end

local function pulseButton(btn)
    if not btn or not btn.Parent then return end
    local originalSize = btn:GetAttribute("OriginalSize") or btn.Size
    btn:SetAttribute("OriginalSize", originalSize)
    local shrink = UDim2.new(
        originalSize.X.Scale, originalSize.X.Offset - 4,
        originalSize.Y.Scale, originalSize.Y.Offset - 4
    )
    local tweenIn = safeTween(btn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = shrink })
    if not tweenIn then return end
    tweenIn.Completed:Connect(function()
        if not btn or not btn.Parent then return end
        safeTween(btn, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = originalSize })
    end)
end

local function flashButton(btn, color)
    if not btn or not btn.Parent then return end
    local flash = Instance.new("Frame")
    flash.Name = "FlashOverlay"
    flash.BackgroundColor3 = color or Color3.new(1, 1, 1)
    flash.BackgroundTransparency = 0.4
    flash.BorderSizePixel = 0
    flash.Size = UDim2.fromScale(1, 1)
    flash.ZIndex = 50
    flash.Parent = btn
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = flash
    safeTween(flash, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
    game:GetService("Debris"):AddItem(flash, 0.3)
end

Library.PulseButton = pulseButton
Library.FlashButton = flashButton

local Window = {}
Window.__index = Window

function Library:CreateWindow(config)
    config = config or {}
    local Title = config.Title or "Window"
    local Subtitle = config.Subtitle or ""
    local Footer = config.Footer or ""
    local DefaultWidth = config.Size and config.Size.X.Offset or Library.DefaultWindowSize.X.Offset
    local DefaultHeight = config.Size and config.Size.Y.Offset or Library.DefaultWindowSize.Y.Offset
    local Icon = config.Icon or ""
    local ParticleCount = config.Particles or 24
    local ShowCredits = (Footer ~= "" and Footer ~= nil)
    local ScreenGuiName = config.Name or "UILib_Window"

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = ScreenGuiName
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    if gethui then
        ScreenGui.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = CoreGui
    else
        ScreenGui.Parent = CoreGui
    end

    local OpenButton = Instance.new("ImageButton")
    OpenButton.Name = "OpenButton"
    OpenButton.AnchorPoint = Vector2.new(0.5, 0.5)
    OpenButton.Size = UDim2.new(0, 60, 0, 60)
    OpenButton.Position = UDim2.new(0.1, 0, 0.1, 0)
    OpenButton.BackgroundColor3 = Library.Scheme.Background
    OpenButton.BorderColor3 = Library.Scheme.AccentColor
    OpenButton.BorderSizePixel = 2
    OpenButton.Image = Icon
    OpenButton.Visible = false
    OpenButton.Parent = ScreenGui

    local OpenCorner = Instance.new("UICorner")
    OpenCorner.CornerRadius = UDim.new(1, 0)
    OpenCorner.Parent = OpenButton

    local OpenStroke = Instance.new("UIStroke")
    OpenStroke.Thickness = 2
    OpenStroke.Color = Library.Scheme.AccentColor
    OpenStroke.Transparency = 0.3
    OpenStroke.Parent = OpenButton

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 0, 0, 0)
    MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    MainFrame.BackgroundColor3 = Library.Scheme.Background
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Visible = true
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 12)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Thickness = 2
    MainStroke.Transparency = 1
    MainStroke.Color = Library.Scheme.AccentColor
    MainStroke.Parent = MainFrame

    local ParticleHolder, Particles = createParticleBackground(MainFrame, ParticleCount)

    local ContentLayer = Instance.new("Frame")
    ContentLayer.Name = "ContentLayer"
    ContentLayer.Size = UDim2.fromScale(1, 1)
    ContentLayer.BackgroundTransparency = 1
    ContentLayer.BorderSizePixel = 0
    ContentLayer.ZIndex = 10
    ContentLayer.Visible = false
    ContentLayer.ClipsDescendants = true
    ContentLayer.Parent = MainFrame

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "Title"
    TitleLabel.Size = UDim2.new(1, 0, 0, 26)
    TitleLabel.Position = UDim2.new(0, 0, 0, 10)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = ""
    TitleLabel.Font = Enum.Font.Arcade
    TitleLabel.TextSize = 22
    TitleLabel.TextColor3 = Library.Scheme.Text
    TitleLabel.TextStrokeColor3 = Library.Scheme.AccentColor
    TitleLabel.TextStrokeTransparency = 0.3
    TitleLabel.ZIndex = 20
    TitleLabel.Parent = ContentLayer

    local TitleShadow = Instance.new("TextLabel")
    TitleShadow.Name = "TitleShadow"
    TitleShadow.Size = UDim2.new(1, 0, 0, 26)
    TitleShadow.Position = UDim2.new(0, 2, 0, 12)
    TitleShadow.BackgroundTransparency = 1
    TitleShadow.Text = ""
    TitleShadow.Font = Enum.Font.Arcade
    TitleShadow.TextSize = 22
    TitleShadow.TextColor3 = Color3.fromRGB(0, 0, 0)
    TitleShadow.TextTransparency = 0.7
    TitleShadow.ZIndex = 19
    TitleShadow.Parent = ContentLayer

    local TitleGlowFrame = Instance.new("Frame")
    TitleGlowFrame.Name = "TitleGlow"
    TitleGlowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    TitleGlowFrame.Position = UDim2.new(0.5, 0, 0, 23)
    TitleGlowFrame.Size = UDim2.new(0, 200, 0, 26)
    TitleGlowFrame.BackgroundColor3 = Library.Scheme.AccentColor
    TitleGlowFrame.BackgroundTransparency = 0.85
    TitleGlowFrame.BorderSizePixel = 0
    TitleGlowFrame.ZIndex = 18
    TitleGlowFrame.Parent = ContentLayer

    local TitleGlowCorner = Instance.new("UICorner")
    TitleGlowCorner.CornerRadius = UDim.new(0, 12)
    TitleGlowCorner.Parent = TitleGlowFrame

    local SubtitleLabel = Instance.new("TextLabel")
    SubtitleLabel.Name = "Subtitle"
    SubtitleLabel.Size = UDim2.new(1, 0, 0, 18)
    SubtitleLabel.Position = UDim2.new(0, 0, 0, 38)
    SubtitleLabel.BackgroundTransparency = 1
    SubtitleLabel.Text = Subtitle
    SubtitleLabel.Font = Enum.Font.Arcade
    SubtitleLabel.TextSize = 13
    SubtitleLabel.TextColor3 = Library.Scheme.AccentLight
    SubtitleLabel.TextTransparency = 0.2
    SubtitleLabel.ZIndex = 20
    SubtitleLabel.Parent = ContentLayer

    local MinimizeButton = Instance.new("ImageButton")
    MinimizeButton.Name = "MinimizeButton"
    MinimizeButton.Size = UDim2.new(0, 26, 0, 26)
    MinimizeButton.Position = UDim2.new(1, -34, 0, 8)
    MinimizeButton.BackgroundColor3 = Library.Scheme.BackgroundSecondary
    MinimizeButton.Image = Icon
    MinimizeButton.BorderSizePixel = 0
    MinimizeButton.ZIndex = 20
    MinimizeButton.Parent = ContentLayer

    local MinCorner = Instance.new("UICorner")
    MinCorner.CornerRadius = UDim.new(0, 6)
    MinCorner.Parent = MinimizeButton

    local MinStroke = Instance.new("UIStroke")
    MinStroke.Color = Library.Scheme.AccentColor
    MinStroke.Thickness = 1
    MinStroke.Transparency = 0.4
    MinStroke.Parent = MinimizeButton

    local CreditsPanel, CreditsStroke, CreditsLabel
    if ShowCredits then
        CreditsPanel = Instance.new("Frame")
        CreditsPanel.Name = "CreditsPanel"
        CreditsPanel.Size = UDim2.new(1, -20, 0, 36)
        CreditsPanel.Position = UDim2.new(0, 10, 1, -42)
        CreditsPanel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        CreditsPanel.BackgroundTransparency = 0.4
        CreditsPanel.ZIndex = 20
        CreditsPanel.Parent = ContentLayer

        local CreditsCorner = Instance.new("UICorner")
        CreditsCorner.CornerRadius = UDim.new(0, 8)
        CreditsCorner.Parent = CreditsPanel

        CreditsStroke = Instance.new("UIStroke")
        CreditsStroke.Thickness = 2
        CreditsStroke.Color = Library.Scheme.AccentColor
        CreditsStroke.Transparency = 0.3
        CreditsStroke.Parent = CreditsPanel

        CreditsLabel = Instance.new("TextLabel")
        CreditsLabel.Name = "CreditsLabel"
        CreditsLabel.Size = UDim2.new(1, 0, 1, 0)
        CreditsLabel.BackgroundTransparency = 1
        CreditsLabel.Text = Footer
        CreditsLabel.Font = Enum.Font.Arcade
        CreditsLabel.TextSize = 11
        CreditsLabel.TextColor3 = Library.Scheme.Text
        CreditsLabel.TextWrapped = true
        CreditsLabel.ZIndex = 21
        CreditsLabel.Parent = CreditsPanel
    end

    local TabBar = Instance.new("Frame")
    TabBar.Name = "TabBar"
    TabBar.Size = UDim2.new(1, -20, 0, 34)
    TabBar.Position = UDim2.new(0, 10, 0, 62)
    TabBar.BackgroundColor3 = Library.Scheme.BackgroundSecondary
    TabBar.BorderSizePixel = 0
    TabBar.ZIndex = 20
    TabBar.Parent = ContentLayer

    local TabBarCorner = Instance.new("UICorner")
    TabBarCorner.CornerRadius = UDim.new(0, 6)
    TabBarCorner.Parent = TabBar

    local TabLayout = Instance.new("UIListLayout")
    TabLayout.FillDirection = Enum.FillDirection.Horizontal
    TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabLayout.Padding = UDim.new(0, 4)
    TabLayout.Parent = TabBar

    local TabPadding = Instance.new("UIPadding")
    TabPadding.PaddingLeft = UDim.new(0, 4)
    TabPadding.PaddingRight = UDim.new(0, 4)
    TabPadding.PaddingTop = UDim.new(0, 4)
    TabPadding.PaddingBottom = UDim.new(0, 4)
    TabPadding.Parent = TabBar

    local PagesFrame = Instance.new("Frame")
    PagesFrame.Name = "PagesFrame"
    PagesFrame.Size = UDim2.new(1, -10, 1, -150)
    PagesFrame.Position = UDim2.new(0, 5, 0, 104)
    PagesFrame.BackgroundTransparency = 1
    PagesFrame.ZIndex = 20
    PagesFrame.ClipsDescendants = true
    PagesFrame.Parent = ContentLayer

    local ResizeGrip = Instance.new("ImageButton")
    ResizeGrip.Name = "ResizeGrip"
    ResizeGrip.AnchorPoint = Vector2.new(1, 1)
    ResizeGrip.Position = UDim2.new(1, -2, 1, -2)
    ResizeGrip.Size = UDim2.new(0, 22, 0, 22)
    ResizeGrip.BackgroundTransparency = 1
    ResizeGrip.BorderSizePixel = 0
    ResizeGrip.Image = ""
    ResizeGrip.AutoButtonColor = false
    ResizeGrip.ZIndex = 30
    ResizeGrip.Parent = ContentLayer

    local GripCorner = Instance.new("Frame")
    GripCorner.Name = "GripCorner"
    GripCorner.AnchorPoint = Vector2.new(1, 1)
    GripCorner.Position = UDim2.new(1, 0, 1, 0)
    GripCorner.Size = UDim2.new(0, 12, 0, 12)
    GripCorner.BackgroundColor3 = Library.Scheme.AccentColor
    GripCorner.BorderSizePixel = 0
    GripCorner.ZIndex = 30
    GripCorner.Parent = ResizeGrip

    local GripCornerCorner = Instance.new("UICorner")
    GripCornerCorner.CornerRadius = UDim.new(0, 3)
    GripCornerCorner.Parent = GripCorner

    local GripLine1 = Instance.new("Frame")
    GripLine1.AnchorPoint = Vector2.new(1, 1)
    GripLine1.Position = UDim2.new(1, -3, 1, -3)
    GripLine1.Size = UDim2.new(0, 6, 0, 1)
    GripLine1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    GripLine1.BackgroundTransparency = 0.3
    GripLine1.BorderSizePixel = 0
    GripLine1.ZIndex = 31
    GripLine1.Parent = ResizeGrip

    local GripLine2 = Instance.new("Frame")
    GripLine2.AnchorPoint = Vector2.new(1, 1)
    GripLine2.Position = UDim2.new(1, -3, 1, -3)
    GripLine2.Size = UDim2.new(0, 1, 0, 6)
    GripLine2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    GripLine2.BackgroundTransparency = 0.3
    GripLine2.BorderSizePixel = 0
    GripLine2.ZIndex = 31
    GripLine2.Parent = ResizeGrip

    local windowState = {
        MainFrame = MainFrame,
        ContentLayer = ContentLayer,
        MainStroke = MainStroke,
        OpenButton = OpenButton,
        OpenStroke = OpenStroke,
        CreditsPanel = CreditsPanel,
        CreditsStroke = CreditsStroke,
        TitleLabel = TitleLabel,
        TitleShadow = TitleShadow,
        TitleGlowFrame = TitleGlowFrame,
        TabBar = TabBar,
        PagesFrame = PagesFrame,
        ResizeGrip = ResizeGrip,
        GripCorner = GripCorner,
        Particles = Particles,
        ParticleHolder = ParticleHolder,
        Tabs = {},
        IsOpen = false,
        IsAnimating = false,
        TitleAnimThread = nil,
        TitleAnimStop = false,
        Resizing = false,
        ResizeStartMouse = nil,
        ResizeStartSize = nil,
        ScreenGui = ScreenGui,
        Icon = Icon,
        Title = Title,
        DefaultWidth = DefaultWidth,
        DefaultHeight = DefaultHeight,
        ShowCredits = ShowCredits,
    }

    table.insert(State.Windows, windowState)

    function windowState:SetFooter(text)
        if CreditsLabel then
            CreditsLabel.Text = text
        end
    end

    function windowState:SetTitle(text)
        self.Title = text
    end

    function windowState:SetSubtitle(text)
        SubtitleLabel.Text = text
    end

    function windowState:StartTitleAnimation()
        if self.TitleAnimThread then
            self.TitleAnimStop = true
            task.wait(0.1)
        end
        self.TitleAnimStop = false
        local animTitle = self.Title

        self.TitleAnimThread = task.spawn(function()
            while not self.TitleAnimStop do
                if not self.TitleLabel or not self.TitleLabel.Parent then break end

                for i = 1, #animTitle do
                    if self.TitleAnimStop or not self.TitleLabel or not self.TitleLabel.Parent then break end
                    local currentText = string.sub(animTitle, 1, i)
                    if self.TitleLabel then self.TitleLabel.Text = currentText end
                    if self.TitleShadow then self.TitleShadow.Text = currentText end
                    if self.TitleLabel then
                        self.TitleLabel.TextSize = 26
                        safeTween(self.TitleLabel, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextSize = 22 })
                    end
                    if self.TitleShadow then
                        self.TitleShadow.TextSize = 26
                        safeTween(self.TitleShadow, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextSize = 22 })
                    end
                    if self.TitleLabel then
                        local originalStroke = self.TitleLabel.TextStrokeColor3
                        local flashColors = {
                            Color3.fromRGB(255, 255, 255),
                            Color3.fromRGB(200, 160, 255),
                            Color3.fromRGB(255, 180, 255),
                        }
                        self.TitleLabel.TextStrokeColor3 = flashColors[math.random(1, 3)]
                        safeTween(self.TitleLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextStrokeColor3 = originalStroke })
                    end
                    if self.TitleGlowFrame then
                        safeTween(self.TitleGlowFrame, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.4 })
                        safeTween(self.TitleGlowFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.85 })
                    end
                    task.wait(0.08)
                end

                task.wait(1.5)

                for i = #animTitle, 0, -1 do
                    if self.TitleAnimStop or not self.TitleLabel or not self.TitleLabel.Parent then break end
                    local currentText = string.sub(animTitle, 1, i)
                    if self.TitleLabel then self.TitleLabel.Text = currentText end
                    if self.TitleShadow then self.TitleShadow.Text = currentText end
                    if self.TitleLabel then self.TitleLabel.TextTransparency = 0.5 end
                    if self.TitleShadow then self.TitleShadow.TextTransparency = 0.85 end
                    task.wait(0.04)
                    if self.TitleLabel then self.TitleLabel.TextTransparency = 0 end
                    if self.TitleShadow then self.TitleShadow.TextTransparency = 0.7 end
                    task.wait(0.03)
                end

                task.wait(0.8)
            end
        end)
    end

    function windowState:Open(instant)
        if self.IsAnimating then return end
        if self.IsOpen and not instant then return end
        self.IsAnimating = true
        self.IsOpen = true

        self.MainFrame.Visible = true
        self.MainFrame.ClipsDescendants = true

        if instant then
            self.MainFrame.Size = UDim2.new(0, self.DefaultWidth, 0, self.DefaultHeight)
            self.MainFrame.Position = UDim2.new(0.5, -self.DefaultWidth / 2, 0.5, -self.DefaultHeight / 2)
            self.MainFrame.Rotation = 0
            self.MainFrame.BackgroundTransparency = 0
            if self.MainStroke then self.MainStroke.Transparency = 0.2 end
            if self.ContentLayer then self.ContentLayer.Visible = true end
            if self.OpenButton then self.OpenButton.Visible = false end
            self.IsAnimating = false
            return
        end

        self.MainFrame.Size = UDim2.new(0, 0, 0, 0)
        self.MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        self.MainFrame.Rotation = 180
        self.MainFrame.BackgroundTransparency = 1
        if self.MainStroke then self.MainStroke.Transparency = 1 end
        if self.ContentLayer then self.ContentLayer.Visible = false end

        safeTween(self.MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, self.DefaultWidth, 0, self.DefaultHeight),
            Position = UDim2.new(0.5, -self.DefaultWidth / 2, 0.5, -self.DefaultHeight / 2),
            Rotation = 0,
            BackgroundTransparency = 0,
        })
        if self.MainStroke then
            safeTween(self.MainStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 0.2 })
        end

        task.delay(0.5, function()
            if self.ContentLayer then self.ContentLayer.Visible = true end
            if self.OpenButton then self.OpenButton.Visible = false end
            task.delay(0.15, function() self.IsAnimating = false end)
        end)
    end

    function windowState:Close()
        if self.IsAnimating then return end
        if not self.IsOpen then return end
        self.IsAnimating = true
        self.IsOpen = false
        playClickSound()

        if self.ContentLayer then self.ContentLayer.Visible = false end

        safeTween(self.MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Rotation = -180,
            BackgroundTransparency = 1,
        })
        if self.MainStroke then
            safeTween(self.MainStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
        end

        task.delay(0.45, function()
            if self.MainFrame then
                self.MainFrame.Visible = false
                self.MainFrame.Rotation = 0
            end
            if self.OpenButton then
                self.OpenButton.Visible = true
                self.OpenButton.Size = UDim2.new(0, 0, 0, 0)
                safeTween(self.OpenButton, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0, 60, 0, 60) })
            end
            task.delay(0.4, function() self.IsAnimating = false end)
        end)
    end

    function windowState:Destroy()
        self.TitleAnimStop = true
        if self.ScreenGui then
            pcall(function() self.ScreenGui:Destroy() end)
        end
    end

    function windowState:AddFullSizeTab(name, icon, tooltip)
        return self:AddTab(name, icon, tooltip)
    end

    function windowState:AddTab(name, icon, tooltip)
        local TabIndex = #self.Tabs + 1

        local TabButton = Instance.new("TextButton")
        TabButton.Name = "Tab_" .. name
        TabButton.Size = UDim2.new(1 / math.max(#self.Tabs + 1, 3), -3, 1, 0)
        TabButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        TabButton.Text = name
        TabButton.TextColor3 = Library.Scheme.Text
        TabButton.Font = Enum.Font.Arcade
        TabButton.TextSize = 13
        TabButton.LayoutOrder = TabIndex
        TabButton.AutoButtonColor = false
        TabButton.ZIndex = 21
        TabButton.Parent = self.TabBar

        local TabCorner = Instance.new("UICorner")
        TabCorner.CornerRadius = UDim.new(0, 5)
        TabCorner.Parent = TabButton

        local Page = Instance.new("ScrollingFrame")
        Page.Name = "Page_" .. name
        Page.Size = UDim2.new(1, 0, 1, 0)
        Page.BackgroundTransparency = 1
        Page.BorderSizePixel = 0
        Page.ScrollBarThickness = 6
        Page.ScrollBarImageColor3 = Library.Scheme.AccentColor
        Page.ScrollBarImageTransparency = 0.4
        Page.CanvasSize = UDim2.new(0, 0, 0, 0)
        Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        Page.Visible = false
        Page.Active = true
        Page.Selectable = true
        Page.ScrollingDirection = Enum.ScrollingDirection.Y
        Page.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
        Page.ZIndex = 21
        Page.Parent = self.PagesFrame

        local PageLayout = Instance.new("UIListLayout")
        PageLayout.Parent = Page
        PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        PageLayout.Padding = UDim.new(0, 8)

        TabButton.MouseEnter:Connect(function()
            if not TabButton:GetAttribute("Active") then
                safeTween(TabButton, TweenInfo.new(0.15), { BackgroundColor3 = Library.Scheme.ButtonHover })
            end
        end)
        TabButton.MouseLeave:Connect(function()
            if not TabButton:GetAttribute("Active") then
                safeTween(TabButton, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(35, 35, 35) })
            end
        end)

        local tab = {
            Name = name,
            Icon = icon,
            Tooltip = tooltip,
            Button = TabButton,
            Page = Page,
            Window = self,
            Groups = {},
        }

        function tab:Show()
            for _, t in ipairs(self.Window.Tabs) do
                t.Button:SetAttribute("Active", false)
                safeTween(t.Button, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(35, 35, 35) })
                t.Page.Visible = false
            end
            TabButton:SetAttribute("Active", true)
            safeTween(TabButton, TweenInfo.new(0.2), { BackgroundColor3 = Library:GetActiveColor() })
            Page.Visible = true
        end

        function tab:AddGroupbox(name, icon)
            return self:CreateGroupbox(name, icon)
        end

        function tab:AddLeftGroupbox(name, icon)
            return self:CreateGroupbox(name, icon)
        end

        function tab:AddRightGroupbox(name, icon)
            return self:CreateGroupbox(name, icon)
        end

        function tab:AddFullSizeGroupbox(name, icon)
            return self:CreateGroupbox(name, icon)
        end

        function tab:CreateGroupbox(name, icon)
            local GroupFrame = Instance.new("Frame")
            GroupFrame.Name = "Group_" .. name
            GroupFrame.Size = UDim2.new(1, -10, 0, 30)
            GroupFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
            GroupFrame.BackgroundTransparency = 0.3
            GroupFrame.BorderSizePixel = 0
            GroupFrame.LayoutOrder = #self.Groups + 1
            GroupFrame.AutomaticSize = Enum.AutomaticSize.Y
            GroupFrame.ZIndex = 22
            GroupFrame.Parent = self.Page

            local GroupCorner = Instance.new("UICorner")
            GroupCorner.CornerRadius = UDim.new(0, 8)
            GroupCorner.Parent = GroupFrame

            local GroupStroke = Instance.new("UIStroke")
            GroupStroke.Color = Library:GetActiveColor()
            GroupStroke.Thickness = 1
            GroupStroke.Transparency = 0.5
            GroupStroke.Parent = GroupFrame

            local GroupTitle = Instance.new("TextLabel")
            GroupTitle.Name = "Title"
            GroupTitle.Size = UDim2.new(1, -10, 0, 24)
            GroupTitle.Position = UDim2.new(0, 5, 0, 4)
            GroupTitle.BackgroundTransparency = 1
            GroupTitle.Text = name
            GroupTitle.Font = Enum.Font.Arcade
            GroupTitle.TextSize = 13
            GroupTitle.TextColor3 = Library.Scheme.AccentLight
            GroupTitle.TextXAlignment = Enum.TextXAlignment.Left
            GroupTitle.ZIndex = 23
            GroupTitle.Parent = GroupFrame

            local GroupContent = Instance.new("Frame")
            GroupContent.Name = "Content"
            GroupContent.Size = UDim2.new(1, 0, 0, 0)
            GroupContent.Position = UDim2.new(0, 0, 0, 30)
            GroupContent.BackgroundTransparency = 1
            GroupContent.BorderSizePixel = 0
            GroupContent.AutomaticSize = Enum.AutomaticSize.Y
            GroupContent.ZIndex = 23
            GroupContent.Parent = GroupFrame

            local ContentPadding = Instance.new("UIPadding")
            ContentPadding.PaddingLeft = UDim.new(0, 5)
            ContentPadding.PaddingRight = UDim.new(0, 5)
            ContentPadding.PaddingBottom = UDim.new(0, 5)
            ContentPadding.Parent = GroupContent

            local ContentLayout = Instance.new("UIListLayout")
            ContentLayout.Parent = GroupContent
            ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
            ContentLayout.Padding = UDim.new(0, 6)

            local groupObj = {
                Name = name,
                Icon = icon,
                Frame = GroupFrame,
                Content = GroupContent,
                Title = GroupTitle,
                Stroke = GroupStroke,
                Layout = ContentLayout,
                Items = {},
                Tab = self,
            }

            function groupObj:AddToggle(key, config)
                config = config or {}
                local text = config.Text or key
                local default = config.Default == true
                local callback = config.Callback or function() end

                local ToggleButton = Instance.new("TextButton")
                ToggleButton.Name = "Toggle_" .. key
                ToggleButton.Size = UDim2.new(1, 0, 0, 30)
                ToggleButton.BackgroundColor3 = default and Library:GetActiveColor() or Library.Scheme.ButtonOff
                ToggleButton.Text = text .. (default and ": ON" or ": OFF")
                ToggleButton.TextColor3 = Library.Scheme.Text
                ToggleButton.Font = Enum.Font.Arcade
                ToggleButton.TextSize = 12
                ToggleButton.LayoutOrder = #self.Items + 1
                ToggleButton.AutoButtonColor = false
                ToggleButton.ZIndex = 24
                ToggleButton.Parent = self.Content

                local ToggleCorner = Instance.new("UICorner")
                ToggleCorner.CornerRadius = UDim.new(0, 6)
                ToggleCorner.Parent = ToggleButton

                local ToggleStroke = Instance.new("UIStroke")
                ToggleStroke.Color = Library:GetActiveColor()
                ToggleStroke.Thickness = 1
                ToggleStroke.Transparency = 0.5
                ToggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                ToggleStroke.Parent = ToggleButton

                local ToggleObj = {
                    Key = key,
                    Text = text,
                    Holder = ToggleButton,
                    Stroke = ToggleStroke,
                    Value = default,
                    Type = "Toggle",
                }

                function ToggleObj:Get()
                    return self.Value
                end

                function ToggleObj:Set(value)
                    self.Value = value == true
                    ToggleButton:SetAttribute("Active", self.Value)
                    ToggleButton:SetAttribute("BaseColor", self.Value and Library:GetActiveColor() or Library.Scheme.ButtonOff)
                    safeTween(ToggleButton, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        BackgroundColor3 = self.Value and Library:GetActiveColor() or Library.Scheme.ButtonOff
                    })
                    ToggleButton.Text = self.Text .. (self.Value and ": ON" or ": OFF")
                    pcall(callback, self.Value)
                end

                function ToggleObj:SetValue(value)
                    self:Set(value)
                end

                ToggleButton.MouseEnter:Connect(function()
                    if not ToggleObj.Value then
                        safeTween(ToggleButton, TweenInfo.new(0.15), { BackgroundColor3 = Library.Scheme.ButtonHover })
                    end
                end)
                ToggleButton.MouseLeave:Connect(function()
                    if not ToggleObj.Value then
                        safeTween(ToggleButton, TweenInfo.new(0.15), { BackgroundColor3 = Library.Scheme.ButtonOff })
                    end
                end)
                ToggleButton.MouseButton1Down:Connect(function()
                    pulseButton(ToggleButton)
                    flashButton(ToggleButton, ToggleObj.Value and Library:GetActiveColor() or Library.Scheme.AccentColor)
                end)
                ToggleButton.MouseButton1Click:Connect(function()
                    playClickSound()
                    ToggleObj:Set(not ToggleObj.Value)
                end)

                table.insert(self.Items, ToggleObj)
                Library.Toggles[key] = ToggleObj
                Library.Options[key] = ToggleObj
                return ToggleObj
            end

            function groupObj:AddButton(config)
                config = config or {}
                local text = config.Text or config.Name or "Button"
                local func = config.Func or config.Callback or function() end
                local bgColor = config.Color or Library.Scheme.BackgroundSecondary

                local Button = Instance.new("TextButton")
                Button.Name = "Button_" .. text
                Button.Size = UDim2.new(1, 0, 0, 30)
                Button.BackgroundColor3 = bgColor
                Button.Text = text
                Button.TextColor3 = Library.Scheme.Text
                Button.Font = Enum.Font.Arcade
                Button.TextSize = 12
                Button.LayoutOrder = #self.Items + 1
                Button.AutoButtonColor = false
                Button.ZIndex = 24
                Button.Parent = self.Content
                Button:SetAttribute("BaseColor", bgColor)

                local ButtonCorner = Instance.new("UICorner")
                ButtonCorner.CornerRadius = UDim.new(0, 6)
                ButtonCorner.Parent = Button

                local ButtonStroke = Instance.new("UIStroke")
                ButtonStroke.Color = Library:GetActiveColor()
                ButtonStroke.Thickness = 1
                ButtonStroke.Transparency = 0.5
                ButtonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                ButtonStroke.Parent = Button

                local ButtonObj = {
                    Text = text,
                    Holder = Button,
                    Func = func,
                    Type = "Button",
                }

                Button.MouseEnter:Connect(function()
                    safeTween(Button, TweenInfo.new(0.15), { BackgroundColor3 = Library.Scheme.ButtonHover })
                end)
                Button.MouseLeave:Connect(function()
                    safeTween(Button, TweenInfo.new(0.15), { BackgroundColor3 = bgColor })
                end)
                Button.MouseButton1Down:Connect(function()
                    pulseButton(Button)
                    flashButton(Button, Library:GetActiveColor())
                end)
                Button.MouseButton1Click:Connect(function()
                    playClickSound()
                    pcall(func)
                end)

                table.insert(self.Items, ButtonObj)
                Library.Buttons[text] = ButtonObj
                return ButtonObj
            end

            function groupObj:AddLabel(text, wraps)
                local Label = Instance.new("TextLabel")
                Label.Name = "Label"
                Label.Size = UDim2.new(1, 0, 0, wraps and 30 or 20)
                Label.BackgroundTransparency = 1
                Label.Text = text
                Label.TextColor3 = Library.Scheme.TextDim
                Label.Font = Enum.Font.Arcade
                Label.TextSize = 12
                Label.TextWrapped = wraps == true
                Label.LayoutOrder = #self.Items + 1
                Label.TextXAlignment = Enum.TextXAlignment.Left
                Label.ZIndex = 24
                Label.AutomaticSize = Enum.AutomaticSize.Y
                Label.Parent = self.Content

                local LabelObj = {
                    Text = text,
                    Holder = Label,
                    Type = "Label",
                }

                function LabelObj:SetText(newText)
                    Label.Text = newText
                end

                function LabelObj:Set(newText)
                    Label.Text = newText
                end

                table.insert(self.Items, LabelObj)
                Library.Labels[text] = LabelObj
                return LabelObj
            end

            function groupObj:AddSlider(key, config)
                config = config or {}
                local text = config.Text or key
                local default = config.Default or 50
                local minVal = config.Min or 0
                local maxVal = config.Max or 100
                local suffix = config.Suffix or ""
                local prefix = config.Prefix or ""
                local callback = config.Callback or function() end

                local SliderLabel = Instance.new("TextLabel")
                SliderLabel.Name = "SliderLabel"
                SliderLabel.Size = UDim2.new(1, 0, 0, 20)
                SliderLabel.BackgroundTransparency = 1
                SliderLabel.Text = text .. ": " .. prefix .. tostring(default) .. suffix
                SliderLabel.TextColor3 = Library.Scheme.TextDim
                SliderLabel.Font = Enum.Font.Arcade
                SliderLabel.TextSize = 12
                SliderLabel.LayoutOrder = #self.Items + 1
                SliderLabel.TextXAlignment = Enum.TextXAlignment.Left
                SliderLabel.ZIndex = 24
                SliderLabel.Parent = self.Content

                local SliderButton = Instance.new("TextButton")
                SliderButton.Name = "Slider_" .. key
                SliderButton.Size = UDim2.new(1, 0, 0, 16)
                SliderButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
                SliderButton.Text = ""
                SliderButton.AutoButtonColor = false
                SliderButton.LayoutOrder = #self.Items + 2
                SliderButton.ZIndex = 24
                SliderButton.Parent = self.Content

                local SliderCorner = Instance.new("UICorner")
                SliderCorner.CornerRadius = UDim.new(1, 0)
                SliderCorner.Parent = SliderButton

                local SliderFill = Instance.new("Frame")
                SliderFill.Name = "Fill"
                SliderFill.Size = UDim2.new(math.clamp((default - minVal) / (maxVal - minVal), 0, 1), 0, 1, 0)
                SliderFill.BackgroundColor3 = Library:GetActiveColor()
                SliderFill.BorderSizePixel = 0
                SliderFill.ZIndex = 25
                SliderFill.Parent = SliderButton

                local FillCorner = Instance.new("UICorner")
                FillCorner.CornerRadius = UDim.new(1, 0)
                FillCorner.Parent = SliderFill

                local SliderKnob = Instance.new("Frame")
                SliderKnob.Name = "Knob"
                SliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
                SliderKnob.Size = UDim2.new(0, 14, 0, 14)
                SliderKnob.BackgroundColor3 = Library:GetActiveColor()
                SliderKnob.BorderSizePixel = 0
                SliderKnob.ZIndex = 26
                SliderKnob.Position = UDim2.new(math.clamp((default - minVal) / (maxVal - minVal), 0, 1), 0, 0.5, 0)
                SliderKnob.Parent = SliderButton

                local KnobCorner = Instance.new("UICorner")
                KnobCorner.CornerRadius = UDim.new(1, 0)
                KnobCorner.Parent = SliderKnob

                local SliderObj = {
                    Key = key,
                    Text = text,
                    Holder = SliderButton,
                    Fill = SliderFill,
                    Knob = SliderKnob,
                    Label = SliderLabel,
                    Value = default,
                    Min = minVal,
                    Max = maxVal,
                    Suffix = suffix,
                    Prefix = prefix,
                    Type = "Slider",
                }

                local function formatValue(val)
                    return text .. ": " .. prefix .. tostring(val) .. suffix
                end

                local function updateFromMouse(mouseX)
                    local absPos = SliderButton.AbsolutePosition.X
                    local absSize = SliderButton.AbsoluteSize.X
                    if absSize <= 0 then return end
                    local percent = math.clamp((mouseX - absPos) / absSize, 0, 1)
                    SliderFill.Size = UDim2.new(percent, 0, 1, 0)
                    SliderKnob.Position = UDim2.new(percent, 0, 0.5, 0)
                    local value = minVal + (maxVal - minVal) * percent
                    if config.Rounding then
                        value = math.floor(value * (10 ^ config.Rounding)) / (10 ^ config.Rounding)
                    else
                        value = math.floor(value)
                    end
                    SliderObj.Value = value
                    SliderLabel.Text = formatValue(value)
                    pcall(callback, value)
                end

                local isDragging = false

                SliderButton.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        isDragging = true
                        updateFromMouse(input.Position.X)
                    end
                end)
                SliderButton.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        isDragging = false
                    end
                end)
                UserInputService.InputChanged:Connect(function(input)
                    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        updateFromMouse(input.Position.X)
                    end
                end)

                function SliderObj:Set(value)
                    value = math.clamp(value, minVal, maxVal)
                    local percent = (value - minVal) / (maxVal - minVal)
                    SliderFill.Size = UDim2.new(percent, 0, 1, 0)
                    SliderKnob.Position = UDim2.new(percent, 0, 0.5, 0)
                    self.Value = value
                    SliderLabel.Text = formatValue(value)
                    pcall(callback, value)
                end

                function SliderObj:SetValue(value)
                    self:Set(value)
                end

                table.insert(self.Items, SliderObj)
                Library.Sliders[key] = SliderObj
                Library.Options[key] = SliderObj
                return SliderObj
            end

            function groupObj:AddDropdown(key, config)
                config = config or {}
                local text = config.Text or key
                local values = config.Values or {}
                local default = config.Default or (type(values) == "table" and values[1])
                local multi = config.Multi == true
                local callback = config.Callback or function() end

                local DropdownBtn = Instance.new("TextButton")
                DropdownBtn.Name = "Dropdown_" .. key
                DropdownBtn.Size = UDim2.new(1, 0, 0, 30)
                DropdownBtn.BackgroundColor3 = Library.Scheme.BackgroundSecondary
                DropdownBtn.Text = text .. ": " .. tostring(default or "None")
                DropdownBtn.TextColor3 = Library.Scheme.Text
                DropdownBtn.Font = Enum.Font.Arcade
                DropdownBtn.TextSize = 12
                DropdownBtn.LayoutOrder = #self.Items + 1
                DropdownBtn.AutoButtonColor = false
                DropdownBtn.ZIndex = 24
                DropdownBtn.Parent = self.Content

                local DropdownCorner = Instance.new("UICorner")
                DropdownCorner.CornerRadius = UDim.new(0, 6)
                DropdownCorner.Parent = DropdownBtn

                local DropdownStroke = Instance.new("UIStroke")
                DropdownStroke.Color = Library:GetActiveColor()
                DropdownStroke.Thickness = 1
                DropdownStroke.Transparency = 0.5
                DropdownStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                DropdownStroke.Parent = DropdownBtn

                local DropdownObj = {
                    Key = key,
                    Text = text,
                    Values = values,
                    Value = multi and {} or default,
                    Multi = multi,
                    Holder = DropdownBtn,
                    Stroke = DropdownStroke,
                    Type = "Dropdown",
                    IsOpen = false,
                    DropdownFrame = nil,
                }

                function DropdownObj:UpdateText()
                    if self.Multi then
                        local selected = {}
                        for k, v in pairs(self.Value) do
                            if v then table.insert(selected, k) end
                        end
                        self.Holder.Text = text .. ": " .. (#selected > 0 and table.concat(selected, ", ") or "None")
                    else
                        self.Holder.Text = text .. ": " .. tostring(self.Value or "None")
                    end
                end

                function DropdownObj:CloseDropdown()
                    if self.DropdownFrame then
                        self.DropdownFrame:Destroy()
                        self.DropdownFrame = nil
                    end
                    self.IsOpen = false
                end

                function DropdownObj:OpenDropdown()
                    if self.IsOpen then self:CloseDropdown() return end
                    self.IsOpen = true

                    local DropFrame = Instance.new("ScrollingFrame")
                    DropFrame.Name = "DropdownMenu"
                    DropFrame.Size = UDim2.new(1, 0, 0, math.min(#self.Values * 28 + 10, 200))
                    DropFrame.Position = UDim2.new(0, 0, 1, 4)
                    DropFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
                    DropFrame.BorderSizePixel = 0
                    DropFrame.ScrollBarThickness = 4
                    DropFrame.ZIndex = 100
                    DropFrame.Parent = self.Holder

                    local DFCorner = Instance.new("UICorner")
                    DFCorner.CornerRadius = UDim.new(0, 6)
                    DFCorner.Parent = DropFrame

                    local DFStroke = Instance.new("UIStroke")
                    DFStroke.Color = Library:GetActiveColor()
                    DFStroke.Thickness = 1
                    DFStroke.Transparency = 0.4
                    DFStroke.Parent = DropFrame

                    local DFLayout = Instance.new("UIListLayout")
                    DFLayout.Parent = DropFrame
                    DFLayout.SortOrder = Enum.SortOrder.LayoutOrder
                    DFLayout.Padding = UDim.new(0, 2)

                    local DFPadding = Instance.new("UIPadding")
                    DFPadding.PaddingTop = UDim.new(0, 4)
                    DFPadding.PaddingLeft = UDim.new(0, 4)
                    DFPadding.PaddingRight = UDim.new(0, 4)
                    DFPadding.Parent = DropFrame

                    for i, value in ipairs(self.Values) do
                        local Option = Instance.new("TextButton")
                        Option.Size = UDim2.new(1, 0, 0, 24)
                        Option.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                        Option.Text = tostring(value)
                        Option.TextColor3 = Library.Scheme.Text
                        Option.Font = Enum.Font.Arcade
                        Option.TextSize = 12
                        Option.LayoutOrder = i
                        Option.AutoButtonColor = false
                        Option.ZIndex = 101
                        Option.Parent = DropFrame

                        local OptCorner = Instance.new("UICorner")
                        OptCorner.CornerRadius = UDim.new(0, 4)
                        OptCorner.Parent = Option

                        Option.MouseEnter:Connect(function()
                            safeTween(Option, TweenInfo.new(0.1), { BackgroundColor3 = Library.Scheme.ButtonHover })
                        end)
                        Option.MouseLeave:Connect(function()
                            safeTween(Option, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(25, 25, 25) })
                        end)
                        Option.MouseButton1Click:Connect(function()
                            playClickSound()
                            if self.Multi then
                                if type(self.Value) ~= "table" then self.Value = {} end
                                self.Value[value] = not self.Value[value]
                            else
                                self.Value = value
                                self:CloseDropdown()
                            end
                            self:UpdateText()
                            pcall(callback, self.Value)
                        end)
                    end

                    self.DropdownFrame = DropFrame
                end

                function DropdownObj:Set(value)
                    if self.Multi then
                        if type(value) == "table" then
                            self.Value = value
                        end
                    else
                        self.Value = value
                    end
                    self:UpdateText()
                    pcall(callback, self.Value)
                end

                function DropdownObj:SetValue(value)
                    self:Set(value)
                end

                function DropdownObj:SetValues(newValues)
                    self.Values = newValues
                    if self.IsOpen then
                        self:CloseDropdown()
                    end
                end

                function DropdownObj:Refresh(newValues)
                    if newValues then self.Values = newValues end
                    if self.IsOpen then
                        self:CloseDropdown()
                        self:OpenDropdown()
                    end
                end

                DropdownBtn.MouseEnter:Connect(function()
                    safeTween(DropdownBtn, TweenInfo.new(0.15), { BackgroundColor3 = Library.Scheme.ButtonHover })
                end)
                DropdownBtn.MouseLeave:Connect(function()
                    safeTween(DropdownBtn, TweenInfo.new(0.15), { BackgroundColor3 = Library.Scheme.BackgroundSecondary })
                end)
                DropdownBtn.MouseButton1Click:Connect(function()
                    playClickSound()
                    pulseButton(DropdownBtn)
                    flashButton(DropdownBtn, Library:GetActiveColor())
                    self:OpenDropdown()
                end)

                table.insert(self.Items, DropdownObj)
                Library.Dropdowns[key] = DropdownObj
                Library.Options[key] = DropdownObj
                return DropdownObj
            end

            function groupObj:AddInput(key, config)
                config = config or {}
                local text = config.Text or key
                local default = config.Default or ""
                local placeholder = config.Placeholder or config.PlaceholderText or "..."
                local callback = config.Callback or function() end

                local InputLabel = Instance.new("TextLabel")
                InputLabel.Size = UDim2.new(1, 0, 0, 20)
                InputLabel.BackgroundTransparency = 1
                InputLabel.Text = text
                InputLabel.TextColor3 = Library.Scheme.TextDim
                InputLabel.Font = Enum.Font.Arcade
                InputLabel.TextSize = 12
                InputLabel.LayoutOrder = #self.Items + 1
                InputLabel.TextXAlignment = Enum.TextXAlignment.Left
                InputLabel.ZIndex = 24
                InputLabel.Parent = self.Content

                local Input = Instance.new("TextBox")
                Input.Name = "Input_" .. key
                Input.Size = UDim2.new(1, 0, 0, 28)
                Input.BackgroundColor3 = Library.Scheme.BackgroundSecondary
                Input.Text = default
                Input.PlaceholderText = placeholder
                Input.TextColor3 = Library.Scheme.Text
                Input.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
                Input.Font = Enum.Font.Arcade
                Input.TextSize = 12
                Input.ClearTextOnFocus = false
                Input.LayoutOrder = #self.Items + 2
                Input.ZIndex = 24
                Input.Parent = self.Content

                local InputCorner = Instance.new("UICorner")
                InputCorner.CornerRadius = UDim.new(0, 6)
                InputCorner.Parent = Input

                local InputStroke = Instance.new("UIStroke")
                InputStroke.Color = Library:GetActiveColor()
                InputStroke.Thickness = 1
                InputStroke.Transparency = 0.5
                InputStroke.Parent = Input

                local InputObj = {
                    Key = key,
                    Text = text,
                    Holder = Input,
                    Value = default,
                    Type = "Input",
                }

                Input.FocusLost:Connect(function()
                    InputObj.Value = Input.Text
                    pcall(callback, Input.Text)
                end)

                function InputObj:Set(value)
                    Input.Text = tostring(value)
                    self.Value = value
                end

                function InputObj:SetValue(value)
                    self:Set(value)
                end

                table.insert(self.Items, InputObj)
                Library.Inputs[key] = InputObj
                Library.Options[key] = InputObj
                return InputObj
            end

            function groupObj:AddKeyPicker(key, config)
                config = config or {}
                local text = config.Text or key
                local default = config.Default or "F"
                local callback = config.Callback or function() end
                local mode = config.Mode or "Toggle"

                local KeyBtn = Instance.new("TextButton")
                KeyBtn.Name = "KeyPicker_" .. key
                KeyBtn.Size = UDim2.new(1, 0, 0, 30)
                KeyBtn.BackgroundColor3 = Library.Scheme.BackgroundSecondary
                KeyBtn.Text = text .. ": " .. default
                KeyBtn.TextColor3 = Library.Scheme.Text
                KeyBtn.Font = Enum.Font.Arcade
                KeyBtn.TextSize = 12
                KeyBtn.LayoutOrder = #self.Items + 1
                KeyBtn.AutoButtonColor = false
                KeyBtn.ZIndex = 24
                KeyBtn.Parent = self.Content

                local KeyCorner = Instance.new("UICorner")
                KeyCorner.CornerRadius = UDim.new(0, 6)
                KeyCorner.Parent = KeyBtn

                local KeyStroke = Instance.new("UIStroke")
                KeyStroke.Color = Library:GetActiveColor()
                KeyStroke.Thickness = 1
                KeyStroke.Transparency = 0.5
                KeyStroke.Parent = KeyBtn

                local KeyObj = {
                    Key = key,
                    Text = text,
                    Holder = KeyBtn,
                    Value = default,
                    Mode = mode,
                    IsBinding = false,
                    Type = "KeyPicker",
                }

                KeyBtn.MouseEnter:Connect(function()
                    safeTween(KeyBtn, TweenInfo.new(0.15), { BackgroundColor3 = Library.Scheme.ButtonHover })
                end)
                KeyBtn.MouseLeave:Connect(function()
                    safeTween(KeyBtn, TweenInfo.new(0.15), { BackgroundColor3 = Library.Scheme.BackgroundSecondary })
                end)
                KeyBtn.MouseButton1Click:Connect(function()
                    playClickSound()
                    KeyObj.IsBinding = true
                    KeyBtn.Text = text .. ": ..."
                end)

                table.insert(self.Items, KeyObj)
                Library.KeyPickers[key] = KeyObj
                Library.Options[key] = KeyObj

                UserInputService.InputBegan:Connect(function(input, gpe)
                    if gpe then return end
                    if KeyObj.IsBinding then
                        KeyObj.IsBinding = false
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            local keyName = input.KeyCode.Name
                            KeyObj.Value = keyName
                            KeyBtn.Text = text .. ": " .. keyName
                            pcall(callback, keyName)
                        end
                        return
                    end
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        if KeyObj.Value == input.KeyCode.Name then
                            pcall(callback, true)
                        end
                    end
                end)

                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        if KeyObj.Value == input.KeyCode.Name and KeyObj.Mode ~= "Toggle" then
                            pcall(callback, false)
                        end
                    end
                end)

                return KeyObj
            end

            function groupObj:AddDivider(dividerText)
                local Divider = Instance.new("Frame")
                Divider.Name = "Divider"
                Divider.Size = UDim2.new(1, 0, 0, 20)
                Divider.BackgroundTransparency = 1
                Divider.LayoutOrder = #self.Items + 1
                Divider.ZIndex = 24
                Divider.Parent = self.Content

                local DivLabel
                if dividerText and dividerText ~= "" then
                    DivLabel = Instance.new("TextLabel")
                    DivLabel.Size = UDim2.new(1, 0, 0, 20)
                    DivLabel.BackgroundTransparency = 1
                    DivLabel.Text = dividerText
                    DivLabel.TextColor3 = Library.Scheme.AccentLight
                    DivLabel.Font = Enum.Font.Arcade
                    DivLabel.TextSize = 12
                    DivLabel.TextXAlignment = Enum.TextXAlignment.Center
                    DivLabel.ZIndex = 25
                    DivLabel.Parent = Divider
                end

                local DividerObj = {
                    Holder = Divider,
                    Label = DivLabel,
                    Type = "Divider",
                }

                table.insert(self.Items, DividerObj)
                return DividerObj
            end

            function groupObj:Resize()
            end

            table.insert(self.Groups, groupObj)
            Library.Groups[name] = groupObj
            return groupObj
        end

        table.insert(self.Tabs, tab)
        Library.Tabs[name] = tab

        if #self.Tabs == 1 then
            tab:Show()
        end

        TabButton.MouseButton1Down:Connect(function()
            pulseButton(TabButton)
        end)
        TabButton.MouseButton1Click:Connect(function()
            playClickSound()
            tab:Show()
        end)

        return tab
    end

    function windowState:SelectTab(index)
        local tab = self.Tabs[index]
        if tab then tab:Show() end
    end

    MinimizeButton.MouseButton1Down:Connect(function()
        pulseButton(MinimizeButton)
        flashButton(MinimizeButton, Library:GetActiveColor())
    end)
    MinimizeButton.MouseButton1Click:Connect(function()
        self:Close()
    end)

    OpenButton.MouseButton1Down:Connect(function()
        pulseButton(OpenButton)
    end)
    OpenButton.MouseButton1Click:Connect(function()
        self:Open()
    end)

    local draggingBall = false
    local dragInputBall = nil
    local dragStartBall = nil
    local startPosBall = nil

    OpenButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingBall = true
            dragStartBall = input.Position
            startPosBall = OpenButton.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    draggingBall = false
                end
            end)
        end
    end)
    OpenButton.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInputBall = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInputBall and draggingBall then
            local delta = input.Position - dragStartBall
            OpenButton.Position = UDim2.new(
                startPosBall.X.Scale, startPosBall.X.Offset + delta.X,
                startPosBall.Y.Scale, startPosBall.Y.Offset + delta.Y
            )
        end
    end)

    ResizeGrip.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            windowState.Resizing = true
            windowState.ResizeStartMouse = Vector2.new(input.Position.X, input.Position.Y)
            local currentSize = MainFrame.AbsoluteSize
            windowState.ResizeStartSize = Vector2.new(currentSize.X, currentSize.Y)
            safeTween(ResizeGrip, TweenInfo.new(0.15), { Size = UDim2.new(0, 26, 0, 26) })
        end
    end)
    ResizeGrip.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            windowState.Resizing = false
            safeTween(ResizeGrip, TweenInfo.new(0.15), { Size = UDim2.new(0, 22, 0, 22) })
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if windowState.Resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            if not windowState.ResizeStartMouse or not windowState.ResizeStartSize then return end
            local deltaX = input.Position.X - windowState.ResizeStartMouse.X
            local deltaY = input.Position.Y - windowState.ResizeStartMouse.Y
            local newWidth = math.clamp(windowState.ResizeStartSize.X + deltaX, Library.MinWindowSize.X, Library.MaxWindowSize.X)
            local newHeight = math.clamp(windowState.ResizeStartSize.Y + deltaY, Library.MinWindowSize.Y, Library.MaxWindowSize.Y)
            MainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
        end
    end)

    task.spawn(function()
        while ScreenGui.Parent do
            local t = tick()
            local r = (math.sin(t * 3) + 1) / 2
            local baseColor = isRainbow() and (Library.RainbowColor or Library.Scheme.AccentColor) or Library.Scheme.AccentColor
            local darkColor = isRainbow() and (Library.RainbowColor or Library.Scheme.AccentDark) or Library.Scheme.AccentDark
            local color = Color3.lerp(baseColor, darkColor, r)
            if MainStroke then MainStroke.Color = color end
            if OpenStroke then OpenStroke.Color = color end
            if CreditsStroke then CreditsStroke.Color = color end
            if MinStroke then MinStroke.Color = color end
            if TitleGlowFrame then TitleGlowFrame.BackgroundColor3 = color end
            if GripCorner then GripCorner.BackgroundColor3 = color end
            task.wait(0.05)
        end
    end)

    if config.AutoOpen ~= false then
        task.spawn(function()
            task.wait(0.15)
            windowState:Open()
            task.wait(0.7)
            windowState:StartTitleAnimation()
        end)
    end

    return windowState
end

function Library:Unload()
    if Library.Unloaded then return end
    Library.Unloaded = true
    if Library.OnUnloadCallback then
        pcall(Library.OnUnloadCallback)
    end
    for _, win in ipairs(State.Windows) do
        if win.TitleAnimThread then
            win.TitleAnimStop = true
        end
        if win.ScreenGui then pcall(function() win.ScreenGui:Destroy() end) end
    end
    State.Windows = {}
    if State.NotifyContainer then
        pcall(function() State.NotifyContainer:Destroy() end)
        State.NotifyContainer = nil
    end
end

function Library:OnUnload(callback)
    Library.OnUnloadCallback = callback
end

function Library:SetToggleKeybind(keyCode)
    if type(keyCode) == "string" then
        keyCode = Enum.KeyCode[keyCode]
    end
    Library.ToggleKeybind = keyCode
end

function Library:SetNotifySide(side)
    Library.NotifySide = side
end

function Library:SetNotificationsEnabled(enabled)
    Library.NotificationsEnabled = enabled
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if Library.ToggleKeybind and input.KeyCode == Library.ToggleKeybind then
        for _, win in ipairs(State.Windows) do
            if win.IsOpen then
                win:Close()
            else
                win:Open()
            end
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if isRainbow() then
            local hue = (tick() * 0.5) % 1
            Library.RainbowColor = Color3.fromHSV(hue, 1, 1)
            Library:UpdateParticleColors()
            for _, toggle in pairs(Library.Toggles) do
                if toggle.Value and toggle.Holder then
                    toggle.Holder.BackgroundColor3 = Library.RainbowColor
                end
            end
        end
        task.wait(0.05)
    end
end)

getgenv().UILib = Library

return Library
