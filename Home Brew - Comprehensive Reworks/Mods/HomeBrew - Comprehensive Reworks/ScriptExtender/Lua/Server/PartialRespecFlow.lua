---@class PendingPartialRespec
---@field level integer|nil
---@field charLevel integer
---@field snapshot table|nil

---@type table<string, PendingPartialRespec>
local pendingRespec = {}

---@param character string
---@return string
local function Guid(character)
    return string.sub(tostring(character), -36)
end

---@param peerId integer
---@return integer
local function PeerToReservedUserID(peerId)
    return peerId - (peerId % 0x10000) + 1
end

-- Only during dialog? Not sure, haven't tested
local RESPEC_START_FLAG = "6d4979bc-8e95-46be-9c27-96c6e22b0152"
local TOAST_DELAY_MS = 1000
local classDisplayNames = {}
local featDisplayNames = {}
local featDescriptionGuids = {}
local featDescriptionsLoaded = false

---@class PartialRespecDisplayName
---@field DisplayNameHandle string|nil
---@field DisplayNameFallback string

---@param value string
---@return string|nil
local function HumanizeResourceName(value)
    local name = tostring(value)
    if name:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") then
        return nil
    end
    name = name:gsub("^ProgressionSubClass_", "")
    name = name:gsub("^ProgressionClass_", "")
    name = name:gsub("^Progression_", "")
    name = name:gsub("^Class_", "")
    name = name:gsub("^SubClass_", "")
    name = name:gsub("^Feat_", "")
    name = name:gsub("([a-z])([A-Z])", "%1 %2")
    name = name:gsub("_", " ")
    return name
end

--- Extracts a localization handle from a TranslatedString.
---@param value TranslatedString
---@return string|nil
local function TranslatedDisplayNameHandle(value)
    if not value or not value.Handle then return nil end

    local valueHandle = value.Handle
    local handle = valueHandle.Handle or valueHandle
    if handle then
        local result = tostring(handle)
        if result ~= "" and not result:find("^ResStr_") then
            return result
        end
    end
    return nil
end

local RESOURCE_TYPES_WITH_NAME = { ClassDescription = true, Feat = true }
local RESOURCE_TYPES_WITH_DISPLAY_NAME = { ClassDescription = true, FeatDescription = true }

--- Resolves a static resource's display name (localized handle + humanized fallback).
---@param resourceGuid string
---@param resourceType string
---@param fallback string
---@return PartialRespecDisplayName
local function ResourceDisplayName(resourceGuid, resourceType, fallback)
    local displayName = {
        DisplayNameHandle = nil,
        DisplayNameFallback = fallback,
    }

    local resource = Ext.StaticData.Get(resourceGuid, resourceType)
    if resource then
        -- Feat has only Name, FeatDescription only DisplayName; ClassDescription has both.
        if RESOURCE_TYPES_WITH_DISPLAY_NAME[resourceType] then
            displayName.DisplayNameHandle = TranslatedDisplayNameHandle(resource.DisplayName)
        end

        if RESOURCE_TYPES_WITH_NAME[resourceType] then
            local resourceName = resource.Name
            if resourceName then
                local name = HumanizeResourceName(resourceName)
                if name then displayName.DisplayNameFallback = name end
            end
        end

        if displayName.DisplayNameHandle then return displayName end
    end
    return displayName
end

---@param classGuid string
---@return PartialRespecDisplayName
local function ClassDisplayName(classGuid)
    if classDisplayNames[classGuid] then
        return classDisplayNames[classGuid]
    end

    classDisplayNames[classGuid] = ResourceDisplayName(classGuid, "ClassDescription", "Unknown class?")
    return classDisplayNames[classGuid]
end

---@param subclassGuid string
---@return PartialRespecDisplayName
local function SubClassDisplayName(subclassGuid)
    return ResourceDisplayName(subclassGuid, "ClassDescription", "Unknown subclass?")
end

