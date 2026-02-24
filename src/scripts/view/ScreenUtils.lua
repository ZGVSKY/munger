-- src/scripts/view/ScreenUtils.lua
local ScreenUtils = {}

-- ==========================================
-- 1. БЕЗПЕЧНІ ЗОНИ (Safe Areas)
-- ==========================================
local top, left, bottom, right = display.getSafeAreaInsets()

ScreenUtils.safeX = display.screenOriginX + left
ScreenUtils.safeY = display.screenOriginY + top
ScreenUtils.safeWidth = display.actualContentWidth - left - right
ScreenUtils.safeHeight = display.actualContentHeight - top - bottom

-- ==========================================
-- 2. "CSS" МАСШТАБУВАННЯ (Reference Scaling)
-- ==========================================
-- Ми беремо уявну (віртуальну) висоту екрану за еталон. 
-- Наприклад, 1000 "умовних одиниць".
local BASE_HEIGHT = 1000 

-- Рахуємо множник. Якщо реальний екран більший за 1000, множник > 1. Якщо менший - < 1.
ScreenUtils.uiScale = ScreenUtils.safeHeight / BASE_HEIGHT

-- @param value (number) базовий розмір
-- @return (number) Розмір, адаптований під поточний екран
function ScreenUtils.px(value)
    return math.floor(value * ScreenUtils.uiScale)
end

return ScreenUtils