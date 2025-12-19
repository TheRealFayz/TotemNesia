-- TotemNesia.lua
-- TotemNesia: Because Shamans always forget their totems
-- Reminds Shamans to destroy totems after combat

local frame = CreateFrame("Frame", "TotemNesiaFrame", UIParent)
local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local wasInCombat = false
local reminderShown = false

-- Configure the warning text
text:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
text:SetFont("Fonts\\FRIZQT__.TTF", 30, "OUTLINE")
text:SetTextColor(0, 0.5, 1) -- Blue color
text:SetText("PICK UP YOUR TOTEMS!")
text:Hide()

-- Function to check if player has active totems
local function HasActiveTotems()
    for i = 1, 4 do
        local haveTotem, totemName = GetTotemInfo(i)
        if haveTotem and totemName ~= "" then
            return true
        end
    end
    return false
end

-- Main event handler
frame:SetScript("OnEvent", function()
    if event == "PLAYER_REGEN_DISABLED" then
        -- Entered combat
        wasInCombat = true
        reminderShown = false
        text:Hide()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Left combat
        if wasInCombat and HasActiveTotems() then
            -- Automatically destroy all totems
            DestroyTotem(1) -- Fire totem
            DestroyTotem(2) -- Earth totem
            DestroyTotem(3) -- Water totem
            DestroyTotem(4) -- Air totem
            
            -- Show confirmation message
            text:SetText("TOTEMS DESTROYED!")
            text:Show()
            reminderShown = true
            -- Auto-hide after 2 seconds
            frame.hideTimer = 2
        end
    elseif event == "PLAYER_TOTEM_UPDATE" then
        -- Check if all totems are gone
        if not HasActiveTotems() then
            text:Hide()
            reminderShown = false
        end
    end
end)

-- OnUpdate for the timer
frame:SetScript("OnUpdate", function()
    if frame.hideTimer then
        frame.hideTimer = frame.hideTimer - arg1
        if frame.hideTimer <= 0 then
            text:Hide()
            frame.hideTimer = nil
        end
    end
end)

-- Register events
frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entering combat
frame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Leaving combat
frame:RegisterEvent("PLAYER_TOTEM_UPDATE")   -- Totem changes

DEFAULT_CHAT_FRAME:AddMessage("TotemNesia loaded! Your totems will be auto-destroyed after combat.")
