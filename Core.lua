-- TotemNesia: Setup, saved settings, spellbook cache, and shared helpers
-- (TotemNesia automatically recalls totems after leaving combat and manages them in play)
-- For Turtle WoW (1.12)
-- Version 1.17

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
BINDING_NAME_TOTEM_BAR_1 = "Totem Bar 1 (Fire)"
BINDING_NAME_TOTEM_BAR_2 = "Totem Bar 2 (Earth)"
BINDING_NAME_TOTEM_BAR_3 = "Totem Bar 3 (Water)"
BINDING_NAME_TOTEM_BAR_4 = "Totem Bar 4 (Air)"
BINDING_NAME_TOTEM_SHIELD = "Recast Shield"

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local TOTEM_DISTANCE_THRESHOLD = 30  -- Yards before warning player about totem distance
local DISTANCE_CHECK_INTERVAL = 0.5  -- Seconds between distance checks
-- Newer constants live in one table because a Lua file can only hold 200 local variables
-- at the top level, and TotemNesia is close to that limit.
local TNC = {}
TNC.VISIBILITY_RANGE = 80  -- Past this distance the client may stop "seeing" a totem that is still alive
TNC.MAX_SPELLBOOK_SCAN = 1024  -- Hard upper bound on spellbook scans so a scan can never loop forever

-- Totems whose effect reaches less far than the general range setting.
-- Used for the red "out of range" tint on the totem bar and tracker (SuperWoW only).
TNC.EFFECT_RANGES = {
    ["Searing Totem"] = 20,  -- Attacks enemies within 20 yards
    ["Magma Totem"] = 8      -- Burns enemies within 8 yards
}

-- Seconds between pulses for totems that work in pulses. Drives the thin bar along the
-- bottom of the totem bar icon. Values come from the in-game spell descriptions; confirm
-- on Turtle WoW, which has changed some totems.
TNC.PULSE_INTERVALS = {
    ["Healing Stream Totem"] = 2,
    ["Mana Spring Totem"] = 2,
    ["Magma Totem"] = 2,
    ["Earthbind Totem"] = 3,
    ["Tremor Totem"] = 4,
    ["Poison Cleansing Totem"] = 5,
    ["Disease Cleansing Totem"] = 5
}

-- Anti-Poison / Anti-Disease modes swap the water slot to one of these
TNC.CLEANSING = {
    poison = "Poison Cleansing Totem",
    disease = "Disease Cleansing Totem"
}

-- Weapon imbues as the server may name them on the weapon tooltip ("Windfury 4 (5 min)")
TNC.WEAPON_IMBUES = {
    {base = "Rockbiter", spell = "Rockbiter Weapon"},
    {base = "Flametongue", spell = "Flametongue Weapon"},
    {base = "Frostbrand", spell = "Frostbrand Weapon"},
    {base = "Windfury", spell = "Windfury Weapon"}
}

-- Shields the shield slot can track and recast
TNC.SHIELD_SPELLS = {
    "Lightning Shield",
    "Water Shield",
    "Earth Shield"
}

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
TotemNesia.hasSuperWoW = false  -- Whether SuperWoW is detected (enables totem unit tracking)
TotemNesia.totemUnits = {}  -- totemName -> SuperWoW unit ID of the totem itself
TotemNesia.spellCache = {}  -- spellName -> { id = highest-rank spellbook index, texture = icon path }
TotemNesia.spellCacheReady = false  -- True once the spellbook has been scanned with results
TotemNesia.hasTotemicMasteryCached = nil  -- nil = not checked yet since login/talent change
TotemNesia.detectedWeaponEnchant = nil  -- Imbue actually found on the main hand weapon
TotemNesia.weaponScanTimer = 0  -- Seconds since the last weapon tooltip scan
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

-- Check for SuperWoW. It adds UnitPosition() and gives totems their own unit IDs,
-- which lets us track each totem's real position and notice the moment it is destroyed.
function TotemNesia.DetectSuperWoW()
    if type(UnitPosition) == "function" then
        TotemNesia.hasSuperWoW = true
        if TotemNesia.DebugPrint then
            TotemNesia.DebugPrint("SuperWoW detected - totem unit tracking enabled")
        end
        return true
    end
    TotemNesia.hasSuperWoW = false
    return false
end

