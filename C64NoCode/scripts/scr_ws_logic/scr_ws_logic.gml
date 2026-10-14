/// C64 NO-CODE STUDIO - Logic workspace (WHEN / DO rule cards in groups, and the code previewer)

#macro LOGIC_DO_ROW_H 40         // each AND DO line makes a rule card this much taller
#macro LOGIC_WHEN_W 210          // the WHEN drop-down: room for 'Actor hits the scenery'
#macro LOGIC_DO_W 250            // the DO drop-downs: room for 'Move actor to another actor'
#macro LOGIC_ACTOR_W 150         // actor drop-downs on a card

function logic_find_role(_roles, _fallback)
{
    for (var i = 0; i < array_length(proj.actors); i++)
    {
        for (var r = 0; r < array_length(_roles); r++)
        {
            if (proj.actors[i].role == _roles[r]) { return i; }
        }
    }
    return _fallback;
}

function logic_add_template(_t)
{
    if (array_length(proj.rules) > RULES_MAX - 4)
    {
        toast("That is a lot of rules! The limit is " + string(RULES_MAX) + ".", 1);
        return;
    }
    undo_mark("tpl" + string(current_time));
    var _first = array_length(proj.rules);
    var _pl = logic_find_role([0], 0);
    var _en = logic_find_role([4, 1, 2, 3], min(1, max(0, array_length(proj.actors) - 1)));
    var _pk = logic_find_role([5], min(2, max(0, array_length(proj.actors) - 1)));
    var _r;
    switch (_t)
    {
        case 0:
            // one card: lose a life AND go home AND flash the border
            _r = rule_new(); _r.when = 0; _r.a = _pl; _r.b = _en; _r.act = 1;
            array_push(_r.more, { act : 4, target : _pl, value : 0 }, { act : 3, target : 0, value : 0 });
            array_push(proj.rules, _r);
            break;
        case 1:
            _r = rule_new(); _r.when = 0; _r.a = _pl; _r.b = _pk; _r.act = 0; _r.value = 10;
            array_push(_r.more, { act : 5, target : _pk, value : 0 }, { act : 2, target : 0, value : 0 });
            array_push(proj.rules, _r);
            break;
        case 2:
            _r = rule_new(); _r.when = 3; _r.n = 100; _r.act = 11; array_push(proj.rules, _r);
            break;
        case 3:
            _r = rule_new(); _r.when = 4; _r.act = 10; array_push(proj.rules, _r);
            break;
        case 4:
            _r = rule_new(); _r.when = 2; _r.n = 10; _r.act = 12; _r.target = _en; array_push(proj.rules, _r);
            break;
        case 5:
            _r = rule_new(); _r.when = 1; _r.act = 2; _r.value = min(1, array_length(proj.sfx) - 1); array_push(proj.rules, _r);
            break;
    }
    // the new rules get a group named after the recipe
    array_push(proj.groups, group_new(global.TEMPLATE_NAMES[_t]));
    var _g = array_length(proj.groups) - 1;
    proj.groups[_g].collapsed = false;
    for (var i = _first; i < array_length(proj.rules); i++) { proj.rules[i].group = _g; }
    logic_sort_rules();
    toast("Rules added in a new group - check the actors are the ones you meant", 0);
}

/// "1: Coin" for each sound (Play a sound drop-downs)
function sfx_names()
{
    var _n = [];
    for (var i = 0; i < array_length(proj.sfx); i++) { array_push(_n, string(i + 1) + ": " + proj.sfx[i].name); }
    return _n;
}

function logic_sentence(_r)
{
    return logic_when_phrase(_r) + ", " + logic_do_list(_r) + ".";
}

/// The WHEN part of a rule as words ("When Hero touches Gem")
function logic_when_phrase(_r)
{
    var _names = actor_names();
    var _na = array_length(proj.actors);
    var _s = "When ";
    if (_r.when == 2) { _s = ""; }
    var _an = "?";
    var _bn = "?";
    if (_r.a < _na) { _an = _names[_r.a]; }
    if (_r.b < _na) { _bn = _names[_r.b]; }
    switch (_r.when)
    {
        case 0:
            if (_r.a == _r.b) { _s += _an + " touches anything"; }
            else { _s += _an + " touches " + _bn; }
            break;
        case 1: _s += "the fire button is pressed"; break;
        case 2: _s += "Every " + string(_r.n) + " seconds"; break;
        case 3: _s += "the score reaches " + string(_r.n); break;
        case 4: _s += "the player runs out of lives"; break;
        case 5: _s += "the game starts"; break;
        case 6: _s += _an + " hits the scenery"; break;
    }
    return _s;
}

/// Every DO line of a rule, joined with "then"
function logic_do_list(_r)
{
    var _names = actor_names();
    var _na = array_length(proj.actors);
    var _s = logic_do_phrase(_r, _names, _na);
    for (var m = 0; m < array_length(_r.more); m++)
    {
        _s += ", then " + logic_do_phrase(_r.more[m], _names, _na);
    }
    return _s;
}

