
WaveCaster = WaveCaster or {}

function WaveCaster.getGameMinutes()
    local gt = getGameTime()
    return math.floor(gt:getWorldAgeHours() * 60)
end

function WaveCaster.formatGameMinutes(Countdown)
    local days = math.floor(Countdown / 1440)
    local hours = math.floor((Countdown % 1440) / 60)
    local mins = Countdown % 60

    return string.format("%d days, %d hours, %d mins", days, hours, mins)
end

function WaveCaster.formatRemainingMin(Countdown)
    if Countdown < 0 then Countdown = 0 end

    local days = math.floor(Countdown / 1440)
    local hours = math.floor((Countdown % 1440) / 60)
    local mins = Countdown % 60

    if days > 0 then
        return string.format("%dd %02dh %02dm", days, hours, mins)
    elseif hours > 0 then
        return string.format("%dh %02dm", hours, mins)
    else
        return string.format("%dm", mins)
    end
end

function WaveCaster.formatRemainingMinutes(minutes)
    minutes = minutes or 0
    if minutes <= 0 then return "Ready" end
    local h = math.floor(minutes / 60)
    local m = minutes % 60
    if h > 0 and m > 0 then
        return string.format("%dh %dm", h, m)
    elseif h > 0 then
        return string.format("%dh", h)
    end
    return string.format("%dm", m)
end


--WaveCaster.formatGameTimeShort(338913)
-- 235d 8h 33m
function WaveCaster.formatGameTimeShort(Countdown)
    local days = math.floor(Countdown / 1440)
    local hours = math.floor((Countdown % 1440) / 60)
    local mins = Countdown % 60

    return string.format("%dd %dh %dm", days, hours, mins)
end

--WaveCaster.formatRemainingTimeShort(90)
-- 0d 1h 30m
function WaveCaster.formatRemainingTimeShort(Countdown)
    if Countdown < 0 then Countdown = 0 end

    local days = math.floor(Countdown / 1440)
    local hours = math.floor((Countdown % 1440) / 60)
    local mins = Countdown % 60

    return string.format("%dd %dh %dm", days, hours, mins)
end

