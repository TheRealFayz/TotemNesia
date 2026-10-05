-- TotemNesia: Minimap button and the options window
-- For Turtle WoW (1.12)

-- Core.lua stops loading on non-Shamans, so every other file stops too
if not TotemNesia or not TotemNesia.shared then
    return
end

-- Shared from files loaded earlier (see the TOC for load order)
local S = TotemNesia.shared
local GetHighestLearnedRank = S.GetHighestLearnedRank
local TNC = S.TNC
local iconFrame = S.iconFrame
local totemBar = S.totemBar
local totemTracker = S.totemTracker

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
menuTitle:SetText("TotemNesia V" .. TotemNesia.GetVersion())  -- Read from the TOC file
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
settingsScrollChild:SetHeight(800)  -- Tall enough for the range, shield, and totem bar help sections
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

-- ============================================================================
-- OPTIONS WINDOW CONTENT (tabs, Totem Sets, Mana, Settings) AND MINIMAP BUTTON
-- ============================================================================
-- Everything is built inside one function so its controls are local to that function
-- instead of the file. A Lua file can only hold 200 top-level locals, and a single
-- function can only reach 32 outside locals (upvalues) in WoW's Lua 5.0. Building the
-- UI from small helpers and data tables keeps TotemNesia far away from both limits.