-- ============================================================================
-- SPELLBOOK CACHE
-- ============================================================================
-- The spellbook is scanned once and kept in a lookup table. It is rebuilt at login
-- and whenever SPELLS_CHANGED fires. Everything else reads from the table instead of
-- walking the spellbook again.
function TotemNesia.BuildSpellCache()
    local cache = {}
    local count = 0
    for i = 1, TNC.MAX_SPELLBOOK_SCAN do
        local spellName = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            break
        end
        -- Ranks are listed lowest to highest, so the last match is the highest rank
        cache[spellName] = { id = i, texture = GetSpellTexture(i, BOOKTYPE_SPELL) }
        count = count + 1
    end
    TotemNesia.spellCache = cache
    -- The spellbook is empty very early in loading; keep rescanning until it has spells
    TotemNesia.spellCacheReady = (count > 0)
    return count
end

-- Look up a spell in the cache (builds the cache on first use)
function TotemNesia.GetCachedSpell(spellName)
    if not spellName then
        return nil
    end
    if not TotemNesia.spellCacheReady then
        TotemNesia.BuildSpellCache()
    end
    return TotemNesia.spellCache[spellName]
end

-- Get addon version from TOC file (e.g., "3.4.41")
function TotemNesia.GetVersion()
    return tostring(GetAddOnMetadata("TotemNesia", "Version"))
end

-- Convert version string to comparable number (e.g., "3.4.41" -> 30441)
function TotemNesia.GetVersionNumber()
    local versionStr = TotemNesia.GetVersion()
    -- Works for two-part ("1.17") and three-part ("1.17.1") versions
    local _, _, major, minor, patch = string.find(versionStr, "(%d+)%.?(%d*)%.?(%d*)")
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
    if TotemNesiaDB.alertVoice == nil then
        TotemNesiaDB.alertVoice = "Jenny"
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
        if TotemNesia.GetCachedSpell("Totemic Recall") then
            hasTotemicRecall = true
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
    if TotemNesiaDB.totemRange == nil then
        TotemNesiaDB.totemRange = TOTEM_DISTANCE_THRESHOLD  -- 30 yards, same as before this setting existed
    end
    if TotemNesiaDB.totemBarFallbacks == nil then
        TotemNesiaDB.totemBarFallbacks = {}
    end
    if TotemNesiaDB.hideShieldSlot == nil then
        TotemNesiaDB.hideShieldSlot = false
    end
    if TotemNesiaDB.shieldFlash == nil then
        TotemNesiaDB.shieldFlash = true
    end
    -- cleansingMode (nil / "poison" / "disease") and shieldSpell default to nil
end

-- Debug print function
function TotemNesia.DebugPrint(msg)
    if TotemNesiaDB and TotemNesiaDB.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia DEBUG: " .. msg)
    end
end

-- Voice actors for the audio alerts (picked in the Settings tab). Each one needs three files
-- in Sounds: "Totems - <name>.mp3", "Low Mana - <name>.mp3", "Mana Potion - <name>.mp3".
-- To add a voice, add the files and put the name in this list.
TNC.VOICES = {"Jenny", "Aria", "Roger"}

-- Play a voice alert. Files live in Sounds as "<alert> - <voice>.mp3",
-- e.g. "Totems - Jenny.mp3". Alerts: "Totems", "Low Mana", "Mana Potion".
-- The voice comes from TotemNesiaDB.alertVoice (default "Jenny").
function TotemNesia.PlayAlertSound(alert)
    local voice = (TotemNesiaDB and TotemNesiaDB.alertVoice) or "Jenny"
    PlaySoundFile("Interface\\AddOns\\TotemNesia\\Sounds\\" .. alert .. " - " .. voice .. ".mp3")
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
    local info = TotemNesia.GetCachedSpell(totemName)
    if info and info.texture then
        return info.texture
    end
    return "Interface\\Icons\\Spell_Nature_Reincarnation"
end

