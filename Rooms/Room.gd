extends Node2D
class_name Room

@export var width: int
@export var height: int
var passages = null
var spawns = null

func get_passages():
	if passages != null:
		return passages
	passages = []
	# if you're getting a "does not exist" error make sure youre running code before you move objects to elsewhere
	for object in get_node("Objects").get_children():
		if object.is_in_group("Passages"):
			passages.append(object)
	return passages

func get_spawns():
	if spawns != null:
		return spawns
	spawns = []
	for object in get_node("Objects").get_children():
		if object.is_in_group("Spawns"):
			spawns.append(object)
	return spawns
