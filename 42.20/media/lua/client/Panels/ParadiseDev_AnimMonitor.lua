local UI_BORDER_SPACING = 10
local BUTTON_HGT = getTextManager():getFontHeight(UIFont.Small) + 6

ParadiseDev = ParadiseDev or {}
ParadiseDev.hook = ParadiseDev.hook or {}

ParadiseDev.hook.ISAnimDebugMonitor_createChildren = ISAnimDebugMonitor.createChildren
ParadiseDev.hook.ISAnimDebugMonitor_onClick = ISAnimDebugMonitor.onClick
ParadiseDev.hook.ISAnimDebugMonitor_update = ISAnimDebugMonitor.update


function ISAnimDebugMonitor:applyLogFilter(_text)
    if not self.filterAnimsOnly or not _text then return _text end

    local delim = _text:find("<LINE>", 1, true) and "<LINE>" or "\n"
    local out = {}

    for line in (_text .. delim):gmatch("(.-)" .. delim) do
        if line ~= "" and not (
            line:find("activated %->", 1, false) or
            line:find("deactivated %->", 1, false) or
            line:find("changed %->", 1, false) or
            line:find("chnaged %->", 1, false)
        ) then
            table.insert(out, line)
        end
    end

    return table.concat(out, delim)
end


function ISAnimDebugMonitor:createChildren()
    ParadiseDev.hook.ISAnimDebugMonitor_createChildren(self)

    local richtext = self.richtext
    local x = richtext:getX()
    local y = richtext:getY()
    local width = richtext:getWidth()
    local extraLogHeight = BUTTON_HGT * 8

    self.buttonFilterAnims = ISButton:new(
        x,
        y,
        width,
        BUTTON_HGT,
        "Hide Activated/Changed",
        self,
        ISAnimDebugMonitor.onClick
    )
    self.buttonFilterAnims.internal = "filter_anims_only"
    self.buttonFilterAnims:initialise()
    self.buttonFilterAnims:instantiate()
    self:addChild(self.buttonFilterAnims)

    richtext:setY(y + BUTTON_HGT + UI_BORDER_SPACING)
    richtext:setHeight(richtext:getHeight() + extraLogHeight)

    self:setHeight(
        richtext:getY() +
        richtext:getHeight() +
        UI_BORDER_SPACING +
        1
    )

    self.filterAnimsOnly = false
end


function ISAnimDebugMonitor:onClick(_button)
    if self.buttonFilterAnims == _button then
        self.filterAnimsOnly = not self.filterAnimsOnly
        self.buttonFilterAnims:toggleAcceptCancel(self.filterAnimsOnly)

        if self.monitor then
            self.richtext.text = self:applyLogFilter(self.monitor:getLogString())
            self.richtext:paginate()
            self:scrollToBottom()
        end

        return
    end

    ParadiseDev.hook.ISAnimDebugMonitor_onClick(self, _button)
end


function ISAnimDebugMonitor:update()
    ParadiseDev.hook.ISAnimDebugMonitor_update(self)

    if self.monitor and self.filterAnimsOnly then
        local filtered = self:applyLogFilter(self.monitor:getLogString())

        if filtered ~= self.richtext.text then
            self.richtext.text = filtered
            self.richtext:paginate()
            self:scrollToBottom()
        end
    end
end

ParadiseDev.Panels = ParadiseDev.Panels or {}
ParadiseDev.Panels.ISAnimDebugMonitor = ISAnimDebugMonitor.OnOpenPanel