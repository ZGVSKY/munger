-- src/scripts/world/ChunkManager.lua
local ChunkManager = {}

local MapRenderer = require("src.scripts.world.MapRenderer")
local Logger = require("src.scripts.utils.logger")
local WorldConfig = require("src.scripts.config.WorldConfig")

local activeChunks = {}       
local processingQueue = {}    
local generatingChunks = {}   
ChunkManager.requiredChunks = {} 

local gridRef, configRef, groupBaseRef, groupTopRef = nil, nil, nil, nil
local CHUNK_SIZE = MapRenderer.CHUNK_SIZE
local CELL_SIZE = WorldConfig.CELL_SIZE
local CHUNK_PIXEL_SIZE = CHUNK_SIZE * CELL_SIZE

-- ==========================================
-- СИСТЕМНІ ПОДІЇ (Порятунок від втрати OpenGL)
-- ==========================================
local function onSystemEvent(event)
    if event.type == "applicationResume" then
        Logger.info("ChunkManager", "App resumed! OpenGL Context Lost. Rebuilding all chunks...")
        -- Гра розгорнулася - знищуємо зіпсовані текстури, наступний кадр створить їх заново
        if ChunkManager.invalidateAll then
            ChunkManager.invalidateAll()
        end
    end
end

function ChunkManager.init(parentGroupBase, parentGroupTop, grid, customConfig)
    groupBaseRef, groupTopRef, gridRef, configRef = parentGroupBase, parentGroupTop, grid, customConfig or WorldConfig
    activeChunks, processingQueue, generatingChunks, ChunkManager.requiredChunks = {}, {}, {}, {}
    
    Runtime:addEventListener("enterFrame", ChunkManager.processQueue)
    Runtime:addEventListener("system", onSystemEvent) -- Підписуємось на згортання/розгортання
end

local function destroyChunk(chunkId)
    local chunk = activeChunks[chunkId]
    if not chunk then return end
    
    if chunk.groundImg then chunk.groundImg:removeSelf() end
    if chunk.topImg then chunk.topImg:removeSelf() end
    if chunk.groundTex then chunk.groundTex:releaseSelf() end
    if chunk.topTex then chunk.topTex:releaseSelf() end
    
    activeChunks[chunkId] = nil
end

