;
; DAS Trainer patch for NES NTSC Tetris. Adds these functions:
;
; Visualizes the current DAS charge by changing the color of the background.
; Each possible DAS charge value is mapped to a color through a look up table in ROM.
; This makes it easy to customize the colors with a hex editor.
; There are two sets of colors that can be switched between by pressing the select button.
;

.include "build/tetris.inc"
.include "ips.inc"

; ----------------------------------------------------------------------------
; MACROS
; ----------------------------------------------------------------------------

; inc 16 bits
.macro  inc16   addr,idx
.ifblank idx
        inc     addr
        bne     :+
        inc     addr+1
:
.else
        inc     addr,idx
        bne     :+
        inc     addr+1,idx
:
.endif
.endmacro

; put 16 bits from lut+2*A into dest
; clobbers: A, Y (both set to A<<1)
.macro  lut16   lut,dest
        asl     a
        tay
        lda     lut,y
        sta     dest
        lda     lut+1,y
        sta     dest+1
.endmacro

.segment "CODE"

; ----------------------------------------------------------------------------
; 16-BIT DIVISION (16-BIT DIVIDEND, DIVISOR, RESULT AND REMAINDER)
; https://codebase64.org/doku.php?id=base:16bit_division_16-bit_result
; ----------------------------------------------------------------------------

divisor = generalCounter        ;+1 used for hi-byte
dividend = tmp1                 ;+1 used for hi-byte
remainder = generalCounter3     ;+1 used for hi-byte
result = dividend               ;save memory by reusing divident to store the result

divide:
	lda #0	        ;preset remainder to 0
	sta remainder
	sta remainder+1
	ldx #16	        ;repeat for each bit: ...

@divloop:
	asl dividend	;dividend lb & hb*2, msb -> Carry
	rol dividend+1
	rol remainder	;remainder lb & hb * 2 + msb from carry
	rol remainder+1
	lda remainder
	sec
	sbc divisor	;substract divisor to see if it fits in
	tay	        ;lb result -> Y, for we may need it later
	lda remainder+1
	sbc divisor+1
	bcc @skip	;if carry=0 then divisor didn't fit in yet

	sta remainder+1	;else save substraction result as new remainder,
	sty remainder
	inc result	;and INCrement result cause divisor fit in 1 times

@skip:
	dex
	bne @divloop
	rts

; ----------------------------------------------------------------------------
; FUNCTIONS COPIED FROM TAUS.S
; ----------------------------------------------------------------------------

; Convert 10 bit binary number (max 999) to bcd. Double dabble algorithm.
; a:    (input) 2 high bits of binary number
;       (output) low byte
; tmp1: (input) 8 low bits of binary number
; tmp2: (output) high byte
binaryToBcd:
        ldy     #00
        sty     tmp2
.if 1
        ldy     #08
.else
        ; Uses 5 bytes to save 16 cycles
        asl     tmp1
        rol     a
        rol     tmp2
        ldy     #07
.endif

@while:
        tax
        and     #$0F
        cmp     #$05
        txa                     ; Does not change carry
        bcc     @tensDigit
        ; carry is set, so it will add +1
        adc     #$02
        tax
@tensDigit:
        cmp     #$50
        bcc     @shift
        clc
        adc     #$30
@shift:
        asl     tmp1
        rol     a
        rol     tmp2
        dey
        bne     @while

        rts

; Multiply 16 bit number by 100
; tmp1: (input)  LO
;       (output) LO
; tmp2: (input)  HI
;       (output) HI
multiplyBy100:
        asl     tmp1    ; input =<< 2
        rol     tmp2
        asl     tmp1
        rol     tmp2

        lda     tmp1    ; output = input
        ldx     tmp2

        asl     tmp1    ; input =<< 3
        rol     tmp2
        asl     tmp1
        rol     tmp2
        asl     tmp1
        rol     tmp2

        clc             ; output += input
        adc     tmp1
        tay
        txa
        adc     tmp2
        tax
        tya

        asl     tmp1    ; input =<< 1
        rol     tmp2

        clc             ; output += input
        adc     tmp1
        tay
        txa
        adc     tmp2

        sty     tmp1
        sta     tmp2
        rts

