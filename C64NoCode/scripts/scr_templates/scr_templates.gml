/// C64 NO-CODE STUDIO - game templates (all built from code, no external files)

function templates_init()
{
    global.TEMPLATES = [
        { name : "Gem Hunter", kind : "Single screen", desc : "Collect gems and dodge ghosts on one screen. Built with actors and WHEN/DO rules." },
        { name : "Side Blaster", kind : "Horizontal shoot-em-up", desc : "Auto-scrolling space shooter over rocky caverns. Waves of sine-wave aliens, saucers and aimed turrets." },
        { name : "Sky Strike", kind : "Vertical shoot-em-up", desc : "Vertical scroller with spread shot, diving attackers and enemies that fire at you." },
        { name : "Jump Quest", kind : "Scrolling platformer", desc : "Run, jump and climb ladders through a long scrolling level. Coins, spikes, walkers and bats." },
        { name : "Castle Rooms", kind : "Flip-screen platformer", desc : "Classic room-by-room platformer: the screen flips when you leave the edge." },
        { name : "Rock Digger", kind : "Cave digger (Boulder Dash style)", desc : "Dig through dirt, collect diamonds, avoid falling boulders and fireflies, then reach the exit." },
        { name : "Maze Raider", kind : "Top-down adventure", desc : "8-way scrolling maze with treasure, shooting and roaming monsters." }
    ];
}

// ---------------- pixel art helpers ----------------

function tpl_hash(_x, _y, _seed)
{
    var _h = (_x * 131 + _y * 197 + _seed * 911 + 17) mod 1021;
    _h = (_h * _h * 7 + _x * 13 + _y * 5 + _seed) mod 1021;
    _h = (_h * 37 + 11) mod 1021;
    return _h / 1020;
}

/// 16x16 shape predicate for tile graphics
function tpl_shape(_shape, _x, _y)
{
    switch (_shape)
    {
        case "brick":
            var _row = _y div 4;
            var _off = 0;
            if ((_row mod 2) == 1) { _off = 4; }
            if ((_y mod 4) == 3) { return false; }
            if (((_x + _off) mod 8) == 7) { return false; }
            return true;
        case "steel":
            if (_x == 0 || _y == 0) { return false; }
            if ((_x == 3 || _x == 12) && (_y == 3 || _y == 12)) { return false; }
            return (_x + _y) mod 7 != 0 || _x < 2;
        case "dirt":
            return tpl_hash(_x, _y, 7) < 0.45;
        case "boulder":
            var _d = point_distance(_x, _y, 7.5, 8);
            if (_d > 7.5) { return false; }
            if (_d > 6 && _x > 8 && _y > 8) { return false; }
            return tpl_hash(_x, _y, 3) < 0.85 || _d < 3;
        case "diamond":
            var _m = abs(_x - 7.5) + abs(_y - 7.5);
            if (_m > 7.5) { return false; }
            if (_m < 3) { return (_x + _y) mod 2 == 0; }
            return true;
        case "exit":
            if (_x < 1 || _x > 14 || _y < 1) { return false; }
            if (_x == 1 || _x == 14 || _y == 1) { return true; }
            return (_x == 11 && _y == 8) || ((_y mod 3) == 0);
        case "ladder":
            if (_x == 2 || _x == 3 || _x == 12 || _x == 13) { return true; }
            return (_y mod 4) == 1;
        case "platform":
            if (_y > 5) { return false; }
            if (_y == 0 || _y == 5) { return true; }
            return (_x mod 4) != 3;
        case "ground":
            if (_y < 3) { return (_x + _y) mod 3 != 0; }
            return tpl_hash(_x, _y, 11) < 0.55;
        case "spikes":
            if (_y < 6) { return false; }
            var _sx = _x mod 4;
            return abs(_sx - 1.5) <= (_y - 6) / 6;
        case "coin":
            var _cd = point_distance(_x, _y, 7.5, 7.5);
            return _cd < 5.5 && !(_cd < 3 && _x != 7);
        case "rock":
            return tpl_hash(_x div 2, _y div 2, 5) < 0.8;
        case "star":
            return (_x == 4 && _y == 5) || (_x == 12 && _y == 11) || (_x == 9 && _y == 2 && tpl_hash(1, 2, 3) > 0.5);
        case "wall":
            if (_x == 0 || _y == 0 || _x == 15 || _y == 15) { return true; }
            return tpl_hash(_x, _y, 13) < 0.3;
        case "floor":
            return (_x mod 8 == 0 && _y mod 8 == 0);
        case "treasure":
            if (_y < 4 || _y > 13 || _x < 2 || _x > 13) { return false; }
            if (_y == 4 || _y == 13 || _x == 2 || _x == 13) { return true; }
            return _y == 8 || (_x == 7 || _x == 8);
        case "lava":
            return (_y + floor(sin(_x / 2) * 2)) mod 4 < 2;
    }
    return false;
}

