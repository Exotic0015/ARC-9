local ScrW, ScrH, LocalPlayer, CurTime, FrameTime, FrameNumber, EyePos, EyeAngles =
      ScrW, ScrH, LocalPlayer, CurTime, FrameTime, FrameNumber, EyePos, EyeAngles
local Color, Material, pairs, ipairs, tostring, tonumber, tobool, select, isstring, istable, isfunction, IsColor, ErrorNoHalt =
      Color, Material, pairs, ipairs, tostring, tonumber, tobool, select, isstring, istable, isfunction, IsColor, ErrorNoHalt

local surface_SetDrawColor, surface_DrawRect, surface_DrawOutlinedRect, surface_DrawLine =
      surface.SetDrawColor, surface.DrawRect, surface.DrawOutlinedRect, surface.DrawLine
local surface_SetMaterial, surface_DrawTexturedRect, surface_DrawTexturedRectUV =
      surface.SetMaterial, surface.DrawTexturedRect, surface.DrawTexturedRectUV
local surface_SetFont, surface_SetTextColor, surface_SetTextPos, surface_DrawText, surface_GetTextSize =
      surface.SetFont, surface.SetTextColor, surface.SetTextPos, surface.DrawText, surface.GetTextSize

local math_min, math_max, math_Clamp, math_Approach, math_floor, math_ceil, math_Round, math_abs =
      math.min, math.max, math.Clamp, math.Approach, math.floor, math.ceil, math.Round, math.abs

local string_format, string_Replace, string_sub, string_upper, string_Split, string_find, string_match, string_gmatch =
      string.format, string.Replace, string.sub, string.upper, string.Split, string.find, string.match, string.gmatch

local table_insert, table_Empty =
      table.insert, table.Empty

local cam_Start3D, cam_End3D, cam_Start3D2D, cam_End3D2D =
      cam.Start3D, cam.End3D, cam.Start3D2D, cam.End3D2D

local render_SetScissorRect =
      render.SetScissorRect

local os_time, os_date, utf8_sub, input_LookupBinding, input_LookupKeyBinding =
      os.time, os.date, utf8.sub, input.LookupBinding, input.LookupKeyBinding

local ENT = FindMetaTable("Entity")
local ENT_GetTable, ENT_IsValid, ENT_Health, ENT_GetMaxHealth, ENT_GetClass, ENT_GetOwner =
      ENT.GetTable, ENT.IsValid, ENT.Health, ENT.GetMaxHealth, ENT.GetClass, ENT.GetOwner

local PLY = FindMetaTable("Player")
local PLY_GetActiveWeapon, PLY_GetAmmoCount, PLY_Armor, PLY_GetWeapon, PLY_HasWeapon =
      PLY.GetActiveWeapon, PLY.GetAmmoCount, PLY.Armor, PLY.GetWeapon, PLY.HasWeapon

local WPN = FindMetaTable("Weapon")
local WPN_GetMaxClip1, WPN_Clip1, WPN_GetPrimaryAmmoType, WPN_GetMaxClip2, WPN_Clip2, WPN_GetSecondaryAmmoType, WPN_IsScripted =
      WPN.GetMaxClip1, WPN.Clip1, WPN.GetPrimaryAmmoType, WPN.GetMaxClip2, WPN.Clip2, WPN.GetSecondaryAmmoType, WPN.IsScripted

local ANG = FindMetaTable("Angle")
local ANG_Up, ANG_Right, ANG_Forward, ANG_RotateAroundAxis =
      ANG.Up, ANG.Right, ANG.Forward, ANG.RotateAroundAxis

local hide = {
    ["CHudHealth"] = true,
    ["CHudBattery"] = true,
    ["CHudAmmo"] = true,
    ["CHudSecondaryAmmo"] = true,
    ["CHudGMod"] = false,
}

hook.Add("HUDShouldDraw", "ARC9_HideHUD", function(name)
    if ARC9.ShouldDrawHUD() then
        if hide[name] then return false end
    end
end)

local arc9_hud_scale_cvar = GetConVar("arc9_hud_scale")
local arc9_hud_scale = arc9_hud_scale_cvar and arc9_hud_scale_cvar:GetFloat() or 1
if arc9_hud_scale_cvar then
    local varname = arc9_hud_scale_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_hud_scale = tonumber(v) or 1 end, varname)
end

local r_640 = 1 / 640
ARC9.ScreenScale = function(size)
    return size * (ScrW() * r_640) * arc9_hud_scale * 0.9
end

local ARC9ScreenScale = ARC9.ScreenScale

ARC9.Colors = {
    bg          = Color(153, 153, 153, 97),
    bgdark      = Color(37, 37, 37, 240),
    bg_pro      = Color(53, 179, 53, 97),
    bg_con      = Color(204, 61, 61, 97),
    pro         = Color(54, 179, 54),
    con         = Color(179, 54, 54),
    fg          = Color(255, 255, 255),
    hi          = Color(255, 123, 0),
    hint        = Color(200, 200, 200, 120),
    unowned     = Color(255, 255, 255, 32),

    notoccupied = Color(216, 216, 216, 70),

    sel         = Color(255, 150, 100),
    occupied    = Color(150, 255, 100),
    shadow      = Color(17, 17, 9),
    neg         = Color(255, 100, 100),
    pos         = Color(100, 255, 100),

    bg_3d       = Color(255, 255, 240),
    fg_3d       = Color(0, 0, 0),
    shadow_3d   = Color(0, 0, 0),
    hi_3d       = Color(255, 50, 50),
    pos_3d      = Color(255, 255, 255),

    bg_menu     = Color(26, 26, 23, 252),
    md          = Color(107,107,92),
}

local cl_drawhud_cvar = GetConVar("cl_drawhud")
local cl_drawhud = cl_drawhud_cvar and cl_drawhud_cvar:GetBool() or true
if cl_drawhud_cvar then
    local varname = cl_drawhud_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) cl_drawhud = tobool(v) end, varname .. "_arc9") -- append a suffix to the callback identifier as this convar is not ours
end

local arc9_hud_arc9_cvar = GetConVar("arc9_hud_arc9")
local arc9_hud_arc9 = arc9_hud_arc9_cvar and arc9_hud_arc9_cvar:GetBool() or false
if arc9_hud_arc9_cvar then
    local varname = arc9_hud_arc9_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_hud_arc9 = tobool(v) end, varname)
end

local arc9_hud_always_cvar = GetConVar("arc9_hud_always")
local arc9_hud_always = arc9_hud_always_cvar and arc9_hud_always_cvar:GetBool() or false
if arc9_hud_always_cvar then
    local varname = arc9_hud_always_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_hud_always = tobool(v) end, varname)
end

local arc9_hud_force_disable_cvar = GetConVar("arc9_hud_force_disable")
local arc9_hud_force_disable = arc9_hud_force_disable_cvar and arc9_hud_force_disable_cvar:GetBool() or false
if arc9_hud_force_disable_cvar then
    local varname = arc9_hud_force_disable_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_hud_force_disable = tobool(v) end, varname)
end

local infammo_cvar = GetConVar("arc9_infinite_ammo")
local infammo = infammo_cvar and infammo_cvar:GetBool() or false
if infammo_cvar then
    local varname = infammo_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) infammo = tobool(v) end, varname)
end

local arc9_dtap_sights_cvar = GetConVar("arc9_dtap_sights")
local arc9_dtap_sights = arc9_dtap_sights_cvar and arc9_dtap_sights_cvar:GetBool() or false
if arc9_dtap_sights_cvar then
    local varname = arc9_dtap_sights_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_dtap_sights = tobool(v) end, varname)
end

local convar_hints_cvar = GetConVar("arc9_hud_hints")
local convar_hints = convar_hints_cvar and convar_hints_cvar:GetFloat() or 1
if convar_hints_cvar then
    local varname = convar_hints_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) convar_hints = tonumber(v) or 0 end, varname)
end

local arc9_hud_compact_cvar = GetConVar("arc9_hud_compact")
local arc9_hud_compact = arc9_hud_compact_cvar and arc9_hud_compact_cvar:GetBool() or false
if arc9_hud_compact_cvar then
    local varname = arc9_hud_compact_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_hud_compact = tobool(v) end, varname)
end

local deadzonex_cvar = GetConVar("arc9_hud_deadzonex")
local deadzonex = deadzonex_cvar and deadzonex_cvar:GetInt() or 0
if deadzonex_cvar then
    local varname = deadzonex_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) deadzonex = math_floor(tonumber(v) or 0) end, varname)
end

function ARC9.ShouldDrawHUD()
    if not cl_drawhud then return end

    local lp = LocalPlayer()
    if not lp or not ENT_IsValid(lp) then return end

    local wpn = PLY_GetActiveWeapon(lp)
    local wpnTbl = (wpn and ENT_IsValid(wpn)) and ENT_GetTable(wpn) or nil
    local a9 = wpnTbl and wpnTbl.ARC9 and not wpnTbl.NotAWeapon
    local incust = a9 and wpnTbl.GetCustomize(wpn) or false

    hide.CHudGMod = incust

    if arc9_hud_force_disable and not incust then return end
    if (not arc9_hud_arc9 and not incust) or (not a9 and not arc9_hud_always) then return end

    return true
end

local alldays = {
    [1] = true,
    [2] = true,
    [3] = true,
    [4] = true,
    [5] = true,
    [6] = true,
    [7] = true,
    [8] = true,
    [9] = true,
    [10] = true,
    [11] = true,
    [12] = true,
    [13] = true,
    [14] = true,
    [15] = true,
    [16] = true,
    [17] = true,
    [18] = true,
    [19] = true,
    [20] = true,
    [21] = true,
    [22] = true,
    [23] = true,
    [24] = true,
    [25] = true,
    [26] = true,
    [27] = true,
    [28] = true,
    [29] = true,
    [30] = true,
    [31] = true,
    [32] = true, -- you can't fight nature, jack
}

