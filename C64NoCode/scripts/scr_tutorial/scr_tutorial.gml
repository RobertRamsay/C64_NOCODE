/// C64 NO-CODE STUDIO - tutorials: a full guided tour plus a mini tour per page

function tut_step(_tab, _target, _title, _body)
{
    return { tab : _tab, target : _target, title : _title, body : _body };
}

function tut_init()
{
    tut_steps = [
        // ---------- HOME ----------
        tut_step(WS_HOME, "", "Welcome to C64 No-Code Studio", "You are going to make a real Commodore 64 game without writing a single line of code. This tour visits every page. Use Next and Back, or the arrow keys. Press Esc to leave at any time."),
        tut_step(WS_HOME, "home_example", "Try the example first", "This loads 'Gem Hunter', a finished little game. It is a great way to see how everything fits together. Go ahead and click it if you like - you can Undo or start a New project any time."),
        tut_step(WS_HOME, "home_card_0", "Six simple steps", "Every game is made the same way: paint a screen, draw sprites, place actors, write rules, add sounds, then build. Click any card to jump to that page."),
        tut_step(WS_HOME, "home_name", "Name your game", "Give your game a name. It is also used for the file names when you save and build."),
        tut_step(WS_HOME, "home_lives", "Lives and score", "Choose how many lives the player gets and whether the score and lives are shown. A rule on the Logic page takes lives away."),
        tut_step(WS_HOME, "home_over", "Messages", "These messages appear when the game ends. The player presses fire to play again."),
        tut_step(WS_HOME, "top_helpers", "Hover helpers", "Rest your mouse on anything and a helper line points to a bubble that explains it. Switch them off here once you know your way around."),
        tut_step(WS_HOME, "top_machine", "Pick your C64", "PAL (Europe), NTSC (USA) or a C64 Ultimate on your network. Timers and sounds are worked out for the machine you pick, and Build & play goes to VICE or straight to the Ultimate."),
        tut_step(WS_HOME, "top_play", "Build and play from anywhere", "Press this (or F5) on any page to build your game and play it at once."),
        tut_step(WS_HOME, "mem_bar", "The memory bar", "This shows how full your C64 program is, a moment after every change: code, sounds, sprites and screen data. Hover it to see where the C64's limits are."),
        tut_step(WS_HOME, "top_tutorial", "Help is always here", "Every page has its own short tutorial. Press this button or F1 whenever you are unsure."),
        tut_step(WS_HOME, "top_undo", "Undo and Redo", "Made a mistake? Undo (Ctrl+Z) takes it back and Redo (Ctrl+Y) puts it back again. Nothing is ever lost."),
        // ---------- SCREEN ----------
        tut_step(WS_SCREEN, "scr_canvas", "The C64 screen", "This is your game's background: 40 characters across and 25 down, surrounded by the border. Actors move on top of it."),
        tut_step(WS_SCREEN, "scr_charpal", "Pick a character", "The C64 has 256 built-in characters, including the famous PETSCII blocks and lines. Click one to paint with it."),
        tut_step(WS_SCREEN, "scr_colour", "Pick a colour", "Every square on the screen can have its own colour from the C64's 16."),
        tut_step(WS_SCREEN, "scr_tool_0", "Brush", "Click and drag on the screen to paint. Right-click rubs out. Alt-click picks up a character you already placed."),
        tut_step(WS_SCREEN, "scr_tool_1", "Type text", "Choose this, click on the screen and just type. Great for titles and instructions."),
        tut_step(WS_SCREEN, "scr_tool_3", "Box fill", "Drag out a box to fill a whole area - perfect for walls, floors and frames."),
        tut_step(WS_SCREEN, "scr_border", "Border and background", "Change the colour of the frame around the screen and the colour behind the characters."),
        tut_step(WS_SCREEN, "scr_actors", "See your actors", "Turn this on to see where your actors start, so you can design the screen around them."),
        // ---------- SPRITES ----------
        tut_step(WS_SPRITES, "spr_slot_0", "Your 8 sprites", "Sprites are the little pictures that move around. The C64 can show 8 at once. Pick a slot to edit it."),
        tut_step(WS_SPRITES, "spr_grid", "Draw pixels", "Left-click to draw, right-click to rub out. The blue lines split the sprite into its three 8-pixel columns."),
        tut_step(WS_SPRITES, "spr_mc", "Hi-res or multicolour", "Hi-res sprites have fine detail in one colour. Multicolour sprites have chunkier pixels but up to three colours."),
        tut_step(WS_SPRITES, "spr_name", "Name it", "Give each sprite a name - you will pick sprites by name on the Actors page."),
        tut_step(WS_SPRITES, "spr_op_fliph", "Quick changes", "Flip, invert and shift the whole sprite with one click. Flip H makes a character face the other way."),
        tut_step(WS_SPRITES, "spr_op_copy", "Copy and paste", "Copy a sprite, pick another slot and paste. Handy for making animation frames or variations."),
        // ---------- ACTORS ----------
        tut_step(WS_ACTORS, "act_add", "Add actors", "Actors are the things in your game: the player, enemies, pickups. Each one uses a sprite. The first actor you add is your player."),
        tut_step(WS_ACTORS, "act_stage", "Place them", "Drag actors around the stage to choose where they start. Guide lines show the exact position while you drag."),
        tut_step(WS_ACTORS, "act_role", "Choose a behaviour", "This is the magic part: a Player follows the joystick, a Chaser hunts the player, Bouncers bounce and Still things stay put. No code needed."),
        tut_step(WS_ACTORS, "act_speed", "Speed", "How fast this actor moves. Try 1 or 2 for enemies to start with - you can always speed them up with a rule."),
        tut_step(WS_ACTORS, "act_sprite", "Sprite and colour", "Pick which sprite this actor looks like and its colour. Two ghosts can share one sprite in different colours."),
        tut_step(WS_ACTORS, "act_vis", "Hidden actors", "Actors can start hidden and appear later using the 'Show actor' action."),
        // ---------- LOGIC ----------
        tut_step(WS_LOGIC, "", "Rules make it a game", "Each rule is a sentence: WHEN something happens, DO something. For example: WHEN Hero touches Gem, DO add 10 to the score."),
        tut_step(WS_LOGIC, "logic_add", "Add a rule", "Press this to add a new rule, then change its parts with the drop-down menus."),
        tut_step(WS_LOGIC, "rule_0_when", "The WHEN part", "Choose what triggers the rule: two actors touching, the fire button, a timer, a score target, running out of lives or the game starting. (Add a rule first if the list is empty.)"),
        tut_step(WS_LOGIC, "rule_0_act", "The DO part", "Choose what happens: add score, lose a life, play a sound, move or hide actors, change colours, win or game over."),
        tut_step(WS_LOGIC, "rule_0_anddo", "AND DO", "One rule can do up to five things: add points AND play a sound AND move the gem. The lines run in order every time the rule fires."),
        tut_step(WS_LOGIC, "logic_addgroup", "Groups", "Put related rules in a named group. Fold it to tidy up, put groups inside groups, or switch a group off to test the game without those rules."),
        tut_step(WS_LOGIC, "logic_tab_code", "See the 6502", "Click a rule card and this panel shows the real C64 machine code it becomes - written for you, updated as you change things."),
        tut_step(WS_LOGIC, "logic_tab_recipes", "Quick recipes", "Not sure where to start? This tab has buttons that add complete, ready-made rules for the most common game ideas."),
        tut_step(WS_LOGIC, "rule_0_up", "Order and removing", "Rules are checked top to bottom every frame. Use the arrows to reorder and X to remove."),
        // ---------- SOUND ----------
        tut_step(WS_SOUND, "snd_slot_0", "Your sounds", "Up to 32 sound effects, in folders. Pick one to edit it, or press Play to hear it. + Sound adds one, + Folder makes a folder - drag sounds onto it."),
        tut_step(WS_SOUND, "snd_preset_0", "Start from a preset", "The quickest way to a good sound: pick a preset like Coin or Explosion, then tweak it."),
        tut_step(WS_SOUND, "snd_wave", "Waveform", "The basic tone of the SID chip: soft triangle, buzzy sawtooth, classic pulse, crunchy noise - or one of the SID's combined waveforms."),
        tut_step(WS_SOUND, "snd_voice_0", "Two voices", "Sounds play on SID voice 1 or 2, so two can play at once - put the shot and the explosion on different voices. While a sound plays it borrows that voice from the music; voice 3 is the music's alone."),
        tut_step(WS_SOUND, "snd_pw", "Pulse width", "The pulse wave's shape. Sweep it for the famous C64 'PWM' sound."),
        tut_step(WS_SOUND, "snd_sweep", "Pitch slide", "Make the pitch rise or fall. Falling slides sound like lasers, rising slides like coins and power-ups."),
        tut_step(WS_SOUND, "snd_graph", "Envelope", "Attack, decay, sustain and release shape how the volume changes over time. The picture updates as you move the sliders."),
        tut_step(WS_SOUND, "snd_fmode", "The SID filter", "Low pass, band pass or high pass with resonance and a sweep - filtered noise makes great explosions and wind."),
        tut_step(WS_SOUND, "snd_kind_1", "Real samples", "Switch a sound to Sample and import a WAV - a voice, a drum, an explosion. The C64 plays it the classic way, 4-bit through the SID volume register, and the page shows what it costs in memory and CPU time."),
        tut_step(WS_SOUND, "snd_kind_2", "Patches", "Patch is ADAM's patch synth on the real chip: three oscillators with sync and ring modulation, the filter with its own envelope, LFOs and a modulation matrix. Start from a preset, or press Randomise and Mutate until something great happens."),
        tut_step(WS_SOUND, "snd_preview", "Listen", "Play the sound any time (or press Space). Rules on the Logic page choose when your game plays it."),
        // ---------- MUSIC ----------
        tut_step(WS_MUSIC, "", "Music", "Songs for the SID chip's 3 voices, played by a small music driver inside your game. Sound effects borrow voice 1 or 2 while they play, then the music has the voice back."),
        tut_step(WS_MUSIC, "mus_cat_0", "The loop library", "Ready-made one-bar loops: drums, bass, chords, leads and effects. Click one to hear it - it becomes your brush."),
        tut_step(WS_MUSIC, "mus_grid", "Paint the song", "Each row is a SID voice, each box a bar. Click empty bars to paint your loop, right-click to rub out, double-click a loop to change its notes in the step editor: drag a note's circle onto a later note to bend into it, and use the effect row for slides, vibrato and volume."),
        tut_step(WS_MUSIC, "mus_play", "Listen", "Play one bar, 4 bars or the whole song from the white marker (click the bar numbers). Space plays and stops."),
        tut_step(WS_MUSIC, "mus_imod", "Bring in a MOD", "Import .mod turns a ProTracker module into a song: its 3 busiest channels become the SID voices and its samples become SID instruments. Save .mod goes the other way, for Amiga trackers and OpenMPT."),
        tut_step(WS_MUSIC, "mus_speed", "Speed and swing", "The driver runs once a frame, so speed is frames per step: 3 is 125 BPM on a PAL C64. Swing gives it a shuffle."),
        tut_step(WS_MUSIC, "mus_lvl_0", "Where it plays", "Pick the song for your game. On the Logic page, Play music and Stop music change it while the game runs."),
        // ---------- BUILD ----------
        tut_step(WS_BUILD, "", "Time to play", "This page turns your project into a real C64 program. The checklist warns you about anything that might be missing."),
        tut_step(WS_BUILD, "build_prg", "Build", "Press Build to create a .PRG file. It runs in any C64 emulator, on a C64 Ultimate or on a real C64 from an SD2IEC or disk."),
        tut_step(WS_BUILD, "build_vicepath", "Set up VICE", "VICE is a free C64 emulator. Point the studio at x64sc.exe once and it will remember."),
        tut_step(WS_BUILD, "build_run", "Build and play", "Builds your game and launches it in VICE straight away - or on your C64 Ultimate when that is the target. Plug the joystick into port 2!"),
        tut_step(WS_BUILD, "u64_ip", "C64 Ultimate", "Got a C64 Ultimate, Ultimate 64 or 1541 Ultimate II+? Type its network address here, press Test, then Send & run plays your game on the real machine in a second."),
        tut_step(WS_BUILD, "build_showasm", "Peek under the hood", "Curious? This shows the 6502 assembly language the studio wrote for you. You never have to touch it."),
        tut_step(WS_BUILD, "", "You're ready!", "That's everything. Load the example, change something, build it and see what happens. Have fun making games!"),
        // ---------- TEMPLATES ----------
        tut_step(WS_TEMPLATES, "tpl_card_1", "Start from a template", "Each card is a complete game: shoot-em-ups, platformers, a Boulder Dash style cave and a maze. The picture shows the start of its first level."),
        tut_step(WS_TEMPLATES, "tpl_use_1", "Use it", "This replaces your project with the template. Then change anything - every tile, enemy and setting is yours to edit. Undo brings your old project back."),
        // ---------- WORLD ----------
        tut_step(WS_WORLD, "w_kind", "Kind of game", "Choose how the player moves: flying and shooting, running and jumping, digging through a cave, or walking a maze."),
        tut_step(WS_WORLD, "w_scroll", "Scrolling", "Horizontal, vertical, 8-way or flip-screen. Shoot-em-ups can scroll by themselves; the others follow the player."),
        tut_step(WS_WORLD, "w_wrows", "The play window", "Only the window scrolls; row 0 is the score bar. Fewer rows means less work for the C64 on every scroll step."),
        tut_step(WS_WORLD, "w_meter", "Stock C64 cycle meter", "This shows how busy the C64 is on its hardest frame. Stay left of the white line and the game scrolls at a smooth 50 frames per second on a real machine."),
        tut_step(WS_WORLD, "w_fit", "Auto-fit", "Not sure? This shrinks the window until it fits the budget."),
        tut_step(WS_WORLD, "w_weapon", "Weapons", "Pick what the fire button shoots, then set the bullet picture, speed and reload time."),
        // ---------- MAP ----------
        tut_step(WS_MAP, "map_view", "Your level", "Paint with the left button, rub out with the right. The mouse wheel scrolls and middle-drag pans around big maps."),
        tut_step(WS_MAP, "map_pal", "Tile palette", "Pick the tile to paint with. Tiles are made on the Tiles page."),
        tut_step(WS_MAP, "map_tool_3", "Enemy spawners", "Place spawners where enemies should appear. They wake up when that part of the map scrolls into view."),
        tut_step(WS_MAP, "map_tool_4", "Player start", "Click where the player begins the level."),
        tut_step(WS_MAP, "map_win", "Screen-size guide", "The dotted box shows how much of the map the player sees at once."),
        // ---------- TILES ----------
        tut_step(WS_TILES, "tile_q0", "Tiles are 2 x 2 characters", "Click a corner, then click a character below to put it there."),
        tut_step(WS_TILES, "tile_chars", "Character picker", "These are the characters from your charset. Draw new ones on the Charset page."),
        tut_step(WS_TILES, "tile_attr0", "What a tile does", "Tick Solid for walls, Deadly for spikes, Collect for coins and gems, Exit for doors, Ladder, One-way platforms, Diggable dirt and Falls for boulders."),
        // ---------- CHARSET ----------
        tut_step(WS_CHARSET, "ch_grid", "The character set", "All 256 characters. Pick one to edit."),
        tut_step(WS_CHARSET, "ch_edit", "Draw pixels", "Left-click draws, right-click rubs out. Every tile using this character updates straight away."),
        tut_step(WS_CHARSET, "ch_mc", "Multicolour", "Switch to multicolour view to draw 4-colour characters with wide pixels."),
        // ---------- ENEMIES ----------
        tut_step(WS_ENEMIES, "en_preview", "Movement preview", "A quick picture of how this enemy moves and where it shoots."),
        tut_step(WS_ENEMIES, "en_move", "Movement", "Straight, sine wave, homing, bouncing, walking along platforms or crawling around walls."),
        tut_step(WS_ENEMIES, "en_fire", "Shooting", "Enemies can fire in a set direction or aim straight at the player.")
    ];
    tut_active = false;
    tut_list = [];
    tut_index = 0;
    tut_anim = 0;
    tut_target_rect = [];
    tut_card_rect = [0, 0, 0, 0];
    tut_allow_target = true;
}

