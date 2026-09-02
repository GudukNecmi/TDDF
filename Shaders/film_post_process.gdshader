shader_type canvas_item;
// The whole game seen through an old western film reel: grain, dust, the
// occasional scratch, a faint flicker and frame wobble, and a soft vignette -
// six cheap effects folded into one full-screen pass rather than six.
//
// It works the same way the existing gameplay vignette does: drawn as a
// full-screen rect that reads [code]screen_texture[/code] - whatever the
// world has already rendered underneath it - and hands back a processed
// version of the same frame. Everything drawn after this in the canvas layer
// (the HUD text, the gameplay vignette, every menu) sits on top of it
// untouched, so nothing about it can ever soften the numbers on screen.
//
// [b]It is a texture, not a light.[/b] Nothing here reads or writes the
// world's ambient colour, [CanvasModulate], or any [SunStage] - the palette
// underneath is exactly what [DayCycleDirector] and [SunController] already
// painted. This only grains, dusts, scratches, flickers, wobbles and vignettes
// whatever colour is already there.
//
// Every knob below is tuned to be continuously noticeable - grain always
// animating, dust motes always turning over somewhere on screen, an
// occasional scratch every few seconds - so the whole frame reads as an old
// projected reel rather than a game with a faint grain filter over it. It
// still has to lose to a muzzle flash or a bounty's blood, never compete
// with them.

group_uniforms Grain;
// Overall strength of the grain. Meant to be clearly visible on flat and
// dark ground rather than a faint texture - the fragment stage applies this
// directly with no hidden extra dampening, and also biases every grain
// sample toward its dark half more than its bright half (see the fragment
// code below), so raising this thickens the grain without it starting to
// read as bright white sparkle.
uniform float grain_amount : hint_range(0.0, 1.0) = 0.06;
// Size of one grain "cell" in screen pixels. Bigger reads coarser and more
// like an old film stock; smaller reads finer and closer to sensor noise.
uniform float grain_size : hint_range(0.5, 8.0) = 1.6;
// How many times a second the grain re-rolls. Real film grain does not hold
// still - kept brisk so the texture is always visibly alive rather than
// resting between rolls.
uniform float grain_speed : hint_range(0.0, 30.0) = 12.0;
// How much more visible the grain is in shadow than in a highlight - the way
// grain actually behaves on real film stock. 1 is even everywhere; higher
// buries it in bright areas and keeps it in the dark ones. Kept high so the
// grain reads on the dim desert atmosphere without dusting the HUD's own
// bright whites.
uniform float grain_contrast : hint_range(0.0, 4.0) = 1.8;

group_uniforms Dust;
// Density of dust motes on screen at once. This is a camera/film artefact -
// small grey-white or dark flecks - and deliberately has nothing to do with
// the desert's own sand. This is the effect most responsible for the reel
// actually feeling alive: high enough that several motes are always
// somewhere on screen, low enough that they never read as a field of noise.
uniform float dust_amount : hint_range(0.0, 1.0) = 0.045;
// How often a given patch of screen gets a new mote, in rolls per second.
// Higher is busier; it does not raise how many are visible at once, only how
// quickly they turn over.
uniform float dust_frequency : hint_range(0.05, 4.0) = 0.75;
// Base radius of one mote, in screen pixels. Each mote also rolls its own
// random size multiplier in the fragment stage (see below), so this is the
// middle of the range rather than a fixed size - real film dirt comes in a
// scatter of sizes, not one.
uniform float dust_size : hint_range(0.5, 6.0) = 2.3;
// How opaque a mote gets at the peak of its short life, before its own
// per-mote opacity and dark-or-light polarity are applied in the fragment
// stage - so this is the ceiling those roll under, not a fixed strength.
uniform float dust_opacity : hint_range(0.0, 1.0) = 0.65;
// How long one mote takes to fade in and back out, in seconds. Short values
// read as a flicker of dust; long values read as a mote drifting through.
uniform float dust_lifetime : hint_range(0.05, 3.0) = 0.4;

group_uniforms Scratches;
// How often a scratch happens, in scratches per second. Still occasional -
// a handful every ten seconds, not a texture - but frequent enough that one
// reliably shows up within a few seconds of watching.
uniform float scratch_frequency : hint_range(0.0, 2.0) = 0.3;
// How tall a vertical scratch is, as a fraction of the screen's height.
uniform float scratch_length : hint_range(0.05, 1.0) = 0.45;
// How wide one scratch is, in screen pixels.
uniform float scratch_width : hint_range(0.5, 4.0) = 1.7;
// How bright a scratch gets at its brightest. Raised so a scratch actually
// reads clearly against the frame instead of needing a careful look.
uniform float scratch_opacity : hint_range(0.0, 1.0) = 0.68;
// How long a single scratch stays visible, in seconds - the flash itself
// eases in and back out across this window rather than snapping.
uniform float scratch_duration : hint_range(0.02, 1.0) = 0.24;
// Fraction of scratch events that come out as a short horizontal scratch
// instead of the usual tall vertical one - a rarer accident within the
// already-rare scratch event, at a fixed fraction of [member scratch_length]
// so it always reads as short.
uniform float scratch_horizontal_chance : hint_range(0.0, 1.0) = 0.2;

