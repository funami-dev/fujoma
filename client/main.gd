extends Node3D
## Phase 1: shared island. Walk around, see other players live, chat and emote.

const PROD_SERVER := "wss://fujoma-server.dw-a6b.workers.dev"
const ISLAND_RADIUS := 40.0
const SPEED := 6.0
const POS_SEND_INTERVAL := 0.1
const REMOTE_SMOOTHING := 12.0
const CAMERA_OFFSET := Vector3(0, 9, 10)
const EMOTES := ["wave", "happy", "sad", "dance"]

var island_code := "main"
var server_url := PROD_SERVER
var guest_id := ""
var guest_secret := ""
var guest_name := ""
var guest_color := Color.WHITE

var net: Net
var me: Avatar
var remotes: Dictionary = {}  # id -> Avatar
var camera: Camera3D
var world_env: Environment
var sun: DirectionalLight3D
var villagers: Villagers
var props: Props
var critters: Critters
var shop_sign: Label3D
var _daylight_timer := 0.0
var cam_yaw := 0.0
var _send_timer := 0.0
var _last_sent := Vector3.INF

var status_label: Label
var chat_log: RichTextLabel
var chat_input: LineEdit
var joystick: Joystick
var hud: Hud
var nodes: Dictionary = {}  # id -> WorldNode
var houses: Dictionary = {}  # owner id -> HouseView
var decor_nodes: Dictionary = {}  # decor id -> DecorNode
var build_rot := 0
var ghost: DecorNode
var _ghost_key := ""
var _touch_dir := Vector2.ZERO


func _ready() -> void:
	ThemeDB.fallback_font = Style.font()
	_read_params()
	_load_or_create_guest()
	_setup_input()
	_build_world()
	_build_ui()

	me = _spawn_avatar(guest_id, guest_name, guest_color)
	add_child(me)

	net = Net.new()
	add_child(net)
	net.connected.connect(_on_connected)
	net.disconnected.connect(_on_disconnected)
	net.message.connect(_on_message)
	net.rejected.connect(_on_rejected)
	status_label.text = "connecting..."
	net.open("%s/island/%s/ws" % [server_url, island_code])


# ---------------------------------------------------------------- identity

func _read_params() -> void:
	if not OS.has_feature("web"):
		return
	var code: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('island') || ''")
	if code is String and (code as String).is_valid_identifier():
		island_code = code
	var hour_param: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('hour') || ''")
	if hour_param is String and (hour_param as String).is_valid_float():
		IslandClock.override_hour = clampf(float(hour_param), 0.0, 23.99)
	var server: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('server') || ''")
	if server is String and (server as String).begins_with("ws"):
		server_url = server


func _load_or_create_guest() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://guest.cfg")
	guest_id = cfg.get_value("guest", "id", "")
	guest_secret = cfg.get_value("guest", "secret", "")
	if guest_secret == "":
		guest_secret = _random_token(24)
		cfg.set_value("guest", "secret", guest_secret)
		cfg.save("user://guest.cfg")
	if guest_id == "":
		guest_id = "%08x%08x" % [randi(), randi()]
		cfg.set_value("guest", "id", guest_id)
		cfg.set_value("guest", "name", "Guest%d" % (randi() % 10000))
		cfg.set_value("guest", "color", Color.from_hsv(randf(), 0.6, 0.95).to_html(false))
		cfg.save("user://guest.cfg")
	guest_name = cfg.get_value("guest", "name", "Guest")
	guest_color = Color.html(cfg.get_value("guest", "color", "ffffff"))
	if OS.has_feature("web"):
		var name_param: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('name') || ''")
		if name_param is String and name_param != "":
			guest_name = (name_param as String).substr(0, 16)


func _random_token(length: int) -> String:
	var chars := "abcdefghijklmnopqrstuvwxyz0123456789"
	var out := ""
	for i in length:
		out += chars[randi() % chars.length()]
	return out


