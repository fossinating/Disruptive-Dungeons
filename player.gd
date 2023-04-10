extends CharacterBody2D
class_name Player


const ACCEL = MAX_SPEED*10
const MAX_SPEED = 300.0
const JUMP_VELOCITY = -500.0
const FRICTION = MAX_SPEED * 3
const AIR_PENALTY = 0.3
const AIR_RESISTANCE = MAX_SPEED * .5

var jump_multiplier := 1.0
var left_multiplier := 1.0
var right_multiplier := 1.0

var accel_disabled := false
var jump_disabled := false
var skills_disabled := false
var weapons_disabled := false

var primary_weapon: Weapon = null
var secondary_weapon: Weapon = null
var primary_skill = null
var secondary_skill = null

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	$"Minimap Camera".set_custom_viewport($"Camera2D/CanvasLayer/Control/Top Right/VBoxContainer/Minimap/SubViewport")
	get_tree().paused = false


func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle Jump.
	if not jump_disabled and Input.is_action_pressed("jump") and is_on_floor() and not Input.is_action_pressed("move_down"):
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction = Input.get_axis("move_left", "move_right")
	if not accel_disabled and direction:
		velocity.x = clamp(velocity.x + (right_multiplier if direction > 0 else left_multiplier) \
			* direction * ACCEL * delta * (AIR_PENALTY if not is_on_floor() else 1.0), -MAX_SPEED, MAX_SPEED)
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0, FRICTION*delta)

	$Sprite2D.rotation = fmod(($Sprite2D.rotation + delta * velocity.x / 20), 360.0)
	$Camera2D.zoom = Vector2(1,1)*move_toward($Camera2D.zoom.x,
		2.5 - (clamp(velocity.length_squared()/90000, 0, .5)), .7*delta)
	
	if Input.is_action_just_pressed("interact") and len(interact_options) > 0:
		interact_options[len(interact_options)-1][0].on_interact(self)
	
	if primary_weapon != null and not weapons_disabled:
		if Input.is_action_just_pressed("use_primary_weapon"):
			primary_weapon.on_activate()
		if Input.is_action_just_released("use_primary_weapon"):
			primary_weapon.on_deactivate()
	if secondary_weapon != null and not weapons_disabled:
		if Input.is_action_just_pressed("use_secondary_weapon"):
			secondary_weapon.on_activate()
		if Input.is_action_just_released("use_secondary_weapon"):
			secondary_weapon.on_deactivate()
	if primary_skill and Input.is_action_just_pressed("use_primary_skill") and not skills_disabled:
		primary_skill.on_activate()
	if secondary_skill and Input.is_action_just_pressed("use_secondary_skill") and not skills_disabled:
		secondary_skill.on_activate()
	
	var primary_on_cooldown = primary_skill and not primary_skill.get_node("Timer").is_stopped()
	$"Camera2D/CanvasLayer/Control/Inventory/Primary Skill/Cooldown".visible = primary_on_cooldown
	$"Camera2D/CanvasLayer/Control/Inventory/Primary Skill/Cooldown".text = cooldown_str(primary_skill.get_node("Timer").time_left) if primary_on_cooldown else ""
	$"Camera2D/CanvasLayer/Control/Inventory/Primary Skill/ColorRect".visible = primary_on_cooldown
	
	var secondary_on_cooldown = secondary_skill and not secondary_skill.get_node("Timer").is_stopped()
	$"Camera2D/CanvasLayer/Control/Inventory/Secondary Skill/Cooldown".visible = secondary_on_cooldown
	$"Camera2D/CanvasLayer/Control/Inventory/Secondary Skill/Cooldown".text = cooldown_str(secondary_skill.get_node("Timer").time_left) if secondary_on_cooldown else ""
	$"Camera2D/CanvasLayer/Control/Inventory/Secondary Skill/ColorRect".visible = secondary_on_cooldown
	
	$"Camera2D/CanvasLayer/Control/Top Right/VBoxContainer/Enemy Count".text = str(len(get_tree().get_nodes_in_group("enemies"))) + " enemies left"
	if len(get_tree().get_nodes_in_group("enemies")) == 0:
		get_tree().paused = true
		$"Camera2D/CanvasLayer/Control/Win Screen".visible = true
		$"Camera2D/CanvasLayer/Control/Win Screen/CenterContainer/VBoxContainer/Time Taken".text = "Time Taken: " + $"Camera2D/CanvasLayer/Control/Pause Menu".get_time_string()
		
	
	#$Camera2D.position += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")*10
	
	#$Camera2D.zoom += Vector2(1,1)*Input.get_axis("zoom_in", "zoom_out")*0.1
	
	set_collision_mask_value(2, not(Input.is_action_pressed("move_down") and Input.is_action_pressed("jump")))
	move_and_slide()

func cooldown_str(val) -> String:
	if val > 1:
		return str(round(val))
	else:
		return str(round(val*10)/10.0)

var disruptors: Array[DisruptionField] = []

func add_disruptor(disruptor):
	disruptors.append(disruptor)
	update_disruption()

func remove_disruptor(disruptor):
	disruptors.remove_at(disruptors.find(disruptor))
	update_disruption()

