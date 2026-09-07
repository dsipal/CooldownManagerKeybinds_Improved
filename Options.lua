-- CooldownManagerKeybinds - Options (Ace3 dropdowns + standard color picker)
-- Requires: AceConfigRegistry-3.0, AceConfigDialog-3.0, AceGUI-3.0
-- Optional: LibSharedMedia-3.0
-- Note: The options tree is embedded directly into the Blizzard Options > AddOns
-- panel (see CreateBlizzardOptionsPanel) rather than opened as a floating window.

local ADDON_NAME, ns = ...

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
local AceConfigDialog   = LibStub("AceConfigDialog-3.0", true)
local AceGUI            = LibStub("AceGUI-3.0", true)
local LSM               = LibStub("LibSharedMedia-3.0", true)

local APP_NAME = "CMK"
local registered = false
local optionsCategory

local anchorChoices = {
    TOPLEFT     = "Top Left",
    TOP         = "Top",
    TOPRIGHT    = "Top Right",
    LEFT        = "Left",
    CENTER      = "Center",
    RIGHT       = "Right",
    BOTTOMLEFT  = "Bottom Left",
    BOTTOM      = "Bottom",
    BOTTOMRIGHT = "Bottom Right",
}

local outlineChoices = {
    [""]                        = "None",
    ["OUTLINE"]                 = "Outline",
    ["THICKOUTLINE"]            = "Thick Outline",
    ["MONOCHROME"]              = "Monochrome",
    ["MONOCHROME,OUTLINE"]      = "Mono Outline",
    ["MONOCHROME,THICKOUTLINE"] = "Mono Thick",
}

local function IsBCDMLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("BetterCooldownManager")
end

local function IsAyijeCDMLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Ayije_CDM")
end

local function GetViewer(viewerKey)
    if not ns.db or not ns.db.profile then return nil end
    ns.db.profile.viewers = ns.db.profile.viewers or {}
    ns.db.profile.viewers[viewerKey] = ns.db.profile.viewers[viewerKey] or {}
    return ns.db.profile.viewers[viewerKey]
end

local function NotifyChanged()
    if ns.Keybinds and ns.Keybinds.OnSettingChanged then
        ns.Keybinds:OnSettingChanged()
    end
end

-- Cache font list so the dropdown does not churn
local fontValuesCache
local function FontValues()
    if fontValuesCache then return fontValuesCache end

    local t = {}
    if LSM and LSM.List then
        local list = LSM:List("font")
        if list and #list > 0 then
            for _, name in ipairs(list) do
                t[name] = name
            end
        end
    end

    if not next(t) then
        t["Friz Quadrata TT"] = "Friz Quadrata TT"
    end

    fontValuesCache = t
    return t
end

local function DefaultFontSize(viewerKey)
    if viewerKey == "Essential" or viewerKey == "BCDMCustomItemSpellBar" then return 13 end
    return 12
end

-- Assisted Combat suggestions are priority/damage abilities, which Blizzard
-- only ever surfaces through the Essential and Utility viewers, so the rotation
-- controls stay hidden everywhere else (and on clients without the API).
local function RotationCapable(viewerKey)
    if viewerKey ~= "Essential" and viewerKey ~= "Utility" then return false end
    return C_AssistedCombat ~= nil and C_AssistedCombat.GetNextCastSpell ~= nil
end

local function RotationHidden(viewerKey)
    return function() return not RotationCapable(viewerKey) end
end

local function RotationDisabled(viewerKey)
    return function()
        local v = GetViewer(viewerKey)
        return not (v and v.rotationHighlight)
    end
end

