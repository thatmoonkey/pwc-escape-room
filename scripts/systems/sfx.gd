class_name Sfx
extends RefCounted

## Every sound in the game, in one place.
##
## The players are SCENE NODES in main.tscn (the looping beds "sfx_ambience" and
## "sfx_music", the one-shots "sfx_voice") rather than being created on demand at
## runtime. That is the whole point of this revision:
##
## Adding a child to the scene root from another node's _ready() fails with
## "Parent node is busy setting up children, add_child() failed", and a play()
## on a player that never entered the tree then fails with "Playback can only
## happen when a node is inside the scene tree". That is exactly how the ambience
## came out silent. Scene nodes exist in the tree before any script's _ready()
## runs, so there is no timing window at all.
##
## If the scene nodes are ever missing, this falls back to creating a player
## under the scene root, deferred, and starts it when it actually enters the
## tree - so a one-shot is never silently dropped.

const COMPUTER := "res://assets/audio/computer_opening.mp3"
const DOOR := "res://assets/audio/door_opening.mp3"
const AMBIENCE := "res://assets/audio/space_ambience.mp3"
const MUSIC := "res://assets/audio/spacemusic.mp3"

const VOICE_GROUP := "sfx_voice"
const AMBIENCE_GROUP := "sfx_ambience"
const MUSIC_GROUP := "sfx_music"

## THE MIX. A level is written as a fraction of full scale because that is how a
## mix gets discussed, and the decibel value is derived from it rather than typed
## beside it, so the two cannot drift apart.
##
## Do not read a percentage as decibels. The conversion is logarithmic, so half
## scale is -6 dB and a third is about -10.5 dB rather than -50 and -70. Two of
## these sit much lower in decibels than their percentage suggests, which is why
## the arithmetic is done here rather than guessed at by hand.
const VOICE_LEVEL := 0.50
const AMBIENCE_LEVEL := 0.30
const MUSIC_LEVEL := 0.60

## One-shots are spread over the scene's voice players so a console opening over
## a door does not cut the first sound short.
static var _next: int = 0
static var _cache: Dictionary = {}

## Fallback players, only used if the scene has none. The looping beds keep one
## per group, so a scene missing its music node can never be handed the ambience
## player and left with no ambience at all.
static var _spare: Array[AudioStreamPlayer] = []
static var _spare_loops: Dictionary = {}
static var _pending: Dictionary = {}


## Fire a one-shot. Safe to call from anywhere, including during _ready.
static func play(path: String, level: float = VOICE_LEVEL) -> void:
	var player: AudioStreamPlayer = _free_voice()
	if player == null:
		push_warning("Sfx: no voice player available for '%s'." % path)
		return
	var stream: AudioStream = _stream(path, false)
	if stream == null:
		return
	player.stream = stream
	player.volume_db = level_to_db(level)
	player.play()


## The room tone, running under everything for the whole session.
static func play_ambience(path: String = AMBIENCE, level: float = AMBIENCE_LEVEL) -> void:
	_start_loop(AMBIENCE_GROUP, path, level)


## The soundtrack. Same contract as the ambience, and deliberately a SEPARATE
## player: both beds run at once, so they cannot share one.
static func play_music(path: String = MUSIC, level: float = MUSIC_LEVEL) -> void:
	_start_loop(MUSIC_GROUP, path, level)


static func stop_ambience() -> void:
	_stop_loop(AMBIENCE_GROUP)


static func stop_music() -> void:
	_stop_loop(MUSIC_GROUP)


## Start a looping bed. Safe to call more than once: a call while it is already
## playing does nothing, which keeps it seamless across a scene reload.
static func _start_loop(group: String, path: String, level: float) -> void:
	var player: AudioStreamPlayer = _loop_voice(group, path, level_to_db(level))
	if player == null:
		push_warning("Sfx: no player in group '%s' available for '%s'." % [group, path])
		return
	if player.playing:
		return
	## The fallback player is added deferred, so it can still be a frame away from
	## entering the tree. Playing it now would error, so its tree_entered handler
	## starts it instead.
	if not player.is_inside_tree():
		return
	player.play()


static func _stop_loop(group: String) -> void:
	var tree: SceneTree = _tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group(group):
		if node is AudioStreamPlayer:
			(node as AudioStreamPlayer).stop()
	var spare: AudioStreamPlayer = _spare_loops.get(group, null)
	if spare != null and is_instance_valid(spare):
		spare.stop()


## A level expressed as a fraction of full scale, as decibels. Decibels are
## logarithmic, so this is arithmetic rather than a shift of the decimal point:
## 0.5 is -6 dB and 0.3 is about -10.5 dB. The floor exists only so that a level
## of exactly zero cannot produce a negative infinity.
static func level_to_db(level: float) -> float:
	return linear_to_db(clampf(level, 0.0001, 1.0))


