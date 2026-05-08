-- src/scripts/view/EntityRenderer.lua
local EntityRenderer = {}
EntityRenderer.__index = EntityRenderer

function EntityRenderer.new(entityLayer, territoryLayer, cellSize, startX, startY)
    local self = setmetatable({}, EntityRenderer)
    
    self.entityLayer = entityLayer
    self.territoryLayer = territoryLayer
    self.cellSize = cellSize
    self.startX = startX
    self.startY = startY
    
    self.activeStatics = {}  
    self.activeUnits = {}    
    self.activeTerritory = {} 
    
    self.lastUpdateX = 99999
    self.lastUpdateY = 99999
    
    -- КЕШУВАННЯ ТЕКСТУР (Preloading)
    self.textures = {
        castles = { Blue        = graphics.newTexture({ type = "image", filename = "src/assets/buildings/CastleBlue.png" }),
                    Red         = graphics.newTexture({ type = "image", filename = "src/assets/buildings/CastleRed.png" }),
                    Green       = graphics.newTexture({ type = "image", filename = "src/assets/buildings/CastleGreen.png" }),
                    Pink        = graphics.newTexture({ type = "image", filename = "src/assets/buildings/CastlePink.png" }),
                    LightBlue   = graphics.newTexture({ type = "image", filename = "src/assets/buildings/CastleLightBlue.png" }),
                    Orange      = graphics.newTexture({ type = "image", filename = "src/assets/buildings/CastleOrange.png" }),
                    Purple      = graphics.newTexture({ type = "image", filename = "src/assets/buildings/CastlePurple.png" }),
                    Yellow      = graphics.newTexture({ type = "image", filename = "src/assets/buildings/CastleYellow.png" }),
                    Shadow      = graphics.newTexture({ type = "image", filename = "src/assets/buildings/CastleShadow.png" })
                  },
        trees = graphics.newImageSheet("src/assets/world/trees.png", { width = 48, height = 64, numFrames = 3 }),
        warrior = graphics.newTexture({ type = "image", filename = "src/assets/units/warrior.png" })
    }
    
    return self
end

-- ==========================================
-- СПАВН ОБ'ЄКТІВ 
-- ==========================================
function EntityRenderer:spawnStatic(x, y, cellData, screenX, screenY)
    local objGroup = display.newGroup()
    objGroup.x = screenX
    objGroup.y = screenY
    objGroup.gridY = y 
    
    if cellData.buildingId == "castle" then
        local tex = self.textures.castles
        print(cellData.castleColor)
        local castleImg = display.newImageRect(objGroup, tex[cellData.castleColor].filename, tex[cellData.castleColor].baseDir, self.cellSize*3, self.cellSize*3)
        
        
    elseif cellData.buildingId == "tree" then
        local tex = self.textures.trees
        display.newImageRect(objGroup, tex, cellData.treeCFG['type'], 96, 128)
        objGroup.x = objGroup.x+  cellData.treeCFG['dx']
        objGroup.y = objGroup.y+  cellData.treeCFG['dy']
    end
    
    self.entityLayer:insert(objGroup)
    return objGroup
end

function EntityRenderer:spawnUnit(unitData, screenX, screenY)
    local unitGroup = display.newGroup()
    unitGroup.x = screenX
    unitGroup.y = screenY
    unitGroup.gridY = unitData.y 
    
    if self.textures.warrior then
        local tex = self.textures.warrior
        local warriorImg = display.newImageRect(unitGroup, tex.filename, tex.baseDir, self.cellSize * 0.8, self.cellSize * 0.8)
        if unitData.ownerColor then warriorImg:setFillColor(unitData.ownerColor[1], unitData.ownerColor[2], unitData.ownerColor[3]) end
    end
    
    self.entityLayer:insert(unitGroup)
    return unitGroup
end

