/// C64 ENGINE - Music workspace (ADAM's Music page, for the SID's 3 voices)
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
// ProTracker .mod (scr_mod does the converting)
// ---------------------------------------------------------------------------

function music_import_mod()
{
    if (array_length(proj.songs) >= MUS_SONG_MAX)
    {
        toast("A game can have up to " + string(MUS_SONG_MAX) + " songs - delete one first", 1);
        return;
    }
    var _f = get_open_filename("ProTracker module|*.mod", "");
    if (_f == "") { return; }
    var _ms = mod_read(_f);
    if (is_undefined(_ms)) { return; }
    var _res = music_mod_import(_ms, filename_change_ext(filename_name(_f), ""));
    var _s = _res.song;
    if (array_length(_s.arr.loops) == 0)
    {
        toast("That module has no notes the SID can play", 2);
        return;
    }
    music_preview_stop();
    undo_mark("musimport" + string(current_time));
    array_push(proj.songs, _s);
    mus_song = array_length(proj.songs) - 1;
    mus_edit = -1;
    mus_xoff = 0;
    mus_from = 0;
    mus_cat = 5;
    if (array_length(proj.songs) == 1 && proj.level_song[0] < 0) { proj.level_song[0] = 0; }
    toast("Imported " + filename_name(_f) + ": " + string(_s.arr.bars) + " bars, " + string(array_length(_s.arr.loops)) + " loops", 0);
    for (var i = 0; i < min(3, array_length(_res.warnings)); i++) { toast(_res.warnings[i], 1); }
}

function music_export_mod(_song)
{
    var _f = get_save_filename("ProTracker module|*.mod", string_replace_all(_song.name, " ", "_") + ".mod");
    if (_f == "") { return; }
    if (string_lower(filename_ext(_f)) != ".mod") { _f += ".mod"; }
    var _res = music_mod_export(_song);
    if (!mod_save_file(_res.ms, _f))
    {
        toast("Could not save " + filename_name(_f), 2);
        return;
    }
    toast("Saved " + filename_name(_f) + " (" + string(mod_size(_res.ms)) + " bytes)", 0);
    for (var i = 0; i < min(3, array_length(_res.warnings)); i++) { toast(_res.warnings[i], 1); }
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
    var L = ["; PSID tune made by " + APP_NAME, "* = $1000", " jmp psid_init", " jmp mus_update",
             "psid_init:", " pha", " lda #$0f", " sta $d418", " lda #0", " sta $d417", " pla", " jmp mus_play"];
    music_emit(L, _p);
    array_push(L, "sv_t:", " .fill 8,0");
    // no sound effects or patches play in a tune: the driver's checks for them find none
    if (patch_any(_p)) { array_push(L, "pt_on:", " .fill 1,0", "pt_vm:", " .fill 1,0", "pt_vbit:", " .fill 15,0"); }
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
    _wstr(_b, APP_NAME);
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
    mus_ed_keys_hover = false;
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
        if (ui_button("mus_first", _mx - 186, _my + 34, 180, 40, "New song", "New song|Makes a song with drums, chords, a tune and a bass line to start from.", BTN_ACCENT)) { music_song_add(); }
        if (ui_button("mus_first_mod", _mx + 6, _my + 34, 180, 40, "Import .mod", "Import a MOD|Brings in a ProTracker .mod as a new song, turned into SID voices, instruments and loops.", BTN_NORMAL)) { music_import_mod(); }
        return;
    }
    var _s = proj.songs[mus_song];
    if (keyboard_check_pressed(vk_space) && ui_focus == "" && ui_can_input() && !keyboard_check(vk_control))
    {
        if (mus_playing) { music_preview_stop(); }
        else if (mus_edit >= 0 && mus_edit < array_length(_s.arr.loops)) { music_preview_loop(_s.arr.loops[mus_edit], true, "edit"); }
        else { music_preview_song(_s); }
    }

    // ---------------- toolbar row 1: the song ----------------
    var _tx = _cx1 + 18;
    var _ty = _y1 + 54;
    var _ns = ui_dropdown("mus_songs", _tx, _ty, 180, 32, music_song_names(), mus_song, "Song|Which song you are working on. A game can have up to " + string(MUS_SONG_MAX) + ".");
    if (_ns != mus_song)
    {
        mus_song = _ns;
        mus_edit = -1;
        mus_xoff = 0;
        mus_from = 0;
        music_preview_stop();
        _s = proj.songs[mus_song];
    }
    _tx += 188;
    if (ui_button("mus_new", _tx, _ty, 64, 32, "New", "New song|Makes another song, with a starter arrangement to change.", BTN_NORMAL)) { music_song_add(); _s = proj.songs[mus_song]; }
    _tx += 72;
    set_val(_s, "name", ui_textfield("mus_name", _tx, _ty, 150, 32, _s.name, 20, "Song name|Shown on the Logic page and in the level list."), "musname");
    _tx += 158;
    if (ui_button("mus_del", _tx, _ty, 76, 32, "Delete", "Delete song|Removes this song. Levels and rules that played it stop playing music. Undo brings it back.", BTN_DANGER))
    {
        music_song_remove();
        return;
    }
    _tx += 84;
    if (ui_button("mus_imod", _tx, _ty, 110, 32, "Import .mod", "Import a MOD|Brings in a ProTracker .mod as a new song. Its 3 busiest channels become the SID voices, its samples become SID instruments (drums by name or sound, tunes by pitch) and its patterns become loops you can edit.", BTN_GHOST))
    {
        music_import_mod();
        return;
    }
    _tx += 118;
    if (ui_button("mus_smod", _tx, _ty, 100, 32, "Save .mod", "Save as a MOD|Saves this song as a 4-channel ProTracker .mod (the 4th channel stays empty), each SID instrument recorded as a sample - for Amiga trackers, OpenMPT and friends.", BTN_GHOST))
    {
        music_export_mod(_s);
    }
    _tx += 108;
    if (ui_button("mus_sid", _tx, _ty, 100, 32, "Save .SID", "Save as a SID tune|Saves all your songs as a .SID file (PSID) - the format C64 music collections use. Play it in VICE's VSID, SIDPlay or on a C64 Ultimate.", BTN_GHOST))
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
    if (mus_edit >= 0) { _lane_h = 24; }
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
    // (while a loop is open the editor needs the room)
    if (mus_edit >= 0) { return _sy + 10; }
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

/// Undo point for an edit of loop _lp: an edited library loop becomes the song's own (Mine)
function music_loop_edit_begin(_lp, _tag)
{
    undo_mark(_tag);
    _lp.lib = -1;
}

/// Plays one note of instrument _inst (with an effect) on its own, once
function music_preview_note(_inst, _note, _fx = 0, _fxp = 0, _drum = false)
{
    var _l = loop_new("Note", 3, _inst);
    _l.notes[0] = clamp(_note, 1, MUS_NOTE_MAX);
    _l.insts[0] = _inst;
    _l.lengths[0] = 8;
    if (_drum || (_inst >= 0 && _inst < array_length(global.MUS_INST) && global.MUS_INST[_inst].fix > 0)) { _l.cat = 0; }
    if (_fx > 0 && _fx != 4)
    {
        _l.fx[0] = _fx;
        _l.fxp[0] = _fxp;
        _l.fx_end[0] = 11;
    }
    var _t = song_new("Note");
    if (array_length(proj.songs) > 0) { _t.speed = proj.songs[clamp(mus_song, 0, array_length(proj.songs) - 1)].speed; }
    _t.arr.loops = [_l];
    _t.arr.bars = 1;
    _t.arr.lanes[0][0] = 0;
    music_preview_start(music_compile([_t], [0]), 0, 0, true, "note");
}

/// The note a drum row plays (drums play at their own pitch; a sound plays its own note)
function music_inst_root(_id)
{
    return MUS_ROOT;
}

/// A short name for a drum row
function music_inst_short(_id)
{
    if (_id >= MUS_INST_USER)
    {
        var _k = _id - MUS_INST_USER;
        if (_k >= 0 && _k < array_length(proj.sfx)) { return string(_k + 1) + ". " + proj.sfx[_k].name; }
        return "Sound";
    }
    if (_id >= 0 && _id < array_length(global.MUS_INST)) { return global.MUS_INST[_id].name; }
    return "?";
}

