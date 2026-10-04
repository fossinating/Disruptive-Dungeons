extends CharacterBody2D
## SP-1N. Movement constants are copied from the jam's player.gd so the feel stays the same.
## One change: speed above MAX_SPEED (from Boost, Heat Vent or recoil) is no longer clamped
## away the moment you press a direction, so speed-based parts like Ram Plating can work.

const Parts := preload("res://demo/parts.gd")

const MAX_SPEED := 300.0
const ACCEL := MAX_SPEED * 10
const JUMP_VELOCITY := -500.0
const FRICTION := MAX_SPEED * 3
const AIR_PENALTY := 0.3
const RADIUS := 14.0
const GRAVITY := 980.0
const BASIC_SHOT_DELAY := 0.25
const BASIC_SHOT_DAMAGE := 5.0
const MAX_HEAT := 100.0

var game
var max_hp := 100.0
var hp := 100.0
var max_shield := 40.0
var shield := 40.0
var shield_delay := 0.0
var invuln := 0.0
var heat := 0.0
var overheated := false
var heat_delay := 0.0
var shot_cd := 0.0
var drone_cd := 0.0
var drone_angle := 0.0
var coil := 0.0
var air_jumps := 0
var slamming := false
var slam_start_y := 0.0
var hovering := false
var aim := Vector2.RIGHT

var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 1 << 6 # "player"
	collision_mask = 1 | 2 # world, platform
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	cs.shape = circle
	add_child(cs)
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://player skins/default.png")
	add_child(_sprite)


func reset_for_room() -> void:
	velocity = Vector2.ZERO
	slamming = false
	hovering = false
	heat = 0.0
	overheated = false
	coil = 0.0
	invuln = 0.6


func step(dt: float) -> void:
	var dir := Input.get_axis("dd_left", "dd_right")
	var down := Input.is_action_pressed("dd_down")
	var jump_held := Input.is_action_pressed("dd_jump")
	var on_floor := is_on_floor()
	aim = (get_global_mouse_position() - global_position).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT

	if not on_floor:
		velocity.y += GRAVITY * dt
	else:
		air_jumps = 1 if game.part_index("djump") >= 0 else 0

	# Jump (held, like the jam build) and the green double jump.
	if jump_held and on_floor and not down:
		velocity.y = JUMP_VELOCITY
		game.sfx.play("jump", -8.0)
	elif Input.is_action_just_pressed("dd_jump") and not on_floor and not down \
			and air_jumps > 0 and game.part_index("djump") >= 0:
		velocity.y = JUMP_VELOCITY * 0.9
		air_jumps -= 1
		game.burst(global_position + Vector2(0, RADIUS), Parts.ui_color("green"), 8, 120.0)
		game.sfx.play("jump", -4.0, 1.3)

	if dir != 0.0:
		var nv := velocity.x + dir * ACCEL * dt * (1.0 if on_floor else AIR_PENALTY)
		if absf(nv) > MAX_SPEED and absf(nv) > absf(velocity.x):
			nv = signf(nv) * maxf(MAX_SPEED, absf(velocity.x))
		velocity.x = nv
	elif on_floor:
		velocity.x = move_toward(velocity.x, 0, FRICTION * dt)
	if on_floor and absf(velocity.x) > MAX_SPEED:
		velocity.x = move_toward(velocity.x, signf(velocity.x) * MAX_SPEED, FRICTION * dt)

	# Thruster Fins: hold jump while falling to hover.
	hovering = false
	if game.part_index("fins") >= 0 and not on_floor and jump_held and not overheated \
			and not slamming and velocity.y > -60.0:
		velocity.y = lerpf(velocity.y, -60.0, minf(1.0, 10.0 * dt))
		add_heat(28.0 * dt)
		hovering = true
		if randf() < 0.5:
			game.particle(global_position + Vector2(randf_range(-6, 6), RADIUS), Vector2(randf_range(-30, 30), 160), Color("ffa040"), 0.25, 3.0)

	if slamming:
		velocity.y = 900.0
		velocity.x = move_toward(velocity.x, 0, 600 * dt)

	# Drop through platforms with down + jump, as in the jam build.
	set_collision_mask_value(2, not (down and jump_held))
	move_and_slide()
	if slamming and is_on_floor():
		_land_slam()

	_sprite.rotation = fmod(_sprite.rotation + dt * velocity.x / 20.0, TAU)

	_step_weapons(dt)
	_step_timers(dt)
	queue_redraw()


