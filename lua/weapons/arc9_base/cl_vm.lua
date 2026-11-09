local ScrW, ScrH, CurTime, FrameTime, FrameNumber, EyePos, EyeAngles, MainEyeAngles, LocalToWorld, DynamicLight, DrawBokehDOF =
      ScrW, ScrH, CurTime, FrameTime, FrameNumber, EyePos, EyeAngles, MainEyeAngles, LocalToWorld, DynamicLight, DrawBokehDOF
local Vector, Material, CreateMaterial, GetRenderTargetEx, pairs, tonumber, tobool, vector_origin, angle_zero =
      Vector, Material, CreateMaterial, GetRenderTargetEx, pairs, tonumber, tobool, vector_origin, angle_zero

local STUDIO_RENDER, STUDIO_DEPTH_MASK =
      STUDIO_RENDER, bit.bor(STUDIO_SSAODEPTHTEXTURE, STUDIO_SHADOWDEPTHTEXTURE)

local math_Clamp, math_Approach, math_max =
      math.Clamp, math.Approach, math.max

local cam_Start2D, cam_End2D, cam_Start3D, cam_End3D, cam_IgnoreZ =
      cam.Start2D, cam.End2D, cam.Start3D, cam.End3D, cam.IgnoreZ

local surface_SetDrawColor, surface_DrawRect, surface_SetMaterial, surface_DrawTexturedRect =
      surface.SetDrawColor, surface.DrawRect, surface.SetMaterial, surface.DrawTexturedRect

local render_UpdateScreenEffectTexture, render_GetScreenEffectTexture, render_CopyTexture, render_SetToneMappingScaleLinear =
      render.UpdateScreenEffectTexture, render.GetScreenEffectTexture, render.CopyTexture, render.SetToneMappingScaleLinear
local render_GetToneMappingScaleLinear, render_PushRenderTarget, render_PopRenderTarget, render_SetMaterial, render_DrawScreenQuad =
      render.GetToneMappingScaleLinear, render.PushRenderTarget, render.PopRenderTarget, render.SetMaterial, render.DrawScreenQuad
local render_DepthRange, render_SetStencilEnable, render_SetBlend, render_Clear, render_ClearDepth, render_SetColorModulation =
      render.DepthRange, render.SetStencilEnable, render.SetBlend, render.Clear, render.ClearDepth, render.SetColorModulation
local render_SuppressEngineLighting, render_MaterialOverride, render_MaterialOverrideByIndex =
      render.SuppressEngineLighting, render.MaterialOverride, render.MaterialOverrideByIndex

local system_HasFocus, util_GetModelInfo, bit_band =
      system.HasFocus, util.GetModelInfo, bit.band

local ENT = FindMetaTable("Entity")
local ENT_GetTable, ENT_IsValid, ENT_EntIndex, ENT_GetPos, ENT_GetAngles =
      ENT.GetTable, ENT.IsValid, ENT.EntIndex, ENT.GetPos, ENT.GetAngles
local ENT_SetPoseParameter, ENT_InvalidateBoneCache, ENT_LookupBone =
      ENT.SetPoseParameter, ENT.InvalidateBoneCache, ENT.LookupBone
local ENT_ManipulateBonePosition, ENT_ManipulateBoneAngles, ENT_ManipulateBoneScale =
      ENT.ManipulateBonePosition, ENT.ManipulateBoneAngles, ENT.ManipulateBoneScale
local ENT_SetMaterial, ENT_GetMaterials, ENT_SetSubMaterial, ENT_GetModel, ENT_DrawModel =
      ENT.SetMaterial, ENT.GetMaterials, ENT.SetSubMaterial, ENT.GetModel, ENT.DrawModel

local IMAT = FindMetaTable("IMaterial")
local IMAT_SetFloat, IMAT_SetTexture =
      IMAT.SetFloat, IMAT.SetTexture

local CPE = FindMetaTable("CNewParticleEffect")
local CPE_IsValid, CPE_Render =
      CPE.IsValid, CPE.Render

local VEC = FindMetaTable("Vector")
local VEC_Add, VEC_Sub, VEC_Mul, VEC_Set, VEC_Unpack =
      VEC.Add, VEC.Sub, VEC.Mul, VEC.Set, VEC.Unpack

local ANG = FindMetaTable("Angle")
local ANG_Forward, ANG_Right, ANG_Up =
      ANG.Forward, ANG.Right, ANG.Up

local vignette = Material("arc9/bgvignette.png", "mips smooth")
-- local vignette2 = Material("arc9/bgvignette2.png", "mips smooth")
local scrw, scrh = ScrW(), ScrH()
local bluramt = 0

