extends Node
## Three save slots stored as JSON in user://saves/.
## On Windows user:// is %APPDATA%/Godot/app_userdata/AshCove/.

const SLOT_COUNT := 3
const SAVE_DIR := "user://saves/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func slot_path(i: int) -> String:
	return SAVE_DIR + "slot_%d.json" % i


func has_save(i: int) -> bool:
	return FileAccess.file_exists(slot_path(i))


func read_slot(i: int) -> Dictionary:
	if not has_save(i):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(slot_path(i)))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Short summary for the slot picker, or {} if empty/corrupt.
func slot_summary(i: int) -> Dictionary:
	var d := read_slot(i)
	if d.is_empty():
		return {}
	return {
		"captain_name": d.get("captain_name", "?"),
		"captain_id": d.get("captain_id", ""),
		"ship_name": d.get("ship_name", ""),
		"day": int(d.get("day", 1)),
		"gold": int(d.get("gold", 0)),
		"location": GameData.town_name(d.get("location", "")),
		"saved_at": d.get("saved_at", ""),
	}


func save_game() -> bool:
	if not GameState.is_active():
		return false
	var f := FileAccess.open(slot_path(GameState.slot), FileAccess.WRITE)
	if f == null:
		push_error("Could not write save: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(GameState.to_dict(), "\t"))
	f.close()
	return true


func load_game(i: int) -> bool:
	var d := read_slot(i)
	if d.is_empty():
		return false
	GameState.from_dict(i, d)
	return true


func delete_slot(i: int) -> void:
	if has_save(i):
		DirAccess.remove_absolute(slot_path(i))


## Most recently saved slot, or -1.
func latest_slot() -> int:
	var best := -1
	var best_time := ""
	for i in SLOT_COUNT:
		var s := slot_summary(i)
		if not s.is_empty() and str(s.saved_at) > best_time:
			best_time = str(s.saved_at)
			best = i
	return best
