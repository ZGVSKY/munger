castle_class = {}

function castle_class:init()
    -- function that initiates player castle, provides basic parameters
    castle = {}

    castle.health = 0
    castle.level  = 1 -- castle level (can be 1,2,3)
    castle.colider = nil -- variable for the collider to make the physics work

    -- the position of the castle on the world map (generated at the last stage of world generation)
    castle.position_x = 0 
    castle.position_y = 0
    

    return castle
end

function castle_class:put_castle_to_players(players)
    -- function to add a castle class inside the player class 
    -- accepts an array of players
    for i=1,#players do
        players[i].castle = castle_class:init()
        print("--------->{INFO}:  create castle for Player: "..i)
    end
end 

return castle_class