/// _tab = -1 for the full tour, otherwise just that page
function tut_start(_tab)
{
    tut_list = [];
    var _tabs = ws_tabs();
    for (var i = 0; i < array_length(tut_steps); i++)
    {
        var _visible = false;
        for (var t = 0; t < array_length(_tabs); t++)
        {
            if (_tabs[t] == tut_steps[i].tab) { _visible = true; }
        }
        if (_tab < 0 && _visible) { array_push(tut_list, i); }
        if (_tab >= 0 && tut_steps[i].tab == _tab) { array_push(tut_list, i); }
    }
    if (array_length(tut_list) == 0) { return; }
    tut_index = 0;
    tut_active = true;
    tut_anim = 0;
    ui_popup_open = false;
    ui_focus = "";
    if (_tab >= 0)
    {
        ws_seen[_tab] = true;
        settings_save();
    }
}

function tut_draw(_gw, _gh)
{
    if (!tut_active) { return; }
    var _step = tut_steps[tut_list[tut_index]];
    if (_step.tab != ws)
    {
        ws = _step.tab;
        ui_popup_open = false;
        tut_target_rect = [];
        return;
    }
    tut_anim = lerp(tut_anim, 1, 0.15);
    var _a = tut_anim;
    var _r = undefined;
    if (_step.target != "") { _r = ds_map_find_value(ui_rects, _step.target); }
    var _dim = 0.62 * _a;
    if (is_undefined(_r))
    {
        tut_target_rect = [];
        draw_set_alpha(_dim);
        draw_rectangle_colour(0, 0, _gw, _gh, c_black, c_black, c_black, c_black, false);
        draw_set_alpha(1);
    }
    else
    {
        var _p = 8;
        var _x1 = _r[0] - _p;
        var _y1 = _r[1] - _p;
        var _x2 = _r[2] + _p;
        var _y2 = _r[3] + _p;
        tut_target_rect = [_r[0], _r[1], _r[2], _r[3]];
        draw_set_alpha(_dim);
        draw_set_colour(c_black);
        draw_rectangle(0, 0, _gw, _y1, false);
        draw_rectangle(0, _y2, _gw, _gh, false);
        draw_rectangle(0, _y1, _x1, _y2, false);
        draw_rectangle(_x2, _y1, _gw, _y2, false);
        draw_set_alpha(1);
        var _pulse = 2 + sin(current_time / 220) * 3;
        ui_rrect_line(_x1 - _pulse, _y1 - _pulse, _x2 + _pulse, _y2 + _pulse, 12, global.TH.warn, 0.9 * _a, 2);
        ui_glow(_x1, _y1, _x2, _y2, 10, global.TH.warn, _a);
    }

    // card
    var _cw = 420;
    draw_set_font(global.f_body);
    var _bh = ui_sh_ext(_step.body, _cw - 48);
    var _ch = 144 + _bh;
    var _cx = (_gw - _cw) / 2;
    var _cy = (_gh - _ch) / 2;
    if (!is_undefined(_r))
    {
        _cx = clamp((_r[0] + _r[2]) / 2 - _cw / 2, 16, _gw - _cw - 16);
        if (_r[3] + 40 + _ch < _gh - 44)
        {
            _cy = _r[3] + 40;
        }
        else
        {
            if (_r[1] - 40 - _ch > 66)
            {
                _cy = _r[1] - 40 - _ch;
            }
            else
            {
                _cy = clamp((_r[1] + _r[3]) / 2 - _ch / 2, 70, _gh - _ch - 44);
                if (_r[2] + 40 + _cw < _gw - 16) { _cx = _r[2] + 40; }
                else { _cx = max(16, _r[0] - 40 - _cw); }
            }
        }
        var _tx = clamp((_r[0] + _r[2]) / 2, _cx + 20, _cx + _cw - 20);
        var _ty = _cy;
        var _sx = (_r[0] + _r[2]) / 2;
        var _sy = _r[3] + 10;
        if (_cy < _r[1])
        {
            _ty = _cy + _ch;
            _sy = _r[1] - 10;
        }
        if (_cx >= _r[2] || _cx + _cw <= _r[0])
        {
            _sy = (_r[1] + _r[3]) / 2;
            _ty = _cy + _ch / 2;
            if (_cx >= _r[2]) { _sx = _r[2] + 10; _tx = _cx; }
            else { _sx = _r[0] - 10; _tx = _cx + _cw; }
        }
        ui_leader(_sx, _sy, _tx, _ty, global.TH.warn, _a);
    }
    _cy += (1 - _a) * 20;
    tut_card_rect = [_cx, _cy, _cx + _cw, _cy + _ch];
    ui_shadow(_cx, _cy, _cx + _cw, _cy + _ch, 16, 2);
    ui_rrect(_cx, _cy, _cx + _cw, _cy + _ch, 16, global.TH.btn_top, global.TH.panel_bot, _a);
    ui_rrect_line(_cx, _cy, _cx + _cw, _cy + _ch, 16, global.TH.warn, 0.8 * _a, 1);

    var _n = array_length(tut_list);
    ui_text(_cx + 24, _cy + 18, "STEP " + string(tut_index + 1) + " OF " + string(_n), global.TH.warn, fa_left, fa_top, global.f_small, _a);
    ui_rrect(_cx + 24, _cy + 38, _cx + _cw - 24, _cy + 42, 2, c_black, c_black, 0.3 * _a);
    ui_rrect(_cx + 24, _cy + 38, _cx + 24 + (_cw - 48) * ((tut_index + 1) / _n), _cy + 42, 2, global.TH.warn, global.TH.warn, _a);
    ui_text(_cx + 24, _cy + 52, _step.title, c_white, fa_left, fa_top, global.f_title, _a);
    ui_text_wrap(_cx + 24, _cy + 80, _step.body, global.TH.text_dim, _cw - 48, global.f_body, _a);

    ui_force_input = true;
    var _by = _cy + _ch - 44;
    var _last = (tut_index >= _n - 1);
    var _next_lab = "Next";
    if (_last) { _next_lab = "Finish"; }
    if (ui_button("tut_next", _cx + _cw - 124, _by, 100, 32, _next_lab, "Next step|Or press the right arrow key.", BTN_ACCENT) || keyboard_check_pressed(vk_right) || keyboard_check_pressed(vk_enter))
    {
        if (_last) { tut_active = false; }
        else
        {
            tut_index += 1;
            tut_anim = 0.3;
        }
    }
    if (tut_index > 0)
    {
        if (ui_button("tut_back", _cx + _cw - 232, _by, 100, 32, "Back", "Previous step|Or press the left arrow key.", BTN_GHOST) || keyboard_check_pressed(vk_left))
        {
            tut_index = max(0, tut_index - 1);
            tut_anim = 0.3;
        }
    }
    if (ui_button("tut_close", _cx + 24, _by, 100, 32, "Close", "Close tutorial|Or press Esc. Start it again with F1.", BTN_GHOST) || keyboard_check_pressed(vk_escape))
    {
        tut_active = false;
    }
    ui_force_input = false;
    if (!tut_active)
    {
        tut_target_rect = [];
        tut_card_rect = [0, 0, 0, 0];
    }
}
