# Dungeon Tower Defense — Game Design Document

**Version:** 0.1 (draft)
**Engine:** Godot 4.x
**Platforms:** iOS (App Store), Android (Google Play)
**Orientation:** Portrait (one-handed play)
**Target:** 2D, pixel-art / painted hybrid, offline-first

---

## 1. High Concept

You are the dungeon. Waves of "heroes" — paladins, rogues, wizards — break in through the entrance to loot your treasure hoard, and you fill the corridors with traps, monster nests and cursed contraptions to stop them.

This is the inversion hook: **the player is the villain, and the thing being attacked is the player's gold.** The heroes are the aggressors. They want what's yours. You are not defending a base, you are defending a *hoard*.

Critically, this is not a reskin. The inversion is load-bearing in four systems — gold is the health bar (§3), hero greed is exploitable (§4), **the hoard itself attracts monsters to fight for you (§5)**, and the kingdom escalates against you (§8). Swap the heroes for orcs and the game stops working. That's the test a real hook has to pass.

**One-sentence pitch:** A tower defense where you play the dungeon, and the heroes are the ones raiding *you* — your gold is your health, your ammunition, and the beacon that summons monsters to your side.

---

## 2. Design Pillars

Four rules that settle every future argument:

**The gold is the point.** Every system routes through the hoard. It's your currency, your score, and your life total. If a feature doesn't make the player feel greedy, protective, or robbed, it probably doesn't belong.

**Readable at a glance.** The player is on a bus holding the phone in one hand. Every threat, every trap state, every coin lost must be legible in a half-second glance at a 6-inch screen. When a design choice adds depth but hurts clarity, clarity wins.

**Meaningful placement over meaningful clicking.** Difficulty comes from *where* you build and *what you build next to what*, not from tapping fast. There is no active-ability spam. A good player wins by reading the wave preview and committing to a layout.

**Every run teaches something.** A loss should leave the player saying "I should have put the Frost Totem at the corner," not "that was random." Enemy compositions are deterministic per level; the player is allowed to learn them.

---

## 3. Core Loop — The Hoard Is the Health Bar

**This is the central mechanic and everything else bends around it.**

There is no separate "base HP." Your level begins with a **Hoard** — say 1,000 gold sitting in the vault at the end of the dungeon. That pile is simultaneously:

- **Your build currency.** Every trap you place is paid for *out of the hoard*. Building is spending your own life total.
- **Your health bar.** Heroes that reach the vault don't "deal damage" — they **grab gold and turn around**. A Squire snatches 20 coins and runs for the exit. A Knight hauls 80.
- **Your score.** Gold remaining at the end of the level determines your rating.

**The retrieval mechanic:** a looting hero must carry the gold *back out through your entire dungeon*. Kill it before it escapes and the gold drops on the floor and returns to the vault. Let it out the front door and that gold is **gone permanently** — not just for this wave, for the rest of the level.

This one rule does an enormous amount of work:

*It makes the return trip the real game.* Your dungeon has to work in both directions. A player who front-loads all their damage at the entrance discovers that a fleeing hero walks out through an empty corridor.

*It makes every build decision agonizing.* Spending 200 gold on a Boulder Chute is 200 gold a hero can't steal — but it's also 200 gold you no longer have if the wave goes badly. Building is both defense and risk.

*It creates a genuine comeback mechanic.* You are never "dead" until the hoard is empty. A player at 80 gold with a good kill-corridor can claw gold back off a fleeing thief. That's a moment no hero-side TD produces.

*It makes losing feel like being robbed*, which is exactly the emotion this game is selling.

**Moment-to-moment (one level, 3–6 minutes):**

