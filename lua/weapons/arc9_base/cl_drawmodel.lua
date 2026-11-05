local LocalPlayer, CurTime, WorldToLocal, Vector, Angle, Matrix, type, tonumber, tobool, vector_origin, angle_zero =
      LocalPlayer, CurTime, WorldToLocal, Vector, Angle, Matrix, type, tonumber, tobool, vector_origin, angle_zero

local STUDIO_RENDER, STUDIO_DEPTH_MASK =
      STUDIO_RENDER, bit.bor(STUDIO_SSAODEPTHTEXTURE, STUDIO_SHADOWDEPTHTEXTURE)

local render_ComputePixelDiameterOfSphere, render_RenderFlashlights, render_UpdatePowerOfTwoTexture =
      render.ComputePixelDiameterOfSphere, render.RenderFlashlights, render.UpdatePowerOfTwoTexture
local render_MaterialOverride, render_SetBlend, render_OverrideDepthEnable =
      render.MaterialOverride, render.SetBlend, render.OverrideDepthEnable

local math_Clamp =
      math.Clamp

local cam_IgnoreZ, util_GetModelInfo, string_match, bit_band =
      cam.IgnoreZ, util.GetModelInfo, string.match, bit.band

local ENT = FindMetaTable("Entity")
local ENT_GetTable, ENT_IsValid, ENT_GetOwner, ENT_IsNPC, ENT_GetPos, ENT_GetAngles =
      ENT.GetTable, ENT.IsValid, ENT.GetOwner, ENT.IsNPC, ENT.GetPos, ENT.GetAngles
local ENT_SetPos, ENT_SetAngles, ENT_SetRenderOrigin, ENT_SetRenderAngles, ENT_SetupBones, ENT_DrawModel =
      ENT.SetPos, ENT.SetAngles, ENT.SetRenderOrigin, ENT.SetRenderAngles, ENT.SetupBones, ENT.DrawModel
local ENT_LookupBone, ENT_CopyBoneMatrix, ENT_GetModel, ENT_GetModelBounds =
      ENT.LookupBone, ENT.CopyBoneMatrix, ENT.GetModel, ENT.GetModelBounds
local ENT_SetMaterial, ENT_GetMaterials, ENT_SetSubMaterial =
      ENT.SetMaterial, ENT.GetMaterials, ENT.SetSubMaterial

local PLY = FindMetaTable("Player")
local PLY_ShouldDrawLocalPlayer =
      PLY.ShouldDrawLocalPlayer

local VMAT = FindMetaTable("VMatrix")
local VMAT_GetTranslation, VMAT_GetAngles =
      VMAT.GetTranslation, VMAT.GetAngles

local VEC = FindMetaTable("Vector")
local VEC_Add, VEC_Mul, VEC_Unpack =
      VEC.Add, VEC.Mul, VEC.Unpack

local ANG = FindMetaTable("Angle")
local ANG_Up, ANG_Right, ANG_Forward, ANG_RotateAroundAxis, ANG_Unpack =
      ANG.Up, ANG.Right, ANG.Forward, ANG.RotateAroundAxis, ANG.Unpack

local lodcvar = GetConVar("arc9_lod_distance")
local lodScale = math_Clamp(lodcvar and lodcvar:GetFloat() or 1, 0.3, 3)
if lodcvar then
    cvars.AddChangeCallback(lodcvar:GetName(), function(_, _, newval)
        lodScale = math_Clamp(tonumber(newval) or 1, 0.3, 3)
    end, "arc9_lod_distance")
end

local drawprojlightscvar = GetConVar("arc9_drawprojectedlights")
local drawprojlights = drawprojlightscvar and drawprojlightscvar:GetBool() or false
if drawprojlightscvar then
    cvars.AddChangeCallback(drawprojlightscvar:GetName(), function(_, _, newval)
        drawprojlights = tobool(newval)
    end, "arc9_drawprojectedlights")
end

local subMaterialKeys = {}
for i = 0, 31 do
    subMaterialKeys[i] = "SubMaterial" .. i
end

local emptytab = {}
local scratchBoneMatrix = Matrix()
local swepGetProcessedValue = SWEP.GetProcessedValue

local function getscopebound(self, selfTbl, scopeent)
    local vm = selfTbl.GetVM(self)
    if not scopeent or not ENT_IsValid(scopeent) or not vm or not ENT_IsValid(vm) or not selfTbl.GetInSights(self) then
        return nil
    end

    local _, uwu = ENT_GetModelBounds(scopeent)
    local localPos = WorldToLocal(ENT_GetPos(scopeent), ENT_GetAngles(scopeent), ENT_GetPos(vm), ENT_GetAngles(vm))
    local lx = VEC_Unpack(localPos)
    local ux = VEC_Unpack(uwu)
    local scopelength = lx + ux

    if scopelength < 5 or scopelength > 45 then return nil end
    if ARC9.Dev(1) then
        print("ARC9: Calculated scope length of", string_match(ENT_GetModel(scopeent), "([^/]+).mdl$"), scopelength)
    end

    return scopelength
