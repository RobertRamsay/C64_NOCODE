/// C64 ENGINE - the custom HUD (UI page, ported from ADAM's UI page): a panel strip at
/// the top or bottom of the screen (1 to 6 text rows), drawn with a 9-slice frame of 9 characters
/// (corners, edges and a fill), a font style (or a font drawn on the page) and the fields: text,
/// score, lives, the level goal and the level, each with its own place and colour.
///
/// The C64 way: the panel is made of characters, so each 8 x 8 square has one colour on the
/// screen's background colour (the frame editor keeps to that), and a letter replaces the frame
/// character it sits on. A single-screen game gets its own copy of the character set (2 KB) when the
/// frame or the font needs it; a map game puts the frame into 9 characters its tiles leave free.

#macro HUD_ROWS_MAX 6
#macro HUD_LABEL_MAX 19
#macro HUD_FIELDS_MAX 12

function hud_font_styles()
{
    return ["C64", "Bold", "Thin", "Italic", "Bold italic", "Custom (drawn here)"];
}

function hud_frame_styles()
{
    return ["Line", "Double line", "Rounded", "Bevel", "Rivets", "Neon", "Bricks"];
}

function hud_field_types()
{
    return ["Text", "Score", "Lives", "Goal", "Level", "Tile carried", "Tool"];
}

/// Field types this kind of game has (Goal and Level belong to map games)
function hud_type_count(_p)
{
    return (_p.game_type == 1) ? 7 : 3;
}

/// The custom HUD of a new project: off (the standard HUD is used)
function hud_new()
{
    return {
        on : false,                         // use the custom HUD
        bottom : false,                     // the panel at the bottom (single-screen games)
        rows : 3,                           // text rows, 8 lines each
        frame_on : true,                    // draw the 9-slice frame
        style : "Line",                     // the preset the frame came from ("Custom" once drawn on)
        frame : array_create(576, 0),       // 24 x 24 pixels, 1 = set
        fcols : array_create(9, 1),         // one colour for each of the 9 characters
        font_style : 0,                     // hud_font_styles()
        font : [],                          // 64 x 8 bytes when font_style is Custom
        fields : []                         // hud_field_new()
    };
}

function hud_field_new(_type)
{
    return { type : _type, label : "", col : 1, row : 0, colour : 1, digits : 4 };
}

/// The custom HUD of a loaded project, made safe
function hud_from_loaded(_raw)
{
    var _u = hud_new();
    if (!is_struct(_raw)) { return _u; }
    struct_overlay(_u, _raw);
    if (!is_bool(_u.on)) { _u.on = (is_numeric(_u.on) && _u.on != 0); }
    if (!is_bool(_u.bottom)) { _u.bottom = (is_numeric(_u.bottom) && _u.bottom != 0); }
    if (!is_bool(_u.frame_on)) { _u.frame_on = (is_numeric(_u.frame_on) && _u.frame_on != 0); }
    if (!is_numeric(_u.rows)) { _u.rows = 3; }
    _u.rows = clamp(floor(_u.rows), 1, HUD_ROWS_MAX);
    if (!is_string(_u.style)) { _u.style = "Line"; }
    if (!is_array(_u.frame) || array_length(_u.frame) != 576) { _u.frame = array_create(576, 0); }
    for (var i = 0; i < 576; i++) { _u.frame[i] = (is_numeric(_u.frame[i]) && _u.frame[i] != 0) ? 1 : 0; }
    if (!is_array(_u.fcols) || array_length(_u.fcols) != 9) { _u.fcols = array_create(9, 1); }
    for (var c = 0; c < 9; c++) { _u.fcols[c] = is_numeric(_u.fcols[c]) ? clamp(floor(_u.fcols[c]), 0, 15) : 1; }
    if (!is_numeric(_u.font_style)) { _u.font_style = 0; }
    _u.font_style = clamp(floor(_u.font_style), 0, 5);
    if (!is_array(_u.font) || array_length(_u.font) != 512) { _u.font = []; }
    for (var b = 0; b < array_length(_u.font); b++) { _u.font[b] = is_numeric(_u.font[b]) ? (floor(_u.font[b]) & 255) : 0; }
    if (_u.font_style == 5 && array_length(_u.font) != 512) { _u.font_style = 0; }
    var _fl = [];
    if (is_array(_u.fields))
    {
        for (var f = 0; f < min(HUD_FIELDS_MAX, array_length(_u.fields)); f++)
        {
            var _src = _u.fields[f];
            if (!is_struct(_src)) { continue; }
            var _fd = struct_overlay(hud_field_new(0), _src);
            _fd.type = is_numeric(_fd.type) ? clamp(floor(_fd.type), 0, 6) : 0;
            if (!is_string(_fd.label)) { _fd.label = ""; }
            _fd.label = string_upper(string_copy(_fd.label, 1, HUD_LABEL_MAX));
            _fd.col = is_numeric(_fd.col) ? clamp(floor(_fd.col), 0, 39) : 0;
            _fd.row = is_numeric(_fd.row) ? clamp(floor(_fd.row), 0, HUD_ROWS_MAX - 1) : 0;
            _fd.colour = is_numeric(_fd.colour) ? clamp(floor(_fd.colour), 0, 15) : 1;
            _fd.digits = is_numeric(_fd.digits) ? clamp(floor(_fd.digits), 1, 6) : 4;
            array_push(_fl, _fd);
        }
    }
    _u.fields = _fl;
    return _u;
}

