extends CharacterBody2D

var target = null

const ACCEL = MAX_SPEED*10
const MAX_SPEED = 100.0
const JUMP_VELOCITY = -500.0
const FRICTION = MAX_SPEED * 3
const AIR_PENALTY = 0.3
const AIR_RESISTANCE = MAX_SPEED * .5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta) -> void:
	var direction = 0
	if target and can_see(target) and target.global_position.x < global_position.x:
		direction = -1
	elif target and can_see(target) and target.global_position.x > global_position.x:
		direction = 1
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle Jump.
	#if not jump_disabled and Input.is_action_pressed("jump") and is_on_floor() and not Input.is_action_pressed("move_down"):
	#	velocity.y = JUMP_VELOCITY
	
	if direction != 0:
		velocity.x = clamp(velocity.x + 1 \
			* direction * ACCEL * delta * (AIR_PENALTY if not is_on_floor() else 1.0), -MAX_SPEED, MAX_SPEED)
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0, FRICTION*delta)
	move_and_slide()


func _on_area_2d_body_entered(body):
	if body is Player:
		target = body


func _on_area_2d_body_exited(body):
	if body == target:
		target = null

var target_in_range = false

func _on_attack_range_body_entered(body):
	target_in_range = true
	if body == target and not $AnimationPlayer.is_playing():
		attack()


func _on_attack_range_body_exited(body):
	if body == target:
		target_in_range = false


func attack():
	hit_enemy = false
	$AnimationPlayer.play("attack" if target.global_position.x > global_position.x else "attack_left")
	

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "attack" or anim_name == "attack_left":
		if target_in_range and can_see(target):
			attack()
		else:
			$AnimationPlayer.play("RESET")

var health := 20

func damage(val):
	health -= val
	if health < 0:
		get_parent().call_deferred("remove_child", self)

var hit_enemy = false

func _on_weapon_damage_body_entered(body):
	if body == target and not hit_enemy:
		hit_enemy = true
		body.damage(15)

func can_see(body):
	$RayCast2D.target_position = body.global_position - global_position
	return $RayCast2D.get_collider() == body
