; =====================================================================
;  C64 NO-CODE STUDIO - MAP GAME ENGINE  (stock C64, PAL)
;  Scrolling: none / horizontal / vertical / 8-way follow / flip-screen
;  Kinds: shoot-em-up, platformer, cave digger, top-down
;  $01=$35 (BASIC+KERNAL out), own IRQ at $FFFE, VIC bank 3:
;  screen $C000, sprites $E000 (ptr 128+n), charset $F000
;  Config equates + data tables + shift routines are generated.
; =====================================================================
SCR    = $c000
COLR   = $d800
SPRMEM = $e000
CHRMEM = $f000
MAPBUF = $8000

zp_p   = $02
zp_c   = $04
zp_m   = $06
zp_s   = $08
zp_d   = $0a
t0 = $10
t1 = $11
t2 = $12
t3 = $13
t4 = $14
t5 = $15
t6 = $16
t7 = $17
frame_flag = $18
irq_stage  = $19

A_SOLID   = 1
A_DEADLY  = 2
A_COLLECT = 4
A_EXIT    = 8
A_LADDER  = 16
A_ONEWAY  = 32
A_DIG     = 64
A_FALLS   = 128

K_NONE = 0
K_PLAYER = 1
K_PBUL = 2
K_ENEMY = 3
K_EBUL = 4
K_DYING = 5

WIN_PXH   = WROWS*8

; ---------------------------------------------------------------------
start:
    sei
    cld
    ldx #$ff
    txs
    lda #$35
    sta $01
    lda #$7f
    sta $dc0d
    sta $dd0d
    lda $dc0d
    lda $dd0d
    lda #<nmi
    sta $fffa
    lda #>nmi
    sta $fffb
    ; IRQ vector -> JMP in zero page so $FFFF (the VIC ghost byte in bank 3) is $00:
    ; idle lines above a vertically scrolled window then stay blank
    lda #$4c
    sta $f0
    lda #<irq
    sta $f1
    lda #>irq
    sta $f2
    lda #$f0
    sta $fffe
    lda #$00
    sta $ffff
    lda #0
    sta $d015
    sta $d01a
    lda $dd02
    ora #3
    sta $dd02
    lda $dd00
    and #$fc
    sta $dd00
    jsr copy_assets
    lda #$0c
    sta $d018
    lda #BORDER
    sta $d020
    lda #BG
    sta $d021
    lda #MC1
    sta $d022
    lda #MC2
    sta $d023
    lda #SMC1
    sta $d025
    lda #SMC2
    sta $d026
    lda #0
    sta $d017
    sta $d01d
    sta $d01b
    jsr sfx_init
    lda #0
    sta irq_stage
    sta frame_flag
    lda #$1b
    sta $d011
    lda #IRQ1_LINE
    sta $d012
    lda #1
    sta $d01a
    lda #$ff
    sta $d019
    cli

new_game:
    ldx #$ff
    txs
    cli
    lda #0
    sta score
    sta score+1
    sta score+2
    sta level
    lda #LIVES
    sta lives

level_start:
    jsr level_init
    lda level
    jsr mus_level           ; this level's song (one already playing carries on)

main:
    lda frame_flag
    beq main
    lda #0
    sta frame_flag
    jsr frame_vic
    lda pend
    sta coarse
    jsr scroll_apply
    inc fcount
    lda $dc00
    eor #$ff
    and #$1f
    sta joy
    jsr game_logic
    jsr sfx_update
    lda game_state
    beq main
    cmp #1
    beq dead
    cmp #2
    beq level_done
    jmp main

dead:
    lda #SFX_DIE
    jsr play_sfx
    jsr wait_frames40
    lda lives
    beq game_over
    dec lives
    lda lives
    beq game_over
    jmp level_start
game_over:
    jsr mus_stop
    ldx #<txt_over
    ldy #>txt_over
    jsr message
    jmp new_game
level_done:
    lda #SFX_EXIT
    jsr play_sfx
    jsr wait_frames40
    inc level
    lda level
    cmp #NLEVELS
    bcc level_start
    jsr mus_stop
    ldx #<txt_win
    ldy #>txt_win
    jsr message
    jmp new_game

; ---------------------------------------------------------------------
; IRQ1 fires on the last raster line of the row above the window (48+WTOP*8-1).
; $D011 is written first, inside that line, so the window's first badline is
; always at 48+WTOP*8+YSCROLL: smooth vertical scrolling with no early badline.
irq:
    pha
    lda irq_stage
    beq irq_s0
    .if SCROLL_V
    cmp #1
    beq irq_s1
    cmp #2
    beq irq_s2
    .endif
    jmp irq_b
irq_s0:
    ; YSCROLL 7 matches line 63 itself (63 & 7 = 7): writing it there would start a
    ; badline mid-line. For that one value wait for the next line, then write.
    lda disp_d011
    and #7
    cmp #7
    bne irq_w
irq_wt:
    lda $d012
    cmp #IRQ1_LINE+1
    bne irq_wt
irq_w:
    lda disp_d011
    .if SCROLL_V
    ; window starts masked (ECM+BMM = invalid mode, shows black) so the partly
    ; scrolled-in top row never shows: the visible top edge stays fixed
    ora #$60
    .endif
    sta $d011
    lda disp_d016
    sta $d016
    .if SCROLL_V
    lda #1
    sta irq_stage
    lda #MASK_TOP-1
    .else
    lda #3
    sta irq_stage
    lda #IRQ2_LINE
    .endif
    sta $d012
    lda #$ff
    sta $d019
    pla
    rti
    .if SCROLL_V
; unmask at the very start of line MASK_TOP (the write lands in the left border)
irq_s1:
    txa
    pha
    ldx disp_d011
    lda #MASK_TOP
irq_p1:
    cmp $d012
    bne irq_p1
    stx $d011
    lda #2
    sta irq_stage
    lda #MASK_BOT-1
    sta $d012
    lda #$ff
    sta $d019
    pla
    tax
    pla
    rti
; mask again from line MASK_BOT so the partly scrolled-in bottom row never shows
irq_s2:
    txa
    pha
    lda disp_d011
    ora #$60
    tax
    lda #MASK_BOT
irq_p2:
    cmp $d012
    bne irq_p2
    stx $d011
    lda #3
    sta irq_stage
    lda #IRQ2_LINE
    sta $d012
    lda #$ff
    sta $d019
    pla
    tax
    pla
    rti
    .endif
irq_b:
    lda #$1b
    sta $d011
    lda #HUD_D016
    sta $d016
    lda #0
    sta irq_stage
    lda #IRQ1_LINE
    sta $d012
    lda #1
    sta frame_flag
    lda #$ff
    sta $d019
    pla
nmi:
    rti

wait_frames40:
    ldx #40
wf1:
    lda frame_flag
    beq wf1
    lda #0
    sta frame_flag
    txa
    pha
    jsr sfx_update
    pla
    tax
    dex
    bne wf1
    rts

; message in middle of the window, wait for fire
message:
    stx zp_s
    sty zp_s+1
    lda #0
    sta $d015
    sta $d404
    ldy #0
msg1:
    lda (zp_s),y
    cmp #$ff
    beq msg2
    sta SCR+(WTOP+WROWS/2)*40,y
    lda #1
    sta COLR+(WTOP+WROWS/2)*40,y
    iny
    bne msg1
msg2:
    lda $dc00
    and #16
    beq msg2
msg3:
    lda $dc00
    and #16
    bne msg3
msg4:
    lda $dc00
    and #16
    beq msg4
    rts

; ---------------------------------------------------------------------
copy_assets:
    lda #<spr_src
    sta zp_s
    lda #>spr_src
    sta zp_s+1
    lda #<SPRMEM
    sta zp_d
    lda #>SPRMEM
    sta zp_d+1
    ldx #SPR_PAGES
    jsr copy_pages
    lda #<chr_src
    sta zp_s
    lda #>chr_src
    sta zp_s+1
    lda #<CHRMEM
    sta zp_d
    lda #>CHRMEM
    sta zp_d+1
    ldx #8
copy_pages:
    ldy #0
cp1:
    lda (zp_s),y
    sta (zp_d),y
    iny
    bne cp1
    inc zp_s+1
    inc zp_d+1
    dex
    bne cp1
    rts

; ---------------------------------------------------------------------
level_init:
    sei
    lda #0
    sta $d015
    sta game_state
    sta need_got
    sta pend
    sta cave_row
    sta fcount
    ldx level
    lda lv_w,x
    sta map_w
    lda lv_h,x
    sta map_h
    lda lv_need,x
    sta need
    lda lv_nsp,x
    sta nsp
    lda lv_sp_lo,x
    sta sp_ptr
    lda lv_sp_hi,x
    sta sp_ptr+1
    lda lv_map_lo,x
    sta zp_s
    lda lv_map_hi,x
    sta zp_s+1
    lda #<MAPBUF
    sta zp_d
    lda #>MAPBUF
    sta zp_d+1
    lda lv_size_hi,x
    sta t0
    lda lv_size_lo,x
    sta t1
    ldy #0
li_cp:
    lda t0
    ora t1
    beq li_cpd
    lda (zp_s),y
    sta (zp_d),y
    inc zp_s
    bne li_c1
    inc zp_s+1
li_c1:
    inc zp_d
    bne li_c2
    inc zp_d+1
li_c2:
    lda t1
    bne li_c3
    dec t0
li_c3:
    dec t1
    jmp li_cp
