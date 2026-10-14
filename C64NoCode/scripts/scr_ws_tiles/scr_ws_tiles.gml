/// C64 ENGINE - the Tiles page (ported from ADAM's Tiles page).
/// Left: the tile set as a grid of pictures, New / Remove, and Dig and place for the game.
/// Centre: the Tile set tab draws a tile's pixels straight onto its 4 characters (a character
/// that other tiles share is copied first, so they don't change), the Characters tab picks
/// which character goes in each corner. Right: what the tile does - solid, collect, dig time,
/// points, the goal, its sound and the tile it leaves behind.

// ---------------------------------------------------------------------------
// The model
// ---------------------------------------------------------------------------

/// A tile from a loaded file, made safe
function tile_from_loaded(_raw)
{
    var _t = struct_overlay(tile_new("Tile"), _raw);
    if (!is_string(_t.name)) { _t.name = "Tile"; }
    if (!is_array(_t.c) || array_length(_t.c) != 4) { _t.c = [32, 32, 32, 32]; }
    for (var q = 0; q < 4; q++) { _t.c[q] = is_numeric(_t.c[q]) ? clamp(floor(_t.c[q]), 0, 255) : 32; }
    if (is_bool(_t.goal)) { _t.goal = _t.goal ? 1 : 0; }
    _t.goal = is_numeric(_t.goal) ? clamp(floor(_t.goal), -1, 1) : -1;
    _t.sound = is_numeric(_t.sound) ? clamp(floor(_t.sound), -1, 255) : -1;
    _t.becomes = is_numeric(_t.becomes) ? clamp(floor(_t.becomes), 0, 63) : 0;
    _t.hard = is_numeric(_t.hard) ? clamp(floor(_t.hard), 1, 250) : 12;
    return _t;
}

/// Does this game dig and place (a platform or top-down map game with it switched on)?
function tile_dig_on(_p)
{
    var _e = _p.eng;
    return (_p.game_type == 1 && _e.dig_place && (_e.kind == KIND_PLAT || _e.kind == KIND_TOP));
}

/// Does taking this tile count towards the level goal?
function tile_counts(_t)
{
    if (_t.goal < 0) { return (_t.attr & TA_COLLECT) != 0; }
    return (_t.goal == 1);
}

/// The sound a tile makes when it is collected or dug (255 = none)
function tile_sfx(_p, _t)
{
    if (_t.sound >= 0 && _t.sound < array_length(_p.sfx)) { return _t.sound; }
    if (_t.sound < 0 && (_t.attr & TA_COLLECT) != 0) { return _p.eng.sfx_collect; }
    return 255;
}

/// The engine's tables for what tiles do when taken: tbecome, tsfx, tflag (1 = counts for
/// the goal), and for Dig and place thard (dig time) and tname (4 letters for the HUD)
function tile_emit_tables(L, _p, _nt, _dig)
{
    var _be = array_create(64, 0);
    var _sf = array_create(64, 255);
    var _fl = array_create(64, 0);
    var _hd = array_create(64, 12);
    var _nm = array_create(256, 32);
    for (var t = 0; t < _nt; t++)
    {
        var _t = _p.tiles[t];
        _be[t] = (_t.becomes < _nt) ? _t.becomes : 0;
        _sf[t] = tile_sfx(_p, _t);
        _fl[t] = tile_counts(_t) ? 1 : 0;
        _hd[t] = clamp(_t.hard, 1, 250);
        var _n = string_upper(string_copy(_t.name + "    ", 1, 4));
        for (var k = 0; k < 4; k++) { _nm[t * 4 + k] = scr_code_from_char(string_char_at(_n, k + 1)) & 63; }
    }
    array_push(L, "tbecome:");
    eng_emit_bytes(L, _be);
    array_push(L, "tsfx:");
    eng_emit_bytes(L, _sf);
    array_push(L, "tflag:");
    eng_emit_bytes(L, _fl);
    if (_dig)
    {
        array_push(L, "thard:");
        eng_emit_bytes(L, _hd);
        array_push(L, "tname:");
        eng_emit_bytes(L, _nm);
    }
}

/// How many tile corners use character _code
function tile_char_users(_code)
{
    var _n = 0;
    for (var t = 0; t < array_length(proj.tiles); t++)
    {
        for (var q = 0; q < 4; q++)
        {
            if (proj.tiles[t].c[q] == _code) { _n += 1; }
        }
    }
    return _n;
}

/// A character no tile uses (letters 0-63 stay letters), or -1
function tile_free_char()
{
    var _used = array_create(256, false);
    for (var t = 0; t < array_length(proj.tiles); t++)
    {
        for (var q = 0; q < 4; q++) { _used[proj.tiles[t].c[q]] = true; }
    }
    for (var c = 128; c < 256; c++)
    {
        if (!_used[c] && c != 160) { return c; }
    }
    for (var c2 = 64; c2 < 128; c2++)
    {
        if (!_used[c2]) { return c2; }
    }
    return -1;
}

/// Gives corner _q of tile _t a character of its own (a copy) when it shares one or uses a
/// letter, so drawing on it changes only this tile. Returns the character, or -1 if none is free.
function tile_own_char(_t, _q)
{
    var _c = _t.c[_q];
    if (_c >= 64 && _c != 160 && tile_char_users(_c) == 1) { return _c; }
    var _n = tile_free_char();
    if (_n < 0) { return -1; }
    for (var r = 0; r < 8; r++) { proj.charset[_n * 8 + r] = proj.charset[_c * 8 + r]; }
    _t.c[_q] = _n;
    charset_dirty = true;
    atlas_dirty = true;
    return _n;
}

