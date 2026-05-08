-- src/scripts/world/WorldGenerator.lua
local WorldGenerator = {}

-- Імпорти
local Perlin = require("src.scripts.utils.ModernPerlin")
local Logger = require("src.scripts.utils.logger")
local Biomes = require("src.scripts.config.Biomes")
local WorldConfig = require("src.scripts.config.WorldConfig")
local GridUtils = require("src.scripts.utils.GridUtils") -- Наша нова чиста математика

--------------------------------------------------------------------------------
-- ПРИВАТНІ ФУНКЦІЇ ДЛЯ КОНКРЕТНИХ ЕТАПІВ ГЕНЕРАЦІЇ
--------------------------------------------------------------------------------

local function traceRiver(grid, startX, startY, config)
    local curr = grid[startX][startY]
    local path = {}
    local pathLength = 0
    local visited = {}
    local prevDx, prevDy = 0, 0 
    
    local MAX_RIVER_STEPS = 300 -- ЗАПОБІЖНИК: Захист від нескінченного циклу (Bottleneck fix)

    -- ПРОХІД 1: Шукаємо шлях до моря
    while true do
        table.insert(path, curr)
        visited[curr.x .. "," .. curr.y] = true
        pathLength = pathLength + 1

        -- Умова виходу (море, або запобіжник)
        if curr.height <= config.GEO.seaLevel or pathLength > MAX_RIVER_STEPS then break end

        local candidates = {}
        for dx = -1, 1 do
            for dy = -1, 1 do
                if not (dx == 0 and dy == 0) then
                    local nx, ny = curr.x + dx, curr.y + dy
                    if nx > 0 and nx <= config.MAP_WIDTH and ny > 0 and ny <= config.MAP_HEIGHT then
                        local nCell = grid[nx][ny]
                        if nCell.height <= curr.height and not visited[nx .. "," .. ny] then
                            table.insert(candidates, {cell = nCell, dx = dx, dy = dy})
                        end
                    end
                end
            end
        end

        if #candidates == 0 then
            curr.isLake = true -- Яма -> Створюємо Озеро
            break
        end

        local bestScore = -math.huge
        local nextCell, nextDx, nextDy = nil, 0, 0

        for _, cand in ipairs(candidates) do
            local drop = (curr.height - cand.cell.height) * 10
            local score = drop
            
            if prevDx ~= 0 or prevDy ~= 0 then
                local dotProduct = (cand.dx * prevDx) + (cand.dy * prevDy)
                score = score + (dotProduct * 0.5) 
            end
            
            score = score + (math.random() * 1.5)

            if score > bestScore then
                bestScore = score
                nextCell = cand.cell
                nextDx = cand.dx
                nextDy = cand.dy
            end
        end

        curr = nextCell
        prevDx, prevDy = nextDx, nextDy
    end

    -- ПРОХІД 2: Малюємо річку (Екскаватор)
    local totalLength = #path
    if totalLength < 5 then return end 

    for i, cell in ipairs(path) do
        local progress = i / totalLength
        local idealRadius = 1 + math.sin(progress * math.pi) * 1.5
        local noise = math.random(-30, 30) / 100.0
        local waterRadius = math.max(0.5, idealRadius + noise)
        local valleyRadius = waterRadius + 2.0 
        local vInt = math.ceil(valleyRadius)

        for dx = -vInt, vInt do
            for dy = -vInt, vInt do
                local distSq = dx*dx + dy*dy
                local nx, ny = cell.x + dx, cell.y + dy
                
                if nx >= 1 and nx <= config.MAP_WIDTH and ny >= 1 and ny <= config.MAP_HEIGHT then
                    if distSq <= waterRadius * waterRadius then
                        grid[nx][ny].isRiver = true
                    elseif distSq <= valleyRadius * valleyRadius then
                        grid[nx][ny].isValley = true
                    end
                end
            end
        end
    end
end

