shader_type canvas_item;
// The whole game seen through an old western film reel: grain, dust, the
// occasional sheet of authored film dirt, a faint flicker and frame wobble,
// and a soft vignette - six cheap effects folded into one full-screen pass
// rather than six.
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
// painted. This only grains, dusts, dirties, flickers, wobbles and vignettes
// whatever colour is already there.
//
// Every knob below is tuned to be continuously noticeable - grain always
// animating, dust motes always turning over somewhere on screen, an
// authored sheet of film dirt washing over the frame every few seconds - so
// the whole frame reads as an old projected reel rather than a game with a
// faint grain filter over it. It still has to lose to a muzzle flash or a
// bounty's blood, never compete with them.

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

group_uniforms Grain_Sheet;
// The authored film-dirt sheet - [code]Assets/UI/HUD/FilmGrain.png[/code] -
// laid over the frame in short bursts rather than held there permanently,
// the way the irregular analog imperfections in an old animated short come
// and go. It is a mostly-transparent sheet of dark specks, blotches and
// hairs, composited by its own alpha and lifted toward white by
// [member grain_sheet_whiteness], so the marks read as bright flaws in the
// film rather than dirt sitting on the lens.
//
// This is deliberately *not* a second copy of the procedural grain above:
// that one is a fine, always-on stock texture, this one is the occasional
// irregular accident on top of it. Both are folded into this same pass -
// the flicker and the vignette below still act on the result - so nothing
// here bypasses the film post process it belongs to.
//
// [b]The sheet is never shown whole.[/b] A burst is broken into a handful of
// separate fragments scattered across the frame, each reading its own
// magnified corner of the artwork, each jumping and blinking on its own while
// it is up, with clear film left between them - see the Patches uniforms
// below and grain_sheet_fragments(). Laying the whole texture down at once
// reads as a still image being faded in and out over the game, which is
// exactly what an analog imperfection is not.
uniform sampler2D grain_sheet_texture : hint_default_transparent, repeat_enable, filter_linear;
// Peak strength of one burst, multiplied into the sheet's own alpha. 0
// switches the sheet off entirely and leaves the rest of the reel exactly as
// it was.
uniform float grain_sheet_amount : hint_range(0.0, 2.0) = 0.18;
// How far each speck is pulled toward white before it is laid down. The
// authored sheet is drawn in near-black ink; at 0 it is composited exactly
// as authored and can only darken, at 1 every mark reads as bright exposed
// film. The sheet's own alpha still decides where the marks land either
// way - this only changes what colour they are once they get there.
uniform float grain_sheet_whiteness : hint_range(0.0, 1.0) = 0.85;
// How often the sheet gets a chance to appear, in chances per second. Each
// chance still has to pass [member grain_sheet_chance], so this is the beat
// the bursts are picked from rather than how often one actually lands.
uniform float grain_sheet_frequency : hint_range(0.02, 4.0) = 0.35;
// Fraction of those chances that actually produce a burst. Below 1 the
// bursts stop arriving on a metronome and start reading as an irregular
// accident - a couple close together, then nothing for a while.
uniform float grain_sheet_chance : hint_range(0.0, 1.0) = 0.45;
// How long one burst lasts, in seconds - it eases in and back out across
// this window rather than snapping.
uniform float grain_sheet_duration : hint_range(0.02, 4.0) = 0.2;
// How much of the sheet is stretched across the screen. 1 fits the whole
// sheet to the frame; smaller magnifies a part of it, larger tiles it.
uniform float grain_sheet_scale : hint_range(0.25, 4.0) = 1.0;
// How many times a second the burst re-rolls how strongly it is showing, so
// it stutters like projected frames instead of fading smoothly.
uniform float grain_sheet_frame_rate : hint_range(0.0, 30.0) = 14.0;

