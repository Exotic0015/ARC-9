local type, tostring, tonumber, next, pairs, ipairs, CurTime, isfunction, MOVETYPE_NOCLIP, getmetatable =
      type, tostring, tonumber, next, pairs, ipairs, CurTime, isfunction, MOVETYPE_NOCLIP, getmetatable

local engine_TickCount, hook_Run =
      engine.TickCount, hook.Run

local math_min, math_max, math_Clamp =
      math.min, math.max, math.Clamp

local table_Copy, table_Merge =
      table.Copy, table.Merge

local ENT = FindMetaTable("Entity")
local ENT_GetTable, ENT_OnGround, ENT_GetMoveType, ENT_GetAbsVelocity, ENT_IsValid, ENT_GetOwner =
      ENT.GetTable, ENT.OnGround, ENT.GetMoveType, ENT.GetAbsVelocity, ENT.IsValid, ENT.GetOwner

local PLY = FindMetaTable("Player")
local PLY_IsSprinting, PLY_Crouching, PLY_GetWalkSpeed =
      PLY.IsSprinting, PLY.Crouching, PLY.GetWalkSpeed

local WPN = FindMetaTable("Weapon")
local WPN_Clip1, WPN_Clip2, WPN_GetNextPrimaryFire =
      WPN.Clip1, WPN.Clip2, WPN.GetNextPrimaryFire

local VEC = FindMetaTable("Vector")
local VEC_Length2D =
      VEC.Length2D

--[[ Class Cache ]]--

SWEP.StatCache = {}
SWEP.PV_CacheLong = {} -- ProcessedStatCache
SWEP.PV_Cache = {} -- ProcessedDynamicStatCache

SWEP.AttTableCache = {}
SWEP.GetSubSlotListCache = nil
SWEP.CacheLastInvalidation = 0

SWEP.HookCache = {}
SWEP.AffectorsCache = nil
SWEP.HasNoAffectors = {}

SWEP.ExcludeFromRawStats = {
    ["PrintName"] = true,
}

SWEP.DynamicConditions = { -- Never cache these conditions because they will always change
    ["Recoil"] = true,
}

SWEP.PV_Tick = 0
SWEP.PV_Move = 0
SWEP.PV_Shooting = 0
SWEP.PV_Melee = 0

SWEP.WantToInvalidateCache = false

local cvarArc9Truenames = GetConVar("arc9_truenames")
local arc9Truenames = cvarArc9Truenames:GetBool()
cvars.AddChangeCallback(cvarArc9Truenames:GetName(), function(_, _, newval)
    arc9Truenames = tobool(newval)
end, "arc9_truenames")

--[[ Variables ]]--

local quickmodifiers = {
    ["DamageMin"] = GetConVar("arc9_mod_damage"),
    ["DamageMax"] = GetConVar("arc9_mod_damage"),
    -- ["SweetSpotDamage"] = GetConVar("arc9_mod_damage"),
    ["Spread"] = GetConVar("arc9_mod_spread"),
    ["DispersionSpread"] = GetConVar("arc9_mod_dispersionspread"),
    ["Recoil"] = GetConVar("arc9_mod_recoil"),
    ["VisualRecoil"] = GetConVar("arc9_mod_visualrecoil"),
    ["AimDownSightsTime"] = GetConVar("arc9_mod_adstime"),
    ["SprintToFireTime"] = GetConVar("arc9_mod_sprinttime"),
    ["DamageRand"] = GetConVar("arc9_mod_damagerand"),
    ["PhysBulletMuzzleVelocity"] = GetConVar("arc9_mod_muzzlevelocity"),
    ["RPM"] = GetConVar("arc9_mod_rpm"),
    ["HeadshotDamage"] = GetConVar("arc9_mod_headshotdamage"),
    ["MalfunctionMeanShotsToFail"] = GetConVar("arc9_mod_malfunction")
}
local quickmodifiers_values = {}

for k, cv in pairs(quickmodifiers) do
    local initVal = cv:GetFloat()
    local shouldInvert = k == "MalfunctionMeanShotsToFail"

    quickmodifiers_values[k] = shouldInvert and (1 / math_max(0.00000001, initVal)) or initVal

    cvars.AddChangeCallback(cv:GetName(), function(_, _, newval)
        local v = tonumber(newval) or 1
        quickmodifiers_values[k] = shouldInvert and (1 / math_max(0.00000001, v)) or v
    end, "arc9_qmods_" .. k)
