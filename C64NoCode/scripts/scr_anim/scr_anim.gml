/// C64 NO-CODE STUDIO - animations (the Animate page), ported from ADAM.
/// Each member of the cast - the actors of a single-screen game; the player, its shot, the
/// enemies' shot and the enemy types of a map game - can have ADAM's animations: Idle, Walk,
/// Jump, Fall, the 8 joystick directions (N NE E SE S SW W NW), Fire and Fire + the 8
/// directions. Each is up to 16 sprite slots, a speed in 50ths of a second per frame and a mode
/// (loop, once, ping-pong). Empty ones borrow from the others (anim_plan, as ADAM's).
///
/// On the C64: the VIC-II can't turn a sprite round, so frames that are turned round (Turn to
/// face left, or a direction borrowed from its partner) become mirrored copies of the sprite
/// data, made at build time in up to 32 more sprite slots after the 32 drawn ones. A small
/// 6502 routine (anim_upd, shared by both kinds of game) runs once a frame for every animated
/// sprite: it works out which way the sprite moved since the last frame, picks the animation
/// (in the air: Jump / Fall; holding fire: Fire; moving: Walk or the direction; else Idle),
/// starts it again when it changes, counts its speed and steps its frames.
/// A member with no frames here keeps the Sprites page animation of its sprite.

#macro ANIM_COUNT 21            // 0 Idle, 1 Walk, 2 Jump, 3 Fall, 4..11 N NE E SE S SW W NW, 12 Fire, 13..20 Fire + N .. NW
#macro ANIM_BASIC 4
#macro ANIM_DIR0 4
#macro ANIM_FIRE0 12
#macro ANIM_FRAMES 16
#macro ANIM_MIRRORS 32          // mirrored copies: sprite slots 32..63 (the VIC-II sees 64 after the sprite base)

function anim_new()
{
    return { frames : [], rate : 8, mode : 0 };      // mode 0 loop, 1 once, 2 ping-pong
}

function anims_new()
{
    var _a = [];
    for (var i = 0; i < ANIM_COUNT; i++) { array_push(_a, anim_new()); }
    return _a;
}

/// What holds a cast member's animations (an actor and an enemy type hold them themselves)
function anim_holder_new()
{
    return { anims : anims_new(), anim_flip : false };
}

/// Makes a loaded anims array safe: 21 entries, up to 16 frames each, values in range
function anims_from_loaded(_raw)
{
    var _out = anims_new();
    if (!is_array(_raw)) { return _out; }
    for (var i = 0; i < min(ANIM_COUNT, array_length(_raw)); i++)
    {
        var _e = _raw[i];
        if (!is_struct(_e)) { continue; }
        var _fr = _e[$ "frames"];
        if (is_array(_fr))
        {
            for (var k = 0; k < min(ANIM_FRAMES, array_length(_fr)); k++)
            {
                if (is_numeric(_fr[k])) { array_push(_out[i].frames, clamp(floor(_fr[k]), 0, SPR_COUNT - 1)); }
            }
        }
        var _r = _e[$ "rate"];
        if (is_numeric(_r)) { _out[i].rate = clamp(floor(_r), 2, 30); }
        var _m = _e[$ "mode"];
        if (is_numeric(_m)) { _out[i].mode = clamp(floor(_m), 0, 2); }
    }
    return _out;
}

/// Makes a loaded holder (or actor / enemy type) safe
function anim_holder_fix(_h)
{
    if (!is_struct(_h)) { return anim_holder_new(); }
    _h.anims = anims_from_loaded(_h[$ "anims"]);
    _h.anim_flip = (_h[$ "anim_flip"] == true);
    return _h;
}

/// After loading a project: every cast member's animations made safe
function anim_project_fix(_p)
{
    for (var i = 0; i < array_length(_p.actors); i++) { anim_holder_fix(_p.actors[i]); }
    for (var e = 0; e < array_length(_p.enemies); e++) { anim_holder_fix(_p.enemies[e]); }
    _p.eng.anim_p = anim_holder_fix(_p.eng[$ "anim_p"]);
    _p.eng.anim_b = anim_holder_fix(_p.eng[$ "anim_b"]);
    _p.eng.anim_eb = anim_holder_fix(_p.eng[$ "anim_eb"]);
}

