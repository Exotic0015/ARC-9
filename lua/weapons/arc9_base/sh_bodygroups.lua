local CLIENT, type, pairs, vector_origin =
      CLIENT, type, pairs, vector_origin

local math_max =
      math.max

local ENT = FindMetaTable("Entity")
local ENT_GetTable, ENT_GetOwner, ENT_IsValid, ENT_LookupBone, ENT_ManipulateBoneScale =
      ENT.GetTable, ENT.GetOwner, ENT.IsValid, ENT.LookupBone, ENT.ManipulateBoneScale
local ENT_SetSkin, ENT_SetBodyGroups, ENT_SetBodygroup, ENT_GetBoneCount, ENT_GetNumPoseParameters =
      ENT.SetSkin, ENT.SetBodyGroups, ENT.SetBodygroup, ENT.GetBoneCount, ENT.GetNumPoseParameters
local ENT_SetPoseParameter, ENT_GetPoseParameterName =
      ENT.SetPoseParameter, ENT.GetPoseParameterName

local v1 = Vector(1, 1, 1)

local swepGetProcessedValue = SWEP.GetProcessedValue

local function hideBone(mdl, bone)
    local boneType = type(bone)
    if boneType == "table" then
        for i = 1, #bone do
            local bone2 = bone[i]
            local boneid = type(bone2) == "number" and bone2 or ENT_LookupBone(mdl, bone2)
            if boneid then
                ENT_ManipulateBoneScale(mdl, boneid, vector_origin)
            end
        end
    else
        local boneid = boneType == "number" and bone or ENT_LookupBone(mdl, bone)
        if boneid then
            ENT_ManipulateBoneScale(mdl, boneid, vector_origin)
        end
    end
end

function SWEP:DoBodygroups(wm, cm)
    wm = wm or cm

    local selfTbl = ENT_GetTable(self)
    local owner = ENT_GetOwner(self)
    local validowner = owner and ENT_IsValid(owner)

    if not wm and not validowner then return end

    local isnpc = (validowner and owner:IsNPC()) or selfTbl.ShouldLOD(self) > 0

    local mdl
    if cm then
        mdl = selfTbl.CModel[1]
    elseif wm then
        mdl = selfTbl.GetWM(self)
    else
        mdl = selfTbl.GetVM(self)
    end

    if not mdl or not ENT_IsValid(mdl) then return end

    ENT_SetSkin(mdl, selfTbl.DefaultSkin)
    ENT_SetBodyGroups(mdl, selfTbl.DefaultBodygroups or "")

    local attElements = selfTbl.GetAttachmentElements(self)
    for i = 1, #attElements do
        local ele = attElements[i]
        local bgs = ele.Bodygroups
        if bgs then
            for _, j in pairs(bgs) do
                if type(j) == "table" then
                    local id = j[1]
                    if type(id) == "number" then
                        ENT_SetBodygroup(mdl, id, j[2] or 0)
                    end
                end
            end
        end

        if ele.Skin then
            ENT_SetSkin(mdl, ele.Skin)
        end
    end

    if not isnpc then
        for i = 0, ENT_GetBoneCount(mdl) do
            ENT_ManipulateBoneScale(mdl, i, v1)
        end

        local swepDt = selfTbl.dt
        local amt = swepDt.Reloading and swepDt.LoadedRounds or self:Clip1()
        local bbg = selfTbl.BulletBodygroups

        if bbg then
            for c = 1, #bbg do
                if amt < c then
                    local bgs = bbg[c]
                    if type(bgs) == "table" then
                        ENT_SetBodygroup(mdl, bgs[1], bgs[2])
                        break
                    end
                end
            end
        end

        local stbg = selfTbl.SoundTableBodygroups
        if stbg then
            for i, k in pairs(stbg) do
                ENT_SetBodygroup(mdl, i, k)
            end
        end

        if CLIENT then
            local poseParams = selfTbl.SoundTablePoseParams
            local numPoseParams = ENT_GetNumPoseParameters(mdl) - 1
            if poseParams then
                for i = 0, numPoseParams do
                    local name = ENT_GetPoseParameterName(mdl, i)
                    ENT_SetPoseParameter(mdl, i, poseParams[name] or 0)
                end
            else
                for i = 0, numPoseParams do
                    ENT_SetPoseParameter(mdl, i, 0)
                end
            end
        end

        local bulletbones = swepGetProcessedValue(self, "BulletBones", true)
        if bulletbones then
            local loaded = swepGetProcessedValue(self, "BottomlessClip", true) and self:Ammo1() or (swepDt.LoadedRounds - (selfTbl.BulletBonesSub1 and 1 or 0))

            for i = math_max(1, loaded + 1), #bulletbones do
                hideBone(mdl, bulletbones[i])
            end
        end

        local stripperbones = swepGetProcessedValue(self, "StripperClipBones", true)
        if stripperbones then
            local loadingIntoClip = selfTbl.GetLoadingIntoClip(self)

            for i = math_max(1, loadingIntoClip + 1), #stripperbones do
                hideBone(mdl, stripperbones[i])
            end
        end
    end

    local hidebones = selfTbl.GetHiddenBones(self, wm)
    if hidebones then
        for bone, enabled in pairs(hidebones) do
            if enabled then
                local boneid = type(bone) == "number" and bone or ENT_LookupBone(mdl, bone)
                if boneid then
                    ENT_ManipulateBoneScale(mdl, boneid, vector_origin)
                end
            end
        end
    end

    local mdlTbl = ENT_GetTable(mdl)
    if mdlTbl then
        mdlTbl.CustomCamoTexture = swepGetProcessedValue(self, "CustomCamoTexture", true)
        mdlTbl.CustomCamoScale = swepGetProcessedValue(self, "CustomCamoScale", true)
        mdlTbl.CustomBlendFactor = swepGetProcessedValue(self, "CustomBlendFactor", true)
    end

    selfTbl.RunHook(self, "Hook_ModifyBodygroups", {model = mdl, elements = selfTbl.GetElements(self)})

    if CLIENT and not isnpc then
        local reloadPPs = selfTbl.GetReloadPoseParameterTable(self, wm)
        if reloadPPs then
            for pp, ppv in pairs(reloadPPs) do
                if pp and type(ppv) == "number" then
                    ENT_SetPoseParameter(mdl, pp, ppv)
                end
            end
        end
    end
