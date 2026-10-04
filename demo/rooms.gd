extends RefCounted
## The demo floor: hand-made rooms built with small helpers so they're quick to edit.
## Grid legend: "#" solid, "-" one-way platform, "D" exit door, "." empty.
## Enemy positions are the tile a ground bot stands in (directly above the floor).

const T := 32
const COUNT := 9


static func build(index: int, dominant: String) -> Dictionary:
	match index:
		0: return _scrapheap()
		1: return _workbench("Workbench", "Install your salvage", 5)
		2: return _red_static()
		3: return _sweeper()
		4: return _generator()
		5: return _workbench("Scrapshop Workbench", "Rebuild before the last stretch", 3)
		6: return _crossfire()
		7: return _stalker(dominant)
		_: return _foreman()


static func _scrapheap() -> Dictionary:
	var r := _blank(44, 14, "The Scrapheap", "The gang dumped you here. Get out.")
	_solid(r, 7, 1, 36, 4)
	_plat(r, 1, 5, 7)
	_solid(r, 14, 10, 3, 3)
	_plat(r, 24, 9, 5)
	_door(r, 10, 12)
	r.spawn = Vector2i(3, 4)
	_sign(r, 4, 4, "Thin platforms: hold S and press Space to drop through.")
	_sign(r, 10, 12, "W or Space to jump. Hold it to keep bouncing.")
	_sign(r, 20, 12, "Left click fires your basic shot. The chassis always has it, even inside a field.")
	_enemy(r, "roller", 30, 12)
	_enemy(r, "roller", 38, 12)
	r.salvage = true
	return r


static func _workbench(title: String, sub: String, give: int) -> Dictionary:
	var r := _blank(22, 10, title, sub)
	_plat(r, 6, 6, 4)
	_door(r, 6, 8)
	r.spawn = Vector2i(2, 8)
	r.bench = Vector2i(11, 8)
	r.give = give
	_sign(r, 7, 8, "Stand at the workbench and press S. You can only change parts here.")
	return r


static func _red_static() -> Dictionary:
	var r := _blank(46, 16, "Red Static", "A red field: every red part shuts off inside it")
	_plat(r, 5, 12, 6)
	_plat(r, 15, 9, 6)
	_plat(r, 25, 9, 6)
	_plat(r, 35, 12, 6)
	_plat(r, 19, 6, 8)
	_solid(r, 22, 12, 2, 3)
	_rect(r, 16, 1, 14, 14, "red")
	_door(r, 12, 14)
	_sign(r, 5, 14, "Your parts are colored. A field turns off every part of its color. The chassis keeps working.")
	_enemy(r, "roller", 18, 14)
	_enemy(r, "roller", 28, 14)
	_enemy(r, "roller", 33, 14)
	_enemy(r, "gunner", 17, 8)
	_enemy(r, "gunner", 38, 11)
	r.salvage = true
	return r


static func _sweeper() -> Dictionary:
	var r := _blank(50, 16, "The Sweeper", "This blue field moves")
	_plat(r, 6, 12, 6)
	_plat(r, 16, 9, 7)
	_plat(r, 28, 9, 7)
	_plat(r, 40, 12, 6)
	_plat(r, 22, 6, 6)
	_rect(r, 8, 1, 5, 14, "blue", {"sweep": {"min": 4.0 * T, "max": 44.0 * T, "speed": 70.0}})
	_door(r, 12, 14)
	_enemy(r, "drone", 14, 5)
	_enemy(r, "drone", 28, 4)
	_enemy(r, "drone", 42, 6)
	_enemy(r, "charger", 22, 14)
	_enemy(r, "charger", 36, 14)
	r.salvage = true
	return r


