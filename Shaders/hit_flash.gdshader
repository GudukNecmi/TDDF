shader_type canvas_item;
// Blends a sprite towards a flat colour without touching its silhouette, and -
// separately - draws an outline round that silhouette.
//
// `flash` is driven from script: 0 leaves the art exactly as it was, 1 paints
// it solid. Alpha is taken from the texture throughout, so a flashing sprite
// keeps its own shape and never lights up its transparent edges.
//
// `outline_width` is 0 by default, which is every ordinary character in the
// game: nothing below it runs and the sprite is drawn exactly as it always was.
// Above 0 it marks a character out - the mini boss is the one today. It is
// deliberately the same material rather than a second one, because the sprites
// already carry this shader and a second material on the same node would have to
// replace it: the flash and the outline coexist on one material instead of
// fighting over one slot.
//
// `tint` is the third of them and 0 by default for the same reason. It is a
// standing wash of colour over the art - an enraged boss's red - as opposed to
// `flash`, which is a momentary one driven by being hit. They are separate
// uniforms rather than one because they have to be able to happen at once: a
// flash written over a tint would erase it for the length of every hit, and a
// tint written into `flash` would be wiped by the next one.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Width in *source texture* pixels, so one number reads the same on art drawn at
// any resolution and does not change when the sprite is scaled up.
uniform float outline_width : hint_range(0.0, 64.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float tint : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);

void fragment() {
	// COLOR arrives holding the node's modulate, so multiplying the texture by
	// it reproduces Godot's default draw before the flash is mixed in.
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec4 result = vec4(mix(base.rgb, flash_color.rgb, flash), base.a);

	// Laid on before the outline rather than after, so the outline is drawn over a
	// tinted man in exactly the colour it was authored in. That is what lets a boss
	// be washed red and still keep the *same* red outline it had at full health,
	// instead of the outline quietly drifting as the wash gets heavier.
	if (tint > 0.0 && tint_color.a > 0.0) {
		result.rgb = mix(result.rgb, tint_color.rgb, tint * tint_color.a);
	}

	if (outline_width > 0.0 && outline_color.a > 0.0) {
		vec2 reach = TEXTURE_PIXEL_SIZE * outline_width;
		// The raw texture alpha, not the modulated one, so a sprite being faded
		// out does not gradually stop being recognised as having an edge.
		float here = texture(TEXTURE, UV).a;

		// Eight taps rather than four, so a diagonal edge is outlined as evenly
		// as a vertical one.
		float a0 = texture(TEXTURE, UV + vec2( reach.x, 0.0)).a;
		float a1 = texture(TEXTURE, UV + vec2(-reach.x, 0.0)).a;
		float a2 = texture(TEXTURE, UV + vec2(0.0,  reach.y)).a;
		float a3 = texture(TEXTURE, UV + vec2(0.0, -reach.y)).a;
		float a4 = texture(TEXTURE, UV + vec2( reach.x,  reach.y)).a;
		float a5 = texture(TEXTURE, UV + vec2( reach.x, -reach.y)).a;
		float a6 = texture(TEXTURE, UV + vec2(-reach.x,  reach.y)).a;
		float a7 = texture(TEXTURE, UV + vec2(-reach.x, -reach.y)).a;

		float lo = min(here, min(min(min(a0, a1), min(a2, a3)), min(min(a4, a5), min(a6, a7))));
		float hi = max(here, max(max(max(a0, a1), max(a2, a3)), max(max(a4, a5), max(a6, a7))));

		// Outward: this texel is clear but the silhouette is within reach, which
		// is the outline proper. Inward: this texel is solid but the edge is
		// within reach, which is a rim drawn just inside it.
		//
		// Both are drawn, on purpose. Outward alone needs the artwork to have
		// transparent padding around it and disappears where the PNG was cropped
		// tight; inward alone can never be clipped but is hidden underneath the
		// character's own dark edge on some art. Together the outline is visible
		// whatever the texture happens to be cropped to - which is what "a clear
		// red outline using the existing art" has to mean when the art itself is
		// not this system's to change.
		float outward = clamp(hi - here, 0.0, 1.0) * (1.0 - step(0.5, here));
		float inward = clamp(here - lo, 0.0, 1.0) * step(0.5, here);
		// Faded with the sprite rather than painted on top of it, so a boss
		// dissolving through DeathFade takes its outline down with it.
		float edge = max(outward, inward) * outline_color.a * COLOR.a;

		result.rgb = mix(result.rgb, outline_color.rgb, edge);
		// Only the outward half adds coverage where there was none. The inward
		// half must not, or it would brighten alpha the sprite already had.
		result.a = max(result.a, outward * outline_color.a * COLOR.a);
	}

	COLOR = result;
}