/// Is tile _t drawn in multicolour?
function tile_is_mc(_t)
{
    return (proj.eng.mc && _t.mc);
}

/// Pixel (_px, _py) of a tile: hi-res 16 x 16 (0 / 1), multicolour 8 x 16 (0..3)
function tile_pixel(_t, _px, _py)
{
    var _mc = tile_is_mc(_t);
    var _w = _mc ? 8 : 16;
    var _q = (_py div 8) * 2 + (_px div (_w / 2));
    var _b = proj.charset[_t.c[_q] * 8 + (_py mod 8)];
    if (_mc) { return (_b >> (6 - (_px mod 4) * 2)) & 3; }
    return (_b >> (7 - (_px mod 8))) & 1;
}

/// Sets a pixel (giving its corner its own character first). Returns false if no character is free.
function tile_set_pixel(_t, _px, _py, _v)
{
    if (tile_pixel(_t, _px, _py) == _v) { return true; }
    var _mc = tile_is_mc(_t);
    var _w = _mc ? 8 : 16;
    var _q = (_py div 8) * 2 + (_px div (_w / 2));
    var _c = tile_own_char(_t, _q);
    if (_c < 0) { return false; }
    var _i = _c * 8 + (_py mod 8);
    var _b = proj.charset[_i];
    if (_mc)
    {
        var _sh = 6 - (_px mod 4) * 2;
        _b = (_b & ~(3 << _sh) & 255) | ((_v & 3) << _sh);
    }
    else
    {
        var _m = 1 << (7 - (_px mod 8));
        _b = (_v != 0) ? (_b | _m) : (_b & ~_m & 255);
    }
    proj.charset[_i] = _b;
    charset_dirty = true;
    atlas_dirty = true;
    proj_dirty = true;
    return true;
}

/// The colour of pixel value _v of tile _t
function tile_value_col(_t, _v)
{
    if (tile_is_mc(_t))
    {
        var _cols = [proj.eng.bg, proj.eng.mc1, proj.eng.mc2, _t.col & 7];
        return _cols[_v];
    }
    return (_v != 0) ? _t.col : proj.eng.bg;
}

// ---------------------------------------------------------------------------
// The page
// ---------------------------------------------------------------------------

/// The grid of tiles to pick from, scrolling in the box _y .. _y2. Returns the bottom y.
function tiles_grid(_x, _y, _w, _y2)
{
    var _cols = 5;
    var _cell = floor((_w - (_cols - 1) * 6) / _cols);
    var _n = array_length(proj.tiles);
    var _content = ceil(_n / _cols) * (_cell + 6) + 4;
    var _boxh = min(_content, _y2 - _y);
    if (_content > _boxh)
    {
        _cell = floor((_w - 14 - (_cols - 1) * 6) / _cols);
        _content = ceil(_n / _cols) * (_cell + 6) + 4;
    }
    var _off = ui_scroll_begin("tile_gridscroll", _x - 4, _y - 2, _x + _w + 4, _y + _boxh, _content);
    for (var i = 0; i < _n; i++)
    {
        var _gx = _x + (i mod _cols) * (_cell + 6);
        var _gy = _y + (i div _cols) * (_cell + 6) - _off;
        if (_gy < _y - _cell || _gy > _y + _boxh) { continue; }
        var _t = proj.tiles[i];
        var _att = "";
        for (var a = 0; a < 8; a++)
        {
            if ((_t.attr & (1 << a)) != 0) { _att += ((_att == "") ? "" : ", ") + string_lower(global.ATTR_NAMES[a]); }
        }
        if (_att == "") { _att = "background"; }
        var _hot = ui_register("tile_pick_" + string(i), _gx, _gy, _gx + _cell, _gy + _cell, string(i) + ": " + _t.name + "|Click to pick this tile (" + _att + ").");
        ui_rrect(_gx, _gy, _gx + _cell, _gy + _cell, 6, c64col(proj.eng.bg), c64col(proj.eng.bg), 1);
        draw_tile_img(i, _gx + 3, _gy + 3, _cell - 6);
        if (tile_sel == i) { ui_rrect_line(_gx - 2, _gy - 2, _gx + _cell + 2, _gy + _cell + 2, 8, global.TH.accent, 1, 2); }
        else if (_hot) { ui_rrect_line(_gx - 1, _gy - 1, _gx + _cell + 1, _gy + _cell + 1, 7, global.TH.accent, 0.6, 1); }
        if (_hot && ui_pressed)
        {
            ui_take_click();
            tile_sel = i;
        }
    }
    ui_scroll_end("tile_gridscroll", _x - 4, _y - 2, _x + _w + 4, _y + _boxh, _content);
    return _y + _boxh + 4;
}