/// A Sound page sound made from built-in instrument _id (Edit sound)
function music_inst_sfx(_id)
{
    var _in = global.MUS_INST[clamp(_id, 0, array_length(global.MUS_INST) - 1)];
    var _s = sfx_new(_in.name);
    _s.wave = 2;
    for (var w = 0; w < array_length(global.WAVE_BITS); w++)
    {
        if (global.WAVE_BITS[w] == _in.w) { _s.wave = w; }
    }
    _s.atk = (_in.ad >> 4) & 15;
    _s.dec = _in.ad & 15;
    _s.sus = (_in.sr >> 4) & 15;
    _s.rel = _in.sr & 15;
    _s.pw = clamp(_in.pw, 0, 4095);
    _s.pws = clamp(_in.pws, -64, 64);
    _s.sweep = clamp(_in.sweep, -8, 8);
    _s.pitch = 60;
    if (_in.fix > 0) { _s.pitch = _in.fix; }
    _s.len = 12;
    return _s;
}

/// Edit sound: copies the loop's built-in instrument into a Sound page sound, and the loop plays that
function music_inst_to_sound(_lp, _slot)
{
    var _id = _lp.inst;
    music_loop_edit_begin(_lp, "musinstedit" + string(current_time));
    var _snd = music_inst_sfx(_id);
    if (_slot >= array_length(proj.sfx)) { array_push(proj.sfx, _snd); _slot = array_length(proj.sfx) - 1; }
    else
    {
        _snd.group = proj.sfx[_slot].group;
        proj.sfx[_slot] = _snd;
    }
    var _uid = MUS_INST_USER + _slot;
    // Sound page sounds play an octave up from the note (built-in instruments have their own octave)
    var _shift = global.MUS_INST[_id].tr - 12;
    _lp.inst = _uid;
    for (var s = 0; s < MUS_STEPS; s++)
    {
        if (_lp.insts[s] == _id) { _lp.insts[s] = _uid; }
        if (_lp.notes[s] > 0 && _lp.cat != 0) { _lp.notes[s] = clamp(_lp.notes[s] + _shift, 1, MUS_NOTE_MAX); }
    }
    snd_sel = _slot;
    project_after_change();
    toast(_snd.name + " is now Sound " + string(_slot + 1) + " - change it on the Sound page", 0);
}

/// Puts (mode 1) or removes (mode 0) a note at a step of the open loop.
/// _length: steps a new note lasts (0 = the default); existing notes keep theirs
function music_ed_apply(_lp, _st, _rv, _drums, _mode, _length)
{
    if (_mode == 1)
    {
        var _note = _rv;
        var _inst = _lp.inst;
        if (_drums)
        {
            _inst = _rv;
            _note = music_inst_root(_rv);
        }
        if (_lp.notes[_st] == _note && _lp.insts[_st] == _inst) { return; }
        music_loop_edit_begin(_lp, mus_ed_tag);
        _lp.notes[_st] = _note;
        _lp.lengths[_st] = clamp(_length, 0, MUS_STEPS - _st);
        _lp.insts[_st] = _inst;
    }
    else
    {
        var _match = false;
        if (_drums) { _match = (_lp.notes[_st] > 0 && _lp.insts[_st] == _rv); }
        else { _match = (_lp.notes[_st] == _rv); }
        if (!_match) { return; }
        music_loop_edit_begin(_lp, mus_ed_tag);
        music_step_clear(_lp, _st);
    }
}

