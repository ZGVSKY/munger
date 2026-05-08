-- src/scripts/world/MapRenderer.lua
local MapRenderer = {}
local WorldConfig = require("src.scripts.config.WorldConfig")

local mFloor = math.floor
local mRand = math.random

MapRenderer.CHUNK_SIZE = 16 

local sheetOptions = { width = 32, height = 32, numFrames = 816, sheetContentWidth = 1536, sheetContentHeight = 544 }
local tilesetSheet = graphics.newImageSheet("src/assets/world/tiles.png", sheetOptions)
local decorSheetOptions = { width = 16, height = 16, numFrames = 30 }
local decorSheet = graphics.newImageSheet("src/assets/world/decor.png", decorSheetOptions)

local DECOR_FRAMES_GRASS = { 2,3,5,6,7,8,9,15,16,17,18,19,25,26 }
local DECOR_FRAMES_OBSTACLE = {27,28,29 }
local DECOR_FRAMES_COAST = {5,6}

local BASE_TILES = {
    ground = { 720+1, 720+2, 720+3, 720+4, 720+5, 720+6, 720+7, 720+8, 720+9, 720+10 },
    coast = { 768+1, 768+2, 768+3, 768+4, 768+5, 768+6, 768+7, 768+8, 768+9, 768+10, 768+11, 768+12, 768+13, 768+14, 768+15, 768+16, 768+17, 768+18 },
    forest = { 720+1 }, scorched = { 720+1 }, water = { 720+11 }, river = { 720+11 }, obstacle = { 720+12 } 
}
BASE_TILES.high_obstacle = BASE_TILES.obstacle

local LAYER_PRIORITY = { 
    water = 0, river = 1, coast = 2, 
    sub_desert = 3, grassland = 3, temp_forest = 4, trop_forest = 5,
    shrubland = 3, taiga = 3, ground = 3, forest = 6, 
    
    scorched = 10, bare = 11, tundra = 12, snow = 13,
    obstacle = 5, high_obstacle = 13 
}

-- ==========================================
--  ВИЗНАЧЕННЯ ТИПУ ТА КОЛЬОРУ
-- ==========================================
local function getGameplayType(cell) 
    if not cell then return "water" end
    -- Якщо WorldGenerator перезаписав gameplay або buildingId, враховуємо це!
    if cell.gameplay then return cell.gameplay end
    if cell.buildingId == "high_obstacle" then return "high_obstacle" end 
    return cell.biome and cell.biome.gameplay or "water" 
end

local function getLayer(cell) 
    if not cell then return 0 end
    local id = cell.biome and cell.biome.id
    local gType = getGameplayType(cell)
    return LAYER_PRIORITY[id] or LAYER_PRIORITY[gType] or 0
end

-- Ця функція ПОВЕРТАЄ ЗГЛАДЖУВАННЯ! Вона перевіряє renderColor перед biome.color
local function applyColor(tile, cell)
    if not cell then return end
    if cell.renderColor then
        tile:setFillColor(unpack(cell.renderColor))
    elseif cell.biome and cell.biome.color then
        tile:setFillColor(unpack(cell.biome.color))
    end
end

