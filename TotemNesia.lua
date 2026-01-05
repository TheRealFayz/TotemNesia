-- TotemNesia: Automatically recalls totems after leaving combat
-- For Turtle WoW (1.12)
-- Version 3.0

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
        TotemNesiaDB.hideUIElement = false
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
            air = nil
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
    if TotemNesiaDB.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia DEBUG: " .. msg)
    end
end

-- Function to check if addon should be active based on group settings
function TotemNesia.IsAddonEnabled()
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

-- Function to get totem icon texture
local function GetTotemIcon(totemName)
    local i = 1
    while true do
        local spellName = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            break
        end
        if spellName == totemName then
            return GetSpellTexture(i, BOOKTYPE_SPELL)
        end
        i = i + 1
    end
    return "Interface\\Icons\\Spell_Nature_Reincarnation"
end

-- Function to get totem duration in seconds
local function GetTotemDuration(totemName)
    -- Most totems last 2 minutes (120 seconds)
    -- Some exceptions:
    if string.find(totemName, "Earthbind") or string.find(totemName, "Stoneclaw") then
        return 45  -- 45 seconds
    elseif string.find(totemName, "Grounding") then
        return 45  -- 45 seconds
    elseif string.find(totemName, "Fire Nova") then
        return 5   -- 5 seconds (though we ignore this totem)
    elseif string.find(totemName, "Searing") then
        return 55  -- 55 seconds (rank dependent, using average)
    end
    -- Default duration for most totems
    return 120
end

