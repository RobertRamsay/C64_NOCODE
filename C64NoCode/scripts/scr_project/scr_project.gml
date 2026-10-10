/// C64 NO-CODE STUDIO - project data model, presets, save/load, undo

function project_defs_init()
{
    global.ROLE_NAMES = ["Player (joystick)", "Bouncer (diagonal)", "Patrol left-right", "Patrol up-down", "Chaser (follows player)", "Still (does not move)"];
    global.WHEN_NAMES = ["Actor touches actor", "Fire button is pressed", "Every few seconds", "Score reaches", "Lives run out", "The game starts"];
    global.DO_NAMES   = ["Add to score", "Lose a life", "Play a sound", "Flash the border", "Send actor back to start",
                         "Move actor to a random spot", "Hide actor", "Show actor", "Change actor colour",
                         "Change background colour", "Game over", "You win!", "Speed up actor"];
    global.WAVE_NAMES = ["Triangle (soft)", "Sawtooth (buzzy)", "Pulse (classic)", "Noise (crunchy)"];
    global.SFX_PRESET_NAMES = ["Coin", "Laser", "Explosion", "Jump", "Hit", "Power up", "Lose", "Blip"];
    global.TEMPLATE_NAMES = ["Player touches enemy: lose a life", "Player touches pickup: score + move pickup",
                             "Score target: you win", "Out of lives: game over", "Every 10 seconds: speed up enemy",
                             "Fire button: play a sound"];
}

function sprite_new(_name)
{
    return {
        name : _name,
        mc : false,
        hi : array_create(504, 0),
        mcp : array_create(252, 0),
        preview : 1
    };
}

function actor_new(_name)
{
    return {
        name : _name,
        sprite : 0,
        colour : 1,
        role : 5,
        speed : 2,
        x : 172,
        y : 140,
        visible : true,
        start_left : false,
        start_up : false
    };
}

function rule_new()
{
    return { when : 0, a : 0, b : 1, n : 1, act : 0, target : 0, value : 10 };
}

function sfx_new(_name)
{
    return { name : _name, wave : 2, pitch : 60, sweep : 0, len : 10, atk : 0, dec : 8, sus : 0, rel : 6 };
}

function sfx_apply_preset(_s, _p)
{
    var _t = [
        [2, 60, 6, 8, 0, 6, 0, 4],
        [1, 120, -8, 12, 0, 8, 0, 6],
        [3, 40, -1, 25, 0, 10, 0, 9],
        [0, 30, 4, 14, 0, 7, 4, 5],
        [3, 14, 0, 6, 0, 5, 0, 3],
        [2, 40, 3, 30, 2, 6, 8, 6],
        [0, 50, -2, 30, 0, 9, 6, 8],
        [2, 90, 0, 3, 0, 3, 0, 2]
    ];
    var _v = _t[clamp(_p, 0, 7)];
    _s.wave = _v[0];
    _s.pitch = _v[1];
    _s.sweep = _v[2];
    _s.len = _v[3];
    _s.atk = _v[4];
    _s.dec = _v[5];
    _s.sus = _v[6];
    _s.rel = _v[7];
}

function project_new()
{
    var _p = {
        version : 1,
        name : "My C64 Game",
        border : 14,
        background : 6,
        chars : array_create(1000, 32),
        cols : array_create(1000, 14),
        sprites : [],
        mc1 : 6,
        mc2 : 1,
        actors : [],
        rules : [],
        sfx : [],
        lives : 3,
        show_score : true,
        show_lives : true,
        hud_row : 0,
        hud_colour : 1,
        over_text : "GAME OVER - PRESS FIRE",
        win_text : "YOU WIN! - PRESS FIRE"
    };
    for (var i = 0; i < 8; i++)
    {
        array_push(_p.sprites, sprite_new("Sprite " + string(i + 1)));
        var _s = sfx_new(global.SFX_PRESET_NAMES[i]);
        sfx_apply_preset(_s, i);
        array_push(_p.sfx, _s);
    }
    return _p;
}

