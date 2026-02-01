-- TotemNesia: Automatically recalls totems after leaving combat
-- For Turtle WoW (1.12)
-- Version 4.3

-- ============================================================================
-- CLASS CHECK AND INITIALIZATION
-- ============================================================================

-- Early class check - don't load on non-Shamans
local _, playerClass = UnitClass("player")
if playerClass ~= "SHAMAN" then
    DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Non-Shaman detected, addon disabled.")
    return
end

-- Shaman detected, proceed with loading
DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Shaman detected, addon enabled.")

-- ============================================================================
-- KEYBIND STRINGS
-- ============================================================================

-- Header for keybindings menu
BINDING_HEADER_TOTEM_NESIA = "TotemNesia"

-- Individual keybind descriptions
BINDING_NAME_TOTEM_SET_1 = "Totem Set 1"
BINDING_NAME_TOTEM_SET_2 = "Totem Set 2"
BINDING_NAME_TOTEM_SET_3 = "Totem Set 3"
BINDING_NAME_TOTEM_SET_4 = "Totem Set 4"
BINDING_NAME_TOTEM_SET_5 = "Totem Set 5"

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local TOTEM_DISTANCE_THRESHOLD = 30  -- Yards before warning player about totem distance
local DISTANCE_CHECK_INTERVAL = 0.5  -- Seconds between distance checks

-- ============================================================================
-- ADDON STATE
-- ============================================================================
TotemNesia = {}
TotemNesia.displayTimer = nil
TotemNesia.inCombat = false
TotemNesia.hasTotems = false
TotemNesia.monitoringForRecall = false
TotemNesia.monitorTimer = 0
TotemNesia.activeTotems = {}  -- Track which totems are currently active
TotemNesia.totemTimestamps = {}  -- Track when each totem was placed
TotemNesia.totemPositions = {}  -- Track where totems were placed
TotemNesia.distanceCheckTimer = 0  -- Timer for distance checks
TotemNesia.weaponEnchantTime = 0  -- Track weapon enchant timestamp
TotemNesia.weaponEnchantExpiry = nil  -- Track when weapon enchant expires
TotemNesia.clickedWeaponEnchant = nil  -- Track which weapon enchant was clicked
TotemNesia.sequentialCastIndex = 1  -- Track position in sequential totem casting (1=fire, 2=earth, 3=water, 4=air)
TotemNesia.sequentialCastLastTime = 0  -- Track last cast time for timeout reset
TotemNesia.hasNampower = false  -- Whether nampower client mod is detected
TotemNesia.nampowerVersion = nil  -- Nampower version if detected
TotemNesia.updateNotified = false  -- Track if update notification has been shown this session
TotemNesia.manaCheckTimer = 0  -- Timer for checking mana periodically
TotemNesia.manaAlertCooldown = 0  -- Cooldown timer to prevent spam
TotemNesia.belowThreshold = false  -- Track if currently below threshold to detect crossing
TotemNesia.potionAlertCooldown = 0  -- Cooldown timer for potion alert
TotemNesia.belowPotionThreshold = false  -- Track if currently below potion threshold
TotemNesia.publicManaAlertCooldown = 0  -- Cooldown timer for public mana alert
TotemNesia.belowPublicManaThreshold = false  -- Track if currently below public mana threshold


-- Check for nampower client mod
function TotemNesia.DetectNampower()
    if GetNampowerVersion then
        local major, minor, patch = GetNampowerVersion()
        if major then
            TotemNesia.hasNampower = true
            TotemNesia.nampowerVersion = string.format("%d.%d.%d", major, minor, patch)
            TotemNesia.DebugPrint("Nampower " .. TotemNesia.nampowerVersion .. " detected - instant multi-totem casting enabled!")
            return true
        end
    end
    TotemNesia.hasNampower = false
    return false
end

-- Get addon version from TOC file (e.g., "3.4.41")
function TotemNesia.GetVersion()
    return tostring(GetAddOnMetadata("TotemNesia", "Version"))
end

-- Convert version string to comparable number (e.g., "3.4.41" -> 30441)
function TotemNesia.GetVersionNumber()
    local versionStr = TotemNesia.GetVersion()
    local _, _, major, minor, patch = string.find(versionStr, "(%d+)%.(%d+)%.(%d+)")
    major = tonumber(major) or 0
    minor = tonumber(minor) or 0
    patch = tonumber(patch) or 0
    return major * 10000 + minor * 100 + patch
end

-- Send version info to party/raid members
function TotemNesia.BroadcastVersion()
    if GetNumRaidMembers() > 0 then
        SendAddonMessage("TotemNesia", "VER:" .. TotemNesia.GetVersionNumber(), "RAID")
    elseif GetNumPartyMembers() > 0 then
        SendAddonMessage("TotemNesia", "VER:" .. TotemNesia.GetVersionNumber(), "PARTY")
    end
end

-- Check if remote version is newer and notify player
function TotemNesia.CheckRemoteVersion(remoteVersion)
    local localVersion = TotemNesia.GetVersionNumber()
    if tonumber(remoteVersion) > localVersion and not TotemNesia.updateNotified then
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: There is a new version of TotemNesia available, download it at https://github.com/TheRealFayz/TotemNesia")
        TotemNesia.updateNotified = true
    end
end

-- Track all totem icon textures for refreshing after spellbook loads
TotemNesia.totemIcons = {}

-- Refresh all totem icons after spellbook is loaded
function TotemNesia.RefreshTotemSetIcons()
    if not TotemNesia.totemIcons then
        return
    end
    
    local refreshCount = 0
    for _, iconData in ipairs(TotemNesia.totemIcons) do
        if iconData and iconData.iconTexture and iconData.totemName then
            local texture = GetTotemIcon(iconData.totemName)
            iconData.iconTexture:SetTexture(texture)
            refreshCount = refreshCount + 1
        end
    end
    TotemNesia.DebugPrint("Refreshed " .. refreshCount .. " totem icons")
end

-- Initialize saved variables
function TotemNesia.InitDB()
    if not TotemNesiaDB then
        TotemNesiaDB = {}
    end
    
    if TotemNesiaDB.isLocked == nil then
        TotemNesiaDB.isLocked = true
    end
    if TotemNesiaDB.debugMode == nil then
        TotemNesiaDB.debugMode = false
    end
    if TotemNesiaDB.audioEnabled == nil then
        TotemNesiaDB.audioEnabled = true
    end
    if TotemNesiaDB.minimapPos == nil then
        TotemNesiaDB.minimapPos = 180
    end
    if TotemNesiaDB.minimapHidden == nil then
        TotemNesiaDB.minimapHidden = false
    end
    if TotemNesiaDB.timerDuration == nil then
        TotemNesiaDB.timerDuration = 15
    end
    if TotemNesiaDB.hideUIElement == nil then
        -- Auto-hide until level 10 and has Totemic Recall
        local playerLevel = UnitLevel("player")
        local hasTotemicRecall = false
        
        -- Check if player has Totemic Recall spell
        local i = 1
        while true do
            local spellName = GetSpellName(i, BOOKTYPE_SPELL)
            if not spellName then break end
            if spellName == "Totemic Recall" then
                hasTotemicRecall = true
                break
            end
            i = i + 1
        end
        
        -- Auto-hide if under level 10 or doesn't have the spell yet
        if playerLevel < 10 or not hasTotemicRecall then
            TotemNesiaDB.hideUIElement = true
        else
            TotemNesiaDB.hideUIElement = false
        end
    end
    if TotemNesiaDB.totemTrackerLocked == nil then
        TotemNesiaDB.totemTrackerLocked = true
    end
    if TotemNesiaDB.enabledSolo == nil then
        TotemNesiaDB.enabledSolo = true
    end
    if TotemNesiaDB.enabledParty == nil then
        TotemNesiaDB.enabledParty = true
    end
    if TotemNesiaDB.enabledRaid == nil then
        TotemNesiaDB.enabledRaid = true
    end
    if TotemNesiaDB.totemTrackerLayout == nil then
        TotemNesiaDB.totemTrackerLayout = "Horizontal"
    end
    if TotemNesiaDB.totemBarEnabled == nil then
        TotemNesiaDB.totemBarEnabled = true
    end
    if TotemNesiaDB.totemBarSlots == nil then
        TotemNesiaDB.totemBarSlots = {
            fire = nil,
            earth = nil,
            water = nil,
            air = nil,
            weapon = nil
        }
    end
    if TotemNesiaDB.totemBarLocked == nil then
        TotemNesiaDB.totemBarLocked = true
    end
    if TotemNesiaDB.totemBarLayout == nil then
        TotemNesiaDB.totemBarLayout = "Horizontal"
    end
    if TotemNesiaDB.totemBarFlyoutDirection == nil then
        TotemNesiaDB.totemBarFlyoutDirection = "Up"
    end
    if TotemNesiaDB.totemBarHidden == nil then
        TotemNesiaDB.totemBarHidden = false
    end
    if TotemNesiaDB.uiFrameScale == nil then
        TotemNesiaDB.uiFrameScale = 1.0
    end
    if TotemNesiaDB.totemTrackerScale == nil then
        TotemNesiaDB.totemTrackerScale = 1.0
    end
    if TotemNesiaDB.totemBarScale == nil then
        TotemNesiaDB.totemBarScale = 1.0
    end
    if TotemNesiaDB.hideWeaponSlot == nil then
        TotemNesiaDB.hideWeaponSlot = false
    end
    if TotemNesiaDB.shiftToOpenFlyouts == nil then
        TotemNesiaDB.shiftToOpenFlyouts = false  -- Default false = shift required
    end
    if TotemNesiaDB.manaThreshold == nil then
        TotemNesiaDB.manaThreshold = 30  -- Default to 30%
    end
    if TotemNesiaDB.manaAudioMuted == nil then
        TotemNesiaDB.manaAudioMuted = false
    end
    if TotemNesiaDB.potionThreshold == nil then
        TotemNesiaDB.potionThreshold = 30
    end
    if TotemNesiaDB.potionAudioMuted == nil then
        TotemNesiaDB.potionAudioMuted = false
    end
    if TotemNesiaDB.publicManaMuted == nil then
        TotemNesiaDB.publicManaMuted = false
    end
    
    -- Initialize totem sets (5 sets)
    if TotemNesiaDB.totemSets == nil then
        TotemNesiaDB.totemSets = {
            [1] = {fire = nil, earth = nil, water = nil, air = nil},
            [2] = {fire = nil, earth = nil, water = nil, air = nil},
            [3] = {fire = nil, earth = nil, water = nil, air = nil},
            [4] = {fire = nil, earth = nil, water = nil, air = nil},
            [5] = {fire = nil, earth = nil, water = nil, air = nil}
        }
    end
    if TotemNesiaDB.currentTotemSet == nil then
        TotemNesiaDB.currentTotemSet = 1
    end
end

-- Create the icon frame
local iconFrame = CreateFrame("Button", "TotemNesiaIconFrame", UIParent)
iconFrame:SetWidth(80)
iconFrame:SetHeight(80)
iconFrame:SetPoint("CENTER", 0, 200)
iconFrame:SetMovable(true)
iconFrame:SetUserPlaced(true)
iconFrame:EnableMouse(true)
iconFrame:RegisterForClicks("LeftButtonUp")
iconFrame:SetFrameStrata("HIGH")
iconFrame:Hide()

-- Set up backdrop
iconFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
iconFrame:SetBackdropColor(0, 0, 0, 0.75)
iconFrame:SetBackdropBorderColor(1, 1, 1, 1)

-- Get Totemic Recall spell icon texture
local function GetTotemicRecallIcon()
    local i = 1
    while true do
        local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            break
        end
        if spellName == "Totemic Recall" then
            local texture = GetSpellTexture(i, BOOKTYPE_SPELL)
            return texture
        end
        i = i + 1
    end
    -- Fallback to generic totem icon if spell not found
    return "Interface\\Icons\\Spell_Nature_Reincarnation"
end

-- Create the spell icon texture
local iconTexture = iconFrame:CreateTexture(nil, "ARTWORK")
iconTexture:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
iconTexture:SetWidth(64)
iconTexture:SetHeight(64)
iconTexture:SetTexture(GetTotemicRecallIcon())

-- Create the timer text overlay
local timerText = iconFrame:CreateFontString(nil, "OVERLAY")
timerText:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
timerText:SetFont("Fonts\\FRIZQT__.TTF", 48, "OUTLINE")
timerText:SetText("")
timerText:SetTextColor(1, 1, 1)
timerText:SetShadowColor(0, 0, 0, 1)
timerText:SetShadowOffset(2, -2)

-- Elemental totem corner indicators (20% of 80px = 16 pixels)
-- Positioned to match in-game totem drop locations
local elementalIcons = {}

-- Fire totem (upper left)
elementalIcons.fire = CreateFrame("Frame", nil, iconFrame)
elementalIcons.fire:SetWidth(16)
elementalIcons.fire:SetHeight(16)
elementalIcons.fire:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 8, -8)
elementalIcons.fire.texture = elementalIcons.fire:CreateTexture(nil, "OVERLAY")
elementalIcons.fire.texture:SetAllPoints(elementalIcons.fire)
elementalIcons.fire:Hide()

-- Earth totem (upper right)
elementalIcons.earth = CreateFrame("Frame", nil, iconFrame)
elementalIcons.earth:SetWidth(16)
elementalIcons.earth:SetHeight(16)
elementalIcons.earth:SetPoint("TOPRIGHT", iconFrame, "TOPRIGHT", -8, -8)
elementalIcons.earth.texture = elementalIcons.earth:CreateTexture(nil, "OVERLAY")
elementalIcons.earth.texture:SetAllPoints(elementalIcons.earth)
elementalIcons.earth:Hide()

-- Air totem (bottom left)
elementalIcons.air = CreateFrame("Frame", nil, iconFrame)
elementalIcons.air:SetWidth(16)
elementalIcons.air:SetHeight(16)
elementalIcons.air:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMLEFT", 8, 8)
elementalIcons.air.texture = elementalIcons.air:CreateTexture(nil, "OVERLAY")
elementalIcons.air.texture:SetAllPoints(elementalIcons.air)
elementalIcons.air:Hide()

-- Water totem (bottom right)
elementalIcons.water = CreateFrame("Frame", nil, iconFrame)
elementalIcons.water:SetWidth(16)
elementalIcons.water:SetHeight(16)
elementalIcons.water:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -8, 8)
elementalIcons.water.texture = elementalIcons.water:CreateTexture(nil, "OVERLAY")
elementalIcons.water.texture:SetAllPoints(elementalIcons.water)
elementalIcons.water:Hide()

-- Store reference for updates
TotemNesia.elementalIcons = elementalIcons

-- Make frame draggable
iconFrame:RegisterForDrag("LeftButton")
iconFrame:SetScript("OnDragStart", function()
    if not TotemNesiaDB.isLocked then
        this:StartMoving()
    end
end)
iconFrame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
end)

-- Make frame clickable to recall totems
iconFrame:SetScript("OnClick", function()
    TotemNesia.DebugPrint("Icon clicked")
    
    if TotemNesiaDB.isLocked and iconFrame:IsVisible() then
        local i = 1
        while true do
            local spellName = GetSpellName(i, BOOKTYPE_SPELL)
            if not spellName then
                break
            end
            if spellName == "Totemic Recall" then
                CastSpell(i, BOOKTYPE_SPELL)
                iconFrame:Hide()
                TotemNesia.displayTimer = nil
                TotemNesia.hasTotems = false
                DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Totems recalled!")
                break
            end
            i = i + 1
        end
    end
end)

-- Debug print function
function TotemNesia.DebugPrint(msg)
    if TotemNesiaDB and TotemNesiaDB.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia DEBUG: " .. msg)
    end
end

-- Function to check if addon should be active based on group settings
function TotemNesia.IsAddonEnabled()
    if not TotemNesiaDB then
        return true  -- Default to enabled if DB not initialized yet
    end
    
    local inRaid = GetNumRaidMembers() > 0
    local inParty = GetNumPartyMembers() > 0
    
    if inRaid then
        return TotemNesiaDB.enabledRaid
    elseif inParty then
        return TotemNesiaDB.enabledParty
    else
        return TotemNesiaDB.enabledSolo
    end
end

-- Function to get totem/weapon enchant icon texture
function GetTotemIcon(totemName)
    local i = 1
    while true do
        local spellName = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            break
        end
        if spellName == totemName then
            local texture = GetSpellTexture(i, BOOKTYPE_SPELL)
            if texture then
                return texture
            end
        end
        i = i + 1
    end
    return "Interface\\Icons\\Spell_Nature_Reincarnation"
end

-- Check if a totem/spell is learned
function IsTotemLearned(totemName)
    local i = 1
    while true do
        local spellName = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            return false
        end
        if spellName == totemName then
            return true
        end
        i = i + 1
    end
    return false
end

-- Totem duration table (base durations without Totemic Mastery talent)
local totemDurations = {
    -- Fire Totems
    ["Flametongue Totem"] = 120,
    ["Frost Resistance Totem"] = 120,
    ["Magma Totem"] = 20,
    ["Fire Nova Totem"] = 5,
    ["Searing Totem"] = 30,
    
    -- Earth Totems
    ["Tremor Totem"] = 120,
    ["Strength of Earth Totem"] = 120,
    ["Earthbind Totem"] = 45,
    ["Stoneskin Totem"] = 120,
    ["Stoneclaw Totem"] = 15,
    
    -- Water Totems
    ["Poison Cleansing Totem"] = 120,
    ["Disease Cleansing Totem"] = 120,
    ["Frost Resistance Totem"] = 120,
    ["Mana Spring Totem"] = 60,
    ["Healing Stream Totem"] = 60,
    
    -- Air Totems
    ["Windfall Totem"] = 120,
    ["Tranquil Air Totem"] = 120,
    ["Nature Resistance Totem"] = 120,
    ["Grace of Air Totem"] = 120,
    ["Windfury Totem"] = 120,
    ["Grounding Totem"] = 45
}

-- Totems that are NOT affected by Totemic Mastery (damage/utility totems)
local totemMasteryExceptions = {
    ["Magma Totem"] = true,
    ["Fire Nova Totem"] = true,
    ["Searing Totem"] = true,
    ["Earthbind Totem"] = true,
    ["Stoneclaw Totem"] = true
}

-- Function to check if player has Totemic Mastery talent
local function HasTotemicMastery()
    local numTabs = GetNumTalentTabs()
    for t = 1, numTabs do
        local numTalents = GetNumTalents(t)
        for i = 1, numTalents do
            local name, _, _, _, rank = GetTalentInfo(t, i)
            if name == "Totemic Mastery" and rank > 0 then
                return true
            end
        end
    end
    return false
end

-- Function to get totem duration in seconds
local function GetTotemDuration(totemName)
    local baseDuration = totemDurations[totemName]
    
    -- If totem not in table, default to 120 seconds
    if not baseDuration then
        baseDuration = 120
    end
    
    -- Apply Totemic Mastery talent (+20% duration) to helpful totems only
    if HasTotemicMastery() and not totemMasteryExceptions[totemName] then
        baseDuration = baseDuration * 1.2
    end
    
    return baseDuration
