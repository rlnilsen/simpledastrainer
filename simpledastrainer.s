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

.segment "CODE"
        ips_segment     "CODE",unreferenced_data1,515

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

dasChargeColorSubsetSize = 17
dasChargeColorSetSize = 3 * dasChargeColorSubsetSize

; each line contains 17 color values, one for each possible value of DAS charge (0-16)
dasChargeColorSet1:
        .byte   $10,$10,$10,$10,$10,$10,$10,$10,$10,$10, $00,$00,$00,$00,$00,$00, $00 ; subset used while not in entry delay
        .byte   $16,$16,$16,$16,$16,$16,$16,$16,$16,$16, $00,$00,$00,$00,$00,$00, $00 ; subset used during entry delay
        .byte   $28,$28,$28,$28,$28,$28,$28,$28,$28,$28, $00,$00,$00,$00,$00,$00, $00 ; subset used if just missed entry delay
        .assert * - dasChargeColorSet1 = dasChargeColorSetSize, error, "Color set has wrong size"
dasChargeColorSet2:
        .byte   $10,$10,$10,$10,$10,$10,$10,$10,$10,$10, $00,$00,$00,$00,$00,$00, $00 ; subset used while not in entry delay
        .byte   $16,$16,$16,$16,$16,$16,$16,$16,$16,$16, $1c,$1c,$1c,$1c,$1c,$1c, $19 ; subset used during entry delay
        .byte   $28,$28,$28,$28,$28,$28,$28,$28,$28,$28, $00,$00,$00,$00,$00,$00, $00 ; subset used if just missed entry delay
        .assert * - dasChargeColorSet2 = dasChargeColorSetSize, error, "Color set has wrong size"

; ----------------------------------------------------------------------------
; SET_BACKGROUND_COLOR_BY_DAS_CHARGE
; ----------------------------------------------------------------------------

missedEntryDelayTimer := spawnCount+1 ; $001B
missedEntryDelayButtonPressed := spawnCount+3 ; $001D

setMissedEntryDelayTimer:
        ldy     #9
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
        lda     #dasChargeColorSetSize
@checkIfInEntryDelay:
        ; we are in entry delay if playState is 2 to 8 inclusive
        ldy     playState
        cpy     #2
        bmi     @notInEntryDelay
        cpy     #9
        bpl     @notInEntryDelay
        ; in entry delay so switch to that color subset by adding to A
        clc
        adc     #dasChargeColorSubsetSize
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
        adc     #dasChargeColorSubsetSize
        adc     #dasChargeColorSubsetSize
@missedEntryDelayButtonNotPressed:

        ; add das charge value to A
        clc
        adc     autorepeatX

        ; load color from selected index
        tay
        ldx         dasChargeColorSet1,y

@setColor:
        stx     PPUDATA ; replaced code
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
