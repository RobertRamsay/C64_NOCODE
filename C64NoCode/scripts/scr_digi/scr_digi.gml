/// C64 ENGINE - sampled sounds ("digis"), ported from ADAM's Sound page sample import.
/// A WAV is kept as an 8-bit mono source (up to 22 kHz, 5 seconds). The C64 plays it the classic
/// way: a CIA 2 timer fires an NMI a few thousand times a second and each NMI writes the next
/// 4-bit sample to the SID's master volume ($D418, low nibble). Two samples are packed in a byte.
/// The SID's voices are not used, so a sample plays alongside sound effects and music - but they
/// share the volume register, so while it plays they rise and fall with it (as in every C64
/// game that talks). The newer 8580 SID plays $D418 samples very quietly; the 6581, VICE's
/// default and the C64 Ultimate's 6581 mode play them loud.

#macro DIGI_SRC_MAX_RATE 22050
#macro DIGI_SRC_MAX_SECONDS 5
#macro DIGI_MAX_BYTES 16384
#macro DIGI_NMI_CYCLES 66          // an NMI: entry, the handler's average path and RTI (plus the KERNAL hop)

function digi_defs_init()
{
    global.DIGI_RATES = [2000, 3000, 4000, 5000, 6000, 8000];
    global.DIGI_RATE_NAMES = ["2000 Hz  (very crunchy)", "3000 Hz", "4000 Hz  (classic C64 speech)", "5000 Hz", "6000 Hz", "8000 Hz  (clearest, busiest)"];
    global.DIGI_BITS = [4, 3, 2];
    global.DIGI_BIT_NAMES = ["4-bit  (all $D418 has)", "3-bit  (gritty)", "2-bit  (crushed)"];
    global.digi_cache = {};
    global.digi_cache_n = 0;
}

