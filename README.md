# WatchTamer 🦖

A classic 90s-style virtual pet for Apple Watch, the kind you raised on a keychain and then plugged into a friend's to battle. It uses a dot-matrix LCD, icon menus and care mistakes, with dinosaurs in place of monsters.

![The 12 WatchTamer dinosaurs](docs/dinosaurs.png)

## Requirements

- Apple Watch running **watchOS 26.4** or later
- **Xcode 26.4** or later on a Mac, to build and install it
- No iPhone app, account or internet connection needed

## Build & run

1. Open `WatchTamer.xcodeproj` in Xcode.
2. Select the target **WatchTamer Watch App** → **Signing & Capabilities** → choose your own **Team** (a free Apple ID works for your own watch).
3. Pick your Apple Watch (or a watch simulator) at the top of the window and press **▶ Run**.
4. On first launch, allow **Motion & Fitness** (for walk training) and **Notifications** (for care reminders).

Builds run from Xcode include a **Testing** section in Settings (skip time, add steps, evolve now, make sick). App Store and TestFlight builds leave it out automatically.

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

Swipe left for **Settings**: pause (daycare), pause while charging, Classic (real time) or Fast (10×) speed, night screen, notification switches, walk training and steps per rep.

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

How long each stage lasts at Classic speed: Egg 10 min · Baby I 10 min · Baby II 6 h · Rookie 24 h · Champion 36 h (then it evolves once it meets the battle goal). Fast speed is 10× quicker. Time spent paused (daycare or charging) doesn't count.

## Project layout

- `PetModel.swift`: all game rules (pure, minute-by-minute simulation)
- `DinoState.swift`: live game: clock, actions, battles, training, step counting, saves, reminders
- `ContentView.swift`: the device screen (icons + LCD)
- `DinoSpriteView.swift`: LCD palette and pixel renderer
- `PixelArt.swift`: all dinosaur and icon sprites as dot-matrix art
- `BattleCode.swift`: friend battle codes and the shared, seeded fight
- `SettingsView.swift`: settings, help and testing tools
- `docs/dinosaurs.png`: the roster image above

## Privacy

WatchTamer has no accounts, ads, analytics or network code. Your dino, your settings and your step count stay on your watch. Step data is only read to turn walking into training; it is never sent anywhere. For the App Store privacy label, this app is **Data Not Collected**.

## License

WatchTamer is free and open source under the [MIT License](LICENSE). You're welcome to play it, learn from it, change it and share it. Just keep the copyright notice.
