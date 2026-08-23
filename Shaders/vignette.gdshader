shader_type canvas_item;
// Darkens the screen towards its edges, leaving an open circle around the middle.
//
// It is drawn as a full-screen rect that is transparent in the centre and dimmed
// towards the corners, so what it dims is whatever is *underneath* it in the
// canvas layer - the world - and anything placed after it in the tree, the HUD
// text and the menus, sits on top and stays fully readable.
//
// The shape is two radii and a curve between them. Inside `inner_radius` nothing
// is touched at all, which is the part of the screen the player is actually
// playing in. From there the darkness rises to `darkness` at `outer_radius`, and
// past that it is held there - so `outer_radius` is what decides how much of the
// frame the fall-off is spread across, and pushing it out past the corners is
// what keeps the dark to the very edge rather than closing it in on the player.
//
// [b]It is a dimmer, not a lid.[/b] The rect is alpha-blended black, so what it
// leaves behind is the lit frame multiplied down - a muzzle flash under the dark
// edge still reads as a muzzle flash, only quieter. Two things keep it that way
// and both are dials rather than rules here:
//
//   * `darkness` is deliberately under 1. At 1 the corners are solid black and
//     nothing lit underneath them can ever show through, which is the one setting
//     that turns this into an opaque layer.
//   * `light_bleed` reads what is already on the screen underneath and lifts the
//     dimming back off wherever it is bright. That is what lets gunfire, torches
//     and the portal push the vignette open around them instead of being flattened
//     by it - the lighting is never touched, it is only allowed through.
//
// Every value below is a uniform, which means every value below is an inspector
// field on the material. Nothing about the size, the darkness or the bleed is
// decided here.

// Where the clear centre ends, as a fraction of half the screen. 0 darkens from
// the very middle; raising it opens the view up.
uniform float inner_radius : hint_range(0.0, 2.0) = 0.78;
// Where the darkness has finished arriving. Anything beyond this is fully dark.
// Past about 1.3 only the extreme corners reach `darkness`, which is what keeps
// the dimming to the edges of the frame.
uniform float outer_radius : hint_range(0.0, 2.0) = 1.32;
// Shapes the fall-off between the two radii. 1 is a straight ramp, above 1 holds
// the centre clear for longer and then closes in faster, below 1 starts dimming
// immediately. This is the edge softness dial.
uniform float softness : hint_range(0.05, 6.0) = 1.2;
// How dark the outside gets at `outer_radius` and beyond. Keep it below 1: at 1
// the edge is solid black and no light underneath it can be seen through it.
uniform float darkness : hint_range(0.0, 1.0) = 0.6;
// Overall strength of the whole effect, applied last. Turning this down fades the
// vignette out without changing its shape - useful for a cutscene or a debug view.
uniform float opacity : hint_range(0.0, 1.0) = 0.85;
// What the edges darken to. Black by default; a very dark red tints the whole
// frame towards the rest of the game's palette.
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Where the opening sits, in screen fractions. 0.5, 0.5 is the middle.
uniform vec2 center = vec2(0.5, 0.5);
// How circular the opening is. 1 is a true circle in screen pixels, which closes
// in hard on the sides of a widescreen window; 0 is an ellipse stretched to the
// window's own shape, which wastes none of it. Between the two is usually what
// looks right.
uniform float aspect_correction : hint_range(0.0, 1.0) = 0.4;
// The exponent of the distance the shape is measured with. 2 is a circle - the
// ordinary one - and it is what this should normally be left at. Higher squares
// the opening off towards a rounded rectangle, which wastes less of a widescreen
// frame; 1 collapses it to a diamond.
uniform float roundness : hint_range(1.0, 8.0) = 2.0;

// The lit frame as it stands underneath this rect - the world with every light in
// it already applied. Read only to decide how much of the dimming to lift, never
// written back, so the lighting itself is left exactly as the renderer produced it.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
// How much of the dimming a fully lit pixel takes back. 0 is a flat vignette that
// ignores the lighting entirely; 1 lets a bright enough light open a hole in it.
uniform float light_bleed : hint_range(0.0, 1.0) = 0.85;
// The brightness the lift starts at, and the brightness it is complete at. Between
// them it eases. Raising the floor means only genuinely bright things - a muzzle
// flash, a torch, the portal - push the dark back, and the ambient floor of the
// arena does not.
uniform float light_bleed_floor : hint_range(0.0, 1.0) = 0.2;
uniform float light_bleed_ceiling : hint_range(0.0, 2.0) = 0.72;

void fragment() {
	vec2 offset = UV - center;

	// The rect covers the whole screen, so `SCREEN_PIXEL_SIZE` is the window's
	// aspect. Scaling the horizontal offset by it makes the opening a circle
	// measured in pixels; blending back towards 1.0 lets it be stretched to the
	// window's own shape instead.
	float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.000001);
	offset.x *= mix(1.0, aspect, aspect_correction);

	// Measured against half the screen, so a radius of 1 reaches the edge of the
	// shorter axis and the two radii above read as fractions of the view.
	vec2 unit = abs(offset) * 2.0;
	float distance_out = pow(
		pow(unit.x, roundness) + pow(unit.y, roundness), 1.0 / roundness);

	// Held at 1 past the outer radius rather than allowed to keep climbing, which
	// is what makes the corners land on exactly `darkness` instead of overshooting
	// it by however far off-screen the maths would have gone.
	float t = clamp(
		(distance_out - inner_radius) / max(outer_radius - inner_radius, 0.000001),
		0.0, 1.0);
	float shade = pow(t, softness) * darkness * opacity;

	// The brightest channel rather than a luminance average, because almost every
	// light in this game is red - weighting the channels the way the eye does would
	// score a red muzzle flash as nearly unlit and dim it anyway.
	if (light_bleed > 0.0 && shade > 0.0) {
		vec3 under = texture(screen_texture, SCREEN_UV).rgb;
		float brightness = max(max(under.r, under.g), under.b);
		float lit = smoothstep(
			light_bleed_floor,
			max(light_bleed_ceiling, light_bleed_floor + 0.001),
			brightness);
		shade *= 1.0 - light_bleed * lit;
	}

	COLOR = vec4(vignette_color.rgb, shade * vignette_color.a);
}