li_cpd:
    ; map row table
    lda #<MAPBUF
    sta t0
    lda #>MAPBUF
    sta t1
    ldx #0
li_rt:
    lda t0
    sta maprow_lo,x
    lda t1
    sta maprow_hi,x
    clc
    lda t0
    adc map_w
    sta t0
    bcc li_rt2
    inc t1
li_rt2:
    inx
    cpx map_h
    bne li_rt
    ; spawner state
    ldx #0
    lda #0
li_sp:
    sta sp_state,x
    sta sp_left,x
    sta sp_timer,x
    inx
    cpx #64
    bne li_sp
    lda #0
    sta sp_scan
    ; entities clear
    ldx #7
li_e:
    lda #0
    sta e_kind,x
    dex
    bpl li_e
    ; player
    ldx level
    lda lv_px,x
    sta t0
    lda lv_py,x
    sta t1
    lda #0
    sta e_xhi
    sta e_yhi
    lda t0
    asl
    rol e_xhi
    asl
    rol e_xhi
    asl
    rol e_xhi
    asl
    rol e_xhi
    sta e_xlo
    lda t1
    asl
    rol e_yhi
    asl
    rol e_yhi
    asl
    rol e_yhi
    asl
    rol e_yhi
    sta e_ylo
    .if KIND_SHMUP+KIND_TOP+KIND_PLAT
    sec
    lda e_ylo
    sbc #5
    sta e_ylo
    bcs li_p1
    dec e_yhi
li_p1:
    .endif
    lda #K_PLAYER
    sta e_kind
    lda #PSPR
    sta e_spr
    lda #PCOL
    sta e_col
    lda #FIREDIR
    sta e_dir
    lda #0
    sta e_vy
    sta e_t
    sta fire_cd
    sta grid_mv
    sta end_t
    ; view
    lda #0
    sta view_x
    sta view_x+1
    sta view_y
    sta view_y+1
    jsr view_max_x
    jsr view_max_y
    .if FOLLOW+FLIP
    jsr view_center
    .endif
    .if AUTO_V
    ; vertical shooter starts at the bottom of the map
    jsr view_max_y
    lda vmax_y
    sta view_y
    lda vmax_y+1
    sta view_y+1
    ; put player near window bottom
    clc
    lda view_y
    adc #WIN_PXH-40
    sta e_ylo
    lda view_y+1
    adc #0
    sta e_yhi
    .endif
    jsr view_split
    jsr hud_draw_static
    jsr clear_window_colour
    jsr draw_window
    jsr compute_disp
    lda new_d016
    sta disp_d016
    lda new_d011
    sta disp_d011
    jsr place_sprites
    cli
    rts

; ---------------------------------------------------------------------
; view helpers
view_max_x:
    ; vmax_x = (map_w*2 - 40) * 8
    lda map_w
    sec
    sbc #20
    bcs vmx1
    lda #0
vmx1:
    sta t0
    lda #0
    sta vmax_x+1
    lda t0
    asl
    rol vmax_x+1
    asl
    rol vmax_x+1
    asl
    rol vmax_x+1
    asl
    rol vmax_x+1
    sta vmax_x
    rts

view_max_y:
    ; vmax_y = map_h*16 - WROWS*8
    lda #0
    sta vmax_y+1
    lda map_h
    asl
    rol vmax_y+1
    asl
    rol vmax_y+1
    asl
    rol vmax_y+1
    asl
    rol vmax_y+1
    sec
    sbc #<WIN_PXH
    sta vmax_y
    lda vmax_y+1
    sbc #>WIN_PXH
    sta vmax_y+1
    bcs vmy1
    lda #0
    sta vmax_y
    sta vmax_y+1
vmy1:
    rts

; centre view on player, clamped
view_center:
    jsr view_max_x
    jsr view_max_y
    .if SCROLL_H+0+FLIP
    sec
    lda e_xlo
    sbc #148
    sta view_x
    lda e_xhi
    sbc #0
    sta view_x+1
    bcs vc1
    lda #0
    sta view_x
    sta view_x+1
vc1:
    .if FLIP
    lda view_x
    and #$f8
    sta view_x
    .endif
    jsr clamp_vx
    .endif
    .if SCROLL_V+0+FLIP
    sec
    lda e_ylo
    sbc #<(WIN_PXH/2)
    sta view_y
    lda e_yhi
    sbc #>(WIN_PXH/2)
    sta view_y+1
    bcs vc2
    lda #0
    sta view_y
    sta view_y+1
vc2:
    .if FLIP
    lda view_y
    and #$f8
    sta view_y
    .endif
    jsr clamp_vy
    .endif
    rts

clamp_vx:
    lda view_x+1
    cmp vmax_x+1
    bcc cvx1
    bne cvx2
    lda view_x
    cmp vmax_x
    bcc cvx1
cvx2:
    lda vmax_x
    sta view_x
    lda vmax_x+1
    sta view_x+1
cvx1:
    rts

clamp_vy:
    lda view_y+1
    cmp vmax_y+1
    bcc cvy1
    bne cvy2
    lda view_y
    cmp vmax_y
    bcc cvy1
cvy2:
    lda vmax_y
    sta view_y
    lda vmax_y+1
    sta view_y+1
cvy1:
    rts

; split view_x/y into tile, sub-char and fine parts
view_split:
    lda view_x+1
    sta t0
    lda view_x
    and #7
    sta fine_x
    lda view_x
    lsr t0
    ror
    lsr t0
    ror
    lsr t0
    ror
    sta t1
    and #1
    sta sub_x
    lda t0
    lsr
    lda t1
    ror
    sta view_tx
    lda view_y+1
    sta t0
    lda view_y
    and #7
    sta fine_y
    lda view_y
    lsr t0
    ror
    lsr t0
    ror
    lsr t0
    ror
    sta t1
    and #1
    sta sub_y
    lda t0
    lsr
    lda t1
    ror
    sta view_ty
    rts

compute_disp:
    lda #COLS_D016
    .if SCROLL_H+0
    sta t0
    lda #7
    sec
    sbc fine_x
    ora t0
    .endif
    sta new_d016
    lda #$1b
    .if SCROLL_V+0
    ; The row above the window only finishes (RC=7, VCBASE advances) on its 8th line.
    ; A window badline earlier than that re-shows that blank row, so the window's real
    ; top is 3 lines below the separator for YSCROLL 3..7 and 8 further for 0..2:
    ; YSCROLL = (10 - fine) & 7 moves the window down exactly one line per step.
    lda #10
    sec
    sbc fine_y
    and #7
    ora #$18
    .endif
    sta new_d011
    rts

; ---------------------------------------------------------------------
; called right after the window has been drawn (IRQ2)
scroll_apply:
    ; the new fine scroll must be in place before IRQ1 of the coming frame;
    ; the coarse shift below races the beam top-down and finishes ahead of it
    lda new_d016
    sta disp_d016
    lda new_d011
    sta disp_d011
    lda pend
    beq sa_done
    .if FLIP
    jsr draw_window
    .else
    lsr pend
    bcc sa1
    jsr shift_left
    lda #39
    jsr draw_col
sa1:
    lsr pend
    bcc sa2
    jsr shift_right
    lda #0
    jsr draw_col
sa2:
    lsr pend
    bcc sa3
    jsr shift_up
    lda #WROWS-1
    jsr draw_row
sa3:
    lsr pend
    bcc sa_done
    jsr shift_down
    lda #0
    jsr draw_row
    .endif
sa_done:
    lda #0
    sta pend
    rts

; move view by (dvx,dvy) signed bytes (|d|<=7), set pend flags
; pend bits: 1 left(view right) 2 right(view left) 4 up(view down) 8 down(view up)
view_move:
    lda view_x
    and #$f8
    sta t2
    lda view_x+1
    sta t3
    lda view_y
    and #$f8
    sta t4
    lda view_y+1
    sta t5
    ; x
    lda dvx
    beq vm_y
    bmi vm_xn
    clc
    adc view_x
    sta view_x
    bcc vm_xc
    inc view_x+1
    jmp vm_xc
vm_xn:
    clc
    adc view_x
    sta view_x
    bcs vm_xc
    dec view_x+1
vm_xc:
    lda view_x+1
    bpl vm_xok0
    lda #0
    sta view_x
    sta view_x+1
vm_xok0:
    jsr clamp_vx
vm_xok:
    lda view_x
    and #$f8
    cmp t2
    bne vm_xch
    lda view_x+1
    cmp t3
    beq vm_y
vm_xch:
    lda dvx
    bmi vm_xl
    lda pend
    ora #1
    sta pend
    jmp vm_y
vm_xl:
    lda pend
    ora #2
    sta pend
vm_y:
    lda dvy
    bne rx_1
    jmp vm_done
rx_1:
    ; only one coarse axis per frame
    lda pend
    beq vm_y0
    lda view_y
    and #7
    sta t6
    lda dvy
    bmi vm_yneg
    clc
    adc t6
    cmp #8
    bcc vm_y0
    lda #7
    sec
    sbc t6
    sta dvy
    jmp vm_y0
vm_yneg:
    clc
    adc t6
    bpl vm_y0
    lda #0
    sec
    sbc t6
    sta dvy
vm_y0:
    lda dvy
    beq vm_done
    bmi vm_yn
    clc
    adc view_y
    sta view_y
    bcc vm_yc
    inc view_y+1
    jmp vm_yc
vm_yn:
    clc
    adc view_y
    sta view_y
    bcs vm_yc
    dec view_y+1
vm_yc:
    lda view_y+1
    bpl vm_yok0
    lda #0
    sta view_y
    sta view_y+1