/// After loading (or making) a project
function hud_project_fix(_p)
{
    _p.hud = hud_from_loaded(_p[$ "hud"]);
}

/// Does any level have a goal counter?
function eng_need_any(_p)
{
    for (var i = 0; i < array_length(_p.levels); i++)
    {
        if (_p.levels[i].need > 0) { return true; }
    }
    return false;
}

/// The map game's window top row as built. The raster split for the window comes 4 lines
/// before the row above it ends, so only the rows above that are clean: the window starts
/// below a custom HUD's panel, and below the standard HUD's second row when it needs one.
function eng_wtop(_p)
{
    var _w = clamp(_p.eng.wtop, 2, 4);
    if (_p.hud.on) { _w = max(_w, min(4, clamp(_p.hud.rows, 1, 3) + 1)); }
    else if (tile_dig_on(_p) && eng_need_any(_p)) { _w = max(_w, 3); }
    return _w;
}

/// How many rows the panel can have: a map game's panel sits above the scrolling window (up to 3)
function hud_rows_max(_p)
{
    if (_p.game_type == 1) { return 3; }
    return HUD_ROWS_MAX;
}

/// The panel's rows as they will be built (a map game's are capped by its window)
function hud_rows(_p, _u)
{
    return clamp(_u.rows, 1, hud_rows_max(_p));
}

/// First text row of the panel on the screen
function hud_row0(_p, _u)
{
    if (_p.game_type == 0 && _u.bottom) { return 25 - hud_rows(_p, _u); }
    return 0;
}

// ---------------------------------------------------------------------------
// The frame presets: a pixel is set or not, and each of the 9 characters has a colour
// ---------------------------------------------------------------------------

/// Is pixel (_px, _py) of a preset's 24 x 24 frame set?
function hud_frame_pixel(_style, _px, _py)
{
    var _d = min(_px, _py, 23 - _px, 23 - _py);
    switch (_style)
    {
        case "Line": return (_d == 3);
        case "Double line": return (_d == 1 || _d == 4);
        case "Rounded":
            if ((_px < 8 || _px > 15) && (_py < 8 || _py > 15))
            {
                var _cx = (_px < 8) ? 8 : 15;
                var _cy = (_py < 8) ? 8 : 15;
                var _r = point_distance(_px, _py, _cx, _cy);
                return (_r >= 4.6 && _r < 5.8);
            }
            return (_d == 3);
        case "Bevel": return (_d <= 2);
        case "Rivets":
            if (_d > 5) { return false; }
            // a rivet in each corner: a ring of 4 x 4 with a dot
            if ((_px < 8 || _px > 15) && (_py < 8 || _py > 15))
            {
                var _rx = (_px < 8) ? 3 : 20;
                var _ry = (_py < 8) ? 3 : 20;
                var _q = max(abs(_px - _rx), abs(_py - _ry));
                if (_q == 1 && !(abs(_px - _rx) == 1 && abs(_py - _ry) == 1)) { return false; }
            }
            return (_d != 5) || ((_px + _py) mod 2 == 0);
        case "Neon": return (_d == 2 || _d == 3);
        case "Bricks":
            var _off = ((_py div 4) mod 2 == 1) ? 4 : 0;
            return !(_py mod 4 == 3 || (_px + _off) mod 8 == 7);
    }
    return false;
}

