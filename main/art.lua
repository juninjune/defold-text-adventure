-- Procedural 1-bit dithered illustrations (early-Macintosh adventure look).
-- Everything is painted at runtime into a small grayscale canvas, ordered-dithered
-- to two colours and uploaded as a gui texture. No image assets are involved.
--
-- Public API:
--   art.render(key, w, h) -> rgb byte string, tex_w, tex_h   (cached per key/size)
--   art.has(key)          -> true if the key can be rendered (used by story validation)
-- key = "<scene>" or "<scene>+<portrait>", e.g. "dining+han", or "clue:<clue id>"
-- (clue illustrations live in main/art_clues.lua and use the primitives exported as M.P).

local M = {}

M.SCALE = 2
M.INK = { 0x0c, 0x0e, 0x13 }
M.PAPER = { 0xd6, 0xd0, 0xbc }

local SCALE = M.SCALE

local BAYER = {
	{ 0, 32, 8, 40, 2, 34, 10, 42 },
	{ 48, 16, 56, 24, 50, 18, 58, 26 },
	{ 12, 44, 4, 36, 14, 46, 6, 38 },
	{ 60, 28, 52, 20, 62, 30, 54, 22 },
	{ 3, 35, 11, 43, 1, 33, 9, 41 },
	{ 51, 19, 59, 27, 49, 17, 57, 25 },
	{ 15, 47, 7, 39, 13, 45, 5, 37 },
	{ 63, 31, 55, 23, 61, 29, 53, 21 },
}

local floor = math.floor

-- deterministic 0..1 noise
local function rnd(x, y, seed)
	local n = (x * 73856093 + y * 19349663 + (seed or 7) * 83492791) % 2147483647
	n = (n * 16807) % 2147483647
	return (n % 10007) / 10007
end

------------------------------------------------------------
-- canvas primitives (values 0 = ink, 1 = paper)
------------------------------------------------------------

local function new_canvas(w, h, v)
	local c = { w = w, h = h }
	for i = 1, w * h do c[i] = v or 0 end
	return c
end

local function set(c, x, y, v)
	x, y = floor(x), floor(y)
	if x < 0 or y < 0 or x >= c.w or y >= c.h then return end
	c[y * c.w + x + 1] = v
end

local function get(c, x, y)
	x, y = floor(x), floor(y)
	if x < 0 or y < 0 or x >= c.w or y >= c.h then return 0 end
	return c[y * c.w + x + 1]
end

local function clamp(v) if v < 0 then return 0 elseif v > 1 then return 1 else return v end end

local function rect(c, x0, y0, x1, y1, v)
	x0, y0, x1, y1 = floor(x0), floor(y0), floor(x1), floor(y1)
	if x0 > x1 then x0, x1 = x1, x0 end
	if y0 > y1 then y0, y1 = y1, y0 end
	for y = math.max(y0, 0), math.min(y1, c.h - 1) do
		for x = math.max(x0, 0), math.min(x1, c.w - 1) do
			c[y * c.w + x + 1] = v
		end
	end
end

-- fn(x, y, old) -> new
local function rect_fn(c, x0, y0, x1, y1, fn)
	x0, y0, x1, y1 = floor(x0), floor(y0), floor(x1), floor(y1)
	for y = math.max(y0, 0), math.min(y1, c.h - 1) do
		for x = math.max(x0, 0), math.min(x1, c.w - 1) do
			local i = y * c.w + x + 1
			c[i] = fn(x, y, c[i])
		end
	end
end

local function vgrad(c, x0, y0, x1, y1, v_top, v_bottom)
	local span = math.max(1, y1 - y0)
	rect_fn(c, x0, y0, x1, y1, function(_, y)
		local t = (y - y0) / span
		return v_top + (v_bottom - v_top) * t
	end)
end

local function hgrad(c, x0, y0, x1, y1, v_left, v_right)
	local span = math.max(1, x1 - x0)
	rect_fn(c, x0, y0, x1, y1, function(x)
		local t = (x - x0) / span
		return v_left + (v_right - v_left) * t
	end)
end

local function grain(c, x0, y0, x1, y1, amp, seed)
	rect_fn(c, x0, y0, x1, y1, function(x, y, old)
		return clamp(old + (rnd(x, y, seed) - 0.5) * amp)
	end)
end

-- blend region toward fog value
local function fog(c, x0, y0, x1, y1, fog_v, amount)
	rect_fn(c, x0, y0, x1, y1, function(_, _, old)
		return old * (1 - amount) + fog_v * amount
	end)
end

local function ellipse(c, cx, cy, rx, ry, v)
	for y = floor(cy - ry), floor(cy + ry) do
		for x = floor(cx - rx), floor(cx + rx) do
			local dx, dy = (x - cx) / rx, (y - cy) / ry
			if dx * dx + dy * dy <= 1 then set(c, x, y, v) end
		end
	end
end

local function ellipse_fn(c, cx, cy, rx, ry, fn)
	for y = floor(cy - ry), floor(cy + ry) do
		for x = floor(cx - rx), floor(cx + rx) do
			local dx, dy = (x - cx) / rx, (y - cy) / ry
			if dx * dx + dy * dy <= 1 then set(c, x, y, fn(x, y, get(c, x, y))) end
		end
	end
end

local function disc(c, cx, cy, r, v) ellipse(c, cx, cy, r, r, v) end

local function ellipse_outline(c, cx, cy, rx, ry, v)
	local n = floor((rx + ry) * 3)
	for i = 0, n do
		local a = i / n * 2 * math.pi
		set(c, cx + rx * math.cos(a), cy + ry * math.sin(a), v)
	end
end

local function ring(c, cx, cy, r, v)
	for y = floor(cy - r), floor(cy + r) do
		for x = floor(cx - r), floor(cx + r) do
			local d = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
			if d <= r + 0.5 and d >= r - 0.6 then set(c, x, y, v) end
		end
	end
end

local function tri(c, x0, y0, x1, y1, x2, y2, v)
	local minx, maxx = floor(math.min(x0, x1, x2)), floor(math.max(x0, x1, x2))
	local miny, maxy = floor(math.min(y0, y1, y2)), floor(math.max(y0, y1, y2))
	local function side(px, py, ax, ay, bx, by)
		return (bx - ax) * (py - ay) - (by - ay) * (px - ax)
	end
	for y = miny, maxy do
		for x = minx, maxx do
			local px, py = x + 0.5, y + 0.5
			local d1 = side(px, py, x0, y0, x1, y1)
			local d2 = side(px, py, x1, y1, x2, y2)
			local d3 = side(px, py, x2, y2, x0, y0)
			local neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
			local pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
			if not (neg and pos) then set(c, x, y, v) end
		end
	end
end

local function line(c, x0, y0, x1, y1, v)
	x0, y0, x1, y1 = floor(x0), floor(y0), floor(x1), floor(y1)
	local dx, dy = math.abs(x1 - x0), -math.abs(y1 - y0)
	local sx, sy = (x0 < x1) and 1 or -1, (y0 < y1) and 1 or -1
	local err = dx + dy
	while true do
		set(c, x0, y0, v)
		if x0 == x1 and y0 == y1 then break end
		local e2 = 2 * err
		if e2 >= dy then err = err + dy; x0 = x0 + sx end
		if e2 <= dx then err = err + dx; y0 = y0 + sy end
	end
end

