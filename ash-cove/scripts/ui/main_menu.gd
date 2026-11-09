extends Control
## Start screen: Continue / New Game / Load Game / Quit.

var _time := 0.0


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var col := UI.vbox(18)
	col.custom_minimum_size.x = 520
	center.add_child(col)

	col.add_child(UI.label("ASH COVE", 120, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UI.label("a trading-at-sea prototype", 30, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var gap := Control.new()
	gap.custom_minimum_size.y = 40
	col.add_child(gap)

	var latest := SaveManager.latest_slot()
	if latest >= 0:
		var s := SaveManager.slot_summary(latest)
		var cont := UI.accent_button("Continue", _on_continue.bind(latest), 0, 34)
		col.add_child(cont)
		col.add_child(UI.label("%s  -  Day %d, %s" % [s.captain_name, s.day, s.location], 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	col.add_child(UI.button("New Game", _on_new, 0, 34))
	var load_btn := UI.button("Load Game", _on_load, 0, 34)
	load_btn.disabled = latest < 0
	col.add_child(load_btn)
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		col.add_child(UI.button("Quit", func(): get_tree().quit(), 0, 34))

	var ver := UI.label("prototype v0.1", 20, UI.MUTED)
	ver.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT, PRESET_MODE_KEEP_SIZE, 24)
	add_child(ver)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# Simple animated waves as backdrop.
	var r := get_rect()
	draw_rect(r, UI.SEA_DEEP)
	for i in 14:
		var y := r.size.y * (0.45 + i * 0.045)
		var pts := PackedVector2Array()
		var x := 0.0
		while x <= r.size.x + 40:
			pts.append(Vector2(x, y + sin(x * 0.01 + _time * (0.6 + i * 0.05) + i) * (6 + i)))
			x += 40
		draw_polyline(pts, Color(UI.SEA, 0.35 + i * 0.03), 3.0, true)


func _on_continue(slot: int) -> void:
	if SaveManager.load_game(slot):
		SceneRouter.goto(SceneRouter.WORLD_MAP)


func _on_new() -> void:
	SceneRouter.save_select_mode = "new"
	SceneRouter.goto(SceneRouter.SAVE_SELECT)


func _on_load() -> void:
	SceneRouter.save_select_mode = "load"
	SceneRouter.goto(SceneRouter.SAVE_SELECT)
