shader_type canvas_item;

// Shipmind CRT overlay — draw this on a full-rect ColorRect ABOVE the
// leaderboard UI. It only darkens: pixel-perfect scanlines, a rounded-tube
// vignette, and a faint 24 fps brightness flicker. Everything animated
// underneath stays interactive and sharp.

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.30;
uniform float scanline_pitch = 3.0;                        // pixels per line
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;
uniform float flicker_strength : hint_range(0.0, 0.2) = 0.04;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	// Horizontal scanlines, locked to physical pixels.
	float scan = step(0.5, fract(FRAGCOORD.y / scanline_pitch)) * scanline_strength;

	// Vignette: squared falloff toward the edges, heavier in the corners,
	// approximating the curvature shadow of a CRT tube.
	vec2 d = abs(UV - 0.5) * 2.0;
	float vig = pow(max(d.x, d.y), 3.0) * vignette_strength;
	vig += pow(dot(d, d) * 0.5, 2.0) * vignette_strength * 0.5;

	// Global flicker at a stepped 24 Hz, plus a whisper of per-frame noise.
	float flick = (hash(floor(TIME * 24.0)) - 0.5) * 2.0 * flicker_strength;

	float a = clamp(scan + vig + flick, 0.0, 1.0);
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
