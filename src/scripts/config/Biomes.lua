-- src/scripts/config/Biomes.lua
local Biomes = {}

Biomes.SEA_LEVEL = 0.22

Biomes.GAMEPLAY = {
    WATER = "water", 
    COAST = "coast", 
    GROUND = "ground",            
    FOREST = "forest",            
    OBSTACLE = "obstacle",        
    HIGH_OBSTACLE = "high_obstacle" 
}

Biomes.TYPES = {
    -- ВОДА
    WATER_1 = { id="water_1", gameplay=Biomes.GAMEPLAY.WATER, color={0.3, 0.8, 0.9} },
    WATER_2 = { id="water_2", gameplay=Biomes.GAMEPLAY.WATER, color={0.2, 0.7, 0.85} }, 
    WATER_3 = { id="water_3", gameplay=Biomes.GAMEPLAY.WATER, color={0.1, 0.5, 0.8} },  
    WATER_4 = { id="water_4", gameplay=Biomes.GAMEPLAY.WATER, color={0.05, 0.35, 0.7} }, 
    WATER_5 = { id="water_5", gameplay=Biomes.GAMEPLAY.WATER, color={0.0, 0.2, 0.5} },  
        
    -- БЕРЕГ
    BEACH   = { id="beach",   gameplay=Biomes.GAMEPLAY.COAST, color={0.92, 0.85, 0.65} }, 
    
    -- ЗЕМЛЯ ТА РІВНИНИ
    SUBTROPICAL_DESERT = { id="sub_desert", gameplay=Biomes.GAMEPLAY.GROUND, color={0.82, 0.78, 0.53} }, 
    SHRUBLAND          = { id="shrubland",  gameplay=Biomes.GAMEPLAY.GROUND, color={0.61, 0.73, 0.41} }, 
    GRASSLAND          = { id="grassland",  gameplay=Biomes.GAMEPLAY.GROUND, color={0.48, 0.72, 0.33} }, 
    TEMPERATE_DESERT   = { id="temp_desert", gameplay=Biomes.GAMEPLAY.GROUND, color={0.55, 0.68, 0.42} }, 
    
    -- ЛІСИ (gameplay = FOREST для правильного спавну дерев)
    TEMP_DECIDUOUS_FOREST = { id="temp_forest", gameplay=Biomes.GAMEPLAY.FOREST, color={0.27, 0.55, 0.24} }, 
    TROPICAL_RAIN_FOREST  = { id="trop_forest", gameplay=Biomes.GAMEPLAY.FOREST, color={0.17, 0.43, 0.20} }, 
    TAIGA                 = { id="taiga",       gameplay=Biomes.GAMEPLAY.FOREST, color={0.22, 0.42, 0.35} }, 

    -- ГОРИ
    -- ВАЖЛИВО: Всі вони мають OBSTACLE!  WorldGenerator сам перетворить центри на HIGH_OBSTACLE
    SCORCHED = { id="scorched", gameplay=Biomes.GAMEPLAY.OBSTACLE, color={0.40, 0.35, 0.32} }, 
    BARE     = { id="bare",     gameplay=Biomes.GAMEPLAY.OBSTACLE, color={0.60, 0.57, 0.55} }, 
    TUNDRA   = { id="tundra",   gameplay=Biomes.GAMEPLAY.OBSTACLE, color={0.70, 0.75, 0.72} }, 
    SNOW     = { id="snow",     gameplay=Biomes.GAMEPLAY.OBSTACLE, color={0.95, 0.98, 1.0} }, 
}

-- Повертаємо пряме посилання на таблиці, щоб == працювало коректно
function Biomes.getBiome(e, m, isLake, depth)
    e = e or 0
    m = m or 0
    depth = depth or 0

    if isLake then
        if depth <= 1 then return Biomes.TYPES.WATER_1 end
        if depth <= 2 then return Biomes.TYPES.WATER_2 end
        if depth <= 4 then return Biomes.TYPES.WATER_3 end
        if depth <= 6 then return Biomes.TYPES.WATER_4 end
        return Biomes.TYPES.WATER_5
    end

    if e < Biomes.SEA_LEVEL then
        if e < 0.05 then return Biomes.TYPES.WATER_5 end
        if e < 0.10 then return Biomes.TYPES.WATER_4 end
        if e < 0.15 then return Biomes.TYPES.WATER_3 end
        if e < 0.19 then return Biomes.TYPES.WATER_2 end
        return Biomes.TYPES.WATER_1
    end

    if e < 0.26 then return Biomes.TYPES.BEACH end

    -- Високі гори та піки
    if e > 0.85 then
        if m < 0.3 then return Biomes.TYPES.SCORCHED end
        if m < 0.6 then return Biomes.TYPES.BARE end
        return Biomes.TYPES.SNOW 
    end

    -- Низькі гори та передгір'я
    if e > 0.70 then
        if m < 0.33 then return Biomes.TYPES.SCORCHED end
        if m < 0.66 then return Biomes.TYPES.BARE end
        return Biomes.TYPES.TUNDRA
    end

    -- Пагорби та холодні зони
    if e > 0.55 then
        if m < 0.16 then return Biomes.TYPES.TEMPERATE_DESERT end
        if m < 0.50 then return Biomes.TYPES.SHRUBLAND end
        if m < 0.83 then return Biomes.TYPES.TEMP_DECIDUOUS_FOREST end
        return Biomes.TYPES.TAIGA 
    end

    -- Рівнини / Низовини
    if m < 0.16 then return Biomes.TYPES.SUBTROPICAL_DESERT end
    if m < 0.33 then return Biomes.TYPES.GRASSLAND end
    if m < 0.66 then return Biomes.TYPES.TEMP_DECIDUOUS_FOREST end
    return Biomes.TYPES.TROPICAL_RAIN_FOREST 
end

return Biomes