/// C64 ENGINE - levels for single-screen games (the Levels page, ported from ADAM's Levels page).
/// Up to 8 levels, each with its own hills grown from a seed and shaped by hand, drawn on the
/// C64 in block characters over the Screen page (a partly filled block on top, so the ground
/// line is smooth to the pixel). Actors can walk on the hills, appear from a given level on,
/// and a goal counter moves the game on to the next level - with a level card in between, a
/// title screen in big letters before the game, and the Win message after the last level.
/// The map games keep their own levels (Map page); these are proj.stages.

#macro STAGE_MAX 8
#macro STAGE_TOP 64          // the highest the ground can go (pixels from the top of the screen)
#macro STAGE_LOW 196         // the lowest; 200 = no ground in that column

/// The block characters that fill the bottom n eighths of a cell (n = 1..8)
function stage_blocks()
{
    return [100, 111, 121, 98, 248, 247, 227, 160];
}

/// Rolling hills from a seed (ADAM's maths, sampled at the middle of each of the 40 columns
/// and scaled to the C64's 200 lines). Returns 40 ground heights, pixels from the top.
function stage_terrain(_seed, _hilly, _base)
{
    var _st = _seed & 0x7fffffff;
    var _lo = [45, 20, 9];
    var _hi = [70, 30, 14];
    var _amp = [11, 5.5, 2.3];
    var _f = [0, 0, 0];
    var _ph = [0, 0, 0];
    var _a = [0, 0, 0];
    for (var k = 0; k < 3; k++)
    {
        _st = (_st * 1103515245 + 12345) mod 2147483648;
        var _r1 = _st / 2147483648;
        _st = (_st * 1103515245 + 12345) mod 2147483648;
        var _r2 = _st / 2147483648;
        _f[k] = 1 / (_lo[k] + _r1 * (_hi[k] - _lo[k]));
        _ph[k] = _r2 * 6.283185307179586;
        _a[k] = _amp[k] * _hilly / 100 * 2.5;
    }
    var _out = array_create(40, 200);
    for (var c = 0; c < 40; c++)
    {
        var _px = c * 8 + 4;
        var _h = _base;
        for (var t = 0; t < 3; t++) { _h += sin(_px * _f[t] + _ph[t]) * _a[t]; }
        _out[c] = clamp(floor(_h + 0.5), STAGE_TOP, STAGE_LOW);
    }
    return _out;
}

function stage_new(_seed)
{
    return { seed : _seed, hilly : 60, base : 160, heights : stage_terrain(_seed, 60, 160) };
}

/// The levels fields of a project (new or loaded), made safe
function stages_fix(_p)
{
    if (!is_bool(_p[$ "levels_on"])) { _p.levels_on = (is_numeric(_p[$ "levels_on"]) && _p[$ "levels_on"] != 0); }
    var _raw = _p[$ "stages"];
    var _out = [];
    if (is_array(_raw))
    {
        for (var i = 0; i < min(STAGE_MAX, array_length(_raw)); i++)
        {
            var _s = struct_overlay(stage_new(1000), _raw[i]);
            _s.seed = is_numeric(_s.seed) ? clamp(floor(_s.seed), 1, 99999) : 1000;
            _s.hilly = is_numeric(_s.hilly) ? clamp(floor(_s.hilly), 0, 150) : 60;
            _s.base = is_numeric(_s.base) ? clamp(floor(_s.base), 100, 190) : 160;
            if (!is_array(_s.heights) || array_length(_s.heights) != 40) { _s.heights = stage_terrain(_s.seed, _s.hilly, _s.base); }
            for (var c = 0; c < 40; c++) { _s.heights[c] = is_numeric(_s.heights[c]) ? clamp(floor(_s.heights[c]), STAGE_TOP, 200) : 200; }
            array_push(_out, _s);
        }
    }
    _p.stages = _out;
    var _tc = _p[$ "terrain_cols"];
    if (!is_array(_tc) || array_length(_tc) != 4) { _tc = [13, 5, 9, 8]; }
    for (var k = 0; k < 4; k++) { _tc[k] = is_numeric(_tc[k]) ? clamp(floor(_tc[k]), 0, 15) : 0; }
    _p.terrain_cols = _tc;
    if (!is_bool(_p[$ "goal_on"])) { _p.goal_on = (is_numeric(_p[$ "goal_on"]) && _p[$ "goal_on"] != 0); }
    _p.goal_label = is_string(_p[$ "goal_label"]) ? string_upper(string_copy(_p.goal_label, 1, 6)) : "GEMS";
    _p.goal = is_numeric(_p[$ "goal"]) ? clamp(floor(_p.goal), 1, 99) : 10;
    if (!is_bool(_p[$ "title_on"])) { _p.title_on = (is_numeric(_p[$ "title_on"]) && _p[$ "title_on"] != 0); }
    _p.title1 = is_string(_p[$ "title1"]) ? string_upper(string_copy(_p.title1, 1, 10)) : "MY GAME";
    _p.title2 = is_string(_p[$ "title2"]) ? string_upper(string_copy(_p.title2, 1, 40)) : "PRESS FIRE TO START";
    _p.lev_text = is_string(_p[$ "lev_text"]) ? string_upper(string_copy(_p.lev_text, 1, 10)) : "LEVEL";
    if (is_array(_p[$ "actors"]))
    {
        for (var a = 0; a < array_length(_p.actors); a++)
        {
            var _ac = _p.actors[a];
            _ac.from_level = is_numeric(_ac[$ "from_level"]) ? clamp(floor(_ac.from_level), 1, STAGE_MAX) : 1;
        }
    }
}

