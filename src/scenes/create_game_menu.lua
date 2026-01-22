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

    -- Налаштування кольорів
    local colors = {
        { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 }, 
        { 1, 1, 0 }, { 0, 1, 1 }, { 1, 0, 1 }  
    }

    local colorButtonSize = 80
    local colorButtonPadding = 20
    local colorStartX = -(colorButtonSize * 1.5 + colorButtonPadding) 

    sceneGroup.currentSelectedName = ""
    sceneGroup.currentSelectedColorIndex = nil
    sceneGroup.tempRGB = nil

    local startX = (screen_width / 2) - 330
    local startY = panel.y + (panel_height * 0.30)
    
    local iconWidth = 89*2
    local iconHeight = 60*2
    local padding = 40 
    local verticalPadding = 20 

    -- Оголошення функцій (Forward Declaration)
    local onAddButtonTap, onColorSelected, onNameFieldInput, onDoneButtonTap, checkDoneButtonState

    local function createPlayerIcon( xPos, yPos )
        local icon = display.newImageRect( sceneGroup, sceneGroup.textures[7].filename, sceneGroup.textures[7].baseDir, iconWidth, iconHeight )
        icon.x = xPos
        icon.y = yPos
        table.insert(players, icon)
        return icon
    end

    local function createAddButton( xPos, yPos )
        local button = display.newImageRect( sceneGroup, sceneGroup.textures[8].filename, sceneGroup.textures[8].baseDir, iconWidth, iconHeight )
        button.x = xPos
        button.y = yPos
        return button
    end

    checkDoneButtonState = function()
        local nameOK = (sceneGroup.currentSelectedName ~= "") 
        local colorOK = (sceneGroup.currentSelectedColorIndex ~= nil)
        
        if sceneGroup.doneButton then
            if (nameOK and colorOK) then
                sceneGroup.doneButton.alpha = 1.0
                sceneGroup.doneButton.isHitTestable = true
            else
                sceneGroup.doneButton.alpha = 0.5
                sceneGroup.doneButton.isHitTestable = false
            end
        end
    end

    function onNameFieldInput( event )
    local textField = event.target

        if event.phase == "editing" and textField.isVisible == true then
             local originalText = textField.text
            local newText = originalText

            newText = string.gsub( newText, "[^%w%s]", "" )

            if string.len( newText ) > 12 then
                newText = string.sub( newText, 1, 12 ) 
            end

            if originalText ~= newText then
                textField.text = newText
            end

            sceneGroup.currentSelectedName = textField.text
            checkDoneButtonState()

            if event.phase == "submitted" or event.phase == "ended" then

            native.setKeyboardFocus(nil)

            end

        return true

        end 
    end

    

    -- ВИПРАВЛЕНО: Правильне присвоєння функції
    onColorSelected = function( event )
        local selectedButton = event.target
        local selectedIndex = selectedButton.colorIndex 

        if usedColors[selectedIndex] then return true end
        
        if sceneGroup.currentSelectedColorIndex == selectedIndex then
            selectedButton.checkmark.isVisible = false
            sceneGroup.currentSelectedColorIndex = nil
            sceneGroup.tempRGB = nil
        else
            for i = 1, #colorButtonTable do
                colorButtonTable[i].checkmark.isVisible = false
            end
            selectedButton.checkmark.isVisible = true
            sceneGroup.currentSelectedColorIndex = selectedIndex
            sceneGroup.tempRGB = selectedButton.rawColor -- Зберігаємо RGB
        end
        checkDoneButtonState()
        return true
    end

    onDoneButtonTap = function( event )
        if event.target.alpha < 1 then return true end

        local selectedIndex = sceneGroup.currentSelectedColorIndex
        local rgb = sceneGroup.tempRGB
        local currentButton = sceneGroup.pendingButton

        usedColors[selectedIndex] = true 
        
        -- Ховаємо панель
        if sceneGroup.nameField then sceneGroup.nameField.isVisible = false end
        transition.to( sceneGroup.colorPanel, { 
            alpha = 0, time = 300, 
            onComplete = function() 
                sceneGroup.colorPanel.isVisible = false 
            end 
        } )
        native.setKeyboardFocus(nil)

        -- Створення гравця
        if #players < maxPlayers then
            local newPlayerIcon = createPlayerIcon( currentButton.x, currentButton.y )
            newPlayerIcon:setFillColor( rgb[1], rgb[2], rgb[3] )
            newPlayerIcon.playerName = sceneGroup.currentSelectedName 
            
            display.remove(currentButton)

            if #players < maxPlayers then
                local nextButtonX, nextButtonY
                local currentPlayerCount = #players 

                if (currentPlayerCount % playersPerRow == 0) then
                    nextButtonX = startX
                    nextButtonY = newPlayerIcon.y + iconHeight + verticalPadding 
                else
                    nextButtonX = newPlayerIcon.x + iconWidth + padding
                    nextButtonY = newPlayerIcon.y 
                end

                local newAddButton = createAddButton( nextButtonX, nextButtonY )
                newAddButton:addEventListener( "tap", onAddButtonTap )
                sceneGroup.colorPanel:toFront() -- Панель завжди зверху
            end
        end
        return true
    end

    onAddButtonTap = function( event )
        if sceneGroup.colorPanel.isVisible then return true end
        
        sceneGroup.pendingButton = event.target
        sceneGroup.currentSelectedName = ""
        sceneGroup.currentSelectedColorIndex = nil
        if sceneGroup.nameField then sceneGroup.nameField.text = "" end
        
        for i = 1, #colorButtonTable do
            local button = colorButtonTable[i]
            button.checkmark.isVisible = false
            if usedColors[i] then
                button.alpha = 0.3
                button.isHitTestable = false 
                button.cross.isVisible = true 
            else
                button.alpha = 1.0
                button.isHitTestable = true 
                button.cross.isVisible = false 
            end
        end
        
        checkDoneButtonState()
        sceneGroup.colorPanel.isVisible = true
        if sceneGroup.nameField then sceneGroup.nameField.isVisible = true end
        transition.to( sceneGroup.colorPanel, { alpha = 1, time = 300 } )
        return true
    end

    -- Створення панелі (Container)
    local colorPanel = display.newContainer( screen_width, screen_height )
    colorPanel.x = screen_width / 2; colorPanel.y = screen_height / 2
    sceneGroup:insert( colorPanel ) 
    sceneGroup.colorPanel = colorPanel

    local colorPanelBG = display.newImageRect( colorPanel, sceneGroup.textures[3].filename, sceneGroup.textures[3].baseDir, panel_width * 0.9, panel_height * 0.8 )
    
    local yPos = -colorPanelBG.height/2 + 60
    local nameLabel = display.newText( colorPanel, "Введіть ім'я:", 0, yPos, native.systemFont, 36 )
    nameLabel.anchorX = 0; nameLabel.x = -colorPanelBG.width/2 + 30
    
    yPos = yPos + 80
    -- Поле введення (Native)
    local nameField = native.newTextField( screen_width/2, screen_height/2 + yPos - 40, colorPanelBG.width - 60, 80 )
    nameField:addEventListener( "userInput", onNameFieldInput )
    sceneGroup.nameField = nameField
    nameField.isVisible = false 
    
    yPos = yPos + 80
    local colorLabel = display.newText( colorPanel, "Виберіть колір:", 0, yPos, native.systemFont, 36 )
    colorLabel.anchorX = 0; colorLabel.x = -colorPanelBG.width/2 + 30
    
    yPos = yPos + 100

    for i = 1, #colors do
        local colorButton = display.newRect( colorPanel, 0, 0, colorButtonSize, colorButtonSize )
        colorButton:setFillColor( colors[i][1], colors[i][2], colors[i][3] )
        colorButton.rawColor = colors[i] -- ВАЖЛИВО: зберігаємо RGB тут
        
        local row = math.floor((i - 1) / 3) 
        local col = (i - 1) % 3 
        colorButton.x = colorStartX + col * (colorButtonSize + colorButtonPadding)
        colorButton.y = yPos + row * (colorButtonSize + colorButtonPadding) 
        colorButton.colorIndex = i

        local cross = display.newText( colorPanel, "X", colorButton.x, colorButton.y, native.systemFontBold, colorButtonSize * 0.8 )
        cross:setFillColor( 0.2, 0.2, 0.2, 0.8 ); cross.isVisible = false 
        colorButton.cross = cross 

        local checkmark = display.newText( colorPanel, "✔", colorButton.x, colorButton.y, native.systemFontBold, colorButtonSize * 0.7 )
        checkmark:setFillColor( 1, 1, 1 ); checkmark.isVisible = false
        colorButton.checkmark = checkmark 

        colorButton:addEventListener( "tap", onColorSelected )
        table.insert( colorButtonTable, colorButton )
    end
    
    local doneButton = display.newText( colorPanel, "Готово", 0, colorPanelBG.height/2 - 70, native.systemFontBold, 48 )
    doneButton:addEventListener( "tap", onDoneButtonTap )
    sceneGroup.doneButton = doneButton 
    
    colorPanel.alpha = 0; colorPanel.isVisible = false

    local initialAddButton = createAddButton( startX, startY )
    initialAddButton:addEventListener( "tap", onAddButtonTap )
end

function scene:hide( event )
    local sceneGroup = self.view
    if event.phase == "will" then
        -- Обов'язково ховаємо нативне поле
        if sceneGroup.nameField then sceneGroup.nameField.isVisible = false end
    end
end

function scene:destroy( event )
    local sceneGroup = self.view
    for i = 1,#sceneGroup.textures do
        sceneGroup.textures[i]:releaseSelf()
    end
    if sceneGroup.nameField then
        sceneGroup.nameField:removeSelf()
        sceneGroup.nameField = nil
    end
    players = {}; usedColors = {}; colorButtonTable = {}
end

scene:addEventListener( "create", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene