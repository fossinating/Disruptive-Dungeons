extends Node2D
## Vertical-slice demo for docs/rework-proposal.md: one floor, 12 parts, 6 bots and a boss.
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

enum Mode { TITLE, PLAY, BENCH, PAUSE, DEAD, WIN }

var mode: int = Mode.TITLE
var run: Dictionary = {}
var room: Dictionary = {}
var room_index := 0
var player
var enemies: Array = []
var fields: Array = []
var gens: Array = []
var bullets: Array = []
var particles: Array = []
var floaters: Array = []
var bolts: Array = []
var pickups: Array = []
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
var _door_body: StaticBody2D
var _smoke := false
var _smoke_frames := 0


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

	new_run()
	_smoke = OS.get_cmdline_user_args().has("--smoke")
	if _smoke:
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
	run = {
		"slots": [null, null, null, null],
		"stash": [],
		"visited": {},
		"stats": {"time": 0.0, "kills": 0, "damage": {}, "offline": {}, "offline_count": {}},
	}
	for c in Parts.COLORS:
		run.stats.offline[c] = 0.0
		run.stats.offline_count[c] = 0
	player.hp = player.max_hp
	player.shield = player.max_shield
	win_timer = -1.0
	disabled.clear()
	raw_colors.clear()
	load_room(0)


func load_room(i: int) -> void:
	room_index = i
	for c in _entity_layer.get_children():
		c.queue_free()
	for c in _field_layer.get_children():
		c.queue_free()
	enemies.clear()
	fields.clear()
	gens.clear()
	bullets.clear()
	pickups.clear()
	bolts.clear()
	particles.clear()
	floaters.clear()
	room = Rooms.build(i, dominant_color())
	_bg_view.set_room(room)
	_wall_view.set_room(room)
	_build_collision()

	player.global_position = Vector2((room.spawn.x + 0.5) * T, (room.spawn.y + 0.5) * T)
	player.reset_for_room()
	for fd in room.fields:
		_add_field(fd)
	for ed in room.enemies:
		var kind: String = ed[0]
		spawn_enemy(kind, _enemy_pos(kind, ed[1], ed[2]), ed[3])

	door_open = false
	if room.enemies.is_empty() and not room.boss:
		_open_door(false)
	if room.has("bench"):
		player.hp = player.max_hp
		if not run.visited.has(i):
			run.visited[i] = true
			var found := give_random_parts(room.give)
			toast("Salvage pile: found %d parts. %s" % [found.size(), ", ".join(found.map(func(id): return Parts.PARTS[id].name))])
		toast("Hull repaired.")

	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = room.w * T
	_camera.limit_bottom = room.h * T + HUD_MARGIN
	_camera.global_position = player.global_position
	_camera.reset_smoothing()
	announce(room.name, room.sub)
	_update_status()


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
	_door_body = _new_body(1)
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
				"D":
					_add_shape(_door_body, Rect2(start * T, y * T, length * T, T), false)


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
	var f = FieldScript.new()
	f.setup(fd)
	f.carrier = carrier
	_field_layer.add_child(f)
	fields.append(f)
	if fd.has("generator"):
		gens.append({"pos": fd.generator, "hp": 90.0, "max_hp": 90.0, "field": f})
	return f


func spawn_enemy(kind: String, pos: Vector2, opts: Dictionary):
	var e = EnemyScript.new()
	e.game = self
	e.setup(kind, opts)
	e.global_position = pos
	_entity_layer.add_child(e)
	enemies.append(e)
	if kind == "jammer":
		e.field = _add_field({"shape": "circle", "pos": pos, "radius": 90.0, "color": opts.get("color", "red")}, e)
	elif kind == "boss":
		e.field = _add_field({"shape": "circle", "pos": pos, "radius": 130.0, "color": "red", "period": 5.0}, e)
	return e


func _open_door(with_sound := true) -> void:
	door_open = true
	for y in room.door:
		room.grid[y][room.w - 1] = "."
	if _door_body != null:
		_door_body.queue_free()
		_bodies.erase(_door_body)
		_door_body = null
	_wall_view.queue_redraw()
	if with_sound:
		sfx.play("door")
		toast("Room clear. The exit is open →")


