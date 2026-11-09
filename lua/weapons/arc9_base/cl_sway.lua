local Lerp, FrameTime, EyeAngles =
      Lerp, FrameTime, EyeAngles

local math_Clamp =
      math.Clamp

local ENT = FindMetaTable("Entity")
local ENT_GetTable, ENT_IsValid =
      ENT.GetTable, ENT.IsValid

SWEP.ViewModelVelocityPos = Vector()
SWEP.ViewModelVelocityAng = Angle()
SWEP.ViewModelPos = Vector()
SWEP.ViewModelAng = Angle()

local lasteyeang = Angle()
local smootheyeang = Angle()
local posoffset = Vector()
local smoothswayroll = 0
local smoothswaypitch = 0

function SWEP:GetViewModelSway(pos, ang)
    local selfTbl = ENT_GetTable(self)

    local ft = FrameTime()
    local sightmult = 0.5 + math_Clamp(1/ft/100, 0, 5) -- for consistent offset on high and low fps
    sightmult = sightmult * Lerp(selfTbl.GetSightAmount(self), 1, 0.25)

    smootheyeang = LerpAngle(math_Clamp(ft * 24, 0.075, 1), smootheyeang, EyeAngles() - lasteyeang)
    lasteyeang = EyeAngles()

    smoothswayroll = Lerp(math_Clamp(ft * 24, 0.075, 1), smoothswayroll, smootheyeang.y)
    if selfTbl.SprintVerticalOffset then
        -- local sprintoffset = (ang.p * 0.06) * Lerp(self:GetSprintAmount(), 0, 1)
        -- print(sprintoffset)
        -- pos:Add(ang:Up() * sprintoffset)
        -- pos:Add(ang:Forward() * sprintoffset)

        -- old thing was wrong as it used vm ang pitch and not eyes pitch so value was  always offsetted by 1.2
        -- so sprint pos was incorrect
        -- keeping it to not mess up old guns

        local sprintoffset = math_Clamp(EyeAngles().p * 0.1, -9, 4.5)
        local sprintoffset2 = sprintoffset + 1.2
        local lerrppp = Lerp(selfTbl.GetSprintAmount(self), 0, 1)
        sprintoffset, sprintoffset2 = sprintoffset * lerrppp, sprintoffset2 * lerrppp

        pos:Add(ang:Up() * (sprintoffset2 + 10) * 0.1 * lerrppp)
        pos:Add(ang:Right() * sprintoffset2 * 0.2)
        pos:Add(ang:Forward() *  (sprintoffset2 + 10) * 0.1 * lerrppp)
        ang.z = ang.z + math.min(0, sprintoffset * -6)
        ang.y = ang.y + math.min(0, sprintoffset * -2)
    end

    smootheyeang.p = math_Clamp(smootheyeang.p * 0.95, -10, 10)
    smootheyeang.y = math_Clamp(smootheyeang.y * 0.9, -4, 4)
    smootheyeang.r = math_Clamp(smoothswayroll * (0.5 + math_Clamp(ft * 64, 0, 4)), -2, 2)

    local inertiaanchor = Vector(selfTbl.CustomizeRotateAnchor)
    inertiaanchor.x = inertiaanchor.x * 0.75

    pos:Add(ang:Up() * smootheyeang.p * 0.075 * sightmult)
    pos:Add(ang:Right() * smootheyeang.y * -0.1 * sightmult)

    local rap_pos, rap_ang = selfTbl.RotateAroundPoint2(self, pos, ang, inertiaanchor, vector_origin, smootheyeang * sightmult)
    pos:Set(rap_pos)
    ang:Set(rap_ang)

    return pos, ang
end

SWEP.ViewModelLastEyeAng = Angle()
SWEP.ViewModelSwayInertia = Angle()

function SWEP:GetViewModelInertia(pos, ang)
    local eyeangg = self:GetOwner():EyeAngles()
    local ft = FrameTime()

    local selfTbl = ENT_GetTable(self)

    local d = 1 - selfTbl.GetSightAmount(self)
    local diff = eyeangg - selfTbl.ViewModelLastEyeAng
    diff = diff * 0.25
    diff.p = math_Clamp(diff.p, -1, 1)
    diff.y = math_Clamp(diff.y, -1, 1)
    local vsi = selfTbl.ViewModelSwayInertia
    vsi.p = math.ApproachAngle(vsi.p, diff.p, vsi.p / 10 * ft / 0.5)
    vsi.y = math.ApproachAngle(vsi.y, diff.y, vsi.y / 10 * ft / 0.5)
    selfTbl.ViewModelLastEyeAng = eyeangg
    ang:RotateAroundAxis(ang:Up(), vsi.y * 12 * d)
    ang:RotateAroundAxis(ang:Right(), -vsi.p * 12 * d)
    -- pos = pos - (ang:Up() * vsi.p * 0.5 * d)
    -- pos = pos - (ang:Right() * vsi.y * 0.5 * d)

    return pos, ang
