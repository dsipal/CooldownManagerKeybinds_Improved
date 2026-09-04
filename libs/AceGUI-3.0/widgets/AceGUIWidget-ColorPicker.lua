--[[-----------------------------------------------------------------------------
ColorPicker Widget
-------------------------------------------------------------------------------]]
local Type, Version = "ColorPicker", 25
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Lua APIs
local pairs = pairs
local type  = type

-- WoW APIs
local CreateFrame, UIParent = CreateFrame, UIParent

--[[-----------------------------------------------------------------------------
Support functions
-------------------------------------------------------------------------------]]
local function SetSwatchColor(tex, r, g, b, a)
    if not tex then return end
    if tex.SetColorRGB then
        tex:SetColorRGB(r, g, b)
    elseif tex.SetColorTexture then
        tex:SetColorTexture(r, g, b, a or 1)
    elseif tex.SetVertexColor then
        tex:SetVertexColor(r, g, b, a or 1)
    end
end

local function GetPickerOpacity()
    if OpacitySliderFrame and OpacitySliderFrame.GetValue then
        return OpacitySliderFrame:GetValue()
    end
    if ColorPickerFrame and ColorPickerFrame.OpacitySlider and ColorPickerFrame.OpacitySlider.GetValue then
        return ColorPickerFrame.OpacitySlider:GetValue()
    end
    if ColorPickerFrame and type(ColorPickerFrame.opacity) == "number" then
        return ColorPickerFrame.opacity
    end
    return nil
end

local function GetCurrentRGBA(widget)
    local r, g, b = 1, 1, 1
    if ColorPickerFrame and ColorPickerFrame.GetColorRGB then
        r, g, b = ColorPickerFrame:GetColorRGB()
    end

    local a = widget.a or 1
    if widget.HasAlpha then
        local o = GetPickerOpacity()
        if o ~= nil then
            a = 1 - o
        end
    else
        a = 1
    end

    return r, g, b, a
end

local function ApplyColor(widget, fireEvent, isAlpha)
    local r, g, b, a = GetCurrentRGBA(widget)
    widget:SetColor(r, g, b, a)
    if fireEvent then
        widget:Fire(fireEvent, r, g, b, a)
    end
    if isAlpha then
        return r, g, b, a
    end
end

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Control_OnEnter(frame)
    frame.obj:Fire("OnEnter")
end

local function Control_OnLeave(frame)
    frame.obj:Fire("OnLeave")
end