-- ЛОГІКА ТЕРИТОРІЙ 
function EntityRenderer:spawnTerritory(x, y, cellData, screenX, screenY, gameState)
    local terrGroup = display.newGroup()
    terrGroup.x = screenX
    terrGroup.y = screenY
    
    local world = gameState.world
    local player = gameState.players[cellData.ownerId]
    
    if player then
        local c = player.color
        
        -- 1. ЗАОКРУГЛЕНА ЗАЛИВКА ТЕРИТОРІЇ
        -- Малюємо в 0, 0, тому що сама група вже стоїть на потрібних координатах (screenX, screenY)
        local cornerRadius = 1
        local territoryRect = display.newRoundedRect(terrGroup, 0, 0, self.cellSize, self.cellSize, cornerRadius)
        territoryRect:setFillColor(c[1], c[2], c[3], 0.25)
        
        -- 2. РОЗУМНІ КОРДОНИ (Без води і з м'якими краями)
        local function isSameOwnerOrWater(nx, ny)
            if nx >= 1 and nx <= world.width and ny >= 1 and ny <= world.height then
                local nCell = world:getTile(nx, ny)
                local isWater = false
                if nCell.biome and (nCell.biome.gameplay == "water" or nCell.biome.gameplay == "river") then
                    isWater = true
                end
                return nCell.ownerId == cellData.ownerId or isWater
            end
            return false 
        end

        local hs = self.cellSize / 2
        local th = 8 -- Товщина кордону

        local function drawEdge(ex, ey, ew, eh)
            local edge = display.newRoundedRect(terrGroup, ex, ey, ew, eh, 1)
            edge:setFillColor(c[1], c[2], c[3], 1)
        end

        -- Якщо зверху чужа земля (і не вода) - малюємо кордон
        if not isSameOwnerOrWater(x, y - 1) then drawEdge(0, -hs + th/2, self.cellSize, th) end
        -- Якщо знизу
        if not isSameOwnerOrWater(x, y + 1) then drawEdge(0, hs - th/2, self.cellSize, th) end
        -- Якщо зліва
        if not isSameOwnerOrWater(x - 1, y) then drawEdge(-hs + th/2, 0, th, self.cellSize) end
        -- Якщо справа
        if not isSameOwnerOrWater(x + 1, y) then drawEdge(hs - th/2, 0, th, self.cellSize) end
    end
    
    self.territoryLayer:insert(terrGroup)
    return terrGroup
end

-- ==========================================
-- JIT РЕНДЕР (Логіка видимості)
-- ==========================================
function EntityRenderer:update(cameraGroup, gameState)
    if not cameraGroup or not gameState or not gameState.world then return end

    local dx = math.abs(cameraGroup.x - self.lastUpdateX)
    local dy = math.abs(cameraGroup.y - self.lastUpdateY)
    if dx < 20 and dy < 20 then return end
    
    self.lastUpdateX, self.lastUpdateY = cameraGroup.x, cameraGroup.y

    local screenX1, screenY1 = display.screenOriginX, display.screenOriginY
    local screenX2, screenY2 = screenX1 + display.actualContentWidth, screenY1 + display.actualContentHeight

    local worldMinX, worldMinY = cameraGroup:contentToLocal(screenX1, screenY1)
    local worldMaxX, worldMaxY = cameraGroup:contentToLocal(screenX2, screenY2)

    local minGridX = math.floor((worldMinX - self.startX + (self.cellSize / 2)) / self.cellSize) + 1
    local maxGridX = math.floor((worldMaxX - self.startX + (self.cellSize / 2)) / self.cellSize) + 1
    local minGridY = math.floor((worldMinY - self.startY + (self.cellSize / 2)) / self.cellSize) + 1
    local maxGridY = math.floor((worldMaxY - self.startY + (self.cellSize / 2)) / self.cellSize) + 1

    local mapWidth = gameState.world.width
    local mapHeight = gameState.world.height
    
    minGridX = math.max(1, minGridX - 2)
    maxGridX = math.min(mapWidth, maxGridX + 2)
    minGridY = math.max(1, minGridY - 2)
    maxGridY = math.min(mapHeight, maxGridY + 2)

    local visibleCells = {} 
    local needsSorting = false 

    for y = minGridY, maxGridY do
        for x = minGridX, maxGridX do
            local cellId = x .. "_" .. y
            visibleCells[cellId] = true
            
            local cellData = gameState.world:getTile(x, y)
            if cellData then
                local screenX = self.startX + (x - 1) * self.cellSize
                local screenY = self.startY + (y - 1) * self.cellSize

                if cellData.buildingId then
                    if not self.activeStatics[cellId] then
                        self.activeStatics[cellId] = self:spawnStatic(x, y, cellData, screenX, screenY)
                        needsSorting = true
                    end
                end

                if cellData.ownerId then
                    if not self.activeTerritory[cellId] then
                        -- ТЕПЕР ПЕРЕДАЄМО gameState СЮДИ, щоб працювала перевірка сусідів
                        self.activeTerritory[cellId] = self:spawnTerritory(x, y, cellData, screenX, screenY, gameState)
                    end
                end

                if cellData.unit then
                    local unitId = cellData.unit.id or cellId 
                    if not self.activeUnits[unitId] then
                        self.activeUnits[unitId] = self:spawnUnit(cellData.unit, screenX, screenY)
                        needsSorting = true
                    end
                end
            end
        end
    end

    for id, obj in pairs(self.activeStatics) do
        if not visibleCells[id] then obj:removeSelf(); self.activeStatics[id] = nil end
    end
    
    for id, obj in pairs(self.activeTerritory) do
        if not visibleCells[id] then obj:removeSelf(); self.activeTerritory[id] = nil end
    end

    for unitId, obj in pairs(self.activeUnits) do
        local uX = math.floor((obj.x - self.startX + (self.cellSize / 2)) / self.cellSize) + 1
        local uY = math.floor((obj.y - self.startY + (self.cellSize / 2)) / self.cellSize) + 1
        local currentCellId = uX .. "_" .. uY
        
        if not visibleCells[currentCellId] then
            obj:removeSelf()
            self.activeUnits[unitId] = nil
        end
    end

    if needsSorting and self.entityLayer.numChildren > 1 then
        local children = {}
        for i = 1, self.entityLayer.numChildren do children[i] = self.entityLayer[i] end
        table.sort(children, function(a, b) return (a.gridY or 0) < (b.gridY or 0) end)
        for i = 1, #children do self.entityLayer:insert(children[i]) end
    end
end

function EntityRenderer:destroy()
    for _, obj in pairs(self.activeStatics) do obj:removeSelf() end
    for _, obj in pairs(self.activeTerritory) do obj:removeSelf() end
    for _, obj in pairs(self.activeUnits) do obj:removeSelf() end
    
    for k, tex in pairs(self.textures) do tex:releaseSelf() end
    
    self.activeStatics, self.activeTerritory, self.activeUnits, self.textures = {}, {}, {}, {}
end

return EntityRenderer