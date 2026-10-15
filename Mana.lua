-- TotemNesia: Mana alerts
-- For OctoWoW (1.12)

-- Core.lua stops loading on non-Shamans, so every other file stops too
if not TotemNesia or not TotemNesia.shared then
    return
end

-- Mana alerts: low mana sound, potion sound, and the public "need to drink" message.
-- Each fires once when mana crosses below its threshold, with a 30 second cooldown.
function TotemNesia.CheckManaAlerts()
    -- Count down cooldowns
    if TotemNesia.manaAlertCooldown > 0 then
        TotemNesia.manaAlertCooldown = TotemNesia.manaAlertCooldown - 1.0
    end
    if TotemNesia.potionAlertCooldown > 0 then
        TotemNesia.potionAlertCooldown = TotemNesia.potionAlertCooldown - 1.0
    end
    if TotemNesia.publicManaAlertCooldown > 0 then
        TotemNesia.publicManaAlertCooldown = TotemNesia.publicManaAlertCooldown - 1.0
    end
    
    local maxMana = UnitManaMax("player")
    if not maxMana or maxMana <= 0 then
        return
    end
    local manaPercent = (UnitMana("player") / maxMana) * 100
    
    -- Low mana alert (threshold from the Alerts tab, 0 turns it off)
    local manaThreshold = TotemNesiaDB.manaThreshold or 0
    if manaThreshold > 0 then
        if manaPercent < manaThreshold and not TotemNesia.belowThreshold then
            TotemNesia.belowThreshold = true
            if not TotemNesiaDB.manaAudioMuted and TotemNesia.manaAlertCooldown <= 0 then
                TotemNesia.PlayAlertSound("Low Mana")
                TotemNesia.manaAlertCooldown = 30
                TotemNesia.DebugPrint("Low mana alert played: " .. math.floor(manaPercent) .. "%")
            end
        elseif manaPercent >= manaThreshold and TotemNesia.belowThreshold then
            TotemNesia.belowThreshold = false
            TotemNesia.DebugPrint("Mana restored above threshold")
        end
    end
    
    -- Potion alert (threshold from the Alerts tab's Potion Threshold slider, 0 turns it off)
    local potionThreshold = TotemNesiaDB.potionThreshold or 0
    if potionThreshold > 0 then
        if manaPercent < potionThreshold and not TotemNesia.belowPotionThreshold then
            TotemNesia.belowPotionThreshold = true
            if not TotemNesiaDB.potionAudioMuted and TotemNesia.potionAlertCooldown <= 0 then
                TotemNesia.PlayAlertSound("Mana Potion")
                TotemNesia.potionAlertCooldown = 30
                TotemNesia.DebugPrint("Potion alert played: " .. math.floor(manaPercent) .. "%")
            end
        elseif manaPercent >= potionThreshold and TotemNesia.belowPotionThreshold then
            TotemNesia.belowPotionThreshold = false
            TotemNesia.DebugPrint("Mana restored above potion threshold")
        end
    end
    
    -- Public mana message: raid chat in a raid, party chat in a party, nothing when solo.
    -- Never /say. Party and raid can each be turned off. Threshold from the Alerts tab, 0 turns it off.
    local publicThreshold = TotemNesiaDB.publicManaThreshold or 15
    if publicThreshold > 0 then
        if manaPercent < publicThreshold and not TotemNesia.belowPublicManaThreshold then
            TotemNesia.belowPublicManaThreshold = true
            local channel = TotemNesia.GetAnnounceChannel()
            if channel and TotemNesiaDB.manaAnnounce and TotemNesia.publicManaAlertCooldown <= 0 then
                SendChatMessage("I am low on mana, I need to drink.", channel)
                TotemNesia.publicManaAlertCooldown = 30
                TotemNesia.DebugPrint("Public mana alert sent to " .. channel .. ": " .. math.floor(manaPercent) .. "%")
            end
        elseif manaPercent >= publicThreshold and TotemNesia.belowPublicManaThreshold then
            TotemNesia.belowPublicManaThreshold = false
            TotemNesia.DebugPrint("Mana restored above public mana threshold")
        end
    end
end
