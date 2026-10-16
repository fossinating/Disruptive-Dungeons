extends CharacterBody2D
## All demo bots in one script, switched on `kind`. Roller and drone follow the jam's
## moving_enemy and flying_enemy; the rest reuse their sprites with a tint until they get art.
## Elites get more health, more speed and one extra behavior each (see the `elite` checks).

const Parts := preload("res://demo/parts.gd")
const GROUND_TEX := preload("res://enemies/moving enemy.png")
const FLYER_TEX := preload("res://enemies/flying enemy.png")
const GRAVITY := 980.0
const T := 32
const MAX_FALL := 1000.0

# `scale` is a number or a Vector2 (for squat or wide bots built from the same sprite).
const STATS := {
	"roller": {"hp": 35.0, "half": Vector2(12, 30), "contact": 12.0, "flying": false, "scale": 1.0, "tint": Color.WHITE},
	"gunner": {"hp": 40.0, "half": Vector2(12, 30), "contact": 6.0, "flying": false, "scale": 1.0, "tint": Color(0.6, 0.78, 1.0)},
	"charger": {"hp": 60.0, "half": Vector2(15, 38), "contact": 10.0, "flying": false, "scale": 1.2, "tint": Color(1.0, 0.7, 0.4)},
	"scrapper": {"hp": 45.0, "half": Vector2(10, 24), "contact": 0.0, "flying": false, "scale": 0.8, "tint": Color(0.85, 0.6, 0.35)},
	"sniper": {"hp": 30.0, "half": Vector2(11, 28), "contact": 4.0, "flying": false, "scale": 0.9, "tint": Color(0.7, 0.95, 0.75)},
	"mortar": {"hp": 50.0, "half": Vector2(17, 24), "contact": 6.0, "flying": false, "scale": Vector2(1.2, 0.8), "tint": Color(0.75, 0.7, 0.6)},
	"mite": {"hp": 8.0, "half": Vector2(6, 10), "contact": 5.0, "flying": false, "scale": 0.32, "tint": Color(0.95, 0.85, 0.55)},
	"shield": {"hp": 50.0, "half": Vector2(12, 30), "contact": 8.0, "flying": false, "scale": 1.0, "tint": Color(0.65, 0.65, 0.75)},
	"turret": {"hp": 70.0, "half": Vector2(15, 16), "contact": 0.0, "flying": false, "scale": Vector2(1.0, 0.5), "tint": Color(0.6, 0.6, 0.65)},
	"tank": {"hp": 170.0, "half": Vector2(22, 40), "contact": 22.0, "flying": false, "scale": Vector2(1.6, 1.3), "tint": Color(0.55, 0.6, 0.5)},
	"splitter": {"hp": 55.0, "half": Vector2(15, 33), "contact": 10.0, "flying": false, "scale": 1.1, "tint": Color(0.9, 0.6, 0.9)},
	"splitling": {"hp": 18.0, "half": Vector2(9, 19), "contact": 6.0, "flying": false, "scale": 0.6, "tint": Color(0.9, 0.6, 0.9)},
	"drone": {"hp": 24.0, "half": Vector2(13, 13), "contact": 0.0, "flying": true, "scale": 1.0, "tint": Color.WHITE},
	"jammer": {"hp": 55.0, "half": Vector2(16, 16), "contact": 0.0, "flying": true, "scale": 1.2, "tint": Color.WHITE},
	"bomber": {"hp": 30.0, "half": Vector2(14, 14), "contact": 0.0, "flying": true, "scale": 1.1, "tint": Color(1.0, 0.6, 0.45)},
	"magnet": {"hp": 45.0, "half": Vector2(16, 16), "contact": 0.0, "flying": true, "scale": 1.2, "tint": Color(0.6, 0.65, 0.8)},
	"repair": {"hp": 35.0, "half": Vector2(12, 12), "contact": 0.0, "flying": true, "scale": 0.9, "tint": Color(0.6, 1.0, 0.7)},
	"boss": {"hp": 900.0, "half": Vector2(30, 70), "contact": 18.0, "flying": false, "scale": 2.2, "tint": Color(1.0, 0.55, 0.45)},
}

const LABELS := {
	"roller": "Roller", "gunner": "Gunner", "charger": "Charger", "scrapper": "Scrapper",
	"sniper": "Sniper", "mortar": "Mortar", "mite": "Mite", "shield": "Shield Bot",
	"turret": "Turret", "tank": "Tank", "splitter": "Splitter", "splitling": "Splitling",
	"drone": "Drone", "jammer": "Jammer", "bomber": "Bomber", "magnet": "Magnet Bot",
	"repair": "Repair Bot", "boss": "The Foreman",
}

# Small arms that bounce off a Tank's plating. Rams, slams, vents and lightning hit it fully.
# One boss per floor. They share the "boss" stats and differ in health, tint and attacks.
const BOSSES := {
	"foreman": {"name": "The Foreman", "hp": 900.0, "tint": Color(1.0, 0.55, 0.45)},
	"magnate": {"name": "The Magnate", "hp": 1100.0, "tint": Color(0.55, 0.65, 1.0)},
	"chopper": {"name": "The Chopper", "hp": 1250.0, "tint": Color(0.75, 1.0, 0.55)},
	"rust": {"name": "Boss Rust", "hp": 1500.0, "tint": Color(0.85, 0.45, 0.25)},
}

