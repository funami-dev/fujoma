class_name WorldNode
extends Node3D
## A harvestable tree or rock. The server owns its cooldown; we only mirror it.

const COLLISION_RADIUS := {"tree": 0.9, "rock": 0.8}

var node_id := ""
var kind := ""
var _ready_at_ms := 0
var _fruit: Node3D
var _rock_mesh: MeshInstance3D


func setup(id: String, k: String, ready_in_ms: int) -> void:
	node_id = id
	kind = k
	set_ready_in(ready_in_ms)
	if kind == "tree":
		_build_tree()
	else:
		_build_rock()
	_refresh()


func is_ready() -> bool:
	return Time.get_ticks_msec() >= _ready_at_ms


func set_ready_in(ms: int) -> void:
	_ready_at_ms = Time.get_ticks_msec() + ms
	_refresh()


func collision_radius() -> float:
	return COLLISION_RADIUS[kind]


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	var ready := is_ready()
	if _fruit:
		_fruit.visible = ready
	if _rock_mesh:
		_rock_mesh.scale = Vector3.ONE if ready else Vector3(0.6, 0.6, 0.6)


func _mat(color: Color) -> Material:
	return Style.mat(color)


func _ball(radius: float, segments := 18) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = segments
	s.rings = segments / 2
	return s


func _build_tree() -> void:
	# Per-tree variation from the id, so every client draws the same tree.
	var rng := RandomNumberGenerator.new()
	rng.seed = node_id.hash()
	var greens := [Color(0.42, 0.6, 0.3), Color(0.36, 0.54, 0.3), Color(0.5, 0.62, 0.3), Color(0.4, 0.58, 0.36)]
	var green: Color = greens[rng.randi() % greens.size()]

	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.38
	cyl.height = 2.4
	cyl.radial_segments = 8
	trunk.mesh = cyl
	trunk.material_override = _mat(Color(0.52, 0.33, 0.22))
	trunk.position.y = 1.2
	trunk.rotation.z = rng.randf_range(-0.08, 0.08)
	add_child(trunk)

	# A lumpy crown from a few overlapping blobs.
	var blobs := [
		[1.4, Vector3(0, 3.2, 0)], [1.0, Vector3(0.9, 2.9, 0.3)],
		[1.05, Vector3(-0.8, 3.0, -0.3)], [0.9, Vector3(0.1, 4.0, 0.2)],
	]
	for b: Array in blobs:
		var crown := MeshInstance3D.new()
		crown.mesh = _ball(b[0] * rng.randf_range(0.9, 1.1))
		crown.material_override = _mat(green.lerp(Color(0.6, 0.66, 0.32), rng.randf() * 0.25))
		crown.position = b[1]
		add_child(crown)

	_fruit = Node3D.new()
	add_child(_fruit)
	for p: Vector3 in [Vector3(1.5, 2.9, 0.7), Vector3(-1.3, 3.2, 0.7), Vector3(0.3, 2.8, -1.4), Vector3(-0.5, 4.3, -0.7)]:
		var apple := MeshInstance3D.new()
		apple.mesh = _ball(0.2, 8)
		apple.material_override = _mat(Color(0.86, 0.22, 0.15))
		apple.position = p
		_fruit.add_child(apple)


func _build_rock() -> void:
	_rock_mesh = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.8
	s.height = 1.1
	s.radial_segments = 7  # few segments: a chunky, hand-carved look
	s.rings = 4
	_rock_mesh.mesh = s
	_rock_mesh.material_override = _mat(Color(0.64, 0.61, 0.56))
	_rock_mesh.position.y = 0.35
	_rock_mesh.rotation.y = float(node_id.hash() % 360)
	add_child(_rock_mesh)
