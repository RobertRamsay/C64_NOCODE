/// C64 NO-CODE STUDIO - Sprites workspace (pixel editor)

function spr_get_px(_s, _x, _y)
{
    if (_s.mc) { return _s.mcp[_y * 12 + _x]; }
    return _s.hi[_y * 24 + _x];
}

function spr_set_px(_s, _x, _y, _v)
{
    if (_s.mc) { _s.mcp[_y * 12 + _x] = _v; }
    else { _s.hi[_y * 24 + _x] = _v; }
}

function spr_transform(_s, _kind)
{
    var _w = 24;
    if (_s.mc) { _w = 12; }
    var _src = [];
    for (var i = 0; i < _w * 21; i++)
    {
        if (_s.mc) { array_push(_src, _s.mcp[i]); }
        else { array_push(_src, _s.hi[i]); }
    }
    for (var _iy = 0; _iy < 21; _iy++)
    {
        for (var _ix = 0; _ix < _w; _ix++)
        {
            var _sx = _ix;
            var _sy = _iy;
            var _v = 0;
            var _in = true;
            switch (_kind)
            {
                case "fliph": _sx = _w - 1 - _ix; break;
                case "flipv": _sy = 20 - _iy; break;
                case "left":  _sx = _ix + 1; break;
                case "right": _sx = _ix - 1; break;
                case "up":    _sy = _iy + 1; break;
                case "down":  _sy = _iy - 1; break;
            }
            if (_sx < 0 || _sx >= _w || _sy < 0 || _sy > 20) { _in = false; }
            if (_in) { _v = _src[_sy * _w + _sx]; }
            if (_kind == "invert")
            {
                _v = _src[_iy * _w + _ix];
                if (_s.mc)
                {
                    if (_v == 0) { _v = 1; }
                    else
                    {
                        if (_v == 1) { _v = 0; }
                    }
                }
                else
                {
                    _v = 1 - _v;
                }
            }
            if (_kind == "clear") { _v = 0; }
            spr_set_px(_s, _ix, _iy, _v);
        }
    }
}

/// Converts the sprite between hi-res and multicolour, keeping the shape roughly
function spr_set_mode(_s, _mc)
{
    if (_s.mc == _mc) { return; }
    if (_mc)
    {
        for (var i = 0; i < 252; i++)
        {
            var _y = i div 12;
            var _x = (i mod 12) * 2;
            var _on = 0;
            if (_s.hi[_y * 24 + _x] != 0 || _s.hi[_y * 24 + _x + 1] != 0) { _on = 1; }
            _s.mcp[i] = _on;
        }
    }
    else
    {
        for (var k = 0; k < 504; k++)
        {
            var _yy = k div 24;
            var _xx = (k mod 24) div 2;
            var _v = 0;
            if (_s.mcp[_yy * 12 + _xx] != 0) { _v = 1; }
            _s.hi[k] = _v;
        }
    }
    _s.mc = _mc;
}

