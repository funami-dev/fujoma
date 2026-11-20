class_name Critters
extends Node3D
## Tiny round island folk with big eyes. They live in the boot, the stump, the crates and other
## nooks, waddle around carrying things, and scurry home when someone comes too close.
## Purely cosmetic: each client simulates its own critters.

const WALK_SPEED := 1.1
const FLEE_SPEED := 3.6
const SCARE_RADIUS := 3.5
const SAFE_RADIUS := 7.0
const WANDER_RADIUS := 4.5

const COLORS := [
	Color(0.62, 0.52, 0.42), Color(0.78, 0.68, 0.5), Color(0.55, 0.58, 0.6),
	Color(0.85, 0.72, 0.45), Color(0.6, 0.45, 0.4),
]
const CARRY := ["", "apple", "twig", "leaf", "hat", "", "apple"]

var _critters: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


## Builds a critter body (used for the wandering ones and for the static ones on props).
## carry: "", "apple", "twig", "leaf" (umbrella) or "hat".
static func build_body(color: Color, carry := "") -> Node3D:
	var root := Node3D.new()
	root.scale = Vector3.ONE * 1.6
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	Style.part(body, Style.ball(0.2, 12), color, Vector3(0, 0.24, 0), Vector3.ZERO).scale = Vector3(1, 1.1, 0.95)
	# Big eyes looking forward (-Z).
	for x in [-0.08, 0.08]:
		Style.part(body, Style.ball(0.07, 10), Color(0.98, 0.97, 0.94), Vector3(x, 0.3, -0.15))
		Style.part(body, Style.ball(0.035, 8), Style.INK, Vector3(x, 0.3, -0.21), Vector3.ZERO, {"outline": false})
	Style.part(body, Style.ball(0.03, 6), Color(0.85, 0.45, 0.4), Vector3(0, 0.22, -0.19), Vector3.ZERO, {"outline": false})
	for x in [-0.08, 0.08]:
		var foot := Style.part(root, Style.box(Vector3(0.08, 0.05, 0.12)), Color(0.35, 0.25, 0.18), Vector3(x, 0.03, -0.02))
		foot.name = "FootL" if x < 0.0 else "FootR"
	match carry:
		"apple":
			Style.part(body, Style.ball(0.09, 8), Color(0.86, 0.22, 0.15), Vector3(0.2, 0.2, -0.08))
		"twig":
			Style.part(body, Style.cyl(0.015, 0.02, 0.55, 5), Color(0.5, 0.35, 0.22), Vector3(0.17, 0.3, -0.05), Vector3(0.3, 0, 0.6))
		"leaf":
			Style.part(body, Style.cyl(0.012, 0.012, 0.45, 5), Color(0.4, 0.5, 0.25), Vector3(0.12, 0.55, 0))
			var leaf := Style.part(body, Style.ball(0.22, 10), Color(0.45, 0.62, 0.3), Vector3(0.12, 0.78, 0))
			leaf.scale = Vector3(1.2, 0.25, 1.0)
		"hat":
			Style.part(body, Style.cyl(0.0, 0.13, 0.3, 8), Color(0.8, 0.25, 0.2), Vector3(0, 0.55, 0), Vector3(0, 0, 0.15))
	return root


## homes: Array of {"pos": Vector3, "count": int}
func setup(homes: Array) -> void:
	_rng.seed = 2024
	for h: Dictionary in homes:
		for i in int(h["count"]):
			var color: Color = COLORS[_rng.randi() % COLORS.size()]
			var carry: String = CARRY[_rng.randi() % CARRY.size()]
			var node := build_body(color, carry)
			add_child(node)
			var home: Vector3 = h["pos"]
			node.position = home + Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5))
			var shout := Style.label3d("!", 56, 0.01)
			shout.position.y = 0.75
			shout.visible = false
			node.add_child(shout)
			_critters.append({
				"node": node, "home": home, "state": "pause", "timer": _rng.randf_range(0.5, 3.0),
				"target": node.position, "shout": shout, "shout_left": 0.0, "phase": _rng.randf() * TAU,
			})


func update(player_pos: Vector3, delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for c: Dictionary in _critters:
		var node: Node3D = c["node"]
		var home: Vector3 = c["home"]
		var to_player := player_pos.distance_to(node.position)
		var moving := false

		match c["state"]:
			"hidden":
				c["timer"] -= delta
				if c["timer"] <= 0.0 and player_pos.distance_to(home) > SAFE_RADIUS:
					node.visible = true
					node.position = home
					c["state"] = "pause"
					c["timer"] = _rng.randf_range(1.0, 3.0)
			"flee":
				moving = _step(node, home, FLEE_SPEED, delta)
				if not moving:
					node.visible = false
					c["state"] = "hidden"
					c["timer"] = 3.0
			"walk":
				if to_player < SCARE_RADIUS:
					_scare(c)
				else:
					moving = _step(node, c["target"], WALK_SPEED, delta)
					if not moving:
						c["state"] = "pause"
						c["timer"] = _rng.randf_range(1.5, 4.5)
			"pause":
				if to_player < SCARE_RADIUS:
					_scare(c)
				else:
					c["timer"] -= delta
					if c["timer"] <= 0.0:
						var a := _rng.randf() * TAU
						var target := home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.0, WANDER_RADIUS)
						var flat := Vector2(target.x, target.z)
						if flat.length() > 42.0:  # stay on the sand, out of the sea
							flat = flat.normalized() * 42.0
						c["target"] = Vector3(flat.x, 0, flat.y)
						c["state"] = "walk"

		# Waddle while moving, gentle breathing while standing.
		var body: Node3D = node.get_node("Body")
		var speed_t: float = t * (16.0 if c["state"] == "flee" else 11.0) + float(c["phase"])
		if moving:
			body.rotation.z = sin(speed_t) * 0.18
			body.position.y = absf(sin(speed_t)) * 0.05
			(node.get_node("FootL") as Node3D).position.y = 0.03 + maxf(0.0, sin(speed_t)) * 0.06
			(node.get_node("FootR") as Node3D).position.y = 0.03 + maxf(0.0, -sin(speed_t)) * 0.06
		else:
			body.rotation.z = lerpf(body.rotation.z, 0.0, minf(1.0, 8.0 * delta))
			body.position.y = sin(t * 2.0 + float(c["phase"])) * 0.01

		if c["shout_left"] > 0.0:
			c["shout_left"] -= delta
			if c["shout_left"] <= 0.0:
				(c["shout"] as Label3D).visible = false


func _scare(c: Dictionary) -> void:
	c["state"] = "flee"
	(c["shout"] as Label3D).visible = true
	c["shout_left"] = 0.8


## Moves toward `target`. Returns false once it has arrived.
func _step(node: Node3D, target: Vector3, speed: float, delta: float) -> bool:
	var d := target - node.position
	d.y = 0
	if d.length() < 0.15:
		return false
	var dir := d.normalized()
	node.position += dir * minf(speed * delta, d.length())
	node.rotation.y = lerp_angle(node.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, 12.0 * delta))
	return true