const LIGHT_SOURCES := ["Basic shot", "Shotgun", "Attack Drone"]
const TANK_ARMOR := 0.4
const TURRET_BACK_BONUS := 1.5

var game
var kind := "roller"
var hp := 20.0
var max_hp := 20.0
var half := Vector2(12, 30)
var flying := false
var contact := 10.0
var state := "idle"
var timer := 1.0
var burst_left := 0
var facing := 1.0
var flash := 0.0
var ram_cd := 0.0
var field_color := ""
var field = null
var carried = null
var carried_slot := -1
var phase2 := false
var summon_t := 4.0
var last_attack := ""
var airborne := false
var dead := false
# Elites: more health, faster, golden, and one extra behavior. The key carrier is always an elite.
var elite := false
var drops_key := false
var speed_mult := 1.0
# Shield Bots and Turrets block hits from the side they face.
var front_armor := false
var turn_t := 0.0
var block_t := 0.0
var aim_dir := Vector2.RIGHT
var aim_point := Vector2.ZERO
var dashes_left := 0
# Magnet Bot: pull target. Repair Bot: what it's fixing (a bot or a generator).
var pull_to := Vector2.ZERO
var mend = null
var mend_gen = null
var mend_t := 0.0
var bob := 0.0
var boss_id := "foreman"
var recolor_t := 0.0

var _sprite: Sprite2D


func setup(k: String, opts: Dictionary) -> void:
	kind = k
	var s: Dictionary = STATS[kind]
	hp = s.hp
	max_hp = hp
	half = s.half
	contact = s.contact
	flying = s.flying
	field_color = opts.get("color", "")
	elite = opts.get("elite", false)
	drops_key = opts.get("key", false)
	facing = opts.get("face", 1.0)
	front_armor = kind == "shield" or kind == "turret"
	if kind == "boss":
		boss_id = opts.get("boss", "foreman")
		hp = BOSSES[boss_id].hp
		max_hp = hp
	bob = randf() * TAU
	if elite:
		hp *= 2.5
		max_hp = hp
		half *= 1.15
		speed_mult = 1.3
	collision_layer = 1 << 7 # "enemy"
	collision_mask = 1 if flying else (1 | 2)
	var cs := CollisionShape2D.new()
	if flying:
		var c := CircleShape2D.new()
		c.radius = half.x
		cs.shape = c
	else:
		var c := CapsuleShape2D.new()
		c.radius = half.x
		c.height = maxf(half.y * 2.0, half.x * 2.0)
		cs.shape = c
	add_child(cs)
	_sprite = Sprite2D.new()
	_sprite.texture = FLYER_TEX if flying else GROUND_TEX
	var sc = s.scale
	_sprite.scale = (sc if sc is Vector2 else Vector2.ONE * sc) * (1.15 if elite else 1.0)
	_sprite.modulate = Color(1.0, 0.82, 0.3) if elite else s.tint
	if kind == "boss":
		_sprite.modulate = BOSSES[boss_id].tint
	if kind == "jammer":
		_sprite.modulate = Parts.ui_color(field_color)
	add_child(_sprite)
	timer = randf_range(0.6, 1.4)


func hit_rect() -> Rect2:
	return Rect2(global_position - half, half * 2.0)


func label() -> String:
	if kind == "boss":
		return BOSSES[boss_id].name
	return ("Elite " if elite else "") + LABELS[kind]


func step(dt: float) -> void:
	flash -= dt
	ram_cd -= dt
	timer -= dt
	block_t -= dt
	var p: Vector2 = game.target_pos()
	var to_p := p - global_position
	var dist := to_p.length()
	var sees: bool = dist < 460.0 and game.los(global_position, p)
	match kind:
		"roller":
			_roller(dt, sees, to_p)
		"gunner":
			_gunner(dt, sees, to_p, dist)
		"charger":
			_charger(dt, sees, to_p)
		"scrapper":
			_scrapper(dt, sees, to_p)
		"sniper":
			_sniper(dt, to_p, dist)
		"mortar":
			_mortar(dt, to_p, dist)
		"mite", "splitter", "splitling":
			var speeds := {"mite": 190.0, "splitter": 90.0, "splitling": 150.0}
			_ground_move(dt, signf(to_p.x) if sees else 0.0, speeds[kind])
			if kind == "mite" and is_on_floor() and sees and randf() < 0.8 * dt:
				velocity.y = -300.0
		"shield":
			_shield(dt, sees, to_p, dist)
		"turret":
			_turret(dt, to_p, dist)
		"tank":
			_tank(dt, sees, to_p)
		"drone":
			_drone(dt, sees, to_p, dist)
		"jammer":
			_fly_toward(dt, p + Vector2(0, -40), 60.0)
		"bomber":
			_bomber(dt, to_p)
		"magnet":
			_magnet(dt, to_p, dist)
		"repair":
			_repair(dt, to_p, dist)
		"boss":
			match boss_id:
				"magnate": _magnate(dt, to_p)
				"chopper": _chopper(dt, to_p)
				"rust": _rust(dt, to_p)
				_: _boss(dt, to_p)
	if not flying and not is_on_floor():
		# Capped, so a bot wedged on a ledge can't build up enough speed to tunnel through tiles.
		velocity.y = minf(velocity.y + GRAVITY * dt, MAX_FALL)
	move_and_slide()
	_sprite.modulate.a = 1.0
	_sprite.self_modulate = Color(3, 3, 3) if flash > 0.0 else Color.WHITE
	if front_armor or kind in ["sniper", "mortar", "tank"]:
		_sprite.flip_h = facing < 0.0
	queue_redraw()