function TNC.BuildOptionsUI()
    local ui = {}
    TNC.ui = ui

    local ACTIVE_TAB = "Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab"
    local INACTIVE_TAB = "Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab"
    local SLIDER_BACKDROP = {
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 }
    }
    local BUTTON_BACKDROP = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 1, edgeSize = 2,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    }
    local SELECTED_BORDER = {
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 1, edgeSize = 2,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    }

    -- ------------------------------------------------------------------
    -- Small builders
    -- ------------------------------------------------------------------
    local function MakeText(parent, font, point, x, y, text, width, justify)
        local fs = parent:CreateFontString(nil, "OVERLAY", font)
        fs:SetPoint(point, x, y)
        if width then
            fs:SetWidth(width)
        end
        if justify then
            fs:SetJustifyH(justify)
        end
        fs:SetText(text)
        return fs
    end

    -- Checkbox bound to a saved setting. invert = checkbox shows the opposite of the setting.
    -- onChange runs after the setting is saved. labelLeft puts the label on the left side.
    local checkboxes = {}
    local function MakeCheckbox(parent, point, x, y, text, dbKey, invert, onChange, labelLeft)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint(point, x, y)
        cb:SetWidth(24)
        cb:SetHeight(24)
        local label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if labelLeft then
            label:SetPoint("RIGHT", cb, "LEFT", -5, 0)
        else
            label:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        end
        label:SetText(text)
        cb.dbKey = dbKey
        cb.invert = invert
        cb.onChange = onChange
        cb:SetScript("OnClick", function()
            local checked = this:GetChecked() and true or false
            if this.invert then
                TotemNesiaDB[this.dbKey] = not checked
            else
                TotemNesiaDB[this.dbKey] = checked
            end
            if this.onChange then
                this.onChange(TotemNesiaDB[this.dbKey])
            end
        end)
        table.insert(checkboxes, cb)
        return cb
    end

    -- Slider bound to a saved setting. format(value) returns the label text.
    -- round(raw) turns the raw slider value into the stored value.
    local sliders = {}
    local function MakeSlider(parent, y, minValue, maxValue, step, dbKey, format, round, onChange)
        local label = MakeText(parent, "GameFontNormal", "TOP", 0, y, "")
        local slider = CreateFrame("Slider", nil, parent)
        slider:SetPoint("TOP", 0, y - 20)
        slider:SetWidth(350)
        slider:SetHeight(15)
        slider:SetOrientation("HORIZONTAL")
        slider:SetMinMaxValues(minValue, maxValue)
        slider:SetValueStep(step)
        slider:SetBackdrop(SLIDER_BACKDROP)
        local thumb = slider:CreateTexture(nil, "OVERLAY")
        thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        thumb:SetWidth(32)
        thumb:SetHeight(32)
        slider:SetThumbTexture(thumb)
        slider.label = label
        slider.dbKey = dbKey
        slider.format = format
        slider.round = round
        slider.onChange = onChange
        slider:SetScript("OnValueChanged", function()
            local value = this.round(this:GetValue())
            TotemNesiaDB[this.dbKey] = value
            this.label:SetText(this.format(value))
            if this.onChange then
                this.onChange(value)
            end
        end)
        table.insert(sliders, slider)
        return slider
    end

    local function RoundWhole(v) return math.floor(v + 0.5) end
    local function RoundTenth(v) return math.floor(v * 10 + 0.5) / 10 end
    local function RoundFive(v) return math.floor(v / 5 + 0.5) * 5 end

    -- ------------------------------------------------------------------
    -- Tabs
    -- ------------------------------------------------------------------
    local totemSetsContent = CreateFrame("Frame", nil, optionsMenu)
    totemSetsContent:SetAllPoints(optionsMenu)
    totemSetsContent:Hide()

    local manaContent = CreateFrame("Frame", nil, optionsMenu)
    manaContent:SetAllPoints(optionsMenu)
    manaContent:Hide()

    local tabs = {}
    local function SelectTab(index)
        for i, tab in ipairs(tabs) do
            if i == index then
                tab:SetNormalTexture(ACTIVE_TAB)
            else
                tab:SetNormalTexture(INACTIVE_TAB)
            end
        end
        if index == 1 then
            settingsContent:SetVerticalScroll(0)
            settingsScrollbar:SetValue(0)
            settingsContent:Show()
            settingsScrollbar:Show()
        else
            settingsContent:Hide()
            settingsScrollbar:Hide()
        end
        if index == 2 then
            totemSetsContent:Show()
            ui.RefreshSetsTab()
        else
            totemSetsContent:Hide()
        end
        if index == 3 then
            manaContent:Show()
        else
            manaContent:Hide()
        end
    end

    local tabNames = {"Settings", "Totem Sets", "Mana"}
    for i, name in ipairs(tabNames) do
        local tab = CreateFrame("Button", nil, optionsMenu)
        tab:SetWidth(100)
        tab:SetHeight(32)
        if i == 1 then
            tab:SetPoint("TOPLEFT", optionsMenu, "BOTTOMLEFT", 10, 7)
            tab:SetNormalTexture(ACTIVE_TAB)
        else
            tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", -15, 0)
            tab:SetNormalTexture(INACTIVE_TAB)
        end
        tab:SetHighlightTexture(ACTIVE_TAB)
        local tabText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tabText:SetPoint("CENTER", 0, 2)
        tabText:SetText(name)
        tab.index = i
        tab:SetScript("OnClick", function()
            SelectTab(this.index)
        end)
        tabs[i] = tab
    end

    -- ------------------------------------------------------------------
    -- Totem Sets tab
    -- ------------------------------------------------------------------
    MakeText(totemSetsContent, "GameFontNormal", "TOP", 0, -60,
        "Click a set, then click totems to assign them.\nKeybinds: ESC > Key Bindings > TotemNesia (5 keybinds)", 380, "CENTER")
    MakeText(totemSetsContent, "GameFontNormalLarge", "TOP", 0, -110, "Totem Set:")

    -- One row per element: label, clear button, totem buttons
    local setRows = {
        {element = "fire", title = "Fire", y = -190, color = {1, 0.3, 0.3},
         totems = {"Searing Totem", "Fire Nova Totem", "Magma Totem", "Flametongue Totem", "Frost Resistance Totem"}},
        {element = "earth", title = "Earth", y = -235, color = {0.8, 0.6, 0.3},
         totems = {"Stoneclaw Totem", "Stoneskin Totem", "Earthbind Totem", "Strength of Earth Totem", "Tremor Totem"}},
        {element = "water", title = "Water", y = -280, color = {0.3, 0.5, 1},
         totems = {"Healing Stream Totem", "Mana Spring Totem", "Fire Resistance Totem", "Disease Cleansing Totem", "Poison Cleansing Totem"}},
        {element = "air", title = "Air", y = -325, color = {0.7, 0.9, 1},
         totems = {"Grounding Totem", "Windfury Totem", "Grace of Air Totem", "Nature Resistance Totem", "Tranquil Air Totem", "Windwall Totem"}}
    }
    local setTotemButtons = {}  -- element -> list of buttons
    local setButtons = {}

    -- Gold border on the totem picked for the current set, for one element
    local function UpdateSetBorders(element)
        if not TotemNesiaDB or not TotemNesiaDB.totemSets then
            return
        end
        local set = TotemNesiaDB.totemSets[TotemNesiaDB.currentTotemSet or 1]
        if not set then
            return
        end
        local selectedTotem = set[element]
        for _, btn in ipairs(setTotemButtons[element]) do
            if btn.totemName == selectedTotem then
                btn.borderOverlay:SetBackdrop(SELECTED_BORDER)
                btn.borderOverlay:SetBackdropBorderColor(1, 0.82, 0, 1)
            else
                btn.borderOverlay:SetBackdrop(nil)
            end
        end
    end

    -- Refresh set highlight and all borders (called when the tab opens or a set changes)
    function ui.RefreshSetsTab()
        local current = (TotemNesiaDB and TotemNesiaDB.currentTotemSet) or 1
        for j = 1, 5 do
            if j == current then
                setButtons[j]:LockHighlight()
            else
                setButtons[j]:UnlockHighlight()
            end
        end
        for _, row in ipairs(setRows) do
            UpdateSetBorders(row.element)
        end
    end

    -- Set selector buttons (1-5)
    for i = 1, 5 do
        local btn = CreateFrame("Button", nil, totemSetsContent, "UIPanelButtonTemplate")
        btn:SetWidth(40)
        btn:SetHeight(28)
        btn:SetPoint("TOP", -110 + (i - 1) * 55, -140)
        btn:SetText(tostring(i))
        btn.setNumber = i
        btn:SetScript("OnClick", function()
            TotemNesiaDB.currentTotemSet = this.setNumber
            TotemNesia.DebugPrint("Selected Set " .. this.setNumber)
            ui.RefreshSetsTab()
        end)
        setButtons[i] = btn
    end
    setButtons[1]:LockHighlight()

    local function TotemTooltip()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        local highestId = GetHighestLearnedRank(this.totemName)
        if highestId then
            GameTooltip:SetSpell(highestId, BOOKTYPE_SPELL)
        else
            GameTooltip:SetText(this.totemName)
        end
        GameTooltip:Show()
    end
    local function HideTooltip()
        GameTooltip:Hide()
    end

    for _, row in ipairs(setRows) do
        local element = row.element
        setTotemButtons[element] = {}
        MakeText(totemSetsContent, "GameFontNormalLarge", "TOPLEFT", 20, row.y, row.title .. ":")

        -- Clear button
        local clearBtn = CreateFrame("Button", nil, totemSetsContent)
        clearBtn:SetWidth(20)
        clearBtn:SetHeight(20)
        clearBtn:SetPoint("TOPLEFT", 60, row.y - 4)
        clearBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        clearBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
        clearBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
        clearBtn.element = element
        clearBtn.title = row.title
        clearBtn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText("Clear " .. this.title .. " totem assignment")
            GameTooltip:Show()
        end)
        clearBtn:SetScript("OnLeave", HideTooltip)
        clearBtn:SetScript("OnClick", function()
            local set = TotemNesiaDB.currentTotemSet
            TotemNesiaDB.totemSets[set][this.element] = nil
            TotemNesia.DebugPrint("Cleared Set " .. set .. " " .. this.title .. " totem")
            UpdateSetBorders(this.element)
        end)

        -- Totem buttons
        for j, totemName in ipairs(row.totems) do
            local btn = CreateFrame("Button", nil, totemSetsContent)
            btn:SetWidth(28)
            btn:SetHeight(28)
            btn:SetPoint("TOPLEFT", 80 + (j - 1) * 32, row.y)
            btn:SetBackdrop(BUTTON_BACKDROP)
            btn:SetBackdropColor(row.color[1], row.color[2], row.color[3], 0.6)
            btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(btn)
            icon:SetTexture(GetTotemIcon(totemName))
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            table.insert(TotemNesia.totemIcons, {iconTexture = icon, totemName = totemName})

            -- Border overlay above the icon (shows the gold "selected" border)
            local overlay = CreateFrame("Frame", nil, btn)
            overlay:SetAllPoints(btn)
            overlay:SetFrameLevel(btn:GetFrameLevel() + 1)
            btn.borderOverlay = overlay

            btn.totemName = totemName
            btn.element = element
            btn.title = row.title
            btn:SetScript("OnEnter", TotemTooltip)
            btn:SetScript("OnLeave", HideTooltip)
            btn:SetScript("OnClick", function()
                local set = TotemNesiaDB.currentTotemSet
                TotemNesiaDB.totemSets[set][this.element] = this.totemName
                TotemNesia.DebugPrint("Set " .. set .. " " .. this.title .. " = " .. this.totemName)
                UpdateSetBorders(this.element)
            end)
            table.insert(setTotemButtons[element], btn)
        end
    end

    -- ------------------------------------------------------------------
    -- Mana tab
    -- ------------------------------------------------------------------
    MakeText(manaContent, "GameFontNormalLarge", "TOP", 0, -60, "Mana Management")
    MakeText(manaContent, "GameFontNormal", "TOP", 0, -85,
        "Configure low mana alerts to help manage your mana pool during combat.", 360, "CENTER")
    MakeCheckbox(manaContent, "TOPLEFT", 20, -110, "Mute low mana alert", "manaAudioMuted")
    MakeCheckbox(manaContent, "TOPLEFT", 20, -140, "Mute potion alert", "potionAudioMuted")
    MakeCheckbox(manaContent, "TOPLEFT", 210, -110, "Disable public mana alert", "publicManaMuted")
    MakeSlider(manaContent, -170, 0, 100, 5, "manaThreshold",
        function(v) return "Low Mana Alert Threshold: " .. v .. "%" end, RoundFive)
    MakeSlider(manaContent, -220, 0, 100, 5, "potionThreshold",
        function(v) return "Potion Alert: " .. v .. "%" end, RoundFive)
    MakeText(manaContent, "GameFontNormalSmall", "TOP", 0, -280,
        "The addon will play an audio alert when your mana drops below the threshold.\n\nThe alert has a 30-second cooldown to prevent spam and only triggers when crossing below the threshold (not while hovering).",
        360, "LEFT")

    -- ------------------------------------------------------------------
    -- Settings tab (scrolling)
    -- ------------------------------------------------------------------
    local sc = settingsScrollChild

    -- Left column
    MakeCheckbox(sc, "TOPLEFT", 20, -45, "Lock recall notification", "isLocked", false, function(locked)
        if locked then
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
    MakeCheckbox(sc, "TOPLEFT", 20, -75, "Hide recall notification", "hideUIElement")
    MakeCheckbox(sc, "TOPLEFT", 20, -105, "Mute recall audio queue", "audioEnabled", true)
    MakeCheckbox(sc, "TOPLEFT", 20, -135, "Lock totem tracker", "totemTrackerLocked", false, function(locked)
        totemTracker:EnableMouse(not locked)
    end)
    MakeCheckbox(sc, "TOPLEFT", 20, -165, "Hide totem tracker", "totemTrackerHidden", false, function()
        TotemNesia.UpdateTotemTracker()
    end)

    -- Right column
    MakeCheckbox(sc, "TOPLEFT", 210, -45, "Enable totem bar", "totemBarEnabled", false, function()
        TotemNesia.UpdateTotemBar()
    end)
    MakeCheckbox(sc, "TOPLEFT", 210, -75, "Lock totem bar", "totemBarLocked", false, function(locked)
        totemBar:EnableMouse(not locked)
    end)
    MakeCheckbox(sc, "TOPLEFT", 210, -105, "Disable shift for flyouts", "shiftToOpenFlyouts")
    MakeCheckbox(sc, "TOPLEFT", 210, -135, "Hide weapon enchant slot", "hideWeaponSlot", false, function()
        TotemNesia.UpdateTotemBar()
    end)

    -- Group types
    MakeText(sc, "GameFontNormal", "TOPLEFT", 20, -190, "Will be enabled when in:")
    MakeCheckbox(sc, "TOPLEFT", 20, -210, "Solo", "enabledSolo")
    MakeCheckbox(sc, "TOPLEFT", 20, -235, "Parties", "enabledParty")
    MakeCheckbox(sc, "TOPLEFT", 20, -260, "Raids", "enabledRaid")

    -- Totem bar layout and flyout direction
    local layoutButton = CreateFrame("Button", nil, sc, "UIPanelButtonTemplate")
    layoutButton:SetWidth(120)
    layoutButton:SetHeight(24)
    layoutButton:SetPoint("TOPRIGHT", -20, -205)
    layoutButton:SetText("Horizontal")
    local layoutLabel = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    layoutLabel:SetPoint("BOTTOM", layoutButton, "TOP", 0, 2)
    layoutLabel:SetText("Totem Bar Layout:")

    local flyoutButton = CreateFrame("Button", nil, sc, "UIPanelButtonTemplate")
    flyoutButton:SetWidth(120)
    flyoutButton:SetHeight(24)
    flyoutButton:SetPoint("TOPRIGHT", -20, -255)
    flyoutButton:SetText("Up")
    local flyoutLabel = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    flyoutLabel:SetPoint("BOTTOM", flyoutButton, "TOP", 0, 2)
    flyoutLabel:SetText("Flyout Direction:")

    layoutButton:SetScript("OnClick", function()
        if TotemNesiaDB.totemBarLayout == "Horizontal" then
            -- Vertical layout defaults its flyouts to the right
            TotemNesiaDB.totemBarLayout = "Vertical"
            TotemNesiaDB.totemBarFlyoutDirection = "Right"
        else
            -- Horizontal layout defaults its flyouts upward
            TotemNesiaDB.totemBarLayout = "Horizontal"
            TotemNesiaDB.totemBarFlyoutDirection = "Up"
        end
        this:SetText(TotemNesiaDB.totemBarLayout)
        flyoutButton:SetText(TotemNesiaDB.totemBarFlyoutDirection)
        TotemNesia.DebugPrint("Layout changed to " .. TotemNesiaDB.totemBarLayout .. ", flyout direction set to " .. TotemNesiaDB.totemBarFlyoutDirection)
        TotemNesia.UpdateTotemBar()
        TotemNesia.UpdateTotemBarFlyouts()
    end)

    flyoutButton:SetScript("OnClick", function()
        local direction = TotemNesiaDB.totemBarFlyoutDirection
        if TotemNesiaDB.totemBarLayout == "Vertical" then
            -- Vertical layout: cycle between Left and Right
            if direction == "Left" then direction = "Right" else direction = "Left" end
        else
            -- Horizontal layout: cycle between Up and Down
            if direction == "Up" then direction = "Down" else direction = "Up" end
        end
        TotemNesiaDB.totemBarFlyoutDirection = direction
        this:SetText(direction)
        TotemNesia.UpdateTotemBarFlyouts()
    end)
    ui.layoutButton = layoutButton
    ui.flyoutButton = flyoutButton

    -- Sliders
    MakeSlider(sc, -285, 15, 60, 1, "timerDuration",
        function(v) return "Display Duration: " .. v .. "s" end, RoundWhole)
    MakeSlider(sc, -330, 0.5, 2.0, 0.1, "uiFrameScale",
        function(v) return "Recall Notification Scale: " .. v end, RoundTenth,
        function(v) iconFrame:SetScale(v) end)
    MakeSlider(sc, -375, 0.5, 2.0, 0.1, "totemTrackerScale",
        function(v) return "Totem Tracker Scale: " .. v end, RoundTenth,
        function(v) totemTracker:SetScale(v) end)
    MakeSlider(sc, -420, 0.5, 2.0, 0.1, "totemBarScale",
        function(v) return "Totem Bar Scale: " .. v end, RoundTenth,
        function(v) totemBar:SetScale(v) end)

    -- Keybind note and read-only recall macro
    MakeText(sc, "GameFontNormal", "TOP", 0, -530,
        "Keybinds: Sequential Totem Cast keybind available in ESC > Key Bindings > TotemNesia", 360, "CENTER")
    local RECALL_MACRO = "/script TotemNesia_RecallTotems()"
    local macroBox = CreateFrame("EditBox", nil, sc)
    macroBox:SetPoint("TOPLEFT", 20, -550)
    macroBox:SetWidth(360)
    macroBox:SetHeight(20)
    macroBox:SetFontObject(GameFontNormalSmall)
    macroBox:SetText(RECALL_MACRO)
    macroBox:SetAutoFocus(false)
    macroBox:SetScript("OnEditFocusGained", function() this:HighlightText() end)
    macroBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    macroBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    macroBox:SetScript("OnChar", function()
        -- Block all character input
        this:SetText(RECALL_MACRO)
        this:HighlightText()
    end)
    macroBox:SetScript("OnTextChanged", function()
        -- Restore text if it gets changed
        if this:GetText() ~= RECALL_MACRO then
            this:SetText(RECALL_MACRO)
            this:HighlightText()
        end
    end)

    MakeCheckbox(sc, "TOPRIGHT", -20, -550, "Debug mode", "debugMode", false, nil, true)

    -- Range
    MakeSlider(sc, -595, 10, 40, 1, "totemRange",
        function(v) return "Totem Range: " .. v .. " yds" end, RoundWhole)
    MakeText(sc, "GameFontNormalSmall", "TOP", 0, -638,
        "The recall reminder shows when you move farther than this from your totems. With SuperWoW, totem icons also turn red when you are out of a totem's range (Searing Totem 20 yds, Magma Totem 8 yds).",
        350, "LEFT")

    -- Shield slot
    MakeCheckbox(sc, "TOPLEFT", 20, -685, "Hide shield slot", "hideShieldSlot", false, function()
        TotemNesia.UpdateTotemBar()
    end)
    MakeCheckbox(sc, "TOPLEFT", 210, -685, "Flash when shield is low", "shieldFlash")

    -- Totem bar controls help
    MakeText(sc, "GameFontNormalSmall", "TOP", 0, -720,
        "Totem bar: Ctrl-click a flyout totem to put it in the slot. Alt-click a flyout totem to make it the slot's fallback, cast when the slot totem is on cooldown (Alt-click it again to clear). Right-click the water slot to cycle Anti-Poison (P), Anti-Disease (D), and off. Click the shield slot, or use the Recast Shield keybind, to recast your shield.",
        350, "LEFT")

    -- ------------------------------------------------------------------
    -- Refresh every control from the saved settings (runs when the window opens)
    -- ------------------------------------------------------------------
    function ui.RefreshAll()
        for _, cb in ipairs(checkboxes) do
            local value = TotemNesiaDB[cb.dbKey]
            if cb.invert then
                value = not value
            end
            cb:SetChecked(value)
        end
        for _, slider in ipairs(sliders) do
            local value = TotemNesiaDB[slider.dbKey]
            if value then
                slider:SetValue(value)
                slider.label:SetText(slider.format(value))
            end
        end
        layoutButton:SetText(TotemNesiaDB.totemBarLayout or "Horizontal")
        flyoutButton:SetText(TotemNesiaDB.totemBarFlyoutDirection or "Up")
        SelectTab(1)
    end
end

TNC.BuildOptionsUI()

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
    TotemNesia.SetTooltipOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("TotemNesia")
    GameTooltip:AddLine("Click to open Settings", 1, 1, 1)
    GameTooltip:AddLine("Right-click to drag", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Click to open options menu (every control is refreshed from saved settings first)
minimapButton:SetScript("OnClick", function()
    if optionsMenu:IsVisible() then
        optionsMenu:Hide()
    else
        TNC.ui.RefreshAll()
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


-- Share with files loaded after this one
TotemNesia.shared.minimapButton = minimapButton
