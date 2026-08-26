-- HarderDifficulty.lua
-- HomeBrew difficulty scaling (server-side)
--
-- NPCs:
--   * Hit Points: Normal / Dangerous / Fatal encounter dropdowns
--   * Resources: Actions / Bonus Actions / Reactions
--   * Stats: AC / Attack / Damage / Damage Resistance / Saves / Spell Save DC
--
-- Players:
--   * Hit Points: Normal / Doubled / Tripled / Quadrupled / Quintupled
--   * Resources: Actions / Bonus Actions / Reactions
--   * Stats: AC / Attack / Damage / Damage Resistance / Saves / Spell Save DC

local MOD_UUID = "486d1526-3505-4b09-9790-0f6a60f5ac0f"

-- Encounter classification passives
local PASSIVE_DANGEROUS = "Dangerous_Encounter"
local PASSIVE_FATAL     = "Fatal_Encounter"

-- Summons carrying any of these statuses are excluded from both systems.
local SUMMON_EXCLUSION_STATUSES = {
    "SHADOWCURSE_SUMMON_CHECK",
    "UNSUMMON_ABLE",
}

-- Late combat joiners are processed after a short delay.
local pendingEnteredCombat = {}

-- =========================================================
-- MCM SETTING IDS
-- =========================================================

local DIFFICULTY_PRESET = "hb_difficulty_preset"

local NPC_HP_MODE = {
    normal    = "hb_hp_mode_normal",
    dangerous = "hb_hp_mode_dangerous",
    fatal     = "hb_hp_mode_fatal",
}

local NPC_STATS = {
    normal = {
        AC               = "hb_stats_AC",
        Attack           = "hb_stats_Attack",
        Damage           = "hb_stats_Damage",
        DamageResistance = "hb_stats_DamageResistance",
        Saves            = "hb_stats_Saves",
        SaveDC           = "hb_stats_SaveDC",
    },
    dangerous = {
        AC               = "hb_stats_dangerous_AC",
        Attack           = "hb_stats_dangerous_Attack",
        Damage           = "hb_stats_dangerous_Damage",
        DamageResistance = "hb_stats_dangerous_DamageResistance",
        Saves            = "hb_stats_dangerous_Saves",
        SaveDC           = "hb_stats_dangerous_SaveDC",
    },
    fatal = {
        AC               = "hb_stats_fatal_AC",
        Attack           = "hb_stats_fatal_Attack",
        Damage           = "hb_stats_fatal_Damage",
        DamageResistance = "hb_stats_fatal_DamageResistance",
        Saves            = "hb_stats_fatal_Saves",
        SaveDC           = "hb_stats_fatal_SaveDC",
    },
}

local NPC_PROFICIENCY = {
    normal = {
        AC               = "hb_stats_prof_AC",
        Attack           = "hb_stats_prof_Attack",
        Damage           = "hb_stats_prof_Damage",
        DamageResistance = "hb_stats_prof_DamageResistance",
        Saves            = "hb_stats_prof_Saves",
        SaveDC           = "hb_stats_prof_SaveDC",
    },
    dangerous = {
        AC               = "hb_stats_prof_dangerous_AC",
        Attack           = "hb_stats_prof_dangerous_Attack",
        Damage           = "hb_stats_prof_dangerous_Damage",
        DamageResistance = "hb_stats_prof_dangerous_DamageResistance",
        Saves            = "hb_stats_prof_dangerous_Saves",
        SaveDC           = "hb_stats_prof_dangerous_SaveDC",
    },
    fatal = {
        AC               = "hb_stats_prof_fatal_AC",
        Attack           = "hb_stats_prof_fatal_Attack",
        Damage           = "hb_stats_prof_fatal_Damage",
        DamageResistance = "hb_stats_prof_fatal_DamageResistance",
        Saves            = "hb_stats_prof_fatal_Saves",
        SaveDC           = "hb_stats_prof_fatal_SaveDC",
    },
}

local NPC_RESOURCES = {
    normal = {
        actions      = "hb_res_normal_actions",
        bonusactions = "hb_res_normal_bonusactions",
        reactions    = "hb_res_normal_reactions",
    },
    dangerous = {
        actions      = "hb_res_dangerous_actions",
        bonusactions = "hb_res_dangerous_bonusactions",
        reactions    = "hb_res_dangerous_reactions",
    },
    fatal = {
        actions      = "hb_res_fatal_actions",
        bonusactions = "hb_res_fatal_bonusactions",
        reactions    = "hb_res_fatal_reactions",
    },
}

