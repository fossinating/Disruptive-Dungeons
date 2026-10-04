extends Control
## Calls back into the game to draw the HUD in screen space.

var draw_fn: Callable


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if draw_fn.is_valid():
		draw_fn.call(self)
