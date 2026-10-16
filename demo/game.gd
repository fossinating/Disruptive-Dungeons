extends Node2D
## Demo of docs/rework-proposal.md: four generated floors, each with its own boss, and the
## parts, fields and bots from the proposal.
## Everything is built in code so the slice can change quickly while the plan is still moving.
## Run with `-- --smoke` to step through every room headless and quit (used for CI-style checks).

const Parts := preload("res://demo/parts.gd")
const Rooms := preload("res://demo/rooms.gd")
const PlayerScript := preload("res://demo/player.gd")
const EnemyScript := preload("res://demo/enemy.gd")
const FieldScript := preload("res://demo/field.gd")
const Drawer := preload("res://demo/drawer.gd")
const UiDrawer := preload("res://demo/ui_drawer.gd")
const RoomView := preload("res://demo/room_view.gd")
const Sfx := preload("res://demo/sfx.gd")
const BenchUI := preload("res://demo/bench_ui.gd")
const Unlocks := preload("res://demo/unlocks.gd")

const T := 32
const GRAVITY := 980.0
const TEXT := Color("f0e6d8")
const MUTED := Color(0.72, 0.68, 0.66)
const PANEL := Color(0.07, 0.05, 0.09, 0.9)
const ACCENT := Color("ffcf6a")
# The jam camera sat at 2.5x and zoomed out to 2.0x with speed. That hides most of a combat
# room, so the demo starts wider and keeps the same speed zoom-out.
const BASE_ZOOM := 1.75
const SPEED_ZOOM_OUT := 0.35
# Extra camera room below the floor so the slot cards don't cover the player.
const HUD_MARGIN := 80
const RAM_MIN_SPEED := 360.0
const ELITE_SCHEMATIC_CHANCE := 0.25

enum Mode { TITLE, PLAY, BENCH, PAUSE, DEAD, WIN }

var mode: int = Mode.TITLE
var run: Dictionary = {}
var room: Dictionary = {}
var room_pos := Vector2i.ZERO
var player
var enemies: Array = []
var fields: Array = []
var gens: Array = []
var bullets: Array = []
var particles: Array = []
var floaters: Array = []
var bolts: Array = []
var pickups: Array = []
var flames: Array = []
var decoy := {}
var toasts: Array = []
var banner := {}
var raw_colors: Dictionary = {}
var disabled: Dictionary = {}
var status: Array = []
var god_mode := false
var shake := 0.0
var win_timer := -1.0
var door_open := false
var sfx

var _bg_view
var _wall_view
var _field_layer: Node2D
var _entity_layer: Node2D
var _fx
var _camera: Camera2D
var _hud
var _overlay: Control
var _bench
var _bodies: Array = []
var _lock_hint_t := 0.0
var _smoke := false
var _smoke_frames := 0
var _smoke_cells: Array = []


func _ready() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	RenderingServer.set_default_clear_color(Color("140e18"))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_input()

	_bg_view = RoomView.new()
	_bg_view.background = true
	add_child(_bg_view)
	_field_layer = Node2D.new()
	add_child(_field_layer)
	_wall_view = RoomView.new()
	add_child(_wall_view)
	_entity_layer = Node2D.new()
	add_child(_entity_layer)
	player = PlayerScript.new()
	player.game = self
	add_child(player)
	_fx = Drawer.new()
	_fx.draw_fn = _draw_fx
	add_child(_fx)
	_camera = Camera2D.new()
	_camera.zoom = Vector2(BASE_ZOOM, BASE_ZOOM)
	add_child(_camera)
	sfx = Sfx.new()
	add_child(sfx)

	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = UiDrawer.new()
	_hud.draw_fn = _draw_hud
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_hud)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.theme = _make_theme()
	layer.add_child(_overlay)
	_bench = BenchUI.new()
	_bench.game = self
	_bench.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bench.theme = _overlay.theme
	_bench.visible = false
	layer.add_child(_bench)

	var args := OS.get_cmdline_user_args()
	if args.has("--smoke") or args.has("--traverse") or args.has("--bestiary"):
		Unlocks.reset()
	new_run()
	_smoke = OS.get_cmdline_user_args().has("--smoke")
	if OS.get_cmdline_user_args().has("--traverse"):
		_traverse_test.call_deferred()
	elif OS.get_cmdline_user_args().has("--bestiary"):
		_bestiary_test.call_deferred()
	elif _smoke:
		mode = Mode.PLAY
		run.stash = Parts.PARTS.keys()
		for i in 4:
			run.slots[i] = {"id": run.stash.pop_front(), "cd": 0.0, "color": "red"}
		god_mode = true
		sfx.muted = true
	else:
		_show_title()


func _setup_input() -> void:
	var keys := {
		"dd_left": [KEY_A, KEY_LEFT], "dd_right": [KEY_D, KEY_RIGHT],
		"dd_jump": [KEY_W, KEY_SPACE, KEY_UP], "dd_down": [KEY_S, KEY_DOWN],
		"dd_slot0": [KEY_Q], "dd_slot1": [KEY_E], "dd_slot2": [KEY_R], "dd_slot3": [KEY_F],
		"dd_pause": [KEY_ESCAPE],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("dd_shoot"):
		InputMap.add_action("dd_shoot")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("dd_shoot", mb)


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 20
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.16, 0.12, 0.18)
	btn.border_color = Color(0.45, 0.4, 0.48)
	btn.set_border_width_all(2)
	btn.set_corner_radius_all(4)
	btn.set_content_margin_all(10)
	var hover := btn.duplicate()
	hover.border_color = ACCENT
	hover.bg_color = Color(0.22, 0.17, 0.2)
	th.set_stylebox("normal", "Button", btn)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", hover)
	th.set_stylebox("focus", "Button", hover)
	var pressed_toggle := hover.duplicate()
	pressed_toggle.bg_color = Color(0.3, 0.24, 0.16)
	th.set_stylebox("hover_pressed", "Button", pressed_toggle)
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", ACCENT)
	return th


# --- run and room flow ---

func new_run() -> void:
	var seed_value := randi()
	run = {
		"slots": [null, null, null, null],
		"stash": [],
		"seed": seed_value,
		"stats": {"time": 0.0, "kills": 0, "damage": {}, "offline": {}, "offline_count": {}, "rooms": 0},
	}
	for c in Parts.COLORS:
		run.stats.offline[c] = 0.0
		run.stats.offline_count[c] = 0
	player.hp = player.max_hp
	player.shield = player.max_shield
	start_floor(0)


## Generates floor `index` (0-3) and drops you at its start. Parts and hull carry over.
func start_floor(index: int) -> void:
	if run.has("cells"):
		run.stats.rooms += run.cells.values().filter(func(x): return x.visited).size()
	run.floor_num = index
	run.floor = Rooms.generate_floor(run.seed + index * 7919, index)
	run.cells = {}
	run.has_key = false
	run.unlocked = false
	run.revealed = false
	run.lift_open = false
	win_timer = -1.0
	disabled.clear()
	raw_colors.clear()
	load_room(run.floor.start)
	if index > 0:
		announce("Floor %d: %s" % [index + 1, Rooms.FLOORS[index].name], "The boss key is on an elite again")


func last_floor() -> bool:
	return run.floor_num >= Rooms.FLOORS.size() - 1


## What the run remembers about a room: visited, cleared, destroyed generators.
func cell_state(pos: Vector2i) -> Dictionary:
	if not run.cells.has(pos):
		run.cells[pos] = {"visited": false, "cleared": false, "gens_dead": []}
	return run.cells[pos]


## Loads a room. `entry` is the side the player comes in from ("" = the room's spawn point).
func load_room(pos: Vector2i, entry := "", from_pos := Vector2.ZERO) -> void:
	room_pos = pos
	for c in _entity_layer.get_children():
		c.queue_free()
	for c in _field_layer.get_children():
		c.queue_free()
	enemies.clear()
	fields.clear()
	gens.clear()
	bullets.clear()
	pickups.clear()
	flames.clear()
	decoy = {}
	bolts.clear()
	particles.clear()
	floaters.clear()

	var state := cell_state(pos)
	var first_visit: bool = not state.visited
	state.visited = true
	room = Rooms.build(pos, run.floor, dominant_color())
	if room.enemies.is_empty():
		state.cleared = true
	# Bots seal the room until they're destroyed.
	door_open = state.cleared
	if run.unlocked:
		_set_openings(".", true)
	if not door_open:
		_set_openings("D")
	_bg_view.set_room(room)
	_wall_view.set_room(room)
	_build_collision()

	if entry == "":
		player.global_position = Vector2((room.spawn.x + 0.5) * T, (room.spawn.y + 0.5) * T)
		player.reset_for_room(false)
	else:
		_place_at_entry(entry, from_pos)
		player.reset_for_room(true)

	var gen_index := 0
	for fd in room.fields:
		if fd.has("generator"):
			fd["gen_index"] = gen_index
			gen_index += 1
			if state.gens_dead.has(fd.gen_index):
				gens.append({"pos": fd.generator, "hp": 0.0, "max_hp": 90.0, "field": null, "fd": fd})
				continue
		_add_field(fd)
	if not state.cleared:
		for ed in room.enemies:
			var kind: String = ed[0]
			spawn_enemy(kind, _enemy_pos(kind, ed[1], ed[2]) + Vector2(ed[3].get("dx", 0.0), 0.0), ed[3])

	if room.has("bench"):
		player.hp = player.max_hp
		if first_visit:
			var found := give_random_parts(room.give)
			toast("Salvage pile: found %d parts. %s" % [found.size(), ", ".join(found.map(func(id): return Parts.PARTS[id].name))])
		toast("Hull repaired.")

	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = room.w * T
	_camera.limit_bottom = room.h * T + HUD_MARGIN
	_camera.global_position = player.global_position
	_camera.reset_smoothing()
	if first_visit:
		announce(room.name, room.sub)
	_update_status()


