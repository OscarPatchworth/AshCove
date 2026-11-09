class_name MapView
extends Control
## PLACEHOLDER 2D map renderer. Draws islands, sea routes, towns and the ship
## from GameData, and reports clicks on towns. Holds no game logic, so it can be
## swapped for a 2.5D/3D map later as long as it emits `town_clicked` and
## exposes the ship position setters used by world_map.gd.

signal town_clicked(town_id: String)
signal empty_clicked

const MAP_SIZE := Vector2(1920, 1080)
const TOWN_RADIUS := 16.0
const CLICK_RADIUS := 48.0   # in screen pixels, generous for touch

var selected_town: String = ""
var highlight_path: PackedVector2Array = PackedVector2Array()
var ship_pos: Vector2 = Vector2.ZERO      # map space
var ship_heading: float = 0.0
var _island_polys: Array = []             # PackedVector2Array per island (map space)
var _time := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	for isl in GameData.islands:
		_island_polys.append(_make_island(isl))
	if GameState.location != "":
		ship_pos = GameData.towns_by_id[GameState.location].position


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# --- Coordinate transform ----------------------------------------------------

func _scale() -> float:
	return minf(size.x / MAP_SIZE.x, size.y / MAP_SIZE.y)


func _offset() -> Vector2:
	return (size - MAP_SIZE * _scale()) / 2.0


func to_screen(p: Vector2) -> Vector2:
	return _offset() + p * _scale()


func to_map(p: Vector2) -> Vector2:
	return (p - _offset()) / _scale()


# --- Input -------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var best := ""
		var best_d := CLICK_RADIUS
		for t in GameData.towns:
			var d := to_screen(t.position).distance_to(event.position)
			if d < best_d:
				best_d = d
				best = t.id
		if best != "":
			town_clicked.emit(best)
		else:
			empty_clicked.emit()
		accept_event()


# --- Drawing -----------------------------------------------------------------

func _make_island(isl: Dictionary) -> PackedVector2Array:
	var c := Vector2(isl.center[0], isl.center[1])
	var rad := Vector2(isl.radius[0], isl.radius[1])
	var s := float(isl.get("seed", 1))
	var pts := PackedVector2Array()
	var n := 64
	for i in n:
		var a := TAU * i / n
		var wobble := 1.0 + 0.09 * sin(3.0 * a + s) + 0.06 * sin(7.0 * a + s * 2.1) + 0.035 * sin(13.0 * a + s * 3.7)
		pts.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y) * wobble)
	return pts


func _xform(poly: PackedVector2Array, grow: float = 1.0, center: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(to_screen(center + (p - center) * grow))
	return out


func _draw() -> void:
	var sc := _scale()
	draw_rect(Rect2(Vector2.ZERO, size), UI.SEA_DEEP)
	draw_rect(Rect2(to_screen(Vector2.ZERO), MAP_SIZE * sc), UI.SEA)

	# Gentle wave marks.
	for i in 40:
		var wp := Vector2(fmod(i * 431.0, MAP_SIZE.x), fmod(i * 257.0 + 60, MAP_SIZE.y))
		var off := sin(_time * 0.8 + i) * 6.0
		var p := to_screen(wp + Vector2(off, 0))
		draw_arc(p, 10 * sc, PI * 1.15, PI * 1.85, 6, Color(1, 1, 1, 0.08), 2.0)
		draw_arc(p + Vector2(18, 0) * sc, 10 * sc, PI * 1.15, PI * 1.85, 6, Color(1, 1, 1, 0.08), 2.0)

	# Islands: shallows ring, land, outline.
	for i in _island_polys.size():
		var poly: PackedVector2Array = _island_polys[i]
		var isl: Dictionary = GameData.islands[i]
		var c := Vector2(isl.center[0], isl.center[1])
		draw_colored_polygon(_xform(poly, 1.07, c), Color(UI.SEA.lightened(0.15)))
		var land := _xform(poly)
		draw_colored_polygon(land, UI.LAND)
		var outline := land.duplicate()
		outline.append(land[0])
		draw_polyline(outline, UI.LAND_EDGE, 3.0, true)
		_draw_text(to_screen(c + Vector2(0, -20)), str(isl.name).to_upper(), int(26 * sc), Color(0, 0, 0, 0.28))

	# Routes.
	for r in GameData.routes:
		var col := Color(1, 1, 1, 0.18).lerp(Color(UI.BAD, 0.35), float(r.danger))
		_draw_dashed(_xform(r.points), col, 3.0)
	if highlight_path.size() > 1:
		draw_polyline(_xform(highlight_path), Color(UI.ACCENT, 0.9), 5.0, true)

	# Towns.
	var font_size := int(24 * maxf(sc, 0.8))
	for t in GameData.towns:
		var p := to_screen(t.position)
		var r := TOWN_RADIUS * maxf(sc, 0.8)
		var visited: bool = t.id in GameState.stats.get("towns_visited", [])
		if t.id == selected_town:
			draw_circle(p, r + 10 + sin(_time * 4.0) * 2.0, Color(UI.ACCENT, 0.35))
		draw_circle(p, r + 3, Color(0, 0, 0, 0.5))
		draw_circle(p, r, Color("f1e3c6") if visited else Color("b9ad96"))
		if t.id == GameState.location:
			draw_circle(p, r * 0.5, UI.ACCENT)
		var badge := ""
		if t.get("shipyard", false):
			badge += "S"
		if t.get("tavern", false):
			badge += "T"
		_draw_text(p + Vector2(0, -r - 12), t.name, font_size, UI.TEXT, true)
		if badge != "":
			_draw_text(p + Vector2(0, r + 24), badge, int(font_size * 0.7), Color(UI.TEXT, 0.6))

	_draw_ship(to_screen(ship_pos), ship_heading, sc)


func _draw_dashed(pts: PackedVector2Array, col: Color, width: float) -> void:
	for i in range(1, pts.size()):
		draw_dashed_line(pts[i - 1], pts[i], col, width, 14.0, true)


func _draw_ship(p: Vector2, heading: float, sc: float) -> void:
	var s := 22.0 * maxf(sc, 0.8)
	var bob := sin(_time * 3.0) * 2.0
	var xf := Transform2D(heading, p + Vector2(0, bob))
	var hull := PackedVector2Array([Vector2(s, 0), Vector2(-s * 0.8, -s * 0.5), Vector2(-s * 0.5, 0), Vector2(-s * 0.8, s * 0.5)])
	var shadow := PackedVector2Array()
	var pts := PackedVector2Array()
	for v in hull:
		pts.append(xf * v)
		shadow.append(xf * v + Vector2(3, 4))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	draw_colored_polygon(pts, Color("6b4428"))
	draw_circle(p + Vector2(0, bob - s * 0.15), s * 0.38, Color("f4ecd8"))
	draw_circle(p + Vector2(0, bob - s * 0.15), s * 0.38, UI.ACCENT, false, 2.0)


func _draw_text(p: Vector2, text: String, fs: int, col: Color, outline: bool = false) -> void:
	var font := get_theme_default_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := p + Vector2(-w / 2.0, fs * 0.35)
	if outline:
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.7))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
