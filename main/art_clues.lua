-- Clue illustrations for the notebook detail screen (canvas 420x120, values 0 = ink, 1 = paper).
-- Each entry is keyed by the clue id in story.lua and receives (canvas, P) where P holds the
-- drawing primitives exported by main/art.lua. Objects are drawn large and centred;
-- testimony clues show the speaker's bust on the left and a subject sketch on the right.

local floor = math.floor
local C = {}

------------------------------------------------------------
-- shared pieces
------------------------------------------------------------

-- plain backdrop with a soft pool of light behind the subject
local function pad(c, P, cx, cy)
	P.rect(c, 0, 0, c.w - 1, c.h - 1, 0.02)
	P.grain(c, 0, 0, c.w - 1, c.h - 1, 0.03, 201)
	P.glow(c, cx or c.w / 2, cy or c.h / 2, 90, 0.16)
end

-- a light sheet of paper with an outline; returns nothing
local function sheet(c, P, x, y, w, h, v)
	P.rect(c, x, y, x + w, y + h, v or 0.9)
	P.outline(c, x - 1, y - 1, x + w + 1, y + h + 1, 0.3)
	-- corner shadow
	P.rect(c, x + w + 1, y + 2, x + w + 2, y + h + 2, 0.15)
	P.rect(c, x + 2, y + h + 1, x + w + 2, y + h + 2, 0.15)
end

-- handwriting: short dark dashes on a light sheet
local function script_lines(c, P, x, y, w, n, seed, v)
	for i = 0, n - 1 do
		local ly = y + i * 7
		local sx = x
		local k = 0
		while sx < x + w - 4 do
			local len = 3 + floor(P.rnd(k, i, seed) * 9)
			if sx + len > x + w then len = x + w - sx end
			P.rect(c, sx, ly, sx + len, ly, v or 0.1)
			if P.rnd(k + 7, i, seed) > 0.7 then P.rect(c, sx + 1, ly - 1, sx + 2, ly - 1, v or 0.1) end
			sx = sx + len + 3 + floor(P.rnd(k + 3, i, seed) * 4)
			k = k + 1
		end
	end
end

-- a shoe seen from above (sole print) or from the side
local function sole(c, P, cx, cy, len, wid, v)
	P.ellipse(c, cx, cy - len * 0.2, wid / 2, len * 0.3, v)
	P.ellipse(c, cx, cy + len * 0.28, wid / 2.6, len * 0.16, v)
end

local function shoe_side(c, P, x, y, len, high, v, edge)
	-- x,y = heel bottom; toe to the right
	P.rect(c, x, y - 4, x + len, y, v)
	P.ellipse(c, x + len * 0.62, y - 6, len * 0.38, 6, v)
	P.rect(c, x, y - high, x + len * 0.42, y - 4, v)
	P.ellipse(c, x + len * 0.42, y - high + 2, len * 0.14, 4, v)
	edge = edge or 0.9
	P.line(c, x, y, x + len, y, edge)
	P.line(c, x, y - high, x, y, edge)
	P.line(c, x, y - high, x + len * 0.42, y - high, edge)
	P.line(c, x + len * 0.42 + len * 0.14, y - high + 2, x + len, y - 6, edge)
	P.line(c, x + len, y - 6, x + len, y, edge)
	P.line(c, x, y - 4, x + len * 0.3, y - 4, 0.15)
end

local function boot(c, P, x, y, len, high, v)
	shoe_side(c, P, x, y, len, high, v, 0.9)
	P.rect(c, x + 1, y - high + 1, x + len * 0.42 - 1, y - high + 4, 0.6)
	P.line(c, x + 4, y - 3, x + len - 4, y - 3, 0.15)
end