function anim_names()
{
    return ["Idle", "Walk", "Jump", "Fall", "N", "NE", "E", "SE", "S", "SW", "W", "NW",
            "Fire", "N", "NE", "E", "SE", "S", "SW", "W", "NW"];
}

function anim_long_names()
{
    return ["Idle", "Walk", "Jump", "Fall", "Up", "Up and right", "Right", "Down and right", "Down", "Down and left", "Left", "Up and left",
            "Fire", "Fire + up", "Fire + up and right", "Fire + right", "Fire + down and right", "Fire + down", "Fire + down and left", "Fire + left", "Fire + up and left"];
}

function anim_mode_names()
{
    return ["Loop", "Once (then hold)", "Ping-pong"];
}

/// True when the member has frames here (they replace its sprite's Sprites page animation)
function anims_used(_h)
{
    for (var i = 0; i < ANIM_COUNT; i++)
    {
        if (array_length(_h.anims[i].frames) > 0) { return true; }
    }
    return false;
}

/// True when the joystick directions have frames: they are used instead of Walk
function anims_dirs_on(_h)
{
    for (var i = ANIM_DIR0; i < ANIM_DIR0 + 8; i++)
    {
        if (array_length(_h.anims[i].frames) > 0) { return true; }
    }
    return false;
}

/// True when the member has Fire animations (only the player can hold fire)
function anims_fire_used(_it)
{
    if (!_it.fire) { return false; }
    for (var i = ANIM_FIRE0; i < ANIM_COUNT; i++)
    {
        if (array_length(_it.h.anims[i].frames) > 0) { return true; }
    }
    return false;
}

// ---------------------------------------------------------------------------
// The cast
// ---------------------------------------------------------------------------

/// The cast of project _p: { name, sub, h (holds anims and anim_flip), sprite, colour,
/// gravity (Jump and Fall are used), fire (Fire animations are used), member (its number in
/// the game's animation tables), still_idle (the Sprites page animation only plays while it moves) }
function anim_cast(_p)
{
    var _out = [];
    if (_p.game_type == 1)
    {
        var _e = _p.eng;
        array_push(_out, { name : "Player", sub : "Player", h : _e.anim_p, sprite : clamp(_e.pspr, 0, SPR_COUNT - 1), colour : _e.pcol, gravity : (_e.kind == KIND_PLAT), fire : true, member : 0, still_idle : true });
        array_push(_out, { name : "Player's shot", sub : "Shot", h : _e.anim_b, sprite : clamp(_e.bspr, 0, SPR_COUNT - 1), colour : _e.bcol, gravity : false, fire : false, member : 1, still_idle : false });
        array_push(_out, { name : "Enemy shot", sub : "Shot", h : _e.anim_eb, sprite : clamp(_e.ebspr, 0, SPR_COUNT - 1), colour : _e.ebcol, gravity : false, fire : false, member : 2, still_idle : false });
        for (var i = 0; i < min(16, array_length(_p.enemies)); i++)
        {
            var _en = _p.enemies[i];
            array_push(_out, { name : _en.name, sub : "Enemy", h : _en, sprite : clamp(_en.spr, 0, SPR_COUNT - 1), colour : _en.col, gravity : false, fire : false, member : 3 + i, still_idle : false });
        }
        return _out;
    }
    var _rn = ["Player", "Bouncer", "Patrol L-R", "Patrol U-D", "Chaser", "Still"];
    for (var a = 0; a < min(8, array_length(_p.actors)); a++)
    {
        var _ac = _p.actors[a];
        array_push(_out, { name : _ac.name, sub : _rn[clamp(_ac.role, 0, 5)], h : _ac, sprite : clamp(_ac.sprite, 0, SPR_COUNT - 1), colour : _ac.colour, gravity : false, fire : (_ac.role == 0), member : a, still_idle : false });
    }
    return _out;
}

