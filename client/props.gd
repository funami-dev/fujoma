class_name Props
extends Node3D
## Quirky little scenes on the island: a bathtub garden, a scarecrow with a crow, laundry,
## a boot house, a pinwheel, a ladder to nowhere and more. Positions come from Defs.PROPS
## (the server keeps furniture out of them). Front (-Z) faces the island center.

const BEACH_RADIUS := 41.6

## Where critters live: {"pos": Vector3, "count": int}, filled while building.
var homes: Array = []

var _spinners: Array[Node3D] = []
var _swingers: Array[Node3D] = []
var _crow: Node3D
var _bird: Node3D
var _buoy: Node3D
var _sailboat: Node3D
var _time := 0.0

const WOOD := Color(0.6, 0.42, 0.27)
const DARK_WOOD := Color(0.45, 0.31, 0.21)
const CREAM := Color(0.95, 0.91, 0.8)


func _ready() -> void:
	for p: Array in Defs.PROPS:
		var pos2: Vector2 = p[1]
		var node := Node3D.new()
		node.position = Vector3(pos2.x, 0, pos2.y)
		var to_center := -node.position.normalized()
		node.rotation.y = atan2(-to_center.x, -to_center.z)
		node.scale = Vector3.ONE * float(p[3])  # storybook proportions: a bit oversized
		add_child(node)
		call("_build_" + p[0], node)
	_build_beach()


func _home(node: Node3D, local: Vector3, count: int) -> void:
	homes.append({"pos": node.to_global(local) if node.is_inside_tree() else node.transform * local, "count": count})


func _process(delta: float) -> void:
	_time += delta
	for s in _spinners:
		s.rotation.z += delta * 2.2
	for i in _swingers.size():
		_swingers[i].rotation.x = sin(_time * 1.7 + i * 1.3) * 0.25
	if _crow:
		_crow.rotation.y = sin(_time * 0.8) * 0.6
		_crow.position.y = 1.72 + maxf(0.0, sin(_time * 3.0)) * (0.12 if fmod(_time, 7.0) < 1.0 else 0.0)
	if _bird:
		# Peeks out of the teapot spout hole every few seconds.
		var peek := clampf(sin(_time * 0.9) * 3.0 - 1.5, 0.0, 1.0)
		_bird.position.z = lerpf(-0.12, -0.36, peek)
	if _buoy:
		_buoy.position.y = sin(_time * 1.3) * 0.15 - 0.4
		_buoy.rotation.z = sin(_time * 1.1) * 0.12
	if _sailboat:
		var a := _time * 0.025
		_sailboat.position = Vector3(cos(a) * 62.0, -0.45 + sin(_time * 1.2) * 0.08, sin(a) * 62.0)
		_sailboat.rotation.y = -a  # sails tangentially around the island
		_sailboat.rotation.z = sin(_time * 0.9) * 0.06


# ---------------------------------------------------------------- meadow props

func _build_bathtub(n: Node3D) -> void:
	Style.part(n, Style.box(Vector3(1.8, 0.6, 0.9)), Color(0.93, 0.93, 0.9), Vector3(0, 0.55, 0))
	Style.part(n, Style.box(Vector3(1.6, 0.06, 0.72)), Color(0.42, 0.3, 0.2), Vector3(0, 0.84, 0))
	for x in [-0.75, 0.75]:
		for z in [-0.32, 0.32]:
			Style.part(n, Style.ball(0.11, 8), Color(0.85, 0.7, 0.3), Vector3(x, 0.12, z))
	var flowers := [Color(0.95, 0.45, 0.5), Color(0.98, 0.85, 0.3), Color(0.65, 0.55, 0.95), Color(0.98, 0.98, 0.95)]
	for i in 7:
		var x := -0.6 + i * 0.2
		var z := 0.2 if i % 2 == 0 else -0.15
		Style.part(n, Style.cyl(0.015, 0.015, 0.45, 5), Color(0.35, 0.55, 0.25), Vector3(x, 1.05, z), Vector3.ZERO, {"outline": false})
		Style.part(n, Style.ball(0.09, 8), flowers[i % flowers.size()], Vector3(x, 1.3, z))
	# A rubber duck on the rim.
	Style.part(n, Style.ball(0.12, 8), Color(0.98, 0.85, 0.2), Vector3(0.75, 0.95, -0.3))
	Style.part(n, Style.ball(0.08, 8), Color(0.98, 0.85, 0.2), Vector3(0.75, 1.1, -0.38))
	Style.part(n, Style.cyl(0.0, 0.035, 0.08, 6), Color(0.95, 0.5, 0.15), Vector3(0.75, 1.09, -0.47), Vector3(PI / 2, 0, 0))
	_home(n, Vector3(1.4, 0, -0.6), 1)