vm_yok0:
    jsr clamp_vy
vm_yok:
    lda view_y
    and #$f8
    cmp t4
    bne vm_ych
    lda view_y+1
    cmp t5
    beq vm_done
vm_ych:
    lda dvy
    bmi vm_yu
    lda pend
    ora #4
    sta pend
    jmp vm_done
vm_yu:
    lda pend
    ora #8
    sta pend
vm_done:
    jsr view_split
    jsr compute_disp
    rts

; ---------------------------------------------------------------------
; drawing
clear_window_colour:
    ldx #0
cwc:
    lda #WINCOL
    sta COLR,x
    sta COLR+250,x
    sta COLR+500,x
    sta COLR+750,x
    inx
    cpx #250
    bne cwc
    jmp hud_draw_static_col

draw_window:
    lda #0
dw1:
    pha
    jsr draw_row
    pla
    clc
    adc #1
    cmp #WROWS
    bne dw1
    rts

; A = window row (0..WROWS-1)
draw_row:
    sta t0
    clc
    adc #WTOP
    tax
    lda scr_lo,x
    sta zp_p
    sta zp_c
    lda scr_hi,x
    sta zp_p+1
    clc
    adc #>(COLR-SCR)
    sta zp_c+1
    ; char row = sub_y + r
    lda sub_y
    clc
    adc t0
    sta t1
    lsr
    clc
    adc view_ty
    tax
    lda maprow_lo,x
    clc
    adc view_tx
    sta zp_m
    lda maprow_hi,x
    adc #0
    sta zp_m+1
    lda t1
    and #1
    beq dr_top
    lda #<tc2
    sta dr_l+1
    lda #>tc2
    sta dr_l+2
    lda #<tc3
    sta dr_r+1
    lda #>tc3
    sta dr_r+2
    jmp dr_go
dr_top:
    lda #<tc0
    sta dr_l+1
    lda #>tc0
    sta dr_l+2
    lda #<tc1
    sta dr_r+1
    lda #>tc1
    sta dr_r+2
dr_go:
    lda sub_x
    sta t2
    lda #0
    sta t3
    ldy #0
dr_loop:
    sty t4
    ldy t3
    lda (zp_m),y
    tax
    ldy t4
    lda t2
    bne dr_rgt
dr_l:
    lda tc0,x
    sta (zp_p),y
    .if FULLCOL
    lda tcol,x
    sta (zp_c),y
    .endif
    lda #1
    sta t2
    jmp dr_nx
dr_rgt:
dr_r:
    lda tc1,x
    sta (zp_p),y
    .if FULLCOL
    lda tcol,x
    sta (zp_c),y
    .endif
    lda #0
    sta t2
    inc t3
dr_nx:
    iny
    cpy #40
    bne dr_loop
    rts

; A = screen column (0..39)
draw_col:
    sta t0
    clc
    adc sub_x
    sta t1
    lsr
    clc
    adc view_tx
    sta t3
    lda t1
    and #1
    sta t2
    lda sub_y
    sta t5
    lda view_ty
    sta t6
    lda #0
    sta t4
dc_loop:
    lda t4
    clc
    adc #WTOP
    tax
    lda scr_lo,x
    sta zp_p
    sta zp_c
    lda scr_hi,x
    sta zp_p+1
    clc
    adc #>(COLR-SCR)
    sta zp_c+1
    ldx t6
    lda maprow_lo,x
    sta zp_m
    lda maprow_hi,x
    sta zp_m+1
    ldy t3
    lda (zp_m),y
    tax
    ldy t0
    lda t5
    asl
    ora t2
    beq dc_0
    cmp #1
    beq dc_1
    cmp #2
    beq dc_2
    lda tc3,x
    jmp dc_w
dc_0:
    lda tc0,x
    jmp dc_w
dc_1:
    lda tc1,x
    jmp dc_w
dc_2:
    lda tc2,x
dc_w:
    sta (zp_p),y
    .if FULLCOL
    lda tcol,x
    sta (zp_c),y
    .endif
    lda t5
    eor #1
    sta t5
    bne dc_n
    inc t6
dc_n:
    inc t4
    lda t4
    cmp #WROWS
    bne dc_loop
    rts

; redraw the 2x2 chars of map tile (tx=t0, ty=t1) if visible
draw_tile:
    ; char col = tx*2 - (view_tx*2+sub_x)
    lda t0
    sec
    sbc view_tx
    bcc dt_x
    cmp #21
    bcs dt_x
    asl
    sec
    sbc sub_x
    sta t2
    lda t1
    sec
    sbc view_ty
    bcc dt_x
    cmp #(WROWS/2+2)
    bcs dt_x
    asl
    sec
    sbc sub_y
    sta t3
    ldx t1
    lda maprow_lo,x
    sta zp_m
    lda maprow_hi,x
    sta zp_m+1
    ldy t0
    lda (zp_m),y
    and #$3f
    tax
    lda tc0,x
    sta t4
    lda tc1,x
    sta t5
    lda tc2,x
    sta t6
    lda tc3,x
    sta t7
    lda tcol,x
    sta dt_col
    ldy t2
    lda t3
    ldx #t4
    jsr dt_put
    iny
    ldx #t5
    jsr dt_put
    dey
    lda t3
    clc
    adc #1
    sta t3
    ldx #t6
    jsr dt_put
    iny
    ldx #t7
    jsr dt_put
dt_x:
    rts
; put char zp(x) at col y (signed, 0..39) row t3 (signed, 0..WROWS-1)
dt_put:
    cpy #40
    bcs dtp_x
    lda t3
    cmp #WROWS
    bcs dtp_x
    clc
    adc #WTOP
    stx dtp_ld+1
    tax
    lda scr_lo,x
    sta zp_p
    sta zp_c
    lda scr_hi,x
    sta zp_p+1
    clc
    adc #>(COLR-SCR)
    sta zp_c+1
dtp_ld:
    lda t4
    sta (zp_p),y
    .if FULLCOL
    lda dt_col
    sta (zp_c),y
    .endif
dtp_x:
    rts

; ---------------------------------------------------------------------
; tiles: get/set. IN: px (t0,t1 = x lo/hi)  py (t2,t3)  OUT: A = attr, X = tile, t4/t5 = tx/ty
tile_at:
    lda t1
    sta t5
    lda t0
    lsr t5
    ror
    lsr t5
    ror
    lsr t5
    ror
    lsr t5
    ror
    sta t4
    lda t5
    bne ta_out
    lda t4
    cmp map_w
    bcs ta_out
    lda t3
    sta t5
    lda t2
    lsr t5
    ror
    lsr t5
    ror
    lsr t5
    ror
    lsr t5
    ror
    ldx t5
    bne ta_below
    cmp map_h
    bcs ta_below
    sta t5
    tax
    lda maprow_lo,x
    sta zp_m
    lda maprow_hi,x
    sta zp_m+1
    ldy t4
    lda (zp_m),y
    and #$3f
    tax
    lda tattr,x
    rts
ta_out:
    ldx #0
    lda #A_SOLID
    rts
ta_below:
    ldx #0
    lda t3
    bmi ta_above
    lda #A_DEADLY
    rts
ta_above:
    lda #0
    rts

; set tile t4,t5 to A and redraw
set_tile:
    pha
    ldx t5
    lda maprow_lo,x
    sta zp_m
    lda maprow_hi,x
    sta zp_m+1
    ldy t4
    pla
    sta (zp_m),y
    lda t4
    sta t0
    lda t5
    sta t1
    jmp draw_tile

; point of entity X with offsets (A=dx, Y=dy) -> t0..t3
ent_point:
    clc
    adc e_xlo,x
    sta t0
    lda e_xhi,x
    adc #0
    sta t1
    tya
    clc
    adc e_ylo,x
    sta t2
    lda e_yhi,x
    adc #0
    sta t3
    rts

; attr union at the 4 hitbox corners of entity X (x 5..18, y 3..19) -> A
ent_attr4:
    stx t7
    lda #5
    ldy #3
    jsr ent_point
    jsr tile_at
    sta t6
    ldx t7
    lda #18
    ldy #3
    jsr ent_point
    jsr tile_at
    ora t6
    sta t6
    ldx t7
    lda #5
    ldy #19
    jsr ent_point
    jsr tile_at
    ora t6
    sta t6
    ldx t7
    lda #18
    ldy #19
    jsr ent_point
    jsr tile_at
    ora t6
    ldx t7
    rts

; ---------------------------------------------------------------------
; 16-bit add of signed A to entity coordinate: x axis
add_ex:
    cmp #0
    bmi aex_n
    clc
    adc e_xlo,x
    sta e_xlo,x
    bcc aex_r
    inc e_xhi,x
aex_r:
    rts
aex_n:
    clc
    adc e_xlo,x
    sta e_xlo,x
    bcs aex_r
    dec e_xhi,x
    rts
add_ey:
    cmp #0
    bmi aey_n
    clc
    adc e_ylo,x
    sta e_ylo,x
    bcc aey_r
    inc e_yhi,x
aey_r:
    rts
aey_n:
    clc
    adc e_ylo,x
    sta e_ylo,x
    bcs aey_r
    dec e_yhi,x
    rts

; move entity X along e_dir by e_spd (no collision)
move_dir:
    ldy e_dir,x
    lda e_spd,x
    sta t7
mvd1:
    lda dir_dx,y
    jsr add_ex
    lda dir_dy,y
    jsr add_ey
    dec t7
    bne mvd1
    rts

