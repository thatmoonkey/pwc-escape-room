extends Node3D

## Staged review scene for the extracted interior-pack prefabs.
##
## WHY IT MEASURES INSTEAD OF JUST SHOWING. The prefabs carry a custom
## ShaderMaterial, and the two ways of looking at this scene disagree: an
## edit-time staged render drew the prefabs flat white, while a runtime
## screenshot is unavailable in floating-window mode. Neither answers the only
## question that matters - did the ember recolour actually reach the screen.
##
## So the running game reads its own rendered frame back and reports the mean
## colour of the lit geometry. The answer is a number, not an impression:
## a correct warm recolour gives a mean where red is clearly the largest channel,
## and a failed one gives a grey (channels equal) or a cool blue-dominant mean.
##
## Delete once the recolour is confirmed against the art direction.

## A pixel is treated as geometry rather than background above this brightness.
const GEOMETRY_FLOOR := 0.15
## Sample every Nth pixel: a full 1080p readback is not needed for a mean.
const STEP := 4


func _ready() -> void:
	print("[Lineup] ready - measuring the rendered frame")
	## Two frames for the scene to draw, then a post-draw hook so the readback
	## sees a finished frame rather than a cleared one.
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_measure()


func _measure() -> void:
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		print("[Lineup] readback FAILED: no image from the viewport")
		return
	var width := image.get_width()
	var height := image.get_height()
	var total := Vector3.ZERO
	var warm := 0
	var cool := 0
	var grey := 0
	var counted := 0
	for y in range(0, height, STEP):
		for x in range(0, width, STEP):
			var colour := image.get_pixel(x, y)
			if maxf(colour.r, maxf(colour.g, colour.b)) < GEOMETRY_FLOOR:
				continue
			counted += 1
			total += Vector3(colour.r, colour.g, colour.b)
			## Warm means red leads; cool means blue leads. A near-tie is
			## neither, which is what an unresoloured grey surface looks like.
			var lead := colour.r - colour.b
			if lead > 0.02:
				warm += 1
			elif lead < -0.02:
				cool += 1
			else:
				grey += 1
	if counted == 0:
		print("[Lineup] no lit geometry found in the frame (is the camera facing the prefabs?)")
		return
	var mean := total / float(counted)
	print("[Lineup] frame %dx%d geometry_px=%d | mean RGB = %.3f, %.3f, %.3f" % [
		width, height, counted, mean.x, mean.y, mean.z])
	print("[Lineup] warm_px=%d cool_px=%d neutral_px=%d" % [warm, cool, grey])
	print("[Lineup] verdict: %s" % _verdict(mean, warm, cool))
	## The reference cube is deliberately white, so a small neutral count is
	## expected; a dominant cool count is not.
	image.save_png("user://lineup_readback.png")


func _verdict(mean: Vector3, warm: int, cool: int) -> String:
	if warm > cool * 3 and mean.x > mean.z:
		return "WARM - the recolour reached the screen (red leads blue by %.3f)" % (mean.x - mean.z)
	if cool > warm * 3:
		return "COOL - the pack's own blue/teal is still showing, the recolour did NOT apply"
	if absf(mean.x - mean.z) < 0.02 and absf(mean.x - mean.y) < 0.02:
		return "NEUTRAL/GREY - surfaces are rendering without the warm ramp"
	return "MIXED - inspect the saved readback at user://lineup_readback.png"