local function chest(c, P, x, y, w, h, open)
	P.box(c, x, y, x + w, y + h, 0.03, 0.85)
	P.line(c, x, y + h * 0.5, x + w, y + h * 0.5, 0.35)
	for i = 0, 2 do P.line(c, x + w * (0.25 + i * 0.25), y, x + w * (0.25 + i * 0.25), y + h, 0.25) end
	-- lock plate
	P.box(c, x + w / 2 - 4, y + h * 0.4, x + w / 2 + 4, y + h * 0.6, 0.5, nil)
	if open then
		-- lid swung up and back
		P.tri(c, x, y, x + w, y, x + w - 6, y - h * 0.7, 0.06)
		P.tri(c, x, y, x + 6, y - h * 0.7, x + w - 6, y - h * 0.7, 0.06)
		P.line(c, x, y, x + 6, y - h * 0.7, 0.85); P.line(c, x + 6, y - h * 0.7, x + w - 6, y - h * 0.7, 0.85)
		P.line(c, x + w, y, x + w - 6, y - h * 0.7, 0.85)
		-- empty inside: dark with dust smears
		P.rect(c, x + 2, y + 1, x + w - 2, y + h * 0.45, 0.0)
		for i = 0, 5 do P.line(c, x + 8 + i * (w / 7), y + 3, x + 14 + i * (w / 7), y + h * 0.4, 0.25) end
	else
		P.tri(c, x - 2, y, x + w + 2, y, x + w / 2, y - 8, 0.06)
		P.line(c, x - 2, y, x + w / 2, y - 8, 0.85); P.line(c, x + w + 2, y, x + w / 2, y - 8, 0.6)
	end
end

local function key(c, P, x, y, len, v)
	-- bow (ring) at left, shaft to the right, bits at the end
	P.ring(c, x, y, 7, v); P.ring(c, x, y, 6, v)
	P.rect(c, x + 7, y - 1, x + len, y + 1, v)
	P.rect(c, x + len - 3, y + 1, x + len - 3, y + 6, v)
	P.rect(c, x + len - 9, y + 1, x + len - 9, y + 4, v)
	P.rect(c, x + len - 7, y + 1, x + len - 6, y + 6, v)
end

local function bottle(c, P, x, y, w, h, v, level)
	-- x,y = bottom-left
	P.box(c, x, y - h * 0.62, x + w, y, v, 0.85)
	P.rect(c, x + w * 0.3, y - h, x + w * 0.7, y - h * 0.62, v)
	P.outline(c, x + w * 0.3, y - h, x + w * 0.7, y - h * 0.62, 0.85)
	P.rect(c, x + w * 0.25, y - h - 3, x + w * 0.75, y - h, 0.5)
	if level then P.rect(c, x + 1, y - h * 0.62 * level, x + w - 1, y - 1, 0.35) end
	-- label
	P.rect(c, x + 3, y - h * 0.45, x + w - 3, y - h * 0.2, 0.8)
	P.line(c, x + 6, y - h * 0.36, x + w - 6, y - h * 0.36, 0.1)
end

local function speech(c, P, x, y, h, v)
	-- opening 「 bracket
	P.rect(c, x, y, x + 12, y + 1, v); P.rect(c, x, y, x + 1, y + h, v)
end

local function cane(c, P, x0, y0, x1, y1, v)
	P.line(c, x0, y0, x1, y1, v); P.line(c, x0 + 1, y0, x1 + 1, y1, v)
	P.disc(c, x0, y0, 2.5, v)
end

local function testimony(c, P, who, subject)
	pad(c, P, 290, 60)
	P.bust(c, 74, c.h - 1, P.PORTRAITS[who])
	speech(c, P, 128, 22, 20, 0.6)
	if subject then subject(c, P, 290, 62) end
end

local function photo_print(c, P, x, y, w, h)
	P.rect(c, x - 5, y - 5, x + w + 5, y + h + 5, 0.92)
	P.vgrad(c, x, y, x + w, y + h, 0.3, 0.5)
	P.grain(c, x, y, x + w, y + h, 0.1, 211)
	-- lighthouse and two boys
	P.lighthouse(c, x + w * 0.62, y + h - 4, h * 0.8, 10, false, 0.9)
	P.fig(c, x + w * 0.28, y + h - 3, h * 0.42, 0.04)
	P.fig(c, x + w * 0.4, y + h - 3, h * 0.3, 0.04)
	P.rect(c, x, y + h - 4, x + w, y + h, 0.12)
end

local function door(c, P, x, y, w, h)
	P.door_int(c, x, y, w, h, false)
end

------------------------------------------------------------
-- objects
------------------------------------------------------------