--- Builds a FeatId -> FeatDescription guid map once to find localized feat display handles.
local function LoadFeatDescriptionGuids()
    if featDescriptionsLoaded then return end

    local descriptionGuids = Ext.StaticData.GetAll("FeatDescription")
    if not descriptionGuids then return end

    for _, descriptionGuid in ipairs(descriptionGuids) do
        local description = Ext.StaticData.Get(descriptionGuid, "FeatDescription")
        if description then
            local featId = description.FeatId
            if featId then
                local key = tostring(featId)
                if not featDescriptionGuids[key] then
                    featDescriptionGuids[key] = tostring(descriptionGuid)
                end
            end
        end
    end

    featDescriptionsLoaded = true
end

--- Feat display name with localized fallback via the linked FeatDescription resource.
---@param featGuid string
---@return PartialRespecDisplayName
local function FeatDisplayName(featGuid)
    if featDisplayNames[featGuid] then
        return featDisplayNames[featGuid]
    end

    local displayName = ResourceDisplayName(featGuid, "Feat", "Unknown feat")
    LoadFeatDescriptionGuids()

    local descriptionGuid = featDescriptionGuids[featGuid]
    if descriptionGuid then
        local descriptionName = ResourceDisplayName(
            descriptionGuid,
            "FeatDescription",
            displayName.DisplayNameFallback
        )
        if descriptionName.DisplayNameHandle then
            displayName.DisplayNameHandle = descriptionName.DisplayNameHandle
        end
    end

    featDisplayNames[featGuid] = displayName
    return displayName
end

---@param guid any
---@return boolean
local function IsValidGuid(guid)
    return guid ~= nil and tostring(guid) ~= "00000000-0000-0000-0000-000000000000"
end

