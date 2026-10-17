-- TotemNesia: Aggro alert and line of sight announcement
-- For OctoWoW (1.12)

-- Core.lua stops loading on non-Shamans, so every other file stops too
if not TotemNesia or not TotemNesia.shared then
    return
end

-- ============================================================================
-- AGGRO ALERT
-- ============================================================================
-- How the aggro check works:
-- Vanilla has no "you pulled aggro" event, so twice a second (only while you are in a
-- group and in combat) the addon asks whether any hostile mob is targeting you. It looks
-- in three places, stopping at the first hit:
--   1. A threat API, if a client mod provides UnitThreatSituation.
--   2. Your target, your pet's target, and every party or raid member's target.
--   3. With SuperWoW, every mob that has a visible nameplate. SuperWoW stores each
--      nameplate's unit ID (GUID) on the nameplate, so mobs nobody has targeted can be
--      checked too. Enemy nameplates have to be turned on (V key) for this step.
-- A mob has to stay on you for AGGRO_CONFIRM_TIME before the alert fires, so a mob that
-- only glances at you on its way to the tank doesn't count. The alert fires once when you
-- gain aggro, then waits until you lose it, and never repeats faster than
-- AGGRO_REALERT_TIME. The "I have aggro!" chat message has its own longer cooldown,
-- AGGRO_ANNOUNCE_COOLDOWN, so a mob bouncing between you and the tank doesn't spam the group.
-- Both cooldowns reset when you leave combat, so the first aggro of the next pull always alerts.
-- The alert: "You have aggro!" on screen, the Aggro voice, and "I have aggro!" in party
-- or raid chat (each can be turned off on the Alerts tab).

local AGGRO_CHECK_INTERVAL = 0.5  -- seconds between checks
local AGGRO_CONFIRM_TIME = 1.0    -- seconds a mob must stay on you before alerting
local AGGRO_REALERT_TIME = 10     -- minimum seconds between two on-screen/voice aggro alerts
local AGGRO_ANNOUNCE_COOLDOWN = 20 -- minimum seconds between two "I have aggro!" chat messages (resets out of combat)

local aggroElapsed = 0
local aggroSince = nil     -- when the current aggro started
local aggroAlerted = false -- already alerted for the current aggro
local lastAggroAlert = 0
local lastAggroAnnounce = 0

-- True if this unit is a living hostile mob that is targeting the player
local function IsTargetingMe(unit)
    if not UnitExists(unit) or UnitIsDead(unit) or not UnitCanAttack("player", unit) then
        return false
    end
    return UnitIsUnit(unit .. "target", "player")
end

local function HasAggro()
    -- 1. Threat API from a client mod (2 or 3 means a mob is attacking you)
    if UnitThreatSituation then
        local ok, status = pcall(UnitThreatSituation, "player")
        if ok and status and status >= 2 then
            return true
        end
    end

    -- 2. Your target, your pet's target, and your group's targets
    if IsTargetingMe("target") or IsTargetingMe("pettarget") then
        return true
    end
    local raidCount = GetNumRaidMembers()
    if raidCount > 0 then
        for i = 1, raidCount do
            if IsTargetingMe("raid" .. i .. "target") then
                return true
            end
        end
    else
        for i = 1, GetNumPartyMembers() do
            if IsTargetingMe("party" .. i .. "target") or IsTargetingMe("partypet" .. i .. "target") then
                return true
            end
        end
    end

    -- 3. SuperWoW: every mob with a visible nameplate, targeted or not
    if TotemNesia.hasSuperWoW and WorldFrame then
        local kids = { WorldFrame:GetChildren() }
        for i = 1, table.getn(kids) do
            local frame = kids[i]
            if frame and frame:IsVisible() then
                local ok, guid = pcall(frame.GetName, frame, 1)
                if ok and type(guid) == "string" and guid ~= "" then
                    local ok2, mine = pcall(IsTargetingMe, guid)
                    if ok2 and mine then
                        return true
                    end
                end
            end
        end
    end

    return false
end

