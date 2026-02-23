-- src/scripts/world/WorldGenerator.lua
local WorldGenerator = {}

-- Імпорти
local Perlin = require("src.scripts.utils.ModernPerlin")
local Logger = require("src.scripts.utils.logger")
local Biomes = require("src.scripts.config.Biomes")

--------------------------------------------------------------------------------
-- Приватні допоміжні функції
--------------------------------------------------------------------------------

-- Маска острова (Градієнт від центру)
local function applyIslandMask(grid, width, height, landPercent)
    local centerX = width / 2
    local centerY = height / 2
    
    -- Якщо landPercent = 60, то plateauSize = 0.6.
    -- Це означає, що 60% радіусу - це чистий шум, а далі йде спад у воду.
    local plateauSize = (landPercent / 100) 

    for x = 1, width do
        for y = 1, height do
            local nx = (x - centerX) / (width / 2)
            local ny = (y - centerY) / (height / 2)
            
            -- Відстань від центру (0..1)
            -- Використовуємо трішки "квадратну" відстань для кращого заповнення кутів
            -- Але для початку звичайна евклідова (коло/еліпс) найнадійніша
            local dist = math.sqrt(nx*nx + ny*ny)
            
            local maskVal = 1.0
            
            if dist > plateauSize then
                -- Плавний спад
                local distanceToEdge = (dist - plateauSize) / (1.0 - plateauSize)
                maskVal = math.cos(distanceToEdge * (math.pi / 2))
                
                if dist >= 1.0 then maskVal = 0 end
                if maskVal < 0 then maskVal = 0 end
            end
            
            -- Множимо висоту на маску
            grid[x][y].height = grid[x][y].height * maskVal
        end
    end
end

-- Розтягує діапазон висот на повні 0..1
local function normalizeGrid(grid, width, height)
    local minH = 10000
    local maxH = -10000
    
    -- 1. Знаходимо екстремуми
    for x = 1, width do
        for y = 1, height do
            local h = grid[x][y].height
            if h < minH then minH = h end
            if h > maxH then maxH = h end
        end
    end
    
    -- Захист від ділення на нуль
    if maxH == minH then return end
    
    local range = maxH - minH
    
    -- 2. Розтягуємо
    for x = 1, width do
        for y = 1, height do
            grid[x][y].height = (grid[x][y].height - minH) / range
        end
    end
    Logger.info("Gen", "Normalized range: " .. string.format("%.2f", minH) .. " .. " .. string.format("%.2f", maxH))
end

-- Знаходить найнижчого сусіда для клітинки (x, y)
local function getLowestNeighbor(grid, x, y, width, height)
    local minH = grid[x][y].height
    local lowestCell = nil

    -- Перевіряємо 8 сусідів
    for dx = -1, 1 do
        for dy = -1, 1 do
            if not (dx == 0 and dy == 0) then
                local nx, ny = x + dx, y + dy
                -- Перевірка меж карти
                if nx > 0 and nx <= width and ny > 0 and ny <= height then
                    local neighbor = grid[nx][ny]
                    if neighbor.height < minH then
                        minH = neighbor.height
                        lowestCell = neighbor
                    end
                end
            end
        end
    end
    return lowestCell
end

