-- TotemNesia: Automatically recalls totems after leaving combat
-- For Turtle WoW (1.12)
-- Version 2.5

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

TotemNesia = {}
TotemNesia.displayTimer = nil
TotemNesia.inCombat = false
TotemNesia.hasTotems = false
TotemNesia.monitoringForRecall = false
TotemNesia.monitorTimer = 0
TotemNesia.activeTotems = {}  -- Track which totems are currently active
TotemNesia.totemTimestamps = {}  -- Track when each totem was placed

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
    if TotemNesiaDB.totemBarLocked == nil then
        TotemNesiaDB.totemBarLocked = true
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

-- Create totem tracker bar
local totemBar = CreateFrame("Frame", "TotemNesiaTotemBar", UIParent)
totemBar:SetWidth(400)
totemBar:SetHeight(24)
totemBar:SetPoint("CENTER", UIParent, "BOTTOM", 0, 100)
totemBar:SetMovable(true)
totemBar:SetUserPlaced(true)
totemBar:SetFrameStrata("MEDIUM")
totemBar:Hide()

-- Make totem bar draggable when unlocked
totemBar:RegisterForDrag("LeftButton")
totemBar:SetScript("OnDragStart", function()
    if not TotemNesiaDB.totemBarLocked then
        this:StartMoving()
    end
end)
totemBar:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
end)

-- Totem bar icons storage
TotemNesia.totemBarIcons = {}

-- Function to update totem bar display
function TotemNesia.UpdateTotemBar()
    -- Clear existing icons
    for _, icon in pairs(TotemNesia.totemBarIcons) do
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
    
    if activeCount == 0 or TotemNesiaDB.totemBarHidden then
        totemBar:Hide()
        return
    end
    
    -- Create/update icons for active totems only
    local iconSize = 20
    local iconSpacing = 1
    local totalWidth = (activeCount * iconSize) + ((activeCount - 1) * iconSpacing)
    
    totemBar:SetWidth(totalWidth + 8)
    totemBar:SetHeight(iconSize + 8)
    totemBar:Show()
    
    local index = 0
    for totemName, _ in pairs(TotemNesia.activeTotems) do
        local icon = TotemNesia.totemBarIcons[totemName]
        
        if not icon then
            icon = CreateFrame("Frame", nil, totemBar)
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
            
            TotemNesia.totemBarIcons[totemName] = icon
        end
        
        icon:SetPoint("LEFT", totemBar, "LEFT", 4 + (index * (iconSize + iconSpacing)), 0)
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

-- Update totem bar when totems change
local totemUpdateFrame = CreateFrame("Frame")
totemUpdateFrame.timeSinceUpdate = 0
totemUpdateFrame:SetScript("OnUpdate", function()
    this.timeSinceUpdate = this.timeSinceUpdate + arg1
    if this.timeSinceUpdate >= 0.5 then
        TotemNesia.UpdateTotemBar()
        TotemNesia.UpdateElementalIndicators()
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
optionsMenu:SetHeight(300)
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
    TotemNesiaDB.totemBarLocked = this:GetChecked() and true or false
    if TotemNesiaDB.totemBarLocked then
        totemBar:EnableMouse(false)
    else
        totemBar:EnableMouse(true)
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
    TotemNesiaDB.totemBarHidden = this:GetChecked() and true or false
    TotemNesia.UpdateTotemBar()
end)

-- Debug mode checkbox
local debugCheckbox = CreateFrame("CheckButton", "TotemNesiaDebugCheckbox", optionsMenu, "UICheckButtonTemplate")
debugCheckbox:SetPoint("TOPLEFT", 210, -105)
debugCheckbox:SetWidth(24)
debugCheckbox:SetHeight(24)
local debugLabel = debugCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
debugLabel:SetPoint("LEFT", debugCheckbox, "RIGHT", 5, 0)
debugLabel:SetText("Debug mode")
debugCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.debugMode = this:GetChecked() and true or false
end)

-- "Will be enabled when in:" section
local enabledWhenLabel = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
enabledWhenLabel:SetPoint("TOP", 0, -125)
enabledWhenLabel:SetText("Will be enabled when in:")

-- Solo checkbox
local soloCheckbox = CreateFrame("CheckButton", "TotemNesiaSoloCheckbox", optionsMenu, "UICheckButtonTemplate")
soloCheckbox:SetPoint("TOPLEFT", 20, -145)
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
partyCheckbox:SetPoint("TOPLEFT", 120, -145)
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
raidCheckbox:SetPoint("TOPLEFT", 220, -145)
raidCheckbox:SetWidth(24)
raidCheckbox:SetHeight(24)
local raidLabel = raidCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
raidLabel:SetPoint("LEFT", raidCheckbox, "RIGHT", 5, 0)
raidLabel:SetText("Raids")
raidCheckbox:SetScript("OnClick", function()
    TotemNesiaDB.enabledRaid = this:GetChecked() and true or false
end)

-- Timer duration label
local timerLabel = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
timerLabel:SetPoint("TOP", 0, -175)
timerLabel:SetText("Display Duration: 15s")

-- Timer duration slider
local timerSlider = CreateFrame("Slider", "TotemNesiaTimerSlider", optionsMenu)
timerSlider:SetPoint("TOP", 0, -195)
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

-- Keybind macros section
local keybindTitle = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
keybindTitle:SetPoint("TOP", 0, -230)
keybindTitle:SetText("You can create a hotkey to interact with the UI element by copying the macro below:")

-- Recall macro EditBox
local keybind1 = CreateFrame("EditBox", nil, optionsMenu)
keybind1:SetPoint("TOPLEFT", 20, -250)
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
        lockTotemBarCheckbox:SetChecked(TotemNesiaDB.totemBarLocked)
        hideTotemBarCheckbox:SetChecked(TotemNesiaDB.totemBarHidden)
        debugCheckbox:SetChecked(TotemNesiaDB.debugMode)
        soloCheckbox:SetChecked(TotemNesiaDB.enabledSolo)
        partyCheckbox:SetChecked(TotemNesiaDB.enabledParty)
        raidCheckbox:SetChecked(TotemNesiaDB.enabledRaid)
        
        timerSlider:SetValue(TotemNesiaDB.timerDuration)
        timerLabel:SetText("Display Duration: " .. TotemNesiaDB.timerDuration .. "s")
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
            TotemNesia.hasTotems = false
            TotemNesia.DebugPrint("Totemic Recall faded - totems gone")
        elseif string.find(arg1, "Totem") then
            -- Individual totem faded
            local totemName = string.gsub(arg1, "(.+) fades from you%.", "%1")
            TotemNesia.activeTotems[totemName] = nil
            TotemNesia.totemTimestamps[totemName] = nil
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
        TotemNesia.UpdateTotemBar()
        
        -- Set totem bar mouse state based on lock setting
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
        lockTotemBarCheckbox:SetChecked(TotemNesiaDB.totemBarLocked)
        hideTotemBarCheckbox:SetChecked(TotemNesiaDB.totemBarHidden)
        debugCheckbox:SetChecked(TotemNesiaDB.debugMode)
        soloCheckbox:SetChecked(TotemNesiaDB.enabledSolo)
        partyCheckbox:SetChecked(TotemNesiaDB.enabledParty)
        raidCheckbox:SetChecked(TotemNesiaDB.enabledRaid)
        
        timerSlider:SetValue(TotemNesiaDB.timerDuration)
        timerLabel:SetText("Display Duration: " .. TotemNesiaDB.timerDuration .. "s")
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