/// How many levels the single-screen game plays
function stage_count(_p)
{
    if (!_p.levels_on) { return 1; }
    return clamp(array_length(_p.stages), 1, STAGE_MAX);
}

/// Is the actor role a ground walker (player on the ground, walker)?
function role_on_ground(_role)
{
    return (_role == 6 || _role == 7);
}

/// Is the role a player (the joystick moves it)?
function role_is_player(_role)
{
    return (_role == 0 || _role == 6);
}

/// The hills of level _h (40 heights) as cells over the screen: { scr[1000], col[1000] } (-1 = none).
/// The same rules as draw_hills in the game.
function stage_cells(_p, _h)
{
    var _scr = array_create(1000, -1);
    var _col = array_create(1000, 0);
    var _bl = stage_blocks();
    var _tc = _p.terrain_cols;
    for (var c = 0; c < 40; c++)
    {
        var _g = _h[c];
        if (_g >= 200) { continue; }
        var _r0 = _g div 8;
        for (var r = _r0; r < 25; r++)
        {
            var _d = r - _r0;
            var _i = r * 40 + c;
            if (_d == 0)
            {
                _scr[_i] = _bl[7 - (_g mod 8)];
                _col[_i] = _tc[0];
            }
            else
            {
                _scr[_i] = 160;
                if (_d == 1) { _col[_i] = _tc[1]; }
                else { _col[_i] = (((c * 5 + r * 3) & 15) == 0) ? _tc[3] : _tc[2]; }
            }
        }
    }
    return { scr : _scr, col : _col };
}

/// The lowest drawn row of a sprite (its feet)
function sprite_feet(_si)
{
    var _s = proj.sprites[clamp(_si, 0, SPR_COUNT - 1)];
    if (_s.mc)
    {
        for (var q = 251; q >= 0; q--)
        {
            if (_s.mcp[q] != 0) { return q div 12; }
        }
    }
    else
    {
        for (var q2 = 503; q2 >= 0; q2--)
        {
            if (_s.hi[q2] != 0) { return q2 div 24; }
        }
    }
    return 20;
}

// ---------------------------------------------------------------------------
// In the game
// ---------------------------------------------------------------------------

/// The C64 letters of the title in big letters: each pixel of a letter becomes a quarter of a
/// character (the C64's own quarter-block characters), so a letter is 4 x 4 characters.
/// Returns 160 screen codes (4 rows of 40).
function stage_title_cells(_text)
{
    var _q = [32, 108, 123, 98, 124, 225, 255, 254, 126, 127, 97, 252, 226, 251, 236, 160];
    var _out = array_create(160, 32);
    var _t = string_upper(string_copy(_text, 1, 10));
    var _n = string_length(_t);
    var _x0 = (40 - _n * 4) div 2;
    for (var i = 0; i < _n; i++)
    {
        var _code = scr_code_from_char(string_char_at(_t, i + 1)) & 63;
        for (var cy = 0; cy < 4; cy++)
        {
            for (var cx = 0; cx < 4; cx++)
            {
                var _top = global.chargen_rom[_code * 8 + cy * 2];
                var _bot = global.chargen_rom[_code * 8 + cy * 2 + 1];
                var _m1 = 0x80 >> (cx * 2);
                var _m2 = 0x40 >> (cx * 2);
                var _v = (((_top & _m1) != 0) ? 8 : 0) | (((_top & _m2) != 0) ? 4 : 0) | (((_bot & _m1) != 0) ? 2 : 0) | (((_bot & _m2) != 0) ? 1 : 0);
                _out[cy * 40 + _x0 + i * 4 + cx] = _q[_v];
            }
        }
    }
    return _out;
}