func _next_room() -> void:
	if room_index + 1 < Rooms.COUNT:
		load_room(room_index + 1)


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
	var fresh := []
	for id in Parts.PARTS:
		if not owned.has(id):
			fresh.append(id)
	fresh.shuffle()
	var out := []
	for k in n:
		var id: String = fresh.pop_back() if not fresh.is_empty() else Parts.PARTS.keys().pick_random()
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
	for i in run.slots.size():
		var s = run.slots[i]
		if s != null:
			s.cd = maxf(0.0, s.cd - dt)
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
	_step_pickups(dt)
	_step_effects(dt)

	if room.has("bench") and _near_bench() and Input.is_action_just_pressed("dd_down") \
			and not Input.is_action_pressed("dd_jump"):
		open_bench()

	if not door_open and not room.boss and enemies.is_empty():
		_open_door()
		if room.salvage:
			pickups.append({"pos": player.global_position + Vector2(0, -10), "vel": Vector2(randf_range(-60, 60), -260), "t": 0.0, "crate": true})
	if door_open and player.global_position.x > (room.w - 1) * T + 2:
		_next_room()

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
	var shots := OS.get_environment("DD_SHOTS")
	if shots != "" and _smoke_frames % 90 == 60:
		if room.has("bench"):
			open_bench()
		_save_shot.call_deferred(shots.path_join("room_%d.png" % room_index))
	if _smoke_frames % 90 == 0:
		# Exercise each active part once per room, then move on.
		for i in 4:
			_try_activate(i)
		if room_index + 1 < Rooms.COUNT:
			print("smoke: room %d ok (%s), %d bots, %d fields" % [room_index, room.name, enemies.size(), fields.size()])
			load_room(room_index + 1)
		else:
			print("smoke: room %d ok (%s), %d bots, %d fields" % [room_index, room.name, enemies.size(), fields.size()])
			print("smoke: done")
			get_tree().quit()


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
	if part_index("ram") >= 0 and speed > RAM_MIN_SPEED:
		if e.ram_cd <= 0.0:
			e.ram_cd = 0.35
			e.take_damage((8.0 + (speed - RAM_MIN_SPEED) * 0.05) * pot("ram"), "Ram Plating", -away * 260.0 + Vector2(0, -120))
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


func open_bench() -> void:
	mode = Mode.BENCH
	_bench.open()


func close_bench() -> void:
	_bench.visible = false
	mode = Mode.PLAY
	_update_status()


# --- combat helpers used by player and enemies ---

func fire(from: Vector2, vel: Vector2, dmg: float, friendly: bool, color: Color, source: String, pierce: bool, life := 1.4) -> void:
	bullets.append({"pos": from, "vel": vel, "dmg": dmg, "friendly": friendly, "color": color, "source": source, "pierce": pierce, "life": life, "hit": []})


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
			e.take_damage(dmg, "Heat Vent", dir * 300.0)


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
	if e.carried != null:
		pickups.append({"pos": e.global_position, "vel": Vector2(0, -260), "t": 0.0, "slot": e.carried, "slot_index": e.carried_slot})
	if e.kind == "boss":
		win_timer = 2.5
		announce("The Foreman is scrap", "The exit is yours")
		for other in enemies.duplicate():
			other.take_damage(999.0, "Boss death")
	e.queue_free()


