-- src/scripts/view/MapRenderer.lua
local MapRenderer = {}
local Logger = require("src.scripts.utils.logger")

local CELL_SIZE = 8

--- Створює КОРУТИНУ для рендеру
function MapRenderer.createRenderCoroutine(grid, parentGroup)
    return coroutine.create(function()
        local widthCells = #grid
        local heightCells = #grid[1]
        local totalWidth = widthCells * CELL_SIZE
        local totalHeight = heightCells * CELL_SIZE
        
        Logger.info("Renderer", "Start Baking Texture: " .. totalWidth .. "x" .. totalHeight)
        
        -- 1. Створюємо порожню текстуру
        local tex = graphics.newTexture({ type="canvas", width=totalWidth, height=totalHeight })
        
        -- 2. Малюємо фон (вода) - один раз
        local bg = display.newRect(0, 0, totalWidth, totalHeight)
        bg:setFillColor(1, 1, 1)
        bg.x, bg.y = 0, 0
        tex:draw(bg)
        bg:removeSelf()

        -- Параметри для циклу
        -- Canvas (0,0) - це центр, тому рахуємо зміщення
        local startX = -(totalWidth / 2) + (CELL_SIZE / 2)
        local startY = -(totalHeight / 2) + (CELL_SIZE / 2)
        
        local tilesProcessed = 0
        local totalTiles = widthCells * heightCells

        -- 3. Проходимо по карті
        for x = 1, widthCells do
            for y = 1, heightCells do
                local cell = grid[x][y]
                -- Створюємо НОВИЙ об'єкт (як ти й казав)
                -- Ми не додаємо його в групу (parent=nil), щоб не засмічувати сцену
                local rect = display.newRect(0, 0, CELL_SIZE, CELL_SIZE)
                
                -- Фарбуємо
                
                -- Пріоритет 3: Біом
                if cell.biome and cell.biome.color then
                    local c = cell.biome.color
                    rect:setFillColor(c[1], c[2], c[3])
                else
                    rect:setFillColor(1, 0, 1) -- Рожевий помилки
                end
                if cell.isRiver then 
                    rect:setFillColor(0.2, 0.6, 1.0)
                end
                
                
                -- Позиціонуємо
                rect.x = startX + (x - 1) * CELL_SIZE
                rect.y = startY + (y - 1) * CELL_SIZE
                
                -- Штампуємо в текстуру
                tex:draw(rect)       
                --rect:removeSelf()
                tilesProcessed = tilesProcessed + 1
                
                -- Кожні 500 тайлів (або кожен рядок) перериваємось, щоб оновити екран
                if tilesProcessed % 500 == 0 then
                    local progress = tilesProcessed / totalTiles
                    coroutine.yield({ status = "Painting World...", progress = progress })
                end
            end
        end
        
        Logger.info("Renderer", "Baking finished. Finalizing texture...")
        
        -- Примусово оновлюємо текстуру
        tex:invalidate()
        
        -- Створюємо фінальну картинку
        local mapImage = display.newImageRect(parentGroup, tex.filename, tex.baseDir, totalWidth, totalHeight)
        mapImage.x = display.contentCenterX
        mapImage.y = display.contentCenterY
        
        -- Повертаємо готовий об'єкт
        return { status = "Done", result = mapImage }
    end)
end

return MapRenderer