-- CooldownManagerKeybinds - Core

local ADDON_NAME, ns = ...

-- ------------------------------------------------------------
-- Module + libs
-- ------------------------------------------------------------
local Keybinds = {}
ns.Keybinds = Keybinds

local LSM   = LibStub("LibSharedMedia-3.0", true)
local AceDB = LibStub("AceDB-3.0")

-- ------------------------------------------------------------
-- Defaults
-- ------------------------------------------------------------
local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"


local FALLBACK_DEFAULTS = {
    profile = {
        enabled = true,
        viewers = {
            Essential            = { showKeybinds = true, anchor = "TOPRIGHT", fontSize = 13, offsetX = -1, offsetY = -1, fontName = "Friz Quadrata TT", fontFlags = "OUTLINE", color = { 1, 1, 1, 1 }, rotationHighlight = false, rotationCombatOnly = false, rotationColor = { 1, 1, 1, 1 }, rotationOverhang = 4 },
            Utility              = { showKeybinds = true, anchor = "TOPRIGHT", fontSize = 12, offsetX = -1, offsetY = -1, fontName = "Friz Quadrata TT", fontFlags = "OUTLINE", color = { 1, 1, 1, 1 }, rotationHighlight = false, rotationCombatOnly = false, rotationColor = { 1, 1, 1, 1 }, rotationOverhang = 4 },
            BuffIcon             = { showKeybinds = true, anchor = "TOPRIGHT", fontSize = 12, offsetX = -1, offsetY = -1, fontName = "Friz Quadrata TT", fontFlags = "OUTLINE", color = { 1, 1, 1, 1 } },
            BuffBar              = { showKeybinds = true, anchor = "RIGHT",    fontSize = 12, offsetX = -3, offsetY =  0, fontName = "Friz Quadrata TT", fontFlags = "OUTLINE", color = { 1, 1, 1, 1 } },
            Defensives           = { showKeybinds = true, anchor = "TOPRIGHT", fontSize = 12, offsetX = -1, offsetY = -1, fontName = "Friz Quadrata TT", fontFlags = "OUTLINE", color = { 1, 1, 1, 1 } },
            Trinkets             = { showKeybinds = true, anchor = "TOPRIGHT", fontSize = 12, offsetX = -1, offsetY = -1, fontName = "Friz Quadrata TT", fontFlags = "OUTLINE", color = { 1, 1, 1, 1 } },
            Racials              = { showKeybinds = true, anchor = "TOPRIGHT", fontSize = 12, offsetX = -1, offsetY = -1, fontName = "Friz Quadrata TT", fontFlags = "OUTLINE", color = { 1, 1, 1, 1 } },
            BCDMCustomSpells     = { showKeybinds = true, anchor = "TOPRIGHT", fontSize = 12, offsetX = -1, offsetY = -1, fontName = "Friz Quadrata TT", fontFlags = "OUTLINE", color = { 1, 1, 1, 1 } },
            BCDMCustomItems      = { showKeybinds = true, anchor = "TOPRIGHT", fontSize = 12, offsetX = -1, offsetY = -1, fontName = "Friz Quadrata TT", fontFlags = "OUTLINE", color = { 1, 1, 1, 1 } },
            BCDMTrinkets         = { showKeybinds = true, anchor = "TOPRIGHT", fontSize = 12, offsetX = -1, offsetY = -1, fontName = "Friz Quadrata TT", fontFlags = "OUTLINE", color = { 1, 1, 1, 1 } },
            BCDMCustomItemSpellBar = { showKeybinds = true, anchor = "TOPRIGHT", fontSize = 13, offsetX = -1, offsetY = -1, fontName = "Friz Quadrata TT", fontFlags = "OUTLINE", color = { 1, 1, 1, 1 } },
        },
    },
}

local viewers = {
    -- Blizzard CDM (always present)
    EssentialCooldownViewer          = "Essential",
    UtilityCooldownViewer            = "Utility",
    BuffIconCooldownViewer           = "BuffIcon",
    BuffBarCooldownViewer            = "BuffBar",

    -- BetterCooldownManager (BCDM)
    BCDM_CustomCooldownViewer        = "BCDMCustomSpells",
    BCDM_CustomItemSpellBar          = "BCDMCustomItemSpellBar",
    BCDM_AdditionalCustomCooldownViewer = "BCDMCustomSpells",
    BCDM_CustomItemBar               = "BCDMCustomItems",
    BCDM_TrinketBar                  = "BCDMTrinkets",

    -- Ayije_CDM
    EssentialCooldownViewer_CDM_Container = "Essential",
    UtilityCooldownViewer_CDM_Container   = "Utility",
    CDM_DefensivesContainer               = "Defensives",
    CDM_TrinketsContainer                 = "Trinkets",
    CDM_RacialsContainer                  = "Racials",
}

-- ------------------------------------------------------------
-- State
-- ------------------------------------------------------------
local isEnabled = false
local mappingCache = nil

local viewerChildrenCache = {}
local viewerChildCountCache = {}
local hooked = {}

local scheduledOOC = false
local dirtyOOC = false

local scheduledSeries = false
local seriesDirty = false
local seriesIndex = 1
local seriesDelays = { 0.15, 0.45, 1.00, 2.00 }

local activeAdapterName = nil

-- Trinket warmup retry state
local trinketWarmupRunning = false
local trinketWarmupIndex = 1
local trinketWarmupDelays = { 0.15, 0.35, 0.75, 1.50, 3.00 }

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
local wipe = wipe or table.wipe

local function SafeRegister(frame, event)
    local ok = pcall(frame.RegisterEvent, frame, event)
    return ok
end

-- Secret values (WoW 12.0+): the client hands tainted code black-boxed values
-- for anything combat-sensitive. type() and plain assignment stay legal, but
-- comparing one, doing arithmetic on it, calling a method on it, or using it as
-- a table key all raise a Lua error. Every ID we take from a Blizzard frame has
-- to clear these guards before it reaches a comparison or a map lookup; an ID we
-- cannot inspect is simply one we cannot resolve a keybind for, so we drop it.
local function IsUsableID(v)
    if issecretvalue and issecretvalue(v) then return false end
    return type(v) == "number" and v > 0
end

local function IsUsableString(v)
    if issecretvalue and issecretvalue(v) then return false end
    return type(v) == "string" and v ~= ""
end

local function CanReadTable(t)
    if type(t) ~= "table" then return false end
    if issecrettable and issecrettable(t) then return false end
    if canaccesstable and not canaccesstable(t) then return false end
    return true
end

local function Trim(s)
    if s == nil then return nil end
    if type(s) ~= "string" then
        s = tostring(s)
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function GetFontPath(fontName)
    if not fontName or fontName == "" then return DEFAULT_FONT_PATH end
    if LSM then
        local p = LSM:Fetch("font", fontName)
        if p then return p end
    end
    return DEFAULT_FONT_PATH
end

local function FormatKey(key)
    if not key or key == "" then return "" end
    key = key:upper()

    if key == "-" then
        return "-"
    end

    key = key:gsub("MOUSE%s*WHEEL%s*UP", "MOUSEWHEELUP")
    key = key:gsub("MOUSE%s*WHEEL%s*DOWN", "MOUSEWHEELDOWN")
    key = key:gsub("MOUSE%s*BUTTON", "MOUSEBUTTON")

    key = key:gsub("SHIFT%-", "S")
             :gsub("CTRL%-",  "C")
             :gsub("ALT%-",   "A")

    key = key:gsub("MOUSEWHEELUP", "MU")
             :gsub("MOUSEWHEELDOWN", "MD")

    key = key:gsub("MOUSEBUTTON", "M")
             :gsub("BUTTON", "M")

    key = key:gsub("NUMPADPLUS", "N+")
             :gsub("NUMPADMINUS", "N-")
             :gsub("NUMPADMULTIPLY", "N*")
             :gsub("NUMPADDIVIDE", "N/")
             :gsub("NUMPADDECIMAL", "N.")
             :gsub("NUMPADENTER", "NENT")
             :gsub("NUMPAD", "N")
             :gsub("NUM", "N")

    key = key:gsub("PAGEUP", "PGU")
             :gsub("PAGEDOWN", "PGD")
             :gsub("INSERT", "INS")
             :gsub("DELETE", "DEL")
             :gsub("BACKSPACE", "BS")
             :gsub("SPACEBAR", "Spc")
             :gsub("ENTER", "Ent")
             :gsub("ESCAPE", "Esc")
             :gsub("TAB", "Tab")
             :gsub("CAPSLOCK", "Caps")
             :gsub("HOME", "Hom")
             :gsub("END", "End")

    local endsWithMinus = (key:sub(-1) == "-")
    if endsWithMinus then
        key = key:sub(1, -2) .. "<MINUS>"
    end

    key = key:gsub("%-", "")

    if endsWithMinus then
        key = key:gsub("<MINUS>", "-")
    end

    return key
end

local function IsAnyViewerEnabled()
    if not ns.db or not ns.db.profile or not ns.db.profile.enabled then return false end
    for _, viewerKey in pairs(viewers) do
        local v = ns.db.profile.viewers and ns.db.profile.viewers[viewerKey]
        if v and (v.showKeybinds or v.rotationHighlight) then return true end
    end
    return false
end