end

function SWEP:GetViewModelSmooth(pos, ang)
    return pos, ang
end

SWEP.ViewModelBobVelocity = 0
SWEP.ViewModelNotOnGround = 0
SWEP.BobCT = 0

local v = 0

local offset = Vector()
local affset = Angle()

local airtime = 0

local stammer = 0
local stammer_moving = false

local function FesiugBob(self, pos, ang)
    local selfTbl = ENT_GetTable(self)

    if selfTbl.GetCustomize(self) then return pos, ang end
    local owner = self:GetOwner()

    local sharedmult = selfTbl.GetIsSprinting(self) and selfTbl.GetProcessedValue(self, "BobSprintMult", true) or selfTbl.GetProcessedValue(self, "BobWalkMult", true)

    local cv = owner:GetVelocity():Length()
    v = math.Approach(v, cv, FrameTime()*400/0.4)
    v = math_Clamp(v, 0, 400)
    local tv = v / 400
    tv = tv * 1.1
    local mulp = Lerp(selfTbl.GetSightDelta(self), 1, 0.15)
    local mulk = Lerp(selfTbl.GetSightDelta(self), 1, 0.3)
    local tk = tv * mulk
    tv = tv * mulp
    selfTbl.BobScale = 0
    local p = math.pi
    local spe = selfTbl.GetIsSprinting(self)

    local grounded = (owner:IsOnGround() or owner:GetMoveType() == MOVETYPE_NOCLIP)
    airtime = math.Approach(airtime, (grounded and 0 or 1), FrameTime()*5*(grounded and 10 or 1))

    offset:Set(vector_origin)
    affset:Set(angle_zero)

    local ct = ( (CurTime() * 1.1) % (0.975 * ((1/1.1)+0.1)) )

    offset.x = offset.x + math.sin( ct * p * 2 ) * 0.2 * ( spe and -2 or 1 )
    offset.y = offset.y + math.pow(math.sin( ct * p * 2 ), 2) * -0.5 * ( spe and -2 or 1 )
    offset.z = offset.z + math.abs(math.sin( ct * p * -1 )) * -0.15

    offset.z = offset.z + math.pow(math.abs( math.sin(ct * p * 2) ), 6) * -0.395 * ( spe and -4 or 0 )

    offset.z = offset.z + ( (-0.395/2)*3 * tv )

    offset.z = offset.z + ( math.pow(math.sin((ct+0)*p*2.5), 2) * -0.3 )
    offset.z = offset.z + ( math.pow(math.sin((ct+0.3)*p*2.5), 2) * -0.3 )

    affset.x = affset.x - ( math.pow( math.sin( ct * p ) * 2.2, 2 ) - ( (2.2/2) * tv ) ) * ( spe and 2 or 1 )
    affset.y = affset.y + math.sin( ct * p * -(3) ) * 0.5 * 1.5
    affset.z = affset.z + ( ( ((ct/2) % 1) < 0.5 and -1 or 2 ) * math.sin( ct * p * 2 ) * 2 * 1.5 ) * ( spe and 2 or 1 )
    affset.z = affset.z + ( ( ((ct/2) % 1) > 0.5 and -1 or 2 ) * math.sin( ct * p * 2 ) * 2 * 1.5 ) * ( spe and 2 or 1 )

    affset.x = affset.x + ( (-2) * tv )

    pos:Add( ang:Right()     *   offset.x * tv * sharedmult )
    pos:Add( ang:Forward()   *   offset.y * tv * sharedmult )
    pos:Add( ang:Up()        *   offset.z * tv * sharedmult )

    local stammertime_pos = Vector()
    local stammertime_ang = Angle()

    local pep = owner:KeyDown(IN_FORWARD) or owner:KeyDown(IN_BACK) or owner:KeyDown(IN_MOVELEFT) or owner:KeyDown(IN_MOVERIGHT)
    if tk > 0.1 then
        stammer = 1
        stammer_moving = true
    else
        stammer_moving = false
        stammer = math.Approach(stammer, 0, FrameTime()*3)
    end
    local elistam = (!pep and stammer or 0)*Lerp(selfTbl.GetSightDelta(self), 1, 0.3)

    stammertime_pos.x = stammertime_pos.x + math.sin( ct * p * 5*1.334 ) * -0.05
    stammertime_pos.y = stammertime_pos.y + elistam*-0.5
    stammertime_pos.z = stammertime_pos.z + elistam*-0.25
    stammertime_ang.y = stammertime_ang.y + math.sin( ct * p * 2*1.334 ) * 0.8
    stammertime_ang.z = stammertime_ang.z + math.sin( ct * p * 5*1.334 ) * 0.5

    pos:Add( ang:Right()     *   stammertime_pos.x * elistam * sharedmult )
    pos:Add( ang:Forward()   *   stammertime_pos.y * elistam * sharedmult )
    pos:Add( ang:Up()        *   stammertime_pos.z * elistam * sharedmult )

    ang:RotateAroundAxis( ang:Forward(),        affset.x * tv * sharedmult )
    ang:RotateAroundAxis( ang:Right(),          affset.y * tv * sharedmult )
    ang:RotateAroundAxis( ang:Up(),             affset.z * tv * sharedmult )

    ang:RotateAroundAxis( ang:Forward(),        stammertime_ang.x * elistam * sharedmult )
    ang:RotateAroundAxis( ang:Right(),          stammertime_ang.y * elistam * sharedmult )
    ang:RotateAroundAxis( ang:Up(),             stammertime_ang.z * elistam * sharedmult )
    ang:RotateAroundAxis( ang:Up(),             (owner:KeyDown(IN_MOVELEFT) and 2 or owner:KeyDown(IN_MOVERIGHT) and -2 or 0) * tv )

    ang:RotateAroundAxis( ang:Forward(),          math.sin( ct * p * 1 ) * airtime*-5 * mulp * 2)
    ang:RotateAroundAxis( ang:Right(),          ( math.sin( ct * p * 1 ) * airtime*3 * mulp ) + ( (3/2) * airtime * mulp ) )
    ang:RotateAroundAxis( ang:Up(),          math.sin( ct * p * 2 ) * airtime*2 * mulp )

    return pos, ang
