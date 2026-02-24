-- src/scripts/core/GameState.lua
local GameState = {}
GameState.__index = GameState

--- Ініціалізація нової гри
-- @param world (World) Об'єкт нашої карти
-- @param players (table) Масив об'єктів Player
function GameState.new(world, players)
    local self = setmetatable({}, GameState)
    
    self.world = world
    self.players = players
    
    -- Управління ходами
    self.currentTurn = 1
    self.currentPlayerIndex = 1
    
    return self
end

--- Повертає гравця, чий зараз хід
function GameState:getCurrentPlayer()
    return self.players[self.currentPlayerIndex]
end

--- Повертає гравця за його ID
function GameState:getPlayerById(id)
    for _, player in ipairs(self.players) do
        if player.id == id then
            return player
        end
    end
    return nil
end

return GameState