shader_type canvas_item;
render_mode unshaded;
// The finishing pass for a shadow made of more than one part: the [CanvasGroup]
// holding a body, a head and whatever is being carried, once they have all been
// projected and drawn into its buffer by shadow_silhouette.gdshader.
//
// It exists separately from that shader because a CanvasGroup is not drawn like
// anything else, and getting this wrong is what made assembled figures throw a
// flat rectangular slab instead of a silhouette. A CanvasGroup renders its
// children into an offscreen buffer and then draws one quad over the whole of
// their bounds. That buffer is reached through the SCREEN texture at SCREEN_UV -
// TEXTURE is the quad's own, which is a blank white pixel, so a material that
// samples TEXTURE reads "opaque everywhere" and paints the entire rectangle. The
// buffer is also premultiplied, so its colour has to be divided back out by its
// coverage before it means anything.
//
// Everything this does is done once, to the assembled figure: softened once,
// faded once, coloured once. That is what stops a head and a body from darkening
// each other where they overlap, and it is why the object reads as one shadow
// rather than as a pile of them.

// The group's own offscreen buffer. Linear, because it is being blurred.
uniform sampler2D group_buffer : hint_screen_texture, repeat_disable, filter_linear;

// How much the outline of the whole figure is blurred, as a fraction of
// SOFTNESS_TEXELS. Here a texel is a screen pixel, because the buffer holds the
// shadow already projected.
uniform float softness : hint_range(0.0, 1.0) = 0.35;
// How much the far end of the shadow fades away, measured against the height each
// point was drawn at - see below.
uniform float fade_strength : hint_range(0.0, 1.0) = 0.2;
// What colour shadows are on this map - see SunStage.shadow_color.
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

const float SOFTNESS_TEXELS = 12.0;

const vec2 RING[8] = {
	vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
	vec2(0.707, 0.707), vec2(-0.707, 0.707), vec2(0.707, -0.707), vec2(-0.707, -0.707)
};


void fragment() {
	float radius = softness * SOFTNESS_TEXELS;

	// Alpha is the union of every part's coverage - where two parts overlap it is
	// still one, which is exactly what keeps a head from darkening the body it is
	// sitting on. Red is that coverage times the height the part was drawn at, so
	// dividing the two back out recovers the height, averaged where parts meet.
	vec2 sum = textureLod(group_buffer, SCREEN_UV, 0.0).ra * 2.0;
	float weight = 2.0;
	for (int i = 0; i < 8; i++) {
		sum += textureLod(group_buffer,
			SCREEN_UV + RING[i] * radius * SCREEN_PIXEL_SIZE, 0.0).ra;
		weight += 1.0;
	}
	sum /= weight;

	float a = sum.y;
	float height = sum.y > 0.0001 ? clamp(sum.x / sum.y, 0.0, 1.0) : 0.0;
	a *= mix(1.0, 1.0 - height, fade_strength);

	// The map's own colour, because the artwork's colours went with the buffer's
	// red channel long ago, and the hour's own opacity, which arrives as the
	// group's modulate and is the only place it is applied.
	COLOR = vec4(shadow_color.rgb, a * COLOR.a);
}
