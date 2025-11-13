-------------------------------------------------------
-- player class created at 07.11.25 by zgvsk
-------------------------------------------------------

player_class = {}

function player_class:create(color)
    local player = {}
    player.color = color
    player.gold = 0
    player.wood = 0
    player.stone = 0
    player.is_died = false
    player.is_bot = false
    player.caste = nil
    player.buildings = {}
    player.units = {}
    player.camera_position = {x=0,y=0}
    return player
end

function player_class:create_players(picked_players)
    local out = {}
    for i=1,#picked_players do
        out[i]=(player_class:create(picked_players[i]))
        print("--------->{INFO}: create player: "..i)
    end 
    return out
end

function player_class:manage_resourses(player, gold, wood, stone)
    player.gold  = player.gold  + gold
    player.wood  = player.wood  + wood
    player.stone = player.stone + stone
end

return player_class