/// 40 screen codes of a line of text, centred
function stage_line_cells(_text)
{
    var _out = array_create(40, 32);
    var _t = string_upper(string_copy(_text, 1, 40));
    var _x0 = (40 - string_length(_t)) div 2;
    for (var i = 0; i < string_length(_t); i++) { _out[_x0 + i] = scr_code_from_char(string_char_at(_t, i + 1)); }
    return _out;
}

/// The actors' start for this level: as the Actors page says, shown from their level on
/// (one subroutine, run at the start and at each new level)
function stage_emit_actor_vis(L, _ac, _sa, _vis)
{
    array_push(L, " lda #" + string(_vis));
    var _from = clamp(_ac.from_level, 1, STAGE_MAX);
    if (_vis && _from > 1) { array_push(L, " ldy level", " cpy #" + string(_from - 1), " bcs av_" + _sa, " lda #0", "av_" + _sa + ":"); }
    array_push(L, " sta avis+" + _sa);
}

/// Everything the levels need in a single-screen game: the hills, walking on them, the level
/// card, the title screen and moving on. na = actors in the game.
function stage_emit(L, _p, na, _win_lines)
{
    var _acts = _p.actors;
    var _nl = stage_count(_p);
    var _ground = false;
    for (var a = 0; a < na; a++)
    {
        if (role_on_ground(_acts[a].role)) { _ground = true; }
    }
    // the levels' ground: 40 heights each (200 = no ground)
    array_push(L, "; ---------------- levels (Levels page) ----------------");
    if (_p.levels_on)
    {
        var _lo = [];
        var _hi = [];
        for (var l = 0; l < _nl; l++)
        {
            array_push(L, "hl_" + string(l) + ":");
            eng_emit_bytes(L, _p.stages[l].heights);
            array_push(_lo, "<hl_" + string(l));
            array_push(_hi, ">hl_" + string(l));
        }
        array_push(L, "hl_lo:", " .byte " + string_join_ext(",", _lo), "hl_hi:", " .byte " + string_join_ext(",", _hi));
        var _bl = stage_blocks();
        var _part = [];
        for (var k = 0; k < 8; k++) { array_push(_part, _bl[7 - k]); }
        array_push(L, "hl_part:", " .byte " + string_join_ext(",", _part));
        var _rl = [];
        var _rh = [];
        for (var r = 0; r < 25; r++)
        {
            array_push(_rl, string((1024 + r * 40) & 255));
            array_push(_rh, string((1024 + r * 40) >> 8));
        }
        array_push(L, "row_lo:", " .byte " + string_join_ext(",", _rl), "row_hi:", " .byte " + string_join_ext(",", _rh));
        var _tc = _p.terrain_cols;
        // draw_hills: each column's top cell is a partly filled block in the edge colour, then
        // a grass cell, then soil (with specks); the ground lines go into gnd for the walkers
        array_push(L, "draw_hills:", " ldx level", " lda hl_lo,x", " sta ptr", " lda hl_hi,x", " sta ptr+1", " ldy #0");
        array_push(L, "dh_col:", " sty hcol", " lda (ptr),y", " clc", " adc #50", " sta gnd,y", " lda (ptr),y", " cmp #200", " bcc dh_go", " jmp dh_next", "dh_go:");
        array_push(L, " pha", " lsr", " lsr", " lsr", " sta hrow", " pla", " and #7", " tax", " lda hl_part,x", " sta hch", " lda #0", " sta hdep");
        array_push(L, "dh_row:", " ldx hrow", " lda row_lo,x", " sta $fd", " lda row_hi,x", " sta $fe", " ldy hcol", " lda hch", " sta ($fd),y");
        array_push(L, " lda hdep", " bne dh_c1", " lda #" + string(_tc[0]), " jmp dh_cs", "dh_c1:", " cmp #1", " bne dh_c2", " lda #" + string(_tc[1]), " jmp dh_cs");
        array_push(L, "dh_c2:", " lda hcol", " asl", " asl", " clc", " adc hcol", " sta hcl", " lda hrow", " asl", " clc", " adc hrow", " adc hcl", " and #15", " bne dh_c3", " lda #" + string(_tc[3]), " jmp dh_cs", "dh_c3:", " lda #" + string(_tc[2]));
        array_push(L, "dh_cs:", " pha", " lda $fe", " clc", " adc #$d4", " sta $fe", " pla", " sta ($fd),y");
        array_push(L, " lda #160", " sta hch", " inc hdep", " inc hrow", " lda hrow", " cmp #25", " bcs dh_next", " jmp dh_row");
        array_push(L, "dh_next:", " ldy hcol", " iny", " cpy #40", " beq dh_done", " jmp dh_col", "dh_done:", " rts");
    }
    else if (_ground)
    {
        // no hills: the ground is the bottom of the screen
        array_push(L, "draw_hills:", " ldy #39", " lda #250", "dh0:", " sta gnd,y", " dey", " bpl dh0", " rts");
    }
    array_push(L, "gnd:", " .fill 40,250");

    if (_ground)
    {
        // where each actor's feet are (the sprite's lowest row + 1)
        var _fb = [];
        for (var f = 0; f < 8; f++) { array_push(_fb, (f < na) ? sprite_feet(_acts[f].sprite) + 1 : 21); }
        array_push(L, "afb:", " .byte " + string_join_ext(",", _fb));
        // gnd_at: X = actor -> A = the ground line under its middle (sprite y), Y = its column
        array_push(L, "gnd_at:", " lda ax_lo,x", " sec", " sbc #12", " sta tmp3", " lda ax_hi,x", " sbc #0", " lsr", " lda tmp3", " ror", " lsr", " lsr", " cmp #40", " bcc ga1", " lda #39", "ga1:", " tay", " lda gnd,y", " rts");
        // ground_fall: X = actor - gravity, and standing on the ground
        array_push(L, "ground_fall:", " lda acnt", " and #1", " bne gf1", " lda avy,x", " bmi gf0", " cmp #6", " bcs gf1", "gf0:", " inc avy,x", "gf1:");
        array_push(L, " lda ay,x", " clc", " adc avy,x", " sta ay,x", " cmp #" + string(CG_YMIN), " bcs gf2", " lda #" + string(CG_YMIN), " sta ay,x", " lda #0", " sta avy,x");
        array_push(L, "gf2:", " jsr gnd_at", " sec", " sbc afb,x", " sta tmp3", " lda avy,x", " bmi gf_r", " lda ay,x", " cmp tmp3", " bcc gf_air");
        array_push(L, " lda tmp3", " sta ay,x", " lda #0", " sta avy,x", " lda #1", " sta agr,x", " rts", "gf_air:", " lda #0", " sta agr,x", "gf_r:", " rts");
        // ground_step: X = actor, A = signed pixels across - stopped by the screen edges and by
        // ground more than 8 pixels above its feet. A = 0 moved, 1 blocked.
        array_push(L, "ground_step:", " sta tmp4", " lda ax_lo,x", " sta tmp5", " lda ax_hi,x", " sta tmp6", " lda tmp4", " bmi gs_n");
        array_push(L, " clc", " adc ax_lo,x", " sta ax_lo,x", " bcc gs1", " inc ax_hi,x", " jmp gs1", "gs_n:", " clc", " adc ax_lo,x", " sta ax_lo,x", " bcs gs1", " dec ax_hi,x");
        array_push(L, "gs1:", " lda ax_hi,x", " bne gs_h", " lda ax_lo,x", " cmp #" + string(CG_XMIN), " bcc gs_b", " jmp gs_c", "gs_h:", " lda ax_lo,x", " cmp #" + string((CG_XMAX & 255) + 1), " bcs gs_b");
        array_push(L, "gs_c:", " jsr gnd_at", " sec", " sbc afb,x", " sta tmp3", " lda ay,x", " sec", " sbc tmp3", " bcc gs_ok", " cmp #9", " bcs gs_b", "gs_ok:", " lda #0", " rts");
        array_push(L, "gs_b:", " lda tmp5", " sta ax_lo,x", " lda tmp6", " sta ax_hi,x", " lda #1", " rts");
    }

    // wait_fire: fire let go, pressed, let go
    array_push(L, "wait_fire:", "wf1:", " lda $dc00", " and #16", " beq wf1", "wf2:", " lda $dc00", " and #16", " bne wf2", "wf3:", " lda $dc00", " and #16", " beq wf3", " rts");
    array_push(L, "clear_scr:", " lda #0", " sta $d015", " ldx #0", " lda #32", "cs1:", " sta $0400,x", " sta $0500,x", " sta $0600,x", " sta $06e8,x", " inx", " bne cs1", " rts");
    // b2d: A (0-99) -> X tens and A units, as screen codes
    array_push(L, "b2d:", " ldx #48", "b2d1:", " cmp #10", " bcc b2d2", " sbc #10", " inx", " bne b2d1", "b2d2:", " ora #48", " rts");

    // level_begin: the screen (with this level's hills), the actors, the level's song
    array_push(L, "level_begin:", " lda #0", " sta $d015", " sta goal_got", " sta lvl_pend", " jsr draw_screen", " jsr actors_init", " lda level", " jsr mus_level");
    array_push(L, " jsr draw_hud", " jsr place_sprites", " lda $d01e", " lda $d01f", " rts");
    // next_level: after the last level the game is won, otherwise a level card and the next one
    array_push(L, "next_level:", " lda #0", " sta lvl_pend", " lda level", " cmp #" + string(_nl - 1), " bcc nl1");
    for (var w = 0; w < array_length(_win_lines); w++) { array_push(L, _win_lines[w]); }
    array_push(L, "nl1:", " inc level", " jsr sfx_stop", " jsr clear_scr");
    var _card = stage_line_cells(_p.lev_text + " 0");
    array_push(L, " ldx #39", "lc1:", " lda lc_txt,x", " sta $0400+480,x", " lda #1", " sta $d800+480,x", " dex", " bpl lc1");
    var _digit = 0;
    for (var dc = 39; dc >= 0; dc--)
    {
        if (_card[dc] != 32) { _digit = dc; break; }
    }
    array_push(L, " lda level", " clc", " adc #49", " sta $0400+480+" + string(_digit), " jsr wait_fire", " jsr level_begin", " jmp mainloop");
    array_push(L, "lc_txt:");
    eng_emit_bytes(L, _card);
    // the title screen: the title in big letters and a line under it, until fire
    if (_p.title_on)
    {
        array_push(L, "title_screen:", " jsr clear_scr", " ldx #159", "ts1:", " lda tt_big,x", " sta $0400+240,x", " lda #1", " sta $d800+240,x", " dex", " cpx #255", " bne ts1");
        array_push(L, " ldx #39", "ts2:", " lda tt_sub,x", " sta $0400+600,x", " lda #7", " sta $d800+600,x", " dex", " bpl ts2", " jmp wait_fire");
        array_push(L, "tt_big:");
        eng_emit_bytes(L, stage_title_cells(_p.title1));
        array_push(L, "tt_sub:");
        eng_emit_bytes(L, stage_line_cells(_p.title2));
    }
}