local OVERLAY_TILES = {
    ground = {
        N = { 2, 48+2, 96+2, 144+2, 192+2, 240+2 }, S = { 1, 48+1, 96+1, 144+1, 192+1, 240+1 },
        W = { 5, 48+5, 96+5, 144+5, 192+5, 240+5 }, E = { 6, 48+6, 96+6, 144+6, 192+6, 240+6 },
        NW = { 336+2, 336+4, 336+6 }, NE = { 336+1, 336+3, 336+5 }, 
        SW = { 288+2, 288+4, 288+6 }, SE = { 288+1, 288+3, 288+5 },
        NW_INNER = { 7, 9, 11 }, NE_INNER = { 8, 10, 12 }, 
        SW_INNER = { 48+7, 48+9, 48+11 }, SE_INNER = { 48+8, 48+10, 48+12 }
    },
    ground_over_water = {
        N = { base = { 240+9, 240+10, 240+12 }, top = { 48+2 } }, S = { base = { 192+9, 192+10, 192+11, 192+12 }, top = { 48+1 } },
        W = { base = { 3, 48+3, 96+3, 144+3 }, top = { 48+5 } }, E = { base = { 4, 48+4, 96+4, 144+4 }, top = { 48+6 } },
        NW = { base = { 432+4 }, top = { 336+6 } }, NE = { base = { 432+3 }, top = { 336+5 } },
        SW = { base = { 384+2, 384+4 }, top = { 288+6 } }, SE = { base = { 384+1, 384+3 }, top = { 288+5 } },
        NW_INNER = { base = { 96+7, 96+9, 96+11 }, top = { 7 } }, NE_INNER = { base = { 96+8, 96+10, 96+12 }, top = { 8 } },
        SW_INNER = { base = { 144+7, 144+9, 144+11 }, top = { 48+7 } }, SE_INNER = { base = { 144+8, 144+10, 144+12 }, top = { 48+8 } },
    },
    coast = {
        N = { 240+9, 240+10, 240+11, 240+12 }, S = { 192+9, 192+10, 192+11, 192+12 }, 
        W = { 3, 48+3, 96+3, 144+3 }, E = { 4, 48+4, 96+4, 144+4 },
        NW = { 432+2, 432+4 }, NE = { 432+1, 432+3 }, SW = { 384+2, 384+4 }, SE = { 384+1, 384+3 },
        NW_INNER = { 96+7, 96+9, 96+11 }, NE_INNER = { 96+8, 96+10, 96+12 }, 
        SW_INNER = { 144+7, 144+9, 144+11 }, SE_INNER = { 144+8, 144+10, 144+12 }
    },
    obstacle = {
        N = { parts = { { frame = 48+14, dy = 0 }, { frame = 96+14, dy = 1 }, { frame = 144+14, dy = 2 } } },
        S = { 14 }, W = { 96+17 }, E = { 96+16 },
        NW = { parts = { {frame = 48+17, dy = 0}, {frame = 192+16, dy = 1}, {frame = 192+14, dy = 2} } },
        NE = { parts = { {frame = 48+16, dy = 0}, {frame = 192+15, dy = 1}, {frame = 192+13, dy = 2} } },
        SW = { 17 }, SE = { 16},
        NE_INNER = { parts = { {frame = 47, dy = 0}, {frame = 192+16, dy = 1}, {frame = 192+14, dy = 2} } },
        NW_INNER = { parts = { {frame = 46, dy = 0}, {frame = 192+15, dy = 1}, {frame = 192+13, dy = 2} } }, 
        SW_INNER = { 144+7 }, SE_INNER = { 144+8 }
    }
}
OVERLAY_TILES.high_obstacle = OVERLAY_TILES.obstacle

local CONST_DIAGONALS = {
    { dx = -1, dy = -1, dir = "NW", adj1 = {dx=0, dy=-1}, adj2 = {dx=-1, dy=0} }, { dx = 1,  dy = -1, dir = "NE", adj1 = {dx=0, dy=-1}, adj2 = {dx=1, dy=0}  }, 
    { dx = -1, dy = 1,  dir = "SW", adj1 = {dx=0, dy=1},  adj2 = {dx=-1, dy=0} }, { dx = 1,  dy = 1,  dir = "SE", adj1 = {dx=0, dy=1},  adj2 = {dx=1, dy=0}  }, 
}

local function getOverlayConfig(nCell, mCell)
    if not nCell or not mCell then return nil end
    
    local nG = getGameplayType(nCell)
    local mG = getGameplayType(mCell)
    local nId = nCell.biome and nCell.biome.id
    local mId = mCell.biome and mCell.biome.id

    local isLowGround = (mG == "ground" or mG == "forest" or mG == "water" or mG == "river" or mG == "coast")

    if nId == "snow" then
        if mId == "tundra" or mId == "bare" or mId == "scorched" or isLowGround then return OVERLAY_TILES["obstacle"] end
    elseif nId == "tundra" then
        if mId == "bare" or mId == "scorched" or isLowGround then return OVERLAY_TILES["obstacle"] end
    elseif nId == "bare" then
        if mId == "scorched" or isLowGround then return OVERLAY_TILES["obstacle"] end
    elseif nId == "scorched" then
        if isLowGround then return OVERLAY_TILES["obstacle"] end
    elseif nG == "obstacle" or nG == "high_obstacle" then
         if isLowGround then return OVERLAY_TILES["obstacle"] end
    end

    if nG == "ground" and (mG == "water" or mG == "river") then return OVERLAY_TILES["ground_over_water"] end
    if nG == "forest" then
        if mG == "river" or mG == "water" then return OVERLAY_TILES["ground_over_water"] end
        if mG == "coast" or mG == "ground" then return OVERLAY_TILES["ground"] end
        if mId == "temp_forest" then return OVERLAY_TILES["ground"] end
    end
    

    return OVERLAY_TILES[nG]