function ChunkManager.processQueue(event)
    if #processingQueue == 0 then return end
    
    local timeBudget = 8 
    local startFrame = system.getTimer()
    
    while (#processingQueue > 0 and (system.getTimer() - startFrame < timeBudget)) do
        local task = processingQueue[1]
        local shouldCancel = not ChunkManager.requiredChunks[task.id]
        
        if coroutine.status(task.co) == "dead" then
            table.remove(processingQueue, 1)
        else
            if shouldCancel then
                if task.started then coroutine.resume(task.co, "cancel") end
                generatingChunks[task.id] = nil
                table.remove(processingQueue, 1)
            else
                task.started = true 
                local success, data = coroutine.resume(task.co)
                
                if not success then
                    Logger.error("ChunkManager", "Coroutine crash: " .. tostring(data))
                    generatingChunks[task.id] = nil
                    table.remove(processingQueue, 1)
                elseif coroutine.status(task.co) == "dead" then
                    if data and not data.isEmpty and not data.isCancelled then
                        if activeChunks[task.id] then destroyChunk(task.id) end
                        
                        if data.groundImg then groupBaseRef:insert(data.groundImg) end
                        if data.topImg then groupTopRef:insert(data.topImg) end
                        
                        activeChunks[task.id] = data
                    end
                    generatingChunks[task.id] = nil
                    table.remove(processingQueue, 1)
                end
            end
        end
    end
end

function ChunkManager.update(cameraGroup)
    if not gridRef or not cameraGroup then return end
    
    local screenX1, screenY1 = display.screenOriginX, display.screenOriginY
    local screenX2, screenY2 = display.screenOriginX + display.actualContentWidth, display.screenOriginY + display.actualContentHeight
    
    local minVisibleX, minVisibleY = cameraGroup:contentToLocal(screenX1, screenY1)
    local maxVisibleX, maxVisibleY = cameraGroup:contentToLocal(screenX2, screenY2)
    
    local worldCenterX = (minVisibleX + maxVisibleX) / 2
    local worldCenterY = (minVisibleY + maxVisibleY) / 2
    
    local mapOffsetX = math.floor(-(configRef.MAP_WIDTH * CELL_SIZE / 2) + (CELL_SIZE / 2))
    local mapOffsetY = math.floor(-(configRef.MAP_HEIGHT * CELL_SIZE / 2) + (CELL_SIZE / 2))
    
    local minChunkX = math.floor((minVisibleX - mapOffsetX) / CHUNK_PIXEL_SIZE) + 1
    local maxChunkX = math.floor((maxVisibleX - mapOffsetX) / CHUNK_PIXEL_SIZE) + 1
    local minChunkY = math.floor((minVisibleY - mapOffsetY) / CHUNK_PIXEL_SIZE) + 1
    local maxChunkY = math.floor((maxVisibleY - mapOffsetY) / CHUNK_PIXEL_SIZE) + 1
    
    local centerChunkX = math.floor((worldCenterX - mapOffsetX) / CHUNK_PIXEL_SIZE) + 1
    local centerChunkY = math.floor((worldCenterY - mapOffsetY) / CHUNK_PIXEL_SIZE) + 1
    
    local maxMapChunkX, maxMapChunkY = math.ceil(configRef.MAP_WIDTH / CHUNK_SIZE), math.ceil(configRef.MAP_HEIGHT / CHUNK_SIZE)
    
    for k in pairs(ChunkManager.requiredChunks) do ChunkManager.requiredChunks[k] = nil end
    
    local addedNew = false
    for cy = minChunkY - 1, maxChunkY + 1 do
        for cx = minChunkX - 1, maxChunkX + 1 do
            if cx >= 1 and cx <= maxMapChunkX and cy >= 1 and cy <= maxMapChunkY then
                local chunkId = cx .. "_" .. cy
                ChunkManager.requiredChunks[chunkId] = true
                
                local targetLOD = "high"
                local existingChunk = activeChunks[chunkId]
                local isGenerating = generatingChunks[chunkId]
                
                if not isGenerating then
                    if not existingChunk or (existingChunk.lod == "low" and targetLOD == "high") then
                        generatingChunks[chunkId] = targetLOD
                        local co = MapRenderer.buildChunkCoroutine(cx, cy, gridRef, groupBaseRef, groupTopRef, configRef, targetLOD)
                        local dist = math.abs(cx - centerChunkX) + math.abs(cy - centerChunkY)
                        table.insert(processingQueue, { id = chunkId, co = co, lod = targetLOD, started = false, dist = dist })
                        addedNew = true
                    end
                end
            end
        end
    end
    
    if addedNew then
        table.sort(processingQueue, function(a, b) return a.dist < b.dist end)
    end
    
    local chunksDestroyed = false
    for chunkId, chunkData in pairs(activeChunks) do
        if not ChunkManager.requiredChunks[chunkId] then
            destroyChunk(chunkId)
            chunksDestroyed = true
        end
    end
    
    if chunksDestroyed then 
        -- collectgarbage("collect") -- Removed to prevent stuttering during camera movement
    end
end

-- ==========================================
-- ОЧИЩЕННЯ ПАМ'ЯТІ ТА КЕШУ
-- ==========================================

-- Внутрішня функція: очищує всі чанки без зупинки роботи менеджера
function ChunkManager.invalidateAll()
    for chunkId, _ in pairs(activeChunks) do 
        destroyChunk(chunkId) 
    end
    
    for i = 1, #processingQueue do
        local task = processingQueue[i]
        if task.started and coroutine.status(task.co) ~= "dead" then
            coroutine.resume(task.co, "cancel")
        end
    end
    
    activeChunks = {}
    processingQueue = {}
    generatingChunks = {}
    ChunkManager.requiredChunks = {}
    collectgarbage("collect")
end

-- Повне вимкнення (для виходу з GameScene)
function ChunkManager.destroyAll()
    Runtime:removeEventListener("enterFrame", ChunkManager.processQueue)
    Runtime:removeEventListener("system", onSystemEvent) -- Відписуємось від подій
    
    ChunkManager.invalidateAll()
end

return ChunkManager