local events = {
    ["New Year's"] = {
        months = { [1] = true },
        days = { [1] = true },
    },
    ["Leap Day"] = {
        months = { [2] = true },
        days = { [29] = true },
    },
    -- ["Opposite Day"] = {
    --     months = { [1] = true },
    --     days = { [25] = true },
    -- },
    ["Earth Day"] = {
        months = { [4] = true },
        days = { [22] = true },
    },
    ["Easter"] = {
        months = { [4] = true },
        days = alldays,
    },
    ["Halloween"] = {
        months = { [10] = true },
        days = { [31] = true },
    },
    ["Thanksgiving"] = {
        months = { [11] = true },
        days = { [23] = true },
    },
    ["Christmas"] = {
        months = { [12] = true },
        days = { [25] = true },
    },
    ["Birthday - Arctic"] = {
        months = { [7] = true },
        days = { [27] = true },
    },
    ["Summer Break"] = {
        months = { [6] = true, [7] = true, [8] = true,  },
        days = alldays,
    },
    ["Troll Day"] = {
        months = { [4] = true },
        days = { [1] = true },
    },
}

local holidayscolors = {
    ["Christmas"] = {
        hi     = Color(184, 210, 160),
        bg     = Color(153, 113, 110, 97),
        bgdark = Color(33, 11, 9, 240),
    },
    ["Halloween"] = {
        hi     = Color(255, 187, 132),
        bg     = Color(120, 110, 153, 97),
        bgdark = Color(14, 6, 37, 240),
    },
    ["Thanksgiving"] = {
        hi     = Color(240, 195, 172),
        bg     = Color(153, 137, 110, 97),
        bgdark = Color(38, 34, 27, 240),
    },
    ["New Year's"] = {
        hi     = Color(255, 255, 200),
        bg     = Color(114, 114, 153, 97),
        bgdark = Color(30, 30, 40, 240),
    },
    ["Birthday - Arctic"] = {
        hi     = Color(210, 235, 255),
        bg     = Color(153, 153, 114, 97),
        bgdark = Color(40, 40, 30, 240),
    },
    ["None"] = {
        hi     = ARC9.Colors.hi,
        bg     = ARC9.Colors.bg,
        bgdark = ARC9.Colors.bgdark,
    },
}

local arc9_holiday_month_cvar = GetConVar("arc9_holiday_month")
local arc9_holiday_month = arc9_holiday_month_cvar and arc9_holiday_month_cvar:GetInt() or 0

local arc9_holiday_day_cvar = GetConVar("arc9_holiday_day")
local arc9_holiday_day = arc9_holiday_day_cvar and arc9_holiday_day_cvar:GetInt() or 0

local cachedHolidayName = "None"
local nextHolidayCheck = 0

function ARC9.GetTime()
    if arc9_holiday_month > 0 and arc9_holiday_day > 0 then
        return os_time({ month = arc9_holiday_month, day = arc9_holiday_day, year = 2000 })
    else
        return os_time() -- { month = 12, day = 1, year = 2000 } )
    end
end

local function refreshHolidayColor()
    local d = os_date("*t", ARC9.GetTime())
    for i, _ in pairs(holidayscolors) do
        if i ~= "None" then
            local ev = events[i]
            if ev and ev.days[d.day] and ev.months[d.month] then
                cachedHolidayName = i
                return i
            end
        end
    end

    cachedHolidayName = "None"
    return "None"
end

if arc9_holiday_month_cvar then
    local varname = arc9_holiday_month_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v)
        arc9_holiday_month = math_floor(tonumber(v) or 0)
        refreshHolidayColor()
    end, varname)
end

if arc9_holiday_day_cvar then
    local varname = arc9_holiday_day_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v)
        arc9_holiday_day = math_floor(tonumber(v) or 0)
        refreshHolidayColor()
    end, varname)
end

function ARC9.GetHolidayColor()
    local ct = CurTime()
    if ct >= nextHolidayCheck then
        nextHolidayCheck = ct + 60
        return refreshHolidayColor()
    end
    return cachedHolidayName
end

ARC9.ActiveHolidays = {}

do
    local d = os_date("*t", ARC9.GetTime())
    for i, j in pairs(events) do
        if j.days[d.day] and j.months[d.month] then
            ARC9.ActiveHolidays[i] = true
        end
    end
    refreshHolidayColor()
end

local arc9_hud_color_r_cvar = GetConVar("arc9_hud_color_r")
local arc9_hud_color_g_cvar = GetConVar("arc9_hud_color_g")
local arc9_hud_color_b_cvar = GetConVar("arc9_hud_color_b")

local customHiColor = Color(
    arc9_hud_color_r_cvar and arc9_hud_color_r_cvar:GetInt() or 255,
    arc9_hud_color_g_cvar and arc9_hud_color_g_cvar:GetInt() or 123,
    arc9_hud_color_b_cvar and arc9_hud_color_b_cvar:GetInt() or 0
)

if arc9_hud_color_r_cvar then
    local varname = arc9_hud_color_r_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) customHiColor.r = math_floor(tonumber(v) or 255) end, varname)
end

if arc9_hud_color_g_cvar then
    local varname = arc9_hud_color_g_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) customHiColor.g = math_floor(tonumber(v) or 123) end, varname)
end

if arc9_hud_color_b_cvar then
    local varname = arc9_hud_color_b_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) customHiColor.b = math_floor(tonumber(v) or 0) end, varname)
end

local arc9_hud_lightmode_cvar = GetConVar("arc9_hud_lightmode")
local arc9_hud_lightmode = arc9_hud_lightmode_cvar and arc9_hud_lightmode_cvar:GetBool() or false
if arc9_hud_lightmode_cvar then
    local varname = arc9_hud_lightmode_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_hud_lightmode = tobool(v) end, varname)
end

local arc9_hud_holiday_cvar = GetConVar("arc9_hud_holiday")
local arc9_hud_holiday = arc9_hud_holiday_cvar and arc9_hud_holiday_cvar:GetBool() or false
if arc9_hud_holiday_cvar then
    local varname = arc9_hud_holiday_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) arc9_hud_holiday = tobool(v) end, varname)
end

function ARC9.GetHUDColor(part, alpha)
    alpha = alpha or 255
    local col = ARC9.Colors[part] or ARC9.Colors.hi
    local holidaycol = holidayscolors[ARC9.GetHolidayColor()]

    if part == "hi" then
        col = arc9_hud_holiday and holidaycol.hi or customHiColor
    elseif part == "bg" then
        if arc9_hud_lightmode then
            if arc9_hud_holiday then col = holidaycol.bg end
        else
            col = arc9_hud_holiday and holidaycol.bgdark or ARC9.Colors.bgdark
        end
    end

    if alpha < 255 then
        return Color(col.r, col.g, col.b, alpha)
    end
    return col
end

local function setDrawHUDColor(part, alpha)
    local col = ARC9.Colors[part] or ARC9.Colors.hi
    if part == "hi" then
        col = arc9_hud_holiday and holidayscolors[ARC9.GetHolidayColor()].hi or customHiColor
    elseif part == "bg" then
        local holidaycol = holidayscolors[ARC9.GetHolidayColor()]
        if arc9_hud_lightmode then
            if arc9_hud_holiday then col = holidaycol.bg end
        else
            col = arc9_hud_holiday and holidaycol.bgdark or ARC9.Colors.bgdark
        end
    end
    surface_SetDrawColor(col.r, col.g, col.b, alpha or col.a or 255) -- colors are implemented in lua so no need to unpack for perf
end

local function setTextHUDColor(part, alpha)
    local col = ARC9.Colors[part] or ARC9.Colors.hi
    if part == "hi" then
        col = arc9_hud_holiday and holidayscolors[ARC9.GetHolidayColor()].hi or customHiColor
    elseif part == "bg" then
        local holidaycol = holidayscolors[ARC9.GetHolidayColor()]
        if arc9_hud_lightmode then
            if arc9_hud_holiday then col = holidaycol.bg end
        else
            col = arc9_hud_holiday and holidaycol.bgdark or ARC9.Colors.bgdark
        end
    end
    surface_SetTextColor(col.r, col.g, col.b, alpha or col.a or 255) -- colors are implemented in lua so no need to unpack for perf
end

local rackrisetime = 0
local lastrow = 0
local lastweapon = NULL
local hint_alpha = 1
local lasthintcount = 0
local hidefadetime = 0
local first = true

local hud_bg = Material("arc9/hud_bg.png", "mips smooth")
local hud_t_full = Material("arc9/thermometer_full.png", "mips")
local hud_t_empty = Material("arc9/thermometer_empty.png", "mips")
local hud_bigblur = Material("arc9/bigblur.png", "mips")
local hud_sillyhints = Material("arc9/sillyhintsblur.png", "mips")
local hud_logo_lowvis = Material("arc9/logo/logo_lowvis.png", "mips smooth")

local firemode_pics = {
    [-1] = Material("arc9/fs_auto.png", "mips smooth"),
    [0] = Material("arc9/fs_safe.png", "mips smooth"),
    [1] = Material("arc9/fs_semi.png", "mips smooth"),
    [2] = Material("arc9/fs_2rb.png", "mips smooth"),
    [3] = Material("arc9/fs_3rb.png", "mips smooth"),
}

local automatics = {
    ["weapon_smg1"] = true,
    ["weapon_ar2"] = true,
    ["weapon_mp5_hl1"] = true,
    ["weapon_gauss"] = true,
    ["weapon_egon"] = true,
}

local glyphMatCacheMips = {}
local glyphMatCacheSmooth = {}

local function getGlyphMaterial(family, glyph, isMips)
    local cache = isMips and glyphMatCacheMips or glyphMatCacheSmooth
    local key = family .. glyph
    local mat = cache[key]
    if not mat then
        mat = Material("arc9/" .. key .. ".png", isMips and "mips smooth" or "smooth")
        cache[key] = mat
    end
    return mat
end