func _step_weapons(dt: float) -> void:
	shot_cd -= dt
	var siphon: bool = game.part_index("siphon") >= 0
	if Input.is_action_pressed("dd_shoot") and shot_cd <= 0.0 and not overheated:
		shot_cd = BASIC_SHOT_DELAY * (0.5 if siphon else 1.0)
		var dmg: float = BASIC_SHOT_DAMAGE * (game.pot("siphon") if siphon else 1.0)
		if coil >= 1.0 and game.part_index("coil") >= 0:
			game.chain_lightning(global_position, 16.0 * game.pot("coil"))
			coil = 0.0
		game.fire(global_position, aim * 500.0, dmg, true, Color(0.9, 0.95, 1.0), "Basic shot", siphon)
		add_heat(4.0)
		game.sfx.play("shot", -12.0)

	if game.part_index("coil") >= 0:
		if absf(velocity.x) >= MAX_SPEED * 0.9 and coil < 1.0:
			coil = minf(1.0, coil + dt / 1.2)
			if coil >= 1.0:
				game.sfx.play("zap", -10.0, 1.4)
	else:
		coil = 0.0

	if game.part_index("drone") >= 0:
		drone_angle += dt * 2.5
		drone_cd -= dt * game.pot("drone")
		if drone_cd <= 0.0:
			var from := global_position + drone_offset()
			var target = game.nearest_enemy(from, 280.0, true)
			if target != null:
				var to: Vector2 = (target.global_position - from).normalized()
				game.fire(from, to * 420.0, 6.0 * game.pot("drone"), true, Parts.ui_color("purple"), "Attack Drone", false)
				drone_cd = 0.55
			else:
				drone_cd = 0.1


func _step_timers(dt: float) -> void:
	heat_delay -= dt
	if heat_delay <= 0.0:
		heat = maxf(0.0, heat - 40.0 * dt)
	if overheated and heat <= 30.0:
		overheated = false
	shield_delay -= dt
	if shield_delay <= 0.0:
		shield = minf(max_shield, shield + 12.0 * dt)
	invuln -= dt
	visible = invuln <= 0.0 or fmod(invuln, 0.12) < 0.08


func add_heat(amount: float) -> void:
	heat += amount
	heat_delay = 0.35
	if heat >= MAX_HEAT:
		heat = MAX_HEAT
		if not overheated:
			overheated = true
			game.sfx.play("overheat", -6.0)
			game.floater(global_position + Vector2(0, -30), "OVERHEAT", Color("ff6a3d"))


func drone_offset() -> Vector2:
	return Vector2(cos(drone_angle) * 24.0, sin(drone_angle) * 10.0 - 26.0)


## Runs an active part. Returns false when it couldn't fire, so no cooldown is spent.
func activate(id: String, pot: float) -> bool:
	match id:
		"boost":
			velocity = aim * 800.0
			slamming = false
			game.sfx.play("boost", -4.0)
			game.burst(global_position, Parts.ui_color("blue"), 12, 160.0)
			return true
		"slam":
			if is_on_floor():
				return false
			slamming = true
			slam_start_y = global_position.y
			velocity = Vector2(velocity.x * 0.3, 900.0)
			return true
		"shotgun":
			if overheated:
				return false
			for i in 6:
				var a := aim.rotated(randf_range(-0.28, 0.28))
				game.fire(global_position, a * randf_range(480.0, 560.0), 6.0 * pot, true, Color("ffb050"), "Shotgun", false, 0.35)
			velocity -= aim * 180.0
			add_heat(34.0)
			game.sfx.play("shotgun", -2.0)
			game.add_shake(4.0)
			return true
		"vent":
			velocity = -aim * 560.0
			slamming = false
			game.vent_blast(global_position, aim, 12.0 * pot)
			heat = 0.0
			overheated = false
			game.sfx.play("vent", -2.0)
			return true
		"hack":
			return game.hack_nearest(global_position)
	return false


