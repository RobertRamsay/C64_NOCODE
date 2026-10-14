/// C64 NO-CODE STUDIO - turns the no-code project into 6502 assembly
/// Memory: BASIC stub $0801, code, vars, sprites aligned at >= $2000, screen + colour data after.

#macro CG_XMIN 24
#macro CG_XMAX 320
#macro CG_YMIN 50
#macro CG_YMAX 229

function cg_bcd(_n)
{
    var _v = clamp(floor(_n), 0, 9999);
    var _hi = ((_v div 1000) << 4) | ((_v div 100) mod 10);
    var _lo = (((_v div 10) mod 10) << 4) | (_v mod 10);
    return [_hi, _lo];
}

function cg_text_bytes(_s)
{
    var _t = string_upper(string_copy(_s, 1, 40));
    var _pad = (40 - string_length(_t)) div 2;
    var _out = "";
    for (var p = 0; p < _pad; p++) { _out += "32,"; }
    for (var i = 1; i <= string_length(_t); i++)
    {
        _out += string(scr_code_from_char(string_char_at(_t, i))) + ",";
    }
    return _out + "255";
}

function cg_join_bytes(_arr, _from, _count)
{
    var _s = "";
    for (var i = 0; i < _count; i++)
    {
        if (i > 0) { _s += ","; }
        _s += string(_arr[_from + i] & 255);
    }
    return _s;
}

/// The DO actions that change an actor (their target is an actor)
function cg_act_needs_actor(_act)
{
    return (_act == 4 || _act == 5 || _act == 6 || _act == 7 || _act == 8 || _act == 12 || _act == 13 || _act == 15);
}

/// Pushes one DO line as a subroutine body (it ends with rts or a jmp to a routine that returns)
function cg_do_lines(L, _p, _d, _tag, na)
{
    var _acts = _p.actors;
    var _act = _d.act;
    var _tg = _d.target;
    var _ts = string(_tg);
    if (cg_act_needs_actor(_act) && _tg >= na)
    {
        array_push(L, " rts");
        return;
    }
    switch (_act)
    {
        case 0:
            var _sb = cg_bcd(max(1, _d.value));
            array_push(L, " lda #" + string(_sb[1]), " ldx #" + string(_sb[0]), " jmp add_score");
            break;
        case 1:
            array_push(L, " lda lives", " beq la" + _tag, " dec lives", "la" + _tag + ":", " jmp draw_hud");
            break;
        case 2:
            array_push(L, " lda #" + string(clamp(_d.value, 0, array_length(_p.sfx) - 1)), " jmp play_sfx");
            break;
        case 3:
            array_push(L, " lda #16", " sta flash", " rts");
            break;
        case 4:
            var _sx = clamp(floor(_acts[_tg].x), CG_XMIN, CG_XMAX);
            var _sy = clamp(floor(_acts[_tg].y), CG_YMIN, CG_YMAX);
            array_push(L, " lda #" + string(_sx & 255), " sta ax_lo+" + _ts, " lda #" + string(_sx >> 8), " sta ax_hi+" + _ts);
            array_push(L, " lda #" + string(_sy), " sta ay+" + _ts, " rts");
            break;
        case 5:
            array_push(L, " jsr rnd", " clc", " adc #" + string(CG_XMIN), " sta ax_lo+" + _ts, " lda #0", " adc #0", " sta ax_hi+" + _ts);
            array_push(L, " jsr rnd", " and #127", " clc", " adc #60", " sta ay+" + _ts, " rts");
            break;
        case 6:
            array_push(L, " lda #0", " sta avis+" + _ts, " rts");
            break;
        case 7:
            array_push(L, " lda #1", " sta avis+" + _ts, " rts");
            break;
        case 8:
            array_push(L, " lda #" + string(clamp(_d.value, 0, 15)), " sta $d027+" + _ts, " rts");
            break;
        case 9:
            array_push(L, " lda #" + string(clamp(_d.value, 0, 15)), " sta $d021", " rts");
            break;
        case 10:
            if (_p.pic_over >= 0 && _p.pic_over < array_length(_p.pictures)) { array_push(L, " lda #" + string(bmp_slot(bmp_game_list(_p), _p.pic_over)), " jmp pic_end_scr"); }
            else { array_push(L, " ldx #<txt_over", " ldy #>txt_over", " jmp end_screen"); }
            break;
        case 11:
            if (_p.pic_win >= 0 && _p.pic_win < array_length(_p.pictures)) { array_push(L, " lda #" + string(bmp_slot(bmp_game_list(_p), _p.pic_win)), " jmp pic_end_scr"); }
            else { array_push(L, " ldx #<txt_win", " ldy #>txt_win", " jmp end_screen"); }
            break;
        case 12:
            array_push(L, " lda aspd+" + _ts, " cmp #8", " bcs sp" + _tag, " inc aspd+" + _ts, "sp" + _tag + ":", " rts");
            break;
        case 13:
            array_push(L, " lda aspd+" + _ts, " cmp #2", " bcc sl" + _tag, " dec aspd+" + _ts, "sl" + _tag + ":", " rts");
            break;
        case 14:
            array_push(L, " lda lives", " cmp #9", " bcs al" + _tag, " inc lives", "al" + _tag + ":", " jmp draw_hud");
            break;
        case 15:
            var _to = clamp(_d.value, 0, max(0, na - 1));
            var _os = string(_to);
            array_push(L, " lda ax_lo+" + _os, " sta ax_lo+" + _ts, " lda ax_hi+" + _os, " sta ax_hi+" + _ts);
            array_push(L, " lda ay+" + _os, " sta ay+" + _ts, " rts");
            break;
        case 16:
            array_push(L, " jmp sfx_stop");
            break;
        case 17:
            array_push(L, " lda #" + string(clamp(_d.value, 0, max(0, array_length(_p.songs) - 1))), " jmp mus_play");
            break;
        case 18:
            array_push(L, " jmp mus_stop");
            break;
        case 19:
            // show a bitmap: for some seconds, or until fire is pressed and let go
            var _ps = bmp_slot(bmp_game_list(_p), _d.value);
            if (_ps == 255) { array_push(L, " rts"); }
            else { array_push(L, " lda #" + string(_ps), " ldx #" + string(clamp(_d.target, 0, 30)), " jmp pic_show"); }
            break;
        default:
            array_push(L, " rts");
            break;
    }
}

