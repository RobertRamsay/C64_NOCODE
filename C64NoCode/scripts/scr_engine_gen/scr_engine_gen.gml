/// C64 NO-CODE STUDIO - map game engine: data model + code generator
/// The 6502 engine lives in datafiles/engine/engine.asm; this script adds the
/// configuration, generated shift routines and all the game data.

#macro KIND_SHMUP 1
#macro KIND_PLAT 2
#macro KIND_CAVE 3
#macro KIND_TOP 4
#macro SCROLL_NONE 0
#macro SCROLL_H 1
#macro SCROLL_V 2
#macro SCROLL_8 3
#macro SCROLL_FLIP 4

#macro TA_SOLID 1
#macro TA_DEADLY 2
#macro TA_COLLECT 4
#macro TA_EXIT 8
#macro TA_LADDER 16
#macro TA_ONEWAY 32
#macro TA_DIG 64
#macro TA_FALLS 128

function engine_defs_init()
{
    global.GAME_TYPE_NAMES = ["Single screen (actors + rules)", "Map game (scrolling engine)"];
    global.KIND_NAMES = ["", "Shoot-em-up", "Platformer", "Cave digger", "Top-down"];
    global.KIND_LIST = ["Shoot-em-up", "Platformer", "Cave digger", "Top-down adventure"];
    global.SCROLL_NAMES = ["No scrolling (one screen)", "Horizontal", "Vertical", "8-way (follows player)", "Flip-screen (rooms)"];
    global.MOVE_NAMES = ["Still (turret)", "Straight line", "Sine wave", "Homing", "Bounce", "Walker (platforms)", "Crawler (follows walls)"];
    global.FIRE_NAMES = ["Does not fire", "Fires in a fixed direction", "Fires at the player"];
    global.DIR_NAMES = ["Up", "Up-right", "Right", "Down-right", "Down", "Down-left", "Left", "Up-left"];
    global.WEAPON_NAMES = ["No weapon", "Single shot", "Double shot", "Spread shot", "Rapid fire"];
    global.AUTO_NAMES = ["1 pixel every frame (fast)", "1 pixel every 2nd frame", "1 pixel every 4th frame (slow)"];
    global.ATTR_NAMES = ["Solid", "Deadly", "Collect", "Exit", "Ladder", "One-way", "Diggable", "Falls"];
    global.ATTR_HELP = [
        "Solid|Nothing can move through this tile: walls, floors, rocks.",
        "Deadly|Touching this tile loses a life: spikes, lava, water.",
        "Collect|The player picks it up for points: coins, gems, diamonds. It counts towards the level's target.",
        "Exit|Touching it finishes the level once enough items have been collected.",
        "Ladder|In platform games the player can climb up and down it.",
        "One-way|A platform you can jump up through and stand on.",
        "Diggable|In cave games the player digs through it: dirt and earth.",
        "Falls|In cave games it falls when nothing is below and rolls off round things: boulders and diamonds."
    ];
}

function eng_settings_new()
{
    return {
        kind : KIND_SHMUP, scroll : SCROLL_H, auto : true, auto_speed : 0,
        wtop : 2, wrows : 18, cols38 : true, fullcol : true, wincol : 11,
        mc : false, mc1 : 11, mc2 : 12, hudcol : 1, border : 0, bg : 0, smc1 : 11, smc2 : 1,
        pspeed : 2, jumpv : 6, grav : 0, maxfall : 5, jump_up : false,
        weapon : 1, bspeed : 6, firedir : 2, cooldown : 10,
        pspr : 0, pcol : 7, bspr : 1, bcol : 1, ebspr : 2, ebcol : 10, lives : 3,
        sfx_shoot : 1, sfx_hit : 2, sfx_die : 6, sfx_collect : 0, sfx_jump : 3, sfx_exit : 5
    };
}

function tile_new(_name)
{
    return { name : _name, c : [32, 32, 32, 32], col : 1, mc : false, attr : 0, score : 0 };
}

