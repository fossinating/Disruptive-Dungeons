extends RigidBody2D


func _on_body_entered(body):
	if body is Player and body.has_method("damage"):
		body.damage(5)
	if self != null and get_parent() != null:
		get_parent().call_deferred("remove_child", self)