end

local singleplayer = game.SinglePlayer()
local ARC9HeatCapacityGPVOverflow = false



--[[ Helpers ]]--

local Lerp = function(a, v1, v2)
    return v1 + (a * (v2 - v1))
end



--[[ Class Methods ]]--

function SWEP:ClearLongCache() -- would rename this to "ClearProcessedCache" or smth i dunno
    local selfTbl = ENT_GetTable(self)
    selfTbl.PV_Cache = {}
    selfTbl.PV_CacheLong = {}
end


function SWEP:InvalidateCache()
    if singleplayer and getmetatable(ENT_GetOwner(self)) == PLY then
        self:CallOnClient("InvalidateCache")
    end

    self.WantToInvalidateCache = true
end


function SWEP:DoInvalidateCache() -- todo: run this while supermods are being applied so the PV_CacheLong updates properly now
    local selfTbl = ENT_GetTable(self)
    selfTbl.WantToInvalidateCache = false

    selfTbl.StatCache = {}
    selfTbl.PV_Cache = {}
    selfTbl.PV_CacheLong = {}

    selfTbl.AttTableCache = {}

    selfTbl.HookCache = {}
    selfTbl.AttPosCache = {}
    selfTbl.AdvancedCamoCache = nil
    selfTbl.AffectorsCache = nil
    selfTbl.ElementsCache = nil
    selfTbl.ElementTablesCache = nil
    selfTbl.RecoilPatternCache = {}
    selfTbl.CachedToggleAttsStatus = nil
    -- selfTbl.ScrollLevels = {} -- moved to PostModify
    selfTbl.HasNoAffectors = {}
    selfTbl.ListOfToggleableAttSlots = nil

    selfTbl.GetSubSlotListCache = nil
    selfTbl.CacheLastInvalidation = CurTime()

    selfTbl.SetBaseSettings(self)
end


function SWEP:GetFinalAttTableFromAddress(address)
    return self:GetFinalAttTable(self:LocateSlotFromAddress(address))
end


local function getFinalAttTable(self, slot, selfTbl)
    if not slot or not slot.Installed then return {} end
    selfTbl = selfTbl or ENT_GetTable(self)

    local attTableCache = selfTbl.AttTableCache
    local cache = attTableCache[slot]
    if cache then
        local result = table_Copy(cache) -- Create a copy so we don't mutate the cache
        local toggleStats = result.ToggleStats
        if toggleStats then
            table_Merge(result, toggleStats[slot.ToggleNum or 1] or {})
        end
        return result
    end

    local installed = slot.Installed
    local atttbl = table_Copy(ARC9.GetAttTable(installed) or {})

    local overrides = selfTbl.AttachmentTableOverrides
    if overrides and overrides[installed] then
        atttbl = table_Merge(atttbl, overrides[installed])
    end

    attTableCache[slot] = atttbl

    local result = table_Copy(atttbl) -- Create a copy of the new cache
    local toggleStats = result.ToggleStats
    if toggleStats then
        table_Merge(result, toggleStats[slot.ToggleNum or 1] or {})
    end

    return result
end

function SWEP:GetFinalAttTable(slot)
    return getFinalAttTable(self, slot, ENT_GetTable(self))
end


