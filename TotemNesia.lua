-- TotemNesia: Automatically recalls totems after leaving combat
-- For Turtle WoW (1.12)

TotemNesia = {}
TotemNesia.displayTimer = nil
TotemNesia.inCombat = false
TotemNesia.isLocked = true
TotemNesia.hasTotems = false
TotemNesia.debugMode = false

-- Create the message frame
local messageFrame = CreateFrame("Button", "TotemNesiaMessageFrame", UIParent)
messageFrame:SetWidth(300)
messageFrame:SetHeight(50)
messageFrame:SetPoint("CENTER", 0, 200)
messageFrame:SetMovable(true)
messageFrame:SetUserPlaced(true)
messageFrame:EnableMouse(true)
messageFrame:RegisterForClicks("LeftButtonUp")
messageFrame:SetFrameStrata("HIGH")
messageFrame:Hide()

-- Set up backdrop
messageFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
messageFrame:SetBackdropColor(0, 0, 0, 0.25)

-- Create the text
local messageText = messageFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
messageText:SetPoint("CENTER", messageFrame, "CENTER", 0, 0)
messageText:SetFont("Fonts\\FRIZQT__.TTF", 30, "OUTLINE")
messageText:SetText("Click to recall totems")
messageText:SetTextColor(1, 0.82, 0)

-- Make frame draggable and clickable
messageFrame:RegisterForDrag("LeftButton")
messageFrame:SetScript("OnDragStart", function()
    if not TotemNesia.isLocked then
        this:StartMoving()
    end
end)
messageFrame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
end)

-- Make frame clickable to recall totems
messageFrame:SetScript("OnClick", function()
    TotemNesia.DebugPrint("Frame clicked!")
    TotemNesia.DebugPrint("isLocked = " .. tostring(TotemNesia.isLocked))
    TotemNesia.DebugPrint("isVisible = " .. tostring(messageFrame:IsVisible()))
    
    if TotemNesia.isLocked and messageFrame:IsVisible() then
        TotemNesia.DebugPrint("Searching for spell...")
        -- Cast Totemic Recall
        local i = 1
        while true do
            local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
            if not spellName then
                TotemNesia.DebugPrint("Reached end of spellbook")
                break
            end
            if spellName == "Totemic Recall" then
                TotemNesia.DebugPrint("Found spell at index " .. i .. ", casting...")
                CastSpell(i, BOOKTYPE_SPELL)
                messageFrame:Hide()
                TotemNesia.displayTimer = nil
                TotemNesia.hasTotems = false  -- Reset totem flag after recalling
                TotemNesia.DebugPrint("Totem flag reset to: " .. tostring(TotemNesia.hasTotems))
                DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Totems recalled!")
                break
            end
            i = i + 1
        end
    else
        TotemNesia.DebugPrint("Conditions not met for casting")
    end
end)

-- Function to toggle lock state
function TotemNesia.ToggleLock()
    TotemNesia.isLocked = not TotemNesia.isLocked
    
    if TotemNesia.isLocked then
        -- Locked state: 25% transparency
        messageFrame:SetBackdropColor(0, 0, 0, 0.25)
        messageFrame:RegisterForClicks("LeftButtonUp")
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Frame locked.")
    else
        -- Unlocked state: no transparency
        messageFrame:SetBackdropColor(0, 0, 0, 1)
        messageFrame:RegisterForClicks()
        messageFrame:Show() -- Show frame so it can be positioned
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Frame unlocked. Drag to reposition.")
    end
end

-- Debug print function
function TotemNesia.DebugPrint(msg)
    if TotemNesia.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia DEBUG: " .. msg)
    end
end

-- Function to check if player is a shaman
local function IsShaman()
    local _, class = UnitClass("player")
    return class == "SHAMAN"
end

-- Function to check if player has totems out
local function HasTotemsOut()
    return TotemNesia.hasTotems
end

