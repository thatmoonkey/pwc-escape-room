extends DeckBuilder

## One-off authoring tool for the bridge (the cockpit), the last room on the
## ship that was still built at load instead of authored:
##
##   run scenes/dev/author_cockpit.tscn once -> writes res://scenes/world/cockpit.tscn
##
## Same contract as author_deck1.gd, author_deck2.gd and author_stairwell.gd:
## the shared machinery - how a piece is built, instanced and owned, and the
## receipt - lives in deck_builder.gd, and this file is ONLY the layout. The game
## never calls this.
##
## The bridge is NOT on the pack's 3.50 m module: it is the one chamber on the
## vessel that is not made of kit modules, which is why it was built from boxes
## in cockpit_room.gd and is built from the same boxes here. The grid helpers
## (_deck_slab, _wall_run_x/z, _window, _doorway) are deliberately unused.
##
## Nothing about the room changes in the move from load-time to authored: floor
## top y 0, ceiling underside y 3.4, interior half width 2.985, Z 17.5..28.15,
## and the helm console stands at Z 22.6, on the CockpitHelm aim volume that
## station.tscn already carries. The two material decisions that DO change are
## noted where they are made.

const OUT := "res://scenes/world/cockpit.tscn"
const TAG := "Cockpit"

## Floor top, ceiling underside, interior half width, and the two end planes.
## NEAR is the deck 1 spine's forward end plane, so the two floors meet on one
## line instead of leaving a strip of nothing between them.
const HALF_W := 2.985
const HEIGHT := 3.4
const NEAR := 17.5
const FAR := 28.15
const LENGTH := FAR - NEAR
const MID := NEAR + LENGTH * 0.5

## Where the helm console stands. This is the position the CockpitHelm
## interaction body already occupies in station.tscn, so the visible console,
## its aim volume and its collision box are one object rather than three that
## nearly agree.
const HELM_Z := 22.6
## The two crew seats: aft of the helm, facing it, either side of the centreline.
const SEAT_Z := 21.0
const SEAT_X := 0.85

const CONSOLE_MODEL := "res://assets/library/shooter-scifi/sci-fi-computer-desk-console.glb"
const CHAIR := "res://assets/library/shooter-scifi/scifi-furniture-05.glb"
## The same freestanding terminal the deck 1 and deck 2 junctions use.
const KIOSK_MODEL := "res://assets/library/shooter-scifi/futuristic-free-standing-terminal.glb"
## Console height, not the model's own: the terminal is fitted to this so both
## the kiosk and the helm read as furniture of one height.
const KIOSK_HEIGHT := 1.35
const S_PAINT := "res://scripts/world/prop_paint.gd"

const PANEL := "res://materials/panel_light.tres"
const TRIM := "res://materials/trim_black.tres"
const FLOOR := "res://materials/floor_dark.tres"
## The bridge's instrument glow. This was accent_cyan until the room was
## authored; the project keeps no cool hue inside the hull now - every strip on
## both decks is amber - so the bridge's strips and screens are amber too.
const ACCENT := "res://materials/accent_amber.tres"
const GLASS := "res://materials/window_glass.tres"
const SEAT := "res://materials/seat_warm.tres"


func _ready() -> void:
	_begin("Cockpit", OUT, TAG)
	_build()
	_finish(" | half_w=%.3f height=%.2f z=%.1f..%.1f | helm_z=%.1f | seats=2 | kiosks=1" % [
		HALF_W, HEIGHT, NEAR, FAR, HELM_Z])


