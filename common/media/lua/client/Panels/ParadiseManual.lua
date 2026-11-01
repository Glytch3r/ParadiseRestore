require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"

ParadiseManual = ParadiseManual or {}

local PAGE_SIZE = 512
local SIDE_MARGIN = 12
local BOTTOM_BAR = 44

local SETS = {
    player = { dir = "media/textures/ParadiseManual/Player/", count = 8,  label = "Player Guide" },
    admin  = { dir = "media/textures/ParadiseManual/Admin/",  count = 12, label = "Admin Guide" },
}

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

    self.btnPrev = ISButton:new(SIDE_MARGIN, self.height - 38, 90, 26, "< Prev", self, ParadiseManual.Panel.onClick)
    self.btnPrev.internal = "PREV"
    self.btnPrev:initialise()
    self.btnPrev:instantiate()
    self:addChild(self.btnPrev)

    self.btnNext = ISButton:new(self.width - SIDE_MARGIN - 90, self.height - 38, 90, 26, "Next >", self, ParadiseManual.Panel.onClick)
    self.btnNext.internal = "NEXT"
    self.btnNext:initialise()
    self.btnNext:instantiate()
    self:addChild(self.btnNext)
end

function ParadiseManual.Panel:onClick(button)
    if button.internal == "PREV" then
        self:setIndex(self.index - 1)
    elseif button.internal == "NEXT" then
        self:setIndex(self.index + 1)
    end
end

function ParadiseManual.Panel:setIndex(index)
    if index < 1 or index > #self.pages then return end
    self.index = index
    setButtonEnabled(self.btnPrev, index > 1)
    setButtonEnabled(self.btnNext, index < #self.pages)
end

function ParadiseManual.Panel:showSection(section)
    self.pages = ParadiseManual.getPages(ParadiseManual.isAdmin())
    if section ~= "admin" or ParadiseManual.isAdmin() then
        self:setIndex(ParadiseManual.firstIndexOf(self.pages, section))
    else
        self:setIndex(1)
    end
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
    ParadiseManual.text(self, page.label, SIDE_MARGIN + 100, barY, "accent.primary")
    ParadiseManual.text(self, "page " .. page.num .. " of " .. SETS[page.section].count, math.floor(self.width / 2) - 40, barY, "text.muted")
end

function ParadiseManual.Panel:onClose()
    self:close()
end

function ParadiseManual.Panel:close()
    ParadiseManual.ClosePanel()
end