func _build_signpost(n: Node3D) -> void:
	var post := Node3D.new()
	post.rotation.z = 0.08
	n.add_child(post)
	Style.part(post, Style.cyl(0.07, 0.08, 2.5, 8), DARK_WOOD, Vector3(0, 1.25, 0))
	var boards := [
		["To the Moon ->", 20.0, Color(0.95, 0.9, 0.75)],
		["<- Somewhere else", -65.0, Color(0.75, 0.85, 0.95)],
		["Tea time ->", 150.0, Color(0.95, 0.75, 0.7)],
		["Back soon!", 95.0, Color(0.85, 0.92, 0.75)],
	]
	for i in boards.size():
		var b: Array = boards[i]
		var arm := Node3D.new()
		arm.position = Vector3(0, 2.25 - i * 0.32, 0)
		arm.rotation_degrees.y = b[1]
		arm.rotation.z = (i % 2 - 0.5) * 0.12
		post.add_child(arm)
		Style.part(arm, Style.box(Vector3(1.25, 0.24, 0.05)), b[2], Vector3(0.55, 0, 0))
		for side in [-1.0, 1.0]:
			var label := Label3D.new()
			label.text = b[0]
			label.font = Style.font()
			label.font_size = 30
			label.pixel_size = 0.0055
			label.modulate = Style.TEXT_DARK
			label.outline_size = 0
			label.position = Vector3(0.55, 0, 0.03 * side)
			label.rotation.y = 0.0 if side > 0.0 else PI
			arm.add_child(label)


func _build_scarecrow(n: Node3D) -> void:
	Style.part(n, Style.cyl(0.05, 0.06, 2.2, 6), DARK_WOOD, Vector3(0, 1.1, 0))
	Style.part(n, Style.cyl(0.04, 0.04, 1.8, 6), DARK_WOOD, Vector3(0, 1.6, 0), Vector3(0, 0, PI / 2))
	Style.part(n, Style.box(Vector3(0.75, 0.7, 0.35)), Color(0.72, 0.32, 0.25), Vector3(0, 1.4, 0))
	Style.part(n, Style.box(Vector3(0.2, 0.2, 0.37)), Color(0.4, 0.5, 0.65), Vector3(0.15, 1.25, 0))  # patch
	Style.part(n, Style.ball(0.3, 12), Color(0.83, 0.71, 0.5), Vector3(0, 2.05, 0))
	for x in [-0.1, 0.1]:
		Style.part(n, Style.ball(0.04, 6), Style.INK, Vector3(x, 2.1, -0.27), Vector3.ZERO, {"outline": false})
	Style.part(n, Style.box(Vector3(0.22, 0.03, 0.02)), Style.INK, Vector3(0, 1.95, -0.28), Vector3(0, 0, 0.15), {"outline": false})
	Style.part(n, Style.cyl(0.4, 0.4, 0.04, 14), Color(0.3, 0.25, 0.22), Vector3(0, 2.3, 0), Vector3(0.1, 0, 0))
	Style.part(n, Style.cyl(0.2, 0.24, 0.32, 12), Color(0.3, 0.25, 0.22), Vector3(0, 2.46, 0.02))
	for x in [-0.95, 0.95]:
		Style.part(n, Style.cyl(0.0, 0.1, 0.3, 6), Color(0.92, 0.8, 0.4), Vector3(x, 1.6, 0), Vector3(0, 0, -signf(x) * PI / 2))
	# The crow sitting on the scarecrow's arm, looking around.
	_crow = Node3D.new()
	_crow.position = Vector3(0.75, 1.72, 0)
	n.add_child(_crow)
	Style.part(_crow, Style.ball(0.15, 10), Color(0.15, 0.14, 0.17), Vector3(0, 0.1, 0)).scale = Vector3(1, 0.9, 1.3)
	Style.part(_crow, Style.ball(0.09, 8), Color(0.15, 0.14, 0.17), Vector3(0, 0.25, -0.13))
	Style.part(_crow, Style.cyl(0.0, 0.04, 0.12, 6), Color(0.95, 0.65, 0.2), Vector3(0, 0.24, -0.25), Vector3(-PI / 2, 0, 0))
	Style.part(_crow, Style.ball(0.025, 6), Color.WHITE, Vector3(0.05, 0.28, -0.19), Vector3.ZERO, {"outline": false})


