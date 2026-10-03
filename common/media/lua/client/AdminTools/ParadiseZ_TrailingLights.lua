require "ISUI/ISPanel"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISLabel"
require "ISUI/ISButton"
require "ISUI/ISTickBox"
require "ISUI/ISComboBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISColorPickerHSB"
require "RadioCom/ISUIRadio/ISSliderPanel"

local existingTL = rawget(_G, "ParadiseZTrailingLights")
if existingTL and existingTL.teardown then
    pcall(function() existingTL.teardown(false) end)
end

local TL = {}
_G.ParadiseZTrailingLights = TL

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6
local TWO_PI = math.pi * 2.0
local LIGHT_EPSILON = 0.003

TL.VERSION = "2026-07-28-working-ui-4b"
TL.VIS_LOCAL = "local"
TL.VIS_ADMINS = "admins"
TL.VIS_EVERYONE = "everyone"
-- Legacy value kept only so existing saved light settings continue to work.
TL.VIS_SHARED = "shared"

TL.EFFECT_NONE = "none"
TL.EFFECT_FLASH = "flash"
TL.EFFECT_STROBE = "strobe"
TL.EFFECT_FIRE = "fire"
TL.EFFECT_STORM = "storm"
TL.EFFECT_MYSTIC = "mystic"
TL.EFFECT_HORROR = "horror"

local DEFAULT_COLOR = ColorInfo.new(1.0, 0.85, 0.50, 1.0)
local DEFAULT_H, DEFAULT_S, DEFAULT_V = ISColorPickerHSB:toHSB(DEFAULT_COLOR:toColor())

TL.MD = {
    enabled = "ParadiseZTL_enabled",
    visibility = "ParadiseZTL_visibility",
    effect = "ParadiseZTL_effect",
    h = "ParadiseZTL_h",
    s = "ParadiseZTL_s",
    r = "ParadiseZTL_r",
    g = "ParadiseZTL_g",
    b = "ParadiseZTL_b",
    brightness = "ParadiseZTL_brightness",
    radius = "ParadiseZTL_radius",
    flashPeriod = "ParadiseZTL_flashPeriod",
    flashOnPct = "ParadiseZTL_flashOnPct",
    strobeSpeed = "ParadiseZTL_strobeSpeed",
    strobeOnPct = "ParadiseZTL_strobeOnPct",
    mysticSpeed = "ParadiseZTL_mysticSpeed",
    fireSeverity = "ParadiseZTL_fireSeverity",
    stormSeverity = "ParadiseZTL_stormSeverity",
}

TL.defaults = {
    enabled = false,
    visibility = TL.VIS_LOCAL,
    effect = TL.EFFECT_NONE,
    h = DEFAULT_H,
    s = DEFAULT_S,
    r = 1.0,
    g = 0.85,
    b = 0.50,
    brightness = DEFAULT_V,
    radius = 15,
    flashPeriod = 2.0,
    flashOnPct = 50,
    strobeSpeed = 0.5,
    strobeOnPct = 50,
    mysticSpeed = 0.5,
    fireSeverity = 1.0,
    stormSeverity = 1.0,
}

TL.stateByPlayer = {}
TL.windows = {}
TL.activeLights = {}

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function round(value, places)
    local mult = 10 ^ (places or 0)
    return math.floor(value * mult + 0.5) / mult
end

function TL.frac(value)
    return value - math.floor(value)
end

function TL.hashString(text)
    local total = 0
    text = text or ""
    for i = 1, #text do
        total = (total * 131 + string.byte(text, i)) % 1000003
    end
    return total
end

function TL.hash01(seed)
    local value = math.sin(seed * 12.9898 + 78.233) * 43758.5453
    return TL.frac(value)
end

function TL.smoothstep(t)
    return t * t * (3.0 - 2.0 * t)
end

function TL.sampleSmoothNoise(samplePos, seed)
    local index = math.floor(samplePos)
    local blend = TL.smoothstep(TL.frac(samplePos))
    local a = TL.hash01(index + seed)
    local b = TL.hash01(index + 1 + seed)
    return a + (b - a) * blend
end

function TL.ease01(t)
    t = clamp(t, 0.0, 1.0)
    return 0.5 - (0.5 * math.cos(t * math.pi))
end

function TL.playerIdentity(playerObj)
    if not playerObj then
        return "unknown"
    end
    local username = playerObj:getUsername()
    if username and username ~= "" then
        return username
    end
    return tostring(playerObj)
end

function TL.normalizeVisibility(visibility)
    if visibility == TL.VIS_ADMINS then return TL.VIS_ADMINS end
    if visibility == TL.VIS_EVERYONE or visibility == TL.VIS_SHARED then return TL.VIS_EVERYONE end
    return TL.VIS_LOCAL
end

function TL.normalizeEffect(effect)
    if effect == TL.EFFECT_FLASH then return TL.EFFECT_FLASH end
    if effect == TL.EFFECT_STROBE then return TL.EFFECT_STROBE end
    if effect == TL.EFFECT_FIRE then return TL.EFFECT_FIRE end
    if effect == TL.EFFECT_STORM then return TL.EFFECT_STORM end
    if effect == TL.EFFECT_MYSTIC then return TL.EFFECT_MYSTIC end
    if effect == TL.EFFECT_HORROR then return TL.EFFECT_HORROR end
    return TL.EFFECT_NONE
end

function TL.ensureColorState(state)
    if state.h == nil or state.s == nil then
        local fallback = ColorInfo.new(
            clamp(tonumber(state.r) or TL.defaults.r, 0, 1),
            clamp(tonumber(state.g) or TL.defaults.g, 0, 1),
            clamp(tonumber(state.b) or TL.defaults.b, 0, 1),
            1.0
        )
        local h, s, v = ISColorPickerHSB:toHSB(fallback:toColor())
        state.h = h
        state.s = s
        if state.brightness == nil then
            state.brightness = v
        end
    end

    state.h = clamp(tonumber(state.h) or TL.defaults.h, 0, 1)
    state.s = clamp(tonumber(state.s) or TL.defaults.s, 0, 1)
end

function TL.getColorRGB(state, brightnessOverride)
    TL.ensureColorState(state)
    local value = clamp(tonumber(brightnessOverride) or tonumber(state.brightness) or TL.defaults.brightness, 0, 1)
    local color = Color.HSBtoRGB(state.h, state.s, value)
    return color:getRedFloat(), color:getGreenFloat(), color:getBlueFloat()
end

function TL.getColorInfo(state, brightnessOverride)
    local r, g, b = TL.getColorRGB(state, brightnessOverride)
    return ColorInfo.new(r, g, b, 1.0)
end

function TL.applyBounded01(baseValue, minValue, maxValue, wave01, amount)
    wave01 = clamp(wave01 or 0.5, 0.0, 1.0)
    amount = math.max(0.0, amount or 0.0)

    local downAmount = math.min(baseValue - minValue, amount)
    local upAmount = math.min(maxValue - baseValue, amount)

    if downAmount <= 0.0001 and upAmount <= 0.0001 then
        return baseValue
    end

    if upAmount <= 0.0001 then
        return baseValue - ((1.0 - wave01) * downAmount)
    end

    if downAmount <= 0.0001 then
        return baseValue + (wave01 * upAmount)
    end

    if wave01 >= 0.5 then
        return baseValue + (((wave01 - 0.5) * 2.0) * upAmount)
    end

    return baseValue - (((0.5 - wave01) * 2.0) * downAmount)
end

