/// C64 NO-CODE STUDIO - compact two-pass 6502 assembler
/// Modes: 0 IMP, 1 ACC, 2 IMM, 3 ZP, 4 ZPX, 5 ZPY, 6 ABS, 7 ABX, 8 ABY, 9 IND, 10 IZX, 11 IZY, 12 REL
/// Directives: * = addr, name = expr, .byte, .fill n,v, .align n, .padto addr
/// Expressions: + - * / and < > prefixes, $hex, %bin, decimal, labels.

function asm6502_init()
{
    global.ASM_OPS = {
        BRK : [0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        ORA : [-1, -1, 9, 5, 21, -1, 13, 29, 25, -1, 1, 17, -1],
        ASL : [-1, 10, -1, 6, 22, -1, 14, 30, -1, -1, -1, -1, -1],
        PHP : [8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        BPL : [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 16],
        CLC : [24, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        JSR : [-1, -1, -1, -1, -1, -1, 32, -1, -1, -1, -1, -1, -1],
        AND : [-1, -1, 41, 37, 53, -1, 45, 61, 57, -1, 33, 49, -1],
        BIT : [-1, -1, -1, 36, -1, -1, 44, -1, -1, -1, -1, -1, -1],
        ROL : [-1, 42, -1, 38, 54, -1, 46, 62, -1, -1, -1, -1, -1],
        PLP : [40, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        BMI : [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 48],
        SEC : [56, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        RTI : [64, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        EOR : [-1, -1, 73, 69, 85, -1, 77, 93, 89, -1, 65, 81, -1],
        LSR : [-1, 74, -1, 70, 86, -1, 78, 94, -1, -1, -1, -1, -1],
        PHA : [72, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        JMP : [-1, -1, -1, -1, -1, -1, 76, -1, -1, 108, -1, -1, -1],
        BVC : [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 80],
        CLI : [88, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        RTS : [96, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        ADC : [-1, -1, 105, 101, 117, -1, 109, 125, 121, -1, 97, 113, -1],
        ROR : [-1, 106, -1, 102, 118, -1, 110, 126, -1, -1, -1, -1, -1],
        PLA : [104, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        BVS : [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 112],
        SEI : [120, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        STA : [-1, -1, -1, 133, 149, -1, 141, 157, 153, -1, 129, 145, -1],
        STY : [-1, -1, -1, 132, 148, -1, 140, -1, -1, -1, -1, -1, -1],
        STX : [-1, -1, -1, 134, -1, 150, 142, -1, -1, -1, -1, -1, -1],
        DEY : [136, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        TXA : [138, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        BCC : [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 144],
        TYA : [152, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        TXS : [154, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        LDY : [-1, -1, 160, 164, 180, -1, 172, 188, -1, -1, -1, -1, -1],
        LDA : [-1, -1, 169, 165, 181, -1, 173, 189, 185, -1, 161, 177, -1],
        LDX : [-1, -1, 162, 166, -1, 182, 174, -1, 190, -1, -1, -1, -1],
        TAY : [168, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        TAX : [170, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        BCS : [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 176],
        CLV : [184, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        TSX : [186, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        CPY : [-1, -1, 192, 196, -1, -1, 204, -1, -1, -1, -1, -1, -1],
        CMP : [-1, -1, 201, 197, 213, -1, 205, 221, 217, -1, 193, 209, -1],
        DEC : [-1, -1, -1, 198, 214, -1, 206, 222, -1, -1, -1, -1, -1],
        INY : [200, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        DEX : [202, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        BNE : [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 208],
        CLD : [216, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        CPX : [-1, -1, 224, 228, -1, -1, 236, -1, -1, -1, -1, -1, -1],
        SBC : [-1, -1, 233, 229, 245, -1, 237, 253, 249, -1, 225, 241, -1],
        INC : [-1, -1, -1, 230, 246, -1, 238, 254, -1, -1, -1, -1, -1],
        INX : [232, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        NOP : [234, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        BEQ : [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 240],
        SED : [248, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]

    };
}

function asm_is_ident_char(_ch, _first)
{
    var _o = ord(_ch);
    if (_o >= 65 && _o <= 90) { return true; }
    if (_o >= 97 && _o <= 122) { return true; }
    if (_ch == "_") { return true; }
    if (!_first)
    {
        if (_o >= 48 && _o <= 57) { return true; }
    }
    return false;
}

function asm_is_ident(_s)
{
    var _n = string_length(_s);
    if (_n == 0) { return false; }
    for (var i = 1; i <= _n; i++)
    {
        if (!asm_is_ident_char(string_char_at(_s, i), i == 1)) { return false; }
    }
    return true;
}

function asm_tokens(_e)
{
    var _t = [];
    var _n = string_length(_e);
    var i = 1;
    while (i <= _n)
    {
        var _ch = string_char_at(_e, i);
        if (_ch == " " || _ch == "\t")
        {
            i += 1;
            continue;
        }
        var j = i + 1;
        if (_ch == "$")
        {
            while (j <= _n && string_pos(string_char_at(_e, j), "0123456789abcdefABCDEF") > 0) { j += 1; }
            array_push(_t, string_copy(_e, i, j - i));
            i = j;
            continue;
        }
        if (_ch == "%")
        {
            while (j <= _n && string_pos(string_char_at(_e, j), "01") > 0) { j += 1; }
            array_push(_t, string_copy(_e, i, j - i));
            i = j;
            continue;
        }
        if (string_pos(_ch, "0123456789") > 0)
        {
            while (j <= _n && string_pos(string_char_at(_e, j), "0123456789") > 0) { j += 1; }
            array_push(_t, string_copy(_e, i, j - i));
            i = j;
            continue;
        }
        if (asm_is_ident_char(_ch, true))
        {
            while (j <= _n && asm_is_ident_char(string_char_at(_e, j), false)) { j += 1; }
            array_push(_t, string_copy(_e, i, j - i));
            i = j;
            continue;
        }
        array_push(_t, _ch);
        i += 1;
    }
    return _t;
}

function asm_parse_num(_tok)
{
    var _first = string_char_at(_tok, 1);
    var _v = 0;
    if (_first == "$")
    {
        for (var i = 2; i <= string_length(_tok); i++)
        {
            _v = _v * 16 + (string_pos(string_upper(string_char_at(_tok, i)), "0123456789ABCDEF") - 1);
        }
        return _v;
    }
    if (_first == "%")
    {
        for (var k = 2; k <= string_length(_tok); k++)
        {
            _v = _v * 2 + (string_pos(string_char_at(_tok, k), "01") - 1);
        }
        return _v;
    }
    return real(_tok);
}

/// Evaluates an expression. _st = { toks, i, known, labels, pass1 }
function asm_eval(_expr, _labels, _pass1)
{
    var _st = { toks : asm_tokens(_expr), i : 0, known : true, labels : _labels, pass1 : _pass1 };
    if (array_length(_st.toks) == 0) { throw ("Missing value"); }
    var _v = asm_ev_add(_st);
    if (_st.i < array_length(_st.toks)) { throw ("Unexpected '" + _st.toks[_st.i] + "'"); }
    return { value : _v, known : _st.known };
}

function asm_ev_add(_st)
{
    var _v = asm_ev_mul(_st);
    while (_st.i < array_length(_st.toks))
    {
        var _o = _st.toks[_st.i];
        if (_o != "+" && _o != "-") { break; }
        _st.i += 1;
        var _w = asm_ev_mul(_st);
        if (_o == "+") { _v += _w; }
        else { _v -= _w; }
    }
    return _v;
}

function asm_ev_mul(_st)
{
    var _v = asm_ev_unary(_st);
    while (_st.i < array_length(_st.toks))
    {
        var _o = _st.toks[_st.i];
        if (_o != "*" && _o != "/") { break; }
        _st.i += 1;
        var _w = asm_ev_unary(_st);
        if (_o == "*") { _v *= _w; }
        else
        {
            if (_w != 0) { _v = _v div _w; }
            else { _v = 0; }
        }
    }
    return _v;
}

function asm_ev_unary(_st)
{
    if (_st.i >= array_length(_st.toks)) { throw ("Missing value"); }
    var _t = _st.toks[_st.i];
    _st.i += 1;
    if (_t == "<") { return asm_ev_unary(_st) & 255; }
    if (_t == ">") { return (asm_ev_unary(_st) >> 8) & 255; }
    if (_t == "-") { return -asm_ev_unary(_st); }
    var _f = string_char_at(_t, 1);
    if (_f == "$" || _f == "%" || string_pos(_f, "0123456789") > 0)
    {
        return asm_parse_num(_t);
    }
    if (asm_is_ident(_t))
    {
        var _lv = _st.labels[$ _t];
        if (!is_undefined(_lv)) { return _lv; }
        _st.known = false;
        if (!_st.pass1) { throw ("Unknown label '" + _t + "'"); }
        return 0;
    }
    throw ("Unexpected '" + _t + "'");
}

/// Assembles source text. Returns { ok, err, org, bytes, labels, line }
function asm6502_assemble(_src)
{
    var _lines = string_split(_src, "\n");
    var _labels = {};
    var _sizes = array_create(array_length(_lines), -1);
    var _res = { ok : false, err : "", org : 0, bytes : [], labels : _labels, line : 0 };
    var _ln = 0;
    try
    {
        for (var _pass = 1; _pass <= 2; _pass++)
        {
            var _p1 = (_pass == 1);
            var _pc = 0;
            var _org = -1;
            var _out = [];
            for (_ln = 0; _ln < array_length(_lines); _ln++)
            {
                var _l = _lines[_ln];
                var _sc = string_pos(";", _l);
                if (_sc > 0) { _l = string_copy(_l, 1, _sc - 1); }
                _l = string_trim(_l);
                if (_l == "") { continue; }

                // label:
                var _colon = string_pos(":", _l);
                if (_colon > 1)
                {
                    var _lab = string_copy(_l, 1, _colon - 1);
                    if (asm_is_ident(_lab))
                    {
                        if (_p1)
                        {
                            if (!is_undefined(_labels[$ _lab])) { throw ("Label '" + _lab + "' defined twice"); }
                            _labels[$ _lab] = _pc;
                        }
                        _l = string_trim(string_delete(_l, 1, _colon));
                        if (_l == "") { continue; }
                    }
                }

                // equate / origin
                var _eq = string_pos("=", _l);
                if (_eq > 1)
                {
                    var _name = string_trim(string_copy(_l, 1, _eq - 1));
                    var _rhs = string_trim(string_delete(_l, 1, _eq));
                    if (_name == "*" || asm_is_ident(_name))
                    {
                        var _ev = asm_eval(_rhs, _labels, _p1);
                        if (_name == "*")
                        {
                            if (_org < 0)
                            {
                                _org = _ev.value;
                            }
                            else
                            {
                                for (var z = _pc; z < _ev.value; z++) { array_push(_out, 0); }
                            }
                            _pc = _ev.value;
                        }
                        else
                        {
                            _labels[$ _name] = _ev.value;
                        }
                        continue;
                    }
                }

                var _sp = string_pos(" ", _l);
                var _mn = _l;
                var _opd = "";
                if (_sp > 0)
                {
                    _mn = string_copy(_l, 1, _sp - 1);
                    _opd = string_trim(string_delete(_l, 1, _sp));
                }
                _mn = string_upper(_mn);

                if (_mn == ".BYTE")
                {
                    var _items = string_split(_opd, ",");
                    for (var b = 0; b < array_length(_items); b++)
                    {
                        var _bv = asm_eval(_items[b], _labels, _p1);
                        array_push(_out, _bv.value & 255);
                        _pc += 1;
                    }
                    continue;
                }
                if (_mn == ".FILL")
                {
                    var _fa = string_split(_opd, ",");
                    var _cnt = asm_eval(_fa[0], _labels, false).value;
                    var _fv = 0;
                    if (array_length(_fa) > 1) { _fv = asm_eval(_fa[1], _labels, false).value & 255; }
                    for (var f = 0; f < _cnt; f++) { array_push(_out, _fv); }
                    _pc += _cnt;
                    continue;
                }
                if (_mn == ".ALIGN")
                {
                    var _al = asm_eval(_opd, _labels, false).value;
                    while ((_pc mod _al) != 0)
                    {
                        array_push(_out, 0);
                        _pc += 1;
                    }
                    continue;
                }
                if (_mn == ".PADTO")
                {
                    var _pt = asm_eval(_opd, _labels, false).value;
                    while (_pc < _pt)
                    {
                        array_push(_out, 0);
                        _pc += 1;
                    }
                    continue;
                }

                var _tab = global.ASM_OPS[$ _mn];
                if (is_undefined(_tab)) { throw ("Unknown instruction '" + _mn + "'"); }
                var _u = string_upper(_opd);
                var _ol = string_length(_opd);

                if (_opd == "" || _u == "A")
                {
                    var _m0 = 0;
                    if (_tab[0] < 0) { _m0 = 1; }
                    if (_tab[_m0] < 0) { throw ("'" + _mn + "' needs an operand"); }
                    array_push(_out, _tab[_m0]);
                    _pc += 1;
                    continue;
                }
                if (string_char_at(_opd, 1) == "#")
                {
                    if (_tab[2] < 0) { throw ("'" + _mn + "' cannot use #immediate"); }
                    var _iv = asm_eval(string_delete(_opd, 1, 1), _labels, _p1);
                    array_push(_out, _tab[2], _iv.value & 255);
                    _pc += 2;
                    continue;
                }
                if (_tab[12] >= 0)
                {
                    var _rv = asm_eval(_opd, _labels, _p1);
                    var _d = _rv.value - (_pc + 2);
                    if (!_p1 && (_d < -128 || _d > 127)) { throw ("Branch too far (" + string(_d) + " bytes)"); }
                    array_push(_out, _tab[12], _d & 255);
                    _pc += 2;
                    continue;
                }
                if (string_char_at(_opd, 1) == "(" && string_copy(_u, _ol - 2, 3) == ",X)")
                {
                    var _xv = asm_eval(string_copy(_opd, 2, _ol - 4), _labels, _p1);
                    array_push(_out, _tab[10], _xv.value & 255);
                    _pc += 2;
                    continue;
                }
                if (string_char_at(_opd, 1) == "(" && string_copy(_u, _ol - 2, 3) == "),Y")
                {
                    var _yv = asm_eval(string_copy(_opd, 2, _ol - 4), _labels, _p1);
                    array_push(_out, _tab[11], _yv.value & 255);
                    _pc += 2;
                    continue;
                }
                if (string_char_at(_opd, 1) == "(")
                {
                    var _nv = asm_eval(string_copy(_opd, 2, _ol - 2), _labels, _p1);
                    array_push(_out, _tab[9], _nv.value & 255, (_nv.value >> 8) & 255);
                    _pc += 3;
                    continue;
                }
                var _idx = 0;
                var _base = _opd;
                if (string_copy(_u, _ol - 1, 2) == ",X") { _idx = 1; _base = string_copy(_opd, 1, _ol - 2); }
                if (string_copy(_u, _ol - 1, 2) == ",Y") { _idx = 2; _base = string_copy(_opd, 1, _ol - 2); }
                var _av = asm_eval(_base, _labels, _p1);
                var _zpmode = 3 + _idx;
                var _absmode = 6 + _idx;
                if (_p1)
                {
                    var _usezp = 0;
                    if (_av.known && _av.value >= 0 && _av.value < 256 && _tab[_zpmode] >= 0) { _usezp = 1; }
                    _sizes[_ln] = _usezp;
                }
                if (_sizes[_ln] == 1)
                {
                    array_push(_out, _tab[_zpmode], _av.value & 255);
                    _pc += 2;
                }
                else
                {
                    if (_tab[_absmode] < 0) { throw ("'" + _mn + "' cannot use that addressing mode"); }
                    array_push(_out, _tab[_absmode], _av.value & 255, (_av.value >> 8) & 255);
                    _pc += 3;
                }
            }
            if (_pass == 2)
            {
                _res.ok = true;
                _res.org = _org;
                _res.bytes = _out;
            }
        }
    }
    catch (_e)
    {
        _res.ok = false;
        var _msg = _e;
        if (is_struct(_e)) { _msg = _e.message; }
        _res.err = "Line " + string(_ln + 1) + ": " + string(_msg);
        _res.line = _ln + 1;
    }
    return _res;
}
