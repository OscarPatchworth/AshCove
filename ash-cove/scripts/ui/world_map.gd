extends Control
## Main game screen: map + HUD. Click a town to inspect it, Set Sail to travel.
## Arriving at a port autosaves and opens the port screen.

const TOP_BAR_H := 92
const DEBUG_SLOT := 99   # used when this scene is run directly from the editor (F6)

var map_view: MapView
var _top_labels: Dictionary = {}
var _top_buttons: Array = []
var _side: PanelContainer
var _side_body: VBoxContainer
var _log_box: VBoxContainer
var _port_layer: Control
var _popup_layer: Control
var _sailing := false
var _selected := ""


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	if not GameState.is_active():
		GameState.new_game(DEBUG_SLOT, GameData.captains[0].id, GameData.captains[0].name, "Debug Dinghy")

	map_view = MapView.new()
	map_view.set_anchors_preset(PRESET_FULL_RECT)
	map_view.offset_top = TOP_BAR_H
	map_view.town_clicked.connect(_on_town_clicked)
	map_view.empty_clicked.connect(_deselect)
	add_child(map_view)

	_build_side_panel()
	_build_log()

	_port_layer = Control.new()
	_port_layer.set_anchors_preset(PRESET_FULL_RECT)
	_port_layer.offset_top = TOP_BAR_H
	_port_layer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_port_layer)

	_build_top_bar()

	_popup_layer = Control.new()
	_popup_layer.set_anchors_preset(PRESET_FULL_RECT)
	_popup_layer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_popup_layer)

	GameState.changed.connect(_refresh_top_bar)
	GameState.message.connect(_log)
	_refresh_top_bar()
	_open_port()


# --- Top bar -----------------------------------------------------------------

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(UI.PANEL_DARK, 0, Color.TRANSPARENT, 0, 24))
	bar.set_anchors_preset(PRESET_TOP_WIDE)
	bar.custom_minimum_size.y = TOP_BAR_H
	add_child(bar)
	var row := UI.hbox(44)
	bar.add_child(row)

	var cap := GameState.captain()
	row.add_child(UI.swatch(Color(cap.get("color", "#888888")), Vector2(44, 44)))
	_top_labels["name"] = UI.label("", 28)
	row.add_child(_top_labels["name"])
	row.add_child(UI.spacer())
	for key in ["day", "gold", "cargo", "crew"]:
		var l := UI.label("", 30, UI.GOLD if key == "gold" else UI.TEXT)
		_top_labels[key] = l
		row.add_child(l)
	row.add_child(UI.spacer())
	_top_buttons = [UI.button("Ship", _show_ship_popup, 150), UI.button("Menu", _show_menu_popup, 150)]
	for b in _top_buttons:
		row.add_child(b)


func _refresh_top_bar() -> void:
	_top_labels["name"].text = "Capt. %s  -  %s" % [GameState.captain_name, GameState.ship_name]
	_top_labels.day.text = "Day %d" % GameState.day
	_top_labels.gold.text = "%d gold" % GameState.gold
	_top_labels.cargo.text = "Hold %d/%d" % [GameState.cargo_used(), GameState.cargo_capacity()]
	_top_labels.crew.text = "Crew %d/%d" % [GameState.crew.size(), GameState.max_crew()]
	for b in _top_buttons:
		b.disabled = _sailing


# --- Town info side panel -------------------------------------------------------

func _build_side_panel() -> void:
	_side = UI.panel(Color(UI.PANEL, 0.96), Color("3a4150"), 26)
	_side.set_anchors_preset(PRESET_RIGHT_WIDE)
	_side.offset_left = -560
	_side.offset_right = -20
	_side.offset_top = TOP_BAR_H + 20
	_side.offset_bottom = -20
	_side.visible = false
	add_child(_side)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side.add_child(scroll)
	_side_body = UI.vbox(12)
	_side_body.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_side_body)


func _on_town_clicked(id: String) -> void:
	if _sailing or _port_layer.get_child_count() > 0:
		return
	_selected = id
	map_view.selected_town = id
	var path := GameData.find_path(GameState.location, id)
	map_view.highlight_path = GameData.path_points(path) if not path.is_empty() else PackedVector2Array()
	_fill_side_panel(id, path)


