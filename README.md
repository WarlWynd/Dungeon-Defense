# Dungeon Tower Defense — Milestone 1 Vertical Slice

A Godot 4 project. Colored shapes, no art, no menus, no meta-progression. That's deliberate — this build exists to answer **three questions** and nothing else.

## Run it

1. Install **Godot 4.3+** (Standard build — you do not need the .NET/C# version).
2. Open Godot → **Import** → select the `project.godot` in this folder.
3. Press **F5**.

## How to play

The dungeon runs top (entrance) to bottom (vault). The glowing gold pile at the bottom is your **Hoard** — it is your build currency, your health bar, your Allure rating and your score, all at the same time.

During **BUILD**, tap a trap in the bottom tray, then tap a glowing circle on the map to place it. Hit **UNLEASH** (or wait out the timer) to start the wave.

**Keys:** `P` / `Space` / `Esc` pause · `F` toggles 2× speed · `R` swaps the window between portrait and landscape. There are on-screen **PAUSE** and **1x/2x** buttons top-right too — the game owns its own pause, because Godot's editor pause button lives in the embedded-game toolbar and vanishes when you un-embed the game to test rotation.

To test rotation you need the game running in its own window: **Editor Settings → Run → Window Placement → Game Embed Mode → Disabled**. (Dragging the window wider than it is tall also works — the dungeon re-fits and rotates automatically.)

Heroes walk in, reach the vault, **grab your gold and run back out**. Kill them on the way out and the coins fly home. Let them reach the entrance and that gold is **gone for the rest of the level**.

Watch the notches on the hoard bar. Select a trap and the bar shows you a **ghost preview** of where the purchase lands you — and flashes red if it's about to cost you a minion.

## What you're testing

Play it for an hour and answer these honestly. They are the go/no-go for the whole project (GDD §16).

**1. Is watching gold *leave* compelling, or just stressful?** The entire design rests on this bet. If it feels like punishment rather than tension, the fix is generosity in the recovery mechanic — not abandoning the concept.

**2. Does the return trip actually get played?** Build only at the entrance and see what happens. If your traps are good enough that nobody ever reaches the vault, the whole retrieval layer is dead content and hero HP needs tuning *up* so that leaks are normal rather than a failure state. That's a big philosophy call and this build is how you make it.

**3. Does Allure make spending *interesting* or just *frightening*?** Watch for the tell: if you find yourself refusing to build traps at all because you're scared to drop below a notch, the thresholds are too punishing and need to be lower and further apart.

## What's in here

**The steal-and-flee loop.** Hero state machine is `ADVANCING → LOOTING → FLEEING → ESCAPED`, plus `CHARMED`/`RETURNING`. Movement samples a `Curve2D` directly rather than using `PathFollow2D`, so fleeing is just `direction = -1`.

**Two heroes.** The *Squire* (weak, packs) and the *Treasure Hunter* — fragile, fast, and it steals 160 gold in one grab. It's in wave 2 on purpose: it's the enemy that teaches the whole mechanic.

**Three traps.** Spike Pit (area), Crossbow Turret (single-target, and it happily shoots *fleeing* thieves), Frost Totem (no damage, pure slow — deliberately unglamorous so its power is a discovery).

**Two minions, via Allure.** *Goblin Pack* arrives above 50% hoard. *Succubus* arrives above 75% — she doesn't kill, she **charms**: a thief carrying your gold turns around and walks it back to your vault for you. She only works on the greedy; disciplined heroes are immune.

**The guardrails.** Allure is evaluated *only* at wave start (never mid-fight), there's a hysteresis buffer so minions don't flicker in and out, desertion is telegraphed a full build window in advance, and the Goblin Pack never fully abandons you. Without these the system death-spirals.

## Known gaps (deliberate)

No art, no audio, no haptics, no win/lose screens beyond a text label, no save, no Workshop, no Kingdom Escalation, no bait or interdiction traps. All of that is Milestone 2+ in `ROADMAP.md`. **Do not build any of it until questions 1–3 are answered.**

## Where to tune

Everything is in `scripts/autoload/game_data.gd`. Hero stats, trap costs, Allure thresholds, wave composition, starting hoard. One file, no hunting.

The numbers most worth pushing on first: `STARTING_HOARD`, the Treasure Hunter's `greed` (160), and the Goblin Pack's `allure_arrive` (0.50).
