shader_type spatial;

// Discards the starship hull inside the boxes the crew module occupies, and
// inside the windows it looks out of.
//
// The ship imports as ONE closed mesh with ONE surface and no separate interior
// geometry, so there is nothing to delete from it. Instead the hull is discarded
// wherever a fragment falls inside one of the boxes ship_hull.gd computes.
//
// THE BOXES COME IN TWO KINDS, and both are needed:
//
//   the interiors  one box per region the crew can stand in. These remove the
//                  ship's own plating where it crosses a corridor or a room, so
//                  the compartments are clear. Each one stops at the interior's
//                  outer surface and stays inside the ship's skin, so the
//                  exterior is untouched by them.
//
//   the windows    one box per bay window, extruded outward past the hull's
//                  measured skin. These are the only boxes that deliberately
//                  open the exterior, because a window is meant to be a hole in
//                  the ship.
//
// WHAT THIS REPLACED, AND WHY IT MATTERS. The cut was once one box around the
// whole crew module, out to the 16.5 m half beam: it let the windows work, but it
// threw away every fragment of ship between the stairwell's aft bulkhead and the
// cockpit canopy, so the ship read as sliced open from outside. Narrowing it to
// the windows alone put the exterior back but left hull standing in the rooms.
// Both families together are the only arrangement that is right in both
// directions.
//
// Everything outside the boxes draws normally, with the model's own texture
// carried across from its imported material.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool use_texture = false;
uniform float hull_roughness : hint_range(0.0, 1.0) = 0.85;
uniform float hull_metallic : hint_range(0.0, 1.0) = 0.0;

// The boxes, in WORLD space. A fragment strictly inside any of them is not drawn.
//
// The arrays are a fixed size because a shader uniform array is, and the size
// must match MAX_CUTS in scripts/world/ship_hull.gd. Unused slots are left as a
// box with no inside (min == max), which nothing can be strictly inside, and
// cut_count says how many are real.
uniform int cut_count = 0;
uniform vec3 cut_min[16];
uniform vec3 cut_max[16];

varying vec3 world_pos;

void vertex() {
	// World position is computed per vertex and interpolated, rather than read
	// back from the view matrix in fragment(), so this does not depend on which
	// view-matrix built-ins the running renderer exposes.
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	for (int i = 0; i < 16; i++) {
		if (i >= cut_count) {
			break;
		}
		if (all(greaterThan(world_pos, cut_min[i])) && all(lessThan(world_pos, cut_max[i]))) {
			discard;
		}
	}
	vec3 base = use_texture ? texture(albedo_tex, UV).rgb : vec3(1.0);
	ALBEDO = base * albedo_color.rgb;
	ROUGHNESS = hull_roughness;
	METALLIC = hull_metallic;
}
