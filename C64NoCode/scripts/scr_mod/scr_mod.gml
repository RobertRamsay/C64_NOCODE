/// C64 ENGINE - ProTracker .MOD import and save (Music page), ported from ADAM's scr_mod.
/// The file side (mod_write / mod_parse / mod_read / mod_save_file, the neutral "modsong" struct
/// { title, samples[31], order[], restart, patterns[][64][4] { note, sample, effect, param } })
/// is ADAM's, unchanged. What is new is the C64 side:
///   music_mod_import(_ms, _fname) - a MOD becomes a 3-voice SID song: the 3 busiest of its 4
///       channels become voices 1-3, each 64-row pattern becomes bars of loops, its samples
///       become SID instruments (drums by name or by sound, the rest by pitch range), and
///       0xy / 1xx / 2xx / 3xx / 4xy / Cxx / ECx / Fxx / Bxx / Dxx are turned into chords,
///       slides, glides, vibrato, note ends, tempo, the loop point and shortened patterns.
///   music_mod_export(_song) - a song becomes a 4-channel MOD (channel 4 stays empty, as the SID
///       has 3 voices): one row per step, 2 bars a pattern, each SID instrument rendered by the
///       preview synth into an 8-bit sample (looped while it sustains), effects as above.
/// Samples can't be played by the SID, so they never come in as sound - only as a choice of
/// instrument. The original file layout notes follow.
///
/// File layout written (standard 4-channel 31-sample ProTracker module, big-endian):
///   0     20 bytes  title (ASCII, zero padded)
///   20    31 x 30   sample headers: 22 name, word length (words), byte finetune
///                   (low nibble, two's complement -8..7), byte volume 0..64,
///                   word loop start (words), word loop length (words, 1 = no loop)
///   950   byte      song length (1..128)
///   951   byte      restart: the modsong restart position when it is 1..songlen-1,
///                   otherwise 127 (what ProTracker itself writes; restart 0)
///   952   128 bytes order table (unused entries 0)
///   1080  "M.K."    ("M!K!" only if more than 64 patterns are needed)
///   1084  patterns  64 rows x 4 channels x 4 bytes:
///                   [sample hi nibble | period bits 11-8] [period bits 7-0]
///                   [sample lo nibble | effect] [param]
///   then  samples   signed 8-bit, in sample order
///
/// Conventions:
///   - Pattern count = highest pattern index in the order table + 1 (that is how
///     ProTracker and every player count them); patterns not in the order table
///     beyond that are not written, missing ones are written empty.
///   - Sample lengths are padded to an even byte count with 0 and capped at
///     65535 words (131070 bytes).
///   - A sample with no loop is written with loop start 0, loop length 1 word,
///     and its first two bytes forced to 0: Paula keeps repeating that first word
///     after a one-shot sample ends, so it must be silent. A loop must be at least
///     2 words (4 bytes) long - a 1-word loop means "no loop" in a MOD.
///   - Notes 1..36 = C-1..B-3 at finetune 0 (periods 856..113). Reading maps any
///     period to the nearest of those 36 (so finetuned periods and the odd
///     out-of-range period still land on a sensible note). Effects and params are
///     kept exactly as stored.

#macro MOD_HEADER_SIZE 1084
#macro MOD_PATTERN_SIZE 1024
#macro MOD_MAX_PATTERNS 100
#macro MOD_MAX_SAMPLE_BYTES 131070

/// ProTracker periods for C-1..B-3, finetune 0
function mod_periods()
{
    static _tab = [
        856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480, 453,
        428, 404, 381, 360, 339, 320, 302, 285, 269, 254, 240, 226,
        214, 202, 190, 180, 170, 160, 151, 143, 135, 127, 120, 113
    ];
    return _tab;
}

/// Note 1..36 -> period (0 for no note)
function mod_note_to_period(_note)
{
    if (_note < 1 || _note > 36) { return 0; }
    var _tab = mod_periods();
    return _tab[_note - 1];
}

/// Period -> nearest note 1..36 (0 for period 0)
function mod_period_to_note(_period)
{
    if (_period <= 0) { return 0; }
    var _tab = mod_periods();
    var _best = 1;
    var _best_d = 1000000;
    for (var i = 0; i < 36; i++)
    {
        var _d = abs(ln(_period / _tab[i]));
        if (_d < _best_d)
        {
            _best_d = _d;
            _best = i + 1;
        }
    }
    return _best;
}

/// Reads a number field from a struct (modsong data may come from JSON)
function mod_num(_s, _key, _def)
{
    if (!is_struct(_s)) { return _def; }
    var _v = _s[$ _key];
    if (is_undefined(_v) || !is_numeric(_v)) { return _def; }
    return _v;
}

function mod_int(_v, _lo, _hi)
{
    return clamp(floor(_v), _lo, _hi);
}

/// The order table as written: 1..128 entries, each 0..MOD_MAX_PATTERNS-1
function mod_song_order(_ms)
{
    var _out = [];
    var _src = undefined;
    if (is_struct(_ms)) { _src = _ms[$ "order"]; }
    if (is_array(_src))
    {
        var _n = min(array_length(_src), 128);
        for (var i = 0; i < _n; i++)
        {
            var _v = _src[i];
            if (!is_numeric(_v)) { _v = 0; }
            array_push(_out, mod_int(_v, 0, MOD_MAX_PATTERNS - 1));
        }
    }
    if (array_length(_out) == 0) { array_push(_out, 0); }
    return _out;
}

function mod_pattern_count(_order)
{
    var _top = 0;
    for (var i = 0; i < array_length(_order); i++)
    {
        _top = max(_top, _order[i]);
    }
    return _top + 1;
}

/// Sample _i (0..30) normalised for writing: even byte length, loop in bytes
function mod_sample_info(_ms, _i)
{
    var _inf = { name : "", data : undefined, bytes : 0, volume : 0, finetune : 0, loop_start : 0, loop_len : 0 };
    var _list = undefined;
    if (is_struct(_ms)) { _list = _ms[$ "samples"]; }
    if (!is_array(_list) || _i >= array_length(_list)) { return _inf; }
    var _s = _list[_i];
    if (!is_struct(_s)) { return _inf; }
    var _name = _s[$ "name"];
    if (is_string(_name)) { _inf.name = _name; }
    var _data = _s[$ "data"];
    if (is_array(_data))
    {
        _inf.data = _data;
        var _n = min(array_length(_data), MOD_MAX_SAMPLE_BYTES);
        _inf.bytes = _n + (_n mod 2);
    }
    _inf.volume = mod_int(mod_num(_s, "volume", 64), 0, 64);
    _inf.finetune = mod_int(mod_num(_s, "finetune", 0), -8, 7);
    var _ls = mod_int(mod_num(_s, "loop_start", 0), 0, _inf.bytes);
    _ls = _ls - (_ls mod 2);
    var _ll = mod_int(mod_num(_s, "loop_len", 0), 0, _inf.bytes - _ls);
    _ll = _ll - (_ll mod 2);
    if (_ll < 4)
    {
        _ls = 0;
        _ll = 0;
    }
    _inf.loop_start = _ls;
    _inf.loop_len = _ll;
    return _inf;
}