end

function SWEP:ShouldLOD()
    local selfTbl = ENT_GetTable(self)
    if selfTbl.IsStatue then return 0 end

    local owner = ENT_GetOwner(self)
    if LocalPlayer() == owner then return -1 end

    if selfTbl.GetIsStatue(self) then
        selfTbl.IsStatue = true
        return 0
    end

    local ct = CurTime()
    if (selfTbl.NextLODCheck or 0) > ct then return selfTbl.LastLOD or 0 end
    selfTbl.NextLODCheck = ct + 0.5

    local screenSize = render_ComputePixelDiameterOfSphere(ENT_GetPos(self), 0.5) * lodScale -- same thing as in source:tm:
    local metric = screenSize > 0 and (100 / screenSize) or 0
    if not owner or not ENT_IsValid(owner) then
        metric = metric * 1.5
    end

    local result = 0
    if metric > 128 then
        result = 2
    elseif metric > 96 then
        result = 1.5
    elseif metric > 64 then
        result = 1 -- middle value for tpik lod
    end

    selfTbl.LastLOD = result
    return result
end

function SWEP:DrawCustomModel(wm, custompos, customang, flags)
    flags = flags or STUDIO_RENDER
    local isDepthPass = bit_band(flags, STUDIO_DEPTH_MASK) ~= 0

    local selfTbl = ENT_GetTable(self)
    local owner = ENT_GetOwner(self)
    local validowner = owner and ENT_IsValid(owner)

    if not wm and not validowner then return end

    local lod = selfTbl.ShouldLOD(self)
    local isnpc = (validowner and owner:IsNPC()) or lod > 0
    if not wm and isnpc then return end

    local inrt = ARC9.RTScopeRender
    if wm and inrt then return end
    if custompos then wm = true end

    local gpv = swepGetProcessedValue or selfTbl.GetProcessedValue
    local mdl = wm and (custompos and selfTbl.CModel or selfTbl.WModel) or selfTbl.VModel

    if wm then
        if not custompos and not isDepthPass and lod == 0 and mdl then
            local mdl1 = mdl[1]
            if mdl1 and ENT_IsValid(mdl1) then
                ENT_SetMaterial(mdl1, gpv(self, "Material", true))

                local matCount = selfTbl.VMMaterialAmount
                if not matCount and ENT_GetMaterials(mdl1) then
                    local minfo = util_GetModelInfo(ENT_GetModel(mdl1))
                    if minfo then
                        matCount = minfo.MaterialCount
                        selfTbl.VMMaterialAmount = matCount
                    end
                end

                for ind = 0, matCount or 31 do
                    local key = subMaterialKeys[ind] or ("SubMaterial" .. ind)
                    local val = gpv(self, key, true)
                    if val then
                        ENT_SetSubMaterial(mdl1, ind, val)
                    end
                end
            end
        end

        if lod >= 2 then
            ENT_DrawModel(self)
            return
        end
    end

    if not mdl then
        selfTbl.KillModel(self)
        selfTbl.SetupModel(self, wm, lod, custompos ~= nil and custompos ~= false)
        mdl = wm and (custompos and selfTbl.CModel or selfTbl.WModel) or selfTbl.VModel
        if not mdl then return end
    end

    if lod < 2 then
        local onground = wm and not validowner
        local hidebones = isnpc and emptytab or selfTbl.GetHiddenBones(self, wm)

        local customCamoTexture = gpv(self, "CustomCamoTexture", true)
        local customCamoScale, customBlendFactor
        if customCamoTexture then
            customCamoScale = gpv(self, "CustomCamoScale", true)
            customBlendFactor = gpv(self, "CustomBlendFactor", true)
        end

        local activeSightSlot = selfTbl.GetActiveSightSlotTable(self)
        local activesightaddress = activeSightSlot and activeSightSlot.Address
        local getpos = ENT_GetPos(self)
        local presetcam = ARC9.PresetCam
        local scopecondition = not presetcam and not inrt and not ARC9.OverDraw
        local shouldRenderFlashlights = not isDepthPass and (drawProjLightsBool or rttenabled == false)

        local getFinalAttTable = selfTbl.GetFinalAttTable
        local getAttachmentPos = selfTbl.GetAttachmentPos
        local selfRTScope = selfTbl.RTScope
        local fallbackAng = customang or angle_zero

        for i = 1, #mdl do
            local model = mdl[i]
            if not model or not ENT_IsValid(model) then
                selfTbl.KillModel(self)
                return
            end

            local modelTbl = ENT_GetTable(model)
            if modelTbl.IsAnimationProxy then continue end

            local slottbl = modelTbl.slottbl
            local atttbl = getFinalAttTable(self, slottbl)

            if not onground or modelTbl.OptimizPrevWMPos ~= getpos then
                modelTbl.OptimizPrevWMPos = onground and getpos or nil

                if inrt and atttbl.RTScope then continue end -- dont draw scope model while drawing vm from scope position

                modelTbl.hidden = false

                if modelTbl.charmparent then
                    continue
                else
                    if not isnpc and hidebones[slottbl.Bone or -1] then
                        modelTbl.hidden = true
                        continue
                    end

                    local duplicate = modelTbl.Duplicate
                    if duplicate then
                        local dupModels = slottbl.DuplicateModels
                        local duplitbl = dupModels and dupModels[duplicate]
                        local dupBone = duplitbl and duplitbl.Bone or -1

                        if not isnpc and hidebones[dupBone] then
                            modelTbl.hidden = true
                            continue
                        end
                    end

                    local apos, aang = getAttachmentPos(self, slottbl, wm, false, false, custompos, fallbackAng, duplicate)
                    ENT_SetPos(model, apos)
                    ENT_SetAngles(model, aang)
                    ENT_SetRenderOrigin(model, apos)
                    ENT_SetRenderAngles(model, aang)
                    ENT_SetupBones(model)

                    local charmmdl = modelTbl.charmmdl
                    if charmmdl and lod < 1 and not inrt then
                        local bonename = atttbl.CharmBone
                        if bonename then
                            local boneindex = ENT_LookupBone(model, bonename)
                            if boneindex then
                                ENT_CopyBoneMatrix(model, boneindex, scratchBoneMatrix)
                                local bpos = VMAT_GetTranslation(scratchBoneMatrix)
                                local bang = VMAT_GetAngles(scratchBoneMatrix)

                                if bpos and bang then
                                    local coffset = atttbl.CharmOffset or vector_origin
                                    local cangle = atttbl.CharmAngle or angle_zero

                                    local up, right, forward = ANG_Up(bang), ANG_Right(bang), ANG_Forward(bang)
                                    local cx, cy, cz = VEC_Unpack(coffset)
                                    local cp, cyaw, cr = ANG_Unpack(cangle)

                                    ANG_RotateAroundAxis(bang, up, cp)
                                    ANG_RotateAroundAxis(bang, right, cyaw)
                                    ANG_RotateAroundAxis(bang, forward, cr)

                                    VEC_Mul(forward, cy)
                                    VEC_Mul(up, cz)
                                    VEC_Mul(right, cx)
                                    VEC_Add(bpos, forward)
                                    VEC_Add(bpos, up)
                                    VEC_Add(bpos, right)

                                    ENT_SetPos(charmmdl, bpos)
                                    ENT_SetAngles(charmmdl, bang)
                                    ENT_SetupBones(charmmdl)
                                    ENT_DrawModel(charmmdl)
                                end
                            end
                        end
                    end
                end

                if scopecondition then
                    if (not wm and atttbl.RTScope) or selfRTScope then
                        if slottbl.Address == activesightaddress then
                            selfTbl.RTScopeModel = model
                            if selfRTScope then atttbl.RTScopeNew_DisableShaderEyeOffset = true end
                            selfTbl.RTScopeAtttbl = atttbl
                            if atttbl.RTScopeNew_BlurTexture then
                                modelTbl.RTScope_BlurTexture = atttbl.RTScopeNew_BlurTexture
                            end
                        end
                    elseif not wm and atttbl.RTScopeNew_BlurTexture then
                        modelTbl.RTScope_BlurTexture = atttbl.RTScopeNew_BlurTexture
                        selfTbl.RTScope_ForceBlurModel = model
                    end
                end
            end

            modelTbl.CustomCamoTexture = customCamoTexture
            modelTbl.CustomCamoScale = customCamoScale
            modelTbl.CustomBlendFactor = customBlendFactor

            if not modelTbl.NoDraw and (not modelTbl.istranslucent or presetcam or onground or isnpc) then
                ENT_DrawModel(model)

                if shouldRenderFlashlights then
                    local flashFunc = modelTbl.DrawModelFlashlightFunc
                    if not flashFunc then
                        -- caching to prevent gc spike
                        flashFunc = function() ENT_DrawModel(model) end
                        modelTbl.DrawModelFlashlightFunc = flashFunc
                    end

                    render_RenderFlashlights(flashFunc)
                end
            end

            if selfTbl.RTScopeModel == model and not modelTbl.RTScopeLength then
                modelTbl.RTScopeLength = getscopebound(self, selfTbl, model)
            end

            local drawFunc = atttbl.DrawFunc
            if drawFunc and not isDepthPass then
                drawFunc(self, model, wm)
            end
        end
    end