-- Function to get totem element type
local function GetTotemElement(totemName)
    -- Fire totems
    if string.find(totemName, "Searing") or string.find(totemName, "Fire Nova") or 
       string.find(totemName, "Magma") or string.find(totemName, "Flametongue") or
       string.find(totemName, "Fire Resistance") or string.find(totemName, "Frost Resistance") then
        return "fire"
    end
    
    -- Water totems
    if string.find(totemName, "Healing Stream") or string.find(totemName, "Mana Spring") or
       string.find(totemName, "Mana Tide") or string.find(totemName, "Disease Cleansing") or
       string.find(totemName, "Poison Cleansing") then
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
        "Flametongue Totem",
        "Totem of Wrath"
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
        "Fire Resistance Totem",
        "Disease Cleansing Totem",
        "Poison Cleansing Totem",
        "Mana Tide Totem"
    },
    air = {
        "Grounding Totem",
        "Windfury Totem",
        "Grace of Air Totem",
        "Nature Resistance Totem",
        "Tranquil Air Totem",
        "Windwall Totem"
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

-- Create 4 element slots (Fire, Earth, Water, Air)
local elementOrder = {"fire", "earth", "water", "air"}
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
    iconTexture:SetAllPoints(slot)
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
    local iconSize = 24
    local iconSpacing = 2
    local numTotems = table.getn(totems)
    
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
        
        -- Tooltip on hover
        button:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            -- Search for the spell in the spellbook
            local spellName = this.totemName
            local i = 1
            while true do
                local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
                if not name then
                    break
                end
                if name == spellName then
                    GameTooltip:SetSpell(i, BOOKTYPE_SPELL)
                    GameTooltip:Show()
                    this:SetBackdropBorderColor(1, 1, 0, 1)
                    return
                end
                i = i + 1
            end
            -- Fallback if spell not found in book
            GameTooltip:SetText(spellName, 1, 1, 1)
            GameTooltip:Show()
            this:SetBackdropBorderColor(1, 1, 0, 1)
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
            this:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end)
        
        -- Click handling
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnClick", function()
            if IsControlKeyDown() then
                -- Ctrl-click: Set as default totem for this slot
                local elem = this.element
                TotemNesiaDB.totemBarSlots[elem] = this.totemName
                local slotBtn = TotemNesia.totemBarSlots[elem]
                if slotBtn then
                    slotBtn.iconTexture:SetTexture(GetTotemIcon(this.totemName))
                    slotBtn.iconTexture:SetAlpha(1)
                    slotBtn.selectedTotem = this.totemName
                    DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: " .. this.totemName .. " set to " .. elem .. " slot")
                else
                    DEFAULT_CHAT_FRAME:AddMessage("TotemNesia DEBUG: slotBtn is nil for element: " .. tostring(elem))
                end
                flyout.hideTime = nil
                flyout:Hide()
            else
                -- Normal click: Cast totem without updating slot
                CastSpellByName(this.totemName)
                flyout.hideTime = nil
                flyout:Hide()
            end
        end)
    end
    
    -- Slot mouse events for flyout
    slot:SetScript("OnEnter", function()
        this.flyout:Show()
        this.flyout.hideTime = nil  -- Cancel any pending hide
        this.flyout.slotEntered = true
    end)
    
    slot:SetScript("OnLeave", function()
        -- Start 1 second timer before hiding
        this.flyout.hideTime = GetTime() + 1
        this.flyout.slotEntered = false
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
        if this.hideTime then
            local timeNow = GetTime()
            if timeNow >= this.hideTime then
                -- Check if mouse is over flyout or slot
                if not MouseIsOver(this) and not this.slotEntered then
                    this:Hide()
                    this.hideTime = nil
                    this.slotEntered = false
                else
                    -- Mouse came back, cancel hide
                    this.hideTime = nil
                end
            end
        end
    end)
    
    -- Slot click to cast selected totem
    slot:RegisterForClicks("LeftButtonUp")
    slot:SetScript("OnClick", function()
        if this.selectedTotem then
            CastSpellByName(this.selectedTotem)
        end
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
    local elementOrder = {"fire", "earth", "water", "air"}
    
    if isVertical then
        -- Vertical layout
        totemBar:SetWidth(slotSize + 8)
        totemBar:SetHeight((4 * slotSize) + (3 * slotSpacing) + 8)
        
        for i, element in ipairs(elementOrder) do
            local slot = TotemNesia.totemBarSlots[element]
            if slot then
                slot:ClearAllPoints()
                slot:SetPoint("TOP", totemBar, "TOP", 0, -4 - ((i-1) * (slotSize + slotSpacing)))
            end
        end
    else
        -- Horizontal layout
        totemBar:SetWidth((4 * slotSize) + (3 * slotSpacing) + 8)
        totemBar:SetHeight(slotSize + 8)
        
        for i, element in ipairs(elementOrder) do
            local slot = TotemNesia.totemBarSlots[element]
            if slot then
                slot:ClearAllPoints()
                slot:SetPoint("LEFT", totemBar, "LEFT", 4 + ((i-1) * (slotSize + slotSpacing)), 0)
            end
        end
    end
    
    -- Update each slot
    for element, slot in pairs(TotemNesia.totemBarSlots) do
        -- Restore saved totem selection
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

-- Function to update flyout directions
function TotemNesia.UpdateTotemBarFlyouts()
    local direction = TotemNesiaDB.totemBarFlyoutDirection
    local iconSize = 24
    local iconSpacing = 2
    
    if TotemNesiaDB.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: UpdateTotemBarFlyouts called, direction = " .. tostring(direction))
    end
    
    for element, slot in pairs(TotemNesia.totemBarSlots) do
        local flyout = slot.flyout
        if flyout then
            local totems = TotemNesia.totemLists[element]
            local numTotems = table.getn(totems)
            
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
            texture:SetTexture(GetTotemIcon(totemName))
            icon.texture = texture
            
            -- Add timer text
            local timerText = icon:CreateFontString(nil, "OVERLAY")
            timerText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            timerText:SetPoint("BOTTOM", icon, "BOTTOM", 0, 0)
            timerText:SetTextColor(1, 1, 1)
            icon.timerText = timerText
            
            TotemNesia.totemTrackerIcons[totemName] = icon
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
optionsMenu:SetHeight(520)
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
menuTitle:SetText("TotemNesia Options")

-- Version number
local versionText = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
versionText:SetPoint("TOP", 0, -35)
versionText:SetText("v3.0")
versionText:SetTextColor(0.7, 0.7, 0.7, 1)

-- Close button (X in upper right)
local closeButton = CreateFrame("Button", nil, optionsMenu)
closeButton:SetWidth(20)
closeButton:SetHeight(20)
closeButton:SetPoint("TOPRIGHT", -10, -10)

-- Create X texture
local closeText = closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
closeText:SetPoint("CENTER", 0, 0)
closeText:SetText("X")
closeText:SetTextColor(1, 0.2, 0.2)

-- Hover effect
closeButton:SetScript("OnEnter", function()
    closeText:SetTextColor(1, 0, 0)
end)
closeButton:SetScript("OnLeave", function()
    closeText:SetTextColor(1, 0.2, 0.2)
end)
closeButton:SetScript("OnClick", function()
    optionsMenu:Hide()
end)

-- LEFT COLUMN
-- Lock UI Frame checkbox
local lockCheckbox = CreateFrame("CheckButton", "TotemNesiaLockCheckbox", optionsMenu, "UICheckButtonTemplate")
lockCheckbox:SetPoint("TOPLEFT", 20, -45)
lockCheckbox:SetWidth(24)
lockCheckbox:SetHeight(24)
local lockLabel = lockCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lockLabel:SetPoint("LEFT", lockCheckbox, "RIGHT", 5, 0)
lockLabel:SetText("Lock UI Frame")
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
local muteCheckbox = CreateFrame("CheckButton", "TotemNesiaMuteCheckbox", optionsMenu, "UICheckButtonTemplate")
muteCheckbox:SetPoint("TOPLEFT", 20, -75)
muteCheckbox:SetWidth(24)
muteCheckbox:SetHeight(24)
local muteLabel = muteCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
muteLabel:SetPoint("LEFT", muteCheckbox, "RIGHT", 5, 0)
muteLabel:SetText("Mute audio queue")
muteCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.audioEnabled = not this:GetChecked()
end)

