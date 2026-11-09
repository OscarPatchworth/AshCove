extends Control
## Choose one of the premade captains, name them and their ship, then set sail.

const SHIP_NAMES := ["The Cinder Gull", "Salt Wraith", "Ember Maiden", "The Drowned Lantern",
	"Ashen Tide", "The Lucky Kettle", "Grey Heron", "Smoke on the Water"]

var _selected: String = ""
var _cards: Dictionary = {}   # captain id -> PanelContainer
var _name_edit: LineEdit
var _ship_edit: LineEdit
var _start_btn: Button


func _ready() -> void:
	theme = UI.theme
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 70)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 50)
	add_child(margin)

	var col := UI.vbox(30)
	margin.add_child(col)
	col.add_child(UI.label("Choose your Captain", 56, UI.ACCENT))

	var row := UI.hbox(28)
	row.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(row)
	for cap in GameData.captains:
		row.add_child(_make_card(cap))

	var form := UI.hbox(20)
	form.add_child(UI.label("Captain name"))
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(420, 64)
	_name_edit.max_length = 24
	_name_edit.text_changed.connect(func(_t): _refresh())
	form.add_child(_name_edit)
	form.add_child(UI.label("   Ship name"))
	_ship_edit = LineEdit.new()
	_ship_edit.custom_minimum_size = Vector2(420, 64)
	_ship_edit.max_length = 28
	_ship_edit.text = SHIP_NAMES.pick_random()
	_ship_edit.text_changed.connect(func(_t): _refresh())
	form.add_child(_ship_edit)
	col.add_child(form)

	var bottom := UI.hbox(20)
	bottom.add_child(UI.button("Back", func(): SceneRouter.goto(SceneRouter.SAVE_SELECT), 220))
	bottom.add_child(UI.spacer())
	_start_btn = UI.accent_button("Set Sail", _start, 320, 34)
	bottom.add_child(_start_btn)
	col.add_child(bottom)

	_select(GameData.captains[0].id)


func _make_card(cap: Dictionary) -> Control:
	var card := UI.panel()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.mouse_filter = MOUSE_FILTER_STOP
	card.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_select(cap.id))
	_cards[cap.id] = card

	var v := UI.vbox(14)
	v.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(v)

	var portrait := Portrait.new()
	portrait.color = Color(cap.color)
	portrait.initial = str(cap.name).substr(0, 1)
	portrait.custom_minimum_size = Vector2(0, 220)
	v.add_child(portrait)

	v.add_child(UI.label(cap.name, 36, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(cap.title, 26, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(cap.perk_name, 30, Color(cap.color), HORIZONTAL_ALIGNMENT_CENTER))
	var desc := UI.wrap_label(cap.perk_desc, 24)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)
	v.add_child(UI.spacer(false))
	v.add_child(UI.label("Starting gold: %d" % cap.start_gold, 26, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	for c in v.get_children():
		if c is Control:
			c.mouse_filter = MOUSE_FILTER_IGNORE
	return card


func _select(id: String) -> void:
	var prev_default := ""
	if _selected != "":
		prev_default = GameData.captains_by_id[_selected].name
	_selected = id
	# Swap in the captain's default name unless the player typed their own.
	if _name_edit.text == "" or _name_edit.text == prev_default:
		_name_edit.text = GameData.captains_by_id[id].name
	for cid in _cards:
		var cap: Dictionary = GameData.captains_by_id[cid]
		var on: bool = cid == id
		_cards[cid].add_theme_stylebox_override("panel",
			UI.box(UI.PANEL_LIGHT if on else UI.PANEL, 14, Color(cap.color) if on else Color("3a4150"), 4 if on else 2, 24))
	_refresh()


func _refresh() -> void:
	_start_btn.disabled = _selected == "" or _name_edit.text.strip_edges() == "" or _ship_edit.text.strip_edges() == ""


func _start() -> void:
	GameState.new_game(SceneRouter.pending_slot, _selected, _name_edit.text.strip_edges(), _ship_edit.text.strip_edges())
	SaveManager.save_game()
	SceneRouter.goto(SceneRouter.WORLD_MAP)


## Placeholder portrait: coloured circle with the captain's initial.
class Portrait extends Control:
	var color := Color.WHITE
	var initial := "?"

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.45
		var c := size / 2.0
		draw_circle(c, r + 6, Color(0, 0, 0, 0.35))
		draw_circle(c, r, color)
		draw_circle(c + Vector2(0, r * 0.15), r * 0.55, color.darkened(0.25))
		var font := get_theme_default_font()
		var fs := int(r * 0.9)
		var ts := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, c + Vector2(-ts.x / 2.0, ts.y * 0.32), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
