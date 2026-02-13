--[[---------------------------------------------------------------------------------------
   main file created at 06.11.25 by zgvsk
   Using to start a main menu scene and setup global settings of the project
   loads and initializes user settings for subsequent startup
-------------------------------------------------------------------------------------------]]

-- load user settings
-- TODO:

-- load user data 
-- TODO:

-- setup global aplication settings


display.setStatusBar(display.HiddenStatusBar)                   -- hide status bar (top panel) on android devices
native.setProperty( "androidSystemUiVisibility", "immersive" )  -- hide navigation (bottom panel) bar on android devices 
system.activate( "multitouch" )                                 -- activate multitouch
local widget = require("widget")
widget.setTheme("widget_theme_android_holo_dark")               -- switch widgets on dark theme

composer = require( "composer" )                                -- create a composer object used to control scenes
composer.recycleOnSceneChange = true                            -- enable auto-recycle on scene change
composer.isDebug = true                                         -- enable composer debug info
math.randomseed(os.time())                                      -- setup global random seed
-- go to main menu scene


--composer.gotoScene( "src.scenes.create_game_menu" )                        -- moves to the main scene
composer.gotoScene( "src.scenes.test_load_scene" )