local function addRiverMoisture(grid, config)
    for x = 1, config.MAP_WIDTH do
        for y = 1, config.MAP_HEIGHT do
            local cell = grid[x][y]
            if cell.isRiver or cell.isLake then
                for dx = -2, 2 do
                    for dy = -2, 2 do
                        local nx, ny = x+dx, y+dy
                        if nx > 0 and nx <= config.MAP_WIDTH and ny > 0 and ny <= config.MAP_HEIGHT then
                            local dist = math.sqrt(dx*dx + dy*dy)
                            local bonus = 0.25 / (dist + 0.1)
                            grid[nx][ny].moisture = math.min(1, grid[nx][ny].moisture + bonus)
                        end
                    end
                end
            end
        end
    end
end

local function calculateLakeDepth(grid, config)
    local queue = {}
    
    for x = 1, config.MAP_WIDTH do
        for y = 1, config.MAP_HEIGHT do
            local cell = grid[x][y]
            if cell.isLake then
                cell.lakeDepth = nil 
                local touchesLand = false
                local neighbors = { {x=x+1, y=y}, {x=x-1, y=y}, {x=x, y=y+1}, {x=x, y=y-1} }
                
                for _, n in ipairs(neighbors) do
                    if n.x >= 1 and n.x <= config.MAP_WIDTH and n.y >= 1 and n.y <= config.MAP_HEIGHT then
                        if grid[n.x][n.y].height >= config.GEO.seaLevel then
                            touchesLand = true
                            break
                        end
                    end
                end
                
                if touchesLand then
                    cell.lakeDepth = 1
                    table.insert(queue, cell)
                end
            end
        end
    end
    
    local head = 1
    while head <= #queue do
        local current = queue[head]
        head = head + 1
        
        local neighbors = { {x=current.x+1, y=current.y}, {x=current.x-1, y=current.y}, {x=current.x, y=current.y+1}, {x=current.x, y=current.y-1} }
        for _, n in ipairs(neighbors) do
            if n.x >= 1 and n.x <= config.MAP_WIDTH and n.y >= 1 and n.y <= config.MAP_HEIGHT then
                local neighbor = grid[n.x][n.y]
                if neighbor.isLake and neighbor.lakeDepth == nil then
                    neighbor.lakeDepth = current.lakeDepth + 1
                    table.insert(queue, neighbor)
                end
            end
        end
    end
end

local function enforceCoastlines(grid, config)
    local waterToSand = {}

    for x = 1, config.MAP_WIDTH do
        for y = 1, config.MAP_HEIGHT do
            local cell = grid[x][y]
            if cell.biome.gameplay == "water" then
                local touchesGrass = false
                local neighbors = { 
                    {-1, -1}, {0, -1}, {1, -1},
                    {-1,  0},          {1,  0},
                    {-1,  1}, {0,  1}, {1,  1} 
                }
                
                for _, dir in ipairs(neighbors) do
                    local nx, ny = x + dir[1], y + dir[2]
                    if nx >= 1 and nx <= config.MAP_WIDTH and ny >= 1 and ny <= config.MAP_HEIGHT then
                        local neighborGameplay = grid[nx][ny].biome.gameplay
                        if neighborGameplay == "ground" or neighborGameplay == "forest" then
                            touchesGrass = true
                            break
                        end
                    end
                end
                
                if touchesGrass then table.insert(waterToSand, cell) end
            end
        end
    end

    for _, cell in ipairs(waterToSand) do
        -- Використовуємо конфіг для висоти берега
        cell.biome = Biomes.TYPES.BEACH
        cell.type = cell.biome.id
        cell.gameplay = "coast" -- Надійно фіксуємо геймплей
        
        -- Очищаємо згладжений синій колір води, щоб рендер взяв жовтий колір піску з біома!
        cell.renderColor = nil
    end
end