func _build_laundry(n: Node3D) -> void:
	for x in [-2.0, 2.0]:
		Style.part(n, Style.cyl(0.05, 0.06, 1.9, 6), DARK_WOOD, Vector3(x, 0.95, 0))
	Style.part(n, Style.cyl(0.01, 0.01, 4.0, 4), CREAM, Vector3(0, 1.82, 0), Vector3(0, 0, PI / 2), {"outline": false})
	var items := [
		[-1.4, Vector3(0.18, 0.5, 0.05), Color(0.85, 0.3, 0.3)],
		[-0.9, Vector3(0.18, 0.5, 0.05), Color(0.3, 0.5, 0.8)],
		[-0.2, Vector3(0.65, 0.6, 0.05), Color(0.95, 0.88, 0.5)],
		[0.6, Vector3(0.3, 0.9, 0.06), Color(0.95, 0.95, 0.92)],  # giant striped sock
		[1.4, Vector3(0.5, 0.35, 0.05), Color(0.55, 0.75, 0.5)],
	]
	for it: Array in items:
		var pivot := Node3D.new()
		pivot.position = Vector3(it[0], 1.82, 0)
		n.add_child(pivot)
		var size: Vector3 = it[1]
		Style.part(pivot, Style.box(size), it[2], Vector3(0, -size.y / 2.0, 0))
		if size.y > 0.8:
			for k in 3:
				Style.part(pivot, Style.box(Vector3(0.31, 0.1, 0.07)), Color(0.85, 0.3, 0.3), Vector3(0, -0.2 - k * 0.25, 0))
			Style.part(pivot, Style.box(Vector3(0.3, 0.22, 0.06)), Color(0.95, 0.95, 0.92), Vector3(-0.2, -0.82, 0))
		elif size.x < 0.2:
			Style.part(pivot, Style.box(Vector3(0.18, 0.1, 0.05)), it[2], Vector3(-0.08, -0.46, 0))
		_swingers.append(pivot)


func _build_boot_house(n: Node3D) -> void:
	var leather := Color(0.48, 0.32, 0.22)
	Style.part(n, Style.box(Vector3(1.7, 0.16, 3.1)), Color(0.25, 0.2, 0.17), Vector3(0, 0.08, -0.55))  # sole
	Style.part(n, Style.cyl(0.85, 0.95, 2.4, 14), leather, Vector3(0, 1.35, 0.4))  # shaft
	Style.part(n, Style.box(Vector3(1.6, 0.9, 1.8)), leather, Vector3(0, 0.6, -0.9))  # foot
	Style.part(n, Style.ball(0.8, 14), leather, Vector3(0, 0.55, -1.75)).scale = Vector3(1.0, 0.65, 1.0)  # toe
	# Laces across the front of the shaft.
	for i in 4:
		Style.part(n, Style.box(Vector3(0.8, 0.05, 0.05)), CREAM, Vector3(0, 1.2 + i * 0.3, -0.5), Vector3(0, 0, 0.35 if i % 2 == 0 else -0.35), {"outline": false})
	Style.part(n, Style.box(Vector3(0.48, 0.6, 0.06)), Color(0.3, 0.5, 0.45), Vector3(0, 0.45, -2.48))  # door
	Style.part(n, Style.ball(0.04, 6), Color(0.85, 0.7, 0.3), Vector3(0.15, 0.45, -2.52))
	Style.part(n, Style.cyl(0.18, 0.18, 0.05, 12), Color(0.98, 0.85, 0.45), Vector3(0.35, 1.9, -0.5), Vector3(PI / 2, 0, 0), {"emission": Color(0.4, 0.3, 0.1)})  # round window
	Style.part(n, Style.cyl(0.08, 0.08, 0.7, 8), Color(0.45, 0.45, 0.48), Vector3(0.4, 2.85, 0.6))  # stove pipe
	Style.smoke(n, Vector3(0.4, 3.25, 0.6))
	_home(n, Vector3(0, 0, -2.9), 2)


