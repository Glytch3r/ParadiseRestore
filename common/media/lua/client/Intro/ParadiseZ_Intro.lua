-- B42 exposes OnPreMapLoad reliably, but it occurs before the Enter Paradise
-- prompt. Delay the standalone ParadiseZ sound so it lands after that screen.
ParadiseZIntro = ParadiseZIntro or {}
local Intro = ParadiseZIntro
Intro.played = Intro.played == true
Intro.startedAt = Intro.startedAt or nil
Intro.tickInstalled = Intro.tickInstalled == true
Intro.delayMilliseconds = 15000

function Intro.onTick()
    if Intro.played or not Intro.startedAt then
        return
    end

    if getTimestampMs() - Intro.startedAt < Intro.delayMilliseconds then
        return
    end

    Intro.played = true
    Intro.startedAt = nil
    if Intro.tickInstalled then
        Events.OnTick.Remove(Intro.onTick)
        Intro.tickInstalled = false
    end

    print("[ParadiseZ] Delayed intro sound: ParadiseZ_Intro_2 at 25% volume.")
    local soundHandle = getSoundManager():playUISound("ParadiseZ_Intro_2")
    if soundHandle ~= 0 then
        getSoundManager():getUIEmitter():setVolume(soundHandle, 0.25)
    end
end

function Intro.onPreMapLoad()
    if Intro.played or Intro.startedAt then
        return
    end

    Intro.startedAt = getTimestampMs()
    if not Intro.tickInstalled then
        Intro.tickInstalled = true
        Events.OnTick.Add(Intro.onTick)
    end
    print("[ParadiseZ] World loading started; intro sound queued for 15 seconds.")
end

Events.OnPreMapLoad.Add(Intro.onPreMapLoad)
print("[ParadiseZ] Intro hook registered: delayed OnPreMapLoad")