function TL.getState(playerNum)
    local state = TL.stateByPlayer[playerNum]
    if not state then
        state = {}
        TL.stateByPlayer[playerNum] = state
    end

    for key, value in pairs(TL.defaults) do
        if state[key] == nil then
            state[key] = value
        end
    end

    state.visibility = TL.normalizeVisibility(state.visibility)
    state.enabled = state.enabled == true
    state.effect = TL.normalizeEffect(state.effect)

    TL.ensureColorState(state)

    state.brightness = clamp(tonumber(state.brightness) or TL.defaults.brightness, 0.00, 1.00)
    state.radius = clamp(math.floor((tonumber(state.radius) or TL.defaults.radius) + 0.5), 1, 30)

    state.flashPeriod = round(clamp(tonumber(state.flashPeriod) or TL.defaults.flashPeriod, 1.5, 30.0), 1)
    state.flashOnPct = clamp(math.floor((tonumber(state.flashOnPct) or TL.defaults.flashOnPct) + 0.5), 5, 95)

    state.strobeSpeed = round(clamp(tonumber(state.strobeSpeed) or TL.defaults.strobeSpeed, 0.1, 10.0), 1)
    state.strobeOnPct = clamp(math.floor((tonumber(state.strobeOnPct) or TL.defaults.strobeOnPct) + 0.5), 5, 95)

    state.mysticSpeed = round(clamp(tonumber(state.mysticSpeed) or TL.defaults.mysticSpeed, 0.1, 10.0), 1)
    state.fireSeverity = round(clamp(tonumber(state.fireSeverity) or TL.defaults.fireSeverity, 0.1, 10.0), 1)
    state.stormSeverity = round(clamp(tonumber(state.stormSeverity) or TL.defaults.stormSeverity, 0.1, 10.0), 1)

    return state
end

function TL.clearLight(key)
    local entry = TL.activeLights[key]
    if not entry then return end
    if entry.light and getCell() then
        getCell():removeLamppost(entry.light)
    end
    TL.activeLights[key] = nil
end

local PZContext = {
    trailingLightsCallback = nil,
    _contextMenuHook = nil,
    _origDebugDoMenu = nil,
}

function PZContext.canAddParadiseZContext(playerNum)
    -- The security bootstrap verifies access once at login. Context menus only
    -- read that cached result and never repeat an access-level lookup.
    return ParadiseZAccess and ParadiseZAccess.isAuthorized and ParadiseZAccess.isAuthorized()
end

function PZContext.findDebugMenu(context)
    if not context then return nil end

    local debugOption = context:getOptionFromName(getText("ContextMenu_Debug"))
    if not debugOption or not debugOption.subOption then
        return nil
    end

    return context:getSubMenu(debugOption.subOption)
end

function PZContext.openTrailingLights(playerNum)
    if PZContext.trailingLightsCallback then
        PZContext.trailingLightsCallback(playerNum)
    end
end

function PZContext.injectIntoContext(playerNum, context, worldobjects, test)
    if not PZContext.canAddParadiseZContext(playerNum) then
        return
    end

    local debugMenu = PZContext.findDebugMenu(context)
    if not debugMenu then
        return
    end

    local paradiseOption = debugMenu:getOptionFromName("ParadiseZ")
    local paradiseMenu

    if paradiseOption and paradiseOption.subOption then
        paradiseMenu = debugMenu:getSubMenu(paradiseOption.subOption)
    else
        paradiseOption = debugMenu:addOption("ParadiseZ")
        paradiseMenu = ISContextMenu:getNew(debugMenu)
        debugMenu:addSubMenu(paradiseOption, paradiseMenu)
    end

    if not paradiseMenu:getOptionFromName("Trailing Lights") then
        paradiseMenu:addOption("Trailing Lights", playerNum, PZContext.openTrailingLights)
    end
end

function PZContext.install(trailingLightsCallback)
    PZContext.trailingLightsCallback = trailingLightsCallback

    PZContext._contextMenuHook = function(playerNum, context, worldobjects, test)
        local ok, err = pcall(PZContext.injectIntoContext, playerNum, context, worldobjects, test)
        if not ok then
            print("[ParadiseZ] context hook error: " .. tostring(err))
        end
    end
    Events.OnFillWorldObjectContextMenu.Add(PZContext._contextMenuHook)

    if DebugContextMenu and DebugContextMenu.doDebugMenu then
        PZContext._origDebugDoMenu = DebugContextMenu.doDebugMenu
        DebugContextMenu.doDebugMenu = function(playerNum, context, worldobjects, test)
            local result = PZContext._origDebugDoMenu(playerNum, context, worldobjects, test)
            local ok, err = pcall(PZContext.injectIntoContext, playerNum, context, worldobjects, test)
            if not ok then
                print("[ParadiseZ] debug wrapper error: " .. tostring(err))
            end
            return result
        end
    end
end

function PZContext.teardown()
    if PZContext._contextMenuHook then
        pcall(function() Events.OnFillWorldObjectContextMenu.Remove(PZContext._contextMenuHook) end)
    end

    if PZContext._origDebugDoMenu and DebugContextMenu then
        DebugContextMenu.doDebugMenu = PZContext._origDebugDoMenu
    end

    PZContext.trailingLightsCallback = nil
    PZContext._contextMenuHook = nil
    PZContext._origDebugDoMenu = nil
end

function TL.teardown(preserveState)
    PZContext.teardown()

    if TL._tickHook then
        pcall(function() Events.OnTick.Remove(TL._tickHook) end)
    end

    for _, window in pairs(TL.windows or {}) do
        if window then
            if window.colorPicker then
                window.colorPicker:removeSelf()
                window.colorPicker = nil
            end
            window:removeFromUIManager()
        end
    end

    for key, _ in pairs(TL.activeLights or {}) do
        TL.clearLight(key)
    end

    TL.windows = {}
    TL.activeLights = {}
    TL._tickHook = nil
    TL._rendererInstalled = nil
    TL._installed = nil

    if not preserveState then
        TL.stateByPlayer = {}
    end
end

function TL.pushSharedState(playerNum)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end

    local state = TL.getState(playerNum)
    local modData = playerObj:getModData()
    local changed = false

    local function setValue(key, value)
        if modData[key] ~= value then
            modData[key] = value
            changed = true
        end
    end

    local r, g, b = TL.getColorRGB(state, state.brightness)

    setValue(TL.MD.enabled, state.enabled and state.visibility ~= TL.VIS_LOCAL)
    setValue(TL.MD.visibility, state.visibility)
    setValue(TL.MD.effect, state.effect)
    setValue(TL.MD.h, state.h)
    setValue(TL.MD.s, state.s)
    setValue(TL.MD.r, r)
    setValue(TL.MD.g, g)
    setValue(TL.MD.b, b)
    setValue(TL.MD.brightness, state.brightness)
    setValue(TL.MD.radius, state.radius)

    setValue(TL.MD.flashPeriod, state.flashPeriod)
    setValue(TL.MD.flashOnPct, state.flashOnPct)
    setValue(TL.MD.strobeSpeed, state.strobeSpeed)
    setValue(TL.MD.strobeOnPct, state.strobeOnPct)
    setValue(TL.MD.mysticSpeed, state.mysticSpeed)
    setValue(TL.MD.fireSeverity, state.fireSeverity)
    setValue(TL.MD.stormSeverity, state.stormSeverity)

    if changed and playerObj.transmitModData then
        playerObj:transmitModData()
    end
end