end

local function ArcticBob(self, pos, ang)
    local selfTbl = ENT_GetTable(self)

    local step = 10
    local mag = 1
    local ts = 0 -- self:GetTraversalSprintAmount()
    -- ts = 1
    if selfTbl.GetCustomize(self) then return pos, ang end

    local owner = self:GetOwner()
    local ft = FrameTime()

    local sharedmult = selfTbl.GetIsSprinting(self) and selfTbl.GetProcessedValue(self, "BobSprintMult", true) or selfTbl.GetProcessedValue(self, "BobWalkMult", true)

    local v = owner:GetVelocity():Length()
    v = math_Clamp(v, 0, 350)
    selfTbl.ViewModelBobVelocity = math.Approach(selfTbl.ViewModelBobVelocity, v, ft * 10000)
    local d = math_Clamp(selfTbl.ViewModelBobVelocity / 350, 0, 1)

    if owner:OnGround() and owner:GetMoveType() != MOVETYPE_NOCLIP then
        selfTbl.ViewModelNotOnGround = math.Approach(selfTbl.ViewModelNotOnGround, 0, ft / 0.1)
    else
        selfTbl.ViewModelNotOnGround = math.Approach(selfTbl.ViewModelNotOnGround, 1, ft / 0.1)
    end

    d = d * Lerp(selfTbl.GetSightAmount(self), 1, 0.5) * Lerp(ts, 1, 1.5)
    mag = d * 2
    mag = mag * Lerp(ts, 1, 1.5)
    step = 10
    ang:RotateAroundAxis(ang:Forward(), math.sin(selfTbl.BobCT * step * 0.5) * ((math.sin(selfTbl.BobCT * 6.151) * 0.2) + 1) * 4.5 * d * sharedmult)
    ang:RotateAroundAxis(ang:Right(), math.sin(selfTbl.BobCT * step * 0.12) * ((math.sin(selfTbl.BobCT * 1.521) * 0.2) + 1) * 2.11 * d * sharedmult)
    pos = pos - (ang:Up() * math.sin(selfTbl.BobCT * step) * 0.1 * ((math.sin(selfTbl.BobCT * 3.515) * 0.2) + 1) * mag * sharedmult)
    pos = pos + (ang:Forward() * math.sin(selfTbl.BobCT * step * 0.3) * 0.11 * ((math.sin(selfTbl.BobCT * 2) * ts * 1.25) + 1) * ((math.sin(selfTbl.BobCT * 1.615) * 0.2) + 1) * mag * sharedmult)
    pos = pos + (ang:Right() * (math.sin(selfTbl.BobCT * step * 0.15) + (math.cos(selfTbl.BobCT * step * 0.3332))) * 0.16 * mag * sharedmult)

    local steprate = Lerp(d, 1, 2.5)
    steprate = Lerp(selfTbl.ViewModelNotOnGround, steprate, 0.25)

    if IsFirstTimePredicted() or game.SinglePlayer() then
        selfTbl.BobCT = selfTbl.BobCT + (ft * steprate)
    end

    return pos, ang