end

-- Function to check if a name is actually a valid totem
-- This prevents false positives from buffs/items with "Totem" in the name
local function IsValidTotem(name)
    -- Known totem names
    local validTotems = {
        -- Fire
        "Searing Totem", "Fire Nova Totem", "Magma Totem", "Flametongue Totem", "Frost Resistance Totem",
        -- Water
        "Healing Stream Totem", "Mana Spring Totem", "Mana Tide Totem", "Disease Cleansing Totem", 
        "Poison Cleansing Totem", "Fire Resistance Totem",
        -- Earth  
        "Stoneclaw Totem", "Stoneskin Totem", "Earthbind Totem", "Tremor Totem", "Strength of Earth Totem",
        -- Air
        "Windfury Totem", "Grace of Air Totem", "Windwall Totem", "Grounding Totem", 
        "Nature Resistance Totem", "Tranquil Air Totem"
    }
    
    -- Check if the name matches any known totem
    for _, totemName in ipairs(validTotems) do
        if string.find(name, totemName) then
            return true, totemName  -- Return true and the standardized name
        end
    end
    
    return false, nil
end

-- Function to find the highest learned rank of a spell/totem
-- Returns the spell ID of the highest rank, or nil if not found
local function GetHighestLearnedRank(baseName)
    local highestId = nil
    local highestRank = 0
    
    -- Scan spellbook for all ranks of this spell
    for i = 1, 200 do
        local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            break  -- End of spellbook
        end
        
        -- Check if this spell matches the base name
        if spellName == baseName then
            -- Extract rank number from spellRank (e.g., "Rank 5" -> 5)
            local rank = 1  -- Default rank if no rank string
            if spellRank then
                local _, _, rankNum = string.find(spellRank, "Rank (%d+)")
                if rankNum then
                    rank = tonumber(rankNum)
                end
            end
            
            -- Keep track of highest rank
            if rank >= highestRank then
                highestRank = rank
                highestId = i
            end
        end
    end
    
    return highestId
end

-- Function to get totem element type
local function GetTotemElement(totemName)
    -- Fire totems
    if string.find(totemName, "Searing") or string.find(totemName, "Fire Nova") or 
       string.find(totemName, "Magma") or string.find(totemName, "Flametongue") or
       string.find(totemName, "Frost Resistance") then
        return "fire"
    end
    
    -- Water totems
    if string.find(totemName, "Healing Stream") or string.find(totemName, "Mana Spring") or
       string.find(totemName, "Mana Tide") or string.find(totemName, "Disease Cleansing") or
       string.find(totemName, "Poison Cleansing") or string.find(totemName, "Fire Resistance") then
        return "water"
    end
    
    -- Earth totems
    if string.find(totemName, "Stoneskin") or string.find(totemName, "Strength of Earth") or
       string.find(totemName, "Earthbind") or string.find(totemName, "Tremor") or
       string.find(totemName, "Stoneclaw") then
        return "earth"
    end
    
    -- Air totems
    if string.find(totemName, "Windfury") or string.find(totemName, "Grace of Air") or
       string.find(totemName, "Windwall") or string.find(totemName, "Grounding") or
       string.find(totemName, "Nature Resistance") or string.find(totemName, "Tranquil Air") then
        return "air"
    end
    
    return nil
end

-- Function to update elemental indicators on main icon
function TotemNesia.UpdateElementalIndicators()
    -- Hide all indicators first
    for _, icon in pairs(TotemNesia.elementalIcons) do
        icon:Hide()
    end
    
    -- Track which elements have totems
    local activeElements = {
        fire = nil,
        water = nil,
        earth = nil,
        air = nil
    }
    
    -- Check each active totem
    for totemName, _ in pairs(TotemNesia.activeTotems) do
        local element = GetTotemElement(totemName)
        if element and not activeElements[element] then
            activeElements[element] = totemName
        end
    end
    
    -- Show indicators for active elements
    for element, totemName in pairs(activeElements) do
        if totemName then
            local icon = TotemNesia.elementalIcons[element]
            local texture = GetTotemIcon(totemName)
            icon.texture:SetTexture(texture)
            icon:Show()
        end
    end
end

-- ============================================================================
-- TOTEM BAR (Quick-cast 4-slot bar)
-- ============================================================================

-- Totem lists for Totem Bar (organized by element)
TotemNesia.totemLists = {
    fire = {
        "Searing Totem",
        "Fire Nova Totem",
        "Magma Totem",
        "Frost Resistance Totem",
        "Flametongue Totem"
        -- Totem of Wrath removed (doesn't exist on Turtle WoW)
    },
    earth = {
        "Stoneclaw Totem",
        "Stoneskin Totem",
        "Earthbind Totem",
        "Strength of Earth Totem",
        "Tremor Totem"
    },
    water = {
        "Healing Stream Totem",
        "Mana Spring Totem",
        "Frost Resistance Totem",
        "Disease Cleansing Totem",
        "Poison Cleansing Totem"
        -- Mana Tide Totem removed (doesn't exist on Turtle WoW)
    },
    air = {
        "Grounding Totem",
        "Windfury Totem",
        "Grace of Air Totem",
        "Nature Resistance Totem",
        "Tranquil Air Totem",
        "Windwall Totem"
    },
    weapon = {
        "Rockbiter Weapon",
        "Flametongue Weapon",
        "Frostbrand Weapon",
        "Windfury Weapon"
    }
}

-- Totem Bar slot data (initialize before creating slots)
TotemNesia.totemBarSlots = {}
TotemNesia.totemBarTimers = {}

-- Create Totem Bar frame
local totemBar = CreateFrame("Frame", "TotemNesiaTotemBar", UIParent)
totemBar:SetWidth(100)  -- 4 slots @ 24px + spacing
totemBar:SetHeight(28)
totemBar:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
totemBar:SetMovable(true)
totemBar:SetUserPlaced(true)
totemBar:SetFrameStrata("MEDIUM")
totemBar:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
totemBar:SetBackdropColor(0, 0, 0, 0.75)
totemBar:Hide()  -- Hidden by default until enabled

-- Make Totem Bar draggable when unlocked
totemBar:RegisterForDrag("LeftButton")
totemBar:SetScript("OnDragStart", function()
    if not TotemNesiaDB.totemBarLocked then
        this:StartMoving()
    end
end)
totemBar:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
end)

-- Create 5 element slots (Fire, Earth, Water, Air, Weapon)
local elementOrder = {"fire", "earth", "water", "air", "weapon"}
local slotSize = 24
local slotSpacing = 1

for i, element in ipairs(elementOrder) do
    local slot = CreateFrame("Button", "TotemNesiaTotemBarSlot_"..element, totemBar)
    slot:SetWidth(slotSize)
    slot:SetHeight(slotSize)
    slot:SetPoint("LEFT", totemBar, "LEFT", 4 + ((i-1) * (slotSize + slotSpacing)), 0)
    
    -- Slot background
    slot:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 1,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    slot:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    slot:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    -- Totem icon texture
    local iconTexture = slot:CreateTexture(nil, "ARTWORK")
    iconTexture:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
    iconTexture:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
    iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    slot.iconTexture = iconTexture
    
    -- Timer text
    local timerText = slot:CreateFontString(nil, "OVERLAY")
    timerText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    timerText:SetPoint("BOTTOM", slot, "BOTTOM", 0, 0)
    timerText:SetTextColor(1, 1, 1)
    slot.timerText = timerText
    
    -- Element identifier
    slot.element = element
    
    -- Enable mouse interaction for dragging
    slot:EnableMouse(true)
    
    -- Store slot reference
    TotemNesia.totemBarSlots[element] = slot
    
    -- Create flyout menu for this slot (hidden by default)
    local flyout = CreateFrame("Frame", "TotemNesiaFlyout_"..element, slot)
    flyout:SetFrameStrata("DIALOG")
    flyout:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    flyout:SetBackdropColor(0, 0, 0, 0.95)
    flyout:SetPoint("BOTTOM", slot, "TOP", 0, 2)
    flyout:Hide()
    slot.flyout = flyout
    slot.element = element
    
    -- Populate flyout with totem icons in a single line
    local totems = TotemNesia.totemLists[element]
    
    -- Create buttons for ALL totems (will hide unlearned ones later)
    local numTotems = table.getn(totems)
    
    local iconSize = 24
    local iconSpacing = 2
    
    -- Flyout will be resized dynamically based on direction
    -- For now, set it for horizontal (will be updated by UpdateTotemBarFlyouts)
    flyout:SetWidth((numTotems * iconSize) + ((numTotems + 1) * iconSpacing))
    flyout:SetHeight(iconSize + (2 * iconSpacing))
    
    for j, totemName in ipairs(totems) do
        local button = CreateFrame("Button", nil, flyout)
        button:SetWidth(iconSize)
        button:SetHeight(iconSize)
        -- Position horizontally for now (will be repositioned by UpdateTotemBarFlyouts)
        button:SetPoint("LEFT", flyout, "LEFT", iconSpacing + ((j - 1) * (iconSize + iconSpacing)), 0)
        
        -- Button background
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            tileSize = 1,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        button:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        button:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        
        -- Totem icon
        local btnIcon = button:CreateTexture(nil, "ARTWORK")
        btnIcon:SetAllPoints(button)
        btnIcon:SetTexture(GetTotemIcon(totemName))
        btnIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        
        button.totemName = totemName
        button.element = element  -- Store element for use in OnClick
        button.iconTexture = btnIcon  -- Store reference to icon texture for refreshing
        
        -- Tooltip on hover
        button:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            local highestId = GetHighestLearnedRank(this.totemName)
            if highestId then
                GameTooltip:SetSpell(highestId, BOOKTYPE_SPELL)
                GameTooltip:Show()
                this:SetBackdropBorderColor(1, 1, 0, 1)
            else
                -- Fallback if spell not found in book
                GameTooltip:SetText(this.totemName, 1, 1, 1)
                GameTooltip:Show()
                this:SetBackdropBorderColor(1, 1, 0, 1)
            end
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
            this:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end)
        
        -- Click handling
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnClick", function()
            if IsControlKeyDown() and this.element ~= "weapon" then
                -- Ctrl-click: Set as default totem for this slot (not for weapon enchants)
                local elem = this.element
                TotemNesiaDB.totemBarSlots[elem] = this.totemName
                local slotBtn = TotemNesia.totemBarSlots[elem]
                if slotBtn then
                    slotBtn.iconTexture:SetTexture(GetTotemIcon(this.totemName))
                    slotBtn.iconTexture:SetAlpha(1)
                    slotBtn.selectedTotem = this.totemName
                    TotemNesia.DebugPrint(this.totemName .. " set to " .. elem .. " slot")
                end
                flyout.hideTime = nil
                flyout:Hide()
            else
                -- Normal click: Cast totem/enchant
                CastSpellByName(this.totemName)
                
                -- If this is a weapon enchant, track which one was clicked
                if this.element == "weapon" then
                    TotemNesia.clickedWeaponEnchant = this.totemName
                    TotemNesia.DebugPrint("Weapon enchant clicked: " .. this.totemName)
                end
                
                flyout.hideTime = nil
                flyout:Hide()
            end
        end)
    end
    
    -- Slot mouse events for flyout
    slot:SetScript("OnEnter", function()
        -- Require shift key unless disabled in settings
        if not TotemNesiaDB.shiftToOpenFlyouts and not IsShiftKeyDown() then
            return
        end
        
        -- Only show flyout if there are visible (learned) totems
        local children = {this.flyout:GetChildren()}
        local hasVisibleButtons = false
        for _, child in ipairs(children) do
            if child:IsShown() then
                hasVisibleButtons = true
                break
            end
        end
        
        if hasVisibleButtons then
            this.flyout:Show()
            this.flyout.hideTime = nil  -- Cancel any pending hide
        end
    end)
    
    slot:SetScript("OnLeave", function()
        -- Start 1 second timer before hiding
        this.flyout.hideTime = GetTime() + 1
    end)
    
    -- Keep flyout open when mouse is over it
    flyout:SetScript("OnEnter", function()
        this:Show()
        this.hideTime = nil  -- Cancel any pending hide
    end)
    
    flyout:SetScript("OnLeave", function()
        -- Start 1 second timer before hiding
        this.hideTime = GetTime() + 1
    end)
    
    -- Update handler that always runs to check hide timer
    flyout:SetScript("OnUpdate", function(elapsed)
        -- Always check if we should hide, regardless of timer
        local shouldBeVisible = MouseIsOver(flyout) or MouseIsOver(slot)
        
        if this.hideTime then
            local timeNow = GetTime()
            if timeNow >= this.hideTime then
                -- Timer expired - hide if mouse not over slot or flyout
                if not shouldBeVisible then
                    this:Hide()
                    this.hideTime = nil
                else
                    -- Mouse is still over something, keep it open
                    this.hideTime = nil
                end
            end
        else
            -- No timer, but if mouse isn't over anything, start hiding timer
            if this:IsVisible() and not shouldBeVisible then
                this.hideTime = GetTime() + 1
            end
        end
    end)
    
    -- Slot click to cast selected totem (skip for weapon slot - it's display-only)
    if element ~= "weapon" then
        slot:RegisterForClicks("LeftButtonUp")
        slot:SetScript("OnClick", function()
            if this.selectedTotem then
                CastSpellByName(this.selectedTotem)
            end
        end)
    end
    
    -- Make slot draggable and propagate to parent totemBar
    slot:RegisterForDrag("LeftButton")
    slot:SetScript("OnDragStart", function()
        if not TotemNesiaDB.totemBarLocked then
            totemBar:StartMoving()
        end
    end)
    slot:SetScript("OnDragStop", function()
        totemBar:StopMovingOrSizing()
    end)
end

-- Function to check if player is too far from totems
function TotemNesia.CheckTotemDistance()
    if not TotemNesia.hasTotems then
        return false
    end
    
    local px, py = GetPlayerMapPosition("player")
    if not px or not py or (px == 0 and py == 0) then
        return false -- Can't determine position
    end
    
    for totemName, _ in pairs(TotemNesia.activeTotems) do
        local pos = TotemNesia.totemPositions[totemName]
        if pos then
            -- Calculate distance in yards (approximate)
            -- Map coordinates are 0-1, so we convert to yards
            -- Assuming average zone is ~1000 yards across
            local dx = (px - pos.x) * 1000
            local dy = (py - pos.y) * 1000
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance > TOTEM_DISTANCE_THRESHOLD then
                return true -- Player is too far from at least one totem
            end
        end
    end
    
    return false
end

-- Function to check if player has Totemic Recall spell and is high enough level
function TotemNesia.CanUseTotemicRecall()
    -- Check level requirement
    if UnitLevel("player") < 10 then
        return false
    end
    
    -- Check if player has Totemic Recall spell
    local i = 1
    while true do
        local spellName = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then break end
        if spellName == "Totemic Recall" then
            return true
        end
        i = i + 1
    end
    
    return false
end

-- Function to update Totem Bar display and timers
function TotemNesia.UpdateTotemBar()
    if not TotemNesiaDB.totemBarEnabled or TotemNesiaDB.totemBarHidden then
        totemBar:Hide()
        return
    end
    
    totemBar:Show()
    
    -- Apply layout (Horizontal or Vertical)
    local isVertical = (TotemNesiaDB.totemBarLayout == "Vertical")
    local slotSize = 24
    local slotSpacing = 1
    local elementOrder = {"fire", "earth", "water", "air", "weapon"}
    
    -- Count visible slots
    local visibleSlots = TotemNesiaDB.hideWeaponSlot and 4 or 5
    
    if isVertical then
        -- Vertical layout
        totemBar:SetWidth(slotSize + 8)
        totemBar:SetHeight((visibleSlots * slotSize) + ((visibleSlots - 1) * slotSpacing) + 8)
        
        local visibleIndex = 0
        for i, element in ipairs(elementOrder) do
            local slot = TotemNesia.totemBarSlots[element]
            if slot then
                -- Hide weapon slot if setting is enabled
                if element == "weapon" and TotemNesiaDB.hideWeaponSlot then
                    slot:Hide()
                else
                    slot:Show()
                    slot:ClearAllPoints()
                    slot:SetPoint("TOP", totemBar, "TOP", 0, -4 - (visibleIndex * (slotSize + slotSpacing)))
                    visibleIndex = visibleIndex + 1
                end
            end
        end
    else
        -- Horizontal layout
        totemBar:SetWidth((visibleSlots * slotSize) + ((visibleSlots - 1) * slotSpacing) + 8)
        totemBar:SetHeight(slotSize + 8)
        
        local visibleIndex = 0
        for i, element in ipairs(elementOrder) do
            local slot = TotemNesia.totemBarSlots[element]
            if slot then
                -- Hide weapon slot if setting is enabled
                if element == "weapon" and TotemNesiaDB.hideWeaponSlot then
                    slot:Hide()
                else
                    slot:Show()
                    slot:ClearAllPoints()
                    slot:SetPoint("LEFT", totemBar, "LEFT", 4 + (visibleIndex * (slotSize + slotSpacing)), 0)
                    visibleIndex = visibleIndex + 1
                end
            end
        end
    end
    
    -- Update each slot
    for element, slot in pairs(TotemNesia.totemBarSlots) do
        -- Handle weapon slot specially - show active enchant icon
        if element == "weapon" then
            -- Show icon for clicked weapon enchant if timer is active
            if TotemNesia.weaponEnchantTime > 0 and TotemNesia.weaponEnchantExpiry and TotemNesia.clickedWeaponEnchant then
                local enchantIcon = GetTotemIcon(TotemNesia.clickedWeaponEnchant)
                if not TotemNesia.lastWeaponIconState or TotemNesia.lastWeaponIconState ~= TotemNesia.clickedWeaponEnchant then
                    TotemNesia.DebugPrint("Setting weapon icon to: " .. TotemNesia.clickedWeaponEnchant .. " (" .. tostring(enchantIcon) .. ")")
                    TotemNesia.lastWeaponIconState = TotemNesia.clickedWeaponEnchant
                end
                slot.iconTexture:SetTexture(enchantIcon)
                slot.iconTexture:SetAlpha(1)
            else
                -- No active enchant, clear icon
                if TotemNesia.lastWeaponIconState then
                    TotemNesia.DebugPrint("Clearing weapon icon - Time:" .. tostring(TotemNesia.weaponEnchantTime) .. " Expiry:" .. tostring(TotemNesia.weaponEnchantExpiry) .. " Clicked:" .. tostring(TotemNesia.clickedWeaponEnchant))
                    TotemNesia.lastWeaponIconState = nil
                end
                slot.iconTexture:SetTexture(nil)
                slot.iconTexture:SetAlpha(0)
            end
            
            -- Update timer
            if TotemNesia.weaponEnchantTime > 0 and TotemNesia.weaponEnchantExpiry then
                local remaining = TotemNesia.weaponEnchantExpiry - GetTime()
                if remaining > 0 then
                    if remaining >= 60 then
                        local mins = math.floor(remaining / 60)
                        slot.timerText:SetText(mins .. "m")
                    else
                        slot.timerText:SetText(math.ceil(remaining))
                    end
                else
                    slot.timerText:SetText("")
                    TotemNesia.weaponEnchantTime = 0
                    TotemNesia.weaponEnchantExpiry = nil
                    TotemNesia.clickedWeaponEnchant = nil
                end
            else
                slot.timerText:SetText("")
            end
        else
            -- Restore saved totem selection for non-weapon slots
            local savedTotem = TotemNesiaDB.totemBarSlots[element]
            if savedTotem and not slot.selectedTotem then
                slot.selectedTotem = savedTotem
                slot.iconTexture:SetTexture(GetTotemIcon(savedTotem))
                slot.iconTexture:SetAlpha(1)
            end
            
            -- Update timer if this totem type is active
            local hasActiveTotem = false
            for totemName, _ in pairs(TotemNesia.activeTotems) do
                if GetTotemElement(totemName) == element then
                    hasActiveTotem = true
                    local timestamp = TotemNesia.totemTimestamps[totemName]
                    if timestamp then
                        local elapsed = GetTime() - timestamp
                        local duration = GetTotemDuration(totemName)
                        local remaining = duration - elapsed
                        if remaining > 0 then
                            slot.timerText:SetText(math.ceil(remaining))
                        else
                            slot.timerText:SetText("")
                        end
                    end
                    break
                end
            end
            
            if not hasActiveTotem then
                slot.timerText:SetText("")
            end
        end
    end
end

-- Function to update flyout directions
function TotemNesia.UpdateTotemBarFlyouts()
    local direction = TotemNesiaDB.totemBarFlyoutDirection
    local iconSize = 24
    local iconSpacing = 2
    
    if TotemNesiaDB.debugMode then
        TotemNesia.DebugPrint("UpdateTotemBarFlyouts called, direction = " .. tostring(direction))
    end
    
    for element, slot in pairs(TotemNesia.totemBarSlots) do
        local flyout = slot.flyout
        if flyout then
            local totems = TotemNesia.totemLists[element]
            
            -- Filter to only count learned totems
            local learnedCount = 0
            for _, totemName in ipairs(totems) do
                if IsTotemLearned(totemName) then
                    learnedCount = learnedCount + 1
                end
            end
            local numTotems = learnedCount
            
            -- Get all child buttons
            local buttons = {}
            local children = {flyout:GetChildren()}
            for _, child in ipairs(children) do
                table.insert(buttons, child)
            end
            
            -- Reposition flyout relative to slot
            flyout:ClearAllPoints()
            
            if direction == "Up" or direction == "Down" then
                -- Vertical flyout layout (icons stacked vertically)
                flyout:SetWidth(iconSize + (2 * iconSpacing))
                flyout:SetHeight((numTotems * iconSize) + ((numTotems + 1) * iconSpacing))
                
                -- Position buttons vertically
                for i, button in ipairs(buttons) do
                    button:ClearAllPoints()
                    button:SetPoint("TOP", flyout, "TOP", 0, -(iconSpacing + ((i - 1) * (iconSize + iconSpacing))))
                end
                
                if direction == "Up" then
                    flyout:SetPoint("BOTTOM", slot, "TOP", 0, 2)
                else
                    flyout:SetPoint("TOP", slot, "BOTTOM", 0, -2)
                end
            else
                -- Horizontal flyout layout (icons side by side)
                flyout:SetWidth((numTotems * iconSize) + ((numTotems + 1) * iconSpacing))
                flyout:SetHeight(iconSize + (2 * iconSpacing))
                
                -- Position buttons horizontally
                for i, button in ipairs(buttons) do
                    button:ClearAllPoints()
                    button:SetPoint("LEFT", flyout, "LEFT", iconSpacing + ((i - 1) * (iconSize + iconSpacing)), 0)
                end
                
                if direction == "Left" then
                    flyout:SetPoint("RIGHT", slot, "LEFT", -2, 0)
                else
                    flyout:SetPoint("LEFT", slot, "RIGHT", 2, 0)
                end
            end
        end
    end
end

-- Create totem tracker bar
local totemTracker = CreateFrame("Frame", "TotemNesiaTotemTracker", UIParent)
totemTracker:SetWidth(400)
totemTracker:SetHeight(24)
totemTracker:SetPoint("CENTER", UIParent, "BOTTOM", 0, 100)
totemTracker:SetMovable(true)
totemTracker:SetUserPlaced(true)
totemTracker:SetFrameStrata("MEDIUM")
totemTracker:Hide()

-- Make Totem Tracker draggable when unlocked
totemTracker:RegisterForDrag("LeftButton")
totemTracker:SetScript("OnDragStart", function()
    if not TotemNesiaDB.totemTrackerLocked then
        this:StartMoving()
    end
end)
totemTracker:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
end)

