;
; DAS Trainer patch for NES NTSC Tetris.
;
; Visualizes the current DAS charge by changing the color of the background.
; Each possible DAS charge value is mapped to a color through a look up table in ROM.
; This makes it easy to customize the colors with a hex editor.
;

.include "build/tetris.inc"
.include "ips.inc"

.segment "JMP_SET_BACKGROUND_COLOR_BY_DAS_CHARGE"
        ips_segment     "JMP_SET_BACKGROUND_COLOR_BY_DAS_CHARGE",render_mode_play_and_demo+426 ; $9698 / @setPaletteColor

; replaces "stx PPUDATA"
        jsr     renderDasCharge

.segment "CODE"
        ips_segment     "CODE",unreferenced_data3

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