function ws_tiles_draw(_x1, _y1, _x2, _y2)
{
    var _lw = 260;
    var _rw = 310;
    var _nt = array_length(proj.tiles);
    tile_sel = clamp(tile_sel, 0, _nt - 1);
    var _cx1 = _x1 + _lw + 12;
    var _cx2 = _x2 - _rw - 12;
    var _e = proj.eng;

    // ---------------- left: the tiles, and Dig and place ----------------
    ui_panel(_x1, _y1, _x1 + _lw, _y2, "Tiles (" + string(_nt) + " / 64)");
    var _ly = tiles_grid(_x1 + 16, _y1 + 54, _lw - 32, max(_y1 + 160, _y2 - 250)) + 10;
    var _bw = floor((_lw - 40) / 2);
    if (ui_button("tile_add", _x1 + 16, _ly, _bw, 30, "New tile", "New tile|Adds a tile (up to 64), starting as a copy of the one picked - same characters, so draw on it to make it different (it gets characters of its own as you draw).", BTN_NORMAL) && _nt < 64)
    {
        undo_mark("tadd" + string(current_time));
        var _nw = (tile_sel == 0) ? tile_new("Tile " + string(_nt)) : tile_from_loaded(json_parse(json_stringify(proj.tiles[tile_sel])));
        if (tile_sel > 0) { _nw.name = string_copy(_nw.name, 1, 16) + " 2"; }
        array_push(proj.tiles, _nw);
        tile_sel = _nt;
        atlas_dirty = true;
    }
    var _dst = (tile_sel == 0) ? BTN_GHOST : BTN_DANGER;
    if (ui_button("tile_del", _x1 + 24 + _bw, _ly, _lw - 40 - _bw, 30, "Remove", "Remove tile|Takes the picked tile out; maps that used it get the empty tile 0 instead. Tile 0, the empty background, stays. You can Undo this.", _dst) && tile_sel > 0)
    {
        undo_mark("tdel" + string(current_time));
        tile_remove(tile_sel);
        tile_sel -= 1;
    }
    _ly += 46;
    ui_heading(_x1 + 16, _ly, "Dig and place");
    _ly += 20;
    if (_e.kind == KIND_PLAT || _e.kind == KIND_TOP)
    {
        set_val(_e, "dig_place", ui_toggle("tile_dig", _x1 + 16, _ly, "Dig and place", _e.dig_place, "Dig and place|The player digs: fire + a direction digs the tile that way (each Diggable tile says how long it takes), fire on its own puts the last tile dug back down in front. Up jumps, and fire no longer shoots. The HUD shows the tile carried and how many."), "tiledig");
        _ly += 32;
        var _dt = _e.dig_place ? "Fire + a direction digs Diggable tiles, fire on its own puts the tile carried down. Up jumps; no shooting." : "Switch it on to dig into the world and build with what you dig, Terraria style.";
        ui_text_wrap(_x1 + 16, _ly, _dt, global.TH.text_faint, _lw - 32, global.f_small, 1);
    }
    else
    {
        var _kt = (_e.kind == KIND_CAVE) ? "A cave game digs as the player moves: walking into a Diggable tile digs it out." : "Digging and placing tiles works in platform and top-down games (World page: kind of game).";
        ui_text_wrap(_x1 + 16, _ly, _kt, global.TH.text_faint, _lw - 32, global.f_small, 1);
    }

    // ---------------- centre: Tile set or Characters ----------------
    ui_panel(_cx1, _y1, _cx2, _y2, "");
    var _tabs = ["Tile set", "Characters", "Tools"];
    var _thelp = ["Tile set|Draw the tile's pixels: it is 2 x 2 characters, and a character other tiles share is copied first so they don't change.", "Characters|Which character goes in each corner of the tile - pick from all 256. Edit their shapes here on the Tile set tab, or on the Charset page.", "Tools|The player's tools: space opens a menu in the game to pick one (a pickaxe, a hammer, a ladder...) and fire uses it."];
    for (var tb = 0; tb < 3; tb++)
    {
        if (ui_tab("tile_tab_" + string(tb), _cx1 + 16 + tb * 136, _y1 + 12, 130, 30, _tabs[tb], tile_page == tb, _thelp[tb])) { tile_page = tb; }
    }
    if (tile_page == 2) { tiles_tools_editor(_cx1, _y1 + 50, _cx2, _y2); }
    else if (tile_page == 1) { tiles_chars_editor(_cx1, _y1 + 50, _cx2, _y2); }
    else { tiles_set_editor(_cx1, _y1 + 50, _cx2, _y2); }

    // ---------------- right: the picked tile ----------------
    var _rx = _x2 - _rw;
    var _t = proj.tiles[tile_sel];
    ui_panel(_rx, _y1, _x2, _y2, "Tile " + string(tile_sel) + ": " + ui_text_fit(_t.name, global.f_bold, _rw - 140));
    var _fx = _rx + 20;
    var _fw = _rw - 40;
    var _half = floor((_fw - 12) / 2);
    var _y = _y1 + 52;
    ui_heading(_fx, _y, "Name");
    ui_heading(_fx + _half + 12, _y, "Colour");
    set_val(_t, "name", ui_textfield("tile_name", _fx, _y + 18, _half, 30, _t.name, 20, "Name|Its first 4 letters show on the HUD for the tile the player carries."), "tname");
    if (set_val(_t, "col", ui_colour_drop("tile_col", _fx + _half + 12, _y + 18, _half, 30, _t.col, "Colour|The colour of the tile's characters (a multicolour tile uses colours 0-7 here, with the World page's two shared colours)."), "tcol")) { atlas_dirty = true; }
    _y += 58;
    if (_e.mc)
    {
        if (set_val(_t, "mc", ui_toggle("tile_mc", _fx, _y, "Multicolour tile", _t.mc, "Multicolour|Draw this tile in multicolour: pixels twice as wide, in 4 colours."), "tmc")) { atlas_dirty = true; }
        _y += 32;
    }
    ui_heading(_fx, _y, "What it does");
    _y += 20;
    for (var ab = 0; ab < 8; ab++)
    {
        var _on = (_t.attr & (1 << ab)) != 0;
        var _nv = ui_toggle("tile_attr" + string(ab), _fx + (ab mod 2) * (_half + 12), _y + (ab div 2) * 30, global.ATTR_NAMES[ab], _on, global.ATTR_HELP[ab]);
        if (_nv != _on)
        {
            undo_mark("tattr" + string(current_time));
            if (_nv) { _t.attr = _t.attr | (1 << ab); }
            else { _t.attr = _t.attr & ~(1 << ab); }
        }
    }
    _y += 4 * 30 + 6;
    if (tile_sel == 0)
    {
        ui_text_wrap(_fx, _y, "Tile 0 is the empty background: it fills the map, and is what collected and dug tiles leave behind unless they say otherwise.", global.TH.text_faint, _fw, global.f_small, 1);
        return;
    }
    var _taken = (_t.attr & (TA_COLLECT | TA_DIG)) != 0;
    var _cnt = tile_counts(_t);
    var _ng = ui_toggle("tile_goal", _fx, _y, "Counts towards the goal", _cnt, "Counts towards the level goal|Taking it - collecting or digging it - adds one to the level's goal counter (Map page: the goal). Collectables count unless you switch this off.");
    if (_ng != _cnt) { set_val(_t, "goal", _ng ? 1 : 0, "tgoal"); }
    _y += 34;
    ui_heading(_fx, _y, "Points");
    ui_heading(_fx + _half + 12, _y, "Dig time (50ths)");
    set_val(_t, "score", ui_stepper("tile_score", _fx, _y + 18, _half, _t.score, 0, 99, "Points|Added to the score when the player collects or digs it."), "tscore");
    set_val(_t, "hard", ui_stepper("tile_hard", _fx + _half + 12, _y + 18, _half, _t.hard, 1, 250, "Dig time|With Dig and place: how long fire has to be held to dig it, in 50ths of a second - 6 is sand, 25 stone, 60 a strong wall."), "thard");
    _y += 58;
    ui_heading(_fx, _y, "Sound when taken");
    var _sn = ["Automatic"];
    for (var s = 0; s < array_length(proj.sfx); s++) { array_push(_sn, string(s + 1) + ": " + proj.sfx[s].name); }
    array_push(_sn, "(no sound)");
    var _si = (_t.sound < 0) ? 0 : ((_t.sound >= array_length(proj.sfx)) ? array_length(_sn) - 1 : _t.sound + 1);
    var _nsi = ui_dropdown("tile_snd", _fx, _y + 18, _fw, 30, _sn, _si, "Sound|Plays when it is collected or dug. Automatic: collectables play the World page's Collect sound, other tiles none.");
    if (_nsi != _si) { set_val(_t, "sound", (_nsi == 0) ? -1 : ((_nsi == array_length(_sn) - 1) ? 255 : _nsi - 1), "tsnd"); }
    _y += 58;
    ui_heading(_fx, _y, "Leaves behind");
    var _tn = [];
    for (var k = 0; k < _nt; k++) { array_push(_tn, string(k) + ": " + proj.tiles[k].name); }
    set_val(_t, "becomes", ui_dropdown("tile_bec", _fx, _y + 18, _fw, 30, _tn, clamp(_t.becomes, 0, _nt - 1), "Leaves behind|What is left when it is collected or dug: the empty tile 0, or a background tile like a dark cave wall."), "tbec");
    _y += 58;
    if (!_taken) { ui_text_wrap(_fx, _y, "Points, the goal, the sound and what it leaves behind matter once it is Collect or Diggable.", global.TH.text_faint, _fw, global.f_small, 1); }
}