-- convars
local arc9_fx_rtblur_cvar = GetConVar("arc9_fx_rtblur")
local arc9_fx_rtblur = arc9_fx_rtblur_cvar and arc9_fx_rtblur_cvar:GetBool() or false
if arc9_fx_rtblur_cvar then
    local varname = arc9_fx_rtblur_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_fx_rtblur = tobool(v) end, varname)
end

local arc9_fx_animblur_cvar = GetConVar("arc9_fx_animblur")
local arc9_fx_animblur = arc9_fx_animblur_cvar and arc9_fx_animblur_cvar:GetBool() or false
if arc9_fx_animblur_cvar then
    local varname = arc9_fx_animblur_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_fx_animblur = tobool(v) end, varname)
end

local arc9_fx_reloadblur_cvar = GetConVar("arc9_fx_reloadblur")
local arc9_fx_reloadblur = arc9_fx_reloadblur_cvar and arc9_fx_reloadblur_cvar:GetBool() or false
if arc9_fx_reloadblur_cvar then
    local varname = arc9_fx_reloadblur_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_fx_reloadblur = tobool(v) end, varname)
end

local arc9_fx_inspectblur_cvar = GetConVar("arc9_fx_inspectblur")
local arc9_fx_inspectblur = arc9_fx_inspectblur_cvar and arc9_fx_inspectblur_cvar:GetBool() or false
if arc9_fx_inspectblur_cvar then
    local varname = arc9_fx_inspectblur_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_fx_inspectblur = tobool(v) end, varname)
end

local arc9_cust_blur_cvar = GetConVar("arc9_cust_blur")
local arc9_cust_blur = arc9_cust_blur_cvar and arc9_cust_blur_cvar:GetBool() or false
if arc9_cust_blur_cvar then
    local varname = arc9_cust_blur_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_cust_blur = tobool(v) end, varname)
end

local arc9_hud_lightmode_cvar = GetConVar("arc9_hud_lightmode")
local arc9_hud_lightmode = arc9_hud_lightmode_cvar and arc9_hud_lightmode_cvar:GetBool() or false
if arc9_hud_lightmode_cvar then
    local varname = arc9_hud_lightmode_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_hud_lightmode = tobool(v) end, varname)
end

local arc9_dev_greenscreen_cvar = GetConVar("arc9_dev_greenscreen")
local arc9_dev_greenscreen = arc9_dev_greenscreen_cvar and arc9_dev_greenscreen_cvar:GetBool() or false
if arc9_dev_greenscreen_cvar then
    local varname = arc9_dev_greenscreen_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_dev_greenscreen = tobool(v) end, varname)
end

local arc9_cust_light_cvar = GetConVar("arc9_cust_light")
local arc9_cust_light = arc9_cust_light_cvar and arc9_cust_light_cvar:GetBool() or false
if arc9_cust_light_cvar then
    local varname = arc9_cust_light_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_cust_light = tobool(v) end, varname)
end

local arc9_cust_light_brightness_cvar = GetConVar("arc9_cust_light_brightness")
local arc9_cust_light_brightness = arc9_cust_light_brightness_cvar and arc9_cust_light_brightness_cvar:GetFloat() or 1
if arc9_cust_light_brightness_cvar then
    local varname = arc9_cust_light_brightness_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_cust_light_brightness = tonumber(v) or 1 end, varname)
end

local arc9_dev_benchgun_cvar = GetConVar("arc9_dev_benchgun")
local arc9_dev_benchgun = arc9_dev_benchgun_cvar and arc9_dev_benchgun_cvar:GetBool() or false
if arc9_dev_benchgun_cvar then
    local varname = arc9_dev_benchgun_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_dev_benchgun = tobool(v) end, varname)
end

local arc9_fx_adsblur_new_cvar = GetConVar("arc9_fx_adsblur_new")
local arc9_fx_adsblur_new = arc9_fx_adsblur_new_cvar and arc9_fx_adsblur_new_cvar:GetBool() or false
if arc9_fx_adsblur_new_cvar then
    local varname = arc9_fx_adsblur_new_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_fx_adsblur_new = tobool(v) end, varname)
end

local arc9_fx_adsblur_always_cvar = GetConVar("arc9_fx_adsblur_always")
local arc9_fx_adsblur_always = arc9_fx_adsblur_always_cvar and arc9_fx_adsblur_always_cvar:GetBool() or false
if arc9_fx_adsblur_always_cvar then
    local varname = arc9_fx_adsblur_always_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_fx_adsblur_always = tobool(v) end, varname)
