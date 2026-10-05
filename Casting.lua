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
    
    -- NAMPOWER MODE: Cast all 4 totems instantly
    if TotemNesia.hasNampower then
        local castCount = 0
        
        -- Each cast goes through cleansing mode and fallback handling
        if TotemNesia.CastTotemForElement("fire", set.fire) then
            castCount = castCount + 1
        end
        
        if TotemNesia.CastTotemForElement("earth", set.earth) then
            castCount = castCount + 1
        end
        
        if TotemNesia.CastTotemForElement("water", set.water) then
            castCount = castCount + 1
        end
        
        if TotemNesia.CastTotemForElement("air", set.air) then
            castCount = castCount + 1
        end
        
        if castCount > 0 then
            TotemNesia.DebugPrint("Cast " .. castCount .. " totems from Set " .. setNumber .. " (Nampower)")
        else
            TotemNesia.DebugPrint("No totems assigned to Set " .. setNumber)
        end
        
        return
    end
    
    -- SEQUENTIAL MODE: Cast one totem at a time for non-nampower users
    -- Check for timeout (10 seconds of inactivity resets to Fire)
    local currentTime = GetTime()
    if currentTime - TotemNesia.sequentialCastLastTime > 10 then
        TotemNesia.sequentialCastIndex = 1
    end
    
    -- Determine which totem to cast based on sequence index
    local totemName = nil
    local familyName = nil
    local element = nil
    
    if TotemNesia.sequentialCastIndex == 1 then
        totemName = set.fire
        familyName = "Fire"
        element = "fire"
    elseif TotemNesia.sequentialCastIndex == 2 then
        totemName = set.earth
        familyName = "Earth"
        element = "earth"
    elseif TotemNesia.sequentialCastIndex == 3 then
        totemName = set.water
        familyName = "Water"
        element = "water"
    elseif TotemNesia.sequentialCastIndex == 4 then
        totemName = set.air
        familyName = "Air"
        element = "air"
    end
    
    -- Cast the totem (cleansing mode can fill the water step even if the set has no water totem)
    local castName = nil
    if element then
        castName = TotemNesia.CastTotemForElement(element, totemName)
    end
    if castName then
        TotemNesia.DebugPrint("Casting " .. castName .. " (Set " .. setNumber .. ", " .. familyName .. " " .. TotemNesia.sequentialCastIndex .. "/4)")
    else
        TotemNesia.DebugPrint("No " .. (familyName or "totem") .. " assigned to Set " .. setNumber)
    end
    
    -- Advance to next totem in sequence
    TotemNesia.sequentialCastIndex = TotemNesia.sequentialCastIndex + 1
    if TotemNesia.sequentialCastIndex > 4 then
        TotemNesia.sequentialCastIndex = 1
        TotemNesia.DebugPrint("Sequence complete, resetting to Fire")
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
