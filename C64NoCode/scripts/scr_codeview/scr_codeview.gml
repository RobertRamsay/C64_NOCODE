/// C64 NO-CODE STUDIO - live build: the game is generated and assembled again a moment after
/// each change (never mid-stroke). It feeds the code previewer on the Logic page and the
/// memory bar in the status bar.

#macro LIVE_DELAY_MS 400
#macro C64_BASIC_START 2049        // $0801
#macro C64_BASIC_END 40960         // $A000: the BASIC ROM starts here (38911 BASIC bytes free)
#macro C64_VIC_BANK_END 16384      // $4000: sprites must sit in VIC bank 0 below here
#macro CODEVIEW_LINE_H 17

/// Asks for a new live build once things settle
function live_mark_stale()
{
    live_stale = true;
    live_stale_time = current_time;
}

/// Called every step: builds again when the project changed and the mouse is up
function live_step()
{
    if (live_proj_ref != proj || live_machine != proj.machine || live_type != proj.game_type)
    {
        if (!live_stale) { live_mark_stale(); }
    }
    if (live_stale && !mouse_check_button(mb_left) && !mouse_check_button(mb_right) && current_time - live_stale_time > LIVE_DELAY_MS)
    {
        live_measure();
    }
}

/// Label value from an assembler result, or _def when it is missing
function live_label(_labels, _name, _def)
{
    var _v = _labels[$ _name];
    if (is_undefined(_v)) { return _def; }
    return _v;
}

/// Generates and assembles the game (nothing is saved) and measures it
function live_measure()
{
    live_stale = false;
    live_proj_ref = proj;
    live_machine = proj.machine;
    live_type = proj.game_type;
    live_ok = false;
    live_err = "";
    try
    {
        var _gen;
        if (proj.game_type == 1) { _gen = engine_codegen(proj); }
        else { _gen = codegen_project(proj); }
        live_lines = _gen.lines;
        live_marks = [];
        if (proj.game_type == 0) { live_marks = _gen.marks; }
        var _res = asm6502_assemble(_gen.src);
        if (!_res.ok)
        {
            live_err = _res.err;
            return;
        }
        var _lab = _res.labels;
        var _org = _res.org;
        live_end = _org + array_length(_res.bytes);
        live_size = array_length(_res.bytes) + 2;
        var _ss = live_label(_lab, "sid_start", _org);
        var _se = live_label(_lab, "sid_end", _ss);
        live_seg_sound = _se - _ss;
        if (proj.game_type == 1)
        {
            // engine and code, then the level data (tiles, enemies, maps - the sound tables are in it), then sprites + charset
            var _ld = live_label(_lab, "level_data", _org);
            var _ds = live_label(_lab, "spr_src", live_end);
            live_seg_code = _ld - _org;
            live_seg_gap = 0;
            live_seg_sprites = live_end - _ds;
            live_seg_data = max(0, _ds - _ld - live_seg_sound);
            live_limit = 32768;
            live_spr_end = 0;
        }
        else
        {
            var _ve = live_label(_lab, "vars_end", _se);
            var _sp = live_label(_lab, "spr_data", _ve);
            live_seg_code = _ve - _org - live_seg_sound;
            live_seg_gap = _sp - _ve;
            live_seg_sprites = SPR_COUNT * 64;
            live_seg_data = live_end - _sp - live_seg_sprites;
            live_limit = C64_BASIC_END;
            live_spr_end = _sp + live_seg_sprites;
        }
        // bytes of 6502 each rule became (its check in the frame loop + its actions)
        live_rule_bytes = array_create(array_length(proj.rules), 0);
        for (var r = 0; r < array_length(proj.rules); r++)
        {
            var _rs = string(r);
            var _c0 = live_label(_lab, "rchk_" + _rs, 0);
            var _c1 = live_label(_lab, "rchk_" + _rs + "_e", _c0);
            var _a0 = live_label(_lab, "ract_" + _rs, 0);
            var _a1 = live_label(_lab, "ract_" + _rs + "_e", _a0);
            live_rule_bytes[r] = (_c1 - _c0) + (_a1 - _a0);
        }
        live_ok = true;
    }
    catch (_e)
    {
        live_err = "could not build - " + string(_e);
    }
}