local PLAYER_HP_MODE = "hb_player_hp_mode"

local PLAYER_STATS = {
    AC               = "hb_player_stats_AC",
    Attack           = "hb_player_stats_Attack",
    Damage           = "hb_player_stats_Damage",
    DamageResistance = "hb_player_stats_DamageResistance",
    Saves            = "hb_player_stats_Saves",
    SaveDC           = "hb_player_stats_SaveDC",
}

local PLAYER_PROFICIENCY = {
    AC               = "hb_player_stats_prof_AC",
    Attack           = "hb_player_stats_prof_Attack",
    Damage           = "hb_player_stats_prof_Damage",
    DamageResistance = "hb_player_stats_prof_DamageResistance",
    Saves            = "hb_player_stats_prof_Saves",
    SaveDC           = "hb_player_stats_prof_SaveDC",
}

local PLAYER_RESOURCES = {
    actions      = "hb_player_res_actions",
    bonusactions = "hb_player_res_bonusactions",
    reactions    = "hb_player_res_reactions",
}

-- =========================================================
-- STATUS NAMES
-- =========================================================

local NPC_HP_STATUS = {
    normal = {
        veryeasy  = "HEALTHBOOST_VERYEASY",
        easy      = "HEALTHBOOST_EASY",
        normal    = "HEALTHBOOST_NORMAL",
        hard      = "HEALTHBOOST_HARD",
        veryhard  = "HEALTHBOOST_VERYHARD",
        nightmare = "HEALTHBOOST_NIGHTMARE",
        infernal  = "HEALTHBOOST_INFERNAL",
        legendary = "HEALTHBOOST_LEGENDARY",
        ascendant = "HEALTHBOOST_ASCENDANT",
        impossible = "HEALTHBOOST_IMPOSSIBLE",
    },
    dangerous = {
        veryeasy  = "HEALTHBOOST_VERYEASY_DANGEROUS",
        easy      = "HEALTHBOOST_EASY_DANGEROUS",
        normal    = "HEALTHBOOST_NORMAL_DANGEROUS",
        hard      = "HEALTHBOOST_HARD_DANGEROUS",
        veryhard  = "HEALTHBOOST_VERYHARD_DANGEROUS",
        nightmare = "HEALTHBOOST_NIGHTMARE_DANGEROUS",
        infernal  = "HEALTHBOOST_INFERNAL_DANGEROUS",
        legendary = "HEALTHBOOST_LEGENDARY_DANGEROUS",
        ascendant = "HEALTHBOOST_ASCENDANT_DANGEROUS",
        impossible = "HEALTHBOOST_IMPOSSIBLE_DANGEROUS",
    },
    fatal = {
        veryeasy  = "HEALTHBOOST_VERYEASY_FATAL",
        easy      = "HEALTHBOOST_EASY_FATAL",
        normal    = "HEALTHBOOST_NORMAL_FATAL",
        hard      = "HEALTHBOOST_HARD_FATAL",
        veryhard  = "HEALTHBOOST_VERYHARD_FATAL",
        nightmare = "HEALTHBOOST_NIGHTMARE_FATAL",
        infernal  = "HEALTHBOOST_INFERNAL_FATAL",
        legendary = "HEALTHBOOST_LEGENDARY_FATAL",
        ascendant = "HEALTHBOOST_ASCENDANT_FATAL",
        impossible = "HEALTHBOOST_IMPOSSIBLE_FATAL",
    },
}

-- IMPORTANT:
-- These four names must match the player HP statuses in your stats files.
-- Normal intentionally applies no status.
local PLAYER_HP_STATUS = {
    doubled    = "PLAYER_HEALTHBOOST_DOUBLED",
    tripled    = "PLAYER_HEALTHBOOST_TRIPLED",
    quadrupled = "PLAYER_HEALTHBOOST_QUADRUPLED",
    quintupled = "PLAYER_HEALTHBOOST_QUINTUPLED",
}

local STAT_STATUS = {
    AC = {},
    Attack = {},
    Damage = {},
    DamageResistance = {},
    Saves = {},
    SaveDC = {},
}

