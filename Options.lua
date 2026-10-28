-- TotemNesia: Minimap button and the options window
-- For OctoWoW (1.12)

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

local LOGO = "Interface\\AddOns\\TotemNesia\\Textures\\Logo"

-- ============================================================================
-- SPINNING LOGO
-- ============================================================================
-- The logo on the settings window and the minimap button does one quick spin every
-- SPIN_EVERY seconds. WoW 1.12 has no texture rotation, so the spin turns the texture
-- coordinates instead. Logo.tga keeps the art inside the middle of the image, so the
-- turned coordinates never reach past its edges and the corners stay clear.
local SPIN_EVERY = 3     -- seconds from the start of one spin to the start of the next
local SPIN_TIME = 0.6    -- how long a spin takes
local SPIN_K = 0.35355   -- half the diagonal of the visible square, in texture units
local spinTextures = {}
local spinClock = 0
local spinResting = false

local function SetLogoAngle(tex, a)
    local c, s = math.cos(a), math.sin(a)
    local k = SPIN_K
    tex:SetTexCoord(
        0.5 + k * (s - c), 0.5 - k * (s + c),   -- upper left
        0.5 - k * (c + s), 0.5 + k * (c - s),   -- lower left
        0.5 + k * (c + s), 0.5 + k * (s - c),   -- upper right
        0.5 + k * (c - s), 0.5 + k * (s + c))   -- lower right
end

local spinFrame = CreateFrame("Frame")
spinFrame:SetScript("OnUpdate", function()
    spinClock = math.mod(spinClock + (arg1 or 0), SPIN_EVERY)
    local t = spinClock / SPIN_TIME
    if t < 1 then
        -- Ease in and out, one full turn clockwise
        local eased = t * t * (3 - 2 * t)
        local angle = -2 * math.pi * eased
        for i = 1, table.getn(spinTextures) do
            SetLogoAngle(spinTextures[i], angle)
        end
        spinResting = false
    elseif not spinResting then
        for i = 1, table.getn(spinTextures) do
            SetLogoAngle(spinTextures[i], 0)
        end
        spinResting = true
    end
end)

-- ============================================================================
-- MINIMAP BUTTON
-- ============================================================================
local minimapButton = CreateFrame("Button", "TotemNesiaMinimapButton", Minimap)
minimapButton:SetWidth(31)   -- the usual minimap button size, so button bars that
minimapButton:SetHeight(31)  -- scale every button the same (pfUI) treat it like the rest
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- The logo has its own ring, so it doesn't need the usual minimap button border. It's
-- drawn a little smaller than the button so its ring is the same size as the gold ring
-- on other addons' buttons.
local minimapIcon = minimapButton:CreateTexture(nil, "ARTWORK")
minimapIcon:SetWidth(28)
minimapIcon:SetHeight(28)
minimapIcon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
minimapIcon:SetTexture(LOGO)
SetLogoAngle(minimapIcon, 0)
table.insert(spinTextures, minimapIcon)

-- ============================================================================
-- SETTINGS WINDOW
-- ============================================================================
-- Blizzard dialog frame with the round logo over the top-left corner, the title in the
-- middle, a dark inset holding the settings, and icon tabs down the right side.
local W, H = 400, 500
local CW = 322        -- usable width inside a page

local optionsMenu = CreateFrame("Frame", "TotemNesiaOptionsMenu", UIParent)
optionsMenu:SetWidth(W)
optionsMenu:SetHeight(H)
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
optionsMenu:SetClampedToScreen(true)
optionsMenu:RegisterForDrag("LeftButton")
optionsMenu:SetScript("OnDragStart", function() this:StartMoving() end)
optionsMenu:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
optionsMenu:Hide()

-- Close with Esc
table.insert(UISpecialFrames, "TotemNesiaOptionsMenu")

-- Round logo over the top-left corner
local portraitFrame = CreateFrame("Frame", nil, optionsMenu)
portraitFrame:SetWidth(72)
portraitFrame:SetHeight(72)
portraitFrame:SetPoint("TOPLEFT", optionsMenu, "TOPLEFT", -12, 12)
portraitFrame:SetFrameLevel(optionsMenu:GetFrameLevel() + 5)
local portrait = portraitFrame:CreateTexture(nil, "ARTWORK")
portrait:SetAllPoints(portraitFrame)
portrait:SetTexture(LOGO)
SetLogoAngle(portrait, 0)
table.insert(spinTextures, portrait)