end

local arc9_fx_adsblur_bleeding_cvar = GetConVar("arc9_fx_adsblur_bleeding")
local arc9_fx_adsblur_bleeding = arc9_fx_adsblur_bleeding_cvar and arc9_fx_adsblur_bleeding_cvar:GetBool() or false
if arc9_fx_adsblur_bleeding_cvar then
    local varname = arc9_fx_adsblur_bleeding_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_fx_adsblur_bleeding = tobool(v) end, varname)
end

local arc9_fx_adsblur_bleeding_amount_cvar = GetConVar("arc9_fx_adsblur_bleeding_amount")
local arc9_fx_adsblur_bleeding_amount = math_Clamp(arc9_fx_adsblur_bleeding_amount_cvar and arc9_fx_adsblur_bleeding_amount_cvar:GetInt() or 1, 1, 60) -- clamp value on assignment instead of every time it's used to save performance
if arc9_fx_adsblur_bleeding_amount_cvar then
    local varname = arc9_fx_adsblur_bleeding_amount_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v)
        arc9_fx_adsblur_bleeding_amount = math_Clamp(tonumber(v) or 1, 1, 60)
    end, varname)
end
-- end convars

local subMaterialKeys = {}
for i = 0, 31 do
    subMaterialKeys[i] = "SubMaterial" .. i
end

local tune_nohdr = Vector(1, 0, 0)
local scratchVec = Vector()
local divisor = 2
local lastblurtime = 0
local lastcust = false

local fuckopengl = system.IsLinux() or system.IsOSX()
local dx11 = render.GetDXLevel() >= 110

local rt_cheapblur = GetRenderTargetEx("arc9_halfblur", scrw / divisor, scrh / divisor,
    RT_SIZE_LITERAL,
    MATERIAL_RT_DEPTH_NONE,
    bit.bor(2,4,8,256,512),
    0,
    -- 19 -- IMAGE_FORMAT_BGRA5551 -- doesn't work on nvidia lol
    IMAGE_FORMAT_RGBA8888
)

local mat_cheapblurresult = CreateMaterial("arc9_mat_halfblur", "UnlitGeneric", {
    ["$basetexture"] = rt_cheapblur:GetName(),
    ["$translucent"] = 1,
    ["$vertexcolor"] = 1,
    ["$ignorez"] = 1,
})

local function DrawCheapBlur(intensity, self, selfTbl)
    if dx11 then return end

    if not fuckopengl and intensity > 0 and system_HasFocus() then
        lastblurtime = FrameNumber()
        lastcust = selfTbl.GetCustomize(self)

        -- if GetConVar("meow"):GetBool() then
            render_UpdateScreenEffectTexture()
            render_SetToneMappingScaleLinear(tune_nohdr) -- Turns off hdr
            render_PushRenderTarget(rt_cheapblur)
                -- render.UpdateScreenEffectTexture()
                -- render.Clear(0,0,0,255)

                -- mat_cheapblur:SetFloat( "$c0_x", intensity )
                -- mat_cheapblur:SetFloat( "$c0_y", 16 * intensity )
                -- mat_cheapblur:SetFloat( "$c1_x", 1/scrw )
                -- mat_cheapblur:SetFloat( "$c1_y", 1/scrh )
                -- render.SetMaterial(mat_cheapblur)
                -- render.DrawScreenQuad()
                DrawBokehDOF(intensity, 1, 0)
            render_PopRenderTarget()
            render_SetMaterial(mat_cheapblurresult)
            render_DrawScreenQuad()
            -- render.DrawScreenQuadEx( 100, 700, scrw/3, scrh/3 )
        -- else
        --     DrawBokehDOF(intensity * 5, 1, 0)
        -- end
    end
end