func _land_slam() -> void:
	slamming = false
	var fall := global_position.y - slam_start_y
	var dmg: float = (14.0 + fall * 0.06) * game.pot("slam")
	game.shockwave(global_position + Vector2(0, RADIUS), 90.0, dmg, "Ground Slam", Parts.ui_color("green"))
	game.sfx.play("slam", -2.0)
	game.add_shake(7.0)


func hurt(amount: float, knock := Vector2.ZERO) -> void:
	if invuln > 0.0 or game.god_mode:
		return
	invuln = 0.6
	shield_delay = 3.0
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		if shield <= 0.0:
			game.sfx.play("shield_break", -4.0)
			game.floater(global_position + Vector2(0, -30), "SHIELD DOWN", Color("7fd6ff"))
	hp -= amount
	velocity += knock
	game.sfx.play("hurt", -4.0)
	game.add_shake(5.0)
	if hp <= 0.0:
		game.player_died()


func _draw() -> void:
	# Color ring: one arc per color. Colors you have parts in are bright;
	# a color knocked out by a field flashes and breaks into dashes.
	var owned: Dictionary = game.owned_colors()
	for i in 4:
		var c: String = Parts.COLORS[i]
		var a0 := -PI * 0.75 + i * PI * 0.5 + 0.12
		var a1 := a0 + PI * 0.5 - 0.24
		var col: Color = Parts.ui_color(c)
		if game.disabled.has(c):
			var flash := fmod(Time.get_ticks_msec() / 1000.0, 0.4) < 0.2
			var seg := (a1 - a0) / 5.0
			for k in 5:
				if k % 2 == 0:
					draw_arc(Vector2.ZERO, RADIUS + 7, a0 + seg * k, a0 + seg * (k + 1), 4, col if flash else Color(0.3, 0.3, 0.3), 4.0)
		elif owned.has(c):
			draw_arc(Vector2.ZERO, RADIUS + 7, a0, a1, 10, col, 3.0)
		else:
			draw_arc(Vector2.ZERO, RADIUS + 7, a0, a1, 10, Color(col, 0.18), 2.0)

	if shield > 0.0:
		draw_arc(Vector2.ZERO, RADIUS + 2, 0, TAU, 24, Color(0.5, 0.85, 1.0, 0.15 + 0.35 * shield / max_shield), 1.5)

	if heat > 0.5:
		var w := 32.0
		draw_rect(Rect2(-w / 2, RADIUS + 12, w, 4), Color(0, 0, 0, 0.6))
		var hc := Color("ff3d2e") if overheated else Color("ffa040").lerp(Color("ff3d2e"), heat / MAX_HEAT)
		draw_rect(Rect2(-w / 2, RADIUS + 12, w * heat / MAX_HEAT, 4), hc)

	if game.part_index("drone") >= 0:
		var d := drone_offset()
		draw_circle(d, 5.0, Parts.ui_color("purple"))
		draw_circle(d, 2.0, Color.WHITE)

	if coil >= 1.0 and game.part_index("coil") >= 0:
		var r := RADIUS + 3 + randf() * 2.0
		draw_arc(Vector2.ZERO, r, 0, TAU, 16, Parts.ui_color("blue"), 1.5)
		draw_arc(Vector2.ZERO, r + 2, randf() * TAU, randf() * TAU, 6, Parts.ui_color("purple"), 1.5)

	# Aim tick.
	draw_line(aim * (RADIUS + 10), aim * (RADIUS + 16), Color(1, 1, 1, 0.6), 2.0)
