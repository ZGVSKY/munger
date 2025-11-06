-------------------------------------------------------
-- world class created at 07.11.25 by zgvsk
-- stores player data, all progress of the current game, also stores the map
-------------------------------------------------------


world = {}
world.map = {}

world.players = nil
world.players_count = nil
world.level = nil

function world:init(players, map)
    world.map = map

    world.players = players
    world.players_count = #players
    world.level = level

return world