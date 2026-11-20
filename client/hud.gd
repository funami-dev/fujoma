class_name Hud
extends CanvasLayer
## Inventory, crafting panel, interaction prompt and toast messages.

signal act_pressed
signal craft_requested(recipe: String)
signal build_item_selected(item: String)
signal place_pressed
signal rotate_pressed
signal pickup_pressed
signal buy_requested(item: String)
signal sell_requested(item: String, qty: int)
signal emote_requested(kind: String)
signal chat_requested
signal garden_tool_selected(tool: String)

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
var _clock: Label
var _dialogue: PanelContainer
var _dialogue_name: Label
var _dialogue_text: Label
var _dialogue_options: HBoxContainer
var _shop: PanelContainer
var _shop_title: Label
var _shop_list: VBoxContainer
var _shop_mode := ""
var _primary: Button
var _menu_btn: Button
var _wheel: ActionWheel
var _near_decor := false
var _garden_panel: PanelContainer
var _garden_list: VBoxContainer
## Selected garden tool: "ground:<kind>" or "seed:<item>", or "" for none.
var garden_tool := ""
## On touch screens keyboard hints are hidden and the chat field only opens on demand.
var touch := DisplayServer.is_touchscreen_available()


func _ready() -> void:
	_inventory_label = Label.new()
	_inventory_label.position = Vector2(12, 34)
	add_child(_inventory_label)

	_clock = Label.new()
	_clock.anchor_left = 0.5
	_clock.anchor_right = 0.5
	_clock.offset_left = -60
	_clock.offset_right = 60
	_clock.offset_top = 8
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.add_theme_font_size_override("font_size", 22)
	add_child(_clock)

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
	_toast.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	add_child(_toast)

	# Big round context button (bottom right) and the menu button that opens the action wheel.
	_primary = _round(Vector2(-150, -150), 134.0, "Aktion", "PrimaryButton")
	_primary.pressed.connect(func() -> void: act_pressed.emit())
	_menu_btn = _round(Vector2(-232, -96), 80.0, "Menü", "RoundButton")
	_menu_btn.pressed.connect(open_wheel)
	_pickup_btn = _round(Vector2(-140, -250), 80.0, "Auf-\nheben", "RoundButton")
	_pickup_btn.pressed.connect(func() -> void: pickup_pressed.emit())
	_rotate_btn = _round(Vector2(-232, -200), 80.0, "Drehen", "RoundButton")
	_rotate_btn.pressed.connect(func() -> void: rotate_pressed.emit())
	_pickup_btn.visible = false
	_rotate_btn.visible = false

	_build_panel = PanelContainer.new()
	_build_panel.anchor_left = 1.0
	_build_panel.anchor_right = 1.0
	_build_panel.offset_left = -380
	_build_panel.offset_right = -16
	_build_panel.offset_top = 56
	_build_panel.visible = false
	add_child(_build_panel)
	var build_box := VBoxContainer.new()
	_build_panel.add_child(build_box)
	_build_hint = Label.new()
	_build_hint.theme_type_variation = "PanelLabel"
	_build_hint.text = "Wähle etwas aus, dann Platzieren"
	build_box.add_child(_build_hint)
	_build_items = _scroll_list(build_box)
	var place_row := HBoxContainer.new()
	build_box.add_child(place_row)
	_action_button(place_row, "Platzieren", func() -> void: place_pressed.emit())
	_action_button(place_row, "Drehen", func() -> void: rotate_pressed.emit())
	_action_button(place_row, "Fertig", toggle_build)

	_build_dialogue()
	_build_shop()

	_craft_panel = PanelContainer.new()
	_craft_panel.anchor_left = 1.0
	_craft_panel.anchor_right = 1.0
	_craft_panel.offset_left = -440
	_craft_panel.offset_right = -16
	_craft_panel.offset_top = 56
	_craft_panel.visible = false
	add_child(_craft_panel)
	var box := VBoxContainer.new()
	_craft_panel.add_child(box)
	var craft_head := HBoxContainer.new()
	box.add_child(craft_head)
	var craft_title := Label.new()
	craft_title.theme_type_variation = "PanelLabel"
	craft_title.text = "Basteln"
	craft_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_head.add_child(craft_title)
	_action_button(craft_head, "Schließen", toggle_craft)
	var craft_list := _scroll_list(box)
	for recipe: String in Defs.RECIPES:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: craft_requested.emit(recipe))
		craft_list.add_child(b)
		_craft_buttons[recipe] = b

	_garden_panel = PanelContainer.new()
	_garden_panel.anchor_left = 1.0
	_garden_panel.anchor_right = 1.0
	_garden_panel.offset_left = -380
	_garden_panel.offset_right = -16
	_garden_panel.offset_top = 56
	_garden_panel.visible = false
	add_child(_garden_panel)
	var garden_box := VBoxContainer.new()
	_garden_panel.add_child(garden_box)
	var garden_head := HBoxContainer.new()
	garden_box.add_child(garden_head)
	var garden_title := Label.new()
	garden_title.theme_type_variation = "PanelLabel"
	garden_title.text = "Garten"
	garden_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	garden_head.add_child(garden_title)
	_action_button(garden_head, "Fertig", toggle_garden)
	_garden_list = _scroll_list(garden_box)
	_wheel = ActionWheel.new()
	_wheel.chosen.connect(_on_wheel_chosen)
	add_child(_wheel)

	set_inventory({})
	for c in get_children():
		if c is Control:
			(c as Control).theme = Style.ui_theme()


