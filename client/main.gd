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
var cam_yaw := 0.0
var _send_timer := 0.0
var _last_sent := Vector3.INF

var status_label: Label
var chat_log: RichTextLabel
var chat_input: LineEdit
var joystick: Joystick
var hud: Hud
var nodes: Dictionary = {}  # id -> WorldNode
var _touch_dir := Vector2.ZERO


func _ready() -> void:
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
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.53, 0.81, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.75, 0.85)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	add_child(sun)

	_add_mesh(_cylinder(ISLAND_RADIUS + 3.0, 2.0), Color(0.93, 0.85, 0.6), Vector3(0, -1.05, 0))  # sand
	_add_mesh(_cylinder(ISLAND_RADIUS, 2.0), Color(0.45, 0.75, 0.38), Vector3(0, -1.0, 0))  # grass

	var water := PlaneMesh.new()
	water.size = Vector2(400, 400)
	_add_mesh(water, Color(0.2, 0.5, 0.8), Vector3(0, -0.6, 0))

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


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m


func _add_mesh(mesh: Mesh, color: Color, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
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

	hud = Hud.new()
	add_child(hud)
	hud.act_pressed.connect(_act)
	hud.craft_requested.connect(func(recipe: String) -> void: net.send({"t": "craft", "recipe": recipe}))

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
			hud.set_inventory(d.get("inv", {}))
			_update_status()
		"inv":
			hud.set_inventory(d.get("inv", {}))
		"toast":
			hud.show_toast(d.get("text", ""))
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
		var flat := Vector2(me.position.x, me.position.z)
		if flat.length() > ISLAND_RADIUS:
			flat = flat.normalized() * ISLAND_RADIUS
			me.position = Vector3(flat.x, 0, flat.y)
		me.rotation.y = lerp_angle(me.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, 14.0 * delta))
		_push_out_of_nodes()

	_update_prompt()

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
	for n: WorldNode in nodes.values():
		var offset := me.position - n.position
		offset.y = 0
		var min_dist := n.collision_radius() + 0.4
		if offset.length() < min_dist:
			if offset.length() < 0.001:
				offset = Vector3(1, 0, 0)
			me.position = n.position + offset.normalized() * min_dist


func _update_prompt() -> void:
	var n := _nearest_node()
	if n:
		var what := "pick fruit / gather wood" if n.kind == "tree" else "take stone"
		if n.is_ready() or n.kind == "tree":
			hud.set_prompt("F: %s" % what)
		else:
			hud.set_prompt("(%s: nothing right now)" % n.kind)
	elif _on_shore():
		hud.set_prompt("F: fish" if hud.has_item("fishing_rod") else "Shore: craft a fishing rod to fish")
	else:
		hud.set_prompt("")
