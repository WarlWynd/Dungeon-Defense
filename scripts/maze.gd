extends RefCounted
class_name Maze

## A branching dungeon: straight tunnels joined at right-angle junctions, some
## of which are DEAD ENDS. Built from a FIXED graph (authored in GameData), so
## the layout is the same every attempt and the player can learn where the
## junctions and the traps that guard them belong.
##
## Two very different journeys share this graph:
##
##   APPROACH (random) — a hero enters and does NOT know where the vault is.
##   It picks turns at random (a depth-first walk), blundering into dead ends
##   and backtracking, until it stumbles onto the gold. Every hero takes a
##   different route, so the approach is chaotic and unpredictable.
##
##   ESCAPE (optimal) — once it has the gold it knows the way, and it takes the
##   SHORTEST route to the exit. Every thief flees along the same corridor, so
##   the exit is predictable — and therefore defensible. Chaos in, order out.
##
## This is the whole reason fixed paths were the right call for v1: bidirectional
## movement and route-finding on a small fixed GRAPH is trivial; true A* over a
## dynamic space would not be.

var junctions: PackedVector2Array = PackedVector2Array()
var edges: Array = []              ## [[i, j], ...] — kept for drawing
var _adj: Dictionary = {}          ## node index -> Array[int] of neighbours
var entrance: int = 0
var vault: int = 0

var _escape_indices: Array = []    ## cached shortest vault -> entrance, node indices


func setup(points: Array, edge_list: Array, entrance_idx: int, vault_idx: int) -> void:
	for p in points:
		junctions.append(p)
	entrance = entrance_idx
	vault = vault_idx

	edges = edge_list.duplicate()
	for i in junctions.size():
		_adj[i] = []
	for e in edge_list:
		var a: int = e[0]
		var b: int = e[1]
		_adj[a].append(b)
		_adj[b].append(a)   ## tunnels are two-way

	_escape_indices = _shortest_path(vault, entrance)


func get_edges() -> Array:
	return edges


func neighbours(i: int) -> Array:
	return _adj.get(i, [])


func edge_count() -> int:
	var n := 0
	for i in _adj:
		n += _adj[i].size()
	return n / 2


## Dead ends: degree-1 nodes that aren't the entrance or the vault. Only used
## for drawing/telemetry — the player never sees this list.
func dead_ends() -> Array:
	var out := []
	for i in _adj:
		if _adj[i].size() == 1 and i != entrance and i != vault:
			out.append(i)
	return out


## A RANDOM route entrance -> vault, as world points. Depth-first with the
## neighbours visited in random order, backtracking out of dead ends. Because
## the graph is connected, this always finds the vault; because the order is
## random, (almost) every hero takes a different path.
func random_approach() -> PackedVector2Array:
	var order := _random_dfs(entrance, vault)
	return _to_points(order)


## The one true fastest way out, shared by every fleeing thief.
func escape_route() -> PackedVector2Array:
	return _to_points(_escape_indices)


# --- internals -------------------------------------------------------------

func _to_points(indices: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in indices:
		out.append(junctions[i])
	return out


## Random depth-first search returning the ACTUAL walked route (with the
## backtracking steps included), so a hero that explores a dead end really
## walks in and back out of it — the player sees the wasted trip.
func _random_dfs(start: int, goal: int) -> Array:
	var route := [start]
	var visited := {start: true}
	var stack := [start]

	while not stack.is_empty():
		var cur: int = stack[stack.size() - 1]
		if cur == goal:
			break

		## Unvisited neighbours, in random order.
		var options := []
		for nb in _adj[cur]:
			if not visited.has(nb):
				options.append(nb)

		if options.is_empty():
			## Dead end (or fully explored) — back up one step. The hero
			## physically walks back to the previous junction.
			stack.pop_back()
			if not stack.is_empty():
				route.append(stack[stack.size() - 1])
			continue

		var next: int = options[randi() % options.size()]
		visited[next] = true
		stack.append(next)
		route.append(next)

	return route


## Breadth-first shortest path (fewest junctions). Fine for a hand-authored
## graph of a dozen-odd nodes.
func _shortest_path(from: int, to: int) -> Array:
	var queue := [from]
	var came_from := {from: -1}

	while not queue.is_empty():
		var cur: int = queue.pop_front()
		if cur == to:
			break
		for nb in _adj[cur]:
			if not came_from.has(nb):
				came_from[nb] = cur
				queue.append(nb)

	if not came_from.has(to):
		return [from]   ## disconnected (shouldn't happen in an authored maze)

	var path := []
	var c: int = to
	while c != -1:
		path.push_front(c)
		c = came_from[c]
	return path


## A corridor route (world points) from `from` to `to` that stays on the tunnels
## instead of cutting through the stone. Hops onto the nearest corridor, walks the
## graph to the corridor nearest the destination, then steps off to the target.
func route_points(from: Vector2, to: Vector2) -> PackedVector2Array:
	if junctions.is_empty() or edges.is_empty():
		return PackedVector2Array([to])
	var ef := _nearest_edge(from)
	var et := _nearest_edge(to)
	## On the same tunnel already — just slide along it.
	if ef["a"] == et["a"] and ef["b"] == et["b"]:
		return PackedVector2Array([ef["q"], et["q"], to])
	var best_path: Array = []
	var best_len := INF
	for sa in [int(ef["a"]), int(ef["b"])]:
		for sb in [int(et["a"]), int(et["b"])]:
			var p := _shortest_path(sa, sb)
			var l: float = _path_length(p) \
					+ junctions[sa].distance_to(ef["q"]) \
					+ junctions[sb].distance_to(et["q"])
			if l < best_len:
				best_len = l
				best_path = p
	var out := PackedVector2Array()
	out.append(ef["q"])
	for i in best_path:
		out.append(junctions[i])
	out.append(et["q"])
	out.append(to)
	return out


## The closest point that lies ON the tunnels — used to keep a commanded unit's
## post on the path instead of out in the stone.
func nearest_path_point(p: Vector2) -> Vector2:
	if edges.is_empty():
		return p
	return _nearest_edge(p)["q"]


func _nearest_edge(p: Vector2) -> Dictionary:
	var best := {"a": 0, "b": 0, "q": p}
	var best_d := INF
	for e in edges:
		var a: int = e[0]
		var b: int = e[1]
		var q := _closest_on_segment(p, junctions[a], junctions[b])
		var d := p.distance_to(q)
		if d < best_d:
			best_d = d
			best = {"a": a, "b": b, "q": q}
	return best


func _closest_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var d2 := ab.length_squared()
	if d2 <= 0.0:
		return a
	var t := clampf((p - a).dot(ab) / d2, 0.0, 1.0)
	return a + ab * t


func _path_length(idx_path: Array) -> float:
	var l := 0.0
	for i in range(1, idx_path.size()):
		l += junctions[idx_path[i - 1]].distance_to(junctions[idx_path[i]])
	return l