-- Totem Tracker icons storage
TotemNesia.totemTrackerIcons = {}

-- Function to refresh flyout menu icons (called after login to ensure spellbook is loaded)
function TotemNesia.RefreshFlyoutIcons()
    local iconSize = 24
    local iconSpacing = 2
    local direction = TotemNesiaDB.totemBarFlyoutDirection or "Up"
    
    for element, slot in pairs(TotemNesia.totemBarSlots) do
        if slot.flyout then
            -- Get all child buttons from the flyout
            local children = {slot.flyout:GetChildren()}
            local visibleButtons = {}
            
            for _, child in ipairs(children) do
                if child.totemName and child.iconTexture then
                    -- Refresh the icon texture from spellbook
                    local iconPath = GetTotemIcon(child.totemName)
                    child.iconTexture:SetTexture(iconPath)
                    
                    -- Hide button if totem is not learned, show if learned
                    if IsTotemLearned(child.totemName) then
                        child:Show()
                        table.insert(visibleButtons, child)
                    else
                        child:Hide()
                    end
                end
            end
            
            local visibleCount = table.getn(visibleButtons)
            
            -- Reposition only visible buttons based on direction
            if direction == "Up" or direction == "Down" then
                -- Vertical layout
                slot.flyout:SetWidth(iconSize + (2 * iconSpacing))
                slot.flyout:SetHeight((visibleCount * iconSize) + ((visibleCount + 1) * iconSpacing))
                
                for i, button in ipairs(visibleButtons) do
                    button:ClearAllPoints()
                    button:SetPoint("TOP", slot.flyout, "TOP", 0, -(iconSpacing + ((i - 1) * (iconSize + iconSpacing))))
                end
            else
                -- Horizontal layout (Left or Right)
                slot.flyout:SetWidth((visibleCount * iconSize) + ((visibleCount + 1) * iconSpacing))
                slot.flyout:SetHeight(iconSize + (2 * iconSpacing))
                
                for i, button in ipairs(visibleButtons) do
                    button:ClearAllPoints()
                    button:SetPoint("LEFT", slot.flyout, "LEFT", iconSpacing + ((i - 1) * (iconSize + iconSpacing)), 0)
                end
            end
        end
    end
end

-- Function to update Totem Tracker display
function TotemNesia.UpdateTotemTracker()
    -- Clear existing icons
    for _, icon in pairs(TotemNesia.totemTrackerIcons) do
        icon:Hide()
    end
    
    -- Check for expired totems and remove them
    local currentTime = GetTime()
    for totemName, timestamp in pairs(TotemNesia.totemTimestamps) do
        local duration = GetTotemDuration(totemName)
        local elapsed = currentTime - timestamp
        if elapsed >= duration then
            -- Totem has expired
            TotemNesia.activeTotems[totemName] = nil
            TotemNesia.totemTimestamps[totemName] = nil
            TotemNesia.DebugPrint("Totem expired: " .. totemName)
        end
    end
    
    -- Check if any totems left
    local anyActive = false
    for _ in pairs(TotemNesia.activeTotems) do
        anyActive = true
        break
    end
    if not anyActive then
        TotemNesia.hasTotems = false
    end
    
    -- Count active totems
    local activeCount = 0
    for _ in pairs(TotemNesia.activeTotems) do
        activeCount = activeCount + 1
    end
    
    if activeCount == 0 or TotemNesiaDB.totemTrackerHidden then
        totemTracker:Hide()
        return
    end
    
    -- Create/update icons for active totems only
    local iconSize = 20
    local iconSpacing = 1
    local isVertical = (TotemNesiaDB.totemTrackerLayout == "Vertical")
    
    if isVertical then
        local totalHeight = (activeCount * iconSize) + ((activeCount - 1) * iconSpacing)
        totemTracker:SetWidth(iconSize + 8)
        totemTracker:SetHeight(totalHeight + 8)
    else
        local totalWidth = (activeCount * iconSize) + ((activeCount - 1) * iconSpacing)
        totemTracker:SetWidth(totalWidth + 8)
        totemTracker:SetHeight(iconSize + 8)
    end
    
    totemTracker:Show()
    
    local index = 0
    for totemName, _ in pairs(TotemNesia.activeTotems) do
        local icon = TotemNesia.totemTrackerIcons[totemName]
        
        if not icon then
            icon = CreateFrame("Frame", nil, totemTracker)
            icon:SetWidth(iconSize)
            icon:SetHeight(iconSize)
            
            local texture = icon:CreateTexture(nil, "ARTWORK")
            texture:SetAllPoints(icon)
            icon.texture = texture
            
            -- Add timer text
            local timerText = icon:CreateFontString(nil, "OVERLAY")
            timerText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            timerText:SetPoint("BOTTOM", icon, "BOTTOM", 0, 0)
            timerText:SetTextColor(1, 1, 1)
            icon.timerText = timerText
            
            TotemNesia.totemTrackerIcons[totemName] = icon
        end
        
        -- ALWAYS refresh the texture (fixes blank icons if spellbook wasn't loaded initially)
        if icon.texture then
            local totemTexture = GetTotemIcon(totemName)
            if totemTexture then
                icon.texture:SetTexture(totemTexture)
            else
                -- Fallback to default icon if texture not found
                icon.texture:SetTexture("Interface\\Icons\\Spell_Nature_Reincarnation")
            end
        end
        
        -- Position based on layout
        icon:ClearAllPoints()
        if isVertical then
            icon:SetPoint("TOP", totemTracker, "TOP", 0, -4 - (index * (iconSize + iconSpacing)))
        else
            icon:SetPoint("LEFT", totemTracker, "LEFT", 4 + (index * (iconSize + iconSpacing)), 0)
        end
        icon:Show()
        
        -- Always full color since we're only showing active totems
        icon.texture:SetVertexColor(1, 1, 1)
        icon.totemName = totemName
        
        -- Update timer
        local timestamp = TotemNesia.totemTimestamps[totemName]
        if timestamp then
            local elapsed = GetTime() - timestamp
            local duration = GetTotemDuration(totemName)
            local remaining = duration - elapsed
            if remaining > 0 then
                icon.timerText:SetText(math.ceil(remaining))
            else
                icon.timerText:SetText("0")
            end
        else
            icon.timerText:SetText("")
        end
        
        index = index + 1
    end
end

-- Update Totem Tracker when totems change
local totemUpdateFrame = CreateFrame("Frame")
totemUpdateFrame.timeSinceUpdate = 0
totemUpdateFrame:SetScript("OnUpdate", function()
    this.timeSinceUpdate = this.timeSinceUpdate + arg1
    if this.timeSinceUpdate >= 0.5 then
        -- Check for weapon enchants
        local hasMainHandEnchant, mainHandExpiration = GetWeaponEnchantInfo()
        if hasMainHandEnchant and mainHandExpiration then
            -- Convert milliseconds to seconds and record when it will expire
            local expirationSeconds = mainHandExpiration / 1000
            local currentTime = GetTime()
            -- If we don't have a start time, or enchant changed, record new start
            if TotemNesia.weaponEnchantTime == 0 or (TotemNesia.weaponEnchantExpiry and math.abs(TotemNesia.weaponEnchantExpiry - (currentTime + expirationSeconds)) > 5) then
                TotemNesia.weaponEnchantTime = currentTime
                TotemNesia.weaponEnchantExpiry = currentTime + expirationSeconds
                TotemNesia.DebugPrint("Weapon enchant detected, expires in " .. math.floor(expirationSeconds) .. " seconds")
            end
        else
            -- No enchant, clear timer
            if TotemNesia.weaponEnchantTime > 0 then
                TotemNesia.DebugPrint("Weapon enchant expired")
            end
            TotemNesia.weaponEnchantTime = 0
            TotemNesia.weaponEnchantExpiry = nil
        end
        
        TotemNesia.UpdateTotemTracker()
        TotemNesia.UpdateElementalIndicators()
        TotemNesia.UpdateTotemBar()
        this.timeSinceUpdate = 0
    end
end)

-- Minimap button
local minimapButton = CreateFrame("Button", "TotemNesiaMinimapButton", Minimap)
minimapButton:SetWidth(31)
minimapButton:SetHeight(31)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- Button icon
local minimapIcon = minimapButton:CreateTexture(nil, "BACKGROUND")
minimapIcon:SetWidth(20)
minimapIcon:SetHeight(20)
minimapIcon:SetPoint("CENTER", 0, 1)
minimapIcon:SetTexture("Interface\\Icons\\Spell_Nature_Reincarnation")

-- Button border
local minimapBorder = minimapButton:CreateTexture(nil, "OVERLAY")
minimapBorder:SetWidth(52)
minimapBorder:SetHeight(52)
minimapBorder:SetPoint("TOPLEFT", 0, 0)
minimapBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

-- Create options menu frame
local optionsMenu = CreateFrame("Frame", "TotemNesiaOptionsMenu", UIParent)
optionsMenu:SetWidth(400)
optionsMenu:SetHeight(400)  -- 20% shorter (was 500)
optionsMenu:SetPoint("CENTER", UIParent, "CENTER")
optionsMenu:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
optionsMenu:SetBackdropColor(0, 0, 0, 0.9)
optionsMenu:SetFrameStrata("DIALOG")
optionsMenu:EnableMouse(true)
optionsMenu:SetMovable(true)
optionsMenu:RegisterForDrag("LeftButton")
optionsMenu:SetScript("OnDragStart", function() this:StartMoving() end)
optionsMenu:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
optionsMenu:Hide()

-- Make options menu close with ESC key
table.insert(UISpecialFrames, "TotemNesiaOptionsMenu")

-- Options menu title
local menuTitle = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
menuTitle:SetPoint("TOP", 0, -15)
menuTitle:SetText("TotemNesia V3.0")
menuTitle:SetTextColor(1, 0.82, 0, 1)  -- Yellow color

-- Author credit (smaller text below title)
local authorText = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
authorText:SetPoint("TOP", menuTitle, "BOTTOM", 0, -2)
authorText:SetText("By Fayz of Nordanaar")
authorText:SetTextColor(1, 1, 1, 1)  -- White color

-- Close button (X in upper right)
local closeButton = CreateFrame("Button", nil, optionsMenu)
closeButton:SetWidth(32)
closeButton:SetHeight(32)
closeButton:SetPoint("TOPRIGHT", -10, -5)  -- Aligned with scrollbar right edge

-- Use the standard UI close button textures
closeButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
closeButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
closeButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")

closeButton:SetScript("OnClick", function()
    optionsMenu:Hide()
end)

-- Content frames
local settingsContent = CreateFrame("ScrollFrame", nil, optionsMenu)
settingsContent:SetPoint("TOPLEFT", 10, -30)  -- Reduced to -30 for 30px spacing from author text
settingsContent:SetPoint("BOTTOMRIGHT", -30, 40)  -- Leave room for scrollbar on right

-- Create scroll child (this is where all settings will go)
local settingsScrollChild = CreateFrame("Frame", nil, settingsContent)
settingsScrollChild:SetWidth(360)  -- Reduced to leave room for scrollbar
settingsScrollChild:SetHeight(480)  -- 20% shorter than 600px
settingsContent:SetScrollChild(settingsScrollChild)

-- Create scrollbar BEFORE setting up mouse wheel (so it exists when referenced)
local settingsScrollbar = CreateFrame("Slider", nil, optionsMenu)
settingsScrollbar:SetPoint("TOPRIGHT", optionsMenu, "TOPRIGHT", -10, -40)  -- Start below close X (which ends at -37)
settingsScrollbar:SetPoint("BOTTOMRIGHT", optionsMenu, "BOTTOMRIGHT", -10, 40)  -- Aligned with content bottom
settingsScrollbar:SetWidth(16)
settingsScrollbar:SetOrientation("VERTICAL")
settingsScrollbar:SetMinMaxValues(0, 1)
settingsScrollbar:SetValueStep(0.01)
settingsScrollbar:SetValue(0)
settingsScrollbar:EnableMouse(true)

-- Scrollbar background
settingsScrollbar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false,
    tileSize = 1,
    edgeSize = 2,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
settingsScrollbar:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
settingsScrollbar:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

-- Scrollbar thumb
local scrollbarThumb = settingsScrollbar:CreateTexture(nil, "OVERLAY")
scrollbarThumb:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
scrollbarThumb:SetWidth(16)
scrollbarThumb:SetHeight(24)
settingsScrollbar:SetThumbTexture(scrollbarThumb)

-- Flag to prevent circular updates
local updatingScrollbar = false

-- Enable mouse wheel scrolling (NOW scrollbar exists)
settingsContent:EnableMouseWheel(true)
settingsContent:SetScript("OnMouseWheel", function()
    local current = this:GetVerticalScroll()
    local maxScroll = this:GetVerticalScrollRange()
    if arg1 > 0 then
        -- Scroll up
        this:SetVerticalScroll(math.max(0, current - 20))
    else
        -- Scroll down
        this:SetVerticalScroll(math.min(maxScroll, current + 20))
    end
    -- Update scrollbar position with NEW scroll value
    if not updatingScrollbar then
        updatingScrollbar = true
        local newScroll = this:GetVerticalScroll()
        if maxScroll > 0 then
            settingsScrollbar:SetValue(newScroll / maxScroll)
        else
            settingsScrollbar:SetValue(0)
        end
        updatingScrollbar = false
    end
end)

-- Scrollbar OnValueChanged script
settingsScrollbar:SetScript("OnValueChanged", function()
    if not updatingScrollbar then
        updatingScrollbar = true
        local value = this:GetValue()
        local maxScroll = settingsContent:GetVerticalScrollRange()
        settingsContent:SetVerticalScroll(value * maxScroll)
        updatingScrollbar = false
    end
end)

-- Make scrollbar visible
settingsScrollbar:SetFrameLevel(optionsMenu:GetFrameLevel() + 2)
settingsScrollbar:Show()

settingsContent:Show()

local totemSetsContent = CreateFrame("Frame", nil, optionsMenu)
totemSetsContent:SetAllPoints(optionsMenu)
totemSetsContent:Hide()

local manaContent = CreateFrame("Frame", nil, optionsMenu)
manaContent:SetAllPoints(optionsMenu)
manaContent:Hide()

-- Create fireButtons table BEFORE tabs (so it exists when tabs reference it)
local fireButtons = {}
local earthButtons = {}
local waterButtons = {}
local airButtons = {}

-- Define UpdateFireBorders BEFORE tabs (so they can call it)
local function UpdateFireBorders()
    if not TotemNesiaDB or not TotemNesiaDB.currentTotemSet or not TotemNesiaDB.totemSets then
        return
    end
    local currentSet = TotemNesiaDB.currentTotemSet
    if not TotemNesiaDB.totemSets[currentSet] then
        return
    end
    local selectedTotem = TotemNesiaDB.totemSets[currentSet].fire
    for _, btn in ipairs(fireButtons) do
        if btn.totemName == selectedTotem then
            btn.borderOverlay:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false, tileSize = 1, edgeSize = 2,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            })
            btn.borderOverlay:SetBackdropBorderColor(1, 0.82, 0, 1)
        else
            btn.borderOverlay:SetBackdrop(nil)
        end
    end