-- soft light source
local function glow(c, cx, cy, r, strength)
	rect_fn(c, cx - r, cy - r, cx + r, cy + r, function(x, y, old)
		local d = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2) / r
		if d >= 1 then return old end
		local g = (1 - d) * (1 - d) * strength
		return clamp(old + g)
	end)
end

------------------------------------------------------------
-- scenery pieces  (1-bit rule: solid ink shapes, light outlines, dither only in fog/gradients)
------------------------------------------------------------

local function outline(c, x0, y0, x1, y1, v)
	line(c, x0, y0, x1, y0, v); line(c, x0, y1, x1, y1, v)
	line(c, x0, y0, x0, y1, v); line(c, x1, y0, x1, y1, v)
end

local function box(c, x0, y0, x1, y1, fill, edge)
	rect(c, x0, y0, x1, y1, fill)
	if edge then outline(c, x0, y0, x1, y1, edge) end
end

local function sky(c, horizon, v_top, v_hor, seed)
	vgrad(c, 0, 0, c.w - 1, horizon, v_top, v_hor)
	grain(c, 0, 0, c.w - 1, horizon, 0.03, seed or 1)
end

-- horizontal fog band centred on y with half-height hh
local function fog_band(c, y, hh, amount, seed)
	rect_fn(c, 0, y - hh, c.w - 1, y + hh, function(x, py, old)
		local t = 1 - math.abs((py - y) / hh)
		local a = amount * t * (0.75 + 0.25 * rnd(x, py, seed or 4))
		return old * (1 - a) + 0.55 * a
	end)
end

local function sea(c, horizon, seed)
	vgrad(c, 0, horizon, c.w - 1, c.h - 1, 0.16, 0.02)
	local y = horizon + 1
	local row = 0
	while y < c.h do
		local x = floor(rnd(row, 3, seed or 2) * 12)
		local depth = (y - horizon) / math.max(1, c.h - horizon)
		while x < c.w do
			local len = 2 + floor(rnd(x, y, seed or 2) * (4 + depth * 10))
			local gap = 5 + floor(rnd(x + 1, y, seed or 2) * (10 + depth * 30))
			if rnd(x, y + 1, seed or 2) > 0.3 + depth * 0.4 then
				rect(c, x, y, x + len, y, 0.9 - depth * 0.4)
			end
			x = x + len + gap
		end
		row = row + 1
		y = y + 2 + floor(depth * 4)
	end
end

local function moon(c, cx, cy, r)
	glow(c, cx, cy, r * 4, 0.45)
	disc(c, cx, cy, r, 1)
	-- a few dark craters
	set(c, cx - 1, cy - 1, 0.45); set(c, cx + 1, cy + 1, 0.45)
end

-- tapered white tower; gy = ground line; lit = lamp on; dim = brightness multiplier
local function lighthouse(c, x, gy, h, wb, lit, dim)
	dim = dim or 1
	x, gy, h = floor(x), floor(gy), floor(h)
	local top = gy - h
	local wt = math.max(3, floor(wb * 0.66))
	for y = top, gy do
		local t = (y - top) / h
		local hw = (wt + (wb - wt) * t) / 2
		local x0, x1 = floor(x - hw), floor(x + hw)
		for px = x0, x1 do
			local s = (px - x0) / math.max(1, x1 - x0)
			set(c, px, y, (0.95 - 0.75 * s) * dim)
		end
		set(c, x0, y, 0.02); set(c, x1, y, 0.02)
	end
	-- dark band rings
	for i = 1, 2 do
		local y = floor(top + h * (0.3 * i))
		local t = (y - top) / h
		local hw = (wt + (wb - wt) * t) / 2
		rect(c, x - hw, y, x + hw, y + 1, 0.02)
	end
	-- gallery
	rect(c, x - wt / 2 - 2, top - 1, x + wt / 2 + 2, top, 0.02)
	line(c, x - wt / 2 - 2, top - 2, x + wt / 2 + 2, top - 2, 0.7 * dim)
	-- lamp room
	local lh = math.max(3, floor(h * 0.12))
	rect(c, x - wt / 2, top - lh - 1, x + wt / 2, top - 2, 0.02)
	rect(c, x - wt / 2 + 1, top - lh, x + wt / 2 - 1, top - 3, lit and 1 or 0.22 * dim)
	if not lit then line(c, x, top - lh, x, top - 3, 0.02) end
	-- cap
	tri(c, x - wt / 2 - 1, top - lh - 1, x + wt / 2 + 1, top - lh - 1, x, top - lh - 4, 0.02)
	set(c, x, top - lh - 4, 0.8 * dim)
	if lit then
		local ly = top - lh / 2 - 1
		glow(c, x, ly, h * 0.35, 0.5)
		local reach = c.w
		rect_fn(c, 0, 0, c.w - 1, gy - 2, function(px, py, old)
			local dx = px - x
			if math.abs(dx) < wt then return old end
			local spread = math.abs(dx) * 0.10 + 1
			local dyn = math.abs(py - ly) / spread
			if dyn > 1 then return old end
			local fall = 1 - math.abs(dx) / reach
			return clamp(old + (1 - dyn) * 0.6 * fall)
		end)
	end
end

local function fig(c, x, gy, h, v)
	local r = math.max(1, floor(h * 0.11))
	disc(c, x, gy - h + r, r, v)
	rect(c, x - r, gy - h + 2 * r, x + r, gy - h * 0.4, v)
	rect(c, x - r, gy - h * 0.4, x - 1, gy, v)
	rect(c, x + 1, gy - h * 0.4, x + r, gy, v)
end

-- two-storey inn: solid body, light outlines, windows lit by index (1..8)
local function inn(c, x, gy, w, h, lit)
	local top = gy - h
	rect(c, x, top, x + w, gy, 0.03)
	outline(c, x, top, x + w, gy, 0.55)
	-- roof
	local ry = top - h * 0.3
	tri(c, x - 3, top, x + w + 3, top, x + w / 2, ry, 0.03)
	line(c, x - 3, top, x + w / 2, ry, 0.9)
	line(c, x + w + 3, top, x + w / 2, ry, 0.5)
	line(c, x - 3, top, x + w + 3, top, 0.7)
	-- chimney + smoke
	rect(c, x + w * 0.76, ry + h * 0.08, x + w * 0.76 + 3, top, 0.03)
	line(c, x + w * 0.76, ry + h * 0.08, x + w * 0.76 + 3, ry + h * 0.08, 0.7)
	for i = 0, 5 do
		set(c, floor(x + w * 0.76 + 1 + i * 0.8 + rnd(i, 1) * 2), floor(ry + h * 0.06 - i * 2), 0.6)
	end
	-- windows
	local wn = 0
	local cw = (w - 6) / 4
	for row = 0, 1 do
		for col = 0, 3 do
			wn = wn + 1
			local wx = x + 3 + col * cw + 2
			local wy = top + 3 + row * (h / 2)
			local ww, wh = cw - 4, h / 2 - 7
			local on = lit and lit[wn]
			if on then
				rect(c, wx, wy, wx + ww, wy + wh, 1)
				line(c, wx + ww / 2, wy, wx + ww / 2, wy + wh, 0.03)
				line(c, wx, wy + wh / 2, wx + ww, wy + wh / 2, 0.03)
			else
				outline(c, wx, wy, wx + ww, wy + wh, 0.45)
			end
		end
	end
	-- door
	local dw, dh = w * 0.12, h * 0.36
	outline(c, x + w / 2 - dw / 2, gy - dh, x + w / 2 + dw / 2, gy, 0.75)
	set(c, floor(x + w / 2 + dw / 2 - 2), floor(gy - dh * 0.45), 0.9)
