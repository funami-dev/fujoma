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


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m


func _build_tree() -> void:
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.3
	cyl.height = 2.0
	trunk.mesh = cyl
	trunk.material_override = _mat(Color(0.5, 0.33, 0.2))
	trunk.position.y = 1.0
	add_child(trunk)

	var crown := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.5
	sphere.height = 3.0
	crown.mesh = sphere
	crown.material_override = _mat(Color(0.2, 0.55, 0.25))
	crown.position.y = 3.2
	add_child(crown)

	_fruit = Node3D.new()
	add_child(_fruit)
	for p: Vector3 in [Vector3(1.1, 3.0, 0.5), Vector3(-0.9, 3.4, 0.9), Vector3(0.2, 2.6, -1.3), Vector3(-0.6, 3.8, -0.8)]:
		var apple := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.2
		s.height = 0.4
		apple.mesh = s
		apple.material_override = _mat(Color(0.85, 0.12, 0.12))
		apple.position = p
		_fruit.add_child(apple)


func _build_rock() -> void:
	_rock_mesh = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.8
	s.height = 1.1
	_rock_mesh.mesh = s
	_rock_mesh.material_override = _mat(Color(0.55, 0.55, 0.58))
	_rock_mesh.position.y = 0.4
	add_child(_rock_mesh)
