shader_type canvas_item;
render_mode unshaded;
// The diseased blob a VOLATILE BLOOD kill leaves - see BloodBag. Built on
// RECOIL DEVIL's ward (recoil_shield.gdshader) and kept apart from it, so the ward
// never changes: the same one read of what is already on screen, nudged by
// out-of-step sine waves inside a wandering edge. Where the ward is a thin tinted
// rim over a clear inside, this is its old dark self - an almost black, opaque body
// of corrupted blood under a dark blood-red rim, with slow red veins churning in it
// and a wet sheen on top. Nothing is blurred and there is no second pass.

uniform sampler2D screen : hint_screen_texture, repeat_disable, filter_linear;

// Everything below is written by BloodBag from the VolatileBlood part.

// How much of the blob is showing, 0 to 1.
uniform float presence : hint_range(0.0, 1.0) = 1.0;
// Radius of the blob, in local pixels.
uniform float radius_px = 28.0;
// How far its edge wanders in and out, in local pixels, how fast, and how many
// lobes wander round it.
uniform float edge_wobble_px = 2.5;
uniform float wobble_speed = 3.0;
uniform float lobes = 5.0;
// Width of the blood-red rim, in local pixels.
uniform float rim_width_px = 6.0;
// Furthest a pixel behind the rim is nudged, in screen pixels - the ward's shimmer.
uniform float distortion_px = 1.6;
// How far apart the ripples are, in local pixels.
uniform float wavelength_px = 12.0;
// The corrupted body. Its alpha is how opaque it is - near 1 is solid.
uniform vec4 core_color : source_color = vec4(0.03, 0.0, 0.01, 0.94);
// The rim. Its alpha is the rim's strength.
uniform vec4 rim_color : source_color = vec4(0.45, 0.02, 0.03, 0.95);
// The veins churning inside the body.
uniform vec4 vein_color : source_color = vec4(0.4, 0.01, 0.03, 0.55);
// The wet sheen on top of the body.
uniform vec4 sheen_color : source_color = vec4(0.85, 0.2, 0.18, 0.35);
// 0 to 1: how strongly the unstable pulse brightens the rim and veins right now.
uniform float pulse = 0.5;

varying vec2 local;


void vertex() {
	local = VERTEX;
}


void fragment() {
	float t = TIME * wobble_speed;
	float d = length(local);
	float angle = atan(local.y, local.x);

	// The edge wanders like the ward's does - two waves round it, out of step.
	float edge = radius_px + edge_wobble_px * (sin(angle * lobes + t * 1.3) * 0.6
		+ sin(angle * (lobes - 2.0) - t * 0.9) * 0.4);
	float inside = 1.0 - smoothstep(edge - 1.5, edge + 1.0, d);
	float rim = inside * smoothstep(edge - rim_width_px, edge, d);

	// The ward's nudge, strongest at the rim where the corruption leaks out.
	float rows = local.y / wavelength_px * 6.2831;
	float across = sin(rows + t) * 0.6 + sin(rows * 2.13 - t * 1.31 + local.x * 0.11) * 0.4;
	float down = sin(local.x / (wavelength_px * 1.7) * 6.2831 + t * 0.8) * 0.3;
	vec2 nudge = vec2(across, down) * distortion_px * inside * mix(0.3, 1.0, rim) * SCREEN_PIXEL_SIZE;
	vec3 behind = textureLod(screen, SCREEN_UV + nudge, 0.0).rgb;

	// The body: near black, with slow red veins that crawl and branch.
	vec2 p = local / max(radius_px, 1.0);
	float veins = sin(p.x * 7.0 + sin(p.y * 5.0 + t * 0.7) * 1.6 + t * 0.4)
		* sin(p.y * 6.0 - sin(p.x * 4.0 - t * 0.5) * 1.4 - t * 0.3);
	veins = smoothstep(0.55, 0.95, abs(veins)) * (1.0 - smoothstep(0.55, 1.0, d / max(edge, 1.0)) * 0.4);
	vec3 body = mix(core_color.rgb, vein_color.rgb, veins * vein_color.a * (0.6 + 0.4 * pulse));
	vec3 colour = mix(behind, body, clamp(inside * core_color.a, 0.0, 1.0));

	// The rim, flickering so it reads as something alive, not glass.
	float flicker = 0.8 + 0.2 * sin(angle * 7.0 - t * 2.1 + d * 0.25);
	colour = mix(colour, rim_color.rgb * (0.8 + 0.4 * pulse), clamp(rim * rim_color.a * flicker, 0.0, 1.0));

	// A wet sheen high on the body, the one light it catches.
	float sheen = 1.0 - smoothstep(0.0, radius_px * 0.32, length(local - vec2(-0.3, -0.42) * radius_px));
	colour += sheen_color.rgb * sheen * sheen_color.a * inside;

	COLOR = vec4(colour, clamp(inside * presence, 0.0, 1.0));
}
