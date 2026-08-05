-- B42.20 adds ARF (Animation/Action Recording) to the debug sidebar.
-- It is not useful to ParadiseZ and currently throws an error when selected.
ParadiseDev = ParadiseDev or {}
ParadiseDev.hook = ParadiseDev.hook or {}

if not ParadiseDev.hook.ISEquippedItemInitialise then
    ParadiseDev.hook.ISEquippedItemInitialise = ISEquippedItem.initialise

    function ISEquippedItem:initialise()
        ParadiseDev.hook.ISEquippedItemInitialise(self)

        local arfBtn = self.arfBtn
        if not arfBtn then
            return
        end

        local removedY = arfBtn:getY()
        local removedHeight = arfBtn:getHeight() + 15 -- vanilla sidebar spacing: 10 + 5

        -- Remove the actual button and the corresponding tooltip hitbox.
        self:removeChild(arfBtn)
        if self.mouseOverList then
            for index = #self.mouseOverList, 1, -1 do
                if self.mouseOverList[index].object == arfBtn then
                    table.remove(self.mouseOverList, index)
                end
            end
        end

        -- The vanilla initializer has already positioned later sidebar controls.
        -- Move them up so removing ARF leaves neither a blank slot nor a dead tooltip.
        for _, child in ipairs(self.childrenInOrder or {}) do
            if child:getY() > removedY then
                child:setY(child:getY() - removedHeight)
            end
        end
        self:setHeight(math.max(0, self:getHeight() - removedHeight))
        self.arfBtn = nil
    end
end
