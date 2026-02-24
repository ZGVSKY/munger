-- src/scripts/core/ActionManager.lua
local Logger = require("src.scripts.utils.logger")

local ActionManager = {}

--- Головна функція виконання будь-якої дії
-- @param gameState - поточний стан гри
-- @param action - таблиця з командою, наприклад { type = "MOVE", playerId = 1, unitId = 5, x = 10, y = 12 }
function ActionManager.execute(gameState, action)
    local activePlayer = gameState:getCurrentPlayer()
    
    -- 1. Базова перевірка: чи зараз взагалі хід цього гравця?
    if action.playerId ~= activePlayer.id then
        Logger.error("Action", "Player " .. action.playerId .. " tried to act, but it's Player " .. activePlayer.id .. "'s turn!")
        return false
    end
    
    Logger.info("Action", "Executing [" .. action.type .. "] for Player " .. action.playerId)
    
    -- 2. Розподіл по типах команд (поки залишаємо пустим для майбутнього)
    if action.type == "MOVE" then
        -- логіка руху
    elseif action.type == "BUILD" then
        -- логіка будівництва
    elseif action.type == "ATTACK" then
        -- логіка бою
    else
        Logger.error("Action", "Unknown action type: " .. tostring(action.type))
        return false
    end
    
    return true
end

return ActionManager