-- Check if a totem/spell is learned
function IsTotemLearned(totemName)
    if TotemNesia.GetCachedSpell(totemName) then
        return true
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
    ["Fire Resistance Totem"] = 120,
    ["Mana Spring Totem"] = 60,
    ["Healing Stream Totem"] = 60,
    
    -- Air Totems
    ["Windwall Totem"] = 120,
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
-- Result is cached; the cache is cleared at login and when talent points change
local function HasTotemicMastery()
    if TotemNesia.hasTotemicMasteryCached ~= nil then
        return TotemNesia.hasTotemicMasteryCached
    end
    local numTabs = GetNumTalentTabs()
    if not numTabs or numTabs == 0 then
        return false  -- Talent data not available yet, check again later
    end
    local found = false
    for t = 1, numTabs do
        local numTalents = GetNumTalents(t)
        for i = 1, numTalents do
            local name, _, _, _, rank = GetTalentInfo(t, i)
            if name == "Totemic Mastery" and rank and rank > 0 then
                found = true
            end
        end
    end
    TotemNesia.hasTotemicMasteryCached = found
    return found
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

-- Every totem TotemNesia knows, mapped to its element. Lookups are a single table read.
TNC.TOTEM_ELEMENTS = {
    -- Fire
    ["Searing Totem"] = "fire", ["Fire Nova Totem"] = "fire", ["Magma Totem"] = "fire",
    ["Flametongue Totem"] = "fire", ["Frost Resistance Totem"] = "fire",
    -- Water
    ["Healing Stream Totem"] = "water", ["Mana Spring Totem"] = "water", ["Mana Tide Totem"] = "water",
    ["Disease Cleansing Totem"] = "water", ["Poison Cleansing Totem"] = "water", ["Fire Resistance Totem"] = "water",
    -- Earth
    ["Stoneclaw Totem"] = "earth", ["Stoneskin Totem"] = "earth", ["Earthbind Totem"] = "earth",
    ["Tremor Totem"] = "earth", ["Strength of Earth Totem"] = "earth",
    -- Air
    ["Windfury Totem"] = "air", ["Grace of Air Totem"] = "air", ["Windwall Totem"] = "air",
    ["Grounding Totem"] = "air", ["Nature Resistance Totem"] = "air", ["Tranquil Air Totem"] = "air"
}
TNC.normalizedTotemNames = {}  -- Remembers "Searing Totem IV" -> "Searing Totem" after the first lookup

-- Function to check if a name is actually a valid totem
-- This prevents false positives from buffs/items with "Totem" in the name.
-- Returns true plus the standard name (e.g. "Searing Totem IV" -> "Searing Totem").
local function IsValidTotem(name)
    if not name then
        return false, nil
    end
    -- Exact name (most common)
    if TNC.TOTEM_ELEMENTS[name] then
        return true, name
    end
    -- Seen this variant before
    local known = TNC.normalizedTotemNames[name]
    if known then
        return true, known
    end
    -- Name with extra text, such as a rank: find the known totem inside it
    for totemName, _ in pairs(TNC.TOTEM_ELEMENTS) do
        if string.find(name, totemName, 1, true) then
            TNC.normalizedTotemNames[name] = totemName
            return true, totemName
        end
    end
    return false, nil
end

-- Function to find the highest learned rank of a spell/totem
-- Returns the spell ID of the highest rank, or nil if not found
local function GetHighestLearnedRank(baseName)
    local info = TotemNesia.GetCachedSpell(baseName)
    if info then
        return info.id
    end
    return nil
end

-- Function to get totem element type ("fire", "earth", "water", "air", or nil)
local function GetTotemElement(totemName)
    if not totemName then
        return nil
    end
    local element = TNC.TOTEM_ELEMENTS[totemName]
    if element then
        return element
    end
    local isValid, standardName = IsValidTotem(totemName)
    if isValid then
        return TNC.TOTEM_ELEMENTS[standardName]
    end
    return nil
end

-- ============================================================================
-- SHARED HELPERS (range, timers, casting, totem tracking, shields, imbues)
-- ============================================================================

-- Range used for the recall reminder and the general out-of-range check
function TotemNesia.GetGeneralRange()
    return (TotemNesiaDB and TotemNesiaDB.totemRange) or TOTEM_DISTANCE_THRESHOLD
end

-- How far a specific totem's effect reaches
function TotemNesia.GetTotemRange(totemName)
    if totemName and TNC.EFFECT_RANGES[totemName] then
        return TNC.EFFECT_RANGES[totemName]
    end
    return TotemNesia.GetGeneralRange()
end

