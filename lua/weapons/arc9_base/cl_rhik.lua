
local Lerp, LerpVector, CurTime, EyeAngles, LerpAngle, Vector, Angle, Matrix, vector_origin, angle_zero =
      Lerp, LerpVector, CurTime, EyeAngles, LerpAngle, Vector, Angle, Matrix, vector_origin, angle_zero

local math_Clamp, math_ease_InExpo, math_ease_OutExpo, math_ease_InCubic, math_ease_InOutQuart =
      math.Clamp, math.ease.InExpo, math.ease.OutExpo, math.ease.InCubic, math.ease.InOutQuart

local ENT = FindMetaTable("Entity")
local ENT_GetTable, ENT_IsValid, ENT_SetupBones, ENT_LookupBone, ENT_CopyBoneMatrix, ENT_SetBoneMatrix =
      ENT.GetTable, ENT.IsValid, ENT.SetupBones, ENT.LookupBone, ENT.CopyBoneMatrix, ENT.SetBoneMatrix
local ENT_GetSequence, ENT_GetCycle, ENT_SetCycle, ENT_ResetSequence, ENT_GetAttachment, ENT_SetPos =
      ENT.GetSequence, ENT.GetCycle, ENT.SetCycle, ENT.ResetSequence, ENT.GetAttachment, ENT.SetPos
local ENT_SetAngles, ENT_GetBonePosition, ENT_GetPos =
      ENT.SetAngles, ENT.GetBonePosition, ENT.GetPos

local VMAT = FindMetaTable("VMatrix")
local VMAT_GetTranslation, VMAT_GetAngles, VMAT_SetTranslation, VMAT_SetAngles =
      VMAT.GetTranslation, VMAT.GetAngles, VMAT.SetTranslation, VMAT.SetAngles

local VEC = FindMetaTable("Vector")
local VEC_Sub, VEC_Mul, VEC_Add, VEC_Unpack =
      VEC.Sub, VEC.Mul, VEC.Add, VEC.Unpack

local ANG = FindMetaTable("Angle")
local ANG_Forward, ANG_Up, ANG_Right, ANG_Sub, ANG_Mul, ANG_Add, ANG_Unpack, ANG_SetUnpacked =
      ANG.Forward, ANG.Up, ANG.Right, ANG.Sub, ANG.Mul, ANG.Add, ANG.Unpack, ANG.SetUnpacked

local vmBoneMatrix = Matrix()
local targetBoneMatrix = Matrix()

local function qerp(delta, a, b)
    local qdelta = math_Clamp(-(delta * delta) + (delta * 2), 0, 1)
    return a + (b - a) * qdelta
end

