-- src/scenes/GameScene.lua
local composer = require("composer")
local scene = composer.newScene()

local MatchInit = require("src.scripts.core.MatchInit")
local TurnManager = require("src.scripts.core.TurnManager")
local EntityRenderer = require("src.scripts.world.EntityRenderer")
local WorldConfig = require("src.scripts.config.WorldConfig")
local Logger = require("src.scripts.utils.logger")
local MAS = require("src.scripts.utils.moveAndScale")
local GameUI = require("src.scripts.view.GameUI") 

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
    -- Конвертуємо координати екрану (event.x, event.y) в координати всередині worldGroup
    local localX, localY = scene.worldGroup:contentToLocal(event.x, event.y)
    
    -- Конвертуємо пікселі в координати сітки [GridX, GridY]
    local gridX = math.floor((localX - scene.startX) / CELL_SIZE) + 1
    local gridY = math.floor((localY - scene.startY) / CELL_SIZE) + 1
    
    -- Перевірка, чи не клікнули ми за межі карти
    local worldParams = scene.gameState.world
    if gridX >= 1 and gridX <= worldParams.width and gridY >= 1 and gridY <= worldParams.height then
        Logger.info("Input", "Tapped on Grid: " .. gridX .. ", " .. gridY)
        
        -- Переміщуємо курсор виділення
        scene.cursor.x = math.floor(scene.startX + (gridX - 1) * CELL_SIZE + (CELL_SIZE / 2))
        scene.cursor.y = math.floor(scene.startY + (gridY - 1) * CELL_SIZE + (CELL_SIZE / 2))
        scene.cursor.isVisible = true
        
        -- ОНОВЛЮЄМО ІНФОРМАЦІЮ В UI 
        local cellData = worldParams:getTile(gridX, gridY)
        scene.gameUI:showTileInfo(gridX, gridY, cellData)
    else
        scene.cursor.isVisible = false
    end
    
    return true
end

--- Обмеження Камери (Clamp & Zoom)
local function onEnterFrame()
    if not scene.cameraGroup then return end
    
    -- 1. Обмеження зуму (від 0.5x до 2.0x)
    local minZoom, maxZoom = 0.5, 2.0
    if scene.cameraGroup.xScale < minZoom then
        scene.cameraGroup.xScale, scene.cameraGroup.yScale = minZoom, minZoom
    elseif scene.cameraGroup.xScale > maxZoom then
        scene.cameraGroup.xScale, scene.cameraGroup.yScale = maxZoom, maxZoom
    end
    
    -- В майбутньому тут можна додати жорсткий Clamp, щоб камера не вилітала за межі карти по X та Y
end

-- ==========================================
-- БАЗОВІ ФУНКЦІЇ СЦЕНИ
-- ==========================================

function scene:create(event)
    local sceneGroup = self.view
    local params = event.params

    if not params or not params.grid then return end

    self.worldGroup = display.newGroup()     
    self.bgLayer = display.newGroup()        
    self.territoryLayer = display.newGroup() 
    self.entityLayer = display.newGroup()    
    self.uiLayer = display.newGroup()        

    self.worldGroup:insert(self.bgLayer)
    self.worldGroup:insert(self.territoryLayer)
    self.worldGroup:insert(self.entityLayer)

    self.bgLayer:insert(params.mapGroup)

    self.cameraGroup = MAS:init(self.worldGroup)
    self.cameraGroup.x = display.contentCenterX
    self.cameraGroup.y = display.contentCenterY
    
    -- ВАЖЛИВО: Явно вказуємо порядок відмальовки!
    sceneGroup:insert(self.cameraGroup) -- 1. Камера знизу
    sceneGroup:insert(self.uiLayer)     -- 2. UI ПОВЕРХ камери
    self.uiLayer:toFront()              -- Примусово витягуємо інтерфейс наперед

    MAS:start(self.cameraGroup)


    

    

    local totalWidth = params.width * CELL_SIZE
    local totalHeight = params.height * CELL_SIZE
    self.startX = math.floor(-(totalWidth / 2) + (CELL_SIZE / 2))
    self.startY = math.floor(-(totalHeight / 2) + (CELL_SIZE / 2))

    -- Ініціалізація Логіки
    self.gameState = MatchInit.setupNewGame(params.grid, params.width, params.height)
    self.entityRenderer = EntityRenderer.new(self.entityLayer, self.startX, self.startY)
    self.entityRenderer:drawAll(self.gameState)

    -- СТВОРЕННЯ UI 
    self.gameUI = GameUI.new(self.uiLayer, self.gameState)

    -- СТВОРЕННЯ КУРСОРА (Жовтий квадрат для виділення клітинки)
    self.cursor = display.newRect(self.entityLayer, 0, 0, CELL_SIZE, CELL_SIZE)
    self.cursor:setFillColor(0, 0, 0, 0) -- Прозорий всередині
    self.cursor.strokeWidth = 4
    self.cursor:setStrokeColor(1, 1, 0, 0.8) -- Жовтий контур
    self.cursor.isVisible = false -- Ховаємо до першого кліку

    
    -- Додаємо слухачі подій
    self.bgLayer:addEventListener("tap", onMapTap)
    Runtime:addEventListener("enterFrame", onEnterFrame)
end

function scene:show(event)
    if event.phase == "did" then
        Logger.info("GameScene", "Game Started!")
        
        -- Демонстрація focusOn: На старті плавно летимо до Замку Першого Гравця!
        local p1 = self.gameState:getPlayerById(1)
        if p1 and #p1.buildings > 0 then
            local p1Castle = p1.buildings[1]
            self:focusOnGrid(p1Castle.x, p1Castle.y)
        end
    end
end

function scene:hide(event)
    if event.phase == "will" then
        self.bgLayer:removeEventListener("tap", onMapTap)
        Runtime:removeEventListener("enterFrame", onEnterFrame)
    end
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)

return scene