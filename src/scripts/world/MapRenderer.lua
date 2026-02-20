-- src/scripts/view/MapRenderer.lua
local MapRenderer = {}
local Logger = require("src.scripts.utils.logger")

local CELL_SIZE = 64

-- ==========================================
-- НАЛАШТУВАННЯ РЕНДЕРУ (ПЕРЕМИКАЧІ ЕТАПІВ)
-- ==========================================
local RENDER_STAGES = {
    baseTiles   = true,  -- Етап 1: Плоска земля та вода
    transitions = true,  -- Етап 2: Берегові лінії, накладення, кути
    obstacles   = true   -- Етап 3: Високі об'єкти (Гори, Дерева з Y-сортуванням)
}

-- 1. НАЛАШТУВАННЯ ТАЙЛСЕТУ
local sheetOptions = {
    width = 32,
    height = 32,
    numFrames = 816, 
    sheetContentWidth = 1536, 
    sheetContentHeight = 544  -- 48 в строці 
}
local tilesetSheet = graphics.newImageSheet("src/assets/world/tiles.png", sheetOptions)

-- 2. БАЗОВІ ТАЙЛИ
local BASE_TILES = {
    ground    = { 720+1, 720+2, 720+3, 720+4, 720+5, 720+6, 720+7, 720+8, 720+9, 720+10 },
    coast     = { 768+1, 768+2, 768+3, 768+4, 768+5, 768+6, 768+7, 768+8, 768+9, 768+10, 768+11, 768+12, 768+13, 768+14, 768+15, 768+16, 768+17, 768+18 },
    forest    = { 720+1 }, 
    scorched  = { 720+1 }, 
    water     = { 720+11 },
    obstacle  = { 720+12 } 
}

-- НОВЕ: Графіка для Гір
local OBSTACLE_TILES = {
    bare = { 22 }, 
    snow = { 22 }, 
}

local LAYER_PRIORITY = {
    water    = 0,
    coast    = 1,
    ground   = 2,
    obstacle = 3  
}

