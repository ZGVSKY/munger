-- src/scripts/core/MatchInit.lua
local World = require("src.scripts.models.World")
local Player = require("src.scripts.models.Player")
local GameState = require("src.scripts.core.GameState")
local SpawnManager = require("src.scripts.core.SpawnManager")
local Logger = require("src.scripts.utils.logger")

local MatchInit = {}

--- Створює всі ігрові об'єкти перед початком матчу
function MatchInit.setupNewGame(grid, width, height)
    Logger.info("Init", "Setting up new match...")
    
    -- 1. Створюємо Світ
    local world = World.new(grid, width, height)
    
    -- 2. Створюємо Гравців (Player 1 - Людина, Player 2 - Бот)
    local p1 = Player.new(1,"sasha", false, {0.2, 0.4, 1}, "Blue") 
    local p2 = Player.new(2,"bot", true, {1, 0.2, 0.2}, "red")
    local players = {p1, p2}
    
    -- 3. Розставляємо Замки
    SpawnManager.spawnCastles(world, players)
    
    -- 4. Формуємо глобальний стан
    local gameState = GameState.new(world, players)
    
    Logger.info("Init", "Match setup complete!")
    return gameState
end

return MatchInit