func _round(offset: Vector2, size_px: float, text: String, variation: String) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = offset.x
	b.offset_top = offset.y
	b.offset_right = offset.x + size_px
	b.offset_bottom = offset.y + size_px
	add_child(b)
	return b


# ---------------------------------------------------------------- action wheel

func open_wheel() -> void:
	var items := [
		{"id": "build", "label": "Bauen"},
		{"id": "craft", "label": "Basteln"},
		{"id": "garden", "label": "Garten"},
		{"id": "chat", "label": "Chat"},
		{"id": "wave", "label": Defs.EMOTE_LABELS["wave"]},
		{"id": "happy", "label": Defs.EMOTE_LABELS["happy"]},
		{"id": "sad", "label": Defs.EMOTE_LABELS["sad"]},
		{"id": "dance", "label": Defs.EMOTE_LABELS["dance"]},
	]
	if _near_decor:
		items.insert(2, {"id": "pickup", "label": "Auf-\nheben"})
		items.insert(3, {"id": "rotate", "label": "Drehen"})
	_wheel.open(items)


func toggle_wheel() -> void:
	if _wheel.visible:
		_wheel.close()
	else:
		open_wheel()


func _on_wheel_chosen(id: String) -> void:
	match id:
		"build":
			if not _build_panel.visible:
				toggle_build()
		"craft":
			if not _craft_panel.visible:
				toggle_craft()
		"garden":
			if not _garden_panel.visible:
				toggle_garden()
		"chat":
			chat_requested.emit()
		"pickup":
			pickup_pressed.emit()
		"rotate":
			rotate_pressed.emit()
		_:
			emote_requested.emit(id)


## Label of the big context button, e.g. "Reden" or "Ernten".
func set_primary(text: String) -> void:
	_primary.text = text if text != "" else "Aktion"


func _action_button(parent: Control, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


## A vertical list that scrolls when it gets taller than the screen allows.
func _scroll_list(parent: Control) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 250)
	parent.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	return list


## Only one side panel at a time.
func _close_panels(except: Control) -> void:
	if except != _craft_panel:
		_craft_panel.visible = false
	if except != _build_panel and _build_panel.visible:
		_build_panel.visible = false
		select_item("")
	if except != _garden_panel and _garden_panel.visible:
		_garden_panel.visible = false
		select_garden_tool("")


func toggle_craft() -> void:
	_close_panels(_craft_panel)
	_craft_panel.visible = not _craft_panel.visible


func toggle_build() -> void:
	_close_panels(_build_panel)
	_build_panel.visible = not _build_panel.visible
	if not _build_panel.visible:
		select_item("")


func toggle_garden() -> void:
	_close_panels(_garden_panel)
	_garden_panel.visible = not _garden_panel.visible
	if not _garden_panel.visible:
		select_garden_tool("")
	else:
		_refresh_garden()


