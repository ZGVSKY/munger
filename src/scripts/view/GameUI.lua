-- src/scripts/view/GameUI.lua
local TurnManager = require("src.scripts.core.TurnManager")
local ActionManager = require("src.scripts.core.ActionManager")
local Logger = require("src.scripts.utils.logger")
local ScreenUtils = require("src.scripts.view.ScreenUtils")
local ToastManager = require("src.scripts.view.ToastManager")
local UIWindow = require("src.scripts.view.UIWindow")
local UITheme = require("src.scripts.config.UITheme")

local GameUI = {}
GameUI.__index = GameUI


--- ДОПОМІЖНА ФУНКЦІЯ: Перетворює будь-яку таблицю на читабельний текст
local function dumpData(obj, indent)
    indent = indent or ""
    -- Запобіжник від нескінченної рекурсії (глибина не більше 2 рівнів)
    if string.len(indent) > 4 then return "{...}" end 
    
    local str = ""
    for k, v in pairs(obj) do
        -- Пропускаємо системні поля та непотрібні функції
        if k ~= "view" and k ~= "mainGroup" and type(v) ~= "function" and type(v) ~= "userdata" then
            if type(v) == "table" then
                str = str .. indent .. tostring(k) .. ":\n" .. dumpData(v, indent .. "  ")
            else
                str = str .. indent .. tostring(k) .. ": " .. tostring(v) .. "\n"
            end
        end
    end
    return str
end

