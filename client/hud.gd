class_name Hud
extends CanvasLayer
## Inventory, crafting panel, interaction prompt and toast messages.

signal act_pressed
signal craft_requested(recipe: String)

var _inventory_label: Label
var _prompt: Label
var _toast: Label
var _toast_left := 0.0
var _craft_panel: PanelContainer
var _craft_buttons: Dictionary = {}
var _inv: Dictionary = {}


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
	buttons.offset_top = -150
	buttons.offset_bottom = -16
	add_child(buttons)
	var act := Button.new()
	act.text = "Act (F)"
	act.custom_minimum_size = Vector2(0, 56)
	act.focus_mode = Control.FOCUS_NONE
	act.pressed.connect(func() -> void: act_pressed.emit())
	buttons.add_child(act)
	var craft := Button.new()
	craft.text = "Craft (C)"
	craft.custom_minimum_size = Vector2(0, 56)
	craft.focus_mode = Control.FOCUS_NONE
	craft.pressed.connect(toggle_craft)
	buttons.add_child(craft)

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


func toggle_craft() -> void:
	_craft_panel.visible = not _craft_panel.visible


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


func has_item(item: String) -> bool:
	return int(_inv.get(item, 0)) > 0


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.text = ""