end

function SWEP:DrawTranslucentPass(wm) -- translucent pass, fuck source and gmod
    local selfTbl = ENT_GetTable(self)

    if not wm then
        local vmodel = selfTbl.VModel
        if vmodel then
            local updatebitch = true
            local ignoreZ = selfTbl.CustomizeDelta > 0

            for i = 1, #vmodel do
                local model = vmodel[i]
                if model and ENT_IsValid(model) then
                    local modelTbl = ENT_GetTable(model)
                    if modelTbl.istranslucent and not modelTbl.hidden then
                        if ignoreZ then cam_IgnoreZ(true) end
                        if updatebitch then render_UpdatePowerOfTwoTexture() updatebitch = false end

                        ENT_DrawModel(model)

                        local extraMat = modelTbl.translucentpassextramat
                        if extraMat then
                            render_MaterialOverride(extraMat)
                                render_SetBlend(modelTbl.translucentpassblend or 0.75)
                                    render_OverrideDepthEnable(true, true)
                                        ENT_DrawModel(model)
                                    render_OverrideDepthEnable(false, false)
                                render_SetBlend(1)
                            render_MaterialOverride()
                        end
                    end
                end
            end
        end
    else
        local wmodel = selfTbl.WModel
        if wmodel then
            -- local rtt = render.GetRenderTarget()
            -- if rtt and rtt:GetName() == "_rt_waterreflection" then return end -- mirror fix -- doesn't work for some reason

            local lp = LocalPlayer()
            if (not lp or not ENT_IsValid(lp) or not PLY_ShouldDrawLocalPlayer(lp)) and lp == ENT_GetOwner(self) then return end -- mirror fix 2

            for i = 1, #wmodel do
                local model = wmodel[i]
                if model and ENT_IsValid(model) then
                    local modelTbl = ENT_GetTable(model)
                    if modelTbl.istranslucent and not modelTbl.hidden then
                        ENT_DrawModel(model)
                    end
                end
            end
        end
    end