; ----------------------------------------------------------------------------
; MOD: SET BACKGROUND COLOR BY DAS CHARGE
; ----------------------------------------------------------------------------

.segment "LEGALSCREEN_BG"
        ips_segment     "LEGALSCREEN_BG",legal_screen_nametable,1121 ; $ADB8

; legal_screen_nametable
        .incbin "build/simpledastrainer_legal.nam.stripe"
        .byte   $FF

.segment "GAME_BG"
        ips_segment     "GAME_BG",game_nametable,1121 ; $BF3C

; game_nametable
        .incbin "build/simpledastrainer_game.nam.stripe"
        .byte   $FF

.segment "GAME_PALETTE"
        ips_segment     "GAME_PALETTE",game_palette+3,8 ; $ACF6

; default colors of stats labels to black
        .byte   $0F,$0F,$0F,$0F
        .byte   $0F,$0F,$0F,$0F

.segment "JMP_RENDER_PIECE_STAT_MOD"
        ips_segment     "JMP_RENDER_PIECE_STAT_MOD",render_mode_play_and_demo+360 ; $9656

; replaces "sta PPUADDR; lda statsByType+1,x; sta PPUDATA; lda statsByType,x"
        jmp     renderPieceStat_mod
        lda     statsByColor+1,x
        sta     PPUDATA
        lda     statsByColor,x

.segment "JMP_CALC_DAS_CHARGE_BG_COLOR_AND_STATS"
        ips_segment     "JMP_CALC_DAS_CHARGE_BG_COLOR_AND_STATS",gameModeState_vblankThenRunState2 ; $9E27

; replaces "lda #$02; sta gameModeState; jsr noop_disabledVramRowIncr"
        jmp     calcDasChargeBgColorAndStats
after_calcDasChargeBgColorAndStats:
        lda     #$02
        sta     gameModeState
        ; can drop jsr noop_disabledVramRowIncr because it is a noop

.segment "JMP_RENDER_DAS_CHARGE_BG_COLOR"
        ips_segment     "JMP_RENDER_DAS_CHARGE_BG_COLOR",render_mode_play_and_demo+426 ; $9698 / @setPaletteColor

; replaces "stx PPUDATA"
        jmp     renderDasChargeBgColor
after_renderDasChargeBgColor:

.segment "JMP_NEW_PIECE_MOD"
        ips_segment     "JMP_NEW_PIECE_MOD",playState_spawnNextTetrimino+83 ; $98E1 / onePlayerPieceSelection

; replaces "jsr chooseNextTetrimino"
        jmp     spawnNextTetrimino_mod
after_spawnNextTetrimino_mod:

.segment "TOGGLE_SHOW_DAS_CHARGE_BG_COLOR_WITH_SELECT_BUTTON"
        ips_segment     "TOGGLE_SHOW_DAS_CHARGE_BG_COLOR_WITH_SELECT_BUTTON",gameModeState_updateCountersAndNonPlayerState+30 ; $88A2

; replaces "lda displayNextPiece; eor #$01; sta displayNextPiece"
        lda     z:dontShowDasChargeBgColor
        eor     #$01
        sta     z:dontShowDasChargeBgColor

.segment "JMP_INIT_GAME_STATE"
        ips_segment     "JMP_INIT_GAME_STATE",gameModeState_initGameState+21 ; $86F1, after statsByType init so we can overwrite

; replaces "sta player1_tetriminoX; sta player2_tetriminoX"
        jmp initGameState_mod
        nop
after_initGameState_mod:

.segment "JMP_CHECK_SKIP_RENDER_STATS"
        ips_segment     "JMP_CHECK_SKIP_RENDER_STATS",$952A ; $952A

; replaces "jsr copyPlayfieldRowToVRAM"
        jmp     checkSkipRenderStats
after_checkSkipRenderStats:

.segment "CODE"
        ips_segment     "CODE",unreferenced_data1+$100,$637-$100

DASCHARGEVALUECOUNT = 17
STATSCOUNT = 7

.struct DasChargeColorProfile
        notInEntryDelay         .res ::DASCHARGEVALUECOUNT
        inEntryDelay            .res ::DASCHARGEVALUECOUNT
        missedEntryDelay        .res ::DASCHARGEVALUECOUNT
        statIndexToColor        .res ::STATSCOUNT
