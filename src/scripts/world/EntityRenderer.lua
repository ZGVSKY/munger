-- src/scripts/world/EntityRenderer.lua
local EntityRenderer = {}
EntityRenderer.__index = EntityRenderer

local config = require("src.scripts.config.WorldConfig")
local mRand = math.random

local treeSheetOptions = { width = 48, height = 64, numFrames = 3 }
local treeSheet = graphics.newImageSheet("src/assets/world/trees.png", treeSheetOptions)
local TREE_FRAMES = { 1, 2, 3 }

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
                    -- 1. ЗАОКРУГЛЕНА ЗАЛИВКА ТЕРИТОРІЇ
                    -- Використовуємо newRoundedRect (радіус 6 пікселів). 
                    -- Це створить дуже стильний паттерн на стиках клітинок!
                    local cornerRadius = 1
                    local territoryRect = display.newRoundedRect(self.territoryLayer, cx, cy, self.cellSize, self.cellSize, cornerRadius)
                    territoryRect:setFillColor(player.color[1], player.color[2], player.color[3], 0.25)
                    table.insert(self.dynamicObjects, territoryRect)

                    -- 2. РОЗУМНІ КОРДОНИ (Без води і з м'якими краями)
                    -- Функція тепер перевіряє: "Чи це наша земля АБО чи це вода?"
                    local function isSameOwnerOrWater(nx, ny)
                        if nx >= 1 and nx <= world.width and ny >= 1 and ny <= world.height then
                            local nCell = world:getTile(nx, ny)
                            
                            -- Перевіряємо, чи це вода
                            local isWater = false
                            if nCell.biome and (nCell.biome.gameplay == "water" or nCell.biome.gameplay == "river") then
                                isWater = true
                            end
                            
                            -- Якщо це наш тайл АБО це вода - ми НЕ малюємо кордон
                            return nCell.ownerId == cell.ownerId or isWater
                        end
                        return false 
                    end

                    local hs = self.cellSize / 2
                    local th = 8 -- Товщина кордону
                    local c = player.color

                    -- Створюємо допоміжну функцію для малювання м'яких ліній (капсул)
                    local function drawEdge(ex, ey, ew, eh)
                        -- th/2 робить краї лінії ідеально круглими
                        local edge = display.newRoundedRect(self.territoryLayer, ex, ey, ew, eh, 1)
                        edge:setFillColor(c[1], c[2], c[3], 1)
                        table.insert(self.dynamicObjects, edge)
                    end

                    -- Якщо зверху чужа земля (і не вода) - малюємо кордон
                    if not isSameOwnerOrWater(x, y - 1) then
                        drawEdge(cx, cy - hs + th/2, self.cellSize, th)
                    end
                    -- Якщо знизу
                    if not isSameOwnerOrWater(x, y + 1) then
                        drawEdge(cx, cy + hs - th/2, self.cellSize, th)
                    end
                    -- Якщо зліва
                    if not isSameOwnerOrWater(x - 1, y) then
                        drawEdge(cx - hs + th/2, cy, th, self.cellSize)
                    end
                    -- Якщо справа
                    if not isSameOwnerOrWater(x + 1, y) then
                        drawEdge(cx + hs - th/2, cy, th, self.cellSize)
                    end
                end
            end

            -- Б) МАЛЮЄМО БУДІВЛІ (Поки це сірі квадрати з іконкою)
            if cell.buildingId then
                if cell.buildingId == "castle" then
                    -- 1. МАЛЮЄМО ГОЛОВНИЙ ЗАМОК (3x3)
                    -- Шукаємо картинку для конкретного гравця (castle_1.png, castle_2.png)
                    
                    local spritePath = "src/assets/buildings/Castle" .. cell.castleColor .. ".png"
                    local castleShadow = "src/assets/buildings/CastleShadow.png"
                    
                    -- Розмір замку: 3 тайли в ширину і 3 в висоту
                    local castleSize =  self.cellSize * 3
                    local castleShadowImg = display.newImageRect(self.group, castleShadow, castleSize+16, castleSize+16)
                    if castleShadowImg then
                        castleShadowImg.x = cx+10
                        castleShadowImg.y = cy-10
                        --table.insert(self.dynamicObjects, castleImg)
                    end
                    
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

            if cell.biome and cell.biome.gameplay == "forest" and not cell.buildingId then
                -- Використовуємо псевдорандом на основі координат, щоб дерева завжди виглядали однаково
                local frameIdx = mRand(1,3)
                       

                -- Малюємо дерево
                local tree = display.newImageRect(self.group, treeSheet, TREE_FRAMES[frameIdx], 96, 128)
                tree.anchorY = 1 -- Якір знизу, щоб дерево стояло на клітинці
                tree.x = cx + mRand(-config.RENDER.treeOffset, config.RENDER.treeOffset)
                tree.y = cy + (self.cellSize / 2) + mRand(-config.RENDER.treeOffset, config.RENDER.treeOffset) 
                
                -- Трохи змінюємо відтінок для різноманітності
                local shade = 0.8 + ((x + y) % 3) * 0.1
                tree:setFillColor(shade, shade, shade)

                table.insert(self.dynamicObjects, tree)
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