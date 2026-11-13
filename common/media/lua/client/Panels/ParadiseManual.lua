require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"

ParadiseManual = ParadiseManual or {}

local PAGE_SIZE = 512
local SIDE_MARGIN = 12
local BOTTOM_BAR = 44

local SETS = {
    player = { dir = "media/textures/ParadiseManual/Player/", count = 13, label = "Player Guide" },
    admin  = { dir = "media/textures/ParadiseManual/Admin/",  count = 33, label = "Admin Guide" },
}

ParadiseManual.PAGE_BY_KEY = {
    economy = { section = "player", num = 2 },
    economyAccount = { section = "player", num = 3 },
    paradiseMart = { section = "player", num = 4 },
    tradeManagement = { section = "player", num = 5 },
    jimsRules = { section = "player", num = 6 },
    promoPlayer = { section = "player", num = 7 },
    themes = { section = "player", num = 8 },
    mailPlayer = { section = "player", num = 9 },
    squadManager = { section = "player", num = 10 },
    paradiseManual = { section = "player", num = 11 },
    chatCommands = { section = "player", num = 13 },
    adminHub = { section = "admin", num = 1 },
    economyAccountBrowser = { section = "admin", num = 2 },
    economyAdmin = { section = "admin", num = 3 },
    economyTables = { section = "admin", num = 4 },
    economyLedger = { section = "admin", num = 5 },
    safehouseAdmin = { section = "admin", num = 6 },
    contextMenuManager = { section = "admin", num = 7 },
    recordsPanel = { section = "admin", num = 8 },
    jimsRulesAdmin = { section = "admin", num = 9 },
    trailingLights = { section = "admin", num = 10 },
    uiInspector = { section = "admin", num = 11 },
    factionManager = { section = "admin", num = 12 },
    dataCheck = { section = "admin", num = 13 },
    dataSniffer = { section = "admin", num = 14 },
    globalModData = { section = "admin", num = 15 },
    mediaSpawner = { section = "admin", num = 16 },
    modActiveCheck = { section = "admin", num = 17 },
    playtimeCheck = { section = "admin", num = 18 },
    traitSyncer = { section = "admin", num = 19 },
    zedController = { section = "admin", num = 20 },
    zones = { section = "admin", num = 21 },
    zonesEditor = { section = "admin", num = 22 },
    zonesTestRemote = { section = "admin", num = 23 },
    poi = { section = "admin", num = 24 },
    poiBuilder = { section = "admin", num = 25 },
    luaResetTool = { section = "admin", num = 26 },
    waveCaster = { section = "admin", num = 27 },
    promoAdmin = { section = "admin", num = 28 },
    themeEditor = { section = "admin", num = 29 },
    mailAdmin = { section = "admin", num = 30 },
    playerCleanup = { section = "admin", num = 31 },
    notesAdmin = { section = "admin", num = 32 },
    chatCommandsAdmin = { section = "admin", num = 33 },
}

local TITLE_OVERRIDES = {
    jimsRules = "Jim's Rules",
    jimsRulesAdmin = "Jim's Rules (Admin)",
    poi = "POI",
    poiBuilder = "POI Builder",
    uiInspector = "UI Inspector",
    globalModData = "Global ModData",
    promoPlayer = "Promo Codes",
    promoAdmin = "Promo Codes (Admin)",
    mailPlayer = "Mail",
    mailAdmin = "Mail (Admin)",
    zones = "Zone Editor",
    economyTables = "Economy Data",
    chatCommandsAdmin = "Chat Commands (Admin)",
}

local KEY_BY_PAGE = {}
for key, ref in pairs(ParadiseManual.PAGE_BY_KEY) do
    KEY_BY_PAGE[ref.section .. ":" .. ref.num] = key
end

function ParadiseManual.pageTitle(page)
    local key = KEY_BY_PAGE[page.section .. ":" .. page.num]
    if key then
        if TITLE_OVERRIDES[key] then return TITLE_OVERRIDES[key] end
        local str = key:gsub("([a-z])([A-Z])", "%1 %2")
        return str:sub(1, 1):upper() .. str:sub(2)
    end
    if page.section == "player" and page.num == 1 then return "Welcome to Paradise" end
    if page.section == "player" and page.num == 12 then return "Quick Reference" end
    return page.label .. " " .. page.num
end

function ParadiseManual.isAdmin()
    return ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer()) or false
end

