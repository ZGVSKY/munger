-------------------------------------------------------
-- world class created at 07.11.25 by zgvsk
-- stores player data, all progress of the current game, also stores the map
-------------------------------------------------------


world = {}

function world:init(picked_players)
    -- initialize game world, game parameters,start game state  
    -- create players, generate map 
    ----------------------------------------------------
    -- import stage

    local player_class = require("src.world.player")
    local castle_class = require("src.buildings.player_castle_class")
    ----------------------------------------------------
    -- the first stage of generation, where arrays of player classes are created, and a castle is added to the players

    world.players = player_class:create_players(picked_players) -- create instances of players
    world.players_count = #world.players -- get players count
    castle_class:put_castle_to_players(world.players) -- generate castles and add it into players
    
    print("--------->{INFO}:Players generation done") --log
    -- print("checking for variable availability: ",world.players[1].color, world.players[1].castle.level)
    ----------------------------------------------------

    -- world.map = map
end

return world