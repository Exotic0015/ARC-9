local WorldToLocal, LocalToWorld, ipairs, SafeRemoveEntity, ClientsideModel, Vector, Angle, Matrix, vector_origin, angle_zero =
      WorldToLocal, LocalToWorld, ipairs, SafeRemoveEntity, ClientsideModel, Vector, Angle, Matrix, vector_origin, angle_zero

local ENT = FindMetaTable("Entity")
local ENT_GetTable, ENT_IsValid, ENT_GetOwner, ENT_SetupBones, ENT_SetPos, ENT_SetAngles, ENT_SetNoDraw =
      ENT.GetTable, ENT.IsValid, ENT.GetOwner, ENT.SetupBones, ENT.SetPos, ENT.SetAngles, ENT.SetNoDraw
local ENT_LookupSequence, ENT_ResetSequence, ENT_SetPoseParameter, ENT_InvalidateBoneCache, ENT_LookupBone =
      ENT.LookupSequence, ENT.ResetSequence, ENT.SetPoseParameter, ENT.InvalidateBoneCache, ENT.LookupBone
local ENT_GetBoneMatrix, ENT_GetAngles, ENT_GetPos =
      ENT.GetBoneMatrix, ENT.GetAngles, ENT.GetPos

local VMAT = FindMetaTable("VMatrix")
local VMAT_GetTranslation, VMAT_GetAngles =
      VMAT.GetTranslation, VMAT.GetAngles

local ANG = FindMetaTable("Angle")
local ANG_Set, ANG_Forward, ANG_Right, ANG_Up, ANG_RotateAroundAxis =
      ANG.Set, ANG.Forward, ANG.Right, ANG.Up, ANG.RotateAroundAxis

SWEP.ModelVersion = 0

SWEP.AttPosCache = {}

local swepGetProcessedValue = SWEP.GetProcessedValue

