;
; Two-player Tetris Mod
;

; Normally player 1 uses palette 2 and 6 (zero indexed). The mod uses palettes
; 1/2 and 5/6, but has player 1 uses palette 1 so that we can just use the
; "current player" as the palette value.

; TODO:
; Allow player 2 to pause
; Save another RNG to let the behind player catch up.
; Fix background tetrimino pattern
; Demo can be two-player if second player presses start and then the system goes idle. But demo playing is broken in 2 player
; Allow toggling on garbage?
; Allow second player to disable next piece display (minor)

; Integrations:
; Have handicap support 2 players
; Any way to fit stats on screen? Seems like there's no room.
; No room for A/B-Type, high score

.include "build/tetris.inc"

.ifdef TOURNAMENT_MODE
.include "tournament.screenlayout.inc"
.include "tournament.romlayout.inc"
.endif

.segment "CHR"
        .incbin "build/tetris-CHR-00.chr"
        .incbin "build/twoplayer-CHR-01.chr"

.bss


.segment "GAMEBSS"

.ifndef TOURNAMENT_MODE
.res 1 ; must be at least size 1 to prevent init loop from breaking
.else
tetrisCount_P1:
        .res    1
tetrisCount_P2:
        .res    1
binaryLines_P1:
        .res    1
binaryLines_P2:
        .res    1
binaryLines_P1_HI:
        .res    1
binaryLines_P2_HI:
        .res    1
.endif

.code

initGameState_mod:
        .export initGameState_mod
        .import __GAMEBSS_SIZE__, __GAMEBSS_RUN__
        jsr     memset_page

        lda     #$00
        ldx     #<__GAMEBSS_SIZE__
@clearByte:
        sta     __GAMEBSS_RUN__-1,x
        dex
        bne     @clearByte

        .importzp personal_rng
        .importzp spawnID_
        .importzp spawnCount_
        .importzp player1_rng
        .importzp player1_spawnID_
        .importzp player1_spawnCount_
        .importzp player2_rng
        .importzp player2_spawnID_
        .importzp player2_spawnCount_
; FIXME. reuses the seed at beginning of game
        lda     rng_seed
        sta     personal_rng
        sta     player1_rng
        sta     player2_rng
        lda     rng_seed+1
        sta     personal_rng+1
        sta     player1_rng+1
        sta     player2_rng+1
        lda     spawnID_
        sta     player1_spawnID_
        sta     player2_spawnID_
        lda     spawnCount_
        sta     player1_spawnCount_
        sta     player2_spawnCount_

        ldx     #player1_rng
        ldy     #$02
        jsr     generateNextPseudorandomNumber
        ldx     #player1_rng
        ldy     #$02
        jsr     generateNextPseudorandomNumber
        ldx     #player2_rng
        ldy     #$02
        jsr     generateNextPseudorandomNumber
        ldx     #player2_rng
        ldy     #$02
        jsr     generateNextPseudorandomNumber

        rts

initGameBackground_mod:
        .export initGameBackground_mod
        lda     numberOfPlayers
        cmp     #$01
        bne     @twoPlayers
        jsr     bulkCopyToPpu
        .addr   game_nametable
        .import after_initGameBackground_mod_player1
        jmp     after_initGameBackground_mod_player1

@twoPlayers:
        jsr     copyRleNametableToPpu
        .addr   twoplayer_game_nametable
        .import after_initGameBackground_mod_player2
        jmp     after_initGameBackground_mod_player2

twoplayer_game_nametable:
.ifdef  TOURNAMENT_MODE
        .incbin "build/tournament.nam.rle"
.elseif .defined(NEXT_ON_TOP)
        .incbin "build/twoplayer_game_top.nam.rle"
.else
        .incbin "build/twoplayer_game.nam.rle"
.endif

copyRleNametableToPpu:
        jsr     copyAddrAtReturnAddressToTmp_incrReturnAddrBy2
        ldx     PPUSTATUS
        lda     #$20
        sta     PPUADDR
        lda     #$00
        sta     PPUADDR
        .import rleDecodeToPpu
        jmp     rleDecodeToPpu

renderPlay_mod:
        .export renderPlay_mod
        lda     numberOfPlayers
        cmp     #$02
        beq     @twoPlayers
        .import after_renderPlay_mod
        jmp     after_renderPlay_mod

@twoPlayers:
        ; Update level/palette on a different frame than score (and implicitly
        ; lines) is updated. This reduces the number of updates on the same
        ; frame to help squeeze updates within vsync. The wrong palette is not
        ; visible the first frame of the game in two-player because the game
        ; logic runs after rendering, so the first frame has no sprites. In
        ; one-player the statistics will have the wrong palette for an extra
        ; frame.
        lda     outOfDateRenderFlags
        eor     #$02
        and     #$06
        bne     @renderScore

