extends TileMap

@export var room_options: Array[PackedScene]
@export var entrance_room: PackedScene
@export var MAX_CELLS: int
var rng := RandomNumberGenerator.new()
var cells := 0
var passages : Array[Passage] = []
var valid_rooms : Array[PackedScene]

var step_build = false

# map layers:
# layer 0 - bounding box layer
# layer 1 - visible layer

func _ready():
	valid_rooms = room_options
	current_valid_build_options = valid_rooms.duplicate()
	build_map()
	
	for spawner in get_tree().get_nodes_in_group("spawner"):
		spawner.spawn()


func _process(_delta):
	if step_build and Input.is_action_just_pressed("step_build") and len(passages) > 0:
		build_next_room()
		force_update()
		get_node("../position marker").global_position = passages[0].global_position
		get_node("../position marker").visible = true
	if OS.is_debug_build() and Input.is_action_just_pressed("ui_accept"):
		var cell = local_to_map(get_local_mouse_position())
		var tile_data = get_cell_tile_data(0, cell)
		if tile_data:
			print("Terrain: " + str(tile_data.terrain))


func build_map():
	var room: Room = entrance_room.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	add_room(Vector2i(0,0), room)
	if step_build and OS.is_debug_build():
		return
	while len(passages) > 0:# and cells < MAX_CELLS*2:
		build_next_room()
	force_update()

var current_valid_build_options: Array[PackedScene]

func build_next_room():
	if step_build:
		print("Currently at " + str(cells) + " / " + str(MAX_CELLS) + " with " + str(len(current_valid_build_options)) + " possible options")
	var i = rng.randi_range(0, len(current_valid_build_options)-1)
	var room_scene = current_valid_build_options[i]
	var room = room_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if (len(room.get_passages()) > 1 and (MAX_CELLS - cells) < len(room.get_passages()) * 50):
		valid_rooms.remove_at(valid_rooms.find(room_scene))
		current_valid_build_options.remove_at(i)
		if step_build:
			print(room.name + " has too many passages, removing it from the options")
		return
	if (len(room.get_passages()) == 1 and len(passages) == 1 and cells < MAX_CELLS*.80) and len(current_valid_build_options) > 4:
		if step_build:
			print(room.name + " has too few passages, ignoring for now")
		return
	if try_add_room(passages[0], room):
		passages[0].get_parent().call_deferred("remove_child", passages[0])
		passages.remove_at(0)
		current_valid_build_options = valid_rooms.duplicate()
	else:
		current_valid_build_options.remove_at(i)



func weight_room(room: Room):
	return max(0, 1-len(room.get_passages())*pow(float(cells)/MAX_CELLS, len(room.get_passages())))



func try_add_room(passage: Passage, room: Room):
	if step_build:
		print("Trying to add room " + room.name)
	for room_passage in room.get_passages():
		if can_room_fit_from_passage(passage, room, room_passage):
			var i := len(passages)
			passages.append(room_passage)
			add_room(Vector2i(passage.position_i - room_passage.position_i), room)
			passages.remove_at(i)
			return true
	if step_build:
		print("Could not add room")
	return false

func add_room(root_position: Vector2i, room: Room):
	var walls: Array[Vector2i] = []
	var backgrounds: Array[Vector2i] = []
	for x in range(room.width):
		for y in range(room.height):
			var room_position = Vector2i(x, y)
			var world_position = root_position + room_position
			var cell_data: TileData = room.get_node("TileMap").get_cell_tile_data(0, room_position)
			if cell_data:
				if cell_data.terrain == 0:
					walls.append(world_position)
				else:
					backgrounds.append(world_position)
					set_cell(0, world_position, 
						room.get_node("TileMap").get_cell_source_id(0, room_position), 
						room.get_node("TileMap").get_cell_atlas_coords(0, room_position))
			set_cell(1, world_position, 
				room.get_node("TileMap").get_cell_source_id(1, room_position), 
				room.get_node("TileMap").get_cell_atlas_coords(1, room_position))
	#set_cells_terrain_connect(0, backgrounds, 0, 1)
	cells += len(walls) + len(backgrounds)
	var objects_node = room.get_node("Objects")
	for _passage in room.get_passages():
		_passage.position_i += root_position
		if _passage not in passages:
			passages.append(_passage)
		else:
			_passage.get_parent().call_deferred("remove_child", _passage)
			for i in range(-1, 2):
				set_cell(0, 
					_passage.position_i + Vector2i(i if _passage.exit_dir % 2 == 0 else 0, i if _passage.exit_dir % 2 == 1 else 0),
					1, Vector2i(0,0))
	set_cells_terrain_connect(0, walls, 0, 0)
	room.remove_child(objects_node)
	get_node("../Objects").add_child(objects_node)
	objects_node.global_position = root_position*32# - Vector2i(16,32)
	if step_build:
		print("Successfully added")


func can_room_fit_from_passage(_passage: Passage, room: Room, room_passage: Passage):
	if (_passage.exit_dir + 2) % 4 != room_passage.exit_dir:
		return false
	for x in range(room.width):
		for y in range(room.height):
			var room_position = Vector2i(x, y)
			var world_position = _passage.position_i + room_position - room_passage.position_i
			var world_tile_data = get_cell_tile_data(0, world_position)
			var room_tile_data = room.get_node("TileMap").get_cell_tile_data(0, room_position)
			if world_tile_data and room_tile_data and not (room_tile_data.terrain == 0 and world_tile_data.terrain == 0):
				return false
	return true


var instanced_scenes = []

func get_random_room():
	var room_scene = room_options[rng.randi_range(0, len(room_options)-1)]
	var room = room_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	return room