/// Bytes mod_write would produce
function mod_size(_ms)
{
    var _total = MOD_HEADER_SIZE + mod_pattern_count(mod_song_order(_ms)) * MOD_PATTERN_SIZE;
    for (var s = 0; s < 31; s++)
    {
        _total += mod_sample_info(_ms, s).bytes;
    }
    return _total;
}

function mod_poke16(_b, _pos, _v)
{
    buffer_poke(_b, _pos, buffer_u8, (_v >> 8) & 0xff);
    buffer_poke(_b, _pos + 1, buffer_u8, _v & 0xff);
}

function mod_peek16(_b, _pos)
{
    return (buffer_peek(_b, _pos, buffer_u8) << 8) | buffer_peek(_b, _pos + 1, buffer_u8);
}

/// Writes up to _len ASCII bytes of _str (other characters become '?'); rest stays 0
function mod_put_text(_b, _pos, _str, _len)
{
    var _n = min(string_length(_str), _len);
    for (var i = 0; i < _n; i++)
    {
        var _c = ord(string_char_at(_str, i + 1));
        if (_c < 32 || _c > 126) { _c = 63; }
        buffer_poke(_b, _pos + i, buffer_u8, _c);
    }
}

/// Reads a zero-terminated text field, keeping printable ASCII only
function mod_get_text(_b, _pos, _len)
{
    var _s = "";
    for (var i = 0; i < _len; i++)
    {
        var _c = buffer_peek(_b, _pos + i, buffer_u8);
        if (_c == 0) { break; }
        if (_c >= 32 && _c <= 126) { _s += chr(_c); }
    }
    return _s;
}

/// Builds the MOD. Returns a buffer_fixed buffer of exactly mod_size(_ms) bytes.
function mod_write(_ms)
{
    var _order = mod_song_order(_ms);
    var _nord = array_length(_order);
    var _npat = mod_pattern_count(_order);
    var _size = mod_size(_ms);
    var _b = buffer_create(_size, buffer_fixed, 1);
    buffer_fill(_b, 0, buffer_u8, 0, _size);

    var _title = "";
    if (is_struct(_ms) && is_string(_ms[$ "title"])) { _title = _ms[$ "title"]; }
    mod_put_text(_b, 0, _title, 20);

    // sample headers
    var _infos = array_create(31, undefined);
    for (var s = 0; s < 31; s++)
    {
        var _inf = mod_sample_info(_ms, s);
        _infos[s] = _inf;
        var _p = 20 + s * 30;
        mod_put_text(_b, _p, _inf.name, 22);
        mod_poke16(_b, _p + 22, _inf.bytes div 2);
        buffer_poke(_b, _p + 24, buffer_u8, _inf.finetune & 0x0f);
        buffer_poke(_b, _p + 25, buffer_u8, _inf.volume);
        if (_inf.loop_len > 0)
        {
            mod_poke16(_b, _p + 26, _inf.loop_start div 2);
            mod_poke16(_b, _p + 28, _inf.loop_len div 2);
        }
        else
        {
            mod_poke16(_b, _p + 26, 0);
            mod_poke16(_b, _p + 28, 1);
        }
    }

    // song length, restart, order table, tag
    buffer_poke(_b, 950, buffer_u8, _nord);
    var _restart = floor(mod_num(_ms, "restart", 0));
    if (_restart > 0 && _restart < _nord) { buffer_poke(_b, 951, buffer_u8, _restart); }
    else { buffer_poke(_b, 951, buffer_u8, 127); }
    for (var o = 0; o < _nord; o++)
    {
        buffer_poke(_b, 952 + o, buffer_u8, _order[o]);
    }
    if (_npat > 64) { mod_put_text(_b, 1080, "M!K!", 4); }
    else { mod_put_text(_b, 1080, "M.K.", 4); }

    // patterns
    var _pats = undefined;
    if (is_struct(_ms)) { _pats = _ms[$ "patterns"]; }
    if (!is_array(_pats)) { _pats = []; }
    for (var _pn = 0; _pn < _npat; _pn++)
    {
        if (_pn >= array_length(_pats)) { break; }
        var _pat = _pats[_pn];
        if (!is_array(_pat)) { continue; }
        var _rows = min(array_length(_pat), 64);
        for (var r = 0; r < _rows; r++)
        {
            var _row = _pat[r];
            if (!is_array(_row)) { continue; }
            var _chans = min(array_length(_row), 4);
            for (var c = 0; c < _chans; c++)
            {
                var _cell = _row[c];
                if (!is_struct(_cell)) { continue; }
                var _per = mod_note_to_period(floor(mod_num(_cell, "note", 0)));
                var _smp = mod_int(mod_num(_cell, "sample", 0), 0, 31);
                var _eff = mod_int(mod_num(_cell, "effect", 0), 0, 15);
                var _par = mod_int(mod_num(_cell, "param", 0), 0, 255);
                var _pos = MOD_HEADER_SIZE + _pn * MOD_PATTERN_SIZE + r * 16 + c * 4;
                buffer_poke(_b, _pos, buffer_u8, (_smp & 0xf0) | ((_per >> 8) & 0x0f));
                buffer_poke(_b, _pos + 1, buffer_u8, _per & 0xff);
                buffer_poke(_b, _pos + 2, buffer_u8, ((_smp & 0x0f) << 4) | _eff);
                buffer_poke(_b, _pos + 3, buffer_u8, _par);
            }
        }
    }

    // sample data (signed 8-bit)
    buffer_seek(_b, buffer_seek_start, MOD_HEADER_SIZE + _npat * MOD_PATTERN_SIZE);
    for (var sd = 0; sd < 31; sd++)
    {
        var _di = _infos[sd];
        if (_di.bytes == 0) { continue; }
        var _start = buffer_tell(_b);
        var _data = _di.data;
        var _n = min(array_length(_data), _di.bytes);
        for (var i = 0; i < _n; i++)
        {
            var _v = _data[i];
            if (!is_numeric(_v)) { _v = 0; }
            buffer_write(_b, buffer_u8, mod_int(_v, -128, 127) & 0xff);
        }
        if (_n < _di.bytes) { buffer_write(_b, buffer_u8, 0); }
        if (_di.loop_len == 0)
        {
            buffer_poke(_b, _start, buffer_u8, 0);
            buffer_poke(_b, _start + 1, buffer_u8, 0);
        }
    }
    return _b;
}

/// Writes the MOD to a file. Returns true on success.
function mod_save_file(_ms, _path)
{
    var _b = mod_write(_ms);
    var _ok = true;
    try
    {
        buffer_save(_b, _path);
    }
    catch (_e)
    {
        _ok = false;
    }
    buffer_delete(_b);
    if (_ok) { _ok = file_exists(_path); }
    return _ok;
}

