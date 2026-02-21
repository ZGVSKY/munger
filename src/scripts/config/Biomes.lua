-- src/scripts/config/Biomes.lua
local Biomes = {}

Biomes.SEA_LEVEL = 0.22

Biomes.GAMEPLAY = {
    WATER = "water", COAST = "coast", GROUND = "ground", OBSTACLE = "obstacle", FOREST = 'forest'
}

Biomes.TYPES = {
    -- ВОДА (5 рівнів градієнту для озер/океанів)
    WATER_1 = { id="water_1", gameplay=Biomes.GAMEPLAY.WATER, color={0.3, 0.8, 0.9} }, -- Наймілкіша (біля берега)
    WATER_2 = { id="water_2", gameplay=Biomes.GAMEPLAY.WATER, color={0.2, 0.7, 0.85} }, 
    WATER_3 = { id="water_3", gameplay=Biomes.GAMEPLAY.WATER, color={0.1, 0.5, 0.8} },  -- Середня
    WATER_4 = { id="water_4", gameplay=Biomes.GAMEPLAY.WATER, color={0.05, 0.35, 0.7} }, 
    WATER_5 = { id="water_5", gameplay=Biomes.GAMEPLAY.WATER, color={0.0, 0.2, 0.5} },  -- Найглибша (центр)
       
    -- БЕРЕГ
    BEACH      = { id="beach",      gameplay=Biomes.GAMEPLAY.COAST, color={0.95, 0.85, 0.6} }, -- Пісок
    
    -- ЗЕМЛЯ (Рівнини)
    SCORCHED           = { id="scorched",   gameplay=Biomes.GAMEPLAY.GROUND, color={45/255, 162/255, 6/255} }, --rgb(45, 162, 6)
    SUBTROPICAL_DESERT = { id="sub_desert", gameplay=Biomes.GAMEPLAY.GROUND, color={45/255, 162/255, 6/255} },
    GRASSLAND          = { id="grassland",  gameplay=Biomes.GAMEPLAY.GROUND, color={26/255, 212/255, 70/255} }, --rgb(26, 212, 70)
    TROPICAL_RAIN_FOREST={ id="trop_forest",gameplay=Biomes.GAMEPLAY.FOREST, color={22/255, 174/255, 58/255} }, -- rgb(22, 174, 58)
    
    -- ВИСОЧИНИ
    TEMPERATE_DESERT   = { id="temp_desert", gameplay=Biomes.GAMEPLAY.GROUND, color={19/255, 161/255, 53/255} }, -- rgb(19, 161, 53)
    SHRUBLAND          = { id="shrubland",   gameplay=Biomes.GAMEPLAY.GROUND, color={0.5, 0.6, 0.4} },
    TEMP_DECIDUOUS_FOREST={ id="temp_forest",gameplay=Biomes.GAMEPLAY.GROUND, color={0.2, 0.55, 0.2} },
    TAIGA              = { id="taiga",      gameplay=Biomes.GAMEPLAY.GROUND, color={0.2, 0.4, 0.35} },

    -- ГОРИ
    BARE               = { id="bare",       gameplay=Biomes.GAMEPLAY.OBSTACLE, color={0.5, 0.5, 0.5} },
    TUNDRA             = { id="tundra",     gameplay=Biomes.GAMEPLAY.OBSTACLE,   color={0.7, 0.7, 0.65} },
    SNOW               = { id="snow",       gameplay=Biomes.GAMEPLAY.OBSTACLE, color={0.95, 0.95, 1.0} },
}


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

    -- ЛОГІКА ОКЕАНУ
    if e < Biomes.SEA_LEVEL then
        -- Можемо використати ті ж кольори води, але базуючись на висоті (від 0 до 0.22)
        if e < 0.05 then return Biomes.TYPES.WATER_5 end
        if e < 0.10 then return Biomes.TYPES.WATER_4 end
        if e < 0.15 then return Biomes.TYPES.WATER_3 end
        if e < 0.19 then return Biomes.TYPES.WATER_2 end
        return Biomes.TYPES.WATER_1
    end

    -- 2. ПЛЯЖ (Розширили зону до 0.28, щоб точно було видно)
    if e < 0.28 then return Biomes.TYPES.BEACH end

    -- 3. ГОРИ (> 0.88)
    if e > 0.88 then
        if m < 0.1 then return Biomes.TYPES.SCORCHED end
        if m < 0.3 then return Biomes.TYPES.BARE end
        return Biomes.TYPES.SNOW
    end

    -- 4. СКЕЛІ (0.75 - 0.88)
    if e > 0.75 then
        if m < 0.33 then return Biomes.TYPES.TEMPERATE_DESERT end
        if m < 0.66 then return Biomes.TYPES.SHRUBLAND end
        return Biomes.TYPES.TUNDRA
    end

    -- 5. ПАГОРБИ (0.55 - 0.75)
    if e > 0.55 then
        if m < 0.16 then return Biomes.TYPES.TEMPERATE_DESERT end
        if m < 0.50 then return Biomes.TYPES.SHRUBLAND end
        if m < 0.83 then return Biomes.TYPES.TEMP_DECIDUOUS_FOREST end
        return Biomes.TYPES.TAIGA
    end

    -- 6. РІВНИНИ (0.27 - 0.55)
    if m < 0.16 then return Biomes.TYPES.SUBTROPICAL_DESERT end
    if m < 0.33 then return Biomes.TYPES.GRASSLAND end
    if m < 0.66 then return Biomes.TYPES.TEMP_DECIDUOUS_FOREST end
    return Biomes.TYPES.TROPICAL_RAIN_FOREST
end

return Biomes