/// The 9 characters' colours of a preset: [top-left, top, top-right, left, fill, right, ...]
function hud_frame_colours(_style)
{
    switch (_style)
    {
        case "Line":        return [15, 15, 15, 15, 15, 15, 15, 15, 15];
        case "Double line": return [14, 14, 14, 14, 14, 14, 14, 14, 14];
        case "Rounded":     return [7, 7, 7, 7, 7, 7, 7, 7, 7];
        case "Bevel":       return [1, 1, 15, 1, 12, 11, 15, 11, 11];
        case "Rivets":      return [15, 12, 15, 12, 12, 12, 15, 12, 15];
        case "Neon":        return [4, 3, 4, 3, 3, 3, 4, 3, 4];
        case "Bricks":      return [2, 2, 2, 2, 2, 2, 2, 2, 2];
    }
    return array_create(9, 1);
}

/// A frame preset: sets the pixels and the colours (the fill stays empty so letters read well)
function hud_apply_preset(_u, _style)
{
    _u.style = _style;
    for (var _py = 0; _py < 24; _py++)
    {
        for (var _px = 0; _px < 24; _px++)
        {
            var _in = (_px >= 8 && _px < 16 && _py >= 8 && _py < 16);
            _u.frame[_py * 24 + _px] = (!_in && hud_frame_pixel(_style, _px, _py)) ? 1 : 0;
        }
    }
    _u.fcols = hud_frame_colours(_style);
}

/// The 8 bytes of one of the 9 frame characters (0 = top-left ... 8 = bottom-right)
function hud_slice_bytes(_u, _s)
{
    var _out = array_create(8, 0);
    var _ox = (_s mod 3) * 8;
    var _oy = (_s div 3) * 8;
    for (var r = 0; r < 8; r++)
    {
        var _v = 0;
        for (var b = 0; b < 8; b++)
        {
            if (_u.frame[(_oy + r) * 24 + _ox + b] != 0) { _v |= (0x80 >> b); }
        }
        _out[r] = _v;
    }
    return _out;
}

// ---------------------------------------------------------------------------
// The font and the character set
// ---------------------------------------------------------------------------

/// The letters before any style: the C64's own (single screen) or the Charset page's (map game)
function hud_font_base(_p)
{
    var _out = array_create(512, 0);
    var _src = (_p.game_type == 1) ? _p.charset : global.chargen_rom;
    if (is_array(_src) && array_length(_src) >= 512) { array_copy(_out, 0, _src, 0, 512); }
    return _out;
}

/// The HUD's font: 64 characters (screen codes 0..63: @, A-Z, signs and digits) x 8 rows
function hud_font_bytes(_p, _u)
{
    var _st = _u.font_style;
    if (_st == 5 && array_length(_u.font) == 512) { return _u.font; }
    var _out = hud_font_base(_p);
    if (_st == 0) { return _out; }
    var _base = array_create(512, 0);
    array_copy(_base, 0, _out, 0, 512);
    for (var c = 0; c < 64; c++)
    {
        for (var i = 0; i < 8; i++)
        {
            var _r = _base[c * 8 + i];
            if (_st == 1 || _st == 4) { _r = (_r | (_r >> 1)) & 255; }
            // thin: the right-hand pixel of each run goes (2-wide strokes become 1, long bars stay)
            if (_st == 2) { _r = _r & ~(_r & (_r >> 1) & ~(_r << 1)) & 255; }
            if (_st == 3 || _st == 4)
            {
                if (i < 3) { _r = _r >> 1; }
                else if (i >= 5) { _r = (_r << 1) & 255; }
            }
            _out[c * 8 + i] = _r;
        }
    }
    return _out;
}

/// Character codes the game doesn't use, best first (for the frame's 9 characters)
function hud_free_codes(_p)
{
    var _used = array_create(256, false);
    for (var i = 0; i < 64; i++) { _used[i] = true; }
    if (_p.game_type == 1)
    {
        for (var t = 0; t < min(64, array_length(_p.tiles)); t++)
        {
            for (var k = 0; k < 4; k++) { _used[clamp(_p.tiles[t].c[k], 0, 255)] = true; }
        }
    }
    else
    {
        for (var s = 0; s < 1000; s++) { _used[clamp(_p.chars[s], 0, 255)] = true; }
    }
    _used[160] = true;                     // the reversed space: keep it for solid blocks
    var _out = [];
    for (var c = 255; c >= 64; c--)
    {
        if (!_used[c]) { array_push(_out, c); }
    }
    return _out;
}