local function ViewerGroup(viewerKey, label, order)
    return {
        type  = "group",
        name  = label,
        order = order,
        args  = {
            showKeybinds = {
                type  = "toggle",
                name  = "Show keybinds",
                order = 1,
                get = function()
                    local v = GetViewer(viewerKey)
                    return v and (v.showKeybinds ~= false) or false
                end,
                set = function(_, val)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.showKeybinds = val
                    NotifyChanged()
                end,
            },

            fontName = {
                type   = "select",
                name   = "Font family",
                order  = 2,
                values = FontValues,
                get = function()
                    local v = GetViewer(viewerKey)
                    local current = (v and v.fontName) or "Friz Quadrata TT"
                    local values = FontValues()
                    if values[current] then return current end
                    return "Friz Quadrata TT"
                end,
                set = function(_, val)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.fontName = val
                    NotifyChanged()
                end,
            },

            fontSize = {
                type  = "range",
                name  = "Font size",
                order = 3,
                min   = 8,
                max   = 24,
                step  = 1,
                get = function()
                    local v = GetViewer(viewerKey)
                    return (v and v.fontSize) or DefaultFontSize(viewerKey)
                end,
                set = function(_, val)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.fontSize = val
                    NotifyChanged()
                end,
            },

            fontFlags = {
                type   = "select",
                name   = "Outline",
                order  = 4,
                values = outlineChoices,
                get = function()
                    local v = GetViewer(viewerKey)
                    local f = (v and v.fontFlags) or ""
                    if outlineChoices[f] ~= nil then return f end
                    return ""
                end,
                set = function(_, val)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.fontFlags = val
                    NotifyChanged()
                end,
            },

            color = {
                type     = "color",
                name     = "Font colour",
                order    = 5,
                hasAlpha = true,
                get = function()
                    local v = GetViewer(viewerKey)
                    local c = (v and v.color) or { 1, 1, 1, 1 }
                    return c[1], c[2], c[3], c[4]
                end,
                set = function(_, r, g, b, a)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.color = { r, g, b, a }
                    NotifyChanged()
                end,
            },

            posHeader = {
                type  = "header",
                name  = "Keybind position",
                order = 20,
            },

            anchor = {
                type   = "select",
                name   = "Anchor",
                order  = 21,
                values = anchorChoices,
                get = function()
                    local v = GetViewer(viewerKey)
                    local a = (v and v.anchor) or "TOPRIGHT"
                    if anchorChoices[a] then return a end
                    return "TOPRIGHT"
                end,
                set = function(_, val)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.anchor = val
                    NotifyChanged()
                end,
            },

            offsetX = {
                type  = "range",
                name  = "Offset X",
                order = 22,
                min   = -50,
                max   = 50,
                step  = 1,
                get = function()
                    local v = GetViewer(viewerKey)
                    if not v then return -1 end
                    return (v.offsetX ~= nil) and v.offsetX or -1
                end,
                set = function(_, val)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.offsetX = val
                    NotifyChanged()
                end,
            },

            offsetY = {
                type  = "range",
                name  = "Offset Y",
                order = 23,
                min   = -50,
                max   = 50,
                step  = 1,
                get = function()
                    local v = GetViewer(viewerKey)
                    if not v then return -1 end
                    return (v.offsetY ~= nil) and v.offsetY or -1
                end,
                set = function(_, val)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.offsetY = val
                    NotifyChanged()
                end,
            },

            rotationHeader = {
                type   = "header",
                name   = "Assisted Combat highlight",
                order  = 40,
                hidden = RotationHidden(viewerKey),
            },

            rotationDesc = {
                type   = "description",
                name   = "Animates Blizzard rotation-helper ants on the icon that Assisted Combat currently suggests casting next.",
                order  = 41,
                hidden = RotationHidden(viewerKey),
            },

            rotationHighlight = {
                type   = "toggle",
                name   = "Highlight suggested cast",
                order  = 42,
                hidden = RotationHidden(viewerKey),
                get = function()
                    local v = GetViewer(viewerKey)
                    return (v and v.rotationHighlight) and true or false
                end,
                set = function(_, val)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.rotationHighlight = val
                    NotifyChanged()
                end,
            },

            rotationCombatOnly = {
                type     = "toggle",
                name     = "Only in combat",
                order    = 43,
                hidden   = RotationHidden(viewerKey),
                disabled = RotationDisabled(viewerKey),
                get = function()
                    local v = GetViewer(viewerKey)
                    return (v and v.rotationCombatOnly) and true or false
                end,
                set = function(_, val)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.rotationCombatOnly = val
                    NotifyChanged()
                end,
            },

            rotationColor = {
                type     = "color",
                name     = "Highlight colour",
                order    = 44,
                hasAlpha = true,
                hidden   = RotationHidden(viewerKey),
                disabled = RotationDisabled(viewerKey),
                get = function()
                    local v = GetViewer(viewerKey)
                    local c = (v and v.rotationColor) or { 1, 1, 1, 1 }
                    return c[1], c[2], c[3], c[4]
                end,
                set = function(_, r, g, b, a)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.rotationColor = { r, g, b, a }
                    NotifyChanged()
                end,
            },

            rotationOverhang = {
                type     = "range",
                name     = "Size overhang",
                desc     = "How far the highlight extends past the icon edge, in pixels.",
                order    = 45,
                min      = 0,
                max      = 12,
                step     = 1,
                hidden   = RotationHidden(viewerKey),
                disabled = RotationDisabled(viewerKey),
                get = function()
                    local v = GetViewer(viewerKey)
                    if not v then return 4 end
                    return (v.rotationOverhang ~= nil) and v.rotationOverhang or 4
                end,
                set = function(_, val)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.rotationOverhang = val
                    NotifyChanged()
                end,
            },
        },
    }
