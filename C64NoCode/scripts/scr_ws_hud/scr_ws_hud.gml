/// C64 ENGINE - the UI page (ported from ADAM's UI page): design your own HUD.
/// Left: switch it on, where it goes, its height, the frame and font styles, and the fields.
/// Centre: the game screen with the HUD (drag a field to move it), then the frame or font editor.
/// Right: the picked field. The model, the preview and the 6502 side are in scr_hud.

function ws_hud_draw(_x1, _y1, _x2, _y2)
{
    var _lw = 280;
    var _rw = 300;
    var _p = proj;
    var _u = _p.hud;
    var _cx1 = _x1 + _lw + 12;
    var _cx2 = _x2 - _rw - 12;
    var _nf = array_length(_u.fields);
    hud_sel = clamp(hud_sel, 0, max(0, _nf - 1));
    // coming back to the page: the Charset page may have changed the letters
    if (hud_away) { hud_sheet_tick += 1; hud_away = false; }

    // ---------------- left: on, where, the frame, the font, the fields ----------------
    ui_panel(_x1, _y1, _x1 + _lw, _y2, "Custom HUD");
    var _fx = _x1 + 16;
    var _fw = _lw - 32;
    var _y = _y1 + 52;
    var _on = ui_toggle("hud_on", _fx, _y, "Use a custom HUD", _u.on, "Custom HUD|Replaces the standard score line with your own panel, font and fields. Switch it off to go back to the standard one (your design is kept).");
    if (_on != _u.on)
    {
        undo_mark("hudon" + string(current_time));
        if (_on) { hud_switch_on(_p); }
        else { _u.on = false; }
        _nf = array_length(_u.fields);
    }
    _y += 36;
    var _half = floor((_fw - 8) / 2);
    var _rmax = hud_rows_max(_p);
    ui_heading(_fx, _y, "Where");
    ui_heading(_fx + _half + 8, _y, "Height (rows)");
    if (_p.game_type == 1)
    {
        ui_text(_fx + 4, _y + 33, "Top", global.TH.text_dim, fa_left, fa_middle, global.f_body, 1);
        ui_register("hud_pos", _fx, _y + 18, _fx + _half, _y + 48, "Where|A map game's HUD sits above the scrolling window: the window starts below the panel (or lower, as the World page sets).");
    }
    else
    {
        var _pos = _u.bottom ? 1 : 0;
        var _np = ui_dropdown("hud_pos", _fx, _y + 18, _half, 30, ["Top", "Bottom"], _pos, "Where|The panel's place on the screen. It covers those rows of the Screen page.");
        if (_np != _pos) { set_val(_u, "bottom", (_np == 1), "hudpos"); }
    }
    set_val(_u, "rows", ui_stepper("hud_rows", _fx + _half + 8, _y + 18, _half, clamp(_u.rows, 1, _rmax), 1, _rmax, "Height|Text rows of 8 lines: 1 is a slim strip, 3 a frame round one line of text. Fields on rows below the panel are not shown."), "hudrows");
    _y += 58;
    if (_p.game_type == 1) { ui_text(_fx, _y - 4, "Scrolling window from row " + string(eng_wtop(_p)), global.TH.text_faint, fa_left, fa_top, global.f_small, 1); _y += 18; }
    set_val(_u, "frame_on", ui_toggle("hud_frame_on", _fx, _y, "Panel frame", _u.frame_on, "Panel frame|Draws the 9-slice frame: 9 characters for the corners, the edges (repeated along the panel) and the fill. Off: the screen shows behind the text."), "hudframeon");
    _y += 32;
    ui_heading(_fx, _y, "Frame style");
    var _styles = hud_frame_styles();
    var _si = -1;
    for (var s = 0; s < array_length(_styles); s++)
    {
        if (_styles[s] == _u.style) { _si = s; }
    }
    var _snames = [];
    for (var s2 = 0; s2 < array_length(_styles); s2++) { array_push(_snames, _styles[s2]); }
    var _shown = _si;
    if (_si < 0)
    {
        array_push(_snames, "Custom (drawn)");
        _shown = array_length(_snames) - 1;
    }
    var _ns = ui_dropdown("hud_style", _fx, _y + 18, _fw, 30, _snames, _shown, "Frame style|A ready-made frame. Then draw on it under the preview to make it your own.");
    if (_ns != _shown && _ns < array_length(_styles))
    {
        undo_mark("hudstyle" + string(current_time));
        hud_apply_preset(_u, _styles[_ns]);
    }
    _y += 58;
    ui_heading(_fx, _y, "Font");
    var _nfs = ui_dropdown("hud_font", _fx, _y + 18, _fw, 30, hud_font_styles(), _u.font_style, "Font|The letters and digits of the HUD - and of the whole game, as the C64 has one set of letters on the screen. Custom: draw your own under the preview.");
    if (_nfs != _u.font_style)
    {
        undo_mark("hudfont" + string(current_time));
        if (_nfs == 5 && array_length(_u.font) != 512) { _u.font = hud_font_bytes(_p, _u); }
        _u.font_style = _nfs;
        if (_nfs == 5) { hud_edit_tab = 1; }
    }
    _y += 58;
    ui_heading(_fx, _y, "Fields (" + string(_nf) + ")");
    _y += 18;
    var _types = hud_field_types();
    var _listh = max(60, _y2 - 64 - _y);
    var _rowh = 30;
    var _content = _nf * _rowh + 4;
    var _off = ui_scroll_begin("hud_fields", _fx - 4, _y, _fx + _fw + 4, _y + _listh, _content);
    for (var f = 0; f < _nf; f++)
    {
        var _fy = _y + f * _rowh - _off;
        if (_fy < _y - _rowh || _fy > _y + _listh) { continue; }
        var _fd = _u.fields[f];
        var _hot = ui_register("hud_field_" + string(f), _fx, _fy, _fx + _fw, _fy + _rowh - 4, "Field|Click to change it on the right, or drag it on the preview.");
        if (hud_sel == f) { ui_rrect(_fx, _fy, _fx + _fw, _fy + _rowh - 4, 6, global.TH.accent, global.TH.accent_dark, 0.9); }
        else if (_hot) { ui_rrect(_fx, _fy, _fx + _fw, _fy + _rowh - 4, 6, global.TH.btn_hot_top, global.TH.btn_hot_bot, 0.6); }
        ui_rrect(_fx + 6, _fy + 6, _fx + 20, _fy + _rowh - 10, 3, c64col(_fd.colour), c64col(_fd.colour), 1);
        var _ft = _types[_fd.type];
        if (_fd.label != "") { _ft += ": " + _fd.label; }
        ui_text(_fx + 28, _fy + (_rowh - 4) / 2, ui_text_fit(_ft, global.f_small, _fw - 36), global.TH.text, fa_left, fa_middle, global.f_small, 1);
        if (_hot && ui_pressed)
        {
            ui_take_click();
            hud_sel = f;
        }
    }
    ui_scroll_end("hud_fields", _fx - 4, _y, _fx + _fw + 4, _y + _listh, _content);
    var _addn = ["+ Field"];
    for (var t = 0; t < hud_type_count(_p); t++) { array_push(_addn, _types[t]); }
    var _bw = floor((_fw - 8) / 2);
    var _add = ui_dropdown("hud_add", _fx, _y2 - 48, _bw, 32, _addn, 0, "Add a field|Text, the score, lives - and in a map game the level goal, the level number, the tile carried and the tool in use (Dig and place).");
    if (_add > 0 && _nf < HUD_FIELDS_MAX && _u.on)
    {
        undo_mark("hudadd" + string(current_time));
        var _nfd = hud_field_new(_add - 1);
        _nfd.colour = 1;
        _nfd.row = hud_text_row(_p);
        switch (_add - 1)
        {
            case 0: _nfd.label = "TEXT"; break;
            case 1: _nfd.label = "SCORE "; _nfd.digits = (_p.game_type == 1) ? 6 : 4; break;
            case 2: _nfd.label = "LIVES "; _nfd.digits = 1; break;
            case 3: _nfd.label = "GEMS "; break;
            case 4: _nfd.label = "LEVEL "; _nfd.digits = 1; break;
            case 5: _nfd.label = ""; break;
            case 6: _nfd.label = ""; break;
        }
        array_push(_u.fields, _nfd);
        hud_sel = array_length(_u.fields) - 1;
    }
    var _dst = (_nf == 0) ? BTN_GHOST : BTN_DANGER;
    if (ui_button("hud_del", _fx + _bw + 8, _y2 - 48, _fw - _bw - 8, 32, "Remove", "Remove field|Takes the picked field off the HUD. You can Undo this.", _dst) && _nf > 0)
    {
        undo_mark("huddel" + string(current_time));
        array_delete(_u.fields, hud_sel, 1);
        hud_sel = max(0, hud_sel - 1);
    }
    _nf = array_length(_u.fields);
    hud_sel = clamp(hud_sel, 0, max(0, _nf - 1));

    // ---------------- centre: the preview, then the frame / font editor ----------------
    ui_panel(_cx1, _y1, _cx2, _y2, "Preview");
    var _pw = _cx2 - _cx1 - 32;
    var _ph = floor((_y2 - _y1) * 0.56);
    var _sc = max(1, floor(min(_pw / 320, (_ph - 10) / 200) * 2) / 2);
    var _vx = floor((_cx1 + _cx2 - 320 * _sc) / 2);
    var _vy = _y1 + 50;
    var _bc = (_p.game_type == 1) ? _p.eng.border : _p.border;
    ui_rrect(_vx - 10, _vy - 10, _vx + 320 * _sc + 10, _vy + 200 * _sc + 10, 8, c64col(_bc), c64col(_bc), 1);
    hud_preview_draw(_vx, _vy, _sc);
    ui_register("hud_preview", _vx, _vy, _vx + 320 * _sc, _vy + 200 * _sc, "Preview|The game screen with your HUD, using sample numbers. Drag a field to move it (it snaps to the 8 x 8 character grid).");
    var _rows = hud_rows(_p, _u);
    var _r0 = hud_row0(_p, _u);
    var _cs = 8 * _sc;
    if (_u.on)
    {
        // the panel's outline, and the fields: click to pick, drag to move
        draw_set_alpha(0.6);
        draw_rectangle_colour(_vx - 1, _vy + _r0 * _cs - 1, _vx + 320 * _sc, _vy + (_r0 + _rows) * _cs, global.TH.accent2, global.TH.accent2, global.TH.accent2, global.TH.accent2, true);
        draw_set_alpha(1);
        var _hov = -1;
        for (var f2 = 0; f2 < _nf; f2++)
        {
            var _fd2 = _u.fields[f2];
            if (_fd2.row >= _rows) { continue; }
            var _len = max(1, min(40 - _fd2.col, string_length(hud_field_text(_p, _fd2, true))));
            var _rx1 = _vx + _fd2.col * _cs;
            var _ry1 = _vy + (_r0 + _fd2.row) * _cs;
            var _rx2 = _rx1 + _len * _cs;
            var _ry2 = _ry1 + _cs;
            if (point_in_rectangle(ui_mx, ui_my, _rx1, _ry1, _rx2, _ry2) && hud_drag < 0 && ui_can_input()) { _hov = f2; }
            if (f2 == hud_sel) { draw_rectangle_colour(_rx1 - 2, _ry1 - 2, _rx2 + 1, _ry2 + 1, global.TH.accent, global.TH.accent, global.TH.accent, global.TH.accent, true); }
            else if (f2 == _hov) { draw_rectangle_colour(_rx1 - 2, _ry1 - 2, _rx2 + 1, _ry2 + 1, c_white, c_white, c_white, c_white, true); }
        }
        if (_hov >= 0 && ui_pressed)
        {
            ui_take_click();
            hud_sel = _hov;
            hud_drag = _hov;
            hud_drag_dx = ui_mx - (_vx + _u.fields[_hov].col * _cs);
            hud_drag_dy = ui_my - (_vy + (_r0 + _u.fields[_hov].row) * _cs);
            undo_mark("huddrag" + string(current_time));
        }
        if (hud_drag >= 0)
        {
            if (!ui_held || hud_drag >= _nf) { hud_drag = -1; }
            else
            {
                var _df = _u.fields[hud_drag];
                var _nc = clamp(round((ui_mx - hud_drag_dx - _vx) / _cs), 0, 39);
                var _nr = clamp(round((ui_my - hud_drag_dy - _vy) / _cs) - _r0, 0, _rows - 1);
                if (_nc != _df.col || _nr != _df.row)
                {
                    _df.col = _nc;
                    _df.row = _nr;
                    proj_dirty = true;
                }
            }
        }
    }

    // the editors: the frame (24 x 24, 9 characters) or the font
    var _ey = _vy + 200 * _sc + 22;
    if (_u.on)
    {
        var _etabs = ["Panel frame", "Font"];
        var _ehelp = ["Panel frame|Draw the frame: the 3 x 3 characters are the corners, the edges (repeated along the panel) and the fill (repeated inside). Each character has one colour, as on the C64.", "Font|Draw the letters: pick a character, then draw it. The first change makes the font Custom."];
        for (var et = 0; et < 2; et++)
        {
            if (ui_tab("hud_etab_" + string(et), _cx1 + 16 + et * 130, _ey, 124, 30, _etabs[et], hud_edit_tab == et, _ehelp[et])) { hud_edit_tab = et; }
        }
        var _cost = hud_bytes(_p);
        ui_text(_cx2 - 16, _ey + 15, "About " + string(_cost) + " bytes in the game", global.TH.text_faint, fa_right, fa_middle, global.f_small, 1);
        _ey += 40;
        if (hud_edit_tab == 0) { hud_frame_editor(_cx1 + 16, _ey, _cx2 - 16, _y2 - 14); }
        else { hud_font_editor(_cx1 + 16, _ey, _cx2 - 16, _y2 - 14); }
    }
    else
    {
        ui_text_wrap(_cx1 + 16, _ey, "The standard HUD is in use: one line with the score and lives. Switch on 'Use a custom HUD' to design a panel with a frame, a font and fields of your own.", global.TH.text_dim, _cx2 - _cx1 - 32, global.f_body, 1);
    }

    // ---------------- right: the picked field ----------------
    var _rx = _x2 - _rw;
    ui_panel(_rx, _y1, _x2, _y2, "Field");
    var _gx = _rx + 20;
    var _gw = _rw - 40;
    var _gy = _y1 + 56;
    if (!_u.on || _nf == 0)
    {
        var _msg = (!_u.on) ? "Switch on 'Use a custom HUD' on the left to design your own." : "Add a field on the left.";
        ui_text_wrap(_gx, _gy, _msg, global.TH.text_dim, _gw, global.f_body, 1);
        return;
    }
    var _sf = _u.fields[hud_sel];
    var _tn = [];
    for (var t2 = 0; t2 < hud_type_count(_p); t2++) { array_push(_tn, _types[t2]); }
    var _ti = _sf.type;
    if (_ti >= array_length(_tn)) { array_push(_tn, _types[_ti] + " (map games)"); _ti = array_length(_tn) - 1; }
    ui_heading(_gx, _gy, "Shows");
    var _nt = ui_dropdown("hud_ftype", _gx, _gy + 18, _gw, 30, _tn, _ti, "Shows|Text: just the label. Score, Lives, Level: the label then the number. Goal: the label and 'got / needed' for the level's goal (map games).");
    if (_nt != _ti && _nt < hud_type_count(_p)) { set_val(_sf, "type", _nt, "hudftype"); }
    _gy += 58;
    ui_heading(_gx, _gy, "Label (up to " + string(HUD_LABEL_MAX) + " letters)");
    // each field has its own label box: picking another field drops the typing in the old one
    var _lid = "hud_flabel" + string(hud_sel);
    if (string_pos("hud_flabel", ui_focus) == 1 && ui_focus != _lid) { ui_focus = ""; }
    var _nl = ui_textfield(_lid, _gx, _gy + 18, _gw, 32, _sf.label, HUD_LABEL_MAX, "Label|Drawn before the number, e.g. 'SCORE ' (end it with a space). For Text it is the whole text.");
    set_val(_sf, "label", string_upper(_nl), "hudflabel" + string(hud_sel));
    _gy += 62;
    var _gh = floor((_gw - 10) / 2);
    ui_heading(_gx, _gy, "Column (0-39)");
    ui_heading(_gx + _gh + 10, _gy, "Row (0-" + string(_rows - 1) + ")");
    set_val(_sf, "col", ui_stepper("hud_fcol", _gx, _gy + 18, _gh, _sf.col, 0, 39, "Column|Where the field starts across the screen, in characters (or drag it on the preview)."), "hudfcol");
    set_val(_sf, "row", ui_stepper("hud_frow", _gx + _gh + 10, _gy + 18, _gh, min(_sf.row, _rows - 1), 0, _rows - 1, "Row|Which text row of the panel."), "hudfrow");
    _gy += 58;
    ui_heading(_gx, _gy, "Colour");
    set_val(_sf, "colour", ui_colour_drop("hud_fcolour", _gx, _gy + 18, _gw, 30, _sf.colour, "Colour|The letters' colour. Each character square on the C64 has one colour, on the screen's background colour."), "hudfcolour");
    _gy += 58;
    if (_sf.type == 1 || _sf.type == 2 || _sf.type == 4)
    {
        var _dmax = (_sf.type == 4) ? 2 : 6;
        ui_heading(_gx, _gy, "Digits");
        set_val(_sf, "digits", ui_stepper("hud_fdig", _gx, _gy + 18, _gh, clamp(_sf.digits, 1, _dmax), 1, _dmax, "Digits|How many digits the number has, with zeros in front. A single-screen game's score goes up to 9999, a map game's to 999999."), "hudfdig");
        _gy += 58;
    }
    ui_text_wrap(_gx, _gy + 8, "Shows: " + hud_field_text(_p, _sf, true), global.TH.text_faint, _gw, global.f_small, 1);
    var _wl = hud_warnings(_p);
    if (array_length(_wl) > 0) { ui_text_wrap(_gx, _gy + 40, _wl[0], global.TH.warn, _gw, global.f_small, 1); }
}