/// Reads a .WAV file into sound _s (8, 16, 24 or 32-bit, PCM or float, mono or stereo, any rate):
/// mixed to mono, resampled to at most 22 kHz, the first 5 seconds kept, normalised. (ADAM's sfx_import_wav)
function sfx_import_wav(_s, _path)
{
    var _b = buffer_load(_path);
    if (_b == -1) { return false; }
    var _size = buffer_get_size(_b);
    if (_size < 44)
    {
        buffer_delete(_b);
        return false;
    }
    var _riff = chr(buffer_peek(_b, 0, buffer_u8)) + chr(buffer_peek(_b, 1, buffer_u8)) + chr(buffer_peek(_b, 2, buffer_u8)) + chr(buffer_peek(_b, 3, buffer_u8));
    var _wave = chr(buffer_peek(_b, 8, buffer_u8)) + chr(buffer_peek(_b, 9, buffer_u8)) + chr(buffer_peek(_b, 10, buffer_u8)) + chr(buffer_peek(_b, 11, buffer_u8));
    if (_riff != "RIFF" || _wave != "WAVE")
    {
        buffer_delete(_b);
        return false;
    }
    var _fmt = 0;
    var _ch = 0;
    var _rate = 0;
    var _bits = 0;
    var _data = -1;
    var _dlen = 0;
    var _o = 12;
    while (_o + 8 <= _size)
    {
        var _id = chr(buffer_peek(_b, _o, buffer_u8)) + chr(buffer_peek(_b, _o + 1, buffer_u8)) + chr(buffer_peek(_b, _o + 2, buffer_u8)) + chr(buffer_peek(_b, _o + 3, buffer_u8));
        var _len = buffer_peek(_b, _o + 4, buffer_u32);
        if (_id == "fmt ")
        {
            _fmt = buffer_peek(_b, _o + 8, buffer_u16);
            _ch = buffer_peek(_b, _o + 10, buffer_u16);
            _rate = buffer_peek(_b, _o + 12, buffer_u32);
            _bits = buffer_peek(_b, _o + 22, buffer_u16);
            if (_fmt == 65534 && _len >= 26) { _fmt = buffer_peek(_b, _o + 32, buffer_u16); }
        }
        if (_id == "data")
        {
            _data = _o + 8;
            _dlen = min(_len, _size - _data);
        }
        _o += 8 + _len + (_len mod 2);
    }
    var _bps = _bits div 8;
    if (_data < 0 || _ch < 1 || _rate < 1000 || _bps < 1 || _bps > 4 || (_fmt != 1 && _fmt != 3))
    {
        buffer_delete(_b);
        return false;
    }
    var _frames = _dlen div (_bps * _ch);
    // only what will be kept is read
    _frames = min(_frames, ceil(DIGI_SRC_MAX_SECONDS * _rate) + 2);
    var _src = array_create(_frames, 0);
    var _peak = 0.0001;
    for (var f = 0; f < _frames; f++)
    {
        var _sum = 0;
        for (var c = 0; c < _ch; c++)
        {
            var _p = _data + (f * _ch + c) * _bps;
            var _v = 0;
            switch (_bps)
            {
                case 1: _v = (buffer_peek(_b, _p, buffer_u8) - 128) / 128; break;
                case 2: _v = buffer_peek(_b, _p, buffer_s16) / 32768; break;
                case 3:
                    var _w = buffer_peek(_b, _p, buffer_u8) | (buffer_peek(_b, _p + 1, buffer_u8) << 8) | (buffer_peek(_b, _p + 2, buffer_u8) << 16);
                    if (_w >= 8388608) { _w -= 16777216; }
                    _v = _w / 8388608;
                    break;
                case 4:
                    if (_fmt == 3) { _v = buffer_peek(_b, _p, buffer_f32); }
                    else { _v = buffer_peek(_b, _p, buffer_s32) / 2147483648; }
                    break;
            }
            _sum += _v;
        }
        _src[f] = _sum / _ch;
        _peak = max(_peak, abs(_src[f]));
    }
    buffer_delete(_b);
    var _nrate = min(_rate, DIGI_SRC_MAX_RATE);
    var _step = _rate / _nrate;
    var _n = min(floor(_frames / _step), DIGI_SRC_MAX_SECONDS * _nrate);
    if (_n < 2) { return false; }
    var _ob = buffer_create(_n, buffer_fixed, 1);
    for (var i = 0; i < _n; i++)
    {
        var _pos = i * _step;
        var _i0 = floor(_pos);
        var _fr = _pos - _i0;
        var _a0 = _src[min(_i0, _frames - 1)];
        var _a1 = _src[min(_i0 + 1, _frames - 1)];
        var _val = (_a0 + (_a1 - _a0) * _fr) / _peak;
        buffer_write(_ob, buffer_s8, clamp(round(_val * 127), -127, 127));
    }
    _s.smp = buffer_base64_encode(_ob, 0, _n);
    buffer_delete(_ob);
    _s.smp_rate = _nrate;
    _s.smp_len = _n;
    _s.smp_file = filename_name(_path);
    _s.kind = 1;
    _s.trim_a = 0;
    _s.trim_b = 1000;
    _s.gain = 100;
    _s.name = string_copy(filename_change_ext(filename_name(_path), ""), 1, 16);
    return true;
}

function digi_key(_s)
{
    return string(_s.rate) + "|" + string(_s.bits) + "|" + string(_s.gain) + "|" + string(_s.trim_a) + "|" + string(_s.trim_b) + "|"
         + string(_s.smp_len) + "|" + _s.smp_file + "|" + string(string_length(_s.smp)) + "|" + string(sid_clock());
}