/// Draws a 16x16 shape into 4 consecutive chars of the charset
function tpl_tile_gfx(_p, _code, _shape)
{
    for (var q = 0; q < 4; q++)
    {
        var _ox = (q mod 2) * 8;
        var _oy = (q div 2) * 8;
        for (var r = 0; r < 8; r++)
        {
            var _b = 0;
            for (var b = 0; b < 8; b++)
            {
                if (tpl_shape(_shape, _ox + b, _oy + r)) { _b = _b | (128 >> b); }
            }
            _p.charset[(_code + q) * 8 + r] = _b;
        }
    }
}

/// Adds a tile with fresh graphics. Returns the tile index.
function tpl_tile(_p, _name, _shape, _col, _attr, _score)
{
    var _t = tile_new(_name);
    var _code = 128 + (array_length(_p.tiles) - 1) * 4;
    if (_shape == "")
    {
        _t.c = [32, 32, 32, 32];
    }
    else
    {
        tpl_tile_gfx(_p, _code, _shape);
        _t.c = [_code, _code + 1, _code + 2, _code + 3];
    }
    _t.col = _col;
    _t.attr = _attr;
    _t.score = _score;
    array_push(_p.tiles, _t);
    return array_length(_p.tiles) - 1;
}

/// Sprite from rows of text. Hi-res: '#' set. Multicolour (12 wide): 1 own, 2 shared A, 3 shared B.
function tpl_sprite(_p, _i, _name, _mc, _rows, _preview)
{
    var _s = sprite_new(_name);
    _s.mc = _mc;
    _s.preview = _preview;
    for (var r = 0; r < min(21, array_length(_rows)); r++)
    {
        var _line = _rows[r];
        for (var c = 1; c <= string_length(_line); c++)
        {
            var _ch = string_char_at(_line, c);
            if (_mc)
            {
                if (c <= 12)
                {
                    var _v = 0;
                    if (_ch == "1") { _v = 1; }
                    if (_ch == "2") { _v = 2; }
                    if (_ch == "3") { _v = 3; }
                    _s.mcp[r * 12 + c - 1] = _v;
                }
            }
            else
            {
                if (c <= 24 && _ch == "#") { _s.hi[r * 24 + c - 1] = 1; }
            }
        }
    }
    _p.sprites[_i] = _s;
}

