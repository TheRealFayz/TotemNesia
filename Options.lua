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
authorText:SetText("By Fayz")
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
    -- Pages and tabs
    -- Every tab is a page inside the one scroll area. Only the selected page is shown,
    -- and the scroll area is sized to that page so there is no empty space at the bottom.
    -- ------------------------------------------------------------------
    local sc = settingsScrollChild
    local COL_L, COL_R = 15, 195
    local pages = {}
    local pg      -- page being built
    local y = 0   -- running row cursor on that page

    local function NewPage()
        local page = CreateFrame("Frame", nil, sc)
        page:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, 0)
        page:SetWidth(360)
        page:SetHeight(10)
        page:Hide()
        table.insert(pages, page)
        pg = page
        y = -8
        return page
    end

    -- Finish the page being built: remember how tall it is
    local function EndPage()
        pg.contentHeight = -y + 4
        pg:SetHeight(pg.contentHeight)
    end

    -- Section header: white title with a thin gold line under it
    local function Header(text)
        MakeText(pg, "GameFontHighlight", "TOPLEFT", 12, y, text)
        local line = pg:CreateTexture(nil, "ARTWORK")
        line:SetTexture(1, 0.82, 0, 0.35)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", pg, "TOPLEFT", 12, y - 16)
        line:SetPoint("TOPRIGHT", pg, "TOPRIGHT", -8, y - 16)
        y = y - 24
    end

    -- Checkbox at the current row
    local function Check(x, text, dbKey, invert, onChange)
        return MakeCheckbox(pg, "TOPLEFT", x, y, text, dbKey, invert, onChange)
    end

    -- Slider at the current row, then move the cursor past it
    local function Slider(minValue, maxValue, step, dbKey, format, round, onChange)
        MakeSlider(pg, y, minValue, maxValue, step, dbKey, format, round, onChange)
        y = y - 46
    end

    -- Small help text at the current row, then move the cursor past it
    local function Note(text, height)
        MakeText(pg, "GameFontNormalSmall", "TOPLEFT", COL_L, y, text, 335, "LEFT")
        y = y - height
    end

    local tabs = {}
    local function SelectTab(index)
        for i, tab in ipairs(tabs) do
            if i == index then
                tab:SetNormalTexture(ACTIVE_TAB)
            else
                tab:SetNormalTexture(INACTIVE_TAB)
            end
        end
        for i, page in ipairs(pages) do
            if i == index then
                page:Show()
            else
                page:Hide()
            end
        end
        sc:SetHeight(pages[index].contentHeight or 10)
        settingsContent:UpdateScrollChildRect()
        settingsContent:SetVerticalScroll(0)
        settingsScrollbar:SetValue(0)
        if index == 3 then
            ui.RefreshSetsTab()
        end
    end

    local tabNames = {"General", "Totem Bar", "Totem Sets", "Alerts"}
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

    -- ==================================================================
    -- Tab 1: General
    -- ==================================================================
    NewPage()

    Header("Recall Notification")
    Check(COL_L, "Lock recall notification", "isLocked", false, function(locked)
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
    Check(COL_R, "Hide recall notification", "hideUIElement")
    y = y - 30
    Slider(15, 60, 1, "timerDuration",
        function(v) return "Display Duration: " .. v .. "s" end, RoundWhole)
    Slider(0.5, 2.0, 0.1, "uiFrameScale",
        function(v) return "Scale: " .. v end, RoundTenth,
        function(v) iconFrame:SetScale(v) end)
    y = y - 6

    Header("Totem Tracker")
    Check(COL_L, "Lock totem tracker", "totemTrackerLocked", false, function(locked)
        totemTracker:EnableMouse(not locked)
    end)
    Check(COL_R, "Hide totem tracker", "totemTrackerHidden", false, function()
        TotemNesia.UpdateTotemTracker()
    end)
    y = y - 30
    Slider(0.5, 2.0, 0.1, "totemTrackerScale",
        function(v) return "Scale: " .. v end, RoundTenth,
        function(v) totemTracker:SetScale(v) end)
    y = y - 6

    Header("Totem Range")
    Slider(10, 40, 1, "totemRange",
        function(v) return "Totem Range: " .. v .. " yds" end, RoundWhole)
    Note("The recall reminder shows when you move farther than this from your totems. With SuperWoW, totem icons also turn red when you are out of a totem's range (Searing Totem 20 yds, Magma Totem 8 yds).", 52)

    Header("Enabled When In")
    Check(COL_L, "Solo", "enabledSolo")
    Check(135, "Parties", "enabledParty")
    Check(255, "Raids", "enabledRaid")
    y = y - 36

    Header("Keybinds and Macro")
    Note("Set keybinds in ESC > Key Bindings > TotemNesia. Recall macro (click to select, then Ctrl-C):", 30)
    local RECALL_MACRO = "/script TotemNesia_RecallTotems()"
    local macroBox = CreateFrame("EditBox", nil, pg)
    macroBox:SetPoint("TOPLEFT", COL_L + 4, y)
    macroBox:SetWidth(330)
    macroBox:SetHeight(20)
    macroBox:SetFontObject(GameFontHighlightSmall)
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
    y = y - 28
    Check(COL_L, "Debug mode", "debugMode")
    y = y - 30
    EndPage()

    -- ==================================================================
    -- Tab 2: Totem Bar
    -- ==================================================================
    NewPage()

    Header("Totem Bar")
    Check(COL_L, "Enable totem bar", "totemBarEnabled", false, function()
        TotemNesia.UpdateTotemBar()
    end)
    Check(COL_R, "Lock totem bar", "totemBarLocked", false, function(locked)
        totemBar:EnableMouse(not locked)
    end)
    y = y - 26
    Check(COL_L, "Disable shift for flyouts", "shiftToOpenFlyouts")
    y = y - 36

    Header("Slots")
    Check(COL_L, "Hide weapon enchant slot", "hideWeaponSlot", false, function()
        TotemNesia.UpdateTotemBar()
    end)
    Check(COL_R, "Hide shield slot", "hideShieldSlot", false, function()
        TotemNesia.UpdateTotemBar()
    end)
    y = y - 26
    Check(COL_L, "Flash when shield is low", "shieldFlash")
    y = y - 36

    Header("Layout")
    MakeText(pg, "GameFontNormal", "TOPLEFT", COL_L + 4, y, "Orientation:")
    MakeText(pg, "GameFontNormal", "TOPLEFT", COL_R + 4, y, "Flyout Direction:")
    local layoutButton = CreateFrame("Button", nil, pg, "UIPanelButtonTemplate")
    layoutButton:SetWidth(140)
    layoutButton:SetHeight(24)
    layoutButton:SetPoint("TOPLEFT", COL_L, y - 16)
    layoutButton:SetText("Horizontal")

    local flyoutButton = CreateFrame("Button", nil, pg, "UIPanelButtonTemplate")
    flyoutButton:SetWidth(140)
    flyoutButton:SetHeight(24)
    flyoutButton:SetPoint("TOPLEFT", COL_R, y - 16)
    flyoutButton:SetText("Up")

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
    y = y - 50
    Slider(0.5, 2.0, 0.1, "totemBarScale",
        function(v) return "Scale: " .. v end, RoundTenth,
        function(v) totemBar:SetScale(v) end)
    y = y - 6

    Header("How to Use")
    Note("Hold Shift and mouse over a slot to open its flyout (unless shift is disabled above).", 30)
    Note("Ctrl-click a flyout totem or weapon enchant to put it in the slot.", 18)
    Note("Alt-click a flyout totem to make it the slot's fallback, cast when the slot totem is on cooldown. Alt-click it again to clear.", 30)
    Note("Right-click the water slot to cycle Anti-Poison (P), Anti-Disease (D), and off.", 30)
    Note("Click the shield slot, or use the Recast Shield keybind, to recast your shield.", 22)
    EndPage()

    -- ==================================================================
    -- Tab 3: Totem Sets
    -- ==================================================================
    local setsPage = NewPage()
    Note("Pick a set, then click a totem in each row to assign it. A gold border marks the assigned totem. Each set has its own keybind in ESC > Key Bindings > TotemNesia.", 44)

    Header("Set")
    local setButtons = {}
    for i = 1, 5 do
        local btn = CreateFrame("Button", nil, setsPage, "UIPanelButtonTemplate")
        btn:SetWidth(44)
        btn:SetHeight(24)
        btn:SetPoint("TOPLEFT", COL_L + (i - 1) * 52, y)
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
    y = y - 36

    Header("Totems")
    -- One row per element: label, clear button, totem buttons
    local setRows = {
        {element = "fire", title = "Fire", color = {1, 0.3, 0.3},
         totems = {"Searing Totem", "Fire Nova Totem", "Magma Totem", "Flametongue Totem", "Frost Resistance Totem"}},
        {element = "earth", title = "Earth", color = {0.8, 0.6, 0.3},
         totems = {"Stoneclaw Totem", "Stoneskin Totem", "Earthbind Totem", "Strength of Earth Totem", "Tremor Totem"}},
        {element = "water", title = "Water", color = {0.3, 0.5, 1},
         totems = {"Healing Stream Totem", "Mana Spring Totem", "Fire Resistance Totem", "Disease Cleansing Totem", "Poison Cleansing Totem"}},
        {element = "air", title = "Air", color = {0.7, 0.9, 1},
         totems = {"Grounding Totem", "Windfury Totem", "Grace of Air Totem", "Nature Resistance Totem", "Tranquil Air Totem", "Windwall Totem"}}
    }
    local setTotemButtons = {}  -- element -> list of buttons

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
        local label = MakeText(setsPage, "GameFontNormal", "TOPLEFT", COL_L + 4, y - 8, row.title)
        label:SetTextColor(row.color[1], row.color[2], row.color[3])

        -- Clear button
        local clearBtn = CreateFrame("Button", nil, setsPage)
        clearBtn:SetWidth(22)
        clearBtn:SetHeight(22)
        clearBtn:SetPoint("TOPLEFT", 62, y - 3)
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
            local btn = CreateFrame("Button", nil, setsPage)
            btn:SetWidth(28)
            btn:SetHeight(28)
            btn:SetPoint("TOPLEFT", 90 + (j - 1) * 32, y)
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
        y = y - 36
    end
    EndPage()

    -- ==================================================================
    -- Tab 4: Alerts
    -- ==================================================================
    NewPage()

    Header("Audio Alerts")
    MakeText(pg, "GameFontNormal", "TOPLEFT", COL_L, y - 10, "Alert Voice:")
    local voiceDropDown = CreateFrame("Frame", "TotemNesiaVoiceDropDown", pg, "UIDropDownMenuTemplate")
    voiceDropDown:SetPoint("TOPLEFT", 75, y)
    UIDropDownMenu_SetWidth(110, voiceDropDown)
    UIDropDownMenu_Initialize(voiceDropDown, function()
        for _, name in ipairs(TNC.VOICES) do
            local info = {}
            info.text = name
            info.value = name
            info.checked = (TotemNesiaDB and TotemNesiaDB.alertVoice == name)
            info.func = function()
                TotemNesiaDB.alertVoice = this.value
                UIDropDownMenu_SetText(this.value, TotemNesiaVoiceDropDown)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    ui.voiceDropDown = voiceDropDown

    -- Play button: plays the Totems alert in the chosen voice (ignores the mute settings)
    local voiceTest = CreateFrame("Button", nil, pg)
    voiceTest:SetWidth(26)
    voiceTest:SetHeight(26)
    voiceTest:SetPoint("LEFT", voiceDropDown, "RIGHT", -12, 2)
    voiceTest:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    voiceTest:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    voiceTest:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    voiceTest:SetScript("OnClick", function()
        TotemNesia.PlayAlertSound("Totems")
    end)
    voiceTest:SetScript("OnEnter", function()
        TotemNesia.SetTooltipOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Test voice", 1, 1, 1)
        GameTooltip:AddLine("Plays the Totems alert in the chosen voice", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    voiceTest:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    y = y - 36
    Check(COL_L, "Mute recall alert", "audioEnabled", true)
    Check(COL_R, "Mute low mana alert", "manaAudioMuted")
    y = y - 26
    Check(COL_L, "Mute potion alert", "potionAudioMuted")
    y = y - 36

    Header("Mana Alerts")
    Slider(0, 100, 5, "manaThreshold",
        function(v) return "Low Mana Threshold: " .. v .. "%" end, RoundFive)
    Slider(0, 100, 5, "potionThreshold",
        function(v) return "Potion Threshold: " .. v .. "%" end, RoundFive)
    Note("An alert plays when your mana drops below a threshold. Each alert has a 30 second cooldown and only fires when you cross below the line. Set a slider to 0% to turn that alert off.", 52)

    Header("Chat")
    Check(COL_L, "Disable public mana alert", "publicManaMuted")
    y = y - 30
    Note("When your mana drops below 15%, TotemNesia says \"I am low on mana, I need to drink.\" in /say so your group knows. 30 second cooldown.", 40)
    EndPage()

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
        UIDropDownMenu_SetText(TotemNesiaDB.alertVoice or "Jenny", voiceDropDown)
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