/// What one DO / AND DO line does, as words (_d: act, target, value)
function logic_do_phrase(_d, _names, _na)
{
    var _tn = "?";
    if (_d.target < _na) { _tn = _names[_d.target]; }
    switch (_d.act)
    {
        case 0: return "add " + string(_d.value) + " to the score";
        case 1: return "lose a life";
        case 2: return "play sound '" + proj.sfx[clamp(_d.value, 0, array_length(proj.sfx) - 1)].name + "'";
        case 3: return "flash the border";
        case 4: return "send " + _tn + " back to its start";
        case 5: return "move " + _tn + " to a random spot";
        case 6: return "hide " + _tn;
        case 7: return "show " + _tn;
        case 8: return "make " + _tn + " " + string_lower(global.C64PAL_NAMES[clamp(_d.value, 0, 15)]);
        case 9: return "make the background " + string_lower(global.C64PAL_NAMES[clamp(_d.value, 0, 15)]);
        case 10: return "it's game over";
        case 11: return "the player wins";
        case 12: return "speed up " + _tn;
        case 13: return "slow down " + _tn;
        case 14: return "add a life";
        case 15:
            var _vn = "?";
            if (_d.value < _na) { _vn = _names[_d.value]; }
            return "move " + _tn + " to " + _vn;
        case 16: return "stop all sounds";
        case 17:
            if (array_length(proj.songs) == 0) { return "play music (no songs yet)"; }
            return "play the song '" + proj.songs[clamp(_d.value, 0, array_length(proj.songs) - 1)].name + "'";
        case 18: return "stop the music";
    }
    return "?";
}

// ---------------------------------------------------------------------------
// Groups: named, collapsible sets of rules, which can sit inside other groups
// (parent = the group they are in, -1 = top level). proj.rules stays in run
// order and is kept sorted by group (rules outside any group first, then each
// group's rules in tree order), so what you see top to bottom is exactly the
// order the C64 checks them. A group switched off is left out of the game.
// ---------------------------------------------------------------------------

function group_new(_name)
{
    return { name : _name, collapsed : true, enabled : true, parent : -1 };
}

function group_colour(_g)
{
    return make_colour_hsv((_g * 47 + 140) mod 255, 150, 230);
}

/// The parent of group _g in _groups (-1 = top level, or when it is not a valid group)
function group_parent_of(_groups, _g)
{
    if (_g < 0 || _g >= array_length(_groups)) { return -1; }
    var _p = _groups[_g].parent;
    if (!is_numeric(_p) || _p < 0 || _p >= array_length(_groups)) { return -1; }
    return _p;
}

/// True when group _g (or a group it is inside) is switched off - its rules are not built
function group_off_in(_groups, _g)
{
    var _n = 0;
    while (_g >= 0 && _g < array_length(_groups) && _n <= array_length(_groups))
    {
        if (!_groups[_g].enabled) { return true; }
        _g = group_parent_of(_groups, _g);
        _n += 1;
    }
    return false;
}

/// How deep group _g sits (0 = top level)
function group_depth(_g)
{
    var _d = 0;
    var _p = group_parent_of(proj.groups, _g);
    while (_p >= 0 && _d <= array_length(proj.groups))
    {
        _d += 1;
        _p = group_parent_of(proj.groups, _p);
    }
    return _d;
}

/// True when _g is _anc or inside it (at any depth)
function group_inside(_g, _anc)
{
    var _n = 0;
    while (_g >= 0 && _n <= array_length(proj.groups))
    {
        if (_g == _anc) { return true; }
        _g = group_parent_of(proj.groups, _g);
        _n += 1;
    }
    return false;
}

/// True when a group _g is inside is folded (so _g is not shown)
function group_hidden(_g)
{
    var _p = group_parent_of(proj.groups, _g);
    var _n = 0;
    while (_p >= 0 && _n <= array_length(proj.groups))
    {
        if (proj.groups[_p].collapsed) { return true; }
        _p = group_parent_of(proj.groups, _p);
        _n += 1;
    }
    return false;
}

/// The groups in tree order: each group, then the groups inside it
function group_order()
{
    var _out = [];
    var _stack = [];
    for (var g = array_length(proj.groups) - 1; g >= 0; g--)
    {
        if (group_parent_of(proj.groups, g) < 0) { array_push(_stack, g); }
    }
    while (array_length(_stack) > 0 && array_length(_out) <= array_length(proj.groups))
    {
        var _g = array_pop(_stack);
        array_push(_out, _g);
        for (var c = array_length(proj.groups) - 1; c >= 0; c--)
        {
            if (group_parent_of(proj.groups, c) == _g) { array_push(_stack, c); }
        }
    }
    return _out;
}

/// Stable sort of the rules by group (-1 = no group comes first), groups in tree order
function logic_sort_rules()
{
    var _sel = undefined;
    if (logic_sel >= 0 && logic_sel < array_length(proj.rules)) { _sel = proj.rules[logic_sel]; }
    var _out = [];
    var _order = group_order();
    for (var i0 = 0; i0 < array_length(proj.rules); i0++)
    {
        if (proj.rules[i0].group < 0) { array_push(_out, proj.rules[i0]); }
    }
    for (var k = 0; k < array_length(_order); k++)
    {
        var g = _order[k];
        for (var i = 0; i < array_length(proj.rules); i++)
        {
            if (proj.rules[i].group == g) { array_push(_out, proj.rules[i]); }
        }
    }
    proj.rules = _out;
    // the selected rule stays selected wherever it moved to
    if (!is_undefined(_sel))
    {
        for (var j = 0; j < array_length(proj.rules); j++)
        {
            if (proj.rules[j] == _sel) { logic_sel = j; }
        }
    }
}

/// "Outer > Inner" name of group _g
function group_path(_g)
{
    var _s = proj.groups[_g].name;
    var _p = group_parent_of(proj.groups, _g);
    var _n = 0;
    while (_p >= 0 && _n < 8)
    {
        _s = proj.groups[_p].name + " > " + _s;
        _p = group_parent_of(proj.groups, _p);
        _n += 1;
    }
    return _s;
}

