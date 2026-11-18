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
	_plaque.text = "%s's house" % display_name
	_room_label.text = "%s's room" % display_name


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m


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

	_mesh(self, _box(Vector3(5, 3, 4)), Color(0.96, 0.9, 0.78), Vector3(0, 1.5, 0))
	var roof := PrismMesh.new()
	roof.size = Vector3(5.6, 1.8, 4.6)
	_mesh(self, roof, Color(0.75, 0.25, 0.2), Vector3(0, 3.9, 0))
	_mesh(self, _box(Vector3(1.1, 2.0, 0.12)), Color(0.45, 0.28, 0.15), Vector3(0, 1.0, -2.04))
	_mesh(self, _box(Vector3(0.8, 0.8, 0.12)), Color(0.6, 0.85, 0.95), Vector3(-1.6, 1.8, -2.04))
	_mesh(self, _box(Vector3(0.8, 0.8, 0.12)), Color(0.6, 0.85, 0.95), Vector3(1.6, 1.8, -2.04))

	_plaque = Label3D.new()
	_plaque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plaque.no_depth_test = true
	_plaque.pixel_size = 0.012
	_plaque.font_size = 40
	_plaque.outline_size = 8
	_plaque.position = Vector3(0, 5.6, 0)
	add_child(_plaque)


func _build_room(world: Node3D) -> void:
	var room := Node3D.new()
	room.position = Defs.room_center(slot)
	world.add_child(room)
	var half := Defs.ROOM_HALF + 0.5
	_mesh(room, _box(Vector3(half * 2, 0.2, half * 2)), Color(0.78, 0.6, 0.38), Vector3(0, -0.1, 0))
	var wall_color := Color(0.96, 0.9, 0.78)
	_mesh(room, _box(Vector3(half * 2, 1.2, 0.3)), wall_color, Vector3(0, 0.6, -half))  # back
	_mesh(room, _box(Vector3(0.3, 1.2, half * 2)), wall_color, Vector3(-half, 0.6, 0))  # left
	_mesh(room, _box(Vector3(0.3, 1.2, half * 2)), wall_color, Vector3(half, 0.6, 0))  # right
	_mesh(room, _box(Vector3(half - 1.2, 1.2, 0.3)), wall_color, Vector3(-(half + 1.2) / 2.0, 0.6, half))  # front left
	_mesh(room, _box(Vector3(half - 1.2, 1.2, 0.3)), wall_color, Vector3((half + 1.2) / 2.0, 0.6, half))  # front right
	_mesh(room, _box(Vector3(2.0, 0.04, 1.2)), Color(0.75, 0.2, 0.2), Vector3(0, 0.02, 5.5))  # door mat

	var exit_label := Label3D.new()
	exit_label.text = "Exit (F)"
	exit_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	exit_label.no_depth_test = true
	exit_label.pixel_size = 0.01
	exit_label.font_size = 36
	exit_label.outline_size = 8
	exit_label.position = Vector3(0, 1.6, 5.5)
	room.add_child(exit_label)

	_room_label = Label3D.new()
	_room_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_room_label.no_depth_test = true
	_room_label.pixel_size = 0.012
	_room_label.font_size = 44
	_room_label.outline_size = 8
	_room_label.position = Vector3(0, 2.6, -half)
	room.add_child(_room_label)
