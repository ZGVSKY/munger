-- src/scripts/core/TurnManager.lua
local Logger = require("src.scripts.utils.logger")
local ToastManager = require("src.scripts.view.ToastManager")

local TurnManager = {}

TurnManager.TURN_TIME_LIMIT = 120 -- 2 хвилини на хід (в секундах)
TurnManager.timeRemaining = 0
TurnManager.timerId = nil

-- ==========================================
-- 1. СТАРТ ХОДУ (Для нового гравця)
-- ==========================================
function TurnManager.startTurn(gameState, scene)
    local player = gameState:getCurrentPlayer()
    Logger.info("TurnManager", "Turn started for " .. player.name)

    -- А) Перерахунок дельт (на всякий випадок)
    player:calculateDeltas()

    -- Б) Відновлення позиції камери
    if player.cameraX and player.cameraY and scene.cameraGroup and scene.cameraGroup.insert then
        -- Використовуємо transition для плавного перельоту камери!


        transition.to(scene.cameraGroup, {
            time = 600, 
            x = player.cameraX, 
            y = player.cameraY,
            xScale =  player.cameraScaleX,
            yScale = player.cameraScaleY,
            transition = easing.outQuad
            
        })
    end

    -- В) Запуск таймера
    TurnManager.timeRemaining = TurnManager.TURN_TIME_LIMIT
    
    if TurnManager.timerId then
        timer.cancel(TurnManager.timerId)
    end
    
    TurnManager.timerId = timer.performWithDelay(1000, function()
        TurnManager.timeRemaining = TurnManager.timeRemaining - 1
        
        -- Оновлюємо UI таймера
        if scene.gameUI then scene.gameUI:updateTimer(TurnManager.timeRemaining) end
        
        -- Якщо час вийшов - примусово завершуємо хід
        if TurnManager.timeRemaining <= 0 then
            ToastManager.show("Time's Up!", {0.9, 0.2, 0.2})
            TurnManager.endTurn(gameState, scene)
        end
    end, 0) -- 0 означає "повторювати нескінченно" (ми самі зупинимо)
    
    -- Оновлюємо UI
    if scene.gameUI then scene.gameUI:update() end
    ToastManager.show(player.name .. "'s Turn", player.color)
end

-- ==========================================
-- 2. ЗАВЕРШЕННЯ ХОДУ (Для поточного гравця)
-- ==========================================
function TurnManager.endTurn(gameState, scene)
    local player = gameState:getCurrentPlayer()

    -- А) Зупиняємо таймер
    if TurnManager.timerId then
        timer.cancel(TurnManager.timerId)
        TurnManager.timerId = nil
    end

    -- Б) Зберігаємо координати камери поточного гравця
    if scene.cameraGroup then
        player.cameraX = scene.cameraGroup.x
        player.cameraY = scene.cameraGroup.y
        player.cameraScaleX = scene.cameraGroup.xScale  
        player.cameraScaleY = scene.cameraGroup.yScale
    end

    -- В) ЕКОНОМІКА: Нараховуємо/віднімаємо ресурси на основі дельти
    -- Проходимося по всіх типах ресурсів у дельті і додаємо їх
    for resType, deltaAmount in pairs(player.resourceDeltas) do
        player:addResource(resType, deltaAmount)
    end
    
    -- Перевірка на банкрутство ТІЛЬКИ для золота (якщо впали в мінус)
    if player.resources.gold < 0 then
        player.resources.gold = 0
        player.isBankrupt = true
        Logger.info("TurnManager", player.name .. " is BANKRUPT!")
    else
        player.isBankrupt = false
    end

    -- Г) ПЕРЕДАЧА ХОДУ
    gameState.currentPlayerIndex = gameState.currentPlayerIndex + 1
    if gameState.currentPlayerIndex > #gameState.players then
        gameState.currentPlayerIndex = 1
        gameState.currentTurn = gameState.currentTurn + 1
    end

    -- Д) ЗАПУСК ХОДУ НАСТУПНОГО ГРАВЦЯ
    TurnManager.startTurn(gameState, scene)
end

function TurnManager.stopTimer()
    if TurnManager.timerId then
        timer.cancel(TurnManager.timerId)
        TurnManager.timerId = nil
    end
end

return TurnManager