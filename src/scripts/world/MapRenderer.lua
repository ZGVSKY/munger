-- src/scripts/view/MapRenderer.lua
local MapRenderer = {}
local Logger = require("src.scripts.utils.logger")
local WorldConfig = require("src.scripts.config.WorldConfig")

-- ОПТИМІЗАЦІЯ: Локальне кешування математичних функцій (дуже прискорює цикли в Lua)
local mFloor = math.floor
local mRand = math.random

-- ==========================================
-- 1. НАЛАШТУВАННЯ ТАЙЛСЕТІВ (Залишаємо як було)
-- ==========================================
local sheetOptions = {
    width = 32, height = 32,
    numFrames = 816, 
    sheetContentWidth = 1536, sheetContentHeight = 544 
}
local tilesetSheet = graphics.newImageSheet("src/assets/world/tiles.png", sheetOptions)

local treeSheetOptions = {
    width = 48, height = 64, numFrames = 3
}
local treeSheet = graphics.newImageSheet("src/assets/world/trees.png", treeSheetOptions)

local decorSheetOptions = {
    width = 16, height = 16, numFrames = 30 
}
local decorSheet = graphics.newImageSheet("src/assets/world/decor.png", decorSheetOptions)

local DECOR_FRAMES_GRASS = { 1,2,3,4,5,6,7,8,9,10,14,15,16,17,18,19,20,25,26 }
local DECOR_FRAMES_OBSTACLE = {27,28,29 }
local DECOR_FRAMES_COAST = {5,6}
local TREE_FRAMES = { 1, 2, 3 }

-- ==========================================
-- 2. БАЗОВІ ТАЙЛИ ТА ІЄРАРХІЯ
-- ==========================================
local BASE_TILES = {
    ground    = { 720+1, 720+2, 720+3, 720+4, 720+5, 720+6, 720+7, 720+8, 720+9, 720+10 },
    coast     = { 768+1, 768+2, 768+3, 768+4, 768+5, 768+6, 768+7, 768+8, 768+9, 768+10, 768+11, 768+12, 768+13, 768+14, 768+15, 768+16, 768+17, 768+18 },
    forest    = { 720+1 }, 
    scorched  = { 720+1 }, 
    water     = { 720+11 },
    river     = { 720+11 },
    obstacle  = { 720+12 } 
}

local LAYER_PRIORITY = {
    water    = 0,
    river    = 1,
    coast    = 2,
    ground   = 3,
    forest   = 4,
    obstacle = 5 
}

local OVERLAY_TILES = {
    ground = {
        N = { 2, 48+2, 96+2, 144+2, 192+2, 240+2 },
        S = { 1, 48+1, 96+1, 144+1, 192+1, 240+1 },
        W = { 5, 48+5, 96+5, 144+5, 192+5, 240+5 },
        E = { 6, 48+6, 96+6, 144+6, 192+6, 240+6 },
        NW = { 336+2, 336+4, 336+6 }, 
        NE = { 336+1, 336+3, 336+5 }, 
        SW = { 288+2, 288+4, 288+6 }, 
        SE = { 288+1, 288+3, 288+5 },
        NW_INNER = { 7, 9, 11 }, 
        NE_INNER = { 8, 10, 12 }, 
        SW_INNER = { 48+7, 48+9, 48+11 }, 
        SE_INNER = { 48+8, 48+10, 48+12 }
    },
    ground_over_water = {
        N =  { base = { 240+9, 240+10, 240+12 }, top = { 48+2 } },
        S =  { base = { 192+9, 192+10, 192+11, 192+12 }, top = { 48+1 } },
        W =  { base = { 3, 48+3, 96+3, 144+3 }, top = { 48+5 } },
        E =  { base = { 4, 48+4, 96+4, 144+4 }, top = { 48+6 } },
        NW = { base = { 432+4 }, top = { 336+6 } },
        NE = { base = { 432+3 }, top = { 336+5 } },
        SW = { base = { 384+2, 384+4 }, top = { 288+6 } },
        SE = { base = { 384+1, 384+3 }, top = { 288+5 } },
        NW_INNER = { base = { 96+7, 96+9, 96+11 }, top = { 7 } }, 
        NE_INNER = { base = { 96+8, 96+10, 96+12 }, top = { 8 } },
        SW_INNER = { base = { 144+7, 144+9, 144+11 }, top = { 48+7 } },
        SE_INNER = { base = { 144+8, 144+10, 144+12 }, top = { 48+8 } },
    },
    coast = {
        N = { 240+9, 240+10, 240+11, 240+12 },
        S = { 192+9, 192+10, 192+11, 192+12 }, 
        W = { 3, 48+3, 96+3, 144+3 }, 
        E = { 4, 48+4, 96+4, 144+4 },
        NW = { 432+2, 432+4 }, 
        NE = { 432+1, 432+3 }, 
        SW = { 384+2, 384+4 }, 
        SE = { 384+1, 384+3 },
        NW_INNER = { 96+7, 96+9, 96+11 }, 
        NE_INNER = { 96+8, 96+10, 96+12 }, 
        SW_INNER = { 144+7, 144+9, 144+11 }, 
        SE_INNER = { 144+8, 144+10, 144+12 }
    },
    obstacle = {
        N = { parts = { { frame = 48+14, dy = 0 }, { frame = 96+14, dy = 1 }, { frame = 144+14, dy = 2 } } },
        S = { 14 },     
        W = { 96+17 }, 
        E = { 96+16 },
        NW = { parts = { {frame = 48+17, dy = 0}, {frame = 192+16, dy = 1}, {frame = 192+14, dy = 2} } },
        NE = { parts = { {frame = 48+16, dy = 0}, {frame = 192+15, dy = 1}, {frame = 192+13, dy = 2} } },
        SW = { 17 }, 
        SE = { 16},
        NE_INNER = { parts = { {frame = 47, dy = 0}, {frame = 192+16, dy = 1}, {frame = 192+14, dy = 2} } },
        NW_INNER = { parts = { {frame = 46, dy = 0}, {frame = 192+15, dy = 1}, {frame = 192+13, dy = 2} } }, 
        SW_INNER = { 144+7 }, 
        SE_INNER = { 144+8 }
    }
}