/// The first change on the Animate page starts from the member's Sprites page animation
/// (its sprite's frames and speed; left-facing frames become the Left direction)
function anim_seed_from_legacy(_it)
{
    var _h = _it.h;
    if (anims_used(_h)) { return; }
    var _sp = proj.sprites[_it.sprite];
    if (_sp.frames <= 1) { return; }
    var _n = min(_sp.frames, 4);
    var _right = [];
    for (var f = 0; f < _n; f++) { array_push(_right, min(SPR_COUNT - 1, _it.sprite + f)); }
    var _rate = clamp(1 << clamp(_sp.anim_speed, 0, 5), 2, 30);
    _h.anims[1] = { frames : _right, rate : _rate, mode : 0 };
    if (!_it.still_idle) { _h.anims[0] = { frames : variable_clone(_right), rate : _rate, mode : 0 }; }
    if (_sp.left)
    {
        var _left = [];
        for (var g = 0; g < _n; g++) { array_push(_left, min(SPR_COUNT - 1, _it.sprite + _n + g)); }
        _h.anims[ANIM_DIR0 + 2] = { frames : variable_clone(_right), rate : _rate, mode : 0 };
        _h.anims[ANIM_DIR0 + 6] = { frames : _left, rate : _rate, mode : 0 };
    }
}

// ---------------------------------------------------------------------------
// The plan: what the game plays (ADAM's anim_plan)
// ---------------------------------------------------------------------------

/// The directions tried, in order, for each of the 8 when it has no frames: [entry, turn]
/// pairs - turn 1 = turned round (only with anim_flip), 2 = turned round when anim_flip is on;
/// entry 1 is Walk
function anim_dir_chains()
{
    return [
        [[4, 0], [1, 0]],
        [[5, 0], [11, 1], [6, 0], [10, 1], [1, 0]],
        [[6, 0], [10, 1], [1, 0]],
        [[7, 0], [9, 1], [6, 0], [10, 1], [1, 0]],
        [[8, 0], [1, 0]],
        [[9, 0], [7, 1], [10, 0], [6, 1], [1, 2]],
        [[10, 0], [6, 1], [1, 2]],
        [[11, 0], [5, 1], [10, 0], [6, 1], [1, 2]]
    ];
}

function anim_resolve_dirs(_e, _base, _walk, _flip)
{
    var _chains = anim_dir_chains();
    var _dirs = array_create(8, undefined);
    for (var d = 0; d < 8; d++)
    {
        var _ch = _chains[d];
        for (var c = 0; c < array_length(_ch); c++)
        {
            var _k = _ch[c][0];
            var _t = _ch[c][1];
            if (_t == 1 && !_flip) { continue; }
            var _src = _walk;
            if (_k != 1) { _src = _e[_k - ANIM_DIR0 + _base]; }
            if (!is_undefined(_src))
            {
                var _fl = false;
                if (_t == 1) { _fl = true; }
                if (_t == 2 && _flip) { _fl = true; }
                if (_src.flip) { _fl = !_fl; }
                _dirs[d] = { frames : _src.frames, rate : _src.rate, mode : _src.mode, flip : _fl };
                break;
            }
        }
    }
    for (var d2 = 0; d2 < 8; d2++)
    {
        if (is_undefined(_dirs[d2]))
        {
            if (!is_undefined(_dirs[2])) { _dirs[d2] = _dirs[2]; }
            else if (!is_undefined(_dirs[6])) { _dirs[d2] = _dirs[6]; }
        }
    }
    return _dirs;
}