/// Builds a full working example game
function project_example()
{
    var _p = project_new();
    _p.name = "Gem Hunter";
    _p.border = 11;
    _p.background = 0;
    // frame of reverse-space blocks
    for (var c = 0; c < 40; c++)
    {
        _p.chars[40 + c] = 160;   _p.cols[40 + c] = 12;
        _p.chars[960 + c] = 160;  _p.cols[960 + c] = 12;
    }
    for (var r = 1; r < 25; r++)
    {
        _p.chars[r * 40] = 160;      _p.cols[r * 40] = 12;
        _p.chars[r * 40 + 39] = 160; _p.cols[r * 40 + 39] = 12;
    }
    var _msg = "COLLECT GEMS - AVOID GHOSTS";
    var _start = 40 * 23 + (40 - string_length(_msg)) div 2;
    for (var k = 1; k <= string_length(_msg); k++)
    {
        _p.chars[_start + k - 1] = scr_code_from_char(string_char_at(_msg, k));
        _p.cols[_start + k - 1] = 15;
    }

    // sprite 1: hero (hires smiley)
    var _hero = _p.sprites[0];
    _hero.name = "Hero";
    _hero.preview = 7;
    for (var _iy = 0; _iy < 21; _iy++)
    {
        for (var _ix = 0; _ix < 24; _ix++)
        {
            var _d = point_distance(_ix, _iy, 11.5, 10);
            if (_d <= 9.6) { _hero.hi[_iy * 24 + _ix] = 1; }
            if ((_ix == 8 || _ix == 9 || _ix == 14 || _ix == 15) && (_iy == 6 || _iy == 7)) { _hero.hi[_iy * 24 + _ix] = 0; }
            if (_iy == 13 && _ix >= 7 && _ix <= 16) { _hero.hi[_iy * 24 + _ix] = 0; }
            if (_iy == 12 && (_ix == 6 || _ix == 17)) { _hero.hi[_iy * 24 + _ix] = 0; }
        }
    }
    // sprite 2: ghost (multicolour)
    var _gh = _p.sprites[1];
    _gh.name = "Ghost";
    _gh.mc = true;
    _gh.preview = 2;
    for (var y2 = 0; y2 < 21; y2++)
    {
        for (var x2 = 0; x2 < 12; x2++)
        {
            var _in = false;
            if (y2 < 9)
            {
                if (point_distance(x2 * 2 + 1, y2, 12, 9) <= 10) { _in = true; }
            }
            else
            {
                if (y2 < 18) { _in = true; }
                else
                {
                    if ((x2 + (y2 - 18)) mod 3 != 0) { _in = true; }
                }
            }
            if (x2 < 1 || x2 > 10) { _in = false; }
            if (_in) { _gh.mcp[y2 * 12 + x2] = 1; }
            if ((x2 == 3 || x2 == 4 || x2 == 7 || x2 == 8) && y2 >= 6 && y2 <= 9) { _gh.mcp[y2 * 12 + x2] = 3; }
            if ((x2 == 4 || x2 == 8) && (y2 == 8 || y2 == 9)) { _gh.mcp[y2 * 12 + x2] = 2; }
        }
    }
    // sprite 3: gem (hires diamond)
    var _gem = _p.sprites[2];
    _gem.name = "Gem";
    _gem.preview = 3;
    for (var y3 = 0; y3 < 21; y3++)
    {
        for (var x3 = 0; x3 < 24; x3++)
        {
            if (abs(x3 - 11.5) * 1.1 + abs(y3 - 10) <= 9) { _gem.hi[y3 * 24 + x3] = 1; }
            if (y3 == 6 && abs(x3 - 11.5) < 5) { _gem.hi[y3 * 24 + x3] = 0; }
        }
    }

    var _a0 = actor_new("Hero");
    _a0.sprite = 0; _a0.colour = 7; _a0.role = 0; _a0.speed = 2; _a0.x = 172; _a0.y = 150;
    var _a1 = actor_new("Ghost");
    _a1.sprite = 1; _a1.colour = 2; _a1.role = 4; _a1.speed = 1; _a1.x = 60; _a1.y = 80;
    var _a2 = actor_new("Bouncy Ghost");
    _a2.sprite = 1; _a2.colour = 4; _a2.role = 1; _a2.speed = 2; _a2.x = 280; _a2.y = 90;
    var _a3 = actor_new("Gem");
    _a3.sprite = 2; _a3.colour = 3; _a3.role = 5; _a3.speed = 1; _a3.x = 250; _a3.y = 190;
    _p.actors = [_a0, _a1, _a2, _a3];

    _p.rules = [];
    var _r;
    _r = rule_new(); _r.when = 0; _r.a = 0; _r.b = 1; _r.act = 1; array_push(_p.rules, _r);
    _r = rule_new(); _r.when = 0; _r.a = 0; _r.b = 1; _r.act = 4; _r.target = 0; array_push(_p.rules, _r);
    _r = rule_new(); _r.when = 0; _r.a = 0; _r.b = 1; _r.act = 2; _r.value = 6; array_push(_p.rules, _r);
    _r = rule_new(); _r.when = 0; _r.a = 0; _r.b = 2; _r.act = 1; array_push(_p.rules, _r);
    _r = rule_new(); _r.when = 0; _r.a = 0; _r.b = 2; _r.act = 4; _r.target = 0; array_push(_p.rules, _r);
    _r = rule_new(); _r.when = 0; _r.a = 0; _r.b = 2; _r.act = 3; array_push(_p.rules, _r);
    _r = rule_new(); _r.when = 0; _r.a = 0; _r.b = 3; _r.act = 0; _r.value = 10; array_push(_p.rules, _r);
    _r = rule_new(); _r.when = 0; _r.a = 0; _r.b = 3; _r.act = 5; _r.target = 3; array_push(_p.rules, _r);
    _r = rule_new(); _r.when = 0; _r.a = 0; _r.b = 3; _r.act = 2; _r.value = 0; array_push(_p.rules, _r);
    _r = rule_new(); _r.when = 2; _r.n = 10; _r.act = 12; _r.target = 2; array_push(_p.rules, _r);
    _r = rule_new(); _r.when = 3; _r.n = 200; _r.act = 11; array_push(_p.rules, _r);
    _r = rule_new(); _r.when = 4; _r.act = 10; array_push(_p.rules, _r);
    return _p;
}