.endstruct

dasChargeColorProfile1:
        .byte   $86,$86,$86,$86,$86,$86,$86,$86,$86,$86, $a0,$a0,$90,$90,$80,$80, $2d
        .byte   $46,$46,$46,$46,$46,$46,$46,$46,$46,$46, $60,$60,$50,$50,$40,$40, $6d
        .byte   $68,$68,$68,$68,$68,$68,$68,$68,$68,$68, $a0,$a0,$90,$90,$80,$80, $2d
        .byte   $ff, $06, $28, $20, $10, $00, $2d
        .assert * - dasChargeColorProfile1 = .sizeof(DasChargeColorProfile), error, "Color profile has wrong size"
dasChargeColorProfile2:
        .byte   $10,$10,$10,$10,$10,$10,$10,$10,$10,$10, $00,$00,$00,$00,$00,$00, $00
        .byte   $16,$16,$16,$16,$16,$16,$16,$16,$16,$16, $1c,$1c,$1c,$1c,$1c,$1c, $19
        .byte   $28,$28,$28,$28,$28,$28,$28,$28,$28,$28, $00,$00,$00,$00,$00,$00, $00
        .byte   $ff, $16, $28, $10, $1c, $19, $00
        .assert * - dasChargeColorProfile2 = .sizeof(DasChargeColorProfile), error, "Color profile has wrong size"

dasChargeColorProfileLUT:
        .addr   dasChargeColorProfile1
        .addr   dasChargeColorProfile2

dasChargeColorProfile_statIndexToColorLUT:
        .addr   dasChargeColorProfile1+DasChargeColorProfile::statIndexToColor
        .addr   dasChargeColorProfile2+DasChargeColorProfile::statIndexToColor

dasChargeBgColor := spawnCount+1 ; $001B

missedEntryDelayTimer := spawnCount+2 ; $001C
missedEntryDelayButtonPressed := spawnCount+3 ; $001D

colorProfile := spawnCount+4 ; $001E
dontShowDasChargeBgColor := spawnCount+5 ; $001F

statsIncremented := verticalBlankingInterval - STATSCOUNT ; $002C, STATSCOUNT bytes - set to 1 when index associated color detected, to avoid incrementing statsCounters more than once per piece
statsCounters := $0780 ; STATSCOUNT*2 bytes - counts how many pieces has seen the index associated color
statsByColor := $03E0

; called for each new piece
resetStatsIncremented:
        lda     #0
        ldx     #STATSCOUNT-1
@loop:
        sta     statsIncremented,x
        dex
        bpl     @loop
        rts

; called for each new game
resetStatsCounters:
        ; zero out all stats counters
        lda     #0
        ldx     #(STATSCOUNT*2)-1
@loop:
        sta     statsCounters,x
        dex
        bpl     @loop
        ; except the first one which we set to 1
        inc     statsCounters
        ;jsr     updateAllStats not needed here because we do it every frame in patched gameModeState_vblankThenRunState2
        rts

; various mitigations to avoid nmi taking longer time than vblank
checkSkipRenderStats:
        lda     outOfDateRenderFlags
        and     #$02
        beq     @noRenderLevel
        ; we are rendering level - delay lines and score rendering by shifting them to a different location in outOfDateRenderFlags
        lda     outOfDateRenderFlags
        and     #$05 ; Bit 0-lines 2-score
        asl     a
        asl     a
        asl     a
        sta     tmp1
        lda     outOfDateRenderFlags
        and     #<~$05 ; Bit 0-lines 2-score
        ora     tmp1
        sta     outOfDateRenderFlags
        jmp     @skipDelayedOutOfDateRenderFlags
@noRenderLevel:
        ; we are _not_ rendering level, _un_delay lines and score rendering
        lda     outOfDateRenderFlags
        and     #$05<<3 ; Bit 3-lines 5-score
        beq     @skipDelayedOutOfDateRenderFlags ; speed optimization
        lsr     a
        lsr     a
        lsr     a
        sta     tmp1
        lda     outOfDateRenderFlags
        and     #<~($05<<3) ; Bit 3-lines 5-score
        ora     tmp1
        sta     outOfDateRenderFlags
