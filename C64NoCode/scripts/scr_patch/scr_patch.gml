/// C64 NO-CODE STUDIO - Patch sounds (Sound page, kind 2), ported from ADAM's Patch synth.
/// ADAM renders its patch into a Paula sample. The SID already is the synth ADAM imitates -
/// three oscillators, hard sync, ring modulation, a resonant multimode filter - so here a patch
/// plays on the real chip: the studio works out what to write to every SID register on every
/// frame (pitch envelope, LFOs, modulation slots, filter envelope and key follow are computed
/// here), stores only the registers that change, and a small player in the game streams that
/// table into the SID once a frame. The preview plays the very same table through a model of
/// all three SID voices.
///
/// Oscillators 1 and 2 are SID voices 1 and 2 (the SID syncs and ring-modulates voice 2 from
/// voice 1). Oscillator 3 takes the first free voice: voice 1 or 2 when one is unused, else
/// voice 3, which it borrows from the music while it plays. FM, unison, chorus, drive, crush and
/// echo are sample tricks with no SID equivalent, so they are not here; the SID's own combined
/// waveforms and per-voice filter routing are.

#macro PATCH_MAX_FRAMES 250

function patch_defs_init()
{
    var _lfo = ["Sine", "Triangle", "Square", "Saw", "Random"];
    var _src = ["None", "LFO 1", "LFO 2", "Filter env", "Amp env", "Pitch env"];
    var _dst = ["Pitch", "Osc 2 pitch", "Pulse width", "Cutoff", "Resonance", "Volume", "Osc 3 pitch"];
    // [name, min, max, kind (0 slider, 1 list, 2 toggle), label, help, list or format]
    // formats: 0 number, 1 %, 2 semitones, 3 cents, 4 env time, 5 LFO Hz, 6 seconds, 7 octaves, 9 note, 13 SID attack, 14 SID decay/release, 15 SID level, 16 delay (0 = off)
    global.PATCH_DEF = [
        ["key", 0, 59, 0, "Note", "Note|The note the patch plays.", 9],
        ["o1_wave", 0, 6, 1, "Wave", "Oscillator 1 wave (SID voice 1)|The SID's waveforms: triangle is soft, sawtooth bright, pulse the classic chip sound (set its width), noise for drums and effects - and the SID's combined waveforms, quieter and metallic.", global.WAVE_NAMES],
        ["o1_oct", -3, 3, 0, "Octave", "Octave|Moves this oscillator up or down by whole octaves.", 7],
        ["o1_semi", -12, 12, 0, "Semitones", "Semitones|Tunes this oscillator in semitones: +7 is a fifth above, +12 an octave.", 2],
        ["o1_fine", -50, 50, 0, "Fine tune", "Fine tune|Detunes slightly, in cents. Two voices a few cents apart sound thick and chorused.", 3],
        ["o1_lvl", 0, 100, 0, "Level", "Level|How loud this oscillator holds after its decay. The SID has one volume for the whole chip, so every voice peaks at full - the level sets how far its own envelope sustains. 0 switches it off (as a sync or ring source it still runs, silently).", 1],
        ["o1_pw", 5, 95, 0, "Pulse width", "Pulse width|For pulse waves ($D402): 50% is hollow, small or large values thin and nasal.", 1],
        ["o2_wave", 0, 6, 1, "Wave", "Oscillator 2 wave (SID voice 2)|The second oscillator. The SID can sync it to oscillator 1 or ring-modulate it by oscillator 1.", global.WAVE_NAMES],
        ["o2_oct", -3, 3, 0, "Octave", "Octave|Moves this oscillator up or down by whole octaves.", 7],
        ["o2_semi", -12, 12, 0, "Semitones", "Semitones|Tunes this oscillator in semitones.", 2],
        ["o2_fine", -50, 50, 0, "Fine tune", "Fine tune|Detunes slightly, in cents.", 3],
        ["o2_lvl", 0, 100, 0, "Level", "Level|How loud oscillator 2 holds after its decay. 0 switches it off.", 1],
        ["o2_pw", 5, 95, 0, "Pulse width", "Pulse width|For pulse waves.", 1],
        ["o3_wave", 0, 6, 1, "Wave", "Oscillator 3 wave|A third oscillator - noise here adds breath or a drum crack. It plays on the first free SID voice; when oscillators 1 and 2 are both in use it borrows voice 3 from the music.", global.WAVE_NAMES],
        ["o3_oct", -3, 3, 0, "Octave", "Octave|Moves this oscillator up or down by whole octaves.", 7],
        ["o3_semi", -12, 12, 0, "Semitones", "Semitones|Tunes this oscillator in semitones.", 2],
        ["o3_fine", -50, 50, 0, "Fine tune", "Fine tune|Detunes slightly, in cents.", 3],
        ["o3_lvl", 0, 100, 0, "Level", "Level|How loud oscillator 3 holds after its decay. 0 switches it off.", 1],
        ["o3_pw", 5, 95, 0, "Pulse width", "Pulse width|For pulse waves.", 1],
        ["sync", 0, 1, 2, "Sync osc 2 to osc 1", "Hard sync|The SID restarts voice 2's waveform every time voice 1's starts ($D40B bit 1). Tune osc 2 higher, or sweep its pitch, for the classic tearing sync lead.", 0],
        ["ring", 0, 1, 2, "Ring mod osc 2 by osc 1", "Ring modulation|The SID ring-modulates voice 2's triangle by voice 1 ($D40B bit 2): bells, gongs and robots. It only works on a triangle wave - pick Triangle for osc 2.", 0],
        ["amp_a", 0, 15, 0, "Attack", "Attack|How quickly the sound fades in - the SID's own attack rates ($D405).", 13],
        ["amp_d", 0, 15, 0, "Decay", "Decay|How quickly it falls from full volume to the sustain level.", 14],
        ["amp_s", 0, 15, 0, "Sustain", "Sustain|The volume held while the note is on ($D406). 0 makes plucks and drums.", 15],
        ["amp_r", 0, 15, 0, "Release", "Release|How long it fades after the note ends.", 14],
        ["gate", 1, 400, 0, "Note length", "Note length|How long the note is held before the release.", 6],
        ["vol", 0, 15, 0, "Volume", "Volume|The SID's master volume while the patch plays ($D418) - it is the chip's only volume, so it turns the music down too.", 0],
        ["penv", -48, 48, 0, "Pitch drop", "Pitch envelope|The pitch starts this many semitones away and glides back to the note. Positive values fall (kicks, lasers), negative values rise (risers).", 2],
        ["pdec", 0, 100, 0, "Pitch time", "Pitch envelope time|How long the pitch takes to glide back.", 4],
        ["flt", 0, 4, 1, "Filter", "Filter type|The SID's filter: low pass darker, high pass thinner, band pass a band in the middle, notch (low + high) scoops the middle out.", ["Off", "Low pass", "High pass", "Band pass", "Notch (low + high)"]],
        ["cut", 0, 100, 0, "Cutoff", "Cutoff|Where the filter cuts ($D415-$D416).", 1],
        ["res", 0, 15, 0, "Resonance", "Resonance|Boosts the cutoff frequency ($D417): squelchy and whistling when high. Real 6581 chips differ a lot here.", 0],
        ["rt1", 0, 1, 2, "Filter osc 1", "Filter osc 1|Send oscillator 1 through the filter ($D417).", 0],
        ["rt2", 0, 1, 2, "Filter osc 2", "Filter osc 2|Send oscillator 2 through the filter.", 0],
        ["rt3", 0, 1, 2, "Filter osc 3", "Filter osc 3|Send oscillator 3 through the filter.", 0],
        ["fenv", -100, 100, 0, "Env amount", "Filter envelope amount|How far the filter envelope opens (+) or closes (-) the cutoff, up to six octaves.", 1],
        ["ktrk", 0, 100, 0, "Key follow", "Key follow|How much the cutoff follows the note, so high notes are as bright as low ones.", 1],
        ["fa", 0, 100, 0, "Attack", "Filter attack|How quickly the filter envelope rises.", 4],
        ["fd", 0, 100, 0, "Decay", "Filter decay|How quickly it falls to its sustain level - short for plucks and acid basses.", 4],
        ["fs", 0, 100, 0, "Sustain", "Filter sustain|Where the filter envelope rests while the note is held.", 1],
        ["fr", 0, 100, 0, "Release", "Filter release|How quickly it falls after the note ends.", 4],
        ["l1_wave", 0, 4, 1, "LFO 1 shape", "LFO 1 shape|A slow wave that moves other settings (pick where it goes in the slots below). It is worked out once a frame, so it can wobble up to 25 times a second.", _lfo],
        ["l1_rate", 0, 100, 0, "LFO 1 rate", "LFO 1 rate|From one wobble every 20 seconds to 25 a second.", 5],
        ["l1_dly", 0, 100, 0, "LFO 1 delay", "LFO 1 delay|The LFO fades in after this long - delayed vibrato.", 16],
        ["l2_wave", 0, 4, 1, "LFO 2 shape", "LFO 2 shape|A second slow wave.", _lfo],
        ["l2_rate", 0, 100, 0, "LFO 2 rate", "LFO 2 rate|From one wobble every 20 seconds to 25 a second.", 5],
        ["l2_dly", 0, 100, 0, "LFO 2 delay", "LFO 2 delay|The LFO fades in after this long.", 16],
        ["m1_src", 0, 5, 1, "Source", "Modulation source|What moves the setting: an LFO or one of the envelopes.", _src],
        ["m1_dst", 0, 6, 1, "Target", "Modulation target|The setting that is moved.", _dst],
        ["m1_amt", -100, 100, 0, "Amount", "Modulation amount|How far, and which way. Small amounts on pitch make vibrato.", 1],
        ["m2_src", 0, 5, 1, "Source", "Modulation source|What moves the setting.", _src],
        ["m2_dst", 0, 6, 1, "Target", "Modulation target|The setting that is moved.", _dst],
        ["m2_amt", -100, 100, 0, "Amount", "Modulation amount|How far, and which way.", 1],
        ["m3_src", 0, 5, 1, "Source", "Modulation source|What moves the setting.", _src],
        ["m3_dst", 0, 6, 1, "Target", "Modulation target|The setting that is moved.", _dst],
        ["m3_amt", -100, 100, 0, "Amount", "Modulation amount|How far, and which way.", 1]
    ];
    global.PATCH_IDX = {};
    for (var i = 0; i < array_length(global.PATCH_DEF); i++) { global.PATCH_IDX[$ global.PATCH_DEF[i][0]] = global.PATCH_DEF[i]; }

    // Preset patches (ADAM's, made for the SID): [name, settings that differ from patch_new()]
    global.PATCH_PRESETS = [
        ["Init", {}],
        ["Acid bass", { key : 12, o1_wave : 1, flt : 1, cut : 12, res : 14, fenv : 70, fd : 30, fs : 0, amp_d : 6, amp_s : 10, amp_r : 3, gate : 25 }],
        ["PWM bass", { key : 12, o1_wave : 2, o1_pw : 30, flt : 1, cut : 25, res : 6, fenv : 40, fd : 25, amp_d : 7, amp_s : 6, amp_r : 4, gate : 25, l1_rate : 30, m1_src : 1, m1_dst : 2, m1_amt : 40 }],
        ["Fat saw bass", { key : 12, o1_wave : 1, o2_wave : 1, o2_fine : 14, o2_lvl : 100, o2_oct : -1, flt : 1, cut : 30, res : 5, fenv : 25, fd : 40, amp_s : 12, gate : 40 }],
        ["Square lead", { key : 36, o1_wave : 2, o1_pw : 40, flt : 0, l1_rate : 56, l1_dly : 35, m1_src : 1, m1_dst : 0, m1_amt : 14, amp_d : 6, amp_s : 12, amp_r : 6, gate : 60 }],
        ["PWM lead", { key : 36, o1_wave : 2, flt : 0, l1_rate : 35, m1_src : 1, m1_dst : 2, m1_amt : 60, amp_s : 12, gate : 60 }],
        ["Sync lead", { key : 36, o1_lvl : 0, o2_wave : 1, o2_lvl : 100, o2_oct : 1, sync : 1, m1_src : 3, m1_dst : 1, m1_amt : 75, fd : 45, fs : 20, flt : 0, amp_s : 12, gate : 60 }],
        ["Ring bell", { key : 36, o1_wave : 0, o1_lvl : 0, o2_wave : 0, o2_lvl : 100, o2_oct : 1, o2_semi : 3, ring : 1, flt : 0, amp_a : 0, amp_d : 10, amp_s : 0, amp_r : 10, gate : 30 }],
        ["Organ", { key : 24, o1_wave : 0, o2_wave : 0, o2_oct : 1, o2_lvl : 60, o3_wave : 0, o3_oct : 2, o3_lvl : 40, flt : 0, amp_d : 2, amp_s : 15, amp_r : 4, gate : 80 }],
        ["Warm pad", { key : 24, o1_wave : 1, o2_wave : 1, o2_fine : 15, o2_lvl : 100, flt : 1, cut : 30, res : 4, l1_rate : 18, m1_src : 1, m1_dst : 3, m1_amt : 25, amp_a : 9, amp_d : 9, amp_s : 12, amp_r : 10, gate : 150 }],
        ["Pluck", { key : 36, o1_wave : 2, o1_pw : 25, flt : 1, cut : 35, fenv : 50, fd : 20, amp_d : 6, amp_s : 0, amp_r : 6, gate : 20 }],
        ["Kick", { key : 12, o1_wave : 0, penv : 36, pdec : 18, flt : 0, amp_d : 7, amp_s : 0, amp_r : 5, gate : 8 }],
        ["Snare", { key : 24, o1_wave : 0, o1_lvl : 60, penv : 12, pdec : 10, o3_wave : 3, o3_lvl : 100, o3_oct : 2, flt : 3, cut : 55, res : 4, rt1 : 0, amp_d : 6, amp_s : 0, amp_r : 6, gate : 6 }],
        ["Hi-hat", { key : 48, o1_lvl : 0, o3_wave : 3, o3_lvl : 100, o3_oct : 2, flt : 2, cut : 70, res : 4, amp_d : 3, amp_s : 0, amp_r : 3, gate : 3 }],
        ["Laser", { key : 48, o1_wave : 2, penv : 36, pdec : 26, flt : 0, amp_d : 6, amp_s : 0, amp_r : 5, gate : 12 }],
        ["Zap", { key : 40, o1_wave : 1, o2_wave : 0, o2_lvl : 70, o2_oct : 1, ring : 1, penv : -30, pdec : 12, flt : 0, amp_d : 5, amp_s : 0, amp_r : 4, gate : 10 }],
        ["Riser", { key : 24, o1_wave : 1, o2_wave : 1, o2_fine : 15, o2_lvl : 100, o3_wave : 3, o3_lvl : 30, penv : -24, pdec : 80, flt : 1, cut : 10, fenv : 70, fa : 80, fs : 100, amp_a : 9, amp_s : 15, amp_r : 8, gate : 150 }],
        ["Explosion", { key : 12, o1_lvl : 0, o3_wave : 3, o3_lvl : 100, flt : 1, cut : 35, res : 8, fenv : 50, fd : 60, fs : 0, amp_d : 10, amp_s : 0, amp_r : 9, gate : 20 }],
        ["Wind", { key : 24, o1_lvl : 0, o3_wave : 3, o3_lvl : 100, o3_oct : 2, flt : 3, cut : 30, res : 12, l1_rate : 10, m1_src : 1, m1_dst : 3, m1_amt : 60, amp_a : 10, amp_s : 15, amp_r : 10, gate : 200 }]
    ];
    global.PATCH_PRESET_NAMES = [];
    global.PATCH_PRESET_MENU = ["Choose a preset..."];
    for (var p = 0; p < array_length(global.PATCH_PRESETS); p++)
    {
        array_push(global.PATCH_PRESET_NAMES, global.PATCH_PRESETS[p][0]);
        array_push(global.PATCH_PRESET_MENU, global.PATCH_PRESETS[p][0]);
    }
    global.patch_cache = {};
    global.patch_cache_n = 0;
}

