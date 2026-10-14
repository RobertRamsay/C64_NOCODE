/// C64 NO-CODE STUDIO - Music workspace (ADAM's Music page, for the SID's 3 voices)
/// Left: the loop library. Centre: the song toolbar, the 3-voice timeline you paint loops onto,
/// and below it the loop editor (drum grid or piano roll) or where each song plays.

#macro MUS_BAR_W 72
#macro MUS_LABEL_W 118

// ---------------------------------------------------------------------------
// Songs and loops
// ---------------------------------------------------------------------------

/// A new song with a little starter arrangement: drums on voice 1, chords then a tune on
/// voice 2, the bass on voice 3 (sound effects never borrow voice 3, so the bass never drops out)
function music_starter_song(_name)
{
    var _s = song_new(_name);
    var _a = _s.arr;
    _a.bars = 8;
    var _lib = [1, 13, 20, 9];
    for (var i = 0; i < array_length(_lib); i++) { array_push(_a.loops, loop_copy(global.MUS_LIB[_lib[i]])); }
    for (var b = 0; b < 8; b++)
    {
        _a.lanes[0][b] = 0;
        _a.lanes[1][b] = 1;
        if (b >= 4) { _a.lanes[1][b] = 2; }
        _a.lanes[2][b] = 3;
    }
    return _s;
}

function music_song_add()
{
    if (array_length(proj.songs) >= MUS_SONG_MAX)
    {
        toast("A game can have up to " + string(MUS_SONG_MAX) + " songs", 1);
        return;
    }
    undo_mark("musnew" + string(current_time));
    array_push(proj.songs, music_starter_song("Song " + string(array_length(proj.songs) + 1)));
    mus_song = array_length(proj.songs) - 1;
    mus_edit = -1;
    mus_xoff = 0;
    mus_from = 0;
    if (array_length(proj.songs) == 1 && proj.level_song[0] < 0)
    {
        proj.level_song[0] = 0;
        if (proj.game_type == 1) { toast("New song - it plays on level 1", 0); }
        else { toast("New song - it plays on your game's screen", 0); }
    }
    else { toast("New song", 0); }
}

function music_song_remove()
{
    if (array_length(proj.songs) == 0) { return; }
    music_preview_stop();
    undo_mark("musdel" + string(current_time));
    var _name = proj.songs[mus_song].name;
    music_song_delete(mus_song);
    mus_song = clamp(mus_song, 0, max(0, array_length(proj.songs) - 1));
    mus_edit = -1;
    toast("Deleted " + _name, 0);
}

/// The loop of song _s the brush paints: a library loop is copied into the song the first time
function music_brush_loop(_s)
{
    if (mus_brush_src == 1)
    {
        if (mus_brush >= 0 && mus_brush < array_length(_s.arr.loops)) { return mus_brush; }
        return -1;
    }
    var _lib = clamp(mus_brush, 0, array_length(global.MUS_LIB) - 1);
    for (var i = 0; i < array_length(_s.arr.loops); i++)
    {
        if (_s.arr.loops[i].lib == _lib) { return i; }
    }
    if (array_length(_s.arr.loops) >= MUS_LOOP_MAX)
    {
        toast("A song can have up to " + string(MUS_LOOP_MAX) + " different loops", 1);
        return -1;
    }
    array_push(_s.arr.loops, loop_copy(global.MUS_LIB[_lib]));
    return array_length(_s.arr.loops) - 1;
}

/// The default instrument of each loop category
function music_cat_inst(_cat)
{
    var _i = [0, 6, 8, 10, 13];
    return _i[clamp(_cat, 0, 4)];
}

function music_loop_add(_s)
{
    if (array_length(_s.arr.loops) >= MUS_LOOP_MAX)
    {
        toast("A song can have up to " + string(MUS_LOOP_MAX) + " different loops", 1);
        return;
    }
    var _cat = mus_cat;
    if (_cat > 4) { _cat = 3; }
    undo_mark("musloopnew" + string(current_time));
    var _l = loop_new("My loop " + string(array_length(_s.arr.loops) + 1), _cat, music_cat_inst(_cat));
    array_push(_s.arr.loops, _l);
    mus_brush_src = 1;
    mus_brush = array_length(_s.arr.loops) - 1;
    mus_edit = mus_brush;
    mus_edit_lane = -1;
    mus_edit_bar = -1;
    mus_edit_step = -1;
    toast("New loop - add notes below, then paint it onto the timeline", 0);
}

/// Plays one loop on its own: twice (_repeat false) or over and over
function music_preview_loop(_lp, _repeat, _what)
{
    var _t = song_new("Loop");
    if (array_length(proj.songs) > 0)
    {
        var _cur = proj.songs[clamp(mus_song, 0, array_length(proj.songs) - 1)];
        _t.speed = _cur.speed;
        _t.swing = _cur.swing;
    }
    _t.arr.loops = [_lp];
    _t.arr.bars = 2;
    _t.arr.lanes[0][0] = 0;
    _t.arr.lanes[0][1] = 0;
    music_preview_start(music_compile([_t], [0]), 0, 0, !_repeat, _what);
}

/// Plays the current song: one bar, 4 bars or the whole song, from the play-from marker
function music_preview_song(_s)
{
    var _cs = music_compile([_s], [0]);
    var _c = _cs.songs[0];
    var _from = clamp(mus_from, 0, _c.bars - 1);
    if (mus_range == 0)
    {
        _c.bars = _from + 1;
        _c.loop = _from;
    }
    if (mus_range == 1)
    {
        _c.bars = min(_c.bars, _from + 4);
        _c.loop = _from;
    }
    music_preview_start(_cs, 0, _from, false, "song" + string(mus_song));
}

/// Note editing changes the loop: it is the song's own now (the Mine tab)
function music_loop_touched(_lp)
{
    _lp.lib = -1;
}

// ---------------------------------------------------------------------------
// Export: a PSID file any SID player (VICE's VSID, SIDPlay, the C64 Ultimate) can play
// ---------------------------------------------------------------------------

function music_export_sid()
{
    if (array_length(proj.songs) == 0) { return; }
    var _name = string_replace_all(proj.name, " ", "_");
    var _path = get_save_filename("SID tune|*.sid", _name + ".sid");
    if (_path == "") { return; }
    if (string_lower(filename_ext(_path)) != ".sid") { _path += ".sid"; }
    var _n = music_sid_save(proj, _path);
    if (_n > 0) { toast("Saved " + filename_name(_path) + " (" + string(array_length(proj.songs)) + " song(s), " + string(_n) + " bytes)", 0); }
}

