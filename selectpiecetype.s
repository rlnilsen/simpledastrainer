.include "build/tetris.inc"
.include "ips.inc"

; ----------------------------------------------------------------------

pieceType := spawnCount+24 ; 0=random, 1-7=T-I

; ----------------------------------------------------------------------

.segment "SELECT_PIECE_TYPE_CODE"
        ips_segment     "SELECT_PIECE_TYPE_CODE",unreferenced_data4,$515

; ----------------------------------------------------------------------

.pushseg
.segment "PICK_RANDOM_TETRIMINO_MOD"
        ips_segment     "PICK_RANDOM_TETRIMINO_MOD",pickRandomTetrimino ; $9903

; replaces "jsr @realStart"
        jmp     pickRandomTetrimino_mod
after_pickRandomTetrimino_mod:

.popseg

pickRandomTetrimino_mod:
        ldx     pieceType
        beq     @random
        dex
        lda     spawnTable,x
        ;sta     spawnId
        rts
@random:
        jsr     pickRandomTetrimino+4 ; replaced code
        jmp     after_pickRandomTetrimino_mod

; ----------------------------------------------------------------------

.pushseg
.segment "SELECT_PRESSED"
        ips_segment     "SELECT_PRESSED",gameModeState_updateCountersAndNonPlayerState+30 ; $88A2

; replaces "lda displayNextPiece; eor #$01; sta displayNextPiece"
        jmp     selectPressed
        nop
        nop
        nop
after_selectPressed:

.popseg

selectPressed:
        ; delay piece drop to allow user to focus on piece selection
        lda     #<-128+48 ; smallest negative value + slowest dropSpeed
        sta     player1_fallTimer
        ;
        ldx     pieceType
        inx
        cpx     #8
        bmi     @notRandomPiece
        ; random piece
        ldx     #0
        stx     pieceType
        ; make next piece random in stead of always I
        jsr     chooseNextTetrimino
        sta     nextPiece
        jmp     after_selectPressed
@notRandomPiece:
        stx     pieceType
        dex
        lda     spawnTable,x
        sta     nextPiece
        jmp     after_selectPressed

; ----------------------------------------------------------------------

.pushseg
.segment "RENDER_RANDOM_OR_SINGLE_PIECE_INDICATOR"
        ips_segment     "RENDER_RANDOM_OR_SINGLE_PIECE_INDICATOR",render_mode_play_and_demo ; $94EE

; replaces "lda player1_playState; cmp #$04"
        jmp     renderRandomOrSinglePieceIndicator
        nop
after_renderRandomOrSinglePieceIndicator:

.popseg

renderRandomOrSinglePieceIndicator:
        lda     #$22
        sta     PPUADDR
        lda     #$3B
        sta     PPUADDR
        lda     #$1B ; 'R'
        ldx     pieceType
        beq     :+
        lda     #$01 ; '1'
:
        sta     PPUDATA

        ; replaced code
        lda     player1_playState
        cmp     #$04

        jmp     after_renderRandomOrSinglePieceIndicator
