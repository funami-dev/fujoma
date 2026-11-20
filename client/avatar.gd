class_name Avatar
extends Node3D
## A player character: Kenney "Animated Characters" model (CC0) with a skin, idle/run/jump
## animations, a name tag and a speech label.

const MODEL_PATH := "res://assets/characters/characterMedium.fbx"
const ANIMATION_PATHS := {
	"idle": "res://assets/characters/animations/idle.fbx",
	"run": "res://assets/characters/animations/run.fbx",
	"jump": "res://assets/characters/animations/jump.fbx",
}
const SKIN_PATHS := [
	"res://assets/characters/skins/survivorMaleB.png",
	"res://assets/characters/skins/survivorFemaleA.png",
	"res://assets/characters/skins/zombieA.png",
	"res://assets/characters/skins/zombieC.png",
]
const MODEL_SCALE := 1.0
const MODEL_YAW := PI  # the model faces +Z, our forward is -Z
const RUN_SPEED_THRESHOLD := 0.8  # m/s
const TELEPORT_SPEED := 30.0  # ignore jumps like entering a house
const SPEECH_SECONDS := 5.0
const EMOTE_SECONDS := 2.0

static var _model_scene: PackedScene
static var _animations: Dictionary = {}  # name -> Animation

var target_position := Vector3.ZERO
var target_yaw := 0.0
var player_id := ""

var _model: Node3D
var _anim: AnimationPlayer
var _current_anim := ""
var _name_label: Label3D
var _speech_label: Label3D
var _speech_left := 0.0
var _emote_left := 0.0
var _last_position := Vector3.INF


var _status_text := ""


## skin: index into SKIN_PATHS, or -1 to pick one from the id.
func setup(id: String, display_name: String, color: Color, skin := -1) -> void:
	player_id = id
	_build_model(skin, Color.WHITE.lerp(color, 0.22))
	_name_label = _make_label(display_name, 2.3, 40)
	_speech_label = _make_label("", 3.0, 40)
	_speech_label.modulate = Color(1, 1, 0.6)


## Persistent text above the head (e.g. "Zzz"), shown whenever nothing is being said.
func set_status(text: String) -> void:
	_status_text = text
	if _speech_left <= 0.0:
		_speech_label.text = text


func set_name_color(color: Color) -> void:
	_name_label.modulate = color


func say(text: String) -> void:
	_speech_label.text = text
	_speech_left = SPEECH_SECONDS


func emote(kind: String) -> void:
	_speech_label.text = "*%s*" % kind
	_speech_left = EMOTE_SECONDS
	_emote_left = EMOTE_SECONDS


func _build_model(skin: int, tint: Color) -> void:
	if _model_scene == null:
		_model_scene = load(MODEL_PATH)
	_model = _model_scene.instantiate()
	_model.scale = Vector3.ONE * MODEL_SCALE
	_model.rotation.y = MODEL_YAW
	add_child(_model)

	# The skin is picked from the player id so everyone looks the same on every client.
	# Players get one of the two human skins (the zombies do not fit the storybook look).
	var skin_index := skin if skin >= 0 else absi(player_id.hash()) % 2
	var mat := Style.mat(tint, {"texture": load(SKIN_PATHS[skin_index]), "paper": 0.06})
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat

	_anim = AnimationPlayer.new()
	_model.add_child(_anim)  # track paths ("Root/Skeleton3D:...") are relative to the model root
	var library := AnimationLibrary.new()
	for anim_name: String in ANIMATION_PATHS:
		library.add_animation(anim_name, _animation(anim_name))
	_anim.add_animation_library("", library)
	_play("idle")


## Loads an animation once from its FBX and shares it between all avatars.
static func _animation(anim_name: String) -> Animation:
	if _animations.has(anim_name):
		return _animations[anim_name]
	var scene: Node = (load(ANIMATION_PATHS[anim_name]) as PackedScene).instantiate()
	var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
	var found: Animation = null
	for a in player.get_animation_list():
		if a.to_lower().ends_with(anim_name):
			found = player.get_animation(a)
	scene.free()
	if found == null:
		found = Animation.new()
	found.loop_mode = Animation.LOOP_LINEAR
	_animations[anim_name] = found
	return found


func _play(anim_name: String) -> void:
	if _anim == null or anim_name == _current_anim:
		return
	_current_anim = anim_name
	_anim.play(anim_name, 0.15)


func _make_label(text: String, height: float, size: int) -> Label3D:
	var label := Style.label3d(text, size)
	label.position.y = height
	add_child(label)
	return label


func _process(delta: float) -> void:
	if _speech_left > 0.0:
		_speech_left -= delta
		if _speech_left <= 0.0:
			_speech_label.text = _status_text
	if _emote_left > 0.0:
		_emote_left -= delta

	var speed := 0.0
	if _last_position != Vector3.INF and delta > 0.0:
		speed = position.distance_to(_last_position) / delta
	_last_position = position
	if speed > TELEPORT_SPEED:
		speed = 0.0

	if _emote_left > 0.0:
		_play("jump")
	elif speed > RUN_SPEED_THRESHOLD:
		_play("run")
	else:
		_play("idle")