for i = 1, 10 do
    STAT_STATUS.AC[i]               = "STATBOOST_AC_" .. i
    STAT_STATUS.Attack[i]           = "STATBOOST_ATTACK_" .. i
    STAT_STATUS.Damage[i]           = "STATBOOST_DAMAGE_" .. i
    STAT_STATUS.DamageResistance[i] = "STATBOOST_DAMAGERESISTANCE_" .. i
    STAT_STATUS.Saves[i]            = "STATBOOST_SAVINGTHROWS_" .. i
    STAT_STATUS.SaveDC[i]           = "STATBOOST_SPELLSAVEDC_" .. i
end

-- These six names must match the proficiency-scaling statuses in your stats files.
local PROFICIENCY_STAT_STATUS = {
    AC               = "STATBOOST_PROFICIENCY_AC",
    Attack           = "STATBOOST_PROFICIENCY_ATTACK",
    Damage           = "STATBOOST_PROFICIENCY_DAMAGE",
    DamageResistance = "STATBOOST_PROFICIENCY_DAMAGERESISTANCE",
    Saves            = "STATBOOST_PROFICIENCY_SAVINGTHROWS",
    SaveDC           = "STATBOOST_PROFICIENCY_SPELLSAVEDC",
}

local ACTION_STATUS = {
    [1] = "ACTION_1",
    [2] = "ACTION_2",
    [3] = "ACTION_3",
}

local BONUS_STATUS = {
    [1] = "BONUSACTION_1",
    [2] = "BONUSACTION_2",
    [3] = "BONUSACTION_3",
}

local REACTION_STATUS = {
    [1] = "REACTIONACTION_1",
    [2] = "REACTIONACTION_2",
    [3] = "REACTIONACTION_3",
}

-- =========================================================
-- FLAT STATUS LISTS
-- =========================================================

local ALL_NPC_HP_STATUSES = {}
for _, encounterStatuses in pairs(NPC_HP_STATUS) do
    for _, status in pairs(encounterStatuses) do
        table.insert(ALL_NPC_HP_STATUSES, status)
    end
end

local ALL_PLAYER_HP_STATUSES = {}
for _, status in pairs(PLAYER_HP_STATUS) do
    table.insert(ALL_PLAYER_HP_STATUSES, status)
end

local ALL_STAT_STATUSES = {}
for _, statuses in pairs(STAT_STATUS) do
    for i = 1, 10 do
        table.insert(ALL_STAT_STATUSES, statuses[i])
    end
end

for _, status in pairs(PROFICIENCY_STAT_STATUS) do
    table.insert(ALL_STAT_STATUSES, status)
end

local ALL_RESOURCE_STATUSES = {
    "ACTION_1", "ACTION_2", "ACTION_3",
    "BONUSACTION_1", "BONUSACTION_2", "BONUSACTION_3",
    "REACTIONACTION_1", "REACTIONACTION_2", "REACTIONACTION_3",
}

-- =========================================================
-- INTERNAL STATE
-- =========================================================

local didInitialRefresh = false
local warnedMissingStats = {}
local isApplyingPreset = false

-- Complete difficulty preset definitions.
-- Any setting omitted from a preset is reset to its neutral value.
-- Custom intentionally changes nothing.
local DIFFICULTY_PRESETS = {
    Explorer = {
        npcHP = "Very Easy",
    },
    Balanced = {
        npcHP = "Easy",
    },
    Tactician = {
        npcHP = "Normal",
    },
    Honour = {
        npcHP = "Normal",
        npcProficiency = true,
    },
    Mythic = {
        npcHP = "Normal",
        npcProficiency = true,
        npcResources = {
            dangerous = 1,
            fatal = 2,
        },
    },
    ["Expanded Party Size (Easy)"] = {
        npcHP = "Nightmare",
    },
    ["Expanded Party Size (Normal)"] = {
        npcHP = "Nightmare",
        npcProficiency = true,
    },
    ["Expanded Party Size (Hard)"] = {
        npcHP = "Nightmare",
        npcProficiency = true,
        npcResources = {
            dangerous = 1,
            fatal = 2,
        },
    },
    ["Maximum Difficulty"] = {
        npcHP = "Impossible",
        npcResources = {
            normal = 3,
            dangerous = 3,
            fatal = 3,
        },
        npcStats = 10,
    },
    Endurance = {
        npcHP = "Very Hard",
        playerHP = "Quintupled",
        npcProficiency = true,
        playerProficiency = true,
        npcResources = {
            normal = 1,
            dangerous = 1,
            fatal = 1,
        },
        playerResources = 1,
    },
}

