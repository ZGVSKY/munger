-- src/scripts/models/Unit.lua
local RulesConfig = require("src.scripts.config.RulesConfig")

local Unit = {}
Unit.__index = Unit

--- Конструктор нового юніта
-- @param id (number) Унікальний ID юніта у світі
-- @param ownerId (number) ID гравця, якому він належить
-- @param unitType (string) Тип з RulesConfig (наприклад, "warrior_lv1")
-- @param x, y (number) Координати на сітці
function Unit.new(id, ownerId, unitType, x, y)
    local self = setmetatable({}, Unit)
    
    local config = RulesConfig.UNITS[unitType]
    if not config then
        print("Error: Unknown unit type: " .. tostring(unitType))
        return nil
    end

    self.id = id
    self.ownerId = ownerId
    self.type = unitType
    
    -- Координати
    self.x = x
    self.y = y
    
    -- Характеристики з конфігу
    self.maxHp = config.hp
    self.hp = config.hp
    
    self.maxMoves = config.maxMoves
    self.movesLeft = config.maxMoves
    
    self.captureRadius = config.captureRadius

    return self
end

--- Віднімає здоров'я
function Unit:takeDamage(amount)
    self.hp = self.hp - amount
    if self.hp < 0 then self.hp = 0 end
    return self.hp == 0 -- Повертає true, якщо юніт помер
end

--- Відновлює очки ходу (викликається на початку ходу гравця)
function Unit:resetMoves()
    self.movesLeft = self.maxMoves
end

return Unit