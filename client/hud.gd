class_name Hud
extends CanvasLayer
## Inventory, crafting panel, interaction prompt and toast messages.

signal act_pressed
signal craft_requested(recipe: String)
signal build_item_selected(item: String)
signal place_pressed
signal rotate_pressed
signal pickup_pressed

var _inventory_label: Label
var _prompt: Label
var _toast: Label
var _toast_left := 0.0
var _craft_panel: PanelContainer
var _craft_buttons: Dictionary = {}
var _inv: Dictionary = {}
var _build_panel: PanelContainer
var _build_items: VBoxContainer
var _build_hint: Label
var _pickup_btn: Button
var _rotate_btn: Button
var selected_item := ""


func _ready() -> void:
	_inventory_label = Label.new()
	_inventory_label.position = Vector2(12, 34)
	add_child(_inventory_label)

	_prompt = Label.new()
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -150
	_prompt.offset_right = 150
	_prompt.offset_top = -110
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)

	_toast = Label.new()
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -250
	_toast.offset_right = 250
	_toast.offset_top = 56
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", Color(1, 1, 0.6))
	add_child(_toast)

	var buttons := VBoxContainer.new()
	buttons.anchor_left = 1.0
	buttons.anchor_right = 1.0
	buttons.anchor_top = 1.0
	buttons.anchor_bottom = 1.0
	buttons.offset_left = -130
	buttons.offset_right = -16
	buttons.offset_top = -290
	buttons.offset_bottom = -16
	buttons.alignment = BoxContainer.ALIGNMENT_END
	add_child(buttons)
	_pickup_btn = _action_button(buttons, "Pick up (G)", func() -> void: pickup_pressed.emit())
	_rotate_btn = _action_button(buttons, "Rotate (R)", func() -> void: rotate_pressed.emit())
	_pickup_btn.visible = false
	_rotate_btn.visible = false
	_action_button(buttons, "Act (F)", func() -> void: act_pressed.emit())
	_action_button(buttons, "Build (B)", toggle_build)
	_action_button(buttons, "Craft (C)", toggle_craft)

	_build_panel = PanelContainer.new()
	_build_panel.anchor_left = 1.0
	_build_panel.anchor_right = 1.0
	_build_panel.offset_left = -330
	_build_panel.offset_right = -140
	_build_panel.offset_top = 56
	_build_panel.visible = false
	add_child(_build_panel)
	var build_box := VBoxContainer.new()
	_build_panel.add_child(build_box)
	_build_hint = Label.new()
	_build_hint.text = "Pick an item, then Place (P)"
	build_box.add_child(_build_hint)
	_build_items = VBoxContainer.new()
	build_box.add_child(_build_items)
	var place_row := HBoxContainer.new()
	build_box.add_child(place_row)
	_action_button(place_row, "Place (P)", func() -> void: place_pressed.emit())
	_action_button(place_row, "Rotate (R)", func() -> void: rotate_pressed.emit())

	_craft_panel = PanelContainer.new()
	_craft_panel.anchor_left = 1.0
	_craft_panel.anchor_right = 1.0
	_craft_panel.offset_left = -330
	_craft_panel.offset_right = -140
	_craft_panel.offset_top = 56
	_craft_panel.visible = false
	add_child(_craft_panel)
	var box := VBoxContainer.new()
	_craft_panel.add_child(box)
	for recipe: String in Defs.RECIPES:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: craft_requested.emit(recipe))
		box.add_child(b)
		_craft_buttons[recipe] = b
	set_inventory({})


func _action_button(parent: Control, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func toggle_craft() -> void:
	_craft_panel.visible = not _craft_panel.visible


func toggle_build() -> void:
	_build_panel.visible = not _build_panel.visible
	if not _build_panel.visible:
		select_item("")


func is_building() -> bool:
	return _build_panel.visible and selected_item != ""


func select_item(item: String) -> void:
	selected_item = item
	build_item_selected.emit(item)
	_refresh_build_items()


func set_nearby_decor(near: bool) -> void:
	var visible_now := near and not is_building()
	_pickup_btn.visible = visible_now
	_rotate_btn.visible = visible_now


func set_prompt(text: String) -> void:
	_prompt.text = text


func show_toast(text: String) -> void:
	_toast.text = text
	_toast_left = 3.0


func set_inventory(inv: Dictionary) -> void:
	_inv = inv
	var lines: PackedStringArray = []
	for item: String in Defs.ITEM_NAMES:
		var qty: int = int(inv.get(item, 0))
		if qty > 0:
			lines.append("%s x%d" % [Defs.ITEM_NAMES[item], qty])
	_inventory_label.text = "Inventory\n" + ("\n".join(lines) if lines.size() > 0 else "(empty)")
	if selected_item != "" and int(inv.get(selected_item, 0)) < 1:
		select_item("")
	_refresh_build_items()
	for recipe: String in _craft_buttons:
		var cost: Dictionary = Defs.RECIPES[recipe]
		var parts: PackedStringArray = []
		var affordable := true
		for item: String in cost:
			parts.append("%d %s" % [cost[item], Defs.ITEM_NAMES[item].to_lower()])
			if int(inv.get(item, 0)) < int(cost[item]):
				affordable = false
		var b: Button = _craft_buttons[recipe]
		b.text = "%s (%s)" % [Defs.ITEM_NAMES[recipe], ", ".join(parts)]
		b.disabled = not affordable


func _refresh_build_items() -> void:
	if _build_items == null:
		return
	for c in _build_items.get_children():
		c.queue_free()
	var any := false
	for item: String in Defs.PLACEABLE:
		var qty := int(_inv.get(item, 0))
		if qty < 1:
			continue
		any = true
		var b := Button.new()
		b.text = "%s x%d%s" % [Defs.ITEM_NAMES[item], qty, "  <" if item == selected_item else ""]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(select_item.bind(item))
		_build_items.add_child(b)
	_build_hint.text = "Pick an item, then Place (P)" if any else "Nothing to place. Craft furniture first (C)."


func has_item(item: String) -> bool:
	return int(_inv.get(item, 0)) > 0


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.text = ""
