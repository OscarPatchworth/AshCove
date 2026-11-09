# AshCove

Mobile (landscape, 1080p) trading-at-sea game. Godot 4.7, GDScript. The Godot project lives in [`ash-cove/`](ash-cove/).

## Prototype v0.1 — what's in it

- **Start screen** with Continue / New Game / Load Game.
- **3 save slots**, autosave every time you dock, manual save from the in-game Menu.
- **Captain select**: 4 premade captains, each with a perk (sell bonus, speed, fight, cargo/freshness).
- **Click-to-sail map**: tap a town to see the days at sea, how dangerous the route is, and the prices you last saw there. Routes find the shortest way through other ports automatically.
- **Trading**: each town sells some goods cheap (what it produces) and pays well for others (what it demands). Prices drift every day, with occasional shortages and gluts. Buying pushes the price up and selling pushes it down, and prices recover over a few days.
- **Perishables** (Fish, Sunfruit, Moonpetal Elixir) keep full value for a few days, then lose value down to 0 over 3 days and get thrown overboard.
- **Shipyard**: Cargo Hold / Sails / Cannons upgrades (3 levels each).
- **Tavern**: hire crew for a one-off fee. Each crewmate adds a little cargo, speed and fight. Taverns also give rumours (market events plus a price tip).
- **Encounters (placeholder)**: random Fight / Flee / Pay Off choice while sailing, resolved by a dice roll weighted by your fight strength and speed.

## Tweaking the game without code

Everything is data in [`ash-cove/data/`](ash-cove/data/):

| File | What it controls |
| --- | --- |
| `world.json` | Towns (position, produces/demands, shipyard/tavern), routes (danger, `via` waypoints), island shapes |
| `goods.json` | Goods, base prices, perishable + fresh days |
| `captains.json` | Playable captains and their perks |
| `balance.json` | Ship base stats, crew fee/buffs, upgrade costs, market volatility, spoil speed, travel speed, encounter rate |
| `encounters.json` | Encounter types, strength / toll / loot ranges |

Map coordinates use a 1920×1080 space. Saves made before you add towns or goods still load (the missing markets get filled in).

## Code layout

See [docs/diagrams.md](docs/diagrams.md) for Mermaid diagrams of the data, the systems and the gameplay loop.

```
ash-cove/
  scripts/autoload/   GameData (reads JSON), GameState (the current run), SaveManager, UI (theme + widgets), SceneRouter
  scripts/systems/    Economy (price model), CombatResolver (PLACEHOLDER combat)
  scripts/map/        MapView (PLACEHOLDER 2D map renderer, no game logic)
  scripts/ui/         Screens: main menu, save select, character select, world map, port, encounter dialog
  scenes/             Thin .tscn roots; the UI is built in code
  tests/              Headless smoke test + screenshot tool
```

**Combat hook:** replace `CombatResolver.resolve_fight()`, or have `EncounterDialog` open a combat scene and pass its win/lose result to `CombatResolver.fight_outcome()`.

**2.5D map:** `MapView` only draws and reports clicks (`town_clicked`). A 3D map scene can replace it if it emits the same signal and has `ship_pos` / `ship_heading` / `selected_town` / `highlight_path` properties. The rest of the game doesn't need to change.

## Running

- Open `ash-cove/project.godot` in Godot 4.7 and press F5. Run `world_map.tscn` on its own (F6) to jump straight in with a debug save.
- Smoke test (from `ash-cove/`):
  `Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/smoke_test.tscn`
- Screenshots of every screen:
  `Godot_v4.7-stable_win64_console.exe --path . --resolution 1920x1080 res://tests/screenshots.tscn -- --out=C:/some/folder`

**Exporting to mobile:** add `*.json` to the export preset's "Filters to export non-resource files", otherwise the data files won't be packed.