function patch_new()
{
    return {
        key : 24,
        o1_wave : 1, o1_oct : 0, o1_semi : 0, o1_fine : 0, o1_lvl : 100, o1_pw : 50,
        o2_wave : 2, o2_oct : 0, o2_semi : 0, o2_fine : 7, o2_lvl : 0, o2_pw : 50,
        o3_wave : 3, o3_oct : 0, o3_semi : 0, o3_fine : 0, o3_lvl : 0, o3_pw : 50,
        sync : 0, ring : 0,
        amp_a : 0, amp_d : 8, amp_s : 10, amp_r : 6, gate : 40, vol : 15,
        penv : 0, pdec : 20,
        flt : 1, cut : 45, res : 8, rt1 : 1, rt2 : 1, rt3 : 1, fenv : 0, ktrk : 50, fa : 0, fd : 35, fs : 0, fr : 30,
        l1_wave : 0, l1_rate : 40, l1_dly : 0, l2_wave : 0, l2_rate : 20, l2_dly : 0,
        m1_src : 0, m1_dst : 0, m1_amt : 0, m2_src : 0, m2_dst : 3, m2_amt : 0, m3_src : 0, m3_dst : 5, m3_amt : 0
    };
}

/// A patch read from a file: every known setting, clamped; anything else ignored
function patch_from_loaded(_raw)
{
    var _p = patch_new();
    if (!is_struct(_raw)) { return _p; }
    for (var i = 0; i < array_length(global.PATCH_DEF); i++)
    {
        var _d = global.PATCH_DEF[i];
        var _v = _raw[$ _d[0]];
        if (is_numeric(_v)) { _p[$ _d[0]] = clamp(round(_v), _d[1], _d[2]); }
    }
    return _p;
}

