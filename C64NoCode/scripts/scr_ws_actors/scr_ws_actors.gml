/// C64 NO-CODE STUDIO - Actors workspace (cast + stage)

function actor_names()
{
    var _n = [];
    for (var i = 0; i < array_length(proj.actors); i++) { array_push(_n, proj.actors[i].name); }
    if (array_length(_n) == 0) { array_push(_n, "(no actors yet)"); }
    return _n;
}

function sprite_names()
{
    var _n = [];
    for (var i = 0; i < SPR_COUNT; i++) { array_push(_n, string(i + 1) + ": " + proj.sprites[i].name); }
    return _n;
}

function ws_actors_draw(_x1, _y1, _x2, _y2)
{
    var _lw = 240;
    var _rw = 320;
    var _na = array_length(proj.actors);
    sel_actor = clamp(sel_actor, 0, max(0, _na - 1));

    // ---------------- cast list ----------------
    ui_panel(_x1, _y1, _x1 + _lw, _y2, "Cast  (" + string(_na) + " / 8)");
    var _ly = _y1 + 54;
    var _rowh = 58;
    var _role_short = ["Player", "Bouncer", "Patrol L-R", "Patrol U-D", "Chaser", "Still"];
    for (var i = 0; i < _na; i++)
    {
        var _ac = proj.actors[i];
        var _ry = _ly + i * _rowh;
        var _id = "act_slot_" + string(i);
        var _hot = ui_register(_id, _x1 + 10, _ry, _x1 + _lw - 10, _ry + _rowh - 6, _ac.name + "|Click to select this actor and change its settings on the right.");
        var _tgt = 0;
        if (_hot) { _tgt = 1; }
        var _a = ui_anim_to(_id, _tgt);
        if (sel_actor == i)
        {
            ui_rrect(_x1 + 10, _ry, _x1 + _lw - 10, _ry + _rowh - 6, 10, global.TH.accent, global.TH.accent_dark, 0.9);
        }
        else
        {
            ui_rrect(_x1 + 10, _ry, _x1 + _lw - 10, _ry + _rowh - 6, 10, global.TH.btn_hot_top, global.TH.btn_hot_bot, 0.25 + _a * 0.75);
        }
        ui_rrect(_x1 + 16, _ry + 5, _x1 + 58, _ry + _rowh - 11, 6, c64col(proj.background), c64col(proj.background), 1);
        draw_sprite_c64(_ac.sprite, _x1 + 19, _ry + 7, 1.5, _ac.colour, 1);
        ui_text(_x1 + 68, _ry + 16, ui_text_fit(_ac.name, global.f_bold, _lw - 90), global.TH.text, fa_left, fa_middle, global.f_bold, 1);
        ui_text(_x1 + 68, _ry + 35, _role_short[clamp(_ac.role, 0, 5)], global.TH.text_dim, fa_left, fa_middle, global.f_small, 1);
        if (_hot && ui_pressed)
        {
            sel_actor = i;
            ui_take_click();
        }
    }
    var _by = _y2 - 130;
    var _bw = _lw - 32;
    var _st = BTN_ACCENT;
    if (_na >= 8) { _st = BTN_GHOST; }
    if (ui_button("act_add", _x1 + 16, _by, _bw, 34, "Add actor", "Add actor|Adds a new actor (up to 8 - the C64 has 8 hardware sprites). New actors start in the middle of the screen.", _st))
    {
        if (_na < 8)
        {
            undo_mark("actadd" + string(current_time));
            var _n = actor_new("Actor " + string(_na + 1));
            _n.sprite = min(_na, 7);
            _n.colour = 1 + (_na mod 14);
            if (_na == 0) { _n.role = 0; _n.name = "Player"; }
            array_push(proj.actors, _n);
            sel_actor = _na;
        }
        else
        {
            toast("The C64 has 8 sprites - that is the limit", 1);
        }
    }
    if (ui_button("act_dup", _x1 + 16, _by + 42, _bw, 34, "Duplicate", "Duplicate|Makes a copy of the selected actor, slightly to the side.", BTN_NORMAL))
    {
        if (_na > 0 && _na < 8)
        {
            undo_mark("actdup" + string(current_time));
            var _cp = struct_overlay(actor_new(""), json_parse(json_stringify(proj.actors[sel_actor])));
            _cp.name = _cp.name + " 2";
            _cp.x = min(320, _cp.x + 30);
            array_push(proj.actors, _cp);
            sel_actor = _na;
        }
    }
    if (ui_button("act_del", _x1 + 16, _by + 84, _bw, 34, "Remove", "Remove actor|Deletes the selected actor. Rules that used it will point at the first actor instead. You can Undo this.", BTN_DANGER))
    {
        if (_na > 0)
        {
            undo_mark("actdel" + string(current_time));
            actor_remove(sel_actor);
            sel_actor = max(0, sel_actor - 1);
            _na = array_length(proj.actors);
        }
    }

    // ---------------- stage ----------------
    var _cx1 = _x1 + _lw + 12;
    var _cx2 = _x2 - _rw - 12;
    ui_panel(_cx1, _y1, _cx2, _y2, "");
    var _scale = min((_cx2 - _cx1 - 32) / 384, (_y2 - _y1 - 60) / 272);
    if (_scale >= 2) { _scale = floor(_scale); }
    var _fw = 384 * _scale;
    var _fh = 272 * _scale;
    var _fx = floor((_cx1 + _cx2 - _fw) / 2);
    var _fy = floor((_y1 + _y2 - _fh) / 2) - 10;
    ui_rrect(_fx - 6, _fy - 6, _fx + _fw + 6, _fy + _fh + 6, 10, c_black, c_black, 0.35);
    draw_c64_screen(_fx, _fy, _scale, true);
    // movement area
    ui_dotted_line(_fx + 32 * _scale, _fy + 35 * _scale, _fx + 352 * _scale, _fy + 35 * _scale, global.TH.accent2, 0.35, 4);
    ui_dotted_line(_fx + 32 * _scale, _fy + 235 * _scale, _fx + 352 * _scale, _fy + 235 * _scale, global.TH.accent2, 0.35, 4);

    ui_register("act_stage", _fx, _fy, _fx + _fw, _fy + _fh, "Stage|Drag actors to set where they start. The dotted lines show the play area. Hidden actors are drawn faded.");
    var _hover = -1;
    if (ui_hit(_fx, _fy, _fx + _fw, _fy + _fh))
    {
        for (var h = _na - 1; h >= 0; h--)
        {
            var _hx = _fx + (proj.actors[h].x + 8) * _scale;
            var _hy = _fy + (proj.actors[h].y - 15) * _scale;
            if (point_in_rectangle(ui_mx, ui_my, _hx, _hy, _hx + 24 * _scale, _hy + 21 * _scale))
            {
                _hover = h;
                break;
            }
        }
    }
    if (_hover >= 0 && ui_pressed)
    {
        sel_actor = _hover;
        act_drag = true;
        act_drag_dx = ui_mx - (_fx + (proj.actors[_hover].x + 8) * _scale);
        act_drag_dy = ui_my - (_fy + (proj.actors[_hover].y - 15) * _scale);
        undo_mark("actdrag" + string(current_time));
        ui_take_click();
    }
    if (!ui_held) { act_drag = false; }
    if (act_drag && _na > 0)
    {
        var _ad = proj.actors[sel_actor];
        _ad.x = clamp(round((ui_mx - act_drag_dx - _fx) / _scale - 8), CG_XMIN, CG_XMAX);
        _ad.y = clamp(round((ui_my - act_drag_dy - _fy) / _scale + 15), CG_YMIN, CG_YMAX);
        proj_dirty = true;
    }
    for (var d = 0; d < _na; d++)
    {
        var _ac2 = proj.actors[d];
        var _dx = _fx + (_ac2.x + 8) * _scale;
        var _dy = _fy + (_ac2.y - 15) * _scale;
        var _alpha = 1;
        if (!_ac2.visible) { _alpha = 0.4; }
        draw_sprite_c64(_ac2.sprite, _dx, _dy, _scale, _ac2.colour, _alpha);
        if (d == sel_actor)
        {
            ui_rrect_line(_dx - 4, _dy - 4, _dx + 24 * _scale + 4, _dy + 21 * _scale + 4, 6, global.TH.accent, 1, 2);
            ui_text(_dx, _dy - 8, _ac2.name, c_white, fa_left, fa_bottom, global.f_small, 1);
        }
        else
        {
            if (d == _hover)
            {
                ui_rrect_line(_dx - 3, _dy - 3, _dx + 24 * _scale + 3, _dy + 21 * _scale + 3, 6, c_white, 0.7, 1);
                ui_help_title = _ac2.name;
                ui_help_body = "Drag to move where this actor starts.";
            }
        }
    }
    if (act_drag && _na > 0)
    {
        var _ag = proj.actors[sel_actor];
        var _gx = _fx + (_ag.x + 8 + 12) * _scale;
        var _gy = _fy + (_ag.y - 15 + 10) * _scale;
        ui_dotted_line(_fx, _gy, _fx + _fw, _gy, global.TH.warn, 0.7, 5);
        ui_dotted_line(_gx, _fy, _gx, _fy + _fh, global.TH.warn, 0.7, 5);
        var _txt = "X " + string(_ag.x) + "   Y " + string(_ag.y);
        draw_set_font(global.f_small);
        var _tw = ui_sw(_txt) + 20;
        ui_rrect(_gx + 14, _gy + 14, _gx + 14 + _tw, _gy + 38, 10, global.TH.btn_top, global.TH.btn_bot, 0.95);
        ui_text(_gx + 24, _gy + 26, _txt, global.TH.warn, fa_left, fa_middle, global.f_small, 1);
    }
    ui_text((_cx1 + _cx2) / 2, _fy + _fh + 22, "Drag actors to place them. Behaviour, speed and colour are on the right.", global.TH.text_faint, fa_center, fa_middle, global.f_small, 1);

    // ---------------- properties ----------------
    var _px = _x2 - _rw;
    ui_panel(_px, _y1, _x2, _y2, "Actor settings");
    var _fx2 = _px + 20;
    var _fw2 = _rw - 40;
    if (_na == 0)
    {
        ui_text_wrap(_fx2, _y1 + 60, "No actors yet. Press 'Add actor' to create your player. The first actor you add is set up as the player for you.", global.TH.text_dim, _fw2, global.f_body, 1);
        return;
    }
    var _s = proj.actors[sel_actor];
    var _y = _y1 + 56;
    ui_heading(_fx2, _y, "Name");
    set_val(_s, "name", ui_textfield("act_name", _fx2, _y + 18, _fw2, 32, _s.name, 20, "Actor name|Used in the Logic page so your rules read nicely, e.g. 'Hero touches Ghost'."), "actname");
    _y += 62;
    var _half = floor((_fw2 - 12) / 2);
    ui_heading(_fx2, _y, "Sprite");
    if (set_val(_s, "sprite", ui_dropdown("act_sprite", _fx2, _y + 18, _half, 32, sprite_names(), _s.sprite, "Sprite|Which picture this actor uses. Draw them on the Sprites page."), "actsprite")) { }
    ui_heading(_fx2 + _half + 12, _y, "Colour");
    set_val(_s, "colour", ui_colour_drop("act_colour", _fx2 + _half + 12, _y + 18, _half, 32, _s.colour, "Actor colour|The sprite's own colour. Two actors can share a sprite but have different colours."), "actcol");
    _y += 62;
    ui_heading(_fx2, _y, "Behaviour");
    set_val(_s, "role", ui_dropdown("act_role", _fx2, _y + 18, _fw2, 32, global.ROLE_NAMES, _s.role, "Behaviour|How this actor moves on its own. Pick 'Player' for the one the joystick controls."), "actrole");
    _y += 58;
    var _rdesc = [
        "Moves with a joystick in port 2. Stops at the edges of the screen.",
        "Moves diagonally and bounces off every edge like a ball.",
        "Moves left and right, turning around at the screen edges.",
        "Moves up and down, turning around at the top and bottom.",
        "Always heads towards the player. Speed 1 is gentle, 3 is scary!",
        "Stays where you put it. Great for pickups, doors and goals."
    ];
    ui_rrect(_fx2, _y, _fx2 + _fw2, _y + 50, 8, global.TH.inset_top, global.TH.inset_bot, 0.8);
    ui_text_wrap(_fx2 + 10, _y + 7, _rdesc[clamp(_s.role, 0, 5)], global.TH.text_dim, _fw2 - 20, global.f_small, 1);
    _y += 62;
    ui_heading(_fx2, _y, "Speed");
    set_val(_s, "speed", ui_stepper("act_speed", _fx2, _y + 18, _half, _s.speed, 1, 8, "Speed|Pixels moved every frame (50 frames per second). 1 is slow, 8 is very fast."), "actspeed");
    ui_heading(_fx2 + _half + 12, _y, "Visible at start");
    set_val(_s, "visible", ui_toggle("act_vis", _fx2 + _half + 12, _y + 22, "Shown", _s.visible, "Visible at start|Hidden actors can be shown later with the 'Show actor' action in Logic."), "actvis");
    _y += 62;
    if (_s.role == 1 || _s.role == 2)
    {
        set_val(_s, "start_left", ui_toggle("act_left", _fx2, _y, "Starts moving left", _s.start_left, "Start direction|Whether this actor starts heading left instead of right."), "actleft");
        _y += 32;
    }
    if (_s.role == 1 || _s.role == 3)
    {
        set_val(_s, "start_up", ui_toggle("act_up", _fx2, _y, "Starts moving up", _s.start_up, "Start direction|Whether this actor starts heading up instead of down."), "actup");
        _y += 32;
    }
    _y += 6;
    ui_heading(_fx2, _y, "Start X");
    set_val(_s, "x", ui_stepper("act_x", _fx2, _y + 18, _half, _s.x, CG_XMIN, CG_XMAX, "Start X|Horizontal start position in C64 sprite pixels (24 = left edge, 320 = right edge). Hold Shift for steps of 10."), "actx");
    ui_heading(_fx2 + _half + 12, _y, "Start Y");
    set_val(_s, "y", ui_stepper("act_y", _fx2 + _half + 12, _y + 18, _half, _s.y, CG_YMIN, CG_YMAX, "Start Y|Vertical start position (50 = top, 229 = bottom). Hold Shift for steps of 10."), "acty");
}
