/// C64 NO-CODE STUDIO - bitmaps: full-screen 320 x 200 pictures (the Bitmaps page), ported from
/// the C64 Dev Machine's bitmap editor and laid out like ADAM's Backdrop page.
///
/// A bitmap is multicolour (160 x 200, pixels twice as wide) or hi-res (320 x 200). Every pixel
/// holds a C64 colour (0-15), as one hex digit in the string pix, so the project, undo and saving
/// all stay plain JSON. The VIC-II's rule is kept at all times: each 8 x 8 cell (4 x 8 pixels in
/// multicolour) holds the background colour + 3 more (multicolour) or 2 colours (hi-res).
/// Painting a new colour into a full cell recolours the colour painted over in that whole cell,
/// just as the real screen RAM would.
///
/// In the game a bitmap is 10,003 bytes (multicolour: 8000 bitmap + 1000 screen + 1000 colour +
/// 3 settings) or 9,003 (hi-res). pic_show copies it into VIC bank 3 - bitmap $E000, screen $C000,
/// colours $D800 - shows it until fire is pressed (or for some seconds), then puts the game's
/// screen back. A loading picture costs no game memory: it goes in a small loader on a .d64 disk
/// that shows it while the KERNAL loads the game.

#macro BMP_MAX 8
#macro BMP_H 200

// ---------------------------------------------------------------------------
// Colours
// ---------------------------------------------------------------------------

function bmp_defs_init()
{
    global.BMP_RGB = [];
    global.BMP_LUMA = [];
    for (var i = 0; i < 16; i++)
    {
        var _c = global.C64PAL[i];
        array_push(global.BMP_RGB, [colour_get_red(_c), colour_get_green(_c), colour_get_blue(_c)]);
        array_push(global.BMP_LUMA, 0.299 * colour_get_red(_c) + 0.587 * colour_get_green(_c) + 0.114 * colour_get_blue(_c));
    }
    global.BMP_BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
    global.BMP_BAYER8 = [0, 32, 8, 40, 2, 34, 10, 42, 48, 16, 56, 24, 50, 18, 58, 26, 12, 44, 4, 36, 14, 46, 6, 38, 60, 28, 52, 20, 62, 30, 54, 22, 3, 35, 11, 43, 1, 33, 9, 41, 51, 19, 59, 27, 49, 17, 57, 25, 15, 47, 7, 39, 13, 45, 5, 37, 63, 31, 55, 23, 61, 29, 53, 21];
    global.BMP_LUT = array_create(32768, -1);
    global.BMP_HEX = [48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 97, 98, 99, 100, 101, 102];
    // surfaces as bytes: RGBA or BGRA? (find out once)
    var _s = surface_create(1, 1);
    surface_set_target(_s);
    draw_clear_alpha(make_colour_rgb(255, 0, 0), 1);
    surface_reset_target();
    var _b = buffer_create(4, buffer_fixed, 1);
    buffer_get_surface(_b, _s, 0);
    global.BMP_BGRA = (buffer_peek(_b, 0, buffer_u8) < 128);
    buffer_delete(_b);
    surface_free(_s);
    global.BMP_U32 = [];
    for (var k = 0; k < 16; k++)
    {
        var _rgb = global.BMP_RGB[k];
        var _v = _rgb[0] | (_rgb[1] << 8) | (_rgb[2] << 16);
        if (global.BMP_BGRA) { _v = _rgb[2] | (_rgb[1] << 8) | (_rgb[0] << 16); }
        array_push(global.BMP_U32, _v | $FF000000);
    }
}

function bmp_defs_ok()
{
    if (!variable_global_exists("BMP_U32")) { bmp_defs_init(); }
}

/// How far apart two colours look (weighted RGB)
function bmp_dist(_r, _g, _b, _k)
{
    var _p = global.BMP_RGB[_k];
    var _dr = _r - _p[0];
    var _dg = _g - _p[1];
    var _db = _b - _p[2];
    return 2 * _dr * _dr + 4 * _dg * _dg + 3 * _db * _db;
}

/// The nearest C64 colour to r, g, b (cached in 15-bit steps)
function bmp_nearest(_r, _g, _b)
{
    var _ri = clamp(floor(_r), 0, 255) >> 3;
    var _gi = clamp(floor(_g), 0, 255) >> 3;
    var _bi = clamp(floor(_b), 0, 255) >> 3;
    var _key = (_ri << 10) | (_gi << 5) | _bi;
    var _v = global.BMP_LUT[_key];
    if (_v >= 0) { return _v; }
    var _best = 0;
    var _bd = infinity;
    var _cr = _ri * 8 + 4;
    var _cg = _gi * 8 + 4;
    var _cb = _bi * 8 + 4;
    for (var k = 0; k < 16; k++)
    {
        var _d = bmp_dist(_cr, _cg, _cb, k);
        if (_d < _bd) { _bd = _d; _best = k; }
    }
    global.BMP_LUT[_key] = _best;
    return _best;
}

/// The colour of _list nearest to C64 colour _k
function bmp_nearest_in(_k, _list)
{
    var _p = global.BMP_RGB[_k];
    var _best = _list[0];
    var _bd = infinity;
    for (var i = 0; i < array_length(_list); i++)
    {
        var _d = bmp_dist(_p[0], _p[1], _p[2], _list[i]);
        if (_d < _bd) { _bd = _d; _best = _list[i]; }
    }
    return _best;
}

// ---------------------------------------------------------------------------
// The bitmap and the project
// ---------------------------------------------------------------------------

/// Width in pixels: 160 (multicolour) or 320 (hi-res)
function bmp_w(_b)
{
    return (_b.mode == 0) ? 160 : 320;
}

function bmp_new(_name, _mode)
{
    var _w = (_mode == 0) ? 160 : 320;
    return { name : _name, mode : _mode, bg : 0, border : 0, pix : string_repeat("0", _w * BMP_H) };
}

/// Bytes it takes in the game (3 settings + bitmap + screen + colours for multicolour)
function bmp_bytes(_b)
{
    return (_b.mode == 0) ? 10003 : 9003;
}

function bmp_mode_names()
{
    return ["Multicolour  160 x 200", "Hi-res  320 x 200"];
}

/// A loaded bitmap made safe
function bmp_from_loaded(_raw)
{
    var _b = bmp_new("Bitmap", 0);
    if (!is_struct(_raw)) { return _b; }
    if (is_string(_raw[$ "name"])) { _b.name = string_copy(_raw.name, 1, 24); }
    if (is_numeric(_raw[$ "mode"])) { _b.mode = clamp(floor(_raw.mode), 0, 1); }
    if (is_numeric(_raw[$ "bg"])) { _b.bg = clamp(floor(_raw.bg), 0, 15); }
    if (is_numeric(_raw[$ "border"])) { _b.border = clamp(floor(_raw.border), 0, 15); }
    var _n = bmp_w(_b) * BMP_H;
    _b.pix = string_repeat("0", _n);
    var _px = _raw[$ "pix"];
    if (is_string(_px) && string_length(_px) == _n)
    {
        // only hex digits get through
        var _t = buffer_create(_n + 1, buffer_fixed, 1);
        buffer_fill(_t, 0, buffer_u8, 0, _n + 1);
        buffer_write(_t, buffer_text, _px);
        var _ok = true;
        for (var i = 0; i < _n; i++)
        {
            var _c = buffer_peek(_t, i, buffer_u8);
            if (!((_c >= 48 && _c <= 57) || (_c >= 97 && _c <= 102))) { _ok = false; break; }
        }
        buffer_delete(_t);
        if (_ok) { _b.pix = _px; }
    }
    return _b;
}

