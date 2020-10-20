;
; DAS Trainer patch for NES NTSC Tetris. Adds these functions:
;
; 1. Visualizes the current DAS charge by changing the color of the background.
; Each possible DAS charge value is mapped to a color through a look up table in ROM.
; This makes it easy to customize the colors with a hex editor.
; There are two sets of colors that can be switched between by pressing the select button.
;
; 2. Allows choosing which tetriminos to spawn.
; Each possible tetrimino type is mapped to any other through a look up table in ROM.
; This makes it easy to customize with a hex editor.
;

.include "build/tetris.inc"
.include "ips.inc"

; ----------------------------------------------------------------------------
; SET_BACKGROUND_COLOR_BY_DAS_CHARGE
; ----------------------------------------------------------------------------

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

; replaces "sta PPUADDR"
        jmp     renderPieceStat_mod

.segment "JMP_SET_BACKGROUND_COLOR_BY_DAS_CHARGE"
        ips_segment     "JMP_SET_BACKGROUND_COLOR_BY_DAS_CHARGE",render_mode_play_and_demo+426 ; $9698 / @setPaletteColor

; replaces "stx PPUDATA"
        jsr     renderDasCharge

.segment "ALWAYS_DISPLAY_NEXT_PIECE"
        ips_segment     "ALWAYS_DISPLAY_NEXT_PIECE",stageSpriteForNextPiece ; $8BCE

; replaces "lda displayNextPiece"
        lda     #0

.segment "JMP_SET_MISSED_ENTRY_DELAY_TIMER"
        ips_segment     "JMP_SET_MISSED_ENTRY_DELAY_TIMER",playState_spawnNextTetrimino+83 ; $98E1 / onePlayerPieceSelection

; replaces "jsr chooseNextTetrimino"
        jsr     setMissedEntryDelayTimer

.segment "DISABLE_PIECE_STATS"
        ips_segment     "DISABLE_PIECE_STATS",incrementPieceStat ; $9969

; replaces "tax"
       rts

.segment "JMP_INIT_GAME_STATE"
        ips_segment     "JMP_INIT_GAME_STATE",gameModeState_initGameState+21 ; $86F1, after statsByType init so we can overwrite

; replaces "sta player1_tetriminoX; sta player2_tetriminoX"
        jsr initGameState_mod
        nop

.segment "JMP_UPDATE_COLOR_STATS"
        ips_segment     "JMP_UPDATE_COLOR_STATS",gameModeState_vblankThenRunState2 ; $9E27

; replaces "lda #$02; sta gameModeState; jsr noop_disabledVramRowIncr"
        jsr     updateAllStats
        lda     #$02
        sta     gameModeState
        ; can drop jsr noop_disabledVramRowIncr because it is a noop

.segment "JMP_CHECK_SKIP_RENDER_STATS"
        ips_segment     "JMP_CHECK_SKIP_RENDER_STATS",$952A ; $952A

; replaces "jsr copyPlayfieldRowToVRAM"
        jsr     checkSkipRenderStats

; ----------------------------------------------------------------------------
; SWAP_TETRIMINO_TYPE
; ----------------------------------------------------------------------------

.segment "JMP_SWAP_TETRIMINO_TYPE_LOCATION_1"
        ips_segment     "JMP_SWAP_TETRIMINO_TYPE_LOCATION_1",pickRandomTetrimino+18 ; $9915

; replaces "tax; lda spawnTable,x"
        jsr     swapTetriminoType

.segment "JMP_SWAP_TETRIMINO_TYPE_LOCATION_2"
        ips_segment     "JMP_SWAP_TETRIMINO_TYPE_LOCATION_2",pickRandomTetrimino+49 ; $9934

; replaces "tax; lda spawnTable,x"
        jsr     swapTetriminoType

.segment "CODE2"
        ips_segment     "CODE2",unreferenced_data4,515

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

.segment "CODE"
        ips_segment     "CODE",unreferenced_data1,637

; ----------------------------------------------------------------------------
; SWAP_TETRIMINO_TYPE
; ----------------------------------------------------------------------------

swapTetriminoTypeTable:
        .byte  0,1,2,3,4,5,6 ; original behaviour
;        .byte  0,0,0,0,0,0,0 ; T only
;        .byte  1,1,1,1,1,1,1 ; J only
;        .byte  2,2,2,2,2,2,2 ; Z only
;        .byte  3,3,3,3,3,3,3 ; O only
;        .byte  4,4,4,4,4,4,4 ; S only
;        .byte  5,5,5,5,5,5,5 ; L only
;        .byte  6,6,6,6,6,6,6 ; I only

; ----------------------------------------------------------------------------
; SET_BACKGROUND_COLOR_BY_DAS_CHARGE
; ----------------------------------------------------------------------------

DASCHARGECOLORSUBSETSIZE = 17
DASCHARGECOLORSETSIZE = 3 * DASCHARGECOLORSUBSETSIZE

; each line contains 17 color values, one for each possible value of DAS charge (0-16)
dasChargeColorSet1:
        .byte   $10,$10,$10,$10,$10,$10,$10,$10,$10,$10, $00,$00,$00,$00,$00,$00, $00 ; subset used while not in entry delay
        .byte   $16,$16,$16,$16,$16,$16,$16,$16,$16,$16, $00,$00,$00,$00,$00,$00, $00 ; subset used during entry delay
        .byte   $28,$28,$28,$28,$28,$28,$28,$28,$28,$28, $00,$00,$00,$00,$00,$00, $00 ; subset used if just missed entry delay
        .assert * - dasChargeColorSet1 = DASCHARGECOLORSETSIZE, error, "Color set has wrong size"
