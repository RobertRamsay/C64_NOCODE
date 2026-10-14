/// C64 NO-CODE STUDIO - top bar, workspace switching, shortcuts

#macro WS_HOME 0
#macro WS_SCREEN 1
#macro WS_SPRITES 2
#macro WS_ACTORS 3
#macro WS_LOGIC 4
#macro WS_SOUND 5
#macro WS_BUILD 6
#macro WS_MUSIC 13
#macro WS_COUNT 14

function ws_set(_i)
{
    if (ws == _i) { return; }
    ws = _i;
    ui_focus = "";
    ui_popup_open = false;
    if (!tut_active && auto_tutorials && !ws_seen[_i])
    {
        ws_seen[_i] = true;
        settings_save();
        tut_start(_i);
    }
}

/// Draws text with the real C64 character ROM. Returns its width.
function ui_c64_text(_x, _y, _str, _scale, _col)
{
    gpu_set_texfilter(false);
    for (var i = 1; i <= string_length(_str); i++)
    {
        var _code = scr_code_from_char(string_char_at(_str, i));
        if (_code != 32) { draw_c64_char(_code, _x + (i - 1) * 8 * _scale, _y, _scale, _col); }
    }
    gpu_set_texfilter(true);
    return string_length(_str) * 8 * _scale;
}

/// Logo capsule: "64  C64 NO-CODE" in the C64 font + rainbow stripes. Returns its width.
function draw_logo(_x, _y, _compact)
{
    var _h = 34;
    var _sc = 2;
    var _r = _h * 0.5;
    var _ty = _y + (_h - 8 * _sc) * 0.5;
    var _badge_w = 2 * 8 * _sc;
    var _title_w = 11 * 8 * _sc;
    if (_compact) { _title_w = -14; }          // narrow window: just the 64 badge and the stripes
    var _stripe_x = _x + 14 + _badge_w + 14 + _title_w + 12;
    var _w = (_stripe_x - _x) + 34 + 6;
    ui_rrect(_x, _y + 2, _x + _w, _y + _h + 2, _r, c_black, c_black, 0.3);
    ui_rrect(_x, _y, _x + _w, _y + _h, _r, make_colour_rgb(70, 78, 92), make_colour_rgb(40, 46, 56), 1);
    ui_rrect(_x + 2, _y + 1, _x + _w - 2, _y + _h * 0.45, _r - 1, c_white, c_white, 0.06);
    ui_rrect_line(_x, _y, _x + _w, _y + _h, _r, global.TH.panel_edge, 0.8, 1);
    ui_c64_text(_x + 14, _ty, "64", _sc, c_white);
    if (!_compact) { ui_c64_text(_x + 14 + _badge_w + 14, _ty, "C64 NO-CODE", _sc, global.TH.text); }
    // breadbin rainbow stripes at the right end
    var _stripes = [make_colour_rgb(222, 72, 72), make_colour_rgb(240, 150, 60), make_colour_rgb(240, 210, 80), make_colour_rgb(90, 190, 110), make_colour_rgb(80, 140, 230)];
    var _st = _y + 8;
    var _sb = _y + _h - 8;
    for (var i = 0; i < 5; i++)
    {
        var _sx = _stripe_x + i * 4.5;
        draw_set_colour(_stripes[i]);
        draw_primitive_begin(pr_trianglestrip);
        draw_vertex(_sx, _sb);
        draw_vertex(_sx + 3, _sb);
        draw_vertex(_sx + 11, _st);
        draw_vertex(_sx + 14, _st);
        draw_primitive_end();
    }
    return _w;
}