/// The 24 x 24 frame, magnified, with the 9 characters marked, and the colours to draw with
function hud_frame_editor(_x1, _y1, _x2, _y2)
{
    var _u = proj.hud;
    var _ps = max(3, floor(min((_x2 - _x1) * 0.5, _y2 - _y1 - 6) / 24));
    var _gx = _x1;
    var _gy = _y1;
    var _gw = _ps * 24;
    var _bgc = (proj.game_type == 1) ? proj.eng.bg : proj.background;
    ui_rrect(_gx - 4, _gy - 4, _gx + _gw + 4, _gy + _gw + 4, 6, c64col(_bgc), c64col(_bgc), 1);
    for (var _py = 0; _py < 24; _py++)
    {
        for (var _px = 0; _px < 24; _px++)
        {
            if (_u.frame[_py * 24 + _px] == 0) { continue; }
            var _c = c64col(_u.fcols[(_py div 8) * 3 + (_px div 8)]);
            draw_rectangle_colour(_gx + _px * _ps, _gy + _py * _ps, _gx + (_px + 1) * _ps - 1, _gy + (_py + 1) * _ps - 1, _c, _c, _c, _c, false);
        }
    }
    draw_set_alpha(0.5);
    for (var l = 1; l < 3; l++)
    {
        draw_line_colour(_gx + l * 8 * _ps, _gy, _gx + l * 8 * _ps, _gy + _gw, c_white, c_white);
        draw_line_colour(_gx, _gy + l * 8 * _ps, _gx + _gw, _gy + l * 8 * _ps, c_white, c_white);
    }
    draw_set_alpha(1);
    var _hot = ui_register("hud_frame_canvas", _gx, _gy, _gx + _gw - 1, _gy + _gw - 1, "Frame|Left-click draws with the colour picked - the whole character takes that colour, as on the C64. Right-click rubs out. Corners stay put; the edges repeat along the panel and the fill repeats inside.");
    if (_hot)
    {
        var _hx = clamp(floor((ui_mx - _gx) / _ps), 0, 23);
        var _hy = clamp(floor((ui_my - _gy) / _ps), 0, 23);
        draw_rectangle_colour(_gx + _hx * _ps, _gy + _hy * _ps, _gx + (_hx + 1) * _ps - 1, _gy + (_hy + 1) * _ps - 1, c_white, c_white, c_white, c_white, true);
        if (ui_pressed || ui_rpressed)
        {
            ui_take_click();
            undo_mark("hudframe" + string(current_time));
            hud_drawing = true;
        }
        if (hud_drawing)
        {
            var _k = _hy * 24 + _hx;
            var _sl = (_hy div 8) * 3 + (_hx div 8);
            if (ui_held && (_u.frame[_k] != 1 || _u.fcols[_sl] != hud_pen))
            {
                _u.frame[_k] = 1;
                _u.fcols[_sl] = hud_pen;
                _u.style = "Custom";
                proj_dirty = true;
            }
            if (ui_rheld && _u.frame[_k] != 0)
            {
                _u.frame[_k] = 0;
                _u.style = "Custom";
                proj_dirty = true;
            }
        }
    }
    if (!ui_held && !ui_rheld) { hud_drawing = false; }
    var _px2 = _gx + _gw + 24;
    var _cw = max(14, min(24, floor((_x2 - _px2 - 28) / 8)));
    ui_heading(_px2, _y1, "Colour: " + global.C64PAL_NAMES[hud_pen]);
    hud_pen = ui_colour_grid("hud_pal", _px2, _y1 + 20, _cw, hud_pen, "Colour|The colour to draw with.");
    var _ty = _y1 + 20 + 2 * (_cw + 4) + 12;
    if (ui_button("hud_fclear", _px2, _ty, 120, 30, "Clear", "Clear|Rubs the whole frame out, to draw one from nothing.", BTN_GHOST))
    {
        undo_mark("hudfclear" + string(current_time));
        _u.frame = array_create(576, 0);
        _u.style = "Custom";
    }
    ui_text_wrap(_px2, _ty + 42, "Letters sit on the screen's background colour, so an empty fill reads best.", global.TH.text_faint, max(60, _x2 - _px2), global.f_small, 1);
}

