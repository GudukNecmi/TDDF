shader_type canvas_item;
// The World Map fog's only visual, replacing per-cell draw_rect() rectangles
// with a per-pixel gradient - see WorldMapFogOverlay's class doc for why.
//
// Two things are blended together, both driven from CPU-side uniforms rather
// than per-frame draw calls:
//
// 1. A bilinearly-filtered low-resolution mask of WorldMapFog's own explored
//    set. The mask texture is rebuilt only when WorldMapFog recomputes (its
//    own 10Hz tick), never every frame, and "filter_linear" below is what
//    turns its blocky source cells into a smooth gradient at the explored/
//    unexplored boundary - the fix for the pixelated look, not a smaller
//    grid.
// 2. An analytic radial falloff around the player, computed fresh every
//    fragment from a handful of float uniforms - no texture at all - so the
//    boundary that actually matters most (what is visible right now) is
//    perfectly smooth regardless of the logical grid's cell size.

uniform sampler2D mask_texture: filter_linear, repeat_disable;
uniform vec2 mask_origin;
uniform vec2 mask_size;
uniform vec2 player_pos;
uniform float visible_radius = 640.0;
uniform float soft_edge_width = 220.0;
uniform float reveal_falloff = 1.6;
uniform float explored_alpha = 0.6;
uniform float unexplored_alpha = 1.0;
uniform vec3 fog_color = vec3(0.03, 0.02, 0.02);

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 uv = (local_pos - mask_origin) / max(mask_size, vec2(0.001));
	uv = clamp(uv, vec2(0.0), vec2(1.0));
	float explored = texture(mask_texture, uv).r;
	float base_alpha = mix(unexplored_alpha, explored_alpha, explored);

	float dist = distance(local_pos, player_pos);
	float inner = max(visible_radius - soft_edge_width, 0.0);
	float t = clamp((dist - inner) / max(visible_radius - inner, 0.001), 0.0, 1.0);
	float strength = 1.0 - pow(t, max(reveal_falloff, 0.001));

	COLOR = vec4(fog_color, base_alpha * (1.0 - strength));
}
