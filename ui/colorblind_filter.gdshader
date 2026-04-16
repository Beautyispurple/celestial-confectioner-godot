shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
/// 0 = Off (pass-through), 1 = Deuteranopia, 2 = Protanopia, 3 = Tritanopia
uniform int filter_mode = 0;
uniform float strength : hint_range(0.0, 1.0) = 0.0;

/// Approximate simulation matrices (linear RGB).
vec3 apply_deuteranopia(vec3 c) {
	return mat3(
			vec3(0.367, 0.861, -0.228),
			vec3(0.280, 0.673, 0.047),
			vec3(-0.012, 0.043, 0.969)
		) * c;
}

vec3 apply_protanopia(vec3 c) {
	return mat3(
			vec3(0.152, 1.083, -0.235),
			vec3(0.115, 0.786, 0.099),
			vec3(-0.005, -0.048, 1.053)
		) * c;
}

vec3 apply_tritanopia(vec3 c) {
	return mat3(
			vec3(1.256, -0.077, -0.179),
			vec3(-0.078, 0.931, 0.147),
			vec3(-0.006, 0.053, 0.953)
		) * c;
}

void fragment() {
	vec4 src = texture(screen_texture, SCREEN_UV);
	vec3 rgb = src.rgb;
	vec3 out_rgb = rgb;
	if (filter_mode == 1) {
		out_rgb = apply_deuteranopia(rgb);
	} else if (filter_mode == 2) {
		out_rgb = apply_protanopia(rgb);
	} else if (filter_mode == 3) {
		out_rgb = apply_tritanopia(rgb);
	}
	out_rgb = clamp(mix(rgb, out_rgb, strength), 0.0, 1.0);
	COLOR = vec4(out_rgb, src.a);
}