/// What the game plays: undefined (no frames here), else 4 (12 with directions, 21 with Fire)
/// x { frames, rate, mode, flip } with empty animations filled in from the others
/// (flip = turned round; mode 3 = stand facing the way it last moved)
function anim_plan(_it)
{
    var _h = _it.h;
    if (!anims_used(_h)) { return undefined; }
    var _e = [];
    for (var i = 0; i < ANIM_COUNT; i++)
    {
        var _src = _h.anims[i];
        if (array_length(_src.frames) > 0) { array_push(_e, { frames : _src.frames, rate : clamp(_src.rate, 2, 30), mode : clamp(_src.mode, 0, 2), flip : false }); }
        else { array_push(_e, undefined); }
    }
    var _idle = _e[0];
    var _walk = _e[1];
    var _jump = _e[2];
    var _fall = _e[3];
    var _dirs = undefined;
    var _one = { frames : [_it.sprite], rate : 8, mode : 0, flip : false };
    if (anims_dirs_on(_h))
    {
        var _w0 = _walk;
        if (is_undefined(_w0)) { _w0 = _idle; }
        _dirs = anim_resolve_dirs(_e, ANIM_DIR0, _w0, _h.anim_flip);
        for (var d = 0; d < 8; d++)
        {
            if (is_undefined(_dirs[d])) { _dirs[d] = _one; }
        }
        if (is_undefined(_idle)) { _idle = { frames : [_it.sprite], rate : 8, mode : 3, flip : false }; }
        if (is_undefined(_walk)) { _walk = _dirs[2]; }
    }
    else
    {
        if (is_undefined(_idle))
        {
            if (!is_undefined(_walk)) { _idle = _walk; }
            else { _idle = _one; }
        }
        if (is_undefined(_walk)) { _walk = _idle; }
    }
    if (is_undefined(_jump)) { _jump = _walk; }
    if (is_undefined(_fall)) { _fall = _jump; }
    var _out = [_idle, _walk, _jump, _fall];
    if (anims_fire_used(_it))
    {
        if (is_undefined(_dirs)) { _dirs = array_create(8, _walk); }
        var _fstand = _e[ANIM_FIRE0];
        var _fd = anim_resolve_dirs(_e, ANIM_FIRE0 + 1, _fstand, _h.anim_flip);
        if (is_undefined(_fstand))
        {
            if (!is_undefined(_fd[2])) { _fstand = _fd[2]; }
            else if (!is_undefined(_fd[6])) { _fstand = _fd[6]; }
            else { _fstand = _idle; }
        }
        for (var d3 = 0; d3 < 8; d3++)
        {
            if (is_undefined(_fd[d3])) { _fd[d3] = _fstand; }
        }
        for (var d4 = 0; d4 < 8; d4++) { array_push(_out, _dirs[d4]); }
        array_push(_out, _fstand);
        for (var d5 = 0; d5 < 8; d5++) { array_push(_out, _fd[d5]); }
        return _out;
    }
    if (!is_undefined(_dirs))
    {
        for (var d6 = 0; d6 < 8; d6++) { array_push(_out, _dirs[d6]); }
    }
    return _out;
}

/// Frame number 0..n-1 of an animation _ticks 50ths of a second after it started
function anim_frame_at(_e, _ticks)
{
    var _n = array_length(_e.frames);
    if (_n <= 1) { return 0; }
    var _steps = floor(_ticks / max(2, _e.rate));
    if (_e.mode == 1) { return min(_steps, _n - 1); }
    if (_e.mode == 2)
    {
        var _per = 2 * _n - 2;
        var _m = _steps mod _per;
        if (_m >= _n) { return _per - _m; }
        return _m;
    }
    return _steps mod _n;
}

/// The sprite a cast member shows in lists right now (its Idle, or its sprite)
function anim_cast_preview_sprite(_it)
{
    var _plan = anim_plan(_it);
    if (is_undefined(_plan)) { return _it.sprite; }
    var _e = _plan[0];
    if (_e.mode == 3) { _e = _plan[ANIM_DIR0 + 2]; }
    return _e.frames[anim_frame_at(_e, current_time div 20)];
}

// ---------------------------------------------------------------------------
// Mirrored sprites
// ---------------------------------------------------------------------------

/// The 63 bytes of sprite _s turned round (left to right)
function sprite_mirror_bytes(_s)
{
    var _m = sprite_new("m");
    _m.mc = _s.mc;
    for (var r = 0; r < 21; r++)
    {
        for (var c = 0; c < 24; c++) { _m.hi[r * 24 + c] = _s.hi[r * 24 + 23 - c]; }
        for (var c2 = 0; c2 < 12; c2++) { _m.mcp[r * 12 + c2] = _s.mcp[r * 12 + 11 - c2]; }
    }
    return sprite_encode(_m);
}

/// Draws sprite _i, turned round when _flip
function draw_sprite_c64_flip(_i, _x, _y, _scale, _flip, _colour, _alpha)
{
    if (!_flip)
    {
        draw_sprite_c64(_i, _x, _y, _scale, _colour, _alpha);
        return;
    }
    if (_i < 0 || _i >= SPR_COUNT) { return; }
    spr_cache_update(_i);
    gpu_set_texfilter(false);
    var _x2 = _x + 24 * _scale;
    draw_surface_ext(spr_surf_sh[_i], _x2, _y, -_scale, _scale, 0, c64col(proj.mc1), _alpha);
    draw_surface_ext(spr_surf_sh2[_i], _x2, _y, -_scale, _scale, 0, c64col(proj.mc2), _alpha);
    draw_surface_ext(spr_surf_own[_i], _x2, _y, -_scale, _scale, 0, c64col(_colour), _alpha);
    gpu_set_texfilter(true);
}

// ---------------------------------------------------------------------------
// What the game gets: tables built from the plans
// ---------------------------------------------------------------------------

/// { on, members[] ({ on, n, flags, row[] }), entries[] ({ frames[] (sprite slots, 32+ =
/// mirrored), rate, mode }), mirrors[] (the slot each mirrored copy is of), warnings[] }.
/// A member's row maps its animation number (0..n-1, then n..n+3 = Idle .. Fall turned round
/// for facing left) to an entry; flags: 1 Fire, 2 directions, 4 turn round to face left.
function anim_build(_p)
{
    var _b = { on : false, members : [], entries : [], mirrors : [], warnings : [] };
    var _cast = anim_cast(_p);
    var _ekeys = {};
    var _mirror_of = {};
    var _full = false;
    for (var c = 0; c < array_length(_cast); c++)
    {
        var _it = _cast[c];
        var _plan = anim_plan(_it);
        var _m = { on : false, n : 0, flags : 0, row : [] };
        if (is_undefined(_plan))
        {
            array_push(_b.members, _m);
            continue;
        }
        _b.on = true;
        _m.on = true;
        _m.n = array_length(_plan);
        if (anims_fire_used(_it)) { _m.flags |= 1; }
        if (anims_dirs_on(_it.h)) { _m.flags |= 2; }
        var _basic_flip = (_it.h.anim_flip && !anims_dirs_on(_it.h));
        if (_basic_flip) { _m.flags |= 4; }
        var _list = [];
        for (var k = 0; k < _m.n; k++) { array_push(_list, [_plan[k], _plan[k].flip]); }
        if (_basic_flip)
        {
            for (var k2 = 0; k2 < 4; k2++) { array_push(_list, [_plan[k2], !_plan[k2].flip]); }
        }
        for (var q = 0; q < array_length(_list); q++)
        {
            var _pe = _list[q][0];
            var _fl = _list[q][1];
            var _fr = [];
            for (var f = 0; f < array_length(_pe.frames); f++)
            {
                var _slot = clamp(_pe.frames[f], 0, SPR_COUNT - 1);
                if (_fl)
                {
                    var _mk = string(_slot);
                    var _mi = _mirror_of[$ _mk];
                    if (is_undefined(_mi))
                    {
                        if (array_length(_b.mirrors) < ANIM_MIRRORS)
                        {
                            _mi = SPR_COUNT + array_length(_b.mirrors);
                            array_push(_b.mirrors, _slot);
                            _mirror_of[$ _mk] = _mi;
                        }
                        else
                        {
                            _mi = _slot;
                            if (!_full) { array_push(_b.warnings, "More than " + string(ANIM_MIRRORS) + " sprites are turned round - the rest face the way they are drawn. Draw some left-facing frames instead."); }
                            _full = true;
                        }
                    }
                    _slot = _mi;
                }
                array_push(_fr, _slot);
            }
            var _ent = { frames : _fr, rate : clamp(_pe.rate, 2, 30), mode : clamp(_pe.mode, 0, 3) };
            var _key = json_stringify(_ent);
            var _id = _ekeys[$ _key];
            if (is_undefined(_id))
            {
                _id = array_length(_b.entries);
                array_push(_b.entries, _ent);
                _ekeys[$ _key] = _id;
            }
            array_push(_m.row, _id);
        }
        array_push(_b.members, _m);
    }
    // multicolour or not, for every slot the VIC-II may be pointed at
    _b.mc = array_create(SPR_COUNT + ANIM_MIRRORS, 0);
    for (var sm = 0; sm < SPR_COUNT; sm++) { _b.mc[sm] = (_p.sprites[sm].mc ? 1 : 0); }
    for (var mm = 0; mm < array_length(_b.mirrors); mm++) { _b.mc[SPR_COUNT + mm] = _b.mc[_b.mirrors[mm]]; }
    if (array_length(_b.entries) > 255)
    {
        array_push(_b.warnings, "The animations are too varied for the game's tables (more than 255 different ones).");
        _b.on = false;
    }
    return _b;
}

/// The mirrored sprites' data (64 bytes each, after the 32 drawn sprites)
function anim_emit_mirrors(L, _p, _b)
{
    for (var i = 0; i < array_length(_b.mirrors); i++)
    {
        var _bytes = sprite_mirror_bytes(_p.sprites[_b.mirrors[i]]);
        array_push(L, " .byte " + cg_join_bytes(_bytes, 0, 63) + ",0");
    }
}

