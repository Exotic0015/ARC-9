local LocalPlayer, RealFrameTime, Vector, tonumber, getmetatable =
      LocalPlayer, RealFrameTime, Vector, tonumber, getmetatable

local string_Explode, string_Replace =
      string.Explode, string.Replace

local math_ease_InExpo, math_min =
      math.ease.InExpo, math.min

local render_GetLightColor =
      render.GetLightColor

local ENT = FindMetaTable("Entity")
local ENT_GetTable, ENT_IsValid, ENT_GetOwner, ENT_GetPos =
      ENT.GetTable, ENT.IsValid, ENT.GetOwner, ENT.GetPos

local PLY = FindMetaTable("Player")
local PLY_GetActiveWeapon =
      PLY.GetActiveWeapon

local NPC = FindMetaTable("NPC")
local NPC_GetActiveWeapon =
      NPC.GetActiveWeapon

local IMAT = FindMetaTable("IMaterial")
local IMAT_GetTexture, IMAT_SetTexture, IMAT_GetFloat, IMAT_SetFloat, IMAT_SetUndefined, IMAT_Recompute =
      IMAT.GetTexture, IMAT.SetTexture, IMAT.GetFloat, IMAT.SetFloat, IMAT.SetUndefined, IMAT.Recompute
local IMAT_GetString, IMAT_SetString, IMAT_SetVector =
      IMAT.GetString, IMAT.SetString, IMAT.SetVector

local VEC = FindMetaTable("Vector")
local VEC_IsEqualTol, VEC_Unpack, VEC_Set, VEC_Mul =
      VEC.IsEqualTol, VEC.Unpack, VEC.Set, VEC.Mul

local function Lerp(delta, from, to)
    return from + (to - from) * delta
end

local function getActiveWeapon(owner)
    local mt = getmetatable(owner)
    if mt == PLY then return PLY_GetActiveWeapon(owner) end
    if mt == NPC then return NPC_GetActiveWeapon(owner) end
    return owner:GetActiveWeapon()
end

matproxy.Add({
    name = "CustomCamo",
    init = function(self, mat, values)
        local detailResult = values.camotexture
        local scaleResult = values.camoscale
        local blendResult = values.blend

        -- Store the name of the variable we want to set
        self.DetailResult = detailResult
        self.ScaleResult = scaleResult
        self.BlendResult = blendResult

        if detailResult then
            self.DefaultTexture = IMAT_GetTexture(mat, detailResult)
        end

        if scaleResult then
            self.DefaultScale = IMAT_GetFloat(mat, scaleResult)
        end

        if blendResult then
            self.DefaultBlend = IMAT_GetFloat(mat, blendResult)
        end
    end,
    bind = function(self, mat, ent)
        if not ent or not ENT_IsValid(ent) then return end
        local entTbl = ENT_GetTable(ent)
        if not entTbl then return end

        local detailResult = self.DetailResult
        if detailResult then
            local camoTex = entTbl.CustomCamoTexture
            if camoTex then
                IMAT_SetTexture(mat, detailResult, camoTex)
                self.ShouldRecomputeIfSet = true
            else
                IMAT_SetUndefined(mat, detailResult)
                if self.ShouldRecomputeIfSet then
                    IMAT_Recompute(mat)
                    self.ShouldRecomputeIfSet = false
                end
            end
        end

        local scaleResult = self.ScaleResult
        if scaleResult then
            local camoScale = entTbl.CustomCamoScale
            if camoScale then
                IMAT_SetFloat(mat, scaleResult, camoScale)
                self.ShouldRecomputeIfSet = true
            else
                local defScale = self.DefaultScale
                if defScale then
                    IMAT_SetFloat(mat, scaleResult, defScale)
                else
                    IMAT_SetUndefined(mat, scaleResult)
                    if self.ShouldRecomputeIfSet then
                        IMAT_Recompute(mat)
                        self.ShouldRecomputeIfSet = false
                    end
                end
            end
        end

        local blendResult = self.BlendResult
        if blendResult then
            local camoBlend = entTbl.CustomCamoBlend
            if camoBlend then
                IMAT_SetFloat(mat, blendResult, camoBlend)
                self.ShouldRecomputeIfSet = true
            else
                local defBlend = self.DefaultBlend
                if defBlend then
                    IMAT_SetFloat(mat, blendResult, defBlend)
                else
                    IMAT_SetUndefined(mat, blendResult)
                    if self.ShouldRecomputeIfSet then
                        IMAT_Recompute(mat)
                        self.ShouldRecomputeIfSet = false
                    end
                end
            end
        end
    end
})



