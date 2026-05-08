-- src/scenes/GameScene.lua
local composer = require("composer")
local scene = composer.newScene()

local ActionManager = require("src.scripts.core.ActionManager")
local MatchInit = require("src.scripts.core.MatchInit")
local TurnManager = require("src.scripts.core.TurnManager")
local EntityRenderer = require("src.scripts.world.EntityRenderer")
local WorldConfig = require("src.scripts.config.WorldConfig")
local Logger = require("src.scripts.utils.logger")
local MAS = require("src.scripts.utils.moveAndScale")
local GameUI = require("src.scripts.view.GameUI") 
local ChunkManager = require("src.scripts.world.ChunkManager")
local ToastManager = require("src.scripts.view.ToastManager")

local CELL_SIZE = WorldConfig.CELL_SIZE

-- ==========================================
-- ЛОГІКА КАМЕРИ ТА КЛІКІВ 
-- ==========================================

--- Плавне переміщення камери до вказаної клітинки
function scene:focusOnGrid(gridX, gridY)
    if not self.cameraGroup then return end

    -- Рахуємо центр потрібної клітинки в пікселях
    local targetX = self.startX + (gridX - 1) * CELL_SIZE + (CELL_SIZE / 2)
    local targetY = self.startY + (gridY - 1) * CELL_SIZE + (CELL_SIZE / 2)

    -- Рахуємо, куди треба посунути групу, щоб ця точка стала центром екрану
    local endX = display.contentCenterX - (targetX * self.cameraGroup.xScale)
    local endY = display.contentCenterY - (targetY * self.cameraGroup.yScale)

    transition.to(self.cameraGroup, {
        x = endX, 
        y = endY, 
        time = 800, 
        transition = easing.outQuad
    })
end

--- Обробка тапу по екрану (Touch to Grid)
local function onMapTap(event)
    local localX, localY = scene.worldGroup:contentToLocal(event.x, event.y)
    
    -- 1. Знаходимо реальний лівий верхній край карти (віднімаємо половину тайлу)
    local mapLeftEdge = scene.startX - (CELL_SIZE / 2)
    local mapTopEdge = scene.startY - (CELL_SIZE / 2)
    
    -- 2. Тепер ділимо на розмір тайлу. Математика буде ідеальною!
    local gridX = math.floor((localX - mapLeftEdge) / CELL_SIZE) + 1
    local gridY = math.floor((localY - mapTopEdge) / CELL_SIZE) + 1
    
    -- Перевірка, чи не клікнули ми за межі карти
    local worldParams = scene.gameState.world
    if gridX >= 1 and gridX <= worldParams.width and gridY >= 1 and gridY <= worldParams.height then
        Logger.info("Input", "Tapped on Grid: " .. gridX .. ", " .. gridY)

        local actionHandled = ActionManager.handleMapClick(gridX, gridY, scene.gameState, scene.gameUI)
        
        if actionHandled then
            --scene.entityRenderer:update(scene.gameState)
            -- Оновлюємо візуальний стан карти (поки просто ховаємо курсор)
            scene.cursor.isVisible = false
            scene.gameUI.infoGroup.isVisible = false
            return true 
        end
        -- Курсор залишаємо як є (він відмальовується ВІД ЦЕНТРУ, тому тут все було правильно)
        scene.cursor.x = math.floor(scene.startX + (gridX - 1) * CELL_SIZE)
        scene.cursor.y = math.floor(scene.startY + (gridY - 1) * CELL_SIZE)
        scene.cursor.isVisible = true
        
        local cellData = worldParams:getTile(gridX, gridY)
        scene.gameUI:showTileInfo(gridX, gridY, cellData)
    else
        scene.cursor.isVisible = false
        scene.gameUI.infoGroup.isVisible = false
    end
    
    return true
end

--- Обмеження Камери (Clamp & Zoom)
--- Обмеження Камери (Clamp Panning)


function GameUI:updateTimer(seconds)
    
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    self.timerText.text = string.format("%d:%02d", m, s)
    
    -- Якщо залишилось мало часу, робимо червоним
    if seconds <= 15 then
        self.timerText:setFillColor(1, 0.2, 0.2)
    else
        self.timerText:setFillColor(1, 1, 1)
    end
end

-- ==========================================
-- БАЗОВІ ФУНКЦІЇ СЦЕНИ
-- ==========================================