function draw_topbar(_gw)
{
    ui_rrect(0, -20, _gw, 60, 0, global.TH.bar_top, global.TH.bar_bot, 1);
    draw_line_colour(0, 60, _gw, 60, global.TH.panel_edge, global.TH.panel_edge);
    draw_set_alpha(0.25);
    draw_line_colour(0, 61, _gw, 61, c_black, c_black);
    draw_set_alpha(1);

    // widths of the right-hand buttons, sized from their labels so they are never cut short
    var _tabs = ws_tabs();
    var _nt = array_length(_tabs);
    var _tutlab = "Tutorial (F1)";
    var _playlab = "Build & play (F5)";
    if (proj.machine == MACHINE_ULTIMATE) { _playlab = "Play on Ultimate (F5)"; }
    draw_set_font(global.f_bold);
    var _tutw = max(104, ceil(ui_sw(_tutlab)) + 24);
    var _playw = ceil(ui_sw(_playlab)) + 28;
    var _helpw = 102;
    var _udw = 64;
    var _lsum = 0;
    for (var tl = 0; tl < _nt; tl++) { _lsum += ceil(ui_sw(ws_name(_tabs[tl]))); }
    var _mw = 136;
    var _full_avail = _gw - (14 + 290 + 12 + _mw + 18) - (14 + _tutw + 6 + _helpw + 6 + _udw + 6 + _udw + 12 + _playw + 12);
    // narrow window: shorter labels and no Helpers button (it is on Home too)
    var _compact = (_full_avail < _lsum + 16 * _nt);
    if (_compact)
    {
        _tutlab = "Help";
        _playlab = "Play";              // F5 is in its help bubble
        draw_set_font(global.f_bold);
        _tutw = ceil(ui_sw(_tutlab)) + 24;
        _playw = ceil(ui_sw(_playlab)) + 24;
        _helpw = 0;
        _udw = 58;
        _mw = 112;
    }

    var _logo_w = draw_logo(14, 13, _compact);

    // target machine badge: PAL, NTSC or the C64 Ultimate
    var _m = machine_cur();
    var _mx = 14 + _logo_w + 12;
    var _mnames = [];
    for (var mi = 0; mi < MACHINE_COUNT; mi++) { array_push(_mnames, global.MACHINES[mi].short_name); }
    var _nm = ui_dropdown("top_machine", _mx, 14, _mw, 32, _mnames, proj.machine, "Target machine|" + _m.name + ". " + _m.note + " Click to change the machine this game is made for.");
    if (_nm != proj.machine)
    {
        set_val(proj, "machine", _nm, "machine" + string(current_time));
        toast("Target: " + global.MACHINES[_nm].name, 0);
    }

    // page tabs share what is left
    var _right = 14 + _tutw + 6 + _udw + 6 + _udw + 12 + _playw + 12;
    if (_helpw > 0) { _right += _helpw + 6; }
    var _tw = 94;
    var _tx = _mx + _mw + 18;
    var _avail = _gw - _tx - _right;
    // each tab 94 wide when there is room; otherwise sized to its label plus an even share
    var _tws = array_create(_nt, _tw);
    if (_avail < _tw * _nt)
    {
        draw_set_font(global.f_bold);
        for (var t0 = 0; t0 < _nt; t0++) { _tws[t0] = ceil(ui_sw(ws_name(_tabs[t0]))); }
        var _pad = floor((_avail - _lsum) / _nt);
        if (_pad >= 12)
        {
            for (var t1 = 0; t1 < _nt; t1++) { _tws[t1] += _pad; }
        }
        else
        {
            // no room for every label: the longest are cut short first, the short ones stay whole
            var _lo = 10;
            var _hi = 240;
            while (_lo < _hi)
            {
                var _mid = (_lo + _hi + 1) div 2;
                var _sum = 0;
                for (var t4 = 0; t4 < _nt; t4++) { _sum += min(_tws[t4], _mid) + 12; }
                if (_sum <= _avail) { _lo = _mid; }
                else { _hi = _mid - 1; }
            }
            for (var t2 = 0; t2 < _nt; t2++) { _tws[t2] = min(_tws[t2], _lo) + 12; }
        }
    }
    var _tsum = 0;
    for (var t3 = 0; t3 < _nt; t3++) { _tsum += _tws[t3]; }
    ui_rrect(_tx - 6, 11, _tx + _tsum + 6, 49, 19, global.TH.inset_top, global.TH.inset_bot, 0.8);
    var _tabx = _tx;
    for (var i = 0; i < _nt; i++)
    {
        var _w = _tabs[i];
        if (ui_tab("tab_" + string(_w), _tabx, 14, _tws[i] - 2, 32, ui_text_fit(ws_name(_w), global.f_bold, _tws[i] - 10), ws == _w, ws_help(_w)))
        {
            ws_set(_w);
        }
        _tabx += _tws[i];
    }

    var _rx = _gw - 14;
    _rx -= _tutw;
    if (ui_button("top_tutorial", _rx, 14, _tutw, 32, _tutlab, "Tutorial|Shows a step-by-step guide for the page you are on. Every page has its own tutorial. Shortcut: F1.", BTN_ACCENT))
    {
        tut_start(ws);
    }
    if (_helpw > 0)
    {
        _rx -= _helpw + 6;
        var _hlab = "Helpers off";
        var _hsty = BTN_NORMAL;
        if (helpers_on)
        {
            _hlab = "Helpers on";
            _hsty = BTN_ON;
        }
        if (ui_button("top_helpers", _rx, 14, _helpw, 32, _hlab, "Hover helpers|When on, resting the mouse on any control draws guide lines and a help bubble explaining it.", _hsty))
        {
            helpers_on = !helpers_on;
            settings_save();
        }
    }
    var _nredo = array_length(redo_stack);
    var _nundo = array_length(undo_stack);
    _rx -= _udw + 6;
    var _rst = BTN_GHOST;
    if (_nredo > 0) { _rst = BTN_NORMAL; }
    if (ui_button("top_redo", _rx, 14, _udw, 32, "Redo", "Redo|Puts back the last change you undid (" + string(_nredo) + " to redo). Shortcut: Ctrl+Y.", _rst))
    {
        redo_do();
    }
    _rx -= _udw + 6;
    var _ust = BTN_GHOST;
    if (_nundo > 0) { _ust = BTN_NORMAL; }
    if (ui_button("top_undo", _rx, 14, _udw, 32, "Undo", "Undo|Takes back your last change (" + string(_nundo) + " to undo). Shortcut: Ctrl+Z.", _ust))
    {
        undo_do();
    }
    if (_nundo > 0)
    {
        draw_circle_colour(_rx + _udw - 4, 18, 7, global.TH.accent, global.TH.accent_dark, false);
        ui_text(_rx + _udw - 4, 18, string(min(99, _nundo)), c_white, fa_center, fa_middle, global.f_small, 1);
    }
    _rx -= _playw + 12;
    var _phelp = "Build and play|Builds your game's .PRG and starts it in VICE straight away, from any page - the same as Build and play on the Build page. Shortcut: F5.";
    if (proj.machine == MACHINE_ULTIMATE) { _phelp = "Play on the C64 Ultimate|Builds your game's .PRG and sends it over the network to your C64 Ultimate, which runs it straight away. Set its address on the Build page. Shortcut: F5."; }
    if (ui_button("top_play", _rx, 14, _playw, 32, _playlab, _phelp, BTN_ACCENT))
    {
        build_ws_build(true);
    }
}

function shortcuts_step()
{
    if (ui_focus != "") { return; }
    var _ctrl = keyboard_check(vk_control);
    if (_ctrl && keyboard_check_pressed(ord("Z"))) { undo_do(); }
    if (_ctrl && keyboard_check_pressed(ord("Y"))) { redo_do(); }
    if (_ctrl && keyboard_check_pressed(ord("S"))) { home_save(false); }
    if (_ctrl && keyboard_check_pressed(ord("B"))) { build_ws_build(false); }
    if (keyboard_check_pressed(vk_f5)) { build_ws_build(true); }
    if (_ctrl && (keyboard_check_pressed(187) || keyboard_check_pressed(vk_add))) { ui_scale_step(1); }
    if (_ctrl && (keyboard_check_pressed(189) || keyboard_check_pressed(vk_subtract))) { ui_scale_step(-1); }
    if (_ctrl && keyboard_check_pressed(ord("0"))) { ui_scale_pref = 0; settings_save(); toast("Interface size: auto", 0); }
    if (keyboard_check_pressed(vk_f1))
    {
        if (tut_active) { tut_active = false; }
        else { tut_start(ws); }
    }
    if (!tut_active && !_ctrl && ws != WS_SCREEN && !(ws == WS_MUSIC && mus_ed_keys_hover))
    {
        var _tabs = ws_tabs();
        for (var i = 0; i < min(9, array_length(_tabs)); i++)
        {
            if (keyboard_check_pressed(ord(string(i + 1)))) { ws_set(_tabs[i]); }
        }
        if (array_length(_tabs) >= 10 && keyboard_check_pressed(ord("0"))) { ws_set(_tabs[array_length(_tabs) - 1]); }   // 0 = Build
    }
}