function TL.readSharedState(playerObj)
    if not playerObj then
        return nil
    end

    local modData = playerObj:getModData()
    if modData[TL.MD.enabled] ~= true then
        return nil
    end

    local shared = {
        enabled = true,
        visibility = TL.normalizeVisibility(modData[TL.MD.visibility] or TL.VIS_SHARED),
        effect = TL.normalizeEffect(modData[TL.MD.effect]),
		h = tonumber(modData[TL.MD.h]),
        s = tonumber(modData[TL.MD.s]),
        r = tonumber(modData[TL.MD.r]),
        g = tonumber(modData[TL.MD.g]),
        b = tonumber(modData[TL.MD.b]),
        brightness = clamp(tonumber(modData[TL.MD.brightness]) or TL.defaults.brightness, 0.00, 1.00),
        radius = clamp(math.floor((tonumber(modData[TL.MD.radius]) or TL.defaults.radius) + 0.5), 1, 30),
        flashPeriod = round(clamp(tonumber(modData[TL.MD.flashPeriod]) or TL.defaults.flashPeriod, 1.5, 30.0), 1),
        flashOnPct = clamp(math.floor((tonumber(modData[TL.MD.flashOnPct]) or TL.defaults.flashOnPct) + 0.5), 5, 95),
        strobeSpeed = round(clamp(tonumber(modData[TL.MD.strobeSpeed]) or TL.defaults.strobeSpeed, 0.1, 10.0), 1),
        strobeOnPct = clamp(math.floor((tonumber(modData[TL.MD.strobeOnPct]) or TL.defaults.strobeOnPct) + 0.5), 5, 95),
        mysticSpeed = round(clamp(tonumber(modData[TL.MD.mysticSpeed]) or TL.defaults.mysticSpeed, 0.1, 10.0), 1),
        fireSeverity = round(clamp(tonumber(modData[TL.MD.fireSeverity]) or TL.defaults.fireSeverity, 0.1, 10.0), 1),
        stormSeverity = round(clamp(tonumber(modData[TL.MD.stormSeverity]) or TL.defaults.stormSeverity, 0.1, 10.0), 1),
    }

    TL.ensureColorState(shared)
    return shared
end

function TL.canRenderSharedState(sharedState)
    if sharedState.visibility == TL.VIS_EVERYONE then
        return true
    end

    return sharedState.visibility == TL.VIS_ADMINS
        and ParadiseZAccess
        and ParadiseZAccess.isAuthorized
        and ParadiseZAccess.isAuthorized()
end

function TL.onLocalStateChanged(playerNum)
    TL.pushSharedState(playerNum)
    local window = TL.windows[playerNum]
    if window then
        window:syncFromState()
    end
end

function TL.pulseShape(timePos, startTime, duration)
    if duration <= 0 then
        return 0.0
    end
    if timePos < startTime or timePos > (startTime + duration) then
        return 0.0
    end
    local p = (timePos - startTime) / duration
    return math.sin(p * math.pi)
end

function TL.profileFlash(baseBrightness, baseRadius, settings, now, seed, offset)
    local period = clamp(settings.flashPeriod or TL.defaults.flashPeriod, 1.5, 30.0)
    local onFrac = clamp((settings.flashOnPct or TL.defaults.flashOnPct) / 100.0, 0.05, 0.95)

    local cycle = TL.frac((now + offset) / period)
    local cycleTime = cycle * period
    local onTime = period * onFrac
    local offTime = math.max(period - onTime, 0.001)

    if cycleTime < onTime then
        return {
            brightness = baseBrightness,
            radius = baseRadius,
        }
    end

    local offPhase = cycleTime - onTime
    local fadeEach = math.min(0.75, offTime * 0.5)
    local intensity = 0.0

    if offTime <= (fadeEach * 2.0) + 0.0001 then
        local half = offTime * 0.5
        if offPhase < half then
            intensity = 1.0 - TL.ease01(offPhase / half)
        else
            intensity = TL.ease01((offPhase - half) / half)
        end
    else
        if offPhase < fadeEach then
            intensity = 1.0 - TL.ease01(offPhase / fadeEach)
        elseif offPhase < (offTime - fadeEach) then
            intensity = 0.0
        else
            intensity = TL.ease01((offPhase - (offTime - fadeEach)) / fadeEach)
        end
    end

    intensity = clamp(intensity, 0.0, 1.0)

    return {
        brightness = baseBrightness * intensity,
        radius = clamp(baseRadius * (0.55 + (0.45 * intensity)), 1, 30),
    }
end

function TL.profileStrobe(baseBrightness, baseRadius, settings, now, seed, offset)
    local speed = clamp(settings.strobeSpeed or TL.defaults.strobeSpeed, 0.1, 10.0)
    local period = 1.0 / speed
    local onFrac = clamp((settings.strobeOnPct or TL.defaults.strobeOnPct) / 100.0, 0.05, 0.95)
    local cycle = TL.frac((now + offset) / period)

    if cycle < onFrac then
        return {
            brightness = baseBrightness,
            radius = baseRadius,
        }
    end

    return {
        brightness = 0.0,
        radius = clamp(baseRadius * 0.60, 1, 30),
    }
end

function TL.profileFire(baseBrightness, baseRadius, settings, now, seed, offset)
    local severity = clamp(settings.fireSeverity or TL.defaults.fireSeverity, 0.1, 10.0)
    local anchoredSeverity = math.min(severity, 3.0)
    local extraSeverity = math.max(0.0, severity - 3.0)
    local t = now + offset

    local low = TL.sampleSmoothNoise(t / 1.40, seed * 0.091 + 7.0)
    local med = TL.sampleSmoothNoise(t / 0.70, seed * 0.173 + 19.0)
    local high = TL.sampleSmoothNoise(t / 0.35, seed * 0.287 + 31.0)

    local wave = ((low * 0.52) + (med * 0.33) + (high * 0.15) - 0.5) * 2.0
    local flare = math.max(0.0, med - 0.72) / 0.28

    local brightnessDepth = clamp(0.18 + (anchoredSeverity * 0.08) + (extraSeverity * 0.02), 0.18, 0.56)
    local radiusDepth = clamp(0.10 + (anchoredSeverity * 0.05) + (extraSeverity * 0.012), 0.10, 0.34)

    local brightnessWave = clamp(0.56 + (wave * 0.22) + (flare * 0.18), 0.0, 1.0)
    local radiusWave = clamp(0.52 + (wave * 0.18) + (flare * 0.22), 0.0, 1.0)

    local brightnessFactor = (1.0 - brightnessDepth) + (brightnessDepth * brightnessWave)
    local radiusFactor = (1.0 - radiusDepth) + (radiusDepth * radiusWave)

    return {
        brightness = baseBrightness * brightnessFactor,
        radius = clamp(baseRadius * radiusFactor, 1, 30),
    }
end

function TL.profileStorm(baseBrightness, baseRadius, settings, now, seed, offset)
    local severity = clamp(settings.stormSeverity or TL.defaults.stormSeverity, 0.1, 10.0)
    local anchoredSeverity = math.min(severity, 3.0)
    local extraSeverity = math.max(0.0, severity - 3.0)
    local cyclePeriod = 10.0
    local cycleFloat = (now + offset) / cyclePeriod
    local cycleIndex = math.floor(cycleFloat)
    local cyclePos = TL.frac(cycleFloat) * cyclePeriod

    local ambient = 0.08 + (TL.sampleSmoothNoise((now + offset) / 2.8, seed * 0.121 + 5.0) * 0.08)
    local burst = 0.0
    local burstScale = clamp(0.30 + (anchoredSeverity * 0.18) + (extraSeverity * 0.05), 0.30, 1.19)

    for i = 1, 4 do
        local start = 0.35 + (TL.hash01(seed + cycleIndex * 17 + i * 13) * 8.40)
        local duration = 0.10 + (TL.hash01(seed + cycleIndex * 23 + i * 7) * 0.22)
        local amplitude = 0.35 + (TL.hash01(seed + cycleIndex * 29 + i * 11) * 0.65)

        local mainPulse = TL.pulseShape(cyclePos, start, duration) * amplitude
        local echoDelay = 0.04 + (TL.hash01(seed + cycleIndex * 31 + i * 5) * 0.16)
        local echoPulse = TL.pulseShape(cyclePos, start + echoDelay, duration * 0.55) * amplitude * 0.55

        burst = math.max(burst, mainPulse + echoPulse)
    end

    local factor = clamp(ambient + (burst * burstScale), 0.0, 1.0)

    return {
        brightness = baseBrightness * factor,
        radius = 30,
    }
end