func is_gardening() -> bool:
	return _garden_panel.visible and garden_tool != ""


func select_garden_tool(tool: String) -> void:
	garden_tool = tool
	garden_tool_selected.emit(tool)
	_refresh_garden()


func _refresh_garden() -> void:
	if _garden_list == null:
		return
	for c in _garden_list.get_children():
		c.queue_free()
	var head := Label.new()
	head.theme_type_variation = "PanelLabel"
	head.text = "Boden"
	_garden_list.add_child(head)
	for g: Array in Defs.GROUND_TOOLS:
		var tool := "ground:" + String(g[0])
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = "%s  (%s)%s" % [g[1], g[2], "  <" if garden_tool == tool else ""]
		b.pressed.connect(select_garden_tool.bind(tool))
		_garden_list.add_child(b)
	var seeds_head := Label.new()
	seeds_head.theme_type_variation = "PanelLabel"
	seeds_head.text = "Säen"
	_garden_list.add_child(seeds_head)
	var any := false
	for seed: String in Defs.SEEDS:
		var qty := int(_inv.get(seed, 0))
		if qty < 1:
			continue
		any = true
		var tool := "seed:" + seed
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = "%s x%d%s" % [Defs.ITEM_NAMES[seed], qty, "  <" if garden_tool == tool else ""]
		b.pressed.connect(select_garden_tool.bind(tool))
		_garden_list.add_child(b)
	if not any:
		var none := Label.new()
		none.theme_type_variation = "PanelLabel"
		none.text = "Keine Samen. Mara verkauft welche."
		_garden_list.add_child(none)


func is_building() -> bool:
	return _build_panel.visible and selected_item != ""


func select_item(item: String) -> void:
	selected_item = item
	build_item_selected.emit(item)
	_refresh_build_items()


func set_nearby_decor(near: bool) -> void:
	_near_decor = near
	var visible_now := near and not is_building()
	_pickup_btn.visible = visible_now
	_rotate_btn.visible = visible_now


## key: keyboard hint shown on desktop only (e.g. "F").
func set_prompt(text: String, key := "") -> void:
	_prompt.text = text if key == "" or touch else "%s: %s" % [key, text]


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
	_inventory_label.text = "Münzen: %d\nRucksack\n%s" % [int(inv.get(Defs.COINS, 0)), "\n".join(lines) if lines.size() > 0 else "(leer)"]
	if _shop and _shop.visible:
		_refresh_shop()
	if selected_item != "" and int(inv.get(selected_item, 0)) < 1:
		select_item("")
	if garden_tool.begins_with("seed:") and int(inv.get(garden_tool.substr(5), 0)) < 1:
		select_garden_tool("")
	elif _garden_panel and _garden_panel.visible:
		_refresh_garden()
	_refresh_build_items()
	for recipe: String in _craft_buttons:
		var cost: Dictionary = Defs.RECIPES[recipe]
		var parts: PackedStringArray = []
		var affordable := true
		for item: String in cost:
			parts.append("%d %s" % [cost[item], Defs.ITEM_NAMES[item]])
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
	_build_hint.text = "Wähle etwas aus, dann Platzieren" if any else "Nichts zum Aufstellen.\nBastle zuerst Möbel."


func set_clock(text: String) -> void:
	_clock.text = text


# ---------------------------------------------------------------- dialogue

func _build_dialogue() -> void:
	_dialogue = PanelContainer.new()
	_dialogue.anchor_left = 0.5
	_dialogue.anchor_right = 0.5
	_dialogue.anchor_top = 1.0
	_dialogue.anchor_bottom = 1.0
	_dialogue.offset_left = -260
	_dialogue.offset_right = 260
	_dialogue.offset_top = -230
	_dialogue.offset_bottom = -120
	_dialogue.visible = false
	add_child(_dialogue)
	var box := VBoxContainer.new()
	_dialogue.add_child(box)
	_dialogue_name = Label.new()
	_dialogue_name.theme_type_variation = "PanelLabel"
	_dialogue_name.add_theme_color_override("font_color", Style.ACCENT)
	box.add_child(_dialogue_name)
	_dialogue_text = Label.new()
	_dialogue_text.theme_type_variation = "PanelLabel"
	_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text.custom_minimum_size = Vector2(500, 0)
	box.add_child(_dialogue_text)
	_dialogue_options = HBoxContainer.new()
	_dialogue_options.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(_dialogue_options)