.ifndef NEXT_ON_TOP
.ifndef TOURNAMENT_MODE
        lda     #$20
        sta     PPUADDR
        lda     #$EF
        sta     PPUADDR
.else
        lda     #>INGAME_LAYOUT_P1_LEVEL
        sta     PPUADDR
        lda     #<INGAME_LAYOUT_P1_LEVEL
        sta     PPUADDR
.endif
.else
        lda     #$21
        sta     PPUADDR
        lda     #$0F
        sta     PPUADDR
.endif

        ldx     player1_levelNumber
        lda     levelDisplayTable,x
        jsr     twoDigsToPPU
        jsr     updatePaletteForLevel

.ifndef NEXT_ON_TOP
.ifndef TOURNAMENT_MODE
        lda     #$22
        sta     PPUADDR
        lda     #$50
        sta     PPUADDR
.else
        lda     #>INGAME_LAYOUT_P2_LEVEL
        sta     PPUADDR
        lda     #<INGAME_LAYOUT_P2_LEVEL
        sta     PPUADDR
.endif
.else
        lda     #$21
        sta     PPUADDR
        lda     #$F0
        sta     PPUADDR
.endif

        ldx     player2_levelNumber
        lda     levelDisplayTable,x
        jsr     twoDigsToPPU
        ; updatePaletteForLevel_player2
        lda     player2_levelNumber
        ldy     #$08
        .import updatePaletteForLevel_postConf
        jsr     updatePaletteForLevel_postConf
        lda     outOfDateRenderFlags
        and     #$FD
        sta     outOfDateRenderFlags

.ifdef TOURNAMENT_MODE
        ;in tourmanent mode we try to reduce updates
        ;so we update only one set of numbers at once
        ;if we updated level, we just leave
        lda     #$00
        jmp     after_renderPlay_mod

.endif

@renderScore:
        lda     outOfDateRenderFlags
        and     #$04
        beq     @ret

.ifndef NEXT_ON_TOP
.ifndef TOURNAMENT_MODE
        lda     #$20
.else
        lda     #>INGAME_LAYOUT_P1_SCORE
.endif
.else
        lda     #$23
.endif
        sta     PPUADDR
.ifndef TOURNAMENT_MODE
        lda     #$66
.else
        lda     #<INGAME_LAYOUT_P1_SCORE
.endif
        sta     PPUADDR
        lda     player1_score+2
        jsr     twoDigsToPPU
        lda     player1_score+1
        jsr     twoDigsToPPU
        lda     player1_score
        jsr     twoDigsToPPU

.ifndef NEXT_ON_TOP
.ifndef TOURNAMENT_MODE
        lda     #$20
.else
        lda     #>INGAME_LAYOUT_P2_SCORE
.endif
.else
        lda     #$23
.endif
        sta     PPUADDR
.ifndef TOURNAMENT_MODE
        lda     #$78
.else
        lda     #<INGAME_LAYOUT_P2_SCORE
.endif
        sta     PPUADDR
        lda     player2_score+2
        jsr     twoDigsToPPU
        lda     player2_score+1
        jsr     twoDigsToPPU
        lda     player2_score
        jsr     twoDigsToPPU

        lda     outOfDateRenderFlags
        and     #$FB
        sta     outOfDateRenderFlags
.ifdef TOURNAMENT_MODE
        ;in tourmanent mode we try to reduce updates
        ;so we update only one set of numbers at once
        ;if we updated score, we just leave
        lda     #$00
        jmp     after_renderPlay_mod
@ret:
        ;we did no update so far, lets see if the
        ;tournament statistics need update
        jsr     updateTournamentRendering
.else
@ret:
 .endif
        lda     #$00
        jmp     after_renderPlay_mod

.import vramPlayfieldRowsHi
.import vramPlayfieldRowsLo
.define FASTROWTOVRAM 2
.if FASTROWTOVRAM = 1
; A faster implementation of copying to the VRAM, by 92 cycles (from 246
; cycles down to 154).
;
; An unmodified implementation of render_mode_play_and_demo, but with 2 players
; enabled, does not fit within a vsync because 8 rows are copied which totals
; 1968 cycles by itself. The optimization here brings it down to 1232 cycles
; which may still be tight but isn't too much more than the 984 cycles
; normally used for 1 player.
copyPlayfieldRowToVRAM_fast:
        .export copyPlayfieldRowToVRAM_fast
        ldx     vramRow
        cpx     #$15
        bmi     @skipRts
        rts
@skipRts:
        ldy     multBy10Table,x
        lda     vramPlayfieldRowsHi,x
        sta     PPUADDR
        lda     numberOfPlayers
        cmp     #$01
        beq     @onePlayer
        lda     playfieldAddr+1
        cmp     #$05
        beq     @playerTwo
        lda     vramPlayfieldRowsLo,x
        sec
        sbc     #$04
        sta     PPUADDR
        jmp     @copyRowForPlayer1