func _deselect() -> void:
	if _sailing:
		return
	_selected = ""
	map_view.selected_town = ""
	map_view.highlight_path = PackedVector2Array()
	_side.visible = false


func _fill_side_panel(id: String, path: Dictionary) -> void:
	UI.clear_children(_side_body)
	_side.visible = true
	var t: Dictionary = GameData.towns_by_id[id]
	var head := UI.hbox()
	head.add_child(UI.label(t.name, 42, UI.ACCENT))
	head.add_child(UI.spacer())
	head.add_child(UI.button("X", _deselect, 64))
	_side_body.add_child(head)
	_side_body.add_child(UI.wrap_label(t.desc, 22, UI.MUTED))

	var services := []
	if t.get("shipyard", false):
		services.append("Shipyard")
	if t.get("tavern", false):
		services.append("Tavern")
	_side_body.add_child(UI.label("Market" + (", " + ", ".join(services) if not services.is_empty() else ""), 22))

	var known: Dictionary = GameState.known_prices.get(id, {})
	if not known.is_empty():
		var prod := []
		for g in t.get("produces", []):
			prod.append(GameData.good_name(g))
		var dem := []
		for g in t.get("demands", []):
			dem.append(GameData.good_name(g))
		_side_body.add_child(UI.wrap_label("Sells cheap: " + ", ".join(prod), 22, UI.GOOD))
		_side_body.add_child(UI.wrap_label("Pays well for: " + ", ".join(dem), 22, UI.BAD))
	else:
		_side_body.add_child(UI.wrap_label("You haven't visited yet - prices unknown.", 22, UI.MUTED))

	if id == GameState.location:
		_side_body.add_child(UI.label("You are docked here.", 26, UI.GOOD))
		_side_body.add_child(UI.accent_button("Enter Port", _open_port))
	elif path.is_empty():
		_side_body.add_child(UI.label("No known sea route.", 26, UI.BAD))
	else:
		var days := GameState.travel_days(path.length)
		var danger := 0.0
		for r in path.routes:
			danger = maxf(danger, float(r.danger))
		var danger_txt := "Low" if danger < 0.35 else ("Medium" if danger < 0.6 else "High")
		var stops := []
		for tid in path.towns.slice(1, -1):
			stops.append(GameData.town_name(tid))
		_side_body.add_child(UI.label("%d day%s at sea" % [days, "" if days == 1 else "s"], 30))
		_side_body.add_child(UI.label("Danger: " + danger_txt, 24, UI.GOOD if danger < 0.35 else (UI.WARN if danger < 0.6 else UI.BAD)))
		if not stops.is_empty():
			_side_body.add_child(UI.wrap_label("Via " + ", ".join(stops), 22, UI.MUTED))
		_side_body.add_child(UI.accent_button("Set Sail", _set_sail.bind(id)))

	if not known.is_empty():
		var age := GameState.day - int(known.day)
		_side_body.add_child(UI.label("Prices seen %s" % ("today" if age == 0 else "%d day%s ago" % [age, "" if age == 1 else "s"]), 24, UI.MUTED))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("v_separation", 2)
		for h in ["Good", "Buy", "Sell"]:
			grid.add_child(UI.label(h, 20, UI.MUTED))
		var here: Dictionary = GameState.known_prices.get(GameState.location, {})
		for g in GameData.goods:
			var nl := UI.label(g.name, 22)
			nl.custom_minimum_size.x = 260
			grid.add_child(nl)
			grid.add_child(UI.label(str(known.buy.get(g.id, "-")), 22, UI.GOLD))
			# Highlight sell prices that beat what you'd pay at your current port.
			var sell_v := int(known.sell.get(g.id, 0))
			var col := UI.TEXT
			if id != GameState.location and not here.is_empty() and sell_v > int(here.buy.get(g.id, 999999)):
				col = UI.GOOD
			grid.add_child(UI.label(str(sell_v), 22, col))
		_side_body.add_child(grid)
		if id != GameState.location:
			_side_body.add_child(UI.wrap_label("Green = sells there for more than it costs here.", 18, UI.MUTED))


# --- Sailing -----------------------------------------------------------------

