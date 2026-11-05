# One-off helper: render res://icon.svg at the PWA icon sizes on a dark background.
# Run: godot --headless --path . --script res://scripts/dev/make_pwa_icons.gd
extends SceneTree


const SIZES := [144, 180, 512]
const BG := Color("0b0f1a")


func _init() -> void:
	var tex: Texture2D = load("res://icon.svg")
	if tex == null:
		push_error("make_pwa_icons: could not load res://icon.svg")
		quit(1)
		return
	var src := tex.get_image()
	# Decompress if the import pipeline handed back a compressed texture.
	if src.is_compressed():
		src.decompress()
	for s in SIZES:
		var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
		img.fill(BG)
		var glyph := src.duplicate()
		# Scale the 128x128 source with a small margin so the border isn't clipped.
		var inner := int(s * 0.82)
		glyph.resize(inner, inner, Image.INTERPOLATE_LANCZOS)
		var at := Vector2i(int((s - inner) / 2.0), int((s - inner) / 2.0))
		img.blend_rect(glyph, Rect2i(0, 0, inner, inner), at)
		var path := "res://assets/branding/icon_%dx%d.png" % [s, s]
		DirAccess.make_dir_recursive_absolute("res://assets/branding")
		var err := img.save_png(path)
		print("make_pwa_icons: ", path, " -> ", err)
	quit(0)
