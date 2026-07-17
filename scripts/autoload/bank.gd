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

var souls: int = 0
var gems: int = 0
var _unlocked: Dictionary = {}          ## anti-hero id -> true (permanent)

const SAVE_PATH := "user://bank.cfg"

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
	_load()


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
	c.save(SAVE_PATH)


func _load() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK:
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


func watch_ad_for_gems() -> void:
	## STUB: show a rewarded ad via an ad SDK (AdMob, etc.), and on the
	## ad-completed callback call add_gems(AD_REWARD_GEMS).
	add_gems(AD_REWARD_GEMS)
