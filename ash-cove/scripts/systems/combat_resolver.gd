class_name CombatResolver
extends RefCounted
## PLACEHOLDER combat: a random resolver for the Fight / Flee / Pay Off choice.
##
## To plug in real combat later, replace `resolve_fight()` (or have the encounter
## dialog launch a combat scene and feed its win/lose into `fight_outcome()`).
## Everything else (encounter generation, consequences) can stay as is.


## Rolls whether an encounter happens on one day of sailing a route.
static func roll_encounter(route_danger: float, rng: RandomNumberGenerator) -> bool:
	var base := float(GameData.bal("travel", "base_encounter_chance", 0.12))
	return rng.randf() < base * (0.5 + route_danger)


static func make_encounter(rng: RandomNumberGenerator, day: int) -> Dictionary:
	var total := 0
	for e in GameData.encounters:
		total += int(e.get("weight", 1))
	var pick := rng.randi_range(1, total)
	var def: Dictionary = GameData.encounters[0]
	for e in GameData.encounters:
		pick -= int(e.get("weight", 1))
		if pick <= 0:
			def = e
			break
	var scale := 1.0 + day / 60.0
	return {
		"id": def.id,
		"name": def.name,
		"text": def.text,
		"pay_text": def.get("pay_text", "Pay them off"),
		"strength": snappedf(rng.randf_range(def.strength[0], def.strength[1]) * scale, 0.1),
		"toll": int(rng.randi_range(int(def.toll[0]), int(def.toll[1])) * scale),
		"loot": int(rng.randi_range(int(def.loot[0]), int(def.loot[1])) * scale),
	}


static func fight_chance(enc: Dictionary) -> float:
	var power := GameState.fight_strength()
	return clampf(power / (power + float(enc.strength)), 0.1, 0.9)


static func flee_chance(enc: Dictionary) -> float:
	var speed_ratio := GameState.ship_speed() / float(GameData.bal("ship", "base_speed", 110))
	var c := 0.3 + (speed_ratio - 1.0) * 0.6 + float(GameState.perk("flee_bonus", 0.0))
	c -= float(enc.strength) * 0.015
	return clampf(c, 0.1, 0.85)


## Returns a result dict: {outcome, text, gold, cargo_loss, crew_loss, can_continue}
## outcome: "won", "lost", "fled", "caught", "paid"
static func resolve(action: String, enc: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	match action:
		"fight":
			return resolve_fight(enc, rng)
		"flee":
			if rng.randf() < flee_chance(enc):
				return {"outcome": "fled", "text": "You catch a lucky gust and leave the %s in your wake." % enc.name}
			return {"outcome": "caught", "text": "They're too quick! The %s blocks your escape. Fight or pay." % enc.name}
		"pay":
			return {"outcome": "paid", "gold": -int(enc.toll),
				"text": "You hand over %d gold. The %s lets you pass." % [enc.toll, enc.name]}
	return {"outcome": "fled", "text": ""}


static func resolve_fight(enc: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	return fight_outcome(enc, rng.randf() < fight_chance(enc), rng)


static func fight_outcome(enc: Dictionary, won: bool, rng: RandomNumberGenerator) -> Dictionary:
	if won:
		return {"outcome": "won", "gold": int(enc.loot),
			"text": "Victory! You drive off the %s and salvage %d gold." % [enc.name, enc.loot]}
	var gold_loss := int(GameState.gold * 0.2)
	var crew_loss := 1 if (not GameState.crew.is_empty() and rng.randf() < 0.5) else 0
	var text := "Defeat. The %s plunders a third of your cargo and %d gold." % [enc.name, gold_loss]
	if crew_loss > 0:
		text += " One of your crew was lost."
	return {"outcome": "lost", "gold": -gold_loss, "cargo_loss": 0.33, "crew_loss": crew_loss, "text": text}
