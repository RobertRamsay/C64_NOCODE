/// Window sizing, autosave, shortcuts

var _ww = window_get_width();
var _wh = window_get_height();
if (_ww > 0 && _wh > 0)
{
    if (_ww != gui_w || _wh != gui_h)
    {
        gui_w = _ww;
        gui_h = _wh;
        display_set_gui_size(gui_w, gui_h);
    }
}

autosave_timer += delta_time / 1000000;
if (autosave_timer > 30)
{
    autosave_timer = 0;
    if (proj_dirty)
    {
        file_write_text(autosave_path(), json_stringify(proj));
    }
}

shortcuts_step();

var _cap = "C64 No-Code Studio - " + proj.name;
if (proj_dirty) { _cap += " *"; }
if (_cap != caption_last)
{
    caption_last = _cap;
    window_set_caption(_cap);
}