function tpl_sprite_library(_p)
{
    tpl_sprite(_p, 0, "Ship right", false, [
        "", "", "",
        "####",
        "######",
        " #######",
        "  ##########",
        "  ##############",
        " ####################",
        "########################",
        " ####################",
        "  ##############",
        "  ##########",
        " #######",
        "######",
        "####"], 7);
    tpl_sprite(_p, 1, "Laser", false, ["", "", "", "", "", "", "", "", "",
        "     ##############",
        "     ##############"], 1);
    tpl_sprite(_p, 2, "Enemy shot", false, ["", "", "", "", "", "", "", "",
        "          ####",
        "         ######",
        "         ######",
        "          ####"], 10);
    tpl_sprite(_p, 3, "Alien", true, [
        "", "",
        "    1111",
        "  11111111",
        " 1133113311",
        " 1132113211",
        " 1111111111",
        "  11111111",
        "   1 22 1",
        "  1  22  1",
        " 1        1"], 5);
    tpl_sprite(_p, 4, "Saucer", true, [
        "", "", "", "",
        "    3333",
        "   333333",
        "  11111111",
        " 1212121211",
        "111111111111",
        "  11111111",
        "    2222"], 14);
    tpl_sprite(_p, 5, "Turret", true, [
        "", "", "", "", "", "", "", "",
        "     22",
        "     22",
        "    1111",
        "   111111",
        "  11111111",
        "  13311331",
        " 1111111111",
        " 1111111111"], 12);
    tpl_sprite(_p, 6, "Ship up", false, [
        "           ##",
        "           ##",
        "          ####",
        "          ####",
        "         ######",
        "         ######",
        "        ########",
        "   #    ########    #",
        "   #   ##########   #",
        "   ## ############ ##",
        "   ##################",
        "   ##################",
        "   ######## #########",
        "   #####       ######",
        "   ###          #####",
        "                  "], 15);
    tpl_sprite(_p, 7, "Bolt", false, ["",
        "           ##",
        "           ##",
        "           ##",
        "           ##",
        "           ##",
        "           ##",
        "           ##"], 7);
    tpl_sprite(_p, 8, "Hero", true, [
        "",
        "    2222",
        "   222222",
        "   311311",
        "   311311",
        "    3333",
        "   111111",
        "  11111111",
        "  31111113",
        "  31111113",
        "   111111",
        "   22  22",
        "   22  22",
        "   22  22",
        "  222  222",
        "", "", "", "", "",
        ""], 6);
    tpl_sprite(_p, 9, "Walker", true, [
        "", "", "", "", "",
        "    1111",
        "   111111",
        "  11311311",
        "  11211211",
        "  11111111",
        "   111111",
        "  1 1111 1",
        "  1  11  1",
        "    1  1",
        "   11  11"], 8);
    tpl_sprite(_p, 10, "Bat", true, [
        "", "", "", "",
        "11        11",
        "111  11  111",
        "1111 11 1111",
        "111113311111",
        " 1111111111",
        "  11 11 11",
        "  1      1"], 4);
    tpl_sprite(_p, 11, "Digger", true, [
        "",
        "    3333",
        "   322223",
        "   312213",
        "   322223",
        "    3333",
        "   111111",
        "  11111111",
        "  21111112",
        "  21111112",
        "   111111",
        "   11  11",
        "   11  11",
        "  222  222",
        "", "", "", "", "", "",
        ""], 5);
    tpl_sprite(_p, 12, "Firefly", true, [
        "",
        "  33    33",
        "   3    3",
        "  11111111",
        " 1122222211",
        " 1121111211",
        " 1121331211",
        " 1121331211",
        " 1121111211",
        " 1122222211",
        "  11111111",
        "   3    3",
        "  33    33"], 8);
    tpl_sprite(_p, 13, "Explorer", true, [
        "",
        "    2222",
        "   222222",
        "  22222222",
        "   311113",
        "   313313",
        "    3333",
        "  11111111",
        " 1111111111",
        " 3 111111 3",
        "   111111",
        "   22  22",
        "   22  22",
        "  333  333"], 9);
    tpl_sprite(_p, 14, "Ghost", true, [
        "",
        "    1111",
        "  11111111",
        " 1111111111",
        " 1133113311",
        " 1132113211",
        " 1111111111",
        " 1111111111",
        " 1111111111",
        " 1111111111",
        " 1111111111",
        " 11 11 11 1",
        " 1  1  1  1"], 2);
    tpl_sprite(_p, 15, "Spark", false, ["", "", "", "", "", "",
        "         #  #",
        "          ##",
        "        ######",
        "          ##",
        "         #  #"], 1);
}

function tpl_base(_name, _kind, _scroll)
{
    var _p = project_new();
    _p.name = _name;
    _p.game_type = 1;
    _p.eng.kind = _kind;
    _p.eng.scroll = _scroll;
    _p.tiles = [];
    _p.enemies = [];
    _p.levels = [];
    tpl_tile(_p, "Empty", "", 0, 0, 0);
    tpl_sprite_library(_p);
    return _p;
}

function tpl_set(_lv, _x, _y, _t)
{
    if (_x >= 0 && _y >= 0 && _x < _lv.w && _y < _lv.h) { _lv.map[_y * _lv.w + _x] = _t; }
}

function tpl_fill(_lv, _x1, _y1, _x2, _y2, _t)
{
    for (var _yy = _y1; _yy <= _y2; _yy++)
    {
        for (var _xx = _x1; _xx <= _x2; _xx++) { tpl_set(_lv, _xx, _yy, _t); }
    }
}

function tpl_enemy(_p, _name, _spr, _col, _move, _spd, _dir, _hp, _score, _fire, _rate, _fdir)
{
    var _e = enemy_new(_name);
    _e.spr = _spr; _e.col = _col; _e.move = _move; _e.spd = _spd; _e.dir = _dir;
    _e.hp = _hp; _e.score = _score; _e.fire = _fire; _e.rate = _rate; _e.fdir = _fdir;
    array_push(_p.enemies, _e);
    return array_length(_p.enemies) - 1;
}

function tpl_spawn(_lv, _x, _y, _type, _count, _interval, _dir)
{
    var _s = spawner_new(_x, _y, _type);
    _s.count = _count;
    _s.interval = _interval;
    _s.dir = _dir;
    array_push(_lv.spawners, _s);
}

// ---------------- the templates ----------------

function template_build(_i)
{
    switch (_i)
    {
        case 0: return project_example();
        case 1: return tpl_side_blaster();
        case 2: return tpl_sky_strike();
        case 3: return tpl_jump_quest(false);
        case 4: return tpl_jump_quest(true);
        case 5: return tpl_rock_digger();
        case 6: return tpl_maze_raider();
    }
    return project_new();
}

