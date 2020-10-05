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
        lda		#0

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

dasChargeColorSubsetSize = 17
dasChargeColorSetSize = 2 * dasChargeColorSubsetSize

; each line contains 17 color values, one for each possible value of DAS charge (0-16)
dasChargeColorSet1:
        .byte   $10,$10,$10,$10,$10,$10,$10,$10,$10,$10, $00,$00,$00,$00,$00,$00, $00 ; subset used while not in entry delay
        .byte   $17,$17,$17,$17,$17,$17,$17,$17,$17,$17, $1c,$1c,$1c,$1c,$1c,$1c, $19 ; subset used during entry delay
		.assert	* - dasChargeColorSet1 = dasChargeColorSetSize, error, "Color set has wrong size"
dasChargeColorSet2:
        .byte   $10,$10,$10,$10,$10,$10,$10,$10,$10,$10, $00,$00,$00,$00,$00,$00, $00 ; subset used while not in entry delay
        .byte   $17,$17,$17,$17,$17,$17,$17,$17,$17,$17, $00,$00,$00,$00,$00,$00, $00 ; subset used during entry delay
		.assert	* - dasChargeColorSet2 = dasChargeColorSetSize, error, "Color set has wrong size"

renderDasCharge:
		; only replace bg color if it is gray ($00), not if it is white ($30 meaning a tetris flash is happening)
        cpx     #$00
        bne     @setColor
		; select color set: load offset from dasChargeColorSet1 in a
		lda		#0
		ldy		displayNextPiece
		beq		@checkIfInEntryDelay
		lda 	#dasChargeColorSetSize
@checkIfInEntryDelay:
		; we are in entry delay if playState is 2 to 8 inclusive
		ldy		playState
		cpy		#2
		bmi		@notInEntryDelay
		cpy		#9
		bpl		@notInEntryDelay
		; in entry delay so switch to that color subset by adding to a
		clc
		adc		#dasChargeColorSubsetSize
@notInEntryDelay:
		; add das charge value to a
		clc
		adc		autorepeatX
		; load color from selected index
		tay
        ldx	    dasChargeColorSet1,y
@setColor:
        stx     PPUDATA	; replaced code
        rts

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

swapTetriminoType:
        tax
        lda     swapTetriminoTypeTable,x
        ; replaced code
        tax
        lda     spawnTable,x
		;
        rts