C.body = function(c, P)
	pad(c, P, 210, 78)
	local fy = 92
	P.line(c, 20, fy + 12, 400, fy + 12, 0.35)
	-- foot of the stairs
	for i = 0, 3 do
		local x = 300 + i * 26
		P.rect(c, x, fy + 8 - i * 12, x + 60, fy + 12 - i * 12, 0.03)
		P.line(c, x, fy + 8 - i * 12, x + 60, fy + 8 - i * 12, 0.8)
	end
	-- the body, lit from the left
	P.ellipse(c, 150, fy + 4, 62, 13, 0.85)
	P.ellipse(c, 158, fy + 8, 48, 6, 0.08)
	P.rect(c, 205, fy - 3, 290, fy + 5, 0.8); P.line(c, 205, fy + 5, 290, fy + 5, 0.08)
	P.rect(c, 210, fy + 7, 296, fy + 13, 0.6)
	P.disc(c, 84, fy + 5, 12, 0.9); P.disc(c, 80, fy + 1, 8, 0.03)
	P.rect(c, 96, fy + 12, 140, fy + 15, 0.8)
	-- coat buttons, all present
	for i = 0, 3 do P.disc(c, 128 + i * 16, fy + 1, 1.5, 0.05) end
end

C.brass_button = function(c, P)
	pad(c, P, 210, 60)
	local cx, cy, r = 210, 60, 36
	P.disc(c, cx, cy, r, 0.55)
	P.ring(c, cx, cy, r, 0.95); P.ring(c, cx, cy, r - 4, 0.15)
	-- anchor
	P.rect(c, cx - 1, cy - 20, cx + 1, cy + 16, 0.05)
	P.rect(c, cx - 12, cy - 12, cx + 12, cy - 10, 0.05)
	P.ring(c, cx, cy - 24, 4, 0.05)
	for i = 0, 10 do
		local a = math.pi * (0.15 + i / 10 * 0.7)
		P.set(c, cx + math.cos(a) * 18, cy + 2 + math.sin(a) * 16, 0.05)
		P.set(c, cx + math.cos(a) * 18 + 1, cy + 2 + math.sin(a) * 16, 0.05)
	end
	-- star
	for i = 0, 4 do
		local a = -math.pi / 2 + i * 2 * math.pi / 5
		P.line(c, cx, cy + 4, cx + math.cos(a) * 9, cy + 4 + math.sin(a) * 9, 0.05)
	end
	-- torn thread trailing off
	P.line(c, cx + r - 2, cy + 8, cx + r + 40, cy + 30, 0.8)
	P.line(c, cx + r + 40, cy + 30, cx + r + 52, cy + 26, 0.8)
	P.line(c, cx + r + 30, cy + 25, cx + r + 46, cy + 40, 0.6)
end

C.footprints = function(c, P)
	pad(c, P, 210, 60)
	-- iron step treads
	for i = 0, 2 do
		local y = 20 + i * 38
		P.line(c, 40, y, 380, y, 0.3)
	end
	-- big shoe, small shoe, alternating up the treads
	sole(c, P, 150, 52, 44, 20, 0.7); sole(c, P, 196, 88, 44, 20, 0.7)
	sole(c, P, 258, 50, 32, 14, 0.7); sole(c, P, 288, 86, 32, 14, 0.7)
	-- dried mud crumbs
	for i = 0, 30 do
		local x = 100 + P.rnd(i, 1, 221) * 240
		local y = 30 + P.rnd(i, 2, 221) * 80
		P.set(c, x, y, 0.5)
	end
end

C.empty_chest = function(c, P)
	pad(c, P, 210, 70)
	chest(c, P, 140, 56, 140, 50, true)
	-- hand-swept dust on the floor
	for i = 0, 4 do P.line(c, 60 + i * 12, 108, 100 + i * 12, 112, 0.25) end
end

C.shoes_lim = function(c, P)
	pad(c, P, 210, 70)
	shoe_side(c, P, 120, 96, 78, 22, 0.3)
	shoe_side(c, P, 216, 96, 78, 22, 0.3)
	-- laces
	for _, x in ipairs({ 150, 246 }) do
		for i = 0, 2 do P.line(c, x + i * 4, 82 - i * 3, x + 6 + i * 4, 78 - i * 3, 0.7) end
	end
	-- mud in the sole grooves
	for _, x in ipairs({ 122, 218 }) do
		for i = 0, 8 do P.rect(c, x + 4 + i * 8, 95, x + 6 + i * 8, 96, 0.5) end
	end
	-- the damp rag
	P.ellipse(c, 330, 96, 30, 8, 0.6); P.ellipse(c, 322, 92, 16, 5, 0.75)