function tpl_side_blaster()
{
    var _p = tpl_base("Side Blaster", KIND_SHMUP, SCROLL_H);
    var _e = _p.eng;
    _e.auto = true; _e.auto_speed = 0; _e.wtop = 2; _e.wrows = 18; _e.fullcol = false; _e.wincol = 15;
    _e.pspr = 0; _e.pcol = 7; _e.bspr = 1; _e.bcol = 1; _e.ebspr = 2; _e.ebcol = 10;
    _e.weapon = 2; _e.firedir = 2; _e.bspeed = 7; _e.cooldown = 9; _e.pspeed = 2;
    _e.border = 0; _e.bg = 0; _e.smc1 = 11; _e.smc2 = 1;
    _p.sfx[1].name = "Laser"; sfx_apply_preset(_p.sfx[1], 1);
    _p.sfx[2].name = "Boom"; sfx_apply_preset(_p.sfx[2], 2);
    var _star = tpl_tile(_p, "Stars", "star", 15, 0, 0);
    var _rock = tpl_tile(_p, "Rock", "rock", 9, TA_SOLID, 0);
    var _rim = tpl_tile(_p, "Rock edge", "ground", 8, TA_SOLID, 0);
    var _wave = tpl_enemy(_p, "Wave alien", 3, 5, 2, 2, 6, 1, 10, 0, 60, 6);
    var _sauc = tpl_enemy(_p, "Saucer", 4, 14, 4, 2, 7, 2, 25, 1, 50, 6);
    var _tur = tpl_enemy(_p, "Turret", 5, 12, 0, 1, 0, 3, 50, 2, 70, 6);
    var _dart = tpl_enemy(_p, "Dart", 3, 10, 1, 3, 6, 1, 15, 0, 60, 6);
    var _lv = level_new("Asteroid run", 160, 9);
    for (var _ix = 0; _ix < 160; _ix++)
    {
        for (var _iy = 0; _iy < 9; _iy++)
        {
            if (tpl_hash(_ix, _iy, 1) < 0.18) { tpl_set(_lv, _ix, _iy, _star); }
        }
        var _top = floor(1 + sin(_ix / 7) * 1.2 + tpl_hash(_ix, 0, 2));
        var _bot = floor(1 + cos(_ix / 9) * 1.2 + tpl_hash(_ix, 1, 2));
        if (_ix < 22) { _top = 0; _bot = 1; }
        tpl_fill(_lv, _ix, 0, _ix, _top - 1, _rock);
        if (_top > 0) { tpl_set(_lv, _ix, _top - 1, _rim); }
        tpl_fill(_lv, _ix, 9 - _bot, _ix, 8, _rock);
        if (_bot > 0) { tpl_set(_lv, _ix, 9 - _bot, _rim); }
    }
    _lv.px = 3; _lv.py = 4;
    for (var w = 24; w < 150; w += 9)
    {
        var _k = (w div 9) mod 4;
        if (_k == 0) { tpl_spawn(_lv, w, 3, _wave, 5, 14, 255); }
        if (_k == 1) { tpl_spawn(_lv, w, 5, _sauc, 2, 40, 255); }
        if (_k == 2) { tpl_spawn(_lv, w, 2 + (w mod 4), _dart, 3, 20, 255); }
        if (_k == 3)
        {
            tpl_fill(_lv, w - 1, 6, w + 1, 8, _rock);
            tpl_set(_lv, w, 6, _rim);
            tpl_spawn(_lv, w, 5, _tur, 1, 1, 255);
        }
    }
    array_push(_p.levels, _lv);
    _p.over_text = "GAME OVER - PRESS FIRE";
    _p.win_text = "SECTOR CLEARED! - PRESS FIRE";
    return _p;
}

function tpl_sky_strike()
{
    var _p = tpl_base("Sky Strike", KIND_SHMUP, SCROLL_V);
    var _e = _p.eng;
    _e.auto = true; _e.auto_speed = 1; _e.wtop = 2; _e.wrows = 16; _e.fullcol = false; _e.wincol = 14;
    _e.pspr = 6; _e.pcol = 15; _e.bspr = 7; _e.bcol = 7; _e.ebspr = 2; _e.ebcol = 2;
    _e.weapon = 3; _e.firedir = 0; _e.bspeed = 7; _e.cooldown = 10; _e.pspeed = 2;
    _e.border = 6; _e.bg = 6;
    sfx_apply_preset(_p.sfx[1], 1);
    sfx_apply_preset(_p.sfx[2], 2);
    var _cloud = tpl_tile(_p, "Clouds", "dirt", 14, 0, 0);
    var _isle = tpl_tile(_p, "Island", "ground", 14, 0, 0);
    var _diver = tpl_enemy(_p, "Diver", 3, 13, 1, 2, 4, 1, 10, 0, 60, 4);
    var _weave = tpl_enemy(_p, "Weaver", 10, 4, 2, 1, 4, 1, 20, 0, 60, 4);
    var _gun = tpl_enemy(_p, "Gunship", 4, 7, 1, 1, 4, 3, 40, 2, 55, 4);
    var _lv = level_new("Skyway", 20, 150);
    for (var _iy = 0; _iy < 150; _iy++)
    {
        for (var _ix = 0; _ix < 20; _ix++)
        {
            if (tpl_hash(_ix, _iy, 9) < 0.07) { tpl_set(_lv, _ix, _iy, _cloud); }
            if (abs(_ix - 10 - sin(_iy / 6) * 6) < 1.5 && (_iy mod 20) < 6) { tpl_set(_lv, _ix, _iy, _isle); }
        }
    }
    _lv.px = 9; _lv.py = 147;
    for (var s = 136; s > 6; s -= 8)
    {
        var _k = (s div 8) mod 3;
        if (_k == 0) { tpl_spawn(_lv, 3 + (s mod 13), s - 9, _diver, 4, 12, 255); }
        if (_k == 1) { tpl_spawn(_lv, 8, s - 9, _weave, 5, 16, 255); }
        if (_k == 2) { tpl_spawn(_lv, 2 + ((s * 7) mod 15), s - 9, _gun, 1, 1, 255); }
    }
    array_push(_p.levels, _lv);
    _p.win_text = "MISSION COMPLETE! - PRESS FIRE";
    return _p;
}

