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

local treeSheetOptions = {
    width = 48,   -- Ширина одного дерева
    height = 64,  -- Висота одного дерева
    numFrames = 3 -- Кількість різних дерев у файлі trees.png (зміни на свою)
}
local treeSheet = graphics.newImageSheet("src/assets/world/trees.png", treeSheetOptions)

local decorSheetOptions = {
    width = 16,
    height = 16,
    numFrames = 30 
}
local decorSheet = graphics.newImageSheet("src/assets/world/decor.png", decorSheetOptions)

--Список кадрів декор
local DECOR_FRAMES_GRASS = { 1,2,3,4,5,6,7,8,9,10,14,15,16,17,18,19,20,25,26 }
local DECOR_FRAMES_OBSTACLE = {27,28,29 }
local DECOR_FRAMES_COAST = {5,6}
-- НОВЕ: Список кадрів дерев для рандомізації
local TREE_FRAMES = { 1, 2 }

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
        -- Звичайні (пласкі) краї для півночі, заходу і сходу
        N = {parts = {
                { frame = 48+14, dy = 0 }, -- Верхівка обриву (малюється на самій клітинці)
                { frame = 96+14, dy = 1 }, -- Вертикальна стіна (на 1 тайл нижче)
                { frame = 144+14, dy = 2 }  -- Підніжжя скелі, що переходить у землю (на 2 тайли нижче)17
            } },
        S = { 14 },     
        W = { 96+17 }, 
        E = { 96+16 },

        NW = { parts = {
                {frame = 48+17, dy = 0},
                {frame = 192+16, dy = 1},
                {frame = 192+14, dy = 2}, 
            } },

        NE = { parts = {
                {frame = 48+16, dy = 0},
                {frame = 192+15, dy = 1},
                {frame = 192+13, dy = 2}, 
            } },
        SW = { 17 }, 
        SE = { 16},

        
        NE_INNER = { parts = {
                {frame = 47, dy = 0},
                {frame = 192+16, dy = 1},
                {frame = 192+14, dy = 2}, 
            } },

        NW_INNER = { parts = {
                {frame = 46, dy = 0},
                {frame = 192+15, dy = 1},
                {frame = 192+13, dy = 2}, 
            } }, 
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
        local mapGroup = display.newGroup()
        
        
        -- Жорстко відсікаємо будь-які дробові значення
        local startX = math.floor(-(totalWidth / 2) + (CELL_SIZE / 2))
        local startY = math.floor(-(totalHeight / 2) + (CELL_SIZE / 2))

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
                            tile.x = math.floor(startX + (x - 1) * CELL_SIZE)
                            tile.y = math.floor(startY + (y - 1) * CELL_SIZE)
                            mapGroup:insert(tile)
                            --tex:draw(tile)
                            --table.insert(trashBin, tile)
                        end
                    end

                    if myGameplay == "ground" or myGameplay == "forest" then
                        
                        -- Шанс появи декору: 5~15% (густіше/рідше)
                        if math.random(1, 100) <= 6 then
                            
                            local decorFrame = DECOR_FRAMES_GRASS[math.random(1, #DECOR_FRAMES_GRASS)]
                            
                            -- Розтягуємо 16х16 до розміру нашої клітинки (CELL_SIZE), 
                            -- щоб пікселі відповідали масштабу світу
                            decor_size = CELL_SIZE/math.random(1,2);
                            local decorTile = display.newImageRect(decorSheet, decorFrame, decor_size, decor_size)
                            
                            if decorTile then
                                decorTile.x = math.floor(startX + (x - 1) * CELL_SIZE)
                                decorTile.y = math.floor(startY + (y - 1) * CELL_SIZE)

                                decorTile.x = decorTile.x + math.random(-8, 8)
                                mapGroup:insert(decorTile)
                            end
                        end
                    end
                    if myGameplay == "coast" then
                        
                        -- Шанс появи декору: 5~15% (густіше/рідше)
                        if math.random(1, 100) <= 8 then
                            
                            local decorFrame = DECOR_FRAMES_COAST[math.random(1, #DECOR_FRAMES_COAST)]
                            
                            -- Розтягуємо 16х16 до розміру нашої клітинки (CELL_SIZE), 
                            -- щоб пікселі відповідали масштабу світу
                            decor_size = CELL_SIZE/math.random(1,2);
                            local decorTile = display.newImageRect(decorSheet, decorFrame, decor_size, decor_size)
                            
                            if decorTile then
                                decorTile.x = math.floor(startX + (x - 1) * CELL_SIZE)
                                decorTile.y = math.floor(startY + (y - 1) * CELL_SIZE)

                                decorTile.x = decorTile.x + math.random(-8, 8)
                                mapGroup:insert(decorTile)
                            end
                        end
                    end

                    if myGameplay == "obstacle" then
                        
                        -- Шанс появи декору: 5~30% (густіше/рідше)
                        if math.random(1, 100) <= 21 then
                            
                            local decorFrame = DECOR_FRAMES_OBSTACLE[math.random(1, #DECOR_FRAMES_OBSTACLE)]
                            
                            -- Розтягуємо 16х16 до розміру нашої клітинки (CELL_SIZE), 
                            -- щоб пікселі відповідали масштабу світу
                            decor_size = CELL_SIZE/math.random(1,2);
                            local decorTile = display.newImageRect(decorSheet, decorFrame, decor_size, decor_size)
                            
                            if decorTile then
                                decorTile.x = math.floor(startX + (x - 1) * CELL_SIZE)
                                decorTile.y = math.floor(startY + (y - 1) * CELL_SIZE)

                                mapGroup:insert(decorTile)
                            end
                        end
                    end
                    
                    
                    tilesProcessed = tilesProcessed + 1
                    if tilesProcessed % 2000 == 0 then
                        --coroutine.yield({ status = "Pass 1: Base Tiles...", progress = (tilesProcessed / (width * height)) * 0.33 })
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

            -- Локальна функція для малювання 1 оверлею бутерброда або звичайного
            local function drawOverlay(x, y, dirKey, refCell)
                if not refCell then return end
                local config = getOverlayConfig(refCell, grid[x][y])
                if not config or not config[dirKey] then return end
                
                local overlayData = config[dirKey]
                
                -- 1. ПЕРЕВІРКА НА ВЕЛИКІ ГОРИ / СКЕЛІ (parts)
                if overlayData.parts then
                    for _, part in ipairs(overlayData.parts) do
                        
                        local tile = display.newImageRect(tilesetSheet, part.frame, CELL_SIZE, CELL_SIZE)
                        if tile then
                            if refCell.renderColor then 
                                tile:setFillColor(refCell.renderColor[1], refCell.renderColor[2], refCell.renderColor[3])
                            elseif refCell.biome and refCell.biome.color then 
                                tile:setFillColor(refCell.biome.color[1], refCell.biome.color[2], refCell.biome.color[3]) 
                            end
                            
                            --  Додаємо зсув part.dx та part.dy (і округлюємо для мобільних)
                            tile.x = math.floor(startX + (x - 1) * CELL_SIZE + (part.dx or 0) * CELL_SIZE)
                            tile.y = math.floor(startY + (y - 1) * CELL_SIZE + (part.dy or 0) * CELL_SIZE)
                            
                            -- Додаємо в групу замість tex:draw
                            mapGroup:insert(tile)
                        end
                    end
                    
                -- 2. ПЕРЕВІРКА НА "БУТЕРБРОД" (Два шари на одній клітинці)
                elseif overlayData.base and overlayData.top then
                    if #overlayData.base > 0 then
                        local baseTile = display.newImageRect(tilesetSheet, overlayData.base[math.random(1, #overlayData.base)], CELL_SIZE, CELL_SIZE)
                        if baseTile then
                            baseTile:setFillColor(0.92, 0.85, 0.6) 
                            baseTile.x = math.floor(startX + (x - 1) * CELL_SIZE)
                            baseTile.y = math.floor(startY + (y - 1) * CELL_SIZE)
                            mapGroup:insert(baseTile)
                        end
                    end
                    if #overlayData.top > 0 then
                        local topTile = display.newImageRect(tilesetSheet, overlayData.top[math.random(1, #overlayData.top)], CELL_SIZE, CELL_SIZE)
                        if topTile then
                            if refCell.renderColor then topTile:setFillColor(refCell.renderColor[1], refCell.renderColor[2], refCell.renderColor[3])
                            elseif refCell.biome and refCell.biome.color then topTile:setFillColor(refCell.biome.color[1], refCell.biome.color[2], refCell.biome.color[3]) end
                            topTile.x = math.floor(startX + (x - 1) * CELL_SIZE)
                            topTile.y = math.floor(startY + (y - 1) * CELL_SIZE)
                            mapGroup:insert(topTile)
                        end
                    end
                    
                -- 3. СТАНДАРТНЕ МАЛЮВАННЯ (Один тайл)
                else
                    if type(overlayData) == "table" and #overlayData > 0 then
                        local tile = display.newImageRect(tilesetSheet, overlayData[math.random(1, #overlayData)], CELL_SIZE, CELL_SIZE)
                        if tile then
                            if refCell.renderColor then tile:setFillColor(refCell.renderColor[1], refCell.renderColor[2], refCell.renderColor[3])
                            elseif refCell.biome and refCell.biome.color then tile:setFillColor(refCell.biome.color[1], refCell.biome.color[2], refCell.biome.color[3]) end
                            tile.x = math.floor(startX + (x - 1) * CELL_SIZE)
                            tile.y = math.floor(startY + (y - 1) * CELL_SIZE)
                            mapGroup:insert(tile)
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

                    if isN and isW then drawOverlay(x, y, "NW_INNER", cellN); drawN, drawW = false, false end
                    if isN and isE then drawOverlay(x, y, "NE_INNER", cellN); drawN, drawE = false, false end
                    if isS and isW then drawOverlay(x, y, "SW_INNER", cellS); drawS, drawW = false, false end
                    if isS and isE then drawOverlay(x, y, "SE_INNER", cellS); drawS, drawE = false, false end

                    if drawN then drawOverlay(x, y, "N", cellN) end
                    if drawS then drawOverlay(x, y, "S", cellS) end
                    if drawW then drawOverlay(x, y, "W", cellW) end
                    if drawE then drawOverlay(x, y, "E", cellE) end

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
                                drawOverlay(x, y, d.dir, cellDiag)
                            end
                        end
                    end
                    
                    tilesProcessed = tilesProcessed + 1
                    if tilesProcessed % 2000 == 0 then
                        --coroutine.yield({ status = "Pass 2: Overlays...", progress = 0.33 + (tilesProcessed / (width * height)) * 0.33 })
                    end
                end
            end
        end

        -- ==========================================
        -- ПРОХІД 3: ОБ'ЄКТИ ТА ГОРИ (Y-SORTING)
        -- ==========================================
        local function runPass3_Objects()
            Logger.info("Render", "[Pass 3] Drawing Objects and Mountain Bases...")
            
            for y = 1, height do
                for x = 1, width do
                    local cell = grid[x][y]

                    if getGameplayType(cell) == "forest" then
                        print( "forest" )
                        -- Завантажуємо окрему картинку дерева
                        local tree = display.newImageRect(treeSheet, TREE_FRAMES[math.random(1, #TREE_FRAMES)], 96, 128)
                        
                        if tree then
                            -- Зміщуємо дерева в самий низ (до стовбура)
                            tree.anchorY = 1 
                            
                            -- Ставимо стовбур по центру поточної клітинки
                            tree.x = math.floor(startX + (x - 1) * CELL_SIZE)
                            -- Додаємо (CELL_SIZE / 2), щоб стовбур стояв на нижньому краї клітинки
                            tree.y = math.floor(startY + (y - 1) * CELL_SIZE + (CELL_SIZE / 2))
                            
                            -- За бажанням можна трохи рандомізувати відтінок дерева, щоб ліс не був однаковим
                            local shade = math.random(80, 100) / 100
                            tree:setFillColor(shade, shade, shade)
                            
                            mapGroup:insert(tree)
                        end
                    end
                    
                    
                    if getGameplayType(cell) == "obstacle" then
                        
                        -- Беремо базовий кадр гори 
                        local mtnFrames = BASE_TILES["obstacle"] 
                        
                        if mtnFrames and #mtnFrames > 0 then
                            local frame = mtnFrames[math.random(1, #mtnFrames)]
                            local tile = display.newImageRect(tilesetSheet, frame, CELL_SIZE, CELL_SIZE)
                            
                            if tile then
                                if cell.renderColor then
                                    tile:setFillColor(cell.renderColor[1], cell.renderColor[2], cell.renderColor[3])
                                end
                                
                                tile.x = math.floor(startX + (x - 1) * CELL_SIZE)
                                tile.y = math.floor(startY + (y - 1) * CELL_SIZE)
                                
                                mapGroup:insert(tile)
                            end
                        end
                    end
                    
                end
            end
        end

        -- ==========================================
        -- ЗАПУСК ВИБРАНИХ ЕТАПІВ
        -- ==========================================
        if RENDER_STAGES.baseTiles   then runPass1_BaseTiles() end
        if RENDER_STAGES.transitions then runPass2_Transitions() end
        if RENDER_STAGES.obstacles   then runPass3_Objects() end

        -- Збираємо текстуру і віддаємо
        tex:draw(mapGroup)
        tex:invalidate()
        coroutine.yield({ status = "Finalizing GPU render...", progress = 0.99 })
        
        local mapImage = display.newImageRect(parentGroup, tex.filename, tex.baseDir, totalWidth, totalHeight)
        -- Центр екрану на телефонах часто дробовий, округлюємо його
        mapImage.x = math.floor(display.contentCenterX)
        mapImage.y = math.floor(display.contentCenterY)
        Logger.info("Render", "Render Complete!")
        return { status = "Done", result = mapImage }
    end)
end

return MapRenderer