## The player for a looping bed. Prefers the scene node carrying that group;
## otherwise creates one deferred and starts it on tree_entered, so it is never
## played from outside the tree.
static func _loop_voice(group: String, path: String, volume_db: float) -> AudioStreamPlayer:
	var tree: SceneTree = _tree()
	if tree == null:
		return null
	for node in tree.get_nodes_in_group(group):
		if node is AudioStreamPlayer:
			var player: AudioStreamPlayer = node
			if player.stream == null:
				player.stream = _stream(path, true)
			## Set whether or not the stream was just assigned. A bed saved with
			## a stream already on it would otherwise keep the volume it was
			## saved with and quietly ignore the mix.
			player.volume_db = volume_db
			return player
	var spare: AudioStreamPlayer = _spare_loops.get(group, null)
	if spare != null and is_instance_valid(spare):
		return spare
	spare = AudioStreamPlayer.new()
	spare.name = "SfxLoop_%s" % group
	spare.add_to_group(group)
	_spare_loops[group] = spare
	_pending[group] = {"path": path, "db": volume_db}
	spare.tree_entered.connect(_on_spare_loop_ready.bind(group), Object.CONNECT_ONE_SHOT)
	tree.root.add_child.call_deferred(spare)
	return null


static func _on_spare_loop_ready(group: String) -> void:
	var spare: AudioStreamPlayer = _spare_loops.get(group, null)
	if spare == null or not is_instance_valid(spare):
		return
	var pending: Dictionary = _pending.get(group, {})
	var stream: AudioStream = _stream(String(pending.get("path", "")), true)
	if stream == null:
		return
	spare.stream = stream
	spare.volume_db = float(pending.get("db", -6.0))
	if not spare.playing:
		spare.play()


## A voice for a one-shot: an idle scene player, else round-robin over them, else
## a spare created under the scene root.
static func _free_voice() -> AudioStreamPlayer:
	var tree: SceneTree = _tree()
	if tree == null:
		return null
	var voices: Array[Node] = tree.get_nodes_in_group(VOICE_GROUP)
	for node in voices:
		if node is AudioStreamPlayer and not (node as AudioStreamPlayer).playing:
			return node
	if not voices.is_empty():
		_next = (_next + 1) % voices.size()
		var reused: Node = voices[_next]
		if reused is AudioStreamPlayer:
			return reused
	# No scene voices at all: keep a small spare pool under the scene root.
	for player in _spare:
		if is_instance_valid(player) and not player.playing:
			return player
	if _spare.size() >= 4:
		return _spare[0] if is_instance_valid(_spare[0]) else null
	var created := AudioStreamPlayer.new()
	created.name = "SfxSpare%d" % _spare.size()
	created.add_to_group(VOICE_GROUP)
	tree.root.add_child.call_deferred(created)
	_spare.append(created)
	return created


## Loads and caches one stream. MP3 and Ogg both need their loop flag set at
## runtime, because the import setting cannot be read back from a script.
static func _stream(path: String, loop: bool) -> AudioStream:
	var cached: AudioStream = _cache.get(path, null)
	if cached != null:
		## The loop flag is re-applied rather than assumed. load() hands back ONE
		## shared resource per path, so the flag lives on that shared resource:
		## without this, whichever caller asked last would decide whether a bed
		## loops, and a one-shot probe listed before the soundtrack started would
		## leave the music playing exactly once.
		if loop:
			_apply_loop(cached)
		return cached
	var resource: Resource = load(path)
	if resource == null or not (resource is AudioStream):
		push_warning("Sfx: could not load '%s' as an audio stream." % path)
		return null
	var stream: AudioStream = resource
	if loop:
		_apply_loop(stream)
	_cache[path] = stream
	return stream


static func _apply_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true


## A one-line report of the audio state, for the boot log. Read-only: it proves
## each clip resolves and whether the beds are actually running at the level the
## mix asks for, but never plays anything itself. The percentage is reported
## beside the decibels because this log gets read against the mix, and nobody
## should have to convert -10.5 into thirty percent in their head to check it.
static func debug_state() -> String:
	var tree: SceneTree = _tree()
	if tree == null:
		return "no scene tree"
	return "ambience %s | music %s | voices=%d | clips: computer=%s door=%s music=%s" % [
		_bed_state(AMBIENCE_GROUP),
		_bed_state(MUSIC_GROUP),
		tree.get_nodes_in_group(VOICE_GROUP).size(),
		str(_stream(COMPUTER, false) != null),
		str(_stream(DOOR, false) != null),
		str(_stream(MUSIC, true) != null),
	]


## One looping bed's state: how many players carry the group, and what the first
## of them is doing.
static func _bed_state(group: String) -> String:
	var tree: SceneTree = _tree()
	if tree == null:
		return "no scene tree"
	var nodes: Array[Node] = tree.get_nodes_in_group(group)
	for node in nodes:
		if node is AudioStreamPlayer:
			var player: AudioStreamPlayer = node
			if player.stream == null:
				return "[%d] no stream" % nodes.size()
			return "[%d] playing=%s stream=%s vol=%.1f (%.0f%%)" % [
				nodes.size(),
				str(player.playing),
				player.stream.resource_path,
				player.volume_db,
				db_to_linear(player.volume_db) * 100.0,
			]
	return "MISSING"


static func _tree() -> SceneTree:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return loop as SceneTree
	return null
