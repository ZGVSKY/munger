-----------------------------------------------------------------------------------------
-- default placeholder
-----------------------------------------------------------------------------------------

-- import requirements
composer = require( "composer" )
scene = composer.newScene()
widget = require "widget"

-- global enviroments
assets_path = 'src/assets/menu/'
screen_width = display.actualContentWidth
screen_height = display.actualContentHeight


function scene:create( event )
    -- Called when the scene is created

    local sceneGroup = self.view
    local phase = event.phase

    -- preload assets as a textures

    local assest_to_load = {
        'background (1).png',    
        'logo.png',          
        'Rectangle1.png',  
        'Players.png', 
        'Line1.png',         
        'Line2.png',         
        'player.png',        
        'addnew.png'         
    }
    
    local loaded_assets = {}

   for i=1,#assest_to_load do
        loaded_assets[i] = graphics.newTexture( {
            type = "image",
            filename = assets_path .. assest_to_load[i],
            baseDir = system.ResourceDirectory
        } )
        loaded_assets[i]:preload()

        if loaded_assets[i] == nil then
            print( " Немає: " .. imagePath )

        else
            loaded_assets[i]:preload()
        end

        
    end
    sceneGroup.textures = loaded_assets
        
    local background = display.newImageRect( sceneGroup, sceneGroup.textures[1].filename, sceneGroup.textures[1].baseDir, screen_width, screen_height )
    local logo = display.newImageRect( sceneGroup, sceneGroup.textures[2].filename, sceneGroup.textures[2].baseDir, 338*2, 56*2 )
    -- розмір панелі
    local panel_width = screen_width * 0.85
    local panel_height = screen_height * 0.65

    local panel = display.newImageRect( sceneGroup, sceneGroup.textures[3].filename, sceneGroup.textures[3].baseDir, panel_width, panel_height )
    local playersText = display.newImageRect( sceneGroup, sceneGroup.textures[4].filename, sceneGroup.textures[4].baseDir, 152*2, 43*2 )
    local line1 = display.newImageRect( sceneGroup, sceneGroup.textures[5].filename, sceneGroup.textures[5].baseDir, 442*2, 23*2 )
    local line2 = display.newImageRect( sceneGroup, sceneGroup.textures[6].filename, sceneGroup.textures[6].baseDir, 442*2, 23*2 )
    local addButton = display.newImageRect( sceneGroup, sceneGroup.textures[8].filename, sceneGroup.textures[8].baseDir, 89*2, 60*2 )



    background.x = screen_width / 2
    background.y = screen_height / 2

    logo.x = screen_width / 2
    logo.y = screen_height * 0.15

    panel.x = screen_width / 2
    panel.y = screen_height * 0.55

    playersText.x = screen_width / 2
    playersText.y = panel.y - (panel_height * 0.1)

    line1.x = screen_width / 2
    line1.y = playersText.y + 70

    line2.x = screen_width / 2
    line2.y = panel.y + (panel_height * 0.25)

    addButton.x = (screen_width / 2) - 330
    addButton.y =  panel.y + (panel_height * 0.30)

    
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
end

---------------------------------------------------------------------------------

-- Listener setup
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

-----------------------------------------------------------------------------------------

return scene