end

local function fence(c, x0, x1, gy)
	line(c, x0, gy - 5, x1, gy - 5, 0.6)
	line(c, x0, gy - 2, x1, gy - 2, 0.4)
	for x = x0, x1, 7 do rect(c, x, gy - 8, x, gy, 0.7) end
end

local function ground(c, y, v, seed)
	rect(c, 0, y, c.w - 1, c.h - 1, v)
	grain(c, 0, y, c.w - 1, c.h - 1, 0.12, seed or 5)
	line(c, 0, y, c.w - 1, y, 0.35)
end

local function birds(c, seed, n, ymin, ymax)
	for i = 1, n do
		local x = floor(rnd(i, 11, seed) * (c.w - 10)) + 5
		local y = floor(ymin + rnd(i, 12, seed) * (ymax - ymin))
		set(c, x - 2, y - 1, 0.9); set(c, x - 1, y, 0.9); set(c, x, y, 0.9)
		set(c, x + 1, y, 0.9); set(c, x + 2, y - 1, 0.9)
	end
end

-- interior shell: dark wall + darker floor, light seams
local function room_shell(c, floor_y, wall_top_v, wall_bot_v, seed)
	vgrad(c, 0, 0, c.w - 1, floor_y - 1, wall_top_v, wall_bot_v)
	grain(c, 0, 0, c.w - 1, floor_y - 1, 0.03, seed or 21)
	vgrad(c, 0, floor_y, c.w - 1, c.h - 1, 0.06, 0.0)
	line(c, 0, floor_y, c.w - 1, floor_y, 0.7)
	for y = floor_y + 4, c.h - 1, 5 do line(c, 0, y, c.w - 1, y, 0.25) end
	for i = 0, 8 do
		local x_top = i * (c.w / 8)
		local x_bot = c.w / 2 + (x_top - c.w / 2) * 1.5
		line(c, x_top, floor_y, x_bot, c.h - 1, 0.2)
	end
	-- skirting
	line(c, 0, floor_y - 2, c.w - 1, floor_y - 2, 0.3)
end

local function window_int(c, x, y, w, h, outside)
	vgrad(c, x, y, x + w, y + h, outside, outside - 0.12)
	grain(c, x, y, x + w, y + h, 0.08, 31)
	outline(c, x - 1, y - 1, x + w + 1, y + h + 1, 0.85)
	line(c, x + w / 2, y, x + w / 2, y + h, 0.03)
	line(c, x, y + h / 2, x + w, y + h / 2, 0.03)
	glow(c, x + w / 2, y + h + 4, w * 0.8, 0.12)
end

local function door_int(c, x, y, w, h, plate)
	rect(c, x, y, x + w, y + h, 0.03)
	outline(c, x, y, x + w, y + h, 0.7)
	outline(c, x + 2, y + 2, x + w - 2, y + h * 0.45, 0.35)
	outline(c, x + 2, y + h * 0.55, x + w - 2, y + h - 2, 0.35)
	set(c, x + w - 3, floor(y + h * 0.5), 0.95)
	if plate then rect(c, x + w / 2 - 2, y + 3, x + w / 2 + 2, y + 4, 0.9) end
end

local function lamp_hanging(c, x, y_top, y_lamp)
	line(c, x, y_top, x, y_lamp, 0.6)
	tri(c, x - 7, y_lamp + 5, x + 7, y_lamp + 5, x, y_lamp, 0.03)
	line(c, x - 7, y_lamp + 5, x, y_lamp, 0.7); line(c, x + 7, y_lamp + 5, x, y_lamp, 0.7)
	rect(c, x - 6, y_lamp + 5, x + 6, y_lamp + 5, 1)
	glow(c, x, y_lamp + 10, 22, 0.45)
end

local function table_chairs(c, x, y, w)
	rect(c, x, y, x + w, y + 2, 0.03)
	line(c, x, y, x + w, y, 0.9)
	rect(c, x + 2, y + 3, x + 3, y + 13, 0.03); line(c, x + 2, y + 3, x + 2, y + 13, 0.5)
	rect(c, x + w - 3, y + 3, x + w - 2, y + 13, 0.03); line(c, x + w - 3, y + 3, x + w - 3, y + 13, 0.5)
	for _, cx in ipairs({ x - 7, x + w + 3 }) do
		rect(c, cx, y - 8, cx + 4, y + 11, 0.03)
		outline(c, cx, y - 8, cx + 4, y + 11, 0.45)
		line(c, cx, y - 1, cx + 4, y - 1, 0.45)
	end
end

local function bottle(c, x, y, v)
	rect(c, x, y - 5, x + 2, y, v)
	rect(c, x + 1, y - 8, x + 1, y - 6, v)
	set(c, x, y - 5, 0.9)
end

local function bed(c, x, y, w)
	rect(c, x, y, x + w, y + 9, 0.03)
	outline(c, x, y, x + w, y + 9, 0.55)
	rect(c, x, y, x + w, y + 2, 0.7)
	rect(c, x + 2, y - 3, x + 9, y + 1, 0.95)
	rect(c, x - 1, y - 7, x, y + 11, 0.03); line(c, x - 1, y - 7, x - 1, y + 11, 0.6)
	rect(c, x + w, y - 4, x + w + 1, y + 11, 0.03); line(c, x + w + 1, y - 4, x + w + 1, y + 11, 0.6)
end

local function chair_side(c, x, y)
	line(c, x, y - 13, x, y + 7, 0.7)
	line(c, x, y, x + 10, y, 0.7)
	line(c, x + 10, y, x + 10, y + 7, 0.7)
end

local function frame_pic(c, x, y, w, h)
	rect(c, x, y, x + w, y + h, 0.3)
	outline(c, x - 1, y - 1, x + w + 1, y + h + 1, 0.9)
	local sy = y + h * 0.6
	rect(c, x + w * 0.3, sy, x + w * 0.7, sy + 1, 0.03)
	line(c, x + w * 0.5, sy, x + w * 0.5, y + 2, 0.03)
	tri(c, x + w * 0.5, y + 2, x + w * 0.5, sy - 1, x + w * 0.7, sy - 1, 0.03)
end

------------------------------------------------------------
-- portraits
------------------------------------------------------------