func _place_at_entry(entry: String, from_pos: Vector2) -> void:
	match entry:
		"left":
			player.global_position = Vector2(T + 16, from_pos.y)
		"right":
			player.global_position = Vector2(room.w * T - T - 16, from_pos.y)
		"up":
			player.global_position = Vector2(from_pos.x, T + 16)
		"down":
			# Pop up onto the lid over the shaft.
			player.global_position = Vector2(from_pos.x, (room.h - 2) * T - 16)
			player.velocity.y = -200.0


## Sets every opening tile to `tile`. Locked tiles stay locked unless `unlock` is set.
func _set_openings(tile: String, unlock := false) -> void:
	for d in room.openings:
		for t in room.openings[d]:
			if room.grid[t.y][t.x] == "L" and not unlock:
				continue
			room.grid[t.y][t.x] = tile


func _go(dir: String) -> void:
	var to: Vector2i = room_pos + Rooms.DIRS[dir]
	if run.floor.cells.has(to):
		load_room(to, Rooms.OPPOSITE[dir], player.global_position)


func _enemy_pos(kind: String, tx: int, ty: int) -> Vector2:
	var s: Dictionary = EnemyScript.STATS[kind]
	if s.flying:
		return Vector2((tx + 0.5) * T, (ty + 0.5) * T)
	# Stand the bot on the floor below its tile.
	return Vector2((tx + 0.5) * T, (ty + 1) * T - s.half.y - 2)


func _build_collision() -> void:
	for b in _bodies:
		b.queue_free()
	_bodies.clear()
	var solids := _new_body(1)
	var plats := _new_body(2)
	var doors := _new_body(1)
	for y in room.h:
		var x := 0
		while x < room.w:
			var c: String = room.grid[y][x]
			if c == ".":
				x += 1
				continue
			var start := x
			while x < room.w and room.grid[y][x] == c:
				x += 1
			var length := x - start
			match c:
				"#":
					_add_shape(solids, Rect2(start * T, y * T, length * T, T), false)
				"-":
					_add_shape(plats, Rect2(start * T, y * T, length * T, 8), true)
				"D", "L":
					_add_shape(doors, Rect2(start * T, y * T, length * T, T), false)


func _new_body(layer_bits: int) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = layer_bits
	b.collision_mask = 0
	add_child(b)
	_bodies.append(b)
	return b


func _add_shape(body: StaticBody2D, r: Rect2, one_way: bool) -> void:
	var cs := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = r.size
	cs.shape = s
	cs.position = r.get_center()
	cs.one_way_collision = one_way
	body.add_child(cs)


func _add_field(fd: Dictionary, carrier = null):
	var f = _spawn_field(fd, carrier)
	if fd.has("generator"):
		gens.append({"pos": fd.generator, "hp": 90.0, "max_hp": 90.0, "field": f, "fd": fd})
	return f


func _spawn_field(fd: Dictionary, carrier = null):
	var f = FieldScript.new()
	f.setup(fd)
	f.carrier = carrier
	_field_layer.add_child(f)
	fields.append(f)
	return f


func spawn_enemy(kind: String, pos: Vector2, opts: Dictionary):
	var e = EnemyScript.new()
	e.game = self
	e.setup(kind, opts)
	e.global_position = pos
	_entity_layer.add_child(e)
	enemies.append(e)
	if kind == "jammer":
		var fd := {"shape": "circle", "pos": pos, "radius": 130.0 if e.elite else 90.0, "color": opts.get("color", "red")}
		# Elite Jammers carry a bigger field that changes color.
		if e.elite:
			fd["period"] = 5.0
		e.field = _add_field(fd, e)
	elif kind == "boss":
		match e.boss_id:
			"foreman":
				e.field = _add_field({"shape": "circle", "pos": pos, "radius": 130.0, "color": "red", "period": 5.0}, e)
			"magnate":
				e.field = _add_field({"shape": "circle", "pos": pos, "radius": 120.0, "color": dominant_color()}, e)
				e.recolor_t = 6.0
			"chopper":
				var first := dominant_color()
				var second: String = Parts.COLORS.filter(func(c): return c != first).pick_random()
				for k in 2:
					_add_field({"shape": "circle", "pos": pos, "radius": 85.0, "color": [first, second][k], "orbit": {"radius": 150.0, "speed": 1.3, "angle": PI * k}}, e)
			"rust":
				# Not carried: it stalks you on its own.
				e.field = _add_field({"shape": "circle", "pos": pos + Vector2(0, -80), "radius": 110.0, "color": dominant_color(), "follow": 50.0})
				e.recolor_t = 8.0
	return e


func add_temp_field(fd: Dictionary) -> void:
	_spawn_field(fd)


func add_gen_field(fd: Dictionary) -> void:
	_add_field(fd)


## A boss saw: a big, slow shot that bounces off walls a few times.
func saw(from: Vector2, vel: Vector2, dmg: float, source: String) -> void:
	fire(from, vel, dmg, false, Color("d8d8e0"), source, false, 5.0)
	bullets[-1].bounces = 3
	bullets[-1].saw = true


func _unseal() -> void:
	door_open = true
	cell_state(room_pos).cleared = true
	_set_openings(".")
	_build_collision()
	_wall_view.queue_redraw()
	sfx.play("door")
	toast("Room clear. The doors are open.")


func _check_lock() -> void:
	var cell: Dictionary = run.floor.cells[room_pos]
	if cell.locked == "" or run.unlocked:
		return
	_lock_hint_t -= get_physics_process_delta_time()
	for t in room.openings[cell.locked]:
		if player.global_position.distance_to(Vector2((t.x + 0.5) * T, (t.y + 0.5) * T)) > 48.0:
			continue
		if run.has_key:
			run.unlocked = true
			run.has_key = false
			for tt in room.openings[cell.locked]:
				room.grid[tt.y][tt.x] = "." if door_open else "D"
			_build_collision()
			_wall_view.queue_redraw()
			sfx.play("door", 0.0, 0.7)
			toast("Boss door unlocked. The Foreman is waiting.")
		elif _lock_hint_t <= 0.0:
			_lock_hint_t = 4.0
			sfx.play("deny")
			toast("Locked. An elite somewhere on this floor carries the boss key.")
		return


func dominant_color() -> String:
	var counts := {}
	for s in run.get("slots", []):
		if s == null:
			continue
		for c in Parts.PARTS[s.id].colors:
			counts[c] = counts.get(c, 0) + 1
	if counts.is_empty():
		return Parts.COLORS.pick_random()
	var best := []
	var top := 0
	for c in counts:
		if counts[c] > top:
			top = counts[c]
			best = [c]
		elif counts[c] == top:
			best.append(c)
	return best.pick_random()


func give_random_parts(n: int) -> Array:
	var owned := {}
	for s in run.slots:
		if s != null:
			owned[s.id] = true
	for id in run.stash:
		owned[id] = true
	# Only parts you've found the schematic for (or that never needed one).
	var pool: Array = Unlocks.pool()
	var fresh := []
	for id in pool:
		if not owned.has(id):
			fresh.append(id)
	fresh.shuffle()
	var out := []
	for k in n:
		var id: String = fresh.pop_back() if not fresh.is_empty() else pool.pick_random()
		run.stash.append(id)
		out.append(id)
	return out


# --- main loop ---

func _physics_process(dt: float) -> void:
	if mode != Mode.PLAY:
		return
	if _smoke:
		_smoke_step()
	run.stats.time += dt
	player.step(dt)
	if mode != Mode.PLAY:
		return
	_update_status()
	# Overclock: parts recharge twice as fast inside a red field.
	var recharge := 2.0 if part_index("overclock") >= 0 else 1.0
	for i in run.slots.size():
		var s = run.slots[i]
		if s != null:
			s.cd = maxf(0.0, s.cd - dt * recharge)
		if Input.is_action_just_pressed("dd_slot%d" % i):
			_try_activate(i)

	for f in fields:
		f.step(dt, player.global_position)
	for f in fields.filter(func(f): return f.dead):
		fields.erase(f)
		f.queue_free()

	for e in enemies.duplicate():
		if not e.dead:
			e.step(dt)
			_check_contact(e)

	_step_bullets(dt)
	_step_flames(dt)
	_step_pickups(dt)
	_step_effects(dt)

	if room.has("bench") and _near_bench() and Input.is_action_just_pressed("dd_down") \
			and not Input.is_action_pressed("dd_jump"):
		open_bench()
	if _near_lift() and Input.is_action_just_pressed("dd_down") and not Input.is_action_pressed("dd_jump"):
		_ride_lift()
		return

	if not door_open and not room.boss and enemies.is_empty():
		_unseal()
		if room.salvage:
			pickups.append({"pos": player.global_position + Vector2(0, -10), "vel": Vector2(randf_range(-60, 60), -260), "t": 0.0, "crate": true})
	_check_lock()
	var pp: Vector2 = player.global_position
	if pp.x < 0.0:
		_go("left")
	elif pp.x > room.w * T:
		_go("right")
	elif pp.y < 0.0:
		_go("up")
	elif pp.y > room.h * T:
		_go("down")

	if win_timer > 0.0:
		win_timer -= dt
		if win_timer <= 0.0:
			_show_end(true)

	# Camera follows the player like the jam build, zooming out a little with speed.
	_camera.global_position = player.global_position
	var z := move_toward(_camera.zoom.x, BASE_ZOOM - clampf(player.velocity.length_squared() / 90000.0, 0.0, 1.0) * SPEED_ZOOM_OUT, 0.7 * dt)
	_camera.zoom = Vector2(z, z)
	shake = move_toward(shake, 0.0, 30.0 * dt)
	_camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))