/// The sample as the C64 plays it: { nib : 4-bit levels 0..15, rate : the real NMI rate,
/// latch : the CIA timer value, capped : cut to fit }. Cached.
function digi_levels(_s)
{
    var _key = digi_key(_s);
    var _hit = global.digi_cache[$ _key];
    if (!is_undefined(_hit)) { return _hit; }
    var _latch = clamp(round(sid_clock() / max(1000, _s.rate)) - 1, 60, 65535);
    var _rate = sid_clock() / (_latch + 1);
    var _res = { nib : [], rate : _rate, latch : _latch, capped : false };
    if (_s.smp != "" && _s.smp_len >= 2)
    {
        var _buf = buffer_base64_decode(_s.smp);
        var _n = min(_s.smp_len, buffer_get_size(_buf));
        var _a = floor(_n * clamp(_s.trim_a, 0, 1000) / 1000);
        var _b = floor(_n * clamp(_s.trim_b, 0, 1000) / 1000);
        if (_b > _a + 1)
        {
            var _step = _s.smp_rate / _rate;
            var _len = floor((_b - _a) / _step);
            if (_len > DIGI_MAX_BYTES * 2)
            {
                _len = DIGI_MAX_BYTES * 2;
                _res.capped = true;
            }
            _len -= _len mod 2;
            var _out = array_create(_len, 8);
            var _gain = _s.gain / 100;
            var _q = 1 << (4 - clamp(_s.bits, 1, 4));
            for (var i = 0; i < _len; i++)
            {
                // averaged over the step (a little low-pass, so the crunch is not all aliasing)
                var _p0 = _a + i * _step;
                var _acc = 0;
                var _cnt = 0;
                for (var k = floor(_p0); k < min(_n, floor(_p0 + _step)); k++)
                {
                    _acc += buffer_peek(_buf, k, buffer_s8);
                    _cnt += 1;
                }
                if (_cnt == 0) { _acc = buffer_peek(_buf, min(floor(_p0), _n - 1), buffer_s8); _cnt = 1; }
                var _v = clamp(_acc / _cnt * _gain, -128, 127);
                var _lv = clamp(floor((_v + 128) / 16), 0, 15);
                if (_q > 1) { _lv = floor(_lv / _q) * _q + floor(_q / 2); }
                _out[i] = clamp(_lv, 0, 15);
            }
            _res.nib = _out;
        }
        buffer_delete(_buf);
    }
    global.digi_cache_n += 1;
    if (global.digi_cache_n > 24)
    {
        global.digi_cache = {};
        global.digi_cache_n = 1;
    }
    global.digi_cache[$ _key] = _res;
    return _res;
}

/// Bytes the sample takes on the C64 (2 samples a byte)
function digi_bytes(_s)
{
    return array_length(digi_levels(_s).nib) div 2;
}

/// Share of the C64's time the NMIs take while the sample plays (0..1)
function digi_cpu(_s)
{
    return digi_levels(_s).rate * DIGI_NMI_CYCLES / sid_clock();
}

function sfx_digi_seconds(_s)
{
    var _d = digi_levels(_s);
    return array_length(_d.nib) / max(1, _d.rate);
}

/// The preview: the 4-bit levels held for their time, as the volume register steps
function sfx_digi_render(_s)
{
    var _d = digi_levels(_s);
    var _rate = SFX_PREVIEW_RATE;
    var _n = max(64, floor(array_length(_d.nib) / max(1, _d.rate) * _rate) + 64);
    var _buf = buffer_create(_n * 2, buffer_fixed, 2);
    var _m = array_length(_d.nib);
    for (var i = 0; i < _n; i++)
    {
        var _k = floor(i * _d.rate / _rate);
        var _v = 0;
        if (_k < _m) { _v = (_d.nib[_k] - 7.5) / 7.5; }
        buffer_write(_buf, buffer_s16, round(_v * 0.9 * 32000));
    }
    return _buf;
}

/// Pushes the packed sample data (high nibble first) for every sampled sound of _p onto L
function digi_emit(L, _p)
{
    array_push(L, "; ---------------- samples: 4-bit, 2 a byte, played through $D418 by the NMI ----------------", "dig_start:");
    for (var i = 0; i < min(SFX_MAX, array_length(_p.sfx)); i++)
    {
        var _s = _p.sfx[i];
        if (_s.kind != 1) { continue; }
        var _nib = digi_levels(_s).nib;
        array_push(L, "sdig_" + string(i) + ":");
        var _row = "";
        var _cnt = 0;
        for (var k = 0; k + 1 < array_length(_nib); k += 2)
        {
            if (_cnt > 0) { _row += ","; }
            _row += string((_nib[k] << 4) | _nib[k + 1]);
            _cnt += 1;
            if (_cnt == 32)
            {
                array_push(L, " .byte " + _row);
                _row = "";
                _cnt = 0;
            }
        }
        if (_cnt > 0) { array_push(L, " .byte " + _row); }
        if (array_length(_nib) < 2) { array_push(L, " .byte $88"); }
    }
    array_push(L, "dig_end:");
}

/// True when project _p has a sampled sound
function digi_any(_p)
{
    for (var i = 0; i < min(SFX_MAX, array_length(_p.sfx)); i++)
    {
        if (_p.sfx[i].kind == 1) { return true; }
    }
    return false;
}
