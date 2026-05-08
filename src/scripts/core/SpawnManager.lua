-- src/scripts/core/SpawnManager.lua
local Building = require("src.scripts.models.Building")
local Logger = require("src.scripts.utils.logger")

local SpawnManager = {}

-- Допоміжна функція для стартової території
local function claimInitialTerritory(world, cx, cy, radius, playerId)
        -- Додаємо 0.5 до радіуса, щоб краї кола на квадратній сітці виглядали акуратніше
        local radiusSq = (radius + 0.5) * (radius + 0.5) 
        
        for y = cy - radius, cy + radius do
            for x = cx - radius, cx + radius do
                if x >= 1 and x <= world.width and y >= 1 and y <= world.height then
                    -- Формула кола: (x - cx)^2 + (y - cy)^2 <= R^2
                    local distSq = (x - cx)^2 + (y - cy)^2
                    if distSq <= radiusSq then
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
                                    --print( player.colorText )
                                    cell.castleColor = player.colorText
                                    

                                    local castleWorldX = math.floor(-((world.width*64) / 2) + (64 / 2)) + (nx-1)  * 64
                                    local castleWorldY = math.floor(-((world.height*64) / 2) + (64 / 2)) + (ny-1)  * 64

                                    -- 2. Рахуємо координати камери (інвертуємо і центруємо по екрану)
                                    local idealCamX = -castleWorldX + display.contentCenterX
                                    local idealCamY = -castleWorldY + display.contentCenterY

                                    -- 3. Записуємо їх гравцю!
                                    player.cameraX = idealCamX
                                    player.cameraY = idealCamY
                            else
                                    cell.buildingId = "castle_part"
                            end
                        
                            -- Очищаємо об'єкти (дерева/гори), які могли тут згенеруватись
                            --cell.biome.props = nil 
                            cell.ownerId = player.id
                        end
                    end
                end
            
                Logger.info("MatchInit", "Player " .. player.id .. " castle placed at " .. cx .. "," .. cy)
            
            
        end
    end
end

-- Функція для перевірки, чи є поруч замки або гори (в radius клітинок)
local function isSafeToPlantTree(grid, cx, cy, radius, mapWidth, mapHeight)
    local minX = math.max(1, cx - radius)
    local maxX = math.min(mapWidth, cx + radius)
    local minY = math.max(1, cy - radius)
    local maxY = math.min(mapHeight, cy + radius)

    for y = minY, maxY do
        for x = minX, maxX do
            local cell = grid[x][y]
            if cell then
                -- Перевіряємо на замок, гору або частину гори
                local isCastle = (cell.buildingId == "castle")
                local isObstaclePart = (cell.buildingId == "obstacle_part")
                local isMountain = (cell.biome and cell.biome.gameplay == "obstacle")
                
                if isCastle or isObstaclePart or isMountain then
                    return false -- Знайшли перешкоду, саджати не можна!
                end
            end
        end
    end
    return true
end

-- Головна функція генерації дерев
function SpawnManager.generateTrees(grid, mapWidth, mapHeight)
    local treeChance = 40 -- Шанс 40% посадити дерево на клітинці лісу
    local spacingRadius = 3 -- Мінімум 3 тайла від замків і гір

    for y = 1, mapHeight do
        for x = 1, mapWidth do
            local cell = grid[x][y]
            
            -- Якщо це ліс і там ще нічого не збудовано
            if cell.biome.gameplay == "forest" and not cell.buildingId then
                -- Перевіряємо сусідів
                if isSafeToPlantTree(grid, x, y, spacingRadius, mapWidth, mapHeight) then
                    -- Кидаємо кубик
                    
                    if math.random(1, 100) <= treeChance then
                        cell.buildingId = "tree"
                        cell.treeCFG = {type = math.random(1,2), dx = math.random(-8,8), dy = math.random(-8,8)}
                    end
                    
                end
            end
        end
    end
end

return SpawnManager