local OVERLAY_TILES = {
    ground = {
        N = { 2, 48+2, 96+2, 144+2, 192+2, 240+2 },-- перший, другий,третій,четвертий,пятий,шостий ряди
        S = { 1, 48+1, 96+1, 144+1, 192+1, 240+1 },
        W = { 5, 48+5, 96+5, 144+5, 192+5, 240+5 },
        E = { 6, 48+6, 96+6, 144+6, 192+6, 240+6 },
        NW = { 336+2, 336+4, 336+6 }, -- 8 ряд
        NE = { 336+1, 336+3, 336+5 }, 
        SW = { 288+2, 288+4, 288+6 }, --верхнє 7 ряд
        SE = { 288+1, 288+3, 288+5 },
        NW_INNER = { 7, 9, 11 }, 
        NE_INNER = { 8, 10, 12 }, --верхнє
        SW_INNER = { 48+7,48+ 9, 48+11 }, 
        SE_INNER = { 48+8, 48+10, 48+12 }
    },
    ground_over_water = {
        N =  { base = { 192+3, 192+4 }, top = { 48+2 } },
        S =  { base = { 192+9, 192+10, 192+11, 192+12 }, top = { 48+1 } },
        W =  { base = { 192+9, 192+10, 192+11, 192+12 }, top = { 48+5 } },
        E =  { base = { 4, 48+4, 96+4, 144+4 }, top = { 48+6 } },
        NW = { base = { 240+9,240+11 }, top = { 336+6 } },
        NE = { base = { 240+9,240+11  }, top = { 336+5 } },
        SW = { base = { 192+10, 192+12 }, top = { 288+6 } },
        SE = { base = { 192+10, 192+12 }, top = { 288+5 } },
        NW_INNER = { base = { 96+7, 96+9, 96+11 }, top = { 2 } }, -- 11 12 48+11 48+12
        NE_INNER = { base = { 96+8, 96+10, 96+12 }, top = { 2 } },
        SW_INNER = { base = { 144+7,144+ 9, 144+11 }, top = { 1 } },
        SE_INNER = { base = { 144+8, 144+10, 144+12 }, top = { 1 } },
    },
    coast = {
        N = { 240+9, 240+10, 240+11, 240+12 },
        S = {  192+9, 192+10, 192+11, 192+12}, 
        W = { 3, 48+3, 96+3, 144+3 }, 
        E = { 4, 48+4, 96+4, 144+4 },
        NW = { 432+2, 432+4 }, 
        NE = { 432+1, 432+3 }, 
        SW = { 384+2, 384+4 }, 
        SE = { 384+1, 384+3 },
        NW_INNER = { 96+7, 96+9, 96+11 }, 
        NE_INNER = { 96+8, 96+10, 96+12 }, 
        SW_INNER = { 144+7,144+ 9, 144+11 }, 
        SE_INNER = { 144+8, 144+10, 144+12 }
    },

    obstacle = {
        N = { },
        S = {},
        W = {},
        E = {},
        NW = { 14,  96+14, 144+14}, 
        NE = { 13,  96+13, 144+13 }, 
        SW = {  }, 
        SE = {  },
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
    if nGameplay == "ground" and myGameplay == "water" then
        return OVERLAY_TILES["ground_over_water"]
    end
    return OVERLAY_TILES[nGameplay]
end

-- ==========================================
-- ГОЛОВНА ФУНКЦІЯ РЕНДЕРУ
-- ==========================================
function MapRenderer.createRenderCoroutine(grid, parentGroup)
    return coroutine.create(function()
        Logger.info("Render", "Starting Multi-Pass Map Rendering...")
        
        local width = #grid
        local height = #grid[1]
        local totalWidth = width * CELL_SIZE
        local totalHeight = height * CELL_SIZE
        
        local tex = graphics.newTexture({ type="canvas", width=totalWidth, height=totalHeight })
        
        
        local startX = -(totalWidth / 2) + (CELL_SIZE / 2)
        local startY = -(totalHeight / 2) + (CELL_SIZE / 2)

        -- ==========================================
        -- ПРОХІД 1: БАЗОВІ ТАЙЛИ
        -- ==========================================
        local function runPass1_BaseTiles()
            Logger.info("Render", "[Pass 1] Drawing Base Tiles...")
            local tilesProcessed = 0
            
            for y = 1, height do
                for x = 1, width do
                    local cell = grid[x][y]
                    local myGameplay = getGameplayType(cell)
                    
                    local baseFrames = BASE_TILES[myGameplay]
                    if baseFrames and #baseFrames > 0 then
                        local frame = baseFrames[math.random(1, #baseFrames)]
                        local tile = display.newImageRect(tilesetSheet, frame, CELL_SIZE, CELL_SIZE)
                        
                        if tile then
                            if cell.renderColor then
                                tile:setFillColor(cell.renderColor[1], cell.renderColor[2], cell.renderColor[3])
                            end
                            tile.x = startX + (x - 1) * CELL_SIZE
                            tile.y = startY + (y - 1) * CELL_SIZE
                            tex:draw(tile)
                            
                        end
                    end
                    
                    tilesProcessed = tilesProcessed + 1
                    if tilesProcessed % 2000 == 0 then
                        coroutine.yield({ status = "Pass 1: Base Tiles...", progress = (tilesProcessed / (width * height)) * 0.33 })
                    end
                end
            end
        end

        -- ==========================================
        -- ПРОХІД 2: ПЕРЕХОДИ ТА КРАЇ
        -- ==========================================
        local function runPass2_Transitions()
            Logger.info("Render", "[Pass 2] Drawing Transitions and Overlays...")
            local tilesProcessed = 0

            local function safeGetLayer(gx, gy)
                if gx >= 1 and gx <= width and gy >= 1 and gy <= height then
                    return getLayer(grid[gx][gy]), grid[gx][gy]
                end
                return 0, nil
            end

            -- Локальна функція для малювання 1 оверлею (бутерброда або звичайного)
            local function drawSingleOverlay(x, y, dirKey, refCell)
                if not refCell then return end
                local config = getOverlayConfig(refCell, grid[x][y])
                if not config or not config[dirKey] then return end
                
                local overlayData = config[dirKey]
                
                if overlayData.base and overlayData.top then
                    if #overlayData.base > 0 then
                        local baseTile = display.newImageRect(tilesetSheet, overlayData.base[math.random(1, #overlayData.base)], CELL_SIZE, CELL_SIZE)
                        if baseTile then
                            baseTile:setFillColor(0.92, 0.85, 0.6) 
                            baseTile.x, baseTile.y = startX + (x - 1) * CELL_SIZE, startY + (y - 1) * CELL_SIZE
                            tex:draw(baseTile)
                            
                        end
                    end
                    if #overlayData.top > 0 then
                        local topTile = display.newImageRect(tilesetSheet, overlayData.top[math.random(1, #overlayData.top)], CELL_SIZE, CELL_SIZE)
                        if topTile then
                            if refCell.renderColor then topTile:setFillColor(refCell.renderColor[1], refCell.renderColor[2], refCell.renderColor[3])
                            elseif refCell.biome and refCell.biome.color then topTile:setFillColor(refCell.biome.color[1], refCell.biome.color[2], refCell.biome.color[3]) end
                            topTile.x, topTile.y = startX + (x - 1) * CELL_SIZE, startY + (y - 1) * CELL_SIZE
                            tex:draw(topTile)
                            
                        end
                    end
                else
                    if type(overlayData) == "table" and #overlayData > 0 then
                        local tile = display.newImageRect(tilesetSheet, overlayData[math.random(1, #overlayData)], CELL_SIZE, CELL_SIZE)
                        if tile then
                            if refCell.renderColor then tile:setFillColor(refCell.renderColor[1], refCell.renderColor[2], refCell.renderColor[3])
                            elseif refCell.biome and refCell.biome.color then tile:setFillColor(refCell.biome.color[1], refCell.biome.color[2], refCell.biome.color[3]) end
                            tile.x, tile.y = startX + (x - 1) * CELL_SIZE, startY + (y - 1) * CELL_SIZE
                            tex:draw(tile)
                            
                        end
                    end
                end
            end

            for y = 1, height do
                for x = 1, width do
                    local myLayer = getLayer(grid[x][y])
                    
                    -- 1. Прямі та Внутрішні кути
                    local layerN, cellN = safeGetLayer(x, y - 1)
                    local layerS, cellS = safeGetLayer(x, y + 1)
                    local layerW, cellW = safeGetLayer(x - 1, y)
                    local layerE, cellE = safeGetLayer(x + 1, y)

                    local isN, isS, isW, isE = layerN > myLayer, layerS > myLayer, layerW > myLayer, layerE > myLayer
                    local drawN, drawS, drawW, drawE = isN, isS, isW, isE

                    if isN and isW then drawSingleOverlay(x, y, "NW_INNER", cellN); drawN, drawW = false, false end
                    if isN and isE then drawSingleOverlay(x, y, "NE_INNER", cellN); drawN, drawE = false, false end
                    if isS and isW then drawSingleOverlay(x, y, "SW_INNER", cellS); drawS, drawW = false, false end
                    if isS and isE then drawSingleOverlay(x, y, "SE_INNER", cellS); drawS, drawE = false, false end

                    if drawN then drawSingleOverlay(x, y, "N", cellN) end
                    if drawS then drawSingleOverlay(x, y, "S", cellS) end
                    if drawW then drawSingleOverlay(x, y, "W", cellW) end
                    if drawE then drawSingleOverlay(x, y, "E", cellE) end

                    -- 2. Зовнішні кути (Діагоналі)
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
                                drawSingleOverlay(x, y, d.dir, cellDiag)
                            end
                        end
                    end
                    
                    tilesProcessed = tilesProcessed + 1
                    if tilesProcessed % 2000 == 0 then
                        coroutine.yield({ status = "Pass 2: Overlays...", progress = 0.33 + (tilesProcessed / (width * height)) * 0.33 })
                    end
                end
            end
        end

        -- ==========================================
        -- ПРОХІД 3: ОБ'ЄКТИ ТА ГОРИ (Y-SORTING)
        -- ==========================================
        local function runPass3_Obstacles()
            Logger.info("Render", "[Pass 3] Drawing Obstacles (Mountains)...")
            local tilesProcessed = 0
            
            -- Йдемо СТРОГО зверху вниз по осі Y
            for y = 1, height do
                for x = 1, width do
                    local cell = grid[x][y]
                    
                    if getGameplayType(cell) == "obstacle" then
                        -- Шукаємо тип гори, або беремо дефолтну ("bare")
                        local mountainFrames = OBSTACLE_TILES[cell.type] or OBSTACLE_TILES["bare"]
                        
                        if mountainFrames and #mountainFrames > 0 then
                            local frame = mountainFrames[math.random(1, #mountainFrames)]
                            local mountainTile = display.newImageRect(tilesetSheet, frame, CELL_SIZE, CELL_SIZE)
                            
                            if mountainTile then
                                -- Зазвичай гори не фарбують, але якщо треба:
                                if cell.renderColor then
                                    mountainTile:setFillColor(cell.renderColor[1], cell.renderColor[2], cell.renderColor[3])
                                end
                                
                                mountainTile.x = startX + (x - 1) * CELL_SIZE
                                mountainTile.y = startY + (y - 1) * CELL_SIZE
                                tex:draw(mountainTile)
                                
                            end
                        end
                    end
                    
                    tilesProcessed = tilesProcessed + 1
                end
                
                -- Викликаємо yield по завершенню кожного рядка Y (щоб графіка не фрізила)
                if y % 10 == 0 then
                    coroutine.yield({ status = "Pass 3: Mountains...", progress = 0.66 + (y / height) * 0.34 })
                end
            end
        end

        -- ==========================================
        -- ЗАПУСК ВИБРАНИХ ЕТАПІВ
        -- ==========================================
        if RENDER_STAGES.baseTiles   then runPass1_BaseTiles() end
        if RENDER_STAGES.transitions then runPass2_Transitions() end
        if RENDER_STAGES.obstacles   then runPass3_Obstacles() end

        -- Збираємо текстуру і віддаємо
        tex:invalidate()
        local mapImage = display.newImageRect(parentGroup, tex.filename, tex.baseDir, totalWidth, totalHeight)
        mapImage.x = display.contentCenterX
        mapImage.y = display.contentCenterY
        
        Logger.info("Render", "Render Complete!")
        return { status = "Done", result = mapImage }
    end)
end

return MapRenderer