function enemy_new(_name)
{
    return { name : _name, spr : 3, col : 2, move : 1, spd : 1, dir : 6, hp : 1, score : 10, fire : 0, rate : 60, fdir : 6 };
}

function level_new(_name, _w, _h)
{
    return { name : _name, w : _w, h : _h, map : array_create(_w * _h, 0), px : 2, py : 2, need : 0, spawners : [] };
}

function spawner_new(_x, _y, _type)
{
    return { x : _x, y : _y, type : _type, count : 1, interval : 30, dir : 255 };
}

/// Fill in the engine-related fields on a project struct
function project_add_engine(_p)
{
    _p.game_type = 0;
    _p.eng = eng_settings_new();
    _p.charset = array_create(2048, 0);
    if (array_length(global.chargen_rom) == 2048)
    {
        array_copy(_p.charset, 0, global.chargen_rom, 0, 2048);
    }
    _p.tiles = [tile_new("Empty")];
    _p.enemies = [enemy_new("Enemy 1")];
    _p.levels = [level_new("Level 1", 40, 12)];
}

function level_resize(_lv, _w, _h)
{
    var _nm = array_create(_w * _h, 0);
    for (var _iy = 0; _iy < min(_h, _lv.h); _iy++)
    {
        for (var _ix = 0; _ix < min(_w, _lv.w); _ix++)
        {
            _nm[_iy * _w + _ix] = _lv.map[_iy * _lv.w + _ix];
        }
    }
    _lv.map = _nm;
    _lv.w = _w;
    _lv.h = _h;
    _lv.px = min(_lv.px, _w - 1);
    _lv.py = min(_lv.py, _h - 1);
}

/// Minimum map size for the chosen window
function eng_min_w() { return 20; }
function eng_min_h(_e) { return ceil(_e.wrows / 2) + 1; }

/// Cycle cost of the worst (coarse scroll) frame, calibrated against the
/// engine running in a 6502 emulator. Returns struct.
function eng_cycle_budget(_e)
{
    var _per_char = 12.5;
    if (_e.fullcol) { _per_char = 21.5; }
    var _rows = _e.wrows;
    var _shift = 0;
    var _draw = 0;
    if (_e.scroll == SCROLL_H) { _shift = _rows * 39 * _per_char; _draw = _rows * 130; }
    if (_e.scroll == SCROLL_V) { _shift = (_rows - 1) * 40 * _per_char; _draw = 2600; }
    if (_e.scroll == SCROLL_8) { _shift = _rows * 39 * _per_char; _draw = max(_rows * 130, 2600); }
    var _logic = 2600;
    if (_e.kind == KIND_PLAT) { _logic = 4400; }
    if (_e.kind == KIND_SHMUP) { _logic = 3300; }
    var _frame = 18200;
    var _full = 9000;
    if (_e.kind == KIND_CAVE) { _full = 11000; }
    var _total = 400 + _shift + _draw + _logic;
    var _tear = false;
    var _bottom = 50 + (_e.wtop + _rows) * 8;
    var _lead_cycles = ((312 - _bottom) + 50 + _e.wtop * 8) * 63;
    if (_e.scroll == SCROLL_H || _e.scroll == SCROLL_8)
    {
        var _row_cost = 39 * _per_char;
        for (var r = 0; r < _rows; r++)
        {
            if ((r + 1) * _row_cost > _lead_cycles + r * 464) { _tear = true; }
        }
    }
    if (_e.scroll == SCROLL_V)
    {
        if (_shift > _lead_cycles) { _tear = true; }
    }
    return { shift : _shift + _draw, logic : _logic, total : _total, frame : _frame, normal : _full, tear : _tear, fits : (_total <= _frame) };
}

