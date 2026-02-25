-- src/scripts/core/SpawnManager.lua
local Building = require("src.scripts.models.Building")
local Logger = require("src.scripts.utils.logger")

local SpawnManager = {}

-- Допоміжна функція для стартової території
    local function claimInitialTerritory(world, cx, cy, radius, playerId)
        for y = cy - radius, cy + radius do
            for x = cx - radius, cx + radius do
                if x >= 1 and x <= world.width and y >= 1 and y <= world.height then
                    local dist = math.abs(x - cx) + math.abs(y - cy)
                    if dist <= radius then
                        local cell = world:getTile(x, y)
                        if cell.biome and cell.biome.gameplay ~= "water" then
                            cell.ownerId = playerId
                        end
                    end
                end
            end
        end
    end

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
            world.nextBuildingId = world.nextBuildingId + 1
            
            -- Записуємо будівлю в світ і гравцю
            table.insert(player.buildings, castle)
            
            -- Зберігаємо координати для розрахунку відстані наступним гравцям
            table.insert(spawnedCastles, {x = bestCand.x, y = bestCand.y})
            
            -- Видаляємо цього кандидата, щоб інші не стали на нього ж
            table.remove(candidates, bestCandIndex)
            local cx, cy = bestCand.x, bestCand.y
            
            -- А) Створюємо стартову територію 
            claimInitialTerritory(world, cx, cy, 5, player.id)

            -- Б) 9 тайлів під замок (3x3)
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local nx, ny = cx + dx, cy + dy
                        if nx >= 1 and nx <= world.width and ny >= 1 and ny <= world.height then
                            local cell = world:getTile(nx, ny)
                        
                            -- Якщо це центр - ставимо головний ID, якщо боки - ставимо "стіну"
                            if dx == 0 and dy == 0 then
                                    cell.buildingId = "castle"
                                    print( player.colorText )
                                    cell.castleColor = player.colorText
                            else
                                    cell.buildingId = "castle_part"
                            end
                        
                            -- Очищаємо об'єкти (дерева/гори), які могли тут згенеруватись
                            cell.biome.props = nil 
                            cell.ownerId = player.id
                        end
                    end
                end
            
                Logger.info("MatchInit", "Player " .. player.id .. " castle placed at " .. cx .. "," .. cy)
            
            
        end
    end
end

return SpawnManager