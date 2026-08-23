shader_type canvas_item;
// Cheap full-screen blur for the run-end overlay.
//
// Rather than running a real multi-tap blur, this samples the screen texture at
// a coarse mipmap level - the GPU has already built those, so the cost is one
// texture fetch. The screen is frozen behind a paused tree while this is
// visible, so there is nothing for the low resolution to alias against.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// Mip level sampled. Higher is blurrier.
uniform float blur_amount : hint_range(0.0, 6.0) = 2.6;
// Darkens the frozen gameplay so the overlay reads clearly on top of it.
uniform float dim : hint_range(0.0, 1.0) = 0.55;

const vec3 DIM_COLOR = vec3(0.02, 0.02, 0.04);

void fragment() {
	vec3 blurred = textureLod(screen_texture, SCREEN_UV, blur_amount).rgb;
	COLOR = vec4(mix(blurred, DIM_COLOR, dim), 1.0);
}
