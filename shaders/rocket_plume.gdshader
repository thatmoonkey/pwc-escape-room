shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// One cone of exhaust, drawn additively so overlapping layers build a hot core.
//
// The gradient runs in MODEL space along the cone's own axis rather than
// through UV: the same material is shared by every layer, their mesh heights
// differ, and UVs on a cylinder wrap the circumference rather than running
// nozzle-to-tip, which is what made the old flame read as a smooth flat wedge.
//
// Nothing here is lit. The colour is the light, so energy below 1 keeps the
// flame inside the frame instead of clipping to a white cone.

uniform vec4 flame_color : source_color = vec4(1.0, 0.40, 0.08, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.94, 0.78, 1.0);
uniform float body_energy : hint_range(0.0, 4.0) = 1.1;
uniform float opacity : hint_range(0.0, 1.0) = 0.85;
uniform float tip_fade : hint_range(0.5, 4.0) = 1.5;
/// The mesh height of the cone this material is on, so the model-space axis can
/// be normalised: the mesh is wide at -Y (the bell) and narrow at +Y (the tip).
uniform float cone_height : hint_range(0.01, 8.0) = 1.0;
/// Hot collar right behind the bell, where the gas is still dense.
uniform float collar : hint_range(0.0, 2.0) = 0.0;
/// How much the exhaust breaks up into drifting streaks instead of a smooth
/// gradient. Zero is a clean cone; one is a ragged, turbulent jet.
uniform float turbulence : hint_range(0.0, 1.0) = 0.45;

varying float v_along;

void vertex() {
	// The mesh runs from -Y at the bell to +Y at the tip.
	v_along = clamp(0.5 + VERTEX.y / cone_height, 0.0, 1.0);
}

void fragment() {
	float along = v_along;
	// The cone is a shell, so a face turned away from the lens is the far side
	// of the flame seen through the near side. Fading it out stops the hard
	// silhouette that gives a cone its cardboard look.
	// Both faces of the shell are drawn, so the absolute value is what matters:
	// gas seen face-on is dense, gas at the silhouette is thin, and it does not
	// matter which side of the surface the lens happens to be on.
	float facing = abs(dot(NORMAL, VIEW));
	float rim = smoothstep(0.10, 0.90, facing);

	// Two out-of-phase waves around the circumference: streaks of hotter and
	// cooler gas that drift as the ship burns.
	float streak_a = sin(UV.x * 37.6991 + along * 11.0 - TIME * 5.0);
	float streak_b = sin(UV.x * 20.9 - along * 17.0 + TIME * 3.3);
	float grain = 0.5 + 0.25 * streak_a + 0.25 * streak_b;
	float turb = mix(1.0, 0.35 + 1.15 * grain, turbulence * smoothstep(0.05, 0.8, along));

	float hot_collar = 1.0 + collar * pow(1.0 - along, 8.0);
	float burn = pow(1.0 - along, tip_fade);

	// White-hot at the bell, orange down the plume, gone at the tip.
	vec3 tint = mix(core_color.rgb, flame_color.rgb, smoothstep(0.0, 0.55, along));
	ALBEDO = tint * body_energy * hot_collar;
	ALPHA = burn * rim * opacity * turb;
}
