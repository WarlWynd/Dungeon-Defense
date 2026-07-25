extends RefCounted

## Procedural "juice" for a character drawn as a glyph (Tier 1 — no art): a
## footfall bob, a squash at contact, and a lean toward travel. Everything is
## computed in SCREEN space (world velocity is rotated by the unit's world
## rotation) so it reads the same in portrait and landscape.
##
## Preloaded via `const WalkMotion := preload(...)` rather than a global
## class_name, so a headless CLI run resolves it without an editor pass.
##
## One instance per unit: call update() each physics frame, then feed offset /
## rotation / scale into draw_set_transform + the glyph's centre in _draw.

var offset := Vector2.ZERO   ## screen-space bob, applied to the glyph centre
var rotation := 0.0          ## lean + step wobble, radians
var scale := Vector2.ONE     ## squash / stretch
var stride := 0.0            ## -1..1 leg swing (one foot forward / one back)

var _phase := 0.0
var _amp := 0.0              ## 0 idle .. 1 walking, smoothed
var _lean := 0.0
var _wobble := 0.0

## Tuned to actually READ as walking, not slide. A bodiless glyph looks like it's
## walking mainly from the side-to-side WOBBLE (the body rocking over each step)
## plus the vertical BOB; SQUASH sells the footfall weight, LEAN the direction.
const BOB := 0.22            ## bob height as a fraction of the unit radius
const SQUASH := 0.13
const WOBBLE := 0.14         ## step rock, radians
const LEAN_MAX := 0.12
const MOVE_EPS := 1.5        ## px/sec below which the unit counts as stopped —
                             ## low so a slow-drifting minion still strides


func update(delta: float, world_vel: Vector2, world_rot: float, radius: float) -> void:
	if delta <= 0.0:
		return
	var sv := world_vel.rotated(world_rot)   ## world velocity -> screen velocity
	var spd := sv.length()
	var walking := spd > MOVE_EPS
	_amp = lerpf(_amp, 1.0 if walking else 0.0, clampf(delta * 8.0, 0.0, 1.0))

	## Cadence scales gently with speed, so a sprint bobs faster than a creep. A
	## slow floor keeps the idle breathe alive when stopped.
	var rate := 7.0 + clampf(spd / 40.0, 0.0, 2.5) * 5.0
	_phase += delta * rate * maxf(_amp, 0.25)

	var b := sin(_phase)
	if _amp > 0.2:
		## Two footfalls per stride: the body rises on each (absf, twice a cycle),
		## then flattens (squash) at the contact between them, and rocks side to side
		## once per stride (b, the wobble) — the rock is what reads as "walking".
		offset = Vector2(0.0, -absf(b) * BOB * radius * _amp)
		var contact := (1.0 - absf(b)) * _amp
		scale = Vector2(1.0 + SQUASH * contact, 1.0 - SQUASH * contact)
		_wobble = b * WOBBLE * _amp
		## Legs swing at the stride frequency: one foot forward as the body rocks.
		stride = b * _amp
	else:
		## Idle: NOT frozen. A gentle breathe, a small weight-shift rock, and a soft
		## leg sway, so a parked minion still shows a small amount of movement.
		offset = Vector2.ZERO
		var breathe := b * 0.03
		scale = Vector2(1.0 - breathe, 1.0 + breathe)
		_wobble = b * 0.045
		stride = b * 0.28

	var target_lean := clampf(sv.x / 60.0, -1.0, 1.0) * LEAN_MAX * _amp
	_lean = lerpf(_lean, target_lean, clampf(delta * 10.0, 0.0, 1.0))
	rotation = _lean + _wobble