## Applies a hit. `hit_dir` is the direction the hit travels (bullets, rams, vents), so armored
## fronts can block it. Returns false when the hit was blocked.
func take_damage(amount: float, source: String, knock := Vector2.ZERO, hit_dir := Vector2.ZERO) -> bool:
	if dead:
		return false
	if front_armor and hit_dir != Vector2.ZERO:
		var from_front := signf(hit_dir.x) == -facing and absf(hit_dir.x) > 0.2
		if from_front:
			_blocked()
			return false
		if kind == "turret":
			amount *= TURRET_BACK_BONUS
	if kind == "tank" and LIGHT_SOURCES.has(source):
		amount *= TANK_ARMOR
	hp -= amount
	flash = 0.08
	var resist := 0.25 if kind == "boss" else (0.2 if kind == "tank" else (0.0 if kind == "turret" else 1.0))
	velocity += knock * resist
	game.record_damage(source, amount)
	game.floater(global_position + Vector2(randf_range(-8, 8), -half.y - 6), str(roundi(amount)), Color(1, 0.95, 0.8), 0.6)
	if hp <= 0.0:
		dead = true
		game.on_enemy_killed(self)
	else:
		game.sfx.play("hit", -10.0, randf_range(0.9, 1.1))
	return true


func _blocked() -> void:
	var front := global_position + Vector2(facing * (half.x + 4), -4)
	for i in 4:
		game.particle(front, Vector2(facing * randf_range(60, 160), randf_range(-120, 40)), Color("e8f0ff"), 0.2, 2.0)
	if block_t <= 0.0:
		block_t = 0.8
		game.floater(global_position + Vector2(0, -half.y - 10), "BLOCKED", Color(0.8, 0.85, 0.95), 0.6, 15)
		game.sfx.play("hit", -12.0, 1.8)


# --- movement helpers ---

func _ground_move(dt: float, dir: float, max_speed: float) -> void:
	max_speed *= speed_mult
	var on_floor := is_on_floor()
	if dir != 0.0:
		velocity.x = clampf(velocity.x + dir * max_speed * 10.0 * dt * (1.0 if on_floor else 0.3), -max_speed, max_speed)
		facing = dir
		# Hop over low walls instead of grinding against them.
		if on_floor and is_on_wall():
			velocity.y = -430.0
	elif on_floor:
		velocity.x = move_toward(velocity.x, 0, max_speed * 3.0 * dt)


func _fly_toward(dt: float, target: Vector2, max_speed: float) -> void:
	var d := target - global_position
	if d.length() > 6.0:
		velocity += d.normalized() * max_speed * 10.0 * dt
		velocity = velocity.limit_length(max_speed)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, max_speed * 3.0 * dt)


func _shoot(dir: Vector2, speed: float, dmg: float, from := Vector2.INF) -> void:
	var at := global_position if from == Vector2.INF else from
	game.fire(at, dir.normalized() * speed, dmg, false, Color("ff5050"), label(), false, 3.0)
	game.sfx.play("enemy_shot", -14.0)


## A hostile shell with gravity that explodes where it lands.
func _lob(vel: Vector2, dmg: float, blast: float, grav := GRAVITY) -> void:
	game.shell(global_position + Vector2(0, -half.y * 0.6), vel, dmg, false, Color("ff7a40"), label(), grav, blast)
	game.sfx.play("enemy_shot", -10.0, 0.6)


## Launch velocity that lands a gravity shell on `target` after `t` seconds.
func _ballistic(from: Vector2, target: Vector2, t: float) -> Vector2:
	var d := target - from
	return Vector2(d.x / t, (d.y - 0.5 * GRAVITY * t * t) / t)


# --- behaviors ---

func _roller(dt: float, sees: bool, to_p: Vector2) -> void:
	_ground_move(dt, signf(to_p.x) if sees else 0.0, 100.0)
	# Elite: lunges at you when it gets close.
	if elite and sees and is_on_floor() and timer <= 0.0 and absf(to_p.x) < 170.0:
		velocity = Vector2(signf(to_p.x) * 380.0, -330.0)
		timer = 1.8


func _gunner(dt: float, sees: bool, to_p: Vector2, dist: float) -> void:
	var dir := 0.0
	if sees:
		if dist > 260.0:
			dir = signf(to_p.x)
		elif dist < 150.0:
			dir = -signf(to_p.x)
	_ground_move(dt, dir, 80.0)
	if sees:
		facing = signf(to_p.x)
	match state:
		"idle":
			if sees and timer <= 0.0:
				state = "aim"
				timer = 0.45
		"aim":
			if timer <= 0.0:
				state = "burst"
				# Elite: longer bursts.
				burst_left = 5 if elite else 3
				timer = 0.0
		"burst":
			if timer <= 0.0:
				_shoot(to_p, 280.0, 7.0)
				burst_left -= 1
				timer = 0.15
				if burst_left <= 0:
					state = "idle"
					timer = 2.0