-- split into a separate function, gmod was complaining about it using too many upvalues :/
local function preDrawBlurAndLight(self, selfTbl, getsights, sightamount, custdelta, curTime)
    local blurtarget = 0
    local blurenable = arc9_fx_rtblur
    local sightAtt = getsights.atttbl

    local shouldrtblur = sightamount > 0 and blurenable and not selfTbl.Peeking and sightAtt and sightAtt.RTScope and not getsights.Disassociate and not sightAtt.RTCollimator and not sightAtt.RTScopeNoBlur

    if shouldrtblur then
        blurtarget = 2 * sightamount
    end

    if (arc9_fx_reloadblur and selfTbl.GetReloading(self) and sightamount < 0.99) or (arc9_fx_animblur and selfTbl.GetReadyTime(self) >= curTime) or (arc9_fx_inspectblur and selfTbl.GetInspecting(self) and sightamount < 0.01) then
        blurtarget = 1.5
        shouldrtblur = true
    end

    if ARC9.StencilFuckery then render_SetStencilEnable(false) end

    if custdelta > 0 then
        if arc9_cust_blur then
            blurtarget = 5 * custdelta
        end

        cam_Start2D()
            surface_SetDrawColor(15, 15, 15, 180 * custdelta)
            surface_DrawRect(0, 0, scrw, scrh)
            surface_SetDrawColor(0, 0, 0, 255 * custdelta)
            if arc9_hud_lightmode then
                surface_SetMaterial(vignette)
                surface_DrawTexturedRect(0, 0, scrw, scrh)
            end

            if arc9_dev_greenscreen then
                surface_SetDrawColor(0, 255, 0, 255 * custdelta)
                surface_DrawRect(0, 0, scrw, scrh)
            end
        cam_End2D()
    end

    if (shouldrtblur and blurenable) or (custdelta > 0 and blurtarget > 0) then
        DrawCheapBlur(bluramt, self, selfTbl)
    end

    if ARC9.StencilFuckery then render_SetStencilEnable(true) end

    bluramt = math_Approach(bluramt, blurtarget, FrameTime() * 10)

    if arc9_cust_light and selfTbl.GetCustomize(self) then
        local light = DynamicLight(ENT_EntIndex(self), true)
        local up = ANG_Up(EyeAngles())
        VEC_Mul(up, 12)
        VEC_Add(up, EyePos())
        light.pos = up
        light.r = 255
        light.g = 255
        light.b = 255
        light.brightness = 0.2 * arc9_cust_light_brightness
        light.Decay = 1000
        light.Size = 500
        light.DieTime = curTime + 0.1
    end
end

local rt_prevm = GetRenderTargetEx("arc9_prevm", 1024, 1024,
    RT_SIZE_LITERAL,
    MATERIAL_RT_DEPTH_NONE,
    bit.bor(2,4,8,256,512),
    0,
    IMAGE_FORMAT_RGBA8888
)

hook.Add("ShouldDrawAmbientOcclusion", "ARC9.RemoveAO", function()
    -- if lastblurtime == FrameNumber() then return false end -- wanted to do it in every blur case but nah
    if lastblurtime == FrameNumber() and lastcust then return false end
end)