function patch_apply_preset(_p, _i)
{
    var _fresh = patch_new();
    var _over = global.PATCH_PRESETS[clamp(_i, 0, array_length(global.PATCH_PRESETS) - 1)][1];
    var _names = variable_struct_get_names(_fresh);
    for (var i = 0; i < array_length(_names); i++) { _p[$ _names[i]] = _fresh[$ _names[i]]; }
    var _on = variable_struct_get_names(_over);
    for (var k = 0; k < array_length(_on); k++) { _p[$ _on[k]] = _over[$ _on[k]]; }
}

/// Randomise (_amount 1) or mutate (_amount < 1: nudge some settings)
function patch_randomise(_p, _amount)
{
    for (var i = 0; i < array_length(global.PATCH_DEF); i++)
    {
        var _d = global.PATCH_DEF[i];
        if (_d[0] == "key" || _d[0] == "vol") { continue; }
        if (_amount >= 1)
        {
            _p[$ _d[0]] = irandom_range(_d[1], _d[2]);
        }
        else if (random(1) < 0.35 && _d[3] == 0)
        {
            var _span = (_d[2] - _d[1]) * _amount;
            _p[$ _d[0]] = clamp(round(_p[$ _d[0]] + random_range(-_span, _span)), _d[1], _d[2]);
        }
    }
    if (_amount >= 1)
    {
        // keep it playable: something audible, not too long
        _p.o1_lvl = irandom_range(60, 100);
        _p.gate = irandom_range(10, 120);
        _p.amp_a = irandom_range(0, 8);
        _p.amp_r = irandom_range(2, 9);
        _p.res = irandom_range(0, 12);
        _p.cut = irandom_range(20, 90);
    }
}

function patch_env_ms(_v) { return 1 + 0.8 * _v * _v; }
function patch_lfo_hz(_v) { return 0.05 * power(2, _v / 100 * 9); }

/// The frequency of patch note _key (0 = C-1 ... 59 = B-5)
function patch_key_hz(_key) { return 32.7032 * power(2, _key / 12); }

function patch_key_name(_key)
{
    var _k = clamp(round(_key), 0, 59);
    return global.MUS_NOTE_NAMES[_k mod 12] + string(_k div 12 + 1);
}

/// One envelope value (0..1) at time _t (seconds) for a note held _gate seconds
function patch_adsr(_t, _a, _d, _s, _r, _gate)
{
    var _lvl = 0;
    var _held = min(_t, _gate);
    if (_held < _a) { _lvl = _held / max(0.0001, _a); }
    else
    {
        var _x = min(1, (_held - _a) / max(0.0001, _d));
        _lvl = _s + (1 - _s) * (1 - _x) * (1 - _x);
    }
    if (_t > _gate)
    {
        var _xr = min(1, (_t - _gate) / max(0.0001, _r));
        _lvl *= (1 - _xr) * (1 - _xr);
    }
    return _lvl;
}

/// An LFO value in -1..1 (Random holds a value per cycle)
function patch_lfo(_wave, _ph, _rnd)
{
    switch (_wave)
    {
        case 1: return 1 - 4 * abs(_ph - 0.5);
        case 2:
            if (_ph < 0.5) { return 1; }
            return -1;
        case 3: return _ph * 2 - 1;
        case 4: return _rnd;
    }
    return sin(_ph * 2 * pi);
}

/// Which SID voice (0..2) each oscillator plays on, or -1 when it is not used
function patch_voices(_p)
{
    var _v = [-1, -1, -1];
    var _free = [true, true, true];
    if (_p.o1_lvl > 0 || _p.sync || _p.ring)
    {
        _v[0] = 0;
        _free[0] = false;
    }
    if (_p.o2_lvl > 0)
    {
        _v[1] = 1;
        _free[1] = false;
    }
    if (_p.o3_lvl > 0)
    {
        for (var i = 0; i < 3; i++)
        {
            if (_free[i])
            {
                _v[2] = i;
                _free[i] = false;
                break;
            }
        }
    }
    return _v;
}

/// The voices a patch uses as a bit mask (1 = voice 1, 2 = voice 2, 4 = voice 3)
function patch_voice_mask(_p)
{
    var _v = patch_voices(_p);
    var _m = 0;
    for (var i = 0; i < 3; i++)
    {
        if (_v[i] >= 0) { _m |= 1 << _v[i]; }
    }
    return _m;
}

/// The SID registers, frame by frame: an array of frames, each 25 values for $D400-$D418
/// (-1 = not written that frame). Cached.
function patch_frames(_p)
{
    var _key = json_stringify(_p) + "|" + string(sid_clock());
    var _hit = global.patch_cache[$ _key];
    if (!is_undefined(_hit)) { return _hit; }
    var _fps = sid_fps();
    var _hz0 = patch_key_hz(_p.key);
    var _vo = patch_voices(_p);
    var _gate_s = _p.gate / 100;
    var _gate_f = max(1, round(_gate_s * _fps));
    var _rel_s = global.SID_DR_MS[clamp(_p.amp_r, 0, 15)] / 1000;
    var _nf = min(PATCH_MAX_FRAMES, _gate_f + ceil(_rel_s * _fps) + 1);
    var _w = [_p.o1_wave, _p.o2_wave, _p.o3_wave];
    var _lv = [_p.o1_lvl / 100, _p.o2_lvl / 100, _p.o3_lvl / 100];
    var _pwb = [_p.o1_pw / 100, _p.o2_pw / 100, _p.o3_pw / 100];
    var _tune = [_p.o1_oct * 12 + _p.o1_semi + _p.o1_fine / 100, _p.o2_oct * 12 + _p.o2_semi + _p.o2_fine / 100, _p.o3_oct * 12 + _p.o3_semi + _p.o3_fine / 100];
    var _rt = [_p.rt1, _p.rt2, _p.rt3];
    var _aa = global.SID_ATK_MS[clamp(_p.amp_a, 0, 15)] / 1000;
    var _ad = global.SID_DR_MS[clamp(_p.amp_d, 0, 15)] / 1000;
    var _as = _p.amp_s / 15;
    var _fa = patch_env_ms(_p.fa) / 1000;
    var _fd = patch_env_ms(_p.fd) / 1000;
    var _fs = _p.fs / 100;
    var _fr = patch_env_ms(_p.fr) / 1000;
    var _pdec = patch_env_ms(_p.pdec) / 1000;
    var _l_wave = [_p.l1_wave, _p.l2_wave];
    var _l_hz = [patch_lfo_hz(_p.l1_rate), patch_lfo_hz(_p.l2_rate)];
    var _l_dly = [(patch_env_ms(_p.l1_dly) - 1) / 1000, (patch_env_ms(_p.l2_dly) - 1) / 1000];
    var _m_src = [_p.m1_src, _p.m2_src, _p.m3_src];
    var _m_dst = [_p.m1_dst, _p.m2_dst, _p.m3_dst];
    var _m_amt = [_p.m1_amt / 100, _p.m2_amt / 100, _p.m3_amt / 100];
    var _rnd = 22222;
    var _lph = [0, 0];
    var _lrnd = [0, 0];
    var _route = 0;
    for (var o0 = 0; o0 < 3; o0++)
    {
        if (_vo[o0] >= 0 && _rt[o0] && _p.flt > 0) { _route |= 1 << _vo[o0]; }
    }
    var _modes = [0, 0x10, 0x40, 0x20, 0x50];
    var _frames = [];
    for (var f = 0; f < _nf; f++)
    {
        var _t = f / _fps;
        var _e_amp = patch_adsr(_t, _aa, _ad, _as, _rel_s, _gate_s);
        var _e_flt = patch_adsr(_t, _fa, _fd, _fs, _fr, _gate_s);
        var _e_pit = 0;
        if (_t < _pdec) { _e_pit = (1 - _t / _pdec) * (1 - _t / _pdec); }
        var _lval = [0, 0];
        for (var l = 0; l < 2; l++)
        {
            if (f > 0) { _lph[l] += _l_hz[l] / _fps; }
            if (_lph[l] >= 1 || f == 0)
            {
                _lph[l] -= floor(_lph[l]);
                _rnd = (_rnd * 1103515245 + 12345) & 0x7fffffff;
                _lrnd[l] = (_rnd / 0x3fffffff) - 1;
            }
            var _fade = 1;
            if (_l_dly[l] > 0) { _fade = clamp(_t / _l_dly[l], 0, 1); }
            _lval[l] = patch_lfo(_l_wave[l], _lph[l], _lrnd[l]) * _fade;
        }
        var _dm = array_create(7, 0);
        for (var m = 0; m < 3; m++)
        {
            if (_m_src[m] == 0 || _m_amt[m] == 0) { continue; }
            var _sv = 0;
            switch (_m_src[m])
            {
                case 1: _sv = _lval[0]; break;
                case 2: _sv = _lval[1]; break;
                case 3: _sv = _e_flt; break;
                case 4: _sv = _e_amp; break;
                case 5: _sv = _e_pit; break;
            }
            _dm[_m_dst[m]] += _sv * _m_amt[m];
        }
        var _reg = array_create(25, -1);
        // pitch: squared amounts, so small settings make a gentle vibrato
        var _pmain = _p.penv * _e_pit + 12 * _dm[0] * abs(_dm[0]);
        for (var o = 0; o < 3; o++)
        {
            var _vv = _vo[o];
            if (_vv < 0) { continue; }
            var _semis = _tune[o] + _pmain;
            if (o == 1) { _semis += 12 * _dm[1] * abs(_dm[1]); }
            if (o == 2) { _semis += 12 * _dm[6] * abs(_dm[6]); }
            var _fr16 = clamp(round(_hz0 * power(2, _semis / 12) * 16777216 / sid_clock()), 0, 65535);
            var _pw = clamp(round(clamp(_pwb[o] + _dm[2] * 0.45, 0.05, 0.95) * 4095), 0, 4095);
            var _b = _vv * 7;
            _reg[_b] = _fr16 & 255;
            _reg[_b + 1] = _fr16 >> 8;
            _reg[_b + 2] = _pw & 255;
            _reg[_b + 3] = _pw >> 8;
            var _ctrl = global.WAVE_BITS[clamp(_w[o], 0, array_length(global.WAVE_BITS) - 1)];
            if (o == 1 && _vo[0] == 0)
            {
                if (_p.sync) { _ctrl |= 2; }
                if (_p.ring) { _ctrl |= 4; }
            }
            if (f < _gate_f && _lv[o] > 0) { _ctrl |= 1; }
            _reg[_b + 4] = _ctrl;
            _reg[_b + 5] = (clamp(_p.amp_a, 0, 15) << 4) | clamp(_p.amp_d, 0, 15);
            _reg[_b + 6] = (clamp(round(_p.amp_s * _lv[o]), 0, 15) << 4) | clamp(_p.amp_r, 0, 15);
        }
        // filter and volume
        var _fc = 30 + _p.cut / 100 * 2047 * 5.8;
        _fc *= power(_hz0 / 261.63, _p.ktrk / 100);
        _fc *= power(2, _p.fenv / 100 * _e_flt * 6 + _dm[3] * 5);
        var _c11 = clamp(round((_fc - 30) / 5.8), 0, 2047);
        var _res = clamp(round(_p.res + _dm[4] * 15), 0, 15);
        var _vol = clamp(round(_p.vol * clamp(1 + _dm[5], 0, 2)), 0, 15);
        _reg[21] = _c11 & 7;
        _reg[22] = _c11 >> 3;
        _reg[23] = (_res << 4) | _route;
        _reg[24] = _modes[clamp(_p.flt, 0, 4)] | _vol;
        array_push(_frames, _reg);
    }
    global.patch_cache_n += 1;
    if (global.patch_cache_n > 32)
    {
        global.patch_cache = {};
        global.patch_cache_n = 1;
    }
    global.patch_cache[$ _key] = _frames;
    return _frames;
}