/// Steps the interface size up or down through the preset list
function ui_scale_step(_d)
{
    var _vals = global.UI_SCALE_VALUES;
    var _cur = ui_scale_pref;
    if (_cur == 0) { _cur = global.ui_scale; }
    var _best = 1;
    for (var i = 1; i < array_length(_vals); i++)
    {
        if (abs(_vals[i] - _cur) < abs(_vals[_best] - _cur)) { _best = i; }
    }
    _best = clamp(_best + _d, 1, array_length(_vals) - 1);
    ui_scale_pref = _vals[_best];
    settings_save();
    toast("Interface size: " + global.UI_SCALE_NAMES[_best], 0);
}

/// Tabs shown for the current kind of project
function ws_tabs()
{
    if (proj.game_type == 1)
    {
        return [WS_HOME, WS_TEMPLATES, WS_WORLD, WS_MAP, WS_TILES, WS_CHARSET, WS_ENEMIES, WS_SPRITES, WS_SOUND, WS_MUSIC, WS_BUILD];
    }
    return [WS_HOME, WS_TEMPLATES, WS_SCREEN, WS_SPRITES, WS_ACTORS, WS_LOGIC, WS_SOUND, WS_MUSIC, WS_BUILD];
}

function ws_name(_w)
{
    var _n = ["Home", "Screen", "Sprites", "Actors", "Logic", "Sound", "Build", "Templates", "World", "Charset", "Tiles", "Map", "Enemies", "Music"];
    return _n[_w];
}

function ws_help(_w)
{
    var _h = [
        "Home|Start here: open or create projects, choose single-screen or map game, and set game-wide options.",
        "Screen|Paint the background screen with C64 characters and colours, or type text straight onto it.",
        "Sprites|Draw up to 32 sprites pixel by pixel. They become the pictures for players, enemies and bullets.",
        "Actors|Place the things that move: the player, enemies and pickups. Choose how each one behaves.",
        "Logic|Make the game rules in plain English: WHEN something happens, DO something - in groups you can fold and switch off, with the 6502 code it becomes shown live.",
        "Sound|Design up to 32 sound effects for the C64's SID chip - waveforms, pulse width, envelope, filter and arpeggios - in folders, and hear them instantly.",
        "Build|Turn your game into a real C64 program (.PRG) and play it in VICE, on a C64 Ultimate over the network, or on real hardware.",
        "Templates|Ready-made games to start from: shoot-em-ups, platformers, a Boulder Dash style cave and more.",
        "World|How the map game plays: kind of game, scrolling, the play window, the player, weapons, and the stock-C64 cycle meter.",
        "Charset|Edit the 256 characters that tiles are built from, in hi-res or multicolour.",
        "Tiles|Build 16x16 tiles from 4 characters and give them jobs: solid, deadly, collectable, exit, ladder and more.",
        "Map|Paint levels with tiles, place enemy spawners and the player's start. Up to 8 levels.",
        "Enemies|Design enemy types: picture, movement, speed, toughness, points and how they shoot.",
        "Music|Make songs for the SID chip's 3 voices: paint ready-made loops onto a timeline, edit the notes, and choose where each song plays. Bring in ProTracker .mod files, or save songs as .mod or .SID. Sound effects borrow voice 1 or 2 while they play."
    ];
    return _h[_w];
}
