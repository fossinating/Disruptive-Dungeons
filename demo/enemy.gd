extends CharacterBody2D
## All demo bots in one script, switched on `kind`. Roller and drone follow the jam's
## moving_enemy and flying_enemy; the rest reuse their sprites with a tint until they get art.

const Parts := preload("res://demo/parts.gd")
const GROUND_TEX := preload("res://enemies/moving enemy.png")
const FLYER_TEX := preload("res://enemies/flying enemy.png")
const GRAVITY := 980.0
const T := 32

const STATS := {
	"roller": {"hp": 35.0, "half": Vector2(12, 30), "contact": 12.0, "flying": false, "scale": 1.0, "tint": Color.WHITE},
	"gunner": {"hp": 40.0, "half": Vector2(12, 30), "contact": 6.0, "flying": false, "scale": 1.0, "tint": Color(0.6, 0.78, 1.0)},
	"charger": {"hp": 60.0, "half": Vector2(15, 38), "contact": 10.0, "flying": false, "scale": 1.2, "tint": Color(1.0, 0.7, 0.4)},
	"scrapper": {"hp": 45.0, "half": Vector2(10, 24), "contact": 0.0, "flying": false, "scale": 0.8, "tint": Color(0.85, 0.6, 0.35)},
	"drone": {"hp": 24.0, "half": Vector2(13, 13), "contact": 0.0, "flying": true, "scale": 1.0, "tint": Color.WHITE},
	"jammer": {"hp": 55.0, "half": Vector2(16, 16), "contact": 0.0, "flying": true, "scale": 1.2, "tint": Color.WHITE},
	"boss": {"hp": 900.0, "half": Vector2(30, 70), "contact": 18.0, "flying": false, "scale": 2.2, "tint": Color(1.0, 0.55, 0.45)},
}

const LABELS := {
	"roller": "Roller", "gunner": "Gunner", "charger": "Charger", "scrapper": "Scrapper",
	"drone": "Drone", "jammer": "Jammer", "boss": "The Foreman",
}

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
		c.height = half.y * 2.0
		cs.shape = c
	add_child(cs)
	_sprite = Sprite2D.new()
	_sprite.texture = FLYER_TEX if flying else GROUND_TEX
	_sprite.scale = Vector2.ONE * s.scale
	_sprite.modulate = s.tint
	if kind == "jammer":
		_sprite.modulate = Parts.ui_color(field_color)
	add_child(_sprite)


func hit_rect() -> Rect2:
	return Rect2(global_position - half, half * 2.0)


func label() -> String:
	return LABELS[kind]


func step(dt: float) -> void:
	flash -= dt
	ram_cd -= dt
	timer -= dt
	var p: Vector2 = game.player.global_position
	var to_p := p - global_position
	var dist := to_p.length()
	var sees: bool = dist < 460.0 and game.los(global_position, p)
	match kind:
		"roller":
			_ground_move(dt, signf(to_p.x) if sees else 0.0, 100.0)
		"gunner":
			_gunner(dt, sees, to_p, dist)
		"charger":
			_charger(dt, sees, to_p)
		"scrapper":
			_scrapper(dt, sees, to_p)
		"drone":
			_drone(dt, sees, to_p, dist)
		"jammer":
			_fly_toward(dt, p + Vector2(0, -40), 60.0)
		"boss":
			_boss(dt, to_p)
	if not flying and not is_on_floor():
		velocity.y += GRAVITY * dt
	move_and_slide()
	_sprite.modulate.a = 1.0
	_sprite.self_modulate = Color(3, 3, 3) if flash > 0.0 else Color.WHITE
	queue_redraw()


func take_damage(amount: float, source: String, knock := Vector2.ZERO) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.08
	velocity += knock * (0.25 if kind == "boss" else 1.0)
	game.record_damage(source, amount)
	game.floater(global_position + Vector2(randf_range(-8, 8), -half.y - 6), str(roundi(amount)), Color(1, 0.95, 0.8), 0.6)
	if hp <= 0.0:
		dead = true
		game.on_enemy_killed(self)
	else:
		game.sfx.play("hit", -10.0, randf_range(0.9, 1.1))