/// The Tile set tab: the tile's 16 x 16 pixels (8 x 16 in multicolour), drawn onto its characters
function tiles_set_editor(_x1, _y1, _x2, _y2)
{
    var _t = proj.tiles[tile_sel];
    var _mc = tile_is_mc(_t);
    var _pw = _mc ? 8 : 16;
    var _avail = min(_x2 - _x1 - 260, _y2 - _y1 - 130);
    var _ps = max(8, floor(_avail / 16));
    var _gw = _ps * 16;
    var _gx = _x1 + 24;
    var _gy = _y1 + 14;
    var _cw = _ps * (16 / _pw);              // a multicolour pixel is two wide
    ui_rrect(_gx - 8, _gy - 8, _gx + _gw + 8, _gy + _gw + 8, 10, c_black, c_black, 0.35);
    for (var _py = 0; _py < 16; _py++)
    {
        for (var _px = 0; _px < _pw; _px++)
        {
            var _c = c64col(tile_value_col(_t, tile_pixel(_t, _px, _py)));
            draw_rectangle_colour(_gx + _px * _cw, _gy + _py * _ps, _gx + (_px + 1) * _cw - 1, _gy + (_py + 1) * _ps - 1, _c, _c, _c, _c, false);
        }
    }
    draw_set_alpha(0.12);
    for (var gl = 0; gl <= _pw; gl++) { draw_line_colour(_gx + gl * _cw, _gy, _gx + gl * _cw, _gy + _gw, c_white, c_white); }
    for (var gl2 = 0; gl2 <= 16; gl2++) { draw_line_colour(_gx, _gy + gl2 * _ps, _gx + _gw, _gy + gl2 * _ps, c_white, c_white); }
    draw_set_alpha(0.55);
    draw_line_colour(_gx + _gw / 2, _gy, _gx + _gw / 2, _gy + _gw, c_white, c_white);
    draw_line_colour(_gx, _gy + _gw / 2, _gx + _gw, _gy + _gw / 2, c_white, c_white);
    draw_set_alpha(1);
    for (var q = 0; q < 4; q++)
    {
        var _sh = (tile_char_users(_t.c[q]) > 1 || _t.c[q] < 64) ? " shared" : "";
        ui_text(_gx + (q mod 2) * _gw / 2 + 4, _gy + (q div 2) * _gw / 2 + 2, string(_t.c[q]) + _sh, c_white, fa_left, fa_top, global.f_small, 0.6);
    }
    var _hot = ui_register("tile_canvas", _gx, _gy, _gx + _gw - 1, _gy + _gw - 1, "Tile|Left-click draws with the colour picked, right-click with the background. A tile is 2 x 2 characters: drawing on one another tile shares (or a letter) copies it first, so only this tile changes.");
    if (_hot && tile_sel > 0)
    {
        var _hx = clamp(floor((ui_mx - _gx) / _cw), 0, _pw - 1);
        var _hy = clamp(floor((ui_my - _gy) / _ps), 0, 15);
        draw_rectangle_colour(_gx + _hx * _cw, _gy + _hy * _ps, _gx + (_hx + 1) * _cw - 1, _gy + (_hy + 1) * _ps - 1, c_white, c_white, c_white, c_white, true);
        if (ui_pressed || ui_rpressed)
        {
            undo_mark("tiledraw" + string(current_time));
            tile_drawing = true;
            ui_take_click();
        }
        if (tile_drawing)
        {
            var _v = -1;
            if (ui_held) { _v = _mc ? tile_pen_mc : 1; }
            if (ui_rheld) { _v = 0; }
            if (_v >= 0 && !tile_set_pixel(_t, _hx, _hy, _v))
            {
                toast("No free characters left to give this tile its own - free some on the Characters tab.", 1);
                tile_drawing = false;
            }
        }
    }
    if (!ui_held && !ui_rheld) { tile_drawing = false; }
    if (tile_sel == 0) { ui_text(_gx + _gw / 2, _gy + _gw + 24, "Tile 0 is the empty background", global.TH.text_dim, fa_center, fa_middle, global.f_body, 1); }

    // the colours to draw with, whole-tile buttons, and the tile at its real size
    var _rx = _gx + _gw + 32;
    var _rw = _x2 - 20 - _rx;
    var _y = _y1 + 8;
    ui_heading(_rx, _y, "Draw with");
    _y += 20;
    if (_mc)
    {
        var _nm = ["Background", "Shared 1", "Shared 2", "Tile colour"];
        for (var v = 0; v < 4; v++)
        {
            var _vc = c64col(tile_value_col(_t, v));
            var _by = _y + v * 34;
            var _h2 = ui_register("tile_pen" + string(v), _rx, _by, _rx + _rw, _by + 28, _nm[v] + "|" + ((v == 1 || v == 2) ? "Shared by every multicolour character: set on the World page." : "Draw with this colour."));
            if (tile_pen_mc == v) { ui_rrect(_rx - 4, _by - 3, _rx + _rw, _by + 31, 7, global.TH.accent, global.TH.accent_dark, 0.8); }
            ui_rrect(_rx, _by, _rx + 28, _by + 28, 6, _vc, _vc, 1);
            ui_text(_rx + 38, _by + 14, _nm[v], global.TH.text, fa_left, fa_middle, global.f_body, 1);
            if (_h2 && ui_pressed)
            {
                ui_take_click();
                tile_pen_mc = v;
            }
        }
        _y += 4 * 34 + 8;
    }
    else
    {
        var _tc = c64col(_t.col);
        ui_rrect(_rx, _y, _rx + 28, _y + 28, 6, _tc, _tc, 1);
        ui_text_wrap(_rx + 38, _y + 2, "The tile colour (left button) on the background (right button). Hi-res characters have one colour each.", global.TH.text_dim, _rw - 38, global.f_small, 1);
        _y += 70;
    }
    var _ops = ["Fill", "Flip H", "Flip V", "Clear"];
    var _ow = floor((_rw - 8) / 2);
    for (var o = 0; o < 4; o++)
    {
        var _st = (o == 3) ? BTN_DANGER : BTN_NORMAL;
        if (ui_button("tile_op_" + string(o), _rx + (o mod 2) * (_ow + 8), _y + (o div 2) * 38, _ow, 30, _ops[o], _ops[o] + "|Changes the whole tile (its characters get copied first if other tiles share them). You can Undo it.", _st) && tile_sel > 0)
        {
            undo_mark("tileop" + string(current_time));
            var _old = array_create(_pw * 16, 0);
            for (var p = 0; p < _pw * 16; p++) { _old[p] = tile_pixel(_t, p mod _pw, p div _pw); }
            for (var p2 = 0; p2 < _pw * 16; p2++)
            {
                var _ox = p2 mod _pw;
                var _oy = p2 div _pw;
                var _nv = _old[p2];
                if (o == 0) { _nv = _mc ? tile_pen_mc : 1; }
                if (o == 1) { _nv = _old[_oy * _pw + (_pw - 1 - _ox)]; }
                if (o == 2) { _nv = _old[(15 - _oy) * _pw + _ox]; }
                if (o == 3) { _nv = 0; }
                if (!tile_set_pixel(_t, _ox, _oy, _nv))
                {
                    toast("No free characters left to give this tile its own.", 1);
                    break;
                }
            }
        }
    }
    _y += 2 * 38 + 14;
    ui_heading(_rx, _y, "The tile, and side by side");
    _y += 22;
    ui_inset(_rx, _y, _rx + _rw, _y + 72, 8);
    draw_tile_img(tile_sel, _rx + 10, _y + 4, 64);
    var _nside = clamp(floor((_rw - 100) / 32), 0, 4);
    for (var rr = 0; rr < _nside; rr++)
    {
        for (var rc = 0; rc < 2; rc++) { draw_tile_img(tile_sel, _rx + 90 + rr * 32, _y + 4 + rc * 32, 32); }
    }
    _y += 86;
    var _free = 0;
    var _used = array_create(256, false);
    for (var t2 = 0; t2 < array_length(proj.tiles); t2++)
    {
        for (var q2 = 0; q2 < 4; q2++) { _used[proj.tiles[t2].c[q2]] = true; }
    }
    for (var cc = 64; cc < 256; cc++)
    {
        if (!_used[cc] && cc != 160) { _free += 1; }
    }
    ui_text_wrap(_rx, _y, string(_free) + " characters free for drawing (letters 0-63 stay letters for the HUD).", global.TH.text_faint, _rw, global.f_small, 1);
}

