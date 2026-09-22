PartialRespecSnapshot = PartialRespecSnapshot or {}

local ComponentSpecs = {
    -- MulticlassSpellSlotOverride/field_50 are C++ maps, assigning the JSON table back throws an error
    { name = "ProgressionMeta",                key = "meta",               skip = { Owner = true, MulticlassSpellSlotOverride = true, field_50 = true } },
    { name = "ProgressionAbilityImprovements", key = "abilityImprovements" },
    { name = "ProgressionFeat",                key = "feat" },
    { name = "ProgressionSpells",              key = "spells" },
    { name = "ProgressionSkills",              key = "skills" },
    { name = "ProgressionPassives",            key = "passives" },
    { name = "ProgressionReplicatedFeat",      key = "replicatedFeat" },
    { name = "LevelUp",                        key = "levelUp" },
}

local CharacterComponentSpecs = {
    { name = "Classes",           key = "classes" },
    { name = "SpellBook",         key = "spellBook" },
    { name = "SpellBookPrepares", key = "spellBookPrepares" },
    { name = "LearnedSpells",     key = "learnedSpells" },
    { name = "CCLevelUp",         key = "ccLevelUp" },
}

--- Serializes a live component into plain data for the snapshot; restore re-applies it via Unserialize.
---@param component table|nil
---@param skip table<string, boolean>|nil
---@param label string
---@return table|nil
local function SerializeComponent(component, skip, label)
    if not component then
        return nil
    end

    local data = Ext.Types.Serialize(component)
    if type(data) ~= "table" then
        error(("Could not serialize %s: %s"):format(label, tostring(data)))
    end

    for key in pairs(skip or {}) do
        data[key] = nil
    end
    data.Entity = nil
    return data
end

--- Marks a component changed and replicates it so the engine and peers pick up restored data.
---@param entity EntityHandle
---@param componentName ExtComponentType
local function MarkComponentChanged(entity, componentName, replicate)
    entity:MarkChanged(componentName)

    if replicate == false then return end

    -- expects ExtComponentType here
    entity:Replicate(componentName)
end

--- Captures one progression entity (meta, feat, spells, skills, ...) into serializable form.
---@param entity EntityHandle
---@return table
local function SnapshotProgressionEntry(entity)
    local entry = {}

    for _, spec in ipairs(ComponentSpecs) do
        local component = entity[spec.name]
        local serialized = SerializeComponent(component, spec.skip, spec.name)
        if serialized then
            entry[spec.key] = serialized
        end
    end

    return entry
end

--- Captures the character state (components + progression buckets) before the vanilla respec wipes it.
---@param character EntityHandle
---@return table
local function SnapshotCharacter(character)
    local snapshot = {
        schemaVersion = 2,
        components = {},
        progressions = { buckets = {} },
    }

    for _, spec in ipairs(CharacterComponentSpecs) do
        snapshot.components[spec.key] = SerializeComponent(character[spec.name], nil, spec.name)
    end

    local container = character.ProgressionContainer
    if container and container.Progressions then
        for level, bucket in ipairs(container.Progressions) do
            snapshot.progressions.buckets[level] = {}

            for _, progressionEntity in ipairs(bucket) do
                table.insert(snapshot.progressions.buckets[level], SnapshotProgressionEntry(progressionEntity))
            end
        end
    end

    return snapshot
end

---@param characterRef string|EntityHandle|nil
---@return EntityHandle
local function ResolveCharacter(characterRef)
    local ref = characterRef or Osi.GetHostCharacter()
    if not characterRef then
        PRWarn(0, "PartialRespecSnapshot: no character given, falling back to host %s", tostring(ref))
    end
    local character = Ext.Entity.Get(ref)
    if not character then
        error("Could not resolve character: " .. tostring(ref))
    end
    return character
end

---@param path string
---@param snapshot table
function PartialRespecSnapshot.Save(path, snapshot)
    if PRPrinter.DebugLevel < 1 then return end

    local json = Ext.Json.Stringify(snapshot, { Beautify = true, StringifyInternalTypes = false })
    if not Ext.IO.SaveFile(path, json) then
        error("Failed to save snapshot: " .. path)
    end
    PRPrint(1, "PartialRespecSnapshot saved %s", path)
end

---@param path string
---@param characterRef string|EntityHandle|nil
---@return table snapshot
function PartialRespecSnapshot.SaveCharacter(path, characterRef)
    local character = ResolveCharacter(characterRef)
    local snapshot = SnapshotCharacter(character)
    PartialRespecSnapshot.Save(path, snapshot)
    return snapshot
end

