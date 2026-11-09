class_name Economy
extends RefCounted
## Market price model. Pure functions over the `markets` dictionary stored in GameState.
##
## mid price = base_price * town_mult * (1 + noise) * (1 + pressure)
##   town_mult : cheap where a town produces a good, dear where it demands it
##   noise     : daily mean-reverting random walk, plus rare shortage/glut events
##   pressure  : player trading impact (buying raises it, selling lowers it), decays daily


static func _m(key: String, default_value: float) -> float:
	return float(GameData.bal("market", key, default_value))


static func init_markets(rng: RandomNumberGenerator) -> Dictionary:
	var markets := {}
	for t in GameData.towns:
		var row := {}
		for g in GameData.goods:
			row[g.id] = {"noise": rng.randf_range(-0.15, 0.15), "pressure": 0.0}
		markets[t.id] = row
	return markets


## Fixed per-town multiplier for a good.
static func town_mult(town_id: String, good_id: String) -> float:
	var town: Dictionary = GameData.towns_by_id[town_id]
	var mult := 1.0
	if good_id in town.get("produces", []):
		mult = _m("produces_mult", 0.55)
	elif good_id in town.get("demands", []):
		mult = _m("demands_mult", 1.65)
	# Deterministic small variance so neutral towns still differ a little.
	var h := posmod(hash(town_id + ":" + good_id), 10000) / 10000.0
	mult *= 1.0 + (h * 2.0 - 1.0) * _m("town_variance", 0.12)
	return mult


static func mid_price(markets: Dictionary, town_id: String, good_id: String) -> float:
	var st: Dictionary = markets[town_id][good_id]
	var base: float = GameData.goods_by_id[good_id].base_price
	return base * town_mult(town_id, good_id) * (1.0 + st.noise) * (1.0 + st.pressure)


static func buy_price(markets: Dictionary, town_id: String, good_id: String, buy_mult: float = 1.0) -> int:
	return maxi(1, ceili(mid_price(markets, town_id, good_id) * _m("buy_spread", 1.06) * buy_mult))


static func sell_price(markets: Dictionary, town_id: String, good_id: String, sell_mult: float = 1.0) -> int:
	return maxi(1, floori(mid_price(markets, town_id, good_id) * _m("sell_spread", 0.94) * sell_mult))


## Positive units = player bought (price rises), negative = sold (price falls).
static func apply_trade(markets: Dictionary, town_id: String, good_id: String, units: int) -> void:
	var st: Dictionary = markets[town_id][good_id]
	st.pressure = clampf(st.pressure + units * _m("impact_per_unit", 0.012),
		_m("pressure_min", -0.6), _m("pressure_max", 1.0))


## Advance all markets by one day. Returns news strings for notable events.
static func tick(markets: Dictionary, rng: RandomNumberGenerator) -> Array:
	var news := []
	var decay := _m("pressure_decay", 0.82)
	var revert := _m("noise_revert", 0.9)
	var step := _m("noise_step", 0.06)
	var limit := _m("noise_limit", 0.35)
	for town_id in markets:
		for good_id in markets[town_id]:
			var st: Dictionary = markets[town_id][good_id]
			st.pressure *= decay
			st.noise = clampf(st.noise * revert + rng.randf_range(-step, step), -limit, limit)
		if rng.randf() < _m("event_chance", 0.02):
			var g: Dictionary = GameData.goods[rng.randi() % GameData.goods.size()]
			var st: Dictionary = markets[town_id][g.id]
			var size := _m("event_size", 0.35)
			if rng.randf() < 0.5:
				st.noise = minf(st.noise + size, limit * 1.6)
				news.append("Shortage of %s in %s - prices are soaring!" % [g.name, GameData.town_name(town_id)])
			else:
				st.noise = maxf(st.noise - size, -limit * 1.6)
				news.append("A glut of %s in %s - prices have crashed." % [g.name, GameData.town_name(town_id)])
	return news