func _charger(dt: float, sees: bool, to_p: Vector2) -> void:
	match state:
		"idle":
			_ground_move(dt, signf(to_p.x) if sees else 0.0, 60.0)
			if sees and timer <= 0.0 and absf(to_p.y) < 70.0 and absf(to_p.x) < 300.0:
				state = "windup"
				timer = 0.6
				facing = signf(to_p.x)
				# Elite: turns around and dashes a second time.
				dashes_left = 2 if elite else 1
		"windup":
			velocity.x = move_toward(velocity.x, 0, 800 * dt)
			_sprite.position.x = randf_range(-2, 2)
			if timer <= 0.0:
				_sprite.position.x = 0
				state = "dash"
				timer = 0.6
				velocity.x = facing * 460.0 * speed_mult
		"dash":
			velocity.x = facing * 460.0 * speed_mult
			if is_on_wall():
				state = "stun"
				timer = 1.0
				game.add_shake(3.0)
			elif timer <= 0.0:
				dashes_left -= 1
				if dashes_left > 0:
					state = "windup"
					timer = 0.35
					facing = signf(to_p.x) if to_p.x != 0.0 else -facing
				else:
					state = "idle"
					timer = 1.2
		"stun":
			velocity.x = move_toward(velocity.x, 0, 800 * dt)
			if timer <= 0.0:
				state = "idle"
				timer = 0.8


func _scrapper(dt: float, sees: bool, to_p: Vector2) -> void:
	if carried == null:
		_ground_move(dt, signf(to_p.x) if sees else 0.0, 170.0)
	else:
		# Run off with the part, hopping whenever it hits a wall.
		_ground_move(dt, -signf(to_p.x) if absf(to_p.x) > 1.0 else 1.0, 185.0)


func _sniper(dt: float, to_p: Vector2, dist: float) -> void:
	var sees: bool = dist < 760.0 and game.los(global_position + Vector2(0, -14), game.target_pos())
	# Keeps its distance.
	var dir := 0.0
	if sees and dist < 300.0 and state != "lock":
		dir = -signf(to_p.x)
	_ground_move(dt, dir, 70.0)
	if sees:
		facing = signf(to_p.x)
	match state:
		"idle":
			if sees and timer <= 0.0:
				state = "aim"
				timer = 1.3
		"aim":
			# The aiming line tracks you, then freezes just before the shot.
			aim_dir = (game.target_pos() - global_position - Vector2(0, -14)).normalized()
			if not sees:
				state = "idle"
				timer = 0.8
			elif timer <= 0.0:
				state = "lock"
				timer = 0.35
		"lock":
			if timer <= 0.0:
				_shoot(aim_dir, 780.0, 15.0, global_position + Vector2(0, -14))
				# Elite: a second shot at where you are now.
				if elite:
					state = "second"
					timer = 0.25
				else:
					state = "idle"
					timer = 1.6
		"second":
			if timer <= 0.0:
				_shoot(game.target_pos() - global_position - Vector2(0, -14), 780.0, 12.0, global_position + Vector2(0, -14))
				state = "idle"
				timer = 1.8


func _mortar(dt: float, to_p: Vector2, dist: float) -> void:
	# Barely moves. Lobs shells over platforms, so it doesn't need to see you.
	_ground_move(dt, 0.0, 30.0)
	facing = signf(to_p.x) if to_p.x != 0.0 else facing
	match state:
		"idle":
			if timer <= 0.0 and dist < 900.0:
				state = "windup"
				timer = 0.8
				aim_point = game.target_pos() + Vector2(0, 14)
		"windup":
			if timer <= 0.0:
				var from := global_position + Vector2(0, -half.y * 0.6)
				var t := clampf(from.distance_to(aim_point) / 360.0, 0.9, 1.6)
				_lob(_ballistic(from, aim_point, t), 14.0, 60.0)
				# Elite: a three-shell volley.
				if elite:
					_lob(_ballistic(from, aim_point + Vector2(-90, 0), t), 10.0, 50.0)
					_lob(_ballistic(from, aim_point + Vector2(90, 0), t), 10.0, 50.0)
				state = "idle"
				timer = 2.6


func _shield(dt: float, sees: bool, to_p: Vector2, dist: float) -> void:
	# Turns to face you slowly, so you can get behind it.
	var want := signf(to_p.x)
	if sees and want != 0.0 and want != facing:
		turn_t += dt
		if turn_t > 0.75:
			facing = want
			turn_t = 0.0
	else:
		turn_t = 0.0
	match state:
		"idle":
			var dir := facing if sees and want == facing and dist > 40.0 else 0.0
			var keep := facing
			_ground_move(dt, dir, 55.0)
			facing = keep
			# Elite: a shield bash when you're close in front of it.
			if elite and sees and want == facing and dist < 110.0 and timer <= 0.0:
				state = "windup"
				timer = 0.4
		"windup":
			velocity.x = move_toward(velocity.x, 0, 800 * dt)
			if timer <= 0.0:
				state = "dash"
				timer = 0.25
		"dash":
			velocity.x = facing * 420.0
			if timer <= 0.0 or is_on_wall():
				state = "idle"
				timer = 1.8


func _turret(dt: float, to_p: Vector2, dist: float) -> void:
	velocity.x = 0.0
	# Elite: swings around to face the other way every few seconds.
	if elite:
		turn_t += dt
		if turn_t > 7.0:
			facing = -facing
			turn_t = 0.0
	var in_front: bool = signf(to_p.x) == facing and dist < 520.0 and game.los(global_position + Vector2(0, -8), game.target_pos())
	if in_front:
		aim_dir = to_p.normalized()
	match state:
		"idle":
			if in_front and timer <= 0.0:
				state = "burst"
				burst_left = 3
				timer = 0.25
		"burst":
			if timer <= 0.0:
				_shoot(aim_dir, 320.0, 7.0, global_position + Vector2(0, -8) + aim_dir * 18.0)
				burst_left -= 1
				timer = 0.18
				if burst_left <= 0:
					state = "idle"
					timer = 1.8


