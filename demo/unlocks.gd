extends RefCounted
## Permanent progression: the schematics you've found, saved between runs.
## Tests use their own file so they never touch the real one.

const Parts := preload("res://demo/parts.gd")
const PATH := "user://unlocks.json"
const TEST_PATH := "user://unlocks_test.json"

static var _found: Array = []
static var _loaded := false


static func _path() -> String:
	var args := OS.get_cmdline_user_args()
	return TEST_PATH if args.has("--smoke") or args.has("--traverse") or args.has("--bestiary") else PATH


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_found = []
	if not FileAccess.file_exists(_path()):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(_path()))
	if data is Dictionary and data.get("schematics") is Array:
		for id in data.schematics:
			if Parts.LOCKED.has(id) and not _found.has(id):
				_found.append(id)


static func _save() -> void:
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"schematics": _found}))


static func is_unlocked(id: String) -> bool:
	_load()
	return not Parts.LOCKED.has(id) or _found.has(id)


## Every part that can drop in a run right now.
static func pool() -> Array:
	return Parts.PARTS.keys().filter(is_unlocked)


static func still_locked() -> Array:
	_load()
	return Parts.LOCKED.filter(func(id): return not _found.has(id))


static func found_count() -> int:
	_load()
	return _found.size()


static func unlock(id: String) -> void:
	_load()
	if not _found.has(id):
		_found.append(id)
		_save()


static func reset() -> void:
	_found = []
	_loaded = true
	_save()