## options: Array of {"label": String, "action": Callable}. With no options, a single "OK" closes it.
func show_dialogue(speaker: String, text: String, options: Array = []) -> void:
	_dialogue_name.text = speaker
	_dialogue_text.text = text
	for c in _dialogue_options.get_children():
		c.queue_free()
	if options.is_empty():
		options = [{"label": "OK", "action": Callable()}]
	for opt: Dictionary in options:
		var b := Button.new()
		b.text = opt["label"]
		b.focus_mode = Control.FOCUS_NONE
		var action: Callable = opt["action"]
		b.pressed.connect(func() -> void:
			hide_dialogue()
			if action.is_valid():
				action.call())
		_dialogue_options.add_child(b)
	_dialogue.visible = true


func hide_dialogue() -> void:
	_dialogue.visible = false


func is_dialogue_open() -> bool:
	return _dialogue.visible


# ---------------------------------------------------------------- shop

func _build_shop() -> void:
	_shop = PanelContainer.new()
	_shop.anchor_left = 0.5
	_shop.anchor_right = 0.5
	_shop.offset_left = -220
	_shop.offset_right = 220
	_shop.offset_top = 60
	_shop.visible = false
	add_child(_shop)
	var box := VBoxContainer.new()
	_shop.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_shop_title = Label.new()
	_shop_title.theme_type_variation = "PanelLabel"
	_shop_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_shop_title)
	var close := Button.new()
	close.text = "Schließen"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide_shop)
	header.add_child(close)
	_shop_list = _scroll_list(box)


## mode: "buy" or "sell"
func show_shop(mode: String) -> void:
	_shop_mode = mode
	_shop.visible = true
	_refresh_shop()


func hide_shop() -> void:
	_shop.visible = false


func is_shop_open() -> bool:
	return _shop.visible


func _refresh_shop() -> void:
	for c in _shop_list.get_children():
		c.queue_free()
	var coins := int(_inv.get(Defs.COINS, 0))
	if _shop_mode == "buy":
		_shop_title.text = "Kaufen  (du hast %d Münzen)" % coins
		for item: String in Defs.SHOP_CATALOG:
			var price: int = Defs.SHOP_CATALOG[item]
			var b := Button.new()
			b.text = "%s  -  %d Münzen" % [Defs.ITEM_NAMES[item], price]
			b.focus_mode = Control.FOCUS_NONE
			b.disabled = coins < price
			b.pressed.connect(func() -> void: buy_requested.emit(item))
			_shop_list.add_child(b)
	else:
		_shop_title.text = "Verkaufen  (du hast %d Münzen)" % coins
		var any := false
		for item: String in Defs.SELL_PRICES:
			var qty := int(_inv.get(item, 0))
			if qty < 1:
				continue
			any = true
			var row := HBoxContainer.new()
			var label := Label.new()
			label.theme_type_variation = "PanelLabel"
			label.text = "%s x%d  (je %d)" % [Defs.ITEM_NAMES[item], qty, Defs.SELL_PRICES[item]]
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			var one := Button.new()
			one.text = "1 verkaufen"
			one.focus_mode = Control.FOCUS_NONE
			one.pressed.connect(func() -> void: sell_requested.emit(item, 1))
			row.add_child(one)
			var all := Button.new()
			all.text = "Alle"
			all.focus_mode = Control.FOCUS_NONE
			all.pressed.connect(func() -> void: sell_requested.emit(item, qty))
			row.add_child(all)
			_shop_list.add_child(row)
		if not any:
			var empty := Label.new()
			empty.theme_type_variation = "PanelLabel"
			empty.text = "Nichts zu verkaufen. Sammle Äpfel,\nHolz, Steine oder Fische."
			_shop_list.add_child(empty)


func get_inventory() -> Dictionary:
	return _inv


func has_item(item: String) -> bool:
	return int(_inv.get(item, 0)) > 0


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.text = ""
