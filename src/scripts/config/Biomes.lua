-- src/scripts/config/Biomes.lua
local Biomes = {}


Biomes.GAMEPLAY = {
    WATER = "water",       -- Кораблі плавають
    GROUND = "ground",     -- Юніти ходять
    OBSTACLE = "obstacle", -- Гори, стіни (не можна ходити)
    COAST = "coast"        -- Можна будувати порти?
}

-- Визначення типів біомів
-- color: колір для дебагу {R, G, B}
Biomes.TYPES = {
    -- ВОДА
    DEEP_OCEAN = { id="deep_ocean", gameplay=Biomes.GAMEPLAY.WATER, color={0.1, 0.1, 0.4} },
    OCEAN      = { id="ocean",      gameplay=Biomes.GAMEPLAY.WATER, color={0.2, 0.2, 0.6} },
    
    -- БЕРЕГ
    BEACH      = { id="beach",      gameplay=Biomes.GAMEPLAY.GROUND, color={0.9, 0.85, 0.6} }, -- Пісочний колір
    
    -- ЗЕМЛЯ (Різні відтінки трави)
    SCORCHED   = { id="scorched",   gameplay=Biomes.GAMEPLAY.GROUND, color={0.5, 0.3, 0.2} }, -- Темно-коричневий
    BARE       = { id="bare",       gameplay=Biomes.GAMEPLAY.GROUND, color={0.6, 0.6, 0.6} }, -- Сірий
    TUNDRA     = { id="tundra",     gameplay=Biomes.GAMEPLAY.GROUND, color={0.7, 0.7, 0.6} }, -- Блідий
    SNOW       = { id="snow",       gameplay=Biomes.GAMEPLAY.GROUND, color={0.95, 0.95, 1.0} }, -- Майже білий
    
    TEMPERATE_DESERT = { id="temp_desert", gameplay=Biomes.GAMEPLAY.GROUND, color={0.8, 0.8, 0.5} },
    SHRUBLAND        = { id="shrubland",   gameplay=Biomes.GAMEPLAY.GROUND, color={0.5, 0.6, 0.4} },
    GRASSLAND        = { id="grassland",   gameplay=Biomes.GAMEPLAY.GROUND, color={0.4, 0.7, 0.4} }, -- Соковита зелень
    
    TEMPERATE_DECIDUOUS_FOREST = { id="temp_forest", gameplay=Biomes.GAMEPLAY.GROUND, color={0.3, 0.6, 0.3} },
    TEMPERATE_RAIN_FOREST      = { id="rain_forest", gameplay=Biomes.GAMEPLAY.GROUND, color={0.2, 0.5, 0.2} },
    
    SUBTROPICAL_DESERT = { id="sub_desert", gameplay=Biomes.GAMEPLAY.GROUND, color={0.85, 0.7, 0.5} },
    TROPICAL_RAIN_FOREST = { id="trop_forest", gameplay=Biomes.GAMEPLAY.GROUND, color={0.1, 0.4, 0.1} }, -- Темно-зелений
}

-- Функція, яка визначає біом на основі Висоти (Elevation) та Вологості (Moisture)
-- e: Elevation (0..1), m: Moisture (0..1)
function Biomes.getBiome(e, m)
    -- 1. ВОДА
    if e < 0.25 then return Biomes.TYPES.DEEP_OCEAN end
    if e < 0.35 then return Biomes.TYPES.OCEAN end
    if e < 0.38 then return Biomes.TYPES.BEACH end

    -- 2. ВИСОКІ ГОРИ (Висота > 0.8)
    if e > 0.8 then
        if m < 0.1 then return Biomes.TYPES.SCORCHED end
        if m < 0.2 then return Biomes.TYPES.BARE end
        if m < 0.5 then return Biomes.TYPES.TUNDRA end
        return Biomes.TYPES.SNOW
    end

    -- 3. СЕРЕДНЯ ВИСОТА / ПАГОРБИ (0.6 - 0.8)
    if e > 0.6 then
        if m < 0.33 then return Biomes.TYPES.TEMPERATE_DESERT end
        if m < 0.66 then return Biomes.TYPES.SHRUBLAND end
        return Biomes.TYPES.TUNDRA
    end

    -- 4. РІВНИНИ (0.38 - 0.6)
    if e > 0.38 then
        if m < 0.16 then return Biomes.TYPES.SUBTROPICAL_DESERT end
        if m < 0.33 then return Biomes.TYPES.GRASSLAND end
        if m < 0.66 then return Biomes.TYPES.TEMPERATE_DECIDUOUS_FOREST end
        return Biomes.TYPES.TROPICAL_RAIN_FOREST
    end

    return Biomes.TYPES.GRASSLAND -- Фолбек
end

return Biomes