/// The memory bar in the status bar: the C64's BASIC program area ($0801-$9FFF) or, for map
/// games, the engine's $0801-$7FFF, split into code, sound, the VIC gap, sprites and data
function mem_bar_draw(_x, _y, _w, _h)
{
    var _range = max(1, live_limit - C64_BASIC_START);
    var _used = live_end - C64_BASIC_START;
    var _frac = clamp(_used / _range, 0, 1);
    var _over = false;
    if (proj.game_type == 0 && live_spr_end > C64_VIC_BANK_END) { _over = true; }
    if (live_end > live_limit) { _over = true; }
    var _edge = global.TH.panel_edge;
    if (_frac > 0.75) { _edge = global.TH.warn; }
    if (_frac > 0.9 || _over || !live_ok) { _edge = global.TH.danger; }
    ui_rrect(_x, _y, _x + _w, _y + _h, 4, c_black, c_black, 0.35);
    var _iw = _w - 2;
    if (live_ok)
    {
        var _bx = _x + 1;
        var _parts = [live_seg_code, live_seg_sound, live_seg_gap, live_seg_sprites, live_seg_data];
        var _top = [global.TH.accent, global.TH.warn, global.TH.text_faint, make_colour_rgb(240, 150, 60), global.TH.accent2];
        for (var i = 0; i < 5; i++)
        {
            var _pw = min(_parts[i] / _range * _iw, _x + 1 + _iw - _bx);
            if (_pw >= 1)
            {
                var _a = 1;
                if (i == 2) { _a = 0.45; }
                ui_rrect(_bx, _y + 1, _bx + _pw, _y + _h - 1, 3, _top[i], merge_colour(_top[i], c_black, 0.3), _a);
                _bx += _pw;
            }
        }
    }
    if (proj.game_type == 0)
    {
        // red tick: sprites must end by $4000, so the code must end by $3800
        var _kx = _x + 1 + (C64_VIC_BANK_END - SPR_COUNT * 64 - C64_BASIC_START) / _range * _iw;
        draw_line_width_colour(_kx, _y - 2, _kx, _y + _h + 2, 2, global.TH.danger, global.TH.danger);
    }
    ui_rrect_line(_x, _y, _x + _w, _y + _h, 4, _edge, 0.9, 1);

    var _lab = "Memory  -";
    if (live_ok) { _lab = "Memory  " + string(ceil(_used / 1024)) + " / " + string(_range div 1024) + " KB  (" + string(floor(_frac * 100)) + "%)"; }
    if (!live_ok && live_err != "") { _lab = "Memory  (build error)"; }
    ui_text(_x - 10, _y + _h * 0.5, _lab, global.TH.text_dim, fa_right, fa_middle, global.f_small, 1);

    var _help = "Memory|How full your C64 program is, measured a moment after each change. Blue: code made from your rules. Yellow: the SID sound player and sound tables. Orange: the 32 sprites. Green: the screen and colour data.";
    if (proj.game_type == 1) { _help = "Memory|How full your C64 program is, measured a moment after each change. Blue: the scrolling engine. Yellow: the SID sound player and sound tables. Green: tiles, enemy types and the level maps. Orange: sprites and the charset."; }
    if (proj.game_type == 0)
    {
        _help += " The full bar is the 38911 bytes BASIC leaves free ($0801-$9FFF). Grey is a gap: the VIC-II chip sees the character ROM at $1000-$1FFF, so sprites start at $2000. The red tick is $3800 - code past it pushes the sprites beyond $4000, where the VIC-II cannot see them.";
    }
    else
    {
        _help += " The full bar is $0801-$7FFF: the engine keeps $8000 and up for the screen, charset and sprites at run time.";
    }
    if (_over) { _help += " Too big - it will not build."; }
    if (!live_ok && live_err != "") { _help += " Build error: " + live_err; }
    _help += " Amber from 75%, red from 90%.";
    ui_register("mem_bar", _x - 10 - 190, _y - 6, _x + _w, _y + _h + 6, _help);
}

/// Draws one generated line with simple colouring: labels, comments, mnemonics, operands
function codeview_line(_x, _y, _line, _w)
{
    var _c1 = string_char_at(_line, 1);
    if (_c1 == ";")
    {
        var _cc = global.TH.text_faint;
        if (string_copy(_line, 1, 7) == "; Rule ") { _cc = global.TH.accent2; }
        ui_text(_x, _y, ui_text_fit(_line, global.f_small, _w), _cc, fa_left, fa_top, global.f_small, 1);
        return;
    }
    if (_c1 != " ")
    {
        ui_text(_x, _y, ui_text_fit(_line, global.f_small, _w), global.TH.accent, fa_left, fa_top, global.f_small, 1);
        return;
    }
    var _t = string_trim(_line);
    var _sp = string_pos(" ", _t);
    var _mn = _t;
    var _op = "";
    if (_sp > 0)
    {
        _mn = string_copy(_t, 1, _sp - 1);
        _op = string_delete(_t, 1, _sp);
    }
    var _mc = global.TH.text;
    if (string_char_at(_mn, 1) == ".") { _mc = global.TH.text_faint; }
    ui_text(_x + 12, _y, _mn, _mc, fa_left, fa_top, global.f_small, 1);
    if (_op != "")
    {
        var _oc = global.TH.text_dim;
        if (string_char_at(_op, 1) == "#") { _oc = global.TH.warn; }
        if (string_char_at(_op, 1) == "$") { _oc = make_colour_rgb(150, 200, 255); }
        ui_text(_x + 46, _y, ui_text_fit(_op, global.f_small, _w - 46), _oc, fa_left, fa_top, global.f_small, 1);
    }
}

/// Is generated line _l part of rule _r (its check or its actions)?
function codeview_in_rule(_l, _r)
{
    for (var m = 0; m < array_length(live_marks); m++)
    {
        var _mk = live_marks[m];
        if (_mk.rule == _r && _l >= _mk.from && _l < _mk.to) { return true; }
    }
    return false;
}

