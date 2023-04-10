extends Sprite2D
class_name ItemPickup

@export var item_scene: PackedScene
var item_name: String
var item: Item

func _ready():
	if item == null and item_scene == null:
		return
	refresh()
	

func refresh():
	assert(item != null or item_scene != null, "Either item or item scene must be set before refresh")
	if item == null:
		item = item_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	texture = item.item_image
	item_name = item.name

func on_interact(player):
	player.pickup_item(self)


func _on_area_2d_body_entered(body):
	if body is Player:
		body.create_interact_option(self, "pick up " + item_name)


func _on_area_2d_body_exited(body):
	if body is Player:
		body.remove_interact_option(self)
