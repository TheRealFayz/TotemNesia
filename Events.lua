-- TotemNesia: Combat log tracking, game events, and the main timer
-- For Turtle WoW (1.12)

-- Core.lua stops loading on non-Shamans, so every other file stops too
if not TotemNesia or not TotemNesia.shared then
    return
end

-- Shared from files loaded earlier (see the TOC for load order)
local S = TotemNesia.shared
local DISTANCE_CHECK_INTERVAL = S.DISTANCE_CHECK_INTERVAL
local IsShaman = S.IsShaman
local IsValidTotem = S.IsValidTotem
local iconFrame = S.iconFrame
local minimapButton = S.minimapButton
local timerText = S.timerText
local totemBar = S.totemBar
local totemTracker = S.totemTracker

-- Combat log parser to track totem summons and recalls
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
combatFrame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE")
combatFrame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:RegisterEvent("PLAYER_DEAD")
combatFrame:SetScript("OnEvent", function()
    -- Check if addon is enabled for current group type
    if not TotemNesia.IsAddonEnabled() then
        return
    end
    
    if event == "CHAT_MSG_SPELL_SELF_BUFF" then
        -- Check for totem summons - validate it's actually a totem
        if string.find(arg1, "Totem") and not string.find(arg1, "Totemic Recall") then
            -- Try to extract totem name from message
            -- Could be "You cast X." or "You gain X." or just the totem name
            local rawName = arg1
            -- Clean up common prefixes
            rawName = string.gsub(rawName, "You cast ", "")
            rawName = string.gsub(rawName, "You gain ", "")
            rawName = string.gsub(rawName, "%.", "")
            
            -- Validate this is actually a totem we know about
            local isValid, totemName = IsValidTotem(rawName)
            
            if isValid then
                -- Special handling for Fire Nova Totem (self-destructs)
                if string.find(totemName, "Fire Nova Totem") then
                    TotemNesia.DebugPrint("Fire Nova Totem ignored (self-destructs)")
                    return
                end
                
                -- Record the totem (replaces any older totem of the same element)
                TotemNesia.RegisterTotem(totemName)
                
                -- Hide recall notification if showing - player replaced totems instead of recalling
                if iconFrame:IsVisible() then
                    iconFrame:Hide()
                    TotemNesia.displayTimer = nil
                    timerText:SetText("")
                    TotemNesia.monitoringForRecall = false
                    TotemNesia.monitorTimer = 0
                    TotemNesia.DebugPrint("Recall notification cleared - new totems placed")
                end
                
                TotemNesia.DebugPrint("Totem summoned: " .. totemName)
            else
                -- Not a valid totem - ignore it
                TotemNesia.DebugPrint("Ignored non-totem buff with 'Totem' in name: " .. rawName)
            end
        end
        
        if string.find(arg1, "Totemic Recall") then
            -- Clear all active totems
            TotemNesia.ClearAllTotems()
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
            local rawName = string.gsub(arg1, "(.+) dies%.", "%1")
            -- Normalize (the unit name can carry a rank, e.g. "Searing Totem IV")
            local isValid, totemName = IsValidTotem(rawName)
            if not isValid then
                totemName = rawName
            end
            TotemNesia.RemoveTotem(totemName, "died")
        end
    elseif event == "CHAT_MSG_SPELL_AURA_GONE_SELF" then
        if string.find(arg1, "Totemic Recall") then
            TotemNesia.ClearAllTotems()
            TotemNesia.DebugPrint("Totemic Recall faded - totems gone")
        elseif string.find(arg1, "Totem") then
            -- Individual totem faded
            local rawName = string.gsub(arg1, "(.+) fades from you%.", "%1")
            local isValid, totemName = IsValidTotem(rawName)
            if not isValid then
                totemName = rawName
            end
            TotemNesia.RemoveTotem(totemName, "faded")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- When UI is hidden, monitor for manual Totemic Recall after combat
        if TotemNesiaDB.hideUIElement and TotemNesia.hasTotems then
            -- Start monitoring for Totemic Recall
            TotemNesia.monitoringForRecall = true
            TotemNesia.monitorTimer = 60  -- Monitor for 60 seconds after combat
            TotemNesia.DebugPrint("UI hidden mode - monitoring for manual Totemic Recall")
        end
    elseif event == "PLAYER_DEAD" then
        -- Player died - all totems despawn
        TotemNesia.ClearAllTotems()
        TotemNesia.monitoringForRecall = false
        TotemNesia.monitorTimer = 0
        iconFrame:Hide()
        TotemNesia.displayTimer = nil
        timerText:SetText("")
        TotemNesia.DebugPrint("Player died - all totems cleared")
    end
end)

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("SPELLS_CHANGED")  -- Fires when player learns new spells
eventFrame:RegisterEvent("CHAT_MSG_ADDON")  -- For version checking
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")  -- For broadcasting version on party join
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")  -- For broadcasting version on raid join
eventFrame:RegisterEvent("UPDATE_BINDINGS")  -- Fires when keybindings change
eventFrame:RegisterEvent("UNIT_MODEL_CHANGED")  -- SuperWoW: fires with the totem's unit ID when it appears
eventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")  -- Talent change (Totemic Mastery affects durations)

eventFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        TotemNesia.BuildSpellCache()
        TotemNesia.hasTotemicMasteryCached = nil
        TotemNesia.InitDB()
        TotemNesia.DetectNampower()
        TotemNesia.DetectSuperWoW()
        TotemNesia.UpdateMinimapButton()
        TotemNesia.UpdateTotemTracker()
        TotemNesia.UpdateTotemBar()
        TotemNesia.UpdateTotemBarKeybinds()  -- Update keybind displays
        
        -- Refresh flyout icons now that spellbook is loaded (also lays out the flyouts)
        TotemNesia.RefreshFlyoutIcons()
        
        -- Refresh totem set icons now that spellbook is loaded
        TotemNesia.RefreshTotemSetIcons()
        
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
        else
            minimapButton:Show()
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
        
        if IsShaman() and TotemNesia.hasTotems then
            -- Only show UI element if not hidden by setting AND player can use Totemic Recall
            if not TotemNesiaDB.hideUIElement and TotemNesia.CanUseTotemicRecall() then
                TotemNesia.displayTimer = TotemNesiaDB.timerDuration
                TotemNesia.UpdateElementalIndicators()
                iconFrame:Show()
                iconFrame:SetAlpha(1)
                iconFrame:RegisterForClicks("LeftButtonUp")
                TotemNesia.DebugPrint("Showing recall icon")
            else
                if not TotemNesia.CanUseTotemicRecall() then
                    TotemNesia.DebugPrint("Player cannot use Totemic Recall yet - skipping display")
                else
                    TotemNesia.DebugPrint("UI element hidden by setting - skipping display")
                end
            end
            
            -- Play audio only if player can use Totemic Recall
            if TotemNesiaDB.audioEnabled and TotemNesia.CanUseTotemicRecall() then
                TotemNesia.PlayAlertSound("Totems")
            end
        else
            TotemNesia.hasTotems = false
            TotemNesia.DebugPrint("No totems detected")
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Additional safety check (though we already return early if not Shaman)
        if not IsShaman() then
            this:UnregisterAllEvents()
        else
            -- Refresh flyout icons in case spellbook changed (new totems learned, respec, etc.)
            TotemNesia.BuildSpellCache()
            TotemNesia.hasTotemicMasteryCached = nil
            TotemNesia.RefreshFlyoutIcons()
        end
    
    elseif event == "SPELLS_CHANGED" then
        -- Spellbook changed (learned new spell, respec, etc.) - rebuild the cache, then refresh icons
        TotemNesia.BuildSpellCache()
        TotemNesia.RefreshFlyoutIcons()
        TotemNesia.RefreshTotemSetIcons()
    
    elseif event == "CHAT_MSG_ADDON" then
        -- Version checking via addon messages
        local prefix, message, distribution, sender = arg1, arg2, arg3, arg4
        if prefix == "TotemNesia" then
            local _, _, versionStr = string.find(message, "VER:(%d+)")
            if versionStr then
                TotemNesia.CheckRemoteVersion(versionStr)
            end
        end
    
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        -- Broadcast version when joining/leaving party/raid
        if GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 then
            TotemNesia.BroadcastVersion()
        end
    
    elseif event == "UPDATE_BINDINGS" then
        -- Update keybind displays when bindings change
        TotemNesia.UpdateTotemBarKeybinds()
    
    elseif event == "UNIT_MODEL_CHANGED" then
        -- SuperWoW: link a newly appeared totem to its unit ID
        if TotemNesia.hasSuperWoW and TotemNesia.OnTotemUnitSeen(arg1) then
            -- New totems placed instead of recalling: clear the recall notification
            if iconFrame:IsVisible() then
                iconFrame:Hide()
                TotemNesia.displayTimer = nil
                timerText:SetText("")
                TotemNesia.monitoringForRecall = false
                TotemNesia.monitorTimer = 0
            end
        end
    
    elseif event == "CHARACTER_POINTS_CHANGED" then
        -- Talents changed; check Totemic Mastery again next time a duration is needed
        TotemNesia.hasTotemicMasteryCached = nil
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
            -- Player is too far from totems - show UI only if they can use Totemic Recall
            if not iconFrame:IsVisible() and TotemNesia.CanUseTotemicRecall() then
                TotemNesia.UpdateElementalIndicators()
                iconFrame:Show()
                TotemNesia.displayTimer = TotemNesiaDB.timerDuration
                if TotemNesiaDB.audioEnabled then
                    TotemNesia.PlayAlertSound("Totems")
                end
                TotemNesia.DebugPrint("Too far from totems - UI shown")
            end
        end
    end
    
    -- Check mana once per second
    TotemNesia.manaCheckTimer = TotemNesia.manaCheckTimer + arg1
    if TotemNesia.manaCheckTimer >= 1.0 then
        TotemNesia.manaCheckTimer = 0
        TotemNesia.CheckManaAlerts()
    end
end)

DEFAULT_CHAT_FRAME:AddMessage("TotemNesia v" .. TotemNesia.GetVersion() .. " loaded. Click minimap button for options.")
