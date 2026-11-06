extends SceneTree

## Headless check: the leaderboard client fetches, parses and emits against
## the live API. Run:
##   godot --headless --path . -s res://tests/client_check.gd

var _client: Node = null
var _started := false
var _done := false
var _ticks := 0


func _initialize() -> void:
	_client = load("res://assets/ui/LeaderboardClient.gd").new()


func _process(_delta: float) -> bool:
	# request() refuses until the tree is live, so start on the first frame.
	if not _started:
		_started = true
		root.add_child(_client)
		# Web resolves this in _ready via the JS bridge; headless has no
		# bridge, so pin the test site's URL directly.
		_client.BASE_URL = "https://pwc-iom-space-l.netlify.app/api"
		_client.leaderboard_received.connect(func(entries: Array, total: int) -> void:
			print("CLIENT CHECK: board ok — %d entries, %d players" % [entries.size(), total])
			for e in entries.slice(0, 3):
				print("  rank %s  %s  %s" % [e.get("rank"), e.get("player_name"), e.get("score")])
			_finish(true))
		_client.request_failed.connect(func(action: String, message: String) -> void:
			print("CLIENT CHECK: FAILED — %s: %s" % [action, message])
			_finish(false))
		_client.fetch_leaderboard("default", 5)
	elif not _done:
		_ticks += 1
		if _ticks > 600:
			print("CLIENT CHECK: TIMEOUT")
			_finish(false)
	return false


func _finish(ok: bool) -> void:
	if _done:
		return
	_done = true
	print("CLIENT CHECK: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
