class_name EncounterDialog
extends Control
## Modal Fight / Flee / Pay Off choice. Emits `finished` once the player
## dismisses the result. Combat itself is resolved by CombatResolver (placeholder).

signal finished

var enc: Dictionary
var _body: VBoxContainer


func setup(encounter: Dictionary) -> void:
	enc = encounter


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	add_child(UI.dimmer(0.55))
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	var p := UI.panel(UI.PANEL, UI.BAD, 40)
	p.custom_minimum_size.x = 900
	center.add_child(p)
	_body = UI.vbox(22)
	p.add_child(_body)
	GameState.stats.encounters = int(GameState.stats.get("encounters", 0)) + 1
	_show_choice(true)


func _show_choice(can_flee: bool) -> void:
	UI.clear_children(_body)
	_body.add_child(UI.label(enc.name + "!", 52, UI.BAD))
	_body.add_child(UI.wrap_label(enc.text, 28))
	var stats := UI.hbox(40)
	stats.add_child(UI.label("Their strength: %.1f" % enc.strength, 26, UI.MUTED))
	stats.add_child(UI.label("Yours: %.1f" % GameState.fight_strength(), 26, UI.MUTED))
	_body.add_child(stats)

	var row := UI.hbox(20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UI.accent_button("Fight  (%d%%)" % roundi(CombatResolver.fight_chance(enc) * 100), _act.bind("fight"), 250))
	var flee := UI.button("Flee  (%d%%)" % roundi(CombatResolver.flee_chance(enc) * 100), _act.bind("flee"), 250)
	flee.disabled = not can_flee
	row.add_child(flee)
	var pay := UI.button("%s  (%d g)" % ["Pay Off" if enc.pay_text == "Pay them off" else "Offer", enc.toll], _act.bind("pay"), 250)
	pay.disabled = GameState.gold < int(enc.toll)
	pay.tooltip_text = enc.pay_text
	row.add_child(pay)
	_body.add_child(row)
	_body.add_child(UI.label("(placeholder combat - outcomes are a dice roll)", 20, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))


func _act(action: String) -> void:
	var result := CombatResolver.resolve(action, enc, GameState.rng)
	if result.outcome == "caught":
		_show_choice(false)
		_body.add_child(UI.label(result.text, 26, UI.WARN))
		return
	GameState.apply_encounter_result(result)
	UI.clear_children(_body)
	var good: bool = result.outcome in ["won", "fled", "paid"]
	var titles := {"won": "Victory", "lost": "Defeat", "fled": "Escaped", "paid": "Passage Bought"}
	_body.add_child(UI.label(titles.get(result.outcome, ""), 52, UI.GOOD if good else UI.BAD))
	_body.add_child(UI.wrap_label(result.text, 28))
	var row := UI.hbox()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UI.accent_button("Sail On", func(): finished.emit(); queue_free(), 260))
	_body.add_child(row)
