-- src/scripts/view/ToastManager.lua
local ScreenUtils = require("src.scripts.view.ScreenUtils")

local ToastManager = {}

-- Черга активних повідомлень
local activeToasts = {}
-- Група для відмальовки (сюди будемо передавати uiLayer зі сцени)
local targetLayer = nil

function ToastManager.init(uiLayer)
    targetLayer = uiLayer
end

--- Показує спливаюче повідомлення
-- @param text (string) Текст повідомлення
-- @param color (table) RGB колір фону {r, g, b}
function ToastManager.show(text, color)
    if not targetLayer then return end
    
    local bgColor = color or {0.2, 0.2, 0.2}
    
    -- Використовуємо нашу "CSS" систему розмірів!
    local toastW = ScreenUtils.px(400)
    local toastH = ScreenUtils.px(60)
    local fontSize = ScreenUtils.px(24)
    local cornerRadius = ScreenUtils.px(15)
    
    -- Стартова позиція (внизу безпечної зони, за межами екрану)
    local startX = ScreenUtils.safeX + (ScreenUtils.safeWidth / 2)
    local startY = ScreenUtils.safeY + ScreenUtils.safeHeight + toastH

    -- Створюємо групу
    local toastGroup = display.newGroup()
    targetLayer:insert(toastGroup)
    
    -- Фон
    local bg = display.newRoundedRect(toastGroup, 0, 0, toastW, toastH, cornerRadius)
    bg:setFillColor(bgColor[1], bgColor[2], bgColor[3], 0.9)
    bg.strokeWidth = 2
    bg:setStrokeColor(1, 1, 1, 0.5)
    
    -- Текст
    display.newText({
        parent = toastGroup,
        text = text,
        x = 0, y = 0,
        font = native.systemFontBold,
        fontSize = fontSize
    })
    
    toastGroup.x = startX
    toastGroup.y = startY
    
    -- Анімація 1: Виїзд вгору
    local targetY = ScreenUtils.safeY + ScreenUtils.safeHeight - ScreenUtils.px(100) - (#activeToasts * (toastH + ScreenUtils.px(10)))
    
    transition.to(toastGroup, {
        y = targetY, 
        time = 400, 
        transition = easing.outBack,
        onComplete = function()
            -- Анімація 2: Затримка і зникання
            transition.to(toastGroup, {
                alpha = 0,
                time = 500,
                delay = 2000, -- Висить 2 секунди
                onComplete = function()
                    -- Видалення з екрану та пам'яті
                    toastGroup:removeSelf()
                    -- Видаляємо з черги
                    for i, t in ipairs(activeToasts) do
                        if t == toastGroup then table.remove(activeToasts, i) break end
                    end
                end
            })
        end
    })
    
    table.insert(activeToasts, toastGroup)
end

return ToastManager