/// Parses a MOD held in a buffer. Never reads past the end.
/// Returns { song : modsong or undefined, err : "", warn : "" }.
function mod_parse(_b)
{
    var _res = { song : undefined, err : "", warn : "" };
    var _size = buffer_get_size(_b);
    if (_size < MOD_HEADER_SIZE + MOD_PATTERN_SIZE)
    {
        _res.err = "That file is too small to be a MOD";
        return _res;
    }

    var _tag = "";
    for (var i = 0; i < 4; i++)
    {
        var _c = buffer_peek(_b, 1080 + i, buffer_u8);
        if (_c < 32 || _c > 126) { _c = 63; }
        _tag += chr(_c);
    }
    if (_tag != "M.K." && _tag != "M!K!" && _tag != "FLT4" && _tag != "4CHN")
    {
        var _chn = string_copy(_tag, 2, 3) == "CHN" && string_digits(string_char_at(_tag, 1)) != "";
        var _ch2 = string_copy(_tag, 3, 2) == "CH" && string_digits(string_copy(_tag, 1, 2)) == string_copy(_tag, 1, 2);
        if (_chn || _ch2 || _tag == "FLT8" || _tag == "CD81" || _tag == "OKTA" || _tag == "OCTA" || _tag == "TDZ8")
        {
            _res.err = "This MOD has more than 4 channels (" + _tag + ") - the Amiga plays 4-channel MODs only";
        }
        else
        {
            _res.err = "Not a 31-sample ProTracker MOD (old 15-sample Soundtracker files: re-save as MOD in OpenMPT)";
        }
        return _res;
    }

    var _nord = buffer_peek(_b, 950, buffer_u8);
    if (_nord < 1 || _nord > 128)
    {
        _res.err = "That MOD is damaged (bad song length)";
        return _res;
    }
    // pattern count: highest entry in the whole order table, like ProTracker
    var _top = 0;
    for (var o = 0; o < 128; o++)
    {
        _top = max(_top, buffer_peek(_b, 952 + o, buffer_u8));
    }
    if (_top >= MOD_MAX_PATTERNS)
    {
        // junk past the song end: count the used entries only
        _top = 0;
        for (var u = 0; u < _nord; u++)
        {
            _top = max(_top, buffer_peek(_b, 952 + u, buffer_u8));
        }
    }
    if (_top >= MOD_MAX_PATTERNS)
    {
        _res.err = "That MOD is damaged (too many patterns)";
        return _res;
    }
    var _npat = _top + 1;
    var _data_at = MOD_HEADER_SIZE + _npat * MOD_PATTERN_SIZE;
    if (_data_at > _size)
    {
        _res.err = "That MOD is cut short (patterns missing)";
        return _res;
    }

    var _ms = {
        title : mod_get_text(_b, 0, 20),
        samples : array_create(31, undefined),
        order : array_create(_nord, 0),
        restart : 0,
        patterns : array_create(_npat, undefined)
    };
    var _rs = buffer_peek(_b, 951, buffer_u8);
    if (_rs < _nord) { _ms.restart = _rs; }
    for (var k = 0; k < _nord; k++)
    {
        _ms.order[k] = min(buffer_peek(_b, 952 + k, buffer_u8), _npat - 1);
    }

    for (var _pn = 0; _pn < _npat; _pn++)
    {
        var _pat = array_create(64, undefined);
        for (var r = 0; r < 64; r++)
        {
            var _row = array_create(4, undefined);
            for (var c = 0; c < 4; c++)
            {
                var _pos = MOD_HEADER_SIZE + _pn * MOD_PATTERN_SIZE + r * 16 + c * 4;
                var _b0 = buffer_peek(_b, _pos, buffer_u8);
                var _b1 = buffer_peek(_b, _pos + 1, buffer_u8);
                var _b2 = buffer_peek(_b, _pos + 2, buffer_u8);
                var _b3 = buffer_peek(_b, _pos + 3, buffer_u8);
                _row[c] = {
                    note : mod_period_to_note(((_b0 & 0x0f) << 8) | _b1),
                    sample : (_b0 & 0xf0) | (_b2 >> 4),
                    effect : _b2 & 0x0f,
                    param : _b3
                };
            }
            _pat[r] = _row;
        }
        _ms.patterns[_pn] = _pat;
    }

    var _at = _data_at;
    for (var s = 0; s < 31; s++)
    {
        var _p = 20 + s * 30;
        var _len = mod_peek16(_b, _p + 22) * 2;
        var _ft = buffer_peek(_b, _p + 24, buffer_u8) & 0x0f;
        if (_ft > 7) { _ft -= 16; }
        var _ls = mod_peek16(_b, _p + 26) * 2;
        var _ll = mod_peek16(_b, _p + 28) * 2;
        var _avail = max(0, _size - _at);
        if (_len > _avail)
        {
            _res.warn = "Some sample data was missing from the end of that MOD";
            _len = _avail - (_avail mod 2);
        }
        if (_ll <= 2 || _ls >= _len)
        {
            _ls = 0;
            _ll = 0;
        }
        else if (_ls + _ll > _len)
        {
            _ll = _len - _ls;
            if (_ll < 4)
            {
                _ls = 0;
                _ll = 0;
            }
        }
        var _data = array_create(_len, 0);
        if (_len > 0)
        {
            buffer_seek(_b, buffer_seek_start, _at);
            for (var j = 0; j < _len; j++)
            {
                _data[j] = buffer_read(_b, buffer_s8);
            }
        }
        _at += _len;
        _ms.samples[s] = {
            name : mod_get_text(_b, _p, 22),
            data : _data,
            volume : min(buffer_peek(_b, _p + 25, buffer_u8), 64),
            finetune : _ft,
            loop_start : _ls,
            loop_len : _ll
        };
    }
    _res.song = _ms;
    return _res;
}

/// Loads a MOD file. Returns a modsong, or undefined (with a toast) on failure.
function mod_read(_path)
{
    if (!file_exists(_path))
    {
        toast("Can't find " + filename_name(_path), 2);
        return undefined;
    }
    var _b = buffer_load(_path);
    if (!buffer_exists(_b))
    {
        toast("Couldn't read " + filename_name(_path), 2);
        return undefined;
    }
    var _res;
    try
    {
        _res = mod_parse(_b);
    }
    catch (_e)
    {
        _res = { song : undefined, err : "That MOD is damaged", warn : "" };
    }
    buffer_delete(_b);
    if (is_undefined(_res.song))
    {
        toast(_res.err, 2);
        return undefined;
    }
    if (_res.warn != "") { toast(_res.warn, 1); }
    return _res.song;
}

/// 64 x 4 empty cells
function mod_empty_pattern()
{
    var _pat = array_create(64, undefined);
    for (var r = 0; r < 64; r++)
    {
        var _row = array_create(4, undefined);
        for (var c = 0; c < 4; c++)
        {
            _row[c] = { note : 0, sample : 0, effect : 0, param : 0 };
        }
        _pat[r] = _row;
    }
    return _pat;
}

function mod_set_cell(_pat, _row, _ch, _note, _smp, _eff, _par)
{
    var _cells = _pat[_row];
    _cells[@ _ch] = { note : _note, sample : _smp, effect : _eff, param : _par };
}

// ===========================================================================
// C64 side: MOD <-> 3-voice SID song
// ===========================================================================

#macro MOD_C2_RATE 8287          // a sample played at C-2 (period 428) runs at 3546895 / 428 Hz
#macro MOD_PITCH_OFS 24          // MOD note m (1 = C-1) sounds as SID pitch m + 24 (C-3 upwards) -
#macro MOD_BASS_OFS 12           // or m + 12 for a bass, so a saved song comes back at its own pitch

/// SID pitch offset of MOD notes played by instrument _id
function music_mod_ofs(_id)
{
    if (_id == 6 || _id == 7) { return MOD_BASS_OFS; }
    return MOD_PITCH_OFS;
}

