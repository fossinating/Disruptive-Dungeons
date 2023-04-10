extends Node2D

@export var items: Array[PackedScene]
var rng = RandomNumberGenerator.new()
@onready var item_pickup_scene = preload("res://items/item_pickup.tscn")

func get_item_pickup():
	var item_scene = items[rng.randi_range(0, len(items))]
	var item_pickup = item_pickup_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	item_pickup.item_scene = item_scene
	return item_pickup
