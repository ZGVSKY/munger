-- src/scripts/models/Player.lua
local Player = {}
Player.__index = Player

local rules = require("src.scripts.config.RulesConfig")

--- Конструктор нового гравця
-- @param id (number) Унікальний номер гравця
-- @param isBot (boolean) Чи керує цим гравцем ШІ
-- @param colorConfig (table) Колір гравця у форматі {r, g, b}
function Player.new(id, name, isBot, colorConfig, colorText)
    local self = setmetatable({}, Player)
    
    -- Базова інформація
    self.id = id
    self.name = isBot and ("Bot " .. id) or name
    self.color = colorConfig or {1, 1, 1}
    self.colorText = colorText
    
    -- Стан гравця
    self.isBot = isBot or false
    self.isAlive = true

    self.cameraX = nil
    self.cameraY = nil
    self.cameraScaleX = 1
    self.cameraScaleY = 1
    
    self.isBankrupt = false

    -- Ресурси 
    self.resources = {
        gold = 50,
        stone = 50,
        wood = 50,
        food = 50
    }

    -- Очікуваний прибуток/витрати за наступний хід
    self.resourceDeltas = {
        gold = 0,
        stone = 0,
        wood = 0,
        food = 0
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

-- Перерахунок дельти (викликається при спавні або зміні ходу)
function Player:calculateDeltas()
    local goldDelta = 0
    
    -- Допоміжна функція пошуку в каталогах
    local function getFromCatalog(catalog, id)
        for _, item in ipairs(catalog) do
            if item.id == id then return item end
        end
        return nil
    end
    
    -- 1. Додаємо дохід від будівель
    for _, bldg in ipairs(self.buildings) do
        local bData = getFromCatalog(rules.BUILDINGScatalog, bldg.id)
        if bData and bData.income then
            goldDelta = goldDelta + bData.income
        end
    end
    
    -- 2. Віднімаємо утримання армії
    for _, unit in ipairs(self.units) do
        local uData = getFromCatalog(rules.UNITScatalog, unit.id)
        if uData and uData.upkeep then
            goldDelta = goldDelta - uData.upkeep
        end
    end
    
    self.resourceDeltas.gold = goldDelta
end

return Player