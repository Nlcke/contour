local texture = Texture.new "image.png"
local w, h = texture:getWidth(), texture:getHeight()
local image = Bitmap.new(texture)
local render = RenderTarget.new(w, h)
render:draw(image)
local bitmap = Bitmap.new(render)
stage:addChild(bitmap)

print "image loaded"

local contour = Contour.trace(render)
print "contour after trace:"
Contour.print(contour)

contour = Contour.clean(contour)
print "contour after clean:"
Contour.print(contour)

local path = Contour.path(contour)
print "contour as path:\n"
print(path)
print "\n"
local path2d = Path2D.new()
path2d:setSvgPath(path)
stage:addChild(path2d)

Contour.save(shapes, "|D|contour.json")
print "contour saved to '|D|contour.json'\n"

shapes = Contour.load("|D|contour.json")
print "contour loaded from '|D|contour.json'\n"

local shapes = Contour.shape(contour)
print "shapes created from contour:"
Contour.print(shapes)

require "box2d"
local world = b2.World.new(0, 9.8, true)
local function createBox(world, w, h)
	for k,v in ipairs{{0,0;w,0}, {w,0;w,h}, {0,h;w,h}, {0,h;0,0}} do
		local body = world:createBody{}
		local shape = b2.EdgeShape.new()
		shape:set(v[1], v[2], v[3], v[4])
		body:createFixture{shape = shape}
	end
end
createBox(world, application:getDeviceWidth(), application:getDeviceHeight())
local body = world:createBody{type = b2.DYNAMIC_BODY}
Contour.apply(body, shapes, {density = 10, restitution = 1, friction = 0.3})
body:setPosition(application:getDeviceWidth()/2, 0)
stage:addEventListener(Event.ENTER_FRAME, function()
	world:step(1/60, 8, 3)
	bitmap:setPosition(body:getPosition())
	bitmap:setRotation(body:getAngle() * 180 / math.pi)
end)

print "Jumping started!"