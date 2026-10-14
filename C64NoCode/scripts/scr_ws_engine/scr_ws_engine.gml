/// C64 NO-CODE STUDIO - map game editors: templates, world, charset, tiles, map, enemies

#macro WS_TEMPLATES 7
#macro WS_WORLD 8
#macro WS_CHARSET 9
#macro WS_TILES 10
#macro WS_MAP 11
#macro WS_ENEMIES 12

// ---------------------------------------------------------------- caches

/// White glyph sprite of the project charset (256 chars, 16x16 grid)
function pchars_refresh()
{
    if (!charset_dirty && pchars_sprite != -1) { return; }
    if (pchars_sprite != -1 && sprite_exists(pchars_sprite)) { sprite_delete(pchars_sprite); }
    pchars_sprite = glyph_sheet_sprite(proj.charset);
    charset_dirty = false;
    atlas_dirty = true;
}

/// Draws one project char. Multicolour chars use the MC colours.
function draw_pchar(_code, _x, _y, _scale, _col, _mc)
{
    if (_mc)
    {
        var _cols = [-1, proj.eng.mc1, proj.eng.mc2, _col & 7];
        for (var r = 0; r < 8; r++)
        {
            var _b = proj.charset[_code * 8 + r];
            for (var p = 0; p < 4; p++)
            {
                var _v = (_b >> (6 - p * 2)) & 3;
                if (_v != 0)
                {
                    px_rect(_x + p * 2 * _scale, _y + r * _scale, 2 * _scale, _scale, c64col(_cols[_v]));
                }
            }
        }
        return;
    }
    pchars_refresh();
    draw_sprite_part_ext(pchars_sprite, 0, (_code mod 16) * 8, (_code div 16) * 8, 8, 8, _x, _y, _scale, _scale, c64col(_col), 1);
}

/// 16x16 atlas of all tiles (8 x 8 grid) baked with colours
function atlas_refresh()
{
    if (!surface_exists(tile_atlas)) { tile_atlas = surface_create(128, 128); atlas_dirty = true; }
    pchars_refresh();
    if (!atlas_dirty) { return; }
    surface_set_target(tile_atlas);
    draw_clear(c64col(proj.eng.bg));
    gpu_set_texfilter(false);
    for (var t = 0; t < min(64, array_length(proj.tiles)); t++)
    {
        var _tl = proj.tiles[t];
        var _tx = (t mod 8) * 16;
        var _ty = (t div 8) * 16;
        var _mc = (proj.eng.mc && _tl.mc);
        draw_pchar(_tl.c[0], _tx, _ty, 1, _tl.col, _mc);
        draw_pchar(_tl.c[1], _tx + 8, _ty, 1, _tl.col, _mc);
        draw_pchar(_tl.c[2], _tx, _ty + 8, 1, _tl.col, _mc);
        draw_pchar(_tl.c[3], _tx + 8, _ty + 8, 1, _tl.col, _mc);
    }
    surface_reset_target();
    atlas_dirty = false;
}

function draw_tile_img(_t, _x, _y, _size)
{
    atlas_refresh();
    var _ti = clamp(_t, 0, 63);
    gpu_set_texfilter(false);
    draw_surface_part_ext(tile_atlas, (_ti mod 8) * 16, (_ti div 8) * 16, 16, 16, _x, _y, _size / 16, _size / 16, c_white, 1);
    gpu_set_texfilter(true);
}

function engine_mark_dirty()
{
    atlas_dirty = true;
}

function enemy_names()
{
    var _n = [];
    for (var i = 0; i < array_length(proj.enemies); i++) { array_push(_n, string(i + 1) + ": " + proj.enemies[i].name); }
    return _n;
}

function tile_names()
{
    var _n = [];
    for (var i = 0; i < array_length(proj.tiles); i++) { array_push(_n, string(i) + ": " + proj.tiles[i].name); }
    return _n;
}

function sfx_names_none()
{
    var _n = sfx_names();
    array_push(_n, "(no sound)");
    return _n;
}

/// tile removal keeps maps consistent
function tile_remove(_idx)
{
    if (_idx <= 0) { return; }
    array_delete(proj.tiles, _idx, 1);
    // what tiles leave behind points at the same tiles
    for (var b = 0; b < array_length(proj.tiles); b++)
    {
        var _bt = proj.tiles[b];
        if (_bt.becomes == _idx) { _bt.becomes = 0; }
        else if (_bt.becomes > _idx) { _bt.becomes -= 1; }
    }
    for (var l = 0; l < array_length(proj.levels); l++)
    {
        var _m = proj.levels[l].map;
        for (var i = 0; i < array_length(_m); i++)
        {
            if (_m[i] == _idx) { _m[i] = 0; }
            else
            {
                if (_m[i] > _idx) { _m[i] -= 1; }
            }
        }
    }
    atlas_dirty = true;
}

function enemy_remove(_idx)
{
    array_delete(proj.enemies, _idx, 1);
    for (var l = 0; l < array_length(proj.levels); l++)
    {
        var _sp = proj.levels[l].spawners;
        for (var i = array_length(_sp) - 1; i >= 0; i--)
        {
            if (_sp[i].type == _idx) { array_delete(_sp, i, 1); }
            else
            {
                if (_sp[i].type > _idx) { _sp[i].type -= 1; }
            }
        }
    }
}

/// Builds every template once (for previews)
function templates_cache()
{
    if (array_length(tpl_cache) > 0) { return; }
    var _keep = proj;
    for (var i = 0; i < array_length(global.TEMPLATES); i++)
    {
        array_push(tpl_cache, template_build(i));
    }
    proj = _keep;
}

// ---------------------------------------------------------------- templates

function ws_templates_draw(_x1, _y1, _x2, _y2)
{
    templates_cache();
    ui_panel(_x1, _y1, _x2, _y2, "Game templates");
    ui_text(_x1 + 200, _y1 + 16, "Pick a starting point. Every template is a complete, playable game you can change in any way.", global.TH.text_faint, fa_left, fa_top, global.f_small, 1);
    var _n = array_length(global.TEMPLATES);
    var _cols = 4;
    if (_x2 - _x1 < 1300) { _cols = 3; }
    var _cw = floor((_x2 - _x1 - 32 - (_cols - 1) * 14) / _cols);
    var _ch = 300;
    var _content = ceil(_n / _cols) * (_ch + 14) + 10;
    var _off = ui_scroll_begin("tpl_list", _x1 + 10, _y1 + 52, _x2 - 10, _y2 - 10, _content);
    for (var i = 0; i < _n; i++)
    {
        var _t = global.TEMPLATES[i];
        var _cx = _x1 + 16 + (i mod _cols) * (_cw + 14);
        var _cy = _y1 + 60 + (i div _cols) * (_ch + 14) - _off;
        var _id = "tpl_card_" + string(i);
        var _hot = ui_register(_id, _cx, _cy, _cx + _cw, _cy + _ch, _t.name + "|" + _t.desc);
        var _tg = 0;
        if (_hot) { _tg = 1; }
        var _a = ui_anim_to(_id, _tg);
        ui_rrect(_cx, _cy, _cx + _cw, _cy + _ch, 14, merge_colour(global.TH.btn_top, global.TH.btn_hot_top, _a), global.TH.panel_bot, 1);
        ui_rrect_line(_cx, _cy, _cx + _cw, _cy + _ch, 14, merge_colour(global.TH.panel_edge, global.TH.accent, _a), 0.7, 1);
        ui_glow(_cx, _cy, _cx + _cw, _cy + _ch, 14, global.TH.accent, _a * 0.7);
        // preview
        var _px1 = _cx + 12;
        var _py1 = _cy + 12;
        var _pw = _cw - 24;
        var _ph = 150;
        ui_inset(_px1, _py1, _px1 + _pw, _py1 + _ph, 10);
        tpl_draw_preview_i(i, _px1 + 4, _py1 + 4, _pw - 8, _ph - 8);
        ui_rrect(_cx + 12, _cy + 172, _cx + 20 + ui_sw(_t.kind) * 0.8 + 16, _cy + 194, 11, global.TH.accent2, make_colour_rgb(46, 140, 116), 1);
        ui_text(_cx + 22, _cy + 183, _t.kind, make_colour_rgb(16, 30, 28), fa_left, fa_middle, global.f_small, 1);
        ui_text(_cx + 14, _cy + 202, _t.name, c_white, fa_left, fa_top, global.f_title, 1);
        ui_text_wrap(_cx + 14, _cy + 228, _t.desc, global.TH.text_dim, _cw - 28, global.f_small, 1);
        if (ui_button("tpl_use_" + string(i), _cx + _cw - 132, _cy + _ch - 44, 120, 32, "Use template", "Use template|Replaces your current project with '" + _t.name + "'. You can Undo this.", BTN_ACCENT))
        {
            undo_mark("tpl" + string(current_time));
            proj = template_build(i);
            proj_path = "";
            project_after_change();
            if (proj.game_type == 1) { ws_set(WS_WORLD); }
            else { ws_set(WS_HOME); }
            toast(_t.name + " loaded - build it to play!", 0);
        }
    }
    ui_scroll_end("tpl_list", _x1 + 10, _y1 + 52, _x2 - 10, _y2 - 10, _content);
}

