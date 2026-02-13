-- src/scenes/test_load_scene.lua
local composer = require("composer")
local scene = composer.newScene()
local widget = require("widget")

local inputFields = {}

-- Дефолтні параметри
local defaultParams = {
    width = "300",
    height = "300",
    seed = tostring(os.time()),
    scale = "80",
    octaves = "8",
    seaLevel = "-0.3",
    riverCount = "40",
    landPercent = "80"
}

-- Динамічні розміри шрифтів та відступи
local W, H = display.contentWidth, display.contentHeight
local FONT_SIZE = H * 0.025 -- Шрифт залежить від висоти екрану
local ROW_HEIGHT = H * 0.08 -- Висота одного рядка налаштувань

local function createInput(group, labelText, key, index, defaultValue)
    local yPos = H * 0.15 + (index * ROW_HEIGHT)
    
    -- Підпис (Зліва)
    local lbl = display.newText({
        parent = group,
        text = labelText,
        x = W * 0.45, -- Закінчується на 45% ширини
        y = yPos,
        font = native.systemFontBold,
        fontSize = FONT_SIZE
    })
    lbl.anchorX = 1 -- Вирівнювання по правому краю
    lbl:setFillColor(0.9, 0.9, 0.9)

    -- Поле вводу (Справа)
    local input = native.newTextField(
        W * 0.55, -- Починається з 55% ширини
        yPos, 
        W * 0.35, -- Ширина поля 35% екрану
        ROW_HEIGHT * 0.6 -- Висота поля
    )
    input.anchorX = 0 -- Вирівнювання по лівому краю
    input.text = defaultValue
    input.inputType = "default"
    
    -- Для цифр краще використати цифрову клавіатуру, але для seed потрібен текст
    if key ~= "seed" then input.inputType = "decimal" end
    
    input.id = key
    input.font = native.newFont(native.systemFont, FONT_SIZE)
    
    table.insert(inputFields, input)
    return input
end

function scene:create(event)
    local sceneGroup = self.view
    
    -- Фон
    local bg = display.newRect(sceneGroup, W/2, H/2, W, H)
    bg:setFillColor(0.15, 0.15, 0.2) -- Темно-синій фон

    -- Заголовок
    local title = display.newText({
        parent = sceneGroup,
        text = "World Generator Config",
        x = W/2,
        y = H * 0.08,
        font = native.systemFontBold,
        fontSize = FONT_SIZE * 1.5
    })
    title:setFillColor(1, 0.8, 0)
end

function scene:show(event)
    if event.phase == "did" then
        -- Створюємо поля
        createInput(self.view, "Width:", "width", 0, defaultParams.width)
        createInput(self.view, "Height:", "height", 1, defaultParams.height)
        createInput(self.view, "Seed:", "seed", 2, defaultParams.seed)
        createInput(self.view, "Scale (Zoom):", "scale", 3, defaultParams.scale)
        createInput(self.view, "Octaves:", "octaves", 4, defaultParams.octaves)
        createInput(self.view, "Sea Level (0-1):", "seaLevel", 5, defaultParams.seaLevel)
        createInput(self.view, "Rivers:", "riverCount", 6, defaultParams.riverCount)
        createInput(self.view, "Land Size (%):", "landPercent", 7, defaultParams.landPercent)
        
        -- Велика кнопка GENERATE
        local btnHeight = H * 0.1
        local btn = widget.newButton({
            label = "GENERATE WORLD",
            x = W/2,
            y = H - btnHeight,
            shape = "roundedRect",
            width = W * 0.8,
            height = btnHeight,
            cornerRadius = 15,
            fontSize = FONT_SIZE * 1.2,
            fillColor = { default={0, 0.6, 0}, over={0, 0.4, 0} },
            labelColor = { default={1,1,1}, over={0.8,0.8,0.8} },
            onRelease = function()
                local params = {}
                for i, field in ipairs(inputFields) do
                    if field.id == "seed" then
                        params[field.id] = tonumber(field.text) or os.time()
                    else
                        params[field.id] = tonumber(field.text)
                    end
                end
                params.enableOcean = true
                params.enableRivers = true
                params.persistence = 0.5

                composer.gotoScene("src.scenes.loading", { params = { params = params } })
            end
        })
        self.view:insert(btn)
    end
end

function scene:hide(event)
    if event.phase == "will" then
        for i, field in ipairs(inputFields) do
            field:removeSelf()
        end
        inputFields = {}
    end
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)

return scene