# ---------------------------------------------------------------- setup

func _setup_input() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"cam_left": [KEY_Q],
		"cam_right": [KEY_E],
		"act": [KEY_F],
		"craft": [KEY_C],
	}
	for action: String in bindings:
		InputMap.add_action(action)
		for key: int in bindings[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	world_env = e
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.53, 0.81, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.75, 0.85)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	add_child(sun)

	_build_shop_stall()
	villagers = Villagers.new()
	add_child(villagers)
	props = Props.new()
	add_child(props)
	critters = Critters.new()
	add_child(critters)
	critters.setup(props.homes)

	_add_mesh(_cylinder(ISLAND_RADIUS + 3.0, 2.0), Color(0.9, 0.8, 0.58), Vector3(0, -1.05, 0), {"paper": 0.2})  # sand
	_add_mesh(_cylinder(ISLAND_RADIUS, 2.0), Color(0.54, 0.62, 0.36), Vector3(0, -1.0, 0),
			{"color2": Color(0.45, 0.55, 0.3), "patch_scale": 0.09, "paper": 0.18})  # meadow

	var water := PlaneMesh.new()
	water.size = Vector2(400, 400)
	_add_mesh(water, Color(0.45, 0.62, 0.7), Vector3(0, -0.6, 0),
			{"color2": Color(0.4, 0.56, 0.66), "patch_scale": 0.05, "paper": 0.22, "outline": false})
	_scatter_meadow()

	camera = Camera3D.new()
	camera.fov = 60.0
	camera.current = true
	add_child(camera)


func _cylinder(radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	return c


func _mat(color: Color, opts := {}) -> Material:
	return Style.mat(color, opts)


func _add_mesh(mesh: Mesh, color: Color, pos: Vector3, opts := {}) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, opts)
	mi.position = pos
	add_child(mi)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	status_label = Label.new()
	status_label.position = Vector2(12, 8)
	layer.add_child(status_label)

	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = false
	chat_log.scroll_following = true
	chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_log.anchor_top = 1.0
	chat_log.anchor_bottom = 1.0
	chat_log.offset_left = 12
	chat_log.offset_top = -240
	chat_log.offset_right = 420
	chat_log.offset_bottom = -52
	layer.add_child(chat_log)

	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Press Enter to chat"
	chat_input.max_length = 120
	chat_input.anchor_top = 1.0
	chat_input.anchor_bottom = 1.0
	chat_input.offset_left = 12
	chat_input.offset_top = -44
	chat_input.offset_right = 420
	chat_input.offset_bottom = -12
	chat_input.text_submitted.connect(_on_chat_submitted)
	layer.add_child(chat_input)

	var emote_box := HBoxContainer.new()
	emote_box.anchor_left = 1.0
	emote_box.anchor_right = 1.0
	emote_box.offset_left = -340
	emote_box.offset_top = 8
	emote_box.offset_right = -12
	layer.add_child(emote_box)
	for kind: String in EMOTES:
		var b := Button.new()
		b.text = kind
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_send_emote.bind(kind))
		emote_box.add_child(b)

	for c in layer.get_children():
		if c is Control:
			(c as Control).theme = Style.ui_theme()

	hud = Hud.new()
	add_child(hud)
	hud.act_pressed.connect(_act)
	hud.place_pressed.connect(_place)
	hud.rotate_pressed.connect(_rotate)
	hud.pickup_pressed.connect(_pickup)
	hud.build_item_selected.connect(_on_build_item_selected)
	hud.craft_requested.connect(func(recipe: String) -> void: net.send({"t": "craft", "recipe": recipe}))
	hud.buy_requested.connect(func(item: String) -> void: net.send({"t": "buy", "item": item}))
	hud.sell_requested.connect(func(item: String, qty: int) -> void: net.send({"t": "sell", "item": item, "qty": qty}))

	if DisplayServer.is_touchscreen_available():
		joystick = Joystick.new()
		joystick.anchor_top = 1.0
		joystick.anchor_bottom = 1.0
		joystick.offset_left = 20
		joystick.offset_top = -200
		joystick.offset_right = 180
		joystick.offset_bottom = -40
		layer.add_child(joystick)