local function ColorSwatch_OnClick(frame)
    local widget = frame.obj
    if widget.disabled then
        AceGUI:ClearFocus()
        return
    end

    local r, g, b, a = widget.r or 1, widget.g or 1, widget.b or 1, widget.a or 1
    local prev = { r = r, g = g, b = b, a = a }

    local function swatchChanged()
        local cr, cg, cb, ca = GetCurrentRGBA(widget)
        widget:SetColor(cr, cg, cb, ca)
        widget:Fire("OnValueChanged", cr, cg, cb, ca)
    end

    local function confirmed()
        local cr, cg, cb, ca = GetCurrentRGBA(widget)
        widget:SetColor(cr, cg, cb, ca)
        widget:Fire("OnValueConfirmed", cr, cg, cb, ca)
    end

    local function cancelled()
        widget:SetColor(prev.r, prev.g, prev.b, prev.a)
        widget:Fire("OnValueConfirmed", prev.r, prev.g, prev.b, prev.a)
    end

    -- Modern Mainline API
    if type(SetupColorPickerAndShow) == "function" then
        SetupColorPickerAndShow({
            r = r, g = g, b = b,
            hasOpacity = widget.HasAlpha,
            opacity = widget.HasAlpha and (1 - a) or nil,

            swatchFunc = swatchChanged,
            opacityFunc = swatchChanged,

            okayFunc = confirmed,
            cancelFunc = cancelled,
        })

        AceGUI:ClearFocus()
        return
    end

    -- Legacy fallback
    if ColorPickerFrame and ColorPickerFrame.Hide then
        ColorPickerFrame:Hide()
    end

    if ColorPickerFrame and ColorPickerFrame.SetFrameStrata then
        ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        ColorPickerFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
        ColorPickerFrame:SetClampedToScreen(true)
    end

    ColorPickerFrame.hasOpacity = widget.HasAlpha
    if widget.HasAlpha then
        ColorPickerFrame.opacity = 1 - (a or 1)
    end

    -- Provide both legacy and modern names so Mainline does not explode
    ColorPickerFrame.func = swatchChanged
    ColorPickerFrame.swatchFunc = swatchChanged
    ColorPickerFrame.opacityFunc = swatchChanged

    ColorPickerFrame.cancelFunc = cancelled
    ColorPickerFrame.okayFunc = confirmed

    if ColorPickerFrame.SetColorRGB then
        ColorPickerFrame:SetColorRGB(r, g, b)
    end

    if ColorPickerFrame.Show then
        ColorPickerFrame:Show()
    end

    AceGUI:ClearFocus()
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
    ["OnAcquire"] = function(self)
        self:SetHeight(24)
        self:SetWidth(200)
        self:SetHasAlpha(false)
        self:SetColor(0, 0, 0, 1)
        self:SetDisabled(nil)
        self:SetLabel(nil)
    end,

    ["SetLabel"] = function(self, text)
        self.text:SetText(text)
    end,

    ["SetColor"] = function(self, r, g, b, a)
        self.r = r
        self.g = g
        self.b = b
        self.a = a or 1
        SetSwatchColor(self.colorSwatch, r, g, b, self.a)
    end,

    ["SetHasAlpha"] = function(self, HasAlpha)
        self.HasAlpha = HasAlpha
    end,

    ["SetDisabled"] = function(self, disabled)
        self.disabled = disabled
        if self.disabled then
            self.frame:Disable()
            self.text:SetTextColor(0.5, 0.5, 0.5)
        else
            self.frame:Enable()
            self.text:SetTextColor(1, 1, 1)
        end
    end
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local function Constructor()
    local frame = CreateFrame("Button", nil, UIParent)
    frame:Hide()

    frame:EnableMouse(true)
    frame:SetScript("OnEnter", Control_OnEnter)
    frame:SetScript("OnLeave", Control_OnLeave)
    frame:SetScript("OnClick", ColorSwatch_OnClick)

    local colorSwatch = frame:CreateTexture(nil, "OVERLAY")
    colorSwatch:SetWidth(19)
    colorSwatch:SetHeight(19)
    colorSwatch:SetTexture(130939) -- Interface\\ChatFrame\\ChatFrameColorSwatch
    colorSwatch:SetPoint("LEFT")

    local texture = frame:CreateTexture(nil, "BACKGROUND")
    colorSwatch.background = texture
    texture:SetWidth(16)
    texture:SetHeight(16)
    texture:SetColorTexture(1, 1, 1)
    texture:SetPoint("CENTER", colorSwatch)
    texture:Show()

    local checkers = frame:CreateTexture(nil, "BACKGROUND")
    colorSwatch.checkers = checkers
    checkers:SetWidth(14)
    checkers:SetHeight(14)
    checkers:SetTexture(188523) -- Tileset\\Generic\\Checkers
    checkers:SetTexCoord(.25, 0, 0.5, .25)
    checkers:SetDesaturated(true)
    checkers:SetVertexColor(1, 1, 1, 0.75)
    checkers:SetPoint("CENTER", colorSwatch)
    checkers:Show()

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetHeight(24)
    text:SetJustifyH("LEFT")
    text:SetTextColor(1, 1, 1)
    text:SetPoint("LEFT", colorSwatch, "RIGHT", 2, 0)
    text:SetPoint("RIGHT")

    local widget = {
        colorSwatch = colorSwatch,
        text        = text,
        frame       = frame,
        type        = Type,
    }
    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