-- Hide UI element checkbox
local hideUICheckbox = CreateFrame("CheckButton", "TotemNesiaHideUICheckbox", optionsMenu, "UICheckButtonTemplate")
hideUICheckbox:SetPoint("TOPLEFT", 20, -105)
hideUICheckbox:SetWidth(24)
hideUICheckbox:SetHeight(24)
local hideUILabel = hideUICheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hideUILabel:SetPoint("LEFT", hideUICheckbox, "RIGHT", 5, 0)
hideUILabel:SetText("Hide UI element")
hideUICheckbox:SetScript("OnClick", function()
    TotemNesiaDB.hideUIElement = this:GetChecked() and true or false
end)

-- Enable Totem Bar checkbox
local enableTotemBarCheckbox = CreateFrame("CheckButton", "TotemNesiaEnableTotemBarCheckbox", optionsMenu, "UICheckButtonTemplate")
enableTotemBarCheckbox:SetPoint("TOPLEFT", 20, -135)
enableTotemBarCheckbox:SetWidth(24)
enableTotemBarCheckbox:SetHeight(24)
local enableTotemBarLabel = enableTotemBarCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
enableTotemBarLabel:SetPoint("LEFT", enableTotemBarCheckbox, "RIGHT", 5, 0)
enableTotemBarLabel:SetText("Enable Totem Bar")
enableTotemBarCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.totemBarEnabled = this:GetChecked() and true or false
    TotemNesia.UpdateTotemBar()
end)

-- RIGHT COLUMN
-- Lock Totem Tracker checkbox
local lockTotemBarCheckbox = CreateFrame("CheckButton", "TotemNesiaLockTotemBarCheckbox", optionsMenu, "UICheckButtonTemplate")
lockTotemBarCheckbox:SetPoint("TOPLEFT", 210, -45)
lockTotemBarCheckbox:SetWidth(24)
lockTotemBarCheckbox:SetHeight(24)
local lockTotemBarLabel = lockTotemBarCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lockTotemBarLabel:SetPoint("LEFT", lockTotemBarCheckbox, "RIGHT", 5, 0)
lockTotemBarLabel:SetText("Lock Totem Tracker")
lockTotemBarCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.totemTrackerLocked = this:GetChecked() and true or false
    if TotemNesiaDB.totemTrackerLocked then
        totemTracker:EnableMouse(false)
    else
        totemTracker:EnableMouse(true)
    end
end)

-- Hide Totem Tracker checkbox
local hideTotemBarCheckbox = CreateFrame("CheckButton", "TotemNesiaHideTotemBarCheckbox", optionsMenu, "UICheckButtonTemplate")
hideTotemBarCheckbox:SetPoint("TOPLEFT", 210, -75)
hideTotemBarCheckbox:SetWidth(24)
hideTotemBarCheckbox:SetHeight(24)
local hideTotemBarLabel = hideTotemBarCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hideTotemBarLabel:SetPoint("LEFT", hideTotemBarCheckbox, "RIGHT", 5, 0)
hideTotemBarLabel:SetText("Hide Totem Tracker")
hideTotemBarCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.totemTrackerHidden = this:GetChecked() and true or false
    TotemNesia.UpdateTotemTracker()