-- Title, a little right of center to balance the logo
local menuTitle = optionsMenu:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
menuTitle:SetPoint("TOP", optionsMenu, "TOP", 16, -18)
menuTitle:SetText("TotemNesia")
local authorText = optionsMenu:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
authorText:SetPoint("TOP", menuTitle, "BOTTOM", 0, -2)
authorText:SetText("By Fayz")
local versionText = optionsMenu:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
versionText:SetPoint("TOP", authorText, "BOTTOM", 0, -6)
versionText:SetText("|cff888888Version " .. TotemNesia.GetVersion() .. "|r")

local closeButton = CreateFrame("Button", "TotemNesiaOptionsClose", optionsMenu, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", optionsMenu, "TOPRIGHT", -6, -6)

-- ----------------------------------------------------------------------------
-- Scale grip in the bottom-right corner: drag to scale the whole window, right-click
-- to put it back to 100%. The top-left corner stays put while you drag. The scale is
-- saved per character.
-- ----------------------------------------------------------------------------
local TEXTURES = "Interface\\AddOns\\TotemNesia\\Textures\\"
local MIN_SCALE, MAX_SCALE = 0.6, 1.6

local function SetWindowScale(s, absLeft, absTop)
    if s < MIN_SCALE then s = MIN_SCALE end
    if s > MAX_SCALE then s = MAX_SCALE end
    s = math.floor(s * 100 + 0.5) / 100
    if not absLeft then
        local eff = optionsMenu:GetEffectiveScale()
        absLeft = optionsMenu:GetLeft() * eff
        absTop = optionsMenu:GetTop() * eff
    end
    optionsMenu:SetScale(s)
    -- keep the top-left corner where it was on screen
    local eff = optionsMenu:GetEffectiveScale()
    optionsMenu:ClearAllPoints()
    optionsMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", absLeft / eff, absTop / eff)
    TotemNesiaCharDB.optionsScale = s
end

local scaleGrip = CreateFrame("Button", nil, optionsMenu)
scaleGrip:SetWidth(16)
scaleGrip:SetHeight(16)
scaleGrip:SetPoint("BOTTOMRIGHT", optionsMenu, "BOTTOMRIGHT", -10, 10)
scaleGrip:SetFrameLevel(optionsMenu:GetFrameLevel() + 10)
scaleGrip:EnableMouse(true)
scaleGrip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
scaleGrip:SetNormalTexture(TEXTURES .. "SizeGrabber-Up")
scaleGrip:SetPushedTexture(TEXTURES .. "SizeGrabber-Down")
scaleGrip:SetHighlightTexture(TEXTURES .. "SizeGrabber-Highlight")
scaleGrip:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Drag to resize")
    GameTooltip:AddLine("Right-click to reset", 1, 1, 1)
    GameTooltip:Show()
end)
scaleGrip:SetScript("OnLeave", function()
    if not this.sizing then
        GameTooltip:Hide()
    end
end)
scaleGrip:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" then
        local eff = optionsMenu:GetEffectiveScale()
        this.left = optionsMenu:GetLeft() * eff
        this.top = optionsMenu:GetTop() * eff
        this.sizing = true
        this:SetButtonState("PUSHED", 1)  -- stay pressed for the whole drag
    elseif arg1 == "RightButton" then
        SetWindowScale(1)
    end
end)
scaleGrip:SetScript("OnMouseUp", function()
    if this.sizing then
        this.sizing = false
        this:SetButtonState("NORMAL")
        GameTooltip:Hide()
    end
end)
scaleGrip:SetScript("OnUpdate", function()
    if not this.sizing then
        return
    end
    local cx, cy = GetCursorPosition()
    -- scale the window so its bottom-right corner follows the cursor
    local wantEff = ((cx - this.left) / W + (this.top - cy) / H) / 2
    SetWindowScale(wantEff / UIParent:GetEffectiveScale(), this.left, this.top)
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Scale: " .. math.floor(TotemNesiaCharDB.optionsScale * 100 + 0.5) .. "%")
    GameTooltip:Show()
end)

-- Dark inset that holds the settings
local BOX_BACKDROP = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
}
local inset = CreateFrame("Frame", nil, optionsMenu)
inset:SetPoint("TOPLEFT", optionsMenu, "TOPLEFT", 14, -72)
inset:SetPoint("BOTTOMRIGHT", optionsMenu, "BOTTOMRIGHT", -14, 28)  -- the strip below holds the scale grip
inset:SetBackdrop(BOX_BACKDROP)
inset:SetBackdropColor(0, 0, 0, 0.5)
inset:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