local function GetWeaponCapabilities(wpn, wpnTbl)
    wpnTbl = wpnTbl or ENT_GetTable(wpn)
    local inSights = wpnTbl.GetInSights(wpn)
    local getValue = wpnTbl.GetValue
    local sight = inSights and wpnTbl.GetSight(wpn)
    local sightAtt = sight and sight.atttbl

    return {
        UBGL = tobool(not inSights and getValue(wpn, "UBGL")),
        Bash = tobool(not inSights and getValue(wpn, "Bash")),
        SwitchSights = tobool(inSights and #wpnTbl.MultiSightTable > 1),
        Inspect = not inSights and not wpnTbl.NoInspect and tobool(wpnTbl.HasAnimation(wpn, "enter_inspect") or wpnTbl.HasAnimation(wpn, "inspect")),
        Firemode = tobool(not wpnTbl.GetUBGL(wpn) and #getValue(wpn, "Firemodes") > 1),
        HoldBreath = tobool(inSights and getValue(wpn, "HoldBreathTime") > 0),
        VariableZoom = tobool(inSights and sightAtt and sightAtt.RTScopeAdjustable),
        ManualCycle = tobool(wpnTbl.GetNeedsCycle(wpn) and wpnTbl.ShouldManualCycle(wpn)),
    }
end

local function GetHintsTable(capabilities, weapon, wpnTbl)
    if not weapon then
        local lp = LocalPlayer()
        weapon = (lp and ENT_IsValid(lp)) and PLY_GetActiveWeapon(lp) or nil
    end
    wpnTbl = wpnTbl or ENT_GetTable(weapon)

    local hints = {}
    local gpv = wpnTbl.GetProcessedValue
    local getBindKey = ARC9.GetBindKey
    local getKeyIsBound = ARC9.GetKeyIsBound

    if capabilities.UBGL then
        local ubgltext = gpv(weapon, "UBGLFiremodeName", true)
        local phrase = ARC9:GetPhrase(ubgltext) or ubgltext
        if getKeyIsBound("+arc9_ubgl") then
            table_insert(hints, {
                glyph = getBindKey("+arc9_ubgl"),
                action = string_format(ARC9:GetPhrase("hud.hint.ubgl"), tostring(phrase))
            })
        else
            table_insert(hints, {
                glyph = getBindKey("+use"),
                glyph2 = getBindKey("+attack2"),
                action = string_format(ARC9:GetPhrase("hud.hint.ubgl"), tostring(phrase))
            })
        end
    end

    if capabilities.SwitchSights then
        if getKeyIsBound("+arc9_switchsights") then
            table_insert(hints, {
                glyph = getBindKey("+arc9_switchsights"),
                action = ARC9:GetPhrase("hud.hint.switchsights")
            })
        else
            local useKey = getBindKey("+use")
            table_insert(hints, {
                glyph = useKey,
                glyph2 = not arc9_dtap_sights and getBindKey("invnext") or useKey,
                action = ARC9:GetPhrase("hud.hint.switchsights")
            }) -- TODO: hardcoded to mouse wheel, see sh_move.lua ARC9.StartCommand
        end
    end

    if capabilities.VariableZoom then
        local bind113 = input_LookupKeyBinding(113)
        local bind112 = input_LookupKeyBinding(112)
        table_insert(hints, {
            glyph = not input_LookupBinding("invnext") and not (bind113 ~= nil and #bind113 > 0) and "shared_mouse_scroll_down" or getBindKey("invnext"),
            glyph2 = not input_LookupBinding("invprev") and not (bind112 ~= nil and #bind112 > 0) and "shared_mouse_scroll_up" or getBindKey("invprev"),
            action = ARC9:GetPhrase("hud.hint.zoom")
        }) -- use mouse wheel if invnext or invprev not bound, possible convar to swap maybe? currently for semi parity with switchsights
    end

    if capabilities.HoldBreath then
        table_insert(hints, {
            glyph = getBindKey("+speed"),
            action = ARC9:GetPhrase("hud.hint.breath")
        })
    end

    if capabilities.Bash and not wpnTbl.PrimaryBash then
        if wpnTbl.SecondaryBash then -- If the weapon performs bashing as the primary attack function, only display the "+attack" function.
            table_insert(hints, {
                glyph = getBindKey("+attack2"),
                action = ARC9:GetPhrase("hud.hint.bash")
            })
        elseif getKeyIsBound("+arc9_melee") then
            table_insert(hints, {
                glyph = getBindKey("+arc9_melee"),
                action = ARC9:GetPhrase("hud.hint.bash")
            })
        else
            table_insert(hints, {
                glyph = getBindKey("+use"),
                glyph2 = getBindKey("+attack"),
                action = ARC9:GetPhrase("hud.hint.bash")
            })
        end
    end

    if capabilities.Inspect then
        if getKeyIsBound("+arc9_inspect") then
            table_insert(hints, {
                glyph = getBindKey("+arc9_inspect"),
                action = ARC9:GetPhrase("hud.hint.inspect")
            })
        else
            table_insert(hints, {
                glyph = getBindKey("+use"),
                glyph2 = getBindKey("+reload"),
                action = ARC9:GetPhrase("hud.hint.inspect")
            })
        end
    end

    if capabilities.Firemode then
        table_insert(hints, {
            glyph = getBindKey("+zoom"),
            action = ARC9:GetPhrase("hud.hint.firemode")
        })
    end

    if capabilities.ManualCycle then
        table_insert(hints, {
            glyph = getBindKey("+reload"),
            action = ARC9:GetPhrase("hud.hint.cycle")
        })
    end

    if wpnTbl.CanToggleAllStatsOnF(weapon) then
        table_insert(hints, {
            glyph = getBindKey("impulse 100"),
            action = ARC9:GetPhrase("hud.hint.toggleatts")
        })
    end

    local cantpeek = gpv(weapon, "CantPeek", true)
    local sight = wpnTbl.GetInSights(weapon)
    local bipod = wpnTbl.GetBipod(weapon)
    if not (cantpeek and sight) and not (sight and bipod) then
        table_insert(hints, {
            glyph = getBindKey("+menu_context"),
            action = (not cantpeek and sight) and ARC9:GetPhrase("hud.hint.peek") or ARC9:GetPhrase("hud.hint.customize")
        })
    end

    if not wpnTbl.CantSafety then
        table_insert(hints, {
            glyph = getBindKey("+use"),
            glyph2 = getBindKey("+zoom"),
            action = ARC9:GetPhrase("hud.hint.safe")
        })
    end

    if wpnTbl.EFT_HasTacReloads and (not gpv(weapon, "ShotgunReload", true) or wpnTbl.EFT_HasTacReloadsAlways) then
        local reloadKey = getBindKey("+reload")
        table_insert(hints, {
            glyph = reloadKey,
            glyph2 = reloadKey,
            action = ARC9:GetPhrase("hud.hint.quickreload")
        })
    end

    if ARC9.RadialMenuOpen and wpnTbl.MouseAngle then
        table_insert(hints, {
            glyph = "shared_mouse_l_click_lg",
            glyph2 = "shared_mouse_r_click_lg",
            action = ARC9:GetPhrase("customize.hint.nextmode") .. "/" .. ARC9:GetPhrase("customize.hint.lastmode")
        })
    end

    local owner = ENT_GetOwner(weapon)
    if owner and ENT_IsValid(owner) then
        local ownerTbl = ENT_GetTable(owner)
        local quicknade = ownerTbl and ownerTbl.ARC9LastSelectedGrenade
        if quicknade and not wpnTbl.IsQuickGrenade and PLY_HasWeapon(owner, quicknade) then
            local quicknadeent = PLY_GetWeapon(owner, quicknade)
            if quicknadeent and ENT_IsValid(quicknadeent) then
                local qnTbl = ENT_GetTable(quicknadeent)
                local howmanyquicknades = infammo and 0 or PLY_GetAmmoCount(owner, qnTbl.Ammo)
                table_insert(hints, {
                    glyph = getBindKey("+grenade1"),
                    action = string_format(ARC9:GetPhrase("hud.hint.quicknade"), qnTbl.ShortPrintName or qnTbl.PrintName) .. (howmanyquicknades > 0 and (" (" .. (howmanyquicknades + 1) .. ")") or "")
                })
            end
        end
    end

    local ctrlLookup = ARC9.CTRL_Lookup
    local ctrlConvertTo = ARC9.CTRL_ConvertTo
    local ctrlExists = ARC9.CTRL_Exists
    local family = ARC9.GlyphFamilyHUD()

    for i = 1, #hints do
        local v = hints[i]
        local g1 = v.glyph
        if ctrlLookup[g1] then g1 = ctrlLookup[g1] end
        if ctrlConvertTo[g1] then g1 = ctrlConvertTo[g1] end
        if ctrlExists[g1] then g1 = getGlyphMaterial(family, g1, true) end
        v.glyph = g1

        local g2 = v.glyph2
        if g2 then
            if ctrlLookup[g2] then g2 = ctrlLookup[g2] end
            if ctrlConvertTo[g2] then g2 = ctrlConvertTo[g2] end
            if ctrlExists[g2] then g2 = getGlyphMaterial(family, g2, true) end
            v.glyph2 = g2
        end
    end

    return hints
end

local scratchKeyLineInfo = { x = 0, y = 0, size = 0, font_keyb = "ARC9_10", font = "ARC9_10" }
local scratchGlyph1 = { nil, 0 }
local scratchGlyph2 = { nil, 0 }

local function DrawSimpleHints()
    if convar_hints == 0 or not cl_drawhud then return end

    local lp = LocalPlayer()
    if not lp or not ENT_IsValid(lp) then return end

    local weapon = PLY_GetActiveWeapon(lp)
    if not weapon or not ENT_IsValid(weapon) then return end

    local wpnTbl = ENT_GetTable(weapon)
    if not wpnTbl or not wpnTbl.ARC9 or wpnTbl.NotAWeapon or wpnTbl.GetCustomize(weapon) then return end

    local ct = CurTime()
    local capabilities = GetWeaponCapabilities(weapon, wpnTbl)
    local hints = GetHintsTable(capabilities, weapon, wpnTbl)
    local hintCount = #hints

    if (lasthintcount ~= hintCount or wpnTbl.GetInSights(weapon) or ARC9.RadialMenuOpen) and hidefadetime + 1.5 < ct then
        hidefadetime = ct
    end

    if first then
        hidefadetime = ct + 7
        first = false
    end

    lasthintcount = hintCount

    if convar_hints == 2 then
        hint_alpha = 1
    elseif hidefadetime + 1.5 > ct then
        hint_alpha = math_Approach(hint_alpha, 1, FrameTime() * 10)
    else
        hint_alpha = math_Approach(hint_alpha, 0, FrameTime())
    end

    local SIZE = ARC9ScreenScale(8)
    local hints_w = ARC9ScreenScale(100)
    local hints_h = ARC9ScreenScale(11) * hintCount

    local hx = ARC9ScreenScale(10) + deadzonex
    local hy = (ScrH() - hints_h) * 0.5

    setDrawHUDColor("shadow", 160 * hint_alpha)
    surface_SetMaterial(hud_sillyhints)
    surface_DrawTexturedRect(-ARC9ScreenScale(5) + deadzonex, hy - ARC9ScreenScale(12.5), hints_w, hints_h + ARC9ScreenScale(25))

    local off_x = ARC9ScreenScale(1)
    local off_y = ARC9ScreenScale(1)
    local txt_off_y = -ARC9ScreenScale(0.8)
    local size9 = ARC9ScreenScale(9)
    local size10 = ARC9ScreenScale(10)
    local minOffset = ARC9ScreenScale(25)
    local stepY = ARC9ScreenScale(12)

    scratchKeyLineInfo.font_keyb = "ARC9_10"
    scratchKeyLineInfo.font = "ARC9_10"
    scratchGlyph1[2] = SIZE
    scratchGlyph2[2] = SIZE

    for i = 1, hintCount do
        local hint = hints[i]
        scratchGlyph1[1] = hint.glyph
        local hasG2 = hint.glyph2 ~= nil
        scratchGlyph2[1] = hint.glyph2
        local actionStr = " " .. hint.action

        surface_SetFont("ARC9_10")
        setDrawHUDColor("shadow", 100 * hint_alpha)
        setTextHUDColor("shadow", 100 * hint_alpha)
        surface_SetTextPos(hx + off_x, hy + off_y)

        scratchKeyLineInfo.x = hx + off_x
        scratchKeyLineInfo.y = hy + off_y
        scratchKeyLineInfo.size = size9
        local strreturn = CreateControllerKeyLine(scratchKeyLineInfo, scratchGlyph1, hasG2 and "  " or "", hasG2 and scratchGlyph2 or "")

        scratchKeyLineInfo.x = hx + off_x + math_max(strreturn, minOffset)
        scratchKeyLineInfo.y = hy + txt_off_y + off_y
        scratchKeyLineInfo.size = size10
        CreateControllerKeyLine(scratchKeyLineInfo, actionStr)

        surface_SetFont("ARC9_10")
        setDrawHUDColor("fg", 200 * hint_alpha)
        setTextHUDColor("fg", 200 * hint_alpha)
        surface_SetTextPos(hx, hy)

        scratchKeyLineInfo.x = hx
        scratchKeyLineInfo.y = hy
        scratchKeyLineInfo.size = size9
        strreturn = CreateControllerKeyLine(scratchKeyLineInfo, scratchGlyph1, hasG2 and "  " or "", hasG2 and scratchGlyph2 or "")

        scratchKeyLineInfo.x = hx + math_max(strreturn, minOffset)
        scratchKeyLineInfo.y = hy + txt_off_y
        scratchKeyLineInfo.size = size10
        CreateControllerKeyLine(scratchKeyLineInfo, actionStr)

        hy = hy + stepY
    end
end

local function draw3D2DHints(weapon, wpnTbl, pos, ang, ct)
    local capabilities = GetWeaponCapabilities(weapon, wpnTbl)
    local hints = GetHintsTable(capabilities, weapon, wpnTbl)
    local hintCount = #hints

    if (lasthintcount ~= hintCount or wpnTbl.GetInSights(weapon)) and hidefadetime + 1.5 < ct then
        hidefadetime = ct
    end

    if first then
        hidefadetime = ct + 10
        first = false
    end

    lasthintcount = hintCount

    if convar_hints == 2 then
        hint_alpha = 1
    elseif hidefadetime + 1.5 > ct then
        hint_alpha = math_Approach(hint_alpha, 1, FrameTime() * 10)
    else
        hint_alpha = math_Approach(hint_alpha, 0, FrameTime())
    end

    local hx = 0
    local hy = 0
    local SIZE = 16

    cam_Start3D2D(pos - (ANG_Right(ang) * ((20 * hintCount * 0.0125) + 0.25)), ang, 0.0125)
        setDrawHUDColor("shadow", 150 * hint_alpha)
        surface_SetMaterial(hud_bigblur)
        surface_DrawTexturedRect(-32, 0, 300, 20 * hintCount)

        local isRu = ARC9:GetLanguage() == "ru"
        scratchKeyLineInfo.font_keyb = nil
        scratchKeyLineInfo.font = "ARC9_16_Unscaled"
        scratchKeyLineInfo.size = 16
        scratchGlyph1[2] = SIZE
        scratchGlyph2[2] = SIZE

        for i = 1, hintCount do
            local hint = hints[i]
            local hintcaps = isRu and ARC9:UperCyrillic(hint.action) or hint.action
            local actionStr = " " .. hintcaps

            scratchGlyph1[1] = hint.glyph
            local hasG2 = hint.glyph2 ~= nil
            scratchGlyph2[1] = hint.glyph2

            surface_SetFont("ARC9_16_Unscaled")
            setDrawHUDColor("shadow", 100 * hint_alpha)
            setTextHUDColor("shadow", 100 * hint_alpha)
            surface_SetTextPos(hx + 4, hy + 2)

            scratchKeyLineInfo.x = hx + 2
            scratchKeyLineInfo.y = hy + 1
            local strreturn = CreateControllerKeyLine(scratchKeyLineInfo, scratchGlyph1, hasG2 and " " or "", hasG2 and scratchGlyph2 or "")

            scratchKeyLineInfo.x = hx + 4 + math_max(strreturn, 48)
            scratchKeyLineInfo.y = hy + 2
            CreateControllerKeyLine(scratchKeyLineInfo, actionStr)

            surface_SetFont("ARC9_16_Unscaled")
            setDrawHUDColor("fg", 200 * hint_alpha)
            setTextHUDColor("fg", 200 * hint_alpha)
            surface_SetTextPos(hx, hy)

            scratchKeyLineInfo.x = hx
            scratchKeyLineInfo.y = hy
            strreturn = CreateControllerKeyLine(scratchKeyLineInfo, scratchGlyph1, hasG2 and " " or "", hasG2 and scratchGlyph2 or "")

            scratchKeyLineInfo.x = hx + math_max(strreturn, 48)
            scratchKeyLineInfo.y = hy
            CreateControllerKeyLine(scratchKeyLineInfo, actionStr)

            hy = hy + 22
        end
    cam_End3D2D()
end

local function getWeaponHUDState(localplayer, weapon, wpnTbl)
    local weapon_clipsize = WPN_GetMaxClip1(weapon)
    local weapon_clip = WPN_Clip1(weapon)
    local primaryAmmoType = WPN_GetPrimaryAmmoType(weapon)
    local weapon_reserve = PLY_GetAmmoCount(localplayer, primaryAmmoType)

    local firemode_text = "AUTO"
    local firemode_pic = firemode_pics[-1]

    local chambered = math_max(weapon_clip - weapon_clipsize, 0)
    local clip_to_show = math_min(weapon_clip, weapon_clipsize)

    local inf_clip = false
    local inf_reserve = false
    local melee = false
    local jammed = false
    local showheat = false
    local heat = 0
    local heatcap = 100
    local heatlocked = false
    local multiple_modes = false

    if weapon_clipsize <= 0 then
        inf_clip = true
        clip_to_show = weapon_reserve
    end

    if wpnTbl.ARC9 then
        if wpnTbl.GetCustomize(weapon) then return nil end

        local gpv = wpnTbl.GetProcessedValue
        local arc9_mode = wpnTbl.GetCurrentFiremodeTable(weapon)
        firemode_text = wpnTbl.GetFiremodeName(weapon)

        if #wpnTbl.GetValue(weapon, "Firemodes") > 1 then
            multiple_modes = true
        end

        if gpv(weapon, "NoFiremodeWhenEmpty", true) and weapon_clip <= 0 then
            multiple_modes = false
        end

        if wpnTbl.GetUBGL(weapon) then
            firemode_text = gpv(weapon, "UBGLFiremodeName", true)
            arc9_mode = {
                Mode = wpnTbl.GetCurrentFiremode(weapon),
                PrintName = firemode_text
            }
            weapon_clipsize = WPN_GetMaxClip2(weapon)
            weapon_clip = WPN_Clip2(weapon)
            clip_to_show = weapon_clip
            weapon_reserve = PLY_GetAmmoCount(localplayer, WPN_GetSecondaryAmmoType(weapon))
            multiple_modes = false
        end

        if arc9_mode.Icon then
            firemode_pic = arc9_mode.Icon
        elseif firemode_pics[arc9_mode.Mode] then
            firemode_pic = firemode_pics[arc9_mode.Mode]
        elseif arc9_mode.Mode < 0 then
            firemode_pic = firemode_pics[-1]
        else
            firemode_pic = firemode_pics[3]
        end

        if wpnTbl.GetSafe(weapon) then
            firemode_pic = firemode_pics[0]
        end

        if wpnTbl.GetInfiniteAmmo(weapon) then
            inf_reserve = true
            weapon_reserve = 2147483640
        end

        if gpv(weapon, "BottomlessClip", true) then
            inf_clip = true
            weapon_reserve = weapon_reserve + weapon_clip
            clip_to_show = weapon_reserve
            weapon_clip = weapon_reserve
            weapon_clipsize = 1
            chambered = 0

            if inf_reserve then
                clip_to_show = 2147483640 - (wpnTbl.GetNthShot(weapon) % 2147483640)
            end
        end

        if wpnTbl.GetJammed(weapon) then
            jammed = true
        end

        if gpv(weapon, "Overheat", true) then
            showheat = true
            heat = wpnTbl.GetHeatAmount(weapon)
            heatcap = gpv(weapon, "HeatCapacity", true)
            heatlocked = wpnTbl.GetHeatLockout(weapon)
        end
    elseif wpnTbl.ArcCW then
        local arccw_mode = wpnTbl.GetCurrentFiremode(weapon)

        firemode_text = wpnTbl.GetFiremodeName(weapon)
        -- there was a reason I kept it to 4 letters you assholes

        firemode_text = string_Replace(firemode_text, "-", "")
        firemode_text = string_Replace(firemode_text, " ", "")
        firemode_text = string_sub(firemode_text, 1, 4)
        firemode_text = string_upper(firemode_text)

        if arccw_mode.Mode > 1 then
            firemode_pic = firemode_pics[-1]
        elseif arccw_mode.Mode == 1 then
            firemode_pic = firemode_pics[1]
        elseif firemode_pics[-arccw_mode.Mode] then
            firemode_pic = firemode_pics[-arccw_mode.Mode]
        else
            firemode_pic = firemode_pics[3]
        end
    elseif WPN_IsScripted(weapon) then
        if not wpnTbl.Primary.Automatic then
            firemode_pic = firemode_pics[1]
            firemode_text = ARC9:GetPhrase("hud.firemode.single")
        end

        if wpnTbl.ThreeRoundBurst then
            firemode_pic = firemode_pics[3]
            firemode_text = "3-" .. ARC9:GetPhrase("hud.firemode.burst")
        end

        if wpnTbl.TwoRoundBurst then
            firemode_pic = firemode_pics[2]
            firemode_text = "2-" .. ARC9:GetPhrase("hud.firemode.burst")
        end

        if wpnTbl.GetSafe and wpnTbl.GetSafe(weapon) then
            firemode_pic = firemode_pics[0]
            firemode_text = ARC9:GetPhrase("hud.firemode.safe")
        end

        if isfunction(wpnTbl.Safe) and wpnTbl.Safe(weapon) then
            firemode_pic = firemode_pics[0]
            firemode_text = ARC9:GetPhrase("hud.firemode.safe")
        end

        if isfunction(wpnTbl.Safety) and wpnTbl.Safety(weapon) then
            firemode_pic = firemode_pics[0]
            firemode_text = ARC9:GetPhrase("hud.firemode.safe")
        end
    else
        if not automatics[ENT_GetClass(weapon)] then
            firemode_pic = firemode_pics[1]
            firemode_text = ARC9:GetPhrase("hud.firemode.single")
        end
    end

    local flashammowidgets = (weapon_clip / weapon_clipsize) < 0.34 and weapon_clip ~= 0

    if weapon_clipsize <= 0 and primaryAmmoType == -1 then
        melee = true
        flashammowidgets = false
    end

    if inf_clip then
        weapon_clipsize = 30
    end

    if jammed then
        flashammowidgets = true
    end

    return weapon_clipsize, weapon_clip, weapon_reserve, firemode_text, firemode_pic, chambered, clip_to_show, inf_clip, inf_reserve, melee, jammed, showheat, heat, heatcap, heatlocked, multiple_modes, flashammowidgets
end

function ARC9.DrawHUD()
    EyeAngles() -- This, for some ungodly reason, allows sway to work when the HUD is off.
    EyePos()

    if not ARC9.ShouldDrawHUD() then
        DrawSimpleHints()
        return
    end

    local localplayer = LocalPlayer()
    if not localplayer or not ENT_IsValid(localplayer) then return end

    local weapon = PLY_GetActiveWeapon(localplayer)
    if not weapon or not ENT_IsValid(weapon) then return end

    local wpnTbl = ENT_GetTable(weapon)
    local ct = CurTime()

    if lastweapon ~= weapon then
        rackrisetime = ct
        lastrow = 0
        hidefadetime = ct
    end

    -- upvalue limit strikes again, had to split it off to a separate function :D
    local weapon_clipsize, weapon_clip, weapon_reserve, firemode_text, firemode_pic, chambered, clip_to_show, inf_clip, inf_reserve, melee, jammed, showheat, heat, heatcap, heatlocked, multiple_modes, flashammowidgets = getWeaponHUDState(localplayer, weapon, wpnTbl)
    if not weapon_clipsize then return end

    local flash_period = 3
    local isFlashTick = math_floor(ct * flash_period) % 2 == 0
    local heat_part = (heatlocked and isFlashTick) and "hi_3d" or "fg_3d"
    local am_part = ((flashammowidgets and isFlashTick) or (weapon_clip == 0 and not melee)) and "hi_3d" or "fg_3d"

    local s_right = 2
    local s_down = 1

    local scrw, scrh = ScrW(), ScrH()
    local anchorwidth = math_min(scrw * 0.5, scrh * 0.5)

    cam_Start3D(nil, nil, 55, deadzonex, scrh - anchorwidth, anchorwidth, anchorwidth)

    local ang = EyeAngles()
    local up, right, forward = ANG_Up(ang), ANG_Right(ang), ANG_Forward(ang)

    ANG_RotateAroundAxis(ang, up, 180)
    ANG_RotateAroundAxis(ang, right, 105)
    ANG_RotateAroundAxis(ang, forward, -95)

    local pos = EyePos() + (forward * 4) + (up * -0.25) + (right * -1.5)
    pos, ang = ARC9.HUDBob(pos, ang)
    pos, ang = ARC9.HUDSway(pos, ang)

    local compatc = arc9_hud_compact

    cam_Start3D2D(pos, ang, 0.0125)
        if compatc then
            setDrawHUDColor("bg_3d", 20)
            surface_DrawRect(0, 0, 254, 80)

            setDrawHUDColor("bg_3d", 100)
            surface_SetMaterial(hud_bg)
            surface_DrawTexturedRect(0, 0, 254, 80)
            surface_DrawLine(0, 85, 254, 85)

            surface_SetDrawColor(0, 0, 0, 50)
            surface_SetMaterial(hud_logo_lowvis)
            surface_DrawTexturedRect(87, 0, 80, 80)
        else
            setDrawHUDColor("bg_3d", 20)
            surface_DrawRect(0, 0, 254, 110)

            setDrawHUDColor("bg_3d", 100)
            surface_SetMaterial(hud_bg)
            surface_DrawTexturedRect(0, 0, 254, 110)
            surface_DrawLine(0, 115, 254, 115)

            surface_SetDrawColor(0, 0, 0, 50)
            surface_SetMaterial(hud_logo_lowvis)
            surface_DrawTexturedRect(72, 0, 110, 110)
        end

        local deco_x = 6
        local deco_y = 2
        local deco = ARC9:GetPhrase("hud.version") .. ARC9.Version

        setTextHUDColor("shadow_3d", 100)
        surface_SetFont("ARC9_Deco_8_Unscaled")
        surface_SetTextPos(deco_x + s_right, deco_y + s_down)
        surface_DrawText(deco)

        setTextHUDColor("fg_3d", 255)
        surface_SetFont("ARC9_Deco_8_Unscaled")
        surface_SetTextPos(deco_x, deco_y)
        surface_DrawText(deco)

        local health_x = 8
        local health_y = 9
        local curHealth = ENT_Health(localplayer)
        local maxHealth = ENT_GetMaxHealth(localplayer)
        local curArmor = PLY_Armor(localplayer)
        local health = math_Clamp(curHealth / maxHealth, 0, 99.99)
        local overheal = curHealth > maxHealth or curArmor > 100

        local flashHealth = curHealth <= 10 and isFlashTick
        local hb_part = flashHealth and "hi_3d" or "fg_3d"
        local hb_alpha = flashHealth and 170 or 225

        local hb_left = 30
        local hb_tall = 24
        local hb_wide = (compatc and showheat) and 140 or 209

        if not overheal then
            if curArmor > 0 then
                hb_tall = 18
                local armor = math_min(curArmor * 0.01, 1)
                local armorW = hb_wide * armor

                setDrawHUDColor("shadow_3d", 100)
                surface_DrawRect(hb_left + s_right, 32 + s_down, armorW, 3)

                setDrawHUDColor(hb_part, hb_alpha)
                surface_DrawRect(hb_left, 32, armorW, 3)
            end

            local healthW = hb_wide * health
            setDrawHUDColor("shadow_3d", 100)
            if health < 1 then
                surface_DrawLine(hb_wide + hb_left + s_right, 12 + s_down, hb_wide + hb_left + s_right, 12 + hb_tall + s_down)
            end
            surface_DrawRect(hb_left + s_right, 12 + s_down, healthW, hb_tall)

            setDrawHUDColor(hb_part, hb_alpha)
            if health < 1 then
                surface_DrawLine(hb_wide + hb_left, 12, hb_wide + hb_left, 12 + hb_tall)
            end
            surface_DrawRect(hb_left, 12, healthW, hb_tall)
        end

        local healthtext = overheal and ("♥:" .. tostring(math_ceil(health * 100)) .. "%") or "♥"

        setTextHUDColor("shadow_3d", 100)
        surface_SetFont("ARC9_24_LCD")
        surface_SetTextPos(health_x + s_right, health_y + s_down)
        surface_DrawText(healthtext)

        setTextHUDColor(hb_part, 255)
        surface_SetFont("ARC9_24_LCD")
        surface_SetTextPos(health_x, health_y)
        surface_DrawText(healthtext)

        if overheal then
            local armor_y = 9
            local armorStr = "⌂:" .. tostring(math_ceil(math_Round(curArmor))) .. "%"

            surface_SetFont("ARC9_24_LCD")
            local armor_x = 250 - surface_GetTextSize(armorStr)

            setTextHUDColor("shadow_3d", 100)
            surface_SetTextPos(armor_x + s_right, armor_y + s_down)
            surface_DrawText(armorStr)

            setTextHUDColor("fg_3d", 255)
            surface_SetTextPos(armor_x, armor_y)
            surface_DrawText(armorStr)
        end

        if showheat then
            local therm_x = 174
            local therm_y = compatc and 6 or 66
            local therm_w = 70
            local therm_h = 35
            local therm_deco_x = 190
            local therm_deco_y = compatc and 5 or 97
            local therm_deco = ARC9:GetPhrase("hud.therm_deco")

            setTextHUDColor("shadow_3d", 100)
            surface_SetFont("ARC9_Deco_8_Unscaled")
            surface_SetTextPos(therm_deco_x + s_right, therm_deco_y + s_down)
            surface_DrawText(therm_deco)

            setTextHUDColor("fg_3d", 255)
            surface_SetFont("ARC9_Deco_8_Unscaled")
            surface_SetTextPos(therm_deco_x, therm_deco_y)
            surface_DrawText(therm_deco)

            local fill = math_Clamp(0.05 + (0.9 * heat) / heatcap, 0, 1)
            local fillW = math_ceil(therm_w * fill)
            local remW = therm_w * (1 - fill)

            setDrawHUDColor("shadow_3d", 100)
            surface_SetMaterial(hud_t_full)
            surface_DrawTexturedRectUV(therm_x + s_right, therm_y + s_down, fillW, therm_h, 0, 0, fill, 1)

            setDrawHUDColor(heat_part, 200)
            surface_SetMaterial(hud_t_full)
            surface_DrawTexturedRectUV(therm_x, therm_y, fillW, therm_h, 0, 0, fill, 1)

            setDrawHUDColor("shadow_3d", 100)
            surface_SetMaterial(hud_t_empty)
            surface_DrawTexturedRectUV(therm_x + fillW + s_right, therm_y + s_down, remW, therm_h, fill, 0, 1, 1)

            setDrawHUDColor(heat_part, 200)
            surface_SetMaterial(hud_t_empty)
            surface_DrawTexturedRectUV(therm_x + fillW, therm_y, remW, therm_h, fill, 0, 1, 1)
        end

        local ammo_x = 8
        local ammo_y = 40
        local ammo_text

        if jammed then
            ammo_text = ARC9:GetPhrase("hud.jammed")
        elseif melee then
            ammo_text = "-"
        elseif inf_reserve then
            ammo_text = inf_clip and "∞" or (tostring(weapon_clip) .. "/∞")
        else
            ammo_text = inf_clip and tostring(weapon_reserve) or (tostring(weapon_clip) .. "/" .. tostring(weapon_reserve))
        end

        setTextHUDColor("shadow_3d", 100)
        surface_SetFont("ARC9_24_LCD")
        surface_SetTextPos(ammo_x + s_right, ammo_y + s_down)
        surface_DrawText(ammo_text)

        setTextHUDColor(am_part, 255)
        surface_SetFont("ARC9_24_LCD")
        surface_SetTextPos(ammo_x, ammo_y)
        surface_DrawText(ammo_text)

        local fmi_x = 215
        local fmi_y = 38
        local fmi_s = 30

        setDrawHUDColor("shadow_3d", 100)
        surface_SetMaterial(firemode_pic)
        surface_DrawTexturedRect(fmi_x + s_right, fmi_y + s_down, fmi_s, fmi_s)

        setDrawHUDColor("fg_3d", 255)
        surface_SetMaterial(firemode_pic)
        surface_DrawTexturedRect(fmi_x, fmi_y, fmi_s, fmi_s)

        local fmm_x = 212
        local fmm_y = multiple_modes and 39 or 45

        setTextHUDColor("shadow_3d", 100)
        surface_SetFont("ARC9_12_Unscaled")
        local fmm_w = surface_GetTextSize(firemode_text)
        surface_SetTextPos(fmm_x + s_right - fmm_w, fmm_y + s_down)
        surface_DrawText(firemode_text)

        setTextHUDColor("fg_3d", 255)
        surface_SetFont("ARC9_12_Unscaled")
        surface_SetTextPos(fmm_x - fmm_w, fmm_y)
        surface_DrawText(firemode_text)

        if multiple_modes then
            local fmh_text = ARC9.GetBindKey("+zoom")
            local fmh_x = 212
            local fmh_y = 53

            if ARC9.CTRL_Lookup[fmh_text] then fmh_text = ARC9.CTRL_Lookup[fmh_text] end
            if ARC9.CTRL_ConvertTo[fmh_text] then fmh_text = ARC9.CTRL_ConvertTo[fmh_text] end

            local fmhArg
            if ARC9.CTRL_Exists[fmh_text] then
                scratchGlyph1[1] = getGlyphMaterial(ARC9.GlyphFamilyHUD(), fmh_text, false)
                scratchGlyph1[2] = 15
                fmhArg = scratchGlyph1
            else
                fmhArg = "[" .. fmh_text .. "]"
            end

            setDrawHUDColor("shadow", 100)
            setTextHUDColor("shadow", 100)
            surface_SetFont("ARC9_12_LCD")
            scratchKeyLineInfo.font_keyb = nil
            scratchKeyLineInfo.font = "ARC9_12_LCD"
            scratchKeyLineInfo.size = 16
            local fmh_w = GetControllerKeyLineSize(scratchKeyLineInfo, fmhArg)

            scratchKeyLineInfo.x = fmh_x + s_right - fmh_w
            scratchKeyLineInfo.y = fmh_y + s_down
            CreateControllerKeyLine(scratchKeyLineInfo, fmhArg)

            setDrawHUDColor("fg", 200 * hint_alpha)
            setTextHUDColor("fg_3d", 255)
            surface_SetFont("ARC9_12_LCD")
            scratchKeyLineInfo.x = fmh_x - fmh_w
            scratchKeyLineInfo.y = fmh_y
            CreateControllerKeyLine(scratchKeyLineInfo, fmhArg)
        end

        if not compatc then
            local b_alpha = 225
            local b_m_left = -8
            local b_m_down = 72
            local b_m_margin = 2
            local row_size = showheat and 10 or 15

            local row1_bullets = 0
            local row2_bullets = 0
            local rackrise = 0

            local disparity = weapon_clipsize % row_size
            local corrected = clip_to_show - disparity
            local row = math_ceil(corrected / row_size)
            local sb = 14
            local crc = disparity > 0 and (clip_to_show + row_size - disparity) or clip_to_show

            if crc > row_size then
                row2_bullets = math_min(row_size, clip_to_show + disparity)
                row1_bullets = corrected % row_size
                if row1_bullets == 0 then
                    row1_bullets = row_size
                end
                if clip_to_show <= row_size + disparity then
                    row2_bullets = disparity
                end
                if row < lastrow then
                    rackrisetime = ct
                end
                lastrow = row
            else
                row2_bullets = clip_to_show
            end

            if rackrisetime + 0.2 > ct then
                local rackrisedelta = ((rackrisetime + 0.2) - ct) * 5
                rackrise = rackrisedelta * (sb + b_m_margin)
            end

            local stepX = sb + b_m_margin
            local row1Y = b_m_down + rackrise
            for i = 1, row1_bullets do
                local bx = b_m_left + (stepX * i)
                setDrawHUDColor("shadow_3d", 100)
                surface_DrawRect(bx + s_right, row1Y + s_down, sb, sb)

                setDrawHUDColor((row1_bullets - i < chambered) and "hi_3d" or "fg_3d", b_alpha)
                surface_DrawRect(bx, row1Y, sb, sb)
            end

            local row2Y = b_m_down + stepX + rackrise
            local remChambered = chambered - row1_bullets
            for i = 1, row2_bullets do
                local bx = b_m_left + (stepX * i)
                setDrawHUDColor("shadow_3d", 100)
                surface_DrawRect(bx + s_right, row2Y + s_down, sb, sb)

                setDrawHUDColor((row2_bullets - i < remChambered) and "hi_3d" or "fg_3d", b_alpha)
                surface_DrawRect(bx, row2Y, sb, sb)
            end
        end
    cam_End3D2D()

    if wpnTbl.ARC9 and convar_hints > 0 then
        draw3D2DHints(weapon, wpnTbl, pos, ang, ct)
    end

    cam_End3D()

    lastweapon = weapon
end

hook.Add("HUDPaint", "ARC9_DrawHud", ARC9.DrawHUD)

-- Controller / key additions by Fesiug. Blame Fesiug!

local convar_controllermode_cvar = GetConVar("arc9_controller")
local convar_controllermode = convar_controllermode_cvar and convar_controllermode_cvar:GetBool() or false
if convar_controllermode_cvar then
    local varname = convar_controllermode_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v) convar_controllermode = tobool(v) end, varname)
end

function ARC9.ControllerMode()
    return convar_controllermode
end

ARC9.CTRL_Set_Xbox = {}
ARC9.CTRL_Set_UserCustom = {}
ARC9.CTRL_ConvertTo = ARC9.CTRL_Set_Xbox

local glyphFamilyMap = {
    light = "glyphs_light/",
    dark = "glyphs_dark/",
    knockout = "glyphs_knockout/",
}

local arc9_glyph_family_hud_cvar = GetConVar("arc9_glyph_family_hud")
local glyphFamilyHUD = glyphFamilyMap[arc9_glyph_family_hud_cvar and arc9_glyph_family_hud_cvar:GetString() or ""] or "glyphs_light/"
if arc9_glyph_family_hud_cvar then
    local varname = arc9_glyph_family_hud_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v)
        glyphFamilyHUD = glyphFamilyMap[tostring(v)] or "glyphs_light/"
    end, varname)