/// The step editor (ADAM's, for the SID): a piano roll or drum grid with snap, selection,
/// copy and paste, linked bends, the effect row and the chord row
function music_editor_draw(_x1, _y1, _x2, _y2, _s, _lp)
{
    var _drums = (_lp.cat == 0);
    if (mus_ed_select_ref != _lp)
    {
        mus_ed_resize_step = -1;
        mus_ed_select_ref = _lp;
        mus_ed_selected = array_create(MUS_STEPS, false);
        mus_ed_select_drag = false;
    }
    var _col = global.MUS_CAT_COLS[_lp.cat];
    ui_rrect(_x1, _y1, _x2, _y2, 10, global.TH.btn_top, global.TH.panel_bot, 0.6);
    ui_rrect(_x1, _y1 + 10, _x1 + 4, _y2 - 10, 2, _col, _col, 1);

    // ---------- header ----------
    var _hx = _x1 + 14;
    var _hy = _y1 + 8;
    var _nm = ui_textfield("mus_lname", _hx, _hy, 150, 30, _lp.name, 24, "Loop name|Shown on the timeline and in the Mine list.");
    if (_nm != _lp.name) { music_loop_edit_begin(_lp, "muslname"); _lp.name = _nm; }
    _hx += 158;
    if (_drums)
    {
        ui_text(_hx + 4, _hy + 15, "Drums", global.TH.text_dim, fa_left, fa_middle, global.f_bold, 1);
        _hx += 64;
    }
    else
    {
        var _cats = ["Bass", "Chords", "Lead", "FX"];
        var _nc = ui_dropdown("mus_lcat", _hx, _hy, 90, 30, _cats, _lp.cat - 1, "Kind of loop|Sorts it in the library and colours it on the timeline.");
        set_val(_lp, "cat", _nc + 1, "muslcat");
        _hx += 98;
        var _ids = music_inst_ids();
        var _names = [];
        var _cur = 0;
        for (var i = 0; i < array_length(_ids); i++)
        {
            array_push(_names, music_inst_name(_ids[i]));
            if (_ids[i] == _lp.inst) { _cur = i; }
        }
        var _ni = ui_dropdown("mus_linst", _hx, _hy, 170, 30, _names, _cur, "Instrument|The SID sound the notes play with: built-in instruments first, then the synth sounds from your Sound page (their waveform, pulse, envelope and slide).");
        if (_ids[_ni] != _lp.inst)
        {
            music_loop_edit_begin(_lp, "muslinst" + string(current_time));
            _lp.inst = _ids[_ni];
            for (var s0 = 0; s0 < MUS_STEPS; s0++) { _lp.insts[s0] = _lp.inst; }
            music_preview_note(_lp.inst, 25);
        }
        _hx += 178;
        if (_lp.inst < MUS_INST_USER)
        {
            // a new sound when there is room, else the one selected on the Sound page
            var _slot = array_length(proj.sfx);
            var _adds = (_slot < SFX_MAX);
            if (!_adds) { _slot = clamp(snd_sel, 0, SFX_MAX - 1); }
            var _ed_tip = "Edit sound|Copies " + music_inst_name(_lp.inst) + " into a new sound on the Sound page, so you can change it. This loop then plays that sound. Undo brings it back.";
            if (!_adds) { _ed_tip = "Edit sound|Copies " + music_inst_name(_lp.inst) + " into Sound " + string(_slot + 1) + " (the one selected on the Sound page - there is no room for another), replacing it. This loop then plays it. Undo brings it back."; }
            if (ui_button("mus_inst_edit", _hx, _hy, 90, 30, "Edit sound", _ed_tip, BTN_GHOST)) { music_inst_to_sound(_lp, _slot); }
            _hx += 98;
        }
    }
    var _lis = (mus_playing && mus_play_what == "edit");
    var _ll = "Listen";
    if (_lis) { _ll = "Stop"; }
    if (ui_button("mus_listen", _hx, _hy, 70, 30, _ll, "Listen|Plays this loop on its own, over and over, as you edit it. Space does the same.", BTN_ACCENT))
    {
        if (_lis) { music_preview_stop(); }
        else { music_preview_loop(_lp, true, "edit"); }
    }
    _hx += 78;
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
    }
    var _rx = _x2 - 10;
    if (ui_button("mus_close", _rx - 70, _hy, 70, 30, "Close", "Close the editor|Back to where the music plays. Double-click any bar to edit again.", BTN_NORMAL))
    {
        mus_edit = -1;
        if (mus_play_what == "edit") { music_preview_stop(); }
        return;
    }
    _rx -= 78;
    if (ui_button("mus_ldel", _rx - 70, _hy, 70, 30, "Delete", "Delete this loop|Takes it out of the song, and out of every bar it plays in. Undo brings it back.", BTN_DANGER))
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
    if (ui_button("mus_clear", _rx - 64, _hy, 64, 30, "Clear", "Clear loop|Removes every note, chord, effect and bend link from this loop. Undo brings them back.", BTN_GHOST))
    {
        music_loop_edit_begin(_lp, "musclear" + string(current_time));
        for (var s1 = 0; s1 < MUS_STEPS; s1++) { music_step_clear(_lp, s1); }
        mus_ed_selected = array_create(MUS_STEPS, false);
        var _tc = "Loop cleared";
        if (_uses > 1) { _tc += " in all " + string(_uses) + " bars that play it"; }
        toast(_tc + " - Undo brings it back", 0);
    }

    var _tip = "Used in " + string(_uses) + " bar";
    if (_uses != 1) { _tip += "s"; }
    if (_drums) { _tip += "  -  one hit per step: click to add or remove, drag to paint, right-click to rub out. One SID voice plays one sound at a time."; }
    else { _tip += "  -  one note per step: click to place, drag to move; drag a note's circle to a later note to link a bend. Chords play as fast arpeggios."; }
    // the line under: what to do, the selected effect amount, and snap
    var _res_x = _x2 - 112;
    var _res_y = _y1 + 44;
    var _pw = 0;
    if (_lp.fx[clamp(mus_ed_fx_step, 0, MUS_STEPS - 1)] > 0) { _pw = music_ed_fx_param(_lp, _res_x - 12, _res_y - 3); }
    ui_text(_x1 + 14, _res_y + 12, ui_text_fit(_tip, global.f_small, _res_x - 24 - _pw - _x1 - 14), global.TH.text_faint, fa_left, fa_middle, global.f_small, 1);

    // ---------- snap ----------
    var _res_label = "Snap 1/" + string(mus_ed_resolution);
    if (keyboard_check(vk_alt)) { _res_label = "No snap"; }
    var _res_tip = "Grid snap|Choose 4, 8, 16 or 32 places a bar for notes to start; new notes last one snap step. Click for coarser, right-click for finer. Keys 1-4 pick 1/32, 1/16, 1/8 or 1/4 while the mouse is over the editor. Hold Alt to place, move or resize without snap.";
    if (!_drums && ui_hit(_x1, _y1, _x2, _y2))
    {
        mus_ed_keys_hover = true;
        if (ui_focus == "" && !keyboard_check(vk_control))
        {
            var _key_snaps = [32, 16, 8, 4];
            for (var _ks = 0; _ks < 4; _ks++)
            {
                if (keyboard_check_pressed(ord(string(_ks + 1)))) { mus_ed_resolution = _key_snaps[_ks]; }
            }
        }
    }
    var _snap_dir = 0;
    if (!_drums && ui_button("mus_ed_resolution", _res_x, _res_y, 100, 24, _res_label, _res_tip, BTN_GHOST)) { _snap_dir = -1; }
    if (!_drums && ui_rpressed && ui_hit(_res_x, _res_y, _res_x + 100, _res_y + 24)) { _snap_dir = 1; }
    if (_snap_dir != 0)
    {
        var _snap_values = [4, 8, 16, 32];
        var _snap_idx = 0;
        for (var si = 0; si < 4; si++)
        {
            if (_snap_values[si] == mus_ed_resolution) { _snap_idx = si; }
        }
        mus_ed_resolution = _snap_values[(_snap_idx + _snap_dir + 4) mod 4];
    }

    // ---------- grid ----------
    var _gx1 = _x1 + 10;
    var _gx2 = _x2 - 10;
    var _gy1 = _y1 + 74;
    var _gy2 = _y2 - 8;
    if (!_drums) { _gy2 -= 60; }
    else { _gy2 -= 32; }
    if (_gy2 - _gy1 < 30) { return; }
    var _lab = 92;
    var _snap_stride = 2;
    if (!_drums) { _snap_stride = MUS_STEPS div mus_ed_resolution; }
    if (keyboard_check(vk_alt)) { _snap_stride = 1; }
    var _new_len = 0;
    if (!_drums) { _new_len = _snap_stride; }
    var _cw = max(6, (_gx2 - _gx1 - _lab - 16) / MUS_STEPS);
    var _rows = [];
    var _rh = 16;
    if (_drums)
    {
        music_drum_rows_refresh();
        _rows = global.MUS_DRUM_ROWS;
        _rh = 22;
    }
    else
    {
        for (var n = MUS_NOTE_MAX; n >= 1; n--) { array_push(_rows, n); }
        if (_gy2 - _gy1 < 168) { _rh = 13; }
    }
    var _nr = array_length(_rows);
    var _sid = "mus_ed_roll";
    if (_drums) { _sid = "mus_ed_drums"; }
    var _content = _nr * _rh;
    // opening a loop: scroll to its notes
    var _seen = string(mus_song) + "_" + string(mus_edit);
    if (mus_edit_seen != _seen)
    {
        mus_edit_seen = _seen;
        if (!_drums)
        {
            var _lo = 99, _hi = 0;
            for (var q = 0; q < MUS_STEPS; q++)
            {
                if (_lp.notes[q] > 0)
                {
                    _lo = min(_lo, _lp.notes[q]);
                    _hi = max(_hi, _lp.notes[q]);
                }
            }
            if (_hi == 0) { _lo = 25; _hi = 25; }
            ds_map_replace(ui_scroll, _sid, max(0, (MUS_NOTE_MAX - (_lo + _hi) * 0.5) * _rh - (_gy2 - _gy1) * 0.5));
        }
    }
    var _off = ui_scroll_begin(_sid, _gx1, _gy1, _gx2, _gy2, _content);
    var _sx = _gx1 + _lab;
    var _sx2 = _sx + _cw * MUS_STEPS;
    if (mus_ed_select_drag && ui_held && ui_mx >= _sx && ui_mx <= _sx2)
    {
        if (ui_my < _gy1 + 12) { _off -= 6; }
        if (ui_my > _gy2 - 12) { _off += 6; }
        _off = clamp(_off, 0, max(0, _content - (_gy2 - _gy1)));
        ds_map_replace(ui_scroll, _sid, _off);
    }
    var _grid_note = "Snap sets where new notes go and how long they last (keys 1-4; hold Alt for no snap). Shift-drag a note's right edge to make it longer or shorter; Ctrl+D deselects.";
    var _grid_help = "Notes|" + _grid_note + " Ctrl-drag a box to select notes, Ctrl+C to copy them (or the note under the mouse), Ctrl-drag a note to clone it, Ctrl+V to paste at the mouse. Drag a note to move it, or its circle onto a later note to link a bend. Hold Alt over a note to hear it. One SID voice plays one note at a time: a note stops when the next one starts.";
    if (_drums) { _grid_help = "Drum grid|Click to put a hit on a step, click it again to take it off; drag to paint, right-click to rub out. The rows are the built-in drums and effects, then every synth sound on your Sound page. Ctrl-drag a box to select, Ctrl+C / Ctrl+V to copy and paste, Ctrl-drag a hit to clone it."; }
    ui_register("mus_ed_grid", _sx, _gy1, _sx2, _gy2, _grid_help);
    var _hr = -1;
    var _hs = -1;
    if (ui_hit(_sx, _gy1, _sx2, _gy2))
    {
        _hr = floor((ui_my - _gy1 + _off) / _rh);
        _hs = floor((ui_mx - _sx) / _cw);
        if (_hr < 0 || _hr >= _nr || _hs < 0 || _hs >= MUS_STEPS)
        {
            _hr = -1;
            _hs = -1;
        }
    }
    if (_hr >= 0)
    {
        var _raw_hit = _hs;
        _hs = (_raw_hit div _snap_stride) * _snap_stride;
        for (var _note_hit = 0; _note_hit < MUS_STEPS; _note_hit++)
        {
            if (_lp.notes[_note_hit] <= 0 || music_note_row(_lp, _note_hit, _drums) != _hr) { continue; }
            if (ui_mx >= _sx + _note_hit * _cw && ui_mx < _sx + (_note_hit + music_note_length(_lp, _note_hit)) * _cw) { _hs = _note_hit; }
        }
    }
    var _select_this_frame = mus_ed_select_drag;
    var _on_note = false;
    if (_hr >= 0 && _hs >= 0)
    {
        if (_drums) { _on_note = (_lp.notes[_hs] > 0 && _lp.insts[_hs] == _rows[_hr]); }
        else { _on_note = (_lp.notes[_hs] == _rows[_hr]); }
    }
    // Ctrl-drag on an empty spot: a selection box
    if (ui_pressed && keyboard_check(vk_control) && _hr >= 0 && !_on_note)
    {
        ui_take_click();
        ui_focus = "";
        mus_ed_select_drag = true;
        _select_this_frame = true;
        mus_ed_selected = array_create(MUS_STEPS, false);
        mus_ed_select_start = [ui_mx - _sx, ui_my - _gy1 + _off];
        mus_ed_select_end = mus_ed_select_start;
        mus_ed_note_drag = false;
        mus_ed_note_glide = false;
        mus_ed_fx_drag = false;
        mus_ed_painting = false;
        mus_ed_rclear = false;
    }
    if (mus_ed_select_drag)
    {
        mus_ed_select_end = [clamp(ui_mx - _sx, 0, _sx2 - _sx), clamp(ui_my, _gy1, _gy2) - _gy1 + _off];
        mus_ed_selected = music_notes_in_box(_lp, _drums, _cw, _rh, [mus_ed_select_start[0], mus_ed_select_start[1], mus_ed_select_end[0], mus_ed_select_end[1]]);
        if (!ui_held) { mus_ed_select_drag = false; }
    }
    if (!_select_this_frame && ui_focus == "" && ui_can_input() && keyboard_check(vk_control))
    {
        if (keyboard_check_pressed(ord("D")) && !mus_ed_note_drag) { mus_ed_selected = array_create(MUS_STEPS, false); }
        if (keyboard_check_pressed(ord("C")) && ui_hit(_x1, _y1, _x2, _y2))
        {
            // the note under the mouse, unless it is part of the selection
            var _copy_sel = mus_ed_selected;
            if (_on_note && !mus_ed_selected[_hs])
            {
                _copy_sel = array_create(MUS_STEPS, false);
                _copy_sel[_hs] = true;
            }
            var _copied = music_notes_copy(_lp, _copy_sel, _drums);
            var _ncp = array_length(_copied.notes);
            if (_ncp > 0)
            {
                mus_ed_clip = _copied;
                if (_ncp == 1) { toast("Copied 1 note", 0); }
                else { toast("Copied " + string(_ncp) + " notes", 0); }
            }
            else { toast("Hover a note or Ctrl-drag a box over some notes first", 0); }
        }
        if (keyboard_check_pressed(ord("V")) && _hr >= 0)
        {
            if (mus_ed_clip.drums != _drums) { toast("Paste into the same kind of grid: notes or drums", 1); }
            else
            {
                var _preview = music_notes_paste(_lp, mus_ed_clip, _hs, _hr, _drums, false);
                if (_preview.count > 0)
                {
                    music_loop_edit_begin(_lp, "musnotepaste" + string(current_time));
                    var _pasted = music_notes_paste(_lp, mus_ed_clip, _hs, _hr, _drums);
                    mus_ed_selected = _pasted.selected;
                }
                else { toast("Copy some notes first, then paste where they fit", 0); }
            }
        }
    }
    var _play_step = -1;
    var _hit_handle_step = -1;
    var _hit_handle_row = -1;
    var _hit_handle_distance = 9;
    var _hit_resize_step = -1;
    var _glide_col = make_colour_rgb(80, 220, 120);
    var _glide_drop_step = -1;
    var _glide_drop_row = -1;
    if (mus_ed_note_glide && !_drums && ui_my >= _gy1 && ui_my < _gy2)
    {
        for (var _target_step = 0; _target_step < MUS_STEPS; _target_step++)
        {
            if (_target_step <= mus_ed_note_src[0] || _lp.notes[_target_step] <= 0) { continue; }
            var _target_row = MUS_NOTE_MAX - _lp.notes[_target_step];
            var _target_x = _sx + _target_step * _cw;
            var _target_y = _gy1 + _target_row * _rh - _off;
            if (ui_hit(_target_x + 2, _target_y + 2, _target_x + music_note_length(_lp, _target_step) * _cw - 2, _target_y + _rh - 2)
                || point_distance(ui_mx, ui_my, _target_x + 2, _target_y + _rh * 0.5) <= 7)
            {
                _glide_drop_step = _target_step;
                _glide_drop_row = _target_row;
                break;
            }
        }
    }
    if (mus_playing && mus_play_what == "edit")
    {
        var _pos = music_preview_pos();
        if (_pos >= 0) { _play_step = floor((_pos - floor(_pos)) * MUS_STEPS); }
    }
    var _beat_cells = MUS_STEPS div 4;
    for (var r = 0; r < _nr; r++)
    {
        var _ry = _gy1 + r * _rh - _off;
        if (_ry + _rh < _gy1 || _ry > _gy2) { continue; }
        var _rv = _rows[r];
        var _lname = "";
        var _black = false;
        if (_drums) { _lname = music_inst_short(_rv); }
        else
        {
            _lname = music_note_name(_rv);
            var _semi = (_rv - 1) mod 12;
            _black = (_semi == 1 || _semi == 3 || _semi == 6 || _semi == 8 || _semi == 10);
        }
        var _lc = global.TH.text_dim;
        if (!_drums && (_rv - 1) mod 12 == 0) { _lc = global.TH.text; }
        if (_black) { _lc = global.TH.text_faint; }
        ui_text(_gx1 + 6, _ry + _rh * 0.5, ui_text_fit(_lname, global.f_small, _lab - 12), _lc, fa_left, fa_middle, global.f_small, 1);
        // cells and grid lines first, so long notes are drawn over them
        for (var _gst = 0; _gst < MUS_STEPS; _gst++)
        {
            var _gcx = _sx + _gst * _cw;
            var _ba = 0.10;
            if ((_gst div _beat_cells) mod 2 == 1) { _ba = 0.05; }
            if (_black) { _ba *= 0.5; }
            if (_gst == _play_step) { _ba += 0.12; }
            draw_set_alpha(_ba);
            draw_rectangle_colour(_gcx + 1, _ry + 1, _gcx + _cw - 1, _ry + _rh - 1, c_white, c_white, c_white, c_white, false);
            // beat lines brightest, snap lines clear, other steps faint
            var _la = 0.06;
            if (_gst mod _snap_stride == 0) { _la = 0.30; }
            if (_gst mod _beat_cells == 0) { _la = 0.55; }
            draw_set_alpha(_la);
            draw_line_colour(_gcx, _ry, _gcx, _ry + _rh, c_white, c_white);
            draw_set_alpha(1);
        }
        for (var st = 0; st < MUS_STEPS; st++)
        {
            var _cx = _sx + st * _cw;
            var _on = false;
            if (_drums) { _on = (_lp.notes[st] > 0 && _lp.insts[st] == _rv); }
            else { _on = (_lp.notes[st] == _rv); }
            if (_on)
            {
                var _note_w = music_note_length(_lp, st) * _cw;
                if (_drums && keyboard_check(vk_shift) && point_distance(ui_mx, ui_my, _cx + _note_w - 2, _ry + _rh * 0.5) <= 9 && ui_my >= _gy1 && ui_my < _gy2) { _hit_resize_step = st; }
                ui_rrect(_cx + 2, _ry + 2, _cx + _note_w - 2, _ry + _rh - 2, 4, merge_colour(_col, c_white, 0.15), _col, 1);
                if (_lp.arps[st] != 0 && !_drums) { ui_text(_cx + 5, _ry + _rh * 0.5, "+", c_white, fa_left, fa_middle, global.f_small, 1); }
                if (mus_ed_selected[st]) { ui_rrect_line(_cx + 1, _ry + 1, _cx + _note_w - 1, _ry + _rh - 1, 4, c_white, 1, 2); }
                if (!_drums)
                {
                    var _handle_x = _cx + _note_w - 2;
                    var _handle_y = _ry + _rh * 0.5;
                    var _handle_distance = point_distance(ui_mx, ui_my, _handle_x, _handle_y);
                    var _handle_hot = (_handle_distance <= 9);
                    if (keyboard_check(vk_shift) && _handle_hot && ui_my >= _gy1 && ui_my < _gy2) { _hit_resize_step = st; }
                    if (!keyboard_check(vk_shift) && _handle_hot && _handle_distance <= _hit_handle_distance && ui_my >= _gy1 && ui_my < _gy2)
                    {
                        _hit_handle_step = st;
                        _hit_handle_row = r;
                        _hit_handle_distance = _handle_distance;
                    }
                    var _handle_colour = global.TH.accent;
                    var _handle_radius = 4;
                    if (_handle_hot || (mus_ed_note_glide && st == mus_ed_note_src[0]))
                    {
                        _handle_colour = c_white;
                        _handle_radius = 6;
                    }
                    if (!keyboard_check(vk_shift))
                    {
                        draw_circle_colour(_handle_x, _handle_y, _handle_radius + 1, global.TH.panel_bot, global.TH.panel_bot, false);
                        draw_circle_colour(_handle_x, _handle_y, _handle_radius, _handle_colour, _handle_colour, false);
                    }
                    else { draw_line_width_colour(_handle_x, _ry + 3, _handle_x, _ry + _rh - 3, 2, c_white, c_white); }
                }
            }
            if (_on && mus_ed_note_glide && ui_held && st > mus_ed_note_src[0])
            {
                draw_circle_colour(_cx + 2, _ry + _rh * 0.5, 5, global.TH.panel_bot, global.TH.panel_bot, false);
                draw_circle_colour(_cx + 2, _ry + _rh * 0.5, 4, _glide_col, _glide_col, false);
                if (_glide_drop_step == st && _glide_drop_row == r)
                {
                    var _flash_alpha = 0.55 + 0.45 * abs(sin(current_time / 120));
                    draw_set_alpha(_flash_alpha * 0.3);
                    draw_rectangle_colour(_cx + 2, _ry + 2, _cx + _cw - 2, _ry + _rh - 2, _glide_col, _glide_col, _glide_col, _glide_col, false);
                    draw_set_alpha(1);
                    ui_rrect_line(_cx + 1, _ry + 1, _cx + _cw - 1, _ry + _rh - 1, 4, _glide_col, _flash_alpha, 2);
                }
            }
        }
    }
    // hover outline: the note under the mouse, or the note a click would place
    if (_hr >= 0 && _hs >= 0 && !mus_ed_note_drag && !_select_this_frame && mus_ed_resize_step < 0)
    {
        var _hov_len = 0;
        if (_on_note) { _hov_len = music_note_length(_lp, _hs); }
        else
        {
            _hov_len = _new_len;
            if (_hov_len <= 0) { _hov_len = 2; }
            _hov_len = min(_hov_len, MUS_STEPS - _hs);
        }
        var _hov_x = _sx + _hs * _cw;
        var _hov_y = _gy1 + _hr * _rh - _off;
        if (!_on_note)
        {
            draw_set_alpha(0.18);
            draw_rectangle_colour(_hov_x + 2, _hov_y + 2, _hov_x + _hov_len * _cw - 2, _hov_y + _rh - 2, global.TH.accent, global.TH.accent, global.TH.accent, global.TH.accent, false);
            draw_set_alpha(1);
        }
        ui_rrect_line(_hov_x + 1, _hov_y + 1, _hov_x + _hov_len * _cw - 1, _hov_y + _rh - 1, 4, global.TH.accent, 0.9, 1);
    }
    // dragging one note (moved or Ctrl-cloned): a ghost where it will land when let go
    if (mus_ed_note_drag && !mus_ed_note_group && !mus_ed_note_glide && mus_ed_note_last[0] >= 0)
    {
        var _ghost_len = min(music_note_length(_lp, mus_ed_note_src[0]), MUS_STEPS - mus_ed_note_last[0]);
        var _ghost_x = _sx + mus_ed_note_last[0] * _cw;
        var _ghost_y = _gy1 + mus_ed_note_last[1] * _rh - _off;
        ui_rrect(_ghost_x + 2, _ghost_y + 2, _ghost_x + _ghost_len * _cw - 2, _ghost_y + _rh - 2, 4, merge_colour(_col, c_white, 0.15), _col, 0.45);
        ui_rrect_line(_ghost_x + 1, _ghost_y + 1, _ghost_x + _ghost_len * _cw - 1, _ghost_y + _rh - 1, 4, c_white, 0.9, 1);
    }
    // dragging a selection: ghosts of every selected note where they will land
    if (mus_ed_note_drag && mus_ed_note_group && mus_ed_note_last[0] >= 0)
    {
        var _gd_steps = mus_ed_note_last[0] - mus_ed_note_src[0];
        var _gd_rows = mus_ed_note_last[1] - mus_ed_note_src[1];
        for (var _gn = 0; _gn < MUS_STEPS; _gn++)
        {
            if (!mus_ed_selected[_gn] || _lp.notes[_gn] <= 0) { continue; }
            var _gn_to = _gn + _gd_steps;
            if (_gn_to < 0 || _gn_to >= MUS_STEPS) { continue; }
            var _gn_len = min(music_note_length(_lp, _gn), MUS_STEPS - _gn_to);
            var _gn_x = _sx + _gn_to * _cw;
            var _gn_y = _gy1 + (music_note_row(_lp, _gn, _drums) + _gd_rows) * _rh - _off;
            ui_rrect(_gn_x + 2, _gn_y + 2, _gn_x + _gn_len * _cw - 2, _gn_y + _rh - 2, 4, merge_colour(_col, c_white, 0.15), _col, 0.45);
            ui_rrect_line(_gn_x + 1, _gn_y + 1, _gn_x + _gn_len * _cw - 1, _gn_y + _rh - 1, 4, c_white, 0.9, 1);
        }
    }
    // linked bends
    if (!_drums)
    {
        for (var _glide_src = 0; _glide_src < MUS_STEPS; _glide_src++)
        {
            if (!music_glide_valid(_lp, _glide_src)) { continue; }
            var _glide_target = _lp.glide_to[_glide_src];
            var _line_x1 = _sx + (_glide_src + music_note_length(_lp, _glide_src)) * _cw - 2;
            var _line_x2 = _sx + _glide_target * _cw + 2;
            var _line_y1 = _gy1 + (MUS_NOTE_MAX - _lp.notes[_glide_src]) * _rh - _off + _rh * 0.5;
            var _line_y2 = _gy1 + (MUS_NOTE_MAX - _lp.notes[_glide_target]) * _rh - _off + _rh * 0.5;
            draw_line_width_colour(_line_x1, _line_y1, _line_x2, _line_y2, 3, _glide_col, _glide_col);
            if (!keyboard_check(vk_shift))
            {
                draw_circle_colour(_line_x1, _line_y1, 4, _glide_col, _glide_col, false);
                draw_circle_colour(_line_x2, _line_y2, 4, _glide_col, _glide_col, false);
            }
        }
    }
    if (mus_ed_note_glide && ui_held)
    {
        var _src_x = _sx + (mus_ed_note_src[0] + music_note_length(_lp, mus_ed_note_src[0])) * _cw - 2;
        var _src_y = _gy1 + mus_ed_note_src[1] * _rh - _off + _rh * 0.5;
        draw_line_width_colour(_src_x, _src_y, ui_mx, ui_my, 2, _glide_col, _glide_col);
    }
    if (_select_this_frame)
    {
        var _box_x1 = _sx + min(mus_ed_select_start[0], mus_ed_select_end[0]);
        var _box_x2 = _sx + max(mus_ed_select_start[0], mus_ed_select_end[0]);
        var _box_y1 = _gy1 - _off + min(mus_ed_select_start[1], mus_ed_select_end[1]);
        var _box_y2 = _gy1 - _off + max(mus_ed_select_start[1], mus_ed_select_end[1]);
        draw_set_alpha(0.15);
        draw_rectangle_colour(_box_x1, _box_y1, _box_x2, _box_y2, global.TH.accent, global.TH.accent, global.TH.accent, global.TH.accent, false);
        draw_set_alpha(1);
        draw_rectangle_colour(_box_x1, _box_y1, _box_x2, _box_y2, global.TH.accent, global.TH.accent, global.TH.accent, global.TH.accent, true);
    }
    ui_scroll_end(_sid, _gx1, _gy1, _gx2, _gy2, _content);

    // Shift-drag a note's end: its length (every selected note's, when it is selected)
    if (ui_pressed && _hit_resize_step >= 0 && !mus_ed_note_drag)
    {
        ui_take_click();
        mus_ed_resize_step = _hit_resize_step;
        mus_ed_resize_changed = false;
        mus_ed_tag = "musresize" + string(current_time);
        mus_ed_painting = false;
    }
    if (mus_ed_resize_step >= 0)
    {
        if (ui_held)
        {
            var _resize_end = round((ui_mx - _sx) / (_cw * _snap_stride)) * _snap_stride;
            var _resize_len = clamp(_resize_end - mus_ed_resize_step, 1, MUS_STEPS - mus_ed_resize_step);
            if (_resize_len != music_note_length(_lp, mus_ed_resize_step))
            {
                music_loop_edit_begin(_lp, mus_ed_tag);
                _lp.lengths[mus_ed_resize_step] = _resize_len;
                if (mus_ed_selected[mus_ed_resize_step])
                {
                    for (var _rs = 0; _rs < MUS_STEPS; _rs++)
                    {
                        if (mus_ed_selected[_rs] && _lp.notes[_rs] > 0) { _lp.lengths[_rs] = min(_resize_len, MUS_STEPS - _rs); }
                    }
                }
                mus_ed_resize_changed = true;
            }
        }
        else { mus_ed_resize_step = -1; }
    }

    // the circle reaches beyond its cell: grabbing its edge must not paint a note
    if (ui_pressed && !mus_ed_note_drag && !keyboard_check(vk_control) && _hit_handle_step >= 0)
    {
        _hs = _hit_handle_step;
        _hr = _hit_handle_row;
    }
    if (mus_ed_note_glide && _glide_drop_step >= 0)
    {
        _hs = _glide_drop_step;
        _hr = _glide_drop_row;
    }

    // Alt over a note plays it, once until the mouse leaves it
    if (!_select_this_frame && keyboard_check(vk_alt) && _hr >= 0 && _hs >= 0)
    {
        var _alt_row_value = _rows[_hr];
        var _alt_on = false;
        if (_drums) { _alt_on = (_lp.notes[_hs] > 0 && _lp.insts[_hs] == _alt_row_value); }
        else { _alt_on = (_lp.notes[_hs] == _alt_row_value); }
        if (_alt_on)
        {
            if (_hs != mus_ed_alt_preview_step || _hr != mus_ed_alt_preview_row)
            {
                if (_drums) { music_preview_note(_alt_row_value, music_inst_root(_alt_row_value), 0, 0, true); }
                else { music_preview_note(_lp.inst, _lp.notes[_hs], _lp.fx[_hs], _lp.fxp[_hs]); }
            }
            mus_ed_alt_preview_step = _hs;
            mus_ed_alt_preview_row = _hr;
        }
        else
        {
            mus_ed_alt_preview_step = -1;
            mus_ed_alt_preview_row = -1;
        }
    }
    else
    {
        mus_ed_alt_preview_step = -1;
        mus_ed_alt_preview_row = -1;
    }

    if (_hr >= 0 && !_select_this_frame && mus_ed_resize_step < 0)
    {
        var _rv2 = _rows[_hr];
        var _on2 = false;
        if (_drums) { _on2 = (_lp.notes[_hs] > 0 && _lp.insts[_hs] == _rv2); }
        else { _on2 = (_lp.notes[_hs] == _rv2); }
        if (ui_pressed && !mus_ed_note_drag)
        {
            ui_take_click();
            mus_ed_fx_step = _hs;
            mus_ed_tag = "musstep" + string(current_time);
            if (_on2)
            {
                mus_ed_note_drag = true;
                mus_ed_note_copy = keyboard_check(vk_control);
                mus_ed_note_group = (mus_ed_selected[_hs] && !mus_ed_note_copy);
                mus_ed_note_src = [_hs, _hr];
                mus_ed_note_pitch = _lp.notes[_hs];
                mus_ed_note_inst = _lp.insts[_hs];
                if (!_drums) { mus_ed_note_inst = _lp.inst; }
                mus_ed_note_fx = _lp.fx[_hs];
                mus_ed_note_fxp = _lp.fxp[_hs];
                mus_ed_note_moved = false;
                mus_ed_note_last = [-1, -1];
                mus_ed_note_preview_pitch = mus_ed_note_pitch;
                var _note_cell_x = _sx + _hs * _cw;
                var _note_cell_y = _gy1 + _hr * _rh - _off;
                mus_ed_note_glide = (!_drums && !keyboard_check(vk_shift) && !mus_ed_note_copy && point_distance(ui_mx, ui_my, _note_cell_x + music_note_length(_lp, _hs) * _cw - 2, _note_cell_y + _rh * 0.5) <= 9);
                mus_ed_painting = false;
            }
            else
            {
                mus_ed_selected = array_create(MUS_STEPS, false);
                mus_ed_painting = true;
                music_ed_apply(_lp, _hs, _rv2, _drums, 1, _new_len);
                if (_drums) { music_preview_note(_rv2, music_inst_root(_rv2), 0, 0, true); }
                else { music_preview_note(_lp.inst, _rv2, _lp.fx[_hs], _lp.fxp[_hs]); }
            }
        }
        if (mus_ed_note_drag && !mus_ed_note_glide && ui_held && _hs >= 0)
        {
            var _dst_step = clamp(floor((ui_mx - _sx) / (_cw * _snap_stride)) * _snap_stride, 0, MUS_STEPS - 1);
            var _dst_row = _hr;
            var _dst_pitch = clamp(mus_ed_note_pitch + mus_ed_note_src[1] - _dst_row, 1, MUS_NOTE_MAX);
            if (_drums) { _dst_pitch = mus_ed_note_pitch; }
            var _dst = [_dst_step, _dst_row];
            var _last_was = mus_ed_note_last;
            if (mus_ed_note_copy)
            {
                // Ctrl-drag clone: a ghost follows the mouse; nothing changes until the button is let go
                if (_dst_step != mus_ed_note_src[0])
                {
                    mus_ed_note_last = _dst;
                    mus_ed_note_moved = true;
                }
                else { mus_ed_note_last = [-1, -1]; }
                if (_dst_pitch != mus_ed_note_preview_pitch && !_drums)
                {
                    mus_ed_note_preview_pitch = _dst_pitch;
                    music_preview_note(mus_ed_note_inst, _dst_pitch, mus_ed_note_fx, mus_ed_note_fxp);
                }
            }
            else if (mus_ed_note_group)
            {
                // a selection: ghosts follow the mouse; the move is made when the button is let go
                var _grp_steps = _dst_step - mus_ed_note_src[0];
                var _grp_rows = _dst_row - mus_ed_note_src[1];
                if (_grp_steps == 0 && _grp_rows == 0) { mus_ed_note_last = [-1, -1]; }
                else if (!is_undefined(music_notes_move(_lp, mus_ed_selected, _grp_steps, _grp_rows, _drums, false)))
                {
                    mus_ed_note_last = _dst;
                    mus_ed_note_moved = true;
                }
                if (_dst_pitch != mus_ed_note_preview_pitch && !_drums && (mus_ed_note_last[0] >= 0 || (_grp_steps == 0 && _grp_rows == 0)))
                {
                    mus_ed_note_preview_pitch = _dst_pitch;
                    music_preview_note(mus_ed_note_inst, _dst_pitch, mus_ed_note_fx, mus_ed_note_fxp);
                }
            }
            else
            {
                // one note: a ghost follows the mouse; the note moves when the button is let go
                var _same_spot = (_dst_step == mus_ed_note_src[0] && _dst_row == mus_ed_note_src[1]);
                if (_same_spot) { mus_ed_note_last = [-1, -1]; }
                else if (music_note_can_move(_lp, mus_ed_note_src[0], _dst_step))
                {
                    mus_ed_note_last = _dst;
                    mus_ed_note_moved = true;
                }
                if (_dst_pitch != mus_ed_note_preview_pitch && !_drums && (_same_spot || mus_ed_note_last[0] >= 0))
                {
                    mus_ed_note_preview_pitch = _dst_pitch;
                    music_preview_note(mus_ed_note_inst, _dst_pitch, mus_ed_note_fx, mus_ed_note_fxp);
                }
            }
            // drums: play the hit each time the ghost lands on a new step or row
            if (_drums && (mus_ed_note_last[0] != _last_was[0] || mus_ed_note_last[1] != _last_was[1]))
            {
                var _hit_row = mus_ed_note_src[1];
                if (mus_ed_note_last[0] >= 0) { _hit_row = mus_ed_note_last[1]; }
                music_preview_note(_rows[_hit_row], music_inst_root(_rows[_hit_row]), 0, 0, true);
            }
        }
        if (mus_ed_note_drag && !ui_held) { music_ed_drop(_lp, _drums, _rows, _glide_drop_step); }
        if (mus_ed_painting && !mus_ed_note_drag && ui_held && _hs >= 0)
        {
            if (_drums || !_on2) { music_ed_apply(_lp, _hs, _rv2, _drums, 1, _new_len); }
        }
        if (ui_rpressed && !mus_ed_note_drag)
        {
            mus_ed_rclear = true;
            mus_ed_tag = "musstepclr" + string(current_time);
        }
        if (mus_ed_rclear && !mus_ed_note_drag && ui_rheld && _lp.notes[_hs] > 0)
        {
            music_loop_edit_begin(_lp, mus_ed_tag);
            music_step_clear(_lp, _hs);
            mus_ed_selected[_hs] = false;
        }
    }
    if (_hr < 0 && mus_ed_note_drag && !ui_held)
    {
        // let go outside the grid: a link dropped on nothing, or a move cancelled
        mus_ed_note_drag = false;
        mus_ed_note_glide = false;
    }
    if (!ui_held) { mus_ed_painting = false; }
    if (!ui_rheld) { mus_ed_rclear = false; }

    music_ed_fx_row(_lp, _drums, _x1, _x2, _gx1, _sx, _sx2, _cw, _gy2);
    if (!_drums) { music_ed_chord_row(_lp, _gx1, _sx, _cw, _gy2); }
}

