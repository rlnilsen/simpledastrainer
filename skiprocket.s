;
; Mod that skips the rocket animation that shows when the score is 30000 or more
;

.include "ips.inc"
.include "build/tetris.inc"

.segment "SKIP_ROCKET"
        ips_segment     "SKIP_ROCKET",playState_updateGameOverCurtain+62 ; $9A4F

; Skip the rocket animation
        cmp     #$FF