end

function ARC9.GlyphFamilyHUD()
    return glyphFamilyHUD
end

local arc9_glyph_family_cust_cvar = GetConVar("arc9_glyph_family_cust")
local glyphFamilyCust = glyphFamilyMap[arc9_glyph_family_cust_cvar and arc9_glyph_family_cust_cvar:GetString() or ""] or "glyphs_light/"
if arc9_glyph_family_cust_cvar then
    local varname = arc9_glyph_family_cust_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v)
        glyphFamilyCust = glyphFamilyMap[tostring(v)] or "glyphs_light/"
    end, varname)
end

function ARC9.GlyphFamilyCust()
    return glyphFamilyCust
end

local glyphSetMap = {
    xbox = "Xbox/",
    ps = "PS/",
    switch = "Switch/",
}

local arc9_glyph_type_cvar = GetConVar("arc9_glyph_type")
local glyphSet = glyphSetMap[arc9_glyph_type_cvar and arc9_glyph_type_cvar:GetString() or ""] or "Xbox/"
if arc9_glyph_type_cvar then
    local varname = arc9_glyph_type_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v)
        glyphSet = glyphSetMap[tostring(v)] or "Xbox/"
    end, varname)
end

function ARC9.GlyphSet()
    return glyphSet
end

ARC9.CTRL_Lookup = {
    MOUSE1 = "shared_mouse_l_click_lg",
    MOUSE2 = "shared_mouse_r_click_lg",
    MOUSE3 = "shared_mouse_mid_click_lg",
    MOUSE4 = "shared_mouse_5_lg",
    MOUSE5 = "shared_mouse_4_lg",

    MWHEELUP = "shared_mouse_scroll_up_lg",
    MWHEELDOWN = "shared_mouse_scroll_down_lg",

    KP_INS        = "KP 0",
    KP_END        = "KP 1",
    KP_DOWNARROW  = "KP 2",
    KP_PGDN       = "KP 3",
    KP_LEFTARROW  = "KP 4",
    KP_5          = "KP 5",
    KP_RIGHTARROW = "KP 6",
    KP_HOME       = "KP 7",
    KP_UPARROW    = "KP 8",
    KP_PGUP       = "KP 9",
    KP_SLASH      = "KP /",
    KP_MULTIPLY   = "KP *",
    KP_MINUS      = "KP -",
    KP_PLUS       = "KP +",
    KP_ENTER      = "KP ENTER",
    KP_DEL        = "KP .",

}