func _tank(dt: float, sees: bool, to_p: Vector2) -> void:
	_ground_move(dt, signf(to_p.x) if sees else 0.0, 40.0)
	if sees and timer <= 0.0:
		timer = 3.0
		var dir := to_p.normalized()
		var from := global_position + Vector2(facing * half.x, -half.y * 0.4)
		# Elite: its shells explode.
		game.shell(from, dir * 230.0, 16.0, false, Color("ffb050"), label(), 0.0, 70.0 if elite else 0.0)
		game.sfx.play("shotgun", -10.0, 0.6)
		game.add_shake(2.0)


func _drone(dt: float, sees: bool, to_p: Vector2, dist: float) -> void:
	# Same idea as the jam's flying_enemy: hover above the player at an ideal distance.
	if sees:
		var dir := Vector2.ZERO
		if absf(to_p.x) > 60.0:
			dir.x = signf(to_p.x)
		if to_p.y - 60.0 < 0.0:
			dir.y = -1.0
		elif to_p.y - 90.0 > 0.0:
			dir.y = 1.0
		if dir != Vector2.ZERO:
			velocity += dir * 1000.0 * dt
			velocity = velocity.limit_length(100.0 * speed_mult)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * dt)
		if timer <= 0.0 and dist < 320.0:
			_shoot(to_p, 300.0, 7.0)
			# Elite: a three-shot spread.
			if elite:
				_shoot(to_p.rotated(0.22), 300.0, 6.0)
				_shoot(to_p.rotated(-0.22), 300.0, 6.0)
			timer = 1.4
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * dt)


func _bomber(dt: float, to_p: Vector2) -> void:
	# Flies over you and drops bombs. It stays high, so it's hard to reach without jumping.
	bob += dt * 2.0
	var p: Vector2 = game.target_pos()
	var target := Vector2(p.x + sin(bob) * 50.0, maxf(2.5 * T, p.y - 180.0))
	_fly_toward(dt, target, 120.0 * speed_mult)
	if absf(to_p.x) < 50.0 and to_p.y > 40.0 and timer <= 0.0:
		_lob(Vector2(velocity.x * 0.4, 40.0), 14.0, 56.0)
		# Elite: a cluster of three.
		if elite:
			_lob(Vector2(-90.0, -60.0), 10.0, 48.0)
			_lob(Vector2(90.0, -60.0), 10.0, 48.0)
		timer = 1.7


func _magnet(dt: float, to_p: Vector2, dist: float) -> void:
	# Hovers, then pulls you toward the nearest field that's on (or toward itself).
	var p: Vector2 = game.target_pos()
	bob += dt
	_fly_toward(dt, p + Vector2(sin(bob) * 120.0, -150.0), 70.0)
	match state:
		"idle":
			if timer <= 0.0 and dist < 360.0:
				state = "pull"
				timer = 2.0
				game.sfx.play("hack", -8.0, 0.5)
		"pull":
			var f = game.nearest_field(game.player.global_position)
			pull_to = f.center() if f != null else global_position
			var d: Vector2 = pull_to - game.player.global_position
			if d.length() > 12.0 and game.player.global_position.distance_to(global_position) < 380.0:
				game.player.velocity += d.normalized() * (900.0 if elite else 650.0) * dt
			if timer <= 0.0:
				state = "idle"
				timer = 2.5
				# Elite: a three-shot fan when the pull ends.
				if elite:
					for i in 3:
						_shoot(to_p.rotated((i - 1) * 0.25), 280.0, 7.0)


func _repair(dt: float, to_p: Vector2, dist: float) -> void:
	# Heals damaged bots and rebuilds destroyed generators. Keeps away from you.
	if mend != null and (not is_instance_valid(mend) or mend.dead or mend.hp >= mend.max_hp):
		mend = null
	if mend_gen != null and mend_gen.hp > 0.0:
		mend_gen = null
	if mend == null and mend_gen == null and timer <= 0.0:
		timer = 0.5
		mend = game.most_damaged_enemy(self)
		if mend == null:
			mend_gen = game.dead_gen()
			mend_t = 0.0
	var goal := global_position
	if mend != null:
		goal = mend.global_position + Vector2(0, -70)
	elif mend_gen != null:
		goal = mend_gen.pos + Vector2(0, -60)
	if dist < 160.0:
		goal -= to_p.normalized() * 120.0
	_fly_toward(dt, goal, 90.0 * speed_mult)
	if mend != null and global_position.distance_to(mend.global_position) < 140.0:
		mend.hp = minf(mend.max_hp, mend.hp + 12.0 * dt)
		# Elite: heals every bot around its target too.
		if elite:
			for e in game.enemies:
				if e != mend and e != self and not e.dead and e.global_position.distance_to(global_position) < 160.0:
					e.hp = minf(e.max_hp, e.hp + 8.0 * dt)
	elif mend_gen != null and global_position.distance_to(mend_gen.pos) < 120.0:
		mend_t += dt
		if mend_t >= 3.5:
			game.rebuild_gen(mend_gen)
			mend_gen = null
			timer = 2.0