function tpl_jump_quest(_flip)
{
    var _name = "Jump Quest";
    var _scroll = SCROLL_H;
    if (_flip)
    {
        _name = "Castle Rooms";
        _scroll = SCROLL_FLIP;
    }
    var _p = tpl_base(_name, KIND_PLAT, _scroll);
    var _e = _p.eng;
    _e.auto = false; _e.wtop = 2; _e.wrows = 16; _e.fullcol = true;
    if (!_flip) { _e.fullcol = false; _e.wincol = 13; }
    _e.pspr = 8; _e.pcol = 6; _e.weapon = 0; _e.pspeed = 2; _e.jumpv = 7; _e.grav = 1; _e.maxfall = 5;
    _e.border = 14; _e.bg = 0; _e.smc1 = 10; _e.smc2 = 9;
    if (_flip) { _e.border = 11; _e.bg = 0; }
    var _brick = tpl_tile(_p, "Brick", "brick", 2, TA_SOLID, 0);
    var _ground = tpl_tile(_p, "Ground", "ground", 5, TA_SOLID, 0);
    var _plat = tpl_tile(_p, "Ledge", "platform", 12, TA_ONEWAY, 0);
    var _ladder = tpl_tile(_p, "Ladder", "ladder", 8, TA_LADDER, 0);
    var _coin = tpl_tile(_p, "Coin", "coin", 7, TA_COLLECT, 5);
    var _spike = tpl_tile(_p, "Spikes", "spikes", 15, TA_DEADLY, 0);
    var _door = tpl_tile(_p, "Exit door", "exit", 13, TA_EXIT, 0);
    var _walker = tpl_enemy(_p, "Walker", 9, 8, 5, 1, 6, 1, 10, 0, 60, 6);
    var _bat = tpl_enemy(_p, "Bat", 10, 4, 2, 1, 6, 1, 20, 0, 60, 6);
    var _w = 80;
    if (_flip) { _w = 60; }
    var _lv = level_new("Level 1", _w, 8);
    tpl_fill(_lv, 0, 7, _w - 1, 7, _ground);
    tpl_fill(_lv, 0, 0, 0, 7, _brick);
    tpl_fill(_lv, _w - 1, 0, _w - 1, 7, _brick);
    for (var _ix = 10; _ix < _w - 8; _ix += 11)
    {
        var _k = (_ix div 11) mod 4;
        tpl_set(_lv, _ix, 7, _spike);
        tpl_set(_lv, _ix + 1, 7, _spike);
        tpl_fill(_lv, _ix - 2, 4, _ix + 3, 4, _plat);
        tpl_fill(_lv, _ix - 1, 3, _ix + 2, 3, _coin);
        if (_k == 1)
        {
            tpl_fill(_lv, _ix + 5, 2, _ix + 8, 2, _brick);
            tpl_fill(_lv, _ix + 7, 3, _ix + 7, 6, _ladder);
            tpl_set(_lv, _ix + 6, 1, _coin);
            tpl_set(_lv, _ix + 7, 1, _coin);
        }
        if (_k == 2) { tpl_fill(_lv, _ix + 5, 5, _ix + 7, 6, _brick); }
        if (_k == 3) { tpl_fill(_lv, _ix + 4, 1, _ix + 6, 1, _coin); }
        tpl_spawn(_lv, _ix + 6, 6, _walker, 1, 1, 255);
        if (_k mod 2 == 0) { tpl_spawn(_lv, _ix + 8, 2, _bat, 2, 40, 255); }
    }
    tpl_fill(_lv, _w - 4, 5, _w - 3, 6, _door);
    _lv.px = 3; _lv.py = 6;
    array_push(_p.levels, _lv);
    _p.win_text = "QUEST COMPLETE! - PRESS FIRE";
    return _p;
}