end

-- Update Earth borders function
local function UpdateEarthBorders()
    if not TotemNesiaDB or not TotemNesiaDB.currentTotemSet or not TotemNesiaDB.totemSets then
        return
    end
    local currentSet = TotemNesiaDB.currentTotemSet
    local selectedTotem = TotemNesiaDB.totemSets[currentSet].earth
    for _, btn in ipairs(earthButtons) do
        if btn.totemName == selectedTotem then
            btn.borderOverlay:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false, tileSize = 1, edgeSize = 2,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            })
            btn.borderOverlay:SetBackdropBorderColor(1, 0.82, 0, 1)
        else
            btn.borderOverlay:SetBackdrop(nil)
        end
    end
end

-- Update Water borders function
local function UpdateWaterBorders()
    if not TotemNesiaDB or not TotemNesiaDB.currentTotemSet or not TotemNesiaDB.totemSets then
        return
    end
    local currentSet = TotemNesiaDB.currentTotemSet
    local selectedTotem = TotemNesiaDB.totemSets[currentSet].water
    for _, btn in ipairs(waterButtons) do
        if btn.totemName == selectedTotem then
            btn.borderOverlay:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false, tileSize = 1, edgeSize = 2,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            })
            btn.borderOverlay:SetBackdropBorderColor(1, 0.82, 0, 1)
        else
            btn.borderOverlay:SetBackdrop(nil)
        end
    end
end

-- Update Air borders function
local function UpdateAirBorders()
    if not TotemNesiaDB or not TotemNesiaDB.currentTotemSet or not TotemNesiaDB.totemSets then
        return
    end
    local currentSet = TotemNesiaDB.currentTotemSet
    local selectedTotem = TotemNesiaDB.totemSets[currentSet].air
    for _, btn in ipairs(airButtons) do
        if btn.totemName == selectedTotem then
            btn.borderOverlay:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false, tileSize = 1, edgeSize = 2,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            })
            btn.borderOverlay:SetBackdropBorderColor(1, 0.82, 0, 1)
        else
            btn.borderOverlay:SetBackdrop(nil)
        end
    end
end

-- Simple tab buttons
local settingsTab = CreateFrame("Button", nil, optionsMenu)
settingsTab:SetWidth(100)
settingsTab:SetHeight(32)
settingsTab:SetPoint("TOPLEFT", optionsMenu, "BOTTOMLEFT", 10, 7)
settingsTab:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
settingsTab:SetHighlightTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")

local settingsTabText = settingsTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
settingsTabText:SetPoint("CENTER", 0, 2)
settingsTabText:SetText("Settings")

local totemSetsTab = CreateFrame("Button", nil, optionsMenu)
totemSetsTab:SetWidth(100)
totemSetsTab:SetHeight(32)
totemSetsTab:SetPoint("LEFT", settingsTab, "RIGHT", -15, 0)
totemSetsTab:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab")
totemSetsTab:SetHighlightTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")

local totemSetsTabText = totemSetsTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
totemSetsTabText:SetPoint("CENTER", 0, 2)
totemSetsTabText:SetText("Totem Sets")

local manaTab = CreateFrame("Button", nil, optionsMenu)
manaTab:SetWidth(100)
manaTab:SetHeight(32)
manaTab:SetPoint("LEFT", totemSetsTab, "RIGHT", -15, 0)
manaTab:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab")
manaTab:SetHighlightTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")

local manaTabText = manaTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
manaTabText:SetPoint("CENTER", 0, 2)
manaTabText:SetText("Mana")

-- Tab click handlers
settingsTab:SetScript("OnClick", function()
    settingsContent:SetVerticalScroll(0); settingsScrollbar:SetValue(0)  -- Reset scroll to top
    settingsContent:Show()
    settingsScrollbar:Show()
    totemSetsContent:Hide()
    manaContent:Hide()
    settingsTab:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
    totemSetsTab:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab")
    manaTab:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab")
end)

totemSetsTab:SetScript("OnClick", function()
    settingsContent:Hide()
    settingsScrollbar:Hide()
    totemSetsContent:Show()
    manaContent:Hide()
    settingsTab:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab")
    totemSetsTab:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
    manaTab:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab")
    -- Update all borders when tab is opened
    UpdateFireBorders()
    UpdateEarthBorders()
    UpdateWaterBorders()
    UpdateAirBorders()
end)

manaTab:SetScript("OnClick", function()
    settingsContent:Hide()
    settingsScrollbar:Hide()
    totemSetsContent:Hide()
    manaContent:Show()
    settingsTab:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab")
    totemSetsTab:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab")
    manaTab:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab")
end)

-- TOTEM SETS TAB - Step 1: Instructions and Set Selector
local setsInstructions = totemSetsContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
setsInstructions:SetPoint("TOP", 0, -60)
setsInstructions:SetWidth(380)
setsInstructions:SetJustifyH("CENTER")
setsInstructions:SetText("Click a set, then click totems to assign them.\nKeybinds: ESC > Key Bindings > TotemNesia (5 keybinds)")

-- Set selector label
local setLabel = totemSetsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
setLabel:SetPoint("TOP", 0, -110)
setLabel:SetText("Totem Set:")

-- Set selector buttons (1-5)
local setButtons = {}
for i = 1, 5 do
    local btn = CreateFrame("Button", nil, totemSetsContent, "UIPanelButtonTemplate")
    btn:SetWidth(40)
    btn:SetHeight(28)
    btn:SetPoint("TOP", -110 + (i-1) * 55, -140)
    btn:SetText(tostring(i))
    btn.setNumber = i
    btn:SetScript("OnClick", function()
        TotemNesiaDB.currentTotemSet = this.setNumber
        -- Highlight buttons
        for j = 1, 5 do
            if j == this.setNumber then
                setButtons[j]:LockHighlight()
            else
                setButtons[j]:UnlockHighlight()
            end
        end
        TotemNesia.DebugPrint("Selected Set " .. this.setNumber)
        -- Update all totem family borders
        UpdateFireBorders()
        UpdateEarthBorders()
        UpdateWaterBorders()
        UpdateAirBorders()
    end)
    setButtons[i] = btn
end

-- Highlight the currently selected set from database
if TotemNesiaDB and TotemNesiaDB.currentTotemSet then
    setButtons[TotemNesiaDB.currentTotemSet]:LockHighlight()
else
    setButtons[1]:LockHighlight()
end

-- Fire totem buttons (testBtn, testBtn2-5)
local fireLabel = totemSetsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
fireLabel:SetPoint("TOPLEFT", 20, -190)
fireLabel:SetText("Fire:")

-- Fire Clear Button
local fireClearBtn = CreateFrame("Button", nil, totemSetsContent)
fireClearBtn:SetWidth(20)
fireClearBtn:SetHeight(20)
fireClearBtn:SetPoint("TOPLEFT", 60, -194)
fireClearBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
fireClearBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
fireClearBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
fireClearBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Clear Fire totem assignment")
    GameTooltip:Show()
end)
fireClearBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
fireClearBtn:SetScript("OnClick", function()
    local set = TotemNesiaDB.currentTotemSet
    TotemNesiaDB.totemSets[set].fire = nil
    TotemNesia.DebugPrint("Cleared Set " .. set .. " Fire totem")
    UpdateFireBorders()
end)

-- Fire 1: Searing Totem
local testBtn = CreateFrame("Button", nil, totemSetsContent)
testBtn:SetWidth(28)
testBtn:SetHeight(28)
testBtn:SetPoint("TOPLEFT", 80, -190)

testBtn:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false,
    tileSize = 1,
    edgeSize = 2,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
testBtn:SetBackdropColor(1, 0.3, 0.3, 0.6)
testBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

-- Add Searing Totem icon
local icon = testBtn:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints(testBtn)

icon:SetTexture(GetTotemIcon("Searing Totem"))
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = icon, totemName = "Searing Totem"})

-- Create border overlay frame on top of icon
local borderOverlay = CreateFrame("Frame", nil, testBtn)
borderOverlay:SetAllPoints(testBtn)
borderOverlay:SetFrameLevel(testBtn:GetFrameLevel() + 1)
testBtn.borderOverlay = borderOverlay

testBtn.totemName = "Searing Totem"
table.insert(fireButtons, testBtn)

testBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    local highestId = GetHighestLearnedRank(this.totemName)
    if highestId then
        GameTooltip:SetSpell(highestId, BOOKTYPE_SPELL)
    else
        GameTooltip:SetText(this.totemName)
    end
    GameTooltip:Show()
end)
testBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

testBtn:SetScript("OnClick", function()
    local set = TotemNesiaDB.currentTotemSet
    TotemNesiaDB.totemSets[set].fire = this.totemName
    TotemNesia.DebugPrint("Set " .. set .. " Fire = " .. this.totemName)
    UpdateFireBorders()
end)

-- Add second button: Fire Nova Totem
local testBtn2 = CreateFrame("Button", nil, totemSetsContent)
testBtn2:SetWidth(28)
testBtn2:SetHeight(28)
testBtn2:SetPoint("TOPLEFT", 112, -190)  -- 32 pixels to the right

testBtn2:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false,
    tileSize = 1,
    edgeSize = 2,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
testBtn2:SetBackdropColor(1, 0.3, 0.3, 0.6)
testBtn2:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

local icon2 = testBtn2:CreateTexture(nil, "ARTWORK")
icon2:SetAllPoints(testBtn2)

icon2:SetTexture(GetTotemIcon("Fire Nova Totem"))
icon2:SetTexCoord(0.08, 0.92, 0.08, 0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = icon2, totemName = "Fire Nova Totem"})

-- Create border overlay frame on top of icon
local borderOverlay2 = CreateFrame("Frame", nil, testBtn2)
borderOverlay2:SetAllPoints(testBtn2)
borderOverlay2:SetFrameLevel(testBtn2:GetFrameLevel() + 1)
testBtn2.borderOverlay = borderOverlay2

testBtn2.totemName = "Fire Nova Totem"

table.insert(fireButtons, testBtn2)
testBtn2:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    local highestId = GetHighestLearnedRank(this.totemName)
    if highestId then
        GameTooltip:SetSpell(highestId, BOOKTYPE_SPELL)
    else
        GameTooltip:SetText(this.totemName)
    end
    GameTooltip:Show()
end)
testBtn2:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

testBtn2:SetScript("OnClick", function()
    local set = TotemNesiaDB.currentTotemSet
    TotemNesiaDB.totemSets[set].fire = this.totemName
    TotemNesia.DebugPrint("Set " .. set .. " Fire = " .. this.totemName)
    UpdateFireBorders()
    UpdateFireBorders()
end)

-- Add third button: Magma Totem
local testBtn3 = CreateFrame("Button", nil, totemSetsContent)
testBtn3:SetWidth(28)
testBtn3:SetHeight(28)
testBtn3:SetPoint("TOPLEFT", 144, -190)
testBtn3:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 1, edgeSize = 2,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
testBtn3:SetBackdropColor(1, 0.3, 0.3, 0.6)
testBtn3:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
local icon3 = testBtn3:CreateTexture(nil, "ARTWORK")
icon3:SetAllPoints(testBtn3)

icon3:SetTexture(GetTotemIcon("Magma Totem"))
icon3:SetTexCoord(0.08, 0.92, 0.08, 0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = icon3, totemName = "Magma Totem"})

-- Create border overlay frame on top of icon
local borderOverlay3 = CreateFrame("Frame", nil, testBtn3)
borderOverlay3:SetAllPoints(testBtn3)
borderOverlay3:SetFrameLevel(testBtn3:GetFrameLevel() + 1)
testBtn3.borderOverlay = borderOverlay3

testBtn3.totemName = "Magma Totem"
table.insert(fireButtons, testBtn3)
testBtn3:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    local highestId = GetHighestLearnedRank(this.totemName)
    if highestId then
        GameTooltip:SetSpell(highestId, BOOKTYPE_SPELL)
    else
        GameTooltip:SetText(this.totemName)
    end
    GameTooltip:Show()
end)
testBtn3:SetScript("OnLeave", function() GameTooltip:Hide() end)
testBtn3:SetScript("OnClick", function()
    local set = TotemNesiaDB.currentTotemSet
    TotemNesiaDB.totemSets[set].fire = this.totemName
    TotemNesia.DebugPrint("Set " .. set .. " Fire = " .. this.totemName)
    UpdateFireBorders()
    UpdateFireBorders()
end)

-- Add fourth button: Flametongue Totem
local testBtn4 = CreateFrame("Button", nil, totemSetsContent)
testBtn4:SetWidth(28)
testBtn4:SetHeight(28)
testBtn4:SetPoint("TOPLEFT", 176, -190)
testBtn4:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 1, edgeSize = 2,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
testBtn4:SetBackdropColor(1, 0.3, 0.3, 0.6)
testBtn4:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
local icon4 = testBtn4:CreateTexture(nil, "ARTWORK")
icon4:SetAllPoints(testBtn4)

icon4:SetTexture(GetTotemIcon("Flametongue Totem"))
icon4:SetTexCoord(0.08, 0.92, 0.08, 0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = icon4, totemName = "Flametongue Totem"})

-- Create border overlay frame on top of icon
local borderOverlay4 = CreateFrame("Frame", nil, testBtn4)
borderOverlay4:SetAllPoints(testBtn4)
borderOverlay4:SetFrameLevel(testBtn4:GetFrameLevel() + 1)
testBtn4.borderOverlay = borderOverlay4

testBtn4.totemName = "Flametongue Totem"
table.insert(fireButtons, testBtn4)
testBtn4:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    local highestId = GetHighestLearnedRank(this.totemName)
    if highestId then
        GameTooltip:SetSpell(highestId, BOOKTYPE_SPELL)
    else
        GameTooltip:SetText(this.totemName)
    end
    GameTooltip:Show()
end)
testBtn4:SetScript("OnLeave", function() GameTooltip:Hide() end)
testBtn4:SetScript("OnClick", function()
    local set = TotemNesiaDB.currentTotemSet
    TotemNesiaDB.totemSets[set].fire = this.totemName
    TotemNesia.DebugPrint("Set " .. set .. " Fire = " .. this.totemName)
    UpdateFireBorders()
    UpdateFireBorders()
end)

-- Add fifth button: Frost Resistance Totem
local testBtn5 = CreateFrame("Button", nil, totemSetsContent)
testBtn5:SetWidth(28)
testBtn5:SetHeight(28)
testBtn5:SetPoint("TOPLEFT", 208, -190)
testBtn5:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 1, edgeSize = 2,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
testBtn5:SetBackdropColor(1, 0.3, 0.3, 0.6)
testBtn5:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
local icon5 = testBtn5:CreateTexture(nil, "ARTWORK")
icon5:SetAllPoints(testBtn5)

icon5:SetTexture(GetTotemIcon("Frost Resistance Totem"))
icon5:SetTexCoord(0.08, 0.92, 0.08, 0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = icon5, totemName = "Frost Resistance Totem"})

-- Create border overlay frame on top of icon
local borderOverlay5 = CreateFrame("Frame", nil, testBtn5)
borderOverlay5:SetAllPoints(testBtn5)
borderOverlay5:SetFrameLevel(testBtn5:GetFrameLevel() + 1)
testBtn5.borderOverlay = borderOverlay5

testBtn5.totemName = "Frost Resistance Totem"
table.insert(fireButtons, testBtn5)
testBtn5:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    local highestId = GetHighestLearnedRank(this.totemName)
    if highestId then
        GameTooltip:SetSpell(highestId, BOOKTYPE_SPELL)
    else
        GameTooltip:SetText(this.totemName)
    end
    GameTooltip:Show()
end)
testBtn5:SetScript("OnLeave", function() GameTooltip:Hide() end)
testBtn5:SetScript("OnClick", function()
    local set = TotemNesiaDB.currentTotemSet
    TotemNesiaDB.totemSets[set].fire = this.totemName
    TotemNesia.DebugPrint("Set " .. set .. " Fire = " .. this.totemName)
    UpdateFireBorders()
end)

-- EARTH TOTEMS SECTION (earthBtn1, e2-5)
local earthLabel = totemSetsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
earthLabel:SetPoint("TOPLEFT", 20, -235)
earthLabel:SetText("Earth:")

-- Earth Clear Button
local earthClearBtn = CreateFrame("Button", nil, totemSetsContent)
earthClearBtn:SetWidth(20)
earthClearBtn:SetHeight(20)
earthClearBtn:SetPoint("TOPLEFT", 60, -239)
earthClearBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
earthClearBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
earthClearBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
earthClearBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Clear Earth totem assignment")
    GameTooltip:Show()
end)
earthClearBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
earthClearBtn:SetScript("OnClick", function()
    local set = TotemNesiaDB.currentTotemSet
    TotemNesiaDB.totemSets[set].earth = nil
    TotemNesia.DebugPrint("Cleared Set " .. set .. " Earth totem")
    UpdateEarthBorders()
end)

-- Earth Totem 1: Stoneclaw Totem
local earthBtn1 = CreateFrame("Button", nil, totemSetsContent)
earthBtn1:SetWidth(28)
earthBtn1:SetHeight(28)
earthBtn1:SetPoint("TOPLEFT", 80, -235)
earthBtn1:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 1, edgeSize = 2,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
earthBtn1:SetBackdropColor(0.8, 0.6, 0.3, 0.6)
earthBtn1:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
local earthIcon1 = earthBtn1:CreateTexture(nil, "ARTWORK")
earthIcon1:SetAllPoints(earthBtn1)

earthIcon1:SetTexture(GetTotemIcon("Stoneclaw Totem"))
earthIcon1:SetTexCoord(0.08, 0.92, 0.08, 0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = earthIcon1, totemName = "Stoneclaw Totem"})
local earthOverlay1 = CreateFrame("Frame", nil, earthBtn1)
earthOverlay1:SetAllPoints(earthBtn1)
earthOverlay1:SetFrameLevel(earthBtn1:GetFrameLevel() + 1)
earthBtn1.borderOverlay = earthOverlay1
earthBtn1.totemName = "Stoneclaw Totem"
table.insert(earthButtons, earthBtn1)
earthBtn1:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    local highestId = GetHighestLearnedRank(this.totemName)
    if highestId then
        GameTooltip:SetSpell(highestId, BOOKTYPE_SPELL)
    else
        GameTooltip:SetText(this.totemName)
    end
    GameTooltip:Show()
