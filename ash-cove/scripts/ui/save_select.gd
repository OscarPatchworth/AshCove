extends Control
## Pick one of the 3 save slots, for a new game ("new") or loading ("load").

var _slots_row: HBoxContainer
var _confirm_layer: Control


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 80)
	add_child(margin)

	var col := UI.vbox(40)
	margin.add_child(col)

	var is_new := SceneRouter.save_select_mode == "new"
	col.add_child(UI.label("New Game - choose a save slot" if is_new else "Load Game", 56, UI.ACCENT))

	_slots_row = UI.hbox(40)
	_slots_row.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(_slots_row)

	var bottom := UI.hbox()
	bottom.add_child(UI.button("Back", func(): SceneRouter.goto(SceneRouter.MAIN_MENU), 220))
	col.add_child(bottom)

	_build_slots()


func _build_slots() -> void:
	UI.clear_children(_slots_row)
	var is_new := SceneRouter.save_select_mode == "new"
	for i in SaveManager.SLOT_COUNT:
		var s := SaveManager.slot_summary(i)
		var card := UI.panel(UI.PANEL, Color("3a4150"), 32)
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		card.size_flags_vertical = SIZE_EXPAND_FILL
		_slots_row.add_child(card)

		var v := UI.vbox(16)
		card.add_child(v)
		v.add_child(UI.label("Slot %d" % (i + 1), 40, UI.MUTED))

		if s.is_empty():
			v.add_child(UI.label("- Empty -", 34, UI.MUTED))
			v.add_child(UI.spacer(false))
			var b := UI.accent_button("Start Here", _choose.bind(i, false)) if is_new else UI.button("Empty")
			b.disabled = not is_new
			v.add_child(b)
			continue

		var cap: Dictionary = GameData.captains_by_id.get(s.captain_id, {})
		var who := UI.hbox()
		who.add_child(UI.swatch(Color(cap.get("color", "#888888")), Vector2(40, 40)))
		who.add_child(UI.label(str(s.captain_name), 36))
		v.add_child(who)
		v.add_child(UI.label("Ship: %s" % s.ship_name, 26, UI.MUTED))
		v.add_child(UI.label("Day %d" % s.day, 30))
		v.add_child(UI.label("%s gold" % s.gold, 30, UI.GOLD))
		v.add_child(UI.label("Docked at %s" % s.location, 26))
		v.add_child(UI.label(str(s.saved_at).replace("T", "  "), 22, UI.MUTED))
		v.add_child(UI.spacer(false))

		if is_new:
			v.add_child(UI.button("Overwrite", _choose.bind(i, true)))
		else:
			v.add_child(UI.accent_button("Load", _choose.bind(i, false)))
		var del := UI.button("Delete", _confirm.bind("Delete the save in slot %d?" % (i + 1), _delete.bind(i)))
		del.add_theme_color_override("font_color", UI.BAD)
		v.add_child(del)


func _choose(i: int, needs_confirm: bool) -> void:
	if needs_confirm:
		_confirm("Overwrite the save in slot %d? It will be lost." % (i + 1), _choose.bind(i, false))
		return
	if SceneRouter.save_select_mode == "new":
		SceneRouter.pending_slot = i
		SceneRouter.goto(SceneRouter.CHARACTER_SELECT)
	elif SaveManager.load_game(i):
		SceneRouter.goto(SceneRouter.WORLD_MAP)


func _delete(i: int) -> void:
	SaveManager.delete_slot(i)
	_build_slots()


func _confirm(text: String, on_yes: Callable) -> void:
	_confirm_layer = Control.new()
	_confirm_layer.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_confirm_layer)
	_confirm_layer.add_child(UI.dimmer())
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	_confirm_layer.add_child(center)
	var p := UI.panel(UI.PANEL, UI.ACCENT, 40)
	center.add_child(p)
	var v := UI.vbox(30)
	p.add_child(v)
	v.add_child(UI.label(text, 32))
	var row := UI.hbox(20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UI.button("Cancel", _close_confirm, 220))
	row.add_child(UI.accent_button("Yes", func(): _close_confirm(); on_yes.call(), 220))
	v.add_child(row)


func _close_confirm() -> void:
	if is_instance_valid(_confirm_layer):
		_confirm_layer.queue_free()