/// Pushes anim_upd, the tables and its variables onto L.
/// anim_upd: X = the sprite's slot (0..7), A = cast member, an_dx / an_dy = how far it moved
/// since the last frame, an_air = 0 on the ground, 1 going up, 2 coming down, an_fire != 0 =
/// fire held. Returns carry set and A = the sprite slot to show (0..63), or carry clear when the
/// member has no animations here. X is kept.
function anim_emit(L, _b)
{
    array_push(L, "; ---------------- animations (Animate page) ----------------", "anim_start:");
    array_push(L, "anim_upd:", " sta an_m", " tay", " lda cm_on,y", " bne au_go", " clc", " rts");
    // a move of more than 16 pixels is a jump to a new place (a new life, a new level): not a move
    array_push(L, "au_go:", " lda an_dx", " clc", " adc #16", " cmp #33", " bcs au_tp", " lda an_dy", " clc", " adc #16", " cmp #33", " bcc au_mv");
    array_push(L, "au_tp:", " lda #0", " sta an_dx", " sta an_dy");
    // which way: 3 x (dx sign + 1) + (dy sign + 1) -> direction 0..7, 255 = not moving; facing left or right
    array_push(L, "au_mv:", " ldy #4", " lda an_dx", " beq au_x0", " bmi au_xl", " iny", " iny", " iny", " lda #0", " sta as_left,x", " beq au_x0");
    array_push(L, "au_xl:", " dey", " dey", " dey", " lda #1", " sta as_left,x");
    array_push(L, "au_x0:", " lda an_dy", " beq au_y0", " bmi au_yu", " iny", " bne au_y0");
    array_push(L, "au_yu:", " dey");
    array_push(L, "au_y0:", " lda an_dir9,y", " bmi au_st", " sta as_dir,x", " lda #1", " sta an_mv", " bne au_pk");
    array_push(L, "au_st:", " lda #0", " sta an_mv");
    // which animation: holding fire, in the air, moving, standing
    array_push(L, "au_pk:", " ldy an_m", " lda cm_flags,y", " sta an_fl");
    array_push(L, " lda an_fire", " beq au_nf", " lda an_fl", " and #1", " beq au_nf", " lda an_mv", " beq au_f0", " lda as_dir,x", " clc", " adc #13", " bne au_k");
    array_push(L, "au_f0:", " lda #12", " bne au_k");
    array_push(L, "au_nf:", " lda an_air", " beq au_gd", " clc", " adc #1", " bne au_k");
    array_push(L, "au_gd:", " lda an_mv", " beq au_id", " lda an_fl", " and #2", " beq au_wk", " lda as_dir,x", " clc", " adc #4", " bne au_k");
    array_push(L, "au_wk:", " lda #1", " bne au_k");
    array_push(L, "au_id:", " lda #0");
    // facing left: Idle .. Fall turned round (after the member's own animations)
    array_push(L, "au_k:", " sta an_k", " cmp #4", " bcs au_k2", " lda an_fl", " and #4", " beq au_k2", " lda as_left,x", " beq au_k2", " lda an_k", " clc", " adc cm_n,y", " sta an_k");
    array_push(L, "au_k2:", " lda cm_rlo,y", " sta au_mr+1", " sta au_ms+1", " lda cm_rhi,y", " sta au_mr+2", " sta au_ms+2", " ldy an_k");
    array_push(L, "au_mr:", " lda $ffff,y", " tay", " lda #0", " sta an_fz", " lda en_mode,y", " cmp #3", " bne au_e");
    // stand facing the way it last moved: that direction's first frame, held
    array_push(L, " lda as_dir,x", " clc", " adc #4", " sta an_k", " tay");
    array_push(L, "au_ms:", " lda $ffff,y", " tay", " lda #1", " sta an_fz");
    array_push(L, "au_e:", " sty an_e", " tya", " sta as_e,x");
    // a different animation starts from its first frame
    array_push(L, " lda an_k", " cmp as_k,x", " bne au_nw", " lda an_m", " cmp as_m,x", " bne au_nw", " lda an_fz", " beq au_ol");
    array_push(L, "au_nw:", " lda an_k", " sta as_k,x", " lda an_m", " sta as_m,x", " lda #0", " sta as_f,x", " sta as_t,x", " sta as_pd,x", " jmp au_out");
    // the speed: a new frame every en_rate frames
    array_push(L, "au_ol:", " inc as_t,x", " lda as_t,x", " cmp en_rate,y", " bcc au_out", " lda #0", " sta as_t,x", " lda en_mode,y", " beq au_lp", " cmp #1", " beq au_on");
    // ping-pong
    array_push(L, " lda en_cnt,y", " cmp #2", " bcc au_z", " lda as_pd,x", " bne au_bk", " inc as_f,x", " lda as_f,x", " clc", " adc #1", " cmp en_cnt,y", " bcc au_out", " lda #1", " sta as_pd,x", " bne au_out");
    array_push(L, "au_bk:", " dec as_f,x", " bne au_out", " lda #0", " sta as_pd,x", " beq au_out");
    array_push(L, "au_z:", " lda #0", " sta as_f,x", " beq au_out");
    // loop
    array_push(L, "au_lp:", " inc as_f,x", " lda as_f,x", " cmp en_cnt,y", " bcc au_out", " lda #0", " sta as_f,x", " beq au_out");
    // once, then hold the last frame
    array_push(L, "au_on:", " lda as_f,x", " clc", " adc #1", " cmp en_cnt,y", " bcs au_out", " inc as_f,x");
    // the frame
    array_push(L, "au_out:", " ldy an_e", " lda en_flo,y", " sta au_fr+1", " lda en_fhi,y", " sta au_fr+2", " ldy as_f,x");
    array_push(L, "au_fr:", " lda $ffff,y", " sec", " rts");
    // anim_hold (X = slot, A = member): the frame it shows now, without moving the animation on
    // (a frame where nothing moved, like the map engine's coarse scroll frames)
    array_push(L, "anim_hold:", " cmp as_m,x", " beq ah_0", " jmp anim_upd", "ah_0:", " tay", " lda cm_on,y", " bne ah_1", " clc", " rts", "ah_1:", " lda as_e,x", " sta an_e", " jmp au_out");
    // tables
    array_push(L, "an_dir9:", " .byte 7,6,5,0,255,4,1,2,3");
    var _mcs = [];
    for (var q = 0; q < array_length(_b.mc); q++) { array_push(_mcs, string(_b.mc[q])); }
    array_push(L, "an_mc:", " .byte " + string_join_ext(",", _mcs));
    var _nm = max(1, array_length(_b.members));
    var _on = [], _fl = [], _n = [], _rl = [], _rh = [];
    for (var m = 0; m < _nm; m++)
    {
        var _mm = { on : false, n : 0, flags : 0, row : [] };
        if (m < array_length(_b.members)) { _mm = _b.members[m]; }
        array_push(_on, string(_mm.on ? 1 : 0));
        array_push(_fl, string(_mm.flags));
        array_push(_n, string(_mm.n));
        if (_mm.on)
        {
            array_push(_rl, "<anr_" + string(m));
            array_push(_rh, ">anr_" + string(m));
        }
        else
        {
            array_push(_rl, "0");
            array_push(_rh, "0");
        }
    }
    array_push(L, "cm_on:", " .byte " + string_join_ext(",", _on), "cm_flags:", " .byte " + string_join_ext(",", _fl), "cm_n:", " .byte " + string_join_ext(",", _n));
    array_push(L, "cm_rlo:", " .byte " + string_join_ext(",", _rl), "cm_rhi:", " .byte " + string_join_ext(",", _rh));
    for (var m2 = 0; m2 < array_length(_b.members); m2++)
    {
        if (!_b.members[m2].on) { continue; }
        var _row = [];
        for (var r = 0; r < array_length(_b.members[m2].row); r++) { array_push(_row, string(_b.members[m2].row[r])); }
        array_push(L, "anr_" + string(m2) + ":", " .byte " + string_join_ext(",", _row));
    }
    var _ne = max(1, array_length(_b.entries));
    var _t = [[], [], [], [], []];
    for (var e = 0; e < _ne; e++)
    {
        var _en = { frames : [0], rate : 8, mode : 0 };
        if (e < array_length(_b.entries)) { _en = _b.entries[e]; }
        array_push(_t[0], "<anf_" + string(e));
        array_push(_t[1], ">anf_" + string(e));
        array_push(_t[2], string(array_length(_en.frames)));
        array_push(_t[3], string(_en.rate));
        array_push(_t[4], string(_en.mode));
    }
    var _tn = ["en_flo", "en_fhi", "en_cnt", "en_rate", "en_mode"];
    for (var tt = 0; tt < 5; tt++) { array_push(L, _tn[tt] + ":", " .byte " + string_join_ext(",", _t[tt])); }
    for (var e2 = 0; e2 < _ne; e2++)
    {
        var _fr = [0];
        if (e2 < array_length(_b.entries)) { _fr = _b.entries[e2].frames; }
        var _fs = [];
        for (var f = 0; f < array_length(_fr); f++) { array_push(_fs, string(_fr[f])); }
        array_push(L, "anf_" + string(e2) + ":", " .byte " + string_join_ext(",", _fs));
    }
    // per sprite: animation number and member playing, frame, tick, ping-pong way, last direction, facing left, last position
    var _sv = ["as_k", "as_m", "as_e", "as_f", "as_t", "as_pd", "as_dir", "as_left", "as_px", "as_py"];
    for (var v = 0; v < array_length(_sv); v++) { array_push(L, _sv[v] + ":", " .fill 8,0"); }
    var _gv = ["an_m", "an_dx", "an_dy", "an_air", "an_fire", "an_mv", "an_fl", "an_k", "an_e", "an_fz"];
    for (var v2 = 0; v2 < array_length(_gv); v2++) { array_push(L, _gv[v2] + ":", " .fill 1,0"); }
    array_push(L, "anim_end:");
}