func _build_windmill(n: Node3D) -> void:
	Style.part(n, Style.cyl(0.05, 0.06, 2.6, 6), DARK_WOOD, Vector3(0, 1.3, 0))
	Style.part(n, Style.box(Vector3(0.06, 0.4, 0.5)), Color(0.85, 0.3, 0.3), Vector3(0, 2.6, 0.35))  # tail
	var rotor := Node3D.new()
	rotor.position = Vector3(0, 2.6, -0.12)
	n.add_child(rotor)
	Style.part(rotor, Style.ball(0.08, 8), Color(0.85, 0.7, 0.3), Vector3.ZERO)
	var colors := [Color(0.9, 0.35, 0.3), Color(0.98, 0.85, 0.35), Color(0.4, 0.6, 0.85)]
	for i in 6:
		var blade := Node3D.new()
		blade.rotation.z = i * TAU / 6.0
		rotor.add_child(blade)
		Style.part(blade, Style.box(Vector3(0.16, 0.6, 0.03)), colors[i % 3], Vector3(0, 0.38, 0), Vector3(0, 0.4, 0))
	_spinners.append(rotor)


func _build_ladder(n: Node3D) -> void:
	# A ladder leaning against absolutely nothing, with a critter enjoying the view on top.
	var ladder := Node3D.new()
	ladder.rotation.x = -0.32
	n.add_child(ladder)
	for x in [-0.3, 0.3]:
		Style.part(ladder, Style.box(Vector3(0.08, 3.4, 0.08)), WOOD, Vector3(x, 1.7, 0))
	for i in 8:
		Style.part(ladder, Style.box(Vector3(0.6, 0.05, 0.06)), WOOD, Vector3(0, 0.3 + i * 0.42, 0))
	var sitter := Critters.build_body(Color(0.78, 0.68, 0.5), "hat")
	sitter.scale = Vector3.ONE * 1.1  # the prop itself is already scaled up
	sitter.position = Vector3(0, 3.42, 0.05)
	ladder.add_child(sitter)


func _build_stump_house(n: Node3D) -> void:
	Style.part(n, Style.cyl(0.7, 0.88, 1.0, 14), Color(0.5, 0.34, 0.22), Vector3(0, 0.5, 0))
	Style.part(n, Style.cyl(0.66, 0.66, 0.03, 14), Color(0.85, 0.72, 0.48), Vector3(0, 1.01, 0), Vector3.ZERO, {"outline": false})
	Style.part(n, Style.box(Vector3(0.34, 0.5, 0.05)), Color(0.75, 0.25, 0.2), Vector3(0, 0.27, -0.84), Vector3(-0.1, 0, 0))
	Style.part(n, Style.box(Vector3(0.16, 0.16, 0.04)), Color(0.98, 0.85, 0.45), Vector3(0.42, 0.62, -0.6), Vector3(0, -0.6, 0), {"emission": Color(0.35, 0.25, 0.08)})
	Style.part(n, Style.box(Vector3(0.42, 0.02, 0.26)), Color(0.4, 0.55, 0.35), Vector3(0, 0.01, -1.08), Vector3.ZERO, {"outline": false})
	Style.part(n, Style.cyl(0.02, 0.03, 0.18, 6), CREAM, Vector3(-0.55, 0.09, -0.75))
	Style.part(n, Style.ball(0.13, 10), Color(0.8, 0.25, 0.2), Vector3(-0.55, 0.2, -0.75)).scale = Vector3(1, 0.55, 1)
	_home(n, Vector3(0, 0, -1.2), 2)


func _build_birdhouse(n: Node3D) -> void:
	Style.part(n, Style.cyl(0.05, 0.06, 1.8, 6), DARK_WOOD, Vector3(0, 0.9, 0))
	var pot_color := Color(0.6, 0.78, 0.85)
	Style.part(n, Style.ball(0.38, 14), pot_color, Vector3(0, 2.1, 0)).scale = Vector3(1, 0.85, 1)
	Style.part(n, Style.ball(0.14, 10), pot_color, Vector3(0, 2.42, 0))
	Style.part(n, Style.ball(0.05, 6), Color(0.85, 0.7, 0.3), Vector3(0, 2.56, 0))
	Style.part(n, Style.cyl(0.05, 0.09, 0.42, 8), pot_color, Vector3(0.38, 2.15, 0), Vector3(0, 0, -0.9))  # spout
	var handle := TorusMesh.new()
	handle.inner_radius = 0.11
	handle.outer_radius = 0.17
	Style.part(n, handle, pot_color, Vector3(-0.38, 2.12, 0), Vector3(PI / 2, 0, 0))
	for i in 5:
		var a := i * TAU / 5.0
		Style.part(n, Style.ball(0.045, 6), CREAM, Vector3(cos(a) * 0.36, 2.0, sin(a) * 0.36), Vector3.ZERO, {"outline": false})
	Style.part(n, Style.cyl(0.1, 0.1, 0.05, 10), Style.INK, Vector3(0, 2.12, -0.33), Vector3(PI / 2, 0, 0), {"outline": false})
	_bird = Node3D.new()
	_bird.position = Vector3(0, 2.12, -0.12)
	n.add_child(_bird)
	Style.part(_bird, Style.ball(0.09, 8), Color(0.98, 0.8, 0.3), Vector3.ZERO)
	Style.part(_bird, Style.cyl(0.0, 0.03, 0.08, 6), Color(0.95, 0.5, 0.15), Vector3(0, -0.01, -0.11), Vector3(-PI / 2, 0, 0))
	for x in [-0.04, 0.04]:
		Style.part(_bird, Style.ball(0.018, 6), Style.INK, Vector3(x, 0.03, -0.08), Vector3.ZERO, {"outline": false})