@playerTwo:
        lda     vramPlayfieldRowsLo,x
        clc
        adc     #$0E
        sta     PPUADDR
        .repeat 10,I
        lda     playfieldForSecondPlayer+I,y
        sta     PPUDATA
        .endrepeat
        jmp     @doneWithRow

@onePlayer:
        lda     vramPlayfieldRowsLo,x
        clc
        adc     #$06
        sta     PPUADDR
@copyRowForPlayer1:
        .repeat 10,I
        lda     playfield+I,y
        sta     PPUDATA
        .endrepeat
@doneWithRow:
        inc     vramRow
        lda     vramRow
        cmp     #$14
        bmi     @ret
        lda     #$20
        sta     vramRow
@ret:   rts

.elseif FASTROWTOVRAM = 2
; A batched implementation of copying playfield to the VRAM, saving 76 cycles
; compared to copying each row individually (from 635 cycles down to 559,
; including boilerplate in caller).
;
; reg x: (input/output) vramRow
; reg a: (input) 0=player 1, 1=player 2
;
copyPlayfieldRowToVRAM4:
        .export copyPlayfieldRowToVRAM4
        cpx     #$20
        bmi     @skipRts
        rts
@skipRts:
        sta     generalCounter3
        tay
        beq     @playerOne
;playerTwo:
        lda     #$0E
        sta     generalCounter2
        bne     @continueSetup

@playerOne:
        ldy     numberOfPlayers
        lda     @offsetTable-1,y
        sta     generalCounter2

@continueSetup:
        lda     #$04
        sta     generalCounter
; reg x: vramRow
; reg y: playfield offset for row
; generalCounter: loop counter
; generalCounter2: VRAM LO offset
; generalCounter3: 0=player 1, 1=player 2
@loop:
        lda     vramPlayfieldRowsHi,x
        sta     PPUADDR
        lda     vramPlayfieldRowsLo,x
        clc
        adc     generalCounter2
        sta     PPUADDR

        ldy     multBy10Table,x
        lda     generalCounter3
        bne     @playerTwoCopy
        .repeat 10,I
        lda     playfield+I,y
        sta     PPUDATA
        .endrepeat
        jmp     @nextIter
@playerTwoCopy:
        .repeat 10,I
        lda     playfieldForSecondPlayer+I,y
        sta     PPUDATA
        .endrepeat

@nextIter:
        inx
        cpx     #$14
        bpl     @doneWithAllRows
@vramInRange:
        dec     generalCounter
        beq     @ret
        jmp     @loop

@doneWithAllRows:
        ldx     #$20
@ret:
        rts

@offsetTable:
        .byte   $06,(-$04)&$FF
.endif

copyOamStagingToOam_mod:
        .export copyOamStagingToOam_mod
        lda     #$00
        sta     OAMADDR
        lda     #$02
        sta     OAMDMA
        .import after_copyOamStagingToOam_mod
        jmp     after_copyOamStagingToOam_mod

.segment "CODE2"

stageSpriteForNextPiece_player1_mod:
        .export stageSpriteForNextPiece_player1_mod
        lda     displayNextPiece
        bne     @ret
        lda     numberOfPlayers
        cmp     #$01
        bne     @twoPlayers
        lda     #$C8
        sta     spriteXOffset
        lda     #$77
        sta     spriteYOffset
        jmp     @stage
@twoPlayers:
.ifndef NEXT_ON_TOP
.ifndef TOURNAMENT_MODE
        lda     #$78
        sta     spriteXOffset
        lda     #$53
.else
        lda     #INGAME_LAYOUT_P1_PREVIEW_X
        sta     spriteXOffset
        lda     #INGAME_LAYOUT_P1_PREVIEW_Y
.endif
.else
        lda     #6*8
        sta     spriteXOffset
        lda     #3*8
.endif
        sta     spriteYOffset
@stage:
        .importzp player1_nextPiece
        ldx     player1_nextPiece
        lda     orientationToSpriteTable,x
        sta     spriteIndexInOamContentLookup

        jmp     loadSpriteIntoOamStaging

@ret:   rts

savePlayer2State_mod:
        .export savePlayer2State_mod
        jsr     savePlayer2State
        jsr     stageSpriteForNextPiece_player2

.if .NOT(.def(NEXT_ON_TOP) .OR .def(TOURNAMENT_MODE))
        ; Alternate draw order to flicker on conflict
        lda     frameCounter
        and     #$0F
        jsr     moveSpriteToEndOfOamStaging
        lda     frameCounter
        and     #$0F
        eor     #$08
        jsr     moveSpriteToEndOfOamStaging
.endif
.ifdef TOURNAMENT_MODE
        jmp     tournamentLeadCheck
.else
        rts
.endif

stageSpriteForNextPiece_player2:
        lda     displayNextPiece
        bne     @ret
.ifndef NEXT_ON_TOP
.ifndef TOURNAMENT_MODE
        lda     #$80
        sta     spriteXOffset
        lda     #$AB
.else
        lda     #INGAME_LAYOUT_P2_PREVIEW_X
        sta     spriteXOffset
        lda     #INGAME_LAYOUT_P2_PREVIEW_Y
.endif
.else
        lda     #24*8
        sta     spriteXOffset
        lda     #3*8
.endif
        sta     spriteYOffset
        .importzp player2_nextPiece
        ldx     player2_nextPiece
        lda     orientationToSpriteTable,x
        sta     spriteIndexInOamContentLookup
        jmp     loadSpriteIntoOamStaging_player2

@ret:   rts


loadSpriteIntoOamStaging_player2:
        lda     oamStagingLength
        sta     generalCounter3
        jsr     loadSpriteIntoOamStaging
        ldx     generalCounter3
@adjustSprite:
        inx
        inx
        inc     oamStaging,x
        inx
        inx
        cpx     oamStagingLength
        bne     @adjustSprite
        rts


.if .NOT(.def(NEXT_ON_TOP) .OR .def(TOURNAMENT_MODE))
; Move a sprite in oamStaging to end of oamStaging.
;
; reg a: sprite number in oamStaging to move
moveSpriteToEndOfOamStaging:
        asl     a
        asl     a
        tax
        ldy     oamStagingLength
        lda     #$04
        sta     generalCounter
@copySprite:
        lda     oamStaging,x
        sta     oamStaging,y
        lda     #$FF
        sta     oamStaging,x
        inx
        iny
        dec     generalCounter
        bne     @copySprite

        sty     oamStagingLength
        rts
.endif


pickRandomTetrimino_mod:
        .export pickRandomTetrimino_mod
        ldx     #personal_rng
        ldy     #$02
        jsr     generateNextPseudorandomNumber
        ldx     #personal_rng
        ldy     #$02
        jsr     generateNextPseudorandomNumber
        ldx     #personal_rng
        ldy     #$02
        jsr     generateNextPseudorandomNumber
        rts

gameMode_levelMenu_nametable_mod:
        .export gameMode_levelMenu_nametable_mod
        jsr     bulkCopyToPpu
        .addr   level_menu_nametable
        lda     numberOfPlayers
        cmp     #$01
        bne     @twoPlayers

        jsr     bulkCopyToPpu
        .addr   player2PressStartPatch
        jmp     @levelMenuInit

@twoPlayers:
        jsr     bulkCopyToPpu
        .addr   player1ActivePatch

@levelMenuInit:
        lda     player2_startLevel
@forceStartLevelToRange:
        sta     player2_startLevel
        sec
        sbc     #$0A
        bcs     @forceStartLevelToRange

        rts

gameMode_levelMenu_processPlayer1Navigation_processPlayer2:
        .export gameMode_levelMenu_processPlayer1Navigation_processPlayer2
        lda     newlyPressedButtons_player2
        cmp     #$10
        bne     @checkBPressed
        lda     numberOfPlayers
        cmp     #$01
        bne     @checkBPressed
        inc     numberOfPlayers
        lda     #$08
        sta     soundEffectSlot1Init
        jmp     gameMode_levelMenu
@checkBPressed:
        lda     newlyPressedButtons_player2
        cmp     #$40
        bne     @ret
        lda     numberOfPlayers
        cmp     #$02
        bne     @ret
        dec     numberOfPlayers
        lda     #$01
        sta     soundEffectSlot3Init
        jmp     gameMode_levelMenu
@ret:
        jsr     updateAudioWaitForNmiAndResetOamStaging
        jmp     gameMode_levelMenu_processPlayer1Navigation

player2PressStartPatch:
        .byte   $20,$A4,$18
        .byte   $FF,$FF,$FF,$FF,$FF
        .byte   $19,$02,$FF ; P2
        .byte   $19,$1B,$0E,$1C,$1C,$FF ; PRESS
        .byte   $1C,$1D,$0A,$1B,$1D,$52 ; START!
        .byte   $FF,$FF,$FF,$FF
        .byte   $FF
player1ActivePatch:
        .byte   $20,$A4,$18
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $19,$15,$0A,$22,$0E,$1B,$FF,$01
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF
player2ActivePatch:
        .byte   $20,$A4,$18
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $19,$15,$0A,$22,$0E,$1B,$FF,$02
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF

gameMode_levelMenu_processPlayer2Navigation:
        .export gameMode_levelMenu_processPlayer2Navigation
        lda     numberOfPlayers
        cmp     #$01
        bne     @twoPlayers
        inc     gameMode
        rts

@twoPlayers:
        jsr     updateAudioWaitForNmiAndDisablePpuRendering
        jsr     disableNmi
        jsr     bulkCopyToPpu
        .addr   player2ActivePatch
        jsr     waitForVBlankAndEnableNmi
        jsr     updateAudioWaitForNmiAndEnablePpuRendering

@afterPatch:
        lda     #$00
        sta     activePlayer
        lda     player2_startLevel
        sta     startLevel
        lda     player2_startHeight
        sta     startHeight
        lda     originalY
        sta     selectingLevelOrHeight
        lda     newlyPressedButtons_player2
        sta     newlyPressedButtons
        jsr     gameMode_levelMenu_handleLevelHeightNavigation
        lda     startLevel
        sta     player2_startLevel
        lda     startHeight
        sta     player2_startHeight
        lda     selectingLevelOrHeight
        sta     originalY
        lda     newlyPressedButtons_player2
        cmp     #$10
        bne     @checkBPressed
        lda     heldButtons_player2
        cmp     #$90
        bne     @startAndANotPressed
        lda     player2_startLevel
        clc
        adc     #$0A
        sta     player2_startLevel
@startAndANotPressed:
        lda     #$00
        sta     gameModeState
        lda     #$02
        sta     soundEffectSlot1Init
        inc     gameMode
        rts

@checkBPressed:
        lda     newlyPressedButtons_player2
        cmp     #$40
        bne     @doneProcessing
        lda     #$02
        sta     soundEffectSlot1Init
        jsr     updateAudioWaitForNmiAndResetOamStaging
        jmp     gameMode_levelMenu

@doneProcessing:
        jsr     updateAudioWaitForNmiAndResetOamStaging
        jmp     @afterPatch


gameModeState_handleGameOver_mod:
        .export gameModeState_handleGameOver_mod
        lda     numberOfPlayers
        cmp     #$01
        bne     @twoPlayers
        ldx     #$00 ; player score offset for handleHighScoreIfNecessary
        stx     tmp3
        jmp     gameModeState_handleGameOver

@twoPlayers:
        lda     player1_playState
        ora     player2_playState
        beq     @gameOver
        ; put known data in a, to avoid it from matching "cmp gameModeState" in
        ; @mainLoop. In 1 player mode, numberOfPlayers will be in a.
        lda     #$00
        inc     gameModeState
        rts

@gameOver:
        ldx     #$00 ; player score offset for handleHighScoreIfNecessary
        stx     tmp3
        jsr     handleHighScoreIfNecessary
        ldx     #player2_score-player1_score
        stx     tmp3
        jsr     handleHighScoreIfNecessary

        jmp     gameModeState_handleGameOver

highScoreEntryScreen_render:
        .export highScoreEntryScreen_render
        lda     numberOfPlayers
        cmp     #$01
        beq     @ret
        lda     tmp3
        bne     @player2
        jsr     bulkCopyToPpu
        .addr   player1ActivePatch
        jmp     @ret
@player2:
        jsr     bulkCopyToPpu
        .addr   player2ActivePatch

@ret:
        jsr     waitForVBlankAndEnableNmi
        rts

highScoreEntryScreen_get_player:
        .export highScoreEntryScreen_get_player
        jsr     loadSpriteIntoOamStaging
        ldx     tmp3
        beq     @ret
        ldx     #$01
@ret:
        rts

updateMusicSpeed_noBlockInRow_mod:
        .export updateMusicSpeed_noBlockInRow_mod
        tax
        and     activePlayer
        eor     allegro
        sta     allegro
        txa
        cmp     activePlayer
        rts

updateMusicSpeed_foundBlockInRow_mod:
        .export updateMusicSpeed_foundBlockInRow_mod
        tax
        ora     activePlayer
        sta     allegro
        txa
        cmp     #$00
        rts

playState_updateGameOverCurtain_curtainFinished_mod:
        .export playState_updateGameOverCurtain_curtainFinished_mod
        sta     playState

        lda     numberOfPlayers
        cmp     #$02
        bne     @ret

        ; playState has not yet been copied to player*_playState.
        ; If a player has already died, then this would make two.
        lda     player1_playState
        beq     @bothPlayersDead
        lda     player2_playState
        beq     @bothPlayersDead
        jmp     updateMusicSpeed_playerDied

@bothPlayersDead:
        ; Wait for a player to press start
        jsr     updateAudioWaitForNmiAndResetOamStaging
        lda     newlyPressedButtons_player1
        ora     newlyPressedButtons_player2
        and     #$10
        bne     @ret
        jmp     @bothPlayersDead
@ret:
        ; Prevent start button from counting as pause
        lda     #$00
        sta     newlyPressedButtons_player1
        sta     newlyPressedButtons_player2
        rts

