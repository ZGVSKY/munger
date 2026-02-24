-- src/scenes/GameScene.lua
local composer = require("composer")
local scene = composer.newScene()

local MatchInit = require("src.scripts.core.MatchInit")
local TurnManager = require("src.scripts.core.TurnManager")
local EntityRenderer = require("src.scripts.world.EntityRenderer")
local WorldConfig = require("src.scripts.config.WorldConfig")
local Logger = require("src.scripts.utils.logger")
local MAS = require("src.scripts.utils.moveAndScale") 

local CELL_SIZE = WorldConfig.CELL_SIZE

function scene:create(event)
    local sceneGroup = self.view
    local params = event.params

    if not params or not params.grid then return end
    Logger.info("GameScene", "Initializing Game World...")

    -- ==========================================
    -- 1. ШАРИ ВІДМАЛЬОВКИ
    -- ==========================================
    self.worldGroup = display.newGroup()     
    self.bgLayer = display.newGroup()        
    self.territoryLayer = display.newGroup() 
    self.entityLayer = display.newGroup()    
    self.uiLayer = display.newGroup()        

    self.worldGroup:insert(self.bgLayer)
    self.worldGroup:insert(self.territoryLayer)
    self.worldGroup:insert(self.entityLayer)
    sceneGroup:insert(self.worldGroup)
    sceneGroup:insert(self.uiLayer)

    self.bgLayer:insert(params.mapGroup)

    local totalWidth = params.width * CELL_SIZE
    local totalHeight = params.height * CELL_SIZE
    self.startX = math.floor(-(totalWidth / 2) + (CELL_SIZE / 2))
    self.startY = math.floor(-(totalHeight / 2) + (CELL_SIZE / 2))

    -- ==========================================
    -- 2. ЛОГІКА ТА РЕНДЕР
    -- ==========================================
    -- Делегуємо створення гри Директору
    self.gameState = MatchInit.setupNewGame(params.grid, params.width, params.height)

    -- Делегуємо малювання Художнику
    self.entityRenderer = EntityRenderer.new(self.entityLayer, self.startX, self.startY)
    self.entityRenderer:drawAll(self.gameState)

    -- ==========================================
    -- 3. КАМЕРА
    -- ==========================================
    self.cameraGroup = MAS:init(self.worldGroup)
    self.cameraGroup.x = display.contentCenterX
    self.cameraGroup.y = display.contentCenterY
    MAS:start(self.cameraGroup)
end

function scene:show(event)
    local phase = event.phase
    if phase == "did" then
        -- Коли сцена повністю з'явилася на екрані, офіційно починаємо гру!
        Logger.info("GameScene", "Game Started!")
        -- Якщо розкоментувати рядок нижче, він передасть хід другому гравцю
        -- TurnManager.nextTurn(self.gameState) 
    end
end

function scene:hide(event)
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)

return scene