/// C64 NO-CODE STUDIO - theme, palette and fonts

function theme_init()
{
    global.TH = {
        bg_top      : make_colour_rgb(46, 53, 64),
        bg_bot      : make_colour_rgb(18, 21, 27),
        bar_top     : make_colour_rgb(58, 66, 79),
        bar_bot     : make_colour_rgb(38, 44, 53),
        panel_top   : make_colour_rgb(55, 63, 75),
        panel_bot   : make_colour_rgb(36, 42, 51),
        panel_edge  : make_colour_rgb(82, 94, 110),
        inset_top   : make_colour_rgb(26, 30, 37),
        inset_bot   : make_colour_rgb(33, 38, 46),
        btn_top     : make_colour_rgb(78, 89, 105),
        btn_bot     : make_colour_rgb(56, 64, 77),
        btn_hot_top : make_colour_rgb(98, 111, 130),
        btn_hot_bot : make_colour_rgb(68, 78, 93),
        accent      : make_colour_rgb(122, 162, 255),
        accent_dark : make_colour_rgb(72, 108, 205),
        accent2     : make_colour_rgb(95, 211, 176),
        warn        : make_colour_rgb(255, 200, 87),
        danger      : make_colour_rgb(255, 107, 107),
        danger_dark : make_colour_rgb(176, 62, 62),
        text        : make_colour_rgb(230, 235, 242),
        text_dim    : make_colour_rgb(154, 165, 180),
        text_faint  : make_colour_rgb(104, 114, 130),
        shadow      : c_black,
        radius      : 10
    };

    // Colodore-style C64 palette
    global.C64PAL = [
        make_colour_rgb(0, 0, 0),       make_colour_rgb(255, 255, 255),
        make_colour_rgb(129, 51, 56),   make_colour_rgb(117, 206, 200),
        make_colour_rgb(142, 60, 151),  make_colour_rgb(86, 172, 77),
        make_colour_rgb(46, 44, 155),   make_colour_rgb(237, 241, 113),
        make_colour_rgb(142, 80, 41),   make_colour_rgb(85, 56, 0),
        make_colour_rgb(196, 108, 113), make_colour_rgb(74, 74, 74),
        make_colour_rgb(123, 123, 123), make_colour_rgb(169, 255, 159),
        make_colour_rgb(112, 109, 235), make_colour_rgb(178, 178, 178)
    ];
    global.C64PAL_NAMES = ["Black", "White", "Red", "Cyan", "Purple", "Green", "Blue", "Yellow",
                           "Orange", "Brown", "Light red", "Dark grey", "Grey", "Light green", "Light blue", "Light grey"];

    global.ui_scale = 1;
    global.ui_sx = 1;
    global.ui_sy = 1;
    global.f_body  = -1;
    global.f_bold  = -1;
    global.f_small = -1;
    global.f_title = -1;
    global.f_hero  = -1;
    fonts_load(1);
}

/// (Re)creates the fonts rasterised for the given interface scale
function fonts_load(_scale)
{
    theme_free();
    global.f_body  = -1;
    global.f_bold  = -1;
    global.f_small = -1;
    global.f_title = -1;
    global.f_hero  = -1;
    var _dir = working_directory + "fonts/";
    if (file_exists(_dir + "Poppins-Regular.ttf"))
    {
        global.f_body  = font_add(_dir + "Poppins-Regular.ttf", round(12 * _scale), false, false, 32, 255);
        global.f_small = font_add(_dir + "Poppins-Regular.ttf", round(10 * _scale), false, false, 32, 255);
    }
    if (file_exists(_dir + "Poppins-Medium.ttf"))
    {
        global.f_bold  = font_add(_dir + "Poppins-Medium.ttf", round(12 * _scale), false, false, 32, 255);
        global.f_title = font_add(_dir + "Poppins-Medium.ttf", round(16 * _scale), false, false, 32, 255);
    }
    if (file_exists(_dir + "Poppins-Bold.ttf"))
    {
        global.f_hero = font_add(_dir + "Poppins-Bold.ttf", round(26 * _scale), false, false, 32, 255);
    }
    if (global.f_body == -1)  { global.f_body  = -1; }
    if (global.f_bold == -1)  { global.f_bold  = global.f_body; }
    if (global.f_title == -1) { global.f_title = global.f_bold; }
    if (global.f_hero == -1)  { global.f_hero  = global.f_title; }
    if (global.f_small == -1) { global.f_small = global.f_body; }
}

function theme_free()
{
    if (is_undefined(global.f_body)) { return; }
    var _list = [global.f_body, global.f_bold, global.f_small, global.f_title, global.f_hero];
    var _done = [];
    for (var i = 0; i < array_length(_list); i++)
    {
        var _f = _list[i];
        if (_f != -1 && font_exists(_f))
        {
            var _already = false;
            for (var j = 0; j < array_length(_done); j++)
            {
                if (_done[j] == _f) { _already = true; }
            }
            if (!_already)
            {
                font_delete(_f);
                array_push(_done, _f);
            }
        }
    }
}

function c64col(_index)
{
    return global.C64PAL[clamp(floor(_index), 0, 15)];
}

/// Converts typed text to C64 screen codes (uppercase / graphics set)
function scr_code_from_char(_ch)
{
    var _c = ord(string_upper(_ch));
    if (_c >= 65 && _c <= 90) { return _c - 64; }
    if (_c == 64) { return 0; }
    if (_c >= 32 && _c <= 63) { return _c; }
    return 32;
}