end

local smoothsidemove = 0
local smoothjumpmove = 0

local function ArcticBreadBob(self, pos, ang)
    local selfTbl = ENT_GetTable(self)

    local step = 10
    local mag = 1
    local ts = 0 -- self:GetTraversalSprintAmount()
    -- ts = 1
    if selfTbl.GetCustomize(self) then return pos, ang end

    local owner = self:GetOwner()
    local ft = FrameTime()

    local sharedmult = selfTbl.GetIsSprinting(self) and selfTbl.GetProcessedValue(self, "BobSprintMult", true) or selfTbl.GetProcessedValue(self, "BobWalkMult", true)

    local velocityangle = owner:GetVelocity()
    local v = velocityangle:Length()
    v = math_Clamp(v, 0, 350)
    selfTbl.ViewModelBobVelocity = math.Approach(selfTbl.ViewModelBobVelocity, v, ft * 10000)
    local d = math_Clamp(selfTbl.ViewModelBobVelocity / 350, 0, 1)

    if owner:OnGround() and owner:GetMoveType() != MOVETYPE_NOCLIP then
        selfTbl.ViewModelNotOnGround = math.Approach(selfTbl.ViewModelNotOnGround, 0, ft / 0.1)
    else
        selfTbl.ViewModelNotOnGround = math.Approach(selfTbl.ViewModelNotOnGround, 1, ft / 0.1)
    end

    local sightamount = selfTbl.GetSightAmount(self)

    d = d * Lerp(sightamount, 1,0.03) * Lerp(ts, 1, 1.5)
    mag = d * 2
    mag = mag * Lerp(ts, 1, 2)
    step = 10

    -- local sidemove = ((owner:KeyDown(IN_MOVERIGHT) and 1 or 0) - (owner:KeyDown(IN_MOVELEFT) and 1 or 0)) * 8 * (1.1-sightamount)
    local sidemove = (owner:GetVelocity():Dot(owner:EyeAngles():Right()) / owner:GetMaxSpeed()) * 4 * (1.5-sightamount)
    smoothsidemove = Lerp(math_Clamp(ft*8, 0, 1), smoothsidemove, sidemove)

    local crouchmult = 1
    if owner:Crouching() then
        crouchmult = 3.5 + sightamount* 10
        step = 6
    end

    local jumpmove = math_Clamp(math.ease.InExpo(math_Clamp(velocityangle.z, -150, 0)/-150)*0.5 + math.ease.InExpo(math_Clamp(velocityangle.z, 0, 350)/350)*-50, -4, 2.5) * 0.5   -- crazy math for jump movement
    smoothjumpmove = Lerp(math_Clamp(ft*8, 0, 1), smoothjumpmove, jumpmove)
    local smoothjumpmove2 = math_Clamp(smoothjumpmove, -0.3, 0.01) * (1.5-sightamount)


    if owner.GetSliding then if owner:GetSliding() then mag = 0 step = 5 smoothsidemove = 0 end end

    if selfTbl.GetIsSprinting(self) then
        pos = pos - (ang:Up() * math.sin(selfTbl.BobCT * step) * 0.45 * ((math.sin(selfTbl.BobCT * 3.515) * 0.2) + 1) * mag * sharedmult)
        pos = pos + (ang:Forward() * math.sin(selfTbl.BobCT * step * 0.3) * 0.11 * ((math.sin(selfTbl.BobCT * 2) * ts * 1.25) + 1) * ((math.sin(selfTbl.BobCT * 0.615) * 0.2) + 2) * mag * sharedmult)
        pos = pos + (ang:Right() * (math.sin(selfTbl.BobCT * step * 0.5) + (math.cos(selfTbl.BobCT * step * 0.5))) * 0.55 * mag * sharedmult)
        ang:RotateAroundAxis(ang:Forward(), math.sin(selfTbl.BobCT * step * 0.5) * ((math.sin(selfTbl.BobCT * 6.151) * 0.2) + 1) * 9 * d * sharedmult + smoothsidemove * 1.5)
        ang:RotateAroundAxis(ang:Right(), math.sin(selfTbl.BobCT * step * 0.12) * ((math.sin(selfTbl.BobCT * 1.521) * 0.2) + 1) * 1 * d * sharedmult)
        ang:RotateAroundAxis(ang:Up(), math.sin(selfTbl.BobCT * step * 0.5) * ((math.sin(selfTbl.BobCT * 1.521) * 0.2) + 1) * 6 * d * sharedmult)
        ang:RotateAroundAxis(ang:Right(), smoothjumpmove2 * 5)
    else
        pos = pos - (ang:Up() * math.sin(selfTbl.BobCT * step) * 0.1 * ((math.sin(selfTbl.BobCT * 3.515) * 0.2) + 2) * mag * crouchmult * sharedmult) - (ang:Up() * smoothsidemove * -0.05) - (ang:Up() * smoothjumpmove2 * 0.2)
        pos = pos + (ang:Forward() * math.sin(selfTbl.BobCT * step * 0.3) * 0.11 * ((math.sin(selfTbl.BobCT * 2) * ts * 1.25) + 1) * ((math.sin(selfTbl.BobCT * 0.615) * 0.2) + 1) * mag * sharedmult)
        pos = pos + (ang:Right() * (math.sin(selfTbl.BobCT * step * 0.5) + (math.cos(selfTbl.BobCT * step * 0.5))) * 0.55 * mag * sharedmult)
        ang:RotateAroundAxis(ang:Forward(), math.sin(selfTbl.BobCT * step * 0.5) * ((math.sin(selfTbl.BobCT * 6.151) * 0.2) + 1) * 5 * d * sharedmult + smoothsidemove)
        ang:RotateAroundAxis(ang:Right(), math.sin(selfTbl.BobCT * step * 0.12) * ((math.sin(selfTbl.BobCT * 1.521) * 0.2) + 1) * 0.1 * d * sharedmult)
        ang:RotateAroundAxis(ang:Right(), smoothjumpmove2 * 5)
    end

    local steprate = Lerp(d, 1, 2.75)
    steprate = Lerp(selfTbl.ViewModelNotOnGround, steprate, 0.75)

    if IsFirstTimePredicted() or game.SinglePlayer() then
        selfTbl.BobCT = selfTbl.BobCT + (ft * steprate)
    end

    return pos, ang