group_uniforms Flicker;
// Peak change in overall brightness. This is a projector flicker, not a
// strobe - kept small, but raised enough to actually be seen as a slow
// organic breathing in brightness.
uniform float flicker_amount : hint_range(0.0, 0.5) = 0.045;
// How fast the flicker moves. Kept slow so it reads as an old projector's
// lamp drifting, not a pulse.
uniform float flicker_speed : hint_range(0.0, 20.0) = 4.0;
// Blends between an even, predictable wobble (0) and an irregular, noisy
// one (1) - real projector flicker is closer to the noisy end, but a fully
// smooth one is calmer if the noisy version ever reads as distracting.
uniform float flicker_smoothness : hint_range(0.0, 1.0) = 0.65;

group_uniforms Frame_Jitter;
// How far the whole frame can drift off its resting position, in screen
// pixels. This is the old projector's registration wobble - it must stay
// small enough that aiming and reading the screen are never affected.
uniform float jitter_amount : hint_range(0.0, 4.0) = 0.55;
// How fast the frame wanders.
uniform float jitter_speed : hint_range(0.0, 20.0) = 2.6;

group_uniforms Vignette;
// How dark the frame's own corners get. Separate from - and meant to sit
// well underneath - the gameplay vignette already drawn above this, so this
// one is the film's, not the HUD's. Kept soft so it frames the shot without
// meaningfully darkening gameplay on its own.
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.2;
// Where the darkening begins, as a fraction of the distance to the corner.
uniform float vignette_radius : hint_range(0.0, 1.5) = 0.88;
// How gradual the fall-off from clear to dark is.
uniform float vignette_softness : hint_range(0.05, 2.0) = 1.15;