/// The Characters tab: which character goes in each corner of the tile
function tiles_chars_editor(_x1, _y1, _x2, _y2)
{
    var _t = proj.tiles[tile_sel];
    var _big = 160;
    var _bx = _x1 + 30;
    var _byy = _y1 + 14;
    ui_rrect(_bx - 8, _byy - 8, _bx + _big + 8, _byy + _big + 8, 10, c_black, c_black, 0.35);
    draw_tile_img(tile_sel, _bx, _byy, _big);
    for (var q = 0; q < 4; q++)
    {
        var _qx = _bx + (q mod 2) * (_big / 2);
        var _qy = _byy + (q div 2) * (_big / 2);
        var _qh = ui_register("tile_q" + string(q), _qx, _qy, _qx + _big / 2 - 1, _qy + _big / 2 - 1, "Tile corner|A tile is 2 x 2 characters. Click a corner, then click a character below to put it there.");
        if (q == tile_quad) { ui_rrect_line(_qx, _qy, _qx + _big / 2, _qy + _big / 2, 4, global.TH.warn, 1, 2); }
        else if (_qh) { ui_rrect_line(_qx, _qy, _qx + _big / 2, _qy + _big / 2, 4, global.TH.accent, 1, 1); }
        if (_qh && ui_pressed)
        {
            tile_quad = q;
            ui_take_click();
        }
        ui_text(_qx + 4, _qy + 2, string(_t.c[q]), c_white, fa_left, fa_top, global.f_small, 0.8);
    }
    ui_text_wrap(_bx + _big + 30, _byy, "Click a corner of the tile, then pick the character that goes there. Tiles can share characters - drawing on the Tile set tab copies a shared one first.", global.TH.text_dim, _x2 - _bx - _big - 60, global.f_body, 1);
    if (ui_button("tile_editchar", _bx + _big + 30, _byy + 100, 200, 32, "Open in Charset", "Edit character|Jumps to the Charset page with this corner's character picked.", BTN_NORMAL))
    {
        ch_sel = _t.c[tile_quad];
        ws_set(WS_CHARSET);
    }
    var _gy = _byy + _big + 40;
    var _cell = min(22, floor((_x2 - _x1 - 60) / 16), floor((_y2 - _gy - 20) / 16));
    var _gx = floor((_x1 + _x2 - _cell * 16) / 2);
    ui_heading(_gx, _gy - 20, "Characters");
    ui_inset(_gx - 6, _gy - 6, _gx + _cell * 16 + 6, _gy + _cell * 16 + 6, 8);
    var _tmc = tile_is_mc(_t);
    gpu_set_texfilter(false);
    px_rect(_gx, _gy, _cell * 16, _cell * 16, c64col(proj.eng.bg));
    if (_tmc)
    {
        for (var cc = 0; cc < 256; cc++) { draw_pchar(cc, _gx + (cc mod 16) * _cell + (_cell - 16) / 2, _gy + (cc div 16) * _cell + (_cell - 16) / 2, 2, _t.col, true); }
    }
    else
    {
        pchars_refresh();
        draw_sprite_ext(pchars_sprite, 0, _gx, _gy, _cell / 8, _cell / 8, 0, c64col(_t.col), 1);
    }
    gpu_set_texfilter(true);
    var _gh = ui_register("tile_chars", _gx, _gy, _gx + _cell * 16 - 1, _gy + _cell * 16 - 1, "Characters|Click to put a character in the picked tile corner.");
    var _cur = _t.c[tile_quad];
    ui_rrect_line(_gx + (_cur mod 16) * _cell - 2, _gy + (_cur div 16) * _cell - 2, _gx + (_cur mod 16 + 1) * _cell + 2, _gy + (_cur div 16 + 1) * _cell + 2, 4, global.TH.warn, 1, 2);
    if (_gh)
    {
        var _hc = clamp(floor((ui_mx - _gx) / _cell), 0, 15) + clamp(floor((ui_my - _gy) / _cell), 0, 15) * 16;
        var _us = tile_char_users(_hc);
        ui_help_body = "Character " + string(_hc) + ((_us > 0) ? " (used " + string(_us) + " times by tiles)" : " (free)") + ". Click to use it in this corner.";
        if (ui_pressed)
        {
            undo_mark("tchar" + string(current_time));
            _t.c[tile_quad] = _hc;
            tile_quad = (tile_quad + 1) mod 4;
            atlas_dirty = true;
            ui_take_click();
        }
    }
}

