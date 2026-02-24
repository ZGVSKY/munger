-- src/scripts/view/UIWindow.lua
local ScreenUtils = require("src.scripts.view.ScreenUtils")

local UIWindow = {}
UIWindow.__index = UIWindow

--- Конструктор вікна
-- @param params Таблиця параметрів: parent, x, y, width, height, title, can_change, onClose
function UIWindow.new(params)
    local self = setmetatable({}, UIWindow)
    
    self.parent = params.parent
    self.can_change = params.can_change or false
    
    -- Головна група вікна
    self.view = display.newGroup()
    if self.parent then self.parent:insert(self.view) end
    self.view.x = params.x
    self.view.y = params.y
    
    -- 1. Фон вікна
    self.bg = display.newRoundedRect(self.view, 0, 0, params.width, params.height, ScreenUtils.px(12))
    self.bg:setFillColor(0.1, 0.1, 0.15, 0.95)
    self.bg.strokeWidth = ScreenUtils.px(2)
    self.bg:setStrokeColor(0.3, 0.3, 0.4, 1)
    
    -- Блокуємо кліки крізь фон
    self.bg:addEventListener("touch", function() return true end)
    self.bg:addEventListener("tap", function() return true end)

    -- 2. Заголовок (Title Bar)
    local titleHeight = ScreenUtils.px(40)
    self.titleBar = display.newRect(self.view, 0, -params.height/2 + titleHeight/2, params.width, titleHeight)
    self.titleBar:setFillColor(0.15, 0.15, 0.2, 1)
    
    self.titleText = display.newText({
        parent = self.view,
        text = params.title or "Window",
        x = 0,
        y = self.titleBar.y,
        font = native.systemFontBold,
        fontSize = ScreenUtils.px(18)
    })

    -- 3. Кнопка закриття (Х)
    local closeBtnSize = ScreenUtils.px(30)
    self.closeBtn = display.newRect(self.view, params.width/2 - closeBtnSize/2 - ScreenUtils.px(5), self.titleBar.y, closeBtnSize, closeBtnSize)
    self.closeBtn:setFillColor(0.8, 0.2, 0.2)
    
    local closeText = display.newText({
        parent = self.view,
        text = "X",
        x = self.closeBtn.x, y = self.closeBtn.y,
        font = native.systemFontBold,
        fontSize = ScreenUtils.px(16)
    })
    
    self.closeBtn:addEventListener("tap", function()
        if params.onClose then params.onClose() end
        self:hide()
        return true
    end)

    -- 4. Група для контенту (кнопок, тексту)
    self.contentGroup = display.newGroup()
    self.view:insert(self.contentGroup)
    -- Зміщуємо контент під заголовок, щоб зручніше було рахувати координати
    self.contentGroup.y = self.titleBar.y + titleHeight/2

    -- 5. Логіка перетягування (Drag & Drop), якщо can_change = true
    if self.can_change then
        self.titleBar:addEventListener("touch", function(event)
            if event.phase == "began" then
                display.getCurrentStage():setFocus(self.titleBar)
                self.titleBar.isFocus = true
                -- Запам'ятовуємо різницю між точкою кліку і центром вікна
                self.markX = self.view.x - event.x
                self.markY = self.view.y - event.y
                -- Витягуємо вікно на передній план при кліку
                self.view:toFront()
            elseif self.titleBar.isFocus then
                if event.phase == "moved" then
                    local targetX = event.x + self.markX
                    local targetY = event.y + self.markY
                    
                    -- Ліміти (Clamp), щоб вікно не витягнули за межі екрану
                    local halfW, halfH = params.width/2, params.height/2
                    if targetX - halfW < ScreenUtils.safeX then targetX = ScreenUtils.safeX + halfW end
                    if targetX + halfW > ScreenUtils.safeX + ScreenUtils.safeWidth then targetX = ScreenUtils.safeX + ScreenUtils.safeWidth - halfW end
                    if targetY - halfH < ScreenUtils.safeY then targetY = ScreenUtils.safeY + halfH end
                    if targetY + halfH > ScreenUtils.safeY + ScreenUtils.safeHeight then targetY = ScreenUtils.safeY + ScreenUtils.safeHeight - halfH end
                    
                    self.view.x = targetX
                    self.view.y = targetY
                elseif event.phase == "ended" or event.phase == "cancelled" then
                    display.getCurrentStage():setFocus(nil)
                    self.titleBar.isFocus = false
                end
            end
            return true
        end)
    end

    return self
end

function UIWindow:show()
    self.view.isVisible = true
    self.view:toFront()
end

function UIWindow:hide()
    self.view.isVisible = false
end

return UIWindow