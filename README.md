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

## Event 9996 choices

The mod has exclusive tech branches. These are hard-coded:

- heavy air, gasoline engine, welded armour
- Special Treatment Steel, closed hangar
- Superior Firepower doctrine, Befehlstaktik
- turreted vehicles, torpedo floatplane, 3x4 turret layout
- division size increases at max

Skipped: never-researchable techs (mixed/motorized/armored support upgrades, `*_info`), hidden tracker techs, nation-specific techs (Sherman, T-34, Tiger, Long Lance, ...), SS, Guards and NKVD techs, and the other three doctrine trees.

## Layout

- `mod/events/PoliticalEvents_cheats.txt`: cheat events 9999, 9997, 9998 and 9996, copied from the end of the mod's `events/PoliticalEvents.txt`
- `mod/events/event_9996.txt`: event 9996 on its own, as generated
- `mod/common/event_modifiers_cheats.txt`: `cheatunits`, `cheatresearch` and `leadship1` modifiers, copied from the end of `common/event_modifiers.txt`
- `techscan.ps1`: scans the mod's `technologies/*.txt` and writes `data/techs.csv` with each tech's category, max level, folder and `allow` block
- `gen_event.ps1`: builds event 9996 from `data/techs.csv` and replaces the 9996 block in the mod's `PoliticalEvents.txt`
- `data/seen.csv`: highest level of each tech seen in a 1940 save, used as the cap for techs without `max_level`
- `reports/`: tech lists produced while working out which techs are gated or exclusive

## Installing into the mod

1. Append `mod/events/PoliticalEvents_cheats.txt` to `BlackICE 15.1/events/PoliticalEvents.txt`.
2. Append `mod/common/event_modifiers_cheats.txt` to `BlackICE 15.1/common/event_modifiers.txt`.

To change the event 9996 choices, edit the exclude lists in `gen_event.ps1` and run:

```
powershell -NoProfile -ExecutionPolicy Bypass -File gen_event.ps1
```