end

C.boots_dry = function(c, P)
	pad(c, P, 210, 66)
	boot(c, P, 120, 102, 84, 60, 0.3)
	boot(c, P, 216, 102, 84, 60, 0.3)
	-- cracked rubber and white salt
	for _, x in ipairs({ 120, 216 }) do
		P.line(c, x + 6, 70, x + 14, 82, 0.55); P.line(c, x + 14, 82, x + 10, 92, 0.55)
		P.line(c, x + 24, 60, x + 28, 72, 0.55)
		for i = 0, 14 do P.set(c, x + 4 + P.rnd(i, 3, 231) * 70, 88 + P.rnd(i, 4, 231) * 10, 0.9) end
	end
end

C.shoes_doyun = function(c, P)
	pad(c, P, 210, 66)
	boot(c, P, 90, 102, 84, 62, 0.3)
	boot(c, P, 186, 102, 84, 62, 0.3)
	-- fresh mud, still wet, and a boot print beside for comparison
	for _, x in ipairs({ 90, 186 }) do P.rect(c, x + 1, 92, x + 83, 101, 0.08); P.line(c, x + 1, 92, x + 83, 92, 0.5) end
	sole(c, P, 330, 70, 60, 26, 0.6)
	for i = 0, 4 do P.line(c, 312, 52 + i * 8, 348, 52 + i * 8, 0.1) end
end

C.key_mud = function(c, P)
	pad(c, P, 210, 60)
	-- board with hooks; the lighthouse key hangs on the second
	P.box(c, 110, 18, 310, 44, 0.03, 0.7)
	for i = 0, 3 do
		local hx = 140 + i * 48
		P.rect(c, hx, 44, hx, 52, 0.85); P.set(c, hx + 1, 52, 0.85)
	end
	key(c, P, 188, 68, 44, 0.9)
	P.line(c, 188, 52, 188, 61, 0.85)
	-- wet mud on key and nail
	for i = 0, 12 do P.set(c, 180 + P.rnd(i, 1, 241) * 50, 60 + P.rnd(i, 2, 241) * 14, 0.3) end
	P.rect(c, 186, 50, 190, 53, 0.35)
end

C.register = function(c, P)
	pad(c, P, 210, 62)
	-- open ledger
	P.rect(c, 110, 24, 310, 100, 0.9)
	P.line(c, 210, 24, 210, 100, 0.3)
	P.outline(c, 109, 23, 311, 101, 0.3)
	P.tri(c, 110, 100, 310, 100, 210, 106, 0.4)
	for i = 0, 8 do P.line(c, 118, 34 + i * 8, 202, 34 + i * 8, 0.65) end
	for i = 0, 8 do P.line(c, 218, 34 + i * 8, 302, 34 + i * 8, 0.65) end
	-- four entries with room numbers
	for i = 0, 3 do
		local y = 36 + i * 16
		P.rect(c, 120, y, 124, y + 3, 0.1)
		P.rect(c, 130, y + 1, 150 + floor(P.rnd(i, 1, 251) * 30), y + 1, 0.1)
		P.rect(c, 226, y + 1, 250 + floor(P.rnd(i, 2, 251) * 40), y + 1, 0.1)
	end
	P.line(c, 130, 28, 190, 28, 0.05)
end

C.memorial = function(c, P)
	pad(c, P, 210, 60)
	local sx, sw, top = 210, 70, 14
	P.hgrad(c, sx - sw / 2, top + 8, sx + sw / 2, 108, 0.6, 0.15)
	P.ellipse_fn(c, sx, top + 8, sw / 2, 8, function(x) return 0.6 - 0.45 * (x - (sx - sw / 2)) / sw end)
	P.line(c, sx - sw / 2, top + 8, sx - sw / 2, 108, 0.9)
	P.box(c, sx - sw / 2 - 8, 106, sx + sw / 2 + 8, 112, 0.03, 0.5)
	-- title + four names
	P.rect(c, sx - 16, top + 18, sx + 16, top + 19, 0.05)
	for i = 0, 3 do P.rect(c, sx - 12, top + 30 + i * 12, sx + 12, top + 31 + i * 12, 0.05) end
	-- chrysanthemums, and one cigarette
	for i = 0, 2 do P.disc(c, sx - 40 + i * 9, 104 - (i % 2) * 3, 3, 0.85) end
	P.rect(c, sx + 24, 106, sx + 40, 107, 0.95); P.set(c, sx + 41, 106, 0.4)
	P.sea(c, 118, 261)