/// After loading (or making) a project: the bitmaps and where they show
function bmp_project_fix(_p)
{
    var _raw = _p[$ "pictures"];
    var _out = [];
    if (is_array(_raw))
    {
        for (var i = 0; i < min(BMP_MAX, array_length(_raw)); i++) { array_push(_out, bmp_from_loaded(_raw[i])); }
    }
    _p.pictures = _out;
    var _n = array_length(_out);
    var _slots = ["pic_title", "pic_load", "pic_over", "pic_win"];
    for (var s = 0; s < array_length(_slots); s++)
    {
        var _v = _p[$ _slots[s]];
        if (!is_numeric(_v) || _v < 0 || _v >= _n) { _v = -1; }
        _p[$ _slots[s]] = floor(_v);
    }
    if (is_array(_p[$ "levels"]))
    {
        for (var l = 0; l < array_length(_p.levels); l++)
        {
            var _lv = _p.levels[l];
            if (!is_struct(_lv)) { continue; }
            var _lp = _lv[$ "pic"];
            if (!is_numeric(_lp) || _lp < 0 || _lp >= _n) { _lp = -1; }
            _lv.pic = floor(_lp);
        }
    }
}

/// Names for dropdowns: "None", then the bitmaps
function bmp_choice_names()
{
    var _o = ["None"];
    for (var i = 0; i < array_length(proj.pictures); i++) { array_push(_o, string(i + 1) + ": " + proj.pictures[i].name); }
    return _o;
}

/// Bitmap _i is gone: everything that showed it shows nothing, later ones move down one
function bmp_deleted(_i)
{
    var _slots = ["pic_title", "pic_load", "pic_over", "pic_win"];
    for (var s = 0; s < array_length(_slots); s++)
    {
        var _v = proj[$ _slots[s]];
        if (_v == _i) { _v = -1; }
        else if (_v > _i) { _v -= 1; }
        proj[$ _slots[s]] = _v;
    }
    for (var l = 0; l < array_length(proj.levels); l++)
    {
        var _lv = proj.levels[l];
        if (_lv[$ "pic"] == _i) { _lv.pic = -1; }
        else if (is_numeric(_lv[$ "pic"]) && _lv.pic > _i) { _lv.pic -= 1; }
    }
    for (var r = 0; r < array_length(proj.rules); r++)
    {
        var _ru = proj.rules[r];
        var _ds = [_ru];
        for (var m = 0; m < array_length(_ru.more); m++) { array_push(_ds, _ru.more[m]); }
        for (var d = 0; d < array_length(_ds); d++)
        {
            if (_ds[d].act != 19) { continue; }
            if (_ds[d].value == _i) { _ds[d].value = 0; }
            else if (_ds[d].value > _i) { _ds[d].value -= 1; }
        }
    }
}

/// Where bitmap _i shows, in words ("" = nowhere yet)
function bmp_uses(_i)
{
    var _u = [];
    if (proj.pic_title == _i) { array_push(_u, "title"); }
    if (proj.pic_load == _i) { array_push(_u, "loading"); }
    if (proj.pic_over == _i) { array_push(_u, "game over"); }
    if (proj.pic_win == _i) { array_push(_u, "you win"); }
    if (proj.game_type == 1)
    {
        for (var l = 0; l < array_length(proj.levels); l++)
        {
            if (proj.levels[l][$ "pic"] == _i) { array_push(_u, "level " + string(l + 1)); }
        }
    }
    else
    {
        var _logic = false;
        for (var r = 0; r < array_length(proj.rules); r++)
        {
            var _ru = proj.rules[r];
            if (_ru.act == 19 && _ru.value == _i) { _logic = true; }
            for (var m = 0; m < array_length(_ru.more); m++)
            {
                if (_ru.more[m].act == 19 && _ru.more[m].value == _i) { _logic = true; }
            }
        }
        if (_logic) { array_push(_u, "a rule"); }
    }
    return string_join_ext(", ", _u);
}

// ---------------------------------------------------------------------------
// Pixels: the hex string <-> a byte buffer (one byte a pixel)
// ---------------------------------------------------------------------------

function bmp_hex_to_buf(_s, _buf, _n)
{
    var _t = buffer_create(_n + 1, buffer_fixed, 1);
    buffer_fill(_t, 0, buffer_u8, 48, _n + 1);
    buffer_write(_t, buffer_text, string_copy(_s, 1, _n));
    for (var i = 0; i < _n; i++)
    {
        var _c = buffer_peek(_t, i, buffer_u8);
        var _v = _c - 48;
        if (_c >= 97) { _v = _c - 87; }
        buffer_poke(_buf, i, buffer_u8, clamp(_v, 0, 15));
    }
    buffer_delete(_t);
}

function bmp_buf_to_hex(_buf, _n)
{
    bmp_defs_ok();
    var _hx = global.BMP_HEX;
    var _t = buffer_create(_n + 1, buffer_fixed, 1);
    for (var i = 0; i < _n; i++) { buffer_poke(_t, i, buffer_u8, _hx[buffer_peek(_buf, i, buffer_u8) & 15]); }
    buffer_poke(_t, _n, buffer_u8, 0);
    var _s = buffer_peek(_t, 0, buffer_string);
    buffer_delete(_t);
    return _s;
}

/// The bitmap's pixels as an array (for building and saving files)
function bmp_pix_array(_b)
{
    var _n = bmp_w(_b) * BMP_H;
    var _buf = buffer_create(_n, buffer_fixed, 1);
    bmp_hex_to_buf(_b.pix, _buf, _n);
    var _a = array_create(_n, 0);
    for (var i = 0; i < _n; i++) { _a[i] = buffer_peek(_buf, i, buffer_u8); }
    buffer_delete(_buf);
    return _a;
}

function bmp_pix_from_array(_a)
{
    var _n = array_length(_a);
    var _buf = buffer_create(_n, buffer_fixed, 1);
    for (var i = 0; i < _n; i++) { buffer_poke(_buf, i, buffer_u8, _a[i] & 15); }
    var _s = bmp_buf_to_hex(_buf, _n);
    buffer_delete(_buf);
    return _s;
}

// ---------------------------------------------------------------------------
// The VIC-II's colours per cell
// ---------------------------------------------------------------------------