# ---------------------------------------------------------------- network

func _on_connected() -> void:
	status_label.text = "island: %s" % island_code
	net.send({"t": "join", "id": guest_id, "secret": guest_secret, "name": guest_name, "color": "#" + guest_color.to_html(false)})
	_last_sent = Vector3.INF


func _on_rejected(code: int) -> void:
	match code:
		4000:
			status_label.text = "This guest is open in another tab. Close it and reload."
		4003:
			status_label.text = "This guest id belongs to another device. Clear site data to start fresh."
		_:
			status_label.text = "Connection refused (%d)" % code


func _on_disconnected() -> void:
	status_label.text = "disconnected, retrying..."
	for id: String in remotes.keys():
		_remove_remote(id)


func _on_message(d: Dictionary) -> void:
	match d.get("t", ""):
		"welcome":
			for p: Dictionary in d.get("players", []):
				_add_remote(p)
			_clear_nodes()
			for n: Dictionary in d.get("nodes", []):
				_add_node(n)
			for h: Dictionary in d.get("houses", []):
				_add_house(h)
			_clear_decor()
			for dd: Dictionary in d.get("decor", []):
				_add_decor(dd)
			hud.set_inventory(d.get("inv", {}))
			IslandClock.offset_minutes = int(d.get("tz_offset", IslandClock.offset_minutes))
			_update_status()
		"inv":
			hud.set_inventory(d.get("inv", {}))
		"toast":
			hud.show_toast(d.get("text", ""))
		"house":
			_add_house(d["h"])
		"decor_add":
			_add_decor(d["d"])
		"decor_remove":
			var dn: DecorNode = decor_nodes.get(d.get("id", ""))
			if dn:
				dn.queue_free()
				decor_nodes.erase(d["id"])
		"decor_rot":
			var dr: DecorNode = decor_nodes.get(d.get("id", ""))
			if dr:
				dr.set_rot(int(d.get("rot", 0)))
		"node":
			var wn: WorldNode = nodes.get(d.get("id", ""))
			if wn:
				wn.set_ready_in(int(d.get("ready_in", 0)))
		"joined":
			_add_remote(d["p"])
			_log("%s joined" % d["p"].get("name", "?"))
			_update_status()
		"left":
			var id: String = d.get("id", "")
			if remotes.has(id):
				_log("%s left" % remotes[id].get_meta("display_name", "?"))
			_remove_remote(id)
			_update_status()
		"pos":
			var a: Avatar = remotes.get(d.get("id", ""))
			if a:
				a.target_position = Vector3(d["x"], 0, d["z"])
				a.target_yaw = d["ry"]
				if d.get("s", false):
					a.position = a.target_position
					a.rotation.y = a.target_yaw
		"chat":
			_log("%s: %s" % [d.get("name", "?"), d.get("text", "")])
			if d.get("id", "") == guest_id:
				me.say(d["text"])
			elif remotes.has(d.get("id", "")):
				remotes[d["id"]].say(d["text"])
		"emote":
			if d.get("id", "") == guest_id:
				me.emote(d["e"])
			elif remotes.has(d.get("id", "")):
				remotes[d["id"]].emote(d["e"])


func _clear_nodes() -> void:
	for n: WorldNode in nodes.values():
		n.queue_free()
	nodes.clear()


func _add_node(n: Dictionary) -> void:
	var wn := WorldNode.new()
	wn.position = Vector3(n["x"], 0, n["z"])
	add_child(wn)
	wn.setup(n["id"], n["k"], int(n["ready_in"]))
	nodes[n["id"]] = wn


