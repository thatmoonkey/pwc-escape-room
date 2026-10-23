class_name LaunchCutscene
extends Node3D

## The departure, played from the helm.
##
## Three shots, and the sequence is built around one handoff. It opens at the
## helmsman's eye looking forward through the bridge glass - the planet, the
## station and the starfield the crew's bay windows have shown all game - and
## then leaves the ship entirely, so the vessel they have been walking through
## for the whole session is finally seen from outside as it lights its engines
## and goes.
##
## The ship it shows is the corridor the crew actually walked: the kit walls and
## the bridge are real geometry built from these same numbers, so the vessel
## flying away is the vessel they have been inside, not a stand-in.
##
## The renderer is the WorldEnvironment every window already looks through, so
## this adds one camera and one light and touches nothing else - no new sky, no
## lighting change, no second starfield. The viewport is only taken over while
## the sequence runs, and the crew's own camera is restored on every exit path.

signal finished

const SHOT_INTERIOR_END := 1.6
const SHOT_REAR_END := 5.2
const SHOT_END := 14.0

## The helmsman's eye, in the same coordinates the corridor itself uses, so the
## first shot lines up with the room the crew are standing in.
const BRIDGE_EYE := Vector3(0.0, 1.7, 24.2)

## Where the departure burn is lit. This is the HULL's stern, not the corridor's
## aft end: the ship the crew are inside runs 114 m along Z and its aft-most
## geometry is at Z -50.0, so an engine glow at the corridor's aft wall sits about
## 30 m inside the ship and throws its light on nothing the camera can see. Three
## metres behind that stern face and low, so the burn lands on the hull's own
## transom where its nozzles would be.
const ENGINE_GLOW := Vector3(0.0, 3.0, -53.0)

## THE PULL-OUT - the middle shot, and where the crew's exit from the ship is
## faked.
##
## This shot used to begin 11 m INSIDE the ship and travel out through the
## stern, and that is where the visible clipping came from. The hull imports as
## one closed mesh, so from inside it every hull face is a backface and is
## culled: the plating simply disappears and the camera is left looking at the
## module's own interior fittings hanging in space. None of that is meant to be
## seen from outside the ship.
##
## So the shot BEGINS outside the shell and never re-enters it. The hull's
## aft-most geometry is at Z -50.0, and both endpoints below are aft of that, so
## every frame of the pull-out is outside the ship by construction rather than by
## eye. These points moved when the ship model was replaced: the previous hull's
## stern was at Z -38.1, and leaving them where they were would have started the
## shot six metres inside the new one.
##
## What sells the exit is the cut in from the helm: the last inside frame is the
## crew's own view forward, and the first outside frame is the same heading with
## the ship now behind them and the burn lighting its stern.
##
## It ends exactly where the reveal arc begins, so the two shots are one
## continuous move and that join cannot drift apart.
const PULLOUT_EYE := Vector3(17.0, 7.5, -58.0)
const PULLOUT_END := Vector3(6.0, 6.4, -68.0)

## THE REVEAL ARC - the last shot.
##
## The camera used to pull straight back down the ship's own axis, which ends
## with the vessel shrinking to a dot and never shows its shape. Instead it now
## swings around the stern quarter to the ship's LEFT side, so the shot opens
## close behind the vessel and finishes broadside: the whole 114 m hull in
## profile, which is the silhouette the ship is recognised by.
##
## The motion is polar about the hull's long axis - the camera holds a radius
## from that line while the azimuth sweeps from astern to abeam. The ship comes
## into frame by turning rather than by retreating: the first frame is 18 m
## behind the stern with the hull filling it, and by the last the camera is out
## to the side with the whole 114 m vessel in profile. Height and aim are keyed
## separately, and look_at is always given Vector3.UP, so the horizon stays
## level through the whole swing. Roll is never introduced.
##
## The first frame of this shot is the last frame of the previous one, so the
## join between them does not move the camera at all: only what it is aimed at
## changes, from the ship's stern quarter out to the whole vessel.
##
## The ship, from the hull placement receipt: 114.0 m long, along Z from -50.0
## (stern) to 64.0 (bow), 38.4 m tall from Y -12.0, centred in Z at 7.0.
const ARC_CENTRE_Z := 7.0
## Azimuth, where 0 is abeam on the ship's left (+X) and -90 is dead astern.
## Only the finish is written down here: the start's azimuth, radius and height
## are read off PULLOUT_END, because its first frame has to be that point, and a
## second, hand-copied set of numbers is how a join acquires a jump.
const ARC_END_ANGLE := 0.0
## 76 m out frames the whole hull: roughly 60 percent of the frame's width and
## 36 percent of its height at 70 degrees, with margin for a narrower viewport.
## The end height and aim sit close to the ship's own vertical centre (Y 7.2), so
## the profile is read side-on rather than from well above it.
const ARC_END_RADIUS := 76.0
const ARC_END_HEIGHT := 16.0
const ARC_START_LOOK := Vector3(0.0, 1.5, 1.0)
const ARC_END_LOOK := Vector3(0.0, 7.0, ARC_CENTRE_Z)