/// GML model of anim_upd (keep in step with anim_emit): state _st (as_* of one sprite),
/// member _m, inputs; returns the sprite slot, or -1 when the member has no animations
function anim_sim(_b, _st, _m, _dx, _dy, _air, _fire)
{
    if (_m >= array_length(_b.members) || !_b.members[_m].on) { return -1; }
    var _mm = _b.members[_m];
    if (_dx < -16 || _dx > 16 || _dy < -16 || _dy > 16)
    {
        _dx = 0;
        _dy = 0;
    }
    var _y = 4;
    if (_dx > 0) { _y += 3; _st.left = 0; }
    if (_dx < 0) { _y -= 3; _st.left = 1; }
    if (_dy > 0) { _y += 1; }
    if (_dy < 0) { _y -= 1; }
    var _d9 = [7, 6, 5, 0, 255, 4, 1, 2, 3];
    var _mv = 0;
    if (_d9[_y] != 255)
    {
        _st.dir = _d9[_y];
        _mv = 1;
    }
    var _k = 0;
    if (_fire && (_mm.flags & 1)) { _k = (_mv ? 13 + _st.dir : 12); }
    else if (_air != 0) { _k = _air + 1; }
    else if (_mv) { _k = ((_mm.flags & 2) ? 4 + _st.dir : 1); }
    if (_k < 4 && (_mm.flags & 4) && _st.left) { _k += _mm.n; }
    var _e = _mm.row[_k];
    var _fz = 0;
    if (_b.entries[_e].mode == 3)
    {
        _k = 4 + _st.dir;
        _e = _mm.row[_k];
        _fz = 1;
    }
    var _en = _b.entries[_e];
    var _cnt = array_length(_en.frames);
    if (_k != _st.k || _m != _st.m || _fz)
    {
        _st.k = _k;
        _st.m = _m;
        _st.f = 0;
        _st.t = 0;
        _st.pd = 0;
    }
    else
    {
        _st.t = (_st.t + 1) & 255;
        if (_st.t >= _en.rate)
        {
            _st.t = 0;
            if (_en.mode == 0)
            {
                _st.f += 1;
                if (_st.f >= _cnt) { _st.f = 0; }
            }
            else if (_en.mode == 1)
            {
                if (_st.f + 1 < _cnt) { _st.f += 1; }
            }
            else
            {
                if (_cnt < 2) { _st.f = 0; }
                else if (_st.pd == 0)
                {
                    _st.f += 1;
                    if (_st.f + 1 >= _cnt) { _st.pd = 1; }
                }
                else
                {
                    _st.f -= 1;
                    if (_st.f == 0) { _st.pd = 0; }
                }
            }
        }
    }
    return _en.frames[_st.f];
}
