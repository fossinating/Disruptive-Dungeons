extends Area2D
class_name DisruptionField

@export var disruptsAccel: bool = false
@export var disruptsJump: bool = false
@export var disruptsWeapons: bool = false
@export var disruptsSkills: bool = false

func _ready():
	$Sprite2D.scale = $CollisionShape2D.shape.size / 1000
	$Sprite2D.position = $CollisionShape2D.position
	
	var colors = []
	
	if disruptsAccel:
		colors.append(Color(99.0/255, 155.0/255, 1.0, 1.0))
	if disruptsJump:
		colors.append(Color(106.0/255, 190.0/255, 48.0/255, 1.0))
	if disruptsSkills:
		colors.append(Color(125.0/255, 51.0/255, 154.0/255, 1.0))
	if disruptsWeapons:
		colors.append(Color(172.0/255, 50.0/255, 50.0/255, 1.0))
	
	var gradient = Gradient.new()
	for i in range(len(colors)):
		gradient.add_point(i*(1.0/len(colors)), colors[i])
	
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill = GradientTexture2D.FILL_LINEAR
	gradient_texture.fill_from = Vector2(0,0)
	gradient_texture.fill_to = Vector2(0.05, 0.05)
	gradient_texture.repeat = GradientTexture2D.REPEAT
	gradient_texture.width = 1000
	gradient_texture.height = 1000
	$Sprite2D.texture = gradient_texture


func _on_body_entered(body):
	if body is Player:
		body.add_disruptor(self)


func _on_body_exited(body):
	if body is Player:
		body.remove_disruptor(self)
