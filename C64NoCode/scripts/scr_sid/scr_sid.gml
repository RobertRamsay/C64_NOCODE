/// C64 NO-CODE STUDIO - SID sound effects: data model, presets, preview synth and the 6502 player
/// One player is used by both kinds of game (single screen codegen and the map engine).
/// Sounds play on SID voice 1 or 2, borrowing it from the music while they play; voice 3 is the
/// music's alone (scr_music). The player runs once a frame (50 Hz PAL, 60 Hz NTSC).

#macro SFX_MAX 32
#macro SID_CLOCK_PAL 985248
#macro SID_CLOCK_NTSC 1022727
#macro SFX_PREVIEW_RATE 22050

function sid_defs_init()
{
    digi_defs_init();
    global.WAVE_NAMES = ["Triangle (soft)", "Sawtooth (buzzy)", "Pulse (classic)", "Noise (crunchy)",
                         "Pulse + triangle", "Pulse + sawtooth", "Sawtooth + triangle"];
    global.WAVE_SHORT = ["Triangle", "Sawtooth", "Pulse", "Noise", "Pulse+tri", "Pulse+saw", "Saw+tri"];
    // SID control register waveform bits ($D404): tri $10, saw $20, pulse $40, noise $80
    global.WAVE_BITS = [16, 32, 64, 128, 80, 96, 48];
    global.FILTER_NAMES = ["Off", "Low pass (dull, warm)", "Band pass (nasal)", "High pass (thin)"];
    global.VOICE_NAMES = ["Voice 1", "Voice 2"];
    global.SFX_PRESET_NAMES = ["Coin", "Laser", "Explosion", "Jump", "Hit", "Power up", "Lose", "Blip",
                               "Zap", "Chord", "Wind", "Drum"];
    // SID ADSR: attack time and decay / release time to silence for each 0..15 setting (ms)
    global.SID_ATK_MS = [2, 8, 16, 24, 38, 56, 68, 80, 100, 250, 500, 800, 1000, 3000, 5000, 8000];
    global.SID_DR_MS  = [6, 24, 48, 72, 114, 168, 204, 240, 300, 750, 1500, 2400, 3000, 9000, 15000, 24000];
    // ADSR rate counter periods in clock cycles (one envelope step each period)
    global.SID_RATE = [9, 32, 63, 95, 149, 220, 267, 313, 392, 977, 1954, 3126, 3907, 11720, 19532, 31251];
}

function sfx_new(_name)
{
    return {
        name : _name,
        group : -1,
        voice : 0,
        wave : 2,
        pitch : 60,
        sweep : 0,
        len : 10,
        atk : 0, dec : 8, sus : 0, rel : 6,
        pw : 2048,
        pws : 0,
        fmode : 0,
        fcut : 80,
        fres : 8,
        fsweep : 0,
        arp : false,
        arp1 : 4,
        arp2 : 7,
        // kind 1: a sample imported from a WAV (scr_digi), played through $D418
        kind : 0,
        smp : "",
        smp_rate : 0,
        smp_len : 0,
        smp_file : "",
        rate : 4000,
        bits : 4,
        gain : 100,
        trim_a : 0,
        trim_b : 1000
    };
}

