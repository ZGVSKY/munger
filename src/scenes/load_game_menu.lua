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

    local assest_to_load = {'background.jpg', 'logo.png'}
    local loaded_assets = {}

    -- for each object from the assest_to_load list , we create an object of texture type and preload it
    for i=1,#assest_to_load do
        loaded_assets[i] = graphics.newTexture( {
            type = "image",
            filename = assets_path .. assest_to_load[i],
            baseDir = system.ResourceDirectory
        } )
        loaded_assets[i]:preload()
    end
    sceneGroup.textures = loaded_assets -- adding all textures to scene group
    
    -----------------------------------------------------------------------

    -- build the scene

    -- create objects
    local background = display.newImageRect( sceneGroup.textures[1].filename, sceneGroup.textures[1].baseDir, screen_width, screen_height )
    local logo = display.newImageRect( sceneGroup.textures[2].filename, sceneGroup.textures[1].baseDir, 338*2, 56*2 )

    -- setup objects position and parametrs 
    background.x = screen_width/2; background.y = screen_height/2
    logo.x = screen_width/2; logo.y = screen_height*0.15

    -----------------------------------------------------------------------

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
