/// The whole studio is drawn here in GUI space

ui_frame_begin();
ui_background(gui_w, gui_h);

var _x1 = 16;
var _y1 = 76;
var _x2 = gui_w - 16;
var _y2 = gui_h - 46;

switch (ws)
{
    case WS_HOME:    ws_home_draw(_x1, _y1, _x2, _y2);    break;
    case WS_SCREEN:  ws_screen_draw(_x1, _y1, _x2, _y2);  break;
    case WS_SPRITES: ws_sprites_draw(_x1, _y1, _x2, _y2); break;
    case WS_ACTORS:  ws_actors_draw(_x1, _y1, _x2, _y2);  break;
    case WS_LOGIC:   ws_logic_draw(_x1, _y1, _x2, _y2);   break;
    case WS_SOUND:   ws_sound_draw(_x1, _y1, _x2, _y2);   break;
    case WS_BUILD:   ws_build_draw(_x1, _y1, _x2, _y2);   break;
    case WS_TEMPLATES: ws_templates_draw(_x1, _y1, _x2, _y2); break;
    case WS_WORLD:   ws_world_draw(_x1, _y1, _x2, _y2);   break;
    case WS_CHARSET: ws_charset_draw(_x1, _y1, _x2, _y2); break;
    case WS_TILES:   ws_tiles_draw(_x1, _y1, _x2, _y2);   break;
    case WS_MAP:     ws_map_draw(_x1, _y1, _x2, _y2);     break;
    case WS_ENEMIES: ws_enemies_draw(_x1, _y1, _x2, _y2); break;
    case WS_MUSIC:   ws_music_draw(_x1, _y1, _x2, _y2);   break;
    case WS_ANIMATE: ws_animate_draw(_x1, _y1, _x2, _y2); break;
}

draw_topbar(gui_w);
ui_status_bar(gui_w, gui_h);
ui_popup_draw(gui_w, gui_h);
u64_card_draw(gui_w, gui_h);
toasts_draw(gui_w, gui_h);
tut_draw(gui_w, gui_h);
// last, so a help bubble is never hidden under the cards and panels
ui_help_draw(gui_w, gui_h);
ui_frame_end();

draw_set_colour(c_white);
draw_set_alpha(1);