/// The frames as the player's table: only changed registers. Each frame starts with a byte:
/// bit 7 = the end; bit 6 = n frames with no change (low 6 bits); else bits 0-3 say which
/// groups follow (voice 1, voice 2, voice 3, filter), each a mask byte then the values.
function patch_encode(_frames)
{
    var _out = [];
    var _last = array_create(25, -1);
    var _idle = 0;
    for (var f = 0; f < array_length(_frames); f++)
    {
        var _reg = _frames[f];
        var _groups = 0;
        var _body = [];
        for (var g = 0; g < 4; g++)
        {
            var _mask = 0;
            var _vals = [];
            for (var r = 0; r < 7; r++)
            {
                var _ri = g * 7 + r;
                if (_ri > 24) { break; }
                if (_reg[_ri] >= 0 && (_reg[_ri] != _last[_ri] || f == 0))
                {
                    _mask |= 1 << r;
                    array_push(_vals, _reg[_ri]);
                    _last[_ri] = _reg[_ri];
                }
            }
            if (_mask != 0)
            {
                _groups |= 1 << g;
                array_push(_body, _mask);
                for (var v = 0; v < array_length(_vals); v++) { array_push(_body, _vals[v]); }
            }
        }
        if (_groups == 0)
        {
            _idle += 1;
            if (_idle == 63)
            {
                array_push(_out, 0x40 | _idle);
                _idle = 0;
            }
            continue;
        }
        if (_idle > 0)
        {
            array_push(_out, 0x40 | _idle);
            _idle = 0;
        }
        array_push(_out, _groups);
        for (var b = 0; b < array_length(_body); b++) { array_push(_out, _body[b]); }
    }
    if (_idle > 0) { array_push(_out, 0x40 | _idle); }
    array_push(_out, 0x80);
    return _out;
}

function patch_bytes(_p)
{
    return array_length(patch_encode(patch_frames(_p)));
}

function patch_seconds(_p)
{
    return array_length(patch_frames(_p)) / sid_fps();
}

// ---------------------------------------------------------------------------
// Preview: the frames played through a model of the whole SID - 3 voices with hard sync and
// ring modulation, the multimode filter with per-voice routing, and the master volume
// ---------------------------------------------------------------------------

function patch_render(_p)
{
    var _frames = patch_frames(_p);
    var _rate = SFX_PREVIEW_RATE;
    var _cyc = sid_clock() / _rate;
    var _spf = _rate / sid_fps();
    var _n = max(64, floor(array_length(_frames) * _spf));
    var _buf = buffer_create(_n * 2, buffer_fixed, 2);
    var _acc = [0, 0, 0];
    var _frq = [0, 0, 0];
    var _pw = [2048, 2048, 2048];
    var _ctl = [0, 0, 0];
    var _ad = [0, 0, 0];
    var _sr = [0, 0, 0];
    var _env = [0, 0, 0];
    var _est = [2, 2, 2];
    var _rc = [0, 0, 0];
    var _ec = [0, 0, 0];
    var _lfsr = [0x7ffff8, 0x7ffff8, 0x7ffff8];
    var _nz = [0, 0, 0];
    var _msb = [false, false, false];
    var _cut = 0, _res = 0, _route = 0, _mode = 0, _vol = 15;
    var _lp = 0, _bp = 0;
    var _outs = array_create(_n, 0);
    var _rose = [false, false, false];
    // only the voices the patch uses are worked out
    var _vm = patch_voice_mask(_p);
    var _act = [];
    for (var a = 0; a < 3; a++)
    {
        if ((_vm & (1 << a)) != 0) { array_push(_act, a); }
    }
    var _na = array_length(_act);
    var _peak = 0.0001;
    var _frame = -1;
    for (var i = 0; i < _n; i++)
    {
        var _f = floor(i / _spf);
        if (_f != _frame && _f < array_length(_frames))
        {
            _frame = _f;
            var _reg = _frames[_f];
            for (var v = 0; v < 3; v++)
            {
                var _b = v * 7;
                if (_reg[_b] >= 0) { _frq[v] = (_frq[v] & 0xff00) | _reg[_b]; }
                if (_reg[_b + 1] >= 0) { _frq[v] = (_frq[v] & 255) | (_reg[_b + 1] << 8); }
                if (_reg[_b + 2] >= 0) { _pw[v] = (_pw[v] & 0xf00) | _reg[_b + 2]; }
                if (_reg[_b + 3] >= 0) { _pw[v] = (_pw[v] & 255) | ((_reg[_b + 3] & 15) << 8); }
                if (_reg[_b + 5] >= 0) { _ad[v] = _reg[_b + 5]; }
                if (_reg[_b + 6] >= 0) { _sr[v] = _reg[_b + 6]; }
                if (_reg[_b + 4] >= 0)
                {
                    var _c = _reg[_b + 4];
                    if ((_c & 1) != 0 && (_ctl[v] & 1) == 0) { _est[v] = 0; _rc[v] = 0; }
                    if ((_c & 1) == 0 && (_ctl[v] & 1) != 0) { _est[v] = 2; }
                    _ctl[v] = _c;
                }
            }
            if (_reg[21] >= 0) { _cut = (_cut & 0x7f8) | (_reg[21] & 7); }
            if (_reg[22] >= 0) { _cut = (_cut & 7) | (_reg[22] << 3); }
            if (_reg[23] >= 0) { _res = _reg[23] >> 4; _route = _reg[23] & 7; }
            if (_reg[24] >= 0) { _mode = _reg[24] & 0x70; _vol = _reg[24] & 15; }
        }
        // oscillators (all three advance, then sync: a voice restarts when its source's top bit rises)
        for (var a1 = 0; a1 < _na; a1++)
        {
            var v1 = _act[a1];
            var _prev = _acc[v1];
            _acc[v1] = (_acc[v1] + _frq[v1] * _cyc) mod 16777216;
            var _m = (_acc[v1] >= 8388608);
            _rose[v1] = (_m && !_msb[v1]) || (_acc[v1] < _prev && _m);
            _msb[v1] = _m;
            if ((_ctl[v1] & 128) != 0)
            {
                var _clocks = floor((_acc[v1] + 524288) / 1048576) - floor((_prev + 524288) / 1048576);
                if (_clocks < 0) { _clocks += 16; }
                var _l = _lfsr[v1];
                for (var c = 0; c < _clocks; c++)
                {
                    var _bit = ((_l >> 22) ^ (_l >> 17)) & 1;
                    _l = ((_l << 1) | _bit) & 0x7fffff;
                }
                _lfsr[v1] = _l;
                _nz[v1] = (((_l >> 20) & 1) << 7) | (((_l >> 18) & 1) << 6) | (((_l >> 14) & 1) << 5) | (((_l >> 11) & 1) << 4)
                        | (((_l >> 9) & 1) << 3) | (((_l >> 5) & 1) << 2) | (((_l >> 2) & 1) << 1) | (_l & 1);
            }
        }
        for (var a2 = 0; a2 < _na; a2++)
        {
            var v2 = _act[a2];
            var _src = (v2 + 2) mod 3;
            if ((_ctl[v2] & 2) != 0 && _rose[_src])
            {
                _acc[v2] = 0;
                _msb[v2] = false;
            }
        }
        var _filt_in = 0;
        var _direct = 0;
        for (var a3 = 0; a3 < _na; a3++)
        {
            var v3 = _act[a3];
            // envelope (the SID's step rates)
            var _per = global.SID_RATE[(_ad[v3] >> 4) & 15];
            if (_est[v3] == 1) { _per = global.SID_RATE[_ad[v3] & 15]; }
            if (_est[v3] == 2) { _per = global.SID_RATE[_sr[v3] & 15]; }
            _rc[v3] += _cyc;
            while (_rc[v3] >= _per)
            {
                _rc[v3] -= _per;
                if (_est[v3] == 0)
                {
                    _env[v3] += 1;
                    if (_env[v3] >= 255) { _env[v3] = 255; _est[v3] = 1; }
                }
                else
                {
                    var _e = _env[v3];
                    var _div = 1;
                    if (_e < 94) { _div = 2; }
                    if (_e < 55) { _div = 4; }
                    if (_e < 27) { _div = 8; }
                    if (_e < 15) { _div = 16; }
                    if (_e < 7) { _div = 30; }
                    _ec[v3] += 1;
                    if (_ec[v3] >= _div)
                    {
                        _ec[v3] = 0;
                        if (_est[v3] == 1)
                        {
                            if (_e > ((_sr[v3] >> 4) & 15) * 17) { _env[v3] -= 1; }
                        }
                        else if (_e > 0) { _env[v3] -= 1; }
                    }
                }
            }
            if (_env[v3] == 0) { continue; }
            var _wb = _ctl[v3] & 0xf0;
            var _a12 = floor(_acc[v3] / 4096);
            var _w = 4095;
            if ((_wb & 16) != 0)
            {
                var _top = (_a12 >= 2048);
                if ((_ctl[v3] & 4) != 0 && _msb[(v3 + 2) mod 3]) { _top = !_top; }     // ring modulation
                var _tt = _a12 & 2047;
                if (_top) { _tt = 2047 - _tt; }
                _w = _w & (_tt * 2);
            }
            if ((_wb & 32) != 0) { _w = _w & _a12; }
            if ((_wb & 64) != 0 && _a12 < _pw[v3]) { _w = 0; }
            if ((_wb & 128) != 0) { _w = _w & (_nz[v3] << 4); }
            if (_wb == 0) { _w = 2048; }
            var _o = (_w / 2047.5 - 1) * (_env[v3] / 255);
            if ((_route & (1 << v3)) != 0) { _filt_in += _o; }
            else { _direct += _o; }
        }
        var _fo = 0;
        if (_mode != 0)
        {
            var _hz = min(30 + _cut * 5.8, _rate * 0.45);
            var _k = 2 * sin(pi * _hz / (_rate * 2));
            var _q = 1 / (0.707 + _res / 15 * 2.2);
            var _hp = 0;
            for (var os = 0; os < 2; os++)
            {
                _hp = _filt_in - _lp - _q * _bp;
                _bp += _k * _hp;
                _lp += _k * _bp;
            }
            if ((_mode & 0x10) != 0) { _fo += _lp; }
            if ((_mode & 0x20) != 0) { _fo += _bp; }
            if ((_mode & 0x40) != 0) { _fo += _hp; }
        }
        else { _fo = _filt_in; }
        _outs[i] = (_fo + _direct) * _vol / 15 * 0.3;
        _peak = max(_peak, abs(_outs[i]));
    }
    var _g = 1;
    if (_peak > 0.9) { _g = 0.9 / _peak; }
    for (var k = 0; k < _n; k++) { buffer_write(_buf, buffer_s16, round(clamp(_outs[k] * _g, -1, 1) * 32000)); }
    return _buf;
}