end)
earthBtn1:SetScript("OnLeave", function() GameTooltip:Hide() end)
earthBtn1:SetScript("OnClick", function()
    local set = TotemNesiaDB.currentTotemSet
    TotemNesiaDB.totemSets[set].earth = this.totemName
    TotemNesia.DebugPrint("Set " .. set .. " Earth = " .. this.totemName)
    UpdateEarthBorders()
end)
-- Earth 2: Stoneskin (112, -235)
local e2=CreateFrame("Button",nil,totemSetsContent)
e2:SetWidth(28) e2:SetHeight(28) e2:SetPoint("TOPLEFT",112,-235)
e2:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=false,tileSize=1,edgeSize=2,insets={left=0,right=0,top=0,bottom=0}})
e2:SetBackdropColor(0.8,0.6,0.3,0.6) e2:SetBackdropBorderColor(0.3,0.3,0.3,1)
local ei2=e2:CreateTexture(nil,"ARTWORK") ei2:SetAllPoints(e2) ei2:SetTexture(GetTotemIcon("Stoneskin Totem")) ei2:SetTexCoord(0.08,0.92,0.08,0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = ei2, totemName = "Stoneskin Totem"})
local eo2=CreateFrame("Frame",nil,e2) eo2:SetAllPoints(e2) eo2:SetFrameLevel(e2:GetFrameLevel()+1) e2.borderOverlay=eo2
e2.totemName="Stoneskin Totem" table.insert(earthButtons,e2)
e2:SetScript("OnEnter",function() 
    GameTooltip:SetOwner(this,"ANCHOR_RIGHT") 
    local highestId = GetHighestLearnedRank(this.totemName) 
    if highestId then 
        GameTooltip:SetSpell(highestId,BOOKTYPE_SPELL) 
    else 
        GameTooltip:SetText(this.totemName) 
    end 
    GameTooltip:Show() 
end)
e2:SetScript("OnLeave",function() GameTooltip:Hide() end)
e2:SetScript("OnClick",function() local set=TotemNesiaDB.currentTotemSet TotemNesiaDB.totemSets[set].earth=this.totemName TotemNesia.DebugPrint("Set "..set.." Earth = "..this.totemName) UpdateEarthBorders() end)

-- Earth 3: Earthbind (144, -235)
local e3=CreateFrame("Button",nil,totemSetsContent)
e3:SetWidth(28) e3:SetHeight(28) e3:SetPoint("TOPLEFT",144,-235)
e3:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=false,tileSize=1,edgeSize=2,insets={left=0,right=0,top=0,bottom=0}})
e3:SetBackdropColor(0.8,0.6,0.3,0.6) e3:SetBackdropBorderColor(0.3,0.3,0.3,1)
local ei3=e3:CreateTexture(nil,"ARTWORK") ei3:SetAllPoints(e3) ei3:SetTexture(GetTotemIcon("Earthbind Totem")) ei3:SetTexCoord(0.08,0.92,0.08,0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = ei3, totemName = "Earthbind Totem"})
local eo3=CreateFrame("Frame",nil,e3) eo3:SetAllPoints(e3) eo3:SetFrameLevel(e3:GetFrameLevel()+1) e3.borderOverlay=eo3
e3.totemName="Earthbind Totem" table.insert(earthButtons,e3)
e3:SetScript("OnEnter",function() GameTooltip:SetOwner(this,"ANCHOR_RIGHT") local highestId = GetHighestLearnedRank(this.totemName) if highestId then GameTooltip:SetSpell(highestId,BOOKTYPE_SPELL) else GameTooltip:SetText(this.totemName) end GameTooltip:Show() end)
e3:SetScript("OnLeave",function() GameTooltip:Hide() end)
e3:SetScript("OnClick",function() local set=TotemNesiaDB.currentTotemSet TotemNesiaDB.totemSets[set].earth=this.totemName TotemNesia.DebugPrint("Set "..set.." Earth = "..this.totemName) UpdateEarthBorders() end)

-- Earth 4: Strength of Earth (176, -235)
local e4=CreateFrame("Button",nil,totemSetsContent)
e4:SetWidth(28) e4:SetHeight(28) e4:SetPoint("TOPLEFT",176,-235)
e4:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=false,tileSize=1,edgeSize=2,insets={left=0,right=0,top=0,bottom=0}})
e4:SetBackdropColor(0.8,0.6,0.3,0.6) e4:SetBackdropBorderColor(0.3,0.3,0.3,1)
local ei4=e4:CreateTexture(nil,"ARTWORK") ei4:SetAllPoints(e4) ei4:SetTexture(GetTotemIcon("Strength of Earth Totem")) ei4:SetTexCoord(0.08,0.92,0.08,0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = ei4, totemName = "Strength of Earth Totem"})
local eo4=CreateFrame("Frame",nil,e4) eo4:SetAllPoints(e4) eo4:SetFrameLevel(e4:GetFrameLevel()+1) e4.borderOverlay=eo4
e4.totemName="Strength of Earth Totem" table.insert(earthButtons,e4)
e4:SetScript("OnEnter",function() GameTooltip:SetOwner(this,"ANCHOR_RIGHT") local highestId = GetHighestLearnedRank(this.totemName) if highestId then GameTooltip:SetSpell(highestId,BOOKTYPE_SPELL) else GameTooltip:SetText(this.totemName) end GameTooltip:Show() end)
e4:SetScript("OnLeave",function() GameTooltip:Hide() end)
e4:SetScript("OnClick",function() local set=TotemNesiaDB.currentTotemSet TotemNesiaDB.totemSets[set].earth=this.totemName TotemNesia.DebugPrint("Set "..set.." Earth = "..this.totemName) UpdateEarthBorders() end)

-- Earth 5: Tremor (208, -235)
local e5=CreateFrame("Button",nil,totemSetsContent)
e5:SetWidth(28) e5:SetHeight(28) e5:SetPoint("TOPLEFT",208,-235)
e5:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=false,tileSize=1,edgeSize=2,insets={left=0,right=0,top=0,bottom=0}})
e5:SetBackdropColor(0.8,0.6,0.3,0.6) e5:SetBackdropBorderColor(0.3,0.3,0.3,1)
local ei5=e5:CreateTexture(nil,"ARTWORK") ei5:SetAllPoints(e5) ei5:SetTexture(GetTotemIcon("Tremor Totem")) ei5:SetTexCoord(0.08,0.92,0.08,0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = ei5, totemName = "Tremor Totem"})
local eo5=CreateFrame("Frame",nil,e5) eo5:SetAllPoints(e5) eo5:SetFrameLevel(e5:GetFrameLevel()+1) e5.borderOverlay=eo5
e5.totemName="Tremor Totem" table.insert(earthButtons,e5)
e5:SetScript("OnEnter",function() GameTooltip:SetOwner(this,"ANCHOR_RIGHT") local highestId = GetHighestLearnedRank(this.totemName) if highestId then GameTooltip:SetSpell(highestId,BOOKTYPE_SPELL) else GameTooltip:SetText(this.totemName) end GameTooltip:Show() end)
e5:SetScript("OnLeave",function() GameTooltip:Hide() end)
e5:SetScript("OnClick",function() local set=TotemNesiaDB.currentTotemSet TotemNesiaDB.totemSets[set].earth=this.totemName TotemNesia.DebugPrint("Set "..set.." Earth = "..this.totemName) UpdateEarthBorders() end)

-- WATER TOTEMS (w1-5)
local waterLabel=totemSetsContent:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
waterLabel:SetPoint("TOPLEFT",20,-280) waterLabel:SetText("Water:")

-- Water Clear Button
local waterClearBtn = CreateFrame("Button", nil, totemSetsContent)
waterClearBtn:SetWidth(20)
waterClearBtn:SetHeight(20)
waterClearBtn:SetPoint("TOPLEFT", 60, -284)
waterClearBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
waterClearBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
waterClearBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
waterClearBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Clear Water totem assignment")
    GameTooltip:Show()
end)
waterClearBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
waterClearBtn:SetScript("OnClick", function()
    local set = TotemNesiaDB.currentTotemSet
    TotemNesiaDB.totemSets[set].water = nil
    TotemNesia.DebugPrint("Cleared Set " .. set .. " Water totem")
    UpdateWaterBorders()
end)

-- Water 1: Healing Stream (80, -280)
local w1=CreateFrame("Button",nil,totemSetsContent)
w1:SetWidth(28) w1:SetHeight(28) w1:SetPoint("TOPLEFT",80,-280)
w1:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=false,tileSize=1,edgeSize=2,insets={left=0,right=0,top=0,bottom=0}})
w1:SetBackdropColor(0.3,0.5,1,0.6) w1:SetBackdropBorderColor(0.3,0.3,0.3,1)
local wi1=w1:CreateTexture(nil,"ARTWORK") wi1:SetAllPoints(w1) wi1:SetTexture(GetTotemIcon("Healing Stream Totem")) wi1:SetTexCoord(0.08,0.92,0.08,0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = wi1, totemName = "Healing Stream Totem"})
local wo1=CreateFrame("Frame",nil,w1) wo1:SetAllPoints(w1) wo1:SetFrameLevel(w1:GetFrameLevel()+1) w1.borderOverlay=wo1
w1.totemName="Healing Stream Totem" table.insert(waterButtons,w1)
w1:SetScript("OnEnter",function() GameTooltip:SetOwner(this,"ANCHOR_RIGHT") local highestId = GetHighestLearnedRank(this.totemName) if highestId then GameTooltip:SetSpell(highestId,BOOKTYPE_SPELL) else GameTooltip:SetText(this.totemName) end GameTooltip:Show() end)
w1:SetScript("OnLeave",function() GameTooltip:Hide() end)
w1:SetScript("OnClick",function() local set=TotemNesiaDB.currentTotemSet TotemNesiaDB.totemSets[set].water=this.totemName TotemNesia.DebugPrint("Set "..set.." Water = "..this.totemName) UpdateWaterBorders() end)

-- Water 2: Mana Spring (112, -280)
local w2=CreateFrame("Button",nil,totemSetsContent)
w2:SetWidth(28) w2:SetHeight(28) w2:SetPoint("TOPLEFT",112,-280)
w2:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=false,tileSize=1,edgeSize=2,insets={left=0,right=0,top=0,bottom=0}})
w2:SetBackdropColor(0.3,0.5,1,0.6) w2:SetBackdropBorderColor(0.3,0.3,0.3,1)
local wi2=w2:CreateTexture(nil,"ARTWORK") wi2:SetAllPoints(w2) wi2:SetTexture(GetTotemIcon("Mana Spring Totem")) wi2:SetTexCoord(0.08,0.92,0.08,0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = wi2, totemName = "Mana Spring Totem"})
local wo2=CreateFrame("Frame",nil,w2) wo2:SetAllPoints(w2) wo2:SetFrameLevel(w2:GetFrameLevel()+1) w2.borderOverlay=wo2
w2.totemName="Mana Spring Totem" table.insert(waterButtons,w2)
w2:SetScript("OnEnter",function() GameTooltip:SetOwner(this,"ANCHOR_RIGHT") local highestId = GetHighestLearnedRank(this.totemName) if highestId then GameTooltip:SetSpell(highestId,BOOKTYPE_SPELL) else GameTooltip:SetText(this.totemName) end GameTooltip:Show() end)
w2:SetScript("OnLeave",function() GameTooltip:Hide() end)
w2:SetScript("OnClick",function() local set=TotemNesiaDB.currentTotemSet TotemNesiaDB.totemSets[set].water=this.totemName TotemNesia.DebugPrint("Set "..set.." Water = "..this.totemName) UpdateWaterBorders() end)

-- Water 3: Fire Resistance (144, -280)
local w3=CreateFrame("Button",nil,totemSetsContent)
w3:SetWidth(28) w3:SetHeight(28) w3:SetPoint("TOPLEFT",144,-280)
w3:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=false,tileSize=1,edgeSize=2,insets={left=0,right=0,top=0,bottom=0}})
w3:SetBackdropColor(0.3,0.5,1,0.6) w3:SetBackdropBorderColor(0.3,0.3,0.3,1)
local wi3=w3:CreateTexture(nil,"ARTWORK") wi3:SetAllPoints(w3) wi3:SetTexture(GetTotemIcon("Fire Resistance Totem")) wi3:SetTexCoord(0.08,0.92,0.08,0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = wi3, totemName = "Fire Resistance Totem"})
local wo3=CreateFrame("Frame",nil,w3) wo3:SetAllPoints(w3) wo3:SetFrameLevel(w3:GetFrameLevel()+1) w3.borderOverlay=wo3
w3.totemName="Fire Resistance Totem" table.insert(waterButtons,w3)
w3:SetScript("OnEnter",function() GameTooltip:SetOwner(this,"ANCHOR_RIGHT") local highestId = GetHighestLearnedRank(this.totemName) if highestId then GameTooltip:SetSpell(highestId,BOOKTYPE_SPELL) else GameTooltip:SetText(this.totemName) end GameTooltip:Show() end)
w3:SetScript("OnLeave",function() GameTooltip:Hide() end)
w3:SetScript("OnClick",function() local set=TotemNesiaDB.currentTotemSet TotemNesiaDB.totemSets[set].water=this.totemName TotemNesia.DebugPrint("Set "..set.." Water = "..this.totemName) UpdateWaterBorders() end)

-- Water 4: Disease Cleansing (176, -280)
local w4=CreateFrame("Button",nil,totemSetsContent)
w4:SetWidth(28) w4:SetHeight(28) w4:SetPoint("TOPLEFT",176,-280)
w4:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=false,tileSize=1,edgeSize=2,insets={left=0,right=0,top=0,bottom=0}})
w4:SetBackdropColor(0.3,0.5,1,0.6) w4:SetBackdropBorderColor(0.3,0.3,0.3,1)
local wi4=w4:CreateTexture(nil,"ARTWORK") wi4:SetAllPoints(w4) wi4:SetTexture(GetTotemIcon("Disease Cleansing Totem")) wi4:SetTexCoord(0.08,0.92,0.08,0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = wi4, totemName = "Disease Cleansing Totem"})
local wo4=CreateFrame("Frame",nil,w4) wo4:SetAllPoints(w4) wo4:SetFrameLevel(w4:GetFrameLevel()+1) w4.borderOverlay=wo4
w4.totemName="Disease Cleansing Totem" table.insert(waterButtons,w4)
w4:SetScript("OnEnter",function() GameTooltip:SetOwner(this,"ANCHOR_RIGHT") local highestId = GetHighestLearnedRank(this.totemName) if highestId then GameTooltip:SetSpell(highestId,BOOKTYPE_SPELL) else GameTooltip:SetText(this.totemName) end GameTooltip:Show() end)
w4:SetScript("OnLeave",function() GameTooltip:Hide() end)
w4:SetScript("OnClick",function() local set=TotemNesiaDB.currentTotemSet TotemNesiaDB.totemSets[set].water=this.totemName TotemNesia.DebugPrint("Set "..set.." Water = "..this.totemName) UpdateWaterBorders() end)

-- Water 5: Poison Cleansing (208, -280)
local w5=CreateFrame("Button",nil,totemSetsContent)
w5:SetWidth(28) w5:SetHeight(28) w5:SetPoint("TOPLEFT",208,-280)
w5:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=false,tileSize=1,edgeSize=2,insets={left=0,right=0,top=0,bottom=0}})
w5:SetBackdropColor(0.3,0.5,1,0.6) w5:SetBackdropBorderColor(0.3,0.3,0.3,1)
local wi5=w5:CreateTexture(nil,"ARTWORK") wi5:SetAllPoints(w5) wi5:SetTexture(GetTotemIcon("Poison Cleansing Totem")) wi5:SetTexCoord(0.08,0.92,0.08,0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = wi5, totemName = "Poison Cleansing Totem"})
local wo5=CreateFrame("Frame",nil,w5) wo5:SetAllPoints(w5) wo5:SetFrameLevel(w5:GetFrameLevel()+1) w5.borderOverlay=wo5
w5.totemName="Poison Cleansing Totem" table.insert(waterButtons,w5)
w5:SetScript("OnEnter",function() GameTooltip:SetOwner(this,"ANCHOR_RIGHT") local highestId = GetHighestLearnedRank(this.totemName) if highestId then GameTooltip:SetSpell(highestId,BOOKTYPE_SPELL) else GameTooltip:SetText(this.totemName) end GameTooltip:Show() end)
w5:SetScript("OnLeave",function() GameTooltip:Hide() end)
w5:SetScript("OnClick",function() local set=TotemNesiaDB.currentTotemSet TotemNesiaDB.totemSets[set].water=this.totemName TotemNesia.DebugPrint("Set "..set.." Water = "..this.totemName) UpdateWaterBorders() end)

-- AIR TOTEMS (a1-6)
local airLabel=totemSetsContent:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
airLabel:SetPoint("TOPLEFT",20,-325) airLabel:SetText("Air:")

-- Air Clear Button
local airClearBtn = CreateFrame("Button", nil, totemSetsContent)
airClearBtn:SetWidth(20)
airClearBtn:SetHeight(20)
airClearBtn:SetPoint("TOPLEFT", 60, -329)
airClearBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
airClearBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
airClearBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
airClearBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Clear Air totem assignment")
    GameTooltip:Show()
end)
airClearBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
airClearBtn:SetScript("OnClick", function()
    local set = TotemNesiaDB.currentTotemSet
    TotemNesiaDB.totemSets[set].air = nil
    TotemNesia.DebugPrint("Cleared Set " .. set .. " Air totem")
    UpdateAirBorders()
end)

-- Air 1: Grounding (80, -325)
local a1=CreateFrame("Button",nil,totemSetsContent)
a1:SetWidth(28) a1:SetHeight(28) a1:SetPoint("TOPLEFT",80,-325)
a1:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=false,tileSize=1,edgeSize=2,insets={left=0,right=0,top=0,bottom=0}})
a1:SetBackdropColor(0.7,0.9,1,0.6) a1:SetBackdropBorderColor(0.3,0.3,0.3,1)
local ai1=a1:CreateTexture(nil,"ARTWORK") ai1:SetAllPoints(a1) ai1:SetTexture(GetTotemIcon("Grounding Totem")) ai1:SetTexCoord(0.08,0.92,0.08,0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = ai1, totemName = "Grounding Totem"})
local ao1=CreateFrame("Frame",nil,a1) ao1:SetAllPoints(a1) ao1:SetFrameLevel(a1:GetFrameLevel()+1) a1.borderOverlay=ao1
a1.totemName="Grounding Totem" table.insert(airButtons,a1)
a1:SetScript("OnEnter",function() GameTooltip:SetOwner(this,"ANCHOR_RIGHT") local highestId = GetHighestLearnedRank(this.totemName) if highestId then GameTooltip:SetSpell(highestId,BOOKTYPE_SPELL) else GameTooltip:SetText(this.totemName) end GameTooltip:Show() end)
a1:SetScript("OnLeave",function() GameTooltip:Hide() end)
a1:SetScript("OnClick",function() local set=TotemNesiaDB.currentTotemSet TotemNesiaDB.totemSets[set].air=this.totemName TotemNesia.DebugPrint("Set "..set.." Air = "..this.totemName) UpdateAirBorders() end)

