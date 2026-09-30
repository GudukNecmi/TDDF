shader_type canvas_item;
render_mode unshaded;
// A flat, see-through silhouette of whatever sprite it is drawn on - the white,
// yellow and red marks BLACK POWDER leaves of the player (see PlayerStealth). Only
// the shape of the artwork is kept: every pixel is the one colour, at the
// artwork's own coverage times the colour's alpha times the node's modulate, so
// fading a mark is only a modulate tween.

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.35);
// A soft brightening towards the edge of the shape, 0 to 1, so the mark reads as
// an outline of someone rather than a cut-out hole.
uniform float edge_glow : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	float a = texture(TEXTURE, UV).a;
	// How much less solid the neighbourhood is than this pixel - high at the edge.
	vec2 px = TEXTURE_PIXEL_SIZE * 3.0;
	float around = (texture(TEXTURE, UV + vec2(px.x, 0.0)).a
		+ texture(TEXTURE, UV - vec2(px.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, px.y)).a
		+ texture(TEXTURE, UV - vec2(0.0, px.y)).a) * 0.25;
	float edge = clamp(a - around, 0.0, 1.0);
	float alpha = a * tint.a * (1.0 + edge * edge_glow * 2.0);
	COLOR = vec4(tint.rgb, clamp(alpha, 0.0, 1.0) * COLOR.a);
}
