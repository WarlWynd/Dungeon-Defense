extends Node
class_name WaveSpawner

## Deterministic waves — the player is allowed to learn them.

signal wave_finished()

var _container: Node2D

## Supplies each hero its [approach, escape] curve pair. Linear boards return
## the shared corridor; the maze returns a fresh random approach per hero.
var _route_provider: Callable

var _queue: Array[String] = []
var _timer: float = 0.0
var _spawning: bool = false

const SPAWN_INTERVAL := 0.75


func setup(container: Node2D, route_provider: Callable) -> void:
	_container = container
	_route_provider = route_provider


func start_wave(index: int) -> void:
	_queue.clear()
	var comp: Dictionary = GameData.WAVES[index]
	for key in comp.keys():
		var id: String = key
		var n: int = comp[id]
		for i in n:
			_queue.append(id)
	_timer = 0.0
	_spawning = true


func is_spawning() -> bool:
	return _spawning


func _process(delta: float) -> void:
	if not _spawning:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if _queue.is_empty():
		_spawning = false
		wave_finished.emit()
		return
	_spawn(_queue.pop_front())
	_timer = SPAWN_INTERVAL


func _spawn(id: String) -> void:
	var d: HeroData = GameData.heroes[id]
	var routes: Array = _route_provider.call()
	var hero := Hero.new()
	hero.setup(d, routes[0], routes[1])
	hero.add_to_group("heroes")
	_container.add_child(hero)
	EventBus.hero_spawned.emit(hero)
