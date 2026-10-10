/// C64 NO-CODE STUDIO - app controller

// ---------- display ----------
var _aa = 0;
if ((display_aa & 8) != 0) { _aa = 8; }
else
{
    if ((display_aa & 4) != 0) { _aa = 4; }
    else
    {
        if ((display_aa & 2) != 0) { _aa = 2; }
    }
}
display_reset(_aa, true);
draw_set_circle_precision(48);
window_set_min_width(1280);
window_set_min_height(760);
application_surface_draw_enable(false);
gui_w = max(1280, window_get_width());
gui_h = max(720, window_get_height());
display_set_gui_size(gui_w, gui_h);
caption_last = "";
win_w = 0;
win_h = 0;
startup_frames = 0;
ui_scale_pref = 0;
start_fullscreen = true;
global.UI_SCALE_NAMES = ["Auto (fits your screen)", "100%", "125%", "150%", "175%", "200%", "250%", "300%"];
global.UI_SCALE_VALUES = [0, 1, 1.25, 1.5, 1.75, 2, 2.5, 3];

// ---------- systems ----------
theme_init();
project_defs_init();
engine_defs_init();
templates_init();
asm6502_init();
chargen_init();
pixel_sprite_init();

// ---------- UI state ----------
ui_mx = 0;
ui_my = 0;
ui_pressed = false;
ui_pressed_raw = false;
ui_held = false;
ui_released = false;
ui_rpressed = false;
ui_rheld = false;
ui_wheel = 0;
ui_input_ok = true;
ui_force_input = false;
ui_hot = "";
ui_hot_prev = "";
ui_hot_time = 0;
ui_hot_rect = [];
ui_help_title = "";
ui_help_body = "";
ui_rects = ds_map_create();
ui_anim = ds_map_create();
ui_scroll = ds_map_create();
ui_focus = "";
ui_focus_claimed = false;
ui_drag_id = "";
ui_clip = [0, 0, 0, 0];
ui_clip_on = false;
ui_popup_open = false;
ui_popup_id = "";
ui_popup_kind = 0;
ui_popup_x = 0;
ui_popup_y = 0;
ui_popup_w = 0;
ui_popup_opts = [];
ui_popup_index = 0;
ui_popup_anchor_y = 0;
ui_popup_scroll = 0;
ui_popup_rect = [0, 0, 0, 0];
ui_popup_result_id = "";
ui_popup_result = 0;

help_alpha = 0;
help_last_rect = [];
help_last_title = "";
help_last_body = "";
toasts = [];

// ---------- project ----------
proj = project_new();
proj_path = "";
proj_dirty = false;
undo_stack = [];
redo_stack = [];
undo_last_tag = "";
undo_last_time = 0;
autosave_timer = 0;

// ---------- workspaces ----------
ws = WS_HOME;
ws_seen = array_create(WS_COUNT, false);
helpers_on = true;
auto_tutorials = true;
vice_path = "";
out_path = "";

// screen
scr_tool = 0;
scr_char = 81;
scr_colour = 1;
scr_cursor = -1;
scr_cursor_home = 0;
scr_grid = false;
scr_show_actors = true;
scr_painting = false;
scr_box_start = 0;
scr_box_clear = false;

// sprites
spr_sel = 0;
spr_pen = 1;
spr_drawing = false;
spr_clip = "";
spr_surf_own = array_create(SPR_COUNT, -1);
spr_surf_sh = array_create(SPR_COUNT, -1);
spr_surf_sh2 = array_create(SPR_COUNT, -1);
spr_dirty = array_create(SPR_COUNT, true);

// map-game editors
charset_dirty = true;
pchars_sprite = -1;
tile_atlas = -1;
atlas_dirty = true;
tpl_cache = [];
ch_sel = 128;
ch_colour = 1;
ch_mc_view = false;
ch_pen = 3;
ch_drawing = false;
ch_clip = [];
tile_sel = 1;
tile_quad = 0;
map_level = 0;
map_tool = 0;
map_tile = 1;
map_zoom = 24;
map_sx = 0;
map_sy = 0;
map_pan = false;
map_pan_mx = 0;
map_pan_my = 0;
map_drawing = false;
map_box_x = 0;
map_box_y = 0;
map_box_clear = false;
map_spawner_sel = -1;
map_drag_sp = false;
map_show_window = true;
enemy_sel = 0;

// actors
sel_actor = 0;
act_drag = false;
act_drag_dx = 0;
act_drag_dy = 0;

// sound
snd_sel = 0;
preview_sound = -1;
preview_buffer = -1;
preview_inst = -1;

// build
build_log = [];
build_listing = [];
build_warnings = [];
build_ok = false;
build_msg = "";
build_size = 0;
build_end = 0;
build_spr = 0;
build_show_asm = false;

// ---------- tutorials + settings ----------
tut_init();
settings_load();

// restore the last session
var _keep_path = proj_path;
var _auto = autosave_path();
if (file_exists(_auto))
{
    var _txt = file_read_text(_auto);
    if (_txt != "")
    {
        try
        {
            proj = project_from_loaded(json_parse(_txt));
            toast("Welcome back - your last session was restored", 0);
        }
        catch (_e)
        {
            proj = project_new();
        }
    }
}
proj_path = _keep_path;
project_after_change();

if (auto_tutorials && !ws_seen[WS_HOME])
{
    ws_seen[WS_HOME] = true;
    settings_save();
    tut_start(-1);
}
