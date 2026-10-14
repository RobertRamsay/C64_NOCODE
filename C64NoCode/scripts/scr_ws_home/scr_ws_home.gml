/// C64 ENGINE - Home workspace

function home_save(_save_as)
{
    var _path = proj_path;
    if (_save_as || _path == "")
    {
        _path = get_save_filename(APP_NAME + " project|*.c64nc", proj.name + ".c64nc");
        if (_path == "") { return; }
        if (filename_ext(_path) == "") { _path += ".c64nc"; }
    }
    project_save_to(_path);
}

function home_open()
{
    if (proj_dirty)
    {
        if (!show_question("You have unsaved changes. Open another project anyway?")) { return; }
    }
    var _path = get_open_filename(APP_NAME + " project|*.c64nc", "");
    if (_path != "") { project_load_from(_path); }
}

function home_new(_example)
{
    if (proj_dirty)
    {
        if (!show_question("You have unsaved changes. Start a new project anyway?")) { return; }
    }
    if (_example) { proj = project_example(); }
    else { proj = project_new(); }
    proj_path = "";
    proj_dirty = false;
    undo_stack = [];
    redo_stack = [];
    project_after_change();
    if (_example) { toast("Example game loaded - try Build to play it!", 0); }
    else { toast("New project ready", 0); }
}