// --- How the sheet is broken up.
// The sheet is never laid down whole. The screen is divided into this many
// cells, and only some of them carry a fragment at any moment, so what
// reaches the frame is a scatter of separate irregular patches with clear
// film between them rather than one texture stretched over everything.
uniform vec2 grain_sheet_patch_grid = vec2(6.0, 4.0);
// Fraction of the cells carrying a fragment at any one moment. Low keeps the
// screen mostly clear with a few accidents on it; 1 fills every cell.
uniform float grain_sheet_patch_chance : hint_range(0.0, 1.0) = 0.32;
// Radius of one fragment as a fraction of its own cell, before its own rolled
// size and aspect. Capped at 0.45 so a fragment always fits inside its cell.
uniform float grain_sheet_patch_size : hint_range(0.05, 0.45) = 0.34;
// How soft a fragment's edge is, as a fraction of its radius. High feathers
// it into the frame, low leaves a harder-edged blotch.
uniform float grain_sheet_patch_softness : hint_range(0.0, 1.0) = 0.6;
// How far into the sheet each fragment magnifies. Above 1 means a fragment
// reads a small corner of the artwork rather than a shrunken copy of the
// whole of it, which is what keeps the specks the size they were drawn.
uniform float grain_sheet_patch_zoom : hint_range(1.0, 16.0) = 5.0;
// How far a fragment jumps on each flash step, in cell widths - the analog
// shake that stops a fragment sitting still while it is on screen. 0 pins
// the fragments in place and leaves only the blinking.
uniform float grain_sheet_shake : hint_range(0.0, 1.0) = 0.3;

group_uniforms Dash_Burst;
// The dash's own throw of grain across the frame, driven from
// [method FilmPostProcess.grain_burst] - 0 at rest, raised to 1 the instant a
// dash starts and driven back down over the burst's own length. Nothing in
// the shader decides when this happens; it only says what it looks like.
uniform float grain_sheet_burst : hint_range(0.0, 2.0) = 0.0;
// Re-rolled by the same call, so two dashes never scatter their fragments to
// the same places.
uniform float grain_sheet_burst_seed = 0.0;
// Peak strength of a burst's fragments, in the same units as
// [member grain_sheet_amount]. Louder than the ambient sheet - this is an
// event, not the reel's own dirt.
uniform float grain_sheet_burst_amount : hint_range(0.0, 2.0) = 0.5;
// Fraction of the cells carrying a fragment during a burst. Higher than the
// ambient chance, so a dash reads as grain thrown across the whole frame
// while still leaving clear film between the pieces.
uniform float grain_sheet_burst_patch_chance : hint_range(0.0, 1.0) = 0.55;
// How many times a second a burst re-rolls which cells are lit and where
// they sit - much faster than the ambient sheet, which is what makes a dash
// flash rather than fade.
uniform float grain_sheet_burst_flash_rate : hint_range(1.0, 90.0) = 45.0;

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

