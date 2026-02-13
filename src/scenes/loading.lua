-- src/scenes/loading.lua
local composer = require("composer")
local scene = composer.newScene()
local MapRenderer = require("src.scripts.world.MapRenderer")
local WorldGenerator = require("src.scripts.world.WorldGenerator")
local Logger = require("src.scripts.utils.logger")

-- Підключаємо камеру
local MAS = require("src.scripts.utils.moveAndScale") 


local startTime
local loadingText, loadingBarBG, loadingBarFill

local generationCo -- Корутина генерації даних
local renderingCo  -- Корутина малювання текстури (нова)
local mapGridData  -- Тут збережемо згенеровані дані перед малюванням

local STATE_GEN = 1
local STATE_RENDER = 2
local currentState = STATE_GEN

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
-- Функція, яка виконується кожен кадр
local function onFrame(event)
    local timeBudget = 15 -- 15мс на кадр
    local startFrame = system.getTimer()
    
    -- Працюємо поки є час
    while (system.getTimer() - startFrame < timeBudget) do
        
        if currentState == STATE_GEN then
            -------------------------------------------------------
            -- ЕТАП 1: ГЕНЕРАЦІЯ ДАНИХ
            -------------------------------------------------------
            if coroutine.status(generationCo) == "dead" then
                -- Генерація завершена, переходимо до рендеру
                return -- чекаємо наступного кадру
            end

            local success, data = coroutine.resume(generationCo)
            
            if not success then
                print("Error Gen:", data); Runtime:removeEventListener("enterFrame", onFrame); return
            end

            if coroutine.status(generationCo) == "dead" then
                -- Дані готові!
                mapGridData = data.result
                Logger.info("Loader", "Data generated. Starting Renderer...")
                
                -- Перемикаємось на етап рендеру
                currentState = STATE_RENDER
                
                -- Створюємо корутину рендеру, передаємо їй дані
                -- Створюємо тимчасову групу, куди рендер покладе картинку
                scene.tempMapGroup = display.newGroup() 
                renderingCo = MapRenderer.createRenderCoroutine(mapGridData, scene.tempMapGroup)
            else
                -- Оновлення прогресу генерації
                if data and data.progress then
                    loadingText.text = data.status
                    loadingBarFill.width = 296 * (data.progress * 0.5) -- Перші 50% бару
                end
            end

        elseif currentState == STATE_RENDER then
            -------------------------------------------------------
            -- ЕТАП 2: МАЛЮВАННЯ ТЕКСТУРИ
            -------------------------------------------------------
            if not renderingCo or coroutine.status(renderingCo) == "dead" then
                return
            end

            local success, data = coroutine.resume(renderingCo)
            
            if not success then
                print("Error Render:", data); Runtime:removeEventListener("enterFrame", onFrame); return
            end

            if coroutine.status(renderingCo) == "dead" then
                -- РЕНДЕР ЗАВЕРШЕНО!
                Logger.info("Loader", "Rendering complete!")
                
                Runtime:removeEventListener("enterFrame", onFrame)
                loadingText.text = "Done!"
                loadingBarFill.width = 296
                
                -- Отримуємо готову картинку
                local mapImage = data.result
                
                -- Ініціалізуємо камеру MAS
                -- mapImage вже знаходиться в scene.tempMapGroup
                local cameraGroup = MAS:init(scene.tempMapGroup)
                scene.view:insert(cameraGroup)
                
                cameraGroup.x = display.contentCenterX
                cameraGroup.y = display.contentCenterY
                MAS:start(cameraGroup)
                
                
               
                
            else
                -- Оновлення прогресу рендеру
                if data and data.progress then
                    loadingText.text = data.status
                    -- Друга половина бару (від 50% до 100%)
                    loadingBarFill.width = 148 + (148 * data.progress)
                end
            end
        end
    end
end

function scene:show(event)
    if event.phase == "did" then
    local params = inputParams or {
            width = 200,
            height = 200,
            seed = os.time(),
            scale =80, 
            enableOcean = true,
            enableRivers = true,
            riverCount = 40,
            landPercent = "80"
        }        
        self.genParams = params
        
        -- Скидаємо стани
        currentState = STATE_GEN
        renderingCo = nil
        mapGridData = nil
        
        loadingText.text = "Generating Data..."
        loadingBarFill.width = 0
        
        -- Створюємо першу корутину (Генерація чисел)
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