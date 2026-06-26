shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 32.0) = 16.0;

void fragment() {
	vec4 center = texture(TEXTURE, UV);
	if (blur_amount <= 0.01) {
		COLOR = center;
		return;
	}
	vec4 sum = center * 0.16;
	float weight_sum = 0.16;
	vec2 px = TEXTURE_PIXEL_SIZE * blur_amount;
	const int radius = 4;
	for (int x = -radius; x <= radius; x++) {
		for (int y = -radius; y <= radius; y++) {
			if (x == 0 && y == 0) {
				continue;
			}
			float dist = length(vec2(float(x), float(y)));
			float w = exp(-dist * dist / 5.0);
			vec2 offset = vec2(float(x), float(y)) * px;
			sum += texture(TEXTURE, UV + offset) * w;
			weight_sum += w;
		}
	}
	COLOR = sum / weight_sum;
}
