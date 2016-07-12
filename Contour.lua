--[[-----------------------------Contour library----------------------------
Author: Nikolay Yevstakhov aka N1cke
License: MIT
Contour API:
◘ Contour.trace(render, [alpha])
	creates contour from render by detecting pixels with matched alpha
	'render' is RenderTarget instance
	'alpha' is minimal alpha value to detect contour, 0..255, [default: 128]
	returns contour as list of points where each point is in {x, y} format
◘ Contour.clean(contour, [dist])
	reduces number of contour points by removing close ones
	'contour' is list of points where each point is in {x, y} format
	'dist' is maximal distance to detect redundant points, 0.., [default: 1]
	returns cleaned contour
◘ Contour.shape(contour, [size])
	converts contour into convex shapes suitable for Box2D
	'contour' is list of points where each point is in {x, y} format
	'size' is maximal number of shape vertices, 3..8, [default: 8]
	returns list of shapes where each shape is list of {x, y} points
◘ Contour.apply(body, shapes, fixdef)
	applies shapes and Box2D fixture definition to Box2D body
	'body' is Box2D body
	'shapes' list of shapes where each shape is list of {x, y} points
	'fixdef' is fixture definition table (see b2.Body.createFixture)
	returns nil since it modifies Box2D body
◘ Contour.path(contour)
	creates svg path from contour to use with Path2D.setSvgPath
	'contour' is list of points where each point is in {x, y} format
	returns string
◘ Contour.save(contour, filename)
	saves contour to file with json format
	'contour' is list of points where each point is in {x, y} format
	'filename' is full filename
	returns nil since it performs file write operation
◘ Contour.load(filename)
	loads contour from file with json format
	'filename' is full filename
	returns contour as list of points where each point is in {x, y} format
◘ Contour.print(contour|shapes)
	prints contour or shapes in json format
	returns nil
--]]------------------------------------------------------------------------

Contour = {}

function Contour.trace(render, alpha)
	local contour = {}
	
	alpha = alpha or 128
	local w, h = render:getWidth(), render:getHeight()
	local pixels = render:getPixels(1, 1, w, h)
	
	local data = {}
	for x = 2, w-1 do
		local col = {}
		local off = 4 * (x - w)
		local mul = 4 * w
		for y = 2, h-1 do
			local i = off + y * mul
			col[y] = pixels:byte(i) < alpha
		end
		data[x] = col
	end
	
	data[1] = {}
	data[w] = {}
	for y = 1, h do data[1][y], data[w][y] = true, true end
	for x = 2, w-1 do data[x][1], data[x][h] = true, true end
	
	local x0, y0 = nil, nil
	for x = 1, w do
		if x0 then break end
		local col = data[x]
		for y = 1, h do
			if not col[y] then x0, y0 = x-1, y; break end
		end
	end
	
	if not x0 then return {{1, 1}, {w, 1}, {w, h}, {1, h}} end
	
	local dx = {0, 1, 1, 1, 0, -1, -1, -1}
	local dy = {-1, -1, 0, 1, 1, 1, 0, -1}
	local isOdd = {true, false, true, false, true, false, true, false}
	local nDir = {8, 1, 2, 3, 4, 5, 6, 7}
	local pDir = {2, 3, 4, 5, 6, 7, 8, 1}
	
	contour[1] = {x0, y0}
	local x, y, d, pd, l = x0+1, y0-1, 2, 0, 1
	while x ~= x0 or y ~= y0 do
		d = d < 7 and d + 2 or d - 6
		for i = 1, 8 do
			local tx, ty = x + dx[d], y + dy[d]
			if data[tx][ty] then
				local n, p = nDir[d], pDir[d]
				if isOdd[d] or data[x+dx[n]][y+dy[n]]
				or data[x+dx[p]][y+dy[p]] then
					if d ~= pd then l = l + 1; pd = d end
					contour[l] = {x, y}
					x, y = tx, ty
					break
				end
			end
			d = d > 1 and d - 1 or 8
		end
	end
	
	return contour
end

local function pointsAreClose(pt1, pt2, distSqrd)
	return (pt1[1] - pt2[1]) ^ 2 + (pt1[2] - pt2[2]) ^ 2 <= distSqrd
end

