extends Node
## Headless smoke test. Run from the project folder:
##   godot --headless --path . res://tests/smoke_test.tscn
## Exits with code 0 on success, 1 on any failed check.

const TEST_SLOT := 98

var _fails := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		printerr("  FAIL ", what)


func _ready() -> void:
	print("== Data")
	check(GameData.goods.size() >= 5, "goods loaded")
	check(GameData.towns.size() >= 5, "towns loaded")
	check(GameData.captains.size() == 4, "4 captains loaded")
	for t in GameData.towns:
		check(not GameData.adjacency[t.id].is_empty(), "town %s has a route" % t.id)
		if t.id != GameData.start_town:
			check(not GameData.find_path(GameData.start_town, t.id).is_empty(), "path to %s" % t.id)

	print("== New game")
	GameState.new_game(TEST_SLOT, "merchant", "Tester", "Test Boat")
	check(GameState.gold == 600, "start gold")
	check(GameState.location == GameData.start_town, "start location")
	check(GameState.cargo_capacity() == 40, "base cargo capacity")

	print("== Trading")
	var p0 := GameState.buy_price("grain")
	var got := GameState.buy("grain", 10)
	check(got == 10, "bought 10 grain")
	check(GameState.buy_price("grain") > p0, "buying raised the price")
	check(GameState.qty_of("grain") == 10, "grain in hold")
	var gold_before := GameState.gold
	check(GameState.sell("grain", 4) == 4, "sold 4 grain")
	check(GameState.gold > gold_before, "selling earned gold")
	var maxb := GameState.max_buyable("obsidian")
	var bought := GameState.buy("obsidian", maxb)
	check(bought == maxb, "max_buyable matches buy (%d)" % maxb)
	check(GameState.cargo_used() <= GameState.cargo_capacity(), "hold not overfilled")

	print("== Perishables")
	GameState.gold = 5000
	GameState.sell("obsidian", 999)
	GameState.buy("fish", 5)
	var lot: Dictionary = GameState.lots_of("fish")[0]
	var fd := GameState.fresh_days("fish")
	for i in fd:
		GameState.advance_day()
	check(GameState.lot_freshness(lot) == 1.0, "fish fresh after %d days" % fd)
	GameState.advance_day()
	var f1 := GameState.lot_freshness(lot)
	check(f1 < 1.0 and f1 > 0.0, "fish spoiling (%.2f)" % f1)
	for i in 3:
		GameState.advance_day()
	check(GameState.qty_of("fish") == 0, "rotten fish thrown overboard")

	print("== Upgrades & crew")
	var cap0 := GameState.cargo_capacity()
	var spd0 := GameState.ship_speed()
	check(GameState.buy_upgrade("hold"), "bought hold upgrade")
	check(GameState.cargo_capacity() == cap0 + 20, "hold adds 20 cargo")
	var names := GameState.tavern_candidates(GameState.location)
	check(names.size() == 3, "3 tavern candidates")
	check(GameState.hire_crew(GameState.location, names[0]), "hired crew")
	check(GameState.ship_speed() > spd0, "crew adds speed")
	check(GameState.cargo_capacity() == cap0 + 22, "crew adds cargo")

	print("== Encounters")
	for i in 30:
		var enc := CombatResolver.make_encounter(GameState.rng, GameState.day)
		for action in ["fight", "flee", "pay"]:
			var r := CombatResolver.resolve(action, enc, GameState.rng)
			if not r.outcome in ["won", "lost", "fled", "caught", "paid"]:
				check(false, "resolve %s -> %s" % [action, r.outcome])
	var lose := CombatResolver.fight_outcome(CombatResolver.make_encounter(GameState.rng, 1), false, GameState.rng)
	GameState.buy("timber", 10)
	var t_before := GameState.qty_of("timber")
	GameState.apply_encounter_result(lose)
	check(GameState.qty_of("timber") < t_before, "losing a fight costs cargo")

	print("== Markets drift")
	var mid0 := Economy.mid_price(GameState.markets, "goldreach", "wine")
	for i in 20:
		GameState.advance_day()
	check(Economy.mid_price(GameState.markets, "goldreach", "wine") != mid0, "prices change over time")
	check(Economy.buy_price(GameState.markets, "highmoor", "iron") < Economy.buy_price(GameState.markets, "ash_cove", "iron") * 2, "sanity: iron price")
	var prod := Economy.town_mult("ash_cove", "obsidian")
	var dem := Economy.town_mult("goldreach", "obsidian")
	check(dem > prod * 2.0, "obsidian cheap at Ash Cove, dear at Goldreach")

	print("== Save / load")
	GameState.buy("cloth", 3)
	var snapshot := GameState.to_dict()
	check(SaveManager.save_game(), "saved")
	GameState.gold = 1
	GameState.cargo = []
	check(SaveManager.load_game(TEST_SLOT), "loaded")
	check(GameState.gold == snapshot.gold, "gold restored")
	check(GameState.qty_of("cloth") == 3, "cargo restored")
	check(GameState.day == snapshot.day, "day restored")
	check(GameState.crew.size() == snapshot.crew.size(), "crew restored")
	check(int(GameState.upgrades.hold) == 1, "upgrades restored")
	SaveManager.delete_slot(TEST_SLOT)

	print("== Screens")
	for path in [SceneRouter.MAIN_MENU, SceneRouter.SAVE_SELECT, SceneRouter.CHARACTER_SELECT, SceneRouter.WORLD_MAP]:
		var scene: Node = load(path).instantiate()
		add_child(scene)
		await get_tree().process_frame
		await get_tree().process_frame
		check(is_instance_valid(scene), "instantiated " + path)
		if path == SceneRouter.WORLD_MAP:
			_poke_world_map(scene)
			await get_tree().process_frame
		scene.queue_free()
		await get_tree().process_frame

	var port := PortScreen.new()
	port.setup("goldreach")
	add_child(port)
	for tab in ["market", "shipyard", "tavern"]:
		port._show_tab(tab)
		await get_tree().process_frame
	check(true, "port tabs built")
	port.queue_free()

	var dlg := EncounterDialog.new()
	dlg.setup(CombatResolver.make_encounter(GameState.rng, 5))
	add_child(dlg)
	await get_tree().process_frame
	dlg._act("pay")
	await get_tree().process_frame
	check(true, "encounter dialog")

	print("\n%s (%d failures)" % ["PASSED" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _poke_world_map(wm: Node) -> void:
	wm._close_port()
	wm._on_town_clicked("goldreach")
	wm._on_town_clicked(GameState.location)
	wm._show_ship_popup()
	wm._show_menu_popup()
	wm._close_popup()
	wm._deselect()
