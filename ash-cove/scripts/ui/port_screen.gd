class_name PortScreen
extends Control
## Docked-at-port overlay with Market, Shipyard and Tavern tabs.

signal cast_off

var town: Dictionary
var _tab: String = "market"
var _tab_buttons: Dictionary = {}
var _content: VBoxContainer


func setup(town_id: String) -> void:
	town = GameData.towns_by_id[town_id]


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_STOP
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var col := UI.vbox(18)
	margin.add_child(col)

	var header := UI.hbox(30)
	var titles := UI.vbox(2)
	titles.add_child(UI.label("Port of " + str(town.name), 48, UI.ACCENT))
	titles.add_child(UI.label(town.desc, 24, UI.MUTED))
	header.add_child(titles)
	header.add_child(UI.spacer())
	for tab in [["market", "Market", true], ["shipyard", "Shipyard", town.get("shipyard", false)], ["tavern", "Tavern", town.get("tavern", false)]]:
		var b := UI.button(tab[1] if tab[2] else tab[1] + " (none)", _show_tab.bind(tab[0]), 200)
		b.disabled = not tab[2]
		header.add_child(b)
		_tab_buttons[tab[0]] = b
	var go := UI.accent_button("Cast Off", func(): cast_off.emit(), 220, 32)
	header.add_child(go)
	col.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_content = UI.vbox(10)
	_content.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_content)

	GameState.changed.connect(_rebuild)
	_show_tab("market")


func _show_tab(tab: String) -> void:
	_tab = tab
	for t in _tab_buttons:
		var b: Button = _tab_buttons[t]
		if t == tab:
			b.add_theme_stylebox_override("normal", UI.box(UI.ACCENT_DARK, 10, UI.ACCENT, 2, 22))
		else:
			b.remove_theme_stylebox_override("normal")
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	UI.clear_children(_content)
	match _tab:
		"market": _build_market()
		"shipyard": _build_shipyard()
		"tavern": _build_tavern()


# --- Market ------------------------------------------------------------------

func _build_market() -> void:
	var info := UI.hbox(40)
	info.add_child(UI.label("Gold: %d" % GameState.gold, 30, UI.GOLD))
	info.add_child(UI.label("Hold: %d / %d" % [GameState.cargo_used(), GameState.cargo_capacity()], 30))
	info.add_child(UI.spacer())
	info.add_child(UI.label("Prices rise as you buy and fall as you sell. They recover over a few days.", 22, UI.MUTED))
	_content.add_child(info)

	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)

	for h in ["", "Good", "Market", "Buy", "", "In hold", "Avg paid", "Sell", "", ""]:
		grid.add_child(UI.label(h, 22, UI.MUTED))

	for g in GameData.goods:
		var id: String = g.id
		var held := GameState.qty_of(id)
		var bp := GameState.buy_price(id)
		var sp := GameState.next_sell_price(id)
		var ratio := Economy.mid_price(GameState.markets, GameState.location, id) / float(g.base_price)

		grid.add_child(UI.swatch(Color(g.color)))

		var name_text: String = g.name
		if GameState.is_perishable(id):
			name_text += "  (fresh %dd)" % GameState.fresh_days(id)
		var name_l := UI.label(name_text, 26)
		name_l.custom_minimum_size.x = 330
		grid.add_child(name_l)

		var tag := "fair"
		var tag_col := UI.MUTED
		if ratio < 0.75:
			tag = "cheap"
			tag_col = UI.GOOD
		elif ratio > 1.3:
			tag = "dear"
			tag_col = UI.BAD
		var tag_l := UI.label(tag, 24, tag_col)
		tag_l.custom_minimum_size.x = 90
		grid.add_child(tag_l)

		var bp_l := UI.label("%d g" % bp, 28, UI.GOLD)
		bp_l.custom_minimum_size.x = 100
		grid.add_child(bp_l)

		var buy_row := UI.hbox(6)
		var can_buy := bp <= GameState.gold and GameState.cargo_free() > 0
		for q in [1, 10]:
			var b := UI.button("+%d" % q, _buy.bind(id, q), 84, 24)
			b.disabled = not can_buy
			buy_row.add_child(b)
		var bmax := UI.button("Max", _buy_max.bind(id), 96, 24)
		bmax.disabled = not can_buy
		buy_row.add_child(bmax)
		grid.add_child(buy_row)

		grid.add_child(_held_label(id, held))

		var avg_text := "-"
		if held > 0:
			var total := 0.0
			for lot in GameState.lots_of(id):
				total += float(lot.cost) * int(lot.qty)
			avg_text = "%d g" % roundi(total / held)
		var avg_l := UI.label(avg_text, 24, UI.MUTED)
		avg_l.custom_minimum_size.x = 110
		grid.add_child(avg_l)

		var sp_col := UI.TEXT
		if held > 0:
			sp_col = UI.GOOD if sp >= roundi(_avg_cost(id)) else UI.BAD
		var sp_l := UI.label("%d g" % sp, 28, sp_col)
		sp_l.custom_minimum_size.x = 100
		grid.add_child(sp_l)

		var sell_row := UI.hbox(6)
		for q in [1, 10]:
			var b := UI.button("-%d" % q, _sell.bind(id, q), 84, 24)
			b.disabled = held <= 0
			sell_row.add_child(b)
		var ball := UI.button("All", _sell.bind(id, held), 96, 24)
		ball.disabled = held <= 0
		sell_row.add_child(ball)
		grid.add_child(sell_row)

		grid.add_child(Control.new())


