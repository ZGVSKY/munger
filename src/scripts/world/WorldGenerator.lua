-- src/scripts/world/WorldGenerator.lua
local WorldGenerator = {}

-- Імпорти
local Perlin = require("src.scripts.utils.ModernPerlin")
local Logger = require("src.scripts.utils.logger")

--------------------------------------------------------------------------------
-- Приватні допоміжні функції
--------------------------------------------------------------------------------

-- Маска острова (Градієнт від центру)
local function applyIslandMask(grid, width, height)
    local centerX = width / 2
    local centerY = height / 2
    local maxDist = math.sqrt(centerX^2 + centerY^2)

    for x = 1, width do
        for y = 1, height do
            local dx = x - centerX
            local dy = y - centerY
            local dist = math.sqrt(dx^2 + dy^2)
            
            -- Градієнт: 1 в центрі, 0 по краях.
            -- Використовуємо ступінь (^3), щоб зробити краї різкішими (більше моря)
            local gradient = 1 - (dist / maxDist)
            gradient = math.pow(gradient, 1.5) -- Експериментуй з цим числом (0.5 - 3.0)

            if gradient < 0 then gradient = 0 end

            -- Множимо висоту на маску
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
        local seaLevel = params.seaLevel or 0.3
        
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
            Logger.info("Gen", "Phase 2: Island Mask")
            applyIslandMask(grid, width, height)
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

        coroutine.yield({ status = "Finalizing...", progress = 1.0 })
        return { status = "Done", result = grid }
    end)
end

return WorldGenerator