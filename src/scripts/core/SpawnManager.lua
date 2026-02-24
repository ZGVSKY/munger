-- src/scripts/core/SpawnManager.lua
local Building = require("src.scripts.models.Building")
local Logger = require("src.scripts.utils.logger")

local SpawnManager = {}

--- Головна функція розстановки Замків
-- @param world (World)
-- @param players (table) Масив гравців
function SpawnManager.spawnCastles(world, players)
    Logger.info("Spawn", "Starting Castle placement algorithm...")
    
    local candidates = {}
    
    -- 1. Знаходимо всі потенційні місця і даємо їм "Ресурсну Оцінку"
    for x = 1, world.width do
        for y = 1, world.height do
            local cell = world:getTile(x, y)
            
            -- Замок можна ставити тільки на землі
            if cell and cell.biome.gameplay == "ground" then
                local score = 0
                local hasForest = false
                local hasMountain = false
                
                -- Скануємо радіус 5 тайлів навколо
                for dx = -5, 5 do
                    for dy = -5, 5 do
                        local nx, ny = x + dx, y + dy
                        local nCell = world:getTile(nx, ny)
                        if nCell then
                            if nCell.biome.gameplay == "forest" then hasForest = true end
                            if nCell.biome.gameplay == "obstacle" then hasMountain = true end
                        end
                    end
                end
                
                if hasForest then score = score + 50 end
                if hasMountain then score = score + 50 end
                
                -- Якщо є хоча б один ресурс поруч - це хороший кандидат
                if score > 0 then
                    table.insert(candidates, {x = x, y = y, resScore = score})
                end
            end
        end
    end
    
    if #candidates == 0 then
        Logger.error("Spawn", "CRITICAL: No suitable land found for castles!")
        return
    end

    -- 2. Жадібний алгоритм розстановки (максимальна відстань)
    local spawnedCastles = {}
    
    for _, player in ipairs(players) do
        local bestCand = nil
        local bestFinalScore = -math.huge
        local bestCandIndex = 1
        
        for i, cand in ipairs(candidates) do
            -- Знаходимо відстань до НАЙБЛИЖЧОГО вже поставленого замку
            local minDistToOthers = math.huge
            for _, sc in ipairs(spawnedCastles) do
                -- Теорема Піфагора
                local dist = math.sqrt((cand.x - sc.x)^2 + (cand.y - sc.y)^2)
                if dist < minDistToOthers then 
                    minDistToOthers = dist 
                end
            end
            
            -- Якщо це перший гравець, ігноруємо відстань
            if minDistToOthers == math.huge then minDistToOthers = 1 end
            
            -- Фінальна оцінка = Відстань (важить дуже багато) + Ресурсна оцінка
            local finalScore = (minDistToOthers * 10) + cand.resScore
            
            if finalScore > bestFinalScore then
                bestFinalScore = finalScore
                bestCand = cand
                bestCandIndex = i
            end
        end
        
        -- Створюємо замок на знайденому місці
        if bestCand then
            local castle = Building.new(world.nextBuildingId, player.id, "castle", bestCand.x, bestCand.y)
            world.nextBuildingId = world.nextBuildingId + 1
            
            -- Записуємо будівлю в світ і гравцю
            world:getTile(bestCand.x, bestCand.y).buildingId = castle.id
            table.insert(player.buildings, castle)
            
            -- Зберігаємо координати для розрахунку відстані наступним гравцям
            table.insert(spawnedCastles, {x = bestCand.x, y = bestCand.y})
            
            -- Видаляємо цього кандидата, щоб інші не стали на нього ж
            table.remove(candidates, bestCandIndex)
            
            Logger.info("Spawn", "Player " .. player.id .. " castle placed at " .. bestCand.x .. ", " .. bestCand.y)
        end
    end
end

return SpawnManager