function TL.profileMystic(baseBrightness, baseRadius, settings, now, seed, offset)
    local speed = clamp(settings.mysticSpeed or TL.defaults.mysticSpeed, 0.1, 10.0)
    local period = 4.0 / speed
    local phase = ((now + offset) / period) * TWO_PI

    local wave = (math.sin(phase) * 0.80) + (math.sin((phase * 2.0) + seed * 0.01) * 0.20)
    wave = clamp(wave, -1.0, 1.0)
    local wave01 = 0.5 + (wave * 0.5)

    return {
        brightness = TL.applyBounded01(baseBrightness, 0.0, 1.0, wave01, baseBrightness * 0.30),
        radius = TL.applyBounded01(baseRadius, 1.0, 30.0, wave01, baseRadius * 0.30),
    }
end

function TL.profileHorror(baseBrightness, baseRadius, settings, now, seed, offset)
    local cyclePeriod = 10.0
    local cycleFloat = (now + offset) / cyclePeriod
    local cycleIndex = math.floor(cycleFloat)
    local cyclePos = TL.frac(cycleFloat) * cyclePeriod

    local bedNoise = TL.sampleSmoothNoise((now + offset) / 1.9, seed * 0.083 + 9.0)
    local bedFactor = 0.18 + (bedNoise * 0.12)
    local ambientBrightness = baseBrightness * bedFactor
    local ambientRadius = clamp(baseRadius * (0.52 + (bedFactor * 0.36)), 1, 30)

    for i = 1, 4 do
        local start = 0.45 + (TL.hash01(seed + cycleIndex * 17 + i * 29) * 8.40)
        local duration = 0.50 + (TL.hash01(seed + cycleIndex * 23 + i * 11) * 1.15)

        if cyclePos >= start and cyclePos < (start + duration) then
            local localPos = cyclePos - start
            local slice = 0.06 + (TL.hash01(seed + cycleIndex * 31 + i * 13) * 0.16)
            local sliceIndex = math.floor(localPos / slice)
            local pick = TL.hash01(seed + cycleIndex * 37 + i * 19 + sliceIndex * 7)

            local stateMul
            if localPos < 0.07 then
                stateMul = 1.0
            elseif pick < 0.30 then
                stateMul = 0.0
            elseif pick < 0.62 then
                stateMul = 0.45
            else
                stateMul = 1.0
            end

            local radiusMul
            if stateMul <= 0.001 then
                radiusMul = 0.28
            elseif stateMul < 0.60 then
                radiusMul = 0.55
            else
                radiusMul = 1.0
            end

            return {
                brightness = baseBrightness * stateMul,
                radius = clamp(baseRadius * radiusMul, 1, 30),
            }
        end
    end

    return {
        brightness = ambientBrightness,
        radius = ambientRadius,
    }
end

function TL.effectProfile(playerObj, settings)
    local now = getTimestampMs() / 1000.0
    local seed = TL.hashString(TL.playerIdentity(playerObj))
    local offset = (seed % 1000) * 0.001

    local baseBrightness = clamp(settings.brightness or TL.defaults.brightness, 0.0, 1.0)
    local baseRadius = clamp(math.floor((settings.radius or TL.defaults.radius) + 0.5), 1, 30)
    local effect = TL.normalizeEffect(settings.effect)

    if effect == TL.EFFECT_FLASH then
        return TL.profileFlash(baseBrightness, baseRadius, settings, now, seed, offset)
    end
    if effect == TL.EFFECT_STROBE then
        return TL.profileStrobe(baseBrightness, baseRadius, settings, now, seed, offset)
    end
    if effect == TL.EFFECT_FIRE then
        return TL.profileFire(baseBrightness, baseRadius, settings, now, seed, offset)
    end
    if effect == TL.EFFECT_STORM then
        return TL.profileStorm(baseBrightness, baseRadius, settings, now, seed, offset)
    end
    if effect == TL.EFFECT_MYSTIC then
        return TL.profileMystic(baseBrightness, baseRadius, settings, now, seed, offset)
    end
    if effect == TL.EFFECT_HORROR then
        return TL.profileHorror(baseBrightness, baseRadius, settings, now, seed, offset)
    end

    return {
        brightness = baseBrightness,
        radius = baseRadius,
    }
end

function TL.renderLight(key, playerObj, settings)
    if not playerObj or playerObj:isDead() or not playerObj:getCurrentSquare() then
        TL.clearLight(key)
        return
    end

    local cell = getCell()
    if not cell then
        TL.clearLight(key)
        return
    end

    local effect = TL.effectProfile(playerObj, settings)

    local x = math.floor(playerObj:getX())
    local y = math.floor(playerObj:getY())
    local z = math.floor(playerObj:getZ())
    local radius = clamp(math.floor((effect.radius or settings.radius or TL.defaults.radius) + 0.5), 1, 30)
    local brightnessValue = clamp(effect.brightness or settings.brightness or TL.defaults.brightness, 0.0, 1.0)

    if brightnessValue <= 0.001 then
        TL.clearLight(key)
        return
    end

    local r, g, b = TL.getColorRGB(settings, brightnessValue)

    local entry = TL.activeLights[key]
    local needsRefresh = not entry
        or entry.x ~= x
        or entry.y ~= y
        or entry.z ~= z
        or entry.radius ~= radius
        or math.abs(entry.r - r) > LIGHT_EPSILON
        or math.abs(entry.g - g) > LIGHT_EPSILON
        or math.abs(entry.b - b) > LIGHT_EPSILON

    if not needsRefresh then
        return
    end

    TL.clearLight(key)

    local light = cell:addLamppost(x, y, z, r, g, b, radius)
    if not light then
        return
    end

    TL.activeLights[key] = {
        light = light,
        x = x,
        y = y,
        z = z,
        r = r,
        g = g,
        b = b,
        radius = radius,
    }
end

function TL.forEachNetworkPlayer(callback)
    local seen = {}

    local onlinePlayers = getOnlinePlayers and getOnlinePlayers() or nil
    if onlinePlayers then
        for i = 0, onlinePlayers:size() - 1 do
            local playerObj = onlinePlayers:get(i)
            if playerObj then
                local identity = TL.playerIdentity(playerObj)
                if not seen[identity] then
                    seen[identity] = true
                    callback(playerObj)
                end
            end
        end
    end

    for playerNum = 0, getNumActivePlayers() - 1 do
        local playerObj = getSpecificPlayer(playerNum)
        if playerObj then
            local identity = TL.playerIdentity(playerObj)
            if not seen[identity] then
                seen[identity] = true
                callback(playerObj)
            end
        end
    end
end

