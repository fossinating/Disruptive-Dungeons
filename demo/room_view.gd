extends Node2D
## Draws a room grid. One instance draws the background, another the walls and platforms,
## so fields can sit between them.

const T := 32
const BG_TEX := preload("res://background tile.png")
const PLATFORM_TEX := preload("res://platform tile.png")
const WALL := Color("2e2232")
const WALL_EDGE := Color("5f5866")

var background := false
var room: Dictionary = {}


func set_room(r: Dictionary) -> void:
	room = r
	queue_redraw()


func _draw() -> void:
	if room.is_empty():
		return
	if background:
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		draw_texture_rect(BG_TEX, Rect2(0, 0, room.w * T, room.h * T), true, Color(0.55, 0.5, 0.6))
		return
	for y in room.h:
		for x in room.w:
			var c: String = room.grid[y][x]
			var p := Vector2(x * T, y * T)
			match c:
				"#":
					draw_rect(Rect2(p, Vector2(T, T)), WALL)
					if not _solid(x, y - 1):
						draw_rect(Rect2(p, Vector2(T, 3)), WALL_EDGE)
					if not _solid(x, y + 1):
						draw_rect(Rect2(p + Vector2(0, T - 2), Vector2(T, 2)), WALL_EDGE)
					if not _solid(x - 1, y):
						draw_rect(Rect2(p, Vector2(2, T)), WALL_EDGE)
					if not _solid(x + 1, y):
						draw_rect(Rect2(p + Vector2(T - 2, 0), Vector2(2, T)), WALL_EDGE)
				"-":
					draw_texture(PLATFORM_TEX, p)
				"D":
					draw_rect(Rect2(p, Vector2(T, T)), Color("3a1f1f"))
					for i in 3:
						draw_rect(Rect2(p + Vector2(4 + i * 10, 0), Vector2(4, T)), Color("d0653a"))


func _solid(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= room.w or y >= room.h:
		return true
	return room.grid[y][x] == "#" or room.grid[y][x] == "D"