local function controlClusterSizes(grid, config, targetType, minSize, maxSize)
    local visited = {}
    
    for x = 1, config.MAP_WIDTH do
        for y = 1, config.MAP_HEIGHT do
            if grid[x][y].biome.gameplay == targetType and not visited[x..","..y] then
                
                local cluster = {}
                local queue = {grid[x][y]}
                local head = 1
                visited[x..","..y] = true
                
                while head <= #queue do
                    local curr = queue[head]
                    head = head + 1
                    table.insert(cluster, curr)
                    
                    local neighbors = { {1,0}, {-1,0}, {0,1}, {0,-1} }
                    for _, dir in ipairs(neighbors) do
                        local nx, ny = curr.x + dir[1], curr.y + dir[2]
                        if nx >= 1 and nx <= config.MAP_WIDTH and ny >= 1 and ny <= config.MAP_HEIGHT then
                            if grid[nx][ny].biome.gameplay == targetType and not visited[nx..","..ny] then
                                visited[nx..","..ny] = true
                                table.insert(queue, grid[nx][ny])
                            end
                        end
                    end
                end
                
                if #cluster < minSize then
                    for _, cell in ipairs(cluster) do
                        cell.biome = Biomes.getBiome(0.4, cell.moisture, false, nil)
                        cell.type = cell.biome.id
                    end
                elseif #cluster > maxSize then
                    local toRemove = #cluster - maxSize
                    local edgeQueue = {}
                    local isEdge = {}
                    
                    for _, cell in ipairs(cluster) do
                        local hasOuterNeighbor = false
                        local neighbors = { {1,0}, {-1,0}, {0,1}, {0,-1} }
                        for _, dir in ipairs(neighbors) do
                            local nx, ny = cell.x + dir[1], cell.y + dir[2]
                            if nx >= 1 and nx <= config.MAP_WIDTH and ny >= 1 and ny <= config.MAP_HEIGHT then
                                if grid[nx][ny].biome.gameplay ~= targetType then
                                    hasOuterNeighbor = true
                                    break
                                end
                            end
                        end
                        if hasOuterNeighbor then
                            table.insert(edgeQueue, cell)
                            isEdge[cell.x..","..cell.y] = true
                        end
                    end
                    
                    local removedCount = 0
                    local eqHead = 1
                    
                    while removedCount < toRemove and eqHead <= #edgeQueue do
                        local curr = edgeQueue[eqHead]
                        eqHead = eqHead + 1
                        
                        curr.biome = Biomes.getBiome(0.4, curr.moisture, false, nil)
                        curr.type = curr.biome.id
                        removedCount = removedCount + 1
                        
                        local neighbors = { {1,0}, {-1,0}, {0,1}, {0,-1} }
                        for _, dir in ipairs(neighbors) do
                            local nx, ny = curr.x + dir[1], curr.y + dir[2]
                            if nx >= 1 and nx <= config.MAP_WIDTH and ny >= 1 and ny <= config.MAP_HEIGHT then
                                local nCell = grid[nx][ny]
                                if nCell.biome.gameplay == targetType and not isEdge[nx..","..ny] then
                                    isEdge[nx..","..ny] = true
                                    table.insert(edgeQueue, nCell)
                                end
                            end
                        end
                    end
                end
                
            end
        end
    end
end

local function smoothBiomeColors(grid, config)
    local blurRadius = config.POST_PROCESS.smoothColorsRadius
    local width, height = config.MAP_WIDTH, config.MAP_HEIGHT
    local tempColors = {}
    for x = 1, width do tempColors[x] = {} end

    -- ОПТИМІЗАЦІЯ: Уникаємо створення зайвих таблиць у внутрішніх циклах
    for x = 1, width do
        for y = 1, height do
            local cell = grid[x][y]
            local gameplayType = cell.biome and cell.biome.gameplay or "water"
            
            if gameplayType == "ground" or gameplayType == "water" then
                local r, g, b = 0, 0, 0
                local count = 0
                
                for nx = x - blurRadius, x + blurRadius do
                    if nx >= 1 and nx <= width then
                        local column = grid[nx]
                        for ny = y - blurRadius, y + blurRadius do
                            if ny >= 1 and ny <= height then
                                local nCell = column[ny]
                                local nGameplay = nCell.biome and nCell.biome.gameplay or "water"
                                if nGameplay == gameplayType and nCell.biome and nCell.biome.color then
                                    local c = nCell.biome.color
                                    r = r + c[1]
                                    g = g + c[2]
                                    b = b + c[3]
                                    count = count + 1
                                end
                            end
                        end
                    end
                end
                
                if count > 0 then
                    tempColors[x][y] = { r / count, g / count, b / count }
                else
                    tempColors[x][y] = cell.biome.color
                end
            else
                tempColors[x][y] = cell.biome.color
            end
        end
    end

    for x = 1, width do
        for y = 1, height do
            grid[x][y].renderColor = tempColors[x][y]
        end
    end