/// What the custom HUD needs of the character set:
/// { need : a charset of its own (single screen), codes : the 9 frame characters (or []), bytes : 2048, missing : not enough free characters }
function hud_charset(_p)
{
    var _u = _p.hud;
    var _out = { need : false, codes : [], bytes : [], missing : false };
    var _b = array_create(2048, 0);
    var _src = (_p.game_type == 1) ? _p.charset : global.chargen_rom;
    if (is_array(_src) && array_length(_src) == 2048) { array_copy(_b, 0, _src, 0, 2048); }
    _out.bytes = _b;
    if (!_u.on) { return _out; }
    if (_u.font_style != 0)
    {
        var _f = hud_font_bytes(_p, _u);
        array_copy(_b, 0, _f, 0, 512);
        _out.need = true;
    }
    if (_u.frame_on)
    {
        var _free = hud_free_codes(_p);
        if (array_length(_free) < 9) { _out.missing = true; }
        else
        {
            for (var s = 0; s < 9; s++)
            {
                var _code = _free[s];
                array_push(_out.codes, _code);
                var _sb = hud_slice_bytes(_u, s);
                for (var r = 0; r < 8; r++) { _b[_code * 8 + r] = _sb[r]; }
            }
            _out.need = true;
        }
    }
    if (_p.game_type == 1) { _out.need = false; }   // a map game always has its own (the Charset page's)
    return _out;
}

// ---------------------------------------------------------------------------
// The panel: what each of its cells shows
// ---------------------------------------------------------------------------

/// Is this field a number the game keeps up to date?
function hud_field_live(_f)
{
    return (_f.type >= 1);
}

/// The digits a number field really shows (a single-screen score has 4, a map game's 6)
function hud_field_digits(_p, _f)
{
    switch (_f.type)
    {
        case 1: return _f.digits;
        case 2: return _f.digits;
        case 4: return clamp(_f.digits, 1, 2);
    }
    return 0;
}

/// The value part of a field: sample numbers for the preview, zeros for the game (it fills them in)
function hud_field_value(_p, _f, _sample)
{
    var _d = hud_field_digits(_p, _f);
    switch (_f.type)
    {
        case 1:
            var _sv = _sample ? 1230 : 0;
            return string_replace_all(string_format(_sv mod power(10, _d), _d, 0), " ", "0");
        case 2:
            var _lv = _sample ? clamp(_p.lives, 0, 9) : 0;
            if (_p.game_type == 1) { _lv = _sample ? clamp(_p.eng.lives, 1, 9) : 0; }
            return string_replace_all(string_format(_lv, _d, 0), " ", "0");
        case 3:
            if (!_sample) { return "00/00"; }
            var _need = 12;
            if (_p.game_type == 1 && array_length(_p.levels) > 0 && _p.levels[0].need > 0) { _need = clamp(_p.levels[0].need, 1, 99); }
            return "05/" + string_replace_all(string_format(_need, 2, 0), " ", "0");
        case 4:
            return string_replace_all(string_format(1, _d, 0), " ", "0");
        case 5:
            // the tile carried (Tiles page: Dig and place): its first 4 letters and how many
            if (!_sample) { return "     00"; }
            var _tn = (array_length(_p.tiles) > 1) ? _p.tiles[1].name : "DIRT";
            return string_upper(string_copy(_tn + "    ", 1, 4)) + " 03";
        case 6:
            // the tool in use (Tiles page: Tools tab), 8 letters
            var _tl = (array_length(_p.eng.tools) > 0) ? _p.eng.tools[0].name : "";
            return string_upper(string_copy(_tl + "        ", 1, 8));
    }
    return "";
}

/// The whole text of a field
function hud_field_text(_p, _f, _sample)
{
    if (_f.type >= hud_type_count(_p)) { return _f.label; }
    return _f.label + hud_field_value(_p, _f, _sample);
}

/// The panel's cells: { rows, row0, scr : codes (-1 = left as it is), col : colours, live : [{ f, pos }] }
/// _codes: the frame's 9 characters ([] = no frame)
function hud_cells(_p, _codes, _sample)
{
    var _u = _p.hud;
    var _rows = hud_rows(_p, _u);
    var _n = _rows * 40;
    var _scr = array_create(_n, -1);
    var _col = array_create(_n, 0);
    if (_p.game_type == 1)
    {
        // a map game's HUD rows are cleared first: spaces
        for (var i = 0; i < _n; i++) { _scr[i] = 32; _col[i] = 1; }
    }
    if (_u.frame_on && array_length(_codes) == 9)
    {
        for (var r = 0; r < _rows; r++)
        {
            // 1 row: the sides only; 2 rows: the screen's edge stands in for the frame's outer edge
            var _sr = 1;
            if (_rows >= 3) { _sr = (r == 0) ? 0 : ((r == _rows - 1) ? 2 : 1); }
            else if (_rows == 2)
            {
                if (hud_row0(_p, _u) == 0) { _sr = (r == 0) ? 1 : 2; }
                else { _sr = (r == 0) ? 0 : 1; }
            }
            for (var c = 0; c < 40; c++)
            {
                var _sc = (c == 0) ? 0 : ((c == 39) ? 2 : 1);
                var _s = _sr * 3 + _sc;
                _scr[r * 40 + c] = _codes[_s];
                _col[r * 40 + c] = _u.fcols[_s];
            }
        }
    }
    var _live = [];
    for (var f = 0; f < array_length(_u.fields); f++)
    {
        var _fd = _u.fields[f];
        if (_fd.row >= _rows) { continue; }
        var _t = string_upper(hud_field_text(_p, _fd, _sample));
        for (var k = 0; k < string_length(_t); k++)
        {
            var _cx = _fd.col + k;
            if (_cx >= 40) { break; }
            _scr[_fd.row * 40 + _cx] = scr_code_from_char(string_char_at(_t, k + 1)) & 63;
            _col[_fd.row * 40 + _cx] = _fd.colour;
        }
        if (_fd.type >= 1 && _fd.type < hud_type_count(_p)) { array_push(_live, { f : _fd, pos : _fd.row * 40 + _fd.col + string_length(_fd.label) }); }
    }
    return { rows : _rows, row0 : hud_row0(_p, _u), scr : _scr, col : _col, live : _live };
}

