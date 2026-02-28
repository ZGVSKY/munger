-- src/scripts/config/RulesConfig.lua
local RulesConfig = {
    
    -- ==========================================
    -- 1. ЕКОНОМІКА ТА РЕСУРСИ
    -- ==========================================
    ECONOMY = {
        foodPerPeasant = 1,          -- Скільки їжі споживає 1 селянин за хід 
        peasantCost = { food = 10 }, -- Вартість створення нового селянина в Домі Селянина
        baseMaxUnits = 4,            -- Базовий ліміт армії (без казарм)
    },

    -- ==========================================
    -- 2. ТОВАРИ (Для заробітку золота)
    -- ==========================================
    GOODS = {
        simple_tools = { 
            productionCost = { wood = 2, stone = 1 }, -- Що потрібно для крафту
            sellPrice = 5                             -- Скільки золота дає при продажі
        }
        -- В майбутньому тут можна додати зброю, одяг тощо
    },

    -- ==========================================
    -- 3. БУДІВЛІ
    -- ==========================================
    BUILDINGS = {
        castle = {
            --cost = { stone = 50, wood = 50 },
            hp = { level1 = 1000, level2 = 1500, level3 = 2000 }
        },
        peasant_house = {
            cost = { wood = 15 },
            hp = 100,
            description = "Дозволяє створювати селян"
        },
        farm = {
            cost = { wood = 20 },
            hp = 100,
            foodProduction = 5 -- Дає їжу 
        },
        mine = {
            cost = { wood = 30 },
            hp = 200,
            production = 3,    -- Дає камінь
            --requires = "obstacle" 
            requires_near = "obstacle"-- Тільки в горах
        },
        lumbermill = {
            cost = { stone = 10 },
            hp = 150,
            production = 3,    -- Дає дерево
            --requires = "forest"    
            requires_near = "forest"-- Тільки в лісі
        },
        workshop = {
            cost = { wood = 40, stone = 20 },
            hp = 200,
            description = "Виробнича будівля. Потребує 1 селянина для роботи"
        },
        barracks = {
            cost = { stone = 40, wood = 40 },
            hp = 300,
            unitLimitBonus = { level1 = 4, level2 = 6 } 
        }
    },

    -- КАТАЛОГ ДОБУВАЮЧИХ БУДІВЕЛЬ (Ресурси)
    BUILDINGScatalog = {
        { id = "peasant_house", name = "peasant_house", cost = { wood = 15 }, income = 10},
        { id = "farm",          name = "farm",          cost = { wood = 20 }, income = 25},
        { id = "mine",          name = "mine",          cost = { wood = 30 }, income = 15},
        { id = "lumbermill",    name = "lumbermill",    cost = { stone = 10 }, income = 25},
        { id = "workshop",      name = "workshop",      cost = { wood = 40, stone = 20 }, income = 25},
        { id = "barracks",      name = "barracks",      cost = { stone = 40, wood = 40 }, income = 25}
    },

    -- ==========================================
    -- 4. ЮНІТИ (Воїни)
    -- ==========================================
    UNITS = {
        warrior_lv1 = {
            cost = { gold = 20 },
            upkeep = { gold = 2 },   -- Утримання 
            hp = 50,
            maxMoves = 4,            
            captureRadius = 1,       
            canAttackBuildings = false
        },
        warrior_lv2 = {
            cost = { gold = 50, wood = 10 },
            upkeep = { gold = 5 },
            hp = 100,
            maxMoves = 5,
            captureRadius = 2,
            canAttackBuildings = true, 
            canAttackCastle = false
        },
        warrior_lv3 = {
            cost = { wood = 15 },
            upkeep = { gold = 10 },
            hp = 250,
            maxMoves = 6,
            captureRadius = 3,
            canAttackBuildings = true,
            canAttackCastle = true     
        }
    },

    -- КАТАЛОГ ЮНІТІВ
    UNITScatalog = {
        { id = "warrior_lvl1", name = "Warrior Lvl 1", cost = { gold = 20 },  upkeep = 2,  moveRange = 2 },
        { id = "warrior_lvl2", name = "Warrior Lvl 2", cost = { gold = 50, wood = 10 }, upkeep = 5,  moveRange = 3 },
        { id = "warrior_lvl3", name = "Warrior Lvl 3", cost = { wood = 15 }, upkeep = 10, moveRange = 5 }
    }
}

-- КАТАЛОГ ЗАХИСНИХ СПОРУД
defense_buildings = {
    --{ id = "tower_lvl1", name = "Watch Tower", cost = 150, hp = 500, iconColor = {0.3, 0.3, 0.8} },
    --{ id = "wall", name = "Stone Wall", cost = 25, hp = 200, iconColor = {0.6, 0.6, 0.6} }
}

return RulesConfig