end


local function ArcticBreadDarsuBob(self, pos, ang)
    local selfTbl = ENT_GetTable(self)

    local step = 10
    local mag = 1
    local ts = 0 -- self:GetTraversalSprintAmount()
    -- ts = 1
    if selfTbl.GetCustomize(self) then return pos, ang end

    local owner = self:GetOwner()
    local ft = FrameTime()

    local sharedmult = selfTbl.GetIsSprinting(self) and selfTbl.GetProcessedValue(self, "BobSprintMult", true) or selfTbl.GetProcessedValue(self, "BobWalkMult", true)
    local velocityangle = owner:GetVelocity()
    local v = velocityangle:Length()
    v = math_Clamp(v, 0, 350)
    selfTbl.ViewModelBobVelocity = math.Approach(selfTbl.ViewModelBobVelocity, v, ft * 10000)
    local d = math_Clamp(selfTbl.ViewModelBobVelocity / 350, 0, 1)
    -- d = math.ease.InSine(d)
    if owner:OnGround() and owner:GetMoveType() != MOVETYPE_NOCLIP then
        selfTbl.ViewModelNotOnGround = math.Approach(selfTbl.ViewModelNotOnGround, 0, ft / 0.1)
    else
        selfTbl.ViewModelNotOnGround = math.Approach(selfTbl.ViewModelNotOnGround, 1, ft / 0.1)
    end

    local sightamount = selfTbl.GetSightAmount(self) - ((selfTbl.Peeking and not selfTbl.PeekingIsSight) and 0.72 or 0.1)

    d = d * Lerp(sightamount, 1,0.03) * Lerp(ts, 1, 1.5)
    mag = d * 2
    mag = mag * Lerp(ts, 1, 2)
    step = 9.25

    local sidemove = (owner:GetVelocity():Dot(owner:EyeAngles():Right()) / owner:GetMaxSpeed()) * 4 * (1.5-sightamount)
    -- local sidemove = ((owner:KeyDown(IN_MOVERIGHT) and 1 or 0) - (owner:KeyDown(IN_MOVELEFT) and 1 or 0)) * 3 * (1.5-sightamount)
    smoothsidemove = Lerp(math_Clamp(ft*8, 0, 1), smoothsidemove, sidemove)

    local crouchmult = 1
    if owner:Crouching() then
        crouchmult = 3.5 + sightamount * 3
        step = 6
    end

    local jumpmove = math_Clamp(math.ease.InExpo(math_Clamp(velocityangle.z, -150, 0)/-150)*0.5 + math.ease.InExpo(math_Clamp(velocityangle.z, 0, 350)/350)*-50, -4, 2.5) * 0.5   -- crazy math for jump movement
    smoothjumpmove = Lerp(math_Clamp(ft*8, 0, 1), smoothjumpmove, jumpmove)
    local smoothjumpmove2 = math_Clamp(smoothjumpmove, -0.3, 0.01) * (1.5-sightamount) * 2


    if owner.GetSliding then if owner:GetSliding() then mag = 0 step = 5 smoothsidemove = 0 end end


    if selfTbl.GetIsSprinting(self) then
        pos = pos - (ang:Up() * math.sin(selfTbl.BobCT * step) * 0.45 * ((math.sin(selfTbl.BobCT * 3.515) * 0.2) + 1) * mag * sharedmult)
        pos = pos + (ang:Forward() * math.sin(selfTbl.BobCT * step * 0.3) * 0.13 * ((math.sin(selfTbl.BobCT * 2) * ts * 1.25) + 2) * ((math.sin(selfTbl.BobCT * 0.615) * 0.2) + 2) * mag * sharedmult)
        pos = pos + (ang:Right() * (math.sin(selfTbl.BobCT * step * 0.5) + (math.cos(selfTbl.BobCT * step * 0.5))) * 0.55 * mag * sharedmult)
        ang:RotateAroundAxis(ang:Forward(), math.sin(selfTbl.BobCT * step * 0.5) * ((math.sin(selfTbl.BobCT * 6.151) * 0.2) + 1) * 6 * d * sharedmult + smoothsidemove * 1.5)
        ang:RotateAroundAxis(ang:Right(), math.sin(selfTbl.BobCT * step * 0.12) * ((math.sin(selfTbl.BobCT * 1.521) * 0.2) + 1) * 1 * d * sharedmult)
        ang:RotateAroundAxis(ang:Up(), math.sin(selfTbl.BobCT * step * 0.5) * ((math.sin(selfTbl.BobCT * 1.521) * 0.2) + 1) * 3 * d * sharedmult)
        ang:RotateAroundAxis(ang:Right(), smoothjumpmove2 * 5)
    else
        pos = pos - (ang:Up() * math.sin(selfTbl.BobCT * step) * 0.1 * ((math.sin(selfTbl.BobCT * 3.515) * 0.2) + 1.5) * mag * crouchmult * sharedmult) - (ang:Up() * smoothsidemove * -0.05) - (ang:Up() * smoothjumpmove2 * 0.2)
        pos = pos + (ang:Forward() * math.sin(selfTbl.BobCT * step * 0.3) * 0.11 * ((math.sin(selfTbl.BobCT * 2) * ts * 1.25) + 1) * ((math.sin(selfTbl.BobCT * 0.615) * 0.2) + 1) * mag * sharedmult)
        pos = pos + (ang:Right() * (math.sin(selfTbl.BobCT * step * 0.5) + (math.cos(selfTbl.BobCT * step * 0.5))) * 0.2 * mag * sharedmult)
        ang:RotateAroundAxis(ang:Forward(), math.sin(selfTbl.BobCT * step * 0.5) * ((math.sin(selfTbl.BobCT * 6.151) * 0.2) + 1) * 5 * d * sharedmult + smoothsidemove)
        ang:RotateAroundAxis(ang:Right(), math.sin(selfTbl.BobCT * step * 0.12) * ((math.sin(selfTbl.BobCT * 1.521) * 0.2) + 1) * 0.1 * d * sharedmult)
        ang:RotateAroundAxis(ang:Right(), smoothjumpmove2 * 5)
    end

    local steprate = Lerp(d, 1, 2.75)
    steprate = Lerp(selfTbl.ViewModelNotOnGround, steprate, 0.75)

    if IsFirstTimePredicted() or game.SinglePlayer() then
        selfTbl.BobCT = selfTbl.BobCT + (ft * steprate)
    end

    return pos, ang