/// Sets pixel (x, y) of buffer _buf to colour _c keeping the cell's colour limit: a new colour
/// in a full cell takes over the colour it paints on, in the whole cell (multicolour: painting on
/// the background in a full cell moves the cell's rarest colour to its nearest one first).
/// Returns true when anything changed.
function bmp_plot(_b, _buf, _x, _y, _c)
{
    var _w = (_b.mode == 0) ? 160 : 320;
    if (_x < 0 || _y < 0 || _x >= _w || _y >= BMP_H) { return false; }
    var _i = _y * _w + _x;
    var _old = buffer_peek(_buf, _i, buffer_u8);
    if (_old == _c) { return false; }
    var _mc = (_b.mode == 0);
    if (_mc && _c == _b.bg)
    {
        buffer_poke(_buf, _i, buffer_u8, _c);
        return true;
    }
    var _cw = _mc ? 4 : 8;
    var _x0 = (_x div _cw) * _cw;
    var _y0 = (_y div 8) * 8;
    var _cnt = array_create(16, 0);
    for (var yy = 0; yy < 8; yy++)
    {
        var _row = (_y0 + yy) * _w + _x0;
        for (var xx = 0; xx < _cw; xx++) { _cnt[buffer_peek(_buf, _row + xx, buffer_u8)] += 1; }
    }
    if (_cnt[_c] > 0)
    {
        buffer_poke(_buf, _i, buffer_u8, _c);
        return true;
    }
    var _n = 0;
    for (var k = 0; k < 16; k++)
    {
        if (_cnt[k] > 0 && !(_mc && k == _b.bg)) { _n += 1; }
    }
    var _lim = _mc ? 3 : 2;
    if (_n < _lim)
    {
        buffer_poke(_buf, _i, buffer_u8, _c);
        return true;
    }
    if (!(_mc && _old == _b.bg))
    {
        // the colour painted on becomes the new colour in the whole cell
        for (var y2 = 0; y2 < 8; y2++)
        {
            var _r2 = (_y0 + y2) * _w + _x0;
            for (var x2 = 0; x2 < _cw; x2++)
            {
                if (buffer_peek(_buf, _r2 + x2, buffer_u8) == _old) { buffer_poke(_buf, _r2 + x2, buffer_u8, _c); }
            }
        }
        return true;
    }
    // multicolour, painting on the background of a full cell: its rarest colour makes room
    var _z = -1;
    var _zn = 999;
    var _keep = [_b.bg];
    for (var k2 = 0; k2 < 16; k2++)
    {
        if (_cnt[k2] > 0 && k2 != _b.bg && _cnt[k2] < _zn) { _zn = _cnt[k2]; _z = k2; }
    }
    for (var k3 = 0; k3 < 16; k3++)
    {
        if (_cnt[k3] > 0 && k3 != _b.bg && k3 != _z) { array_push(_keep, k3); }
    }
    var _to = bmp_nearest_in(_z, _keep);
    for (var y3 = 0; y3 < 8; y3++)
    {
        var _r3 = (_y0 + y3) * _w + _x0;
        for (var x3 = 0; x3 < _cw; x3++)
        {
            if (buffer_peek(_buf, _r3 + x3, buffer_u8) == _z) { buffer_poke(_buf, _r3 + x3, buffer_u8, _to); }
        }
    }
    buffer_poke(_buf, _i, buffer_u8, _c);
    return true;
}

