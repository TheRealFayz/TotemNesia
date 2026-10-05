-- TotemNesia: Recall notification icon, element corner icons, and the distance check
-- For Turtle WoW (1.12)

-- Core.lua stops loading on non-Shamans, so every other file stops too
if not TotemNesia or not TotemNesia.shared then
    return
end

-- Shared from files loaded earlier (see the TOC for load order)
local S = TotemNesia.shared
local GetTotemElement = S.GetTotemElement
local TNC = S.TNC

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
    local info = TotemNesia.GetCachedSpell("Totemic Recall")
    if info and info.texture then
        return info.texture
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
        local info = TotemNesia.GetCachedSpell("Totemic Recall")
        if info then
            CastSpell(info.id, BOOKTYPE_SPELL)
            iconFrame:Hide()
            TotemNesia.displayTimer = nil
            TotemNesia.hasTotems = false
            DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Totems recalled!")
        end
    end
end)

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
            TNC.SetIcon(icon.texture, texture)
            icon:Show()
        end
    end
end

-- Function to check if player is too far from totems
function TotemNesia.CheckTotemDistance()
    if not TotemNesia.hasTotems then
        return false
    end
    
    local threshold = TotemNesia.GetGeneralRange()
    
    -- SuperWoW: real distance to each totem's actual position
    if TotemNesia.hasSuperWoW then
        for totemName, _ in pairs(TotemNesia.activeTotems) do
            local distance = TotemNesia.GetTotemDistance(totemName)
            if distance and distance > threshold then
                return true -- Player is too far from at least one totem
            end
        end
        return false
    end
    
    -- Without SuperWoW: estimate from map coordinates
    local px, py = GetPlayerMapPosition("player")
    if not px or not py or (px == 0 and py == 0) then
        return false -- Can't determine position
    end
    
    for totemName, _ in pairs(TotemNesia.activeTotems) do
        local pos = TotemNesia.totemPositions[totemName]
        if pos and not pos.world then
            -- Calculate distance in yards (approximate)
            -- Map coordinates are 0-1, so we convert to yards
            -- Assuming average zone is ~1000 yards across
            local dx = (px - pos.x) * 1000
            local dy = (py - pos.y) * 1000
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance > threshold then
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
    if TotemNesia.GetCachedSpell("Totemic Recall") then
        return true
    end
    
    return false
end


-- Share with files loaded after this one
TotemNesia.shared.iconFrame = iconFrame
TotemNesia.shared.timerText = timerText
