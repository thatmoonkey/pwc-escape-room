extends Node

const MAIN_SCENE := "res://scenes/main.tscn"

var _intro_finished := false
var _scene_ready := false
var _switching := false
var _threaded := false
var _load_started := false
var _main_scene: PackedScene = null
var _loading: CanvasLayer = null


func _ready() -> void:
	var intro := $IntroScreen as IntroScreen
	intro.finished.connect(_on_intro_finished)
	_build_loading_message()
	_start_load.call_deferred()


## The request waits one frame: asking for the main scene from inside the boot
## scene's own _ready raced the engine's startup registration and made the
## loader report the station as a missing resource.
func _start_load() -> void:
	await get_tree().process_frame
	_threaded = ResourceLoader.load_threaded_request(MAIN_SCENE, "", true) == OK
	_load_started = true


func _process(_delta: float) -> void:
	if _scene_ready or _switching or not _load_started:
		return
	if _threaded:
		var status := ResourceLoader.load_threaded_get_status(MAIN_SCENE)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_main_scene = ResourceLoader.load_threaded_get(MAIN_SCENE) as PackedScene
			_scene_ready = _main_scene != null
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_threaded = false
	if not _threaded and _intro_finished:
		_main_scene = load(MAIN_SCENE) as PackedScene
		_scene_ready = _main_scene != null
	if _scene_ready and _intro_finished:
		_switch_to_main()


func _on_intro_finished() -> void:
	_intro_finished = true
	if _scene_ready:
		_switch_to_main()
	else:
		_loading.visible = true


func _switch_to_main() -> void:
	if _switching:
		return
	_switching = true
	get_tree().set_meta("shipmind_intro_played", true)
	get_tree().change_scene_to_packed.call_deferred(_main_scene)


func _build_loading_message() -> void:
	_loading = CanvasLayer.new()
	_loading.layer = 140
	_loading.visible = false
	add_child(_loading)
	var label := Label.new()
	label.text = "PREPARING THE SHIP..."
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.position = Vector2(-150.0, -64.0)
	label.size = Vector2(300.0, 32.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.941, 0.722, 0.224))
	label.add_theme_font_size_override("font_size", 16)
	_loading.add_child(label)