local function GetViewerSettings(viewerKey)
    local v = (ns.db and ns.db.profile and ns.db.profile.viewers and ns.db.profile.viewers[viewerKey]) or {}
    return {
        anchor    = v.anchor or "TOPRIGHT",
        fontSize  = v.fontSize or 13,
        offsetX   = (v.offsetX ~= nil) and v.offsetX or -1,
        offsetY   = (v.offsetY ~= nil) and v.offsetY or -1,
        fontName  = v.fontName or "Friz Quadrata TT",
        fontFlags = v.fontFlags or "",
        color     = v.color or { 1, 1, 1, 1 },
    }
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function MappingLooksEmpty(map)
    return not map
        or (not next(map.byID) and not next(map.byName) and not next(map.itemsByID) and not next(map.itemsByName))
end

-- ------------------------------------------------------------
-- Frame safety helpers
-- ------------------------------------------------------------
local function GetAttachFrame(obj)
    if not obj then return nil end
    if obj.IsObjectType and obj:IsObjectType("Frame") then
        return obj
    end
    if obj.GetParent then
        local p = obj:GetParent()
        if p and p.IsObjectType and p:IsObjectType("Frame") then
            return p
        end
    end
    return nil
end

local function CollectFrameDescendants(root, out, seen, depth, maxDepth, maxNodes)
    if not root or not root.GetChildren then return end
    if #out >= maxNodes then return end
    if depth > maxDepth then return end

    local kids = { root:GetChildren() }
    for _, child in ipairs(kids) do
        if #out >= maxNodes then return end

        local f = GetAttachFrame(child)
        if f and not seen[f] then
            seen[f] = true
            out[#out + 1] = f
        end

        CollectFrameDescendants(child, out, seen, depth + 1, maxDepth, maxNodes)
    end
end

-- ------------------------------------------------------------
-- Spell resolution
-- ------------------------------------------------------------
local function GetSpellIDFromName(spellName)
    if not IsUsableString(spellName) then return nil end

    local n = tonumber(spellName)
    if n then
        if C_Spell and C_Spell.DoesSpellExist and C_Spell.DoesSpellExist(n) then
            return n
        end
        return nil
    end

    if C_Spell and C_Spell.GetSpellIDForSpellIdentifier then
        local sid = C_Spell.GetSpellIDForSpellIdentifier(spellName)
        if IsUsableID(sid) then return sid end
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellName)
        if CanReadTable(info) and IsUsableID(info.spellID) then
            return info.spellID
        end
    end

    if GetSpellInfo then
        local sid = select(7, GetSpellInfo(spellName))
        if IsUsableID(sid) then return sid end
    end

    return nil
end

local function GetSpellNameFromID(spellID)
    if not IsUsableID(spellID) then return nil end

    if C_Spell and C_Spell.GetSpellName then
        local n = C_Spell.GetSpellName(spellID)
        if IsUsableString(n) then return n end
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if CanReadTable(info) and IsUsableString(info.name) then return info.name end
    end

    if GetSpellInfo then
        local n = GetSpellInfo(spellID)
        if IsUsableString(n) then return n end
    end

    return nil
end

-- ------------------------------------------------------------
-- Item helpers
-- ------------------------------------------------------------
local function GetItemNameFromID(itemID)
    if not IsUsableID(itemID) then return nil end
    if C_Item and C_Item.GetItemNameByID then
        local n = C_Item.GetItemNameByID(itemID)
        if IsUsableString(n) then return n end
    end
    if GetItemInfo then
        local name = GetItemInfo(itemID)
        if IsUsableString(name) then return name end
    end
    return nil
end

-- ------------------------------------------------------------
-- Macro parsing
-- ------------------------------------------------------------
local function CleanMacroToken(token)
    if token == nil then return nil end
    if type(token) ~= "string" then token = tostring(token) end
    token = token:gsub("%[.-%]%s*", "")
    token = token:gsub("#.*$", "")
    token = token:gsub("!+", "")
    token = Trim(token)
    if token == "" then return nil end
    return token
end

