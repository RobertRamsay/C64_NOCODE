/// C64 NO-CODE STUDIO - music: loop library, SID instruments, songs, the song compiler,
/// the 6502 music driver and the preview player (it runs the driver's logic frame by frame).
///
/// Arrangement (song.arr), as ADAM's Music page but for the SID's 3 voices:
///   arr = { bars, lanes, loops }
///   bars  : song length in bars (1..MUS_BAR_MAX)
///   lanes : 3 arrays (one per SID voice) of MUS_BAR_MAX entries: an index into
///           arr.loops, or -1 for an empty bar
///   loops : the song's 1-bar loops = { name, cat, lib, inst, notes, lengths, insts, arps, fx, fxp, fx_end, glide_to }
///           cat   : 0 drums, 1 bass, 2 chords, 3 lead, 4 fx
///           lib   : the library loop it was copied from, -1 = edited (Mine)
///           notes : 32 steps, 0 = none, 1..60 = C-1..B-5
///           lengths: steps the note is held (0 = 2)
///           insts : instrument per step (0.. built-in, 100+k = Sound page sound k)
///           arps  : chord per step, $xy = semitones of the 2nd and 3rd note (played as a
///                   per-frame arpeggio, the C64 way to play a chord on one voice)
///           fx    : the effect row (ADAM's tracker effects, for the SID): 0 none, 1 slide up,
///                   2 slide down, 3 vibrato, 4 glide (older loops), 5 volume (the voice's sustain
///                   level); fxp = its amount (vibrato: speed - 1 in bits 6-7, depth in bits 0-5)
///           fx_end: the last step the effect lasts (-1 = only its own step)
///           glide_to: a linked bend from this note to a later one (-1 = none): the pitch slides
///                   so it arrives on time, and the later note carries on without a new attack
///
/// Compiled events (MUS_EV_SIZE bytes): step, note, instrument (+128 = carry on without a new
/// attack, 255 = only an effect), length, chord, effect, amount, effect length in steps
/// (a bend - effect 6 - has its target note in the chord byte and its 16-bit rate in the last two).
///
/// Timing: the driver runs once a frame. A step lasts song.speed frames (125 BPM at speed 3
/// on PAL, 8 steps a beat); swing makes the first 16th of each pair longer and the second shorter.
/// Sound effects borrow voice 1 or 2 while they play; the music carries on underneath.

#macro MUS_SONG_MAX 4
#macro MUS_LANES 3
#macro MUS_STEPS 32
#macro MUS_BAR_MAX 128
#macro MUS_LOOP_MAX 64
#macro MUS_RATE 22050
#macro MUS_INST_USER 100
#macro MUS_ROOT 18
#macro MUS_NOTE_MAX 60
#macro MUS_SOUND_MAX 94
#macro MUS_LEVELS 8
#macro MUS_EV_SIZE 8
#macro MUS_ZP 253                 // $FD/$FE: the driver's pointer (free in both kinds of game)

/// A built-in SID instrument. _fix > 0: a drum that always plays that pitch (frequency high byte).
/// _w1: the waveform of the first frame (0 = the same as _w) - the classic C64 drum trick.
function mus_inst_def(_name, _w, _w1, _ad, _sr, _pw, _pws, _sweep, _fix, _tr)
{
    return { name : _name, w : _w, w1 : _w1, ad : _ad, sr : _sr, pw : _pw, pws : _pws, sweep : _sweep, fix : _fix, tr : _tr };
}

function music_defs_init()
{
    global.MUS_NOTE_NAMES = ["C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"];
    global.MUS_CAT_NAMES = ["Drums", "Bass", "Chords", "Lead", "FX", "Mine"];
    global.MUS_CAT_COLS = [make_colour_rgb(232, 96, 84), make_colour_rgb(240, 170, 60), make_colour_rgb(110, 196, 110),
                           make_colour_rgb(88, 158, 240), make_colour_rgb(186, 120, 232), make_colour_rgb(200, 206, 214)];
    global.MUS_CHORD_NAMES = ["-", "Minor", "Major", "7th", "Sus 4", "Octave"];
    global.MUS_CHORD_CODES = [0, 0x37, 0x47, 0x4a, 0x57, 0xc0];
    global.MUS_FX_NAMES = ["No effect", "Slide up", "Slide down", "Vibrato", "Glide from last note", "Volume"];
    global.MUS_FX_SHORT = ["--", "Up", "Down", "Vib", "Glide", "Vol"];

    // Built-in SID instruments: waveform, first-frame waveform, $D405 (AD), $D406 (SR),
    // pulse width, pulse sweep, pitch sweep per frame, drum pitch (0 = plays the note), transpose
    global.MUS_INST = [
        mus_inst_def("Kick",        64, 128, 0x08, 0x00, 2048, 0, -2, 16, 0),
        mus_inst_def("Snare",      128,  64, 0x07, 0x00, 1024, 0, -1, 72, 0),
        mus_inst_def("Hi-hat",     128,   0, 0x02, 0x00, 2048, 0, 0, 220, 0),
        mus_inst_def("Open hat",   128,   0, 0x05, 0x05, 2048, 0, 0, 220, 0),
        mus_inst_def("Tom",         16, 128, 0x08, 0x00, 2048, 0, -1, 26, 0),
        mus_inst_def("Clap",       128, 128, 0x04, 0x24, 2048, 0, 0, 110, 0),
        mus_inst_def("Pulse bass",  64,   0, 0x06, 0x64, 1024, 0, 0, 0, 0),
        mus_inst_def("Saw bass",    32,   0, 0x05, 0x54, 2048, 0, 0, 0, 0),
        mus_inst_def("Organ",       64,   0, 0x18, 0xa6, 2048, 0, 0, 0, 12),
        mus_inst_def("Soft pad",    16,   0, 0x69, 0xc8, 2048, 0, 0, 0, 12),
        mus_inst_def("Pulse lead",  64,   0, 0x06, 0x95, 1536, 16, 0, 0, 24),
        mus_inst_def("Saw lead",    32,   0, 0x06, 0x95, 2048, 0, 0, 0, 24),
        mus_inst_def("Pluck",       64,   0, 0x04, 0x04, 800, 0, 0, 0, 24),
        mus_inst_def("Zap",         32,   0, 0x07, 0x00, 2048, 0, -8, 140, 0),
        mus_inst_def("Riser",       64,   0, 0x49, 0xa5, 1024, 24, 4, 20, 0),
        mus_inst_def("Noise sweep",128,   0, 0x8a, 0x88, 2048, 0, 2, 30, 0)
    ];
    global.MUS_DRUM_ROWS = [0, 1, 2, 3, 4, 5, 13, 14, 15];

    // ---------- the built-in loop library (the same loops as ADAM) ----------
    var _z = array_create(16, 0);
    var _min = 0x37;
    var _maj = 0x47;
    global.MUS_LIB = [
        // drums: K kick, S snare, H hi-hat, O open hat, T tom, C clap
        mus_lib_drums("Four on the floor", "K.H.K.H.K.H.K.H."),
        mus_lib_drums("Rock beat",         "K.H.S.H.K.KHS.H."),
        mus_lib_drums("Breakbeat",         "K.H.S..KK.H.S.HC"),
        mus_lib_drums("Half time",         "K...H...S...H..."),
        mus_lib_drums("Disco claps",       "K.H.C.H.K.H.C.HO"),
        mus_lib_drums("Busy hats",         "HHHHHHHHHHHHHHO."),
        mus_lib_drums("Tom fill",          "T.T.TT.TS.S.SSSC"),
        // bass (C minor)
        mus_lib_tone("Root pulse",    1, 6, [13, 0, 0, 0, 13, 0, 0, 0, 13, 0, 0, 0, 13, 0, 0, 0], _z),
        mus_lib_tone("Octave bounce", 1, 7, [13, 0, 25, 0, 13, 0, 25, 0, 13, 0, 25, 0, 13, 0, 25, 0], _z),
        mus_lib_tone("Walking bass",  1, 6, [13, 0, 0, 0, 16, 0, 0, 0, 18, 0, 0, 0, 20, 0, 18, 0], _z),
        mus_lib_tone("Offbeat bass",  1, 6, [0, 0, 13, 0, 0, 0, 13, 0, 0, 0, 13, 0, 0, 0, 13, 0], _z),
        mus_lib_tone("Acid line",     1, 7, [13, 13, 25, 13, 0, 13, 23, 13, 13, 0, 25, 0, 16, 13, 18, 13], _z),
        mus_lib_tone("Driving eighths", 1, 7, [13, 0, 13, 0, 13, 0, 13, 0, 21, 0, 21, 0, 23, 0, 23, 0], _z),
        // chords (arpeggio chords)
        mus_lib_tone("Minor stabs",   2, 8, [13, 0, 0, 13, 0, 0, 13, 0, 0, 0, 13, 0, 0, 0, 0, 0],
                                            [_min, 0, 0, _min, 0, 0, _min, 0, 0, 0, _min, 0, 0, 0, 0, 0]),
        mus_lib_tone("Minor to major", 2, 9, [13, 0, 0, 0, 0, 0, 0, 0, 21, 0, 0, 0, 0, 0, 0, 0],
                                             [_min, 0, 0, 0, 0, 0, 0, 0, _maj, 0, 0, 0, 0, 0, 0, 0]),
        mus_lib_tone("Offbeat skank", 2, 8, [0, 0, 13, 0, 0, 0, 13, 0, 0, 0, 13, 0, 0, 0, 13, 0],
                                            [0, 0, _min, 0, 0, 0, _min, 0, 0, 0, _min, 0, 0, 0, _min, 0]),
        mus_lib_tone("Rising chords", 2, 9, [13, 0, 0, 0, 16, 0, 0, 0, 18, 0, 0, 0, 20, 0, 0, 0],
                                            [_min, 0, 0, 0, _maj, 0, 0, 0, _min, 0, 0, 0, _min, 0, 0, 0]),
        mus_lib_tone("Long minor",    2, 9, [13, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                                            [_min, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        // lead
        mus_lib_tone("Arp up",        3, 12, [13, 16, 20, 25, 13, 16, 20, 25, 13, 16, 20, 25, 13, 16, 20, 25], _z),
        mus_lib_tone("Arp down",      3, 12, [25, 20, 16, 13, 25, 20, 16, 13, 25, 20, 16, 13, 25, 20, 16, 13], _z),
        mus_lib_tone("Hook one",      3, 10, [13, 0, 0, 16, 0, 0, 20, 0, 18, 0, 16, 0, 15, 0, 13, 0], _z),
        mus_lib_tone("Hook two",      3, 11, [25, 0, 23, 0, 20, 0, 0, 0, 18, 0, 20, 0, 23, 0, 0, 0], _z),
        mus_lib_tone("Long notes",    3, 10, [20, 0, 0, 0, 0, 0, 0, 0, 18, 0, 0, 0, 0, 0, 0, 0], _z),
        mus_lib_tone("Trill",         3, 12, [25, 27, 25, 27, 25, 27, 25, 27, 23, 25, 23, 25, 23, 25, 23, 25], _z),
        // fx
        mus_lib_tone("Zap hits",      4, 13, [18, 0, 0, 0, 0, 0, 0, 0, 18, 0, 0, 0, 0, 0, 0, 0], _z),
        mus_lib_tone("Laser rain",    4, 13, [25, 0, 0, 23, 0, 0, 20, 0, 0, 0, 18, 0, 0, 16, 0, 0], _z),
        mus_lib_tone("Riser",         4, 14, [13, 0, 0, 0, 18, 0, 0, 0, 20, 0, 0, 0, 25, 0, 0, 0], _z),
        mus_lib_tone("Noise swell",   4, 15, [18, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], _z),
        mus_lib_tone("Blips",         4, 12, [0, 0, 32, 0, 0, 30, 0, 0, 0, 32, 0, 0, 28, 0, 0, 0], _z)
    ];
    for (var i = 0; i < array_length(global.MUS_LIB); i++) { global.MUS_LIB[i].lib = i; }
    // long notes in the library: the long chords and leads hold for a while
    global.MUS_LIB[17].lengths[0] = 30;
    global.MUS_LIB[22].lengths[0] = 14;
    global.MUS_LIB[22].lengths[16] = 14;
    global.MUS_LIB[27].lengths[0] = 30;
}

function loop_new(_name, _cat, _inst)
{
    return {
        name : _name,
        cat : _cat,
        lib : -1,
        inst : _inst,
        notes : array_create(MUS_STEPS, 0),
        lengths : array_create(MUS_STEPS, 0),
        insts : array_create(MUS_STEPS, _inst),
        arps : array_create(MUS_STEPS, 0),
        fx : array_create(MUS_STEPS, 0),
        fxp : array_create(MUS_STEPS, 0),
        fx_end : array_create(MUS_STEPS, -1),
        glide_to : array_create(MUS_STEPS, -1)
    };
}

/// Drum loop from a 16-letter pattern: K kick, S snare, H hat, O open hat, T tom, C clap, . rest
function mus_lib_drums(_name, _pat)
{
    var _l = loop_new(_name, 0, 0);
    var _keys = "KSHOTC";
    for (var i = 0; i < string_length(_pat); i++)
    {
        var _k = string_pos(string_char_at(_pat, i + 1), _keys);
        if (_k > 0)
        {
            _l.notes[i * 2] = MUS_ROOT;
            _l.insts[i * 2] = _k - 1;
        }
    }
    return _l;
}

function mus_lib_tone(_name, _cat, _inst, _notes, _chords)
{
    var _l = loop_new(_name, _cat, _inst);
    for (var i = 0; i < array_length(_notes); i++)
    {
        _l.notes[i * 2] = _notes[i];
        if (i < array_length(_chords)) { _l.arps[i * 2] = _chords[i]; }
    }
    return _l;
}

function loop_copy(_l)
{
    var _c = loop_new(_l.name, _l.cat, _l.inst);
    _c.lib = _l.lib;
    array_copy(_c.notes, 0, _l.notes, 0, MUS_STEPS);
    array_copy(_c.lengths, 0, _l.lengths, 0, MUS_STEPS);
    array_copy(_c.insts, 0, _l.insts, 0, MUS_STEPS);
    array_copy(_c.arps, 0, _l.arps, 0, MUS_STEPS);
    array_copy(_c.fx, 0, _l.fx, 0, MUS_STEPS);
    array_copy(_c.fxp, 0, _l.fxp, 0, MUS_STEPS);
    array_copy(_c.fx_end, 0, _l.fx_end, 0, MUS_STEPS);
    array_copy(_c.glide_to, 0, _l.glide_to, 0, MUS_STEPS);
    return _c;
}

function music_inst_valid(_id)
{
    if (!is_numeric(_id)) { return false; }
    if (_id >= 0 && _id < array_length(global.MUS_INST)) { return true; }
    if (_id >= MUS_INST_USER && _id < MUS_INST_USER + SFX_MAX) { return true; }
    return false;
}

function music_inst_name(_id)
{
    if (_id >= MUS_INST_USER)
    {
        var _k = _id - MUS_INST_USER;
        if (_k >= 0 && _k < array_length(proj.sfx)) { return "Sound " + string(_k + 1) + ": " + proj.sfx[_k].name; }
        return "Sound";
    }
    if (_id >= 0 && _id < array_length(global.MUS_INST)) { return global.MUS_INST[_id].name; }
    return "?";
}

/// Every instrument id, in the order the menus show them: built-in, then the Sound page's sounds
function music_inst_ids()
{
    var _out = [];
    for (var i = 0; i < array_length(global.MUS_INST); i++) { array_push(_out, i); }
    // samples play through the volume register and patches take whole voices: neither can be a music instrument
    for (var k = 0; k < array_length(proj.sfx); k++)
    {
        if (proj.sfx[k].kind == 0) { array_push(_out, MUS_INST_USER + k); }
    }
    return _out;
}

function music_note_name(_n)
{
    if (_n < 1) { return "---"; }
    return global.MUS_NOTE_NAMES[(_n - 1) mod 12] + string(1 + (_n - 1) div 12);
}

/// The note length in steps (0 = the default 2)
function music_note_length(_lp, _step)
{
    var _length = _lp.lengths[_step];
    if (_length <= 0) { _length = 2; }
    return min(_length, MUS_STEPS - _step);
}

// ---------------------------------------------------------------------------
// Songs
// ---------------------------------------------------------------------------

function arr_new()
{
    var _a = { bars : 8, lanes : [], loops : [] };
    for (var l = 0; l < MUS_LANES; l++) { array_push(_a.lanes, array_create(MUS_BAR_MAX, -1)); }
    return _a;
}

function song_new(_name)
{
    return { name : _name, speed : 3, swing : 0, loop_bar : 0, arr : arr_new() };
}

function loop_from_loaded(_raw)
{
    var _l = loop_new("Loop", 0, 0);
    if (!is_struct(_raw)) { return _l; }
    if (is_string(_raw[$ "name"])) { _l.name = string_copy(_raw.name, 1, 24); }
    if (is_numeric(_raw[$ "cat"])) { _l.cat = clamp(floor(_raw.cat), 0, 4); }
    if (is_numeric(_raw[$ "lib"])) { _l.lib = clamp(floor(_raw.lib), -1, array_length(global.MUS_LIB) - 1); }
    if (music_inst_valid(_raw[$ "inst"])) { _l.inst = floor(_raw.inst); }
    var _keys = ["notes", "lengths", "insts", "arps", "fx", "fxp"];
    var _hi = [MUS_NOTE_MAX, MUS_STEPS, 999, 255, 5, 255];
    for (var k = 0; k < array_length(_keys); k++)
    {
        var _a = _raw[$ _keys[k]];
        if (!is_array(_a)) { continue; }
        var _dst = _l[$ _keys[k]];
        for (var s = 0; s < min(MUS_STEPS, array_length(_a)); s++)
        {
            if (!is_numeric(_a[s])) { continue; }
            if (k == 2)
            {
                if (music_inst_valid(_a[s])) { _dst[s] = floor(_a[s]); }
            }
            else { _dst[s] = clamp(floor(_a[s]), 0, _hi[k]); }
        }
    }
    var _ends = _raw[$ "fx_end"];
    var _links = _raw[$ "glide_to"];
    for (var s2 = 0; s2 < MUS_STEPS; s2++)
    {
        if (_l.fx[s2] == 5) { _l.fxp[s2] = min(_l.fxp[s2], 15); }
        if (is_array(_ends))
        {
            if (s2 < array_length(_ends) && is_numeric(_ends[s2]) && _ends[s2] >= s2 && _ends[s2] < MUS_STEPS) { _l.fx_end[s2] = floor(_ends[s2]); }
        }
        else if (_l.fx[s2] > 0)
        {
            // older loops: an effect lasted until the next note, and vibrato had one amount
            if (_l.fx[s2] == 3) { _l.fxp[s2] = clamp(_l.fxp[s2], 1, 63); }
            var _e = MUS_STEPS - 1;
            for (var t = s2 + 1; t < MUS_STEPS; t++)
            {
                if (_l.notes[t] > 0)
                {
                    _e = t - 1;
                    break;
                }
            }
            _l.fx_end[s2] = _e;
        }
        if (is_array(_links) && s2 < array_length(_links) && is_numeric(_links[s2]) && _links[s2] > s2 && _links[s2] < MUS_STEPS) { _l.glide_to[s2] = floor(_links[s2]); }
    }
    return _l;
}

// ---------------------------------------------------------------------------
// Effects and linked bends (ADAM's step editor)
// ---------------------------------------------------------------------------

/// The step whose effect is playing at step _step (an effect lasts from its step to fx_end), or -1
function music_fx_active_step(_lp, _step)
{
    var _active = -1;
    for (var _source = 0; _source <= _step; _source++)
    {
        if (_lp.fx[_source] > 0 && (_source == _step || _lp.fx_end[_source] >= _step)) { _active = _source; }
    }
    return _active;
}

/// The last step effect _src lasts
function music_fx_last(_lp, _src)
{
    return max(_src, _lp.fx_end[_src]);
}

/// Click on the effect row: the next effect (an older glide moves on to volume)
function music_fx_next_kind(_kind)
{
    if (_kind == 0) { return 1; }
    if (_kind == 1) { return 2; }
    if (_kind == 2) { return 3; }
    if (_kind == 3 || _kind == 4) { return 5; }
    return 0;
}

/// A new effect's amount: slides 8, vibrato speed 1 depth 8, volume full
function music_fx_default(_kind)
{
    if (_kind == 3) { return 8; }
    if (_kind == 5) { return 15; }
    if (_kind == 0) { return 0; }
    return 8;
}

function music_glide_valid(_lp, _source)
{
    var _target = _lp.glide_to[_source];
    if (_target <= _source || _target >= MUS_STEPS || _lp.notes[_source] <= 0) { return false; }
    return (_lp.notes[_target] > 0);
}

/// One SID voice bends one way at a time: links that would cross this one are taken away
function music_glide_connect(_lp, _source, _target)
{
    for (var _other = 0; _other < MUS_STEPS; _other++)
    {
        if (music_glide_valid(_lp, _other) && _other < _target && _lp.glide_to[_other] > _source)
        {
            _lp.glide_to[_other] = -1;
        }
    }
    _lp.glide_to[_source] = _target;
}

function music_glide_unlink(_lp, _step)
{
    _lp.glide_to[_step] = -1;
    for (var _source = 0; _source < MUS_STEPS; _source++)
    {
        if (_lp.glide_to[_source] == _step) { _lp.glide_to[_source] = -1; }
    }
}

/// Clears step _st of loop _lp (its note, chord, effect and links)
function music_step_clear(_lp, _st)
{
    music_glide_unlink(_lp, _st);
    _lp.notes[_st] = 0;
    _lp.lengths[_st] = 0;
    _lp.insts[_st] = _lp.inst;
    _lp.arps[_st] = 0;
    _lp.fx[_st] = 0;
    _lp.fxp[_st] = 0;
    _lp.fx_end[_st] = -1;
}

/// A linked note can't be moved past the note it links to (or from)
function music_note_can_move(_lp, _from, _to)
{
    if (_from == _to) { return true; }
    if (_lp.glide_to[_from] >= 0 && _to >= _lp.glide_to[_from]) { return false; }
    for (var _source = 0; _source < MUS_STEPS; _source++)
    {
        if (_lp.glide_to[_source] == _from && _to <= _source) { return false; }
    }
    return true;
}

function music_note_move(_lp, _from, _to, _pitch)
{
    if (!music_note_can_move(_lp, _from, _to)) { return false; }
    if (_from != _to)
    {
        music_glide_unlink(_lp, _to);
        _lp.notes[_to] = _lp.notes[_from];
        _lp.lengths[_to] = min(_lp.lengths[_from], MUS_STEPS - _to);
        _lp.insts[_to] = _lp.insts[_from];
        _lp.fx[_to] = _lp.fx[_from];
        _lp.fxp[_to] = _lp.fxp[_from];
        _lp.arps[_to] = _lp.arps[_from];
        _lp.glide_to[_to] = _lp.glide_to[_from];
        _lp.fx_end[_to] = -1;
        if (_lp.fx_end[_from] >= _from) { _lp.fx_end[_to] = clamp(_lp.fx_end[_from] + _to - _from, _to, MUS_STEPS - 1); }
        _lp.notes[_from] = 0;
        _lp.lengths[_from] = 0;
        _lp.insts[_from] = _lp.inst;
        _lp.fx[_from] = 0;
        _lp.fxp[_from] = 0;
        _lp.arps[_from] = 0;
        _lp.glide_to[_from] = -1;
        _lp.fx_end[_from] = -1;
        for (var _source = 0; _source < MUS_STEPS; _source++)
        {
            if (_lp.glide_to[_source] == _from) { _lp.glide_to[_source] = _to; }
        }
    }
    _lp.notes[_to] = _pitch;
    return true;
}

function music_note_duplicate(_lp, _from, _to, _pitch)
{
    if (_from == _to) { return false; }
    music_glide_unlink(_lp, _to);
    _lp.notes[_to] = _pitch;
    _lp.lengths[_to] = min(_lp.lengths[_from], MUS_STEPS - _to);
    _lp.insts[_to] = _lp.insts[_from];
    _lp.fx[_to] = _lp.fx[_from];
    _lp.fxp[_to] = _lp.fxp[_from];
    _lp.arps[_to] = _lp.arps[_from];
    _lp.fx_end[_to] = -1;
    if (_lp.fx_end[_from] >= _from) { _lp.fx_end[_to] = clamp(_lp.fx_end[_from] + _to - _from, _to, MUS_STEPS - 1); }
    _lp.glide_to[_to] = -1;
    if (_lp.glide_to[_from] > _to) { _lp.glide_to[_to] = _lp.glide_to[_from]; }
    return true;
}

/// The drum grid's rows: the built-in drums and effects, then every synth sound on the Sound page
function music_drum_rows_refresh()
{
    var _rows = [0, 1, 2, 3, 4, 5, 13, 14, 15];
    for (var k = 0; k < min(SFX_MAX, array_length(proj.sfx)); k++)
    {
        if (proj.sfx[k].kind == 0) { array_push(_rows, MUS_INST_USER + k); }
    }
    global.MUS_DRUM_ROWS = _rows;
}

/// The grid row of step _step's note (piano roll: MUS_NOTE_MAX at the top), or -1
function music_note_row(_lp, _step, _drums)
{
    if (!_drums) { return MUS_NOTE_MAX - _lp.notes[_step]; }
    for (var _row = 0; _row < array_length(global.MUS_DRUM_ROWS); _row++)
    {
        if (global.MUS_DRUM_ROWS[_row] == _lp.insts[_step]) { return _row; }
    }
    return -1;
}

/// The notes a selection box (grid pixels) touches
function music_notes_in_box(_lp, _drums, _cw, _rh, _box)
{
    var _selected = array_create(MUS_STEPS, false);
    var _left = min(_box[0], _box[2]);
    var _right = max(_box[0], _box[2]);
    var _top = min(_box[1], _box[3]);
    var _bottom = max(_box[1], _box[3]);
    for (var _step = 0; _step < MUS_STEPS; _step++)
    {
        if (_lp.notes[_step] <= 0) { continue; }
        var _row = music_note_row(_lp, _step, _drums);
        if (_row < 0) { continue; }
        var _px = _step * _cw;
        var _py = _row * _rh;
        _selected[_step] = (_left <= _px + music_note_length(_lp, _step) * _cw - 2 && _right >= _px + 2 && _top <= _py + _rh - 2 && _bottom >= _py + 2);
    }
    return _selected;
}

function music_notes_copy(_lp, _selected, _drums)
{
    var _clip = { notes : [], drums : _drums };
    var _first = MUS_STEPS;
    var _top = 1000;
    for (var _step = 0; _step < MUS_STEPS; _step++)
    {
        if (!_selected[_step] || _lp.notes[_step] <= 0) { continue; }
        var _row = music_note_row(_lp, _step, _drums);
        if (_row < 0) { continue; }
        _first = min(_first, _step);
        _top = min(_top, _row);
    }
    if (_first == MUS_STEPS) { return _clip; }
    for (var _step2 = 0; _step2 < MUS_STEPS; _step2++)
    {
        if (!_selected[_step2] || _lp.notes[_step2] <= 0) { continue; }
        var _row2 = music_note_row(_lp, _step2, _drums);
        if (_row2 < 0) { continue; }
        var _link = -1;
        if (music_glide_valid(_lp, _step2) && _selected[_lp.glide_to[_step2]]) { _link = _lp.glide_to[_step2] - _first; }
        var _end = -1;
        if (_lp.fx_end[_step2] >= _step2) { _end = _lp.fx_end[_step2] - _first; }
        array_push(_clip.notes, {
            step : _step2 - _first, row : _row2 - _top, pitch : _lp.notes[_step2], length : _lp.lengths[_step2],
            inst : _lp.insts[_step2], arp : _lp.arps[_step2], fx : _lp.fx[_step2],
            fxp : _lp.fxp[_step2], fx_end : _end, glide_to : _link
        });
    }
    return _clip;
}

/// Pastes clipboard _clip with its first note at step _step, row _row. A dry run (_apply false)
/// says how many notes fit, so the page makes an undo point only when something changes.
function music_notes_paste(_lp, _clip, _step, _row, _drums, _apply = true)
{
    var _result = { count : 0, selected : array_create(MUS_STEPS, false) };
    if (_clip.drums != _drums) { return _result; }
    var _max_row = MUS_NOTE_MAX;
    if (_drums) { _max_row = array_length(global.MUS_DRUM_ROWS); }
    for (var _i = 0; _i < array_length(_clip.notes); _i++)
    {
        var _note = _clip.notes[_i];
        var _to = _step + _note.step;
        var _to_row = _row + _note.row;
        if (_to < 0 || _to >= MUS_STEPS || _to_row < 0 || _to_row >= _max_row) { continue; }
        _result.selected[_to] = true;
        _result.count += 1;
        if (_apply) { music_glide_unlink(_lp, _to); }
    }
    if (!_apply) { return _result; }
    for (var _i2 = 0; _i2 < array_length(_clip.notes); _i2++)
    {
        var _note2 = _clip.notes[_i2];
        var _to2 = _step + _note2.step;
        if (_to2 < 0 || _to2 >= MUS_STEPS || !_result.selected[_to2]) { continue; }
        var _pitch = MUS_NOTE_MAX - (_row + _note2.row);
        var _inst = _note2.inst;
        if (_drums)
        {
            _pitch = _note2.pitch;
            _inst = global.MUS_DRUM_ROWS[_row + _note2.row];
        }
        _lp.notes[_to2] = _pitch;
        _lp.lengths[_to2] = min(_note2.length, MUS_STEPS - _to2);
        _lp.insts[_to2] = _inst;
        _lp.arps[_to2] = _note2.arp;
        _lp.fx[_to2] = _note2.fx;
        _lp.fxp[_to2] = _note2.fxp;
        _lp.fx_end[_to2] = -1;
        if (_note2.fx_end >= _note2.step) { _lp.fx_end[_to2] = min(MUS_STEPS - 1, _step + _note2.fx_end); }
    }
    for (var _i3 = 0; _i3 < array_length(_clip.notes); _i3++)
    {
        var _note3 = _clip.notes[_i3];
        var _from = _step + _note3.step;
        var _tgt = _step + _note3.glide_to;
        if (_note3.glide_to < 0 || _from < 0 || _from >= MUS_STEPS || _tgt < 0 || _tgt >= MUS_STEPS) { continue; }
        if (_result.selected[_from] && _result.selected[_tgt]) { _lp.glide_to[_from] = _tgt; }
    }
    return _result;
}

/// Moves the selected notes by _steps and _rows together (undefined when one would fall off)
function music_notes_move(_lp, _selected, _steps, _rows, _drums, _apply = true)
{
    var _result = array_create(MUS_STEPS, false);
    var _max_row = MUS_NOTE_MAX;
    if (_drums) { _max_row = array_length(global.MUS_DRUM_ROWS); }
    for (var _step = 0; _step < MUS_STEPS; _step++)
    {
        if (!_selected[_step] || _lp.notes[_step] <= 0) { continue; }
        var _to = _step + _steps;
        var _row = music_note_row(_lp, _step, _drums) + _rows;
        if (_to < 0 || _to >= MUS_STEPS || _row < 0 || _row >= _max_row) { return undefined; }
        _result[_to] = true;
    }
    if (!_apply) { return _result; }
    var _before = loop_copy(_lp);
    for (var _s1 = 0; _s1 < MUS_STEPS; _s1++)
    {
        if (!_selected[_s1] && !_result[_s1]) { continue; }
        _lp.notes[_s1] = 0;
        _lp.insts[_s1] = _lp.inst;
        _lp.fx[_s1] = 0;
        _lp.fxp[_s1] = 0;
        _lp.arps[_s1] = 0;
        _lp.fx_end[_s1] = -1;
        _lp.glide_to[_s1] = -1;
    }
    for (var _s2 = 0; _s2 < MUS_STEPS; _s2++)
    {
        if (!_selected[_s2] || _before.notes[_s2] <= 0) { continue; }
        var _to2 = _s2 + _steps;
        _lp.notes[_to2] = _before.notes[_s2] - _rows;
        _lp.lengths[_to2] = min(_before.lengths[_s2], MUS_STEPS - _to2);
        _lp.insts[_to2] = _before.insts[_s2];
        if (_drums)
        {
            _lp.notes[_to2] = _before.notes[_s2];
            _lp.insts[_to2] = global.MUS_DRUM_ROWS[music_note_row(_before, _s2, true) + _rows];
        }
        _lp.fx[_to2] = _before.fx[_s2];
        _lp.fxp[_to2] = _before.fxp[_s2];
        _lp.arps[_to2] = _before.arps[_s2];
        if (_before.fx_end[_s2] >= _s2) { _lp.fx_end[_to2] = clamp(_before.fx_end[_s2] + _steps, _to2, MUS_STEPS - 1); }
    }
    _lp.glide_to = array_create(MUS_STEPS, -1);
    for (var _s3 = 0; _s3 < MUS_STEPS; _s3++)
    {
        var _target = _before.glide_to[_s3];
        if (_target < 0) { continue; }
        if ((!_selected[_s3] && _result[_s3]) || (!_selected[_target] && _result[_target])) { continue; }
        var _from = _s3;
        if (_selected[_s3]) { _from += _steps; }
        if (_selected[_target]) { _target += _steps; }
        if (_target > _from && _lp.notes[_from] > 0 && _lp.notes[_target] > 0) { _lp.glide_to[_from] = _target; }
    }
    return _result;
}

/// Frames step _k of a bar lasts (the driver's step timing, with swing)
function music_step_frames(_k, _speed, _swing)
{
    var _q = _k & 3;
    if (_q == 0) { return _speed + _swing; }
    if (_q == 2) { return _speed - _swing; }
    return _speed;
}

function song_from_loaded(_raw)
{
    var _s = song_new("Song");
    if (!is_struct(_raw)) { return _s; }
    if (is_string(_raw[$ "name"])) { _s.name = string_copy(_raw.name, 1, 20); }
    if (is_numeric(_raw[$ "speed"])) { _s.speed = clamp(floor(_raw.speed), 2, 12); }
    if (is_numeric(_raw[$ "swing"])) { _s.swing = clamp(floor(_raw.swing), 0, _s.speed - 1); }
    var _ra = _raw[$ "arr"];
    if (is_struct(_ra))
    {
        var _lr = _ra[$ "loops"];
        if (is_array(_lr))
        {
            for (var i = 0; i < min(MUS_LOOP_MAX, array_length(_lr)); i++) { array_push(_s.arr.loops, loop_from_loaded(_lr[i])); }
        }
        if (is_numeric(_ra[$ "bars"])) { _s.arr.bars = clamp(floor(_ra.bars), 1, MUS_BAR_MAX); }
        var _ln = _ra[$ "lanes"];
        if (is_array(_ln))
        {
            for (var l = 0; l < min(MUS_LANES, array_length(_ln)); l++)
            {
                if (!is_array(_ln[l])) { continue; }
                for (var b = 0; b < min(MUS_BAR_MAX, array_length(_ln[l])); b++)
                {
                    var _v = _ln[l][b];
                    if (is_numeric(_v) && _v >= 0 && _v < array_length(_s.arr.loops)) { _s.arr.lanes[l][b] = floor(_v); }
                }
            }
        }
    }
    if (is_numeric(_raw[$ "loop_bar"])) { _s.loop_bar = clamp(floor(_raw.loop_bar), 0, _s.arr.bars - 1); }
    return _s;
}

/// The project's songs and the song for each level, from a loaded file
function music_from_loaded(_p, _raw)
{
    var _songs = [];
    var _rs = _raw[$ "songs"];
    if (is_array(_rs))
    {
        for (var i = 0; i < min(MUS_SONG_MAX, array_length(_rs)); i++) { array_push(_songs, song_from_loaded(_rs[i])); }
    }
    _p.songs = _songs;
    var _ls = array_create(MUS_LEVELS, -1);
    var _rl = _raw[$ "level_song"];
    if (is_array(_rl))
    {
        for (var l = 0; l < min(MUS_LEVELS, array_length(_rl)); l++)
        {
            if (is_numeric(_rl[l]) && _rl[l] >= 0 && _rl[l] < array_length(_songs)) { _ls[l] = floor(_rl[l]); }
        }
    }
    _p.level_song = _ls;
}

/// How many bars use loop _li
function music_loop_uses(_song, _li)
{
    var _n = 0;
    for (var l = 0; l < MUS_LANES; l++)
    {
        for (var b = 0; b < MUS_BAR_MAX; b++)
        {
            if (_song.arr.lanes[l][b] == _li) { _n += 1; }
        }
    }
    return _n;
}

/// Removes loop _li from a song (its bars must already be empty); later loops move down
function music_loop_remove(_song, _li)
{
    array_delete(_song.arr.loops, _li, 1);
    for (var l = 0; l < MUS_LANES; l++)
    {
        for (var b = 0; b < MUS_BAR_MAX; b++)
        {
            if (_song.arr.lanes[l][b] > _li) { _song.arr.lanes[l][b] -= 1; }
        }
    }
}

/// Deletes song _i; levels and rules that played it are fixed up
function music_song_delete(_i)
{
    array_delete(proj.songs, _i, 1);
    for (var l = 0; l < MUS_LEVELS; l++)
    {
        if (proj.level_song[l] == _i) { proj.level_song[l] = -1; }
        else
        {
            if (proj.level_song[l] > _i) { proj.level_song[l] -= 1; }
        }
    }
    for (var r = 0; r < array_length(proj.rules); r++)
    {
        var _ru = proj.rules[r];
        if (_ru.act == 17 && _ru.value >= _i) { _ru.value = max(0, _ru.value - 1); }
        for (var m = 0; m < array_length(_ru.more); m++)
        {
            if (_ru.more[m].act == 17 && _ru.more[m].value >= _i) { _ru.more[m].value = max(0, _ru.more[m].value - 1); }
        }
    }
}

function music_song_names()
{
    var _n = [];
    for (var i = 0; i < array_length(proj.songs); i++) { array_push(_n, string(i + 1) + ": " + proj.songs[i].name); }
    return _n;
}

/// "(no music)" then every song (level pickers)
function music_song_options()
{
    var _n = ["(no music)"];
    for (var i = 0; i < array_length(proj.songs); i++) { array_push(_n, string(i + 1) + ": " + proj.songs[i].name); }
    return _n;
}

/// Sound page sound _k is gone: loops that played it fall back to a built-in instrument
function music_sound_deleted(_k)
{
    for (var s = 0; s < array_length(proj.songs); s++)
    {
        var _loops = proj.songs[s].arr.loops;
        for (var i = 0; i < array_length(_loops); i++)
        {
            var _lp = _loops[i];
            var _fix = function(_id, _k)
            {
                if (_id == MUS_INST_USER + _k) { return 10; }
                if (_id > MUS_INST_USER + _k) { return _id - 1; }
                return _id;
            };
            _lp.inst = _fix(_lp.inst, _k);
            for (var st = 0; st < MUS_STEPS; st++) { _lp.insts[st] = _fix(_lp.insts[st], _k); }
        }
    }
}

// ---------------------------------------------------------------------------
// The compiled form: what the driver plays (and the preview runs)
// ---------------------------------------------------------------------------

/// SID frequency register for note _n (1 = C-1) on the target machine
function music_note_freq(_n)
{
    if (_n < 1) { return 0; }
    var _hz = 32.7032 * power(2, (_n - 1) / 12);
    return clamp(round(_hz * 16777216 / sid_clock()), 0, 65535);
}

/// The driver's form of instrument id _id (built-in or a Sound page sound); _drum = in a drum loop
function music_inst_compiled(_id, _drum)
{
    if (_id >= MUS_INST_USER)
    {
        var _k = clamp(_id - MUS_INST_USER, 0, array_length(proj.sfx) - 1);
        var _s = proj.sfx[_k];
        if (_s.kind != 0)
        {
            // a sound that became a sample or a patch: the nearest built-in instrument plays instead
            if (_drum) { return music_inst_compiled(1, true); }
            return music_inst_compiled(10, false);
        }
        var _fx = 0;
        if (_drum) { _fx = clamp(_s.pitch, 1, 255); }
        return {
            w : global.WAVE_BITS[clamp(_s.wave, 0, array_length(global.WAVE_BITS) - 1)], w1 : 0,
            ad : (clamp(_s.atk, 0, 15) << 4) | clamp(_s.dec, 0, 15), sr : (clamp(_s.sus, 0, 15) << 4) | clamp(_s.rel, 0, 15),
            pw : clamp(_s.pw, 0, 4095), pws : clamp(_s.pws, -64, 64), sweep : clamp(_s.sweep, -8, 8), fix : _fx, tr : 12
        };
    }
    var _d = global.MUS_INST[clamp(_id, 0, array_length(global.MUS_INST) - 1)];
    return { w : _d.w, w1 : _d.w1, ad : _d.ad, sr : _d.sr, pw : _d.pw, pws : _d.pws, sweep : _d.sweep, fix : _d.fix, tr : _d.tr };
}

/// Compiles songs into { insts[], pats[] (event arrays), songs[] ({ speed, swing, bars, loop, order[3][] }), levels[] }.
/// Every pattern is a list of MUS_EV_SIZE-byte events (see the top of this file).
function music_compile(_songs, _levels)
{
    var _cs = { insts : [], inst_keys : [], pats : [], songs : [], levels : array_create(MUS_LEVELS, 255) };
    for (var s = 0; s < array_length(_songs); s++)
    {
        var _song = _songs[s];
        var _sp = clamp(_song.speed, 2, 12);
        var _c = { speed : _sp, swing : clamp(_song.swing, 0, _sp - 1), bars : clamp(_song.arr.bars, 1, MUS_BAR_MAX),
                   loop : clamp(_song.loop_bar, 0, _song.arr.bars - 1), order : [] };
        // each loop the song uses becomes one pattern (unused ones cost nothing)
        var _map = array_create(array_length(_song.arr.loops), -1);
        for (var lb = 0; lb < _c.bars; lb++)
        {
            for (var lv = 0; lv < MUS_LANES; lv++)
            {
                var _u = _song.arr.lanes[lv][lb];
                if (_u >= 0 && _u < array_length(_map) && _map[_u] < 0 && array_length(_cs.pats) < 255)
                {
                    _map[_u] = array_length(_cs.pats);
                    array_push(_cs.pats, music_compile_loop(_cs, _song.arr.loops[_u], _c.speed, _c.swing));
                }
            }
        }
        for (var v = 0; v < MUS_LANES; v++)
        {
            var _o = array_create(_c.bars, 255);
            for (var b = 0; b < _c.bars; b++)
            {
                var _li = _song.arr.lanes[v][b];
                if (_li >= 0 && _li < array_length(_map) && _map[_li] >= 0) { _o[b] = _map[_li]; }
            }
            array_push(_c.order, _o);
        }
        array_push(_cs.songs, _c);
    }
    for (var l = 0; l < MUS_LEVELS; l++)
    {
        if (l < array_length(_levels) && _levels[l] >= 0 && _levels[l] < array_length(_songs)) { _cs.levels[l] = _levels[l]; }
    }
    return _cs;
}

/// The compiled instrument index of instrument _id (added to _cs.insts when first used), or -1 when full
function music_compile_inst(_cs, _id, _drum)
{
    var _key = string(_id) + "_" + string(_drum);
    for (var k = 0; k < array_length(_cs.inst_keys); k++)
    {
        if (_cs.inst_keys[k] == _key) { return k; }
    }
    if (array_length(_cs.insts) >= 64) { return -1; }
    array_push(_cs.insts, music_inst_compiled(_id, _drum));
    array_push(_cs.inst_keys, _key);
    return array_length(_cs.insts) - 1;
}

/// One loop -> events; instruments are added to _cs.insts as they are first used.
/// _speed and _swing are the song's (a linked bend's rate is worked out in frames).
function music_compile_loop(_cs, _lp, _speed, _swing)
{
    var _ev = [];
    var _drum = (_lp.cat == 0);
    // the notes linked bends arrive at: they carry on without a new attack
    var _arrive = array_create(MUS_STEPS, false);
    if (!_drum)
    {
        for (var g = 0; g < MUS_STEPS; g++)
        {
            if (music_glide_valid(_lp, g)) { _arrive[_lp.glide_to[g]] = true; }
        }
    }
    for (var st = 0; st < MUS_STEPS; st++)
    {
        var _n = _lp.notes[st];
        var _src = music_fx_active_step(_lp, st);
        var _fx = 0, _fp = 0, _fd = 0;
        if (_src >= 0)
        {
            _fx = clamp(_lp.fx[_src], 0, 5);
            _fp = clamp(_lp.fxp[_src], 0, 255);
            if (_fx == 5) { _fp = min(_fp, 15); }
            _fd = music_fx_last(_lp, _src) - st + 1;
        }
        if (_n <= 0)
        {
            // an effect that starts on a step with no note: it changes the note that is sounding
            if (_src == st) { array_push(_ev, [st, 0, 255, 0, 0, _fx, _fp, _fd]); }
            continue;
        }
        var _id = _lp.insts[st];
        if (!_drum) { _id = _lp.inst; }
        var _ii = music_compile_inst(_cs, _id, _drum);
        if (_ii < 0) { continue; }
        var _ins = _cs.insts[_ii];
        var _snd = 0;
        if (_ins.fix == 0) { _snd = clamp(_n + _ins.tr, 1, MUS_SOUND_MAX); }
        var _ib = _ii;
        if (_arrive[st] && _ins.fix == 0) { _ib = _ii | 128; }
        var _len = music_note_length(_lp, st);
        var _arp = _lp.arps[st] & 255;
        if (!_drum && _ins.fix == 0 && music_glide_valid(_lp, st))
        {
            // a linked bend: slide to the target note so it arrives on its step (the gate stays on)
            var _t = _lp.glide_to[st];
            var _tsnd = clamp(_lp.notes[_t] + _ins.tr, 1, MUS_SOUND_MAX);
            var _frames = 0;
            for (var k = st; k < _t; k++) { _frames += music_step_frames(k, _speed, _swing); }
            var _rate = clamp(round(abs(music_note_freq(_tsnd) - music_note_freq(_snd)) / max(1, _frames)), 1, 65535);
            _fx = 6;
            _arp = _tsnd;
            _fp = _rate & 255;
            _fd = _rate >> 8;
            _len = min(MUS_STEPS, _t - st + 1);
        }
        array_push(_ev, [st, _snd, _ib, _len, _arp, _fx, _fp, _fd]);
    }
    return _ev;
}

// ---------------------------------------------------------------------------
// Preview player: the driver's frame logic in GML (keep it in step with music_emit)
// driving 3 SID voices synthesised at MUS_RATE.
// ---------------------------------------------------------------------------

function mus_sidv_new()
{
    return { acc : 0, lfsr : 0x7ffff8, nz : 0, env : 0, est : 2, rc : 0, ec : 0, ctrl : 0, freq : 0, pw : 2048, ad : 0, sr : 0 };
}

/// Writes the control register of synth voice _sv (a gate 0 -> 1 restarts the attack)
function mus_sidv_ctrl(_sv, _c)
{
    if ((_c & 1) != 0 && (_sv.ctrl & 1) == 0)
    {
        _sv.est = 0;
        _sv.rc = 0;
    }
    if ((_c & 1) == 0 && (_sv.ctrl & 1) != 0) { _sv.est = 2; }
    _sv.ctrl = _c;
}

/// One output sample of synth voice _sv (-1..1)
function mus_sidv_sample(_sv, _cyc)
{
    if (_sv.est == 2 && _sv.env == 0) { return 0; }
    var _prev = _sv.acc;
    _sv.acc = (_sv.acc + _sv.freq * _cyc) mod 16777216;
    var _wb = _sv.ctrl & 0xf0;
    if ((_wb & 128) != 0)
    {
        var _clocks = floor((_sv.acc + 524288) / 1048576) - floor((_prev + 524288) / 1048576);
        if (_clocks < 0) { _clocks += 16; }
        for (var c = 0; c < _clocks; c++)
        {
            var _bit = ((_sv.lfsr >> 22) ^ (_sv.lfsr >> 17)) & 1;
            _sv.lfsr = ((_sv.lfsr << 1) | _bit) & 0x7fffff;
        }
        var _l = _sv.lfsr;
        _sv.nz = (((_l >> 20) & 1) << 7) | (((_l >> 18) & 1) << 6) | (((_l >> 14) & 1) << 5) | (((_l >> 11) & 1) << 4)
               | (((_l >> 9) & 1) << 3) | (((_l >> 5) & 1) << 2) | (((_l >> 2) & 1) << 1) | (_l & 1);
    }
    var _a12 = floor(_sv.acc / 4096);
    var _w = 4095;
    if ((_wb & 16) != 0)
    {
        var _tri = _a12 * 2;
        if (_a12 >= 2048) { _tri = (4095 - _a12) * 2; }
        _w = _w & clamp(_tri, 0, 4095);
    }
    if ((_wb & 32) != 0) { _w = _w & _a12; }
    if ((_wb & 64) != 0)
    {
        if (_a12 < _sv.pw) { _w = 0; }
    }
    if ((_wb & 128) != 0) { _w = _w & (_sv.nz << 4); }
    if (_wb == 0) { _w = 2048; }
    // ADSR with the SID's step rates
    var _per = global.SID_RATE[(_sv.ad >> 4) & 15];
    if (_sv.est == 1) { _per = global.SID_RATE[_sv.ad & 15]; }
    if (_sv.est == 2) { _per = global.SID_RATE[_sv.sr & 15]; }
    _sv.rc += _cyc;
    while (_sv.rc >= _per)
    {
        _sv.rc -= _per;
        if (_sv.est == 0)
        {
            _sv.env += 1;
            if (_sv.env >= 255) { _sv.env = 255; _sv.est = 1; }
        }
        else
        {
            var _div = 1;
            if (_sv.env < 94) { _div = 2; }
            if (_sv.env < 55) { _div = 4; }
            if (_sv.env < 27) { _div = 8; }
            if (_sv.env < 15) { _div = 16; }
            if (_sv.env < 7) { _div = 30; }
            _sv.ec += 1;
            if (_sv.ec >= _div)
            {
                _sv.ec = 0;
                if (_sv.est == 1)
                {
                    if (_sv.env > ((_sv.sr >> 4) & 15) * 17) { _sv.env -= 1; }
                }
                else
                {
                    if (_sv.env > 0) { _sv.env -= 1; }
                }
            }
        }
    }
    return (_w / 2047.5 - 1) * (_sv.env / 255);
}

/// A player for compiled songs _cs, starting song _song at bar _bar. _once: stop after the last bar.
function mus_player_new(_cs, _song, _bar, _once)
{
    var _pl = {
        cs : _cs, on : false, once : _once, song : 0, bar : 0, step : 0, tick : 1, speed : 3, swing : 0, bars : 1, loop : 0,
        v : [], sv : [], cyc : sid_clock() / MUS_RATE, spf : MUS_RATE / sid_fps(), fpos : 0, done : false, ended : 0,
        pos_bar : 0, pos_step : 0
    };
    for (var i = 0; i < MUS_LANES; i++)
    {
        array_push(_pl.v, { on : false, pat : [], idx : 0, act : false, note : 0, ins : 0, gt : 0, arp : 0, as : 0, fx : 0, fp : 0, vph : 0,
                            fl : 0, tl : 0, pw : 2048, pws : 0, first : false, fs : 0, rh : 0, bt : 0 });
        array_push(_pl.sv, mus_sidv_new());
    }
    mus_player_play(_pl, _song, _bar);
    return _pl;
}

/// mus_play: start song _s (from bar _bar)
function mus_player_play(_pl, _s, _bar)
{
    if (_s < 0 || _s >= array_length(_pl.cs.songs))
    {
        _pl.on = false;
        return;
    }
    var _c = _pl.cs.songs[_s];
    _pl.song = _s;
    _pl.speed = _c.speed;
    _pl.swing = _c.swing;
    _pl.bars = _c.bars;
    _pl.loop = _c.loop;
    _pl.bar = clamp(_bar, 0, _c.bars - 1);
    _pl.step = 0;
    _pl.tick = 1;
    _pl.on = true;
    for (var i = 0; i < MUS_LANES; i++)
    {
        _pl.v[i].on = false;
        _pl.v[i].act = false;
        mus_sidv_ctrl(_pl.sv[i], 0);
    }
}

/// mus_update: one frame of the driver
function mus_player_frame(_pl)
{
    if (!_pl.on) { return; }
    _pl.tick -= 1;
    if (_pl.tick <= 0) { mus_player_step(_pl); }
    for (var i = 0; i < MUS_LANES; i++) { mus_player_voice(_pl, i); }
}

function mus_player_step(_pl)
{
    var _c = _pl.cs.songs[_pl.song];
    _pl.pos_bar = _pl.bar;
    _pl.pos_step = _pl.step;
    if (_pl.step == 0)
    {
        for (var i = 0; i < MUS_LANES; i++)
        {
            var _o = _c.order[i][_pl.bar];
            var _v = _pl.v[i];
            if (_o == 255) { _v.on = false; }
            else
            {
                _v.pat = _pl.cs.pats[_o];
                _v.idx = 0;
                _v.on = true;
            }
        }
    }
    for (var j = 0; j < MUS_LANES; j++) { mus_player_note(_pl, j); }
    var _q = _pl.step & 3;
    _pl.tick = _pl.speed;
    if (_q == 0) { _pl.tick = _pl.speed + _pl.swing; }
    if (_q == 2) { _pl.tick = _pl.speed - _pl.swing; }
    _pl.step += 1;
    if (_pl.step >= MUS_STEPS)
    {
        _pl.step = 0;
        _pl.bar += 1;
        if (_pl.bar >= _pl.bars)
        {
            _pl.bar = _pl.loop;
            if (_pl.once) { _pl.done = true; }
        }
    }
}

function mus_player_note(_pl, _i)
{
    var _v = _pl.v[_i];
    // an effect lasts its number of steps
    if (_v.fs > 0)
    {
        _v.fs -= 1;
        if (_v.fs == 0) { _v.fx = 0; }
    }
    if (!_v.on || _pl.done) { return; }
    if (_v.idx >= array_length(_v.pat)) { return; }
    var _e = _v.pat[_v.idx];
    if (_e[0] != _pl.step) { return; }
    _v.idx += 1;
    _v.fx = _e[5];
    _v.fp = _e[6];
    var _arp = _e[4];
    if (_v.fx == 6)
    {
        // a linked bend: the target note and the 16-bit rate
        _v.rh = _e[7];
        _v.bt = music_note_freq(_arp);
        _v.fs = 0;
        _arp = 0;
    }
    else { _v.fs = _e[7]; }
    if (_e[2] == 255) { return; }                  // only an effect
    _v.note = _e[1];
    _v.ins = _e[2] & 127;
    _v.arp = _arp;
    _v.gt = min(255, _e[3] * _pl.speed);
    var _in = _pl.cs.insts[_v.ins];
    if (_in.fix > 0)
    {
        _v.fl = _in.fix * 256;
    }
    else
    {
        _v.tl = music_note_freq(_v.note);
        if ((_e[2] & 128) != 0 && _v.act)
        {
            _v.fl = _v.tl;                         // a bend arrives: the note carries on
            return;
        }
        if (_v.fx == 4 && _v.act) { return; }      // glide: no new attack, the pitch slides in
        _v.fl = _v.tl;
    }
    _v.pw = _in.pw;
    _v.pws = _in.pws;
    _v.as = 0;
    _v.vph = 0;
    _v.act = true;
    _v.first = true;
    var _sv = _pl.sv[_i];
    mus_sidv_ctrl(_sv, 0);
    _sv.ad = _in.ad;
    _sv.sr = _in.sr;
}

function mus_player_voice(_pl, _i)
{
    var _v = _pl.v[_i];
    if (!_v.act) { return; }
    if (_v.gt > 0) { _v.gt -= 1; }
    var _in = _pl.cs.insts[_v.ins];
    // pitch sweep of the instrument (high byte, clamped)
    if (_in.sweep != 0)
    {
        var _hi = clamp((_v.fl >> 8) + _in.sweep, 0, 255);
        _v.fl = (_hi << 8) | (_v.fl & 255);
    }
    // effects (16-bit frequency)
    if (_v.fx == 1) { _v.fl = min(65535, _v.fl + _v.fp * 8); }
    if (_v.fx == 2) { _v.fl = max(0, _v.fl - _v.fp * 8); }
    if (_v.fx == 3)
    {
        // vibrato: depth in bits 0-5, speed - 1 in bits 6-7
        var _inc = (_v.fp >> 6) + 1;
        var _vd = (_v.fp & 63) * 2 * _inc;
        if (((_v.vph + 4) & 8) == 0) { _v.fl = min(65535, _v.fl + _vd); }
        else { _v.fl = max(0, _v.fl - _vd); }
        _v.vph = (_v.vph + _inc) & 15;
    }
    if (_v.fx == 4 || _v.fx == 6)
    {
        var _d = _v.fp * 16;
        if (_v.fx == 6)
        {
            _v.tl = _v.bt;
            _d = _v.fp | (_v.rh << 8);
        }
        if (_v.fl < _v.tl) { _v.fl = min(_v.tl, _v.fl + _d); }
        else { _v.fl = max(_v.tl, _v.fl - _d); }
    }
    var _out = _v.fl;
    if (_v.arp != 0 && _in.fix == 0)
    {
        _v.as += 1;
        if (_v.as >= 3) { _v.as = 0; }
        if (_v.as == 1) { _out = music_note_freq(min(MUS_SOUND_MAX, _v.note + (_v.arp >> 4))); }
        if (_v.as == 2) { _out = music_note_freq(min(MUS_SOUND_MAX, _v.note + (_v.arp & 15))); }
    }
    if (_v.pws != 0) { _v.pw = (_v.pw + _v.pws) & 4095; }
    var _sv = _pl.sv[_i];
    _sv.freq = _out;
    _sv.pw = _v.pw;
    // the envelope every frame; the volume effect sets the sustain level
    _sv.ad = _in.ad;
    _sv.sr = _in.sr;
    if (_v.fx == 5) { _sv.sr = ((_v.fp & 15) << 4) | (_in.sr & 15); }
    var _w = _in.w;
    if (_v.first)
    {
        _v.first = false;
        if (_in.w1 != 0) { _w = _in.w1; }
    }
    if (_v.gt > 0) { _w = _w | 1; }
    mus_sidv_ctrl(_sv, _w);
}

/// Renders _n samples into _buf (s16) at its current position
function mus_player_render(_pl, _buf, _n)
{
    for (var i = 0; i < _n; i++)
    {
        if (_pl.fpos <= 0)
        {
            _pl.fpos += _pl.spf;
            mus_player_frame(_pl);
            if (_pl.done)
            {
                _pl.ended += 1;
                if (_pl.ended == 1)
                {
                    for (var g = 0; g < MUS_LANES; g++) { mus_sidv_ctrl(_pl.sv[g], _pl.sv[g].ctrl & 0xfe); }
                }
            }
        }
        _pl.fpos -= 1;
        var _o = 0;
        for (var k = 0; k < MUS_LANES; k++) { _o += mus_sidv_sample(_pl.sv[k], _pl.cyc); }
        buffer_write(_buf, buffer_s16, round(clamp(_o * 0.3, -1, 1) * 32000));
    }
}

// ---------------- streaming the preview through an audio queue ----------------

/// Starts playing compiled songs _cs (song _song from bar _bar); _what names what is playing
function music_preview_start(_cs, _song, _bar, _once, _what)
{
    music_preview_stop();
    if (array_length(_cs.songs) == 0) { return; }
    sfx_preview_stop();
    mus_pl = mus_player_new(_cs, _song, _bar, _once);
    mus_queue = audio_create_play_queue(buffer_s16, MUS_RATE, audio_mono);
    mus_rendered = 0;
    mus_marks = [];
    mus_playing = true;
    mus_play_what = _what;
    mus_started = current_time;
    music_preview_fill(0.35);
    mus_inst = audio_play_sound(mus_queue, 1, false);
}

/// Keeps _ahead seconds of sound queued
function music_preview_fill(_ahead)
{
    var _played = (current_time - mus_started) / 1000 * MUS_RATE;
    var _guard = 0;
    while (mus_rendered - _played < _ahead * MUS_RATE && _guard < 8)
    {
        _guard += 1;
        if (mus_pl.done && mus_pl.ended > sid_fps() * 2) { break; }
        var _n = 1470;
        var _b = buffer_create(_n * 2, buffer_fixed, 2);
        array_push(mus_marks, [mus_rendered, mus_pl.pos_bar + mus_pl.pos_step / MUS_STEPS]);
        mus_player_render(mus_pl, _b, _n);
        audio_queue_sound(mus_queue, _b, 0, _n * 2);
        array_push(mus_bufs, _b);
        mus_rendered += _n;
    }
    if (array_length(mus_marks) > 64) { array_delete(mus_marks, 0, array_length(mus_marks) - 64); }
}

function music_preview_stop()
{
    if (!mus_playing) { return; }
    mus_playing = false;
    mus_play_what = "";
    if (mus_queue != -1)
    {
        audio_stop_sound(mus_inst);
        audio_free_play_queue(mus_queue);
        mus_queue = -1;
    }
    mus_old_bufs_time = current_time;
}

/// Every step: keep the queue fed, stop at the end of a one-shot, free spent buffers
function music_preview_step()
{
    if (!mus_playing)
    {
        // the queue is gone: its buffers can go once the audio thread is done with them
        if (array_length(mus_bufs) > 0 && current_time - mus_old_bufs_time > 500)
        {
            for (var i = 0; i < array_length(mus_bufs); i++)
            {
                if (buffer_exists(mus_bufs[i])) { buffer_delete(mus_bufs[i]); }
            }
            mus_bufs = [];
        }
        return;
    }
    music_preview_fill(0.35);
    var _played = (current_time - mus_started) / 1000 * MUS_RATE;
    if (mus_pl.done && _played > mus_rendered) { music_preview_stop(); }
}

/// Async audio playback: a queued buffer has been played
function music_preview_async()
{
    var _b = async_load[? "buffer_id"];
    for (var i = 0; i < array_length(mus_bufs); i++)
    {
        if (mus_bufs[i] == _b)
        {
            buffer_delete(_b);
            array_delete(mus_bufs, i, 1);
            return;
        }
    }
}

/// Where the preview is now, in bars (bar + step / 32), or -1
function music_preview_pos()
{
    if (!mus_playing) { return -1; }
    var _played = (current_time - mus_started) / 1000 * MUS_RATE;
    var _pos = -1;
    for (var i = 0; i < array_length(mus_marks); i++)
    {
        if (mus_marks[i][0] <= _played) { _pos = mus_marks[i][1]; }
    }
    return _pos;
}

// ---------------------------------------------------------------------------
// The 6502 music driver and its data (emitted into both kinds of game)
// ---------------------------------------------------------------------------

/// Pushes the music driver, note table and song data onto L. mus_play (A = song), mus_stop,
/// mus_level (A = level: plays that level's song, carries on if it is already playing),
/// mus_update (once a frame, from sfx_update). With no songs these are just rts.
function music_emit(L, _p)
{
    array_push(L, "; ---------------- music driver: 3 SID voices, sound effects borrow voices 1 and 2 ----------------");
    array_push(L, "mus_start:");
    var _cs = music_compile(_p.songs, _p.level_song);
    if (array_length(_cs.songs) == 0)
    {
        array_push(L, "mus_play:", "mus_stop:", "mus_level:", "mus_update:", " rts", "mus_end:");
        return;
    }
    var _ns = array_length(_cs.songs);
    var _z = string(MUS_ZP);
    var _z1 = string(MUS_ZP + 1);
    array_push(L, "MUS_NSONGS = " + string(_ns));
    // ---- start / stop ----
    array_push(L, "mus_stop:", " stx m_sx", " lda #0", " sta m_on", " ldx #0", " jsr mv_quiet", " ldx #7", " jsr mv_quiet", " ldx #14", " jsr mv_quiet", " ldx m_sx", " rts");
    array_push(L, "mv_quiet:", " lda #0", " sta mv_on,x", " sta mv_act,x", " jsr mv_busy", " bne mvq_r", " sta $d404,x");
    array_push(L, "mvq_r:", " rts");
    // a sound effect has voice X while sfx_update counts it down (voice 3 is never used by them)
    // ... and a patch sound has the voices in pt_vm while it plays (voice 3 too, when it needs it)
    if (patch_any(_p)) { array_push(L, "mv_busy:", " lda pt_on", " beq mvb_s", " lda pt_vbit,x", " and pt_vm", " bne mvb_r"); }
    else { array_push(L, "mv_busy:"); }
    array_push(L, "mvb_s:", " cpx #14", " beq mvb_no", " lda sv_t,x", "mvb_r:", " rts", "mvb_no:", " lda #0", " rts");
    // (X and Y are kept by all three)
    array_push(L, "mus_level:", " sty m_sy", " tay", " lda mus_lvl,y", " ldy m_sy", " cmp #$ff", " beq mus_stop", " sta m_t1", " lda m_on", " beq ml_go");
    array_push(L, " lda m_t1", " cmp m_song", " bne ml_go", " rts", "ml_go:", " lda m_t1");
    array_push(L, "mus_play:", " cmp #MUS_NSONGS", " bcs mus_stop", " stx m_sx", " sty m_sy", " sta m_song", " tay");
    array_push(L, " lda ms_speed,y", " sta m_speed", " lda ms_swing,y", " sta m_swing", " lda ms_bars,y", " sta m_bars", " lda ms_loop,y", " sta m_loop");
    array_push(L, " lda ms_o0l,y", " sta m_ol", " lda ms_o0h,y", " sta m_oh", " lda ms_o1l,y", " sta m_ol+7", " lda ms_o1h,y", " sta m_oh+7");
    array_push(L, " lda ms_o2l,y", " sta m_ol+14", " lda ms_o2h,y", " sta m_oh+14");
    array_push(L, " lda #0", " sta m_bar", " sta m_step", " lda #1", " sta m_tick", " sta m_on");
    array_push(L, " ldx #0", " jsr mv_quiet", " ldx #7", " jsr mv_quiet", " ldx #14", " jsr mv_quiet", " ldx m_sx", " ldy m_sy", " rts");
    // ---- once a frame ----
    array_push(L, "mus_update:", " lda m_on", " bne mu_go", " rts");
    array_push(L, "mu_go:", " dec m_tick", " bne mu_fr", " jsr mu_step");
    array_push(L, "mu_fr:", " ldx #0", " jsr mu_voice", " ldx #7", " jsr mu_voice", " ldx #14", " jmp mu_voice");
    // ---- a step: new bar -> patterns, then each voice's note, then the next step's length ----
    array_push(L, "mu_step:", " lda m_bar", " sta m_pbar", " lda m_step", " sta m_pstep", " bne ms_ev", " ldx #0", " jsr ms_bar", " ldx #7", " jsr ms_bar", " ldx #14", " jsr ms_bar");
    array_push(L, "ms_ev:", " ldx #0", " jsr ms_note", " ldx #7", " jsr ms_note", " ldx #14", " jsr ms_note");
    array_push(L, " lda m_step", " and #3", " bne ms_t1", " lda m_speed", " clc", " adc m_swing", " jmp ms_t3");
    array_push(L, "ms_t1:", " cmp #2", " bne ms_t2", " lda m_speed", " sec", " sbc m_swing", " jmp ms_t3");
    array_push(L, "ms_t2:", " lda m_speed");
    array_push(L, "ms_t3:", " sta m_tick", " inc m_step", " lda m_step", " cmp #" + string(MUS_STEPS), " bne ms_r");
    array_push(L, " lda #0", " sta m_step", " inc m_bar", " lda m_bar", " cmp m_bars", " bcc ms_r", " lda m_loop", " sta m_bar");
    array_push(L, "ms_r:", " rts");
    array_push(L, "ms_bar:", " lda m_ol,x", " sta " + _z, " lda m_oh,x", " sta " + _z1, " ldy m_bar", " lda (" + _z + "),y", " cmp #$ff", " bne mb_p", " lda #0", " sta mv_on,x", " rts");
    array_push(L, "mb_p:", " tay", " lda mp_lo,y", " sta mv_pl,x", " lda mp_hi,y", " sta mv_ph,x", " lda #0", " sta mv_idx,x", " lda #1", " sta mv_on,x", " rts");
    // a note: read the event when it is for this step
    // an effect lasts its number of steps
    array_push(L, "ms_note:", " lda mv_fs,x", " beq mn_0", " dec mv_fs,x", " bne mn_0", " lda #0", " sta mv_fx,x");
    array_push(L, "mn_0:", " lda mv_on,x", " bne mn_1", " rts");
    array_push(L, "mn_1:", " lda mv_pl,x", " sta " + _z, " lda mv_ph,x", " sta " + _z1, " ldy mv_idx,x", " lda (" + _z + "),y", " cmp m_step", " beq mn_2", " rts");
    array_push(L, "mn_2:", " iny", " lda (" + _z + "),y", " sta m_t3", " iny", " lda (" + _z + "),y", " sta m_t4");
    array_push(L, " iny", " lda (" + _z + "),y", " sta m_t1", " iny", " lda (" + _z + "),y", " sta m_t5");
    array_push(L, " iny", " lda (" + _z + "),y", " sta mv_fx,x", " iny", " lda (" + _z + "),y", " sta mv_fp,x", " iny", " lda (" + _z + "),y", " sta m_t6", " iny", " tya", " sta mv_idx,x");
    // a linked bend: its target note (in the chord byte) and 16-bit rate; else the effect's length
    array_push(L, " lda mv_fx,x", " cmp #6", " bne mn_fd", " lda m_t6", " sta mv_rh,x", " ldy m_t5", " lda mft_lo,y", " sta mv_bl,x", " lda mft_hi,y", " sta mv_bh,x");
    array_push(L, " lda #0", " sta mv_fs,x", " sta m_t5", " beq mn_ev");
    array_push(L, "mn_fd:", " lda m_t6", " sta mv_fs,x");
    // only an effect: the note sounding carries on
    array_push(L, "mn_ev:", " lda m_t4", " cmp #255", " bne mn_3", " rts");
    array_push(L, "mn_3:", " and #127", " sta mv_ins,x", " lda m_t3", " sta mv_note,x", " lda m_t5", " sta mv_arp,x");
    // gate time = length x speed frames (at most 255)
    array_push(L, " lda #0", " ldy m_t1");
    array_push(L, "mn_g:", " clc", " adc m_speed", " bcc mn_g2", " lda #255");
    array_push(L, "mn_g2:", " dey", " bne mn_g", " sta mv_gt,x");
    // frequency: a drum's own pitch, or the note's (glide keeps the old note sounding)
    array_push(L, " ldy mv_ins,x", " lda mi_fix,y", " beq mn_tone", " sta mv_fh,x", " lda #0", " sta mv_fl,x", " jmp mn_set");
    array_push(L, "mn_tone:", " ldy mv_note,x", " lda mft_lo,y", " sta mv_tl,x", " lda mft_hi,y", " sta mv_th,x");
    // a bend arrives (instrument + 128): the note carries on at its pitch, no new attack
    array_push(L, " lda m_t4", " bpl mn_nl", " lda mv_act,x", " beq mn_jump", " jmp mn_lg");
    array_push(L, "mn_nl:", " lda mv_fx,x", " cmp #4", " bne mn_jump", " lda mv_act,x", " beq mn_jump", " rts");
    array_push(L, "mn_jump:", " lda mv_tl,x", " sta mv_fl,x", " lda mv_th,x", " sta mv_fh,x");
    array_push(L, "mn_set:", " ldy mv_ins,x", " lda mi_pwl,y", " sta mv_pwl,x", " lda mi_pwh,y", " sta mv_pwh,x", " lda mi_pws,y", " sta mv_pws,x");
    array_push(L, " lda #0", " sta mv_as,x", " sta mv_vph,x", " lda #1", " sta mv_act,x", " sta mv_first,x");
    array_push(L, " jsr mv_busy", " bne mn_r", " sta $d404,x", " ldy mv_ins,x", " lda mi_ad,y", " sta $d405,x", " lda mi_sr,y", " sta $d406,x");
    array_push(L, "mn_r:", " rts");
    array_push(L, "mn_lg:", " lda mv_tl,x", " sta mv_fl,x", " lda mv_th,x", " sta mv_fh,x", " rts");
    // ---- a voice, every frame ----
    array_push(L, "mu_voice:", " lda mv_act,x", " bne mv_1", " rts");
    array_push(L, "mv_1:", " lda mv_gt,x", " beq mv_2", " dec mv_gt,x");
    // instrument pitch sweep (high byte, clamped)
    array_push(L, "mv_2:", " ldy mv_ins,x", " lda mi_sw,y", " beq mv_efx", " bmi mv_swn", " clc", " adc mv_fh,x", " bcc mv_sws", " lda #255", " jmp mv_sws");
    array_push(L, "mv_swn:", " clc", " adc mv_fh,x", " bcs mv_sws", " lda #0");
    array_push(L, "mv_sws:", " sta mv_fh,x");
    // effects: m_t1/m_t2 = the amount as a 16-bit step
    array_push(L, "mv_efx:", " lda mv_fx,x", " bne mv_f0", " jmp mv_out");
    array_push(L, "mv_f0:", " lda mv_fp,x", " sta m_t1", " lda #0", " sta m_t2", " lda mv_fx,x", " cmp #3", " bne mv_fa", " jmp mv_vib");
    array_push(L, "mv_fa:", " cmp #4", " bne mv_fb", " jmp mv_gli", "mv_fb:", " cmp #6", " bne mv_fc", " jmp mv_bend", "mv_fc:", " cmp #5", " bne mv_fd", " jmp mv_out", "mv_fd:");
    // slide: amount x 8
    array_push(L, " asl m_t1", " rol m_t2", " asl m_t1", " rol m_t2", " asl m_t1", " rol m_t2", " lda mv_fx,x", " cmp #1", " bne mv_dn");
    array_push(L, "mv_up:", " clc", " lda mv_fl,x", " adc m_t1", " sta mv_fl,x", " lda mv_fh,x", " adc m_t2", " bcc mv_upo", " lda #$ff", " sta mv_fl,x");
    array_push(L, "mv_upo:", " sta mv_fh,x", " jmp mv_out");
    array_push(L, "mv_dn:", " sec", " lda mv_fl,x", " sbc m_t1", " sta mv_fl,x", " lda mv_fh,x", " sbc m_t2", " bcs mv_dno", " lda #0", " sta mv_fl,x");
    array_push(L, "mv_dno:", " sta mv_fh,x", " jmp mv_out");
    // vibrato: depth (bits 0-5) x 2 x speed (bits 6-7, + 1); up for a quarter of the cycle,
    // down for a half, up for a quarter; the speed is how far round the 16-step cycle a frame goes
    array_push(L, "mv_vib:", " lda mv_fp,x", " and #63", " sta m_t1", " lda mv_fp,x", " rol", " rol", " rol", " and #3", " clc", " adc #1", " sta m_t3");
    array_push(L, " asl m_t1", " rol m_t2", " lda #0", " sta m_t4", " sta m_t5", " ldy m_t3");
    array_push(L, "mvv_m:", " clc", " lda m_t4", " adc m_t1", " sta m_t4", " lda m_t5", " adc m_t2", " sta m_t5", " dey", " bne mvv_m");
    array_push(L, " lda m_t4", " sta m_t1", " lda m_t5", " sta m_t2");
    array_push(L, " lda mv_vph,x", " tay", " clc", " adc m_t3", " and #15", " sta mv_vph,x", " tya", " clc", " adc #4", " and #8", " bne mvv_d", " jmp mv_up", "mvv_d:", " jmp mv_dn");
    // a linked bend: its own target and 16-bit rate, then as a glide
    array_push(L, "mv_bend:", " lda mv_bl,x", " sta mv_tl,x", " lda mv_bh,x", " sta mv_th,x", " lda mv_fp,x", " sta m_t1", " lda mv_rh,x", " sta m_t2", " jmp mv_gcmp");
    // glide: amount x 16 towards the target note
    array_push(L, "mv_gli:", " asl m_t1", " rol m_t2", " asl m_t1", " rol m_t2", " asl m_t1", " rol m_t2", " asl m_t1", " rol m_t2");
    array_push(L, "mv_gcmp:", " lda mv_fh,x", " cmp mv_th,x", " bne mv_gc", " lda mv_fl,x", " cmp mv_tl,x", " bne mv_gc", " jmp mv_out");
    array_push(L, "mv_gc:", " bcs mv_gd");
    array_push(L, " clc", " lda mv_fl,x", " adc m_t1", " sta mv_fl,x", " lda mv_fh,x", " adc m_t2", " sta mv_fh,x", " bcs mv_gset");
    array_push(L, " cmp mv_th,x", " bcc mv_out", " bne mv_gset", " lda mv_fl,x", " cmp mv_tl,x", " bcc mv_out", " jmp mv_gset");
    array_push(L, "mv_gd:", " sec", " lda mv_fl,x", " sbc m_t1", " sta mv_fl,x", " lda mv_fh,x", " sbc m_t2", " sta mv_fh,x", " bcc mv_gset");
    array_push(L, " cmp mv_th,x", " bcc mv_gset", " bne mv_out", " lda mv_fl,x", " cmp mv_tl,x", " bcs mv_out");
    array_push(L, "mv_gset:", " lda mv_tl,x", " sta mv_fl,x", " lda mv_th,x", " sta mv_fh,x");
    // output: chord (arpeggio) notes come from the note table, else the current frequency
    array_push(L, "mv_out:", " lda mv_fl,x", " sta m_t1", " lda mv_fh,x", " sta m_t2");
    array_push(L, " lda mv_arp,x", " beq mv_pw", " ldy mv_ins,x", " lda mi_fix,y", " bne mv_pw");
    array_push(L, " inc mv_as,x", " lda mv_as,x", " cmp #3", " bcc mv_a1", " lda #0", " sta mv_as,x");
    array_push(L, "mv_a1:", " cmp #1", " bne mv_a2", " lda mv_arp,x", " lsr", " lsr", " lsr", " lsr", " jmp mv_a3");
    array_push(L, "mv_a2:", " cmp #2", " bne mv_pw", " lda mv_arp,x", " and #15");
    array_push(L, "mv_a3:", " clc", " adc mv_note,x", " cmp #" + string(MUS_SOUND_MAX + 1), " bcc mv_a4", " lda #" + string(MUS_SOUND_MAX));
    array_push(L, "mv_a4:", " tay", " lda mft_lo,y", " sta m_t1", " lda mft_hi,y", " sta m_t2");
    // pulse width sweep (12 bits, wraps round)
    array_push(L, "mv_pw:", " lda mv_pws,x", " beq mv_wr", " bmi mv_pn", " clc", " adc mv_pwl,x", " sta mv_pwl,x", " lda mv_pwh,x", " adc #0", " jmp mv_pq");
    array_push(L, "mv_pn:", " clc", " adc mv_pwl,x", " sta mv_pwl,x", " lda mv_pwh,x", " adc #$ff");
    array_push(L, "mv_pq:", " and #$0f", " sta mv_pwh,x");
    // to the SID, unless a sound effect has the voice
    array_push(L, "mv_wr:", " jsr mv_busy", " bne mv_x", " lda m_t1", " sta $d400,x", " lda m_t2", " sta $d401,x", " lda mv_pwl,x", " sta $d402,x", " lda mv_pwh,x", " sta $d403,x");
    // the envelope again every frame: a sound effect may have changed it while it had the voice
    // (the volume effect sets the sustain level)
    array_push(L, " ldy mv_ins,x", " lda mi_ad,y", " sta $d405,x", " lda mv_fx,x", " cmp #5", " bne mv_sr0");
    array_push(L, " lda mv_fp,x", " asl", " asl", " asl", " asl", " sta m_t1", " lda mi_sr,y", " and #$0f", " ora m_t1", " jmp mv_sr1");
    array_push(L, "mv_sr0:", " lda mi_sr,y", "mv_sr1:", " sta $d406,x", " lda mv_first,x", " beq mv_wm", " lda #0", " sta mv_first,x", " lda mi_w1,y", " bne mv_ws");
    array_push(L, "mv_wm:", " lda mi_w,y");
    array_push(L, "mv_ws:", " ldy mv_gt,x", " beq mv_wg", " ora #1", " jmp mv_wo");
    array_push(L, "mv_wg:", " and #$fe");
    array_push(L, "mv_wo:", " sta $d404,x");
    array_push(L, "mv_x:", " rts");

    // ---- data ----
    var _lo = "", _hi = "";
    for (var n = 0; n <= MUS_SOUND_MAX; n++)
    {
        var _f = music_note_freq(n);
        if (n > 0) { _lo += ","; _hi += ","; }
        _lo += string(_f & 255);
        _hi += string(_f >> 8);
    }
    array_push(L, "mft_lo:", " .byte " + _lo, "mft_hi:", " .byte " + _hi);
    var _ik = ["mi_ad", "mi_sr", "mi_w", "mi_w1", "mi_pwl", "mi_pwh", "mi_pws", "mi_sw", "mi_fix"];
    for (var k = 0; k < array_length(_ik); k++)
    {
        var _row = "";
        for (var i = 0; i < max(1, array_length(_cs.insts)); i++)
        {
            var _in = { ad : 0, sr : 0, w : 16, w1 : 0, pw : 0, pws : 0, sweep : 0, fix : 0 };
            if (i < array_length(_cs.insts)) { _in = _cs.insts[i]; }
            var _vals = [_in.ad, _in.sr, _in.w, _in.w1, _in.pw & 255, (_in.pw >> 8) & 15, _in.pws & 255, _in.sweep & 255, _in.fix];
            if (i > 0) { _row += ","; }
            _row += string(_vals[k] & 255);
        }
        array_push(L, _ik[k] + ":", " .byte " + _row);
    }
    var _plo = "", _phi = "";
    for (var pn = 0; pn < array_length(_cs.pats); pn++)
    {
        if (pn > 0) { _plo += ","; _phi += ","; }
        _plo += "<mpat_" + string(pn);
        _phi += ">mpat_" + string(pn);
    }
    if (array_length(_cs.pats) == 0) { _plo = "0"; _phi = "0"; }
    array_push(L, "mp_lo:", " .byte " + _plo, "mp_hi:", " .byte " + _phi);
    for (var pj = 0; pj < array_length(_cs.pats); pj++)
    {
        var _ev = _cs.pats[pj];
        var _b = "";
        for (var e = 0; e < array_length(_ev); e++)
        {
            for (var f = 0; f < MUS_EV_SIZE; f++) { _b += string(_ev[e][f] & 255) + ","; }
        }
        array_push(L, "mpat_" + string(pj) + ":", " .byte " + _b + "255");
    }
    var _sk = ["ms_speed", "ms_swing", "ms_bars", "ms_loop"];
    var _sv = ["speed", "swing", "bars", "loop"];
    for (var k2 = 0; k2 < 4; k2++)
    {
        var _r2 = "";
        for (var s = 0; s < _ns; s++)
        {
            if (s > 0) { _r2 += ","; }
            _r2 += string(_cs.songs[s][$ _sv[k2]]);
        }
        array_push(L, _sk[k2] + ":", " .byte " + _r2);
    }
    for (var v = 0; v < MUS_LANES; v++)
    {
        var _ol = "", _oh = "";
        for (var s2 = 0; s2 < _ns; s2++)
        {
            if (s2 > 0) { _ol += ","; _oh += ","; }
            _ol += "<mord_" + string(s2) + "_" + string(v);
            _oh += ">mord_" + string(s2) + "_" + string(v);
        }
        array_push(L, "ms_o" + string(v) + "l:", " .byte " + _ol, "ms_o" + string(v) + "h:", " .byte " + _oh);
    }
    for (var s3 = 0; s3 < _ns; s3++)
    {
        for (var v2 = 0; v2 < MUS_LANES; v2++)
        {
            var _o = _cs.songs[s3].order[v2];
            var _ob = "";
            for (var b = 0; b < array_length(_o); b++)
            {
                if (b > 0) { _ob += ","; }
                _ob += string(_o[b]);
            }
            array_push(L, "mord_" + string(s3) + "_" + string(v2) + ":", " .byte " + _ob);
        }
    }
    var _lv = "";
    for (var l = 0; l < MUS_LEVELS; l++)
    {
        if (l > 0) { _lv += ","; }
        _lv += string(_cs.levels[l]);
    }
    array_push(L, "mus_lvl:", " .byte " + _lv);
    // variables: per voice, indexed by the voice's SID register offset (0, 7, 14)
    var _vv = ["mv_on", "mv_pl", "mv_ph", "mv_idx", "mv_act", "mv_note", "mv_ins", "mv_gt", "mv_arp", "mv_as", "mv_fx", "mv_fp", "mv_vph",
               "mv_fl", "mv_fh", "mv_tl", "mv_th", "mv_pwl", "mv_pwh", "mv_pws", "mv_first", "m_ol", "m_oh",
               "mv_fs", "mv_rh", "mv_bl", "mv_bh"];
    for (var q = 0; q < array_length(_vv); q++) { array_push(L, _vv[q] + ":", " .fill 15,0"); }
    var _gv = ["m_on", "m_song", "m_bar", "m_step", "m_tick", "m_speed", "m_swing", "m_bars", "m_loop", "m_t1", "m_t2", "m_sx", "m_sy", "m_pbar", "m_pstep",
               "m_t3", "m_t4", "m_t5", "m_t6"];
    for (var q2 = 0; q2 < array_length(_gv); q2++) { array_push(L, _gv[q2] + ":", " .fill 1,0"); }
    array_push(L, "mus_end:");
}
