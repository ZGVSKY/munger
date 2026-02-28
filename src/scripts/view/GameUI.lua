-- src/scripts/view/GameUI.lua
local TurnManager = require("src.scripts.core.TurnManager")
local ActionManager = require("src.scripts.core.ActionManager")
local Logger = require("src.scripts.utils.logger")
local ScreenUtils = require("src.scripts.view.ScreenUtils")
local ToastManager = require("src.scripts.view.ToastManager")
local UIWindow = require("src.scripts.view.UIWindow")
local UITheme = require("src.scripts.config.UITheme")
local rules = require("src.scripts.config.RulesConfig")

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

    -- Пред завантаження іконок
    icons = {
        gold = graphics.newTexture({ type = "image", filename = "src/assets/interface/gold.png" }),
        wood = graphics.newTexture({ type = "image", filename = "src/assets/interface/wood.png" }),
        stone = graphics.newTexture({ type = "image", filename = "src/assets/interface/stone.png" }),
        food = graphics.newTexture({ type = "image", filename = "src/assets/interface/food.png" }),
        
        warrior_lvl1 = graphics.newTexture({ type = "image", filename = "src/assets/interface/UnitL1.png" }),
        warrior_lvl2 = graphics.newTexture({ type = "image", filename = "src/assets/interface/UnitL2.png" }),
        warrior_lvl3 = graphics.newTexture({ type = "image", filename = "src/assets/interface/UnitL3.png" }),

        peasant_house = graphics.newTexture({ type = "image", filename = "src/assets/interface/peasant_house.png" }),
        farm          = graphics.newTexture({ type = "image", filename = "src/assets/interface/stone.png" }),
        mine          = graphics.newTexture({ type = "image", filename = "src/assets/interface/cave.png" }),
        lumbermill    = graphics.newTexture({ type = "image", filename = "src/assets/interface/stone.png" }),
        workshop      = graphics.newTexture({ type = "image", filename = "src/assets/interface/stone.png" }),
        barracks      = graphics.newTexture({ type = "image", filename = "src/assets/interface/barracks.png" }),

    }
    
    
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
        {id="gold",  },
        {id="wood"   },
        {id="stone"  },
        {id="food"   }
    }
    
    for i, res in ipairs(resTypes) do
        local yPos = resBg.y - resH/2 + ScreenUtils.px(15) + (i-1) * ScreenUtils.px(22)
        -- Іконка-заглушка
        local icon = display.newImageRect(self.resGroup, icons[res.id].filename, icons[res.id].baseDir, ScreenUtils.px(24), ScreenUtils.px(24) )
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
        { label = "U", color = {0.8, 0.3, 0.3}, mode = "spawn_unit", title = "Recruit Units", items = rules.UNITScatalog },
        { label = "R", color = {0.3, 0.8, 0.3}, mode = "build_resource", title = "Resource Buildings", items = rules.BUILDINGScatalog },
        { label = "D", color = {0.3, 0.3, 0.8}, mode = "build_defense", title = "Defenses", items = rules.BUILDINGS }
    }

    -- Генерація кнопок 
    for i, btnConf in ipairs(actionButtons) do
        local actionBtn = display.newCircle(self.bottomGroup, botBg.x - botBg.width/2 + ScreenUtils.px(40) + (i-1)*ScreenUtils.px(60), botBg.y, ScreenUtils.px(20))
        actionBtn:setFillColor(unpack(btnConf.color))
        display.newText(self.bottomGroup, btnConf.label, actionBtn.x, actionBtn.y, UITheme.fontMain, ScreenUtils.px(16))
        
        actionBtn:addEventListener("tap", function()
            self:openSelectionMenu(btnConf.title, btnConf.mode, btnConf.items)
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

    -- ==========================================
    -- 9. МЕНЮ ПОКУПОК ЮНІТІВ ТА БУДІВЕЛЬ
    -- ==========================================

    local panelHeight = ScreenUtils.px(280)
    -- РОБИМО ВІКНО НА ВСЮ ШИРИНУ ЕКРАНА
    local panelWidth = display.actualContentWidth  - pad*2
    local panelTargetY = display.actualContentHeight - panelHeight/2 - pad

    self.selectionWindow = UIWindow.new({
        parent = self.layer,
        x = display.contentCenterX, 
        y = panelTargetY, 
        width = panelWidth, 
        height = panelHeight,
        title = "Select Action",
        can_change = false,        
        closeOnOutside = true,     
        hideCloseBtn = true,       
        transparentOverlay = true, 
        onClose = function()
            transition.to(self.bottomGroup, { time = 250, y = 0, transition = easing.outBack })
        end
    })
    
    local originalShow = self.selectionWindow.show
    function self.selectionWindow:show()
        originalShow(self)
        self.windowGroup.y = display.actualContentHeight + panelHeight
        transition.to(self.windowGroup, { time = 250, y = panelTargetY, transition = easing.outBack })
    end

    local originalHide = self.selectionWindow.hide
    function self.selectionWindow:hide()
        transition.to(self.windowGroup, { time = 200, y = display.actualContentHeight + panelHeight, transition = easing.inQuad, onComplete = function()
            originalHide(self)
        end})
    end

    self.selectionListGroup = display.newGroup()
    self.selectionWindow.contentGroup:insert(self.selectionListGroup)

    -- ФУНКЦІЯ ГЕНЕРАЦІЇ СІТКИ (Grid 2x3)
    function self:openSelectionMenu(title, mode, items)
        self.selectionWindow.titleText.text = title

        for i = self.selectionListGroup.numChildren, 1, -1 do
            local child = self.selectionListGroup[i]
            if child then child:removeSelf() end
        end

        -- НАЛАШТУВАННЯ СІТКИ (Grid)
        local columns = 2
        local btnWidth = panelWidth / columns -- Ширина однієї кнопки (половина екрана)
        local rowHeight = ScreenUtils.px(70)
        
        -- Початкова точка для першої кнопки (відносно центру вікна)
        local startX = -panelWidth/2 + btnWidth/2
        local startY = ScreenUtils.px(60)

        for i, item in ipairs(items) do
            -- Математика сітки: вираховуємо рядок і колонку (від 0)
            local col = (i - 1) % columns
            local row = math.floor((i - 1) / columns)
            
            local xPos = startX + (col * btnWidth)
            local yPos = startY + (row * rowHeight)
            
            local rowGroup = display.newGroup()
            rowGroup.x, rowGroup.y = xPos, yPos
            self.selectionListGroup:insert(rowGroup)

            -- Клікабельний фон кнопки (трохи менший за btnWidth, щоб були відступи)
            local rowBg = display.newRoundedRect(rowGroup, 0, 0, btnWidth - ScreenUtils.px(16), rowHeight - ScreenUtils.px(10), ScreenUtils.px(8))
            UITheme.applyStyle(rowBg)

            -- Квадратна Іконка (зліва)
            local iconSize = ScreenUtils.px(36)
            local iconX = -btnWidth/2 + ScreenUtils.px(30)
            
            -- А) КОЛЬОРОВЕ ТЛО-РАМКА (замість сірого квадрата)
            local iconFrame = display.newRoundedRect(rowGroup, iconX, 0, iconSize, iconSize, ScreenUtils.px(6))
            
            -- Робимо тло напівпрозорим, щоб воно було м'якшим під зображенням
            local c = item.iconColor or {0.5, 0.5, 0.5}
            iconFrame:setFillColor(c[1], c[2], c[3], 0.3)

            -- Б) САМЕ ЗОБРАЖЕННЯ ЮНІТА/БУДІВЛІ (накладаємо зверху)

            -- Спроба завантажити іконку. Щоб уникнути мікро-лагів,
            print( item.id )
            local unitIcon = display.newImageRect(rowGroup, icons[item.id].filename, icons[item.id].baseDir , iconSize * 0.8, iconSize * 0.8)
            if unitIcon then
                unitIcon.x, unitIcon.y = iconX, 0
            end

            -- Назва об'єкта (вище)
            local textX = iconX + iconSize/2 + ScreenUtils.px(10)
            local nameText = display.newText({
                parent = rowGroup, text = item.name,
                x = textX, y = -ScreenUtils.px(10),
                font = UITheme.fontMain, fontSize = ScreenUtils.px(18)
            })
            nameText.anchorX = 0

            -- ІКОНКА ЦІНИ ТА ТЕКСТ (нижче)
            local goldIconSize = ScreenUtils.px(24)
        
            
            GoldIcon  = display.newImageRect(rowGroup, icons["gold"].filename, icons["gold"].baseDir, goldIconSize, goldIconSize)
            StoneIcon = display.newImageRect(rowGroup, icons["stone"].filename, icons["stone"].baseDir, goldIconSize, goldIconSize)
            WoodIcon  = display.newImageRect(rowGroup, icons["wood"].filename, icons["wood"].baseDir, goldIconSize, goldIconSize)
            
            GoldIcon.x = textX +goldIconSize/3 ; GoldIcon.y = ScreenUtils.px(10)

            -- Текст ціни біля іконки
            local goldText = display.newText({
                parent = rowGroup, text = item.cost.gold or 0,
                x = GoldIcon.x + goldIconSize/2 + ScreenUtils.px(4), y = GoldIcon.y,
                font = UITheme.fontMain, fontSize = ScreenUtils.px(16)
            })

            StoneIcon.x = goldText.x + goldIconSize; StoneIcon.y = ScreenUtils.px(10)

            -- Текст ціни біля іконки
            local stoneText = display.newText({
                parent = rowGroup, text = item.cost.stone or 0,
                x = StoneIcon.x + goldIconSize/2 + ScreenUtils.px(4), y = GoldIcon.y,
                font = UITheme.fontMain, fontSize = ScreenUtils.px(16)
            })

             WoodIcon.x = stoneText.x + goldIconSize; WoodIcon.y = ScreenUtils.px(10)

            -- Текст ціни біля іконки
            local woodText = display.newText({
                parent = rowGroup, text = item.cost.wood or 0,
                x = WoodIcon.x + goldIconSize/2 + ScreenUtils.px(4), y = GoldIcon.y,
                font = UITheme.fontMain, fontSize = ScreenUtils.px(16)
            })

            goldText.anchorX = 0
            stoneText.anchorX = 0
            woodText.anchorX = 0
            
        -- ==========================================
        -- КНОПКА ДОПОМОГИ "?" (Top Right)
        -- ==========================================
        local helpBtnSize = ScreenUtils.px(16)
        
        -- Вираховуємо крайні точки нашої головної кнопки rowBg
        local bgHalfW = rowBg.width / 2
        local bgHalfH = rowBg.height / 2

        -- Створюємо групу для допомоги, щоб центрувати текст
        local helpGroup = display.newGroup()
        -- Відступаємо трохи від верхнього правого кута
        helpGroup.x = bgHalfW - helpBtnSize/2 - ScreenUtils.px(8)
        helpGroup.y = -bgHalfH + helpBtnSize/2 + ScreenUtils.px(8)
        rowGroup:insert(helpGroup)

        local helpCircle = display.newCircle(helpGroup, 0, 0, helpBtnSize/2)
        helpCircle:setFillColor(0.25, 0.25, 0.3, 0.5) -- Трохи світліше за фон кнопки

        local helpText = display.newText({
            parent = helpGroup, text = "?",
            x = 0, y = 0,
            font = UITheme.fontMain, fontSize = ScreenUtils.px(12)
        })
        helpText:setFillColor(0.7, 0.7, 0.7)

        -- Робимо її неклікабельною, але щоб вона "ковтала" тап (щоб не спрацювала кнопка вибору)
        helpGroup:addEventListener("tap", function() return true end)
        helpGroup:addEventListener("touch", function() return true end)

            -- ОБРОБКА КЛІКУ ПО ОБ'ЄКТУ
            rowBg:addEventListener("tap", function()
                transition.to(self.bottomGroup, { time = 250, y = 0, transition = easing.outBack })
                self.selectionWindow:hide()
                
                local ActionManager = require("src.scripts.core.ActionManager")
                ActionManager.setMode(mode, item)
                return true
            end)
        end

        transition.to(self.bottomGroup, { time = 200, y = ScreenUtils.px(120), transition = easing.inQuad })
        self.selectionWindow:show()
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