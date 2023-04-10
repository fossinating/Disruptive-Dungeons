extends CharacterBody2D

var target = null

const ACCEL = MAX_SPEED*10
const MAX_SPEED = 100.0
const FRICTION = MAX_SPEED * 3
const IDEAL_DISTANCE = 60

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta) -> void:
	if target and can_see(target):
		var direction = Vector2(0,0)
		if abs(target.global_position.x - global_position.x) < IDEAL_DISTANCE:
			direction.x = 0
		elif target.global_position.x < global_position.x:
			direction.x = -1
		elif target.global_position.x > global_position.x:
			direction.x = 1
		
		if target.global_position.y - IDEAL_DISTANCE < global_position.y:
			direction.y = -1
		elif target.global_position.y - IDEAL_DISTANCE*1.5 > global_position.y:
			direction.y = 1
		
	
		if direction != Vector2(0,0):
			velocity += direction * ACCEL * delta
			velocity = velocity.normalized() * clamp(velocity.length(), -MAX_SPEED, MAX_SPEED)
		else:
			velocity = velocity.normalized() * move_toward(velocity.length(), 0, FRICTION*delta)
	move_and_slide()


func _on_area_2d_body_entered(body):
	if body is Player:
		target = body


func _on_area_2d_body_exited(body):
	if body == target:
		target = null

var target_in_range = false

func _on_attack_range_body_entered(body):
	if body == target:
		target_in_range = true
		if $Timer.is_stopped():
			attack()


func _on_attack_range_body_exited(body):
	if body == target:
		target_in_range = false


@onready var bullet_scene = preload("res://enemies/enemy bullet.tscn")

func attack():
	var bullet: RigidBody2D = bullet_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	get_tree().root.call_deferred("add_child", bullet)
	bullet.add_collision_exception_with(self)
	bullet.global_position = global_position
	bullet.get_node("CollisionPolygon2D").look_at(target.global_position)
	bullet.get_node("Sprite2D").look_at(target.global_position)
	bullet.set_linear_velocity((target.global_position - global_position).normalized()*500)
	$Timer.start()

var health := 20

func damage(val):
	health -= val
	if health < 0:
		get_parent().call_deferred("remove_child", self)


func _on_timer_timeout():
	if target_in_range and can_see(target):
		attack()

func can_see(body):
	$RayCast2D.target_position = body.global_position - global_position
	return $RayCast2D.get_collider() == body