-- Straight-line distance between two world positions (yards)
function TNC.WorldDistance(x1, y1, z1, x2, y2, z2)
    local dx = x1 - x2
    local dy = y1 - y2
    local dz = (z1 or 0) - (z2 or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Distance from the player to a totem in yards (SuperWoW only, otherwise nil)
function TotemNesia.GetTotemDistance(totemName)
    if not TotemNesia.hasSuperWoW then
        return nil
    end
    local px, py, pz = UnitPosition("player")
    if not px or not py then
        return nil
    end
    local tx, ty, tz
    local unit = TotemNesia.totemUnits[totemName]
    if unit and UnitExists(unit) then
        tx, ty, tz = UnitPosition(unit)
    end
    if not tx then
        -- Totem unit not visible right now; use where it was last seen
        local pos = TotemNesia.totemPositions[totemName]
        if pos and pos.world then
            tx, ty, tz = pos.x, pos.y, pos.z
        end
    end
    if not tx or not ty then
        return nil
    end
    return TNC.WorldDistance(px, py, pz, tx, ty, tz)
end

-- Timer text color: white normally, gold in the last quarter, red in the last 5 seconds
function TotemNesia.GetTimerColor(remaining, duration)
    if remaining <= 5 then
        return 1, 0.2, 0.2
    end
    if duration and duration > 0 and (remaining / duration) <= 0.25 then
        return 1, 0.82, 0
    end
    return 1, 1, 1
end

-- Tooltip anchoring. When pfUI is loaded, use the default anchor so the tooltip follows
-- the position configured in pfUI. Otherwise anchor next to the frame like before.
function TotemNesia.SetTooltipOwner(frame, anchor)
    if pfUI and GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, frame)
    else
        GameTooltip:SetOwner(frame, anchor or "ANCHOR_RIGHT")
    end
end

-- Set a texture only when the path changes (the update loop runs twice a second)
function TNC.SetIcon(texture, path)
    if texture.tnPath ~= path then
        texture:SetTexture(path)
        texture.tnPath = path
    end
end

-- True if a spell is on a real cooldown. The global cooldown (1.5s or less) is ignored so
-- that casting one totem doesn't make the next one look unavailable (matters for Nampower).
function TotemNesia.IsSpellOnCooldown(spellName)
    local info = TotemNesia.GetCachedSpell(spellName)
    if not info then
        return false
    end
    local start, duration = GetSpellCooldown(info.id, BOOKTYPE_SPELL)
    if start and start > 0 and duration and duration > 1.5 then
        return true
    end
    return false
end

-- Work out which totem should actually be cast for an element:
-- 1. Anti-Poison / Anti-Disease mode replaces the water totem with a cleansing totem
-- 2. If that totem is on cooldown and the element has a fallback, use the fallback
-- Returns totemName, usedFallback
function TotemNesia.ResolveTotemForElement(element, totemName)
    if element == "water" and TotemNesiaDB and TotemNesiaDB.cleansingMode then
        local cleansing = TNC.CLEANSING[TotemNesiaDB.cleansingMode]
        if cleansing and IsTotemLearned(cleansing) then
            totemName = cleansing
        end
    end
    if totemName and totemName ~= "" and TotemNesia.IsSpellOnCooldown(totemName) then
        local fallbacks = TotemNesiaDB and TotemNesiaDB.totemBarFallbacks
        local fallback = fallbacks and fallbacks[element]
        if fallback and fallback ~= totemName and IsTotemLearned(fallback) and not TotemNesia.IsSpellOnCooldown(fallback) then
            return fallback, true
        end
    end
    return totemName, false
end

-- Cast the right totem for an element (applies cleansing mode and fallbacks)
-- queue = true is used when several totems are cast from one keypress (Nampower).
-- Those casts go through CastSpell with the spellbook index, the same path as action
-- bar buttons, which Nampower queues so every totem lands. CastSpellByName and
-- QueueSpellByName calls in the same keypress collide and only the first totem drops.
-- (Same approach as SuperTotem.)
function TotemNesia.CastTotemForElement(element, totemName, queue)
    local toCast, usedFallback = TotemNesia.ResolveTotemForElement(element, totemName)
    if toCast and toCast ~= "" then
        local info = queue and TotemNesia.GetCachedSpell(toCast)
        if info then
            CastSpell(info.id, BOOKTYPE_SPELL)
        else
            CastSpellByName(toCast)
        end
        if usedFallback then
            TotemNesia.DebugPrint(tostring(totemName) .. " on cooldown - cast fallback " .. toCast)
        end
        return toCast
    end
    return nil
