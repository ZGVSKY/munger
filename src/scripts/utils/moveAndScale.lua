local isDevice = true 

function lengthOf( a, b )
    local width, height = b.x-a.x, b.y-a.y
    return (width*width + height*height)^0.5
end

function angleOfPoint( pt )
    local x, y = pt.x, pt.y
    local radian = math.atan2(y,x)
    local angle = radian*180/math.pi
    if angle < 0 then angle = 360 + angle end
    return angle
end

function angleBetweenPoints( a, b )
    local x, y = b.x - a.x, b.y - a.y
    return angleOfPoint( { x=x, y=y } )
end

local function calcAvgCentre( points )
    local x, y = 0, 0
    for i=1, #points do
        local pt = points[i]
        x = x + pt.x; y = y + pt.y
    end
    return { x = x / #points, y = y / #points }
end

local function updateTracking( centre, points )
    for i=1, #points do
        local point = points[i]
        point.prevAngle = point.angle
        point.prevDistance = point.distance
        point.angle = angleBetweenPoints( centre, point )
        point.distance = lengthOf( centre, point )
    end
end

local function calcAverageScaling( points )
    local total = 0
    for i=1, #points do
        local point = points[i]
        total = total + point.distance / point.prevDistance
    end
    return total / #points
end

-- ==========================================
-- Вбудовані межі камери (БЕЗ Округлення)
-- ==========================================
local function enforceBounds(rect)
    if not rect.mapWidth or not rect.mapHeight then 
        rect.x = rect.exactX
        rect.y = rect.exactY
        return 
    end
    
    local mapW = rect.mapWidth * rect.xScale
    local mapH = rect.mapHeight * rect.yScale
    
    local screenW = display.actualContentWidth
    local screenH = display.actualContentHeight
    
    local minX = display.screenOriginX + screenW - (mapW / 2)
    local maxX = display.screenOriginX + (mapW / 2)
    
    local minY = display.screenOriginY + screenH - (mapH / 2)
    local maxY = display.screenOriginY + (mapH / 2)

    if mapW <= screenW then
        rect.exactX = display.contentCenterX
    else
        if rect.exactX < minX then rect.exactX = minX; rect.vx = 0 end
        if rect.exactX > maxX then rect.exactX = maxX; rect.vx = 0 end
    end

    if mapH <= screenH then
        rect.exactY = display.contentCenterY
    else
        if rect.exactY < minY then rect.exactY = minY; rect.vy = 0 end
        if rect.exactY > maxY then rect.exactY = maxY; rect.vy = 0 end
    end
    
    -- Віддаємо точні дробові координати для максимальної плавності
    rect.x = rect.exactX
    rect.y = rect.exactY
end

function newTrackDot(e)
    local circle = display.newCircle( e.x, e.y, 50 )
    circle.alpha = 0
    local rect = e.target

    function circle:touch(e)
        local target = circle
        e.parent = rect

        if (e.phase == "began") then
            display.getCurrentStage():setFocus(target, e.id)
            target.hasFocus = true
            return true
        elseif (target.hasFocus) then
            if (e.phase == "moved") then
                target.x, target.y = e.x, e.y
            else 
                display.getCurrentStage():setFocus(target, nil)
                target.hasFocus = false
            end
            rect:touch(e)
            return true
        end
        return false
    end

    circle:addEventListener("touch")
    circle:touch(e)
    return circle
end

function touch(self, e)
    local rect = self

    if (e.phase == "began") then
        local dot = newTrackDot(e)
        rect.dots[ #rect.dots+1 ] = dot
        rect.prevCentre = calcAvgCentre( rect.dots )
        updateTracking( rect.prevCentre, rect.dots )
        
        rect.isDragging = true
        rect.vx, rect.vy = 0, 0
        
        rect.exactX = rect.x
        rect.exactY = rect.y
        
        return true
    elseif (e.parent == rect) then
        if (e.phase == "moved") then
            local centre = calcAvgCentre( rect.dots )
            updateTracking( rect.prevCentre, rect.dots )

            local scale = 1
            if (#rect.dots > 1) then
                scale = calcAverageScaling( rect.dots )
                
                local minZoom, maxZoom = 0.5, 2.0
                local targetScale = rect.xScale * scale
                if targetScale < minZoom then scale = minZoom / rect.xScale end
                if targetScale > maxZoom then scale = maxZoom / rect.xScale end
                
                rect.xScale, rect.yScale = rect.xScale * scale, rect.yScale * scale
            end

            local pt = {}
            local dx = centre.x - rect.prevCentre.x
            local dy = centre.y - rect.prevCentre.y
            
            pt.x = rect.exactX + dx
            pt.y = rect.exactY + dy

            pt.x = centre.x + ((pt.x - centre.x) * scale)
            pt.y = centre.y + ((pt.y - centre.y) * scale)

            rect.exactX = pt.x
            rect.exactY = pt.y
            enforceBounds(rect)

            rect.prevCentre = centre
            
            -- ЧИСТА ПОКАДРОВА ШВИДКІСТЬ (без рваного dt)
            if #rect.dots == 1 then
                -- Згладжуємо поточний рух (dx/dy) з попередньою швидкістю
                rect.vx = (rect.vx * 0.5) + (dx * 0.5)
                rect.vy = (rect.vy * 0.5) + (dy * 0.5)
            else
                rect.vx, rect.vy = 0, 0 
            end

        else 
            if (isDevice or e.numTaps == 2) then
                local index = table.indexOf( rect.dots, e.target )
                table.remove( rect.dots, index )
                e.target:removeSelf()
                if #rect.dots > 0 then
                    rect.prevCentre = calcAvgCentre( rect.dots )
                    updateTracking( rect.prevCentre, rect.dots )
                end
            end
            
            if #rect.dots == 0 then
                rect.isDragging = false
                if not rect.hasInertiaLoop then
                    rect.hasInertiaLoop = true
                    Runtime:addEventListener("enterFrame", rect.inertiaLogic)
                end
            end
        end
        return true
    end
    return false
end

local MAS = {}

function MAS:init(rect)
    local group = display.newGroup()
    group:insert( rect ) 
    group.dots = {}
    
    group.vx, group.vy = 0, 0
    group.isDragging = false
    group.hasInertiaLoop = false
    
    group.exactX = rect.x
    group.exactY = rect.y
    
    group.inertiaLogic = function()
        if group.isDragging then return end
        
        -- ВИПРАВЛЕНО: Жорсткий поріг зупинки. Якщо швидкість < 0.5, зупиняємось миттєво.
        -- Це прибирає ефект "дрижання/повзання" в кінці гальмування.
        if math.abs(group.vx) > 0.5 or math.abs(group.vy) > 0.5 then
            -- Додаємо швидкість прямо до координат (ідеальна математична крива)
            group.exactX = group.exactX + group.vx
            group.exactY = group.exactY + group.vy
            
            enforceBounds(group)
            
            -- Гальмування (множимо швидкість на 0.9 кожен кадр)
            group.vx = group.vx * 0.90
            group.vy = group.vy * 0.90
        else
            -- Повна зупинка
            group.vx, group.vy = 0, 0
            Runtime:removeEventListener("enterFrame", group.inertiaLogic)
            group.hasInertiaLoop = false
        end
    end

    return group
end

function MAS:start(group)
    -- Автоматична ініціалізація всіх змінних для інерції
    group.exactX = group.exactX or group.x
    group.exactY = group.exactY or group.y
    group.vx = group.vx or 0
    group.vy = group.vy or 0
    group.dots = group.dots or {}
    group.isDragging = false
    group.hasInertiaLoop = false
    
    -- СТВОРЮЄМО ЛОГІКУ ІНЕРЦІЇ, ЯКЩО ЇЇ НЕМАЄ
    group.inertiaLogic = group.inertiaLogic or function()
        if group.isDragging then return end
        
        if math.abs(group.vx) > 0.5 or math.abs(group.vy) > 0.5 then
            group.exactX = group.exactX + group.vx
            group.exactY = group.exactY + group.vy
            
            enforceBounds(group)
            
            group.vx = group.vx * 0.90
            group.vy = group.vy * 0.90
        else
            group.vx, group.vy = 0, 0
            Runtime:removeEventListener("enterFrame", group.inertiaLogic)
            group.hasInertiaLoop = false
        end
    end

    group.touch = touch
    group:addEventListener("touch")

    group._mouseListener = function(event)
        if event.type == "scroll" then
            local zoomFactor = -(event.scrollY * 0.05) 
            local newScale = group.xScale + zoomFactor
            
            if newScale < 0.5 then newScale = 0.5 end
            if newScale > 2.0 then newScale = 2.0 end
            
            group.xScale = newScale
            group.yScale = newScale
            
            enforceBounds(group)
            return true
        end
    end
    
    Runtime:addEventListener("mouse", group._mouseListener)
end

function MAS:setBounds(group, totalWidth, totalHeight)
    group.mapWidth = totalWidth
    group.mapHeight = totalHeight
    
    -- ЗАПОБІЖНИК: Гарантуємо, що координати існують до перевірки меж
    group.exactX = group.exactX or group.x
    group.exactY = group.exactY or group.y
    
    enforceBounds(group) 
end

function MAS:stop(group)
    group:removeEventListener("touch")
    if group._mouseListener then
        Runtime:removeEventListener("mouse", group._mouseListener)
    end
    if group.hasInertiaLoop then
        Runtime:removeEventListener("enterFrame", group.inertiaLogic)
        group.hasInertiaLoop = false
    end
    group.touch = nil
end

return MAS