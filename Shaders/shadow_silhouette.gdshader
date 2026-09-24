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

// How much the outline is blurred, as a fraction of SOFTNESS_PIXELS. It is counted
// in screen pixels - worked back into this texture through the UV's own rate of
// change - so artwork painted at many times the size it is drawn at feathers by as
// much as a character does, instead of by a fraction of a pixel.
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

// How many screen pixels of blur a softness of 1 asks for. ShadowGroup does the
// same multiplication when it pads the geometry, so the two always agree.
const float SOFTNESS_PIXELS = 12.0;

// Eight directions on the unit circle. The blur samples two rings of them - one at
// half the radius, one at the full radius and turned half a step - which gives the
// edge a graded feather rather than the double outline a single ring leaves.
const vec2 RING[8] = {
	vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
	vec2(0.707, 0.707), vec2(-0.707, 0.707), vec2(0.707, -0.707), vec2(-0.707, -0.707)
};
const vec2 RING_TURNED[8] = {
	vec2(0.924, 0.383), vec2(-0.924, -0.383), vec2(0.383, 0.924), vec2(-0.383, -0.924),
	vec2(-0.383, 0.924), vec2(0.383, -0.924), vec2(-0.924, 0.383), vec2(0.924, -0.383)
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
		// One screen pixel, in this texture's UV: how far the UV moves per pixel
		// across and down the screen. The projection stretches and squeezes the
		// mesh, and this follows it, so the feather is even on screen.
		vec2 per_pixel = abs(dFdx(UV)) + abs(dFdy(UV));
		vec2 reach = per_pixel * softness * SOFTNESS_PIXELS;
		float sum = a * 4.0;
		float weight = 4.0;
		for (int i = 0; i < 8; i++) {
			vec2 near_tap = UV + RING[i] * reach * 0.5;
			vec2 near_in = step(low, near_tap) * step(near_tap, high);
			sum += texture(TEXTURE, near_tap).a * near_in.x * near_in.y * 2.0;
			vec2 far_tap = UV + RING_TURNED[i] * reach;
			vec2 far_in = step(low, far_tap) * step(far_tap, high);
			sum += texture(TEXTURE, far_tap).a * far_in.x * far_in.y;
			weight += 3.0;
		}
		sum /= weight;
		sum *= mix(1.0, 1.0 - clamp(COLOR.r, 0.0, 1.0), fade_strength);
		// The map's colour, written rather than multiplied: the source artwork's
		// own colours are not wanted at all, only the shape they cover.
		COLOR = vec4(shadow_color.rgb, sum * COLOR.a);
	}
}
