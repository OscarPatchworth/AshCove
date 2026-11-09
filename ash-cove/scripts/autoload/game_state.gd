extends Node
## The current playthrough: captain, ship, cargo, crew, markets, day counter.
## Everything here is serialised by to_dict()/from_dict() for saving.

signal changed                      # any state change; UI should refresh
signal message(text: String)        # player-facing log line

const SAVE_VERSION := 1

var slot: int = -1
var captain_id: String = ""
var captain_name: String = ""
var ship_name: String = ""
var gold: int = 0
var day: int = 1
var location: String = ""
var cargo: Array = []          # lots: {good, qty, day, cost}  (cost = unit cost paid)
var crew: Array = []           # crew names
var upgrades: Dictionary = {}  # upgrade id -> level
var markets: Dictionary = {}
var known_prices: Dictionary = {}  # town -> {day, buy: {good: int}, sell: {good: int}}
var news: Array = []               # recent {day, text}
var tavern_offers: Dictionary = {} # town -> {day, names: []}
var stats: Dictionary = {}
var rng := RandomNumberGenerator.new()


# --- Lifecycle ---------------------------------------------------------------

func new_game(save_slot: int, cap_id: String, cap_name: String, new_ship_name: String) -> void:
	rng.randomize()
	var cap: Dictionary = GameData.captains_by_id[cap_id]
	slot = save_slot
	captain_id = cap_id
	captain_name = cap_name
	ship_name = new_ship_name
	gold = int(cap.start_gold)
	day = 1
	location = GameData.start_town
	cargo = []
	crew = []
	upgrades = {}
	for u in GameData.upgrades_by_id:
		upgrades[u] = 0
	upgrades["cannons"] = int(perk("start_cannons", 0))
	for i in int(perk("start_crew", 0)):
		crew.append(random_crew_name())
	markets = Economy.init_markets(rng)
	known_prices = {}
	news = []
	tavern_offers = {}
	stats = {"profit": 0, "trades": 0, "encounters": 0, "days_sailed": 0, "towns_visited": [location]}
	record_prices(location)
	changed.emit()


func is_active() -> bool:
	return slot >= 0 and captain_id != ""


func captain() -> Dictionary:
	return GameData.captains_by_id.get(captain_id, {})


func perk(key: String, default_value = 0.0):
	return captain().get("perks", {}).get(key, default_value)


# --- Ship stats --------------------------------------------------------------

func cargo_capacity() -> int:
	var cap := int(GameData.bal("ship", "base_cargo", 40))
	cap += int(upgrades.get("hold", 0)) * int(GameData.upgrades_by_id.hold.cargo)
	cap += crew.size() * int(GameData.bal("crew", "cargo_per_crew", 2))
	cap += int(perk("cargo_bonus", 0))
	return cap


func cargo_used() -> int:
	var n := 0
	for lot in cargo:
		n += int(lot.qty)
	return n


func cargo_free() -> int:
	return maxi(0, cargo_capacity() - cargo_used())


func ship_speed() -> float:
	var mult := 1.0
	mult += int(upgrades.get("sails", 0)) * float(GameData.upgrades_by_id.sails.speed)
	mult += crew.size() * float(GameData.bal("crew", "speed_per_crew", 0.03))
	return float(GameData.bal("ship", "base_speed", 110)) * mult * float(perk("speed_mult", 1.0))


func fight_strength() -> float:
	var s := float(GameData.bal("ship", "base_fight", 2))
	s += int(upgrades.get("cannons", 0)) * float(GameData.upgrades_by_id.cannons.fight)
	s += crew.size() * float(GameData.bal("crew", "fight_per_crew", 0.5))
	s += float(perk("fight_bonus", 0))
	return s


func travel_days(distance: float) -> int:
	return maxi(1, ceili(distance / ship_speed()))


# --- Cargo & perishables -----------------------------------------------------

func fresh_days(good_id: String) -> int:
	return int(GameData.goods_by_id[good_id].get("fresh_days", 0)) + int(perk("fresh_bonus", 0))


func is_perishable(good_id: String) -> bool:
	return bool(GameData.goods_by_id[good_id].get("perishable", false))


## 1.0 while fresh, then falls linearly to 0 over spoil_days.
func lot_freshness(lot: Dictionary) -> float:
	if not is_perishable(lot.good):
		return 1.0
	var age := day - int(lot.day)
	var over := age - fresh_days(lot.good)
	if over <= 0:
		return 1.0
	var spoil := float(GameData.bal("perish", "spoil_days", 3))
	return clampf(1.0 - over / spoil, 0.0, 1.0)


## Days left before a lot starts losing value (negative once spoiling).
func lot_fresh_left(lot: Dictionary) -> int:
	return fresh_days(lot.good) - (day - int(lot.day))


func qty_of(good_id: String) -> int:
	var n := 0
	for lot in cargo:
		if lot.good == good_id:
			n += int(lot.qty)
	return n


