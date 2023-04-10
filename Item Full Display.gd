extends Control

@export var default_weapon_texture: Texture2D
@export var default_skill_texture: Texture2D

func set_item(item: Item, is_weapon: bool = true):
	if item:
		$Name.text = item.name
		$TextureRect.texture = item.item_image
		$Description.text = item.description
	else:
		$Name.text = "Empty Slot"
		$TextureRect.texture = default_weapon_texture if is_weapon else default_skill_texture
		$Description.text = ""