func _add_house(h: Dictionary) -> void:
	var owner_id: String = h["owner"]
	if houses.has(owner_id):
		(houses[owner_id] as HouseView).set_owner_name(h["name"])
		return
	var hv := HouseView.new()
	hv.setup(int(h["slot"]), owner_id, h["name"], self)
	houses[owner_id] = hv


func _clear_decor() -> void:
	for dn: DecorNode in decor_nodes.values():
		dn.queue_free()
	decor_nodes.clear()


func _add_decor(d: Dictionary) -> void:
	if decor_nodes.has(d["id"]):
		return
	var dn := DecorNode.new()
	add_child(dn)
	dn.setup(d["id"], d["item"], int(d["rot"]), int(d["gx"]), int(d["gz"]))
	decor_nodes[d["id"]] = dn


func _my_house() -> HouseView:
	return houses.get(guest_id)


func _in_room() -> bool:
	return me.position.x >= Defs.ROOM_REGION_X


## Cell in front of the player where furniture would be placed.
func _target_cell() -> Vector2i:
	var forward := Vector3(-sin(me.rotation.y), 0, -cos(me.rotation.y))
	var p := me.position + forward * 1.8
	return Vector2i(roundi(p.x), roundi(p.z))


## Client-side guess whether a cell is valid. The server decides for real.
func _cell_valid(cell: Vector2i) -> bool:
	for dn: DecorNode in decor_nodes.values():
		if dn.gx == cell.x and dn.gz == cell.y:
			return false
	if cell.x >= Defs.ROOM_REGION_X:
		var mine := _my_house()
		if mine == null or Defs.room_slot_at(cell.x) != mine.slot:
			return false
		var c := Defs.room_center(mine.slot)
		return absf(cell.x - c.x) <= Defs.ROOM_PLACE_HALF and absf(cell.y) <= Defs.ROOM_PLACE_HALF
	if Vector2(cell).length() > Defs.ISLAND_RADIUS - 1.5:
		return false
	if Vector2(cell).distance_to(Vector2(Defs.SHOP_POS.x, Defs.SHOP_POS.z)) < Defs.SHOP_CLEARANCE:
		return false
	for p: Array in Defs.PROPS:
		if Vector2(cell).distance_to(p[1]) < float(p[2]) + 0.8:
			return false
	for n: WorldNode in nodes.values():
		if Vector2(n.position.x, n.position.z).distance_to(Vector2(cell)) < 1.8:
			return false
	for slot in Defs.MAX_HOUSES:
		var hc := Defs.house_center(slot)
		var dc := Defs.door_outside(slot)
		if Vector2(hc.x, hc.z).distance_to(Vector2(cell)) < 4.5 or Vector2(dc.x, dc.z).distance_to(Vector2(cell)) < 2.5:
			return false
	return true


func _on_build_item_selected(item: String) -> void:
	build_rot = 0
	_ghost_key = ""
	if item == "" and ghost:
		ghost.queue_free()
		ghost = null


func _update_ghost() -> void:
	if hud == null or not hud.is_building():
		if ghost:
			ghost.queue_free()
			ghost = null
		_ghost_key = ""
		return
	var cell := _target_cell()
	var key := "%s|%d" % [hud.selected_item, build_rot]
	if ghost == null or key != _ghost_key:
		if ghost:
			ghost.queue_free()
		ghost = DecorNode.new()
		add_child(ghost)
		ghost.setup("ghost", hud.selected_item, build_rot, cell.x, cell.y)
		_ghost_key = key
	ghost.position = Vector3(cell.x, 0, cell.y)
	ghost.set_ghost(_cell_valid(cell))


func _place() -> void:
	if not hud.is_building():
		hud.show_toast("Open Build (B) and pick an item first")
		return
	var cell := _target_cell()
	net.send({"t": "place", "item": hud.selected_item, "gx": cell.x, "gz": cell.y, "rot": build_rot})


