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

-- Генерація однієї річки
local function traceRiver(grid, startX, startY, width, height, seaLevel)
    local curr = grid[startX][startY]
    local pathLength = 0
    
    -- Річка тече поки не впаде в море або в яму
    while true do
        curr.isRiver = true
        pathLength = pathLength + 1

        -- Якщо дійшли до моря - кінець річки
        if curr.height < seaLevel then
            break
        end

        local nextCell = getLowestNeighbor(grid, curr.x, curr.y, width, height)

        if nextCell then
            -- Вода тече далі
            curr = nextCell
            -- Захист від зациклення (дуже довгі річки)
            if pathLength > 200 then break end
        else
            -- Немає куди текти (Яма) -> Створюємо Озеро
            curr.isLake = true
            -- Можна розширити озеро на сусідів, але поки 1 клітинка
            break 
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
                cell.type = cell.biome.id
            end
        end

        

        coroutine.yield({ status = "Finalizing...", progress = 1.0 })
        return { status = "Done", result = grid }
    end)
end

return WorldGenerator