-- =========================================================
-- HELPERS
-- =========================================================

local function Log(message)
    Ext.Utils.Print(string.format("[HarderDifficulty] %s", tostring(message)))
end

local function IsCharacter(guid)
    return guid ~= nil and guid ~= "" and Osi.IsCharacter(guid) == 1
end

local function IsPlayerCharacter(guid)
    return IsCharacter(guid) and Osi.IsPlayer(guid) == 1
end

local function IsExcludedSummon(guid)
    for _, status in ipairs(SUMMON_EXCLUSION_STATUSES) do
        if Osi.HasActiveStatus(guid, status) == 1 then
            return true
        end
    end

    return false
end

local function IsValidNPCTarget(guid)
    return IsCharacter(guid)
        and not IsPlayerCharacter(guid)
        and not IsExcludedSummon(guid)
end

local function IsValidPlayerTarget(guid)
    return IsPlayerCharacter(guid)
        and not IsExcludedSummon(guid)
end

local function HasStatus(guid, status)
    return status ~= nil
        and status ~= ""
        and Osi.HasActiveStatus(guid, status) == 1
end

local function StatusExists(status)
    if status == nil or status == "" then
        return false
    end

    -- Ext.Stats.Get returns nil when the status is not defined.
    return Ext.Stats.Get(status) ~= nil
end

local function ApplyStatusPermanent(guid, status)
    if not status or status == "" then
        return
    end

    if not StatusExists(status) then
        if not warnedMissingStats[status] then
            warnedMissingStats[status] = true
            Log("Missing status definition: " .. status)
        end
        return
    end

    if not HasStatus(guid, status) then
        Osi.ApplyStatus(guid, status, -1, 1, guid)
    end
end

local function RemoveStatusIfPresent(guid, status)
    if status and status ~= "" and HasStatus(guid, status) then
        Osi.RemoveStatus(guid, status)
    end
end

local function RemoveStatuses(guid, statuses)
    for _, status in ipairs(statuses) do
        RemoveStatusIfPresent(guid, status)
    end
end

local function HasPassive(guid, passive)
    return Osi.HasPassive(guid, passive) == 1
end

local function EncounterType(guid)
    if HasPassive(guid, PASSIVE_FATAL) then
        return "fatal"
    end

    if HasPassive(guid, PASSIVE_DANGEROUS) then
        return "dangerous"
    end

    return "normal"
end

local function GetInt(settingId, defaultValue)
    if not (MCM and MCM.Get) then
        return defaultValue
    end

    local value = MCM.Get(settingId)
    if type(value) == "number" then
        return math.floor(value)
    end

    return defaultValue
end

local function GetBool(settingId, defaultValue)
    if not (MCM and MCM.Get) then
        return defaultValue
    end

    local value = MCM.Get(settingId)

    if type(value) == "boolean" then
        return value
    end

    if type(value) == "number" then
        return value ~= 0
    end

    if type(value) == "string" then
        local normalized = value:lower()
        if normalized == "true" or normalized == "1" then
            return true
        end
        if normalized == "false" or normalized == "0" then
            return false
        end
    end

    return defaultValue
end

local function GetString(settingId, defaultValue)
    if not (MCM and MCM.Get) then
        return defaultValue
    end

    local value = MCM.Get(settingId)
    if type(value) == "string" and value ~= "" then
        return value
    end

    return defaultValue
end

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function NormalizeNPCMode(value)
    local mode = tostring(value or "Normal")
    mode = mode:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    mode = mode:gsub("%s+", "")

    local valid = {
        veryeasy = true,
        easy = true,
        normal = true,
        hard = true,
        veryhard = true,
        nightmare = true,
        infernal = true,
        legendary = true,
        ascendant = true,
        impossible = true,
    }

    if valid[mode] then
        return mode
    end

    return "normal"
end

local function NormalizePlayerHPMode(value)
    local mode = tostring(value or "Normal")
    mode = mode:gsub("^%s+", ""):gsub("%s+$", ""):lower()

    if mode == "doubled" then return "doubled" end
    if mode == "tripled" then return "tripled" end
    if mode == "quadrupled" then return "quadrupled" end
    if mode == "quintupled" then return "quintupled" end

    return "normal"
