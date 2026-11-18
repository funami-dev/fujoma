class_name Joystick
extends Control
## Minimal on-screen joystick. Touch input arrives as emulated mouse events.

var value := Vector2.ZERO
var _active := false
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_active = event.pressed
		if _active:
			_update(event.position)
		else:
			value = Vector2.ZERO
			_knob = Vector2.ZERO
			queue_redraw()
	elif event is InputEventMouseMotion and _active:
		_update(event.position)


func _update(pos: Vector2) -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0
	_knob = (pos - center).limit_length(radius)
	value = _knob / radius
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0
	draw_circle(center, radius, Color(1, 1, 1, 0.2))
	draw_circle(center + _knob, radius * 0.4, Color(1, 1, 1, 0.5))