/// The code that moves a ground actor m (role 6: the player on the ground, 7: a walker)
function stage_emit_actor(L, _ac, m)
{
    var s = string(m);
    var t = "_" + s;
    if (_ac.role == 6)
    {
        array_push(L, " ldx #" + s, " lda joy", " and #4", " beq gl" + t, " lda #0", " sec", " sbc aspd+" + s, " jsr ground_step", "gl" + t + ":");
        array_push(L, " ldx #" + s, " lda joy", " and #8", " beq gr" + t, " lda aspd+" + s, " jsr ground_step", "gr" + t + ":");
        // fire or up jumps, from the ground
        array_push(L, " lda joy", " and #17", " beq gj" + t, " lda agr+" + s, " beq gj" + t, " lda #250", " sta avy+" + s, " lda #0", " sta agr+" + s, "gj" + t + ":");
        array_push(L, " ldx #" + s, " jsr ground_fall");
    }
    if (_ac.role == 7)
    {
        array_push(L, " ldx #" + s, " lda adx+" + s, " bne wl" + t, " lda aspd+" + s, " jsr ground_step", " beq wd" + t, " lda #1", " sta adx+" + s, " jmp wd" + t);
        array_push(L, "wl" + t + ":", " lda #0", " sec", " sbc aspd+" + s, " jsr ground_step", " beq wd" + t, " lda #0", " sta adx+" + s);
        array_push(L, "wd" + t + ":", " ldx #" + s, " jsr ground_fall");
    }
}
