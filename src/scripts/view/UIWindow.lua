-- src/scripts/view/UIWindow.lua
local ScreenUtils = require("src.scripts.view.ScreenUtils")
local UITheme = require("src.scripts.config.UITheme")

local UIWindow = {}
UIWindow.__index = UIWindow

function UIWindow.new(params)
    local self = setmetatable({}, UIWindow)
    
    self.parent = params.parent
    self.can_change = params.can_change or false
    
    -- 1. НАЙГОЛОВНІШИЙ КОНТЕЙНЕР (саме його ми будемо ховати/показувати)
    self.container = display.newGroup()
    if self.parent then self.parent:insert(self.container) end

    if params.closeOnOutside or params.isModal then
        self.overlayBg = display.newRect(self.container, display.contentCenterX, display.contentCenterY, display.actualContentWidth + 100, display.actualContentHeight + 100)
        
        self.overlayBg:setFillColor(0, 0, 0, 0.6) 
        
        self.overlayBg:addEventListener("touch", function() return true end) 
        
        if params.closeOnOutside then
            self.overlayBg:addEventListener("tap", function() 
                if params.onClose then params.onClose() end
                self:hide()
                return true 
            end)
        else
            -- Якщо це суворе модальне вікно, просто блокуємо тапи, щоб вони не йшли на карту
            self.overlayBg:addEventListener("tap", function() return true end)
        end
    end

    -- 3. ГРУПА САМОГО ВІКНА (лежить ПОВЕРХ затемнення)
    self.windowGroup = display.newGroup()
    self.container:insert(self.windowGroup)
    self.windowGroup.x = params.x
    self.windowGroup.y = params.y
    
    -- 4. Фон вікна
    self.bg = display.newRoundedRect(self.windowGroup, 0, 0, params.width, params.height, ScreenUtils.px(UITheme.cornerRadius))
    UITheme.applyStyle(self.bg)
    self.bg:addEventListener("touch", function() return true end)
    self.bg:addEventListener("tap", function() return true end)

    -- 5. Заголовок (Title Bar)
    local titleHeight = ScreenUtils.px(40)
    self.titleBar = display.newRoundedRect(self.windowGroup, 0, -params.height/2 + titleHeight/2, params.width, titleHeight, ScreenUtils.px(UITheme.cornerRadius))
    self.titleBar:setFillColor(0.15, 0.15, 0.2, 0.4)
    
    self.titleText = display.newText({
        parent = self.windowGroup,
        text = params.title or "Window",
        x = 0, y = self.titleBar.y,
        font = UITheme.fontMain,
        fontSize = ScreenUtils.px(18)
    })

    -- 6. Кнопка закриття (Х)
    local closeBtnSize = ScreenUtils.px(30)
    self.closeBtn = display.newRect(self.windowGroup, params.width/2 - closeBtnSize/2 - ScreenUtils.px(5), self.titleBar.y, closeBtnSize, closeBtnSize)
    self.closeBtn:setFillColor(0.8, 0.2, 0.2, 0.01)
    
    self.closeText = display.newText({
        parent = self.windowGroup, text = "X",
        x = self.closeBtn.x, y = self.closeBtn.y,
        font = UITheme.fontMain, fontSize = ScreenUtils.px(16)
    })
    
    self.closeBtn:addEventListener("tap", function()
        if params.onClose then params.onClose() end
        self:hide()
        return true
    end)

    -- НОВЕ: Можливість приховати хрестик
    if params.hideCloseBtn then
        self.closeBtn.isVisible = false
        self.closeText.isVisible = false
    end

    -- 7. Група для контенту
    self.contentGroup = display.newGroup()
    self.windowGroup:insert(self.contentGroup)
    self.contentGroup.y = self.titleBar.y + titleHeight/2

    -- 8. Логіка перетягування (Drag & Drop)
    if self.can_change then
        self.titleBar:addEventListener("touch", function(event)
            if event.phase == "began" then
                display.getCurrentStage():setFocus(self.titleBar)
                self.titleBar.isFocus = true
                self.markX = self.windowGroup.x - event.x
                self.markY = self.windowGroup.y - event.y
                self.container:toFront()
            elseif self.titleBar.isFocus then
                if event.phase == "moved" then
                    local targetX = event.x + self.markX
                    local targetY = event.y + self.markY
                    
                    local halfW, halfH = params.width/2, params.height/2
                    if targetX - halfW < ScreenUtils.safeX then targetX = ScreenUtils.safeX + halfW end
                    if targetX + halfW > ScreenUtils.safeX + ScreenUtils.safeWidth then targetX = ScreenUtils.safeX + ScreenUtils.safeWidth - halfW end
                    if targetY - halfH < ScreenUtils.safeY then targetY = ScreenUtils.safeY + halfH end
                    if targetY + halfH > ScreenUtils.safeY + ScreenUtils.safeHeight then targetY = ScreenUtils.safeY + ScreenUtils.safeHeight - halfH end
                    
                    self.windowGroup.x = targetX
                    self.windowGroup.y = targetY
                elseif event.phase == "ended" or event.phase == "cancelled" then
                    display.getCurrentStage():setFocus(nil)
                    self.titleBar.isFocus = false
                end
            end
            return true
        end)
    end

    -- ХОВАЄМО ВІКНО ПРИ СТВОРЕННІ
    self.container.isVisible = false

    return self
end

function UIWindow:show()
    self.container.isVisible = true
    self.container:toFront()
end

function UIWindow:hide()
    self.container.isVisible = false
end

return UIWindow