func _smoke_step() -> void:
	_smoke_frames += 1
	if _smoke_cells.is_empty() and _smoke_frames == 1:
		_smoke_cells = run.floor.cells.keys()
		print("smoke: floor 1 of %d rooms" % _smoke_cells.size())
	var shots := OS.get_environment("DD_SHOTS")
	if shots != "" and _smoke_frames % 90 == 60:
		if room.has("bench") and _smoke_frames < 1000:
			open_bench()
		_save_shot.call_deferred(shots.path_join("room_%d_%d.png" % [room_pos.x, room_pos.y]))
	if _smoke_frames % 90 == 0:
		# Install the next four parts and fire each one, so every part gets used across the run.
		var ids: Array = Parts.PARTS.keys()
		for i in 4:
			var id: String = ids[(_smoke_frames / 90 * 4 + i) % ids.size()]
			run.slots[i] = {"id": id, "cd": 0.0, "color": "red"}
		_update_status()
		for i in 4:
			_try_activate(i)
		print("smoke: %s ok (%s, depth %d), %d bots, %d fields" % [room_pos, room.name, room.depth, enemies.size(), fields.size()])
		if _smoke_cells.is_empty() and last_floor():
			print("smoke: done")
			get_tree().quit()
		elif _smoke_cells.is_empty():
			start_floor(run.floor_num + 1)
			_smoke_cells = run.floor.cells.keys()
			print("smoke: floor %d of %d rooms" % [run.floor_num + 1, _smoke_cells.size()])
		else:
			load_room(_smoke_cells.pop_front())


## Test mode: clears each room, then uses the real controls to leave through every door,
## checking that each connection (including shafts and the locked boss door) is passable.
func _traverse_test() -> void:
	god_mode = true
	sfx.muted = true
	mode = Mode.PLAY
	var fails := 0
	var total := 0
	for floor_index in Rooms.FLOORS.size():
		if floor_index > 0:
			start_floor(floor_index)
		var r := await _traverse_floor()
		fails += r[0]
		total += r[1]
	print("traverse: %d of %d connections passable" % [total - fails, total])
	get_tree().quit()


## Test helper: destroys every bot, including any that split off while dying.
func _kill_all() -> void:
	for k in 5:
		for e in enemies.duplicate():
			e.take_damage(99999.0, "test")


func _traverse_floor() -> Array:
	var fails := 0
	var total := 0
	for pos in run.floor.cells:
		var cell: Dictionary = run.floor.cells[pos]
		if cell.kind == "boss":
			continue
		for d in cell.doors:
			total += 1
			load_room(pos)
			_kill_all()
			win_timer = -1.0
			for i in 3:
				await get_tree().physics_frame
			if cell.locked == d:
				run.unlocked = false
				run.has_key = true
			var target: Vector2i = pos + Rooms.DIRS[d]
			var y_floor := (Rooms.H - 1) * T - 16.0
			player.velocity = Vector2.ZERO
			match d:
				"left":
					player.global_position = Vector2(60, y_floor)
					Input.action_press("dd_left")
				"right":
					player.global_position = Vector2(Rooms.W * T - 60, y_floor)
					Input.action_press("dd_right")
				"up":
					player.global_position = Vector2(21.5 * T, 3 * T - 15)
					Input.action_press("dd_jump")
				"down":
					player.global_position = Vector2(21.5 * T, (Rooms.H - 2) * T - 15)
					Input.action_press("dd_down")
					Input.action_press("dd_jump")
			var arrived := false
			for f in 300:
				await get_tree().physics_frame
				if room_pos == target:
					arrived = true
					break
			for a in ["dd_left", "dd_right", "dd_jump", "dd_down"]:
				Input.action_release(a)
			var note := " (locked door)" if cell.locked == d else ""
			print("traverse: floor %d %s -> %s going %s%s: %s" % [run.floor_num + 1, pos, target, d, note, "ok" if arrived else "FAILED, stuck at %s" % player.global_position])
			if not arrived:
				fails += 1
	return [fails, total]


## Test mode: spawns every bot, plain and elite, in a room with the player, lets them act for a
## few seconds, then destroys them. Also checks that a Repair Bot rebuilds a generator.
func _bestiary_test() -> void:
	god_mode = true
	sfx.muted = true
	mode = Mode.PLAY
	var fails := 0
	var entries := []
	for kind in EnemyScript.STATS:
		if kind == "boss":
			for b in EnemyScript.BOSSES:
				entries.append(["boss", {"boss": b}])
		else:
			entries.append([kind, {}])
	for entry in entries:
		var kind: String = entry[0]
		for elite in ([false] if kind == "boss" else [false, true]):
			load_room(run.floor.boss if kind == "boss" else run.floor.start)
			_kill_all()
			win_timer = -1.0
			player.global_position = Vector2(12 * T, (Rooms.H - 2) * T)
			var opts := {"elite": elite, "color": "blue", "face": -1.0}
			opts.merge(entry[1])
			var e = spawn_enemy(kind, _enemy_pos(kind, 30, Rooms.H - 2), opts)
			if kind == "boss":
				# Straight to the second phase, so both get exercised.
				for f in 200:
					await get_tree().physics_frame
				e.hp = e.max_hp * 0.4
			var wounded = spawn_enemy("roller", _enemy_pos("roller", 36, Rooms.H - 2), {})
			# Keep the doors (and the floor shaft) sealed, like a real fight.
			door_open = false
			_set_openings("D")
			_build_collision()
			wounded.hp = 5.0
			for f in 240:
				await get_tree().physics_frame
			var alive: bool = is_instance_valid(e) and not e.dead
			if alive and not Rect2(0, 0, room.w * T, room.h * T).has_point(e.global_position):
				print("bestiary: %s left the room at %s" % [kind, e.global_position])
				alive = false
			var name: String = e.label() if alive and kind == "boss" else kind
			_kill_all()
			await get_tree().physics_frame
			var ok: bool = alive and count_kind(kind) == 0
			# Bosses always drop a schematic while any are still locked.
			if kind == "boss" and not pickups.any(func(p): return p.has("schematic")):
				print("bestiary: %s dropped no schematic" % name)
				ok = false
			print("bestiary: %s%s %s" % ["elite " if elite else "", name, "ok" if ok else "FAILED"])
			if not ok:
				fails += 1

	# Repair Bot vs. a destroyed generator.
	load_room(run.floor.start)
	_kill_all()
	win_timer = -1.0
	add_gen_field({"shape": "rect", "pos": Vector2(20 * T, T), "size": Vector2(10 * T, 10 * T), "color": "green", "generator": Vector2(25.5 * T, 5 * T - 15), "gen_index": 0})
	_hit_gen(gens[0], 99999.0)
	player.global_position = Vector2(3 * T, (Rooms.H - 2) * T)
	spawn_enemy("repair", gens[0].pos + Vector2(200, 0), {})
	var rebuilt := false
	for f in 900:
		await get_tree().physics_frame
		if gens[0].hp > 0.0:
			rebuilt = true
			break
	var remembered: bool = not cell_state(room_pos).gens_dead.has(0)
	print("bestiary: repair bot rebuilds a generator %s" % ("ok" if rebuilt and remembered else "FAILED"))
	if not (rebuilt and remembered):
		fails += 1
	fails += await _part_checks()
	print("bestiary: %d failures" % fails)
	get_tree().quit()


## Checks that the newer parts land hits: stomp, flak, afterburner and decoy.
func _part_checks() -> int:
	var fails := 0
	var floor_y := (Rooms.H - 1) * T - 16.0
	for id in ["pogo", "flak", "afterburner", "decoy"]:
		load_room(run.floor.start)
		_kill_all()
		await get_tree().physics_frame
		win_timer = -1.0
		run.slots = [{"id": id, "cd": 0.0, "color": "red"}, null, null, null]
		var target = spawn_enemy("tank", _enemy_pos("tank", 30, Rooms.H - 2), {})
		target.speed_mult = 0.0
		door_open = false
		_set_openings("D")
		_build_collision()
		var ok := false
		match id:
			"pogo":
				player.global_position = target.global_position + Vector2(0, -target.half.y - 60)
				player.velocity = Vector2(0, 300)
			"flak":
				player.global_position = Vector2(24 * T, floor_y)
				player.aim = Vector2.RIGHT
				_update_status()
				player.activate("flak", 1.0)
			"afterburner":
				player.global_position = Vector2(26 * T, floor_y)
			"decoy":
				player.global_position = Vector2(12 * T, floor_y)
				_update_status()
				_try_activate(0)
				player.global_position.x += 200.0
				ok = not decoy.is_empty() and target_pos() == decoy.pos
		for f in 90:
			if id == "afterburner":
				# Run back and forth through the tank.
				player.velocity.x = 600.0 * (1.0 if f % 40 < 20 else -1.0)
			await get_tree().physics_frame
		if id != "decoy":
			ok = target.hp < target.max_hp
		print("parts: %s %s" % [Parts.PARTS[id].name, "ok" if ok else "FAILED"])
		if not ok:
			fails += 1
	return fails


func _save_shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	if mode == Mode.BENCH:
		close_bench()


