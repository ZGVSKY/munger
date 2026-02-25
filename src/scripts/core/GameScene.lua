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
local function onEnterFrame()
    if not scene.cameraGroup or not scene.gameState then return end
    
    local cam = scene.cameraGroup
    local world = scene.gameState.world
    
    -- 1. Розміри карти в пікселях З УРАХУВАННЯМ поточного зуму
    local mapW = world.width * CELL_SIZE * cam.xScale
    local mapH = world.height * CELL_SIZE * cam.yScale
    
    -- 2. Розміри фізичного екрану
    local screenW = display.actualContentWidth
    local screenH = display.actualContentHeight
    
    -- 3. Математика меж (Лівий, Правий, Верхній, Нижній ліміти камери)
    local minX = display.screenOriginX + screenW - (mapW / 2)
    local maxX = display.screenOriginX + (mapW / 2)
    
    local minY = display.screenOriginY + screenH - (mapH / 2)
    local maxY = display.screenOriginY + (mapH / 2)

    -- 4. Перевірка по осі X
    -- Якщо карта при віддаленні стала меншою за екран - тримаємо її по центру
    if mapW <= screenW then
        cam.x = display.contentCenterX
    else
        -- Інакше жорстко не пускаємо за краї
        if cam.x < minX then cam.x = minX end
        if cam.x > maxX then cam.x = maxX end
    end

    -- 5. Перевірка по осі Y
    if mapH <= screenH then
        cam.y = display.contentCenterY
    else
        if cam.y < minY then cam.y = minY end
        if cam.y > maxY then cam.y = maxY end
    end
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

    params.mapGroup.isVisible = true
    self.mapGroupRef = params.mapGroup
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

function scene:destroy(event)
    Logger.info("GameScene", "Destroying scene and clearing VRAM...")
    
    if self.mapGroupRef then
        -- Видаляємо першу текстуру (Земля)
        if self.mapGroupRef._groundTex then
            self.mapGroupRef._groundTex:releaseSelf()
            self.mapGroupRef._groundTex = nil
        end
        -- Видаляємо другу текстуру (Дерева/Гори)
        if self.mapGroupRef._overlayTex then
            self.mapGroupRef._overlayTex:releaseSelf()
            self.mapGroupRef._overlayTex = nil
        end
    end
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