-- One scroll area; each tab is a page inside it
local settingsContent = CreateFrame("ScrollFrame", "TotemNesiaOptionsScroll", inset, "UIPanelScrollFrameTemplate")
settingsContent:SetPoint("TOPLEFT", inset, "TOPLEFT", 6, -8)
settingsContent:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -28, 8)
settingsContent.scrollBarHideable = 1
local settingsScrollChild = CreateFrame("Frame", nil, settingsContent)
settingsScrollChild:SetWidth(CW + 8)
settingsScrollChild:SetHeight(100)
settingsContent:SetScrollChild(settingsScrollChild)
settingsContent:EnableMouseWheel(true)
settingsContent:SetScript("OnMouseWheel", function()
    local bar = getglobal("TotemNesiaOptionsScrollScrollBar")
    if bar and bar:IsShown() then
        bar:SetValue(bar:GetValue() - arg1 * 40)
    end
end)

-- Show the scroll bar only when the page is taller than the inset
local function UpdateScrollBar()
    settingsContent:UpdateScrollChildRect()
    local bar = getglobal("TotemNesiaOptionsScrollScrollBar")
    if not bar then
        return
    end
    if (settingsScrollChild:GetHeight() or 0) > (settingsContent:GetHeight() or 0) + 1 then
        bar:Show()
    else
        bar:SetValue(0)
        bar:Hide()
    end
end

-- ============================================================================
-- OPTIONS WINDOW CONTENT
-- ============================================================================
-- Everything is built inside one function so its controls are local to that function
-- instead of the file. A Lua file can only hold 200 top-level locals, and a single
-- function can only reach 32 outside locals (upvalues) in WoW's Lua 5.0. Building the
-- UI from small helpers and data tables keeps TotemNesia far away from both limits.

function TNC.BuildOptionsUI()
    local ui = {}
    TNC.ui = ui

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

    -- Unique names for controls whose templates need one (sliders)
    local uid = 0
    local function NewName(prefix)
        uid = uid + 1
        return "TotemNesiaOpt" .. prefix .. uid
    end

    local function Tooltip(frame, title, text)
        frame.tipTitle = title
        frame.tipText = text
        frame:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(this.tipTitle)
            if this.tipText then
                GameTooltip:AddLine(this.tipText, 1, 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- ------------------------------------------------------------------
    -- Small builders
    -- ------------------------------------------------------------------
    local function MakeText(parent, font, point, x, y, text, width, justify)
        local fs = parent:CreateFontString(nil, "ARTWORK", font)
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
    -- onChange runs after the setting is saved. The label is part of the click area.
    local checkboxes = {}
    local function MakeCheckbox(parent, x, y, text, dbKey, invert, onChange)
        local cb = CreateFrame("CheckButton", nil, parent)
        cb:SetWidth(22)
        cb:SetHeight(22)
        cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        local hl = cb:GetHighlightTexture()
        if hl then
            hl:SetBlendMode("ADD")
        end
        cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        local label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 4, 1)
        label:SetText(text)
        if cb.SetHitRectInsets then
            cb:SetHitRectInsets(0, -(label:GetStringWidth() or 0) - 6, 0, 0)
        end
        cb.dbKey = dbKey
        cb.invert = invert
        cb.onChange = onChange
        cb:SetScript("OnClick", function()
            local checked = this:GetChecked() and true or false
            if this.invert then
                TotemNesiaCharDB[this.dbKey] = not checked
            else
                TotemNesiaCharDB[this.dbKey] = checked
            end
            if this.onChange then
                this.onChange(TotemNesiaCharDB[this.dbKey])
            end
        end)
        table.insert(checkboxes, cb)
        return cb
    end

    -- Slider bound to a saved setting: "Label:  value" above the bar.
    -- valueText(value) formats the value, round(raw) turns the raw slider value into
    -- the stored value.
    local sliders = {}
    local function MakeSlider(parent, y, label, minValue, maxValue, step, dbKey, valueText, round, onChange)
        local name = NewName("Slider")
        local title = MakeText(parent, "GameFontNormalSmall", "TOPLEFT", 12, y, label)
        local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, y - 16)
        slider:SetWidth(CW - 16)
        slider:SetHeight(16)
        slider:SetMinMaxValues(minValue, maxValue)
        slider:SetValueStep(step)
        getglobal(name .. "Low"):SetText(valueText(minValue))
        getglobal(name .. "High"):SetText(valueText(maxValue))
        getglobal(name .. "Text"):SetText("")
        slider.title = title
        slider.labelText = label
        slider.dbKey = dbKey
        slider.valueText = valueText
        slider.round = round
        slider.onChange = onChange
        slider.ShowValue = function(self, value)
            self.title:SetText(self.labelText .. ":  |cffffffff" .. self.valueText(value) .. "|r")
        end
        slider:SetScript("OnValueChanged", function()
            local value = this.round(this:GetValue())
            this:ShowValue(value)
            if this.loading then
                return
            end
            TotemNesiaCharDB[this.dbKey] = value
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
    local function Seconds(v) return v .. "s" end
    local function Yards(v) return v .. " yds" end
    local function Percent(v) return v .. "%" end
    local function Plain(v) return tostring(v) end

    -- ------------------------------------------------------------------
    -- Pages and tabs
    -- Every tab is a page inside the one scroll area. Only the selected page is shown,
    -- and the scroll area is sized to that page so there is no empty space at the bottom.
    -- ------------------------------------------------------------------
    local sc = settingsScrollChild
    local COL_L, COL_R = 8, 170
    local pages = {}
    local pg      -- page being built
    local y = 0   -- running row cursor on that page

    local function NewPage()
        local page = CreateFrame("Frame", nil, sc)
        page:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, 0)
        page:SetWidth(CW + 8)
        page:SetHeight(10)
        page:Hide()
        table.insert(pages, page)
        pg = page
        y = -6
        return page
    end

    -- Finish the page being built: remember how tall it is
    local function EndPage()
        pg.contentHeight = -y + 6
        pg:SetHeight(pg.contentHeight)
    end

    -- Gold section title with a faint gold rule under it
    local function Header(text)
        if y < -6 then
            y = y - 8   -- a little air above every section but the first
        end
        MakeText(pg, "GameFontNormal", "TOPLEFT", 8, y, text)
        local rule = pg:CreateTexture(nil, "ARTWORK")
        rule:SetTexture(1, 0.82, 0, 0.25)
        rule:SetHeight(1)
        rule:SetWidth(CW)
        rule:SetPoint("TOPLEFT", pg, "TOPLEFT", 8, y - 16)
        y = y - 26
    end

    -- Checkbox at the current row (call Row() after the last one on the row)
    local function Check(x, text, dbKey, invert, onChange)
        return MakeCheckbox(pg, x, y, text, dbKey, invert, onChange)
    end
    local function Row()
        y = y - 24
    end

    -- Slider at the current row, then move the cursor past it
    local function Slider(label, minValue, maxValue, step, dbKey, valueText, round, onChange)
        MakeSlider(pg, y, label, minValue, maxValue, step, dbKey, valueText, round, onChange)
        y = y - 50
    end

    -- Small gray help text at the current row, then move the cursor past it
    local function Note(text)
        local fs = MakeText(pg, "GameFontDisableSmall", "TOPLEFT", 12, y, text, CW - 8, "LEFT")
        local h = fs:GetHeight() or 0
        local guess = math.ceil(string.len(text) / 58) * 12
        if guess > h then
            h = guess
        end
        y = y - h - 8
        return fs
    end

    -- Side tabs: spellbook-style icon tabs down the right edge of the window
    local tabs = {}
    local function SelectTab(index)
        for i, tab in ipairs(tabs) do
            tab:SetChecked(i == index and 1 or nil)
        end
        for i, page in ipairs(pages) do
            if i == index then
                page:Show()
            else
                page:Hide()
            end
        end
        ui.currentTab = index
        sc:SetHeight(pages[index].contentHeight or 10)
        settingsContent:SetVerticalScroll(0)
        UpdateScrollBar()
        if index == 3 then
            ui.RefreshSetsTab()
        end
    end

    local tabInfo = {
        {name = "General", icon = "Interface\\Icons\\INV_Misc_Gear_01"},
        {name = "Totem Bar", icon = "Interface\\Icons\\Spell_Fire_SearingTotem"},
        {name = "Totem Sets", icon = "Interface\\Icons\\Spell_Nature_StoneSkinTotem"},
        {name = "Alerts", icon = "Interface\\Icons\\Ability_Warrior_BattleShout"}
    }
    for i, info in ipairs(tabInfo) do
        local tab = CreateFrame("CheckButton", nil, optionsMenu)
        tab:SetWidth(32)
        tab:SetHeight(32)
        tab:SetPoint("TOPLEFT", optionsMenu, "TOPLEFT", W - 4, -48 - (i - 1) * 48)
        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
        bg:SetWidth(64)
        bg:SetHeight(64)
        bg:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)
        tab:SetNormalTexture(info.icon)
        tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        local hl = tab:GetHighlightTexture()
        if hl then
            hl:SetBlendMode("ADD")
        end
        tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
        local ck = tab.GetCheckedTexture and tab:GetCheckedTexture()
        if ck then
            ck:SetBlendMode("ADD")
        end
        tab.index = i
        Tooltip(tab, info.name)
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
    Check(COL_L, "Lock notification", "isLocked", false, function(locked)
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
    Check(COL_R, "Hide notification", "hideUIElement")
    Row()
    y = y - 4
    Slider("Display Duration", 15, 60, 1, "timerDuration", Seconds, RoundWhole)
    Slider("Scale", 0.5, 2.0, 0.1, "uiFrameScale", Plain, RoundTenth,
        function(v) iconFrame:SetScale(v) end)

    Header("Totem Tracker")
    Check(COL_L, "Lock totem tracker", "totemTrackerLocked", false, function(locked)
        totemTracker:EnableMouse(not locked)
    end)
    Check(COL_R, "Hide totem tracker", "totemTrackerHidden", false, function()
        TotemNesia.UpdateTotemTracker()
    end)
    Row()
    y = y - 4
    Slider("Scale", 0.5, 2.0, 0.1, "totemTrackerScale", Plain, RoundTenth,
        function(v) totemTracker:SetScale(v) end)

    Header("Totem Range")
    Slider("Totem Range", 10, 40, 1, "totemRange", Yards, RoundWhole)
    Note("The recall reminder shows when you move farther than this from your totems. With SuperWoW, totem icons also turn red when you are out of a totem's range (Searing Totem 20 yds, Magma Totem 8 yds).")

    Header("Enabled When In")
    Check(COL_L, "Solo", "enabledSolo")
    Check(115, "Parties", "enabledParty")
    Check(222, "Raids", "enabledRaid")
    Row()

    Header("Appearance and Debug")
    Check(COL_L, "Match pfUI style on the bars", "pfuiSkinBars")
    Row()
    Note("When pfUI is installed, the totem bar, flyouts, totem tracker, and recall notification take pfUI's look. Takes effect after a /reload.")
    Check(COL_L, "Debug mode", "debugMode")
    Row()
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
    Row()
    Check(COL_L, "Disable shift for flyouts", "shiftToOpenFlyouts")
    Row()

    Header("Slots")
    Check(COL_L, "Hide weapon slot", "hideWeaponSlot", false, function()
        TotemNesia.UpdateTotemBar()
    end)
    Check(COL_R, "Hide shield slot", "hideShieldSlot", false, function()
        TotemNesia.UpdateTotemBar()
    end)
    Row()
    Check(COL_L, "Flash when shield is low", "shieldFlash")
    Row()

    Header("Layout")
    MakeText(pg, "GameFontNormalSmall", "TOPLEFT", 12, y, "Orientation")
    MakeText(pg, "GameFontNormalSmall", "TOPLEFT", COL_R + 4, y, "Flyout Direction")
    local layoutButton = CreateFrame("Button", NewName("Btn"), pg, "UIPanelButtonTemplate")
    layoutButton:SetWidth(140)
    layoutButton:SetHeight(22)
    layoutButton:SetPoint("TOPLEFT", pg, "TOPLEFT", 10, y - 14)
    layoutButton:SetText("Horizontal")

    local flyoutButton = CreateFrame("Button", NewName("Btn"), pg, "UIPanelButtonTemplate")
    flyoutButton:SetWidth(140)
    flyoutButton:SetHeight(22)
    flyoutButton:SetPoint("TOPLEFT", pg, "TOPLEFT", COL_R + 2, y - 14)
    flyoutButton:SetText("Up")

    layoutButton:SetScript("OnClick", function()
        if TotemNesiaCharDB.totemBarLayout == "Horizontal" then
            -- Vertical layout defaults its flyouts to the right
            TotemNesiaCharDB.totemBarLayout = "Vertical"
            TotemNesiaCharDB.totemBarFlyoutDirection = "Right"
        else
            -- Horizontal layout defaults its flyouts upward
            TotemNesiaCharDB.totemBarLayout = "Horizontal"
            TotemNesiaCharDB.totemBarFlyoutDirection = "Up"
        end
        this:SetText(TotemNesiaCharDB.totemBarLayout)
        flyoutButton:SetText(TotemNesiaCharDB.totemBarFlyoutDirection)
        TotemNesia.DebugPrint("Layout changed to " .. TotemNesiaCharDB.totemBarLayout .. ", flyout direction set to " .. TotemNesiaCharDB.totemBarFlyoutDirection)
        TotemNesia.UpdateTotemBar()
        TotemNesia.UpdateTotemBarFlyouts()
    end)

    flyoutButton:SetScript("OnClick", function()
        local direction = TotemNesiaCharDB.totemBarFlyoutDirection
        if TotemNesiaCharDB.totemBarLayout == "Vertical" then
            -- Vertical layout: cycle between Left and Right
            if direction == "Left" then direction = "Right" else direction = "Left" end
        else
            -- Horizontal layout: cycle between Up and Down
            if direction == "Up" then direction = "Down" else direction = "Up" end
        end
        TotemNesiaCharDB.totemBarFlyoutDirection = direction
        this:SetText(direction)
        TotemNesia.UpdateTotemBarFlyouts()
    end)
    ui.layoutButton = layoutButton
    ui.flyoutButton = flyoutButton
    y = y - 44
    Slider("Scale", 0.5, 2.0, 0.1, "totemBarScale", Plain, RoundTenth,
        function(v) totemBar:SetScale(v) end)

    Header("Key Bindings")
    local bindButton = CreateFrame("Button", NewName("Btn"), pg, "UIPanelButtonTemplate")
    bindButton:SetWidth(160)
    bindButton:SetHeight(22)
    bindButton:SetPoint("TOPLEFT", pg, "TOPLEFT", 10, y)
    bindButton:SetText("Key Bind Mode")
    bindButton:SetScript("OnClick", function()
        optionsMenu:Hide()  -- get the window out of the way of the totem bar
        TotemNesia.ToggleBindMode()
    end)
    y = y - 30
    Note("Hover a totem bar slot and press a key to bind it. Esc over a slot clears its key. Press Esc anywhere else to finish.")
    Note("Totem Sets, the Totem Bar slots, and Recast Shield can also be bound in ESC > Key Bindings > TotemNesia.")
    Note("To recall totems with a key, put this in a macro (click to select, then Ctrl-C):")
    local RECALL_MACRO = "/script TotemNesia_RecallTotems()"
    local macroBox = CreateFrame("EditBox", nil, pg)
    macroBox:SetPoint("TOPLEFT", pg, "TOPLEFT", 12, y)
    macroBox:SetWidth(CW - 12)
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
    y = y - 26

    Header("How to Use")
    Note("Hold Shift and mouse over a slot to open its flyout (unless shift is disabled above).")
    Note("Shift-click a flyout totem to cast it. Shift-right-click a flyout totem or weapon enchant to put it in the slot.")
    Note("Alt-click a flyout totem to make it the slot's fallback, cast when the slot totem is on cooldown. Alt-click it again to clear.")
    Note("Right-click the water slot to cycle Anti-Poison (P), Anti-Disease (D), and off. Right-click the earth slot to toggle Tremor mode (T). Assigning a totem to the slot turns its mode off.")
    Note("Click the shield slot, or use the Recast Shield keybind, to recast your shield.")
    Note("A red icon means you're out of that totem's range. A blue icon means you don't have the mana to cast it.")
    EndPage()

    -- ==================================================================
    -- Tab 3: Totem Sets
    -- ==================================================================
    local setsPage = NewPage()
    Note("Pick a set, then click a totem in each row to assign it. A gold border marks the assigned totem. Each set has its own keybind in ESC > Key Bindings > TotemNesia.")

    Header("Set")
    local setButtons = {}
    for i = 1, 5 do
        local btn = CreateFrame("Button", NewName("Btn"), setsPage, "UIPanelButtonTemplate")
        btn:SetWidth(44)
        btn:SetHeight(22)
        btn:SetPoint("TOPLEFT", setsPage, "TOPLEFT", 10 + (i - 1) * 52, y)
        btn:SetText(tostring(i))
        btn.setNumber = i
        btn:SetScript("OnClick", function()
            TotemNesiaCharDB.currentTotemSet = this.setNumber
            TotemNesia.DebugPrint("Selected Set " .. this.setNumber)
            ui.RefreshSetsTab()
        end)
        setButtons[i] = btn
    end
    setButtons[1]:LockHighlight()
    y = y - 30

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
        if not TotemNesiaCharDB or not TotemNesiaCharDB.totemSets then
            return
        end
        local set = TotemNesiaCharDB.totemSets[TotemNesiaCharDB.currentTotemSet or 1]
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
        local current = (TotemNesiaCharDB and TotemNesiaCharDB.currentTotemSet) or 1
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
        local label = MakeText(setsPage, "GameFontNormal", "TOPLEFT", 12, y - 8, row.title)
        label:SetTextColor(row.color[1], row.color[2], row.color[3])

        -- Clear button
        local clearBtn = CreateFrame("Button", nil, setsPage)
        clearBtn:SetWidth(22)
        clearBtn:SetHeight(22)
        clearBtn:SetPoint("TOPLEFT", setsPage, "TOPLEFT", 58, y - 3)
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
            local set = TotemNesiaCharDB.currentTotemSet
            TotemNesiaCharDB.totemSets[set][this.element] = nil
            TotemNesia.DebugPrint("Cleared Set " .. set .. " " .. this.title .. " totem")
            UpdateSetBorders(this.element)
        end)

        -- Totem buttons
        for j, totemName in ipairs(row.totems) do
            local btn = CreateFrame("Button", nil, setsPage)
            btn:SetWidth(28)
            btn:SetHeight(28)
            btn:SetPoint("TOPLEFT", setsPage, "TOPLEFT", 86 + (j - 1) * 32, y)
            btn:SetBackdrop(BUTTON_BACKDROP)
            btn:SetBackdropColor(row.color[1], row.color[2], row.color[3], 0.6)
            btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(btn)
            icon:SetTexture(TotemNesia.GetTotemIcon(totemName))
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
                local set = TotemNesiaCharDB.currentTotemSet
                TotemNesiaCharDB.totemSets[set][this.element] = this.totemName
                TotemNesia.DebugPrint("Set " .. set .. " " .. this.title .. " = " .. this.totemName)
                UpdateSetBorders(this.element)
            end)
            table.insert(setTotemButtons[element], btn)
        end
        y = y - 36
    end

    Header("How Sets Cast")
    Note("With Nampower, one press drops every totem in the set. Without Nampower, each press drops the next totem (Fire, Earth, Water, Air).")
    Note("Totems that are already down with more than 10 seconds left, and that you're still in range of, are skipped. So pressing again only replaces what's missing, expiring, or left behind.")
    EndPage()

    -- ==================================================================
    -- Tab 4: Alerts
    -- ==================================================================
    NewPage()

    Header("Audio Alerts")
    MakeText(pg, "GameFontNormalSmall", "TOPLEFT", 12, y - 8, "Voice")
    local voiceDropDown = CreateFrame("Frame", "TotemNesiaVoiceDropDown", pg, "UIDropDownMenuTemplate")
    voiceDropDown:SetPoint("TOPLEFT", pg, "TOPLEFT", 30, y)
    UIDropDownMenu_SetWidth(110, voiceDropDown)
    UIDropDownMenu_Initialize(voiceDropDown, function()
        for _, name in ipairs(TNC.VOICES) do
            local info = {}
            info.text = name
            info.value = name
            info.checked = (TotemNesiaCharDB and TotemNesiaCharDB.alertVoice == name)
            info.func = function()
                TotemNesiaCharDB.alertVoice = this.value
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
    Tooltip(voiceTest, "Test voice", "Plays the Totems alert in the chosen voice")
    y = y - 34
    -- Checked = the sound plays. The mute settings are stored inverted, so these boxes flip them.
    Check(COL_L, "Recall alert sound", "audioEnabled")
    Check(COL_R, "Low mana alert sound", "manaAudioMuted", true)
    Row()
    Check(COL_L, "Potion alert sound", "potionAudioMuted", true)
    Check(COL_R, "Aggro alert sound", "aggroAudioMuted", true)
    Row()

    Header("Mana Alerts")
    Slider("Low Mana Threshold", 0, 100, 5, "manaThreshold", Percent, RoundFive)
    Slider("Potion Threshold", 0, 100, 5, "potionThreshold", Percent, RoundFive)
    Note("An alert plays when your mana drops below a threshold. Each alert has a 30 second cooldown and only fires when you cross below the line. Set a slider to 0% to turn that alert off.")

    Header("Aggro Alert")
    Check(COL_L, "Aggro alert", "aggroAlert")
    Row()
    Note("\"You have aggro!\" on screen plus the Aggro voice when a mob stays on you for a second, in a group and in combat. Checks your group's targets, and with SuperWoW every visible nameplate (turn on enemy nameplates with V).")

    Header("Group Announcements")
    Check(COL_L, "Announce in parties", "publicManaParty")
    Check(COL_R, "Announce in raids", "publicManaRaid")
    Row()
    Check(COL_L, "Announce low mana", "manaAnnounce")
    Check(COL_R, "Announce aggro", "aggroAnnounce")
    Row()
    Check(COL_L, "Announce line of sight", "losAnnounce")
    Row()
    y = y - 4
    Slider("Low Mana Announcement", 0, 100, 5, "publicManaThreshold", Percent, RoundFive)
    Note("Posted to party or raid chat, never /say, and never when solo. Low mana: \"I am low on mana, I need to drink.\" Aggro: \"I have aggro!\" (at most every 20s). Line of sight: \"<Name>, you are out of LoS for healing.\" (at most every 20s per player).")
    EndPage()

    -- ------------------------------------------------------------------
    -- Refresh every control from the saved settings (runs when the window opens)
    -- ------------------------------------------------------------------
    function ui.RefreshAll()
        for _, cb in ipairs(checkboxes) do
            local value = TotemNesiaCharDB[cb.dbKey]
            if cb.invert then
                value = not value
            end
            cb:SetChecked(value and 1 or nil)
        end
        for _, slider in ipairs(sliders) do
            local value = TotemNesiaCharDB[slider.dbKey]
            if value then
                slider.loading = true
                slider:SetValue(value)
                slider:ShowValue(value)
                slider.loading = nil
            end
        end
        layoutButton:SetText(TotemNesiaCharDB.totemBarLayout or "Horizontal")
        flyoutButton:SetText(TotemNesiaCharDB.totemBarFlyoutDirection or "Up")
        UIDropDownMenu_SetText(TotemNesiaCharDB.alertVoice or "Jenny", voiceDropDown)
        SelectTab(ui.currentTab or 1)
    end
end

TNC.BuildOptionsUI()

-- Update minimap button position
function TotemNesia.UpdateMinimapButton()
    local angle = math.rad(TotemNesiaCharDB.minimapPos or 180)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)

    -- Ensure button is visible unless explicitly hidden
    if not TotemNesiaCharDB.minimapHidden then
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

