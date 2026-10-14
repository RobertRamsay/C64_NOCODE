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
tpl_prev = [];
ch_sel = 128;
ch_colour = 1;
ch_mc_view = false;
ch_pen = 3;
ch_drawing = false;
ch_clip = [];
tile_sel = 1;
tile_quad = 0;
// the Tiles page: the tab (0 tile set, 1 characters), drawing, the multicolour pen
tile_page = 0;
tile_drawing = false;
tile_pen_mc = 3;
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
snd_ungrouped_open = true;
snd_drag = -1;
snd_patch_tab = 0;
snd_patch_osc = 0;
snd_patch_content_h = 0;
snd_drag_y0 = 0;
snd_dragging = false;
preview_sound = -1;
preview_buffer = -1;
preview_inst = -1;
preview_start = 0;
preview_len_ms = 0;
preview_key = "";
preview_scope = [];
// Music page (scr_ws_music) and its preview player (scr_music)
mus_song = 0;
mus_cat = 0;
mus_brush_src = 0;
mus_brush = 0;
mus_edit = -1;
mus_edit_lane = -1;
mus_edit_bar = -1;
mus_edit_step = -1;
mus_xoff = 0;
mus_range = 2;
mus_from = 0;
mus_paint = 0;
mus_paint_cell = "";
mus_paint_tag = "";
mus_click_t = 0;
mus_click_key = "";
mus_edit_seen = "";
// the step editor (ADAM's)
mus_ed_keys_hover = false;
mus_ed_resolution = 16;
mus_ed_select_ref = undefined;
mus_ed_selected = array_create(MUS_STEPS, false);
mus_ed_select_drag = false;
mus_ed_select_start = [0, 0];
mus_ed_select_end = [0, 0];
mus_ed_clip = { notes : [], drums : false };
mus_ed_resize_step = -1;
mus_ed_resize_changed = false;
mus_ed_tag = "";
mus_ed_painting = false;
mus_ed_rclear = false;
mus_ed_note_drag = false;
mus_ed_note_glide = false;
mus_ed_note_group = false;
mus_ed_note_copy = false;
mus_ed_note_src = [0, 0];
mus_ed_note_last = [-1, -1];
mus_ed_note_pitch = 0;
mus_ed_note_inst = 0;
mus_ed_note_fx = 0;
mus_ed_note_fxp = 0;
mus_ed_note_moved = false;
mus_ed_note_preview_pitch = 0;
mus_ed_alt_preview_step = -1;
mus_ed_alt_preview_row = -1;
mus_ed_fx_step = 0;
mus_ed_fx_drag = false;
mus_ed_fx_src = 0;
mus_ed_fx_end = 0;
// Animate page (scr_ws_animate)
anim_cast_sel = 0;
anim_sel = 1;
anim_slot = 0;
anim_t0 = 0;
anim_test = false;
anim_test_source = 0;
anim_test_entry = -1;
anim_test_t0 = 0;
anim_test_dir = 2;
anim_test_face = false;
anim_face_left = false;
anim_click_id = "";
anim_click_time = 0;
anim_click_added = false;
anim_click_set = undefined;
anim_lib_tab = 0;
anim_drag_armed = false;
anim_drag_on = false;
anim_drag_x0 = 0;
anim_drag_y0 = 0;
anim_drag_frames = [];
anim_drag_rate = 8;
anim_drag_mode = 0;
anim_drag_flip = false;
anim_drag_col = 1;
anim_drag_label = "";
anim_drag_src = -1;
anim_drop_k = -1;
// Bitmaps page (scr_ws_bitmap)
bm_sel = 0;
bm_tool = 0;
bm_pen = 1;
bm_pen2 = 0;
bm_brush = 0;
bm_pattern = 0;
bm_filled = false;
bm_shades = false;
bm_zoom = 0;
bm_pan_x = 0;
bm_pan_y = 0;
bm_panning = false;
bm_pan_mx = 0;
bm_pan_my = 0;
bm_grid = false;
bm_drag = 0;
bm_ax = 0;
bm_ay = 0;
bm_lx = 0;
bm_ly = 0;
bm_last_x = -1;
bm_last_y = -1;
bm_clip = undefined;
bm_stamping = false;
bm_texting = false;
bm_tx = 0;
bm_ty = 0;
bm_tx0 = 0;
bm_imp = undefined;
bm_tab = 0;
bm_cache = { ref : undefined, src : "", w : 0, buf : -1, rgba : -1, surf : -1, d1 : 0, d2 : -1 };
bm_thumbs = {};
// the UI page (custom HUD)
hud_sel = 0;
hud_drag = -1;
hud_drag_dx = 0;
hud_drag_dy = 0;
hud_edit_tab = 0;
hud_pen = 1;
hud_font_char = 1;
hud_drawing = false;
hud_sheet = -1;
hud_prev_surf = -1;
hud_sheet_key = "";
hud_sheet_tick = 0;
hud_away = true;
mus_pl = undefined;
mus_queue = -1;
mus_inst = -1;
mus_bufs = [];
mus_marks = [];
mus_rendered = 0;
mus_playing = false;
mus_play_what = "";
mus_started = 0;
mus_old_bufs_time = 0;

// logic + code previewer
logic_sel = -1;
logic_reveal = -1;
logic_resort = false;
logic_code_on = true;
codeview_sel_only = false;
codeview_follow = false;

// live build (code previewer + memory bar): the game made again a moment after each change
live_stale = true;
live_stale_time = 0;
live_proj_ref = undefined;
live_machine = -1;
live_type = -1;
live_ok = false;
live_err = "";
live_lines = [];
live_marks = [];
live_rule_bytes = [];
live_end = 2049;
live_size = 0;
live_limit = 40960;
live_spr_end = 0;
live_seg_code = 0;
live_seg_sound = 0;
live_seg_gap = 0;
live_seg_sprites = 0;
live_seg_data = 0;
live_seg_music = 0;
live_seg_pics = 0;

// C64 Ultimate on the network
u64_ip = "";
u64_password = "";
u64_busy = false;
u64_req = -1;
u64_what = "";
u64_buffer = -1;
u64_started = 0;
u64_status = "";
u64_status_kind = 0;

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
