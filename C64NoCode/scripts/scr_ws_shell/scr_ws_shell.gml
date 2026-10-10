/// C64 NO-CODE STUDIO - top bar, workspace switching, shortcuts

#macro WS_HOME 0
#macro WS_SCREEN 1
#macro WS_SPRITES 2
#macro WS_ACTORS 3
#macro WS_LOGIC 4
#macro WS_SOUND 5
#macro WS_BUILD 6
#macro WS_COUNT 13

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
function draw_logo(_x, _y)
{
    var _h = 34;
    var _sc = 2;
    var _r = _h * 0.5;
    var _ty = _y + (_h - 8 * _sc) * 0.5;
    var _badge_w = 2 * 8 * _sc;
    var _title_w = 11 * 8 * _sc;
    var _stripe_x = _x + 14 + _badge_w + 14 + _title_w + 12;
    var _w = (_stripe_x - _x) + 34 + 6;
    ui_rrect(_x, _y + 2, _x + _w, _y + _h + 2, _r, c_black, c_black, 0.3);
    ui_rrect(_x, _y, _x + _w, _y + _h, _r, make_colour_rgb(70, 78, 92), make_colour_rgb(40, 46, 56), 1);
    ui_rrect(_x + 2, _y + 1, _x + _w - 2, _y + _h * 0.45, _r - 1, c_white, c_white, 0.06);
    ui_rrect_line(_x, _y, _x + _w, _y + _h, _r, global.TH.panel_edge, 0.8, 1);
    ui_c64_text(_x + 14, _ty, "64", _sc, c_white);
    ui_c64_text(_x + 14 + _badge_w + 14, _ty, "C64 NO-CODE", _sc, global.TH.text);
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
    var _logo_w = draw_logo(14, 13);

    var _tabs = ws_tabs();
    var _nt = array_length(_tabs);
    var _tw = 94;
    var _tx = 14 + _logo_w + 18;
    var _avail = _gw - _tx - 380;
    if (_avail < _tw * _nt) { _tw = max(64, floor(_avail / _nt)); }
    ui_rrect(_tx - 6, 11, _tx + _tw * _nt + 6, 49, 19, global.TH.inset_top, global.TH.inset_bot, 0.8);
    for (var i = 0; i < _nt; i++)
    {
        var _w = _tabs[i];
        if (ui_tab("tab_" + string(_w), _tx + i * _tw, 14, _tw - 2, 32, ui_text_fit(ws_name(_w), global.f_bold, _tw - 10), ws == _w, ws_help(_w)))
        {
            ws_set(_w);
        }
    }

    var _rx = _gw - 14;
    _rx -= 104;
    if (ui_button("top_tutorial", _rx, 14, 104, 32, "Tutorial (F1)", "Tutorial|Shows a step-by-step guide for the page you are on. Every page has its own tutorial.", BTN_ACCENT))
    {
        tut_start(ws);
    }
    _rx -= 108;
    var _hlab = "Helpers off";
    var _hsty = BTN_NORMAL;
    if (helpers_on)
    {
        _hlab = "Helpers on";
        _hsty = BTN_ON;
    }
    if (ui_button("top_helpers", _rx, 14, 102, 32, _hlab, "Hover helpers|When on, resting the mouse on any control draws guide lines and a help bubble explaining it.", _hsty))
    {
        helpers_on = !helpers_on;
        settings_save();
    }
    _rx -= 70;
    if (ui_button("top_redo", _rx, 14, 64, 32, "Redo", "Redo|Puts back the last change you undid. Shortcut: Ctrl+Y.", BTN_GHOST))
    {
        redo_do();
    }
    _rx -= 70;
    if (ui_button("top_undo", _rx, 14, 64, 32, "Undo", "Undo|Takes back your last change. Shortcut: Ctrl+Z.", BTN_GHOST))
    {
        undo_do();
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
    if (_ctrl && (keyboard_check_pressed(187) || keyboard_check_pressed(vk_add))) { ui_scale_step(1); }
    if (_ctrl && (keyboard_check_pressed(189) || keyboard_check_pressed(vk_subtract))) { ui_scale_step(-1); }
    if (_ctrl && keyboard_check_pressed(ord("0"))) { ui_scale_pref = 0; settings_save(); toast("Interface size: auto", 0); }
    if (keyboard_check_pressed(vk_f1))
    {
        if (tut_active) { tut_active = false; }
        else { tut_start(ws); }
    }
    if (!tut_active && !_ctrl && ws != WS_SCREEN)
    {
        var _tabs = ws_tabs();
        for (var i = 0; i < min(9, array_length(_tabs)); i++)
        {
            if (keyboard_check_pressed(ord(string(i + 1)))) { ws_set(_tabs[i]); }
        }
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
        return [WS_HOME, WS_TEMPLATES, WS_WORLD, WS_MAP, WS_TILES, WS_CHARSET, WS_ENEMIES, WS_SPRITES, WS_SOUND, WS_BUILD];
    }
    return [WS_HOME, WS_TEMPLATES, WS_SCREEN, WS_SPRITES, WS_ACTORS, WS_LOGIC, WS_SOUND, WS_BUILD];
}

function ws_name(_w)
{
    var _n = ["Home", "Screen", "Sprites", "Actors", "Logic", "Sound", "Build", "Templates", "World", "Charset", "Tiles", "Map", "Enemies"];
    return _n[_w];
}

function ws_help(_w)
{
    var _h = [
        "Home|Start here: open or create projects, choose single-screen or map game, and set game-wide options.",
        "Screen|Paint the background screen with C64 characters and colours, or type text straight onto it.",
        "Sprites|Draw up to 32 sprites pixel by pixel. They become the pictures for players, enemies and bullets.",
        "Actors|Place the things that move: the player, enemies and pickups. Choose how each one behaves.",
        "Logic|Make the game rules in plain English: WHEN something happens, DO something.",
        "Sound|Design up to 8 sound effects with the C64's SID chip and preview them instantly.",
        "Build|Turn your game into a real C64 program (.PRG) and play it in VICE or on real hardware.",
        "Templates|Ready-made games to start from: shoot-em-ups, platformers, a Boulder Dash style cave and more.",
        "World|How the map game plays: kind of game, scrolling, the play window, the player, weapons, and the stock-C64 cycle meter.",
        "Charset|Edit the 256 characters that tiles are built from, in hi-res or multicolour.",
        "Tiles|Build 16x16 tiles from 4 characters and give them jobs: solid, deadly, collectable, exit, ladder and more.",
        "Map|Paint levels with tiles, place enemy spawners and the player's start. Up to 8 levels.",
        "Enemies|Design enemy types: picture, movement, speed, toughness, points and how they shoot."
    ];
    return _h[_w];
}