/// Replaces every setting of sound _s (not its name, folder or voice) with preset _p
function sfx_apply_preset(_s, _p)
{
    //       wave pitch sweep len atk dec sus rel   pw   pws fmode fcut fres fsw  arp a1 a2
    var _t = [
        [2,  60,   6,   8,  0,  6,  0,  4,  2048,  0,  0,   80,  8,   0,  true,  5, 12],
        [5, 120,  -8,  12,  0,  8,  0,  6,  1024, 24,  0,   80,  8,   0,  false, 4, 7],
        [3,  40,  -1,  25,  0, 10,  0,  9,  2048,  0,  1,  160, 10,  -6,  false, 4, 7],
        [0,  30,   4,  14,  0,  7,  4,  5,  2048,  0,  0,   80,  8,   0,  false, 4, 7],
        [3,  14,   0,   6,  0,  5,  0,  3,  2048,  0,  1,   90,  4,   0,  false, 4, 7],
        [2,  40,   3,  30,  2,  6,  8,  6,  1024, 16,  0,   80,  8,   0,  true,  4, 7],
        [0,  50,  -2,  30,  0,  9,  6,  8,  2048,  0,  1,  120,  6,  -3,  false, 4, 7],
        [2,  90,   0,   3,  0,  3,  0,  2,  2048,  0,  0,   80,  8,   0,  false, 4, 7],
        [2,  70,  -3,  20,  0,  8,  4,  6,   256, 40,  0,   80,  8,   0,  false, 4, 7],
        [1,  34,   0,  40,  1,  8, 10,  8,  2048,  0,  1,  110, 12,   0,  true,  4, 7],
        [3,  60,   0, 120,  9, 10, 12, 11,  2048,  0,  2,   40, 15,   2,  false, 4, 7],
        [3,  26,  -1,   4,  0,  6,  0,  4,  2048,  0,  1,  200,  2,  -9,  false, 4, 7]
    ];
    var _v = _t[clamp(_p, 0, array_length(_t) - 1)];
    _s.wave = _v[0];
    _s.pitch = _v[1];
    _s.sweep = _v[2];
    _s.len = _v[3];
    _s.atk = _v[4];
    _s.dec = _v[5];
    _s.sus = _v[6];
    _s.rel = _v[7];
    _s.pw = _v[8];
    _s.pws = _v[9];
    _s.fmode = _v[10];
    _s.fcut = _v[11];
    _s.fres = _v[12];
    _s.fsweep = _v[13];
    _s.arp = _v[14];
    _s.arp1 = _v[15];
    _s.arp2 = _v[16];
}

/// The project's sounds, loaded from a file (older projects have 8 with fewer settings)
function sfx_list_from_loaded(_raw)
{
    var _out = [];
    if (is_array(_raw))
    {
        for (var i = 0; i < min(SFX_MAX, array_length(_raw)); i++)
        {
            var _s = struct_overlay(sfx_new("Sound " + string(i + 1)), _raw[i]);
            _s.wave = clamp(floor(_s.wave), 0, array_length(global.WAVE_BITS) - 1);
            _s.voice = clamp(floor(_s.voice), 0, 1);
            _s.fmode = clamp(floor(_s.fmode), 0, 3);
            if (!is_numeric(_s.group)) { _s.group = -1; }
            if (!is_bool(_s.arp)) { _s.arp = (_s.arp == 1); }
            if (!is_string(_s.smp) || !is_string(_s.smp_file) || !is_numeric(_s.kind))
            {
                _s.smp = "";
                _s.smp_file = "";
                _s.kind = 0;
            }
            _s.kind = clamp(floor(_s.kind), 0, 1);
            _s.rate = clamp(floor(_s.rate), 1000, 16000);
            _s.bits = clamp(floor(_s.bits), 2, 4);
            _s.gain = clamp(_s.gain, 10, 300);
            _s.trim_a = clamp(_s.trim_a, 0, 990);
            _s.trim_b = clamp(_s.trim_b, _s.trim_a + 10, 1000);
            array_push(_out, _s);
        }
    }
    if (array_length(_out) == 0)
    {
        for (var k = 0; k < 8; k++)
        {
            var _d = sfx_new(global.SFX_PRESET_NAMES[k]);
            sfx_apply_preset(_d, k);
            array_push(_out, _d);
        }
    }
    return _out;
}

/// Frames per second of the target machine (the player runs once a frame)
function sid_fps()
{
    if (machine_is_ntsc()) { return 60; }
    return 50;
}

function sid_clock()
{
    if (machine_is_ntsc()) { return SID_CLOCK_NTSC; }
    return SID_CLOCK_PAL;
}

/// SID frequency register -> Hz on the target machine
function sid_hz(_reg)
{
    return _reg * sid_clock() / 16777216;
}

/// Musical note name nearest to frequency hi byte _fh (e.g. "C-4")
function sid_note_name(_fh)
{
    var _hz = sid_hz(max(1, _fh) * 256);
    var _n = round(12 * log2(_hz / 440)) + 57;
    var _names = ["C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"];
    var _o = floor(_n / 12);
    var _i = _n - _o * 12;
    return _names[_i] + string(_o) + "  (" + string(round(_hz)) + " Hz)";
}