/// The row new text goes on: inside the frame (the middle row)
function hud_text_row(_p)
{
    var _rows = hud_rows(_p, _p.hud);
    if (_rows >= 3) { return 1; }
    if (_rows == 2 && hud_row0(_p, _p.hud) > 0) { return 1; }
    return 0;
}

/// Fields like the standard HUD
function hud_default_fields(_p)
{
    var _f = [];
    var _row = hud_text_row(_p);
    if (_p.game_type == 1)
    {
        var _hc = clamp(_p.eng.hudcol, 0, 15);
        var _s = hud_field_new(1);
        _s.label = "SCORE "; _s.col = 2; _s.row = _row; _s.colour = _hc; _s.digits = 6;
        array_push(_f, _s);
        var _l = hud_field_new(2);
        _l.label = "LIVES "; _l.col = 16; _l.row = _row; _l.colour = _hc; _l.digits = 1;
        array_push(_f, _l);
        var _need = false;
        for (var i = 0; i < array_length(_p.levels); i++)
        {
            if (_p.levels[i].need > 0) { _need = true; }
        }
        if (_need)
        {
            var _g = hud_field_new(3);
            _g.label = "GEMS "; _g.col = 25; _g.row = _row; _g.colour = 7;
            array_push(_f, _g);
        }
        else
        {
            var _v = hud_field_new(4);
            _v.label = "LEVEL "; _v.col = 29; _v.row = _row; _v.colour = 7; _v.digits = 1;
            array_push(_f, _v);
        }
        return _f;
    }
    var _hc2 = clamp(_p.hud_colour, 0, 15);
    if (_p.show_score)
    {
        var _s2 = hud_field_new(1);
        _s2.label = "SCORE "; _s2.col = 2; _s2.row = _row; _s2.colour = _hc2; _s2.digits = 4;
        array_push(_f, _s2);
    }
    if (_p.show_lives)
    {
        var _l2 = hud_field_new(2);
        _l2.label = "LIVES "; _l2.col = 30; _l2.row = _row; _l2.colour = _hc2; _l2.digits = 1;
        array_push(_f, _l2);
    }
    return _f;
}

/// Switches the custom HUD on, starting from fields like the standard HUD and a line frame
function hud_switch_on(_p)
{
    var _u = _p.hud;
    _u.on = true;
    var _blank = true;
    for (var i = 0; i < 576; i++)
    {
        if (_u.frame[i] != 0) { _blank = false; }
    }
    if (_blank) { hud_apply_preset(_u, _u.style); }
    _u.rows = clamp(_u.rows, 1, hud_rows_max(_p));
    if (array_length(_u.fields) == 0) { _u.fields = hud_default_fields(_p); }
}

/// Bytes the custom HUD adds to the game (roughly: the panel, its code and a character set)
function hud_bytes(_p)
{
    var _u = _p.hud;
    if (!_u.on) { return 0; }
    var _cs = hud_charset(_p);
    var _n = hud_rows(_p, _u) * 80 + 40 + array_length(_u.fields) * 30;
    if (_cs.need) { _n += 2048; }
    return _n;
}

// ---------------------------------------------------------------------------
// In the game
// ---------------------------------------------------------------------------