-- Нова функція для прокладання шляху річки "слегка випишва капля летнього дождя"
local function traceRiver(grid, startX, startY, width, height, seaLevel)
    local curr = grid[startX][startY]
    local path = {}
    local pathLength = 0
    local visited = {}
    
    local prevDx, prevDy = 0, 0 -- Для інерції (щоб річка плавно звивалась)

    --  Шукаємо шлях до моря 
    while true do
        table.insert(path, curr)
        visited[curr.x .. "," .. curr.y] = true
        pathLength = pathLength + 1

        -- Зупиняємось, якщо дійшли до моря або річка занадто довга
        if curr.height <= seaLevel or pathLength > 250 then
            break
        end

        -- Шукаємо сусідів, які нижче або на тому ж рівні
        local candidates = {}
        for dx = -1, 1 do
            for dy = -1, 1 do
                if not (dx == 0 and dy == 0) then
                    local nx, ny = curr.x + dx, curr.y + dy
                    if nx > 0 and nx <= width and ny > 0 and ny <= height then
                        local nCell = grid[nx][ny]
                        -- Перевіряємо, щоб вода текла вниз і не йшла по колу
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

        -- Вибираємо найкращого сусіда з урахуванням нахилу, інерції та випадковості
        local bestScore = -9999
        local nextCell = nil
        local nextDx, nextDy = 0, 0

        for _, cand in ipairs(candidates) do
            -- Нахил чим стрімкіше вниз, тим краще
            local drop = (curr.height - cand.cell.height) * 10
            local score = drop
            
            -- Інерція 
            if prevDx ~= 0 or prevDy ~= 0 then
                local dotProduct = (cand.dx * prevDx) + (cand.dy * prevDy)
                score = score + (dotProduct * 0.5) 
            end
            
            -- Додаємо випадковий шум для органічних вигинів
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

    -- Малюємо річку змінної ширини 
    local totalLength = #path
    if totalLength < 5 then return end -- Ігноруємо надто короткі струмочки

    for i, cell in ipairs(path) do
        -- Прогрес від 0.0 (витік) до 1.0 (гирло)
        local progress = i / totalLength
        
        -- math.sin дає дугу: 0 на старті, 1 в центрі, 0 в кінці.
        -- Базовий радіус 0.5 (1 тайл), плюс потовщення до +1.5 тайла в центрі.
        local progress = i / totalLength
        
        -- Радіус самої води
        local idealRadius = 1 + math.sin(progress * math.pi) * 1.5
        local noise = math.random(-30, 30) / 100.0
        local waterRadius = math.max(0.5, idealRadius + noise)
        
        -- Радіус ДОЛИНИ (на 2 тайли ширше за воду)
        local valleyRadius = waterRadius + 2.0 
        
        local vInt = math.ceil(valleyRadius)

        -- Зафарбовуємо коло (екскаватор тепер більший)
        for dx = -vInt, vInt do
            for dy = -vInt, vInt do
                local distSq = dx*dx + dy*dy
                local nx, ny = cell.x + dx, cell.y + dy
                
                if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
                    -- Якщо ми всередині радіусу води
                    if distSq <= waterRadius * waterRadius then
                        grid[nx][ny].isRiver = true
                    
                    -- Якщо ми ЗА межами води, але в межах долини
                    elseif distSq <= valleyRadius * valleyRadius then
                        grid[nx][ny].isValley = true
                    end
                end
            end
        end
    end
end


-- Додає вологість навколо річок та озер
local function addRiverMoisture(grid, width, height)
    for x = 1, width do
        for y = 1, height do
            local cell = grid[x][y]
            if cell.isRiver or cell.isLake then
                -- Радіус впливу річки  - тільки сусіди
                for dx = -2, 2 do
                    for dy = -2, 2 do
                        local nx, ny = x+dx, y+dy
                        if nx>0 and nx<=width and ny>0 and ny<=height then
                            -- Додаємо вологу (чим ближче, тим більше)
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

