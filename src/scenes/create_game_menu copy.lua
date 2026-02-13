-- import requirements
local composer = require( "composer" )
local scene = composer.newScene()
local widget = require "widget"

-- global environments
local assets_path = 'src/assets/menu/'
local screen_width = display.actualContentWidth
local screen_height = display.actualContentHeight

-- Локальні змінні для логіки гравців
local players = {} 
local usedColors = {} 
local colorButtonTable = {}     
local maxPlayers = 6
local playersPerRow = 3

function scene:create( event )
    local sceneGroup = self.view

    -- Список ассетів
    local assest_to_load = {
        'background (1).png', 'logo.png', 'Rectangle1.png', 'Players.png', 
        'Line1.png', 'Line2.png', 'player.png', 'addnew.png'         
    }

    -- Завантаження текстур
    local loaded_assets = {}
    for i=1,#assest_to_load do
        loaded_assets[i] = graphics.newTexture( {
            type = "image", filename = assets_path .. assest_to_load[i],
            baseDir = system.ResourceDirectory
        } )
        loaded_assets[i]:preload()
    end
    sceneGroup.textures = loaded_assets
        
    -- Основний інтерфейс
    local background = display.newImageRect( sceneGroup, sceneGroup.textures[1].filename, sceneGroup.textures[1].baseDir, screen_width, screen_height )
    local logo = display.newImageRect( sceneGroup, sceneGroup.textures[2].filename, sceneGroup.textures[2].baseDir, 338*2, 56*2 )

    local panel_width = screen_width * 0.85
    local panel_height = screen_height * 0.65

    local panel = display.newImageRect( sceneGroup, sceneGroup.textures[3].filename, sceneGroup.textures[3].baseDir, panel_width, panel_height )
    local playersText = display.newImageRect( sceneGroup, sceneGroup.textures[4].filename, sceneGroup.textures[4].baseDir, 152*2, 43*2 )
    local line1 = display.newImageRect( sceneGroup, sceneGroup.textures[5].filename, sceneGroup.textures[5].baseDir, 442*2, 23*2 )
    local line2 = display.newImageRect( sceneGroup, sceneGroup.textures[6].filename, sceneGroup.textures[6].baseDir, 442*2, 23*2 )

    background.x = screen_width / 2; background.y = screen_height / 2
    logo.x = screen_width / 2; logo.y = screen_height * 0.15
    panel.x = screen_width / 2; panel.y = screen_height * 0.55
    playersText.x = screen_width / 2; playersText.y = panel.y - (panel_height * 0.1)
    line1.x = screen_width / 2; line1.y = playersText.y + 70
    line2.x = screen_width / 2; line2.y = panel.y + (panel_height * 0.25)


    -- 6 неонових кольорів для меню
    local colors = {
        { 1, 0.2, 0.2 },    -- Яскраво-червоний 🔴
        { 0.2, 1, 0.2 },    -- Неоновий лайм 🟢
        { 0.2, 1, 1 },      -- Ціан (Блакитний) 🔵
        { 1, 1, 0.2 },      -- Сонячно-жовтий 🟡
        { 1, 0.6, 0 },      -- Оранжевий 🟠
        { 0.9, 0.2, 0.9 }   -- Маджента (Рожевий) 🟣
    }

    

    -- функція для заглиблення у полі введення
    local function createInputBox( group, x, y, width, height )
    
    local bg = display.newRect( group, x, y, width, height )
    
    local topShadow = display.newLine( group, x - width/2, y - height/2, x + width/2, y - height/2 )
    topShadow:setStrokeColor( 0, 0, 0 ) 
    topShadow.strokeWidth = 2

    local leftShadow = display.newLine( group, x - width/2, y - height/2, x - width/2, y + height/2 )
    leftShadow:setStrokeColor( 0, 0, 0 ) 
    leftShadow.strokeWidth = 2

    return bg
end


local function createPlayerRow( index )
    -- група для наших списків ( ім'я колір і тд )
    local rowGroup = display.newGroup()
    local yPos = 100 + (index - 1) * 60
    
    -- розміщуємо групу на точку
    rowGroup.y = yPos
    rowGroup.x = screen_width / 2  

    -- створення заглиблення у полі введення ( функція вище )  
    local visualBox = createInputBox( rowGroup, 0, 0, 200, 40 )

    -- створюємо текстове поле для ніку
    local inputField = native.newTextField( 0, 0, 200, 40 )
    
    -- додаємо текстове поле в групу 
    rowGroup:insert( inputField )

    -- прибираємо фон який йде у текстовому полі
    inputField.hasBackground = false 

    -- галочка і хрестик
    local checkIcon = display.newImageRect( rowGroup, "assets/ok.png", 40, 40 )
    local deleteIcon = display.newImageRect( rowGroup, "assets/no.png", 40, 40 )

    -- зміщуємо вправо від поля вводу тексту
    checkIcon.x = 150 
    deleteIcon.x = 150 

    -- Вставляємо в групу галочку і хрестик
    rowGroup:insert( checkIcon )
    rowGroup:insert( deleteIcon )

    -- прив'язуємо галочку і хрестик до групи за іменем
    rowGroup.okIcon = checkIcon   
    rowGroup.delIcon = deleteIcon
    rowGroup.okIcon.isVisible = true
    rowGroup.delIcon.isVisible = false

        -- створення прямокутника для кольору 
    local colorBox = display.newRect( rowGroup, 0, 0, 30, 30 )

     -- початковий колір 
    local startColorIndex = 1
    colorBox.myColorIndex = startColorIndex


    -- функція для зміни кольору циклічного при натисканні
    local function changeColor( event )
    

        colorBox.myColorIndex = colorBox.myColorIndex + 1
        if colorBox.myColorIndex > #colors then colorBox.myColorIndex = 1 end
        colorBox:setFillColor( unpack( colors[ colorBox.myColorIndex ] ) )
    
    end

    -- функція коли натискаємо на галочку, заборона змінювати ім'я і заборона змінювати колір
    local function onSaveRow( event )
        -- Блокуємо зміну кольору
        colorBox:removeEventListener( "tap", changeColor ) 

        -- Блокуємо введення тексту
        inputField.isEditable = false 

        -- Ховаємо клавіатуру
        native.setKeyboardFocus( nil )

        -- галочку ховаємо, хрестик показуємо
        checkIcon.isVisible = false
        deleteIcon.isVisible = true 

        index = index + 1
        if index <= #colors then 
        createPlayerRow(index)
        end 
    end

    -- нажимаємо на галочку
    checkIcon:addEventListener( "tap", onSaveRow )

    -- нажимаємо на трикутник з кольором 
    colorBox:addEventListener( "tap", changeColor )

        
        return rowGroup
end





scene:addEventListener( "create", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene