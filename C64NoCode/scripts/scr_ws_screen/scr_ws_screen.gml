/// C64 ENGINE - Screen workspace (character painter)

function ws_screen_draw(_x1, _y1, _x2, _y2)
{
    var _lw = 220;
    var _rw = 310;
    var _cx1 = _x1 + _lw + 12;
    var _cx2 = _x2 - _rw - 12;

    // ---------------- tools ----------------
    ui_panel(_x1, _y1, _x1 + _lw, _y2, "Tools");
    var _tx = _x1 + 16;
    var _tw = _lw - 32;
    var _ty = _y1 + 58;
    var _tools = ["Brush", "Type text", "Recolour", "Box fill"];
    var _thelp = [
        "Brush|Left-click and drag to paint the selected character in the selected colour. Right-click to rub out. Alt-click picks up a character from the screen.",
        "Type text|Click a square on the screen, then type on your keyboard. Letters, numbers and punctuation become C64 text. Arrow keys move, Enter goes to the next line.",
        "Recolour|Paints only the colour, keeping the characters. Great for colouring a title after typing it.",
        "Box fill|Drag a box on the screen and let go to fill it with the selected character and colour. Right-drag clears the box."
    ];
    for (var i = 0; i < 4; i++)
    {
        var _st = BTN_NORMAL;
        if (scr_tool == i) { _st = BTN_ACCENT; }
        if (ui_button("scr_tool_" + string(i), _tx, _ty, _tw, 34, _tools[i], _thelp[i], _st))
        {
            scr_tool = i;
            scr_cursor = -1;
            keyboard_string = "";
        }
        _ty += 42;
    }
    _ty += 8;
    ui_heading(_tx, _ty, "View");
    _ty += 20;
    scr_grid = ui_toggle("scr_grid", _tx, _ty, "Grid", scr_grid, "Grid|Shows faint lines between the 40 x 25 character squares.");
    _ty += 32;
    scr_show_actors = ui_toggle("scr_actors", _tx, _ty, "Show actors", scr_show_actors, "Show actors|Draws your actors on top of the screen so you can design around them. They are moved on the Actors page.");
    _ty += 44;
    ui_heading(_tx, _ty, "Whole screen");
    _ty += 20;
    if (ui_button("scr_fill", _tx, _ty, _tw, 32, "Fill with brush", "Fill screen|Fills all 1000 squares with the selected character and colour.", BTN_NORMAL))
    {
        undo_mark("fill" + string(current_time));
        for (var f = 0; f < 1000; f++)
        {
            proj.chars[f] = scr_char;
            proj.cols[f] = scr_colour;
        }
    }
    _ty += 40;
    if (ui_button("scr_clear", _tx, _ty, _tw, 32, "Clear screen", "Clear screen|Rubs out every character (the colours stay). You can Undo this.", BTN_DANGER))
    {
        undo_mark("clear" + string(current_time));
        for (var c = 0; c < 1000; c++) { proj.chars[c] = 32; }
    }
    _ty += 48;
    ui_text_wrap(_tx, _ty, "Tip: the top row shows the score and lives while playing. Leave it clear or change the row on the Home page.", global.TH.text_faint, _tw, global.f_small, 1);

    // ---------------- canvas ----------------
    ui_panel(_cx1, _y1, _cx2, _y2, "");
    var _aw = _cx2 - _cx1 - 32;
    var _ah = _y2 - _y1 - 32;
    var _scale = min(_aw / 384, _ah / 272);
    if (_scale >= 2) { _scale = floor(_scale); }
    else
    {
        if (_scale >= 1) { _scale = floor(_scale * 4) / 4; }
    }
    var _fw = 384 * _scale;
    var _fh = 272 * _scale;
    var _fx = floor((_cx1 + _cx2 - _fw) / 2);
    var _fy = floor((_y1 + _y2 - _fh) / 2);
    ui_rrect(_fx - 6, _fy - 6, _fx + _fw + 6, _fy + _fh + 6, 10, c_black, c_black, 0.35);
    var _o = draw_c64_screen(_fx, _fy, _scale, true);
    var _sx = _o[0];
    var _sy = _o[1];
    var _cs = 8 * _scale;
    var _sw = 320 * _scale;
    var _sh = 200 * _scale;

    if (scr_grid)
    {
        draw_set_alpha(0.12);
        for (var gx = 0; gx <= 40; gx++) { draw_line_colour(_sx + gx * _cs, _sy, _sx + gx * _cs, _sy + _sh, c_white, c_white); }
        for (var gy = 0; gy <= 25; gy++) { draw_line_colour(_sx, _sy + gy * _cs, _sx + _sw, _sy + gy * _cs, c_white, c_white); }
        draw_set_alpha(1);
    }
    if (scr_show_actors)
    {
        for (var a = 0; a < array_length(proj.actors); a++)
        {
            var _ac = proj.actors[a];
            var _ax = _fx + (_ac.x + 8) * _scale;
            var _ay = _fy + (_ac.y - 15) * _scale;
            draw_sprite_c64(_ac.sprite, _ax, _ay, _scale, _ac.colour, 0.75);
        }
    }

    var _hot = ui_register("scr_canvas", _sx, _sy, _sx + _sw - 1, _sy + _sh - 1, "Screen|This is the C64 screen: 40 characters across, 25 down. The coloured frame around it is the border.");
    var _col = clamp(floor((ui_mx - _sx) / _cs), 0, 39);
    var _row = clamp(floor((ui_my - _sy) / _cs), 0, 24);
    var _cell = _row * 40 + _col;

    if (_hot)
    {
        // helper guides for the hovered square
        draw_set_alpha(0.35);
        draw_set_colour(global.TH.accent);
        draw_rectangle(_sx + _col * _cs, _sy, _sx + _col * _cs + _cs - 1, _sy + _sh - 1, true);
        draw_rectangle(_sx, _sy + _row * _cs, _sx + _sw - 1, _sy + _row * _cs + _cs - 1, true);
        draw_set_alpha(1);
        draw_rectangle_colour(_sx + _col * _cs - 1, _sy + _row * _cs - 1, _sx + _col * _cs + _cs, _sy + _row * _cs + _cs, c_white, c_white, c_white, c_white, true);
        var _badge = "Row " + string(_row) + "  Col " + string(_col) + "  Char " + string(proj.chars[_cell]);
        draw_set_font(global.f_small);
        var _bw = ui_sw(_badge) + 20;
        ui_rrect(_fx, _fy + _fh + 10, _fx + _bw, _fy + _fh + 34, 10, global.TH.btn_top, global.TH.btn_bot, 0.95);
        ui_text(_fx + 10, _fy + _fh + 22, _badge, global.TH.text, fa_left, fa_middle, global.f_small, 1);
    }

    var _alt = keyboard_check(vk_alt);
    if (_hot && ui_pressed && _alt)
    {
        scr_char = proj.chars[_cell];
        scr_colour = proj.cols[_cell];
        ui_take_click();
    }
    if (scr_tool == 0 || scr_tool == 2)
    {
        if (_hot && (ui_pressed || ui_rpressed))
        {
            undo_mark("paint" + string(current_time));
            scr_painting = true;
            ui_take_click();
        }
        if (scr_painting && _hot)
        {
            if (ui_held)
            {
                if (scr_tool == 0) { proj.chars[_cell] = scr_char; }
                proj.cols[_cell] = scr_colour;
                proj_dirty = true;
            }
            if (ui_rheld && scr_tool == 0)
            {
                proj.chars[_cell] = 32;
                proj_dirty = true;
            }
        }
        if (!ui_held && !ui_rheld) { scr_painting = false; }
    }
    if (scr_tool == 3)
    {
        if (_hot && (ui_pressed || ui_rpressed))
        {
            scr_box_start = _cell;
            scr_box_clear = ui_rpressed;
            scr_painting = true;
            ui_take_click();
        }
        if (scr_painting)
        {
            var _r1 = min(scr_box_start div 40, _row);
            var _r2 = max(scr_box_start div 40, _row);
            var _c1 = min(scr_box_start mod 40, _col);
            var _c2 = max(scr_box_start mod 40, _col);
            ui_rrect_line(_sx + _c1 * _cs - 2, _sy + _r1 * _cs - 2, _sx + (_c2 + 1) * _cs + 2, _sy + (_r2 + 1) * _cs + 2, 4, global.TH.accent2, 1, 2);
            ui_text(_sx + (_c2 + 1) * _cs + 6, _sy + (_r2 + 1) * _cs, string(_c2 - _c1 + 1) + " x " + string(_r2 - _r1 + 1), global.TH.accent2, fa_left, fa_top, global.f_small, 1);
            if (!ui_held && !ui_rheld)
            {
                undo_mark("box" + string(current_time));
                for (var br = _r1; br <= _r2; br++)
                {
                    for (var bc = _c1; bc <= _c2; bc++)
                    {
                        if (scr_box_clear) { proj.chars[br * 40 + bc] = 32; }
                        else
                        {
                            proj.chars[br * 40 + bc] = scr_char;
                            proj.cols[br * 40 + bc] = scr_colour;
                        }
                    }
                }
                scr_painting = false;
            }
        }
    }
    if (scr_tool == 1)
    {
        if (_hot && ui_pressed)
        {
            scr_cursor = _cell;
            scr_cursor_home = _col;
            keyboard_string = "";
            ui_focus = "";
            ui_take_click();
        }
        if (scr_cursor >= 0 && ui_focus == "")
        {
            var _typed = keyboard_string;
            keyboard_string = "";
            if (_typed != "") { undo_mark("type"); }
            for (var k = 1; k <= string_length(_typed); k++)
            {
                proj.chars[scr_cursor] = scr_code_from_char(string_char_at(_typed, k));
                proj.cols[scr_cursor] = scr_colour;
                scr_cursor = min(999, scr_cursor + 1);
            }
            if (keyboard_check_pressed(vk_backspace))
            {
                undo_mark("type");
                scr_cursor = max(0, scr_cursor - 1);
                proj.chars[scr_cursor] = 32;
            }
            if (keyboard_check_pressed(vk_left)) { scr_cursor = max(0, scr_cursor - 1); }
            if (keyboard_check_pressed(vk_right)) { scr_cursor = min(999, scr_cursor + 1); }
            if (keyboard_check_pressed(vk_up)) { scr_cursor = max(scr_cursor mod 40, scr_cursor - 40); }
            if (keyboard_check_pressed(vk_down))
            {
                if (scr_cursor + 40 <= 999) { scr_cursor += 40; }
            }
            if (keyboard_check_pressed(vk_enter))
            {
                var _nr = min(24, (scr_cursor div 40) + 1);
                scr_cursor = _nr * 40 + scr_cursor_home;
            }
            if (keyboard_check_pressed(vk_escape)) { scr_cursor = -1; }
            if (scr_cursor >= 0 && (current_time div 400) mod 2 == 0)
            {
                var _ccx = _sx + (scr_cursor mod 40) * _cs;
                var _ccy = _sy + (scr_cursor div 40) * _cs;
                draw_set_alpha(0.7);
                draw_rectangle_colour(_ccx, _ccy, _ccx + _cs - 1, _ccy + _cs - 1, c64col(scr_colour), c64col(scr_colour), c64col(scr_colour), c64col(scr_colour), false);
                draw_set_alpha(1);
            }
        }
    }

    // ---------------- palette ----------------
    var _px = _x2 - _rw;
    ui_panel(_px, _y1, _x2, _y2, "Characters");
    var _gx = _px + floor((_rw - 256) / 2);
    var _gy = _y1 + 56;
    ui_inset(_gx - 6, _gy - 6, _gx + 262, _gy + 262, 8);
    gpu_set_texfilter(false);
    for (var ch = 0; ch < 256; ch++)
    {
        var _chx = _gx + (ch mod 16) * 16;
        var _chy = _gy + (ch div 16) * 16;
        draw_c64_char(ch, _chx, _chy, 2, c64col(scr_colour));
    }
    gpu_set_texfilter(true);
    var _phot = ui_register("scr_charpal", _gx, _gy, _gx + 255, _gy + 255, "Character set|All 256 C64 characters: letters, numbers and the famous PETSCII graphics blocks. Click one to paint with it. The bottom half is the reversed versions.");
    var _selx = _gx + (scr_char mod 16) * 16;
    var _sely = _gy + (scr_char div 16) * 16;
    ui_rrect_line(_selx - 2, _sely - 2, _selx + 18, _sely + 18, 4, c_white, 1, 2);
    if (_phot)
    {
        var _hc = clamp(floor((ui_mx - _gx) / 16), 0, 15) + clamp(floor((ui_my - _gy) / 16), 0, 15) * 16;
        var _hx = _gx + (_hc mod 16) * 16;
        var _hy = _gy + (_hc div 16) * 16;
        ui_rrect_line(_hx - 2, _hy - 2, _hx + 18, _hy + 18, 4, global.TH.accent, 1, 1);
        ui_help_body = "Character " + string(_hc) + ". Click to paint with it.";
        if (ui_pressed)
        {
            scr_char = _hc;
            if (scr_tool == 1 || scr_tool == 2) { scr_tool = 0; }
            ui_take_click();
        }
    }
    var _yy = _gy + 276;
    ui_heading(_px + 20, _yy, "Brush colour");
    scr_colour = ui_colour_grid("scr_colour", _px + 20, _yy + 20, 30, scr_colour, "Brush colour|The colour used when painting or typing");
    _yy += 96;
    var _half = floor((_rw - 52) / 2);
    ui_heading(_px + 20, _yy, "Border");
    set_val(proj, "border", ui_colour_drop("scr_border", _px + 20, _yy + 18, _half, 32, proj.border, "Border colour|The colour of the frame around the screen."), "border");
    ui_heading(_px + 32 + _half, _yy, "Background");
    set_val(proj, "background", ui_colour_drop("scr_bg", _px + 32 + _half, _yy + 18, _half, 32, proj.background, "Background colour|The colour behind all the characters."), "background");
    _yy += 64;
    ui_heading(_px + 20, _yy, "Current brush");
    ui_inset(_px + 20, _yy + 20, _px + 76, _yy + 76, 8);
    draw_set_colour(c64col(proj.background));
    draw_rectangle(_px + 24, _yy + 24, _px + 72, _yy + 72, false);
    gpu_set_texfilter(false);
    draw_c64_char(scr_char, _px + 24, _yy + 24, 6, c64col(scr_colour));
    gpu_set_texfilter(true);
    ui_text(_px + 90, _yy + 32, "Character " + string(scr_char), global.TH.text, fa_left, fa_top, global.f_bold, 1);
    ui_text(_px + 90, _yy + 52, global.C64PAL_NAMES[scr_colour], global.TH.text_dim, fa_left, fa_top, global.f_small, 1);
}
