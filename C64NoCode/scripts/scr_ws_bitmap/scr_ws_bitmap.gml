/// C64 ENGINE - the Bitmaps page: paint full-screen C64 bitmaps (multicolour or hi-res),
/// import PNG / JPG / Koala / Art Studio pictures, and choose where they show: the title screen,
/// the loading screen, game over, you win, before a level (map games) or from a rule (Logic page).
/// Tools as the C64 Dev Machine's bitmap editor, laid out like ADAM's Backdrop page.
/// The bitmaps' data and the 6502 side are in scr_bitmap.

#macro BM_BRUSH 0
#macro BM_LINE 1
#macro BM_BOX 2
#macro BM_ELLIPSE 3
#macro BM_FILL 4
#macro BM_GRADIENT 5
#macro BM_TEXT 6
#macro BM_PICK 7
#macro BM_COPY 8

function bm_tool_names()
{
    return ["Brush", "Line", "Box", "Ellipse", "Fill", "Gradient", "Text", "Pick", "Copy"];
}

function bm_tool_keys()
{
    return ["B", "L", "R", "E", "F", "G", "T", "K", "C"];
}

function bm_brush_sizes()
{
    return [1, 2, 3, 5, 8];
}

function bm_pattern_names()
{
    return ["Solid", "75%", "50%", "25%", "12%"];
}

/// The bitmap on the canvas: the import preview while importing, else the selected one
function bm_cur()
{
    if (is_struct(bm_imp)) { return bm_imp.pic; }
    if (array_length(proj.pictures) == 0) { return undefined; }
    bm_sel = clamp(bm_sel, 0, array_length(proj.pictures) - 1);
    return proj.pictures[bm_sel];
}

/// The canvas's pixel buffer and surface for bitmap _b, made again when its pixels changed elsewhere
function bm_cache_get(_b)
{
    bmp_defs_ok();
    var _c = bm_cache;
    var _w = bmp_w(_b);
    var _n = _w * BMP_H;
    if (_c.ref != _b || _c.src != _b.pix || _c.w != _w)
    {
        if (_c.buf >= 0 && buffer_get_size(_c.buf) != _n)
        {
            buffer_delete(_c.buf);
            _c.buf = -1;
        }
        if (_c.buf < 0) { _c.buf = buffer_create(_n, buffer_fixed, 1); }
        bmp_hex_to_buf(_b.pix, _c.buf, _n);
        _c.ref = _b;
        _c.src = _b.pix;
        _c.w = _w;
        _c.d1 = 0;
        _c.d2 = BMP_H - 1;
    }
    if (_c.rgba < 0) { _c.rgba = buffer_create(320 * BMP_H * 4, buffer_fixed, 1); }
    if (!surface_exists(_c.surf))
    {
        _c.surf = surface_create(320, BMP_H);
        _c.d1 = 0;
        _c.d2 = BMP_H - 1;
    }
    if (_c.d2 >= _c.d1)
    {
        bmp_render_rows(_b, _c.buf, _c.rgba, max(0, _c.d1), min(BMP_H - 1, _c.d2));
        buffer_set_surface(_c.rgba, _c.surf, 0);
        _c.d1 = BMP_H;
        _c.d2 = -1;
    }
    return _c;
}

/// Rows y1..y2 need drawing again
function bm_mark(_y1, _y2)
{
    bm_cache.d1 = min(bm_cache.d1, max(0, _y1));
    bm_cache.d2 = max(bm_cache.d2, min(BMP_H - 1, _y2));
}

/// The edits in the buffer become the bitmap's pixels
function bm_commit(_b)
{
    _b.pix = bmp_buf_to_hex(bm_cache.buf, bmp_w(_b) * BMP_H);
    bm_cache.src = _b.pix;
    proj_dirty = true;
    live_mark_stale();
}

// ---------------------------------------------------------------------------
// Painting (on the cache's buffer; bm_commit afterwards)
// ---------------------------------------------------------------------------

function bm_pat_ok(_x, _y)
{
    var _lv = [16, 12, 8, 4, 2];
    return global.BMP_BAYER[(_y & 3) * 4 + (_x & 3)] < _lv[clamp(bm_pattern, 0, 4)];
}

/// One pixel in colour _c (the pattern decides when _pat)
function bm_dot(_b, _x, _y, _c, _pat)
{
    if (_pat && !bm_pat_ok(_x, _y)) { return; }
    if (bmp_plot(_b, bm_cache.buf, _x, _y, _c))
    {
        var _y0 = (_y div 8) * 8;
        bm_mark(_y0, _y0 + 7);
    }
}

/// The brush's pixels around (0, 0): a round brush _size screen pixels across (multicolour
/// pixels are two wide, so it is half as many pixels across)
function bm_brush_offsets(_mode, _size)
{
    var _o = [];
    var _seen = {};
    var _r = _size / 2;
    for (var yy = 0; yy < _size; yy++)
    {
        for (var xx = 0; xx < _size; xx++)
        {
            if (_size >= 3)
            {
                var _dx = xx + 0.5 - _r;
                var _dy = yy + 0.5 - _r;
                if (_dx * _dx + _dy * _dy > _r * _r) { continue; }
            }
            var _lx = xx - (_size div 2);
            if (_mode == 0) { _lx = floor(_lx / 2); }
            var _ly = yy - (_size div 2);
            var _k = string(_lx) + "," + string(_ly);
            if (!is_undefined(_seen[$ _k])) { continue; }
            _seen[$ _k] = true;
            array_push(_o, [_lx, _ly]);
        }
    }
    return _o;
}

function bm_stamp_brush(_b, _x, _y, _c)
{
    var _sizes = bm_brush_sizes();
    var _o = bm_brush_offsets(_b.mode, _sizes[clamp(bm_brush, 0, 4)]);
    for (var i = 0; i < array_length(_o); i++) { bm_dot(_b, _x + _o[i][0], _y + _o[i][1], _c, true); }
}

/// A line of brush stamps (Bresenham)
function bm_line(_b, _x1, _y1, _x2, _y2, _c)
{
    var _dx = abs(_x2 - _x1);
    var _dy = -abs(_y2 - _y1);
    var _sx = (_x1 < _x2) ? 1 : -1;
    var _sy = (_y1 < _y2) ? 1 : -1;
    var _err = _dx + _dy;
    var _x = _x1;
    var _y = _y1;
    repeat (2000)
    {
        bm_stamp_brush(_b, _x, _y, _c);
        if (_x == _x2 && _y == _y2) { break; }
        var _e2 = 2 * _err;
        if (_e2 >= _dy) { _err += _dy; _x += _sx; }
        if (_e2 <= _dx) { _err += _dx; _y += _sy; }
    }
}

function bm_box(_b, _x1, _y1, _x2, _y2, _c)
{
    var _l = min(_x1, _x2);
    var _r = max(_x1, _x2);
    var _t = min(_y1, _y2);
    var _u = max(_y1, _y2);
    if (bm_filled)
    {
        for (var _py = _t; _py <= _u; _py++) { for (var _px = _l; _px <= _r; _px++) { bm_dot(_b, _px, _py, _c, true); } }
        return;
    }
    bm_line(_b, _l, _t, _r, _t, _c);
    bm_line(_b, _r, _t, _r, _u, _c);
    bm_line(_b, _r, _u, _l, _u, _c);
    bm_line(_b, _l, _u, _l, _t, _c);
}

function bm_ellipse(_b, _x1, _y1, _x2, _y2, _c)
{
    var _cx = (_x1 + _x2) / 2;
    var _cy = (_y1 + _y2) / 2;
    var _rx = max(0.5, abs(_x2 - _x1) / 2);
    var _ry = max(0.5, abs(_y2 - _y1) / 2);
    if (bm_filled)
    {
        for (var _py = floor(_cy - _ry); _py <= ceil(_cy + _ry); _py++)
        {
            var _t = (_py - _cy) / _ry;
            if (abs(_t) > 1) { continue; }
            var _hw = _rx * sqrt(1 - _t * _t);
            for (var _px = round(_cx - _hw); _px <= round(_cx + _hw); _px++) { bm_dot(_b, _px, _py, _c, true); }
        }
        return;
    }
    var _steps = max(16, ceil((_rx + _ry) * 4));
    var _px = round(_cx + _rx);
    var _py = round(_cy);
    for (var i = 1; i <= _steps; i++)
    {
        var _a = i / _steps * 2 * pi;
        var _nx = round(_cx + _rx * cos(_a));
        var _ny = round(_cy + _ry * sin(_a));
        bm_line(_b, _px, _py, _nx, _ny, _c);
        _px = _nx;
        _py = _ny;
    }
}