end)

-- Lock Totem Bar checkbox
local lockTotemBarCastCheckbox = CreateFrame("CheckButton", "TotemNesiaLockTotemBarCastCheckbox", optionsMenu, "UICheckButtonTemplate")
lockTotemBarCastCheckbox:SetPoint("TOPLEFT", 210, -105)
lockTotemBarCastCheckbox:SetWidth(24)
lockTotemBarCastCheckbox:SetHeight(24)
local lockTotemBarCastLabel = lockTotemBarCastCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lockTotemBarCastLabel:SetPoint("LEFT", lockTotemBarCastCheckbox, "RIGHT", 5, 0)
lockTotemBarCastLabel:SetText("Lock Totem Bar")
lockTotemBarCastCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.totemBarLocked = this:GetChecked() and true or false
    if TotemNesiaDB.totemBarLocked then
        totemBar:EnableMouse(false)
    else
        totemBar:EnableMouse(true)
    end
end)

-- Hide Totem Bar checkbox
local hideTotemBarCastCheckbox = CreateFrame("CheckButton", "TotemNesiaHideTotemBarCastCheckbox", optionsMenu, "UICheckButtonTemplate")
hideTotemBarCastCheckbox:SetPoint("TOPLEFT", 210, -135)
hideTotemBarCastCheckbox:SetWidth(24)
hideTotemBarCastCheckbox:SetHeight(24)
local hideTotemBarCastLabel = hideTotemBarCastCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hideTotemBarCastLabel:SetPoint("LEFT", hideTotemBarCastCheckbox, "RIGHT", 5, 0)
hideTotemBarCastLabel:SetText("Hide Totem Bar")
hideTotemBarCastCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.totemBarHidden = this:GetChecked() and true or false
    TotemNesia.UpdateTotemBar()
end)

-- LEFT SIDE: "Will be enabled when in:" section
local enabledWhenLabel = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
enabledWhenLabel:SetPoint("TOPLEFT", 20, -165)
enabledWhenLabel:SetText("Will be enabled when in:")

-- Solo checkbox (vertical stack)
local soloCheckbox = CreateFrame("CheckButton", "TotemNesiaSoloCheckbox", optionsMenu, "UICheckButtonTemplate")
soloCheckbox:SetPoint("TOPLEFT", 20, -185)
soloCheckbox:SetWidth(24)
soloCheckbox:SetHeight(24)
local soloLabel = soloCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
soloLabel:SetPoint("LEFT", soloCheckbox, "RIGHT", 5, 0)
soloLabel:SetText("Solo")
soloCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.enabledSolo = this:GetChecked() and true or false
end)

-- Parties checkbox
local partyCheckbox = CreateFrame("CheckButton", "TotemNesiaPartyCheckbox", optionsMenu, "UICheckButtonTemplate")
partyCheckbox:SetPoint("TOPLEFT", 20, -210)
partyCheckbox:SetWidth(24)
partyCheckbox:SetHeight(24)
local partyLabel = partyCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
partyLabel:SetPoint("LEFT", partyCheckbox, "RIGHT", 5, 0)
partyLabel:SetText("Parties")
partyCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.enabledParty = this:GetChecked() and true or false
end)

-- Raids checkbox
local raidCheckbox = CreateFrame("CheckButton", "TotemNesiaRaidCheckbox", optionsMenu, "UICheckButtonTemplate")
raidCheckbox:SetPoint("TOPLEFT", 20, -235)
raidCheckbox:SetWidth(24)
raidCheckbox:SetHeight(24)
local raidLabel = raidCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
raidLabel:SetPoint("LEFT", raidCheckbox, "RIGHT", 5, 0)
raidLabel:SetText("Raids")
raidCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.enabledRaid = this:GetChecked() and true or false
end)

-- RIGHT SIDE: Totem Bar Layout toggle button
local layoutButton = CreateFrame("Button", "TotemNesiaLayoutButton", optionsMenu, "UIPanelButtonTemplate")
layoutButton:SetWidth(120)
layoutButton:SetHeight(24)
layoutButton:SetPoint("TOPRIGHT", -20, -179)
layoutButton:SetText("Horizontal")  -- Default text, will be updated when options open