func update_disruption():
	accel_disabled = false
	jump_disabled = false
	skills_disabled = false
	var old_weapons_disabled = weapons_disabled
	weapons_disabled = false
	for disruptor in disruptors:
		if disruptor.disruptsAccel:
			accel_disabled = true
		if disruptor.disruptsJump:
			jump_disabled = true
		if disruptor.disruptsSkills:
			skills_disabled = true
		if disruptor.disruptsWeapons:
			weapons_disabled = true
	get_node("Camera2D/CanvasLayer/Control/VFlowContainer/Accel Disabled").visible = accel_disabled
	get_node("Camera2D/CanvasLayer/Control/VFlowContainer/Jump Disabled").visible = jump_disabled
	get_node("Camera2D/CanvasLayer/Control/VFlowContainer/Skills Disabled").visible = skills_disabled
	get_node("Camera2D/CanvasLayer/Control/VFlowContainer/Weapons Disabled").visible = weapons_disabled
	
	if weapons_disabled != old_weapons_disabled:
		if weapons_disabled:
			if primary_weapon:
				primary_weapon.on_deactivate()
			if secondary_weapon:
				secondary_weapon.on_deactivate()
		else:
			if primary_weapon and Input.is_action_pressed("use_primary_weapon"):
				primary_weapon.on_activate()
			if secondary_weapon and Input.is_action_pressed("use_secondary_weapon"):
				secondary_weapon.on_activate()

var interact_options = []

func update_interact_message():
	if len(interact_options) > 0:
		get_node("Camera2D/CanvasLayer/Control/CenterContainer/Interact Prompt/Label2").text = " to " + interact_options[len(interact_options)-1][1]
	get_node("Camera2D/CanvasLayer/Control/CenterContainer/Interact Prompt").visible = (len(interact_options) > 0)
	get_node("Camera2D/CanvasLayer/Control/CenterContainer/Interact Prompt/ActionIcon").refresh()

func create_interact_option(referrer, action_description):
	interact_options.append([referrer, action_description])
	update_interact_message()

func remove_interact_option(referrer):
	for i in range(len(interact_options)):
		if interact_options[i][0] == referrer:
			interact_options.remove_at(i)
			update_interact_message()
			return

var item_to_be_picked_up: ItemPickup = null

func pickup_item(item_pickup: ItemPickup):
	item_to_be_picked_up = item_pickup
	$"Camera2D/CanvasLayer/Control/Pickup Selector".visible = true
	$"Camera2D/CanvasLayer/Control/Pickup Selector/Pickup Selector/New Item/Item Full Display".set_item(item_pickup.item)
	if item_pickup.item is Weapon:
		$"Camera2D/CanvasLayer/Control/Pickup Selector/Pickup Selector/Primary Slot/Item Full Display".set_item(primary_weapon, true)
		$"Camera2D/CanvasLayer/Control/Pickup Selector/Pickup Selector/Secondary Slot/Item Full Display".set_item(secondary_weapon, true)
	elif item_pickup.item is Skill:
		$"Camera2D/CanvasLayer/Control/Pickup Selector/Pickup Selector/Primary Slot/Item Full Display".set_item(primary_skill, false)
		$"Camera2D/CanvasLayer/Control/Pickup Selector/Pickup Selector/Secondary Slot/Item Full Display".set_item(secondary_skill, false)


func _on_select_primary_slot_button_pressed():
	if item_to_be_picked_up.item is Weapon:
		# handle dropping the item first
		if primary_weapon:
			drop_item(primary_weapon)
			remove_child(primary_weapon)
		primary_weapon = item_to_be_picked_up.item
		$"Camera2D/CanvasLayer/Control/Inventory/Primary Weapon/TextureRect".texture = primary_weapon.item_image
	elif item_to_be_picked_up.item is Skill:
		if primary_skill:
			drop_item(primary_skill)
			remove_child(primary_skill)
		primary_skill = item_to_be_picked_up.item
		$"Camera2D/CanvasLayer/Control/Inventory/Primary Skill/TextureRect".texture = primary_skill.item_image
	add_child(item_to_be_picked_up.item)
	item_to_be_picked_up.get_parent().remove_child(item_to_be_picked_up)
	item_to_be_picked_up = null
	$"Camera2D/CanvasLayer/Control/Pickup Selector".visible = false


func _on_select_secondary_slot_button_pressed():
	if item_to_be_picked_up.item is Weapon:
		# handle dropping the item first
		if secondary_weapon:
			drop_item(secondary_weapon)
			remove_child(secondary_weapon)
		secondary_weapon = item_to_be_picked_up.item
		$"Camera2D/CanvasLayer/Control/Inventory/Secondary Weapon/TextureRect".texture = secondary_weapon.item_image
	elif item_to_be_picked_up.item is Skill:
		if secondary_skill:
			drop_item(secondary_skill)
			remove_child(secondary_skill)
		secondary_skill = item_to_be_picked_up.item
		$"Camera2D/CanvasLayer/Control/Inventory/Secondary Skill/TextureRect".texture = secondary_skill.item_image
	add_child(item_to_be_picked_up.item)
	item_to_be_picked_up.get_parent().remove_child(item_to_be_picked_up)
	item_to_be_picked_up = null
	$"Camera2D/CanvasLayer/Control/Pickup Selector".visible = false

@onready var item_pickup_scene = preload("res://items/item_pickup.tscn")

func drop_item(item):
	var item_pickup = item_pickup_scene.instantiate()
	item_pickup.item = item
	get_parent().add_child(item_pickup)
	item_pickup.refresh()
	item_pickup.global_position = global_position

var health := 100

func damage(val):
	health -= val
	$"Camera2D/CanvasLayer/Control/Health Section/HealthBar".value = health
	if health <= 0:
		get_tree().paused = true
		$"Camera2D/CanvasLayer/Control/Death Screen".visible = true


func _on_main_menu_button_pressed():
	get_tree().change_scene_to_file("res://UI/main_menu.tscn")
	get_tree().paused = false


func _on_play_again_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://world.tscn")


func _on_resume_button_pressed():
	get_tree().paused = false
