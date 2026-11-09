extends Node
## Scene paths + small bits of state handed between menu screens.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const SAVE_SELECT := "res://scenes/save_select.tscn"
const CHARACTER_SELECT := "res://scenes/character_select.tscn"
const WORLD_MAP := "res://scenes/world_map.tscn"

var save_select_mode: String = "new"   # "new" or "load"
var pending_slot: int = -1             # slot chosen for a new game


func goto(path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(path)