end

-- ==========================================
-- ПОСТ-ОБРОБКА ГІР (Створення масивів гір та тіней)
-- Виклич цю функцію після генерації всіх біомів!
-- ==========================================
function processObstacles(grid, width, height)
    for y = 1, height do
        for x = 1, width do
            local cell = grid[x][y]
            
            if cell.biome and cell.biome.gameplay == "obstacle" then
                -- 1. СТВОРЕННЯ HIGH_OBSTACLE (Двошарові гори)
                -- Якщо навколо цієї гори з усіх 4 боків теж є гори - робимо її високою!
                local isSurrounded = true
                local neighbors = {{0,-1}, {0,1}, {-1,0}, {1,0}}
                
                for _, n in ipairs(neighbors) do
                    local nx, ny = x + n[1], y + n[2]
                    if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
                        local nGameplay = grid[nx][ny].biome.gameplay
                        if nGameplay ~= "obstacle" and nGameplay ~= "high_obstacle" then
                            isSurrounded = false
                            break
                        end
                    end
                end
                
                if isSurrounded and math.random() > 0.4 then
                    cell.biome.gameplay = "high_obstacle" -- Змінюємо тип!
                end

                -- 2. ЗАХИСТ ВІД ДЕКОРАЦІЙ (Розмічаємо підніжжя)
                -- Розмічаємо тайли знизу та по діагоналях, де буде намальована тінь/база гори
                local parts = {{0,1}, {0,2}, {-1,1}, {1,1}, {-1,2}, {1,2}}
                for _, p in ipairs(parts) do
                    local tx, ty = x + p[1], y + p[2]
                    if tx >= 1 and tx <= width and ty >= 1 and ty <= height then
                        -- Ставимо прапорець, що це тінь гори. На ній НЕ БУДЕ рости трава.
                        grid[tx][ty].isObstaclePart = true 
                    end
                end
            end
        end
    end
end

--- Створює корутину генерації світу
--------------------------------------------------------------------------------
-- ПУБЛІЧНИЙ ІНТЕРФЕЙС
--------------------------------------------------------------------------------

