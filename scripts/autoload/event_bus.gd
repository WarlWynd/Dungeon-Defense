extends Node

## Global signal hub. HUD, audio, haptics and the Allure system all just listen
## here. Every signal is emitted/connected from OTHER scripts, which the linter
## can't see from inside an autoload — hence the unused_signal suppression.

@warning_ignore_start("unused_signal")

# --- The hoard ---
signal gold_spent(amount: int, new_total: int)
signal gold_stolen(amount: int, new_total: int, thief: Node)
signal gold_recovered(amount: int, new_total: int)
signal gold_plundered(amount: int, new_total: int)
signal hoard_changed(new_total: int)
signal hoard_empty()

# --- Units ---
signal hero_spawned(hero: Node)
signal hero_died(hero: Node, carried_gold: int)
signal hero_escaped(hero: Node, stolen_gold: int)
signal hero_charmed(hero: Node)

# --- Allure ---
signal minion_arrived(minion_data: MinionData)
signal minion_deserted(minion_data: MinionData)
signal minion_restless(minion_data: MinionData)
signal minion_reinforced(minion_data: MinionData, count: int)

# --- Flow ---
signal wave_started(index: int, total: int)
signal wave_cleared(index: int)
signal build_phase_started(seconds: float)
signal level_won(gold_remaining: int)
signal level_lost()

@warning_ignore_restore("unused_signal")
