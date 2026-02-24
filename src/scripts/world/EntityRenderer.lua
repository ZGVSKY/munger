-- src/scripts/world/EntityRenderer.lua
local EntityRenderer = {}
EntityRenderer.__index = EntityRenderer

local CELL_SIZE = 64

--- Конструктор рендера
function EntityRenderer.new(entityLayer, startX, startY)
    local self = setmetatable({}, EntityRenderer)
    
    self.layer = entityLayer
    self.startX = startX
    self.startY = startY
    
    -- Тут ми будемо зберігати посилання на картинки (щоб потім їх видаляти/рухати)
    self.visuals = {} 
    
    return self
end

--- Відмальовує ВСІ об'єкти на карті з нуля
function EntityRenderer:drawAll(gameState)
    -- Очищаємо старі картинки (якщо вони були)
    for i = self.layer.numChildren, 1, -1 do
        self.layer[i]:removeSelf()
    end
    self.visuals = {}
    
    -- Малюємо об'єкти кожного гравця
    for _, player in ipairs(gameState.players) do
        
        -- 1. Будівлі (Замки)
        for _, building in ipairs(player.buildings) do
            local cx = math.floor(self.startX + (building.x - 1) * CELL_SIZE + (CELL_SIZE / 2))
            local cy = math.floor(self.startY + (building.y - 1) * CELL_SIZE + (CELL_SIZE / 2))

            local bVis = display.newRect(self.layer, cx, cy, CELL_SIZE * 0.8, CELL_SIZE * 0.8)
            bVis:setFillColor(unpack(player.color))
            bVis.strokeWidth = 4
            bVis:setStrokeColor(1, 0.8, 0)
            
            display.newText({
                parent = self.layer,
                text = "C",
                x = cx, y = cy,
                font = native.systemFontBold,
                fontSize = 32
            })
            
            -- Зберігаємо картинку за її ігровим ID
            self.visuals["b_" .. building.id] = bVis
        end
        
        -- 2. Юніти (В майбутньому тут буде цикл по player.units)
    end
end

return EntityRenderer