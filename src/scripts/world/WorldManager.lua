-- src/scripts/world/WorldManager.lua
local WorldManager = {}

local WorldGenerator = require("src.scripts.world.WorldGenerator")
local MapRenderer = require("src.scripts.world.MapRenderer")
local WorldConfig = require("src.scripts.config.WorldConfig")
local Logger = require("src.scripts.utils.logger")

--- Головна функція створення світу
-- @param parentGroup Група, в яку буде поміщений відрендерений світ
-- @param customConfig Таблиця з налаштуваннями (якщо nil, береться дефолтний WorldConfig)
-- @param callbacks Таблиця з функціями: onProgress(text, percent), onComplete(mapGroup), onError(msg)
function WorldManager.generateWorld(parentGroup, customConfig, callbacks)
    local config = customConfig or WorldConfig
    
    local generationCo = WorldGenerator.createGenerationCoroutine(config)
    local renderingCo = nil
    local mapGridData = nil
    local currentState = "GEN"

    -- Внутрішній цикл (раніше він був у loading.lua)
    local function onFrame(event)
        local timeBudget = 15 -- 15мс на кадр
        local startFrame = system.getTimer()
        
        while (system.getTimer() - startFrame < timeBudget) do
            
            if currentState == "GEN" then
                if coroutine.status(generationCo) == "dead" then return end
                
                local success, data = coroutine.resume(generationCo)
                
                if not success then
                    Runtime:removeEventListener("enterFrame", onFrame)
                    if callbacks.onError then callbacks.onError("Gen Engine Error: " .. tostring(data)) end
                    return
                end
                
                if coroutine.status(generationCo) == "dead" then
                    if data.status == "Error" then
                        Runtime:removeEventListener("enterFrame", onFrame)
                        if callbacks.onError then callbacks.onError(data.error) end
                        return
                    end
                    
                    -- Перехід до рендеру
                    mapGridData = data.result
                    currentState = "RENDER"
                    renderingCo = MapRenderer.createRenderCoroutine(mapGridData, parentGroup, config)
                else
                    if callbacks.onProgress then
                        -- Генерація займає перші 50% прогрес-бару
                        callbacks.onProgress(data.status, data.progress * 0.5)
                    end
                end
                
            elseif currentState == "RENDER" then
                if not renderingCo or coroutine.status(renderingCo) == "dead" then return end
                
                local success, data = coroutine.resume(renderingCo)
                
                if not success then
                    Runtime:removeEventListener("enterFrame", onFrame)
                    if callbacks.onError then callbacks.onError("Render Engine Error: " .. tostring(data)) end
                    return
                end
                
                if coroutine.status(renderingCo) == "dead" then
                    Runtime:removeEventListener("enterFrame", onFrame)
                    if data.status == "Error" then
                        if callbacks.onError then callbacks.onError(data.error) end
                        return
                    end
                    
                    -- ВСЕ ГОТОВО!
                    if callbacks.onComplete then
                        callbacks.onComplete({map = data.result, grid = mapGridData, mapImage = data.map, topMapImage=data.topMapImage})
                    end
                else
                    if callbacks.onProgress then
                        -- Рендер займає другі 50% прогрес-бару
                        callbacks.onProgress(data.status, 0.5 + (data.progress * 0.5))
                    end
                end
            end
        end
    end

    -- Запускаємо процес
    Runtime:addEventListener("enterFrame", onFrame)
end

return WorldManager