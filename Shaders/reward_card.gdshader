shader_type canvas_item;
// A reward card's face, drawn as a physical card: tilted in 3D towards the mouse
// with a perspective-correct texture, and lit by a soft glare that follows the
// mouse across the card stock in the card's rarity colour. Every value is set by
// RewardChoiceCard from its Inspector exports.

// The drawn rect's size, in pixels - the tilt pivots on its middle.
uniform vec2 rect_size = vec2(200.0, 290.0);
// Rotation, in radians: x turns the card about its vertical axis, y about its
// horizontal one.
uniform vec2 tilt = vec2(0.0);
// Eye distance, in pixels. Smaller is a stronger perspective.
uniform float perspective = 900.0;

// Where the glare sits, in the card's UV space.
uniform vec2 glare_pos = vec2(0.5);
uniform vec4 glare_color : source_color = vec4(1.0);
// 0..1 how present the glare is right now - faded in and out on hover.
uniform float glare_amount = 0.0;
uniform float glare_strength = 0.6;
// Radius of the glare, as a fraction of the card's height.
uniform float glare_size = 0.45;
// 0 is a hard disc, 1 fades from the very centre.
uniform float glare_softness = 0.85;
uniform float glare_opacity = 0.55;

varying vec3 v_uvw;
varying vec4 v_modulate;

void vertex() {
	vec2 c = VERTEX - rect_size * 0.5;
	float z = c.x * sin(tilt.x) + c.y * sin(tilt.y);
	vec2 flat_pos = vec2(c.x * cos(tilt.x), c.y * cos(tilt.y));
	float s = perspective / max(perspective + z, 1.0);
	VERTEX = flat_pos * s + rect_size * 0.5;
	v_uvw = vec3(UV * s, s);
	v_modulate = COLOR;
}

void fragment() {
	vec2 uv = v_uvw.xy / v_uvw.z;
	vec4 col = texture(TEXTURE, uv);
	vec2 aspect = vec2(rect_size.x / rect_size.y, 1.0);
	float d = distance(uv * aspect, glare_pos * aspect);
	float inner = glare_size * (1.0 - clamp(glare_softness, 0.0, 1.0));
	float g = 1.0 - smoothstep(inner, max(glare_size, inner + 0.0001), d);
	float k = g * glare_amount * glare_strength * glare_opacity;
	// Screen blend: light falling on card stock, never pushing it past white.
	vec3 lit = 1.0 - (1.0 - col.rgb) * (1.0 - glare_color.rgb * k);
	COLOR = vec4(lit, col.a) * v_modulate;
}