/// The code that writes number field _lv (at screen address _addr) - single-screen game
function hud_emit_live_single(L, _p, _lv, _addr)
{
    var _f = _lv.f;
    var _d = hud_field_digits(_p, _f);
    if (_f.type == 1)
    {
        // score_lo / score_hi: 4 BCD digits; more digits are zeros in front
        for (var i = 0; i < min(_d, 4); i++)
        {
            var _a = _addr + _d - 1 - i;
            array_push(L, " lda " + ((i < 2) ? "score_lo" : "score_hi"));
            if (i mod 2 == 1) { array_push(L, " lsr", " lsr", " lsr", " lsr"); }
            else { array_push(L, " and #15"); }
            array_push(L, " ora #48", " sta " + string(_a));
        }
    }
    if (_f.type == 2) { array_push(L, " lda lives", " ora #48", " sta " + string(_addr + _d - 1)); }
}

/// The custom HUD of a single-screen game: hud_panel (the panel, after draw_screen) and
/// draw_hud (the numbers, whenever they change). Returns false if the HUD is off.
function hud_emit_single(L, _p)
{
    var _u = _p.hud;
    if (!_u.on) { return false; }
    var _cs = hud_charset(_p);
    var _cells = hud_cells(_p, _cs.codes, false);
    var _n = _cells.rows * 40;
    var _base = 1024 + _cells.row0 * 40;
    array_push(L, "hud_panel:");
    var _full = true;
    for (var i = 0; i < _n; i++)
    {
        if (_cells.scr[i] < 0) { _full = false; }
    }
    if (_full)
    {
        array_push(L, " ldx #0", "hudp1:", " lda hud_pscr,x", " sta " + string(_base) + ",x", " lda hud_pcol,x", " sta " + string(_base + 54272) + ",x", " inx", " cpx #" + string(_n), " bne hudp1");
    }
    else
    {
        for (var k = 0; k < _n; k++)
        {
            if (_cells.scr[k] < 0) { continue; }
            array_push(L, " lda #" + string(_cells.scr[k]), " sta " + string(_base + k), " lda #" + string(_cells.col[k]), " sta " + string(_base + k + 54272));
        }
    }
    array_push(L, "draw_hud:");
    for (var v = 0; v < array_length(_cells.live); v++) { hud_emit_live_single(L, _p, _cells.live[v], _base + _cells.live[v].pos); }
    array_push(L, " rts");
    if (_full)
    {
        array_push(L, "hud_pscr:");
        eng_emit_bytes(L, _cells.scr);
        array_push(L, "hud_pcol:");
        eng_emit_bytes(L, _cells.col);
    }
    return true;
}

/// The character set a single-screen game copies in (only when the frame or the font needs one)
function hud_emit_chars_single(L, _p)
{
    var _cs = hud_charset(_p);
    if (!_cs.need) { return false; }
    array_push(L, " .align 2048", "hud_chars:");
    for (var cb = 0; cb < 2048; cb += 64) { array_push(L, " .byte " + cg_join_bytes(_cs.bytes, cb, 64)); }
    array_push(L, "hud_chars_end:");
    return true;
}

/// set_chars: points the VIC-II at the game's characters (the ROM's, or the HUD's own copy)
function hud_emit_set_chars(L, _p)
{
    array_push(L, "set_chars:");
    if (hud_charset(_p).need) { array_push(L, " lda #>hud_chars", " lsr", " lsr", " and #$0e", " ora #$10", " sta $d018", " rts"); }
    else { array_push(L, " lda #$15", " sta $d018", " rts"); }
}