; ---------------------------------------------------------------------
game_logic:
    jsr player_update
    jsr scroll_update
    lda coarse
    beq gl_full
    jmp place_sprites
gl_full:
    jsr spawners
    jsr entities
    jsr collisions
    .if KIND_CAVE
    jsr cave_physics
    .endif
    jsr hud_update
    jsr place_sprites
    rts

; ---------------------------------------------------------------------
scroll_update:
    lda #0
    sta dvx
    sta dvy
    .if AUTO_H
    lda fcount
    and #AUTODIV
    bne su_x
    lda view_x+1
    cmp vmax_x+1
    bne su_x1
    lda view_x
    cmp vmax_x
    beq su_x
su_x1:
    lda #1
    sta dvx
    ; carry the player along
    ldx #0
    jsr add_ex
su_x:
    .endif
    .if AUTO_V
    lda fcount
    and #AUTODIV
    bne su_v
    lda view_y
    ora view_y+1
    beq su_v
    lda #$ff
    sta dvy
    ldx #0
    jsr add_ey
su_v:
    .endif
    .if FOLLOW
    .if SCROLL_H+0
    ; player screen x = e_x - view_x ; push zone 120..184
    sec
    lda e_xlo
    sbc view_x
    sta t0
    lda e_xhi
    sbc view_x+1
    bmi su_fx_lo
    bne su_fx_hi
    lda t0
    cmp #120
    bcs su_fx1
    sec
    sbc #120
    cmp #$f9
    bcs su_fx_set
su_fx_lo:
    lda #$f9
    jmp su_fx_set
su_fx1:
    cmp #185
    bcc su_fy
    sec
    sbc #184
    cmp #8
    bcc su_fx_set
su_fx_hi:
    lda #7
su_fx_set:
    sta dvx
su_fy:
    .endif
    .if SCROLL_V+0
    sec
    lda e_ylo
    sbc view_y
    sta t0
    lda e_yhi
    sbc view_y+1
    bmi su_fy_lo
    bne su_fy_hi
    lda t0
    cmp #<(WIN_PXH/2-24)
    bcs su_fy1
    sec
    sbc #<(WIN_PXH/2-24)
    cmp #$f9
    bcs su_fy_set
su_fy_lo:
    lda #$f9
    jmp su_fy_set
su_fy1:
    cmp #<(WIN_PXH/2+8)
    bcc su_fdone
    sec
    sbc #<(WIN_PXH/2+7)
    cmp #8
    bcc su_fy_set
su_fy_hi:
    lda #7
su_fy_set:
    sta dvy
su_fdone:
    .endif
    .endif
    .if AUTO_H+AUTO_V
    lda dvx
    ora dvy
    bne su_ae
    inc end_t
    lda end_t
    cmp #250
    bcc su_ae
    lda #2
    sta game_state
su_ae:
    .endif
    .if FLIP
    jmp flip_check
    .else
    lda dvx
    ora dvy
    beq su_r
    jmp view_move
su_r:
    rts
    .endif

    .if FLIP
flip_check:
    ; player screen pos outside window -> move view a whole window
    lda view_x
    sta fl_ox
    lda view_x+1
    sta fl_ox+1
    lda view_y
    sta fl_oy
    lda view_y+1
    sta fl_oy+1
    sec
    lda e_xlo
    sbc view_x
    sta t0
    lda e_xhi
    sbc view_x+1
    bmi fl_left
    beq fl_lo
    cmp #1
    bne fl_right
    lda t0
    cmp #<(320-24)
    bcs fl_right
    jmp fl_v
fl_lo:
    lda t0
    cmp #8
    bcc fl_left
    jmp fl_v
fl_left:
    sec
    lda view_x
    sbc #<(320-32)
    sta view_x
    lda view_x+1
    sbc #>(320-32)
    sta view_x+1
    bcs fl_do
    lda #0
    sta view_x
    sta view_x+1
    jmp fl_do
fl_right:
    clc
    lda view_x
    adc #<(320-32)
    sta view_x
    lda view_x+1
    adc #>(320-32)
    sta view_x+1
    jsr clamp_vx
    jmp fl_do
fl_v:
    sec
    lda e_ylo
    sbc view_y
    sta t0
    lda e_yhi
    sbc view_y+1
    bmi fl_up
    bne fl_down
    lda t0
    cmp #<(WIN_PXH-21)
    bcs fl_down
    rts
fl_up:
    sec
    lda view_y
    sbc #<(WIN_PXH-16)
    sta view_y
    lda view_y+1
    sbc #>(WIN_PXH-16)
    sta view_y+1
    bcs fl_do
    lda #0
    sta view_y
    sta view_y+1
    jmp fl_do
fl_down:
    clc
    lda view_y
    adc #<(WIN_PXH-16)
    sta view_y
    lda view_y+1
    adc #>(WIN_PXH-16)
    sta view_y+1
    jsr clamp_vy
fl_do:
    lda view_x
    cmp fl_ox
    bne fl_go
    lda view_x+1
    cmp fl_ox+1
    bne fl_go
    lda view_y
    cmp fl_oy
    bne fl_go
    lda view_y+1
    cmp fl_oy+1
    bne fl_go
    rts
fl_go:
    lda #1
    sta pend
    jsr view_split
    jmp compute_disp
    .endif

; ---------------------------------------------------------------------
player_update:
    lda e_kind
    cmp #K_PLAYER
    beq pu_go
    rts
pu_go:
    ldx #0
    lda joy
    and #15
    ora grid_mv
    sta moving
    lda fire_cd
    beq pu_f0
    dec fire_cd
pu_f0:
    .if KIND_SHMUP+KIND_TOP
    jsr pl_free
    .endif
    .if KIND_PLAT
    jsr pl_plat
    .endif
    .if KIND_CAVE
    jsr pl_cave
    .endif
    .if WEAPON_ON
    lda joy
    and #16
    beq pu_nf
    lda fire_cd
    bne pu_nf
    jsr player_fire
pu_nf:
    .endif
    ; tile effects (collect / deadly / exit)
    .if KIND_CAVE
    rts
    .else
    ldx #0
    lda #12
    ldy #11
    jsr ent_point
    jsr tile_at
    sta t6
    and #A_COLLECT
    beq pu_nc
    txa
    pha
    lda #0
    jsr set_tile
    pla
    tax
    jsr collect_tile
pu_nc:
    lda t6
    and #A_EXIT
    beq pu_ne
    lda need_got
    cmp need
    bcc pu_ne
    lda #2
    sta game_state
pu_ne:
    ldx #0
    jsr ent_attr4
    and #A_DEADLY
    beq pu_nd
    lda #1
    sta game_state
pu_nd:
    .if KIND_SHMUP
    ldx #0
    jsr ent_attr4
    and #A_SOLID
    beq pu_ns
    lda #1
    sta game_state
pu_ns:
    .endif
    rts
    .endif

; X = tile index collected
collect_tile:
    lda tscore,x
    jsr add_score
    inc need_got
    lda #SFX_COLLECT
    jmp play_sfx

; ---------- free 8-way movement (shooter / top-down) ----------
pl_free:
    lda joy
    and #15
    bne rx_6
    jmp plf_r
rx_6:
    ldy #8
    lda joy
    and #1
    beq plf1
    ldy #0
plf1:
    lda joy
    and #2
    beq plf2
    ldy #4
plf2:
    lda joy
    and #4
    beq plf3
    lda #6
    cpy #0
    bne plf3a
    lda #7
plf3a:
    cpy #4
    bne plf3b
    lda #5
plf3b:
    tay
plf3:
    lda joy
    and #8
    beq plf4
    lda #2
    cpy #0
    bne plf4a
    lda #1
plf4a:
    cpy #4
    bne plf4b
    lda #3
plf4b:
    tay
plf4:
    cpy #8
    beq plf_r
    .if KIND_TOP
    sty e_dir
    .endif
    lda #PSPEED
    sta mv_cnt
    sty mv_y
plf_step:
    ldy mv_y
    lda dir_dx,y
    beq plf_y
    sta mv_d
    jsr add_ex
    .if KIND_TOP
    jsr ent_attr4
    and #A_SOLID
    beq plf_y
    lda #0
    sec
    sbc mv_d
    jsr add_ex
    .endif
plf_y:
    ldy mv_y
    lda dir_dy,y
    beq plf_n
    sta mv_d
    jsr add_ey
    .if KIND_TOP
    jsr ent_attr4
    and #A_SOLID
    beq plf_n
    lda #0
    sec
    sbc mv_d
    jsr add_ey
    .endif
plf_n:
    dec mv_cnt
    bne plf_step
plf_r:
    .if KIND_SHMUP
    jsr clamp_to_view
    .endif
    rts

    .if KIND_SHMUP
; keep player inside the visible window
clamp_to_view:
    ; x >= view_x+8
    clc
    lda view_x
    adc #8
    sta t0
    lda view_x+1
    adc #0
    sta t1
    lda e_xhi
    cmp t1
    bcc ctv_xl
    bne ctv_x2
    lda e_xlo
    cmp t0
    bcs ctv_x2
ctv_xl:
    lda t0
    sta e_xlo
    lda t1
    sta e_xhi
ctv_x2:
    clc
    lda view_x
    adc #<(320-32)
    sta t0
    lda view_x+1
    adc #>(320-32)
    sta t1
    lda e_xhi
    cmp t1
    bcc ctv_y
    bne ctv_xh
    lda e_xlo
    cmp t0
    bcc ctv_y