end

function SWEP:GetActiveSightSlotTable()
    local sight = ENT_GetTable(self).GetSight(self)
    return (sight and sight.slottbl) or emptytab
end

-- advanced camos

-- SWEP.AdvancedCamoCache = {}

-- local maxcamos = GetConVar("arc9_atts_maxcamos") -- was unused

local advCamoSlotKeys = {
    [1] = "IsAdvancedCamo1",
    [2] = "IsAdvancedCamo2",
    [3] = "IsAdvancedCamo3",
}

function SWEP:GetAdvancedCamo(att, address)
    local selfTbl = ENT_GetTable(self)
    local advCache = selfTbl.AdvancedCamoCache
    if advCache == false then return end -- disable this bitch if no super camo slots

    local key = address or att or ""
    if not advCache then
        advCache = {}
        selfTbl.AdvancedCamoCache = advCache
    else
        local cached = advCache[key]
        if cached ~= nil then
            return cached or nil
        end
    end

    local state = 1
    if key == "second" then
        state = 2
    elseif key == "third" then
        state = 3
    elseif address then
        local slott = selfTbl.LocateSlotFromAddress(self, address)
        if type(slott) == "table" and slott.ToggleNum then
            state = slott.ToggleNum
        end
    elseif key ~= "" then
        state = selfTbl.GetValue(self, key .. "_camoslot") or 1
    end

    local hasadvcamoslots = false
    local camoatt
    local stateKey = advCamoSlotKeys[state] or ("IsAdvancedCamo" .. state)
    local subSlotList = selfTbl.GetSubSlotList(self)

    for i = 1, #subSlotList do
        local slot = subSlotList[i]
        if slot.IsAdvancedCamo1 then
            hasadvcamoslots = true
        end
        if slot[stateKey] and slot.Installed then
            camoatt = selfTbl.GetFinalAttTable(self, slot)
        end
    end

    if not hasadvcamoslots then selfTbl.AdvancedCamoCache = false return end -- disable this bitch if no super camo slots

    if camoatt then
        local entry = {
            Texture = camoatt.CustomCamoTexture,
            Scale = camoatt.CustomCamoScale,
            Rotate = camoatt.CustomCamoRotate,
            BlendMode = camoatt.CustomCamoBlendMode,
            Factor = camoatt.CustomBlendFactor,
            PhongMult = camoatt.CustomCamoPhongMult,
        }
        advCache[key] = entry
        return entry
    else
        advCache[key] = false
        return nil
    end
end