/// The mouse let go of a note: the move, clone, group move or bend link is made now
function music_ed_drop(_lp, _drums, _rows, _glide_drop_step)
{
    if (mus_ed_note_glide)
    {
        if (_glide_drop_step > mus_ed_note_src[0])
        {
            music_loop_edit_begin(_lp, mus_ed_tag);
            music_glide_connect(_lp, mus_ed_note_src[0], _glide_drop_step);
            mus_ed_fx_step = _glide_drop_step;
        }
    }
    else if (mus_ed_note_copy)
    {
        if (mus_ed_note_last[0] >= 0 && mus_ed_note_last[0] != mus_ed_note_src[0])
        {
            var _copy_to = mus_ed_note_last[0];
            var _copy_row = mus_ed_note_last[1];
            var _copy_pitch = clamp(mus_ed_note_pitch + mus_ed_note_src[1] - _copy_row, 1, MUS_NOTE_MAX);
            if (_drums) { _copy_pitch = mus_ed_note_pitch; }
            music_loop_edit_begin(_lp, mus_ed_tag);
            music_note_duplicate(_lp, mus_ed_note_src[0], _copy_to, _copy_pitch);
            if (_drums) { _lp.insts[_copy_to] = _rows[_copy_row]; }
            mus_ed_selected[_copy_to] = mus_ed_selected[mus_ed_note_src[0]];
        }
    }
    else if (mus_ed_note_group)
    {
        if (mus_ed_note_last[0] >= 0)
        {
            var _grp_to_steps = mus_ed_note_last[0] - mus_ed_note_src[0];
            var _grp_to_rows = mus_ed_note_last[1] - mus_ed_note_src[1];
            if (!is_undefined(music_notes_move(_lp, mus_ed_selected, _grp_to_steps, _grp_to_rows, _drums, false)))
            {
                music_loop_edit_begin(_lp, mus_ed_tag);
                music_notes_move(_lp, mus_ed_selected, _grp_to_steps, _grp_to_rows, _drums);
                mus_ed_selected = array_create(MUS_STEPS, false);
            }
        }
    }
    else if (mus_ed_note_moved)
    {
        if (mus_ed_note_last[0] >= 0 && music_note_can_move(_lp, mus_ed_note_src[0], mus_ed_note_last[0]))
        {
            var _move_to = mus_ed_note_last[0];
            var _move_row = mus_ed_note_last[1];
            var _move_pitch = clamp(mus_ed_note_pitch + mus_ed_note_src[1] - _move_row, 1, MUS_NOTE_MAX);
            if (_drums) { _move_pitch = mus_ed_note_pitch; }
            music_loop_edit_begin(_lp, mus_ed_tag);
            music_note_move(_lp, mus_ed_note_src[0], _move_to, _move_pitch);
            if (_drums) { _lp.insts[_move_to] = _rows[_move_row]; }
            mus_ed_selected[mus_ed_note_src[0]] = false;
            mus_ed_fx_step = _move_to;
        }
    }
    else
    {
        // a click on a note without moving it takes it away
        music_loop_edit_begin(_lp, mus_ed_tag);
        music_step_clear(_lp, mus_ed_note_src[0]);
        mus_ed_selected[mus_ed_note_src[0]] = false;
    }
    mus_ed_note_drag = false;
    mus_ed_note_glide = false;
}

