local Library              = {}
Library.__index            = Library
Library.Flags              = {}
Library.FlagCallbacks      = {}
Library.Connections        = {}
Library.Windows            = {}
Library.Open               = true
Library.Version            = "4.1.2"
Library.Name               = "Obscura"
Library._activeDropdown    = nil
Library._activeColorpicker = nil
Library._listeningKeybind  = nil
Library.UnloadCallbacks    = {}
Library.FlagBindings       = {}
Library.ConfigStore        = {}
Library._configFolder      = "Obscura"
Library.ScriptName         = "Obscura"
Library._mobileActions     = {}
Library._keybinds          = {}

local UIS         = game:GetService("UserInputService")
local TS          = game:GetService("TweenService")
local RS          = game:GetService("RunService")
local CoreGui     = game:GetService("CoreGui")
local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LP          = Players.LocalPlayer

local Icons
do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/AWLOID/Obscura/refs/heads/main/icons.lua"))()
    end)
    Icons = ok and result or {}
end

local function getIcon(name)
    local sheet = Icons and Icons["48px"]
    if not sheet then return nil, nil, nil end
    local data = sheet[name]
    if not data then return nil, nil, nil end
    return "rbxassetid://" .. data[1],
           Vector2.new(data[3][1], data[3][2]),
           Vector2.new(data[2][1], data[2][2])
end

local ThemeLight = {
    Bg          = Color3.fromRGB(250, 248, 246),
    Bg2         = Color3.fromRGB(243, 240, 237),
    Bg3         = Color3.fromRGB(232, 228, 224),
    Hover       = Color3.fromRGB(222, 218, 212),
    Border      = Color3.fromRGB(215, 210, 205),
    BorderHi    = Color3.fromRGB(180, 174, 168),
    Text        = Color3.fromRGB(32, 28, 24),
    SubText     = Color3.fromRGB(110, 104, 96),
    DimText     = Color3.fromRGB(165, 158, 150),
    Accent      = Color3.fromRGB(86, 107, 174),
    AccentText  = Color3.fromRGB(250, 249, 247),
    Track       = Color3.fromRGB(210, 206, 200),
    Shadow      = Color3.fromRGB(12, 10, 8),
    Knob        = Color3.fromRGB(255, 253, 250),
}
local ThemeDark = {
    Bg          = Color3.fromRGB(28, 26, 24),
    Bg2         = Color3.fromRGB(36, 34, 30),
    Bg3         = Color3.fromRGB(48, 45, 40),
    Hover       = Color3.fromRGB(60, 56, 50),
    Border      = Color3.fromRGB(54, 50, 46),
    BorderHi    = Color3.fromRGB(95, 90, 82),
    Text        = Color3.fromRGB(240, 236, 230),
    SubText     = Color3.fromRGB(168, 162, 154),
    DimText     = Color3.fromRGB(115, 110, 102),
    Accent      = Color3.fromRGB(120, 148, 220),
    AccentText  = Color3.fromRGB(28, 26, 22),
    Track       = Color3.fromRGB(72, 68, 62),
    Shadow      = Color3.fromRGB(6, 5, 4),
    Knob        = Color3.fromRGB(248, 244, 238),
}

local Theme = {}
for k, v in pairs(ThemeLight) do Theme[k] = v end
Library.Theme       = Theme
local ThemeMidnight = {
    Bg          = Color3.fromRGB(16, 16, 22),
    Bg2         = Color3.fromRGB(22, 22, 30),
    Bg3         = Color3.fromRGB(32, 32, 42),
    Hover       = Color3.fromRGB(42, 42, 54),
    Border      = Color3.fromRGB(38, 38, 50),
    BorderHi    = Color3.fromRGB(70, 68, 90),
    Text        = Color3.fromRGB(220, 218, 230),
    SubText     = Color3.fromRGB(140, 138, 160),
    DimText     = Color3.fromRGB(90, 88, 110),
    Accent      = Color3.fromRGB(130, 100, 220),
    AccentText  = Color3.fromRGB(240, 238, 250),
    Track       = Color3.fromRGB(50, 48, 65),
    Shadow      = Color3.fromRGB(4, 4, 6),
    Knob        = Color3.fromRGB(235, 232, 245),
}

Library.Themes      = { light = ThemeLight, dark = ThemeDark, midnight = ThemeMidnight }
Library.CurrentTheme = "light"

local function colorEq(a, b)
    if not a or not b then return false end
    return math.abs(a.R - b.R) < 0.02
       and math.abs(a.G - b.G) < 0.02
       and math.abs(a.B - b.B) < 0.02
end

local function colorDist(a, b)
    if not a or not b then return 999 end
    local dr, dg, db = a.R - b.R, a.G - b.G, a.B - b.B
    return math.sqrt(dr*dr + dg*dg + db*db)
end

local function _themeTween(inst, prop, to, dur)
    local ok = pcall(function()
        local tw = TS:Create(inst, TweenInfo.new(
            dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
        ), { [prop] = to })
        tw:Play()
    end)
    if not ok then
        pcall(function() inst[prop] = to end)
    end
end

local function _findThemeKey(c)
    if typeof(c) ~= "Color3" then return nil end
    for k, v in pairs(Theme) do
        if math.abs(c.R - v.R) < 0.001
        and math.abs(c.G - v.G) < 0.001
        and math.abs(c.B - v.B) < 0.001 then
            return k
        end
    end
    return nil
end

local _PROPS_BY_CLASS = {
    Frame                = { "BackgroundColor3" },
    TextButton           = { "BackgroundColor3", "TextColor3", "PlaceholderColor3" },
    TextBox              = { "BackgroundColor3", "TextColor3", "PlaceholderColor3" },
    TextLabel            = { "BackgroundColor3", "TextColor3", "PlaceholderColor3" },
    ImageButton          = { "BackgroundColor3", "ImageColor3" },
    ImageLabel           = { "BackgroundColor3", "ImageColor3" },
    ScrollingFrame       = { "BackgroundColor3", "ScrollBarImageColor3" },
    UIStroke             = { "Color" },
    ScreenGui            = { },
}

function Library:SetTheme(name, instant)
    local target = self.Themes[name] or self.Themes.light
    if not target then return end
    if self.CurrentTheme == name and not instant then return end

    local old = {}
    for k, v in pairs(Theme) do old[k] = v end

    for k, v in pairs(target) do Theme[k] = v end
    self.CurrentTheme = name

    local sg = self.ScreenGui
    if not sg then return end

    local function remapByColor(c)
        if not c then return nil end
        for k, oldC in pairs(old) do
            if colorEq(c, oldC) then return target[k] end
        end
        local bestKey, bestDist = nil, 0.15
        for k, oldC in pairs(old) do
            local d = colorDist and colorDist(c, oldC)
                       or math.sqrt((c.R-oldC.R)^2 + (c.G-oldC.G)^2 + (c.B-oldC.B)^2)
            if d < bestDist then
                bestKey  = k
                bestDist = d
            end
        end
        if bestKey then return target[bestKey] end
        return nil
    end

    local dur = instant and 0 or 0.25

    local function setOrTween(inst, prop, to)
        if not to then return end
        if dur <= 0 then
            pcall(function() inst[prop] = to end)
        else
            _themeTween(inst, prop, to, dur)
        end
    end

    local function applyOne(inst, prop)
        local key = inst:GetAttribute("ObsT_" .. prop)
        if key and target[key] then
            setOrTween(inst, prop, target[key])
            return
        end
        local current
        local ok = pcall(function() current = inst[prop] end)
        if ok and current and typeof(current) == "Color3" then

            for k, oldC in pairs(old) do
                if colorEq(current, oldC) then
                    setOrTween(inst, prop, target[k])
                    pcall(function() inst:SetAttribute("ObsT_" .. prop, k) end)
                    return
                end
            end

            local bestKey, bestDist = nil, 0.35
            for k, oldC in pairs(old) do
                local d = colorDist(current, oldC)
                if d < bestDist then
                    bestKey  = k
                    bestDist = d
                end
            end
            if bestKey then
                setOrTween(inst, prop, target[bestKey])
                pcall(function() inst:SetAttribute("ObsT_" .. prop, bestKey) end)
            end
        end
    end

    local instances = sg:GetDescendants()
    table.insert(instances, sg)
    for _, inst in ipairs(instances) do
        if not inst:GetAttribute("ObsPreserve") then
            local props = _PROPS_BY_CLASS[inst.ClassName]
            if props then
                for _, prop in ipairs(props) do
                    applyOne(inst, prop)
                end
            end
        end
    end
end

function Library:SetAccent(color, instant)
    if typeof(color) ~= "Color3" then return end
    local oldAccent = Theme.Accent
    local current = self.Themes[self.CurrentTheme]
    if current then current.Accent = color end
    Theme.Accent = color

    local sg = self.ScreenGui
    if not sg then return end

    local dur = instant and 0 or 0.16
    local function apply(inst, prop)
        local shouldApply = inst:GetAttribute("ObsT_" .. prop) == "Accent"
        if not shouldApply then
            local ok, currentValue = pcall(function() return inst[prop] end)
            shouldApply = ok and typeof(currentValue) == "Color3" and colorEq(currentValue, oldAccent)
        end
        if shouldApply then
            if dur <= 0 then
                pcall(function() inst[prop] = color end)
            else
                _themeTween(inst, prop, color, dur)
            end
            pcall(function() inst:SetAttribute("ObsT_" .. prop, "Accent") end)
        end
    end

    local instances = sg:GetDescendants()
    for _, inst in ipairs(instances) do
        if not inst:GetAttribute("ObsPreserve") then
            local props = _PROPS_BY_CLASS[inst.ClassName]
            if props then
                for _, prop in ipairs(props) do
                    apply(inst, prop)
                end
            end
        end
    end
end

local FONT, FONT_M, FONT_SB, FONT_B =
    Enum.Font.Gotham,
    Enum.Font.GothamMedium,
    Enum.Font.GothamSemibold,
    Enum.Font.GothamBold

local TEXT_XS, TEXT_SM, TEXT_MD, TEXT_LG = 11, 12, 13, 15

local R_SM   = UDim.new(0, 8)
local R_MD   = UDim.new(0, 12)
local R_LG   = UDim.new(0, 16)
local R_XL   = UDim.new(0, 20)
local R_PILL = UDim.new(1, 0)

local THEMED_PROPS = {
    BackgroundColor3    = true,
    TextColor3          = true,
    PlaceholderColor3   = true,
    ImageColor3         = true,
    ScrollBarImageColor3= true,
    Color               = true,
}

local function new(class, props)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then inst[k] = v end
        end
        for k, v in pairs(props) do
            if THEMED_PROPS[k] then
                local key = _findThemeKey(v)
                if key then
                    pcall(function()
                        inst:SetAttribute("ObsT_" .. k, key)
                    end)
                end
            end
        end
        if props.Parent then inst.Parent = props.Parent end
    end
    return inst
end

local function bindTheme(inst, prop, key)
    if not inst or not prop or not key then return end
    if Theme[key] == nil then return end
    pcall(function()
        inst[prop] = Theme[key]
        inst:SetAttribute("ObsT_" .. prop, key)
    end)
end
Library._bindTheme = bindTheme

local function corner(parent, radius)
    local r = type(radius) == "number" and UDim.new(0, radius)
        or (typeof(radius) == "UDim" and radius) or R_MD
    return new("UICorner", { Parent = parent, CornerRadius = r })
end

local function stroke(parent, color, thickness)
    return new("UIStroke", {
        Parent          = parent,
        Color           = color or Theme.Border,
        Thickness       = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function pad(parent, l, t, r, b)
    return new("UIPadding", {
        Parent        = parent,
        PaddingLeft   = UDim.new(0, l or 0),
        PaddingTop    = UDim.new(0, t or l or 0),
        PaddingRight  = UDim.new(0, r or l or 0),
        PaddingBottom = UDim.new(0, b or t or l or 0),
    })
end

local function listLayout(parent, dir, padding, halign, valign)
    return new("UIListLayout", {
        Parent              = parent,
        FillDirection       = dir or Enum.FillDirection.Vertical,
        Padding             = UDim.new(0, padding or 0),
        HorizontalAlignment = halign or Enum.HorizontalAlignment.Left,
        VerticalAlignment   = valign or Enum.VerticalAlignment.Top,
        SortOrder           = Enum.SortOrder.LayoutOrder,
    })
end

local function tween(obj, t, props, style, dir)
    local tw = TS:Create(obj, TweenInfo.new(
        t or 0.18,
        style or Enum.EasingStyle.Quad,
        dir or Enum.EasingDirection.Out
    ), props)
    tw:Play()
    return tw
end

local function register(c) table.insert(Library.Connections, c); return c end
local function clamp(v, a, b) if v < a then return a end if v > b then return b end return v end
local function round(n, d) local m = 10 ^ (d or 0) return math.floor(n * m + 0.5) / m end
local function isInside(f, p)
    local pp, ss = f.AbsolutePosition, f.AbsoluteSize
    return p.X >= pp.X and p.X <= pp.X + ss.X
       and p.Y >= pp.Y and p.Y <= pp.Y + ss.Y
end

local function viewportSize()
    local cam = workspace.CurrentCamera
    return (cam and cam.ViewportSize) or Vector2.new(800, 600)
end

local function smartWindowSize(requested, opts, verticalTabs)
    opts = opts or {}
    if opts.AutoSize == false or typeof(requested) ~= "UDim2" then
        return requested
    end
    if requested.X.Scale ~= 0 or requested.Y.Scale ~= 0 then
        return requested
    end

    local vp = viewportSize()
    local margin = UIS.TouchEnabled and 20 or 32
    local maxW = math.max(300, vp.X - margin)
    local maxH = math.max(260, vp.Y - margin)
    local minW = tonumber(opts.MinWidth) or (verticalTabs and 390 or 340)
    local minH = tonumber(opts.MinHeight) or 300
    if UIS.TouchEnabled or vp.X < 520 then
        minW = math.min(minW, 320)
        minH = math.min(minH, 280)
    end

    local w = clamp(requested.X.Offset, math.min(minW, maxW), maxW)
    local h = clamp(requested.Y.Offset, math.min(minH, maxH), maxH)
    return UDim2.fromOffset(math.floor(w), math.floor(h))
end

local function smartTabWidth(requested, rootWidth, opts)
    opts = opts or {}
    local w = tonumber(requested) or 104
    if opts.AutoSize ~= false then
        local maxAllowed = math.max(80, math.floor((rootWidth or 540) * 0.26))
        w = clamp(w, 80, maxAllowed)
        if (rootWidth or 540) <= 430 then
            w = math.min(w, 88)
        end
    end
    return math.floor(w)
end

local function fitWindowToViewport(root, opts)
    opts = opts or {}
    if opts.AutoPosition == false or not root or not root.Parent then return end
    local vp = viewportSize()
    local size = root.AbsoluteSize
    if size.X <= 0 or size.Y <= 0 then return end

    local margin = UIS.TouchEnabled and 8 or 12
    local minX = margin
    local minY = margin
    local maxX = math.max(minX, vp.X - size.X - margin)
    local maxY = math.max(minY, vp.Y - size.Y - margin)
    local x = clamp(root.AbsolutePosition.X, minX, maxX)
    local y = clamp(root.AbsolutePosition.Y, minY, maxY)
    if math.abs(x - root.AbsolutePosition.X) < 1 and math.abs(y - root.AbsolutePosition.Y) < 1 then
        return
    end
    root.Position = UDim2.fromOffset(
        x + size.X * root.AnchorPoint.X,
        y + size.Y * root.AnchorPoint.Y
    )
end

local function drawChevron(parent, w, color)
    local h = math.floor(w * 0.55)
    local cont = new("Frame", {
        Parent                 = parent,
        Size                   = UDim2.fromOffset(w, h),
        BackgroundTransparency = 1,
    })
    local thickness = 1.5
    local lineLen = math.floor(w * 0.62)

    local left = new("Frame", {
        Parent           = cont,
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(0.28, 0, 0.5, 0),
        Size             = UDim2.fromOffset(lineLen, thickness),
        BackgroundColor3 = color,
        BorderSizePixel  = 0,
        Rotation         = 35,
    })
    corner(left, UDim.new(0, 1))
    local right = new("Frame", {
        Parent           = cont,
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(0.72, 0, 0.5, 0),
        Size             = UDim2.fromOffset(lineLen, thickness),
        BackgroundColor3 = color,
        BorderSizePixel  = 0,
        Rotation         = -35,
    })
    corner(right, UDim.new(0, 1))

    local api = {}
    api.Container = cont
    api.Lines     = { left, right }
    function api:SetColor(c)
        left.BackgroundColor3  = c
        right.BackgroundColor3 = c
    end
    function api:SetOpen(open)
        local rot = open and 180 or 0
        tween(cont, 0.18, { Rotation = rot })
    end
    return api
end

local function drawCheck(parent, size, color)
    local cont = new("Frame", {
        Parent                 = parent,
        Size                   = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        Visible                = true,
    })
    local short = new("Frame", {
        Parent           = cont,
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(0.30, 0, 0.65, 0),
        Size             = UDim2.fromOffset(math.max(4, size * 0.38), 1.5),
        BackgroundColor3 = color,
        BorderSizePixel  = 0,
        Rotation         = 45,
    })
    corner(short, UDim.new(0, 1))
    local long = new("Frame", {
        Parent           = cont,
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(0.62, 0, 0.42, 0),
        Size             = UDim2.fromOffset(math.max(6, size * 0.62), 1.5),
        BackgroundColor3 = color,
        BorderSizePixel  = 0,
        Rotation         = -45,
    })
    corner(long, UDim.new(0, 1))

    local api = { Container = cont }
    function api:SetColor(c)
        short.BackgroundColor3 = c
        long.BackgroundColor3  = c
    end
    function api:SetVisible(v) cont.Visible = v end
    return api
end

local function drawCross(parent, size, color)
    local cont = new("Frame", {
        Parent                 = parent,
        Size                   = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
    })
    local len = size * 0.62
    local thick = 1.5
    local a = new("Frame", {
        Parent           = cont,
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.fromScale(0.5, 0.5),
        Size             = UDim2.fromOffset(len, thick),
        BackgroundColor3 = color,
        BorderSizePixel  = 0,
        Rotation         = 45,
    })
    corner(a, UDim.new(0, 1))
    local b = new("Frame", {
        Parent           = cont,
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.fromScale(0.5, 0.5),
        Size             = UDim2.fromOffset(len, thick),
        BackgroundColor3 = color,
        BorderSizePixel  = 0,
        Rotation         = -45,
    })
    corner(b, UDim.new(0, 1))

    local api = { Container = cont }
    function api:SetColor(c)
        a.BackgroundColor3 = c
        b.BackgroundColor3 = c
    end
    return api
end

local function drawMinus(parent, size, color)
    local cont = new("Frame", {
        Parent                 = parent,
        Size                   = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
    })
    local bar = new("Frame", {
        Parent           = cont,
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.fromScale(0.5, 0.5),
        Size             = UDim2.fromOffset(size * 0.62, 1.5),
        BackgroundColor3 = color,
        BorderSizePixel  = 0,
    })
    corner(bar, UDim.new(0, 1))
    return { Container = cont, SetColor = function(_, c) bar.BackgroundColor3 = c end }
end

local function drawHamburger(parent, size, color)
    local cont = new("Frame", {
        Parent                 = parent,
        Size                   = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
    })
    local len, thick = size * 0.6, 1.5
    for i = 1, 3 do
        local y = (i - 1) / 2
        local bar = new("Frame", {
            Parent           = cont,
            AnchorPoint      = Vector2.new(0.5, 0.5),
            Position         = UDim2.new(0.5, 0, y * 0.5 + 0.25, 0),
            Size             = UDim2.fromOffset(len, thick),
            BackgroundColor3 = color,
            BorderSizePixel  = 0,
        })
        corner(bar, UDim.new(0, 1))
    end
    return { Container = cont }
end

local function drawSettingsGlyph(parent, size, color)
    local cont = new("Frame", {
        Parent                 = parent,
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.fromScale(0.5, 0.5),
        Size                   = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        ZIndex                 = 21,
    })

    local parts = {}
    local lineLen = math.floor(size * 0.72 + 0.5)
    local lineH = math.max(2, math.floor(size * 0.12 + 0.5))
    local knob = math.max(4, math.floor(size * 0.25 + 0.5))
    local center = math.floor(size * 0.5 + 0.5)
    local ys = {
        math.floor(size * 0.28 + 0.5),
        center,
        math.floor(size * 0.72 + 0.5),
    }
    local xs = {
        math.floor(size * 0.32 + 0.5),
        math.floor(size * 0.68 + 0.5),
        math.floor(size * 0.48 + 0.5),
    }

    for i = 1, 3 do
        local line = new("Frame", {
            Parent           = cont,
            AnchorPoint      = Vector2.new(0.5, 0.5),
            Position         = UDim2.fromOffset(center, ys[i]),
            Size             = UDim2.fromOffset(lineLen, lineH),
            BackgroundColor3 = color,
            BorderSizePixel  = 0,
            ZIndex           = 21,
        })
        corner(line, R_PILL)
        table.insert(parts, line)

        local dot = new("Frame", {
            Parent           = cont,
            AnchorPoint      = Vector2.new(0.5, 0.5),
            Position         = UDim2.fromOffset(xs[i], ys[i]),
            Size             = UDim2.fromOffset(knob, knob),
            BackgroundColor3 = color,
            BorderSizePixel  = 0,
            ZIndex           = 22,
        })
        corner(dot, R_PILL)
        table.insert(parts, dot)
    end

    local api = { Container = cont, Parts = parts }
    function api:SetColor(c, themeKey)
        for _, part in ipairs(parts) do
            part.BackgroundColor3 = c
            if themeKey then
                pcall(function() part:SetAttribute("ObsT_BackgroundColor3", themeKey) end)
            end
        end
    end
    return api
end

local function makeDraggable(target, handle, onDragStart)
    handle = handle or target
    local dragging, dragInput, startPos, startInput = false, nil, nil, nil
    register(handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging, startInput, startPos = true, input.Position, target.Position
            if onDragStart then pcall(onDragStart) end
            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if conn then conn:Disconnect() end
                end
            end)
        end
    end))
    register(handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))
    register(UIS.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local d = input.Position - startInput
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end))
end

