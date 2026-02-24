-- src/scripts/models/Building.lua
local RulesConfig = require("src.scripts.config.RulesConfig")

local Building = {}
Building.__index = Building

--- Конструктор нової будівлі
function Building.new(id, ownerId, buildingType, x, y)
    local self = setmetatable({}, Building)
    
    local config = RulesConfig.BUILDINGS[buildingType]
    if not config then return nil end

    self.id = id
    self.ownerId = ownerId
    self.type = buildingType
    
    self.x = x
    self.y = y
    
    -- Якщо це замок, беремо HP першого рівня, інакше звичайне HP
    self.level = 1
    self.maxHp = type(config.hp) == "table" and config.hp.level1 or config.hp
    self.hp = self.maxHp

    return self
end

function Building:takeDamage(amount)
    self.hp = self.hp - amount
    if self.hp < 0 then self.hp = 0 end
    return self.hp == 0
end

return Building