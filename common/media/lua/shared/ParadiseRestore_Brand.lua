ParadiseRestore = ParadiseRestore or {}
ParadiseRestore.Brand = ParadiseRestore.Brand or {}
local Brand = ParadiseRestore.Brand

local trim = function(s)
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local isHex = function(s)
	return type(s) == "string" and string.match(s, "^%x%x%x%x%x%x$") ~= nil
end

local hexToRgb = function(hex)
	return {
		r = tonumber(string.sub(hex, 1, 2), 16),
		g = tonumber(string.sub(hex, 3, 4), 16),
		b = tonumber(string.sub(hex, 5, 6), 16),
	}
end

local rgbToHex = function(c)
	return string.format("%02X%02X%02X", math.floor(c.r + 0.5), math.floor(c.g + 0.5), math.floor(c.b + 0.5))
end

local mix = function(a, b, t)
	return { r = a.r + (b.r - a.r) * t, g = a.g + (b.g - a.g) * t, b = a.b + (b.b - a.b) * t }
end

local lighten = function(c, t)
	return mix(c, { r = 255, g = 255, b = 255 }, t)
end

local darken = function(c, t)
	return mix(c, { r = 0, g = 0, b = 0 }, t)
end

Brand.DEFAULT_LIST =
	"pegasus:Pegasus:heaven:@pegasus;" ..
	"cerberus:Cerberus:hell:@cerberus;" ..
	"kraken:Kraken:between:@kraken;" ..
	"minotaur:Minotaur:between:@minotaur;" ..
	"mananangal:Mananangal:hell:@mananangal;" ..
	"styx:Styx:between:@styx"

Brand.presets = {
	pegasus = {
		label = "Pegasus",
		align = "heaven",
		tagline = "Ivory and gold, the paradise you build",
		tokens = {
			["window.bg"] = "1A130AE8",
			["window.border"] = "C9A94F",
			["window.borderInner"] = "4A3618",
			["window.titleBg"] = "241A0CF2",
			["window.titleText"] = "F6E7BD",
			["window.titleRule"] = "C9A94F",
			["window.glow"] = "E7C86A",
			["surface.base"] = "17110AEB",
			["surface.raised"] = "211809F2",
			["surface.sunken"] = "0F0B06F2",
			["tab.bg"] = "1C140AF2",
			["tab.activeTint"] = "C9A94F",
			["tab.idleTint"] = "6A5326",
			["tab.hover"] = "E7C86A",
			["tab.text"] = "BFA878",
			["tab.textActive"] = "F6E7BD",
			["tab.indicator"] = "C9A94F",
			["text.primary"] = "F0E4C6",
			["text.secondary"] = "C3AE86",
			["text.muted"] = "8E7C5C",
			["text.alert"] = "D9704F",
			["text.success"] = "9DB26A",
			["accent.primary"] = "C9A94F",
			["accent.secondary"] = "8A6C2E",
			["accent.glow"] = "E7C86A",
			["button.bg"] = "2A1F0DF2",
			["button.bgHover"] = "3E2D12",
			["button.bgPressed"] = "1E1608",
			["button.bgDisabled"] = "1B150B",
			["button.border"] = "5C4620",
			["button.borderHover"] = "C9A94F",
			["button.text"] = "F0E4C6",
			["button.textDisabled"] = "6F6248",
			["button.blink"] = "E7C86A",
			["frame.portrait"] = "C9A94F",
			["frame.portraitTint"] = "6E5A2A",
			["divider"] = "5C4620",
			["watermark"] = "C9A94F",
		},
	},
	cerberus = {
		label = "Cerberus",
		align = "hell",
		tagline = "Ember and bone, the hell you survive",
		tokens = {
			["window.bg"] = "140A09F0",
			["window.border"] = "A33A24",
			["window.borderInner"] = "43140D",
			["window.titleBg"] = "1C0A08F5",
			["window.titleText"] = "F3D2B6",
			["window.titleRule"] = "C8452A",
			["window.glow"] = "FF7A3C",
			["surface.base"] = "120B0AF0",
			["surface.raised"] = "1D1210F5",
			["surface.sunken"] = "0A0505F5",
			["tab.bg"] = "170D0BF2",
			["tab.activeTint"] = "C8452A",
			["tab.idleTint"] = "5E241B",
			["tab.hover"] = "FF7A3C",
			["tab.text"] = "C2947E",
			["tab.textActive"] = "F5DCC4",
			["tab.indicator"] = "FF7A3C",
			["text.primary"] = "EED8C0",
			["text.secondary"] = "B98F78",
			["text.muted"] = "80604F",
			["text.alert"] = "FF6A46",
			["text.success"] = "A3A05A",
			["accent.primary"] = "C8452A",
			["accent.secondary"] = "7A2A1C",
			["accent.glow"] = "FF7A3C",
			["button.bg"] = "2A1512F2",
			["button.bgHover"] = "3E1D17",
			["button.bgPressed"] = "1A0C0A",
			["button.bgDisabled"] = "180F0D",
			["button.border"] = "5E241B",
			["button.borderHover"] = "C8452A",
			["button.text"] = "EED8C0",
			["button.textDisabled"] = "6C5247",
			["button.blink"] = "FF7A3C",
			["frame.portrait"] = "A33A24",
			["frame.portraitTint"] = "6A2C22",
			["divider"] = "5E241B",
			["watermark"] = "C8452A",
		},
	},
	kraken = {
		label = "Kraken",
		align = "between",
		tagline = "Black water and cold light",
		tokens = {
			["window.bg"] = "06141AF0",
			["window.border"] = "2E7F8C",
			["window.borderInner"] = "0F3A42",
			["window.titleBg"] = "081C22F5",
			["window.titleText"] = "DDF4F6",
			["window.titleRule"] = "3FA9B8",
			["window.glow"] = "7FE3E8",
			["surface.base"] = "07161BF0",
			["surface.raised"] = "0D2229F5",
			["surface.sunken"] = "040D11F5",
			["tab.bg"] = "0A1D23F2",
			["tab.activeTint"] = "3FA9B8",
			["tab.idleTint"] = "1F5B66",
			["tab.hover"] = "7FE3E8",
			["tab.text"] = "93C3C9",
			["tab.textActive"] = "E2F7F8",
			["tab.indicator"] = "7FE3E8",
			["text.primary"] = "DCF2F4",
			["text.secondary"] = "A9CCD1",
			["text.muted"] = "6F9297",
			["text.alert"] = "E8795F",
			["text.success"] = "63C79E",
			["accent.primary"] = "3FA9B8",
			["accent.secondary"] = "1F6F78",
			["accent.glow"] = "7FE3E8",
			["button.bg"] = "0E262DF2",
			["button.bgHover"] = "173C46",
			["button.bgPressed"] = "08181D",
			["button.bgDisabled"] = "0A1A1F",
			["button.border"] = "1F5B66",
			["button.borderHover"] = "3FA9B8",
			["button.text"] = "DCF2F4",
			["button.textDisabled"] = "5A7C82",
			["button.blink"] = "7FE3E8",
			["frame.portrait"] = "2E7F8C",
			["frame.portraitTint"] = "1F5B66",
			["divider"] = "1F5B66",
			["watermark"] = "3FA9B8",
		},
	},
	minotaur = {
		label = "Minotaur",
		align = "between",
		tagline = "Bronze halls and labyrinth dust",
		tokens = {
			["window.bg"] = "1A130DF0",
			["window.border"] = "A9742F",
			["window.borderInner"] = "4A2E14",
			["window.titleBg"] = "241A10F5",
			["window.titleText"] = "F5E2C2",
			["window.titleRule"] = "C98A3E",
			["window.glow"] = "E8B563",
			["surface.base"] = "17110BF0",
			["surface.raised"] = "21180FF5",
			["surface.sunken"] = "100B07F5",
			["tab.bg"] = "1D150DF2",
			["tab.activeTint"] = "C98A3E",
			["tab.idleTint"] = "7A5423",
			["tab.hover"] = "E8B563",
			["tab.text"] = "C8AB80",
			["tab.textActive"] = "F7E7C8",
			["tab.indicator"] = "E8B563",
			["text.primary"] = "F1DFC2",
			["text.secondary"] = "C7AC82",
			["text.muted"] = "8F7854",
			["text.alert"] = "D9532F",
			["text.success"] = "A3A85A",
			["accent.primary"] = "C98A3E",
			["accent.secondary"] = "7A5423",
			["accent.glow"] = "E8B563",
			["button.bg"] = "2B1E12F2",
			["button.bgHover"] = "3B2A1B",
			["button.bgPressed"] = "1C1309",
			["button.bgDisabled"] = "1A130D",
			["button.border"] = "63441F",
			["button.borderHover"] = "C98A3E",
			["button.text"] = "F1DFC2",
			["button.textDisabled"] = "78654B",
			["button.blink"] = "E8B563",
			["frame.portrait"] = "A9742F",
			["frame.portraitTint"] = "6E4B24",
			["divider"] = "63441F",
			["watermark"] = "C98A3E",
		},
	},
	mananangal = {
		label = "Mananangal",
		align = "hell",
		tagline = "Moonlit rot and bruised violet",
		tokens = {
			["window.bg"] = "100C12F0",
			["window.border"] = "6E4A7E",
			["window.borderInner"] = "332041",
			["window.titleBg"] = "171020F5",
			["window.titleText"] = "E6DDEA",
			["window.titleRule"] = "8FA34A",
			["window.glow"] = "C9D98A",
			["surface.base"] = "0E0B10F0",
			["surface.raised"] = "17111DF5",
			["surface.sunken"] = "08060AF5",
			["tab.bg"] = "130E17F2",
			["tab.activeTint"] = "8FA34A",
			["tab.idleTint"] = "4A3258",
			["tab.hover"] = "C9D98A",
			["tab.text"] = "B3A6BC",
			["tab.textActive"] = "EADFEA",
			["tab.indicator"] = "C9D98A",
			["text.primary"] = "E2D9E6",
			["text.secondary"] = "B4A8BC",
			["text.muted"] = "7F7488",
			["text.alert"] = "D0516E",
			["text.success"] = "8FA34A",
			["accent.primary"] = "8FA34A",
			["accent.secondary"] = "6E4A7E",
			["accent.glow"] = "C9D98A",
			["button.bg"] = "1B1422F2",
			["button.bgHover"] = "2A2033",
			["button.bgPressed"] = "120D17",
			["button.bgDisabled"] = "120F16",
			["button.border"] = "453153",
			["button.borderHover"] = "8FA34A",
			["button.text"] = "E2D9E6",
			["button.textDisabled"] = "70687A",
			["button.blink"] = "C9D98A",
			["frame.portrait"] = "6E4A7E",
			["frame.portraitTint"] = "4A3258",
			["divider"] = "453153",
			["watermark"] = "8FA34A",
		},
	},
	styx = {
		label = "Styx",
		align = "between",
		tagline = "Ash and river fog",
		tokens = {
			["window.bg"] = "0D1116F0",
			["window.border"] = "6C7F8E",
			["window.borderInner"] = "33424D",
			["window.titleBg"] = "111820F5",
			["window.titleText"] = "E4EEF5",
			["window.titleRule"] = "8FA6B8",
			["window.glow"] = "CFE3F2",
			["surface.base"] = "0B1015F0",
			["surface.raised"] = "121A21F5",
			["surface.sunken"] = "060A0DF5",
			["tab.bg"] = "0F161BF2",
			["tab.activeTint"] = "8FA6B8",
			["tab.idleTint"] = "38505F",
			["tab.hover"] = "CFE3F2",
			["tab.text"] = "A9B8C4",
			["tab.textActive"] = "EAF2F8",
			["tab.indicator"] = "CFE3F2",
			["text.primary"] = "DCE6ED",
			["text.secondary"] = "A6B6C2",
			["text.muted"] = "76858F",
			["text.alert"] = "D9806E",
			["text.success"] = "7FAF95",
			["accent.primary"] = "8FA6B8",
			["accent.secondary"] = "38505F",
			["accent.glow"] = "CFE3F2",
			["button.bg"] = "161F26F2",
			["button.bgHover"] = "22303A",
			["button.bgPressed"] = "0D141A",
			["button.bgDisabled"] = "101820",
			["button.border"] = "3E4C57",
			["button.borderHover"] = "8FA6B8",
			["button.text"] = "DCE6ED",
			["button.textDisabled"] = "6C7A83",
			["button.blink"] = "CFE3F2",
			["frame.portrait"] = "6C7F8E",
			["frame.portraitTint"] = "38505F",
			["divider"] = "3E4C57",
			["watermark"] = "8FA6B8",
		},
	},
}

