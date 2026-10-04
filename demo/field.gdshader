shader_type canvas_item;

uniform vec4 col : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 col2 : source_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 size = vec2(100.0, 100.0);
uniform float circle = 0.0;
uniform float active = 1.0;
uniform float warn = 0.0;
uniform float next_warn = 0.0;

void fragment() {
	vec2 p = UV * size;
	float edge_dist;
	if (circle > 0.5) {
		float r = size.x * 0.5;
		float d = length(p - vec2(r));
		if (d > r) {
			discard;
		}
		edge_dist = r - d;
	} else {
		edge_dist = min(min(p.x, p.y), min(size.x - p.x, size.y - p.y));
	}
	float stripe = step(0.5, fract((p.x + p.y) / 28.0 - TIME * 0.6));
	vec3 c = col.rgb;
	// About to change color: the stripes flash the next color.
	if (next_warn > 0.5 && stripe > 0.5 && fract(TIME * 4.0) < 0.5) {
		c = col2.rgb;
	}
	float a = mix(0.10, 0.32, stripe);
	float edge = 1.0 - smoothstep(1.5, 3.5, edge_dist);
	if (active < 0.5) {
		// Switched off: dashed outline only, flickering just before it switches back on.
		if (warn > 0.5 && fract(TIME * 5.0) < 0.5) {
			a *= 0.8;
		} else {
			a = 0.0;
		}
		edge *= step(0.5, fract((p.x + p.y) / 16.0)) * 0.6;
	}
	COLOR = vec4(mix(c, vec3(1.0), edge * 0.25), max(a, edge * 0.85));
}
