# AshCove — Diagrams (prototype v0.1)

Mermaid diagrams of the prototype's data, systems and gameplay loop. GitHub renders these inline; in VS Code use a Mermaid preview extension.

Numbers quoted below are the defaults in `ash-cove/data/balance.json`. If you change the code or data, update these diagrams too.

- [1. Data](#1-data)
  - [1.1 Static game data (JSON)](#11-static-game-data-json)
  - [1.2 Save file (the current run)](#12-save-file-the-current-run)
- [2. Systems](#2-systems)
  - [2.1 Architecture](#21-architecture)
  - [2.2 Screen flow](#22-screen-flow)
- [3. Gameplay](#3-gameplay)
  - [3.1 Core loop](#31-core-loop)
  - [3.2 A voyage, day by day](#32-a-voyage-day-by-day)
  - [3.3 Market price model](#33-market-price-model)
  - [3.4 Perishable goods](#34-perishable-goods)
  - [3.5 Encounters (placeholder combat)](#35-encounters-placeholder-combat)

---

## 1. Data

### 1.1 Static game data (JSON)

Read-only content loaded by `GameData` from `ash-cove/data/`. Editing these files changes the world without code changes.

```mermaid
erDiagram
    TOWN ||--o{ ROUTE : "is end a or b of"
    ROUTE ||--o{ WAYPOINT : "bends via"
    TOWN }o--o{ GOOD : "produces (cheap)"
    TOWN }o--o{ GOOD : "demands (dear)"
    ISLAND ||..o{ TOWN : "drawn near (visual only)"
    WORLD ||--|{ TOWN : contains
    WORLD ||--|{ ROUTE : contains
    WORLD ||--|{ ISLAND : contains
    WORLD ||--|| TOWN : "start_town"

    WORLD {
        string start_town "world.json"
    }
    TOWN {
        string id PK
        string name
        vec2 pos "1920x1080 map space"
        string desc
        list produces "good ids"
        list demands "good ids"
        bool shipyard
        bool tavern
    }
    ROUTE {
        string a FK "town id"
        string b FK "town id"
        float danger "0 to 1"
        list via "optional waypoints"
    }
    WAYPOINT {
        float x
        float y
    }
    ISLAND {
        string name
        vec2 center
        vec2 radius
        int seed "shape wobble"
    }
    GOOD {
        string id PK
        string name
        int base_price
        string color
        bool perishable
        int fresh_days
    }
    CAPTAIN {
        string id PK
        string name
        string title
        int start_gold
        string perk_name
        dict perks "sell_mult buy_mult speed_mult fight_bonus flee_bonus cargo_bonus fresh_bonus start_crew start_cannons"
    }
    ENCOUNTER {
        string id PK
        string name
        int weight "pick chance"
        range strength
        range toll
        range loot
        string pay_text
    }
    BALANCE {
        dict ship "base cargo speed fight"
        dict crew "fee max buffs"
        list upgrades "hold sails cannons"
        dict market "multipliers spreads drift"
        dict perish "spoil_days"
        dict travel "speed encounter rate"
    }
```

### 1.2 Save file (the current run)

`GameState.to_dict()` is written by `SaveManager` to `user://saves/slot_N.json` (N = 0–2). On Windows that's `%APPDATA%/Godot/app_userdata/AshCove/saves/`.

```mermaid
erDiagram
    SAVE ||--|| CAPTAIN : "captain_id"
    SAVE ||--|| TOWN : "location"
    SAVE ||--o{ CARGO_LOT : cargo
    SAVE ||--o{ CREW_NAME : crew
    SAVE ||--|{ MARKET_STATE : "markets (town x good)"
    SAVE ||--o{ KNOWN_PRICES : "known_prices (per town)"
    SAVE ||--o{ NEWS : "news (last 10)"
    SAVE ||--o{ TAVERN_OFFER : "tavern_offers (per town)"
    CARGO_LOT }o--|| GOOD : good
    MARKET_STATE }o--|| TOWN : town
    MARKET_STATE }o--|| GOOD : good

    SAVE {
        int version
        string saved_at
        string captain_name
        string ship_name
        int gold
        int day
        dict upgrades "hold sails cannons levels"
        dict stats "profit trades encounters days_sailed towns_visited"
        int rng_seed
        int rng_state
    }
    CARGO_LOT {
        string good FK
        int qty
        int day "day bought - drives spoilage"
        float cost "avg unit cost paid"
    }
    CREW_NAME {
        string name
    }
    MARKET_STATE {
        float noise "daily random drift"
        float pressure "player trade impact"
    }
    KNOWN_PRICES {
        int day "when last seen"
        dict buy "good to price"
        dict sell "good to price"
    }
    NEWS {
        int day
        string text
    }
    TAVERN_OFFER {
        int day
        list names "crew for hire today"
    }
```

---

## 2. Systems

### 2.1 Architecture

Autoloads hold all state and rules. Screens are thin `.tscn` roots that build their UI in code and talk to the autoloads. The **placeholder** parts (the map renderer and combat) are kept separate so they can be swapped out.

```mermaid
flowchart TD
    subgraph SCREENS["Screens (scenes/ + scripts/ui/)"]
        direction LR
        subgraph MENUS["Menu screens"]
            direction TB
            MM[MainMenu]
            SS[SaveSelect]
            CS[CharacterSelect]
        end
        subgraph GAME["WorldMap (main game screen)"]
            direction TB
            WM["WorldMap<br/>HUD, side panel, sailing loop"]
            MV["MapView<br/>PLACEHOLDER 2D map"]
            PS["PortScreen<br/>Market / Shipyard / Tavern"]
            ED["EncounterDialog<br/>Fight / Flee / Pay"]
            WM --> MV
            WM --> PS
            WM --> ED
        end
    end

    subgraph AUTO["Autoloads (scripts/autoload/)"]
        direction LR
        SR["SceneRouter<br/>scene changes"]
        SM["SaveManager<br/>3 JSON slots"]
        GS["GameState<br/>the current run"]
        GD["GameData<br/>content + route graph"]
    end

    subgraph SYS["Systems (scripts/systems/)"]
        direction LR
        EC["Economy<br/>prices + daily tick"]
        CR["CombatResolver<br/>PLACEHOLDER dice roll"]
    end

    DATA[("data/*.json")]

    MENUS --> SR
    MENUS --> SM
    CS -- new_game --> GS
    WM -- "autosave" --> SM
    WM -- "travel, advance_day" --> GS
    PS -- "buy / sell / upgrade / hire" --> GS
    ED -- resolve --> CR
    CR -- "apply result" --> GS
    SM <-- "to_dict / from_dict" --> GS
    GS -- "tick, prices" --> EC
    GS ==>|"signals: changed, message"| WM
    DATA --> GD
    GD --> GS
    GD --> EC
    GD --> CR

    classDef placeholder fill:#5a2d1a,stroke:#e8743b,color:#fff
    class CR,MV placeholder
```

Not drawn, to keep the graph readable: every screen uses the `UI` autoload for its theme and widgets, and `MapView` reads `GameData` and `GameState` directly to draw the map.

**Swap points:**
- **2.5D map** — replace `MapView` with anything that emits `town_clicked(id)` and has `ship_pos`, `ship_heading`, `selected_town` and `highlight_path` properties.
- **Real combat** — replace `CombatResolver.resolve_fight()`, or have `EncounterDialog` open a combat scene and pass its result to `CombatResolver.fight_outcome(enc, won, rng)`.

### 2.2 Screen flow

```mermaid
flowchart LR
    START((Launch)) --> MM[Main Menu]
    MM -- Continue --> LOAD1[/"load latest slot"/] --> WM
    MM -- New Game --> SSN["Save Select<br/>(new mode)<br/>can delete slots"]
    MM -- Load Game --> SSL["Save Select<br/>(load mode)<br/>can delete slots"]
    MM -- Quit --> EXIT((Exit))

    SSN -- "empty slot /<br/>confirm overwrite" --> CS[Character Select]
    SSN -- Back --> MM
    SSL -- Load --> LOAD2[/"load slot"/] --> WM
    SSL -- Back --> MM

    CS -- Back --> SSN
    CS -- "Set Sail" --> NEW[/"new_game + save"/] --> WM

    WM[World Map] -- "Menu > Save & Quit" --> MM
    WM <--> PORT[Port Screen overlay]
    WM <--> POP["Ship / Menu popups"]
    WM <--> ENC[Encounter dialog]
```

---

## 3. Gameplay

### 3.1 Core loop

```mermaid
flowchart TD
    DOCK(["Docked at port<br/>(autosaved)"]) --> MARKET

    subgraph PORT["In port"]
        MARKET["Market<br/>sell cargo, buy cheap goods"]
        YARD["Shipyard<br/>hold / sails / cannons"]
        TAV["Tavern<br/>hire crew, read rumours"]
        MARKET <--> YARD
        MARKET <--> TAV
    end

    PORT -- "Cast Off" --> PLAN["Plan on the map<br/>tap a town: days, danger,<br/>last-seen prices"]
    PLAN --> SAIL["Set Sail<br/>day-by-day voyage"]
    SAIL --> EVT{"Encounter?"}
    EVT -- no --> ARRIVE
    EVT -- yes --> FIGHT["Fight / Flee / Pay Off"] --> ARRIVE
    ARRIVE["Arrive<br/>record prices, autosave"] --> DOCK

    MARKET -. "profit" .-> GOLD[(Gold)]
    GOLD -. "spend" .-> YARD
    GOLD -. "spend" .-> TAV
    YARD -. "more cargo, speed, fight" .-> SAIL
    TAV -. "more cargo, speed, fight" .-> SAIL
```

### 3.2 A voyage, day by day

What `WorldMap._set_sail()` does from the moment you press **Set Sail**.

```mermaid
sequenceDiagram
    autonumber
    actor P as Player
    participant WM as WorldMap
    participant GD as GameData
    participant GS as GameState
    participant EC as Economy
    participant CR as CombatResolver
    participant ED as EncounterDialog
    participant SM as SaveManager

    P->>WM: tap town, Set Sail
    WM->>GD: find_path(location, dest)
    GD-->>WM: towns, routes, length
    WM->>GS: travel_days(length)
    Note over WM: days = ceil(length / ship_speed)

    loop each day 1..N
        WM->>WM: tween ship along path (0.55s)
        WM->>GS: advance_day()
        GS->>EC: tick(markets)
        EC-->>GS: drifted prices + news events
        GS->>GS: age perishables, throw out rotten lots
        alt not the final day
            WM->>CR: roll_encounter(route danger)
            opt encounter triggered
                WM->>ED: show(make_encounter())
                P->>ED: Fight / Flee / Pay
                ED->>CR: resolve(action)
                CR-->>ED: outcome
                ED->>GS: apply_encounter_result()
                ED-->>WM: finished
            end
        end
    end

    WM->>GS: arrive_at(dest), record_prices
    WM->>SM: save_game() (autosave)
    WM->>P: open PortScreen
```

### 3.3 Market price model

Every town keeps a `noise` and a `pressure` value for every good.

```mermaid
flowchart LR
    BASE["base_price<br/>(goods.json)"] --> MID
    TM["town_mult<br/>produces x0.55<br/>demands x1.65<br/>else x1.0<br/>plus fixed +/-12% per town"] --> MID
    NOISE["(1 + noise)<br/>daily drift"] --> MID
    PRES["(1 + pressure)<br/>your trading"] --> MID
    MID(("mid price")) --> BUY["Buy = ceil(mid x 1.06 x captain buy_mult)"]
    MID --> SELL["Sell = floor(mid x 0.94 x captain sell_mult)<br/>x lot freshness"]

    subgraph TRADE["Each unit traded"]
        B1["buy 1 unit"] -- "pressure +0.012" --> PRES
        S1["sell 1 unit"] -- "pressure -0.012" --> PRES
    end

    subgraph DAY["Each day (Economy.tick)"]
        D1["pressure x 0.82<br/>(recovers toward 0)"] --> PRES
        D2["noise x 0.9 + random(+/-0.06)<br/>clamped +/-0.35"] --> NOISE
        D3["2% per town: shortage or glut<br/>noise +/-0.35 + news item"] --> NOISE
    end
```

### 3.4 Perishable goods

Each cargo lot remembers the day it was bought. Defaults: Fish 3 days fresh, Sunfruit 4, Elixir 6, plus 2 for the Quartermaster. Selling takes from the oldest lot first.

```mermaid
stateDiagram-v2
    [*] --> Fresh: bought (lot.day = today)
    Fresh --> Fresh: age <= fresh_days<br/>value 100%
    Fresh --> Spoiling: age > fresh_days<br/>("will start to spoil tomorrow!" warning the day before)
    Spoiling --> Spoiling: value drops linearly<br/>100% to 0% over 3 days
    Spoiling --> Rotten: value reaches 0%
    Rotten --> [*]: thrown overboard
    Fresh --> [*]: sold
    Spoiling --> [*]: sold at reduced value
```

### 3.5 Encounters (placeholder combat)

The encounter chance is rolled on every day at sea except the arrival day: `0.12 x (0.5 + route danger)`. Enemy strength, toll and loot scale by `1 + day/60`.

```mermaid
stateDiagram-v2
    state "Fight / Flee / Pay Off" as Choice
    state "Fight / Pay Off (no fleeing)" as CaughtChoice

    [*] --> Choice: encounter generated<br/>(weighted pick from encounters.json)
    Choice --> Won: fight succeeds
    Choice --> Lost: fight fails
    Choice --> Fled: flee succeeds
    Choice --> Caught: flee fails
    Choice --> Paid: pay toll
    Caught --> CaughtChoice
    CaughtChoice --> Won
    CaughtChoice --> Lost
    CaughtChoice --> Paid

    Won --> [*]: + loot gold
    Lost --> [*]: -20% gold, -33% of each cargo lot,<br/>50% chance to lose a crewmate
    Fled --> [*]: no cost
    Paid --> [*]: - toll gold

    note right of Choice
        Fight win chance = you / (you + them), clamped 10-90%
        Flee chance = 0.3 + (speed ratio - 1) x 0.6
            + captain flee bonus - their strength x 0.015, clamped 10-85%
        Pay Off needs gold >= toll
    end note
```

Your fight strength = 2 base + 2 per Cannons level + 0.5 per crewmate + captain bonus (Privateer +3).