--[[
    Advanced camo usage:


    "$detailblendmode" "4"
    "$detailblendfactor" "0.5"
    "$detailscale" "1.0"

    "$detailangle" 90.0
    "$attname" eft_ak12_stock_tube

    ...

    "Arc9CustomCamoAdvanced"
        {
            "camoTexture" $detail
            "camoScale" $detailscale
            "camoAngle" $detailangle
            "camoBlendMode" $detailblendmode
            "camoBlendFactor" $detailblendfactor
            "phonk" $phongboost
            "color" "[0.99 0.99 0.99]"
        }

        "TextureTransform"
        {
            "rotateVar" "$detailangle"
            "resultVar" "$detailtexturetransform"
        }

]]--

local fallbackCamo = {}

matproxy.Add({
    name = "Arc9CustomCamoAdvanced",
    init = function(self, mat, values)
        local detailResult = values.camotexture
        local phongResult = values.phonk
        local scaleResult = values.camoscale
        local angleResult = values.camoangle
        local blendModeResult = values.camoblendmode
        local blendFactorResult = values.camoblendfactor

        -- Store the name of the variable we want to set
        self.DetailResult = detailResult
        self.PhongResult = phongResult
        self.ScaleResult = scaleResult
        self.AngleResult = angleResult
        self.BlendModeResult = blendModeResult
        self.BlendFactorResult = blendFactorResult
        self.AttName = IMAT_GetString(mat, "$attname") or values.attname or ""

        if phongResult then self.DefaultPhong = IMAT_GetFloat(mat, phongResult) end
        if scaleResult then self.DefaultScale = IMAT_GetFloat(mat, scaleResult) end
        if angleResult then self.DefaultAngle = IMAT_GetFloat(mat, angleResult) end
        if blendFactorResult then self.DefaultFactor = IMAT_GetFloat(mat, blendFactorResult) end
        if detailResult then self.DefaultTexture = IMAT_GetTexture(mat, detailResult) end
    end,
    bind = function(self, mat, ent)
        if not ent or not ENT_IsValid(ent) then return end
        local entTbl = ENT_GetTable(ent)
        if not entTbl then return end

        local wep = entTbl.weapon
        if not (wep and ENT_IsValid(wep) and ENT_GetTable(wep).ARC9) then
            local owner = ENT_GetOwner(ent)
            wep = (owner and ENT_IsValid(owner)) and getActiveWeapon(owner) or nil
        end

        local camo
        if wep and ENT_IsValid(wep) then
            local wepTbl = ENT_GetTable(wep)
            if wepTbl then
                local slottbl = entTbl.slottbl
                local maybeaddress = slottbl and slottbl.Address
                local getAdvCamo = wepTbl.GetAdvancedCamo
                if getAdvCamo then
                    camo = getAdvCamo(wep, self.AttName, maybeaddress)
                    if camo and not camo.Texture then camo = nil end
                end

                if not camo and entTbl.CustomCamoTexture and wepTbl.AdvancedCamoCache == false then
                    fallbackCamo.Texture = entTbl.CustomCamoTexture
                    camo = fallbackCamo
                end
            end
        end

        local detailResult = self.DetailResult
        if camo and camo.Texture and detailResult then
            IMAT_SetTexture(mat, detailResult, camo.Texture)

            local phongResult = self.PhongResult
            if phongResult then
                local phongMult = camo.PhongMult
                IMAT_SetFloat(mat, phongResult, (self.DefaultPhong or 1) * (phongMult or 0.1))
                if phongMult and phongMult <= 0.1 then
                    entTbl.PhongMultSoLowerEnvmapPls = true
                end
            end

            local scaleResult = self.ScaleResult
            if scaleResult then IMAT_SetFloat(mat, scaleResult, (self.DefaultScale or 1) * (camo.Scale or 1)) end

            local angleResult = self.AngleResult
            if angleResult then IMAT_SetFloat(mat, angleResult, (self.DefaultAngle or 0) + (camo.Rotate or 0)) end

            local blendModeResult = self.BlendModeResult
            if blendModeResult then IMAT_SetFloat(mat, blendModeResult, camo.BlendMode or 4) end

            local blendFactorResult = self.BlendFactorResult
            if blendFactorResult then IMAT_SetFloat(mat, blendFactorResult, (self.DefaultFactor or 1) * (camo.Factor or 0.5)) end

            self.ShouldRecomputeIfSet = true
        elseif detailResult then
            IMAT_SetUndefined(mat, detailResult)
            if self.PhongResult then
                IMAT_SetFloat(mat, self.PhongResult, self.DefaultPhong or 0)
            end
            entTbl.PhongMultSoLowerEnvmapPls = nil
            if self.ShouldRecomputeIfSet then
                IMAT_Recompute(mat)
                self.ShouldRecomputeIfSet = false
            end
        end
    end
})