Build Phase opens with the map: the entrance, the path(s), the vault and its glittering hoard. A wave preview shows what's coming — including each hero's **Greed** value (how much they'll steal). The player spends from the hoard on traps, then taps **Unleash**.

Heroes enter, walk toward the vault, get shredded (or don't). Survivors loot and flee. Traps fire on them again on the way out. Between waves, a short build window (10s, skippable for a bonus). Repeat for 10–20 waves. Hoard hits zero → the dungeon is looted, run failed. Survive all waves → win, scored 1–3 skulls on gold remaining.

**Session-to-session (meta loop):**

Winning awards Souls (soft currency, scaled by gold defended) and sometimes a Blueprint (new trap or upgrade). Souls go into the **Dungeon Workshop** for permanent trap upgrades and new tiers. This is the retention engine: the next attempt at a hard level *feels different*, not just repeated.

The **Loadout** is capped — 5 traps carried into a level out of everything unlocked. This is the most important secondary system in the game. It turns "unlock everything" into "choose correctly," so a new trap changes how a level is played rather than just adding a button.

---

## 4. Greed — Hero Behavior and the Bait Layer

Heroes are not a conveyor belt. They are **adventurers**, and adventurers are greedy. That greed is a system you attack.

**Every hero has a Greed stat.** It governs how much gold they steal from the vault, and — more importantly — how easily they can be *distracted*.

**Bait is a core verb, not a gimmick.** Placeable lures pull heroes off the optimal path:

*Mimic Chest* — looks like treasure. High-greed heroes divert to open it and get eaten. Low-greed heroes (Paladins, the disciplined ones) walk straight past. This means bait is a *targeted* tool, not a universal one.

*Gold Pile (Decoy)* — you deliberately drop some of your own gold in a side room. Heroes detour to grab it. You've paid real currency to buy positioning — a trade only a villain would make, and it's delicious.

*Cursed Idol* — heroes stop to pick it up, becoming stationary for 2 seconds. A stun you have to *tempt* them into.

**Greed also splits parties.** In branching maps, a high-greed hero will peel away from its group toward a bait, breaking up the Shieldbearer's protective formation. Your bait placement isn't just "delay them" — it's *dismantling their composition*.

The design consequence: two viable strategic identities. **The Grinder** builds a lethal corridor and kills everything head-on. **The Trickster** builds cheap damage and enormous bait pressure, scattering parties and picking them apart. Both should clear the game.

---

## 5. Allure — The Hoard Summons Monsters

**Gold doesn't just buy things. Gold *calls* things.**

Your hoard has an **Allure** rating derived directly from how much gold is sitting in the vault. Monsters can smell treasure from miles away, and a big enough pile draws them out of the dark to fight for it. You don't buy allies. You **attract** them, by being rich.

**The thresholds** (tuned per level, shown as glowing notches on the Hoard counter):

| Hoard | Allure | Who shows up |
|---|---|---|
| >40% | *Noticed* | **Goblin Pack** — 3 weak melee roamers |
| >60% | *Whispered About* | **Cave Troll** — high HP, blocks a corridor, regenerates |
| >80% | *Legendary* | **Ogre Champion** — heavy Siege melee, hurls heroes backward |
| >95% | *The Dragon's Envy* | **Wyrmling** — flies, chases fleeing thieves, breathes fire |

**And here is the mechanic that makes this great: they leave when the gold does.**

Allies are mercenary. They are loyal to the *hoard*, not to you. If your gold drops back below a threshold, that monster **deserts** — it shrugs, gives you a look, and walks out. The pile isn't impressive anymore.

### The tension this creates

Until now, gold had two jobs (build currency, health bar), and both pushed the same way: spend gold to protect gold. Allure adds a third job that **pulls in the opposite direction.**

Spending 300 gold on a Boulder Chute is now *also* potentially spending your Ogre. Hoarding gold makes you powerful — but a hoarder with no traps is a hoarder about to be robbed.

Every build decision becomes a genuine dilemma:

- *"I could afford that Arcane Obelisk... but it drops me under 80% and the Ogre walks."*
- *"If that Treasure Hunter reaches the vault, I lose the gold AND the Wyrmling. Kill it at any cost."*
- *"I'm going to deliberately run a lean, cheap dungeon and let my Allure carry me."*

That last one is a whole viable playstyle. Alongside the Grinder and the Trickster, Allure creates **The Dragon** — build almost nothing, sit on an enormous pile, and let the monsters it summons do the killing. High risk, spectacular payoff, and a completely different way to play the same level.

### Why it's thematically perfect

The monsters don't respect you. They respect your money. That is *exactly* the right relationship for a villain fantasy, it's funny, and it makes the moment a hero robs you sting twice — you lose the gold, and you watch your Ogre leave in disgust.

### Guardrails (important — this system can death-spiral)

The obvious failure mode: you get robbed → your allies desert → you get robbed harder → everything leaves → unwinnable. That's not tension, that's a punishment loop. Three guardrails:

**Allies are locked in for the wave.** Allure is evaluated *at the start of each wave*. A monster that showed up for wave 6 fights the whole of wave 6, even if you're robbed blind mid-wave. Desertion happens in the quiet build window, never mid-fight.

**A hysteresis buffer.** A monster arrives at 80% but doesn't desert until 70%. This stops allies flickering in and out on every coin, which would be maddening and would make the Hoard counter unreadable.

**Desertion is telegraphed.** During the build window, an ally about to leave shows a clear "restless" state and a countdown. The player always has one build window to fix it — spend *less*, or recover gold — before it goes.

If playtesting still shows a spiral, the fallback is a floor: your lowest-tier ally (the Goblin Pack) never deserts. Cheap safety net, keeps a losing player in the fight.

### Design notes

Allies are **mobile**, which is what makes them structurally different from traps. They roam, they chase, and — critically — **they pursue fleeing thieves.** A Wyrmling that hunts down the Rogue sprinting for the exit with your gold is the single most satisfying thing in this game, and it exists only because Allure and the retrieval mechanic (§3) were designed to feed each other.

Optional depth, if it plays well: **tribute.** Top-tier allies take a small cut of the gold you recover. The Wyrmling is *helping*, but it's also here for itself. Only add this if the base system needs more friction — it may be a complication too far.

---

## 6. Combat Model

### Damage types and armor

Three damage types, three armor types, and a rock-paper-scissors matrix the player can learn in one level:

| Damage | Strong vs | Weak vs |
|---|---|---|
| **Physical** (spikes, blades, arrows) | Unarmored (rogues, mages) | Plate (knights, paladins) |
| **Magic** (arcane, fire, poison) | Plate (ignores armor) | Warded (mages, clerics) |
| **Siege** (boulders, crushing, explosive) | Shielded (breaks shields, hits groups) | Fast/evasive (misses lone rogues) |

The matrix is shown on the enemy's info card, and enemy sprites are color-coded by armor type at the silhouette level (heavy grey = plate, cloth blue = warded, leather brown = unarmored). This is the "readable at a glance" pillar in practice.

### Status effects

Only four, deliberately. Every trap either deals damage or applies one of these:

- **Slow** — reduces movement speed. The backbone of the game; almost every good layout has a slow source.
- **Burn** — damage over time, ignores armor. Punishes health-stacking bruisers.
- **Weaken** — target takes +30% damage from all sources. The multiplier that makes combos matter.
- **Stun** — target stops moving for a short duration. Rare, expensive, on cooldown.

Combos matter: a Frost Totem (Slow) plus a Boulder Chute (Siege, high damage, slow fire rate) is the classic pairing, because slowed enemies get hit by every boulder. The player discovering this on their own is a designed moment.

---

## 7. Trap Roster (Towers)

Every trap has 3 upgrade levels in-level (gold), and a permanent tier unlock in the Workshop (souls). Launch target is 14 traps; the first 5 are the tutorial set.

Note the new trap category — **Interdiction** traps only trigger on heroes *carrying gold*. They're worthless on the way in and lethal on the way out. They exist purely because of the retrieval mechanic, and they're the clearest proof the hook is structural.

**Tier 1 — starting kit**

*Spike Pit* — cheap physical damage, hits every hero standing on it, no range. The filler. Teaches "path coverage."

*Crossbow Turret* — single-target physical, medium range, fast fire rate. Teaches "range and line of sight."

*Frost Totem* — no damage, applies Slow in an area. Teaches "support traps have value." Deliberately unglamorous so its power is a discovery.

*Goblin Barracks* — spawns 2 goblins that block the path and fight in melee. The only trap that *stops* movement. Teaches "chokepoints."

*Boulder Chute* — high Siege damage, very slow fire rate, wide splash. Teaches "burst vs sustain."

**Tier 2 — unlocked over World 1**

*Poison Fungus* — Burn, stacks, cheap. Excellent vs high-HP knights.
*Arcane Obelisk* — Magic damage, pierces plate armor, expensive.
*Mimic Chest* — **[Bait]** Looks like treasure. High-greed heroes divert to open it and get chomped. Ignored by low-greed heroes.
*Portcullis* — **[Interdiction]** Slams shut in front of any hero carrying gold, blocking the exit for 5 seconds. Does nothing to heroes on the way in. The pure expression of the retrieval mechanic.

**Tier 3 — late unlocks**

*Cursed Brazier* — applies Weaken in an aura. The combo enabler.
*Gargoyle Perch* — flying unit that intercepts *only* flying/leaping heroes.
*Pendulum Blades* — sweeping physical damage across a corridor segment, hits everything in a line.
*Gold Pile (Decoy)* — **[Bait]** You place a chunk of your own hoard in a side room. Heroes detour to grab it instead of pushing to the vault. You are literally spending life total to buy positioning. If you kill them, you get it back.
*Cursed Idol* — **[Bait]** Heroes stop to pick it up, becoming stationary for 2s. A stun you have to *tempt* them into.
*Greed Curse* — **[Interdiction]** Gold-carrying heroes hit by this move at half speed and drop a coin every second. Turns a successful thief into a slow, bleeding piñata.

---

## 8. Enemy Roster (Heroes)

Every hero has **HP, Speed, Armor, Greed** (how much gold they steal) and **Discipline** (resistance to bait). High-greed heroes steal more but are easily distracted; disciplined heroes steal little but cannot be pulled off the path. That tension is the enemy design language.

**Basic**

*Squire* — weak, fast, packs. Greed: low. Discipline: low. The tutorial enemy and the trash-clear check.
*Knight* — plate armor, slow, high HP. Greed: high — steals a big stack. Teaches "physical is bad here" and "let this one out and it hurts."
*Rogue* — very fast, low HP, unarmored, **dodges the first hit of every trap**, and on the way out **moves 50% faster while carrying gold**. The single most dangerous thief in the game. Punishes players with no interdiction.
*Cleric* — heals nearby heroes. Greed: none — it steals nothing, it just keeps the thieves alive. The priority target.

**Advanced**

*Battlemage* — warded, ranged, **destroys your traps** as it walks. The first enemy that changes your build, not your placement.
*Shieldbearer* — projects a shield over heroes behind it; must be broken with Siege. Discipline: high — cannot be baited, so you must break the formation by baiting the *greedy* heroes out from behind it.
*Ranger* — leaps over one trap segment, in *both* directions. Requires vertical coverage / Gargoyles.
*Paladin* — plate + warded, slow, immense HP. Greed: **zero**, Discipline: **absolute**. It doesn't want your gold. It's here to kill your monsters and escort the thieves. The wall, and immune to every bait you own.
*Treasure Hunter* — low HP, no combat ability, **Greed: enormous**. Beelines for the vault ignoring everything, grabs a huge stack, and sprints for the exit. Trivially killable — *if* you have anything covering the return path. This is the enemy that teaches the whole mechanic, and it should show up in World 1.

**Bosses** (one per world, wave 10 or 20)

*The Hero of the Realm* — high HP, revives once at 50% HP unless killed by Magic damage. A designed puzzle, not a stat check.
*The Dwarven Sapper* — sprints straight for the Heart, ignores gold, must be burst down.
*The Archmage* — periodically disables a random trap for 8 seconds.

---

## 9. Levels & Progression

**Structure:** 4 worlds × 12 levels = 48 levels at launch, roughly 6–10 hours of first-clear content.

- **World 1 — The Cellar.** Single path, wide build area. Teaches the fundamentals *and the return trip* — the Treasure Hunter shows up in level 3 and robs you blind if you built entrance-only. 10 waves each.
- **World 2 — The Catacombs.** Branching paths, and the heroes now have a *second* exit route. Introduces Ranger and Shieldbearer, and makes bait genuinely necessary. 15 waves.
- **World 3 — The Molten Depths.** Environmental hazards (lava vents to push heroes into), limited build nodes — placement is genuinely scarce, so Interdiction traps have to earn their slot. 15 waves.
- **World 4 — The Sunken Vault.** Two entrances, **two separate hoards** to defend, Battlemages destroying traps. 20 waves.

**Endless Mode** unlocks after World 2: one map, infinite scaling waves, leaderboard ranked by gold defended. Cheap to build, huge retention value.

**Scoring:** 3 skulls = kept >90% of the hoard, 2 skulls = >60%, 1 skull = survived with anything left. Skulls gate world unlocks, softly encouraging replay with better Workshop upgrades rather than hard-walling the player.

### Kingdom Escalation — the villain's progression system

**The kingdom reacts to you.** This is the third structural pillar of the inversion, and it's a progression mechanic only the villain side can justify.

Every hero that **escapes with your gold** doesn't just cost you the coins. It survives, returns to town, spends your gold on better equipment, and **comes back stronger in a later level.** Escaped heroes are tracked persistently per world in a **Kingdom Roster**.

So a Squire that gets away with 20 gold in level 2 returns in level 5 as a **Veteran Squire** with better armor. Let it escape again and by level 9 it's a Knight-Captain leading a squad. Meanwhile a hero you *killed* is gone forever.

What this does:

*It gives permanent stakes to a single leaked hero,* which is exactly the emotional weight a "leak" should carry and almost never does in this genre.

*It creates a difficulty curve the player authored themselves.* A skilled player faces a weak kingdom. A sloppy player faces the army they funded. This is self-balancing — struggling players aren't punished into a wall, they're just facing the consequences they created, and the Workshop lets them catch up.

*It makes the villain fantasy real.* You are not defending against a scripted wave table. You are in a war with a kingdom that learns.

**Between-level screen:** "The Kingdom grows bolder." Shows escaped heroes, the gold they took, and what they've upgraded into. Optionally, you can spend Souls on a **Assassination** — hunt down an escaped hero in town and remove it from the roster before it returns. A villain move, and a pressure valve if the roster gets ugly.

**Design guardrail:** cap escalation so the roster can't death-spiral a player out of the game. Escaped heroes upgrade a maximum of 2 tiers, and the roster resets between worlds. This must be a *consequence*, not a punishment loop.

---

## 10. Economy

**Hoard gold (in-level)** — starts at a fixed amount per level. It is, simultaneously and by design, **four things**: your build currency, your health bar, your Allure rating, and your score. Spent on traps, stolen by heroes, recovered by killing thieves. Does not carry between levels.

That quadruple duty is the whole economic engine of the game. Spending gold buys you defense but costs you health, allies, and score. Hoarding gold buys you allies and score but leaves you undefended. There is no safe number — only a bet.

**Souls** — earned from level completion, scaled by gold defended. Spent in the Workshop on permanent trap upgrades, new tiers, and Assassinations. The progression currency.

**Gems** — premium. Sources: rare level rewards, achievements, purchase. Spent on cosmetics and Workshop shortcuts. **Never on power the player cannot otherwise earn.**

Tuning rule: a player who never spends money reaches the end of World 4 in roughly 12–15 hours. A spender skips grind, not skill.

---

## 11. Monetization

Recommended model: **free-to-play, ad-supported, with a single generous IAP.**

*Rewarded video ads* — optional, player-initiated only. "Watch an ad to double your Souls from this level," and — thematically perfect — **"Watch an ad to recover the gold that was just stolen from you."** The rewarded ad is fused to the core mechanic instead of bolted on. Never interstitials between levels; nothing kills a TD session faster than an unskippable ad after a hard-won victory.

*Remove Ads + Starter Pack* — one purchase, ~$4.99. Removes rewarded-ad *prompts* (keeping the rewards), grants a soul bundle and a cosmetic dungeon skin. This is the conversion workhorse.

*Cosmetic packs* — dungeon themes, trap skins, hero-death animations. ~$1.99–$4.99.

*Optional Season Pass* — post-launch, only if the game finds an audience. Do not build this for v1.

Explicitly rejected: energy/lives systems, timers on building, pay-to-win trap tiers, loot boxes. They will each raise short-term ARPU and each will cost you the store rating that actually drives installs.

---

## 12. UX & Controls

Portrait, one thumb. The bottom third is the trap tray (5 loadout slots, cost shown, greyed when unaffordable). The top strip shows **the Hoard counter** — the single most important number on screen — plus wave counter and the wave preview.

**The Hoard counter is the emotional center of the UI.** It must be large, gold, and animated. When you spend, coins fly *from* it into the trap. When a hero loots, coins visibly fly *out of the vault into the hero's hands*, and the counter drops with a sickening tick. When you kill a thief, the coins spill on the floor and *fly home* with a satisfying chime. The player should feel the number in their stomach.

**The Allure notches live on the Hoard counter itself.** Glowing marks at 40 / 60 / 80 / 95%, each with the icon of the monster it summons. As you drag a trap into place, the counter *previews the drop* — the bar visibly shows where you'll land and which notch you're about to fall below, with the threatened ally's portrait flashing red. The player must be able to see "this purchase costs me the Ogre" **before they commit,** not after. If they can't, the system is cruel instead of tense. This preview is not a nice-to-have; without it, Allure is a trap for the player rather than a decision.

**Carrying heroes are unmissable.** A looting hero gets a glowing gold aura, a coin icon over its head, a trail of sparkles, and a distinct sound. The UI should scream *THAT ONE HAS YOUR MONEY.* Optionally, a subtle desaturation of everything else while a thief is fleeing.

Tap a build node → radial menu of your 5 loadout traps, at thumb height, not under the finger. Tap a placed trap → Upgrade / Sell / Info. Pinch to zoom, drag to pan, sticky 2× speed toggle.

Haptics on kill, on gold recovered, and — hardest of all — **on gold stolen.** Theft should feel like a punch.

---

## 13. Art & Audio Direction

Chunky pixel art at a generous resolution (e.g. 32×32 tiles at integer scale) with modern lighting — torch glow, trap flashes, colored point lights. Reads well on a small bright screen, cheap to produce, dodges the uncanny valley of low-budget 3D.

**The vault must be the most beautiful thing on screen** — a glittering, animated pile of gold that *visibly shrinks as it's looted.* This is the highest-value art asset in the game. A player watching their gorgeous hoard become a sad little stack of three coins is the entire game in one image, and it's the screenshot that sells it.

Palette per world: Cellar warm brown/torchlight, Catacombs cold green/bone, Molten Depths orange/black, Sunken Vault deep blue/teal. Each identifiable from a 1-inch thumbnail.

Audio: a low, loopable ambient bed per world, punchy distinct SFX per trap. The two most important assets are **the theft sound** (heroes grabbing your gold — make it *awful*) and **the recovery chime** (coins coming home — make it *delicious*). Budget real effort on both.

Tone: dry, comedic villainy. Heroes shout heroic lines as they die and *smug* lines as they escape with your money ("For the realm! And for my retirement!"). Trap flavor text ("Mimic Chest: it's not entrapment if they *volunteer*."). Cheap personality, and it's what gets screenshots shared.

**Allies get the best writing in the game.** They're mercenaries and they don't respect you. The Ogre arriving should feel like a bouncer being paid. A deserting monster should be *insulting* about it — a Cave Troll glancing at your depleted vault, snorting, and lumbering off. That single animation does more for the game's voice than a page of dialogue, and it makes the player *furious* in exactly the right way.

---

## 14. Scope Discipline (the section that saves the project)

The biggest risk here is not technical, it's scope. Tower defense is a genre where the *first playable* takes a week and the *finished game* takes a year, and the gap is content, tuning and polish.

**Vertical slice first:** one map, three traps, two enemy types (one of them the Treasure Hunter), **one ally (the Goblin Pack) with one Allure threshold**, five waves, the full steal-and-flee loop, no meta-progression, no menus. That single threshold is enough to test whether the spend-vs-hoard dilemma is fun. Play it. If it isn't, no amount of content fixes it.

**Cut list, pre-authorized:** cut World 4 before cutting polish; cut Kingdom Escalation before cutting Allure; cut Allure's upper tiers before cutting Allure entirely; cut Endless Mode before cutting the Workshop. Ship 24 excellent levels rather than 48 mediocre ones.

**Do not cut:** the retrieval mechanic, the hoard-as-health-bar, the Allure preview UI, or the vault art. Those *are* the game.

---

## 15. Technical Notes (Godot 4, mobile)

Godot 4 exports to iOS and Android from one project. Practical constraints:

Use the **Mobile** or **Compatibility** renderer, not Forward+ — Forward+ is desktop-oriented and hurts battery and low-end Android. Compatibility (OpenGL/GLES3) is safest for 2D and maximizes device reach.

**Hero movement needs to run in reverse.** Use `Path2D` + `PathFollow2D` and drive `progress_ratio` — fleeing is simply negating the direction of travel. This is precisely why fixed paths are the right call: bidirectional movement on a fixed path is trivial, whereas bidirectional A* with dynamic bait targets is a genuine engineering problem. Do not write custom pathfinding for v1.

**Hero state machine:** `ADVANCING → LOOTING → FLEEING → ESCAPED`, plus `BAITED` as an interrupt from `ADVANCING`. Gold carried is a property on the hero; it's dropped as a pickup on death and returned to the vault, or removed from the run on `ESCAPED`. Keep this state machine clean — every interesting mechanic in the game hangs off it.

**The hoard is one number owned by one system.** Route every change through a single `EconomySystem` autoload emitting signals (`gold_spent`, `gold_stolen`, `gold_recovered`, `hoard_empty`, `allure_threshold_crossed`). The HUD, audio, haptics, Kingdom Roster and the Allure system all just listen. Do not let enemies mutate the hoard directly.

**Allure is a pure function of the hoard, evaluated at wave boundaries.** An `AllureSystem` reads the gold total at wave start, resolves which tiers are met (with the hysteresis buffer), spawns or dismisses allies, and then *does not re-evaluate mid-wave*. Keeping this evaluation on a strict tick — rather than reacting live to every coin — is what makes the guardrails in §5 actually hold, and it makes the whole thing far easier to reason about and debug.

**Allies are enemies with the sign flipped.** A monster ally is a mobile unit that pathfinds toward hostiles and attacks them. Reuse the hero state machine and combat code rather than writing a parallel system — target selection is the only real difference, plus a `pursue_thieves_first` priority flag that makes the Wyrmling chase whoever's carrying gold. Allies are the one place a little real pathfinding (`NavigationAgent2D`) is worth it, since they roam rather than follow the fixed path.

Object-pool enemies and projectiles from day one. Endless wave 20 will have hundreds of entities and `instantiate()`/`queue_free()` churn shows up as frame hitches on a mid-range Android phone.

Shipping to iOS requires a Mac (or cloud macOS runner) and a $99/year Apple Developer account. Google Play is $25 one-time. Note Google Play requires new personal developer accounts to run a closed test before production release — confirm the current rules when you get close, they've changed recently.

---

## 16. Open Questions

Before the vertical slice, five things want answering:

**Is watching gold leave more compelling than watching an HP bar drop, or just more stressful?** This is the bet the whole design rests on. Prototype it, play it for an hour, be honest. The failure mode is players feeling punished rather than challenged — if so, the fix is generosity in the *recovery* mechanic, not abandoning the concept.

**Does the return trip actually get played, or do players just build a kill-box at the entrance and never see it?** If most heroes die before reaching the vault, the entire retrieval layer is dead content. This may mean deliberately tuning hero HP *up* so that leakers are normal rather than a failure state. Big tuning philosophy call.

**Does Allure paralyze the player instead of tempting them?** This is the real risk. Gold now does four jobs, and every purchase has three costs — that's either delicious or it's decision paralysis and an unreadable economy. Watch for the tell: if playtesters stop building traps entirely because they're scared to spend, the thresholds are too punishing and need to be lower and further apart. The system should make spending *interesting*, not frightening.

**Is the 5-trap loadout cap right?** Maybe 4 (more agonizing) or 6 (more expressive). Playtest question, not a spreadsheet question.

**Does Kingdom Escalation feel like consequence or punishment?** If players read it as "the game kicks me while I'm down," make it opt-in (a difficulty modifier paying bonus Souls) rather than default. Note this risk compounds with Allure desertion — both systems punish the losing player. Watch that interaction closely; it may be that the game can only afford *one* of them.