local function getScreenGui()
    if Library.ScreenGui and Library.ScreenGui.Parent then return Library.ScreenGui end
    local sg = new("ScreenGui", {
        Name           = "Obscura_" .. HttpService:GenerateGUID(false):sub(1, 8),
        ResetOnSpawn   = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder   = 999999999,
    })
    local protected = false
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(sg); sg.Parent = CoreGui; protected = true
        elseif gethui then sg.Parent = gethui(); protected = true
        elseif get_hidden_gui then sg.Parent = get_hidden_gui(); protected = true
        elseif protect_gui then protect_gui(sg); sg.Parent = CoreGui; protected = true end
    end)
    if not protected then
        pcall(function() sg.Parent = CoreGui end)
    end
    Library.ScreenGui = sg
    return sg
end

local KEY_NAMES = {
    [Enum.UserInputType.MouseButton1] = "MB1",
    [Enum.UserInputType.MouseButton2] = "MB2",
    [Enum.UserInputType.MouseButton3] = "MB3",
}
local function keyToString(key)
    if not key then return "—" end
    if typeof(key) == "EnumItem" then
        if key.EnumType == Enum.KeyCode then return key.Name end
        if KEY_NAMES[key] then return KEY_NAMES[key] end
    end
    return tostring(key)
end
local function isKeyPressed(key, input)
    if not key then return false end
    if typeof(key) == "EnumItem" then
        if key.EnumType == Enum.KeyCode then return input.KeyCode == key end
        return input.UserInputType == key
    end
    return false
end

local function normalizeKeybindOptions(opts)
    if typeof(opts) == "EnumItem" then
        return { Default = opts }
    end
    if type(opts) == "table" then
        return opts
    end
    return {}
end

function Library:BindAction(opts)
    opts = normalizeKeybindOptions(opts)
    local key       = opts.Key or opts.Default or opts.Bind
    local mode      = tostring(opts.Mode or "Always"):lower()
    local callback  = opts.Callback or function() end
    local onChanged = opts.OnChanged or function() end
    local stateFlag = opts.StateFlag
    local ignoreProcessed = opts.IgnoreProcessed == true
    local enabled   = opts.Enabled ~= false
    local active    = opts.DefaultState and true or false
    local conns     = {}

    local api = {}
    function api:Set(k, silent)
        key = k
        if opts.Flag then Library:SetFlag(opts.Flag, key) end
        if not silent then task.spawn(onChanged, key) end
    end
    function api:Get() return key end
    function api:SetMode(m) mode = tostring(m or "Always"):lower() end
    function api:GetMode() return mode end
    function api:SetCallback(fn) callback = fn or function() end end
    function api:SetEnabled(v) enabled = v and true or false end
    function api:IsEnabled() return enabled end
    function api:Destroy()
        enabled = false
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        for i, b in ipairs(Library._keybinds) do
            if b == api then table.remove(Library._keybinds, i) break end
        end
    end

    table.insert(conns, register(UIS.InputBegan:Connect(function(input, processed)
        if not enabled or not key then return end
        if processed and not ignoreProcessed then return end
        if not isKeyPressed(key, input) then return end

        if mode == "toggle" then
            active = not active
            if stateFlag then Library:SetFlag(stateFlag, active) end
            task.spawn(callback, active)
        elseif mode == "hold" then
            if active then return end
            active = true
            if stateFlag then Library:SetFlag(stateFlag, true) end
            task.spawn(callback, true)
        else
            task.spawn(callback)
        end
    end)))

    table.insert(conns, register(UIS.InputEnded:Connect(function(input)
        if not enabled or mode ~= "hold" or not key then return end
        if not active or not isKeyPressed(key, input) then return end
        active = false
        if stateFlag then Library:SetFlag(stateFlag, false) end
        task.spawn(callback, false)
    end)))

    if opts.Flag then Library:SetFlag(opts.Flag, key) end
    table.insert(Library._keybinds, api)
    return api
end

function Library:CreateMobileAction(opts)
    opts = opts or {}
    local sg      = getScreenGui()
    local linked  = opts.Api or opts.Element
    local mode    = tostring(opts.Mode or opts.Type or (linked and linked.Toggle and "toggle" or "button")):lower()
    local text    = tostring(opts.Text or opts.Name or opts.Title or "Action")
    local sizeOpt = opts.Size or 44
    local size    = typeof(sizeOpt) == "UDim2" and sizeOpt or UDim2.fromOffset(tonumber(sizeOpt) or 44, tonumber(sizeOpt) or 44)
    local pos     = opts.Position or UDim2.new(1, -66, 1, -104)
    local anchor  = opts.AnchorPoint or Vector2.new(1, 1)
    local callback = opts.Callback or function() end
    local state   = opts.Default and true or false

    local btn = new("TextButton", {
        Parent           = sg,
        Name             = "ObscuraQuickAction",
        AnchorPoint      = anchor,
        Position         = pos,
        Size             = size,
        BackgroundColor3 = Theme.Bg2,
        BorderSizePixel  = 0,
        Text             = "",
        AutoButtonColor  = false,
        ZIndex           = 10001,
        Active           = true,
        Visible          = opts.Visible ~= false,
    })
    corner(btn, R_PILL)
    local btnStroke = stroke(btn, Theme.BorderHi, 1)

    new("ImageLabel", {
        Parent                 = btn,
        ZIndex                 = 10000,
        Size                   = UDim2.new(1, 18, 1, 18),
        Position               = UDim2.fromOffset(-9, -7),
        BackgroundTransparency = 1,
        Image                  = "rbxasset://textures/ui/Controls/DropShadow.png",
        ImageColor3            = Theme.Shadow,
        ImageTransparency      = 0.86,
        ScaleType              = Enum.ScaleType.Slice,
        SliceCenter            = Rect.new(12, 12, 244, 244),
    })

    local iconImage, iconOffset, iconSize
    if type(opts.Icon) == "string" then
        iconImage, iconOffset, iconSize = getIcon(opts.Icon)
    end
    local icon
    if iconImage then
        icon = new("ImageLabel", {
            Parent                 = btn,
            AnchorPoint            = Vector2.new(0.5, 0.5),
            Position               = UDim2.fromScale(0.5, 0.5),
            Size                   = UDim2.fromOffset(20, 20),
            BackgroundTransparency = 1,
            Image                  = iconImage,
            ImageRectOffset        = iconOffset,
            ImageRectSize          = iconSize,
            ImageColor3            = Theme.Text,
            ZIndex                 = 10002,
            ScaleType              = Enum.ScaleType.Fit,
        })
    else
        icon = new("TextLabel", {
            Parent                 = btn,
            AnchorPoint            = Vector2.new(0.5, 0.5),
            Position               = UDim2.fromScale(0.5, 0.5),
            Size                   = UDim2.new(1, -8, 1, -8),
            BackgroundTransparency = 1,
            Font                   = FONT_B,
            TextSize               = TEXT_SM,
            TextColor3             = Theme.Text,
            Text                   = string.upper(text:sub(1, 3)),
            TextTruncate           = Enum.TextTruncate.AtEnd,
            ZIndex                 = 10002,
        })
    end

    local api = {}
    local function readLinked()
        if linked and linked.Get then
            local ok, v = pcall(linked.Get, linked)
            if ok then return v and true or false end
        end
        return state
    end
    local function render(animate)
        local on = mode == "toggle" and readLinked()
        local bg = on and Theme.Accent or Theme.Bg2
        local fg = on and Theme.AccentText or Theme.Text
        if animate then
            tween(btn, 0.16, { BackgroundColor3 = bg })
            tween(btnStroke, 0.16, { Color = on and Theme.Accent or Theme.BorderHi })
            if icon:IsA("ImageLabel") then
                tween(icon, 0.16, { ImageColor3 = fg })
            else
                tween(icon, 0.16, { TextColor3 = fg })
            end
        else
            btn.BackgroundColor3 = bg
            btnStroke.Color = on and Theme.Accent or Theme.BorderHi
            if icon:IsA("ImageLabel") then icon.ImageColor3 = fg else icon.TextColor3 = fg end
        end
    end

    function api:Set(v, silent)
        state = v and true or false
        if linked and linked.Set then pcall(linked.Set, linked, state, silent) end
        render(true)
        if not silent then task.spawn(callback, state) end
    end
    function api:Get() return readLinked() end
    function api:Toggle()
        if linked and linked.Toggle then
            pcall(linked.Toggle, linked)
        else
            api:Set(not readLinked())
        end
        render(true)
        task.spawn(callback, readLinked())
    end
    function api:Fire()
        if mode == "toggle" then
            api:Toggle()
            return
        end
        if linked and linked.Fire then pcall(linked.Fire, linked) end
        task.spawn(callback)
    end
    function api:SetVisible(v) btn.Visible = v and true or false end
    function api:Destroy()
        for i, a in ipairs(Library._mobileActions) do
            if a == api then table.remove(Library._mobileActions, i) break end
        end
        if btn and btn.Parent then btn:Destroy() end
    end

    makeDraggable(btn)
    btn.MouseEnter:Connect(function()
        tween(btn, 0.12, { Size = size + UDim2.fromOffset(2, 2) })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, 0.12, { Size = size })
    end)
    btn.MouseButton1Click:Connect(function() api:Fire() end)

    table.insert(Library._mobileActions, api)
    render(false)
    return api
end

function Library:_attachElementExtras(api, opts, kind)
    opts = opts or {}
    local bindOpts = opts.Keybind or opts.Bind or opts.Hotkey
    if bindOpts then
        local keyOpts = normalizeKeybindOptions(bindOpts)
        if not keyOpts.Callback then
            keyOpts.Callback = function()
                if kind == "toggle" and api.Toggle then
                    api:Toggle()
                elseif kind == "button" and api.Fire then
                    api:Fire()
                elseif kind == "slider" and api.Set and api.Get then
                    if keyOpts.Value ~= nil then
                        api:Set(keyOpts.Value)
                    elseif keyOpts.Step then
                        api:Set((api:Get() or 0) + (tonumber(keyOpts.Step) or 0))
                    end
                elseif (kind == "dropdown" or kind == "colorpicker") and api.Open and api.Close then
                    local floating = api.List or api.Popup
                    if floating and floating.Visible then api:Close() else api:Open() end
                end
            end
        end
        api.Keybind = Library:BindAction(keyOpts)
    end

    if opts.Mobile then
        local mobileOpts = type(opts.Mobile) == "table" and opts.Mobile or {}
        mobileOpts.Api  = mobileOpts.Api or api
        mobileOpts.Text = mobileOpts.Text or opts.Text
        mobileOpts.Icon = mobileOpts.Icon or opts.Icon
        mobileOpts.Mode = mobileOpts.Mode or kind
        api.MobileAction = Library:CreateMobileAction(mobileOpts)
    end

    return api
end

function Library:SetFlag(flag, value)
    if not flag then return end
    Library.Flags[flag] = value
    local list = Library.FlagCallbacks[flag]
    if list then for _, fn in ipairs(list) do task.spawn(fn, value) end end
end
function Library:GetFlag(flag, default)
    local v = Library.Flags[flag]
    if v == nil then return default end
    return v
end
function Library:OnFlag(flag, fn)
    Library.FlagCallbacks[flag] = Library.FlagCallbacks[flag] or {}
    table.insert(Library.FlagCallbacks[flag], fn)
end

function Library:BindFlag(flag, api)
    if not flag or not api then return end
    Library.FlagBindings[flag] = api
end

local function _ensureConfigFolder()
    if not isfolder then return false end
    local folder = Library._configFolder
    if not isfolder(folder) then
        pcall(makefolder, folder)
    end
    return isfolder(folder)
end

function Library:SaveConfig(name)
    name = tostring(name or "default")
    local data = {}
    for flag, value in pairs(Library.Flags) do
        local t = typeof(value)
        if t == "string" or t == "number" or t == "boolean" then
            data[flag] = value
        elseif t == "Color3" then
            data[flag] = { _type = "Color3", R = value.R, G = value.G, B = value.B }
        elseif t == "EnumItem" then
            data[flag] = { _type = "EnumItem", EnumType = tostring(value.EnumType), Name = value.Name }
        elseif t == "table" or type(value) == "table" then
            data[flag] = value
        end
    end
    local json = HttpService:JSONEncode(data)
    Library.ConfigStore[name] = json
    if _ensureConfigFolder() and writefile then
        pcall(writefile, Library._configFolder .. "/" .. name .. ".json", json)
    end
    return true
end

function Library:LoadConfig(name)
    name = tostring(name or "default")
    local json = Library.ConfigStore[name]
    if not json and _ensureConfigFolder() and readfile and isfile then
        local path = Library._configFolder .. "/" .. name .. ".json"
        if isfile(path) then
            local ok, content = pcall(readfile, path)
            if ok then json = content end
        end
    end
    if not json then return false end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
    if not ok or type(data) ~= "table" then return false end
    for flag, value in pairs(data) do
        if type(value) == "table" and value._type == "Color3" then
            value = Color3.new(value.R, value.G, value.B)
        elseif type(value) == "table" and value._type == "EnumItem" then
            pcall(function() value = Enum[value.EnumType][value.Name] end)
        end
        local binding = Library.FlagBindings[flag]
        if binding and binding.Set then
            pcall(binding.Set, binding, value)
        else
            Library:SetFlag(flag, value)
        end
    end
    return true
end

function Library:ListConfigs()
    local configs = {}
    for name in pairs(Library.ConfigStore) do
        table.insert(configs, name)
    end
    if _ensureConfigFolder() and listfiles then
        local ok, files = pcall(listfiles, Library._configFolder)
        if ok then
            for _, path in ipairs(files) do
                local n = path:match("([^/\\]+)%.json$")
                if n then
                    local found = false
                    for _, existing in ipairs(configs) do
                        if existing == n then found = true break end
                    end
                    if not found then table.insert(configs, n) end
                end
            end
        end
    end
    table.sort(configs)
    return configs
end

function Library:DeleteConfig(name)
    name = tostring(name or "default")
    Library.ConfigStore[name] = nil
    if _ensureConfigFolder() and delfile and isfile then
        local path = Library._configFolder .. "/" .. name .. ".json"
        if isfile(path) then pcall(delfile, path) end
    end
    return true
end

function Library:SetConfigFolder(folder)
    Library._configFolder = tostring(folder or "Obscura")
end

function Library:Toggle(state)
    if state == nil then state = not Library.Open end
    Library.Open = state
    if not state then
        if Library._activeDropdown    then Library._activeDropdown:Close()    end
        if Library._activeColorpicker then Library._activeColorpicker:Close() end
        if Library._listeningKeybind  then Library._listeningKeybind:Cancel() end
    end
    for _, w in ipairs(Library.Windows) do
        if w.Root then w.Root.Visible = state end
        if w.Shadow then w.Shadow.Visible = state end
    end
end

function Library:OnUnload(fn)
    if type(fn) == "function" then
        table.insert(Library.UnloadCallbacks, fn)
    end
end

function Library:Destroy()
    for _, fn in ipairs(Library.UnloadCallbacks) do
        pcall(fn)
    end
    for _, c in ipairs(Library.Connections) do
        pcall(function() c:Disconnect() end)
    end
    Library.Connections = {}
    if Library.ScreenGui then pcall(function() Library.ScreenGui:Destroy() end) end
    Library.ScreenGui = nil
    Library.Windows, Library.Flags, Library.FlagCallbacks = {}, {}, {}
    Library.UnloadCallbacks, Library.FlagBindings, Library.ConfigStore = {}, {}, {}
    Library.MobileButton, Library.NotifyHolder, Library.PrimaryWindow = nil, nil, nil
    Library._activeDropdown, Library._activeColorpicker, Library._listeningKeybind = nil, nil, nil
    Library._mobileActions, Library._keybinds = {}, {}
    Library._notifications = {}
end

local function makeMobileButton()
    if Library.MobileButton then return end
    local sg = getScreenGui()
    local btn = new("TextButton", {
        Parent           = sg,
        Name             = "ObscuraToggle",
        Size             = UDim2.fromOffset(44, 44),
        Position         = UDim2.new(0, 14, 0, 14),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel  = 0,
        Text             = "",
        AutoButtonColor  = false,
        ZIndex           = 10000,
        Active           = true,
    })
    corner(btn, R_PILL)

    local sh = new("ImageLabel", {
        Parent                 = btn,
        ZIndex                 = 9999,
        Size                   = UDim2.new(1, 24, 1, 24),
        Position               = UDim2.fromOffset(-12, -10),
        BackgroundTransparency = 1,
        Image                  = "rbxasset://textures/ui/Controls/DropShadow.png",
        ImageColor3            = Theme.Shadow,
        ImageTransparency      = 0.78,
        ScaleType              = Enum.ScaleType.Slice,
        SliceCenter            = Rect.new(12, 12, 244, 244),
    })

    local iconHolder = new("Frame", {
        Parent                 = btn,
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.fromScale(0.5, 0.5),
        Size                   = UDim2.fromOffset(20, 20),
        BackgroundTransparency = 1,
    })
    drawHamburger(iconHolder, 20, Theme.AccentText)

    makeDraggable(btn)
    btn.MouseButton1Click:Connect(function()
        if Library.PrimaryWindow and Library.PrimaryWindow.Toggle then
            Library.PrimaryWindow:Toggle()
        else
            Library:Toggle()
        end
    end)
    Library.MobileButton = btn
end

register(RS.Heartbeat:Connect(function()
    local d = Library._activeDropdown
    if d and d.UpdatePosition then pcall(d.UpdatePosition, d) end
    local cp = Library._activeColorpicker
    if cp and cp.UpdatePosition then pcall(cp.UpdatePosition, cp) end
end))

register(UIS.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
   and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local pos = input.Position
    if Library._activeDropdown then
        local d = Library._activeDropdown
        if d.List and d.Button and not isInside(d.List, pos) and not isInside(d.Button, pos) then
            d:Close()
        end
    end
    if Library._activeColorpicker then
        local cp = Library._activeColorpicker
        if cp.Popup and cp.Button and not isInside(cp.Popup, pos) and not isInside(cp.Button, pos) then
            cp:Close()
        end
    end
end))

local function _resolveColor(c)
    if typeof(c) == "Color3" then return c end
    if type(c) == "string" then return Theme[c] end
    return nil
end

local function accentHoverColor()
    local a = Theme.Accent
    if (a.R + a.G + a.B) / 3 > 0.5 then
        return Color3.new(math.max(0, a.R - 0.06),
                          math.max(0, a.G - 0.06),
                          math.max(0, a.B - 0.06))
    else
        return Color3.new(math.min(1, a.R + 0.16),
                          math.min(1, a.G + 0.16),
                          math.min(1, a.B + 0.16))
    end
end
local function attachHover(btn, normal, hover, strokeInst)
    btn.MouseEnter:Connect(function()
        tween(btn, 0.14, { BackgroundColor3 = _resolveColor(hover) or hover })
        if strokeInst then tween(strokeInst, 0.14, { Color = Theme.BorderHi }) end
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, 0.14, { BackgroundColor3 = _resolveColor(normal) or normal })
        if strokeInst then tween(strokeInst, 0.14, { Color = Theme.Border }) end
    end)
end