end

C.sewing_kit = function(c, P)
	pad(c, P, 210, 64)
	-- open tin
	P.box(c, 120, 52, 300, 104, 0.06, 0.85)
	P.tri(c, 120, 52, 300, 52, 300, 20, 0.04); P.line(c, 120, 52, 300, 20, 0.85); P.line(c, 300, 20, 300, 52, 0.85)
	-- spools
	for i = 0, 2 do
		local x = 140 + i * 30
		P.box(c, x, 62, x + 18, 94, 0.4, 0.8)
		for y = 66, 90, 4 do P.line(c, x + 1, y, x + 17, y, 0.2) end
	end
	-- needles and a loose thread
	P.line(c, 236, 60, 286, 96, 0.95); P.line(c, 244, 58, 290, 90, 0.95)
	P.line(c, 286, 96, 330, 80, 0.7); P.line(c, 330, 80, 320, 108, 0.7); P.line(c, 320, 108, 360, 100, 0.7)
	-- a small button waiting to be sewn
	P.disc(c, 260, 78, 6, 0.9); P.ring(c, 260, 78, 6, 0.3); P.set(c, 258, 77, 0.1); P.set(c, 262, 77, 0.1)
end

C.telegram = function(c, P)
	pad(c, P, 210, 60)
	sheet(c, P, 100, 30, 220, 62, 0.88)
	-- header band + pasted strips of text
	P.rect(c, 100, 30, 320, 38, 0.6)
	P.rect(c, 108, 33, 150, 34, 0.05)
	for i = 0, 2 do
		local y = 48 + i * 13
		P.rect(c, 108, y - 3, 300 - i * 30, y + 5, 0.95)
		P.rect(c, 112, y + 1, 296 - i * 30, y + 1, 0.05)
	end
	-- torn edge
	for x = 100, 320, 6 do P.tri(c, x, 92, x + 6, 92, x + 3, 96, 0.88) end
end

C.whisky = function(c, P)
	pad(c, P, 210, 66)
	bottle(c, P, 168, 104, 30, 80, 0.06, 0.5)
	-- a single glass with a dried ring
	P.box(c, 236, 78, 262, 104, 0.08, 0.85)
	P.line(c, 240, 96, 258, 96, 0.4)
	P.ellipse_outline(c, 249, 96, 8, 2, 0.5)
	P.ellipse_outline(c, 290, 100, 12, 3, 0.35)
end

C.roster = function(c, P)
	pad(c, P, 210, 60)
	sheet(c, P, 130, 14, 160, 96, 0.9)
	P.rect(c, 150, 24, 270, 26, 0.05)
	script_lines(c, P, 142, 40, 136, 6, 271, 0.12)
	-- company seal
	P.ring(c, 262, 92, 10, 0.3); P.ring(c, 262, 92, 7, 0.3)
	P.line(c, 258, 92, 266, 92, 0.3)
end

C.shorthand = function(c, P)
	pad(c, P, 210, 60)
	-- small notebook, spiral
	P.rect(c, 140, 20, 280, 104, 0.9)
	P.outline(c, 139, 19, 281, 105, 0.3)
	for i = 0, 8 do P.ring(c, 140, 26 + i * 9, 2, 0.4) end
	for i = 0, 8 do P.line(c, 150, 30 + i * 8, 272, 30 + i * 8, 0.7) end
	-- shorthand squiggles: little hooks and loops
	for i = 0, 7 do
		local y = 28 + i * 8
		local x = 152
		local k = 0
		while x < 266 do
			local s = P.rnd(k, i, 281)
			if s < 0.3 then P.line(c, x, y, x + 4, y - 3, 0.1)
			elseif s < 0.6 then P.line(c, x, y - 3, x + 3, y + 1, 0.1)
			else P.ring(c, x + 2, y - 1, 1.5, 0.1) end
			x = x + 6 + floor(P.rnd(k + 1, i, 281) * 6)
			k = k + 1
		end
	end
	-- the three readable words are boxed
	for _, x in ipairs({ 156, 196, 234 }) do P.outline(c, x, 66, x + 26, 74, 0.05) end