/// The map engine's HUD routines (engine.asm leaves its own out when HUD_STD is 0)
function hud_emit_map(L, _p)
{
    var _u = _p.hud;
    var _cs = hud_charset(_p);
    var _cells = hud_cells(_p, _cs.codes, false);
    var _n = _cells.rows * 40;
    array_push(L, "hud_draw_static:", " ldx #0", " lda #32", "hud_c1:", " sta SCR,x", " sta SCR+250,x", " sta SCR+500,x", " sta SCR+750,x", " inx", " cpx #250", " bne hud_c1");
    array_push(L, " ldx #0", "hud_c2:", " lda hud_pscr,x", " sta SCR,x", " inx", " cpx #" + string(_n), " bne hud_c2", " rts");
    array_push(L, "hud_draw_static_col:", " ldx #0", "hud_c3:", " lda hud_pcol,x", " sta COLR,x", " inx", " cpx #" + string(_n), " bne hud_c3", " rts");
    array_push(L, "hud_update:");
    for (var v = 0; v < array_length(_cells.live); v++)
    {
        var _lv = _cells.live[v];
        var _f = _lv.f;
        var _a = "SCR+" + string(_lv.pos);
        var _d = hud_field_digits(_p, _f);
        switch (_f.type)
        {
            case 1:
                // score: 3 BCD bytes, the high one at score+2
                for (var i = 0; i < _d; i++)
                {
                    array_push(L, " lda score+" + string(i div 2));
                    if (i mod 2 == 1) { array_push(L, " lsr", " lsr", " lsr", " lsr"); }
                    else { array_push(L, " and #15"); }
                    array_push(L, " ora #48", " sta SCR+" + string(_lv.pos + _d - 1 - i));
                }
                break;
            case 2:
                array_push(L, " lda lives", " ora #48", " sta SCR+" + string(_lv.pos + _d - 1));
                break;
            case 3:
                array_push(L, " lda need", " beq hud_g" + string(v), " lda need_got", " jsr bin2dec", " stx " + _a, " sta SCR+" + string(_lv.pos + 1));
                array_push(L, " lda need", " jsr bin2dec", " stx SCR+" + string(_lv.pos + 3), " sta SCR+" + string(_lv.pos + 4), "hud_g" + string(v) + ":");
                break;
            case 5:
                array_push(L, " lda carry_n", " beq hud_n" + string(v), " lda carry_t", " asl", " asl", " tax");
                for (var c5 = 0; c5 < 4; c5++) { array_push(L, " lda tname+" + string(c5) + ",x", " sta SCR+" + string(_lv.pos + c5)); }
                array_push(L, " lda carry_n", " jsr bin2dec", " stx SCR+" + string(_lv.pos + 5), " sta SCR+" + string(_lv.pos + 6), " jmp hud_m" + string(v));
                array_push(L, "hud_n" + string(v) + ":", " lda #32");
                for (var c6 = 0; c6 < 4; c6++) { array_push(L, " sta SCR+" + string(_lv.pos + c6)); }
                array_push(L, "hud_m" + string(v) + ":");
                break;
            case 6:
                if (tools_on(_p))
                {
                    array_push(L, " lda tool_cur", " asl", " asl", " asl", " tax");
                    for (var c7 = 0; c7 < 8; c7++) { array_push(L, " lda tl_name+" + string(c7) + ",x", " sta SCR+" + string(_lv.pos + c7)); }
                }
                break;
            case 4:
                array_push(L, " lda level", " clc", " adc #1", " jsr bin2dec");
                if (_d == 2) { array_push(L, " stx " + _a, " sta SCR+" + string(_lv.pos + 1)); }
                else { array_push(L, " sta " + _a); }
                break;
        }
    }
    array_push(L, " rts");
    array_push(L, "hud_pscr:");
    eng_emit_bytes(L, _cells.scr);
    array_push(L, "hud_pcol:");
    eng_emit_bytes(L, _cells.col);
}

/// Warnings for the Build page
function hud_warnings(_p)
{
    var _w = [];
    var _u = _p.hud;
    if (!_u.on) { return _w; }
    var _cs = hud_charset(_p);
    if (_cs.missing) { array_push(_w, "Custom HUD: no frame - the game needs 9 characters it doesn't use (it uses nearly all 256)."); }
    for (var f = 0; f < array_length(_u.fields); f++)
    {
        var _fd = _u.fields[f];
        if (_fd.type >= hud_type_count(_p)) { array_push(_w, "Custom HUD: a " + hud_field_types()[_fd.type] + " field only works in a map game - it shows its label only."); }
        if (_fd.type == 6 && !tools_on(_p)) { array_push(_w, "Custom HUD: the Tool field needs Dig and place and at least one tool (Tiles page: Tools)."); }
        if (_fd.type == 5 && !tile_dig_on(_p)) { array_push(_w, "Custom HUD: the Tile carried field shows nothing until Dig and place is on (Tiles page)."); }
        if (_fd.row >= hud_rows(_p, _u)) { array_push(_w, "Custom HUD: a field is on row " + string(_fd.row) + ", below the panel - it isn't shown."); }
    }
    if (_p.game_type == 0)
    {
        for (var g = 0; g < array_length(_u.fields); g++)
        {
            if (_u.fields[g].type == 1 && _u.fields[g].digits > 4) { array_push(_w, "Custom HUD: a single-screen score goes up to 9999 - the extra digits stay 0."); break; }
        }
    }
    return _w;
}

// ---------------------------------------------------------------------------
// The preview (UI page)
// ---------------------------------------------------------------------------

