extends Weapon

func _enter_tree():
	visible = false
	set_process(false)
	$StaticBody2D/CollisionPolygon2D.set_deferred("disabled", true)


func _process(_delta):
	look_at(get_global_mouse_position())


func on_activate():
	visible = true
	set_process(true)
	$StaticBody2D/CollisionPolygon2D.set_deferred("disabled", false)


func on_deactivate():
	visible = false
	set_process(false)
	$StaticBody2D/CollisionPolygon2D.set_deferred("disabled", true)