function GameUI.new(uiLayer, gameState)
    local self = setmetatable({}, GameUI)
    
    self.layer = uiLayer
    self.gameState = gameState
    ToastManager.init(self.layer)
    
    -- Базові відступи
    local pad = ScreenUtils.px(10)

    
    
    -- ==========================================
    -- 1. ВЕРХНЯ ЛІВА ПАНЕЛЬ (Ресурси)
    -- ==========================================
    self.resGroup = display.newGroup()
    self.layer:insert(self.resGroup)
    
    local resW, resH = ScreenUtils.px(120), ScreenUtils.px(100)
    local resBg = display.newRoundedRect(self.resGroup, ScreenUtils.safeX + pad + resW/2, ScreenUtils.safeY + pad + resH/2, resW, resH, ScreenUtils.px(12))
    UITheme.applyStyle(resBg)
    resBg:addEventListener("tap", function()
        self.resWindow:show()
        return true
    end)
    
    self.resTexts = {}
    self.resTextsdelta = {}
    local resTypes = {
        {id="gold", color={1, 0.8, 0}, label="G"},
        {id="wood", color={0.6, 0.4, 0.2}, label="W"},
        {id="stone", color={0.6, 0.6, 0.6}, label="S"},
        {id="food", color={0.2, 0.8, 0.2}, label="F"}
    }
    
    for i, res in ipairs(resTypes) do
        local yPos = resBg.y - resH/2 + ScreenUtils.px(15) + (i-1) * ScreenUtils.px(22)
        -- Іконка-заглушка
        local icon = display.newImageRect( self.resGroup, "src/assets/interface/"..res.id..".png", ScreenUtils.px(24), ScreenUtils.px(24) )
        icon.x = ScreenUtils.px(25)
        icon.y = yPos
        --icon:setFillColor(unpack(res.color))
        
        -- Текст (Поточне значення + Дельта)
        self.resTexts[res.id] = display.newText({
            parent = self.resGroup,
            text = "0  ",
            x = icon.x + ScreenUtils.px(15),
            y = yPos,
            font = UITheme.fontMain,
            fontSize = ScreenUtils.px(16)
        })
        self.resTextsdelta[res.id] = display.newText({
            parent = self.resGroup,
            text = " +0",
            x = icon.x + ScreenUtils.px(10) + self.resTexts[res.id].x,
            y = yPos,
            font = UITheme.fontMain,
            fontSize = ScreenUtils.px(16)
        })
        self.resTexts[res.id].anchorX = 0 -- Вирівнювання по лівому краю
        self.resTextsdelta[res.id].anchorX = 0
        self.resTextsdelta[res.id]:setFillColor(0.5)
    end

    -- ==========================================
    -- 2. ВЕРХНЯ ЦЕНТРАЛЬНА (Гравець і Таймер)
    -- ==========================================
    self.topCenterGroup = display.newGroup()
    self.layer:insert(self.topCenterGroup)
    
    local tcW, tcH = ScreenUtils.px(120), ScreenUtils.px(30)
    local tcBg = display.newRoundedRect(self.topCenterGroup, display.contentCenterX, ScreenUtils.safeY + pad + tcH/2, tcW, tcH, ScreenUtils.px(10))
    UITheme.applyStyle(tcBg)

    self.topCenterGroup:addEventListener("tap", function()
        self.playerWindow:show()
        return true
    end)
    
    self.playerNameText = display.newText({
        
        parent = self.topCenterGroup, text = "Player 1",
        x = tcBg.x - ScreenUtils.px(20), y = tcBg.y,
        font = UITheme.fontMain, fontSize = ScreenUtils.px(16)
    })
    
    self.timerText = display.newText({
        parent = self.topCenterGroup, text = "2:00",
        x = tcBg.x + ScreenUtils.px(40), y = tcBg.y,
        font = UITheme.fontMain, fontSize = ScreenUtils.px(16)
    })

    -- ==========================================
    -- 3. ПРАВА ВЕРХНЯ (Пауза та DEV)
    -- ==========================================
    local btnSize = ScreenUtils.px(40)
    
    -- Кнопка Паузи
    self.pauseBtn = display.newRoundedRect(self.layer, ScreenUtils.safeX + ScreenUtils.safeWidth - pad - btnSize/2, ScreenUtils.safeY + pad + btnSize/2, btnSize, btnSize, ScreenUtils.px(8))
    UITheme.applyStyle(self.pauseBtn)
    display.newText(self.layer, "||", self.pauseBtn.x, self.pauseBtn.y, UITheme.fontMain, ScreenUtils.px(18))
    
    self.pauseBtn:addEventListener("tap", function()
        self.gameState.isPaused = true
        self.pauseWindow:show()
        return true
    end)
    
    -- Кнопка DEV (під паузою)
    self.devBtn = display.newRoundedRect(self.layer, self.pauseBtn.x, self.pauseBtn.y + btnSize + pad, btnSize, btnSize, ScreenUtils.px(8))
    UITheme.applyStyle(self.devBtn)
    display.newText(self.layer, "DEV", self.devBtn.x, self.devBtn.y, UITheme.fontMain, ScreenUtils.px(14))
    
    self.devBtn:addEventListener("tap", function()
        self.debugWindow.container.isVisible = not self.debugWindow.container.isVisible
        return true
    end)

    -- ==========================================
    -- 4. НИЖНЯ ПАНЕЛЬ (Дії та Кінець Ходу)
    -- ==========================================
    self.bottomGroup = display.newGroup()
    self.layer:insert(self.bottomGroup)
    
    local botH = ScreenUtils.px(50)
    local absoluteBottom = display.actualContentHeight
    
    -- 2. Беремо звичайний відступ від краю
    local bottomMargin = ScreenUtils.px(10)
    
    -- 3. Рахуємо Y координату: Низ екрану МІНУС відступ МІНУС половина висоти панелі (бо малюємо від центру)
    local panelY = absoluteBottom - bottomMargin - (botH)
    
    local botBg = display.newRoundedRect(
        self.bottomGroup, 
        display.contentCenterX, 
        panelY, 
        ScreenUtils.safeWidth - pad*2, 
        botH, 
        ScreenUtils.px(UITheme.cornerRadius)
    )
    UITheme.applyStyle(botBg)
    botBg:addEventListener("touch", function() return true end)
    
    local actionButtons = {
        { label = "U", color = {0.8, 0.3, 0.3}, mode = "spawn_unit", data = {id = "warrior_lvl1", name = "Lvl 1 Warrior", cost = 50} },
        { label = "R", color = {0.3, 0.8, 0.3}, mode = "build_resource", data = {id = "farm_lvl1", name = "Lvl 1 Farm", cost = 100} },
        { label = "D", color = {0.3, 0.3, 0.8}, mode = "build_defense", data = {id = "tower_lvl1", name = "Defense Tower", cost = 150} }
    }

    for i, btnConf in ipairs(actionButtons) do
        local actionBtn = display.newCircle(self.bottomGroup, botBg.x - botBg.width/2 + ScreenUtils.px(40) + (i-1)*ScreenUtils.px(60), botBg.y, ScreenUtils.px(20))
        actionBtn:setFillColor(unpack(btnConf.color))
        
        -- Додаємо літеру на кнопку для наочності (U, R, D)
        display.newText(self.bottomGroup, btnConf.label, actionBtn.x, actionBtn.y, UITheme.fontMain, ScreenUtils.px(16))
        
        actionBtn:addEventListener("tap", function()
            -- Передаємо режим в ActionManager
            ActionManager.setMode(btnConf.mode, btnConf.data)
            return true
        end)
    end
    
    -- ВЕЛИКА КНОПКА "КІНЕЦЬ ХОДУ" (справа)
    self.endTurnBtn = display.newRoundedRect(self.bottomGroup, botBg.x + botBg.width/2 - ScreenUtils.px(50), botBg.y, ScreenUtils.px(80), botH - ScreenUtils.px(10), ScreenUtils.px(10))
    self.endTurnBtn:setFillColor(0.1); self.endTurnBtn.alpha = 0.3;
    display.newText(self.bottomGroup, "END >>", self.endTurnBtn.x, self.endTurnBtn.y, UITheme.fontMain, ScreenUtils.px(18))
    
    self.endTurnBtn:addEventListener("tap", function()
        TurnManager.nextTurn(self.gameState)
        self:update()
        local activeP = self.gameState:getCurrentPlayer()
        ToastManager.show(activeP.name .. "'s Turn", activeP.color)
        return true
    end)

    -- ==========================================
    -- 5. ПАНЕЛЬ ІНФО ПРО ОБ'ЄКТ (Під ресурсами)
    -- ==========================================
    self.infoGroup = display.newGroup()
    self.layer:insert(self.infoGroup)
    
    local infoW, infoH = ScreenUtils.px(120), ScreenUtils.px(120)
    self.infoBg = display.newRoundedRect(self.infoGroup,  ScreenUtils.safeX + pad + resW/2, resBg.y + resH/2 + pad + infoH/2, infoW, infoH, ScreenUtils.px(12))
    UITheme.applyStyle(self.infoBg)
    self.infoBg:addEventListener("touch", function() return true end)
    
    self.infoTitle = display.newText(self.infoGroup, "SELECT TILE", self.infoBg.x - infoW/2 + pad, self.infoBg.y - infoH/2 + pad, UITheme.fontMain, ScreenUtils.px(16))
    self.infoTitle.anchorX = 0
    
    self.infoDesc = display.newText(self.infoGroup, "HP: --\nMoves: --", self.infoTitle.x, self.infoTitle.y + ScreenUtils.px(30), UITheme.fontMain, ScreenUtils.px(14))
    self.infoDesc.anchorX = 0
    
    -- Кнопка закриття панелі інфо
    local closeInfoBtn = display.newText(self.infoGroup, "X", self.infoBg.x + infoW/2 - ScreenUtils.px(15), self.infoTitle.y, UITheme.fontMain, ScreenUtils.px(16))
    closeInfoBtn:setFillColor(0.8, 0.2, 0.2)
    closeInfoBtn:addEventListener("tap", function()
        self.infoGroup.isVisible = false
        return true
    end)
    
    self.infoGroup.isVisible = false -- Ховаємо до кліку

    -- ==========================================
    -- 6. НОВІ ДЕБАГ ВІКНА (Perf, Player, GameState)
    -- ==========================================
    self.perfWindow = UIWindow.new({ parent = self.layer, x = ScreenUtils.safeX + ScreenUtils.px(100), y = display.contentCenterY, width = ScreenUtils.px(200), height = ScreenUtils.px(150), title = "Performance", can_change = true, closeOnOutside = false })
    self.perfText = display.newText({ parent = self.perfWindow.contentGroup, text = "Loading...", x = 0, y = 100, font = native.systemFont, fontSize = ScreenUtils.px(14) })
    
    self.pStateWindow = UIWindow.new({ parent = self.layer, x = display.contentCenterX, y = display.contentCenterY, width = ScreenUtils.px(180), height = ScreenUtils.px(800), title = "Player State", can_change = true, closeOnOutside = false })
    self.pStateText = display.newText({ parent = self.pStateWindow.contentGroup, text = "", x = 0, y = 600, font = native.systemFont, fontSize = ScreenUtils.px(12) })
    
    self.gStateWindow = UIWindow.new({ parent = self.layer, x = display.contentCenterX, y = display.contentCenterY, width = ScreenUtils.px(220), height = ScreenUtils.px(400), title = "Game State", can_change = true, closeOnOutside = false })
    self.gStateText = display.newText({ parent = self.gStateWindow.contentGroup, text = "", x = 0, y = 100, font = native.systemFont, fontSize = ScreenUtils.px(12) })

    -- Логіка для FPS та Пам'яті
    local lastTime = system.getTimer()
    local frames = 0
    local fps = 60
    Runtime:addEventListener("enterFrame", function()
        if not self.perfWindow.container.isVisible then return end
        frames = frames + 1
        local curTime = system.getTimer()
        if curTime - lastTime >= 1000 then
            fps = frames
            frames = 0
            lastTime = curTime
        end
        local memUsed = collectgarbage("count") / 1000
        local texUsed = system.getInfo("textureMemoryUsed") / 1000000
        self.perfText.text = string.format("FPS: %d\nRAM: %.2f MB\nVRAM: %.2f MB", fps, memUsed, texUsed)
    end)

    -- ==========================================
    -- 7. ГОЛОВНЕ ДЕБАГ МЕНЮ 
    -- ==========================================
    self.debugWindow = UIWindow.new({ parent = self.layer, x = display.contentCenterX, y = display.contentCenterY, width = ScreenUtils.px(280), height = ScreenUtils.px(400), title = "Developer Menu", can_change = true, closeOnOutside = true })

    local startY = ScreenUtils.px(120)
    local stepY = ScreenUtils.px(45)

    local function createCheatBtn(label, yPos, onClick)
        local btn = display.newRect(self.debugWindow.contentGroup, 0, yPos, ScreenUtils.px(240), ScreenUtils.px(35))
        btn:setFillColor(0.2, 0.5, 0.7)
        display.newText(self.debugWindow.contentGroup, label, btn.x, btn.y, UITheme.fontMain, ScreenUtils.px(16))
        btn:addEventListener("tap", function() onClick(); self:update(); return true end)
    end

    createCheatBtn("+ ALL Resources", startY, function()
        local p = self.gameState:getCurrentPlayer()
        p:addResource("gold", 5000); p:addResource("wood", 5000)
        p:addResource("stone", 5000); p:addResource("food", 5000)
        ToastManager.show("5000 of ALL added!", {0.8, 0.8, 0.2})
    end)

    createCheatBtn("Toggle Perf. Stats", startY + stepY, function()
        if self.perfWindow.container.isVisible then self.perfWindow:hide() else self.perfWindow:show() end
    end)

    createCheatBtn("Show Player State", startY + stepY * 2, function()
        local p = self.gameState:getCurrentPlayer()
        self.pStateText.text = dumpData(p)
        self.pStateWindow:show()
    end)

    createCheatBtn("Show Game State", startY + stepY * 3, function()
        -- Показуємо загальну інфу про гру, без гравців (щоб текст вліз)
        local info = { turn = self.gameState.currentTurn, activePlayerIdx = self.gameState.currentPlayerIndex, totalPlayers = #self.gameState.players }
        self.gStateText.text = dumpData(info)
        self.gStateWindow:show()
    end)

    createCheatBtn("Next Turn", startY + stepY * 4, function()
        TurnManager.nextTurn(self.gameState)
        ToastManager.show("Turn Forced", {0.8, 0.2, 0.2})
    end)

    -- ==========================================
    -- 8. МЕНЮ ПАУЗИ ТА ВИХОДУ
    -- ==========================================
    self.pauseWindow = UIWindow.new({ 
        parent = self.layer, 
        x = display.contentCenterX, y = display.contentCenterY, 
        width = ScreenUtils.px(260), height = ScreenUtils.px(320), 
        title = "GAME PAUSED", 
        can_change = false,      -- Забороняємо рухати
        isModal = true,          -- Затемнює екран і блокує кліки
        closeOnOutside = false,  -- Забороняємо закривати кліком повз
        hideCloseBtn = true      -- Ховаємо Хрестик
    })

    local pStartY = ScreenUtils.px(60)
    local pStepY = ScreenUtils.px(65)

    -- Функція для генерації красивих кнопок меню
    local function createMenuBtn(label, yPos, color, onClick)
        local btn = display.newRoundedRect(self.pauseWindow.contentGroup, 0, yPos, ScreenUtils.px(200), ScreenUtils.px(45), ScreenUtils.px(8))
        btn:setFillColor(unpack(color))
        btn.strokeWidth = ScreenUtils.px(2)
        btn:setStrokeColor(0.1, 0.1, 0.1)
        
        display.newText(self.pauseWindow.contentGroup, label, btn.x, btn.y, UITheme.fontMain, ScreenUtils.px(18))
        btn:addEventListener("tap", function() onClick(); return true end)
    end

    -- Кнопка 1: Продовжити
    createMenuBtn("Resume Game", pStartY, {0.2, 0.6, 0.3}, function()
        self.gameState.isPaused = false
        self.pauseWindow:hide()
    end)

    -- Кнопка 2: Налаштування
    createMenuBtn("Settings", pStartY + pStepY, {0.4, 0.4, 0.45}, function()
        ToastManager.show("Settings (Coming Soon)", {0.5, 0.5, 0.5})
    end)

    -- Кнопка 3: Вийти в головне меню
    createMenuBtn("Quit to Menu", pStartY + pStepY * 2, {0.8, 0.2, 0.2}, function()
        local composer = require("composer")
        
        -- Очищаємо посилання на гру, щоб збирач сміття (GC) міг усе видалити
        self.gameState = nil
        
        -- переход сцени головного меню 
        composer.gotoScene("src.scenes.test_load_scene", { effect = "crossFade", time = 300 })
    end)

    self.resWindow = UIWindow.new({ parent = self.resGroup, x = ScreenUtils.safeX + ScreenUtils.px(100), y = display.contentCenterY, width = ScreenUtils.px(200), height = ScreenUtils.px(150), title = "resurces", can_change = true, closeOnOutside = false })
    self.playerWindow = UIWindow.new({ parent = self.topCenterGroup, x = display.contentCenterX, y = display.contentCenterY, width = ScreenUtils.px(200), height = ScreenUtils.px(200), title = "Players Stats", can_change = true, closeOnOutside = false })
    self:update()
    return self
end

--- Оновлює верхню панель ресурсів
function GameUI:update()
    local p = self.gameState:getCurrentPlayer()
    
    -- Оновлюємо ім'я та колір
    -- ОБРІЗКА ТЕКСТУ 
    local displayName = p.name
    
    -- Перевіряємо довжину рядка. Якщо більше ліміту - обрізаємо і додаємо ...
    if string.len(displayName) > UITheme.maxNameLength then
        displayName = string.sub(displayName, 1, UITheme.maxNameLength - 2) .. "..."
    end
    
    self.playerNameText.text = displayName
    self.playerNameText:setFillColor(unpack(p.color))
    self.playerNameText:setFillColor(unpack(p.color))
    
    -- Оновлюємо ресурси та їх дельти
    local resources = {"gold", "wood", "stone", "food"}
    for _, res in ipairs(resources) do
        local current = p.resources[res]
        local delta = p.resourceDeltas[res]
        
        local sign = delta >= 0 and "+" or ""
        self.resTexts[res].text = string.format("%d  ", current)
        self.resTextsdelta[res].text = string.format(" %s%.1f", sign, delta)
        
        -- Якщо дельта мінусова - підсвічуємо червоним (Опціональна краса)
        if delta < 0 then
            self.resTextsdelta[res]:setFillColor(1, 0.4, 0.4)
        else
            self.resTextsdelta[res]:setFillColor(0.5)
        end
    end
end

--- Показує інформацію про вибрану клітинку
function GameUI:showTileInfo(gridX, gridY, cellData)
    self.infoGroup.isVisible = true
    
    if not cellData then 
        self.infoTitle.text = "OUT OF BOUNDS"
        self.infoDesc.text = ""
        return 
    end
    
    local typeName = cellData.biome and cellData.biome.gameplay or "unknown"
    self.infoTitle.text = string.upper(typeName) .. " [" .. gridX .. "," .. gridY .. "]"
    
    local desc = ""
    if cellData.ownerId then desc = desc .. "Owner: Player " .. cellData.ownerId .. "\n" end
    if cellData.buildingId then desc = desc .. "Building ID: " .. cellData.buildingId .. "\n" end
    if cellData.unitId then desc = desc .. "Unit ID: " .. cellData.unitId .. "\n" end
    
    if desc == "" then desc = "Empty tile" end
    self.infoDesc.text = desc
end

return GameUI