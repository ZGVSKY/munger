-- src/scripts/models/World.lua
local World = {}
World.__index = World

--- Ініціалізує світ на основі згенерованої сітки
function World.new(generatedGrid, width, height)
    local self = setmetatable({}, World)
    
    self.grid = generatedGrid
    self.width = width
    self.height = height
    
    -- Підготовлюємо кожну клітинку для геймплею
    for x = 1, self.width do
        for y = 1, self.height do
            local cell = self.grid[x][y]
            -- Додаємо ігрові поля в тайл генератора
            cell.ownerId = nil    -- ID гравця, чия це територія
            cell.buildingId = nil -- ID будівлі, яка тут стоїть
            cell.unitId = nil     -- ID юніта, який тут стоїть
        end
    end

    -- Глобальні лічильники для генерації унікальних ID
    self.nextUnitId = 1
    self.nextBuildingId = 1

    return self
end

-- ==========================================
-- БАЗОВІ МЕТОДИ КАРТИ
-- ==========================================

--- Повертає клітинку за координатами
function World:getTile(x, y)
    if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
        return self.grid[x][y]
    end
    return nil
end

--- Змінює власника території (Зафарбовування)
function World:setOwner(x, y, playerId)
    local tile = self:getTile(x, y)
    if tile then
        tile.ownerId = playerId
    end
end

return World