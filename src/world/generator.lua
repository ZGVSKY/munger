generator = {}

function generator:init()
    -- function to initialize the default generator parameters, all variables
    -- create an empty map object
    ---------------------------------------------------
    -- import stage

    local cell_class = require("src.world.cell")
    local simplex = require("src.utils.ModernPerlin")
    ---------------------------------------------------
    -- setup map parameters

    local map = {}
    map.size_x = 10
    map.size_y = 10
    map.cell_size = 15

    local scale = 1
    map.grid = {}
    -- generate map seed 
    map.seed = math.random()*100000
    map.resourses_seed = math.random()*100000
    print("--------->{GENERATOR-INFO}: all parameters set, generated world seed : ".. map.seed)
    ---------------------------------------------------
    -- generate empty map grid , and pirlin noise for cells

    for index_x = 1, map.size_x do
        local colm = {}
        for index_y = 1, map.size_y do
            -- create a cell with noise
            -- use fractal sum of 2 perlin 2d noises
            -- for cell position, the formula (position+seed)/scale is applied
            table.insert(colm, cell_class:create(simplex.FractalSum(simplex.Noise2D, 2, (index_x+map.seed)/scale, (index_y+map.seed)/scale)))
        end
        table.insert(map.grid, colm)
    end
    print("--------->{GENERATOR-INFO}: empty map grid created ")

    return map
end

return generator