local function StripLeadingBracketBlocks(s)
    s = Trim(s or "")
    while s ~= "" do
        local first = s:match("^(%b[])")
        if not first then break end
        s = Trim(s:sub(#first + 1))
    end
    return s
end

local function ExtractFirstCastSpellToken(body)
    if not body or body == "" then return nil end

    for line in body:gmatch("[^\r\n]+") do
        line = Trim(line or "")
        if line ~= "" then
            local cmd, rest = line:match("^/(%S+)%s+(.+)$")
            if cmd and rest then
                cmd = cmd:lower()

                if cmd == "cast" then
                    rest = StripLeadingBracketBlocks(rest)
                    rest = rest:match("^([^;]+)") or rest
                    rest = CleanMacroToken(rest)
                    if rest then
                        local first = Trim((rest:match("^([^,]+)")) or rest)
                        if first and first ~= "" then return first end
                    end

                elseif cmd == "castsequence" then
                    rest = StripLeadingBracketBlocks(rest)
                    rest = rest:gsub("^reset=[^%s]+%s*", "")
                    rest = rest:match("^([^;]+)") or rest
                    rest = CleanMacroToken(rest)
                    if rest then
                        local first = Trim((rest:match("^([^,]+)")) or rest)
                        if first and first ~= "" then return first end
                    end
                end
            end
        end
    end

    return nil
end

local function GetMacroBodySafe(macroIndex)
    if not IsUsableID(macroIndex) then return nil end

    if GetMacroInfo then
        local _, _, body = GetMacroInfo(macroIndex)
        if body and body ~= "" then return body end
    end

    if GetMacroBody then
        local body = GetMacroBody(macroIndex)
        if body and body ~= "" then return body end
    end

    return nil
end

local function ExtractUseTokensFromBody(body)
    if not body or body == "" then return nil end
    local found = {}

    for line in body:gmatch("[^\r\n]+") do
        line = Trim(line)
        if line and line ~= "" then
            local cmd, rest = line:match("^/(%S+)%s+(.+)$")
            if cmd and rest then
                cmd = cmd:lower()
                if cmd == "use" or cmd == "item" then
                    for segment in rest:gmatch("([^;]+)") do
                        local token = CleanMacroToken(segment)
                        if token then
                            for part in token:gmatch("([^,]+)") do
                                local t = CleanMacroToken(part)
                                if t then
                                    found[t:lower()] = t
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local out
    for _, original in pairs(found) do
        out = out or {}
        out[#out + 1] = original
    end
    return out
end

local function ExtractShowtooltipSpellName(body)
    if not body or body == "" then return nil end
    for line in body:gmatch("[^\r\n]+") do
        line = Trim(line or "")
        local lower = line:lower()
        if lower:find("#showtooltip", 1, true) then
            local rest = line:match("^#showtooltip%s*(.+)$")
            rest = Trim(rest or "")
            if rest ~= "" then
                rest = CleanMacroToken(rest)
                if rest and rest ~= "" then
                    return rest
                end
            end
            return nil
        end
    end
    return nil
end

local function ResolveMacroSpellID(macroIndex, body)
    if not IsUsableID(macroIndex) then return nil end

    if GetMacroSpell then
        local v = GetMacroSpell(macroIndex)
        if IsUsableID(v) then
            return v
        end
        if type(v) == "string" then
            local n = Trim(v)
            if n ~= "" then
                return GetSpellIDFromName(n)
            end
        end
    end

    local st = ExtractShowtooltipSpellName(body)
    if st then
        local sid = GetSpellIDFromName(st)
        if sid then return sid end
    end

    local castToken = ExtractFirstCastSpellToken(body)
    if castToken then
        local sid = GetSpellIDFromName(castToken)
        if sid then return sid end
    end

    return nil
end

-- ------------------------------------------------------------
-- Action button key extraction
-- ------------------------------------------------------------
local function TryGetKeyFromButton(button)
    if not button then return nil end

    if button.config and button.config.keyBoundTarget then
        local k = GetBindingKey(button.config.keyBoundTarget)
        if IsUsableString(k) then return k end
    end

    if button.commandName then
        local k = GetBindingKey(button.commandName)
        if IsUsableString(k) then return k end
    end

    local name = button.GetName and button:GetName()
    if IsUsableString(name) and GetBindingKey then
        local k = GetBindingKey("CLICK " .. name .. ":LeftButton")
        if IsUsableString(k) then return k end
        k = GetBindingKey("CLICK " .. name .. ":RightButton")
        if IsUsableString(k) then return k end
    end

    if button.HotKey and button.HotKey.GetText then
        local t = button.HotKey:GetText()
        if IsUsableString(t) and t ~= "●" then
            return t
        end
    end

    return nil
end

local function GetDirectFormattedKey(icon)
    icon = GetAttachFrame(icon)
    if not icon then return "" end

    local raw = TryGetKeyFromButton(icon)
    if (not raw or raw == "" or raw == "●") and icon.GetParent then
        raw = TryGetKeyFromButton(icon:GetParent())
    end

    if raw and raw ~= "" and raw ~= "●" then
        return FormatKey(raw)
    end

    return ""
end

-- ------------------------------------------------------------
-- Mapping storage
-- ------------------------------------------------------------
local function AddSpellNameKey(nameToKey, spellName, fmtKey)
    if not spellName or spellName == "" then return end
    if not fmtKey or fmtKey == "" then return end
    local k = spellName:lower()
    if nameToKey[k] then return end
    nameToKey[k] = fmtKey
end

local function AddSpellKey(map, spellID, fmtKey)
    if not map or not map.byID or not map.byName then return end
    if not IsUsableID(spellID) then return end
    if not fmtKey or fmtKey == "" then return end
    if map.byID[spellID] then return end

    map.byID[spellID] = fmtKey

    local name = GetSpellNameFromID(spellID)
    if name then
        AddSpellNameKey(map.byName, name, fmtKey)
    end

    if C_Spell and C_Spell.GetOverrideSpell then
        local overrideID = C_Spell.GetOverrideSpell(spellID)
        if IsUsableID(overrideID) and not map.byID[overrideID] then
            map.byID[overrideID] = fmtKey
            local oname = GetSpellNameFromID(overrideID)
            if oname then AddSpellNameKey(map.byName, oname, fmtKey) end
        end
    end

    if C_Spell and C_Spell.GetBaseSpell then
        local baseID = C_Spell.GetBaseSpell(spellID)
        if IsUsableID(baseID) and not map.byID[baseID] then
            map.byID[baseID] = fmtKey
            local bname = GetSpellNameFromID(baseID)
            if bname then AddSpellNameKey(map.byName, bname, fmtKey) end
        end
    end
end

-- Macro wins when it resolves to a spell, to avoid wrong keybinds on conditional macros
local function SetSpellKey(map, spellID, fmtKey)
    if not map or not map.byID or not map.byName then return end
    if not IsUsableID(spellID) then return end
    if not fmtKey or fmtKey == "" then return end

    map.byID[spellID] = fmtKey

    local name = GetSpellNameFromID(spellID)
    if name then
        map.byName[name:lower()] = fmtKey
    end

    if C_Spell and C_Spell.GetOverrideSpell then
        local overrideID = C_Spell.GetOverrideSpell(spellID)
        if IsUsableID(overrideID) then
            map.byID[overrideID] = fmtKey
            local oname = GetSpellNameFromID(overrideID)
            if oname then map.byName[oname:lower()] = fmtKey end
        end
    end

    if C_Spell and C_Spell.GetBaseSpell then
        local baseID = C_Spell.GetBaseSpell(spellID)
        if IsUsableID(baseID) then
            map.byID[baseID] = fmtKey
            local bname = GetSpellNameFromID(baseID)
            if bname then map.byName[bname:lower()] = fmtKey end
        end
    end
end

local function LookupKeyForSpell(map, spellID)
    if not map or not map.byID or not map.byName then return "" end
    if not IsUsableID(spellID) then return "" end

    local k = map.byID[spellID]
    if k then return k end

    if C_Spell and C_Spell.GetOverrideSpell then
        local o = C_Spell.GetOverrideSpell(spellID)
        if IsUsableID(o) and map.byID[o] then return map.byID[o] end
    end

    if C_Spell and C_Spell.GetBaseSpell then
        local b = C_Spell.GetBaseSpell(spellID)
        if IsUsableID(b) and map.byID[b] then return map.byID[b] end
    end

    local name = GetSpellNameFromID(spellID)
    if name then
        return map.byName[name:lower()] or ""
    end

    return ""
end

local function AddItemNameKey(nameToKey, itemName, fmtKey)
    if not itemName or itemName == "" then return end
    if not fmtKey or fmtKey == "" then return end
    local k = itemName:lower()
    if nameToKey[k] then return end
    nameToKey[k] = fmtKey
end

local function AddItemKey(map, itemID, fmtKey)
    if not map or not map.itemsByID or not map.itemsByName then return end
    if not IsUsableID(itemID) then return end
    if not fmtKey or fmtKey == "" then return end
    if map.itemsByID[itemID] then return end

    map.itemsByID[itemID] = fmtKey

    local name = GetItemNameFromID(itemID)
    if name then
        AddItemNameKey(map.itemsByName, name, fmtKey)
    end
end

local function LookupKeyForItem(map, itemID)
    if not map or not map.itemsByID or not map.itemsByName then return "" end
    if not IsUsableID(itemID) then return "" end

    local k = map.itemsByID[itemID]
    if k then return k end

    local name = GetItemNameFromID(itemID)
    if name then
        return map.itemsByName[name:lower()] or ""
    end

    return ""
end

-- ------------------------------------------------------------
-- BCDM button mapping scan
-- ------------------------------------------------------------
local function GetBoundSpellIDFromButton(btn)
    if not btn then return nil end

    if btn.spellID or btn.spellId or btn.SpellID then
        local sid = btn.spellID or btn.spellId or btn.SpellID
        if IsUsableID(sid) then return sid end
    end

    if btn.GetAttribute then
        local t = btn:GetAttribute("type") or btn:GetAttribute("type1")
        if IsUsableString(t) and t == "spell" then
            local spell = btn:GetAttribute("spell") or btn:GetAttribute("spell1")
            if IsUsableID(spell) then return spell end
            if type(spell) == "string" then
                return GetSpellIDFromName(spell)
            end
        end
    end

    if btn.action then
        local actionType, id = GetActionInfo(btn.action)
        if actionType == "spell" and type(id) == "number" then
            return id
        end
    end

    return nil
end

local function GetBoundItemIDFromButton(btn)
    if not btn then return nil end

    if btn.itemID or btn.itemId or btn.ItemID then
        local iid = btn.itemID or btn.itemId or btn.ItemID
        if IsUsableID(iid) then return iid end
    end

    if btn.GetAttribute then
        local t = btn:GetAttribute("type") or btn:GetAttribute("type1")
        if IsUsableString(t) and t == "item" then
            local item = btn:GetAttribute("item") or btn:GetAttribute("item1")
            if IsUsableID(item) then return item end
            if type(item) == "string" then
                local n = tonumber(item)
                if IsUsableID(n) then return n end
            end
        end
    end

    if btn.action then
        local actionType, id = GetActionInfo(btn.action)
        if actionType == "item" and type(id) == "number" then
            return id
        end
    end

    return nil
end

local function ScanBCDMFramesIntoMap(map)
    local roots = {
        _G["BCDM_CustomCooldownViewer"],
        _G["BCDM_CustomItemSpellBar"],
        _G["BCDM_CustomItemBar"],
        _G["BCDM_AdditionalCustomCooldownViewer"],
        _G["BCDM_TrinketBar"],
        _G["CDM_TrinketsContainer"],
    }

    for _, root in ipairs(roots) do
        if root then
            local list, seen = {}, {}
            CollectFrameDescendants(root, list, seen, 1, 7, 2000)

            for _, f in ipairs(list) do
                local btn = GetAttachFrame(f)
                if btn then
                    local rawKey = TryGetKeyFromButton(btn)
                    if rawKey and rawKey ~= "" and rawKey ~= "●" then
                        local fmt = FormatKey(rawKey)
                        if fmt ~= "" then
                            local sid = GetBoundSpellIDFromButton(btn)
                            if sid then
                                AddSpellKey(map, sid, fmt)
                            else
                                local iid = GetBoundItemIDFromButton(btn)
                                if iid then
                                    AddItemKey(map, iid, fmt)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ------------------------------------------------------------
-- Adapters
-- ------------------------------------------------------------
local Adapters = {}

Adapters.Blizzard = {
    Detect = function() return true end,
    Iterate = function(yield)
        local prefixes = {
            "ActionButton",
            "MultiBarBottomLeftButton",
            "MultiBarBottomRightButton",
            "MultiBarRightButton",
            "MultiBarLeftButton",
            "MultiBar5Button",
            "MultiBar6Button",
            "MultiBar7Button",
        }

        for _, prefix in ipairs(prefixes) do
            for j = 1, 12 do
                local btn = _G[prefix .. j]
                if btn and btn.action then
                    local key = TryGetKeyFromButton(btn)
                    if key and key ~= "●" then
                        local slot = btn.action

                        -- IMPORTANT: paging (mount, vehicle, stance, etc.)
                        if ActionButton_GetPagedID then
                            local paged = ActionButton_GetPagedID(btn)
                            if IsUsableID(paged) then
                                slot = paged
                            end
                        end

                        yield(slot, key)
                    end
                end
            end
        end
    end,
}

Adapters.Dominos = {
    Detect = function()
        local b = _G["DominosActionButton1"]
        return b and b.action ~= nil
    end,
    Iterate = function(yield)
        for i = 1, 180 do
            local btn = _G["DominosActionButton" .. i]
            if btn and btn.action then
                local key = TryGetKeyFromButton(btn)
                if key and key ~= "●" then
                    yield(btn.action, key)
                end
            end
        end
    end,
}

Adapters.BT4 = {
    Detect = function()
        local b = _G["BT4Button1"]
        return b and b.action ~= nil
    end,
    Iterate = function(yield)
        for i = 1, 180 do
            local btn = _G["BT4Button" .. i]
            if btn and btn.action then
                local key = TryGetKeyFromButton(btn)
                if key and key ~= "●" then
                    yield(btn.action, key)
                end
            end
        end
    end,
}

Adapters.ElvUI = {
    Detect = function()
        local b = _G["ElvUI_Bar1Button1"]
        return b and b.action ~= nil
    end,
    Iterate = function(yield)
        for bar = 1, 15 do
            local first = _G["ElvUI_Bar" .. bar .. "Button1"]
            if first then
                local prefix = "ElvUI_Bar" .. bar .. "Button"
                for j = 1, 12 do
                    local btn = _G[prefix .. j]
                    if btn and btn.action then
                        local key = TryGetKeyFromButton(btn)
                        if key and key ~= "●" then
                            yield(btn.action, key)
                        end
                    end
                end
            end
        end
    end,
}

local function PickAdapter()
    if Adapters.Dominos.Detect() then return Adapters.Dominos, "Dominos" end
    if Adapters.BT4.Detect() then return Adapters.BT4, "BT4" end
    if Adapters.ElvUI.Detect() then return Adapters.ElvUI, "ElvUI" end
    return Adapters.Blizzard, "Blizzard"
end

-- ------------------------------------------------------------
-- Mapping builder
-- ------------------------------------------------------------
local function ResolveMacroFromSlot(slot, id)
    local macroName = GetActionText and GetActionText(slot)
    if macroName and macroName ~= "" and GetMacroIndexByName then
        local idx = GetMacroIndexByName(macroName)
        if IsUsableID(idx) then return idx end
    end

    if IsUsableID(id) then
        if GetMacroInfo then
            local name = GetMacroInfo(id)
            if name then return id end
        end
    end

    return nil
end

-- Always include base Action Bar 1 bindings (ACTIONBUTTON1-12) so keys do not disappear
-- when Bar 1 is temporarily replaced by vehicle, override, possess, mount states.
local function ScanPrimaryBarBaseSlots(map, macroQueue, seenSlots)
    if not map or not macroQueue then return end
    if not GetBindingKey or not GetActionInfo then return end

    for page = 0, 9 do
        for i = 1, 12 do
            local slot = page * 12 + i
            if not seenSlots[slot] then
                local rawKey = GetBindingKey("ACTIONBUTTON" .. i)
                if rawKey and rawKey ~= "" and rawKey ~= "●" then
                    local fmt = FormatKey(rawKey)
                    if fmt ~= "" then
                        local actionType, id = GetActionInfo(slot)
                        if actionType == "spell" then
                            AddSpellKey(map, id, fmt)
                        elseif actionType == "item" then
                            AddItemKey(map, id, fmt)
                        elseif actionType == "macro" then
                            macroQueue[#macroQueue + 1] = { slot = slot, id = id, fmt = fmt }
                        end
                    end
                end
            end
        end
    end
end

local function BuildSpellToKeyMapping()
    if InCombatLockdown and InCombatLockdown() then
        return { byID = {}, byName = {}, itemsByID = {}, itemsByName = {} }, false
    end

    local adapter, name = PickAdapter()
    if not adapter or not adapter.Iterate then
        return { byID = {}, byName = {}, itemsByID = {}, itemsByName = {} }, false
    end

    local adapterChanged = (activeAdapterName ~= name)
    activeAdapterName = name

local map = { byID = {}, byName = {}, itemsByID = {}, itemsByName = {} }
    local macroQueue = {}
    local seenSlots = {}

    adapter.Iterate(function(slot, rawKey)
        local fmt = FormatKey(rawKey)
        if fmt == "" then return end

        seenSlots[slot] = true

        local actionType, id = GetActionInfo(slot)
        if not actionType or not id then return end

        if actionType == "spell" then
            AddSpellKey(map, id, fmt)
            return
        end

        if actionType == "item" then
            AddItemKey(map, id, fmt)
            return
        end

        if actionType == "macro" then
            macroQueue[#macroQueue + 1] = { slot = slot, id = id, fmt = fmt }
            return
        end
    end)

    ScanPrimaryBarBaseSlots(map, macroQueue, seenSlots)
    ScanBCDMFramesIntoMap(map)

    for _, m in ipairs(macroQueue) do
        local macroIndex = ResolveMacroFromSlot(m.slot, m.id)
        if macroIndex then
            local body = GetMacroBodySafe(macroIndex)

            local macroSpellID = ResolveMacroSpellID(macroIndex, body)
            if macroSpellID then
                SetSpellKey(map, macroSpellID, m.fmt)
            end

            local lowerBody = (body or ""):lower()
            local hasCast = lowerBody:find("/cast", 1, true) or lowerBody:find("/castsequence", 1, true)

            local uses = ExtractUseTokensFromBody(body)
            if uses then
                for _, tok in ipairs(uses) do
                    local n = tonumber(tok)
                    if n then
                        if (n == 13 or n == 14) then
                            if not hasCast then
                                local equipped = GetInventoryItemID and GetInventoryItemID("player", n)
                                if equipped and not map.itemsByID[equipped] then
                                    AddItemKey(map, equipped, m.fmt)
                                end
                            end
                        else
                            if not map.itemsByID[n] then
                                AddItemKey(map, n, m.fmt)
                            end
                        end
                    end
                end
            end
        end
    end

    return map, adapterChanged
end

local function RebuildMapping()
    local map, adapterChanged = BuildSpellToKeyMapping()
    mappingCache = map
    return adapterChanged
end

-- ------------------------------------------------------------
-- Viewer overlays
-- ------------------------------------------------------------
local function GetOrCreateOverlay(icon)
    icon = GetAttachFrame(icon)
    if not icon then return nil end

    if icon.cmkKeybindText and icon.cmkKeybindText.text then
        return icon.cmkKeybindText.text
    end

    icon.cmkKeybindText = CreateFrame("Frame", nil, icon, "BackdropTemplate")
    -- Do NOT set a fixed strata here; inherit from the parent icon so the
    -- overlay never floats above frames (e.g. the world map) that sit in a
    -- higher strata than the cooldown viewer itself.
    icon.cmkKeybindText:SetFrameLevel(icon:GetFrameLevel() + 2)

    local t = icon.cmkKeybindText:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    t:SetShadowColor(0, 0, 0, 1)
    t:SetShadowOffset(1, -1)
    t:SetDrawLayer("OVERLAY", 7)

    icon.cmkKeybindText.text = t
    return t
end

local function ApplyOverlayStyle(icon, viewerKey)
    icon = GetAttachFrame(icon)
    if not icon or not icon.cmkKeybindText then return end

    local s = GetViewerSettings(viewerKey)
    local t = GetOrCreateOverlay(icon)
    if not t then return end

    t:ClearAllPoints()
    t:SetPoint(s.anchor, icon, s.anchor, s.offsetX, s.offsetY)

    t:SetFont(GetFontPath(s.fontName), s.fontSize, s.fontFlags or "")

    local c = s.color or { 1, 1, 1, 1 }
    t:SetTextColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
end

local function HideOverlay(icon)
    icon = GetAttachFrame(icon)
    if icon and icon.cmkKeybindText then
        icon.cmkKeybindText:Hide()
    end
end

-- ------------------------------------------------------------
-- BCDM frame helpers
-- ------------------------------------------------------------
local function BCDMIDFromName(name)
    if not name then return nil end

    local id = name:match("^BCDM_Custom_(%d+)")
    if id then return tonumber(id) end

    id = name:match("^BCDM_AdditionalCustom_(%d+)")
    if id then return tonumber(id) end

    return nil
end

local function BCDMTrinketSlotFromName(name)
    if not name then return nil end
    local slot = name:match("^BCDM_Custom_Trinket_(%d+)")
    if slot then return tonumber(slot) end
    return nil
end

local function LooksLikeBCDMTrinketFrame(f)
    f = GetAttachFrame(f)
    if not f or not f.GetName then return false end
    local n = f:GetName()
    if not n then return false end

    if n:find("BCDM", 1, true) and n:lower():find("trinket", 1, true) then
        return true
    end

    return n:match("^BCDM_Custom_Trinket_%d+") ~= nil
end

local function LooksLikeBCDMCustomFrame(f)
    f = GetAttachFrame(f)
    if not f or not f.GetName then return false end
    local n = f:GetName()
    return n and (n:match("^BCDM_Custom_%d+") or n:match("^BCDM_AdditionalCustom_%d+"))
end

-- ------------------------------------------------------------
-- Target extraction
-- ------------------------------------------------------------
-- Collects every spell ID an icon might plausibly represent, best guess first.
-- The buff viewers in particular expose the tracked aura on .spellID while the
-- castable spell that actually owns the keybind sits on .linkedSpellID, so the
-- caller walks the candidates in order rather than trusting the first one.
local function ExtractSpellCandidates(icon)
    icon = GetAttachFrame(icon)
    if not icon then return nil end

    local out, seen = {}, {}
    local function add(id)
        -- IsUsableID must run first: a secret ID cannot be compared or used as
        -- a table key, so both the dedupe and the > 0 test below would error.
        if not IsUsableID(id) then return end
        if seen[id] then return end
        seen[id] = true
        out[#out + 1] = id
    end

    -- Ayije_CDM: spell data is accessed via GetCooldownInfo() or GetSpellID()
    if icon.GetCooldownInfo then
        local ok, info = pcall(icon.GetCooldownInfo, icon)
        if ok and CanReadTable(info) then
            add(info.overrideSpellID)
            add(info.spellID)
            add(info.linkedSpellID)
        end
    end

    if icon.GetSpellID then
        local ok, sid = pcall(icon.GetSpellID, icon)
        if ok then add(sid) end
    end

    -- Blizzard CDM: spell data via cooldownID. Some item frames expose this as a
    -- getter rather than a plain field, so try both before giving up.
    local cooldownID = icon.cooldownID
    if not IsUsableID(cooldownID) and type(icon.GetCooldownID) == "function" then
        local ok, value = pcall(icon.GetCooldownID, icon)
        if ok then cooldownID = value end
    end

    if IsUsableID(cooldownID)
        and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
        if ok and CanReadTable(info) then
            add(info.overrideSpellID)
            add(info.spellID)
            add(info.linkedSpellID)
        end
    end

    -- Direct field access (BCDM and others).
    -- Skip on Ayije CDM item frames: spellID is set to the itemID on those frames,
    -- which would cause a false spell match and prevent item lookup.
    if not icon.isItem then
        add(icon.spellID or icon.spellId or icon.SpellID)

        if icon.GetName then
            add(BCDMIDFromName(icon:GetName()))
        end

        if icon.GetParent then
            local p = icon:GetParent()
            if p and p.GetName then
                add(BCDMIDFromName(p:GetName()))
            end
        end
    end

    if #out == 0 then return nil end
    return out
end

local function ExtractItemFromIcon(icon, viewerKey)
    icon = GetAttachFrame(icon)
    if not icon then return nil end

    local iid = icon.itemID or icon.itemId or icon.ItemID

    if not iid and icon.GetName then
        iid = BCDMIDFromName(icon:GetName())
    end

    if not iid and icon.GetParent then
        local p = icon:GetParent()
        if p and p.GetName then
            iid = BCDMIDFromName(p:GetName())
        end
    end

    if not iid and viewerKey == "BCDMTrinkets" then
        local slot
        if icon.GetName then
            slot = BCDMTrinketSlotFromName(icon:GetName())
        end
        if not slot and icon.GetParent then
            local p = icon:GetParent()
            if p and p.GetName then
                slot = BCDMTrinketSlotFromName(p:GetName())
            end
        end
        if slot and GetInventoryItemID then
            iid = GetInventoryItemID("player", slot)
        end
    end

    return iid
end

local function ClearIconCaches(kids)
    for _, child in ipairs(kids) do
        child = GetAttachFrame(child)
        if child then
            child.cmkCachedSpellID = nil
            child.cmkCachedItemID = nil
        end
    end
end

-- ------------------------------------------------------------
-- Viewer child caching
-- ------------------------------------------------------------
local function ShouldRecacheChildren(viewerFrameName, viewerKey)
    local f = _G[viewerFrameName]
    if not f then return true end

    -- Ayije_CDM uses a frame pool; always recache so we pick up current active frames
    if f.itemFramePool then return true end

    local cached = viewerChildrenCache[viewerFrameName]
    local cachedCount = viewerChildCountCache[viewerFrameName] or 0
    if not cached then return true end

    if f.GetNumChildren and f:GetNumChildren() ~= cachedCount then
        return true
    end

    if viewerKey == "BCDMTrinkets" and #cached == 0 then
        return true
    end

    return false
end

local function CacheViewerChildren(viewerFrameName, viewerKey)
    local viewerFrame = _G[viewerFrameName]
    if not viewerFrame then
        viewerChildrenCache[viewerFrameName] = nil
        viewerChildCountCache[viewerFrameName] = 0
        return
    end

    local list = {}

    -- Ayije_CDM: icons are parented directly to UIParent and managed via a
    -- frame pool rather than as children of the viewer frame itself.
    if viewerFrame.itemFramePool then
        for frame in viewerFrame.itemFramePool:EnumerateActive() do
            if frame:IsShown() then
                list[#list + 1] = frame
            end
        end
        viewerChildrenCache[viewerFrameName] = list
        viewerChildCountCache[viewerFrameName] = #list
        ClearIconCaches(list)
        return
    end

    if viewerKey == "BCDMCustomSpells" or viewerKey == "BCDMCustomItems" or viewerKey == "BCDMTrinkets" then
        local seen = {}
        CollectFrameDescendants(viewerFrame, list, seen, 1, 7, 2000)
    else
        list = { viewerFrame:GetChildren() }
    end

    viewerChildrenCache[viewerFrameName] = list

    if viewerFrame.GetNumChildren then
        viewerChildCountCache[viewerFrameName] = viewerFrame:GetNumChildren()
    else
        viewerChildCountCache[viewerFrameName] = #list
    end

    ClearIconCaches(list)
end

local function GetViewerChildren(viewerFrameName, viewerKey)
    local viewerFrame = _G[viewerFrameName]
    if not viewerFrame then return {} end

    if ShouldRecacheChildren(viewerFrameName, viewerKey) then
        CacheViewerChildren(viewerFrameName, viewerKey)
    end

    return viewerChildrenCache[viewerFrameName] or {}
end

-- ------------------------------------------------------------
-- Apply viewer
-- ------------------------------------------------------------
local function ApplyViewer(viewerFrameName, viewerKey, map)
    local viewerFrame = _G[viewerFrameName]
    if not viewerFrame then return end

    local v = ns.db.profile.viewers and ns.db.profile.viewers[viewerKey]
    if not v or not v.showKeybinds then
        local kids = viewerChildrenCache[viewerFrameName] or { viewerFrame:GetChildren() }
        for _, child in ipairs(kids) do
            HideOverlay(child)
        end
        return
    end

    local kids = GetViewerChildren(viewerFrameName, viewerKey)

    for _, child in ipairs(kids) do
        child = GetAttachFrame(child)
        if child then
            local isCustom    = (viewerKey == "BCDMCustomSpells" or viewerKey == "BCDMCustomItems")
            local isBCDMTrink = (viewerKey == "BCDMTrinkets")
            local isCDMTrink  = (viewerKey == "Trinkets")

            local allowed =
                (not isCustom and not isBCDMTrink and not isCDMTrink)
                or (isCustom and LooksLikeBCDMCustomFrame(child))
                or (isBCDMTrink and LooksLikeBCDMTrinketFrame(child))
                or (isCDMTrink) -- CDM trinkets: do NOT apply BCDM name filtering

            if allowed then
                local text = ""
                local hasTarget = false

                if viewerKey == "BCDMTrinkets" or viewerKey == "Trinkets" then
                    local direct = GetDirectFormattedKey(child)
                    if direct ~= "" then
                        text = direct
                        hasTarget = true
                    else
                        local itemID = ExtractItemFromIcon(child, viewerKey)
                        if itemID then
                            local mapped = LookupKeyForItem(map, itemID)
                            if mapped ~= "" then
                                text = mapped
                                hasTarget = true
                            end
                        end
                    end

                elseif viewerKey == "BCDMCustomItems" then
                    local itemID = ExtractItemFromIcon(child, viewerKey)
                    if itemID then
                        text = LookupKeyForItem(map, itemID)
                        hasTarget = true
                    end

                else
                    local candidates = ExtractSpellCandidates(child)
                    if candidates then
                        -- First candidate that actually has a bound key wins.
                        for i = 1, #candidates do
                            text = LookupKeyForSpell(map, candidates[i])
                            if text ~= "" then break end
                        end
                        hasTarget = true
                    else
                        -- Handles Ayije CDM item frames (e.g. potions in the Racials bar).
                        -- Also tries the alternateItemID for cases where Ayije stores the
                        -- primary item ID on the frame but the action bar has the alternate.
                        local itemID = ExtractItemFromIcon(child, viewerKey)
                        if itemID then
                            text = LookupKeyForItem(map, itemID)
                            if text == "" and child.cdmRacialEntry and child.cdmRacialEntry.alternateItemID then
                                text = LookupKeyForItem(map, child.cdmRacialEntry.alternateItemID)
                            end
                            hasTarget = true
                        end
                    end
                end

                if hasTarget then
                    local t = GetOrCreateOverlay(child)
                    if t then
                        ApplyOverlayStyle(child, viewerKey)
                        if text == "" then
                            t:SetText("")
                            HideOverlay(child)
                        else
                            child.cmkKeybindText:Show()
                            t:SetText(text)
                            t:Show()
                        end
                    end
                else
                    HideOverlay(child)
                end
            else
                HideOverlay(child)
            end
        end
    end
end

local function ApplyAllViewers()
    if not mappingCache then return end
    for viewerName, viewerKey in pairs(viewers) do
        CacheViewerChildren(viewerName, viewerKey)
        ApplyViewer(viewerName, viewerKey, mappingCache)
    end
end

local function ApplyAllViewerStyles()
    if not mappingCache then return end
    for viewerName, viewerKey in pairs(viewers) do
        local viewerFrame = _G[viewerName]
        if viewerFrame then
            local kids = GetViewerChildren(viewerName, viewerKey)
            for _, child in ipairs(kids) do
                child = GetAttachFrame(child)
                if child and child.cmkKeybindText and child.cmkKeybindText:IsShown() then
                    ApplyOverlayStyle(child, viewerKey)
                end
            end
        end
    end
end


-- ------------------------------------------------------------
-- Assisted Combat rotation highlight
-- ------------------------------------------------------------
-- Blizzard renders its rotation helper on action buttons only -- there is no
-- Cooldown Manager equivalent and no CooldownViewer category for it -- so we
-- draw it ourselves: ask C_AssistedCombat which spell it wants cast next, then
-- animate Blizzard's own ants atlas on whichever viewer icon matches.
--
-- This is deliberately kept out of the keybind pipeline. The suggestion changes
-- constantly *during* combat, whereas every keybind rebuild is deferred until
-- combat ends. Instead we precompute a baseSpellID -> {glow,...} index whenever
-- the layout changes, so the in-combat tick is one API call and one compare.
local Rotation = {}
ns.Rotation = Rotation

local ROTATION_VIEWERS = {
    EssentialCooldownViewer = "Essential",
    UtilityCooldownViewer   = "Utility",
}

local ROTATION_ATLAS    = "RotationHelper_Ants_Flipbook_2x"
local ROTATION_ROWS     = 6
local ROTATION_COLS     = 5
local ROTATION_FRAMES   = 30
local ROTATION_DURATION = 1.0

local rotationEnabled        = false
local rotationHooksInstalled = false
local rotationSpells         = {}    -- [baseSpellID] = true
local rotationSpellsValid    = false
local rotationIndex          = {}    -- [baseSpellID] = { glow, ... }
local rotationFrames         = {}    -- every glow we ever created
local activeHighlights       = {}    -- glows currently shown
local currentSuggestion      = nil
local rotationIndexDirty     = true
local scheduledRotation      = false

-- Defined in the poll driver further down; forward-declared because the index
-- rebuild is what decides whether the poll should be running at all.
local StartRotationPoll, StopRotationPoll

local function GetRotationSettings(viewerKey)
    local v = (ns.db and ns.db.profile and ns.db.profile.viewers and ns.db.profile.viewers[viewerKey]) or {}
    return {
        combatOnly = v.rotationCombatOnly and true or false,
        color      = v.rotationColor or { 1, 1, 1, 1 },
        overhang   = (v.rotationOverhang ~= nil) and v.rotationOverhang or 4,
    }
end

local function IsRotationEnabled(viewerKey)
    if not ns.db or not ns.db.profile or not ns.db.profile.enabled then return false end
    local v = ns.db.profile.viewers and ns.db.profile.viewers[viewerKey]
    return (v and v.rotationHighlight) and true or false
end

local function IsRotationEnabledForAnyViewer()
    for _, viewerKey in pairs(ROTATION_VIEWERS) do
        if IsRotationEnabled(viewerKey) then return true end
    end
    return false
end

-- ------------------------------------------------------------
-- Blizzard API wrappers (secret-safe)
-- ------------------------------------------------------------
local function GetBaseSpellID(spellID)
    if not IsUsableID(spellID) then return nil end
    if C_Spell and C_Spell.GetBaseSpell then
        local ok, base = pcall(C_Spell.GetBaseSpell, spellID)
        if ok and IsUsableID(base) then return base end
    end
    return spellID
end

local function GetSuggestedSpellID()
    if not C_AssistedCombat or not C_AssistedCombat.GetNextCastSpell then return nil end
    -- false decouples us from the visible action buttons and from the
    -- assistedCombatHighlight CVar, so the highlight still works when
    -- Blizzard's own rotation display is switched off.
    local ok, id = pcall(C_AssistedCombat.GetNextCastSpell, false)
    if not ok then return nil end
    if not IsUsableID(id) then return nil end
    return id
end

local function RefreshRotationSpells()
    wipe(rotationSpells)
    if C_AssistedCombat and C_AssistedCombat.GetRotationSpells then
        local ok, list = pcall(C_AssistedCombat.GetRotationSpells)
        if ok and CanReadTable(list) then
            for _, id in ipairs(list) do
                local base = GetBaseSpellID(id)
                if base then rotationSpells[base] = true end
            end
        end
    end
    rotationSpellsValid = true
end

-- ------------------------------------------------------------
-- Highlight frames
-- ------------------------------------------------------------
local function ApplyRotationStyle(f, viewerKey)
    if not f or not f.tex then return end

    local s = GetRotationSettings(viewerKey or f.viewerKey)

    local icon = f:GetParent()
    if icon and icon.GetFrameLevel then
        pcall(f.SetFrameLevel, f, icon:GetFrameLevel() + 1)
    end

    -- The ants have to overhang the icon border. Sizing from icon:GetWidth()
    -- is not an option: viewer geometry can be a secret value and arithmetic
    -- on one raises a Lua error. Anchoring opposite corners with a fixed inset
    -- lets the layout engine resolve the size instead, so no Lua arithmetic
    -- ever touches icon geometry. Hence a pixel overhang, not a scale factor.
    local o = s.overhang
    f.tex:ClearAllPoints()
    f.tex:SetPoint("TOPLEFT",     f, "TOPLEFT",     -o,  o)
    f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT",  o, -o)

    local c = s.color
    local r, g, b, a = c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
    -- An ADD-blended atlas tints muddy unless it is desaturated first.
    f.tex:SetDesaturated(not (r >= 1 and g >= 1 and b >= 1))
    f.tex:SetVertexColor(r, g, b, a)
end

local function CreateRotationHighlight(icon, viewerKey)
    icon = GetAttachFrame(icon)
    if not icon then return nil end
    if icon.cmkRotationGlow then
        icon.cmkRotationGlow.viewerKey = viewerKey
        return icon.cmkRotationGlow
    end

    local f = CreateFrame("Frame", nil, icon)
    f:EnableMouse(false)
    f:SetAllPoints(icon)
    f:Hide()

    local tex = f:CreateTexture(nil, "OVERLAY", nil, 7)
    tex:SetBlendMode("ADD")
    -- false stops the atlas from imposing its own size over our anchors.
    tex:SetAtlas(ROTATION_ATLAS, false)

    local anim = tex:CreateAnimationGroup()
    anim:SetLooping("REPEAT")
    local flip = anim:CreateAnimation("FlipBook")
    flip:SetDuration(ROTATION_DURATION)
    flip:SetFlipBookRows(ROTATION_ROWS)
    flip:SetFlipBookColumns(ROTATION_COLS)
    flip:SetFlipBookFrames(ROTATION_FRAMES)
    flip:SetFlipBookFrameWidth(0)
    flip:SetFlipBookFrameHeight(0)

    f.tex = tex
    f.anim = anim
    f.viewerKey = viewerKey

    -- Driving the animation from Show/Hide means a hidden glow costs nothing,
    -- and the animation stops by itself when the CDM hides the parent icon.
    f:SetScript("OnShow", function(self)
        if self.anim and not self.anim:IsPlaying() then self.anim:Play() end
    end)
    f:SetScript("OnHide", function(self)
        if self.anim and self.anim:IsPlaying() then self.anim:Stop() end
    end)

    icon.cmkRotationGlow = f
    rotationFrames[#rotationFrames + 1] = f
    return f
end

local function HideRotationHighlights()
    for i = #activeHighlights, 1, -1 do
        activeHighlights[i]:Hide()
        activeHighlights[i] = nil
    end
end

local function ShowRotationHighlightsFor(baseID)
    local list = baseID and rotationIndex[baseID]
    if not list then return end

    local inCombat = InCombat()
    for i = 1, #list do
        local f = list[i]
        local s = GetRotationSettings(f.viewerKey)
        if inCombat or not s.combatOnly then
            f:Show()
            activeHighlights[#activeHighlights + 1] = f
        end
    end
end

-- ------------------------------------------------------------
-- Hot path: runs ~10x/sec in combat, so it must stay O(1)
-- ------------------------------------------------------------
local function RefreshRotationSuggestion(force)
    if not rotationEnabled then return end

    local id = GetSuggestedSpellID()
    local base = id and GetBaseSpellID(id) or nil

    if base == currentSuggestion and not force then return end
    currentSuggestion = base

    HideRotationHighlights()
    if base then ShowRotationHighlightsFor(base) end
end

local function RebuildRotationIndex()
    if not rotationSpellsValid then RefreshRotationSpells() end

    local newIndex, matched, found = {}, {}, 0

    for viewerName, viewerKey in pairs(ROTATION_VIEWERS) do
        if IsRotationEnabled(viewerKey) then
            local kids = GetViewerChildren(viewerName, viewerKey)
            for _, child in ipairs(kids) do
                child = GetAttachFrame(child)
                if child then
                    local candidates = ExtractSpellCandidates(child)
                    if candidates then
                        -- Index every candidate, not just the first: an icon can
                        -- expose overrideSpellID/spellID/linkedSpellID and the
                        -- suggestion may come back as any one of them.
                        for i = 1, #candidates do
                            local base = GetBaseSpellID(candidates[i])
                            if base and rotationSpells[base] then
                                local f = CreateRotationHighlight(child, viewerKey)
                                if f then
                                    ApplyRotationStyle(f, viewerKey)
                                    local bucket = newIndex[base]
                                    if not bucket then
                                        bucket = {}
                                        newIndex[base] = bucket
                                    end
                                    bucket[#bucket + 1] = f
                                    matched[f] = true
                                    found = found + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- In combat every icon's spell ID can legitimately be secret, so a rebuild
    -- can match nothing at all. Keep the last known-good index rather than
    -- blanking the highlight for the rest of the fight, and retry on regen.
    if found == 0 and next(rotationIndex) ~= nil and InCombat() then
        rotationIndexDirty = true
        return
    end

    rotationIndex = newIndex
    HideRotationHighlights()
    currentSuggestion = nil

    for i = 1, #rotationFrames do
        if not matched[rotationFrames[i]] then rotationFrames[i]:Hide() end
    end

    rotationIndexDirty = false

    if next(rotationIndex) then StartRotationPoll() else StopRotationPoll() end
    RefreshRotationSuggestion(true)
end

-- Coalesces relayout bursts. Deliberately not combat-gated, unlike the keybind
-- schedulers -- the guard above handles the in-combat case instead.
local function ScheduleRotationRebuild()
    if not rotationEnabled then return end

    rotationIndexDirty = true
    if scheduledRotation then return end
    scheduledRotation = true

    C_Timer.After(0.20, function()
        scheduledRotation = false
        if not rotationEnabled then
            rotationIndexDirty = false
            return
        end
        if rotationIndexDirty then RebuildRotationIndex() end
    end)
end

-- ------------------------------------------------------------
-- Poll driver
-- ------------------------------------------------------------
local rotationPoller = CreateFrame("Frame")
local rotationPollElapsed = 0
local rotationPollRate = 0.1

local function RefreshRotationPollRate()
    local rate
    if C_CVar and C_CVar.GetCVar then
        local ok, v = pcall(C_CVar.GetCVar, "assistedCombatIconUpdateRate")
        if ok then rate = tonumber(v) end
    end
    rate = rate or 0.1
    if rate < 0.05 then rate = 0.05 elseif rate > 1 then rate = 1 end
    rotationPollRate = rate
end

function StopRotationPoll()
    rotationPoller:SetScript("OnUpdate", nil)
end

function StartRotationPoll()
    rotationPollElapsed = 0
    RefreshRotationPollRate()
    rotationPoller:SetScript("OnUpdate", function(_, elapsed)
        rotationPollElapsed = rotationPollElapsed + elapsed
        if rotationPollElapsed < rotationPollRate then return end
        rotationPollElapsed = 0
        RefreshRotationSuggestion()
    end)
end

-- The poll is the authoritative source; these only cut latency, and only fire
-- while Blizzard's own CVar-driven highlight is active. hooksecurefunc cannot
-- be undone, so the enabled check has to live inside the callback.
local function InstallRotationHooks()
    if rotationHooksInstalled then return end
    rotationHooksInstalled = true

    if EventRegistry and EventRegistry.RegisterCallback then
        pcall(EventRegistry.RegisterCallback, EventRegistry,
            "AssistedCombatManager.OnAssistedHighlightSpellChange",
            function() RefreshRotationSuggestion() end, rotationPoller)
    end

    if hooksecurefunc and AssistedCombatManager
        and type(AssistedCombatManager.UpdateAllAssistedHighlightFramesForSpell) == "function" then
        hooksecurefunc(AssistedCombatManager, "UpdateAllAssistedHighlightFramesForSpell", function()
            RefreshRotationSuggestion()
        end)
    end
end

-- ------------------------------------------------------------
-- Module surface
-- ------------------------------------------------------------
function Rotation:Enable()
    if rotationEnabled then return end
    rotationEnabled = true

    InstallRotationHooks()
    rotationSpellsValid = false
    RefreshRotationSpells()
    RebuildRotationIndex()
end

function Rotation:Disable()
    rotationEnabled = false
    StopRotationPoll()
    HideRotationHighlights()

    -- Frames cannot be destroyed in WoW; hiding stops their animations.
    for i = 1, #rotationFrames do rotationFrames[i]:Hide() end

    rotationIndex = {}
    currentSuggestion = nil
    rotationIndexDirty = true
end

function Rotation:RefreshStyle()
    for i = 1, #rotationFrames do ApplyRotationStyle(rotationFrames[i]) end
end

function Rotation:OnSettingChanged()
    local want = IsRotationEnabledForAnyViewer()

    if want and not rotationEnabled then
        self:Enable()
        return
    end
    if not want and rotationEnabled then
        self:Disable()
        return
    end
    if not rotationEnabled then return end

    RebuildRotationIndex()
    self:RefreshStyle()
end

function Rotation:InvalidateSpells()
    rotationSpellsValid = false
    ScheduleRotationRebuild()
end

function Rotation:OnCombatChanged()
    if not rotationEnabled then return end
    if rotationIndexDirty then
        ScheduleRotationRebuild()
    else
        RefreshRotationSuggestion(true)
    end
end

function Rotation:OnCVarChanged(cvar)
    if not rotationEnabled then return end
    -- CVAR_UPDATE fires for every cvar in the game; ignore all but ours.
    if IsUsableString(cvar) and cvar ~= "assistedCombatIconUpdateRate" then return end
    RefreshRotationPollRate()
end

-- Exposed so EnsureViewerHooks (below) can flag a rebuild on relayout.
local function IsRotationViewer(viewerName)
    return ROTATION_VIEWERS[viewerName] ~= nil
end
-- ------------------------------------------------------------
-- Trinket warmup refresh (fixes "no keybind until interaction")
-- ------------------------------------------------------------
local function HasAnyTrinketKeyVisible()
    if not mappingCache then return false end
    local f = _G["BCDM_TrinketBar"]
    if not f then return false end

    CacheViewerChildren("BCDM_TrinketBar", "BCDMTrinkets")
    local kids = GetViewerChildren("BCDM_TrinketBar", "BCDMTrinkets")

    for _, child in ipairs(kids) do
        child = GetAttachFrame(child)
        if child and LooksLikeBCDMTrinketFrame(child) then
            local direct = GetDirectFormattedKey(child)
            if direct and direct ~= "" then
                return true
            end
        end
    end

    return false
end

local function WarmupTrinkets()
    if not isEnabled then
        trinketWarmupRunning = false
        return
    end

    if InCombat() then
        C_Timer.After(0.50, WarmupTrinkets)
        return
    end

    if not mappingCache then
        RebuildMapping()
    end

    CacheViewerChildren("BCDM_TrinketBar", "BCDMTrinkets")
    ApplyViewer("BCDM_TrinketBar", "BCDMTrinkets", mappingCache)

    if HasAnyTrinketKeyVisible() then
        trinketWarmupRunning = false
        return
    end

    trinketWarmupIndex = trinketWarmupIndex + 1
    if trinketWarmupIndex > #trinketWarmupDelays then
        trinketWarmupRunning = false
        return
    end

    C_Timer.After(trinketWarmupDelays[trinketWarmupIndex], WarmupTrinkets)
end

local function ScheduleTrinketWarmup(reason)
    if not isEnabled then return end
    if trinketWarmupRunning then return end

    trinketWarmupRunning = true
    trinketWarmupIndex = 1

    C_Timer.After(trinketWarmupDelays[trinketWarmupIndex], WarmupTrinkets)
end

-- ------------------------------------------------------------
-- Hooks
-- ------------------------------------------------------------
-- Forward-declared: defined below (Out of combat scheduler section) but
-- referenced from the combat-gated hooks in EnsureViewerHooks so a pending
-- refresh is retried once combat ends instead of being dropped.
local ScheduleOutOfCombatUpdate

local function EnsureViewerHooks()
    for viewerName, viewerKey in pairs(viewers) do
        if not hooked[viewerName] then
            local f = _G[viewerName]
            if f then
                -- Hook RefreshLayout if available (Blizzard CDM / BCDM style)
                if type(f.RefreshLayout) == "function" then
                    hooksecurefunc(f, "RefreshLayout", function()
                        if not isEnabled then return end
                        CacheViewerChildren(viewerName, viewerKey)
                        if IsRotationViewer(viewerName) then ScheduleRotationRebuild() end
                        if InCombat() then
                            ScheduleOutOfCombatUpdate(viewerKey .. ":RefreshLayout")
                            return
                        end
                        if not mappingCache then RebuildMapping() end
                        ApplyViewer(viewerName, viewerKey, mappingCache)

                        if viewerKey == "BCDMTrinkets" then
                            ScheduleTrinketWarmup("RefreshLayout")
                        end
                    end)
                end

                -- Hook Ayije_CDM's QueueViewer once on the CDM global.
                -- This fires after every layout pass so we can re-apply keybinds.
                local AyijeCDM = _G["Ayije_CDM"]
                if AyijeCDM and not AyijeCDM.__cmkQueueViewerHooked and type(AyijeCDM.QueueViewer) == "function" then
                    AyijeCDM.__cmkQueueViewerHooked = true
                    hooksecurefunc(AyijeCDM, "QueueViewer", function(_, vName)
                        if not isEnabled then return end
                        local viewerKey = viewers[vName]
                        if not viewerKey then return end
                        C_Timer.After(0.05, function()
                            if not isEnabled then return end
                            CacheViewerChildren(vName, viewerKey)
                            if InCombat() then
                                ScheduleOutOfCombatUpdate(viewerKey .. ":QueueViewer")
                                return
                            end
                            if not mappingCache then RebuildMapping() end
                            ApplyViewer(vName, viewerKey, mappingCache)
                        end)
                    end)
                end

                if not f.__cmkOnShowHooked then
                    f.__cmkOnShowHooked = true
                    f:HookScript("OnShow", function()
                        if not isEnabled then return end
                        CacheViewerChildren(viewerName, viewerKey)
                        if IsRotationViewer(viewerName) then ScheduleRotationRebuild() end
                        if InCombat() then
                            ScheduleOutOfCombatUpdate(viewerKey .. ":OnShow")
                            return
                        end
                        if not mappingCache then RebuildMapping() end
                        ApplyViewer(viewerName, viewerKey, mappingCache)

                        if viewerKey == "BCDMTrinkets" or viewerKey == "Trinkets" then
                            ScheduleTrinketWarmup("OnShow")
                        end
                    end)
                end

                hooked[viewerName] = true
                CacheViewerChildren(viewerName, viewerKey)
            end
        end
    end
end

-- ------------------------------------------------------------
-- Out of combat scheduler
-- ------------------------------------------------------------
function ScheduleOutOfCombatUpdate(reason)
    if not isEnabled then return end

    dirtyOOC = true
    if scheduledOOC then return end
    scheduledOOC = true

    local function run()
        scheduledOOC = false
        if not isEnabled then return end

        if InCombat() then
            C_Timer.After(0.50, run)
            return
        end

        if dirtyOOC then
            dirtyOOC = false
            RebuildMapping()
            EnsureViewerHooks()
            ApplyAllViewers()

            ScheduleTrinketWarmup("OOC")
        end
    end

    C_Timer.After(0.10, run)
end

local scheduledStyle = false
local function ScheduleStyleRefresh()
    if not isEnabled then return end
    if scheduledStyle then return end
    scheduledStyle = true

    local function run()
        scheduledStyle = false
        if not isEnabled then return end

        if InCombat() then
            C_Timer.After(0.50, run)
            return
        end

        ApplyAllViewerStyles()
        Rotation:RefreshStyle()
    end

    C_Timer.After(0.05, run)
end

local function ScheduleRebuildSeries(reason)
    if not isEnabled then return end

    seriesDirty = true
    if scheduledSeries then return end
    scheduledSeries = true
    seriesIndex = 1

    local function step()
        if not isEnabled then
            scheduledSeries = false
            seriesDirty = false
            return
        end

        if InCombat() then
            C_Timer.After(0.50, step)
            return
        end

        if seriesDirty then
            seriesDirty = false

            local adapterChanged = RebuildMapping()
            EnsureViewerHooks()
            ApplyAllViewers()

            ScheduleTrinketWarmup("Series")

            local needsMore = adapterChanged or MappingLooksEmpty(mappingCache)

            seriesIndex = seriesIndex + 1
            if needsMore and seriesIndex <= #seriesDelays then
                C_Timer.After(seriesDelays[seriesIndex], function()
                    seriesDirty = true
                    step()
                end)
                return
            end
        end

        scheduledSeries = false
    end

    C_Timer.After(seriesDelays[seriesIndex], step)
end

-- ------------------------------------------------------------
-- Binding hooks
-- ------------------------------------------------------------
local bindingsHooked = false
local function HookBindingChanges()
    if bindingsHooked then return end
    bindingsHooked = true

    local function onBindingChange()
        if not isEnabled then return end
        ScheduleOutOfCombatUpdate("bindings")
    end

    if hooksecurefunc then
        if SetBinding then hooksecurefunc("SetBinding", onBindingChange) end
        if SetBindingClick then hooksecurefunc("SetBindingClick", onBindingChange) end
        if SetBindingSpell then hooksecurefunc("SetBindingSpell", onBindingChange) end
        if SetBindingMacro then hooksecurefunc("SetBindingMacro", onBindingChange) end
        if SaveBindings then hooksecurefunc("SaveBindings", onBindingChange) end
        if LoadBindings then hooksecurefunc("LoadBindings", onBindingChange) end
    end
end

-- ------------------------------------------------------------
-- Events
-- ------------------------------------------------------------
local BAR_ADDONS = {
    BetterCooldownManager = true,
    Ayije_CDM             = true,
    ElvUI                 = true,
    Bartender4            = true,
    Dominos               = true,
}

local function ShouldRunSeries(event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        return true
    end
    if event == "ADDON_LOADED" then
        return arg1 == ADDON_NAME or BAR_ADDONS[arg1]
    end
    return false
end

local function ShouldScheduleOOC(event, arg1)
    if event == "ADDON_LOADED" then
        return false
    end

    return event == "PLAYER_REGEN_ENABLED"
        or event == "UPDATE_BINDINGS"
        or event == "UPDATE_MACROS"
        or event == "ACTIONBAR_SLOT_CHANGED"
        or event == "SPELLS_CHANGED"
        or event == "SPELL_DATA_LOAD_RESULT"
        or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "TRAIT_CONFIG_UPDATED"
        or event == "ACTIONBAR_PAGE_CHANGED"
        or event == "UPDATE_BONUS_ACTIONBAR"
        or event == "EDIT_MODE_LAYOUTS_UPDATED"
        or event == "PLAYER_EQUIPMENT_CHANGED"
        or event == "UNIT_INVENTORY_CHANGED"
        or event == "UPDATE_OVERRIDE_ACTIONBAR"
        or event == "UPDATE_VEHICLE_ACTIONBAR"
        or event == "UPDATE_POSSESS_BAR"
end

-- The rotation spell list depends on talents/spec/forms, so these invalidate it.
-- Deliberately NOT added to ShouldScheduleOOC: routing UPDATE_SHAPESHIFT_FORM or
-- PLAYER_TALENT_UPDATE there would trigger a full keybind RebuildMapping on every
-- druid form change.
local function ShouldInvalidateRotationSpells(event)
    return event == "PLAYER_TALENT_UPDATE"
        or event == "SPELLS_CHANGED"
        or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "TRAIT_CONFIG_UPDATED"
        or event == "UPDATE_SHAPESHIFT_FORM"
        or event == "EDIT_MODE_LAYOUTS_UPDATED"
        or event == "PLAYER_ENTERING_WORLD"
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if not isEnabled then return end

    if ShouldInvalidateRotationSpells(event) then
        Rotation:InvalidateSpells()
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        Rotation:OnCombatChanged()
    elseif event == "CVAR_UPDATE" then
        Rotation:OnCVarChanged(arg1)
    end

    if ShouldRunSeries(event, arg1) then
        ScheduleRebuildSeries(event)
        return
    end

    if event == "UNIT_INVENTORY_CHANGED" and arg1 and arg1 ~= "player" then
        return
    end

    if ShouldScheduleOOC(event, arg1) then
        ScheduleOutOfCombatUpdate(event)

        if event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
            ScheduleTrinketWarmup(event)
        end
    end
end)

function Keybinds:Enable()
    if isEnabled then return end
    isEnabled = true

    SafeRegister(eventFrame, "PLAYER_ENTERING_WORLD")
    SafeRegister(eventFrame, "ADDON_LOADED")
    SafeRegister(eventFrame, "PLAYER_REGEN_ENABLED")
    SafeRegister(eventFrame, "UPDATE_BINDINGS")
    SafeRegister(eventFrame, "UPDATE_MACROS")
    SafeRegister(eventFrame, "ACTIONBAR_SLOT_CHANGED")
    SafeRegister(eventFrame, "SPELLS_CHANGED")
    SafeRegister(eventFrame, "SPELL_DATA_LOAD_RESULT")
    SafeRegister(eventFrame, "PLAYER_SPECIALIZATION_CHANGED")
    SafeRegister(eventFrame, "TRAIT_CONFIG_UPDATED")
    SafeRegister(eventFrame, "UPDATE_BONUS_ACTIONBAR")
    SafeRegister(eventFrame, "ACTIONBAR_PAGE_CHANGED")
    SafeRegister(eventFrame, "EDIT_MODE_LAYOUTS_UPDATED")
    SafeRegister(eventFrame, "PLAYER_EQUIPMENT_CHANGED")
    SafeRegister(eventFrame, "UNIT_INVENTORY_CHANGED")
    SafeRegister(eventFrame, "UPDATE_OVERRIDE_ACTIONBAR")
    SafeRegister(eventFrame, "UPDATE_VEHICLE_ACTIONBAR")
    SafeRegister(eventFrame, "UPDATE_POSSESS_BAR")

    -- Rotation-highlight only. These must not reach ShouldScheduleOOC.
    SafeRegister(eventFrame, "PLAYER_REGEN_DISABLED")
    SafeRegister(eventFrame, "UPDATE_SHAPESHIFT_FORM")
    SafeRegister(eventFrame, "PLAYER_TALENT_UPDATE")
    SafeRegister(eventFrame, "CVAR_UPDATE")

    HookBindingChanges()
    EnsureViewerHooks()

    ScheduleRebuildSeries("enable")
    ScheduleTrinketWarmup("enable")

    Rotation:OnSettingChanged()
end

function Keybinds:Disable()
    if not isEnabled then return end

    Rotation:Disable()

    isEnabled = false
    mappingCache = nil
    eventFrame:UnregisterAllEvents()

    trinketWarmupRunning = false

    for viewerName in pairs(viewers) do
        local viewerFrame = _G[viewerName]
        if viewerFrame then
            local kids = viewerChildrenCache[viewerName] or { viewerFrame:GetChildren() }
            for _, child in ipairs(kids) do
                HideOverlay(child)
            end
        end
    end
end

function Keybinds:OnSettingChanged()
    if not ns.db or not ns.db.profile then return end

    -- Every settings change funnels through here (dialog widgets, slash
    -- commands, profile reset) so this is the single place to tell an
    -- already-open Ace3 options dialog to redraw itself.
    if ns.NotifyOptionsChanged then
        ns.NotifyOptionsChanged()
    end

    if not IsAnyViewerEnabled() then
        self:Disable()
        return
    end

    if not isEnabled then
        self:Enable()
        return
    end

    if mappingCache then
        ScheduleStyleRefresh()
    end

    ScheduleOutOfCombatUpdate("settings")

    -- Combat-safe by design, so unlike the keybind half this applies at once.
    Rotation:OnSettingChanged()
end

function Keybinds:ResetProfileToDefaults()
    if not ns.db then return end
    Rotation:Disable()
    ns.db:ResetProfile()
    mappingCache = nil
    viewerChildrenCache = {}
    viewerChildCountCache = {}
    hooked = {}
    scheduledOOC = false
    dirtyOOC = false
    scheduledSeries = false
    seriesDirty = false
    activeAdapterName = nil
    trinketWarmupRunning = false
    self:OnSettingChanged()
end

function Keybinds:Initialize()
    if type(_G["CMK_DB#"]) == "table" and type(_G["CMK_DB"]) ~= "table" then
        _G["CMK_DB"] = _G["CMK_DB#"]
        _G["CMK_DB#"] = nil
    end

    local defaults = ns.DB_DEFAULTS or FALLBACK_DEFAULTS
    ns.db = AceDB:New("CMK_DB", defaults, true)

    if ns.RegisterOptions then
        ns.RegisterOptions()
    end

    if not IsAnyViewerEnabled() then
        return
    end

    self:Enable()
end

-- ------------------------------------------------------------
-- Boot
-- ------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    Keybinds:Initialize()
end)

-- ------------------------------------------------------------
-- Slash commands
-- ------------------------------------------------------------
SLASH_CMK1 = "/cmk"
SlashCmdList.CMK = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "" or msg == "options" then
        if ns.OpenOptions then
            ns.OpenOptions()
            return
        end
        print("CMK: options not ready")
        return
    end

    if msg == "on" then
        if ns.db and ns.db.profile then
            ns.db.profile.enabled = true
        end
        Keybinds:OnSettingChanged()
        print("CMK: enabled")
        return
    end

    if msg == "off" then
        if ns.db and ns.db.profile then
            ns.db.profile.enabled = false
        end
        Keybinds:OnSettingChanged()
        print("CMK: disabled")
        return
    end

    if msg == "reset" then
        Keybinds:ResetProfileToDefaults()
        print("CMK: reset to defaults")
        return
    end

    print("CMK commands:")
    print("/cmk options")
    print("/cmk on")
    print("/cmk off")
    print("/cmk reset")
end