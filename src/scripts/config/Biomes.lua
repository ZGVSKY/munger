-- src/scripts/config/Biomes.lua
local Biomes = {}

Biomes.SEA_LEVEL = 0.22

Biomes.GAMEPLAY = {
    WATER = "water", COAST = "coast", GROUND = "ground", OBSTACLE = "obstacle"
}

Biomes.TYPES = {
    -- ВОДА
    DEEP_OCEAN = { id="deep_ocean", gameplay=Biomes.GAMEPLAY.WATER, color={0.05, 0.05, 0.3} }, -- Темна безодня
    MID_OCEAN = { id="deep_ocean", gameplay=Biomes.GAMEPLAY.WATER, color={0.1, 0.2, 0.6} }, -- Темна безодня
    OCEAN      = { id="ocean",      gameplay=Biomes.GAMEPLAY.WATER, color={0.1, 0.3, 0.8} },   -- Синій океан
    -- ОЗЕРА (Градієнт)
    LAKE_SHALLOW = { id="lake_shallow", color={1} }, -- Світло-блакитний (біля берега)
    LAKE_MID     = { id="lake_mid",     color={1} }, -- Середній
    LAKE_DEEP    = { id="lake_deep",    color={1} }, -- Темний (центр)
    
    -- БЕРЕГ
    BEACH      = { id="beach",      gameplay=Biomes.GAMEPLAY.COAST, color={0.95, 0.85, 0.6} }, -- Пісок
    
    -- ЗЕМЛЯ (Рівнини)
    SCORCHED           = { id="scorched",   gameplay=Biomes.GAMEPLAY.GROUND, color={0.5, 0.3, 0.2} },
    SUBTROPICAL_DESERT = { id="sub_desert", gameplay=Biomes.GAMEPLAY.GROUND, color={0.85, 0.8, 0.5} },
    GRASSLAND          = { id="grassland",  gameplay=Biomes.GAMEPLAY.GROUND, color={0.4, 0.7, 0.3} },
    TROPICAL_RAIN_FOREST={ id="trop_forest",gameplay=Biomes.GAMEPLAY.GROUND, color={0.05, 0.4, 0.1} },
    
    -- ВИСОЧИНИ
    TEMPERATE_DESERT   = { id="temp_desert", gameplay=Biomes.GAMEPLAY.GROUND, color={0.8, 0.85, 0.6} },
    SHRUBLAND          = { id="shrubland",   gameplay=Biomes.GAMEPLAY.GROUND, color={0.5, 0.6, 0.4} },
    TEMP_DECIDUOUS_FOREST={ id="temp_forest",gameplay=Biomes.GAMEPLAY.GROUND, color={0.2, 0.55, 0.2} },
    TAIGA              = { id="taiga",      gameplay=Biomes.GAMEPLAY.GROUND, color={0.2, 0.4, 0.35} },

    -- ГОРИ
    BARE               = { id="bare",       gameplay=Biomes.GAMEPLAY.OBSTACLE, color={0.5, 0.5, 0.5} },
    TUNDRA             = { id="tundra",     gameplay=Biomes.GAMEPLAY.GROUND,   color={0.7, 0.7, 0.65} },
    SNOW               = { id="snow",       gameplay=Biomes.GAMEPLAY.OBSTACLE, color={0.95, 0.95, 1.0} },
}


function Biomes.getBiome(e, m, isLake, depth)
    e = e or 0
    m = m or 0
    depth = depth or 0

    

     
    if e < Biomes.SEA_LEVEL  then
        if e < 0.002 then return Biomes.TYPES.DEEP_OCEAN end
        if e < 0.1 then return Biomes.TYPES.MID_OCEAN end
        return Biomes.TYPES.OCEAN
    end

    -- ЛОГІКА ОЗЕР
    if isLake then
        if depth <= 2 then return Biomes.TYPES.LAKE_SHALLOW end
        if depth <= 5 then return Biomes.TYPES.LAKE_MID end
        return Biomes.TYPES.LAKE_DEEP
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