-- bust facing the viewer, hard-lit from the left. gy = bottom row. About 72 px tall.
local function bust(c, cx, gy, s)
	local rx, ry = 11, 13
	local head_cy = gy - 46
	local ink = 0.0
	-- solid ink backdrop with a rim so the figure separates from the scene
	ellipse(c, cx, gy - 20, 44, 46, ink)
	ellipse_fn(c, cx, gy - 20, 44, 46, function(x, y, old)
		local dx, dy = (x - cx) / 44, (y - (gy - 20)) / 46
		local d = dx * dx + dy * dy
		if d > 0.9 then return 0.5 end
		return old
	end)
	-- coat: solid ink trapezoid with a lit left edge and a lighter left panel
	local coat_v = s.coat or 0.0
	rect_fn(c, cx - 34, gy - 22, cx + 34, gy, function(x, y, old)
		local dy = (y - (gy - 22)) / 22
		local half = 10 + 24 * dy
		local dx = x - cx
		if math.abs(dx) > half then return old end
		if dx < -half + 2 then return 0.9 end
		if dx < 0 then return coat_v + 0.25 end
		return coat_v
	end)
	if s.collar then
		tri(c, cx - 7, gy - 22, cx + 7, gy - 22, cx, gy - 10, s.collar)
		line(c, cx - 7, gy - 22, cx, gy - 10, 0.9)
	end
	if s.apron then
		tri(c, cx - 12, gy - 8, cx + 12, gy - 8, cx, gy - 17, 0.85)
		rect(c, cx - 12, gy - 8, cx + 12, gy, 0.85)
	end
	-- neck
	rect(c, cx - 4, gy - 35, cx + 4, gy - 21, 0.55)
	rect(c, cx - 4, gy - 35, cx - 2, gy - 21, 0.9)
	-- head: lit side solid paper, shadow side dithered
	ellipse_fn(c, cx, head_cy, rx, ry, function(x, y)
		local dx, dy = (x - cx) / rx, (y - head_cy) / ry
		if dx * dx + dy * dy > 0.8 and x > cx then return 0.75 end
		if x < cx + 2 then return 0.97 end
		return 0.42
	end)
	set(c, cx - rx, head_cy, 0.6)
	-- hair
	local hv = s.hair_v or ink
	local rim = (s.hair_v and 0.3) or 0.6
	local hair = s.hair or "short"
	local function hair_rim(y0)
		line(c, cx - rx - 1, y0, cx - rx - 1, head_cy, rim)
	end
	if hair == "short" or hair == "neat" or hair == "bun" then
		ellipse_outline(c, cx, head_cy - 7, rx + 2, 8, rim)
		ellipse(c, cx, head_cy - 7, rx + 1, 7, hv)
		rect(c, cx - rx - 1, head_cy - 7, cx - rx + 1, head_cy + 1, hv)
		rect(c, cx + rx - 1, head_cy - 7, cx + rx + 1, head_cy + 1, hv)
		hair_rim(head_cy - 7)
	end
	if hair == "neat" then line(c, cx - 3, head_cy - 13, cx - 7, head_cy - 7, 0.7) end
	if hair == "bun" then
		disc(c, cx + rx + 3, head_cy - 4, 4, hv)
		rect(c, cx - rx - 1, head_cy - 7, cx - rx + 1, head_cy + 4, hv)
	end
	if hair == "beanie" then
		ellipse_outline(c, cx, head_cy - 10, rx + 3, 8, rim)
		ellipse(c, cx, head_cy - 10, rx + 2, 7, hv)
		rect(c, cx - rx - 2, head_cy - 10, cx + rx + 2, head_cy - 7, hv)
		line(c, cx - rx - 2, head_cy - 7, cx + rx + 2, head_cy - 7, 0.7)
		hair_rim(head_cy - 8)
	end
	if hair == "cap" then
		ellipse_outline(c, cx, head_cy - 8, rx + 2, 7, rim)
		ellipse(c, cx, head_cy - 8, rx + 1, 6, hv)
		rect(c, cx - rx - 1, head_cy - 10, cx + rx + 1, head_cy - 7, hv)
		rect(c, cx - rx - 7, head_cy - 7, cx + rx, head_cy - 6, hv)
		line(c, cx - rx - 7, head_cy - 8, cx + rx, head_cy - 8, 0.7)
		hair_rim(head_cy - 10)
	end
	if hair == "captain" then
		rect(c, cx - rx - 1, head_cy - 15, cx + rx + 1, head_cy - 8, hv)
		rect(c, cx - rx - 3, head_cy - 8, cx + rx + 3, head_cy - 6, hv)
		line(c, cx - rx - 1, head_cy - 15, cx + rx + 1, head_cy - 15, 0.6)
		line(c, cx - rx - 1, head_cy - 15, cx - rx - 1, head_cy - 8, 0.6)
		line(c, cx - rx - 3, head_cy - 9, cx + rx + 3, head_cy - 9, 0.7)
		disc(c, cx, head_cy - 12, 1.5, 0.95)
	end
	-- features
	set(c, cx - 4, head_cy - 2, ink); set(c, cx - 3, head_cy - 2, ink)
	set(c, cx + 4, head_cy - 2, ink); set(c, cx + 5, head_cy - 2, ink)
	line(c, cx - 7, head_cy - 5, cx - 2, head_cy - 5, ink)
	line(c, cx + 3, head_cy - 5, cx + 7, head_cy - 5, ink)
	line(c, cx + 1, head_cy - 1, cx + 1, head_cy + 3, ink) -- nose
	line(c, cx - 3, head_cy + 7, cx + 3, head_cy + 7, ink)
	if s.tired then
		line(c, cx - 5, head_cy + 1, cx - 2, head_cy + 1, 0.4); line(c, cx + 3, head_cy + 1, cx + 6, head_cy + 1, 0.15)
	end
	if s.beard then
		local bv = s.beard
		ellipse(c, cx, head_cy + 10, rx - 2, 6, bv)
		rect(c, cx - rx + 2, head_cy + 5, cx + rx - 2, head_cy + 9, bv)
		line(c, cx - 3, head_cy + 7, cx + 3, head_cy + 7, bv > 0.5 and 0.1 or 0.6)
	end
	if s.glasses then
		ring(c, cx - 4, head_cy - 2, 4, ink); ring(c, cx + 4, head_cy - 2, 4, ink)
		set(c, cx, head_cy - 2, ink)
	end
	if s.camera then
		box(c, cx - 10, gy - 12, cx + 6, gy - 2, ink, 0.8)
		disc(c, cx - 2, gy - 7, 3, 0.95); disc(c, cx - 2, gy - 7, 1, ink)
		line(c, cx - 10, gy - 12, cx - 17, gy - 22, 0.8)
		line(c, cx + 6, gy - 12, cx + 14, gy - 22, 0.8)
	end
	if s.cane then
		line(c, cx + 28, gy - 26, cx + 20, gy, 0.9)
		disc(c, cx + 28, gy - 26, 2, 0.95)
	end
	if s.stains then
		set(c, cx - 18, gy - 5, 0.5); set(c, cx - 17, gy - 6, 0.5); set(c, cx + 14, gy - 9, 0.5); set(c, cx + 15, gy - 9, 0.5)
	end
end

local PORTRAITS = {
	han   = { hair = "bun", apron = true, tired = true, coat = 0.1 },
	jang  = { hair = "beanie", beard = 0.5, coat = 0.0 },
	baek  = { hair = "captain", beard = 0.9, hair_v = 0.9, cane = true, coat = 0.0, collar = 0.7 },
	seo   = { hair = "short", camera = true, coat = 0.05, collar = 0.9 },
	lim   = { hair = "neat", coat = 0.7, collar = 0.15 },
	doyun = { hair = "cap", coat = 0.1, stains = true },
}

------------------------------------------------------------
-- scenes  (canvas is c.w x c.h; banner 420x84, title 420x150)
------------------------------------------------------------

local S = {}