func _hit_gen(g: Dictionary, dmg: float) -> void:
	if g.hp <= 0.0:
		return
	g.hp -= dmg
	record_damage("Generator", 0.0)
	if g.hp <= 0.0:
		g.field.dead = true
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
		var next: Vector2 = b.pos + b.vel * dt
		var q := PhysicsRayQueryParameters2D.create(b.pos, next, 1)
		var wall := space.intersect_ray(q)
		var alive: bool = b.life > 0.0
		if not wall.is_empty():
			particle(wall.position, -b.vel.normalized() * 60.0, b.color, 0.15, 2.0)
			alive = false
		b.pos = next
		if alive and b.friendly:
			for e in enemies.duplicate():
				if e.dead or b.hit.has(e):
					continue
				if e.hit_rect().grow(3.0).has_point(b.pos):
					e.take_damage(b.dmg, b.source, b.vel.normalized() * 60.0)
					b.hit.append(e)
					if not b.pierce:
						alive = false
						break
			if alive:
				for g in gens:
					if g.hp > 0.0 and Rect2(g.pos - Vector2(10, 14), Vector2(20, 28)).has_point(b.pos):
						_hit_gen(g, b.dmg)
						alive = false
						break
		elif alive and b.pos.distance_to(player.global_position) < PlayerScript.RADIUS + 3.0:
			player.hurt(b.dmg, b.vel.normalized() * 120.0)
			alive = false
		if alive:
			keep.append(b)
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
	for g in gens:
		if g.hp <= 0.0:
			continue
		var col: Color = Parts.ui_color(g.field.color)
		c.draw_rect(Rect2(g.pos - Vector2(10, 14), Vector2(20, 28)), Color("3c3444"))
		c.draw_rect(Rect2(g.pos - Vector2(6, 10), Vector2(12, 12)), col if fmod(Time.get_ticks_msec() / 300.0, 2.0) < 1.4 else col.darkened(0.5))
		c.draw_line(g.pos + Vector2(0, -14), g.pos + Vector2(0, -26), Color("8a8a96"), 2.0)
		c.draw_circle(g.pos + Vector2(0, -27), 3.0, col)
		c.draw_rect(Rect2(g.pos + Vector2(-14, 18), Vector2(28, 3)), Color(0, 0, 0, 0.7))
		c.draw_rect(Rect2(g.pos + Vector2(-14, 18), Vector2(28 * g.hp / g.max_hp, 3)), Color("e05050"))
	for p in pickups:
		if p.get("crate", false):
			c.draw_rect(Rect2(p.pos - Vector2(8, 8), Vector2(16, 16)), Color("a07850"))
			c.draw_rect(Rect2(p.pos - Vector2(8, 8), Vector2(16, 16)), ACCENT, false, 1.5)
			c.draw_line(p.pos - Vector2(8, 8), p.pos + Vector2(8, 8), Color("6b5040"), 1.5)
		else:
			c.draw_rect(Rect2(p.pos - Vector2(8, 8), Vector2(16, 16)), Parts.part_color(p.slot.id))
			c.draw_rect(Rect2(p.pos - Vector2(8, 8), Vector2(16, 16)), Color.WHITE, false, 1.5)
	for b in bullets:
		var tail: Vector2 = b.vel.normalized() * (6.0 if b.friendly else 4.0)
		c.draw_line(b.pos - tail, b.pos + tail * 0.3, b.color, 3.0 if b.friendly else 4.0)
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
	var sub := "Room %d of %d" % [room_index + 1, Rooms.COUNT]
	if not room.has("bench"):
		sub += "  ·  %d bots left" % enemies.size() if not door_open else "  ·  exit open →"
	_text(c, Vector2(vs.x - 24, 68), sub, 18, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)

	# Boss bar.
	for e in enemies:
		if e.kind == "boss":
			var w := minf(560.0, vs.x - 80)
			var r := Rect2((vs.x - w) / 2.0, 96, w, 18)
			_bar(c, r, e.hp / e.max_hp, Color("e06040"), "")
			_text(c, Vector2(vs.x / 2.0, 90), "THE FOREMAN", 18, TEXT, HORIZONTAL_ALIGNMENT_CENTER)

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
	if prompt != "":
		var w := minf(760.0, vs.x - 48)
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
		"You are SP-1N, caught by a scrapper gang. Fight through one floor of the scrapshop and beat the Foreman. Every part you install has a color, and a disruption field shuts off every part of its color.",
		["The question this slice tests: is it fun to lose one color of your build to a field and fight with the rest?", 18, ACCENT],
		["A / D roll   ·   W or Space jump   ·   S + Space drop through platforms\nLeft click: basic shot   ·   Q E R F: use the part in that slot\nS at a workbench: change parts   ·   Esc: pause, room select and debug options", 17, MUTED],
	], [["Start the escape", _start]])


func _start() -> void:
	_clear_overlay()
	mode = Mode.PLAY


func _show_pause() -> void:
	mode = Mode.PAUSE
	var box := _screen("Paused", [["Debug tools for trying things out quickly.", 18, MUTED]], [
		["Resume", _resume],
		["Restart run", _restart],
		["Add every part to stash", _debug_all_parts],
		["God mode: %s" % ("on" if god_mode else "off"), _toggle_god],
		["Sound: %s" % ("off" if sfx.muted else "on"), _toggle_sound],
		["Quit", _quit],
	])
	box.add_child(_label("Jump to room", 20, TEXT))
	var rooms := HFlowContainer.new()
	rooms.add_theme_constant_override("h_separation", 8)
	rooms.add_theme_constant_override("v_separation", 8)
	box.add_child(rooms)
	for i in Rooms.COUNT:
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, Rooms.build(i, "red").name]
		b.pressed.connect(_jump_to_room.bind(i))
		rooms.add_child(b)


func _debug_all_parts() -> void:
	for id in Parts.PARTS:
		if not run.stash.has(id):
			run.stash.append(id)
	toast("Every part is in your stash. Visit a workbench to install them.")
	_resume()


func _toggle_god() -> void:
	god_mode = not god_mode
	_show_pause()


func _toggle_sound() -> void:
	sfx.muted = not sfx.muted
	_show_pause()


func _jump_to_room(i: int) -> void:
	load_room(i)
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
		lines.append(["You beat the Foreman and escaped the scrapshop. In the full game this is floor 1 of 4.", 18, TEXT])
	else:
		lines.append(["The gang strips your parts and throws you back on the scrapheap.", 18, TEXT])
	lines.append(["Time %d:%02d   ·   Bots destroyed %d   ·   Reached room %d of %d" % [int(st.time) / 60, int(st.time) % 60, st.kills, room_index + 1, Rooms.COUNT], 18, MUTED])
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
	lines.append(["Things to notice: did losing a color feel like a puzzle or a punishment? Did synergy pull you toward one color? Did you hear a color power down before you saw it?", 17, ACCENT])
	_screen("Escaped!" if won else "Scrapped", lines, [["Try again", _restart], ["Quit", _quit]])