func _held_label(id: String, held: int) -> Control:
	if held <= 0:
		var l0 := UI.label("-", 26, UI.MUTED)
		l0.custom_minimum_size.x = 170
		return l0
	var text := str(held)
	var col := UI.TEXT
	if GameState.is_perishable(id):
		# Show the state of the oldest lot (sold first).
		var lot: Dictionary = GameState.lots_of(id)[0]
		var left := GameState.lot_fresh_left(lot)
		var f := GameState.lot_freshness(lot)
		if f < 1.0:
			text += "  (%d%%)" % roundi(f * 100)
			col = UI.BAD
		else:
			text += "  (%dd)" % left
			col = UI.WARN if left <= 1 else UI.GOOD
	var l := UI.label(text, 26, col)
	l.custom_minimum_size.x = 170
	return l


func _avg_cost(id: String) -> float:
	var total := 0.0
	var n := 0
	for lot in GameState.lots_of(id):
		total += float(lot.cost) * int(lot.qty)
		n += int(lot.qty)
	return total / n if n > 0 else 0.0


func _buy(id: String, q: int) -> void:
	GameState.buy(id, q)


func _buy_max(id: String) -> void:
	GameState.buy(id, GameState.max_buyable(id))


func _sell(id: String, q: int) -> void:
	GameState.sell(id, q)


# --- Shipyard ----------------------------------------------------------------