func _update_status() -> void:
	var raw := {}
	for f in fields:
		if f.on and not f.dead and f.contains(player.global_position):
			raw[f.color] = true
	var shielded := ""
	for s in run.slots:
		if s != null and s.id == "cage":
			shielded = s.color
	var now := raw.duplicate()
	if shielded != "":
		now.erase(shielded)

	var lost := 0
	for c in now:
		if not disabled.has(c):
			_on_color_lost(c, lost)
			lost += 1
	for c in disabled:
		if not now.has(c):
			sfx.play("up_" + c, -6.0)
	if shielded != "" and raw.has(shielded) and not raw_colors.has(shielded):
		floater(player.global_position + Vector2(0, -40), "%s SHIELDED" % Parts.COLOR_NAME[shielded].to_upper(), Parts.ui_color(shielded))
	raw_colors = raw
	disabled = now
	if mode == Mode.PLAY:
		for c in disabled:
			run.stats.offline[c] += get_physics_process_delta_time()

	status = []
	for i in run.slots.size():
		var s = run.slots[i]
		if s == null:
			status.append({})
			continue
		var p: Dictionary = Parts.PARTS[s.id]
		var on := true
		var reason := ""
		if p.get("overload", false):
			on = raw.has(p.colors[0])
			reason = "Needs a %s field" % Parts.COLOR_NAME[p.colors[0]].to_lower()
		else:
			for c in p.colors:
				if disabled.has(c):
					on = false
					reason = "%s field" % Parts.COLOR_NAME[c]
		status.append({"on": on, "reason": reason, "syn": 0, "pot": 1.0})
	for i in status.size():
		if status[i].is_empty() or not status[i].on:
			continue
		var mine: Array = Parts.PARTS[run.slots[i].id].colors
		var syn := 0
		for j in status.size():
			if j == i or status[j].is_empty() or not status[j].on:
				continue
			for c in Parts.PARTS[run.slots[j].id].colors:
				if mine.has(c):
					syn += 1
					break
		var pot := 1.0 + Parts.SYNERGY_PER_PART * syn
		if shielded != "" and mine.has(shielded):
			pot *= Parts.SHIELD_PENALTY
		status[i].syn = syn
		status[i].pot = pot


func _on_color_lost(c: String, stack: int) -> void:
	sfx.play("down_" + c, -2.0)
	run.stats.offline_count[c] += 1
	var names := []
	for s in run.slots:
		if s != null and Parts.PARTS[s.id].colors.has(c) and not Parts.PARTS[s.id].get("overload", false):
			names.append(Parts.PARTS[s.id].name)
	var text := "%s OFFLINE" % Parts.COLOR_NAME[c].to_upper()
	var y := -64.0 - stack * 26.0
	if names.size() > 0:
		text += ": " + ", ".join(names)
	floater(player.global_position + Vector2(0, y), text, Parts.ui_color(c), 1.8, 20)


## Index of the first installed, working part with this id, or -1.
func part_index(id: String) -> int:
	for i in run.slots.size():
		var s = run.slots[i]
		if s != null and s.id == id and i < status.size() and not status[i].is_empty() and status[i].on:
			return i
	return -1


## Strength multiplier for a part (synergy and shield penalty), 1.0 if it isn't working.
func pot(id: String) -> float:
	var i := part_index(id)
	return status[i].pot if i >= 0 else 1.0


func owned_colors() -> Dictionary:
	var out := {}
	for s in run.get("slots", []):
		if s != null:
			for c in Parts.PARTS[s.id].colors:
				out[c] = true
	return out


func _try_activate(i: int) -> void:
	var s = run.slots[i]
	if s == null:
		return
	var p: Dictionary = Parts.PARTS[s.id]
	if not p.active:
		return
	if not status[i].on:
		sfx.play("deny", -6.0)
		floater(player.global_position + Vector2(0, -36), "%s OFFLINE" % p.name.to_upper(), Color(0.7, 0.7, 0.7), 0.8, 16)
		return
	if s.cd > 0.0:
		sfx.play("deny", -12.0)
		return
	if player.activate(s.id, status[i].pot):
		# Synergy also shortens cooldowns a little.
		s.cd = p.cd / (1.0 + 0.5 * (status[i].pot - 1.0))


func _check_contact(e) -> void:
	var r: Rect2 = e.hit_rect()
	var pp: Vector2 = player.global_position
	var closest := Vector2(clampf(pp.x, r.position.x, r.end.x), clampf(pp.y, r.position.y, r.end.y))
	if closest.distance_to(pp) > PlayerScript.RADIUS:
		return
	var away: Vector2 = (pp - e.global_position).normalized()
	var speed: float = player.velocity.length()
	# Ram only counts above normal top speed: Boost, Heat Vent, recoil or a long fall.
	if player.try_stomp(e):
		return
	if part_index("ram") >= 0 and speed > RAM_MIN_SPEED:
		if e.ram_cd <= 0.0:
			e.ram_cd = 0.35
			e.take_damage((8.0 + (speed - RAM_MIN_SPEED) * 0.05) * pot("ram"), "Ram Plating", -away * 260.0 + Vector2(0, -120), -away)
			player.velocity *= 0.8
			player.invuln = maxf(player.invuln, 0.15)
			sfx.play("slam", -8.0, 1.6)
			add_shake(3.0)
		return
	if e.kind == "scrapper" and e.carried == null:
		_steal_part(e)
		return
	var dmg: float = e.contact
	if e.state == "dash":
		dmg = 24.0 if e.kind == "boss" else 20.0
	if dmg > 0.0:
		player.hurt(dmg, away * 260.0 + Vector2(0, -160))


func _steal_part(e) -> void:
	var filled := []
	for i in run.slots.size():
		if run.slots[i] != null:
			filled.append(i)
	if filled.is_empty():
		player.hurt(6.0, Vector2(0, -120))
		return
	var i: int = filled.pick_random()
	e.carried = run.slots[i]
	e.carried_slot = i
	run.slots[i] = null
	sfx.play("hack", -2.0, 0.7)
	toast("A Scrapper stole your %s. Destroy it to get the part back." % Parts.PARTS[e.carried.id].name)
	player.invuln = maxf(player.invuln, 0.6)


func _near_bench() -> bool:
	var b := Vector2((room.bench.x + 0.5) * T, (room.bench.y + 0.5) * T)
	var d: Vector2 = player.global_position - b
	return absf(d.x) < 40.0 and absf(d.y) < 48.0


func _near_lift() -> bool:
	if not room.has("lift") or not run.lift_open:
		return false
	var l := Vector2((room.lift.x + 0.5) * T, (room.lift.y + 0.5) * T)
	var d: Vector2 = player.global_position - l
	return absf(d.x) < 48.0 and absf(d.y) < 48.0


func _ride_lift() -> void:
	sfx.play("door", 0.0, 0.5)
	# Some hull back between floors.
	player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.4)
	start_floor(run.floor_num + 1)


func open_bench() -> void:
	mode = Mode.BENCH
	_bench.open()


func close_bench() -> void:
	_bench.visible = false
	mode = Mode.PLAY
	_update_status()


# --- combat helpers used by player and enemies ---

func fire(from: Vector2, vel: Vector2, dmg: float, friendly: bool, color: Color, source: String, pierce: bool, life := 1.4) -> void:
	bullets.append({"pos": from, "vel": vel, "dmg": dmg, "friendly": friendly, "color": color, "source": source, "pierce": pierce, "life": life, "hit": [], "grav": 0.0, "blast": 0.0, "bounces": 0, "saw": false})


## A slow shell with optional gravity. With `blast` > 0 it explodes when it hits anything.
func shell(from: Vector2, vel: Vector2, dmg: float, friendly: bool, color: Color, source: String, grav: float, blast: float) -> void:
	fire(from, vel, dmg, friendly, color, source, false, 4.0)
	bullets[-1].grav = grav
	bullets[-1].blast = blast


func explode(at: Vector2, radius: float, dmg: float, friendly: bool, source: String) -> void:
	sfx.play("slam", -8.0, 1.3)
	add_shake(3.0)
	for i in 16:
		particle(at, Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60, radius * 3.0), Color("ff8a3d").lerp(Color("ffd060"), randf()), 0.35, 4.0)
	if friendly:
		for e in enemies.duplicate():
			if not e.dead and e.hit_rect().grow(radius).has_point(at):
				e.take_damage(dmg, source, (e.global_position - at).normalized() * 200.0)
		for g in gens:
			if g.pos.distance_to(at) < radius + 14.0:
				_hit_gen(g, dmg)
	elif player.global_position.distance_to(at) < radius + PlayerScript.RADIUS:
		player.hurt(dmg, (player.global_position - at).normalized() * 220.0 + Vector2(0, -120))


## Where the bots aim: the player, or a Decoy while one is up.
func target_pos() -> Vector2:
	if not decoy.is_empty():
		return decoy.pos
	return player.global_position


func drop_decoy(at: Vector2, duration: float) -> void:
	decoy = {"pos": at, "t": duration}
	burst(at, Parts.ui_color("purple"), 14, 140.0)


func add_flame(at: Vector2, dmg: float) -> void:
	if flames.size() < 80:
		flames.append({"pos": at, "life": 0.7, "dmg": dmg})


## Afterburner fire: burns each bot it touches every few tenths of a second.
func _step_flames(dt: float) -> void:
	if not decoy.is_empty():
		decoy.t -= dt
		if decoy.t <= 0.0:
			burst(decoy.pos, Parts.ui_color("purple"), 10, 100.0)
			decoy = {}
	for f in flames:
		f.life -= dt
		if randf() < 0.3:
			particle(f.pos + Vector2(randf_range(-6, 6), 0), Vector2(randf_range(-20, 20), -80), Color("ff8a3d").lerp(Color("ffd060"), randf()), 0.3, 3.0)
	flames = flames.filter(func(f): return f.life > 0.0)
	if flames.is_empty():
		return
	for e in enemies.duplicate():
		if e.dead or e.burn_cd > 0.0:
			continue
		var r: Rect2 = e.hit_rect().grow(10.0)
		for f in flames:
			if r.has_point(f.pos):
				e.burn_cd = 0.3
				e.take_damage(f.dmg, "Afterburner")
				break


## The first wall point between a and b, or b.
func ray_end(a: Vector2, b: Vector2) -> Vector2:
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(a, b, 1))
	return b if hit.is_empty() else hit.position


func nearest_field(from: Vector2):
	var best = null
	var best_d := INF
	for f in fields:
		if f.dead or not f.on:
			continue
		var d: float = f.distance_to_point(from)
		if d < best_d:
			best = f
			best_d = d
	return best


## For Repair Bots: the hurt bot that's missing the most health.
func most_damaged_enemy(exclude):
	var best = null
	var best_missing := 4.0
	for e in enemies:
		if e == exclude or e.dead or e.kind == "boss":
			continue
		if e.max_hp - e.hp > best_missing:
			best = e
			best_missing = e.max_hp - e.hp
	return best


func dead_gen():
	for g in gens:
		if g.hp <= 0.0:
			return g
	return null


func rebuild_gen(g: Dictionary) -> void:
	g.hp = g.max_hp
	g.field = _spawn_field(g.fd)
	cell_state(room_pos).gens_dead.erase(g.fd.gen_index)
	sfx.play("door", -4.0, 1.4)
	burst(g.pos, Parts.ui_color(g.field.color), 20, 160.0)
	toast("A Repair Bot rebuilt the generator.")


func los(a: Vector2, b: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func nearest_enemy(from: Vector2, max_dist: float, need_los: bool, exclude := []):
	var best = null
	var best_d := max_dist
	for e in enemies:
		if e.dead or exclude.has(e):
			continue
		var d := from.distance_to(e.global_position)
		if d < best_d and (not need_los or los(from, e.global_position)):
			best = e
			best_d = d
	return best


func chain_lightning(from: Vector2, dmg: float) -> void:
	var hit := []
	var cur := from
	for k in 3:
		var e = nearest_enemy(cur, 220.0 if k == 0 else 150.0, true, hit)
		if e == null:
			break
		bolts.append({"a": cur, "b": e.global_position, "t": 0.18})
		hit.append(e)
		cur = e.global_position
		e.take_damage(dmg, "Static Coil")
	if not hit.is_empty():
		sfx.play("zap", -4.0)


func vent_blast(from: Vector2, dir: Vector2, dmg: float) -> void:
	for i in 18:
		var a := dir.rotated(randf_range(-0.5, 0.5))
		particle(from, a * randf_range(200, 380), Color("ff8a3d").lerp(Color("ffd060"), randf()), 0.35, 4.0)
	for e in enemies.duplicate():
		var to: Vector2 = e.global_position - from
		if to.length() < 90.0 and absf(dir.angle_to(to)) < 0.7:
			e.take_damage(dmg, "Heat Vent", dir * 300.0, dir)


func shockwave(at: Vector2, radius: float, dmg: float, source: String, color: Color) -> void:
	for i in 20:
		var a := Vector2.RIGHT.rotated(randf() * PI + PI)
		particle(at, Vector2(a.x * randf_range(150, 300), a.y * randf_range(40, 140)), color, 0.4, 3.0)
	for e in enemies.duplicate():
		var to: Vector2 = e.global_position - at
		if absf(to.x) < radius + e.half.x and absf(to.y) < 60.0 + e.half.y:
			e.take_damage(dmg, source, Vector2(signf(to.x) * 200.0, -200.0))
	for g in gens:
		if g.pos.distance_to(at) < radius:
			_hit_gen(g, dmg)


func boss_slam(at: Vector2, radius: float, dmg: float) -> void:
	add_shake(9.0)
	sfx.play("slam")
	for i in 30:
		var a := Vector2.RIGHT.rotated(randf() * PI + PI)
		particle(at, Vector2(a.x * randf_range(200, 420), a.y * randf_range(40, 160)), Color("ff8a5a"), 0.5, 4.0)
	var d: Vector2 = player.global_position - at
	if player.is_on_floor() and absf(d.x) < radius and absf(d.y) < 70.0:
		player.hurt(dmg, Vector2(signf(d.x) * 220.0, -320.0))


func hack_nearest(from: Vector2) -> bool:
	var best = null
	var best_d := 200.0
	for f in fields:
		var d: float = f.distance_to_point(from)
		if d < best_d:
			best = f
			best_d = d
	if best == null:
		floater(from + Vector2(0, -36), "NO FIELD IN RANGE", Color(0.7, 0.7, 0.7), 0.8, 16)
		sfx.play("deny", -6.0)
		return false
	best.color = best.next_color()
	best.cycle_t = 0.0
	best.step(0.0, player.global_position)
	sfx.play("hack")
	floater(from + Vector2(0, -36), "HACKED → %s" % Parts.COLOR_NAME[best.color].to_upper(), Parts.ui_color(best.color), 1.0, 20)
	bolts.append({"a": from, "b": best.center() if best_d > 0.0 else from + Vector2(0, -30), "t": 0.25, "color": Parts.ui_color("purple")})
	return true


func on_enemy_killed(e) -> void:
	run.stats.kills += 1
	enemies.erase(e)
	burst(e.global_position, Color("ffb070"), 18, 220.0)
	sfx.play("kill", -4.0, 0.7 if e.kind == "boss" else 1.0)
	add_shake(10.0 if e.kind == "boss" else 2.0)
	if e.drops_key:
		pickups.append({"pos": e.global_position, "vel": Vector2(0, -300), "t": 0.0, "key": true})
		toast("The elite dropped the boss key.")
	if e.kind == "boss" or (e.elite and randf() < ELITE_SCHEMATIC_CHANCE):
		drop_schematic(e.global_position)
	if e.carried != null:
		pickups.append({"pos": e.global_position, "vel": Vector2(0, -260), "t": 0.0, "slot": e.carried, "slot_index": e.carried_slot})
	if e.kind == "splitter":
		# Elites split into three.
		var n := 3 if e.elite else 2
		for i in n:
			var s = spawn_enemy("splitling", e.global_position + Vector2((i - (n - 1) / 2.0) * 22.0, 8.0), {})
			s.velocity = Vector2((i - (n - 1) / 2.0) * 200.0, -260.0)
			s.speed_mult = e.speed_mult
	if e.kind == "boss":
		for other in enemies.duplicate():
			other.take_damage(999.0, "Boss death")
		for f in fields:
			f.dead = true
		for g in gens:
			g.hp = 0.0
		if last_floor():
			win_timer = 2.5
			announce("%s is scrap" % e.label(), "The exit is yours")
		else:
			run.lift_open = true
			announce("%s is scrap" % e.label(), "The freight lift is running. Stand on it and press S")
	e.queue_free()


## Drops a schematic for a part you haven't unlocked yet, if there are any left.
func drop_schematic(at: Vector2) -> bool:
	var left: Array = Unlocks.still_locked()
	for p in pickups:
		left.erase(p.get("schematic", ""))
	if left.is_empty():
		return false
	pickups.append({"pos": at, "vel": Vector2(randf_range(-60, 60), -320), "t": 0.0, "schematic": left.pick_random()})
	return true


func _hit_gen(g: Dictionary, dmg: float) -> void:
	if g.hp <= 0.0:
		return
	g.hp -= dmg
	record_damage("Generator", 0.0)
	if g.hp <= 0.0:
		g.field.dead = true
		cell_state(room_pos).gens_dead.append(g.fd.gen_index)
		burst(g.pos, Parts.ui_color(g.field.color), 30, 260.0)
		sfx.play("kill")
		add_shake(6.0)
		toast("Generator destroyed. Its field is down.")
	else:
		sfx.play("hit", -8.0, 0.6)


func record_damage(source: String, amount: float) -> void:
	if amount > 0.0:
		run.stats.damage[source] = run.stats.damage.get(source, 0.0) + amount


func count_kind(kind: String) -> int:
	return enemies.filter(func(e): return e.kind == kind and not e.dead).size()


func player_died() -> void:
	if mode != Mode.PLAY:
		return
	burst(player.global_position, Color("cfe8ff"), 30, 260.0)
	sfx.play("kill", 0.0, 0.6)
	_show_end(false)


# --- simulation of bullets, pickups and effects ---

func _step_bullets(dt: float) -> void:
	var space := get_world_2d().direct_space_state
	var keep := []
	for b in bullets:
		b.life -= dt
		b.vel.y += b.grav * dt
		var next: Vector2 = b.pos + b.vel * dt
		# Shells land on platforms too.
		var q := PhysicsRayQueryParameters2D.create(b.pos, next, 1 | (2 if b.blast > 0.0 and b.vel.y > 0.0 else 0))
		var wall := space.intersect_ray(q)
		var alive: bool = b.life > 0.0
		if not wall.is_empty():
			particle(wall.position, -b.vel.normalized() * 60.0, b.color, 0.15, 2.0)
			next = wall.position
			if b.bounces > 0:
				b.bounces -= 1
				b.vel = b.vel.bounce(wall.normal)
				next += wall.normal * 2.0
				sfx.play("hit", -14.0, 1.6)
			else:
				alive = false
		b.pos = next
		if alive and b.friendly:
			for e in enemies.duplicate():
				if e.dead or b.hit.has(e):
					continue
				if e.hit_rect().grow(3.0).has_point(b.pos):
					var landed: bool = b.blast > 0.0 or e.take_damage(b.dmg, b.source, b.vel.normalized() * 60.0, b.vel.normalized())
					b.hit.append(e)
					if not b.pierce or not landed:
						alive = false
						break
			if alive:
				for g in gens:
					if g.hp > 0.0 and Rect2(g.pos - Vector2(10, 14), Vector2(20, 28)).has_point(b.pos):
						_hit_gen(g, b.dmg)
						alive = false
						break
		elif alive and b.pos.distance_to(player.global_position) < PlayerScript.RADIUS + (12.0 if b.saw else 3.0):
			if b.blast <= 0.0:
				player.hurt(b.dmg, b.vel.normalized() * 120.0)
			alive = false
		if alive:
			keep.append(b)
		elif b.blast > 0.0:
			explode(b.pos, b.blast, b.dmg, b.friendly, b.source)
	bullets = keep


func _step_pickups(dt: float) -> void:
	var space := get_world_2d().direct_space_state
	var keep := []
	for p in pickups:
		p.t += dt
		p.vel.y += GRAVITY * dt
		var next: Vector2 = p.pos + p.vel * dt
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(p.pos, next + Vector2(0, 8), 1 | 2))
		if not hit.is_empty() and p.vel.y > 0.0:
			p.pos = hit.position - Vector2(0, 8)
			p.vel = Vector2.ZERO
		else:
			p.pos = next
		if p.t > 0.4 and p.pos.distance_to(player.global_position) < 30.0:
			_collect(p)
		else:
			keep.append(p)
	pickups = keep


