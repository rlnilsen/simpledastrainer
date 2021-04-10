.include "build/tetris.inc"
.include "ips.inc"

; ----------------------------------------------------------------------

.segment "XIHZ_DAS_CODE"
        ips_segment     "XIHZ_DAS_CODE",unreferenced_data4,$515

; ----------------------------------------------------------------------

.pushseg
.segment "SHIFT_TETRIMINO_MOD"
        ips_segment     "SHIFT_TETRIMINO_MOD",$89CC ; shift_tetrimino+?

; replaces "lda #$0A; sta autorepeatX"
        jmp     shift_tetrimino_mod
        nop
after_shift_tetrimino_mod:

.popseg

shift_tetrimino_mod:
        ; carry is always 1 here (set by cmp #$10 @ $89C8)
        lda     tetriminoX
        and     #$01
        adc     #9 ; really 10 but compensated for carry
        sta     autorepeatX
        jmp     after_shift_tetrimino_mod
        