end

-- Forget a totem (expired, destroyed, replaced, or recalled)
function TotemNesia.RemoveTotem(totemName, reason)
    TotemNesia.activeTotems[totemName] = nil
    TotemNesia.totemTimestamps[totemName] = nil
    TotemNesia.totemPositions[totemName] = nil
    TotemNesia.totemUnits[totemName] = nil
    if next(TotemNesia.activeTotems) == nil then
        TotemNesia.hasTotems = false
    end
    if reason then
        TotemNesia.DebugPrint("Totem removed (" .. reason .. "): " .. totemName)
    end
end

-- Forget every totem (Totemic Recall, death)
function TotemNesia.ClearAllTotems()
    TotemNesia.activeTotems = {}
    TotemNesia.totemTimestamps = {}
    TotemNesia.totemPositions = {}
    TotemNesia.totemUnits = {}
    TotemNesia.hasTotems = false
end

-- Record a newly placed totem. Called from the combat log, and from SuperWoW when the
-- totem unit appears. Both can report the same drop, so a second report within 2 seconds
-- is ignored. Returns true if this was a new drop.
function TotemNesia.RegisterTotem(totemName)
    local now = GetTime()
    local lastTime = TotemNesia.totemTimestamps[totemName]
    if TotemNesia.activeTotems[totemName] and lastTime and (now - lastTime) < 2 then
        return false
    end

    -- Only one totem per element can be active
    local newElement = GetTotemElement(totemName)
    if newElement then
        for existingTotem, _ in pairs(TotemNesia.activeTotems) do
            if GetTotemElement(existingTotem) == newElement then
                TotemNesia.RemoveTotem(existingTotem, "replaced")
            end
        end
    end

    TotemNesia.activeTotems[totemName] = true
    TotemNesia.totemTimestamps[totemName] = now

    -- Starting position is where the player stands; SuperWoW replaces it with the
    -- totem's own position once the totem unit shows up
    if TotemNesia.hasSuperWoW then
        local x, y, z = UnitPosition("player")
        if x and y then
            TotemNesia.totemPositions[totemName] = {x = x, y = y, z = z, world = true}
        end
    else
        local x, y = GetPlayerMapPosition("player")
        TotemNesia.totemPositions[totemName] = {x = x, y = y}
    end

    TotemNesia.hasTotems = true
    return true
end

-- SuperWoW: a unit appeared. If it is one of our totems, remember its unit ID and position.
-- Returns true if this registered a new totem drop.
function TotemNesia.OnTotemUnitSeen(unit)
    if not TotemNesia.hasSuperWoW or not unit or type(unit) ~= "string" then
        return false
    end
    -- Only accept real unit IDs (GUIDs), not tokens like "target" that point at different units over time
    if not string.find(unit, "^0x") then
        return false
    end
    local unitName = UnitName(unit)
    if not unitName or not string.find(unitName, "Totem") then
        return false
    end
    if UnitName(unit .. "owner") ~= UnitName("player") then
        return false
    end
    local isValid, totemName = IsValidTotem(unitName)
    if not isValid then
        return false
    end
    -- Fire Nova Totem is ignored everywhere else in TotemNesia (it self-destructs)
    if totemName == "Fire Nova Totem" then
        return false
    end
    if TotemNesia.totemUnits[totemName] == unit then
        return false  -- Already tracking this exact totem
    end

    local isNew = false
    if not TotemNesia.activeTotems[totemName] then
        if not TotemNesia.IsAddonEnabled() then
            return false
        end
        isNew = TotemNesia.RegisterTotem(totemName)
    end

    TotemNesia.totemUnits[totemName] = unit
    local x, y, z = UnitPosition(unit)
    if x and y then
        TotemNesia.totemPositions[totemName] = {x = x, y = y, z = z, world = true}
    end
    TotemNesia.DebugPrint("SuperWoW linked " .. totemName .. " to unit " .. unit)
    return isNew
end