function Library:CreateKeySystem(opts)
    opts = opts or {}
    local keyTitle    = opts.Title or "Key System"
    local subtitle    = opts.Subtitle or "Enter your key to continue"
    local getKeyUrl   = opts.GetKeyUrl or ""
    local checkKey    = opts.CheckKey or function(key) return false end
    local savedKey    = opts.SaveKey ~= false
    local keyFileName = opts.KeyFile or "Obscura_Key.txt"

    local sg = getScreenGui()

    local overlay = new("Frame", {
        Parent           = sg,
        Size             = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.4,
        BorderSizePixel  = 0,
        ZIndex           = 9000,
    })

    local box = new("Frame", {
        Parent           = overlay,
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.fromScale(0.5, 0.5),
        Size             = UDim2.fromOffset(340, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel  = 0,
        ZIndex           = 9001,
    })
    corner(box, R_XL)
    stroke(box, Theme.Border, 1)
    pad(box, 24, 24, 24, 24)
    listLayout(box, Enum.FillDirection.Vertical, 12,
        Enum.HorizontalAlignment.Center)

    new("ImageLabel", {
        Parent                 = box,
        ZIndex                 = 9000,
        Size                   = UDim2.new(1, 50, 1, 50),
        Position               = UDim2.fromOffset(-25, -20),
        BackgroundTransparency = 1,
        Image                  = "rbxasset://textures/ui/Controls/DropShadow.png",
        ImageColor3            = Theme.Shadow,
        ImageTransparency      = 0.82,
        ScaleType              = Enum.ScaleType.Slice,
        SliceCenter            = Rect.new(12, 12, 244, 244),
    })

    new("TextLabel", {
        Parent                 = box,
        Size                   = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Font                   = FONT_SB,
        TextSize               = TEXT_LG,
        TextColor3             = Theme.Text,
        Text                   = keyTitle,
        TextXAlignment         = Enum.TextXAlignment.Center,
        ZIndex                 = 9002,
    })

    new("TextLabel", {
        Parent                 = box,
        Size                   = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Font                   = FONT,
        TextSize               = TEXT_SM,
        TextColor3             = Theme.SubText,
        Text                   = subtitle,
        TextXAlignment         = Enum.TextXAlignment.Center,
        ZIndex                 = 9002,
    })

    local inputBox = new("Frame", {
        Parent           = box,
        Size             = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Theme.Bg2,
        BorderSizePixel  = 0,
        ZIndex           = 9002,
    })
    corner(inputBox, R_MD)
    local inputStroke = stroke(inputBox, Theme.Border, 1)

    local keyInput = new("TextBox", {
        Parent                 = inputBox,
        BackgroundTransparency = 1,
        Position               = UDim2.fromOffset(12, 0),
        Size                   = UDim2.new(1, -24, 1, 0),
        Font                   = FONT,
        TextSize               = TEXT_MD,
        TextColor3             = Theme.Text,
        PlaceholderColor3      = Theme.DimText,
        PlaceholderText        = "Enter key...",
        Text                   = "",
        TextXAlignment         = Enum.TextXAlignment.Left,
        ClearTextOnFocus       = false,
        ZIndex                 = 9002,
    })

    keyInput.Focused:Connect(function()
        tween(inputStroke, 0.14, { Color = Theme.Accent })
    end)
    keyInput.FocusLost:Connect(function()
        tween(inputStroke, 0.14, { Color = Theme.Border })
    end)

    local statusLabel = new("TextLabel", {
        Parent                 = box,
        Size                   = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Font                   = FONT,
        TextSize               = TEXT_SM,
        TextColor3             = Theme.DimText,
        Text                   = "",
        TextXAlignment         = Enum.TextXAlignment.Center,
        ZIndex                 = 9002,
    })

    local btnRow = new("Frame", {
        Parent                 = box,
        Size                   = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        ZIndex                 = 9002,
    })
    listLayout(btnRow, Enum.FillDirection.Horizontal, 8,
        Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)

    local function makeKeyBtn(text, color, textColor)
        local b = new("TextButton", {
            Parent           = btnRow,
            Size             = UDim2.new(0.5, -4, 0, 36),
            BackgroundColor3 = color,
            BorderSizePixel  = 0,
            Font             = FONT_M,
            TextSize         = TEXT_MD,
            TextColor3       = textColor,
            Text             = text,
            AutoButtonColor  = false,
            ZIndex           = 9002,
        })
        corner(b, R_MD)
        return b
    end

    local checkBtn = makeKeyBtn("Check Key", Theme.Accent, Theme.AccentText)
    local getKeyBtn
    if getKeyUrl ~= "" then
        getKeyBtn = makeKeyBtn("Get Key", Theme.Bg3, Theme.Text)
        stroke(getKeyBtn, Theme.BorderHi, 1)
    end

    if savedKey then
        pcall(function()
            local saved = readfile(keyFileName)
            if saved and saved ~= "" then
                keyInput.Text = saved
            end
        end)
    end

    local resolved = false
    local api = {}

    checkBtn.MouseButton1Click:Connect(function()
        local key = keyInput.Text
        if key == "" then
            statusLabel.Text = "Please enter a key"
            statusLabel.TextColor3 = Color3.fromRGB(235, 65, 55)
            return
        end
        statusLabel.Text = "Checking..."
        statusLabel.TextColor3 = Theme.DimText
        task.spawn(function()
            local ok = checkKey(key)
            if ok then
                statusLabel.Text = "Key accepted!"
                statusLabel.TextColor3 = Color3.fromRGB(48, 185, 120)
                if savedKey then
                    pcall(function() writefile(keyFileName, key) end)
                end
                resolved = true
                task.delay(0.5, function()
                    tween(overlay, 0.3, { BackgroundTransparency = 1 })
                    tween(box, 0.3, { Position = UDim2.new(0.5, 0, 0.5, 40),
                        BackgroundTransparency = 1 })
                    task.delay(0.35, function()
                        overlay:Destroy()
                    end)
                end)
            else
                statusLabel.Text = "Invalid key"
                statusLabel.TextColor3 = Color3.fromRGB(235, 65, 55)
                tween(inputStroke, 0.14, { Color = Color3.fromRGB(235, 65, 55) })
                task.delay(1.5, function()
                    if not resolved then
                        statusLabel.Text = ""
                        tween(inputStroke, 0.14, { Color = Theme.Border })
                    end
                end)
            end
        end)
    end)

    if getKeyBtn then
        getKeyBtn.MouseButton1Click:Connect(function()
            if setclipboard then
                setclipboard(getKeyUrl)
                statusLabel.Text = "Link copied to clipboard!"
                statusLabel.TextColor3 = Theme.Accent
            elseif openurl then
                openurl(getKeyUrl)
            end
        end)
    end

    function api:IsResolved() return resolved end
    function api:Destroy() if overlay and overlay.Parent then overlay:Destroy() end end

    while not resolved do task.wait(0.1) end
    return api
end

local Window = {}
Window.__index = Window

function Library:CreateWindow(opts)
    opts = opts or {}
    local isPrimary = #Library.Windows == 0
    local title    = opts.Title    or "Obscura"
    local subtitle = opts.Subtitle or ""
    local position = opts.Position or UDim2.fromScale(0.5, 0.5)
    local anchor   = opts.AnchorPoint or Vector2.new(0.5, 0.5)
    local hasToggleKey = opts.ToggleKey ~= false and (opts.ToggleKey ~= nil or isPrimary)
    local toggleKey= opts.ToggleKey or Enum.KeyCode.RightShift
    local mobile   = opts.MobileButton ~= false
    local layout   = tostring(opts.Layout or opts.MenuLayout or opts.TabLayout or opts.MenuOrientation or "horizontal"):lower()
    local verticalTabs = layout == "vertical" or layout == "left" or layout == "side"
    local baseSize = opts.Size or UDim2.fromOffset(540, 350)
    local size     = smartWindowSize(baseSize, opts, verticalTabs)
    local scriptName = tostring(opts.ScriptName or opts.Name or title or Library.ScriptName)
    local confirmClose = opts.ConfirmClose
    if confirmClose == nil then confirmClose = true end
    local closeMode = tostring(opts.CloseMode or opts.CloseAction or (isPrimary and "library" or "hide")):lower()
    local initialVisible = opts.Visible ~= false and opts.StartVisible ~= false
    local searchWidth = tonumber(opts.SearchWidth) or 128
    local searchEnabled = opts.Search ~= false
    Library.ScriptName = scriptName
    if opts.Accent then Theme.Accent = opts.Accent end

    local sg = getScreenGui()

    local wmEnabled = opts.Watermark ~= false
    local wmOpts = opts.Watermark or {}
    if type(wmOpts) == "string" then wmOpts = { Name = wmOpts } end
    if type(wmOpts) ~= "table" then wmOpts = {} end
    if type(wmOpts) == "table" and wmOpts.Enabled == false then wmEnabled = false end
    local wmName = wmOpts.Name or ""
    local wmShowFPS     = wmOpts.FPS ~= false
    local wmShowPlayers = wmOpts.Players == true
    local wmShowTime    = wmOpts.Time ~= false
    local wmTransparency = tonumber(wmOpts.Transparency or wmOpts.BackgroundTransparency) or 0

    local wmFrame, wmLabels
    if wmEnabled and wmName ~= "" then
        wmFrame = new("Frame", {
            Parent           = sg,
            Name             = "Watermark",
            AnchorPoint      = Vector2.new(1, 0),
            Position         = UDim2.new(1, -14, 0, 10),
            Size             = UDim2.fromOffset(0, 26),
            AutomaticSize    = Enum.AutomaticSize.X,
            BackgroundColor3 = Theme.Bg2,
            BackgroundTransparency = wmTransparency,
            BorderSizePixel  = 0,
            ZIndex           = 999,
            Visible          = wmOpts.Visible ~= false,
        })
        corner(wmFrame, R_MD)
        stroke(wmFrame, Theme.Border, 1)
        pad(wmFrame, 10, 0, 10, 0)
        listLayout(wmFrame, Enum.FillDirection.Horizontal, 8, nil, Enum.VerticalAlignment.Center)

        local function wmLabel(text, key)
            local l = new("TextLabel", {
                Parent                 = wmFrame,
                BackgroundTransparency = 1,
                Size                   = UDim2.fromOffset(0, 26),
                AutomaticSize          = Enum.AutomaticSize.X,
                Font                   = FONT_M,
                TextSize               = TEXT_SM,
                TextColor3             = Theme.SubText,
                Text                   = text,
                ZIndex                 = 1000,
            })
            bindTheme(l, "TextColor3", key or "SubText")
            return l
        end

        local function wmSep()
            local s = new("Frame", {
                Parent           = wmFrame,
                Size             = UDim2.fromOffset(1, 12),
                BackgroundColor3 = Theme.Border,
                BorderSizePixel  = 0,
                ZIndex           = 1000,
            })
            bindTheme(s, "BackgroundColor3", "Border")
            return s
        end

        wmLabels = {}
        local wmIconName = wmOpts.Icon
        if wmIconName and type(wmIconName) == "string" then
            local wmImage, wmRectOff, wmRectSize = getIcon(wmIconName)
            if wmImage then
                new("ImageLabel", {
                    Parent                 = wmFrame,
                    BackgroundTransparency = 1,
                    Size                   = UDim2.fromOffset(14, 14),
                    Image                  = wmImage,
                    ImageRectOffset        = wmRectOff,
                    ImageRectSize          = wmRectSize,
                    ImageColor3            = Theme.Text,
                    ZIndex                 = 1000,
                    LayoutOrder            = 0,
                    ScaleType              = Enum.ScaleType.Fit,
                })
            end
        end
        wmLabels.name = wmLabel(wmName, "Text")
        if wmShowFPS then
            wmSep()
            wmLabels.fps = wmLabel("-- FPS", "SubText")
        end
        if wmShowPlayers then
            wmSep()
            wmLabels.players = wmLabel("0 players", "SubText")
        end
        if wmShowTime then
            wmSep()
            wmLabels.time = wmLabel("00:00", "SubText")
        end

        local fpsAccum, fpsCount = 0, 0
        register(RS.Heartbeat:Connect(function(dt)
            if not wmFrame or not wmFrame.Parent then return end
            if wmLabels.fps then
                fpsAccum = fpsAccum + dt
                fpsCount = fpsCount + 1
                if fpsAccum >= 0.5 then
                    wmLabels.fps.Text = math.floor(fpsCount / fpsAccum) .. " FPS"
                    fpsAccum, fpsCount = 0, 0
                end
            end
            if wmLabels.players then
                wmLabels.players.Text = #Players:GetPlayers() .. " players"
            end
            if wmLabels.time then
                wmLabels.time.Text = os.date("%H:%M", os.time())
            end
        end))
    end

    local shadow = new("ImageLabel", {
        Parent                 = sg,
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = position,
        Size                   = size + UDim2.fromOffset(60, 60),
        BackgroundTransparency = 1,
        Image                  = "rbxasset://textures/ui/Controls/DropShadow.png",
        ImageColor3            = Theme.Shadow,
        ImageTransparency      = 0.82,
        ScaleType              = Enum.ScaleType.Slice,
        SliceCenter            = Rect.new(12, 12, 244, 244),
        ZIndex                 = 1,
        Visible                = initialVisible,
    })

    local root = new("Frame", {
        Parent           = sg,
        Name             = "Window",
        AnchorPoint      = anchor,
        Position         = position,
        Size             = size,
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        Active           = true,
        ZIndex           = 2,
        Visible          = initialVisible,
    })
    corner(root, R_XL)
    local rootStroke = stroke(root, Theme.Border, 1)

    local function syncShadow()
        shadow.Position = UDim2.fromOffset(
            root.AbsolutePosition.X + root.AbsoluteSize.X / 2,
            root.AbsolutePosition.Y + root.AbsoluteSize.Y / 2
        )
    end
    register(root:GetPropertyChangedSignal("AbsolutePosition"):Connect(syncShadow))
    register(root:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncShadow))
    register(root:GetPropertyChangedSignal("Visible"):Connect(function()
        shadow.Visible = root.Visible
    end))
    task.defer(syncShadow)

    local titleBar = new("Frame", {
        Parent                 = root,
        Name                   = "TitleBar",
        Size                   = UDim2.new(1, 0, 0, 44),
        BackgroundTransparency = 1,
        Active                 = true,
    })

    new("Frame", {
        Parent           = titleBar,
        Size             = UDim2.new(1, -32, 0, 1),
        Position         = UDim2.new(0, 16, 1, -1),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel  = 0,
    })

    local subtitleText
    local titleRightInset = searchEnabled and (searchWidth + 112) or 90
    local titleText = new("TextLabel", {
        Parent                 = titleBar,
        BackgroundTransparency = 1,
        Position               = UDim2.fromOffset(18, 6),
        Size                   = UDim2.new(1, -titleRightInset, 0, 18),
        Font                   = FONT_SB,
        TextSize               = TEXT_LG,
        TextColor3             = Theme.Text,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextTruncate           = Enum.TextTruncate.AtEnd,
        Text                   = title,
    })
    if subtitle ~= "" then
        subtitleText = new("TextLabel", {
            Parent                 = titleBar,
            BackgroundTransparency = 1,
            Position               = UDim2.fromOffset(18, 24),
            Size                   = UDim2.new(1, -titleRightInset, 0, 14),
            Font                   = FONT,
            TextSize               = TEXT_SM,
            TextColor3             = Theme.SubText,
            TextXAlignment         = Enum.TextXAlignment.Left,
            TextTruncate           = Enum.TextTruncate.AtEnd,
            Text                   = subtitle,
        })
    else
        titleText.Position = UDim2.fromOffset(18, 0)
        titleText.Size = UDim2.new(1, -titleRightInset, 1, 0)
    end

    local function makeIconBtn(order, drawFn, danger)
        local b = new("TextButton", {
            Parent                 = titleBar,
            AnchorPoint            = Vector2.new(1, 0.5),
            Position               = UDim2.new(1, -10 - (order - 1) * 32, 0.5, 0),
            Size                   = UDim2.fromOffset(28, 28),
            BackgroundColor3       = Theme.Bg2,
            BackgroundTransparency = 1,
            BorderSizePixel        = 0,
            Text                   = "",
            AutoButtonColor        = false,
        })
        corner(b, R_PILL)
        local iconHolder = new("Frame", {
            Parent                 = b,
            AnchorPoint            = Vector2.new(0.5, 0.5),
            Position               = UDim2.fromScale(0.5, 0.5),
            Size                   = UDim2.fromOffset(14, 14),
            BackgroundTransparency = 1,
        })
        local icon = drawFn(iconHolder, 14, Theme.SubText)
        b.MouseEnter:Connect(function()
            tween(b, 0.14, {
                BackgroundTransparency = 0,
                BackgroundColor3 = danger and Color3.fromRGB(255, 59, 48) or Theme.Bg3,
            })
            if icon.SetColor then
                icon:SetColor(danger and Theme.AccentText or Theme.Text)
            end
        end)
        b.MouseLeave:Connect(function()
            tween(b, 0.14, { BackgroundTransparency = 1 })
            if icon.SetColor then icon:SetColor(Theme.SubText) end
        end)
        return b
    end

    local closeBtn = makeIconBtn(1, drawCross, true)
    local minBtn   = makeIconBtn(2, drawMinus, false)
    local windowRef
    minBtn.MouseButton1Click:Connect(function()
        if windowRef and windowRef.Toggle then
            windowRef:Toggle(false)
        else
            Library:Toggle(false)
        end
    end)
    closeBtn.MouseButton1Click:Connect(function()
        if windowRef and windowRef.RequestClose then
            windowRef:RequestClose()
        else
            Library:Destroy()
        end
    end)

    local tabBarH = tonumber(opts.TabBarHeight or opts.TabBarSize) or 56
    local baseTabBarW = tonumber(opts.TabBarWidth or opts.TabBarSize) or 104
    local tabBarW = smartTabWidth(baseTabBarW, size.X.Offset, opts)
    local tabBar = new("Frame", {
        Parent           = root,
        Name             = "TabBar",
        AnchorPoint      = verticalTabs and Vector2.new(0, 0) or Vector2.new(0, 1),
        Position         = verticalTabs and UDim2.fromOffset(0, 44) or UDim2.new(0, 0, 1, 0),
        Size             = verticalTabs and UDim2.new(0, tabBarW, 1, -44) or UDim2.new(1, 0, 0, tabBarH),
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel  = 0,
    })

    corner(tabBar, R_XL)
    if verticalTabs then
        new("Frame", {
            Parent           = tabBar,
            Size             = UDim2.new(0, 1, 1, -20),
            Position         = UDim2.new(1, -1, 0, 10),
            BackgroundColor3 = Theme.Border,
            BorderSizePixel  = 0,
            ZIndex           = 3,
        })
    else
        new("Frame", {
            Parent           = tabBar,
            Name             = "TopLip",
            Position         = UDim2.fromOffset(0, 0),
            Size             = UDim2.new(1, 0, 0, R_XL.Offset),
            BackgroundColor3 = Theme.Bg,
            BorderSizePixel  = 0,
            ZIndex           = 2,
        })

        new("Frame", {
            Parent           = tabBar,
            Size             = UDim2.new(1, -32, 0, 1),
            Position         = UDim2.new(0, 16, 0, 0),
            BackgroundColor3 = Theme.Border,
            BorderSizePixel  = 0,
            ZIndex           = 3,
        })
    end

    local tabRow = new("Frame", {
        Parent                 = tabBar,
        Position               = verticalTabs and UDim2.fromOffset(0, 0) or UDim2.fromOffset(0, 1),
        Size                   = verticalTabs and UDim2.fromScale(1, 1) or UDim2.new(1, 0, 1, -1),
        BackgroundTransparency = 1,
        ZIndex                 = 3,
    })
    if verticalTabs then
        pad(tabRow, 8, 10, 8, 10)
    else
        pad(tabRow, 16, 0, 16, 0)
    end
    local tabLayout = listLayout(tabRow,
        verticalTabs and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
        verticalTabs and 4 or 0,
        Enum.HorizontalAlignment.Center,
        verticalTabs and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Center)
    pcall(function() tabLayout.HorizontalFlex = Enum.UIFlexAlignment.Fill end)

    local indicator = new("Frame", {
        Parent           = tabBar,
        Size             = verticalTabs and UDim2.fromOffset(3, 24) or UDim2.fromOffset(24, 3),
        Position         = UDim2.fromOffset(0, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel  = 0,
        AnchorPoint      = verticalTabs and Vector2.new(0, 0.5) or Vector2.new(0.5, 0),
        Visible          = false,
        ZIndex           = 4,
    })
    corner(indicator, R_PILL)

    local content = new("Frame", {
        Parent                 = root,
        Name                   = "Content",
        Position               = verticalTabs and UDim2.fromOffset(tabBarW, 44) or UDim2.fromOffset(0, 44),
        Size                   = verticalTabs and UDim2.new(1, -tabBarW, 1, -44) or UDim2.new(1, 0, 1, -44 - tabBarH),
        BackgroundTransparency = 1,
        ClipsDescendants       = true,
    })

    makeDraggable(root, titleBar)

    if hasToggleKey then
        register(UIS.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.KeyCode == toggleKey then
                if windowRef and windowRef.Toggle then
                    windowRef:Toggle()
                else
                    Library:Toggle()
                end
            end
        end))
    end

    if mobile then makeMobileButton() end

    local searchBox = new("TextBox", {
        Parent                 = titleBar,
        AnchorPoint            = Vector2.new(1, 0.5),
        Position               = UDim2.new(1, -76, 0.5, 0),
        Size                   = UDim2.fromOffset(searchWidth, 26),
        BackgroundColor3       = Theme.Bg2,
        BorderSizePixel        = 0,
        Font                   = FONT,
        TextSize               = TEXT_SM,
        TextColor3             = Theme.Text,
        PlaceholderColor3      = Theme.DimText,
        PlaceholderText        = "Search...",
        Text                   = "",
        TextXAlignment         = Enum.TextXAlignment.Left,
        ClearTextOnFocus       = false,
        ClipsDescendants       = true,
        ZIndex                 = 10,
        Visible                = searchEnabled,
    })
    corner(searchBox, R_PILL)
    pad(searchBox, 10, 0, 10, 0)
    local searchStroke = stroke(searchBox, Theme.Border, 1)

    searchBox.Focused:Connect(function()
        tween(searchStroke, 0.14, { Color = Theme.Accent })
    end)
    searchBox.FocusLost:Connect(function()
        tween(searchStroke, 0.14, { Color = Theme.Border })
    end)

    local self = setmetatable({
        Root        = root,
        Shadow      = shadow,
        TitleBar    = titleBar,
        TabBar      = tabBar,
        TabRow      = tabRow,
        Indicator   = indicator,
        Content     = content,
        SearchBox   = searchBox,
        Tabs        = {},
        ActiveTab   = nil,
        Title       = title,
        ScriptName  = scriptName,
        CloseMode   = closeMode,
        OnClose     = opts.OnClose,
        ConfirmClose = confirmClose,
        CloseTitle  = type(confirmClose) == "table" and confirmClose.Title or nil,
        CloseText   = type(confirmClose) == "table" and confirmClose.Text or nil,
        Watermark   = wmFrame,
        WatermarkLabels = wmLabels,
        TabLayout   = verticalTabs and "vertical" or "horizontal",
        VerticalTabs = verticalTabs,
        TabBarSize  = verticalTabs and tabBarW or tabBarH,
    }, Window)
    windowRef = self

    function self:_applyResponsive()
        local nextSize = smartWindowSize(baseSize, opts, verticalTabs)
        root.Size = nextSize
        shadow.Size = nextSize + UDim2.fromOffset(60, 60)

        local width = nextSize.X.Offset > 0 and nextSize.X.Offset or root.AbsoluteSize.X
        local compact = width > 0 and width < 450
        local currentSearchWidth = compact and 0 or searchWidth
        local showSearch = searchEnabled and not compact
        searchBox.Visible = showSearch
        searchBox.Size = UDim2.fromOffset(currentSearchWidth, 26)
        searchBox.Position = UDim2.new(1, -76, 0.5, 0)

        local rightInset = showSearch and (currentSearchWidth + 112) or 90
        titleText.Size = UDim2.new(1, -rightInset, titleText.Size.Y.Scale, titleText.Size.Y.Offset)
        if subtitleText then
            subtitleText.Size = UDim2.new(1, -rightInset, 0, 14)
        end

        if verticalTabs then
            local currentTabW = smartTabWidth(baseTabBarW, width, opts)
            tabBar.Size = UDim2.new(0, currentTabW, 1, -44)
            content.Position = UDim2.fromOffset(currentTabW, 44)
            content.Size = UDim2.new(1, -currentTabW, 1, -44)
            self.TabBarSize = currentTabW
        else
            tabBar.Size = UDim2.new(1, 0, 0, tabBarH)
            content.Position = UDim2.fromOffset(0, 44)
            content.Size = UDim2.new(1, 0, 1, -44 - tabBarH)
            self.TabBarSize = tabBarH
        end

        fitWindowToViewport(root, opts)
        task.defer(function()
            if self.ActiveTab then self:_updateIndicator(self.ActiveTab, false) end
        end)
    end

    if wmFrame and wmTransparency > 0 then
        self:SetWatermarkTransparency(wmTransparency)
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        self:_filterElements(searchBox.Text)
    end)

    table.insert(Library.Windows, self)
    if isPrimary and not Library.PrimaryWindow then
        Library.PrimaryWindow = self
    end
    self:_applyResponsive()
    local cam = workspace.CurrentCamera
    if cam then
        register(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            if self.Root and self.Root.Parent then
                self:_applyResponsive()
            end
        end))
    end
    return self