local getAllAffectors
do
    local cvarArcModifiers = GetConVar("arc9_modifiers")
    local arcModifiers = cvarArcModifiers:GetString()
    cvars.AddChangeCallback(cvarArcModifiers:GetName(), function(_, _, newval)
        arcModifiers = tostring(newval)
    end, "arc9_modifiers")

    getAllAffectors = function(self, selfTbl)
        selfTbl = selfTbl or ENT_GetTable(self)
        if selfTbl.AffectorsCache then return selfTbl.AffectorsCache end

        local aff = {selfTbl}

        local affLength = 1

        if not ARC9.OverrunSights then
            ARC9.OverrunSights = true
            local originalSightTable = selfTbl.GetSight(self).OriginalSightTable

            if originalSightTable then
                affLength = affLength + 1
                aff[affLength] = originalSightTable
            end

            ARC9.OverrunSights = false
        end

        local subSlotList = selfTbl.GetSubSlotList(self)
        local subSlotListLength = #subSlotList

        for i = 1, subSlotListLength do
            local atttbl = getFinalAttTable(self, subSlotList[i], selfTbl)

            if atttbl then
                affLength = affLength + 1
                aff[affLength] = atttbl
            end
        end

        local config = string.Split(arcModifiers, "\\n")
        local configLength = #config
        local c4 = {}

        for i = 1, configLength do
            local swig = string.Split(config[i], "\\t")
            local swig1, swig2 = swig[1], swig[2]
            -- local c2 = c4[swig[1]]
            local swig2Num = tonumber(swig2)

            if swig2Num then
                c4[swig1] = swig2Num
            elseif swig2 == "true" or swig2 == "false" then
                c4[swig1] = swig2 == "true"
            else
                c4[swig1] = swig2
            end
        end

        affLength = affLength + 1
        aff[affLength] = c4

        if not ARC9.OverrunFiremodes then
            ARC9.OverrunFiremodes = true
            affLength = affLength + 1
            aff[affLength] = selfTbl.GetCurrentFiremodeTable(self)
            ARC9.OverrunFiremodes = false
        end

        if not ARC9.OverrunAttElements then
            ARC9.OverrunAttElements = true

            local eles = selfTbl.GetAttachmentElements(self)

            for _, eletable in ipairs(eles) do
                if eletable then
                    affLength = affLength + 1
                    aff[affLength] = eletable
                end
            end

            ARC9.OverrunAttElements = false
        end

        selfTbl.AffectorsCache = aff

        return aff
    end
end

function SWEP:GetAllAffectors()
    return getAllAffectors(self, ENT_GetTable(self))
end


local function runHook(self, val, data, selfTbl)
    selfTbl = selfTbl or ENT_GetTable(self)
    local any = false
    local hookCacheTbl = selfTbl.HookCache
    local hookCache = hookCacheTbl[val]

    if hookCache then
        for i = 1, #hookCache do
            local d = hookCache[i](self, data)

            if d ~= nil then
                data = d
            end

            any = true
        end

        local data2 = hook_Run("ARC9_" .. val, self, data)
        if data2 ~= nil then
            data = data2
        end

        return data, any
    end

    local cacheLen = 0
    local newCache = {}
    local allAffectors = getAllAffectors(self, selfTbl)
    local affectorsCount = #allAffectors

    for i = 1, affectorsCount do
        local elem = allAffectors[i]
        local mod = elem[val]

        if mod and isfunction(mod) then
            any = true
            cacheLen = cacheLen + 1
            newCache[cacheLen] = mod

            local d = mod(self, data)
            if d ~= nil then
                data = d
            end
        end
    end

    hookCacheTbl[val] = newCache
    local data2 = hook_Run("ARC9_" .. val, self, data)
    if data2 ~= nil then
        data = data2
    end

    return data, any
end

function SWEP:RunHook(val, data)
    return runHook(self, val, data)
end