local layoutLabel = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
layoutLabel:SetPoint("BOTTOM", layoutButton, "TOP", 0, 2)
layoutLabel:SetText("Totem Bar Layout:")

-- Flyout Direction toggle button (create before layout OnClick so we can reference it)
local flyoutButton = CreateFrame("Button", "TotemNesiaFlyoutButton", optionsMenu, "UIPanelButtonTemplate")
flyoutButton:SetWidth(120)
flyoutButton:SetHeight(24)
flyoutButton:SetPoint("TOPRIGHT", -20, -229)
flyoutButton:SetText("Up")  -- Default text, will be updated when options open

local flyoutLabel = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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
            DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Layout changed to Vertical, flyout direction set to Right")
        end
    else
        TotemNesiaDB.totemBarLayout = "Horizontal"
        this:SetText("Horizontal")
        -- Default to Up for horizontal layout
        TotemNesiaDB.totemBarFlyoutDirection = "Up"
        flyoutButton:SetText("Up")
        if TotemNesiaDB.debugMode then
            DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Layout changed to Horizontal, flyout direction set to Up")
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
local timerLabel = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
timerLabel:SetPoint("TOP", 0, -260)
timerLabel:SetText("Display Duration: 15s")

-- Timer duration slider
local timerSlider = CreateFrame("Slider", "TotemNesiaTimerSlider", optionsMenu)
timerSlider:SetPoint("TOP", 0, -280)
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

-- UI Frame Scale label
local uiScaleLabel = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
uiScaleLabel:SetPoint("TOP", 0, -305)
uiScaleLabel:SetText("UI Frame Scale: 1.0")

-- UI Frame Scale slider
local uiScaleSlider = CreateFrame("Slider", "TotemNesiaUIScaleSlider", optionsMenu)
uiScaleSlider:SetPoint("TOP", 0, -325)
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
    uiScaleLabel:SetText("UI Frame Scale: " .. value)
    iconFrame:SetScale(value)
end)

-- Totem Tracker Scale label
local trackerScaleLabel = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
trackerScaleLabel:SetPoint("TOP", 0, -350)
trackerScaleLabel:SetText("Totem Tracker Scale: 1.0")

-- Totem Tracker Scale slider
local trackerScaleSlider = CreateFrame("Slider", "TotemNesiaTrackerScaleSlider", optionsMenu)
trackerScaleSlider:SetPoint("TOP", 0, -370)
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
local barScaleLabel = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
barScaleLabel:SetPoint("TOP", 0, -395)
barScaleLabel:SetText("Totem Bar Scale: 1.0")

-- Totem Bar Scale slider
local barScaleSlider = CreateFrame("Slider", "TotemNesiaBarScaleSlider", optionsMenu)
barScaleSlider:SetPoint("TOP", 0, -415)
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
local keybindTitle = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
keybindTitle:SetPoint("TOP", 0, -445)
keybindTitle:SetWidth(360)
keybindTitle:SetJustifyH("CENTER")
keybindTitle:SetText("You can create a hotkey to interact with the UI element by copying the macro below:")

-- Recall macro EditBox
local keybind1 = CreateFrame("EditBox", nil, optionsMenu)
keybind1:SetPoint("TOPLEFT", 20, -465)
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

-- Debug mode checkbox (bottom right corner)
local debugCheckbox = CreateFrame("CheckButton", "TotemNesiaDebugCheckbox", optionsMenu, "UICheckButtonTemplate")
debugCheckbox:SetPoint("BOTTOMRIGHT", -20, 10)
debugCheckbox:SetWidth(24)
debugCheckbox:SetHeight(24)
local debugLabel = debugCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
debugLabel:SetPoint("RIGHT", debugCheckbox, "LEFT", -5, 0)
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
end

