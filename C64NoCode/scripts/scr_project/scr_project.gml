/// C64 NO-CODE STUDIO - project data model, presets, save/load, undo

#macro SPR_COUNT 32

function project_defs_init()
{
    global.ROLE_NAMES = ["Player (joystick)", "Bouncer (diagonal)", "Patrol left-right", "Patrol up-down", "Chaser (follows player)", "Still (does not move)"];
    global.WHEN_NAMES = ["Actor touches actor", "Fire button is pressed", "Every few seconds", "Score reaches", "Lives run out", "The game starts",
                         "Actor hits the scenery"];
    global.DO_NAMES   = ["Add to score", "Lose a life", "Play a sound", "Flash the border", "Send actor back to start",
                         "Move actor to a random spot", "Hide actor", "Show actor", "Change actor colour",
                         "Change background colour", "Game over", "You win!", "Speed up actor",
                         "Slow down actor", "Add a life", "Move actor to another actor", "Stop all sounds",
                         "Play music", "Stop music"];
    global.TEMPLATE_NAMES = ["Player touches enemy: lose a life", "Player touches pickup: score + move pickup",
                             "Score target: you win", "Out of lives: game over", "Every 10 seconds: speed up enemy",
                             "Fire button: play a sound"];
    sid_defs_init();
    machine_defs_init();
    music_defs_init();
}

function sprite_new(_name)
{
    return {
        name : _name,
        mc : false,
        hi : array_create(504, 0),
        mcp : array_create(252, 0),
        preview : 1,
        frames : 1,
        anim_speed : 3,
        left : false
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
        start_up : false,
        anims : anims_new(),        // the Animate page (scr_anim)
        anim_flip : false
    };
}

#macro RULE_DOS_MAX 5
#macro RULES_MAX 100

/// A WHEN / DO rule card: the first DO is on the rule itself, AND DO lines are in more
function rule_new()
{
    return { when : 0, a : 0, b : 1, n : 1, act : 0, target : 0, value : 10, more : [], group : -1 };
}