/// The font: a grid of the 64 characters, and the picked one magnified to draw on
function hud_font_editor(_x1, _y1, _x2, _y2)
{
    var _u = proj.hud;
    var _font = hud_font_bytes(proj, _u);
    var _cs = max(14, min(26, floor((_x2 - _x1) * 0.55 / 16), floor((_y2 - _y1) / 4) - 2));
    for (var c = 0; c < 64; c++)
    {
        var _cx = _x1 + (c mod 16) * (_cs + 2);
        var _cy = _y1 + (c div 16) * (_cs + 2);
        var _hot = ui_register("hud_char_" + string(c), _cx, _cy, _cx + _cs, _cy + _cs, "Character|Click to draw it on the right.");
        var _bg = make_colour_rgb(22, 24, 30);
        if (c == hud_font_char) { _bg = global.TH.accent_dark; }
        else if (_hot) { _bg = make_colour_rgb(44, 48, 58); }
        draw_rectangle_colour(_cx, _cy, _cx + _cs - 1, _cy + _cs - 1, _bg, _bg, _bg, _bg, false);
        var _pp = (_cs - 4) / 8;
        var _ox = _cx + 2;
        var _oy = _cy + 2;
        for (var i = 0; i < 8; i++)
        {
            var _row = _font[c * 8 + i];
            if (_row == 0) { continue; }
            for (var b = 0; b < 8; b++)
            {
                if ((_row & (0x80 >> b)) != 0) { px_rect(_ox + b * _pp, _oy + i * _pp, _pp, _pp, c_white); }
            }
        }
        if (_hot && ui_pressed)
        {
            ui_take_click();
            hud_font_char = c;
        }
    }
    var _ex = _x1 + 16 * (_cs + 2) + 24;
    var _ps = max(6, floor(min(_x2 - _ex, _y2 - _y1 - 40) / 8));
    ui_rrect(_ex - 4, _y1 - 4, _ex + 8 * _ps + 4, _y1 + 8 * _ps + 4, 6, make_colour_rgb(22, 24, 30), make_colour_rgb(22, 24, 30), 1);
    for (var i2 = 0; i2 < 8; i2++)
    {
        for (var b2 = 0; b2 < 8; b2++)
        {
            var _set = ((_font[hud_font_char * 8 + i2] & (0x80 >> b2)) != 0);
            var _col = _set ? c_white : make_colour_rgb(40, 44, 54);
            draw_rectangle_colour(_ex + b2 * _ps + 1, _y1 + i2 * _ps + 1, _ex + (b2 + 1) * _ps - 1, _y1 + (i2 + 1) * _ps - 1, _col, _col, _col, _col, false);
        }
    }
    var _cn = "@ABCDEFGHIJKLMNOPQRSTUVWXYZ[£]^< !\"#$%&'()*+,-./0123456789:;<=>?";
    ui_text_wrap(_ex, _y1 + 8 * _ps + 10, "'" + string_char_at(_cn, hud_font_char + 1) + "' - left-click draws, right-click rubs out", global.TH.text_dim, max(60, _x2 - _ex), global.f_small, 1);
    var _hot2 = ui_register("hud_font_canvas", _ex, _y1, _ex + 8 * _ps - 1, _y1 + 8 * _ps - 1, "Character|Left-click sets a pixel, right-click clears it. The first change makes the font Custom (starting from the style you had).");
    if (_hot2)
    {
        var _hb = clamp(floor((ui_mx - _ex) / _ps), 0, 7);
        var _hr = clamp(floor((ui_my - _y1) / _ps), 0, 7);
        if (ui_pressed || ui_rpressed)
        {
            ui_take_click();
            undo_mark("hudfontdraw" + string(current_time));
            if (_u.font_style != 5)
            {
                _u.font = hud_font_bytes(proj, _u);
                _u.font_style = 5;
            }
            hud_drawing = true;
        }
        if (hud_drawing && _u.font_style == 5)
        {
            var _k = hud_font_char * 8 + _hr;
            var _m = 0x80 >> _hb;
            var _old = _u.font[_k];
            if (ui_held) { _u.font[_k] = _old | _m; }
            if (ui_rheld) { _u.font[_k] = _old & ~_m & 255; }
            if (_u.font[_k] != _old) { proj_dirty = true; }
        }
    }
    if (!ui_held && !ui_rheld) { hud_drawing = false; }
}
