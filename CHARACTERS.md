# Characters — Living Roster

The working document for every unit in the game. This is where character discussions land; `scripts/autoload/game_data.gd` holds the numbers, and this holds the *reasons*.

**Rule of thumb for everything below:** every stat on a card must be able to change what the player builds. A stat that can't change a decision is decoration.

---

## The stat card

Every hero has ten numbers. Six of them are the ones that matter in a fight:

**Damage** — what it hits your minions for. `0` means pacifist: it ignores your monsters entirely and just runs (the Treasure Hunter). Anything above zero will stop and fight.

**Attack rate** — seconds between swings.

**Hit points** — how much punishment it absorbs.

**Movement speed**, and **flee speed** — how fast it walks in, and how fast it runs *out* once it has your gold. These are different numbers on purpose. Flee speed is the one that decides whether you can catch a thief.

**Greed** — how much gold it grabs from the vault. The single most important number on the card, because it's the only one that tells you what a leak actually *costs*.

And the three defences, which are three separate axes on purpose:

| Defence | Blunts | Answered by |
|---|---|---|
| **Armour** | Physical (spikes, crossbows, blades) | Magic, or Siege (which half-ignores armour) |
| **Magic defence** | Magic (poison, arcane, fire) | Physical |
| **Purity** | *Corruption* — charm, curses, weaken, bait | Raw damage, or higher charm power |

**Purity is not a damage stat.** It's the axis that has nothing to do with hurting things — it's whether a unit can be *tempted*.

**And it's a resistance *chance*, not a threshold.** 50% purity = a 50% chance to shrug off each charm attempt:

| Purity | Charm lands | Feel |
|---|---|---|
| 0% — Treasure Hunter | **100%** | Pure avarice. Always falls. |
| 20% — Squire | 80% | Usually falls. |
| 50% — Knight | **50%** | A coin flip. She can turn him; she can't *count* on it. |
| 100% — Paladin | 0% | Incorruptible. Never, not once. |

`P(charm) = (1 − purity) + (power − 0.5)`, where `power` is the corruptor's strength, baselined at 0.5. An upgraded Succubus at 0.7 power pushes straight through purity — the Knight becomes 70% charmable. That's the Workshop upgrade path.

**The cooldown is what makes probability work.** She re-rolls every 6 seconds, so across a long corridor a coin-flip target will *probably* fall — roughly 78% of the time over a typical approach. Not "immune", just **unreliable**. A single roll would feel arbitrary; repeated rolls are a probability the player can plan around.

> ⚠️ **Implementation trap (found and fixed):** the cooldown must be spent on the *attempt*, not on success. If it's only spent when the charm lands, she silently re-rolls every frame — 60 times a second — and a "50% chance" resolves in **35 milliseconds**. Purity would look implemented and mean nothing.

A failed charm shows a white flare on the hero. A 50% roll that fails silently is indistinguishable from a bug.

Three defences means three ways to attack, which means an enemy is never simply "hard" — it's hard *the wrong way*, and the player's job is working out which key fits which lock.

---

## Heroes (the raiders)

### Squire
`42 HP · 88 speed (flees 15% faster) · 6 dmg / 0.9s · 10% armour · 0% magic def · 20% purity · steals 25`

Cannon fodder with a sword and a dream. Weak, fast, never alone. Steals little — but a dozen squires is still 300 gold walking out of your front door.

*Design role:* the baseline. Everything else is measured against it.

### Treasure Hunter
`30 HP · 135 speed (flees 60% faster) · 0 dmg · 0% armour · 0% magic def · 0% purity · steals 160`

Not a warrior — a professional. Ignores your minions completely, beelines for the vault, grabs a fortune and *sprints* for the exit, faster out than in.

Trivially easy to kill. The catch: it'll already be *behind* your traps. If everything you own points at the entrance, this one robs you blind and you never touch it.

*Design role:* **teaches the return trip.** It's the enemy the whole steal-and-flee mechanic exists to justify, which is why it lands in wave 2.

### Knight
`130 HP · 58 speed (does not run) · 14 dmg / 1.1s · 75% armour · 0% magic def · 50% purity · steals 90`

A wall of consecrated steel. Slow, brutal, and it butchers your minions — a Knight kills a goblin in three seconds and shrugs off all three of them together.

*Design role:* **teaches the whole stat system at once.**
- 75% armour → your crossbow takes **22 seconds**. Physical damage is a trap.
- 0% magic defence → poison takes **9 seconds**. There is always an answer; it just isn't the obvious one.
- 50% purity → the Succubus is a **coin flip**. She can turn a Knight, but she can't rely on it — half the time he shrugs her off and keeps walking.

