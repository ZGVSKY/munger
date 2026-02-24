-- src/scenes/loading.lua
local composer = require("composer")
local scene = composer.newScene()

local WorldManager = require("src.scripts.world.WorldManager")
local WorldConfig = require("src.scripts.config.WorldConfig")
local MAS = require("src.scripts.utils.moveAndScale") 
local Logger = require("src.scripts.utils.logger")

local loadingText, loadingBarBG, loadingBarFill

-- Створюємо UI
function scene:create(event)
    local sceneGroup = self.view
    local cx, cy = display.contentCenterX, display.contentCenterY

    local bg = display.newRect(sceneGroup, cx, cy, display.contentWidth, display.contentHeight)
    bg:setFillColor(0.1, 0.1, 0.15)

    loadingText = display.newText({
        parent = sceneGroup,
        text = "Initializing...",
        x = cx, y = cy - 50,
        font = native.systemFontBold,
        fontSize = 24
    })

    loadingBarBG = display.newRect(sceneGroup, cx, cy + 20, 300, 20)
    loadingBarBG:setFillColor(0.2, 0.2, 0.2)
    loadingBarBG.strokeWidth = 2
    loadingBarBG:setStrokeColor(0.5, 0.5, 0.5)

    loadingBarFill = display.newRect(sceneGroup, cx - 148, cy + 20, 0, 16)
    loadingBarFill:setFillColor(0.2, 0.8, 0.2)
    loadingBarFill.anchorX = 0 
end

-- Запускаємо логіку при показі сцени
function scene:show(event)
    if event.phase == "did" then
        loadingText.text = "Preparing World..."
        loadingBarFill.width = 0
        loadingText:setFillColor(1, 1, 1) -- Скидаємо колір тексту (якщо була помилка)
        
        -- Створюємо тимчасову групу для карти
        scene.tempMapGroup = display.newGroup() 
        
        -- Викликаємо наш новий єдиний інтерфейс
        WorldManager.generateWorld(scene.tempMapGroup, WorldConfig, {
            
            -- 1. Оновлення UI
            onProgress = function(statusText, progressFloat)
                loadingText.text = statusText
                loadingBarFill.width = 296 * progressFloat
            end,
            
            -- 2. Успішне завершення
            onComplete = function(data)
                loadingText.text = "Done!"
                loadingBarFill.width = 296
                
                
                -- ПЕРЕХІД ДО ГОЛОВНОЇ СЦЕНИ (передаємо дані)
                composer.gotoScene("src.scripts.core.GameScene", {
                    time = 500,
                    effect = "crossFade",
                    params = {
                        grid = data.grid,
                        mapGroup = data.map,
                        width = WorldConfig.MAP_WIDTH,
                        height = WorldConfig.MAP_HEIGHT
                    }
                })
            end,
            
            -- 3. Обробка збоїв
            onError = function(errorMsg)
                loadingText.text = "Error Generating World!"
                loadingText:setFillColor(1, 0.2, 0.2)
                loadingBarFill:setFillColor(1, 0, 0)
                Logger.error("Scene", tostring(errorMsg))
            end
            
        })
    end
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)

return scene