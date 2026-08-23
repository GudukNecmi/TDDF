shader_type canvas_item;
// Blurs and fades the screen blood as it dries off the glass.
//
// This blurs the overlay's OWN texture rather than the screen behind it, which
// is what pause_blur.gdshader does - the world underneath has to stay sharp
// while the blood over it goes soft, so sampling the screen would blur exactly
// the wrong thing.
//
// It is a plain box blur rather than a mipmap fetch, because the overlay is a
// single large sprite whose mips would smear its transparent edges inwards and
// pull the drips away from the frame. Nine taps is enough: the effect is a
// smear, not a lens.
//
// Both uniforms are driven from BloodScreen. At blur_amount 0 the taps all land
// on the same texel, so an idle overlay costs no more than an ordinary sprite.

uniform float blur_amount : hint_range(0.0, 16.0) = 0.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 step_size = TEXTURE_PIXEL_SIZE * blur_amount;

	vec4 total = vec4(0.0);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			total += texture(TEXTURE, UV + vec2(float(x), float(y)) * step_size);
		}
	}

	COLOR = total / 9.0;
	COLOR.a *= alpha;
}