/// Puts an effect in the first free effect column of a row (from channel _prefer); if every
/// column is busy, channel _prefer's is replaced. (ADAM's music_put_fx)
function mod_put_fx(_row, _fx, _prm, _prefer)
{
    for (var k = 0; k < 4; k++)
    {
        var _c = _row[(_prefer + k) mod 4];
        if (_c.effect == 0 && _c.param == 0)
        {
            _c.effect = _fx;
            _c.param = _prm;
            return true;
        }
    }
    _row[_prefer].effect = _fx;
    _row[_prefer].param = _prm;
    return false;
}

function mod_pattern_key(_pat)
{
    var _s = "";
    for (var r = 0; r < 64; r++)
    {
        for (var c = 0; c < 4; c++)
        {
            var _cell = _pat[r][c];
            if (_cell.note != 0 || _cell.sample != 0 || _cell.effect != 0 || _cell.param != 0)
            {
                _s += string(r * 4 + c) + ":" + string(_cell.note) + "," + string(_cell.sample) + "," + string(_cell.effect) + "," + string(_cell.param) + ";";
            }
        }
    }
    return _s;
}

function mod_warn(_list, _text)
{
    for (var i = 0; i < array_length(_list); i++)
    {
        if (_list[i] == _text) { return; }
    }
    array_push(_list, _text);
}

// ---------------------------------------------------------------------------
// Save: song -> modsong
// ---------------------------------------------------------------------------

/// An 8-bit sample of compiled instrument _in, played by the SID synth at pitch _pref (or at its
/// drum pitch) at MOD_C2_RATE. Sustaining sounds get a loop of whole waveform cycles.
function music_mod_sample(_in, _pref)
{
    var _rate = MOD_C2_RATE;
    var _sv = mus_sidv_new();
    _sv.ad = _in.ad;
    _sv.sr = _in.sr;
    _sv.pw = _in.pw;
    var _fl = music_note_freq(_pref);
    if (_in.fix > 0) { _fl = _in.fix * 256; }
    var _cyc = sid_clock() / _rate;
    var _spf = _rate / sid_fps();
    var _sus = (_in.sr >> 4) & 15;
    var _oneshot = (_in.fix > 0 || _sus == 0 || _in.sweep != 0);
    var _data = [];
    var _fpos = 0;
    var _frame = 0;
    var _pw = _in.pw;
    var _max = floor(_rate * 1.2);
    // attack and decay (the whole sound, for one-shots)
    while (array_length(_data) < _max)
    {
        if (_fpos <= 0)
        {
            _fpos += _spf;
            if (_in.sweep != 0) { _fl = (clamp((_fl >> 8) + _in.sweep, 0, 255) << 8) | (_fl & 255); }
            if (_in.pws != 0 && _oneshot) { _pw = (_pw + _in.pws) & 4095; }
            _sv.freq = _fl;
            _sv.pw = _pw;
            var _w = _in.w;
            if (_frame == 0 && _in.w1 != 0) { _w = _in.w1; }
            mus_sidv_ctrl(_sv, _w | 1);
            _frame += 1;
        }
        _fpos -= 1;
        array_push(_data, mus_sidv_sample(_sv, _cyc));
        if (_frame > 2)
        {
            if (_oneshot && _sv.est == 1 && _sv.env == 0) { break; }
            if (!_oneshot && _sv.est == 1 && _sv.env <= _sus * 17) { break; }
        }
    }
    var _ls = 0;
    var _ll = 0;
    if (!_oneshot)
    {
        // a loop of k whole cycles, as close to a whole number of samples as can be
        var _per = _rate * 16777216 / max(1, _fl * sid_clock());
        var _bestk = 1;
        var _beste = 1;
        for (var k = 1; k <= 64; k++)
        {
            if (_per * k < 128) { continue; }
            var _e = abs(_per * k - round(_per * k)) / k;
            if (_e < _beste)
            {
                _beste = _e;
                _bestk = k;
            }
            if (_per * k > 4000) { break; }
        }
        var _n = max(4, round(_per * _bestk));
        _n += _n mod 2;
        if (array_length(_data) mod 2 == 1) { array_push(_data, mus_sidv_sample(_sv, _cyc)); }
        _ls = array_length(_data);
        for (var i = 0; i < _n; i++) { array_push(_data, mus_sidv_sample(_sv, _cyc)); }
        _ll = _n;
    }
    var _peak = 0.05;
    for (var j = 0; j < array_length(_data); j++) { _peak = max(_peak, abs(_data[j])); }
    var _g = min(4, 0.95 / _peak);
    for (var q = 0; q < array_length(_data); q++) { _data[q] = clamp(round(_data[q] * _g * 127), -128, 127); }
    return { data : _data, loop_start : _ls, loop_len : _ll };
}

/// Splits a song into MOD patterns of up to 2 bars, starting one at the loop bar (ADAM's chunks)
function music_mod_chunks(_song)
{
    var _bars = clamp(_song.arr.bars, 1, MUS_BAR_MAX);
    var _lb = clamp(_song.loop_bar, 0, _bars - 1);
    var _out = [];
    var _b = 0;
    while (_b < _bars)
    {
        var _e = min(_b + 2, _bars);
        if (_b < _lb) { _e = min(_e, _lb); }
        array_push(_out, [_b, _e - _b]);
        _b = _e;
    }
    return _out;
}

/// MOD effect [effect, param] for loop _lp's step _st sounding at SID pitch _p (MOD note _m)
function music_mod_fx_out(_lp, _st, _p, _m, _speed)
{
    var _fx = _lp.fx[_st];
    if (_fx == 5) { return [12, clamp(round(_lp.fxp[_st] * 64 / 15), 0, 64)]; }      // volume (sustain level)
    var _fp = max(1, _lp.fxp[_st]);
    if (_fx == 0) { return [0, 0]; }
    var _per = mod_note_to_period(_m);
    var _f = max(1, music_note_freq(_p));
    var _tick = _speed / max(1, _speed - 1);        // MOD slides skip each row's first tick
    if (_fx == 1) { return [1, clamp(round(_per * _fp * 8 / _f * _tick), 1, 255)]; }
    if (_fx == 2) { return [2, clamp(round(_per * _fp * 8 / _f * _tick), 1, 255)]; }
    if (_fx == 3)
    {
        // vibrato: a 16-step cycle advanced by the speed each frame = MOD speed x 4 of 64 per tick
        var _inc = (_fp >> 6) + 1;
        return [4, (clamp(_inc * 4, 1, 15) << 4) | clamp(round(_per * (_fp & 63) * 8 / _f / 2), 1, 15)];
    }
    return [3, clamp(round(_per * _fp * 16 / _f * _tick), 1, 255)];
}