end

function Window:SetWatermarkVisible(v)
    if self.Watermark then self.Watermark.Visible = v and true or false end
end

function Window:SetVisible(v)
    v = v and true or false
    if not v then
        if Library._activeDropdown then pcall(Library._activeDropdown.Close, Library._activeDropdown) end
        if Library._activeColorpicker then pcall(Library._activeColorpicker.Close, Library._activeColorpicker) end
        if Library._listeningKeybind then Library._listeningKeybind:Cancel() end
    elseif self._applyResponsive then
        self:_applyResponsive()
    end
    if self.Root then self.Root.Visible = v end
    if self.Shadow then self.Shadow.Visible = v end
end

function Window:Toggle(state)
    if state == nil then
        state = not (self.Root and self.Root.Visible)
    end
    self:SetVisible(state)
end

function Window:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    if self._closeConfirm and self._closeConfirm.Parent then self._closeConfirm:Destroy() end
    if Library._activeDropdown then pcall(Library._activeDropdown.Close, Library._activeDropdown) end
    if Library._activeColorpicker then pcall(Library._activeColorpicker.Close, Library._activeColorpicker) end
    if self.Watermark and self.Watermark.Parent then self.Watermark:Destroy() end
    if self.Shadow and self.Shadow.Parent then self.Shadow:Destroy() end
    if self.Root and self.Root.Parent then self.Root:Destroy() end
    for i, w in ipairs(Library.Windows) do
        if w == self then table.remove(Library.Windows, i) break end
    end
    if Library.PrimaryWindow == self then
        Library.PrimaryWindow = Library.Windows[1]
    end
    if self.OnClose then task.spawn(self.OnClose, self, "destroy") end
end

function Window:_closeNow()
    local mode = tostring(self.CloseMode or "library"):lower()
    if mode == "hide" or mode == "toggle" or mode == "minimize" then
        self:SetVisible(false)
        if self.OnClose then task.spawn(self.OnClose, self, "hide") end
    elseif mode == "destroy" or mode == "window" then
        self:Destroy()
    else
        Library:Destroy()
    end
end

function Window:SetWatermarkTransparency(value)
    value = clamp(tonumber(value) or 0, 0, 1)
    if not self.Watermark then return end
    self.Watermark.BackgroundTransparency = value
    for _, d in ipairs(self.Watermark:GetDescendants()) do
        if d:IsA("TextLabel") then
            d.TextTransparency = value
        elseif d:IsA("ImageLabel") then
            d.ImageTransparency = value
        elseif d:IsA("Frame") then
            d.BackgroundTransparency = value
        elseif d:IsA("UIStroke") then
            d.Transparency = value
        end
    end
end

function Window:RequestClose()
    if self.ConfirmClose == false then
        self:_closeNow()
    else
        self:_showCloseConfirm()
    end
end