/// Generates the complete source for a map game. Returns { src, lines, warnings }
function engine_codegen(_p)
{
    var _e = _p.eng;
    var L = [];
    var _warn = [];
    var _sh = 0;
    var _sv = 0;
    var _flip = 0;
    if (_e.scroll == SCROLL_H) { _sh = 1; }
    if (_e.scroll == SCROLL_V) { _sv = 1; }
    if (_e.scroll == SCROLL_8) { _sh = 1; _sv = 1; }
    if (_e.scroll == SCROLL_FLIP) { _flip = 1; }
    var _auto_h = 0;
    var _auto_v = 0;
    var _follow = 0;
    if (_e.auto && _e.kind == KIND_SHMUP)
    {
        if (_e.scroll == SCROLL_H) { _auto_h = 1; }
        if (_e.scroll == SCROLL_V) { _auto_v = 1; }
    }
    if ((_sh == 1 || _sv == 1) && _auto_h == 0 && _auto_v == 0) { _follow = 1; }
    var _wtop = clamp(_e.wtop, 2, 4);
    var _wrows = clamp(_e.wrows, 6, 25 - _wtop - _sv);
    var _autodiv = [0, 1, 3];
    var _gravdiv = [0, 1, 3];
    var _wpn = clamp(_e.weapon, 0, 4);
    var _mcbit = 0;
    if (_e.mc) { _mcbit = 16; }
    var _cols = 8;
    if (_e.cols38 && _sh == 1) { _cols = 0; }

    array_push(L, "; ===== " + _p.name + " - generated by C64 No-Code Studio =====");
    array_push(L, "* = $0801");
    array_push(L, " .byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00");
    var _cfg = [
        ["KIND_SHMUP", (_e.kind == KIND_SHMUP)], ["KIND_PLAT", (_e.kind == KIND_PLAT)],
        ["KIND_CAVE", (_e.kind == KIND_CAVE)], ["KIND_TOP", (_e.kind == KIND_TOP)],
        ["SCROLL_H", _sh], ["SCROLL_V", _sv], ["FLIP", _flip], ["FOLLOW", _follow],
        ["AUTO_H", _auto_h], ["AUTO_V", _auto_v], ["AUTODIV", _autodiv[clamp(_e.auto_speed, 0, 2)]],
        ["WTOP", _wtop], ["WROWS", _wrows], ["HUDROW", 0], ["FULLCOL", _e.fullcol],
        ["WINCOL", _e.wincol], ["HUDCOL", _e.hudcol], ["COLS_D016", _cols | _mcbit], ["HUD_D016", 8 | _mcbit],
        ["BORDER", _e.border], ["BG", _e.bg], ["MC1", _e.mc1], ["MC2", _e.mc2], ["SMC1", _e.smc1], ["SMC2", _e.smc2],
        ["PSPEED", clamp(_e.pspeed, 1, 4)], ["JUMPV", clamp(_e.jumpv, 2, 9)], ["GRAVDIV", _gravdiv[clamp(_e.grav, 0, 2)]],
        ["MAXFALL", clamp(_e.maxfall, 2, 8)], ["WEAPON_ON", (_wpn > 0)], ["WEAPON_DOUBLE", (_wpn == 2)], ["WEAPON_SPREAD", (_wpn == 3)],
        ["BSPEED", clamp(_e.bspeed, 2, 8)], ["FIREDIR", clamp(_e.firedir, 0, 7)], ["CAVE_ROWS", 3],
        ["PSPR", clamp(_e.pspr, 0, 31)], ["PCOL", _e.pcol], ["BSPR", clamp(_e.bspr, 0, 31)], ["BCOL", _e.bcol],
        ["EBSPR", clamp(_e.ebspr, 0, 31)], ["EBCOL", _e.ebcol], ["LIVES", clamp(_e.lives, 1, 9)],
        ["NLEVELS", max(1, min(8, array_length(_p.levels)))], ["SPR_PAGES", 8],
        ["SFX_SHOOT", _e.sfx_shoot], ["SFX_HIT", _e.sfx_hit], ["SFX_DIE", _e.sfx_die], ["SFX_COLLECT", _e.sfx_collect],
        ["SFX_JUMP", _e.sfx_jump], ["SFX_EXIT", _e.sfx_exit]
    ];
    var _cd = clamp(_e.cooldown, 2, 60);
    if (_wpn == 4) { _cd = max(2, _cd div 3); }
    array_push(_cfg, ["FIRE_COOLDOWN", _cd]);
    var _jm = 16;
    if (_e.jump_up) { _jm = 1; }
    array_push(_cfg, ["JUMPMASK", _jm]);
    var _offx = 24;
    if (_sh == 1) { _offx = 31; }
    var _offy = 50 + _wtop * 8;
    if (_sv == 1) { _offy += 4; }
    array_push(_cfg, ["OFFX", _offx], ["OFFY", _offy]);
    for (var i = 0; i < array_length(_cfg); i++)
    {
        var _v = _cfg[i][1];
        if (is_bool(_v))
        {
            if (_v) { _v = 1; }
            else { _v = 0; }
        }
        array_push(L, _cfg[i][0] + " = " + string(floor(_v)));
    }

    // engine source
    var _eng = file_read_text(working_directory + "engine/engine.asm");
    if (_eng == "")
    {
        array_push(_warn, "engine.asm is missing from the included files.");
    }
    var _el = string_split(_eng, "\n");
    for (var k = 0; k < array_length(_el); k++)
    {
        var _ln = string_replace_all(_el[k], "\r", "");
        if (k < 8 && string_copy(_ln, 1, 1) == ";") { continue; }
        array_push(L, _ln);
    }

    // generated shift routines
    engine_gen_shifts(L, _wtop, _wrows, _e.fullcol);

    // ---------------- data ----------------
    array_push(L, "; ---------------- data ----------------");
    // tiles (64)
    var _nt = min(64, array_length(_p.tiles));
    var _tabs = ["tc0", "tc1", "tc2", "tc3", "tcol", "tattr", "tscore"];
    for (var tb = 0; tb < 7; tb++)
    {
        var _vals = [];
        for (var t = 0; t < 64; t++)
        {
            var _v2 = 0;
            if (t < _nt)
            {
                var _tl = _p.tiles[t];
                if (tb < 4) { _v2 = _tl.c[tb]; }
                if (tb == 4)
                {
                    _v2 = _tl.col;
                    if (_e.mc && _tl.mc) { _v2 = (_tl.col & 7) | 8; }
                }
                if (tb == 5) { _v2 = _tl.attr; }
                if (tb == 6) { _v2 = eng_bcd2(_tl.score); }
            }
            else
            {
                if (tb < 4) { _v2 = 32; }
            }
            array_push(_vals, _v2);
        }
        array_push(L, _tabs[tb] + ":");
        eng_emit_bytes(L, _vals);
    }
    // enemy types (16)
    var _ne = min(16, array_length(_p.enemies));
    var _etn = ["et_spr", "et_col", "et_move", "et_spd", "et_dir", "et_hp", "et_score", "et_fire", "et_rate", "et_fdir"];
    for (var en = 0; en < 10; en++)
    {
        var _ev = [];
        for (var q = 0; q < 16; q++)
        {
            var _x = 0;
            if (q < _ne)
            {
                var _et = _p.enemies[q];
                switch (en)
                {
                    case 0: _x = clamp(_et.spr, 0, 31); break;
                    case 1: _x = _et.col; break;
                    case 2: _x = clamp(_et.move, 0, 6); break;
                    case 3: _x = clamp(_et.spd, 1, 6); break;
                    case 4: _x = clamp(_et.dir, 0, 7); break;
                    case 5: _x = clamp(_et.hp, 1, 99); break;
                    case 6: _x = eng_bcd2(_et.score); break;
                    case 7: _x = clamp(_et.fire, 0, 2); break;
                    case 8: _x = clamp(_et.rate, 10, 255); break;
                    case 9: _x = clamp(_et.fdir, 0, 7); break;
                }
            }
            array_push(_ev, _x);
        }
        array_push(L, _etn[en] + ":");
        eng_emit_bytes(L, _ev);
    }
    // sprite multicolour flags
    var _smc = [];
    for (var s = 0; s < 32; s++)
    {
        var _f = 0;
        if (s < array_length(_p.sprites) && _p.sprites[s].mc) { _f = 1; }
        array_push(_smc, _f);
    }
    array_push(L, "spr_mc:");
    eng_emit_bytes(L, _smc);

    // levels
    var _nl = max(1, min(8, array_length(_p.levels)));
    var _ltabs = ["lv_w", "lv_h", "lv_px", "lv_py", "lv_need", "lv_nsp", "lv_size_lo", "lv_size_hi"];
    for (var lt = 0; lt < 8; lt++)
    {
        var _lv = [];
        for (var l = 0; l < _nl; l++)
        {
            var _lev = _p.levels[l];
            var _val = 0;
            switch (lt)
            {
                case 0: _val = _lev.w; break;
                case 1: _val = _lev.h; break;
                case 2: _val = _lev.px; break;
                case 3: _val = _lev.py; break;
                case 4: _val = min(99, _lev.need); break;
                case 5: _val = min(64, array_length(_lev.spawners)); break;
                case 6: _val = (_lev.w * _lev.h) & 255; break;
                case 7: _val = ((_lev.w * _lev.h) >> 8) & 255; break;
            }
            array_push(_lv, _val);
        }
        array_push(L, _ltabs[lt] + ":");
        eng_emit_bytes(L, _lv);
    }
    var _plo = "lv_map_lo: .byte ";
    var _phi = "lv_map_hi: .byte ";
    var _slo = "lv_sp_lo: .byte ";
    var _shi = "lv_sp_hi: .byte ";
    for (var l2 = 0; l2 < _nl; l2++)
    {
        var _sep = ",";
        if (l2 == 0) { _sep = ""; }
        _plo += _sep + "<map_" + string(l2);
        _phi += _sep + ">map_" + string(l2);
        _slo += _sep + "<spw_" + string(l2);
        _shi += _sep + ">spw_" + string(l2);
    }
    array_push(L, _plo, _phi, _slo, _shi);
    for (var l3 = 0; l3 < _nl; l3++)
    {
        var _lv3 = _p.levels[l3];
        if (_lv3.w < 20) { array_push(_warn, _lv3.name + ": maps must be at least 20 tiles wide."); }
        if (_lv3.h * 2 < _wrows) { array_push(_warn, _lv3.name + ": map is shorter than the play window."); }
        if (_lv3.w * _lv3.h > 16384) { array_push(_warn, _lv3.name + ": map is too big (max 16384 tiles)."); }
        array_push(L, "map_" + string(l3) + ":");
        var _row = [];
        for (var m = 0; m < _lv3.w * _lv3.h; m++)
        {
            array_push(_row, clamp(_lv3.map[m], 0, 63));
            if (array_length(_row) == 48)
            {
                array_push(L, " .byte " + eng_join(_row));
                _row = [];
            }
        }
        if (array_length(_row) > 0) { array_push(L, " .byte " + eng_join(_row)); }
        array_push(L, "spw_" + string(l3) + ":");
        var _ns = min(64, array_length(_lv3.spawners));
        if (_ns == 0) { array_push(L, " .byte 0"); }
        for (var sp = 0; sp < _ns; sp++)
        {
            var _s = _lv3.spawners[sp];
            var _d = _s.dir;
            if (_d < 0 || _d > 7) { _d = 255; }
            array_push(L, " .byte " + string(clamp(_s.x, 0, 255)) + "," + string(clamp(_s.y, 0, 255)) + "," + string(clamp(_s.type, 0, 15)) + "," + string(clamp(_s.count, 1, 99)) + "," + string(clamp(_s.interval, 1, 255)) + "," + string(_d));
        }
    }

    // texts
    var _need_any = false;
    for (var l4 = 0; l4 < _nl; l4++)
    {
        if (_p.levels[l4].need > 0) { _need_any = true; }
    }
    var _hud = "SCORE 000000 LIVES 3";
    if (_need_any) { _hud += "     GEMS 00/00"; }
    array_push(L, "hud_txt:", " .byte " + eng_text(_hud, false));
    array_push(L, "txt_over:", " .byte " + cg_text_bytes(_p.over_text));
    array_push(L, "txt_win:", " .byte " + cg_text_bytes(_p.win_text));

    // sfx
    var _ad = "", _sr = "", _fq = "", _sw = "", _len = "", _wv = "";
    var _waves = [16, 32, 64, 128];
    for (var sfi = 0; sfi < 8; sfi++)
    {
        var _sf = _p.sfx[sfi];
        var _sp = ",";
        if (sfi == 0) { _sp = ""; }
        _ad += _sp + string((clamp(_sf.atk, 0, 15) << 4) | clamp(_sf.dec, 0, 15));
        _sr += _sp + string((clamp(_sf.sus, 0, 15) << 4) | clamp(_sf.rel, 0, 15));
        _fq += _sp + string(clamp(_sf.pitch, 1, 255));
        _sw += _sp + string(clamp(_sf.sweep, -8, 8) & 255);
        _len += _sp + string(clamp(_sf.len, 1, 200));
        _wv += _sp + string(_waves[clamp(_sf.wave, 0, 3)]);
    }
    array_push(L, "sfxt_ad:", " .byte " + _ad, "sfxt_sr:", " .byte " + _sr, "sfxt_f:", " .byte " + _fq);
    array_push(L, "sfxt_sw:", " .byte " + _sw, "sfxt_len:", " .byte " + _len, "sfxt_w:", " .byte " + _wv);

    // sprite and charset blobs (copied to $E000 / $F000 at start)
    array_push(L, "spr_src:");
    for (var sb = 0; sb < 32; sb++)
    {
        var _bytes = sprite_encode(_p.sprites[min(sb, array_length(_p.sprites) - 1)]);
        array_push(L, " .byte " + cg_join_bytes(_bytes, 0, 63) + ",0");
    }
    array_push(L, "chr_src:");
    for (var cb = 0; cb < 2048; cb += 64)
    {
        array_push(L, " .byte " + cg_join_bytes(_p.charset, cb, 64));
    }
    array_push(L, "data_end:");
    return { src : string_join_ext("\n", L), warnings : _warn, lines : L };
}