ctv_xh:
    lda t0
    sta e_xlo
    lda t1
    sta e_xhi
ctv_y:
    lda e_yhi
    cmp view_y+1
    bcc ctv_yl
    bne ctv_y2
    lda e_ylo
    cmp view_y
    bcs ctv_y2
ctv_yl:
    lda view_y
    sta e_ylo
    lda view_y+1
    sta e_yhi
ctv_y2:
    clc
    lda view_y
    adc #<(WIN_PXH-21)
    sta t0
    lda view_y+1
    adc #>(WIN_PXH-21)
    sta t1
    lda e_yhi
    cmp t1
    bcc ctv_r
    bne ctv_yh
    lda e_ylo
    cmp t0
    bcc ctv_r
ctv_yh:
    lda t0
    sta e_ylo
    lda t1
    sta e_yhi
ctv_r:
    rts
    .endif

; ---------- platformer ----------
    .if KIND_PLAT
pl_plat:
    ; horizontal
    lda joy
    and #12
    beq pp_v
    lda #PSPEED
    sta mv_cnt
pp_h:
    lda joy
    and #4
    beq pp_hr
    lda #6
    sta e_dir
    lda #$ff
    jmp pp_hm
pp_hr:
    lda #2
    sta e_dir
    lda #1
pp_hm:
    sta mv_d
    jsr add_ex
    jsr ent_attr4
    and #A_SOLID
    beq pp_hn
    lda #0
    sec
    sbc mv_d
    jsr add_ex
    jmp pp_v
pp_hn:
    dec mv_cnt
    bne pp_h
pp_v:
    ; ladder?
    lda #12
    ldy #12
    jsr ent_point
    jsr tile_at
    and #A_LADDER
    beq pp_noladder
    lda joy
    and #3
    beq pp_noladder
    lda #0
    sta e_vy
    lda joy
    and #1
    beq pp_ldn
    lda #$ff
    jmp pp_lm
pp_ldn:
    lda #1
pp_lm:
    sta mv_d
    lda #2
    sta mv_cnt
pp_lstep:
    lda mv_d
    jsr add_ey
    jsr ent_attr4
    and #A_SOLID
    beq pp_lok
    lda #0
    sec
    sbc mv_d
    jsr add_ey
    rts
pp_lok:
    dec mv_cnt
    bne pp_lstep
    rts
pp_noladder:
    ; on ground?
    jsr on_ground
    sta t6
    beq pp_air
    lda e_vy
    bmi pp_air
    lda #0
    sta e_vy
    lda joy
    and #JUMPMASK
    beq pp_nj
    lda jump_held
    bne pp_nj2
    lda #(256-JUMPV)
    sta e_vy
    lda #SFX_JUMP
    jsr play_sfx
    ldx #0
    lda #1
    sta jump_held
    jmp pp_air
pp_nj:
    lda #0
    sta jump_held
pp_nj2:
    rts
pp_air:
    lda joy
    and #JUMPMASK
    bne pp_air1
    lda #0
    sta jump_held
pp_air1:
    ; gravity
    lda fcount
    and #GRAVDIV
    bne pp_g1
    lda e_vy
    bmi pp_g0
    cmp #MAXFALL
    bcs pp_g1
pp_g0:
    inc e_vy
pp_g1:
    lda e_vy
    beq pp_r
    bmi pp_up
    sta mv_cnt
pp_dn:
    jsr on_ground
    bne pp_land
    lda #1
    jsr add_ey
    dec mv_cnt
    bne pp_dn
    rts
pp_land:
    lda #0
    sta e_vy
    rts
pp_up:
    eor #$ff
    clc
    adc #1
    sta mv_cnt
pp_u1:
    lda #$ff
    jsr add_ey
    jsr ent_attr4
    and #A_SOLID
    beq pp_u2
    lda #1
    jsr add_ey
    lda #0
    sta e_vy
    rts
pp_u2:
    dec mv_cnt
    bne pp_u1
pp_r:
    rts

; A != 0 if a solid / one-way / ladder top is just below the feet
on_ground:
    lda #6
    ldy #21
    jsr ent_point
    jsr tile_at
    sta t6
    lda #17
    ldy #21
    jsr ent_point
    jsr tile_at
    ora t6
    sta t6
    and #A_SOLID
    bne og_y
    lda t6
    and #A_ONEWAY
    beq og_n
    ; one-way: only when feet exactly on tile top
    lda e_ylo
    clc
    adc #21
    and #15
    bne og_n
og_y:
    ldx #0
    lda #1
    rts
og_n:
    ldx #0
    lda #0
    rts
    .endif

; ---------- cave digger (grid moves of 16px) ----------
    .if KIND_CAVE
pl_cave:
    lda grid_mv
    beq rx_4
    jmp pc_moving
rx_4:
    lda joy
    and #15
    bne pc_in
    rts
pc_in:
    ; choose dir 0 up 2 right 4 down 6 left
    ldy #0
    lsr
    bcs pc_d
    ldy #4
    lsr
    bcs pc_d
    ldy #6
    lsr
    bcs pc_d
    ldy #2
pc_d:
    sty e_dir
    jsr player_tile
    ldy e_dir
    lda t4
    clc
    adc dir_dx,y
    sta cv_x
    sta t4
    lda t5
    clc
    adc dir_dy,y
    sta cv_y
    sta t5
    jsr map_get
    sta cv_tile
    tax
    lda tattr,x
    sta cv_attr
    and #A_SOLID
    bne pc_block
    lda cv_attr
    and #A_FALLS
    beq pc_ok
    lda cv_attr
    and #A_COLLECT
    bne pc_ok
    ; push boulder sideways if the cell behind is empty
    ldy e_dir
    cpy #2
    beq pc_push
    cpy #6
    beq pc_push
pc_block:
    rts
pc_push:
    lda fcount
    and #3
    bne pc_block
    lda cv_x
    clc
    adc dir_dx,y
    sta t4
    lda cv_y
    sta t5
    jsr map_get
    cmp #0
    bne pc_block
    lda cv_tile
    jsr set_tile
    lda cv_x
    sta t4
    lda cv_y
    sta t5
    lda #0
    jsr set_tile
    jmp pc_go
pc_ok:
    lda cv_attr
    and #A_EXIT
    beq pc_nx
    lda need_got
    cmp need
    bcc pc_block
    lda #2
    sta game_state
    rts
pc_nx:
    lda cv_attr
    and #A_DEADLY
    beq pc_nd
    lda #1
    sta game_state
    rts
pc_nd:
    lda cv_attr
    and #A_COLLECT
    beq pc_nc
    ldx cv_tile
    jsr collect_tile
pc_nc:
    lda cv_attr
    and #(A_DIG+A_COLLECT)
    beq pc_go
    lda cv_x
    sta t4
    lda cv_y
    sta t5
    lda #0
    jsr set_tile
pc_go:
    lda #16
    sta grid_mv
pc_moving:
    ldx #0
    ldy e_dir
    lda #2
    sta t7
pc_m1:
    lda dir_dx,y
    jsr add_ex
    lda dir_dy,y
    jsr add_ey
    dec grid_mv
    beq pc_r
    dec t7
    bne pc_m1
pc_r:
    rts

; player tile -> t4/t5
player_tile:
    lda e_xhi
    sta t5
    lda e_xlo
    clc
    adc #8
    bcc ptl1
    inc t5
ptl1:
    lsr t5
    ror
    lsr t5
    ror
    lsr t5
    ror
    lsr t5
    ror
    sta t4
    lda e_yhi
    sta t5
    lda e_ylo
    clc
    adc #8
    bcc ptl2
    inc t5
ptl2:
    lsr t5
    ror
    lsr t5
    ror
    lsr t5
    ror
    lsr t5
    ror
    sta t5
    rts

; map value at t4,t5 (tile index, low 6 bits) -> A ; out of map -> wall tile 1
map_get:
    lda t4
    cmp map_w
    bcs mg_o
    ldx t5
    cpx map_h
    bcs mg_o
    lda maprow_lo,x
    sta zp_m
    lda maprow_hi,x
    sta zp_m+1
    ldy t4
    lda (zp_m),y
    and #$3f
    ldy e_dir
    rts
mg_o:
    lda #1
    ldy e_dir
    rts

; falling objects, CAVE_ROWS rows per frame, bottom-up
cave_physics:
    lda #CAVE_ROWS
    sta cp_n
cp_row:
    lda cave_row
    bne cp_r1
    lda map_h
    sta cave_row
cp_r1:
    dec cave_row
    ldx cave_row
    lda maprow_lo,x
    sta zp_s
    lda maprow_hi,x
    sta zp_s+1
    inx
    cpx map_h
    bcc cp_r2
    jmp cp_next
cp_r2:
    lda maprow_lo,x
    sta zp_d
    lda maprow_hi,x
    sta zp_d+1
    ldy #0
cp_cell:
    lda (zp_s),y
    and #$40
    beq cp_c0
    lda (zp_s),y
    and #$bf
    sta (zp_s),y
    jmp cp_cn
cp_c0:
    lda (zp_s),y
    and #$3f
    tax
    lda tattr,x
    and #A_FALLS
    bne rx_5
    jmp cp_cn
rx_5:
    stx cp_t
    ; below
    lda (zp_d),y
    and #$3f
    bne cp_below
    ; is the player in the cell below?
    jsr cp_player_below
    bcc cp_fall
    lda (zp_s),y
    bpl cp_stop
    lda #1
    sta game_state
    jmp cp_cn