Brand.presetOrder = { "pegasus", "cerberus", "kraken", "minotaur", "mananangal", "styx" }

Brand.prefFile = "ParadiseBrand.ini"
Brand.selection = nil
Brand.selectionLoaded = false
Brand.listRaw = nil
Brand.listCache = nil
Brand.lastRawCheck = -1000
Brand.overrideKey = nil
Brand.previewDef = nil

function ParadiseRestore.Brand.parseHex(hex)
	local r = tonumber(string.sub(hex, 1, 2), 16) / 255
	local g = tonumber(string.sub(hex, 3, 4), 16) / 255
	local b = tonumber(string.sub(hex, 5, 6), 16) / 255
	local a = 1
	if #hex >= 8 then
		a = tonumber(string.sub(hex, 7, 8), 16) / 255
	end
	return { r = r, g = g, b = b, a = a }
end

function ParadiseRestore.Brand.deriveTokens(def)
	local accent = hexToRgb(def.accent)
	local bg = hexToRgb(def.bg)
	local text = hexToRgb(def.text)
	local alert, success
	if def.align == "heaven" then
		alert, success = "D9704F", "9DB26A"
	elseif def.align == "hell" then
		alert, success = "FF6A46", "A3A05A"
	else
		alert, success = "E8795F", "63C79E"
	end
	local glow = lighten(accent, 0.45)
	local dim = darken(accent, 0.55)
	return {
		["window.bg"] = rgbToHex(darken(bg, 0.05)) .. "E8",
		["window.border"] = rgbToHex(accent),
		["window.borderInner"] = rgbToHex(dim),
		["window.titleBg"] = rgbToHex(mix(bg, accent, 0.07)) .. "F2",
		["window.titleText"] = rgbToHex(lighten(text, 0.18)),
		["window.titleRule"] = rgbToHex(accent),
		["window.glow"] = rgbToHex(glow),
		["surface.base"] = rgbToHex(darken(bg, 0.03)) .. "EB",
		["surface.raised"] = rgbToHex(lighten(bg, 0.06)) .. "F2",
		["surface.sunken"] = rgbToHex(darken(bg, 0.30)) .. "F2",
		["tab.bg"] = rgbToHex(bg) .. "F2",
		["tab.activeTint"] = rgbToHex(accent),
		["tab.idleTint"] = rgbToHex(darken(accent, 0.55)),
		["tab.hover"] = rgbToHex(glow),
		["tab.text"] = rgbToHex(mix(text, bg, 0.35)),
		["tab.textActive"] = rgbToHex(text),
		["tab.indicator"] = rgbToHex(glow),
		["text.primary"] = rgbToHex(text),
		["text.secondary"] = rgbToHex(mix(text, bg, 0.28)),
		["text.muted"] = rgbToHex(mix(text, bg, 0.52)),
		["text.alert"] = alert,
		["text.success"] = success,
		["accent.primary"] = rgbToHex(accent),
		["accent.secondary"] = rgbToHex(darken(accent, 0.35)),
		["accent.glow"] = rgbToHex(glow),
		["button.bg"] = rgbToHex(lighten(bg, 0.10)) .. "F2",
		["button.bgHover"] = rgbToHex(mix(lighten(bg, 0.20), accent, 0.18)),
		["button.bgPressed"] = rgbToHex(darken(bg, 0.30)),
		["button.bgDisabled"] = rgbToHex(bg),
		["button.border"] = rgbToHex(dim),
		["button.borderHover"] = rgbToHex(accent),
		["button.text"] = rgbToHex(text),
		["button.textDisabled"] = rgbToHex(mix(text, bg, 0.62)),
		["button.blink"] = rgbToHex(glow),
		["frame.portrait"] = rgbToHex(accent),
		["frame.portraitTint"] = rgbToHex(darken(accent, 0.50)),
		["divider"] = rgbToHex(dim),
		["watermark"] = rgbToHex(accent),
	}