function Window:_showCloseConfirm()
    if self._closeConfirm and self._closeConfirm.Parent then return end
    local sg = getScreenGui()
    local scriptName = self.ScriptName or self.Title or Library.ScriptName or "Obscura"

    local overlay = new("Frame", {
        Parent                 = sg,
        Name                   = "ObscuraCloseConfirm",
        Size                   = UDim2.fromScale(1, 1),
        BackgroundColor3       = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.52,
        BorderSizePixel        = 0,
        ZIndex                 = 20000,
    })
    self._closeConfirm = overlay

    local dialog = new("Frame", {
        Parent           = overlay,
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.fromScale(0.5, 0.5),
        Size             = UDim2.fromOffset(330, 158),
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel  = 0,
        ZIndex           = 20001,
    })
    corner(dialog, R_LG)
    stroke(dialog, Theme.BorderHi, 1)
    pad(dialog, 18, 16, 18, 16)
    listLayout(dialog, Enum.FillDirection.Vertical, 10)

    new("TextLabel", {
        Parent                 = dialog,
        Size                   = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Font                   = FONT_SB,
        TextSize               = TEXT_LG,
        TextColor3             = Theme.Text,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Text                   = self.CloseTitle or ("Close " .. scriptName .. "?"),
        ZIndex                 = 20002,
    })
    new("TextLabel", {
        Parent                 = dialog,
        Size                   = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1,
        Font                   = FONT,
        TextSize               = TEXT_SM,
        TextColor3             = Theme.SubText,
        TextWrapped            = true,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextYAlignment         = Enum.TextYAlignment.Top,
        Text                   = self.CloseText or "Are you sure you want to close this menu?",
        ZIndex                 = 20002,
    })

    local actions = new("Frame", {
        Parent                 = dialog,
        Size                   = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
        ZIndex                 = 20002,
    })
    listLayout(actions, Enum.FillDirection.Horizontal, 8,
        Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

    local cancel = new("TextButton", {
        Parent           = actions,
        Size             = UDim2.fromOffset(92, 32),
        BackgroundColor3 = Theme.Bg2,
        BorderSizePixel  = 0,
        Text             = "Cancel",
        Font             = FONT_M,
        TextSize         = TEXT_SM,
        TextColor3       = Theme.Text,
        AutoButtonColor  = false,
        ZIndex           = 20003,
        LayoutOrder      = 1,
    })
    corner(cancel, R_PILL)
    stroke(cancel, Theme.Border, 1)

    local close = new("TextButton", {
        Parent           = actions,
        Size             = UDim2.fromOffset(96, 32),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel  = 0,
        Text             = "Close",
        Font             = FONT_M,
        TextSize         = TEXT_SM,
        TextColor3       = Theme.AccentText,
        AutoButtonColor  = false,
        ZIndex           = 20003,
        LayoutOrder      = 2,
    })
    corner(close, R_PILL)

    cancel.MouseEnter:Connect(function() tween(cancel, 0.14, { BackgroundColor3 = Theme.Bg3 }) end)
    cancel.MouseLeave:Connect(function() tween(cancel, 0.14, { BackgroundColor3 = Theme.Bg2 }) end)
    close.MouseEnter:Connect(function() tween(close, 0.14, { BackgroundColor3 = accentHoverColor() }) end)
    close.MouseLeave:Connect(function() tween(close, 0.14, { BackgroundColor3 = Theme.Accent }) end)

    cancel.MouseButton1Click:Connect(function()
        if overlay and overlay.Parent then overlay:Destroy() end
    end)
    close.MouseButton1Click:Connect(function()
        if overlay and overlay.Parent then overlay:Destroy() end
        self:_closeNow()
    end)
end

function Window:_filterElements(query)
    query = query:lower()
    for _, tab in ipairs(self.Tabs) do
        for _, section in ipairs(tab.Sections) do
            for _, item in ipairs(section.Content:GetChildren()) do
                if item:IsA("GuiObject") and not item:IsA("UIListLayout") and not item:IsA("UIPadding") then
                    if query == "" then
                        item.Visible = true
                    else
                        local found = false
                        for _, desc in ipairs(item:GetDescendants()) do
                            if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
                                if desc.Text and desc.Text:lower():find(query, 1, true) then
                                    found = true
                                    break
                                end
                            end
                        end
                        if item:IsA("TextLabel") and item.Text:lower():find(query, 1, true) then
                            found = true
                        end
                        item.Visible = found
                    end
                end
            end
        end

        if query ~= "" then
            tab.Page.Visible = true
        end
    end
    if query == "" and self.ActiveTab then
        for _, t in ipairs(self.Tabs) do
            t.Page.Visible = (t == self.ActiveTab)
        end
    end
end

function Window:_updateIndicator(tab, animate)
    local ind = self.Indicator
    if not tab then ind.Visible = false return end
    ind.Visible = true
    local btn = tab.Button

    local newPos
    if self.VerticalTabs then
        local btnAbsY = btn.AbsolutePosition.Y
        local btnH    = btn.AbsoluteSize.Y
        local barAbsY = self.TabBar.AbsolutePosition.Y
        local cy = btnAbsY - barAbsY + btnH / 2
        newPos = UDim2.fromOffset(0, cy)
    else
        local btnAbsX = btn.AbsolutePosition.X
        local btnW    = btn.AbsoluteSize.X
        local barAbsX = self.TabBar.AbsolutePosition.X
        local cx = btnAbsX - barAbsX + btnW / 2
        newPos = UDim2.fromOffset(cx, 0)
    end
    if animate then
        tween(ind, 0.22, { Position = newPos }, Enum.EasingStyle.Quart)
    else
        ind.Position = newPos
    end
end

local Tab = {}
Tab.__index = Tab

function Window:Notify(opts)
    return Library:Notify(opts)
end

function Window:CreateTab(name, iconAsset)
    name = tostring(name or "Tab")
    local vertical = self.VerticalTabs

    local btn = new("TextButton", {
        Parent                 = self.TabRow,
        Name                   = name,
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        Text                   = "",
        AutoButtonColor        = false,
        Size                   = vertical and UDim2.new(1, 0, 0, 46) or UDim2.new(0, 0, 1, 0),
    })
    if vertical then
        pad(btn, 10, 0, 10, 0)
        listLayout(btn, Enum.FillDirection.Horizontal, 8,
            Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    else
        pad(btn, 4, 6, 4, 6)
        listLayout(btn, Enum.FillDirection.Vertical, 2,
            Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
    end

    local iconImg
    local iconName = type(iconAsset) == "table" and iconAsset.Icon or iconAsset
    if iconName then
        local image, rectOffset, rectSize = getIcon(iconName)
        if not image then image = iconName end
        iconImg = new("ImageLabel", {
            Parent                 = btn,
            Size                   = UDim2.fromOffset(vertical and 18 or 20, vertical and 18 or 20),
            BackgroundTransparency = 1,
            Image                  = image,
            ImageRectOffset        = rectOffset or Vector2.new(0, 0),
            ImageRectSize          = rectSize or Vector2.new(0, 0),
            ImageColor3            = Theme.SubText,
            LayoutOrder            = 1,
            ScaleType              = Enum.ScaleType.Fit,
        })
        bindTheme(iconImg, "ImageColor3", "SubText")
    end

    local label = new("TextLabel", {
        Parent                 = btn,
        BackgroundTransparency = 1,
        Size                   = vertical and UDim2.new(1, -30, 1, 0) or UDim2.new(1, 0, 0, 16),
        Font                   = FONT_M,
        TextSize               = TEXT_SM,
        TextColor3             = Theme.SubText,
        TextXAlignment         = vertical and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
        TextTruncate           = Enum.TextTruncate.AtEnd,
        Text                   = name,
        LayoutOrder            = 2,
    })

    local page = new("ScrollingFrame", {
        Parent                 = self.Content,
        Name                   = name,
        Size                   = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        ScrollBarThickness     = 2,
        ScrollBarImageColor3   = Theme.BorderHi,
        ScrollingDirection     = Enum.ScrollingDirection.Y,
        CanvasSize             = UDim2.new(),
        AutomaticCanvasSize    = Enum.AutomaticSize.Y,
        Visible                = false,
    })
    pad(page, 18, 14, 18, 18)
    listLayout(page, Enum.FillDirection.Vertical, 14)

    local tab = setmetatable({
        Window = self, Name = name, Button = btn, Page = page,
        Label = label, Icon = iconImg, Sections = {},
    }, Tab)

    btn.MouseEnter:Connect(function()
        if self.ActiveTab ~= tab then
            tween(label, 0.14, { TextColor3 = Theme.Text })
            if iconImg then tween(iconImg, 0.14, { ImageColor3 = Theme.Text }) end
        end
    end)
    btn.MouseLeave:Connect(function()
        if self.ActiveTab ~= tab then
            tween(label, 0.14, { TextColor3 = Theme.SubText })
            if iconImg then tween(iconImg, 0.14, { ImageColor3 = Theme.SubText }) end
        end
    end)
    btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)

    table.insert(self.Tabs, tab)
    if not self.ActiveTab then
        self:SelectTab(tab)
    else

        task.defer(function() self:_updateIndicator(self.ActiveTab, false) end)
    end
    return tab
end

function Window:SelectTab(tab)
    for _, t in ipairs(self.Tabs) do
        local active = (t == tab)
        t.Page.Visible = active
        if active then
            tween(t.Label, 0.18, { TextColor3 = Theme.Accent })
            t.Label.Font = FONT_SB
            if t.Icon then tween(t.Icon, 0.18, { ImageColor3 = Theme.Accent }) end
        else
            tween(t.Label, 0.18, { TextColor3 = Theme.SubText })
            t.Label.Font = FONT_M
            if t.Icon then tween(t.Icon, 0.18, { ImageColor3 = Theme.SubText }) end
        end
    end
    local prev = self.ActiveTab
    self.ActiveTab = tab

    task.defer(function()
        self:_updateIndicator(tab, prev ~= nil)
    end)
end

local Section = {}
Section.__index = Section

local function makeSettingsButton(parent, xOffset)
    local btn = new("TextButton", {
        Parent                 = parent,
        AnchorPoint            = Vector2.new(1, 0.5),
        Position               = UDim2.new(1, xOffset or -2, 0.5, 0),
        Size                   = UDim2.fromOffset(28, 28),
        BackgroundColor3       = Theme.Bg2,
        BackgroundTransparency = 0.35,
        BorderSizePixel        = 0,
        Text                   = "",
        AutoButtonColor        = false,
        ZIndex                 = 20,
    })
    corner(btn, R_PILL)
    local btnStroke = stroke(btn, Theme.Border, 1)

    local icon = drawSettingsGlyph(btn, 16, Theme.SubText)

    btn.MouseEnter:Connect(function()
        tween(btn, 0.14, { BackgroundTransparency = 0, BackgroundColor3 = Theme.Bg3 })
        tween(btnStroke, 0.14, { Color = Theme.BorderHi })
        icon:SetColor(Theme.Text, "Text")
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, 0.14, { BackgroundTransparency = 0.35, BackgroundColor3 = Theme.Bg2 })
        tween(btnStroke, 0.14, { Color = Theme.Border })
        icon:SetColor(Theme.SubText, "SubText")
    end)
    return btn
end

local function createInlineSection(owner, parent, opts)
    opts = type(opts) == "table" and opts or { Title = tostring(opts or "") }
    local title = opts.Title or opts.Name or ""
    local explicitSize = typeof(opts.Size) == "UDim2"
    local frame = new("Frame", {
        Parent                 = parent,
        Name                   = tostring(title ~= "" and title or "Submenu"),
        Size                   = explicitSize and opts.Size or UDim2.new(1, 0, 0, 0),
        AutomaticSize          = explicitSize and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
        BackgroundColor3       = opts.BackgroundColor3 or Theme.Bg2,
        BackgroundTransparency = opts.Transparent and 1 or (tonumber(opts.Transparency) or 0),
        BorderSizePixel        = 0,
        Visible                = opts.Visible ~= false,
        ClipsDescendants       = opts.Clips == true,
    })
    corner(frame, opts.Radius or R_LG)
    stroke(frame, opts.BorderColor3 or Theme.Border, 1)
    pad(frame, 10, 9, 10, 10)
    listLayout(frame, Enum.FillDirection.Vertical, 7)

    if title ~= "" then
        new("TextLabel", {
            Parent                 = frame,
            Size                   = UDim2.new(1, 0, 0, 14),
            BackgroundTransparency = 1,
            Font                   = FONT_SB,
            TextSize               = TEXT_XS,
            TextColor3             = Theme.SubText,
            TextXAlignment         = Enum.TextXAlignment.Left,
            Text                   = string.upper(tostring(title)),
            LayoutOrder            = 0,
        })
    end

    local content = new("Frame", {
        Parent                 = frame,
        Name                   = "Content",
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder            = 1,
    })
    listLayout(content, Enum.FillDirection.Vertical, 6)

    return setmetatable({
        Tab = owner.Tab,
        Frame = frame,
        Content = content,
        Name = title,
        Items = {},
        ParentSection = owner,
    }, Section)
end

local function populateInlineSection(section, spec)
    if type(spec) == "function" then
        pcall(spec, section)
    elseif type(spec) == "table" then
        for _, item in ipairs(spec) do
            if type(item) == "table" then
                local kind = tostring(item.Type or item.Kind or item.Element or item[1] or ""):lower()
                if kind == "label" then section:AddLabel(item.Text or item.Label or "")
                elseif kind == "paragraph" then section:AddParagraph(item)
                elseif kind == "divider" then section:AddDivider()
                elseif kind == "button" then section:AddButton(item)
                elseif kind == "toggle" then section:AddToggle(item)
                elseif kind == "slider" then section:AddSlider(item)
                elseif kind == "dropdown" then section:AddDropdown(item)
                elseif kind == "multidropdown" or kind == "multi-dropdown" then section:AddMultiDropdown(item)
                elseif kind == "textbox" or kind == "input" then section:AddTextbox(item)
                elseif kind == "keybind" then section:AddKeybind(item)
                elseif kind == "colorpicker" or kind == "color" then section:AddColorpicker(item)
                end
            end
        end
    end
end

local function normalizePanelSpec(spec, defaultTitle)
    if type(spec) == "table"
        and (spec.Title or spec.Name or spec.Items or spec.Elements or spec.Build
            or spec.Size or spec.Visible ~= nil or spec.Transparency or spec.Transparent) then
        return spec
    end
    return { Title = defaultTitle, Build = spec }
end

function Section:CreateSubmenu(opts)
    opts = opts or {}
    local section = createInlineSection(self, self.Content, opts)
    populateInlineSection(section, opts.Items or opts.Elements or opts.Build)
    return section
end

function Tab:CreateSection(name, _side)

    local frame = new("Frame", {
        Parent                 = self.Page,
        Name                   = name or "Section",
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    listLayout(frame, Enum.FillDirection.Vertical, 8)

    if name and name ~= "" then
        new("TextLabel", {
            Parent                 = frame,
            Size                   = UDim2.new(1, 0, 0, 14),
            BackgroundTransparency = 1,
            Font                   = FONT_SB,
            TextSize               = TEXT_XS,
            TextColor3             = Theme.SubText,
            TextXAlignment         = Enum.TextXAlignment.Left,
            Text                   = string.upper(tostring(name)),
            LayoutOrder            = 0,
        })
    end

    local content = new("Frame", {
        Parent                 = frame,
        Name                   = "Content",
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder            = 1,
    })
    listLayout(content, Enum.FillDirection.Vertical, 6)

    local section = setmetatable({
        Tab = self, Frame = frame, Content = content, Name = name, Items = {},
    }, Section)
    table.insert(self.Sections, section)
    return section
end

function Section:AddLabel(text, iconName)
    local hasIcon = iconName and type(iconName) == "string"
    local iconImage, iconOffset, iconSize
    if hasIcon then
        iconImage, iconOffset, iconSize = getIcon(iconName)
        hasIcon = iconImage ~= nil
    end

    local container
    if hasIcon then
        container = new("Frame", {
            Parent                 = self.Content,
            Size                   = UDim2.new(1, 0, 0, 18),
            AutomaticSize          = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
        })
        local icon = new("ImageLabel", {
            Parent              = container,
            BackgroundTransparency = 1,
            AnchorPoint         = Vector2.new(0, 0.5),
            Size                = UDim2.fromOffset(16, 16),
            Position            = UDim2.fromOffset(0, 9),
            Image               = iconImage,
            ImageRectOffset     = iconOffset,
            ImageRectSize       = iconSize,
            ImageColor3         = Theme.SubText,
            ScaleType           = Enum.ScaleType.Fit,
        })
        bindTheme(icon, "ImageColor3", "SubText")
    end

    local lbl = new("TextLabel", {
        Parent                 = hasIcon and container or self.Content,
        Size                   = hasIcon and UDim2.new(1, -22, 0, 18) or UDim2.new(1, 0, 0, 18),
        Position               = hasIcon and UDim2.fromOffset(22, 0) or UDim2.new(0, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Font                   = FONT,
        TextSize               = TEXT_MD,
        TextColor3             = Theme.SubText,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextYAlignment         = Enum.TextYAlignment.Top,
        TextWrapped            = true,
        Text                   = tostring(text or ""),
    })
    local api = {}
    function api:Set(t) lbl.Text = tostring(t) end
    function api:SetColor(c) lbl.TextColor3 = c end
    return api
end

function Section:AddParagraph(opts)
    opts = opts or {}
    local frame = new("Frame", {
        Parent           = self.Content,
        Size             = UDim2.new(1, 0, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Bg2,
        BorderSizePixel  = 0,
    })
    corner(frame, R_MD)
    pad(frame, 12, 10, 12, 10)
    listLayout(frame, Enum.FillDirection.Vertical, 4)

    local title = new("TextLabel", {
        Parent                 = frame,
        Size                   = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Font                   = FONT_SB,
        TextSize               = TEXT_MD,
        TextColor3             = Theme.Text,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Text                   = tostring(opts.Title or "Paragraph"),
    })
    local body = new("TextLabel", {
        Parent                 = frame,
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Font                   = FONT,
        TextSize               = TEXT_SM,
        TextColor3             = Theme.SubText,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextYAlignment         = Enum.TextYAlignment.Top,
        TextWrapped            = true,
        Text                   = tostring(opts.Text or ""),
    })

    local api = {}
    function api:SetTitle(t) title.Text = tostring(t) end
    function api:SetText(t)  body.Text  = tostring(t) end
    return api
end

function Section:AddDivider()
    local frame = new("Frame", {
        Parent                 = self.Content,
        Size                   = UDim2.new(1, 0, 0, 8),
        BackgroundTransparency = 1,
    })
    new("Frame", {
        Parent           = frame,
        Size             = UDim2.new(1, 0, 0, 1),
        Position         = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel  = 0,
    })
end

function Section:AddButton(opts)
    opts = opts or {}
    local text     = tostring(opts.Text or "Button")
    local callback = opts.Callback or function() end
    local style    = (opts.Style or "filled"):lower()
    local settingsSpec = opts.Settings

    local outer = new("Frame", {
        Parent                 = self.Content,
        Size                   = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1,
    })

    local btn = new("TextButton", {
        Parent           = outer,
        Size             = settingsSpec and UDim2.new(1, -36, 1, 0) or UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = (style == "filled") and Theme.Accent or Theme.Bg,
        BorderSizePixel  = 0,
        Text             = "",
        AutoButtonColor  = false,
    })
    corner(btn, R_MD)
    local s
    if style == "outlined" then s = stroke(btn, Theme.BorderHi, 1) end

    local hasIcon = opts.Icon and type(opts.Icon) == "string"
    local iconImage, iconOffset, iconSize
    if hasIcon then
        iconImage, iconOffset, iconSize = getIcon(opts.Icon)
        hasIcon = iconImage ~= nil
    end

    if hasIcon then
        local icon = new("ImageLabel", {
            Parent              = btn,
            BackgroundTransparency = 1,
            AnchorPoint         = Vector2.new(0, 0.5),
            Size                = UDim2.fromOffset(18, 18),
            Position            = UDim2.new(0, 10, 0.5, 0),
            Image               = iconImage,
            ImageRectOffset     = iconOffset,
            ImageRectSize       = iconSize,
            ImageColor3         = (style == "filled") and Theme.AccentText or Theme.Text,
            ScaleType           = Enum.ScaleType.Fit,
        })
        bindTheme(icon, "ImageColor3", (style == "filled") and "AccentText" or "Text")
    end

    local label = new("TextLabel", {
        Parent                 = btn,
        BackgroundTransparency = 1,
        Size                   = hasIcon and UDim2.new(1, -34, 1, 0) or UDim2.fromScale(1, 1),
        Position               = hasIcon and UDim2.new(0, 32, 0, 0) or UDim2.new(0, 0, 0, 0),
        Font                   = FONT_M,
        TextSize               = TEXT_MD,
        TextColor3             = (style == "filled") and Theme.AccentText or Theme.Text,
        TextXAlignment         = hasIcon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
        Text                   = text,
    })

    local settingsSection
    if settingsSpec then
        local settingsBtn = makeSettingsButton(outer, 0)
        settingsBtn.MouseButton1Click:Connect(function()
            if not settingsSection then
                local panelOpts = normalizePanelSpec(settingsSpec, text .. " settings")
                panelOpts.Visible = false
                settingsSection = createInlineSection(self, self.Content, panelOpts)
                populateInlineSection(settingsSection, panelOpts.Items or panelOpts.Elements or panelOpts.Build)
            end
            settingsSection.Frame.Visible = not settingsSection.Frame.Visible
        end)
    end

    if style == "filled" then
        btn.MouseEnter:Connect(function() tween(btn, 0.14, { BackgroundColor3 = accentHoverColor() }) end)
        btn.MouseLeave:Connect(function() tween(btn, 0.14, { BackgroundColor3 = Theme.Accent }) end)
    else
        attachHover(btn, "Bg", "Bg2", s)
    end

    btn.MouseButton1Click:Connect(function()

        local origSize = btn.Size
        tween(btn, 0.06, { Size = origSize - UDim2.fromOffset(0, 2) })
        task.delay(0.08, function() tween(btn, 0.12, { Size = origSize }) end)
        task.spawn(callback)
    end)

    local api = {}
    function api:SetText(t) label.Text = tostring(t) end
    function api:SetCallback(fn) callback = fn or function() end end
    function api:Fire() task.spawn(callback) end
    return Library:_attachElementExtras(api, opts, "button")
end

function Section:AddToggle(opts)
    opts = opts or {}
    local text     = tostring(opts.Text or "Toggle")
    local default  = opts.Default and true or false
    local flag     = opts.Flag
    local callback = opts.Callback or function() end
    local settingsSpec = opts.Settings
    local submenuSpec  = opts.Submenu or opts.Menu or opts.Children

    local outer = new("Frame", {
        Parent                 = self.Content,
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    listLayout(outer, Enum.FillDirection.Vertical, 5)

    local line = new("Frame", {
        Parent                 = outer,
        Size                   = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
    })

    local row = new("TextButton", {
        Parent                 = line,
        Size                   = settingsSpec and UDim2.new(1, -36, 1, 0) or UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        Text                   = "",
        AutoButtonColor        = false,
    })
    corner(row, R_MD)
    pad(row, 4, 0, 4, 0)

    local hasIcon = opts.Icon and type(opts.Icon) == "string"
    local iconImage, iconOffset, iconSize
    if hasIcon then
        iconImage, iconOffset, iconSize = getIcon(opts.Icon)
        hasIcon = iconImage ~= nil
    end

    if hasIcon then
        local icon = new("ImageLabel", {
            Parent              = row,
            BackgroundTransparency = 1,
            AnchorPoint         = Vector2.new(0, 0.5),
            Size                = UDim2.fromOffset(18, 18),
            Position            = UDim2.new(0, 6, 0.5, 0),
            Image               = iconImage,
            ImageRectOffset     = iconOffset,
            ImageRectSize       = iconSize,
            ImageColor3         = Theme.Text,
            ScaleType           = Enum.ScaleType.Fit,
        })
        bindTheme(icon, "ImageColor3", "Text")
    end

    local rightSpace = 54
    local label = new("TextLabel", {
        Parent                 = row,
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, hasIcon and -(rightSpace + 30) or -rightSpace, 1, 0),
        Position               = hasIcon and UDim2.new(0, 30, 0, 0) or UDim2.new(0, 0, 0, 0),
        Font                   = FONT_M,
        TextSize               = TEXT_MD,
        TextColor3             = Theme.Text,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Text                   = text,
    })

    local track = new("Frame", {
        Parent           = row,
        AnchorPoint      = Vector2.new(1, 0.5),
        Position         = UDim2.new(1, -2, 0.5, 0),
        Size             = UDim2.fromOffset(38, 22),
        BackgroundColor3 = Theme.Track,
        BorderSizePixel  = 0,
    })
    corner(track, R_PILL)
    local knob = new("Frame", {
        Parent           = track,
        AnchorPoint      = Vector2.new(0, 0.5),
        Position         = UDim2.new(0, 2, 0.5, 0),
        Size             = UDim2.fromOffset(18, 18),
        BackgroundColor3 = Theme.Knob,
        BorderSizePixel  = 0,
        ZIndex           = 2,
    })
    corner(knob, R_PILL)

    local knobShadow = new("ImageLabel", {
        Parent                 = knob,
        ZIndex                 = 1,
        Size                   = UDim2.new(1, 16, 1, 16),
        Position               = UDim2.fromOffset(-8, -6),
        BackgroundTransparency = 1,
        Image                  = "rbxasset://textures/ui/Controls/DropShadow.png",
        ImageColor3            = Theme.Shadow,
        ImageTransparency      = 0.86,
        ScaleType              = Enum.ScaleType.Slice,
        SliceCenter            = Rect.new(12, 12, 244, 244),
    })

    local parentSection = self
    local state = default
    local api = {}
    local submenus = {}

    local function render(animate)
        local trackKey   = state and "Accent" or "Track"
        local knobKey    = state and "AccentText" or "Knob"
        local trackColor = Theme[trackKey]
        local knobColor  = Theme[knobKey]
        local knobPos    = state and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
        if animate then
            tween(track, 0.18, { BackgroundColor3 = trackColor })
            tween(knob,  0.22, { Position = knobPos, BackgroundColor3 = knobColor },
                Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        else
            track.BackgroundColor3 = trackColor
            knob.BackgroundColor3  = knobColor
            knob.Position          = knobPos
        end
        pcall(function() track:SetAttribute("ObsT_BackgroundColor3", trackKey) end)
        pcall(function() knob:SetAttribute("ObsT_BackgroundColor3", knobKey) end)
        for _, submenu in ipairs(submenus) do
            if submenu and submenu.Frame then
                submenu.Frame.Visible = state
            end
        end
    end

    function api:Set(v, silent)
        local newState = v and true or false
        local changed = newState ~= state
        state = newState
        render(true)
        if flag then Library:SetFlag(flag, state) end
        if not silent and changed then task.spawn(callback, state) end
    end
    function api:Get() return state end
    function api:Toggle() api:Set(not state) end
    function api:SetText(t) label.Text = tostring(t) end
    function api:CreateSubmenu(panelOpts)
        panelOpts = normalizePanelSpec(panelOpts or {}, text .. " menu")
        panelOpts.Visible = state
        local submenu = createInlineSection(parentSection, outer, panelOpts)
        table.insert(submenus, submenu)
        populateInlineSection(submenu, panelOpts.Items or panelOpts.Elements or panelOpts.Build)
        return submenu
    end

    local settingsSection
    if settingsSpec then
        local settingsBtn = makeSettingsButton(line, 0)
        settingsBtn.MouseButton1Click:Connect(function()
            if not settingsSection then
                local panelOpts = normalizePanelSpec(settingsSpec, text .. " settings")
                panelOpts.Visible = false
                settingsSection = createInlineSection(self, outer, panelOpts)
                populateInlineSection(settingsSection, panelOpts.Items or panelOpts.Elements or panelOpts.Build)
            end
            settingsSection.Frame.Visible = not settingsSection.Frame.Visible
        end)
    end

    row.MouseButton1Click:Connect(function() api:Toggle() end)

    if flag then Library:BindFlag(flag, api) end
    if submenuSpec then api:CreateSubmenu(submenuSpec) end
    api:Set(default, true)
    render(false)
    return Library:_attachElementExtras(api, opts, "toggle")
end

function Section:AddSlider(opts)
    opts = opts or {}
    local text     = tostring(opts.Text or "Slider")
    local minV     = tonumber(opts.Min) or 0
    local maxV     = tonumber(opts.Max) or 100
    local default  = clamp(tonumber(opts.Default) or minV, minV, maxV)
    local decimals = tonumber(opts.Decimals) or 0
    local step     = tonumber(opts.Step)
    local suffix   = tostring(opts.Suffix or "")
    local flag     = opts.Flag
    local callback = opts.Callback or function() end
    local settingsSpec = opts.Settings

    local frame = new("Frame", {
        Parent                 = self.Content,
        Size                   = UDim2.new(1, 0, 0, 58),
        BackgroundTransparency = 1,
        Active                 = true,
    })
    pad(frame, 4, 0, 4, 0)

    local hasIcon = opts.Icon and type(opts.Icon) == "string"
    local iconImage, iconOffset, iconSize
    if hasIcon then
        iconImage, iconOffset, iconSize = getIcon(opts.Icon)
        hasIcon = iconImage ~= nil
    end

    if hasIcon then
        local icon = new("ImageLabel", {
            Parent              = frame,
            BackgroundTransparency = 1,
            AnchorPoint         = Vector2.new(0, 0.5),
            Size                = UDim2.fromOffset(16, 16),
            Position            = UDim2.fromOffset(2, 9),
            Image               = iconImage,
            ImageRectOffset     = iconOffset,
            ImageRectSize       = iconSize,
            ImageColor3         = Theme.SubText,
            ScaleType           = Enum.ScaleType.Fit,
        })
        bindTheme(icon, "ImageColor3", "SubText")
    end

    local rightSpace = settingsSpec and 142 or 116
    local label = new("TextLabel", {
        Parent                 = frame,
        BackgroundTransparency = 1,
        Position               = hasIcon and UDim2.fromOffset(22, 0) or UDim2.fromOffset(2, 0),
        Size                   = UDim2.new(1, hasIcon and -(rightSpace + 22) or -rightSpace, 0, 18),
        Font                   = FONT_M,
        TextSize               = TEXT_SM,
        TextColor3             = Theme.SubText,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextTruncate           = Enum.TextTruncate.AtEnd,
        Text                   = text,
    })
    local valueLabel = new("TextLabel", {
        Parent                 = frame,
        BackgroundTransparency = 1,
        AnchorPoint            = Vector2.new(1, 0),
        Position               = settingsSpec and UDim2.new(1, -36, 0, 0) or UDim2.new(1, -2, 0, 0),
        Size                   = UDim2.fromOffset(settingsSpec and 96 or 112, 18),
        Font                   = FONT_SB,
        TextSize               = TEXT_SM,
        TextColor3             = Theme.Text,
        TextXAlignment         = Enum.TextXAlignment.Right,
        Text                   = tostring(default) .. suffix,
    })

    local settingsSection
    if settingsSpec then
        local settingsBtn = makeSettingsButton(frame, -2)
        settingsBtn.AnchorPoint = Vector2.new(1, 0)
        settingsBtn.Position = UDim2.new(1, -2, 0, 0)
        settingsBtn.MouseButton1Click:Connect(function()
            if not settingsSection then
                local panelOpts = normalizePanelSpec(settingsSpec, text .. " settings")
                panelOpts.Visible = false
                settingsSection = createInlineSection(self, self.Content, panelOpts)
                populateInlineSection(settingsSection, panelOpts.Items or panelOpts.Elements or panelOpts.Build)
            end
            settingsSection.Frame.Visible = not settingsSection.Frame.Visible
        end)
    end

    local TRACK_Y = 34
    local TRACK_H = 6
    local track = new("Frame", {
        Parent           = frame,
        Position         = UDim2.new(0, 0, 0, TRACK_Y),
        Size             = UDim2.new(1, 0, 0, TRACK_H),
        BackgroundColor3 = Theme.Track,
        BorderSizePixel  = 0,
        Active           = true,
        ClipsDescendants = true,
    })
    corner(track, R_PILL)
    local fill = new("Frame", {
        Parent           = track,
        Size             = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel  = 0,
    })
    corner(fill, R_PILL)

    local halo = new("Frame", {
        Parent                 = frame,
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0, 0, 0, TRACK_Y + TRACK_H / 2),
        Size                   = UDim2.fromOffset(26, 24),
        BackgroundColor3       = Theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        ZIndex                 = 2,
    })
    corner(halo, R_PILL)

    local thumb = new("Frame", {
        Parent           = frame,
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(0, 0, 0, TRACK_Y + TRACK_H / 2),
        Size             = UDim2.fromOffset(6, 20),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel  = 0,
        ZIndex           = 3,
    })
    corner(thumb, R_PILL)

    local hitArea = new("TextButton", {
        Parent                 = frame,
        Position               = UDim2.new(0, 0, 0, TRACK_Y - 14),
        Size                   = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        Text                   = "",
        AutoButtonColor        = false,
        ZIndex                 = 4,
        Active                 = true,
    })

    local value = default
    local api = {}

    local function quantize(v)
        v = tonumber(v) or minV
        if step and step > 0 then
            v = minV + round((v - minV) / step, 0) * step
        end
        return clamp(round(v, decimals), minV, maxV)
    end

    local function render(snap)
        local pct = (maxV == minV) and 0 or clamp((value - minV) / (maxV - minV), 0, 1)
        local fillSize = UDim2.new(pct, 0, 1, 0)
        local thumbPos = UDim2.new(pct, 0, 0, TRACK_Y + TRACK_H / 2)
        if snap then
            fill.Size = fillSize
            thumb.Position = thumbPos
            halo.Position = thumbPos
        else
            tween(fill, 0.10, { Size = fillSize })
            tween(thumb, 0.10, { Position = thumbPos })
            tween(halo, 0.10, { Position = thumbPos })
        end
        valueLabel.Text = tostring(round(value, decimals)) .. suffix
    end

    function api:Set(v, silent)
        v = quantize(v)
        local changed = v ~= value
        value = v
        render(true)
        if flag then Library:SetFlag(flag, value) end
        if not silent and changed then task.spawn(callback, value) end
    end
    function api:Get() return value end
    function api:SetText(t) label.Text = tostring(t) end
    function api:SetRange(a, b) minV, maxV = a, b; api:Set(value, true) end
    function api:SetStep(v) step = tonumber(v); api:Set(value, true) end

    local dragging = false
    local function updateFromInput(input)
        local abs  = track.AbsolutePosition.X
        local size = track.AbsoluteSize.X
        local x = clamp(input.Position.X - abs, 0, size)
        local pct = size > 0 and (x / size) or 0
        api:Set(minV + (maxV - minV) * pct)
    end

    local function onBegan(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            tween(halo, 0.12, { BackgroundTransparency = 0.86 })
            tween(thumb, 0.12, { Size = UDim2.fromOffset(8, 22) })
            updateFromInput(input)
        end
    end
    hitArea.InputBegan:Connect(onBegan)

    register(UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input)
        end
    end))
    register(UIS.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            tween(halo, 0.16, { BackgroundTransparency = 1 })
            tween(thumb, 0.16, { Size = UDim2.fromOffset(6, 20) })
        end
    end))

    api:Set(default, true)
    return Library:_attachElementExtras(api, opts, "slider")
end

function Section:AddDropdown(opts)
    opts = opts or {}
    local text     = tostring(opts.Text or "Dropdown")
    local options  = opts.Options or {}
    local default  = opts.Default
    local flag     = opts.Flag
    local callback = opts.Callback or function() end

    local frame = new("Frame", {
        Parent                 = self.Content,
        Size                   = UDim2.new(1, 0, 0, 54),
        BackgroundTransparency = 1,
    })

    local hasIcon = opts.Icon and type(opts.Icon) == "string"
    local iconImage, iconOffset, iconSize
    if hasIcon then
        iconImage, iconOffset, iconSize = getIcon(opts.Icon)
        hasIcon = iconImage ~= nil
    end

    if hasIcon then
        local icon = new("ImageLabel", {
            Parent              = frame,
            BackgroundTransparency = 1,
            AnchorPoint         = Vector2.new(0, 0.5),
            Size                = UDim2.fromOffset(16, 16),
            Position            = UDim2.fromOffset(2, 8),
            Image               = iconImage,
            ImageRectOffset     = iconOffset,
            ImageRectSize       = iconSize,
            ImageColor3         = Theme.SubText,
            ScaleType           = Enum.ScaleType.Fit,
        })
        bindTheme(icon, "ImageColor3", "SubText")
    end

    new("TextLabel", {
        Parent                 = frame,
        BackgroundTransparency = 1,
        Position               = hasIcon and UDim2.fromOffset(20, 0) or UDim2.fromOffset(2, 0),
        Size                   = UDim2.new(1, hasIcon and -22 or -4, 0, 16),
        Font                   = FONT_M,
        TextSize               = TEXT_SM,
        TextColor3             = Theme.SubText,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Text                   = text,
    })

    local btn = new("TextButton", {
        Parent           = frame,
        Position         = UDim2.fromOffset(0, 20),
        Size             = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.Bg2,
        BorderSizePixel  = 0,
        Text             = "",
        AutoButtonColor  = false,
    })
    corner(btn, R_MD)
    local s = stroke(btn, Theme.Border, 1)

    local valueLabel = new("TextLabel", {
        Parent                 = btn,
        BackgroundTransparency = 1,
        Position               = UDim2.fromOffset(12, 0),
        Size                   = UDim2.new(1, -36, 1, 0),
        Font                   = FONT_M,
        TextSize               = TEXT_MD,
        TextColor3             = Theme.DimText,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextTruncate           = Enum.TextTruncate.AtEnd,
        Text                   = "—",
    })

    local arrowHolder = new("Frame", {
        Parent                 = btn,
        AnchorPoint            = Vector2.new(1, 0.5),
        Position               = UDim2.new(1, -10, 0.5, 0),
        Size                   = UDim2.fromOffset(12, 7),
        BackgroundTransparency = 1,
    })
    local chevron = drawChevron(arrowHolder, 12, Theme.SubText)

    local list = new("Frame", {
        Parent           = getScreenGui(),
        Visible          = false,
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel  = 0,
        ZIndex           = 1000,
    })
    corner(list, R_MD)
    stroke(list, Theme.BorderHi, 1)

    new("ImageLabel", {
        Parent                 = list,
        ZIndex                 = 999,
        Size                   = UDim2.new(1, 30, 1, 30),
        Position               = UDim2.fromOffset(-15, -10),
        BackgroundTransparency = 1,
        Image                  = "rbxasset://textures/ui/Controls/DropShadow.png",
        ImageColor3            = Theme.Shadow,
        ImageTransparency      = 0.85,
        ScaleType              = Enum.ScaleType.Slice,
        SliceCenter            = Rect.new(12, 12, 244, 244),
    })

    local listScroll = new("ScrollingFrame", {
        Parent                 = list,
        Size                   = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        ScrollBarThickness     = 2,
        ScrollBarImageColor3   = Theme.BorderHi,
        CanvasSize             = UDim2.new(),
        AutomaticCanvasSize    = Enum.AutomaticSize.Y,
        ZIndex                 = 1000,
    })
    pad(listScroll, 6)
    listLayout(listScroll, Enum.FillDirection.Vertical, 2)

    local current = nil
    local api = {}

    local function render()
        if current == nil then
            valueLabel.Text       = "Select…"
            valueLabel.TextColor3 = Theme.DimText
        else
            valueLabel.Text       = tostring(current)
            valueLabel.TextColor3 = Theme.Text
        end
    end

    function api:Set(v, silent)
        if v == nil then
            current = nil
        else
            local found = false
            for _, opt in ipairs(options) do
                if opt == v then found = true break end
            end
            if found then current = v end
        end
        render()
        if flag then Library:SetFlag(flag, current) end
        if not silent then task.spawn(callback, current) end
    end
    function api:Get() return current end

    function api:UpdatePosition()
        if not list.Visible then return end
        local absPos  = btn.AbsolutePosition
        local absSize = btn.AbsoluteSize
        local count   = #options
        local listH   = math.min(count * 30 + 12, 220)
        local screenH = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 600
        local yBelow  = absPos.Y + absSize.Y + 6
        local yAbove  = absPos.Y - listH - 6
        local yFinal  = (yBelow + listH > screenH and yAbove >= 0) and yAbove or yBelow
        list.Position = UDim2.fromOffset(absPos.X, yFinal)
        list.Size     = UDim2.fromOffset(absSize.X, listH)
    end

    function api:Open()
        if Library._activeDropdown and Library._activeDropdown ~= api then
            Library._activeDropdown:Close()
        end
        Library._activeDropdown = api
        list.Visible = true
        api:UpdatePosition()
        chevron:SetOpen(true)
        tween(s, 0.14, { Color = Theme.Accent })
    end
    function api:Close()
        list.Visible = false
        chevron:SetOpen(false)
        tween(s, 0.14, { Color = Theme.Border })
        if Library._activeDropdown == api then Library._activeDropdown = nil end
    end

    function api:Refresh(newOptions, keepSelection)
        options = newOptions or {}
        for _, c in ipairs(listScroll:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
        end
        if #options == 0 then
            new("TextLabel", {
                Parent                 = listScroll,
                Size                   = UDim2.new(1, 0, 0, 28),
                BackgroundTransparency = 1,
                Font                   = FONT,
                TextSize               = TEXT_SM,
                TextColor3             = Theme.DimText,
                Text                   = "No items",
                ZIndex                 = 1001,
            })
        end
        for i, opt in ipairs(options) do
            local item = new("TextButton", {
                Parent                 = listScroll,
                Size                   = UDim2.new(1, 0, 0, 28),
                BackgroundColor3       = Theme.Bg,
                BackgroundTransparency = 1,
                BorderSizePixel        = 0,
                Text                   = "",
                AutoButtonColor        = false,
                LayoutOrder            = i,
                ZIndex                 = 1001,
            })
            corner(item, R_SM)
            local isCurrent = (current == opt)
            if isCurrent then
                item.BackgroundTransparency = 0
                item.BackgroundColor3       = Theme.Accent
            end
            local itemLbl = new("TextLabel", {
                Parent                 = item,
                BackgroundTransparency = 1,
                Position               = UDim2.fromOffset(12, 0),
                Size                   = UDim2.new(1, -24, 1, 0),
                Font                   = FONT_M,
                TextSize               = TEXT_SM,
                TextColor3             = isCurrent and Theme.AccentText or Theme.Text,
                TextXAlignment         = Enum.TextXAlignment.Left,
                TextTruncate           = Enum.TextTruncate.AtEnd,
                Text                   = tostring(opt),
                ZIndex                 = 1002,
            })

            item.MouseEnter:Connect(function()
                if current ~= opt then
                    tween(item, 0.1, { BackgroundTransparency = 0, BackgroundColor3 = Theme.Bg2 })
                end
            end)
            item.MouseLeave:Connect(function()
                if current ~= opt then
                    tween(item, 0.1, { BackgroundTransparency = 1 })
                end
            end)
            item.MouseButton1Click:Connect(function()
                api:Set(opt)
                api:Close()
            end)
        end
        if not keepSelection then api:Set(nil, true) end
    end

    btn.MouseEnter:Connect(function()
        tween(btn, 0.14, { BackgroundColor3 = Theme.Bg3 })
        if not list.Visible then tween(s, 0.14, { Color = Theme.BorderHi }) end
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, 0.14, { BackgroundColor3 = Theme.Bg2 })
        if not list.Visible then tween(s, 0.14, { Color = Theme.Border }) end
    end)
    btn.MouseButton1Click:Connect(function()
        if list.Visible then api:Close() else api:Open() end
    end)

    api.Button = btn
    api.List   = list

    if flag then Library:BindFlag(flag, api) end
    api:Refresh(options, true)
    if default ~= nil then api:Set(default, true) end
    render()
    return Library:_attachElementExtras(api, opts, "dropdown")
end

function Section:AddMultiDropdown(opts)
    opts = opts or {}
    local text     = tostring(opts.Text or "MultiDropdown")
    local options  = opts.Options or {}
    local default  = opts.Default or {}
    local maxSel   = tonumber(opts.Max) or math.huge
    local flag     = opts.Flag
    local callback = opts.Callback or function() end

    local frame = new("Frame", {
        Parent                 = self.Content,
        Size                   = UDim2.new(1, 0, 0, 54),
        BackgroundTransparency = 1,
    })
    new("TextLabel", {
        Parent                 = frame,
        BackgroundTransparency = 1,
        Position               = UDim2.fromOffset(2, 0),
        Size                   = UDim2.new(1, 0, 0, 16),
        Font                   = FONT_M,
        TextSize               = TEXT_SM,
        TextColor3             = Theme.SubText,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Text                   = text,
    })

    local btn = new("TextButton", {
        Parent           = frame,
        Position         = UDim2.fromOffset(0, 20),
        Size             = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.Bg2,
        BorderSizePixel  = 0,
        Text             = "",
        AutoButtonColor  = false,
    })
    corner(btn, R_MD)
    local s = stroke(btn, Theme.Border, 1)

    local valueLabel = new("TextLabel", {
        Parent                 = btn,
        BackgroundTransparency = 1,
        Position               = UDim2.fromOffset(12, 0),
        Size                   = UDim2.new(1, -36, 1, 0),
        Font                   = FONT_M,
        TextSize               = TEXT_MD,
        TextColor3             = Theme.DimText,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Text                   = "Select…",
        TextTruncate           = Enum.TextTruncate.AtEnd,
    })

    local arrowHolder = new("Frame", {
        Parent                 = btn,
        AnchorPoint            = Vector2.new(1, 0.5),
        Position               = UDim2.new(1, -10, 0.5, 0),
        Size                   = UDim2.fromOffset(12, 7),
        BackgroundTransparency = 1,
    })
    local chevron = drawChevron(arrowHolder, 12, Theme.SubText)

    local list = new("Frame", {
        Parent           = getScreenGui(),
        Visible          = false,
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel  = 0,
        ZIndex           = 1000,
    })
    corner(list, R_MD)
    stroke(list, Theme.BorderHi, 1)
    new("ImageLabel", {
        Parent                 = list,
        ZIndex                 = 999,
        Size                   = UDim2.new(1, 30, 1, 30),
        Position               = UDim2.fromOffset(-15, -10),
        BackgroundTransparency = 1,
        Image                  = "rbxasset://textures/ui/Controls/DropShadow.png",
        ImageColor3            = Theme.Shadow,
        ImageTransparency      = 0.85,
        ScaleType              = Enum.ScaleType.Slice,
        SliceCenter            = Rect.new(12, 12, 244, 244),
    })

    local listScroll = new("ScrollingFrame", {
        Parent                 = list,
        Size                   = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        ScrollBarThickness     = 2,
        ScrollBarImageColor3   = Theme.BorderHi,
        CanvasSize             = UDim2.new(),
        AutomaticCanvasSize    = Enum.AutomaticSize.Y,
        ZIndex                 = 1000,
    })
    pad(listScroll, 6)
    listLayout(listScroll, Enum.FillDirection.Vertical, 2)

    local selected = {}
    local items = {}
    local api = {}

    local function render()
        local arr = {}
        for k, vv in pairs(selected) do
            if vv then table.insert(arr, k) end
        end
        if #arr == 0 then
            valueLabel.Text       = "Select…"
            valueLabel.TextColor3 = Theme.DimText
        else
            table.sort(arr, function(a, b) return tostring(a) < tostring(b) end)
            valueLabel.Text       = table.concat(arr, ", ")
            valueLabel.TextColor3 = Theme.Text
        end
        for opt, item in pairs(items) do
            if item and item.Btn then
                local on = selected[opt] and true or false
                tween(item.Btn, 0.12, {
                    BackgroundColor3       = on and Theme.Accent or Theme.Bg,
                    BackgroundTransparency = on and 0 or 1,
                })
                tween(item.Label, 0.12, {
                    TextColor3 = on and Theme.AccentText or Theme.Text,
                })
            end
        end
    end

    function api:Set(tbl, silent)
        selected = {}
        for _, vv in ipairs(tbl or {}) do selected[vv] = true end
        render()
        if flag then Library:SetFlag(flag, self:Get()) end
        if not silent then task.spawn(callback, self:Get()) end
    end
    function api:Get()
        local arr = {}
        for k, vv in pairs(selected) do if vv then table.insert(arr, k) end end
        return arr
    end
    function api:Toggle(opt)
        if selected[opt] then
            selected[opt] = nil
        else
            local count = 0
            for _, vv in pairs(selected) do if vv then count += 1 end end
            if count >= maxSel then return end
            selected[opt] = true
        end
        render()
        if flag then Library:SetFlag(flag, self:Get()) end
        task.spawn(callback, self:Get())
    end

    function api:UpdatePosition()
        if not list.Visible then return end
        local absPos  = btn.AbsolutePosition
        local absSize = btn.AbsoluteSize
        local count   = #options
        local listH   = math.min(count * 30 + 12, 220)
        local screenH = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 600
        local yBelow  = absPos.Y + absSize.Y + 6
        local yAbove  = absPos.Y - listH - 6
        local yFinal  = (yBelow + listH > screenH and yAbove >= 0) and yAbove or yBelow
        list.Position = UDim2.fromOffset(absPos.X, yFinal)
        list.Size     = UDim2.fromOffset(absSize.X, listH)
    end

    function api:Open()
        if Library._activeDropdown and Library._activeDropdown ~= api then
            Library._activeDropdown:Close()
        end
        Library._activeDropdown = api
        list.Visible = true
        api:UpdatePosition()
        chevron:SetOpen(true)
        tween(s, 0.14, { Color = Theme.Accent })
    end
    function api:Close()
        list.Visible = false
        chevron:SetOpen(false)
        tween(s, 0.14, { Color = Theme.Border })
        if Library._activeDropdown == api then Library._activeDropdown = nil end
    end

    function api:Refresh(newOptions)
        options = newOptions or {}
        for _, c in ipairs(listScroll:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
        end
        items = {}
        if #options == 0 then
            new("TextLabel", {
                Parent                 = listScroll,
                Size                   = UDim2.new(1, 0, 0, 28),
                BackgroundTransparency = 1,
                Font                   = FONT,
                TextSize               = TEXT_SM,
                TextColor3             = Theme.DimText,
                Text                   = "No items",
                ZIndex                 = 1001,
            })
        end
        for i, opt in ipairs(options) do
            local item = new("TextButton", {
                Parent                 = listScroll,
                Size                   = UDim2.new(1, 0, 0, 28),
                BackgroundColor3       = Theme.Bg,
                BackgroundTransparency = 1,
                BorderSizePixel        = 0,
                Text                   = "",
                AutoButtonColor        = false,
                LayoutOrder            = i,
                ZIndex                 = 1001,
            })
            corner(item, R_SM)

            local lbl = new("TextLabel", {
                Parent                 = item,
                BackgroundTransparency = 1,
                Position               = UDim2.fromOffset(12, 0),
                Size                   = UDim2.new(1, -24, 1, 0),
                Font                   = FONT_M,
                TextSize               = TEXT_SM,
                TextColor3             = Theme.Text,
                TextXAlignment         = Enum.TextXAlignment.Left,
                TextTruncate           = Enum.TextTruncate.AtEnd,
                Text                   = tostring(opt),
                ZIndex                 = 1002,
            })
            item.MouseEnter:Connect(function()
                if not selected[opt] then
                    tween(item, 0.1, { BackgroundTransparency = 0, BackgroundColor3 = Theme.Bg2 })
                end
            end)
            item.MouseLeave:Connect(function()
                if not selected[opt] then
                    tween(item, 0.1, { BackgroundTransparency = 1 })
                end
            end)
            item.MouseButton1Click:Connect(function() api:Toggle(opt) end)
            items[opt] = { Btn = item, Label = lbl }
        end
        render()
    end

    btn.MouseEnter:Connect(function()
        tween(btn, 0.14, { BackgroundColor3 = Theme.Bg3 })
        if not list.Visible then tween(s, 0.14, { Color = Theme.BorderHi }) end
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, 0.14, { BackgroundColor3 = Theme.Bg2 })
        if not list.Visible then tween(s, 0.14, { Color = Theme.Border }) end
    end)
    btn.MouseButton1Click:Connect(function()
        if list.Visible then api:Close() else api:Open() end
    end)

    api.Button = btn
    api.List   = list

    if flag then Library:BindFlag(flag, api) end
    api:Refresh(options)
    api:Set(default, true)
    return Library:_attachElementExtras(api, opts, "dropdown")
end

function Section:AddTextbox(opts)
    opts = opts or {}
    local text         = tostring(opts.Text or "Input")
    local placeholder  = tostring(opts.Placeholder or "")
    local default      = tostring(opts.Default or "")
    local clearOnFocus = opts.ClearOnFocus and true or false
    local numeric      = opts.Numeric and true or false
    local flag         = opts.Flag
    local callback     = opts.Callback or function() end

    local frame = new("Frame", {
        Parent                 = self.Content,
        Size                   = UDim2.new(1, 0, 0, 54),
        BackgroundTransparency = 1,
    })

    local hasIcon = opts.Icon and type(opts.Icon) == "string"
    local iconImage, iconOffset, iconSize
    if hasIcon then
        iconImage, iconOffset, iconSize = getIcon(opts.Icon)
        hasIcon = iconImage ~= nil
    end

    if hasIcon then
        local icon = new("ImageLabel", {
            Parent              = frame,
            BackgroundTransparency = 1,
            AnchorPoint         = Vector2.new(0, 0.5),
            Size                = UDim2.fromOffset(16, 16),
            Position            = UDim2.fromOffset(2, 8),
            Image               = iconImage,
            ImageRectOffset     = iconOffset,
            ImageRectSize       = iconSize,
            ImageColor3         = Theme.SubText,
            ScaleType           = Enum.ScaleType.Fit,
        })
        bindTheme(icon, "ImageColor3", "SubText")
    end

    new("TextLabel", {
        Parent                 = frame,
        BackgroundTransparency = 1,
        Position               = hasIcon and UDim2.fromOffset(20, 0) or UDim2.fromOffset(2, 0),
        Size                   = UDim2.new(1, hasIcon and -22 or -4, 0, 16),
        Font                   = FONT_M,
        TextSize               = TEXT_SM,
        TextColor3             = Theme.SubText,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Text                   = text,
    })

    local box = new("Frame", {
        Parent           = frame,
        Position         = UDim2.fromOffset(0, 20),
        Size             = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.Bg2,
        BorderSizePixel  = 0,
    })
    corner(box, R_MD)
    local s = stroke(box, Theme.Border, 1)

    local input = new("TextBox", {
        Parent                 = box,
        BackgroundTransparency = 1,
        Position               = UDim2.fromOffset(12, 0),
        Size                   = UDim2.new(1, -24, 1, 0),
        Font                   = FONT,
        TextSize               = TEXT_MD,
        TextColor3             = Theme.Text,
        PlaceholderColor3      = Theme.DimText,
        PlaceholderText        = placeholder,
        Text                   = default,
        ClearTextOnFocus       = clearOnFocus,
        TextXAlignment         = Enum.TextXAlignment.Left,
        ClipsDescendants       = true,
    })

    local api = {}
    function api:Set(t, silent)
        t = tostring(t)
        if numeric then t = (tonumber(t) and t) or "" end
        input.Text = t
        if flag then Library:SetFlag(flag, t) end
        if not silent then task.spawn(callback, t) end
    end
    function api:Get() return input.Text end

    input.Focused:Connect(function()
        tween(s,   0.14, { Color = Theme.Accent, Thickness = 1.5 })
        tween(box, 0.14, { BackgroundColor3 = Theme.Bg })
    end)
    input.FocusLost:Connect(function(enter)
        tween(s,   0.14, { Color = Theme.Border, Thickness = 1 })
        tween(box, 0.14, { BackgroundColor3 = Theme.Bg2 })
        if numeric and tonumber(input.Text) == nil then input.Text = "" end
        if flag then Library:SetFlag(flag, input.Text) end
        task.spawn(callback, input.Text, enter)
    end)

    if flag then Library:BindFlag(flag, api) end
    if default ~= "" and flag then Library:SetFlag(flag, default) end
    return Library:_attachElementExtras(api, opts, "textbox")
end

function Section:AddKeybind(opts)
    opts = opts or {}
    local text      = tostring(opts.Text or "Keybind")
    local default   = opts.Default
    local mode      = (opts.Mode or "Toggle"):lower()
    local flag      = opts.Flag
    local callback  = opts.Callback or function() end
    local onChanged = opts.OnChanged or function() end

    local row = new("Frame", {
        Parent                 = self.Content,
        Size                   = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
    })
    pad(row, 4, 0, 4, 0)

    local hasIcon = opts.Icon and type(opts.Icon) == "string"
    local iconImage, iconOffset, iconSize
    if hasIcon then
        iconImage, iconOffset, iconSize = getIcon(opts.Icon)
        hasIcon = iconImage ~= nil
    end

    if hasIcon then
        local icon = new("ImageLabel", {
            Parent              = row,
            BackgroundTransparency = 1,
            AnchorPoint         = Vector2.new(0, 0.5),
            Size                = UDim2.fromOffset(18, 18),
            Position            = UDim2.new(0, 6, 0.5, 0),
            Image               = iconImage,
            ImageRectOffset     = iconOffset,
            ImageRectSize       = iconSize,
            ImageColor3         = Theme.Text,
            ScaleType           = Enum.ScaleType.Fit,
        })
        bindTheme(icon, "ImageColor3", "Text")
    end

    new("TextLabel", {
        Parent                 = row,
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, hasIcon and -140 or -110, 1, 0),
        Position               = hasIcon and UDim2.new(0, 30, 0, 0) or UDim2.new(0, 0, 0, 0),
        Font                   = FONT_M,
        TextSize               = TEXT_MD,
        TextColor3             = Theme.Text,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Text                   = text,
    })

    local btn = new("TextButton", {
        Parent           = row,
        AnchorPoint      = Vector2.new(1, 0.5),
        Position         = UDim2.new(1, 0, 0.5, 0),
        Size             = UDim2.fromOffset(96, 26),
        BackgroundColor3 = Theme.Bg2,
        BorderSizePixel  = 0,
        Text             = keyToString(default),
        Font             = FONT_M,
        TextSize         = TEXT_SM,
        TextColor3       = Theme.Text,
        AutoButtonColor  = false,
    })
    corner(btn, R_PILL)
    local bs = stroke(btn, Theme.BorderHi, 1)

    local key = default
    local listening = false
    local toggled = false

    local api = {}
    function api:Set(k, silent)
        key = k
        btn.Text = keyToString(key)
        if flag then Library:SetFlag(flag, key) end
        if not silent then task.spawn(onChanged, key) end
    end
    function api:Get() return key end
    function api:GetMode() return mode end
    function api:SetMode(m) mode = (m or "Toggle"):lower() end
    function api:Cancel()
        if not listening then return end
        listening = false
        btn.Text = keyToString(key)
        tween(bs,  0.14, { Color = Theme.BorderHi })
        tween(btn, 0.14, { BackgroundColor3 = Theme.Bg2 })
        btn.TextColor3 = Theme.Text
        if Library._listeningKeybind == api then
            Library._listeningKeybind = nil
        end
    end

    btn.MouseEnter:Connect(function()
        if not listening then tween(btn, 0.14, { BackgroundColor3 = Theme.Bg3 }) end
    end)
    btn.MouseLeave:Connect(function()
        if not listening then tween(btn, 0.14, { BackgroundColor3 = Theme.Bg2 }) end
    end)

    btn.MouseButton1Click:Connect(function()
        if listening then
            api:Cancel()
            return
        end
        if Library._listeningKeybind and Library._listeningKeybind ~= api then
            Library._listeningKeybind:Cancel()
        end
        listening = true
        Library._listeningKeybind = api
        btn.Text = "Press…"
        tween(bs,  0.14, { Color = Theme.Accent })
        tween(btn, 0.14, { BackgroundColor3 = Theme.Bg })
        btn.TextColor3 = Theme.Accent
    end)

    register(UIS.InputBegan:Connect(function(input, processed)
        if listening then
            if processed then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape then
                    api:Cancel()
                    return
                elseif input.KeyCode == Enum.KeyCode.Backspace then
                    api:Set(nil)
                else
                    api:Set(input.KeyCode)
                end
            elseif input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.MouseButton2
                or input.UserInputType == Enum.UserInputType.MouseButton3 then
                api:Set(input.UserInputType)
            else
                return
            end
            listening = false
            tween(bs,  0.14, { Color = Theme.BorderHi })
            tween(btn, 0.14, { BackgroundColor3 = Theme.Bg2 })
            btn.TextColor3 = Theme.Text
            if Library._listeningKeybind == api then
                Library._listeningKeybind = nil
            end
            return
        end
        if processed then return end
        if isKeyPressed(key, input) then
            if mode == "toggle" then
                toggled = not toggled
                task.spawn(callback, toggled)
            elseif mode == "hold" then
                task.spawn(callback, true)
            elseif mode == "always" then
                task.spawn(callback)
            end
        end
    end))
    register(UIS.InputEnded:Connect(function(input)
        if mode == "hold" and isKeyPressed(key, input) then
            task.spawn(callback, false)
        end
    end))

    if flag then Library:BindFlag(flag, api) end
    if default and flag then Library:SetFlag(flag, default) end
    return api
end

local function hslToColor(h, s, l)
    local function f(n)
        local k = (n + h * 12) % 12
        local a = s * math.min(l, 1 - l)
        return l - a * math.max(-1, math.min(k - 3, 9 - k, 1))
    end
    return Color3.new(f(0), f(8), f(4))
end

local function colorToHL(c)
    local mx = math.max(c.R, c.G, c.B)
    local mn = math.min(c.R, c.G, c.B)
    local l = (mx + mn) / 2
    local h
    if mx == mn then
        h = 0
    else
        local d = mx - mn
        if mx == c.R then
            h = ((c.G - c.B) / d) % 6
        elseif mx == c.G then
            h = (c.B - c.R) / d + 2
        else
            h = (c.R - c.G) / d + 4
        end
        h = h / 6
        if h < 0 then h = h + 1 end
    end
    return h, l
end

function Section:AddColorpicker(opts)
    opts = opts or {}
    local text     = tostring(opts.Text or "Color")
    local default  = opts.Default or Color3.fromRGB(255, 255, 255)
    local hasAlpha = opts.Alpha == true
    local flag     = opts.Flag
    local callback = opts.Callback or function() end

    local row = new("Frame", {
        Parent                 = self.Content,
        Size                   = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
    })
    pad(row, 4, 0, 4, 0)

    local hasIcon = opts.Icon and type(opts.Icon) == "string"
    local iconImage, iconOffset, iconSize
    if hasIcon then
        iconImage, iconOffset, iconSize = getIcon(opts.Icon)
        hasIcon = iconImage ~= nil
    end

    if hasIcon then
        local icon = new("ImageLabel", {
            Parent              = row,
            BackgroundTransparency = 1,
            AnchorPoint         = Vector2.new(0, 0.5),
            Size                = UDim2.fromOffset(18, 18),
            Position            = UDim2.new(0, 6, 0.5, 0),
            Image               = iconImage,
            ImageRectOffset     = iconOffset,
            ImageRectSize       = iconSize,
            ImageColor3         = Theme.Text,
            ScaleType           = Enum.ScaleType.Fit,
        })
        bindTheme(icon, "ImageColor3", "Text")
    end

    new("TextLabel", {
        Parent                 = row,
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, hasIcon and -80 or -50, 1, 0),
        Position               = hasIcon and UDim2.new(0, 30, 0, 0) or UDim2.new(0, 0, 0, 0),
        Font                   = FONT_M,
        TextSize               = TEXT_MD,
        TextColor3             = Theme.Text,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Text                   = text,
    })

    local swatch = new("TextButton", {
        Parent           = row,
        AnchorPoint      = Vector2.new(1, 0.5),
        Position         = UDim2.new(1, 0, 0.5, 0),
        Size             = UDim2.fromOffset(38, 22),
        BackgroundColor3 = default,
        BorderSizePixel  = 0,
        Text             = "",
        AutoButtonColor  = false,
    })
    corner(swatch, R_PILL)
    local swStroke = stroke(swatch, Theme.BorderHi, 1)
    swatch:SetAttribute("ObsPreserve", true)

    local POP_W   = 240
    local headerH = 30
    local stripH  = 16
    local previewH = 32
    local hexH    = 28
    local gap     = 10
    local popupH  = 12 + headerH + 6 + previewH + gap + stripH + gap + stripH
                    + (hasAlpha and (gap + stripH) or 0) + gap + hexH + 12

    local popup = new("Frame", {
        Parent           = getScreenGui(),
        Visible          = false,
        Size             = UDim2.fromOffset(POP_W, popupH),
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel  = 0,
        ZIndex           = 1500,
        Active           = true,
    })
    corner(popup, R_LG)
    stroke(popup, Theme.BorderHi, 1)
    pad(popup, 12, 12, 12, 12)

    new("ImageLabel", {
        Parent                 = popup,
        ZIndex                 = 1499,
        Size                   = UDim2.new(1, 40, 1, 40),
        Position               = UDim2.fromOffset(-20, -14),
        BackgroundTransparency = 1,
        Image                  = "rbxasset://textures/ui/Controls/DropShadow.png",
        ImageColor3            = Theme.Shadow,
        ImageTransparency      = 0.84,
        ScaleType              = Enum.ScaleType.Slice,
        SliceCenter            = Rect.new(12, 12, 244, 244),
    })

    local header = new("Frame", {
        Parent                 = popup,
        Size                   = UDim2.new(1, 0, 0, headerH),
        BackgroundTransparency = 1,
        ZIndex                 = 1501,
        Active                 = true,
    })
    new("TextLabel", {
        Parent                 = header,
        BackgroundTransparency = 1,
        Position               = UDim2.fromOffset(0, 0),
        Size                   = UDim2.new(1, -32, 1, 0),
        Font                   = FONT_SB,
        TextSize               = TEXT_MD,
        TextColor3             = Theme.Text,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Text                   = text,
        ZIndex                 = 1502,
    })

    local closeBtn = new("TextButton", {
        Parent                 = header,
        AnchorPoint            = Vector2.new(1, 0.5),
        Position               = UDim2.new(1, 0, 0.5, 0),
        Size                   = UDim2.fromOffset(22, 22),
        BackgroundColor3       = Theme.Bg2,
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        Text                   = "",
        AutoButtonColor        = false,
        ZIndex                 = 1502,
    })
    corner(closeBtn, R_PILL)
    local crossHolder = new("Frame", {
        Parent                 = closeBtn,
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.fromScale(0.5, 0.5),
        Size                   = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 1,
        ZIndex                 = 1503,
    })
    local crossIcon = drawCross(crossHolder, 10, Theme.SubText)
    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, 0.12, { BackgroundTransparency = 0, BackgroundColor3 = Theme.Bg3 })
        crossIcon:SetColor(Theme.Text)
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, 0.12, { BackgroundTransparency = 1 })
        crossIcon:SetColor(Theme.SubText)
    end)

    local nextY = headerH + 6

    local preview = new("Frame", {
        Parent           = popup,
        Position         = UDim2.fromOffset(0, nextY),
        Size             = UDim2.new(1, 0, 0, previewH),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel  = 0,
        ZIndex           = 1501,
    })
    corner(preview, R_MD)
    stroke(preview, Theme.BorderHi, 1)
    preview:SetAttribute("ObsPreserve", true)
    nextY = nextY + previewH + gap

    local hueBar = new("Frame", {
        Parent          = popup,
        Position        = UDim2.fromOffset(0, nextY),
        Size            = UDim2.new(1, 0, 0, stripH),
        BorderSizePixel = 0,
        ZIndex          = 1501,
        Active          = true,
    })
    corner(hueBar, R_PILL)
    hueBar:SetAttribute("ObsPreserve", true)
    new("UIGradient", {
        Parent = hueBar,
        Color  = ColorSequence.new({
            ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(1/6,  Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(2/6,  Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(3/6,  Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(4/6,  Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(5/6,  Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1,    Color3.fromRGB(255, 0, 0)),
        }),
    })
    local hueCursor = new("Frame", {
        Parent           = hueBar,
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Size             = UDim2.fromOffset(4, stripH + 6),
        Position         = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel  = 0,
        ZIndex           = 1503,
    })
    corner(hueCursor, R_SM)
    local hueCStroke = stroke(hueCursor, Color3.fromRGB(0, 0, 0), 1)
    hueCursor:SetAttribute("ObsPreserve", true)
    hueCStroke:SetAttribute("ObsPreserve", true)
    nextY = nextY + stripH + gap

    local lightBar = new("Frame", {
        Parent           = popup,
        Position         = UDim2.fromOffset(0, nextY),
        Size             = UDim2.new(1, 0, 0, stripH),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel  = 0,
        ZIndex           = 1501,
        Active           = true,
    })
    corner(lightBar, R_PILL)
    lightBar:SetAttribute("ObsPreserve", true)
    local lightGrad = new("UIGradient", { Parent = lightBar })
    local lightCursor = new("Frame", {
        Parent           = lightBar,
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Size             = UDim2.fromOffset(4, stripH + 6),
        Position         = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel  = 0,
        ZIndex           = 1503,
    })
    corner(lightCursor, R_SM)
    local lightCStroke = stroke(lightCursor, Color3.fromRGB(0, 0, 0), 1)
    lightCursor:SetAttribute("ObsPreserve", true)
    lightCStroke:SetAttribute("ObsPreserve", true)
    nextY = nextY + stripH + gap

    local alphaBar, alphaCursor
    if hasAlpha then
        alphaBar = new("Frame", {
            Parent           = popup,
            Position         = UDim2.fromOffset(0, nextY),
            Size             = UDim2.new(1, 0, 0, stripH),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel  = 0,
            ZIndex           = 1501,
            Active           = true,
        })
        corner(alphaBar, R_PILL)
        alphaBar:SetAttribute("ObsPreserve", true)
        new("UIGradient", {
            Parent = alphaBar,
            Color  = ColorSequence.new(Color3.fromRGB(0,0,0), Color3.fromRGB(255,255,255)),
        })
        alphaCursor = new("Frame", {
            Parent           = alphaBar,
            AnchorPoint      = Vector2.new(0.5, 0.5),
            Size             = UDim2.fromOffset(4, stripH + 6),
            Position         = UDim2.new(1, 0, 0.5, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel  = 0,
            ZIndex           = 1503,
        })
        corner(alphaCursor, R_SM)
        local alphaCStroke = stroke(alphaCursor, Color3.fromRGB(0, 0, 0), 1)
        alphaCursor:SetAttribute("ObsPreserve", true)
        alphaCStroke:SetAttribute("ObsPreserve", true)
        nextY = nextY + stripH + gap
    end

    local hex = new("TextBox", {
        Parent                 = popup,
        Position               = UDim2.fromOffset(0, nextY),
        Size                   = UDim2.new(1, 0, 0, hexH),
        BackgroundColor3       = Theme.Bg2,
        BorderSizePixel        = 0,
        Font                   = FONT_M,
        TextSize               = TEXT_SM,
        TextColor3             = Theme.Text,
        PlaceholderColor3      = Theme.DimText,
        PlaceholderText        = "#FFFFFF",
        Text                   = "",
        ClearTextOnFocus       = false,
        ZIndex                 = 1501,
    })
    corner(hex, R_MD)
    local hexStroke = stroke(hex, Theme.Border, 1)

    local h, l = colorToHL(default)
    local alpha = 1
    local userMoved = false
    local lastCallbackAt = 0
    local callbackQueued = false
    local api = {}

    makeDraggable(popup, header, function() userMoved = true end)

    local function color() return hslToColor(h, 1, l) end
    local function rgbToHex(c)
        return string.format("#%02X%02X%02X",
            math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5))
    end

    local function render()
        local c = color()
        swatch.BackgroundColor3 = c
        preview.BackgroundColor3 = c

        local pureHue = hslToColor(h, 1, 0.5)
        lightGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(0, 0, 0)),
            ColorSequenceKeypoint.new(0.5, pureHue),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 255, 255)),
        })
        hueCursor.Position    = UDim2.new(h, 0, 0.5, 0)
        lightCursor.Position  = UDim2.new(l, 0, 0.5, 0)
        if alphaCursor then alphaCursor.Position = UDim2.new(alpha, 0, 0.5, 0) end
        if not hex:IsFocused() then hex.Text = rgbToHex(c) end
    end

    local function fireCallbackThrottled()
        local now = os.clock()
        local delayLeft = (1 / 45) - (now - lastCallbackAt)
        if delayLeft <= 0 then
            lastCallbackAt = now
            task.spawn(callback, color(), alpha)
            return
        end
        if callbackQueued then return end
        callbackQueued = true
        task.delay(delayLeft, function()
            callbackQueued = false
            lastCallbackAt = os.clock()
            task.spawn(callback, color(), alpha)
        end)
    end

    function api:Set(c, a, silent)
        if c then h, l = colorToHL(c) end
        if a ~= nil then alpha = clamp(a, 0, 1) end
        render()
        if flag then Library:SetFlag(flag, color()) end
        if not silent then fireCallbackThrottled() end
    end
    function api:Get() return color(), alpha end

    function api:UpdatePosition()
        if not popup.Visible then return end
        if userMoved then return end
        local absPos  = swatch.AbsolutePosition
        local absSize = swatch.AbsoluteSize
        local sg      = getScreenGui()
        local screenW = sg.AbsoluteSize.X
        local screenH = sg.AbsoluteSize.Y
        local pSize   = popup.AbsoluteSize
        local px = absPos.X + absSize.X - pSize.X
        local py = absPos.Y + absSize.Y + 8
        px = clamp(px, 8, math.max(8, screenW - pSize.X - 8))
        if py + pSize.Y > screenH - 8 then
            py = absPos.Y - pSize.Y - 8
        end
        popup.Position = UDim2.fromOffset(px, py)
    end

    function api:Open()
        if Library._activeColorpicker and Library._activeColorpicker ~= api then
            Library._activeColorpicker:Close()
        end
        Library._activeColorpicker = api
        popup.Visible = true
        userMoved = false
        api:UpdatePosition()
        tween(swStroke, 0.14, { Color = Theme.Accent })
    end
    function api:Close()
        popup.Visible = false
        tween(swStroke, 0.14, { Color = Theme.BorderHi })
        if Library._activeColorpicker == api then Library._activeColorpicker = nil end
    end

    swatch.MouseButton1Click:Connect(function()
        if popup.Visible then api:Close() else api:Open() end
    end)
    closeBtn.MouseButton1Click:Connect(function() api:Close() end)

    local function makeStripDrag(strip, onPct)
        local dragging = false
        local function update(input)
            local p  = strip.AbsolutePosition
            local sz = strip.AbsoluteSize
            local x = clamp(input.Position.X - p.X, 0, sz.X)
            local pct = (sz.X > 0) and x / sz.X or 0
            onPct(pct)
        end
        strip.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                update(input)
            end
        end)
        register(UIS.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
                update(input)
            end
        end))
        register(UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end))
    end

    makeStripDrag(hueBar,   function(pct) h = pct;        api:Set(nil) end)
    makeStripDrag(lightBar, function(pct) l = pct;        api:Set(nil) end)
    if hasAlpha then
        makeStripDrag(alphaBar, function(pct) alpha = pct; api:Set(nil, alpha) end)
    end

    hex.Focused:Connect(function() tween(hexStroke, 0.14, { Color = Theme.Accent }) end)
    hex.FocusLost:Connect(function()
        tween(hexStroke, 0.14, { Color = Theme.Border })
        local txt = hex.Text:gsub("#", ""):gsub("%s", "")
        if #txt == 6 then
            local r = tonumber(txt:sub(1,2), 16)
            local g = tonumber(txt:sub(3,4), 16)
            local b = tonumber(txt:sub(5,6), 16)
            if r and g and b then
                api:Set(Color3.fromRGB(r, g, b))
                return
            end
        end
        render()
    end)

    api.Button = swatch
    api.Popup  = popup
    if flag then Library:BindFlag(flag, api) end
    api:Set(default, 1, true)
    return Library:_attachElementExtras(api, opts, "colorpicker")