func _collect(p: Dictionary) -> void:
	sfx.play("pickup", -4.0)
	if p.get("key", false):
		run.has_key = true
		toast("You have the boss key. The locked door is gold on the map.")
		return
	if p.has("schematic"):
		var id: String = p.schematic
		Unlocks.unlock(id)
		run.stash.append(id)
		run.stats.schematics = run.stats.get("schematics", 0) + 1
		sfx.play("door", -2.0, 1.6)
		announce("Schematic: %s" % Parts.PARTS[id].name, "It can show up in every run from now on. This one goes in your stash.")
		return
	if p.get("crate", false):
		var got := give_random_parts(1)
		toast("Salvaged: %s (%s). Install it at the next workbench." % [Parts.PARTS[got[0]].name, Parts.color_line(got[0])])
		return
	var slot: Dictionary = p.slot
	if run.slots[p.slot_index] == null:
		run.slots[p.slot_index] = slot
		toast("Got your %s back." % Parts.PARTS[slot.id].name)
	else:
		run.stash.append(slot.id)
		toast("Got your %s back. It went to the stash." % Parts.PARTS[slot.id].name)


func _step_effects(dt: float) -> void:
	var keep := []
	for p in particles:
		p.life -= dt
		p.vel.y += 400.0 * dt
		p.pos += p.vel * dt
		if p.life > 0.0:
			keep.append(p)
	particles = keep
	for b in bolts:
		b.t -= dt
	bolts = bolts.filter(func(b): return b.t > 0.0)


func particle(pos: Vector2, vel: Vector2, color: Color, life: float, size: float) -> void:
	if particles.size() < 600:
		particles.append({"pos": pos, "vel": vel, "color": color, "life": life, "max": life, "size": size})


func burst(pos: Vector2, color: Color, n: int, speed: float) -> void:
	for i in n:
		particle(pos, Vector2.RIGHT.rotated(randf() * TAU) * randf_range(speed * 0.3, speed), color, randf_range(0.25, 0.6), 3.0)


func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)


func floater(pos: Vector2, text: String, color: Color, life := 1.0, font_size := 20) -> void:
	floaters.append({"pos": pos, "text": text, "color": color, "life": life, "max": life, "size": font_size})


func toast(text: String) -> void:
	toasts.append({"text": text, "life": 5.0})
	if toasts.size() > 4:
		toasts.pop_front()


func announce(title: String, sub: String) -> void:
	banner = {"title": title, "sub": sub, "life": 3.0}


func _process(dt: float) -> void:
	for f in floaters:
		f.life -= dt
		f.pos.y -= 30.0 * dt
	floaters = floaters.filter(func(f): return f.life > 0.0)
	for t in toasts:
		t.life -= dt
	toasts = toasts.filter(func(t): return t.life > 0.0)
	if not banner.is_empty():
		banner.life -= dt
		if banner.life <= 0.0:
			banner = {}


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("dd_pause"):
		return
	match mode:
		Mode.PLAY:
			_show_pause()
		Mode.PAUSE:
			_resume()
		Mode.BENCH:
			close_bench()


# --- drawing ---