function SWEP:DoRHIK(wm)
    local selfTbl = ENT_GetTable(self)
    if not selfTbl.UseHands then return end

    local vm = wm and selfTbl.GetWM(self) or selfTbl.GetVM(self)
    if not vm or not ENT_IsValid(vm) then return end

    ENT_SetupBones(vm)

    local hasonehandsprint = selfTbl.GetValue(self, "OneHandedSprint")
    local hide_lh_d, hide_rh_d

    if ARC9.PresetCam then
        hide_lh_d = 1
        hide_rh_d = 1
    else
        local custDelta = selfTbl.CustomizeDelta
        hide_lh_d = custDelta + (hasonehandsprint and selfTbl.GetSprintAmount(self) or 0)
        hide_rh_d = custDelta

        if hide_lh_d > 0 then hide_lh_d = math_ease_InExpo(hide_lh_d) end
        if hide_rh_d > 0 then hide_rh_d = math_ease_InCubic(hide_rh_d) end
    end

    local lh_delta = 1
    local rh_delta = 1

    local ikAnim = selfTbl.GetIKAnimation(self)
    local animTbl = ikAnim and selfTbl.Animations[ikAnim]
    local iktl = animTbl and animTbl.IKTimeLine

    if iktl then
        local doLHIK = selfTbl.GetProcessedValue(self, "LHIK", true)
        local doRHIK = selfTbl.GetProcessedValue(self, "RHIK", true)

        if doLHIK or doRHIK then
            local iket = selfTbl.GetIKTime(self)
            local iklt = math_Clamp((CurTime() - selfTbl.GetIKTimeLineStart(self)) / iket, 0, 1)
            local iktlCount = #iktl
            local next_stage_index

            for i = 1, iktlCount do
                local k = iktl[i]
                if k and k.t and k.t > iklt then
                    next_stage_index = i
                    break
                end
            end

            if next_stage_index then
                local stage, stage_t
                local next_stage = iktl[next_stage_index]

                if next_stage_index == 1 then
                    stage_t = 0
                else
                    stage = iktl[next_stage_index - 1]
                    stage_t = stage.t
                end

                local dt = next_stage.t - stage_t
                local delta_time = dt > 0 and math_ease_InOutQuart((iklt - stage_t) / dt) or 1

                if doLHIK then
                    lh_delta = qerp(delta_time, stage and stage.lhik or 0, next_stage.lhik or 0)
                end

                if doRHIK then
                    rh_delta = qerp(delta_time, stage and stage.rhik or 0, next_stage.rhik or 0)
                end
            else
                local last_stage = iktl[iktlCount]
                if last_stage then
                    if doLHIK then lh_delta = last_stage.lhik or 0 end
                    if doRHIK then rh_delta = last_stage.rhik or 0 end
                end
            end
        end
    end

    local rhik_model = wm and selfTbl.RHIKModelWM or selfTbl.RHIKModel
    if rhik_model and ENT_IsValid(rhik_model) then
        ENT_SetupBones(rhik_model)

        local rhikBones = ARC9.RHIKBones
        for i = 1, #rhikBones do
            local bone = rhikBones[i]
            local vm_bone = ENT_LookupBone(vm, bone)
            local target_bone = ENT_LookupBone(rhik_model, bone)
            if not vm_bone or not target_bone then continue end

            ENT_CopyBoneMatrix(vm, vm_bone, vmBoneMatrix)
            ENT_CopyBoneMatrix(rhik_model, target_bone, targetBoneMatrix)

            local lerped_pos = LerpVector(rh_delta, VMAT_GetTranslation(vmBoneMatrix), VMAT_GetTranslation(targetBoneMatrix))
            local lerped_ang = LerpAngle(rh_delta, VMAT_GetAngles(vmBoneMatrix), VMAT_GetAngles(targetBoneMatrix))

            VMAT_SetTranslation(vmBoneMatrix, lerped_pos)
            VMAT_SetAngles(vmBoneMatrix, lerped_ang)
            ENT_SetBoneMatrix(vm, vm_bone, vmBoneMatrix)
        end
    end

    local lhik_model = wm and selfTbl.LHIKModelWM or selfTbl.LHIKModel
    if lhik_model and ENT_IsValid(lhik_model) then
        ENT_SetupBones(lhik_model)

        lh_delta = lh_delta - math_ease_OutExpo(hide_lh_d)

        local lhikBones = ARC9.LHIKBones
        for i = 1, #lhikBones do
            local bone = lhikBones[i]
            local vm_bone = ENT_LookupBone(vm, bone)
            local target_bone = ENT_LookupBone(lhik_model, bone)
            if not vm_bone or not target_bone then continue end

            ENT_CopyBoneMatrix(vm, vm_bone, vmBoneMatrix)
            ENT_CopyBoneMatrix(lhik_model, target_bone, targetBoneMatrix)

            local lerped_pos = LerpVector(lh_delta, VMAT_GetTranslation(vmBoneMatrix), VMAT_GetTranslation(targetBoneMatrix))
            local lerped_ang = LerpAngle(lh_delta, VMAT_GetAngles(vmBoneMatrix), VMAT_GetAngles(targetBoneMatrix))

            VMAT_SetTranslation(vmBoneMatrix, lerped_pos)
            VMAT_SetAngles(vmBoneMatrix, lerped_ang)
            ENT_SetBoneMatrix(vm, vm_bone, vmBoneMatrix)
        end
    end

    if wm then return end

    selfTbl.LHIKThirdArm(self)

    local eyeAng
    if hide_lh_d > 0 then
        eyeAng = EyeAngles()

        local offset = ANG_Up(eyeAng)
        local fwd = ANG_Forward(eyeAng)
        if hasonehandsprint and hide_rh_d == 0 then
            local right = ANG_Right(eyeAng)
            VEC_Mul(offset, -16)
            VEC_Mul(fwd, -9)
            VEC_Mul(right, -12)
            VEC_Add(offset, fwd)
            VEC_Add(offset, right)
        else
            VEC_Mul(offset, -48)
            VEC_Mul(fwd, -16)
            VEC_Add(offset, fwd)
        end
        VEC_Mul(offset, hide_lh_d)

        local lhikBones = ARC9.LHIKBones
        for i = 1, #lhikBones do
            local vmbone = ENT_LookupBone(vm, lhikBones[i])
            if not vmbone then continue end -- Happens when spectating someone prolly

            ENT_CopyBoneMatrix(vm, vmbone, vmBoneMatrix)

            local vm_pos = VMAT_GetTranslation(vmBoneMatrix)
            VEC_Add(vm_pos, offset)

            VMAT_SetTranslation(vmBoneMatrix, vm_pos)
            ENT_SetBoneMatrix(vm, vmbone, vmBoneMatrix)
        end
    end

    if hide_rh_d > 0 then
        eyeAng = eyeAng or EyeAngles()

        local offset = ANG_Up(eyeAng)
        local fwd = ANG_Forward(eyeAng)
        VEC_Mul(offset, -48)
        VEC_Mul(fwd, -16)
        VEC_Add(offset, fwd)
        VEC_Mul(offset, hide_rh_d)

        local rhikBones = ARC9.RHIKBones
        for i = 1, #rhikBones do
            local vmbone = ENT_LookupBone(vm, rhikBones[i])
            if not vmbone then continue end -- Happens when spectating someone prolly

            ENT_CopyBoneMatrix(vm, vmbone, vmBoneMatrix)

            local vm_pos = VMAT_GetTranslation(vmBoneMatrix)
            VEC_Add(vm_pos, offset)

            VMAT_SetTranslation(vmBoneMatrix, vm_pos)
            ENT_SetBoneMatrix(vm, vmbone, vmBoneMatrix)
        end
    end
