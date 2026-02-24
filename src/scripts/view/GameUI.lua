-- src/scripts/view/GameUI.lua
local TurnManager = require("src.scripts.core.TurnManager")
local Logger = require("src.scripts.utils.logger")
local ScreenUtils = require("src.scripts.view.ScreenUtils")
local ToastManager = require("src.scripts.view.ToastManager")
local UIWindow = require("src.scripts.view.UIWindow")

local GameUI = {}
GameUI.__index = GameUI

function GameUI.new(uiLayer, gameState)
    local self = setmetatable({}, GameUI)
    
    self.layer = uiLayer
    self.gameState = gameState
    
    -- Ініціалізуємо менеджер повідомлень
    ToastManager.init(self.layer)
    
    -- ==========================================
    -- 1. ВЕРХНЯ ПАНЕЛЬ РЕСУРСІВ (Статична)
    -- ==========================================
    local topBarH = ScreenUtils.px(60)
    
    self.topBar = display.newRect(self.layer, display.contentCenterX, ScreenUtils.safeY + topBarH/2, ScreenUtils.safeWidth, topBarH)
    self.topBar:setFillColor(0.1, 0.1, 0.1, 0.95)
    self.topBar:addEventListener("touch", function() return true end)
    self.topBar:addEventListener("tap", function() return true end)
    
    self.resourceText = display.newText({
        parent = self.layer,
        text = "Loading...",
        x = display.contentCenterX,
        y = self.topBar.y,
        font = native.systemFontBold,
        fontSize = ScreenUtils.px(20)
    })
    
    -- Кнопка "DEV" (Відкриває вікно)
    local devBtnW = ScreenUtils.px(80)
    local devBtnH = ScreenUtils.px(40)
    local devBtn = display.newRect(self.layer, ScreenUtils.safeX + ScreenUtils.safeWidth - devBtnW/2 - ScreenUtils.px(10), self.topBar.y, devBtnW, devBtnH)
    devBtn:setFillColor(0.8, 0.2, 0.2)
    display.newText(self.layer, "DEV", devBtn.x, devBtn.y, native.systemFontBold, ScreenUtils.px(16))
    
    devBtn:addEventListener("tap", function()
        if self.debugWindow.view.isVisible then
            self.debugWindow:hide()
        else
            self.debugWindow:show()
        end
        return true
    end)

    -- ==========================================
    -- 2. НИЖНЯ ПАНЕЛЬ ІНФО (Статична)
    -- ==========================================
    local botBarH = ScreenUtils.px(50)
    self.bottomBar = display.newRect(self.layer, display.contentCenterX, ScreenUtils.safeY + ScreenUtils.safeHeight - botBarH/2, ScreenUtils.safeWidth, botBarH)
    self.bottomBar:setFillColor(0.1, 0.1, 0.1, 0.95)
    self.bottomBar:addEventListener("touch", function() return true end)
    self.bottomBar:addEventListener("tap", function() return true end)
    
    self.infoText = display.newText({
        parent = self.layer,
        text = "Select a tile...",
        x = display.contentCenterX,
        y = self.bottomBar.y,
        font = native.systemFont,
        fontSize = ScreenUtils.px(18)
    })

    -- ==========================================
    -- 3. ВІКНО РОЗРОБНИКА (Плаваюче, can_change = true)
    -- ==========================================
    self.debugWindow = UIWindow.new({
        parent = self.layer,
        x = display.contentCenterX,
        y = display.contentCenterY,
        width = ScreenUtils.px(300),
        height = ScreenUtils.px(400),
        title = "Developer Menu",
        can_change = true
    })
    self.debugWindow:hide()

    -- Додаємо кнопки всередину contentGroup нашого вікна!
    local startY = ScreenUtils.px(30)
    local stepY = ScreenUtils.px(60)

    local function createCheatBtn(label, yPos, onClick)
        local btn = display.newRect(self.debugWindow.contentGroup, 0, yPos, ScreenUtils.px(240), ScreenUtils.px(40))
        btn:setFillColor(0.2, 0.6, 0.2)
        display.newText(self.debugWindow.contentGroup, label, btn.x, btn.y, native.systemFontBold, ScreenUtils.px(18))
        
        btn:addEventListener("tap", function()
            onClick()
            self:update()
            return true
        end)
    end

    createCheatBtn("+1000 Gold", startY, function()
        local p = self.gameState:getCurrentPlayer()
        p:addResource("gold", 1000)
        ToastManager.show("Added 1000 Gold to P" .. p.id, {0.8, 0.8, 0.2})
    end)

    createCheatBtn("+500 Wood & Stone", startY + stepY, function()
        local p = self.gameState:getCurrentPlayer()
        p:addResource("wood", 500)
        p:addResource("stone", 500)
        ToastManager.show("Added Wood & Stone!", {0.2, 0.8, 0.2})
    end)

    createCheatBtn("Next Turn", startY + stepY * 2, function()
        TurnManager.nextTurn(self.gameState)
        local p = self.gameState:getCurrentPlayer()
        ToastManager.show("Turn: Player " .. p.id, p.color)
    end)

    self:update()
    return self
end

function GameUI:update()
    local p = self.gameState:getCurrentPlayer()
    local text = string.format("P%d | G:%d | W:%d | S:%d | F:%d", 
        p.id, p.resources.gold, p.resources.wood, p.resources.stone, p.resources.food)
    self.resourceText.text = text
    self.resourceText:setFillColor(unpack(p.color))
end

function GameUI:showTileInfo(gridX, gridY, cellData)
    if not cellData then return end
    local typeName = cellData.biome and cellData.biome.gameplay or "unknown"
    local ownerStr = cellData.ownerId and (" | P" .. cellData.ownerId) or ""
    local bldStr = cellData.buildingId and (" | Bld: " .. cellData.buildingId) or ""
    self.infoText.text = string.format("[%d, %d] %s%s%s", gridX, gridY, string.upper(typeName), ownerStr, bldStr)
end

return GameUI