dasChargeColorSet2:
        .byte   $10,$10,$10,$10,$10,$10,$10,$10,$10,$10, $00,$00,$00,$00,$00,$00, $00 ; subset used while not in entry delay
        .byte   $16,$16,$16,$16,$16,$16,$16,$16,$16,$16, $1c,$1c,$1c,$1c,$1c,$1c, $19 ; subset used during entry delay
        .byte   $28,$28,$28,$28,$28,$28,$28,$28,$28,$28, $00,$00,$00,$00,$00,$00, $00 ; subset used if just missed entry delay
        .assert * - dasChargeColorSet2 = DASCHARGECOLORSETSIZE, error, "Color set has wrong size"

statIndexToColor:
        .byte   $ff, $16, $28, $10, $ff, $1c, $19

; ----------------------------------------------------------------------------
; SET_BACKGROUND_COLOR_BY_DAS_CHARGE
; ----------------------------------------------------------------------------

missedEntryDelayTimer := spawnCount+1 ; $001B
missedEntryDelayButtonPressed := spawnCount+2 ; $001C

STATSCOUNT = 7
statsIncremented := spawnCount+3 ; $001D, STATSCOUNT bytes - set to 1 when index associated color detected, to avoid incrementing statsCounters more than once per piece
statsCounters := $0780 ; STATSCOUNT*2 bytes - counts how many pieces has seen the index associated color

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
        rts

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
        rts

; in: tmp1: color
; out: x: index or $ff if not found, flags n+z set by x
colorToStatIndex:
        ldx     #6
@loop:
        lda     statIndexToColor,x
        cmp     tmp1
        beq     @ret
        dex
        bpl     @loop
@ret:
        rts

; number of frames to check for missed left/right press after entry delay
; in practise seems to be -3 off, since 9 gives two lines on level 18 (level 18 has 3 frames per line)
MISSEDENTRYDELAYFRAMES = 9

; called for each new piece except the first one
setMissedEntryDelayTimer:
        jsr     resetStatsIncremented
        ; inc 16 bits
        inc     statsCounters
        bne     :+
        inc     statsCounters+1
:
        ldy     #MISSEDENTRYDELAYFRAMES
        sty     missedEntryDelayTimer
        ldy     #0
        sty     missedEntryDelayButtonPressed
        jsr     chooseNextTetrimino     ; replaced code
        rts

renderDasCharge:
        ; only replace bg color if it is gray ($00), not if it is white ($30 meaning a tetris flash is happening)
        cpx     #$00
        bne     @setColor

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

        ; select color set: load offset from dasChargeColorSet1 in A
        lda     #0
        ldy     displayNextPiece
        beq     @checkIfInEntryDelay
        lda     #DASCHARGECOLORSETSIZE
@checkIfInEntryDelay:
        ; we are in entry delay if playState is 2 to 8 inclusive
        ldy     playState
        cpy     #2
        bmi     @notInEntryDelay
        cpy     #9
        bpl     @notInEntryDelay
        ; in entry delay so switch to that color subset by adding to A
        clc
        adc     #DASCHARGECOLORSUBSETSIZE
        jmp     @missedEntryDelayButtonNotPressed
@notInEntryDelay:

        ; check if left or right button was pressed just after entry delay
        ldy     missedEntryDelayButtonPressed
        beq     @missedEntryDelayButtonNotPressed
        tay
        lda     heldButtons
        and     #$03
        tax
        tya
        cpx     #0
        bne     @stillHeld
        ldy     #0
        sty     missedEntryDelayButtonPressed
        jmp     @missedEntryDelayButtonNotPressed
@stillHeld:
        ; just missed entry delay so switch color subset by adding to A
        clc
        adc     #DASCHARGECOLORSUBSETSIZE
        adc     #DASCHARGECOLORSUBSETSIZE
@missedEntryDelayButtonNotPressed:

        ; add das charge value to A
        clc
        adc     autorepeatX

        ; load color from selected index
        tay
        ldx     dasChargeColorSet1,y
        
        ; stats
        stx     tmp3 ; save X
        stx     tmp1
        jsr     colorToStatIndex
        bmi     @endStats ; color not found
        lda     statsIncremented,x
        bne     @endStats ; don't increase stat again untul new piece
        lda     #1
        sta     statsIncremented,x
        ;
        txa
        asl     a
        tax
        ; inc 16 bits
        inc     statsCounters,x
        bne     :+
        inc     statsCounters+1,x
:
@endStats:
        ldx     tmp3 ; restore X

@setColor:
        stx     PPUDATA ; replaced code
        rts

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
        sta     statsByType,x
        lda     tmp2
        sta     statsByType+1,x
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
        sta     statsByType,x
        lda     tmp2
        sta     statsByType+1,x
@done:
        lda     outOfDateRenderFlags
        ora     #$40
        sta     outOfDateRenderFlags
        rts

renderPieceStat_mod:
        sta     PPUADDR ; replaced code
        ldy     tmpCurrentPiece
        beq     @showStat
        lda     statIndexToColor,y
        bmi     @hideStat
@showStat:
        jmp     render_mode_play_and_demo+363 ; $9659
@hideStat:
        ; tile pattern #$ff already in A (from statIndexToColor table lookup)
        sta     PPUDATA
        sta     PPUDATA
        sta     PPUDATA
        jmp     render_mode_play_and_demo+375 ; $9665

updateStatsPalette:
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
        lda     statIndexToColor,y
        bpl     @weHaveAColor
        lda     #$0f ; black
@weHaveAColor:
        sta     PPUDATA
        iny
        rts

; ----------------------------------------------------------------------------
; SWAP_TETRIMINO_TYPE
; ----------------------------------------------------------------------------

swapTetriminoType:
        tax
        lda     swapTetriminoTypeTable,x
        ; replaced code
        tax
        lda     spawnTable,x
        ;
        rts