-- SuperWoW: drop any totem whose unit is gone (killed, destroyed, or expired early).
-- Returns true if anything was removed.
function TotemNesia.CheckTotemUnits()
    if not TotemNesia.hasSuperWoW then
        return false
    end
    local removedAny = false
    local playerName = UnitName("player")
    for totemName, unit in pairs(TotemNesia.totemUnits) do
        if not UnitExists(unit) then
            -- Very far away, the client stops seeing units that are still alive. In that case
            -- stop watching the unit and let the normal timer expire the totem instead.
            local pos = TotemNesia.totemPositions[totemName]
            local px, py, pz = UnitPosition("player")
            local tooFarToSee = false
            if pos and pos.world and px and py then
                tooFarToSee = TNC.WorldDistance(px, py, pz, pos.x, pos.y, pos.z) > TNC.VISIBILITY_RANGE
            end
            if tooFarToSee then
                TotemNesia.totemUnits[totemName] = nil
                TotemNesia.DebugPrint(totemName .. " out of sight - falling back to its timer")
            else
                TotemNesia.RemoveTotem(totemName, "destroyed")
                removedAny = true
            end
        elseif UnitName(unit .. "owner") ~= playerName then
            TotemNesia.RemoveTotem(totemName, "no longer ours")
            removedAny = true
        end
    end
    return removedAny
end

-- Shield currently on the player: returns shieldName, charges (or nil, 0)
function TotemNesia.GetActiveShield()
    for i = 1, 32 do
        local texture, applications = UnitBuff("player", i)
        if not texture then
            break
        end
        local lowerTexture = string.lower(texture)
        for _, shieldName in ipairs(TNC.SHIELD_SPELLS) do
            local info = TotemNesia.GetCachedSpell(shieldName)
            if info and info.texture and string.lower(info.texture) == lowerTexture then
                return shieldName, (applications or 0)
            end
        end
    end
    return nil, 0
end

-- Shield the shield slot should cast: the one picked from the flyout, otherwise the first learned
function TotemNesia.GetChosenShield()
    if TotemNesiaDB and TotemNesiaDB.shieldSpell and IsTotemLearned(TotemNesiaDB.shieldSpell) then
        return TotemNesiaDB.shieldSpell
    end
    for _, shieldName in ipairs(TNC.SHIELD_SPELLS) do
        if IsTotemLearned(shieldName) then
            return shieldName
        end
    end
    return nil
end

-- Hidden tooltip used to read the imbue name off the main hand weapon
TNC.scanTooltip = CreateFrame("GameTooltip", "TotemNesiaScanTooltip", nil, "GameTooltipTemplate")

-- Read which imbue is on the main hand weapon. The server may call it "Windfury 4" instead of
-- "Windfury Weapon", so we match on the start of the line and ignore the rank number.
-- Returns the imbue spell name (e.g. "Windfury Weapon") or nil.
function TotemNesia.DetectWeaponImbue()
    local slotId = GetInventorySlotInfo("MainHandSlot")
    if not slotId then
        return nil
    end
    TNC.scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    TNC.scanTooltip:ClearLines()
    TNC.scanTooltip:SetInventoryItem("player", slotId)
    local numLines = TNC.scanTooltip:NumLines() or 0
    for i = 2, numLines do  -- Line 1 is the item name
        local line = getglobal("TotemNesiaScanTooltipTextLeft" .. i)
        local text = line and line:GetText()
        -- Temporary enchants show a duration in brackets, e.g. "(5 min)" or "(30 sec)"
        if text and string.find(text, "%(%d+ ") then
            for _, imbue in ipairs(TNC.WEAPON_IMBUES) do
                if string.find(text, "^" .. imbue.base) then
                    TNC.scanTooltip:Hide()
                    return imbue.spell
                end
            end
        end
    end
    TNC.scanTooltip:Hide()
    return nil
end

-- Function to check if player is a shaman
local function IsShaman()
    local _, class = UnitClass("player")
    return class == "SHAMAN"
end


-- Share with files loaded after this one
TotemNesia.shared = TotemNesia.shared or {}
TotemNesia.shared.DISTANCE_CHECK_INTERVAL = DISTANCE_CHECK_INTERVAL
TotemNesia.shared.GetHighestLearnedRank = GetHighestLearnedRank
TotemNesia.shared.GetTotemDuration = GetTotemDuration
TotemNesia.shared.GetTotemElement = GetTotemElement
TotemNesia.shared.IsShaman = IsShaman
TotemNesia.shared.IsValidTotem = IsValidTotem
TotemNesia.shared.TNC = TNC