func _nearest_decor() -> DecorNode:
	var best: DecorNode = null
	var best_d := 3.0
	for dn: DecorNode in decor_nodes.values():
		var d := dn.position.distance_to(me.position)
		if d < best_d:
			best_d = d
			best = dn
	return best


func _rotate() -> void:
	if hud.is_building():
		build_rot = (build_rot + 1) % 4
		return
	var dn := _nearest_decor()
	if dn:
		net.send({"t": "rotate", "id": dn.decor_id})


func _pickup() -> void:
	var dn := _nearest_decor()
	if dn:
		net.send({"t": "pickup", "id": dn.decor_id})
	else:
		hud.show_toast("Nothing to pick up nearby")


## Teleports the local player and tells everyone to snap instead of gliding.
func _teleport(pos: Vector3) -> void:
	me.position = pos
	_last_sent = Vector3(pos.x, me.rotation.y, pos.z)
	net.send({"t": "pos", "x": pos.x, "z": pos.z, "ry": me.rotation.y, "s": true})


## Returns the door action available at the player's position: {"text": ..., "go": Callable} or empty.
func _door_option() -> Dictionary:
	if _in_room():
		var slot := Defs.room_slot_at(me.position.x)
		if me.position.distance_to(Defs.room_exit_spot(slot)) < 2.2:
			return {"text": "F: leave the house", "go": func() -> void: _teleport(Defs.door_outside(slot))}
		return {}
	for hv: HouseView in houses.values():
		if me.position.distance_to(Defs.door_outside(hv.slot)) < 2.5:
			return {
				"text": "F: enter %s's house" % hv.owner_name,
				"go": func() -> void: _teleport(Defs.room_center(hv.slot) + Vector3(0, 0, 4.0)),
			}
	return {}


func _add_remote(p: Dictionary) -> void:
	var id: String = p["id"]
	if id == guest_id or remotes.has(id):
		return
	var a := _spawn_avatar(id, p["name"], Color.html(p["color"]))
	a.set_meta("display_name", p["name"])
	a.position = Vector3(p["x"], 0, p["z"])
	a.target_position = a.position
	a.target_yaw = p["ry"]
	a.rotation.y = p["ry"]
	add_child(a)
	remotes[id] = a


func _remove_remote(id: String) -> void:
	if remotes.has(id):
		remotes[id].queue_free()
		remotes.erase(id)


func _spawn_avatar(id: String, display_name: String, color: Color) -> Avatar:
	var a := Avatar.new()
	a.setup(id, display_name, color)
	return a


func _update_status() -> void:
	status_label.text = "island: %s  |  players: %d" % [island_code, remotes.size() + 1]


func _log(line: String) -> void:
	chat_log.append_text(line + "\n")


func _on_chat_submitted(text: String) -> void:
	chat_input.clear()
	chat_input.release_focus()
	if text.strip_edges() != "":
		net.send({"t": "chat", "text": text})


func _send_emote(kind: String) -> void:
	net.send({"t": "emote", "e": kind})


# ---------------------------------------------------------------- loop

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ENTER:
		chat_input.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_F:
		_act()
	elif event.physical_keycode == KEY_C:
		hud.toggle_craft()
	elif event.physical_keycode == KEY_B:
		hud.toggle_build()
	elif event.physical_keycode == KEY_P:
		_place()
	elif event.physical_keycode == KEY_R:
		_rotate()
	elif event.physical_keycode == KEY_G:
		_pickup()
	elif event.keycode == KEY_ESCAPE:
		hud.select_item("")
		hud.hide_dialogue()
		hud.hide_shop()