func _build_crates(n: Node3D) -> void:
	var crate := func(pos: Vector3, rot: float) -> void:
		Style.part(n, Style.box(Vector3(0.8, 0.8, 0.8)), WOOD, pos, Vector3(0, rot, 0))
		for k in [-0.2, 0.2]:
			Style.part(n, Style.box(Vector3(0.82, 0.06, 0.82)), DARK_WOOD, pos + Vector3(0, k, 0), Vector3(0, rot, 0), {"outline": false})
	crate.call(Vector3(-0.5, 0.4, 0.2), 0.1)
	crate.call(Vector3(0.45, 0.4, 0.3), -0.2)
	crate.call(Vector3(0.0, 1.2, 0.25), 0.3)
	Style.part(n, Style.cyl(0.36, 0.36, 0.9, 12), Color(0.55, 0.36, 0.22), Vector3(1.2, 0.45, -0.3))
	for y in [0.15, 0.75]:
		Style.part(n, Style.cyl(0.37, 0.37, 0.06, 12), Color(0.35, 0.33, 0.32), Vector3(1.2, y, -0.3), Vector3.ZERO, {"outline": false})
	Style.part(n, Style.ball(0.12, 8), Color(0.86, 0.22, 0.15), Vector3(0.05, 1.72, 0.2))
	_home(n, Vector3(0, 0, -0.9), 2)


func _build_mushroom_house(n: Node3D) -> void:
	Style.part(n, Style.cyl(0.38, 0.5, 1.4, 14), Color(0.95, 0.9, 0.78), Vector3(0, 0.7, 0))
	Style.part(n, Style.ball(1.2, 18), Color(0.82, 0.24, 0.18), Vector3(0, 1.55, 0)).scale = Vector3(1, 0.55, 1)
	var dots := [Vector3(0.5, 1.85, -0.6), Vector3(-0.6, 1.88, -0.4), Vector3(0.1, 2.1, -0.2), Vector3(0.8, 1.75, 0.3), Vector3(-0.4, 1.95, 0.6), Vector3(-0.9, 1.7, 0.1)]
	for d: Vector3 in dots:
		Style.part(n, Style.ball(0.13, 8), CREAM, d, Vector3.ZERO, {"outline": false}).scale = Vector3(1, 0.4, 1)
	Style.part(n, Style.box(Vector3(0.3, 0.5, 0.05)), Color(0.3, 0.45, 0.6), Vector3(0, 0.25, -0.47))
	Style.part(n, Style.cyl(0.09, 0.09, 0.04, 10), Color(0.98, 0.85, 0.45), Vector3(0.2, 0.85, -0.4), Vector3(PI / 2, 0, 0.3), {"emission": Color(0.35, 0.25, 0.08)})
	_home(n, Vector3(0, 0, -0.8), 1)