function ParadiseManual.getPages(includeAdmin)
    local pages = {}
    local order = includeAdmin and { "player", "admin" } or { "player" }
    for _, name in ipairs(order) do
        local set = SETS[name]
        for i = 1, set.count do
            pages[#pages + 1] = {
                section = name,
                label = set.label,
                num = i,
                path = set.dir .. "page-" .. string.format("%02d", i) .. ".png",
            }
        end
    end
    return pages
end

function ParadiseManual.firstIndexOf(pages, section)
    for i, page in ipairs(pages) do
        if page.section == section then return i end
    end
    return 1
end

function ParadiseManual.getSize()
    local width = math.min(PAGE_SIZE + SIDE_MARGIN * 2, getCore():getScreenWidth() - 40)
    local height = math.min(PAGE_SIZE + BOTTOM_BAR + 50, getCore():getScreenHeight() - 40)
    return width, height
end

function ParadiseManual.text(panel, str, x, y, tok)
    if ParadiseThemes and ParadiseThemes.text then
        ParadiseThemes.text(panel, str, x, y, tok)
        return
    end
    panel:drawText(str, x, y, 1, 1, 1, 1, UIFont.Small)
end

local function setButtonEnabled(btn, on)
    if not btn then return end
    btn.enable = on
    if btn.setEnable then btn:setEnable(on) end
end

function ParadiseManual.attachHelpButton(panel, key)
    if not panel or not key or key == "paradiseManual" then return end
    if not ParadiseManual.PAGE_BY_KEY[key] then return end
    if panel.paradiseHelpButton or not panel.closeButton or not panel.titleBarHeight then return end
    local th = panel:titleBarHeight()
    local btnSize = th - 2
    local btn = ISButton:new(panel.width - 1 - btnSize * 2 - 2, 1, btnSize, btnSize, "?", panel, function(self, button)
        if ParadiseManual.OpenPanel then ParadiseManual.OpenPanel(button.paradiseHelpKey) end
    end)
    btn.paradiseHelpKey = key
    btn.anchorRight = true
    btn.anchorLeft = false
    btn:initialise()
    btn:instantiate()
    btn.borderColor.a = 0
    btn.backgroundColor.a = 0
    btn.backgroundColorMouseOver.a = 0.7
    panel:addChild(btn)
    panel.paradiseHelpButton = btn
end

ParadiseManual.Panel = ISCollapsableWindow:derive("ParadiseManual.Panel")

function ParadiseManual.Panel:new(x, y, width, height)
    local panel = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.title = "Paradise Manual"
    panel.resizable = false
    panel.index = 1
    panel.pages = ParadiseManual.getPages(ParadiseManual.isAdmin())
    return panel
end

function ParadiseManual.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)

    self.btnHome = ISButton:new(SIDE_MARGIN, self.height - 38, 64, 26, "Home", self, ParadiseManual.Panel.onClick)
    self.btnHome.internal = "HOME"
    self.btnHome:initialise()
    self.btnHome:instantiate()
    self:addChild(self.btnHome)

    self.btnContents = ISButton:new(SIDE_MARGIN + 68, self.height - 38, 88, 26, "Contents", self, ParadiseManual.Panel.onClick)
    self.btnContents.internal = "CONTENTS"
    self.btnContents:initialise()
    self.btnContents:instantiate()
    self:addChild(self.btnContents)

    self.btnPrev = ISButton:new(self.width - SIDE_MARGIN - 144, self.height - 38, 70, 26, "< Prev", self, ParadiseManual.Panel.onClick)
    self.btnPrev.internal = "PREV"
    self.btnPrev:initialise()
    self.btnPrev:instantiate()
    self:addChild(self.btnPrev)

    self.btnNext = ISButton:new(self.width - SIDE_MARGIN - 70, self.height - 38, 70, 26, "Next >", self, ParadiseManual.Panel.onClick)
    self.btnNext.internal = "NEXT"
    self.btnNext:initialise()
    self.btnNext:instantiate()
    self:addChild(self.btnNext)

    local top = self:titleBarHeight()
    self.tocList = ISScrollingListBox:new(SIDE_MARGIN, top + 8, self.width - SIDE_MARGIN * 2, self.height - top - BOTTOM_BAR - SIDE_MARGIN)
    self.tocList:initialise()
    self.tocList:instantiate()
    self.tocList.font = UIFont.Small
    self.tocList.fontHgt = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()
    self.tocList.itemPadY = 3
    self.tocList.itemheight = self.tocList.fontHgt + 6
    self.tocList.backgroundColor = { r = 0.04, g = 0.07, b = 0.07, a = 0.98 }
    self.tocList.selectionColor = { r = 0.2, g = 0.6, b = 0.5, a = 0.35 }
    self.tocList:setOnMouseDownFunction(self, ParadiseManual.Panel.onTocClick)
    self.tocList:setVisible(false)
    self:addChild(self.tocList)
    self.tocOpen = false
    self:rebuildToc()