-- ==========================================
-- ДОПОМІЖНІ ФУНКЦІЇ ДЛЯ ЛОГІКИ
-- ==========================================
local function getGameplayType(cell)
    if not cell or not cell.biome then return "water" end
    return cell.biome.gameplay or "water"
end

local function getLayer(cell)
    local gType = getGameplayType(cell)
    return LAYER_PRIORITY[gType] or 0
end

local function getOverlayConfig(neighborCell, myCell)
    if not neighborCell or not myCell then return nil end
    local nGameplay = getGameplayType(neighborCell)
    local myGameplay = getGameplayType(myCell)
    
    if nGameplay == "ground" and (myGameplay == "water" or myGameplay == "river") then
        return OVERLAY_TILES["ground_over_water"]
    end
    if nGameplay == "forest" then
        if myGameplay == "river" or myGameplay == "water" then return OVERLAY_TILES["ground_over_water"] end
        if myGameplay == "coast" or myGameplay == "ground" then return OVERLAY_TILES["ground"] end
    end
    if neighborCell.biome.id == "scorched" and myGameplay == "ground" then
        return OVERLAY_TILES["ground"]
    end
    
    return OVERLAY_TILES[nGameplay]
end

-- ==========================================
-- ГОЛОВНА ФУНКЦІЯ РЕНДЕРУ 
-- ==========================================
function MapRenderer.createRenderCoroutine(grid, parentGroup, customConfig)
    return coroutine.create(function()
        Logger.info("Render", "Starting Multi-Pass Map Rendering...")
        
        local config = customConfig or WorldConfig
        local cellSize = config.CELL_SIZE
        local width = config.MAP_WIDTH
        local height = config.MAP_HEIGHT
        
        local totalWidth = width * cellSize
        local totalHeight = height * cellSize
        
        local tex = graphics.newTexture({ type="canvas", width=totalWidth, height=totalHeight })
        local overLayerGroupTex = graphics.newTexture({ type="canvas", width=totalWidth, height=totalHeight })
        
        local mapGroup = display.newGroup()
        local overLayerGroup = display.newGroup()
        
        local startX = mFloor(-(totalWidth / 2) + (cellSize / 2))
        local startY = mFloor(-(totalHeight / 2) + (cellSize / 2))

        -- ПРОХІД 1: БАЗОВІ ТАЙЛИ
        if config.RENDER.stages.baseTiles then
            Logger.info("Render", "[Pass 1] Drawing Base Tiles...")
            for y = 1, height do
                for x = 1, width do
                    local cell = grid[x][y]
                    local myGameplay = getGameplayType(cell)
                    
                    local cx = mFloor(startX + (x - 1) * cellSize)
                    local cy = mFloor(startY + (y - 1) * cellSize)
                    
                    local baseFrames = BASE_TILES[myGameplay]
                    if baseFrames and #baseFrames > 0 then
                        local tile = display.newImageRect(tilesetSheet, baseFrames[mRand(1, #baseFrames)], cellSize, cellSize)
                        if tile then
                            if cell.renderColor then tile:setFillColor(cell.renderColor[1], cell.renderColor[2], cell.renderColor[3]) end
                            tile.x, tile.y = cx, cy
                            mapGroup:insert(tile)
                        end
                    end

                    -- ДЕКОРАЦІЇ
                    if myGameplay == "ground" or myGameplay == "forest" then
                        if mRand(1, 100) <= config.RENDER.decorChances.grass then
                            local decor_size = cellSize / mRand(1, 2)
                            local decorTile = display.newImageRect(decorSheet, DECOR_FRAMES_GRASS[mRand(1, #DECOR_FRAMES_GRASS)], decor_size, decor_size)
                            if decorTile then
                                decorTile.x, decorTile.y = cx + mRand(-8, 8), cy
                                mapGroup:insert(decorTile)
                            end
                        end
                    elseif myGameplay == "coast" then
                        if mRand(1, 100) <= config.RENDER.decorChances.coast then
                            local decor_size = cellSize / mRand(1, 2)
                            local decorTile = display.newImageRect(decorSheet, DECOR_FRAMES_COAST[mRand(1, #DECOR_FRAMES_COAST)], decor_size, decor_size)
                            if decorTile then
                                decorTile.x, decorTile.y = cx + mRand(-8, 8), cy
                                mapGroup:insert(decorTile)
                            end
                        end
                    elseif myGameplay == "obstacle" then
                        if mRand(1, 100) <= config.RENDER.decorChances.obstacle then
                            local decor_size = cellSize / mRand(1, 2)
                            local decorTile = display.newImageRect(decorSheet, DECOR_FRAMES_OBSTACLE[mRand(1, #DECOR_FRAMES_OBSTACLE)], decor_size, decor_size)
                            if decorTile then
                                decorTile.x, decorTile.y = cx, cy
                                mapGroup:insert(decorTile)
                            end
                        end
                    end
                end
            end
            coroutine.yield({ status = "Render Base...", progress = 0.33 })
        end

        -- ПРОХІД 2: ПЕРЕХОДИ ТА КРАЇ
        if config.RENDER.stages.transitions then
            Logger.info("Render", "[Pass 2] Drawing Transitions...")
            local drawnBases = {}

            local function safeGetLayer(gx, gy)
                if gx >= 1 and gx <= width and gy >= 1 and gy <= height then
                    return getLayer(grid[gx][gy]), grid[gx][gy]
                end
                return 0, nil
            end

            local function drawOverlay(x, y, dirKey, refCell)
                if not refCell then return end
                local c = getOverlayConfig(refCell, grid[x][y])
                if not c or not c[dirKey] then return end
                
                local overlayData = c[dirKey]
                local cx = mFloor(startX + (x - 1) * cellSize)
                local cy = mFloor(startY + (y - 1) * cellSize)
                
                if type(overlayData) == "table" and #overlayData > 0 then
                    local tile = display.newImageRect(tilesetSheet, overlayData[mRand(1, #overlayData)], cellSize, cellSize)
                    if tile then
                        if refCell.renderColor then tile:setFillColor(refCell.renderColor[1], refCell.renderColor[2], refCell.renderColor[3])
                        elseif refCell.biome and refCell.biome.color then tile:setFillColor(refCell.biome.color[1], refCell.biome.color[2], refCell.biome.color[3]) end
                        tile.x, tile.y = cx, cy
                        mapGroup:insert(tile)
                    end
                end
                 
                if overlayData.base and overlayData.top then
                    local cellKey = x .. "_" .. y
                    if #overlayData.base > 0 and not drawnBases[cellKey] then
                        local baseTile = display.newImageRect(tilesetSheet, overlayData.base[mRand(1, #overlayData.base)], cellSize, cellSize)
                        if baseTile then
                            baseTile:setFillColor(0.92, 0.85, 0.6) 
                            baseTile.x, baseTile.y = cx, cy
                            mapGroup:insert(baseTile)
                            drawnBases[cellKey] = true 
                        end
                    end

                    if #overlayData.top > 0 then
                        local topTile = display.newImageRect(tilesetSheet, overlayData.top[mRand(1, #overlayData.top)], cellSize, cellSize)
                        if topTile then
                            if refCell.renderColor then topTile:setFillColor(refCell.renderColor[1], refCell.renderColor[2], refCell.renderColor[3])
                            elseif refCell.biome and refCell.biome.color then topTile:setFillColor(refCell.biome.color[1], refCell.biome.color[2], refCell.biome.color[3]) end
                            topTile.x, topTile.y = cx, cy
                            mapGroup:insert(topTile)
                        end
                    end
                end
                    
                if overlayData.parts then
                    for _, part in ipairs(overlayData.parts) do
                        local tile = display.newImageRect(tilesetSheet, part.frame, cellSize, cellSize)
                        if tile then
                            if refCell.renderColor then tile:setFillColor(refCell.renderColor[1], refCell.renderColor[2], refCell.renderColor[3])
                            elseif refCell.biome and refCell.biome.color then tile:setFillColor(refCell.biome.color[1], refCell.biome.color[2], refCell.biome.color[3]) end
                            
                            tile.x = mFloor(cx + (part.dx or 0) * cellSize)
                            tile.y = mFloor(cy + (part.dy or 0) * cellSize)
                            overLayerGroup:insert(tile)
                        end
                    end
                end 
            end

            for y = 1, height do
                for x = 1, width do
                    local myLayer = getLayer(grid[x][y])
                    
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

                    local diagonals = {
                        { dx = -1, dy = -1, dir = "NW", adj1 = {dx=0, dy=-1}, adj2 = {dx=-1, dy=0} }, 
                        { dx = 1,  dy = -1, dir = "NE", adj1 = {dx=0, dy=-1}, adj2 = {dx=1, dy=0}  }, 
                        { dx = -1, dy = 1,  dir = "SW", adj1 = {dx=0, dy=1},  adj2 = {dx=-1, dy=0} }, 
                        { dx = 1,  dy = 1,  dir = "SE", adj1 = {dx=0, dy=1},  adj2 = {dx=1, dy=0}  }, 
                    }
                    for _, d in ipairs(diagonals) do
                        local layerDiag, cellDiag = safeGetLayer(x + d.dx, y + d.dy)
                        if layerDiag > myLayer then
                            local lAdj1 = safeGetLayer(x + d.adj1.dx, y + d.adj1.dy)
                            local lAdj2 = safeGetLayer(x + d.adj2.dx, y + d.adj2.dy)
                            if lAdj1 < layerDiag and lAdj2 < layerDiag then
                                drawOverlay(x, y, d.dir, cellDiag)
                            end
                        end
                    end
                end
            end
            coroutine.yield({ status = "Render Overlays...", progress = 0.66 })
        end

        -- ПРОХІД 3: ОБ'ЄКТИ ТА ГОРИ
        if config.RENDER.stages.obstacles then
            Logger.info("Render", "[Pass 3] Drawing Objects...")
            for y = 1, height do
                for x = 1, width do
                    local cell = grid[x][y]
                    local cx = mFloor(startX + (x - 1) * cellSize)
                    local cy = mFloor(startY + (y - 1) * cellSize)

                    if getGameplayType(cell) == "forest" then
                        local tree = display.newImageRect(treeSheet, TREE_FRAMES[mRand(1, #TREE_FRAMES)], 96, 128)
                        if tree then
                            tree.anchorY = 1 
                            tree.x = cx + mRand(-config.RENDER.treeOffset, config.RENDER.treeOffset)
                            tree.y = cy + (cellSize / 2) + mRand(-config.RENDER.treeOffset, config.RENDER.treeOffset)
                            
                            local shadeMin = mFloor(config.RENDER.treeShadeMin * 10)
                            local shadeMax = mFloor(config.RENDER.treeShadeMax * 10)
                            local shade = mRand(shadeMin, shadeMax) / 10
                            tree:setFillColor(shade, shade, shade)
                            
                            overLayerGroup:insert(tree)
                        end
                    end
                    
                    if getGameplayType(cell) == "obstacle" then
                        local mtnFrames = BASE_TILES["obstacle"] 
                        if mtnFrames and #mtnFrames > 0 then
                            local tile = display.newImageRect(tilesetSheet, mtnFrames[mRand(1, #mtnFrames)], cellSize, cellSize)
                            if tile then
                                if cell.renderColor then tile:setFillColor(cell.renderColor[1], cell.renderColor[2], cell.renderColor[3]) end
                                tile.x, tile.y = cx, cy
                                overLayerGroup:insert(tile)
                            end
                        end
                    end
                end
            end
        end

        -- Збираємо текстуру
        local fullmapGroup = display.newGroup()

        tex:draw(mapGroup)
        tex:invalidate()

        overLayerGroupTex:draw(overLayerGroup)
        overLayerGroupTex:invalidate()

        coroutine.yield({ status = "Finalizing GPU render...", progress = 0.99 })
        
        local mapImage = display.newImageRect(parentGroup, tex.filename, tex.baseDir, totalWidth, totalHeight)
        mapImage.x = mFloor(display.contentCenterX)
        mapImage.y = mFloor(display.contentCenterY)

        local overLayerImage = display.newImageRect(parentGroup, overLayerGroupTex.filename, overLayerGroupTex.baseDir, totalWidth, totalHeight)
        overLayerImage.x = mFloor(display.contentCenterX)
        overLayerImage.y = mFloor(display.contentCenterY)

        fullmapGroup:insert(mapImage)
        fullmapGroup:insert(overLayerImage)

        Logger.info("Render", "Render Complete!")
        return { status = "Done", result = fullmapGroup }
    end)
end

return MapRenderer