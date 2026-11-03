shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Ember recolour for the interior prefab kits.
//
// The Sketchfab kits in res://assets/kit ship cool teal and blue albedo
// textures, and the interior palette in res://docs/art-direction.md allows no
// cool blue or green. Rather than throw the kits' panel detail away, this shader
// reads each albedo as pure luminance and maps that luminance onto a warm ramp:
// a dark panel seam becomes tint_low, a lit plate face becomes tint_high. The
// normal map is passed through, so the modelled seams and rivets keep their
// shading, and the kit's own emission map is re-tinted with glow_tint so screens
// and light strips glow amber instead of cyan.
//
// cull_disabled matches the kits' own materials (cull_mode disabled): several of
// their parts are single quads with no back face, and would vanish from one side
// if back-face culling were on.

uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform sampler2D normal_texture : hint_normal;
uniform sampler2D emission_texture : source_color, hint_default_black;

// Warm ramp. The defaults are the interior's light neutral over a darker
// seam - a white ship, quiet, with the brand's orange kept as the glow and
// accent rather than as surface.
uniform vec3 tint_low : source_color = vec3(0.720, 0.710, 0.690);
uniform vec3 tint_high : source_color = vec3(0.910, 0.900, 0.880);
uniform vec3 glow_tint : source_color = vec3(0.992, 0.380, 0.050);

uniform float exposure_gain : hint_range(0.0, 3.0) = 1.0;
// Luminance at or below seam_floor is pure tint_low; at or above plate_ceiling
// it is pure tint_high. Between them the ramp blends.
uniform float seam_floor : hint_range(0.0, 1.0) = 0.05;
uniform float plate_ceiling : hint_range(0.0, 1.0) = 0.85;

uniform float param_metallic : hint_range(0.0, 1.0) = 0.12;
uniform float param_roughness : hint_range(0.0, 1.0) = 0.72;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float emission_energy : hint_range(0.0, 8.0) = 1.0;
// Below this much glow a pixel is treated as unlit, so the kit's dark emission
// map does not lift the whole surface into a dull amber wash.
uniform float emission_cut : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	vec3 sampled = texture(albedo_texture, UV).rgb;
	float lum = clamp(dot(sampled, vec3(0.2126, 0.7152, 0.0722)) * exposure_gain, 0.0, 1.0);
	ALBEDO = mix(tint_low, tint_high, smoothstep(seam_floor, plate_ceiling, lum));

	METALLIC = param_metallic;
	ROUGHNESS = param_roughness;

	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;

	float glow = dot(texture(emission_texture, UV).rgb, vec3(0.2126, 0.7152, 0.0722));
	EMISSION = glow_tint * smoothstep(emission_cut, 1.0, glow) * emission_energy;
}