-- Combat log parser to track totem summons and deaths
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
combatFrame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE")
combatFrame:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE")
combatFrame:RegisterEvent("CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF")
combatFrame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_SPELL_SELF_BUFF" then
        -- Check if message contains "Totem" but NOT "Totemic Recall"
        if string.find(arg1, "Totem") and not string.find(arg1, "Totemic Recall") then
            TotemNesia.hasTotems = true
            TotemNesia.DebugPrint("Totem summoned - flag set to true")
        end
    elseif event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE" or 
           event == "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE" or
           event == "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF" then
        -- Check if a totem died
        if string.find(arg1, "Totem") and (string.find(arg1, "dies") or string.find(arg1, "is destroyed")) then
            TotemNesia.DebugPrint("Totem destroyed message detected")
        end
    end
end)

-- Function to recall totems
local function RecallTotems()
    DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Recalling totems...")
    
    -- Find and cast Totemic Recall
    local i = 1
    while true do
        local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Spell not found in spellbook")
            break
        end
        if spellName == "Totemic Recall" then
            DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Found spell, casting...")
            CastSpell(i, BOOKTYPE_SPELL)
            break
        end
        i = i + 1
    end
    
    -- Show message
    messageFrame:Show()
    messageFrame:SetAlpha(1)
    
    -- Fade out animation
    local fadeTime = 0
    messageFrame:SetScript("OnUpdate", function()
        fadeTime = fadeTime + arg1
        if fadeTime >= 1.5 then
            local alpha = 1 - ((fadeTime - 1.5) / 1.5)
            if alpha <= 0 then
                if TotemNesia.isLocked then
                    messageFrame:Hide()
                end
                messageFrame:SetScript("OnUpdate", nil)
            else
                messageFrame:SetAlpha(alpha)
            end
        end
    end)
end

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function()
    if event == "PLAYER_REGEN_DISABLED" then
        -- Entered combat - hide message and reset timer
        TotemNesia.inCombat = true
        TotemNesia.displayTimer = nil
        messageFrame:Hide()
        TotemNesia.DebugPrint("Entered combat, hiding message")
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Left combat
        TotemNesia.inCombat = false
        TotemNesia.DebugPrint("Left combat - hasTotems flag is: " .. tostring(TotemNesia.hasTotems))
        if IsShaman() and HasTotemsOut() then
            -- Only show if totems are out
            TotemNesia.displayTimer = 15
            messageFrame:Show()
            messageFrame:SetAlpha(1)
            messageFrame:RegisterForClicks("LeftButtonUp")
            TotemNesia.DebugPrint("Totems detected, showing recall message")
        else
            TotemNesia.DebugPrint("No totems detected, resetting flag")
            -- Reset totem flag when leaving combat with no totems
            TotemNesia.hasTotems = false
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Check if player is shaman
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
        if TotemNesia.displayTimer <= 0 then
            messageFrame:Hide()
            TotemNesia.displayTimer = nil
        end
    end
end)

-- Slash commands
SLASH_TOTEMNESIA1 = "/tn"
SlashCmdList["TOTEMNESIA"] = function(msg)
    if msg == "lock" then
        if not TotemNesia.isLocked then
            TotemNesia.ToggleLock()
        else
            DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Frame is already locked.")
        end
    elseif msg == "unlock" then
        if TotemNesia.isLocked then
            TotemNesia.ToggleLock()
        else
            DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Frame is already unlocked.")
        end
    elseif msg == "test" then
        -- Show the clickable message
        TotemNesia.displayTimer = 15
        messageFrame:Show()
        messageFrame:SetAlpha(1)
        messageFrame:RegisterForClicks("LeftButtonUp")
    elseif msg == "debug" then
        TotemNesia.debugMode = not TotemNesia.debugMode
        if TotemNesia.debugMode then
            DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Debug mode ON")
        else
            DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Debug mode OFF")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("/tn unlock - Unlock message frame for positioning")
        DEFAULT_CHAT_FRAME:AddMessage("/tn lock - Lock message frame")
        DEFAULT_CHAT_FRAME:AddMessage("/tn test - Test the recall function")
        DEFAULT_CHAT_FRAME:AddMessage("/tn debug - Toggle debug messages")
    end
end

DEFAULT_CHAT_FRAME:AddMessage("TotemNesia loaded. Type /tn for commands.")
