class_name DecorNode
extends Node3D
## A placed piece of furniture (simple primitive shapes). Forward is -Z, rotation is in quarter turns.

var decor_id := ""
var item := ""
var rot := 0
var gx := 0
var gz := 0
var _meshes: Array[MeshInstance3D] = []


func setup(id: String, item_name: String, quarter_turns: int, cell_x: int, cell_z: int) -> void:
	decor_id = id
	item = item_name
	gx = cell_x
	gz = cell_z
	position = Vector3(gx, 0, gz)
	set_rot(quarter_turns)
	_build()


func set_rot(quarter_turns: int) -> void:
	rot = quarter_turns
	rotation.y = rot * PI / 2.0


## Turns this node into a translucent placement preview.
func set_ghost(valid: bool) -> void:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.3, 1.0, 0.4, 0.55) if valid else Color(1.0, 0.3, 0.3, 0.55)
	for mi in _meshes:
		mi.material_override = m


func _part(mesh: Mesh, color: Color, pos: Vector3, emissive := false) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.5
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	_meshes.append(mi)


func _light(color: Color, pos: Vector3) -> void:
	if decor_id == "ghost":
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 1.2
	l.omni_range = 5.0
	l.position = pos
	add_child(l)


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _cyl(radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	return c


func _ball(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	return s


func _build() -> void:
	var wood := Color(0.62, 0.42, 0.24)
	match item:
		"chair":
			_part(_box(Vector3(0.6, 0.1, 0.6)), wood, Vector3(0, 0.45, 0))
			_part(_box(Vector3(0.6, 0.6, 0.1)), wood, Vector3(0, 0.8, 0.25))
			for x in [-0.25, 0.25]:
				for z in [-0.25, 0.25]:
					_part(_box(Vector3(0.08, 0.45, 0.08)), wood, Vector3(x, 0.22, z))
		"table":
			_part(_box(Vector3(0.95, 0.08, 0.95)), wood, Vector3(0, 0.75, 0))
			for x in [-0.4, 0.4]:
				for z in [-0.4, 0.4]:
					_part(_box(Vector3(0.1, 0.72, 0.1)), wood, Vector3(x, 0.36, z))
		"lamp":
			_part(_cyl(0.05, 1.3), Color(0.3, 0.3, 0.3), Vector3(0, 0.65, 0))
			_part(_ball(0.25), Color(1.0, 0.9, 0.5), Vector3(0, 1.4, 0), true)
			_light(Color(1.0, 0.85, 0.55), Vector3(0, 1.4, 0))
		"bed":
			_part(_box(Vector3(0.9, 0.3, 1.0)), wood, Vector3(0, 0.25, 0))
			_part(_box(Vector3(0.8, 0.15, 0.7)), Color(0.4, 0.55, 0.9), Vector3(0, 0.46, 0.1))
			_part(_box(Vector3(0.6, 0.12, 0.25)), Color(0.95, 0.95, 0.95), Vector3(0, 0.55, -0.35))
		"campfire":
			for i in 6:
				var a := i * TAU / 6.0
				_part(_ball(0.14), Color(0.5, 0.5, 0.52), Vector3(cos(a) * 0.4, 0.12, sin(a) * 0.4))
			var flame := CylinderMesh.new()
			flame.top_radius = 0.02
			flame.bottom_radius = 0.25
			flame.height = 0.7
			_part(flame, Color(1.0, 0.5, 0.1), Vector3(0, 0.4, 0), true)
			_light(Color(1.0, 0.55, 0.2), Vector3(0, 0.8, 0))
		"fruit_basket":
			_part(_cyl(0.3, 0.25), Color(0.7, 0.5, 0.25), Vector3(0, 0.12, 0))
			for p: Vector3 in [Vector3(-0.1, 0.32, 0), Vector3(0.12, 0.3, 0.05), Vector3(0, 0.34, -0.12)]:
				_part(_ball(0.1), Color(0.85, 0.15, 0.15), p)
		"flower_pot":
			_part(_cyl(0.22, 0.35), Color(0.78, 0.4, 0.28), Vector3(0, 0.17, 0))
			_part(_cyl(0.02, 0.4), Color(0.2, 0.55, 0.25), Vector3(0, 0.55, 0))
			_part(_ball(0.16), Color(0.95, 0.4, 0.65), Vector3(0, 0.78, 0))
		_:
			_part(_box(Vector3(0.6, 0.6, 0.6)), Color(0.7, 0.2, 0.7), Vector3(0, 0.3, 0))