end

local function HasAnyStatus(guid, statuses)
    for _, status in ipairs(statuses) do
        if HasStatus(guid, status) then
            return true
        end
    end

    return false
end

-- =========================================================
-- NPC SYSTEMS
-- =========================================================

local function ApplyNPCHP(guid, force)
    if not IsValidNPCTarget(guid) then
        RemoveStatuses(guid, ALL_NPC_HP_STATUSES)
        return
    end

    if not force and HasAnyStatus(guid, ALL_NPC_HP_STATUSES) then
        return
    end

    local encounter = EncounterType(guid)
    local mode = NormalizeNPCMode(GetString(NPC_HP_MODE[encounter], "Normal"))
    local status = NPC_HP_STATUS[encounter][mode]

    RemoveStatuses(guid, ALL_NPC_HP_STATUSES)
    ApplyStatusPermanent(guid, status)
end

local function ApplyNPCStats(guid, force)
    if not IsValidNPCTarget(guid) then
        RemoveStatuses(guid, ALL_STAT_STATUSES)
        return
    end

    local encounter = EncounterType(guid)
    local settings = NPC_STATS[encounter]
    local proficiencySettings = NPC_PROFICIENCY[encounter]

    -- Always rebuild this category. This correctly restores individual
    -- statuses if one was removed while others remained.
    RemoveStatuses(guid, ALL_STAT_STATUSES)

    for statKey, settingId in pairs(settings) do
        if GetBool(proficiencySettings[statKey], false) then
            ApplyStatusPermanent(guid, PROFICIENCY_STAT_STATUS[statKey])
        else
            local value = Clamp(GetInt(settingId, 0), 0, 10)
            if value > 0 then
                ApplyStatusPermanent(guid, STAT_STATUS[statKey][value])
            end
        end
    end
end

local function ApplyNPCResources(guid, force)
    if not IsValidNPCTarget(guid) then
        RemoveStatuses(guid, ALL_RESOURCE_STATUSES)
        return
    end

    local encounter = EncounterType(guid)
    local settings = NPC_RESOURCES[encounter]

    local actions = Clamp(GetInt(settings.actions, 0), 0, 3)
    local bonusActions = Clamp(GetInt(settings.bonusactions, 0), 0, 3)
    local reactions = Clamp(GetInt(settings.reactions, 0), 0, 3)

    RemoveStatuses(guid, ALL_RESOURCE_STATUSES)

    if actions > 0 then
        ApplyStatusPermanent(guid, ACTION_STATUS[actions])
    end

    if bonusActions > 0 then
        ApplyStatusPermanent(guid, BONUS_STATUS[bonusActions])
    end

    if reactions > 0 then
        ApplyStatusPermanent(guid, REACTION_STATUS[reactions])
    end
end

-- =========================================================
-- PLAYER SYSTEMS
-- =========================================================

local function ApplyPlayerHP(guid, force)
    if not IsValidPlayerTarget(guid) then
        RemoveStatuses(guid, ALL_PLAYER_HP_STATUSES)
        return
    end

    if not force and HasAnyStatus(guid, ALL_PLAYER_HP_STATUSES) then
        return
    end

    local mode = NormalizePlayerHPMode(GetString(PLAYER_HP_MODE, "Normal"))

    RemoveStatuses(guid, ALL_PLAYER_HP_STATUSES)

    -- Normal means no multiplier status.
    if mode ~= "normal" then
        ApplyStatusPermanent(guid, PLAYER_HP_STATUS[mode])
    end
end

local function ApplyPlayerStats(guid, force)
    if not IsValidPlayerTarget(guid) then
        RemoveStatuses(guid, ALL_STAT_STATUSES)
        return
    end

    RemoveStatuses(guid, ALL_STAT_STATUSES)

    for statKey, settingId in pairs(PLAYER_STATS) do
        if GetBool(PLAYER_PROFICIENCY[statKey], false) then
            ApplyStatusPermanent(guid, PROFICIENCY_STAT_STATUS[statKey])
        else
            local value = Clamp(GetInt(settingId, 0), 0, 10)
            if value > 0 then
                ApplyStatusPermanent(guid, STAT_STATUS[statKey][value])
            end
        end
    end
end