/// The pixels joined to (x, y) that share its colour (4-way)
function bm_region(_b, _x, _y)
{
    var _w = bmp_w(_b);
    var _buf = bm_cache.buf;
    var _out = [];
    if (_x < 0 || _y < 0 || _x >= _w || _y >= BMP_H) { return _out; }
    var _seed = buffer_peek(_buf, _y * _w + _x, buffer_u8);
    var _seen = buffer_create(_w * BMP_H, buffer_fixed, 1);
    buffer_fill(_seen, 0, buffer_u8, 0, _w * BMP_H);
    var _stack = [_y * _w + _x];
    buffer_poke(_seen, _y * _w + _x, buffer_u8, 1);
    while (array_length(_stack) > 0)
    {
        var _i = array_pop(_stack);
        array_push(_out, _i);
        var _px = _i mod _w;
        var _py = _i div _w;
        var _nb = [];
        if (_px > 0) { array_push(_nb, _i - 1); }
        if (_px < _w - 1) { array_push(_nb, _i + 1); }
        if (_py > 0) { array_push(_nb, _i - _w); }
        if (_py < BMP_H - 1) { array_push(_nb, _i + _w); }
        for (var k = 0; k < array_length(_nb); k++)
        {
            var _j = _nb[k];
            if (buffer_peek(_seen, _j, buffer_u8) == 0 && buffer_peek(_buf, _j, buffer_u8) == _seed)
            {
                buffer_poke(_seen, _j, buffer_u8, 1);
                array_push(_stack, _j);
            }
        }
    }
    buffer_delete(_seen);
    return _out;
}

function bm_fill(_b, _x, _y, _c)
{
    var _w = bmp_w(_b);
    var _r = bm_region(_b, _x, _y);
    for (var i = 0; i < array_length(_r); i++) { bm_dot(_b, _r[i] mod _w, _r[i] div _w, _c, true); }
}

/// The colours a gradient runs through: from _a to _z, or through the shades between them
function bm_ramp(_a, _z)
{
    if (!bm_shades || _a == _z) { return [_a, _z]; }
    var _la = global.BMP_LUMA[_a];
    var _lz = global.BMP_LUMA[_z];
    var _mid = [];
    for (var k = 0; k < 16; k++)
    {
        if (k == _a || k == _z) { continue; }
        var _l = global.BMP_LUMA[k];
        if ((_l > min(_la, _lz)) && (_l < max(_la, _lz))) { array_push(_mid, k); }
    }
    // darkest to lightest, then the way the drag goes
    array_sort(_mid, function(_p, _q) { return global.BMP_LUMA[_p] - global.BMP_LUMA[_q]; });
    if (_la > _lz) { _mid = array_reverse(_mid); }
    var _o = [_a];
    for (var m = 0; m < array_length(_mid); m++) { array_push(_o, _mid[m]); }
    array_push(_o, _z);
    return _o;
}

/// Fills the area under (ax, ay) with a dithered gradient along the drag from (ax, ay) to (bx, by)
function bm_gradient(_b, _ax, _ay, _bx, _by)
{
    var _w = bmp_w(_b);
    var _xs = (_b.mode == 0) ? 2 : 1;
    var _r = bm_region(_b, _ax, _ay);
    var _ramp = bm_ramp(bm_pen, bm_pen2);
    var _n = array_length(_ramp);
    var _vx = (_bx - _ax) * _xs;
    var _vy = _by - _ay;
    var _ll = max(1, _vx * _vx + _vy * _vy);
    var _x1 = _w;
    var _x2 = 0;
    var _y1 = BMP_H;
    var _y2 = 0;
    for (var i = 0; i < array_length(_r); i++)
    {
        var _x = _r[i] mod _w;
        var _y = _r[i] div _w;
        var _t = clamp(((_x - _ax) * _xs * _vx + (_y - _ay) * _vy) / _ll, 0, 1);
        var _seg = _t * (_n - 1);
        var _i0 = floor(_seg);
        var _k = _ramp[min(_n - 1, _i0)];
        if (_i0 < _n - 1 && (_seg - _i0) > (global.BMP_BAYER[(_y & 3) * 4 + (_x & 3)] + 0.5) / 16) { _k = _ramp[_i0 + 1]; }
        buffer_poke(bm_cache.buf, _r[i], buffer_u8, _k);
        _x1 = min(_x1, _x); _x2 = max(_x2, _x); _y1 = min(_y1, _y); _y2 = max(_y2, _y);
    }
    if (array_length(_r) > 0)
    {
        bmp_reduce(_b, bm_cache.buf, _x1, _y1, _x2, _y2);
        bm_mark((_y1 div 8) * 8, (_y2 div 8) * 8 + 7);
    }
}

/// Letter _ch of the C64's character set at (x, y): 8 pixels across (16 screen pixels in multicolour)
function bm_text_char(_b, _ch, _x, _y, _c)
{
    if (array_length(global.chargen_rom) < 2048) { return; }
    var _code = scr_code_from_char(_ch) & 255;
    for (var r = 0; r < 8; r++)
    {
        var _bits = global.chargen_rom[(_code & 255) * 8 + r];
        for (var p = 0; p < 8; p++)
        {
            if ((_bits >> (7 - p)) & 1) { bm_dot(_b, _x + p, _y + r, _c, false); }
        }
    }
}

/// Copies pixels x1..x2, y1..y2 for stamping; the background (multicolour) or black (hi-res) is see-through
function bm_grab(_b, _x1, _y1, _x2, _y2)
{
    var _w = bmp_w(_b);
    var _l = clamp(min(_x1, _x2), 0, _w - 1);
    var _r = clamp(max(_x1, _x2), 0, _w - 1);
    var _t = clamp(min(_y1, _y2), 0, BMP_H - 1);
    var _u = clamp(max(_y1, _y2), 0, BMP_H - 1);
    var _clear = (_b.mode == 0) ? _b.bg : 0;
    var _d = [];
    for (var _py = _t; _py <= _u; _py++)
    {
        for (var _px = _l; _px <= _r; _px++)
        {
            var _v = buffer_peek(bm_cache.buf, _py * _w + _px, buffer_u8);
            array_push(_d, (_v == _clear) ? -1 : _v);
        }
    }
    bm_clip = { w : _r - _l + 1, h : _u - _t + 1, d : _d, mode : _b.mode };
    bm_stamping = true;
}

/// Stamps the copy with its top-left corner at (x, y)
function bm_stamp(_b, _x, _y)
{
    var _cl = bm_clip;
    var _sx = 1;
    if (_cl.mode == 0 && _b.mode == 1) { _sx = 2; }
    for (var yy = 0; yy < _cl.h; yy++)
    {
        for (var xx = 0; xx < _cl.w; xx++)
        {
            var _v = _cl.d[yy * _cl.w + xx];
            if (_v < 0) { continue; }
            if (_cl.mode == 1 && _b.mode == 0 && (xx & 1)) { continue; }
            var _tx = (_cl.mode == 1 && _b.mode == 0) ? _x + (xx div 2) : _x + xx * _sx;
            bm_dot(_b, _tx, _y + yy, _v, false);
            if (_sx == 2) { bm_dot(_b, _tx + 1, _y + yy, _v, false); }
        }
    }
}

function bm_clip_flip(_h)
{
    var _cl = bm_clip;
    var _d = array_create(array_length(_cl.d), -1);
    for (var _py = 0; _py < _cl.h; _py++)
    {
        for (var _px = 0; _px < _cl.w; _px++)
        {
            var _sx = _h ? (_cl.w - 1 - _px) : _px;
            var _sy = _h ? _py : (_cl.h - 1 - _py);
            _d[_py * _cl.w + _px] = _cl.d[_sy * _cl.w + _sx];
        }
    }
    _cl.d = _d;
}

/// Turns the whole bitmap round (h) or upside down
function bm_flip_all(_b, _h)
{
    var _w = bmp_w(_b);
    var _buf = bm_cache.buf;
    var _n = _w * BMP_H;
    var _t = buffer_create(_n, buffer_fixed, 1);
    buffer_copy(_buf, 0, _n, _t, 0);
    for (var _py = 0; _py < BMP_H; _py++)
    {
        for (var _px = 0; _px < _w; _px++)
        {
            var _sx = _h ? (_w - 1 - _px) : _px;
            var _sy = _h ? _py : (BMP_H - 1 - _py);
            buffer_poke(_buf, _py * _w + _px, buffer_u8, buffer_peek(_t, _sy * _w + _sx, buffer_u8));
        }
    }
    buffer_delete(_t);
    // turning round moves pixels between cells: keep every cell within its colours
    bmp_reduce(_b, _buf, 0, 0, _w - 1, BMP_H - 1);
    bm_mark(0, BMP_H - 1);
}