var _camera: Camera3D = null
var _overlay: CanvasLayer = null
var _player_camera: Camera3D = null
var _engine_glow: OmniLight3D = null
var _title_label: Label = null
var _caption_label: Label = null
var _captions: Array[Dictionary] = []
var _elapsed: float = 0.0
var _running: bool = false


func _ready() -> void:
	_build_camera()
	_build_engine_glow()
	_build_overlay()
	set_overlay_visible(false)
	set_process(false)


## Called by the helm once the crew has ordered the launch.
func play() -> void:
	if _running:
		return
	_running = true
	set_overlay_visible(true)
	set_process(true)
	## Captured here rather than in _ready(): this is the last moment the crew's
	## camera is guaranteed to be the one rendering, and it has to be put back.
	_remember_player_camera()
	if _camera != null:
		_camera.global_position = BRIDGE_EYE
		_camera.look_at(BRIDGE_EYE + Vector3(0.0, 0.0, 1.0), Vector3.UP)
		_camera.current = true
	if _engine_glow != null:
		_engine_glow.light_energy = 0.6
	## The input layer owns the screen, so the crew's look and move input cannot
	## fight the cutscene camera.
	InputRouter.set_ui_blocking(true)
	## The ship undocks as it departs, so the arms holding it to the station go
	## with it. They are welded to both, so they have to leave the shot.
	_set_arms_visible(false)
	if OS.is_debug_build():
		print("[LaunchCutscene] departure started")


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	_drive_shots()
	_advance_captions()
	_fade_overlay()
	if _elapsed >= SHOT_END:
		_finish()


## Shot 1 sits at the helm looking forward through the glass, including the
## ship's own bow in the lower frame. Shot 2 cuts to outside the stern - the
## crew's exit - as the engines light, and shot 3 swings around the hull to
## abeam, ending on its left profile: the whole vessel sideways in frame.
func _drive_shots() -> void:
	if _camera == null:
		return
	if _elapsed < SHOT_INTERIOR_END:
		## A slow push forward at the helm, so the first shot is alive.
		var t: float = clampf(_elapsed / SHOT_INTERIOR_END, 0.0, 1.0)
		_camera.global_position = BRIDGE_EYE.lerp(BRIDGE_EYE + Vector3(0.0, 0.25, 1.1), t)
		_camera.look_at(BRIDGE_EYE + Vector3(0.0, -0.15, 40.0), Vector3.UP)
		_engine(0.6 + 0.8 * t)
	elif _elapsed < SHOT_REAR_END:
		## Outside the shell from the first frame to the last, so the hull is
		## never entered. The burn comes up behind the ship as it gets under way.
		var t: float = clampf((_elapsed - SHOT_INTERIOR_END) / (SHOT_REAR_END - SHOT_INTERIOR_END), 0.0, 1.0)
		_camera.global_position = PULLOUT_EYE.lerp(PULLOUT_END, t)
		_camera.look_at(ARC_START_LOOK, Vector3.UP)
		_engine(2.0 + 3.0 * t)
	else:
		## The reveal: around the stern quarter to broadside on the ship's left,
		## so the last frame is the whole vessel in profile.
		var t: float = clampf((_elapsed - SHOT_REAR_END) / maxf(SHOT_END - SHOT_REAR_END, 0.01), 0.0, 1.0)
		## Eased at both ends, so the swing starts and settles instead of ticking.
		var eased: float = smoothstep(0.0, 1.0, t)
		## The start is read off PULLOUT_END rather than written down again.
		var start: Vector2 = _arc_start_offset()
		var azimuth: float = deg_to_rad(lerpf(rad_to_deg(atan2(start.y, start.x)), ARC_END_ANGLE, eased))
		var radius: float = lerpf(start.length(), ARC_END_RADIUS, eased)
		var height: float = lerpf(PULLOUT_END.y, ARC_END_HEIGHT, eased)
		_camera.global_position = Vector3(
			cos(azimuth) * radius,
			height,
			ARC_CENTRE_Z + sin(azimuth) * radius)
		_camera.look_at(ARC_START_LOOK.lerp(ARC_END_LOOK, eased), Vector3.UP)
		_engine(5.0 + 5.0 * t)


## The reveal arc is polar about the hull's long axis, so its opening frame is
## held as an offset from that axis: Vector2(x, z - ARC_CENTRE_Z). Reading it
## off PULLOUT_END is what keeps the join between the pull-out and the arc
## exact - the same point cannot drift out of agreement with itself the way two
## hand-copied sets of numbers would.
func _arc_start_offset() -> Vector2:
	return Vector2(PULLOUT_END.x, PULLOUT_END.z - ARC_CENTRE_Z)


func _engine(energy: float) -> void:
	if _engine_glow == null:
		return
	## Thrust flicker, so the burn reads as engines rather than as a lamp.
	_engine_glow.light_energy = energy * (0.92 + 0.08 * sin(_elapsed * 26.0))


## Developer shortcut. The departure is the one part of the game that cannot be
## reached in a few seconds - it needs all five systems and the helm - so tuning
## this shot would otherwise cost a full run per attempt. F9 replays it in place.
## Handled here rather than through InputMap, so a development-only key never
## has to appear in project settings.
func _unhandled_input(event: InputEvent) -> void:
	if _running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		play()
		get_viewport().set_input_as_handled()