func _boss(dt: float, to_p: Vector2) -> void:
	if not phase2 and hp < max_hp * 0.5:
		phase2 = true
		game.announce("The Foreman is overheating", "Its field grows and it calls for backup")
		game.sfx.play("roar")
	if field != null and is_instance_valid(field):
		field.set_radius(180.0 if phase2 else 130.0)
	if not _boss_moves(dt):
		_foreman(dt, to_p)
	if phase2:
		summon_t -= dt
		if summon_t <= 0.0:
			summon_t = 9.0
			if game.count_kind("roller") < 4:
				game.spawn_enemy("roller", Vector2(3 * T, 3 * T), {})
				game.spawn_enemy("roller", Vector2((game.room.w - 3) * T, 3 * T), {})


func _foreman(dt: float, to_p: Vector2) -> void:
	match state:
		"idle":
			_ground_move(dt, signf(to_p.x), 80.0)
			if timer <= 0.0:
				_boss_pick(to_p)
		"spray":
			velocity.x = move_toward(velocity.x, 0, 800 * dt)
			if timer <= 0.0 and burst_left > 0:
				for i in 7:
					_shoot(to_p.rotated((i - 3) * 0.16), 260.0, 8.0)
				burst_left -= 1
				timer = 0.45
				if burst_left <= 0:
					state = "idle"
					timer = 1.4


func _boss_pick(to_p: Vector2) -> void:
	var options := ["charge", "spray", "leap"]
	options.erase(last_attack)
	last_attack = options.pick_random()
	facing = signf(to_p.x)
	match last_attack:
		"charge":
			state = "windup"
			timer = 0.7
		"spray":
			state = "spray"
			burst_left = 3 if phase2 else 2
			timer = 0.3
		"leap":
			state = "leap"
			airborne = false
			velocity = Vector2(clampf(to_p.x * 1.1, -380.0, 380.0), -560.0)


# --- shared boss attacks ---

func _enter_phase2(title: String, sub: String) -> bool:
	if phase2 or hp >= max_hp * 0.5:
		return false
	phase2 = true
	game.announce(title, sub)
	game.sfx.play("roar")
	return true


## Charge, stun and leap, shared by every boss. Returns true if it handled the state.
func _boss_moves(dt: float) -> bool:
	match state:
		"windup":
			velocity.x = move_toward(velocity.x, 0, 800 * dt)
			_sprite.position.x = randf_range(-3, 3)
			if timer <= 0.0:
				_sprite.position.x = 0
				state = "dash"
				timer = 0.9
		"dash":
			velocity.x = facing * 480.0
			if is_on_wall():
				state = "stun"
				timer = 0.9
				game.add_shake(8.0)
			elif timer <= 0.0:
				state = "idle"
				timer = 1.0
		"stun":
			velocity.x = move_toward(velocity.x, 0, 800 * dt)
			if timer <= 0.0:
				state = "idle"
				timer = 0.6
		"leap":
			if not is_on_floor():
				airborne = true
			elif airborne:
				airborne = false
				game.boss_slam(global_position + Vector2(0, half.y), 160.0, 18.0)
				state = "idle"
				timer = 1.2
		_:
			return false
	return true


func _start_move(move: String, to_p: Vector2) -> void:
	last_attack = move
	facing = signf(to_p.x) if to_p.x != 0.0 else facing
	match move:
		"charge":
			state = "windup"
			timer = 0.7
		"leap":
			state = "leap"
			airborne = false
			velocity = Vector2(clampf(to_p.x * 1.1, -380.0, 380.0), -560.0)


func _pick(options: Array) -> String:
	options.erase(last_attack)
	return options.pick_random()


## The Magnate: its field takes the color you rely on most, it drags you in, and it scatters
## short-lived fields across the floor.
func _magnate(dt: float, to_p: Vector2) -> void:
	_enter_phase2("The Magnate is overcharged", "It pulls harder and drops more fields")
	recolor_t -= dt
	if field != null and is_instance_valid(field):
		field.set_radius(150.0 if phase2 else 120.0)
		field.next_warn = recolor_t < 1.2
		if recolor_t <= 0.0:
			recolor_t = 6.0
			field.color = game.dominant_color()
	if _boss_moves(dt):
		return
	match state:
		"idle":
			_ground_move(dt, signf(to_p.x), 70.0)
			if timer <= 0.0:
				var move := _pick(["pull", "drop", "ring", "leap"])
				_start_move(move, to_p)
				match move:
					"pull":
						state = "pull"
						timer = 2.4
						game.sfx.play("hack", -4.0, 0.4)
					"drop":
						state = "drop"
						timer = 0.6
					"ring":
						state = "ring"
						burst_left = 3 if phase2 else 2
						timer = 0.4
		"pull":
			velocity.x = move_toward(velocity.x, 0, 800 * dt)
			var d: Vector2 = global_position - game.player.global_position
			if d.length() < 560.0:
				game.player.velocity += d.normalized() * (820.0 if phase2 else 620.0) * dt
			if timer <= 0.0:
				state = "idle"
				timer = 1.0
		"drop":
			velocity.x = move_toward(velocity.x, 0, 800 * dt)
			if timer <= 0.0:
				var n := 4 if phase2 else 3
				for i in n:
					var x := randf_range(3.0 * T, (game.room.w - 3.0) * T)
					var y := randf_range(6.0 * T, (game.room.h - 2.0) * T)
					game.add_temp_field({"shape": "circle", "pos": Vector2(x, y), "radius": 75.0, "color": Parts.COLORS.pick_random(), "life": 7.0})
				game.sfx.play("zap", -6.0, 0.6)
				state = "idle"
				timer = 1.4
		"ring":
			velocity.x = move_toward(velocity.x, 0, 800 * dt)
			if timer <= 0.0:
				var n := 16 if phase2 else 12
				var off := randf() * TAU
				for i in n:
					_shoot(Vector2.RIGHT.rotated(off + TAU * i / n), 210.0, 8.0)
				burst_left -= 1
				timer = 0.6
				if burst_left <= 0:
					state = "idle"
					timer = 1.4