function TL.onTick()
    local desiredKeys = {}

    for playerNum = 0, getNumActivePlayers() - 1 do
        local playerObj = getSpecificPlayer(playerNum)
        if playerObj then
            local state = TL.getState(playerNum)
            if state.enabled and state.visibility == TL.VIS_LOCAL then
                local key = "local:" .. TL.playerIdentity(playerObj)
                desiredKeys[key] = true
                TL.renderLight(key, playerObj, state)
            end
        end
    end

    TL.forEachNetworkPlayer(function(playerObj)
        local sharedState = TL.readSharedState(playerObj)
        if sharedState and sharedState.enabled and TL.canRenderSharedState(sharedState) then
            local key = "shared:" .. TL.playerIdentity(playerObj)
            desiredKeys[key] = true
            TL.renderLight(key, playerObj, sharedState)
        end
    end)

    local stale = {}
    for key, _ in pairs(TL.activeLights) do
        if not desiredKeys[key] then
            stale[#stale + 1] = key
        end
    end

    for i = 1, #stale do
        TL.clearLight(stale[i])
    end
end

TLNumberBox = ISPanel:derive("TLNumberBox")

function TLNumberBox:initialise()
    ISPanel.initialise(self)
end

function TLNumberBox:createChildren()
    local btnW = self.buttonWidth or 15

    self.leftButton = ISButton:new(0, 0, btnW, self.height, "", self, nil)
    self.leftButton.internal = "LESS"
    self.leftButton:initialise()
    self.leftButton:setImage(getTexture("media/ui/ArrowLeft.png"))
    self.leftButton.borderColor.a = 0.0
    self.leftButton.backgroundColor.a = 0.0
    self.leftButton.backgroundColorMouseOver.a = 0.25
    self.leftButton:setRepeatWhilePressed(TLNumberBox.onArrow)
    self:addChild(self.leftButton)

    self.entry = ISTextEntryBox:new("", btnW + 1, 0, self.width - btnW * 2 - 2, self.height)
    self.entry:initialise()
    self.entry:instantiate()
    self.entry:setMaxTextLength(self.maxTextLength or 8)
    self:addChild(self.entry)

    self.rightButton = ISButton:new(self.width - btnW, 0, btnW, self.height, "", self, nil)
    self.rightButton.internal = "MORE"
    self.rightButton:initialise()
    self.rightButton:setImage(getTexture("media/ui/ArrowRight.png"))
    self.rightButton.borderColor.a = 0.0
    self.rightButton.backgroundColor.a = 0.0
    self.rightButton.backgroundColorMouseOver.a = 0.25
    self.rightButton:setRepeatWhilePressed(TLNumberBox.onArrow)
    self:addChild(self.rightButton)

    local parent = self
    self.entry.onCommandEntered = function(entry)
        parent:onEntryCommitted(true)
	end
    self.entry.onLostFocus = function(entry)
        parent:onEntryCommitted(false)
    end

    self:setValue(self.value or self.minValue or 0, true)
end

function TLNumberBox:normalize(value)
    value = tonumber(value)
    if value == nil then
        value = self.value or self.minValue or 0
    end

    value = clamp(value, self.minValue, self.maxValue)

    if self.decimals == 0 then
        value = math.floor(value + 0.5)
    else
        value = round(value, self.decimals)
    end

    return value
end

function TLNumberBox:formatValue(value)
    if self.decimals == 0 then
        return tostring(math.floor(value + 0.5))
    end
    return string.format("%." .. tostring(self.decimals) .. "f", value)
end

function TLNumberBox:setValue(value, suppressCallback)
    local normalized = self:normalize(value)
    self.value = normalized

    if self.entry then
        self.entry:setValid(true)
        self.entry:setText(self:formatValue(normalized))
    end

    if not suppressCallback and self.onValueChanged then
        self.onValueChanged(self.target, normalized, self)
    end
end

function TLNumberBox:getValue()
    return self.value
end

function TLNumberBox:changeBy(delta)
    self:setValue((self.value or self.minValue or 0) + delta)
end

function TLNumberBox:onArrow(button)
    if button.internal == "LESS" then
        self:changeBy(-self.stepValue)
    elseif button.internal == "MORE" then
        self:changeBy(self.stepValue)
    end
end

function TLNumberBox:onEntryCommitted(unfocusAfter)
    local text = self.entry:getInternalText()
    local value = tonumber(text)

    if value == nil then
        self.entry:setValid(false)
        self.entry:setText(self:formatValue(self.value or self.minValue or 0))
        self.entry:setValid(true)
    else
        self:setValue(value)
    end

    if unfocusAfter then
        self.entry:unfocus()
    end
end

function TLNumberBox:new(x, y, width, height, target, onValueChanged, minValue, maxValue, stepValue, decimals, maxTextLength, buttonWidth)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.background = false
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.0 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.0 }

    o.target = target
    o.onValueChanged = onValueChanged
    o.minValue = minValue or 0
    o.maxValue = maxValue or 100
    o.stepValue = stepValue or 1
    o.decimals = decimals or 0
    o.maxTextLength = maxTextLength or 8
    o.buttonWidth = buttonWidth or 15
    o.value = o.minValue

    return o
end

ParadiseZTrailingLightsWindow = ISCollapsableWindow:derive("ParadiseZTrailingLightsWindow")

function ParadiseZTrailingLightsWindow:initialise()
    ISCollapsableWindow.initialise(self)
end

function ParadiseZTrailingLightsWindow.onResizeWindow(target, newW, newH)
    local minW = target.minimumWidth or target.minWidth or 0
    local minH = target.minimumHeight or target.minHeight or 0
    target:setWidth(math.max(newW, minW))
    target:setHeight(math.max(newH, minH))
    target:layoutChrome()
end

function ParadiseZTrailingLightsWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    if self.resizeWidget then
        self.resizeWidget.resizeFunction = ParadiseZTrailingLightsWindow.onResizeWindow
    end
    if self.resizeWidget2 then
        self.resizeWidget2.resizeFunction = ParadiseZTrailingLightsWindow.onResizeWindow
    end

    self.colorLabel = ISLabel:new(0, 0, FONT_HGT_SMALL, "Color", 1, 1, 1, 1, UIFont.Small, false)
    self.colorLabel:initialise()
    self.colorLabel:instantiate()
    self:addChild(self.colorLabel)

    self.previewButton = ISButton:new(0, 0, BUTTON_HGT * 2, BUTTON_HGT, "", self, ParadiseZTrailingLightsWindow.onPickColor)
    self.previewButton:initialise()
    self.previewButton:instantiate()
    self.previewButton.borderColor = { r = 1, g = 1, b = 1, a = 0.4 }
    self:addChild(self.previewButton)

    self.pickButton = ISButton:new(0, 0, 46, BUTTON_HGT, "Pick", self, ParadiseZTrailingLightsWindow.onPickColor)
    self.pickButton:initialise()
    self.pickButton:instantiate()
    self:addChild(self.pickButton)

    self.brightnessLabel = ISLabel:new(0, 0, FONT_HGT_SMALL, "Bright", 1, 1, 1, 1, UIFont.Small, false)
    self.brightnessLabel:initialise()
    self.brightnessLabel:instantiate()
    self:addChild(self.brightnessLabel)

    self.brightnessValue = ISLabel:new(0, 0, FONT_HGT_SMALL, "1.00", 1, 1, 1, 1, UIFont.Small, false)
    self.brightnessValue:initialise()
    self.brightnessValue:instantiate()
    self:addChild(self.brightnessValue)

    self.brightnessSlider = ISSliderPanel:new(0, 0, 120, BUTTON_HGT, self, ParadiseZTrailingLightsWindow.onBrightnessChanged)
    self.brightnessSlider:initialise()
    self.brightnessSlider:instantiate()
    self.brightnessSlider:setValues(0.00, 1.00, 0.01, 0.10, true)
    self:addChild(self.brightnessSlider)

    self.radiusLabel = ISLabel:new(0, 0, FONT_HGT_SMALL, "Radius", 1, 1, 1, 1, UIFont.Small, false)
    self.radiusLabel:initialise()
    self.radiusLabel:instantiate()
    self:addChild(self.radiusLabel)

    self.radiusValue = ISLabel:new(0, 0, FONT_HGT_SMALL, "15", 1, 1, 1, 1, UIFont.Small, false)
    self.radiusValue:initialise()
    self.radiusValue:instantiate()
    self:addChild(self.radiusValue)

    self.radiusSlider = ISSliderPanel:new(0, 0, 120, BUTTON_HGT, self, ParadiseZTrailingLightsWindow.onRadiusChanged)
    self.radiusSlider:initialise()
    self.radiusSlider:instantiate()
    self.radiusSlider:setValues(1, 30, 1, 5, true)
    self:addChild(self.radiusSlider)

    self.visibilityLabel = ISLabel:new(0, 0, FONT_HGT_SMALL, "Visible", 1, 1, 1, 1, UIFont.Small, false)
    self.visibilityLabel:initialise()
    self.visibilityLabel:instantiate()
    self:addChild(self.visibilityLabel)

    self.visibilityCombo = ISComboBox:new(0, 0, 82, BUTTON_HGT, self, ParadiseZTrailingLightsWindow.onVisibilityChanged)
    self.visibilityCombo:initialise()
    self.visibilityCombo:instantiate()
    self.visibilityCombo:addOptionWithData("Only Me", TL.VIS_LOCAL)
    self.visibilityCombo:addOptionWithData("Admins", TL.VIS_ADMINS)
    self.visibilityCombo:addOptionWithData("Everyone", TL.VIS_EVERYONE)
    self:addChild(self.visibilityCombo)

    self.effectsLabel = ISLabel:new(0, 0, FONT_HGT_SMALL, "Effects", 1, 1, 1, 1, UIFont.Small, false)
    self.effectsLabel:initialise()
    self.effectsLabel:instantiate()
    self:addChild(self.effectsLabel)

    self.flashTick = ISTickBox:new(0, 0, 84, BUTTON_HGT, "", self, ParadiseZTrailingLightsWindow.onEffectChanged, TL.EFFECT_FLASH)
    self.flashTick:initialise()
    self.flashTick:instantiate()
    self.flashTick:addOption("Flash")
    self.flashTick:setWidthToFit()
    self:addChild(self.flashTick)

    self.flashSecLabel = ISLabel:new(0, 0, FONT_HGT_SMALL, "Sec:", 1, 1, 1, 1, UIFont.Small, false)
    self.flashSecLabel:initialise()
    self.flashSecLabel:instantiate()
    self:addChild(self.flashSecLabel)

    self.flashPeriodBox = TLNumberBox:new(0, 0, 56, BUTTON_HGT, self, ParadiseZTrailingLightsWindow.onFlashPeriodChanged, 1.5, 30.0, 0.1, 1, 4, 10)
    self.flashPeriodBox:initialise()
    self.flashPeriodBox:instantiate()
    self:addChild(self.flashPeriodBox)

    self.flashPctLabel = ISLabel:new(0, 0, FONT_HGT_SMALL, "On%:", 1, 1, 1, 1, UIFont.Small, false)
    self.flashPctLabel:initialise()
    self.flashPctLabel:instantiate()
    self:addChild(self.flashPctLabel)

    self.flashOnPctBox = TLNumberBox:new(0, 0, 46, BUTTON_HGT, self, ParadiseZTrailingLightsWindow.onFlashOnPctChanged, 5, 95, 1, 0, 3, 10)
    self.flashOnPctBox:initialise()
    self.flashOnPctBox:instantiate()
    self:addChild(self.flashOnPctBox)

    self.strobeTick = ISTickBox:new(0, 0, 84, BUTTON_HGT, "", self, ParadiseZTrailingLightsWindow.onEffectChanged, TL.EFFECT_STROBE)
    self.strobeTick:initialise()
    self.strobeTick:instantiate()
    self.strobeTick:addOption("Strobe")
    self.strobeTick:setWidthToFit()
    self:addChild(self.strobeTick)

    self.strobeSpeedLabel = ISLabel:new(0, 0, FONT_HGT_SMALL, "Speed:", 1, 1, 1, 1, UIFont.Small, false)
    self.strobeSpeedLabel:initialise()
    self.strobeSpeedLabel:instantiate()
    self:addChild(self.strobeSpeedLabel)

    self.strobeSpeedBox = TLNumberBox:new(0, 0, 56, BUTTON_HGT, self, ParadiseZTrailingLightsWindow.onStrobeSpeedChanged, 0.1, 10.0, 0.1, 1, 4, 10)
    self.strobeSpeedBox:initialise()
    self.strobeSpeedBox:instantiate()
    self:addChild(self.strobeSpeedBox)

    self.strobePctLabel = ISLabel:new(0, 0, FONT_HGT_SMALL, "On%:", 1, 1, 1, 1, UIFont.Small, false)
    self.strobePctLabel:initialise()
    self.strobePctLabel:instantiate()
    self:addChild(self.strobePctLabel)

    self.strobeOnPctBox = TLNumberBox:new(0, 0, 46, BUTTON_HGT, self, ParadiseZTrailingLightsWindow.onStrobeOnPctChanged, 5, 95, 1, 0, 3, 10)
    self.strobeOnPctBox:initialise()
    self.strobeOnPctBox:instantiate()
    self:addChild(self.strobeOnPctBox)

    self.fireTick = ISTickBox:new(0, 0, 84, BUTTON_HGT, "", self, ParadiseZTrailingLightsWindow.onEffectChanged, TL.EFFECT_FIRE)
    self.fireTick:initialise()
    self.fireTick:instantiate()
    self.fireTick:addOption("Fire")
    self.fireTick:setWidthToFit()
    self:addChild(self.fireTick)

    self.fireSeverityLabel = ISLabel:new(0, 0, FONT_HGT_SMALL, "Severity:", 1, 1, 1, 1, UIFont.Small, false)
    self.fireSeverityLabel:initialise()
    self.fireSeverityLabel:instantiate()
    self:addChild(self.fireSeverityLabel)

    self.fireSeverityBox = TLNumberBox:new(0, 0, 56, BUTTON_HGT, self, ParadiseZTrailingLightsWindow.onFireSeverityChanged, 0.1, 10.0, 0.1, 1, 4, 10)
    self.fireSeverityBox:initialise()
    self.fireSeverityBox:instantiate()
    self:addChild(self.fireSeverityBox)

    self.stormTick = ISTickBox:new(0, 0, 84, BUTTON_HGT, "", self, ParadiseZTrailingLightsWindow.onEffectChanged, TL.EFFECT_STORM)
    self.stormTick:initialise()
    self.stormTick:instantiate()
    self.stormTick:addOption("Storm")
    self.stormTick:setWidthToFit()
    self:addChild(self.stormTick)

    self.stormSeverityLabel = ISLabel:new(0, 0, FONT_HGT_SMALL, "Severity:", 1, 1, 1, 1, UIFont.Small, false)
    self.stormSeverityLabel:initialise()
    self.stormSeverityLabel:instantiate()
    self:addChild(self.stormSeverityLabel)

    self.stormSeverityBox = TLNumberBox:new(0, 0, 56, BUTTON_HGT, self, ParadiseZTrailingLightsWindow.onStormSeverityChanged, 0.1, 10.0, 0.1, 1, 4, 10)
    self.stormSeverityBox:initialise()
    self.stormSeverityBox:instantiate()
    self:addChild(self.stormSeverityBox)

    self.mysticTick = ISTickBox:new(0, 0, 84, BUTTON_HGT, "", self, ParadiseZTrailingLightsWindow.onEffectChanged, TL.EFFECT_MYSTIC)
    self.mysticTick:initialise()
    self.mysticTick:instantiate()
    self.mysticTick:addOption("Mystic")
    self.mysticTick:setWidthToFit()
    self:addChild(self.mysticTick)

    self.mysticSpeedLabel = ISLabel:new(0, 0, FONT_HGT_SMALL, "Speed:", 1, 1, 1, 1, UIFont.Small, false)
    self.mysticSpeedLabel:initialise()
    self.mysticSpeedLabel:instantiate()
    self:addChild(self.mysticSpeedLabel)

    self.mysticSpeedBox = TLNumberBox:new(0, 0, 56, BUTTON_HGT, self, ParadiseZTrailingLightsWindow.onMysticSpeedChanged, 0.1, 10.0, 0.1, 1, 4, 10)
    self.mysticSpeedBox:initialise()
    self.mysticSpeedBox:instantiate()
    self:addChild(self.mysticSpeedBox)

    self.horrorTick = ISTickBox:new(0, 0, 84, BUTTON_HGT, "", self, ParadiseZTrailingLightsWindow.onEffectChanged, TL.EFFECT_HORROR)
    self.horrorTick:initialise()
    self.horrorTick:instantiate()
    self.horrorTick:addOption("Horror")
    self.horrorTick:setWidthToFit()
    self:addChild(self.horrorTick)

    self.toggleButton = ISButton:new(0, 0, 120, BUTTON_HGT, "Turn On", self, ParadiseZTrailingLightsWindow.onToggleLight)
    self.toggleButton:initialise()
    self.toggleButton:instantiate()
    self:addChild(self.toggleButton)

    self:syncFromState()
    self:layoutChildren()
    self:layoutChrome()
end

