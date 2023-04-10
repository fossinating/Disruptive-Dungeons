extends Panel

var timer := 0.0

func _process(delta):
	if get_node("../Win Screen").visible:
		return
	if Input.is_action_just_pressed("pause"):
		get_tree().paused = not get_tree().paused
	$"CenterContainer/VBoxContainer/Time Taken".text = "Current Time: " + get_time_string()
	self.visible = get_tree().paused
	
	if not get_tree().paused:
		timer += delta

func get_time_string():
	var minutes = floor(timer / 60)
	var seconds = timer - minutes*60
	return str(minutes) + "m " + str(round(seconds*100)/100.0) + "s"
