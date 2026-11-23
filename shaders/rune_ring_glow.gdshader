shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 team_color : source_color = vec4(0.0, 0.157, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.863, 0.980, 1.0, 1.0);
uniform float inner_radius = 0.115;
uniform float outer_radius = 0.135;
uniform vec2 plane_size = vec2(0.43);

void fragment() {
	float radius = length((UV - vec2(0.5)) * plane_size);
	float middle = (inner_radius + outer_radius) * 0.5;
	float half_width = (outer_radius - inner_radius) * 0.5;
	float across = abs(radius - middle);
	float outside = max(across - half_width, 0.0);
	// The same local glare model as a lightbar, applied around a circular LED band.
	float halo = exp(-outside / 0.02);
	float core = 1.0 - smoothstep(half_width * 0.15, half_width * 0.7, across);
	ALBEDO = mix(team_color.rgb, core_color.rgb, core);
	ALPHA = 0.8 * halo * (1.0 - smoothstep(0.048, 0.072, outside));
}