func _set_sail(dest: String) -> void:
	var path := GameData.find_path(GameState.location, dest)
	if path.is_empty():
		return
	_sailing = true
	_side.visible = false
	_refresh_top_bar()
	var pts := GameData.path_points(path)
	map_view.highlight_path = pts
	map_view.selected_town = dest

	# Cumulative route lengths, to know which route (danger) we're on each day.
	var route_ends := []
	var acc := 0.0
	for r in path.routes:
		acc += r.length
		route_ends.append(acc)

	var days := GameState.travel_days(path.length)
	var secs := float(GameData.bal("travel", "seconds_per_day", 0.55))
	_log("Set sail for %s (%d days)." % [GameData.town_name(dest), days])
	GameState.location = ""
	for d in range(1, days + 1):
		var t0 := float(d - 1) / days
		var t1 := float(d) / days
		var tw := create_tween()
		tw.tween_method(_set_ship_t.bind(pts), t0, t1, secs)
		await tw.finished
		GameState.advance_day()
		if d < days:
			var dist_now: float = t1 * path.length
			var danger := 0.3
			for i in route_ends.size():
				if dist_now <= route_ends[i] + 0.01:
					danger = float(path.routes[i].danger)
					break
			if CombatResolver.roll_encounter(danger, GameState.rng):
				var dlg := EncounterDialog.new()
				dlg.setup(CombatResolver.make_encounter(GameState.rng, GameState.day))
				_popup_layer.add_child(dlg)
				await dlg.finished

	GameState.arrive_at(dest)
	map_view.ship_pos = GameData.towns_by_id[dest].position
	map_view.highlight_path = PackedVector2Array()
	map_view.selected_town = ""
	_sailing = false
	_refresh_top_bar()
	if SaveManager.save_game():
		_log("Docked at %s. Game autosaved." % GameData.town_name(dest))
	_open_port()


func _set_ship_t(t: float, pts: PackedVector2Array) -> void:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	var target := t * total
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		if target <= seg or i == pts.size() - 1:
			var f := clampf(target / maxf(seg, 0.001), 0.0, 1.0)
			map_view.ship_pos = pts[i - 1].lerp(pts[i], f)
			map_view.ship_heading = (pts[i] - pts[i - 1]).angle()
			return
		target -= seg


# --- Port --------------------------------------------------------------------

func _open_port() -> void:
	if GameState.location == "" or _port_layer.get_child_count() > 0:
		return
	_deselect()
	var port := PortScreen.new()
	port.setup(GameState.location)
	port.set_anchors_preset(PRESET_FULL_RECT)
	port.cast_off.connect(_close_port)
	_port_layer.add_child(port)


func _close_port() -> void:
	GameState.record_prices(GameState.location)
	UI.clear_children(_port_layer)
	_log("Cast off from %s. Pick a destination on the map." % GameData.town_name(GameState.location))


# --- Log ---------------------------------------------------------------------

func _build_log() -> void:
	_log_box = UI.vbox(6)
	_log_box.set_anchors_preset(PRESET_BOTTOM_LEFT)
	_log_box.grow_vertical = GROW_DIRECTION_BEGIN
	_log_box.offset_left = 24
	_log_box.offset_bottom = -24
	_log_box.custom_minimum_size.x = 900
	_log_box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_log_box)


func _log(text: String) -> void:
	var p := UI.panel(Color(UI.PANEL_DARK, 0.85), Color.TRANSPARENT, 12)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var l := UI.label(text, 22)
	p.add_child(l)
	p.size_flags_horizontal = SIZE_SHRINK_BEGIN
	_log_box.add_child(p)
	while _log_box.get_child_count() > 6:
		_log_box.get_child(0).free()
	var tw := p.create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(p, "modulate:a", 0.0, 1.0)
	tw.tween_callback(p.queue_free)


# --- Popups ------------------------------------------------------------------

