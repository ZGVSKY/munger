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
    
    -- Максимальна дистанція від центру до кута
    local maxDist = math.sqrt(centerX^2 + centerY^2)
    
    -- Переводимо відсотки (80%) у коефіцієнт (0.8)
    -- Це буде радіус нашого "Плато", де маска = 1.0
    local plateauRadius = (landPercent or 50) / 100
    
    -- Трохи зменшуємо радіус, щоб 100% не впиралось прямо в кути
    plateauRadius = plateauRadius * 0.85 

    for x = 1, width do
        for y = 1, height do
            local dx = x - centerX
            local dy = y - centerY
            local dist = math.sqrt(dx^2 + dy^2)
            
            -- Нормалізована дистанція (0.0 в центрі, 1.0 в кутку)
            local distNorm = dist / maxDist
            
            local gradient = 1
            
            if distNorm > plateauRadius then
                -- Ми за межами плато, починаємо спуск
                -- Обчислюємо, скільки місця залишилось до краю (від 0.0 до 1.0)
                local remainingDist = 1.0 - plateauRadius
                local posInFade = (distNorm - plateauRadius) / remainingDist
                
                -- Лінійний спад від 1 до 0
                gradient = 1 - posInFade
                
                -- Робимо спад більш плавним (крива)
                if gradient < 0 then gradient = 0 end
                gradient = math.pow(gradient, 2.0) 
            end

            -- Застосовуємо маску
            grid[x][y].height = grid[x][y].height * gradient
        end
    end
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
        local seaLevel = -0.5
        

        local landPercent = params.landPercent or 80
        
        -- Налаштування шуму
        local scale = params.scale or 0.05
        local octaves = params.octaves or 4
        local persistence = params.persistence or 0.5

        local grid = {}
        local stepsDone = 0
        local totalSteps = width * height * 2 -- Поки що 2 проходи (Висота + Маска)

        -- 1. Ініціалізація та Висота
        Logger.info("Gen", "Step 1: Generating Height Map")
        
        for x = 1, width do
            grid[x] = {}
            for y = 1, height do
                local h = Perlin.getFractalNoise_Fast(x, y, seed, octaves, persistence, scale)
                
                -- Створюємо об'єкт клітинки
                grid[x][y] = {
                    x = x,
                    y = y,
                    height = h,
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

        -- 2. Маска
        if params.enableOcean then
            Logger.info("Gen", "Phase 2: Island Mask (Size: " .. landPercent .. "%)")
            
            -- Передаємо параметр landPercent
            applyIslandMask(grid, width, height, landPercent)
            
            coroutine.yield({ status = "Shaping Island...", progress = 0.4 })
        end

        -- 3. Річки (НОВЕ)
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
        for x = 1, width do
            for y = 1, height do
                local cell = grid[x][y]
                
                -- Визначаємо біом на основі висоти та вологості
                cell.biome = Biomes.getBiome(cell.height, cell.moisture)
                
                -- Перезаписуємо тип для зручності
                cell.type = cell.biome.id 
            end
        end

        coroutine.yield({ status = "Finalizing...", progress = 1.0 })
        return { status = "Done", result = grid }
    end)
end

return WorldGenerator