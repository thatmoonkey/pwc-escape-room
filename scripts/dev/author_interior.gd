extends Node3D

## Runs every interior authoring tool in one pass, so a layout change is one run
## rather than three:
##
##   run scenes/dev/author_interior.tscn once
##     -> res://scenes/world/deck1.tscn
##     -> res://scenes/world/stairwell.tscn
##     -> res://scenes/world/deck2.tscn
##
## Each tool is a scene of its own and writes its own file; this only instantiates
## them in build order and prints one line at the end. It changes nothing else,
## and the game never calls it.
##
## The tools share deck_builder.gd, and a change to THAT is why this exists: the
## shared vocabulary moves deck 1, the stairwell and deck 2 at once, and
## regenerating only some of them leaves the decks disagreeing about the walls
## they share.

const TOOLS: Array[String] = [
	"res://scenes/dev/author_deck1.tscn",
	"res://scenes/dev/author_stairwell.tscn",
	"res://scenes/dev/author_deck2.tscn",
]


func _ready() -> void:
	var built: Array[String] = []
	for path in TOOLS:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			print("[Author] could not load %s" % path)
			continue
		add_child(packed.instantiate())
		built.append(path.get_file().get_basename())
	print("[Author] interior rebuilt: %s" % ", ".join(built))