function group_names()
{
    var _n = ["(no group)"];
    for (var g = 0; g < array_length(proj.groups); g++) { array_push(_n, group_path(g)); }
    return _n;
}

/// Removes group _g: its rules and the groups inside it move up into its parent
function group_delete(_g)
{
    var _up = group_parent_of(proj.groups, _g);
    for (var i = 0; i < array_length(proj.rules); i++)
    {
        var _r = proj.rules[i];
        if (_r.group == _g) { _r.group = _up; }
    }
    for (var c = 0; c < array_length(proj.groups); c++)
    {
        if (proj.groups[c].parent == _g) { proj.groups[c].parent = _up; }
    }
    for (var i2 = 0; i2 < array_length(proj.rules); i2++)
    {
        if (proj.rules[i2].group > _g) { proj.rules[i2].group -= 1; }
    }
    for (var c2 = 0; c2 < array_length(proj.groups); c2++)
    {
        if (proj.groups[c2].parent > _g) { proj.groups[c2].parent -= 1; }
    }
    array_delete(proj.groups, _g, 1);
    logic_sort_rules();
}

/// Swaps groups _a and _b (two groups with the same parent: their order flips)
function group_swap(_a, _b)
{
    var _tmp = proj.groups[_a];
    proj.groups[_a] = proj.groups[_b];
    proj.groups[_b] = _tmp;
    for (var i = 0; i < array_length(proj.rules); i++)
    {
        var _r = proj.rules[i];
        if (_r.group == _a) { _r.group = _b; }
        else
        {
            if (_r.group == _b) { _r.group = _a; }
        }
    }
    for (var c = 0; c < array_length(proj.groups); c++)
    {
        var _gp = proj.groups[c];
        if (_gp.parent == _a) { _gp.parent = _b; }
        else
        {
            if (_gp.parent == _b) { _gp.parent = _a; }
        }
    }
    logic_sort_rules();
}

/// The group before (_dir -1) or after (_dir 1) _g with the same parent, or -1
function group_sibling(_g, _dir)
{
    var _p = group_parent_of(proj.groups, _g);
    var _j = _g + _dir;
    while (_j >= 0 && _j < array_length(proj.groups))
    {
        if (group_parent_of(proj.groups, _j) == _p) { return _j; }
        _j += _dir;
    }
    return -1;
}

/// Is rule _r switched off by its group (or a group that group is inside)?
function rule_disabled(_r)
{
    return group_off_in(proj.groups, _r.group);
}

/// A dim word between a card's controls, at _x; returns the x just after it (and a gap)
function logic_word(_x, _y, _text)
{
    draw_set_font(global.f_body);
    ui_text(_x, _y + 15, _text, global.TH.text_dim, fa_left, fa_middle, global.f_body, 1);
    return _x + ceil(ui_sw(_text)) + 8;
}

/// Height of rule _r's card: 128, plus a row for each AND DO line
function logic_card_h(_r)
{
    return 128 + array_length(_r.more) * LOGIC_DO_ROW_H;
}

/// One DO line of a rule card (_d = the rule, or one of its AND DO lines); _pill = "DO" or "AND".
/// _xr = the x the row must stop at (clear of the buttons on the right of the card).
function logic_do_row(_d, _rid, _x, _y, _pill, _anames, _snames, _xr)
{
    var _dx = _x;
    var _dy = _y;
    ui_rrect(_dx, _dy + 4, _dx + 56, _dy + 26, 11, global.TH.accent, global.TH.accent_dark, 1);
    ui_text(_dx + 28, _dy + 15, _pill, c_white, fa_center, fa_middle, global.f_small, 1);
    _dx += 66;
    set_val(_d, "act", ui_dropdown(_rid + "_act", _dx, _dy, LOGIC_DO_W, 30, global.DO_NAMES, _d.act, "DO|What happens when the WHEN part is true. AND DO lines happen too, in order, every time it fires."), _rid + "act");
    _dx += LOGIC_DO_W + 10;
    var _act = _d.act;
    if (cg_act_needs_actor(_act))
    {
        set_val(_d, "target", ui_dropdown(_rid + "_t", _dx, _dy, LOGIC_ACTOR_W, 30, _anames, _d.target, "Which actor|The actor this action changes."), _rid + "t");
        _dx += LOGIC_ACTOR_W + 10;
    }
    if (_act == 0)
    {
        set_val(_d, "value", ui_stepper(_rid + "_v", _dx, _dy, 150, _d.value, 1, 9999, "Points|How many points to add. Hold Shift for steps of 10."), _rid + "v");
        logic_word(_dx + 158, _dy, "points");
    }
    if (_act == 2)
    {
        var _sw = max(100, min(180, _xr - _dx - 68));
        set_val(_d, "value", ui_dropdown(_rid + "_snd", _dx, _dy, _sw, 30, _snames, clamp(_d.value, 0, array_length(proj.sfx) - 1), "Sound|Which of your sounds to play. Design them on the Sound page."), _rid + "snd");
        if (ui_button(_rid + "_play", _dx + _sw + 8, _dy, 60, 30, "Play", "Preview|Plays this sound so you can hear it.", BTN_GHOST))
        {
            sfx_preview_play(proj.sfx[clamp(_d.value, 0, array_length(proj.sfx) - 1)]);
        }
    }
    if (_act == 17)
    {
        if (array_length(proj.songs) == 0)
        {
            if (ui_button(_rid + "_mk", _dx, _dy, 150, 30, "Make a song...", "No songs yet|Opens the Music page so you can make one.", BTN_GHOST)) { ws_set(WS_MUSIC); }
        }
        else
        {
            var _mw = max(100, min(180, _xr - _dx - 68));
            set_val(_d, "value", ui_dropdown(_rid + "_song", _dx, _dy, _mw, 30, music_song_names(), clamp(_d.value, 0, array_length(proj.songs) - 1), "Song|Which song to play, from the Music page. It replaces the song that is playing."), _rid + "song");
            var _sv = clamp(_d.value, 0, array_length(proj.songs) - 1);
            var _pl = (mus_playing && mus_play_what == "logic" + string(_sv));
            var _pt = "Play";
            if (_pl) { _pt = "Stop"; }
            if (ui_button(_rid + "_mplay", _dx + _mw + 8, _dy, 60, 30, _pt, "Preview|Plays this song so you can hear it.", BTN_GHOST))
            {
                if (_pl) { music_preview_stop(); }
                else { music_preview_start(music_compile(proj.songs, proj.level_song), _sv, 0, false, "logic" + string(_sv)); }
            }
        }
    }
    if (_act == 8 || _act == 9)
    {
        set_val(_d, "value", ui_colour_drop(_rid + "_col", _dx, _dy, 150, 30, clamp(_d.value, 0, 15), "Colour|The colour to change to."), _rid + "col");
    }
    if (_act == 15)
    {
        var _tox = logic_word(_dx, _dy, "to");
        var _tow = max(100, min(LOGIC_ACTOR_W, _xr - _tox));
        set_val(_d, "value", ui_dropdown(_rid + "_to", _tox, _dy, _tow, 30, _anames, clamp(_d.value, 0, max(0, array_length(proj.actors) - 1)), "To which actor|The first actor jumps to where this one is - drop a gem where an enemy was, or respawn at a portal."), _rid + "to");
    }
}