function SWEP:GetAttachmentPos(slottbl, wm, idle, nomodeloffset, custompos, customang, dupli)
    local selfTbl = ENT_GetTable(self)
    dupli = dupli or 0
    idle = idle or false
    local parentmdl = nil
    if custompos then wm = true end

    if wm then
        if slottbl.WMBase then
            parentmdl = ENT_GetOwner(self)
            if not parentmdl or not ENT_IsValid(parentmdl) then parentmdl = self end
            if custompos then parentmdl = nil end
        else
            if custompos then
                parentmdl = selfTbl.CModel[1]
                if parentmdl then ENT_SetupBones(parentmdl) end
            else
                parentmdl = selfTbl.WModel and selfTbl.WModel[1]
            end
        end
    else
        parentmdl = selfTbl.GetVM(self)
    end

    if idle then
        parentmdl = ClientsideModel(selfTbl.ViewModel)
        ENT_SetPos(parentmdl, vector_origin)
        ENT_SetAngles(parentmdl, angle_zero)
        ENT_SetNoDraw(parentmdl, true)

        local anim = selfTbl.TranslateAnimation(self, "idle")
        local ae = selfTbl.GetAnimationEntry(self, anim)
        local seq = ENT_LookupSequence(parentmdl, selfTbl.RandomChoice(self, ae.Source))

        ENT_ResetSequence(parentmdl, seq)
        ENT_SetPoseParameter(parentmdl, "sights", 1)

        ENT_SetupBones(parentmdl)
        ENT_InvalidateBoneCache(parentmdl)

        table.insert(ARC9.CSModelPile, {Model = parentmdl, Weapon = self, Version = self.ModelVersion})
    end

    local bone = slottbl.Bone
    local atttbl = {}

    if slottbl.WMBase then
        bone = (selfTbl.ShouldTPIK(self) and selfTbl.TPIKParentToSpine4) and "ValveBiped.Bip01_Spine4" or "ValveBiped.Bip01_R_Hand"
    end

    if slottbl.Installed then
        atttbl = selfTbl.GetFinalAttTable(self, slottbl)
    end

    local icon_offset = slottbl.Icon_Offset or vector_origin

    local offset_pos = slottbl.Pos or vector_origin
    local offset_ang = slottbl.Ang or angle_zero
    local bpos, bang = vector_origin, angle_zero

    if dupli > 0 then
        local dupli_tbl = slottbl.DuplicateModels[dupli]
        if dupli_tbl then
            offset_pos = dupli_tbl.Pos or offset_pos
            offset_ang = dupli_tbl.Ang or offset_ang
            bone = dupli_tbl.Bone or bone
        end
    end

    if parentmdl and bone then
        local boneindex = ENT_LookupBone(parentmdl, bone)

        if not boneindex then return vector_origin, angle_zero, vector_origin end

        if parentmdl == ENT_GetOwner(self) then
            ENT_SetupBones(parentmdl)
            ENT_InvalidateBoneCache(parentmdl)
        end

        local bonemat = ENT_GetBoneMatrix(parentmdl, boneindex)
        if bonemat then
            bpos = VMAT_GetTranslation(bonemat)
            bang = VMAT_GetAngles(bonemat)
        end

        if not bang or not bpos then
            bang = ENT_GetAngles(self)
            bpos = ENT_GetPos(self)
        end
    elseif custompos then
        bpos = custompos
        bang = customang or angle_zero
    end

    local cust = selfTbl.GetCustomize(self)
    local possiblecache = selfTbl.AttPosCache[slottbl.Address] -- att pos cache
    if not cust and possiblecache then
        local qpos, qang = LocalToWorld(possiblecache[1], possiblecache[2], bpos, bang)
        return qpos, qang, possiblecache[3]
    end

    if slottbl.OriginalAddress then
        local eles = selfTbl.GetAttachmentElements(self)

        for _, ele in ipairs(eles) do
            local mods = ele.AttPosMods
            if mods then
                local mod_data = mods[slottbl.OriginalAddress]
                if mod_data then
                    offset_pos = mod_data.Pos or offset_pos
                    offset_ang = mod_data.Ang or offset_ang
                    icon_offset = mod_data.Icon_Offset or icon_offset
                end
            end
        end
    end

    if wm then
        offset_pos = offset_pos * (selfTbl.WorldModelOffset.Scale or 1)
    end

    local apos, aang = LocalToWorld(Vector(offset_pos[1], -offset_pos[2], offset_pos[3]), bang, bpos, bang)

    if not nomodeloffset then
        offset_ang = offset_ang + (atttbl.ModelAngleOffset or angle_zero)
    end

    ANG_Set(aang, bang)

    local forward = ANG_Forward(aang)
    local right = ANG_Right(aang)
    local up = ANG_Up(aang)

    ANG_RotateAroundAxis(aang, forward, offset_ang.r)
    ANG_RotateAroundAxis(aang, right, offset_ang.p)
    ANG_RotateAroundAxis(aang, up, offset_ang.y)

    if not nomodeloffset and atttbl.ModelOffset then
        local moffset = atttbl.ModelOffset * (slottbl.Scale or 1)
        if wm then
            moffset = moffset * (selfTbl.WorldModelOffset.Scale or 1)
        end

        apos = apos + ANG_Forward(aang) * moffset.x + ANG_Right(aang) * moffset.y + ANG_Up(aang) * moffset.z
    end

    if idle then SafeRemoveEntity(parentmdl) end

    selfTbl.AttTempDataTbl = selfTbl.AttTempDataTbl or {}
    local data = selfTbl.AttTempDataTbl
    data.pos = apos
    data.ang = aang
    data.atttbl = atttbl
    data.slottbl = slottbl

    data = selfTbl.RunHook(self, "Hook_GetAttachmentPos", data) or data

    apos = data.pos or apos
    aang = data.ang or aang

    if slottbl.Address and not cust then -- att pos cache
        local ypos, yang = WorldToLocal(apos, aang, bpos, bang)
        selfTbl.AttPosCache[slottbl.Address] = { ypos, yang, icon_offset }
    end

    return apos, aang, icon_offset
end

function SWEP:CreateAttachmentModel(wm, atttbl, slottbl, ignorescale, cm, dupli, customCamoTexture, customCamoScale, customBlendFactor)
    ignorescale = ignorescale or false

    local model = atttbl.Model

    if wm and atttbl.WorldModel then
        model = atttbl.WorldModel
    end

    local csmodel = ClientsideModel(model)

    if not IsValid(csmodel) then return end

    csmodel:SetNoDraw(true)
    csmodel.atttbl = atttbl
    csmodel.slottbl = slottbl
    csmodel.weapon = self -- for matproxy

    csmodel.istranslucent = atttbl.TranslucentPass
    csmodel.translucentpassextramat = atttbl.TranslucentPassExtraMat
    csmodel.translucentpassblend = atttbl.TranslucentPassBlend

    if atttbl.DrawFunc then
        csmodel.DrawFunc = atttbl.DrawFunc
    end

    if atttbl.ModelSkin then
        csmodel:SetSkin(atttbl.ModelSkin)
    end

    if atttbl.ModelBodygroups then
        csmodel:SetBodyGroups(atttbl.ModelBodygroups)
    end

    if atttbl.ModelMaterial then
        -- csmodel:SetMaterial(atttbl.ModelMaterial)
        csmodel:SetSubMaterial(0, atttbl.ModelMaterial)
        csmodel:SetSubMaterial(1, atttbl.ModelMaterial)
        csmodel:SetSubMaterial(2, atttbl.ModelMaterial)
        csmodel:SetSubMaterial(3, atttbl.ModelMaterial)
        csmodel:SetSubMaterial(4, atttbl.ModelMaterial)
    end

    if atttbl.EnableModelSubMaterial then
        -- csmodel:SetMaterial(atttbl.ModelMaterial)
        if not csmodel.MaterialAmount then csmodel.MaterialAmount = table.Count(csmodel:GetMaterials() or {}) end

        for ind = 0, csmodel.MaterialAmount do
            local val = swepGetProcessedValue(self, "ModelSubMaterial" .. ind, true)
            if val then
                csmodel:SetSubMaterial(ind, val)
            end
        end
    end

    if atttbl.RTScopeSubmatIndex then
        csmodel:SetSubMaterial(atttbl.RTScopeSubmatIndex, wm and "vgui/black" or "effects/arc9/rt")
    end

    if not swepGetProcessedValue then swepGetProcessedValue = self.GetProcessedValue end
    csmodel.CustomCamoTexture = customCamoTexture or swepGetProcessedValue(self, "CustomCamoTexture", true)
    csmodel.CustomCamoScale = customCamoScale or swepGetProcessedValue(self, "CustomCamoScale", true)
    csmodel.CustomBlendFactor = customBlendFactor or swepGetProcessedValue(self, "CustomBlendFactor", true)

    if atttbl.CharmModel then
        local charmmodel = ClientsideModel(atttbl.CharmModel)

        csmodel.charmmdl = charmmodel
        charmmodel.charmparent = csmodel

        charmmodel.atttbl = atttbl
        charmmodel.slottbl = slottbl
        charmmodel.weapon = self

        charmmodel:SetBodyGroups(atttbl.CharmBodygroups or "") -- RUBAT THANK YOU FOR MAKING FUNC ERROR AFTER 10 YEARS OF STABLE WORK
        charmmodel:SetMaterial(atttbl.CharmMaterial)
        if atttbl.CharmSkin then
            charmmodel:SetSkin(atttbl.CharmSkin)
        end
        charmmodel:SetNoDraw(true)

        local scale = Matrix()
        local vec = Vector(1, 1, 1) * (atttbl.CharmScale or 1) * (atttbl.Scale or 1)
        if wm then
            vec = vec * (self.WorldModelOffset.Scale or 1)
        end
        vec = vec * (slottbl.Scale or 1)
        scale:Scale(vec)
        charmmodel:EnableMatrix("RenderMultiply", scale)

        local charmtbl = {
            Model = charmmodel,
            Weapon = self,
            Version = self.ModelVersion
        }

        table.insert(ARC9.CSModelPile, charmtbl)

        if cm then
            table.insert(self.CModel, charmmodel)
        else
            if wm then
                table.insert(self.WModel, charmmodel)
            else
                table.insert(self.VModel, charmmodel)
            end
        end
    end

    if atttbl.Flare then
        csmodel.Flare = {
            Color = atttbl.FlareColor or Color(255, 255, 255),
            Size = atttbl.FlareSize or 200,
            Attachment = atttbl.FlareAttachment,
            Focus = atttbl.FlareFocus
        }
    end

    local scalee = atttbl.Scale or 1

    if slottbl.OriginalAddress then
        local eles = self:GetAttachmentElements()

        for _, ele in ipairs(eles) do
            local mods = ele.AttPosMods
            if mods then
                local mod_data = mods[slottbl.OriginalAddress]
                if mod_data and mod_data.Scale then
                    scalee = mod_data.Scale * scalee
                end
            end
        end
    end

    if not ignorescale then
        local scale = Matrix()
        local vec = Vector(1, 1, 1) * scalee
        if wm then
            vec = vec * (self.WorldModelOffset.Scale or 1)
        end
        vec:Mul(slottbl.Scale or 1)
        scale:Scale(vec)
        csmodel.Scale = vec
        csmodel:EnableMatrix("RenderMultiply", scale)
    end

    local tbl = {
        Model = csmodel,
        Weapon = self,
        Version = self.ModelVersion
    }

    table.insert(ARC9.CSModelPile, tbl)

    if cm then
        table.insert(self.CModel, csmodel)
    else
        if wm then
            table.insert(self.WModel, csmodel)
        else
            table.insert(self.VModel, csmodel)
        end
    end

    return csmodel
end

SWEP.LHIKModel = nil
SWEP.LHIKModelAddress = nil
SWEP.LHIK_Priority = -1000
SWEP.RHIKModel = nil
SWEP.RHIKModelAddress = nil
SWEP.RHIK_Priority = -1000
SWEP.LHIKModelWM = nil
SWEP.RHIKModelWM = nil
SWEP.MuzzleDeviceVM = nil
SWEP.MuzzleDeviceWM = nil
SWEP.MuzzleDeviceUBGLVM = nil
SWEP.MuzzleDeviceUBGLWM = nil

-- An important function
function SWEP:SetupModel(wm, lod, cm)
    lod = lod or 0
    if not wm then lod = 0 end
    if cm then wm = true end

    -- self:KillModel(cm)

    if not cm then
        self:KillSpecificModel(wm)
    end

    local owner = self:GetOwner()

    if not wm and not IsValid(owner) then return end

    if wm and not self.MirrorVMWM then return end

    self.LHIK_Priority = -1000
    self.RHIK_Priority = -1000
    self.MuzzleDevice_Priority = -1000
    self.MuzzleDeviceUBGL_Priority = -1000

    if not swepGetProcessedValue then swepGetProcessedValue = self.GetProcessedValue end
    local customCamoTexture = swepGetProcessedValue(self, "CustomCamoTexture", true)
    local customBlendFactor, customCamoScale

    if customCamoTexture then
        customCamoScale = swepGetProcessedValue(self, "CustomCamoScale", true)
        customBlendFactor = swepGetProcessedValue(self, "CustomBlendFactor", true)
    end

    local basemodel = nil

    local mdl = {}

    if not wm then
        self.VModel = mdl
        self.LHIKModel = nil
        self.RHIKModel = nil
        self.MuzzleDeviceVM = nil
        self.MuzzleDeviceUBGLVM = nil

        if not owner.GetViewModel then return end -- safe check to fix random mp error

        basemodel = owner:GetViewModel()
    else
        if cm then
            self.CModel = mdl
        else
            self.LHIKModelWM = nil
            self.RHIKModelWM = nil
            self.MuzzleDeviceWM = nil
            self.MuzzleDeviceUBGLWM = nil
            self.WModel = mdl
        end

        local csmodel = ClientsideModel(self.WorldModelMirror or self.ViewModel)
        csmodel.weapon = self
        basemodel = csmodel

        if not IsValid(csmodel) then return end

        csmodel:SetNoDraw(true)
        csmodel.atttbl = {}

        if cm then
            csmodel.slottbl = {
                WMBase = true,
                Pos = Vector(0, 0, 0),
                Ang = Angle(0, 0, 0)
            }
        else
            csmodel.slottbl = {
                WMBase = true,
                Pos = self.WorldModelOffset.Pos or Vector(0, 0, 0),
                Ang = self.WorldModelOffset.Ang or Angle(-5, 0, 180)
            }
        end

        local animentry = self:GetAnimationEntry("idle")
        local source = animentry and animentry.Source or "idle"

        if istable(source) then
            source = source[1]
        end

        if not isnumber(source) then
            source = csmodel:LookupSequence(source)
        end

        if source >= 0 then
            csmodel:ResetSequence(source)
        end

        local scale = Matrix()
        local vec = Vector(1, 1, 1) * (self.WorldModelOffset.Scale or 1)
        scale:Scale(vec)
        csmodel:EnableMatrix("RenderMultiply", scale)

        local tbl = {
            Model = csmodel,
            Weapon = self,
            Version = self.ModelVersion
        }

        table.insert(ARC9.CSModelPile, tbl)

        table.insert(mdl, 1, csmodel)
    end

    if not wm and owner ~= LocalPlayer() then return end
    if lod > 0 then return end

    local eles = self:GetAttachmentElements()

    for _, ele in ipairs(eles) do

        if not ele then continue end
        if not ele.Models then continue end

        for _, model in ipairs(ele.Models) do
            local csmodel = ClientsideModel(model.Model)

            if not IsValid(csmodel) then continue end

            csmodel:SetNoDraw(true)
            csmodel.atttbl = {}

            csmodel.slottbl = {
                Pos = model.Pos or Vector(0, 0, 0),
                Ang = model.Ang or Angle(0, 0, 0),
                Bone = model.Bone
            }

            if model.BoneMerge then
                csmodel.BoneMerge = true

                csmodel:AddEffects(EF_BONEMERGE)
                csmodel:SetParent(basemodel)
            end

            local scale = Matrix()
            local vec = model.ScaleVector or (Vector(1, 1, 1) * (model.Scale or 1))
            if wm then
                vec = vec * (self.WorldModelOffset.Scale or 1)
            end
            scale:Scale(vec)
            csmodel:EnableMatrix("RenderMultiply", scale)

            csmodel:SetSkin(model.Skin or 1)
            csmodel:SetBodyGroups(model.Bodygroups or "")

            if (ele.MuzzleDevice) then
                local priority = ele.MuzzleDevice_Priority or 0
                local totalpriority = self.MuzzleDevice_Priority or 0

                if priority > totalpriority or (priority == totalpriority and i > 0) then
                    self.MuzzleDevice_Priority = priority
                    csmodel.IsMuzzleDevice = true

                    if wm then
                        self.MuzzleDeviceWM = csmodel
                    else
                        self.MuzzleDeviceVM = csmodel
                    end
                end
            end

            local tbl = {
                Model = csmodel,
                Weapon = self,
                Version = self.ModelVersion
            }

            csmodel.CustomCamoTexture = customCamoTexture
            csmodel.CustomCamoScale = customCamoScale
            csmodel.CustomBlendFactor = customBlendFactor

            table.insert(ARC9.CSModelPile, tbl)

            table.insert(mdl, 1, csmodel)
        end
    end

    for _, slottbl in ipairs(self:GetSubSlotList()) do
        if not slottbl.Installed then continue end
        if slottbl.NoDraw then continue end

        -- local atttbl = ARC9.GetAttTable(slottbl.Installed)
        local atttbl = self:GetFinalAttTable(slottbl)

        local stickertablepath = slottbl.StickerModel

        if wm then
            stickertablepath = slottbl.StickerModelWorld or stickertablepath
        end

        if stickertablepath and atttbl.StickerMaterial then
            local stickermodel = ClientsideModel(stickertablepath)

            if not IsValid(stickermodel) then continue end

            stickermodel:SetNoDraw(true)
            stickermodel.atttbl = {
                DrawFunc = atttbl.StickerDrawFunc
            }
            stickermodel.slottbl = slottbl

            stickermodel:AddEffects(EF_BONEMERGE)
            local stickerparent = basemodel
            if slottbl.ParentTable then
                if wm then
                    stickerparent = slottbl.ParentTable.WModel or basemodel
                else
                    stickerparent = slottbl.ParentTable.VModel or basemodel
                end
            end
            stickermodel:SetParent(stickerparent)
            local stickermat = atttbl.StickerMaterial

            if self.StickersNoNocull then
                local fakestickwithoutnocull = Material(stickermat)
                fakestickwithoutnocull:SetInt("$flags", bit.band(fakestickwithoutnocull:GetInt("$flags"), bit.bnot(8192)))
                fakestickwithoutnocull:Recompute()
            end

            -- stickermodel:SetMaterial(stickermat)
            stickermodel:SetSubMaterial(0, stickermat)
            stickermodel:SetSubMaterial(1, stickermat)
            stickermodel:SetSubMaterial(2, stickermat)

            local tbl = {
                Model = stickermodel,
                Weapon = self,
                Version = self.ModelVersion
            }

            table.insert(ARC9.CSModelPile, tbl)

            table.insert(mdl, stickermodel)
        end

        if not atttbl.Model then continue end

        local dupli = slottbl.DuplicateModels or {}

        if not swepGetProcessedValue then swepGetProcessedValue = self.GetProcessedValue end
        local duplicheck = swepGetProcessedValue(self, "Akimbo",true) or swepGetProcessedValue(self, "DuplicateAttachments",true)

        for i = 0, #dupli do
            local csmodel = self:CreateAttachmentModel(wm, atttbl, slottbl, false, cm, dupli, customCamoTexture, customCamoScale, customBlendFactor)

            if duplicheck  then
                csmodel.Duplicate = i
            end

            if atttbl.NoDraw then
                csmodel.NoDraw = true
            end

            if csmodel.DrawFunc then
                csmodel.DrawFunc(self, csmodel, wm)
            end

            local proxmodel

            if not cm and ((atttbl.LHIK or atttbl.RHIK) or atttbl.MuzzleDevice or atttbl.MuzzleDeviceUBGL) then
                proxmodel = self:CreateAttachmentModel(wm, atttbl, slottbl, true)
                proxmodel.NoDraw = true
                if duplicheck then
                    proxmodel.Duplicate = i
                end

                local scale = Matrix()
                local vec = Vector(1, 1, 1) * (slottbl.Scale or 1) * (atttbl.Scale or 1)
                if wm then
                    vec = vec * (self.WorldModelOffset.Scale or 1)
                end
                if i > 0 then
                    vec = vec * (slottbl.DuplicateModels[i].Scale or 1)
                end
                scale:Scale(vec)
                proxmodel:EnableMatrix("RenderMultiply", scale)

                local tbl = {
                    Model = proxmodel,
                    Weapon = self,
                    Version = self.ModelVersion
                }

                table.insert(ARC9.CSModelPile, tbl)
            end

            if atttbl.BoneMerge then
                csmodel.BoneMerge = true

                csmodel:AddEffects(EF_BONEMERGE)
                csmodel:SetParent(basemodel)
            end

            if (atttbl.MuzzleDevice or atttbl.MuzzleDeviceUBGL) and not cm then
                local priority = atttbl.MuzzleDevice_Priority or 0
                local totalpriority = self.MuzzleDevice_Priority or 0

                if atttbl.MuzzleDeviceUBGL then
                    priority = atttbl.MuzzleDeviceUBGL_Priority or 0
                    totalpriority = self.MuzzleDeviceUBGL_Priority or 0
                end

                if priority > totalpriority or (priority == totalpriority and i > 0) then
                    if atttbl.MuzzleDeviceUBGL then
                        self.MuzzleDeviceUBGL_Priority = priority
                    else
                        self.MuzzleDevice_Priority = priority
                        proxmodel.IsMuzzleDevice = true
                    end

                    local tbl

                    if atttbl.MuzzleDeviceUBGL then
                        tbl = self.MuzzleDeviceUBGLVM

                        if wm then
                            tbl = self.MuzzleDeviceUBGLWM
                        end
                    else
                        tbl = self.MuzzleDeviceVM

                        if wm then
                            tbl = self.MuzzleDeviceWM
                        end
                    end

                    if #dupli > 0 then
                        if i == 0 then
                            tbl = {proxmodel}
                        else
                            table.insert(tbl, proxmodel)
                        end
                    else
                        tbl = proxmodel
                    end

                    if atttbl.MuzzleDeviceUBGL then
                        self.MuzzleDeviceUBGLVM = tbl

                        if wm then
                            self.MuzzleDeviceUBGLWM = tbl
                        end
                    else
                        self.MuzzleDeviceVM = tbl

                        if wm then
                            self.MuzzleDeviceWM = tbl
                        end
                    end
                end
            end

            if not cm and i == 0 then
                if wm then
                    slottbl.WModel = csmodel
                else
                    slottbl.VModel = csmodel
                end
            end

            if i == 0 then
                csmodel.LaserCorrectionAngle = slottbl.LaserCorrectionAngle
            else
                csmodel.LaserCorrectionAngle = slottbl.DuplicateModels[i].LaserCorrectionAngle or slottbl.LaserCorrectionAngle
            end

            if not cm and i == 0 then
                if atttbl.IKAnimationProxy then
                    local animproxmodel = self:CreateAttachmentModel(wm, atttbl, slottbl, true)
                    animproxmodel.NoDraw = true
                    animproxmodel.IsAnimationProxy = true

                    slottbl.GunDriverModel = animproxmodel

                    local reflectproxmodel = ClientsideModel(self.ViewModel)

                    if not IsValid(reflectproxmodel) then return end

                    reflectproxmodel:SetNoDraw(true)
                    reflectproxmodel.atttbl = atttbl
                    reflectproxmodel.slottbl = slottbl

                    local tbl = {
                        Model = reflectproxmodel,
                        Weapon = self,
                        Version = self.ModelVersion
                    }

                    table.insert(ARC9.CSModelPile, tbl)

                    table.insert(mdl, reflectproxmodel)

                    reflectproxmodel.NoDraw = true
                    reflectproxmodel.IsAnimationProxy = true

                    slottbl.ReflectDriverModel = reflectproxmodel

                    local anim = self:TranslateAnimation("idle")
                    local ae = self:GetAnimationEntry(anim)
                    local seq = reflectproxmodel:LookupSequence(self:RandomChoice(ae.Source))

                    reflectproxmodel:ResetSequence(seq)
                end
            end

            if not cm and i == 0 and atttbl.LHIK or atttbl.RHIK then
                slottbl.IKModel = proxmodel

                if atttbl.LHIK then
                    if (atttbl.LHIK_Priority or 0) > self.LHIK_Priority then
                        self.LHIK_Priority = atttbl.LHIK_Priority or 0
                        if wm then
                            self.LHIKModelWM = proxmodel
                        else
                            self.LHIKModel = proxmodel
                        end
                        self.LHIKModelAddress = slottbl.Address
                    end
                end
                if atttbl.RHIK then
                    if (atttbl.RHIK_Priority or 0) > self.RHIK_Priority then
                        self.RHIK_Priority = atttbl.RHIK_Priority or 0
                        if wm then
                            self.RHIKModelWM = proxmodel
                        else
                            self.RHIKModel = proxmodel
                        end
                        self.RHIKModelAddress = slottbl.Address
                    end
                end
            end
        end
    end

    self:CreateFlashlights()

    self:DoBodygroups(wm, cm)
end

SWEP.VModel = nil
SWEP.WModel = nil
SWEP.CModel = nil

function SWEP:KillSpecificModel(wm)
    if wm then
        for _, model in ipairs(self.WModel or {}) do
            SafeRemoveEntity(model)
        end

        self.WModel = nil
    else
        for _, model in ipairs(self.VModel or {}) do
            SafeRemoveEntity(model)
        end

        self.VModel = nil
    end
end

function SWEP:KillModel(cmo)
    if cmo then
        for _, model in ipairs(self.CModel or {}) do
            SafeRemoveEntity(model)
        end

        self.CModel = nil

        return
    end

    if not self.VModel and not self.WModel then return end

    for _, model in ipairs(self.VModel or {}) do
        SafeRemoveEntity(model)
    end
    for _, model in ipairs(self.WModel or {}) do
        SafeRemoveEntity(model)
    end

    self.ModelVersion = self.ModelVersion + 1

    self.VModel = nil
    self.WModel = nil
end