func _draw_fx(c: Node2D) -> void:
	var font := ThemeDB.fallback_font
	for s in room.signs:
		var p := Vector2((s.tile.x + 0.5) * T, (s.tile.y + 1) * T)
		c.draw_rect(Rect2(p + Vector2(-2, -22), Vector2(4, 22)), Color("6b5a4a"))
		c.draw_rect(Rect2(p + Vector2(-9, -32), Vector2(18, 14)), Color("d8b070"))
		c.draw_string(font, p + Vector2(-4, -20), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("2a1d14"))
	if room.has("bench"):
		var b := Vector2((room.bench.x + 0.5) * T, (room.bench.y + 1) * T)
		c.draw_rect(Rect2(b + Vector2(-26, -20), Vector2(52, 6)), Color("a07850"))
		c.draw_rect(Rect2(b + Vector2(-22, -14), Vector2(5, 14)), Color("6b5040"))
		c.draw_rect(Rect2(b + Vector2(17, -14), Vector2(5, 14)), Color("6b5040"))
		c.draw_rect(Rect2(b + Vector2(-10, -30), Vector2(14, 10)), Color("8a8a96"))
		c.draw_string(font, b + Vector2(-34, -38), "WORKBENCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ACCENT)
	if room.has("lift") and run.lift_open:
		var l := Vector2((room.lift.x + 0.5) * T, (room.lift.y + 1) * T)
		var glow := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 200.0)
		c.draw_rect(Rect2(l + Vector2(-40, -6), Vector2(80, 6)), Color("8a8a96"))
		c.draw_rect(Rect2(l + Vector2(-40, -96), Vector2(4, 90)), Color("5f5866"))
		c.draw_rect(Rect2(l + Vector2(36, -96), Vector2(4, 90)), Color("5f5866"))
		c.draw_rect(Rect2(l + Vector2(-36, -10), Vector2(72, 4)), Color(ACCENT, glow))
		c.draw_string(font, l + Vector2(-30, -104), "LIFT  ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ACCENT)
	for g in gens:
		if g.hp <= 0.0:
			# A wrecked generator, which a Repair Bot can rebuild.
			c.draw_rect(Rect2(g.pos - Vector2(10, -4), Vector2(20, 10)), Color("2a2430"))
			continue
		var col: Color = Parts.ui_color(g.field.color)
		c.draw_rect(Rect2(g.pos - Vector2(10, 14), Vector2(20, 28)), Color("3c3444"))
		c.draw_rect(Rect2(g.pos - Vector2(6, 10), Vector2(12, 12)), col if fmod(Time.get_ticks_msec() / 300.0, 2.0) < 1.4 else col.darkened(0.5))
		c.draw_line(g.pos + Vector2(0, -14), g.pos + Vector2(0, -26), Color("8a8a96"), 2.0)
		c.draw_circle(g.pos + Vector2(0, -27), 3.0, col)
		c.draw_rect(Rect2(g.pos + Vector2(-14, 18), Vector2(28, 3)), Color(0, 0, 0, 0.7))
		c.draw_rect(Rect2(g.pos + Vector2(-14, 18), Vector2(28 * g.hp / g.max_hp, 3)), Color("e05050"))
	for p in pickups:
		if p.get("key", false):
			c.draw_circle(p.pos + Vector2(-4, 0), 5.0, ACCENT)
			c.draw_rect(Rect2(p.pos + Vector2(0, -1.5), Vector2(10, 3)), ACCENT)
			c.draw_rect(Rect2(p.pos + Vector2(6, 0), Vector2(2, 5)), ACCENT)
		elif p.has("schematic"):
			var bob := sin(Time.get_ticks_msec() / 250.0) * 3.0
			var r := Rect2(p.pos - Vector2(10, 7 - bob), Vector2(20, 14))
			c.draw_rect(r, Color("3a6ab0"))
			for k in 3:
				c.draw_line(r.position + Vector2(3, 4 + k * 3), r.position + Vector2(17, 4 + k * 3), Color(0.85, 0.92, 1.0), 1.0)
			c.draw_rect(r, Parts.part_color(p.schematic), false, 2.0)
		elif p.get("crate", false):
			c.draw_rect(Rect2(p.pos - Vector2(8, 8), Vector2(16, 16)), Color("a07850"))
			c.draw_rect(Rect2(p.pos - Vector2(8, 8), Vector2(16, 16)), ACCENT, false, 1.5)
			c.draw_line(p.pos - Vector2(8, 8), p.pos + Vector2(8, 8), Color("6b5040"), 1.5)
		else:
			c.draw_rect(Rect2(p.pos - Vector2(8, 8), Vector2(16, 16)), Parts.part_color(p.slot.id))
			c.draw_rect(Rect2(p.pos - Vector2(8, 8), Vector2(16, 16)), Color.WHITE, false, 1.5)
	for b in bullets:
		if b.saw:
			var spin := Time.get_ticks_msec() / 40.0
			c.draw_circle(b.pos, 11.0, Color("8a8a96"))
			for k in 6:
				var a := Vector2.RIGHT.rotated(spin + k * TAU / 6.0)
				c.draw_line(b.pos + a * 6.0, b.pos + a * 14.0, b.color, 3.0)
			continue
		if b.blast > 0.0:
			c.draw_circle(b.pos, 6.0, Color("3a3030"))
			c.draw_circle(b.pos, 3.0, b.color if fmod(b.life, 0.25) < 0.12 else Color("ffe0a0"))
			continue
		var tail: Vector2 = b.vel.normalized() * (6.0 if b.friendly else 4.0)
		c.draw_line(b.pos - tail, b.pos + tail * 0.3, b.color, 3.0 if b.friendly else 4.0)
	for f in flames:
		c.draw_circle(f.pos, 5.0 * f.life / 0.7 + 2.0, Color(1.0, 0.55, 0.2, 0.7))
	if not decoy.is_empty():
		var flick := 0.35 + 0.25 * sin(Time.get_ticks_msec() / 50.0)
		c.draw_circle(decoy.pos, PlayerScript.RADIUS, Color(Parts.ui_color("purple"), flick))
		c.draw_arc(decoy.pos, PlayerScript.RADIUS + 4.0, 0, TAU, 20, Color(Parts.ui_color("purple"), 0.8), 1.5)
	for p in particles:
		var a: float = p.life / p.max
		c.draw_rect(Rect2(p.pos - Vector2.ONE * p.size / 2.0, Vector2.ONE * p.size), Color(p.color, a))
	for b in bolts:
		var col: Color = b.get("color", Color("bfe0ff"))
		var pts := PackedVector2Array([b.a])
		for k in range(1, 6):
			pts.append(b.a.lerp(b.b, k / 6.0) + Vector2(randf_range(-6, 6), randf_range(-6, 6)))
		pts.append(b.b)
		c.draw_polyline(pts, col, 2.0)


func _draw_hud(c: Control) -> void:
	if room.is_empty():
		return
	var font := ThemeDB.fallback_font
	var vs := c.size
	var to_screen := get_viewport().get_canvas_transform()

	# Hull, shield and heat, top left.
	_bar(c, Rect2(24, 22, 300, 24), player.hp / player.max_hp, Color("d04a4a"), "HULL  %d / %d" % [ceili(maxf(player.hp, 0.0)), player.max_hp])
	_bar(c, Rect2(24, 50, 300, 14), player.shield / player.max_shield, Color("7fd6ff"), "")
	var heat_col := Color("ff3d2e") if player.overheated else Color("ffa040")
	_bar(c, Rect2(24, 68, 300, 12), player.heat / PlayerScript.MAX_HEAT, heat_col, "")
	c.draw_string(font, Vector2(332, 62), "SHIELD", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("7fd6ff"))
	c.draw_string(font, Vector2(332, 80), "OVERHEATED" if player.overheated else "HEAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, heat_col)

	# Room, top right.
	_text(c, Vector2(vs.x - 24, 42), room.name, 26, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	var sub := "Floor %d  ·  Depth %d" % [run.floor_num + 1, room.depth]
	sub += "  ·  %d bots left, doors sealed" % enemies.size() if not door_open else "  ·  doors open"
	_text(c, Vector2(vs.x - 24, 68), sub, 18, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_minimap(c, vs)
	if run.has_key:
		var kr := Rect2(24, 90, 130, 28)
		c.draw_rect(kr, Color("8a6a1a"))
		c.draw_rect(kr, ACCENT, false, 2.0)
		_text(c, kr.get_center() + Vector2(0, 7), "BOSS KEY", 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

	# Boss bar.
	for e in enemies:
		if e.kind == "boss":
			var w := minf(560.0, vs.x - 80)
			var r := Rect2((vs.x - w) / 2.0, 96, w, 18)
			_bar(c, r, e.hp / e.max_hp, Color("e06040"), "")
			_text(c, Vector2(vs.x / 2.0, 90), e.label().to_upper(), 18, TEXT, HORIZONTAL_ALIGNMENT_CENTER)

	_draw_slots(c, vs)

	# Disabled colors next to the player, not in a corner.
	var sp: Vector2 = to_screen * player.global_position
	var chips := []
	for col_name in disabled:
		chips.append([Parts.COLOR_NAME[col_name].to_upper() + " OFF", Parts.FIELD_COLOR[col_name]])
	for s in run.slots:
		if s != null and s.id == "cage" and raw_colors.has(s.color):
			chips.append([Parts.COLOR_NAME[s.color].to_upper() + " SHIELDED", Parts.FIELD_COLOR[s.color].darkened(0.3)])
	if player.overheated:
		chips.append(["OVERHEAT", Color("b03020")])
	if not chips.is_empty():
		var cw := 128.0
		var total := chips.size() * cw + (chips.size() - 1) * 6.0
		var x := sp.x - total / 2.0
		for chip in chips:
			var r := Rect2(x, sp.y - 96, cw, 28)
			c.draw_rect(r, chip[1])
			c.draw_rect(r, Color(1, 1, 1, 0.8), false, 2.0)
			_text(c, Vector2(r.get_center().x, r.position.y + 20), chip[0], 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			x += cw + 6.0

	for f in floaters:
		var a: float = clampf(f.life / f.max * 2.0, 0.0, 1.0)
		var fp: Vector2 = to_screen * f.pos
		var half_w: float = font.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, f.size).x / 2.0 + 12.0
		fp.x = clampf(fp.x, half_w, maxf(half_w, vs.x - half_w))
		_text(c, fp, f.text, f.size, Color(f.color, a), HORIZONTAL_ALIGNMENT_CENTER)

	# Signs and the workbench prompt sit just above the slot cards.
	var prompt := ""
	for s in room.signs:
		var p := Vector2((s.tile.x + 0.5) * T, (s.tile.y + 0.5) * T)
		if p.distance_to(player.global_position) < 110.0:
			prompt = s.text
	if room.has("bench") and _near_bench():
		prompt = "Press S to use the workbench"
	if _near_lift():
		prompt = "Press S to ride the lift to floor %d" % (run.floor_num + 2)
	if prompt != "":
		var w := minf(640.0, vs.x - 2.0 * (_minimap_width() + 40.0))
		var lines := ceili(font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x / (w - 32.0))
		var r := Rect2((vs.x - w) / 2.0, 100, w, 20 + 24 * lines)
		c.draw_rect(r, PANEL)
		c.draw_rect(r, ACCENT, false, 2.0)
		c.draw_multiline_string(font, r.position + Vector2(16, 32), prompt, HORIZONTAL_ALIGNMENT_CENTER, w - 32, 18, -1, TEXT)

	var ty := 200.0
	for t in toasts:
		var a: float = clampf(t.life, 0.0, 1.0)
		_text(c, Vector2(vs.x / 2.0, ty), t.text, 18, Color(TEXT, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x - 80)
		ty += 28.0

	if not banner.is_empty():
		var a: float = clampf(banner.life, 0.0, 1.0)
		_text(c, Vector2(vs.x / 2.0, vs.y * 0.42), banner.title, 44, Color(ACCENT, a), HORIZONTAL_ALIGNMENT_CENTER)
		_text(c, Vector2(vs.x / 2.0, vs.y * 0.42 + 34), banner.sub, 20, Color(TEXT, a), HORIZONTAL_ALIGNMENT_CENTER)


const MAP_CELL := Vector2(30, 20)
const MAP_GAP := 8.0


func _minimap_width() -> float:
	return Rooms.GRID.x * (MAP_CELL.x + MAP_GAP) - MAP_GAP


## Rooms you've visited, plus the rooms next to them, revealed as outlines (fog of war).
func _room_known(pos: Vector2i) -> bool:
	if run.revealed or cell_state(pos).visited:
		return true
	for d in run.floor.cells[pos].doors:
		var n: Vector2i = pos + Rooms.DIRS[d]
		if run.cells.has(n) and run.cells[n].visited:
			return true
	return false


func _map_rect(origin: Vector2, p: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(p.x * (MAP_CELL.x + MAP_GAP), p.y * (MAP_CELL.y + MAP_GAP)), MAP_CELL)


func _draw_minimap(c: Control, vs: Vector2) -> void:
	var origin := Vector2(vs.x - 24 - _minimap_width(), 92)
	var size := Vector2(_minimap_width(), Rooms.GRID.y * (MAP_CELL.y + MAP_GAP) - MAP_GAP)
	c.draw_rect(Rect2(origin - Vector2(8, 8), size + Vector2(16, 16)), PANEL)
	var font := ThemeDB.fallback_font
	var cells: Dictionary = run.floor.cells
	for pos in cells:
		if not _room_known(pos):
			continue
		for d in ["right", "down"]:
			if not cells[pos].doors.has(d):
				continue
			var to: Vector2i = pos + Rooms.DIRS[d]
			if not _room_known(to):
				continue
			var a := _map_rect(origin, pos).get_center()
			var b := _map_rect(origin, to).get_center()
			var locked: bool = (cells[pos].locked == d or cells[to].locked == Rooms.OPPOSITE[d]) and not run.unlocked
			c.draw_line(a, b, ACCENT if locked else Color(0.5, 0.46, 0.52), 3.0)
			if locked:
				c.draw_rect(Rect2((a + b) / 2.0 - Vector2(4, 4), Vector2(8, 8)), ACCENT)
	for pos in cells:
		if not _room_known(pos):
			continue
		var r := _map_rect(origin, pos)
		var cell: Dictionary = cells[pos]
		var st: Dictionary = cell_state(pos)
		if st.visited:
			c.draw_rect(r, Color(0.3, 0.26, 0.34) if st.cleared else Color(0.42, 0.2, 0.2))
		else:
			c.draw_rect(r, Color(0.1, 0.08, 0.12))
			c.draw_rect(r, Color(0.45, 0.42, 0.48), false, 1.5)
		var icon := ""
		var icon_col := TEXT
		match cell.kind:
			"bench":
				icon = "W"
			"boss":
				icon = "B"
				icon_col = Color("ff7050")
			"start":
				icon = "S"
		if cell.key and st.visited and not st.cleared:
			icon = "K"
			icon_col = ACCENT
		if icon != "":
			c.draw_string(font, r.get_center() + Vector2(-5, 6), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, icon_col)
		if pos == room_pos:
			c.draw_rect(r.grow(2), ACCENT, false, 2.0)


func _draw_slots(c: Control, vs: Vector2) -> void:
	var gap := 12.0
	var cw := minf(220.0, (vs.x - 48.0 - gap * 3.0) / 4.0)
	var ch := 100.0
	var x0 := (vs.x - (cw * 4.0 + gap * 3.0)) / 2.0
	var y0 := vs.y - ch - 20.0
	for i in run.slots.size():
		var r := Rect2(x0 + i * (cw + gap), y0, cw, ch)
		var s = run.slots[i]
		var key: String = Parts.SLOT_KEYS[i]
		c.draw_rect(r, PANEL)
		if s == null:
			c.draw_rect(r, Color(0.35, 0.33, 0.37), false, 2.0)
			_text(c, Vector2(r.position.x + 12, r.position.y + 28), key, 16, Color(0.45, 0.43, 0.47))
			_text(c, r.get_center() + Vector2(0, 6), "Empty slot", 18, Color(0.45, 0.43, 0.47), HORIZONTAL_ALIGNMENT_CENTER)
			continue
		var p: Dictionary = Parts.PARTS[s.id]
		var st: Dictionary = status[i] if i < status.size() else {}
		var on: bool = st.get("on", true)
		var col := Parts.part_color(s.id)

		# Color stripe on the left: one band per color the part has.
		var colors: Array = p.colors if p.colors.size() > 0 else [s.color]
		var band := ch / colors.size()
		for k in colors.size():
			c.draw_rect(Rect2(r.position.x, r.position.y + band * k, 8, band), Parts.ui_color(colors[k]))

		if s.cd > 0.0 and p.cd > 0.0:
			var frac: float = clampf(s.cd / p.cd, 0.0, 1.0)
			c.draw_rect(Rect2(r.position.x + 8, r.end.y - ch * frac, cw - 8, ch * frac), Color(1, 1, 1, 0.08))

		var tx := r.position.x + 20
		if p.active:
			var kr := Rect2(tx, r.position.y + 10, 26, 26)
			c.draw_rect(kr, Color(1, 1, 1, 0.12))
			c.draw_rect(kr, Color(1, 1, 1, 0.5), false, 1.5)
			_text(c, kr.get_center() + Vector2(0, 7), key, 18, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
			tx += 34
		_text(c, Vector2(tx, r.position.y + 30), p.name, 19, col if on else Color(0.55, 0.53, 0.55), HORIZONTAL_ALIGNMENT_LEFT, r.end.x - tx - 8)
		var info := Parts.color_line(s.id)
		if s.id == "cage":
			info = "Shields %s" % Parts.COLOR_NAME[s.color]
		_text(c, Vector2(r.position.x + 20, r.position.y + 56), info, 14, MUTED, HORIZONTAL_ALIGNMENT_LEFT, cw - 28)
		if st.get("syn", 0) > 0 or st.get("pot", 1.0) != 1.0:
			_text(c, Vector2(r.end.x - 10, r.position.y + 56), "×%.2f" % st.pot, 14, ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)

		var line := "READY" if p.active else "ON"
		var line_col := Color(0.6, 0.9, 0.6)
		if not on:
			line = ("OFFLINE · " + st.reason) if not p.get("overload", false) else st.reason
			line_col = Parts.ui_color(colors[0]) if p.get("overload", false) else Color(1, 1, 1)
		elif p.get("overload", false):
			line = "OVERLOADED"
			line_col = ACCENT
		elif s.cd > 0.0:
			line = "%.1fs" % s.cd
			line_col = MUTED
		if not on and not p.get("overload", false):
			var field_col: Color = Parts.FIELD_COLOR[st.reason.split(" ")[0].to_lower()]
			_hatch(c, r, Color(field_col, 0.35))
			c.draw_rect(r, field_col.lightened(0.2), false, 3.0)
		else:
			c.draw_rect(r, Color(col, 0.7 if on else 0.3), false, 2.0)
		_text(c, Vector2(r.position.x + 20, r.end.y - 14), line, 15, line_col, HORIZONTAL_ALIGNMENT_LEFT, cw - 28)

	var hint := "Left click: basic shot (always works)   ·   Esc: pause"
	_text(c, Vector2(vs.x / 2.0, vs.y - 6), hint, 13, Color(0.55, 0.52, 0.5), HORIZONTAL_ALIGNMENT_CENTER)


func _bar(c: Control, r: Rect2, frac: float, col: Color, label: String) -> void:
	c.draw_rect(r, PANEL)
	c.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)
	c.draw_rect(r, Color(1, 1, 1, 0.35), false, 1.5)
	if label != "":
		_text(c, Vector2(r.position.x + 8, r.position.y + r.size.y - 6), label, 16, Color.WHITE)


func _hatch(c: Control, r: Rect2, col: Color) -> void:
	var k := -r.size.y
	while k < r.size.x:
		var a := Vector2(r.position.x + k, r.end.y)
		var b := Vector2(r.position.x + k + r.size.y, r.position.y)
		if a.x < r.position.x:
			a = Vector2(r.position.x, r.end.y - (r.position.x - a.x))
		if b.x > r.end.x:
			b = Vector2(r.end.x, r.position.y + (b.x - r.end.x))
		c.draw_line(a, b, col, 3.0)
		k += 14.0


func _text(c: Control, pos: Vector2, text: String, font_size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var font := ThemeDB.fallback_font
	var w := width
	var p := pos
	if align != HORIZONTAL_ALIGNMENT_LEFT:
		if w < 0.0:
			w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 2.0
		p.x -= w if align == HORIZONTAL_ALIGNMENT_RIGHT else w / 2.0
	c.draw_string_outline(font, p, text, align, w, font_size, 4, Color(0, 0, 0, col.a * 0.8))
	c.draw_string(font, p, text, align, w, font_size, col)


# --- menus ---

func _clear_overlay() -> void:
	for ch in _overlay.get_children():
		ch.queue_free()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _screen(title: String, lines: Array, buttons: Array) -> VBoxContainer:
	_clear_overlay()
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.06, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.06, 0.11)
	sb.border_color = ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size.x = 640
	panel.add_child(box)
	box.add_child(_label(title, 40, ACCENT))
	for l in lines:
		if l is Array:
			box.add_child(_label(l[0], l[1], l[2] if l.size() > 2 else TEXT))
		else:
			box.add_child(_label(l, 18, TEXT))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	box.add_child(row)
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(180, 48)
		btn.pressed.connect(b[1])
		row.add_child(btn)
	return box


func _label(text: String, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 640
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	return l


func _show_title() -> void:
	mode = Mode.TITLE
	_screen("Disruptive Dungeons", [
		["Vertical-slice demo of the rework proposal", 22, MUTED],
		"You are SP-1N, caught by a scrapper gang. Fight up through four generated floors of the scrapshop. On each one, take the boss key from an elite and beat the boss behind the locked door. Every part you install has a color, and a disruption field shuts off every part of its color.",
		["The question this slice tests: is it fun to lose one color of your build to a field and fight with the rest?", 18, ACCENT],
		["Schematics found: %d of %d. Bosses, elites and hidden rooms drop them, and each one adds a part that can show up in every run after." % [Unlocks.found_count(), Parts.LOCKED.size()], 17, TEXT],
		["A / D roll   ·   W or Space jump   ·   S + Space drop through platforms\nLeft click: basic shot   ·   Q E R F: use the part in that slot\nS at a workbench: change parts   ·   Esc: pause and debug options", 17, MUTED],
	], [["Start the escape", _start]])


func _start() -> void:
	_clear_overlay()
	mode = Mode.PLAY


func _show_pause() -> void:
	mode = Mode.PAUSE
	_screen("Paused", [["Debug tools for trying things out quickly.", 18, MUTED]], [
		["Resume", _resume],
		["Restart run", _restart],
		["Add every part to stash", _debug_all_parts],
		["Reveal map", _debug_reveal],
		["Give boss key", _debug_key],
		["Go to boss door", _debug_boss_door],
		["Skip to next floor", _debug_next_floor],
		["God mode: %s" % ("on" if god_mode else "off"), _toggle_god],
		["Forget schematics", _debug_forget],
		["Sound: %s" % ("off" if sfx.muted else "on"), _toggle_sound],
		["Quit", _quit],
	])


func _debug_all_parts() -> void:
	for id in Parts.PARTS:
		if not run.stash.has(id):
			run.stash.append(id)
	toast("Every part is in your stash. Visit a workbench to install them.")
	_resume()


func _debug_forget() -> void:
	Unlocks.reset()
	toast("Schematics forgotten. Only the starting parts drop now.")
	_resume()


func _toggle_god() -> void:
	god_mode = not god_mode
	_show_pause()


func _toggle_sound() -> void:
	sfx.muted = not sfx.muted
	_show_pause()


func _debug_reveal() -> void:
	run.revealed = true
	_resume()


func _debug_key() -> void:
	run.has_key = true
	_resume()


func _debug_boss_door() -> void:
	load_room(run.floor.boss_door)
	_resume()


func _debug_next_floor() -> void:
	if not last_floor():
		start_floor(run.floor_num + 1)
	_resume()


func _quit() -> void:
	get_tree().quit()


func _resume() -> void:
	_clear_overlay()
	mode = Mode.PLAY


func _restart() -> void:
	new_run()
	_resume()


func _show_end(won: bool) -> void:
	mode = Mode.WIN if won else Mode.DEAD
	var st: Dictionary = run.stats
	var lines := []
	if won:
		lines.append(["You beat Boss Rust and escaped the scrapshop.", 18, TEXT])
	else:
		lines.append(["The gang strips your parts and throws you back on the scrapheap. You made it to floor %d of %d, %s." % [run.floor_num + 1, Rooms.FLOORS.size(), Rooms.FLOORS[run.floor_num].name], 18, TEXT])
	var rooms_seen: int = st.rooms + run.cells.values().filter(func(x): return x.visited).size()
	lines.append(["Time %d:%02d   ·   Bots destroyed %d   ·   Rooms explored %d" % [int(st.time) / 60, int(st.time) % 60, st.kills, rooms_seen], 18, MUTED])
	var off := []
	for c in Parts.COLORS:
		off.append("%s %.0fs (%d×)" % [Parts.COLOR_NAME[c], st.offline[c], st.offline_count[c]])
	lines.append(["Time with each color offline:   " + "   ".join(off), 17, TEXT])
	var dmg := []
	var keys: Array = st.damage.keys()
	keys.sort_custom(func(a, b): return st.damage[a] > st.damage[b])
	for k in keys.slice(0, 6):
		dmg.append("%s %d" % [k, roundi(st.damage[k])])
	lines.append(["Damage by source:   " + ("   ".join(dmg) if not dmg.is_empty() else "none"), 17, TEXT])
	lines.append(["Schematics found this run: %d   ·   Unlocked so far: %d of %d" % [st.get("schematics", 0), Unlocks.found_count(), Parts.LOCKED.size()], 17, MUTED])
	lines.append(["Things to notice: did losing a color feel like a puzzle or a punishment? Did synergy pull you toward one color? Did you hear a color power down before you saw it?", 17, ACCENT])
	_screen("Escaped!" if won else "Scrapped", lines, [["Try again", _restart], ["Quit", _quit]])
