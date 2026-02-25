-- src/scripts/world/EntityRenderer.lua
local EntityRenderer = {}
EntityRenderer.__index = EntityRenderer

function EntityRenderer.new(parentGroup, territoryLayer,  cellSize, startX, startY)
    local self = setmetatable({}, EntityRenderer)
    self.group = display.newGroup()
    self.territoryLayer = territoryLayer
    parentGroup:insert(self.group)
    
    self.cellSize = cellSize
    self.startX = startX
    self.startY = startY
    
    -- Кеш об'єктів (щоб легко видаляти старі при оновленні)
    self.dynamicObjects = {}
    
    return self
end

--- Викликається кожен раз, коли змінився стан карти
function EntityRenderer:update(gameState)
    -- 1. Очищаємо старі об'єкти (Простий і надійний метод для покрокових ігор)
    for i = #self.dynamicObjects, 1, -1 do
        if self.dynamicObjects[i] then
            self.dynamicObjects[i]:removeSelf()
            self.dynamicObjects[i] = nil
        end
    end

    local world = gameState.world

    -- 2. Проходимо по всій матриці і шукаємо, що малювати
    for y = 1, world.height do
        for x = 1, world.width do
            local cell = world:getTile(x, y)
            
            -- Вираховуємо точні координати центру клітинки
            local cx = math.floor(self.startX + (x - 1) * self.cellSize)
            local cy = math.floor(self.startY + (y - 1) * self.cellSize)

            -- А) МАЛЮЄМО ТЕРИТОРІЮ (Border/Overlay)
            if cell.ownerId then
                local player = gameState.players[cell.ownerId]
                if player then
                    local territoryRect = display.newRect(self.territoryLayer, cx, cy, self.cellSize, self.cellSize)
                    -- Заливаємо кольором гравця, але робимо напівпрозорим (alpha = 0.3)
                    print( player.color[1] )
                    territoryRect:setFillColor(player.color[1], player.color[2], player.color[3], 0.3)
                    
                    -- Додаємо обводочку для стилю
                    territoryRect.strokeWidth = 1
                    territoryRect:setStrokeColor(player.color[1], player.color[2], player.color[3], 0.8)
                    
                    table.insert(self.dynamicObjects, territoryRect)
                end
            end

            -- Б) МАЛЮЄМО БУДІВЛІ (Поки це сірі квадрати з іконкою)
            if cell.buildingId then
                if cell.buildingId == "castle" then
                    -- 1. МАЛЮЄМО ГОЛОВНИЙ ЗАМОК (3x3)
                    -- Шукаємо картинку для конкретного гравця (castle_1.png, castle_2.png)
                    local spritePath = "src/assets/buildings/Castle" .. cell.castleColor .. ".png"
                    
                    -- Розмір замку: 3 тайли в ширину і 3 в висоту
                    local castleSize = self.cellSize * 3
                    
                    local castleImg = display.newImageRect(self.group, spritePath, castleSize, castleSize)
                    if castleImg then
                        castleImg.x = cx
                        castleImg.y = cy
                        table.insert(self.dynamicObjects, castleImg)
                    else
                        -- Заглушка, якщо картинку не знайдено
                        local bRect = display.newRect(self.group, cx, cy, castleSize, castleSize)
                        bRect:setFillColor(0.2, 0.2, 0.2)
                        table.insert(self.dynamicObjects, bRect)
                    end

                elseif cell.buildingId == "castle_part" then
                    -- 2. ЧАСТИНИ ЗАМКУ
                    -- Нічого не малюємо! Головна картинка "castle" вже перекрила ці тайли.
                    -- Але вони існують у даних, щоб сюди не можна було клікнути чи зайти.

                else
                    -- 3. ІНШІ БУДІВЛІ (Ферми, Вежі і т.д. - старий код)
                    local bRect = display.newRoundedRect(self.group, cx, cy, self.cellSize * 0.7, self.cellSize * 0.7, 4)
                    bRect:setFillColor(0.4, 0.4, 0.4)
                    bRect.strokeWidth = 2
                    bRect:setStrokeColor(0.2, 0.2, 0.2)
                    
                    local bText = display.newText(self.group, "B", cx, cy, native.systemFontBold, 16)
                    bText:setFillColor(1, 1, 1)
                    
                    table.insert(self.dynamicObjects, bRect)
                    table.insert(self.dynamicObjects, bText)
                end
            end

            -- В) МАЛЮЄМО ЮНІТІВ (Поки це кольорові кружечки)
            if cell.unitId then
                local player = gameState.players[cell.ownerId]
                local uColor = player and player.color or {1, 1, 1}
                
                local uCircle = display.newCircle(self.group, cx, cy, self.cellSize * 0.35)
                uCircle:setFillColor(unpack(uColor))
                uCircle.strokeWidth = 2
                uCircle:setStrokeColor(0, 0, 0)
                
                local uText = display.newText(self.group, "U", cx, cy, native.systemFontBold, 14)
                uText:setFillColor(0, 0, 0)

                table.insert(self.dynamicObjects, uCircle)
                table.insert(self.dynamicObjects, uText)
            end
        end
    end
end

return EntityRenderer