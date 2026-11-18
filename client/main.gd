extends Node3D

## Phase 0: spinning cube + WebSocket round trip to the island server.

const SERVER_URL := "ws://localhost:8787/island/test/ws"

var _socket := WebSocketPeer.new()
var _was_open := false

@onready var _status: Label = $Status
@onready var _cube: MeshInstance3D = $Cube


func _ready() -> void:
	var err := _socket.connect_to_url(SERVER_URL)
	if err != OK:
		_status.text = "connect failed: %d" % err


func _process(delta: float) -> void:
	_cube.rotate_y(delta)
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _was_open:
				_was_open = true
				_socket.send_text(JSON.stringify({"type": "ping"}))
			while _socket.get_available_packet_count() > 0:
				_status.text = "server: " + _socket.get_packet().get_string_from_utf8()
		WebSocketPeer.STATE_CLOSED:
			_status.text = "disconnected (code %d)" % _socket.get_close_code()