group_uniforms Intensity;
// One master dial across the whole effect, driven by [FilmPostProcess] -
// eased up slightly at night, folded back for weather, and free to be
// pulsed for a cinematic beat. Every uniform above is still what shapes the
// look; this only scales how much of it is currently showing.
uniform float global_intensity : hint_range(0.0, 3.0) = 1.0;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float amt = max(global_intensity, 0.0);

	// --- Frame jitter: the whole read position wanders a little, as if the
	// reel were never perfectly gated. Two offset sine waves rather than
	// noise, so the wobble is a gentle drift and never a shake.
	vec2 jitter_px = vec2(
		sin(TIME * jitter_speed * 1.7 + 1.3),
		cos(TIME * jitter_speed * 1.1 + 4.1)
	) * jitter_amount * amt;
	vec2 uv = SCREEN_UV + jitter_px * SCREEN_PIXEL_SIZE;
	vec3 base = texture(screen_texture, uv).rgb;

	// --- Grain: a fresh hash per cell, re-rolled a fixed number of times a
	// second rather than every frame, so it reads as film stock and not as
	// a shimmering texture.
	vec2 grain_cell = floor(FRAGCOORD.xy / max(grain_size, 0.5));
	float grain_epoch = floor(TIME * max(grain_speed, 0.0));
	float grain_n = hash13(vec3(grain_cell, grain_epoch)) * 2.0 - 1.0;
	// Real film stock reads darker and duller than it does brighter - bias
	// the noise's own upper half down so grain never turns into flecks of
	// bright white sparkle, only a dark/neutral texture.
	if (grain_n > 0.0) {
		grain_n *= 0.5;
	}
	float luma = dot(base, vec3(0.299, 0.587, 0.114));
	float shadow_bias = mix(1.0, 1.0 - luma, clamp(grain_contrast * 0.3, 0.0, 1.0));
	// grain_amount is applied directly here with no hidden extra dampening -
	// what the Inspector shows is what shows on screen.
	base += grain_n * grain_amount * shadow_bias * amt;

	// --- Film dust: a coarse grid of cells, each with its own short-lived
	// mote that blinks on at a random point in its own cycle. Sparse and
	// randomised by construction - no two cells share a phase.
	vec2 dust_grid = vec2(96.0, 54.0) / max(dust_size, 0.3);
	vec2 dust_cell = floor(uv * dust_grid);
	vec2 dust_local = fract(uv * dust_grid);
	float dust_seed = hash13(vec3(dust_cell, 7.0));
	float dust_cycle = 1.0 / max(dust_frequency, 0.05);
	float dust_phase = TIME / dust_cycle + dust_seed * 19.0;
	float dust_epoch = floor(dust_phase);
	float dust_local_t = fract(dust_phase);
	float dust_roll = hash13(vec3(dust_cell, dust_epoch));
	float dust_life_frac = clamp(dust_lifetime / dust_cycle, 0.05, 1.0);
	if (dust_roll < dust_amount && dust_local_t < dust_life_frac) {
		float lt = dust_local_t / dust_life_frac;
		float envelope = sin(lt * 3.14159265);
		vec2 mote_pos = vec2(
			hash13(vec3(dust_cell, dust_epoch + 11.0)),
			hash13(vec3(dust_cell, dust_epoch + 23.0))
		);
		// Each mote also rolls its own size and peak-opacity multiplier, on
		// fresh hash axes independent of its position or polarity - real
		// film dirt is a scatter of different-sized, different-strength
		// specks, not identical dots stamped at one size.
		float size_scale = mix(0.55, 1.9, hash13(vec3(dust_cell, dust_epoch + 31.0)));
		float opacity_scale = mix(0.45, 1.0, hash13(vec3(dust_cell, dust_epoch + 53.0)));
		vec2 to_mote = (dust_local - mote_pos) / max(dust_grid, vec2(1.0));
		float px_radius = max(dust_size * size_scale, 0.5) * SCREEN_PIXEL_SIZE.x;
		float d = length(to_mote) / max(px_radius, 0.0001);
		float mote_mask = 1.0 - smoothstep(0.0, 1.0, d);
		// Each mote rolls its own dark-or-light polarity, on a fresh hash
		// axis so it never correlates with its position or lifetime - real
		// film dust is a mix of dark specks and tiny bright flecks, not one
		// or the other.
		float dust_polarity = hash13(vec3(dust_cell, dust_epoch + 41.0)) > 0.5 ? 1.0 : -1.0;
		base += vec3(mote_mask * envelope * dust_opacity * opacity_scale * dust_polarity * amt);
	}

	// --- Scratches: one occasional bright streak at a time, randomised
	// position, slant and length each time it recurs.
	float scratch_cycle = 1.0 / max(scratch_frequency, 0.02);
	float scratch_epoch = floor(TIME / scratch_cycle);
	float scratch_t = fract(TIME / scratch_cycle);
	float scratch_duration_frac = clamp(scratch_duration / scratch_cycle, 0.01, 1.0);
	if (scratch_t < scratch_duration_frac) {
		float rx = hash13(vec3(scratch_epoch, 12.9, 78.1));
		float ry = hash13(vec3(scratch_epoch, 45.2, 3.7));
		float rslant = hash13(vec3(scratch_epoch, 91.7, 22.3)) - 0.5;
		float progress = scratch_t / scratch_duration_frac;
		float envelope = sin(progress * 3.14159265);
		// Almost every scratch is the tall vertical kind a real reel gets
		// from a piece of grit dragged the length of the film; a rarer roll
		// swaps it for a short horizontal one instead, as if the film had
		// snagged sideways for a frame.
		bool horizontal = hash13(vec3(scratch_epoch, 63.4, 17.8)) < scratch_horizontal_chance;
		if (horizontal) {
			float half_len = clamp(scratch_length, 0.02, 1.0) * 0.5 * 0.35;
			float x0 = clamp(rx - half_len, 0.0, 1.0);
			float x1 = clamp(rx + half_len, 0.0, 1.0);
			if (uv.x > x0 && uv.x < x1) {
				float line_y = ry + rslant * 0.08 * (uv.x - rx);
				float dy = abs(uv.y - line_y) / max(SCREEN_PIXEL_SIZE.y * max(scratch_width, 0.1), 0.0001);
				float line_mask = 1.0 - smoothstep(0.0, 1.0, dy);
				base += vec3(line_mask * envelope * scratch_opacity * amt);
			}
		} else {
			float half_len = clamp(scratch_length, 0.02, 1.0) * 0.5;
			float y0 = clamp(ry - half_len, 0.0, 1.0);
			float y1 = clamp(ry + half_len, 0.0, 1.0);
			if (uv.y > y0 && uv.y < y1) {
				float line_x = rx + rslant * 0.08 * (uv.y - ry);
				float dx = abs(uv.x - line_x) / max(SCREEN_PIXEL_SIZE.x * max(scratch_width, 0.1), 0.0001);
				float line_mask = 1.0 - smoothstep(0.0, 1.0, dx);
				base += vec3(line_mask * envelope * scratch_opacity * amt);
			}
		}
	}

	// --- Flicker: a small overall brightness wobble, blended between a
	// smooth wave and a stepped random one.
	float flicker_wave = sin(TIME * flicker_speed);
	float flicker_step = hash11(floor(TIME * flicker_speed)) * 2.0 - 1.0;
	float flicker = mix(flicker_wave, flicker_step, clamp(flicker_smoothness, 0.0, 1.0));
	base *= 1.0 + flicker * flicker_amount * amt;

	// --- Vignette: the film's own soft corners, separate from the
	// gameplay vignette drawn above this.
	vec2 center_off = uv - vec2(0.5);
	float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.000001);
	center_off.x *= mix(1.0, aspect, 0.4);
	float dist = length(center_off) * 2.0;
	float vt = clamp(
		(dist - vignette_radius) / max(vignette_softness, 0.001), 0.0, 1.0);
	float shade = vt * vignette_amount * amt;
	base *= 1.0 - shade;

	COLOR = vec4(clamp(base, 0.0, 1.0), 1.0);
}