## The Chopper: two fields of different colors orbit it, so where they cross both go dark.
## Throws saws that bounce off the walls.
func _chopper(dt: float, to_p: Vector2) -> void:
	if _enter_phase2("The Chopper spins up", "Its fields orbit faster, and mites pour in"):
		for f in game.fields:
			if f.carrier == self:
				f.orbit.speed *= 1.6
	if phase2:
		summon_t -= dt
		if summon_t <= 0.0:
			summon_t = 10.0
			if game.count_kind("mite") < 8:
				for i in 4:
					game.spawn_enemy("mite", Vector2((3 + i) * T, 3 * T), {})
	if _boss_moves(dt):
		return
	match state:
		"idle":
			_ground_move(dt, signf(to_p.x), 85.0)
			if timer <= 0.0:
				var move := _pick(["saws", "charge", "barrage", "leap"])
				_start_move(move, to_p)
				match move:
					"saws":
						state = "saws"
						timer = 0.5
					"barrage":
						state = "barrage"
						burst_left = 5 if phase2 else 4
						timer = 0.5
		"saws":
			velocity.x = move_toward(velocity.x, 0, 800 * dt)
			if timer <= 0.0:
				for i in 3:
					game.saw(global_position + Vector2(0, -20), to_p.normalized().rotated((i - 1) * 0.35) * 300.0, 10.0, label())
				game.sfx.play("shotgun", -6.0, 1.5)
				state = "idle"
				timer = 1.6
		"barrage":
			velocity.x = move_toward(velocity.x, 0, 800 * dt)
			if timer <= 0.0:
				var at: Vector2 = game.target_pos() + Vector2(randf_range(-120, 120), 14)
				var from := global_position + Vector2(0, -half.y * 0.6)
				_lob(_ballistic(from, at, 1.1), 12.0, 55.0)
				burst_left -= 1
				timer = 0.3
				if burst_left <= 0:
					state = "idle"
					timer = 1.4


## Boss Rust, the gang boss: a field that stalks you in the color you rely on most, elite
## bodyguards, and in its second phase two room-wide fields held up by generators.
func _rust(dt: float, to_p: Vector2) -> void:
	if _enter_phase2("Boss Rust floods the room", "Shoot the generators to take the fields down"):
		var colors := [game.dominant_color()]
		colors.append(Parts.COLORS.filter(func(c): return c != colors[0]).pick_random())
		var w: int = game.room.w
		game.add_gen_field({"shape": "rect", "pos": Vector2(T, T), "size": Vector2((w / 2 - 1) * T, (game.room.h - 2) * T), "color": colors[0], "generator": Vector2(8.5 * T, 5 * T - 15), "gen_index": 100})
		game.add_gen_field({"shape": "rect", "pos": Vector2(w / 2 * T, T), "size": Vector2((w / 2 - 1) * T, (game.room.h - 2) * T), "color": colors[1], "generator": Vector2((w - 8.5) * T, 5 * T - 15), "gen_index": 101})
	recolor_t -= dt
	if field != null and is_instance_valid(field):
		field.next_warn = recolor_t < 1.2
		if recolor_t <= 0.0:
			recolor_t = 8.0
			field.color = game.dominant_color()
	if _boss_moves(dt):
		return
	match state:
		"idle":
			_ground_move(dt, signf(to_p.x), 75.0)
			if timer <= 0.0:
				var move := _pick(["snipe", "summon", "leap", "charge"])
				if move == "summon" and game.enemies.size() > 3:
					move = "snipe"
				_start_move(move, to_p)
				match move:
					"snipe":
						state = "aim"
						timer = 1.0
						burst_left = 3
					"summon":
						state = "summon"
						timer = 0.6
		"aim":
			velocity.x = move_toward(velocity.x, 0, 800 * dt)
			aim_dir = (game.target_pos() - global_position - Vector2(0, -30)).normalized()
			if timer <= 0.0:
				state = "snipe"
				timer = 0.0
		"snipe":
			if timer <= 0.0:
				_shoot(game.target_pos() - global_position - Vector2(0, -30), 720.0, 12.0, global_position + Vector2(0, -30))
				burst_left -= 1
				timer = 0.22
				if burst_left <= 0:
					state = "idle"
					timer = 1.3
		"summon":
			velocity.x = move_toward(velocity.x, 0, 800 * dt)
			if timer <= 0.0:
				for x in [4, game.room.w - 4]:
					var k: String = ["gunner", "charger", "shield"].pick_random()
					game.spawn_enemy(k, Vector2(x * T, 3 * T), {"elite": true, "face": 1.0 if x < 10 else -1.0})
				game.sfx.play("door", -4.0, 0.6)
				state = "idle"
				timer = 1.5


