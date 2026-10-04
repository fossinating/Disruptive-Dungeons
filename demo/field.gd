extends Node2D
## A disruption field. Rect fields sit at their top-left corner; circle fields sit at their center.
## Movement and timing are options, so one script covers every field type in the proposal.

const Parts := preload("res://demo/parts.gd")
const SHADER := preload("res://demo/field.gdshader")

var shape := "rect"
var size := Vector2.ZERO
var radius := 0.0
var color := "red"
var sweep := {}
var sweep_dir := 1.0
var pulse := []
var pulse_t := 0.0
var period := 0.0
var cycle_t := 0.0
var follow_speed := 0.0
var carrier = null
var on := true
var warn := false
var next_warn := false
var dead := false

var _rect: ColorRect
var _mat: ShaderMaterial


func setup(d: Dictionary) -> void:
	shape = d.get("shape", "rect")
	color = d.color
	position = d.pos
	size = d.get("size", Vector2.ZERO)
	radius = d.get("radius", 0.0)
	sweep = d.get("sweep", {})
	pulse = d.get("pulse", [])
	period = d.get("period", 0.0)
	follow_speed = d.get("follow", 0.0)
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)
	_layout()
	_refresh()


func set_radius(r: float) -> void:
	if r != radius:
		radius = r
		_layout()


func next_color() -> String:
	return Parts.COLORS[(Parts.COLORS.find(color) + 1) % Parts.COLORS.size()]


func step(dt: float, target: Vector2) -> void:
	if not sweep.is_empty():
		position.x += sweep_dir * sweep.speed * dt
		if position.x > sweep.max:
			position.x = sweep.max
			sweep_dir = -1.0
		elif position.x < sweep.min:
			position.x = sweep.min
			sweep_dir = 1.0
	if follow_speed > 0.0:
		position = position.move_toward(target, follow_speed * dt)
	if carrier != null:
		if not is_instance_valid(carrier) or carrier.dead:
			dead = true
		else:
			position = carrier.global_position
	if pulse.size() == 2:
		pulse_t += dt
		var phase := fmod(pulse_t, pulse[0] + pulse[1])
		on = phase < pulse[0]
		warn = not on and phase > pulse[0] + pulse[1] - 0.9
	if period > 0.0:
		cycle_t += dt
		if cycle_t >= period:
			cycle_t = 0.0
			color = next_color()
		next_warn = cycle_t > period - 1.2
	_refresh()


func contains(p: Vector2) -> bool:
	if shape == "rect":
		return Rect2(global_position, size).has_point(p)
	return global_position.distance_to(p) < radius


func distance_to_point(p: Vector2) -> float:
	if shape == "rect":
		var r := Rect2(global_position, size)
		var c := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		return c.distance_to(p)
	return maxf(0.0, global_position.distance_to(p) - radius)


func center() -> Vector2:
	return global_position + size / 2.0 if shape == "rect" else global_position


func _layout() -> void:
	if shape == "rect":
		_rect.position = Vector2.ZERO
		_rect.size = size
	else:
		_rect.position = Vector2(-radius, -radius)
		_rect.size = Vector2(radius * 2.0, radius * 2.0)
	_mat.set_shader_parameter("size", _rect.size)
	_mat.set_shader_parameter("circle", 1.0 if shape == "circle" else 0.0)


func _refresh() -> void:
	_mat.set_shader_parameter("col", Parts.FIELD_COLOR[color].lightened(0.15))
	_mat.set_shader_parameter("col2", Parts.FIELD_COLOR[next_color()].lightened(0.15))
	_mat.set_shader_parameter("active", 1.0 if on else 0.0)
	_mat.set_shader_parameter("warn", 1.0 if warn else 0.0)
	_mat.set_shader_parameter("next_warn", 1.0 if next_warn else 0.0)