function ParadiseZTrailingLightsWindow:layoutChrome()
    local buttonHeight = self:titleBarHeight() - 2
    local rightX = self.width - 1 - buttonHeight

    if self.pinButton then
        self.pinButton:setX(rightX)
        self.pinButton:setY(1)
    end
    if self.collapseButton then
        self.collapseButton:setX(rightX)
        self.collapseButton:setY(1)
    end

    local rh = self:resizeWidgetHeight()
    if self.resizeWidget then
        self.resizeWidget:setX(self.width - rh)
        self.resizeWidget:setY(self.height - rh)
    end
    if self.resizeWidget2 then
        self.resizeWidget2:setY(self.height - rh)
        self.resizeWidget2:setWidth(self.width - rh)
    end
end

function ParadiseZTrailingLightsWindow:layoutChildren()
    local pad = UI_BORDER_SPACING
    local labelW = 58
    local controlX = pad + labelW
    local sliderW = self.fixedSliderWidth or 150
    local valueX = controlX + sliderW + 6
    local y = self:titleBarHeight() + pad

    self.colorLabel:setX(pad)
    self.colorLabel:setY(y + 2)

    self.previewButton:setX(controlX)
    self.previewButton:setY(y)
    self.previewButton:setWidth(BUTTON_HGT * 2)
    self.previewButton:setHeight(BUTTON_HGT)

    self.pickButton:setX(self.previewButton:getRight() + 6)
    self.pickButton:setY(y)
    self.pickButton:setWidth(46)
    self.pickButton:setHeight(BUTTON_HGT)

    y = y + BUTTON_HGT + pad

    self.brightnessLabel:setX(pad)
    self.brightnessLabel:setY(y + 2)
    self.brightnessSlider:setX(controlX)
    self.brightnessSlider:setY(y)
    self.brightnessSlider:setWidth(sliderW)
    self.brightnessValue:setX(valueX)
    self.brightnessValue:setY(y + 2)

    y = y + BUTTON_HGT + pad

    self.radiusLabel:setX(pad)
    self.radiusLabel:setY(y + 2)
    self.radiusSlider:setX(controlX)
    self.radiusSlider:setY(y)
    self.radiusSlider:setWidth(sliderW)
    self.radiusValue:setX(valueX)
    self.radiusValue:setY(y + 2)

    y = y + BUTTON_HGT + pad

    self.visibilityLabel:setX(pad)
    self.visibilityLabel:setY(y + 2)
    self.visibilityCombo:setX(controlX)
    self.visibilityCombo:setY(y)
    self.visibilityCombo:setWidth(82)

    y = y + BUTTON_HGT + pad

    self.effectsLabel:setX(pad)
    self.effectsLabel:setY(y + 2)

    local fxX = pad
    local rowPad = 6
    local tickW = math.max(
        self.flashTick:getWidth(),
        self.strobeTick:getWidth(),
        self.fireTick:getWidth(),
        self.stormTick:getWidth(),
        self.mysticTick:getWidth(),
        self.horrorTick:getWidth()
    )

    y = y + FONT_HGT_SMALL + 6

    local inlineX = fxX + tickW + 4

    self.flashTick:setX(fxX)
    self.flashTick:setY(y)
    self.flashSecLabel:setX(inlineX)
    self.flashSecLabel:setY(y + 2)
    self.flashPeriodBox:setX(inlineX + 24)
    self.flashPeriodBox:setY(y)
    self.flashPctLabel:setX(self.flashPeriodBox:getX() + self.flashPeriodBox:getWidth() + 4)
    self.flashPctLabel:setY(y + 2)
    self.flashOnPctBox:setX(self.flashPctLabel:getX() + 28)
    self.flashOnPctBox:setY(y)

    y = y + BUTTON_HGT + rowPad

    self.strobeTick:setX(fxX)
    self.strobeTick:setY(y)
    self.strobeSpeedLabel:setX(inlineX)
    self.strobeSpeedLabel:setY(y + 2)
    self.strobeSpeedBox:setX(inlineX + 36)
    self.strobeSpeedBox:setY(y)
    self.strobePctLabel:setX(self.strobeSpeedBox:getX() + self.strobeSpeedBox:getWidth() + 4)
    self.strobePctLabel:setY(y + 2)
    self.strobeOnPctBox:setX(self.strobePctLabel:getX() + 28)
    self.strobeOnPctBox:setY(y)

    y = y + BUTTON_HGT + rowPad

    self.fireTick:setX(fxX)
    self.fireTick:setY(y)
    self.fireSeverityLabel:setX(inlineX)
    self.fireSeverityLabel:setY(y + 2)
    self.fireSeverityBox:setX(inlineX + 54)
    self.fireSeverityBox:setY(y)

    y = y + BUTTON_HGT + rowPad

    self.stormTick:setX(fxX)
    self.stormTick:setY(y)
    self.stormSeverityLabel:setX(inlineX)
    self.stormSeverityLabel:setY(y + 2)
    self.stormSeverityBox:setX(inlineX + 54)
    self.stormSeverityBox:setY(y)

    y = y + BUTTON_HGT + rowPad

    self.mysticTick:setX(fxX)
    self.mysticTick:setY(y)
    self.mysticSpeedLabel:setX(inlineX)
    self.mysticSpeedLabel:setY(y + 2)
    self.mysticSpeedBox:setX(inlineX + 36)
    self.mysticSpeedBox:setY(y)

    y = y + BUTTON_HGT + rowPad

    self.horrorTick:setX(fxX)
    self.horrorTick:setY(y)

    local buttonY = self.height - self:resizeWidgetHeight() - pad - BUTTON_HGT
    self.toggleButton:setX(pad)
    self.toggleButton:setY(buttonY)
    self.toggleButton:setWidth(self.width - (pad * 2))

    self._lastLayoutW = self.width
    self._lastLayoutH = self.height
end

function ParadiseZTrailingLightsWindow:updateVisuals()
    local state = TL.getState(self.playerNum)
    local r, g, b = TL.getColorRGB(state, state.brightness)

    self.previewButton.backgroundColor = { r = r, g = g, b = b, a = 1.0 }
    self.previewButton.backgroundColorMouseOver = {
        r = clamp(r + 0.10, 0, 1),
        g = clamp(g + 0.10, 0, 1),
        b = clamp(b + 0.10, 0, 1),
        a = 1.0
    }

    self.brightnessValue:setName(string.format("%.2f", state.brightness))
    self.radiusValue:setName(tostring(state.radius))

    if state.enabled then
        self.toggleButton:setTitle("Turn Off")
        self.toggleButton.backgroundColor = { r = 0.18, g = 0.34, b = 0.18, a = 1.0 }
        self.toggleButton.backgroundColorMouseOver = { r = 0.24, g = 0.42, b = 0.24, a = 1.0 }
    else
        self.toggleButton:setTitle("Turn On")
        self.toggleButton.backgroundColor = { r = 0.25, g = 0.25, b = 0.25, a = 1.0 }
        self.toggleButton.backgroundColorMouseOver = { r = 0.35, g = 0.35, b = 0.35, a = 1.0 }
    end
end

function ParadiseZTrailingLightsWindow:syncFromState()
    local state = TL.getState(self.playerNum)

    self.brightnessSlider:setCurrentValue(state.brightness, true)
    self.radiusSlider:setCurrentValue(state.radius, true)
    self.visibilityCombo:setSelectedData(state.visibility)

    self.flashTick:setSelected(1, state.effect == TL.EFFECT_FLASH)
    self.strobeTick:setSelected(1, state.effect == TL.EFFECT_STROBE)
    self.fireTick:setSelected(1, state.effect == TL.EFFECT_FIRE)
    self.stormTick:setSelected(1, state.effect == TL.EFFECT_STORM)
    self.mysticTick:setSelected(1, state.effect == TL.EFFECT_MYSTIC)
    self.horrorTick:setSelected(1, state.effect == TL.EFFECT_HORROR)

    self.flashPeriodBox:setValue(state.flashPeriod, true)
    self.flashOnPctBox:setValue(state.flashOnPct, true)
    self.strobeSpeedBox:setValue(state.strobeSpeed, true)
    self.strobeOnPctBox:setValue(state.strobeOnPct, true)
    self.fireSeverityBox:setValue(state.fireSeverity, true)
    self.stormSeverityBox:setValue(state.stormSeverity, true)
    self.mysticSpeedBox:setValue(state.mysticSpeed, true)

    self:updateVisuals()