S.island = function(c, o)
	local w, h = c.w, c.h
	local hz = floor(h * 0.62)
	if o.dark then
		sky(c, hz, 0.18, 0.4, 1)
	else
		sky(c, hz, 0.0, 0.16, 1)
		moon(c, floor(w * 0.18), floor(h * 0.22), math.max(3, floor(h * 0.06)))
	end
	sea(c, hz, 2)
	-- island silhouette
	local ix0, ix1 = floor(w * 0.42), floor(w * 0.94)
	tri(c, ix0, hz + 1, ix1, hz + 1, floor(w * 0.72), hz - h * 0.15, 0.02)
	rect(c, floor(w * 0.5), hz - h * 0.06, floor(w * 0.9), hz + 1, 0.02)
	tri(c, floor(w * 0.5), hz - h * 0.06, floor(w * 0.6), hz - h * 0.18, floor(w * 0.72), hz - h * 0.06, 0.02)
	-- ridge highlight
	line(c, ix0, hz + 1, floor(w * 0.6), hz - h * 0.18, 0.5)
	line(c, floor(w * 0.6), hz - h * 0.18, floor(w * 0.72), hz - h * 0.15, 0.5)
	-- inn on the slope (tiny, one lit window)
	local iw, ih = floor(w * 0.07), floor(h * 0.1)
	inn(c, floor(w * 0.55), hz - h * 0.09, iw, ih, { [6] = not o.dark })
	-- lighthouse on the ridge
	lighthouse(c, floor(w * 0.78), hz - h * 0.12, floor(h * 0.4), math.max(5, floor(h * 0.08)), o.lit, o.dark and 0.6 or 1)
	if not o.dark then birds(c, 3, 3, h * 0.15, h * 0.4) end
	fog_band(c, hz, h * 0.14, o.dark and 0.8 or 0.5, 4)
end

S.ferry = function(c)
	local w, h = c.w, c.h
	local hz = floor(h * 0.62)
	sky(c, hz, 0.04, 0.2, 11)
	sea(c, hz, 12)
	lighthouse(c, floor(w * 0.66), hz, floor(h * 0.5), 8, false)
	fog(c, 0, 0, w - 1, hz + 3, 0.4, 0.22)
	fog_band(c, hz - h * 0.05, h * 0.2, 0.3, 13)
	-- bow + railing in the foreground
	tri(c, floor(w * 0.18), h - 1, floor(w * 0.82), h - 1, floor(w * 0.5), floor(h * 0.7), 0.02)
	rect(c, floor(w * 0.14), h - 6, floor(w * 0.86), h - 1, 0.02)
	line(c, floor(w * 0.18), h - 1, floor(w * 0.5), floor(h * 0.7), 0.7)
	line(c, floor(w * 0.82), h - 1, floor(w * 0.5), floor(h * 0.7), 0.7)
	local ry = floor(h * 0.78)
	line(c, floor(w * 0.14), ry, floor(w * 0.86), ry, 0.9)
	for x = floor(w * 0.16), floor(w * 0.86), 12 do
		local yy = ry + math.abs(x - w / 2) * 0.16
		line(c, x, ry, x, yy + 4, 0.75)
	end
	glow(c, floor(w * 0.5), floor(h * 0.68), 12, 0.7)
	disc(c, floor(w * 0.5), floor(h * 0.68), 1.5, 1)
end

S.pier = function(c)
	local w, h = c.w, c.h
	local hz = floor(h * 0.46)
	sky(c, hz, 0.0, 0.14, 21)
	sea(c, hz, 22)
	-- moored boat
	local bx = floor(w * 0.7)
	rect(c, bx, hz + 5, bx + 34, hz + 10, 0.02)
	line(c, bx, hz + 5, bx + 34, hz + 5, 0.7)
	tri(c, bx - 4, hz + 5, bx, hz + 5, bx, hz + 10, 0.02)
	line(c, bx + 12, hz + 5, bx + 12, hz - 16, 0.6)
	rect(c, bx + 5, hz + 1, bx + 17, hz + 4, 0.02)
	outline(c, bx + 5, hz + 1, bx + 17, hz + 4, 0.5)
	fog_band(c, hz, h * 0.12, 0.6, 23)
	-- pier deck receding from bottom-left
	local py = floor(h * 0.66)
	local ex = floor(w * 0.4)
	tri(c, 0, h - 1, floor(w * 0.66), h - 1, ex, py, 0.03)
	tri(c, 0, h - 1, 0, py + 8, ex, py, 0.03)
	line(c, ex, py, floor(w * 0.66), h - 1, 0.8)
	line(c, 0, py + 8, ex, py, 0.6)
	for i = 1, 4 do
		local t = i / 4.5
		local y = py + t * (h - 1 - py)
		local x1 = ex + t * (floor(w * 0.66) - ex)
		line(c, 0, y, x1, y, 0.7)
	end
	for i = 0, 3 do
		local t = i / 3
		local x = floor(ex + t * (w * 0.66 - ex))
		local y = floor(py + t * (h - 1 - py))
		local ph = 6 + t * 12
		rect(c, x - 1, y - ph, x + 1, y, 0.02)
		line(c, x - 1, y - ph, x - 1, y, 0.7)
	end
	-- a figure with a tripod at the end of the pier
	fig(c, ex + 6, py + 2, 18, 0.02)
	line(c, ex + 12, py + 2, ex + 15, py - 10, 0.7); line(c, ex + 18, py + 2, ex + 15, py - 10, 0.7)
	rect(c, ex + 13, py - 13, ex + 17, py - 10, 0.02); set(c, ex + 17, py - 12, 0.9)
	birds(c, 5, 2, h * 0.1, h * 0.3)
end

S.yard = function(c)
	local w, h = c.w, c.h
	local gy = floor(h * 0.8)
	sky(c, gy, 0.0, 0.16, 31)
	-- lighthouse up the slope on the left
	tri(c, 0, gy, floor(w * 0.42), gy, 0, gy - h * 0.22, 0.02)
	line(c, 0, gy - h * 0.22, floor(w * 0.42), gy, 0.4)
	lighthouse(c, floor(w * 0.12), gy - h * 0.16, floor(h * 0.6), 10, false, 0.95)
	fog_band(c, gy - h * 0.3, h * 0.12, 0.3, 34)
	inn(c, floor(w * 0.44), gy, floor(w * 0.44), floor(h * 0.55), { [2] = true, [7] = true })
	-- signboard by the door
	box(c, floor(w * 0.66) - 22, gy - h * 0.55 - 7, floor(w * 0.66) - 6, gy - h * 0.55 - 2, 0.02, 0.85)
	ground(c, gy, 0.04, 32)
	-- path from the door down toward the pier (right)
	tri(c, floor(w * 0.63), gy, floor(w * 0.69), gy, floor(w * 0.72) - 16, h - 1, 0.2)
	tri(c, floor(w * 0.63), gy, floor(w * 0.72) - 16, h - 1, floor(w * 0.72) + 14, h - 1, 0.2)
	fence(c, floor(w * 0.9), w - 1, gy)
	fence(c, 0, floor(w * 0.3), gy + 2)
	fog_band(c, gy + 3, 5, 0.5, 33)
end

