class_name HouseView
extends Node3D
## A guest's house: exterior on the island ring plus an interior room far away in the same world.

var slot := 0
var owner_id := ""
var owner_name := ""
var _plaque: Label3D
var _room_label: Label3D


func setup(house_slot: int, owner: String, display_name: String, parent: Node3D) -> void:
	slot = house_slot
	owner_id = owner
	parent.add_child(self)
	_build_exterior()
	_build_room(parent)
	set_owner_name(display_name)


func set_owner_name(display_name: String) -> void:
	owner_name = display_name
	_plaque.text = "Haus von %s" % display_name
	_room_label.text = "Zimmer von %s" % display_name


func _mat(color: Color) -> Material:
	return Style.mat(color)


func _mesh(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _build_exterior() -> void:
	position = Defs.house_center(slot)
	var to_center := -position.normalized()
	rotation.y = atan2(-to_center.x, -to_center.z)  # door (local -Z) faces the island center

	# Falu-red cottage with white corners and window frames, dark roof.
	var white := Color(0.96, 0.94, 0.88)
	_mesh(self, _box(Vector3(5, 3, 4)), Color(0.66, 0.22, 0.16), Vector3(0, 1.5, 0))
	for x in [-2.47, 2.47]:
		for z in [-1.97, 1.97]:
			_mesh(self, _box(Vector3(0.18, 3.0, 0.18)), white, Vector3(x, 1.5, z))
	var roof := PrismMesh.new()
	roof.size = Vector3(5.8, 1.9, 4.7)
	_mesh(self, roof, Color(0.33, 0.29, 0.28), Vector3(0, 3.95, 0))
	_mesh(self, _box(Vector3(0.4, 1.0, 0.4)), Color(0.55, 0.3, 0.22), Vector3(1.4, 4.3, 0.8))  # chimney
	_mesh(self, _box(Vector3(1.3, 2.2, 0.1)), white, Vector3(0, 1.1, -2.03))
	_mesh(self, _box(Vector3(1.05, 2.0, 0.12)), Color(0.3, 0.47, 0.5), Vector3(0, 1.0, -2.06))
	for x in [-1.6, 1.6]:
		_mesh(self, _box(Vector3(1.0, 1.0, 0.1)), white, Vector3(x, 1.8, -2.03))
		_mesh(self, _box(Vector3(0.75, 0.75, 0.12)), Color(0.72, 0.85, 0.88), Vector3(x, 1.8, -2.06))

	Style.smoke(self, Vector3(1.4, 4.95, 0.8))

	# Mailbox with a raised red flag, and a little picket fence along the sides.
	Style.part(self, Style.cyl(0.05, 0.05, 1.1, 6), Color(0.45, 0.31, 0.21), Vector3(2.0, 0.55, -3.2))
	Style.part(self, Style.box(Vector3(0.32, 0.3, 0.5)), Color(0.3, 0.47, 0.5), Vector3(2.0, 1.2, -3.2))
	Style.part(self, Style.box(Vector3(0.04, 0.28, 0.06)), Color(0.85, 0.25, 0.2), Vector3(2.18, 1.4, -3.05))
	for side in [-1.0, 1.0]:
		for i in 6:
			Style.part(self, Style.box(Vector3(0.08, 0.7, 0.08)), white, Vector3(side * 3.1, 0.35, -1.9 + i * 0.75))
		Style.part(self, Style.box(Vector3(0.05, 0.08, 3.9)), white, Vector3(side * 3.1, 0.5, 0.0), Vector3.ZERO, {"outline": false})

	_plaque = Style.label3d("", 40)
	_plaque.position = Vector3(0, 5.6, 0)
	add_child(_plaque)


func _build_room(world: Node3D) -> void:
	var room := Node3D.new()
	room.position = Defs.room_center(slot)
	world.add_child(room)
	var half := Defs.ROOM_HALF + 0.5
	_mesh(room, _box(Vector3(half * 2, 0.2, half * 2)), Color(0.74, 0.56, 0.36), Vector3(0, -0.1, 0))
	var wall_color := Color(0.95, 0.88, 0.72)
	_mesh(room, _box(Vector3(half * 2, 1.2, 0.3)), wall_color, Vector3(0, 0.6, -half))  # back
	_mesh(room, _box(Vector3(0.3, 1.2, half * 2)), wall_color, Vector3(-half, 0.6, 0))  # left
	_mesh(room, _box(Vector3(0.3, 1.2, half * 2)), wall_color, Vector3(half, 0.6, 0))  # right
	_mesh(room, _box(Vector3(half - 1.2, 1.2, 0.3)), wall_color, Vector3(-(half + 1.2) / 2.0, 0.6, half))  # front left
	_mesh(room, _box(Vector3(half - 1.2, 1.2, 0.3)), wall_color, Vector3((half + 1.2) / 2.0, 0.6, half))  # front right
	_mesh(room, _box(Vector3(2.0, 0.04, 1.2)), Color(0.75, 0.2, 0.2), Vector3(0, 0.02, 5.5))  # door mat

	var exit_label := Style.label3d("Ausgang", 36, 0.01)
	exit_label.position = Vector3(0, 1.6, 5.5)
	room.add_child(exit_label)

	_room_label = Style.label3d("", 44)
	_room_label.position = Vector3(0, 2.6, -half)
	room.add_child(_room_label)
