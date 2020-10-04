;
; DAS Trainer patch for NES NTSC Tetris. Adds these functions:
;
; 1. Visualizes the current DAS charge by changing the color of the background.
; Each possible DAS charge value is mapped to a color through a look up table in ROM.
; This makes it easy to customize the colors with a hex editor.
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

;
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
; SET_BACKGROUND_COLOR_BY_DAS_CHARGE
; ----------------------------------------------------------------------------


dasChargeColors:
;        .byte   $06,$06,$06,$06,$06,$06,$06,$06,$06,$06, $01,$01,$01,$01,$01,$01, $0a
;        .byte   $16,$16,$16,$16,$16,$16,$16,$16,$16,$16, $12,$12,$12,$12,$12,$12, $19
;        .byte   $26,$26,$26,$26,$26,$26,$26,$26,$26,$26, $21,$21,$21,$21,$21,$21, $2a
        .byte   $10,$10,$10,$10,$10,$10,$10,$10,$10,$10, $00,$00,$00,$00,$00,$00, $00

renderDasCharge:
        cpx #$00        ; only replace bg color if it is gray ($00 meaning normal), not if it is white ($30 meaning a tetris flash is happening)
        bne @skipRenderDasCharge
        ldy     autorepeatX
        ldx		dasChargeColors,y
@skipRenderDasCharge:
        stx     PPUDATA	; replaced code
        rts

; ----------------------------------------------------------------------------
; SWAP_TETRIMINO_TYPE
; ----------------------------------------------------------------------------

swapTetriminoTypeTable:
;        .byte  0,1,2,3,4,5,6 ; original behaviour
;        .byte  0,0,0,0,0,0,0 ; T only
;        .byte  1,1,1,1,1,1,1 ; J only
;        .byte  2,2,2,2,2,2,2 ; Z only
;        .byte  3,3,3,3,3,3,3 ; O only
;        .byte  4,4,4,4,4,4,4 ; S only
;        .byte  5,5,5,5,5,5,5 ; L only
        .byte  6,6,6,6,6,6,6 ; I only

swapTetriminoType:
        tax
        lda     swapTetriminoTypeTable,x
        ; replaced code
        tax
        lda     spawnTable,x
		;
        rts
