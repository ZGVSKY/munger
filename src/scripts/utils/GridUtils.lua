-- src/scripts/utils/GridUtils.lua
local GridUtils = {}

--- Нормалізує значення висоти на сітці до діапазону від 0.0 до 1.0
function GridUtils.normalizeGrid(grid, width, height)
    local minH = math.huge
    local maxH = -math.huge
    
    -- 1. Знаходимо екстремуми
    for x = 1, width do
        for y = 1, height do
            local h = grid[x][y].height
            if h < minH then minH = h end
            if h > maxH then maxH = h end
        end
    end
    
    -- Захист від ділення на нуль (виняток)
    if maxH == minH then return end
    
    local range = maxH - minH
    
    -- 2. Розтягуємо висоти
    for x = 1, width do
        for y = 1, height do
            grid[x][y].height = (grid[x][y].height - minH) / range
        end
    end
    
    return minH, maxH
end

--- Застосовує еліптичну маску для формування острова (плавний градієнт по краях)
function GridUtils.applyIslandMask(grid, width, height, landPercent)
    local centerX = width / 2
    local centerY = height / 2
    local plateauSize = (landPercent / 100) 

    for x = 1, width do
        for y = 1, height do
            local nx = (x - centerX) / (width / 2)
            local ny = (y - centerY) / (height / 2)
            
            local dist = math.sqrt(nx*nx + ny*ny)
            local maskVal = 1.0
            
            if dist > plateauSize then
                -- Плавний косинусний спад
                local distanceToEdge = (dist - plateauSize) / (1.0 - plateauSize)
                maskVal = math.cos(distanceToEdge * (math.pi / 2))
                
                if dist >= 1.0 then maskVal = 0 end
                if maskVal < 0 then maskVal = 0 end
            end
            
            -- Застосовуємо маску
            grid[x][y].height = grid[x][y].height * maskVal
        end
    end
end

return GridUtils