/// Draws a template sprite pixel by pixel (used to build the cached previews)
function tpl_prev_sprite(_p, _i, _x, _y, _col, _sa, _sb)
{
    if (_i < 0 || _i >= array_length(_p.sprites)) { return; }
    var _s = _p.sprites[_i];
    if (_s.mc)
    {
        var _cols = [-1, _sa, _col, _sb];
        for (var q = 0; q < 252; q++)
        {
            var _v = _s.mcp[q];
            var _pv = 0;
            if (_v == 1) { _pv = 2; }
            if (_v == 2) { _pv = 1; }
            if (_v == 3) { _pv = 3; }
            if (_pv != 0) { px_rect(_x + (q mod 12) * 2, _y + (q div 12), 2, 1, c64col(_cols[_pv])); }
        }
    }
    else
    {
        for (var h = 0; h < 504; h++)
        {
            if (_s.hi[h] != 0) { px_rect(_x + (h mod 24), _y + (h div 24), 1, 1, c64col(_col)); }
        }
    }
}

/// Draws one map tile of a template exactly as the C64 would show it
function tpl_prev_tile(_p, _t, _x, _y)
{
    if (_t <= 0 || _t >= array_length(_p.tiles)) { return; }
    var _e = _p.eng;
    var _tl = _p.tiles[_t];
    var _own = _tl.col;
    if (!_e.fullcol) { _own = _e.wincol; }
    var _mc = (_e.mc && _tl.mc);
    for (var q = 0; q < 4; q++)
    {
        var _ox = _x + (q mod 2) * 8;
        var _oy = _y + (q div 2) * 8;
        var _code = _tl.c[q];
        for (var r = 0; r < 8; r++)
        {
            var _b = _p.charset[_code * 8 + r];
            if (_b == 0) { continue; }
            if (_mc)
            {
                for (var pp = 0; pp < 4; pp++)
                {
                    var _v = (_b >> (6 - pp * 2)) & 3;
                    if (_v == 0) { continue; }
                    var _c = _own & 7;
                    if (_v == 1) { _c = _e.mc1; }
                    if (_v == 2) { _c = _e.mc2; }
                    px_rect(_ox + pp * 2, _oy + r, 2, 1, c64col(_c));
                }
            }
            else
            {
                for (var bit = 0; bit < 8; bit++)
                {
                    if ((_b & (128 >> bit)) != 0) { px_rect(_ox + bit, _oy + r, 1, 1, c64col(_own)); }
                }
            }
        }
    }
}

/// Builds (once) a 320 x 176 picture of a template's start screen
function tpl_preview_surface(_i)
{
    while (array_length(tpl_prev) <= _i) { array_push(tpl_prev, -1); }
    if (surface_exists(tpl_prev[_i])) { return tpl_prev[_i]; }
    var _p = tpl_cache[_i];
    var _surf = surface_create(320, 176);
    surface_set_target(_surf);
    gpu_set_texfilter(false);
    if (_p.game_type == 0)
    {
        draw_clear(c64col(_p.border));
        var _keep = proj;
        proj = _p;
        draw_c64_screen(0, -12, 1, false);
        for (var a = 0; a < array_length(_p.actors); a++)
        {
            var _ac = _p.actors[a];
            tpl_prev_sprite(_p, _ac.sprite, _ac.x - 24, _ac.y - 50 - 12, _ac.colour, _p.mc1, _p.mc2);
        }
        proj = _keep;
    }
    else
    {
        var _e = _p.eng;
        draw_clear(c64col(_e.bg));
        var _lv = _p.levels[0];
        var _vw = 20;
        var _vh = 11;
        var _sx = 0;
        var _sy = 0;
        if (_e.scroll == SCROLL_V) { _sy = max(0, _lv.h - _vh); }
        if (_e.scroll == SCROLL_8 || _e.scroll == SCROLL_FLIP)
        {
            _sx = clamp(_lv.px - _vw div 2, 0, max(0, _lv.w - _vw));
            _sy = clamp(_lv.py - _vh div 2, 0, max(0, _lv.h - _vh));
        }
        if (_e.scroll == SCROLL_H || _e.scroll == SCROLL_FLIP) { _sy = max(0, _lv.h - _vh); }
        for (var ty = 0; ty < min(_vh, _lv.h); ty++)
        {
            for (var tx = 0; tx < min(_vw, _lv.w); tx++)
            {
                tpl_prev_tile(_p, _lv.map[(ty + _sy) * _lv.w + tx + _sx], tx * 16, ty * 16);
            }
        }
        // enemies at their spawn points, then the player
        for (var s = 0; s < array_length(_lv.spawners); s++)
        {
            var _sp = _lv.spawners[s];
            if (_sp.x >= _sx && _sp.x < _sx + _vw && _sp.y >= _sy && _sp.y < _sy + _vh && _sp.type < array_length(_p.enemies))
            {
                var _en = _p.enemies[_sp.type];
                var _ey = (_sp.y - _sy) * 16;
                if (_en.move == 5) { _ey -= 5; }
                tpl_prev_sprite(_p, _en.spr, (_sp.x - _sx) * 16, _ey, _en.col, _e.smc1, _e.smc2);
            }
        }
        var _py = (_lv.py - _sy) * 16;
        if (_e.kind != KIND_CAVE) { _py -= 5; }
        tpl_prev_sprite(_p, _e.pspr, (_lv.px - _sx) * 16, _py, _e.pcol, _e.smc1, _e.smc2);
    }
    gpu_set_texfilter(true);
    surface_reset_target();
    tpl_prev[_i] = _surf;
    return _surf;
}

/// Mini picture of a template: its real graphics, cached
function tpl_draw_preview_i(_i, _x, _y, _w, _h)
{
    var _surf = tpl_preview_surface(_i);
    var _sc = min(_w / 320, _h / 176);
    gpu_set_texfilter(false);
    draw_surface_ext(_surf, _x + (_w - 320 * _sc) / 2, _y + (_h - 176 * _sc) / 2, _sc, _sc, 0, c_white, 1);
    gpu_set_texfilter(true);
}

// ---------------------------------------------------------------- world