/// The effect row (click to cycle, right-click to clear, drag its circle to make it last longer)
/// and the selected effect's amount
function music_ed_fx_row(_lp, _drums, _x1, _x2, _gx1, _sx, _sx2, _cw, _gy2)
{
    var _effect_help = [
        "No effect.",
        "Slide up: the pitch rises every frame by the amount.",
        "Slide down: the pitch falls every frame by the amount.",
        "Vibrato: the pitch wobbles - speed and depth below.",
        "Glide from the last note (an older loop's effect): the note slides in without a new attack. Link notes with their circles now.",
        "Volume: the voice's sustain level ($D406), 0 to 15. The SID can only lower a note that is held; a note that starts while it lasts rises to full and settles there."
    ];
    var _fx_y = _gy2 + 4;
    if (!_drums) { _fx_y = _gy2 + 32; }
    var _fx_handle_hot = -1;
    var _fx_handle_distance = 7;
    for (var _hst = 0; _hst < MUS_STEPS; _hst++)
    {
        if (_lp.fx[_hst] == 0) { continue; }
        var _distance = point_distance(ui_mx, ui_my, _sx + (_hst + 1) * _cw - 2, _fx_y + 12);
        if (_distance <= _fx_handle_distance)
        {
            _fx_handle_hot = _hst;
            _fx_handle_distance = _distance;
        }
    }
    if (ui_pressed && _fx_handle_hot >= 0 && !mus_ed_note_drag)
    {
        ui_take_click();
        mus_ed_fx_drag = true;
        mus_ed_fx_src = _fx_handle_hot;
        mus_ed_fx_step = _fx_handle_hot;
    }
    if (mus_ed_fx_drag)
    {
        var _end_col = clamp(floor((ui_mx - _sx) / _cw), 0, MUS_STEPS - 1);
        mus_ed_fx_end = clamp(_end_col, mus_ed_fx_src, MUS_STEPS - 1);
        if (!ui_held)
        {
            if (ui_hit(_sx - 7, _fx_y - 7, _sx2 + 7, _fx_y + 31) && _lp.fx[mus_ed_fx_src] > 0)
            {
                music_loop_edit_begin(_lp, "musfxlength" + string(current_time));
                _lp.fx_end[mus_ed_fx_src] = mus_ed_fx_end;
            }
            mus_ed_fx_drag = false;
        }
    }
    ui_text(_gx1 + 6, _fx_y + 12, "Effect", global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
    // one text size for every effect label, small enough for the longest to fit
    draw_set_font(global.f_bold);
    var _fx_text_w = 1;
    for (var _fn = 0; _fn < array_length(global.MUS_FX_SHORT); _fn++) { _fx_text_w = max(_fx_text_w, ui_sw(global.MUS_FX_SHORT[_fn])); }
    var _fx_text_k = min(1, (_cw - 6) / _fx_text_w) / global.ui_scale;
    for (var fx_step = 0; fx_step < MUS_STEPS; fx_step++)
    {
        var _fx_x = _sx + fx_step * _cw + 1;
        var _fx_kind = _lp.fx[fx_step];
        var _active_step = music_fx_active_step(_lp, fx_step);
        var _display_kind = _fx_kind;
        if (_active_step >= 0) { _display_kind = _lp.fx[_active_step]; }
        var _fx_style = BTN_GHOST;
        if (_display_kind > 0) { _fx_style = BTN_ON; }
        var _fx_tip = "Step " + string(fx_step + 1) + " effect|" + _effect_help[clamp(_display_kind, 0, 5)] + " Click to change the effect; right-click to clear it. Drag the effect's circle to the right to make it last longer. An effect on a step with no note changes the note that is sounding.";
        if (!mus_ed_fx_drag && ui_hit(_fx_x, _fx_y, _fx_x + _cw - 2, _fx_y + 24))
        {
            mus_ed_fx_step = fx_step;
            if (_active_step >= 0) { mus_ed_fx_step = _active_step; }
        }
        var _fx_pressed = ui_button("mus_fx_" + string(fx_step), _fx_x, _fx_y, _cw - 2, 24, "", _fx_tip, _fx_style);
        var _fx_text_col = global.TH.text;
        if (_fx_style == BTN_ON) { _fx_text_col = make_colour_rgb(16, 30, 28); }
        draw_set_font(global.f_bold);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_colour(_fx_text_col);
        draw_text_transformed(_fx_x + (_cw - 2) * 0.5, _fx_y + 12, global.MUS_FX_SHORT[clamp(_display_kind, 0, 5)], _fx_text_k, _fx_text_k, 0);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        if (_fx_pressed)
        {
            music_loop_edit_begin(_lp, "musfx" + string(current_time));
            mus_ed_fx_step = fx_step;
            _fx_kind = music_fx_next_kind(_fx_kind);
            _lp.fx[fx_step] = _fx_kind;
            _lp.fxp[fx_step] = music_fx_default(_fx_kind);
            if (_fx_kind == 0) { _lp.fx_end[fx_step] = -1; }
        }
        if (!mus_ed_fx_drag && ui_rpressed && _active_step >= 0 && ui_hit(_fx_x, _fx_y, _fx_x + _cw - 2, _fx_y + 24))
        {
            music_loop_edit_begin(_lp, "musfxclear" + string(current_time));
            _lp.fx[_active_step] = 0;
            _lp.fxp[_active_step] = 0;
            _lp.fx_end[_active_step] = -1;
        }
    }
    // how long each effect lasts, drawn over the buttons
    for (var _node_step = 0; _node_step < MUS_STEPS; _node_step++)
    {
        if (_lp.fx[_node_step] == 0) { continue; }
        var _node_x = _sx + (_node_step + 1) * _cw - 2;
        var _effect_end = _lp.fx_end[_node_step];
        if (mus_ed_fx_drag && mus_ed_fx_src == _node_step) { _effect_end = mus_ed_fx_end; }
        if (_effect_end >= _node_step)
        {
            var _end_x = _sx + (_effect_end + 1) * _cw - 2;
            draw_line_width_colour(_node_x, _fx_y + 23, _end_x, _fx_y + 23, 3, global.TH.accent, global.TH.accent);
            draw_circle_colour(_end_x, _fx_y + 23, 3, global.TH.accent, global.TH.accent, false);
        }
        var _radius = 4;
        var _node_col = global.TH.accent;
        if (_fx_handle_hot == _node_step || (mus_ed_fx_drag && mus_ed_fx_src == _node_step))
        {
            _radius = 6;
            _node_col = c_white;
        }
        draw_circle_colour(_node_x, _fx_y + 12, _radius + 1, global.TH.panel_bot, global.TH.panel_bot, false);
        draw_circle_colour(_node_x, _fx_y + 12, _radius, _node_col, _node_col, false);
    }
    if (mus_ed_fx_drag)
    {
        var _src_x = _sx + (mus_ed_fx_src + 1) * _cw - 2;
        draw_line_width_colour(_src_x, _fx_y + 12, clamp(ui_mx, _src_x, _sx2 - 2), _fx_y + 12, 2, global.TH.accent, global.TH.accent);
    }

}

/// The selected effect's amount (slide amount, vibrato speed and depth, or volume), ending at _xr;
/// returns its width
function music_ed_fx_param(_lp, _xr, _py)
{
    var _param_y = _py;
    var _param_step = clamp(mus_ed_fx_step, 0, MUS_STEPS - 1);
    var _param_fx = _lp.fx[_param_step];
    if (_param_fx == 0) { return 0; }
    var _param_w = 212;
    if (_param_fx == 3) { _param_w = 288; }
    var _param_x = _xr - _param_w;
    ui_text(_param_x, _param_y + 15, "Step " + string(_param_step + 1), global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
    if (_param_fx == 5)
    {
        var _volume = clamp(_lp.fxp[_param_step], 0, 15);
        ui_text(_param_x + 54, _param_y + 15, "Volume", global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
        var _new_volume = ui_stepper("mus_fx_volume", _param_x + 118, _param_y, 94, _volume, 0, 15, "Volume|The voice's sustain level, 0 (silent) to 15 (full) - the SID's only per-voice volume. Make the effect last longer to hold this level over later steps.");
        if (_new_volume != _volume)
        {
            music_loop_edit_begin(_lp, "musfxparam" + string(_param_step));
            _lp.fxp[_param_step] = _new_volume;
        }
    }
    else if (_param_fx == 3)
    {
        var _vib_spd = (_lp.fxp[_param_step] >> 6) + 1;
        var _vib_dep = max(1, _lp.fxp[_param_step] & 63);
        ui_text(_param_x + 54, _param_y + 15, "Speed", global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
        var _nvs = ui_stepper("mus_fx_vspeed", _param_x + 104, _param_y, 64, _vib_spd, 1, 4, "Vibrato speed|How quickly the pitch wobbles: 1 is one wobble every 16 frames, 4 every 4 frames.");
        ui_text(_param_x + 178, _param_y + 15, "Depth", global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
        var _nvd = ui_stepper("mus_fx_vdepth", _param_x + 224, _param_y, 64, _vib_dep, 1, 63, "Vibrato depth|How far the pitch wobbles. Hold Shift for steps of 10.");
        if (_nvs != _vib_spd || _nvd != _vib_dep)
        {
            music_loop_edit_begin(_lp, "musfxparam" + string(_param_step));
            _lp.fxp[_param_step] = ((_nvs - 1) << 6) | _nvd;
        }
    }
    else
    {
        var _speed = max(1, _lp.fxp[_param_step]);
        ui_text(_param_x + 54, _param_y + 15, "Amount", global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
        var _nsp = ui_stepper("mus_fx_speed", _param_x + 112, _param_y, 100, _speed, 1, 255, "Effect amount|How far the pitch moves every frame. Hold Shift for steps of 10. Drag the effect's circle to make it last longer.");
        if (_nsp != _speed)
        {
            music_loop_edit_begin(_lp, "musfxparam" + string(_param_step));
            _lp.fxp[_param_step] = _nsp;
        }
    }
    return _param_w;
}

/// The chord row: click to cycle a step's chord, right-click for none
function music_ed_chord_row(_lp, _gx1, _sx, _cw, _gy2)
{
    var _cy = _gy2 + 4;
    ui_text(_gx1 + 6, _cy + 12, "Chord", global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
    var _codes = global.MUS_CHORD_CODES;
    var _short = ["-", "min", "maj", "7th", "sus", "oct"];
    draw_set_font(global.f_bold);
    var _tw = 1;
    for (var k0 = 0; k0 < array_length(_short); k0++) { _tw = max(_tw, ui_sw(_short[k0])); }
    var _tk = min(1, (_cw - 6) / _tw) / global.ui_scale;
    for (var st2 = 0; st2 < MUS_STEPS; st2++)
    {
        var _code = _lp.arps[st2];
        var _idx = -1;
        for (var k = 0; k < array_length(_codes); k++)
        {
            if (_codes[k] == _code) { _idx = k; }
        }
        var _clab = "?";
        if (_idx >= 0) { _clab = _short[_idx]; }
        var _cst = BTN_GHOST;
        if (_code != 0) { _cst = BTN_ON; }
        var _bx = _sx + st2 * _cw + 1;
        var _pressed = ui_button("mus_chord_" + string(st2), _bx, _cy, _cw - 2, 24, "", "Chord|Click to turn this step's note into a chord: minor, major, 7th, sus 4 or octave. The SID voice plays it as a fast arpeggio - a different note each frame, the C64 way. Right-click for no chord.", _cst);
        var _tc = global.TH.text;
        if (_cst == BTN_ON) { _tc = make_colour_rgb(16, 30, 28); }
        draw_set_font(global.f_bold);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_colour(_tc);
        draw_text_transformed(_bx + (_cw - 2) * 0.5, _cy + 12, _clab, _tk, _tk, 0);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        if (_pressed)
        {
            music_loop_edit_begin(_lp, "muschord" + string(current_time));
            _lp.arps[st2] = _codes[(_idx + 1) mod array_length(_codes)];
        }
        if (ui_rpressed && _code != 0 && ui_hit(_bx, _cy, _bx + _cw - 2, _cy + 24))
        {
            music_loop_edit_begin(_lp, "muschord" + string(current_time));
            _lp.arps[st2] = 0;
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