/// Song -> { ms : modsong, warnings : [] }
function music_mod_export(_song)
{
    var _warn = [];
    var _ms = { title : string_copy(_song.name, 1, 20), samples : [], order : [], restart : 0, patterns : [] };
    for (var i = 0; i < 31; i++) { array_push(_ms.samples, { name : "", data : [], volume : 64, finetune : 0, loop_start : 0, loop_len : 0 }); }
    var _arr = _song.arr;
    var _bars = clamp(_arr.bars, 1, MUS_BAR_MAX);
    var _speed = clamp(_song.speed, 2, 12);
    // the instruments the song plays, and the range of pitches each plays
    var _ins = [];
    var _keys = {};
    for (var l = 0; l < MUS_LANES; l++)
    {
        for (var b = 0; b < _bars; b++)
        {
            var _li = _arr.lanes[l][b];
            if (_li < 0 || _li >= array_length(_arr.loops)) { continue; }
            var _lp = _arr.loops[_li];
            for (var st = 0; st < MUS_STEPS; st++)
            {
                if (_lp.notes[st] <= 0) { continue; }
                var _drum = (_lp.cat == 0);
                var _id = _lp.inst;
                if (_drum) { _id = _lp.insts[st]; }
                var _k = string(_id) + "_" + string(_drum);
                var _e = _keys[$ _k];
                if (is_undefined(_e))
                {
                    _e = { id : _id, drum : _drum, ins : music_inst_compiled(_id, _drum), lo : 999, hi : -1, smp : 0, pref : 37 };
                    _keys[$ _k] = _e;
                    array_push(_ins, _e);
                }
                if (_e.ins.fix == 0)
                {
                    var _p = clamp(_lp.notes[st] + _e.ins.tr, 1, MUS_SOUND_MAX);
                    _e.lo = min(_e.lo, _p);
                    _e.hi = max(_e.hi, _p);
                }
            }
        }
    }
    for (var n = 0; n < array_length(_ins); n++)
    {
        var _e2 = _ins[n];
        if (n >= 31)
        {
            mod_warn(_warn, "A MOD has 31 samples - " + music_inst_name(_e2.id) + " and later instruments were left out.");
            continue;
        }
        if (_e2.hi >= 0)
        {
            // MOD notes reach 3 octaves: the sample's pitch puts the lowest note at C-1 if it can
            _e2.pref = clamp(music_mod_ofs(_e2.id) + 13, _e2.hi - 23, _e2.lo + 12);
            if (_e2.hi - 23 > _e2.lo + 12) { _e2.pref = _e2.hi - 23; }
            if (_e2.hi - _e2.lo > 35) { mod_warn(_warn, music_inst_name(_e2.id) + " plays more than 3 octaves - a MOD's notes only reach 3, so the lowest were moved up."); }
        }
        var _smp = music_mod_sample(_e2.ins, _e2.pref);
        var _ms_s = _ms.samples[n];
        _ms_s.name = string_copy(music_inst_name(_e2.id), 1, 22);
        _ms_s.data = _smp.data;
        _ms_s.loop_start = _smp.loop_start;
        _ms_s.loop_len = _smp.loop_len;
        _e2.smp = n + 1;
    }
    // patterns: one row per step, 2 bars each
    var _chunks = music_mod_chunks(_song);
    var _lb = clamp(_song.loop_bar, 0, _bars - 1);
    var _seen = {};
    for (var c = 0; c < array_length(_chunks); c++)
    {
        var _b0 = _chunks[c][0];
        var _nb = _chunks[c][1];
        if (_b0 == _lb) { _ms.restart = array_length(_ms.order); }
        var _pat = mod_empty_pattern();
        var _ends = [];
        for (var lane = 0; lane < MUS_LANES; lane++)
        {
            for (var bb = 0; bb < _nb; bb++)
            {
                var _li2 = _arr.lanes[lane][_b0 + bb];
                if (_li2 < 0 || _li2 >= array_length(_arr.loops)) { continue; }
                var _lp2 = _arr.loops[_li2];
                var _drum2 = (_lp2.cat == 0);
                var _snd_m = array_create(MUS_STEPS, 0);
                var _snd_p = array_create(MUS_STEPS, 0);
                var _snd_fix = array_create(MUS_STEPS, true);
                var _arrive = array_create(MUS_STEPS, false);
                if (!_drum2)
                {
                    for (var g0 = 0; g0 < MUS_STEPS; g0++)
                    {
                        if (music_glide_valid(_lp2, g0)) { _arrive[_lp2.glide_to[g0]] = true; }
                    }
                }
                for (var s = 0; s < MUS_STEPS; s++)
                {
                    var _nt = _lp2.notes[s];
                    if (_nt <= 0) { continue; }
                    var _id2 = _lp2.inst;
                    if (_drum2) { _id2 = _lp2.insts[s]; }
                    var _e3 = _keys[$ string(_id2) + "_" + string(_drum2)];
                    if (_e3.smp == 0) { continue; }
                    var _len = music_note_length(_lp2, s);
                    for (var t = s + 1; t < s + _len; t++)
                    {
                        if (_lp2.notes[t] > 0)
                        {
                            _len = t - s;
                            break;
                        }
                    }
                    var _row = bb * MUS_STEPS + s;
                    var _m = 13;
                    var _p2 = 0;
                    if (_e3.ins.fix == 0)
                    {
                        _p2 = clamp(_nt + _e3.ins.tr, 1, MUS_SOUND_MAX);
                        _m = clamp(_p2 - _e3.pref + 13, 1, 36);
                    }
                    var _cell = _pat[_row][lane];
                    _cell.note = _m;
                    _cell.sample = _e3.smp;
                    // a chord, on every row the note is held (a MOD effect lasts one row)
                    if (_lp2.arps[s] != 0 && _e3.ins.fix == 0)
                    {
                        for (var r = _row; r < _row + _len; r++)
                        {
                            _pat[r][lane].effect = 0;
                            _pat[r][lane].param = _lp2.arps[s];
                        }
                    }
                    // the note sounding on each step, for the effects
                    for (var t2 = s; t2 < s + _len; t2++)
                    {
                        _snd_m[t2] = _m;
                        _snd_p[t2] = _p2;
                        _snd_fix[t2] = (_e3.ins.fix != 0);
                    }
                    // a linked bend arrives: the note glides in (3xx) without starting again
                    if (_arrive[s]) { _cell.effect = 3; _cell.param = 255; }
                    // swing: the 2nd and 3rd 32nd of each 16th pair start late
                    if (_song.swing > 0 && (s mod 4 == 1 || s mod 4 == 2) && _cell.effect == 0 && _cell.param == 0)
                    {
                        _cell.effect = 14;
                        _cell.param = 0xd0 | clamp(_song.swing, 1, 15);
                    }
                    // the gate goes off: volume 0 on the row after (unless a note is there)
                    if (_row + _len < _nb * MUS_STEPS) { array_push(_ends, [_row + _len, lane]); }
                }
                // effects: on every step they last, at the pitch sounding there
                for (var t3 = 0; t3 < MUS_STEPS; t3++)
                {
                    var _src = music_fx_active_step(_lp2, t3);
                    if (_src < 0 || _snd_m[t3] == 0 || _snd_fix[t3]) { continue; }
                    var _fo = music_mod_fx_out(_lp2, _src, _snd_p[t3], _snd_m[t3], _speed);
                    var _fc = _pat[bb * MUS_STEPS + t3][lane];
                    if (_fc.effect == 14 || _fc.effect == 3) { continue; }
                    if (_fc.effect == 0 && _fc.param != 0) { mod_warn(_warn, "A MOD row has one effect: steps with a chord and an effect kept the effect."); }
                    _fc.effect = _fo[0];
                    _fc.param = _fo[1];
                }
                // linked bends: period slides on the rows up to the target (as ADAM writes them)
                for (var g1 = 0; g1 < MUS_STEPS; g1++)
                {
                    if (_drum2 || !music_glide_valid(_lp2, g1) || _snd_m[g1] == 0 || _snd_fix[g1]) { continue; }
                    var _gt = _lp2.glide_to[g1];
                    if (_snd_m[_gt] == 0) { continue; }
                    var _delta = mod_note_to_period(_snd_m[_gt]) - mod_note_to_period(_snd_m[g1]);
                    var _units = round(abs(_delta) / max(1, _speed - 1));
                    var _span = _gt - g1;
                    for (var r2 = g1; r2 < _gt; r2++)
                    {
                        var _bc = _pat[bb * MUS_STEPS + r2][lane];
                        if (_bc.effect == 14) { continue; }
                        var _pa = floor(_units * (r2 - g1 + 1) / _span) - floor(_units * (r2 - g1) / _span);
                        _bc.effect = 2;
                        if (_delta < 0) { _bc.effect = 1; }
                        _bc.param = clamp(_pa, 0, 255);
                        if (_bc.param == 0) { _bc.effect = 0; }
                    }
                }
            }
        }
        for (var en = 0; en < array_length(_ends); en++)
        {
            var _ec = _pat[_ends[en][0]][_ends[en][1]];
            if (_ec.note == 0 && _ec.effect == 0 && _ec.param == 0) { _ec.effect = 12; }
        }
        // tempo: rows of song.speed ticks; on NTSC the ticks run 60 times a second (150 BPM)
        if (c == 0 || _b0 == _lb)
        {
            mod_put_fx(_pat[0], 15, _speed, 3);
            if (machine_is_ntsc()) { mod_put_fx(_pat[0], 15, 150, 3); }
        }
        if (_nb == 1) { mod_put_fx(_pat[MUS_STEPS - 1], 13, 0, 3); }
        var _key = mod_pattern_key(_pat);
        var _pn = _seen[$ _key];
        if (is_undefined(_pn))
        {
            if (array_length(_ms.patterns) >= MOD_MAX_PATTERNS)
            {
                mod_warn(_warn, "The song needs more than " + string(MOD_MAX_PATTERNS) + " patterns - the end was left off.");
                break;
            }
            _pn = array_length(_ms.patterns);
            array_push(_ms.patterns, _pat);
            _seen[$ _key] = _pn;
        }
        array_push(_ms.order, _pn);
    }
    if (_song.swing > 0) { mod_warn(_warn, "Swing was saved as note delays (EDx)."); }
    return { ms : _ms, warnings : _warn };
}

