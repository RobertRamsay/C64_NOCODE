/// C64 NO-CODE STUDIO - SID sound preview inside the editor (rendered by sfx_render in scr_sid)

function sfx_preview_stop()
{
    if (preview_sound != -1)
    {
        audio_stop_sound(preview_inst);
        audio_free_buffer_sound(preview_sound);
        preview_sound = -1;
    }
    if (preview_buffer != -1)
    {
        buffer_delete(preview_buffer);
        preview_buffer = -1;
    }
    preview_key = "";
}

function sfx_preview_play(_s)
{
    sfx_preview_stop();
    preview_buffer = sfx_render(_s);
    var _bytes = buffer_get_size(preview_buffer);
    preview_sound = audio_create_buffer_sound(preview_buffer, buffer_s16, SFX_PREVIEW_RATE, 0, _bytes, audio_mono);
    preview_inst = audio_play_sound(preview_sound, 1, false);
    preview_start = current_time;
    preview_len_ms = (_bytes / 2) / SFX_PREVIEW_RATE * 1000;
    preview_key = sfx_key(_s);
    // the scope on the Sound page shows the start of the sound
    preview_scope = array_create(256, 0);
    var _n = _bytes div 2;
    var _span = min(_n, floor(SFX_PREVIEW_RATE * 0.25));
    for (var i = 0; i < 256; i++)
    {
        var _at = floor(i / 256 * _span);
        preview_scope[i] = buffer_peek(preview_buffer, _at * 2, buffer_s16) / 32768;
    }
}

/// 0..1 through the sound being played, or -1 when _s is not the one playing
function sfx_preview_progress(_s)
{
    if (preview_sound == -1 || preview_key != sfx_key(_s)) { return -1; }
    if (!audio_is_playing(preview_inst)) { return -1; }
    return clamp((current_time - preview_start) / max(1, preview_len_ms), 0, 1);
}
