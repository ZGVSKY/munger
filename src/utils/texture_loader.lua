texture_loader = {}
texture_loader.options = {
    Grass =
                    {
                        -- The params below are required
                        width = 16,
                        height = 16,
                        numFrames = 4,
                    
                        -- The params below are optional (used for dynamic image selection)
                        sheetContentWidth = 64,  -- width of original 1x size of entire sheet
                        sheetContentHeight = 16  -- height of original 1x size of entire sheet
                    },
    Coast =
                    {
                        -- The params below are required
                        width = 16,
                        height = 16,
                        numFrames = 9,
                    
                        -- The params below are optional (used for dynamic image selection)
                        sheetContentWidth = 48,  -- width of original 1x size of entire sheet
                        sheetContentHeight = 48  -- height of original 1x size of entire sheet
                    },
    DeepWater =
                    {
                        -- The params below are required
                        width = 16,
                        height = 16,
                        numFrames = 4,
                    
                        -- The params below are optional (used for dynamic image selection)
                        sheetContentWidth =32,  -- width of original 1x size of entire sheet
                        sheetContentHeight = 32  -- height of original 1x size of entire sheet
                    },
    STONE =
                    {
                        width = 13,
                        height = 13,
                        numFrames = 9,
                        sheetContentWidth = 39,  --width of original 1x size of entire sheet
                        sheetContentHeight = 39  --height of original 1x size of entire sheet
                    },
    STONERD =
                    {
                        width = 16,
                        height = 16,
                        numFrames = 4,
                        sheetContentWidth = 32,  --width of original 1x size of entire sheet
                        sheetContentHeight = 32  --height of original 1x size of entire sheet
                    },
    STONEUP =
                    {
                        width = 16,
                        height = 16,
                        numFrames = 4,
                    
                        -- The params below are optional (used for dynamic image selection)
                        sheetContentWidth = 64,  -- width of original 1x size of entire sheet
                        sheetContentHeight = 16  -- height of original 1x size of entire sheet
                    },
    
    Wood = {
                        width = 16,
                        height = 16,
                        numFrames = 9,
                    
                        -- The params below are optional (used for dynamic image selection)
                        sheetContentWidth = 48,  -- width of original 1x size of entire sheet
                        sheetContentHeight = 48  -- height of original 1x size of entire sheet
                    }
}

function texture_loader:load()

    local canvas = {}
    local assets_path = "src/assets/tailset/"
    print("--------->{TEXTURE_LOADER-INFO}: start texture preload, textures to load ->"..#texture_loader.options)

    canvas.GRASS        = graphics.newImageSheet(assets_path.."grass.png",            texture_loader.options.Grass)
    canvas.DeepWater    = graphics.newImageSheet(assets_path.."DeepWaterTileset.png", texture_loader.options.DeepWater)
    canvas.Coast        = graphics.newImageSheet(assets_path.."CoastT.png",           texture_loader.options.Coast)
    canvas.stoneSheet   = graphics.newImageSheet(assets_path.."stoneTileset.png",     texture_loader.options.STONE )
    canvas.stoneSheetRD = graphics.newImageSheet(assets_path.."StoneRD.png",          texture_loader.options.STONERD )
    canvas.stoneSheetUp = graphics.newImageSheet(assets_path.."stoneUP.png",          texture_loader.options.STONERD )
    canvas.wood         = graphics.newImageSheet(assets_path.."WoodTilesetT.png",     texture_loader.options.Wood )
    canvas.woodAndGrass = graphics.newImageSheet(assets_path.."WoodTileset.png",      texture_loader.options.Wood )

    print("--------->{TEXTURE_LOADER-INFO}: all "..#canvas.." textures loaded")
    return canvas
end
return texture_loader