shader_type canvas_item;
render_mode blend_mix;
// One part of a shadow, drawn on the projected mesh [ShadowGroup] builds for it.
//
// The geometry is the whole of the projection - by the time this runs, every
// vertex is already standing where the sun put it. What is left is turning the
// artwork into a silhouette: throw the source's colours away, keep its alpha as
// the shape, soften the edge, fade the far end, and paint it in the map's own
// shadow colour.
//
// It runs in two passes because a shadow made of several parts has to be unioned
// before it is coloured, or a head and a body would darken each other where they
// overlap:
//
//   into_group = false - the object is one part, so there is nothing to union.
//     The finished shadow is drawn straight to the screen.
//   into_group = true  - this part is being written into a [CanvasGroup] buffer
//     that [code]shadow_composite.gdshader[/code] will finish. Only coverage and
//     height go in; the softening, the fade and the colour happen once, up there.

// How much the outline is blurred, as a fraction of SOFTNESS_TEXELS. It is done in
// texture pixels, which the projection then stretches along the light - so the far
// end of a shadow is softer than its near end, the way a penumbra grows with
// distance.
uniform float softness : hint_range(0.0, 1.0) = 0.35;
// How much the far end of the shadow fades away. Measured against how high up the
// object each point was drawn - carried in the vertex red channel - and not
// against the picture's own edges, so a swung weapon and a rolling head fade with
// the rest of the figure rather than along their own texture.
uniform float fade_strength : hint_range(0.0, 1.0) = 0.2;
// What colour shadows are on this map - see SunStage.shadow_color.
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Which part of the texture this silhouette is cut from, as (x, y, width, height)
// in UV. The mesh is deliberately built a little wider than that so the blur has
// transparent room to fade into; this is what makes that room transparent instead
// of letting it reach into the neighbouring frame of a sheet.
uniform vec4 frame_uv = vec4(0.0, 0.0, 1.0, 1.0);
// Whether this is the pass that writes into a CanvasGroup buffer.
uniform bool into_group = false;

// How many texels of blur a softness of 1 asks for. ShadowGroup does the same
// multiplication when it pads the geometry, so the two always agree.
const float SOFTNESS_TEXELS = 12.0;

// Eight directions on the unit circle, for the ring of the blur.
const vec2 RING[8] = {
	vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
	vec2(0.707, 0.707), vec2(-0.707, 0.707), vec2(0.707, -0.707), vec2(-0.707, -0.707)
};



void fragment() {
	// The frame being drawn, as a pair of UV corners. The mesh is deliberately
	// built a little wider than this so the blur has transparent room to fade into,
	// and every tap is cut against it so that room stays transparent instead of
	// reaching into the neighbouring frame of a sheet.
	vec2 low = frame_uv.xy;
	vec2 high = frame_uv.xy + frame_uv.zw;
	vec2 inside = step(low, UV) * step(UV, high);
	float a = texture(TEXTURE, UV).a * inside.x * inside.y;

	if (into_group) {
		// Straight into the buffer: the composite pass softens the assembled
		// figure, so softening each part here would only do it twice.
		//
		// Red carries the height this point was drawn at, so the composite can fade
		// the far end of the whole object. Alpha stays this part's own, which keeps
		// a stowed weapon able to fade out of the silhouette.
		COLOR = vec4(COLOR.r, 0.0, 0.0, a * COLOR.a);
	} else {
		float radius = softness * SOFTNESS_TEXELS;
		float sum = a * 2.0;
		float weight = 2.0;
		for (int i = 0; i < 8; i++) {
			vec2 tap = UV + RING[i] * radius * TEXTURE_PIXEL_SIZE;
			vec2 covered = step(low, tap) * step(tap, high);
			sum += texture(TEXTURE, tap).a * covered.x * covered.y;
			weight += 1.0;
		}
		sum /= weight;
		sum *= mix(1.0, 1.0 - clamp(COLOR.r, 0.0, 1.0), fade_strength);
		// The map's colour, written rather than multiplied: the source artwork's
		// own colours are not wanted at all, only the shape they cover.
		COLOR = vec4(shadow_color.rgb, sum * COLOR.a);
	}
}
