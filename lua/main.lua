-- a Client is used to connect this app to a Place. arg[2] is the URL of the place to
-- connect to, which Assist sets up for you.
local client = Client(
    arg[2], 
    "enlighten"
)

-- App manages the Client connection for you, and manages the lifetime of the
-- your app.
local app = App(client)

-- Assets are files (images, glb models, videos, sounds, etc...) that you want to use
-- in your app. They need to be published so that user's headsets can download them
-- before you can use them. We make `assets` global so you can use it throughout your app.
assets = {
    quit = ui.Asset.File("images/quit.png"),
}
app.assetManager:add(assets)

-- mainView is the main UI for your app. Set it up before connecting.
-- 0, 1.2, -2 means: put the app centered horizontally; 1.2 meters up from the floor; and 2 meters into the room, depth-wise
-- 1, 0.5, 0.01 means 1 meter wide, 0.5 meters tall, and 1 cm deep.
-- It's a surface, so the depth should be close to zero.
local mainView = ui.Surface(ui.Bounds(0, 0.5, -2,   3, 0.5, 0.01))

-- Make it so that the grab button or right mouse button moves lets user move the view.
-- Instead of making mainView grabbable, you could also create a ui.GrabHandle and add it
-- as a subview, sort of like a title bar of a desktop window.
mainView.grabbable = true

-- It's nice to provide a way to quit the app, too.
-- Here's also an alternative syntax for setting the size and position of something.
local quitButton = ui.Button(ui.Bounds{size=ui.Size(0.12,0.12,0.05)}:move( mainView.bounds.size.width/2, mainView.bounds.size.height/2, 0))
-- Use our quit texture file as the image for this button.
quitButton:setDefaultTexture(assets.quit)
quitButton.onActivated = function()
    app:quit()
end
mainView:addSubview(quitButton)

class.Environment(View)
function Environment:_init(bounds)
    bounds = bounds or Bounds(0,0,0,10,10,10)
    self:super(bounds)
    self.effectCube = Cube(Bounds({size = self.bounds.size:copy(), pose = Pose()}))
    self.effectCube:setColor({1, 1, 1, 0.1})
    self.bounds.size = self.effectCube.bounds.size
    -- self.effectCube.hasCollider = true

    self.ambientLight = {0, 0, 0}
    self.skybox = nil
    -- self:addSubview(self.effectCube)
end

function Environment:specification()
    local spec = View.specification(self)
    spec.environment = {
        ambient = {
            light = {
                color = self.ambientLight
            }
        }
    }
    if self.skybox then
        spec.environment.skybox = self.skybox
    end
    return spec
end

local env = Environment()

local applySettings = nil


function slider(text, x, y, parent, func, min, max)
    local margin = 0.1
    local parentWidth = parent.bounds.size.width - margin * 2
    local labelWidth = parentWidth * 0.3 - margin
    local sliderWidth = parentWidth - labelWidth - margin

    local v = View(Bounds(
        x, y, -0.1,
        parentWidth, 0.13, 0.01
    ))
    local l = Label(Bounds(
        -parentWidth / 2 + labelWidth / 2, 0, 0.01,
        labelWidth, v.bounds.size.height, v.bounds.size.depth
    ))
    l:setHalign("right")

    l:setText(text)

    local s = Slider(Bounds(
        -parentWidth / 2 + labelWidth + sliderWidth / 2 + margin, 0, 0.01,
        sliderWidth, v.bounds.size.height, v.bounds.size.depth
    ))

    s.onValueChanged = function (sender, value)
        func(value, v)
    end
    s:minValue(min or 0)
    s:maxValue(max or 1)
    v:addSubview(s)
    v:addSubview(l)
    parent:addSubview(v)
    s.knob:setColor({0.1, 0.1, 0.7, 1})
    v.label = l
    v.slider = s
    s.knob.customSpecAttributes = {
        material = {
            metalness = 0,
            roughness = 1
        }
    }
    s.track.customSpecAttributes = {
        material = {
            metalness = 0.6,
            roughness = 0.6
        }
    }
    pretty.dump(s.knob:specification())
    return v, s, l
end

local stack = StackView({pose=Pose(0,0,0.01), size=mainView.bounds.size:copy()})