-- Air 2: Windfury (112, -325)
local a2=CreateFrame("Button",nil,totemSetsContent)
a2:SetWidth(28) a2:SetHeight(28) a2:SetPoint("TOPLEFT",112,-325)
a2:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=false,tileSize=1,edgeSize=2,insets={left=0,right=0,top=0,bottom=0}})
a2:SetBackdropColor(0.7,0.9,1,0.6) a2:SetBackdropBorderColor(0.3,0.3,0.3,1)
local ai2=a2:CreateTexture(nil,"ARTWORK") ai2:SetAllPoints(a2) ai2:SetTexture(GetTotemIcon("Windfury Totem")) ai2:SetTexCoord(0.08,0.92,0.08,0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = ai2, totemName = "Windfury Totem"})
local ao2=CreateFrame("Frame",nil,a2) ao2:SetAllPoints(a2) ao2:SetFrameLevel(a2:GetFrameLevel()+1) a2.borderOverlay=ao2
a2.totemName="Windfury Totem" table.insert(airButtons,a2)
a2:SetScript("OnEnter",function() GameTooltip:SetOwner(this,"ANCHOR_RIGHT") local highestId = GetHighestLearnedRank(this.totemName) if highestId then GameTooltip:SetSpell(highestId,BOOKTYPE_SPELL) else GameTooltip:SetText(this.totemName) end GameTooltip:Show() end)
a2:SetScript("OnLeave",function() GameTooltip:Hide() end)
a2:SetScript("OnClick",function() local set=TotemNesiaDB.currentTotemSet TotemNesiaDB.totemSets[set].air=this.totemName TotemNesia.DebugPrint("Set "..set.." Air = "..this.totemName) UpdateAirBorders() end)

-- Air 3: Grace of Air (144, -325)
local a3=CreateFrame("Button",nil,totemSetsContent)
a3:SetWidth(28) a3:SetHeight(28) a3:SetPoint("TOPLEFT",144,-325)
a3:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=false,tileSize=1,edgeSize=2,insets={left=0,right=0,top=0,bottom=0}})
a3:SetBackdropColor(0.7,0.9,1,0.6) a3:SetBackdropBorderColor(0.3,0.3,0.3,1)
local ai3=a3:CreateTexture(nil,"ARTWORK") ai3:SetAllPoints(a3) ai3:SetTexture(GetTotemIcon("Grace of Air Totem")) ai3:SetTexCoord(0.08,0.92,0.08,0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = ai3, totemName = "Grace of Air Totem"})
local ao3=CreateFrame("Frame",nil,a3) ao3:SetAllPoints(a3) ao3:SetFrameLevel(a3:GetFrameLevel()+1) a3.borderOverlay=ao3
a3.totemName="Grace of Air Totem" table.insert(airButtons,a3)
a3:SetScript("OnEnter",function() GameTooltip:SetOwner(this,"ANCHOR_RIGHT") local highestId = GetHighestLearnedRank(this.totemName) if highestId then GameTooltip:SetSpell(highestId,BOOKTYPE_SPELL) else GameTooltip:SetText(this.totemName) end GameTooltip:Show() end)
a3:SetScript("OnLeave",function() GameTooltip:Hide() end)
a3:SetScript("OnClick",function() local set=TotemNesiaDB.currentTotemSet TotemNesiaDB.totemSets[set].air=this.totemName TotemNesia.DebugPrint("Set "..set.." Air = "..this.totemName) UpdateAirBorders() end)

-- Air 4: Nature Resistance (176, -325)
local a4=CreateFrame("Button",nil,totemSetsContent)
a4:SetWidth(28) a4:SetHeight(28) a4:SetPoint("TOPLEFT",176,-325)
a4:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=false,tileSize=1,edgeSize=2,insets={left=0,right=0,top=0,bottom=0}})
a4:SetBackdropColor(0.7,0.9,1,0.6) a4:SetBackdropBorderColor(0.3,0.3,0.3,1)
local ai4=a4:CreateTexture(nil,"ARTWORK") ai4:SetAllPoints(a4) ai4:SetTexture(GetTotemIcon("Nature Resistance Totem")) ai4:SetTexCoord(0.08,0.92,0.08,0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = ai4, totemName = "Nature Resistance Totem"})
local ao4=CreateFrame("Frame",nil,a4) ao4:SetAllPoints(a4) ao4:SetFrameLevel(a4:GetFrameLevel()+1) a4.borderOverlay=ao4
a4.totemName="Nature Resistance Totem" table.insert(airButtons,a4)
a4:SetScript("OnEnter",function() GameTooltip:SetOwner(this,"ANCHOR_RIGHT") local highestId = GetHighestLearnedRank(this.totemName) if highestId then GameTooltip:SetSpell(highestId,BOOKTYPE_SPELL) else GameTooltip:SetText(this.totemName) end GameTooltip:Show() end)
a4:SetScript("OnLeave",function() GameTooltip:Hide() end)
a4:SetScript("OnClick",function() local set=TotemNesiaDB.currentTotemSet TotemNesiaDB.totemSets[set].air=this.totemName TotemNesia.DebugPrint("Set "..set.." Air = "..this.totemName) UpdateAirBorders() end)

-- Air 5: Tranquil Air (208, -325)
local a5=CreateFrame("Button",nil,totemSetsContent)
a5:SetWidth(28) a5:SetHeight(28) a5:SetPoint("TOPLEFT",208,-325)
a5:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=false,tileSize=1,edgeSize=2,insets={left=0,right=0,top=0,bottom=0}})
a5:SetBackdropColor(0.7,0.9,1,0.6) a5:SetBackdropBorderColor(0.3,0.3,0.3,1)
local ai5=a5:CreateTexture(nil,"ARTWORK") ai5:SetAllPoints(a5) ai5:SetTexture(GetTotemIcon("Tranquil Air Totem")) ai5:SetTexCoord(0.08,0.92,0.08,0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = ai5, totemName = "Tranquil Air Totem"})
local ao5=CreateFrame("Frame",nil,a5) ao5:SetAllPoints(a5) ao5:SetFrameLevel(a5:GetFrameLevel()+1) a5.borderOverlay=ao5
a5.totemName="Tranquil Air Totem" table.insert(airButtons,a5)
a5:SetScript("OnEnter",function() GameTooltip:SetOwner(this,"ANCHOR_RIGHT") local highestId = GetHighestLearnedRank(this.totemName) if highestId then GameTooltip:SetSpell(highestId,BOOKTYPE_SPELL) else GameTooltip:SetText(this.totemName) end GameTooltip:Show() end)
a5:SetScript("OnLeave",function() GameTooltip:Hide() end)
a5:SetScript("OnClick",function() local set=TotemNesiaDB.currentTotemSet TotemNesiaDB.totemSets[set].air=this.totemName TotemNesia.DebugPrint("Set "..set.." Air = "..this.totemName) UpdateAirBorders() end)

-- Air 6: Windwall (240, -325)
local a6=CreateFrame("Button",nil,totemSetsContent)
a6:SetWidth(28) a6:SetHeight(28) a6:SetPoint("TOPLEFT",240,-325)
a6:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=false,tileSize=1,edgeSize=2,insets={left=0,right=0,top=0,bottom=0}})
a6:SetBackdropColor(0.7,0.9,1,0.6) a6:SetBackdropBorderColor(0.3,0.3,0.3,1)
local ai6=a6:CreateTexture(nil,"ARTWORK") ai6:SetAllPoints(a6) ai6:SetTexture(GetTotemIcon("Windwall Totem")) ai6:SetTexCoord(0.08,0.92,0.08,0.92)
table.insert(TotemNesia.totemIcons, {iconTexture = ai6, totemName = "Windwall Totem"})
local ao6=CreateFrame("Frame",nil,a6) ao6:SetAllPoints(a6) ao6:SetFrameLevel(a6:GetFrameLevel()+1) a6.borderOverlay=ao6
a6.totemName="Windwall Totem" table.insert(airButtons,a6)
a6:SetScript("OnEnter",function() GameTooltip:SetOwner(this,"ANCHOR_RIGHT") local highestId = GetHighestLearnedRank(this.totemName) if highestId then GameTooltip:SetSpell(highestId,BOOKTYPE_SPELL) else GameTooltip:SetText(this.totemName) end GameTooltip:Show() end)
a6:SetScript("OnLeave",function() GameTooltip:Hide() end)
a6:SetScript("OnClick",function() local set=TotemNesiaDB.currentTotemSet TotemNesiaDB.totemSets[set].air=this.totemName TotemNesia.DebugPrint("Set "..set.." Air = "..this.totemName) UpdateAirBorders() end)


-- NOTE: Don't call UpdateFireBorders() here - TotemNesiaDB isn't initialized yet!
-- It will be called when buttons are clicked or tabs are switched

-- MANA TAB CONTENT
-- Mana tab title
local manaTabTitle = manaContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
manaTabTitle:SetPoint("TOP", 0, -60)
manaTabTitle:SetText("Mana Management")

-- Mana tab description
local manaTabDesc = manaContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
manaTabDesc:SetPoint("TOP", 0, -85)
manaTabDesc:SetWidth(360)
manaTabDesc:SetJustifyH("CENTER")
manaTabDesc:SetText("Configure low mana alerts to help manage your mana pool during combat.")

-- Mute mana audio queue checkbox (LEFT COLUMN)
local muteManaCheckbox = CreateFrame("CheckButton", nil, manaContent, "UICheckButtonTemplate")
muteManaCheckbox:SetPoint("TOPLEFT", 20, -110)
muteManaCheckbox:SetWidth(24)
muteManaCheckbox:SetHeight(24)
local muteManaLabel = muteManaCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
muteManaLabel:SetPoint("LEFT", muteManaCheckbox, "RIGHT", 5, 0)
muteManaLabel:SetText("Mute low mana alert")
muteManaCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.manaAudioMuted = this:GetChecked() and true or false
end)

-- Potion Alert checkbox (LEFT COLUMN)
local mutePotionCheckbox = CreateFrame("CheckButton", nil, manaContent, "UICheckButtonTemplate")
mutePotionCheckbox:SetPoint("TOPLEFT", 20, -140)
mutePotionCheckbox:SetWidth(24)
mutePotionCheckbox:SetHeight(24)
local mutePotionLabel = mutePotionCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
mutePotionLabel:SetPoint("LEFT", mutePotionCheckbox, "RIGHT", 5, 0)
mutePotionLabel:SetText("Mute potion alert")
mutePotionCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.potionAudioMuted = this:GetChecked() and true or false
end)

-- Mana Threshold label
local manaThresholdLabel = manaContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
manaThresholdLabel:SetPoint("TOP", 0, -170)
manaThresholdLabel:SetText("Low Mana Alert Threshold: 30%")

-- Mana Threshold slider
local manaThresholdSlider = CreateFrame("Slider", nil, manaContent)
manaThresholdSlider:SetPoint("TOP", 0, -190)
manaThresholdSlider:SetWidth(350)
manaThresholdSlider:SetHeight(15)
manaThresholdSlider:SetOrientation("HORIZONTAL")
manaThresholdSlider:SetMinMaxValues(0, 100)
manaThresholdSlider:SetValueStep(5)
manaThresholdSlider:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 }
})
local manaThresholdThumb = manaThresholdSlider:CreateTexture(nil, "OVERLAY")
manaThresholdThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
manaThresholdThumb:SetWidth(32)
manaThresholdThumb:SetHeight(32)
manaThresholdSlider:SetThumbTexture(manaThresholdThumb)
manaThresholdSlider:SetScript("OnValueChanged", function()
    local value = math.floor(this:GetValue() / 5 + 0.5) * 5  -- Round to nearest 5%
    TotemNesiaDB.manaThreshold = value
    manaThresholdLabel:SetText("Low Mana Alert Threshold: " .. value .. "%")
end)

local potionThresholdLabel = manaContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
potionThresholdLabel:SetPoint("TOP", 0, -220)
potionThresholdLabel:SetText("Potion Alert: 30%")

local potionThresholdSlider = CreateFrame("Slider", nil, manaContent)
potionThresholdSlider:SetPoint("TOP", 0, -240)
potionThresholdSlider:SetWidth(350)
potionThresholdSlider:SetHeight(15)
potionThresholdSlider:SetOrientation("HORIZONTAL")
potionThresholdSlider:SetMinMaxValues(0, 100)
potionThresholdSlider:SetValueStep(5)
potionThresholdSlider:SetValue(30)
potionThresholdSlider:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 }
})
local potionThresholdThumb = potionThresholdSlider:CreateTexture(nil, "OVERLAY")
potionThresholdThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
potionThresholdThumb:SetWidth(32)
potionThresholdThumb:SetHeight(32)
potionThresholdSlider:SetThumbTexture(potionThresholdThumb)
potionThresholdSlider:SetScript("OnValueChanged", function()
    local value = math.floor(this:GetValue() / 5 + 0.5) * 5
    TotemNesiaDB.potionThreshold = value
    potionThresholdLabel:SetText("Potion Alert: " .. value .. "%")
end)

-- Public Mana Alert checkbox (RIGHT COLUMN)
local mutePublicManaCheckbox = CreateFrame("CheckButton", nil, manaContent, "UICheckButtonTemplate")
mutePublicManaCheckbox:SetPoint("TOPLEFT", 210, -110)
mutePublicManaCheckbox:SetWidth(24)
mutePublicManaCheckbox:SetHeight(24)
local mutePublicManaLabel = mutePublicManaCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
mutePublicManaLabel:SetPoint("LEFT", mutePublicManaCheckbox, "RIGHT", 5, 0)
mutePublicManaLabel:SetText("Disable public mana alert")
mutePublicManaCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.publicManaMuted = this:GetChecked() and true or false
end)

-- Public Mana Alert Threshold label
-- Mana explanation text
local manaExplanation = manaContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
manaExplanation:SetPoint("TOP", 0, -280)
manaExplanation:SetWidth(360)
manaExplanation:SetJustifyH("LEFT")
manaExplanation:SetText("The addon will play an audio alert when your mana drops below the threshold.\n\nThe alert has a 30-second cooldown to prevent spam and only triggers when crossing below the threshold (not while hovering).")

-- LEFT COLUMN (now in settingsContent)
-- Lock Recall Notification checkbox
local lockCheckbox = CreateFrame("CheckButton", nil, settingsScrollChild, "UICheckButtonTemplate")
lockCheckbox:SetPoint("TOPLEFT", 20, -45)
lockCheckbox:SetWidth(24)
lockCheckbox:SetHeight(24)
local lockLabel = lockCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lockLabel:SetPoint("LEFT", lockCheckbox, "RIGHT", 5, 0)
lockLabel:SetText("Lock recall notification")
lockCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.isLocked = this:GetChecked() and true or false
    if TotemNesiaDB.isLocked then
        iconFrame:SetBackdropColor(0, 0, 0, 0.75)
        iconFrame:RegisterForClicks("LeftButtonUp")
        -- Hide frame if no active timer
        if not TotemNesia.displayTimer or TotemNesia.displayTimer <= 0 then
            iconFrame:Hide()
        end
    else
        iconFrame:SetBackdropColor(0, 0, 0, 1)
        iconFrame:RegisterForClicks()
        iconFrame:Show()
    end
end)

-- Mute audio queue checkbox
local muteCheckbox = CreateFrame("CheckButton", nil, settingsScrollChild, "UICheckButtonTemplate")
muteCheckbox:SetPoint("TOPLEFT", 20, -105)
muteCheckbox:SetWidth(24)
muteCheckbox:SetHeight(24)
local muteLabel = muteCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
muteLabel:SetPoint("LEFT", muteCheckbox, "RIGHT", 5, 0)
muteLabel:SetText("Mute recall audio queue")
muteCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.audioEnabled = not this:GetChecked()
end)

-- Hide Recall Notification checkbox
local hideUICheckbox = CreateFrame("CheckButton", nil, settingsScrollChild, "UICheckButtonTemplate")
hideUICheckbox:SetPoint("TOPLEFT", 20, -75)
hideUICheckbox:SetWidth(24)
hideUICheckbox:SetHeight(24)
local hideUILabel = hideUICheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hideUILabel:SetPoint("LEFT", hideUICheckbox, "RIGHT", 5, 0)
hideUILabel:SetText("Hide recall notification")
hideUICheckbox:SetScript("OnClick", function()
    TotemNesiaDB.hideUIElement = this:GetChecked() and true or false
end)

-- Enable Totem Bar checkbox
local enableTotemBarCheckbox = CreateFrame("CheckButton", nil, settingsScrollChild, "UICheckButtonTemplate")
enableTotemBarCheckbox:SetPoint("TOPLEFT", 210, -45)
enableTotemBarCheckbox:SetWidth(24)
enableTotemBarCheckbox:SetHeight(24)
local enableTotemBarLabel = enableTotemBarCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
enableTotemBarLabel:SetPoint("LEFT", enableTotemBarCheckbox, "RIGHT", 5, 0)
enableTotemBarLabel:SetText("Enable totem bar")
enableTotemBarCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.totemBarEnabled = this:GetChecked() and true or false
    TotemNesia.UpdateTotemBar()
end)

-- RIGHT COLUMN
-- Lock Totem Tracker checkbox
local lockTotemBarCheckbox = CreateFrame("CheckButton", nil, settingsScrollChild, "UICheckButtonTemplate")
lockTotemBarCheckbox:SetPoint("TOPLEFT", 20, -135)
lockTotemBarCheckbox:SetWidth(24)
lockTotemBarCheckbox:SetHeight(24)
local lockTotemBarLabel = lockTotemBarCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lockTotemBarLabel:SetPoint("LEFT", lockTotemBarCheckbox, "RIGHT", 5, 0)
lockTotemBarLabel:SetText("Lock totem tracker")
lockTotemBarCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.totemTrackerLocked = this:GetChecked() and true or false
    if TotemNesiaDB.totemTrackerLocked then
        totemTracker:EnableMouse(false)
    else
        totemTracker:EnableMouse(true)
    end
end)

-- Hide Totem Tracker checkbox
local hideTotemBarCheckbox = CreateFrame("CheckButton", nil, settingsScrollChild, "UICheckButtonTemplate")
hideTotemBarCheckbox:SetPoint("TOPLEFT", 20, -165)
hideTotemBarCheckbox:SetWidth(24)
hideTotemBarCheckbox:SetHeight(24)
local hideTotemBarLabel = hideTotemBarCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hideTotemBarLabel:SetPoint("LEFT", hideTotemBarCheckbox, "RIGHT", 5, 0)
hideTotemBarLabel:SetText("Hide totem tracker")
hideTotemBarCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.totemTrackerHidden = this:GetChecked() and true or false
    TotemNesia.UpdateTotemTracker()
