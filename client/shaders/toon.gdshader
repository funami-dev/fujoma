// Painterly toon shading: two soft light bands, warm violet shadows and a watercolor paper grain.
shader_type spatial;
render_mode specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 albedo2 : source_color = vec4(1.0);
uniform float patch_scale = 0.0; // > 0 blends albedo2 in large soft patches (meadows)
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform bool use_vertex_color = false;
uniform float paper = 0.12;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.6, 0.52, 0.68, 1.0);

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = albedo.rgb * texture(albedo_tex, UV).rgb;
	if (use_vertex_color) {
		c *= COLOR.rgb;
	}
	if (patch_scale > 0.0) {
		c = mix(c, albedo2.rgb, smoothstep(0.35, 0.65, vnoise(wpos.xz * patch_scale)));
	}
	float grain = vnoise(wpos.xz * 1.3 + wpos.y * 0.7) * 0.65 + vnoise(wpos.xz * 6.0 + wpos.y * 3.0) * 0.35;
	c *= 1.0 + (grain - 0.5) * 2.0 * paper;
	ALBEDO = c;
	EMISSION = emission.rgb;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, 0.08, ndl) * 0.6 + smoothstep(0.45, 0.55, ndl) * 0.4;
	float falloff = 1.0;
	if (LIGHT_IS_DIRECTIONAL) {
		lit *= ATTENUATION; // shadows darken to the tint, never to black
	} else {
		falloff = ATTENUATION;
	}
	vec3 shade = mix(shadow_tint.rgb * 0.7, vec3(1.0), lit);
	DIFFUSE_LIGHT += shade * LIGHT_COLOR * falloff / PI;
}
