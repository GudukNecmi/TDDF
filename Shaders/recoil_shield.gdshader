shader_type canvas_item;
render_mode unshaded;
// The blood-red ward around a player thrown by RECOIL DEVIL - see RecoilShield.
// It is the Noon heat haze's shimmer (heat_haze.gdshader) gathered into a
// bubble: the same one read of what is already on screen, nudged by a couple of
// out-of-step sine waves, only confined to a wavering disc and tinted at its
// rim. Nothing is blurred and there is no second pass. The inner glow that
// closes it is drawn in the same pass, as a soft front growing from the middle.

uniform sampler2D screen : hint_screen_texture, repeat_disable, filter_linear;

// Everything below is written by RecoilShield from its Inspector values.

// How much of the shield is showing, 0 to 1. It fades on this, never pops.
uniform float presence : hint_range(0.0, 1.0) = 0.0;
// Radius of the ward, in local pixels.
uniform float radius_px = 34.0;
// How far the edge of the disc wanders in and out, in local pixels.
uniform float edge_wobble_px = 2.5;
// Width of the tinted rim, in local pixels.
uniform float rim_width_px = 7.0;
// Furthest a pixel behind the ward is nudged, in screen pixels.
uniform float distortion_px = 1.8;
// How far apart the ripples are, in local pixels.
uniform float wavelength_px = 16.0;
// How fast the ripples move.
uniform float speed = 3.0;
// The ward's colour. Its alpha is the rim's opacity.
uniform vec4 shield_color : source_color = vec4(0.78, 0.04, 0.04, 0.55);
// Tint laid over the inside, 0 to 1 - kept low so the player reads through it.
uniform float fill_opacity : hint_range(0.0, 1.0) = 0.10;
// The closing glow: how strong it is right now - 1 is full, above flares - and
// how far its front has grown out from the middle, in local pixels.
uniform float glow = 0.0;
uniform float glow_radius_px = 0.0;
// How soft the glow's front is, in local pixels.
uniform float glow_softness_px = 14.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.25, 0.18, 1.0);

varying vec2 local;


void vertex() {
	local = VERTEX;
}


void fragment() {
	float t = TIME * speed;
	float d = length(local);
	float angle = atan(local.y, local.x);

	// The edge wanders like the haze does - two waves round the circle, out of step.
	float edge = radius_px + edge_wobble_px * (sin(angle * 5.0 + t * 1.3) * 0.6
		+ sin(angle * 3.0 - t * 0.9) * 0.4);
	float inside = 1.0 - smoothstep(edge - 2.0, edge + 1.5, d);
	float rim = inside * smoothstep(edge - rim_width_px, edge, d);

	// The haze's nudge, measured in the ward's own pixels so it moves with the
	// player, and strongest towards the rim where the energy is thickest.
	float rows = local.y / wavelength_px * 6.2831;
	float across = sin(rows + t) * 0.6 + sin(rows * 2.13 - t * 1.31 + local.x * 0.11) * 0.4;
	float down = sin(local.x / (wavelength_px * 1.7) * 6.2831 + t * 0.8) * 0.3;
	float weight = inside * mix(0.45, 1.0, rim) * presence;
	vec2 nudge = vec2(across, down) * distortion_px * weight * SCREEN_PIXEL_SIZE;
	vec3 behind = textureLod(screen, SCREEN_UV + nudge, 0.0).rgb;

	// Rim and fill tint, flickering a little so it reads as energy, not glass.
	float flicker = 0.85 + 0.15 * sin(angle * 7.0 - t * 2.1 + d * 0.2);
	float tint = (rim * shield_color.a * flicker + inside * fill_opacity) * presence;
	vec3 colour = mix(behind, shield_color.rgb, clamp(tint, 0.0, 1.0));

	// The glow: a soft disc out to its front, brightest at the front itself.
	float reach = glow_radius_px;
	float disc = 1.0 - smoothstep(reach - glow_softness_px, reach, d);
	float front = disc * smoothstep(reach - glow_softness_px * 1.5, reach, d);
	float lit = max((disc * 0.35 + front * 0.65) * glow, 0.0);
	colour += glow_color.rgb * lit * glow_color.a;

	// Outside both the ward and the glow nothing is drawn at all.
	float coverage = max(inside * presence, lit);
	COLOR = vec4(colour, clamp(coverage, 0.0, 1.0));
}