local function getValue(self, selfTbl, val, base, condition, amount, donotcache)
    selfTbl = selfTbl or ENT_GetTable(self)
    condition = condition or ""
    amount = amount or 1

    local stat = base
    if stat == nil then
        stat = selfTbl[val]
    end

    local valContCondition = val .. condition
    local qmod = condition == "" and quickmodifiers_values[val]
    local hasNoAffectors = selfTbl.HasNoAffectors

    if hasNoAffectors[valContCondition] then
        if qmod and type(stat) == "number" then
            stat = stat * qmod
        end

        return stat
    end

    local canCache = not donotcache and not selfTbl.DynamicConditions[condition]
    local statCache = selfTbl.StatCache
    local baseContValContCondition = base and (tostring(base) .. valContCondition) or valContCondition

    if canCache then
        local cache = statCache[baseContValContCondition]

        if cache ~= nil then
            local hookstat = runHook(self, val .. "Hook" .. condition, cache) -- whats the point of this though
            -- its not being cached so you want it to be dynamic
            -- but its not gonna be dynamic since you have cache inside GetProcessedValue too, which lasts like 60 seconds or whatever, i forgor
            -- + affectors are getting cached too
            -- im leaving this as it is temporarily
            if hookstat ~= nil then cache = hookstat end

            if qmod and type(cache) == "number" then
                cache = cache * qmod
            end

            return cache
        end
    end

    if type(stat) == "table" then stat.BaseClass = nil end

    local unaffected = true
    local priority = 0
    local allAffectors = getAllAffectors(self, selfTbl)
    local affectorsCount = #allAffectors

    if not selfTbl.ExcludeFromRawStats[val] then
        local prioKey = valContCondition .. "_Priority"
        for i = 1, affectorsCount do
            local elem = allAffectors[i]
            if elem == nil then continue end

            local mod = elem[valContCondition]
            if mod == nil then continue end

            local att_priority = elem[prioKey] or 1
            if att_priority >= priority then
                -- if this is the base weapon and we passed a modified base, scale relative to base stat
                if i == 1 and base ~= nil and condition ~= "" and type(stat) == "number" and type(mod) == "number" then
                    local baseVal = elem[val]
                    if type(baseVal) == "number" and baseVal ~= 0 then
                        stat = base * (mod / baseVal)
                    else
                        stat = mod
                    end
                else
                    stat = mod
                end
                priority = att_priority
                unaffected = false
            end
        end
    end

    local overrideKey = val .. "Override" .. condition
    local overridePrioKey = overrideKey .. "_Priority"
    for i = 1, affectorsCount do
        local elem = allAffectors[i]
        local mod = elem[overrideKey]

        if mod ~= nil then
            local att_priority = elem[overridePrioKey] or 1
            if att_priority >= priority then
                stat = mod
                priority = att_priority
                unaffected = false
            end
        end
    end

    local statType = type(stat)
    if statType == "number" then
        local addKey = val .. "Add" .. condition
        for i = 1, affectorsCount do
            local mod = allAffectors[i][addKey]
            if type(mod) == "number" then
                stat = stat + mod * amount
                unaffected = false
            end
        end

        local multKey = val .. "Mult" .. condition
        for i = 1, affectorsCount do
            local mod = allAffectors[i][multKey]
            if type(mod) == "number" then
                stat = stat * (amount == 1 and mod or (1 + (mod - 1) * amount))
                unaffected = false
            end
        end
    elseif statType == "table" then
        stat.BaseClass = nil -- ???
    end

    local preHookStat = stat
    local hookstat, any = runHook(self, val .. "Hook" .. condition, stat)
    if hookstat ~= nil then stat = hookstat end
    if any then unaffected = false end

    if canCache then
        hasNoAffectors[valContCondition] = unaffected
        statCache[baseContValContCondition] = preHookStat
    end

    if qmod and type(stat) == "number" then
        stat = stat * qmod
    end

    return stat
end

function SWEP:GetValue(val, base, condition, amount, donotcache)
    return getValue(self, nil, val, base, condition, amount, donotcache)
end