/// Returns { src, warnings[], lines[], marks[] } - marks are { rule, from, to } line ranges
/// (the rule's check and its actions) for the code previewer.
function codegen_project(_p)
{
    var L = [];
    var _warn = [];
    var _marks = [];
    var _acts = _p.actors;
    var na = min(8, array_length(_acts));
    var _rules = _p.rules;
    var nr = array_length(_rules);
    // a rule in a group that is switched off (or inside one) is left out of the game
    var _on = array_create(nr, true);
    var _non = 0;
    for (var ro = 0; ro < nr; ro++)
    {
        _on[ro] = !group_off_in(_p.groups, _rules[ro].group);
        if (_on[ro]) { _non += 1; }
    }
    if (_non < nr) { array_push(_warn, string(nr - _non) + " rule(s) are in groups that are switched off - they are not in the game."); }
    var _player = -1;
    for (var i = 0; i < na; i++)
    {
        if (_acts[i].role == 0)
        {
            _player = i;
            break;
        }
    }
    if (na == 0) { array_push(_warn, "There are no actors yet - the game will just show your screen."); }
    if (_player < 0 && na > 0) { array_push(_warn, "No actor is set as Player, so the joystick will not move anything."); }
    var _ab = anim_build(_p);
    for (var aw = 0; aw < array_length(_ab.warnings); aw++) { array_push(_warn, _ab.warnings[aw]); }
    var _chase_target = _player;
    if (_chase_target < 0) { _chase_target = 0; }

    var _names = ["ax_lo", "ax_hi", "ay", "aspd", "avis", "adx", "ady", "latch",
                  "joy", "fcount", "sectick", "coll", "bcoll", "tmp", "tmp2", "lives", "score_lo", "score_hi", "flash", "acnt"];
    var _sizes = [8, 8, 8, 8, 8, 8, 8, max(1, nr), 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
    var _varlen = 0;
    for (var vl = 0; vl < array_length(_sizes); vl++) { _varlen += _sizes[vl]; }

    array_push(L, "; Generated by C64 No-Code Studio - " + _p.name);
    array_push(L, "; Target: " + machine_cur().name + " - " + string(sid_fps()) + " frames a second");
    array_push(L, "* = $0801");
    array_push(L, " .byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00");
    array_push(L, "ptr = $fb");
    array_push(L, "start:");
    array_push(L, " sei", " cld", " ldx #$ff", " txs");
    array_push(L, "restart:");
    array_push(L, " ldx #0", " lda #0");
    array_push(L, "clrv:", " sta vars,x", " inx", " cpx #" + string(_varlen), " bne clrv");
    array_push(L, " lda #" + string(_p.border), " sta $d020", " lda #" + string(_p.background), " sta $d021");
    array_push(L, " lda #$1b", " sta $d011", " jsr set_chars", " lda #$c8", " sta $d016");
    array_push(L, " jsr draw_screen");
    array_push(L, " jsr sfx_init");
    // the screen's song (Music page: Where the music plays); one already playing carries on
    array_push(L, " lda #0", " jsr mus_level");

    var _mc = 0;
    for (var a = 0; a < na; a++)
    {
        var _ac = _acts[a];
        var _si = clamp(_ac.sprite, 0, SPR_COUNT - 1);
        if (_p.sprites[_si].mc) { _mc = _mc | (1 << a); }
        var _x = clamp(floor(_ac.x), CG_XMIN, CG_XMAX);
        var _y = clamp(floor(_ac.y), CG_YMIN, CG_YMAX);
        var _sa = string(a);
        array_push(L, " lda #spr_data/64+" + string(_si), " sta $07f8+" + _sa);
        array_push(L, " lda #" + string(_ac.colour), " sta $d027+" + _sa);
        array_push(L, " lda #" + string(_x & 255), " sta ax_lo+" + _sa);
        array_push(L, " lda #" + string(_x >> 8), " sta ax_hi+" + _sa);
        array_push(L, " lda #" + string(_y), " sta ay+" + _sa);
        array_push(L, " lda #" + string(clamp(_ac.speed, 1, 8)), " sta aspd+" + _sa);
        var _vis = 0;
        if (_ac.visible) { _vis = 1; }
        var _dx = 0;
        if (_ac.start_left) { _dx = 1; }
        var _dy = 0;
        if (_ac.start_up) { _dy = 1; }
        array_push(L, " lda #" + string(_vis), " sta avis+" + _sa);
        array_push(L, " lda #" + string(_dx), " sta adx+" + _sa);
        array_push(L, " lda #" + string(_dy), " sta ady+" + _sa);
    }
    array_push(L, " lda #" + string(_mc), " sta $d01c");
    array_push(L, " lda #" + string(_p.mc1), " sta $d025", " lda #" + string(_p.mc2), " sta $d026");
    array_push(L, " lda #0", " sta $d017", " sta $d01d", " sta $d01b");
    array_push(L, " lda #" + string(clamp(_p.lives, 0, 9)), " sta lives");
    array_push(L, " jsr draw_hud", " jsr place_sprites", " lda $d01e", " lda $d01f");
    // the title bitmap (Bitmaps page) until fire is pressed - the screen's song plays meanwhile
    var _pics = bmp_game_list(_p);
    if (_p.pic_title >= 0 && _p.pic_title < array_length(_p.pictures)) { array_push(L, " lda #" + string(bmp_slot(_pics, _p.pic_title)), " ldx #0", " jsr pic_show", " lda $d01e", " lda $d01f"); }
    for (var r0 = 0; r0 < nr; r0++)
    {
        if (_on[r0] && _rules[r0].when == 5)
        {
            var _m0 = { rule : r0, from : array_length(L), to : 0 };
            array_push(L, "; Rule " + string(r0 + 1) + ": " + logic_sentence(_rules[r0]), " jsr ract_" + string(r0));
            _m0.to = array_length(L);
            array_push(_marks, _m0);
        }
    }
    array_push(L, "mainloop:", "wr1:", " lda $d012", " cmp #250", " bne wr1", " jsr frame", " jmp mainloop");

    // ---------------- per-frame update ----------------
    array_push(L, "frame:");
    array_push(L, " lda $dc00", " eor #$ff", " and #$1f", " sta joy");
    array_push(L, " inc acnt");
    array_push(L, " lda #0", " sta sectick", " inc fcount", " lda fcount", " cmp #" + string(sid_fps()), " bcc fr1", " lda #0", " sta fcount", " inc sectick");
    array_push(L, "fr1:");

    for (var m = 0; m < na; m++)
    {
        var _role = _acts[m].role;
        var t = "_" + string(m);
        var s = string(m);
        if (_role == 0)
        {
            array_push(L, " lda joy", " and #1", " beq pu" + t);
            array_push(L, " lda ay+" + s, " sec", " sbc aspd+" + s, " cmp #" + string(CG_YMIN), " bcs pu2" + t, " lda #" + string(CG_YMIN));
            array_push(L, "pu2" + t + ":", " sta ay+" + s, "pu" + t + ":");
            array_push(L, " lda joy", " and #2", " beq pd" + t);
            array_push(L, " lda ay+" + s, " clc", " adc aspd+" + s, " cmp #" + string(CG_YMAX + 1), " bcc pd2" + t, " lda #" + string(CG_YMAX));
            array_push(L, "pd2" + t + ":", " sta ay+" + s, "pd" + t + ":");
            array_push(L, " lda joy", " and #4", " beq pl" + t);
            array_push(L, " lda ax_lo+" + s, " sec", " sbc aspd+" + s, " tax", " lda ax_hi+" + s, " sbc #0", " bne pl2" + t);
            array_push(L, " cpx #" + string(CG_XMIN), " bcs pl2" + t, " ldx #" + string(CG_XMIN));
            array_push(L, "pl2" + t + ":", " stx ax_lo+" + s, " sta ax_hi+" + s, "pl" + t + ":");
            array_push(L, " lda joy", " and #8", " beq pr" + t);
            array_push(L, " lda ax_lo+" + s, " clc", " adc aspd+" + s, " tax", " lda ax_hi+" + s, " adc #0", " beq pr2" + t);
            array_push(L, " cpx #" + string(CG_XMAX & 255), " bcc pr2" + t, " ldx #" + string(CG_XMAX & 255));
            array_push(L, "pr2" + t + ":", " stx ax_lo+" + s, " sta ax_hi+" + s, "pr" + t + ":");
        }
        if (_role == 1 || _role == 2)
        {
            array_push(L, " lda adx+" + s, " bne bl" + t);
            array_push(L, " lda ax_lo+" + s, " clc", " adc aspd+" + s, " tax", " lda ax_hi+" + s, " adc #0", " beq bs" + t);
            array_push(L, " cpx #" + string(CG_XMAX & 255), " bcc bs" + t, " ldx #" + string(CG_XMAX & 255), " lda #1", " sta adx+" + s, " jmp bs" + t);
            array_push(L, "bl" + t + ":");
            array_push(L, " lda ax_lo+" + s, " sec", " sbc aspd+" + s, " tax", " lda ax_hi+" + s, " sbc #0", " bne bs" + t);
            array_push(L, " cpx #" + string(CG_XMIN), " bcs bs" + t, " ldx #" + string(CG_XMIN), " lda #0", " sta adx+" + s);
            array_push(L, "bs" + t + ":", " stx ax_lo+" + s, " sta ax_hi+" + s);
        }
        if (_role == 1 || _role == 3)
        {
            array_push(L, " lda ady+" + s, " bne bu" + t);
            array_push(L, " lda ay+" + s, " clc", " adc aspd+" + s, " cmp #" + string(CG_YMAX + 1), " bcc bv" + t, " lda #1", " sta ady+" + s, " lda #" + string(CG_YMAX), " jmp bv" + t);
            array_push(L, "bu" + t + ":");
            array_push(L, " lda ay+" + s, " sec", " sbc aspd+" + s, " cmp #" + string(CG_YMIN), " bcs bv" + t, " lda #0", " sta ady+" + s, " lda #" + string(CG_YMIN));
            array_push(L, "bv" + t + ":", " sta ay+" + s);
        }
        if (_role == 4 && m != _chase_target)
        {
            var c = string(_chase_target);
            array_push(L, " ldy aspd+" + s, " beq cz" + t, "cl" + t + ":");
            array_push(L, " lda ax_hi+" + s, " cmp ax_hi+" + c, " bne cc" + t, " lda ax_lo+" + s, " cmp ax_lo+" + c, " beq cx" + t);
            array_push(L, "cc" + t + ":", " bcc ci" + t);
            array_push(L, " lda ax_lo+" + s, " bne cd" + t, " dec ax_hi+" + s);
            array_push(L, "cd" + t + ":", " dec ax_lo+" + s, " jmp cx" + t);
            array_push(L, "ci" + t + ":", " inc ax_lo+" + s, " bne cx" + t, " inc ax_hi+" + s);
            array_push(L, "cx" + t + ":");
            array_push(L, " lda ay+" + s, " cmp ay+" + c, " beq cy" + t, " bcc cj" + t, " dec ay+" + s, " jmp cy" + t);
            array_push(L, "cj" + t + ":", " inc ay+" + s);
            array_push(L, "cy" + t + ":", " dey", " bne cl" + t);
            array_push(L, "cz" + t + ":");
        }
    }
    // sprite-sprite ($D01E) and sprite-background ($D01F) collisions: reading clears them
    array_push(L, " jsr place_sprites", " lda $d01e", " sta coll", " lda $d01f", " sta bcoll");

    // ---------------- rules ----------------
    for (var r = 0; r < nr; r++)
    {
        var _ru = _rules[r];
        if (!_on[r]) { continue; }
        var rt = "_" + string(r);
        var rs = string(r);
        var _w = _ru.when;
        var _mk = { rule : r, from : array_length(L), to : 0 };
        array_push(L, "; Rule " + string(r + 1) + ": " + logic_sentence(_ru), "rchk_" + rs + ":");
        if (_w == 6)
        {
            if (_ru.a < na)
            {
                array_push(L, " lda bcoll", " and #" + string(1 << _ru.a), " beq rn" + rt);
                array_push(L, " lda latch+" + rs, " bne rd" + rt, " lda #1", " sta latch+" + rs, " jsr ract_" + rs, " jmp rd" + rt);
                array_push(L, "rn" + rt + ":", " lda #0", " sta latch+" + rs, "rd" + rt + ":");
            }
        }
        if (_w == 0)
        {
            if (_ru.a >= na || _ru.b >= na)
            {
                array_push(L, "rchk_" + rs + "_e:");
                _mk.to = array_length(L);
                array_push(_marks, _mk);
                continue;
            }
            if (_ru.a == _ru.b)
            {
                array_push(L, " lda coll", " and #" + string(1 << _ru.a), " beq rn" + rt);
            }
            else
            {
                var _mask = (1 << _ru.a) | (1 << _ru.b);
                array_push(L, " lda coll", " and #" + string(_mask), " cmp #" + string(_mask), " bne rn" + rt);
            }
            array_push(L, " lda latch+" + rs, " bne rd" + rt, " lda #1", " sta latch+" + rs, " jsr ract_" + rs, " jmp rd" + rt);
            array_push(L, "rn" + rt + ":", " lda #0", " sta latch+" + rs, "rd" + rt + ":");
        }
        if (_w == 1)
        {
            array_push(L, " lda joy", " and #16", " beq rn" + rt);
            array_push(L, " lda latch+" + rs, " bne rd" + rt, " lda #1", " sta latch+" + rs, " jsr ract_" + rs, " jmp rd" + rt);
            array_push(L, "rn" + rt + ":", " lda #0", " sta latch+" + rs, "rd" + rt + ":");
        }
        if (_w == 2)
        {
            array_push(L, " lda sectick", " beq rd" + rt, " inc latch+" + rs, " lda latch+" + rs, " cmp #" + string(clamp(_ru.n, 1, 255)), " bcc rd" + rt);
            array_push(L, " lda #0", " sta latch+" + rs, " jsr ract_" + rs, "rd" + rt + ":");
        }
        if (_w == 3)
        {
            var _b = cg_bcd(_ru.n);
            array_push(L, " lda latch+" + rs, " bne rd" + rt);
            array_push(L, " lda score_hi", " cmp #" + string(_b[0]), " bcc rd" + rt, " bne rh" + rt, " lda score_lo", " cmp #" + string(_b[1]), " bcc rd" + rt);
            array_push(L, "rh" + rt + ":", " lda #1", " sta latch+" + rs, " jsr ract_" + rs, "rd" + rt + ":");
        }
        if (_w == 4)
        {
            array_push(L, " lda lives", " bne rd" + rt, " lda latch+" + rs, " bne rd" + rt, " lda #1", " sta latch+" + rs, " jsr ract_" + rs, "rd" + rt + ":");
        }
        array_push(L, "rchk_" + rs + "_e:");
        _mk.to = array_length(L);
        array_push(_marks, _mk);
    }

    // ---------------- sound + border flash ----------------
    array_push(L, " jsr sfx_update");
    array_push(L, " lda flash", " beq fl0", " dec flash", " beq fl1", " and #2", " beq fl1", " lda #1", " sta $d020", " rts");
    array_push(L, "fl1:", " lda #" + string(_p.border), " sta $d020", "fl0:", " rts");

    // ---------------- sprite placement ----------------
    array_push(L, "place_sprites:", " lda #0", " sta tmp", " sta tmp2");
    for (var q = 0; q < na; q++)
    {
        var qs = string(q);
        array_push(L, " lda ax_lo+" + qs, " sta $d000+" + string(q * 2), " lda ay+" + qs, " sta $d001+" + string(q * 2));
        array_push(L, " lda ax_hi+" + qs, " beq ph_" + qs, " lda tmp", " ora #" + string(1 << q), " sta tmp", "ph_" + qs + ":");
        array_push(L, " lda avis+" + qs, " beq pv_" + qs, " lda tmp2", " ora #" + string(1 << q), " sta tmp2", "pv_" + qs + ":");
    }
    // animated sprites: pointer = base + ((acnt >> speed) & mask) - or the Animate page's
    // animations: anim_upd works out which way the actor moved and picks the frame
    for (var an = 0; an < na; an++)
    {
        var _asp = _p.sprites[clamp(_acts[an].sprite, 0, SPR_COUNT - 1)];
        if (an < array_length(_ab.members) && _ab.members[an].on)
        {
            var _as = string(an);
            array_push(L, " lda ax_lo+" + _as, " sec", " sbc as_px+" + _as, " sta an_dx", " lda ax_lo+" + _as, " sta as_px+" + _as);
            array_push(L, " lda ay+" + _as, " sec", " sbc as_py+" + _as, " sta an_dy", " lda ay+" + _as, " sta as_py+" + _as, " lda #0", " sta an_air");
            if (_acts[an].role == 0) { array_push(L, " lda joy", " and #16"); }
            array_push(L, " sta an_fire", " ldx #" + _as, " lda #" + _as, " jsr anim_upd", " tay", " lda an_mc,y", " beq amc_" + _as, " lda #" + string(1 << an), "amc_" + _as + ":", " sta an_fl", " lda $d01c", " and #" + string(255 - (1 << an)), " ora an_fl", " sta $d01c", " tya", " clc", " adc #spr_data/64", " sta $07f8+" + _as);
            continue;
        }
        if (_asp.frames > 1)
        {
            var _mask = 1;
            if (_asp.frames >= 4) { _mask = 3; }
            array_push(L, " lda acnt");
            for (var sh = 0; sh < clamp(_asp.anim_speed, 0, 5); sh++) { array_push(L, " lsr"); }
            array_push(L, " and #" + string(_mask), " clc", " adc #spr_data/64+" + string(clamp(_acts[an].sprite, 0, SPR_COUNT - 1)), " sta $07f8+" + string(an));
        }
    }
    array_push(L, " lda tmp", " sta $d010", " lda tmp2", " sta $d015", " rts");

    // ---------------- the screen and the HUD ----------------
    array_push(L, "draw_screen:", " ldx #0", "cpy1:");
    for (var k = 0; k < 4; k++)
    {
        var _o = string(k * 250);
        array_push(L, " lda scr_data+" + _o + ",x", " sta $0400+" + _o + ",x");
        array_push(L, " lda col_data+" + _o + ",x", " sta $d800+" + _o + ",x");
    }
    array_push(L, " inx", " cpx #250", " bne cpy1");
    // the UI page's custom HUD: draw_screen runs on into its panel, then its own draw_hud
    var _hud_on = hud_emit_single(L, _p);
    if (!_hud_on) { array_push(L, " rts"); }
    hud_emit_set_chars(L, _p);
    var _hw = hud_warnings(_p);
    for (var hw = 0; hw < array_length(_hw); hw++) { array_push(_warn, _hw[hw]); }
    if (!_hud_on) { array_push(L, "draw_hud:"); }
    var _hc = string(_p.hud_colour);
    var _row = clamp(_p.hud_row, 0, 24);
    if (!_hud_on && _p.show_score)
    {
        var _base = 1024 + _row * 40 + 1;
        var _lab = "SCORE ";
        for (var h = 1; h <= 6; h++)
        {
            array_push(L, " lda #" + string(scr_code_from_char(string_char_at(_lab, h))), " sta " + string(_base + h - 1));
            array_push(L, " lda #" + _hc, " sta " + string(_base + h - 1 + 54272));
        }
        var _d = _base + 6;
        var _src = ["score_hi", "score_hi", "score_lo", "score_lo"];
        for (var dd = 0; dd < 4; dd++)
        {
            array_push(L, " lda " + _src[dd]);
            if (dd == 0 || dd == 2) { array_push(L, " lsr", " lsr", " lsr", " lsr"); }
            else { array_push(L, " and #15"); }
            array_push(L, " ora #48", " sta " + string(_d + dd), " lda #" + _hc, " sta " + string(_d + dd + 54272));
        }
    }
    if (!_hud_on && _p.show_lives)
    {
        var _lb = 1024 + _row * 40 + 31;
        var _ll = "LIVES ";
        for (var g = 1; g <= 6; g++)
        {
            array_push(L, " lda #" + string(scr_code_from_char(string_char_at(_ll, g))), " sta " + string(_lb + g - 1));
            array_push(L, " lda #" + _hc, " sta " + string(_lb + g - 1 + 54272));
        }
        array_push(L, " lda lives", " ora #48", " sta " + string(_lb + 6), " lda #" + _hc, " sta " + string(_lb + 6 + 54272));
    }
    if (!_hud_on) { array_push(L, " rts"); }

    array_push(L, "add_score:", " sed", " clc", " adc score_lo", " sta score_lo", " txa", " adc score_hi", " sta score_hi", " cld", " bcc as1");
    array_push(L, " lda #$99", " sta score_lo", " sta score_hi", "as1:", " jmp draw_hud");

    array_push(L, "end_screen:", " stx ptr", " sty ptr+1", " jsr sfx_stop", " jsr mus_stop", " lda #0", " sta $d015", " ldy #0");
    array_push(L, "es1:", " lda (ptr),y", " cmp #$ff", " beq es2", " sta $0400+480,y", " lda #1", " sta $d800+480,y", " iny", " bne es1", "es2:");
    array_push(L, "es3:", " lda $dc00", " and #16", " beq es3");
    array_push(L, "es4:", " lda $dc00", " and #16", " bne es4");
    array_push(L, "es5:", " lda $dc00", " and #16", " beq es5");
    array_push(L, " ldx #$ff", " txs", " jmp restart");
    // a game over / winning bitmap instead of the message (A = its slot)
    if (array_length(_pics) > 0) { array_push(L, "pic_end_scr:", " pha", " jsr sfx_stop", " jsr mus_stop", " pla", " ldx #0", " jsr pic_show", " ldx #$ff", " txs", " jmp restart"); }

    // ---------------- rule actions: one subroutine per card, its DO lines run in order ----------------
    for (var ra = 0; ra < nr; ra++)
    {
        if (!_on[ra]) { continue; }
        var _rr = _rules[ra];
        var as_ = string(ra);
        var _ma = { rule : ra, from : array_length(L), to : 0 };
        var _dos = [_rr];
        for (var md = 0; md < array_length(_rr.more); md++) { array_push(_dos, _rr.more[md]); }
        array_push(L, "; Rule " + string(ra + 1) + " does: " + logic_do_list(_rr));
        array_push(L, "ract_" + as_ + ":");
        if (array_length(_dos) == 1)
        {
            cg_do_lines(L, _p, _rr, "_" + as_, na);
        }
        else
        {
            for (var dj = 0; dj < array_length(_dos) - 1; dj++) { array_push(L, " jsr ract_" + as_ + "_" + string(dj)); }
            array_push(L, " jmp ract_" + as_ + "_" + string(array_length(_dos) - 1));
            for (var dk = 0; dk < array_length(_dos); dk++)
            {
                var _dt = "_" + as_ + "_" + string(dk);
                array_push(L, "ract" + _dt + ":");
                cg_do_lines(L, _p, _dos[dk], _dt, na);
            }
        }
        array_push(L, "ract_" + as_ + "_e:");
        _ma.to = array_length(L);
        array_push(_marks, _ma);
    }

    array_push(L, "txt_over:", " .byte " + cg_text_bytes(_p.over_text));
    array_push(L, "txt_win:", " .byte " + cg_text_bytes(_p.win_text));

    sid_emit(L, _p);

    array_push(L, "vars:");
    for (var v = 0; v < array_length(_names); v++)
    {
        array_push(L, _names[v] + ":", " .fill " + string(_sizes[v]) + ",0");
    }
    array_push(L, "vars_end:");

    array_push(L, " .padto $2000", " .align 64", "spr_data:");
    for (var sp = 0; sp < SPR_COUNT; sp++)
    {
        var _bytes = sprite_encode(_p.sprites[sp]);
        array_push(L, " .byte " + cg_join_bytes(_bytes, 0, 63) + ",0");
    }
    // sprites turned round for the Animate page (slots 32 on)
    anim_emit_mirrors(L, _p, _ab);
    array_push(L, "spr_end:");
    // the custom HUD's own character set (when its frame or font needs one): the VIC-II must see it
    hud_emit_chars_single(L, _p);
    array_push(L, "scr_data:");
    for (var sr = 0; sr < 25; sr++) { array_push(L, " .byte " + cg_join_bytes(_p.chars, sr * 40, 40)); }
    array_push(L, "col_data:");
    for (var cr = 0; cr < 25; cr++) { array_push(L, " .byte " + cg_join_bytes(_p.cols, cr * 40, 40)); }
    // the music driver and songs go last: they can be big and the VIC-II doesn't need to see them
    music_emit(L, _p);
    digi_emit(L, _p);
    patch_emit(L, _p);
    if (_ab.on) { anim_emit(L, _ab); }
    // bitmaps last of all: they are big, and are copied to bank 3 to be shown
    if (array_length(_pics) > 0) { bmp_emit_game(L, _p, _pics, 0); }

    return { src : string_join_ext("\n", L), warnings : _warn, lines : L, marks : _marks };
}

/// Full build: codegen + assemble + save PRG. Returns result struct.
function build_prg(_path)
{
    var _gen = codegen_project(proj);
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
    var _spr_end = _res.labels[$ "spr_end"];
    if (_spr_end > 16384)
    {
        build_ok = false;
        build_msg = "Build failed - the code is too long: the sprites would end at $" + string_upper(dec_to_hex(_spr_end)) + ", past $4000 where the VIC-II can see them. Use fewer rules, switch a group off, or turn fewer sprites round on the Animate page.";
        return false;
    }
    var _hce = _res.labels[$ "hud_chars_end"];
    if (!is_undefined(_hce) && _hce > 16384)
    {
        build_ok = false;
        build_msg = "Build failed - the custom HUD's characters would end at $" + string_upper(dec_to_hex(_hce)) + ", past $4000 where the VIC-II can see them. On the UI page use the C64 font and no frame, or make the code shorter.";
        return false;
    }
    if (_end > C64_BASIC_END)
    {
        build_ok = false;
        build_msg = "Build failed - the game is too big: it ends at $" + string_upper(dec_to_hex(_end)) + ", past $A000 where the BASIC ROM starts. " + bmp_too_big_hint(proj) + "Make the songs shorter or use fewer loops.";
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
    build_spr = _res.labels[$ "spr_data"];
    build_msg = "Built " + filename_name(_path) + " - " + string(build_size) + " bytes ($0801-$" + string_upper(dec_to_hex(_end - 1)) + ")";
    return true;
}

function dec_to_hex(_n)
{
    var _h = "0123456789abcdef";
    var _s = "";
    var _v = max(0, floor(_n));
    if (_v == 0) { return "0"; }
    while (_v > 0)
    {
        _s = string_char_at(_h, (_v mod 16) + 1) + _s;
        _v = _v div 16;
    }
    return _s;
}

function launch_vice(_prg)
{
    if (vice_path == "" || !file_exists(vice_path))
    {
        toast("Set the VICE x64sc path first", 1);
        return false;
    }
    if (os_type != os_windows)
    {
        toast("Open " + filename_name(_prg) + " in VICE to play", 1);
        return false;
    }
    execute_shell_simple(vice_path, "-autostart \"" + _prg + "\"");
    toast("Launching VICE...", 0);
    return true;
}
