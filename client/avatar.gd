class_name Avatar
extends Node3D
## A player character: colored capsule with a nose, a name tag and a speech label.

const SPEECH_SECONDS := 5.0
const EMOTE_SECONDS := 2.0

var target_position := Vector3.ZERO
var target_yaw := 0.0
var player_id := ""

var _body: MeshInstance3D
var _name_label: Label3D
var _speech_label: Label3D
var _speech_left := 0.0
var _emote_left := 0.0


func setup(id: String, display_name: String, color: Color) -> void:
	player_id = id

	_body = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	capsule.material = mat
	_body.mesh = capsule
	_body.position.y = 0.8
	add_child(_body)

	# Nose marks the facing direction (-Z is forward).
	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.18, 0.3)
	nose.mesh = box
	nose.position = Vector3(0, 1.1, -0.45)
	add_child(nose)

	_name_label = _make_label(display_name, 2.0, 40)
	_speech_label = _make_label("", 2.7, 40)
	_speech_label.modulate = Color(1, 1, 0.6)


func say(text: String) -> void:
	_speech_label.text = text
	_speech_left = SPEECH_SECONDS


func emote(kind: String) -> void:
	_speech_label.text = "*%s*" % kind
	_speech_left = EMOTE_SECONDS
	_emote_left = EMOTE_SECONDS


func _make_label(text: String, height: float, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.012
	label.font_size = size
	label.outline_size = 8
	label.position.y = height
	add_child(label)
	return label


func _process(delta: float) -> void:
	if _speech_left > 0.0:
		_speech_left -= delta
		if _speech_left <= 0.0:
			_speech_label.text = ""
	if _emote_left > 0.0:
		_emote_left -= delta
		_body.position.y = 0.8 + absf(sin(_emote_left * 12.0)) * 0.4
	else:
		_body.position.y = 0.8