end

local function BuildOptionsTable()
    local opts = {
        type = "group",
        name = "CooldownManagerKeybinds",
        args = {
            enabled = {
                type  = "toggle",
                name  = "Enable",
                order = 1,
                get = function()
                    return ns.db and ns.db.profile and ns.db.profile.enabled or false
                end,
                set = function(_, val)
                    if not ns.db or not ns.db.profile then return end
                    ns.db.profile.enabled = val
                    NotifyChanged()
                end,
            },

            essential = ViewerGroup("Essential", "Essential", 10),
            utility   = ViewerGroup("Utility", "Utility", 20),
            buffIcon  = ViewerGroup("BuffIcon", "Buff Icons", 22),
            buffBar   = ViewerGroup("BuffBar", "Buff Bars", 24),

            bcdmInfo = {
                type  = "description",
                name  = "Custom Spells, Custom Items, and Trinket Bar settings are available when BetterCooldownManager is installed and enabled.",
                order = 29,
                hidden = function()
                    return IsBCDMLoaded()
                end,
            },

            customSpells        = ViewerGroup("BCDMCustomSpells",        "Custom Spells",          30),
            customItemSpellBar  = ViewerGroup("BCDMCustomItemSpellBar",  "Custom Item Spell Bar", 35),
            customItems         = ViewerGroup("BCDMCustomItems",         "Custom Items",           40),
            trinkets            = ViewerGroup("BCDMTrinkets",            "Trinket Bar",            50),

            ayijeInfo = {
                type  = "description",
                name  = "Defensives, Trinkets, and Racials settings are available when Ayije_CDM is installed and enabled.",
                order = 59,
                hidden = function()
                    return IsAyijeCDMLoaded()
                end,
            },

            ayijeDefensives = ViewerGroup("Defensives", "Defensives", 60),
            ayijeTrinkets   = ViewerGroup("Trinkets",   "Trinkets",   70),
            ayijeRacials    = ViewerGroup("Racials",    "Racials",    80),
        },
    }

    -- Only show BCDM groups when BetterCooldownManager is loaded
    opts.args.customSpells.hidden = function()
        return not IsBCDMLoaded()
    end
    opts.args.customItemSpellBar.hidden = function()
        return not IsBCDMLoaded()
    end
    opts.args.customItems.hidden = function()
        return not IsBCDMLoaded()
    end
    opts.args.trinkets.hidden = function()
        return not IsBCDMLoaded()
    end

    -- Only show Ayije_CDM groups when Ayije_CDM is loaded
    opts.args.ayijeDefensives.hidden = function()
        return not IsAyijeCDMLoaded()
    end
    opts.args.ayijeTrinkets.hidden = function()
        return not IsAyijeCDMLoaded()
    end
    opts.args.ayijeRacials.hidden = function()
        return not IsAyijeCDMLoaded()
    end

    -- Keep reset at the end
    opts.args.reset = {
        type        = "execute",
        name        = "Reset to defaults",
        order       = 99,
        confirm     = true,
        confirmText = "Reset all CMK settings to defaults?",
        func = function()
            if ns.Keybinds and ns.Keybinds.ResetProfileToDefaults then
                ns.Keybinds:ResetProfileToDefaults()
            end
        end,
    }

    return opts
