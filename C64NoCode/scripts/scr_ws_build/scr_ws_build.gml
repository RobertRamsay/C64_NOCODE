/// C64 NO-CODE STUDIO - Build workspace

function build_log_add(_text, _kind)
{
    array_push(build_log, { text : _text, kind : _kind });
    if (array_length(build_log) > 200) { array_delete(build_log, 0, 1); }
}

function build_choose_output()
{
    var _name = string_replace_all(proj.name, " ", "_");
    var _p = get_save_filename("C64 program|*.prg", _name + ".prg");
    if (_p == "") { return false; }
    if (string_lower(filename_ext(_p)) != ".prg") { _p += ".prg"; }
    out_path = _p;
    settings_save();
    return true;
}

function build_ws_build(_run)
{
    if (out_path == "")
    {
        if (!build_choose_output()) { return; }
    }
    var _t0 = current_time;
    var _ok = false;
    if (proj.game_type == 1) { _ok = build_engine_prg(out_path); }
    else { _ok = build_prg(out_path); }
    if (_ok)
    {
        build_log_add(build_msg + "  (" + string(current_time - _t0) + " ms)", 0);
        for (var i = 0; i < array_length(build_warnings); i++) { build_log_add(build_warnings[i], 1); }
        toast("Build complete!", 0);
        if (_run) { launch_vice(out_path); }
    }
    else
    {
        build_log_add(build_msg, 2);
        toast("Build failed - see the log", 2);
    }
}

function draw_check(_x, _y, _kind)
{
    var _c = global.TH.accent2;
    if (_kind == 1) { _c = global.TH.warn; }
    if (_kind == 2) { _c = global.TH.danger; }
    draw_circle_colour(_x, _y, 10, _c, merge_colour(_c, c_black, 0.25), false);
    if (_kind == 0)
    {
        draw_line_width_colour(_x - 5, _y, _x - 1, _y + 4, 2, c_white, c_white);
        draw_line_width_colour(_x - 1, _y + 4, _x + 5, _y - 4, 2, c_white, c_white);
    }
    else
    {
        draw_line_width_colour(_x, _y - 5, _x, _y + 1, 2, c_white, c_white);
        draw_circle_colour(_x, _y + 5, 1.5, c_white, c_white, false);
    }
}

