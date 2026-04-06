shader_type canvas_item;

uniform float rainbow_speed : hint_range(0.0, 2.0) = 0.35;
uniform float shimmer : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float h = fract(TIME * rainbow_speed + UV.x * 2.0 + UV.y * 0.5);
	vec3 c = vec3(
		abs(h * 6.0 - 3.0) - 1.0,
		2.0 - abs(h * 6.0 - 2.0),
		2.0 - abs(h * 6.0 - 4.0)
	);
	c = clamp(c, 0.0, 1.0);
	vec3 base = tex.rgb;
	float a = tex.a;
	vec3 out_c = mix(base, c, shimmer * a);
	COLOR = vec4(out_c, a);
}