func _build_shipyard() -> void:
	_content.add_child(UI.label("Shipyard - upgrade the %s" % GameState.ship_name, 34))
	var stats := UI.hbox(50)
	stats.add_child(UI.label("Gold: %d" % GameState.gold, 28, UI.GOLD))
	stats.add_child(UI.label("Cargo: %d" % GameState.cargo_capacity(), 28))
	stats.add_child(UI.label("Speed: %d leagues/day" % roundi(GameState.ship_speed()), 28))
	stats.add_child(UI.label("Fight: %.1f" % GameState.fight_strength(), 28))
	_content.add_child(stats)

	for u in GameData.balance.get("upgrades", []):
		var p := UI.panel(UI.PANEL, Color("3a4150"), 20)
		var row := UI.hbox(30)
		p.add_child(row)
		var info := UI.vbox(4)
		info.custom_minimum_size.x = 560
		info.add_child(UI.label(u.name, 32))
		info.add_child(UI.label(u.desc, 24, UI.MUTED))
		row.add_child(info)

		var lvl := int(GameState.upgrades.get(u.id, 0))
		var pips := UI.hbox(8)
		for i in u.costs.size():
			pips.add_child(UI.swatch(UI.ACCENT if i < lvl else UI.PANEL_DARK, Vector2(36, 36)))
		row.add_child(pips)
		row.add_child(UI.label("Lv %d / %d" % [lvl, u.costs.size()], 26))
		row.add_child(UI.spacer())

		var cost := GameState.upgrade_cost(u.id)
		if cost < 0:
			row.add_child(UI.label("MAXED", 28, UI.GOOD))
		else:
			row.add_child(UI.label("%d g" % cost, 30, UI.GOLD))
			var b := UI.accent_button("Upgrade", func(): GameState.buy_upgrade(u.id), 220)
			b.disabled = cost > GameState.gold
			row.add_child(b)
		_content.add_child(p)


# --- Tavern ------------------------------------------------------------------

func _build_tavern() -> void:
	var cols := UI.hbox(40)
	_content.add_child(cols)

	var left := UI.vbox(14)
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	cols.add_child(left)
	left.add_child(UI.label("Hire Crew", 34))
	left.add_child(UI.label("One-off fee of %d g each. Each crewmate adds +%d cargo, +%d%% speed and +%.1f fight." % [
		GameState.crew_fee(), int(GameData.bal("crew", "cargo_per_crew", 2)),
		roundi(float(GameData.bal("crew", "speed_per_crew", 0.03)) * 100), float(GameData.bal("crew", "fight_per_crew", 0.5))], 22, UI.MUTED))
	var full := GameState.crew.size() >= GameState.max_crew()
	var candidates := GameState.tavern_candidates(town.id)
	if candidates.is_empty():
		left.add_child(UI.label("No one else is looking for work today.", 26, UI.MUTED))
	for n in candidates:
		var p := UI.panel(UI.PANEL, Color("3a4150"), 18)
		var row := UI.hbox(20)
		p.add_child(row)
		row.add_child(UI.label(n, 28))
		row.add_child(UI.spacer())
		row.add_child(UI.label("%d g" % GameState.crew_fee(), 28, UI.GOLD))
		var b := UI.accent_button("Hire", func(): GameState.hire_crew(town.id, n), 160)
		b.disabled = full or GameState.gold < GameState.crew_fee()
		row.add_child(b)
		left.add_child(p)
	if full:
		left.add_child(UI.label("Your ship has no room for more crew.", 24, UI.WARN))

	left.add_child(UI.label("Rumours", 34))
	for r in _rumours():
		left.add_child(UI.wrap_label("- " + r, 24))

	var right := UI.vbox(10)
	right.custom_minimum_size.x = 520
	cols.add_child(right)
	right.add_child(UI.label("Your Crew (%d / %d)" % [GameState.crew.size(), GameState.max_crew()], 34))
	if GameState.crew.is_empty():
		right.add_child(UI.label("Just you and the gulls.", 26, UI.MUTED))
	for c in GameState.crew:
		right.add_child(UI.label(c, 26))


func _rumours() -> Array:
	var out := []
	for n in GameState.news.slice(-3):
		out.append("(day %d) %s" % [n.day, n.text])
	# A tip that's stable for the day: where a random good currently sells best.
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(town.id) + str(GameState.day))
	var g: Dictionary = GameData.goods[r.randi() % GameData.goods.size()]
	var best := ""
	var best_p := 0
	for t in GameData.towns:
		var p := Economy.sell_price(GameState.markets, t.id, g.id)
		if p > best_p and t.id != town.id:
			best_p = p
			best = t.id
	out.append("A sailor swears %s fetches around %d g in %s right now." % [g.name, best_p, GameData.town_name(best)])
	if out.size() == 1:
		out.push_front("All quiet on the seas lately.")
	return out