func lots_of(good_id: String) -> Array:
	var out := []
	for lot in cargo:
		if lot.good == good_id:
			out.append(lot)
	out.sort_custom(func(a, b): return int(a.day) < int(b.day))
	return out


func _add_cargo(good_id: String, qty: int, unit_cost: float) -> void:
	var perishable := is_perishable(good_id)
	for lot in cargo:
		if lot.good == good_id and (not perishable or int(lot.day) == day):
			var total := int(lot.qty) + qty
			lot.cost = (float(lot.cost) * int(lot.qty) + unit_cost * qty) / total
			lot.qty = total
			lot.day = day if perishable else mini(int(lot.day), day)
			return
	cargo.append({"good": good_id, "qty": qty, "day": day, "cost": unit_cost})


# --- Trading -----------------------------------------------------------------

func buy_price(good_id: String) -> int:
	return Economy.buy_price(markets, location, good_id, float(perk("buy_mult", 1.0)))


func sell_price(good_id: String) -> int:
	return Economy.sell_price(markets, location, good_id, float(perk("sell_mult", 1.0)))


## Price the next unit of this good would sell for (accounts for freshness, oldest first).
func next_sell_price(good_id: String) -> int:
	var lots := lots_of(good_id)
	if lots.is_empty():
		return sell_price(good_id)
	return floori(sell_price(good_id) * lot_freshness(lots[0]))


## Max units affordable and storable right now.
func max_buyable(good_id: String) -> int:
	var n := 0
	var money := gold
	var sim_markets := {location: {good_id: markets[location][good_id].duplicate()}}
	var free := cargo_free()
	while n < free:
		var p := Economy.buy_price(sim_markets, location, good_id, float(perk("buy_mult", 1.0)))
		if p > money:
			break
		money -= p
		Economy.apply_trade(sim_markets, location, good_id, 1)
		n += 1
	return n


## Buys up to qty units one at a time (price rises as you buy). Returns units bought.
func buy(good_id: String, qty: int) -> int:
	var bought := 0
	var spent := 0
	while bought < qty and cargo_free() > 0:
		var p := buy_price(good_id)
		if p > gold:
			break
		gold -= p
		spent += p
		Economy.apply_trade(markets, location, good_id, 1)
		_add_cargo(good_id, 1, p)
		bought += 1
	if bought > 0:
		stats.trades += 1
		record_prices(location)
		message.emit("Bought %d %s for %d gold." % [bought, GameData.good_name(good_id), spent])
		changed.emit()
	return bought


## Sells up to qty units, oldest lots first. Returns units sold.
func sell(good_id: String, qty: int) -> int:
	var sold := 0
	var earned := 0
	var cost_basis := 0.0
	while sold < qty:
		var lots := lots_of(good_id)
		if lots.is_empty():
			break
		var lot: Dictionary = lots[0]
		var p := floori(sell_price(good_id) * lot_freshness(lot))
		gold += p
		earned += p
		cost_basis += float(lot.cost)
		Economy.apply_trade(markets, location, good_id, -1)
		lot.qty = int(lot.qty) - 1
		if lot.qty <= 0:
			cargo.erase(lot)
		sold += 1
	if sold > 0:
		var profit := earned - roundi(cost_basis)
		stats.profit += profit
		stats.trades += 1
		record_prices(location)
		message.emit("Sold %d %s for %d gold (%s%d profit)." % [sold, GameData.good_name(good_id), earned, "+" if profit >= 0 else "", profit])
		changed.emit()
	return sold


func record_prices(town_id: String) -> void:
	var buy := {}
	var sell_d := {}
	for g in GameData.goods:
		buy[g.id] = Economy.buy_price(markets, town_id, g.id, float(perk("buy_mult", 1.0)))
		sell_d[g.id] = Economy.sell_price(markets, town_id, g.id, float(perk("sell_mult", 1.0)))
	known_prices[town_id] = {"day": day, "buy": buy, "sell": sell_d}


# --- Ship upgrades & crew ----------------------------------------------------

func upgrade_cost(id: String) -> int:
	var costs: Array = GameData.upgrades_by_id[id].costs
	var lvl := int(upgrades.get(id, 0))
	return int(costs[lvl]) if lvl < costs.size() else -1


func buy_upgrade(id: String) -> bool:
	var cost := upgrade_cost(id)
	if cost < 0 or cost > gold:
		return false
	gold -= cost
	upgrades[id] = int(upgrades.get(id, 0)) + 1
	message.emit("Upgraded %s to level %d." % [GameData.upgrades_by_id[id].name, upgrades[id]])
	changed.emit()
	return true


func crew_fee() -> int:
	return int(GameData.bal("crew", "hire_fee", 150))


func max_crew() -> int:
	return int(GameData.bal("crew", "max_crew", 10))


func tavern_candidates(town_id: String) -> Array:
	var offer: Dictionary = tavern_offers.get(town_id, {})
	if offer.is_empty() or int(offer.day) != day:
		var names := []
		for i in int(GameData.bal("crew", "candidates_per_visit", 3)):
			names.append(random_crew_name())
		offer = {"day": day, "names": names}
		tavern_offers[town_id] = offer
	return offer.names


func hire_crew(town_id: String, crew_name: String) -> bool:
	if gold < crew_fee() or crew.size() >= max_crew():
		return false
	gold -= crew_fee()
	crew.append(crew_name)
	tavern_offers[town_id].names.erase(crew_name)
	message.emit("%s joins the crew of the %s." % [crew_name, ship_name])
	changed.emit()
	return true


const _FIRST := ["Ada", "Bram", "Cora", "Dax", "Edda", "Finn", "Greta", "Hob", "Isla", "Jory", "Kit", "Lars",
	"Mags", "Nell", "Orrin", "Pip", "Quill", "Rook", "Sable", "Tam", "Ulla", "Vik", "Wren", "Yara", "Zed"]
const _LAST := ["Saltbeard", "Ashby", "Tarhand", "Gale", "Rudder", "Keel", "Brine", "Hollow", "Cinders",
	"Barnacle", "Stormwell", "Driftwood", "Flint", "Marsh", "Oakes"]


func random_crew_name() -> String:
	return "%s %s" % [_FIRST[rng.randi() % _FIRST.size()], _LAST[rng.randi() % _LAST.size()]]


# --- Time & travel -----------------------------------------------------------

## Advances one day: markets drift, perishables age. Emits messages.
func advance_day() -> void:
	day += 1
	stats.days_sailed += 1
	for n in Economy.tick(markets, rng):
		news.append({"day": day, "text": n})
	while news.size() > 10:
		news.pop_front()
	for lot in cargo.duplicate():
		if not is_perishable(lot.good):
			continue
		var f := lot_freshness(lot)
		if f <= 0.0:
			cargo.erase(lot)
			message.emit("%d %s rotted away and was thrown overboard." % [lot.qty, GameData.good_name(lot.good)])
		elif lot_fresh_left(lot) == 0:
			message.emit("Your %s will start to spoil tomorrow!" % GameData.good_name(lot.good))
	changed.emit()


func arrive_at(town_id: String) -> void:
	location = town_id
	if not town_id in stats.towns_visited:
		stats.towns_visited.append(town_id)
	record_prices(town_id)
	changed.emit()


func apply_encounter_result(result: Dictionary) -> void:
	gold = maxi(0, gold + int(result.get("gold", 0)))
	var loss := float(result.get("cargo_loss", 0.0))
	if loss > 0.0:
		for lot in cargo.duplicate():
			var lost := ceili(int(lot.qty) * loss)
			lot.qty = int(lot.qty) - lost
			if lot.qty <= 0:
				cargo.erase(lot)
	for i in int(result.get("crew_loss", 0)):
		if not crew.is_empty():
			crew.remove_at(rng.randi() % crew.size())
	changed.emit()


# --- Serialisation -----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"captain_id": captain_id, "captain_name": captain_name, "ship_name": ship_name,
		"gold": gold, "day": day, "location": location,
		"cargo": cargo, "crew": crew, "upgrades": upgrades,
		"markets": markets, "known_prices": known_prices, "news": news,
		"tavern_offers": tavern_offers, "stats": stats,
		"rng_seed": rng.seed, "rng_state": rng.state,
	}


func from_dict(save_slot: int, d: Dictionary) -> void:
	slot = save_slot
	captain_id = d.get("captain_id", "")
	captain_name = d.get("captain_name", "")
	ship_name = d.get("ship_name", "")
	gold = int(d.get("gold", 0))
	day = int(d.get("day", 1))
	location = d.get("location", GameData.start_town)
	cargo = d.get("cargo", [])
	crew = d.get("crew", [])
	upgrades = d.get("upgrades", {})
	for u in GameData.upgrades_by_id:
		upgrades[u] = int(upgrades.get(u, 0))
	markets = d.get("markets", {})
	# Fill in any towns/goods added to the data since this save was made.
	var fresh := Economy.init_markets(rng)
	for t in fresh:
		if not markets.has(t):
			markets[t] = fresh[t]
		for g in fresh[t]:
			if not markets[t].has(g):
				markets[t][g] = fresh[t][g]
	known_prices = d.get("known_prices", {})
	news = d.get("news", [])
	tavern_offers = d.get("tavern_offers", {})
	stats = d.get("stats", {})
	for k in ["profit", "trades", "encounters", "days_sailed"]:
		stats[k] = int(stats.get(k, 0))
	if not stats.has("towns_visited"):
		stats["towns_visited"] = [location]
	rng.seed = int(d.get("rng_seed", 0))
	rng.state = int(d.get("rng_state", 0))
	# JSON numbers load as floats; normalise ints that matter.
	for lot in cargo:
		lot.qty = int(lot.qty)
		lot.day = int(lot.day)
	changed.emit()