local function ApplyPlayerResources(guid, force)
    if not IsValidPlayerTarget(guid) then
        RemoveStatuses(guid, ALL_RESOURCE_STATUSES)
        return
    end

    local actions = Clamp(GetInt(PLAYER_RESOURCES.actions, 0), 0, 3)
    local bonusActions = Clamp(GetInt(PLAYER_RESOURCES.bonusactions, 0), 0, 3)
    local reactions = Clamp(GetInt(PLAYER_RESOURCES.reactions, 0), 0, 3)

    RemoveStatuses(guid, ALL_RESOURCE_STATUSES)

    if actions > 0 then
        ApplyStatusPermanent(guid, ACTION_STATUS[actions])
    end

    if bonusActions > 0 then
        ApplyStatusPermanent(guid, BONUS_STATUS[bonusActions])
    end

    if reactions > 0 then
        ApplyStatusPermanent(guid, REACTION_STATUS[reactions])
    end
end

-- =========================================================
-- ROUTING
-- =========================================================

local function ApplyHP(guid, force)
    if IsPlayerCharacter(guid) then
        RemoveStatuses(guid, ALL_NPC_HP_STATUSES)
        ApplyPlayerHP(guid, force)
    else
        RemoveStatuses(guid, ALL_PLAYER_HP_STATUSES)
        ApplyNPCHP(guid, force)
    end
end

local function ApplyStats(guid, force)
    if IsPlayerCharacter(guid) then
        ApplyPlayerStats(guid, force)
    else
        ApplyNPCStats(guid, force)
    end
end

local function ApplyResources(guid, force)
    if IsPlayerCharacter(guid) then
        ApplyPlayerResources(guid, force)
    else
        ApplyNPCResources(guid, force)
    end
end

local function ApplyAllSystems(guid, force)
    if not IsCharacter(guid) then
        return
    end

    if IsExcludedSummon(guid) then
        RemoveStatuses(guid, ALL_NPC_HP_STATUSES)
        RemoveStatuses(guid, ALL_PLAYER_HP_STATUSES)
        RemoveStatuses(guid, ALL_STAT_STATUSES)
        RemoveStatuses(guid, ALL_RESOURCE_STATUSES)
        return
    end

    ApplyHP(guid, force)
    ApplyStats(guid, force)
    ApplyResources(guid, force)
end

-- =========================================================
-- REFRESH
-- =========================================================

local function ForEachLoadedCharacter(callback)
    local seen = 0

    for _, entity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ServerCharacter")) do
        local guid = entity.Uuid and entity.Uuid.EntityUuid
        if IsCharacter(guid) then
            seen = seen + 1
            callback(guid)
        end
    end

    return seen
end

local function RefreshAllLoaded(reason, force)
    local seen = ForEachLoadedCharacter(function(guid)
        ApplyAllSystems(guid, force == true)
    end)

    Log(string.format(
        "%s refresh (force=%s, characters=%d)",
        tostring(reason),
        tostring(force == true),
        seen
    ))
end

local function RefreshHPOnly(reason)
    local seen = ForEachLoadedCharacter(function(guid)
        ApplyHP(guid, true)
    end)

    Log(string.format("%s HP refresh (characters=%d)", tostring(reason), seen))
end

local function RefreshStatsOnly(reason)
    local seen = ForEachLoadedCharacter(function(guid)
        ApplyStats(guid, true)
    end)

    Log(string.format("%s stats refresh (characters=%d)", tostring(reason), seen))
end

local function RefreshResourcesOnly(reason)
    local seen = ForEachLoadedCharacter(function(guid)
        ApplyResources(guid, true)
    end)

    Log(string.format("%s resources refresh (characters=%d)", tostring(reason), seen))
end