// One pass of the authored sheet, laid down as scattered fragments rather
// than as one sheet stretched over the frame.
//
// The screen is cut into cells and each cell independently rolls whether it
// carries a fragment right now, where in its cell that fragment sits, how big
// and what shape it is, and which magnified corner of the artwork it reads
// from. A cell that does not roll in contributes nothing at all, so the film
// between the fragments is left exactly as it was - the patches are separate
// accidents on the reel, never one block of texture.
//
// Every one of those rolls is re-taken on each flash step, so the set of lit
// fragments moves around the screen and each one jumps a little while it is
// up. That is the whole difference between this and a still image being faded
// in and out.
//
// The same function draws the reel's own ambient dirt and the dash burst -
// they differ only in how strong they are, how many cells they light and how
// fast they re-roll, which is why a dash cannot look like a second effect
// bolted on beside the film.
vec3 grain_sheet_fragments(
	vec3 base,
	vec2 uv,
	float seed,
	float strength,
	float chance,
	float flash_rate,
	float amt
) {
	if (strength <= 0.0 || chance <= 0.0) {
		return base;
	}

	vec2 grid = max(grain_sheet_patch_grid, vec2(1.0));
	vec2 cell_uv = uv * grid;
	vec2 cell = floor(cell_uv);
	vec2 local = fract(cell_uv);

	// Which cells are lit is re-rolled on every step, so the fragments blink
	// from one part of the screen to another instead of staying put.
	float step_epoch = floor(TIME * max(flash_rate, 1.0));
	float step_seed = seed * 7.0 + step_epoch * 29.0;
	if (hash13(vec3(cell, step_seed)) >= chance) {
		return base;
	}

	// The jump this fragment is taking on this step - small, and reused below
	// to slide the piece of artwork it is reading, so the marks inside it
	// move with it rather than the patch sliding over a fixed texture.
	vec2 jump = vec2(
		hash13(vec3(cell, step_seed + 3.0)),
		hash13(vec3(cell, step_seed + 9.0))
	) - 0.5;

	// Its own size and its own aspect, on separate hash axes, so no two
	// fragments come out the same shape.
	vec2 radius = clamp(
		vec2(max(grain_sheet_patch_size, 0.02)) * vec2(
			mix(0.55, 1.35, hash13(vec3(cell, seed + 59.0))),
			mix(0.55, 1.35, hash13(vec3(cell, seed + 67.0)))
		), vec2(0.02), vec2(0.45));

	// Its place inside its own cell, wrapped into the room its own size leaves
	// it. Wrapping rather than clamping is what keeps a fragment whole: a patch
	// allowed to run off the edge of its cell would be cut off there in a
	// straight line, and a straight edge is the one thing an accident on a reel
	// never has. Nothing is lost to the wrap, because which cells are lit is
	// re-rolled on the very next step anyway.
	vec2 free = max(vec2(1.0) - radius * 2.0, vec2(0.0));
	vec2 centre = radius + free * fract(vec2(
		hash13(vec3(cell, seed + 31.0)),
		hash13(vec3(cell, seed + 47.0))
	) + jump * grain_sheet_shake);

	float patch = 1.0 - smoothstep(
		1.0 - clamp(grain_sheet_patch_softness, 0.0, 0.999),
		1.0,
		length((local - centre) / radius));
	if (patch <= 0.0) {
		return base;
	}

	// A magnified, randomly-placed, sometimes-mirrored corner of the sheet.
	// Magnifying is what keeps the specks the size they were drawn instead of
	// squeezing the whole artwork into a patch, and it is the sheet's own
	// alpha inside the patch that gives the fragment its ragged edges.
	float flip = hash13(vec3(cell, seed + 83.0)) > 0.5 ? -1.0 : 1.0;
	vec2 sheet_uv = vec2(uv.x * flip, uv.y)
		* max(grain_sheet_patch_zoom, 1.0) / max(grain_sheet_scale, 0.05)
		+ vec2(
			hash13(vec3(cell, seed + 97.0)),
			hash13(vec3(cell, seed + 113.0))
		) * 11.0
		+ jump * grain_sheet_shake * 0.5;
	vec4 sheet = texture(grain_sheet_texture, sheet_uv);

	// Each fragment also rolls how brightly it is showing on this step, so a
	// burst stutters the way projected frames do rather than dissolving.
	float gate = mix(0.35, 1.0, hash13(vec3(cell, step_seed + 17.0)));
	float mask = clamp(sheet.a * patch * gate * strength * amt, 0.0, 1.0);
	vec3 rgb = mix(sheet.rgb, vec3(1.0), clamp(grain_sheet_whiteness, 0.0, 1.0));
	return mix(base, rgb, mask);
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

	// --- Grain sheet: the authored film-dirt sheet, thrown over the frame in
	// short bursts as a scatter of separate fragments. Every burst rolls its
	// own chance to happen at all, and inside it every fragment rolls its own
	// place, shape and corner of the artwork - see grain_sheet_fragments().
	float sheet_cycle = 1.0 / max(grain_sheet_frequency, 0.02);
	float sheet_epoch = floor(TIME / sheet_cycle);
	float sheet_t = fract(TIME / sheet_cycle);
	float sheet_life = clamp(grain_sheet_duration / sheet_cycle, 0.01, 1.0);
	float sheet_roll = hash13(vec3(sheet_epoch, 5.7, 91.3));
	if (sheet_roll < grain_sheet_chance && sheet_t < sheet_life) {
		float lt = sheet_t / sheet_life;
		float envelope = sin(lt * 3.14159265);
		base = grain_sheet_fragments(
			base,
			uv,
			sheet_epoch,
			envelope * max(grain_sheet_amount, 0.0),
			grain_sheet_patch_chance,
			grain_sheet_frame_rate,
			amt);
	}

	// --- Dash burst: the same fragments, thrown harder and re-rolled far
	// faster, for as long as whoever dashed holds grain_sheet_burst up. It is
	// laid down here, inside the same pass and in the same place in it, so the
	// flicker and the vignette below still act on it exactly as they do on the
	// reel's own dirt - a dash is a louder moment of the film, not a second
	// effect drawn beside it.
	if (grain_sheet_burst > 0.0) {
		base = grain_sheet_fragments(
			base,
			uv,
			grain_sheet_burst_seed + 401.0,
			grain_sheet_burst * max(grain_sheet_burst_amount, 0.0),
			grain_sheet_burst_patch_chance,
			grain_sheet_burst_flash_rate,
			amt);
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