/// Copies fields that exist in _src over the defaults in _dst
function struct_overlay(_dst, _src)
{
    if (!is_struct(_src)) { return _dst; }
    var _names = variable_struct_get_names(_src);
    for (var i = 0; i < array_length(_names); i++)
    {
        var _k = _names[i];
        _dst[$ _k] = _src[$ _k];
    }
    return _dst;
}

function project_from_loaded(_raw)
{
    var _p = project_new();
    if (!is_struct(_raw)) { return _p; }
    var _sprites = _p.sprites;
    var _sfx = _p.sfx;
    struct_overlay(_p, _raw);
    if (!is_array(_p.chars) || array_length(_p.chars) != 1000) { _p.chars = array_create(1000, 32); }
    if (!is_array(_p.cols) || array_length(_p.cols) != 1000) { _p.cols = array_create(1000, 14); }

    var _ls = _raw[$ "sprites"];
    for (var i = 0; i < 8; i++)
    {
        var _s = sprite_new("Sprite " + string(i + 1));
        if (is_array(_ls) && i < array_length(_ls)) { struct_overlay(_s, _ls[i]); }
        if (!is_array(_s.hi) || array_length(_s.hi) != 504) { _s.hi = array_create(504, 0); }
        if (!is_array(_s.mcp) || array_length(_s.mcp) != 252) { _s.mcp = array_create(252, 0); }
        _sprites[i] = _s;
    }
    _p.sprites = _sprites;

    var _lf = _raw[$ "sfx"];
    for (var j = 0; j < 8; j++)
    {
        var _f = _sfx[j];
        if (is_array(_lf) && j < array_length(_lf)) { struct_overlay(_f, _lf[j]); }
    }
    _p.sfx = _sfx;

    var _acts = [];
    var _la = _raw[$ "actors"];
    if (is_array(_la))
    {
        for (var k = 0; k < min(8, array_length(_la)); k++)
        {
            array_push(_acts, struct_overlay(actor_new("Actor"), _la[k]));
        }
    }
    _p.actors = _acts;

    var _rules = [];
    var _lr = _raw[$ "rules"];
    if (is_array(_lr))
    {
        for (var m = 0; m < array_length(_lr); m++)
        {
            array_push(_rules, struct_overlay(rule_new(), _lr[m]));
        }
    }
    _p.rules = _rules;
    return _p;
}

function file_write_text(_path, _text)
{
    var _b = buffer_create(string_byte_length(_text) + 1, buffer_grow, 1);
    buffer_write(_b, buffer_text, _text);
    var _ok = true;
    buffer_save_ext(_b, _path, 0, buffer_tell(_b));
    buffer_delete(_b);
    return _ok;
}

function file_read_text(_path)
{
    if (!file_exists(_path)) { return ""; }
    var _b = buffer_load(_path);
    if (_b == -1) { return ""; }
    buffer_seek(_b, buffer_seek_start, 0);
    var _s = "";
    if (buffer_get_size(_b) > 0) { _s = buffer_read(_b, buffer_text); }
    buffer_delete(_b);
    return _s;
}

function project_save_to(_path)
{
    file_write_text(_path, json_stringify(proj, true));
    proj_path = _path;
    proj_dirty = false;
    settings_save();
    toast("Saved " + filename_name(_path), 0);
}

function project_load_from(_path)
{
    var _txt = file_read_text(_path);
    if (_txt == "")
    {
        toast("Could not read that file", 2);
        return false;
    }
    var _raw = undefined;
    try
    {
        _raw = json_parse(_txt);
    }
    catch (_e)
    {
        toast("That file is not a valid project", 2);
        return false;
    }
    proj = project_from_loaded(_raw);
    proj_path = _path;
    proj_dirty = false;
    project_after_change();
    undo_stack = [];
    redo_stack = [];
    toast("Opened " + filename_name(_path), 0);
    return true;
}

