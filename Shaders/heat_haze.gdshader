shader_type canvas_item;
render_mode unshaded;
// The shimmer of hot air over the desert floor under an overhead sun - see
// HeatHaze. One read of what is already on screen, nudged a pixel or two by a
// couple of slow sine waves; nothing is blurred, nothing is layered and there is
// no second pass. The rect drawing it is hidden outright whenever the sun is not
// high enough to ask for it, so every other hour costs nothing at all.

uniform sampler2D screen : hint_screen_texture, repeat_disable, filter_linear;

// How much of the effect the sun is asking for right now, 0 to 1. Written by
// HeatHaze from SunController.get_contact_shadow_weight().
uniform float strength : hint_range(0.0, 1.0) = 0.0;
// Furthest a pixel is ever nudged, in screen pixels, at full strength.
uniform float amplitude_px : hint_range(0.0, 8.0) = 1.4;
// How far apart the ripples are, down the screen, in screen pixels.
uniform float wavelength_px : hint_range(4.0, 400.0) = 42.0;
// How fast the ripples climb.
uniform float speed : hint_range(0.0, 10.0) = 2.0;


void fragment() {
	vec2 pixel = SCREEN_UV / SCREEN_PIXEL_SIZE;
	float t = TIME * speed;
	float rows = pixel.y / wavelength_px * 6.2831;
	// Two waves across and a slower one down, out of step with each other, so the
	// air wavers rather than scrolling like a sheet.
	float across = sin(rows + t) * 0.6
		+ sin(rows * 2.13 - t * 1.31 + pixel.x * 0.011) * 0.4;
	float down = sin(pixel.x / (wavelength_px * 1.7) * 6.2831 + t * 0.8) * 0.3;
	vec2 nudge = vec2(across, down) * amplitude_px * strength * SCREEN_PIXEL_SIZE;
	COLOR = vec4(textureLod(screen, SCREEN_UV + nudge, 0.0).rgb, 1.0);
}
