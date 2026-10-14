/// C64 NO-CODE STUDIO - C64 Ultimate (and Ultimate 64 / 1541 Ultimate II+) over the network.
/// Uses the Ultimate's REST API: GET /v1/version to test the address, POST /v1/runners:run_prg
/// with the .PRG as the body to load and run it, PUT /v1/machine:reset to reset the C64.
/// Turn on "Web Remote Control Service" in the Ultimate's network settings first.

/// "http://address" from what was typed (spaces and a pasted http:// removed)
function u64_base()
{
    var _ip = string_trim(u64_ip);
    _ip = string_replace(_ip, "http://", "");
    _ip = string_replace(_ip, "https://", "");
    if (string_char_at(_ip, string_length(_ip)) == "/") { _ip = string_copy(_ip, 1, string_length(_ip) - 1); }
    return "http://" + _ip;
}

/// Headers for every request (the password, when the Ultimate has one)
function u64_headers(_binary)
{
    var _h = ds_map_create();
    if (_binary) { ds_map_add(_h, "Content-Type", "application/octet-stream"); }
    if (u64_password != "") { ds_map_add(_h, "X-Password", u64_password); }
    return _h;
}

/// Starts a request; _what = "ping", "run" or "reset". Returns true when it went out.
function u64_request(_what, _method, _path, _body)
{
    if (u64_busy)
    {
        toast("Still talking to the C64 Ultimate - wait a moment", 1);
        return false;
    }
    if (string_trim(u64_ip) == "")
    {
        toast("Type your C64 Ultimate's network address on the Build page first", 1);
        ws_set(WS_BUILD);
        return false;
    }
    var _h = u64_headers(_what == "run");
    var _id = http_request(u64_base() + _path, _method, _h, _body);
    ds_map_destroy(_h);
    if (_id < 0)
    {
        u64_status = "Could not start the request";
        u64_status_kind = 2;
        return false;
    }
    u64_busy = true;
    u64_req = _id;
    u64_what = _what;
    u64_started = current_time;
    return true;
}

/// Tests the address (GET /v1/version)
function u64_ping()
{
    if (u64_request("ping", "GET", "/v1/version", ""))
    {
        u64_status = "Looking for the C64 Ultimate at " + u64_base() + "...";
        u64_status_kind = 0;
    }
}

/// Resets the C64 (PUT /v1/machine:reset)
function u64_reset()
{
    if (u64_request("reset", "PUT", "/v1/machine:reset", ""))
    {
        u64_status = "Resetting the C64...";
        u64_status_kind = 0;
    }
}

/// Sends the .PRG at _path and runs it (POST /v1/runners:run_prg)
function u64_send_prg(_path)
{
    if (!file_exists(_path))
    {
        toast("Build the game first", 1);
        return false;
    }
    var _b = buffer_load(_path);
    if (_b < 0)
    {
        toast("Could not read " + filename_name(_path), 2);
        return false;
    }
    if (!u64_request("run", "POST", "/v1/runners:run_prg", _b))
    {
        buffer_delete(_b);
        return false;
    }
    u64_buffer = _b;        // the body has to live until the request is done
    u64_status = "Sending " + filename_name(_path) + " (" + string(buffer_get_size(_b)) + " bytes) to the C64 Ultimate...";
    u64_status_kind = 0;
    build_log_add("Sending to the C64 Ultimate at " + u64_base(), 0);
    return true;
}

/// Async HTTP event: the answer to our request
function u64_http_async()
{
    if (!u64_busy) { return; }
    if (async_load[? "id"] != u64_req) { return; }
    var _st = async_load[? "status"];
    if (_st == 1) { return; }       // still going
    var _code = async_load[? "http_status"];
    var _res = async_load[? "result"];
    if (!is_string(_res)) { _res = ""; }
    u64_busy = false;
    u64_req = -1;
    if (u64_buffer != -1)
    {
        buffer_delete(u64_buffer);
        u64_buffer = -1;
    }
    var _ok = (_st == 0 && _code >= 200 && _code < 300);
    if (u64_what == "ping")
    {
        if (_ok)
        {
            u64_status = "Found it: C64 Ultimate at " + u64_base() + " is ready.";
            u64_status_kind = 0;
            toast("C64 Ultimate found", 0);
        }
        else
        {
            u64_status = u64_error_text(_st, _code);
            u64_status_kind = 2;
        }
        return;
    }
    if (u64_what == "run")
    {
        if (_ok)
        {
            u64_status = "Running on the C64 Ultimate - grab the joystick in port 2!";
            u64_status_kind = 0;
            build_log_add("Running on the C64 Ultimate", 0);
            toast("Running on the C64 Ultimate", 0);
        }
        else
        {
            u64_status = u64_error_text(_st, _code);
            u64_status_kind = 2;
            build_log_add("C64 Ultimate: " + u64_status, 2);
            toast("The C64 Ultimate did not take the game - see the Build page", 2);
        }
        return;
    }
    if (u64_what == "reset")
    {
        if (_ok)
        {
            u64_status = "The C64 has been reset.";
            u64_status_kind = 0;
        }
        else
        {
            u64_status = u64_error_text(_st, _code);
            u64_status_kind = 2;
        }
    }
}

/// Plain words for a failed request
function u64_error_text(_st, _code)
{
    if (_st < 0 || _code == 0) { return "No answer from " + u64_base() + " - check the address, that the Ultimate is on the same network and that its Web Remote Control Service is on."; }
    if (_code == 401 || _code == 403) { return "The C64 Ultimate wants a password (or a different one) - type it on the Build page."; }
    if (_code == 404) { return "That device answered but does not know this command - update the Ultimate's firmware (3.11 or later)."; }
    return "The C64 Ultimate answered with error " + string(_code) + ".";
}

/// Small card in the bottom-right corner while a request is on its way
function u64_card_draw(_gw, _gh)
{
    if (!u64_busy) { return; }
    var _txt = ui_text_fit(u64_status, global.f_bold, 420);
    draw_set_font(global.f_bold);
    var _w = ui_sw(_txt) + 56;
    var _h = 40;
    var _x = _gw - 20 - _w;
    var _y = _gh - 50 - _h;
    ui_shadow(_x, _y, _x + _w, _y + _h, 12, 1);
    ui_rrect(_x, _y, _x + _w, _y + _h, 12, global.TH.btn_top, global.TH.panel_bot, 1);
    ui_rrect_line(_x, _y, _x + _w, _y + _h, 12, global.TH.accent, 0.8, 1);
    var _a = (current_time - u64_started) / 120;
    for (var i = 0; i < 6; i++)
    {
        var _d = degtorad(_a * 30 + i * 60);
        draw_set_alpha(0.25 + i * 0.12);
        draw_circle_colour(_x + 22 + cos(_d) * 7, _y + _h * 0.5 + sin(_d) * 7, 2.2, global.TH.accent, global.TH.accent, false);
    }
    draw_set_alpha(1);
    ui_text(_x + 40, _y + _h * 0.5, _txt, global.TH.text, fa_left, fa_middle, global.f_bold, 1);
}