func _nearest_node() -> WorldNode:
	var best: WorldNode = null
	var best_d := Defs.INTERACT_RANGE
	for n: WorldNode in nodes.values():
		var d := n.position.distance_to(me.position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _on_shore() -> bool:
	return Vector2(me.position.x, me.position.z).length() >= Defs.SHORE_DISTANCE


func _act() -> void:
	if hud.is_dialogue_open():
		hud.hide_dialogue()
		return
	var door := _door_option()
	if not door.is_empty():
		(door["go"] as Callable).call()
		return
	if _in_room():
		hud.show_toast("Use Build (B) to decorate the room")
		return
	var npc := villagers.nearest(me.position)
	if npc != "":
		_talk_to(npc)
		return
	var n := _nearest_node()
	if n:
		net.send({"t": "interact", "id": n.node_id})
	elif _on_shore():
		net.send({"t": "fish"})
	else:
		hud.show_toast("Nothing nearby")


func _process(delta: float) -> void:
	var typing := chat_input.has_focus()

	var cam_turn := Input.get_axis("cam_left", "cam_right") if not typing else 0.0
	cam_yaw += cam_turn * 1.8 * delta

	var input := Vector2.ZERO
	if not typing:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if joystick:
		input += joystick.value
	input = input.limit_length(1.0)

	if input.length() > 0.05:
		var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, cam_yaw)
		me.position += dir * SPEED * delta
		if _in_room():
			var c := Defs.room_center(Defs.room_slot_at(me.position.x))
			me.position.x = clampf(me.position.x, c.x - Defs.ROOM_HALF, c.x + Defs.ROOM_HALF)
			me.position.z = clampf(me.position.z, -Defs.ROOM_HALF, Defs.ROOM_HALF)
		else:
			var flat := Vector2(me.position.x, me.position.z)
			if flat.length() > ISLAND_RADIUS:
				flat = flat.normalized() * ISLAND_RADIUS
				me.position = Vector3(flat.x, 0, flat.y)
		me.rotation.y = lerp_angle(me.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, 14.0 * delta))
		_push_out_of_nodes()

	_update_prompt()
	villagers.update(me.position, delta)
	critters.update(me.position, delta)
	_daylight_timer -= delta
	if _daylight_timer <= 0.0:
		_daylight_timer = 0.5
		_update_daylight()
	if hud.is_shop_open() and me.position.distance_to(Defs.SHOP_POS) > Defs.SHOP_RANGE + 1.5:
		hud.hide_shop()

	_send_timer += delta
	if _send_timer >= POS_SEND_INTERVAL:
		_send_timer = 0.0
		var cur := Vector3(me.position.x, me.rotation.y, me.position.z)
		if cur.distance_squared_to(_last_sent) > 0.0001:
			_last_sent = cur
			net.send({"t": "pos", "x": me.position.x, "z": me.position.z, "ry": me.rotation.y})

	for a: Avatar in remotes.values():
		var k := minf(1.0, REMOTE_SMOOTHING * delta)
		a.position = a.position.lerp(a.target_position, k)
		a.rotation.y = lerp_angle(a.rotation.y, a.target_yaw, k)

	var focus := me.position
	camera.position = focus + CAMERA_OFFSET.rotated(Vector3.UP, cam_yaw)
	camera.look_at(focus + Vector3(0, 1, 0), Vector3.UP)


func _push_out_of_nodes() -> void:
	if _in_room():
		return
	for hv: HouseView in houses.values():
		var ho := me.position - hv.position
		ho.y = 0
		if ho.length() < Defs.HOUSE_COLLISION_RADIUS:
			me.position = hv.position + ho.normalized() * Defs.HOUSE_COLLISION_RADIUS
	for p: Array in Defs.PROPS:
		var pc := Vector3(p[1].x, 0, p[1].y)
		var po := me.position - pc
		po.y = 0
		var pr: float = p[2]
		if po.length() < pr:
			me.position = pc + (po.normalized() if po.length() > 0.001 else Vector3.RIGHT) * pr
	var so := me.position - Defs.SHOP_COLLISION_CENTER
	so.y = 0
	if so.length() < Defs.SHOP_COLLISION_RADIUS:
		me.position = Defs.SHOP_COLLISION_CENTER + so.normalized() * Defs.SHOP_COLLISION_RADIUS
	for n: WorldNode in nodes.values():
		var offset := me.position - n.position
		offset.y = 0
		var min_dist := n.collision_radius() + 0.4
		if offset.length() < min_dist:
			if offset.length() < 0.001:
				offset = Vector3(1, 0, 0)
			me.position = n.position + offset.normalized() * min_dist