ARC9.CTRL_Exists = {

--[[
    mousel =  true,
    mousemid =  true,
    mouser =  true,
    mouse4 =  true,
    mouse5 =  true,
    mousewhup =  true,
    mousewhdown =  true,

-- Shared
    faced = true,
    facel = true,
    facer = true,
    faceu = true,
    stickl = true,
    stickr = true,
    sticklc = true,
    stickrc = true,
    triggerl = true,
    triggerr = true,
    bumperl = true,
    bumperr = true,
    back = true,
    start = true,
    dpadd = true,
    dpadl = true,
    dpadr = true,
    dpadu = true,
--]]

    ps4_button_logo_lg =  true,
    ps4_button_options_lg =  true,
    ps4_button_share_lg =  true,
    ps4_l1_lg =  true,
    ps4_l2_lg =  true,
    ps4_r1_lg =  true,
    ps4_r2_lg =  true,
    ps4_trackpad_click_lg =  true,
    ps4_trackpad_down_lg =  true,
    ps4_trackpad_l_click_lg =  true,
    ps4_trackpad_l_down_lg =  true,
    ps4_trackpad_l_left_lg =  true,
    ps4_trackpad_l_right_lg =  true,
    ps4_trackpad_l_ring_lg =  true,
    ps4_trackpad_l_swipe_lg =  true,
    ps4_trackpad_l_touch_lg =  true,
    ps4_trackpad_l_up_lg =  true,
    ps4_trackpad_left_lg =  true,
    ps4_trackpad_lg =  true,
    ps4_trackpad_r_click_lg =  true,
    ps4_trackpad_r_down_lg =  true,
    ps4_trackpad_r_left_lg =  true,
    ps4_trackpad_r_right_lg =  true,
    ps4_trackpad_r_ring_lg =  true,
    ps4_trackpad_r_swipe_lg =  true,
    ps4_trackpad_r_touch_lg =  true,
    ps4_trackpad_r_up_lg =  true,
    ps4_trackpad_right_lg =  true,
    ps4_trackpad_ring_lg =  true,
    ps4_trackpad_swipe_lg =  true,
    ps4_trackpad_up_lg =  true,
    ps5_button_create_lg =  true,
    ps5_button_options_lg =  true,
    ps5_l1_lg =  true,
    ps5_l2_lg =  true,
    ps5_r1_lg =  true,
    ps5_r2_lg =  true,
    ps5_trackpad_click_lg =  true,
    ps5_trackpad_down_lg =  true,
    ps5_trackpad_l_click_lg =  true,
    ps5_trackpad_l_down_lg =  true,
    ps5_trackpad_l_left_lg =  true,
    ps5_trackpad_l_right_lg =  true,
    ps5_trackpad_l_ring_lg =  true,
    ps5_trackpad_l_swipe_lg =  true,
    ps5_trackpad_l_touch_lg =  true,
    ps5_trackpad_l_up_lg =  true,
    ps5_trackpad_left_lg =  true,
    ps5_trackpad_lg =  true,
    ps5_trackpad_r_click_lg =  true,
    ps5_trackpad_r_down_lg =  true,
    ps5_trackpad_r_left_lg =  true,
    ps5_trackpad_r_right_lg =  true,
    ps5_trackpad_r_ring_lg =  true,
    ps5_trackpad_r_swipe_lg =  true,
    ps5_trackpad_r_touch_lg =  true,
    ps5_trackpad_r_up_lg =  true,
    ps5_trackpad_right_lg =  true,
    ps5_trackpad_ring_lg =  true,
    ps5_trackpad_swipe_lg =  true,
    ps5_trackpad_up_lg =  true,
    ps_button_circle_lg =  true,
    ps_button_mute_lg =  true,
    ps_button_square_lg =  true,
    ps_button_triangle_lg =  true,
    ps_button_x_lg =  true,
    ps_color_button_circle_lg =  true,
    ps_color_button_square_lg =  true,
    ps_color_button_triangle_lg =  true,
    ps_color_button_x_lg =  true,
    ps_color_outlined_button_circle_lg =  true,
    ps_color_outlined_button_square_lg =  true,
    ps_color_outlined_button_triangle_lg =  true,
    ps_color_outlined_button_x_lg =  true,
    ps_dpad_down_lg =  true,
    ps_dpad_left_lg =  true,
    ps_dpad_lg =  true,
    ps_dpad_right_lg =  true,
    ps_dpad_up_lg =  true,
    ps_outlined_button_circle_lg =  true,
    ps_outlined_button_square_lg =  true,
    ps_outlined_button_triangle_lg =  true,
    ps_outlined_button_x_lg =  true,
    sc_button_l_arrow_lg =  true,
    sc_button_r_arrow_lg =  true,
    sc_button_steam_lg =  true,
    sc_dpad_click_lg =  true,
    sc_dpad_down_lg =  true,
    sc_dpad_left_lg =  true,
    sc_dpad_lg =  true,
    sc_dpad_right_lg =  true,
    sc_dpad_swipe_lg =  true,
    sc_dpad_touch_lg =  true,
    sc_dpad_up_lg =  true,
    sc_lb_lg =  true,
    sc_lg_lg =  true,
    sc_lt_click_lg =  true,
    sc_lt_lg =  true,
    sc_rb_lg =  true,
    sc_rg_lg =  true,
    sc_rt_click_lg =  true,
    sc_rt_lg =  true,
    sc_touchpad_click_lg =  true,
    sc_touchpad_down_lg =  true,
    sc_touchpad_edge_lg =  true,
    sc_touchpad_left_lg =  true,
    sc_touchpad_lg =  true,
    sc_touchpad_right_lg =  true,
    sc_touchpad_swipe_lg =  true,
    sc_touchpad_touch_lg =  true,
    sc_touchpad_up_lg =  true,
    sd_button_aux_lg =  true,
    sd_button_menu_lg =  true,
    sd_button_steam_lg =  true,
    sd_button_view_lg =  true,
    sd_l1_lg =  true,
    sd_l2_half_lg =  true,
    sd_l2_lg =  true,
    sd_l4_lg =  true,
    sd_l5_lg =  true,
    sd_ltrackpad_click_lg =  true,
    sd_ltrackpad_down_lg =  true,
    sd_ltrackpad_left_lg =  true,
    sd_ltrackpad_lg =  true,
    sd_ltrackpad_right_lg =  true,
    sd_ltrackpad_ring_lg =  true,
    sd_ltrackpad_swipe_lg =  true,
    sd_ltrackpad_up_lg =  true,
    sd_r1_lg =  true,
    sd_r2_half_lg =  true,
    sd_r2_lg =  true,
    sd_r4_lg =  true,
    sd_r5_lg =  true,
    sd_rtrackpad_click_lg =  true,
    sd_rtrackpad_down_lg =  true,
    sd_rtrackpad_left_lg =  true,
    sd_rtrackpad_lg =  true,
    sd_rtrackpad_right_lg =  true,
    sd_rtrackpad_ring_lg =  true,
    sd_rtrackpad_swipe_lg =  true,
    sd_rtrackpad_up_lg =  true,
    shared_button_a_lg =  true,
    shared_button_b_lg =  true,
    shared_button_x_lg =  true,
    shared_button_y_lg =  true,
    shared_buttons_e_lg =  true,
    shared_buttons_n_lg =  true,
    shared_buttons_s_lg =  true,
    shared_buttons_w_lg =  true,
    shared_color_button_a_lg =  true,
    shared_color_button_b_lg =  true,
    shared_color_button_x_lg =  true,
    shared_color_button_y_lg =  true,
    shared_color_outlined_button_a_lg =  true,
    shared_color_outlined_button_b_lg =  true,
    shared_color_outlined_button_x_lg =  true,
    shared_color_outlined_button_y_lg =  true,
    shared_dpad_down_lg =  true,
    shared_dpad_left_lg =  true,
    shared_dpad_lg =  true,
    shared_dpad_right_lg =  true,
    shared_dpad_up_lg =  true,
    shared_gyro_lg =  true,
    shared_gyro_pitch_lg =  true,
    shared_gyro_roll_lg =  true,
    shared_gyro_yaw_lg =  true,
    shared_l3_lg =  true,
    shared_lstick_click_lg =  true,
    shared_lstick_down_lg =  true,
    shared_lstick_left_lg =  true,
    shared_lstick_lg =  true,
    shared_lstick_right_lg =  true,
    shared_lstick_touch_lg =  true,
    shared_lstick_up_lg =  true,
    shared_mouse_4_lg =  true,
    shared_mouse_5_lg =  true,
    shared_mouse_l_click_lg =  true,
    shared_mouse_mid_click_lg =  true,
    shared_mouse_r_click_lg =  true,
    shared_mouse_scroll_down_lg =  true,
    shared_mouse_scroll_up_lg =  true,
    shared_outlined_button_a_lg =  true,
    shared_outlined_button_b_lg =  true,
    shared_outlined_button_x_lg =  true,
    shared_outlined_button_y_lg =  true,
    shared_r3_lg =  true,
    shared_rstick_click_lg =  true,
    shared_rstick_down_lg =  true,
    shared_rstick_left_lg =  true,
    shared_rstick_lg =  true,
    shared_rstick_right_lg =  true,
    shared_rstick_touch_lg =  true,
    shared_rstick_up_lg =  true,
    switchpro_button_capture_lg =  true,
    switchpro_button_home_lg =  true,
    switchpro_button_minus_lg =  true,
    switchpro_button_plus_lg =  true,
    switchpro_dpad_down_lg =  true,
    switchpro_dpad_left_lg =  true,
    switchpro_dpad_lg =  true,
    switchpro_dpad_right_lg =  true,
    switchpro_dpad_up_lg =  true,
    switchpro_l2_lg =  true,
    switchpro_l_lg =  true,
    switchpro_lstick_click_lg =  true,
    switchpro_lstick_down_lg =  true,
    switchpro_lstick_left_lg =  true,
    switchpro_lstick_lg =  true,
    switchpro_lstick_right_lg =  true,
    switchpro_lstick_up_lg =  true,
    switchpro_r2_lg =  true,
    switchpro_r_lg =  true,
    switchpro_rstick_click_lg =  true,
    switchpro_rstick_down_lg =  true,
    switchpro_rstick_left_lg =  true,
    switchpro_rstick_lg =  true,
    switchpro_rstick_right_lg =  true,
    switchpro_rstick_up_lg =  true,
    xbox360_button_select_lg =  true,
    xbox360_button_start_lg =  true,
    xbox_button_logo_lg =  true,
    xbox_button_select_lg =  true,
    xbox_button_share_lg =  true,
    xbox_button_start_lg =  true,
    xbox_lb_lg =  true,
    xbox_lt_lg =  true,
    xbox_p1_lg =  true,
    xbox_p2_lg =  true,
    xbox_p3_lg =  true,
    xbox_p4_lg =  true,
    xbox_rb_lg =  true,
    xbox_rt_lg =  true,
}