func _build_wheelbarrow(n: Node3D) -> void:
	var tray := Node3D.new()
	tray.position = Vector3(0, 0.55, 0)
	tray.rotation.x = 0.12
	n.add_child(tray)
	Style.part(tray, Style.box(Vector3(0.85, 0.35, 1.1)), Color(0.4, 0.55, 0.62), Vector3.ZERO)
	for x in [-0.3, 0.3]:
		Style.part(tray, Style.box(Vector3(0.06, 0.06, 1.0)), DARK_WOOD, Vector3(x, -0.15, 0.9))
	var wheel := TorusMesh.new()
	wheel.inner_radius = 0.14
	wheel.outer_radius = 0.24
	Style.part(n, wheel, Color(0.25, 0.22, 0.2), Vector3(0, 0.24, -0.65), Vector3(0, 0, PI / 2))
	Style.part(tray, Style.ball(0.32, 12), Color(0.92, 0.55, 0.2), Vector3(-0.1, 0.35, 0.05)).scale = Vector3(1.1, 0.8, 1)
	Style.part(tray, Style.cyl(0.03, 0.04, 0.12, 6), Color(0.35, 0.5, 0.25), Vector3(-0.1, 0.62, 0.05))
	# A critter taking a nap next to the pumpkin.
	var sleeper := Critters.build_body(Color(0.6, 0.45, 0.4))
	sleeper.scale = Vector3.ONE * 0.9
	sleeper.position = Vector3(0.22, 0.17, 0.25)
	sleeper.rotation.z = 0.5
	tray.add_child(sleeper)
	var zzz := Style.label3d("z z", 34, 0.009)
	zzz.position = Vector3(0.3, 0.8, 0.25)
	tray.add_child(zzz)


# ---------------------------------------------------------------- beach and sea

func _build_beach() -> void:
	# Upside-down rowboat on the sand, with a tiny door: another critter home.
	var boat := _beach_node(100.0, BEACH_RADIUS)
	Style.part(boat, Style.box(Vector3(2.8, 0.55, 1.2)), Color(0.4, 0.55, 0.68), Vector3(0, 0.28, 0))
	Style.part(boat, Style.box(Vector3(2.85, 0.1, 1.25)), CREAM, Vector3(0, 0.42, 0), Vector3.ZERO, {"outline": false})
	Style.part(boat, Style.box(Vector3(0.3, 0.32, 0.05)), Color(0.8, 0.3, 0.25), Vector3(0.6, 0.17, -0.62))
	Style.part(boat, Style.box(Vector3(0.08, 0.06, 1.9)), WOOD, Vector3(-0.3, 0.65, 0.4), Vector3(0.5, 0.4, 0))  # oar
	_home(boat, Vector3(0.6, 0, -1.0), 2)

	# Message in a bottle.
	var bottle := _beach_node(232.0, 40.8)
	Style.part(bottle, Style.cyl(0.09, 0.09, 0.36, 10), Color(0.45, 0.7, 0.5), Vector3(0, 0.09, 0), Vector3(PI / 2, 0, 0.4))
	Style.part(bottle, Style.cyl(0.035, 0.035, 0.08, 6), Color(0.7, 0.55, 0.35), Vector3(-0.09, 0.09, -0.2), Vector3(PI / 2, 0, 0.4))

	# A red-and-white buoy bobbing in the sea.
	_buoy = _beach_node(20.0, 52.0)
	for i in 3:
		Style.part(_buoy, Style.cyl(0.42, 0.45, 0.25, 12), Color(0.85, 0.25, 0.2) if i % 2 == 0 else CREAM, Vector3(0, 0.12 + i * 0.25, 0))
	Style.part(_buoy, Style.cyl(0.0, 0.3, 0.45, 10), Color(0.85, 0.25, 0.2), Vector3(0, 0.95, 0))

	# A little sailboat slowly circling the island.
	_sailboat = Node3D.new()
	add_child(_sailboat)
	Style.part(_sailboat, Style.box(Vector3(0.9, 0.45, 2.6)), Color(0.55, 0.36, 0.22), Vector3(0, 0.2, 0))
	Style.part(_sailboat, Style.cyl(0.05, 0.05, 2.8, 6), DARK_WOOD, Vector3(0, 1.8, 0.1))
	var sail := PrismMesh.new()
	sail.size = Vector3(0.05, 2.2, 1.6)
	Style.part(_sailboat, sail, CREAM, Vector3(0, 1.75, 0.6))
	Style.part(_sailboat, Style.box(Vector3(0.07, 0.25, 0.9)), Color(0.85, 0.3, 0.25), Vector3(0, 1.3, 0.55), Vector3.ZERO, {"outline": false})
	var skipper := Critters.build_body(Color(0.85, 0.72, 0.45), "hat")
	skipper.position = Vector3(0, 0.42, -0.6)
	_sailboat.add_child(skipper)


func _beach_node(angle_deg: float, radius: float) -> Node3D:
	var a := deg_to_rad(angle_deg)
	var node := Node3D.new()
	node.position = Vector3(cos(a) * radius, 0, sin(a) * radius)
	var to_center := -node.position.normalized()
	node.rotation.y = atan2(-to_center.x, -to_center.z)
	add_child(node)
	return node