function eng_bcd2(_n)
{
    var _v = clamp(floor(_n), 0, 99);
    return ((_v div 10) << 4) | (_v mod 10);
}

function eng_join(_arr)
{
    var _s = "";
    for (var i = 0; i < array_length(_arr); i++)
    {
        if (i > 0) { _s += ","; }
        _s += string(_arr[i] & 255);
    }
    return _s;
}

function eng_emit_bytes(_L, _vals)
{
    var _n = array_length(_vals);
    for (var i = 0; i < _n; i += 32)
    {
        var _chunk = [];
        for (var k = i; k < min(_n, i + 32); k++) { array_push(_chunk, _vals[k]); }
        array_push(_L, " .byte " + eng_join(_chunk));
    }
}

function eng_text(_s, _pad)
{
    var _t = string_upper(_s);
    var _out = "";
    for (var i = 1; i <= string_length(_t); i++)
    {
        _out += string(scr_code_from_char(string_char_at(_t, i))) + ",";
    }
    return _out + "255";
}

/// Unrolled shift routines: two rows per loop, top-down where the beam allows
function engine_gen_shifts(L, _wtop, _wrows, _fullcol)
{
    array_push(L, "; ---- generated scroll shifts (" + string(_wrows) + " rows) ----");
    // left: content moves left
    array_push(L, "shift_left:");
    for (var r = 0; r < _wrows; r += 2)
    {
        var _lb = "shl_" + string(r);
        array_push(L, " ldx #0", _lb + ":");
        for (var k = r; k < min(_wrows, r + 2); k++)
        {
            var _s = "SCR+" + string((_wtop + k) * 40);
            array_push(L, " lda " + _s + "+1,x", " sta " + _s + ",x");
            if (_fullcol)
            {
                var _c = "COLR+" + string((_wtop + k) * 40);
                array_push(L, " lda " + _c + "+1,x", " sta " + _c + ",x");
            }
        }
        array_push(L, " inx", " cpx #39", " bne " + _lb);
    }
    array_push(L, " rts", "shift_right:");
    for (var r2 = 0; r2 < _wrows; r2 += 2)
    {
        var _lb2 = "shr_" + string(r2);
        array_push(L, " ldx #38", _lb2 + ":");
        for (var k2 = r2; k2 < min(_wrows, r2 + 2); k2++)
        {
            var _s2 = "SCR+" + string((_wtop + k2) * 40);
            array_push(L, " lda " + _s2 + ",x", " sta " + _s2 + "+1,x");
            if (_fullcol)
            {
                var _c2 = "COLR+" + string((_wtop + k2) * 40);
                array_push(L, " lda " + _c2 + ",x", " sta " + _c2 + "+1,x");
            }
        }
        array_push(L, " dex", " bpl " + _lb2);
    }
    // up: row k <- row k+1 (top-down, safe to pair)
    array_push(L, " rts", "shift_up:");
    for (var r3 = 0; r3 < _wrows - 1; r3 += 2)
    {
        var _lb3 = "shu_" + string(r3);
        array_push(L, " ldx #39", _lb3 + ":");
        for (var k3 = r3; k3 < min(_wrows - 1, r3 + 2); k3++)
        {
            array_push(L, " lda SCR+" + string((_wtop + k3 + 1) * 40) + ",x", " sta SCR+" + string((_wtop + k3) * 40) + ",x");
            if (_fullcol) { array_push(L, " lda COLR+" + string((_wtop + k3 + 1) * 40) + ",x", " sta COLR+" + string((_wtop + k3) * 40) + ",x"); }
        }
        array_push(L, " dex", " bpl " + _lb3);
    }
    // down: row k <- row k-1 (bottom-up)
    array_push(L, " rts", "shift_down:");
    for (var r4 = _wrows - 1; r4 >= 1; r4 -= 2)
    {
        var _lb4 = "shd_" + string(r4);
        array_push(L, " ldx #39", _lb4 + ":");
        for (var k4 = r4; k4 > max(0, r4 - 2); k4--)
        {
            array_push(L, " lda SCR+" + string((_wtop + k4 - 1) * 40) + ",x", " sta SCR+" + string((_wtop + k4) * 40) + ",x");
            if (_fullcol) { array_push(L, " lda COLR+" + string((_wtop + k4 - 1) * 40) + ",x", " sta COLR+" + string((_wtop + k4) * 40) + ",x"); }
        }
        array_push(L, " dex", " bpl " + _lb4);
    }
    array_push(L, " rts");
}