function tpl_rock_digger()
{
    var _p = tpl_base("Rock Digger", KIND_CAVE, SCROLL_8);
    var _e = _p.eng;
    _e.auto = false; _e.wtop = 2; _e.wrows = 14; _e.fullcol = true; _e.weapon = 0;
    _e.pspr = 11; _e.pcol = 5; _e.border = 0; _e.bg = 0; _e.smc1 = 9; _e.smc2 = 1; _e.hudcol = 7;
    _p.sfx[0].name = "Diamond"; sfx_apply_preset(_p.sfx[0], 0);
    var _dirt = tpl_tile(_p, "Dirt", "dirt", 8, TA_DIG, 0);
    var _wall = tpl_tile(_p, "Brick wall", "brick", 12, TA_SOLID, 0);
    var _steel = tpl_tile(_p, "Steel", "steel", 15, TA_SOLID, 0);
    var _rock = tpl_tile(_p, "Boulder", "boulder", 15, TA_FALLS, 0);
    var _gem = tpl_tile(_p, "Diamond", "diamond", 3, TA_FALLS | TA_COLLECT, 10);
    var _exit = tpl_tile(_p, "Exit", "exit", 13, TA_EXIT, 0);
    var _fly = tpl_enemy(_p, "Firefly", 12, 8, 6, 1, 6, 1, 25, 0, 60, 6);
    var _lv = level_new("Cave A", 40, 22);
    tpl_fill(_lv, 0, 0, 39, 21, _dirt);
    for (var _iy = 0; _iy < 22; _iy++)
    {
        for (var _ix = 0; _ix < 40; _ix++)
        {
            var _r = tpl_hash(_ix, _iy, 21);
            if (_r < 0.12) { tpl_set(_lv, _ix, _iy, _rock); }
            else
            {
                if (_r < 0.17) { tpl_set(_lv, _ix, _iy, _gem); }
                else
                {
                    if (_r < 0.21) { tpl_set(_lv, _ix, _iy, 0); }
                }
            }
        }
    }
    tpl_fill(_lv, 6, 7, 22, 7, _wall);
    tpl_fill(_lv, 18, 14, 34, 14, _wall);
    tpl_fill(_lv, 26, 3, 26, 10, _wall);
    // firefly pockets
    tpl_fill(_lv, 9, 10, 13, 12, 0);
    tpl_fill(_lv, 29, 17, 33, 19, 0);
    tpl_spawn(_lv, 11, 11, _fly, 1, 1, 255);
    tpl_spawn(_lv, 31, 18, _fly, 1, 1, 255);
    // border
    tpl_fill(_lv, 0, 0, 39, 0, _steel);
    tpl_fill(_lv, 0, 21, 39, 21, _steel);
    tpl_fill(_lv, 0, 0, 0, 21, _steel);
    tpl_fill(_lv, 39, 0, 39, 21, _steel);
    tpl_fill(_lv, 2, 2, 4, 3, 0);
    tpl_set(_lv, 3, 2, 0);
    tpl_set(_lv, 37, 19, _exit);
    _lv.px = 3; _lv.py = 2;
    _lv.need = 12;
    array_push(_p.levels, _lv);
    _p.over_text = "CRUSHED! - PRESS FIRE";
    _p.win_text = "ALL CAVES CLEARED! - PRESS FIRE";
    return _p;
}