function scene:create(event)
    Logger.info("GameScene", "Creating Scene...")
    local params = event.params or {}
    
    self.bgLayer = display.newGroup()
    self.cameraGroup = display.newGroup()
    self.uiLayer = display.newGroup()
    
    self.view:insert(self.bgLayer)
    self.view:insert(self.cameraGroup)
    self.view:insert(self.uiLayer)

    local bg = display.newRect(self.bgLayer, display.contentCenterX, display.contentCenterY, display.actualContentWidth*2, display.actualContentHeight*2)
    bg:setFillColor(0.1, 0.1, 0.15)
    bg.isHitTestable = true 
    
    -- ==========================================
    -- 1. СТВОРЕННЯ ШАРІВ (Ідеальний Y-Sorting)
    -- ==========================================
    self.mapGroupBase = display.newGroup()    -- Земля, вода, переходи
    self.territoryLayer = display.newGroup()  -- Кольори володінь
    self.entityLayer = display.newGroup()     -- Замки, Воїни, Дерева
    self.mapGroupTop = display.newGroup()     -- Верхівки гір (перекривають воїнів)
    
    self.cameraGroup:insert(self.mapGroupBase)
    self.cameraGroup:insert(self.territoryLayer)
    self.cameraGroup:insert(self.entityLayer)
    self.cameraGroup:insert(self.mapGroupTop)

    -- Розрахунок розмірів
    local totalWidth = params.width * CELL_SIZE
    local totalHeight = params.height * CELL_SIZE
    self.startX = math.floor(-(totalWidth / 2) + (CELL_SIZE / 2))
    self.startY = math.floor(-(totalHeight / 2) + (CELL_SIZE / 2))

    -- ==========================================
    -- 2. ІНІЦІАЛІЗАЦІЯ СИСТЕМ
    -- ==========================================
    -- Підключаємо камеру і передаємо їй межі карти
    MAS:start(self.cameraGroup)
    MAS:setBounds(self.cameraGroup, totalWidth, totalHeight)

    -- Ініціалізуємо ChunkManager (передаємо групи для малювання)
    ChunkManager.init(self.mapGroupBase, self.mapGroupTop, params.grid, WorldConfig)

    -- Ініціалізуємо ігрову логіку
    self.gameState = MatchInit.setupNewGame(params.grid, params.width, params.height)
    
    -- Створюємо UI та рендер сутностей
    self.gameUI = GameUI.new(self.uiLayer, self.gameState)
    self.entityRenderer = EntityRenderer.new(self.entityLayer, self.territoryLayer, CELL_SIZE, self.startX, self.startY)
    
    ToastManager.init(self.uiLayer)
    self.gameUI.sceneRef = self 

    -- ==========================================
    -- 3. ГОЛОВНИЙ ЦИКЛ ОНОВЛЕННЯ (Game Loop)
    -- ==========================================
    self.gameLoop = function()
        -- 1. Чанки землі та гір слідують за камерою
        if ChunkManager and ChunkManager.update then
            ChunkManager.update(self.cameraGroup)
        end
        
        -- 2. Динамічний JIT-рендер сутностей (Замки, Дерева, Воїни)
        if self.entityRenderer and type(self.entityRenderer.update) == "function" then
            -- Передаємо камеру та gameState, щоб рендерер міг читати сітку!
            self.entityRenderer:update(self.cameraGroup, self.gameState)
        end
    end
    Runtime:addEventListener("enterFrame", self.gameLoop)
    
    -- ==========================================
    -- ОБРОБКА КЛІКІВ
    -- ==========================================
    local function onMapTap(e)
        if self.cameraGroup.isDragging then return true end
        
        local localX, localY = self.cameraGroup:contentToLocal(e.x, e.y)
        local gridX = math.floor((localX - self.startX + (CELL_SIZE / 2)) / CELL_SIZE) + 1
        local gridY = math.floor((localY - self.startY + (CELL_SIZE / 2)) / CELL_SIZE) + 1
        
        local cellData = self.gameState.world:getTile(gridX, gridY)
        self.gameUI:showTileInfo(gridX, gridY, cellData)
        
        if ActionManager.mode ~= "idle" then
            ActionManager.handleMapClick(self.gameState, gridX, gridY, self.gameUI, self.entityRenderer)
            return true
        end
        return true
    end
    self.bgLayer:addEventListener("tap", onMapTap)
end

function scene:show(event)
    if event.phase == "did" then
        Logger.info("GameScene", "Game Started!")
        
        -- Запускаємо перший хід та таймер!
        local TurnManager = require("src.scripts.core.TurnManager")
        TurnManager.startTurn(self.gameState, self)
    end
end

-- ==========================================
-- ПРИХОВУВАННЯ СЦЕНИ (Зупинка всіх процесів)
-- ==========================================
function scene:hide(event)
    if event.phase == "will" then
        Logger.info("GameScene", "Hiding scene, stopping all processes...")

        -- 1. Зупиняємо головний ігровий цикл
        if self.gameLoop then 
            Runtime:removeEventListener("enterFrame", self.gameLoop) 
            self.gameLoop = nil
        end
        
        -- 2. Зупиняємо фізику та обробку камери
        if self.cameraGroup then
            MAS:stop(self.cameraGroup)
        end
        
        -- 3. Зупиняємо таймер ходу гравця
        local TurnManager = require("src.scripts.core.TurnManager")
        if TurnManager.stopTimer then
            TurnManager.stopTimer()
        end
        
        -- 4. (Опціонально) Зупиняємо будь-які глобальні Action-менеджери
        if ActionManager and ActionManager.reset then
            ActionManager.reset()
        end
    end
end

-- ==========================================
-- ЗНИЩЕННЯ СЦЕНИ (Повне очищення пам'яті)
-- ==========================================
function scene:destroy(event)
    Logger.info("GameScene", "Destroying scene, freeing memory...")
    
    -- 1. Знищуємо всі чанки та зупиняємо чергу генерації
    if ChunkManager and ChunkManager.destroyAll then
        ChunkManager.destroyAll()
    end
    
    -- 2. Очищаємо UI (якщо у UI є власні Runtime лісенери чи таймери)
    if self.gameUI and type(self.gameUI.destroy) == "function" then
        self.gameUI:destroy()
    end
    self.gameUI = nil
    
    -- 3. Очищаємо рендерер сутностей (відключаємо його процеси)
    if self.entityRenderer and type(self.entityRenderer.destroy) == "function" then
        self.entityRenderer:destroy()
    end
    self.entityRenderer = nil
    
    -- 4. Очищаємо ToastManager (якщо він висів у UI)
    local ToastManager = require("src.scripts.view.ToastManager")
    if ToastManager and ToastManager.destroyAll then
        ToastManager.destroyAll()
    end
    
    -- 5. Обнуляємо посилання на стан гри, щоб Garbage Collector міг його видалити
    self.gameState = nil
    
    -- 6. Примусово викликаємо збирач сміття Lua
    collectgarbage("collect")
end

local function onSystemEvent( event )
    if ( event.type == "applicationResume" ) then
        scene.TEXTURE:invalidate( "cache" )
    end
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene