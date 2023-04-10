extends Item
class_name Skill

func on_activate():
	if $Timer.is_stopped():
		if activate():
			$Timer.start()

func activate() -> bool:
	return false
