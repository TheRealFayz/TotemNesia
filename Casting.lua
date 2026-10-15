-- TotemNesia: Keybind and macro functions: recall, totem sets, totem bar slots, shield
-- For Turtle WoW (1.12)

-- Core.lua stops loading on non-Shamans, so every other file stops too
if not TotemNesia or not TotemNesia.shared then
    return
end

-- Shared from files loaded earlier (see the TOC for load order)
local S = TotemNesia.shared
local IsShaman = S.IsShaman

-- Helper function for keybind macro (users create their own macro)
function TotemNesia_RecallTotems()
    if not IsShaman() then
        return
    end
    
    if UnitAffectingCombat("player") then
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Cannot recall totems while in combat")
        return
    end
    
    if TotemNesia.hasTotems then
        CastSpellByName("Totemic Recall")
        TotemNesia.DebugPrint("Keybind: Totemic Recall cast")
    else
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: No totems to recall")
    end
end

-- Nampower only queues instant spells (totems are instant) when its NP_QueueInstantSpells
-- setting is on. With it off, only the first totem of a set drops. Some Nampower settings
-- addons turn it back off at every login, so instead of relying on it, the set cast turns
-- it on for a moment and puts the player's own value back a few seconds later.
local queueRestoreFrame = CreateFrame("Frame")
queueRestoreFrame:Hide()  -- OnUpdate only runs while shown
local queueRestoreTime = 0
local queueRestoreValue = nil
queueRestoreFrame:SetScript("OnUpdate", function()
    if GetTime() >= queueRestoreTime then
        this:Hide()
        if queueRestoreValue then
            SetCVar("NP_QueueInstantSpells", queueRestoreValue)
            TotemNesia.DebugPrint("NP_QueueInstantSpells restored to " .. queueRestoreValue)
            queueRestoreValue = nil
        end
    end
end)

local function EnsureInstantQueue()
    local ok, value = pcall(GetCVar, "NP_QueueInstantSpells")
    if ok and value and value ~= "1" then
        queueRestoreValue = value
        SetCVar("NP_QueueInstantSpells", "1")
        queueRestoreTime = GetTime() + 3
        queueRestoreFrame:Show()
        TotemNesia.DebugPrint("NP_QueueInstantSpells was " .. value .. ", turned on for this totem set")
    elseif queueRestoreValue then
        -- Still on from an earlier press: keep it on a little longer
        queueRestoreTime = GetTime() + 3
    end
end

-- Element order used when casting a totem set
local SET_ORDER = {"fire", "earth", "water", "air"}

-- Double-press guard for one-press sets. A totem only counts as "already down" once the
-- combat log confirms it, which takes a moment. Without this, a quick second press could
-- send the whole set again. An element cast less than SET_PRESS_GUARD seconds ago is left
-- alone. (Same idea as CallOfElements' throw guard.)
local SET_PRESS_GUARD = 1.0
local setLastCast = {}  -- element -> time it was last sent by a set cast

-- Cast every totem in the set that needs dropping, all on this one keypress
local function CastWholeSet(set, setNumber, modeName)
    local now = GetTime()
    local castCount = 0
    local skipCount = 0
    for _, element in ipairs(SET_ORDER) do
        local totemName = set[element]
        local sentRecently = setLastCast[element] and (now - setLastCast[element]) < SET_PRESS_GUARD
        if sentRecently or TotemNesia.ShouldSkipSetTotem(element, totemName) then
            skipCount = skipCount + 1
        elseif TotemNesia.CastTotemForElement(element, totemName, true) then
            castCount = castCount + 1
            setLastCast[element] = now
        end
    end
    TotemNesia.DebugPrint("Set " .. setNumber .. ": cast " .. castCount .. ", skipped " .. skipCount .. " (" .. modeName .. ")")
end

-- Sequential totem casting function
function TotemNesia.CastNextTotem(setNumber)
    -- Safety checks
    if not TotemNesiaDB or not TotemNesiaDB.totemSets then
        TotemNesia.DebugPrint("Database not initialized")
        return
    end
    
    if not TotemNesiaDB.totemSets[setNumber] then
        TotemNesia.DebugPrint("Set " .. setNumber .. " not found")
        return
    end
    
    local set = TotemNesiaDB.totemSets[setNumber]
    
    -- Totems that are already down (same totem, more than 10 seconds left, and you're in
    -- range) are skipped, so pressing the key again only drops what's missing or expiring.
    -- NAMPOWER MODE: every totem that needs dropping goes out on this one keypress
    if TotemNesia.hasNampower then
        EnsureInstantQueue()
        CastWholeSet(set, setNumber, "Nampower")
        return
    end

    -- Without Nampower the client only takes one totem per keypress (tested on OctoWoW),
    -- so sets are cast one totem at a time below.

    -- SEQUENTIAL MODE (no Nampower): one totem per keypress, in Fire, Earth, Water, Air order.
    -- Empty slots and totems that are already down are passed over, so every press drops
    -- something useful. 10 seconds without a press starts the order over at Fire.
    local currentTime = GetTime()
    if currentTime - TotemNesia.sequentialCastLastTime > 10 then
        TotemNesia.sequentialCastIndex = 1
    end

    local castName = nil
    for _ = 1, 4 do
        local index = TotemNesia.sequentialCastIndex
        local element = SET_ORDER[index]
        local totemName = set[element]

        -- Move on to the next element for the next press (or the next try in this loop)
        TotemNesia.sequentialCastIndex = index + 1
        if TotemNesia.sequentialCastIndex > 4 then
            TotemNesia.sequentialCastIndex = 1
        end

        if not TotemNesia.ShouldSkipSetTotem(element, totemName) then
            castName = TotemNesia.CastTotemForElement(element, totemName)
            if castName then
                TotemNesia.DebugPrint("Casting " .. castName .. " (Set " .. setNumber .. ", " .. element .. ")")
                break
            end
        end
    end
    if not castName then
        TotemNesia.DebugPrint("Set " .. setNumber .. ": nothing to cast (all down or empty)")
    end

    -- Update last cast time
    TotemNesia.sequentialCastLastTime = GetTime()
end

-- Helper function for sequential totem casting keybind
function TotemNesia_CastNextTotem(setNumber)
    if not IsShaman() then
        return
    end
    
    if not setNumber then
        setNumber = TotemNesiaDB.currentTotemSet or 1
    end
    
    TotemNesia.CastNextTotem(setNumber)
end

-- Helper functions for Totem Bar slot keybinds
local function CastTotemBarSlot(element)
    if not IsShaman() then
        return
    end
    local slot = TotemNesia.totemBarSlots[element]
    if slot then
        TotemNesia.CastTotemForElement(element, slot.selectedTotem)
    end
end

function TotemNesia_CastTotemBar1() CastTotemBarSlot("fire") end
function TotemNesia_CastTotemBar2() CastTotemBarSlot("earth") end
function TotemNesia_CastTotemBar3() CastTotemBarSlot("water") end
function TotemNesia_CastTotemBar4() CastTotemBarSlot("air") end

-- Keybind / shield slot click: recast your shield
function TotemNesia_CastShield()
    if not IsShaman() then
        return
    end
    
    local shield = TotemNesia.GetChosenShield()
    if shield then
        CastSpellByName(shield)
    end
end
