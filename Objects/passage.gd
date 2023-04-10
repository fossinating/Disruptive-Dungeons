extends Marker2D
class_name Passage

@export var position_i := Vector2i(position)
@export var exit_dir : int

func _process(_delta) -> void:
	$Sprite2D.visible = Input.is_action_pressed("show_passages")