// ---------------------------------------------------------------------------
// 6502: the patch tables (the player itself is in sid_emit)
// ---------------------------------------------------------------------------

function patch_any(_p)
{
    for (var i = 0; i < min(SFX_MAX, array_length(_p.sfx)); i++)
    {
        if (_p.sfx[i].kind == 2) { return true; }
    }
    return false;
}

/// Pushes every patch sound's table onto L
function patch_emit(L, _p)
{
    array_push(L, "; ---------------- patch sounds: SID register changes, frame by frame ----------------", "pat_start:");
    for (var i = 0; i < min(SFX_MAX, array_length(_p.sfx)); i++)
    {
        var _s = _p.sfx[i];
        if (_s.kind != 2) { continue; }
        var _bytes = patch_encode(patch_frames(_s.patch));
        array_push(L, "spat_" + string(i) + ":");
        var _row = "";
        for (var k = 0; k < array_length(_bytes); k++)
        {
            if (_row != "") { _row += ","; }
            _row += string(_bytes[k]);
            if ((k + 1) mod 32 == 0)
            {
                array_push(L, " .byte " + _row);
                _row = "";
            }
        }
        if (_row != "") { array_push(L, " .byte " + _row); }
    }
    array_push(L, "pat_end:");
}

// ---------------------------------------------------------------------------
// The Sound page for a patch sound
// ---------------------------------------------------------------------------

function patch_fmt(_d, _v)
{
    switch (_d[6])
    {
        case 1: return string(_v) + "%";
        case 2:
            if (_v > 0) { return "+" + string(_v); }
            return string(_v);
        case 3:
            if (_v > 0) { return "+" + string(_v) + " ct"; }
            return string(_v) + " ct";
        case 16:
            if (_v == 0) { return "off"; }
            var _dms = patch_env_ms(_v) - 1;
            if (_dms >= 1000) { return string_format(_dms / 1000, 1, 1) + " s"; }
            return string(round(_dms)) + " ms";
        case 4:
            var _ms = patch_env_ms(_v);
            if (_ms >= 1000) { return string_format(_ms / 1000, 1, 1) + " s"; }
            return string(round(_ms)) + " ms";
        case 5:
            var _hz = patch_lfo_hz(_v);
            if (_hz < 1) { return string_format(_hz, 1, 2) + " Hz"; }
            return string_format(_hz, 1, 1) + " Hz";
        case 6: return string_format(_v / 100, 1, 2) + " s";
        case 7:
            if (_v > 0) { return "+" + string(_v); }
            return string(_v);
        case 9: return patch_key_name(_v);
        case 13: return string(_v) + "  " + snd_ms_text(global.SID_ATK_MS[clamp(_v, 0, 15)]);
        case 14: return string(_v) + "  " + snd_ms_text(global.SID_DR_MS[clamp(_v, 0, 15)]);
        case 15: return string(_v) + "  " + string(round(_v / 15 * 100)) + "%";
    }
    return string(_v);
}