/// Multicolour <-> hi-res: pixels are doubled or every other one kept, then each cell's colours made legal
function bm_set_mode(_b, _mode)
{
    if (_b.mode == _mode) { return; }
    var _old = bmp_pix_array(_b);
    var _a;
    if (_mode == 1)
    {
        _a = array_create(320 * BMP_H, 0);
        for (var i = 0; i < 160 * BMP_H; i++)
        {
            var _y = i div 160;
            var _x = i mod 160;
            _a[_y * 320 + _x * 2] = _old[i];
            _a[_y * 320 + _x * 2 + 1] = _old[i];
        }
    }
    else
    {
        _a = array_create(160 * BMP_H, 0);
        var _tot = array_create(16, 0);
        for (var k = 0; k < 160 * BMP_H; k++)
        {
            var _y2 = k div 160;
            var _x2 = k mod 160;
            _a[k] = _old[_y2 * 320 + _x2 * 2];
            _tot[_a[k]] += 1;
        }
        var _bg = 0;
        for (var t = 1; t < 16; t++) { if (_tot[t] > _tot[_bg]) { _bg = t; } }
        _b.bg = _bg;
    }
    _b.mode = _mode;
    _b.pix = bmp_pix_from_array(_a);
    var _c = bm_cache_get(_b);
    bmp_reduce(_b, _c.buf, 0, 0, bmp_w(_b) - 1, BMP_H - 1);
    bm_mark(0, BMP_H - 1);
    bm_commit(_b);
}

/// Multicolour: a new background colour (every pixel of the old one takes it, as on the C64)
function bm_set_bg(_b, _bg)
{
    if (_b.bg == _bg) { return; }
    var _c = bm_cache_get(_b);
    if (_b.mode == 0)
    {
        var _n = 160 * BMP_H;
        for (var i = 0; i < _n; i++)
        {
            if (buffer_peek(_c.buf, i, buffer_u8) == _b.bg) { buffer_poke(_c.buf, i, buffer_u8, _bg); }
        }
        _b.bg = _bg;
        bm_mark(0, BMP_H - 1);
        bm_commit(_b);
    }
    else { _b.bg = _bg; }
}

// ---------------------------------------------------------------------------
// Bitmaps: new, import, duplicate, delete
// ---------------------------------------------------------------------------

function bm_add(_b)
{
    if (array_length(proj.pictures) >= BMP_MAX)
    {
        toast("You have " + string(BMP_MAX) + " bitmaps - delete one first", 1);
        return false;
    }
    undo_mark("bmadd" + string(current_time));
    array_push(proj.pictures, _b);
    bm_sel = array_length(proj.pictures) - 1;
    bm_zoom = 0;
    return true;
}

/// Asks for a picture: Koala / Art Studio files come straight in, other pictures open the import settings
function bm_import_start()
{
    if (array_length(proj.pictures) >= BMP_MAX)
    {
        toast("You have " + string(BMP_MAX) + " bitmaps - delete one first", 1);
        return;
    }
    var _f = get_open_filename("Pictures|*.png;*.jpg;*.jpeg;*.gif;*.kla;*.koa;*.art;*.aas;*.hpi", "");
    if (_f == "") { return; }
    bm_import_file(_f);
}

function bm_import_file(_f)
{
    var _ext = string_lower(filename_ext(_f));
    if (_ext == ".kla" || _ext == ".koa" || _ext == ".art" || _ext == ".aas" || _ext == ".hpi")
    {
        var _r = bmp_load_c64_file(_f);
        if (is_string(_r))
        {
            toast(_r, 2);
            return;
        }
        if (bm_add(_r)) { toast(filename_name(_f) + " imported", 0); }
        return;
    }
    bm_import_cancel();
    var _spr = sprite_add(_f, 1, false, false, 0, 0);
    if (_spr < 0)
    {
        toast("Could not load that picture", 2);
        return;
    }
    var _mode = 0;
    var _cur = bm_cur();
    if (!is_undefined(_cur)) { _mode = _cur.mode; }
    var _name = string_copy(filename_change_ext(filename_name(_f), ""), 1, 24);
    bm_imp = { spr : _spr, name : _name, set : bmp_import_settings_new(_mode), pic : bmp_new(_name, _mode), dirty : true, t : 0 };
    bm_zoom = 0;
}

function bm_import_cancel()
{
    if (is_struct(bm_imp))
    {
        if (sprite_exists(bm_imp.spr)) { sprite_delete(bm_imp.spr); }
        bm_imp = undefined;
    }
}

/// Runs the import's conversion again when its settings changed (not while a slider is held)
function bm_import_step()
{
    if (!is_struct(bm_imp) || !bm_imp.dirty || ui_held) { return; }
    if (current_time - bm_imp.t < 120) { return; }
    var _r = bmp_convert(bm_imp.spr, bm_imp.set);
    bm_imp.pic.mode = bm_imp.set.mode;
    bm_imp.pic.bg = _r.bg;
    bm_imp.pic.pix = _r.pix;
    bm_imp.dirty = false;
}

function bm_import_finish()
{
    bm_import_step();
    var _p = bm_imp.pic;
    var _b = { name : bm_imp.name, mode : _p.mode, bg : _p.bg, border : 0, pix : _p.pix };
    bm_import_cancel();
    if (bm_add(_b)) { toast("Picture imported - each 8 x 8 cell now keeps to the C64's colours", 0); }
}

// ---------------------------------------------------------------------------
// The page
// ---------------------------------------------------------------------------

function ws_bitmap_draw(_x1, _y1, _x2, _y2)
{
    bmp_defs_ok();
    var _lw = clamp(floor((_x2 - _x1) * 0.2), 210, 260);
    var _rw = clamp(floor((_x2 - _x1) * 0.25), 270, 330);
    var _b = bm_cur();

    bm_left_panel(_x1, _y1, _x1 + _lw, _y2);

    var _cx1 = _x1 + _lw + 12;
    var _cx2 = _x2 - _rw - 12;
    if (is_undefined(_b))
    {
        ui_panel(_cx1, _y1, _x2, _y2, "");
        ui_text_wrap((_cx1 + _x2) / 2 - 200, (_y1 + _y2) / 2 - 30, "No bitmaps yet. Press + New to paint one, or Import... to bring in a PNG, JPG or Koala picture. A bitmap fills the whole screen: a title, a loading screen, or a picture shown at a point in the game.", global.TH.text_dim, 400, global.f_body, 1);
        return;
    }
    bm_import_step();
    bm_canvas(_cx1, _y1, _cx2, _y2, _b);
    if (is_struct(bm_imp)) { bm_import_panel(_x2 - _rw, _y1, _x2, _y2); }
    else { bm_tools_panel(_x2 - _rw, _y1, _x2, _y2, _b); }
    bm_keys(_b);
}