@skipDelayedOutOfDateRenderFlags:
        ; skip rendering of stats if rendering anything else in outOfDateRenderFlags
        lda     outOfDateRenderFlags
        and     #<~$40
        bne     @disableRenderStats
        ; skip rendering of stats if copying playfield to vram
        ldy     vramRow
        cpy     #$20
        bne     @disableRenderStats
        ; stats rendering _not_ disabled so update stats labels palette
        jsr     updateStatsPalette
        jmp     @end
@disableRenderStats:
        sta     outOfDateRenderFlags
@end:
        jsr     copyPlayfieldRowToVRAM ; replaced code
        jmp     after_checkSkipRenderStats

initGameState_mod:
        ; replaced code
        sta     player1_tetriminoX
        sta     player2_tetriminoX
        ;
        lda     #0
        sta     missedEntryDelayTimer ; timer disabled for first piece
        sta     missedEntryDelayButtonPressed
        jsr     resetStatsIncremented
        jsr     resetStatsCounters
        jmp     after_initGameState_mod

; number of frames to check for missed left/right press after entry delay
; in practise seems to be -3 off, since 9 gives two lines on level 18 (level 18 has 3 frames per line)
MISSEDENTRYDELAYFRAMES = 9

; called for each new piece except the first one
spawnNextTetrimino_mod:
        jsr     resetStatsIncremented
        inc16   statsCounters
        ldy     #MISSEDENTRYDELAYFRAMES
        sty     missedEntryDelayTimer
        ldy     #0
        sty     missedEntryDelayButtonPressed
        jsr     chooseNextTetrimino     ; replaced code
        jmp     after_spawnNextTetrimino_mod

calcDasChargeBgColorAndStats:
        ; missed entry delay timer handling
        ldy     missedEntryDelayTimer
        dey
        bmi     @timerEnd
        sty     missedEntryDelayTimer
        ; still counting down
        ; check if left or right buttons pressed
        lda     heldButtons
        and     #$04
        bne     @timerEnd
        lda     newlyPressedButtons
        and     #$03
        beq     @timerEnd
        lda     #1
        sta     missedEntryDelayButtonPressed
        ; timer not needed any more
        lda     #0
        sta     missedEntryDelayTimer
@timerEnd:
        ; put address of current color profile in generalCounter and color subset in A
        lda     colorProfile
        lut16   dasChargeColorProfileLUT, generalCounter
        lda     #DasChargeColorProfile::notInEntryDelay
        ; we are in entry delay if playState is 2 to 8 inclusive
        ldy     playState
        cpy     #2
        bmi     @notInEntryDelay
        cpy     #9
        bpl     @notInEntryDelay
        ; in entry delay so load that color subset to A
        lda     #DasChargeColorProfile::inEntryDelay
        jmp     @missedEntryDelayButtonNotPressed
@notInEntryDelay:
        ; check if left or right button was pressed just after entry delay
        ldy     missedEntryDelayButtonPressed
        beq     @missedEntryDelayButtonNotPressed
        tay     ; save A
        lda     heldButtons
        and     #$03
        tax
        tya     ; restore A
        cpx     #0
        bne     @stillHeld
        ldy     #0
        sty     missedEntryDelayButtonPressed
        jmp     @missedEntryDelayButtonNotPressed
@stillHeld:
        ; just missed entry delay so load that color subset to A
        lda     #DasChargeColorProfile::missedEntryDelay
@missedEntryDelayButtonNotPressed:
        ; add das charge value to A
        clc
        adc     autorepeatX
        ; load color from selected index
        tay
        lda     (generalCounter),y
        sta     tmp1
        ; check if bg color should be updated only when left and right button is up (based on MSB of color value)
        bpl     @setBgColor
        lda     heldButtons
        and     #$03
        bne     @skipSetBgColor
@setBgColor:
        lda     tmp1
        and     #$3f
        sta     dasChargeBgColor ; save for renderDasChargeBgColor to read
@skipSetBgColor:
        ; stats
        ; check if statistic should be increased (based on bit 6 of color value)
        bit     tmp1
        bvc     @endStatsNoUpdate
        ; statIndexToColor table search, takes color to search for in tmp1
        lda     dasChargeBgColor
        sta     tmp1
        lda     colorProfile
        lut16   dasChargeColorProfile_statIndexToColorLUT, generalCounter ; put address of current color profile's statIndexToColor table in generalCounter
        ldy     #6