-- Minimap button tooltip
minimapButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("TotemNesia")
    GameTooltip:AddLine("Click to open options", 1, 1, 1)
    GameTooltip:AddLine(" ", 1, 1, 1)
    local lockStatus = TotemNesiaDB.isLocked and "|cffff0000Locked|r" or "|cff00ff00Unlocked|r"
    local audioStatus = TotemNesiaDB.audioEnabled and "|cff00ff00Unmuted|r" or "|cffff0000Muted|r"
    GameTooltip:AddLine("Status: " .. lockStatus .. ", " .. audioStatus, 1, 1, 1)
    GameTooltip:AddLine("Timer: " .. TotemNesiaDB.timerDuration .. "s", 1, 1, 1)
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
        hideUICheckbox:SetChecked(TotemNesiaDB.hideUIElement)
        enableTotemBarCheckbox:SetChecked(TotemNesiaDB.totemBarEnabled)
        lockTotemBarCheckbox:SetChecked(TotemNesiaDB.totemTrackerLocked)
        hideTotemBarCheckbox:SetChecked(TotemNesiaDB.totemTrackerHidden)
        lockTotemBarCastCheckbox:SetChecked(TotemNesiaDB.totemBarLocked)
        hideTotemBarCastCheckbox:SetChecked(TotemNesiaDB.totemBarHidden)
        debugCheckbox:SetChecked(TotemNesiaDB.debugMode)
        soloCheckbox:SetChecked(TotemNesiaDB.enabledSolo)
        partyCheckbox:SetChecked(TotemNesiaDB.enabledParty)
        raidCheckbox:SetChecked(TotemNesiaDB.enabledRaid)
        
        timerSlider:SetValue(TotemNesiaDB.timerDuration)
        
        uiScaleSlider:SetValue(TotemNesiaDB.uiFrameScale)
        uiScaleLabel:SetText("UI Frame Scale: " .. TotemNesiaDB.uiFrameScale)
        
        trackerScaleSlider:SetValue(TotemNesiaDB.totemTrackerScale)
        trackerScaleLabel:SetText("Totem Tracker Scale: " .. TotemNesiaDB.totemTrackerScale)
        
        barScaleSlider:SetValue(TotemNesiaDB.totemBarScale)
        barScaleLabel:SetText("Totem Bar Scale: " .. TotemNesiaDB.totemBarScale)
        timerLabel:SetText("Display Duration: " .. TotemNesiaDB.timerDuration .. "s")
        layoutButton:SetText(TotemNesiaDB.totemBarLayout or "Horizontal")
        flyoutButton:SetText(TotemNesiaDB.totemBarFlyoutDirection or "Up")
        optionsMenu:Show()
    end
end)

-- Dragging around minimap
minimapButton:RegisterForDrag("LeftButton")
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
combatFrame:SetScript("OnEvent", function()
    -- Check if addon is enabled for current group type
    if not TotemNesia.IsAddonEnabled() then
        return
    end
    
    if event == "CHAT_MSG_SPELL_SELF_BUFF" then
        -- Check for totem summons - format varies
        if string.find(arg1, "Totem") and not string.find(arg1, "Totemic Recall") then
            if not string.find(arg1, "Fire Nova Totem") then
                -- Try to extract totem name from message
                -- Could be "You cast X." or "You gain X." or just the totem name
                local totemName = arg1
                -- Clean up common prefixes
                totemName = string.gsub(totemName, "You cast ", "")
                totemName = string.gsub(totemName, "You gain ", "")
                totemName = string.gsub(totemName, "%.", "")
                
                TotemNesia.activeTotems[totemName] = true
                TotemNesia.totemTimestamps[totemName] = GetTime()  -- Record placement time
                
                -- Record totem position
                local x, y = GetPlayerMapPosition("player")
                TotemNesia.totemPositions[totemName] = {x = x, y = y}
                
                TotemNesia.hasTotems = true
                TotemNesia.DebugPrint("Totem summoned: " .. totemName)
            else
                TotemNesia.DebugPrint("Fire Nova Totem ignored (self-destructs)")
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
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Frame locked.")
    else
        iconFrame:SetBackdropColor(0, 0, 0, 1)
        iconFrame:RegisterForClicks()
        iconFrame:Show()
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Frame unlocked. Drag to reposition.")
    end
end

-- Function to reset frame position
function TotemNesia.ResetPosition()
    iconFrame:ClearAllPoints()
    iconFrame:SetPoint("CENTER", 0, 200)
    DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Frame position reset to center.")
end

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        TotemNesia.InitDB()
        TotemNesia.UpdateMinimapButton()
        TotemNesia.UpdateTotemTracker()
        TotemNesia.UpdateTotemBar()
        TotemNesia.UpdateTotemBarFlyouts()
        
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
            -- Only show UI element if not hidden by setting
            if not TotemNesiaDB.hideUIElement then
                TotemNesia.displayTimer = TotemNesiaDB.timerDuration
                iconFrame:Show()
                iconFrame:SetAlpha(1)
                iconFrame:RegisterForClicks("LeftButtonUp")
                TotemNesia.DebugPrint("Showing recall icon")
            else
                TotemNesia.DebugPrint("UI element hidden by setting - skipping display")
            end
            
            -- Play audio regardless of UI element visibility
            if TotemNesiaDB.audioEnabled then
                PlaySoundFile("Interface\\AddOns\\TotemNesia\\Sounds\\notification.mp3")
            end
        else
            TotemNesia.hasTotems = false
            TotemNesia.DebugPrint("No totems detected")
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Additional safety check (though we already return early if not Shaman)
        if not IsShaman() then
            this:UnregisterAllEvents()
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
            -- Player is too far from totems - show UI
            if not iconFrame:IsVisible() then
                iconFrame:Show()
                TotemNesia.displayTimer = TotemNesiaDB.timerDuration
                TotemNesia.DebugPrint("Too far from totems - UI shown")
            end
        end
    end
end)