/// One AND DO line on a rule card
function do_new()
{
    return { act : 2, target : 0, value : 0 };
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
        win_text : "YOU WIN! - PRESS FIRE",
        sound_groups : [],
        groups : [],
        machine : MACHINE_PAL,
        songs : [],
        level_song : array_create(MUS_LEVELS, -1)
    };
    for (var i = 0; i < 8; i++)
    {
        var _s = sfx_new(global.SFX_PRESET_NAMES[i]);
        sfx_apply_preset(_s, i);
        array_push(_p.sfx, _s);
    }
    for (var k = 0; k < SPR_COUNT; k++)
    {
        array_push(_p.sprites, sprite_new("Sprite " + string(k + 1)));
    }
    project_add_engine(_p);
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
    // sprites 2-3: ghost, two frames (skirt ripples)
    var _ghost = [
        "....1111....",
        "..11111111..",
        ".1111111111.",
        ".1133113311.",
        ".1132113211.",
        ".1111111111.",
        ".1111111111.",
        ".1111111111.",
        ".1111111111.",
        ".1111111111."];
    tpl_sprite_at(_p, 1, "Ghost", true, _ghost, 2, 3);
    tpl_sprite_at(_p, 2, "Ghost 2", true, _ghost, 2, 3);
    for (var gk = 0; gk < 12; gk++)
    {
        if (gk mod 3 != 2) { _p.sprites[1].mcp[13 * 12 + gk] = 1; }
        if (gk mod 3 != 0) { _p.sprites[2].mcp[13 * 12 + gk] = 1; }
    }
    tpl_anim(_p, 1, 2, 3, false);
    // sprites 3-4: gem, two frames (sparkle)
    var _gemrows = [
        ".....33.....",
        "....3113....",
        "...311113...",
        "..31111113..",
        ".3111111113.",
        ".2111111112.",
        "..21111112..",
        "...211112...",
        "....2112....",
        ".....22....."];
    tpl_sprite_at(_p, 3, "Gem", true, _gemrows, 3, 5);
    tpl_sprite_at(_p, 4, "Gem sparkle", true, _gemrows, 3, 5);
    _p.sprites[4].mcp[6 * 12 + 4] = 3;
    _p.sprites[4].mcp[7 * 12 + 3] = 3;
    _p.sprites[4].mcp[7 * 12 + 4] = 3;
    _p.sprites[4].mcp[7 * 12 + 5] = 3;
    _p.sprites[4].mcp[8 * 12 + 4] = 3;
    _p.sprites[4].mcp[3 * 12 + 10] = 3;
    _p.sprites[4].mcp[2 * 12 + 11] = 3;
    tpl_anim(_p, 3, 2, 4, false);
    _p.mc1 = 0;
    _p.mc2 = 1;

    var _a0 = actor_new("Hero");
    _a0.sprite = 0; _a0.colour = 7; _a0.role = 0; _a0.speed = 2; _a0.x = 172; _a0.y = 150;
    var _a1 = actor_new("Ghost");
    _a1.sprite = 1; _a1.colour = 2; _a1.role = 4; _a1.speed = 1; _a1.x = 60; _a1.y = 80;
    var _a2 = actor_new("Bouncy Ghost");
    _a2.sprite = 1; _a2.colour = 4; _a2.role = 1; _a2.speed = 2; _a2.x = 280; _a2.y = 90;
    var _a3 = actor_new("Gem");
    _a3.sprite = 3; _a3.colour = 3; _a3.role = 5; _a3.speed = 1; _a3.x = 250; _a3.y = 190;
    _p.actors = [_a0, _a1, _a2, _a3];

    // rule cards (a DO plus AND DO lines) in three groups
    _p.groups = [group_new("Ghosts"), group_new("Gems"), group_new("Winning and losing")];
    _p.rules = [];
    var _r;
    _r = rule_new(); _r.group = 0; _r.when = 0; _r.a = 0; _r.b = 1; _r.act = 1;
    array_push(_r.more, { act : 4, target : 0, value : 0 }, { act : 2, target : 0, value : 6 });
    array_push(_p.rules, _r);
    _r = rule_new(); _r.group = 0; _r.when = 0; _r.a = 0; _r.b = 2; _r.act = 1;
    array_push(_r.more, { act : 4, target : 0, value : 0 }, { act : 3, target : 0, value : 0 });
    array_push(_p.rules, _r);
    _r = rule_new(); _r.group = 0; _r.when = 2; _r.n = 10; _r.act = 12; _r.target = 2; array_push(_p.rules, _r);
    _r = rule_new(); _r.group = 1; _r.when = 0; _r.a = 0; _r.b = 3; _r.act = 0; _r.value = 10;
    array_push(_r.more, { act : 5, target : 3, value : 0 }, { act : 2, target : 0, value : 0 });
    array_push(_p.rules, _r);
    _r = rule_new(); _r.group = 2; _r.when = 3; _r.n = 200; _r.act = 11; array_push(_p.rules, _r);
    _r = rule_new(); _r.group = 2; _r.when = 4; _r.act = 10; array_push(_p.rules, _r);
    // a song for the screen (Music page)
    array_push(_p.songs, music_starter_song("Gem groove"));
    _p.level_song[0] = 0;
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
    struct_overlay(_p, _raw);
    if (!is_array(_p.chars) || array_length(_p.chars) != 1000) { _p.chars = array_create(1000, 32); }
    if (!is_array(_p.cols) || array_length(_p.cols) != 1000) { _p.cols = array_create(1000, 14); }

    var _ls = _raw[$ "sprites"];
    for (var i = 0; i < SPR_COUNT; i++)
    {
        var _s = sprite_new("Sprite " + string(i + 1));
        if (is_array(_ls) && i < array_length(_ls)) { struct_overlay(_s, _ls[i]); }
        if (!is_array(_s.hi) || array_length(_s.hi) != 504) { _s.hi = array_create(504, 0); }
        if (!is_array(_s.mcp) || array_length(_s.mcp) != 252) { _s.mcp = array_create(252, 0); }
        _sprites[i] = _s;
    }
    _p.sprites = _sprites;

    _p.sfx = sfx_list_from_loaded(_raw[$ "sfx"]);
    var _sg = [];
    var _lsg = _raw[$ "sound_groups"];
    if (is_array(_lsg))
    {
        for (var sg = 0; sg < array_length(_lsg); sg++)
        {
            array_push(_sg, struct_overlay({ name : "Folder " + string(sg + 1), open : true }, _lsg[sg]));
        }
    }
    _p.sound_groups = _sg;
    for (var sf = 0; sf < array_length(_p.sfx); sf++)
    {
        if (_p.sfx[sf].group >= array_length(_sg)) { _p.sfx[sf].group = -1; }
    }
    if (!is_numeric(_p.machine)) { _p.machine = MACHINE_PAL; }
    _p.machine = clamp(floor(_p.machine), 0, MACHINE_COUNT - 1);
    music_from_loaded(_p, _raw);

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

    var _grps = [];
    var _lg = _raw[$ "groups"];
    if (is_array(_lg))
    {
        for (var g = 0; g < array_length(_lg); g++)
        {
            var _gp = struct_overlay(group_new("Group " + string(g + 1)), _lg[g]);
            if (!is_numeric(_gp.parent)) { _gp.parent = -1; }
            array_push(_grps, _gp);
        }
    }
    for (var g2 = 0; g2 < array_length(_grps); g2++)
    {
        if (_grps[g2].parent >= array_length(_grps) || _grps[g2].parent == g2) { _grps[g2].parent = -1; }
    }
    _p.groups = _grps;

    var _rules = [];
    var _lr = _raw[$ "rules"];
    if (is_array(_lr))
    {
        for (var m = 0; m < min(RULES_MAX, array_length(_lr)); m++)
        {
            var _ru = struct_overlay(rule_new(), _lr[m]);
            var _more = [];
            if (is_array(_ru.more))
            {
                for (var md = 0; md < min(RULE_DOS_MAX - 1, array_length(_ru.more)); md++)
                {
                    array_push(_more, struct_overlay(do_new(), _ru.more[md]));
                }
            }
            _ru.more = _more;
            if (!is_numeric(_ru.group) || _ru.group >= array_length(_grps)) { _ru.group = -1; }
            array_push(_rules, _ru);
        }
    }
    _p.rules = _rules;

    // map-game engine data
    var _eng = eng_settings_new();
    struct_overlay(_eng, _raw[$ "eng"]);
    _p.eng = _eng;
    if (!is_array(_p.charset) || array_length(_p.charset) != 2048)
    {
        _p.charset = array_create(2048, 0);
        array_copy(_p.charset, 0, global.chargen_rom, 0, min(2048, array_length(global.chargen_rom)));
    }
    var _tiles = [];
    var _lt = _raw[$ "tiles"];
    if (is_array(_lt))
    {
        for (var t = 0; t < min(64, array_length(_lt)); t++)
        {
            var _tl = struct_overlay(tile_new("Tile"), _lt[t]);
            if (!is_array(_tl.c) || array_length(_tl.c) != 4) { _tl.c = [32, 32, 32, 32]; }
            array_push(_tiles, _tl);
        }
    }
    if (array_length(_tiles) == 0) { _tiles = [tile_new("Empty")]; }
    _p.tiles = _tiles;
    var _ens = [];
    var _le = _raw[$ "enemies"];
    if (is_array(_le))
    {
        for (var e = 0; e < min(16, array_length(_le)); e++) { array_push(_ens, struct_overlay(enemy_new("Enemy"), _le[e])); }
    }
    if (array_length(_ens) == 0) { _ens = [enemy_new("Enemy 1")]; }
    _p.enemies = _ens;
    anim_project_fix(_p);
    var _lvls = [];
    var _ll = _raw[$ "levels"];
    if (is_array(_ll))
    {
        for (var l = 0; l < min(8, array_length(_ll)); l++)
        {
            var _lv = struct_overlay(level_new("Level", 40, 12), _ll[l]);
            if (!is_array(_lv.map) || array_length(_lv.map) != _lv.w * _lv.h) { _lv.map = array_create(_lv.w * _lv.h, 0); }
            var _sps = [];
            if (is_array(_lv.spawners))
            {
                for (var q = 0; q < array_length(_lv.spawners); q++) { array_push(_sps, struct_overlay(spawner_new(0, 0, 0), _lv.spawners[q])); }
            }
            _lv.spawners = _sps;
            array_push(_lvls, _lv);
        }
    }
    if (array_length(_lvls) == 0) { _lvls = [level_new("Level 1", 40, 12)]; }
    _p.levels = _lvls;
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
    for (var i = 0; i < SPR_COUNT; i++) { spr_dirty[i] = true; }
    charset_dirty = true;
    sel_actor = clamp(sel_actor, 0, max(0, array_length(proj.actors) - 1));
    snd_sel = clamp(snd_sel, 0, max(0, array_length(proj.sfx) - 1));
    logic_sel = clamp(logic_sel, -1, array_length(proj.rules) - 1);
    build_listing = [];
    live_mark_stale();
}