func _draw() -> void:
	if elite:
		draw_rect(Rect2(-half - Vector2(3, 3), half * 2.0 + Vector2(6, 6)), Color(1.0, 0.82, 0.3, 0.8), false, 2.0)
	if drops_key:
		var k := Vector2(0, -half.y - 24)
		draw_circle(k + Vector2(-4, 0), 4.0, Color(1.0, 0.82, 0.3))
		draw_rect(Rect2(k + Vector2(0, -1), Vector2(8, 2)), Color(1.0, 0.82, 0.3))
	if hp < max_hp and kind != "boss":
		var w := half.x * 2.0 + 10.0
		draw_rect(Rect2(-w / 2, -half.y - 10, w, 4), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w / 2, -half.y - 10, w * hp / max_hp, 4), Color("e05050"))
	match kind:
		"gunner":
			var to_p: Vector2 = (game.target_pos() - global_position).normalized()
			var col := Color("ff5050") if state == "aim" else Color(0.75, 0.8, 0.9)
			draw_line(Vector2(0, -12), Vector2(0, -12) + to_p * 22.0, col, 4.0)
		"charger", "boss":
			if state == "windup":
				_exclaim()
			if state == "aim":
				var eye := Vector2(0, -30)
				var end: Vector2 = game.ray_end(global_position + eye, global_position + eye + aim_dir * 1200.0) - global_position
				draw_line(eye, end, Color(1, 0.3, 0.25, 0.5 + 0.4 * sin(Time.get_ticks_msec() / 40.0)), 2.0)
			if state == "pull" or state == "drop" or state == "ring" or state == "saws":
				_exclaim()
		"sniper":
			var eye := Vector2(0, -14)
			if state == "aim" or state == "lock":
				var end: Vector2 = game.ray_end(global_position + eye, global_position + eye + aim_dir * 900.0) - global_position
				var col := Color(1, 0.25, 0.2, 0.9) if state == "lock" else Color(1, 0.3, 0.25, 0.35)
				draw_line(eye, end, col, 2.0 if state == "lock" else 1.0)
			draw_line(eye, eye + aim_dir * 26.0, Color(0.75, 0.85, 0.8), 3.0)
		"mortar":
			draw_line(Vector2(0, -half.y + 4), Vector2(facing * 12, -half.y - 12), Color(0.5, 0.48, 0.44), 7.0)
			if state == "windup":
				# Where the shell will land.
				var at: Vector2 = aim_point - global_position
				var a := 0.4 + 0.4 * sin(Time.get_ticks_msec() / 60.0)
				draw_arc(at, 30.0, 0, TAU, 20, Color(1, 0.4, 0.2, a), 2.0)
				draw_line(at + Vector2(-8, 0), at + Vector2(8, 0), Color(1, 0.4, 0.2, a), 2.0)
		"shield", "turret":
			var x := facing * (half.x + 3)
			var col := Color(0.75, 0.85, 1.0, 0.95)
			draw_rect(Rect2(Vector2(x - 2.5, -half.y), Vector2(5, half.y * 2.0)), col)
			if kind == "turret":
				draw_line(Vector2(0, -8), Vector2(0, -8) + aim_dir * 22.0, Color(0.8, 0.8, 0.85), 5.0)
				# The weak spot on its back.
				draw_circle(Vector2(-facing * (half.x - 2), -2), 4.0, Color("ff7050"))
				if elite and turn_t > 6.0:
					_exclaim()
			if state == "windup":
				_exclaim()
		"tank":
			draw_line(Vector2(0, -half.y * 0.4), Vector2(facing * (half.x + 14), -half.y * 0.4), Color(0.4, 0.44, 0.36), 8.0)
		"magnet":
			draw_arc(Vector2(0, 6), 10.0, 0, PI, 10, Color(0.9, 0.3, 0.3), 4.0)
			if state == "pull":
				var pp: Vector2 = game.player.global_position - global_position
				for i in 3:
					var off := Vector2(randf_range(-6, 6), randf_range(-6, 6))
					draw_line(Vector2.ZERO, pp + off, Color(0.7, 0.75, 1.0, 0.5), 1.5)
				draw_arc(pull_to - global_position, 18.0 + fmod(Time.get_ticks_msec() / 25.0, 18.0), 0, TAU, 16, Color(0.7, 0.75, 1.0, 0.6), 2.0)
		"repair":
			draw_rect(Rect2(-2, -8, 4, 12), Color(0.4, 1.0, 0.5))
			draw_rect(Rect2(-6, -4, 12, 4), Color(0.4, 1.0, 0.5))
			var beam_to = null
			if mend != null and is_instance_valid(mend) and global_position.distance_to(mend.global_position) < 140.0:
				beam_to = mend.global_position
			elif mend_gen != null and global_position.distance_to(mend_gen.pos) < 120.0:
				beam_to = mend_gen.pos
			if beam_to != null:
				draw_line(Vector2.ZERO, beam_to - global_position, Color(0.4, 1.0, 0.5, 0.6), 2.0)
	if carried != null:
		var c: Color = Parts.part_color(carried.id)
		draw_rect(Rect2(-9, -half.y - 26, 18, 14), c)
		draw_rect(Rect2(-9, -half.y - 26, 18, 14), Color.WHITE, false, 1.5)


func _exclaim() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(-5, -half.y - 16), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffd040"))