local function ApplyDifficultyPreset(presetName)
    if presetName == nil or presetName == "" or presetName == "Custom" then
        Log("Difficulty preset set to Custom; manual settings preserved.")
        return
    end

    local preset = DIFFICULTY_PRESETS[presetName]
    if preset == nil then
        Log("Unknown difficulty preset: " .. tostring(presetName))
        return
    end

    if not (MCM and MCM.Set) then
        Log("Cannot apply preset because MCM.Set is unavailable.")
        return
    end

    isApplyingPreset = true

    -- Reset every configurable difficulty setting to neutral values first.
    for _, settingId in pairs(NPC_HP_MODE) do
        MCM.Set(settingId, "Normal")
    end

    for _, encounterSettings in pairs(NPC_STATS) do
        for _, settingId in pairs(encounterSettings) do
            MCM.Set(settingId, 0)
        end
    end

    for _, encounterSettings in pairs(NPC_PROFICIENCY) do
        for _, settingId in pairs(encounterSettings) do
            MCM.Set(settingId, false)
        end
    end

    for _, encounterSettings in pairs(NPC_RESOURCES) do
        for _, settingId in pairs(encounterSettings) do
            MCM.Set(settingId, 0)
        end
    end

    MCM.Set(PLAYER_HP_MODE, "Normal")

    for _, settingId in pairs(PLAYER_STATS) do
        MCM.Set(settingId, 0)
    end

    for _, settingId in pairs(PLAYER_PROFICIENCY) do
        MCM.Set(settingId, false)
    end

    for _, settingId in pairs(PLAYER_RESOURCES) do
        MCM.Set(settingId, 0)
    end

    -- NPC Hit Points
    local npcHPMode = preset.npcHP or "Normal"
    for _, settingId in pairs(NPC_HP_MODE) do
        MCM.Set(settingId, npcHPMode)
    end

    -- NPC flat stat bonuses
    local npcStatValue = Clamp(tonumber(preset.npcStats) or 0, 0, 10)
    if npcStatValue > 0 then
        for _, encounterSettings in pairs(NPC_STATS) do
            for _, settingId in pairs(encounterSettings) do
                MCM.Set(settingId, npcStatValue)
            end
        end
    end

    -- NPC proficiency scaling
    if preset.npcProficiency == true then
        for _, encounterSettings in pairs(NPC_PROFICIENCY) do
            for _, settingId in pairs(encounterSettings) do
                MCM.Set(settingId, true)
            end
        end
    end

    -- NPC resources by encounter category
    if type(preset.npcResources) == "table" then
        for encounter, value in pairs(preset.npcResources) do
            local encounterSettings = NPC_RESOURCES[encounter]
            if encounterSettings ~= nil then
                local resourceValue = Clamp(tonumber(value) or 0, 0, 3)
                for _, settingId in pairs(encounterSettings) do
                    MCM.Set(settingId, resourceValue)
                end
            end
        end
    end

    -- Player Hit Points
    MCM.Set(PLAYER_HP_MODE, preset.playerHP or "Normal")

    -- Player proficiency scaling
    if preset.playerProficiency == true then
        for _, settingId in pairs(PLAYER_PROFICIENCY) do
            MCM.Set(settingId, true)
        end
    end

    -- Player resources
    local playerResourceValue = Clamp(tonumber(preset.playerResources) or 0, 0, 3)
    if playerResourceValue > 0 then
        for _, settingId in pairs(PLAYER_RESOURCES) do
            MCM.Set(settingId, playerResourceValue)
        end
    end

    isApplyingPreset = false

    RefreshAllLoaded("Difficulty preset applied: " .. presetName, true)
    Log("Applied complete difficulty preset: " .. tostring(presetName))
end

local PROFICIENCY_SLIDER = {}

for encounter, proficiencySettings in pairs(NPC_PROFICIENCY) do
    for statKey, proficiencySettingId in pairs(proficiencySettings) do
        PROFICIENCY_SLIDER[proficiencySettingId] = NPC_STATS[encounter][statKey]
    end
end

for statKey, proficiencySettingId in pairs(PLAYER_PROFICIENCY) do
    PROFICIENCY_SLIDER[proficiencySettingId] = PLAYER_STATS[statKey]
end

local SLIDER_PROFICIENCY = {}
for proficiencySettingId, sliderSettingId in pairs(PROFICIENCY_SLIDER) do
    SLIDER_PROFICIENCY[sliderSettingId] = proficiencySettingId
end

local function EnforceProficiencyOverride(settingId)
    local sliderSettingId = PROFICIENCY_SLIDER[settingId]
    if sliderSettingId == nil or not GetBool(settingId, false) then
        return
    end

    if MCM and MCM.Set and GetInt(sliderSettingId, 0) ~= 0 then
        isApplyingPreset = true
        MCM.Set(sliderSettingId, 0)
        isApplyingPreset = false

        Log(
            "Proficiency enabled for " .. tostring(settingId)
            .. "; reset " .. tostring(sliderSettingId) .. " to 0."
        )
    end
end