end

function ParadiseRestore.Brand.buildTheme(def)
	if def.c then return def end
	local tokens
	if def.mode == "preset" and def.preset and ParadiseRestore.Brand.presets[def.preset] then
		tokens = ParadiseRestore.Brand.presets[def.preset].tokens
	else
		tokens = ParadiseRestore.Brand.deriveTokens(def)
	end
	def.c = {}
	for tok, hex in pairs(tokens) do
		def.c[tok] = ParadiseRestore.Brand.parseHex(hex)
	end
	return def
end

function ParadiseRestore.Brand.parseThemeList(raw)
	local list = {}
	if type(raw) ~= "string" then return list end
	for entry in string.gmatch(raw, "[^;]+") do
		entry = trim(entry)
		if entry ~= "" then
			local f = {}
			for part in string.gmatch(entry, "[^:]+") do
				f[#f + 1] = trim(part)
			end
			local key, label, align = f[1], f[2], f[3]
			if key and string.match(key, "^[%w_]+$") and label and label ~= "" then
				if align ~= "heaven" and align ~= "hell" then align = "between" end
				local def = { key = key, label = label, align = align }
				if f[4] and string.sub(f[4], 1, 1) == "@" then
					local preset = string.sub(f[4], 2)
					if ParadiseRestore.Brand.presets[preset] then
						def.mode = "preset"
						def.preset = preset
						list[#list + 1] = def
					end
				elseif #f >= 6 and isHex(f[4]) and isHex(f[5]) and isHex(f[6]) then
					def.mode = "custom"
					def.accent = string.upper(f[4])
					def.bg = string.upper(f[5])
					def.text = string.upper(f[6])
					list[#list + 1] = def
				end
			end
		end
	end
	return list
end

function ParadiseRestore.Brand.fallbackDef()
	return { key = "pegasus", label = "Pegasus", align = "heaven", mode = "preset", preset = "pegasus" }
end

function ParadiseRestore.Brand.readRawOption()
	local raw
	if getSandboxOptions then
		local so = getSandboxOptions()
		if so and so.getOptionByName then
			local opt = so:getOptionByName("ParadiseZ.Themes")
			if opt and opt.getValue then
				raw = opt:getValue()
			end
		end
	end
	if type(raw) ~= "string" or raw == "" then
		local sand = SandboxVars and SandboxVars.ParadiseZ
		raw = sand and sand.Themes or nil
	end
	if type(raw) ~= "string" or raw == "" then
		return ParadiseRestore.Brand.DEFAULT_LIST
	end
	return raw
end

function ParadiseRestore.Brand.invalidate()
	ParadiseRestore.Brand.listRaw = nil
	ParadiseRestore.Brand.listCache = nil
	ParadiseRestore.Brand.lastRawCheck = -1000
end

function ParadiseRestore.Brand.getThemeList()
	local B = ParadiseRestore.Brand
	local now = getTimestampMs and getTimestampMs() or 0
	if not B.listCache or (now - B.lastRawCheck) > 500 then
		B.lastRawCheck = now
		local raw = B.readRawOption()
		if raw ~= B.listRaw or not B.listCache then
			B.listRaw = raw
			B.listCache = B.parseThemeList(raw)
			if #B.listCache == 0 then
				B.listCache = B.parseThemeList(B.DEFAULT_LIST)
			end
		end
	end
	return B.listCache
end

function ParadiseRestore.Brand.findTheme(key)
	local list = ParadiseRestore.Brand.getThemeList()
	for i = 1, #list do
		if list[i].key == key then return list[i] end
	end
	return nil
end

function ParadiseRestore.Brand.ensureSelection()
	local B = ParadiseRestore.Brand
	if B.selectionLoaded then return end
	B.selectionLoaded = true
	if not getFileReader then return end
	local reader = getFileReader(B.prefFile, true)
	if not reader then return end
	local line = reader:readLine()
	while line do
		local key = string.match(line, "^theme=(.+)$")
		if key and key ~= "" then
			B.selection = trim(key)
		end
		line = reader:readLine()
	end
	reader:close()
end

function ParadiseRestore.Brand.setSelection(key)
	local B = ParadiseRestore.Brand
	local def = key and B.findTheme(key) or nil
	B.selection = def and key or nil
	if getFileWriter then
		local writer = getFileWriter(B.prefFile, true, false)
		if writer then
			writer:write("theme=" .. tostring(B.selection or "") .. "\n")
			writer:close()
		end
	end
	B.overrideKey = nil
	B.previewDef = nil
	if B.repaint then B.repaint() end
end

function ParadiseRestore.Brand.get()
	local B = ParadiseRestore.Brand
	if B.previewDef then return B.buildTheme(B.previewDef) end
	B.ensureSelection()
	local list = B.getThemeList()
	local key = B.overrideKey or B.selection
	local def
	if key then
		for i = 1, #list do
			if list[i].key == key then
				def = list[i]
				break
			end
		end
	end
	def = def or list[1] or B.fallbackDef()
	return B.buildTheme(def)
end

function ParadiseRestore.Brand.currentKey()
	local B = ParadiseRestore.Brand
	if B.previewDef then return B.previewDef.key end
	return B.get().key
end

function ParadiseRestore.Brand.col(tok, alpha)
	local c = ParadiseRestore.Brand.get().c[tok]
	if not c then return 1, 1, 1, 1 end
	return c.r, c.g, c.b, alpha or c.a
end

function ParadiseRestore.Brand.tbl(tok, alpha)
	local r, g, b, a = ParadiseRestore.Brand.col(tok, alpha)
	return { r = r, g = g, b = b, a = a }
end

function ParadiseRestore.Brand.hexColor(hex, alpha)
	local c = ParadiseRestore.Brand.parseHex(hex)
	return c.r, c.g, c.b, alpha or c.a
end

function ParadiseRestore.Brand.pulse()
	local ms = getTimestampMs and getTimestampMs() or 0
	return 0.30 + 0.70 * (0.5 + 0.5 * math.sin(ms / 380))
end

function ParadiseRestore.Brand.preview(key)
	if not ParadiseRestore.Brand.findTheme(key) then return false end
	ParadiseRestore.Brand.overrideKey = key
	ParadiseRestore.Brand.previewDef = nil
	if ParadiseRestore.Brand.repaint then ParadiseRestore.Brand.repaint() end
	return true
end

function ParadiseRestore.Brand.previewTheme(def)
	if type(def) ~= "table" or def.mode == nil then return false end
	local copy = {
		key = def.key or "preview",
		label = def.label or "Preview",
		align = def.align or "between",
		mode = def.mode,
		preset = def.preset,
		accent = def.accent,
		bg = def.bg,
		text = def.text,
	}
	ParadiseRestore.Brand.previewDef = ParadiseRestore.Brand.buildTheme(copy)
	ParadiseRestore.Brand.overrideKey = nil
	if ParadiseRestore.Brand.repaint then ParadiseRestore.Brand.repaint() end
	return true
end

function ParadiseRestore.Brand.clearPreview()
	ParadiseRestore.Brand.overrideKey = nil
	ParadiseRestore.Brand.previewDef = nil
	if ParadiseRestore.Brand.repaint then ParadiseRestore.Brand.repaint() end
end

function ParadiseRestore.Brand.cycle()
	local B = ParadiseRestore.Brand
	local list = B.getThemeList()
	local cur = B.currentKey()
	local idx = 1
	for i = 1, #list do
		if list[i].key == cur then idx = i end
	end
	idx = idx + 1
	if idx > #list then idx = 1 end
	B.overrideKey = list[idx] and list[idx].key or nil
	B.previewDef = nil
	if B.repaint then B.repaint() end
	return B.overrideKey
end

function ParadiseRestore.Brand.serialize(list)
	local parts = {}
	for i = 1, #list do
		local def = list[i]
		if def.mode == "preset" and def.preset then
			parts[#parts + 1] = string.format("%s:%s:%s:@%s", def.key, def.label, def.align, def.preset)
		else
			parts[#parts + 1] = string.format("%s:%s:%s:%s:%s:%s", def.key, def.label, def.align, def.accent, def.bg, def.text)
		end
	end
	return table.concat(parts, ";")
end

function ParadiseRestore.Brand.validate(def, list, ignoreKey)
	if type(def) ~= "table" then return false, "No theme selected." end
	if type(def.key) ~= "string" or not string.match(def.key, "^[%w_]+$") then
		return false, "Key must use letters, digits or underscore."
	end
	if type(def.label) ~= "string" or trim(def.label) == "" then
		return false, "Label is required."
	end
	if string.find(def.label, "[;:]") then
		return false, "Label cannot contain a semicolon or colon."
	end
	for i = 1, #(list or {}) do
		local other = list[i]
		if other.key == def.key and other.key ~= ignoreKey then
			return false, "Key already exists: " .. def.key
		end
	end
	if def.mode == "preset" then
		if not def.preset or not ParadiseRestore.Brand.presets[def.preset] then
			return false, "Unknown preset."
		end
	else
		if not isHex(def.accent) or not isHex(def.bg) or not isHex(def.text) then
			return false, "Accent, background and text must be 6-digit hex."
		end
	end
	return true, nil
end

function ParadiseRestore.Brand.writeSandbox(raw)
	if ParadiseRestore.isAdm and not ParadiseRestore.isAdm(getPlayer and getPlayer() or nil) then
		return false, "Admin only."
	end
	if isClient and isClient() then
		if not (SandboxOptions and SandboxOptions.new) then
			return false, "Sandbox options unavailable."
		end
		local opts = SandboxOptions.new()
		opts:copyValuesFrom(getSandboxOptions())
		local opt = opts:getOptionByName("ParadiseZ.Themes")
		if not opt then return false, "ParadiseZ.Themes option missing." end
		opt:setValue(raw)
		opts:sendToServer()
		ParadiseRestore.Brand.invalidate()
		return true, nil
	end
	local opt = getSandboxOptions and getSandboxOptions():getOptionByName("ParadiseZ.Themes")
	if not opt then return false, "ParadiseZ.Themes option missing." end
	local so = getSandboxOptions()
	if so and so.set then
		so:set("ParadiseZ.Themes", raw)
	else
		opt:setValue(raw)
	end
	ParadiseRestore.Brand.invalidate()
	return true, nil
end
