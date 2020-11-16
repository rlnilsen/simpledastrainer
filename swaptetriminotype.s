;
; Patch for NES NTSC Tetris. Adds these functions:
;
; Allows choosing which tetriminos to spawn.
; Each possible tetrimino type is mapped to any other through a look up table in ROM.
; This makes it easy to customize with a hex editor.
;

.include "build/tetris.inc"
.include "ips.inc"

; ----------------------------------------------------------------------------
; MOD: SWAP TETRIMINO TYPE
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
        ips_segment     "CODE2",unreferenced_data4,$515

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