local function closestPointOnLine(pt, linePt1, linePt2)
	local dx, dy = linePt2[1] - linePt1[1], linePt2[2] - linePt1[2]
	if dx == 0 and dy == 0 then return {linePt1[1], linePt1[2]} end
	local q = ((pt[1]-linePt1[1])*dx + (pt[2]-linePt1[2])*dy) / (dx*dx + dy*dy)
	return {(1-q)*linePt1[1] + q*linePt2[1], (1-q)*linePt1[2] + q*linePt2[2]}
end

local function slopesNearColinear(pt1, pt2, pt3, distSqrd)
	local d1 = (pt1[1] - pt2[1]) ^ 2 + (pt1[2] - pt2[2]) ^ 2
	local d2 = (pt1[1] - pt3[1]) ^ 2 + (pt1[2] - pt3[2]) ^ 2
	if d1 > d2 then return false end
	local cpol = closestPointOnLine(pt2, pt1, pt3)
	return (pt2[1] - cpol[1]) ^ 2 +  (pt2[2] - cpol[2]) ^ 2 < distSqrd
end

function Contour.clean(con, dist)
	dist = dist or 1
	local out = {}
	local l = #con
	local distSqrd = dist * dist
	
	while l > 1 and pointsAreClose(con[l], con[1], distSqrd) do
		l = l - 1
	end
	
	if l < 3 then return {} end
	
	local pt = con[l]
	local i, k = 1, 1
	
	while true do
		while i < l and pointsAreClose(pt, con[i+1], distSqrd) do
			i = i + 2
		end
		local i2 = i
		while i < l and (pointsAreClose(con[i], con[i+1], distSqrd)
		or slopesNearColinear(pt, con[i], con[i+1], distSqrd)) do
			i = i + 1
		end
		if i >= l then
			break
		elseif i == i2 then
			pt = con[i]
			out[k] = pt
			i, k = i + 1, k + 1
		end
	end
	
	if i <= l then out[k] = con[i]; k = k + 1 end
	if k > 2 and slopesNearColinear(out[k-2], out[k-1],
	out[1], distSqrd) then k = k - 1 end    
	if k <= l then
		for n = k, #out do out[n] = nil end 
	end
	return out
end

local function area(a, b, c)
	return (b[1] - a[1]) * (c[2] - a[2]) -
		(b[2] - a[2]) * (c[1] - a[1])
end 

local function isSegCross(a, b, c, d)
	return area(a, b, c) * area(a, b, d) < 0 and
		area(c, d, a) * area(c, d, b) < 0
end

local function isSamePoint(a, b)
	return a[1] == b[1] and a[2] == b[2]
end