end

function ParadiseZTrailingLightsWindow:prerender()
    if self.width < (self.minimumWidth or self.minWidth) then
        self:setWidth(self.minimumWidth or self.minWidth)
    end
    if self.height < (self.minimumHeight or self.minHeight) then
        self:setHeight(self.minimumHeight or self.minHeight)
    end

    self:layoutChrome()

    if self._lastLayoutW ~= self.width or self._lastLayoutH ~= self.height then
        self:layoutChildren()
    end

    self:updateVisuals()
    ISCollapsableWindow.prerender(self)
end

function ParadiseZTrailingLightsWindow:onBrightnessChanged(value, slider)
    local state = TL.getState(self.playerNum)
    state.brightness = round(clamp(value, 0.00, 1.00), 2)
    TL.onLocalStateChanged(self.playerNum)
end

function ParadiseZTrailingLightsWindow:onRadiusChanged(value, slider)
    local state = TL.getState(self.playerNum)
    state.radius = clamp(math.floor(value + 0.5), 1, 30)
    TL.onLocalStateChanged(self.playerNum)
end

function ParadiseZTrailingLightsWindow:onVisibilityChanged(combo)
    local state = TL.getState(self.playerNum)
    state.visibility = combo:getSelectedData() or TL.VIS_LOCAL
    TL.onLocalStateChanged(self.playerNum)
end

function ParadiseZTrailingLightsWindow:onFlashPeriodChanged(value, box)
    local state = TL.getState(self.playerNum)
    state.flashPeriod = round(clamp(value, 1.5, 30.0), 1)
    TL.onLocalStateChanged(self.playerNum)
end

function ParadiseZTrailingLightsWindow:onFlashOnPctChanged(value, box)
    local state = TL.getState(self.playerNum)
    state.flashOnPct = clamp(math.floor(value + 0.5), 5, 95)
    TL.onLocalStateChanged(self.playerNum)
end

function ParadiseZTrailingLightsWindow:onStrobeSpeedChanged(value, box)
    local state = TL.getState(self.playerNum)
    state.strobeSpeed = round(clamp(value, 0.1, 10.0), 1)
    TL.onLocalStateChanged(self.playerNum)
end

function ParadiseZTrailingLightsWindow:onStrobeOnPctChanged(value, box)
    local state = TL.getState(self.playerNum)
    state.strobeOnPct = clamp(math.floor(value + 0.5), 5, 95)
    TL.onLocalStateChanged(self.playerNum)
end

function ParadiseZTrailingLightsWindow:onFireSeverityChanged(value, box)
    local state = TL.getState(self.playerNum)
    state.fireSeverity = round(clamp(value, 0.1, 10.0), 1)
    TL.onLocalStateChanged(self.playerNum)
end

function ParadiseZTrailingLightsWindow:onStormSeverityChanged(value, box)
    local state = TL.getState(self.playerNum)
    state.stormSeverity = round(clamp(value, 0.1, 10.0), 1)
    TL.onLocalStateChanged(self.playerNum)
end

function ParadiseZTrailingLightsWindow:onMysticSpeedChanged(value, box)
    local state = TL.getState(self.playerNum)
    state.mysticSpeed = round(clamp(value, 0.1, 10.0), 1)
    TL.onLocalStateChanged(self.playerNum)
end

function ParadiseZTrailingLightsWindow:onEffectChanged(index, selected, effectId, unused, tickbox)
    local state = TL.getState(self.playerNum)

    if selected then
        state.effect = TL.normalizeEffect(effectId)
    elseif state.effect == effectId then
        state.effect = TL.EFFECT_NONE
    end

    TL.onLocalStateChanged(self.playerNum)
end

function ParadiseZTrailingLightsWindow:onToggleLight(button)
    local state = TL.getState(self.playerNum)
    state.enabled = not state.enabled
    TL.onLocalStateChanged(self.playerNum)
end

function ParadiseZTrailingLightsWindow.onColorPicked(target, color, mouseUp)
    if not target then
        return
    end

    local colorInfo = ColorInfo.new(color.r or 1.0, color.g or 1.0, color.b or 1.0, 1.0)
    local h, s, v = ISColorPickerHSB:toHSB(colorInfo:toColor())

    local state = TL.getState(target.playerNum)
    state.h = clamp(h or TL.defaults.h, 0, 1)
    state.s = clamp(s or TL.defaults.s, 0, 1)
    state.brightness = clamp(v or TL.defaults.brightness, 0, 1)

    if target.colorPicker then
        target.colorPicker:removeSelf()
        target.colorPicker = nil
    end

    TL.onLocalStateChanged(target.playerNum)
end

function ParadiseZTrailingLightsWindow:onPickColor(button)
    local state = TL.getState(self.playerNum)

    if self.colorPicker then
        self.colorPicker:removeSelf()
        self.colorPicker = nil
    end

    local initialColor = TL.getColorInfo(state, state.brightness)
    local picker = ISColorPickerHSB:new(0, 0, initialColor)
    picker:initialise()
    picker.keepOnScreen = true
    picker.pickedTarget = self
    picker.pickedFunc = ParadiseZTrailingLightsWindow.onColorPicked
    picker.resetFocusTo = self
    picker:setX(button:getAbsoluteX())
    picker:setY(button:getAbsoluteY() + button:getHeight() + 1)
    picker:addToUIManager()
    picker:setInitialColor(initialColor)
    picker:setCapture(true)
    picker:bringToTop()

    self.colorPicker = picker
end

function ParadiseZTrailingLightsWindow:close()
    if self.colorPicker then
        self.colorPicker:removeSelf()
        self.colorPicker = nil
    end
    TL.windows[self.playerNum] = nil
    self:setVisible(false)
    self:removeFromUIManager()
end

function ParadiseZTrailingLightsWindow:new(x, y, width, height, playerNum)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.playerNum = playerNum or 0
    o.title = "ParadiseZ: Trailing Lights"
    o.resizable = true
    o.fixedSliderWidth = 150

    o.minWidth = 276
    o.minHeight = 392
    o.minimumWidth = 276
    o.minimumHeight = 392

    return o
end

function TL.openWindow(playerNum)
    playerNum = playerNum or 0

    local window = TL.windows[playerNum]
    if window then
        window:syncFromState()
        window:setVisible(true)
        window:addToUIManager()
        window:bringToTop()
        return
    end

    local width = 276
    local height = 392
    local x = math.max(20, math.floor((getCore():getScreenWidth() - width) / 2))
    local y = math.max(20, math.floor((getCore():getScreenHeight() - height) / 2))

    window = ParadiseZTrailingLightsWindow:new(x, y, width, height, playerNum)
    window:initialise()
    window:addToUIManager()
    window:bringToTop()

    TL.windows[playerNum] = window
    window:syncFromState()
end

function TL.installRenderer()
    if TL._rendererInstalled then
        return
    end
    TL._rendererInstalled = true

    TL._tickHook = function()
        local ok, err = pcall(TL.onTick)
        if not ok then
            print("[ParadiseZ] tick error: " .. tostring(err))
        end
    end
    Events.OnTick.Add(TL._tickHook)
end

function TL.install()
    if TL._installed then
        return
    end
    TL._installed = true

    PZContext.install(TL.openWindow)
    TL.installRenderer()

    for playerNum = 0, getNumActivePlayers() - 1 do
        local state = TL.getState(playerNum)
        state.enabled = false
        TL.pushSharedState(playerNum)
    end
end

-- Security/ParadiseZ_access.lua calls TL.install() only after the server has
-- verified this client as an administrator. No tick or menu hooks exist before.
print("[ParadiseZ] Trailing Lights loaded; awaiting admin authorization.")