local function DisableProficiencyForSlider(settingId)
    local proficiencySettingId = SLIDER_PROFICIENCY[settingId]
    if proficiencySettingId == nil then
        return
    end

    local sliderValue = GetInt(settingId, 0)
    if sliderValue <= 0 or not GetBool(proficiencySettingId, false) then
        return
    end

    if MCM and MCM.Set then
        isApplyingPreset = true
        MCM.Set(proficiencySettingId, false)
        isApplyingPreset = false

        Log(
            "Slider " .. tostring(settingId)
            .. " changed above 0; disabled " .. tostring(proficiencySettingId) .. "."
        )
    end
end

local function RefreshForSetting(settingId)
    if type(settingId) ~= "string" then
        RefreshAllLoaded("MCM changed", true)
        return
    end

    if settingId == PLAYER_HP_MODE or settingId:find("^hb_hp_mode_") then
        RefreshHPOnly("MCM changed: " .. settingId)
        return
    end

    if settingId:find("^hb_res_") or settingId:find("^hb_player_res_") then
        RefreshResourcesOnly("MCM changed: " .. settingId)
        return
    end

    if settingId:find("^hb_stats_") or settingId:find("^hb_player_stats_") then
        RefreshStatsOnly("MCM changed: " .. settingId)
        return
    end

    RefreshAllLoaded("MCM changed: " .. settingId, true)
end

-- =========================================================
-- EVENTS
-- =========================================================

Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function(guid)
    -- A newly joined companion must be moved from the NPC route to
    -- the player route immediately.
    if IsCharacter(guid) then
        ApplyAllSystems(guid, true)
    end
end)

Ext.Osiris.RegisterListener(
    "LevelGameplayStarted",
    2,
    "after",
    function(levelName, isEditorMode)
        RefreshAllLoaded("Level started: " .. tostring(levelName), false)
    end
)

Ext.ModEvents.BG3MCM["MCM_Setting_Saved"]:Subscribe(function(payload)
    if not payload or payload.modUUID ~= MOD_UUID then
        return
    end

    if isApplyingPreset then
        return
    end

    if payload.settingId == DIFFICULTY_PRESET then
        ApplyDifficultyPreset(GetString(DIFFICULTY_PRESET, "Balanced"))
        return
    end

    EnforceProficiencyOverride(payload.settingId)
    DisableProficiencyForSlider(payload.settingId)

    local isManualDifficultySetting =
        payload.settingId == PLAYER_HP_MODE
        or payload.settingId:find("^hb_hp_mode_")
        or payload.settingId:find("^hb_res_")
        or payload.settingId:find("^hb_player_res_")
        or payload.settingId:find("^hb_stats_")
        or payload.settingId:find("^hb_player_stats_")

    if isManualDifficultySetting then
        local currentPreset = GetString(DIFFICULTY_PRESET, "Custom")

        if currentPreset ~= "Custom" and MCM and MCM.Set then
            isApplyingPreset = true
            MCM.Set(DIFFICULTY_PRESET, "Custom")
            isApplyingPreset = false

            Log(
                "Difficulty setting changed manually; "
                .. "difficulty preset switched to Custom."
            )
        end
    end

    RefreshForSetting(payload.settingId)
end)

Ext.Osiris.RegisterListener("CombatStarted", 1, "after", function(combatGuid)
    RefreshAllLoaded("Combat started: " .. tostring(combatGuid), false)
end)

Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(guid, combatGuid)
    if IsCharacter(guid) then
        pendingEnteredCombat[guid] = 2
    end
end)

Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(object, status, causee, storyActionID)
    if IsCharacter(object) then
        for _, exclusionStatus in ipairs(SUMMON_EXCLUSION_STATUSES) do
            if status == exclusionStatus then
                ApplyAllSystems(object, true)
                return
            end
        end
    end
end)

Ext.Events.Tick:Subscribe(function()
    if not didInitialRefresh and MCM and MCM.Get then
        RefreshAllLoaded("Initial", false)
        didInitialRefresh = true
    end

    for guid, ticksRemaining in pairs(pendingEnteredCombat) do
        ticksRemaining = ticksRemaining - 1

        if ticksRemaining <= 0 then
            pendingEnteredCombat[guid] = nil
            ApplyAllSystems(guid, false)
        else
            pendingEnteredCombat[guid] = ticksRemaining
        end
    end
end)

Log("Loaded: NPC and player HP, stats, resources, and proficiency overrides are active.")