/// Writes project _p's songs to _path as a PSID v2 file (the driver at $1000). Returns the code size, or -1.
function music_sid_save(_p, _path)
{
    var L = ["; PSID tune made by C64 No-Code Studio", "* = $1000", " jmp psid_init", " jmp mus_update",
             "psid_init:", " pha", " lda #$0f", " sta $d418", " lda #0", " sta $d417", " pla", " jmp mus_play"];
    music_emit(L, _p);
    array_push(L, "sv_t:", " .fill 8,0");
    var _res = asm6502_assemble(string_join_ext("\n", L));
    if (!_res.ok)
    {
        toast("Could not make the tune - " + _res.err, 2);
        return -1;
    }
    var _n = array_length(_res.bytes);
    var _b = buffer_create(0x7c + 2 + _n, buffer_fixed, 1);
    var _w16 = function(_buf, _v)
    {
        buffer_write(_buf, buffer_u8, (_v >> 8) & 255);
        buffer_write(_buf, buffer_u8, _v & 255);
    };
    var _wstr = function(_buf, _s)
    {
        for (var i = 0; i < 32; i++)
        {
            var _c = 0;
            if (i < string_length(_s)) { _c = ord(string_char_at(_s, i + 1)) & 127; }
            buffer_write(_buf, buffer_u8, _c);
        }
    };
    buffer_write(_b, buffer_u8, ord("P"));
    buffer_write(_b, buffer_u8, ord("S"));
    buffer_write(_b, buffer_u8, ord("I"));
    buffer_write(_b, buffer_u8, ord("D"));
    _w16(_b, 2);                                    // version
    _w16(_b, 0x7c);                                 // data offset
    _w16(_b, 0);                                    // load address: the first 2 data bytes
    _w16(_b, _res.labels[$ "psid_init"]);
    _w16(_b, _res.labels[$ "mus_update"]);
    _w16(_b, array_length(_p.songs));
    _w16(_b, 1);                                    // start song
    _w16(_b, 0);
    _w16(_b, 0);                                    // speed: every song once a frame (vertical blank)
    _wstr(_b, string_copy(_p.name, 1, 31));
    _wstr(_b, "C64 No-Code Studio");
    _wstr(_b, string(current_year));
    var _flags = 0x14;                              // PAL, 6581
    if (_p.machine == MACHINE_NTSC) { _flags = 0x18; }
    _w16(_b, _flags);
    buffer_write(_b, buffer_u8, 0);                 // start page, page length
    buffer_write(_b, buffer_u8, 0);
    _w16(_b, 0);
    buffer_write(_b, buffer_u8, _res.org & 255);
    buffer_write(_b, buffer_u8, (_res.org >> 8) & 255);
    for (var i = 0; i < _n; i++) { buffer_write(_b, buffer_u8, _res.bytes[i]); }
    buffer_save(_b, _path);
    buffer_delete(_b);
    return _n;
}

// ---------------------------------------------------------------------------
// The page
// ---------------------------------------------------------------------------

function ws_music_draw(_x1, _y1, _x2, _y2)
{
    var _lw = 250;
    mus_song = clamp(mus_song, 0, max(0, array_length(proj.songs) - 1));
    music_library_draw(_x1, _y1, _x1 + _lw, _y2);

    var _cx1 = _x1 + _lw + 12;
    ui_panel(_cx1, _y1, _x2, _y2, "Music");
    if (live_ok && array_length(proj.songs) > 0)
    {
        ui_text(_x2 - 18, _y1 + 21, "Music on the C64: " + string(live_seg_music) + " bytes", global.TH.text_dim, fa_right, fa_middle, global.f_small, 1);
    }
    if (array_length(proj.songs) == 0)
    {
        var _mx = (_cx1 + _x2) * 0.5;
        var _my = (_y1 + _y2) * 0.5;
        ui_text(_mx, _my - 60, "No songs yet", global.TH.text, fa_center, fa_middle, global.f_title, 1);
        ui_text_wrap(_mx - 230, _my - 34, "A song plays on the SID chip's 3 voices while your game runs. Start with a ready-made song, then paint loops from the library onto its timeline.", global.TH.text_dim, 460, global.f_body, 1);
        if (ui_button("mus_first", _mx - 90, _my + 34, 180, 40, "New song", "New song|Makes a song with drums, chords, a tune and a bass line to start from.", BTN_ACCENT)) { music_song_add(); }
        return;
    }
    var _s = proj.songs[mus_song];
    if (keyboard_check_pressed(vk_space) && ui_focus == "" && ui_can_input() && !keyboard_check(vk_control))
    {
        if (mus_playing) { music_preview_stop(); }
        else { music_preview_song(_s); }
    }

    // ---------------- toolbar row 1: the song ----------------
    var _tx = _cx1 + 18;
    var _ty = _y1 + 54;
    var _ns = ui_dropdown("mus_songs", _tx, _ty, 200, 32, music_song_names(), mus_song, "Song|Which song you are working on. A game can have up to " + string(MUS_SONG_MAX) + ".");
    if (_ns != mus_song)
    {
        mus_song = _ns;
        mus_edit = -1;
        mus_xoff = 0;
        mus_from = 0;
        music_preview_stop();
        _s = proj.songs[mus_song];
    }
    _tx += 208;
    if (ui_button("mus_new", _tx, _ty, 64, 32, "New", "New song|Makes another song, with a starter arrangement to change.", BTN_NORMAL)) { music_song_add(); _s = proj.songs[mus_song]; }
    _tx += 72;
    set_val(_s, "name", ui_textfield("mus_name", _tx, _ty, 170, 32, _s.name, 20, "Song name|Shown on the Logic page and in the level list."), "musname");
    _tx += 178;
    if (ui_button("mus_del", _tx, _ty, 76, 32, "Delete", "Delete song|Removes this song. Levels and rules that played it stop playing music. Undo brings it back.", BTN_DANGER))
    {
        music_song_remove();
        return;
    }
    _tx += 84;
    if (ui_button("mus_sid", _tx, _ty, 120, 32, "Save .SID", "Save as a SID tune|Saves all your songs as a .SID file (PSID) - the format C64 music collections use. Play it in VICE's VSID, SIDPlay or on a C64 Ultimate.", BTN_GHOST))
    {
        music_export_sid();
    }

    // ---------------- toolbar row 2: playing and timing ----------------
    _tx = _cx1 + 18;
    var _hy = _y1 + 98;
    var _cy = _hy + 16;
    var _pl = (mus_playing && mus_play_what == "song" + string(mus_song));
    var _plab = "Play";
    var _pst = BTN_ACCENT;
    if (_pl)
    {
        _plab = "Stop";
        _pst = BTN_ON;
    }
    if (ui_button("mus_play", _tx, _cy, 88, 30, _plab, "Play the song|Plays the part chosen on the right, from the play-from marker (click the bar numbers to move it). Shortcut: Space.", _pst))
    {
        if (_pl) { music_preview_stop(); }
        else { music_preview_song(_s); }
    }
    _tx += 96;
    ui_heading(_tx, _hy, "Play");
    var _rn = ["Bar", "4 bars", "Song"];
    var _rh = ["Play one bar|Plays the bar at the play-from marker over and over.", "Play 4 bars|Plays 4 bars from the play-from marker over and over.", "Play the song|Plays from the play-from marker to the end, then goes back to the loop point (the green flag)."];
    for (var r = 0; r < 3; r++)
    {
        var _rs = BTN_GHOST;
        if (mus_range == r) { _rs = BTN_ON; }
        if (ui_button("mus_range_" + string(r), _tx + r * 68, _cy, 64, 30, _rn[r], _rh[r], _rs)) { mus_range = r; }
    }
    _tx += 212;
    var _bpm = round(sid_fps() * 60 / (8 * _s.speed));
    ui_heading(_tx, _hy, "Speed  " + string(_bpm) + " BPM");
    var _sp = ui_stepper("mus_speed", _tx, _cy, 104, _s.speed, 2, 12, "Speed|Frames each step lasts - the music driver runs once a frame (50 a second on PAL, 60 on NTSC). 3 is " + string(round(sid_fps() * 60 / 24)) + " BPM; bigger numbers are slower.");
    if (_sp != _s.speed)
    {
        set_val(_s, "speed", _sp, "musspeed");
        _s.swing = min(_s.swing, _s.speed - 1);
    }
    _tx += 116;
    ui_heading(_tx, _hy, "Swing");
    set_val(_s, "swing", ui_stepper("mus_swing", _tx, _cy, 96, _s.swing, 0, _s.speed - 1, "Swing|Makes every first 16th note longer and the second one shorter, by this many frames - a shuffle feel. 0 is straight."), "musswing");
    _tx += 108;
    ui_heading(_tx, _hy, "Loop from bar");
    var _lb = ui_stepper("mus_loopbar", _tx, _cy, 100, _s.loop_bar + 1, 1, _s.arr.bars, "Loop point|When the song ends it carries on from this bar (the green flag). Right-click a bar number to set it too.");
    set_val(_s, "loop_bar", _lb - 1, "musloopbar");
    _tx += 112;
    ui_heading(_tx, _hy, "Length (bars)");
    var _nb = ui_stepper("mus_bars", _tx, _cy, 104, _s.arr.bars, 1, MUS_BAR_MAX, "Song length|How many bars the song has, up to " + string(MUS_BAR_MAX) + ". Each bar is 32 steps (4 beats).");
    if (_nb != _s.arr.bars)
    {
        set_val(_s.arr, "bars", _nb, "musbars");
        _s.loop_bar = min(_s.loop_bar, _s.arr.bars - 1);
        mus_from = min(mus_from, _s.arr.bars - 1);
    }

    // ---------------- timeline ----------------
    var _lane_h = 46;
    if (mus_edit >= 0) { _lane_h = 34; }
    var _tl_y = _y1 + 156;
    var _tl_b = music_timeline_draw(_cx1 + 18, _tl_y, _x2 - 18, _lane_h, _s);

    // ---------------- loop editor, or where the music plays ----------------
    var _ey = _tl_b + 12;
    if (mus_edit >= 0 && mus_edit < array_length(_s.arr.loops))
    {
        music_editor_draw(_cx1 + 18, _ey, _x2 - 18, _y2 - 16, _s, _s.arr.loops[mus_edit]);
    }
    else
    {
        mus_edit = -1;
        music_where_draw(_cx1 + 18, _ey, _x2 - 18, _y2 - 16);
    }
}