The armour is 75% rather than 60% deliberately. At 60% the physical/magic gap was only ~1.5×, which no player would ever *notice* — and an unnoticed lesson isn't a lesson.

### Paladin
`170 HP · 50 speed · 8 dmg / 1.4s · 50% armour · 60% magic def · 100% purity · blesses to 85% · steals 0`

**Not a bigger Knight — the opposite kind of problem.** This distinction is load-bearing:

| | Knight | Paladin |
|---|---|---|
| Damage | **12.7 dps** — butchers minions | 5.7 dps — barely fights |
| Armour | **75%** | 50% |
| Magic def | 0% | **60%** |
| Purity | 50% | **100%** |
| Counter | **Poison** (9s vs 22s) | **Physical** (14s vs 30s) |
| Wants your gold | Yes, 90 | **No. None.** |

The Knight is the **sword**: heavy armour, heavy damage, and poison is the key. The Paladin is the **shield**: soft, warded, and poison is exactly the *wrong* key. Together they punish a player who found one counter and stopped thinking.

**The aura is its whole identity.** It blesses every hero within range to 85% purity — so while a Paladin lives, your Succubus cannot charm *anyone in its shadow*. Not the squires, not even the Treasure Hunter sprinting out with 160 of your gold. She goes from "the reward for staying rich" to a wasted slot.

That makes it a **priority target, not a wall**. Kill the Paladin and the party it was escorting becomes seducible again, mid-wave. The blessing lapses within a frame of its death, and the halos wink out — you can *see* it happen.

*Design role:* turns **purity from a per-unit immunity flag into an actual system**. Before the Paladin, purity was arguably a Succubus-immunity checkbox wearing a costume. Now it propagates, and it can be *removed by play*.

---

## Minions (yours — attracted by the hoard, loyal to the pile)

### Goblin Pack — arrives at 50% hoard, never deserts
`3 × 40 HP · 7 dmg / 0.7s · chases thieves first`

They smelled the gold and let themselves in. They hunt whoever is *carrying* your gold, which makes them worth more than their damage suggests — a goblin that catches a fleeing thief just paid for itself.

*Design role:* the **safety net**. The one minion that never abandons you, so a losing player can't death-spiral out of the game.

### Succubus — arrives at 75% hoard, leaves below 65%
`55 HP · charm power 0.5 · 6s cooldown · 5s duration · fragile`

She has taste, and your hoard is the only thing in the dungeon that meets her standards.

She doesn't kill. She **charms**: a thief carrying your gold turns around and walks it back to your vault *for you*, then wanders off in a daze. Beaten only by purity — she works on the greedy, not the holy.

*Design role:* the reward for staying rich, and the clearest proof that Allure is a real system rather than a stat bonus.

---

## The counter-matrix (verified by simulation, not vibes)

Time-to-kill in seconds, single trap, continuous coverage:

| | Spike Pit (phys) | Crossbow (phys) | Poison Fungus (magic) |
|---|---|---|---|
| **Squire** | 3.0s | **2.0s** | 2.9s |
| **Treasure Hunter** | 1.9s | **1.3s** | 2.1s |
| **Knight** | 33.4s | 22.0s | **9.1s** |
| **Paladin** | 21.9s | **14.4s** | 29.7s |

Read the last two rows together — that's the whole design. The Knight's answer is magic; the Paladin's answer is physical. **The counter to one is the trap for the other.**

And poison is *not* a strict upgrade: it's worse than the crossbow against the Squire, and much worse against the Paladin. Counters must exist without being universally correct, or the choice evaporates.

---

## Open questions

**Does the Knight stall the game rather than threaten it?** 22 seconds under a crossbow is a long time on a small map. Watch for the failure mode where a Knight simply parks in your kill-box and nothing happens.

**Should minions have armour too?** They currently have none, so the defence system only exists on one side of the fight. Giving the Cave Troll armour would make it a genuine wall rather than a big HP bar.

**Heroes now kill minions — is Allure still worth it?** Untested. A Knight wave could wipe your Goblin Pack and Succubus in one go, which might make staying rich feel like a punishment rather than a reward.

**Is the Paladin's aura too punishing at 85%?** It's a hard shutdown of the Succubus, not a soft one. That's a strong read — but if wave 4 feels like "the game took my toy away," consider dropping the aura to ~0.55 so it only blocks charm on *already-fairly-pure* heroes, leaving the Treasure Hunter seducible.

**Purity now propagates — but it still only resists charm.** Bait, curses and Weaken don't exist yet. The stat is real now; it isn't yet *rich*.

---

## Not yet built (from the GDD)

Rogue, Cleric, Battlemage, Shieldbearer, Ranger, Paladin · bosses (Hero of the Realm, Dwarven Sapper, Archmage) · Cave Troll, Ogre Champion, Wyrmling.
