/// C64 ENGINE - chargen glyphs, C64 screen preview, sprite caches

function chargen_init()
{
    global.spr_chars = -1;
    global.chargen_rom = [];
    var _path = working_directory + "chargen";
    if (!file_exists(_path)) { return; }
    var _b = buffer_load(_path);
    if (_b == -1) { return; }
    global.chargen_rom = array_create(2048, 0);
    for (var k = 0; k < 2048; k++) { global.chargen_rom[k] = buffer_peek(_b, k, buffer_u8); }
    var _bits = array_create(2048, 0);
    for (var k2 = 0; k2 < 2048; k2++) { _bits[k2] = global.chargen_rom[k2]; }
    global.spr_chars = glyph_sheet_sprite(_bits);
    buffer_delete(_b);
}

/// 1x1 white pixel sprite for exact-size filled rectangles
function pixel_sprite_init()
{
    var _surf = surface_create(1, 1);
    mask_to_surface(_surf, 1, 1, [1]);
    global.spr_px = sprite_create_from_surface(_surf, 0, 0, 1, 1, false, false, 0, 0);
    surface_free(_surf);
}

/// Pixel-exact filled rectangle (w x h pixels)
function px_rect(_x, _y, _w, _h, _col)
{
    draw_sprite_ext(global.spr_px, 0, _x, _y, _w, _h, 0, _col, 1);
}

function draw_c64_char(_code, _x, _y, _scale, _col)
{
    if (global.spr_chars == -1)
    {
        if (_code != 32)
        {
            draw_set_colour(_col);
            draw_rectangle(_x + _scale, _y + _scale, _x + _scale * 7, _y + _scale * 7, false);
        }
        return;
    }
    draw_sprite_part_ext(global.spr_chars, 0, (_code mod 16) * 8, (_code div 16) * 8, 8, 8, _x, _y, _scale, _scale, _col, 1);
}

/// Draws the project screen (with border frame). Returns the screen-area origin [sx, sy].
function draw_c64_screen(_x, _y, _scale, _with_border)
{
    gpu_set_texfilter(false);
    var _sx = _x;
    var _sy = _y;
    if (_with_border)
    {
        draw_set_colour(c64col(proj.border));
        draw_rectangle(_x, _y, _x + 384 * _scale - 1, _y + 272 * _scale - 1, false);
        _sx = _x + 32 * _scale;
        _sy = _y + 35 * _scale;
    }
    draw_set_colour(c64col(proj.background));
    draw_rectangle(_sx, _sy, _sx + 320 * _scale - 1, _sy + 200 * _scale - 1, false);
    var _cs = 8 * _scale;
    for (var r = 0; r < 25; r++)
    {
        for (var c = 0; c < 40; c++)
        {
            var _i = r * 40 + c;
            var _ch = proj.chars[_i];
            if (_ch != 32)
            {
                draw_c64_char(_ch, _sx + c * _cs, _sy + r * _cs, _scale, c64col(proj.cols[_i]));
            }
        }
    }
    gpu_set_texfilter(true);
    return [_sx, _sy];
}

/// Writes a white/transparent mask straight into a surface (no 1-pixel draw calls,
/// which DirectX can rasterise as nothing). _mask = array of 0/1, row-major.
function mask_to_surface(_surf, _w, _h, _mask)
{
    var _buf = buffer_create(_w * _h * 4, buffer_fixed, 1);
    for (var i = 0; i < _w * _h; i++)
    {
        if (_mask[i] != 0) { buffer_write(_buf, buffer_u32, $ffffffff); }
        else { buffer_write(_buf, buffer_u32, 0); }
    }
    buffer_set_surface(_buf, _surf, 0);
    buffer_delete(_buf);
}

/// 128x128 sprite of 256 white 8x8 glyphs from 2048 charset bytes
function glyph_sheet_sprite(_bytes)
{
    var _mask = array_create(128 * 128, 0);
    for (var c = 0; c < 256; c++)
    {
        var _ox = (c mod 16) * 8;
        var _oy = (c div 16) * 8;
        for (var r = 0; r < 8; r++)
        {
            var _b = _bytes[c * 8 + r];
            if (_b == 0) { continue; }
            for (var bit = 0; bit < 8; bit++)
            {
                if ((_b & (128 >> bit)) != 0) { _mask[(_oy + r) * 128 + _ox + bit] = 1; }
            }
        }
    }
    var _surf = surface_create(128, 128);
    mask_to_surface(_surf, 128, 128, _mask);
    var _spr = sprite_create_from_surface(_surf, 0, 0, 128, 128, false, false, 0, 0);
    surface_free(_surf);
    return _spr;
}

/// Three white masks per sprite: own colour, shared A, shared B (tinted when drawn)
function spr_cache_update(_i)
{
    if (!surface_exists(spr_surf_own[_i])) { spr_surf_own[_i] = surface_create(24, 21); spr_dirty[_i] = true; }
    if (!surface_exists(spr_surf_sh[_i]))  { spr_surf_sh[_i] = surface_create(24, 21);  spr_dirty[_i] = true; }
    if (!surface_exists(spr_surf_sh2[_i])) { spr_surf_sh2[_i] = surface_create(24, 21); spr_dirty[_i] = true; }
    if (!spr_dirty[_i]) { return; }
    var _s = proj.sprites[_i];
    var _own = array_create(504, 0);
    var _ma = array_create(504, 0);
    var _mb = array_create(504, 0);
    if (_s.mc)
    {
        for (var p = 0; p < 252; p++)
        {
            var _v = _s.mcp[p];
            var _q = (p div 12) * 24 + (p mod 12) * 2;
            if (_v == 1) { _own[_q] = 1; _own[_q + 1] = 1; }
            if (_v == 2) { _ma[_q] = 1; _ma[_q + 1] = 1; }
            if (_v == 3) { _mb[_q] = 1; _mb[_q + 1] = 1; }
        }
    }
    else
    {
        for (var q = 0; q < 504; q++)
        {
            if (_s.hi[q] != 0) { _own[q] = 1; }
        }
    }
    mask_to_surface(spr_surf_own[_i], 24, 21, _own);
    mask_to_surface(spr_surf_sh[_i], 24, 21, _ma);
    mask_to_surface(spr_surf_sh2[_i], 24, 21, _mb);
    spr_dirty[_i] = false;
}

function draw_sprite_c64(_i, _x, _y, _scale, _colour, _alpha)
{
    if (_i < 0 || _i >= SPR_COUNT) { return; }
    spr_cache_update(_i);
    gpu_set_texfilter(false);
    draw_surface_ext(spr_surf_sh[_i], _x, _y, _scale, _scale, 0, c64col(proj.mc1), _alpha);
    draw_surface_ext(spr_surf_sh2[_i], _x, _y, _scale, _scale, 0, c64col(proj.mc2), _alpha);
    draw_surface_ext(spr_surf_own[_i], _x, _y, _scale, _scale, 0, c64col(_colour), _alpha);
    gpu_set_texfilter(true);
}

function spr_cache_free()
{
    for (var i = 0; i < SPR_COUNT; i++)
    {
        if (surface_exists(spr_surf_own[i])) { surface_free(spr_surf_own[i]); }
        if (surface_exists(spr_surf_sh[i])) { surface_free(spr_surf_sh[i]); }
        if (surface_exists(spr_surf_sh2[i])) { surface_free(spr_surf_sh2[i]); }
    }
}

function spr_mark_all_dirty()
{
    for (var i = 0; i < SPR_COUNT; i++) { spr_dirty[i] = true; }
}
