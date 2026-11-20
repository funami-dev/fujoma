class_name Garden
extends Node3D
## Painted ground cells (paths, gravel, garden beds, ponds) and the plants growing on the beds.
## The server owns the state; this node mirrors it and draws it.

const GROUND_STYLE := {
	"path": {"color": Color(0.7, 0.67, 0.62), "height": 0.06, "outline": true, "inset": 0.06},
	"gravel": {"color": Color(0.86, 0.78, 0.62), "height": 0.035, "outline": false, "inset": 0.0},
	"soil": {"color": Color(0.42, 0.29, 0.2), "height": 0.12, "outline": true, "inset": 0.04},
	"pond": {"color": Color(0.42, 0.6, 0.7), "height": 0.03, "outline": false, "inset": 0.0},
}

var ground: Dictionary = {}  # Vector2i -> kind
var plants: Dictionary = {}  # Vector2i -> state Dictionary
var _plant_nodes: Dictionary = {}  # Vector2i -> Node3D
var _layers: Dictionary = {}  # kind -> MultiMeshInstance3D
var _dirty := false


func _ready() -> void:
	for kind: String in GROUND_STYLE:
		var st: Dictionary = GROUND_STYLE[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var size: float = 1.0 - float(st["inset"])
		mm.mesh = Style.box(Vector3(size, st["height"], size))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var opts := {"outline": st["outline"], "paper": 0.22}
		if kind == "pond":
			opts["color2"] = Color(0.36, 0.53, 0.66)
			opts["patch_scale"] = 0.6
		mmi.material_override = Style.mat(st["color"], opts)
		add_child(mmi)
		_layers[kind] = mmi


func load_state(ground_list: Array, plant_list: Array) -> void:
	ground.clear()
	for g: Array in ground_list:
		ground[Vector2i(int(g[0]), int(g[1]))] = g[2]
	for n: Node3D in _plant_nodes.values():
		n.queue_free()
	_plant_nodes.clear()
	plants.clear()
	for p: Dictionary in plant_list:
		set_plant(Vector2i(int(p["gx"]), int(p["gz"])), p)
	_dirty = true


func set_ground(cell: Vector2i, kind: Variant) -> void:
	if kind == null:
		ground.erase(cell)
	else:
		ground[cell] = kind
	_dirty = true


func ground_at(cell: Vector2i) -> String:
	return ground.get(cell, "grass")


func plant_at(cell: Vector2i) -> Dictionary:
	return plants.get(cell, {})


func set_plant(cell: Vector2i, p: Variant) -> void:
	if _plant_nodes.has(cell):
		(_plant_nodes[cell] as Node3D).queue_free()
		_plant_nodes.erase(cell)
	if p == null:
		plants.erase(cell)
		return
	plants[cell] = p
	var node := _build_plant(p)
	node.position = Vector3(cell.x, 0.12, cell.y)
	add_child(node)
	_plant_nodes[cell] = node


## Stage the server would report now: one step per watered day that has passed.
static func stage_of(p: Dictionary) -> int:
	var stage := int(p["stage"])
	var stages: int = Defs.PLANTS[p["kind"]]["stages"]
	if stage < stages and int(p["watered_day"]) >= int(p["stage_day"]) and int(p["watered_day"]) < IslandClock.day():
		stage += 1
	return stage


static func is_ripe(p: Dictionary) -> bool:
	return stage_of(p) >= int(Defs.PLANTS[p["kind"]]["stages"])


static func watered_today(p: Dictionary) -> bool:
	return int(p["watered_day"]) == IslandClock.day()


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_rebuild_ground()


func _rebuild_ground() -> void:
	var by_kind: Dictionary = {}
	for cell: Vector2i in ground:
		var kind: String = ground[cell]
		if not by_kind.has(kind):
			by_kind[kind] = []
		by_kind[kind].append(cell)
	for kind: String in _layers:
		var mm: MultiMesh = (_layers[kind] as MultiMeshInstance3D).multimesh
		var cells: Array = by_kind.get(kind, [])
		mm.instance_count = cells.size()
		var h: float = GROUND_STYLE[kind]["height"]
		for i in cells.size():
			var c: Vector2i = cells[i]
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(c.x, h / 2.0 - 0.005, c.y)))


# ---------------------------------------------------------------- plant visuals

