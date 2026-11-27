# HOI3 BlackICE 15.1 cheats

Console cheat events for Hearts of Iron III: Their Finest Hour with the BlackICE 15.1 mod.

Mod install: `C:\Users\jack\games\Hearts of Iron 3\tfh\mod\BlackICE 15.1`

## Events (console: `event <id>`)

| id   | what it does |
|------|--------------|
| 9999 | adds 99,000 of every resource, supplies, fuel and money |
| 9997 | `cheatunits` (instant unit recruitment) or `cheatresearch` (+10000% research efficiency) for 2000 days |
| 9998 | leadership +500% (`leadship1`) |
| 9996 | **grant all technology**: one firing takes every tech to its max level, never past it |
| 9995 | **faster ship building**: permanent naval build time −50% / −70% / −85%, or remove |

## Why ships get slower as tech goes up

HoI3 adds about **+1% build time and IC per "upgrade"**. An upgrade is a level in any tech that has an effect block for that unit. ([HoI3 wiki, Research](https://hoi3.paradoxwikis.com/Research): "Each upgrade seems to result in a 1% increase in unit IC cost and build time.") The game engine does this itself, so no mod file controls it. What we measured matches:

    shown cost/time = (unit base + the techs' own build lines) x (1 + 1% x upgrades - practical %)

| case | upgrades | predicted | in game |
|------|----------|-----------|---------|
| USA carrier, before 9996 | 54 | ~1,080 days | ~1,000 days |
| USA carrier, after 9996 | 238 | ~2,370 days | >2,000 days |
| CHI carrier, practical +41% | 240 | 50.29 IC | 50.29 IC |
| CHI carrier, TEST all_1 (+26.7%) | 97 | 28.90 IC | 28.89 IC |

Event 9995 offsets this with `naval_build_speed`. It only shortens build time; daily IC stays the same. Rough guide for a fully teched carrier (about 2,000 days at practical 0): −50% gives about 1,000 days, −70% about 600, −85% about 300. Count a unit's upgrades with `upgrades.ps1`.

## Event 9996 choices

The mod has exclusive tech branches. These are hard-coded:

- heavy air, gasoline engine, welded armour
- Special Treatment Steel, closed hangar
- Superior Firepower doctrine, Befehlstaktik
- turreted vehicles, torpedo floatplane, 3x4 turret layout (not its reverse variant)
- division size increases at max

Also granted: `closed_hangar` and `proximity_fuze_ships`. Neither can be researched; the mod normally hands them out through the ship armour event and a 1944+ background decision.

Skipped: never-researchable techs (mixed/motorized/armored support upgrades, `*_info`), hidden tracker techs, nation-specific techs (Sherman, T-34, Tiger, Long Lance, ...), SS, Guards and NKVD techs, and the other three doctrine trees.

If some techs stop short of max (e.g. late jet levels), fire the event again; it never goes past max.

After firing, expect a burst of mod events and new decisions over the next game month or two, since everything that checks tech levels qualifies at once (HQ decisions, Special Warfare Training Center, KampfGruppen, transportation decisions, ...). See `reports/tech_events_summary.txt`.

## Extra naval ministers for Nationalist China

`mod/common/Nationalist China.txt` replaces `BlackICE 15.1/common/countries/Nationalist China.txt`. It adds three ministers, all available from 1936.1.1:

| id    | name         | post               | trait                          |
|-------|--------------|--------------------|--------------------------------|
| 52121 | Sa Zhenbing  | Head of Government | Old Admiral                    |
| 52122 | Shen Honglie | Chief of Navy      | Decisive Naval Battle Doctrine |
| 52123 | Du Xigui     | Armament Minister  | Battle Fleet Proponent         |

Each week these add to `capital_ship_shipyard_variable_count_minister` (+1, +2 and +1, doubled with the Navy national focus). At 80 points event 90207 adds a capital shipyard to a coastal core province you own and control. The original file is in `backup/Nationalist China.txt.orig`. The file is Windows-1252, so keep that encoding if you edit it.

## Layout

- `mod/events/PoliticalEvents_cheats.txt`: cheat events 9999, 9997, 9998 and 9996, copied from the end of the mod's `events/PoliticalEvents.txt`
- `mod/events/event_9996.txt`: event 9996 on its own, as generated
- `mod/common/event_modifiers_cheats.txt`: `cheatunits`, `cheatresearch`, `leadship1` and `ship_build_50/70/85` modifiers, copied from the end of `common/event_modifiers.txt`
- `mod/events/event_9995.txt`: event 9995 on its own
- `install_9995.ps1`: installs event 9995 and its modifiers into the mod (inserts it before the 9996 block, so `gen_event.ps1` keeps it) and refreshes `mod/events/PoliticalEvents_cheats.txt`
- `upgrades.ps1`: counts a unit's upgrades (summed tech levels) for one country in a save
- `techdiff.ps1`: compares the summed tech effects on one unit for two countries in a save (`-SaveName`, `-Unit`, `-A`, `-B`)
- `savediff.ps1`: lists techs that changed between two saves for one country, with each tech's effect on a unit
- `bisect.ps1`: builds `TEST *.hoi3` copies of a save with chosen techs set to another country's level, or to a given level (`-Init`, `-Split`, `-Only`, `-SetTo`, `-Exact`)
- `costscan.ps1`, `modscan.ps1`: list positive build cost/time effects and country-wide tech modifiers
- `savescan.ps1`: reads the latest save for one country (default `CHI`) and prints shipyard techs, shipyard counters, naval practicals, naval ministers in office and capital shipyards per province
- `setpractical.ps1`: sets one country's naval practicals in a save (default `CHI`, value 20, latest non-autosave). It backs the save up to `<save>.hoi3.bak` the first time it runs
- `techscan.ps1`: scans the mod's `technologies/*.txt` and writes `data/techs.csv` with each tech's category, max level, folder and `allow` block
- `gen_event.ps1`: builds event 9996 from `data/techs.csv` and replaces the 9996 block in the mod's `PoliticalEvents.txt`
- `eventscan.ps1`: lists every mod event and decision whose trigger checks a tech that event 9996 grants -> `reports/tech_events.csv`
- `data/seen.csv`: highest level of each tech seen in a 1940 save, used as the cap for techs without `max_level`
- `reports/`: tech lists produced while working out which techs are gated or exclusive

## Installing into the mod

1. Append `mod/events/PoliticalEvents_cheats.txt` to `BlackICE 15.1/events/PoliticalEvents.txt`.
2. Append `mod/common/event_modifiers_cheats.txt` to `BlackICE 15.1/common/event_modifiers.txt`.

To change the event 9996 choices, edit the exclude lists in `gen_event.ps1` and run:

```
powershell -NoProfile -ExecutionPolicy Bypass -File gen_event.ps1
```
