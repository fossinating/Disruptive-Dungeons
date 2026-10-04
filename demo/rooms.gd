extends RefCounted
## Floor generation and room building.
##
## A floor is a grid of same-size rooms joined by doors on any side. Every room has a central
## "spine" of platforms so the top and bottom openings are always reachable, plus a random
## layout on each side. Rooms are rebuilt from their own seed, so they come back the same when
## you backtrack.
## Grid legend: "#" solid, "-" one-way platform, "D" sealed door, "L" locked door, "." empty.

const T := 32
const W := 44
const H := 18
const GRID := Vector2i(6, 4)
const ROOM_COUNT := 10
const DIRS := {"left": Vector2i(-1, 0), "right": Vector2i(1, 0), "up": Vector2i(0, -1), "down": Vector2i(0, 1)}
const OPPOSITE := {"left": "right", "right": "left", "up": "down", "down": "up"}
const SIDE_DOOR_ROWS := [14, 15, 16]
const SHAFT_COLS := [20, 21, 22, 23]

# Platform layouts for one side of a room, written for the left side and mirrored for the right.
# They keep clear of the side door corridor (columns 0-3, rows 13-16) and the spine.
const SIDES := [
	[["plat", 3, 12, 6], ["plat", 8, 9, 5]],
	[["solid", 6, 15, 2, 2], ["plat", 2, 11, 7], ["plat", 9, 8, 4]],
	[["plat", 4, 13, 4], ["plat", 9, 10, 5], ["plat", 3, 7, 5]],
	[["solid", 4, 9, 7, 1], ["plat", 10, 13, 4]],
	[["solid", 8, 14, 3, 3], ["plat", 2, 10, 5], ["plat", 9, 7, 4]],
]

const FIELD_KINDS_BY_DEPTH := [
	["static", "sweep", "pulse"],
	["static", "sweep", "pulse", "cycle", "jammer", "generator"],
	["static", "sweep", "pulse", "cycle", "jammer", "generator", "overlap", "follow"],
]

const ENEMIES_BY_DEPTH := [
	["roller", "roller", "drone", "gunner"],
	["roller", "drone", "gunner", "charger"],
	["roller", "drone", "gunner", "charger", "scrapper"],
]

const FLOOR_SPAWN_COLS := [5, 6, 7, 9, 10, 11, 12, 31, 32, 33, 35, 36, 37, 38, 39]


# --- floor layout ---