local function smoothBiomeColors(grid, width, height, blurRadius)
    Logger.info("Gen", "Smoothing biome colors...")
    local tempColors = {}

    -- 1. Збираємо кольори
    for x = 1, width do
        tempColors[x] = {}
        for y = 1, height do
            local cell = grid[x][y]
            
            -- Якщо це не "ground" (не земля), ми його не змішуємо, залишаємо як є
            local gameplayType = cell.biome and cell.biome.gameplay or "water"
            if gameplayType == "ground" or gameplayType == "water" then
                local r, g, b = 0, 0, 0
                local count = 0
                
                for nx = x - blurRadius, x + blurRadius do
                    for ny = y - blurRadius, y + blurRadius do
                        if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
                            local nCell = grid[nx][ny]
                            local nGameplay = nCell.biome and nCell.biome.gameplay or "water"
                            
                            -- НАЙГОЛОВНІШЕ: Змішуємо тільки зі "своїм" макро-типом
                            -- (Вода з водою, Земля з землею)
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
                
                if count > 0 then
                    tempColors[x][y] = { r / count, g / count, b / count }
                else
                    tempColors[x][y] = cell.biome.color
                end
            else
                -- Для Пляжів (coast) або Гір (obstacle) залишаємо жорсткий колір
                tempColors[x][y] = cell.biome.color
            end
        end
    end

    -- 2. Застосовуємо згладжені кольори до сітки
    for x = 1, width do
        for y = 1, height do
            -- Створюємо нову змінну renderColor, щоб не затерти оригінальний biome.color
            grid[x][y].renderColor = tempColors[x][y]
        end
    end
end

local function calculateLakeDepth(grid, width, height)
    local queue = {}
    
    -- 1. Знаходимо "Берегову лінію" озер
    -- Проходимо по всіх клітинках
    for x = 1, width do
        for y = 1, height do
            local cell = grid[x][y]
            
            if cell.isLake then
                cell.lakeDepth = nil -- Поки що глибина невідома
                
                -- Перевіряємо сусідів: чи є поруч СУША?
                local touchesLand = false
                local neighbors = {
                    {x=x+1, y=y}, {x=x-1, y=y}, {x=x, y=y+1}, {x=x, y=y-1}
                }
                
                for _, n in ipairs(neighbors) do
                    if n.x >= 1 and n.x <= width and n.y >= 1 and n.y <= height then
                        -- Якщо сусід НЕ вода (значить суша або пляж)
                        if grid[n.x][n.y].height >= Biomes.SEA_LEVEL then
                            touchesLand = true
                            break
                        end
                    end
                end
                
                -- Якщо торкається суші - це мілина (глибина 1)
                if touchesLand then
                    cell.lakeDepth = 1
                    table.insert(queue, cell)
                end
            end
        end
    end
    
    -- 2. Розповсюджуємо глибину всередину (BFS)
    local head = 1
    while head <= #queue do
        local current = queue[head]
        head = head + 1
        
        local neighbors = {
            {x=current.x+1, y=current.y}, {x=current.x-1, y=current.y},
            {x=current.x, y=current.y+1}, {x=current.x, y=current.y-1}
        }
        
        for _, n in ipairs(neighbors) do
            if n.x >= 1 and n.x <= width and n.y >= 1 and n.y <= height then
                local neighbor = grid[n.x][n.y]
                
                -- Якщо це озеро і ми ще не виміряли його глибину
                if neighbor.isLake and neighbor.lakeDepth == nil then
                    neighbor.lakeDepth = current.lakeDepth + 1
                    table.insert(queue, neighbor)
                end
            end
        end
    end
    
    -- (Опціонально) Заповнюємо дірки, якщо якісь клітинки залишились nil (наприклад ізольовані в центрі)
    -- Хоча алгоритм BFS має покрити все.
end

-- =========================================================
-- ФУНКЦІЯ 1: Гарантує, що берег має ширину мінімум 1 тайл
-- (Логіка: Вода, яка торкається трави, стає піском)
-- =========================================================
local function enforceCoastlines(grid, width, height)
    Logger.info("Gen", "Enforcing coastlines (Water to Sand, 8-way)...")
    local waterToSand = {}

    for x = 1, width do
        for y = 1, height do
            local cell = grid[x][y]
            
            -- Тепер ми шукаємо ТІЛЬКИ воду
            if cell.biome.gameplay == "water" then
                local touchesGrass = false
                
                -- Перевіряємо всі 8 напрямків (включно з діагоналями)
                local neighbors = { 
                    {-1, -1}, {0, -1}, {1, -1},
                    {-1,  0},          {1,  0},
                    {-1,  1}, {0,  1}, {1,  1} 
                }
                
                for _, dir in ipairs(neighbors) do
                    local nx, ny = x + dir[1], y + dir[2]
                    
                    if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
                        local neighborGameplay = grid[nx][ny].biome.gameplay
                        -- Якщо вода бачить поруч із собою траву або ліс
                        if neighborGameplay == "ground" or neighborGameplay == "forest" then
                            touchesGrass = true
                            break
                        end
                    end
                end
                
                -- Якщо вода торкається зелені, записуємо її в чергу на перетворення
                if touchesGrass then
                    table.insert(waterToSand, cell)
                end
            end
        end
    end

    -- Одночасно перетворюємо всю знайдену воду на пісок
    -- (Це наростить ідеальний пляж на 1 тайл у бік океану)
    for _, cell in ipairs(waterToSand) do
        -- Висота 0.1 відповідає береговій лінії (coast)
        cell.biome = Biomes.getBiome(0.27, cell.moisture, false, nil)
        cell.type = cell.biome.id
    end
