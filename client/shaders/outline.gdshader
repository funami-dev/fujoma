// Ink outline (inverted hull) with a constant width in screen pixels, so it works at any model scale.
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 ink : source_color = vec4(0.22, 0.14, 0.09, 1.0);
uniform float width_px = 2.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n = mat3(MODELVIEW_MATRIX) * NORMAL;
	vec2 dir = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	if (length(dir) > 0.0001) {
		dir = normalize(dir);
	}
	clip.xy += dir * width_px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = ink.rgb;
}
