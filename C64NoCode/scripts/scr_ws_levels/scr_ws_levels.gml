/// C64 ENGINE - the Levels page (single-screen games, ported from ADAM's Levels page).
/// Left: switch levels on, the levels with a picture of their hills, Add / Remove.
/// Centre: the screen with the picked level's hills and its actors; drag to draw the ground,
/// right-drag to smooth it. Right: the seed and how the hills grow, the level's music, the hill
/// colours, the level goal and the screens (title, level card). The 6502 side is in scr_stages.

function ws_levels_draw(_x1, _y1, _x2, _y2)
{
    var _lw = 230;
    var _rw = 340;
    var _nl = array_length(proj.stages);

    // ---------------- the levels ----------------
    ui_panel(_x1, _y1, _x1 + _lw, _y2, "Levels (" + string(_nl) + " / " + string(STAGE_MAX) + ")");
    var _on = ui_toggle("lvl_on", _x1 + 16, _y1 + 54, "Levels and hills", proj.levels_on, "Levels|Turn on to make a game of up to 8 levels. Each level has its own hills, grown from a seed and shaped by hand, drawn over your Screen page. Reaching the level goal moves on to the next level.");
    if (_on != proj.levels_on)
    {
        undo_mark("lvlon" + string(current_time));
        proj.levels_on = _on;
        if (_on && array_length(proj.stages) == 0) { array_push(proj.stages, stage_new(1000)); }
        _nl = array_length(proj.stages);
    }
    var _ly = _y1 + 92;
    var _tc = proj.terrain_cols;
    for (var i = 0; i < _nl; i++)
    {
        var _ry = _ly + i * 44;
        if (_ry + 38 > _y2 - 96) { break; }
        var _id = "lvl_slot_" + string(i);
        var _hot = ui_register(_id, _x1 + 10, _ry, _x1 + _lw - 10, _ry + 38, "Level " + string(i + 1) + "|Click to edit this level's hills.");
        if (lvl_sel == i) { ui_rrect(_x1 + 10, _ry, _x1 + _lw - 10, _ry + 38, 9, global.TH.accent, global.TH.accent_dark, 0.9); }
        else if (_hot) { ui_rrect(_x1 + 10, _ry, _x1 + _lw - 10, _ry + 38, 9, global.TH.btn_hot_top, global.TH.btn_hot_bot, 0.8); }
        // a little picture of the hills
        var _hh = proj.stages[i].heights;
        px_rect(_x1 + 18, _ry + 5, 80, 28, c64col(proj.background));
        for (var t = 0; t < 40; t++)
        {
            if (_hh[t] >= 200) { continue; }
            var _hy = (_hh[t] / 200) * 28;
            px_rect(_x1 + 18 + t * 2, _ry + 5 + _hy, 2, 28 - _hy, c64col(_tc[1]));
        }
        ui_text(_x1 + 108, _ry + 12, "Level " + string(i + 1), global.TH.text, fa_left, fa_middle, global.f_bold, 1);
        var _en = 0;
        for (var a = 0; a < min(8, array_length(proj.actors)); a++)
        {
            if (proj.actors[a].from_level <= i + 1) { _en += 1; }
        }
        ui_text(_x1 + 108, _ry + 28, (_en == 1) ? "1 actor" : string(_en) + " actors", (lvl_sel == i) ? global.TH.text : global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
        if (_hot && ui_pressed)
        {
            lvl_sel = i;
            ui_take_click();
        }
    }
    lvl_sel = clamp(lvl_sel, 0, max(0, _nl - 1));
    var _by = _y2 - 88;
    var _bw = _lw - 32;
    if (ui_button("lvl_add", _x1 + 16, _by, _bw, 34, "Add level", "Add level|Adds a level after the last one, with new hills from the next seed (a little hillier).", (_nl >= STAGE_MAX) ? BTN_GHOST : BTN_ACCENT))
    {
        if (_nl < STAGE_MAX)
        {
            undo_mark("lvladd" + string(current_time));
            var _new = stage_new(1000 + _nl * 37);
            if (_nl > 0)
            {
                _new.hilly = min(150, proj.stages[_nl - 1].hilly + 8);
                _new.base = proj.stages[_nl - 1].base;
                _new.heights = stage_terrain(_new.seed, _new.hilly, _new.base);
            }
            array_push(proj.stages, _new);
            proj.levels_on = true;
            lvl_sel = _nl;
        }
        else { toast(string(STAGE_MAX) + " levels is the most", 1); }
    }
    if (ui_button("lvl_del", _x1 + 16, _by + 42, _bw, 34, "Remove level", "Remove level|Deletes the picked level. You can Undo this.", BTN_DANGER))
    {
        if (_nl > 1)
        {
            undo_mark("lvldel" + string(current_time));
            array_delete(proj.stages, lvl_sel, 1);
            lvl_sel = max(0, lvl_sel - 1);
        }
        else { toast("Keep at least one level - or switch levels off", 1); }
    }

    // ---------------- the screen with the hills ----------------
    var _cx1 = _x1 + _lw + 12;
    var _cx2 = _x2 - _rw - 12;
    ui_panel(_cx1, _y1, _cx2, _y2, "");
    var _sc = max(1, floor(min((_cx2 - _cx1 - 32) / 320, (_y2 - _y1 - 80) / 200) * 2) / 2);
    var _fw = 320 * _sc;
    var _fh = 200 * _sc;
    var _fx = floor((_cx1 + _cx2 - _fw) / 2);
    var _fy = floor((_y1 + _y2 - _fh) / 2) - 10;
    ui_rrect(_fx - 10, _fy - 10, _fx + _fw + 10, _fy + _fh + 10, 8, c64col(proj.border), c64col(proj.border), 1);
    hud_preview_draw(_fx, _fy, _sc);
    // the actors on this level, the walkers standing on the ground
    var _gh = undefined;
    if (proj.levels_on && _nl > 0) { _gh = proj.stages[lvl_sel].heights; }
    for (var d = min(8, array_length(proj.actors)) - 1; d >= 0; d--)
    {
        var _ac = proj.actors[d];
        if (proj.levels_on && _ac.from_level > lvl_sel + 1) { continue; }
        var _ax = clamp(_ac.x, CG_XMIN, CG_XMAX) - 24;
        var _ay = clamp(_ac.y, CG_YMIN, CG_YMAX) - 50;
        if (role_on_ground(_ac.role))
        {
            var _col = clamp((_ax + 12) div 8, 0, 39);
            var _g = is_undefined(_gh) ? 200 : min(200, _gh[_col]);
            _ay = _g - sprite_feet(_ac.sprite) - 1;
        }
        draw_sprite_c64(clamp(_ac.sprite, 0, SPR_COUNT - 1), _fx + _ax * _sc, _fy + _ay * _sc, _sc, _ac.colour, _ac.visible ? 1 : 0.4);
    }
    if (!proj.levels_on || _nl == 0)
    {
        ui_text_wrap(_fx + 20, _fy + 20, "Turn on 'Levels and hills' to give your game up to 8 levels, each with its own ground to walk on.", c_white, _fw - 40, global.f_body, 1);
        levels_side_panel(_x2 - _rw, _y1, _x2, _y2);
        return;
    }
    var _lev = proj.stages[lvl_sel];
    // shape the ground by drawing the hill line
    var _hot2 = ui_register("lvl_canvas", _fx, _fy, _fx + _fw, _fy + _fh, "Shape the hills|Drag with the left button to draw where the ground is. Right-drag smooths it. Generate on the right makes fresh hills from the seed.");
    if (_hot2 && (ui_pressed || ui_rpressed))
    {
        undo_mark("lvldraw" + string(current_time));
        lvl_drawing = true;
        lvl_last_x = -1;
        ui_take_click();
    }
    if (lvl_drawing)
    {
        if (ui_held || ui_rheld)
        {
            var _mx = clamp(floor((ui_mx - _fx) / _sc / 8), 0, 39);
            var _my = clamp(floor((ui_my - _fy) / _sc), STAGE_TOP, STAGE_LOW);
            var _a0 = (lvl_last_x >= 0) ? min(_mx, lvl_last_x) : _mx;
            var _b0 = (lvl_last_x >= 0) ? max(_mx, lvl_last_x) : _mx;
            for (var c = max(0, _a0 - 1); c <= min(39, _b0 + 1); c++)
            {
                if (ui_held)
                {
                    var _t = 1;
                    if (c < _a0 || c > _b0) { _t = 0.5; }
                    _lev.heights[c] = round(lerp(min(_lev.heights[c], STAGE_LOW), _my, _t));
                }
                else
                {
                    var _l = _lev.heights[max(0, c - 1)];
                    var _r = _lev.heights[min(39, c + 1)];
                    _lev.heights[c] = round((_l + _lev.heights[c] * 2 + _r) / 4);
                }
            }
            lvl_last_x = _mx;
            proj_dirty = true;
        }
        else { lvl_drawing = false; }
    }
    ui_text((_cx1 + _cx2) / 2, _fy + _fh + 26, "Level " + string(lvl_sel + 1) + "  -  drag to draw the ground, right-drag to smooth it", global.TH.text_faint, fa_center, fa_middle, global.f_small, 1);

    levels_side_panel(_x2 - _rw, _y1, _x2, _y2);
}

function levels_side_panel(_px, _y1, _x2, _y2)
{
    ui_panel(_px, _y1, _x2, _y2, "Level settings");
    var _fx = _px + 20;
    var _fw = _x2 - _px - 40;
    var _half = floor((_fw - 12) / 2);
    var _y = _y1 + 56;
    var _nl = array_length(proj.stages);
    var _endnote = "After the last level the Win message (Home page) shows - or the You win bitmap (Bitmaps page).";
    draw_set_font(global.f_small);
    var _content = 10 + 174 + 116 + 226 + ceil(ui_sh_ext(_endnote, _fw)) + 12;
    if (proj.levels_on && _nl > 0) { _content += 256; }
    var _off = ui_scroll_begin("lvl_side", _px + 4, _y1 + 46, _x2 - 4, _y2 - 6, _content);
    _y -= _off;
    if (proj.levels_on && _nl > 0)
    {
        var _lev = proj.stages[lvl_sel];
        ui_heading(_fx, _y, "Level " + string(lvl_sel + 1) + " hills");
        _y += 20;
        ui_heading(_fx, _y, "Seed");
        var _ns = ui_stepper("lvl_seed", _fx, _y + 18, _half, _lev.seed, 1, 99999, "Seed|The number the hills grow from. The same seed always gives the same hills. Change it, then press Generate.");
        if (_ns != _lev.seed)
        {
            undo_mark("lvlseed");
            _lev.seed = _ns;
        }
        if (ui_button("lvl_gen", _fx + _half + 12, _y + 18, _half, 30, "Generate", "Generate hills|Replaces this level's ground with fresh hills from the seed, hilliness and height. You can then reshape them by drawing.", BTN_ACCENT))
        {
            undo_mark("lvlgen" + string(current_time));
            _lev.heights = stage_terrain(_lev.seed, _lev.hilly, _lev.base);
        }
        _y += 60;
        ui_heading(_fx, _y, "Hilliness  " + string(_lev.hilly) + "%");
        set_val(_lev, "hilly", round(ui_slider("lvl_hilly", _fx, _y + 18, _fw, _lev.hilly, 0, 150, "Hilliness|How steep and tall the hills are when you press Generate.")), "lvlhilly");
        _y += 52;
        ui_heading(_fx, _y, "Ground height  " + string(200 - _lev.base));
        set_val(_lev, "base", round(ui_slider("lvl_base", _fx, _y + 18, _fw, 290 - _lev.base, 100, 190, "Ground height|Where the middle of the hills sits when you press Generate.")) * -1 + 290, "lvlbase");
        _y += 62;
        ui_heading(_fx, _y, "Level " + string(lvl_sel + 1) + " music");
        var _mopts = music_song_options();
        var _mcur = clamp(proj.level_song[lvl_sel] + 1, 0, array_length(_mopts) - 1);
        var _mnew = ui_dropdown("lvl_music", _fx, _y + 18, _fw, 30, _mopts, _mcur, "Level music|The song that starts when this level begins (the same song as the level before carries on). Make songs on the Music page.");
        if (_mnew != _mcur)
        {
            undo_mark("lvlmusic");
            proj.level_song[lvl_sel] = _mnew - 1;
        }
        _y += 62;
    }

    ui_heading(_fx, _y, "Hill colours (all levels)");
    _y += 18;
    var _tn = ["Edge", "Grass", "Soil", "Specks"];
    var _th = ["Edge colour|The top of the ground: a block filled to the exact line you drew.", "Grass colour|The row under the edge.", "Soil colour|Everything below the grass.", "Speck colour|Stones scattered through the soil."];
    for (var k = 0; k < 4; k++)
    {
        var _cy = _y + k * 38;
        ui_text(_fx, _cy + 15, _tn[k], global.TH.text_faint, fa_left, fa_middle, global.f_small, 1);
        var _nc = ui_colour_drop("lvl_col_" + string(k), _fx + 64, _cy, _fw - 64, 30, proj.terrain_cols[k], _th[k]);
        if (_nc != proj.terrain_cols[k])
        {
            undo_mark("lvlcol" + string(k));
            proj.terrain_cols[k] = _nc;
        }
    }
    _y += 156;

    ui_heading(_fx, _y, "Level goal");
    _y += 20;
    set_val(proj, "goal_on", ui_toggle("lvl_goal_on", _fx, _y, "Count things to collect", proj.goal_on, "Goal counter|Shows a counter like GEMS 00/10 on the HUD. The Logic action 'Count towards the level goal' adds one; reaching the target finishes the level (or wins on the last one)."), "goalon");
    _y += 34;
    ui_heading(_fx, _y, "Label");
    set_val(proj, "goal_label", string_upper(ui_textfield("lvl_goal_label", _fx, _y + 18, _half, 30, proj.goal_label, 6, "Goal label|The word shown before the counter, e.g. GEMS, STARS or KEYS.")), "goallabel");
    ui_heading(_fx + _half + 12, _y, "How many per level");
    set_val(proj, "goal", ui_stepper("lvl_goal", _fx + _half + 12, _y + 18, _half, proj.goal, 1, 99, "Goal|How many to collect on each level."), "goal");
    _y += 62;

    ui_heading(_fx, _y, "Screens");
    _y += 20;
    set_val(proj, "title_on", ui_toggle("lvl_title_on", _fx, _y, "Title screen", proj.title_on, "Title screen|Shows your title in big letters before the game. The player presses fire to start."), "titleon");
    _y += 34;
    ui_heading(_fx, _y, "Title (big letters, up to 10)");
    set_val(proj, "title1", string_upper(ui_textfield("lvl_title1", _fx, _y + 18, _fw, 30, proj.title1, 10, "Title|Up to 10 letters, each made of 4 x 4 of the C64's quarter-block characters.")), "title1");
    _y += 56;
    ui_heading(_fx, _y, "Line under the title");
    set_val(proj, "title2", string_upper(ui_textfield("lvl_title2", _fx, _y + 18, _fw, 30, proj.title2, 40, "Subtitle|A line under the title, e.g. PRESS FIRE TO START.")), "title2");
    _y += 56;
    ui_heading(_fx, _y, "Level card word");
    set_val(proj, "lev_text", string_upper(ui_textfield("lvl_levtxt", _fx, _y + 18, _half, 30, proj.lev_text, 10, "Level card|Between levels a card shows this word and the level number, e.g. LEVEL 3. The player presses fire to go on.")), "levtxt");
    _y += 60;
    ui_text_wrap(_fx, _y, _endnote, global.TH.text_faint, _fw, global.f_small, 1);
    ui_scroll_end("lvl_side", _px + 4, _y1 + 46, _x2 - 4, _y2 - 6, _content);
}