end

-- =========================================================
-- ФУНКЦІЯ 2: Контроль розміру кластерів (Лісів та Гір)
-- =========================================================
local function controlClusterSizes(grid, width, height, targetType, minSize, maxSize)
    Logger.info("Gen", "Smoothing clusters for: " .. targetType)
    local visited = {}
    
    for x = 1, width do
        for y = 1, height do
            -- Якщо знайшли потрібний біом і ще не перевіряли його
            if grid[x][y].biome.gameplay == targetType and not visited[x..","..y] then
                
                -- 1. Знаходимо весь кластер (Flood Fill)
                local cluster = {}
                local queue = {grid[x][y]}
                local head = 1
                visited[x..","..y] = true
                
                while head <= #queue do
                    local curr = queue[head]
                    head = head + 1
                    table.insert(cluster, curr)
                    
                    -- Перевіряємо 4 напрямки (хрестом)
                    local neighbors = { {1,0}, {-1,0}, {0,1}, {0,-1} }
                    for _, dir in ipairs(neighbors) do
                        local nx, ny = curr.x + dir[1], curr.y + dir[2]
                        if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
                            if grid[nx][ny].biome.gameplay == targetType and not visited[nx..","..ny] then
                                visited[nx..","..ny] = true
                                table.insert(queue, grid[nx][ny])
                            end
                        end
                    end
                end
                
                -- 2. ВИДАЛЕННЯ: Якщо кластер замалий
                if #cluster < minSize then
                    for _, cell in ipairs(cluster) do
                        -- Перетворюємо на звичайну траву
                        cell.biome = Biomes.getBiome(0.4, cell.moisture, false, nil)
                        cell.type = cell.biome.id
                    end
                
                -- 3. ЕРОЗІЯ: Якщо кластер завеликий
                elseif #cluster > maxSize then
                    local toRemove = #cluster - maxSize
                    local edgeQueue = {}
                    local isEdge = {}
                    
                    -- Знаходимо крайні тайли кластера (ті, що торкаються інших біомів)
                    for _, cell in ipairs(cluster) do
                        local hasOuterNeighbor = false
                        local neighbors = { {1,0}, {-1,0}, {0,1}, {0,-1} }
                        for _, dir in ipairs(neighbors) do
                            local nx, ny = cell.x + dir[1], cell.y + dir[2]
                            if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
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
                    
                    -- Акуратно "відкушуємо" крайні тайли, рухаючись всередину
                    local removedCount = 0
                    local eqHead = 1
                    
                    while removedCount < toRemove and eqHead <= #edgeQueue do
                        local curr = edgeQueue[eqHead]
                        eqHead = eqHead + 1
                        
                        -- Перетворюємо крайній тайл на траву
                        curr.biome = Biomes.getBiome(0.4, curr.moisture, false, nil)
                        curr.type = curr.biome.id
                        removedCount = removedCount + 1
                        
                        -- Додаємо внутрішніх сусідів у чергу на видалення (вони тепер стали краєм)
                        local neighbors = { {1,0}, {-1,0}, {0,1}, {0,-1} }
                        for _, dir in ipairs(neighbors) do
                            local nx, ny = curr.x + dir[1], curr.y + dir[2]
                            if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
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