/// The list of bitmaps, their buttons, and where they show
function bm_left_panel(_x1, _y1, _x2, _y2)
{
    var _n = array_length(proj.pictures);
    ui_panel(_x1, _y1, _x2, _y2, "Bitmaps  (" + string(_n) + " / " + string(BMP_MAX) + ")");
    var _rowh = 66;
    var _nscreens = 4;
    if (proj.game_type == 1) { _nscreens += min(8, array_length(proj.levels)); }
    var _content = _n * _rowh + 92 + 34 + _nscreens * 40 + 60;
    var _off = ui_scroll_begin("bm_left", _x1 + 6, _y1 + 50, _x2 - 6, _y2 - 8, _content);
    var _y = _y1 + 54 - _off;
    for (var i = 0; i < _n; i++)
    {
        var _pb = proj.pictures[i];
        var _id = "bm_item_" + string(i);
        var _uses = bmp_uses(i);
        var _hot = ui_register(_id, _x1 + 10, _y, _x2 - 10, _y + _rowh - 6, _pb.name + "|Click to paint this bitmap. " + ((_uses == "") ? "It is not shown anywhere yet - choose where under Where they show." : "It shows: " + _uses + "."));
        var _a = ui_anim_to(_id, _hot ? 1 : 0);
        if (bm_sel == i && !is_struct(bm_imp)) { ui_rrect(_x1 + 10, _y, _x2 - 10, _y + _rowh - 6, 10, global.TH.accent, global.TH.accent_dark, 0.9); }
        else { ui_rrect(_x1 + 10, _y, _x2 - 10, _y + _rowh - 6, 10, global.TH.btn_hot_top, global.TH.btn_hot_bot, 0.25 + 0.75 * _a); }
        bm_thumb(i, _x1 + 16, _y + 5, 80, 50);
        ui_text(_x1 + 104, _y + 17, ui_text_fit(_pb.name, global.f_bold, _x2 - _x1 - 124), global.TH.text, fa_left, fa_middle, global.f_bold, 1);
        var _sub = ((_pb.mode == 0) ? "Multicolour" : "Hi-res");
        _sub += (_uses == "") ? "  -  not shown yet" : "  -  " + _uses;
        ui_text(_x1 + 104, _y + 38, ui_text_fit(_sub, global.f_small, _x2 - _x1 - 124), global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
        if (_hot && ui_pressed)
        {
            ui_take_click();
            bm_import_cancel();
            if (bm_sel != i)
            {
                bm_sel = i;
                bm_zoom = 0;
                bm_stamping = false;
                bm_text_end();
            }
        }
        _y += _rowh;
    }
    // buttons
    var _bw = floor((_x2 - _x1 - 28) / 2);
    var _bx = _x1 + 10;
    if (ui_button("bm_new", _bx, _y, _bw, 32, "+ New", "New bitmap|A blank multicolour bitmap. Switch it to hi-res on its Bitmap tab.", BTN_ACCENT))
    {
        bm_import_cancel();
        bm_add(bmp_new("Bitmap " + string(_n + 1), 0));
    }
    if (ui_button("bm_import", _bx + _bw + 8, _y, _bw, 32, "Import...", "Import a picture|A PNG, JPG or GIF is fitted to the screen and turned into C64 colours - you choose the mode, dither and colour settings first. Koala (.kla / .koa) and Art Studio (.art) files come straight in.", BTN_NORMAL)) { bm_import_start(); }
    _y += 40;
    var _cst = (_n > 0) ? BTN_NORMAL : BTN_GHOST;
    if (ui_button("bm_dup", _bx, _y, _bw, 32, "Duplicate", "Duplicate|A copy of this bitmap, to try changes on.", _cst) && _n > 0)
    {
        var _src = proj.pictures[bm_sel];
        var _cp = { name : string_copy(_src.name + " copy", 1, 24), mode : _src.mode, bg : _src.bg, border : _src.border, pix : _src.pix };
        bm_add(_cp);
    }
    var _dst = (_n > 0) ? BTN_DANGER : BTN_GHOST;
    if (ui_button("bm_del", _bx + _bw + 8, _y, _bw, 32, "Delete", "Delete bitmap|Removes this bitmap; wherever it showed shows nothing instead. You can Undo this.", _dst) && _n > 0)
    {
        undo_mark("bmdel" + string(current_time));
        array_delete(proj.pictures, bm_sel, 1);
        bmp_deleted(bm_sel);
        bm_sel = max(0, bm_sel - 1);
        bm_stamping = false;
    }
    _y += 52;
    // where they show
    ui_heading(_x1 + 14, _y, "Where they show");
    _y += 22;
    var _names = bmp_choice_names();
    var _lab = ["Title screen", "Loading screen", "Game over", "You win"];
    var _key = ["pic_title", "pic_load", "pic_over", "pic_win"];
    var _hlp = [
        "Title screen|Shown when the game starts (and after each game over or win) until fire is pressed. Its music keeps playing.",
        "Loading screen|Shown while the game loads from disk. The game is built as a .d64 disk too: a small loader shows this picture, then loads the game. It costs no memory in the game itself - only disk space.",
        "Game over|Shown instead of the GAME OVER message, until fire is pressed.",
        "You win|Shown instead of the winning message, until fire is pressed."
    ];
    var _dw = _x2 - _x1 - 28 - 96;
    for (var s = 0; s < 4; s++)
    {
        ui_text(_x1 + 14, _y + 15, _lab[s], global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
        var _v = ui_dropdown("bm_scr_" + _key[s], _x1 + 110, _y, _dw, 30, _names, proj[$ _key[s]] + 1, _hlp[s]) - 1;
        set_val(proj, _key[s], _v, "bmscr" + _key[s]);
        _y += 40;
    }
    if (proj.game_type == 1)
    {
        for (var l = 0; l < min(8, array_length(proj.levels)); l++)
        {
            var _lv = proj.levels[l];
            ui_text(_x1 + 14, _y + 15, "Level " + string(l + 1), global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
            var _lvv = ui_dropdown("bm_scr_lv" + string(l), _x1 + 110, _y, _dw, 30, _names, bmp_level_pic(_lv) + 1, "Before level " + string(l + 1) + "|Shown when the player reaches this level (not again after losing a life), until fire is pressed.") - 1;
            set_val(_lv, "pic", _lvv, "bmscrlv" + string(l));
            _y += 40;
        }
    }
    else
    {
        ui_text_wrap(_x1 + 14, _y + 2, "To show one during the game, use the Logic page's DO Show a bitmap.", global.TH.text_faint, _x2 - _x1 - 28, global.f_small, 1);
    }
    ui_scroll_end("bm_left", _x1 + 6, _y1 + 50, _x2 - 6, _y2 - 8, _content);
}

/// A small picture of bitmap _i (drawn again only when its pixels change)
function bm_thumb(_i, _x, _y, _w, _h)
{
    ui_rrect(_x - 1, _y - 1, _x + _w + 1, _y + _h + 1, 4, c_black, c_black, 1);
    var _pb = proj.pictures[_i];
    var _t = bm_thumbs[$ string(_i)];
    if (is_undefined(_t) || _t.src != _pb.pix || !surface_exists(_t.surf))
    {
        if (!is_undefined(_t) && surface_exists(_t.surf)) { surface_free(_t.surf); }
        // the bitmap being painted is drawn straight from the canvas instead
        if (bm_cache.ref == _pb && surface_exists(bm_cache.surf))
        {
            draw_surface_stretched(bm_cache.surf, _x, _y, _w, _h);
            return;
        }
        _t = { src : _pb.pix, surf : bmp_to_surface(_pb) };
        bm_thumbs[$ string(_i)] = _t;
    }
    var _tf = gpu_get_texfilter();
    gpu_set_texfilter(true);
    draw_surface_stretched(_t.surf, _x, _y, _w, _h);
    gpu_set_texfilter(_tf);
}

/// Where the canvas is: { ox, oy, sc } (sc = screen pixels per hi-res pixel)
function bm_view(_vx1, _vy1, _vx2, _vy2)
{
    var _fit = min((_vx2 - _vx1) / 320, (_vy2 - _vy1) / BMP_H);
    if (_fit >= 2) { _fit = floor(_fit); }
    var _sc = (bm_zoom > 0) ? bm_zoom : _fit;
    var _cw = 320 * _sc;
    var _ch = BMP_H * _sc;
    if (bm_zoom == 0)
    {
        bm_pan_x = 0;
        bm_pan_y = 0;
    }
    else
    {
        bm_pan_x = clamp(bm_pan_x, -max(0, (_cw - (_vx2 - _vx1)) / 2 + 40), max(0, (_cw - (_vx2 - _vx1)) / 2 + 40));
        bm_pan_y = clamp(bm_pan_y, -max(0, (_ch - (_vy2 - _vy1)) / 2 + 40), max(0, (_ch - (_vy2 - _vy1)) / 2 + 40));
    }
    var _ox = floor((_vx1 + _vx2 - _cw) / 2 + bm_pan_x);
    var _oy = floor((_vy1 + _vy2 - _ch) / 2 + bm_pan_y);
    return { ox : _ox, oy : _oy, sc : _sc, fit : _fit };
}

/// The canvas: the bitmap, the tools' previews, zoom and pan, and the line under it
function bm_canvas(_cx1, _y1, _cx2, _y2, _b)
{
    ui_panel(_cx1, _y1, _cx2, _y2, "");
    var _vx1 = _cx1 + 16;
    var _vy1 = _y1 + 16;
    var _vx2 = _cx2 - 16;
    var _vy2 = _y2 - 44;
    var _c = bm_cache_get(_b);
    var _v = bm_view(_vx1, _vy1, _vx2, _vy2);
    var _sc = _v.sc;
    var _mc = (_b.mode == 0);
    var _pw = _mc ? 2 : 1;
    var _w = bmp_w(_b);
    ui_rrect(_vx1 - 6, _vy1 - 6, _vx2 + 6, _vy2 + 6, 10, c_black, c_black, 0.35);
    ui_scissor(_vx1, _vy1, _vx2 - _vx1, _vy2 - _vy1);
    // the border colour round the picture, as on a TV
    draw_set_colour(c64col(_b.border));
    draw_rectangle(_v.ox - 16 * _sc, _v.oy - 12 * _sc, _v.ox + 336 * _sc, _v.oy + 212 * _sc, false);
    var _tf = gpu_get_texfilter();
    gpu_set_texfilter(false);
    draw_surface_ext(_c.surf, _v.ox, _v.oy, _sc, _sc, 0, c_white, 1);
    gpu_set_texfilter(_tf);
    // cells
    if (bm_grid && _sc >= 2)
    {
        draw_set_alpha(0.22);
        for (var gx = 0; gx <= 40; gx++) { draw_line_colour(_v.ox + gx * 8 * _sc, _v.oy, _v.ox + gx * 8 * _sc, _v.oy + 200 * _sc, c_white, c_white); }
        for (var gy = 0; gy <= 25; gy++) { draw_line_colour(_v.ox, _v.oy + gy * 8 * _sc, _v.ox + 320 * _sc, _v.oy + gy * 8 * _sc, c_white, c_white); }
        draw_set_alpha(1);
    }
    var _help = "Canvas|Left button paints the pen colour, right button the second colour. Alt+click picks a colour. Mouse wheel zooms, Space+drag or the middle button moves the view. Each 8 x 8 cell holds " + (_mc ? "the background + 3 colours" : "2 colours") + ": paint a new one into a full cell and it takes over the colour it lands on, in that cell - the C64's colour clash.";
    if (is_struct(bm_imp)) { _help = "Import preview|What the picture will look like on the C64. Change the settings on the right, then press Use this picture."; }
    var _hot = ui_register("bm_canvas", _vx1, _vy1, _vx2, _vy2, _help);
    // where the mouse is, in the bitmap's pixels
    var _mx = floor((ui_mx - _v.ox) / _sc / _pw);
    var _my = floor((ui_my - _v.oy) / _sc);
    var _in = (_hot && _mx >= 0 && _my >= 0 && _mx < _w && _my < BMP_H);
    // zoom (mouse wheel, round the mouse) and pan
    if (_hot && ui_wheel != 0)
    {
        // Fit, then the zooms bigger than Fit
        var _lv = [0, 2, 3, 4, 6, 8, 12, 16];
        var _cur = 0;
        for (var z = 0; z < array_length(_lv); z++) { if (_lv[z] == bm_zoom) { _cur = z; } }
        var _nz = clamp(_cur + sign(ui_wheel), 0, array_length(_lv) - 1);
        if (ui_wheel > 0) { while (_nz < array_length(_lv) - 1 && _lv[_nz] > 0 && _lv[_nz] <= _v.fit) { _nz += 1; } }
        if (_nz > 0 && _lv[_nz] <= _v.fit) { _nz = 0; }
        var _nsc = (_lv[_nz] == 0) ? _v.fit : _lv[_nz];
        // keep the pixel under the mouse where it is
        var _px = (ui_mx - _v.ox) / _sc;
        var _py = (ui_my - _v.oy) / _sc;
        bm_zoom = _lv[_nz];
        if (bm_zoom > 0)
        {
            var _ox0 = (_vx1 + _vx2 - 320 * _nsc) / 2;
            var _oy0 = (_vy1 + _vy2 - BMP_H * _nsc) / 2;
            bm_pan_x = ui_mx - _px * _nsc - _ox0;
            bm_pan_y = ui_my - _py * _nsc - _oy0;
        }
        ui_wheel = 0;
    }
    var _space = keyboard_check(vk_space) && ui_focus == "";
    if (_hot && (mouse_check_button_pressed(mb_middle) || (_space && ui_pressed)))
    {
        bm_panning = true;
        bm_pan_mx = ui_mx;
        bm_pan_my = ui_my;
        if (ui_pressed) { ui_take_click(); }
    }
    if (bm_panning)
    {
        bm_pan_x += ui_mx - bm_pan_mx;
        bm_pan_y += ui_my - bm_pan_my;
        bm_pan_mx = ui_mx;
        bm_pan_my = ui_my;
        if (!mouse_check_button(mb_middle) && !ui_held) { bm_panning = false; }
    }
    // tools
    if (!is_struct(bm_imp) && !bm_panning) { bm_canvas_input(_b, _in, _mx, _my, _hot); }
    // previews: shapes, the copy box, the stamp, the text cursor, the brush
    var _pc = c64col(bm_pen);
    if (bm_drag > 0 && (bm_tool == BM_LINE || bm_tool == BM_BOX || bm_tool == BM_ELLIPSE || bm_tool == BM_GRADIENT || bm_tool == BM_COPY))
    {
        var _ax = _v.ox + (bm_ax + 0.5) * _pw * _sc;
        var _ay = _v.oy + (bm_ay + 0.5) * _sc;
        var _bx = _v.ox + (clamp(_mx, 0, _w - 1) + 0.5) * _pw * _sc;
        var _by = _v.oy + (clamp(_my, 0, BMP_H - 1) + 0.5) * _sc;
        var _lc = (bm_drag == 2) ? c64col(bm_pen2) : _pc;
        if (bm_tool == BM_LINE || bm_tool == BM_GRADIENT) { draw_line_width_colour(_ax, _ay, _bx, _by, 2, _lc, _lc); }
        if (bm_tool == BM_BOX || bm_tool == BM_COPY) { draw_rectangle_colour(min(_ax, _bx), min(_ay, _by), max(_ax, _bx), max(_ay, _by), _lc, _lc, _lc, _lc, true); }
        if (bm_tool == BM_ELLIPSE) { draw_ellipse_colour(min(_ax, _bx), min(_ay, _by), max(_ax, _bx), max(_ay, _by), _lc, _lc, true); }
        if (bm_tool == BM_GRADIENT)
        {
            draw_circle_colour(_ax, _ay, 6, c64col(bm_pen), c64col(bm_pen), false);
            draw_circle_colour(_bx, _by, 6, c64col(bm_pen2), c64col(bm_pen2), false);
            draw_circle_colour(_ax, _ay, 6, c_white, c_white, true);
            draw_circle_colour(_bx, _by, 6, c_white, c_white, true);
        }
        var _dw = abs(clamp(_mx, 0, _w - 1) - bm_ax) + 1;
        var _dh = abs(clamp(_my, 0, BMP_H - 1) - bm_ay) + 1;
        ui_text(_bx + 12, _by + 12, string(_dw) + " x " + string(_dh), global.TH.warn, fa_left, fa_top, global.f_small, 1);
    }
    if (bm_stamping && is_struct(bm_clip) && _in)
    {
        var _cpw = (bm_clip.mode == 0) ? 2 : 1;
        draw_set_alpha(0.75);
        for (var yy = 0; yy < bm_clip.h; yy++)
        {
            for (var xx = 0; xx < bm_clip.w; xx++)
            {
                var _cv = bm_clip.d[yy * bm_clip.w + xx];
                if (_cv < 0) { continue; }
                var _sx = _v.ox + (_mx * _pw + xx * _cpw) * _sc;
                var _sy = _v.oy + (_my + yy) * _sc;
                draw_set_colour(c64col(_cv));
                draw_rectangle(_sx, _sy, _sx + _cpw * _sc - 1, _sy + _sc - 1, false);
            }
        }
        draw_set_alpha(1);
        var _ex = _v.ox + (_mx * _pw) * _sc;
        var _ey = _v.oy + _my * _sc;
        draw_rectangle_colour(_ex, _ey, _ex + bm_clip.w * _cpw * _sc, _ey + bm_clip.h * _sc, c_white, c_white, c_white, c_white, true);
    }
    if (bm_texting)
    {
        var _tx = _v.ox + bm_tx * _pw * _sc;
        var _ty = _v.oy + bm_ty * _sc;
        if ((current_time div 400) mod 2 == 0) { draw_rectangle_colour(_tx, _ty, _tx + 8 * _pw * _sc - 1, _ty + 8 * _sc - 1, _pc, _pc, _pc, _pc, false); }
        draw_rectangle_colour(_tx, _ty, _tx + 8 * _pw * _sc - 1, _ty + 8 * _sc - 1, c_white, c_white, c_white, c_white, true);
    }
    else if (_in && !bm_stamping && bm_drag == 0 && !is_struct(bm_imp))
    {
        // the pixels the brush covers
        var _sizes = bm_brush_sizes();
        var _bs = (bm_tool == BM_BRUSH || bm_tool == BM_LINE || bm_tool == BM_BOX || bm_tool == BM_ELLIPSE) ? _sizes[bm_brush] : 1;
        var _bo = bm_brush_offsets(_b.mode, _bs);
        var _l = 0, _r = 0, _t = 0, _u = 0;
        for (var o = 0; o < array_length(_bo); o++) { _l = min(_l, _bo[o][0]); _r = max(_r, _bo[o][0]); _t = min(_t, _bo[o][1]); _u = max(_u, _bo[o][1]); }
        var _hx = _v.ox + (_mx + _l) * _pw * _sc;
        var _hy = _v.oy + (_my + _t) * _sc;
        draw_rectangle_colour(_hx, _hy, _hx + (_r - _l + 1) * _pw * _sc - 1, _hy + (_u - _t + 1) * _sc - 1, c_white, c_white, c_white, c_white, true);
    }
    ui_scissor_reset();

    // the line under the canvas
    var _st = "";
    if (_in)
    {
        var _pv = buffer_peek(_c.buf, _my * _w + _mx, buffer_u8);
        _st = "X " + string(_mx) + "   Y " + string(_my) + "   " + global.C64PAL_NAMES[_pv];
        var _cn = bm_cell_colours(_b, _mx, _my);
        _st += "      cell " + string(_mx div (_mc ? 4 : 8)) + "," + string(_my div 8) + ":  " + string(array_length(_cn)) + " of " + (_mc ? "3 + background" : "2");
        // the cell's colours as swatches
        draw_set_font(global.f_small);
        var _sx2 = _vx1 + 8 + ui_sw(_st) + 10;
        for (var k = 0; k < array_length(_cn); k++)
        {
            ui_rrect(_sx2 + k * 18, _y2 - 32, _sx2 + k * 18 + 14, _y2 - 18, 3, c64col(_cn[k]), c64col(_cn[k]), 1);
        }
    }
    else
    {
        _st = (_mc ? "Multicolour 160 x 200" : "Hi-res 320 x 200") + "   -   " + string(bmp_bytes(_b)) + " bytes in the game";
        if (is_struct(bm_imp)) { _st = "Import preview - " + _st; }
    }
    ui_text(_vx1 + 8, _y2 - 25, _st, global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
    var _zt = (bm_zoom == 0) ? "Fit" : string(bm_zoom) + "x";
    ui_text(_vx2 - 8, _y2 - 25, "Zoom " + _zt + "  (mouse wheel)", global.TH.text_faint, fa_right, fa_middle, global.f_small, 1);
}

/// The colours (not the background, in multicolour) of the cell holding pixel (x, y)
function bm_cell_colours(_b, _x, _y)
{
    var _w = bmp_w(_b);
    var _cw = (_b.mode == 0) ? 4 : 8;
    var _x0 = (_x div _cw) * _cw;
    var _y0 = (_y div 8) * 8;
    var _cnt = array_create(16, 0);
    for (var yy = 0; yy < 8; yy++)
    {
        for (var xx = 0; xx < _cw; xx++) { _cnt[buffer_peek(bm_cache.buf, (_y0 + yy) * _w + _x0 + xx, buffer_u8)] += 1; }
    }
    var _o = [];
    for (var k = 0; k < 16; k++)
    {
        if (_cnt[k] > 0 && !(_b.mode == 0 && k == _b.bg)) { array_push(_o, k); }
    }
    return _o;
}

/// Mouse on the canvas: what the tools do
function bm_canvas_input(_b, _in, _mx, _my, _hot)
{
    var _w = bmp_w(_b);
    var _cmx = clamp(_mx, 0, _w - 1);
    var _cmy = clamp(_my, 0, BMP_H - 1);
    var _press = (ui_pressed || ui_rpressed) && _in;
    var _alt = keyboard_check(vk_alt);
    // Alt+click or the Pick tool: pick a colour
    if (_press && (_alt || bm_tool == BM_PICK))
    {
        var _pv = buffer_peek(bm_cache.buf, _my * _w + _mx, buffer_u8);
        if (ui_pressed) { bm_pen = _pv; } else { bm_pen2 = _pv; }
        ui_take_click();
        return;
    }
    // stamping a copy: left places it, right lets it go
    if (bm_stamping)
    {
        if (_press && ui_pressed)
        {
            undo_mark("bmstamp" + string(current_time));
            bm_stamp(_b, _mx, _my);
            bm_commit(_b);
            ui_take_click();
        }
        else if (_press && ui_rpressed)
        {
            bm_stamping = false;
            ui_take_click();
        }
        return;
    }
    if (_press)
    {
        bm_drag = ui_pressed ? 1 : 2;
        ui_take_click();
        bm_ax = _mx;
        bm_ay = _my;
        bm_lx = _mx;
        bm_ly = _my;
        var _col = (bm_drag == 1) ? bm_pen : bm_pen2;
        switch (bm_tool)
        {
            case BM_BRUSH:
                undo_mark("bmpaint" + string(current_time));
                bm_text_end();
                if (keyboard_check(vk_shift) && bm_last_x >= 0) { bm_line(_b, bm_last_x, bm_last_y, _mx, _my, _col); }
                else { bm_stamp_brush(_b, _mx, _my, _col); }
                break;
            case BM_FILL:
                undo_mark("bmfill" + string(current_time));
                bm_fill(_b, _mx, _my, _col);
                bm_commit(_b);
                bm_drag = 0;
                break;
            case BM_TEXT:
                bm_texting = true;
                bm_tx = _mx;
                bm_ty = _my;
                bm_tx0 = _mx;
                ui_focus = "bm_text";
                keyboard_string = "";
                bm_drag = 0;
                break;
        }
    }
    if (bm_drag > 0)
    {
        var _col2 = (bm_drag == 1) ? bm_pen : bm_pen2;
        var _down = (bm_drag == 1) ? ui_held : ui_rheld;
        if (bm_tool == BM_BRUSH && _down && (_cmx != bm_lx || _cmy != bm_ly))
        {
            bm_line(_b, bm_lx, bm_ly, _cmx, _cmy, _col2);
            bm_lx = _cmx;
            bm_ly = _cmy;
        }
        if (!_down)
        {
            // let go: shapes are drawn now
            switch (bm_tool)
            {
                case BM_BRUSH:
                    bm_commit(_b);
                    bm_last_x = bm_lx;
                    bm_last_y = bm_ly;
                    break;
                case BM_LINE:
                    undo_mark("bmline" + string(current_time));
                    bm_line(_b, bm_ax, bm_ay, _cmx, _cmy, _col2);
                    bm_commit(_b);
                    break;
                case BM_BOX:
                    undo_mark("bmbox" + string(current_time));
                    bm_box(_b, bm_ax, bm_ay, _cmx, _cmy, _col2);
                    bm_commit(_b);
                    break;
                case BM_ELLIPSE:
                    undo_mark("bmell" + string(current_time));
                    bm_ellipse(_b, bm_ax, bm_ay, _cmx, _cmy, _col2);
                    bm_commit(_b);
                    break;
                case BM_GRADIENT:
                    undo_mark("bmgrad" + string(current_time));
                    bm_gradient(_b, bm_ax, bm_ay, _cmx, _cmy);
                    bm_commit(_b);
                    break;
                case BM_COPY:
                    bm_grab(_b, bm_ax, bm_ay, _cmx, _cmy);
                    toast("Copied " + string(bm_clip.w) + " x " + string(bm_clip.h) + " - click to stamp it, right-click when done", 0);
                    break;
            }
            bm_drag = 0;
        }
    }
    // typing on the bitmap
    if (bm_texting) { bm_text_step(_b, _in); }
}

function bm_text_end()
{
    if (bm_texting)
    {
        bm_texting = false;
        if (ui_focus == "bm_text") { ui_focus = ""; }
    }
}

function bm_text_step(_b, _in)
{
    if (keyboard_check_pressed(vk_escape) || ((ui_pressed || ui_rpressed) && !_in))
    {
        bm_text_end();
        return;
    }
    if (keyboard_check_pressed(vk_enter))
    {
        bm_tx = bm_tx0;
        bm_ty += 8;
        keyboard_string = "";
        return;
    }
    if (keyboard_check_pressed(vk_backspace))
    {
        bm_tx = max(0, bm_tx - 8);
        keyboard_string = "";
        return;
    }
    var _s = keyboard_string;
    if (_s == "") { return; }
    keyboard_string = "";
    undo_mark("bmtext");
    for (var i = 1; i <= string_length(_s); i++)
    {
        var _ch = string_char_at(_s, i);
        if (ord(_ch) < 32) { continue; }
        bm_text_char(_b, _ch, bm_tx, bm_ty, bm_pen);
        bm_tx += 8;
    }
    bm_commit(_b);
}

/// Tool keys (not while typing on the bitmap or in a text box)
function bm_keys(_b)
{
    if (ui_focus != "" || is_struct(bm_imp) || keyboard_check(vk_control)) { return; }
    var _k = bm_tool_keys();
    for (var i = 0; i < array_length(_k); i++)
    {
        if (keyboard_check_pressed(ord(_k[i]))) { bm_set_tool(i); }
    }
    if (keyboard_check_pressed(ord("X")) && bm_stamping) { bm_clip_flip(true); }
    if (keyboard_check_pressed(ord("Y")) && bm_stamping) { bm_clip_flip(false); }
    if (keyboard_check_pressed(219)) { bm_brush = max(0, bm_brush - 1); }
    if (keyboard_check_pressed(221)) { bm_brush = min(4, bm_brush + 1); }
    if (keyboard_check_pressed(vk_escape)) { bm_stamping = false; }
}

function bm_set_tool(_t)
{
    bm_tool = _t;
    bm_text_end();
    bm_drag = 0;
    if (_t != BM_COPY) { bm_stamping = false; }
}

/// The right panel: Paint and Bitmap tabs
function bm_tools_panel(_px, _y1, _x2, _y2, _b)
{
    ui_panel(_px, _y1, _x2, _y2, "");
    var _fx = _px + 20;
    var _fw = _x2 - _px - 40;
    var _tw = floor((_fw - 6) / 2);
    if (ui_tab("bm_tab_0", _fx, _y1 + 14, _tw, 32, "Paint", bm_tab == 0, "Paint|Tools, patterns and colours.")) { bm_tab = 0; }
    if (ui_tab("bm_tab_1", _fx + _tw + 6, _y1 + 14, _tw, 32, "Bitmap", bm_tab == 1, "Bitmap|Name, mode, background and border, turning it round, and saving it as a Koala, Art Studio or PNG file.")) { bm_tab = 1; }
    var _y = _y1 + 62;
    var _mc = (_b.mode == 0);
    if (bm_tab == 1)
    {
        bm_bitmap_tab(_fx, _y, _fw, _y2, _b);
        return;
    }
    var _content = 640;
    var _off = ui_scroll_begin("bm_tools", _px + 6, _y, _x2 - 6, _y2 - 8, _content);
    _y -= _off;
    // tools
    ui_heading(_fx, _y, "Tools");
    _y += 18;
    var _names = bm_tool_names();
    var _keys = bm_tool_keys();
    var _thelp = [
        "Brush|Paint freehand. Shift+click draws a straight line from the last point.",
        "Line|Drag from one end to the other.",
        "Box|Drag from corner to corner. Switch Filled on for a solid box.",
        "Ellipse|Drag the box it fits in. Switch Filled on for a solid one.",
        "Fill|Fills the area of one colour you click in (with the pattern below).",
        "Gradient|Drag across an area of one colour: it fills with a dithered blend from the pen colour to the second colour, along your drag.",
        "Text|Click where to start, then type in the C64's own letters. Enter starts a new line, Esc stops.",
        "Pick|Click a pixel to take its colour as the pen (right button: the second colour). Alt+click does this with any tool.",
        "Copy|Drag a box round part of the picture, then click to stamp copies of it; right-click when done. X and Y turn the copy round. The background (or black, in hi-res) is see-through."
    ];
    var _bw3 = floor((_fw - 12) / 3);
    for (var t = 0; t < 9; t++)
    {
        var _tx = _fx + (t mod 3) * (_bw3 + 6);
        var _ty = _y + (t div 3) * 38;
        if (ui_button("bm_tool_" + string(t), _tx, _ty, _bw3, 32, _names[t], _thelp[t] + "  (key " + _keys[t] + ")", (bm_tool == t) ? BTN_ACCENT : BTN_GHOST)) { bm_set_tool(t); }
    }
    _y += 3 * 38 + 10;
    // the tool's options
    if (bm_tool <= BM_ELLIPSE)
    {
        ui_heading(_fx, _y, "Brush size  ( [ and ] )");
        _y += 18;
        var _sz = bm_brush_sizes();
        var _bw5 = floor((_fw - 16) / 5);
        for (var s = 0; s < 5; s++)
        {
            if (ui_button("bm_size_" + string(s), _fx + s * (_bw5 + 4), _y, _bw5, 30, string(_sz[s]), "Brush size|" + string(_sz[s]) + " screen pixels across" + (_mc ? " (multicolour pixels are two wide)." : "."), (bm_brush == s) ? BTN_ON : BTN_GHOST)) { bm_brush = s; }
        }
        _y += 40;
    }
    if (bm_tool == BM_BOX || bm_tool == BM_ELLIPSE)
    {
        bm_filled = ui_toggle("bm_filled", _fx, _y, "Filled", bm_filled, "Filled|Draw it solid instead of as an outline.");
        _y += 34;
    }
    if (bm_tool == BM_GRADIENT)
    {
        bm_shades = ui_toggle("bm_shades", _fx, _y, "Through the shades between", bm_shades, "Shades between|Blend through the C64 colours that are lighter than one end and darker than the other - smoother, like a copper bar.");
        _y += 34;
    }
    if (bm_tool == BM_COPY && bm_stamping)
    {
        if (ui_button("bm_cflip_h", _fx, _y, _tw, 30, "Turn round", "Turn the copy round|Mirrors the copy left to right (key X).", BTN_NORMAL)) { bm_clip_flip(true); }
        if (ui_button("bm_cflip_v", _fx + _tw + 6, _y, _tw, 30, "Upside down", "Turn the copy upside down|(key Y)", BTN_NORMAL)) { bm_clip_flip(false); }
        _y += 40;
    }
    if (bm_tool <= BM_FILL)
    {
        ui_heading(_fx, _y, "Pattern");
        _y += 18;
        var _pn = bm_pattern_names();
        var _bw5b = floor((_fw - 16) / 5);
        for (var p = 0; p < 5; p++)
        {
            if (ui_button("bm_pat_" + string(p), _fx + p * (_bw5b + 4), _y, _bw5b, 30, _pn[p], "Pattern|Paints only part of the pixels, in an even dot pattern - the C64 way to make in-between shades.", (bm_pattern == p) ? BTN_ON : BTN_GHOST)) { bm_pattern = p; }
        }
        _y += 40;
    }
    // colours
    ui_heading(_fx, _y, "Colours");
    _y += 18;
    var _cell = floor((_fw - 7 * 4) / 8);
    ds_map_replace(ui_rects, "bm_pal", [_fx, _y, _fx + 8 * (_cell + 4) - 4, _y + 2 * (_cell + 4) - 4]);
    for (var i = 0; i < 16; i++)
    {
        var _sx = _fx + (i mod 8) * (_cell + 4);
        var _sy = _y + (i div 8) * (_cell + 4);
        var _hot = ui_register("bm_pal_" + string(i), _sx, _sy, _sx + _cell, _sy + _cell, global.C64PAL_NAMES[i] + "|Left click: the pen colour. Right click: the second colour (right button, gradients, Fill with the right button).");
        ui_rrect(_sx, _sy, _sx + _cell, _sy + _cell, 6, c64col(i), c64col(i), 1);
        ui_rrect_line(_sx, _sy, _sx + _cell, _sy + _cell, 6, c_black, 0.5, 1);
        var _tc = (global.BMP_LUMA[i] > 128) ? c_black : c_white;
        if (i == bm_pen)
        {
            ui_rrect_line(_sx - 3, _sy - 3, _sx + _cell + 3, _sy + _cell + 3, 8, c_white, 1, 2);
            ui_text(_sx + 5, _sy + 4, "1", _tc, fa_left, fa_top, global.f_small, 1);
        }
        if (i == bm_pen2) { ui_text(_sx + _cell - 5, _sy + _cell - 2, "2", _tc, fa_right, fa_bottom, global.f_small, 1); }
        if (_hot && i != bm_pen) { ui_rrect_line(_sx - 2, _sy - 2, _sx + _cell + 2, _sy + _cell + 2, 8, global.TH.accent, 0.8, 1); }
        if (_hot && ui_pressed) { bm_pen = i; ui_take_click(); }
        if (_hot && ui_rpressed) { bm_pen2 = i; ui_take_click(); }
    }
    _y += 2 * (_cell + 4) + 8;
    ui_text(_fx, _y + 8, "Pen: " + global.C64PAL_NAMES[bm_pen] + "    Second: " + global.C64PAL_NAMES[bm_pen2], global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
    _y += 28;
    if (_mc)
    {
        ui_heading(_fx, _y, "Background (the whole picture)");
        var _nb = ui_colour_drop("bm_bg", _fx, _y + 18, _fw, 32, _b.bg, "Background colour|Multicolour bitmaps share one background colour, which every cell can use as well as its own 3. Changing it changes every pixel of the old background colour.");
        if (_nb != _b.bg)
        {
            undo_mark("bmbg" + string(current_time));
            bm_set_bg(_b, _nb);
        }
        _y += 62;
    }
    bm_grid = ui_toggle("bm_grid", _fx, _y, "Show the 8 x 8 cells", bm_grid, "Cells|Shows the 40 x 25 cells. Each holds " + (_mc ? "the background + 3 colours" : "2 colours") + ".");
    ui_scroll_end("bm_tools", _px + 6, _y1 + 62, _x2 - 6, _y2 - 8, _content);
}

function bm_bitmap_tab(_fx, _y, _fw, _y2, _b)
{
    var _i = bm_sel;
    ui_heading(_fx, _y, "Name");
    set_val(_b, "name", ui_textfield("bm_name", _fx, _y + 18, _fw, 32, _b.name, 24, "Name|A name to find it by in the lists."), "bmname");
    _y += 62;
    ui_heading(_fx, _y, "Mode");
    var _nm = ui_dropdown("bm_mode", _fx, _y + 18, _fw, 30, bmp_mode_names(), _b.mode, "Mode|Multicolour: pixels twice as wide, each 4 x 8 cell holds the background + 3 colours. Hi-res: full detail, each 8 x 8 cell holds 2 colours. Switching converts the picture (you can Undo it).");
    if (_nm != _b.mode)
    {
        undo_mark("bmmode" + string(current_time));
        bm_set_mode(_b, _nm);
        bm_stamping = false;
    }
    _y += 60;
    ui_heading(_fx, _y, "Border");
    set_val(_b, "border", ui_colour_drop("bm_border", _fx, _y + 18, _fw, 32, _b.border, "Border colour|The colour round the picture while it shows."), "bmborder");
    _y += 62;
    var _tw = floor((_fw - 12) / 3);
    if (ui_button("bm_fliph", _fx, _y, _tw, 30, "Flip H", "Flip horizontally|Turns the whole picture round, left to right. You can Undo this.", BTN_NORMAL))
    {
        undo_mark("bmflip" + string(current_time));
        bm_cache_get(_b);
        bm_flip_all(_b, true);
        bm_commit(_b);
    }
    if (ui_button("bm_flipv", _fx + _tw + 6, _y, _tw, 30, "Flip V", "Flip vertically|Turns the whole picture upside down. You can Undo this.", BTN_NORMAL))
    {
        undo_mark("bmflip" + string(current_time));
        bm_cache_get(_b);
        bm_flip_all(_b, false);
        bm_commit(_b);
    }
    if (ui_button("bm_clear", _fx + 2 * (_tw + 6), _y, _fw - 2 * (_tw + 6), 30, "Clear", "Clear|Fills the whole picture with the " + ((_b.mode == 0) ? "background colour" : "second colour") + ". You can Undo this.", BTN_DANGER))
    {
        undo_mark("bmclear" + string(current_time));
        var _cc = (_b.mode == 0) ? _b.bg : bm_pen2;
        _b.pix = string_repeat((_cc < 10) ? chr(48 + _cc) : chr(87 + _cc), bmp_w(_b) * BMP_H);
    }
    _y += 46;
    ui_heading(_fx, _y, "Save as a file");
    _y += 18;
    var _ext = (_b.mode == 0) ? "Koala .kla" : "Art Studio .art";
    var _hw = floor((_fw - 6) / 2);
    if (ui_button("bm_save_c64", _fx, _y, _hw, 30, _ext, "Save for C64 paint programs|Koala Painter (multicolour) or Art Studio (hi-res) - the formats C64 artists and tools use.", BTN_NORMAL))
    {
        var _fe = (_b.mode == 0) ? ".kla" : ".art";
        var _f = get_save_filename(((_b.mode == 0) ? "Koala Painter|*.kla" : "Art Studio|*.art"), string_replace_all(_b.name, " ", "_") + _fe);
        if (_f != "")
        {
            if (string_lower(filename_ext(_f)) != _fe) { _f += _fe; }
            bmp_save_c64_file(_b, _f);
            toast("Saved " + filename_name(_f), 0);
        }
    }
    if (ui_button("bm_save_png", _fx + _hw + 6, _y, _fw - _hw - 6, 30, "PNG", "Save as PNG|A 320 x 200 picture of it in the C64's colours.", BTN_NORMAL))
    {
        var _f2 = get_save_filename("PNG picture|*.png", string_replace_all(_b.name, " ", "_") + ".png");
        if (_f2 != "")
        {
            if (string_lower(filename_ext(_f2)) != ".png") { _f2 += ".png"; }
            var _s = bmp_to_surface(_b);
            surface_save(_s, _f2);
            surface_free(_s);
            toast("Saved " + filename_name(_f2), 0);
        }
    }
    _y += 46;
    ui_heading(_fx, _y, "Memory");
    var _txt = "In the game it takes " + string(bmp_bytes(_b)) + " bytes (about " + string(round(bmp_bytes(_b) / 1024)) + " KB) - once, however many places show it. ";
    _txt += (proj.game_type == 1) ? "A map game has room for one bitmap (the same one can show in several places). " : "A single-screen game has room for two (three with a small game). ";
    _txt += "As the loading screen only, it costs no game memory: it goes in the disk's loader.";
    var _u = bmp_uses(_i);
    _txt += (_u == "") ? " It is not shown anywhere yet." : " It shows: " + _u + ".";
    ui_text_wrap(_fx, _y + 20, _txt, global.TH.text_dim, _fw, global.f_small, 1);
}

/// The import settings, while a picture is being brought in (the Dev Machine's import controls:
/// placement, dither and its strength, colour adjustments), with Use / Cancel kept in view
function bm_import_panel(_px, _y1, _x2, _y2)
{
    ui_panel(_px, _y1, _x2, _y2, "Import picture");
    var _fx = _px + 20;
    var _fw = _x2 - _px - 40;
    var _st = bmp_import_settings_fix(bm_imp.set);
    var _old = json_stringify(_st);
    var _hw = floor((_fw - 6) / 2);
    var _top = _y1 + 50;
    var _bot = _y2 - 62;
    var _content = 1010;
    var _off = ui_scroll_begin("bmi_scroll", _px + 6, _top, _x2 - 6, _bot, _content);
    var _y = _top + 6 - _off;

    ui_heading(_fx, _y, "Mode");
    _st.mode = ui_dropdown("bmi_mode", _fx, _y + 18, _fw, 30, bmp_mode_names(), _st.mode, "Mode|Multicolour suits photos and painted art (more colours, wider pixels). Hi-res suits line art and text.");
    _y += 58;

    // where it goes
    ui_heading(_fx, _y, "Fit");
    _st.fit = ui_dropdown("bmi_fit", _fx, _y + 18, _fw, 30, bmp_fit_names(), _st.fit, "Fit|Fit shows the whole picture (black bars if its shape differs), Fill covers the screen and crops, Stretch squashes it to 320 x 200.");
    _y += 58;
    ui_heading(_fx, _y, "Zoom  " + string(round(_st.zoom)) + "%");
    _st.zoom = round(ui_slider("bmi_zoom", _fx, _y + 18, _fw, _st.zoom, 50, 300, "Zoom|Makes the picture bigger or smaller than the Fit size - zoom in on the part you want."));
    _y += 44;
    ui_heading(_fx, _y, "Move across");
    ui_heading(_fx + _hw + 6, _y, "Move up / down");
    _st.offx = round(ui_slider("bmi_offx", _fx, _y + 18, _hw, _st.offx, -100, 100, "Move across|Slides the picture left or right: -100 lines up its left edge, 100 its right edge."));
    _st.offy = round(ui_slider("bmi_offy", _fx + _hw + 6, _y + 18, _fw - _hw - 6, _st.offy, -100, 100, "Move up / down|Slides the picture up or down: -100 lines up its top edge, 100 its bottom edge."));
    _y += 50;

    // dither
    ui_heading(_fx, _y, "Dither");
    _st.dither = ui_dropdown("bmi_dither", _fx, _y + 18, _fw, 30, bmp_dither_names(), _st.dither, "Dither|How in-between colours are made from the C64's 16. Checker and Lines: a simple 2-step pattern. Bayer 4 x 4 and 8 x 8: even dot patterns (8 x 8 has finer steps). Smooth spreads each pixel's difference to its neighbours - best for photos. Soft (Atkinson) spreads less, for cleaner flat areas.");
    _y += 58;
    var _dst = (_st.dither == 0) ? "Dither strength  (no dither)" : "Dither strength  " + string(round(_st.amount)) + "%";
    ui_heading(_fx, _y, _dst);
    _st.amount = round(ui_slider("bmi_amount", _fx, _y + 18, _fw, _st.amount, 0, 100, "Dither strength|How strongly the dither mixes colours. Lower is cleaner and flatter, higher shows more shades as dots."));
    _y += 50;

    // colour
    ui_heading(_fx, _y, "Brightness  " + string(round(_st.bright)));
    _st.bright = round(ui_slider("bmi_bright", _fx, _y + 18, _fw, _st.bright, -100, 100, "Brightness|Lighter or darker before the colours are chosen."));
    _y += 44;
    ui_heading(_fx, _y, "Contrast  " + string(round(_st.contrast)));
    _st.contrast = round(ui_slider("bmi_contrast", _fx, _y + 18, _fw, _st.contrast, -100, 100, "Contrast|More contrast often helps with the C64's 16 colours."));
    _y += 44;
    ui_heading(_fx, _y, "Colourfulness  " + string(round(_st.sat)) + "%");
    _st.sat = round(ui_slider("bmi_sat", _fx, _y + 18, _fw, _st.sat, 0, 200, "Colourfulness|0 is grey, 100 as it is, 200 extra colourful."));
    _y += 44;
    ui_heading(_fx, _y, "Hue  " + string(round(_st.hue)));
    _st.hue = round(ui_slider("bmi_hue", _fx, _y + 18, _fw, _st.hue, -180, 180, "Hue|Turns every colour round the colour wheel - handy to steer a picture towards the C64's colours."));
    _y += 44;
    ui_heading(_fx, _y, "Softness  " + string(round(_st.blur)));
    _st.blur = round(ui_slider("bmi_blur", _fx, _y + 18, _fw, _st.blur, 0, 4, "Softness|Blurs the picture a little first: fewer stray dots in busy areas."));
    _y += 44;
    if (_st.mode == 0)
    {
        ui_heading(_fx, _y, "Background");
        var _bgn = ["Most used colour"];
        for (var k = 0; k < 16; k++) { array_push(_bgn, global.C64PAL_NAMES[k]); }
        _st.bg = ui_dropdown("bmi_bg", _fx, _y + 18, _fw, 30, _bgn, _st.bg + 1, "Background|Every cell can use the background colour as well as its own 3 - the most used colour usually works best.") - 1;
        _y += 58;
    }
    if (ui_button("bmi_reset", _fx, _y + 4, _fw, 30, "Reset the settings", "Reset|Back to the starting settings (the mode stays).", BTN_GHOST))
    {
        var _m = _st.mode;
        bm_imp.set = bmp_import_settings_new(_m);
        _st = bm_imp.set;
    }
    ui_scroll_end("bmi_scroll", _px + 6, _top, _x2 - 6, _bot, _content);

    if (json_stringify(_st) != _old)
    {
        bm_imp.dirty = true;
        bm_imp.t = current_time;
    }
    var _by = _y2 - 54;
    if (bm_imp.dirty) { ui_text(_fx, _by - 8, "Converting...", global.TH.warn, fa_left, fa_bottom, global.f_small, 1); }
    if (ui_button("bmi_ok", _fx, _by, _hw, 34, "Use picture", "Use this picture|Adds it as a new bitmap.", BTN_ACCENT)) { bm_import_finish(); return; }
    if (ui_button("bmi_cancel", _fx + _hw + 6, _by, _fw - _hw - 6, 34, "Cancel", "Cancel|Leaves the picture out.", BTN_NORMAL)) { bm_import_cancel(); }
}