/// Full map-game build. Returns true on success.
function build_engine_prg(_path)
{
    var _gen = engine_codegen(proj);
    var _res = asm6502_assemble(_gen.src);
    build_listing = _gen.lines;
    build_warnings = _gen.warnings;
    if (!_res.ok)
    {
        build_ok = false;
        build_msg = "Build failed - " + _res.err;
        return false;
    }
    var _end = _res.org + array_length(_res.bytes);
    if (_end > 32768)
    {
        build_ok = false;
        build_msg = "Build failed - the game data is too big (ends at $" + string_upper(dec_to_hex(_end)) + ", limit $8000). Make maps smaller or use fewer levels.";
        return false;
    }
    var _b = buffer_create(array_length(_res.bytes) + 2, buffer_fixed, 1);
    buffer_write(_b, buffer_u8, _res.org & 255);
    buffer_write(_b, buffer_u8, (_res.org >> 8) & 255);
    for (var i = 0; i < array_length(_res.bytes); i++)
    {
        buffer_write(_b, buffer_u8, _res.bytes[i]);
    }
    buffer_save(_b, _path);
    buffer_delete(_b);
    build_ok = true;
    build_size = array_length(_res.bytes) + 2;
    build_end = _end;
    build_spr = _res.labels[$ "spr_src"];
    build_msg = "Built " + filename_name(_path) + " - " + string(build_size) + " bytes ($0801-$" + string_upper(dec_to_hex(_end - 1)) + ")";
    return true;
}
