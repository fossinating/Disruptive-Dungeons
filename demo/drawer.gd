extends Node2D
## Calls back into the game to draw world-space effects (bullets, particles, props).

var draw_fn: Callable


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if draw_fn.is_valid():
		draw_fn.call(self)
