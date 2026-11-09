extends Node
## Captures a PNG of each screen (needs a window, not --headless):
##   godot --path . --resolution 1920x1080 res://tests/screenshots.tscn -- --out=C:/some/dir
## Useful for checking layouts without clicking through the game.

var _out := "user://screenshots"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	GameState.new_game(97, "privateer", "Kara Blackwell", "Ashen Tide")
	GameState.buy("fish", 6)
	GameState.buy("obsidian", 2)

	await _shot(SceneRouter.MAIN_MENU, "01_main_menu")
	SceneRouter.save_select_mode = "new"
	await _shot(SceneRouter.SAVE_SELECT, "02_save_select")
	await _shot(SceneRouter.CHARACTER_SELECT, "03_character_select")

	var wm: Node = await _shot(SceneRouter.WORLD_MAP, "04_port_market", true)
	wm._port_layer.get_child(0)._show_tab("shipyard")
	await _capture("05_port_shipyard")
	wm._port_layer.get_child(0)._show_tab("tavern")
	await _capture("06_port_tavern")
	wm._close_port()
	GameState.known_prices["goldreach"] = GameState.known_prices[GameState.location]
	wm._on_town_clicked("goldreach")
	await _capture("07_map_selected")
	wm._show_ship_popup()
	await _capture("08_ship_popup")
	wm._close_popup()
	var dlg := EncounterDialog.new()
	dlg.setup(CombatResolver.make_encounter(GameState.rng, 3))
	wm._popup_layer.add_child(dlg)
	await _capture("09_encounter")
	SaveManager.delete_slot(97)
	get_tree().quit()


func _shot(path: String, name: String, keep: bool = false) -> Node:
	for c in get_children():
		c.queue_free()
	var scene: Node = load(path).instantiate()
	add_child(scene)
	await _capture(name)
	return scene


func _capture(name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("saved ", name)