function tpl_maze_raider()
{
    var _p = tpl_base("Maze Raider", KIND_TOP, SCROLL_8);
    var _e = _p.eng;
    _e.auto = false; _e.wtop = 2; _e.wrows = 16; _e.fullcol = false; _e.wincol = 9;
    _e.pspr = 13; _e.pcol = 9; _e.bspr = 15; _e.bcol = 1; _e.weapon = 1; _e.firedir = 2; _e.bspeed = 5; _e.cooldown = 14;
    _e.border = 11; _e.bg = 0; _e.smc1 = 10; _e.smc2 = 1;
    var _wall = tpl_tile(_p, "Wall", "wall", 9, TA_SOLID, 0);
    var _floor = tpl_tile(_p, "Floor", "floor", 11, 0, 0);
    var _gold = tpl_tile(_p, "Treasure", "treasure", 7, TA_COLLECT, 20);
    var _lava = tpl_tile(_p, "Lava", "lava", 2, TA_DEADLY, 0);
    var _exit = tpl_tile(_p, "Stairs", "exit", 13, TA_EXIT, 0);
    var _ghost = tpl_enemy(_p, "Ghost", 14, 4, 3, 1, 0, 2, 30, 0, 60, 0);
    var _crawl = tpl_enemy(_p, "Crawler", 12, 5, 6, 1, 2, 1, 15, 0, 60, 0);
    var _lv = level_new("Dungeon", 48, 30);
    tpl_fill(_lv, 0, 0, 47, 29, _floor);
    for (var _iy = 0; _iy < 30; _iy++)
    {
        for (var _ix = 0; _ix < 48; _ix++)
        {
            if (_ix == 0 || _iy == 0 || _ix == 47 || _iy == 29) { tpl_set(_lv, _ix, _iy, _wall); }
            else
            {
                if ((_ix mod 6 == 0 || _iy mod 6 == 0) && tpl_hash(_ix div 6, _iy div 6, (_ix mod 6 == 0)) < 0.55 && (_ix mod 6) + (_iy mod 6) != 3)
                {
                    if (!((_ix mod 6 == 0) && (_iy mod 6 == 3)) && !((_iy mod 6 == 0) && (_ix mod 6 == 3))) { tpl_set(_lv, _ix, _iy, _wall); }
                }
            }
        }
    }
    var _placed = 0;
    for (var g = 0; g < 200 && _placed < 14; g++)
    {
        var _gx = 1 + floor(tpl_hash(g, 1, 33) * 46);
        var _gy = 1 + floor(tpl_hash(g, 2, 33) * 28);
        if (_lv.map[_gy * 48 + _gx] == _floor)
        {
            tpl_set(_lv, _gx, _gy, _gold);
            _placed += 1;
        }
    }
    tpl_fill(_lv, 20, 14, 22, 15, _lava);
    tpl_fill(_lv, 1, 1, 3, 3, _floor);
    tpl_set(_lv, 45, 27, _exit);
    _lv.px = 2; _lv.py = 2;
    _lv.need = 10;
    for (var s = 0; s < 8; s++)
    {
        var _sx = 9 + (s mod 4) * 10;
        var _sy = 4 + (s div 4) * 14;
        tpl_set(_lv, _sx, _sy, _floor);
        var _t = _ghost;
        if (s mod 2 == 1) { _t = _crawl; }
        tpl_spawn(_lv, _sx, _sy, _t, 2, 90, 255);
    }
    array_push(_p.levels, _lv);
    _p.win_text = "ESCAPED WITH THE GOLD! - PRESS FIRE";
    return _p;
}