/// One setting row in the editor; returns its height
function patch_row(_p, _name, _px, _py, _w)
{
    var _d = global.PATCH_IDX[$ _name];
    var _id = "snd_patch_" + _name;
    var _lw = 96;
    if (_d[3] == 2)
    {
        var _on = ui_toggle(_id, _px, _py + 2, _d[4], (_p[$ _name] != 0), _d[5]);
        var _nv = 0;
        if (_on) { _nv = 1; }
        set_val(_p, _name, _nv, "sndp" + _name);
        return 32;
    }
    ui_text(_px, _py + 14, _d[4], global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
    if (_d[3] == 1)
    {
        var _ni = ui_dropdown(_id, _px + _lw, _py, _w - _lw, 28, _d[6], clamp(_p[$ _name], 0, array_length(_d[6]) - 1), _d[5]);
        set_val(_p, _name, _ni, "sndp" + _name);
        return 34;
    }
    var _sv = ui_slider(_id, _px + _lw, _py + 1, _w - _lw - 76, _p[$ _name], _d[1], _d[2], _d[5]);
    set_val(_p, _name, _sv, "sndp" + _name);
    ui_text(_px + _w, _py + 14, patch_fmt(_d, _p[$ _name]), global.TH.text, fa_right, fa_middle, global.f_bold, 1);
    return 32;
}

/// Two list settings side by side (modulation source and target); returns its height
function patch_row_pair(_p, _name_a, _name_b, _px, _py, _w)
{
    var _da = global.PATCH_IDX[$ _name_a];
    var _db = global.PATCH_IDX[$ _name_b];
    var _half = floor((_w - 8) / 2);
    var _na = ui_dropdown("snd_patch_" + _name_a, _px, _py, _half, 28, _da[6], clamp(_p[$ _name_a], 0, array_length(_da[6]) - 1), _da[5]);
    set_val(_p, _name_a, _na, "sndp" + _name_a);
    var _nb = ui_dropdown("snd_patch_" + _name_b, _px + _half + 8, _py, _half, 28, _db[6], clamp(_p[$ _name_b], 0, array_length(_db[6]) - 1), _db[5]);
    set_val(_p, _name_b, _nb, "sndp" + _name_b);
    return 34;
}

/// Columns 1 and 2 of the Sound page for a patch: settings in tabs, then what the SID is told
function sound_patch_panel(_s, _ax, _bx, _colw, _y1, _y2)
{
    var _p = _s.patch;
    var _y = _y1 + 56;
    var _nw = floor(_colw * 0.55);
    ui_heading(_ax, _y, "Name");
    set_val(_s, "name", ui_textfield("snd_name", _ax, _y + 18, _nw, 32, _s.name, 16, "Sound name|Shown on the Logic page when you pick a sound to play."), "sndname");
    ui_heading(_ax + _nw + 8, _y, "Folder");
    var _fnames = ["(none)"];
    for (var g = 0; g < array_length(proj.sound_groups); g++) { array_push(_fnames, proj.sound_groups[g].name); }
    var _fg = ui_dropdown("snd_folder", _ax + _nw + 8, _y + 18, _colw - _nw - 8, 32, _fnames, clamp(_s.group + 1, 0, array_length(_fnames) - 1), "Folder|Which folder this sound is in.");
    set_val(_s, "group", _fg - 1, "sndfolder");
    _y += 60;
    _y += patch_row(_p, "key", _ax, _y, _colw) + 4;

    // ---- tabs ----
    var _tabs = ["Osc", "Filter", "Amp", "Mod"];
    var _tab_help = ["Oscillators|The three oscillators (SID voices) and how voice 2 is synced or ring-modulated by voice 1.",
                     "Filter|The SID filter: type, cutoff, resonance, which oscillators go through it, and its own envelope.",
                     "Amp|The SID envelope, note length, master volume and the pitch envelope.",
                     "Modulation|Two LFOs and three slots that route LFOs and envelopes to settings, worked out once a frame."];
    var _tw = floor((_colw - 3 * 6) / 4);
    for (var t = 0; t < 4; t++)
    {
        if (ui_tab("snd_patch_tab_" + string(t), _ax + t * (_tw + 6), _y, _tw, 30, _tabs[t], snd_patch_tab == t, _tab_help[t])) { snd_patch_tab = t; }
    }
    _y += 40;
    var _sy1 = _y;
    var _sy2 = _y2 - 14;
    var _off = ui_scroll_begin("snd_patch_scroll", _ax - 4, _sy1, _ax + _colw + 14, _sy2, snd_patch_content_h);
    var _ry = _sy1 - _off;
    var _rw = _colw - 8;
    switch (snd_patch_tab)
    {
        case 0:
            var _ow = floor((_rw - 12) / 3);
            var _vo = patch_voices(_p);
            for (var o = 0; o < 3; o++)
            {
                var _lab = "Osc " + string(o + 1);
                if (_vo[o] < 0) { _lab += " (off)"; }
                if (ui_tab("snd_patch_osc_" + string(o), _ax + o * (_ow + 6), _ry, _ow, 28, _lab, snd_patch_osc == o, "Oscillator " + string(o + 1) + "|Show this oscillator's settings.")) { snd_patch_osc = o; }
            }
            _ry += 38;
            var _pre = "o" + string(snd_patch_osc + 1) + "_";
            var _onames = ["wave", "oct", "semi", "fine", "lvl", "pw"];
            for (var k = 0; k < 6; k++) { _ry += patch_row(_p, _pre + _onames[k], _ax, _ry, _rw); }
            _ry += 8;
            ui_heading(_ax, _ry, "Between oscillators (the SID's own)");
            _ry += 20;
            _ry += patch_row(_p, "sync", _ax, _ry, _rw);
            _ry += patch_row(_p, "ring", _ax, _ry, _rw);
            break;
        case 1:
            var _fnames2 = ["flt", "cut", "res", "rt1", "rt2", "rt3", "fenv", "ktrk"];
            for (var k1 = 0; k1 < 8; k1++) { _ry += patch_row(_p, _fnames2[k1], _ax, _ry, _rw); }
            _ry += 8;
            ui_heading(_ax, _ry, "Filter envelope");
            _ry += 20;
            var _fe = ["fa", "fd", "fs", "fr"];
            for (var k2 = 0; k2 < 4; k2++) { _ry += patch_row(_p, _fe[k2], _ax, _ry, _rw); }
            break;
        case 2:
            var _anames = ["gate", "amp_a", "amp_d", "amp_s", "amp_r", "vol"];
            for (var k3 = 0; k3 < 6; k3++) { _ry += patch_row(_p, _anames[k3], _ax, _ry, _rw); }
            _ry += 8;
            ui_heading(_ax, _ry, "Pitch envelope");
            _ry += 20;
            _ry += patch_row(_p, "penv", _ax, _ry, _rw);
            _ry += patch_row(_p, "pdec", _ax, _ry, _rw);
            break;
        case 3:
            for (var l = 1; l <= 2; l++)
            {
                ui_heading(_ax, _ry, "LFO " + string(l));
                _ry += 20;
                _ry += patch_row(_p, "l" + string(l) + "_wave", _ax, _ry, _rw);
                _ry += patch_row(_p, "l" + string(l) + "_rate", _ax, _ry, _rw);
                _ry += patch_row(_p, "l" + string(l) + "_dly", _ax, _ry, _rw);
                _ry += 6;
            }
            for (var m = 1; m <= 3; m++)
            {
                ui_heading(_ax, _ry, "Slot " + string(m) + ": source -> target");
                _ry += 20;
                _ry += patch_row_pair(_p, "m" + string(m) + "_src", "m" + string(m) + "_dst", _ax, _ry, _rw);
                _ry += patch_row(_p, "m" + string(m) + "_amt", _ax, _ry, _rw);
                _ry += 6;
            }
            break;
    }
    snd_patch_content_h = _ry + _off - _sy1 + 8;
    ui_scroll_end("snd_patch_scroll", _ax - 4, _sy1, _ax + _colw + 14, _sy2, snd_patch_content_h);

    // ---- column 2: what the SID is told, frame by frame ----
    var _frames = patch_frames(_p);
    var _nf = array_length(_frames);
    var _gy = _y1 + 74;
    var _gh = 200;
    ui_heading(_bx, _gy - 18, "What the SID is told, frame by frame");
    ui_inset(_bx, _gy, _bx + _colw, _gy + _gh, 10);
    ui_register("snd_graph", _bx, _gy, _bx + _colw, _gy + _gh, "Register picture|Every frame of the patch: each voice's pitch (a line, thick while its gate is on), the filter cutoff (dotted) and the volume (bottom). This is the table the C64 plays; the yellow line is the sound playing.");
    var _vcol = [global.TH.accent, global.TH.accent2, make_colour_rgb(240, 150, 60)];
    var _vo2 = patch_voices(_p);
    var _gx0 = _bx + 10;
    var _gw = _colw - 20;
    var _lo = 99999, _hi = 0;
    for (var f = 0; f < _nf; f++)
    {
        for (var v = 0; v < 3; v++)
        {
            var _fl = _frames[f][v * 7];
            if (_fl < 0) { continue; }
            var _fq = _fl | (_frames[f][v * 7 + 1] << 8);
            if (_fq > 0)
            {
                _lo = min(_lo, ln(_fq));
                _hi = max(_hi, ln(_fq));
            }
        }
    }
    if (_hi < _lo) { _lo = 0; _hi = 1; }
    if (_hi - _lo < 1) { _lo -= 0.5; _hi += 0.5; }
    for (var v2 = 0; v2 < 3; v2++)
    {
        var _px = -1, _py = 0;
        for (var f2 = 0; f2 < _nf; f2++)
        {
            var _b = v2 * 7;
            if (_frames[f2][_b] < 0) { continue; }
            var _fq2 = max(1, _frames[f2][_b] | (_frames[f2][_b + 1] << 8));
            var _x = _gx0 + f2 / max(1, _nf - 1) * _gw;
            var _y3 = _gy + 12 + (1 - (ln(_fq2) - _lo) / (_hi - _lo)) * (_gh - 60);
            var _th = 1;
            if ((_frames[f2][_b + 4] & 1) != 0) { _th = 3; }
            if (_px >= 0) { draw_line_width_colour(_px, _py, _x, _y3, _th, _vcol[v2], _vcol[v2]); }
            _px = _x;
            _py = _y3;
        }
    }
    // cutoff (dotted) and volume (bars at the bottom)
    if (_p.flt > 0)
    {
        for (var f3 = 0; f3 < _nf; f3 += 2)
        {
            var _c11 = _frames[f3][21] | (_frames[f3][22] << 3);
            var _cx = _gx0 + f3 / max(1, _nf - 1) * _gw;
            var _cy = _gy + 12 + (1 - _c11 / 2047) * (_gh - 60);
            draw_rectangle_colour(_cx, _cy, _cx + 1, _cy + 1, global.TH.text_dim, global.TH.text_dim, global.TH.text_dim, global.TH.text_dim, false);
        }
    }
    for (var f4 = 0; f4 < _nf; f4++)
    {
        var _vx = _gx0 + f4 / max(1, _nf) * _gw;
        var _vh = (_frames[f4][24] & 15) / 15 * 24;
        draw_set_alpha(0.35);
        draw_rectangle_colour(_vx, _gy + _gh - 8 - _vh, _vx + max(1, _gw / max(1, _nf)) - 1, _gy + _gh - 8, global.TH.text_faint, global.TH.text_faint, global.TH.text_faint, global.TH.text_faint, false);
        draw_set_alpha(1);
    }
    var _prog = sfx_preview_progress(_s);
    if (_prog >= 0)
    {
        var _mx = _gx0 + _prog * _gw;
        draw_line_width_colour(_mx, _gy + 8, _mx, _gy + _gh - 8, 2, global.TH.warn, global.TH.warn);
    }
    var _iy = _gy + _gh + 10;
    var _vnames = "";
    var _mask = patch_voice_mask(_p);
    for (var vv = 0; vv < 3; vv++)
    {
        if ((_mask & (1 << vv)) != 0)
        {
            if (_vnames != "") { _vnames += ", "; }
            _vnames += string(vv + 1);
        }
    }
    if (_vnames == "") { _vnames = "none"; }
    ui_text(_bx, _iy, "Plays on SID voice(s) " + _vnames, global.TH.text_dim, fa_left, fa_top, global.f_small, 1);
    _iy += 20;
    var _info = string(patch_bytes(_p)) + " bytes  -  " + string(_nf) + " frames, " + string_format(_nf / sid_fps(), 1, 2) + " s";
    ui_text(_bx, _iy, ui_text_fit(_info, global.f_small, _colw), global.TH.text_dim, fa_left, fa_top, global.f_small, 1);
    _iy += 22;
    var _note = "While it plays it has these voices to itself: a sound effect on one of them stops it, and the music waits.";
    if ((_mask & 4) != 0) { _note = "It borrows voice 3 from the music while it plays (osc 1 and 2 are both in use). A sound effect on voice 1 or 2 stops it."; }
    ui_text_wrap(_bx, _iy, _note, global.TH.text_faint, _colw, global.f_small, 1);
    _iy += 62;
    ui_heading(_bx, _iy, "Start from a preset");
    _iy += 20;
    var _pi = ui_dropdown("snd_patch_preset", _bx, _iy, _colw, 32, global.PATCH_PRESET_MENU, 0, "Preset|Replaces this patch with a ready-made one and plays it: basses, leads, pads, organ, drums and effects. Undo brings your patch back.");
    if (_pi > 0)
    {
        undo_mark("sndppreset" + string(current_time));
        patch_apply_preset(_p, _pi - 1);
        sfx_preview_play(_s);
        toast("Preset: " + global.PATCH_PRESET_NAMES[_pi - 1], 0);
    }
    _iy += 40;
    var _hw = floor((_colw - 8) / 2);
    if (ui_button("snd_patch_random", _bx, _iy, _hw, 32, "Randomise", "Randomise|Rolls a completely new patch (keeping its note and volume) and plays it. Undo brings the last one back.", BTN_NORMAL))
    {
        undo_mark("sndprandom" + string(current_time));
        patch_randomise(_p, 1);
        sfx_preview_play(_s);
    }
    if (ui_button("snd_patch_mutate", _bx + _hw + 8, _iy, _hw, 32, "Mutate", "Mutate|Nudges about a third of the settings a little and plays the result - press again for more happy accidents.", BTN_NORMAL))
    {
        undo_mark("sndpmutate" + string(current_time));
        patch_randomise(_p, 0.15);
        sfx_preview_play(_s);
    }
}