surface.CreateFont("ARC9_KeybindPreview", {
    font = "Arial",
    size = 16,
    weight = 600,
    antialias = false,
})

local function parseGlyphSet(glyphset)
    if glyphset and glyphset ~= "" then
        table_Empty(ARC9.CTRL_Set_UserCustom)
        local config = string_Split(glyphset, "\\n")
        for i = 1, #config do
            local swig = string_Split(config[i], "\\t")
            if swig[1] then
                ARC9.CTRL_Set_UserCustom[swig[1]] = swig[2]
            end
        end
        ARC9.CTRL_ConvertTo = ARC9.CTRL_Set_UserCustom
    else
        ARC9.CTRL_ConvertTo = ARC9.CTRL_Set_Xbox
    end
end

local arc9_controller_glyphset_cvar = GetConVar("arc9_controller_glyphset")
if arc9_controller_glyphset_cvar then
    parseGlyphSet(arc9_controller_glyphset_cvar:GetString())
    local varname = arc9_controller_glyphset_cvar:GetName()
    cvars.AddChangeCallback(varname, function(_, _, v)
        parseGlyphSet(tostring(v))
    end, varname)
end

--[[
    Creates a controller key line.
Info:
     x: X position
     y: Y position
     size: Height of font
     font: Font to use

Vararg:
    String: Out goes a string.
    Table:
        If it has a proper glyph name, it is used.
        If it doesn't, it is made into a key.
]]
function CreateControllerKeyLine(info, ...)
    local strlength = 0
    local ctrlExists = ARC9.CTRL_Exists
    local count = select("#", ...)
    local infoX,  infoY,  infoSize,  infoFont =
          info.x, info.y, info.size, info.font

    for i = 1, count do
        local v = select(i, ...)
        if IsColor(v) then
            surface_SetDrawColor(v.r, v.g, v.b, v.a)
            surface_SetTextColor(v.r, v.g, v.b, v.a)
        elseif isstring(v) then
            if v ~= "" then
                surface_SetTextPos(infoX + strlength, infoY)
                surface_DrawText(v)
                strlength = strlength + surface_GetTextSize(v)
            end
        elseif istable(v) then
            local v1, size = v[1], v[2]
            if isstring(v1) and not ctrlExists[v1] then
                surface_SetFont(info.font_keyb or "ARC9_KeybindPreview")
                local sx, sy = surface_GetTextSize(v1)
                local keylength = math_max(sx + (infoSize * 0.5), infoSize)
                surface_DrawOutlinedRect(infoX + strlength, infoY, keylength, infoSize)
                surface_SetTextPos(infoX + strlength - (sx * 0.5) + (keylength * 0.5), infoY - (sy * 0.5) + (infoSize * 0.5))
                surface_DrawText(v1)
                surface_SetFont(infoFont)
                strlength = strlength + keylength
            elseif v1 then
                surface_SetMaterial(v1)
                surface_DrawTexturedRect(infoX + strlength, infoY, size * 1.25, size * 1.25)
                strlength = strlength + size
            end
        end
    end

    return strlength