// ---------------------------------------------------------------------------
// Import: modsong -> song
// ---------------------------------------------------------------------------

/// The SID instrument for MOD sample _s (1..31): drums by name or by how noisy a short sample
/// is, the rest by the notes it plays (_avg = its average MOD note). Returns { id, drum }.
function music_mod_sample_inst(_ms, _s, _avg)
{
    var _smp = _ms.samples[_s - 1];
    var _nm = string_lower(string_trim(_smp.name));
    // a MOD saved here names its samples after the instruments
    for (var b = 0; b < array_length(global.MUS_INST); b++)
    {
        if (_nm == string_lower(global.MUS_INST[b].name)) { return { id : b, drum : (global.MUS_INST[b].fix > 0) }; }
    }
    var _names = [["kick", 0], ["bd", 0], ["bassdrum", 0], ["bass drum", 0], ["snare", 1], ["sd", 1], ["clap", 5], ["cp", 5],
                  ["open", 3], ["oh", 3], ["crash", 3], ["cymbal", 3], ["ride", 3], ["hat", 2], ["hh", 2], ["ch", 2],
                  ["tom", 4], ["noise", 15], ["zap", 13], ["laser", 13]];
    for (var i = 0; i < array_length(_names); i++)
    {
        var _w = _names[i][0];
        var _at = string_pos(_w, _nm);
        if (_at > 0)
        {
            // short codes (bd, sd, oh, hh, ch, cp) must stand on their own
            var _ok = true;
            if (string_length(_w) <= 2)
            {
                if (_at > 1 && string_letters(string_char_at(_nm, _at - 1)) != "") { _ok = false; }
                if (string_letters(string_char_at(_nm, _at + string_length(_w))) != "") { _ok = false; }
            }
            if (_ok) { return { id : _names[i][1], drum : true }; }
        }
    }
    var _d = _smp.data;
    var _n = array_length(_d);
    if (_smp.loop_len == 0 && _n > 0 && _n < 6000)
    {
        // a short one-shot: how often it crosses zero says kick, snare or hi-hat
        var _zc = 0;
        var _m = min(_n, 1500);
        for (var j = 1; j < _m; j++)
        {
            if ((_d[j] >= 0) != (_d[j - 1] >= 0)) { _zc += 1; }
        }
        var _rate = _zc / max(1, _m);
        if (_rate > 0.3) { return { id : 2, drum : true }; }
        if (_rate > 0.1) { return { id : 1, drum : true }; }
        return { id : 0, drum : true };
    }
    if (_avg < 13) { return { id : 6, drum : false }; }
    // a looped sample sustains: a lead that holds its notes; a one-shot: a plucked sound
    if (_smp.loop_len > 0) { return { id : 10, drum : false }; }
    return { id : 12, drum : false };
}

/// [fx, amount] for a MOD slide / glide / vibrato at MOD note _m (the reverse of music_mod_fx_out)
function music_mod_fx_in(_eff, _par, _m, _speed, _ofs)
{
    // values read from the file can be 64-bit integers: keep these sums out of integer maths
    _par = real(_par);
    _speed = real(_speed);
    _m = real(_m);
    var _per = mod_note_to_period(clamp(_m, 1, 36));
    var _f = max(1, music_note_freq(clamp(_m + _ofs, 1, MUS_SOUND_MAX)));
    var _tick = max(1, _speed - 1) / max(1, _speed);
    if (_eff == 1 && _par > 0) { return [1, clamp(round(_par * _tick * _f / (_per * 8)), 1, 255)]; }
    if (_eff == 2 && _par > 0) { return [2, clamp(round(_par * _tick * _f / (_per * 8)), 1, 255)]; }
    if (_eff == 3 || _eff == 5) { return [4, clamp(round(max(1, _par) * _tick * _f / (_per * 16)), 1, 255)]; }
    if (_eff == 4 || _eff == 6)
    {
        var _sp = clamp(round((_par >> 4) / 4), 1, 4);
        return [3, ((_sp - 1) << 6) | clamp(round(max(1, _par & 15) * 2 * _f / (_per * 8)), 1, 63)];
    }
    if (_eff == 12) { return [5, clamp(round(min(_par, 64) * 15 / 64), 0, 15)]; }
    return [0, 0];
}

