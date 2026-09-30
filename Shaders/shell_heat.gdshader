shader_type canvas_item;
render_mode unshaded;
// The heat shimmer around ONE BIG SHELL's round - see CannonShell. The same
// single read of what is already on screen as heat_haze.gdshader, nudged by a
// couple of fast sine waves, but drawn on a small sprite that rides the shell and
// faded out towards the sprite's edge, so only the air around the round wavers.

uniform sampler2D screen : hint_screen_texture, repeat_disable, filter_linear;

// Written by CannonShell every frame: how much shimmer the shell carries right
// now, 0 to 1 and above.
uniform float strength : hint_range(0.0, 3.0) = 1.0;
// Furthest a pixel is ever nudged, in screen pixels, at strength 1.
uniform float amplitude_px : hint_range(0.0, 12.0) = 2.2;
// How far apart the ripples are, in screen pixels.
uniform float wavelength_px : hint_range(2.0, 200.0) = 14.0;
// How fast the ripples run.
uniform float speed : hint_range(0.0, 40.0) = 16.0;
// Where the fade to the edge begins, as a fraction of the sprite's radius.
uniform float inner : hint_range(0.0, 1.0) = 0.35;


void fragment() {
	float from_centre = length(UV - vec2(0.5)) * 2.0;
	float mask = 1.0 - smoothstep(inner, 1.0, from_centre);
	vec2 pixel = SCREEN_UV / SCREEN_PIXEL_SIZE;
	float t = TIME * speed;
	float across = sin(pixel.y / wavelength_px * 6.2831 + t) * 0.6
		+ sin(pixel.y / wavelength_px * 13.4 - t * 1.37 + pixel.x * 0.05) * 0.4;
	float down = sin(pixel.x / (wavelength_px * 1.3) * 6.2831 + t * 0.9) * 0.5;
	vec2 nudge = vec2(across, down) * amplitude_px * strength * mask * SCREEN_PIXEL_SIZE;
	COLOR = vec4(textureLod(screen, SCREEN_UV + nudge, 0.0).rgb, mask * step(0.001, strength));
}