/// Arpeggio offsets (added to the pitch byte) for semitone steps _a, as the player uses them
function sid_arp_offset(_s, _semi)
{
    var _base = clamp(_s.pitch, 1, 255);
    var _up = round(_base * power(2, _semi / 12));
    return clamp(_up, 0, 255) - _base;
}

/// SID filter cutoff byte ($D416) -> Hz (close to the 8580; the 6581 varies chip to chip)
function sid_cutoff_hz(_c)
{
    return 30 + clamp(_c, 0, 255) * 8 * 5.8;
}

/// Seconds the preview of _s lasts (gate time + release, capped)
function sfx_seconds(_s)
{
    if (_s.kind == 1) { return sfx_digi_seconds(_s); }
    var _gate = max(1, _s.len - 1) / sid_fps();
    var _rel = global.SID_DR_MS[clamp(_s.rel, 0, 15)] / 1000;
    return min(_gate + _rel + 0.02, 4);
}

/// Renders sound _s exactly as the player drives the SID (per-frame updates, real ADSR
/// step rates, 24-bit oscillator, 23-bit noise LFSR, pulse width, the filter).
/// Returns a buffer of signed 16-bit samples at SFX_PREVIEW_RATE (caller deletes it).
function sfx_render(_s)
{
    if (_s.kind == 1) { return sfx_digi_render(_s); }
    var _rate = SFX_PREVIEW_RATE;
    var _clock = sid_clock();
    var _fps = sid_fps();
    var _n = max(64, floor(sfx_seconds(_s) * _rate));
    var _buf = buffer_create(_n * 2, buffer_fixed, 2);
    var _cyc = _clock / _rate;                       // SID cycles per output sample
    var _spf = _rate / _fps;                         // samples per frame
    var _wbits = global.WAVE_BITS[clamp(_s.wave, 0, array_length(global.WAVE_BITS) - 1)];

    // player state (as play_sfx leaves it)
    var _fh = clamp(_s.pitch, 1, 255);
    var _sw = clamp(_s.sweep, -8, 8);
    var _t = clamp(_s.len, 1, 200);
    var _pw = clamp(_s.pw, 0, 4095);
    var _pws = clamp(_s.pws, -64, 64);
    var _step = 0;
    var _a1 = sid_arp_offset(_s, _s.arp1);
    var _a2 = sid_arp_offset(_s, _s.arp2);
    var _fc = clamp(_s.fcut, 0, 255);
    var _fs = clamp(_s.fsweep, -9, 9);
    var _ft = _t + 25;
    var _gate = true;
    var _out_fh = _fh;

    // oscillator + noise + envelope state
    var _acc = 0;
    var _lfsr = 0x7ffff8;
    var _noise_out = 0;
    var _env = 0;
    var _env_state = 0;           // 0 attack, 1 decay / sustain, 2 release
    var _rate_cnt = 0;
    var _exp_cnt = 0;
    var _sus_lvl = clamp(_s.sus, 0, 15) * 17;
    var _ra = global.SID_RATE[clamp(_s.atk, 0, 15)];
    var _rd = global.SID_RATE[clamp(_s.dec, 0, 15)];
    var _rr = global.SID_RATE[clamp(_s.rel, 0, 15)];

    // filter (2x oversampled state variable)
    var _lp = 0;
    var _bp = 0;
    var _q = 1 / (0.707 + clamp(_s.fres, 0, 15) / 15 * 2.2);
    var _filt_on = (_s.fmode > 0);

    var _outs = array_create(_n, 0);
    var _peak = 0;
    var _frame = -1;
    for (var i = 0; i < _n; i++)
    {
        // ---- the player's frame update (runs at the start of every frame, as in the game) ----
        var _f = floor(i / _spf);
        if (_f != _frame)
        {
            _frame = _f;
            if (_t > 0)
            {
                _fh = clamp(_fh + _sw, 0, 255);
                _out_fh = _fh;
                if (_s.arp)
                {
                    _step += 1;
                    if (_step >= 3) { _step = 0; }
                    if (_step == 1) { _out_fh = (_fh + _a1) & 255; }
                    if (_step == 2) { _out_fh = (_fh + _a2) & 255; }
                }
                if (_pws != 0) { _pw = (_pw + _pws) & 4095; }
                _t -= 1;
                if (_t == 0) { _gate = false; }
            }
            if (_filt_on && _ft > 0)
            {
                _ft -= 1;
                _fc = clamp(_fc + _fs, 0, 255);
            }
        }

        // ---- oscillator (24-bit phase accumulator) ----
        var _prev = _acc;
        _acc = (_acc + _out_fh * 256 * _cyc) mod 16777216;
        // noise: the LFSR is clocked each time bit 19 rises
        if ((_wbits & 128) != 0)
        {
            var _clocks = floor((_acc + 524288) / 1048576) - floor((_prev + 524288) / 1048576);
            if (_clocks < 0) { _clocks += 16; }
            for (var c = 0; c < _clocks; c++)
            {
                var _bit = ((_lfsr >> 22) ^ (_lfsr >> 17)) & 1;
                _lfsr = ((_lfsr << 1) | _bit) & 0x7fffff;
            }
            _noise_out = (((_lfsr >> 20) & 1) << 7) | (((_lfsr >> 18) & 1) << 6) | (((_lfsr >> 14) & 1) << 5) | (((_lfsr >> 11) & 1) << 4)
                       | (((_lfsr >> 9) & 1) << 3) | (((_lfsr >> 5) & 1) << 2) | (((_lfsr >> 2) & 1) << 1) | (_lfsr & 1);
        }
        var _a12 = floor(_acc / 4096);              // top 12 bits
        var _w = 4095;
        var _any = false;
        if ((_wbits & 16) != 0)
        {
            var _tri = _a12 * 2;
            if (_a12 >= 2048) { _tri = (4095 - _a12) * 2; }
            _w = _w & clamp(_tri, 0, 4095);
            _any = true;
        }
        if ((_wbits & 32) != 0) { _w = _w & _a12; _any = true; }
        if ((_wbits & 64) != 0)
        {
            if (_a12 >= _pw) { _w = _w & 4095; }
            else { _w = 0; }
            _any = true;
        }
        if ((_wbits & 128) != 0) { _w = _w & (_noise_out << 4); _any = true; }
        if (!_any) { _w = 2048; }
        var _v = _w / 2047.5 - 1;

        // ---- ADSR (real step rates; decay and release slow down as the level falls) ----
        if (!_gate && _env_state != 2) { _env_state = 2; }
        var _period = _ra;
        if (_env_state == 1) { _period = _rd; }
        if (_env_state == 2) { _period = _rr; }
        _rate_cnt += _cyc;
        while (_rate_cnt >= _period)
        {
            _rate_cnt -= _period;
            if (_env_state == 0)
            {
                _env += 1;
                if (_env >= 255) { _env = 255; _env_state = 1; }
            }
            else
            {
                var _div = 1;
                if (_env < 94) { _div = 2; }
                if (_env < 55) { _div = 4; }
                if (_env < 27) { _div = 8; }
                if (_env < 15) { _div = 16; }
                if (_env < 7) { _div = 30; }
                _exp_cnt += 1;
                if (_exp_cnt >= _div)
                {
                    _exp_cnt = 0;
                    if (_env_state == 1)
                    {
                        if (_env > _sus_lvl) { _env -= 1; }
                    }
                    else
                    {
                        if (_env > 0) { _env -= 1; }
                    }
                }
            }
        }
        var _o = _v * (_env / 255);

        // ---- filter ----
        if (_filt_on)
        {
            var _hz = min(sid_cutoff_hz(_fc), _rate * 0.45);
            var _k = 2 * sin(pi * _hz / (_rate * 2));
            var _hp = 0;
            for (var os = 0; os < 2; os++)
            {
                _hp = _o - _lp - _q * _bp;
                _bp += _k * _hp;
                _lp += _k * _bp;
            }
            if (_s.fmode == 1) { _o = _lp; }
            if (_s.fmode == 2) { _o = _bp; }
            if (_s.fmode == 3) { _o = _hp; }
        }
        _outs[i] = _o * 0.42;
        _peak = max(_peak, abs(_outs[i]));
    }
    // a ringing filter can go over full scale: turn it down to a peak of 0.9 rather than clip
    var _gain = 1;
    if (_peak > 0.9) { _gain = 0.9 / _peak; }
    for (var j = 0; j < _n; j++)
    {
        buffer_write(_buf, buffer_s16, round(clamp(_outs[j] * _gain, -1, 1) * 32000));
    }
    return _buf;
}

