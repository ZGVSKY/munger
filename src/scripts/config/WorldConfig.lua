-- src/scripts/config/WorldConfig.lua
local WorldConfig = {
    
    -- 1. БАЗОВІ НАЛАШТУВАННЯ СВІТУ
    MAP_WIDTH = 300,
    MAP_HEIGHT = 300,
    CELL_SIZE = 64,
    SEED = os.time(), -- Можна замінити на фіксоване число для тестів

    -- 2. ГЕНЕРАЦІЯ РЕЛЬЄФУ (ШУМ)
    GEN = {
        scale = 60,              -- Масштаб базового шуму (більше число - більші материки)
        octaves = 2,             -- Деталізація (рваність країв)
        persistence = 0.5,
        mountainScaleMult = 2,   -- У скільки разів гори генеруються "частіше" за звичайний рельєф
        moistureOffset = 1000,   -- Зсув для шуму вологості
        moistureScaleMult = 0.8, -- Масштаб шуму вологості
    },

    -- 3. МАКРО-ГЕОГРАФІЯ
    GEO = {
        enableOcean = true,
        landPercent = 80,        -- Радіус острова (у відсотках від розміру карти)
        seaLevel = 0.20,         -- Рівень океану
        
        enableRivers = true,
        riverCount = 58,         -- Кількість спроб генерації річок
        riverStartHeight = 0.6,  -- Мінімальна висота гір, звідки може починатись джерело
    },

    -- 4. ПОСТ-ОБРОБКА ТА ЗГЛАДЖУВАННЯ
    POST_PROCESS = {
        smoothColorsRadius = 1,  -- Радіус розмиття кольорів (1 = 3x3 тайли)
        
        -- Розміри масивів (Алгоритм ерозії)
        forestMinSize = 6,
        forestMaxSize = 40,
        obstacleMinSize = 9,
        obstacleMaxSize = 60,
        
        -- Спеціальні висоти для перетворень
        coastHeight = 0.27,      -- Висота, на якій генерується пісок біля води
        valleyHeight = 0.31,     -- Висота землі навколо річки (щоб зрізати гори)
        valleyMoisture = 0.16,
    },

    -- 5. НАЛАШТУВАННЯ ВІЗУАЛУ ТА РЕНДЕРУ (MapRenderer)
    RENDER = {
        -- Перемикачі етапів рендеру (зручно для дебагу)
        stages = {
            baseTiles = true,
            transitions = true,
            obstacles = true
        },
        
        -- Шанси появи декорацій на клітинку (у відсотках %)
        decorChances = {
            grass = 6,
            coast = 8,
            obstacle = 21
        },
        
        -- Параметри випадковості для дерев
        treeShadeMin = 0.6,
        treeShadeMax = 1.0,
        treeOffset = 8, -- Максимальний зсув стовбура від центру клітинки (в пікселях)
    }
}

return WorldConfig