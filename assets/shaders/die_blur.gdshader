shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 8.0) = 4.0;

void fragment() {
	vec4 sum = vec4(0.0);
	vec2 px = TEXTURE_PIXEL_SIZE * blur_amount;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 offset = vec2(float(x), float(y)) * px;
			sum += texture(TEXTURE, UV + offset);
		}
	}
	COLOR = sum / 25.0;
	COLOR.a = texture(TEXTURE, UV).a;
}