--- Summarizes classes/subclasses/feats gained through the cutoff level for the popup and toast.
---@param levelUps table|nil
---@param cutoff integer
---@return table
local function BuildLevelSummary(levelUps, cutoff)
    local classLevels = {}
    local classOrder = {}
    local feats = {}
    local featKeys = {}

    local function AddFeat(guid, name)
        local key = guid and tostring(guid) or name
        if not key or featKeys[key] then return end
        featKeys[key] = true
        feats[#feats + 1] = name and {
            DisplayNameHandle = nil,
            DisplayNameFallback = name,
        } or FeatDisplayName(key)
    end

    for level = 1, cutoff do
        local levelUp = levelUps and levelUps[level]
        if levelUp then
            if IsValidGuid(levelUp.Class) then
                local classGuid = tostring(levelUp.Class)
                if not classLevels[classGuid] then
                    classLevels[classGuid] = { Level = 0, SubClass = nil }
                    classOrder[#classOrder + 1] = classGuid
                end
                classLevels[classGuid].Level = classLevels[classGuid].Level + 1
                if IsValidGuid(levelUp.SubClass) then
                    classLevels[classGuid].SubClass = tostring(levelUp.SubClass)
                end
            end

            if IsValidGuid(levelUp.Feat) then
                AddFeat(tostring(levelUp.Feat))
            end
        end
    end

    local classes = {}
    local subclasses = {}
    for _, classGuid in ipairs(classOrder) do
        local info = classLevels[classGuid]
        classes[#classes + 1] = {
            Name = ClassDisplayName(classGuid),
            Level = info.Level,
        }
        if info.SubClass then
            subclasses[#subclasses + 1] = SubClassDisplayName(info.SubClass)
        end
    end

    return {
        Level = cutoff,
        Classes = classes,
        Subclasses = subclasses,
        Feats = feats,
    }
end

--- Resolves the numeric user id whose viewer sees the respec screen.
--- Uses PartyView ownership: the target character belongs to a view whose UserID identifies the owning player.
--- Scans every PartyView entity (MP may create one per player). Falls back to the host's reserved user.
---@param characterGuid string
---@return integer
local function RespecViewerUser(characterGuid)
    for _, party in pairs(Ext.Entity.GetAllEntitiesWithComponent("PartyView")) do
        for _, view in pairs(party.PartyView.Views) do
            for _, char in pairs(view.Characters) do
                if char.Uuid and char.Uuid.EntityUuid == characterGuid then
                    return view.UserID
                end
            end
        end
    end
    return Osi.GetReservedUserID(Osi.GetHostCharacter())
end

--- Registers the respec as pending and asks the client to show the level-choice popup.
---@param character string
local function BeginPartialRespec(character)
    local characterGuid = Guid(character)
    if pendingRespec[characterGuid] then return end

    local entity = Ext.Entity.Get(characterGuid)
    if not entity then return end

    local level = entity.EocLevel and entity.EocLevel.Level or 12
    local levelSummaries = {}
    local levelUps = entity.CCLevelUp and entity.CCLevelUp.LevelUps
    for cutoff = 1, level do
        levelSummaries[cutoff] = BuildLevelSummary(levelUps, cutoff)
    end
    pendingRespec[characterGuid] = {
        level = nil,
        charLevel = level,
        snapshot = nil,
    }

    Ext.Timer.WaitFor(1500, function()
        PartialRespecChannel:SendToClient({
            Character = characterGuid,
            MaxLevel = level,
            LevelSummaries = levelSummaries,
            Visible = true,
        }, RespecViewerUser(characterGuid))
        PRPrint(0, "Partial respec popup requested for %s (level %d)", characterGuid, level)
    end)
end

Ext.Osiris.RegisterListener("PROC_FlagReactionAfterDialog", 3, "before", function(character, flag)
    if PartialRespecEnabled and Guid(flag) == RESPEC_START_FLAG then
        BeginPartialRespec(character)
    end
end)

Ext.Osiris.RegisterListener("PROC_LaunchRespec", 2, "before", function(character)
    if PartialRespecEnabled then BeginPartialRespec(character) end
end)

Ext.Osiris.RegisterListener("StartRespec", 1, "after", function(character)
    if PartialRespecEnabled then BeginPartialRespec(character) end
end)

---@param entity EntityHandle
local function DestroyExistingProgressions(entity)
    local container = entity.ProgressionContainer
    if not container or not container.Progressions then return 0 end
    local count = 0
    for _, bucket in ipairs(container.Progressions) do
        for _, progressionHandle in ipairs(bucket) do
            if progressionHandle and progressionHandle:IsAlive() then
                Ext.Entity.Destroy(progressionHandle)
                count = count + 1
            end
        end
    end
    return count
end

--- Replay core logic: destroys old progressions, restores snapshot 1..targetLevel, recalculates classes/EocLevel, notifies client.
---@param entity EntityHandle
---@param snapshot table
---@param targetLevel integer
---@param characterGuid string
local function ApplyReplay(entity, snapshot, targetLevel, characterGuid)
    -- Safety net: capture the pre-destruction state before removing progression entities.
    PartialRespecSnapshot.SaveRecoveryDump(entity, characterGuid, targetLevel, snapshot)

    local oldCount = DestroyExistingProgressions(entity)
    PRPrint(1, "Destroyed %d old progression entities", oldCount)

    Ext.OnNextTick(function()
        local plan = PartialRespecSnapshot.ApplySnapshotToCharacter(entity, snapshot, targetLevel)

        PRPrint(0, "Replay applied: buckets=%d entries=%d",
            plan.newBuckets, plan.newEntries)

        -- Delevel character
        local cc = entity.CCLevelUp
        if cc and cc.LevelUps and #cc.LevelUps > targetLevel then
            for i = #cc.LevelUps, targetLevel + 1, -1 do
                cc.LevelUps[i] = nil
            end
            entity:Replicate("CCLevelUp")
            PRPrint(1, "CCLevelUp truncated to %d", targetLevel)
        end

        -- Replay classes/subclasses
        local classLevels = {}
        if cc and cc.LevelUps then
            for i = 1, targetLevel do
                local lvlUp = cc.LevelUps[i]
                if lvlUp and lvlUp.Class and lvlUp.Class ~= "00000000-0000-0000-0000-000000000000" then
                    local guid = tostring(lvlUp.Class)
                    if not classLevels[guid] then
                        classLevels[guid] = { Level = 0, SubClass = "00000000-0000-0000-0000-000000000000" }
                    end
                    classLevels[guid].Level = classLevels[guid].Level + 1
                    if lvlUp.SubClass and lvlUp.SubClass ~= "00000000-0000-0000-0000-000000000000" then
                        classLevels[guid].SubClass = tostring(lvlUp.SubClass)
                    end
                end
            end
        end

        local newClasses = {}
        for guid, info in pairs(classLevels) do
            newClasses[#newClasses + 1] = {
                ClassUUID = guid,
                Level = info.Level,
                SubClassUUID = info.SubClass,
            }
        end
        entity.Classes.Classes = newClasses
        entity:Replicate("Classes")
        PRPrint(1, "Classes recalculated: %d entries summing to %d", #newClasses, targetLevel)

        local toastSummary = BuildLevelSummary(cc and cc.LevelUps, targetLevel)

        entity.EocLevel.Level = targetLevel
        entity:Replicate("EocLevel")
        PRPrint(1, "EocLevel set to %d", targetLevel)

        Ext.Timer.WaitFor(TOAST_DELAY_MS, function()
            PartialRespecChannel:SendToClient({
                Toast = true,
                ToastLevelCount = targetLevel,
                ToastClasses = toastSummary.Classes,
            }, RespecViewerUser(characterGuid))
        end)
    end)
end

Ext.Osiris.RegisterListener("RespecCompleted", 1, "after", function(character)
    local characterGuid = Guid(character)
    if not PartialRespecEnabled then
        pendingRespec[characterGuid] = nil
        return
    end

    local state = pendingRespec[characterGuid]
    if not state then return end

    PartialRespecChannel:SendToClient({ Visible = false }, RespecViewerUser(characterGuid))

    if not state.level or not state.snapshot then
        pendingRespec[characterGuid] = nil
        PRPrint(1, "RespecCompleted: %s (full respec, no replay)", characterGuid)
        return
    end

    local targetLevel = state.level
    local snapshot = state.snapshot
    pendingRespec[characterGuid] = nil

    PRPrint(0, "RespecCompleted: replaying levels 1-%d for %s", targetLevel, characterGuid)

    local entity = Ext.Entity.Get(characterGuid)
    if not entity then
        PRWarn(0, "Replay failed: cannot resolve entity for %s", characterGuid)
        return
    end

    ApplyReplay(entity, snapshot, targetLevel, characterGuid)
end)

Ext.Osiris.RegisterListener("RespecCancelled", 1, "after", function(character)
    local characterGuid = Guid(character)
    local state = pendingRespec[characterGuid]
    if state then
        PartialRespecChannel:SendToClient({ Visible = false }, RespecViewerUser(characterGuid))
    end
    pendingRespec[characterGuid] = nil
end)

PartialRespecChannel:SetHandler(function(message, user)
    if not PartialRespecEnabled then return end

    if type(message) ~= "table" or type(message.Character) ~= "string" then
        PRWarn(0, "PR choice rejected: invalid message")
        return
    end

    local characterGuid = Guid(message.Character)
    local state = pendingRespec[characterGuid]
    if not state then
        PRWarn(1, "PR choice: no pending respec for %s", characterGuid)
        return
    end

    local reservedUser = Osi.GetReservedUserID(characterGuid)
    if type(user) ~= "number"
        or (reservedUser ~= 0 and reservedUser ~= PeerToReservedUserID(user)) then
        PRWarn(0, "PR choice rejected for %s: wrong user?", characterGuid)
        return
    end

    if message.Cancelled == true then
        PRPrint(1, "PR choice: cancel (full respec)")
        state.level = nil
        state.snapshot = nil
        return
    end

    local level = tonumber(message.Level)
    if not level or level < 1 or level > state.charLevel then
        PRWarn(0, "PR choice: invalid level %s", tostring(message.Level))
        return
    end

    local entity = Ext.Entity.Get(characterGuid)
    if not entity then
        PRWarn(0, "PR choice: cannot resolve entity for snapshot")
        return
    end

    local snapshot = PartialRespecSnapshot.SaveCharacter(
        "PartialRespec/replay_" .. characterGuid .. ".json", entity)
    state.level = level
    state.snapshot = snapshot

    PartialRespecChannel:SendToClient({
        Character = characterGuid,
        Confirmed = true,
    }, RespecViewerUser(characterGuid))

    PRPrint(0, "PR choice: keep levels 1-%d for %s", level, characterGuid)
end)
