-- src/scripts/core/ActionManager.lua
local ToastManager = require("src.scripts.view.ToastManager")
local Logger = require("src.scripts.utils.logger")


local ActionManager = {}

-- Поточний стан (режим)
ActionManager.mode = "idle" -- "idle", "build_resource", "build_defense", "spawn_unit"
ActionManager.currentData = nil

-- Допоміжна функція: перевірка типу тайлу
local function getGameplayType(cell)
    if not cell or not cell.biome then return "water" end
    return cell.biome.gameplay or "water"
end

-- Функція захоплення території (Радіус навколо центру)
local function claimInitialTerritory(world, cx, cy, radius, playerId)
    -- Додаємо 0.5 до радіуса, щоб краї кола на квадратній сітці виглядали акуратніше
    local radiusSq = (radius + 0.5) * (radius + 0.5) 
    
    for y = cy - radius, cy + radius do
        for x = cx - radius, cx + radius do
            if x >= 1 and x <= world.width and y >= 1 and y <= world.height then
                -- Формула кола: (x - cx)^2 + (y - cy)^2 <= R^2
                local distSq = (x - cx)^2 + (y - cy)^2
                if distSq <= radiusSq then
                    local cell = world:getTile(x, y)
                    if cell.biome and cell.biome.gameplay ~= "water" then
                        cell.ownerId = playerId
                    end
                end
            end
        end
    end
end

-- Перевірка сусідніх біомів (радіус 1 клітинка навколо)
local function hasNeighborBiome(world, cx, cy, targetType)
    local neighbors = { {0,-1}, {0,1}, {-1,0}, {1,0}, {-1,-1}, {1,-1}, {-1,1}, {1,1} }
    
    for _, n in ipairs(neighbors) do
        local nx, ny = cx + n[1], cy + n[2]
        if nx >= 1 and nx <= world.width and ny >= 1 and ny <= world.height then
            local nCell = world:getTile(nx, ny)
            
            -- Перевіряємо тип біому
            if nCell.biome and nCell.biome.gameplay == targetType then
                return true
            end
            
            -- Специфічна перевірка для гір (бо ми маркували їхні частини)
            if targetType == "obstacle" and nCell.buildingId == "obstacle_part" then
                return true
            end
        end
    end
    return false
end


--- Активує режим певної дії (викликається кнопками UI)
function ActionManager.setMode(mode, data)
    ActionManager.mode = mode
    ActionManager.currentData = data
    
    if mode ~= "idle" then
        ToastManager.show("Select tile to place " .. data.name, {0.8, 0.8, 0.2})
        Logger.info("ActionManager", "Mode set to: " .. mode .. " | " .. data.name)
    else
        Logger.info("ActionManager", "Mode reset to idle")
    end
end

--- Обробляє клік по карті залежно від поточного режиму
function ActionManager.handleMapClick(gridX, gridY, gameState, ui)
    -- Якщо ми просто оглядаємо карту, нічого не робимо
    if ActionManager.mode == "idle" then return false end

    local player = gameState:getCurrentPlayer()
    local cell = gameState.world:getTile(gridX, gridY)

    -- БАЗОВІ ПЕРЕВІРКИ (поки без перевірки на свою територію, зробимо це наступним кроком)
    if cell.buildingId or cell.unitId then
        ToastManager.show("Tile is already occupied!", {0.8, 0.2, 0.2})
        ActionManager.setMode("idle") -- Скидаємо дію
        return true -- Клік оброблено, але з помилкою
    end

    if getGameplayType(cell) == "water" or getGameplayType(cell) == "obstacle" then
        ToastManager.show("Cannot place here!", {0.8, 0.2, 0.2})
        ActionManager.setMode("idle")
        return true
    end

    -- ==========================================
    -- ЗАБОРОНА БУДІВНИЦТВА НА ЧУЖІЙ ЗЕМЛІ
    -- ==========================================
    if cell.ownerId ~= player.id then
        ToastManager.show("You must build on your territory!", {0.9, 0.2, 0.2})
        ActionManager.setMode("idle")
        return true
    end

    if ActionManager.mode == "build_resource" or ActionManager.mode == "build_defense" then
        
        -- 1. Специфічні перевірки біомів
        if ActionManager.currentData.id:find("mine") then
            if not hasNeighborBiome(gameState.world, gridX, gridY, "obstacle") then
                ToastManager.show("Must be built near a mountain!", {0.9, 0.2, 0.2})
                ActionManager.setMode("idle")
                return true
            end
        elseif ActionManager.currentData.id:find("sawmill") then
            if not hasNeighborBiome(gameState.world, gridX, gridY, "forest") then
                ToastManager.show("Must be built near a forest!", {0.9, 0.2, 0.2})
                ActionManager.setMode("idle")
                return true
            end
        else
            -- 2. ТУТ БУДЕ ЛОГІКА "ЗОНИ ДОЗВОЛЕНОГО БУДІВНИЦТВА" (Залишаємо місце на майбутнє)
            -- if not isInsideBuildingZone(gridX, gridY) then ...
        end

        -- 3. Фінансові перевірки (Використовуємо функцію гравця!)
        if not player:payCost(ActionManager.currentData.cost) then
            ToastManager.show("Not enough resources!", {0.8, 0.2, 0.2})
            ActionManager.setMode("idle")
            return true
        end
        -- player:addResource ми прибрали, бо payCost вже все відняв!
        
        cell.buildingId = ActionManager.currentData.id
        table.insert(player.buildings, { id = ActionManager.currentData.id, x = gridX, y = gridY })
        player:calculateDeltas()
    end

    -- ЛОГІКА НАЙМУ ЮНІТІВ (Воїни)
    if ActionManager.mode == "spawn_unit" then
        -- ТУТ ТЕЖ ДОДАЄМО ПЕРЕВІРКУ НА РЕСУРСИ!
        if not player:payCost(ActionManager.currentData.cost) then
            ToastManager.show("Not enough resources!", {0.8, 0.2, 0.2})
            ActionManager.setMode("idle")
            return true
        end

        cell.unitId = ActionManager.currentData.id
        cell.ownerId = player.id
        table.insert(player.units, { id = ActionManager.currentData.id, x = gridX, y = gridY })
        player:calculateDeltas()
        
        ToastManager.show(ActionManager.currentData.name .. " Deployed!", player.color)
        ActionManager.setMode("idle")
        return true
    end

    return false
end

-- Допоміжна функція (тимчасова)
function getGameplayType(cell)
    if not cell or not cell.biome then return "water" end
    return cell.biome.gameplay or "water"
end

return ActionManager