S.hall = function(c)
	local w, h = c.w, c.h
	local fy = floor(h * 0.7)
	room_shell(c, fy, 0.02, 0.12, 41)
	door_int(c, floor(w * 0.06), floor(h * 0.1), floor(w * 0.1), fy - floor(h * 0.1) - 1, false)
	-- wall clock
	local cx, cy = floor(w * 0.3), floor(h * 0.3)
	box(c, cx - 6, cy - 7, cx + 6, cy + 16, 0.02, 0.6)
	disc(c, cx, cy, 5, 0.95); line(c, cx, cy, cx, cy - 3, 0.03); line(c, cx, cy, cx + 3, cy, 0.03)
	line(c, cx, cy + 7, cx, cy + 13, 0.8); disc(c, cx, cy + 13, 1.5, 0.8)
	-- key board with hooks (one key missing)
	local kx, ky = floor(w * 0.44), floor(h * 0.18)
	box(c, kx, ky, kx + 52, ky + 16, 0.02, 0.7)
	for i = 0, 3 do
		local hx = kx + 8 + i * 12
		set(c, hx, ky + 4, 0.9)
		if i ~= 1 then rect(c, hx, ky + 5, hx, ky + 10, 0.85); set(c, hx + 1, ky + 9, 0.85); set(c, hx + 1, ky + 7, 0.85) end
	end
	-- counter with the register
	local rx = floor(w * 0.66)
	box(c, rx, fy - 14, rx + 56, fy, 0.02, 0.6)
	line(c, rx, fy - 14, rx + 56, fy - 14, 0.9)
	box(c, rx + 10, fy - 18, rx + 28, fy - 14, 0.9, nil)
	line(c, rx + 19, fy - 18, rx + 19, fy - 14, 0.2)
	-- shoe rack (right)
	local sx = floor(w * 0.84)
	for r = 0, 2 do
		local y = fy - 24 + r * 8
		line(c, sx, y, sx + 40, y, 0.7)
		for i = 0, 3 do
			if not (r == 1 and i == 2) then box(c, sx + 2 + i * 10, y + 3, sx + 8 + i * 10, y + 6, 0.02, 0.5) end
		end
	end
	glow(c, floor(w * 0.5), 0, 40, 0.3)
end

S.dining = function(c)
	local w, h = c.w, c.h
	local fy = floor(h * 0.68)
	room_shell(c, fy, 0.02, 0.12, 51)
	window_int(c, floor(w * 0.72), floor(h * 0.14), 40, 22, 0.5)
	frame_pic(c, floor(w * 0.16), floor(h * 0.16), 26, 16)
	lamp_hanging(c, floor(w * 0.48), 0, floor(h * 0.18))
	table_chairs(c, floor(w * 0.38), fy - 8, 70)
	bottle(c, floor(w * 0.44), fy - 9, 0.02)
	bottle(c, floor(w * 0.52), fy - 9, 0.02)
	-- stove in the corner
	box(c, floor(w * 0.9), fy - 20, floor(w * 0.9) + 16, fy, 0.02, 0.6)
	rect(c, floor(w * 0.9) + 6, fy - 34, floor(w * 0.9) + 9, fy - 20, 0.02)
	line(c, floor(w * 0.9) + 6, fy - 34, floor(w * 0.9) + 6, fy - 20, 0.6)
	rect(c, floor(w * 0.9) + 4, fy - 9, floor(w * 0.9) + 12, fy - 5, 0.9)
end

S.corridor = function(c)
	local w, h = c.w, c.h
	local cx, cy = w / 2, h * 0.42
	vgrad(c, 0, 0, w - 1, h - 1, 0.08, 0.0)
	-- end wall with a window
	rect(c, cx - 18, cy - 14, cx + 18, cy + 14, 0.08)
	window_int(c, cx - 7, cy - 9, 14, 14, 0.6)
	glow(c, cx, cy, 34, 0.2)
	line(c, 0, h - 1, cx - 18, cy + 14, 0.8)
	line(c, w - 1, h - 1, cx + 18, cy + 14, 0.8)
	line(c, 0, 0, cx - 18, cy - 14, 0.4)
	line(c, w - 1, 0, cx + 18, cy - 14, 0.4)
	-- floor
	tri(c, 0, h - 1, w - 1, h - 1, cx + 18, cy + 14, 0.03)
	tri(c, 0, h - 1, cx - 18, cy + 14, cx + 18, cy + 14, 0.03)
	line(c, 0, h - 1, cx - 18, cy + 14, 0.8)
	line(c, w - 1, h - 1, cx + 18, cy + 14, 0.8)
	for i = 1, 5 do
		local t = (i / 5) ^ 1.6
		local y = cy + 14 + t * (h - 1 - cy - 14)
		local x0 = cx - 18 - t * (cx - 18)
		local x1 = cx + 18 + t * (w - 1 - cx - 18)
		line(c, x0, y, x1, y, 0.3)
	end
	-- doors along both walls
	for i = 0, 1 do
		local t = 0.3 + i * 0.4
		local dh = 24 + t * 34
		local dw = 8 + t * 12
		local dy = cy + 14 + (h - 1 - (cy + 14)) * t
		local dl_x = cx - 18 - (cx - 18) * t
		door_int(c, dl_x, dy - dh, dw, dh, true)
		local dr_x = cx + 18 + (w - 1 - (cx + 18)) * t
		door_int(c, dr_x - dw, dy - dh, dw, dh, true)
	end
	glow(c, floor(w * 0.2), floor(h * 0.22), 14, 0.5)
	set(c, floor(w * 0.2), floor(h * 0.22), 1)
end

local function guest_room(c, variant)
	local w, h = c.w, c.h
	local fy = floor(h * 0.7)
	room_shell(c, fy, 0.02, 0.1, 60 + variant)
	window_int(c, floor(w * 0.6), floor(h * 0.1), 48, 30, 0.5)
	bed(c, floor(w * 0.08), fy - 13, 96)
	local dx = floor(w * 0.78)
	line(c, dx, fy - 14, dx + 56, fy - 14, 0.9)
	rect(c, dx, fy - 13, dx + 56, fy - 11, 0.02)
	line(c, dx, fy - 11, dx, fy, 0.6); line(c, dx + 56, fy - 11, dx + 56, fy, 0.6)
	line(c, dx + 3, fy - 11, dx + 3, fy - 2, 0.3); line(c, dx + 53, fy - 11, dx + 53, fy - 2, 0.3)
	if variant == 1 then
		bottle(c, dx + 8, fy - 15, 0.02)
		box(c, dx + 16, fy - 18, dx + 19, fy - 15, 0.02, 0.7)
		rect(c, dx + 26, fy - 16, dx + 48, fy - 15, 0.95)
		local sx = floor(w * 0.4)
		box(c, sx, fy - 9, sx + 40, fy, 0.02, 0.7)
		box(c, sx, fy - 22, sx + 40, fy - 10, 0.02, 0.7)
		rect(c, sx + 4, fy - 19, sx + 36, fy - 13, 0.45)
		rect(c, sx + 8, fy - 6, sx + 30, fy - 5, 0.4)
	elseif variant == 2 then
		local tx = floor(w * 0.44)
		line(c, tx, fy, tx + 7, fy - 34, 0.85); line(c, tx + 14, fy, tx + 7, fy - 34, 0.85)
		line(c, tx + 7, fy - 34, tx + 7, fy - 6, 0.85)
		box(c, tx - 1, fy - 44, tx + 15, fy - 34, 0.02, 0.8); disc(c, tx + 11, fy - 39, 2.5, 0.95); disc(c, tx + 11, fy - 39, 1, 0.02)
		line(c, dx + 40, fy - 52, dx + 40, fy - 14, 0.6)
		line(c, dx + 32, fy - 50, dx + 48, fy - 50, 0.7)
		box(c, dx + 30, fy - 48, dx + 50, fy - 18, 0.02, 0.6)
		line(c, dx + 40, fy - 46, dx + 40, fy - 20, 0.3)
		rect(c, dx + 6, fy - 16, dx + 24, fy - 15, 0.95)
	elseif variant == 3 then
		local sx = floor(w * 0.46)
		-- armchair, seen from the side, facing the window
		box(c, sx, fy - 26, sx + 6, fy, 0.02, 0.6)
		box(c, sx + 6, fy - 14, sx + 24, fy, 0.02, 0.6)
		-- the old man: head, hunched back, blanket over the knees
		disc(c, sx + 12, fy - 30, 5, 0.9); ellipse(c, sx + 10, fy - 33, 4, 2, 0.9)
		rect(c, sx + 6, fy - 26, sx + 16, fy - 14, 0.15); line(c, sx + 6, fy - 26, sx + 6, fy - 14, 0.7)
		rect(c, sx + 8, fy - 15, sx + 26, fy - 9, 0.6)
		line(c, sx + 26, fy - 20, sx + 29, fy, 0.9); disc(c, sx + 26, fy - 20, 1.5, 0.95)
		bottle(c, floor(w * 0.14), fy - 14, 0.8)
		rect(c, dx + 8, fy - 16, dx + 30, fy - 15, 0.95)
	elseif variant == 4 then
		box(c, floor(w * 0.14), fy - 18, floor(w * 0.14) + 30, fy - 13, 0.02, 0.6)
		box(c, dx + 12, fy - 10, dx + 40, fy, 0.02, 0.7)
		rect(c, dx + 22, fy - 13, dx + 30, fy - 10, 0.02); line(c, dx + 22, fy - 13, dx + 30, fy - 13, 0.7)
	end
