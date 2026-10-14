/// C64 NO-CODE STUDIO - .d64 disk images (a 1541 floppy: 35 tracks, 683 sectors of 256 bytes),
/// for games with a loading screen: the loader first (so LOAD"*",8,1 and VICE's autostart run
/// it), then the game, which the loader loads by name while it shows the bitmap.

function d64_sectors(_t)
{
    if (_t <= 17) { return 21; }
    if (_t <= 24) { return 19; }
    if (_t <= 30) { return 18; }
    return 17;
}

function d64_offset(_t, _s)
{
    var _o = 0;
    for (var t = 1; t < _t; t++) { _o += d64_sectors(t); }
    return (_o + _s) * 256;
}

/// A disk with files _files ({ name: PETSCII bytes, bytes: the PRG with its load address }).
/// Returns a buffer (the caller deletes it) or a string saying what went wrong.
function d64_make(_files, _disk_name)
{
    var _d = buffer_create(174848, buffer_fixed, 1);
    buffer_fill(_d, 0, buffer_u8, 0, 174848);
    var _used = [];
    for (var t = 0; t <= 35; t++) { array_push(_used, array_create(21, false)); }
    _used[18][0] = true;
    _used[18][1] = true;
    // tracks are used from the middle of the disk outwards, as the 1541 does: 17 down, then 19 up
    var _order = [];
    for (var t1 = 17; t1 >= 1; t1--) { array_push(_order, t1); }
    for (var t2 = 19; t2 <= 35; t2++) { array_push(_order, t2); }
    var _dir = [];
    for (var f = 0; f < array_length(_files); f++)
    {
        var _by = _files[f].bytes;
        var _n = array_length(_by);
        var _blocks = max(1, ceil(_n / 254));
        var _secs = [];
        var _oi = 0;
        var _s = 0;
        var _fresh = true;
        while (array_length(_secs) < _blocks)
        {
            if (_oi >= array_length(_order))
            {
                buffer_delete(_d);
                return "the game does not fit on one disk";
            }
            var _tk = _order[_oi];
            var _ns = d64_sectors(_tk);
            var _found = -1;
            // every 10th sector (the 1541's interleave), so the drive keeps up
            var _start = _fresh ? 0 : (_s + 10) mod _ns;
            for (var k = 0; k < _ns; k++)
            {
                var _try = (_start + k) mod _ns;
                if (!_used[_tk][_try]) { _found = _try; break; }
            }
            if (_found < 0)
            {
                _oi += 1;
                _fresh = true;
                continue;
            }
            _used[_tk][_found] = true;
            array_push(_secs, [_tk, _found]);
            _s = _found;
            _fresh = false;
        }
        for (var b = 0; b < _blocks; b++)
        {
            var _o = d64_offset(_secs[b][0], _secs[b][1]);
            var _from = b * 254;
            var _cnt = min(254, _n - _from);
            if (b + 1 < _blocks)
            {
                buffer_poke(_d, _o, buffer_u8, _secs[b + 1][0]);
                buffer_poke(_d, _o + 1, buffer_u8, _secs[b + 1][1]);
            }
            else
            {
                buffer_poke(_d, _o, buffer_u8, 0);
                buffer_poke(_d, _o + 1, buffer_u8, _cnt + 1);
            }
            for (var i = 0; i < _cnt; i++) { buffer_poke(_d, _o + 2 + i, buffer_u8, _by[_from + i] & 255); }
        }
        array_push(_dir, { name : _files[f].name, t : _secs[0][0], s : _secs[0][1], blocks : _blocks });
    }
    // the directory (one sector: up to 8 files)
    var _do = d64_offset(18, 1);
    buffer_poke(_d, _do, buffer_u8, 0);
    buffer_poke(_d, _do + 1, buffer_u8, 255);
    for (var e = 0; e < min(8, array_length(_dir)); e++)
    {
        var _eo = _do + e * 32;
        buffer_poke(_d, _eo + 2, buffer_u8, $82);
        buffer_poke(_d, _eo + 3, buffer_u8, _dir[e].t);
        buffer_poke(_d, _eo + 4, buffer_u8, _dir[e].s);
        for (var c = 0; c < 16; c++) { buffer_poke(_d, _eo + 5 + c, buffer_u8, (c < array_length(_dir[e].name)) ? _dir[e].name[c] : $A0); }
        buffer_poke(_d, _eo + 30, buffer_u8, _dir[e].blocks & 255);
        buffer_poke(_d, _eo + 31, buffer_u8, _dir[e].blocks >> 8);
    }
    // the BAM: which sectors are free, the disk's name and id
    var _bo = d64_offset(18, 0);
    buffer_poke(_d, _bo, buffer_u8, 18);
    buffer_poke(_d, _bo + 1, buffer_u8, 1);
    buffer_poke(_d, _bo + 2, buffer_u8, $41);
    for (var tt = 1; tt <= 35; tt++)
    {
        var _free = 0;
        var _bits = [0, 0, 0];
        for (var ss = 0; ss < d64_sectors(tt); ss++)
        {
            if (!_used[tt][ss])
            {
                _free += 1;
                _bits[ss div 8] |= 1 << (ss mod 8);
            }
        }
        var _bt = _bo + 4 * tt;
        buffer_poke(_d, _bt, buffer_u8, _free);
        buffer_poke(_d, _bt + 1, buffer_u8, _bits[0]);
        buffer_poke(_d, _bt + 2, buffer_u8, _bits[1]);
        buffer_poke(_d, _bt + 3, buffer_u8, _bits[2]);
    }
    var _nm = bmp_petscii_name(_disk_name);
    for (var q = 0; q < 16; q++) { buffer_poke(_d, _bo + $90 + q, buffer_u8, (q < array_length(_nm)) ? _nm[q] : $A0); }
    buffer_poke(_d, _bo + $A0, buffer_u8, $A0);
    buffer_poke(_d, _bo + $A1, buffer_u8, $A0);
    buffer_poke(_d, _bo + $A2, buffer_u8, 67);      // id "C6"
    buffer_poke(_d, _bo + $A3, buffer_u8, 54);
    buffer_poke(_d, _bo + $A4, buffer_u8, $A0);
    buffer_poke(_d, _bo + $A5, buffer_u8, 50);      // "2A": DOS version and format
    buffer_poke(_d, _bo + $A6, buffer_u8, 65);
    for (var z = $A7; z <= $AA; z++) { buffer_poke(_d, _bo + z, buffer_u8, $A0); }
    return _d;
}

/// After the game is built at _prg_path: the .d64 next to it, with the loading screen's loader
/// and the game. Returns the .d64's path, or a string saying why there is none.
function bmp_build_disk(_prg_path)
{
    var _pb = buffer_load(_prg_path);
    if (_pb < 0) { return "could not read " + filename_name(_prg_path); }
    var _game = [];
    for (var i = 0; i < buffer_get_size(_pb); i++) { array_push(_game, buffer_peek(_pb, i, buffer_u8)); }
    buffer_delete(_pb);
    var _gname = [71, 65, 77, 69, 32, 68, 65, 84, 65];      // "GAME DATA"
    var _ld = bmp_build_loader(proj.pictures[proj.pic_load], _gname, 2061);
    if (is_string(_ld)) { return _ld; }
    var _lname = bmp_petscii_name(proj.name);
    var _d = d64_make([{ name : _lname, bytes : _ld }, { name : _gname, bytes : _game }], proj.name);
    if (is_string(_d)) { return _d; }
    var _out = filename_change_ext(_prg_path, ".d64");
    buffer_save(_d, _out);
    buffer_delete(_d);
    return _out;
}
