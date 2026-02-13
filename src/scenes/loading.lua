-- src/scenes/loading.lua
local composer = require("composer")
local scene = composer.newScene()

local WorldGenerator = require("src.scripts.world.WorldGenerator")
local Logger = require("src.scripts.utils.logger")

local generationCo
local startTime
local loadingText, loadingBarBG, loadingBarFill

-- Налаштування сцени (UI)
function scene:create(event)
    local sceneGroup = self.view
    local cx, cy = display.contentCenterX, display.contentCenterY

    -- Фон
    local bg = display.newRect(sceneGroup, cx, cy, display.contentWidth, display.contentHeight)
    bg:setFillColor(0.1, 0.1, 0.15)

    -- Текст
    loadingText = display.newText({
        parent = sceneGroup,
        text = "Initializing...",
        x = cx, y = cy - 50,
        font = native.systemFontBold,
        fontSize = 24
    })

    -- Прогрес бар (Фон)
    loadingBarBG = display.newRect(sceneGroup, cx, cy + 20, 300, 20)
    loadingBarBG:setFillColor(0.2, 0.2, 0.2)
    loadingBarBG.strokeWidth = 2
    loadingBarBG:setStrokeColor(0.5, 0.5, 0.5)

    -- Прогрес бар (Заповнення)
    loadingBarFill = display.newRect(sceneGroup, cx - 148, cy + 20, 0, 16)
    loadingBarFill:setFillColor(0.2, 0.8, 0.2)
    loadingBarFill.anchorX = 0 -- Розтягуємо зліва направо
end

-- Функція, яка виконується кожен кадр
local function onFrame(event)
    if not generationCo then return end

    -- Виділяємо 16мс (60 FPS) на генерацію. 
    -- Якщо хочеш, щоб генерація йшла швидше, збільш до 30.
    local timeBudget = 15 
    local startTimeFrame = system.getTimer()

    local active = true

    while active and (system.getTimer() - startTimeFrame < timeBudget) do
        
        -- Перевіряємо статус корутини
        if coroutine.status(generationCo) == "dead" then
            active = false
            return -- Корутина вже закінчила роботу
        end

        -- Робимо крок генерації
        local success, data = coroutine.resume(generationCo)

        if not success then
            Logger.error("Loader", "Generation Failed: " .. tostring(data))
            loadingText.text = "Error!"
            Runtime:removeEventListener("enterFrame", onFrame)
            return
        end

        -- Якщо генерація завершена (функція повернула return)
        if coroutine.status(generationCo) == "dead" then
            local finalTime = system.getTimer() - startTime
            Logger.info("Loader", "Finished in " .. finalTime .. "ms")
            
            loadingText.text = "Done!"
            loadingBarFill.width = 296
            
            Runtime:removeEventListener("enterFrame", onFrame)

            -------------------------------------------------------------
            -- НОВА ВІЗУАЛІЗАЦІЯ (Фіксований розмір)
            -------------------------------------------------------------
            local grid = data.result
            
            -- НАЛАШТУВАННЯ: Розмір однієї клітинки в пікселях
            local FIXED_CELL_SIZE = 32 
            
            -- Створюємо групу, щоб тримати всю карту разом
            local mapGroup = display.newGroup()
            --sceneGroup:insert(mapGroup) -- Додаємо в сцену

            -- Розрахунок позиції: Центруємо карту на екрані
            -- Оскільки карта велика, краї будуть за межами екрану
            local totalMapWidth = #grid * FIXED_CELL_SIZE
            local totalMapHeight = #grid[1] * FIXED_CELL_SIZE
            
            local startX = (display.contentWidth - totalMapWidth) / 2
            local startY = (display.contentHeight - totalMapHeight) / 2

            for x = 1, #grid do
                for y = 1, #grid[1] do
                    local cell = grid[x][y]
                    
                    -- Малюємо квадрат фіксованого розміру
                    local rect = display.newRect(
                        mapGroup, 
                        startX + (x-1) * FIXED_CELL_SIZE, -- x-1 щоб почати з 0
                        startY + (y-1) * FIXED_CELL_SIZE, 
                        FIXED_CELL_SIZE, 
                        FIXED_CELL_SIZE
                    )
                    
                    -- Налаштування кольорів (без змін)
                    if cell.isLake then
                        rect:setFillColor(0, 0, 0.8)
                    elseif cell.isRiver then
                        rect:setFillColor(0, 0.5, 1)
                    elseif cell.height < 0.3 then 
                        rect:setFillColor(0, 0, 0.5)
                    elseif cell.height < 0.35 then 
                        rect:setFillColor(1, 1, 0.6)
                    elseif cell.height < 0.7 then 
                        rect:setFillColor(0.2, 0.8, 0.2)
                    else 
                        rect:setFillColor(0.6, 0.6, 0.6)
                    end
                    
                    -- Тонка рамка, щоб бачити сітку (опціонально)
                    rect.strokeWidth = 1
                    rect:setStrokeColor(0, 0, 0, 0.1)
                end
            end
            
            Logger.info("Loader", "Visualized map with cell size: " .. FIXED_CELL_SIZE)
            -------------------------------------------------------------
            
        else
            -- Оновлення UI
            if data and data.progress then
                loadingText.text = data.status
                loadingBarFill.width = 296 * data.progress
            end
        end
    end
end

function scene:show(event)
    if event.phase == "did" then
        -- Запускаємо генерацію при показі сцени
        local params = {
            width = 600,   -- Поки що маленька карта для тесту
            height = 600,
            seed = os.time(),
            scale = 40,    -- Масштаб шуму
            enableOcean = true,
            enableRivers = true,
            riverCount = 30,
            seaLevel = -0.3
        }

        Logger.info("Loader", "Starting Generator Coroutine")
        generationCo = WorldGenerator.createGenerationCoroutine(params)
        startTime = system.getTimer()

        Runtime:addEventListener("enterFrame", onFrame)
    end
end

function scene:hide(event)
    if event.phase == "will" then
        Runtime:removeEventListener("enterFrame", onFrame)
    end
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)

return scene