# Dungeon Tower Defense — Build Roadmap

Companion to `GAME_DESIGN_DOC.md`. This is the "how we actually get there" doc.

---

## Milestone 0 — Setup (a few hours)

Install Godot 4.x (Standard build — you don't need the .NET/C# build; GDScript is the right choice for a hobbyist and is well-suited to this game). Create the project with the **Compatibility** renderer and portrait orientation locked. Set up Git — even solo, even for a hobby project, because you will break something at 1am and want to go back.

Deliverable: an empty Godot project that opens and shows a grey portrait screen.

---

## Milestone 1 — Vertical Slice (the only milestone that matters right now)

**The goal of this milestone is to prove the theft loop is fun.** Everything else is negotiable; this isn't.

One map. Three traps (Spike Pit, Crossbow Turret, Frost Totem). Two enemies (Squire, Treasure Hunter). Five hardcoded waves. No menus, no meta-progression, no art beyond colored rectangles.

Build order within the slice:

1. A hero walks a path (Path2D + PathFollow2D) to the vault. **The vault holds a Hoard — one number.**
2. **The steal-and-flee loop.** Hero reaches the vault → grabs N gold → *reverses along the path* → if it exits, that gold is gone forever. Get this working before anything else. It's the game.
3. Hero HP and death. **A hero killed while carrying gold drops it, and it returns to the hoard.**
4. Build nodes: tap an empty node, place a Crossbow Turret paid for *out of the hoard*, it shoots the nearest hero in range.
5. Wave spawner with a between-wave build window.
6. The other two traps, plus armor/damage types.
7. **One Allure threshold.** If the hoard is above 50% at the start of a wave, a Goblin Pack shows up free and fights for you. If it's below, they don't (or they leave). One threshold, one ally — that's enough to test whether the spend-vs-hoard dilemma is fun.
8. Lose state (hoard empty) and win state (all waves survived, scored on gold remaining).

Then stop and play it for an hour, and answer the three go/no-go questions from GDD §16: does watching gold leave feel *compelling* or just *stressful*; do heroes actually survive long enough to reach the vault at all; and does Allure make spending *interesting* or just *frightening*? This is the go/no-go point for the whole project.

---

## Milestone 2 — Feel & Readability

Same content, but it feels good. The priority list is specific here, because the *feel* of theft is what sells this game:

The animated Hoard counter and the shrinking vault pile. Coins flying out into a thief's hands. Coins spilling and flying home on a kill. The gold aura and coin icon on carrying heroes. The theft sound and the recovery chime. Haptics on stolen and recovered gold.

**The Allure preview.** Notches on the Hoard counter, and — critically — the drag-to-place preview that shows the player *before they commit* that this purchase will cost them an ally. Without this, Allure is cruel rather than tense. Treat it as core, not polish.

Then the general polish: trap fire animations, hit flashes, screen shake, 2× speed toggle, wave preview panel, trap radial menu. Placeholder art replaced with real tiles for World 1 only.

This is the milestone that separates a prototype from a game, and it's the one hobbyists skip. Don't.

---

## Milestone 3 — Systems

Loadout screen, Workshop (soul spending, permanent upgrades), level select with skull scoring, save/load, settings. Full trap and enemy roster including Bait and Interdiction traps. **The full Allure ladder** — all four ally tiers, hysteresis buffer, telegraphed desertion, and roaming allies that pursue fleeing thieves (`NavigationAgent2D`). **Kingdom Escalation** — the persistent escaped-hero roster and the "The Kingdom grows bolder" screen. Enemies and allies object-pooled.

---

## Milestone 4 — Content

Build World 1 (12 levels), tune, playtest, then Worlds 2–4. Content is the long tail — expect this to take longer than everything before it combined. Build a simple level-definition format (a JSON or Godot Resource file describing path, build nodes, and wave composition) so a level is data, not code. Doing this early is the difference between 48 levels being feasible and being a nightmare.

---

## Milestone 5 — Ship

Ads SDK and IAP integration, analytics, store assets (icon, screenshots, trailer, descriptions), privacy policy, age rating questionnaires, device testing on real low-end Android hardware. Apple Developer account ($99/yr, needs a Mac to build), Google Play account ($25 one-time, closed-test requirement — verify current rules when you get there).

Soft-launch in a small market first if you can. Watch the wave-3 drop-off rate — that number tells you if your tutorial works.

---

## Suggested Project Structure

```
res://
├── scenes/
│   ├── main/          # Main.tscn, LevelManager.tscn
│   ├── levels/        # Level scenes (thin — data-driven)
│   ├── traps/         # SpikePit.tscn, CrossbowTurret.tscn, Portcullis.tscn, ...
│   ├── heroes/        # Squire.tscn, Knight.tscn, TreasureHunter.tscn, ...
│   ├── allies/        # GoblinPack.tscn, CaveTroll.tscn, Wyrmling.tscn, ...
│   ├── projectiles/
│   └── ui/            # HUD, HoardCounter, RadialMenu, WavePreview, Workshop
├── scripts/
│   ├── autoload/      # GameState.gd, EconomySystem.gd, SaveManager.gd,
│   │                  # AudioManager.gd, EventBus.gd
│   ├── traps/         # trap_base.gd + one per trap
│   ├── units/         # unit_base.gd → hero_base.gd, ally_base.gd
│   └── systems/       # WaveSpawner.gd, AllureSystem.gd, DamageSystem.gd,
│                      # KingdomRoster.gd
├── resources/
│   ├── traps/         # TrapData .tres — cost, damage, type, range, upgrades
│   ├── heroes/        # HeroData .tres — hp, speed, armor, greed, discipline
│   ├── allies/        # AllyData .tres — hp, damage, allure_threshold
│   └── levels/        # LevelData .tres — path, build nodes, waves, starting hoard
├── assets/
│   ├── sprites/  art/  audio/  fonts/
└── project.godot
```

Three architectural decisions worth making now, because they're painful to retrofit:

**Custom Resources for all data.** `TrapData`, `EnemyData` (including `greed` and `discipline`), `LevelData` as `Resource` subclasses (`.tres`). Balance changes happen in the inspector, not in code, and levels become data you can author quickly.

**A global EventBus autoload** with signals like `hero_died(hero, carried_gold)`, `gold_stolen(amount)`, `gold_recovered(amount)`, `hero_escaped(hero, gold)`, `hoard_empty()`, `wave_started(n)`. HUD, audio, haptics and the Kingdom Roster all just listen. Saves you from a tangle of `get_parent().get_parent()`.

**One system owns the hoard.** An `EconomySystem` autoload holds the single gold number and is the *only* thing allowed to change it. Heroes don't reach in and subtract — they request a steal and the system decides. Every juicy UI moment in this game is driven off those signals, so getting this clean early pays for itself ten times.

---

## Reality Check on Timeline

For a hobbyist working evenings and weekends: the vertical slice is 2–4 weeks. A polished, shippable 48-level game is realistically 9–18 months. That's not discouragement — it's the number that lets you plan honestly and not quit at month 4 thinking you're behind.

The single best thing you can do is get Milestone 1 playable fast and put it in front of someone else.