function SWEP:PreDrawViewModel(vm, weapon, ply, flags)
    flags = flags or STUDIO_RENDER
    local isDepthPass = bit_band(flags, STUDIO_DEPTH_MASK) ~= 0
    local selfTbl = ENT_GetTable(self)

    if ARC9.RTScopeRender and not isDepthPass then -- basically a copy of code in that func for rt barrels but without useless stuff and bad stuff, and also offset of cam in scope
        selfTbl.DoBodygroups(self, false)
        vm = selfTbl.GetVM(self)
        if selfTbl.HasSightsPoseparam then
            ENT_SetPoseParameter(vm, "sights", selfTbl.GetSightAmount(self))
        end
        selfTbl.SetFiremodePose(self)
        ENT_InvalidateBoneCache(vm)

        if ARC9_ENABLE_NEWSCOPES_MEOW then
            local worldvmpos, worldvmang = ENT_GetPos(vm), ENT_GetAngles(vm)
            local rtScopeMdl = selfTbl.RTScopeModel
            local scopelength = ((rtScopeMdl and ENT_IsValid(rtScopeMdl) and ENT_GetTable(rtScopeMdl).RTScopeLength) or 20) * 0.9

            local fwd = ANG_Forward(worldvmang)
            VEC_Mul(fwd, scopelength)
            VEC_Add(worldvmpos, fwd)

            local vmpos = LocalToWorld(-selfTbl.ViewModelPos, -selfTbl.ViewModelAng, worldvmpos, worldvmang)
            local vmang = MainEyeAngles()
            local funnyfov = selfTbl.WidescreenFix(self, selfTbl.GetViewModelFOV(self)) / selfTbl.GetRealZoom(self, selfTbl.GetSight(self))

            if not arc9_dev_benchgun then
                cam_Start3D(vmpos, vmang, funnyfov, nil, nil, nil, nil, 2, 16000)
            end
        else
            local vmagn = selfTbl.LastViewModelAng
            local sx, sy, sz = VEC_Unpack(selfTbl.GetSightPositions(self))

            VEC_Set(scratchVec, selfTbl.LastViewModelPos)
            local fwd = ANG_Forward(vmagn)
            local up = ANG_Up(vmagn)
            local right = ANG_Right(vmagn)
            VEC_Mul(fwd, sy - 15)
            VEC_Mul(up, sz)
            VEC_Mul(right, sx)
            VEC_Sub(scratchVec, fwd)
            VEC_Sub(scratchVec, up)
            VEC_Sub(scratchVec, right)

            if not arc9_dev_benchgun then
                cam_Start3D(scratchVec, nil, ARC9.RTScopeRenderFOV * 0.85, nil, nil, nil, nil, 3, 16000)
            end
        end
        render_DepthRange(0.1, 0.1)

        return
    end

    if ARC9.PresetCam then
        selfTbl.DoBodygroups(self, false)
        return
    end

    local getsights = selfTbl.GetSight(self)
    local sightamount = selfTbl.GetSightAmount(self)
    local custdelta = selfTbl.CustomizeDelta
    local curTime = CurTime()

    if not isDepthPass then
    	preDrawBlurAndLight(self, selfTbl, getsights, sightamount, custdelta, curTime)
    end

    selfTbl.DoPoseParams(self)
    selfTbl.DoBodygroups(self, false)

    local bipodamount = selfTbl.GetBipodAmount(self)
    vm = selfTbl.GetVM(self)
    if not vm or not ENT_IsValid(vm) then return end

    local sightsPoseVal = math_max(sightamount, bipodamount, custdelta)
    if selfTbl.HasSightsPoseparam then
        ENT_SetPoseParameter(vm, "sights", sightsPoseVal)
    end

    local bonemods = selfTbl.GetValue(self, "BoneMods")
    if bonemods then
        for bonename, k in pairs(bonemods) do
            local boneindex = ENT_LookupBone(vm, bonename)
            if not boneindex then continue end

            ENT_ManipulateBonePosition(vm, boneindex, k.pos or vector_origin)
            ENT_ManipulateBoneAngles(vm, boneindex, k.ang or angle_zero)
            ENT_ManipulateBoneScale(vm, boneindex, k.scale or vector_origin)
        end
    end

    local vmfov = selfTbl.GetViewModelFOV(self)
    selfTbl.ViewModelFOV = vmfov

    if not isDepthPass then
    	if not ARC9_ENABLE_NEWSCOPES_MEOW and selfTbl.GetHolsterTime(self) < curTime and selfTbl.RTScope and sightamount > 0 then
    	    selfTbl.DoRTScope(self, vm, selfTbl, true)
    	end

        if arc9_fx_adsblur_bleeding then
            render_UpdateScreenEffectTexture()
            render_CopyTexture(render_GetScreenEffectTexture(), rt_prevm)
        end
    end

    -- this if block is breaking the rendering context for several guns.
    -- ie: guns render behind hands and also render in world context, clipping into geometry
    -- disabling fixes that render issue outright but it's breaking Cheap RT Scopes' zooming.
    if not arc9_dev_benchgun then
        -- We use EyePos/EyeAngles so it doesn't inherit the zoomed world camera
        -- vmfov is whatever GetViewModelFOV() returns, it will remain static regardless of zoom
        cam_Start3D(EyePos(), EyeAngles(), selfTbl.WidescreenFix(self, vmfov), nil, nil, nil, nil, 0.5, 10000)
        render_DepthRange(0.0, 0.1)
    end

	selfTbl.RenderingRTScope = false

	if not isDepthPass then
        local gpv = selfTbl.GetProcessedValue
    	ENT_SetSubMaterial(vm)

        local matCount = selfTbl.VMMaterialAmount
        if not matCount and ENT_GetMaterials(vm) then
            local getmdl = ENT_GetModel(vm)
            local minfo = getmdl and util_GetModelInfo(getmdl)
            if not minfo then return end
            matCount = minfo.MaterialCount
            selfTbl.VMMaterialAmount = matCount
        end

    	for ind = 0, matCount or 31 do
    	    local key = subMaterialKeys[ind] or ("SubMaterial" .. ind)
            local val = gpv(self, key, true)
    	    if val then
    	        ENT_SetSubMaterial(vm, ind, val)
    	    end
    	end

    	ENT_SetMaterial(vm, gpv(self, "Material", true))
	end

    render_DepthRange(0.0, 0.1)
    if ARC9.PresetCam or custdelta > 0 then cam_IgnoreZ(true) end

    selfTbl.SetFiremodePose(self)

    if selfTbl.HasSightsPoseparam then
        ENT_SetPoseParameter(vm, "sights", sightsPoseVal)
    end

    ENT_InvalidateBoneCache(vm)

    if sightamount > 0.75 and getsights.FlatScope and not getsights.FlatScopeKeepVM then
        render_SetBlend(0)
    end
