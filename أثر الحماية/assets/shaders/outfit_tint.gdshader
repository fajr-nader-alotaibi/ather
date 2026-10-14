shader_type canvas_item;

uniform vec4 outfit_color : source_color = vec4(0.75, 0.23, 0.17, 1.0);
uniform float outfit_channel = 0.0;

void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * COLOR;
	float red_bias = pixel.r - max(pixel.g, pixel.b) * 0.82;
	float blue_bias = pixel.b - max(pixel.r, pixel.g) * 0.80;
	float saturation = max(max(pixel.r, pixel.g), pixel.b) - min(min(pixel.r, pixel.g), pixel.b);
	float source_light = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
	float chroma_mask = smoothstep(0.08, 0.22, saturation);
	float light_mask = smoothstep(0.08, 0.25, source_light) * (1.0 - smoothstep(0.70, 0.86, source_light));
	float red_mask = smoothstep(0.045, 0.20, red_bias) * chroma_mask * light_mask;
	red_mask *= 1.0 - smoothstep(0.12, 0.28, pixel.g - pixel.b);
	float blue_mask = smoothstep(0.025, 0.15, blue_bias) * chroma_mask * light_mask;
	float outfit_mask = mix(red_mask, blue_mask, step(0.5, outfit_channel));
	float shade = mix(0.42, 1.18, smoothstep(0.08, 0.72, source_light));
	vec3 recolored = outfit_color.rgb * shade;
	COLOR = vec4(mix(pixel.rgb, recolored, outfit_mask), pixel.a);
}