function ws_sprites_draw(_x1, _y1, _x2, _y2)
{
    var _lw = 230;
    var _rw = 310;
    var _s = proj.sprites[spr_sel];

    // ---------------- sprite list ----------------
    ui_panel(_x1, _y1, _x1 + _lw, _y2, "Sprites");
    var _ly = _y1 + 54;
    var _rowh = floor(min(66, (_y2 - _ly - 10) / 8));
    for (var i = 0; i < 8; i++)
    {
        var _ry = _ly + i * _rowh;
        var _id = "spr_slot_" + string(i);
        var _hot = ui_register(_id, _x1 + 10, _ry, _x1 + _lw - 10, _ry + _rowh - 6, proj.sprites[i].name + "|Click to edit this sprite. Actors use sprites as their pictures.");
        var _tgt = 0;
        if (_hot) { _tgt = 1; }
        var _a = ui_anim_to(_id, _tgt);
        if (spr_sel == i)
        {
            ui_rrect(_x1 + 10, _ry, _x1 + _lw - 10, _ry + _rowh - 6, 10, global.TH.accent, global.TH.accent_dark, 0.9);
        }
        else
        {
            ui_rrect(_x1 + 10, _ry, _x1 + _lw - 10, _ry + _rowh - 6, 10, global.TH.btn_hot_top, global.TH.btn_hot_bot, _a);
        }
        var _th = _rowh - 14;
        ui_rrect(_x1 + 16, _ry + 4, _x1 + 16 + _th * 1.15, _ry + 4 + _th, 6, c64col(proj.background), c64col(proj.background), 1);
        var _sc = (_th - 4) / 21;
        draw_sprite_c64(i, _x1 + 18 + (_th * 1.15 - 24 * _sc) / 2 - 2, _ry + 6, _sc, proj.sprites[i].preview, 1);
        ui_text(_x1 + 26 + _th * 1.15, _ry + (_rowh - 6) * 0.5 - 8, ui_text_fit(proj.sprites[i].name, global.f_bold, _lw - 60 - _th), global.TH.text, fa_left, fa_middle, global.f_bold, 1);
        var _mode = "Hi-res";
        if (proj.sprites[i].mc) { _mode = "Multicolour"; }
        ui_text(_x1 + 26 + _th * 1.15, _ry + (_rowh - 6) * 0.5 + 9, _mode, global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
        if (_hot && ui_pressed)
        {
            spr_sel = i;
            ui_take_click();
        }
    }

    // ---------------- editor grid ----------------
    var _cx1 = _x1 + _lw + 12;
    var _cx2 = _x2 - _rw - 12;
    ui_panel(_cx1, _y1, _cx2, _y2, "");
    var _cols = 24;
    var _pw = 1;
    if (_s.mc)
    {
        _cols = 12;
        _pw = 2;
    }
    var _ps = floor(min((_cx2 - _cx1 - 40) / 24, (_y2 - _y1 - 70) / 21));
    _ps = max(6, _ps);
    var _gw = 24 * _ps;
    var _gh = 21 * _ps;
    var _gx = floor((_cx1 + _cx2 - _gw) / 2);
    var _gy = floor(_y1 + 20 + ((_y2 - _y1 - 40) - _gh) / 2);
    ui_rrect(_gx - 8, _gy - 8, _gx + _gw + 8, _gy + _gh + 8, 10, c_black, c_black, 0.35);
    draw_set_colour(c64col(proj.background));
    draw_rectangle(_gx, _gy, _gx + _gw - 1, _gy + _gh - 1, false);
    var _cw = _ps * _pw;
    for (var py = 0; py < 21; py++)
    {
        for (var px = 0; px < _cols; px++)
        {
            var _v = spr_get_px(_s, px, py);
            if (_v != 0)
            {
                var _c = _s.preview;
                if (_s.mc)
                {
                    if (_v == 2) { _c = proj.mc1; }
                    if (_v == 3) { _c = proj.mc2; }
                }
                draw_set_colour(c64col(_c));
                draw_rectangle(_gx + px * _cw, _gy + py * _ps, _gx + px * _cw + _cw - 1, _gy + py * _ps + _ps - 1, false);
            }
        }
    }
    draw_set_alpha(0.14);
    for (var gx = 0; gx <= _cols; gx++)
    {
        var _lc = c_white;
        draw_line_colour(_gx + gx * _cw, _gy, _gx + gx * _cw, _gy + _gh, _lc, _lc);
    }
    for (var gy = 0; gy <= 21; gy++) { draw_line_colour(_gx, _gy + gy * _ps, _gx + _gw, _gy + gy * _ps, c_white, c_white); }
    draw_set_alpha(0.35);
    for (var bx = 1; bx < 3; bx++) { draw_line_colour(_gx + bx * 8 * _ps, _gy, _gx + bx * 8 * _ps, _gy + _gh, global.TH.accent, global.TH.accent); }
    draw_set_alpha(1);

    var _hot2 = ui_register("spr_grid", _gx, _gy, _gx + _gw - 1, _gy + _gh - 1, "Sprite canvas|Left-click to draw with the selected pen, right-click to rub out. Sprites are 24 x 21 pixels; multicolour pixels are twice as wide.");
    if (_hot2)
    {
        var _hx = clamp(floor((ui_mx - _gx) / _cw), 0, _cols - 1);
        var _hy = clamp(floor((ui_my - _gy) / _ps), 0, 20);
        draw_set_alpha(0.3);
        draw_set_colour(global.TH.accent);
        draw_rectangle(_gx + _hx * _cw, _gy, _gx + _hx * _cw + _cw - 1, _gy + _gh - 1, true);
        draw_rectangle(_gx, _gy + _hy * _ps, _gx + _gw - 1, _gy + _hy * _ps + _ps - 1, true);
        draw_set_alpha(1);
        draw_rectangle_colour(_gx + _hx * _cw, _gy + _hy * _ps, _gx + _hx * _cw + _cw - 1, _gy + _hy * _ps + _ps - 1, c_white, c_white, c_white, c_white, true);
        ui_text(_gx, _gy + _gh + 14, "X " + string(_hx) + "   Y " + string(_hy), global.TH.text_dim, fa_left, fa_top, global.f_small, 1);
        if (ui_pressed || ui_rpressed)
        {
            undo_mark("sprdraw" + string(current_time));
            spr_drawing = true;
            ui_take_click();
        }
        if (spr_drawing)
        {
            var _pen = 1;
            if (_s.mc) { _pen = spr_pen; }
            if (ui_held && spr_get_px(_s, _hx, _hy) != _pen)
            {
                spr_set_px(_s, _hx, _hy, _pen);
                spr_dirty[spr_sel] = true;
                proj_dirty = true;
            }
            if (ui_rheld && spr_get_px(_s, _hx, _hy) != 0)
            {
                spr_set_px(_s, _hx, _hy, 0);
                spr_dirty[spr_sel] = true;
                proj_dirty = true;
            }
        }
    }
    if (!ui_held && !ui_rheld) { spr_drawing = false; }

    // ---------------- properties ----------------
    var _px = _x2 - _rw;
    ui_panel(_px, _y1, _x2, _y2, "Sprite " + string(spr_sel + 1));
    var _fx = _px + 20;
    var _fw = _rw - 40;
    var _y = _y1 + 56;
    ui_heading(_fx, _y, "Name");
    set_val(_s, "name", ui_textfield("spr_name", _fx, _y + 18, _fw, 32, _s.name, 20, "Sprite name|A friendly name so you can find this sprite when choosing actors."), "sprname");
    _y += 62;
    var _mc = ui_toggle("spr_mc", _fx, _y, "Multicolour", _s.mc, "Multicolour mode|Multicolour sprites have 4 colours (own colour + 2 shared) but pixels are twice as wide. Hi-res has 1 colour but finer detail.");
    if (_mc != _s.mc)
    {
        undo_mark("sprmode" + string(current_time));
        spr_set_mode(_s, _mc);
        spr_dirty[spr_sel] = true;
    }
    _y += 38;
    if (_s.mc)
    {
        ui_heading(_fx, _y, "Pen");
        var _pens = ["Own colour", "Shared A", "Shared B"];
        var _pc = [_s.preview, proj.mc1, proj.mc2];
        var _phelp = ["Own colour|Pixels in the actor's own colour. Each actor can have a different own colour.",
                      "Shared A|Pixels in shared colour A. All multicolour sprites share this colour.",
                      "Shared B|Pixels in shared colour B. All multicolour sprites share this colour."];
        var _pw3 = floor((_fw - 16) / 3);
        for (var p = 0; p < 3; p++)
        {
            var _bx = _fx + p * (_pw3 + 8);
            var _st = BTN_GHOST;
            if (spr_pen == p + 1) { _st = BTN_ACCENT; }
            if (ui_button("spr_pen_" + string(p), _bx, _y + 18, _pw3, 44, "", _phelp[p], _st)) { spr_pen = p + 1; }
            ui_rrect(_bx + 8, _y + 24, _bx + 24, _y + 40, 4, c64col(_pc[p]), c64col(_pc[p]), 1);
            ui_text(_bx + 8, _y + 52, _pens[p], global.TH.text, fa_left, fa_middle, global.f_small, 1);
        }
        _y += 74;
        var _half = floor((_fw - 12) / 2);
        ui_heading(_fx, _y, "Shared A");
        if (set_val(proj, "mc1", ui_colour_drop("spr_mc1", _fx, _y + 18, _half, 32, proj.mc1, "Shared colour A|Used by every multicolour sprite in the game."), "mc1")) { spr_mark_all_dirty(); }
        ui_heading(_fx + _half + 12, _y, "Shared B");
        if (set_val(proj, "mc2", ui_colour_drop("spr_mc2", _fx + _half + 12, _y + 18, _half, 32, proj.mc2, "Shared colour B|Used by every multicolour sprite in the game."), "mc2")) { spr_mark_all_dirty(); }
        _y += 62;
    }
    ui_heading(_fx, _y, "Preview colour");
    if (set_val(_s, "preview", ui_colour_drop("spr_prev", _fx, _y + 18, _fw, 32, _s.preview, "Preview colour|The colour used while drawing. Each actor picks its own colour on the Actors page."), "sprprev")) { spr_dirty[spr_sel] = true; }
    _y += 62;

    ui_heading(_fx, _y, "Change the whole sprite");
    _y += 18;
    var _bw = floor((_fw - 16) / 3);
    var _ops = ["Flip H", "Flip V", "Invert", "Left", "Right", "Clear", "Up", "Down", "Copy"];
    var _kinds = ["fliph", "flipv", "invert", "left", "right", "clear", "up", "down", "copy"];
    var _ohelp = ["Flip horizontally|Mirrors the sprite left to right - handy for making a character face the other way.",
                  "Flip vertically|Turns the sprite upside down.",
                  "Invert|Swaps drawn and empty pixels.",
                  "Shift left|Moves every pixel one step left.",
                  "Shift right|Moves every pixel one step right.",
                  "Clear|Rubs out the whole sprite. You can Undo this.",
                  "Shift up|Moves every pixel one step up.",
                  "Shift down|Moves every pixel one step down.",
                  "Copy|Copies this sprite so you can paste it into another slot."];
    for (var o = 0; o < 9; o++)
    {
        var _ox = _fx + (o mod 3) * (_bw + 8);
        var _oy = _y + (o div 3) * 38;
        var _sty = BTN_NORMAL;
        if (_kinds[o] == "clear") { _sty = BTN_DANGER; }
        if (ui_button("spr_op_" + _kinds[o], _ox, _oy, _bw, 32, _ops[o], _ohelp[o], _sty))
        {
            if (_kinds[o] == "copy")
            {
                spr_clip = json_stringify(_s);
                toast("Sprite copied", 0);
            }
            else
            {
                undo_mark("sprop" + string(current_time));
                spr_transform(_s, _kinds[o]);
                spr_dirty[spr_sel] = true;
            }
        }
    }
    _y += 3 * 38;
    var _pst = BTN_GHOST;
    if (spr_clip != "") { _pst = BTN_NORMAL; }
    if (ui_button("spr_paste", _fx, _y, _fw, 32, "Paste into this slot", "Paste|Replaces this sprite with the one you copied (the name is kept).", _pst))
    {
        if (spr_clip != "")
        {
            undo_mark("sprpaste" + string(current_time));
            var _keep = _s.name;
            var _copy = json_parse(spr_clip);
            var _ns = struct_overlay(sprite_new(_keep), _copy);
            _ns.name = _keep;
            proj.sprites[spr_sel] = _ns;
            spr_dirty[spr_sel] = true;
        }
        else
        {
            toast("Copy a sprite first", 1);
        }
    }
    _y += 46;
    if (_y + 70 < _y2)
    {
        ui_heading(_fx, _y, "Actual size");
        ui_inset(_fx, _y + 18, _fx + _fw, min(_y2 - 14, _y + 18 + 21 * 3 + 16), 8);
        draw_sprite_c64(spr_sel, _fx + 10, _y + 26, 1, _s.preview, 1);
        draw_sprite_c64(spr_sel, _fx + 50, _y + 26, 2, _s.preview, 1);
        if (_fw > 200) { draw_sprite_c64(spr_sel, _fx + 112, _y + 26, 3, _s.preview, 1); }
    }
}