-- Skyboxes
local skyboxes = {
    sunset = {
        left = ui.Asset.File('images/skybox/sunset/left.png'),
        right = ui.Asset.File('images/skybox/sunset/right.png'),
        top = ui.Asset.File('images/skybox/sunset/top.png'),
        bottom = ui.Asset.File('images/skybox/sunset/bottom.png'),
        back = ui.Asset.File('images/skybox/sunset/back.png'),
        front = ui.Asset.File('images/skybox/sunset/front.png'),
    },
    sakura = {
        left = ui.Asset.File('images/skybox/sakura/left.png'),
        right = ui.Asset.File('images/skybox/sakura/right.png'),
        top = ui.Asset.File('images/skybox/sakura/top.png'),
        bottom = ui.Asset.File('images/skybox/sakura/bottom.png'),
        back = ui.Asset.File('images/skybox/sakura/back.png'),
        front = ui.Asset.File('images/skybox/sakura/front.png'),
    },
    blueishnight = {
      left = ui.Asset.File('images/skybox/blueish-night/left.png'),
      right = ui.Asset.File('images/skybox/blueish-night/right.png'),
      top = ui.Asset.File('images/skybox/blueish-night/top.png'),
      bottom = ui.Asset.File('images/skybox/blueish-night/bottom.png'),
      back = ui.Asset.File('images/skybox/blueish-night/back.png'),
      front = ui.Asset.File('images/skybox/blueish-night/front.png'),
    },
    daylight = {
        left = ui.Asset.File('images/skybox/daylight/left.png'),
        right = ui.Asset.File('images/skybox/daylight/right.png'),
        top = ui.Asset.File('images/skybox/daylight/top.png'),
        bottom = ui.Asset.File('images/skybox/daylight/bottom.png'),
        back = ui.Asset.File('images/skybox/daylight/back.png'),
        front = ui.Asset.File('images/skybox/daylight/front.png'),
    }
}
app.assetManager:add(skyboxes.sunset, true)
app.assetManager:add(skyboxes.sakura, true)
app.assetManager:add(skyboxes.blueishnight, true)
app.assetManager:add(skyboxes.daylight, true)

local skystack = StackView(Bounds(0,0,0, 0.2, 0.5, 0), "h")


local function skyboxButton(name)
    local button = ui.Button(Bounds(0,0,0, 0.5,0.5,0.1))

    local buttonLabel = Label{bounds=Bounds(0, -0.25, 0.101, 0.4, 0.1, 0.001), color={1.0,1.0,1.0,1}, text=name, halign="center", valign="bottom", fitToWidth=0.4}
    button:addSubview(buttonLabel)

    button:setTexture(skyboxes[name].front)
    --button.label:setText(name)
    button.onActivated = function ()
        local box = {}
        for side,asset in pairs(skyboxes[name]) do
            box[side] = asset:id()
        end
        env.skybox = box
        env:updateComponents()
    end
    return button
end

skystack:addSubview(skyboxButton("sunset"))
skystack:addSubview(skyboxButton("sakura"))
skystack:addSubview(skyboxButton("blueishnight"))
skystack:addSubview(skyboxButton("daylight"))
skystack:layout()
stack:addSubview(skystack)

stack:addSubview(Label({
    bounds = Bounds(0,0,0, 0,0.1,0),
    text = "Ambient Light Color",
    halign = "right",
}))
local r, g, b
local max = 1
slider("RGB", 0, 0, stack, function(value, v)
    for i, slider in ipairs({r.slider, g.slider, b.slider}) do
        slider:currentValue(value)
    end
    applySettings()
end, 0, max)
r = slider("Red", 0, 0, stack, function (value, v)
    v.slider.track:setColor({value/v.slider:maxValue(), 0, 0, 1})
    applySettings()
end, 0, max)
g = slider("Green", 0, 0, stack, function (value, v)
    v.slider.track:setColor({0, value/v.slider:maxValue(), 0, 1})
    applySettings()
end, 0, max)
b = slider("Blue", 0, 0, stack, function (value, v)
    v.slider.track:setColor({0, 0, value/v.slider:maxValue(), 1})
    applySettings()
end, 0, max)

local button = Button()
button.label:setText("Apply")
button.onActivated = function ()
    
end
stack:addSubview(button)

stack:layout()
mainView.bounds.pose:move(0, -(mainView.bounds.size.height - stack.bounds.size.height) / 2, 0)
mainView.bounds.size.height = stack.bounds.size.height
mainView:addSubview(stack)
mainView:addSubview(env)

-- Tell the app that mainView is the primary UI for this app
app.mainView = mainView

applySettings = function()
    local color = { r.slider:currentValue(), g.slider:currentValue(), b.slider:currentValue() }
    env.ambientLight = color
    r.slider.track:setColor({color[1], 0, 0})
    g.slider.track:setColor({0, color[2], 0})
    b.slider.track:setColor({0, 0, color[3]})
    env:updateComponents()
end

button.onActivated()

-- Connect to the designated remote Place server
app:connect()
-- hand over runtime to the app! App will now run forever,
-- or until the app is shut down (ctrl-C or exit button pressed).
app:run()
