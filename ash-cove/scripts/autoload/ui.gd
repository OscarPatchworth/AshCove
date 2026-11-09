extends Node
## Shared palette, theme, and small widget builders for the placeholder UI.
## Screens build their layouts in code with these helpers so the look stays consistent.

const BG := Color("1b1d24")
const PANEL := Color("262a33")
const PANEL_LIGHT := Color("343a47")
const PANEL_DARK := Color("1f2229")
const ACCENT := Color("e8743b")
const ACCENT_DARK := Color("b8552a")
const TEXT := Color("ece6da")
const MUTED := Color("9aa0aa")
const GOOD := Color("7cc47a")
const BAD := Color("e05a5a")
const WARN := Color("e8c547")
const SEA := Color("1f4e66")
const SEA_DEEP := Color("163a4c")
const LAND := Color("8c7a5b")
const LAND_EDGE := Color("5b4f3d")
const GOLD := Color("f2c14e")

const FONT_SIZE := 28

var theme: Theme


func _ready() -> void:
	theme = _build_theme()
	get_tree().root.theme = theme
	RenderingServer.set_default_clear_color(BG)


func box(color: Color, radius: int = 10, border: Color = Color.TRANSPARENT, border_w: int = 0, pad: int = 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	return sb


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_SIZE

	t.set_color("font_color", "Label", TEXT)

	t.set_stylebox("normal", "Button", box(PANEL_LIGHT, 10, Color("4a5163"), 2, 22))
	t.set_stylebox("hover", "Button", box(Color("404757"), 10, ACCENT, 2, 22))
	t.set_stylebox("pressed", "Button", box(ACCENT_DARK, 10, ACCENT, 2, 22))
	t.set_stylebox("disabled", "Button", box(PANEL_DARK, 10, Color("2c313b"), 2, 22))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("5d636e"))

	t.set_stylebox("panel", "PanelContainer", box(PANEL, 14, Color("3a4150"), 2, 24))
	t.set_stylebox("panel", "Panel", box(PANEL, 14))

	t.set_stylebox("normal", "LineEdit", box(PANEL_DARK, 8, Color("4a5163"), 2, 14))
	t.set_stylebox("focus", "LineEdit", box(PANEL_DARK, 8, ACCENT, 2, 14))
	t.set_color("font_color", "LineEdit", TEXT)

	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("h_separation", "GridContainer", 14)
	t.set_constant("v_separation", "GridContainer", 8)
	return t


# --- Widget builders ---------------------------------------------------------

func label(text: String, size: int = 0, color: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if color != TEXT:
		l.add_theme_color_override("font_color", color)
	return l


func wrap_label(text: String, size: int = 0, color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 100
	return l


func button(text: String, on_press: Callable = Callable(), min_w: int = 0, size: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	b.custom_minimum_size.y = 64
	if size > 0:
		b.add_theme_font_size_override("font_size", size)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


func accent_button(text: String, on_press: Callable = Callable(), min_w: int = 0, size: int = 0) -> Button:
	var b := button(text, on_press, min_w, size)
	b.add_theme_stylebox_override("normal", box(ACCENT_DARK, 10, ACCENT, 2, 22))
	b.add_theme_stylebox_override("hover", box(ACCENT, 10, Color("ffb07a"), 2, 22))
	return b


func panel(color: Color = PANEL, border: Color = Color("3a4150"), pad: int = 24) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, 14, border, 2, pad))
	return p


func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func spacer(expand_h: bool = true) -> Control:
	var c := Control.new()
	if expand_h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func swatch(color: Color, size: Vector2 = Vector2(28, 28)) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = size
	return c


## Full-screen dimmer that blocks input to whatever is underneath.
func dimmer(alpha: float = 0.6) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0, 0, 0, alpha)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


func clear_children(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func gold_text(amount: int) -> String:
	return "%d g" % amount
