/// C64 NO-CODE STUDIO - target machine profiles (picked in the top bar, saved in the project)
/// PAL and NTSC change the frame rate (timers, sound speed) and the SID clock.
/// The C64 Ultimate is a PAL C64 that Build and play sends the game to over the network.

#macro MACHINE_PAL 0
#macro MACHINE_NTSC 1
#macro MACHINE_ULTIMATE 2
#macro MACHINE_COUNT 3

function machine_defs_init()
{
    global.MACHINES = [
        {
            name : "Commodore 64 (PAL)", short_name : "C64 PAL", fps : 50, clock : SID_CLOCK_PAL,
            note : "PAL: 50 frames a second, 312 raster lines, SID clock 985 kHz. Europe, UK and Australia. Build and play opens the game in VICE."
        },
        {
            name : "Commodore 64 (NTSC)", short_name : "C64 NTSC", fps : 60, clock : SID_CLOCK_NTSC,
            note : "NTSC: 60 frames a second, 263 raster lines, SID clock 1.02 MHz. USA and Japan. Timers and sounds are worked out for 60 frames a second. Build and play opens the game in VICE (set VICE to NTSC too)."
        },
        {
            name : "C64 Ultimate", short_name : "C64 Ultimate", fps : 50, clock : SID_CLOCK_PAL,
            note : "The C64 Ultimate (or an Ultimate 64 / 1541 Ultimate II+) on your network, in PAL mode. Build and play sends the game straight to it and runs it - set its address on the Build page."
        }
    ];
}

function machine_cur()
{
    return global.MACHINES[clamp(proj.machine, 0, MACHINE_COUNT - 1)];
}

function machine_is_ntsc()
{
    return (proj.machine == MACHINE_NTSC);
}

function machine_short_names()
{
    var _n = [];
    for (var i = 0; i < MACHINE_COUNT; i++) { array_push(_n, global.MACHINES[i].name); }
    return _n;
}
