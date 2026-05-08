-- src/scripts/world/WorldManager.lua
local WorldManager = {}

local WorldGenerator = require("src.scripts.world.WorldGenerator")
local WorldConfig = require("src.scripts.config.WorldConfig")
local Logger = require("src.scripts.utils.logger")

function WorldManager.generateWorld(parentGroup, customConfig, callbacks)
    local config = customConfig or WorldConfig
    
    local generationCo = WorldGenerator.createGenerationCoroutine(config)

    local function onFrame(event)
        local timeBudget = 15 -- 15мс на кадр
        local startFrame = system.getTimer()
        
        while (system.getTimer() - startFrame < timeBudget) do
            if coroutine.status(generationCo) == "dead" then return end
            
            local success, data = coroutine.resume(generationCo)
            
            if not success then
                Runtime:removeEventListener("enterFrame", onFrame)
                if callbacks.onError then callbacks.onError("Gen Error: " .. tostring(data)) end
                return
            end
            
            if coroutine.status(generationCo) == "dead" then
                Runtime:removeEventListener("enterFrame", onFrame)
                if data.status == "Error" then
                    if callbacks.onError then callbacks.onError(data.error) end
                    return
                end
                
                -- ГЕНЕРАЦІЯ ДАНИХ ГОТОВА! Віддаємо тільки grid
                if callbacks.onComplete then
                    callbacks.onComplete({ grid = data.result })
                end
            else
                if callbacks.onProgress then
                    -- Тепер генерація даних - це 100% прогрес-бару
                    callbacks.onProgress(data.status, data.progress)
                end
            end
        end
    end

    Runtime:addEventListener("enterFrame", onFrame)
end

return WorldManager