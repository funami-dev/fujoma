class_name Net
extends Node
## WebSocket connection to the island server with automatic reconnect.

signal connected
signal disconnected
signal message(data: Dictionary)

const RECONNECT_DELAY := 2.0

var url := ""
var _socket: WebSocketPeer
var _was_open := false
var _retry_in := 0.0


func open(server_url: String) -> void:
	url = server_url
	_connect()


func send(data: Dictionary) -> void:
	if _socket and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(JSON.stringify(data))


func is_open() -> bool:
	return _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN


func _connect() -> void:
	_socket = WebSocketPeer.new()
	_was_open = false
	if _socket.connect_to_url(url) != OK:
		_socket = null
		_retry_in = RECONNECT_DELAY


func _process(delta: float) -> void:
	if _socket == null:
		_retry_in -= delta
		if _retry_in <= 0.0:
			_connect()
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _was_open:
				_was_open = true
				connected.emit()
			while _socket.get_available_packet_count() > 0:
				var parsed: Variant = JSON.parse_string(_socket.get_packet().get_string_from_utf8())
				if parsed is Dictionary:
					message.emit(parsed)
		WebSocketPeer.STATE_CLOSED:
			var was_open := _was_open
			_socket = null
			_retry_in = RECONNECT_DELAY
			if was_open:
				disconnected.emit()