end

local NOTIFY_W   = 300
local NOTIFY_MAX = 4
Library._notifications = {}

local function getNotifyHolder()
    local sg = getScreenGui()
    if Library.NotifyHolder and Library.NotifyHolder.Parent then return Library.NotifyHolder end
    local holder = new("Frame", {
        Parent                 = sg,
        Name                   = "Notifications",
        AnchorPoint            = Vector2.new(1, 0),
        Position               = UDim2.new(1, -14, 0, 14),
        Size                   = UDim2.fromOffset(NOTIFY_W, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex                 = 5000,
    })
    listLayout(holder, Enum.FillDirection.Vertical, 6,
        Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top)
    Library.NotifyHolder = holder
    return holder
end

function Library:Notify(opts)
    opts = opts or {}
    local title    = tostring(opts.Title or "Notification")
    local text     = tostring(opts.Text or "")
    local duration = tonumber(opts.Duration) or 3.5
    local nType    = (opts.Type or "info"):lower()
    local iconName = opts.Icon
    local onClick  = opts.Callback

    local typeColors = {
        info    = Theme.Accent,
        success = Color3.fromRGB(48, 185, 120),
        warning = Color3.fromRGB(245, 166, 35),
        error   = Color3.fromRGB(235, 65, 55),
    }
    local barColor = typeColors[nType] or Theme.Accent

    local holder = getNotifyHolder()

    local slot = new("Frame", {
        Parent                 = holder,
        Name                   = "Slot",
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ClipsDescendants       = true,
        ZIndex                 = 5001,
    })

    local card = new("Frame", {
        Parent           = slot,
        AnchorPoint      = Vector2.new(0, 0),
        Position         = UDim2.fromOffset(0, 0),
        Size             = UDim2.new(1, 0, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Bg2,
        BorderSizePixel  = 0,
        ZIndex           = 5001,
        ClipsDescendants = true,
    })
    corner(card, R_LG)
    stroke(card, Theme.BorderHi, 1)
    new("ImageLabel", {
        Parent                 = card,
        Name                   = "Shadow",
        ZIndex                 = 5000,
        Size                   = UDim2.new(1, 30, 1, 30),
        Position               = UDim2.fromOffset(-15, -10),
        BackgroundTransparency = 1,
        Image                  = "rbxasset://textures/ui/Controls/DropShadow.png",
        ImageColor3            = Theme.Shadow,
        ImageTransparency      = 0.9,
        ScaleType              = Enum.ScaleType.Slice,
        SliceCenter            = Rect.new(12, 12, 244, 244),
    })

    local accentBubble = new("Frame", {
        Parent           = card,
        Name             = "AccentBubble",
        Size             = UDim2.fromOffset(28, 28),
        Position         = UDim2.fromOffset(10, 10),
        BackgroundColor3 = barColor,
        BackgroundTransparency = 0.84,
        BorderSizePixel  = 0,
        ZIndex           = 5003,
    })
    corner(accentBubble, R_PILL)

    local contentPadLeft = 48

    local hasIcon = iconName and type(iconName) == "string"
    local iconImage, iconOffset, iconSize
    if hasIcon then
        iconImage, iconOffset, iconSize = getIcon(iconName)
        hasIcon = iconImage ~= nil
    end

    if hasIcon then
        new("ImageLabel", {
            Parent              = accentBubble,
            BackgroundTransparency = 1,
            AnchorPoint         = Vector2.new(0.5, 0.5),
            Position            = UDim2.fromScale(0.5, 0.5),
            Size                = UDim2.fromOffset(16, 16),
            Image               = iconImage,
            ImageRectOffset     = iconOffset,
            ImageRectSize       = iconSize,
            ImageColor3         = barColor,
            ScaleType           = Enum.ScaleType.Fit,
            ZIndex              = 5004,
        })
    else
        local dot = new("Frame", {
            Parent           = accentBubble,
            AnchorPoint      = Vector2.new(0.5, 0.5),
            Position         = UDim2.fromScale(0.5, 0.5),
            Size             = UDim2.fromOffset(8, 8),
            BackgroundColor3 = barColor,
            BorderSizePixel  = 0,
            ZIndex           = 5004,
        })
        corner(dot, R_PILL)
    end

    local content = new("Frame", {
        Parent                 = card,
        Name                   = "Content",
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex                 = 5002,
    })
    pad(content, contentPadLeft, 10, 12, 12)
    listLayout(content, Enum.FillDirection.Vertical, 2)

    local dismissBtn = new("TextButton", {
        Parent                 = card,
        Size                   = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text                   = "",
        ZIndex                 = 5004,
    })

    new("TextLabel", {
        Parent                 = content,
        Size                   = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Font                   = FONT_SB,
        TextSize               = TEXT_MD,
        TextColor3             = Theme.Text,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Text                   = title,
        ZIndex                 = 5002,
    })
    if text ~= "" then
        new("TextLabel", {
            Parent                 = content,
            Size                   = UDim2.new(1, 0, 0, 0),
            AutomaticSize          = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Font                   = FONT,
            TextSize               = TEXT_SM,
            TextColor3             = Theme.SubText,
            TextXAlignment         = Enum.TextXAlignment.Left,
            TextYAlignment         = Enum.TextYAlignment.Top,
            TextWrapped            = true,
            Text                   = text,
            ZIndex                 = 5002,
        })
    end

    local bar = new("Frame", {
        Parent           = card,
        Name             = "Progress",
        AnchorPoint      = Vector2.new(0, 1),
        Position         = UDim2.new(0, 0, 1, 0),
        Size             = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = barColor,
        BackgroundTransparency = 0.1,
        BorderSizePixel  = 0,
        ZIndex           = 5002,
    })

    local function tweenTrans(t, dur, style, dir)
        style = style or Enum.EasingStyle.Quad
        dir   = dir   or Enum.EasingDirection.Out
        tween(card, dur, { BackgroundTransparency = t }, style, dir)
        for _, d in ipairs(card:GetDescendants()) do
            if d:IsA("TextLabel") then
                tween(d, dur, { TextTransparency = t }, style, dir)
            elseif d:IsA("UIStroke") then
                tween(d, dur, { Transparency = t }, style, dir)
            elseif d:IsA("Frame") and d.Name ~= "Content" then
                local base = d.Name == "AccentBubble" and 0.84 or (d.Name == "Progress" and 0.1 or 0)
                tween(d, dur, { BackgroundTransparency = math.min(1, base + t) }, style, dir)
            elseif d:IsA("ImageLabel") then
                local base = d.Name == "Shadow" and 0.9 or 0
                tween(d, dur, { ImageTransparency = math.min(1, base + t) }, style, dir)
            end
        end
    end
    local function setTrans(t)
        card.BackgroundTransparency = t
        for _, d in ipairs(card:GetDescendants()) do
            if d:IsA("TextLabel") then
                d.TextTransparency = t
            elseif d:IsA("UIStroke") then
                d.Transparency = t
            elseif d:IsA("Frame") and d.Name ~= "Content" then
                local base = d.Name == "AccentBubble" and 0.84 or (d.Name == "Progress" and 0.1 or 0)
                d.BackgroundTransparency = math.min(1, base + t)
            elseif d:IsA("ImageLabel") then
                local base = d.Name == "Shadow" and 0.9 or 0
                d.ImageTransparency = math.min(1, base + t)
            end
        end
    end

    local entry = { Card = card, Slot = slot, Closed = false }

    dismissBtn.MouseButton1Click:Connect(function()
        if onClick then task.spawn(onClick) end
        entry:Close()
    end)

    function entry:Close(fast)
        if self.Closed then return end
        self.Closed = true

        for i, e in ipairs(Library._notifications) do
            if e == self then table.remove(Library._notifications, i) break end
        end

        local dur = fast and 0.22 or 0.3

        local h = slot.AbsoluteSize.Y
        if h > 0 then
            slot.AutomaticSize = Enum.AutomaticSize.None
            slot.Size          = UDim2.new(1, 0, 0, h)
            tween(slot, dur, { Size = UDim2.new(1, 0, 0, 0) },
                Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
        end

        tween(card, dur * 0.9, { Position = UDim2.fromOffset(60, 0) },
            Enum.EasingStyle.Quart, Enum.EasingDirection.In)

        tweenTrans(1, dur * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

        task.delay(dur + 0.02, function()
            if slot and slot.Parent then slot:Destroy() end
        end)
    end

    setTrans(1)
    card.Position = UDim2.fromOffset(40, 0)
    tween(card, 0.32, { Position = UDim2.fromOffset(0, 0) },
        Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    tweenTrans(0, 0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    tween(bar, duration, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)

    table.insert(Library._notifications, entry)

    while #Library._notifications > NOTIFY_MAX do
        local oldest = Library._notifications[1]
        if oldest and not oldest.Closed then
            oldest:Close(true)
        else

            table.remove(Library._notifications, 1)
        end
    end

    task.delay(duration, function() entry:Close(false) end)
    return card
end

function Library:CreateKeySystem(cfg)
    cfg = cfg or {}
    local title    = cfg.Title or self.Name
    local subtitle = cfg.Subtitle or "Enter your key"
    local note     = cfg.Note or ""
    local keys     = cfg.Keys or {}
    local saveKey  = cfg.SaveKey or false
    local keyFile  = cfg.KeyFile or (self._configFolder .. "/key.txt")

    if saveKey and isfile and isfile(keyFile) then
        local saved = readfile(keyFile)
        for _, k in ipairs(keys) do
            if saved == k then return true end
        end
    end

    local T = self.Theme
    local sg = getScreenGui()

    local overlay = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = T.Shadow,
        BackgroundTransparency = 0.35,
        ZIndex = 9999,
        Parent = sg,
    })

    local card = new("Frame", {
        Size = UDim2.fromOffset(340, 230),
        Position = UDim2.new(0.5, -170, 0.5, -115),
        BackgroundColor3 = T.Bg,
        ZIndex = 10000,
        Parent = overlay,
    })
    new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = card })
    new("UIStroke", { Color = T.Border, Thickness = 1, Parent = card })

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 36),
        Position = UDim2.fromOffset(0, 18),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        ZIndex = 10001,
        Parent = card,
    })

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.fromOffset(0, 54),
        BackgroundTransparency = 1,
        Text = subtitle,
        TextColor3 = T.SubText,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        ZIndex = 10001,
        Parent = card,
    })

    local box = new("TextBox", {
        Size = UDim2.new(1, -40, 0, 36),
        Position = UDim2.fromOffset(20, 88),
        BackgroundColor3 = T.Bg2,
        PlaceholderText = "Key...",
        Text = "",
        TextColor3 = T.Text,
        PlaceholderColor3 = T.DimText,
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        ClearTextOnFocus = false,
        ZIndex = 10001,
        Parent = card,
    })
    new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = box })

    local btn = new("TextButton", {
        Size = UDim2.new(1, -40, 0, 36),
        Position = UDim2.fromOffset(20, 138),
        BackgroundColor3 = T.Accent,
        Text = "Submit",
        TextColor3 = T.AccentText,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        ZIndex = 10001,
        Parent = card,
    })
    new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = btn })

    if note ~= "" then
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18),
            Position = UDim2.fromOffset(0, 184),
            BackgroundTransparency = 1,
            Text = note,
            TextColor3 = T.DimText,
            Font = Enum.Font.Gotham,
            TextSize = 11,
            ZIndex = 10001,
            Parent = card,
        })
    end

    local passed = false
    btn.MouseButton1Click:Connect(function()
        local input = box.Text
        for _, k in ipairs(keys) do
            if input == k then
                passed = true
                if saveKey and writefile then writefile(keyFile, input) end
                overlay:Destroy()
                return
            end
        end
        box.Text = ""
        box.PlaceholderText = "Invalid key"
        box.PlaceholderColor3 = Color3.fromRGB(220, 60, 60)
    end)

    repeat task.wait() until passed
    return true