end

C.press_id = function(c, P)
	pad(c, P, 210, 60)
	sheet(c, P, 120, 34, 180, 54, 0.9)
	-- photo at left, text at right
	P.rect(c, 128, 40, 160, 82, 0.35)
	P.disc(c, 144, 54, 7, 0.85); P.ellipse(c, 144, 74, 12, 8, 0.85)
	P.ellipse(c, 144, 50, 8, 5, 0.05)
	P.rect(c, 170, 42, 250, 44, 0.05)
	for i = 0, 3 do P.rect(c, 170, 52 + i * 8, 200 + floor(P.rnd(i, 1, 291) * 60), 52 + i * 8, 0.15) end
	P.ring(c, 280, 76, 8, 0.3)
	-- coat pocket edge behind
	P.tri(c, 60, 110, 360, 110, 360, 60, 0.03)
	P.line(c, 60, 110, 360, 60, 0.4)
end

C.letter_draft = function(c, P)
	pad(c, P, 210, 60)
	sheet(c, P, 120, 14, 160, 96, 0.9)
	script_lines(c, P, 132, 30, 136, 9, 301, 0.12)
	-- a crossed-out line and a shaky signature
	P.line(c, 132, 58, 262, 59, 0.05)
	P.line(c, 200, 96, 250, 94, 0.05); P.line(c, 220, 92, 244, 98, 0.05)
	-- fountain pen
	P.line(c, 300, 40, 340, 100, 0.85); P.line(c, 301, 40, 341, 100, 0.85)
	P.tri(c, 296, 34, 306, 38, 300, 46, 0.7)
end

C.meds = function(c, P)
	pad(c, P, 210, 66)
	-- bedside table
	P.line(c, 120, 100, 300, 100, 0.8); P.rect(c, 120, 101, 300, 104, 0.03)
	-- pill bottle + spilled pills
	P.box(c, 180, 62, 206, 100, 0.08, 0.85)
	P.rect(c, 182, 56, 204, 62, 0.5)
	P.rect(c, 184, 74, 202, 88, 0.85)
	P.rect(c, 187, 79, 199, 80, 0.1)
	for i = 0, 4 do P.disc(c, 222 + i * 9, 97 - (i % 2) * 3, 2, 0.9) end
	-- cane leaning against the table
	cane(c, P, 290, 24, 320, 108, 0.9)
end

C.coat_button = function(c, P)
	pad(c, P, 210, 60)
	-- coat front, hanging: collar V, two panels
	P.rect(c, 130, 10, 290, 118, 0.05)
	P.line(c, 130, 10, 130, 118, 0.6); P.line(c, 290, 10, 290, 118, 0.6)
	P.tri(c, 170, 10, 210, 10, 210, 44, 0.3); P.tri(c, 250, 10, 210, 10, 210, 44, 0.2)
	P.line(c, 170, 10, 210, 44, 0.85); P.line(c, 250, 10, 210, 44, 0.85)
	P.line(c, 210, 44, 210, 118, 0.4)
	-- four buttons, the third re-sewn with fresh thread
	for i = 0, 3 do
		local y = 52 + i * 18
		P.disc(c, 210, y, 6, 0.85); P.ring(c, 210, y, 6, 0.2)
		P.set(c, 208, y - 1, 0.1); P.set(c, 212, y - 1, 0.1); P.set(c, 208, y + 1, 0.1); P.set(c, 212, y + 1, 0.1)
		if i == 2 then
			P.disc(c, 210, y, 5, 0.55)
			P.line(c, 208, y - 1, 212, y + 1, 0.95); P.line(c, 208, y + 1, 212, y - 1, 0.95)
			P.line(c, 218, y, 236, y - 8, 0.9)
		end
	end
	-- pocket
	P.outline(c, 236, 90, 280, 96, 0.5)
end

C.photo = function(c, P)
	pad(c, P, 210, 60)
	photo_print(c, P, 150, 24, 120, 72)
	-- a corner of the back with handwriting
	P.rect(c, 290, 60, 360, 108, 0.92)
	P.outline(c, 289, 59, 361, 109, 0.3)
	P.rect(c, 298, 78, 340, 79, 0.1); P.rect(c, 298, 90, 330, 91, 0.1)
end

C.logbook = function(c, P)
	pad(c, P, 210, 60)
	-- thick, sea-stained logbook, open
	P.rect(c, 100, 22, 320, 100, 0.85)
	P.outline(c, 99, 21, 321, 101, 0.3)
	P.line(c, 210, 22, 210, 100, 0.25)
	for i = 0, 3 do P.line(c, 100 - i, 24 + i, 100 - i, 100 + i, 0.4); P.line(c, 320 + i, 24 + i, 320 + i, 100 + i, 0.4) end
	for i = 0, 8 do P.line(c, 108, 32 + i * 8, 204, 32 + i * 8, 0.6); P.line(c, 216, 32 + i * 8, 312, 32 + i * 8, 0.6) end
	script_lines(c, P, 110, 34, 90, 8, 311, 0.1)
	-- the damning entry, underlined twice
	P.rect(c, 218, 46, 300, 47, 0.05); P.rect(c, 218, 54, 290, 55, 0.05)
	P.rect(c, 218, 60, 300, 60, 0.05); P.rect(c, 218, 62, 300, 62, 0.05)
	-- water stain
	P.ellipse_fn(c, 280, 86, 26, 12, function(_, _, old) return old * 0.7 end)
end

------------------------------------------------------------
-- testimony (bust + subject sketch)
------------------------------------------------------------

C.doors3 = function(c, P)
	testimony(c, P, "han", function(c, P, cx, cy)
		door(c, P, cx - 20, cy - 40, 40, 80)
		-- three sound arcs
		for i = 1, 3 do P.ellipse_outline(c, cx + 34, cy, 8 * i, 12 * i, 0.5) end
		P.rect(c, cx - 60, cy - 46, cx + 20, cy - 46, 0.0)
	end)
end

C.alibi_jang = function(c, P)
	testimony(c, P, "han", function(c, P, cx, cy)
		-- Jang slumped over the table under a blanket
		P.line(c, cx - 60, cy + 20, cx + 60, cy + 20, 0.9)
		P.rect(c, cx - 58, cy + 21, cx + 58, cy + 24, 0.03)
		P.ellipse(c, cx - 6, cy + 4, 40, 16, 0.6)
		P.disc(c, cx - 40, cy + 8, 10, 0.85); P.ellipse(c, cx - 42, cy + 2, 10, 5, 0.03)
		bottle(c, P, cx + 30, cy + 20, 12, 34, 0.06, nil)
		-- z z z
		for i = 0, 2 do
			local x, y = cx - 30 + i * 10, cy - 20 - i * 10
			P.line(c, x, y, x + 6, y, 0.7); P.line(c, x + 6, y, x, y + 5, 0.7); P.line(c, x, y + 5, x + 6, y + 5, 0.7)
		end
	end)
end

C.resemblance = function(c, P)
	testimony(c, P, "han", function(c, P, cx, cy)
		-- Lim's face beside a childhood face
		P.bust(c, cx - 40, c.h - 1, P.PORTRAITS.lim)
		P.disc(c, cx + 50, cy - 4, 14, 0.9); P.ellipse(c, cx + 50, cy - 14, 15, 7, 0.03)
		P.set(c, cx + 45, cy - 5, 0.03); P.set(c, cx + 55, cy - 5, 0.03); P.line(c, cx + 47, cy + 4, cx + 53, cy + 4, 0.03)
		P.rect(c, cx + 40, cy + 12, cx + 60, cy + 30, 0.4)
		P.line(c, cx + 8, cy - 4, cx + 30, cy - 4, 0.5); P.line(c, cx + 8, cy + 2, cx + 30, cy + 2, 0.5)
	end)
end