/// Modsong -> { song, warnings }. _name is used when the MOD has no title.
function music_mod_import(_ms, _name)
{
    var _warn = [];
    var _ord = _ms.order;
    var _pats = _ms.patterns;
    // the order actually played: up to the first jump (Bxx), which sets the loop point;
    // a pattern break (Dxx) makes a pattern shorter
    var _play = [];
    var _restart = clamp(_ms.restart, 0, array_length(_ord) - 1);
    var _rows_in = [];
    for (var o = 0; o < array_length(_ord); o++)
    {
        var _pat = _pats[_ord[o]];
        var _rows = 64;
        var _jump = -1;
        for (var r = 0; r < 64 && _rows == 64; r++)
        {
            for (var c = 0; c < 4; c++)
            {
                var _cl = _pat[r][c];
                if (_cl.effect == 13) { _rows = r + 1; }
                if (_cl.effect == 11)
                {
                    _rows = r + 1;
                    _jump = _cl.param;
                }
            }
        }
        array_push(_play, _ord[o]);
        array_push(_rows_in, _rows);
        if (_jump >= 0)
        {
            if (_jump <= o) { _restart = _jump; }
            if (o < array_length(_ord) - 1) { mod_warn(_warn, "The MOD jumps around its order list - the part up to the first jump came in."); }
            break;
        }
    }
    var _np = array_length(_play);
    if (_restart >= _np) { _restart = 0; }
    // tempo: the first speed (Fxx under 32) and BPM (Fxx 32 and up)
    var _ticks = 6;
    var _bpm = 125;
    var _got_t = false;
    var _got_b = false;
    for (var o2 = 0; o2 < _np; o2++)
    {
        for (var r2 = 0; r2 < _rows_in[o2]; r2++)
        {
            for (var c2 = 0; c2 < 4; c2++)
            {
                var _c2 = _pats[_play[o2]][r2][c2];
                if (_c2.effect != 15 || _c2.param == 0) { continue; }
                if (_c2.param < 32)
                {
                    if (!_got_t)
                    {
                        _ticks = _c2.param;
                        _got_t = true;
                    }
                    else if (_c2.param != _ticks) { mod_warn(_warn, "The MOD changes speed as it plays - the song keeps its first speed."); }
                }
                else
                {
                    if (!_got_b)
                    {
                        _bpm = _c2.param;
                        _got_b = true;
                    }
                    else if (_c2.param != _bpm) { mod_warn(_warn, "The MOD changes tempo as it plays - the song keeps its first tempo."); }
                }
            }
        }
    }
    // a row lasts this many C64 frames (MOD ticks run BPM x 2 / 5 times a second)
    var _fpr = real(_ticks) * sid_fps() * 2.5 / real(_bpm);
    // the 3 busiest channels become the SID's voices
    var _count = [0, 0, 0, 0];
    var _odd = false;
    for (var o3 = 0; o3 < _np; o3++)
    {
        for (var r3 = 0; r3 < _rows_in[o3]; r3++)
        {
            for (var c3 = 0; c3 < 4; c3++)
            {
                if (_pats[_play[o3]][r3][c3].note > 0)
                {
                    _count[c3] += 1;
                    if (r3 mod 2 == 1) { _odd = true; }
                }
            }
        }
    }
    var _drop = 0;
    for (var c4 = 1; c4 < 4; c4++)
    {
        if (_count[c4] < _count[_drop]) { _drop = c4; }
    }
    var _chans = [];
    for (var c5 = 0; c5 < 4; c5++)
    {
        if (c5 != _drop) { array_push(_chans, c5); }
    }
    if (_count[_drop] > 0) { mod_warn(_warn, "The SID has 3 voices: channel " + string(_drop + 1) + " (the quietest, " + string(_count[_drop]) + " notes) was left out."); }
    // steps per row: 2 when every note is on an even row and the rows are long enough
    var _spr = 1;
    var _speed = round(_fpr);
    if (!_odd && _fpr >= 3.5)
    {
        _spr = 2;
        _speed = round(_fpr / 2);
    }
    if (_speed < 2 || _speed > 12) { mod_warn(_warn, "The MOD is faster or slower than a C64 song can go - its speed was changed."); }
    else if (abs(_speed * _spr - _fpr) > 0.26 * _spr) { mod_warn(_warn, "The tempo was rounded to whole C64 frames."); }
    _speed = clamp(_speed, 2, 12);
    // each sample's average note, then the SID instrument it becomes
    var _sum = array_create(32, 0);
    var _num = array_create(32, 0);
    var _last = [0, 0, 0, 0];
    for (var o4 = 0; o4 < _np; o4++)
    {
        for (var r4 = 0; r4 < _rows_in[o4]; r4++)
        {
            for (var c6 = 0; c6 < 4; c6++)
            {
                var _c6 = _pats[_play[o4]][r4][c6];
                if (_c6.sample > 0) { _last[c6] = _c6.sample; }
                if (_c6.note > 0 && _last[c6] > 0)
                {
                    _sum[_last[c6]] += _c6.note;
                    _num[_last[c6]] += 1;
                }
            }
        }
    }
    var _map = array_create(32, undefined);
    for (var s = 1; s <= 31; s++)
    {
        if (_num[s] > 0)
        {
            _map[s] = music_mod_sample_inst(_ms, s, _sum[s] / _num[s]);
            _map[s].hold = (_ms.samples[s - 1].loop_len > 0);      // a looped sample rings until stopped
        }
    }

    var _title = string_trim(_ms.title);
    if (_title == "") { _title = _name; }
    var _song = song_new(string_copy(_title, 1, 20));
    _song.speed = _speed;
    var _arr = _song.arr;
    var _loop_keys = {};
    var _bar = 0;
    var _rows_per_bar = MUS_STEPS div _spr;
    var _last2 = [0, 0, 0, 0];
    var _hold = [undefined, undefined, undefined, undefined];      // a note still ringing at the end of a bar
    var _cut_bars = false;
    var _dropped_drums = 0;
    for (var o5 = 0; o5 < _np; o5++)
    {
        if (o5 == _restart) { _song.loop_bar = min(_bar, MUS_BAR_MAX - 1); }
        var _pat5 = _pats[_play[o5]];
        var _nb = ceil(_rows_in[o5] / _rows_per_bar);
        for (var bb = 0; bb < _nb; bb++)
        {
            if (_bar >= MUS_BAR_MAX)
            {
                _cut_bars = true;
                break;
            }
            var _r0 = bb * _rows_per_bar;
            var _r1 = min(_rows_in[o5], _r0 + _rows_per_bar);
            for (var v = 0; v < MUS_LANES; v++)
            {
                var _ch = _chans[v];
                // this bar's notes: { st, m, smp, row, end_row }
                var _ev = [];
                // a long note that rings on past the bar line starts again at the top of this bar
                // (a loop is one bar, so notes can't cross bar lines)
                if (!is_undefined(_hold[_ch]))
                {
                    var _c0 = _pat5[_r0][_ch];
                    var _ends0 = (_c0.effect == 12 && _c0.param == 0) || (_c0.effect == 14 && (_c0.param >> 4) == 12);
                    if (_c0.note == 0 && !_ends0) { array_push(_ev, { st : 0, m : _hold[_ch].m, smp : _hold[_ch].smp, row : _r0, end_row : _r1 }); }
                    _hold[_ch] = undefined;
                }
                for (var rr = _r0; rr < _r1; rr++)
                {
                    var _cc = _pat5[rr][_ch];
                    if (_cc.sample > 0) { _last2[_ch] = _cc.sample; }
                    var _ne = array_length(_ev);
                    if (_cc.note > 0 && _last2[_ch] > 0 && !is_undefined(_map[_last2[_ch]]))
                    {
                        array_push(_ev, { st : (rr - _r0) * _spr, m : _cc.note, smp : _last2[_ch], row : rr, end_row : _r1 });
                        if (_ne > 0) { _ev[_ne - 1].end_row = min(_ev[_ne - 1].end_row, rr); }
                    }
                    // note ends: volume 0 (C00) or a note cut (ECx)
                    if ((_cc.effect == 12 && _cc.param == 0) || (_cc.effect == 14 && (_cc.param >> 4) == 12))
                    {
                        var _ln = array_length(_ev) - 1;
                        if (_ln >= 0 && _ev[_ln].row < rr) { _ev[_ln].end_row = min(_ev[_ln].end_row, rr); }
                        if (_ln >= 0 && _ev[_ln].row == rr) { _ev[_ln].end_row = rr + 1; }
                    }
                }
                var _nl = array_length(_ev) - 1;
                if (_nl >= 0 && _ev[_nl].end_row >= _r1 && !_map[_ev[_nl].smp].drum && _map[_ev[_nl].smp].hold) { _hold[_ch] = { m : _ev[_nl].m, smp : _ev[_nl].smp }; }
                if (array_length(_ev) == 0) { continue; }
                // a drum bar, or a tune on its most used instrument
                var _all_drum = true;
                var _tone_count = {};
                var _best_id = -1;
                var _best_n = 0;
                for (var e = 0; e < array_length(_ev); e++)
                {
                    var _mi = _map[_ev[e].smp];
                    if (!_mi.drum)
                    {
                        _all_drum = false;
                        var _tk = string(_mi.id);
                        var _tn = _tone_count[$ _tk];
                        if (is_undefined(_tn)) { _tn = 0; }
                        _tone_count[$ _tk] = _tn + 1;
                        if (_tn + 1 > _best_n)
                        {
                            _best_n = _tn + 1;
                            _best_id = _mi.id;
                        }
                    }
                }
                var _lp;
                var _tr = 0;
                if (_all_drum) { _lp = loop_new("Drums", 0, 0); }
                else
                {
                    var _cat = 3;
                    if (_best_id == 6 || _best_id == 7) { _cat = 1; }
                    var _sn = "";
                    for (var e1 = 0; e1 < array_length(_ev); e1++)
                    {
                        if (_map[_ev[e1].smp].id == _best_id) { _sn = string_trim(_ms.samples[_ev[e1].smp - 1].name); break; }
                    }
                    if (_sn == "") { _sn = global.MUS_CAT_NAMES[_cat]; }
                    _lp = loop_new(string_copy(_sn, 1, 16), _cat, _best_id);
                    _tr = music_inst_compiled(_best_id, false).tr;
                }
                var _bend_to = [];
                for (var e2 = 0; e2 < array_length(_ev); e2++)
                {
                    var _x = _ev[e2];
                    var _mi2 = _map[_x.smp];
                    var _st = _x.st;
                    if (_all_drum)
                    {
                        _lp.notes[_st] = MUS_ROOT;
                        _lp.insts[_st] = _mi2.id;
                    }
                    else
                    {
                        if (_mi2.drum)
                        {
                            _dropped_drums += 1;
                            continue;
                        }
                        _lp.notes[_st] = clamp(_x.m + music_mod_ofs(_best_id) - _tr, 1, MUS_NOTE_MAX);
                    }
                    _lp.lengths[_st] = clamp((_x.end_row - _x.row) * _spr, 1, MUS_STEPS - _st);
                    if (_mi2.drum) { continue; }
                    // a note that ends a bend this studio saved (3FF on its own row): a linked bend
                    if (_pat5[_x.row][_ch].effect == 3 && _pat5[_x.row][_ch].param == 255)
                    {
                        array_push(_bend_to, _st);
                        continue;
                    }
                    // the first chord or effect while the note is held
                    for (var r6 = _x.row; r6 < _x.end_row; r6++)
                    {
                        var _c7 = _pat5[r6][_ch];
                        if (_c7.effect == 0 && _c7.param != 0)
                        {
                            if (_lp.arps[_st] == 0) { _lp.arps[_st] = _c7.param; }
                            continue;
                        }
                        var _fi = music_mod_fx_in(_c7.effect, _c7.param, _x.m, _ticks, music_mod_ofs(_best_id));
                        if (_fi[0] != 0)
                        {
                            // on the step its row is, lasting as long as the rows repeat it
                            var _es = _st + (r6 - _x.row) * _spr;
                            if (_es >= MUS_STEPS) { break; }
                            var _last = r6;
                            while (_last + 1 < _x.end_row && _pat5[_last + 1][_ch].effect == _c7.effect && _pat5[_last + 1][_ch].param == _c7.param) { _last += 1; }
                            _lp.fx[_es] = _fi[0];
                            _lp.fxp[_es] = _fi[1];
                            _lp.fx_end[_es] = clamp(_st + (_last - _x.row + 1) * _spr - 1, _es, MUS_STEPS - 1);
                            break;
                        }
                    }
                }
                // linked bends: from the note before, whose slides were the bend
                for (var bt = 0; bt < array_length(_bend_to); bt++)
                {
                    var _to = _bend_to[bt];
                    for (var bp = _to - 1; bp >= 0; bp--)
                    {
                        if (_lp.notes[bp] <= 0) { continue; }
                        for (var bc = bp; bc < _to; bc++)
                        {
                            if (_lp.fx[bc] == 1 || _lp.fx[bc] == 2)
                            {
                                _lp.fx[bc] = 0;
                                _lp.fxp[bc] = 0;
                                _lp.fx_end[bc] = -1;
                            }
                        }
                        music_glide_connect(_lp, bp, _to);
                        break;
                    }
                }
                // one copy of each different loop
                var _key = string(_lp.cat) + "/" + string(_lp.inst) + "/" + json_stringify([_lp.notes, _lp.lengths, _lp.insts, _lp.arps, _lp.fx, _lp.fxp, _lp.fx_end, _lp.glide_to]);
                var _li = _loop_keys[$ _key];
                if (is_undefined(_li))
                {
                    if (array_length(_arr.loops) >= MUS_LOOP_MAX)
                    {
                        mod_warn(_warn, "The MOD has more different bars than a song can hold (" + string(MUS_LOOP_MAX) + " loops) - some were left empty.");
                        continue;
                    }
                    _li = array_length(_arr.loops);
                    if (_lp.cat == 0) { _lp.name = "Drums " + string(_li + 1); }
                    else { _lp.name = string_copy(_lp.name, 1, 18) + " " + string(_li + 1); }
                    array_push(_arr.loops, _lp);
                    _loop_keys[$ _key] = _li;
                }
                _arr.lanes[v][_bar] = _li;
            }
            _bar += 1;
        }
        if (_cut_bars) { break; }
    }
    if (_cut_bars) { mod_warn(_warn, "The MOD is longer than " + string(MUS_BAR_MAX) + " bars - the rest was left off."); }
    if (_dropped_drums > 0) { mod_warn(_warn, string(_dropped_drums) + " drum hit(s) shared a bar of a channel with a tune - one SID voice plays one sound at a time, so the tune was kept."); }
    _arr.bars = clamp(_bar, 1, MUS_BAR_MAX);
    _song.loop_bar = clamp(_song.loop_bar, 0, _arr.bars - 1);
    return { song : _song, warnings : _warn };
}
