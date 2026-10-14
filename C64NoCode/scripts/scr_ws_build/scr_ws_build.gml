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
        if (_run)
        {
            if (proj.machine == MACHINE_ULTIMATE) { u64_send_prg(out_path); }
            else { launch_vice(out_path); }
        }
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
    var _plab = "Build and play in VICE   (F5)";
    var _phelp = "Build and play|Builds the program and opens it straight away in the VICE emulator. Joystick: VICE maps it to the keypad or a gamepad - make sure it is in port 2. F5 or the Build & play button at the top does this from any page.";
    if (proj.machine == MACHINE_ULTIMATE)
    {
        _plab = "Build and run on the C64 Ultimate   (F5)";
        _phelp = "Build and run on the C64 Ultimate|Builds the program and sends it over your network to the C64 Ultimate (address on the right), which loads and runs it straight away. F5 or the button at the top does this from any page.";
    }
    else
    {
        if (os_type != os_windows) { _rst = BTN_GHOST; }
    }
    if (ui_button("build_run", _fx, _y, _fw, 46, _plab, _phelp, _rst))
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
    _y += 66;

    // memory: the live measurement (the same as the memory bar at the bottom)
    if (_y + 90 < _y2) { ui_heading(_fx, _y, "Memory (updates as you work)"); }
    _y += 20;
    if (_y + 70 < _y2)
    {
        if (live_ok)
        {
            var _mn = ["Code from your rules", "SID player + sounds", "Sprites (32 x 64 bytes)", "Screen + colour data"];
            var _mv = [live_seg_code, live_seg_sound, live_seg_sprites, live_seg_data];
            var _mc = [global.TH.accent, global.TH.warn, make_colour_rgb(240, 150, 60), global.TH.accent2];
            if (proj.game_type == 1)
            {
                _mn = ["Scrolling engine", "SID player + sounds", "Sprites + charset", "Tiles, enemies + maps"];
            }
            var _cw2 = floor(_fw / 2);
            for (var mi = 0; mi < array_length(_mn); mi++)
            {
                var _mx = _fx + (mi mod 2) * _cw2;
                var _my = _y + (mi div 2) * 22;
                draw_circle_colour(_mx + 6, _my + 9, 5, _mc[mi], _mc[mi], false);
                ui_text(_mx + 18, _my + 9, ui_text_fit(_mn[mi] + "  " + string(_mv[mi]), global.f_small, _cw2 - 22), global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
            }
            ui_text(_fx, _y + 54, ui_text_fit("Program: $0801-$" + string_upper(dec_to_hex(live_end - 1)) + ", " + string(live_size) + " bytes on disk.", global.f_small, _fw), global.TH.text_faint, fa_left, fa_middle, global.f_small, 1);
            ui_register("build_mem", _fx, _y - 20, _fx + _fw, _y + 64, "Memory|What your game is made of, measured a moment after each change (the bar at the bottom of the screen shows the same). Sprites must sit where the VIC-II chip can see them - below $4000 - so very long rule lists push them out and the build fails.");
        }
        else
        {
            var _mt = "Measuring...";
            if (!live_stale && live_err != "") { _mt = "Cannot build yet: " + live_err; }
            ui_text(_fx, _y + 10, ui_text_fit(_mt, global.f_small, _fw), global.TH.text_faint, fa_left, fa_middle, global.f_small, 1);
        }
    }

    // ---------------- log / listing ----------------
    var _rx = _x1 + _lw + 12;
    var _uh = u64_panel_draw(_rx, _y1, _x2);
    var _ry1 = _y1 + _uh + 12;
    ui_panel(_rx, _ry1, _x2, _y2, "Build log");
    build_show_asm = ui_toggle("build_showasm", _x2 - 290, _ry1 + 12, "Show the 6502 code", build_show_asm, "6502 code|For the curious: shows the assembly language the studio wrote for you. You never need to edit it. The Logic page shows it live, rule by rule.");
    var _lx1 = _rx + 14;
    var _ly1 = _ry1 + 52;
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

/// The C64 Ultimate panel on the Build page (address, password, test / run / reset). Returns its height.
function u64_panel_draw(_x1, _y1, _x2)
{
    var _h = 214;
    var _y2 = _y1 + _h;
    var _title = "C64 Ultimate on your network";
    if (proj.machine == MACHINE_ULTIMATE) { _title += "  (target)"; }
    ui_panel(_x1, _y1, _x2, _y2, _title);
    var _fx = _x1 + 20;
    var _fw = _x2 - _x1 - 40;
    var _y = _y1 + 54;
    var _aw = floor(_fw * 0.62);
    var _pw = _fw - _aw - 10;
    ui_heading(_fx, _y, "Address (IP or name)");
    var _ip = ui_textfield("u64_ip", _fx, _y + 18, _aw, 32, u64_ip, 64, "Ultimate address|The network address of your C64 Ultimate, Ultimate 64 or 1541 Ultimate II+ - shown on its screen under F2 > Network settings (for example 192.168.1.64). Turn on 'Web Remote Control Service' there too.");
    if (_ip != u64_ip)
    {
        u64_ip = _ip;
        settings_save();
    }
    ui_heading(_fx + _aw + 10, _y, "Password");
    var _pwd = ui_textfield("u64_pw", _fx + _aw + 10, _y + 18, _pw, 32, u64_password, 32, "Network password|Only if you gave your Ultimate a network password. Leave it empty otherwise. It is kept in the studio's settings on this computer.");
    if (_pwd != u64_password)
    {
        u64_password = _pwd;
        settings_save();
    }
    if (ui_focus != "u64_pw" && u64_password != "")
    {
        // hidden unless you are typing it
        ui_inset(_fx + _aw + 10, _y + 18, _fx + _aw + 10 + _pw, _y + 50, 8);
        ui_text(_fx + _aw + 20, _y + 34, ui_text_fit(string_repeat("*", string_length(u64_password)), global.f_body, _pw - 20), global.TH.text, fa_left, fa_middle, global.f_body, 1);
    }
    _y += 58;
    var _bx = _fx;
    var _bw = floor((_fw - 16) / 3);
    if (ui_button("u64_test", _bx, _y, _bw, 32, "Test", "Test the address|Asks the Ultimate for its version (GET /v1/version) to check the address and password.", BTN_NORMAL)) { u64_ping(); }
    if (ui_button("u64_run", _bx + _bw + 8, _y, _bw, 32, "Send & run", "Build, send and run|Builds the .PRG and sends it to the Ultimate (POST /v1/runners:run_prg), which loads it into memory and runs it - no disks, no SD card.", BTN_ACCENT))
    {
        build_ws_build(false);
        if (build_ok) { u64_send_prg(out_path); }
    }
    if (ui_button("u64_reset", _bx + (_bw + 8) * 2, _y, _bw, 32, "Reset C64", "Reset|Resets the C64 on the Ultimate (PUT /v1/machine:reset), back to the READY prompt.", BTN_GHOST)) { u64_reset(); }
    _y += 42;
    var _msg = u64_status;
    var _col = global.TH.text_dim;
    if (u64_status_kind == 2) { _col = global.TH.danger; }
    if (_msg == "")
    {
        _msg = "Plays your game on a real C64: the C64 Ultimate loads it straight into memory over the network. Pick 'C64 Ultimate' in the top bar and F5 sends it every time.";
        _col = global.TH.text_faint;
    }
    ui_text_wrap(_fx, _y, _msg, _col, _fw, global.f_small, 1);
    return _h;
}