# --- Build --------------------------------------------------------------------

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "CutsceneCamera"
	_camera.fov = 70.0
	_camera.near = 0.1
	_camera.far = 6000.0
	add_child(_camera)


## Behind the hull's own transom, where the engines are - see ENGINE_GLOW. The
## sun already lights the scene; this only has to read as the crew's own burn
## coming up.
func _build_engine_glow() -> void:
	_engine_glow = OmniLight3D.new()
	_engine_glow.name = "EngineGlow"
	_engine_glow.light_color = Color(1.0, 0.66, 0.32)
	_engine_glow.omni_range = 46.0
	_engine_glow.light_energy = 0.0
	_engine_glow.position = ENGINE_GLOW
	add_child(_engine_glow)


func _build_overlay() -> void:
	## The captions live on their own CanvasLayer, not on this node. This node is
	## a Node3D, so the camera and the engine glow belong to the 3D scene;
	## hanging them off a CanvasLayer would put them outside it. Only the text
	## is 2D.
	_overlay = CanvasLayer.new()
	_overlay.name = "Overlay"
	_overlay.layer = 90
	add_child(_overlay)

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(root)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.modulate = Color(1.0, 0.88, 0.55)
	_title_label.position = Vector2(64.0, 58.0)
	root.add_child(_title_label)

	_caption_label = Label.new()
	_caption_label.name = "Caption"
	_caption_label.add_theme_font_size_override("font_size", 18)
	_caption_label.modulate = Color(0.92, 0.87, 0.82)
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_label.size = Vector2(780.0, 220.0)
	_caption_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_caption_label.position = Vector2(64.0, -244.0)
	root.add_child(_caption_label)

	_captions = [
		{"at": 0.0, "title": "ADAMANT VERITY - DEPARTURE",
			"text": "Course locked: KEPLER-442b. For the first time in this emergency I am flying the course the crew set, not the one I would have chosen."},
		{"at": 1.6, "title": "",
			"text": "Departure burn. Efficient or standard - the order came from a human, and it is on the record either way."},
		{"at": 5.2, "title": "",
			"text": "The Adamant Verity, under way. Thirty-six metres of corridor, walked end to end - now flown by hand."},
		{"at": 9.0, "title": "",
			"text": "Thank you for flying with a human in the loop."},
	]


## The 3D nodes stay live while the sequence is closed and only the text
## toggles, because the camera and the light have to exist in the tree before
## play() can make them current.
func set_overlay_visible(value: bool) -> void:
	if _overlay != null:
		_overlay.visible = value


# --- Captions and exit ---------------------------------------------------------

func _advance_captions() -> void:
	for entry in _captions:
		if _elapsed >= float(entry["at"]):
			var title: String = String(entry["title"])
			var body: String = String(entry["text"])
			if _title_label != null and _title_label.text != title:
				_title_label.text = title
			if _caption_label != null and _caption_label.text != body:
				_caption_label.text = body


## The text eases out over the last seconds so the return of control is a reveal
## rather than a cut.
func _fade_overlay() -> void:
	var fade_in: float = clampf(_elapsed / 0.6, 0.0, 1.0)
	var fade_out: float = clampf((SHOT_END - _elapsed) / 2.0, 0.0, 1.0)
	var alpha: float = minf(fade_in, fade_out)
	if _title_label != null:
		var a: Color = _title_label.modulate
		_title_label.modulate = Color(a.r, a.g, a.b, alpha)
	if _caption_label != null:
		var b: Color = _caption_label.modulate
		_caption_label.modulate = Color(b.r, b.g, b.b, alpha)


func _finish() -> void:
	if not _running:
		return
	_running = false
	set_process(false)
	set_overlay_visible(false)
	if _engine_glow != null:
		_engine_glow.light_energy = 0.0
	## Order matters: the crew's camera has to be made current BEFORE this one
	## stands down, or the viewport would briefly have no camera at all.
	if _player_camera != null and is_instance_valid(_player_camera):
		_player_camera.current = true
	if _camera != null:
		_camera.current = false
	InputRouter.set_ui_blocking(false)
	_set_arms_visible(true)
	if OS.is_debug_build():
		print("[LaunchCutscene] departure complete; control returned")
	finished.emit()


## Hides or restores the docking arms that join the corridor to the station.
func _set_arms_visible(value: bool) -> void:
	for node in get_tree().get_nodes_in_group("docking_arms"):
		var arm := node as Node3D
		if arm != null and is_instance_valid(arm):
			arm.visible = value


## The camera that was rendering before the cutscene took over.
func _remember_player_camera() -> void:
	_player_camera = null
	if _camera == null:
		return
	var viewport := _camera.get_viewport()
	if viewport != null:
		_player_camera = viewport.get_camera_3d()
	if _player_camera != null:
		return
	for node in get_tree().get_nodes_in_group("player_camera"):
		if node is Camera3D:
			_player_camera = node as Camera3D
			return