end

-- Gets the size of the controller key line.
function GetControllerKeyLineSize(info, ...)
    local strlength = 0
    local infoSize, infoFont = info.size, info.font
    local ctrlExists = ARC9.CTRL_Exists
    local count = select("#", ...)

    for i = 1, count do
        local v = select(i, ...)
        if isstring(v) then
            if v ~= "" then
                strlength = strlength + surface_GetTextSize(v)
            end
        elseif istable(v) then
            local v1, size = v[1], v[2]
            if isstring(v1) and not ctrlExists[v1] then
                surface_SetFont(info.font_keyb or "ARC9_KeybindPreview")
                local sx = surface_GetTextSize(v1)
                local keylength = math_max(sx + (infoSize * 0.5), infoSize)
                surface_SetFont(infoFont)
                strlength = strlength + keylength
            else
                strlength = strlength + size
            end
        end
    end

    return strlength
end

function ARC9MultiLineText(text, maxw, font)
    local content = {}
    local tline = ""
    local x = 0
    surface_SetFont(font)

    local ts = surface_GetTextSize(" ")
    local newlined = string_Split(text, "\n")

    for i = 1, #newlined do
        local words = string_Split(newlined[i], " ")

        -- Keep track of the current color tag across lines
        local active_color_tag = nil

        for j = 1, #words do
            local word = words[j]
            local tx = surface_GetTextSize(word)

            local openCount, closeCount = 0, 0
            local lastOpenTag

            -- Don't count color tags for length purposes
            for tag in string_gmatch(word, "<color=%d+,%d+,%d+>") do
                tx = tx - surface_GetTextSize(tag)
                openCount = openCount + 1
                lastOpenTag = tag
            end
            for tag in string_gmatch(word, "</color>") do
                tx = tx - surface_GetTextSize(tag)
                closeCount = closeCount + 1
            end
            for tag in string_gmatch(word, "<font=[^>]+>") do
                tx = tx - surface_GetTextSize(tag)
            end
            for tag in string_gmatch(word, "</font>") do
                tx = tx - surface_GetTextSize(tag)
            end

            if x + tx > maxw then
                local dashi = string_find(word, "-")
                if dashi and surface_GetTextSize(utf8_sub(word, 0, dashi)) <= maxw - x then
                    -- cut the word at the dash sign if possible
                    table_insert(content, tline .. utf8_sub(word, 0, dashi))
                    tline = ""
                    x = 0
                    word = utf8_sub(word, dashi + 1)
                    tx = surface_GetTextSize(word)
                else
                    -- move whole word to new line

                    -- close color tag
                    if active_color_tag ~= nil then
                        tline = tline .. "</color>"
                    end

                    table_insert(content, tline)
                    x = 0

                    -- reopen color tag if applicable
                    tline = active_color_tag or ""
                end
            end

            -- Check the status of the color tag at the end of current word
            if math_abs(openCount - closeCount) > 1 then
                ErrorNoHalt("<color> tag miscount!\n")
            elseif openCount > closeCount then
                if active_color_tag ~= nil then
                    ErrorNoHalt("<color> tag miscount (too many opening tags)!\n")
                else
                    active_color_tag = lastOpenTag
                end
            elseif closeCount > openCount then
                if active_color_tag == nil then
                    ErrorNoHalt("<color> tag miscount (too many closing tags)!\n")
                else
                    active_color_tag = nil
                end
            end

            tline = tline .. word .. " "
            x = x + tx + ts
        end

        -- close color tag
        if active_color_tag ~= nil then
            tline = tline .. "</color>"
        end

        table_insert(content, tline)
        tline = ""
        x = 0
    end

    return content
