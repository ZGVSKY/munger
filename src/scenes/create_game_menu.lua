-- import requirements
composer = require( "composer" )
scene = composer.newScene()
widget = require "widget"

-- global enviroments
assets_path = 'src/assets/menu/'
screen_width = display.actualContentWidth
screen_height = display.actualContentHeight

local players = {}
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
    -- щоб легше зробити розміри
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

    -- початкові координати плюса
    local startX = (screen_width / 2) - 330
    local startY = panel.y + (panel_height * 0.30)
    
    -- розміри і відступи іконок
    local iconWidth = 89*2
    local iconHeight = 60*2
    local padding = 40 
    local verticalPadding = 20 
    
    
    -- Створює іконку гравця 
    local function createPlayerIcon( xPos, yPos )
        local icon = display.newImageRect( sceneGroup, sceneGroup.textures[7].filename, sceneGroup.textures[7].baseDir, iconWidth, iconHeight )
        icon.x = xPos
        icon.y = yPos
        table.insert(players, icon) -- додає іконку в список
        print("Створено іконку гравця. Всього гравців: " .. #players)
        return icon
    end

    -- Створює кнопку "додати"
    local function createAddButton( xPos, yPos )
        local button = display.newImageRect( sceneGroup, sceneGroup.textures[8].filename, sceneGroup.textures[8].baseDir, iconWidth, iconHeight )
        button.x = xPos
        button.y = yPos
        return button
    end

    -- коли натискаємо кнопку викликається ця функція
    local function onAddButtonTap( event )
        local currentButton = event.target 

        if #players < maxPlayers then
            print("Додаємо нового гравця...")
            local newPlayerIcon = createPlayerIcon( currentButton.x, currentButton.y )
            
            -- Видаляємо кнопку плюс
            currentButton.isVisible = false
            currentButton:removeSelf()
            currentButton = nil

            -- Перевіряємо, чи потрібно створювати нову кнопку плюс
            if #players < maxPlayers then
                
                local nextButtonX
                local nextButtonY
                local currentPlayerCount = #players -- видає помилку якщо вказувати #players в if

                if (currentPlayerCount % playersPerRow == 0) then
                    print("Досягли " .. currentPlayerCount .. " гравців, переносимо кнопку 'плюс' на новий рядок.")
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
            
            print("Кількість гравців: " .. #players)

        else
        end
        return true
    end

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
end

---------------------------------------------------------------------------------

-- Listener setup
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

-----------------------------------------------------------------------------------------

return scene