end

function SWEP:RecalculateIKGunMotionOffset()
    local selfTbl = ENT_GetTable(self)
    local seqproxy = selfTbl.GetSequenceProxy(self)

    if seqproxy ~= 0 then
        local slottbl = selfTbl.LocateSlotFromAddress(self, seqproxy)
        local anim_mdl = slottbl and slottbl.GunDriverModel
        if not anim_mdl then return end

        local atttbl = selfTbl.GetFinalAttTable(self, slottbl)
        local qca = atttbl.IKGunMotionQCA
        if not qca then return end

        local oldseq = ENT_GetSequence(anim_mdl)
        local oldcycle = ENT_GetCycle(anim_mdl)
        ENT_ResetSequence(anim_mdl, 0)
        ENT_SetCycle(anim_mdl, 0)

        local att = ENT_GetAttachment(anim_mdl, qca)
        if att then
            selfTbl.IKGunMotionOffset = att.Pos
            selfTbl.IKGunMotionOffsetAngle = att.Ang
        end

        ENT_ResetSequence(anim_mdl, oldseq)
        ENT_SetCycle(anim_mdl, oldcycle)
    end
end

function SWEP:GunControllerRHIK(pos, ang)
    local selfTbl = ENT_GetTable(self)
    local seqproxy = selfTbl.GetSequenceProxy(self)

    if seqproxy ~= 0 then
        local slottbl = selfTbl.LocateSlotFromAddress(self, seqproxy)
        local anim_mdl = slottbl and slottbl.GunDriverModel
        if not anim_mdl or not ENT_IsValid(anim_mdl) then return pos, ang end

        local refl_mdl = slottbl.ReflectDriverModel
        if not refl_mdl or not ENT_IsValid(refl_mdl) then return pos, ang end

        local atttbl = selfTbl.GetFinalAttTable(self, slottbl)
        local qca = atttbl.IKGunMotionQCA
        if not qca then return pos, ang end

        ENT_SetPos(anim_mdl, vector_origin)
        ENT_SetAngles(anim_mdl, angle_zero)

        ENT_SetPos(refl_mdl, vector_origin)
        ENT_SetAngles(refl_mdl, angle_zero)

        if not selfTbl.IKGunMotionOffset then
            selfTbl.RecalculateIKGunMotionOffset(self)
        end

        local getatt = ENT_GetAttachment(anim_mdl, qca)
        if not getatt then return pos, ang end
        local attpos, attang = getatt.Pos, getatt.Ang

        ANG_Sub(attang, selfTbl.IKGunMotionOffsetAngle)
        VEC_Sub(attpos, selfTbl.IKGunMotionOffset)

        local p, y, r = ANG_Unpack(attang)
        ANG_SetUnpacked(attang, -r, -y, p)

        local anchor = slottbl.Pos
        local bone = ENT_LookupBone(refl_mdl, slottbl.Bone)
        local bonp, bona = ENT_GetBonePosition(refl_mdl, bone)
        if bonp == ENT_GetPos(refl_mdl) then
            ENT_CopyBoneMatrix(refl_mdl, bone, vmBoneMatrix)
            bonp = VMAT_GetTranslation(vmBoneMatrix)
            bona = VMAT_GetAngles(vmBoneMatrix)
        end

        if anchor and bonp then
            local offsx, offsy, offsz = VEC_Unpack(anchor)
            local motionAnchor = atttbl.IKGunMotionAnchor
            if motionAnchor then
                local mx, my, mz = VEC_Unpack(motionAnchor)
                offsx = offsx + mx
                offsy = offsy + my
                offsz = offsz + mz
            end

            local fwd = ANG_Forward(bona)
            local right = ANG_Right(bona)
            local up = ANG_Up(bona)
            VEC_Mul(fwd, offsx)
            VEC_Mul(right, offsy)
            VEC_Mul(up, offsz)
            VEC_Add(bonp, fwd)
            VEC_Add(bonp, right)
            VEC_Add(bonp, up)

            if atttbl.IKGunMotionMultReal then
                VEC_Mul(attpos, atttbl.IKGunMotionMultReal)
            end

            if atttbl.IKGunMotionAngleMultReal then
                ANG_Mul(attang, atttbl.IKGunMotionAngleMultReal)
            end

            local rap_pos, rap_ang = selfTbl.RotateAroundPoint2(self, pos, ang, bonp, attpos, attang)

            VEC_Sub(rap_pos, pos)
            ANG_Sub(rap_ang, ang)

            selfTbl.IKGunMotionPos = rap_pos
            selfTbl.IKGunMotionAng = rap_ang

            VEC_Add(pos, rap_pos)
            ANG_Add(ang, rap_ang)
        end

        return pos, ang
    else
        return pos, ang
    end
end