func _build() -> void:
	var shell := _node("Shell", _root)
	var canopy := _node("Canopy", _root)
	var detail := _node("Detail", _root)
	var furniture := _node("Furniture", _root)
	var lights := _node("Lights", _root)

	## Floor, ceiling and the two side walls. Each body carries its own collision,
	## so the room is safe to stand in the moment it loads rather than only after
	## something else has been built around it.
	_block(shell, "Floor", Vector3(HALF_W * 2.0, 0.4, LENGTH), Vector3(0.0, -0.2, MID), FLOOR)
	_block(shell, "Ceiling", Vector3(HALF_W * 2.0, 0.4, LENGTH), Vector3(0.0, HEIGHT + 0.2, MID), PANEL)
	_block(shell, "Port", Vector3(0.3, HEIGHT, LENGTH), Vector3(-HALF_W - 0.15, HEIGHT * 0.5, MID), PANEL)
	_block(shell, "Starboard", Vector3(0.3, HEIGHT, LENGTH), Vector3(HALF_W + 0.15, HEIGHT * 0.5, MID), PANEL)

	## The forward end is a canopy: a frame with glass in it, not a panel. The
	## glass is drawn a touch larger than the opening it fills, so no seam of
	## space shows between frame and pane, and it carries no collision of its own
	## - the bulkhead behind it does, on the same layer as every other wall, so
	## the crew look out rather than step out.
	var post := 0.6
	_block(canopy, "Canopy_Port", Vector3(post, HEIGHT, 0.3),
		Vector3(-(HALF_W - post * 0.5), HEIGHT * 0.5, FAR), TRIM)
	_block(canopy, "Canopy_Starboard", Vector3(post, HEIGHT, 0.3),
		Vector3(HALF_W - post * 0.5, HEIGHT * 0.5, FAR), TRIM)
	_block(canopy, "Canopy_Header", Vector3(HALF_W * 2.0, 0.6, 0.3),
		Vector3(0.0, HEIGHT - 0.3, FAR), TRIM)
	_block(canopy, "Canopy_Sill", Vector3(HALF_W * 2.0, 0.5, 0.3),
		Vector3(0.0, 0.25, FAR), TRIM)
	_deco(canopy, "Canopy_Glass", Vector3(4.9, 2.4, 0.06),
		Vector3(0.0, HEIGHT * 0.5 + 0.05, FAR), GLASS)
	_collider(shell, "CanopyBulkhead", Vector3(HALF_W * 2.0, HEIGHT, 0.3),
		Basis(), Vector3(0.0, HEIGHT * 0.5, FAR))

	## The two long strips that tie the bridge to the rest of the ship, and floor
	## lines so the room reads as having a centre rather than as open deck.
	for side in [-1.0, 1.0]:
		_deco(detail, "Accent_%d" % int(side), Vector3(0.04, 0.5, LENGTH - 1.0),
			Vector3(side * (HALF_W - 0.02), 2.0, MID), ACCENT)
		_deco(detail, "FloorStrip_%d" % int(side), Vector3(0.05, 0.02, LENGTH - 2.0),
			Vector3(side * 1.1, 0.01, MID), ACCENT)

	## Where the crew fly from, aft to forward: the console, the two seats that
	## face it, the desks either side, the instrument bank along the canopy and
	## the overhead panel. One console, two seats.
	_helm(furniture)
	_seats(furniture)
	_kiosks(furniture)

	_block(furniture, "ForwardBank", Vector3(4.4, 0.85, 0.6), Vector3(0.0, 0.425, 27.4), TRIM)
	_deco(furniture, "ForwardBankFace", Vector3(4.4, 0.28, 0.05), Vector3(0.0, 0.62, 27.11), ACCENT)
	_deco(furniture, "ForwardBankTop", Vector3(4.4, 0.05, 0.6), Vector3(0.0, 0.875, 27.4), ACCENT)

	_deco(furniture, "Overhead", Vector3(4.6, 0.22, 1.5), Vector3(0.0, 3.14, HELM_Z), TRIM)
	_deco(furniture, "OverheadStrip_A", Vector3(4.4, 0.03, 0.1), Vector3(0.0, 3.02, HELM_Z - 0.5), ACCENT)
	_deco(furniture, "OverheadStrip_B", Vector3(4.4, 0.03, 0.1), Vector3(0.0, 3.02, HELM_Z + 0.5), ACCENT)
	_deco(furniture, "OverheadReadout", Vector3(4.2, 0.04, 0.6), Vector3(0.0, 3.02, HELM_Z), ACCENT)

	for side in [-1.0, 1.0]:
		for z in [20.5, 25.4]:
			_deco(furniture, "SideScreen_%d_%d" % [int(side), int(z)], Vector3(0.05, 0.72, 1.35),
				Vector3(side * (HALF_W - 0.06), 1.72, float(z)), ACCENT)

	## One light per third of the room, high, the same warm fit the decks use -
	## the bridge had none of its own before and relied on the sun through the
	## canopy, which left the aft half of it in the dark.
	_light(lights, "Bridge_Aft", Vector3(0.0, HEIGHT - 0.45, 19.6))
	_light(lights, "Bridge_Helm", Vector3(0.0, HEIGHT - 0.45, HELM_Z))
	_light(lights, "Bridge_Canopy", Vector3(0.0, HEIGHT - 0.45, 26.4))


## The helm console itself: the collection's control station, and the one piece
## of real furniture on the bridge rather than a box. It is placed at identity
## because the model carries its screens on its own -Z, which faces the seats -
## and its base reaches the aim volume the crew stand in.
##
## It is deliberately NOT built as a console interactable: station.tscn already
## carries the CockpitHelm body, its aim volume and the flight puzzle on it, and
## a second aim target here would sit inside the first.
func _helm(parent: Node3D) -> void:
	var scene: PackedScene = load(CONSOLE_MODEL) as PackedScene
	if scene == null:
		_problems.append("helm console did not load: " + CONSOLE_MODEL)
		return
	var model := scene.instantiate() as Node3D
	if model == null:
		_problems.append("helm console is not a Node3D: " + CONSOLE_MODEL)
		return
	model.name = "HelmConsole"
	parent.add_child(model)
	model.position = Vector3(0.0, 0.0, HELM_Z)
	_own(model)
	_count["HelmConsole"] = int(_count.get("HelmConsole", 0)) + 1