cp_fall:
    lda cp_t
    ora #$80
    sta (zp_d),y
    lda #0
    sta (zp_s),y
    jsr cp_draw2
    jmp cp_cn
cp_below:
    tax
    lda tattr,x
    and #A_FALLS
    beq cp_stop
    ; roll left?
    cpy #0
    beq cp_rr
    dey
    lda (zp_s),y
    and #$3f
    bne cp_rl_no
    lda (zp_d),y
    and #$3f
    bne cp_rl_no
    lda cp_t
    ora #$80
    sta (zp_s),y
    iny
    lda #0
    sta (zp_s),y
    dey
    jsr cp_draw_side
    iny
    jmp cp_cn
cp_rl_no:
    iny
cp_rr:
    iny
    cpy map_w
    bcs cp_rr_no
    lda (zp_s),y
    and #$3f
    bne cp_rr_no
    lda (zp_d),y
    and #$3f
    bne cp_rr_no
    lda cp_t
    ora #$c0
    sta (zp_s),y
    dey
    lda #0
    sta (zp_s),y
    jsr cp_draw_side
    jmp cp_cn
cp_rr_no:
    dey
cp_stop:
    lda (zp_s),y
    and #$7f
    sta (zp_s),y
cp_cn:
    iny
    cpy map_w
    bcs cp_next
    jmp cp_cell
cp_next:
    dec cp_n
    beq cp_done
    jmp cp_row
cp_done:
    rts

; C=1 if the player occupies tile (y, cave_row+1)
cp_player_below:
    sty cp_y
    jsr player_tile
    ldy cp_y
    lda cave_row
    clc
    adc #1
    cmp t5
    bne cpb_n
    cpy t4
    bne cpb_n
    sec
    rts
cpb_n:
    clc
    rts

; redraw cell (y,row) and (y,row+1)
cp_draw2:
    sty cp_y
    sty t0
    lda cave_row
    sta t1
    jsr draw_tile
    ldy cp_y
    sty t0
    lda cave_row
    clc
    adc #1
    sta t1
    jsr draw_tile
    ldy cp_y
    lda cave_row
    tax
    lda maprow_lo,x
    sta zp_s
    lda maprow_hi,x
    sta zp_s+1
    inx
    lda maprow_lo,x
    sta zp_d
    lda maprow_hi,x
    sta zp_d+1
    rts
; redraw cells y and y+1 in this row
cp_draw_side:
    sty cp_y
    sty t0
    lda cave_row
    sta t1
    jsr draw_tile
    ldy cp_y
    iny
    sty t0
    lda cave_row
    sta t1
    jsr draw_tile
    ldy cp_y
    jmp cp_draw2
    .endif

; ---------------------------------------------------------------------
    .if WEAPON_ON
player_fire:
    lda #FIRE_COOLDOWN
    sta fire_cd
    lda #SFX_SHOOT
    jsr play_sfx
    ldy e_dir
    .if KIND_PLAT
    ldy e_dir
    .endif
    ldx #1
    jsr spawn_pbullet
    .if WEAPON_DOUBLE
    ldy e_dir
    ldx #2
    jsr spawn_pbullet
    lda e_dir
    and #2
    beq pf_dv
    lda #8
    jmp add_ey
pf_dv:
    lda #8
    jmp add_ex
    .endif
    .if WEAPON_SPREAD
    lda e_dir
    clc
    adc #1
    and #7
    tay
    ldx #2
    jmp spawn_pbullet
    .endif
    rts

; X = slot, Y = dir
spawn_pbullet:
    lda e_kind,x
    beq spb1
    rts
spb1:
    lda #K_PBUL
    sta e_kind,x
    tya
    sta e_dir,x
    lda #BSPEED
    sta e_spd,x
    lda #BSPR
    sta e_spr,x
    lda #BCOL
    sta e_col,x
    lda e_xlo
    sta e_xlo,x
    lda e_xhi
    sta e_xhi,x
    lda e_ylo
    sta e_ylo,x
    lda e_yhi
    sta e_yhi,x
    lda #40
    sta e_t,x
    rts
    .endif

; ---------------------------------------------------------------------
; spawners: check 2 per frame
spawners:
    lda nsp
    bne spw0
    rts
spw0:
    lda #2
    sta t7
spw_loop:
    ldx sp_scan
    inx
    cpx nsp
    bcc spw1
    ldx #0
spw1:
    stx sp_scan
    lda sp_state,x
    bne spw_active
    ; record pointer zp_s = sp_ptr + x*6
    jsr sp_rec
    ; dx = tile_x*16 - view_x + 32 must be in 0..383
    ldy #0
    lda (zp_s),y
    jsr tile_px
    sec
    lda t0
    sbc view_x
    sta t0
    lda t1
    sbc view_x+1
    sta t1
    clc
    lda t0
    adc #32
    sta t0
    lda t1
    adc #0
    beq spw_y
    cmp #1
    bne spw_next
    lda t0
    cmp #128
    bcs spw_next
spw_y:
    ldy #1
    lda (zp_s),y
    jsr tile_px
    sec
    lda t0
    sbc view_y
    sta t0
    lda t1
    sbc view_y+1
    sta t1
    clc
    lda t0
    adc #32
    sta t0
    lda t1
    adc #0
    cmp #>(WIN_PXH+64)
    bcc spw_trig
    bne spw_next
    lda t0
    cmp #<(WIN_PXH+64)
    bcs spw_next
spw_trig:
    ldx sp_scan
    lda #1
    sta sp_state,x
    ldy #3
    lda (zp_s),y
    sta sp_left,x
    lda #0
    sta sp_timer,x
spw_active:
    ldx sp_scan
    lda sp_left,x
    beq spw_next
    lda sp_timer,x
    beq spw_fire
    dec sp_timer,x
    jmp spw_next
spw_fire:
    jsr sp_rec
    jsr spawn_enemy
    bcc spw_next
    ldx sp_scan
    dec sp_left,x
    ldy #4
    lda (zp_s),y
    sta sp_timer,x
spw_next:
    dec t7
    beq spw_r
    jmp spw_loop
spw_r:
    rts

; A = tile coordinate -> t0/t1 = A*16
tile_px:
    sta t0
    lda #0
    sta t1
    lda t0
    asl
    rol t1
    asl
    rol t1
    asl
    rol t1
    asl
    rol t1
    sta t0
    rts

sp_rec:
    lda sp_scan
    asl
    sta t0
    asl
    clc
    adc t0
    clc
    adc sp_ptr
    sta zp_s
    lda sp_ptr+1
    adc #0
    sta zp_s+1
    rts

; spawn from record zp_s, C=1 on success
spawn_enemy:
    ldx #3
se1:
    lda e_kind,x
    beq se_ok
    inx
    cpx #8
    bne se1
    clc
    rts
se_ok:
    ldy #2
    lda (zp_s),y
    sta e_type,x
    tay
    lda #K_ENEMY
    sta e_kind,x
    lda et_spr,y
    sta e_spr,x
    lda et_col,y
    sta e_col,x
    lda et_spd,y
    sta e_spd,x
    lda et_hp,y
    sta e_hp,x
    lda et_dir,y
    sta e_dir,x
    lda et_rate,y
    sta e_t,x
    lda #0
    sta e_vy,x
    sta e_ph,x
    ldy #5
    lda (zp_s),y
    cmp #8
    bcs se_d
    sta e_dir,x
se_d:
    ldy #0
    lda (zp_s),y
    sta t0
    lda #0
    sta e_xhi,x
    lda t0
    asl
    rol e_xhi,x
    asl
    rol e_xhi,x
    asl
    rol e_xhi,x
    asl
    rol e_xhi,x
    sta e_xlo,x
    ldy #1
    lda (zp_s),y
    sta t0
    lda #0
    sta e_yhi,x
    lda t0
    asl
    rol e_yhi,x
    asl
    rol e_yhi,x
    asl
    rol e_yhi,x
    asl
    rol e_yhi,x
    sta e_ylo,x
    ; walkers stand on the tile below their spawn square
    ldy e_type,x
    lda et_move,y
    cmp #5
    bne se_y
    sec
    lda e_ylo,x
    sbc #5
    sta e_ylo,x
    bcs se_y
    dec e_yhi,x
se_y:
    sec
    rts

; ---------------------------------------------------------------------
entities:
    ldx #1
en_loop:
    lda e_kind,x
    beq en_next
    cmp #K_PBUL
    bne en_1
    jsr upd_bullet
    jmp en_next
en_1:
    cmp #K_EBUL
    bne en_2
    jsr upd_bullet
    jmp en_next
en_2:
    cmp #K_ENEMY
    bne en_3
    jsr upd_enemy
    jmp en_next
en_3:
    cmp #K_DYING
    bne en_next
    dec e_t,x
    bne en_next
    lda #0
    sta e_kind,x
en_next:
    inx
    cpx #8
    bne en_loop
    rts

upd_bullet:
    jsr move_dir
    dec e_t,x
    beq ub_kill
    jsr ent_offview
    bcs ub_kill
    stx t7
    lda #12
    ldy #10
    jsr ent_point
    jsr tile_at
    ldx t7
    and #A_SOLID
    beq ub_r
ub_kill:
    lda #0
    sta e_kind,x
ub_r:
    rts

; C=1 if entity X is far outside the view
ent_offview:
    sec
    lda e_xlo,x
    sbc view_x
    sta t0
    lda e_xhi,x
    sbc view_x+1
    sta t1
    clc
    lda t0
    adc #48
    sta t0
    lda t1
    adc #0
    bne eov_y1
    jmp eov_y
