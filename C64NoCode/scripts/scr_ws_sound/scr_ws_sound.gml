/// C64 NO-CODE STUDIO - Sound workspace (SID effects, in folders)

/// "8 ms" / "1.5 s" for an ADSR time in milliseconds
function snd_ms_text(_ms)
{
    if (_ms < 1000) { return string(_ms) + " ms"; }
    return string_format(_ms / 1000, 0, 1) + " s";
}

function ws_sound_draw(_x1, _y1, _x2, _y2)
{
    var _lw = 250;
    snd_sel = clamp(snd_sel, 0, array_length(proj.sfx) - 1);
    sound_list_draw(_x1, _y1, _x1 + _lw, _y2);

    var _cx1 = _x1 + _lw + 12;
    var _s = proj.sfx[snd_sel];
    var _title = "Sound " + string(snd_sel + 1) + "  -  SID " + global.VOICE_NAMES[clamp(_s.voice, 0, 1)];
    if (_s.kind == 1) { _title = "Sound " + string(snd_sel + 1) + "  -  sample, played through the SID volume ($D418)"; }
    if (_s.kind == 2) { _title = "Sound " + string(snd_sel + 1) + "  -  patch, played register by register on the SID"; }
    ui_panel(_cx1, _y1, _x2, _y2, _title);
    if (keyboard_check_pressed(vk_space) && ui_focus == "" && ui_can_input() && !keyboard_check(vk_control)) { sfx_preview_play(_s); }

    var _gap = 24;
    var _colw = floor((_x2 - _cx1 - 40 - _gap * 2) / 3);
    var _ax = _cx1 + 20;
    var _bx = _ax + _colw + _gap;
    var _qx = _bx + _colw + _gap;
    var _half = floor((_colw - 12) / 2);
    var _third = floor((_colw - 16) / 3);
    if (_s.kind == 1)
    {
        sound_sample_panel(_s, _ax, _bx, _colw, _y1, _y2);
        sound_listen_draw(_s, _qx, _colw, _y1, _y2);
        return;
    }
    if (_s.kind == 2)
    {
        sound_patch_panel(_s, _ax, _bx, _colw, _y1, _y2);
        sound_listen_draw(_s, _qx, _colw, _y1, _y2);
        return;
    }

    // ---------------- column 1: the tone ----------------
    var _y = _y1 + 56;
    var _nw = floor(_colw * 0.55);
    ui_heading(_ax, _y, "Name");
    set_val(_s, "name", ui_textfield("snd_name", _ax, _y + 18, _nw, 32, _s.name, 16, "Sound name|Shown on the Logic page when you pick a sound to play."), "sndname");
    ui_heading(_ax + _nw + 8, _y, "Folder");
    var _fnames = ["(none)"];
    for (var g = 0; g < array_length(proj.sound_groups); g++) { array_push(_fnames, proj.sound_groups[g].name); }
    var _fg = ui_dropdown("snd_folder", _ax + _nw + 8, _y + 18, _colw - _nw - 8, 32, _fnames, clamp(_s.group + 1, 0, array_length(_fnames) - 1), "Folder|Which folder this sound is in. Make folders with + Folder; you can also drag a sound onto a folder.");
    set_val(_s, "group", _fg - 1, "sndfolder");
    _y += 62;
    ui_heading(_ax, _y, "Waveform");
    set_val(_s, "wave", ui_dropdown("snd_wave", _ax, _y + 18, _half, 32, global.WAVE_NAMES, _s.wave, "Waveform|The SID's basic tones: soft triangle, buzzy sawtooth, the classic pulse and crunchy noise. The mixed ones (pulse + triangle and so on) are the SID's famous combined waveforms - quieter, with a metallic edge."), "sndwave");
    ui_heading(_ax + _half + 12, _y, "SID voice");
    var _vw = floor((_half - 6) / 2);
    for (var vo = 0; vo < 2; vo++)
    {
        var _vst = BTN_GHOST;
        if (_s.voice == vo) { _vst = BTN_ACCENT; }
        if (ui_button("snd_voice_" + string(vo), _ax + _half + 12 + vo * (_vw + 6), _y + 18, _vw, 32, string(vo + 1), "SID voice " + string(vo + 1) + "|The SID has 3 voices. Sounds play on voice 1 or 2 - put sounds that should play together (a shot and an explosion) on different voices. While a sound plays it borrows its voice from the music, which carries on when it ends. Voice 3 is the music's alone.", _vst))
        {
            set_val(_s, "voice", vo, "sndvoice" + string(current_time));
        }
    }
    _y += 62;
    var _is_pulse = ((global.WAVE_BITS[clamp(_s.wave, 0, array_length(global.WAVE_BITS) - 1)] & 64) != 0);
    ui_heading(_ax, _y, "Pulse width  " + string(round(_s.pw / 40.95)) + "%");
    set_val(_s, "pw", ui_slider("snd_pw", _ax, _y + 18, _half, _s.pw, 0, 4095, "Pulse width|How long the pulse wave stays high in each cycle ($D402-$D403, 12 bits). 50% is a hollow square; thin pulses sound nasal and reedy. Only pulse waveforms use it."), "sndpw");
    ui_heading(_ax + _half + 12, _y, "Width sweep");
    set_val(_s, "pws", ui_stepper("snd_pws", _ax + _half + 12, _y + 18, _half, _s.pws, -64, 64, "Pulse width sweep|Changes the pulse width every frame, wrapping round - the classic C64 'PWM' chorus sound. Hold Shift for steps of 10."), "sndpws");
    if (!_is_pulse)
    {
        ui_rrect(_ax - 4, _y - 4, _ax + _colw + 4, _y + 52, 8, global.TH.panel_bot, global.TH.panel_bot, 0.8);
        ui_text(_ax + _colw * 0.5, _y + 30, "Pulse width: pulse waveforms only", global.TH.text_dim, fa_center, fa_middle, global.f_small, 1);
    }
    _y += 62;
    ui_heading(_ax, _y, "Pitch  " + string(_s.pitch) + "   " + sid_note_name(_s.pitch));
    set_val(_s, "pitch", ui_slider("snd_pitch", _ax, _y + 18, _colw, _s.pitch, 1, 255, "Pitch|The high byte of the SID frequency ($D401). Low numbers are deep, high numbers are squeaky. The note shown is for the machine picked in the top bar (PAL or NTSC)."), "sndpitch");
    _y += 54;
    ui_heading(_ax, _y, "Pitch slide");
    set_val(_s, "sweep", ui_stepper("snd_sweep", _ax, _y + 18, _half, _s.sweep, -8, 8, "Pitch slide|How much the pitch rises (+) or falls (-) every frame. Falling slides make lasers, rising slides make coins and power-ups."), "sndsweep");
    ui_heading(_ax + _half + 12, _y, "Length (frames)");
    set_val(_s, "len", ui_stepper("snd_len", _ax + _half + 12, _y + 18, _half, _s.len, 1, 200, "Length|How long the note is held (the SID gate is on), in frames - 50 a second on PAL, 60 on NTSC. The release then fades it out."), "sndlen");
    _y += 62;
    set_val(_s, "arp", ui_toggle("snd_arp", _ax, _y, "Arpeggio", _s.arp, "Arpeggio|Steps through three notes, one each frame - the C64 way to play a chord on one voice. Great for power-ups, coins and jingles."), "sndarp");
    _y += 30;
    ui_heading(_ax, _y, "Chord steps (semitones up)");
    set_val(_s, "arp1", ui_stepper("snd_arp1", _ax, _y + 18, _half, _s.arp1, 0, 24, "Second note|How many semitones above the first note. 4 = major third, 3 = minor third, 12 = an octave."), "sndarp1");
    set_val(_s, "arp2", ui_stepper("snd_arp2", _ax + _half + 12, _y + 18, _half, _s.arp2, 0, 24, "Third note|How many semitones above the first note. 7 = a fifth, 12 = an octave."), "sndarp2");
    if (!_s.arp)
    {
        ui_rrect(_ax - 4, _y - 4, _ax + _colw + 4, _y + 52, 8, global.TH.panel_bot, global.TH.panel_bot, 0.6);
    }

    // ---------------- column 2: volume envelope + filter ----------------
    var _by = _y1 + 56;
    ui_heading(_bx, _by, "Volume envelope (ADSR)");
    _by += 22;
    var _lab = ["Attack", "Decay", "Sustain", "Release"];
    var _keys = ["atk", "dec", "sus", "rel"];
    var _ehelp = ["Attack|How quickly the sound fades in ($D405 high nibble). 0 is instant (2 ms), 15 takes 8 seconds.",
                  "Decay|How quickly it drops from full volume to the sustain level ($D405 low nibble).",
                  "Sustain|The volume held while the note is on ($D406 high nibble). 0 makes short plucky sounds.",
                  "Release|How long the sound takes to fade away once the note ends ($D406 low nibble)."];
    for (var e = 0; e < 4; e++)
    {
        var _ev = _s[$ _keys[e]];
        ui_text(_bx, _by + 13, _lab[e], global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
        set_val(_s, _keys[e], ui_slider("snd_" + _keys[e], _bx + 64, _by, _colw - 64 - 92, _ev, 0, 15, _ehelp[e]), "snd" + _keys[e]);
        var _et = string(_ev);
        if (e == 0) { _et += "  " + snd_ms_text(global.SID_ATK_MS[_ev]); }
        if (e == 1 || e == 3) { _et += "  " + snd_ms_text(global.SID_DR_MS[_ev]); }
        if (e == 2) { _et += "  " + string(round(_ev / 15 * 100)) + "%"; }
        ui_text(_bx + _colw, _by + 13, _et, global.TH.text, fa_right, fa_middle, global.f_small, 1);
        _by += 30;
    }
    _by += 6;
    var _gh = 120;
    ui_inset(_bx, _by, _bx + _colw, _by + _gh, 10);
    ui_register("snd_graph", _bx, _by, _bx + _colw, _by + _gh, "Envelope shape|How loud the sound is over time: it rises (attack), falls (decay), holds (sustain) while the note is on, then fades (release). The yellow line is the sound playing.");
    var _a1 = 6 + _s.atk * 4;
    var _d1 = 6 + _s.dec * 5;
    var _hold = 10 + _s.len * 1.2;
    var _r1 = 6 + _s.rel * 5;
    var _tot = _a1 + _d1 + _hold + _r1;
    var _sc = (_colw - 30) / _tot;
    var _base = _by + _gh - 16;
    var _top = _by + 14;
    var _sus = _base - (_base - _top) * (_s.sus / 15);
    var _px0 = _bx + 15;
    var _px1 = _px0 + _a1 * _sc;
    var _px2 = _px1 + _d1 * _sc;
    var _px3 = _px2 + _hold * _sc;
    var _px4 = _px3 + _r1 * _sc;
    draw_set_alpha(0.25);
    draw_set_colour(global.TH.accent);
    draw_primitive_begin(pr_trianglestrip);
    draw_vertex(_px0, _base); draw_vertex(_px1, _top);
    draw_vertex(_px1, _base); draw_vertex(_px2, _sus);
    draw_vertex(_px2, _base); draw_vertex(_px3, _sus);
    draw_vertex(_px3, _base); draw_vertex(_px4, _base);
    draw_primitive_end();
    draw_set_alpha(1);
    draw_line_width_colour(_px0, _base, _px1, _top, 3, global.TH.accent, global.TH.accent);
    draw_line_width_colour(_px1, _top, _px2, _sus, 3, global.TH.accent, global.TH.accent);
    draw_line_width_colour(_px2, _sus, _px3, _sus, 3, global.TH.accent, global.TH.accent);
    draw_line_width_colour(_px3, _sus, _px4, _base, 3, global.TH.accent, global.TH.accent);
    var _prog = sfx_preview_progress(_s);
    if (_prog >= 0)
    {
        var _mx = lerp(_px0, _px4, _prog);
        draw_line_width_colour(_mx, _top - 6, _mx, _base, 2, global.TH.warn, global.TH.warn);
    }
    ui_text((_px0 + _px1) / 2, _base + 2, "A", global.TH.text_faint, fa_center, fa_top, global.f_small, 1);
    ui_text((_px1 + _px2) / 2, _base + 2, "D", global.TH.text_faint, fa_center, fa_top, global.f_small, 1);
    ui_text((_px2 + _px3) / 2, _base + 2, "S", global.TH.text_faint, fa_center, fa_top, global.f_small, 1);
    ui_text((_px3 + _px4) / 2, _base + 2, "R", global.TH.text_faint, fa_center, fa_top, global.f_small, 1);
    _by += _gh + 16;

    ui_heading(_bx, _by, "SID filter");
    set_val(_s, "fmode", ui_dropdown("snd_fmode", _bx, _by + 18, _half, 32, global.FILTER_NAMES, _s.fmode, "Filter|The SID's analogue filter ($D417-$D418). Low pass makes it dull and warm (explosions, wind), band pass nasal, high pass thin and hissy. There is one filter for the whole chip: the last sound to use it sets it."), "sndfmode");
    ui_heading(_bx + _half + 12, _by, "Resonance");
    set_val(_s, "fres", ui_stepper("snd_fres", _bx + _half + 12, _by + 18, _half, _s.fres, 0, 15, "Resonance|Boosts the sound around the cutoff ($D417 high nibble) - high values whistle and ring."), "sndfres");
    _by += 62;
    ui_heading(_bx, _by, "Cutoff  " + string(_s.fcut) + "  (" + string(round(sid_cutoff_hz(_s.fcut))) + " Hz)");
    set_val(_s, "fcut", ui_slider("snd_fcut", _bx, _by + 18, _half + 40, _s.fcut, 0, 255, "Cutoff|Where the filter starts working ($D416). The real SID varies from chip to chip (the old 6581 sounds darker than the 8580) - always check on a real machine or in VICE."), "sndfcut");
    ui_heading(_bx + _half + 52, _by, "Sweep");
    set_val(_s, "fsweep", ui_stepper("snd_fsweep", _bx + _half + 52, _by + 18, _colw - _half - 52, _s.fsweep, -9, 9, "Filter sweep|Moves the cutoff every frame while the sound plays (and half a second after) - a falling sweep on noise is a classic C64 explosion."), "sndfsweep");
    if (_s.fmode == 0)
    {
        ui_rrect(_bx - 4, _by - 12, _bx + _colw + 4, _by + 52, 8, global.TH.panel_bot, global.TH.panel_bot, 0.8);
        ui_text(_bx + _colw * 0.5, _by + 20, "Filter is off - pick a filter type above", global.TH.text_dim, fa_center, fa_middle, global.f_small, 1);
    }

    sound_listen_draw(_s, _qx, _colw, _y1, _y2);
}

/// The Sound page's left panel: sounds in folders, scrolling, with add / copy / delete
function sound_list_draw(_x1, _y1, _x2, _y2)
{
    var _n = array_length(proj.sfx);
    ui_panel(_x1, _y1, _x2, _y2, "Sounds  (" + string(_n) + " / " + string(SFX_MAX) + ")");
    var _ng = array_length(proj.sound_groups);

    // rows: folder headers (kind 1) and sounds (kind 0); sounds in no folder come first
    var _rows = [];
    for (var g = -1; g < _ng; g++)
    {
        var _count = 0;
        for (var c = 0; c < _n; c++)
        {
            if (sound_folder_of(c) == g) { _count += 1; }
        }
        var _open = snd_ungrouped_open;
        if (g >= 0) { _open = proj.sound_groups[g].open; }
        if (g >= 0 || _ng > 0) { array_push(_rows, { kind : 1, group : g, count : _count, h : 36 }); }
        if (g == -1 && _ng == 0) { _open = true; }
        if (!_open) { continue; }
        for (var i = 0; i < _n; i++)
        {
            if (sound_folder_of(i) == g) { array_push(_rows, { kind : 0, idx : i, group : g, h : 52 }); }
        }
    }
    var _content = 8;
    var _offsets = [];
    for (var r = 0; r < array_length(_rows); r++)
    {
        array_push(_offsets, _content);
        _content += _rows[r].h;
    }
    var _ly1 = _y1 + 48;
    var _ly2 = _y2 - 88;
    var _off = ui_scroll_begin("snd_list", _x1 + 4, _ly1, _x2 - 4, _ly2, _content);
    var _ix1 = _x1 + 10;
    var _ix2 = _x2 - 16;
    var _hover_group = -2;
    var _removed = false;
    for (var r2 = 0; r2 < array_length(_rows); r2++)
    {
        var _row = _rows[r2];
        var _ry = _ly1 + _offsets[r2] - _off;
        if (_ry + _row.h < _ly1 || _ry > _ly2) { continue; }
        if (_row.kind == 1)
        {
            var _gi = _row.group;
            var _gopen = snd_ungrouped_open;
            var _gname = "No folder";
            if (_gi >= 0)
            {
                _gopen = proj.sound_groups[_gi].open;
                _gname = proj.sound_groups[_gi].name;
            }
            ui_rrect(_ix1, _ry, _ix2, _ry + 30, 6, global.TH.btn_top, global.TH.btn_bot, 1);
            if (snd_drag >= 0 && ui_hit(_ix1, _ry, _ix2, _ry + 30))
            {
                _hover_group = _gi;
                ui_rrect_line(_ix1, _ry, _ix2, _ry + 30, 6, global.TH.accent, 1, 2);
            }
            var _arrow = ">";
            if (_gopen) { _arrow = "v"; }
            if (ui_button("snd_folder_open_" + string(_gi), _ix1 + 2, _ry + 2, 26, 26, _arrow, "Open / close folder|Shows or hides the sounds in this folder.", BTN_GHOST))
            {
                if (_gi < 0) { snd_ungrouped_open = !_gopen; }
                else { proj.sound_groups[_gi].open = !_gopen; }
            }
            if (_gi >= 0)
            {
                var _renamed = ui_textfield("snd_folder_name_" + string(_gi), _ix1 + 32, _ry + 2, _ix2 - _ix1 - 90, 26, _gname, 24, "Folder name|Type a new name. Drag a sound onto this header to put it in the folder.");
                if (_renamed != _gname)
                {
                    undo_mark("sndfolderrename" + string(_gi));
                    proj.sound_groups[_gi].name = _renamed;
                }
                if (ui_button("snd_folder_del_" + string(_gi), _ix2 - 28, _ry + 2, 26, 26, "x", "Remove folder|Removes the folder. Its sounds are kept, in no folder.", BTN_GHOST))
                {
                    sound_folder_remove(_gi);
                    _removed = true;
                    break;
                }
            }
            else
            {
                ui_text(_ix1 + 36, _ry + 15, _gname, global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
            }
            ui_text(_ix2 - 34, _ry + 15, string(_row.count), global.TH.text_faint, fa_right, fa_middle, global.f_small, 1);
            continue;
        }
        var _i = _row.idx;
        var _id = "snd_slot_" + string(_i);
        var _f = proj.sfx[_i];
        var _hot = ui_register(_id, _ix1, _ry, _ix2, _ry + 46, _f.name + "|Click to edit this sound. Rules on the Logic page (and map game events) play it. Drag it onto a folder to move it.");
        if (snd_drag >= 0 && ui_hit(_ix1, _ry, _ix2, _ry + 46)) { _hover_group = _row.group; }
        var _tgt = 0;
        if (_hot) { _tgt = 1; }
        var _a = ui_anim_to(_id, _tgt);
        if (snd_sel == _i) { ui_rrect(_ix1, _ry, _ix2, _ry + 46, 10, global.TH.accent, global.TH.accent_dark, 0.9); }
        else { ui_rrect(_ix1, _ry, _ix2, _ry + 46, 10, global.TH.btn_hot_top, global.TH.btn_hot_bot, 0.25 + _a * 0.75); }
        ui_text(_ix1 + 14, _ry + 15, string(_i + 1) + ". " + ui_text_fit(_f.name, global.f_bold, _ix2 - _ix1 - 100), global.TH.text, fa_left, fa_middle, global.f_bold, 1);
        var _sub = global.WAVE_SHORT[clamp(_f.wave, 0, array_length(global.WAVE_SHORT) - 1)] + "  -  voice " + string(_f.voice + 1);
        if (_f.fmode > 0) { _sub += "  -  filter"; }
        if (_f.kind == 1)
        {
            _sub = "Sample  -  no WAV yet";
            if (_f.smp != "") { _sub = "Sample  -  " + string(digi_bytes(_f)) + " bytes"; }
        }
        if (_f.kind == 2) { _sub = "Patch  -  " + patch_key_name(_f.patch.key) + "  -  " + string(patch_bytes(_f.patch)) + " bytes"; }
        ui_text(_ix1 + 14, _ry + 33, ui_text_fit(_sub, global.f_small, _ix2 - _ix1 - 76), global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
        if (ui_button(_id + "_play", _ix2 - 56, _ry + 8, 48, 30, "Play", "Play|Hear this sound.", BTN_GHOST))
        {
            sfx_preview_play(_f);
        }
        if (_hot && ui_pressed)
        {
            snd_sel = _i;
            snd_drag = _i;
            snd_drag_y0 = ui_my;
            snd_dragging = false;
            ui_take_click();
        }
    }
    ui_scroll_end("snd_list", _x1 + 4, _ly1, _x2 - 4, _ly2, _content);
    if (_removed) { return; }

    // drag a sound onto a folder (or onto "No folder")
    if (snd_drag >= 0)
    {
        if (ui_held)
        {
            if (abs(ui_my - snd_drag_y0) > 8) { snd_dragging = true; }
            if (snd_dragging)
            {
                if (ui_my < _ly1 + 20) { ds_map_replace(ui_scroll, "snd_list", max(0, _off - 6)); }
                if (ui_my > _ly2 - 20) { ds_map_replace(ui_scroll, "snd_list", clamp(_off + 6, 0, max(0, _content - (_ly2 - _ly1)))); }
                var _dn = proj.sfx[clamp(snd_drag, 0, _n - 1)].name;
                ui_rrect(ui_mx + 12, ui_my + 8, ui_mx + 160, ui_my + 34, 6, global.TH.accent, global.TH.accent_dark, 0.9);
                ui_text(ui_mx + 20, ui_my + 21, ui_text_fit(_dn, global.f_small, 132), c_white, fa_left, fa_middle, global.f_small, 1);
            }
        }
        else
        {
            if (snd_dragging && _hover_group > -2 && snd_drag < _n && proj.sfx[snd_drag].group != _hover_group)
            {
                undo_mark("sndfoldermove" + string(current_time));
                proj.sfx[snd_drag].group = _hover_group;
                if (_hover_group >= 0) { proj.sound_groups[_hover_group].open = true; }
            }
            snd_drag = -1;
            snd_dragging = false;
        }
    }

    // ---- add / folder / copy / delete ----
    var _bw = floor((_x2 - _x1 - 28) / 2);
    var _by = _y2 - 80;
    var _add_style = BTN_NORMAL;
    if (_n >= SFX_MAX) { _add_style = BTN_GHOST; }
    if (ui_button("snd_add", _x1 + 10, _by, _bw, 32, "+ Sound", "Add a sound|A new sound in the selected sound's folder. Up to " + string(SFX_MAX) + " - each one is only 16 bytes of tables in your game.", _add_style))
    {
        var _ns = sfx_new("Sound " + string(_n + 1));
        sfx_apply_preset(_ns, 7);
        sound_add(_ns);
    }
    if (ui_button("snd_folder_add", _x1 + 18 + _bw, _by, _bw, 32, "+ Folder", "Add a folder|Groups sounds - player, enemies, jingles... Drag sounds onto it.", BTN_NORMAL))
    {
        if (_ng >= SFX_MAX) { toast("That is a lot of folders already", 1); }
        else
        {
            undo_mark("sndfolderadd" + string(current_time));
            array_push(proj.sound_groups, { name : "Folder " + string(_ng + 1), open : true });
        }
    }
    if (ui_button("snd_copy", _x1 + 10, _by + 40, _bw, 32, "Duplicate", "Duplicate|A copy of the selected sound, to try changes on.", _add_style))
    {
        var _copy = struct_overlay(sfx_new(""), json_parse(json_stringify(proj.sfx[snd_sel])));
        _copy.name = string_copy("Copy " + _copy.name, 1, 16);
        sound_add(_copy);
    }
    if (ui_button("snd_delete", _x1 + 18 + _bw, _by + 40, _bw, 32, "Delete", "Delete|Removes the selected sound if nothing uses it. Later sounds are renumbered and every rule and map game event is fixed up.", BTN_GHOST))
    {
        sound_delete(snd_sel);
    }
}

/// The folder sound _i is shown in (-1 = none)
function sound_folder_of(_i)
{
    var _g = proj.sfx[_i].group;
    if (_g < 0 || _g >= array_length(proj.sound_groups)) { return -1; }
    return _g;
}

/// Adds sound _s after the others, in the selected sound's folder, and selects it
function sound_add(_s)
{
    var _n = array_length(proj.sfx);
    if (_n >= SFX_MAX)
    {
        toast(string(SFX_MAX) + " sounds is the limit", 1);
        return;
    }
    undo_mark("sndadd" + string(current_time));
    _s.group = sound_folder_of(clamp(snd_sel, 0, _n - 1));
    array_push(proj.sfx, _s);
    snd_sel = _n;
    if (_s.group >= 0) { proj.sound_groups[_s.group].open = true; }
    else { snd_ungrouped_open = true; }
}

/// Removes folder _g; its sounds stay, in no folder
function sound_folder_remove(_g)
{
    undo_mark("sndfolderdel" + string(current_time));
    for (var i = 0; i < array_length(proj.sfx); i++)
    {
        if (proj.sfx[i].group == _g) { proj.sfx[i].group = -1; }
        else
        {
            if (proj.sfx[i].group > _g) { proj.sfx[i].group -= 1; }
        }
    }
    array_delete(proj.sound_groups, _g, 1);
}

/// How many rule lines and map game events play sound _k
function sound_uses(_k)
{
    var _uses = 0;
    for (var r = 0; r < array_length(proj.rules); r++)
    {
        var _ru = proj.rules[r];
        if (_ru.act == 2 && _ru.value == _k) { _uses += 1; }
        for (var m = 0; m < array_length(_ru.more); m++)
        {
            if (_ru.more[m].act == 2 && _ru.more[m].value == _k) { _uses += 1; }
        }
    }
    var _evk = ["sfx_shoot", "sfx_hit", "sfx_die", "sfx_collect", "sfx_jump", "sfx_exit"];
    for (var e = 0; e < array_length(_evk); e++)
    {
        if (proj.eng[$ _evk[e]] == _k) { _uses += 1; }
    }
    return _uses;
}

/// Sound numbers from _from up move by _d (after a sound is deleted)
function sfx_refs_shift(_from, _d)
{
    for (var r = 0; r < array_length(proj.rules); r++)
    {
        var _ru = proj.rules[r];
        if (_ru.act == 2 && _ru.value >= _from) { _ru.value += _d; }
        for (var m = 0; m < array_length(_ru.more); m++)
        {
            if (_ru.more[m].act == 2 && _ru.more[m].value >= _from) { _ru.more[m].value += _d; }
        }
    }
    var _evk = ["sfx_shoot", "sfx_hit", "sfx_die", "sfx_collect", "sfx_jump", "sfx_exit"];
    for (var e = 0; e < array_length(_evk); e++)
    {
        var _v = proj.eng[$ _evk[e]];
        if (_v != 255 && _v >= _from) { proj.eng[$ _evk[e]] = _v + _d; }
    }
}

/// Deletes sound _k when nothing plays it, renumbering the later sounds' users
function sound_delete(_k)
{
    if (array_length(proj.sfx) <= 1)
    {
        toast("A game keeps at least one sound", 1);
        return;
    }
    var _uses = sound_uses(_k);
    if (_uses > 0)
    {
        toast(proj.sfx[_k].name + " is played by " + string(_uses) + " rule line(s) or map game event(s) - change those first", 1);
        return;
    }
    undo_mark("snddelete" + string(current_time));
    sfx_preview_stop();
    var _name = proj.sfx[_k].name;
    array_delete(proj.sfx, _k, 1);
    sfx_refs_shift(_k + 1, -1);
    music_sound_deleted(_k);
    snd_sel = clamp(_k, 0, array_length(proj.sfx) - 1);
    toast("Deleted " + _name, 0);
}


/// Synth or sample switch, Play, the scope, and the presets (synth sounds) - the Sound page's right column
function sound_listen_draw(_s, _qx, _colw, _y1, _y2)
{
    var _qy = _y1 + 56;
    // synth, sample or patch
    var _kw = floor((_colw - 16) / 3);
    var _kn = ["Synth", "Sample", "Patch"];
    var _kh = ["Synth sound|Made on the SID's voices 1 or 2 from a waveform, envelope, slide and filter. A few bytes each.",
               "Sampled sound|A real recording - a voice, a drum, an explosion - imported from a WAV and played the way C64 games talk: 4-bit samples written to the SID's volume register by a timer interrupt.",
               "Patch|ADAM's patch synth on the real chip: up to three oscillators with sync and ring modulation, the filter with its own envelope, a pitch envelope, two LFOs and a modulation matrix. The studio works out every SID register for every frame; the game plays them back."];
    for (var kk = 0; kk < 3; kk++)
    {
        var _ks = BTN_GHOST;
        if (_s.kind == kk) { _ks = BTN_ACCENT; }
        if (ui_button("snd_kind_" + string(kk), _qx + kk * (_kw + 8), _qy, _kw, 32, _kn[kk], _kh[kk], _ks) && _s.kind != kk)
        {
            sfx_preview_stop();
            set_val(_s, "kind", kk, "sndkind" + string(current_time));
        }
    }
    _qy += 44;
    if (ui_button("snd_preview", _qx, _qy, _colw, 44, "Play sound  (Space)", "Play|Hear the sound as the C64 plays it: the same frame-by-frame steps as the game, the SID's real envelope rates, noise and filter. Shortcut: Space.", BTN_ACCENT))
    {
        sfx_preview_play(_s);
    }
    _qy += 56;
    var _sh = 90;
    ui_inset(_qx, _qy, _qx + _colw, _qy + _sh, 10);
    ui_register("snd_scope", _qx, _qy, _qx + _colw, _qy + _sh, "Scope|The first quarter second of the sound's wave, as the preview made it.");
    if (preview_key == sfx_key(_s) && array_length(preview_scope) > 1)
    {
        var _cy = _qy + _sh * 0.5;
        var _n = array_length(preview_scope);
        var _px = _qx + 6;
        var _py = _cy - preview_scope[0] * (_sh * 0.45);
        for (var sp = 1; sp < _n; sp++)
        {
            var _nx = _qx + 6 + sp / (_n - 1) * (_colw - 12);
            var _ny = _cy - preview_scope[sp] * (_sh * 0.45);
            draw_line_width_colour(_px, _py, _nx, _ny, 2, global.TH.accent2, global.TH.accent2);
            _px = _nx;
            _py = _ny;
        }
    }
    else
    {
        ui_text(_qx + _colw * 0.5, _qy + _sh * 0.5, "Press Play to see the wave", global.TH.text_faint, fa_center, fa_middle, global.f_small, 1);
    }
    _qy += _sh + 16;
    if (_s.kind == 2)
    {
        ui_text_wrap(_qx, _qy, "A patch plays from a table of SID register changes, one entry a frame - only the registers that change are stored. Patches can't be music instruments: they take whole voices and the filter while they play.", global.TH.text_faint, _colw, global.f_small, 1);
        return;
    }
    if (_s.kind == 1)
    {
        ui_text_wrap(_qx, _qy, "Samples play through the SID's master volume, so while one plays the music and sound effects rise and fall with it - as in every C64 game that talks. The old 6581 SID (VICE's default, and the C64 Ultimate in 6581 mode) plays them loud; the newer 8580 only very quietly.", global.TH.text_faint, _colw, global.f_small, 1);
        return;
    }
    ui_heading(_qx, _qy, "Start from a preset");
    _qy += 20;
    var _pw2 = floor((_colw - 8) / 2);
    var _np = array_length(global.SFX_PRESET_NAMES);
    for (var p = 0; p < _np; p++)
    {
        var _pbx = _qx + (p mod 2) * (_pw2 + 8);
        var _pby = _qy + (p div 2) * 38;
        if (ui_button("snd_preset_" + string(p), _pbx, _pby, _pw2, 32, global.SFX_PRESET_NAMES[p], global.SFX_PRESET_NAMES[p] + " preset|Replaces this sound's settings with a ready-made " + string_lower(global.SFX_PRESET_NAMES[p]) + " sound and plays it. The name, folder and voice stay.", BTN_NORMAL))
        {
            undo_mark("sndpreset" + string(current_time));
            sfx_apply_preset(_s, p);
            sfx_preview_play(_s);
        }
    }
    _qy += ceil(_np / 2) * 38 + 8;
    if (_qy < _y2 - 60)
    {
        ui_text_wrap(_qx, _qy, "Sounds play on SID voices 1 and 2, so two can sound at once. The preview follows the SID closely; the real chip has its own character - always check in VICE or on your C64.", global.TH.text_faint, _colw, global.f_small, 1);
    }
}

/// The sample controls (ADAM's sample panel for the C64): import, rate, crunch, volume, trim, waveform
function sound_sample_panel(_s, _ax, _bx, _colw, _y1, _y2)
{
    var _y = _y1 + 56;
    var _nw = floor(_colw * 0.55);
    ui_heading(_ax, _y, "Name");
    set_val(_s, "name", ui_textfield("snd_name", _ax, _y + 18, _nw, 32, _s.name, 16, "Sound name|Shown on the Logic page when you pick a sound to play."), "sndname");
    ui_heading(_ax + _nw + 8, _y, "Folder");
    var _fnames = ["(none)"];
    for (var g = 0; g < array_length(proj.sound_groups); g++) { array_push(_fnames, proj.sound_groups[g].name); }
    var _fg = ui_dropdown("snd_folder", _ax + _nw + 8, _y + 18, _colw - _nw - 8, 32, _fnames, clamp(_s.group + 1, 0, array_length(_fnames) - 1), "Folder|Which folder this sound is in.");
    set_val(_s, "group", _fg - 1, "sndfolder");
    _y += 62;
    if (ui_button("snd_import", _ax, _y, _colw, 38, "Import WAV...", "Import sample|Loads a .WAV file (8, 16, 24 or 32-bit, mono or stereo, any rate). The first 5 seconds are kept; stereo is mixed to mono.", BTN_ACCENT))
    {
        var _f = get_open_filename("WAV sound|*.wav", "");
        if (_f != "")
        {
            undo_mark("sndimport" + string(current_time));
            if (sfx_import_wav(_s, _f))
            {
                toast("Sample imported: " + string(digi_bytes(_s)) + " bytes on the C64", 0);
                sfx_preview_play(_s);
            }
            else { toast("Could not read that WAV file", 2); }
        }
    }
    _y += 46;
    if (_s.smp == "")
    {
        ui_text_wrap(_ax, _y, "No sample yet. Import a WAV, then choose how crunchy it should sound on the C64.", global.TH.text_dim, _colw, global.f_body, 1);
        return;
    }
    ui_text(_ax, _y, ui_text_fit(_s.smp_file + "  -  " + string_format(_s.smp_len / max(1, _s.smp_rate), 1, 2) + " s", global.f_small, _colw), global.TH.text_faint, fa_left, fa_top, global.f_small, 1);
    _y += 24;
    var _ri = 2;
    for (var r = 0; r < array_length(global.DIGI_RATES); r++)
    {
        if (global.DIGI_RATES[r] == _s.rate) { _ri = r; }
    }
    ui_heading(_ax, _y, "Sample rate");
    var _nri = ui_dropdown("snd_rate", _ax, _y + 18, _colw, 32, global.DIGI_RATE_NAMES, _ri, "Sample rate|How many samples a second the C64 plays - one timer interrupt (NMI) each. Lower rates take less memory and sound grittier; higher rates sound clearer but take more of the C64's time while the sample plays.");
    if (_nri != _ri)
    {
        set_val(_s, "rate", global.DIGI_RATES[_nri], "sndrate" + string(current_time));
        sfx_preview_play(_s);
    }
    _y += 62;
    var _bi = 0;
    for (var b = 0; b < array_length(global.DIGI_BITS); b++)
    {
        if (global.DIGI_BITS[b] == _s.bits) { _bi = b; }
    }
    ui_heading(_ax, _y, "Bit crunch");
    var _nbi = ui_dropdown("snd_bits", _ax, _y + 18, _colw, 32, global.DIGI_BIT_NAMES, _bi, "Bit crunch|The volume register has 16 steps, so C64 samples are 4-bit. Fewer bits crush it further for a lo-fi sound.");
    if (_nbi != _bi)
    {
        set_val(_s, "bits", global.DIGI_BITS[_nbi], "sndbits" + string(current_time));
        sfx_preview_play(_s);
    }
    _y += 62;
    ui_heading(_ax, _y, "Volume  " + string(round(_s.gain)) + "%");
    set_val(_s, "gain", ui_slider("snd_gain", _ax, _y + 18, _colw, _s.gain, 10, 300, "Volume|Makes the sample louder or quieter before it is crunched. With only 16 steps quiet parts vanish - turning it up helps; above 100% it clips, which can sound great on drums."), "sndgain");
    _y += 54;
    var _half = floor((_colw - 12) / 2);
    ui_heading(_ax, _y, "Start");
    set_val(_s, "trim_a", ui_slider("snd_trim_a", _ax, _y + 18, _half, _s.trim_a, 0, 990, "Trim start|Cuts silence or unwanted sound from the beginning."), "sndtrima");
    ui_heading(_ax + _half + 12, _y, "End");
    set_val(_s, "trim_b", ui_slider("snd_trim_b", _ax + _half + 12, _y + 18, _half, _s.trim_b, 10, 1000, "Trim end|Cuts the end off. Shorter samples use less memory."), "sndtrimb");
    if (_s.trim_b <= _s.trim_a + 5) { _s.trim_b = min(1000, _s.trim_a + 10); }

    // ---- column 2: the sample as the C64 plays it, and what it costs ----
    var _d = digi_levels(_s);
    var _gy = _y1 + 74;
    ui_heading(_bx, _gy - 18, "As the C64 plays it");
    var _gh = 170;
    ui_inset(_bx, _gy, _bx + _colw, _gy + _gh, 10);
    ui_register("snd_graph", _bx, _gy, _bx + _colw, _gy + _gh, "Waveform|The sample after trimming, resampling and crunching: each step is one of the 16 volume levels the C64 writes to $D418. The yellow line is the sound playing.");
    var _n = array_length(_d.nib);
    var _mid = _gy + _gh * 0.5;
    var _amp = _gh * 0.5 - 10;
    if (_n > 1)
    {
        var _cols = floor(_colw - 20);
        draw_set_colour(global.TH.accent);
        for (var c = 0; c < _cols; c++)
        {
            var _a = floor(c * _n / _cols);
            var _e = max(_a + 1, floor((c + 1) * _n / _cols));
            var _lo = 15;
            var _hi = 0;
            for (var k = _a; k < min(_e, _n); k++)
            {
                _lo = min(_lo, _d.nib[k]);
                _hi = max(_hi, _d.nib[k]);
            }
            draw_line(_bx + 10 + c, _mid - (_hi - 7.5) / 7.5 * _amp, _bx + 10 + c, _mid - (_lo - 7.5) / 7.5 * _amp + 1);
        }
    }
    var _prog = sfx_preview_progress(_s);
    if (_prog >= 0)
    {
        var _mx = _bx + 10 + _prog * max(1, _colw - 21);
        draw_line_width_colour(_mx, _gy + 8, _mx, _gy + _gh - 8, 2, global.TH.warn, global.TH.warn);
    }
    var _by = _gy + _gh + 12;
    var _info = string(_n div 2) + " bytes  -  " + string_format(_n / max(1, _d.rate), 1, 2) + " s at " + string(round(_d.rate)) + " Hz";
    if (_d.capped) { _info += "  (cut to " + string(DIGI_MAX_BYTES div 1024) + " KB: lower the rate to keep more)"; }
    ui_text(_bx, _by, ui_text_fit(_info, global.f_small, _colw), global.TH.text_dim, fa_left, fa_top, global.f_small, 1);
    _by += 24;
    var _cpu = round(digi_cpu(_s) * 100);
    ui_text_wrap(_bx, _by, "While it plays, the timer interrupt takes about " + string(_cpu) + "% of the C64's time (" + string(round(_d.rate)) + " interrupts a second). In a scrolling map game keep samples short or the rate low, or the game can slow down while one plays.", global.TH.text_faint, _colw, global.f_small, 1);
}
