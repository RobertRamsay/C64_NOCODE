/// C64 NO-CODE STUDIO - chargen glyphs, C64 screen preview, sprite caches

function chargen_init()
{
    global.spr_chars = -1;
    var _path = working_directory + "chargen";
    if (!file_exists(_path)) { return; }
    var _b = buffer_load(_path);
    if (_b == -1) { return; }
    var _surf = surface_create(128, 128);
    surface_set_target(_surf);
    draw_clear_alpha(c_black, 0);
    draw_set_colour(c_white);
    for (var c = 0; c < 256; c++)
    {
        var _ox = (c mod 16) * 8;
        var _oy = (c div 16) * 8;
        for (var r = 0; r < 8; r++)
        {
            var _byte = buffer_peek(_b, c * 8 + r, buffer_u8);
            for (var bit = 0; bit < 8; bit++)
            {
                if ((_byte & (128 >> bit)) != 0)
                {
                    draw_rectangle(_ox + bit, _oy + r, _ox + bit, _oy + r, false);
                }
            }
        }
    }
    surface_reset_target();
    global.spr_chars = sprite_create_from_surface(_surf, 0, 0, 128, 128, false, false, 0, 0);
    surface_free(_surf);
    buffer_delete(_b);
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

function spr_cache_update(_i)
{
    if (!surface_exists(spr_surf_own[_i])) { spr_surf_own[_i] = surface_create(24, 21); spr_dirty[_i] = true; }
    if (!surface_exists(spr_surf_sh[_i]))  { spr_surf_sh[_i] = surface_create(24, 21);  spr_dirty[_i] = true; }
    if (!spr_dirty[_i]) { return; }
    var _s = proj.sprites[_i];
    surface_set_target(spr_surf_own[_i]);
    draw_clear_alpha(c_black, 0);
    draw_set_colour(c_white);
    if (_s.mc)
    {
        for (var p = 0; p < 252; p++)
        {
            if (_s.mcp[p] == 1)
            {
                var _px = (p mod 12) * 2;
                var _py = p div 12;
                draw_rectangle(_px, _py, _px + 1, _py, false);
            }
        }
    }
    else
    {
        for (var q = 0; q < 504; q++)
        {
            if (_s.hi[q] != 0)
            {
                draw_rectangle(q mod 24, q div 24, q mod 24, q div 24, false);
            }
        }
    }
    surface_reset_target();

    surface_set_target(spr_surf_sh[_i]);
    draw_clear_alpha(c_black, 0);
    if (_s.mc)
    {
        for (var m = 0; m < 252; m++)
        {
            var _v = _s.mcp[m];
            if (_v == 2 || _v == 3)
            {
                var _c = proj.mc1;
                if (_v == 3) { _c = proj.mc2; }
                draw_set_colour(c64col(_c));
                var _mx = (m mod 12) * 2;
                var _my = m div 12;
                draw_rectangle(_mx, _my, _mx + 1, _my, false);
            }
        }
    }
    surface_reset_target();
    spr_dirty[_i] = false;
}

function draw_sprite_c64(_i, _x, _y, _scale, _colour, _alpha)
{
    if (_i < 0 || _i > 7) { return; }
    spr_cache_update(_i);
    gpu_set_texfilter(false);
    draw_surface_ext(spr_surf_sh[_i], _x, _y, _scale, _scale, 0, c_white, _alpha);
    draw_surface_ext(spr_surf_own[_i], _x, _y, _scale, _scale, 0, c64col(_colour), _alpha);
    gpu_set_texfilter(true);
}

function spr_cache_free()
{
    for (var i = 0; i < 8; i++)
    {
        if (surface_exists(spr_surf_own[i])) { surface_free(spr_surf_own[i]); }
        if (surface_exists(spr_surf_sh[i])) { surface_free(spr_surf_sh[i]); }
    }
}

function spr_mark_all_dirty()
{
    for (var i = 0; i < 8; i++) { spr_dirty[i] = true; }
}