eov_y1:
    cmp #1
    bne eov_out
    lda t0
    cmp #<(320+96-256)
    bcs eov_out
eov_y:
    sec
    lda e_ylo,x
    sbc view_y
    sta t0
    lda e_yhi,x
    sbc view_y+1
    sta t1
    clc
    lda t0
    adc #48
    sta t0
    lda t1
    adc #0
    bne eov_out
    lda t0
    cmp #<(WIN_PXH+80)
    bcs eov_out
    clc
    rts
eov_out:
    sec
    rts

upd_enemy:
    ldy e_type,x
    lda et_move,y
    bne ue_1
    jmp ue_chk
ue_1:
    cmp #1
    bne ue_2
    jsr move_dir
    jmp ue_chk
ue_2:
    cmp #2
    bne ue_3
    ; sine: move along dir, wave on the other axis
    jsr move_dir
    inc e_ph,x
    lda e_ph,x
    lsr
    lsr
    and #15
    tay
    lda sine_t,y
    sta t5
    ldy e_dir,x
    lda dir_dx,y
    beq ue_2x
    lda t5
    jsr add_ey
    jmp ue_chk
ue_2x:
    lda t5
    jsr add_ex
    jmp ue_chk
ue_3:
    cmp #3
    bne ue_4
    ; homing: one step per speed toward player
    lda e_spd,x
    sta t6
ue_3l:
    lda e_xhi,x
    cmp e_xhi
    bne ue_3a
    lda e_xlo,x
    cmp e_xlo
    beq ue_3y
ue_3a:
    lda #1
    bcc ue_3b
    lda #$ff
ue_3b:
    jsr add_ex
ue_3y:
    lda e_yhi,x
    cmp e_yhi
    bne ue_3c
    lda e_ylo,x
    cmp e_ylo
    beq ue_3n
ue_3c:
    lda #1
    bcc ue_3d
    lda #$ff
ue_3d:
    jsr add_ey
ue_3n:
    dec t6
    bne ue_3l
    jmp ue_chk
ue_4:
    cmp #4
    beq rx_2
    jmp ue_5
rx_2:
    ; bounce off solid tiles and window edges
    jsr move_dir
    jsr ent_attr4
    and #A_SOLID
    beq ue_4e
    lda e_dir,x
    clc
    adc #4
    and #7
    sta e_dir,x
    jsr move_dir
    jmp ue_chk
ue_4e:
    sec
    lda e_xlo,x
    sbc view_x
    sta t0
    lda e_xhi,x
    sbc view_x+1
    bmi ue_4l
    bne ue_4r
    lda t0
    cmp #8
    bcc ue_4l
    jmp ue_4y
ue_4r:
    cmp #1
    bne ue_4y
    lda t0
    cmp #<(320-32-256)
    bcc ue_4y
    ; at right edge: if moving right, mirror
    lda e_dir,x
    cmp #1
    bcc ue_4y
    cmp #4
    bcs ue_4y
    jmp ue_4mx
ue_4l:
    lda e_dir,x
    cmp #5
    bcc ue_4y
ue_4mx:
    lda #8
    sec
    sbc e_dir,x
    and #7
    sta e_dir,x
ue_4y:
    sec
    lda e_ylo,x
    sbc view_y
    sta t0
    lda e_yhi,x
    sbc view_y+1
    bmi ue_4u
    bne ue_4d
    lda t0
    cmp #<(WIN_PXH-21)
    bcc ue_4z
ue_4d:
    ; moving down (3,4,5) -> mirror
    lda e_dir,x
    cmp #3
    bcc ue_4z
    cmp #6
    bcs ue_4z
    jmp ue_4my
ue_4u:
    lda e_dir,x
    cmp #2
    bcc ue_4my
    cmp #7
    bcc ue_4z
ue_4my:
    lda #4
    sec
    sbc e_dir,x
    and #7
    sta e_dir,x
ue_4z:
    jmp ue_chk
ue_5:
    cmp #5
    bne ue_6
    ; walker: horizontal, turn at walls and ledges, gravity
    jsr move_dir
    jsr ent_attr4
    and #A_SOLID
    bne ue_5t
    ; ledge check: tile below front foot
    lda e_dir,x
    cmp #2
    bne ue_5l
    lda #20
    jmp ue_5p
ue_5l:
    lda #3
ue_5p:
    ldy #22
    stx t7
    jsr ent_point
    jsr tile_at
    ldx t7
    and #(A_SOLID+A_ONEWAY+A_LADDER)
    bne ue_chk
ue_5t:
    lda e_dir,x
    eor #4
    sta e_dir,x
    jsr move_dir
    jmp ue_chk
ue_6:
    ; crawler: 4-dir, turn right when blocked
    jsr move_dir
    jsr ent_attr4
    and #A_SOLID
    beq ue_chk
    lda e_dir,x
    clc
    adc #4
    and #7
    sta e_dir,x
    jsr move_dir
    lda e_dir,x
    clc
    adc #6
    and #6
    sta e_dir,x
ue_chk:
    jsr ent_offview
    bcc ue_fire
    lda #0
    sta e_kind,x
    rts
ue_fire:
    ldy e_type,x
    lda et_fire,y
    beq ue_r
    dec e_t,x
    bne ue_r
    lda et_rate,y
    sta e_t,x
    ; find free slot for enemy bullet
    stx t6
    ldx #3
uf1:
    lda e_kind,x
    beq uf_ok
    inx
    cpx #8
    bne uf1
    ldx t6
ue_r:
    rts
uf_ok:
    ldy t6
    lda #K_EBUL
    sta e_kind,x
    lda #EBSPR
    sta e_spr,x
    lda #EBCOL
    sta e_col,x
    lda #2
    sta e_spd,x
    lda #120
    sta e_t,x
    lda e_xlo,y
    sta e_xlo,x
    lda e_xhi,y
    sta e_xhi,x
    lda e_ylo,y
    sta e_ylo,x
    lda e_yhi,y
    sta e_yhi,x
    lda e_type,y
    tay
    lda et_fire,y
    cmp #2
    beq uf_aim
    lda et_fdir,y
    sta e_dir,x
    ldx t6
    rts
uf_aim:
    sec
    lda e_xlo
    sbc e_xlo,x
    sta t0
    lda e_xhi
    sbc e_xhi,x
    sta t1
    jsr dir_of
    sta t2
    sec
    lda e_ylo
    sbc e_ylo,x
    sta t0
    lda e_yhi
    sbc e_yhi,x
    sta t1
    jsr dir_of
    tay
    lda ymap_t,y
    asl
    asl
    ora t2
    tay
    lda aim_t,y
    sta e_dir,x
    ldx t6
    rts

; t0/t1 signed -> A: 0 if |v|<12, 1 if positive, 2 if negative
dir_of:
    lda t1
    bmi do_neg
    bne do_pos
    lda t0
    cmp #12
    bcc do_z
do_pos:
    lda #1
    rts
do_neg:
    cmp #$ff
    bne do_n2
    lda t0
    cmp #$f5
    bcs do_z
do_n2:
    lda #2
    rts
do_z:
    lda #0
    rts

; ---------------------------------------------------------------------
; collisions: player vs enemies/ebullets, pbullets vs enemies
collisions:
    ldx #3
co_loop:
    lda e_kind,x
    cmp #K_ENEMY
    beq co_e
    cmp #K_EBUL
    bne co_next
    ; enemy bullet vs player
    ldy #0
    lda #10
    jsr box_hit
    bcc co_next
    lda e_kind
    cmp #K_PLAYER
    bne co_next
    lda #1
    sta game_state
    jmp co_next
co_e:
    ldy #0
    lda #14
    jsr box_hit
    bcc co_b
    lda #1
    sta game_state
co_b:
    ldy #1
co_bl:
    lda e_kind,y
    cmp #K_PBUL
    bne co_bn
    lda #12
    jsr box_hit
    bcc co_bn
    lda #0
    sta e_kind,y
    dec e_hp,x
    bne co_bn
    ; enemy destroyed
    lda #K_DYING
    sta e_kind,x
    lda #8
    sta e_t,x
    lda #1
    sta e_col,x
    stx t6
    ldy e_type,x
    lda et_score,y
    jsr add_score
    lda #SFX_HIT
    jsr play_sfx
    ldx t6
    jmp co_next
co_bn:
    iny
    cpy #3
    bne co_bl
co_next:
    inx
    cpx #8
    bne co_loop
    rts

; C=1 if |ex(x)-ex(y)| < A and |ey(x)-ey(y)| < A
box_hit:
    sta t5
    sec
    lda e_xlo,x
    sbc e_xlo,y
    sta t0
    lda e_xhi,x
    sbc e_xhi,y
    beq bh_xp
    cmp #$ff
    bne bh_n
    lda t0
    eor #$ff
    clc
    adc #1
    beq bh_n
    sta t0
    jmp bh_x
bh_xp:
bh_x:
    lda t0
    cmp t5
    bcs bh_n
    sec
    lda e_ylo,x
    sbc e_ylo,y
    sta t0
    lda e_yhi,x
    sbc e_yhi,y
    beq bh_y
    cmp #$ff
    bne bh_n
    lda t0
    eor #$ff
    clc
    adc #1
    beq bh_n
    sta t0
bh_y:
    lda t0
    cmp t5
    bcs bh_n
    sec
    rts
bh_n:
    clc
    rts

