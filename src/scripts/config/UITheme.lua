-- src/scripts/config/UITheme.lua
local UITheme = {}

-- ==========================================
-- 1. ГЛОБАЛЬНІ НАЛАШТУВАННЯ (Для меню опцій)
-- ==========================================
UITheme.globalBgAlpha = 0.45 -- Прозорість фону вікон (0.0 до 1.0)
UITheme.fontMain = "src/assets/fonts/Jersey20-Regular.ttf"
UITheme.maxNameLength = 10

-- ==========================================
-- 2. ВІЗУАЛЬНИЙ СТИЛЬ (Заокруглення та Обводка)
-- ==========================================
UITheme.cornerRadius = 20    -- Наскільки круглі кути
UITheme.strokeWidth = 4      -- Товщина обводки
UITheme.strokeColor = {17/255, 13/255, 21/255} -- rgb(17, 13, 21)

-- ==========================================
-- 3. КОЛЬОРИ ГРАДІЄНТУ ФОНУ
-- ==========================================
UITheme.panelColorTop = {48/255, 37/255, 59/255}    -- Світліший верх
UITheme.panelColorBottom = {17/255, 13/255, 21/255} -- Темніший низ
-- ==========================================
-- 4. ГЕНЕРАТОР ГРАДІЄНТУ
-- ==========================================

topBar = {
    type = "gradient",
    color1 = { UITheme.panelColorTop[1], UITheme.panelColorTop[2], UITheme.panelColorTop[3], UITheme.globalBgAlpha },
    color2 = { UITheme.panelColorBottom[1], UITheme.panelColorBottom[2], UITheme.panelColorBottom[3], UITheme.globalBgAlpha },
    direction = "down"
}


--- Допоміжна функція для налаштування фону 
function UITheme.applyStyle(rectObj)
    rectObj:setFillColor(topBar)
    rectObj.strokeWidth = UITheme.strokeWidth
    -- Обводка завжди 100% непрозора для чіткості
    rectObj:setStrokeColor(UITheme.strokeColor[1], UITheme.strokeColor[2], UITheme.strokeColor[3], 0.55)
end

return UITheme