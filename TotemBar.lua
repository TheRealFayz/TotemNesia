-- TotemNesia: Totem bar, flyouts, shield and weapon slots, and the totem tracker
-- For Turtle WoW (1.12)

-- Core.lua stops loading on non-Shamans, so every other file stops too
if not TotemNesia or not TotemNesia.shared then
    return
end

-- Shared from files loaded earlier (see the TOC for load order)
local S = TotemNesia.shared
local GetHighestLearnedRank = S.GetHighestLearnedRank
local GetTotemDuration = S.GetTotemDuration
local GetTotemElement = S.GetTotemElement
local TNC = S.TNC
local iconFrame = S.iconFrame

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
        "Fire Resistance Totem",
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
    },
    shield = TNC.SHIELD_SPELLS
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

-- Create 6 slots (Fire, Earth, Water, Air, Weapon, Shield)
local elementOrder = {"fire", "earth", "water", "air", "weapon", "shield"}
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
    
    -- Keybind text (top-right corner like action buttons)
    local keybindText = slot:CreateFontString(nil, "OVERLAY")
    keybindText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    keybindText:SetPoint("TOPRIGHT", slot, "TOPRIGHT", -1, -1)
    keybindText:SetTextColor(0.6, 0.6, 0.6, 1)  -- Gray color like action buttons
    keybindText:SetJustifyH("RIGHT")
    slot.keybindText = keybindText
    
    -- Pulse bar along the bottom edge (fills once per pulse for pulsing totems)
    local pulseBg = slot:CreateTexture(nil, "OVERLAY")
    pulseBg:SetTexture(0, 0, 0, 0.6)
    pulseBg:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 2, 2)
    pulseBg:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
    pulseBg:SetHeight(2)
    pulseBg:Hide()
    slot.pulseBg = pulseBg
    
    local pulseFill = slot:CreateTexture(nil, "OVERLAY")
    pulseFill:SetTexture(0.4, 0.8, 1, 0.9)
    pulseFill:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 2, 2)
    pulseFill:SetHeight(2)
    pulseFill:SetWidth(1)
    pulseFill:Hide()
    slot.pulseFill = pulseFill
    
    -- Fallback badge (small icon in the top-left corner showing the fallback totem)
    local fallbackBadge = slot:CreateTexture(nil, "OVERLAY")
    fallbackBadge:SetWidth(9)
    fallbackBadge:SetHeight(9)
    fallbackBadge:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
    fallbackBadge:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    fallbackBadge:Hide()
    slot.fallbackBadge = fallbackBadge
    
    -- Mode letter (P / D for Anti-Poison / Anti-Disease on the water slot)
    local modeText = slot:CreateFontString(nil, "OVERLAY")
    modeText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    modeText:SetPoint("LEFT", slot, "LEFT", 2, 0)
    modeText:SetTextColor(0.3, 1, 0.3, 1)
    modeText:SetText("")
    slot.modeText = modeText
    
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
            TotemNesia.SetTooltipOwner(this, "ANCHOR_RIGHT")
            local highestId = GetHighestLearnedRank(this.totemName)
            if highestId then
                GameTooltip:SetSpell(highestId, BOOKTYPE_SPELL)
            else
                -- Fallback if spell not found in book
                GameTooltip:SetText(this.totemName, 1, 1, 1)
            end
            -- Control hints for totem flyouts
            if this.element ~= "weapon" and this.element ~= "shield" then
                GameTooltip:AddLine("Ctrl-click: set as slot totem", 0.6, 0.6, 0.6)
                local fallbacks = TotemNesiaDB.totemBarFallbacks
                if fallbacks and fallbacks[this.element] == this.totemName then
                    GameTooltip:AddLine("Alt-click: clear fallback", 0.6, 0.6, 0.6)
                else
                    GameTooltip:AddLine("Alt-click: set as fallback (cast when the slot totem is on cooldown)", 0.6, 0.6, 0.6, 1)
                end
            elseif this.element == "shield" then
                GameTooltip:AddLine("Click: cast and track this shield", 0.6, 0.6, 0.6)
            elseif this.element == "weapon" then
                GameTooltip:AddLine("Ctrl-click: set as slot enchant", 0.6, 0.6, 0.6)
            end
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
            if this.element == "shield" then
                -- Shield flyout: cast it and make it the tracked shield
                TotemNesiaDB.shieldSpell = this.totemName
                CastSpellByName(this.totemName)
                TotemNesia.UpdateTotemBar()
                TotemNesia.DebugPrint("Shield slot set to " .. this.totemName)
                flyout.hideTime = nil
                flyout:Hide()
            elseif IsAltKeyDown() and this.element ~= "weapon" then
                -- Alt-click: set (or clear) the fallback totem for this slot
                local elem = this.element
                if not TotemNesiaDB.totemBarFallbacks then
                    TotemNesiaDB.totemBarFallbacks = {}
                end
                if TotemNesiaDB.totemBarFallbacks[elem] == this.totemName then
                    TotemNesiaDB.totemBarFallbacks[elem] = nil
                    TotemNesia.DebugPrint("Fallback cleared for " .. elem .. " slot")
                else
                    TotemNesiaDB.totemBarFallbacks[elem] = this.totemName
                    TotemNesia.DebugPrint(this.totemName .. " set as " .. elem .. " fallback")
                end
                TotemNesia.UpdateTotemBar()
                flyout.hideTime = nil
                flyout:Hide()
            elseif IsControlKeyDown() then
                -- Ctrl-click: Set as default totem (or weapon enchant) for this slot
                local elem = this.element
                TotemNesiaDB.totemBarSlots[elem] = this.totemName
                local slotBtn = TotemNesia.totemBarSlots[elem]
                if slotBtn then
                    slotBtn.selectedTotem = this.totemName
                    TotemNesia.UpdateTotemBar()
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
    
    -- Slot click to cast selected totem (the weapon slot casts its Ctrl-click assigned enchant)
    if element == "shield" then
        slot:RegisterForClicks("LeftButtonUp")
        slot:SetScript("OnClick", function()
            TotemNesia_CastShield()
        end)
    elseif element == "weapon" then
        slot:RegisterForClicks("LeftButtonUp")
        slot:SetScript("OnClick", function()
            if this.selectedTotem then
                CastSpellByName(this.selectedTotem)
                TotemNesia.clickedWeaponEnchant = this.selectedTotem
            end
        end)
    elseif element ~= "weapon" then
        slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        slot:SetScript("OnClick", function()
            if arg1 == "RightButton" then
                -- Right-click on the water slot cycles Off -> Anti-Poison -> Anti-Disease -> Off
                if this.element == "water" then
                    TotemNesia.CycleCleansingMode()
                end
                return
            end
            TotemNesia.CastTotemForElement(this.element, this.selectedTotem)
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

-- Function to update keybind displays on all totem bar slots
function TotemNesia.UpdateTotemBarKeybinds()
    if not TotemNesia.totemBarSlots then
        return
    end
    
    -- Map element names to their binding display names (must match Bindings.xml exactly)
    local bindingMap = {
        fire = "Totem Bar 1 (Fire)",
        earth = "Totem Bar 2 (Earth)",
        water = "Totem Bar 3 (Water)",
        air = "Totem Bar 4 (Air)",
        shield = "Recast Shield"
    }
    
    -- Update each slot's keybind display (skip weapon slot)
    for element, bindingName in pairs(bindingMap) do
        local slot = TotemNesia.totemBarSlots[element]
        if slot and slot.keybindText then
            -- Get the first key bound to this action (using exact display name from Bindings.xml)
            local key1, key2 = GetBindingKey(bindingName)
            local keyText = ""
            
            if key1 then
                -- Format the key for display
                keyText = key1
                keyText = string.gsub(keyText, "SHIFT%-", "S")
                keyText = string.gsub(keyText, "CTRL%-", "C")
                keyText = string.gsub(keyText, "ALT%-", "A")
                keyText = string.gsub(keyText, "BUTTON", "M")
                
                -- Debug: Print what we found (only if debug mode is explicitly enabled)
                if TotemNesiaDB and TotemNesiaDB.debugMode == true then
                    DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: " .. element .. " keybind = " .. keyText)
                end
            else
                -- Debug: No binding found (only if debug mode is explicitly enabled)
                if TotemNesiaDB and TotemNesiaDB.debugMode == true then
                    DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: No keybind found for " .. element)
                end
            end
            
            slot.keybindText:SetText(keyText)
        end
    end
end

-- Slot order on the totem bar
TNC.BAR_ORDER = {"fire", "earth", "water", "air", "weapon", "shield"}

-- Which totem bar slots are visible
function TNC.IsSlotVisible(element)
    if element == "weapon" and TotemNesiaDB.hideWeaponSlot then
        return false
    end
    if element == "shield" and TotemNesiaDB.hideShieldSlot then
        return false
    end
    return true
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
    local elementOrder = TNC.BAR_ORDER
    
    -- Only re-place the slots when a layout setting changed (this runs twice a second)
    local layoutKey = tostring(TotemNesiaDB.totemBarLayout) .. (TotemNesiaDB.hideWeaponSlot and "1" or "0") .. (TotemNesiaDB.hideShieldSlot and "1" or "0")
    if TNC.lastBarLayout ~= layoutKey then
        TNC.lastBarLayout = layoutKey
    
        local visibleSlots = 0
        for _, element in ipairs(elementOrder) do
            if TNC.IsSlotVisible(element) then
                visibleSlots = visibleSlots + 1
            end
        end
    
        if isVertical then
            totemBar:SetWidth(slotSize + 8)
            totemBar:SetHeight((visibleSlots * slotSize) + ((visibleSlots - 1) * slotSpacing) + 8)
        else
            totemBar:SetWidth((visibleSlots * slotSize) + ((visibleSlots - 1) * slotSpacing) + 8)
            totemBar:SetHeight(slotSize + 8)
        end
    
        local visibleIndex = 0
        for _, element in ipairs(elementOrder) do
            local slot = TotemNesia.totemBarSlots[element]
            if slot then
                if not TNC.IsSlotVisible(element) then
                    slot:Hide()
                else
                    slot:Show()
                    slot:ClearAllPoints()
                    if isVertical then
                        slot:SetPoint("TOP", totemBar, "TOP", 0, -4 - (visibleIndex * (slotSize + slotSpacing)))
                    else
                        slot:SetPoint("LEFT", totemBar, "LEFT", 4 + (visibleIndex * (slotSize + slotSpacing)), 0)
                    end
                    visibleIndex = visibleIndex + 1
                end
            end
        end
    end
    
    -- Update each slot
    for element, slot in pairs(TotemNesia.totemBarSlots) do
        if element == "weapon" then
            -- Restore saved weapon enchant selection (set with Ctrl-click in the flyout)
            local savedEnchant = TotemNesiaDB.totemBarSlots[element]
            if savedEnchant and not slot.selectedTotem then
                slot.selectedTotem = savedEnchant
            end
            
            -- Weapon slot: show the imbue actually on the weapon, or the last one clicked
            local shownEnchant = TotemNesia.detectedWeaponEnchant or TotemNesia.clickedWeaponEnchant
            if TotemNesia.weaponEnchantTime > 0 and TotemNesia.weaponEnchantExpiry and shownEnchant then
                local enchantIcon = GetTotemIcon(shownEnchant)
                if not TotemNesia.lastWeaponIconState or TotemNesia.lastWeaponIconState ~= shownEnchant then
                    TotemNesia.DebugPrint("Setting weapon icon to: " .. shownEnchant .. " (" .. tostring(enchantIcon) .. ")")
                    TotemNesia.lastWeaponIconState = shownEnchant
                end
                TNC.SetIcon(slot.iconTexture, enchantIcon)
                slot.iconTexture:SetAlpha(1)
                slot.iconTexture:SetVertexColor(1, 1, 1)
            else
                if TotemNesia.lastWeaponIconState then
                    TotemNesia.DebugPrint("Clearing weapon icon")
                    TotemNesia.lastWeaponIconState = nil
                end
                if slot.selectedTotem then
                    -- No imbue on the weapon: show the assigned enchant dimmed, like a missing shield
                    TNC.SetIcon(slot.iconTexture, GetTotemIcon(slot.selectedTotem))
                    slot.iconTexture:SetAlpha(1)
                    slot.iconTexture:SetVertexColor(0.4, 0.4, 0.4)
                else
                    TNC.SetIcon(slot.iconTexture, nil)
                    slot.iconTexture:SetAlpha(0)
                end
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
                    local total = TotemNesia.weaponEnchantExpiry - TotemNesia.weaponEnchantTime
                    slot.timerText:SetTextColor(TotemNesia.GetTimerColor(remaining, total))
                else
                    slot.timerText:SetText("")
                    TotemNesia.weaponEnchantTime = 0
                    TotemNesia.weaponEnchantExpiry = nil
                    TotemNesia.clickedWeaponEnchant = nil
                end
            else
                slot.timerText:SetText("")
            end
            
        elseif element == "shield" then
            -- Shield slot: chosen shield icon, charges as the number, dimmed when missing
            local chosen = TotemNesia.GetChosenShield()
            local activeShield, charges = TotemNesia.GetActiveShield()
            slot.shieldLow = false
            if chosen then
                TNC.SetIcon(slot.iconTexture, GetTotemIcon(activeShield or chosen))
                slot.iconTexture:SetAlpha(1)
                if activeShield then
                    slot.iconTexture:SetVertexColor(1, 1, 1)
                    if charges and charges > 0 then
                        slot.timerText:SetText(charges)
                        if charges <= 1 then
                            slot.timerText:SetTextColor(1, 0.2, 0.2)
                            slot.shieldLow = true
                        else
                            slot.timerText:SetTextColor(1, 1, 1)
                        end
                    else
                        slot.timerText:SetText("")
                    end
                else
                    slot.iconTexture:SetVertexColor(0.4, 0.4, 0.4)
                    slot.timerText:SetText("")
                    slot.shieldLow = true
                end
            else
                -- No shield learned yet
                TNC.SetIcon(slot.iconTexture, nil)
                slot.iconTexture:SetAlpha(0)
                slot.timerText:SetText("")
            end
            
        else
            -- Restore saved totem selection for totem slots
            local savedTotem = TotemNesiaDB.totemBarSlots[element]
            if savedTotem and not slot.selectedTotem then
                slot.selectedTotem = savedTotem
            end
            
            -- Icon shows what a click will cast (cleansing mode can swap the water slot)
            local displayTotem = slot.selectedTotem
            if element == "water" and TotemNesiaDB.cleansingMode then
                local cleansing = TNC.CLEANSING[TotemNesiaDB.cleansingMode]
                if cleansing and IsTotemLearned(cleansing) then
                    displayTotem = cleansing
                end
            end
            
            -- Mode letter on the water slot
            if slot.modeText then
                if element == "water" and TotemNesiaDB.cleansingMode == "poison" then
                    slot.modeText:SetText("P")
                elseif element == "water" and TotemNesiaDB.cleansingMode == "disease" then
                    slot.modeText:SetText("D")
                else
                    slot.modeText:SetText("")
                end
            end
            
            -- Fallback badge
            if slot.fallbackBadge then
                local fallback = TotemNesiaDB.totemBarFallbacks and TotemNesiaDB.totemBarFallbacks[element]
                if fallback and IsTotemLearned(fallback) then
                    TNC.SetIcon(slot.fallbackBadge, GetTotemIcon(fallback))
                    slot.fallbackBadge:Show()
                else
                    slot.fallbackBadge:Hide()
                end
            end
            
            -- Timer, color, and range tint for the active totem of this element
            slot.activeTotem = nil
            local outOfRange = false
            for totemName, _ in pairs(TotemNesia.activeTotems) do
                if GetTotemElement(totemName) == element then
                    slot.activeTotem = totemName
                    local timestamp = TotemNesia.totemTimestamps[totemName]
                    if timestamp then
                        local elapsed = GetTime() - timestamp
                        local duration = GetTotemDuration(totemName)
                        local remaining = duration - elapsed
                        if remaining > 0 then
                            slot.timerText:SetText(math.ceil(remaining))
                            slot.timerText:SetTextColor(TotemNesia.GetTimerColor(remaining, duration))
                        else
                            slot.timerText:SetText("")
                        end
                    end
                    local distance = TotemNesia.GetTotemDistance(totemName)
                    if distance and distance > TotemNesia.GetTotemRange(totemName) then
                        outOfRange = true
                    end
                    break
                end
            end
            
            if not slot.activeTotem then
                slot.timerText:SetText("")
            end
            
            -- Icon: the assigned totem. With no assignment, show the totem of this element
            -- that is currently out so the timer always has an icon next to it.
            local iconTotem = displayTotem or slot.activeTotem
            if iconTotem then
                TNC.SetIcon(slot.iconTexture, GetTotemIcon(iconTotem))
                slot.iconTexture:SetAlpha(1)
            else
                TNC.SetIcon(slot.iconTexture, nil)
                slot.iconTexture:SetAlpha(0)
            end
            
            if outOfRange then
                slot.iconTexture:SetVertexColor(1, 0.35, 0.35)
            else
                slot.iconTexture:SetVertexColor(1, 1, 1)
            end
        end
    end
end

-- Cycle the water slot between Off, Anti-Poison, and Anti-Disease (skips unlearned totems)
function TotemNesia.CycleCleansingMode()
    local current = TotemNesiaDB.cleansingMode
    local nextMode = nil
    if current == nil then
        if IsTotemLearned(TNC.CLEANSING.poison) then
            nextMode = "poison"
        elseif IsTotemLearned(TNC.CLEANSING.disease) then
            nextMode = "disease"
        end
    elseif current == "poison" then
        if IsTotemLearned(TNC.CLEANSING.disease) then
            nextMode = "disease"
        end
    end
    TotemNesiaDB.cleansingMode = nextMode
    if nextMode == "poison" then
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Anti-Poison mode on (water slot casts Poison Cleansing Totem)")
    elseif nextMode == "disease" then
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Anti-Disease mode on (water slot casts Disease Cleansing Totem)")
    else
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Cleansing mode off")
    end
    TotemNesia.UpdateTotemBar()
end

-- Fast updates for the pulse bars and the low-shield flash (runs every frame, very light)
TNC.fastFrame = CreateFrame("Frame")
TNC.fastFrame.elapsed = 0
TNC.fastFrame:SetScript("OnUpdate", function()
    -- About 30 updates a second is plenty for a 20 pixel bar
    this.elapsed = this.elapsed + arg1
    if this.elapsed < 0.033 then
        return
    end
    this.elapsed = 0
    if not totemBar:IsVisible() then
        return
    end
    local now = GetTime()
    for element, slot in pairs(TotemNesia.totemBarSlots) do
        -- Pulse bar
        if slot.pulseFill then
            local totemName = slot.activeTotem
            local interval = totemName and TNC.PULSE_INTERVALS[totemName]
            local timestamp = totemName and TotemNesia.totemTimestamps[totemName]
            if interval and timestamp then
                local elapsed = now - timestamp
                local progress = (elapsed - math.floor(elapsed / interval) * interval) / interval
                local width = progress * 20  -- Slot is 24px with a 2px inset on each side
                if width < 1 then
                    width = 1
                end
                slot.pulseFill:SetWidth(width)
                slot.pulseBg:Show()
                slot.pulseFill:Show()
            else
                slot.pulseBg:Hide()
                slot.pulseFill:Hide()
            end
        end
        -- Low shield flash on the shield slot border
        if element == "shield" then
            if slot.shieldLow and TotemNesiaDB.shieldFlash and not UnitIsDeadOrGhost("player") then
                local pulse = 0.5 + 0.5 * math.sin(now * 6)
                slot:SetBackdropBorderColor(1, 0.2 * pulse, 0.2 * pulse, 1)
            else
                slot:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            end
        end
    end
end)

-- Lay out every flyout: show only learned spells, size the flyout to fit them, and anchor it
-- on the side picked in settings (Up/Down stack vertically, Left/Right sit side by side).
function TotemNesia.UpdateTotemBarFlyouts()
    local direction = TotemNesiaDB.totemBarFlyoutDirection or "Up"
    local iconSize = 24
    local iconSpacing = 2
    local isVerticalFlyout = (direction == "Up" or direction == "Down")
    
    TotemNesia.DebugPrint("UpdateTotemBarFlyouts called, direction = " .. tostring(direction))
    
    for element, slot in pairs(TotemNesia.totemBarSlots) do
        local flyout = slot.flyout
        if flyout then
            -- Show learned spells, hide the rest, and position only the visible ones
            local visibleCount = 0
            local children = {flyout:GetChildren()}
            for _, button in ipairs(children) do
                if button.totemName then
                    if IsTotemLearned(button.totemName) then
                        button:Show()
                        button:ClearAllPoints()
                        local offset = iconSpacing + (visibleCount * (iconSize + iconSpacing))
                        if isVerticalFlyout then
                            button:SetPoint("TOP", flyout, "TOP", 0, -offset)
                        else
                            button:SetPoint("LEFT", flyout, "LEFT", offset, 0)
                        end
                        visibleCount = visibleCount + 1
                    else
                        button:Hide()
                    end
                end
            end
            
            local length = (visibleCount * iconSize) + ((visibleCount + 1) * iconSpacing)
            local thickness = iconSize + (2 * iconSpacing)
            flyout:ClearAllPoints()
            if isVerticalFlyout then
                flyout:SetWidth(thickness)
                flyout:SetHeight(length)
                if direction == "Up" then
                    flyout:SetPoint("BOTTOM", slot, "TOP", 0, 2)
                else
                    flyout:SetPoint("TOP", slot, "BOTTOM", 0, -2)
                end
            else
                flyout:SetWidth(length)
                flyout:SetHeight(thickness)
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
    for element, slot in pairs(TotemNesia.totemBarSlots) do
        if slot.flyout then
            local children = {slot.flyout:GetChildren()}
            for _, child in ipairs(children) do
                if child.totemName and child.iconTexture then
                    child.iconTexture:SetTexture(GetTotemIcon(child.totemName))
                end
            end
        end
    end
    -- Hide unlearned spells and re-fit the flyouts
    TotemNesia.UpdateTotemBarFlyouts()
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
            TotemNesia.RemoveTotem(totemName, "expired")
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
                TNC.SetIcon(icon.texture, totemTexture)
            else
                -- Fallback to default icon if texture not found
                TNC.SetIcon(icon.texture, "Interface\\Icons\\Spell_Nature_Reincarnation")
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
        
        -- Full color, or red tint when out of this totem's range (SuperWoW only)
        local distance = TotemNesia.GetTotemDistance(totemName)
        if distance and distance > TotemNesia.GetTotemRange(totemName) then
            icon.texture:SetVertexColor(1, 0.35, 0.35)
        else
            icon.texture:SetVertexColor(1, 1, 1)
        end
        icon.totemName = totemName
        
        -- Update timer
        local timestamp = TotemNesia.totemTimestamps[totemName]
        if timestamp then
            local elapsed = GetTime() - timestamp
            local duration = GetTotemDuration(totemName)
            local remaining = duration - elapsed
            if remaining > 0 then
                icon.timerText:SetText(math.ceil(remaining))
                icon.timerText:SetTextColor(TotemNesia.GetTimerColor(remaining, duration))
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
            local enchantChanged = false
            if TotemNesia.weaponEnchantTime == 0 or (TotemNesia.weaponEnchantExpiry and math.abs(TotemNesia.weaponEnchantExpiry - (currentTime + expirationSeconds)) > 5) then
                TotemNesia.weaponEnchantTime = currentTime
                TotemNesia.weaponEnchantExpiry = currentTime + expirationSeconds
                enchantChanged = true
                TotemNesia.DebugPrint("Weapon enchant detected, expires in " .. math.floor(expirationSeconds) .. " seconds")
            end
            -- Read the imbue name off the weapon when it changes, and every 10 seconds otherwise
            TotemNesia.weaponScanTimer = TotemNesia.weaponScanTimer + this.timeSinceUpdate
            if enchantChanged or not TotemNesia.detectedWeaponEnchant or TotemNesia.weaponScanTimer >= 10 then
                TotemNesia.weaponScanTimer = 0
                local detected = TotemNesia.DetectWeaponImbue()
                if detected ~= TotemNesia.detectedWeaponEnchant then
                    TotemNesia.DebugPrint("Weapon imbue on weapon: " .. tostring(detected))
                end
                TotemNesia.detectedWeaponEnchant = detected
            end
        else
            -- No enchant, clear timer
            if TotemNesia.weaponEnchantTime > 0 then
                TotemNesia.DebugPrint("Weapon enchant expired")
            end
            TotemNesia.weaponEnchantTime = 0
            TotemNesia.weaponEnchantExpiry = nil
            TotemNesia.detectedWeaponEnchant = nil
        end
        
        -- SuperWoW: notice destroyed totems right away
        TotemNesia.CheckTotemUnits()
        
        TotemNesia.UpdateTotemTracker()
        -- The element corner icons live on the recall notification; skip them while it's hidden
        if iconFrame:IsVisible() then
            TotemNesia.UpdateElementalIndicators()
        end
        TotemNesia.UpdateTotemBar()
        this.timeSinceUpdate = 0
    end
end)


-- Share with files loaded after this one
TotemNesia.shared.totemBar = totemBar
TotemNesia.shared.totemTracker = totemTracker