// ---------------------------------------------------------------------------
// The tools (Tools tab): the space bar menu in the game, ported from ADAM
// ---------------------------------------------------------------------------

#macro TOOL_MAX 6
#macro TOOL_NAME_LEN 8

/// A tool: _act 0 = dig, 1 = build with the tile carried, 2 = put tile _tile where the player
/// stands (a ladder, a torch), 3 = weapon (fire shoots the World page's weapon)
function tool_new(_name, _act, _tile)
{
    return { name : _name, act : _act, tile : _tile };
}

function tool_act_names()
{
    return ["Dig", "Build (tile carried)", "Put a tile here", "Weapon (shoots)"];
}

/// The tools of a loaded project, made safe
function tools_fix(_raw)
{
    var _out = [];
    if (!is_array(_raw)) { return _out; }
    for (var i = 0; i < min(TOOL_MAX, array_length(_raw)); i++)
    {
        var _src = _raw[i];
        if (!is_struct(_src)) { continue; }
        var _t = struct_overlay(tool_new("TOOL", 0, 0), _src);
        if (!is_string(_t.name)) { _t.name = "TOOL"; }
        _t.name = string_upper(string_copy(_t.name, 1, TOOL_NAME_LEN));
        _t.act = is_numeric(_t.act) ? clamp(floor(_t.act), 0, 3) : 0;
        _t.tile = is_numeric(_t.tile) ? clamp(floor(_t.tile), 0, 63) : 0;
        array_push(_out, _t);
    }
    return _out;
}

