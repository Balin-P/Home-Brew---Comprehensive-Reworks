local SIF_KeepInitiativeStatus = "SIF_NEVER_SHARE"

local function SyncInitiative(summon)
    local owner = Osi.CharacterGetOwner(summon)
    local summonEntity = Ext.Entity.Get(summon)
    local ownerEntity = Ext.Entity.Get(owner)
    local summonCombat = summonEntity.CombatantJoinEvent.Combat.CombatState.MyGuid
    local ownerCombat
    local joiningMidCombat

    if ownerEntity and ownerEntity.CombatantJoinEvent then
        ownerCombat = ownerEntity.CombatantJoinEvent.Combat.CombatState.MyGuid
        joiningMidCombat = false
    else
        ownerCombat = Osi.CombatGetGuidFor(owner)
        joiningMidCombat = true
    end

    if not ownerCombat or ownerCombat ~= summonCombat then
        return
    end

    local summonRoll = summonEntity.CombatantJoinEvent.Initiative
    local ownerRoll

    if joiningMidCombat then
        ownerRoll = ownerEntity.CombatParticipant.InitiativeRoll
    else
        ownerRoll = ownerEntity.CombatantJoinEvent.Initiative
    end

    if ownerRoll ~= summonRoll then
        print("Adjusting " .. Osi.ResolveTranslatedString(Osi.GetDisplayName(summon)) .. "'s initiative roll from " .. summonRoll .. " to " .. ownerRoll .. ".")
        summonEntity.CombatantJoinEvent.Initiative = ownerRoll
    end
end

Ext.Entity.OnCreateDeferred("CombatantJoinEvent", function(entity)
    local entityUuid = entity.Uuid.EntityUuid
    if Osi.IsSummon(entityUuid) == 1 and (Osi.HasActiveStatus(entityUuid, SIF_KeepInitiativeStatus) == 0 and Osi.HasActiveStatus(entityUuid, "ALWAYS_USE_OWN_INITIATIVE") == 0) then
        SyncInitiative(entityUuid)

        if Osi.HasActiveStatus(entityUuid, "ALWAYS_USE_OWN_INITIATIVE") == 1 then Ext.Utils.PrintWarning("[Summon Initiative Fixer] ALWAYS_USE_OWN_INITIATIVE status is deprecated; use SIF_NEVER_SHARE status.") end
    end
end)