end

function SWEP:ViewModelDrawn(ent, flags)
	flags = flags or STUDIO_RENDER
    local isDepthPass = bit_band(flags, STUDIO_DEPTH_MASK) ~= 0
    local selfTbl = ENT_GetTable(self)

    selfTbl.StoredVMAngles = selfTbl.GetCameraControl(self)
    selfTbl.DrawCustomModel(self, false, nil, nil, flags)
    render_DepthRange(0.0, 0.1)

    selfTbl.DoRHIK(self)

    if ARC9.RTScopeRender then
        if not isDepthPass then
            render_DepthRange(0.1, 0.1)
            selfTbl.DrawLasers(self, false)
            render_DepthRange(0.0, 0.1)
        end
        return
    end

    selfTbl.PreDrawThirdArm(self)

	if not isDepthPass then
    	selfTbl.DrawFlashlightsVM(self)
    	selfTbl.DrawLasers(self, false)
	end

    local vm = selfTbl.GetVM(self)
    if not vm or not ENT_IsValid(vm) then return end

    ENT_SetMaterial(vm, "")
	for ind = 0, 31 do
		ENT_SetSubMaterial(vm, ind, "")
	end

    if not isDepthPass then
        local pcfs = selfTbl.PCFs
        if pcfs then
            local writeIdx = 0
            local count = #pcfs
            for i = 1, count do
                local pcf = pcfs[i]
                if pcf and CPE_IsValid(pcf) then
                    CPE_Render(pcf)
                    writeIdx = writeIdx + 1
                    if writeIdx ~= i then
                        pcfs[writeIdx] = pcf
                    end
                end
            end
            for i = writeIdx + 1, count do
                pcfs[i] = nil
            end
        end
	end

    local activeEffects = selfTbl.ActiveEffects
    if activeEffects then
        local writeIdx = 0
        local count = #activeEffects
        for i = 1, count do
            local fx = activeEffects[i]
            if fx and ENT_IsValid(fx) then
                if ENT_GetTable(fx).VMContext then
                    ENT_DrawModel(fx)
                    writeIdx = writeIdx + 1
                    if writeIdx ~= i then
                        activeEffects[writeIdx] = fx
                    end
                end
            end
        end
        for i = writeIdx + 1, count do
            activeEffects[i] = nil
        end
    end

    if ARC9.StencilFuckery then render_SetStencilEnable(false) end
end

local mat_dof = Material( "effects/arc9/vm_dof" )
local mat_dof2 = Material( "effects/arc9/vm_dof2" )
local mat_dof_debug = Material( "effects/arc9/vm_dof_debug" )
local mat_white = Material( "effects/arc9/whiteunlit" )
local mat_black = Material( "effects/arc9/blackunlit" )

local rt_dofmask = GetRenderTargetEx("arc9_optic_dof_mask2", scrw, scrh,
    RT_SIZE_FULL_FRAME_BUFFER,
    MATERIAL_RT_DEPTH_SHARED,
    bit.bor(4,8,256,512),
    0,
    5 -- IMAGE_FORMAT_I8
)

local function shadersetstaticvalues()
    local invW, invH = 1 / scrw, 1 / scrh
    local maskName = rt_dofmask:GetName()

    IMAT_SetFloat(mat_dof, "$c1_x", invW)
    IMAT_SetFloat(mat_dof, "$c1_y", invH)
    IMAT_SetTexture(mat_dof, "$texture1", maskName)
    IMAT_SetFloat(mat_dof, "$c0_x", 0) -- 8
    IMAT_SetFloat(mat_dof, "$c0_y", 0.07)

    IMAT_SetFloat(mat_dof2, "$c1_x", invW)
    IMAT_SetFloat(mat_dof2, "$c1_y", invH)
    IMAT_SetTexture(mat_dof2, "$texture1", maskName)
    IMAT_SetFloat(mat_dof2, "$c0_x", 0) -- 8
    IMAT_SetFloat(mat_dof2, "$c0_y", 0.07)
    IMAT_SetFloat(mat_dof2, "$c2_w", arc9_fx_adsblur_bleeding_amount)

    IMAT_SetTexture(mat_dof_debug, "$texture1", maskName)
    IMAT_SetFloat(mat_dof_debug, "$c0_y", 0.07)
end

timer.Simple(5, shadersetstaticvalues)