-- Open or close the options window (every control is refreshed from saved settings first)
function TotemNesia.ToggleOptions()
    if optionsMenu:IsVisible() then
        optionsMenu:Hide()
    else
        optionsMenu:SetScale(TotemNesiaCharDB.optionsScale or 1)
        optionsMenu:Show()
        TNC.ui.RefreshAll()
    end
end

-- Click to open options menu
minimapButton:SetScript("OnClick", function()
    TotemNesia.ToggleOptions()
end)

-- Slash commands: /tn or /totemnesia opens the settings, /tn bind starts Key Bind Mode
SLASH_TOTEMNESIA1 = "/tn"
SLASH_TOTEMNESIA2 = "/totemnesia"
SlashCmdList["TOTEMNESIA"] = function(msg)
    local command = string.lower(msg or "")
    if command == "bind" then
        if optionsMenu:IsVisible() then
            optionsMenu:Hide()
        end
        TotemNesia.ToggleBindMode()
    elseif command == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: /tn opens the settings, /tn bind starts Key Bind Mode")
    else
        TotemNesia.ToggleOptions()
    end
end

-- Dragging around minimap (right-click)
minimapButton:RegisterForDrag("RightButton")
minimapButton:SetScript("OnDragStart", function()
    this:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale

        local angle = math.deg(math.atan2(py - my, px - mx))
        TotemNesiaCharDB.minimapPos = angle
        TotemNesia.UpdateMinimapButton()
    end)
end)

minimapButton:SetScript("OnDragStop", function()
    this:SetScript("OnUpdate", nil)
end)

minimapButton:RegisterForClicks("LeftButtonUp")


-- Share with files loaded after this one
TotemNesia.shared.minimapButton = minimapButton