func _update_prompt() -> void:
	hud.set_nearby_decor(_nearest_decor() != null)
	_update_ghost()
	var door := _door_option()
	if hud.is_building():
		hud.set_prompt("P: place   R: rotate   Esc: cancel")
		return
	if not door.is_empty():
		hud.set_prompt(door["text"])
		return
	var npc := "" if _in_room() else villagers.nearest(me.position)
	if npc != "":
		hud.set_prompt("F: talk to %s" % villagers.display_name(npc))
		return
	var n := _nearest_node()
	if n and not _in_room():
		var what := "pick fruit / gather wood" if n.kind == "tree" else "take stone"
		if n.is_ready() or n.kind == "tree":
			hud.set_prompt("F: %s" % what)
		else:
			hud.set_prompt("(%s: nothing right now)" % n.kind)
	elif _on_shore() and not _in_room():
		hud.set_prompt("F: fish" if hud.has_item("fishing_rod") else "Shore: craft a fishing rod to fish")
	else:
		hud.set_prompt("")


# ---------------------------------------------------------------- villagers and shop

func _talk_to(npc: String) -> void:
	var who := villagers.display_name(npc)
	var text := villagers.line_for(npc, hud.get_inventory())
	if npc == "mara" and not villagers.is_sleeping(npc) and IslandClock.shop_is_open():
		hud.show_dialogue(who, text, [
			{"label": "Buy", "action": func() -> void: hud.show_shop("buy")},
			{"label": "Sell", "action": func() -> void: hud.show_shop("sell")},
			{"label": "Bye", "action": Callable()},
		])
	else:
		hud.show_dialogue(who, text)


func _build_shop_stall() -> void:
	var stall := Node3D.new()
	stall.position = Defs.SHOP_POS
	add_child(stall)
	var wood := Color(0.62, 0.42, 0.24)
	var parts := [
		[Vector3(3.0, 1.0, 0.8), wood, Vector3(0, 0.5, 0)],  # counter
		[Vector3(3.2, 0.08, 1.0), Color(0.9, 0.85, 0.7), Vector3(0, 1.04, 0)],  # counter top
		[Vector3(0.15, 2.6, 0.15), wood, Vector3(-1.45, 1.3, -1.6)],
		[Vector3(0.15, 2.6, 0.15), wood, Vector3(1.45, 1.3, -1.6)],
		[Vector3(0.15, 2.6, 0.15), wood, Vector3(-1.45, 1.3, 0.3)],
		[Vector3(0.15, 2.6, 0.15), wood, Vector3(1.45, 1.3, 0.3)],
		[Vector3(3.4, 0.12, 2.4), Color(0.85, 0.2, 0.2), Vector3(0, 2.65, -0.65)],  # canopy
		[Vector3(3.4, 0.14, 0.5), Color(0.97, 0.97, 0.97), Vector3(0, 2.62, 0.45)],  # canopy trim
	]
	for p: Array in parts:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = p[0]
		mi.mesh = b
		mi.material_override = _mat(p[1])
		mi.position = p[2]
		stall.add_child(mi)
	shop_sign = Style.label3d("", 40)
	shop_sign.no_depth_test = false
	shop_sign.position = Vector3(0, 3.4, -0.4)
	stall.add_child(shop_sign)


# ---------------------------------------------------------------- day and night