func _popup(title: String) -> VBoxContainer:
	UI.clear_children(_popup_layer)
	var layer := Control.new()
	layer.set_anchors_preset(PRESET_FULL_RECT)
	_popup_layer.add_child(layer)
	var dim := UI.dimmer(0.55)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_close_popup())
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var p := UI.panel(UI.PANEL, UI.ACCENT, 36)
	center.add_child(p)
	var v := UI.vbox(16)
	p.add_child(v)
	var head := UI.hbox()
	head.add_child(UI.label(title, 44, UI.ACCENT))
	head.add_child(UI.spacer())
	head.add_child(UI.button("X", _close_popup, 64))
	v.add_child(head)
	return v


func _close_popup() -> void:
	UI.clear_children(_popup_layer)


func _show_menu_popup() -> void:
	var v := _popup("Menu")
	v.custom_minimum_size.x = 520
	v.add_child(UI.button("Resume", _close_popup))
	var status := UI.label("", 24, UI.GOOD, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(UI.button("Save Game", func(): status.text = "Saved to slot %d." % (GameState.slot + 1) if SaveManager.save_game() else "Save failed!"))
	v.add_child(UI.button("Save & Quit to Title", func():
		SaveManager.save_game()
		SceneRouter.goto(SceneRouter.MAIN_MENU)))
	v.add_child(status)


func _show_ship_popup() -> void:
	var v := _popup(GameState.ship_name)
	v.custom_minimum_size.x = 1200
	var cols := UI.hbox(50)
	v.add_child(cols)

	var left := UI.vbox(8)
	left.custom_minimum_size.x = 480
	cols.add_child(left)
	var cap := GameState.captain()
	left.add_child(UI.label("Capt. %s" % GameState.captain_name, 30))
	left.add_child(UI.label("%s - %s" % [cap.get("title", ""), cap.get("perk_name", "")], 22, Color(cap.get("color", "#ffffff"))))
	left.add_child(UI.wrap_label(cap.get("perk_desc", ""), 20, UI.MUTED))
	left.add_child(UI.label("Cargo space: %d" % GameState.cargo_capacity(), 24))
	left.add_child(UI.label("Speed: %d leagues/day" % roundi(GameState.ship_speed()), 24))
	left.add_child(UI.label("Fight strength: %.1f" % GameState.fight_strength(), 24))
	var up_txt := []
	for u in GameData.balance.get("upgrades", []):
		up_txt.append("%s %d" % [u.name, GameState.upgrades.get(u.id, 0)])
	left.add_child(UI.wrap_label("Upgrades: " + ", ".join(up_txt), 22, UI.MUTED))
	left.add_child(UI.label("Crew (%d): " % GameState.crew.size(), 24))
	left.add_child(UI.wrap_label(", ".join(GameState.crew) if not GameState.crew.is_empty() else "none", 20, UI.MUTED))
	var s := GameState.stats
	left.add_child(UI.label("Trade profit: %d g" % s.profit, 24, UI.GOOD if s.profit >= 0 else UI.BAD))
	left.add_child(UI.label("Ports visited: %d / %d" % [s.towns_visited.size(), GameData.towns.size()], 24))
	left.add_child(UI.label("Encounters: %d   Days at sea: %d" % [s.encounters, s.days_sailed], 24))

	var right := UI.vbox(6)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UI.label("Hold (%d / %d)" % [GameState.cargo_used(), GameState.cargo_capacity()], 30))
	if GameState.cargo.is_empty():
		right.add_child(UI.label("Empty.", 24, UI.MUTED))
	for lot in GameState.cargo:
		var row := UI.hbox(14)
		row.add_child(UI.swatch(Color(GameData.goods_by_id[lot.good].color), Vector2(24, 24)))
		var nl := UI.label("%d x %s" % [lot.qty, GameData.good_name(lot.good)], 24)
		nl.custom_minimum_size.x = 330
		row.add_child(nl)
		row.add_child(UI.label("paid %d g" % roundi(lot.cost), 22, UI.MUTED))
		if GameState.is_perishable(lot.good):
			var f := GameState.lot_freshness(lot)
			var left_d := GameState.lot_fresh_left(lot)
			if f < 1.0:
				row.add_child(UI.label("spoiling: %d%% value" % roundi(f * 100), 22, UI.BAD))
			else:
				row.add_child(UI.label("fresh for %d more day%s" % [left_d, "" if left_d == 1 else "s"], 22, UI.WARN if left_d <= 1 else UI.GOOD))
		right.add_child(row)