/// Brings the cells overlapping pixels x1..x2, y1..y2 within the VIC-II's limit: each keeps its
/// most used colours (and the background), the rest move to the nearest kept one
function bmp_reduce(_b, _buf, _x1, _y1, _x2, _y2)
{
    bmp_defs_ok();
    var _w = bmp_w(_b);
    var _mc = (_b.mode == 0);
    var _cw = _mc ? 4 : 8;
    var _lim = _mc ? 3 : 2;
    var _cx1 = max(0, _x1) div _cw;
    var _cx2 = min(_w - 1, _x2) div _cw;
    var _cy1 = max(0, _y1) div 8;
    var _cy2 = min(BMP_H - 1, _y2) div 8;
    for (var cy = _cy1; cy <= _cy2; cy++)
    {
        for (var cx = _cx1; cx <= _cx2; cx++)
        {
            var _cnt = array_create(16, 0);
            for (var yy = 0; yy < 8; yy++)
            {
                var _row = (cy * 8 + yy) * _w + cx * _cw;
                for (var xx = 0; xx < _cw; xx++) { _cnt[buffer_peek(_buf, _row + xx, buffer_u8)] += 1; }
            }
            var _keep = [];
            if (_mc) { array_push(_keep, _b.bg); }
            var _used = 0;
            for (var k = 0; k < 16; k++)
            {
                if (_cnt[k] > 0 && !(_mc && k == _b.bg)) { _used += 1; }
            }
            if (_used <= _lim) { continue; }
            repeat (_lim)
            {
                var _bk = -1;
                var _bn = 0;
                for (var k2 = 0; k2 < 16; k2++)
                {
                    if (_mc && k2 == _b.bg) { continue; }
                    if (_cnt[k2] > _bn) { _bn = _cnt[k2]; _bk = k2; }
                }
                if (_bk < 0) { break; }
                array_push(_keep, _bk);
                _cnt[_bk] = 0;
            }
            var _map = array_create(16, -1);
            for (var y2 = 0; y2 < 8; y2++)
            {
                var _r2 = (cy * 8 + y2) * _w + cx * _cw;
                for (var x2 = 0; x2 < _cw; x2++)
                {
                    var _v = buffer_peek(_buf, _r2 + x2, buffer_u8);
                    var _ok = false;
                    for (var q = 0; q < array_length(_keep); q++)
                    {
                        if (_keep[q] == _v) { _ok = true; break; }
                    }
                    if (_ok) { continue; }
                    if (_map[_v] < 0) { _map[_v] = bmp_nearest_in(_v, _keep); }
                    buffer_poke(_buf, _r2 + x2, buffer_u8, _map[_v]);
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// The C64's bytes: bitmap (cell order), screen RAM and colour RAM
// ---------------------------------------------------------------------------

/// { bmp[8000], scr[1000], col[1000] } as the VIC-II wants them
function bmp_encode(_b)
{
    bmp_defs_ok();
    var _px = bmp_pix_array(_b);
    var _w = bmp_w(_b);
    var _mc = (_b.mode == 0);
    var _bmp = array_create(8000, 0);
    var _scr = array_create(1000, 0);
    var _col = array_create(1000, 0);
    for (var cy = 0; cy < 25; cy++)
    {
        for (var cx = 0; cx < 40; cx++)
        {
            var _cell = cy * 40 + cx;
            var _cnt = array_create(16, 0);
            var _cw = _mc ? 4 : 8;
            for (var yy = 0; yy < 8; yy++)
            {
                for (var xx = 0; xx < _cw; xx++) { _cnt[_px[(cy * 8 + yy) * _w + cx * _cw + xx]] += 1; }
            }
            if (_mc) { _cnt[_b.bg] = 0; }
            // colours by how much they are used, most first
            var _order = [];
            for (var n = 0; n < 16; n++)
            {
                var _bk = -1;
                var _bn = 0;
                for (var k = 0; k < 16; k++)
                {
                    if (_cnt[k] > _bn) { _bn = _cnt[k]; _bk = k; }
                }
                if (_bk < 0) { break; }
                array_push(_order, _bk);
                _cnt[_bk] = 0;
            }
            if (_mc)
            {
                var _c1 = (array_length(_order) > 0) ? _order[0] : 0;
                var _c2 = (array_length(_order) > 1) ? _order[1] : _c1;
                var _c3 = (array_length(_order) > 2) ? _order[2] : _c1;
                _scr[_cell] = (_c1 << 4) | _c2;
                _col[_cell] = _c3;
                var _set = [_b.bg, _c1, _c2, _c3];
                for (var r = 0; r < 8; r++)
                {
                    var _byte = 0;
                    for (var p = 0; p < 4; p++)
                    {
                        var _v = _px[(cy * 8 + r) * _w + cx * 4 + p];
                        var _bits = 0;
                        if (_v == _b.bg) { _bits = 0; }
                        else if (_v == _c1) { _bits = 1; }
                        else if (_v == _c2) { _bits = 2; }
                        else if (_v == _c3) { _bits = 3; }
                        else
                        {
                            var _nv = bmp_nearest_in(_v, _set);
                            for (var s = 0; s < 4; s++) { if (_set[s] == _nv) { _bits = s; break; } }
                        }
                        _byte |= _bits << (6 - p * 2);
                    }
                    _bmp[_cell * 8 + r] = _byte;
                }
            }
            else
            {
                // hi-res: the most used colour is the cell's background, the next its ink
                var _bgc = (array_length(_order) > 0) ? _order[0] : 0;
                var _fg = (array_length(_order) > 1) ? _order[1] : _bgc;
                _scr[_cell] = (_fg << 4) | _bgc;
                for (var r2 = 0; r2 < 8; r2++)
                {
                    var _byte2 = 0;
                    for (var p2 = 0; p2 < 8; p2++)
                    {
                        var _v2 = _px[(cy * 8 + r2) * _w + cx * 8 + p2];
                        var _on = (_v2 != _bgc && _fg != _bgc);
                        if (_on && _v2 != _fg) { _on = (bmp_nearest_in(_v2, [_bgc, _fg]) == _fg); }
                        if (_on) { _byte2 |= 1 << (7 - p2); }
                    }
                    _bmp[_cell * 8 + r2] = _byte2;
                }
            }
        }
    }
    return { bmp : _bmp, scr : _scr, col : _col };
}

/// Pixels from the C64's bytes (buffer _d from offset _o: bitmap, screen, then colour RAM)
function bmp_decode(_b, _d, _o)
{
    var _w = bmp_w(_b);
    var _a = array_create(_w * BMP_H, 0);
    for (var cy = 0; cy < 25; cy++)
    {
        for (var cx = 0; cx < 40; cx++)
        {
            var _cell = cy * 40 + cx;
            var _s = buffer_peek(_d, _o + 8000 + _cell, buffer_u8);
            if (_b.mode == 0)
            {
                var _set = [_b.bg, _s >> 4, _s & 15, buffer_peek(_d, _o + 9000 + _cell, buffer_u8) & 15];
                for (var r = 0; r < 8; r++)
                {
                    var _byte = buffer_peek(_d, _o + _cell * 8 + r, buffer_u8);
                    for (var p = 0; p < 4; p++) { _a[(cy * 8 + r) * 160 + cx * 4 + p] = _set[(_byte >> (6 - p * 2)) & 3]; }
                }
            }
            else
            {
                for (var r2 = 0; r2 < 8; r2++)
                {
                    var _byte2 = buffer_peek(_d, _o + _cell * 8 + r2, buffer_u8);
                    for (var p2 = 0; p2 < 8; p2++) { _a[(cy * 8 + r2) * 320 + cx * 8 + p2] = ((_byte2 >> (7 - p2)) & 1) ? (_s >> 4) : (_s & 15); }
                }
            }
        }
    }
    _b.pix = bmp_pix_from_array(_a);
}

// ---------------------------------------------------------------------------
// Files: Koala Painter (.kla / .koa, multicolour) and Art Studio (.art, hi-res)
// ---------------------------------------------------------------------------

/// A bitmap from a Koala or Art Studio file, or a string saying why not
function bmp_load_c64_file(_path)
{
    var _d = buffer_load(_path);
    if (_d < 0) { return "Could not read " + filename_name(_path); }
    var _n = buffer_get_size(_d);
    var _ext = string_lower(filename_ext(_path));
    var _name = string_copy(filename_change_ext(filename_name(_path), ""), 1, 24);
    var _b = undefined;
    if (_n == 10003 || _n == 10001 || ((_ext == ".kla" || _ext == ".koa") && _n >= 10001))
    {
        var _o = (_n >= 10003) ? 2 : 0;
        _b = bmp_new(_name, 0);
        _b.bg = buffer_peek(_d, _o + 10000, buffer_u8) & 15;
        bmp_decode(_b, _d, _o);
    }
    else if (_n >= 9000 && _n <= 9011)
    {
        var _o2 = (_n >= 9002) ? 2 : 0;
        _b = bmp_new(_name, 1);
        if (_n >= _o2 + 9001) { _b.border = buffer_peek(_d, _o2 + 9000, buffer_u8) & 15; }
        bmp_decode(_b, _d, _o2);
    }
    buffer_delete(_d);
    if (is_undefined(_b)) { return filename_name(_path) + " is not a Koala (10003 bytes) or Art Studio (9002-9009 bytes) picture"; }
    return _b;
}

/// Saves a Koala file (multicolour) or an Art Studio file (hi-res)
function bmp_save_c64_file(_b, _path)
{
    var _e = bmp_encode(_b);
    var _mc = (_b.mode == 0);
    var _n = _mc ? 10003 : 9009;
    var _d = buffer_create(_n, buffer_fixed, 1);
    buffer_fill(_d, 0, buffer_u8, 0, _n);
    buffer_poke(_d, 0, buffer_u8, 0);
    buffer_poke(_d, 1, buffer_u8, _mc ? $60 : $20);
    for (var i = 0; i < 8000; i++) { buffer_poke(_d, 2 + i, buffer_u8, _e.bmp[i]); }
    for (var k = 0; k < 1000; k++) { buffer_poke(_d, 8002 + k, buffer_u8, _e.scr[k]); }
    if (_mc)
    {
        for (var c = 0; c < 1000; c++) { buffer_poke(_d, 9002 + c, buffer_u8, _e.col[c]); }
        buffer_poke(_d, 10002, buffer_u8, _b.bg);
    }
    else { buffer_poke(_d, 9002, buffer_u8, _b.border); }
    buffer_save(_d, _path);
    buffer_delete(_d);
}

/// Draws the bitmap 1:1 into a new 320 x 200 surface (the caller frees it)
function bmp_to_surface(_b)
{
    bmp_defs_ok();
    var _w = bmp_w(_b);
    var _src = buffer_create(_w * BMP_H, buffer_fixed, 1);
    bmp_hex_to_buf(_b.pix, _src, _w * BMP_H);
    var _rgba = buffer_create(320 * BMP_H * 4, buffer_fixed, 1);
    bmp_render_rows(_b, _src, _rgba, 0, BMP_H - 1);
    var _s = surface_create(320, BMP_H);
    buffer_set_surface(_rgba, _s, 0);
    buffer_delete(_src);
    buffer_delete(_rgba);
    return _s;
}

/// Writes rows y1..y2 of pixel buffer _src as 320-wide RGBA into _rgba
function bmp_render_rows(_b, _src, _rgba, _y1, _y2)
{
    var _u = global.BMP_U32;
    if (_b.mode == 0)
    {
        for (var _py = _y1; _py <= _y2; _py++)
        {
            var _si = _py * 160;
            var _di = _py * 1280;
            for (var _px = 0; _px < 160; _px++)
            {
                var _v = _u[buffer_peek(_src, _si + _px, buffer_u8)];
                buffer_poke(_rgba, _di, buffer_u32, _v);
                buffer_poke(_rgba, _di + 4, buffer_u32, _v);
                _di += 8;
            }
        }
    }
    else
    {
        for (var y2 = _y1; y2 <= _y2; y2++)
        {
            var _si2 = y2 * 320;
            var _di2 = y2 * 1280;
            for (var x2 = 0; x2 < 320; x2++)
            {
                buffer_poke(_rgba, _di2, buffer_u32, _u[buffer_peek(_src, _si2 + x2, buffer_u8)]);
                _di2 += 4;
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Pictures from PNG / JPG: fit, adjust, dither, then the VIC-II's colours per cell
// ---------------------------------------------------------------------------

function bmp_import_settings_new(_mode)
{
    return { mode : _mode, fit : 0, zoom : 100, offx : 0, offy : 0, dither : 5, amount : 75, bright : 0, contrast : 0, sat : 100, hue : 0, blur : 0, bg : -1 };
}

/// Old settings (or none) made complete
function bmp_import_settings_fix(_st)
{
    var _d = bmp_import_settings_new(0);
    var _k = variable_struct_get_names(_d);
    for (var i = 0; i < array_length(_k); i++)
    {
        if (!is_numeric(_st[$ _k[i]])) { _st[$ _k[i]] = _d[$ _k[i]]; }
    }
    return _st;
}

function bmp_fit_names()
{
    return ["Fit (whole picture)", "Fill (crop the edges)", "Stretch"];
}

/// The Dev Machine's dither patterns, plus two error-spreading ones
function bmp_dither_names()
{
    return ["No dither", "Checker", "Lines", "Bayer 4 x 4", "Bayer 8 x 8", "Smooth (Floyd-Steinberg)", "Soft (Atkinson)"];
}

/// Converts sprite _spr (a loaded picture) with settings _st: { pix, bg }
/// Order: place (fit, zoom, move) -> softness -> brightness, contrast, colourfulness, hue -> dither
/// to the 16 colours -> each cell keeps its most used colours.
function bmp_convert(_spr, _st)
{
    bmp_defs_ok();
    bmp_import_settings_fix(_st);
    var _mc = (_st.mode == 0);
    var _W = _mc ? 160 : 320;
    var _iw = max(1, sprite_get_width(_spr));
    var _ih = max(1, sprite_get_height(_spr));
    var _sx = 320 / _iw;
    var _sy = 200 / _ih;
    if (_st.fit == 0) { _sx = min(_sx, _sy); _sy = _sx; }
    if (_st.fit == 1) { _sx = max(_sx, _sy); _sy = _sx; }
    _sx *= _st.zoom / 100;
    _sy *= _st.zoom / 100;
    var _dw = _iw * _sx;
    var _dh = _ih * _sy;
    // move: -100 puts the picture's left (top) edge on the screen's, +100 its right (bottom) edge
    var _px = (320 - _dw) / 2 * (1 + _st.offx / 100);
    var _py = (200 - _dh) / 2 * (1 + _st.offy / 100);
    var _s1 = surface_create(320, 200);
    var _s2 = surface_create(_W, 200);
    var _tf = gpu_get_texfilter();
    gpu_set_texfilter(true);
    surface_set_target(_s1);
    draw_clear_alpha(c_black, 1);
    draw_sprite_ext(_spr, 0, _px, _py, _sx, _sy, 0, c_white, 1);
    surface_reset_target();
    // multicolour pixels are two wide: halving the width averages each pair
    surface_set_target(_s2);
    draw_clear_alpha(c_black, 1);
    draw_surface_ext(_s1, 0, 0, _W / 320, 1, 0, c_white, 1);
    surface_reset_target();
    gpu_set_texfilter(_tf);
    var _n = _W * 200;
    var _rb = buffer_create(_n * 4, buffer_fixed, 1);
    buffer_get_surface(_rb, _s2, 0);
    surface_free(_s1);
    surface_free(_s2);
    var _R = array_create(_n, 0);
    var _G = array_create(_n, 0);
    var _B = array_create(_n, 0);
    var _ro = global.BMP_BGRA ? 2 : 0;
    var _bo = global.BMP_BGRA ? 0 : 2;
    for (var i = 0; i < _n; i++)
    {
        _R[i] = buffer_peek(_rb, i * 4 + _ro, buffer_u8);
        _G[i] = buffer_peek(_rb, i * 4 + 1, buffer_u8);
        _B[i] = buffer_peek(_rb, i * 4 + _bo, buffer_u8);
    }
    buffer_delete(_rb);
    // softness: a box blur, across then down (multicolour pixels are already two wide)
    var _rad = clamp(round(_st.blur), 0, 4);
    if (_rad > 0)
    {
        var _ch = [_R, _G, _B];
        for (var c = 0; c < 3; c++)
        {
            var _a = _ch[c];
            var _t = array_create(_n, 0);
            var _rx = _mc ? max(1, _rad div 2) : _rad;
            for (var yy = 0; yy < 200; yy++)
            {
                for (var xx = 0; xx < _W; xx++)
                {
                    var _s = 0;
                    var _k = 0;
                    for (var d = -_rx; d <= _rx; d++)
                    {
                        var _q = xx + d;
                        if (_q >= 0 && _q < _W) { _s += _a[yy * _W + _q]; _k += 1; }
                    }
                    _t[yy * _W + xx] = _s / _k;
                }
            }
            for (var yy2 = 0; yy2 < 200; yy2++)
            {
                for (var xx2 = 0; xx2 < _W; xx2++)
                {
                    var _s2b = 0;
                    var _k2 = 0;
                    for (var d2 = -_rad; d2 <= _rad; d2++)
                    {
                        var _q2 = yy2 + d2;
                        if (_q2 >= 0 && _q2 < 200) { _s2b += _t[_q2 * _W + xx2]; _k2 += 1; }
                    }
                    _a[yy2 * _W + xx2] = _s2b / _k2;
                }
            }
        }
    }
    // brightness, contrast, then colourfulness and hue together (YIQ: turn and scale the colour part)
    var _cf = (100 + _st.contrast) / 100;
    _cf = _cf * _cf;
    var _br = _st.bright * 1.28;
    var _sat = _st.sat / 100;
    var _hc = dcos(_st.hue) * _sat;
    var _hs = dsin(_st.hue) * _sat;
    for (var i2 = 0; i2 < _n; i2++)
    {
        var _r = (_R[i2] - 128) * _cf + 128 + _br;
        var _g = (_G[i2] - 128) * _cf + 128 + _br;
        var _b = (_B[i2] - 128) * _cf + 128 + _br;
        var _Y = 0.299 * _r + 0.587 * _g + 0.114 * _b;
        var _I = 0.596 * _r - 0.274 * _g - 0.322 * _b;
        var _Q = 0.211 * _r - 0.523 * _g + 0.312 * _b;
        var _I2 = _I * _hc - _Q * _hs;
        var _Q2 = _I * _hs + _Q * _hc;
        _R[i2] = clamp(_Y + 0.956 * _I2 + 0.621 * _Q2, 0, 255);
        _G[i2] = clamp(_Y - 0.272 * _I2 - 0.647 * _Q2, 0, 255);
        _B[i2] = clamp(_Y - 1.106 * _I2 + 1.703 * _Q2, 0, 255);
    }
    // to the 16 colours
    var _q = array_create(_n, 0);
    var _amt = clamp(_st.amount, 0, 100) / 100;
    if (_st.dither >= 5)
    {
        // error spreading: Floyd-Steinberg passes on all of a pixel's error, Atkinson 3/4 of it
        var _er = array_create(_n, 0);
        var _eg = array_create(_n, 0);
        var _eb = array_create(_n, 0);
        var _fs = (_st.dither == 5);
        for (var py = 0; py < 200; py++)
        {
            for (var px = 0; px < _W; px++)
            {
                var _k3 = py * _W + px;
                var _r2 = clamp(_R[_k3] + _er[_k3], 0, 255);
                var _g2 = clamp(_G[_k3] + _eg[_k3], 0, 255);
                var _b2 = clamp(_B[_k3] + _eb[_k3], 0, 255);
                var _cc = bmp_nearest(_r2, _g2, _b2);
                _q[_k3] = _cc;
                var _p = global.BMP_RGB[_cc];
                var _dr = (_r2 - _p[0]) * _amt;
                var _dg = (_g2 - _p[1]) * _amt;
                var _db = (_b2 - _p[2]) * _amt;
                var _to = _fs ? [[1, 0, 7], [-1, 1, 3], [0, 1, 5], [1, 1, 1]] : [[1, 0, 2], [2, 0, 2], [-1, 1, 2], [0, 1, 2], [1, 1, 2], [0, 2, 2]];
                var _div = 16;
                for (var t = 0; t < array_length(_to); t++)
                {
                    var _nx = px + _to[t][0];
                    var _ny = py + _to[t][1];
                    if (_nx < 0 || _nx >= _W || _ny >= 200) { continue; }
                    var _kk = _ny * _W + _nx;
                    var _f = _to[t][2] / _div;
                    _er[_kk] += _dr * _f;
                    _eg[_kk] += _dg * _f;
                    _eb[_kk] += _db * _f;
                }
            }
        }
    }
    else
    {
        // ordered: a fixed pattern nudges each pixel lighter or darker before the nearest colour
        var _b4 = global.BMP_BAYER;
        var _b8 = global.BMP_BAYER8;
        var _spread = _amt * 96;
        for (var y3 = 0; y3 < 200; y3++)
        {
            for (var x3 = 0; x3 < _W; x3++)
            {
                var _k4 = y3 * _W + x3;
                var _t01 = 0.5;
                switch (_st.dither)
                {
                    case 1: _t01 = ((x3 + y3) & 1) ? 0.75 : 0.25; break;
                    case 2: _t01 = (y3 & 1) ? 0.75 : 0.25; break;
                    case 3: _t01 = (_b4[(y3 & 3) * 4 + (x3 & 3)] + 0.5) / 16; break;
                    case 4: _t01 = (_b8[(y3 & 7) * 8 + (x3 & 7)] + 0.5) / 64; break;
                }
                var _off = (_st.dither == 0) ? 0 : (_t01 - 0.5) * _spread;
                _q[_k4] = bmp_nearest(_R[_k4] + _off, _G[_k4] + _off, _B[_k4] + _off);
            }
        }
    }
    // multicolour: the background is the most used colour (or the one chosen)
    var _bg = _st.bg;
    if (_mc && _bg < 0)
    {
        var _tot = array_create(16, 0);
        for (var t2 = 0; t2 < _n; t2++) { _tot[_q[t2]] += 1; }
        _bg = 0;
        for (var t3 = 1; t3 < 16; t3++) { if (_tot[t3] > _tot[_bg]) { _bg = t3; } }
    }
    if (!_mc) { _bg = 0; }
    // each cell keeps its most used colours; other pixels take the kept colour nearest their own
    var _cw = _mc ? 4 : 8;
    var _lim = _mc ? 3 : 2;
    for (var cy = 0; cy < 25; cy++)
    {
        for (var cx = 0; cx < 40; cx++)
        {
            var _cnt = array_create(16, 0);
            for (var y4 = 0; y4 < 8; y4++)
            {
                for (var x4 = 0; x4 < _cw; x4++) { _cnt[_q[(cy * 8 + y4) * _W + cx * _cw + x4]] += 1; }
            }
            var _keep = [];
            if (_mc) { array_push(_keep, _bg); _cnt[_bg] = 0; }
            var _used = 0;
            for (var k = 0; k < 16; k++) { if (_cnt[k] > 0) { _used += 1; } }
            if (_used <= _lim) { continue; }
            repeat (_lim)
            {
                var _bk = 0;
                for (var k2 = 1; k2 < 16; k2++) { if (_cnt[k2] > _cnt[_bk]) { _bk = k2; } }
                array_push(_keep, _bk);
                _cnt[_bk] = 0;
            }
            for (var y5 = 0; y5 < 8; y5++)
            {
                for (var x5 = 0; x5 < _cw; x5++)
                {
                    var _k5 = (cy * 8 + y5) * _W + cx * _cw + x5;
                    var _ok = false;
                    for (var qq = 0; qq < array_length(_keep); qq++) { if (_keep[qq] == _q[_k5]) { _ok = true; break; } }
                    if (_ok) { continue; }
                    var _best = _keep[0];
                    var _bd = infinity;
                    for (var q2 = 0; q2 < array_length(_keep); q2++)
                    {
                        var _dd = bmp_dist(_R[_k5], _G[_k5], _B[_k5], _keep[q2]);
                        if (_dd < _bd) { _bd = _dd; _best = _keep[q2]; }
                    }
                    _q[_k5] = _best;
                }
            }
        }
    }
    return { pix : bmp_pix_from_array(_q), bg : _bg };
}

// ---------------------------------------------------------------------------
// In the game: pic_show and the bitmaps' data
// ---------------------------------------------------------------------------

/// The bitmaps the game shows (in slot order): title, game over, you win, the levels' (map
/// games) and the rules' (single screen). The loading picture is on the disk, not in the game.
function bmp_game_list(_p)
{
    var _l = [];
    var _add = function(_l, _i, _n)
    {
        if (_i < 0 || _i >= _n) { return; }
        for (var k = 0; k < array_length(_l); k++) { if (_l[k] == _i) { return; } }
        array_push(_l, _i);
    };
    var _n = array_length(_p.pictures);
    _add(_l, _p.pic_title, _n);
    _add(_l, _p.pic_over, _n);
    _add(_l, _p.pic_win, _n);
    if (_p.game_type == 1)
    {
        for (var l = 0; l < min(8, array_length(_p.levels)); l++) { _add(_l, bmp_level_pic(_p.levels[l]), _n); }
    }
    else
    {
        for (var r = 0; r < array_length(_p.rules); r++)
        {
            if (group_off_in(_p.groups, _p.rules[r].group)) { continue; }
            var _ds = [_p.rules[r]];
            for (var m = 0; m < array_length(_p.rules[r].more); m++) { array_push(_ds, _p.rules[r].more[m]); }
            for (var d = 0; d < array_length(_ds); d++)
            {
                if (_ds[d].act == 19) { _add(_l, _ds[d].value, _n); }
            }
        }
    }
    return _l;
}

/// The slot (0..) of bitmap _i in list _l, or 255 when it is not shown
function bmp_slot(_l, _i)
{
    for (var k = 0; k < array_length(_l); k++) { if (_l[k] == _i) { return k; } }
    return 255;
}

/// One bitmap as the game's data: mode (1 = multicolour), background, border, then the bytes
function bmp_emit_data(L, _b, _label)
{
    var _e = bmp_encode(_b);
    array_push(L, _label + ":", " .byte " + string((_b.mode == 0) ? 1 : 0) + "," + string(_b.bg) + "," + string(_b.border));
    for (var i = 0; i < 8000; i += 40) { array_push(L, " .byte " + cg_join_bytes(_e.bmp, i, 40)); }
    for (var k = 0; k < 1000; k += 40) { array_push(L, " .byte " + cg_join_bytes(_e.scr, k, 40)); }
    if (_b.mode == 0)
    {
        for (var c = 0; c < 1000; c += 40) { array_push(L, " .byte " + cg_join_bytes(_e.col, c, 40)); }
    }
}

/// The copy loop shared by the game and the loader: (S) -> (D), X pages then A bytes; S moves on
function bmp_emit_copy(L, _s, _d)
{
    array_push(L, "pic_adv:", " clc", " adc " + _s, " sta " + _s, " bcc bmq_pa1", " inc " + _s + "+1", "bmq_pa1:", " rts");
    array_push(L, "pic_copy:", " sta pic_rem", " ldy #0", " cpx #0", " beq bmq_pcr");
    array_push(L, "bmq_pcp:", " lda (" + _s + "),y", " sta (" + _d + "),y", " iny", " bne bmq_pcp", " inc " + _s + "+1", " inc " + _d + "+1", " dex", " bne bmq_pcp");
    array_push(L, "bmq_pcr:", " ldy #0", " lda pic_rem", " beq bmq_pcx");
    array_push(L, "bmq_pcrl:", " lda (" + _s + "),y", " sta (" + _d + "),y", " iny", " cpy pic_rem", " bne bmq_pcrl", " tya", " jmp pic_adv");
    array_push(L, "bmq_pcx:", " rts");
}

/// Copies the bitmap at (S) to bank 3 ($E000 bitmap, $C000 screen, $D800 colours) and switches the
/// VIC-II to it (bank 3 is set by the caller)
function bmp_emit_put(L, _s, _d)
{
    array_push(L, " ldy #0", " lda (" + _s + "),y", " sta pic_fl", " iny", " lda (" + _s + "),y", " sta $d021", " iny", " lda (" + _s + "),y", " sta $d020", " lda #3", " jsr pic_adv");
    array_push(L, " lda #0", " sta " + _d, " lda #$e0", " sta " + _d + "+1", " ldx #31", " lda #64", " jsr pic_copy");
    array_push(L, " lda #0", " sta " + _d, " lda #$c0", " sta " + _d + "+1", " ldx #3", " lda #232", " jsr pic_copy");
    array_push(L, " lda pic_fl", " beq bmq_pphr");
    array_push(L, " lda #0", " sta " + _d, " lda #$d8", " sta " + _d + "+1", " ldx #3", " lda #232", " jsr pic_copy", " lda #$18", " bne bmq_ppmd");
    array_push(L, "bmq_pphr:", " lda #$08");
    array_push(L, "bmq_ppmd:", " sta $d016", " lda #$08", " sta $d018");
}

/// pic_show (A = slot, X = seconds, 0 = until fire is pressed and let go) and pic_maybe (A = slot
/// or 255) for game kind _kind (0 single screen, 1 map engine), with the bitmaps of list _l
function bmp_emit_game(L, _p, _l, _kind)
{
    var _s = (_kind == 0) ? "$fd" : "zp_s";
    var _d = (_kind == 0) ? "$fb" : "zp_d";
    array_push(L, "; ---------------- bitmaps (Bitmaps page) ----------------", "pic_start:");
    array_push(L, "pic_maybe:", " cmp #255", " bne pic_m1", " rts", "pic_m1:", " ldx #0");
    array_push(L, "pic_show:", " stx pic_secs", " tay", " lda pic_tlo,y", " sta " + _s, " lda pic_thi,y", " sta " + _s + "+1");
    array_push(L, " lda #0", " sta $d015", " lda #$0b", " sta $d011", " lda $d020", " sta pic_sv0", " lda $d021", " sta pic_sv1");
    if (_kind == 1) { array_push(L, " lda #1", " sta pic_on"); }
    else { array_push(L, " lda $dd00", " and #$fc", " sta $dd00"); }
    bmp_emit_put(L, _s, _d);
    array_push(L, " lda #$3b", " sta $d011", " lda #0", " sta pic_ph", " sta pic_fr");
    // once a frame: sounds and music go on; count the seconds or watch the fire button
    array_push(L, "bmq_pwloop:");
    if (_kind == 1) { array_push(L, "bmq_pwf:", " lda frame_flag", " beq bmq_pwf", " lda #0", " sta frame_flag"); }
    else { array_push(L, "bmq_pwf:", " lda $d012", " cmp #250", " bne bmq_pwf", "bmq_pwg:", " lda $d012", " cmp #250", " beq bmq_pwg"); }
    array_push(L, " jsr sfx_update", " lda pic_secs", " beq bmq_pwfire");
    array_push(L, " inc pic_fr", " lda pic_fr", " cmp #" + string(sid_fps()), " bcc bmq_pwloop", " lda #0", " sta pic_fr", " dec pic_secs", " bne bmq_pwloop", " beq bmq_pwdone");
    array_push(L, "bmq_pwfire:", " lda $dc00", " and #16", " sta pic_t", " lda pic_ph", " beq bmq_pwp0", " cmp #1", " beq bmq_pwp1");
    array_push(L, " lda pic_t", " beq bmq_pwloop", " bne bmq_pwdone");
    array_push(L, "bmq_pwp0:", " lda pic_t", " beq bmq_pwloop", " inc pic_ph", " bne bmq_pwloop");
    array_push(L, "bmq_pwp1:", " lda pic_t", " bne bmq_pwloop", " inc pic_ph", " bne bmq_pwloop");
    // back to the game's screen
    array_push(L, "bmq_pwdone:", " lda #$0b", " sta $d011");
    if (_kind == 1)
    {
        array_push(L, " jsr copy_assets", " lda #$0c", " sta $d018", " lda pic_sv0", " sta $d020", " lda pic_sv1", " sta $d021");
        array_push(L, " sei", " lda #0", " sta irq_stage", " sta pic_on", " lda #IRQ1_LINE", " sta $d012", " lda #$ff", " sta $d019", " cli", " rts");
    }
    else
    {
        array_push(L, " lda $dd00", " ora #3", " sta $dd00", " lda #$15", " sta $d018", " lda #$c8", " sta $d016");
        array_push(L, " lda pic_sv0", " sta $d020", " lda pic_sv1", " sta $d021", " jsr draw_screen", " jsr draw_hud", " lda #$1b", " sta $d011", " rts");
    }
    bmp_emit_copy(L, _s, _d);
    var _lo = [];
    var _hi = [];
    for (var i = 0; i < array_length(_l); i++)
    {
        array_push(_lo, "<pic_d" + string(i));
        array_push(_hi, ">pic_d" + string(i));
    }
    if (array_length(_lo) == 0) { _lo = ["0"]; _hi = ["0"]; }
    array_push(L, "pic_tlo:", " .byte " + string_join_ext(",", _lo), "pic_thi:", " .byte " + string_join_ext(",", _hi));
    var _vars = ["pic_secs", "pic_fr", "pic_ph", "pic_t", "pic_fl", "pic_rem", "pic_sv0", "pic_sv1", "pic_on", "pic_lvl"];
    for (var v = 0; v < array_length(_vars); v++) { array_push(L, _vars[v] + ":", " .fill 1,0"); }
    if (_kind == 1)
    {
        var _lv = [];
        for (var lv = 0; lv < 8; lv++)
        {
            var _pi = -1;
            if (lv < array_length(_p.levels)) { _pi = bmp_level_pic(_p.levels[lv]); }
            array_push(_lv, string(bmp_slot(_l, _pi)));
        }
        array_push(L, "pic_lvtab:", " .byte " + string_join_ext(",", _lv));
    }
    for (var j = 0; j < array_length(_l); j++) { bmp_emit_data(L, _p.pictures[_l[j]], "pic_d" + string(j)); }
    array_push(L, "pic_end:");
}

// ---------------------------------------------------------------------------
// The loading screen: a loader that shows the bitmap while the KERNAL loads the game
// ---------------------------------------------------------------------------

/// PETSCII bytes of a file name (A-Z, 0-9, space and a few signs; 16 at most)
function bmp_petscii_name(_s)
{
    var _t = string_upper(_s);
    var _o = [];
    for (var i = 1; i <= string_length(_t) && array_length(_o) < 16; i++)
    {
        var _c = ord(string_char_at(_t, i));
        if ((_c >= 65 && _c <= 90) || (_c >= 48 && _c <= 57) || _c == 32 || _c == 45 || _c == 46 || _c == 33) { array_push(_o, _c); }
    }
    if (array_length(_o) == 0) { _o = [71, 65, 77, 69]; }
    return _o;
}

/// The loader PRG's bytes (with its load address), or a string saying what went wrong.
/// It shows bitmap _b, then loads file _game_name from the disk it came from and starts it at _entry.
function bmp_build_loader(_b, _game_name, _entry)
{
    // the part that loads: it runs at $C800, out of the way of the game being loaded at $0801
    var S = [];
    array_push(S, "* = $c800");
    array_push(S, " lda #" + string(array_length(_game_name)), " ldx #<ld_name", " ldy #>ld_name", " jsr $ffbd");
    array_push(S, " lda #1", " ldx $ba", " bne ld_dv", " ldx #8", "ld_dv:", " ldy #1", " jsr $ffba");
    array_push(S, " lda #0", " jsr $ffd5", " bcs ld_err");
    array_push(S, " lda #$0b", " sta $d011", " lda $dd00", " ora #3", " sta $dd00", " lda #$15", " sta $d018", " lda #$c8", " sta $d016");
    array_push(S, " jmp " + string(_entry));
    array_push(S, "ld_err:", " inc $d020", " jmp ld_err");
    array_push(S, "ld_name:", " .byte " + string_join_ext(",", _game_name));
    var _rs = asm6502_assemble(string_join_ext("\n", S));
    if (!_rs.ok) { return "the loader's loading part would not assemble: " + _rs.err; }
    var _stub = _rs.bytes;
    var L = [];
    array_push(L, "* = $0801", " .byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00");
    array_push(L, "start:", " lda #$0b", " sta $d011", " lda #0", " sta $d015");
    array_push(L, " lda #<ld_pic", " sta $fd", " lda #>ld_pic", " sta $fe");
    array_push(L, " lda $dd00", " and #$fc", " sta $dd00");
    bmp_emit_put(L, "$fd", "$fb");
    array_push(L, " lda #$3b", " sta $d011");
    array_push(L, " ldx #0", "ld_cp:", " lda ld_stub,x", " sta $c800,x", " inx", " cpx #" + string(array_length(_stub)), " bne ld_cp", " jmp $c800");
    bmp_emit_copy(L, "$fd", "$fb");
    array_push(L, "pic_fl:", " .byte 0", "pic_rem:", " .byte 0");
    array_push(L, "ld_stub:", " .byte " + cg_join_bytes(_stub, 0, array_length(_stub)));
    bmp_emit_data(L, _b, "ld_pic");
    var _r = asm6502_assemble(string_join_ext("\n", L));
    if (!_r.ok) { return "the loader would not assemble: " + _r.err; }
    var _out = [_r.org & 255, _r.org >> 8];
    for (var i = 0; i < array_length(_r.bytes); i++) { array_push(_out, _r.bytes[i]); }
    return _out;
}

/// The bitmap shown before level _lv starts (-1 = none)
function bmp_level_pic(_lv)
{
    var _v = _lv[$ "pic"];
    if (!is_numeric(_v)) { return -1; }
    return _v;
}

/// For "the game is too big": what its bitmaps take, when it shows any
function bmp_too_big_hint(_p)
{
    var _l = bmp_game_list(_p);
    if (array_length(_l) == 0) { return ""; }
    var _n = 0;
    for (var i = 0; i < array_length(_l); i++) { _n += bmp_bytes(_p.pictures[_l[i]]); }
    return "Its " + string(array_length(_l)) + " bitmap(s) take " + string(round(_n / 1024)) + " KB - show fewer (the loading screen costs nothing in the game). ";
}