end)

-- Lock Totem Bar checkbox
local lockTotemBarCastCheckbox = CreateFrame("CheckButton", nil, settingsScrollChild, "UICheckButtonTemplate")
lockTotemBarCastCheckbox:SetPoint("TOPLEFT", 210, -75)
lockTotemBarCastCheckbox:SetWidth(24)
lockTotemBarCastCheckbox:SetHeight(24)
local lockTotemBarCastLabel = lockTotemBarCastCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lockTotemBarCastLabel:SetPoint("LEFT", lockTotemBarCastCheckbox, "RIGHT", 5, 0)
lockTotemBarCastLabel:SetText("Lock totem bar")
lockTotemBarCastCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.totemBarLocked = this:GetChecked() and true or false
    if TotemNesiaDB.totemBarLocked then
        totemBar:EnableMouse(false)
    else
        totemBar:EnableMouse(true)
    end
end)

-- Shift to Open Flyouts checkbox (non-functional placeholder)
local shiftToOpenFlyoutsCheckbox = CreateFrame("CheckButton", nil, settingsScrollChild, "UICheckButtonTemplate")
shiftToOpenFlyoutsCheckbox:SetPoint("TOPLEFT", 210, -105)
shiftToOpenFlyoutsCheckbox:SetWidth(24)
shiftToOpenFlyoutsCheckbox:SetHeight(24)
local shiftToOpenFlyoutsLabel = shiftToOpenFlyoutsCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
shiftToOpenFlyoutsLabel:SetPoint("LEFT", shiftToOpenFlyoutsCheckbox, "RIGHT", 5, 0)
shiftToOpenFlyoutsLabel:SetText("Disable shift for flyouts")
shiftToOpenFlyoutsCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.shiftToOpenFlyouts = this:GetChecked() and true or false
end)

-- Hide Weapon Enchant Slot checkbox
local hideWeaponSlotCheckbox = CreateFrame("CheckButton", nil, settingsScrollChild, "UICheckButtonTemplate")
hideWeaponSlotCheckbox:SetPoint("TOPLEFT", 210, -135)
hideWeaponSlotCheckbox:SetWidth(24)
hideWeaponSlotCheckbox:SetHeight(24)
local hideWeaponSlotLabel = hideWeaponSlotCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hideWeaponSlotLabel:SetPoint("LEFT", hideWeaponSlotCheckbox, "RIGHT", 5, 0)
hideWeaponSlotLabel:SetText("Hide weapon enchant slot")
hideWeaponSlotCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.hideWeaponSlot = this:GetChecked() and true or false
    TotemNesia.UpdateTotemBar()
end)

-- LEFT SIDE: "Will be enabled when in:" section
local enabledWhenLabel = settingsScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
enabledWhenLabel:SetPoint("TOPLEFT", 20, -190)
enabledWhenLabel:SetText("Will be enabled when in:")

-- Solo checkbox (vertical stack)
local soloCheckbox = CreateFrame("CheckButton", nil, settingsScrollChild, "UICheckButtonTemplate")
soloCheckbox:SetPoint("TOPLEFT", 20, -210)
soloCheckbox:SetWidth(24)
soloCheckbox:SetHeight(24)
local soloLabel = soloCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
soloLabel:SetPoint("LEFT", soloCheckbox, "RIGHT", 5, 0)
soloLabel:SetText("Solo")
soloCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.enabledSolo = this:GetChecked() and true or false
end)

-- Parties checkbox
local partyCheckbox = CreateFrame("CheckButton", nil, settingsScrollChild, "UICheckButtonTemplate")
partyCheckbox:SetPoint("TOPLEFT", 20, -235)
partyCheckbox:SetWidth(24)
partyCheckbox:SetHeight(24)
local partyLabel = partyCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
partyLabel:SetPoint("LEFT", partyCheckbox, "RIGHT", 5, 0)
partyLabel:SetText("Parties")
partyCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.enabledParty = this:GetChecked() and true or false
end)

-- Raids checkbox
local raidCheckbox = CreateFrame("CheckButton", nil, settingsScrollChild, "UICheckButtonTemplate")
raidCheckbox:SetPoint("TOPLEFT", 20, -260)
raidCheckbox:SetWidth(24)
raidCheckbox:SetHeight(24)
local raidLabel = raidCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
raidLabel:SetPoint("LEFT", raidCheckbox, "RIGHT", 5, 0)
raidLabel:SetText("Raids")
raidCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.enabledRaid = this:GetChecked() and true or false
end)

-- RIGHT SIDE: Totem Bar Layout toggle button
local layoutButton = CreateFrame("Button", nil, settingsScrollChild, "UIPanelButtonTemplate")
layoutButton:SetWidth(120)
layoutButton:SetHeight(24)
layoutButton:SetPoint("TOPRIGHT", -20, -205)
layoutButton:SetText("Horizontal")  -- Default text, will be updated when options open

local layoutLabel = settingsScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
layoutLabel:SetPoint("BOTTOM", layoutButton, "TOP", 0, 2)
layoutLabel:SetText("Totem Bar Layout:")

-- Flyout Direction toggle button (create before layout OnClick so we can reference it)
local flyoutButton = CreateFrame("Button", nil, settingsScrollChild, "UIPanelButtonTemplate")
flyoutButton:SetWidth(120)
flyoutButton:SetHeight(24)
flyoutButton:SetPoint("TOPRIGHT", -20, -255)
flyoutButton:SetText("Up")  -- Default text, will be updated when options open

local flyoutLabel = settingsScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
flyoutLabel:SetPoint("BOTTOM", flyoutButton, "TOP", 0, 2)
flyoutLabel:SetText("Flyout Direction:")

-- Now set up layout button OnClick (after flyoutButton exists)
layoutButton:SetScript("OnClick", function()
    if TotemNesiaDB.totemBarLayout == "Horizontal" then
        TotemNesiaDB.totemBarLayout = "Vertical"
        this:SetText("Vertical")
        -- Default to Right for vertical layout
        TotemNesiaDB.totemBarFlyoutDirection = "Right"
        flyoutButton:SetText("Right")
        if TotemNesiaDB.debugMode then
            TotemNesia.DebugPrint("Layout changed to Vertical, flyout direction set to Right")
        end
    else
        TotemNesiaDB.totemBarLayout = "Horizontal"
        this:SetText("Horizontal")
        -- Default to Up for horizontal layout
        TotemNesiaDB.totemBarFlyoutDirection = "Up"
        flyoutButton:SetText("Up")
        if TotemNesiaDB.debugMode then
            TotemNesia.DebugPrint("Layout changed to Horizontal, flyout direction set to Up")
        end
    end
    TotemNesia.UpdateTotemBar()
    TotemNesia.UpdateTotemBarFlyouts()
end)

-- Set up flyout button OnClick
flyoutButton:SetScript("OnClick", function()
    local isVertical = (TotemNesiaDB.totemBarLayout == "Vertical")
    
    if isVertical then
        -- Vertical layout: cycle between Left and Right
        if TotemNesiaDB.totemBarFlyoutDirection == "Left" then
            TotemNesiaDB.totemBarFlyoutDirection = "Right"
            this:SetText("Right")
        else
            TotemNesiaDB.totemBarFlyoutDirection = "Left"
            this:SetText("Left")
        end
    else
        -- Horizontal layout: cycle between Up and Down
        if TotemNesiaDB.totemBarFlyoutDirection == "Up" then
            TotemNesiaDB.totemBarFlyoutDirection = "Down"
            this:SetText("Down")
        else
            TotemNesiaDB.totemBarFlyoutDirection = "Up"
            this:SetText("Up")
        end
    end
    
    TotemNesia.UpdateTotemBarFlyouts()
end)

-- Timer duration label
local timerLabel = settingsScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
timerLabel:SetPoint("TOP", 0, -285)
timerLabel:SetText("Display Duration: 15s")

-- Timer duration slider
local timerSlider = CreateFrame("Slider", nil, settingsScrollChild)
timerSlider:SetPoint("TOP", 0, -305)
timerSlider:SetWidth(350)
timerSlider:SetHeight(15)
timerSlider:SetOrientation("HORIZONTAL")
timerSlider:SetMinMaxValues(15, 60)
timerSlider:SetValueStep(1)

-- Slider backdrop
timerSlider:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 }
})

-- Slider thumb
local sliderThumb = timerSlider:CreateTexture(nil, "OVERLAY")
sliderThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
sliderThumb:SetWidth(32)
sliderThumb:SetHeight(32)
timerSlider:SetThumbTexture(sliderThumb)

-- Slider script
timerSlider:SetScript("OnValueChanged", function()
    local value = math.floor(this:GetValue() + 0.5) -- Round to nearest integer
    TotemNesiaDB.timerDuration = value
    timerLabel:SetText("Display Duration: " .. value .. "s")
end)

-- Recall Notification Scale label
local uiScaleLabel = settingsScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
uiScaleLabel:SetPoint("TOP", 0, -330)
uiScaleLabel:SetText("Recall Notification Scale: 1.0")

-- Recall Notification Scale slider
local uiScaleSlider = CreateFrame("Slider", nil, settingsScrollChild)
uiScaleSlider:SetPoint("TOP", 0, -350)
uiScaleSlider:SetWidth(350)
uiScaleSlider:SetHeight(15)
uiScaleSlider:SetOrientation("HORIZONTAL")
uiScaleSlider:SetMinMaxValues(0.5, 2.0)
uiScaleSlider:SetValueStep(0.1)
uiScaleSlider:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 }
})
local uiScaleThumb = uiScaleSlider:CreateTexture(nil, "OVERLAY")
uiScaleThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
uiScaleThumb:SetWidth(32)
uiScaleThumb:SetHeight(32)
uiScaleSlider:SetThumbTexture(uiScaleThumb)
uiScaleSlider:SetScript("OnValueChanged", function()
    local value = math.floor(this:GetValue() * 10 + 0.5) / 10
    TotemNesiaDB.uiFrameScale = value
    uiScaleLabel:SetText("Recall Notification Scale: " .. value)
    iconFrame:SetScale(value)
end)

-- Totem Tracker Scale label
local trackerScaleLabel = settingsScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
trackerScaleLabel:SetPoint("TOP", 0, -375)
trackerScaleLabel:SetText("Totem Tracker Scale: 1.0")

-- Totem Tracker Scale slider
local trackerScaleSlider = CreateFrame("Slider", nil, settingsScrollChild)
trackerScaleSlider:SetPoint("TOP", 0, -395)
trackerScaleSlider:SetWidth(350)
trackerScaleSlider:SetHeight(15)
trackerScaleSlider:SetOrientation("HORIZONTAL")
trackerScaleSlider:SetMinMaxValues(0.5, 2.0)
trackerScaleSlider:SetValueStep(0.1)
trackerScaleSlider:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 }
})
local trackerScaleThumb = trackerScaleSlider:CreateTexture(nil, "OVERLAY")
trackerScaleThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
trackerScaleThumb:SetWidth(32)
trackerScaleThumb:SetHeight(32)
trackerScaleSlider:SetThumbTexture(trackerScaleThumb)
trackerScaleSlider:SetScript("OnValueChanged", function()
    local value = math.floor(this:GetValue() * 10 + 0.5) / 10
    TotemNesiaDB.totemTrackerScale = value
    trackerScaleLabel:SetText("Totem Tracker Scale: " .. value)
    totemTracker:SetScale(value)
end)

-- Totem Bar Scale label
local barScaleLabel = settingsScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
barScaleLabel:SetPoint("TOP", 0, -420)
barScaleLabel:SetText("Totem Bar Scale: 1.0")

-- Totem Bar Scale slider
local barScaleSlider = CreateFrame("Slider", nil, settingsScrollChild)
barScaleSlider:SetPoint("TOP", 0, -440)
barScaleSlider:SetWidth(350)
barScaleSlider:SetHeight(15)
barScaleSlider:SetOrientation("HORIZONTAL")
barScaleSlider:SetMinMaxValues(0.5, 2.0)
barScaleSlider:SetValueStep(0.1)
barScaleSlider:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 }
})
local barScaleThumb = barScaleSlider:CreateTexture(nil, "OVERLAY")
barScaleThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
barScaleThumb:SetWidth(32)
barScaleThumb:SetHeight(32)
barScaleSlider:SetThumbTexture(barScaleThumb)
barScaleSlider:SetScript("OnValueChanged", function()
    local value = math.floor(this:GetValue() * 10 + 0.5) / 10
    TotemNesiaDB.totemBarScale = value
    barScaleLabel:SetText("Totem Bar Scale: " .. value)
    totemBar:SetScale(value)
end)

-- Keybind macros section
local keybindTitle = settingsScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
keybindTitle:SetPoint("TOP", 0, -530)
keybindTitle:SetWidth(360)
keybindTitle:SetJustifyH("CENTER")
keybindTitle:SetText("Keybinds: Sequential Totem Cast keybind available in ESC > Key Bindings > TotemNesia")

-- Recall macro EditBox
local keybind1 = CreateFrame("EditBox", nil, settingsScrollChild)
keybind1:SetPoint("TOPLEFT", 20, -550)
keybind1:SetWidth(360)
keybind1:SetHeight(20)
keybind1:SetFontObject(GameFontNormalSmall)
keybind1:SetText("/script TotemNesia_RecallTotems()")
keybind1:SetAutoFocus(false)
keybind1:SetScript("OnEditFocusGained", function()
    this:HighlightText()
end)
keybind1:SetScript("OnEscapePressed", function()
    this:ClearFocus()
end)
keybind1:SetScript("OnEnterPressed", function()
    this:ClearFocus()
end)
keybind1:SetScript("OnChar", function()
    -- Block all character input
    this:SetText("/script TotemNesia_RecallTotems()")
    this:HighlightText()
end)
keybind1:SetScript("OnTextChanged", function()
    -- Restore text if it gets changed
    if this:GetText() ~= "/script TotemNesia_RecallTotems()" then
        this:SetText("/script TotemNesia_RecallTotems()")
        this:HighlightText()
    end
end)

-- Debug mode checkbox (bottom right, aligned with script)
local debugCheckbox = CreateFrame("CheckButton", nil, settingsScrollChild, "UICheckButtonTemplate")
debugCheckbox:SetPoint("TOPRIGHT", -20, -550)  -- Same Y as script, but on right side
debugCheckbox:SetWidth(24)
debugCheckbox:SetHeight(24)
local debugLabel = debugCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
debugLabel:SetPoint("RIGHT", debugCheckbox, "LEFT", -5, 0)  -- Label on left of checkbox
debugLabel:SetText("Debug mode")
debugCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.debugMode = this:GetChecked() and true or false
end)

-- Update minimap button position
function TotemNesia.UpdateMinimapButton()
    local angle = math.rad(TotemNesiaDB.minimapPos or 180)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    
    -- Ensure button is visible unless explicitly hidden
    if not TotemNesiaDB.minimapHidden then
        minimapButton:Show()
    end
end

