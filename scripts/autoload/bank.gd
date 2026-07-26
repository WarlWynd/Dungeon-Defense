extends Node

## META WALLET + STORE. Owns the two out-of-run currencies and the set of
## permanently-unlocked Anti-Heroes, all persisted to disk so they survive
## between runs:
##   SOULS — soft currency earned in-run from kills; recruits Anti-Heroes.
##   GEMS  — premium currency from real-money packs or rewarded ads; buys
##           Anti-Heroes directly and tops up Gold/Souls.
## Gold itself is the in-run hoard and lives in EconomySystem, not here.
##
## The real-money purchase and rewarded-ad calls are STUBBED (see bottom): they
## grant immediately so the whole flow is testable in-editor. Swap those bodies
## for a billing SDK (Google Play Billing / Apple StoreKit) and a rewarded-ad
## SDK (AdMob, etc.) when you wire up a real build.

signal souls_changed(total: int)
signal gems_changed(total: int)
signal roster_unlocked(id: String)
signal profile_changed(index: int)

var souls: int = 0
var gems: int = 0
var _unlocked: Dictionary = {}          ## anti-hero id -> true (permanent)

## SAVE SLOTS. Everything above is one CHARACTER's progress, so each slot is its
## own file and switching slots is just reading a different one. Settings owns
## which slot is active — it has to outlive Bank swapping its file out.
const PROFILE_COUNT := 3
const PROFILE_PATH := "user://player_%d.cfg"

## The pre-slots save. Migrated into slot 1 on first run so a character built
## before save slots existed isn't silently thrown away. Left on disk afterwards
## rather than deleted — it costs nothing and it's someone's progress.
const SAVE_PATH := "user://bank.cfg"

var profile: int = 0

## --- Store tuning ---
const GOLD_REFILL := 250                 ## gold added to the current hoard
const GEM_GOLD_COST := 5                 ## gems for one Gold refill
const SOULS_PACK := 25                   ## souls added
const GEM_SOULS_COST := 3                ## gems for one Souls pack
const AD_REWARD_GEMS := 5                ## gems granted per rewarded ad
const GEM_PACKS := {                     ## cash packs; price strings are display-only
	"small": {"gems": 100, "price": "$0.99"},
	"medium": {"gems": 550, "price": "$4.99"},
	"large": {"gems": 1200, "price": "$9.99"},
}


func _ready() -> void:
	profile = clampi(Settings.get_profile(), 0, PROFILE_COUNT - 1)
	_migrate_legacy()
	_load()


# --- Save slots ------------------------------------------------------------

func _path(index: int) -> String:
	return PROFILE_PATH % clampi(index, 0, PROFILE_COUNT - 1)


func profile_exists(index: int) -> bool:
	return FileAccess.file_exists(_path(index))


## What's in a slot, WITHOUT loading it — the tab needs to describe all three at
## once. The live slot answers from memory, since that's the newest truth.
func profile_summary(index: int) -> Dictionary:
	if index == profile:
		return {"exists": profile_exists(index), "souls": souls, "gems": gems,
				"unlocked": _unlocked.size()}
	var c := ConfigFile.new()
	if c.load(_path(index)) != OK:
		return {"exists": false, "souls": 0, "gems": 0, "unlocked": 0}
	var list: Array = c.get_value("roster", "unlocked", [])
	return {"exists": true, "souls": int(c.get_value("wallet", "souls", 0)),
			"gems": int(c.get_value("wallet", "gems", 0)), "unlocked": list.size()}


## Play an existing slot. Nothing is written on the way out — every mutation
## already saved itself, so the slot being left is on disk and current.
func use_profile(index: int) -> void:
	profile = clampi(index, 0, PROFILE_COUNT - 1)
	Settings.set_profile(profile)
	_load()
	profile_changed.emit(profile)
	souls_changed.emit(souls)
	gems_changed.emit(gems)