const SKY_KEYS := [
	[0.0, Color(0.1, 0.12, 0.24)], [5.0, Color(0.12, 0.14, 0.27)], [6.5, Color(0.98, 0.78, 0.6)],
	[8.0, Color(0.76, 0.86, 0.88)], [17.5, Color(0.76, 0.86, 0.88)], [19.5, Color(0.98, 0.68, 0.5)],
	[21.0, Color(0.14, 0.15, 0.3)], [24.0, Color(0.1, 0.12, 0.24)],
]


func _sky_color(h: float) -> Color:
	for i in SKY_KEYS.size() - 1:
		var a: Array = SKY_KEYS[i]
		var b: Array = SKY_KEYS[i + 1]
		if h >= a[0] and h <= b[0]:
			return (a[1] as Color).lerp(b[1], (h - a[0]) / (b[0] - a[0]))
	return SKY_KEYS[0][1]


func _update_daylight() -> void:
	var h := IslandClock.hour()
	hud.set_clock(IslandClock.label())
	shop_sign.text = "Mara's Shop\n%s" % ("Open until 22:00" if IslandClock.shop_is_open() else "Closed (opens 8:00)")

	# Sun arc from 6:00 to 20:00 with a golden hour when it is low; a dim blue moon at night.
	var day := clampf(sin(PI * (h - 6.0) / 14.0), 0.0, 1.0) if h > 6.0 and h < 20.0 else 0.0
	var f := clampf(day * 6.0, 0.0, 1.0)  # 0 = night, 1 = daylight
	var golden := 1.0 - clampf(day * 2.5, 0.0, 1.0)  # 1 near sunrise/sunset
	world_env.background_color = _sky_color(h)
	world_env.ambient_light_energy = 0.25 + 0.2 * f
	var day_ambient := Color(0.85, 0.8, 0.72).lerp(Color(0.95, 0.72, 0.6), golden)
	world_env.ambient_light_color = Color(0.42, 0.45, 0.7).lerp(day_ambient, f)
	var sun_color := Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.64, 0.4), golden)
	sun.light_color = Color(0.55, 0.65, 1.0).lerp(sun_color, f)
	sun.light_energy = lerpf(0.2, 0.45 + 0.4 * clampf(day * 2.0, 0.0, 1.0), f)
	var elevation := lerpf(40.0, 15.0 + 60.0 * day, f)
	var azimuth := lerpf(-60.0, 240.0, clampf((h - 6.0) / 14.0, 0.0, 1.0)) if f > 0.0 else 30.0
	sun.rotation_degrees = Vector3(-elevation, azimuth, 0)


## Grass tufts and flowers scattered over the meadow (decoration only, same on every client).
func _scatter_meadow() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var tuft := CylinderMesh.new()
	tuft.top_radius = 0.0
	tuft.bottom_radius = 0.1
	tuft.height = 0.35
	tuft.radial_segments = 5
	tuft.rings = 1
	var flower := SphereMesh.new()
	flower.radius = 0.1
	flower.height = 0.16
	flower.radial_segments = 6
	flower.rings = 3
	var palette := [Color(0.95, 0.85, 0.3), Color(0.95, 0.95, 0.9), Color(0.9, 0.45, 0.5), Color(0.6, 0.55, 0.9)]
	for kind in ["tuft", "flower"]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = tuft if kind == "tuft" else flower
		mm.instance_count = 320 if kind == "tuft" else 140
		for i in mm.instance_count:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * (ISLAND_RADIUS - 2.0)
			var pos := Vector3(cos(a) * r, 0.15 if kind == "tuft" else 0.12, sin(a) * r)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4))
			mm.set_instance_transform(i, Transform3D(basis, pos))
			if kind == "tuft":
				mm.set_instance_color(i, Color(0.42, 0.55, 0.25).lerp(Color(0.55, 0.65, 0.3), rng.randf()))
			else:
				mm.set_instance_color(i, palette[rng.randi() % palette.size()])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Style.mat(Color.WHITE, {"vertex_color": true, "outline": kind == "flower"})
		add_child(mmi)
