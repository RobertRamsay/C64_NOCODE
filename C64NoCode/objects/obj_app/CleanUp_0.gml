/// Free everything

sfx_preview_stop();
music_preview_stop();
for (var mb = 0; mb < array_length(mus_bufs); mb++)
{
    if (buffer_exists(mus_bufs[mb])) { buffer_delete(mus_bufs[mb]); }
}
if (u64_buffer != -1) { buffer_delete(u64_buffer); }
spr_cache_free();
// the Bitmaps page's canvas, thumbnails and any import in progress
if (bm_cache.buf >= 0 && buffer_exists(bm_cache.buf)) { buffer_delete(bm_cache.buf); }
if (bm_cache.rgba >= 0 && buffer_exists(bm_cache.rgba)) { buffer_delete(bm_cache.rgba); }
if (surface_exists(bm_cache.surf)) { surface_free(bm_cache.surf); }
var _bmt = variable_struct_get_names(bm_thumbs);
for (var bt = 0; bt < array_length(_bmt); bt++)
{
    if (surface_exists(bm_thumbs[$ _bmt[bt]].surf)) { surface_free(bm_thumbs[$ _bmt[bt]].surf); }
}
bm_import_cancel();
if (pchars_sprite != -1 && sprite_exists(pchars_sprite)) { sprite_delete(pchars_sprite); }
if (surface_exists(tile_atlas)) { surface_free(tile_atlas); }
for (var tp = 0; tp < array_length(tpl_prev); tp++)
{
    if (surface_exists(tpl_prev[tp])) { surface_free(tpl_prev[tp]); }
}
ds_map_destroy(ui_rects);
ds_map_destroy(ui_anim);
ds_map_destroy(ui_scroll);
if (global.spr_chars != -1 && sprite_exists(global.spr_chars))
{
    sprite_delete(global.spr_chars);
}
if (sprite_exists(global.spr_px)) { sprite_delete(global.spr_px); }
theme_free();