end

function SWEP:GetReloadPoseParameterTable(wm)
    local selfTbl = ENT_GetTable(self)
    local index = selfTbl.GetPoseParameterIndex(self)
    local pps = {}

    if index ~= 0 then
        local pptables = swepGetProcessedValue(self, "ReloadPoseParameterTables", true)
        local pptable = pptables and pptables[index]
        if pptable then
            for pp, ppv in pairs(pptable) do
                pps[pp] = ppv
            end
        end
    end

    return pps
end

function SWEP:GetHiddenBones(wm)
    local selfTbl = ENT_GetTable(self)
    local bones = {}

    local hidefp = swepGetProcessedValue(self, "ReloadHideBonesFirstPerson", true)
    local index = selfTbl.GetHideBoneIndex(self)

    if index ~= 0 then
        local reloadhidebones = swepGetProcessedValue(self, "ReloadHideBoneTables", true)
        if reloadhidebones and ((hidefp and not wm) or (wm and selfTbl.ShouldTPIK(self))) then
            local boneList = reloadhidebones[index]
            if boneList then
                for i = 1, #boneList do
                    bones[boneList[i]] = true
                end
            end
            return selfTbl.RunHook(self, "Hook_HideBones", bones) or bones
        end
    end

    local hidebones = swepGetProcessedValue(self, "HideBones", true)
    if hidebones then
        local hide = selfTbl.CustomizeDelta > 0 or wm or hidefp

        if hide and selfTbl.dt.Reloading then
            if swepGetProcessedValue(self, "ShotgunReload", true) or (selfTbl.GetReloadFinishTime(self) - CurTime()) > 0.1 then
                hide = false
            end
        end

        if hide then
            for i = 1, #hidebones do
                bones[hidebones[i]] = true
            end
        end
    end

    return selfTbl.RunHook(self, "Hook_HideBones", bones) or bones
end