--- Створює корутину генерації світу
function WorldGenerator.createGenerationCoroutine(customConfig)
    return coroutine.create(function()
        local config = customConfig or WorldConfig
        local grid = {}
        local stepsDone = 0
        local totalSteps = config.MAP_WIDTH * config.MAP_HEIGHT

        Logger.info("Gen", "Starting generation pipeline with seed: " .. config.SEED)

        -- ФАЗА 1: Висота
        Logger.info("Gen", "Phase 1: Height Map")
        local mScale = config.GEN.scale * config.GEN.mountainScaleMult
        for x = 1, config.MAP_WIDTH do
            grid[x] = {}
            for y = 1, config.MAP_HEIGHT do
                local baseH = Perlin.getFractalNoise_Fast(x, y, config.SEED, config.GEN.octaves, config.GEN.persistence, config.GEN.scale)
                local mountH = Perlin.getFractalNoise_Fast(x, y, config.SEED + 12345, 5, config.GEN.persistence, mScale)
                
                grid[x][y] = {
                    x = x, y = y,
                    height = baseH * 0.6 + mountH * 0.4,
                    moisture = 0,
                    type = "void"
                }
                stepsDone = stepsDone + 1
            end
            if x % 10 == 0 then
                coroutine.yield({ status = "Terraforming...", progress = (stepsDone / totalSteps) * 0.2 })
            end
        end

        GridUtils.normalizeGrid(grid, config.MAP_WIDTH, config.MAP_HEIGHT)

        -- ФАЗА 2: Маска острова
        if config.GEO.enableOcean then
            Logger.info("Gen", "Phase 2: Island Mask")
            GridUtils.applyIslandMask(grid, config.MAP_WIDTH, config.MAP_HEIGHT, config.GEO.landPercent)
            GridUtils.normalizeGrid(grid, config.MAP_WIDTH, config.MAP_HEIGHT)
            coroutine.yield({ status = "Sculpting Coastlines...", progress = 0.4 })
        end

        -- ФАЗА 3: Озера та Глибина
        Logger.info("Gen", "Phase 3: Lake Depths")
        calculateLakeDepth(grid, config)

        -- ФАЗА 4: Річки
        if config.GEO.enableRivers then
            Logger.info("Gen", "Phase 4: Hydrology (Rivers)")
            local riversSpawned = 0
            for i = 1, config.GEO.riverCount * 2 do
                local rx = math.random(1, config.MAP_WIDTH)
                local ry = math.random(1, config.MAP_HEIGHT)
                if grid[rx][ry].height > config.GEO.riverStartHeight then
                    traceRiver(grid, rx, ry, config)
                    riversSpawned = riversSpawned + 1
                    if riversSpawned >= config.GEO.riverCount then break end
                end
            end
            coroutine.yield({ status = "Filling Rivers...", progress = 0.6 })
        end

        -- ФАЗА 5: Вологість
        Logger.info("Gen", "Phase 5: Moisture Map")
        local moistSeed = config.SEED + config.GEN.moistureOffset
        local moistScale = config.GEN.scale * config.GEN.moistureScaleMult
        for x = 1, config.MAP_WIDTH do
            for y = 1, config.MAP_HEIGHT do
                grid[x][y].moisture = Perlin.getFractalNoise_Fast(x, y, moistSeed, 3, 0.5, moistScale)
            end
        end
        if config.GEO.enableRivers then addRiverMoisture(grid, config) end
        coroutine.yield({ status = "Watering Plants...", progress = 0.7 })

        -- ФАЗА 6: Класифікація Біомів
        Logger.info("Gen", "Phase 6: Biomes")
        for x = 1, config.MAP_WIDTH do
            for y = 1, config.MAP_HEIGHT do
                local cell = grid[x][y]
                cell.biome = Biomes.getBiome(cell.height, cell.moisture, cell.isLake, cell.lakeDepth)
                
                if cell.isValley and cell.biome.gameplay == "obstacle" then
                    cell.biome = Biomes.getBiome(config.POST_PROCESS.valleyHeight, config.POST_PROCESS.valleyMoisture, false, nil)
                end
                
                cell.type = cell.biome.id
                
                if cell.isRiver and cell.height >= config.GEO.seaLevel then
                    cell.biome = { id = "river", gameplay = "river", color = {0.2, 0.6, 0.8} }
                    cell.type = "river"
                end
            end
        end

        -- ФАЗА 7: Пост-обробка
        Logger.info("Gen", "Phase 7: Post-Processing Shapes")
        controlClusterSizes(grid, config, "forest", config.POST_PROCESS.forestMinSize, config.POST_PROCESS.forestMaxSize)
        --controlClusterSizes(grid, config, "obstacle", config.POST_PROCESS.obstacleMinSize, config.POST_PROCESS.obstacleMaxSize)
        enforceCoastlines(grid, config)
        processObstacles(grid, config.MAP_WIDTH, config.MAP_HEIGHT)
        coroutine.yield({status="Post-Processing...", progress=0.90})

        -- ФАЗА 8: Згладжування кольорів
        Logger.info("Gen", "Phase 8: Smoothing Colors")
        smoothBiomeColors(grid, config)

        coroutine.yield({ status = "Finalizing Map...", progress = 1.0 })
        return { status = "Done", result = grid }
    end)
end

return WorldGenerator