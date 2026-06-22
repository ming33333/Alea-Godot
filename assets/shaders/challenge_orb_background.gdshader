shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.88, 0.9, 0.86, 1.0);
uniform float light_strength : hint_range(0.0, 1.0) = 0.82;
uniform float aspect_ratio : hint_range(0.5, 2.5) = 1.6;

const float TRAVEL_START = 1.38;
const float TRAVEL_END = -0.38;
const float TRAVEL_SPAN = 1.76;

float soft_orb(vec2 uv, vec2 center, float radius) {
	vec2 d = uv - center;
	d.x *= aspect_ratio;
	float dist2 = dot(d, d) / (radius * radius);
	return exp(-dist2 * 2.2);
}

float edge_fade(float y) {
	float fade_in = 1.0 - smoothstep(0.84, 1.22, y);
	float fade_out = smoothstep(TRAVEL_END, 0.12, y);
	return fade_in * fade_out;
}

float floating_orb(
	vec2 uv,
	float x,
	float phase,
	float speed,
	float radius,
	float sway_speed,
	float sway_amount
) {
	float cycle = fract(TIME * speed + phase);
	float y = TRAVEL_START - cycle * TRAVEL_SPAN;
	float x_pos = x + sin(TIME * sway_speed + phase * 6.28318) * sway_amount;
	return soft_orb(uv, vec2(x_pos, y), radius) * edge_fade(y);
}

void fragment() {
	vec2 uv = UV;
	float glow = 0.0;

	glow += floating_orb(uv, 0.14, 0.02, 0.045, 0.19, 0.35, 0.028);
	glow += floating_orb(uv, 0.34, 0.21, 0.038, 0.16, 0.42, 0.022);
	glow += floating_orb(uv, 0.56, 0.47, 0.052, 0.21, 0.31, 0.032);
	glow += floating_orb(uv, 0.78, 0.63, 0.041, 0.18, 0.38, 0.026);
	glow += floating_orb(uv, 0.24, 0.79, 0.034, 0.14, 0.45, 0.018);
	glow += floating_orb(uv, 0.68, 0.91, 0.048, 0.17, 0.33, 0.024);
	glow += floating_orb(uv, 0.46, 0.58, 0.029, 0.24, 0.28, 0.034);

	glow = clamp(glow, 0.0, 1.0);
	vec3 col = mix(base_color.rgb, vec3(1.0), glow * light_strength);
	COLOR = vec4(col, base_color.a);
}