end
S.room1 = function(c) guest_room(c, 1) end
S.room2 = function(c) guest_room(c, 2) end
S.room3 = function(c) guest_room(c, 3) end
S.room4 = function(c) guest_room(c, 4) end

S.lighthouse = function(c)
	local w, h = c.w, c.h
	local gy = floor(h * 0.84)
	sky(c, gy, 0.0, 0.14, 71)
	fog_band(c, gy - h * 0.18, h * 0.16, 0.45, 72)
	lighthouse(c, floor(w * 0.5), gy, floor(h * 0.78), 22, false)
	-- keeper's hut
	local hx = floor(w * 0.66)
	box(c, hx, gy - 14, hx + 30, gy, 0.02, 0.5)
	tri(c, hx - 2, gy - 14, hx + 32, gy - 14, hx + 15, gy - 22, 0.02)
	line(c, hx - 2, gy - 14, hx + 15, gy - 22, 0.8)
	rect(c, hx + 11, gy - 10, hx + 17, gy - 5, 0.95)
	-- door at the tower base
	box(c, floor(w * 0.5) - 4, gy - 11, floor(w * 0.5) + 4, gy, 0.02, 0.6)
	ground(c, gy, 0.05, 73)
	-- someone sitting on the rock beside the door, white shirt, no coat
	local px = floor(w * 0.5) + 16
	ellipse(c, px + 2, gy + 1, 7, 3, 0.02)
	rect(c, px - 2, gy - 10, px + 3, gy - 2, 0.85)
	disc(c, px, gy - 13, 2.5, 0.8); rect(c, px - 3, gy - 16, px + 3, gy - 13, 0.02)
	rect(c, px + 3, gy - 6, px + 8, gy - 4, 0.02); rect(c, px + 6, gy - 4, px + 8, gy + 1, 0.02)
	for i = 0, 7 do
		local x = floor(rnd(i, 1, 73) * w)
		local y = gy + 2 + floor(rnd(i, 2, 73) * 8)
		local r = 6 + floor(rnd(i, 3, 73) * 10)
		ellipse(c, x, y, r, 3, 0.02)
		line(c, x - r, y, x, y - 3, 0.5)
	end
	for i = 0, 3 do rect(c, floor(w * 0.5) - 9 + i, gy + 1 + i * 2, floor(w * 0.5) + 9 - i, gy + 1 + i * 2, 0.6) end
	birds(c, 7, 2, h * 0.1, h * 0.3)
end

S.lh_stairs = function(c, o)
	local w, h = c.w, c.h
	vgrad(c, 0, 0, w - 1, h - 1, 0.02, 0.14)
	grain(c, 0, 0, w - 1, h - 1, 0.03, 81)
	for i = 0, 6 do line(c, floor(w * (0.1 + i * 0.13)), 0, floor(w * (0.05 + i * 0.15)), h - 1, 0.14) end
	window_int(c, floor(w * 0.72), floor(h * 0.1), 8, 14, 0.5)
	glow(c, floor(w * 0.73), floor(h * 0.22), 26, 0.22)
	-- iron spiral steps climbing to the right
	local n = 10
	local sx, sy = floor(w * 0.16), h - 4
	local dx, dy = floor(w * 0.066), floor(h * 0.09)
	for i = 0, n - 1 do
		local x = sx + i * dx
		local y = sy - i * dy
		local len = 30 - i
		rect(c, x, y, x + len, y + 3, 0.02)
		line(c, x, y, x + len, y, 0.85)
		line(c, x + len, y, x + len, y + 3, 0.4)
		line(c, x + len - 1, y - 7, x + len - 1, y, 0.35)
	end
	line(c, sx + 2, sy - 12, sx + 2 + (n - 1) * dx, sy - 12 - (n - 1) * dy, 0.6)
	if o and o.inside then
		-- a blanket-covered shape on the floor under the stairs, and Doyun against the wall
		vgrad(c, 0, h - 8, w - 1, h - 1, 0.08, 0.02)
		line(c, 0, h - 8, w - 1, h - 8, 0.4)
		ellipse(c, floor(w * 0.36), h - 5, 30, 4, 0.75)
		ellipse(c, floor(w * 0.36) + 6, h - 6, 12, 2, 0.5)
		fig(c, floor(w * 0.9), h - 2, 34, 0.02)
		rect(c, floor(w * 0.9) - 4, h - 26, floor(w * 0.9) + 4, h - 22, 0.6)
		set(c, floor(w * 0.9) - 4, h - 28, 0.7); set(c, floor(w * 0.9), h - 28, 0.7)
	end
end

S.lh_body = function(c)
	local w, h = c.w, c.h
	vgrad(c, 0, 0, w - 1, h - 1, 0.02, 0.14)
	grain(c, 0, 0, w - 1, h - 1, 0.03, 91)
	local fy = floor(h * 0.62)
	vgrad(c, 0, fy, w - 1, h - 1, 0.1, 0.03)
	line(c, 0, fy, w - 1, fy, 0.5)
	-- foot of the iron stairs, right side
	for i = 0, 5 do
		local x = floor(w * 0.68) + i * 10
		local y = fy - 2 - i * 6
		rect(c, x, y, x + 24, y + 3, 0.02)
		line(c, x, y, x + 24, y, 0.85)
	end
	-- fallen lantern and its light
	local lx = floor(w * 0.24)
	glow(c, lx, fy + 7, 30, 0.7)
	box(c, lx - 4, fy + 4, lx + 4, fy + 9, 0.02, 0.6)
	rect(c, lx - 2, fy + 5, lx + 2, fy + 8, 1)
	-- the body: coat, head, legs; one arm toward the lantern
	local bx = floor(w * 0.36)
	ellipse(c, bx + 22, fy + 6, 24, 6, 0.85)
	ellipse(c, bx + 26, fy + 8, 18, 3, 0.03)
	rect(c, bx + 42, fy + 2, bx + 72, fy + 5, 0.8); line(c, bx + 42, fy + 5, bx + 72, fy + 5, 0.03)
	rect(c, bx + 44, fy + 7, bx + 74, fy + 10, 0.65)
	disc(c, bx, fy + 7, 5, 0.9); disc(c, bx - 1, fy + 5, 3, 0.03)
	rect(c, bx + 4, fy + 10, bx + 18, fy + 11, 0.8)
	set(c, bx + 2, fy + 8, 0.03); set(c, bx + 3, fy + 9, 0.03)
	-- muddy footprints up the stairs
	for i = 0, 3 do set(c, floor(w * 0.7) + i * 11, fy - 4 - i * 6, 0.45); set(c, floor(w * 0.7) + 5 + i * 11, fy - 3 - i * 6, 0.45) end