function project_after_change()
{
    for (var i = 0; i < 8; i++) { spr_dirty[i] = true; }
    sel_actor = clamp(sel_actor, 0, max(0, array_length(proj.actors) - 1));
    build_listing = [];
}

/// Call BEFORE changing proj. Coalesces rapid edits with the same tag.
function undo_mark(_tag)
{
    proj_dirty = true;
    if (_tag == undo_last_tag && current_time - undo_last_time < 1200)
    {
        undo_last_time = current_time;
        return;
    }
    undo_last_tag = _tag;
    undo_last_time = current_time;
    array_push(undo_stack, json_stringify(proj));
    if (array_length(undo_stack) > 80) { array_delete(undo_stack, 0, 1); }
    redo_stack = [];
}

function undo_do()
{
    if (array_length(undo_stack) == 0) { toast("Nothing to undo", 1); return; }
    array_push(redo_stack, json_stringify(proj));
    var _s = array_pop(undo_stack);
    proj = project_from_loaded(json_parse(_s));
    undo_last_tag = "";
    proj_dirty = true;
    project_after_change();
}

function redo_do()
{
    if (array_length(redo_stack) == 0) { toast("Nothing to redo", 1); return; }
    array_push(undo_stack, json_stringify(proj));
    var _s = array_pop(redo_stack);
    proj = project_from_loaded(json_parse(_s));
    undo_last_tag = "";
    proj_dirty = true;
    project_after_change();
}

/// Sets struct field with undo when the value changes
function set_val(_struct, _key, _value, _tag)
{
    if (_struct[$ _key] != _value)
    {
        undo_mark(_tag);
        _struct[$ _key] = _value;
        return true;
    }
    return false;
}

/// Encodes a sprite into 63 C64 bytes
function sprite_encode(_s)
{
    var _out = array_create(63, 0);
    for (var r = 0; r < 21; r++)
    {
        for (var b = 0; b < 3; b++)
        {
            var _v = 0;
            if (_s.mc)
            {
                for (var p = 0; p < 4; p++)
                {
                    var _px = _s.mcp[r * 12 + b * 4 + p];
                    var _bits = 0;
                    if (_px == 1) { _bits = 2; }
                    if (_px == 2) { _bits = 1; }
                    if (_px == 3) { _bits = 3; }
                    _v = _v | (_bits << (6 - p * 2));
                }
            }
            else
            {
                for (var k = 0; k < 8; k++)
                {
                    if (_s.hi[r * 24 + b * 8 + k] != 0) { _v = _v | (128 >> k); }
                }
            }
            _out[r * 3 + b] = _v;
        }
    }
    return _out;
}

/// Removes an actor and repairs rule references
function actor_remove(_idx)
{
    array_delete(proj.actors, _idx, 1);
    for (var i = 0; i < array_length(proj.rules); i++)
    {
        var _r = proj.rules[i];
        if (_r.a == _idx) { _r.a = 0; }
        else { if (_r.a > _idx) { _r.a -= 1; } }
        if (_r.b == _idx) { _r.b = 0; }
        else { if (_r.b > _idx) { _r.b -= 1; } }
        if (_r.target == _idx) { _r.target = 0; }
        else { if (_r.target > _idx) { _r.target -= 1; } }
    }
}

function settings_load()
{
    ini_open("c64nocode_settings.ini");
    vice_path = ini_read_string("paths", "vice", "");
    out_path = ini_read_string("paths", "prg", "");
    proj_path = ini_read_string("paths", "project", "");
    helpers_on = ini_read_real("ui", "helpers", 1) == 1;
    auto_tutorials = ini_read_real("ui", "auto_tutorials", 1) == 1;
    for (var i = 0; i < WS_COUNT; i++)
    {
        ws_seen[i] = ini_read_real("seen", "ws" + string(i), 0) == 1;
    }
    ini_close();
}

function settings_save()
{
    ini_open("c64nocode_settings.ini");
    ini_write_string("paths", "vice", vice_path);
    ini_write_string("paths", "prg", out_path);
    ini_write_string("paths", "project", proj_path);
    var _h = 0;
    if (helpers_on) { _h = 1; }
    ini_write_real("ui", "helpers", _h);
    var _t = 0;
    if (auto_tutorials) { _t = 1; }
    ini_write_real("ui", "auto_tutorials", _t);
    for (var i = 0; i < WS_COUNT; i++)
    {
        var _s = 0;
        if (ws_seen[i]) { _s = 1; }
        ini_write_real("seen", "ws" + string(i), _s);
    }
    ini_close();
}

function autosave_path()
{
    return game_save_id + "autosave.c64nc";
}