function ws_build_draw(_x1, _y1, _x2, _y2)
{
    var _lw = min(480, floor((_x2 - _x1) * 0.42));
    ui_panel(_x1, _y1, _x1 + _lw, _y2, "Build your game");
    var _fx = _x1 + 20;
    var _fw = _lw - 40;
    var _y = _y1 + 58;

    // checklist
    var _na = array_length(proj.actors);
    var _nr = array_length(proj.rules);
    var _has_player = false;
    for (var i = 0; i < _na; i++)
    {
        if (proj.actors[i].role == 0) { _has_player = true; }
    }
    var _lose = false;
    var _end = false;
    for (var r = 0; r < _nr; r++)
    {
        if (proj.rules[r].act == 1) { _lose = true; }
        if (proj.rules[r].act == 10 || proj.rules[r].act == 11) { _end = true; }
    }
    var _items = [];
    var _kinds = [];
    if (proj.game_type == 1)
    {
        var _bud = eng_cycle_budget(proj.eng);
        array_push(_items, global.KIND_LIST[proj.eng.kind - 1] + ", " + string_lower(global.SCROLL_NAMES[proj.eng.scroll]));
        array_push(_kinds, 0);
        array_push(_items, string(array_length(proj.levels)) + " level(s), " + string(array_length(proj.tiles)) + " tiles, " + string(array_length(proj.enemies)) + " enemy types");
        array_push(_kinds, 0);
        var _sp = 0;
        for (var lq = 0; lq < array_length(proj.levels); lq++) { _sp += array_length(proj.levels[lq].spawners); }
        array_push(_items, string(_sp) + " enemy spawner(s) placed");
        if (_sp > 0) { array_push(_kinds, 0); } else { array_push(_kinds, 1); }
        if (_bud.fits && !_bud.tear) { array_push(_items, "Fits the stock C64 frame budget"); array_push(_kinds, 0); }
        else { array_push(_items, "Over the frame budget - see the World page"); array_push(_kinds, 1); }
        var _small = false;
        for (var lw2 = 0; lw2 < array_length(proj.levels); lw2++) { if (proj.levels[lw2].w < 20) { _small = true; } }
        if (_small) { array_push(_items, "A map is narrower than 20 tiles"); array_push(_kinds, 2); }
    }
    else if (_has_player) { array_push(_items, "There is a Player actor for the joystick"); array_push(_kinds, 0); }
    else { array_push(_items, "No Player actor - set one on the Actors page"); array_push(_kinds, 1); }
    if (proj.game_type == 0)
    {
        array_push(_items, string(_na) + " of 8 actors used");
        if (_na > 0) { array_push(_kinds, 0); } else { array_push(_kinds, 1); }
        array_push(_items, string(_nr) + " rule(s)");
        if (_nr > 0) { array_push(_kinds, 0); } else { array_push(_kinds, 1); }
        if (_end) { array_push(_items, "The game can end (game over or win)"); array_push(_kinds, 0); }
        else { array_push(_items, "Nothing ends the game yet - add a Game over or You win rule"); array_push(_kinds, 1); }
    }
    if (proj.game_type == 0 && proj.show_lives && !_lose) { array_push(_items, "Lives are shown but no rule takes a life away"); array_push(_kinds, 1); }
    ui_heading(_fx, _y, "Checklist");
    _y += 22;
    for (var c = 0; c < array_length(_items); c++)
    {
        draw_check(_fx + 10, _y + 11, _kinds[c]);
        ui_text(_fx + 30, _y + 11, ui_text_fit(_items[c], global.f_body, _fw - 34), global.TH.text, fa_left, fa_middle, global.f_body, 1);
        _y += 28;
    }
    _y += 14;

    if (ui_button("build_prg", _fx, _y, _fw, 46, "Build .PRG   (Ctrl+B)", "Build|Turns your project into a real Commodore 64 program file (.PRG) that runs in emulators and on real machines.", BTN_ACCENT))
    {
        build_ws_build(false);
    }
    _y += 54;
    var _rst = BTN_ON;
    if (os_type != os_windows) { _rst = BTN_GHOST; }
    if (ui_button("build_run", _fx, _y, _fw, 46, "Build and play in VICE", "Build and play|Builds the program and opens it straight away in the VICE emulator. Joystick: VICE maps it to the keypad or a gamepad - make sure it is in port 2.", _rst))
    {
        build_ws_build(true);
    }
    _y += 62;

    ui_heading(_fx, _y, "Program file");
    var _op = out_path;
    if (_op == "") { _op = "(you will be asked the first time you build)"; }
    ui_inset(_fx, _y + 18, _fx + _fw - 96, _y + 50, 8);
    ui_text(_fx + 10, _y + 34, ui_text_fit(_op, global.f_small, _fw - 120), global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
    if (ui_button("build_outpath", _fx + _fw - 88, _y + 18, 88, 32, "Change", "Output file|Choose where the .PRG file is saved.", BTN_NORMAL))
    {
        build_choose_output();
    }
    _y += 62;
    ui_heading(_fx, _y, "VICE emulator (x64sc)");
    var _vp = vice_path;
    if (_vp == "") { _vp = "(not set - click Find to choose x64sc.exe)"; }
    ui_inset(_fx, _y + 18, _fx + _fw - 96, _y + 50, 8);
    ui_text(_fx + 10, _y + 34, ui_text_fit(_vp, global.f_small, _fw - 120), global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
    if (ui_button("build_vicepath", _fx + _fw - 88, _y + 18, 88, 32, "Find", "Find VICE|Point the studio at x64sc.exe inside your VICE folder (download VICE free from vice-emu.sourceforge.io).", BTN_NORMAL))
    {
        var _v = get_open_filename("VICE C64 emulator|x64sc.exe;x64sc", "");
        if (_v != "")
        {
            vice_path = _v;
            settings_save();
        }
    }
    _y += 70;

    // memory map
    ui_heading(_fx, _y, "Memory used (after last build)");
    _y += 20;
    ui_inset(_fx, _y, _fx + _fw, _y + 26, 8);
    if (build_ok)
    {
        var _range = 16384 - 2049;
        var _sprsz = SPR_COUNT * 64;
        if (proj.game_type == 1) { _range = 32768 - 2049; _sprsz = 2048 + 2048; }
        var _codew = (build_spr - 2049) / _range * (_fw - 4);
        var _sprw = _sprsz / _range * (_fw - 4);
        var _restw = max(0, (build_end - build_spr - _sprsz) / _range * (_fw - 4));
        ui_rrect(_fx + 2, _y + 2, _fx + 2 + _codew, _y + 24, 6, global.TH.accent, global.TH.accent_dark, 1);
        ui_rrect(_fx + 2 + _codew, _y + 2, _fx + 2 + _codew + _sprw, _y + 24, 4, global.TH.warn, merge_colour(global.TH.warn, c_black, 0.3), 1);
        ui_rrect(_fx + 2 + _codew + _sprw, _y + 2, _fx + 2 + _codew + _sprw + _restw, _y + 24, 4, global.TH.accent2, merge_colour(global.TH.accent2, c_black, 0.3), 1);
        ui_register("build_mem", _fx, _y, _fx + _fw, _y + 26, "Memory map|Blue: program code. Yellow: sprites. Green: screen and colour data. The C64 has plenty of room left!");
        _y += 34;
        ui_text(_fx, _y, "Code   Sprites   Screen data      " + string(build_size) + " bytes", global.TH.text_faint, fa_left, fa_top, global.f_small, 1);
    }
    else
    {
        ui_text(_fx + 12, _y + 13, "Build to see the memory map", global.TH.text_faint, fa_left, fa_middle, global.f_small, 1);
    }

    // ---------------- log / listing ----------------
    var _rx = _x1 + _lw + 12;
    ui_panel(_rx, _y1, _x2, _y2, "Build log");
    build_show_asm = ui_toggle("build_showasm", _x2 - 290, _y1 + 12, "Show the 6502 code", build_show_asm, "6502 code|For the curious: shows the assembly language the studio wrote for you. You never need to edit it.");
    var _lx1 = _rx + 14;
    var _ly1 = _y1 + 52;
    var _lx2 = _x2 - 14;
    var _ly2 = _y2 - 12;
    ui_inset(_lx1, _ly1, _lx2, _ly2, 10);
    if (build_show_asm)
    {
        var _n = array_length(build_listing);
        var _content = _n * 18 + 20;
        var _off = ui_scroll_begin("build_asm", _lx1, _ly1, _lx2, _ly2, _content);
        var _first = max(0, floor((_off - 10) / 18));
        var _last = min(_n, _first + ceil((_ly2 - _ly1) / 18) + 2);
        for (var l = _first; l < _last; l++)
        {
            var _line = build_listing[l];
            var _col = global.TH.text_dim;
            if (string_char_at(_line, 1) != " ") { _col = global.TH.accent; }
            if (string_char_at(_line, 1) == ";") { _col = global.TH.text_faint; }
            ui_text(_lx1 + 50, _ly1 + 10 + l * 18 - _off, _line, _col, fa_left, fa_top, global.f_small, 1);
            ui_text(_lx1 + 40, _ly1 + 10 + l * 18 - _off, string(l + 1), global.TH.text_faint, fa_right, fa_top, global.f_small, 0.6);
        }
        if (_n == 0)
        {
            ui_text(_lx1 + 16, _ly1 + 16, "Build once to see the generated code.", global.TH.text_faint, fa_left, fa_top, global.f_body, 1);
        }
        ui_scroll_end("build_asm", _lx1, _ly1, _lx2, _ly2, _content);
    }
    else
    {
        var _ln = array_length(build_log);
        if (_ln == 0)
        {
            ui_text_wrap(_lx1 + 16, _ly1 + 16, "Nothing built yet. Press 'Build .PRG' and your game is turned into a real C64 program. Messages and tips will appear here.", global.TH.text_faint, _lx2 - _lx1 - 32, global.f_body, 1);
        }
        var _ly = _ly1 + 14;
        for (var m = max(0, _ln - 30); m < _ln; m++)
        {
            var _e = build_log[m];
            draw_check(_lx1 + 22, _ly + 10, _e.kind);
            ui_text(_lx1 + 42, _ly + 10, ui_text_fit(_e.text, global.f_body, _lx2 - _lx1 - 56), global.TH.text, fa_left, fa_middle, global.f_body, 1);
            _ly += 28;
            if (_ly > _ly2 - 20) { break; }
        }
    }
}