/// Does the game have the tools menu (Dig and place on, and at least one tool)?
function tools_on(_p)
{
    return tile_dig_on(_p) && array_length(_p.eng.tools) > 0;
}

function tools_have_weapon(_p)
{
    if (!tools_on(_p)) { return false; }
    for (var i = 0; i < array_length(_p.eng.tools); i++)
    {
        if (_p.eng.tools[i].act == 3) { return true; }
    }
    return false;
}

/// The menu line as the game shows it with tool _sel picked (40 columns)
function tools_menu_line(_p, _sel)
{
    var _l = "";
    for (var j = 0; j < array_length(_p.eng.tools); j++)
    {
        _l += ((j == _sel) ? ">" : " ") + _p.eng.tools[j].name + " ";
    }
    return _l;
}

/// The engine's tool tables: tl_act, tl_tile, tl_name (8 letters each), and the menu
/// lines (40 screen codes, one for each tool picked) with tm_lo / tm_hi
function tools_emit(L, _p)
{
    var _tl = _p.eng.tools;
    var _n = array_length(_tl);
    var _nt = max(1, min(64, array_length(_p.tiles)));
    var _act = [];
    var _tile = [];
    var _name = [];
    for (var i = 0; i < _n; i++)
    {
        array_push(_act, _tl[i].act);
        array_push(_tile, clamp(_tl[i].tile, 0, _nt - 1));
        var _nm = string_upper(string_copy(_tl[i].name + "        ", 1, 8));
        for (var k = 0; k < 8; k++) { array_push(_name, scr_code_from_char(string_char_at(_nm, k + 1)) & 63); }
    }
    array_push(L, "tl_act:");
    eng_emit_bytes(L, _act);
    array_push(L, "tl_tile:");
    eng_emit_bytes(L, _tile);
    array_push(L, "tl_name:");
    eng_emit_bytes(L, _name);
    var _lo = [];
    var _hi = [];
    for (var s = 0; s < _n; s++)
    {
        var _ln = string_upper(string_copy(tools_menu_line(_p, s) + string_repeat(" ", 40), 1, 40));
        var _b = [];
        for (var c = 0; c < 40; c++) { array_push(_b, scr_code_from_char(string_char_at(_ln, c + 1)) & 63); }
        array_push(L, "tm_line" + string(s) + ":");
        eng_emit_bytes(L, _b);
        array_push(_lo, "<tm_line" + string(s));
        array_push(_hi, ">tm_line" + string(s));
    }
    array_push(L, "tm_lo:", " .byte " + string_join_ext(",", _lo));
    array_push(L, "tm_hi:", " .byte " + string_join_ext(",", _hi));
}