updateMusicSpeed_playerDied:
        lda     allegro
        and     activePlayer
        eor     allegro
        sta     allegro
        bne     @fast

        ldx     musicType
        lda     musicSelectionTable,x
        jsr     setMusicTrack
        rts

@fast:
        lda     musicType
        clc
        adc     #$04
        tax
        lda     musicSelectionTable,x
        jsr     setMusicTrack
        rts

;--------------------------------------------------------------------
; Tournament Mode Mod - additional code
;--------------------------------------------------------------------
.ifdef  TOURNAMENT_MODE

;this is the update of stats for the tournament play mode
statsPerBlock_tournamentMode:
        .export statsPerBlock_tournamentMode
        tay
        lda     activePlayer
        clc
        adc     #DROUGHT_P1 - 1
        tax
        lda     tetriminoTypeFromOrientation,y
        cmp     #$06 ; i piece
        beq     @clearDrought
        lda     #1
        jsr     increaseBCDStatsToF9
        jmp     @rts
@clearDrought:
        lda     #$00
        sta     statsByType, x
@rts:
        ;request render update
        lda     tournamentRenderFlags-DROUGHT_P1, x
        ora     #tournamentRenderFlagsDrought
        sta     tournamentRenderFlags-DROUGHT_P1, x

        rts


statsPerLineClear_tournamentMode:
        .export statsPerLineClear_tournamentMode
        lda     completedLines
        cmp     #$00
        beq     @rts
        tay
        lda     activePlayer
        clc
        adc     #BURN_P1 - 1
        tax
        tya
        cmp     #$04
        beq     @clearBurn
        jsr     increaseBCDStatsToF9
        jmp     @updateLines
@clearBurn:
        lda     #$00
        sta     statsByType, x
        inc     tetrisCount_P1 - BURN_P1, x
        inc     tetrisCount_P1 - BURN_P1, x
@updateLines:
        lda     completedLines
        clc
        adc     binaryLines_P1 - BURN_P1, x
        sta     binaryLines_P1 - BURN_P1, x
        bcc     @dirtyRenderFlags
        inc     binaryLines_P1_HI - BURN_P1, x
@dirtyRenderFlags:
        ;request render update
        lda     tournamentRenderFlags-BURN_P1, x
        ora     #tournamentRenderFlagsBurn|tournamentRenderFlagsTetrisRate
        sta     tournamentRenderFlags-BURN_P1, x

        lda     binaryLines_P1 - BURN_P1, x
        sta     tmp1
        lda     binaryLines_P1_HI - BURN_P1, x
        lsr     a
        lda     tetrisCount_P1 - BURN_P1, x
        bcs     @halfresTetrisRate
        asl     a
        bcc     @calculateTetrisRate

@halfresTetrisRate:
        ror     tmp1

@calculateTetrisRate:
        jsr     calculateTetrisRateBCD
        lda     activePlayer
        tax
        lda     tmp2
        sta     statsByType + TRATE_P1 - 1, x

@rts:
        lda     #$00
        sta     completedLines
        inc     playState
        rts

;check who is in lead and what point difference is there
tournamentLeadCheck:
        lda     outOfDateRenderFlags
        and     #$04
        beq     @rts
        ;score needs update, so we also need to update lead
        lda     #$80
        ldx     player2_score+2
        cpx     player1_score+2
        bne     @calcResult
        ldx     player2_score+1
        cpx     player1_score+1
        bne     @calcResult
        ldx     player2_score
        cpx     player1_score
@calcResult:
        beq     @equal
        rol     a
@equal:
        cmp     statsByType + LEADERID
        beq     @calcLead
        sta     statsByType + LEADERID
        lda     tournamentRenderFlags
        ora     #tournamentRenderFlagsLeadArrow
        sta     tournamentRenderFlags
@calcLead:
        lda     #0
        ldx     statsByType + LEADERID
        beq    @player1InLead

        ;this should toggle between p1 and p2 score adress
        eor     #player2_score-player1_score
@player1InLead:
        ;start with lowest byte
        tax
        sec
        jsr     TournamentLeadSubstractInner
        jsr     TournamentLeadSubstractInner
        jsr     TournamentLeadSubstractInner
        lda     tournamentRenderFlags
        ora     #tournamentRenderFlagsLead
        sta     tournamentRenderFlags
@rts:
        rts

;this reads two BCD number which are part of the scores
;substracts them and puts result into the lead display
;it also prepares the next step of the calculation
;(inc x and set carry)
;x - player + offset of higher score
TournamentLeadSubstractInner:
        ldy     player1_score, x
        txa
        eor     #player2_score-player1_score
        tax
        tya
        sbc     player1_score, x
        bcs     @noCarry
        sbc     #$5f
        clc