func _build_plant(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	var kind: String = p["kind"]
	var stage := stage_of(p)
	var stages: int = Defs.PLANTS[kind]["stages"]
	var leaf := Color(0.4, 0.62, 0.3)
	if watered_today(p) and stage < stages:
		Style.part(root, Style.cyl(0.42, 0.42, 0.01, 12), Color(0.25, 0.17, 0.12), Vector3(0, 0.005, 0), Vector3.ZERO, {"outline": false})
	if stage == 0:
		Style.part(root, Style.ball(0.22, 10), Color(0.36, 0.25, 0.18), Vector3(0, 0, 0)).scale = Vector3(1, 0.35, 1)
		for i in 3:
			Style.part(root, Style.ball(0.03, 6), Color(0.85, 0.75, 0.5), Vector3(-0.08 + i * 0.08, 0.06, 0.02 * i), Vector3.ZERO, {"outline": false})
		return root
	if stage < stages:
		# Growing: a sprout that gets bigger with each stage.
		var s := 0.5 + 0.5 * float(stage) / float(stages)
		Style.part(root, Style.cyl(0.02, 0.025, 0.3 * s, 5), leaf, Vector3(0, 0.15 * s, 0))
		for a in [0.0, 2.1, 4.2]:
			var l := Style.part(root, Style.ball(0.14 * s, 8), leaf, Vector3(cos(a) * 0.12 * s, 0.22 * s, sin(a) * 0.12 * s))
			l.scale = Vector3(1.4, 0.4, 0.8)
			l.rotation.y = a
		if kind == "pumpkin" and stage == stages - 1:
			Style.part(root, Style.ball(0.16, 10), Color(0.5, 0.65, 0.3), Vector3(0.15, 0.1, 0.1))
		return root
	match kind:
		"carrot":
			for a in [0.0, 1.2, 2.4, 3.6, 4.8]:
				Style.part(root, Style.cyl(0.0, 0.05, 0.45, 5), Color(0.35, 0.6, 0.28), Vector3(cos(a) * 0.06, 0.25, sin(a) * 0.06), Vector3(cos(a) * 0.25, 0, sin(a) * 0.25))
			Style.part(root, Style.cyl(0.12, 0.0, 0.25, 8), Color(0.95, 0.5, 0.15), Vector3(0, 0.03, 0))
		"tomato":
			Style.part(root, Style.ball(0.35, 12), leaf, Vector3(0, 0.38, 0)).scale = Vector3(1, 1.15, 1)
			for q: Vector3 in [Vector3(0.28, 0.35, 0.12), Vector3(-0.22, 0.5, 0.2), Vector3(0.05, 0.62, -0.28), Vector3(-0.1, 0.25, -0.25)]:
				Style.part(root, Style.ball(0.09, 8), Color(0.88, 0.2, 0.15), q)
		"pumpkin":
			for a in [0.4, 2.3, 4.2]:
				var l := Style.part(root, Style.ball(0.2, 8), leaf, Vector3(cos(a) * 0.35, 0.05, sin(a) * 0.35))
				l.scale = Vector3(1.4, 0.3, 1.0)
			Style.part(root, Style.ball(0.36, 14), Color(0.93, 0.55, 0.2), Vector3(0, 0.22, 0)).scale = Vector3(1.1, 0.75, 1)
			Style.part(root, Style.cyl(0.03, 0.04, 0.14, 6), Color(0.35, 0.5, 0.25), Vector3(0, 0.52, 0))
		"tulip":
			var colors := [Color(0.9, 0.25, 0.3), Color(0.98, 0.8, 0.25), Color(0.95, 0.55, 0.75), Color(0.65, 0.4, 0.85)]
			var c: Color = colors[absi(int(p["gx"]) * 7 + int(p["gz"]) * 13) % colors.size()]
			Style.part(root, Style.cyl(0.015, 0.02, 0.5, 5), leaf, Vector3(0, 0.25, 0), Vector3.ZERO, {"outline": false})
			var l2 := Style.part(root, Style.ball(0.1, 8), leaf, Vector3(0.06, 0.15, 0))
			l2.scale = Vector3(0.6, 1.6, 0.3)
			Style.part(root, Style.ball(0.1, 10), c, Vector3(0, 0.55, 0)).scale = Vector3(1, 1.35, 1)
		"sunflower":
			Style.part(root, Style.cyl(0.03, 0.04, 1.4, 6), leaf, Vector3(0, 0.7, 0))
			for y in [0.45, 0.85]:
				var l3 := Style.part(root, Style.ball(0.14, 8), leaf, Vector3(0.12, y, 0))
				l3.scale = Vector3(1.5, 0.35, 0.9)
			var head := Node3D.new()
			head.position = Vector3(0, 1.45, -0.05)
			head.rotation.x = 0.35
			root.add_child(head)
			Style.part(head, Style.cyl(0.3, 0.3, 0.05, 14), Color(0.98, 0.8, 0.2), Vector3.ZERO, Vector3(PI / 2, 0, 0))
			Style.part(head, Style.cyl(0.14, 0.14, 0.07, 12), Color(0.45, 0.3, 0.18), Vector3(0, 0, -0.02), Vector3(PI / 2, 0, 0), {"outline": false})
	return root
