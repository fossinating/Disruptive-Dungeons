extends Weapon

@onready var bullet_scene: PackedScene = preload("res://items/player bullet.tscn")

var active := false

func on_activate() -> void:
	active = true
	if $Timer.is_stopped():
		shoot()

func on_deactivate() -> void:
	active = false

func _on_timer_timeout():
	if active:
		shoot()

func shoot():
	var bullet: RigidBody2D = bullet_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	get_tree().root.call_deferred("add_child", bullet)
	bullet.global_position = global_position
	bullet.get_node("CollisionPolygon2D").look_at(get_global_mouse_position())
	bullet.get_node("Sprite2D").look_at(get_global_mouse_position())
	bullet.set_linear_velocity((get_global_mouse_position() - global_position).normalized()*500)
	$Timer.start()