function ws_world_draw(_x1, _y1, _x2, _y2)
{
    var _e = proj.eng;
    var _cw = floor((_x2 - _x1 - 24) / 3);
    var _ax = _x1;
    var _bx = _x1 + _cw + 12;
    var _cx = _x1 + (_cw + 12) * 2;
    var _fw = _cw - 40;
    var _half = floor((_fw - 12) / 2);

    // ---- column 1: game + screen
    ui_panel(_ax, _y1, _ax + _cw, _y2, "Game and scrolling");
    var _x = _ax + 20;
    var _y = _y1 + 56;
    ui_heading(_x, _y, "Kind of game");
    if (set_val(_e, "kind", 1 + ui_dropdown("w_kind", _x, _y + 18, _fw, 32, global.KIND_LIST, _e.kind - 1, "Kind of game|Changes how the player moves: free flight with shooting, running and jumping, digging tile by tile, or walking around a maze."), "wkind")) { }
    _y += 62;
    ui_heading(_x, _y, "Scrolling");
    set_val(_e, "scroll", ui_dropdown("w_scroll", _x, _y + 18, _fw, 32, global.SCROLL_NAMES, _e.scroll, "Scrolling|How the map moves past the screen. Horizontal and vertical can scroll by themselves (shoot-em-ups) or follow the player. 8-way follows the player in every direction. Flip-screen jumps a whole screen at a time."), "wscroll");
    _y += 62;
    if (_e.kind == KIND_SHMUP && (_e.scroll == SCROLL_H || _e.scroll == SCROLL_V))
    {
        set_val(_e, "auto", ui_toggle("w_auto", _x, _y, "Scrolls by itself", _e.auto, "Auto-scroll|The level moves on its own like a classic shoot-em-up. Off: the screen follows the player instead."), "wauto");
        _y += 32;
        if (_e.auto)
        {
            set_val(_e, "auto_speed", ui_dropdown("w_autospd", _x, _y, _fw, 30, global.AUTO_NAMES, _e.auto_speed, "Scroll speed|How fast the level moves."), "wautospd");
            _y += 40;
        }
    }
    ui_heading(_x, _y, "Play window - first row / rows");
    set_val(_e, "wtop", ui_stepper("w_wtop", _x, _y + 18, _half, _e.wtop, 2, 4, "Window top row|The score bar uses row 0 and row 1 is a gap. Move the window down to make room for more status rows."), "wtop");
    set_val(_e, "wrows", ui_stepper("w_wrows", _x + _half + 12, _y + 18, _half, _e.wrows, 6, 24 - _e.wtop, "Window height|How many text rows scroll. Fewer rows = less work for the C64 each frame. Watch the cycle meter."), "wrows");
    _y += 62;
    set_val(_e, "fullcol", ui_toggle("w_fullcol", _x, _y, "Colour per tile (slower)", _e.fullcol, "Colour scrolling|On: every tile keeps its own colour, but colour RAM must be shifted too (almost twice the work). Off: the window uses one colour - much faster, ideal with multicolour charsets."), "wfullcol");
    _y += 32;
    if (_e.scroll == SCROLL_H || _e.scroll == SCROLL_8)
    {
        set_val(_e, "cols38", ui_toggle("w_cols38", _x, _y, "38-column mode (hides the edge)", _e.cols38, "38 columns|Hides the left and right column so new tiles appear smoothly. Recommended for horizontal scrolling."), "wcols38");
        _y += 32;
    }
    if (!_e.fullcol)
    {
        ui_heading(_x, _y + 4, "Window colour");
        set_val(_e, "wincol", ui_colour_drop("w_wincol", _x, _y + 22, _fw, 30, _e.wincol, "Window colour|The single colour used for the whole play window."), "wincol");
        _y += 62;
    }
    ui_heading(_x, _y + 4, "Border / background");
    if (set_val(_e, "border", ui_colour_drop("w_border", _x, _y + 22, _half, 30, _e.border, "Border colour|The frame around the screen."), "wborder")) { }
    if (set_val(_e, "bg", ui_colour_drop("w_bg", _x + _half + 12, _y + 22, _half, 30, _e.bg, "Background|The colour behind every character."), "wbg")) { atlas_dirty = true; }
    _y += 62;
    if (set_val(_e, "mc", ui_toggle("w_mc", _x, _y, "Multicolour characters", _e.mc, "Multicolour chars|Lets tiles use 3 colours plus background (chunkier pixels). Pick the two shared colours below and tick MC on each tile."), "wmc")) { atlas_dirty = true; }
    _y += 32;
    if (_e.mc)
    {
        if (set_val(_e, "mc1", ui_colour_drop("w_mc1", _x, _y, _half, 30, _e.mc1, "Char colour A|Shared by all multicolour characters ($D022)."), "wmc1")) { atlas_dirty = true; }
        if (set_val(_e, "mc2", ui_colour_drop("w_mc2", _x + _half + 12, _y, _half, 30, _e.mc2, "Char colour B|Shared by all multicolour characters ($D023)."), "wmc2")) { atlas_dirty = true; }
        _y += 40;
    }

    // ---- column 2: player
    ui_panel(_bx, _y1, _bx + _cw, _y2, "Player and weapons");
    _x = _bx + 20;
    _y = _y1 + 56;
    var _sn = sprite_names();
    ui_heading(_x, _y, "Player sprite / colour");
    set_val(_e, "pspr", ui_dropdown("w_pspr", _x, _y + 18, _half, 30, _sn, _e.pspr, "Player sprite|The picture used for the player."), "wpspr");
    set_val(_e, "pcol", ui_colour_drop("w_pcol", _x + _half + 12, _y + 18, _half, 30, _e.pcol, "Player colour|The player's own colour."), "wpcol");
    _y += 60;
    ui_heading(_x, _y, "Speed / lives");
    set_val(_e, "pspeed", ui_stepper("w_pspeed", _x, _y + 18, _half, _e.pspeed, 1, 4, "Player speed|Pixels per frame."), "wpspeed");
    set_val(_e, "lives", ui_stepper("w_lives", _x + _half + 12, _y + 18, _half, _e.lives, 1, 9, "Lives|Lives at the start of the game."), "wlives");
    _y += 60;
    if (_e.kind == KIND_PLAT)
    {
        ui_heading(_x, _y, "Jump strength / gravity");
        set_val(_e, "jumpv", ui_stepper("w_jumpv", _x, _y + 18, _half, _e.jumpv, 2, 9, "Jump strength|How high the player jumps."), "wjumpv");
        set_val(_e, "grav", ui_dropdown("w_grav", _x + _half + 12, _y + 18, _half, 30, ["Heavy", "Normal", "Floaty"], _e.grav, "Gravity|How quickly the player falls."), "wgrav");
        _y += 60;
        set_val(_e, "jump_up", ui_toggle("w_jumpup", _x, _y, "Jump with joystick UP (not fire)", _e.jump_up, "Jump button|Choose fire or pushing up to jump. Up frees the fire button for shooting."), "wjumpup");
        _y += 36;
    }
    ui_heading(_x, _y, "Weapon");
    set_val(_e, "weapon", ui_dropdown("w_weapon", _x, _y + 18, _fw, 30, global.WEAPON_NAMES, _e.weapon, "Weapon|What the fire button shoots. Double fires two parallel shots, spread fires two at angles, rapid fires very quickly."), "wweapon");
    _y += 58;
    if (_e.weapon > 0)
    {
        set_val(_e, "bspr", ui_dropdown("w_bspr", _x, _y, _half, 30, _sn, _e.bspr, "Bullet sprite|Picture for the player's shots."), "wbspr");
        set_val(_e, "bcol", ui_colour_drop("w_bcol", _x + _half + 12, _y, _half, 30, _e.bcol, "Bullet colour|Colour of the player's shots."), "wbcol");
        _y += 40;
        ui_heading(_x, _y, "Shot speed / reload / direction");
        var _third = floor((_fw - 16) / 3);
        set_val(_e, "bspeed", ui_stepper("w_bspeed", _x, _y + 18, _third, _e.bspeed, 2, 8, "Shot speed|Pixels per frame."), "wbspeed");
        set_val(_e, "cooldown", ui_stepper("w_cool", _x + _third + 8, _y + 18, _third, _e.cooldown, 2, 60, "Reload time|Frames between shots."), "wcool");
        if (_e.kind == KIND_SHMUP)
        {
            set_val(_e, "firedir", ui_dropdown("w_firedir", _x + (_third + 8) * 2, _y + 18, _third, 30, global.DIR_NAMES, _e.firedir, "Shot direction|Which way shots fly. Platform and top-down games fire the way the player faces."), "wfiredir");
        }
        _y += 60;
    }
    ui_heading(_x, _y, "Enemy shots");
    set_val(_e, "ebspr", ui_dropdown("w_ebspr", _x, _y + 18, _half, 30, _sn, _e.ebspr, "Enemy shot sprite|Picture for enemy bullets."), "webspr");
    set_val(_e, "ebcol", ui_colour_drop("w_ebcol", _x + _half + 12, _y + 18, _half, 30, _e.ebcol, "Enemy shot colour|Colour of enemy bullets."), "webcol");
    _y += 60;
    ui_heading(_x, _y, "Sounds for events");
    _y += 18;
    var _evk = ["sfx_shoot", "sfx_hit", "sfx_die", "sfx_collect", "sfx_jump", "sfx_exit"];
    var _evn = ["Shoot", "Enemy hit", "Player dies", "Collect", "Jump", "Level done"];
    var _snd = sfx_names_none();
    for (var ev = 0; ev < 6; ev++)
    {
        var _ex = _x + (ev mod 2) * (_half + 12);
        var _ey = _y + (ev div 2) * 52;
        ui_text(_ex, _ey, _evn[ev], global.TH.text_dim, fa_left, fa_top, global.f_small, 1);
        var _nsnd = array_length(proj.sfx);
        var _cur = _e[$ _evk[ev]];
        if (_cur >= _nsnd) { _cur = _nsnd; }
        var _nv = ui_dropdown("w_" + _evk[ev], _ex, _ey + 16, _half, 28, _snd, _cur, _evn[ev] + " sound|Which sound plays for this event. Design them on the Sound page.");
        if (_nv == _nsnd) { _nv = 255; }
        set_val(_e, _evk[ev], _nv, "w" + _evk[ev]);
    }

    // ---- column 3: cycle meter + layout
    ui_panel(_cx, _y1, _x2, _y2, "Stock C64 budget");
    _x = _cx + 20;
    _y = _y1 + 56;
    var _bud = eng_cycle_budget(_e);
    var _bw = _x2 - _cx - 40;
    ui_text_wrap(_x, _y, "Each frame the C64 has about 18,000 free CPU cycles. Scrolling moves every character in the window once per 8 pixels; that frame is the busiest.", global.TH.text_dim, _bw, global.f_small, 1);
    _y += 66;
    ui_register("w_meter", _x, _y, _x + _bw, _y + 90, "Cycle meter|Blue is the scroll shift on its busiest frame, green is game logic (and the music driver, when a level has a song), the white line is the frame limit. Over the line the game slows down for one frame every 8 pixels.");
    ui_inset(_x, _y, _x + _bw, _y + 34, 9);
    var _scale = (_bw - 8) / 24000;
    var _sw = min(_bw - 8, _bud.shift * _scale);
    var _lw = min(_bw - 8 - _sw, (_bud.logic + 400) * _scale);
    if (_sw > 1) { ui_rrect(_x + 4, _y + 4, _x + 4 + _sw, _y + 30, 6, global.TH.accent, global.TH.accent_dark, 1); }
    ui_rrect(_x + 4 + _sw, _y + 4, _x + 4 + _sw + _lw, _y + 30, 6, global.TH.accent2, make_colour_rgb(46, 140, 116), 1);
    var _lim = _x + 4 + _bud.frame * _scale;
    draw_line_width_colour(_lim, _y - 4, _lim, _y + 38, 2, c_white, c_white);
    ui_text(_lim, _y + 40, "frame", global.TH.text_faint, fa_center, fa_top, global.f_small, 1);
    ui_text(_x, _y + 58, "Busiest frame: " + string(round(_bud.total)) + " cycles", global.TH.text, fa_left, fa_top, global.f_bold, 1);
    _y += 96;
    var _ok = 0;
    var _msg = "Fits in one frame - smooth 50 fps scrolling on a stock C64.";
    if (!_bud.fits) { _ok = 1; _msg = "Too busy: the game drops a frame each coarse scroll step. Use fewer window rows or turn off colour per tile."; }
    if (_bud.tear) { _ok = 2; _msg = "The screen update may not finish before the raster beam: the top of the window can tear. Use fewer rows."; }
    if (_e.scroll == SCROLL_NONE || _e.scroll == SCROLL_FLIP) { _ok = 0; _msg = "No smooth scrolling - plenty of time left for game logic."; }
    draw_check(_x + 10, _y + 11, _ok);
    ui_text_wrap(_x + 30, _y, _msg, global.TH.text, _bw - 34, global.f_body, 1);
    _y += 70;
    if (ui_button("w_fit", _x, _y, _bw, 32, "Make it fit automatically", "Auto-fit|Reduces the window height (and colour scrolling if needed) until the busiest frame fits.", BTN_NORMAL))
    {
        undo_mark("wfit" + string(current_time));
        var _guard = 0;
        while (_guard < 30)
        {
            var _b2 = eng_cycle_budget(_e);
            if (_b2.fits && !_b2.tear) { break; }
            if (_e.wrows > 12) { _e.wrows -= 1; }
            else
            {
                if (_e.fullcol) { _e.fullcol = false; }
                else { break; }
            }
            _guard += 1;
        }
    }
    _y += 48;
    // screen layout diagram
    ui_heading(_x, _y, "Screen layout");
    _y += 20;
    var _sc = min(_bw / 40, 6);
    var _lx = _x + (_bw - 40 * _sc) / 2;
    ui_register("w_layout", _lx, _y, _lx + 40 * _sc, _y + 25 * _sc, "Screen layout|Row 0 is the score bar, the dim rows are gaps, the blue rows scroll. The rest is free border space.");
    for (var r = 0; r < 25; r++)
    {
        var _col = make_colour_rgb(30, 34, 41);
        if (r == 0) { _col = global.TH.warn; }
        if (r >= _e.wtop && r < _e.wtop + _e.wrows) { _col = global.TH.accent_dark; }
        draw_set_colour(_col);
        draw_rectangle(_lx, _y + r * _sc, _lx + 40 * _sc - 1, _y + (r + 1) * _sc - 2, false);
    }
    ui_text(_lx + 40 * _sc + 6, _y, "score", global.TH.warn, fa_left, fa_top, global.f_small, 1);
    ui_text(_lx + 40 * _sc + 6, _y + _e.wtop * _sc, string(_e.wrows) + " rows", global.TH.accent, fa_left, fa_top, global.f_small, 1);
}