matproxy.Add({
    name = "ARC9_Heat",
    init = function(self, mat, values)
        self.BlendResult = values.blend
    end,
    bind = function(self, mat, ent)
        if not ent or not ENT_IsValid(ent) then return end

        local entTbl = ENT_GetTable(ent)
        local entWep = entTbl and entTbl.weapon
        if entWep and ENT_IsValid(entWep) then
            ent = entWep
        end

        local owner = ENT_GetOwner(ent)
        local weapon = (owner and ENT_IsValid(owner)) and getActiveWeapon(owner) or nil

        if weapon and ENT_IsValid(weapon) then
            local wepTbl = ENT_GetTable(weapon)
            if wepTbl and wepTbl.ARC9 and wepTbl.GetProcessedValue(weapon, "Overheat", true) then
                local heat = wepTbl.GetHeatAmount(weapon)
                local cap = wepTbl.GetProcessedValue(weapon, "HeatCapacity", true)
                IMAT_SetFloat(mat, self.BlendResult, math_ease_InExpo(heat / cap) * 2)
                return
            end
        end

        IMAT_SetFloat(mat, self.BlendResult, 0)
    end
})

local lastPos = Vector()
local lastValue = 0
local tintVec = Vector()

matproxy.Add({
	name = "Arc9EnvMapTint",
	init = function(self, mat, values)
		local color = {1, 1, 1}

		if values.color ~= nil then
			color = string_Explode(" ", string_Replace(string_Replace(values.color, "[", ""), "]", ""))
		end

		self.min = tonumber(values.min) or 0
		self.max = tonumber(values.max) or 1
		self.color = Vector(tonumber(color[1]) or 1, tonumber(color[2]) or 1, tonumber(color[3]) or 1)

		if values.envmap ~= "env_cubemap" then
		   IMAT_SetTexture(mat, "$envmap", values.envmap or "arc9/shared/envmaps/specularity_50")
		else
		   IMAT_SetString(mat, "$envmap", "env_cubemap")
		end
	end,
	bind = function(self, mat, ent)
        if not ent or not ENT_IsValid(ent) then return end
        local entTbl = ENT_GetTable(ent)
        if not entTbl then return end

        local getpos = ENT_GetPos(ent)
        if not VEC_IsEqualTol(lastPos, getpos, 1) then
            local r, g, b = VEC_Unpack(render_GetLightColor(getpos))
            lastValue = math_min(((r * 0.2126) + (g * 0.7152) + (b * 0.0722)) * 2, 1)
            lastPos = getpos
        end

        local tint = Lerp(10 * RealFrameTime(), entTbl.m_Arc9EnvMapTint or 0, lastValue)
        if entTbl.PhongMultSoLowerEnvmapPls then
            tint = tint * 0.3
        end
        entTbl.m_Arc9EnvMapTint = tint

        VEC_Set(tintVec, self.color)
        VEC_Mul(tintVec, Lerp(tint, self.min, self.max))
        IMAT_SetVector(mat, "$envmaptint", tintVec)
	end
})

----- Add this to your VMT to fix garbage/shitty reflection

    -- "Proxies"
    -- {
        -- "Arc9EnvMapTint"
        -- {
            -- "specularity" "0.5"
            -- "min" "0"
            -- "max" "0.2" // Change this if its too bright in game
        -- }
    -- }
-- }


matproxy.Add({
    name = "arc9_scope_alpha",
    init = function(self, mat, values)
        self.ResultTo = values.resultvar

		local color = {1, 1, 1}

		if values.color ~= nil then
			color = string_Explode(" ", string_Replace(string_Replace(values.color, "[", ""), "]", ""))
		end

		self.min = tonumber(values.min) or 0
		self.max = tonumber(values.max) or 1
		self.color = Vector(tonumber(color[1]) or 1, tonumber(color[2]) or 1, tonumber(color[3]) or 1)
    end,
    bind = function(self, mat, ent)
        if not ent or not ENT_IsValid(ent) then return end

        local ply = LocalPlayer()
        if not ply or not ENT_IsValid(ply) then return end

        local weapon = PLY_GetActiveWeapon(ply)
        if not weapon or not ENT_IsValid(weapon) then return end

        local wepTbl = ENT_GetTable(weapon)
        if not wepTbl or not wepTbl.ARC9 then return end

        local entTbl = ENT_GetTable(ent)
        if not entTbl then return end

        local amt = 1 - wepTbl.GetSightAmount(weapon) * 0.25

        local getpos = ENT_GetPos(ent)
        if not VEC_IsEqualTol(lastPos, getpos, 1) then
            local r, g, b = VEC_Unpack(render_GetLightColor(getpos))
            lastValue = math_min(((r * 0.2126) + (g * 0.7152) + (b * 0.0722)) * 2, 1)
            lastPos = getpos
        end

        local tint = Lerp(10 * RealFrameTime(), entTbl.m_Arc9EnvMapTint or 0, lastValue)
        entTbl.m_Arc9EnvMapTint = tint

        VEC_Set(tintVec, self.color)
        VEC_Mul(tintVec, Lerp(tint * amt, self.min, self.max))
        IMAT_SetVector(mat, "$envmaptint", tintVec)
   end
})