end

local notonground = 0

-- Default table will be close to old movement to keep compat with all guns
local defbobsettingstable  = {0.5, 0.25, 1,    0.75, 2, 0.875} -- x y z   p y r
local defbobsettingstable2 = {1, 0.75, 1,      1, 1, 0.75}       -- x y z   p y r
-- Edit SWEP.BobSettingsMove/Speed in your own swep to make it better for you! values can be negaitve

local function DarsuBob(self, pos, ang)
    local selfTbl = ENT_GetTable(self)

    selfTbl.BobScale = 0 -- hl2 bob removal
    if selfTbl.GetCustomize(self) then return pos, ang end

    local owner = self:GetOwner()
    local ft = FrameTime()
    local velocityangle = owner:GetVelocity()
    local sightamount = selfTbl.GetSightAmount(self) - ((selfTbl.Peeking and not selfTbl.PeekingIsSight) and 0.72 or 0)
    local sprintamount = selfTbl.GetSprintAmount(self)

    local sharedmult = selfTbl.GetIsSprinting(self) and selfTbl.GetProcessedValue(self, "BobSprintMult", true) or selfTbl.GetProcessedValue(self, "BobWalkMult", true)

    local velocity = math_Clamp(velocityangle:Length(), 0, 350)

    selfTbl.ViewModelBobVelocity = math.Approach(selfTbl.ViewModelBobVelocity, velocity, ft * 10000)

    local d = math_Clamp(selfTbl.ViewModelBobVelocity / 350, 0, 0.75)

    notonground = math.Approach(notonground, (owner:OnGround() and owner:GetMoveType() != MOVETYPE_NOCLIP) and 0 or 1, ft / 0.1)
    local steprate = Lerp(d, 1, 2.5)
    steprate = Lerp(notonground, steprate, 0.5)


    local jumpmove = math_Clamp(math.ease.InExpo(math_Clamp(velocityangle.z, -350, 0)/-350)*25 + math.ease.InExpo(math_Clamp(velocityangle.z, 0, 350)/350)*-60, -5, 3.5) * (1.5-sightamount) -- crazy math for jump movement
    smoothjumpmove = Lerp(math_Clamp(ft*8, 0, 1), smoothjumpmove, jumpmove)


    if IsFirstTimePredicted() or game.SinglePlayer() then selfTbl.BobCT = selfTbl.BobCT + (ft * steprate) end

    d = d * Lerp(sightamount, 1.4, 0.8) -- If we in sights make less moves

    local d2 = math.ease.InQuart(d)
    local d3 = math.ease.InQuad(d) * 0.6
    local speedmult = 1.4
    local speedmultang = 1.45

    local settings = selfTbl.BobSettingsMove or defbobsettingstable -- custom bob per gun
    local settings2 = selfTbl.BobSettingsSpeed or defbobsettingstable2
    local xm, ym, zm, pm, yym, rm = settings[1], settings[2], settings[3], settings[4], settings[5], settings[6]
    local xms, yms, zms, pms, yyms, rms = settings2[1], settings2[2], settings2[3], settings2[4], settings2[5], settings2[6]

    -- local sidemove = ((owner:KeyDown(IN_MOVERIGHT) and 1 or 0) - (owner:KeyDown(IN_MOVELEFT) and 1 or 0)) * 3 * (1.1-sightamount)
    local sidemove = (owner:GetVelocity():Dot(owner:EyeAngles():Right()) / owner:GetMaxSpeed()) * 4 * (1.5-sightamount)
    smoothsidemove = Lerp(math_Clamp(ft*8, 0, 1), smoothsidemove, sidemove)

    local crouchmult = (owner:Crouching() and not selfTbl.GetIsSprinting(self)) and 2.5*(1.3-sightamount)  or 1

    if owner.GetSliding then if owner:GetSliding() then speedmult = 0.01 d3 = 0 smoothsidemove = -10 end end

    pos:Sub(ang:Right() *          math.sin(speedmult * selfTbl.BobCT * 5 * xms)  * d2 * 0.5 * Lerp(sprintamount, 1, 0.05) * xm * sharedmult)                                   -- X
    pos:Sub(ang:Up() *             math.cos(speedmult * selfTbl.BobCT * 7 * yms)    * d * 0.05 * (crouchmult*crouchmult*crouchmult) * Lerp(sprintamount, 1, 0.3) * ym * sharedmult)                     -- Y
    pos:Sub(ang:Forward() *        math.sin(speedmult * selfTbl.BobCT * 4 * zms)  * d2 * 0.75 * crouchmult * zm * sharedmult)                   -- Z

    ang:RotateAroundAxis(ang:Right(),   math.sin(speedmultang * selfTbl.BobCT * 5.5 * pms + 0.3)    * d3 * 2.25 * pm * sharedmult + smoothjumpmove)                  -- P
    ang:RotateAroundAxis(ang:Up(),      math.cos(speedmultang * selfTbl.BobCT * 3.3 * yyms)  * d3 * 1 * Lerp(sprintamount, 1, 0.1) * yym * sharedmult)                                   -- Y
    ang:RotateAroundAxis(ang:Forward(), math.sin(speedmultang * selfTbl.BobCT * 6 * rms)    * d3 * 4.5 * crouchmult * rm * sharedmult + smoothsidemove)   -- R

    return pos, ang