// ---------------------------------------------------------------------------
// The loop library
// ---------------------------------------------------------------------------

function music_library_draw(_x1, _y1, _x2, _y2)
{
    ui_panel(_x1, _y1, _x2, _y2, "Loops");
    var _bw = floor((_x2 - _x1 - 28 - 6) / 2);
    for (var c = 0; c < 6; c++)
    {
        var _bx = _x1 + 14 + (c mod 2) * (_bw + 6);
        var _by = _y1 + 52 + (c div 2) * 34;
        var _st = BTN_GHOST;
        if (mus_cat == c) { _st = BTN_ON; }
        var _help = "Mine|The loops in this song, including the ones you made or changed.";
        if (c < 5) { _help = global.MUS_CAT_NAMES[c] + "|Ready-made " + string_lower(global.MUS_CAT_NAMES[c]) + " loops. Click one to hear it and pick it up, then paint it onto the timeline."; }
        if (ui_button("mus_cat_" + string(c), _bx, _by, _bw, 28, global.MUS_CAT_NAMES[c], _help, _st)) { mus_cat = c; }
        ui_rrect(_bx + 6, _by + 24, _bx + _bw - 6, _by + 27, 1, global.MUS_CAT_COLS[c], global.MUS_CAT_COLS[c], 0.8);
    }
    var _has_song = (array_length(proj.songs) > 0);
    var _ny = _y1 + 158;
    if (_has_song)
    {
        if (ui_button("mus_loop_new", _x1 + 14, _ny, _x2 - _x1 - 28, 30, "+ New loop", "New loop|Makes an empty loop in this song for you to fill with notes.", BTN_NORMAL))
        {
            music_loop_add(proj.songs[mus_song]);
        }
    }
    var _ly1 = _ny + 40;
    var _ly2 = _y2 - 12;
    ui_inset(_x1 + 10, _ly1, _x2 - 10, _ly2, 10);
    // the items: library loops of the category, or this song's loops
    var _items = [];
    if (mus_cat < 5)
    {
        for (var i = 0; i < array_length(global.MUS_LIB); i++)
        {
            if (global.MUS_LIB[i].cat == mus_cat) { array_push(_items, i); }
        }
    }
    else if (_has_song)
    {
        var _s0 = proj.songs[mus_song];
        for (var j = 0; j < array_length(_s0.arr.loops); j++) { array_push(_items, j); }
    }
    var _ih = 34;
    var _ch = array_length(_items) * (_ih + 4) + 8;
    var _off = ui_scroll_begin("mus_lib_scroll", _x1 + 10, _ly1, _x2 - 10, _ly2, _ch);
    for (var k = 0; k < array_length(_items); k++)
    {
        var _iy = _ly1 + 6 + k * (_ih + 4) - _off;
        if (_iy + _ih < _ly1 || _iy > _ly2) { continue; }
        var _ix1 = _x1 + 16;
        var _ix2 = _x2 - 18;
        var _lp, _sel, _sub;
        if (mus_cat < 5)
        {
            _lp = global.MUS_LIB[_items[k]];
            _sel = (mus_brush_src == 0 && mus_brush == _items[k]);
            _sub = music_inst_name(_lp.inst);
            if (_lp.cat == 0) { _sub = "Drum kit"; }
        }
        else
        {
            _lp = proj.songs[mus_song].arr.loops[_items[k]];
            _sel = (mus_brush_src == 1 && mus_brush == _items[k]);
            var _u = music_loop_uses(proj.songs[mus_song], _items[k]);
            _sub = global.MUS_CAT_NAMES[_lp.cat] + "  -  " + string(_u) + " bar(s)";
            if (_u == 0) { _sub = global.MUS_CAT_NAMES[_lp.cat] + "  -  not used"; }
        }
        var _id = "mus_item_" + string(k);
        var _hot = ui_register(_id, _ix1, _iy, _ix2, _iy + _ih, "Loop: " + _lp.name + "|Click to hear it and pick it up as your brush, then click or drag on the timeline to paint it. Double-click to edit its notes.");
        var _col = global.MUS_CAT_COLS[_lp.cat];
        var _bg = global.TH.btn_top;
        if (_hot) { _bg = global.TH.btn_hot_top; }
        ui_rrect(_ix1, _iy, _ix2, _iy + _ih, 8, _bg, global.TH.panel_bot, 0.9);
        if (_sel) { ui_rrect_line(_ix1, _iy, _ix2, _iy + _ih, 8, global.TH.accent, 1, 2); }
        ui_rrect(_ix1 + 6, _iy + 7, _ix1 + 11, _iy + _ih - 7, 2, _col, _col, 1);
        ui_text(_ix1 + 20, _iy + 11, ui_text_fit(_lp.name, global.f_bold, _ix2 - _ix1 - 30), global.TH.text, fa_left, fa_middle, global.f_bold, 1);
        ui_text(_ix1 + 20, _iy + 25, ui_text_fit(_sub, global.f_small, _ix2 - _ix1 - 30), global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
        if (_hot && ui_pressed)
        {
            ui_take_click();
            var _key = "item" + string(mus_cat) + "_" + string(_items[k]);
            var _dbl = (mus_click_key == _key && current_time - mus_click_t < 380);
            mus_click_key = _key;
            mus_click_t = current_time;
            mus_brush_src = (mus_cat == 5);
            mus_brush = _items[k];
            if (_dbl && _has_song)
            {
                var _li = music_brush_loop(proj.songs[mus_song]);
                if (_li >= 0)
                {
                    mus_edit = _li;
                    mus_edit_lane = -1;
                    mus_edit_bar = -1;
                    mus_edit_step = -1;
                }
            }
            else { music_preview_loop(_lp, false, "loop"); }
        }
    }
    ui_scroll_end("mus_lib_scroll", _x1 + 10, _ly1, _x2 - 10, _ly2, _ch);
    if (array_length(_items) == 0)
    {
        var _msg = "Make a song first";
        if (_has_song) { _msg = "No loops in this song yet"; }
        ui_text((_x1 + _x2) * 0.5, _ly1 + 30, _msg, global.TH.text_faint, fa_center, fa_middle, global.f_small, 1);
    }
}

// ---------------------------------------------------------------------------
// The timeline: a lane for each SID voice, a bar per cell. Returns its bottom y.
// ---------------------------------------------------------------------------

function music_timeline_draw(_x1, _y1, _x2, _lane_h, _s)
{
    var _gx = _x1 + MUS_LABEL_W;
    var _gw = _x2 - _gx;
    var _rh = 24;
    var _bars = _s.arr.bars;
    var _total = _bars * MUS_BAR_W;
    var _maxoff = max(0, _total - _gw);
    // follow the playhead
    var _pos = -1;
    if (mus_playing && mus_play_what == "song" + string(mus_song)) { _pos = music_preview_pos(); }
    if (_pos >= 0 && !ui_held)
    {
        var _px = _pos * MUS_BAR_W;
        if (_px < mus_xoff || _px > mus_xoff + _gw - 8) { mus_xoff = floor(_pos) * MUS_BAR_W; }
    }
    mus_xoff = clamp(mus_xoff, 0, _maxoff);
    var _lanes_y = _y1 + _rh + 4;
    var _y2 = _lanes_y + MUS_LANES * (_lane_h + 4);
    // wheel scrolls along the song
    if (ui_hit(_x1, _y1, _x2, _y2) && ui_wheel != 0)
    {
        mus_xoff = clamp(mus_xoff - ui_wheel * MUS_BAR_W, 0, _maxoff);
        ui_wheel = 0;
    }

    // lane labels
    var _vh = ["Voice 1|SID voice 1 ($D400). Sound effects set to voice 1 borrow it while they play - the music carries on underneath.",
               "Voice 2|SID voice 2 ($D407). Sound effects set to voice 2 borrow it while they play.",
               "Voice 3|SID voice 3 ($D40E). Only the music uses it, so it never drops out - a good home for the bass."];
    var _vsub = ["shared with sounds", "shared with sounds", "music only"];
    for (var l = 0; l < MUS_LANES; l++)
    {
        var _ly = _lanes_y + l * (_lane_h + 4);
        ui_register("mus_lane_" + string(l), _x1, _ly, _gx - 8, _ly + _lane_h, _vh[l]);
        ui_rrect(_x1, _ly, _gx - 8, _ly + _lane_h, 8, global.TH.btn_top, global.TH.panel_bot, 0.9);
        if (_lane_h >= 40)
        {
            ui_text(_x1 + 10, _ly + _lane_h * 0.5 - 8, "Voice " + string(l + 1), global.TH.text, fa_left, fa_middle, global.f_bold, 1);
            ui_text(_x1 + 10, _ly + _lane_h * 0.5 + 9, ui_text_fit(_vsub[l], global.f_small, MUS_LABEL_W - 26), global.TH.text_faint, fa_left, fa_middle, global.f_small, 1);
        }
        else { ui_text(_x1 + 10, _ly + _lane_h * 0.5, "Voice " + string(l + 1), global.TH.text, fa_left, fa_middle, global.f_bold, 1); }
    }

    ui_inset(_gx - 2, _y1, _x2, _y2, 8);
    ui_scissor(_gx, _y1, _gw, _y2 - _y1);
    var _b0 = floor(mus_xoff / MUS_BAR_W);
    var _b1 = min(_bars - 1, floor((mus_xoff + _gw) / MUS_BAR_W));
    // ruler
    ui_register("mus_ruler", _gx, _y1, _x2, _y1 + _rh, "Bar numbers|Click a bar number to play from there (the white marker). Right-click to make the song loop back to that bar when it ends (the green flag).");
    for (var b = _b0; b <= _b1; b++)
    {
        var _bx = _gx + b * MUS_BAR_W - mus_xoff;
        draw_line_colour(_bx, _y1 + 4, _bx, _y2 - 2, global.TH.panel_edge, global.TH.panel_edge);
        ui_text(_bx + 6, _y1 + _rh * 0.5, string(b + 1), global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
        if (b == _s.loop_bar)
        {
            draw_triangle_colour(_bx + 1, _y1 + 3, _bx + 1, _y1 + 15, _bx + 11, _y1 + 9, global.TH.accent2, global.TH.accent2, global.TH.accent2, false);
            draw_line_width_colour(_bx + 1, _y1 + 3, _bx + 1, _y1 + _rh, 2, global.TH.accent2, global.TH.accent2);
        }
        if (b == mus_from)
        {
            draw_triangle_colour(_bx + MUS_BAR_W * 0.5 - 5, _y1 + _rh - 8, _bx + MUS_BAR_W * 0.5 + 5, _y1 + _rh - 8, _bx + MUS_BAR_W * 0.5, _y1 + _rh - 2, c_white, c_white, c_white, false);
        }
        var _rb = ui_hit(_bx, _y1, _bx + MUS_BAR_W, _y1 + _rh);
        if (_rb && ui_pressed)
        {
            ui_take_click();
            mus_from = b;
            if (mus_playing && mus_play_what == "song" + string(mus_song)) { music_preview_song(_s); }
        }
        if (_rb && ui_rpressed)
        {
            ui_rpressed = false;
            set_val(_s, "loop_bar", b, "musloopbar" + string(current_time));
        }
    }
    // the end of the song
    var _ex = _gx + _total - mus_xoff;
    if (_ex < _x2) { draw_line_width_colour(_ex, _y1, _ex, _y2, 2, global.TH.text_faint, global.TH.text_faint); }

    // cells
    var _brush_name = "";
    for (var l2 = 0; l2 < MUS_LANES; l2++)
    {
        var _ly2 = _lanes_y + l2 * (_lane_h + 4);
        for (var b2 = _b0; b2 <= _b1; b2++)
        {
            var _cx = _gx + b2 * MUS_BAR_W - mus_xoff;
            var _li = _s.arr.lanes[l2][b2];
            var _cell_hot = ui_hit(_cx, _ly2, _cx + MUS_BAR_W, _ly2 + _lane_h) && ui_hit(_gx, _y1, _x2, _y2);
            if (_li >= 0 && _li < array_length(_s.arr.loops))
            {
                var _lp = _s.arr.loops[_li];
                var _col = global.MUS_CAT_COLS[_lp.cat];
                var _sel = (mus_edit == _li);
                ui_rrect(_cx + 2, _ly2 + 1, _cx + MUS_BAR_W - 2, _ly2 + _lane_h - 1, 6, _col, merge_colour(_col, c_black, 0.35), 0.85);
                music_loop_mini(_lp, _cx + 6, _ly2 + 4, MUS_BAR_W - 12, _lane_h - 8);
                if (_lane_h >= 40) { ui_text(_cx + 7, _ly2 + 11, ui_text_fit(_lp.name, global.f_small, MUS_BAR_W - 12), c_white, fa_left, fa_middle, global.f_small, 1); }
                if (_sel) { ui_rrect_line(_cx + 2, _ly2 + 1, _cx + MUS_BAR_W - 2, _ly2 + _lane_h - 1, 6, c_white, 1, 2); }
            }
            else if (_cell_hot && mus_paint == 0)
            {
                ui_rrect_line(_cx + 3, _ly2 + 2, _cx + MUS_BAR_W - 3, _ly2 + _lane_h - 2, 6, global.TH.accent, 0.5, 1);
            }
            if (!_cell_hot) { continue; }
            var _key = string(l2) + "_" + string(b2);
            if (_li >= 0) { _brush_name = _s.arr.loops[_li].name; }
            // press: a full cell picks its loop up (double-click edits it), an empty one is painted
            if (ui_pressed)
            {
                ui_take_click();
                var _dbl = (mus_click_key == "cell" + _key && current_time - mus_click_t < 380);
                mus_click_key = "cell" + _key;
                mus_click_t = current_time;
                mus_paint = 1;
                mus_paint_cell = _key;
                mus_paint_tag = "muspaint" + string(current_time);
                if (_li >= 0)
                {
                    mus_brush_src = 1;
                    mus_brush = _li;
                    if (_dbl)
                    {
                        mus_edit = _li;
                        mus_edit_lane = l2;
                        mus_edit_bar = b2;
                        mus_edit_step = -1;
                        mus_paint = 0;
                    }
                }
                else { music_paint_cell(_s, l2, b2); }
            }
            else if (ui_rpressed)
            {
                ui_rpressed = false;
                mus_paint = 2;
                mus_paint_cell = "";
                mus_paint_tag = "muserase" + string(current_time);
                music_paint_cell(_s, l2, b2);
            }
            else if (mus_paint == 1 && ui_held && _key != mus_paint_cell)
            {
                mus_paint_cell = "";
                music_paint_cell(_s, l2, b2);
            }
            else if (mus_paint == 2 && ui_rheld)
            {
                music_paint_cell(_s, l2, b2);
            }
        }
    }
    if (!ui_held && !ui_rheld) { mus_paint = 0; }

    // playhead
    if (_pos >= 0)
    {
        var _hx = _gx + _pos * MUS_BAR_W - mus_xoff;
        draw_line_width_colour(_hx, _y1, _hx, _y2, 2, global.TH.warn, global.TH.warn);
    }
    ui_scissor_reset();
    ui_register("mus_grid", _gx, _lanes_y, _x2, _y2, "Timeline|Each row is one of the SID's 3 voices, each box one bar. Click an empty bar to paint the loop you picked, drag to paint more, right-click (and drag) to rub out. Click a loop to pick it up; double-click to edit its notes.");

    // scroll bar
    var _sy = _y2 + 4;
    if (_maxoff > 0)
    {
        var _tw = max(30, _gw * (_gw / _total));
        var _tx = _gx + (_gw - _tw) * (mus_xoff / _maxoff);
        ui_rrect(_gx, _sy, _x2, _sy + 8, 4, c_black, c_black, 0.25);
        var _shot = ui_register("mus_hscroll", _gx, _sy - 2, _x2, _sy + 10, "Scroll|Drag to move along the song. The mouse wheel over the timeline works too.");
        if (_shot && ui_pressed)
        {
            ui_take_click();
            ui_drag_id = "mus_hscroll";
        }
        if (ui_drag_id == "mus_hscroll" && ui_held)
        {
            mus_xoff = clamp((ui_mx - _gx - _tw * 0.5) / max(1, _gw - _tw) * _maxoff, 0, _maxoff);
        }
        ui_rrect(_tx, _sy, _tx + _tw, _sy + 8, 4, global.TH.text_dim, global.TH.text_faint, 0.9);
    }
    // what the brush is
    var _bn = "";
    if (mus_brush_src == 0) { _bn = global.MUS_LIB[clamp(mus_brush, 0, array_length(global.MUS_LIB) - 1)].name; }
    else if (mus_brush >= 0 && mus_brush < array_length(_s.arr.loops)) { _bn = _s.arr.loops[mus_brush].name; }
    var _hint = "Brush: " + _bn + "   -   click an empty bar to paint, drag for more, right-click to rub out, double-click a loop to edit it";
    ui_text(_x1, _sy + 20, ui_text_fit(_hint, global.f_small, _x2 - _x1), global.TH.text_faint, fa_left, fa_middle, global.f_small, 1);
    return _sy + 28;
}

/// Paints (mus_paint 1) or rubs out (2) one bar of a lane
function music_paint_cell(_s, _lane, _bar)
{
    var _v = -1;
    if (mus_paint == 1)
    {
        undo_mark(mus_paint_tag);
        _v = music_brush_loop(_s);          // a library loop is copied into the song (Mine) the first time
        if (_v < 0) { return; }
    }
    if (_s.arr.lanes[_lane][_bar] == _v) { return; }
    undo_mark(mus_paint_tag);
    _s.arr.lanes[_lane][_bar] = _v;
}

/// A loop's notes drawn small inside a timeline box
function music_loop_mini(_lp, _x, _y, _w, _h)
{
    var _sw = _w / MUS_STEPS;
    draw_set_alpha(0.75);
    if (_lp.cat == 0)
    {
        for (var s = 0; s < MUS_STEPS; s++)
        {
            if (_lp.notes[s] <= 0) { continue; }
            var _r = 0;
            for (var d = 0; d < array_length(global.MUS_DRUM_ROWS); d++)
            {
                if (global.MUS_DRUM_ROWS[d] == _lp.insts[s]) { _r = d; }
            }
            var _dy = _y + _h - 3 - (_r / 8) * (_h - 6);
            draw_rectangle_colour(_x + s * _sw, _dy - 1, _x + s * _sw + max(1, _sw - 1), _dy + 1, c_white, c_white, c_white, c_white, false);
        }
    }
    else
    {
        var _lo = 99, _hi = 0;
        for (var s2 = 0; s2 < MUS_STEPS; s2++)
        {
            if (_lp.notes[s2] > 0)
            {
                _lo = min(_lo, _lp.notes[s2]);
                _hi = max(_hi, _lp.notes[s2]);
            }
        }
        var _span = max(12, _hi - _lo);
        for (var s3 = 0; s3 < MUS_STEPS; s3++)
        {
            var _n = _lp.notes[s3];
            if (_n <= 0) { continue; }
            var _len = music_note_length(_lp, s3);
            var _ny = _y + _h - 3 - ((_n - _lo) / _span) * (_h - 6);
            draw_rectangle_colour(_x + s3 * _sw, _ny - 1, _x + (s3 + _len) * _sw - 1, _ny + 1, c_white, c_white, c_white, c_white, false);
        }
    }
    draw_set_alpha(1);
}

// ---------------------------------------------------------------------------
// The loop editor: a drum grid for drum loops, a piano roll for the rest
// ---------------------------------------------------------------------------

function music_editor_draw(_x1, _y1, _x2, _y2, _s, _lp)
{
    var _col = global.MUS_CAT_COLS[_lp.cat];
    ui_rrect(_x1, _y1, _x2, _y2, 10, global.TH.btn_top, global.TH.panel_bot, 0.6);
    ui_rrect(_x1, _y1 + 10, _x1 + 4, _y2 - 10, 2, _col, _col, 1);
    var _hx = _x1 + 14;
    var _hy = _y1 + 8;
    var _was_lib = _lp.lib;
    var _nm = ui_textfield("mus_lname", _hx, _hy, 160, 30, _lp.name, 24, "Loop name|Shown on the timeline and in the Mine list.");
    set_val(_lp, "name", _nm, "muslname");
    _hx += 168;
    if (_lp.cat == 0)
    {
        ui_text(_hx + 4, _hy + 15, "Drums", global.TH.text_dim, fa_left, fa_middle, global.f_bold, 1);
        _hx += 70;
    }
    else
    {
        var _cats = ["Bass", "Chords", "Lead", "FX"];
        var _nc = ui_dropdown("mus_lcat", _hx, _hy, 96, 30, _cats, _lp.cat - 1, "Kind of loop|Sorts it in the library and colours it on the timeline.");
        set_val(_lp, "cat", _nc + 1, "muslcat");
        _hx += 104;
        var _ids = music_inst_ids();
        var _names = [];
        var _cur = 0;
        for (var i = 0; i < array_length(_ids); i++)
        {
            array_push(_names, music_inst_name(_ids[i]));
            if (_ids[i] == _lp.inst) { _cur = i; }
        }
        var _ni = ui_dropdown("mus_linst", _hx, _hy, 170, 30, _names, _cur, "Instrument|The SID sound the notes play with: built-in instruments first, then the sounds from your Sound page (their waveform, pulse, envelope and slide).");
        if (_ids[_ni] != _lp.inst)
        {
            set_val(_lp, "inst", _ids[_ni], "muslinst");
            music_loop_touched(_lp);
        }
        _hx += 178;
    }
    var _lis = (mus_playing && mus_play_what == "edit");
    var _ll = "Listen";
    if (_lis) { _ll = "Stop"; }
    if (ui_button("mus_listen", _hx, _hy, 74, 30, _ll, "Listen|Plays this loop on its own, over and over, as you edit it.", BTN_ACCENT))
    {
        if (_lis) { music_preview_stop(); }
        else { music_preview_loop(_lp, true, "edit"); }
    }
    _hx += 82;
    var _uses = music_loop_uses(_s, mus_edit);
    var _room = (_x2 - 10 - 70 - 8 - 70 - 8 - 64 - 8) - _hx;     // up to the Clear button
    if (mus_edit_bar >= 0 && _uses > 1 && _room >= 70)
    {
        var _cl = "Copy for this bar";
        if (_room < 150) { _cl = "Own copy"; }
        if (ui_button("mus_copy", _hx, _hy, min(150, _room), 30, _cl, "Copy for this bar|This loop plays in " + string(_uses) + " bars, and changing it changes them all. This gives bar " + string(mus_edit_bar + 1) + " its own copy to change.", BTN_NORMAL))
        {
            if (array_length(_s.arr.loops) < MUS_LOOP_MAX)
            {
                undo_mark("muscopy" + string(current_time));
                var _c = loop_copy(_lp);
                _c.lib = -1;
                _c.name = string_copy(_lp.name, 1, 18) + " (2)";
                array_push(_s.arr.loops, _c);
                mus_edit = array_length(_s.arr.loops) - 1;
                _s.arr.lanes[mus_edit_lane][mus_edit_bar] = mus_edit;
                mus_brush_src = 1;
                mus_brush = mus_edit;
                return;
            }
            toast("A song can have up to " + string(MUS_LOOP_MAX) + " different loops", 1);
        }
        _hx += 158;
    }
    var _rx = _x2 - 10;
    if (ui_button("mus_close", _rx - 70, _hy, 70, 30, "Close", "Close the editor|Back to where the music plays.", BTN_NORMAL))
    {
        mus_edit = -1;
        if (mus_play_what == "edit") { music_preview_stop(); }
        return;
    }
    _rx -= 78;
    if (ui_button("mus_ldel", _rx - 70, _hy, 70, 30, "Delete", "Delete this loop|Takes it out of the song, and out of every bar it plays in.", BTN_DANGER))
    {
        undo_mark("musldel" + string(current_time));
        for (var l = 0; l < MUS_LANES; l++)
        {
            for (var b = 0; b < MUS_BAR_MAX; b++)
            {
                if (_s.arr.lanes[l][b] == mus_edit) { _s.arr.lanes[l][b] = -1; }
            }
        }
        music_loop_remove(_s, mus_edit);
        if (mus_brush_src == 1) { mus_brush = -1; }
        mus_edit = -1;
        return;
    }
    _rx -= 78;
    if (ui_button("mus_clear", _rx - 64, _hy, 64, 30, "Clear", "Clear|Removes every note from this loop.", BTN_GHOST))
    {
        undo_mark("musclear" + string(current_time));
        for (var s = 0; s < MUS_STEPS; s++)
        {
            _lp.notes[s] = 0;
            _lp.lengths[s] = 0;
            _lp.arps[s] = 0;
            _lp.fx[s] = 0;
            _lp.fxp[s] = 0;
        }
        music_loop_touched(_lp);
        mus_edit_step = -1;
    }

    var _gy1 = _y1 + 48;
    var _gy2 = _y2 - 10;
    if (_lp.cat == 0) { music_drum_grid(_x1 + 14, _gy1, _x2 - 10, _gy2, _lp); }
    else { music_piano_roll(_x1 + 14, _gy1, _x2 - 10, _gy2, _lp); }
    // an edited library loop becomes this song's own: show it in Mine
    if (_was_lib >= 0 && _lp.lib < 0 && mus_cat < 5 && mus_brush_src == 0)
    {
        mus_brush_src = 1;
        mus_brush = mus_edit;
    }
}

/// Step lines: a strong line every beat (8 steps), a faint one every 16th (2 steps)
function music_grid_lines(_gx, _gy1, _gy2, _sw)
{
    for (var s = 0; s <= MUS_STEPS; s += 2)
    {
        var _a = 0.25;
        if (s mod 8 == 0) { _a = 0.7; }
        draw_set_alpha(_a);
        draw_line_colour(_gx + s * _sw, _gy1, _gx + s * _sw, _gy2, global.TH.panel_edge, global.TH.panel_edge);
    }
    draw_set_alpha(1);
}

/// Where the preview is in the loop being edited (a step), or -1
function music_edit_playstep()
{
    if (!mus_playing || mus_play_what != "edit") { return -1; }
    var _p = music_preview_pos();
    if (_p < 0) { return -1; }
    return (_p - floor(_p)) * MUS_STEPS;
}

function music_drum_grid(_x1, _y1, _x2, _y2, _lp)
{
    // rows: the drum instruments, plus any other instrument the loop already uses
    var _rows = [];
    array_copy(_rows, 0, global.MUS_DRUM_ROWS, 0, array_length(global.MUS_DRUM_ROWS));
    for (var s0 = 0; s0 < MUS_STEPS; s0++)
    {
        if (_lp.notes[s0] > 0)
        {
            var _found = false;
            for (var r0 = 0; r0 < array_length(_rows); r0++) { if (_rows[r0] == _lp.insts[s0]) { _found = true; } }
            if (!_found) { array_push(_rows, _lp.insts[s0]); }
        }
    }
    var _nr = array_length(_rows);
    var _lab_w = 110;
    var _gx = _x1 + _lab_w;
    var _gw = _x2 - _gx;
    var _sw = _gw / MUS_STEPS;
    var _rh = clamp(floor((_y2 - _y1 - 20) / _nr), 10, 26);
    var _gy2 = _y1 + _rh * _nr;
    ui_inset(_gx - 2, _y1 - 2, _x2 + 2, _gy2 + 2, 6);
    music_grid_lines(_gx, _y1, _gy2, _sw);
    ui_register("mus_drums", _gx, _y1, _x2, _gy2, "Drum grid|Click a box to put a drum on that step, click it again to take it off; drag to paint a row. One SID voice plays one sound at a time, so each step holds one drum - the C64 way.");
    var _play = music_edit_playstep();
    for (var r = 0; r < _nr; r++)
    {
        var _ry = _y1 + r * _rh;
        ui_text(_x1, _ry + _rh * 0.5, ui_text_fit(music_inst_name(_rows[r]), global.f_small, _lab_w - 8), global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
        draw_set_alpha(0.3);
        draw_line_colour(_gx, _ry + _rh, _x2, _ry + _rh, global.TH.panel_edge, global.TH.panel_edge);
        draw_set_alpha(1);
        for (var s = 0; s < MUS_STEPS; s++)
        {
            var _cx = _gx + s * _sw;
            var _on = (_lp.notes[s] > 0 && _lp.insts[s] == _rows[r]);
            if (_on) { ui_rrect(_cx + 1, _ry + 2, _cx + _sw - 1, _ry + _rh - 2, 3, global.MUS_CAT_COLS[0], merge_colour(global.MUS_CAT_COLS[0], c_black, 0.3), 1); }
            if (!ui_hit(_cx, _ry, _cx + _sw, _ry + _rh)) { continue; }
            if (!_on) { ui_rrect_line(_cx + 1, _ry + 2, _cx + _sw - 1, _ry + _rh - 2, 3, global.TH.accent, 0.5, 1); }
            if (ui_pressed)
            {
                ui_take_click();
                mus_grid_mode = 1;
                if (_on) { mus_grid_mode = 2; }
                mus_paint_tag = "musdrum" + string(current_time);
            }
            if (ui_held && mus_grid_mode > 0)
            {
                if (mus_grid_mode == 1 && !_on)
                {
                    undo_mark(mus_paint_tag);
                    _lp.notes[s] = MUS_ROOT;
                    _lp.insts[s] = _rows[r];
                    _lp.lengths[s] = 0;
                    music_loop_touched(_lp);
                }
                if (mus_grid_mode == 2 && _on)
                {
                    undo_mark(mus_paint_tag);
                    _lp.notes[s] = 0;
                    music_loop_touched(_lp);
                }
            }
        }
    }
    if (!ui_held) { mus_grid_mode = 0; }
    if (_play >= 0)
    {
        var _px = _gx + _play * _sw;
        draw_line_width_colour(_px, _y1, _px, _gy2, 2, global.TH.warn, global.TH.warn);
    }
    ui_text(_gx, _gy2 + 12, "Each column is a 32nd note; the strong lines are beats. Drums play at their own pitch.", global.TH.text_faint, fa_left, fa_middle, global.f_small, 1);
}

/// The note covering step _s (the latest note starting at or before it that is still held), or -1
function music_note_at(_lp, _s)
{
    for (var t = _s; t >= 0; t--)
    {
        if (_lp.notes[t] > 0)
        {
            if (t + music_note_length(_lp, t) > _s) { return t; }
            return -1;
        }
    }
    return -1;
}

function music_piano_roll(_x1, _y1, _x2, _y2, _lp)
{
    var _props_h = 40;
    var _lab_w = 46;
    var _gx = _x1 + _lab_w;
    var _gw = _x2 - _gx - 30;
    var _sw = _gw / MUS_STEPS;
    var _gh = _y2 - _y1 - _props_h;
    var _rh = clamp(floor(_gh / 25), 9, 18);
    var _nrows = max(6, floor(_gh / _rh));
    mus_roll_base = clamp(mus_roll_base, 1, MUS_NOTE_MAX - _nrows + 1);
    var _gy2 = _y1 + _nrows * _rh;
    var _seen = string(mus_song) + "_" + string(mus_edit);
    if (mus_edit_seen != _seen)
    {
        mus_edit_seen = _seen;
        var _lo = 99, _hi = 0;
        for (var q = 0; q < MUS_STEPS; q++)
        {
            if (_lp.notes[q] > 0)
            {
                _lo = min(_lo, _lp.notes[q]);
                _hi = max(_hi, _lp.notes[q]);
            }
        }
        if (_hi > 0) { mus_roll_base = round((_lo + _hi) / 2 - _nrows / 2); }
    }
    // octave buttons
    if (ui_button("mus_oct_up", _x2 - 26, _y1, 26, 26, "+", "Higher|Shows higher notes (an octave up). The mouse wheel over the notes scrolls too.", BTN_GHOST)) { mus_roll_base += 12; }
    if (ui_button("mus_oct_dn", _x2 - 26, _gy2 - 26, 26, 26, "-", "Lower|Shows lower notes (an octave down).", BTN_GHOST)) { mus_roll_base -= 12; }
    if (ui_hit(_gx, _y1, _gx + _gw, _gy2) && ui_wheel != 0)
    {
        mus_roll_base += ui_wheel * 2;
        ui_wheel = 0;
    }
    mus_roll_base = clamp(mus_roll_base, 1, MUS_NOTE_MAX - _nrows + 1);
    ui_inset(_gx - 2, _y1 - 2, _gx + _gw + 2, _gy2 + 2, 6);
    ui_register("mus_roll", _gx, _y1, _gx + _gw, _gy2, "Piano roll|Click to put a note on a step and drag right to make it longer. Click a note to pick it (change its length, chord and effect below), right-click to delete it. One SID voice plays one note at a time; a chord is played as a fast arpeggio.");
    // rows, black keys darker
    for (var r = 0; r < _nrows; r++)
    {
        var _n = mus_roll_base + _nrows - 1 - r;
        var _ry = _y1 + r * _rh;
        var _pc = (_n - 1) mod 12;
        var _black = (_pc == 1 || _pc == 3 || _pc == 6 || _pc == 8 || _pc == 10);
        if (_black)
        {
            draw_set_alpha(0.25);
            draw_rectangle_colour(_gx, _ry, _gx + _gw, _ry + _rh, c_black, c_black, c_black, c_black, false);
            draw_set_alpha(1);
        }
        // C of every octave, and the top and bottom rows when no C is near
        var _edge = (r == 0 && _pc >= 2) || (r == _nrows - 1 && _pc >= 1 && _pc <= 10);
        if (_pc == 0 || _edge)
        {
            ui_text(_x1, _ry + _rh * 0.5, music_note_name(_n), global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
        }
        if (_pc == 0)
        {
            draw_set_alpha(0.5);
            draw_line_colour(_gx, _ry + _rh, _gx + _gw, _ry + _rh, global.TH.panel_edge, global.TH.panel_edge);
            draw_set_alpha(1);
        }
    }
    music_grid_lines(_gx, _y1, _gy2, _sw);
    // notes
    var _col = global.MUS_CAT_COLS[_lp.cat];
    for (var s = 0; s < MUS_STEPS; s++)
    {
        var _nn = _lp.notes[s];
        if (_nn <= 0) { continue; }
        var _row = mus_roll_base + _nrows - 1 - _nn;
        if (_row < 0 || _row >= _nrows) { continue; }
        var _len = music_note_length(_lp, s);
        // a note is cut short by the next one (one voice, one note)
        for (var t = s + 1; t < s + _len; t++)
        {
            if (_lp.notes[t] > 0)
            {
                _len = t - s;
                break;
            }
        }
        var _ny = _y1 + _row * _rh;
        ui_rrect(_gx + s * _sw + 1, _ny + 1, _gx + (s + _len) * _sw - 1, _ny + _rh - 1, 3, _col, merge_colour(_col, c_black, 0.3), 1);
        if (_lp.arps[s] != 0) { ui_text(_gx + s * _sw + 3, _ny + _rh * 0.5, "+", c_white, fa_left, fa_middle, global.f_small, 1); }
        if (mus_edit_step == s) { ui_rrect_line(_gx + s * _sw, _ny, _gx + (s + _len) * _sw, _ny + _rh, 3, c_white, 1, 2); }
    }
    // mouse
    if (ui_hit(_gx, _y1, _gx + _gw, _gy2))
    {
        var _ms = clamp(floor((ui_mx - _gx) / _sw), 0, MUS_STEPS - 1);
        var _mn = mus_roll_base + _nrows - 1 - clamp(floor((ui_my - _y1) / _rh), 0, _nrows - 1);
        if (ui_pressed)
        {
            ui_take_click();
            var _at = music_note_at(_lp, _ms);
            if (_at >= 0 && _lp.notes[_at] == _mn)
            {
                mus_edit_step = _at;          // pick the note
                mus_roll_drag = -1;
            }
            else
            {
                undo_mark("musnote" + string(current_time));
                if (_lp.notes[_ms] <= 0)
                {
                    _lp.lengths[_ms] = mus_note_len;
                    _lp.arps[_ms] = 0;
                    _lp.fx[_ms] = 0;
                    _lp.fxp[_ms] = 0;
                }
                _lp.notes[_ms] = _mn;
                music_loop_touched(_lp);
                mus_edit_step = _ms;
                mus_roll_drag = _ms;
                mus_roll_tag = "musnotelen" + string(current_time);
            }
        }
        if (ui_rpressed)
        {
            ui_rpressed = false;
            var _at2 = music_note_at(_lp, _ms);
            if (_at2 >= 0)
            {
                undo_mark("musnotedel" + string(current_time));
                _lp.notes[_at2] = 0;
                music_loop_touched(_lp);
                if (mus_edit_step == _at2) { mus_edit_step = -1; }
            }
        }
    }
    // drag right to make the new note longer
    if (mus_roll_drag >= 0 && ui_held)
    {
        var _ds = clamp(floor((ui_mx - _gx) / _sw), mus_roll_drag, MUS_STEPS - 1);
        var _nl = _ds - mus_roll_drag + 1;
        if (_nl != music_note_length(_lp, mus_roll_drag) && _lp.notes[mus_roll_drag] > 0)
        {
            undo_mark(mus_roll_tag);
            _lp.lengths[mus_roll_drag] = _nl;
            mus_note_len = _nl;
        }
    }
    if (!ui_held) { mus_roll_drag = -1; }
    var _play = music_edit_playstep();
    if (_play >= 0)
    {
        var _px = _gx + _play * _sw;
        draw_line_width_colour(_px, _y1, _px, _gy2, 2, global.TH.warn, global.TH.warn);
    }

    // the picked note
    var _py = _gy2 + 8;
    var _st = mus_edit_step;
    if (_st < 0 || _st >= MUS_STEPS || _lp.notes[_st] <= 0)
    {
        mus_edit_step = -1;
        ui_text(_gx, _py + 15, "Click on the grid to add a note. Pick a note to set its length, chord and effect.", global.TH.text_faint, fa_left, fa_middle, global.f_small, 1);
        return;
    }
    if (keyboard_check_pressed(vk_delete) && ui_focus == "")
    {
        undo_mark("musnotedel" + string(current_time));
        _lp.notes[_st] = 0;
        music_loop_touched(_lp);
        mus_edit_step = -1;
        return;
    }
    var _px2 = _x1;
    ui_text(_px2, _py + 15, music_note_name(_lp.notes[_st]) + "  step " + string(_st + 1), global.TH.text, fa_left, fa_middle, global.f_bold, 1);
    _px2 += 110;
    ui_text(_px2, _py + 15, "Length", global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
    var _nlen = ui_stepper("mus_nlen", _px2 + 46, _py, 96, music_note_length(_lp, _st), 1, MUS_STEPS - _st, "Note length|How many steps the note is held (the SID gate is on); then its release fades it out.");
    if (_nlen != music_note_length(_lp, _st))
    {
        undo_mark("musnlen");
        _lp.lengths[_st] = _nlen;
        mus_note_len = _nlen;
        music_loop_touched(_lp);
    }
    _px2 += 152;
    ui_text(_px2, _py + 15, "Chord", global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
    var _ci = 0;
    for (var c = 0; c < array_length(global.MUS_CHORD_CODES); c++) { if (global.MUS_CHORD_CODES[c] == _lp.arps[_st]) { _ci = c; } }
    var _nci = ui_dropdown("mus_nchord", _px2 + 42, _py, 96, 30, global.MUS_CHORD_NAMES, _ci, "Chord|Plays the note as a chord: the SID voice steps through 3 notes, one each frame - the classic C64 arpeggio.");
    if (global.MUS_CHORD_CODES[_nci] != _lp.arps[_st])
    {
        undo_mark("musnchord" + string(current_time));
        _lp.arps[_st] = global.MUS_CHORD_CODES[_nci];
        music_loop_touched(_lp);
    }
    _px2 += 146;
    ui_text(_px2, _py + 15, "Effect", global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
    var _nfx = ui_dropdown("mus_nfx", _px2 + 44, _py, 150, 30, global.MUS_FX_NAMES, clamp(_lp.fx[_st], 0, 4), "Effect|Slide up or down bends the pitch, vibrato wobbles it, glide slides from the note before without starting it again.");
    if (_nfx != _lp.fx[_st])
    {
        undo_mark("musnfx" + string(current_time));
        _lp.fx[_st] = _nfx;
        if (_lp.fxp[_st] == 0) { _lp.fxp[_st] = 8; }
        music_loop_touched(_lp);
    }
    _px2 += 202;
    if (_lp.fx[_st] > 0)
    {
        ui_text(_px2, _py + 15, "Amount", global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
        var _nfp = ui_stepper("mus_nfxp", _px2 + 54, _py, 96, _lp.fxp[_st], 1, 255, "Effect amount|How strong the slide, vibrato or glide is. Hold Shift for steps of 10.");
        if (_nfp != _lp.fxp[_st])
        {
            undo_mark("musnfxp");
            _lp.fxp[_st] = _nfp;
            music_loop_touched(_lp);
        }
    }
}

// ---------------------------------------------------------------------------
// Where the music plays
// ---------------------------------------------------------------------------

function music_where_draw(_x1, _y1, _x2, _y2)
{
    ui_rrect(_x1, _y1, _x2, _y2, 10, global.TH.btn_top, global.TH.panel_bot, 0.6);
    ui_text(_x1 + 16, _y1 + 18, "Where the music plays", global.TH.text, fa_left, fa_middle, global.f_bold, 1);
    var _opts = music_song_options();
    var _y = _y1 + 42;
    if (proj.game_type == 1)
    {
        var _nl = min(MUS_LEVELS, array_length(proj.levels));
        var _cw = floor((_x2 - _x1 - 32 - 12) / 2);
        for (var l = 0; l < _nl; l++)
        {
            var _cx = _x1 + 16 + (l mod 2) * (_cw + 12);
            var _cy = _y + (l div 2) * 38;
            if (_cy + 32 > _y2 - 40) { break; }
            ui_text(_cx, _cy + 15, ui_text_fit(string(l + 1) + ". " + proj.levels[l].name, global.f_body, 130), global.TH.text_dim, fa_left, fa_middle, global.f_body, 1);
            var _v = ui_dropdown("mus_lvl_" + string(l), _cx + 136, _cy, _cw - 136, 30, _opts, proj.level_song[l] + 1, "Level " + string(l + 1) + " music|The song that plays on this level. If it is the same song as the level before, it carries on without starting again.");
            if (_v - 1 != proj.level_song[l])
            {
                undo_mark("muslvl" + string(current_time));
                proj.level_song[l] = _v - 1;
            }
        }
        _y += ceil(_nl / 2) * 38 + 6;
        ui_text_wrap(_x1 + 16, min(_y, _y2 - 44), "The music stops at game over and when the player wins. Sound effects borrow voice 1 or 2 while they play, then the music has it back.", global.TH.text_faint, _x2 - _x1 - 32, global.f_small, 1);
    }
    else
    {
        ui_text(_x1 + 16, _y + 15, "Your game's screen", global.TH.text_dim, fa_left, fa_middle, global.f_body, 1);
        draw_set_font(global.f_body);
        var _v2 = ui_dropdown("mus_lvl_0", _x1 + 28 + ceil(ui_sw("Your game's screen")), _y, 220, 30, _opts, proj.level_song[0] + 1, "Screen music|The song that starts with the game (and again after game over).");
        if (_v2 - 1 != proj.level_song[0])
        {
            undo_mark("muslvl" + string(current_time));
            proj.level_song[0] = _v2 - 1;
        }
        _y += 44;
        ui_text_wrap(_x1 + 16, _y, "To change the music during the game, use Play music and Stop music on the Logic page - say, a boss tune when the score reaches 500. The music stops on the game over and win screens. Sound effects borrow voice 1 or 2 while they play, then the music has it back.", global.TH.text_faint, _x2 - _x1 - 32, global.f_small, 1);
        if (ui_button("mus_to_logic", _x2 - 150, _y1 + 6, 136, 28, "Open Logic", "Logic page|Make rules that play or stop songs.", BTN_GHOST)) { ws_set(WS_LOGIC); }
    }
}
