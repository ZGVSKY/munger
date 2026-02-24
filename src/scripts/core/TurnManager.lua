-- src/scripts/core/TurnManager.lua
local Logger = require("src.scripts.utils.logger")

local TurnManager = {}

--- Передає хід наступному гравцю
function TurnManager.nextTurn(gameState)
    -- Збільшуємо індекс гравця
    gameState.currentPlayerIndex = gameState.currentPlayerIndex + 1
    
    -- Якщо всі гравці походили, починаємо новий глобальний хід
    if gameState.currentPlayerIndex > #gameState.players then
        gameState.currentPlayerIndex = 1
        gameState.currentTurn = gameState.currentTurn + 1
        Logger.info("Turn", "--- GLOBAL TURN " .. gameState.currentTurn .. " STARTED ---")
    end
    
    local currentPlayer = gameState:getCurrentPlayer()
    Logger.info("Turn", "Player " .. currentPlayer.id .. " (" .. currentPlayer.name .. ") is now active.")
    
    -- Відновлюємо очки ходу для всіх юнітів цього гравця
    for _, unit in ipairs(currentPlayer.units) do
        unit:resetMoves()
    end
    
    -- Тут в майбутньому ми будемо викликати EconomySystem для нарахування ресурсів
end

return TurnManager