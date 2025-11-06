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
    player.caste = nil
    player.buildings = {}
    player.units = {}
    player.camera_position = {x=0,y=0}
    return player

function player_class:manage_resourses(player, gold, wood, stone)
    player.gold  += gold
    player.wood  += wood
    player.stone += stone

return player_class