end

function ParadiseManual.Panel:rebuildToc()
    self.tocList:clear()
    self.tocItemByPage = {}
    local lastSection
    for i, page in ipairs(self.pages) do
        if page.section ~= lastSection then
            local header = self.tocList:addItem(page.label, { header = true })
            if page.section == "admin" then
                header.textColor = { r = 0.95, g = 0.65, b = 0.25, a = 1 }
            else
                header.textColor = { r = 0.35, g = 0.85, b = 0.65, a = 1 }
            end
            lastSection = page.section
        end
        local item = self.tocList:addItem(string.format("%02d   %s", page.num, ParadiseManual.pageTitle(page)), { pageIndex = i })
        self.tocItemByPage[i] = item
    end
end

function ParadiseManual.Panel:hideToc()
    self.tocOpen = false
    self.tocList:setVisible(false)
end

function ParadiseManual.Panel:toggleToc()
    self.tocOpen = not self.tocOpen
    self.tocList:setVisible(self.tocOpen)
    if self.tocOpen then
        local item = self.tocItemByPage[self.index]
        if item then
            self.tocList.selected = item.itemindex
            self.tocList:scrollToSelected()
        end
    end
end

function ParadiseManual.Panel:onTocClick(item)
    if not item or not item.pageIndex then return end
    self:setIndex(item.pageIndex)
    self:hideToc()
end

function ParadiseManual.Panel:onClick(button)
    if button.internal == "PREV" then
        self:setIndex(self.index - 1)
    elseif button.internal == "NEXT" then
        self:setIndex(self.index + 1)
    elseif button.internal == "HOME" then
        self:setIndex(1)
        self:hideToc()
    elseif button.internal == "CONTENTS" then
        self:toggleToc()
    end
end

function ParadiseManual.Panel:setIndex(index)
    if index < 1 or index > #self.pages then return end
    self.index = index
    setButtonEnabled(self.btnPrev, index > 1)
    setButtonEnabled(self.btnNext, index < #self.pages)
    if self.tocItemByPage and self.tocItemByPage[index] then
        self.tocList.selected = self.tocItemByPage[index].itemindex
    end
end

function ParadiseManual.Panel:showSection(section)
    self.pages = ParadiseManual.getPages(ParadiseManual.isAdmin())
    self:rebuildToc()
    self:hideToc()
    if section ~= "admin" or ParadiseManual.isAdmin() then
        self:setIndex(ParadiseManual.firstIndexOf(self.pages, section))
    else
        self:setIndex(1)
    end
end

function ParadiseManual.Panel:showPanelKey(key)
    local ref = ParadiseManual.PAGE_BY_KEY[key]
    self.pages = ParadiseManual.getPages(ParadiseManual.isAdmin())
    self:rebuildToc()
    self:hideToc()
    if not ref or (ref.section == "admin" and not ParadiseManual.isAdmin()) then
        self:setIndex(1)
        return
    end
    for i, page in ipairs(self.pages) do
        if page.section == ref.section and page.num == ref.num then
            self:setIndex(i)
            return
        end
    end
    self:setIndex(1)
end

function ParadiseManual.Panel:currentPage()
    return self.pages[self.index]
end

function ParadiseManual.Panel:pageTexture(page)
    if not page.texture then
        page.texture = getTexture(page.path)
    end
    return page.texture
end

function ParadiseManual.Panel:render()
    ISCollapsableWindow.render(self)
    local page = self:currentPage()
    if not page then return end

    local top = self:titleBarHeight()
    local tex = self:pageTexture(page)
    if tex then
        local size = math.min(self.width - SIDE_MARGIN * 2, self.height - top - BOTTOM_BAR - SIDE_MARGIN)
        self:drawTextureScaled(tex, math.floor((self.width - size) / 2), top + 8, size, size, 1, 1, 1, 1)
    end

    local barY = self.height - 22
    local str = page.label .. "  -  page " .. page.num .. " of " .. SETS[page.section].count
    local tw = getTextManager():MeasureStringX(UIFont.Small, str)
    local cx = math.floor((SIDE_MARGIN + 160 + self.width - SIDE_MARGIN - 148) / 2 - tw / 2)
    ParadiseManual.text(self, str, cx, barY, "text.muted")
end

function ParadiseManual.Panel:onClose()
    self:close()
end

function ParadiseManual.Panel:close()
    ParadiseManual.ClosePanel()
end