-- Slash commands
SLASH_TOTEMNESIA1 = "/tn"
SlashCmdList["TOTEMNESIA"] = function(msg)
    local lowerMsg = string.lower(msg)
    
    -- Undocumented test command
    if lowerMsg == "test" then
        TotemNesia.hasTotems = true
        TotemNesia.displayTimer = TotemNesiaDB.timerDuration
        iconFrame:Show()
        if TotemNesiaDB.audioEnabled then
            PlaySoundFile("Interface\\AddOns\\TotemNesia\\Sounds\\notification.mp3")
        end
        return
    end
    
    -- Toggle options menu
    if optionsMenu:IsVisible() then
        optionsMenu:Hide()
    else
        -- Update checkbox states when opening
        lockCheckbox:SetChecked(TotemNesiaDB.isLocked)
        muteCheckbox:SetChecked(not TotemNesiaDB.audioEnabled)
        hideUICheckbox:SetChecked(TotemNesiaDB.hideUIElement)
        enableTotemBarCheckbox:SetChecked(TotemNesiaDB.totemBarEnabled)
        lockTotemBarCheckbox:SetChecked(TotemNesiaDB.totemTrackerLocked)
        hideTotemBarCheckbox:SetChecked(TotemNesiaDB.totemTrackerHidden)
        lockTotemBarCastCheckbox:SetChecked(TotemNesiaDB.totemBarLocked)
        hideTotemBarCastCheckbox:SetChecked(TotemNesiaDB.totemBarHidden)
        debugCheckbox:SetChecked(TotemNesiaDB.debugMode)
        soloCheckbox:SetChecked(TotemNesiaDB.enabledSolo)
        partyCheckbox:SetChecked(TotemNesiaDB.enabledParty)
        raidCheckbox:SetChecked(TotemNesiaDB.enabledRaid)
        
        timerSlider:SetValue(TotemNesiaDB.timerDuration)
        
        uiScaleSlider:SetValue(TotemNesiaDB.uiFrameScale)
        uiScaleLabel:SetText("UI Frame Scale: " .. TotemNesiaDB.uiFrameScale)
        
        trackerScaleSlider:SetValue(TotemNesiaDB.totemTrackerScale)
        trackerScaleLabel:SetText("Totem Tracker Scale: " .. TotemNesiaDB.totemTrackerScale)
        
        barScaleSlider:SetValue(TotemNesiaDB.totemBarScale)
        barScaleLabel:SetText("Totem Bar Scale: " .. TotemNesiaDB.totemBarScale)
        timerLabel:SetText("Display Duration: " .. TotemNesiaDB.timerDuration .. "s")
        layoutButton:SetText(TotemNesiaDB.totemBarLayout or "Horizontal")
        flyoutButton:SetText(TotemNesiaDB.totemBarFlyoutDirection or "Up")
        optionsMenu:Show()
    end
end

DEFAULT_CHAT_FRAME:AddMessage("TotemNesia loaded. Type /tn to open options.")

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
