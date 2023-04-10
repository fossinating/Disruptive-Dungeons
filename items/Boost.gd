extends Skill

func activate() -> bool:
	var player: Player = get_parent()
	player.velocity = (get_global_mouse_position() - player.global_position).normalized() * 800
	return true