end

-- Embeds the actual Ace3 options tree into the Blizzard Options > AddOns
-- panel, instead of showing a launcher button that opens a floating window.
--
-- AceConfigDialog:AddToBlizOptions() would normally do this, but it parents
-- its widget to InterfaceOptionsFramePanelContainer and calls
-- InterfaceOptions_AddCategory() -- both part of the legacy Interface Options
-- system that Settings.RegisterCanvasLayoutCategory below has replaced. So we
-- create the same BlizOptionsGroup widget type by hand and hang it off the
-- modern canvas panel instead.
local function CreateBlizzardOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = "CooldownManagerKeybinds (Improved)"

    local widget
    panel:SetScript("OnShow", function(self)
        if not widget then
            widget = AceGUI:Create("BlizOptionsGroup")
            widget.frame:SetParent(self)
            widget.frame:SetAllPoints(self)
            widget:SetTitle(panel.name)
            widget:SetUserData("appName", APP_NAME)

            -- Register into the same table AddToBlizOptions() would have used,
            -- so AceConfigRegistry:NotifyChange(APP_NAME) -- fired by
            -- ns.NotifyOptionsChanged(), see below -- refreshes this embedded
            -- panel automatically while it's visible, not just floating dialogs.
            AceConfigDialog.BlizOptions[APP_NAME] = AceConfigDialog.BlizOptions[APP_NAME] or {}
            AceConfigDialog.BlizOptions[APP_NAME][APP_NAME] = widget
        end

        AceConfigDialog:Open(APP_NAME, widget)
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        optionsCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(optionsCategory)
    end
end

function ns.RegisterOptions()
    if registered then return end

    if not AceConfigRegistry or not AceConfigDialog or not AceGUI then
        print("CMK: Options libraries missing. Check TOC loads AceConfigRegistry-3.0, AceConfigDialog-3.0, and AceGUI-3.0.")
        return
    end

    AceConfigRegistry:RegisterOptionsTable(APP_NAME, BuildOptionsTable())
    CreateBlizzardOptionsPanel()

    registered = true
end

-- Tells an already-open AceConfigDialog to redraw itself. Core.lua calls this
-- from Keybinds:OnSettingChanged() so the panel reflects changes made outside
-- the dialog's own widgets (slash commands, /cmk reset, addons loading late).
function ns.NotifyOptionsChanged()
    if AceConfigRegistry then
        AceConfigRegistry:NotifyChange(APP_NAME)
    end
end

-- Opens Blizzard's Options window straight to the embedded CMK AddOns
-- category (see CreateBlizzardOptionsPanel) instead of a floating dialog.
function ns.OpenOptions()
    if not optionsCategory or not Settings or not Settings.OpenToCategory then
        print("CMK: Options UI not available.")
        return
    end

    local ok, err = pcall(function()
        local id = optionsCategory:GetID()
        -- Blizzard's Settings.OpenToCategory sometimes no-ops on the first
        -- call if the Settings frame hasn't been shown yet this session;
        -- calling it twice is the documented workaround.
        Settings.OpenToCategory(id)
        Settings.OpenToCategory(id)
    end)
    if not ok then
        print("CMK: Options UI failed to open. " .. tostring(err))
    end
end