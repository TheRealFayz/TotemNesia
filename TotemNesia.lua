-- TotemNesia: Automatically recalls totems after leaving combat
-- For Turtle WoW (1.12)

TotemNesia = {}
TotemNesia.displayTimer = nil
TotemNesia.inCombat = false
TotemNesia.hasTotems = false

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
end

-- Create the message frame
local messageFrame = CreateFrame("Button", "TotemNesiaMessageFrame", UIParent)
messageFrame:SetWidth(300)
messageFrame:SetHeight(80)
messageFrame:SetPoint("CENTER", 0, 200)
messageFrame:SetMovable(true)
messageFrame:SetUserPlaced(true)
messageFrame:EnableMouse(true)
messageFrame:RegisterForClicks("LeftButtonUp")
messageFrame:SetFrameStrata("HIGH")
messageFrame:Hide()

messageFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
messageFrame:SetBackdropColor(0, 0, 0, 0.75)
messageFrame:SetBackdropBorderColor(1, 1, 1, 1)

-- Create the text
local messageText = messageFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
messageText:SetPoint("CENTER", messageFrame, "CENTER", 0, 10)
messageText:SetFont("Fonts\\FRIZQT__.TTF", 30, "OUTLINE")
messageText:SetText("Click to recall totems")
messageText:SetTextColor(1, 0.82, 0)

-- Create the timer text
local timerText = messageFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
timerText:SetPoint("CENTER", messageFrame, "CENTER", 0, -15)
timerText:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
timerText:SetText("")
timerText:SetTextColor(1, 1, 1)

-- Make frame draggable
messageFrame:RegisterForDrag("LeftButton")
messageFrame:SetScript("OnDragStart", function()
    if not TotemNesiaDB.isLocked then
        this:StartMoving()
    end
end)
messageFrame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
end)

-- Make frame clickable to recall totems
messageFrame:SetScript("OnClick", function()
    TotemNesia.DebugPrint("Frame clicked")
    
    if TotemNesiaDB.isLocked and messageFrame:IsVisible() then
        local i = 1
        while true do
            local spellName = GetSpellName(i, BOOKTYPE_SPELL)
            if not spellName then
                break
            end
            if spellName == "Totemic Recall" then
                CastSpell(i, BOOKTYPE_SPELL)
                messageFrame:Hide()
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
combatFrame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
combatFrame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_SPELL_SELF_BUFF" then
        if string.find(arg1, "Totem") and not string.find(arg1, "Totemic Recall") then
            if not string.find(arg1, "Fire Nova Totem") then
                TotemNesia.hasTotems = true
                TotemNesia.DebugPrint("Totem summoned: " .. arg1)
            else
                TotemNesia.DebugPrint("Fire Nova Totem ignored (self-destructs)")
            end
        end
        
        if string.find(arg1, "Totemic Recall") then
            TotemNesia.hasTotems = false
            messageFrame:Hide()
            TotemNesia.displayTimer = nil
            timerText:SetText("")
            TotemNesia.DebugPrint("Manual Totemic Recall detected - flag reset")
        end
    elseif event == "CHAT_MSG_SPELL_AURA_GONE_SELF" then
        if string.find(arg1, "Totemic Recall") then
            TotemNesia.hasTotems = false
            TotemNesia.DebugPrint("Totemic Recall faded - totems gone")
        end
    end
end)

-- Function to toggle lock state
function TotemNesia.ToggleLock()
    TotemNesiaDB.isLocked = not TotemNesiaDB.isLocked
    
    if TotemNesiaDB.isLocked then
        messageFrame:SetBackdropColor(0, 0, 0, 0.75)
        messageFrame:RegisterForClicks("LeftButtonUp")
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Frame locked.")
    else
        messageFrame:SetBackdropColor(0, 0, 0, 1)
        messageFrame:RegisterForClicks()
        messageFrame:Show()
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Frame unlocked. Drag to reposition.")
    end
end