local mat_dof_mask_debug = CreateMaterial("mat_debug_arc9_dof_mask5", "UnlitGeneric", {
    ["$basetexture"] = rt_dofmask:GetName(),
    ["$translucent"] = 0,
    ["$vertexcolor"] = 1,
    ["$ignorez"] = 1,
    ["$additive"] = 1,
} )

function SWEP:DoFSetParams(strength)
    local selfTbl = ENT_GetTable(self)
    local s8 = 8 * strength
    IMAT_SetFloat(mat_dof, "$c0_x", s8)

    if arc9_fx_adsblur_bleeding then
        IMAT_SetFloat(mat_dof2, "$c0_x", s8)
        IMAT_SetFloat(mat_dof2, "$c2_w", arc9_fx_adsblur_bleeding_amount * strength)
    end

    if not selfTbl.DoFDepthSet then
        local depth = selfTbl.DoFDepth or 0.07
        shadersetstaticvalues()
        IMAT_SetFloat(mat_dof, "$c0_y", depth)
        IMAT_SetFloat(mat_dof2, "$c0_y", depth)
        selfTbl.DoFDepthSet = true
    end
end

function SWEP:RenderDoF()
    render_UpdateScreenEffectTexture()
    render_SetMaterial(arc9_fx_adsblur_bleeding and mat_dof2 or mat_dof)
    render_DrawScreenQuad()

    -- if ARC9.Dev(2) then
        -- render.SetMaterial(mat_dof_debug)
        -- render.DrawScreenQuadEx( 10, 100+scrh/2, scrw/4, scrh/4 )
        -- render.SetMaterial(mat_dof_mask_debug)
        -- render.DrawScreenQuadEx( 10, 100+scrh/2, scrw/4, scrh/4 )

        -- render.SetMaterial(mat_dof_debug)
        -- render.DrawScreenQuadEx( -100, 100+scrh/2, scrw/8, scrh/8 )
        -- render.SetMaterial(mat_black)
        -- render.DrawScreenQuadEx( -100, 100+scrh/2+scrh/8, scrw/8, scrh/8 )
        -- render.SetMaterial(mat_dof_mask_debug)
        -- render.DrawScreenQuadEx( -100, 100+scrh/2+scrh/8, scrw/8, scrh/8 )
    -- end
end

local retardedglassnames = {
    "models/weapons/arc9/mw2/mw2_optics/thermal_lens2",
    "models/weapons/arc9/mw3/mw3_optics/barrett_scope_glass",
    "___error",
}

local function findglassmat(scopemodel)
    local modelTbl = ENT_GetTable(scopemodel)
    if modelTbl.RTGlassMatIndex then
        return modelTbl.RTGlassMatIndex
    end

    local glassindex
    local mats = {}
    local rawMats = ENT_GetMaterials(scopemodel)
    if rawMats then
        for k = 1, #rawMats do
            mats[rawMats[k]] = k
        end
    end

    local blurTex = modelTbl.RTScope_BlurTexture
    if blurTex then
        glassindex = mats[blurTex]
    else
        glassindex = mats["effects/arc9/rtglass"] or mats["effects/arc9/rtglasssquare"] or mats["effects/arc9/rt"]

        if not glassindex then
            for i = 1, #retardedglassnames do
                glassindex = mats[retardedglassnames[i]]
                if glassindex then break end
            end
        end

        if not glassindex then
            local atttbl = modelTbl.atttbl
            if atttbl and atttbl.RTScopeSubmatIndex then
                glassindex = atttbl.RTScopeSubmatIndex + 1
            end
        end
    end

    glassindex = glassindex or 1
    modelTbl.RTGlassMatIndex = glassindex
    return glassindex
end

