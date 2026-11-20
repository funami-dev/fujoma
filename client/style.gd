class_name Style
## The game's look: painterly toon materials with ink outlines, a warm storybook palette,
## a handwritten font and paper-like UI panels.

const INK := Color(0.22, 0.14, 0.09)
const PAPER := Color(0.98, 0.94, 0.84)
const TEXT_DARK := Color(0.27, 0.17, 0.1)
const TEXT_LIGHT := Color(1.0, 0.97, 0.9)
const ACCENT := Color(0.62, 0.24, 0.14)

static var _toon: Shader = preload("res://shaders/toon.gdshader")
static var _outline: Shader = preload("res://shaders/outline.gdshader")
static var _font: FontFile = preload("res://assets/fonts/PatrickHand.woff2")
static var _outline_mat: ShaderMaterial
static var _theme: Theme


## opts: texture (Texture2D), color2 + patch_scale (meadow patches), emission (Color),
## paper (grain strength), vertex_color (bool), outline (bool, default true).
static func mat(color: Color, opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _toon
	m.set_shader_parameter("albedo", color)
	if opts.has("texture"):
		m.set_shader_parameter("albedo_tex", opts["texture"])
	if opts.has("color2"):
		m.set_shader_parameter("albedo2", opts["color2"])
		m.set_shader_parameter("patch_scale", opts.get("patch_scale", 0.1))
	if opts.has("emission"):
		m.set_shader_parameter("emission", opts["emission"])
	if opts.has("paper"):
		m.set_shader_parameter("paper", opts["paper"])
	if opts.get("vertex_color", false):
		m.set_shader_parameter("use_vertex_color", true)
	if opts.get("outline", true):
		m.next_pass = outline_material()
	return m


static func outline_material() -> ShaderMaterial:
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = _outline
		_outline_mat.set_shader_parameter("ink", INK)
	return _outline_mat


static func font() -> FontFile:
	return _font


## A billboard label in the handwritten font with an ink outline.
static func label3d(text: String, size := 40, pixel_size := 0.012) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = size
	l.pixel_size = pixel_size
	l.outline_size = 10
	l.outline_modulate = INK
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	return l


static func _box(bg: Color, border: Color, radius: int, border_w: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func ui_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = _font
	t.default_font_size = 22
	var border := Color(0.38, 0.25, 0.15)

	t.set_stylebox("panel", "PanelContainer", _box(Color(PAPER, 0.95), border, 12, 3, 12))
	t.set_stylebox("normal", "Button", _box(Color(0.93, 0.83, 0.6), border, 9, 2, 6))
	t.set_stylebox("hover", "Button", _box(Color(0.97, 0.9, 0.7), border, 9, 2, 6))
	t.set_stylebox("pressed", "Button", _box(Color(0.85, 0.72, 0.5), border, 9, 2, 6))
	t.set_stylebox("disabled", "Button", _box(Color(0.9, 0.85, 0.75, 0.6), Color(border, 0.5), 9, 2, 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "Button", TEXT_DARK)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.47, 0.4))

	t.set_stylebox("normal", "LineEdit", _box(Color(PAPER, 0.92), border, 9, 2, 8))
	t.set_stylebox("focus", "LineEdit", _box(PAPER, ACCENT, 9, 2, 8))
	t.set_color("font_color", "LineEdit", TEXT_DARK)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.5, 0.42, 0.35))

	# Labels float over the 3D world: light text with an ink outline.
	t.set_color("font_color", "Label", TEXT_LIGHT)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 7)
	t.set_color("default_color", "RichTextLabel", TEXT_LIGHT)
	t.set_color("font_outline_color", "RichTextLabel", INK)
	t.set_constant("outline_size", "RichTextLabel", 7)

	# Labels inside paper panels: dark ink, no outline.
	t.set_type_variation("PanelLabel", "Label")
	t.set_color("font_color", "PanelLabel", TEXT_DARK)
	t.set_constant("outline_size", "PanelLabel", 0)
	_theme = t
	return t