## Start a fresh character in a slot: no souls, no gems, nothing unlocked. Wipes
## whatever was there, so the caller is responsible for meaning it.
func new_profile(index: int) -> void:
	profile = clampi(index, 0, PROFILE_COUNT - 1)
	Settings.set_profile(profile)
	souls = 0
	gems = 0
	_unlocked.clear()
	_save()
	profile_changed.emit(profile)
	souls_changed.emit(souls)
	gems_changed.emit(gems)


## Delete a slot's file. Erasing the slot you're playing leaves you on it, empty
## — the same state as a new character, minus the file until something is earned.
func erase_profile(index: int) -> void:
	var idx := clampi(index, 0, PROFILE_COUNT - 1)
	if profile_exists(idx):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(idx)))
	if idx == profile:
		souls = 0
		gems = 0
		_unlocked.clear()
		profile_changed.emit(profile)
		souls_changed.emit(souls)
		gems_changed.emit(gems)


## One-time move of the pre-slots save into slot 1. Only runs when that slot has
## no file of its own, so it can never overwrite a real character.
func _migrate_legacy() -> void:
	if not FileAccess.file_exists(SAVE_PATH) or profile_exists(0):
		return
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK:
		return
	c.save(_path(0))


# --- Souls -----------------------------------------------------------------

func add_souls(n: int) -> void:
	if n <= 0:
		return
	souls += n
	_save()
	souls_changed.emit(souls)


func spend_souls(n: int) -> bool:
	if souls < n:
		return false
	souls -= n
	_save()
	souls_changed.emit(souls)
	return true


func can_afford_souls(n: int) -> bool:
	return souls >= n


# --- Gems ------------------------------------------------------------------

func add_gems(n: int) -> void:
	if n <= 0:
		return
	gems += n
	_save()
	gems_changed.emit(gems)


func spend_gems(n: int) -> bool:
	if gems < n:
		return false
	gems -= n
	_save()
	gems_changed.emit(gems)
	return true


func can_afford_gems(n: int) -> bool:
	return gems >= n


# --- Unlocks ---------------------------------------------------------------

func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func unlock(id: String) -> void:
	if _unlocked.has(id):
		return
	_unlocked[id] = true
	_save()
	roster_unlocked.emit(id)


# --- Persistence -----------------------------------------------------------

func _save() -> void:
	var c := ConfigFile.new()
	c.set_value("wallet", "souls", souls)
	c.set_value("wallet", "gems", gems)
	c.set_value("roster", "unlocked", _unlocked.keys())
	c.save(_path(profile))


## Reads the ACTIVE slot, and clears first — switching characters has to drop the
## previous one's souls and unlocks, or a new player inherits them.
func _load() -> void:
	souls = 0
	gems = 0
	_unlocked.clear()
	var c := ConfigFile.new()
	if c.load(_path(profile)) != OK:
		return
	souls = int(c.get_value("wallet", "souls", 0))
	gems = int(c.get_value("wallet", "gems", 0))
	for id in c.get_value("roster", "unlocked", []):
		_unlocked[id] = true


# --- Real-money purchases & rewarded ads (STUBBED) -------------------------
# Replace the bodies below with real SDK calls. Keep the add_gems() grant on the
# SDK's success/verified callback so the wallet only credits on a real purchase
# or a fully-watched ad. The rest of the game already listens to gems_changed.

func purchase_gems(pack_id: String) -> void:
	## STUB: kick off a real IAP here (Google Play Billing / Apple StoreKit),
	## and on a verified purchase call add_gems(GEM_PACKS[pack_id]["gems"]).
	if GEM_PACKS.has(pack_id):
		add_gems(int(GEM_PACKS[pack_id]["gems"]))


## Called on ad COMPLETION, not on the button press — the Hud plays a simulated
## rewarded ad first (see Hud._build_ad_panel) and only reaches here if the player
## sat through it. Skipping early never calls this, which is the behaviour a real
## rewarded-ad SDK has.
func watch_ad_for_gems() -> void:
	## STUB: replace the simulated ad with a real rewarded ad (AdMob, etc.) and
	## call this from its ad-completed callback.
	add_gems(AD_REWARD_GEMS)