-- Minimap button tooltip
minimapButton:SetScript("OnEnter", function()
    -- TODO: Show context menu in future version
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("TotemNesia")
    GameTooltip:AddLine("Click to open Settings", 1, 1, 1)
    GameTooltip:AddLine("Right-click to drag", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Click to open options menu
minimapButton:SetScript("OnClick", function()
    if optionsMenu:IsVisible() then
        optionsMenu:Hide()
    else
        -- Update checkbox states when opening
        lockCheckbox:SetChecked(TotemNesiaDB.isLocked)
        muteCheckbox:SetChecked(not TotemNesiaDB.audioEnabled)
        muteManaCheckbox:SetChecked(TotemNesiaDB.manaAudioMuted)
        mutePotionCheckbox:SetChecked(TotemNesiaDB.potionAudioMuted)
        -- test comment
        hideUICheckbox:SetChecked(TotemNesiaDB.hideUIElement)
        enableTotemBarCheckbox:SetChecked(TotemNesiaDB.totemBarEnabled)
        lockTotemBarCheckbox:SetChecked(TotemNesiaDB.totemTrackerLocked)
        hideTotemBarCheckbox:SetChecked(TotemNesiaDB.totemTrackerHidden)
        lockTotemBarCastCheckbox:SetChecked(TotemNesiaDB.totemBarLocked)
        hideWeaponSlotCheckbox:SetChecked(TotemNesiaDB.hideWeaponSlot)
        shiftToOpenFlyoutsCheckbox:SetChecked(TotemNesiaDB.shiftToOpenFlyouts)
        debugCheckbox:SetChecked(TotemNesiaDB.debugMode)
        soloCheckbox:SetChecked(TotemNesiaDB.enabledSolo)
        partyCheckbox:SetChecked(TotemNesiaDB.enabledParty)
        raidCheckbox:SetChecked(TotemNesiaDB.enabledRaid)
        
        timerSlider:SetValue(TotemNesiaDB.timerDuration)
        
        uiScaleSlider:SetValue(TotemNesiaDB.uiFrameScale)
        uiScaleLabel:SetText("Recall Notification Scale: " .. TotemNesiaDB.uiFrameScale)
        
        trackerScaleSlider:SetValue(TotemNesiaDB.totemTrackerScale)
        trackerScaleLabel:SetText("Totem Tracker Scale: " .. TotemNesiaDB.totemTrackerScale)
        
        barScaleSlider:SetValue(TotemNesiaDB.totemBarScale)
        barScaleLabel:SetText("Totem Bar Scale: " .. TotemNesiaDB.totemBarScale)
        
        manaThresholdSlider:SetValue(TotemNesiaDB.manaThreshold)
        manaThresholdLabel:SetText("Low Mana Alert: " .. TotemNesiaDB.manaThreshold .. "%")
        potionThresholdSlider:SetValue(TotemNesiaDB.potionThreshold)
        potionThresholdLabel:SetText("Potion Alert: " .. TotemNesiaDB.potionThreshold .. "%")
        timerLabel:SetText("Display Duration: " .. TotemNesiaDB.timerDuration .. "s")
        layoutButton:SetText(TotemNesiaDB.totemBarLayout or "Horizontal")
        flyoutButton:SetText(TotemNesiaDB.totemBarFlyoutDirection or "Up")
        settingsContent:SetVerticalScroll(0); settingsScrollbar:SetValue(0)  -- Reset scroll to top
        optionsMenu:Show()
    end
end)

-- Dragging around minimap (right-click)
minimapButton:RegisterForDrag("RightButton")
minimapButton:SetScript("OnDragStart", function()
    this:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        
        local angle = math.deg(math.atan2(py - my, px - mx))
        TotemNesiaDB.minimapPos = angle
        TotemNesia.UpdateMinimapButton()
    end)
end)

minimapButton:SetScript("OnDragStop", function()
    this:SetScript("OnUpdate", nil)
end)

minimapButton:RegisterForClicks("LeftButtonUp")

-- Function to check if player is a shaman
local function IsShaman()
    local _, class = UnitClass("player")
    return class == "SHAMAN"
end

-- Function to check if player has totems out
local function HasTotemsOut()
    return TotemNesia.hasTotems
end

-- Combat log parser to track totem summons and recalls
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
combatFrame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE")
combatFrame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:RegisterEvent("PLAYER_DEAD")
combatFrame:SetScript("OnEvent", function()
    -- Check if addon is enabled for current group type
    if not TotemNesia.IsAddonEnabled() then
        return
    end
    
    if event == "CHAT_MSG_SPELL_SELF_BUFF" then
        -- Check for totem summons - validate it's actually a totem
        if string.find(arg1, "Totem") and not string.find(arg1, "Totemic Recall") then
            -- Try to extract totem name from message
            -- Could be "You cast X." or "You gain X." or just the totem name
            local rawName = arg1
            -- Clean up common prefixes
            rawName = string.gsub(rawName, "You cast ", "")
            rawName = string.gsub(rawName, "You gain ", "")
            rawName = string.gsub(rawName, "%.", "")
            
            -- Validate this is actually a totem we know about
            local isValid, totemName = IsValidTotem(rawName)
            
            if isValid then
                -- Special handling for Fire Nova Totem (self-destructs)
                if string.find(totemName, "Fire Nova Totem") then
                    TotemNesia.DebugPrint("Fire Nova Totem ignored (self-destructs)")
                    return
                end
                
                -- Get the element of the new totem
                local newElement = GetTotemElement(totemName)
                
                -- Remove any existing totem of the same element
                if newElement then
                    for existingTotem, _ in pairs(TotemNesia.activeTotems) do
                        if GetTotemElement(existingTotem) == newElement then
                            TotemNesia.activeTotems[existingTotem] = nil
                            TotemNesia.totemTimestamps[existingTotem] = nil
                            TotemNesia.totemPositions[existingTotem] = nil
                            TotemNesia.DebugPrint("Removed old " .. newElement .. " totem: " .. existingTotem)
                        end
                    end
                end
                
                -- Add the new totem
                TotemNesia.activeTotems[totemName] = true
                TotemNesia.totemTimestamps[totemName] = GetTime()  -- Record placement time
                
                -- Record totem position
                local x, y = GetPlayerMapPosition("player")
                TotemNesia.totemPositions[totemName] = {x = x, y = y}
                
                TotemNesia.hasTotems = true
                
                -- Hide recall notification if showing - player replaced totems instead of recalling
                if iconFrame:IsVisible() then
                    iconFrame:Hide()
                    TotemNesia.displayTimer = nil
                    timerText:SetText("")
                    TotemNesia.monitoringForRecall = false
                    TotemNesia.monitorTimer = 0
                    TotemNesia.DebugPrint("Recall notification cleared - new totems placed")
                end
                
                TotemNesia.DebugPrint("Totem summoned: " .. totemName)
            else
                -- Not a valid totem - ignore it
                TotemNesia.DebugPrint("Ignored non-totem buff with 'Totem' in name: " .. rawName)
            end
        end
        
        if string.find(arg1, "Totemic Recall") then
            -- Clear all active totems
            TotemNesia.activeTotems = {}
            TotemNesia.totemTimestamps = {}  -- Clear timestamps too
            TotemNesia.totemPositions = {}  -- Clear positions too
            TotemNesia.hasTotems = false
            TotemNesia.monitoringForRecall = false
            TotemNesia.monitorTimer = 0
            iconFrame:Hide()
            TotemNesia.displayTimer = nil
            timerText:SetText("")
            TotemNesia.DebugPrint("Manual Totemic Recall detected - flag reset, monitoring stopped")
        end
    elseif event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE" then
        -- Totem dies or expires
        if string.find(arg1, "Totem") and string.find(arg1, "dies") then
            local totemName = string.gsub(arg1, "(.+) dies%.", "%1")
            TotemNesia.activeTotems[totemName] = nil
            TotemNesia.totemTimestamps[totemName] = nil
            TotemNesia.DebugPrint("Totem died: " .. totemName)
            
            -- Check if any totems left
            local anyActive = false
            for _ in pairs(TotemNesia.activeTotems) do
                anyActive = true
                break
            end
            if not anyActive then
                TotemNesia.hasTotems = false
            end
        end
    elseif event == "CHAT_MSG_SPELL_AURA_GONE_SELF" then
        if string.find(arg1, "Totemic Recall") then
            TotemNesia.activeTotems = {}
            TotemNesia.totemTimestamps = {}
            TotemNesia.totemPositions = {}
            TotemNesia.hasTotems = false
            TotemNesia.DebugPrint("Totemic Recall faded - totems gone")
        elseif string.find(arg1, "Totem") then
            -- Individual totem faded
            local totemName = string.gsub(arg1, "(.+) fades from you%.", "%1")
            TotemNesia.activeTotems[totemName] = nil
            TotemNesia.totemTimestamps[totemName] = nil
            TotemNesia.totemPositions[totemName] = nil
            TotemNesia.DebugPrint("Totem faded: " .. totemName)
            
            -- Check if any totems left
            local anyActive = false
            for _ in pairs(TotemNesia.activeTotems) do
                anyActive = true
                break
            end
            if not anyActive then
                TotemNesia.hasTotems = false
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- When UI is hidden, monitor for manual Totemic Recall after combat
        if TotemNesiaDB.hideUIElement and TotemNesia.hasTotems then
            -- Start monitoring for Totemic Recall
            TotemNesia.monitoringForRecall = true
            TotemNesia.monitorTimer = 60  -- Monitor for 60 seconds after combat
            TotemNesia.DebugPrint("UI hidden mode - monitoring for manual Totemic Recall")
        end
    elseif event == "PLAYER_DEAD" then
        -- Player died - all totems despawn
        TotemNesia.activeTotems = {}
        TotemNesia.totemTimestamps = {}
        TotemNesia.totemPositions = {}
        TotemNesia.hasTotems = false
        TotemNesia.monitoringForRecall = false
        TotemNesia.monitorTimer = 0
        iconFrame:Hide()
        TotemNesia.displayTimer = nil
        timerText:SetText("")
        TotemNesia.DebugPrint("Player died - all totems cleared")
    end
end)

-- Function to toggle lock state
function TotemNesia.ToggleLock()
    TotemNesiaDB.isLocked = not TotemNesiaDB.isLocked
    
    if TotemNesiaDB.isLocked then
        iconFrame:SetBackdropColor(0, 0, 0, 0.75)
        iconFrame:RegisterForClicks("LeftButtonUp")
        -- Hide frame if no active timer
        if not TotemNesia.displayTimer or TotemNesia.displayTimer <= 0 then
            iconFrame:Hide()
        end
        TotemNesia.DebugPrint("Frame locked")
    else
        iconFrame:SetBackdropColor(0, 0, 0, 1)
        iconFrame:RegisterForClicks()
        iconFrame:Show()
        TotemNesia.DebugPrint("Frame unlocked. Drag to reposition")
    end
end

-- Function to reset frame position
function TotemNesia.ResetPosition()
    iconFrame:ClearAllPoints()
    iconFrame:SetPoint("CENTER", 0, 200)
    TotemNesia.DebugPrint("Frame position reset to center")
end

-- Sequential totem casting function (cycles through Fire -> Earth -> Water -> Air)
-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("SPELLS_CHANGED")  -- Fires when player learns new spells
eventFrame:RegisterEvent("CHAT_MSG_ADDON")  -- For version checking
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")  -- For broadcasting version on party join
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")  -- For broadcasting version on raid join

eventFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        TotemNesia.InitDB()
        TotemNesia.DetectNampower()
        TotemNesia.UpdateMinimapButton()
        TotemNesia.UpdateTotemTracker()
        TotemNesia.UpdateTotemBar()
        TotemNesia.UpdateTotemBarFlyouts()
        
        -- Refresh flyout icons now that spellbook is loaded
        TotemNesia.RefreshFlyoutIcons()
        
        -- Refresh totem set icons now that spellbook is loaded
        TotemNesia.RefreshTotemSetIcons()
        
        -- Apply scales
        iconFrame:SetScale(TotemNesiaDB.uiFrameScale)
        totemTracker:SetScale(TotemNesiaDB.totemTrackerScale)
        totemBar:SetScale(TotemNesiaDB.totemBarScale)
        
        -- Set Totem Tracker mouse state based on lock setting
        if TotemNesiaDB.totemTrackerLocked then
            totemTracker:EnableMouse(false)
        else
            totemTracker:EnableMouse(true)
        end
        
        -- Set Totem Bar mouse state based on lock setting
        if TotemNesiaDB.totemBarLocked then
            totemBar:EnableMouse(false)
        else
            totemBar:EnableMouse(true)
        end
        
        if TotemNesiaDB.minimapHidden then
            minimapButton:Hide()
        else
            minimapButton:Show()
        end
        
    elseif event == "PLAYER_REGEN_DISABLED" then
        TotemNesia.inCombat = true
        TotemNesia.displayTimer = nil
        TotemNesia.monitoringForRecall = false
        TotemNesia.monitorTimer = 0
        iconFrame:Hide()
        timerText:SetText("")
        TotemNesia.DebugPrint("Entered combat")
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        TotemNesia.inCombat = false
        TotemNesia.DebugPrint("Left combat - hasTotems: " .. tostring(TotemNesia.hasTotems))
        
        -- Check if addon is enabled for current group type
        if not TotemNesia.IsAddonEnabled() then
            TotemNesia.DebugPrint("Addon disabled for current group type")
            return
        end
        
        if IsShaman() and HasTotemsOut() then
            -- Only show UI element if not hidden by setting AND player can use Totemic Recall
            if not TotemNesiaDB.hideUIElement and TotemNesia.CanUseTotemicRecall() then
                TotemNesia.displayTimer = TotemNesiaDB.timerDuration
                iconFrame:Show()
                iconFrame:SetAlpha(1)
                iconFrame:RegisterForClicks("LeftButtonUp")
                TotemNesia.DebugPrint("Showing recall icon")
            else
                if not TotemNesia.CanUseTotemicRecall() then
                    TotemNesia.DebugPrint("Player cannot use Totemic Recall yet - skipping display")
                else
                    TotemNesia.DebugPrint("UI element hidden by setting - skipping display")
                end
            end
            
            -- Play audio only if player can use Totemic Recall
            if TotemNesiaDB.audioEnabled and TotemNesia.CanUseTotemicRecall() then
                PlaySoundFile("Interface\\AddOns\\TotemNesia\\Sounds\\Pick_up_your_totems.wav")
            end
        else
            TotemNesia.hasTotems = false
            TotemNesia.DebugPrint("No totems detected")
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Additional safety check (though we already return early if not Shaman)
        if not IsShaman() then
            this:UnregisterAllEvents()
        else
            -- Refresh flyout icons in case spellbook changed (new totems learned, respec, etc.)
            TotemNesia.RefreshFlyoutIcons()
        end
    
    elseif event == "SPELLS_CHANGED" then
        -- Spellbook changed (learned new spell, respec, etc.) - refresh flyout icons
        TotemNesia.RefreshFlyoutIcons()
        TotemNesia.RefreshTotemSetIcons()
    
    elseif event == "CHAT_MSG_ADDON" then
        -- Version checking via addon messages
        local prefix, message, distribution, sender = arg1, arg2, arg3, arg4
        if prefix == "TotemNesia" then
            local _, _, versionStr = string.find(message, "VER:(%d+)")
            if versionStr then
                TotemNesia.CheckRemoteVersion(versionStr)
            end
        end
    
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        -- Broadcast version when joining/leaving party/raid
        if GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 then
            TotemNesia.BroadcastVersion()
        end
    end
end)

-- Timer frame
local timerFrame = CreateFrame("Frame")
timerFrame:SetScript("OnUpdate", function()
    if TotemNesia.displayTimer and TotemNesia.displayTimer > 0 then
        TotemNesia.displayTimer = TotemNesia.displayTimer - arg1
        
        local secondsLeft = math.ceil(TotemNesia.displayTimer)
        timerText:SetText(secondsLeft)
        
        if TotemNesia.displayTimer <= 0 then
            iconFrame:Hide()
            TotemNesia.displayTimer = nil
            timerText:SetText("")
            TotemNesia.DebugPrint("Timer expired - totems still may be active")
        end
    end
    
    -- Monitor for manual Totemic Recall when UI is hidden
    if TotemNesia.monitoringForRecall and TotemNesia.monitorTimer > 0 then
        TotemNesia.monitorTimer = TotemNesia.monitorTimer - arg1
        
        if TotemNesia.monitorTimer <= 0 then
            -- Timeout - stop monitoring, assume totems were recalled or expired
            TotemNesia.monitoringForRecall = false
            TotemNesia.hasTotems = false
            TotemNesia.DebugPrint("Monitor timeout - assuming totems recalled or expired")
        end
    end
    
    -- Check distance from totems periodically
    TotemNesia.distanceCheckTimer = TotemNesia.distanceCheckTimer + arg1
    if TotemNesia.distanceCheckTimer >= DISTANCE_CHECK_INTERVAL then
        TotemNesia.distanceCheckTimer = 0
        
        if TotemNesia.hasTotems and TotemNesia.CheckTotemDistance() then
            -- Player is too far from totems - show UI only if they can use Totemic Recall
            if not iconFrame:IsVisible() and TotemNesia.CanUseTotemicRecall() then
                iconFrame:Show()
                TotemNesia.displayTimer = TotemNesiaDB.timerDuration
                if TotemNesiaDB.audioEnabled then
                    PlaySoundFile("Interface\\AddOns\\TotemNesia\\Sounds\\Pick_up_your_totems.wav")
                end
                TotemNesia.DebugPrint("Too far from totems - UI shown")
            end
        end
    end
    
    -- Check mana periodically
    TotemNesia.manaCheckTimer = TotemNesia.manaCheckTimer + arg1
    if TotemNesia.manaCheckTimer >= 1.0 then  -- Check every 1 second
        TotemNesia.manaCheckTimer = 0
        
        -- Update cooldown timer
        if TotemNesia.manaAlertCooldown > 0 then
            TotemNesia.manaAlertCooldown = TotemNesia.manaAlertCooldown - 1.0
        end
        
        -- Only check if threshold is > 0
        if TotemNesiaDB.manaThreshold > 0 then
            local currentMana = UnitMana("player")
            local maxMana = UnitManaMax("player")
            
            if maxMana > 0 then
                local manaPercent = (currentMana / maxMana) * 100
                
                -- Check if we just dropped below threshold
                if manaPercent < TotemNesiaDB.manaThreshold and not TotemNesia.belowThreshold then
                    TotemNesia.belowThreshold = true
                    
                    -- Play audio if not muted and cooldown is done
                    if not TotemNesiaDB.manaAudioMuted and TotemNesia.manaAlertCooldown <= 0 then
                        PlaySoundFile("Interface\\AddOns\\TotemNesia\\Sounds\\Your_mana_is_low.wav")
                        TotemNesia.manaAlertCooldown = 30  -- 30-second cooldown
                        TotemNesia.DebugPrint("Low mana alert played: " .. math.floor(manaPercent) .. "%")
                    end
                elseif manaPercent >= TotemNesiaDB.manaThreshold and TotemNesia.belowThreshold then
                    -- Reset flag when we go back above threshold
                    TotemNesia.belowThreshold = false
                    TotemNesia.DebugPrint("Mana restored above threshold")
                end
            end
        end
        
        -- Potion alert logic (hardcoded 80% threshold)
        -- Update potion alert cooldown timer
        if TotemNesia.potionAlertCooldown > 0 then
            TotemNesia.potionAlertCooldown = TotemNesia.potionAlertCooldown - 1.0
        end
        
        -- Check for potion alert at 80% mana
        local currentMana = UnitMana("player")
        local maxMana = UnitManaMax("player")
        
        if maxMana > 0 then
            local manaPercent = (currentMana / maxMana) * 100
            
            -- Check if we just dropped below 80%
            if manaPercent < 80 and not TotemNesia.belowPotionThreshold then
                TotemNesia.belowPotionThreshold = true
                
                -- Play audio if not muted and cooldown is done
                if not TotemNesiaDB.potionAudioMuted and TotemNesia.potionAlertCooldown <= 0 then
                    PlaySoundFile("Interface\\AddOns\\TotemNesia\\Sounds\\Use_a_potion.wav")
                    TotemNesia.potionAlertCooldown = 30
                    TotemNesia.DebugPrint("Potion alert played: " .. math.floor(manaPercent) .. "%")
                end
            elseif manaPercent >= 80 and TotemNesia.belowPotionThreshold then
                -- Reset flag when we go back above 80%
                TotemNesia.belowPotionThreshold = false
                TotemNesia.DebugPrint("Mana restored above potion threshold")
            end
            
            -- Public mana alert logic (hard-coded 15% threshold)
            -- Update public mana alert cooldown timer
            if TotemNesia.publicManaAlertCooldown > 0 then
                TotemNesia.publicManaAlertCooldown = TotemNesia.publicManaAlertCooldown - 1.0
            end
            
            -- Check if we just dropped below 15%
            if manaPercent < 15 and not TotemNesia.belowPublicManaThreshold then
                TotemNesia.belowPublicManaThreshold = true
                
                -- Send chat message if not muted and cooldown is done
                if not TotemNesiaDB.publicManaMuted and TotemNesia.publicManaAlertCooldown <= 0 then
                    SendChatMessage("I am low on mana, I need to drink.", "SAY")
                    TotemNesia.publicManaAlertCooldown = 30
                    TotemNesia.DebugPrint("Public mana alert sent: 15%")
                end
            elseif manaPercent >= 15 and TotemNesia.belowPublicManaThreshold then
                -- Reset flag when we go back above 15%
                TotemNesia.belowPublicManaThreshold = false
                TotemNesia.DebugPrint("Mana restored above public mana threshold")
            end
        end
    end
end)

DEFAULT_CHAT_FRAME:AddMessage("TotemNesia v4.3.2 loaded. Click minimap button for options.")

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
        
        if set.fire and set.fire ~= "" then
            CastSpellByName(set.fire)
            castCount = castCount + 1
        end
        
        if set.earth and set.earth ~= "" then
            CastSpellByName(set.earth)
            castCount = castCount + 1
        end
        
        if set.water and set.water ~= "" then
            CastSpellByName(set.water)
            castCount = castCount + 1
        end
        
        if set.air and set.air ~= "" then
            CastSpellByName(set.air)
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
    
    if TotemNesia.sequentialCastIndex == 1 then
        totemName = set.fire
        familyName = "Fire"
    elseif TotemNesia.sequentialCastIndex == 2 then
        totemName = set.earth
        familyName = "Earth"
    elseif TotemNesia.sequentialCastIndex == 3 then
        totemName = set.water
        familyName = "Water"
    elseif TotemNesia.sequentialCastIndex == 4 then
        totemName = set.air
        familyName = "Air"
    end
    
    -- Cast the totem if one is assigned
    if totemName and totemName ~= "" then
        CastSpellByName(totemName)
        TotemNesia.DebugPrint("Casting " .. totemName .. " (Set " .. setNumber .. ", " .. familyName .. " " .. TotemNesia.sequentialCastIndex .. "/4)")
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