@noCarry:
        ror     tmp3
        sta     tmp1
        and     #$0f
        sta     tmp2
        tya
        and     #$0f
        cmp     tmp2
        bcs     @noCarryOnes
        lda     tmp1
        sbc     #$05
        sta     tmp1
@noCarryOnes:
        txa
        eor     #player2_score-player1_score
        tax
        and     #player2_score-player1_score-1
        tay
        lda     tmp1
        sta     statsByType + SCORELEAD, y
        inx
        rol     tmp3
        rts

;increases a bcd value, but the first value can increase to F
;the value will go up to F9 and then stop increasing
;the number to add is stored in a
;the adress is stored in x relative to the begin of statsByType

;warning, this can fail for certain numbers, e.g. 8 + 9 = 11
;should be save for all digits 6 and smaller
increaseBCDStatsToF9:
        clc
        adc     statsByType, x
        bcs     @overflow

        sta     statsByType, x
        and     #$0f
        cmp     #10
        bmi     @rts
        lda     statsByType, x
        clc
        adc     #6
        bcc     @writeA
@overflow:
        lda     #$F9
@writeA:
        sta     statsByType, x
@rts:
        rts

;renders the special tournament statistics to screen
;to save some time it does only update a single number per update
updateTournamentRendering:
@leadArrow:
        lda     tournamentRenderFlags
        and     #tournamentRenderFlagsLeadArrow
        beq     @leadScore
        lda     tournamentRenderFlags
        and     #$ff^tournamentRenderFlagsLeadArrow
        sta     tournamentRenderFlags
@leadArrowWrite:
        lda     #>INGAME_LAYOUT_P1_ARROW
        sta     PPUADDR
        lda     #<INGAME_LAYOUT_P1_ARROW
        sta     PPUADDR
        ldy     #$ff
        lda     statsByType + LEADERID
        bne     @firstEmpty
        ldx     #INGAME_LAYOUT_CHARID_ARROWS
        stx     PPUDATA
        inx
        stx     PPUDATA
        bpl     @midEmpty
@firstEmpty:
        sty     PPUDATA
        sty     PPUDATA
@midEmpty:
        sty     PPUDATA
        sty     PPUDATA
@midwritten:
        cmp     #1
        bne     @lastEmpty
        ldx     #INGAME_LAYOUT_CHARID_ARROWS+2
        stx     PPUDATA
        inx
        stx     PPUDATA
        rts
@lastEmpty:
        sty     PPUDATA
        sty     PPUDATA
        rts
@leadScore:
        lda     tournamentRenderFlags
        and     #tournamentRenderFlagsLead
        beq     @trtP1
        lda     tournamentRenderFlags
        and     #$ff^tournamentRenderFlagsLead
        sta     tournamentRenderFlags
@leadScoreWrite:
        lda     #>INGAME_LAYOUT_LEAD
        sta     PPUADDR
        lda     #<INGAME_LAYOUT_LEAD
        sta     PPUADDR
        lda     statsByType + SCORELEAD + 2
        jsr     twoDigsToPPU
        lda     statsByType + SCORELEAD + 1
        jsr     twoDigsToPPU
        lda     statsByType + SCORELEAD + 0
        jmp     twoDigsToPPU

@trtP1:
        lda     tournamentRenderFlags
        and     #tournamentRenderFlagsTetrisRate
        beq     @trtP2
        lda     tournamentRenderFlags
        and     #$ff^tournamentRenderFlagsTetrisRate
        sta     tournamentRenderFlags
@trtP1Write:
        lda     #>INGAME_LAYOUT_P1_TRT
        sta     PPUADDR
        lda     #<INGAME_LAYOUT_P1_TRT
        sta     PPUADDR
        lda     statsByType + TRATE_P1
        cmp     #$A0
        beq     @write100
        jmp     twoDigsToPPU
@write100:
        ldx     #INGAME_LAYOUT_CHARID_HUNDRED
        stx     PPUDATA
        inx
        stx     PPUDATA
        rts
@trtP2:
        lda     tournamentRenderFlags + 1
        and     #tournamentRenderFlagsTetrisRate
        beq     @burnP1
        lda     tournamentRenderFlags + 1
        and     #$ff^tournamentRenderFlagsTetrisRate
        sta     tournamentRenderFlags + 1
@trtP2Write:
        lda     #>INGAME_LAYOUT_P2_TRT
        sta     PPUADDR
        lda     #<INGAME_LAYOUT_P2_TRT
        sta     PPUADDR
        lda     statsByType + TRATE_P2
        cmp     #$A0
        beq     @write100
        jmp     twoDigsToPPU
@burnP1:
        lda     tournamentRenderFlags
        and     #tournamentRenderFlagsBurn
        beq     @burnP2
        lda     tournamentRenderFlags
        and     #$ff^tournamentRenderFlagsBurn
        sta     tournamentRenderFlags