end

local EASE_OUT = Enum.EasingStyle.Quint
local EASE_BACK = Enum.EasingStyle.Back

function Tab:CreateSubTabs(opts)
    opts = opts or {}
    local align = opts.Align or "Stretch"

    local wrapper = new("Frame", {
        Parent                 = self.Page,
        Name                   = "SubTabs",
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    listLayout(wrapper, Enum.FillDirection.Vertical, 10)

    local bar = new("Frame", {
        Parent           = wrapper,
        Name             = "Bar",
        Size             = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.Bg2,
    })
    bindTheme(bar, "BackgroundColor3", "Bg2")
    corner(bar, R_MD)
    stroke(bar, Theme.Border, 1)
    pad(bar, 4, 4, 4, 4)

    local barLayout = listLayout(bar, Enum.FillDirection.Horizontal, 4,
        align == "Left" and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center)
    barLayout.VerticalAlignment = Enum.VerticalAlignment.Center

    local indicator = new("Frame", {
        Parent           = bar,
        Name             = "Indicator",
        BackgroundColor3 = Theme.Accent,
        Size             = UDim2.new(0, 0, 1, 0),
        Position         = UDim2.new(0, 0, 0, 0),
        ZIndex           = 1,
        Visible          = false,
    })
    bindTheme(indicator, "BackgroundColor3", "Accent")
    corner(indicator, R_SM)

    local holder = new("Frame", {
        Parent                 = wrapper,
        Name                   = "Holder",
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })

    local sub = { Tabs = {}, Active = nil, Bar = bar, Holder = holder, Wrapper = wrapper }

    function sub:_moveIndicator(btn, animate)
        if not btn then return end
        local relX = btn.AbsolutePosition.X - bar.AbsolutePosition.X
        local goalPos  = UDim2.new(0, relX, 0, 0)
        local goalSize = UDim2.new(0, btn.AbsoluteSize.X, 1, 0)
        indicator.Visible = true
        if animate == false then
            indicator.Position = goalPos
            indicator.Size     = goalSize
        else
            tween(indicator, 0.32, { Position = goalPos, Size = goalSize }, EASE_OUT)
        end
    end

    function sub:Select(target, animate)
        if self.Active == target then return end
        for _, t in ipairs(self.Tabs) do
            local on = (t == target)
            if on then
                t.Page.Visible = true
                t.Label.TextColor3 = Theme.AccentText
                t.Page.Position = UDim2.new(0, 0, 0, 8)
                t.Page.BackgroundTransparency = 1
                tween(t.Page, 0.28, { Position = UDim2.new(0, 0, 0, 0) }, EASE_OUT)
                self:_moveIndicator(t.Button, animate)
            else
                t.Page.Visible = false
                t.Label.TextColor3 = Theme.SubText
            end
        end
        self.Active = target
    end

    function sub:CreateTab(name, icon)
        name = tostring(name or "Sub")

        local btn = new("TextButton", {
            Parent                 = bar,
            Name                   = name,
            AutoButtonColor        = false,
            BackgroundTransparency = 1,
            Text                   = "",
            Size                   = UDim2.new(0, 0, 1, 0),
            AutomaticSize          = Enum.AutomaticSize.X,
            ZIndex                 = 2,
        })
        local label = new("TextLabel", {
            Parent                 = btn,
            BackgroundTransparency = 1,
            Size                   = UDim2.new(1, 0, 1, 0),
            Font                   = FONT_SB,
            TextSize               = TEXT_SM,
            Text                   = "   " .. name .. "   ",
            TextColor3             = Theme.SubText,
            ZIndex                 = 3,
        })

        local page = new("Frame", {
            Parent                 = holder,
            Name                   = name .. "_Page",
            Size                   = UDim2.new(1, 0, 0, 0),
            AutomaticSize          = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Visible                = false,
        })
        listLayout(page, Enum.FillDirection.Vertical, 12)

        local subtab = setmetatable({
            Window   = self.Window or (Tab.Window),
            Name     = name,
            Page     = page,
            Sections = {},
        }, Tab)
        subtab.Window = self.Window

        local entry = { Button = btn, Label = label, Page = page, Tab = subtab }
        table.insert(self.Tabs, entry)

        btn.MouseEnter:Connect(function()
            if self.Active ~= entry then tween(label, 0.14, { TextColor3 = Theme.Text }) end
        end)
        btn.MouseLeave:Connect(function()
            if self.Active ~= entry then tween(label, 0.14, { TextColor3 = Theme.SubText }) end
        end)
        btn.MouseButton1Click:Connect(function() self:Select(entry, true) end)

        if #self.Tabs == 1 then
            task.defer(function() self:Select(entry, false) end)
        end
        return subtab
    end

    bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if sub.Active then sub:_moveIndicator(sub.Active.Button, false) end
    end)

    sub.Window = self.Window
    return sub
end

function Section:AddProgressBar(opts)
    opts = opts or {}
    local value = math.clamp(tonumber(opts.Value) or 0, 0, 1)

    local frame = new("Frame", {
        Parent                 = self.Content,
        Size                   = UDim2.new(1, 0, 0, 44),
        BackgroundTransparency = 1,
    })
    new("TextLabel", {
        Parent                 = frame,
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, 0, 0, 0),
        Size                   = UDim2.new(1, 0, 0, 18),
        Font                   = FONT_M,
        TextSize               = TEXT_SM,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Text                   = opts.Text or "Progress",
        TextColor3             = Theme.Text,
    })
    local track = new("Frame", {
        Parent           = frame,
        Position         = UDim2.new(0, 0, 0, 26),
        Size             = UDim2.new(1, 0, 0, 10),
        BackgroundColor3 = Theme.Track,
    })
    bindTheme(track, "BackgroundColor3", "Track")
    corner(track, R_SM)
    local fill = new("Frame", {
        Parent           = track,
        Size             = UDim2.new(value, 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
    })
    bindTheme(fill, "BackgroundColor3", "Accent")
    corner(fill, R_SM)

    local api = {}
    function api:Set(v, animate)
        v = math.clamp(tonumber(v) or 0, 0, 1)
        if animate == false then
            fill.Size = UDim2.new(v, 0, 1, 0)
        else
            tween(fill, 0.3, { Size = UDim2.new(v, 0, 1, 0) }, EASE_OUT)
        end
    end
    return api
end

function Section:AddImage(opts)
    opts = opts or {}
    local holder = new("Frame", {
        Parent                 = self.Content,
        Size                   = UDim2.new(1, 0, 0, opts.Height or 120),
        BackgroundColor3       = Theme.Bg2,
    })
    bindTheme(holder, "BackgroundColor3", "Bg2")
    corner(holder, R_MD)
    stroke(holder, Theme.Border, 1)
    local img = new("ImageLabel", {
        Parent                 = holder,
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, -8, 1, -8),
        Position               = UDim2.new(0, 4, 0, 4),
        Image                  = opts.Image or "",
        ScaleType              = opts.ScaleType or Enum.ScaleType.Fit,
        ImageTransparency      = 1,
    })
    corner(img, R_SM)
    tween(img, 0.35, { ImageTransparency = 0 })
    local api = {}
    function api:Set(id) img.Image = id end
    return api
