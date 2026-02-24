-- src/scripts/models/Player.lua
local Player = {}
Player.__index = Player

--- Конструктор нового гравця
-- @param id (number) Унікальний номер гравця
-- @param isBot (boolean) Чи керує цим гравцем ШІ
-- @param colorConfig (table) Колір гравця у форматі {r, g, b}
function Player.new(id, isBot, colorConfig)
    local self = setmetatable({}, Player)
    
    -- Базова інформація
    self.id = id
    self.name = isBot and ("Bot " .. id) or ("Player " .. id)
    self.color = colorConfig or {1, 1, 1}
    
    -- Стан гравця
    self.isBot = isBot or false
    self.isAlive = true

    -- Ресурси 
    self.resources = {
        gold = 50,
        stone = 50,
        wood = 50,
        food = 50
    }

    -- Економіка та населення 
    self.economy = {
        totalPeasants = 5,
        busyPeasants = 0
    }

    -- Ліміти армії
    self.maxUnits = 4 

    -- Списки об'єктів на карті (зберігаємо унікальні ID об'єктів)
    self.units = {}
    self.buildings = {}
    
    -- Статистика гравця (для фінального екрану або ачівок)
    self.stats = {
        unitsCreated = 0,
        unitsKilled = 0,
        buildingsConstructed = 0,
        goodsProduced = 0,
        totalGoldEarned = 0,
        maxTerritoryReached = 0
    }

    return self
end

-- ==========================================
-- МЕТОДИ ДЛЯ РОБОТИ З РЕСУРСАМИ
-- ==========================================

--- Додає ресурс та оновлює статистику (якщо це золото)
function Player:addResource(type, amount)
    if self.resources[type] then
        self.resources[type] = self.resources[type] + amount
        
        -- Трекаємо статистику заробітку
        if type == "gold" and amount > 0 then
            self.stats.totalGoldEarned = self.stats.totalGoldEarned + amount
        end
    end
end

--- Перевіряє, чи вистачає ресурсів, і віднімає їх
function Player:payCost(costTable)
    for resType, amount in pairs(costTable) do
        if not self.resources[resType] or self.resources[resType] < amount then
            return false
        end
    end
    
    for resType, amount in pairs(costTable) do
        self.resources[resType] = self.resources[resType] - amount
    end
    
    return true
end

-- ==========================================
-- МЕТОДИ СЕЛЯН
-- ==========================================

--- Повертає кількість вільних селян
function Player:getFreePeasants()
    return self.economy.totalPeasants - self.economy.busyPeasants
end

--- Призначає селянина на роботу
function Player:assignPeasant()
    if self:getFreePeasants() > 0 then
        self.economy.busyPeasants = self.economy.busyPeasants + 1
        return true
    end
    return false
end

--- Звільняє селянина з роботи
function Player:freePeasant()
    if self.economy.busyPeasants > 0 then
        self.economy.busyPeasants = self.economy.busyPeasants - 1
    end
end

-- ==========================================
-- УПРАВЛІННЯ СТАНОМ
-- ==========================================

--- Викликається, коли гравець втрачає Замок
function Player:die()
    self.isAlive = false
    -- Тут в майбутньому можна додати логіку видалення всіх його юнітів з карти
end

return Player