/// One WHEN / DO card. Returns 0, or 1 = delete, 2 = up, 3 = down.
function logic_rule_card(_r, i, _cx, _cy, _cw, _anames, _snames, _gnames)
{
    var _res = 0;
    var _cardh = logic_card_h(_r);
    var _rid = "rule_" + string(i);
    var _alpha = 0.9;
    if (rule_disabled(_r)) { _alpha = 0.45; }
    ui_rrect(_cx, _cy, _cx + _cw, _cy + _cardh, 12, global.TH.btn_top, global.TH.panel_bot, _alpha);
    if (logic_sel == i) { ui_rrect_line(_cx, _cy, _cx + _cw, _cy + _cardh, 12, global.TH.accent, 1, 2); }
    else { ui_rrect_line(_cx, _cy, _cx + _cw, _cy + _cardh, 12, global.TH.panel_edge, 0.6, 1); }
    if (_r.group >= 0) { ui_rrect(_cx, _cy + 8, _cx + 5, _cy + _cardh - 8, 2, group_colour(_r.group), group_colour(_r.group), 1); }
    draw_circle_colour(_cx + 22, _cy + 22, 12, global.TH.accent, global.TH.accent_dark, false);
    ui_text(_cx + 22, _cy + 22, string(i + 1), c_white, fa_center, fa_middle, global.f_small, 1);

    // WHEN row
    var _wx = _cx + 46;
    var _wy = _cy + 10;
    ui_rrect(_wx, _wy + 4, _wx + 56, _wy + 26, 11, global.TH.accent2, make_colour_rgb(46, 140, 116), 1);
    ui_text(_wx + 28, _wy + 15, "WHEN", make_colour_rgb(16, 30, 28), fa_center, fa_middle, global.f_small, 1);
    _wx += 66;
    set_val(_r, "when", ui_dropdown(_rid + "_when", _wx, _wy, LOGIC_WHEN_W, 30, global.WHEN_NAMES, _r.when, "WHEN|The thing that has to happen for this rule to fire."), _rid + "w");
    _wx += LOGIC_WHEN_W + 10;
    // two actors and 'touches' must fit before the buttons on the right of the card
    draw_set_font(global.f_body);
    var _aw = clamp(floor((_cx + _cw - 50 - _wx - ceil(ui_sw("touches")) - 16) / 2), 90, LOGIC_ACTOR_W);
    switch (_r.when)
    {
        case 0:
            set_val(_r, "a", ui_dropdown(_rid + "_a", _wx, _wy, _aw, 30, _anames, _r.a, "First actor|The actor that does the touching. The C64 checks this with its sprite collision register ($D01E)."), _rid + "a");
            _wx = logic_word(_wx + _aw + 8, _wy, "touches");
            set_val(_r, "b", ui_dropdown(_rid + "_b", _wx, _wy, _aw, 30, _anames, _r.b, "Second actor|The actor being touched. Pick the same actor twice for 'touches anything'."), _rid + "b");
            break;
        case 2:
            _wx = logic_word(_wx, _wy, "every");
            set_val(_r, "n", ui_stepper(_rid + "_n", _wx, _wy, 120, _r.n, 1, 60, "Seconds|How many seconds between each time this rule fires (counted in frames: 50 a second on PAL, 60 on NTSC)."), _rid + "n");
            logic_word(_wx + 128, _wy, "seconds");
            break;
        case 3:
            set_val(_r, "n", ui_stepper(_rid + "_n", _wx, _wy, 150, _r.n, 1, 9999, "Score target|The rule fires once when the score reaches this number. Hold Shift for steps of 10."), _rid + "n");
            logic_word(_wx + 158, _wy, "points");
            break;
        case 6:
            set_val(_r, "a", ui_dropdown(_rid + "_a", _wx, _wy, _aw, 30, _anames, _r.a, "Which actor|Fires when this actor's sprite touches any drawn pixel of a character on the screen - walls, platforms, letters. Spaces do not count. The C64 checks this with its sprite-background collision register ($D01F)."), _rid + "a");
            logic_word(_wx + _aw + 8, _wy, "hits the scenery");
            break;
    }

    // DO row, then the AND DO lines (each fires with the rule)
    logic_do_row(_r, _rid, _cx + 46, _cy + 50, "DO", _anames, _snames, _cx + _cw - 50);
    var _mdel = -1;
    for (var m = 0; m < array_length(_r.more); m++)
    {
        var _my = _cy + 50 + (m + 1) * LOGIC_DO_ROW_H;
        logic_do_row(_r.more[m], _rid + "_m" + string(m), _cx + 46, _my, "AND", _anames, _snames, _cx + _cw - 90);
        if (ui_button(_rid + "_mdel" + string(m), _cx + _cw - 80, _my, 30, 30, "x", "Remove this line|Takes this AND DO line off the rule. You can Undo this.", BTN_GHOST)) { _mdel = m; }
    }
    if (_mdel >= 0)
    {
        undo_mark("ruledodel" + string(current_time));
        array_delete(_r.more, _mdel, 1);
    }

    // sentence, group and tools
    var _gw = 170;
    var _gx = _cx + _cw - 48 - _gw;
    var _by = _cy + _cardh - 38;
    var _sx2 = _gx - 10;
    if (array_length(_r.more) < RULE_DOS_MAX - 1)
    {
        _sx2 = _gx - 112;
        if (ui_button(_rid + "_anddo", _gx - 102, _by, 92, 28, "+ AND DO", "Add an AND DO line|Something else that happens every time this rule fires - e.g. add to the score AND play a sound AND move the gem. Up to " + string(RULE_DOS_MAX) + " DO lines on one rule; they run in order.", BTN_GHOST))
        {
            undo_mark("ruledoadd" + string(current_time));
            array_push(_r.more, do_new());
        }
    }
    ui_text(_cx + 46, _by + 14, ui_text_fit(logic_sentence(_r), global.f_small, _sx2 - _cx - 46), global.TH.text_faint, fa_left, fa_middle, global.f_small, 1);
    var _ng = ui_dropdown(_rid + "_grp", _gx, _by, _gw, 28, _gnames, _r.group + 1, "Group|Move this rule into a group. Groups keep related rules together and can be folded or switched off.") - 1;
    if (_ng != _r.group)
    {
        undo_mark("rulegrp" + string(current_time));
        _r.group = _ng;
        logic_resort = true;
        var _og = _ng;                  // open the group it went into (and the groups that is inside)
        var _on = 0;
        while (_og >= 0 && _on < 64)
        {
            proj.groups[_og].collapsed = false;
            _og = group_parent_of(proj.groups, _og);
            _on += 1;
        }
    }
    var _tx = _cx + _cw - 40;
    if (ui_button(_rid + "_del", _tx, _cy + 10, 30, 30, "X", "Delete rule|Removes this rule. You can Undo this.", BTN_DANGER)) { _res = 1; }
    if (ui_button(_rid + "_up", _tx, _cy + 48, 30, 30, "^", "Move up|Rules higher up are checked first (moves within its group).", BTN_GHOST)) { _res = 2; }
    if (ui_button(_rid + "_dn", _tx, _cy + 86, 30, 30, "v", "Move down|Rules lower down are checked later (moves within its group).", BTN_GHOST)) { _res = 3; }
    // clicking anywhere on the card selects it (the code previewer shows its 6502)
    if (ui_pressed_raw && ui_hit(_cx, _cy, _cx + _cw, _cy + _cardh) && logic_sel != i)
    {
        logic_sel = i;
        codeview_follow = true;
    }
    return _res;
}