--------------------------------------------------------------------------------
-- Публічні методи
--------------------------------------------------------------------------------

--- Створює корутину генерації світу
-- @param params (table) Параметри генерації {width, height, seed, seaLevel...}
function WorldGenerator.createGenerationCoroutine(params)
    return coroutine.create(function()
        Logger.info("Gen", "Starting generation pipeline...")
        

        local width = params.width or 50
        local height = params.height or 50
        local seed = params.seed or os.time()
        local seaLevel = Biomes.SEA_LEVEL
        

        local landPercent = params.landPercent or 80
        
        -- Налаштування шуму
        local scale = params.scale or 0.05
        local octaves = params.octaves or 4
        local persistence = params.persistence or 0.5

        local grid = {}
        local stepsDone = 0
        local mountainScale = scale * 2 -- Гори більш часті
        local totalSteps = width * height * 2 -- Поки що 2 проходи (Висота + Маска)

        Logger.info("GEN", "----GENERATOR PARAMETERS FULL INFO----")
        Logger.info("GEN", "Width x Height        |  " .. width         .. "x".. height .. "  |")
        Logger.info("GEN", "Map seed              |  " .. seed          .. "  |")
        Logger.info("GEN", "Sea level for rivers  |  " .. seaLevel      .. "  |")
        Logger.info("GEN", "Lend percent          |  " .. landPercent   .. "  |")
        Logger.info("GEN", "scale                 |  " .. scale         .. "  |")
        Logger.info("GEN", "octaves               |  " .. octaves       .. "  |")
        Logger.info("GEN", "persistence           |  " .. persistence   .. "  |")
        Logger.info("GEN", "mountainScale         |  " .. mountainScale .. "  |")
        Logger.info("GEN", "totalSteps            |  " .. totalSteps    .. "  |")
        Logger.info("GEN", "enable Ocean          |  " .. tostring(params.enableOcean)     .. "  |")
        Logger.info("GEN", "enable Rivers         |  " .. tostring(params.enableRivers)    .. "  |")

        -- 1. Ініціалізація та Висота
        Logger.info("Gen", "Step 1: Generating Height Map")
        
        for x = 1, width do
            grid[x] = {}
            for y = 1, height do
                local baseHeight = Perlin.getFractalNoise_Fast(x, y, seed, octaves, persistence, scale)
                local mountHeight = Perlin.getFractalNoise_Fast(x, y, seed + 12345, 5, persistence, mountainScale)
                local finalHeight = baseHeight * 0.6 + mountHeight * 0.4
                -- Створюємо об'єкт клітинки
                grid[x][y] = {
                    x = x,
                    y = y,
                    height = finalHeight,
                    moisture = 0,
                    type = "void"
                }

                stepsDone = stepsDone + 1
            end
            
            -- Yield кожні 5 рядків, щоб не блокувати UI
            if x % 5 == 0 then
                coroutine.yield({ 
                    status = "Terraforming (" .. math.floor((stepsDone/totalSteps)*100) .. "%)", 
                    progress = stepsDone / totalSteps 
                })
            end
        end

        Logger.info("Gen", "Phase 1.5: Pre-Normalize")
        normalizeGrid(grid, width, height)

        -- 2 Маска
        if params.enableOcean then
            Logger.info("Gen", "Phase 2: Sculpting Island (Elliptical)")
            applyIslandMask(grid, width, height, landPercent)
            coroutine.yield({ status = "Sculpting...", progress = 0.3 })
        end

        Logger.info("Gen", "Phase 2.5: Normalizing")
        normalizeGrid(grid, width, height)

        -- 2.5 КЛАСИФІКАЦІЯ ВОДИ 
        -- робимо це ДО біомів, щоб знати, де озера
        Logger.info("Gen", "Phase 3.5: Lake Gradients")
        calculateLakeDepth(grid, width, height)
        coroutine.yield({status="Lake Depths...", progress=0.7})

        -- 3. Річки
        if params.enableRivers then
            Logger.info("Gen", "Phase 3: Hydrology")
            local riverCount = params.riverCount or 20
            local riversSpawned = 0
            
            -- Спробуємо знайти високі точки для витоку річок
            for i = 1, riverCount * 2 do -- Робимо більше спроб, бо можемо попасти в море
                local rx = math.random(1, width)
                local ry = math.random(1, height)
                local cell = grid[rx][ry]

                -- Річка починається тільки високо в горах (наприклад > 0.6)
                if cell.height > 0.6 then
                    traceRiver(grid, rx, ry, width, height, seaLevel)
                    riversSpawned = riversSpawned + 1
                    
                    if riversSpawned >= riverCount then break end
                    
                    if i % 5 == 0 then
                        coroutine.yield({ status = "Filling Rivers...", progress = 0.5 + (0.4 * (i/(riverCount*2))) })
                    end
                end
            end
            Logger.info("Gen", "Spawned " .. riversSpawned .. " rivers")
        end
        -- 4. ВОЛОГІСТЬ (Moisture Map)
        Logger.info("Gen", "Phase 4: Moisture Map")
        -- Використовуємо інший offset для шуму, щоб він не співпадав з висотою
        local moistureSeed = seed + 1000 
        
        for x = 1, width do
            for y = 1, height do
                -- Генеруємо шум вологості (трохи менш детальний, scale * 0.8)
                local m = Perlin.getFractalNoise_Fast(x, y, moistureSeed, 3, 0.5, (params.scale or 0.1) * 0.8)
                grid[x][y].moisture = m
            end
            if x % 10 == 0 then coroutine.yield({ status = "Watering...", progress = 0.8 }) end
        end

        -- Додаємо вплив річок на вологість
        if params.enableRivers then
            addRiverMoisture(grid, width, height)
        end

        -- 5. БІОМИ (Classification)
        Logger.info("Gen", "Phase 5: Biomes")
        for x=1, width do
            for y=1, height do
                local cell = grid[x][y]

                cell.biome = Biomes.getBiome(cell.height, cell.moisture, cell.isLake, cell.lakeDepth)
                
                if cell.isValley and cell.biome.gameplay == "obstacle" then
                    -- Примусово робимо її рівниною (беремо висоту 0.4 - це зазвичай трава/ліс)
                    -- Можеш також просто хардкодити сюди біом трави, якщо хочеш
                    cell.biome = Biomes.getBiome(0.31, 0.16, false, nil)
                end

                cell.type = cell.biome.id
                if cell.isRiver and cell.height >= seaLevel then
                    cell.biome = {
                        id = "river",
                        gameplay = "river",
                        color = {0.2, 0.6, 0.8}
                    }
                    cell.type = "river"
                end
            end
        end

        Logger.info("Gen", "Phase 5.5: Post-Processing Shapes")
        
        -- 1. Робимо береги шириною мінімум 1 тайл
        
        
        -- 2. Контролюємо ліси: мінімум 6 тайлів, максимум 40 (заміни на свої M і N)
        --controlClusterSizes(grid, width, height, "forest", 1, 10)
        
        -- 3. Контролюємо гори: мінімум 9 тайлів, максимум 60
        --controlClusterSizes(grid, width, height, "obstacle", 9, 60)

        enforceCoastlines(grid, width, height)
        
        coroutine.yield({status="Post-Processing...", progress=0.92})

        -- 6. ЗГЛАДЖУВАННЯ КОЛЬОРІВ 
        -- Передаємо радіус = 1 (змішує 3х3 тайли). Якщо хочеш ще плавніше, постав 2.
        smoothBiomeColors(grid, width, height, 1)
        coroutine.yield({status="Smoothing Colors...", progress=0.95})

        coroutine.yield({ status = "Finalizing...", progress = 1.0 })
        return { status = "Done", result = grid }
    end)
end

return WorldGenerator