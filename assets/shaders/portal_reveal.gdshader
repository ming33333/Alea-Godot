shader_type canvas_item;

uniform float reveal_y : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	if (UV.y > reveal_y) {
		discard;
	}
	COLOR = texture(TEXTURE, UV);
}