// ---------------------------------------------------------------- charset

function ch_get(_c, _x, _y)
{
    return (proj.charset[_c * 8 + _y] >> (7 - _x)) & 1;
}

function ch_set(_c, _x, _y, _v)
{
    var _i = _c * 8 + _y;
    if (_v) { proj.charset[_i] = proj.charset[_i] | (128 >> _x); }
    else { proj.charset[_i] = proj.charset[_i] & ~(128 >> _x); }
}

function ws_charset_draw(_x1, _y1, _x2, _y2)
{
    pchars_refresh();
    var _lw = 300;
    ui_panel(_x1, _y1, _x1 + _lw, _y2, "Character set");
    var _gx = _x1 + 22;
    var _gy = _y1 + 56;
    ui_inset(_gx - 6, _gy - 6, _gx + 262, _gy + 262, 8);
    draw_set_colour(c64col(proj.eng.bg));
    draw_rectangle(_gx, _gy, _gx + 255, _gy + 255, false);
    gpu_set_texfilter(false);
    draw_sprite_ext(pchars_sprite, 0, _gx, _gy, 2, 2, 0, c_white, 1);
    gpu_set_texfilter(true);
    var _hot = ui_register("ch_grid", _gx, _gy, _gx + 255, _gy + 255, "Character set|All 256 characters your tiles are built from. Click one to edit it. Characters 128 and up are free for your own graphics in the templates.");
    ui_rrect_line(_gx + (ch_sel mod 16) * 16 - 2, _gy + (ch_sel div 16) * 16 - 2, _gx + (ch_sel mod 16) * 16 + 18, _gy + (ch_sel div 16) * 16 + 18, 4, global.TH.warn, 1, 2);
    if (_hot)
    {
        var _hc = clamp(floor((ui_mx - _gx) / 16), 0, 15) + clamp(floor((ui_my - _gy) / 16), 0, 15) * 16;
        ui_rrect_line(_gx + (_hc mod 16) * 16 - 2, _gy + (_hc div 16) * 16 - 2, _gx + (_hc mod 16) * 16 + 18, _gy + (_hc div 16) * 16 + 18, 4, global.TH.accent, 1, 1);
        ui_help_body = "Character " + string(_hc) + ". Click to edit it.";
        if (ui_pressed) { ch_sel = _hc; ui_take_click(); }
    }
    var _y = _gy + 280;
    ui_heading(_gx, _y, "Whole set");
    _y += 20;
    if (ui_button("ch_rom_all", _gx, _y, 256, 32, "Reset all to C64 ROM font", "Reset all|Copies the original Commodore character set over every character. You can Undo this.", BTN_DANGER))
    {
        undo_mark("chrom" + string(current_time));
        array_copy(proj.charset, 0, global.chargen_rom, 0, 2048);
        charset_dirty = true;
    }
    _y += 44;
    ui_text_wrap(_gx, _y, "Tip: draw your tile graphics into characters 128-255; letters and numbers stay usable for the score bar.", global.TH.text_faint, 256, global.f_small, 1);

    // pixel editor
    var _cx1 = _x1 + _lw + 12;
    var _rw = 300;
    var _cx2 = _x2 - _rw - 12;
    ui_panel(_cx1, _y1, _cx2, _y2, "Character " + string(ch_sel));
    var _ps = floor(min((_cx2 - _cx1 - 80) / 8, (_y2 - _y1 - 120) / 8));
    var _ex = floor((_cx1 + _cx2 - _ps * 8) / 2);
    var _ey = _y1 + 70;
    ui_rrect(_ex - 8, _ey - 8, _ex + _ps * 8 + 8, _ey + _ps * 8 + 8, 10, c_black, c_black, 0.35);
    draw_set_colour(c64col(proj.eng.bg));
    draw_rectangle(_ex, _ey, _ex + _ps * 8 - 1, _ey + _ps * 8 - 1, false);
    var _mcv = ch_mc_view;
    var _cols = [proj.eng.bg, proj.eng.mc1, proj.eng.mc2, ch_colour & 7];
    for (var py = 0; py < 8; py++)
    {
        var _b = proj.charset[ch_sel * 8 + py];
        if (_mcv)
        {
            for (var pp = 0; pp < 4; pp++)
            {
                var _v = (_b >> (6 - pp * 2)) & 3;
                if (_v != 0)
                {
                    draw_set_colour(c64col(_cols[_v]));
                    draw_rectangle(_ex + pp * 2 * _ps, _ey + py * _ps, _ex + (pp * 2 + 2) * _ps - 1, _ey + (py + 1) * _ps - 1, false);
                }
            }
        }
        else
        {
            for (var px = 0; px < 8; px++)
            {
                if (((_b >> (7 - px)) & 1) != 0)
                {
                    draw_set_colour(c64col(ch_colour));
                    draw_rectangle(_ex + px * _ps, _ey + py * _ps, _ex + (px + 1) * _ps - 1, _ey + (py + 1) * _ps - 1, false);
                }
            }
        }
    }
    draw_set_alpha(0.15);
    for (var gl = 0; gl <= 8; gl++)
    {
        draw_line_colour(_ex + gl * _ps, _ey, _ex + gl * _ps, _ey + _ps * 8, c_white, c_white);
        draw_line_colour(_ex, _ey + gl * _ps, _ex + _ps * 8, _ey + gl * _ps, c_white, c_white);
    }
    draw_set_alpha(1);
    var _eh = ui_register("ch_edit", _ex, _ey, _ex + _ps * 8 - 1, _ey + _ps * 8 - 1, "Pixel editor|Left-click draws, right-click rubs out. In multicolour view each pixel is two wide and uses the pen colour you pick.");
    if (_eh)
    {
        var _hx = clamp(floor((ui_mx - _ex) / _ps), 0, 7);
        var _hy = clamp(floor((ui_my - _ey) / _ps), 0, 7);
        var _cw2 = 1;
        if (_mcv) { _hx = _hx & 6; _cw2 = 2; }
        draw_rectangle_colour(_ex + _hx * _ps, _ey + _hy * _ps, _ex + (_hx + _cw2) * _ps - 1, _ey + (_hy + 1) * _ps - 1, c_white, c_white, c_white, c_white, true);
        if (ui_pressed || ui_rpressed)
        {
            undo_mark("chdraw" + string(current_time));
            ch_drawing = true;
            ui_take_click();
        }
        if (ch_drawing && (ui_held || ui_rheld))
        {
            if (_mcv)
            {
                var _pen = ch_pen;
                if (ui_rheld) { _pen = 0; }
                ch_set(ch_sel, _hx, _hy, (_pen >> 1) & 1);
                ch_set(ch_sel, _hx + 1, _hy, _pen & 1);
            }
            else
            {
                ch_set(ch_sel, _hx, _hy, ui_held);
            }
            charset_dirty = true;
            proj_dirty = true;
        }
    }
    if (!ui_held && !ui_rheld) { ch_drawing = false; }
    // actual size previews
    var _py2 = _ey + _ps * 8 + 24;
    ui_text(_ex, _py2, "1x", global.TH.text_faint, fa_left, fa_top, global.f_small, 1);
    draw_set_colour(c64col(proj.eng.bg));
    draw_rectangle(_ex + 20, _py2, _ex + 20 + 24 * 3, _py2 + 24, false);
    for (var rep = 0; rep < 3; rep++) { draw_pchar(ch_sel, _ex + 20 + rep * 8, _py2, 1, ch_colour, _mcv); draw_pchar(ch_sel, _ex + 20 + rep * 8, _py2 + 8, 1, ch_colour, _mcv); draw_pchar(ch_sel, _ex + 20 + rep * 8, _py2 + 16, 1, ch_colour, _mcv); }

    // tools
    var _px = _x2 - _rw;
    ui_panel(_px, _y1, _x2, _y2, "Tools");
    var _fx = _px + 20;
    var _fw = _rw - 40;
    var _y3 = _y1 + 56;
    ch_mc_view = ui_toggle("ch_mc", _fx, _y3, "Multicolour view", ch_mc_view, "Multicolour view|Edit this character as 4 wide pixels with 4 colours. Use it for tiles that have MC ticked.");
    _y3 += 36;
    ui_heading(_fx, _y3, "Preview colour");
    ch_colour = ui_colour_drop("ch_col", _fx, _y3 + 18, _fw, 30, ch_colour, "Preview colour|Only for viewing here. Tiles choose their own colour.");
    _y3 += 60;
    if (ch_mc_view)
    {
        ui_heading(_fx, _y3, "Pen");
        var _pnames = ["Background", "Char colour A", "Char colour B", "Tile colour"];
        for (var pn = 0; pn < 4; pn++)
        {
            var _bxp = _fx + (pn mod 2) * (_fw div 2 + 4);
            var _byp = _y3 + 18 + (pn div 2) * 38;
            var _st = BTN_GHOST;
            if (ch_pen == pn) { _st = BTN_ACCENT; }
            if (ui_button("ch_pen_" + string(pn), _bxp, _byp, _fw div 2 - 4, 32, _pnames[pn], "Pen|The colour slot you draw with in multicolour view.", _st)) { ch_pen = pn; }
        }
        _y3 += 104;
    }
    ui_heading(_fx, _y3, "Change this character");
    _y3 += 18;
    var _ops = ["Flip H", "Flip V", "Invert", "Left", "Right", "Clear", "Up", "Down", "ROM"];
    var _bw = floor((_fw - 16) / 3);
    for (var o = 0; o < 9; o++)
    {
        var _ox = _fx + (o mod 3) * (_bw + 8);
        var _oy = _y3 + (o div 3) * 38;
        var _st2 = BTN_NORMAL;
        if (o == 5) { _st2 = BTN_DANGER; }
        if (ui_button("ch_op_" + string(o), _ox, _oy, _bw, 32, _ops[o], _ops[o] + "|Changes the selected character. ROM copies the original C64 shape back.", _st2))
        {
            undo_mark("chop" + string(current_time));
            var _rows = array_create(8, 0);
            for (var k = 0; k < 8; k++) { _rows[k] = proj.charset[ch_sel * 8 + k]; }
            for (var k2 = 0; k2 < 8; k2++)
            {
                var _v2 = _rows[k2];
                switch (o)
                {
                    case 0:
                        var _rv = 0;
                        for (var bb = 0; bb < 8; bb++) { if ((_v2 & (1 << bb)) != 0) { _rv = _rv | (128 >> bb); } }
                        _v2 = _rv;
                        break;
                    case 1: _v2 = _rows[7 - k2]; break;
                    case 2: _v2 = (~_v2) & 255; break;
                    case 3: _v2 = (_v2 << 1) & 255; break;
                    case 4: _v2 = _v2 >> 1; break;
                    case 5: _v2 = 0; break;
                    case 6: if (k2 < 7) { _v2 = _rows[k2 + 1]; } else { _v2 = 0; } break;
                    case 7: if (k2 > 0) { _v2 = _rows[k2 - 1]; } else { _v2 = 0; } break;
                    case 8: _v2 = global.chargen_rom[ch_sel * 8 + k2]; break;
                }
                proj.charset[ch_sel * 8 + k2] = _v2;
            }
            charset_dirty = true;
        }
    }
    _y3 += 3 * 38 + 6;
    if (ui_button("ch_copy", _fx, _y3, _fw div 2 - 4, 32, "Copy", "Copy|Remembers this character.", BTN_NORMAL))
    {
        ch_clip = [];
        for (var c1 = 0; c1 < 8; c1++) { array_push(ch_clip, proj.charset[ch_sel * 8 + c1]); }
        toast("Character copied", 0);
    }
    if (ui_button("ch_paste", _fx + _fw div 2 + 4, _y3, _fw div 2 - 4, 32, "Paste", "Paste|Puts the copied character here.", BTN_NORMAL))
    {
        if (array_length(ch_clip) == 8)
        {
            undo_mark("chpaste" + string(current_time));
            for (var c2 = 0; c2 < 8; c2++) { proj.charset[ch_sel * 8 + c2] = ch_clip[c2]; }
            charset_dirty = true;
        }
    }
}