--- Resolves the character's localized display name, or nil when unavailable.
---@param characterGuid string
---@return string|nil
local function CharacterDisplayName(characterGuid)
    local nameKey = Osi.GetDisplayName(characterGuid)
    if not nameKey then return nil end

    local handle = tostring(nameKey)
    if handle == "" then return nil end

    return Ext.Loca.GetTranslatedString(handle)
end

--- Writes a recovery dump of the state the destructive replay is about to replace.
--- Always writes, regardless of debug level
---@param character EntityHandle
---@param characterGuid string
---@param targetLevel integer
---@param pendingSnapshot table|nil
function PartialRespecSnapshot.SaveRecoveryDump(character, characterGuid, targetLevel, pendingSnapshot)
    local ok, err = pcall(function()
        local state = SnapshotCharacter(character)
        local path = ("PartialRespec/recovery_%s_%s.json"):format(
            characterGuid, tostring(Ext.Timer.ClockEpoch()))

        local dump = {
            kind = "partial_respec_recovery",
            timestamp = Ext.Timer.ClockTime(),
            characterGuid = characterGuid,
            characterName = CharacterDisplayName(characterGuid),
            currentLevel = character.EocLevel and character.EocLevel.Level,
            targetLevel = targetLevel,
            eocLevel = SerializeComponent(character.EocLevel, nil, "EocLevel"),
            components = state.components,
            progressions = state.progressions,
            pendingSnapshot = pendingSnapshot,
        }

        local json = Ext.Json.Stringify(dump, { Beautify = true, StringifyInternalTypes = false })
        if not json or not Ext.IO.SaveFile(path, json) then
            error("Could not write recovery dump " .. path)
        end

        PRPrint(1, "Recovery dump saved %s", path)
    end)

    if not ok then
        PRWarn(0, "Recovery dump failed for %s: %s", tostring(characterGuid), tostring(err))
    end
end

--- Recreates a progression entity from snapshot data, reattaching ProgressionMeta.Owner to the character.
---@param target EntityHandle
---@param entry table
---@return EntityHandle
local function CreateProgressionEntity(target, entry)
    local entity = Ext.Entity.Create()

    for _, spec in ipairs(ComponentSpecs) do
        local data = entry[spec.key]
        if data then
            local component = entity:CreateComponentImmediate(spec.name)
            Ext.Types.Unserialize(component, data)

            if spec.name == "ProgressionMeta" then
                component.Owner = target
            end

            MarkComponentChanged(entity, spec.name, false)
        end
    end

    return entity
end

--- Restores saved progression entities above level 1.
---@param character EntityHandle
---@param snapshot table
---@param restoreThroughLevel integer
---@return table plan
local function ApplyProgressions(character, snapshot, restoreThroughLevel)
    if snapshot.schemaVersion ~= 2 then
        error("Snapshot is from an incompatible build; start a new respec")
    end

    local snapshotBuckets = snapshot.progressions and snapshot.progressions.buckets or {}
    local bucketCount = restoreThroughLevel or #snapshotBuckets
    local plan = { newBuckets = 0, newEntries = 0 }

    if not character.ProgressionContainer then
        character:CreateComponentImmediate("ProgressionContainer")
    end

    -- Level 1 is handled by the vanilla respec.
    for level = 2, bucketCount do
        local bucket = snapshotBuckets[level]
        if not bucket then
            error(("Snapshot has no progression bucket for level %d"):format(level))
        end

        plan.newBuckets = plan.newBuckets + 1
        for _, entry in ipairs(bucket) do
            CreateProgressionEntity(character, entry)
            plan.newEntries = plan.newEntries + 1
        end
    end

    return plan
end

--- Restores snapshot character components (classes, spellbook, level-up data) onto the character.
---@param character EntityHandle
---@param snapshot table
local function ApplyCharacterComponents(character, snapshot)
    for _, spec in ipairs(CharacterComponentSpecs) do
        local data = snapshot.components and snapshot.components[spec.key]
        if data then
            local component = character[spec.name] or character:CreateComponentImmediate(spec.name)
            Ext.Types.Unserialize(component, data)
            MarkComponentChanged(character, spec.name)
        end
    end
end

--- Entry point: replays the snapshot onto a character through the chosen cutoff level.
--- Returns the progressions plan (newBuckets, newEntries) for caller logging.
---@param characterRef string|EntityHandle|nil
---@param snapshot table
---@param restoreThroughLevel integer
---@return table plan
function PartialRespecSnapshot.ApplySnapshotToCharacter(characterRef, snapshot, restoreThroughLevel)
    local character = ResolveCharacter(characterRef)
    local plan = ApplyProgressions(character, snapshot, restoreThroughLevel)
    ApplyCharacterComponents(character, snapshot)
    return plan
end

return PartialRespecSnapshot