@burnP1Write:
        lda     #>INGAME_LAYOUT_P1_BURN
        sta     PPUADDR
        lda     #<INGAME_LAYOUT_P1_BURN
        sta     PPUADDR
        lda     statsByType + BURN_P1
        jmp     twoDigsToPPU
@burnP2:
        lda     tournamentRenderFlags + 1
        and     #tournamentRenderFlagsBurn
        beq     @droughtP1
        lda     tournamentRenderFlags + 1
        and     #$ff^tournamentRenderFlagsBurn
        sta     tournamentRenderFlags + 1
@burnP2Write:
        lda     #>INGAME_LAYOUT_P2_BURN
        sta     PPUADDR
        lda     #<INGAME_LAYOUT_P2_BURN
        sta     PPUADDR
        lda     statsByType + BURN_P2
        jmp     twoDigsToPPU
@droughtP1:
        lda     tournamentRenderFlags
        and     #tournamentRenderFlagsDrought
        beq     @droughtP2
        lda     tournamentRenderFlags
        and     #$ff^tournamentRenderFlagsDrought
        sta     tournamentRenderFlags
@droughtP1Write:
        lda     #>INGAME_LAYOUT_P1_DROUGHT
        sta     PPUADDR
        lda     #<INGAME_LAYOUT_P1_DROUGHT
        sta     PPUADDR
        lda     statsByType + DROUGHT_P1
        jmp     twoDigsToPPU
@droughtP2:
        lda     tournamentRenderFlags + 1
        and     #tournamentRenderFlagsDrought
        beq     @end
        lda     tournamentRenderFlags + 1
        and     #$ff^tournamentRenderFlagsDrought
        sta     tournamentRenderFlags + 1
@droughtP2Write:
        lda     #>INGAME_LAYOUT_P2_DROUGHT
        sta     PPUADDR
        lda     #<INGAME_LAYOUT_P2_DROUGHT
        sta     PPUADDR
        lda     statsByType + DROUGHT_P2
        jmp     twoDigsToPPU
@end:
        rts

; calculate Tetris rate from two 8bit numbers and give BCD result
; its possible do to a low resolution calculation for high line counts
; by shifting a and tmp1 beforehand
; reg a: 4 times tetris count binary
; tmp1: line count binary
; tmp2: (out) result in BCD
calculateTetrisRateBCD:
        cmp     tmp1
        bcc     @below100Percent
        lda     #$a0
        sta     tmp2
        rts
@below100Percent:
        ldx     #0      ;multiply by 10
        stx     tmp3    ;{t2,t3} = 4 times tetris count
        sta     tmp2

        asl     tmp2    ;{t2,t3} =<< 2
        rol     tmp3
        asl     tmp2
        rol     tmp3

        clc             ;{a,t3} = {t2,t3} + {a,0}
        adc     tmp2
        bcc     @noCarryTen
        inc     tmp3
@noCarryTen:

        asl     a       ;{a,t3} =<< 1
        rol     tmp3

        tay             ;store the Tetris Count * 40 to {y,x}
        ldx     tmp3

        lda     #$ff    ;prepare output as -1
        sta     tournamentTmp4

;{y,x} now contains Tetris Count * 40
;we repeatly try to substract from this
;the result is the first numer of the BCD
@setSecTen:
        sec
@tenLoop:
        inc     tournamentTmp4

        tya
        sbc     tmp1
        tay
        bcs     @tenLoop
        dex
        bpl     @setSecTen

@fixRemainder:
        ldx     #0      ;{y,x} = {y+tmp1,0}
        tya
        clc
        adc     tmp1
        bne     @doOnes ;calculate one of BCD number
        sta     tournamentTmp5
        beq     @prepareResult
@doOnes:
        stx     tmp3    ;multiply by 10
        sta     tmp2    ;{t2,t3} = 4 times remaining tetris count

        asl     tmp2    ;{t2,t3} =<< 2
        rol     tmp3
        asl     tmp2
        rol     tmp3

        clc             ; {a,t3} = {t2,t3} + {a,0}
        adc     tmp2
        bcc     @noCarryOnes
        inc     tmp3
@noCarryOnes:

        asl     a       ;{a,t3} =<< 1
        rol     tmp3

        tay             ;store the remaining Tetris Count * 400 to {y,x}
        ldx     tmp3


        lda     #$ff    ; prepare output as -1
        sta     tournamentTmp5

@setSecOne:
        sec
@oneLoop:
        inc     tournamentTmp5

        tya
        sbc     tmp1
        tay
        bcs     @oneLoop
        dex
        bpl     @setSecOne

@prepareResult:
        lda     tournamentTmp4
        asl     a
        asl     a
        asl     a
        asl     a
        ora     tournamentTmp5
        sta     tmp2
        rts

.endif
