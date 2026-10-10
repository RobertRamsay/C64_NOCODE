/// Free everything

sfx_preview_stop();
spr_cache_free();
if (pchars_sprite != -1 && sprite_exists(pchars_sprite)) { sprite_delete(pchars_sprite); }
if (surface_exists(tile_atlas)) { surface_free(tile_atlas); }
ds_map_destroy(ui_rects);
ds_map_destroy(ui_anim);
ds_map_destroy(ui_scroll);
if (global.spr_chars != -1 && sprite_exists(global.spr_chars))
{
    sprite_delete(global.spr_chars);
}
theme_free();