## Two crew stations, either side of the centreline, turned to face AFT - away
## from the helm, so the crew sit with their backs to the console and face the
## room they came in through.
##
## Each is a holder carrying prop_paint.gd with the chair instanced under it,
## rather than the chair alone: the chair ships green and has to be repainted
## warm, and a material override written straight onto the instanced model's
## children does not survive being packed. The holder's repaint runs at load.
##
## The chair arrives mesh-only, so it also gets a blocker of its own. Without one
## the crew walk straight through the seat they are meant to sit at.
func _seats(parent: Node3D) -> void:
	var scene: PackedScene = load(CHAIR) as PackedScene
	if scene == null:
		_problems.append("crew chair did not load: " + CHAIR)
	for side in [-1.0, 1.0]:
		var holder := _node("Seat_%d" % int(side), parent)
		holder.position = Vector3(side * SEAT_X, 0.0, SEAT_Z)
		## The chair faces the way its crew do: aft, away from the helm.
		holder.rotation.y = 0.0
		holder.set_script(load(S_PAINT))
		holder.set("material_path", SEAT)
		if scene != null:
			var chair := scene.instantiate() as Node3D
			if chair != null:
				chair.name = "Chair"
				holder.add_child(chair)
				_own(chair)
				_count[CHAIR.get_file()] = int(_count.get(CHAIR.get_file(), 0)) + 1
		_collider(parent, "SeatBlocker_%d" % int(side), Vector3(0.85, 0.85, 0.75),
			Basis(), Vector3(side * SEAT_X, 0.425, SEAT_Z))


## One SHIPMIND kiosk, standing in the middle of the bridge floor, where the two
## plain deck blocks used to flank the helm.
##
## The pair of terminals that replaced them either side of the console read as a
## wall of screens rather than as furniture, so it is one console at the centre
## of the room instead: the same freestanding terminal the two junctions use,
## turned side-on to the seats.
##
## It is scenery, not an interactable. The kiosks that carry the mission readout
## are the deck 1 and deck 2 junction terminals.
func _kiosks(parent: Node3D) -> void:
	var scene: PackedScene = load(KIOSK_MODEL) as PackedScene
	if scene == null:
		_problems.append("cockpit kiosk did not load: " + KIOSK_MODEL)
		return
	var model := scene.instantiate() as Node3D
	if model == null:
		_problems.append("cockpit kiosk is not a Node3D")
		return
	model.name = "BridgeKiosk"
	parent.add_child(model)
	## The junction yaw, turned a quarter turn clockwise: side-on to the seats.
	model.rotation.y = QUARTER_TURN + HALF_TURN - QUARTER_TURN
	_fit_kiosk(model, Vector3(0.0, 0.0, MID))
	_own(model)
	_count[KIOSK_MODEL.get_file()] = int(_count.get(KIOSK_MODEL.get_file(), 0)) + 1
	## No collider of its own: it stands on the helm's interaction volume, which
	## is already solid, and a second body inside that volume could only get in
	## the way of aiming at the helm.


## Sizes the terminal to a console and stands it on the deck under `target`.
##
## The model cannot simply be dropped in: it imports at its own scale, and its
## cabinet sits about five metres off its own origin, so a plain instance lands
## a fifth of a metre tall, half a room away, behind a wall. Measuring it and
## fitting it means the number that matters - how tall the thing is at the seat -
## is the one written down, whatever the exporter did.
func _fit_kiosk(model: Node3D, target: Vector3) -> void:
	model.force_update_transform()
	var box: AABB = _mesh_bounds(model)
	if box.size.y < 0.01:
		_problems.append("cockpit kiosk measured nothing")
		return
	model.scale = Vector3.ONE * (KIOSK_HEIGHT / box.size.y)
	model.force_update_transform()
	box = _mesh_bounds(model)
	model.position = target + Vector3(
		-(box.position.x + box.size.x * 0.5),
		-box.position.y,
		-(box.position.z + box.size.z * 0.5))


## The bounds of every mesh under `node`, in the space its parent uses.
func _mesh_bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first: bool = true
	for child in _walk(node):
		var mesh := child as MeshInstance3D
		if mesh == null or not mesh.visible:
			continue
		var mesh_box: AABB = mesh.global_transform * mesh.get_aabb()
		if first:
			box = mesh_box
			first = false
		else:
			box = box.merge(mesh_box)
	return box
