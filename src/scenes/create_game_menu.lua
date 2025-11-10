-- import requirements
composer = require( "composer" )
scene = composer.newScene()
widget = require "widget"

-- global enviroments
assets_path = 'src/assets/menu/'
screen_width = display.actualContentWidth
screen_height = display.actualContentHeight

local players = {} -- таблиця для зберігання гравців
local usedColors = {} -- Таблиця для зберігання зайнятих кольорів
local colorButtonTable = {}     -- Таблиця для зберігання самих об'єктів кнопок
local maxPlayers = 6
local playersPerRow = 3

function scene:create( event )
    local sceneGroup = self.view

    local assest_to_load = {
        'background (1).png', 'logo.png', 'Rectangle1.png', 'Players.png', 
        'Line1.png', 'Line2.png', 'player.png', 'addnew.png'         
    }

    
    local loaded_assets = {}
    for i=1,#assest_to_load do
        loaded_assets[i] = graphics.newTexture( {
            type = "image", filename = assets_path .. assest_to_load[i],
            baseDir = system.ResourceDirectory
        } )
        loaded_assets[i]:preload()
    end
    sceneGroup.textures = loaded_assets
        
    local background = display.newImageRect( sceneGroup, sceneGroup.textures[1].filename, sceneGroup.textures[1].baseDir, screen_width, screen_height )
    local logo = display.newImageRect( sceneGroup, sceneGroup.textures[2].filename, sceneGroup.textures[2].baseDir, 338*2, 56*2 )

    local panel_width = screen_width * 0.85
    local panel_height = screen_height * 0.65

    local panel = display.newImageRect( sceneGroup, sceneGroup.textures[3].filename, sceneGroup.textures[3].baseDir, panel_width, panel_height )
    local playersText = display.newImageRect( sceneGroup, sceneGroup.textures[4].filename, sceneGroup.textures[4].baseDir, 152*2, 43*2 )
    local line1 = display.newImageRect( sceneGroup, sceneGroup.textures[5].filename, sceneGroup.textures[5].baseDir, 442*2, 23*2 )
    local line2 = display.newImageRect( sceneGroup, sceneGroup.textures[6].filename, sceneGroup.textures[6].baseDir, 442*2, 23*2 )
 

    -- розміри наших файлів
    background.x = screen_width / 2; background.y = screen_height / 2
    logo.x = screen_width / 2; logo.y = screen_height * 0.15
    panel.x = screen_width / 2; panel.y = screen_height * 0.55
    playersText.x = screen_width / 2; playersText.y = panel.y - (panel_height * 0.1)
    line1.x = screen_width / 2; line1.y = playersText.y + 70
    line2.x = screen_width / 2; line2.y = panel.y + (panel_height * 0.25)


    -- 6 кольорів
    local colors = {
        { 1, 0, 0 }, -- Червоний
        { 0, 1, 0 }, -- Зелений
        { 0, 0, 1 }, -- Синій
        { 1, 1, 0 }, -- Жовтий
        { 0, 1, 1 }, -- Блакитний
        { 1, 0, 1 }  -- Пурпуровий
    }

    -- розміри кнопки кольору і початкова позиція Х для першої кнопки кольору
    local colorButtonSize = 80
    local colorButtonPadding = 20
    local colorStartX = -(colorButtonSize * 1.5 + colorButtonPadding) 

    -- початкові координати плюса
    local startX = (screen_width / 2) - 330
    local startY = panel.y + (panel_height * 0.30)
    
    -- розміри і відступи іконок
    local iconWidth = 89*2
    local iconHeight = 60*2
    local padding = 40 
    local verticalPadding = 20 

    sceneGroup.colorButtonTable = colorButtonTable -- вказівник на таблицю для зберігання кнопок кольорів

    
    -- Створює іконку гравця 
    local function createPlayerIcon( xPos, yPos )
        local icon = display.newImageRect( sceneGroup, sceneGroup.textures[7].filename, sceneGroup.textures[7].baseDir, iconWidth, iconHeight )
        icon.x = xPos
        icon.y = yPos
        table.insert(players, icon) -- додає іконку в список
        return icon
    end

    -- Створює кнопку "додати"
    local function createAddButton( xPos, yPos )
        local button = display.newImageRect( sceneGroup, sceneGroup.textures[8].filename, sceneGroup.textures[8].baseDir, iconWidth, iconHeight )
        button.x = xPos
        button.y = yPos
        return button
    end

    -- викликається коли гравець обирає колір
    local function onColorSelected( event )
        -- колір, який обрав користувач
        local selectedColor = event.target.fill
        local selectedButton = event.target
        local selectedIndex = selectedButton.colorIndex --  індекс кольору, який ми зберегли на кнопці

        if usedColors[selectedIndex] then -- перевірка чи колір зайнятий 
            return true 
        end
        usedColors[selectedIndex] = true -- позначаємо що колір який ми обрали зайнятий
        
        local currentButton = sceneGroup.pendingButton -- Знаходимо, яку кнопку плюс ми натиснули
        if not currentButton then return true end -- Захист від подвійного натискання

        -- Ховаємо панель кольорів з анімацією
        local colorPanel = sceneGroup.colorPanel
        transition.to( colorPanel, { 
            alpha = 0, 
            time = 300, 
            onComplete = function() colorPanel.isVisible = false end 
        } )

        if #players < maxPlayers then
            local newPlayerIcon = createPlayerIcon( currentButton.x, currentButton.y ) -- Створюємо іконку гравця на місці кнопки плюс
            
            newPlayerIcon:setFillColor( selectedColor.r, selectedColor.g, selectedColor.b ) -- фарбуємо іконку гравця
            
            -- Видаляємо кнопку плюс
            currentButton.isVisible = false
            currentButton:removeSelf()
            currentButton = nil

            if #players < maxPlayers then -- Перевіряємо, чи потрібно створювати нову кнопку плюс

                
                local nextButtonX
                local nextButtonY
                local currentPlayerCount = #players -- видає помилку якщо вказувати #players в if

                if (currentPlayerCount % playersPerRow == 0) then
                    nextButtonX = startX
                    nextButtonY = newPlayerIcon.y + iconHeight + verticalPadding 
                else
                    nextButtonX = newPlayerIcon.x + iconWidth + padding
                    nextButtonY = newPlayerIcon.y 
                end

                -- Створюємо НОВУ кнопку плюс
                local newAddButton = createAddButton( nextButtonX, nextButtonY )
                newAddButton:addEventListener( "tap", onAddButtonTap )
                sceneGroup.currentAddButton = newAddButton 

            end
        end
        
        -- Скидаємо збережену кнопку
        sceneGroup.pendingButton = nil
        return true
    end

    -- коли натискаємо кнопку викликається ця функція
    function onAddButtonTap( event )
        local currentButton = event.target 
        
        
        -- Якщо панель вже відкрита, нічого не робимо
        if sceneGroup.colorPanel.isVisible == true then
            return true
        end
        
        sceneGroup.pendingButton = currentButton  -- Зберігаємо, кнопку плюс яку ми натиснули, для створення гравця на тому місці
        local buttons = sceneGroup.colorButtonTable -- щоб зробити фор
        for i = 1, #buttons do -- проходимося по всьому списку кольорів, дії з які не використали і які використали
            local button = buttons[i]
            if usedColors[i] then
                button.alpha = 0.3 -- Робимо напівпрозорим
                button.isHitTestable = false -- вимикаємо натискання
                button.cross.isVisible = true -- ПОКАЗУЄМО хрестик
            else
                button.alpha = 1.0 -- Повна видимість
                button.isHitTestable = true -- вмикаємо натискання
                button.cross.isVisible = false -- ховаємо хрестик
            end
        end
        
        -- Показуємо панель кольорів з анімацією
        sceneGroup.colorPanel.isVisible = true
        transition.to( sceneGroup.colorPanel, { alpha = 1, time = 300 } )

        return true
    end
    
    -- Створюємо новий контейнер для зручності
    local colorPanel = display.newContainer( screen_width, screen_height )
    colorPanel.x = screen_width / 2
    colorPanel.y = screen_height / 2
    sceneGroup:insert( colorPanel ) 
    sceneGroup.colorPanel = colorPanel

    -- Додаємо фон до панелі кольорів і ставимо його в середині colorPanel
    local colorPanelBG = display.newImageRect( colorPanel, sceneGroup.textures[3].filename, sceneGroup.textures[3].baseDir, panel_width * 0.8, panel_height * 0.5 )
    colorPanelBG.x = 0
    colorPanelBG.y = 0

    -- Створюємо кнопки кольорів
    for i = 1, #colors do
        local colorButton = display.newRect( colorPanel, 0, 0, colorButtonSize, colorButtonSize )
        colorButton:setFillColor( colors[i][1], colors[i][2], colors[i][3] )
        
        -- для спрощення автоматичного розставляння 6 кнопок кольорів у акуратну сітку (2 рядки по 3 стовпці ) 
        local row = math.floor((i - 1) / 3) 
        local col = (i - 1) % 3 
        colorButton.x = colorStartX + col * (colorButtonSize + colorButtonPadding)
        colorButton.y = (colorPanelBG.y - colorPanelBG.height/2 + 100) + row * (colorButtonSize + colorButtonPadding)

        colorButton.colorIndex = i

        -- Створюємо хрестик для кожної кнопки
        local cross = display.newText( colorPanel, "X", 0, 0, native.systemFontBold, colorButtonSize * 0.8 )
        cross.x = colorButton.x
        cross.y = colorButton.y
        cross:setFillColor( 0.2, 0.2, 0.2, 0.8 ) 
        cross.isVisible = false 
        
        -- Прив'язуємо хрестик до кнопки
        colorButton.cross = cross

        colorButton:addEventListener( "tap", onColorSelected )

        table.insert( colorButtonTable, colorButton )
    end
    
    -- Ховаємо панель при запуску
    colorPanel.alpha = 0
    colorPanel.isVisible = false

    local initialAddButton = createAddButton( startX, startY )
    initialAddButton:addEventListener( "tap", onAddButtonTap ) -- оживляємо кнопку
    sceneGroup.currentAddButton = initialAddButton
    
end

function scene:show( event )
    -- Called when the scene on the screen
    local sceneGroup = self.view
    local phase = event.phase
    
    print( "show" )
end

function scene:hide( event )
    local sceneGroup = self.view
    local phase = event.phase
    
    if event.phase == "will" then
        -- Called when the scene is on screen and is about to move off screen
        -- e.g. stop timers, stop animation, unload sounds, etc.)

    elseif phase == "did" then
        -- Called when the scene is now off screen
    end 
end

function scene:destroy( event )
    local sceneGroup = self.view
    -- Called prior to the removal of scene's "view" (sceneGroup)
    -- e.g. remove display objects, remove touch listeners, save state, etc.

    -- unload all textures
    for i = 1,#sceneGroup.textures do
        sceneGroup.textures[i]:releaseSelf()
    end
    display.remove(sceneGroup)
    players = {} -- Очищаємо список гравців при знищенні сцени
    usedColors = {}
    colorButtonTable = {}
end

---------------------------------------------------------------------------------

-- Listener setup
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

-----------------------------------------------------------------------------------------

return scene