C.overheard = function(c, P)
	testimony(c, P, "seo", function(c, P, cx, cy)
		-- a thin wall with two silhouettes on the far side
		P.rect(c, cx - 4, cy - 56, cx + 4, cy + 58, 0.5)
		P.fig(c, cx + 44, cy + 58, 100, 0.35)
		P.fig(c, cx + 96, cy + 58, 80, 0.35)
		cane(c, P, cx + 110, cy + 20, cx + 116, cy + 58, 0.9)
		for i = 1, 3 do P.ellipse_outline(c, cx - 20, cy, 6 * i, 9 * i, 0.4) end
	end)
end

C.baek_confession = function(c, P)
	testimony(c, P, "baek", function(c, P, cx, cy)
		-- the ship going down on the reef
		P.sea(c, cy + 10, 321)
		P.tri(c, cx - 50, cy + 4, cx + 30, cy + 26, cx + 40, cy - 10, 0.03)
		P.line(c, cx - 50, cy + 4, cx + 40, cy - 10, 0.8)
		P.line(c, cx, cy - 4, cx + 14, cy - 40, 0.8)
		P.ellipse(c, cx + 60, cy + 14, 24, 6, 0.03)
	end)
end

C.lie_chest = function(c, P)
	testimony(c, P, "baek", function(c, P, cx, cy)
		chest(c, P, cx - 40, cy - 6, 80, 36, false)
		-- a question mark
		P.ellipse_outline(c, cx + 70, cy - 26, 8, 8, 0.85)
		P.rect(c, cx + 62, cy - 26, cx + 62, cy - 18, 0.02)
		P.rect(c, cx + 70, cy - 18, cx + 70, cy - 8, 0.85)
		P.disc(c, cx + 70, cy - 2, 1.5, 0.85)
	end)
end

C.timeline_doyun = function(c, P)
	testimony(c, P, "doyun", function(c, P, cx, cy)
		door(c, P, cx - 60, cy - 40, 40, 80)
		key(c, P, cx + 10, cy - 10, 40, 0.9)
		-- clock at ten
		P.ring(c, cx + 60, cy + 24, 16, 0.85); P.ring(c, cx + 60, cy + 24, 15, 0.85)
		P.line(c, cx + 60, cy + 24, cx + 60, cy + 12, 0.85)
		P.line(c, cx + 60, cy + 24, cx + 51, cy + 18, 0.85)
	end)
end

C.lim_identity = function(c, P)
	testimony(c, P, "lim", function(c, P, cx, cy)
		photo_print(c, P, cx - 40, cy - 34, 90, 54)
		P.rect(c, cx + 62, cy - 10, cx + 100, cy - 9, 0.7); P.rect(c, cx + 62, cy, cx + 90, cy + 1, 0.7)
	end)
end

C.lim_silence = function(c, P)
	testimony(c, P, "lim", function(c, P, cx, cy)
		for i = 0, 2 do P.disc(c, cx - 20 + i * 20, cy, 3, 0.7) end
		-- distant police boat on the horizon
		P.sea(c, cy + 30, 331)
		P.rect(c, cx + 40, cy + 26, cx + 80, cy + 30, 0.03); P.rect(c, cx + 52, cy + 20, cx + 66, cy + 26, 0.03)
		P.line(c, cx + 40, cy + 26, cx + 80, cy + 26, 0.6)
	end)
end

C.jang_lim = function(c, P)
	testimony(c, P, "jang", function(c, P, cx, cy)
		-- a hand holding a spoon, tremor lines around it
		P.ellipse(c, cx, cy + 10, 18, 14, 0.7)
		for i = 0, 3 do P.rect(c, cx - 16 + i * 8, cy - 8, cx - 12 + i * 8, cy + 2, 0.7) end
		P.line(c, cx + 8, cy - 4, cx + 40, cy - 40, 0.9); P.line(c, cx + 9, cy - 4, cx + 41, cy - 40, 0.9)
		P.ellipse(c, cx + 44, cy - 46, 7, 5, 0.9)
		for i = 1, 3 do
			P.line(c, cx - 30 - i * 6, cy - 6 - i * 4, cx - 24 - i * 6, cy - 12 - i * 4, 0.5)
			P.line(c, cx + 30 + i * 6, cy + 18 + i * 3, cx + 36 + i * 6, cy + 12 + i * 3, 0.5)
		end
		P.line(c, cx - 40, cy + 26, cx + 60, cy + 26, 0.8)
	end)
end

return C