function TotemNesia.CheckAggro()
    -- Only while the alert is on, you're alive, in combat, and in a group.
    -- Solo you nearly always have aggro, so alerting there would be noise.
    -- Leaving combat resets both cooldowns, so the next pull starts fresh
    if not UnitAffectingCombat("player") then
        lastAggroAlert = 0
        lastAggroAnnounce = 0
    end

    local inGroup = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
    if not TotemNesiaDB or not TotemNesiaDB.aggroAlert or not inGroup
        or not UnitAffectingCombat("player") or UnitIsDeadOrGhost("player") then
        aggroSince = nil
        aggroAlerted = false
        return
    end

    if not HasAggro() then
        aggroSince = nil
        aggroAlerted = false
        return
    end

    local now = GetTime()
    if not aggroSince then
        aggroSince = now
    end
    if aggroAlerted or (now - aggroSince) < AGGRO_CONFIRM_TIME or (now - lastAggroAlert) < AGGRO_REALERT_TIME then
        return
    end

    aggroAlerted = true
    lastAggroAlert = now
    UIErrorsFrame:AddMessage("You have aggro!", 1, 0.1, 0.1, 1.0, 3)
    if not TotemNesiaDB.aggroAudioMuted then
        TotemNesia.PlayAlertSound("Aggro")
    end
    -- Chat has its own, longer cooldown: when a mob keeps bouncing between you and the
    -- tank, you still get the on-screen warning but the group isn't spammed.
    if TotemNesiaDB.aggroAnnounce and (now - lastAggroAnnounce) >= AGGRO_ANNOUNCE_COOLDOWN then
        local channel = TotemNesia.GetAnnounceChannel()
        if channel then
            SendChatMessage("I have aggro!", channel)
            lastAggroAnnounce = now
        end
    end
    TotemNesia.DebugPrint("Aggro alert")
end

local aggroFrame = CreateFrame("Frame")
aggroFrame:SetScript("OnUpdate", function()
    aggroElapsed = aggroElapsed + arg1
    if aggroElapsed >= AGGRO_CHECK_INTERVAL then
        aggroElapsed = 0
        TotemNesia.CheckAggro()
    end
end)

-- ============================================================================
-- LINE OF SIGHT ANNOUNCEMENT
-- ============================================================================
-- When a spell fails with "Target not in line of sight" on a player in your group, the
-- group is told: "<Name>, you are out of LoS for healing." It goes to party or raid chat
-- so the whole group sees that the healer tried to warn them. Each player is announced
-- at most once every LOS_COOLDOWN seconds, so chain-casting into a pillar doesn't spam chat.
--
-- Who you were healing: the unit under your mouse if it's a group member (mouseover
-- macros and click-casting on raid frames don't change your target), otherwise your
-- target. The error itself doesn't say who the spell was for, so this is a best guess.

local LOS_COOLDOWN = 5
local LOS_ERROR = SPELL_FAILED_LINE_OF_SIGHT or "Target not in line of sight"
local lastLosWarning = {}  -- player name -> time of last announcement

-- True for another player in your party or raid
local function IsGroupPlayer(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then
        return false
    end
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            if UnitIsUnit(unit, "raid" .. i) then
                return true
            end
        end
        return false
    end
    for i = 1, GetNumPartyMembers() do
        if UnitIsUnit(unit, "party" .. i) then
            return true
        end
    end
    return false
end

local losFrame = CreateFrame("Frame")
losFrame:RegisterEvent("UI_ERROR_MESSAGE")
losFrame:SetScript("OnEvent", function()
    if not arg1 or not TotemNesiaDB or not TotemNesiaDB.losAnnounce then
        return
    end
    if arg1 ~= LOS_ERROR and not string.find(string.lower(arg1), "line of sight") then
        return
    end
    local unit = nil
    if IsGroupPlayer("mouseover") then
        unit = "mouseover"
    elseif IsGroupPlayer("target") then
        unit = "target"
    end
    if not unit then
        TotemNesia.DebugPrint("Line of sight error, but no group member under the mouse or targeted")
        return
    end
    local channel = TotemNesia.GetAnnounceChannel()
    local name = UnitName(unit)
    if not channel or not name then
        TotemNesia.DebugPrint("Line of sight error, but announcements are off for this group type")
        return
    end
    local now = GetTime()
    if lastLosWarning[name] and (now - lastLosWarning[name]) < LOS_COOLDOWN then
        return
    end
    lastLosWarning[name] = now
    SendChatMessage(name .. ", you are out of LoS for healing.", channel)
    TotemNesia.DebugPrint("Line of sight warning sent for " .. name)
end)