end

-- ==========================================
-- ФАБРИКА ЧАНКІВ
-- ==========================================
function MapRenderer.buildChunkCoroutine(chunkX, chunkY, grid, parentGroupBase, parentGroupTop, customConfig, lodLevel)
    return coroutine.create(function()
        local config = customConfig or WorldConfig
        local cellSize = config.CELL_SIZE
        local width, height = config.MAP_WIDTH, config.MAP_HEIGHT
        local cSize = MapRenderer.CHUNK_SIZE

        local startX = (chunkX - 1) * cSize + 1
        local endX = math.min(startX + cSize - 1, width)
        local startY = (chunkY - 1) * cSize + 1
        local endY = math.min(startY + cSize - 1, height)

        if startX > width or startY > height then return { isEmpty = true } end

        local pixelW = (endX - startX + 1) * cellSize
        local pixelH = (endY - startY + 1) * cellSize
        local mapOffsetX = mFloor(-(width * cellSize / 2) + (cellSize / 2))
        local mapOffsetY = mFloor(-(height * cellSize / 2) + (cellSize / 2))
        local chunkWorldX = mapOffsetX + (startX - 1) * cellSize
        local chunkWorldY = mapOffsetY + (startY - 1) * cellSize

        local groundTex = graphics.newTexture({ type="canvas", width=pixelW, height=pixelH })
        local topTex = nil 

        local hiddenBakeGroup = display.newGroup()
        hiddenBakeGroup.x, hiddenBakeGroup.y = 0, 0 
        display.getCurrentStage():insert(1, hiddenBakeGroup)

        local layer0_base = display.newGroup(); hiddenBakeGroup:insert(layer0_base)
        local layer1_trans = display.newGroup(); hiddenBakeGroup:insert(layer1_trans)
        local layer2_obs = display.newGroup(); hiddenBakeGroup:insert(layer2_obs)

        local obsLayers = {}
        for _, p in ipairs({5, 10, 11, 12, 13}) do
            obsLayers[p] = display.newGroup()
            layer2_obs:insert(obsLayers[p])
        end

        local function checkCancel(signal)
            if signal == "cancel" then
                if hiddenBakeGroup and hiddenBakeGroup.removeSelf then hiddenBakeGroup:removeSelf() end
                if groundTex then groundTex:releaseSelf() end
                if topTex then topTex:releaseSelf() end
                return true
            end
            return false
        end

        local drawnBases = {}; 
        for i = startX - 3, endX + 3 do drawnBases[i] = {} end
        
        local function safeGetLayer(gx, gy)
            if gx >= 1 and gx <= width and gy >= 1 and gy <= height then return getLayer(grid[gx][gy]), grid[gx][gy] end
            return 0, nil
        end

        local function drawOverlay(x, y, dirKey, refCell)
            local c = getOverlayConfig(refCell, grid[x][y])
            if not c or not c[dirKey] then return end
            
            local overlayData = c[dirKey]
            local cx = (x - startX) * cellSize - pixelW/2 + cellSize/2
            local cy = (y - startY) * cellSize - pixelH/2 + cellSize/2
            
            local gType = getGameplayType(refCell)
            local isObstacle = (gType == "obstacle" or gType == "high_obstacle")
            local refLayer = getLayer(refCell)
            local targetGroup = isObstacle and (obsLayers[refLayer] or obsLayers[5]) or layer1_trans
            
            if type(overlayData) == "table" and #overlayData > 0 then
                local tile = display.newImageRect(targetGroup, tilesetSheet, overlayData[mRand(1, #overlayData)], cellSize, cellSize)
                applyColor(tile, refCell) -- Використовуємо нашу нову функцію!
                tile.x, tile.y = cx, cy
            end
             
            if overlayData.base and overlayData.top then
                if #overlayData.base > 0 and not drawnBases[x][y] then
                    local baseTile = display.newImageRect(targetGroup, tilesetSheet, overlayData.base[mRand(1, #overlayData.base)], cellSize, cellSize)
                    baseTile:setFillColor(0.92, 0.85, 0.6); baseTile.x, baseTile.y = cx, cy; drawnBases[x][y] = true 
                end
                if #overlayData.top > 0 then
                    local topTile = display.newImageRect(targetGroup, tilesetSheet, overlayData.top[mRand(1, #overlayData.top)], cellSize, cellSize)
                    applyColor(topTile, refCell)
                    topTile.x, topTile.y = cx, cy
                end
            end

            if overlayData.parts then
                for _, part in ipairs(overlayData.parts) do
                    local tile = display.newImageRect(targetGroup, tilesetSheet, part.frame, cellSize, cellSize)
                    applyColor(tile, refCell)
                    tile.x, tile.y = mFloor(cx + (part.dx or 0) * cellSize), mFloor(cy + (part.dy or 0) * cellSize)
                    
                    -- Захист від дерев у горах
                    local partGridX = x + (part.dx or 0)
                    local partGridY = y + (part.dy or 0)
                    if grid[partGridX] and grid[partGridX][partGridY] then
                        grid[partGridX][partGridY].buildingId = "obstacle_part"
                    end
                end
            end 
        end

        for y = startY, endY do
            for x = startX, endX do
                local cell = grid[x][y]
                local cx = (x - startX) * cellSize - pixelW/2 + cellSize/2
                local cy = (y - startY) * cellSize - pixelH/2 + cellSize/2
                
                local baseFrames = BASE_TILES[getGameplayType(cell)]
                if baseFrames and #baseFrames > 0 then
                    local tile = display.newImageRect(layer0_base, tilesetSheet, baseFrames[mRand(1, #baseFrames)], cellSize, cellSize)
                    applyColor(tile, cell)
                    tile.x, tile.y = cx, cy
                end

                if lodLevel == "high" then
                    local gType = getGameplayType(cell)
                    -- Декорації не ставимо на схили
                    local isSlope = cell.buildingId == "obstacle_part" or cell.isObstaclePart
                    if (gType == "ground" or gType == "forest") and not isSlope then
                        if mRand(1, 100) <= config.RENDER.decorChances.grass then
                            local d = display.newImageRect(layer1_trans, decorSheet, DECOR_FRAMES_GRASS[mRand(1, #DECOR_FRAMES_GRASS)], cellSize/2, cellSize/2)
                            d.x, d.y = cx + mRand(-8, 8), cy
                        end
                    elseif gType == "coast" and not isSlope then
                        if mRand(1, 100) <= config.RENDER.decorChances.coast then
                            local d = display.newImageRect(layer1_trans, decorSheet, DECOR_FRAMES_COAST[mRand(1, #DECOR_FRAMES_COAST)], cellSize/2, cellSize/2)
                            d.x, d.y = cx + mRand(-8, 8), cy
                        end
                    end
                end
            end
            if y % 2 == 0 and checkCancel(coroutine.yield({ status = "Generating Base..." })) then return { isEmpty = true, isCancelled = true } end
        end

        if lodLevel == "high" then
            local expStartX = math.max(1, startX - 3)
            local expEndX = math.min(width, endX + 3)
            local expStartY = math.max(1, startY - 3)
            local expEndY = math.min(height, endY + 3)

            for y = expStartY, expEndY do
                for x = expStartX, expEndX do
                    local cell = grid[x][y]
                    local cx = (x - startX) * cellSize - pixelW/2 + cellSize/2
                    local cy = (y - startY) * cellSize - pixelH/2 + cellSize/2

                    local myLayer = getLayer(cell)
                    local layerN, cellN = safeGetLayer(x, y - 1)
                    local layerS, cellS = safeGetLayer(x, y + 1)
                    local layerW, cellW = safeGetLayer(x - 1, y)
                    local layerE, cellE = safeGetLayer(x + 1, y)

                    local isN, isS, isW, isE = layerN > myLayer, layerS > myLayer, layerW > myLayer, layerE > myLayer
                    local drawN, drawS, drawW, drawE = isN, isS, isW, isE

                    if isN and isW then drawOverlay(x, y, "NW_INNER", cellN); drawN, drawW = false, false end
                    if isN and isE then drawOverlay(x, y, "NE_INNER", cellN); drawN, drawE = false, false end
                    if isS and isW then drawOverlay(x, y, "SW_INNER", cellS); drawS, drawW = false, false end
                    if isS and isE then drawOverlay(x, y, "SE_INNER", cellS); drawS, drawE = false, false end

                    if drawN then drawOverlay(x, y, "N", cellN) end
                    if drawS then drawOverlay(x, y, "S", cellS) end
                    if drawW then drawOverlay(x, y, "W", cellW) end
                    if drawE then drawOverlay(x, y, "E", cellE) end

                    for _, d in ipairs(CONST_DIAGONALS) do
                        local lDiag, cDiag = safeGetLayer(x + d.dx, y + d.dy)
                        if lDiag > myLayer then
                            if safeGetLayer(x+d.adj1.dx, y+d.adj1.dy) < lDiag and safeGetLayer(x+d.adj2.dx, y+d.adj2.dy) < lDiag then drawOverlay(x, y, d.dir, cDiag) end
                        end
                    end

                    local rawGameplay = getGameplayType(cell)
                    if rawGameplay == "obstacle" or rawGameplay == "high_obstacle" then
                        local mtnFrames = BASE_TILES["obstacle"] 
                        if mtnFrames and #mtnFrames > 0 then
                            local myTargetGroup = obsLayers[myLayer] or obsLayers[5]
                            
                            local tile = display.newImageRect(myTargetGroup, tilesetSheet, mtnFrames[mRand(1, #mtnFrames)], cellSize, cellSize)
                            applyColor(tile, cell)
                            tile.x, tile.y = cx, cy
                            
                            if rawGameplay == "high_obstacle" then
                                local topTile = display.newImageRect(myTargetGroup, tilesetSheet, mtnFrames[mRand(1, #mtnFrames)], cellSize, cellSize)
                                applyColor(topTile, cell)
                                topTile.x, topTile.y = cx, cy - (cellSize * 0.6) 
                            end

                            if mRand(1, 100) <= config.RENDER.decorChances.obstacle then
                                local d = display.newImageRect(myTargetGroup, decorSheet, DECOR_FRAMES_OBSTACLE[mRand(1, #DECOR_FRAMES_OBSTACLE)], cellSize/2, cellSize/2)
                                d.x, d.y = cx + mRand(-8, 8), cy
                            end
                        end
                    end
                end
                if y % 2 == 0 and checkCancel(coroutine.yield({ status = "Generating Details..." })) then return { isEmpty = true, isCancelled = true } end
            end
        end

        groundTex:draw(layer0_base); groundTex:draw(layer1_trans); groundTex:invalidate()
        local groundImg = display.newImageRect(groundTex.filename, groundTex.baseDir, pixelW, pixelH)
        groundImg.x, groundImg.y = chunkWorldX + pixelW/2, chunkWorldY + pixelH/2

        local topImg = nil
        if lodLevel == "high" and layer2_obs.numChildren > 0 then
            topTex = graphics.newTexture({ type="canvas", width=pixelW, height=pixelH })
            topTex:draw(layer2_obs); topTex:invalidate()
            
            topImg = display.newImageRect(topTex.filename, topTex.baseDir, pixelW, pixelH)
            topImg.x, topImg.y = groundImg.x, groundImg.y
        end

        timer.performWithDelay(1, function()
            if hiddenBakeGroup and hiddenBakeGroup.removeSelf then 
                display.remove(hiddenBakeGroup)
                hiddenBakeGroup = nil
            end
        end)

        return {
            status = "Done", chunkId = chunkX .. "_" .. chunkY,
            groundImg = groundImg, topImg = topImg, groundTex = groundTex, topTex = topTex, lod = lodLevel
        }
    end)
end

return MapRenderer