@loop:
        lda     (generalCounter),y
        cmp     tmp1
        beq     @done
        dey
        bpl     @loop
@done:
        ; statIndexToColor table search end, stat index or $ff in y with flags set accordingly
        bmi     @endStats ; color not found
        lda     statsIncremented,y
        bne     @endStats ; don't increase stat again until new piece
        lda     #1
        sta     statsIncremented,y
        ;
        tya
        asl     a
        tax
        inc16   statsCounters,x
@endStats:
        jsr     updateAllStats
@endStatsNoUpdate:
        jmp     after_calcDasChargeBgColorAndStats

renderDasChargeBgColor:
        lda     dontShowDasChargeBgColor
        bne     @setColor
        ; only replace bg color if it is gray ($00), not if it is white ($30 meaning a tetris flash is happening)
        cpx     #$00
        bne     @setColor
        ldx     dasChargeBgColor
@setColor:
        stx     PPUDATA ; replaced code
        jmp     after_renderDasChargeBgColor

; calc percentages, conv to bcd, request transfer to ppu
updateAllStats:
        ldx     #(STATSCOUNT-1)*2
@loop:
        txa ; save X
        pha ;
        jsr     updateStat
        pla ; restore X
        tax ;
        dex
        dex
        bpl     @loop
        rts

; in: x: index of stat * 2
updateStat:
        stx     generalCounter5 ; save X
        cpx     #0
        bne     @percent
        ; convert to bcd
        lda     statsCounters,x
        sta     tmp1
        lda     statsCounters+1,x
        jsr     binaryToBcd
        ldx     generalCounter5 ;restore X
        sta     statsByColor,x
        lda     tmp2
        sta     statsByColor+1,x
        jmp     @done
@percent:
        ; multiplyBy100
        lda     statsCounters,x
        sta     tmp1
        lda     statsCounters+1,x
        sta     tmp2
        jsr     multiplyBy100
        ; divide
        lda     statsCounters
        sta     divisor
        lda     statsCounters+1
        sta     divisor+1
        jsr     divide
        ; convert to bcd
        ;result low byte is tmp1
        lda     result+1
        jsr     binaryToBcd
        ldx     generalCounter5 ;restore X
        sta     statsByColor,x
        lda     tmp2
        sta     statsByColor+1,x
@done:
        lda     outOfDateRenderFlags
        ora     #$40
        sta     outOfDateRenderFlags
        rts

; @showStat path must not alter X
renderPieceStat_mod:
        sta     PPUADDR ; replaced code
        lda     colorProfile
        lut16   dasChargeColorProfile_statIndexToColorLUT, generalCounter ; put address of current color profile's statIndexToColor table in generalCounter
        ldy     tmpCurrentPiece ; stat line # (0-6)
        beq     @showStat ; always show the first stat (total piece count)
        lda     (generalCounter),y ; color assigned to stat line Y
        bmi     @hideStat ; branch if stat line has no color assigned (value $ff)
@showStat:
        jmp     render_mode_play_and_demo+363 ; $9659
@hideStat:
        ; tile pattern #$ff already in A (from statIndexToColor table lookup)
        sta     PPUDATA
        sta     PPUDATA
        sta     PPUDATA
        jmp     render_mode_play_and_demo+375 ; $9665

updateStatsPalette:
        lda     colorProfile
        lut16   dasChargeColorProfile_statIndexToColorLUT, generalCounter ; put address of current color profile's statIndexToColor table in generalCounter
        lda     #$3f
        sta     PPUADDR
        lda     #$01
        sta     PPUADDR
        ldy     #1
        jsr     @setPPUPaletteEntry
        jsr     @setPPUPaletteEntry
        jsr     @setPPUPaletteEntry
        lda     #$0f ; black
        sta     PPUDATA ; skip PPU unused palette entry
        jsr     @setPPUPaletteEntry
        jsr     @setPPUPaletteEntry
        jsr     @setPPUPaletteEntry
        rts

@setPPUPaletteEntry:
        lda     (generalCounter),y
        bpl     @weHaveAColor
        lda     #$0f ; black
@weHaveAColor:
        sta     PPUDATA
        iny
        rts