/// Stable text key of every setting that changes the sound (to know when a render is stale)
function sfx_key(_s)
{
    if (_s.kind == 1) { return "digi|" + digi_key(_s); }
    return string(_s.wave) + "," + string(_s.pitch) + "," + string(_s.sweep) + "," + string(_s.len) + ","
         + string(_s.atk) + string(_s.dec) + string(_s.sus) + string(_s.rel) + "," + string(_s.pw) + "," + string(_s.pws) + ","
         + string(_s.fmode) + "," + string(_s.fcut) + "," + string(_s.fres) + "," + string(_s.fsweep) + ","
         + string(_s.arp) + string(_s.arp1) + "," + string(_s.arp2) + "," + string(sid_fps());
}

// ---------------------------------------------------------------------------
// 6502 side. Tables are one byte per sound; the player state is indexed by the
// voice's SID register offset (0 = voice 1 at $D400, 7 = voice 2 at $D407).
// ---------------------------------------------------------------------------

/// Pushes the sound tables, the player and its variables onto L.
/// play_sfx: A = sound number (anything >= the number of sounds plays nothing). X and Y are kept.
/// sfx_update: once a frame (it runs the music driver too). sfx_stop: silences both voices. sfx_init: once at start.
/// rnd: a random byte in A.
function sid_emit(L, _p)
{
    var _ns = max(1, min(SFX_MAX, array_length(_p.sfx)));
    var _v = "", _ad = "", _sr = "", _f = "", _sw = "", _len = "", _w = "";
    var _pwl = "", _pwh = "", _pws = "", _fm = "", _fr = "", _fc = "", _fsw = "", _a1 = "", _a2 = "";
    for (var i = 0; i < _ns; i++)
    {
        var _s = _p.sfx[min(i, array_length(_p.sfx) - 1)];
        var _sep = ",";
        if (i == 0) { _sep = ""; }
        var _pw = clamp(_s.pw, 0, 4095);
        var _vo = 0;
        if (_s.voice == 1) { _vo = 7; }
        _v += _sep + string(_vo);
        _ad += _sep + string((clamp(_s.atk, 0, 15) << 4) | clamp(_s.dec, 0, 15));
        _sr += _sep + string((clamp(_s.sus, 0, 15) << 4) | clamp(_s.rel, 0, 15));
        _f += _sep + string(clamp(_s.pitch, 1, 255));
        _sw += _sep + string(clamp(_s.sweep, -8, 8) & 255);
        _len += _sep + string(clamp(_s.len, 1, 200));
        _w += _sep + string(global.WAVE_BITS[clamp(_s.wave, 0, array_length(global.WAVE_BITS) - 1)]);
        _pwl += _sep + string(_pw & 255);
        _pwh += _sep + string(_pw >> 8);
        _pws += _sep + string(clamp(_s.pws, -64, 64) & 255);
        var _mode = 0;
        if (_s.fmode > 0) { _mode = 0x0f | (8 << clamp(_s.fmode, 1, 3)); }   // LP $10, BP $20, HP $40 + volume 15 (voice 3 stays on: it plays music)
        _fm += _sep + string(_mode);
        _fr += _sep + string(clamp(_s.fres, 0, 15) << 4);
        _fc += _sep + string(clamp(_s.fcut, 0, 255));
        _fsw += _sep + string(clamp(_s.fsweep, -9, 9) & 255);
        var _o1 = 0;
        var _o2 = 0;
        if (_s.arp)
        {
            _o1 = sid_arp_offset(_s, _s.arp1);
            _o2 = sid_arp_offset(_s, _s.arp2);
        }
        _a1 += _sep + string(_o1 & 255);
        _a2 += _sep + string(_o2 & 255);
    }
    var _arp_on = "";
    for (var j = 0; j < _ns; j++)
    {
        var _sa = 0;
        if (_p.sfx[min(j, array_length(_p.sfx) - 1)].arp) { _sa = 1; }
        if (j > 0) { _arp_on += ","; }
        _arp_on += string(_sa);
    }

    array_push(L, "; ---------------- SID sound player (voices 1 and 2; the music driver has all 3 when they are free) ----------------");
    array_push(L, "SFX_N = " + string(_ns));
    array_push(L, "sid_start:");
    var _dg = digi_any(_p);
    array_push(L, "sfx_init:", " lda #0", " sta $d417", " sta sid_d417", " sta sid_mode", " sta sv_t", " sta sv_t+7", " sta flt_t", " lda #$0f", " sta $d418");
    if (_dg)
    {
        // samples: CIA 2 timer A interrupts off for now, and the NMI pointed at the sample player
        // (through $0318 when the KERNAL is in, straight from $FFFA when it is banked out)
        array_push(L, " lda #$7f", " sta $dd0d", " lda #0", " sta $dd0e", " lda $dd0d");
        array_push(L, " lda #<sid_nmi", " sta $0318", " sta $fffa", " lda #>sid_nmi", " sta $0319", " sta $fffb");
        // a sample (Y = sound): stop the one playing, point the NMI at the new one, start the timer
        array_push(L, " rts", "sidp_dg:", " lda #$7f", " sta $dd0d", " lda #0", " sta $dd0e", " sta dg_nib");
        array_push(L, " lda sfxt_dal,y", " sta dgn_a1+1", " sta dgn_a2+1", " lda sfxt_dah,y", " sta dgn_a1+2", " sta dgn_a2+2");
        array_push(L, " lda sfxt_dnl,y", " sta dg_cl", " lda sfxt_dnh,y", " sta dg_ch", " lda sfxt_dtl,y", " sta $dd04", " lda sfxt_dth,y", " sta $dd05");
        array_push(L, " lda $dd0d", " lda #$81", " sta $dd0d", " lda #$11", " sta $dd0e", " ldx sid_sx", " ldy sid_sy");
    }
    array_push(L, " rts");
    array_push(L, "play_sfx:", " cmp #SFX_N", " bcc sidp_go", " rts");
    array_push(L, "sidp_go:", " stx sid_sx", " sty sid_sy", " tay");
    if (_dg) { array_push(L, " lda sfxt_dg,y", " bne sidp_dg"); }
    array_push(L, " ldx sfxt_v,y");
    array_push(L, " lda #0", " sta sv_t,x", " sta $d404,x", " sta $d400,x", " sta sv_step,x");
    array_push(L, " lda sfxt_ad,y", " sta $d405,x", " lda sfxt_sr,y", " sta $d406,x");
    array_push(L, " lda sfxt_pwl,y", " sta sv_pwl,x", " sta $d402,x", " lda sfxt_pwh,y", " sta sv_pwh,x", " sta $d403,x");
    array_push(L, " lda sfxt_pws,y", " sta sv_pws,x", " lda sfxt_sw,y", " sta sv_sw,x");
    array_push(L, " lda sfxt_f,y", " sta sv_fh,x", " sta $d401,x", " tya", " sta sv_snd,x");
    // filter: a filtered sound takes the filter; an unfiltered one takes its voice out of it
    array_push(L, " lda sfxt_fm,y", " beq sidp_nf", " sta $d418", " and #$f0", " sta sid_mode", " lda sfxt_fr,y", " ora sid_vbit,x", " sta sid_d417", " sta $d417");
    array_push(L, " lda sfxt_fc,y", " sta flt_c", " sta $d416", " lda #0", " sta $d415", " lda sfxt_fsw,y", " sta flt_s");
    array_push(L, " lda sfxt_len,y", " clc", " adc #25", " sta flt_t", " jmp sidp_g");
    array_push(L, "sidp_nf:", " lda sid_d417", " and sid_vmask,x", " sta sid_d417", " sta $d417");
    array_push(L, "sidp_g:", " lda sfxt_w,y", " sta sv_w,x", " ora #1", " sta $d404,x", " lda sfxt_len,y", " sta sv_t,x");
    array_push(L, " ldx sid_sx", " ldy sid_sy", " rts");

    array_push(L, "sfx_update:", " stx sid_sx", " sty sid_sy", " ldx #0", " jsr sidu_v", " ldx #7", " jsr sidu_v");
    // filter sweep, clamped at 0 and 255
    array_push(L, " lda flt_t", " beq sidu_r", " dec flt_t", " lda flt_s", " beq sidu_r", " bmi sidu_fn");
    array_push(L, " clc", " adc flt_c", " bcc sidu_fs", " lda #255", " jmp sidu_fs");
    array_push(L, "sidu_fn:", " clc", " adc flt_c", " bcs sidu_fs", " lda #0");
    array_push(L, "sidu_fs:", " sta flt_c", " sta $d416");
    array_push(L, "sidu_r:", " jsr mus_update", " ldx sid_sx", " ldy sid_sy", " rts");
    // one voice: pitch slide (clamped), arpeggio, pulse width sweep, gate off at the end
    array_push(L, "sidu_v:", " lda sv_t,x", " bne sidu_on", " rts");
    array_push(L, "sidu_on:", " lda sv_sw,x", " beq sidu_ps", " bmi sidu_sn");
    array_push(L, " clc", " adc sv_fh,x", " bcc sidu_sv", " lda #255", " jmp sidu_sv");
    array_push(L, "sidu_sn:", " clc", " adc sv_fh,x", " bcs sidu_sv", " lda #0");
    array_push(L, "sidu_sv:", " sta sv_fh,x");
    array_push(L, "sidu_ps:", " ldy sv_snd,x", " lda sfxt_arp,y", " beq sidu_na");
    array_push(L, " inc sv_step,x", " lda sv_step,x", " cmp #3", " bcc sidu_s1", " lda #0", " sta sv_step,x");
    array_push(L, "sidu_s1:", " cmp #1", " beq sidu_o1", " cmp #2", " bne sidu_na", " lda sfxt_a2,y", " jmp sidu_oa");
    array_push(L, "sidu_o1:", " lda sfxt_a1,y");
    array_push(L, "sidu_oa:", " clc", " adc sv_fh,x", " jmp sidu_fq");
    array_push(L, "sidu_na:", " lda sv_fh,x");
    array_push(L, "sidu_fq:", " sta $d401,x");
    array_push(L, " lda sv_pws,x", " beq sidu_np", " bmi sidu_pn");
    array_push(L, " clc", " adc sv_pwl,x", " sta sv_pwl,x", " lda sv_pwh,x", " adc #0", " jmp sidu_pq");
    array_push(L, "sidu_pn:", " clc", " adc sv_pwl,x", " sta sv_pwl,x", " lda sv_pwh,x", " adc #$ff");
    array_push(L, "sidu_pq:", " and #$0f", " sta sv_pwh,x", " sta $d403,x", " lda sv_pwl,x", " sta $d402,x");
    array_push(L, "sidu_np:", " dec sv_t,x", " bne sidu_x", " lda sv_w,x", " and #$fe", " sta $d404,x");
    // the sound is done: its voice leaves the filter (the music gets it back clean)
    array_push(L, " lda sid_d417", " and sid_vmask,x", " sta sid_d417", " sta $d417");
    array_push(L, "sidu_x:", " rts");
    array_push(L, "sfx_stop:", " lda #0", " sta sv_t", " sta sv_t+7", " sta flt_t", " sta $d404", " sta $d40b");
    if (_dg) { array_push(L, " lda #$7f", " sta $dd0d", " lda #0", " sta $dd0e", " lda sid_mode", " ora #$0f", " sta $d418"); }
    array_push(L, " rts");
    if (_dg)
    {
        // the sample player: one NMI per sample, the high then the low nibble of each byte,
        // written to the SID volume (the filter mode bits in the top nibble are kept)
        array_push(L, "sid_nmi:", " pha", " lda $dd0d", " lda dg_nib", " bne dgn_lo", " inc dg_nib");
        array_push(L, "dgn_a1:", " lda $1000", " lsr", " lsr", " lsr", " lsr", " ora sid_mode", " sta $d418", " pla", " rti");
        array_push(L, "dgn_lo:", " lda #0", " sta dg_nib");
        array_push(L, "dgn_a2:", " lda $1000", " and #$0f", " ora sid_mode", " sta $d418");
        array_push(L, " inc dgn_a1+1", " inc dgn_a2+1", " bne dgn_c", " inc dgn_a1+2", " inc dgn_a2+2");
        array_push(L, "dgn_c:", " lda dg_cl", " bne dgn_d", " dec dg_ch");
        array_push(L, "dgn_d:", " dec dg_cl", " lda dg_cl", " ora dg_ch", " bne dgn_x");
        // the end: timer off, full volume back
        array_push(L, " lda #$7f", " sta $dd0d", " lda #0", " sta $dd0e", " lda sid_mode", " ora #$0f", " sta $d418");
        array_push(L, "dgn_x:", " pla", " rti");
    }

    // rnd: a random byte in A (16-bit LFSR mixed with the raster line; X and Y kept).
    // The SID's voice 3 noise ($D41B) can't be used: voice 3 plays music.
    array_push(L, "rnd:", " lda rnd_s", " asl", " rol rnd_s+1", " bcc sidr_n", " eor #$39", "sidr_n:", " sta rnd_s", " eor rnd_s+1", " eor $d012", " rts");
    array_push(L, "sid_vbit:", " .byte 1,0,0,0,0,0,0,2");
    array_push(L, "sid_vmask:", " .byte $fe,0,0,0,0,0,0,$fd");
    array_push(L, "sfxt_v:", " .byte " + _v, "sfxt_ad:", " .byte " + _ad, "sfxt_sr:", " .byte " + _sr);
    array_push(L, "sfxt_f:", " .byte " + _f, "sfxt_sw:", " .byte " + _sw, "sfxt_len:", " .byte " + _len, "sfxt_w:", " .byte " + _w);
    array_push(L, "sfxt_pwl:", " .byte " + _pwl, "sfxt_pwh:", " .byte " + _pwh, "sfxt_pws:", " .byte " + _pws);
    array_push(L, "sfxt_fm:", " .byte " + _fm, "sfxt_fr:", " .byte " + _fr, "sfxt_fc:", " .byte " + _fc, "sfxt_fsw:", " .byte " + _fsw);
    array_push(L, "sfxt_arp:", " .byte " + _arp_on, "sfxt_a1:", " .byte " + _a1, "sfxt_a2:", " .byte " + _a2);
    var _vars = ["sv_t", "sv_fh", "sv_sw", "sv_w", "sv_snd", "sv_step", "sv_pwl", "sv_pwh", "sv_pws"];
    for (var k = 0; k < array_length(_vars); k++) { array_push(L, _vars[k] + ":", " .fill 8,0"); }
    array_push(L, "flt_c:", " .fill 1,0", "flt_s:", " .fill 1,0", "flt_t:", " .fill 1,0", "sid_d417:", " .fill 1,0");
    array_push(L, "sid_sx:", " .fill 1,0", "sid_sy:", " .fill 1,0", "rnd_s:", " .byte $5a,$c3", "sid_mode:", " .fill 1,0");
    if (_dg)
    {
        // per sound: is it a sample, where its data is, how many bytes, the CIA timer value
        var _t = [[], [], [], [], [], [], []];
        for (var d = 0; d < _ns; d++)
        {
            var _di = min(d, array_length(_p.sfx) - 1);
            var _sd = _p.sfx[_di];
            if (_sd.kind == 1)
            {
                var _lv = digi_levels(_sd);
                var _nb = max(1, array_length(_lv.nib) div 2);
                var _lab = "sdig_" + string(_di);
                array_push(_t[0], "1");
                array_push(_t[1], "<" + _lab);
                array_push(_t[2], ">" + _lab);
                array_push(_t[3], string(_nb & 255));
                array_push(_t[4], string(_nb >> 8));
                array_push(_t[5], string(_lv.latch & 255));
                array_push(_t[6], string(_lv.latch >> 8));
            }
            else
            {
                for (var z = 0; z < 7; z++) { array_push(_t[z], "0"); }
            }
        }
        var _tn = ["sfxt_dg", "sfxt_dal", "sfxt_dah", "sfxt_dnl", "sfxt_dnh", "sfxt_dtl", "sfxt_dth"];
        for (var q = 0; q < 7; q++) { array_push(L, _tn[q] + ":", " .byte " + string_join_ext(",", _t[q])); }
        array_push(L, "dg_nib:", " .fill 1,0", "dg_cl:", " .fill 1,0", "dg_ch:", " .fill 1,0");
    }
    array_push(L, "sid_end:");
}