// ---------------------------------------------------------------- tiles

// ---------------------------------------------------------------- map

function ws_map_draw(_x1, _y1, _x2, _y2)
{
    var _nl = array_length(proj.levels);
    map_level = clamp(map_level, 0, _nl - 1);
    var _lv = proj.levels[map_level];
    var _lw = 250;
    var _rw = 290;

    // ---- left: levels + tools
    ui_panel(_x1, _y1, _x1 + _lw, _y2, "Levels");
    var _fx = _x1 + 16;
    var _fw = _lw - 32;
    var _y = _y1 + 54;
    for (var l = 0; l < _nl; l++)
    {
        var _st = BTN_GHOST;
        if (l == map_level) { _st = BTN_ACCENT; }
        if (ui_button("map_lv_" + string(l), _fx, _y, _fw, 30, string(l + 1) + ". " + proj.levels[l].name, "Level " + string(l + 1) + "|Click to edit this level. Levels are played in order; reaching an exit goes to the next one.", _st)) { map_level = l; }
        _y += 34;
    }
    var _half = (_fw - 8) div 2;
    if (ui_button("map_lv_add", _fx, _y, _half, 30, "+ Level", "Add level|Adds a new level with the same size as this one (up to 8).", BTN_NORMAL))
    {
        if (_nl < 8)
        {
            undo_mark("lvadd" + string(current_time));
            array_push(proj.levels, level_new("Level " + string(_nl + 1), _lv.w, _lv.h));
            map_level = _nl;
        }
    }
    if (ui_button("map_lv_del", _fx + _half + 8, _y, _half, 30, "Remove", "Remove level|Deletes this level. You can Undo this.", BTN_DANGER))
    {
        if (_nl > 1)
        {
            undo_mark("lvdel" + string(current_time));
            array_delete(proj.levels, map_level, 1);
            map_level = max(0, map_level - 1);
            return;
        }
    }
    _y += 42;
    ui_heading(_fx, _y, "Name");
    set_val(_lv, "name", ui_textfield("map_name", _fx, _y + 18, _fw, 30, _lv.name, 20, "Level name|For your own reference."), "lvname");
    _y += 58;
    ui_heading(_fx, _y, "Size in tiles (width / height)");
    var _nw = ui_stepper("map_w", _fx, _y + 18, _half, _lv.w, eng_min_w(), 255, "Map width|Tiles across (each tile is 16 pixels). The screen shows 20 at a time. Hold Shift for steps of 10.");
    var _nh = ui_stepper("map_h", _fx + _half + 8, _y + 18, _half, _lv.h, eng_min_h(proj.eng), 255, "Map height|Tiles down. Hold Shift for steps of 10.");
    if (_nw != _lv.w || _nh != _lv.h)
    {
        if (_nw * _nh <= 16384)
        {
            undo_mark("lvsize");
            level_resize(_lv, _nw, _nh);
        }
        else { toast("Maps can hold at most 16384 tiles", 1); }
    }
    _y += 58;
    ui_heading(_fx, _y, "Items to collect before exit");
    set_val(_lv, "need", ui_stepper("map_need", _fx, _y + 18, _fw, _lv.need, 0, 99, "Collect target|How many Collect tiles the player needs before Exit tiles work. 0 = exits always open."), "lvneed");
    _y += 62;
    ui_heading(_fx, _y, "Tools");
    _y += 18;
    var _tools = ["Paint", "Box", "Fill", "Spawners", "Start", "Pick"];
    var _thelp = ["Paint|Left-click paints the selected tile, right-click paints the empty tile.",
                  "Box|Drag a rectangle to fill it with the selected tile. Right-drag clears.",
                  "Fill|Flood-fills the connected area of the same tile.",
                  "Spawners|Click to place an enemy spawner, drag to move it, right-click to delete. Its settings are on the right.",
                  "Player start|Click where the player begins the level.",
                  "Pick|Click a tile on the map to select it for painting (also Alt-click with any tool)."];
    for (var t = 0; t < 6; t++)
    {
        var _sty = BTN_NORMAL;
        if (map_tool == t) { _sty = BTN_ACCENT; }
        if (ui_button("map_tool_" + string(t), _fx + (t mod 2) * (_half + 8), _y + (t div 2) * 38, _half, 32, _tools[t], _thelp[t], _sty)) { map_tool = t; }
    }
    _y += 3 * 38 + 8;
    map_show_window = ui_toggle("map_win", _fx, _y, "Screen-size guide", map_show_window, "Screen-size guide|Shows how much of the map fits in the play window, centred on the mouse.");
    _y += 32;
    ui_heading(_fx, _y, "Zoom");
    map_zoom = ui_stepper("map_zoom", _fx, _y + 18, _fw, map_zoom, 8, 48, "Zoom|Size of a tile on screen in pixels. Mouse wheel scrolls, Shift+wheel scrolls sideways, middle-drag pans.");

    // ---- centre: the map
    var _cx1 = _x1 + _lw + 12;
    var _cx2 = _x2 - _rw - 12;
    ui_panel(_cx1, _y1, _cx2, _y2, "");
    var _vx1 = _cx1 + 12;
    var _vy1 = _y1 + 12;
    var _vx2 = _cx2 - 12;
    var _vy2 = _y2 - 40;
    ui_inset(_vx1 - 2, _vy1 - 2, _vx2 + 2, _vy2 + 2, 8);
    var _z = map_zoom;
    var _maxsx = max(0, _lv.w * _z - (_vx2 - _vx1));
    var _maxsy = max(0, _lv.h * _z - (_vy2 - _vy1));
    var _inview = ui_hit(_vx1, _vy1, _vx2, _vy2);
    if (_inview && ui_wheel != 0)
    {
        if (keyboard_check(vk_shift)) { map_sx -= ui_wheel * _z * 3; }
        else { map_sy -= ui_wheel * _z * 3; }
        ui_wheel = 0;
    }
    if (_inview && mouse_check_button_pressed(mb_middle)) { map_pan = true; map_pan_mx = ui_mx; map_pan_my = ui_my; }
    if (!mouse_check_button(mb_middle)) { map_pan = false; }
    if (map_pan)
    {
        map_sx -= ui_mx - map_pan_mx;
        map_sy -= ui_my - map_pan_my;
        map_pan_mx = ui_mx;
        map_pan_my = ui_my;
    }
    map_sx = clamp(map_sx, 0, _maxsx);
    map_sy = clamp(map_sy, 0, _maxsy);
    ui_scissor(_vx1, _vy1, _vx2 - _vx1, _vy2 - _vy1);
    draw_set_colour(c64col(proj.eng.bg));
    draw_rectangle(_vx1, _vy1, min(_vx2, _vx1 + _lv.w * _z - map_sx), min(_vy2, _vy1 + _lv.h * _z - map_sy), false);
    var _tx0 = floor(map_sx / _z);
    var _ty0 = floor(map_sy / _z);
    var _tx1 = min(_lv.w - 1, _tx0 + ceil((_vx2 - _vx1) / _z) + 1);
    var _ty1 = min(_lv.h - 1, _ty0 + ceil((_vy2 - _vy1) / _z) + 1);
    atlas_refresh();
    gpu_set_texfilter(false);
    for (var ty = _ty0; ty <= _ty1; ty++)
    {
        for (var tx = _tx0; tx <= _tx1; tx++)
        {
            var _tile = _lv.map[ty * _lv.w + tx];
            if (_tile > 0)
            {
                var _ti = min(_tile, 63);
                draw_surface_part_ext(tile_atlas, (_ti mod 8) * 16, (_ti div 8) * 16, 16, 16, _vx1 + tx * _z - map_sx, _vy1 + ty * _z - map_sy, _z / 16, _z / 16, c_white, 1);
            }
        }
    }
    gpu_set_texfilter(true);
    if (_z >= 16)
    {
        draw_set_alpha(0.08);
        for (var gx = _tx0; gx <= _tx1 + 1; gx++) { draw_line_colour(_vx1 + gx * _z - map_sx, _vy1, _vx1 + gx * _z - map_sx, _vy2, c_white, c_white); }
        for (var gy = _ty0; gy <= _ty1 + 1; gy++) { draw_line_colour(_vx1, _vy1 + gy * _z - map_sy, _vx2, _vy1 + gy * _z - map_sy, c_white, c_white); }
        draw_set_alpha(1);
    }
    // spawners
    for (var s = 0; s < array_length(_lv.spawners); s++)
    {
        var _sp = _lv.spawners[s];
        var _sx = _vx1 + _sp.x * _z - map_sx;
        var _sy = _vy1 + _sp.y * _z - map_sy;
        if (_sp.type < array_length(proj.enemies))
        {
            var _en = proj.enemies[_sp.type];
            draw_sprite_c64(_en.spr, _sx, _sy, _z / 21, _en.col, 0.95);
        }
        var _scol = global.TH.danger;
        if (s == map_spawner_sel && map_tool == 3) { _scol = global.TH.warn; }
        ui_rrect_line(_sx - 1, _sy - 1, _sx + _z + 1, _sy + _z + 1, 4, _scol, 0.9, 1);
        if (_sp.count > 1) { ui_text(_sx + _z, _sy, "x" + string(_sp.count), c_white, fa_right, fa_top, global.f_small, 1); }
    }
    // player start
    var _psx = _vx1 + _lv.px * _z - map_sx;
    var _psy = _vy1 + _lv.py * _z - map_sy;
    draw_sprite_c64(proj.eng.pspr, _psx, _psy, _z / 21, proj.eng.pcol, 1);
    ui_rrect_line(_psx - 2, _psy - 2, _psx + _z + 2, _psy + _z + 2, 4, global.TH.accent2, 1, 2);
    ui_text(_psx, _psy - 2, "START", global.TH.accent2, fa_left, fa_bottom, global.f_small, 1);

    // interaction
    var _hot = ui_register("map_view", _vx1, _vy1, _vx2, _vy2, "Map|Paint tiles with the left button, the empty tile with the right. Wheel scrolls, Shift+wheel scrolls sideways, middle-drag pans.");
    var _mx = floor((ui_mx - _vx1 + map_sx) / _z);
    var _my = floor((ui_my - _vy1 + map_sy) / _z);
    var _inside = (_hot && _mx >= 0 && _my >= 0 && _mx < _lv.w && _my < _lv.h);
    if (_inside)
    {
        var _hx = _vx1 + _mx * _z - map_sx;
        var _hy = _vy1 + _my * _z - map_sy;
        if (map_show_window)
        {
            var _ww = 20 * _z;
            var _wh = (proj.eng.wrows / 2) * _z;
            var _wx = _hx + _z / 2 - _ww / 2;
            var _wy = _hy + _z / 2 - _wh / 2;
            ui_dotted_line(_wx, _wy, _wx + _ww, _wy, global.TH.warn, 0.8, 6);
            ui_dotted_line(_wx, _wy + _wh, _wx + _ww, _wy + _wh, global.TH.warn, 0.8, 6);
            ui_dotted_line(_wx, _wy, _wx, _wy + _wh, global.TH.warn, 0.8, 6);
            ui_dotted_line(_wx + _ww, _wy, _wx + _ww, _wy + _wh, global.TH.warn, 0.8, 6);
        }
        draw_set_alpha(0.25);
        draw_set_colour(global.TH.accent);
        draw_rectangle(_hx, _vy1, _hx + _z - 1, _vy2, true);
        draw_rectangle(_vx1, _hy, _vx2, _hy + _z - 1, true);
        draw_set_alpha(1);
        draw_rectangle_colour(_hx, _hy, _hx + _z - 1, _hy + _z - 1, c_white, c_white, c_white, c_white, true);
        var _cur = _lv.map[_my * _lv.w + _mx];
        var _nm = "";
        if (_cur < array_length(proj.tiles)) { _nm = proj.tiles[_cur].name; }
        ui_help_body = "Tile " + string(_mx) + ", " + string(_my) + " - " + _nm;
        var _alt = keyboard_check(vk_alt);
        if ((map_tool == 5 || _alt) && ui_pressed)
        {
            map_tile = _cur;
            ui_take_click();
        }
        if (map_tool == 0 && !_alt)
        {
            if (ui_pressed || ui_rpressed) { undo_mark("mpaint" + string(current_time)); map_drawing = true; ui_take_click(); }
            if (map_drawing && ui_held) { _lv.map[_my * _lv.w + _mx] = map_tile; proj_dirty = true; }
            if (map_drawing && ui_rheld) { _lv.map[_my * _lv.w + _mx] = 0; proj_dirty = true; }
        }
        if (map_tool == 1 && !_alt && (ui_pressed || ui_rpressed))
        {
            map_box_x = _mx;
            map_box_y = _my;
            map_box_clear = ui_rpressed;
            map_drawing = true;
            ui_take_click();
        }
        if (map_tool == 2 && ui_pressed && !_alt)
        {
            undo_mark("mfill" + string(current_time));
            map_flood(_lv, _mx, _my, map_tile);
            ui_take_click();
        }
        if (map_tool == 3)
        {
            var _found = -1;
            for (var f = 0; f < array_length(_lv.spawners); f++)
            {
                if (_lv.spawners[f].x == _mx && _lv.spawners[f].y == _my) { _found = f; }
            }
            if (ui_pressed)
            {
                if (_found >= 0) { map_spawner_sel = _found; map_drag_sp = true; }
                else
                {
                    if (array_length(_lv.spawners) < 64)
                    {
                        undo_mark("spadd" + string(current_time));
                        var _ns = spawner_new(_mx, _my, clamp(enemy_sel, 0, array_length(proj.enemies) - 1));
                        array_push(_lv.spawners, _ns);
                        map_spawner_sel = array_length(_lv.spawners) - 1;
                    }
                    else { toast("A level can have up to 64 spawners", 1); }
                }
                ui_take_click();
            }
            if (ui_rpressed && _found >= 0)
            {
                undo_mark("spdel" + string(current_time));
                array_delete(_lv.spawners, _found, 1);
                map_spawner_sel = -1;
            }
            if (map_drag_sp && ui_held && map_spawner_sel >= 0 && map_spawner_sel < array_length(_lv.spawners))
            {
                _lv.spawners[map_spawner_sel].x = _mx;
                _lv.spawners[map_spawner_sel].y = _my;
                proj_dirty = true;
            }
        }
        if (map_tool == 4 && ui_pressed)
        {
            undo_mark("mstart" + string(current_time));
            _lv.px = _mx;
            _lv.py = _my;
            ui_take_click();
        }
    }
    if (map_tool == 1 && map_drawing)
    {
        var _bx1 = min(map_box_x, clamp(_mx, 0, _lv.w - 1));
        var _bx2 = max(map_box_x, clamp(_mx, 0, _lv.w - 1));
        var _by1 = min(map_box_y, clamp(_my, 0, _lv.h - 1));
        var _by2 = max(map_box_y, clamp(_my, 0, _lv.h - 1));
        ui_rrect_line(_vx1 + _bx1 * _z - map_sx - 2, _vy1 + _by1 * _z - map_sy - 2, _vx1 + (_bx2 + 1) * _z - map_sx + 2, _vy1 + (_by2 + 1) * _z - map_sy + 2, 4, global.TH.accent2, 1, 2);
        if (!ui_held && !ui_rheld)
        {
            undo_mark("mbox" + string(current_time));
            var _fillt = map_tile;
            if (map_box_clear) { _fillt = 0; }
            for (var yy = _by1; yy <= _by2; yy++)
            {
                for (var xx = _bx1; xx <= _bx2; xx++) { _lv.map[yy * _lv.w + xx] = _fillt; }
            }
            map_drawing = false;
        }
    }
    if (!ui_held && !ui_rheld)
    {
        if (map_tool != 1) { map_drawing = false; }
        map_drag_sp = false;
    }
    ui_scissor_reset();
    ui_text(_vx1, _vy2 + 12, string(_lv.w) + " x " + string(_lv.h) + " tiles   |   " + string(array_length(_lv.spawners)) + " spawners   |   zoom " + string(_z) + "px", global.TH.text_faint, fa_left, fa_top, global.f_small, 1);

    // ---- right: palette or spawner settings
    var _px = _x2 - _rw;
    if (map_tool == 3)
    {
        ui_panel(_px, _y1, _x2, _y2, "Spawner");
        var _sfx = _px + 20;
        var _sfw = _rw - 40;
        var _sy2 = _y1 + 56;
        if (map_spawner_sel < 0 || map_spawner_sel >= array_length(_lv.spawners))
        {
            ui_text_wrap(_sfx, _sy2, "Click on the map to place a spawner. It releases enemies when that spot scrolls into view. Click an existing spawner to change it, right-click to delete it.", global.TH.text_dim, _sfw, global.f_body, 1);
            _sy2 += 110;
            ui_heading(_sfx, _sy2, "New spawners use");
            enemy_sel = ui_dropdown("map_newtype", _sfx, _sy2 + 18, _sfw, 30, enemy_names(), clamp(enemy_sel, 0, array_length(proj.enemies) - 1), "Enemy type|The enemy type new spawners release.");
        }
        else
        {
            var _spr = _lv.spawners[map_spawner_sel];
            ui_text(_sfx, _sy2, "At tile " + string(_spr.x) + ", " + string(_spr.y), global.TH.text_dim, fa_left, fa_top, global.f_small, 1);
            _sy2 += 22;
            ui_heading(_sfx, _sy2, "Enemy type");
            set_val(_spr, "type", ui_dropdown("sp_type", _sfx, _sy2 + 18, _sfw, 30, enemy_names(), clamp(_spr.type, 0, array_length(proj.enemies) - 1), "Enemy type|Which kind of enemy comes out. Design types on the Enemies page."), "sptype");
            _sy2 += 60;
            var _sh = (_sfw - 8) div 2;
            ui_heading(_sfx, _sy2, "How many / every (frames)");
            set_val(_spr, "count", ui_stepper("sp_count", _sfx, _sy2 + 18, _sh, _spr.count, 1, 99, "Count|How many enemies this spawner releases in total."), "spcount");
            set_val(_spr, "interval", ui_stepper("sp_int", _sfx + _sh + 8, _sy2 + 18, _sh, _spr.interval, 1, 255, "Interval|Frames between each enemy (50 frames = 1 second). Hold Shift for steps of 10."), "spint");
            _sy2 += 60;
            ui_heading(_sfx, _sy2, "Direction");
            var _dopts = ["Use the enemy's own"];
            for (var d = 0; d < 8; d++) { array_push(_dopts, global.DIR_NAMES[d]); }
            var _di = _spr.dir + 1;
            if (_spr.dir > 7) { _di = 0; }
            var _nd = ui_dropdown("sp_dir", _sfx, _sy2 + 18, _sfw, 30, _dopts, _di, "Direction|Overrides the direction this spawner's enemies set off in.");
            var _ndv = _nd - 1;
            if (_nd == 0) { _ndv = 255; }
            set_val(_spr, "dir", _ndv, "spdir");
            _sy2 += 64;
            if (ui_button("sp_del", _sfx, _sy2, _sfw, 32, "Delete spawner", "Delete|Removes this spawner.", BTN_DANGER))
            {
                undo_mark("spdel" + string(current_time));
                array_delete(_lv.spawners, map_spawner_sel, 1);
                map_spawner_sel = -1;
            }
        }
    }
    else
    {
        ui_panel(_px, _y1, _x2, _y2, "Tile palette");
        var _nt = array_length(proj.tiles);
        var _cell = 52;
        var _cols = floor((_rw - 30) / _cell);
        var _gx2 = _px + 15;
        var _gy2 = _y1 + 56;
        var _content = ceil(_nt / _cols) * _cell + 10;
        var _off = ui_scroll_begin("map_pal", _px + 8, _gy2 - 4, _x2 - 8, _y2 - 80, _content);
        for (var p = 0; p < _nt; p++)
        {
            var _ppx = _gx2 + (p mod _cols) * _cell;
            var _ppy = _gy2 + (p div _cols) * _cell - _off;
            var _ph = ui_register("map_pal_" + string(p), _ppx, _ppy, _ppx + _cell - 6, _ppy + _cell - 6, proj.tiles[p].name + "|Click to paint with this tile.");
            ui_rrect(_ppx, _ppy, _ppx + _cell - 6, _ppy + _cell - 6, 6, c64col(proj.eng.bg), c64col(proj.eng.bg), 1);
            draw_tile_img(p, _ppx + 3, _ppy + 3, _cell - 12);
            if (p == map_tile) { ui_rrect_line(_ppx - 2, _ppy - 2, _ppx + _cell - 4, _ppy + _cell - 4, 7, global.TH.warn, 1, 2); }
            else { if (_ph) { ui_rrect_line(_ppx - 1, _ppy - 1, _ppx + _cell - 5, _ppy + _cell - 5, 7, global.TH.accent, 1, 1); } }
            if (_ph && ui_pressed)
            {
                map_tile = p;
                if (map_tool >= 3) { map_tool = 0; }
                ui_take_click();
            }
        }
        ui_scroll_end("map_pal", _px + 8, _gy2 - 4, _x2 - 8, _y2 - 80, _content);
        if (map_tile < _nt)
        {
            ui_text(_px + 20, _y2 - 66, string(map_tile) + ": " + proj.tiles[map_tile].name, global.TH.text, fa_left, fa_top, global.f_bold, 1);
        }
        if (ui_button("map_edittile", _px + 20, _y2 - 44, _rw - 40, 30, "Edit this tile", "Edit tile|Opens the Tiles page with this tile selected.", BTN_GHOST))
        {
            tile_sel = map_tile;
            ws_set(WS_TILES);
        }
    }
}