-- Function to reset frame position
function TotemNesia.ResetPosition()
    messageFrame:ClearAllPoints()
    messageFrame:SetPoint("CENTER", 0, 200)
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
        
    elseif event == "PLAYER_REGEN_DISABLED" then
        TotemNesia.inCombat = true
        TotemNesia.displayTimer = nil
        messageFrame:Hide()
        timerText:SetText("")
        TotemNesia.DebugPrint("Entered combat")
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        TotemNesia.inCombat = false
        TotemNesia.DebugPrint("Left combat - hasTotems: " .. tostring(TotemNesia.hasTotems))
        
        if IsShaman() and HasTotemsOut() then
            TotemNesia.displayTimer = 15
            messageFrame:Show()
            messageFrame:SetAlpha(1)
            messageFrame:RegisterForClicks("LeftButtonUp")
            
            if TotemNesiaDB.audioEnabled then
                PlaySoundFile("Interface\\AddOns\\TotemNesia\\Sounds\\notification.mp3")
            end
            
            TotemNesia.DebugPrint("Showing recall message")
        else
            TotemNesia.hasTotems = false
            TotemNesia.DebugPrint("No totems detected")
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
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
        timerText:SetText(secondsLeft .. "s")
        
        if TotemNesia.displayTimer <= 0 then
            messageFrame:Hide()
            TotemNesia.displayTimer = nil
            timerText:SetText("")
            TotemNesia.DebugPrint("Timer expired - totems still may be active")
        end
    end
end)

-- Slash commands
SLASH_TOTEMNESIA1 = "/tn"
SlashCmdList["TOTEMNESIA"] = function(msg)
    local lowerMsg = string.lower(msg)
    
    if lowerMsg == "lock" then
        if not TotemNesiaDB.isLocked then
            TotemNesia.ToggleLock()
        else
            DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Frame is already locked.")
        end
        
    elseif lowerMsg == "unlock" then
        if TotemNesiaDB.isLocked then
            TotemNesia.ToggleLock()
        else
            DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Frame is already unlocked.")
        end
        
    elseif lowerMsg == "mute" then
        if TotemNesiaDB.audioEnabled then
            TotemNesiaDB.audioEnabled = false
            DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Audio notifications muted")
        else
            DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Audio is already muted.")
        end
        
    elseif lowerMsg == "unmute" then
        if not TotemNesiaDB.audioEnabled then
            TotemNesiaDB.audioEnabled = true
            DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Audio notifications unmuted")
            PlaySoundFile("Interface\\AddOns\\TotemNesia\\Sounds\\notification.mp3")
        else
            DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Audio is already unmuted.")
        end
        
    elseif lowerMsg == "reset" then
        TotemNesia.ResetPosition()
        
    elseif lowerMsg == "test" then
        TotemNesia.displayTimer = 15
        messageFrame:Show()
        messageFrame:SetAlpha(1)
        messageFrame:RegisterForClicks("LeftButtonUp")
        
    elseif lowerMsg == "debug" then
        TotemNesiaDB.debugMode = not TotemNesiaDB.debugMode
        if TotemNesiaDB.debugMode then
            DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Debug mode ON")
        else
            DEFAULT_CHAT_FRAME:AddMessage("TotemNesia: Debug mode OFF")
        end
        
    else
        local lockStatus = TotemNesiaDB.isLocked and "|cffff0000Locked|r" or "|cff00ff00Unlocked|r"
        local audioStatus = TotemNesiaDB.audioEnabled and "|cff00ff00Unmuted|r" or "|cffff0000Muted|r"
        local debugStatus = TotemNesiaDB.debugMode and "|cff00ff00On|r" or "|cffff0000Off|r"
        
        DEFAULT_CHAT_FRAME:AddMessage("TotemNesia Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00The message frame is currently|r " .. lockStatus)
        DEFAULT_CHAT_FRAME:AddMessage("/tn lock - Lock message frame")
        DEFAULT_CHAT_FRAME:AddMessage("/tn unlock - Unlock message frame for positioning")
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00The audio queue is currently|r " .. audioStatus)
        DEFAULT_CHAT_FRAME:AddMessage("/tn mute - Mute the audio queue")
        DEFAULT_CHAT_FRAME:AddMessage("/tn unmute - Unmute the audio queue")
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00The debug mode is currently|r " .. debugStatus)
        DEFAULT_CHAT_FRAME:AddMessage("/tn debug - Toggle debug messages")
        DEFAULT_CHAT_FRAME:AddMessage("/tn test - Test the recall function")
        DEFAULT_CHAT_FRAME:AddMessage("/tn reset - Reset the frame position to center")
    end
end

DEFAULT_CHAT_FRAME:AddMessage("TotemNesia loaded. Type /tn for commands.")