/// A glyph sheet of the game's character set with the HUD's font and frame (rebuilt on change)
function hud_sheet_get()
{
    var _cs = hud_charset(proj);
    var _key = string(proj.game_type) + "|" + json_stringify(proj.hud.frame) + json_stringify(proj.hud.font) + string(proj.hud.font_style) + string(proj.hud.on) + string(proj.hud.frame_on) + json_stringify(_cs.codes);
    if (proj.game_type == 1) { _key += string(hud_sheet_tick); }
    if (_key != hud_sheet_key || !sprite_exists(hud_sheet))
    {
        if (sprite_exists(hud_sheet)) { sprite_delete(hud_sheet); }
        hud_sheet = glyph_sheet_sprite(_cs.bytes);
        hud_sheet_key = _key;
    }
    return hud_sheet;
}

function hud_gfx_free()
{
    if (sprite_exists(hud_sheet)) { sprite_delete(hud_sheet); }
    hud_sheet = -1;
    hud_sheet_key = "";
    if (surface_exists(hud_prev_surf)) { surface_free(hud_prev_surf); }
    hud_prev_surf = -1;
}

/// Draws the game screen with the HUD at (_x, _y), _sc screen pixels per C64 pixel
/// (drawn at 1:1 into a surface first, so no glyph bleeds into its neighbour when scaled)
function hud_preview_draw(_dx, _dy, _dsc)
{
    if (!surface_exists(hud_prev_surf)) { hud_prev_surf = surface_create(320, 200); }
    surface_set_target(hud_prev_surf);
    draw_clear_alpha(c_black, 1);
    hud_preview_render(0, 0, 1);
    surface_reset_target();
    gpu_set_texfilter(false);
    draw_surface_ext(hud_prev_surf, _dx, _dy, _dsc, _dsc, 0, c_white, 1);
    gpu_set_texfilter(true);
}

function hud_preview_render(_x, _y, _sc)
{
    var _p = proj;
    var _u = _p.hud;
    var _sheet = hud_sheet_get();
    gpu_set_texfilter(false);
    var _cs = 8 * _sc;
    var _bgc = (_p.game_type == 1) ? _p.eng.bg : _p.background;
    px_rect(_x, _y, 320 * _sc, 200 * _sc, c64col(_bgc));
    if (_p.game_type == 1)
    {
        // the map game: the first level in its window, as the game starts
        var _e = _p.eng;
        var _wtop = eng_wtop(_p);
        var _wrows = clamp(_e.wrows, 6, 24 - _wtop);
        if (array_length(_p.levels) > 0)
        {
            var _lv = _p.levels[0];
            for (var tr = 0; tr < ceil(_wrows / 2); tr++)
            {
                for (var tc = 0; tc < 20; tc++)
                {
                    if (tr >= _lv.h || tc >= _lv.w) { continue; }
                    var _t = _lv.map[tr * _lv.w + tc];
                    var _ty = _y + (_wtop + tr * 2) * _cs;
                    if ((tr * 2 + 1) >= _wrows) { draw_tile_img_part(_t, _x + tc * 2 * _cs, _ty, _sc); }
                    else { draw_tile_img(_t, _x + tc * 2 * _cs, _ty, 16 * _sc); }
                }
            }
        }
    }
    else
    {
        for (var r = 0; r < 25; r++)
        {
            for (var c = 0; c < 40; c++)
            {
                var _i = r * 40 + c;
                var _ch = _p.chars[_i];
                if (_ch == 32) { continue; }
                draw_sprite_part_ext(_sheet, 0, (_ch mod 16) * 8, (_ch div 16) * 8, 8, 8, _x + c * _cs, _y + r * _cs, _sc, _sc, c64col(_p.cols[_i]), 1);
            }
        }
    }
    if (_u.on)
    {
        var _chs = hud_charset(_p);
        var _cells = hud_cells(_p, _chs.codes, true);
        for (var k = 0; k < _cells.rows * 40; k++)
        {
            var _code = _cells.scr[k];
            if (_code < 0) { continue; }
            var _px = _x + (k mod 40) * _cs;
            var _py = _y + (_cells.row0 + k div 40) * _cs;
            px_rect(_px, _py, _cs, _cs, c64col(_bgc));
            draw_sprite_part_ext(_sheet, 0, (_code mod 16) * 8, (_code div 16) * 8, 8, 8, _px, _py, _sc, _sc, c64col(_cells.col[k]), 1);
        }
    }
    gpu_set_texfilter(true);
}

/// The top half of a tile (a window with an odd number of rows ends half way down one)
function draw_tile_img_part(_t, _x, _y, _sc)
{
    atlas_refresh();
    var _ti = clamp(_t, 0, 63);
    draw_surface_part_ext(tile_atlas, (_ti mod 8) * 16, (_ti div 8) * 16, 16, 8, _x, _y, _sc, _sc, c_white, 1);
}