function map_flood(_lv, _x, _y, _t)
{
    var _from = _lv.map[_y * _lv.w + _x];
    if (_from == _t) { return; }
    var _stack = [[_x, _y]];
    var _guard = 0;
    while (array_length(_stack) > 0 && _guard < 70000)
    {
        _guard += 1;
        var _c = array_pop(_stack);
        var _cx = _c[0];
        var _cy = _c[1];
        if (_cx < 0 || _cy < 0 || _cx >= _lv.w || _cy >= _lv.h) { continue; }
        if (_lv.map[_cy * _lv.w + _cx] != _from) { continue; }
        _lv.map[_cy * _lv.w + _cx] = _t;
        array_push(_stack, [_cx + 1, _cy], [_cx - 1, _cy], [_cx, _cy + 1], [_cx, _cy - 1]);
    }
}

// ---------------------------------------------------------------- enemies

function ws_enemies_draw(_x1, _y1, _x2, _y2)
{
    var _ne = array_length(proj.enemies);
    enemy_sel = clamp(enemy_sel, 0, _ne - 1);
    var _en = proj.enemies[enemy_sel];
    var _lw = 260;
    ui_panel(_x1, _y1, _x1 + _lw, _y2, "Enemy types  (" + string(_ne) + " / 16)");
    var _content = _ne * 54 + 10;
    var _off = ui_scroll_begin("en_list", _x1 + 8, _y1 + 50, _x1 + _lw - 8, _y2 - 140, _content);
    for (var i = 0; i < _ne; i++)
    {
        var _ry = _y1 + 54 + i * 54 - _off;
        if (_ry < _y1 + 10 || _ry > _y2 - 140) { continue; }
        var _e2 = proj.enemies[i];
        var _hot = ui_register("en_slot_" + string(i), _x1 + 12, _ry, _x1 + _lw - 18, _ry + 48, _e2.name + "|Click to edit this enemy type.");
        if (enemy_sel == i) { ui_rrect(_x1 + 12, _ry, _x1 + _lw - 18, _ry + 48, 9, global.TH.accent, global.TH.accent_dark, 0.9); }
        else { if (_hot) { ui_rrect(_x1 + 12, _ry, _x1 + _lw - 18, _ry + 48, 9, global.TH.btn_hot_top, global.TH.btn_hot_bot, 1); } }
        ui_rrect(_x1 + 18, _ry + 4, _x1 + 58, _ry + 44, 6, c64col(proj.eng.bg), c64col(proj.eng.bg), 1);
        draw_sprite_c64(_e2.spr, _x1 + 22, _ry + 7, 1.5, _e2.col, 1);
        ui_text(_x1 + 68, _ry + 15, ui_text_fit(_e2.name, global.f_bold, _lw - 100), global.TH.text, fa_left, fa_middle, global.f_bold, 1);
        ui_text(_x1 + 68, _ry + 34, global.MOVE_NAMES[clamp(_e2.move, 0, 6)], global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
        if (_hot && ui_pressed) { enemy_sel = i; ui_take_click(); }
    }
    ui_scroll_end("en_list", _x1 + 8, _y1 + 50, _x1 + _lw - 8, _y2 - 140, _content);
    var _by = _y2 - 128;
    if (ui_button("en_add", _x1 + 16, _by, _lw - 32, 34, "Add enemy type", "Add enemy|Adds a new enemy type (up to 16). Place it on the map with the Spawners tool.", BTN_ACCENT))
    {
        if (_ne < 16)
        {
            undo_mark("enadd" + string(current_time));
            array_push(proj.enemies, enemy_new("Enemy " + string(_ne + 1)));
            enemy_sel = _ne;
        }
    }
    if (ui_button("en_dup", _x1 + 16, _by + 42, _lw - 32, 34, "Duplicate", "Duplicate|Copies this enemy type.", BTN_NORMAL))
    {
        if (_ne < 16)
        {
            undo_mark("endup" + string(current_time));
            var _cp = struct_overlay(enemy_new(""), json_parse(json_stringify(_en)));
            _cp.name += " 2";
            array_push(proj.enemies, _cp);
            enemy_sel = _ne;
        }
    }
    if (ui_button("en_del", _x1 + 16, _by + 84, _lw - 32, 34, "Remove", "Remove|Deletes this type and every spawner that used it. You can Undo this.", BTN_DANGER))
    {
        if (_ne > 1)
        {
            undo_mark("endel" + string(current_time));
            enemy_remove(enemy_sel);
            enemy_sel = max(0, enemy_sel - 1);
            return;
        }
    }

    // centre: preview with movement trail
    var _cx1 = _x1 + _lw + 12;
    var _rw = 320;
    var _cx2 = _x2 - _rw - 12;
    ui_panel(_cx1, _y1, _cx2, _y2, _en.name);
    var _vx = _cx1 + 20;
    var _vy = _y1 + 56;
    var _vw = _cx2 - _cx1 - 40;
    var _vh = min(360, _y2 - _y1 - 140);
    ui_inset(_vx, _vy, _vx + _vw, _vy + _vh, 10);
    ui_register("en_preview", _vx, _vy, _vx + _vw, _vy + _vh, "Movement preview|A rough picture of how this enemy moves and where it shoots. The real game also bounces off walls and the screen edge.");
    ui_scissor(_vx, _vy, _vw, _vh);
    var _dxs = [0, 1, 1, 1, 0, -1, -1, -1];
    var _dys = [-1, -1, 0, 1, 1, 1, 0, -1];
    var _sx = _vx + _vw / 2;
    var _sy = _vy + _vh / 2;
    var _tt = (current_time / 20) mod 240;
    var _px = _sx;
    var _py = _sy;
    var _ddir = _en.dir;
    for (var k = 0; k <= 240; k += 4)
    {
        var _nx = _sx;
        var _ny = _sy;
        switch (_en.move)
        {
            case 0: break;
            case 1: case 4: case 5: case 6:
                _nx = _sx + _dxs[_ddir] * k * _en.spd * 0.6;
                _ny = _sy + _dys[_ddir] * k * _en.spd * 0.6;
                break;
            case 2:
                _nx = _sx + _dxs[_ddir] * k * _en.spd * 0.6;
                _ny = _sy + _dys[_ddir] * k * _en.spd * 0.6;
                var _w = sin(k / 10) * 24;
                if (_dxs[_ddir] != 0) { _ny += _w; } else { _nx += _w; }
                break;
            case 3:
                _nx = _sx + sin(k / 40) * 40;
                _ny = _sy + k * 0.3 * _en.spd;
                break;
        }
        draw_set_alpha(0.35);
        draw_line_width_colour(_px, _py, _nx, _ny, 2, global.TH.accent, global.TH.accent);
        draw_set_alpha(1);
        if (abs(k - _tt) < 4) { draw_sprite_c64(_en.spr, _nx - 24, _ny - 21, 2, _en.col, 1); }
        _px = _nx;
        _py = _ny;
    }
    if (_en.move == 0) { draw_sprite_c64(_en.spr, _sx - 24, _sy - 21, 2, _en.col, 1); }
    if (_en.fire > 0)
    {
        var _fd = _en.fdir;
        var _fx2 = _sx + _dxs[_fd] * 120;
        var _fy2 = _sy + _dys[_fd] * 120;
        var _lab = "shoots " + string_lower(global.DIR_NAMES[_fd]);
        if (_en.fire == 2) { _fx2 = _vx + 40; _fy2 = _vy + _vh - 40; _lab = "aims at the player"; draw_sprite_c64(proj.eng.pspr, _fx2 - 12, _fy2 - 10, 1, proj.eng.pcol, 0.8); }
        ui_dotted_line(_sx, _sy, _fx2, _fy2, global.TH.danger, 0.9, 5);
        ui_text(_fx2, _fy2 + 12, _lab, global.TH.danger, fa_center, fa_top, global.f_small, 1);
    }
    ui_scissor_reset();
    var _sy2 = _vy + _vh + 16;
    ui_text_wrap(_vx, _sy2, "Enemies appear from spawners you place on the Map page. Each spawner chooses a type, how many come out and how often.", global.TH.text_faint, _vw, global.f_small, 1);

    // right: settings
    var _rx = _x2 - _rw;
    ui_panel(_rx, _y1, _x2, _y2, "Enemy settings");
    var _fx = _rx + 20;
    var _fw = _rw - 40;
    var _half = (_fw - 12) div 2;
    var _y = _y1 + 56;
    ui_heading(_fx, _y, "Name");
    set_val(_en, "name", ui_textfield("en_name", _fx, _y + 18, _fw, 30, _en.name, 20, "Name|Shown in the spawner settings."), "enname");
    _y += 58;
    ui_heading(_fx, _y, "Sprite / colour");
    set_val(_en, "spr", ui_dropdown("en_spr", _fx, _y + 18, _half, 30, sprite_names(), _en.spr, "Sprite|The picture for this enemy."), "enspr");
    set_val(_en, "col", ui_colour_drop("en_col", _fx + _half + 12, _y + 18, _half, 30, _en.col, "Colour|The sprite's own colour."), "encol");
    _y += 58;
    ui_heading(_fx, _y, "Movement");
    set_val(_en, "move", ui_dropdown("en_move", _fx, _y + 18, _fw, 30, global.MOVE_NAMES, _en.move, "Movement|Straight flies in its direction, sine weaves, homing follows the player, bounce rebounds off walls and the screen edge, walkers patrol platforms and turn at ledges, crawlers follow walls."), "enmove");
    _y += 58;
    ui_heading(_fx, _y, "Direction / speed");
    set_val(_en, "dir", ui_dropdown("en_dir", _fx, _y + 18, _half, 30, global.DIR_NAMES, _en.dir, "Direction|Which way it sets off. Spawners can override this."), "endir");
    set_val(_en, "spd", ui_stepper("en_spd", _fx + _half + 12, _y + 18, _half, _en.spd, 1, 6, "Speed|Pixels per frame."), "enspd");
    _y += 58;
    ui_heading(_fx, _y, "Hit points / points");
    set_val(_en, "hp", ui_stepper("en_hp", _fx, _y + 18, _half, _en.hp, 1, 99, "Hit points|How many shots it takes to destroy."), "enhp");
    set_val(_en, "score", ui_stepper("en_score", _fx + _half + 12, _y + 18, _half, _en.score, 0, 99, "Points|Added to the score when destroyed."), "enscore");
    _y += 58;
    ui_heading(_fx, _y, "Shooting");
    set_val(_en, "fire", ui_dropdown("en_fire", _fx, _y + 18, _fw, 30, global.FIRE_NAMES, _en.fire, "Shooting|Whether this enemy shoots, and whether it aims at the player. Enemy shots share the sprite set on the World page."), "enfire");
    _y += 58;
    if (_en.fire > 0)
    {
        ui_heading(_fx, _y, "Fire every (frames) / direction");
        set_val(_en, "rate", ui_stepper("en_rate", _fx, _y + 18, _half, _en.rate, 10, 255, "Fire rate|Frames between shots (50 = once a second)."), "enrate");
        if (_en.fire == 1) { set_val(_en, "fdir", ui_dropdown("en_fdir", _fx + _half + 12, _y + 18, _half, 30, global.DIR_NAMES, _en.fdir, "Shot direction|Which way its shots travel."), "enfdir"); }
        _y += 58;
    }
}