end

function Section:AddButtonGroup(opts)
    opts = opts or {}
    local options  = opts.Options or {}
    local callback = opts.Callback or function() end

    local frame = new("Frame", {
        Parent           = self.Content,
        Size             = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.Bg2,
    })
    bindTheme(frame, "BackgroundColor3", "Bg2")
    corner(frame, R_MD)
    stroke(frame, Theme.Border, 1)
    pad(frame, 3, 3, 3, 3)
    local lay = listLayout(frame, Enum.FillDirection.Horizontal, 3)
    lay.VerticalAlignment = Enum.VerticalAlignment.Center
    lay.HorizontalFlex = Enum.UIFlexAlignment.Fill

    local current
    local buttons = {}
    local function refresh(sel)
        current = sel
        for opt, b in pairs(buttons) do
            local on = (opt == sel)
            tween(b.bg, 0.18, { BackgroundTransparency = on and 0 or 1 })
            tween(b.lbl, 0.18, { TextColor3 = on and Theme.AccentText or Theme.SubText })
        end
    end

    for _, opt in ipairs(options) do
        local b = new("TextButton", {
            Parent                 = frame,
            AutoButtonColor        = false,
            BackgroundTransparency = 1,
            Text                   = "",
            Size                   = UDim2.new(0, 60, 1, 0),
        })
        local flex = Instance.new("UIFlexItem"); flex.FlexMode = Enum.UIFlexMode.Fill; flex.Parent = b
        local bg = new("Frame", {
            Parent                 = b,
            Size                   = UDim2.new(1, 0, 1, 0),
            BackgroundColor3       = Theme.Accent,
            BackgroundTransparency = 1,
        })
        bindTheme(bg, "BackgroundColor3", "Accent")
        corner(bg, R_SM)
        local lbl = new("TextLabel", {
            Parent                 = b,
            BackgroundTransparency = 1,
            Size                   = UDim2.new(1, 0, 1, 0),
            Font                   = FONT_SB,
            TextSize               = TEXT_SM,
            Text                   = tostring(opt),
            TextColor3             = Theme.SubText,
            ZIndex                 = 2,
        })
        buttons[opt] = { bg = bg, lbl = lbl }
        b.MouseButton1Click:Connect(function()
            refresh(opt)
            callback(opt)
        end)
    end

    if opts.Default and buttons[opts.Default] then
        refresh(opts.Default)
    elseif options[1] then
        refresh(options[1])
    end

    local api = {}
    function api:Get() return current end
    function api:Set(v) if buttons[v] then refresh(v); callback(v) end end
    return api
end

function Section:AddStepper(opts)
    opts = opts or {}
    local min  = opts.Min or 0
    local max  = opts.Max or 100
    local step = opts.Step or 1
    local val  = math.clamp(opts.Default or min, min, max)
    local callback = opts.Callback or function() end

    local frame = new("Frame", {
        Parent                 = self.Content,
        Size                   = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
    })
    new("TextLabel", {
        Parent                 = frame,
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, -120, 1, 0),
        Font                   = FONT_M,
        TextSize               = TEXT_SM,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Text                   = opts.Text or "Value",
        TextColor3             = Theme.Text,
    })

    local function makeBtn(sym, xoff)
        local b = new("TextButton", {
            Parent           = frame,
            AnchorPoint      = Vector2.new(1, 0.5),
            Position         = UDim2.new(1, xoff, 0.5, 0),
            Size             = UDim2.new(0, 30, 0, 28),
            BackgroundColor3 = Theme.Bg2,
            AutoButtonColor  = false,
            Font             = FONT_B,
            TextSize         = TEXT_MD,
            Text             = sym,
            TextColor3       = Theme.Text,
        })
        bindTheme(b, "BackgroundColor3", "Bg2")
        corner(b, R_SM); stroke(b, Theme.Border, 1)
        b.MouseEnter:Connect(function() tween(b, 0.14, { BackgroundColor3 = Theme.Hover }) end)
        b.MouseLeave:Connect(function() tween(b, 0.14, { BackgroundColor3 = Theme.Bg2 }) end)
        return b
    end
    local plus  = makeBtn("+", 0)
    local disp  = new("TextLabel", {
        Parent                 = frame,
        AnchorPoint            = Vector2.new(1, 0.5),
        Position               = UDim2.new(1, -38, 0.5, 0),
        Size                   = UDim2.new(0, 44, 0, 28),
        BackgroundTransparency = 1,
        Font                   = FONT_SB,
        TextSize               = TEXT_SM,
        Text                   = tostring(val),
        TextColor3             = Theme.Text,
    })
    local minus = makeBtn("-", -82)

    local function set(v)
        val = math.clamp(v, min, max)
        disp.Text = tostring(val)
        callback(val)
    end
    plus.MouseButton1Click:Connect(function() set(val + step) end)
    minus.MouseButton1Click:Connect(function() set(val - step) end)

    local api = {}
    function api:Get() return val end
    function api:Set(v) set(v) end
    return api
end

return Library
