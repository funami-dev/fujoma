class_name ActionWheel
extends Control
## A radial menu: big round buttons on a circle around the screen center, easy to hit with a thumb.
## Tapping outside the ring or the center button closes it.

signal chosen(id: String)

const ITEM_SIZE := 118.0
const CLOSE_SIZE := 84.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


## items: Array of {"id": String, "label": String}
func open(items: Array) -> void:
	for c in get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.05, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var view := get_viewport_rect().size
	var center := view / 2.0
	var radius := minf(view.x, view.y) * 0.33
	radius = maxf(radius, ITEM_SIZE * items.size() / TAU * 1.15)  # keep buttons from overlapping
	for i in items.size():
		var item: Dictionary = items[i]
		var angle := -PI / 2.0 + i * TAU / items.size()
		var b := _round_button(item["label"], ITEM_SIZE, "RoundButton")
		b.position = center + Vector2(cos(angle), sin(angle)) * radius - Vector2.ONE * ITEM_SIZE / 2.0
		var id: String = item["id"]
		b.pressed.connect(func() -> void:
			close()
			chosen.emit(id))
		add_child(b)

	var x := _round_button("X", CLOSE_SIZE, "PrimaryButton")
	x.position = center - Vector2.ONE * CLOSE_SIZE / 2.0
	x.pressed.connect(close)
	add_child(x)

	visible = true
	modulate.a = 0.0
	scale = Vector2.ONE * 0.92
	pivot_offset = center
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.12)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12)


func close() -> void:
	visible = false


func _round_button(text: String, size_px: float, variation: String) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2.ONE * size_px
	b.size = Vector2.ONE * size_px
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


func _gui_input(event: InputEvent) -> void:
	# A tap on the dimmed background closes the wheel.
	if event is InputEventMouseButton and event.pressed:
		close()
		accept_event()