static func generate_floor(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var start := Vector2i(1, rng.randi_range(1, GRID.y - 2))
	var cells := {start: _new_cell(rng)}
	var frontier: Array = [start]
	while cells.size() < ROOM_COUNT and not frontier.is_empty():
		var from: Vector2i = frontier[rng.randi_range(0, frontier.size() - 1)]
		var placed := false
		for d in _shuffled_dirs(rng):
			var to: Vector2i = from + DIRS[d]
			# The last column stays free so the boss room always has somewhere to go.
			if to.x < 0 or to.y < 0 or to.x >= GRID.x - 1 or to.y >= GRID.y or cells.has(to):
				continue
			cells[to] = _new_cell(rng)
			_link(cells, from, to, d)
			frontier.append(to)
			placed = true
			break
		if not placed:
			frontier.erase(from)

	# A few loops so the map isn't a pure tree.
	for pos in cells.keys():
		for d in ["right", "down"]:
			var to: Vector2i = pos + DIRS[d]
			if cells.has(to) and not cells[pos].doors.has(d) and rng.randf() < 0.3:
				_link(cells, pos, to, d)

	var depth := _depths(cells, start)

	# Boss: off the far end of the map, behind a horizontal locked door.
	var boss_from := start
	var boss_dir := "right"
	var best := -1
	for pos in cells:
		for d in ["right", "left"]:
			var to: Vector2i = pos + DIRS[d]
			if to.x < 0 or to.x >= GRID.x or cells.has(to):
				continue
			if depth[pos] > best or (depth[pos] == best and d == "right"):
				best = depth[pos]
				boss_from = pos
				boss_dir = d
	var boss: Vector2i = boss_from + DIRS[boss_dir]
	cells[boss] = _new_cell(rng)
	_link(cells, boss_from, boss, boss_dir)
	cells[boss].kind = "boss"
	cells[boss_from].locked = boss_dir
	depth[boss] = depth[boss_from] + 1
	for pos in cells:
		cells[pos].depth = depth[pos]

	cells[start].kind = "start"
	var candidates := cells.keys().filter(func(p): return cells[p].kind == "combat")
	# First workbench right next to the start, second one deeper in.
	var near := candidates.filter(func(p): return depth[p] == 1)
	if not near.is_empty():
		var wb: Vector2i = near[rng.randi_range(0, near.size() - 1)]
		cells[wb].kind = "bench"
		cells[wb].give = 5
		candidates.erase(wb)
	var deep := candidates.filter(func(p): return depth[p] >= 3 and p != boss_from)
	if not deep.is_empty():
		var wb2: Vector2i = deep[rng.randi_range(0, deep.size() - 1)]
		cells[wb2].kind = "bench"
		cells[wb2].give = 3
		candidates.erase(wb2)
	# The key goes to an elite in a combat room away from the boss door when possible.
	var key_rooms := candidates.filter(func(p): return depth[p] >= 2 and p != boss_from)
	if key_rooms.is_empty():
		key_rooms = candidates
	if not key_rooms.is_empty():
		cells[key_rooms[rng.randi_range(0, key_rooms.size() - 1)]].key = true

	return {"cells": cells, "start": start, "boss": boss, "boss_door": boss_from}


static func _new_cell(rng: RandomNumberGenerator) -> Dictionary:
	return {"doors": {}, "kind": "combat", "depth": 0, "key": false, "locked": "", "give": 0, "seed": rng.randi()}


static func _link(cells: Dictionary, a: Vector2i, b: Vector2i, d: String) -> void:
	cells[a].doors[d] = true
	cells[b].doors[OPPOSITE[d]] = true


static func _shuffled_dirs(rng: RandomNumberGenerator) -> Array:
	# Horizontal first more often than not: vertical shafts are slower to travel.
	var horizontal := ["left", "right"]
	var vertical := ["up", "down"]
	for arr in [horizontal, vertical]:
		if rng.randf() < 0.5:
			arr.reverse()
	return horizontal + vertical if rng.randf() < 0.65 else vertical + horizontal


static func _depths(cells: Dictionary, start: Vector2i) -> Dictionary:
	var depth := {start: 0}
	var queue: Array = [start]
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		for d in cells[pos].doors:
			var to: Vector2i = pos + DIRS[d]
			if not depth.has(to):
				depth[to] = depth[pos] + 1
				queue.append(to)
	return depth


# --- rooms ---

static func build(pos: Vector2i, floor_data: Dictionary, dominant: String) -> Dictionary:
	var cell: Dictionary = floor_data.cells[pos]
	var rng := RandomNumberGenerator.new()
	rng.seed = cell.seed
	var r := _blank("", "")
	r.pos = pos
	r.depth = cell.depth
	r.kind = cell.kind
	match cell.kind:
		"start": _start_room(r)
		"bench": _bench_room(r, cell)
		"boss": _boss_room(r, cell)
		_: _combat_room(r, cell, rng, dominant)
	if cell.kind != "boss":
		_spine(r, cell)
	_openings(r, cell)
	return r


static func _start_room(r: Dictionary) -> void:
	r.name = "The Scrapheap"
	r.sub = "The gang dumped you here. Find the key and the way out."
	# A sealed shelf you can only leave by dropping through its floor.
	_solid(r, 1, 1, 13, 6)
	_solid(r, 13, 7, 1, 3)
	_plat(r, 1, 10, 12)
	_solid(r, 8, 15, 2, 2)
	r.spawn = Vector2i(3, 9)
	_sign(r, 4, 9, "Thin platforms: hold S and press Space to drop through.")
	_sign(r, 5, 16, "W or Space to jump. Hold it to keep bouncing.")
	_sign(r, 12, 16, "Left click fires your basic shot. The map is top right: find an elite with the boss key.")
	_enemy(r, "roller", 33, 16)
	_enemy(r, "roller", 38, 16)
	r.salvage = true


static func _bench_room(r: Dictionary, cell: Dictionary) -> void:
	r.name = "Workbench"
	r.sub = "Install your salvage. Your hull gets repaired here."
	r.bench = Vector2i(8, 16)
	r.give = cell.give
	_plat(r, 3, 12, 6)
	_sign(r, 5, 16, "Stand at the workbench and press S. You can only change parts here.")


static func _boss_room(r: Dictionary, cell: Dictionary) -> void:
	r.name = "The Foreman"
	r.sub = "Boss scrapper. Its field changes color."
	r.boss = true
	_plat(r, 5, 13, 7)
	_plat(r, 32, 13, 7)
	_plat(r, 16, 9, 12)
	_enemy(r, "boss", 9 if cell.doors.has("right") else 34, 16)


static func _combat_room(r: Dictionary, cell: Dictionary, rng: RandomNumberGenerator, dominant: String) -> void:
	var tier := clampi(cell.depth - 1, 0, 2)
	var left: Array = SIDES[rng.randi_range(0, SIDES.size() - 1)]
	var right: Array = SIDES[rng.randi_range(0, SIDES.size() - 1)]
	_apply_side(r, left, false)
	_apply_side(r, right, true)

	var kinds: Array = FIELD_KINDS_BY_DEPTH[tier]
	var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
	var color: String = ["blue", "green", "red", "purple"][rng.randi_range(0, 3)]
	var extra_enemy := ""
	match kind:
		"static":
			r.name = "%s Static" % color.capitalize()
			r.sub = "Every %s part shuts off inside this field" % color
			var x: int = [1, 15, 29][rng.randi_range(0, 2)]
			_rect(r, x, 1, 14, H - 2, color)
		"sweep":
			r.name = "The Sweeper"
			r.sub = "This %s field moves" % color
			_rect(r, 4, 1, 5, H - 2, color, {"sweep": {"min": 2.0 * T, "max": (W - 7.0) * T, "speed": 70.0}})
		"pulse":
			r.name = "Pulse Chamber"
			r.sub = "The %s field switches on and off" % color
			_rect(r, 1, 1, W - 2, H - 2, color, {"pulse": [2.5, 3.0]})
		"cycle":
			r.name = "Color Cycler"
			r.sub = "Watch the stripes: they flash the next color"
			_rect(r, 12, 1, 20, H - 2, color, {"period": 4.0})
		"jammer":
			r.name = "Jammer Nest"
			r.sub = "The Jammer carries its field with it"
			extra_enemy = "jammer"
		"generator":
			r.name = "Generator Room"
			r.sub = "Shoot the generator up top to shut the field down"
			_rect(r, 1, 1, W - 2, H - 2, color, {"generator": Vector2(25.5 * T, 5 * T - 15)})
		"overlap":
			r.name = "Crossfire"
			r.sub = "Where fields overlap, both colors shut off"
			var other: String = ["blue", "green", "red", "purple"][(["blue", "green", "red", "purple"].find(color) + rng.randi_range(1, 3)) % 4]
			_rect(r, 6, 1, 18, H - 2, color)
			_rect(r, 20, 1, 18, H - 2, other)
		"follow":
			r.name = "The Stalker"
			r.sub = "This field hunts you, in the color you rely on most"
			_circle(r, W / 2, 4, 100.0, dominant, {"follow": 45.0})

	var pool: Array = ENEMIES_BY_DEPTH[tier]
	var count := mini(3 + cell.depth / 2, 6)
	var used_cols := []
	for i in count:
		var kind_e: String = pool[rng.randi_range(0, pool.size() - 1)]
		_place_enemy(r, rng, kind_e, used_cols, {})
	if extra_enemy == "jammer":
		_place_enemy(r, rng, "jammer", used_cols, {"color": color})
	if cell.key:
		var elite_kind: String = ["gunner", "charger", "roller"][rng.randi_range(0, 2)]
		_place_enemy(r, rng, elite_kind, used_cols, {"elite": true, "key": true})
		r.sub = "An elite here carries the boss key"
	r.salvage = true


static func _place_enemy(r: Dictionary, rng: RandomNumberGenerator, kind: String, used_cols: Array, opts: Dictionary) -> void:
	if kind == "drone" or kind == "jammer":
		_enemy(r, kind, rng.randi_range(6, W - 7), rng.randi_range(4, 8), opts)
		return
	for attempt in 20:
		var x: int = FLOOR_SPAWN_COLS[rng.randi_range(0, FLOOR_SPAWN_COLS.size() - 1)]
		if used_cols.has(x):
			continue
		if r.grid[H - 2][x] != "." or r.grid[H - 3][x] != "." or r.grid[H - 4][x] != ".":
			continue
		used_cols.append(x)
		_enemy(r, kind, x, H - 2, opts)
		return


static func _apply_side(r: Dictionary, side: Array, mirror: bool) -> void:
	for op in side:
		match op[0]:
			"plat":
				var x: int = (W - op[1] - op[3]) if mirror else op[1]
				_plat(r, x, op[2], op[3])
			"solid":
				var x: int = (W - op[1] - op[3]) if mirror else op[1]
				_solid(r, x, op[2], op[3], op[4])


## Central zig-zag platforms; always present so a top opening is always reachable.
static func _spine(r: Dictionary, cell: Dictionary) -> void:
	_plat(r, 15, 14, 7)
	_plat(r, 22, 11, 7)
	_plat(r, 15, 8, 7)
	_plat(r, 22, 5, 7)
	if cell.doors.has("up"):
		_plat(r, 18, 3, 8)


static func _openings(r: Dictionary, cell: Dictionary) -> void:
	r.openings = {}
	for d in cell.doors:
		var tiles := []
		match d:
			"left":
				for y in SIDE_DOOR_ROWS:
					tiles.append(Vector2i(0, y))
			"right":
				for y in SIDE_DOOR_ROWS:
					tiles.append(Vector2i(W - 1, y))
			"up":
				for x in SHAFT_COLS:
					tiles.append(Vector2i(x, 0))
			"down":
				for x in SHAFT_COLS:
					tiles.append(Vector2i(x, H - 1))
				# A one-way lid over the shaft: drop through it on purpose to go down.
				_plat(r, 19, H - 2, 6)
		for t in tiles:
			r.grid[t.y][t.x] = "L" if cell.locked == d else "."
		r.openings[d] = tiles


# --- helpers ---

static func _blank(title: String, sub: String) -> Dictionary:
	var grid := []
	for y in H:
		var row := []
		for x in W:
			row.append("#" if x == 0 or y == 0 or x == W - 1 or y == H - 1 else ".")
		grid.append(row)
	return {
		"name": title, "sub": sub, "w": W, "h": H, "grid": grid,
		"spawn": Vector2i(2, H - 2), "enemies": [], "fields": [], "signs": [],
		"openings": {}, "give": 0, "salvage": false, "boss": false,
	}


static func _solid(r: Dictionary, x: int, y: int, w: int, h: int) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			r.grid[yy][xx] = "#"


static func _plat(r: Dictionary, x: int, y: int, length: int) -> void:
	for xx in range(x, x + length):
		if r.grid[y][xx] == ".":
			r.grid[y][xx] = "-"


static func _rect(r: Dictionary, x: int, y: int, w: int, h: int, color: String, extra := {}) -> void:
	var f := {"shape": "rect", "pos": Vector2(x * T, y * T), "size": Vector2(w * T, h * T), "color": color}
	f.merge(extra)
	r.fields.append(f)


static func _circle(r: Dictionary, x: int, y: int, radius: float, color: String, extra := {}) -> void:
	var f := {"shape": "circle", "pos": Vector2((x + 0.5) * T, (y + 0.5) * T), "radius": radius, "color": color}
	f.merge(extra)
	r.fields.append(f)


static func _enemy(r: Dictionary, kind: String, x: int, y: int, opts := {}) -> void:
	r.enemies.append([kind, x, y, opts])


static func _sign(r: Dictionary, x: int, y: int, text: String) -> void:
	r.signs.append({"tile": Vector2i(x, y), "text": text})