function SWEP:GetProcessedValue(val, isstatic, base)
    local selfTbl = ENT_GetTable(self)
    local swepDt = selfTbl.dt

    if val == "Malfunction" then
        if swepDt.Jammed then return true end
    elseif val == "Overheat" then
        if swepDt.HeatLockout then return true end
    end

    local processedValueName = base ~= nil and (val .. tostring(base)) or val
    local isStaticCacheable = isstatic and not selfTbl.DynamicConditions[val]
    local pvCache = selfTbl.PV_Cache
    local ticks

    if isStaticCacheable then
        local cache = selfTbl.PV_CacheLong[processedValueName]
        if cache ~= nil then return cache end
    else
        ticks = engine_TickCount()

        if selfTbl.PV_Tick >= ticks then
            local tempcache = pvCache[processedValueName]
            if tempcache ~= nil then return tempcache end
        else
            if next(pvCache) ~= nil then
                selfTbl.PV_Cache = {}
                pvCache = selfTbl.PV_Cache
            end
            selfTbl.PV_Move = nil
            selfTbl.PV_Tick = ticks
        end
    end

    local stat = getValue(self, selfTbl, val, base)

    local owner = ENT_GetOwner(self)
    local isOwnerValid = owner and ENT_IsValid(owner)
    local isOwnerPlayer = isOwnerValid and getmetatable(owner) == PLY
    local isOwnerNPC = isOwnerValid and not isOwnerPlayer and owner:IsNPC()

    if isOwnerNPC then
        stat = getValue(self, selfTbl, val, stat, "NPC", nil, isstatic) -- isstatic to avoid caching unnecessary data, since the processed value will be cached itself
    end

    if arc9Truenames then
        stat = getValue(self, selfTbl, val, stat, "True", nil, isstatic)
    end

    local hasNoAffectors = selfTbl.HasNoAffectors
    local isUBGL = swepDt.UBGL

    if not isUBGL then
        if not hasNoAffectors[val .. "Silenced"] and getValue(self, selfTbl, "Silencer") then
            stat = getValue(self, selfTbl, val, stat, "Silenced", nil, isstatic)
        end
    else
        stat = getValue(self, selfTbl, val, stat, "UBGL", nil, isstatic)
    end

    if not isstatic and not isOwnerNPC then -- nobody is gonna fucking notice that npcs process these stats either way
        local curTime = CurTime()

        if not hasNoAffectors[val .. "FirstShot"] and swepDt.BurstCount == 0 then
            stat = getValue(self, selfTbl, val, stat, "FirstShot")
        end

        local evenShotKey = val .. "EvenShot"
        local oddShotKey = val .. "OddShot"
        if not hasNoAffectors[evenShotKey] or not hasNoAffectors[oddShotKey] then
            if swepDt.NthShot % 2 == 0 then
                if not hasNoAffectors[evenShotKey] then
                    stat = getValue(self, selfTbl, val, stat, "EvenShot")
                end
            elseif not hasNoAffectors[oddShotKey] then
                stat = getValue(self, selfTbl, val, stat, "OddShot")
            end
        end

        if not hasNoAffectors[val .. "Empty"] and WPN_Clip1(self) == 0 then
            stat = getValue(self, selfTbl, val, stat, "Empty")
        end

        if isUBGL and not hasNoAffectors[val .. "EmptyUBGL"] and WPN_Clip2(self) == 0 then
            stat = getValue(self, selfTbl, val, stat, "EmptyUBGL")
        end

        if not hasNoAffectors[val .. "Reload"] and swepDt.Reloading then
            stat = getValue(self, selfTbl, val, stat, "Reload")
        end

        local evenReloadKey = val .. "EvenReload"
        local oddReloadKey = val .. "OddReload"
        if not hasNoAffectors[evenReloadKey] or not hasNoAffectors[oddReloadKey] then
            if swepDt.NthReload % 2 == 0 then
                if not hasNoAffectors[evenReloadKey] then
                    stat = getValue(self, selfTbl, val, stat, "EvenReload")
                end
            elseif not hasNoAffectors[oddReloadKey] then
                stat = getValue(self, selfTbl, val, stat, "OddReload")
            end
        end

        if not hasNoAffectors[val .. "Bipod"] and swepDt.Bipod then
            stat = getValue(self, selfTbl, val, stat, "Bipod")
        end

        local sightedKey = val .. "Sighted"
        local sightsKey = val .. "Sights"
        local hipfireKey = val .. "HipFire"

        if hasNoAffectors[sightedKey] == nil then getValue(self, selfTbl, val, stat, "Sighted") end
        if hasNoAffectors[sightsKey] == nil then getValue(self, selfTbl, val, stat, "Sights") end
        if hasNoAffectors[hipfireKey] == nil then getValue(self, selfTbl, val, stat, "HipFire") end

        local noSighted = hasNoAffectors[sightedKey]
        if not hasNoAffectors[sightsKey] or not hasNoAffectors[hipfireKey] or not noSighted then
            local sightAmount = swepDt.SightAmount

            if type(stat) == "number" then
                if sightAmount >= 1 and not noSighted then
                    stat = getValue(self, selfTbl, val, stat, "Sighted")
                else
                    local hipfire = getValue(self, selfTbl, val, stat, "HipFire")
                    local sights = getValue(self, selfTbl, val, stat, "Sights")

                    if type(hipfire) == "number" and type(sights) == "number" then
                        stat = Lerp(sightAmount, hipfire, sights)
                    end
                end
            else
                if sightAmount >= 1 then
                    if not noSighted then
                        stat = getValue(self, selfTbl, val, stat, "Sighted")
                    else
                        stat = getValue(self, selfTbl, val, stat, "Sights")
                    end
                else
                    stat = getValue(self, selfTbl, val, stat, "HipFire")
                end
            end
        end

        if not ARC9HeatCapacityGPVOverflow and (not hasNoAffectors[val .. "Hot"] or not hasNoAffectors[val .. "Heated"]) then
            local heatAmount = swepDt.HeatAmount

            if heatAmount > 0 and base ~= "HeatCapacity" then
                ARC9HeatCapacityGPVOverflow = true
                local cap = selfTbl.GetProcessedValue(self, "HeatCapacity")
                ARC9HeatCapacityGPVOverflow = false

                local hot = getValue(self, selfTbl, val, stat, "Hot")

                if type(stat) == "number" then
                    if heatAmount >= cap then
                        local heated = getValue(self, selfTbl, val, stat, "Heated")
                        stat = (heated == stat and hot ~= stat) and hot or heated
                    else
                        stat = Lerp(heatAmount / cap, stat, hot)
                    end
                else
                    if heatAmount >= cap then
                        local heated = getValue(self, selfTbl, val, stat, "Heated")
                        stat = (heated == stat and hot ~= stat) and hot or heated
                    else
                        stat = hot
                    end
                end
            end
        end

        if not hasNoAffectors[val .. "Melee"] then
            local lastMeleeTime = swepDt.LastMeleeTime
            if lastMeleeTime < curTime then
                local pft = curTime - lastMeleeTime
                local d = 1 - math_Clamp(pft / (getValue(self, selfTbl, "PreBashTime") + getValue(self, selfTbl, "PostBashTime")), 0, 1)

                if type(stat) == "number" then
                    stat = Lerp(d, stat, getValue(self, selfTbl, val, stat, "Melee"))
                elseif d > 0 then
                    stat = getValue(self, selfTbl, val, stat, "Melee")
                end
            end
        end

        if not hasNoAffectors[val .. "Shooting"] then
            local nextPrimaryFire = WPN_GetNextPrimaryFire(self) + 0.1

            if nextPrimaryFire > curTime then
                local d = math_Clamp((nextPrimaryFire - curTime) * 10, 0, 1)

                if type(stat) == "number" then
                    stat = Lerp(d, stat, getValue(self, selfTbl, val, stat, "Shooting"))
                elseif d > 0 then
                    stat = getValue(self, selfTbl, val, stat, "Shooting")
                end
            end
        end

        if val ~= "RecoilModifierCap" and not hasNoAffectors[val .. "Recoil"] then
            local recoilAmount = swepDt.RecoilAmount
            if recoilAmount > 0 then
                recoilAmount = math_min(selfTbl.GetProcessedValue(self, "RecoilModifierCap"), recoilAmount)
                if recoilAmount > 0 then
                    stat = getValue(self, selfTbl, val, stat, "Recoil", recoilAmount)
                end
            end
        end

        if isOwnerValid then
            if not hasNoAffectors[val .. "Sprint"] or not hasNoAffectors[val .. "Crouch"] or not hasNoAffectors[val .. "MidAir"] then
                if ENT_OnGround(owner) and ENT_GetMoveType(owner) ~= MOVETYPE_NOCLIP then
                    if not hasNoAffectors[val .. "Sprint"] and PLY_IsSprinting(owner) and not selfTbl.StillWaiting(self) then
                        stat = getValue(self, selfTbl, val, stat, "Sprint")
                    elseif not hasNoAffectors[val .. "Crouch"] and PLY_Crouching(owner) then
                        stat = getValue(self, selfTbl, val, stat, "Crouch")
                    end
                elseif not hasNoAffectors[val .. "MidAir"] then
                    stat = getValue(self, selfTbl, val, stat, "MidAir")
                end
            end

            if not hasNoAffectors[val .. "Move"] then
                local spd = selfTbl.PV_Move
                if not spd then
                    local maxspd = getmetatable(owner) == PLY and PLY_GetWalkSpeed(owner) or 250
                    spd = math_min(VEC_Length2D(ENT_GetAbsVelocity(owner)), maxspd) / maxspd
                    selfTbl.PV_Move = spd
                end

                if type(stat) == "number" then
                    stat = Lerp(spd, stat, getValue(self, selfTbl, val, stat, "Move"))
                elseif spd > 0 then
                    stat = getValue(self, selfTbl, val, stat, "Move")
                end
            end
        end

        if not hasNoAffectors[val .. "Toss"] and swepDt.GrenadeTossing then
            stat = getValue(self, selfTbl, val, stat, "Toss")
        end
    end

    if isStaticCacheable then
        selfTbl.PV_CacheLong[processedValueName] = stat
    else
        pvCache[processedValueName] = stat
        if selfTbl.PV_Tick < ticks then
            selfTbl.PV_Tick = ticks + (isOwnerNPC and 16 or 0)
        end
    end

    return stat
end
