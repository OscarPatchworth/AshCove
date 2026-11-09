extends Node
## Static, read-only game data loaded from res://data/*.json.
## Edit the JSON files to change the world; no code changes needed.

const DATA_DIR := "res://data/"

var goods: Array = []            # Array of good dicts, in display order
var goods_by_id: Dictionary = {}
var towns: Array = []
var towns_by_id: Dictionary = {}
var routes: Array = []           # {a, b, danger, points: PackedVector2Array, length}
var adjacency: Dictionary = {}   # town_id -> Array of route dicts
var islands: Array = []
var start_town: String = ""
var captains: Array = []
var captains_by_id: Dictionary = {}
var encounters: Array = []
var balance: Dictionary = {}
var upgrades_by_id: Dictionary = {}


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	goods = _read_json("goods.json").get("goods", [])
	for g in goods:
		goods_by_id[g.id] = g

	var world := _read_json("world.json")
	start_town = world.get("start_town", "")
	islands = world.get("islands", [])
	towns = world.get("towns", [])
	for t in towns:
		t["position"] = Vector2(t.pos[0], t.pos[1])
		towns_by_id[t.id] = t
		adjacency[t.id] = []
	for r in world.get("routes", []):
		if not towns_by_id.has(r.a) or not towns_by_id.has(r.b):
			push_error("Route references unknown town: %s - %s" % [r.a, r.b])
			continue
		var pts := PackedVector2Array()
		pts.append(towns_by_id[r.a].position)
		for v in r.get("via", []):
			pts.append(Vector2(v[0], v[1]))
		pts.append(towns_by_id[r.b].position)
		var length := 0.0
		for i in range(1, pts.size()):
			length += pts[i - 1].distance_to(pts[i])
		var route := {"a": r.a, "b": r.b, "danger": float(r.get("danger", 0.3)), "points": pts, "length": length}
		routes.append(route)
		adjacency[r.a].append(route)
		adjacency[r.b].append(route)

	captains = _read_json("captains.json").get("captains", [])
	for c in captains:
		captains_by_id[c.id] = c

	encounters = _read_json("encounters.json").get("encounters", [])
	balance = _read_json("balance.json")
	for u in balance.get("upgrades", []):
		upgrades_by_id[u.id] = u


func _read_json(file_name: String) -> Dictionary:
	var path := DATA_DIR + file_name
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Could not read data file: " + path)
		return {}
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON in " + path)
		return {}
	return parsed


# --- Helpers -----------------------------------------------------------------

func town_name(id: String) -> String:
	return towns_by_id[id].name if towns_by_id.has(id) else id


func good_name(id: String) -> String:
	return goods_by_id[id].name if goods_by_id.has(id) else id


func bal(section: String, key: String, default_value = 0):
	return balance.get(section, {}).get(key, default_value)


## Returns the route's points ordered so they start at `from_id`.
func route_points_from(route: Dictionary, from_id: String) -> PackedVector2Array:
	if route.a == from_id:
		return route.points
	var rev: PackedVector2Array = route.points.duplicate()
	rev.reverse()
	return rev


## Dijkstra over the route graph by sailing distance.
## Returns {"towns": [ids...], "routes": [route dicts...], "length": float} or {} if unreachable.
func find_path(from_id: String, to_id: String) -> Dictionary:
	if from_id == to_id or not towns_by_id.has(to_id):
		return {}
	var dist := {from_id: 0.0}
	var prev := {}
	var prev_route := {}
	var open := [from_id]
	var closed := {}
	while not open.is_empty():
		var best_i := 0
		for i in open.size():
			if dist[open[i]] < dist[open[best_i]]:
				best_i = i
		var cur: String = open.pop_at(best_i)
		if cur == to_id:
			break
		closed[cur] = true
		for r in adjacency[cur]:
			var nxt: String = r.b if r.a == cur else r.a
			if closed.has(nxt):
				continue
			var d: float = dist[cur] + r.length
			if not dist.has(nxt) or d < dist[nxt]:
				dist[nxt] = d
				prev[nxt] = cur
				prev_route[nxt] = r
				if not open.has(nxt):
					open.append(nxt)
	if not dist.has(to_id):
		return {}
	var path_towns := [to_id]
	var path_routes := []
	var node := to_id
	while node != from_id:
		path_routes.push_front(prev_route[node])
		node = prev[node]
		path_towns.push_front(node)
	return {"towns": path_towns, "routes": path_routes, "length": dist[to_id]}


## Flattened polyline for a path returned by find_path.
func path_points(path: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in path.routes.size():
		var seg := route_points_from(path.routes[i], path.towns[i])
		var start := 0 if pts.is_empty() else 1
		for j in range(start, seg.size()):
			pts.append(seg[j])
	return pts