local function checkIntegrity(con)
	local errors = {}
	local l = #con
	
	if l < 3 then error("contour has less than 3 vertices", 3) end
	
	for i = 1, l - 1 do
		for j = i + 1, l do
			if isSamePoint(con[i], con[j]) then
				errors[#errors+1] = {i, j}
			end
		end
	end
	
	for i = 1, l - 3 do
		for j = i + 2, l do
			if isSegCross(con[i], con[i+1], con[j], con[j+1]) then
				errors[#errors+1] = {i, i + 1, j, j + 1}
			end
		end
	end
	
	if #errors > 0 then
		local list = require"json".encode(errors)
		error("contour has intersections:\n"..list, 3)
	end
end


local function isClockwise(con)
	local n2 = 1
	for i = 2, #con do
		if con[n2][1] > con[i][1] then n2 = i end
	end

	local n1 = n2 - 1
	local w1 = con[n1][1] - con[n2][1]
	local h1 = con[n1][2] - con[n2][2]
	
	local n3 = n2 + 1
	local w3 = con[n3][1] - con[n2][1]
	local h3 = con[n3][2] - con[n2][2]
	
	if w3 == 0 then
		return h3 < 0
	elseif w1 == 0 then
		return h1 >= 0
	else
		return h3/w3 < h1/w1
	end
end

local function isConcave(a, b, c)
	return (c[1] - a[1]) * (b[2] - a[2]) > (c[2] - a[2]) * (b[1] - a[1])
end

local function getConcavesNum(con)
	local n = 0
	for i = 1, #con do
		if con[i][3] then n = n + 1 end
	end
	return n
end

local function isSkew(con, p1, p2)
	local l = #con
	if math.abs(p1 - p2) < 2 then return false end
	if p1 == l and p2 == 1 or p2 == l and p1 == 1 then return false end
	for i = 1, l do
		if isSegCross(con[i], con[i+1], con[p1], con[p2]) then
			return false
		end
	end
	return true
end

local function isInside(con, p1, p2)
  return isConcave(con[p1+1], con[p1], con[p2]) or
	not isConcave(con[p1-1], con[p1], con[p2])
end

local function ringify(con)
	local l = #con
	con.__index = function(t, i) return t[i%l ~= 0 and i%l or l] end
	setmetatable(con, con)
end

local function split(con, p1, p2)
	if p1 > p2 then p1, p2 = p2, p1 end
	
	local con1 = {}
	for i = p1, p2 do con1[i+1-p1] = {con[i][1], con[i][2]} end
	ringify(con1)
	for i = 1, #con1 do
		con1[i][3] = isConcave(con1[i-1], con1[i], con1[i+1])
	end
	
	local con2 = {}
	for i = 1, p1 do con2[i] = {con[i][1], con[i][2]} end
	for i = p2, #con do con2[i-p2+1+p1] = {con[i][1], con[i][2]} end
	ringify(con2)
	for i = 1, #con2 do
		con2[i][3] = isConcave(con2[i-1], con2[i], con2[i+1])
	end
	
	return con1, con2
end

local function getSplitPoints(con)
	local point1, point2
	
	local l, k0 = #con, math.huge
	
	for p1 = 1, l do
		for p2 = 1, l do
			if con[p1][3] and isInside(con, p1, p2) and isSkew(con, p1, p2) then
				local k = (con[p1][1] - con[p2][1])^2 + (con[p1][2] - con[p2][2])^2
				if k < k0 then point1, point2, k0 = p1, p2, k end
			end
		end
	end
	
	return point1, point2
end

function Contour.shape(contour, size)
	size = size or 8
	local l = #contour
	
	local con = {}
	for i = 1, l do con[i] = {contour[i][1], contour[i][2]} end
	ringify(con)
	
	checkIntegrity(con)
	
	if not isClockwise(con) then
		for i = 1, l/2 do con[i], con[l+1-i] = con[l+1-i], con[i] end
	end
	
	for i = 1, l do con[i][3] = isConcave(con[i-1], con[i], con[i+1]) end
	
	local shapes = {}
	local cons = {con}
	
	while #cons > 0 do
		local con = cons[#cons]
		local l = #cons
		if getConcavesNum(con) > 0 then
			local p1, p2 = getSplitPoints(con)
			cons[l+1], cons[l] = split(con, p1, p2)
		elseif #con > size then
			local p1, p2 = 1, math.max(3, math.ceil(#con / 2))
			cons[l+1], cons[l] = split(con, p1, p2)
		else
			con.__index = nil
			for i,point in ipairs(con) do point[3] = nil end
			shapes[#shapes+1] = Contour.clean(con, 1e-100)
			cons[#cons] = nil
		end
	end
	
	return shapes
end

function Contour.apply(body, shapes, fixdef)
	fixdef.shape = b2.PolygonShape.new()
	for i, shape in ipairs(shapes) do
		local t = {}
		for k, point in ipairs(shape) do
			t[#t+1] = point[1]
			t[#t+1] = point[2]
		end
		fixdef.shape:set(unpack(t))
		body:createFixture(fixdef)
	end
end

function Contour.path(contour)
	local t = {}
	t[#t+1] = "M "..contour[1][1].." "..contour[1][2]
	for i, p in ipairs(contour) do
		t[#t+1] = "L "
		t[#t+1] = p[1]
		t[#t+1] = p[2]
	end
	t[#t+1] = "Z"
	return table.concat(t, " ")
end

function Contour.save(contour, filename)
	local data = require"json".encode(contour)
	local file, err = io.open(filename, "wb")
	if err then error(err, 2) end
	file:write(data)
	file:close()
end

function Contour.load(filename)
	local file, err = io.open(filename, "rb")
	if err then error(err, 2) end
	local data = file:read("*a")
	file:close()
	return require"json".decode(data)
end

function Contour.print(contour)
	print(require"json".encode(contour):gsub("%[%[", "\n[[").."\n")
end