function ws_home_draw(_x1, _y1, _x2, _y2)
{
    var _split = _x1 + floor((_x2 - _x1) * 0.6);
    // ---------- hero ----------
    ui_panel(_x1, _y1, _split - 10, _y1 + 250, "");
    // the product's mark, top right of the hero (the top bar drops its name when the tabs need the room)
    var _bw = string_length(APP_LOGO) * 8 * 2;
    if (_split - 10 - 28 - _bw > _x1 + 560) { ui_c64_text(_split - 10 - 28 - _bw, _y1 + 30, APP_LOGO, 2, global.TH.accent2); }
    ui_text(_x1 + 28, _y1 + 26, "Make a Commodore 64 game.", c_white, fa_left, fa_top, global.f_hero, 1);
    ui_text(_x1 + 28, _y1 + 62, "No code needed.", global.TH.accent, fa_left, fa_top, global.f_hero, 1);
    ui_text_wrap(_x1 + 28, _y1 + 106, "Paint a screen, draw sprites, choose how things move and write the rules as simple WHEN / DO sentences. The studio builds a real C64 program for you.", global.TH.text_dim, _split - _x1 - 70, global.f_body, 1);
    var _bx = _x1 + 28;
    var _by = _y1 + 176;
    // the buttons shrink to fit when the left panel is narrow
    var _k = min(1, (_split - 10 - 28 - _bx) / 760);
    if (ui_button("home_tour", _bx, _by, 190 * _k, 40, "Take the guided tour", "Guided tour|A full walk-through of every page, from painting the screen to playing your game. Takes about five minutes.", BTN_ACCENT))
    {
        tut_start(-1);
    }
    if (ui_button("home_example", _bx + 200 * _k, _by, 190 * _k, 40, "Load example game", "Example game|Loads 'Gem Hunter', a finished little game. Look around every page to see how it was made, then build it.", BTN_ON))
    {
        home_new(true);
    }
    if (ui_button("home_new", _bx + 400 * _k, _by, 80 * _k, 40, "New", "New project|Starts a blank project.", BTN_NORMAL)) { home_new(false); }
    if (ui_button("home_open", _bx + 488 * _k, _by, 80 * _k, 40, "Open", "Open project|Opens a .c64nc project file you saved earlier.", BTN_NORMAL)) { home_open(); }
    if (ui_button("home_save", _bx + 576 * _k, _by, 80 * _k, 40, "Save", "Save project|Saves your project (Ctrl+S). The first time it asks where to put it.", BTN_NORMAL)) { home_save(false); }
    if (ui_button("home_saveas", _bx + 664 * _k, _by, 96 * _k, 40, "Save as", "Save as|Saves a copy of your project under a new name.", BTN_GHOST)) { home_save(true); }

    // ---------- workflow cards ----------
    var _cy = _y1 + 270;
    ui_panel(_x1, _cy, _split - 10, _y2, "How it works");
    var _titles = ["Paint the screen", "Draw sprites", "Place actors", "Write the rules", "Make sounds", "Build and play"];
    var _desc = ["Backgrounds, titles and walls made from C64 characters.",
                 "Up to 32 sprite pictures, hi-res or multicolour.",
                 "Pick the player, enemies and pickups and how they move.",
                 "WHEN the player touches a gem, DO add 10 to the score.",
                 "Coins, lasers and explosions from the SID chip - filters, arpeggios and all.",
                 "Get a real .PRG file and run it in VICE or on a C64 Ultimate."];
    var _cw = floor((_split - 10 - _x1 - 48) / 3);
    var _ch = floor((_y2 - _cy - 74) / 2);
    for (var i = 0; i < 6; i++)
    {
        var _cx = _x1 + 16 + (i mod 3) * (_cw + 8);
        var _cyy = _cy + 56 + (i div 3) * (_ch + 8);
        var _id = "home_card_" + string(i);
        var _hot = ui_register(_id, _cx, _cyy, _cx + _cw, _cyy + _ch, _titles[i] + "|" + _desc[i] + " Click to go to that page.");
        var _tgt = 0;
        if (_hot) { _tgt = 1; }
        var _a = ui_anim_to(_id, _tgt);
        ui_rrect(_cx, _cyy, _cx + _cw, _cyy + _ch, 12, merge_colour(global.TH.btn_top, global.TH.btn_hot_top, _a), merge_colour(global.TH.panel_bot, global.TH.btn_bot, _a), 1);
        ui_rrect_line(_cx, _cyy, _cx + _cw, _cyy + _ch, 12, merge_colour(global.TH.panel_edge, global.TH.accent, _a), 0.6 + 0.4 * _a, 1);
        ui_glow(_cx, _cyy, _cx + _cw, _cyy + _ch, 12, global.TH.accent, _a * 0.6);
        draw_circle_colour(_cx + 26, _cyy + 28, 14, global.TH.accent, global.TH.accent_dark, false);
        ui_text(_cx + 26, _cyy + 28, string(i + 1), c_white, fa_center, fa_middle, global.f_bold, 1);
        ui_text(_cx + 50, _cyy + 18, ui_text_fit(_titles[i], global.f_bold, _cw - 60), global.TH.text, fa_left, fa_top, global.f_bold, 1);
        ui_text_wrap(_cx + 16, _cyy + 52, _desc[i], global.TH.text_dim, _cw - 30, global.f_small, 1);
        if (_hot && ui_pressed)
        {
            ui_take_click();
            var _dest = [WS_SCREEN, WS_SPRITES, WS_ACTORS, WS_LOGIC, WS_SOUND, WS_BUILD];
            if (proj.game_type == 1) { _dest = [WS_MAP, WS_SPRITES, WS_ENEMIES, WS_WORLD, WS_SOUND, WS_BUILD]; }
            ws_set(_dest[i]);
        }
    }

    // ---------- settings ----------
    var _px = _split + 10;
    ui_panel(_px, _y1, _x2, _y2, "Game settings");
    var _fx = _px + 20;
    var _fw = _x2 - _px - 40;
    var _y = _y1 + 58;
    ui_heading(_fx, _y, "Game name");
    var _nm = ui_textfield("home_name", _fx, _y + 18, _fw, 32, proj.name, 32, "Game name|The name of your game. It is used for the saved file names too.");
    set_val(proj, "name", _nm, "name");
    _y += 64;
    ui_heading(_fx, _y, "Type of project");
    set_val(proj, "game_type", ui_dropdown("home_gametype", _fx, _y + 18, _fw, 32, global.GAME_TYPE_NAMES, proj.game_type, "Project type|Single screen games use actors and WHEN/DO rules. Map games use the scrolling engine with tiles, maps, spawners and enemy types (shoot-em-ups, platformers, cave diggers, mazes)."), "gametype");
    _y += 64;

    var _half = floor((_fw - 12) / 2);
    ui_heading(_fx, _y, "Lives at start");
    set_val(proj, "lives", ui_stepper("home_lives", _fx, _y + 18, _half, proj.lives, 0, 9, "Lives|How many lives the player starts with. Use the 'Lose a life' action in Logic to take them away."), "lives");
    ui_heading(_fx + _half + 12, _y, "Score / lives row");
    set_val(proj, "hud_row", ui_stepper("home_hudrow", _fx + _half + 12, _y + 18, _half, proj.hud_row, 0, 24, "Score row|Which text row (0 = top, 24 = bottom) shows the score and lives."), "hudrow");
    _y += 64;
    set_val(proj, "show_score", ui_toggle("home_showscore", _fx, _y, "Show score", proj.show_score, "Show score|Shows SCORE 0000 on the left of the score row."), "showscore");
    set_val(proj, "show_lives", ui_toggle("home_showlives", _fx + _half + 12, _y, "Show lives", proj.show_lives, "Show lives|Shows LIVES 3 on the right of the score row."), "showlives");
    _y += 40;
    ui_heading(_fx, _y, "Score colour");
    set_val(proj, "hud_colour", ui_colour_drop("home_hudcol", _fx, _y + 18, _half, 32, proj.hud_colour, "Score colour|The colour used for the score and lives text."), "hudcol");
    _y += 64;
    ui_heading(_fx, _y, "Game over message");
    set_val(proj, "over_text", ui_textfield("home_over", _fx, _y + 18, _fw, 32, proj.over_text, 40, "Game over message|Shown in the middle of the screen when a 'Game over' action happens. The player presses fire to play again."), "overtext");
    _y += 64;
    ui_heading(_fx, _y, "Win message");
    set_val(proj, "win_text", ui_textfield("home_win", _fx, _y + 18, _fw, 32, proj.win_text, 40, "Win message|Shown when a 'You win!' action happens."), "wintext");
    _y += 74;

    ui_heading(_fx, _y, "Display");
    var _si = 0;
    for (var sv = 1; sv < array_length(global.UI_SCALE_VALUES); sv++)
    {
        if (global.UI_SCALE_VALUES[sv] == ui_scale_pref) { _si = sv; }
    }
    var _nsi = ui_dropdown("home_scale", _fx, _y + 18, _half, 30, global.UI_SCALE_NAMES, _si, "Interface size|Makes everything bigger or smaller. Auto picks 200% on a 4K screen. Shortcuts: Ctrl + and Ctrl - (Ctrl 0 = auto).");
    if (_nsi != _si)
    {
        ui_scale_pref = global.UI_SCALE_VALUES[_nsi];
        settings_save();
    }
    var _fs = ui_toggle("home_fullscreen", _fx + _half + 12, _y + 22, "Start maximised", start_fullscreen, "Maximised window|Opens the studio as a normal window filling the screen, with its title bar and border. F11 switches to borderless full screen and back.");
    if (_fs != start_fullscreen)
    {
        start_fullscreen = _fs;
        settings_save();
        if (_fs) { window_maximise_bordered(); }
    }
    _y += 64;
    ui_heading(_fx, _y, "Studio");
    _y += 20;
    var _at = ui_toggle("home_autotut", _fx, _y, "Offer a tutorial on each new page", auto_tutorials, "Automatic tutorials|The first time you open each page its tutorial starts by itself. Turn this off once you know your way around.");
    if (_at != auto_tutorials)
    {
        auto_tutorials = _at;
        settings_save();
    }
    _y += 34;
    var _ho = ui_toggle("home_helpers", _fx, _y, "Hover helper lines and bubbles", helpers_on, "Hover helpers|Shows guide lines and a help bubble when you rest the mouse on something.");
    if (_ho != helpers_on)
    {
        helpers_on = _ho;
        settings_save();
    }
    _y += 34;
    if (ui_button("home_resettut", _fx, _y, 200, 30, "Reset page tutorials", "Reset tutorials|Makes every page offer its tutorial again the next time you visit it.", BTN_GHOST))
    {
        for (var w = 0; w < WS_COUNT; w++) { ws_seen[w] = false; }
        settings_save();
        toast("Page tutorials will show again", 0);
    }
}