function SWEP:RenderDoFMask(clear)
    render_PushRenderTarget(rt_dofmask)
        render_Clear(0, 0, 0, 255)
    render_PopRenderTarget()

    if clear then return end

    local selfTbl = ENT_GetTable(self)
    local scopemodel = selfTbl.RTScopeModel
    if scopemodel == selfTbl.GetVM(self) then return end

    local forcedmodel = selfTbl.RTScope_ForceBlurModel
    local validScope = scopemodel and ENT_IsValid(scopemodel)
    local validForced = forcedmodel and ENT_IsValid(forcedmodel)

    if validScope or validForced then
        render_PushRenderTarget(rt_dofmask)
            -- render.Clear(0, 0, 0, 255)
            local oldtune = render_GetToneMappingScaleLinear()
            render_SetToneMappingScaleLinear(tune_nohdr) -- Turns off hdr
            render_ClearDepth(false)
            -- local sa = self:GetSightAmount()
            -- sa = sa * sa
            -- local sa = 1
            render_SetColorModulation(1, 1, 1)
            render_SuppressEngineLighting(true)

            if validScope then
                render_MaterialOverride(mat_black)
                render_MaterialOverrideByIndex(findglassmat(scopemodel) - 1, mat_white)
                ENT_DrawModel(scopemodel)
            end

            if validForced then
                render_MaterialOverrideByIndex(nil, nil)
                -- render_MaterialOverride()
                render_MaterialOverride(mat_black)
                render_MaterialOverrideByIndex(findglassmat(forcedmodel) - 1, mat_white)
                ENT_DrawModel(forcedmodel)
            end

            render_SetColorModulation(1, 1, 1)
            render_SuppressEngineLighting(false)
            render_MaterialOverride()
            render_MaterialOverrideByIndex(nil, nil)
        render_PopRenderTarget()

        render_SetToneMappingScaleLinear(oldtune) -- Resets hdr
    end
end


function SWEP:PostDrawViewModel(vm, weapon, ply, flags)
    local selfTbl = ENT_GetTable(self)
    local realVM = selfTbl.GetVM(self)
    if not realVM or not ENT_IsValid(realVM) then return end

	flags = flags or STUDIO_RENDER
    local isDepthPass = bit_band(flags, STUDIO_DEPTH_MASK) ~= 0
    local inrt = ARC9.RTScopeRender

    if not isDepthPass then
        selfTbl.DrawTranslucentPass(self, false, isDepthPass)

        local muzzPCFs = selfTbl.MuzzPCFs
        if muzzPCFs then
            if inrt then render_DepthRange(0.1, 0.1) end

            if inrt then
                for i = 1, #muzzPCFs do
                    local pcf = muzzPCFs[i]
                    if pcf and CPE_IsValid(pcf) then
                        CPE_Render(pcf)
                    end
                end
            else
                local writeIdx = 0
                local count = #muzzPCFs
                for i = 1, count do
                    local pcf = muzzPCFs[i]
                    if pcf and CPE_IsValid(pcf) then
                        CPE_Render(pcf)
                        writeIdx = writeIdx + 1
                        if writeIdx ~= i then
                            muzzPCFs[writeIdx] = pcf
                        end
                    end
                end
                for i = writeIdx + 1, count do
                    muzzPCFs[i] = nil
                end
            end
        end
    end

    if ARC9.PresetCam then return end

    cam_IgnoreZ(false)
    render_SetBlend(1)

    -- had to disable this too cause it saying throws errors after removing the earlier cam.Start3D which creates the render context issue.
    if not arc9_dev_benchgun then
        render_DepthRange(0.0, 1.0) -- Reset depth range
        cam_End3D()
    end

    if isDepthPass or inrt then return end

    local sigt, sa, notactivemask
    local activedof = not fuckopengl and not ARC9.IntelGPUDetected and arc9_fx_adsblur_new

    if activedof then
        sigt = selfTbl.GetSight(self)
        sa = selfTbl.GetSightAmount(self)
        local sightAtt = sigt.atttbl
        notactivemask = not (sightAtt and (sightAtt.RTScope or sightAtt.RTScopeNew_BlurTexture))
    end

    selfTbl.RenderingHolosight = false
    local getVMFOV = selfTbl.GetViewModelFOV
    cam_Start3D(nil, nil, selfTbl.WidescreenFix(self, getVMFOV and getVMFOV(self) or 90), nil, nil, nil, nil, 1, 10000)

    local vmodel = selfTbl.VModel
    if vmodel then
        local getFinalAttTable = selfTbl.GetFinalAttTable
        local doHolosight = selfTbl.DoHolosight

        for i = 1, #vmodel do
            local model = vmodel[i]
            if model and ENT_IsValid(model) then
                local modelTbl = ENT_GetTable(model)
                local atttbl = modelTbl.atttbl or getFinalAttTable(self, modelTbl.slottbl)

                if atttbl and atttbl.HoloSight then
                    doHolosight(self, model, atttbl)
                end
            end
        end

        if activedof then
            selfTbl.RenderDoFMask(self, notactivemask)
        end
    end
    cam_End3D()

    if activedof then
        if arc9_fx_adsblur_always then sa = 1 - selfTbl.CustomizeDelta end

        if sa > 0 then
            if sigt.Blur == false then sa = 0 end
            selfTbl.DoFSetParams(self, sa)
            -- selfTbl.RenderDoF(self)
        end
    end
end