/// Call BEFORE changing proj. Coalesces rapid edits with the same tag.
function undo_mark(_tag)
{
    proj_dirty = true;
    live_mark_stale();
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

/// One actor reference after actor _idx is removed (a reference to it becomes 0)
function actor_ref_fix(_v, _idx)
{
    if (_v == _idx) { return 0; }
    if (_v > _idx) { return _v - 1; }
    return _v;
}

/// Removes an actor and repairs rule references (AND DO lines too)
function actor_remove(_idx)
{
    array_delete(proj.actors, _idx, 1);
    for (var i = 0; i < array_length(proj.rules); i++)
    {
        var _r = proj.rules[i];
        _r.a = actor_ref_fix(_r.a, _idx);
        _r.b = actor_ref_fix(_r.b, _idx);
        _r.target = actor_ref_fix(_r.target, _idx);
        if (_r.act == 15) { _r.value = actor_ref_fix(_r.value, _idx); }
        for (var m = 0; m < array_length(_r.more); m++)
        {
            var _d = _r.more[m];
            _d.target = actor_ref_fix(_d.target, _idx);
            if (_d.act == 15) { _d.value = actor_ref_fix(_d.value, _idx); }
        }
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
    ui_scale_pref = ini_read_real("ui", "scale", 0);
    start_fullscreen = ini_read_real("ui", "fullscreen", 1) == 1;
    logic_code_on = ini_read_real("ui", "logic_code", 1) == 1;
    u64_ip = ini_read_string("ultimate", "ip", "");
    u64_password = ini_read_string("ultimate", "password", "");
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
    ini_write_real("ui", "scale", ui_scale_pref);
    var _fs = 0;
    if (start_fullscreen) { _fs = 1; }
    ini_write_real("ui", "fullscreen", _fs);
    var _lc = 0;
    if (logic_code_on) { _lc = 1; }
    ini_write_real("ui", "logic_code", _lc);
    ini_write_string("ultimate", "ip", u64_ip);
    ini_write_string("ultimate", "password", u64_password);
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