end

-- span: panel that hosts the rotating text
-- txt: the text to draw
-- x: where to start the crop
-- y: where to start the crp
-- tx, ty: where to draw the text
-- maxw: maximum width
-- only: don't advance text
function ARC9.DrawTextRot(span, txt, x, y, tx, ty, maxw, only)
    local tw, th = surface_GetTextSize(txt or "")
    local textRot = span.TextRot
    if not textRot then
        textRot = {}
        span.TextRot = textRot
    end

    if tw > maxw then
        local realx, realy = span:LocalToScreen(x, y)
        render_SetScissorRect(realx, realy, realx + maxw, realy + (th * 2), true)

        local rotOffset = textRot[txt] or 0

        if not only then
            local ct = CurTime()
            span.StartTextRot = span.StartTextRot or ct
            local state = span.TextRotState or 0 -- 0: start, 1: moving, 2: end

            if state == 0 then
                rotOffset = 0
                if span.StartTextRot < ct - 2 then
                    span.TextRotState = 1
                end
            elseif state == 1 then
                rotOffset = rotOffset + (FrameTime() * ARC9ScreenScale(32))
                if rotOffset >= (tw - maxw) + ARC9ScreenScale(8) then
                    span.StartTextRot = ct
                    span.TextRotState = 2
                end
            elseif state == 2 then
                if span.StartTextRot < ct - 2 then
                    span.TextRotState = 3
                    span.StartTextRot = ct
                end
            elseif state == 3 then
                rotOffset = rotOffset - (FrameTime() * ARC9ScreenScale(32))
                if rotOffset <= 0 then
                    span.StartTextRot = ct
                    span.TextRotState = 0
                end
            end

            textRot[txt] = rotOffset
        end

        surface_SetTextPos(tx - rotOffset, ty)
        surface_DrawText(txt)
        render_SetScissorRect(0, 0, 0, 0, false)
    else
        surface_SetTextPos(tx, ty)
        surface_DrawText(txt)
    end
end
