# WatchTamer 🦖

A classic 90s-style virtual pet for Apple Watch, the kind you raised on a keychain and then plugged into a friend's to battle. It uses a dot-matrix LCD, icon menus and care mistakes, with dinosaurs in place of monsters.

## How to play

| Icon | What it does |
| --- | --- |
| ⚖️ **Status** | Tap through 6 pages: form & age, hunger hearts, strength hearts, effort, battle record, care |
| 🍴 **Feed** | **Meat** = +1 hunger heart (+1g). **Protein** = +1 strength heart (+2g) |
| 🏋️ **Train** | **TAP**: mash the screen for 5 seconds to fill the meter. **WALK**: just walk; every 250 steps (adjustable) counts as a training rep, even while the app is closed |
| ⚡ **Battle** | **CPU**: fight a computer rival. **FRIEND**: swap battle codes (see below). First to 3 hits wins. Rookie and up |
| 🌊 **Flush** | Clean up poop. 8 piles = your dino gets sick |
| 💡 **Lights** | Bedtime starts at 8–10pm (by stage). **Light off** = your dino sleeps and its needs pause. **Light on** = it wakes up, so you can feed, train, battle, clean and heal any time of day or night. Leave the game during bedtime and the light switches off by itself. |
| ➕ **Medicine** | Cure sickness and battle injuries (skull icon) |
| ⚠️ **Call** | Blinks when your dino needs you. Ignore it for 10 minutes = 1 care mistake |

**Notifications:** when the app is closed, your watch alerts you when your dino gets hungry 🍖, weak 💪, poops 💩 (each pile, with a warning before it gets sick), or gets sick 💀. Each type can be switched off in Settings.

**Taking your watch off? Your dino is safe.**
- **Daycare pause:** hold the screen for 1 second (or use Settings) to freeze time completely. Tap to resume; the paused time is skipped.
- **Charger pause:** if the watch is charging when the game opens or closes, it pauses automatically and resumes once unplugged (can be switched off).
- **Safety net:** your dino can never die while the app is closed. It can still get hungry or sick, but it waits for you, and after you come back you get at least an hour (game time) to fix things.

Swipe left for **Settings**: Classic (real time) or Fast (10×) speed, night screen, care reminders, and walk training. Builds run from Xcode also show testing buttons; App Store builds hide them.

## Battling a friend (battle codes)

1. Both players tap ⚡ → **FRIEND**. Each watch shows a code like `H5N-9QP`, a snapshot of that dino.
2. Type your friend's code into your watch while they type yours.
3. Both watches play out the **same fight** with the same winner, with no internet or pairing needed.

Codes refresh after every battle, so swap new ones for a rematch. Tap your code to make a new one. Mistyped codes are rejected.

## Evolution chart

```
Egg → Hatchling → Dino Kid ─┬─ (≤3 mistakes) Raptor ─┬─ good care + 16 trainings → Triceratops ─→ T-REX
                            │                         ├─ good care, less training → Pteranodon ──→ SPINOSAURUS
                            │                         ├─ sloppy care + training ──→ Stegosaurus ─→ ANKYLOSAURUS
                            │                         └─ sloppy care, no training → Parasaur ────→ BRACHIOSAURUS
                            └─ (4+ mistakes) Compy ───┬─ 16 trainings, ≤5 mistakes → Dilophosaurus → SPINOSAURUS
                                                      ├─ 8+ trainings ────────────→ Stegosaurus
                                                      └─ otherwise ───────────────→ Parasaur
Champion → Ultimate needs 15+ battles with an 80%+ win rate at that stage.
6+ care mistakes as a Champion → Pachycephalosaurus.
```

Timing (Classic speed): Baby I 10 min → Baby II 6 h → Rookie 24 h → Champion 36 h → Ultimate.

## Project layout

- `PetModel.swift`: all game rules (pure, minute-by-minute simulation)
- `DinoState.swift`: live game: clock, actions, battles, training, step counting, saves, reminders
- `ContentView.swift`: the device screen (icons + LCD)
- `DinoSpriteView.swift`: LCD palette and pixel renderer
- `PixelArt.swift`: all dinosaur and icon sprites as dot-matrix art
- `SettingsView.swift`: settings, help and testing tools