function ws_logic_draw(_x1, _y1, _x2, _y2)
{
    var _rw = clamp(floor((_x2 - _x1) * 0.34), 320, 560);
    var _lx2 = _x2 - _rw - 12;
    ui_panel(_x1, _y1, _lx2, _y2, "Rules");
    var _nr = array_length(proj.rules);
    var _ngr = array_length(proj.groups);
    logic_sel = clamp(logic_sel, -1, _nr - 1);
    var _subr = _lx2 - 306;                 // stop before '+ Add group' (or 'Collapse all' when there are groups)
    if (_ngr > 0) { _subr = _lx2 - 422; }
    ui_text(_x1 + 80, _y1 + 15, ui_text_fit(string(_nr) + " rule(s) in " + string(_ngr) + " group(s). Checked every frame, top to bottom.", global.f_small, _subr - _x1 - 80), global.TH.text_faint, fa_left, fa_top, global.f_small, 1);
    if (ui_button("logic_add", _lx2 - 150, _y1 + 8, 136, 30, "+ Add rule", "Add rule|Adds a new WHEN / DO rule (outside any group). Use the + Rule button on a group to add straight into it.", BTN_ACCENT))
    {
        if (_nr < RULES_MAX)
        {
            undo_mark("ruleadd" + string(current_time));
            var _nrule = rule_new();
            _nrule.a = logic_find_role([0], 0);
            _nrule.b = min(1, max(0, array_length(proj.actors) - 1));
            array_push(proj.rules, _nrule);
            logic_sort_rules();
            logic_reveal = _nrule;
        }
        else { toast(string(RULES_MAX) + " rules is the limit", 1); }
    }
    if (ui_button("logic_addgroup", _lx2 - 296, _y1 + 8, 136, 30, "+ Add group", "Add group|Makes a new named group. Put rules in it with the Group drop-down on each rule, put groups inside groups (+ Group, or 'In:' on a group), fold it to tidy up, or switch it off to test without those rules.", BTN_NORMAL))
    {
        undo_mark("grpadd" + string(current_time));
        var _ngp = group_new("Group " + string(_ngr + 1));
        _ngp.collapsed = false;
        array_push(proj.groups, _ngp);
    }
    if (_ngr > 0)
    {
        var _allc = true;
        for (var gc = 0; gc < _ngr; gc++)
        {
            if (!proj.groups[gc].collapsed) { _allc = false; }
        }
        var _clab = "Collapse all";
        if (_allc) { _clab = "Expand all"; }
        if (ui_button("logic_collapse_all", _lx2 - 412, _y1 + 8, 110, 30, _clab, "Collapse / expand all|Folds every group down to its title bar, or opens them all again.", BTN_GHOST))
        {
            for (var gx = 0; gx < _ngr; gx++) { proj.groups[gx].collapsed = !_allc; }
            proj_dirty = true;
        }
    }

    var _lx = _x1 + 14;
    var _ly1 = _y1 + 52;
    var _ly2 = _y2 - 12;
    var _hdrh = 44;
    var _anames = actor_names();
    var _snames = sfx_names();
    var _gnames = group_names();
    var _cw = _lx2 - 14 - _lx - 10;

    // layout: [kind, index] with kind 0 = rule, 1 = group header; groups in tree order
    var _items = [];
    for (var i0 = 0; i0 < _nr; i0++)
    {
        if (proj.rules[i0].group < 0) { array_push(_items, [0, i0]); }
    }
    var _gorder = group_order();
    for (var go = 0; go < array_length(_gorder); go++)
    {
        var g = _gorder[go];
        if (group_hidden(g)) { continue; }
        array_push(_items, [1, g]);
        if (!proj.groups[g].collapsed)
        {
            for (var i1 = 0; i1 < _nr; i1++)
            {
                if (proj.rules[i1].group == g) { array_push(_items, [0, i1]); }
            }
        }
    }
    var _content = 10;
    for (var k = 0; k < array_length(_items); k++)
    {
        if (_items[k][0] == 0) { _content += logic_card_h(proj.rules[_items[k][1]]) + 10; }
        else { _content += _hdrh + 10; }
    }
    // a rule was just added: scroll so its whole card is in view, and select it
    if (is_struct(logic_reveal))
    {
        var _ry2 = 10;
        for (var k3 = 0; k3 < array_length(_items); k3++)
        {
            if (_items[k3][0] == 0 && proj.rules[_items[k3][1]] == logic_reveal)
            {
                var _view = _ly2 - _ly1;
                var _cur = ds_map_find_value(ui_scroll, "logic_list");
                if (is_undefined(_cur)) { _cur = 0; }
                if (_ry2 - 10 < _cur) { _cur = _ry2 - 10; }
                if (_ry2 + logic_card_h(logic_reveal) + 10 > _cur + _view) { _cur = _ry2 + logic_card_h(logic_reveal) + 10 - _view; }
                ds_map_replace(ui_scroll, "logic_list", max(0, _cur));
                logic_sel = _items[k3][1];
                codeview_follow = true;
                break;
            }
            if (_items[k3][0] == 0) { _ry2 += logic_card_h(proj.rules[_items[k3][1]]) + 10; }
            else { _ry2 += _hdrh + 10; }
        }
        logic_reveal = -1;
    }
    var _off = ui_scroll_begin("logic_list", _lx, _ly1, _lx2 - 10, _ly2, _content);
    if (_nr == 0 && _ngr == 0)
    {
        ui_text_wrap(_lx + 20, _ly1 + 20, "No rules yet. Rules make your game a game! Press '+ Add rule' or pick a quick recipe on the right, e.g. 'Player touches enemy: lose a life'. Use groups to keep related rules together.", global.TH.text_dim, _cw - 40, global.f_body, 1);
    }
    var _del = -1;
    var _move = 0;
    var _movei = -1;
    var _gact = -1;
    var _gop = "";
    var _gpar = -1;
    var _y = _ly1 + 10 - _off;
    for (var k2 = 0; k2 < array_length(_items); k2++)
    {
        var _it = _items[k2];
        if (_it[0] == 1)
        {
            var _g = _it[1];
            var _gr = proj.groups[_g];
            var _gin = min(group_depth(_g) * 20, max(0, _cw - 776));     // groups inside groups step in
            var _gx0 = _lx + _gin;
            var _gw0 = _cw - _gin;
            if (_y + _hdrh >= _ly1 - 10 && _y <= _ly2 + 10)
            {
                var _gid = "grp_" + string(_g);
                var _count = 0;
                for (var c = 0; c < _nr; c++)
                {
                    if (proj.rules[c].group == _g) { _count += 1; }
                }
                var _nsub = 0;
                for (var cg = 0; cg < _ngr; cg++)
                {
                    if (group_parent_of(proj.groups, cg) == _g) { _nsub += 1; }
                }
                var _gcol = group_colour(_g);
                var _ga = 0.95;
                if (group_off_in(proj.groups, _g)) { _ga = 0.5; }
                ui_rrect(_gx0, _y, _gx0 + _gw0, _y + _hdrh, 10, merge_colour(global.TH.btn_hot_top, _gcol, 0.18), global.TH.btn_bot, _ga);
                ui_rrect(_gx0, _y, _gx0 + 8, _y + _hdrh, 4, _gcol, _gcol, 1);
                ui_rrect_line(_gx0, _y, _gx0 + _gw0, _y + _hdrh, 10, _gcol, 0.6, 1);
                // collapse / expand
                var _chot = ui_register(_gid + "_fold", _gx0 + 12, _y + 6, _gx0 + 44, _y + _hdrh - 6, "Collapse / expand|Folds this group down to its title (and the groups inside it), or opens it.");
                ui_chevron(_gx0 + 28, _y + _hdrh * 0.5, 6, c_white, !_gr.collapsed);
                if (_chot && ui_pressed)
                {
                    ui_take_click();
                    _gr.collapsed = !_gr.collapsed;
                    proj_dirty = true;
                }
                var _rt = string(_count) + " rule";
                if (_count != 1) { _rt += "s"; }
                if (_nsub > 0) { _rt += ", " + string(_nsub) + " group"; }
                if (_nsub > 1) { _rt += "s"; }
                draw_set_font(global.f_small);
                var _nmw = max(100, min(240, _gw0 - 532 - 10 - ceil(ui_sw(_rt)) - 10 - 48));
                var _nm = ui_textfield(_gid + "_name", _gx0 + 48, _y + 7, _nmw, 30, _gr.name, 28, "Group name|Call it what the rules do, e.g. 'Ghosts hit the hero' or 'Collecting gems'.");
                set_val(_gr, "name", _nm, _gid + "name");
                ui_text(_gx0 + 48 + _nmw + 10, _y + _hdrh * 0.5, ui_text_fit(_rt, global.f_small, max(10, _gw0 - 532 - 10 - 48 - _nmw - 10)), global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
                var _bx = _gx0 + _gw0 - 8;
                _bx -= 30;
                if (ui_button(_gid + "_del", _bx, _y + 7, 30, 30, "X", "Remove group|Removes the group. Its rules are kept and move out of the group. You can Undo this.", BTN_DANGER)) { _gact = _g; _gop = "del"; }
                _bx -= 36;
                if (ui_button(_gid + "_dn", _bx, _y + 7, 30, 30, "v", "Move group down|The whole group runs later.", BTN_GHOST)) { _gact = _g; _gop = "dn"; }
                _bx -= 36;
                if (ui_button(_gid + "_up", _bx, _y + 7, 30, 30, "^", "Move group up|The whole group runs earlier.", BTN_GHOST)) { _gact = _g; _gop = "up"; }
                _bx -= 86;
                if (ui_button(_gid + "_add", _bx, _y + 7, 80, 30, "+ Rule", "Add rule to this group|Adds a new rule at the end of this group.", BTN_NORMAL)) { _gact = _g; _gop = "add"; }
                _bx -= 86;
                if (ui_button(_gid + "_sub", _bx, _y + 7, 80, 30, "+ Group", "Add a group inside|Makes a new group inside this one - group your groups, e.g. 'Enemies' holding 'Ghosts' and 'Bats'.", BTN_GHOST)) { _gact = _g; _gop = "sub"; }
                _bx -= 166;
                var _pn = ["In: (top level)"];
                for (var pg = 0; pg < _ngr; pg++) { array_push(_pn, "In: " + group_path(pg)); }
                var _np = ui_dropdown(_gid + "_par", _bx, _y + 7, 160, 30, _pn, group_parent_of(proj.groups, _g) + 1, "Inside group|Which group this group sits in. Its rules run with that group's, and switching that group off switches this one off too.") - 1;
                if (_np != group_parent_of(proj.groups, _g))
                {
                    if (_np >= 0 && group_inside(_np, _g)) { toast("A group cannot go inside itself or a group inside it", 1); }
                    else
                    {
                        _gact = _g;
                        _gop = "par";
                        _gpar = _np;
                    }
                }
                _bx -= 84;
                set_val(_gr, "enabled", ui_toggle(_gid + "_on", _bx, _y + 10, "On", _gr.enabled, "Group on / off|Switch a group off to leave its rules - and the groups inside it - out of the game while you test. They are kept, just not built (the code previewer shows them gone)."), _gid + "on");
            }
            _y += _hdrh + 10;
        }
        else
        {
            var _i = _it[1];
            var _ch = logic_card_h(proj.rules[_i]);
            if (_y + _ch >= _ly1 - 10 && _y <= _ly2 + 10)
            {
                var _ind = 0;
                if (proj.rules[_i].group >= 0) { _ind = min(16 + group_depth(proj.rules[_i].group) * 20, max(16, _cw - 760)); }
                var _res = logic_rule_card(proj.rules[_i], _i, _lx + _ind, _y, _cw - _ind, _anames, _snames, _gnames);
                if (_res == 1) { _del = _i; }
                if (_res == 2) { _movei = _i; _move = -1; }
                if (_res == 3) { _movei = _i; _move = 1; }
            }
            _y += _ch + 10;
        }
    }
    ui_scroll_end("logic_list", _lx, _ly1, _lx2 - 10, _ly2, _content);
    if (logic_resort)
    {
        logic_resort = false;
        logic_sort_rules();
    }

    if (_del >= 0)
    {
        undo_mark("ruledel" + string(current_time));
        array_delete(proj.rules, _del, 1);
        if (logic_sel == _del) { logic_sel = -1; }
        else
        {
            if (logic_sel > _del) { logic_sel -= 1; }
        }
    }
    if (_movei >= 0)
    {
        // swap with the nearest rule in the same group
        var _grp = proj.rules[_movei].group;
        var _j = _movei + _move;
        while (_j >= 0 && _j < array_length(proj.rules) && proj.rules[_j].group != _grp) { _j += _move; }
        if (_j >= 0 && _j < array_length(proj.rules))
        {
            undo_mark("rulemove" + string(current_time));
            var _tmp = proj.rules[_movei];
            proj.rules[_movei] = proj.rules[_j];
            proj.rules[_j] = _tmp;
            if (logic_sel == _movei) { logic_sel = _j; }
            else
            {
                if (logic_sel == _j) { logic_sel = _movei; }
            }
        }
    }
    if (_gact >= 0)
    {
        if (_gop == "del")
        {
            undo_mark("grpdel" + string(current_time));
            group_delete(_gact);
        }
        if (_gop == "up" && group_sibling(_gact, -1) >= 0)
        {
            undo_mark("grpmove" + string(current_time));
            group_swap(_gact, group_sibling(_gact, -1));
        }
        if (_gop == "dn" && group_sibling(_gact, 1) >= 0)
        {
            undo_mark("grpmove" + string(current_time));
            group_swap(_gact, group_sibling(_gact, 1));
        }
        if (_gop == "par")
        {
            undo_mark("grppar" + string(current_time));
            proj.groups[_gact].parent = _gpar;
            logic_sort_rules();
        }
        if (_gop == "sub")
        {
            undo_mark("grpsub" + string(current_time));
            var _sg = group_new("Group " + string(array_length(proj.groups) + 1));
            _sg.parent = _gact;
            _sg.collapsed = false;
            array_push(proj.groups, _sg);
            proj.groups[_gact].collapsed = false;
            logic_sort_rules();
        }
        if (_gop == "add")
        {
            if (array_length(proj.rules) < RULES_MAX)
            {
                undo_mark("ruleadd" + string(current_time));
                var _nr2 = rule_new();
                _nr2.a = logic_find_role([0], 0);
                _nr2.b = min(1, max(0, array_length(proj.actors) - 1));
                _nr2.group = _gact;
                array_push(proj.rules, _nr2);
                proj.groups[_gact].collapsed = false;
                var _op = group_parent_of(proj.groups, _gact);       // open the groups it is inside too
                var _on2 = 0;
                while (_op >= 0 && _on2 < 64)
                {
                    proj.groups[_op].collapsed = false;
                    _op = group_parent_of(proj.groups, _op);
                    _on2 += 1;
                }
                logic_sort_rules();
                logic_reveal = _nr2;
            }
            else { toast(string(RULES_MAX) + " rules is the limit", 1); }
        }
    }

    // ---------------- right panel: the generated code, or quick recipes ----------------
    var _px = _x2 - _rw;
    ui_panel(_px, _y1, _x2, _y2, "");
    var _tw = floor((_rw - 40) / 2);
    if (ui_tab("logic_tab_code", _px + 14, _y1 + 8, _tw, 30, "6502 code", logic_code_on, "Code previewer|The 6502 machine code the studio writes from your rules, updated as you change them. Click a rule card to see its part."))
    {
        logic_code_on = true;
        settings_save();
    }
    if (ui_tab("logic_tab_recipes", _px + 14 + _tw + 12, _y1 + 8, _tw, 30, "Quick recipes", !logic_code_on, "Quick recipes|Ready-made rules for the most common game ideas, one click each."))
    {
        logic_code_on = false;
        settings_save();
    }
    draw_line_colour(_px + 14, _y1 + 46, _x2 - 14, _y1 + 46, global.TH.panel_edge, global.TH.panel_edge);
    if (logic_code_on)
    {
        codeview_draw(_px, _y1 + 48, _x2, _y2);
        return;
    }
    var _ry = _y1 + 60;
    var _rintro = "One click adds ready-made rules in a new group. They use your first Player, enemy and Still actor.";
    ui_text_wrap(_px + 20, _ry, _rintro, global.TH.text_dim, _rw - 40, global.f_small, 1);
    draw_set_font(global.f_small);
    _ry += max(50, ceil(ui_sh_ext(_rintro, _rw - 40)) + 14);
    var _rhelp = [
        "Enemy hit|Adds a rule card: when the player touches an enemy, lose a life AND go back to the start AND flash the border.",
        "Pickup|Adds a rule card: when the player touches a pickup, add 10 points AND move the pickup somewhere random AND play the first sound.",
        "Win condition|Adds a rule: when the score reaches 100, you win.",
        "Lose condition|Adds a rule: when lives run out, it's game over.",
        "Getting harder|Adds a rule: every 10 seconds the enemy speeds up.",
        "Fire sound|Adds a rule: pressing fire plays sound 2."
    ];
    for (var t = 0; t < array_length(global.TEMPLATE_NAMES); t++)
    {
        if (ui_button("logic_tpl_" + string(t), _px + 20, _ry, _rw - 40, 38, global.TEMPLATE_NAMES[t], _rhelp[t], BTN_NORMAL))
        {
            logic_add_template(t);
        }
        _ry += 46;
    }
}