; ---------------------------------------------------------------------
; sprite shadow registers
place_sprites:
    lda #0
    sta sh_msb
    sta sh_en
    sta sh_mc
    ldx #7
ps_loop:
    lda e_kind,x
    bne rx_7
    jmp ps_next
rx_7:
    ; sx = ex - view_x + OFFX
    sec
    lda e_xlo,x
    sbc view_x
    sta t0
    lda e_xhi,x
    sbc view_x+1
    sta t1
    clc
    lda t0
    adc #OFFX
    sta t0
    lda t1
    adc #0
    sta t1
    beq ps_xok
    cmp #1
    beq rx_8
    jmp ps_next
rx_8:
    lda t0
    cmp #88
    bcc rx_9
    jmp ps_next
rx_9:
ps_xok:
    sec
    lda e_ylo,x
    sbc view_y
    sta t2
    lda e_yhi,x
    sbc view_y+1
    beq rx_10
    jmp ps_next
rx_10:
    lda t2
    cmp #<(WIN_PXH-6)
    bcs ps_next
    clc
    adc #OFFY
    sta sh_y,x
    lda t0
    sta sh_x,x
    lda t1
    beq ps_m0
    lda bit_t,x
    ora sh_msb
    sta sh_msb
ps_m0:
    lda bit_t,x
    ora sh_en
    sta sh_en
    ldy e_spr,x
    lda spr_mc,y
    beq ps_m1
    lda bit_t,x
    ora sh_mc
    sta sh_mc
ps_m1:
    ; animation frame: base + ((fcount >> rate) & mask); the player only animates while moving
    lda #0
    sta t3
    lda spr_fmask,y
    beq ps_nf
    cpx #0
    bne ps_an
    lda moving
    beq ps_nf
ps_an:
    lda fcount
    sta t3
    lda spr_rate,y
    beq ps_r0
    sta t4
ps_rs:
    lsr t3
    dec t4
    bne ps_rs
ps_r0:
    lda t3
    and spr_fmask,y
    sta t3
ps_nf:
    ; left-facing copies follow the right-facing frames
    lda spr_left,y
    beq ps_nl
    lda e_dir,x
    cmp #5
    bcc ps_nl
    lda spr_fmask,y
    sec
    adc t3
    sta t3
ps_nl:
    tya
    clc
    adc t3
    clc
    adc #128
    sta sh_ptr,x
ps_next:
    dex
    bmi rx_3
    jmp ps_loop
rx_3:
    rts

frame_vic:
    ldx #7
fv1:
    txa
    asl
    tay
    lda sh_x,x
    sta $d000,y
    lda sh_y,x
    sta $d001,y
    lda sh_ptr,x
    sta SCR+$3f8,x
    lda e_col,x
    sta $d027,x
    dex
    bpl fv1
    lda sh_msb
    sta $d010
    lda sh_mc
    sta $d01c
    lda sh_en
    sta $d015
    rts

; ---------------------------------------------------------------------
; HUD
hud_draw_static:
    ldx #0
    lda #32
hd1:
    sta SCR,x
    sta SCR+250,x
    sta SCR+500,x
    sta SCR+750,x
    inx
    cpx #250
    bne hd1
    ldx #0
hd2:
    lda hud_txt,x
    cmp #$ff
    beq hd3
    sta SCR+HUDROW*40,x
    inx
    bne hd2
hd3:
    rts
hud_draw_static_col:
    ldx #0
hdc:
    lda #HUDCOL
    sta COLR+HUDROW*40,x
    inx
    cpx #40
    bne hdc
    rts

hud_update:
    ; score 6 digits at col 6
    lda score+2
    jsr hud_bcd
    stx SCR+HUDROW*40+6
    sta SCR+HUDROW*40+7
    lda score+1
    jsr hud_bcd
    stx SCR+HUDROW*40+8
    sta SCR+HUDROW*40+9
    lda score
    jsr hud_bcd
    stx SCR+HUDROW*40+10
    sta SCR+HUDROW*40+11
    lda lives
    ora #48
    sta SCR+HUDROW*40+19
    lda need
    beq hu_r
    lda need_got
    jsr bin2dec
    stx SCR+HUDROW*40+30
    sta SCR+HUDROW*40+31
    lda need
    jsr bin2dec
    stx SCR+HUDROW*40+33
    sta SCR+HUDROW*40+34
hu_r:
    rts

hud_bcd:
    pha
    lsr
    lsr
    lsr
    lsr
    ora #48
    tax
    pla
    and #15
    ora #48
    rts

bin2dec:
    ldx #48
b2d1:
    cmp #10
    bcc b2d2
    sbc #10
    inx
    jmp b2d1
b2d2:
    ora #48
    rts

; A = BCD points (00..99) added to the 6-digit score
add_score:
    sed
    clc
    adc score
    sta score
    lda score+1
    adc #0
    sta score+1
    lda score+2
    adc #0
    sta score+2
    cld
    rts

; ---------------------------------------------------------------------
; sound: play_sfx (A = sound, 255 none), sfx_update, sfx_stop and sfx_init are
; generated with the sound tables by sid_emit (scr_sid) - one player for both kinds of game.
; music: mus_level (A = level), mus_play (A = song), mus_stop - the 3-voice driver and the
; songs are generated by music_emit (scr_music); sfx_update runs it every frame.

; ---------------------------------------------------------------------
dir_dx: .byte 0,1,1,1,0,255,255,255,0
dir_dy: .byte 255,255,0,1,1,1,0,255,0
sine_t: .byte 0,1,1,1,1,1,0,0,0,255,255,255,255,255,0,0
; aim lookup [ydir*4 + xdir]  x:0 same 1 right 2 left  y:0 same 1 up 2 down
aim_t:  .byte 4,2,6,4, 0,1,7,0, 4,3,5,4
ymap_t: .byte 0,2,1
bit_t:  .byte 1,2,4,8,16,32,64,128
scr_lo:
    .byte <(SCR+0),<(SCR+40),<(SCR+80),<(SCR+120),<(SCR+160),<(SCR+200),<(SCR+240),<(SCR+280),<(SCR+320),<(SCR+360),<(SCR+400),<(SCR+440),<(SCR+480)
    .byte <(SCR+520),<(SCR+560),<(SCR+600),<(SCR+640),<(SCR+680),<(SCR+720),<(SCR+760),<(SCR+800),<(SCR+840),<(SCR+880),<(SCR+920),<(SCR+960)
scr_hi:
    .byte >(SCR+0),>(SCR+40),>(SCR+80),>(SCR+120),>(SCR+160),>(SCR+200),>(SCR+240),>(SCR+280),>(SCR+320),>(SCR+360),>(SCR+400),>(SCR+440),>(SCR+480)
    .byte >(SCR+520),>(SCR+560),>(SCR+600),>(SCR+640),>(SCR+680),>(SCR+720),>(SCR+760),>(SCR+800),>(SCR+840),>(SCR+880),>(SCR+920),>(SCR+960)

; ---------------------------------------------------------------------
vars:
score:     .fill 3,0
lives:     .fill 1,0
level:     .fill 1,0
game_state: .fill 1,0
fcount:    .fill 1,0
joy:       .fill 1,0
jump_held: .fill 1,0
fire_cd:   .fill 1,0
grid_mv:   .fill 1,0
map_w:     .fill 1,0
map_h:     .fill 1,0
need:      .fill 1,0
need_got:  .fill 1,0
nsp:       .fill 1,0
sp_ptr:    .fill 2,0
sp_scan:   .fill 1,0
view_x:    .fill 2,0
view_y:    .fill 2,0
vmax_x:    .fill 2,0
vmax_y:    .fill 2,0
view_tx:   .fill 1,0
view_ty:   .fill 1,0
sub_x:     .fill 1,0
sub_y:     .fill 1,0
fine_x:    .fill 1,0
fine_y:    .fill 1,0
dvx:       .fill 1,0
coarse:    .fill 1,0
moving:    .fill 1,0
fl_ox:     .fill 2,0
fl_oy:     .fill 2,0
end_t:     .fill 1,0
mv_cnt:    .fill 1,0
mv_d:      .fill 1,0
mv_y:      .fill 1,0
cv_x:      .fill 1,0
cv_y:      .fill 1,0
cv_tile:   .fill 1,0
cv_attr:   .fill 1,0
dvy:       .fill 1,0
pend:      .fill 1,0
new_d016:  .fill 1,0
new_d011:  .fill 1,0
disp_d016: .fill 1,0
disp_d011: .fill 1,0
dt_col:    .fill 1,0
cave_row:  .fill 1,0
cp_n:      .fill 1,0
cp_t:      .fill 1,0
cp_y:      .fill 1,0
sh_msb:    .fill 1,0
sh_en:     .fill 1,0
sh_mc:     .fill 1,0
sh_x:      .fill 8,0
sh_y:      .fill 8,0
sh_ptr:    .fill 8,0
e_kind:    .fill 8,0
e_type:    .fill 8,0
e_xlo:     .fill 8,0
e_xhi:     .fill 8,0
e_ylo:     .fill 8,0
e_yhi:     .fill 8,0
e_dir:     .fill 8,0
e_spd:     .fill 8,0
e_hp:      .fill 8,0
e_t:       .fill 8,0
e_ph:      .fill 8,0
e_vy:      .fill 8,0
e_spr:     .fill 8,0
e_col:     .fill 8,0
sp_state:  .fill 64,0
sp_left:   .fill 64,0
sp_timer:  .fill 64,0
maprow_lo: .fill 256,0
maprow_hi: .fill 256,0