/// The Tools tab: the space bar menu's tools - up to TOOL_MAX, each a name, what fire does
/// with it and (to put down) its tile. None: fire digs and places as before.
function tiles_tools_editor(_x1, _y1, _x2, _y2)
{
    var _e = proj.eng;
    var _fx = _x1 + 20;
    var _fw = _x2 - _x1 - 40;
    var _y = _y1 + 8;
    var _intro = "In the game, space opens a menu of these tools along the top: left and right pick one, fire or space takes it, and from then on fire uses it. With no tools, fire + a direction digs and fire on its own puts the tile carried down. Needs Dig and place (left).";
    ui_text_wrap(_fx, _y, _intro, global.TH.text_dim, _fw, global.f_body, 1);
    draw_set_font(global.f_body);
    _y += ceil(ui_sh_ext(_intro, _fw)) + 12;
    if (!tile_dig_on(proj))
    {
        ui_text_wrap(_fx, _y, "Dig and place is off (or this kind of game doesn't dig), so the game has no tools.", global.TH.warn, _fw, global.f_body, 1);
        _y += 30;
    }
    var _acts = tool_act_names();
    var _tn = [];
    for (var k = 0; k < array_length(proj.tiles); k++) { array_push(_tn, string(k) + ": " + proj.tiles[k].name); }
    var _nw = 130;
    var _aw = min(220, floor((_fw - _nw - 50) / 2));
    var _tw = _fw - _nw - _aw - 50 - 24;
    ui_heading(_fx, _y, "Name");
    ui_heading(_fx + _nw + 8, _y, "Fire does");
    ui_heading(_fx + _nw + _aw + 16, _y, "Tile it puts down");
    _y += 20;
    var _del = -1;
    for (var i = 0; i < array_length(_e.tools); i++)
    {
        var _t = _e.tools[i];
        var _id = "tool" + string(i) + "_";
        var _nm = ui_textfield(_id + "name", _fx, _y, _nw, 30, _t.name, TOOL_NAME_LEN, "Tool name|Up to 8 letters, shown in the space bar menu and on the HUD.");
        set_val(_t, "name", string_upper(_nm), "toolname" + string(i));
        set_val(_t, "act", ui_dropdown(_id + "act", _fx + _nw + 8, _y, _aw, 30, _acts, _t.act, "Fire does|Dig: fire digs the way the player faces (or fire + a direction digs that way), held down. Build: fire puts the tile carried (the last one dug) where the joystick points, or in front. Put a tile here: fire puts the tile picked here where the player stands - a ladder to climb out of a hole. Weapon: fire shoots the World page's weapon."), "toolact" + string(i));
        if (_t.act == 2)
        {
            set_val(_t, "tile", ui_dropdown(_id + "tile", _fx + _nw + _aw + 16, _y, _tw, 30, _tn, clamp(_t.tile, 0, array_length(_tn) - 1), "Tile it puts down|A ladder tile (Ladder on, Solid off) to climb, or a background tile like a torch. It goes where the player's middle is, or its feet, if that cell is empty."), "tooltile" + string(i));
        }
        if (ui_button(_id + "del", _fx + _fw - 50, _y, 50, 30, "X", "Remove this tool|You can Undo it.", BTN_DANGER)) { _del = i; }
        _y += 38;
    }
    if (_del >= 0)
    {
        undo_mark("tooldel" + string(current_time));
        array_delete(_e.tools, _del, 1);
    }
    var _bst = (array_length(_e.tools) >= TOOL_MAX) ? BTN_GHOST : BTN_NORMAL;
    if (ui_button("tool_add", _fx, _y + 4, 160, 30, "Add a tool", "Add a tool|Up to " + string(TOOL_MAX) + " tools. Keep the names short so they all fit across the screen.", _bst) && array_length(_e.tools) < TOOL_MAX)
    {
        undo_mark("tooladd" + string(current_time));
        var _names = ["PICK", "HAMMER", "LADDER", "TORCH", "TOOL5", "TOOL6"];
        var _n = array_length(_e.tools);
        var _a = (_n == 0) ? 0 : ((_n == 1) ? 1 : 2);
        array_push(_e.tools, tool_new(_names[_n], _a, 0));
    }
    // the menu as the game shows it (40 columns)
    var _line = tools_menu_line(proj, 0);
    if (string_length(_line) > 40)
    {
        ui_text_wrap(_fx, _y + 46, "The menu is " + string(string_length(_line)) + " letters across - only 40 fit. Shorten some names.", global.TH.warn, _fw, global.f_body, 1);
    }
    else if (array_length(_e.tools) > 0)
    {
        ui_heading(_fx, _y + 48, "The menu in the game");
        ui_inset(_fx, _y + 68, _fx + _fw, _y + 104, 6);
        var _cs = clamp(floor((_fw - 16) / 320 * 2) / 2, 1, 2);
        for (var c = 0; c < string_length(_line); c++)
        {
            var _code = scr_code_from_char(string_char_at(_line, c + 1));
            if (_code != 32) { draw_c64_char(_code, _fx + 8 + c * 8 * _cs, _y + 78, _cs, c_white); }
        }
        ui_text_wrap(_fx, _y + 116, "The HUD shows the tool in use next to the tile carried (or add a Tool field on the UI page).", global.TH.text_faint, _fw, global.f_small, 1);
    }
}
