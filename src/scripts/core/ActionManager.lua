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

    -- ЛОГІКА БУДІВНИЦТВА (Ферми, Шахти, Вежі)
    if ActionManager.mode == "build_resource" or ActionManager.mode == "build_defense" then
        -- Віднімаємо золото (тимчасова логіка для тесту)
        if player.resources.gold < ActionManager.currentData.cost then
            ToastManager.show("Not enough gold!", {0.8, 0.2, 0.2})
            ActionManager.setMode("idle")
            return true
        end
        player:addResource("gold", -ActionManager.currentData.cost)

        -- Записуємо дані в клітинку
        cell.buildingId = ActionManager.currentData.id
        cell.ownerId = player.id -- Привласнюємо клітинку

        ToastManager.show(ActionManager.currentData.name .. " Built!", player.color)
        
        -- Оновлюємо UI (щоб показати зняття грошей)
        ui:update()
        ActionManager.setMode("idle")
        return true
    end

    -- ЛОГІКА НАЙМУ ЮНІТІВ (Воїни)
    if ActionManager.mode == "spawn_unit" then
        cell.unitId = ActionManager.currentData.id
        cell.ownerId = player.id
        
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