# --- movement helpers ---

func _ground_move(dt: float, dir: float, max_speed: float) -> void:
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


func _shoot(dir: Vector2, speed: float, dmg: float) -> void:
	game.fire(global_position, dir.normalized() * speed, dmg, false, Color("ff5050"), label(), false, 3.0)
	game.sfx.play("enemy_shot", -14.0)


# --- behaviors ---

func _gunner(dt: float, sees: bool, to_p: Vector2, dist: float) -> void:
	var dir := 0.0
	if sees:
		if dist > 260.0:
			dir = signf(to_p.x)
		elif dist < 150.0:
			dir = -signf(to_p.x)
		facing = signf(to_p.x)
	_ground_move(dt, dir, 80.0)
	match state:
		"idle":
			if sees and timer <= 0.0:
				state = "aim"
				timer = 0.45
		"aim":
			if timer <= 0.0:
				state = "burst"
				burst_left = 3
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
		"windup":
			velocity.x = move_toward(velocity.x, 0, 800 * dt)
			_sprite.position.x = randf_range(-2, 2)
			if timer <= 0.0:
				_sprite.position.x = 0
				state = "dash"
				timer = 0.6
				velocity.x = facing * 460.0
		"dash":
			velocity.x = facing * 460.0
			if is_on_wall():
				state = "stun"
				timer = 1.0
				game.add_shake(3.0)
			elif timer <= 0.0:
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
			velocity = velocity.limit_length(100.0)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * dt)
		if timer <= 0.0 and dist < 320.0:
			_shoot(to_p, 300.0, 7.0)
			timer = 1.4
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * dt)


func _boss(dt: float, to_p: Vector2) -> void:
	if not phase2 and hp < max_hp * 0.5:
		phase2 = true
		game.announce("The Foreman is overheating", "Its field grows and it calls for backup")
		game.sfx.play("roar")
	if field != null and is_instance_valid(field):
		field.set_radius(180.0 if phase2 else 130.0)
	match state:
		"idle":
			_ground_move(dt, signf(to_p.x), 80.0)
			if timer <= 0.0:
				_boss_pick(to_p)
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
		"leap":
			if not is_on_floor():
				airborne = true
			elif airborne:
				airborne = false
				game.boss_slam(global_position + Vector2(0, half.y), 160.0, 18.0)
				state = "idle"
				timer = 1.2
	if phase2:
		summon_t -= dt
		if summon_t <= 0.0:
			summon_t = 9.0
			if game.count_kind("roller") < 4:
				game.spawn_enemy("roller", Vector2(3 * T, 3 * T), {})
				game.spawn_enemy("roller", Vector2((game.room.w - 3) * T, 3 * T), {})


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


func _draw() -> void:
	if hp < max_hp and kind != "boss":
		var w := half.x * 2.0 + 10.0
		draw_rect(Rect2(-w / 2, -half.y - 10, w, 4), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w / 2, -half.y - 10, w * hp / max_hp, 4), Color("e05050"))
	match kind:
		"gunner":
			var to_p: Vector2 = (game.player.global_position - global_position).normalized()
			var col := Color("ff5050") if state == "aim" else Color(0.75, 0.8, 0.9)
			draw_line(Vector2(0, -12), Vector2(0, -12) + to_p * 22.0, col, 4.0)
		"charger", "boss":
			if state == "windup":
				draw_string(ThemeDB.fallback_font, Vector2(-5, -half.y - 16), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffd040"))
	if carried != null:
		var c: Color = Parts.part_color(carried.id)
		draw_rect(Rect2(-9, -half.y - 26, 18, 14), c)
		draw_rect(Rect2(-9, -half.y - 26, 18, 14), Color.WHITE, false, 1.5)
