extends Marker2D
class_name Spawn

@export var spawn_options: Array[PackedScene]

func spawn():
	var rng = RandomNumberGenerator.new()
	var enemy_scene = spawn_options[rng.randi_range(0, len(spawn_options)-1)]
	var enemy = enemy_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	get_parent().add_child(enemy)
	enemy.global_position = global_position
	