/// The code previewer (Logic page, right panel)
function codeview_draw(_x1, _y1, _x2, _y2)
{
    var _fx = _x1 + 16;
    var _fw = _x2 - _x1 - 32;
    var _y = _y1 + 10;
    // status line
    var _st = "";
    var _sc = global.TH.text_dim;
    if (live_stale) { _st = "Updating..."; _sc = global.TH.text_faint; }
    else
    {
        if (live_ok) { _st = "Live: " + string(live_size) + " bytes, $0801-$" + string_upper(dec_to_hex(live_end - 1)); }
        else
        {
            _st = "Cannot build: " + live_err;
            _sc = global.TH.danger;
        }
    }
    ui_text(_fx, _y + 12, ui_text_fit(_st, global.f_small, _fw - 170), _sc, fa_left, fa_middle, global.f_small, 1);
    codeview_sel_only = ui_toggle("codeview_only", _x2 - 16 - 160, _y, "This rule only", codeview_sel_only, "This rule only|Shows just the code of the selected rule card (click a card to select it), instead of the whole program with that rule highlighted.");
    _y += 32;

    // the selected rule
    var _sel = logic_sel;
    if (_sel >= array_length(proj.rules)) { _sel = -1; }
    var _info = "Click a rule card to see the 6502 it becomes. This is real machine code for the C64 - the studio writes it for you, so you never need to touch it.";
    if (_sel >= 0)
    {
        var _rb = 0;
        if (live_ok && _sel < array_length(live_rule_bytes)) { _rb = live_rule_bytes[_sel]; }
        _info = "Rule " + string(_sel + 1) + ": " + logic_sentence(proj.rules[_sel]);
        if (rule_disabled(proj.rules[_sel])) { _info += "  Its group is switched off, so it is not in the game."; }
        else
        {
            if (live_ok) { _info += "  (" + string(_rb) + " bytes)"; }
        }
    }
    draw_set_font(global.f_small);
    var _ih = min(64, ceil(ui_sh_ext(_info, _fw)));
    ui_text_wrap(_fx, _y, _info, global.TH.text_dim, _fw, global.f_small, 1);
    _y += _ih + 10;

    // which lines to show
    var _show = [];
    var _n = array_length(live_lines);
    if (codeview_sel_only && _sel >= 0)
    {
        for (var m = 0; m < array_length(live_marks); m++)
        {
            var _mk = live_marks[m];
            if (_mk.rule != _sel) { continue; }
            for (var l0 = _mk.from; l0 < min(_n, _mk.to); l0++) { array_push(_show, l0); }
        }
    }
    else
    {
        for (var l1 = 0; l1 < _n; l1++) { array_push(_show, l1); }
    }
    var _lx1 = _x1 + 12;
    var _ly1 = _y;
    var _lx2 = _x2 - 12;
    var _ly2 = _y2 - 12;
    ui_inset(_lx1, _ly1, _lx2, _ly2, 10);
    ui_register("codeview_list", _lx1, _ly1, _lx2, _ly2, "Generated 6502|Every rule becomes a check in the frame loop (it runs 50 times a second) and a small subroutine for its DO lines. Blue words are labels, yellow # values are numbers loaded straight into the CPU, $ addresses are C64 chips and memory - $D0xx is the VIC-II, $D4xx the SID.");
    var _ns = array_length(_show);
    var _content = _ns * CODEVIEW_LINE_H + 20;
    // a newly selected rule scrolls into view
    if (codeview_follow && _sel >= 0 && !live_stale)
    {
        codeview_follow = false;
        if (!codeview_sel_only)
        {
            var _first = -1;
            for (var k = 0; k < _ns; k++)
            {
                if (codeview_in_rule(_show[k], _sel))
                {
                    _first = k;
                    break;
                }
            }
            if (_first >= 0) { ds_map_replace(ui_scroll, "codeview", max(0, _first * CODEVIEW_LINE_H - 40)); }
        }
        else { ds_map_replace(ui_scroll, "codeview", 0); }
    }
    var _off = ui_scroll_begin("codeview", _lx1, _ly1, _lx2, _ly2, _content);
    if (_ns == 0)
    {
        var _empty = "Nothing to show yet.";
        if (codeview_sel_only && _sel >= 0) { _empty = "This rule makes no code (its group is off, or an actor it needs is missing)."; }
        ui_text_wrap(_lx1 + 16, _ly1 + 16, _empty, global.TH.text_faint, _lx2 - _lx1 - 32, global.f_body, 1);
    }
    var _a = max(0, floor((_off - 10) / CODEVIEW_LINE_H));
    var _b = min(_ns, _a + ceil((_ly2 - _ly1) / CODEVIEW_LINE_H) + 2);
    var _gcol = global.TH.accent;
    if (_sel >= 0 && proj.rules[_sel].group >= 0) { _gcol = group_colour(proj.rules[_sel].group); }
    for (var i = _a; i < _b; i++)
    {
        var _li = _show[i];
        var _ty = _ly1 + 10 + i * CODEVIEW_LINE_H - _off;
        if (_sel >= 0 && !codeview_sel_only && codeview_in_rule(_li, _sel))
        {
            draw_set_alpha(0.16);
            draw_rectangle_colour(_lx1 + 2, _ty - 1, _lx2 - 10, _ty + CODEVIEW_LINE_H - 1, _gcol, _gcol, _gcol, _gcol, false);
            draw_set_alpha(1);
            draw_rectangle_colour(_lx1 + 2, _ty - 1, _lx1 + 4, _ty + CODEVIEW_LINE_H - 1, _gcol, _gcol, _gcol, _gcol, false);
        }
        ui_text(_lx1 + 38, _ty, string(_li + 1), global.TH.text_faint, fa_right, fa_top, global.f_small, 0.6);
        codeview_line(_lx1 + 46, _ty, live_lines[_li], _lx2 - _lx1 - 70);
    }
    ui_scroll_end("codeview", _lx1, _ly1, _lx2, _ly2, _content);
}