end

local arc9_vm_bobstyle = GetConVar("arc9_vm_bobstyle")

function SWEP:GetViewModelBob(pos, ang)
    local selfTbl = ENT_GetTable(self)

    selfTbl.SwayScale = 0
    selfTbl.BobScale = 0
    local bobb = arc9_vm_bobstyle:GetInt()

    if bobb == 1 then
        return FesiugBob(self, pos, ang)
    elseif bobb == 2 then
        return ArcticBob(self, pos, ang)
    elseif bobb == 3 then
        return DarsuBob(self, pos, ang)
    elseif bobb == 4 then
        return ArcticBreadBob(self, pos, ang)
    elseif bobb == 0 then
        return ArcticBreadDarsuBob(self, pos, ang)
    else
        if selfTbl.GetCustomize(self) then return pos, ang end
        selfTbl.SwayScale = Lerp(selfTbl.GetSightDelta(self), 1, 0.01)
        selfTbl.BobScale = Lerp(selfTbl.GetSightDelta(self), 1, 0.01)

        return pos, ang
    end
end


SWEP.LastViewModelVerticalVelocity = 0

-- SWEP.ViewModelLanded = 0
-- SWEP.ViewModelLanding = 0
function SWEP:GetMidAirBob(pos, ang)
    local selfTbl = ENT_GetTable(self)

    if selfTbl.GetCustomize(self) then return pos, ang end
    local v = -self:GetOwner():GetVelocity().z / 200
    v = math_Clamp(v, -1, 1)
    -- if v == 0 and self.LastViewModelVerticalVelocity != 0 then
    --     self.ViewModelLanding = self.LastViewModelVerticalVelocity
    --     self.ViewModelLanded = 1
    -- end
    -- if self.ViewModelLanded > 0 then
    --     self.ViewModelLanded = math.Approach(self.ViewModelLanded, 0, FrameTime() / 0.25)
    v = Lerp(5 * FrameTime(), self.LastViewModelVerticalVelocity, v)
    -- end
    selfTbl.LastViewModelVerticalVelocity = v
    local d = selfTbl.ViewModelNotOnGround
    d = d * Lerp(selfTbl.GetSightAmount(self), 1, 0.1)
    -- ang:RotateAroundAxis(ang:Right(), -v * d * 8 * math.sin(CurTime() * 0.15))
    pos = pos + ang:Up() * -v * d * 2 * math.sin(CurTime() * 0.15)

    return pos, ang
end

SWEP.ViewModelInertiaX = 0
SWEP.ViewModelInertiaY = 0

function SWEP:GetViewModelLeftRight(pos, ang)
    local selfTbl = ENT_GetTable(self)

    if selfTbl.GetCustomize(self) then return pos, ang end
    local owner = self:GetOwner()
    local ft = FrameTime()

    local v = owner:GetVelocity()
    local d = Lerp(selfTbl.GetSightDelta(self), 1, 0)
    v, _ = WorldToLocal(v, Angle(), Vector(), owner:EyeAngles())
    local vx = math_Clamp(v.x / 200, -1, 1)
    local vy = math_Clamp(v.y / 200, -1, 1)
    selfTbl.ViewModelInertiaX = math.Approach(selfTbl.ViewModelInertiaX, vx, math.abs(vx) * ft / 0.1)
    selfTbl.ViewModelInertiaY = math.Approach(selfTbl.ViewModelInertiaY, vy, math.abs(vy) * ft / 0.1)
    pos = pos + (ang:Right() * -selfTbl.ViewModelInertiaX * 0.65 * d)
    pos = pos + (ang:Forward() * selfTbl.ViewModelInertiaY * 0.5 * d)

    return pos, ang
end