static func _generator() -> Dictionary:
	var r := _blank(34, 22, "The Generator", "Purple everywhere. Find the generator.")
	_plat(r, 3, 18, 8)
	_plat(r, 20, 18, 9)
	_plat(r, 11, 15, 9)
	_plat(r, 3, 12, 7)
	_plat(r, 22, 12, 7)
	_plat(r, 13, 9, 8)
	_plat(r, 24, 6, 4)
	_solid(r, 28, 4, 5, 1)
	_rect(r, 1, 1, 32, 20, "purple", {"generator": Vector2(30.5 * T, 4 * T - 20)})
	_rect(r, 1, 13, 12, 8, "green", {"pulse": [3.0, 2.5]})
	_door(r, 18, 20)
	_sign(r, 5, 20, "This purple field fills the room. Shoot its generator on the top-right ledge to shut it down.")
	_enemy(r, "jammer", 17, 7, {"color": "red"})
	_enemy(r, "roller", 8, 20)
	_enemy(r, "roller", 25, 20)
	_enemy(r, "gunner", 14, 14)
	r.salvage = true
	return r


static func _crossfire() -> Dictionary:
	var r := _blank(48, 16, "Crossfire", "Overlapping fields, and bots that steal")
	_plat(r, 5, 12, 6)
	_plat(r, 14, 9, 6)
	_plat(r, 23, 6, 5)
	_plat(r, 31, 9, 6)
	_plat(r, 40, 12, 6)
	_rect(r, 12, 1, 14, 14, "red")
	_rect(r, 21, 1, 14, 14, "blue")
	_rect(r, 37, 6, 10, 9, "green", {"period": 4.0})
	_door(r, 12, 14)
	_sign(r, 5, 14, "Where fields overlap, both colors shut off. Scrappers steal a part on touch: destroy them to get it back.")
	_enemy(r, "scrapper", 24, 14)
	_enemy(r, "scrapper", 31, 14)
	_enemy(r, "gunner", 16, 8)
	_enemy(r, "gunner", 42, 11)
	_enemy(r, "jammer", 28, 4, {"color": "green"})
	r.salvage = true
	return r


static func _stalker(dominant: String) -> Dictionary:
	var r := _blank(50, 18, "The Stalker", "This field hunts you")
	_plat(r, 6, 14, 6)
	_plat(r, 16, 11, 7)
	_plat(r, 28, 11, 7)
	_plat(r, 40, 14, 6)
	_plat(r, 22, 8, 6)
	_circle(r, 44, 5, 100.0, dominant, {"follow": 45.0})
	_door(r, 14, 16)
	_sign(r, 5, 16, "This field follows you, and it picked the color you rely on most.")
	_enemy(r, "charger", 22, 16)
	_enemy(r, "charger", 40, 16)
	_enemy(r, "drone", 18, 6)
	_enemy(r, "drone", 34, 5)
	_enemy(r, "roller", 30, 16)
	_enemy(r, "gunner", 45, 16)
	return r


static func _foreman() -> Dictionary:
	var r := _blank(40, 16, "The Foreman", "Boss scrapper. Its field changes color.")
	_plat(r, 5, 12, 6)
	_plat(r, 29, 12, 6)
	_plat(r, 15, 8, 10)
	r.spawn = Vector2i(3, 14)
	_enemy(r, "boss", 30, 14)
	r.boss = true
	return r


# --- helpers ---

static func _blank(w: int, h: int, title: String, sub: String) -> Dictionary:
	var grid := []
	for y in h:
		var row := []
		for x in w:
			row.append("#" if x == 0 or y == 0 or x == w - 1 or y == h - 1 else ".")
		grid.append(row)
	return {
		"name": title, "sub": sub, "w": w, "h": h, "grid": grid,
		"spawn": Vector2i(2, h - 2), "enemies": [], "fields": [], "signs": [],
		"door": [], "give": 0, "salvage": false, "boss": false,
	}


static func _solid(r: Dictionary, x: int, y: int, w: int, h: int) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			r.grid[yy][xx] = "#"


static func _plat(r: Dictionary, x: int, y: int, length: int) -> void:
	for xx in range(x, x + length):
		r.grid[y][xx] = "-"


static func _door(r: Dictionary, y0: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		r.grid[y][r.w - 1] = "D"
		r.door.append(y)


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