end

S.lh_top = function(c)
	local w, h = c.w, c.h
	vgrad(c, 0, 0, w - 1, h - 1, 0.22, 0.34)
	grain(c, 0, 0, w - 1, h - 1, 0.08, 101)
	for x = 0, w - 1, floor(w / 7) do rect(c, x, 0, x + 1, h - 1, 0.02) end
	rect(c, 0, floor(h * 0.5), w - 1, floor(h * 0.5), 0.02)
	rect(c, 0, 0, w - 1, 2, 0.02)
	local fy = floor(h * 0.8)
	vgrad(c, 0, fy, w - 1, h - 1, 0.08, 0.02)
	line(c, 0, fy, w - 1, fy, 0.6)
	line(c, 0, fy - 7, w - 1, fy - 7, 0.02)
	for x = 4, w - 1, 9 do rect(c, x, fy - 7, x, fy, 0.02) end
	local cx, cy = floor(w * 0.5), floor(h * 0.42)
	ellipse(c, cx, cy, 22, 24, 0.04)
	for r = 5, 20, 5 do ring(c, cx, cy, r, 0.45) end
	rect(c, cx - 4, cy - 7, cx + 4, cy + 7, 0.2)
	box(c, cx - 24, cy + 22, cx + 24, fy - 7, 0.02, 0.5)
end

S.memorial = function(c)
	local w, h = c.w, c.h
	local hz = floor(h * 0.5)
	sky(c, hz, 0.0, 0.14, 111)
	sea(c, hz, 112)
	fog_band(c, hz, h * 0.14, 0.6, 113)
	local gy = floor(h * 0.86)
	ground(c, gy - 6, 0.04, 114)
	local sx, sw, sh = floor(w * 0.5), 20, floor(h * 0.55)
	hgrad(c, sx - sw / 2, gy - sh + 6, sx + sw / 2, gy - 2, 0.6, 0.15)
	ellipse_fn(c, sx, gy - sh + 6, sw / 2, 5, function(x) return 0.6 - 0.45 * (x - (sx - sw / 2)) / sw end)
	line(c, sx - sw / 2, gy - sh + 6, sx - sw / 2, gy - 2, 0.9)
	box(c, sx - sw / 2 - 4, gy - 3, sx + sw / 2 + 4, gy, 0.02, 0.5)
	for y = gy - sh + 12, gy - 12, 4 do line(c, sx - 5, y, sx + 5, y, 0.02) end
	disc(c, sx - 9, gy - 4, 1.5, 0.9); disc(c, sx - 12, gy - 3, 1.5, 0.8)
	rect(c, sx + 6, gy - 4, sx + 11, gy - 4, 0.95)
	fig(c, floor(w * 0.2), gy, 30, 0.02)
end

-- primitives shared with art_clues.lua
M.P = {
	rnd = rnd, set = set, get = get, clamp = clamp, rect = rect, rect_fn = rect_fn,
	vgrad = vgrad, hgrad = hgrad, grain = grain, fog = fog, ellipse = ellipse, ellipse_fn = ellipse_fn,
	disc = disc, ellipse_outline = ellipse_outline, ring = ring, tri = tri, line = line, glow = glow,
	outline = outline, box = box, fig = fig, lighthouse = lighthouse, bust = bust, PORTRAITS = PORTRAITS,
	door_int = door_int, sea = sea, sky = sky, fog_band = fog_band,
}

------------------------------------------------------------
-- rendering / cache
------------------------------------------------------------

local cache = {}

local function to_rgb(c)
	local ink = string.rep(string.char(M.INK[1], M.INK[2], M.INK[3]), SCALE)
	local paper = string.rep(string.char(M.PAPER[1], M.PAPER[2], M.PAPER[3]), SCALE)
	local rows = {}
	local w = c.w
	for y = 0, c.h - 1 do -- texture rows start at the top for gui textures
		local row = {}
		local by = BAYER[(y % 8) + 1]
		local base = y * w
		for x = 0, w - 1 do
			local t = (by[(x % 8) + 1] + 0.5) / 64
			row[x + 1] = (c[base + x + 1] > t) and paper or ink
		end
		local r = table.concat(row)
		for _ = 1, SCALE do rows[#rows + 1] = r end
	end
	return table.concat(rows)
end

local SCENE_OPTS = {
	island_lit = { fn = "island", lit = true },
	island_dark = { fn = "island", dark = true },
	lh_inside = { fn = "lh_stairs", inside = true },
}

-- key: "<scene>" or "<scene>+<portrait>"; w/h are the final texture size in px
function M.render(key, w, h)
	local ck = key .. ":" .. w .. "x" .. h
	if cache[ck] then return cache[ck], w, h end
	local cw, ch = floor(w / SCALE), floor(h / SCALE)
	if key:sub(1, 5) == "clue:" then
		local fn = require("main.art_clues")[key:sub(6)]
		local c = new_canvas(cw, ch, 0.02)
		if fn then fn(c, M.P) else grain(c, 0, 0, cw - 1, ch - 1, 0.3, 1) end
		local data = to_rgb(c)
		cache[ck] = data
		return data, cw * SCALE, ch * SCALE
	end
	local scene_key, portrait = key, nil
	local plus = key:find("+", 1, true)
	if plus then
		scene_key, portrait = key:sub(1, plus - 1), key:sub(plus + 1)
	end
	local opts = SCENE_OPTS[scene_key] or { fn = scene_key }
	local fn = S[opts.fn]
	local c = new_canvas(cw, ch, 0.1)
	if fn then
		fn(c, opts)
	else
		grain(c, 0, 0, cw - 1, ch - 1, 0.3, 1)
	end
	if portrait and PORTRAITS[portrait] then
		bust(c, floor(cw * 0.13), ch - 1, PORTRAITS[portrait])
	end
	local data = to_rgb(c)
	cache[ck] = data
	return data, cw * SCALE, ch * SCALE
end

function M.has(key)
	if key:sub(1, 5) == "clue:" then return require("main.art_clues")[key:sub(6)] ~= nil end
	local scene_key, portrait = key, nil
	local plus = key:find("+", 1, true)
	if plus then scene_key, portrait = key:sub(1, plus - 1), key:sub(plus + 1) end
	local opts = SCENE_OPTS[scene_key] or { fn = scene_key }
	if not S[opts.fn] then return false end
	if portrait and not PORTRAITS[portrait] then return false end
	return true
end

return M
