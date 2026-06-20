; PONGAUTO_REV4.ASM
; SC720 / Z80-Z180 + TMSEMU3 / TMS9918A
; Auto-playing Pong for the TMSAsmBuilder REV8 IDE.
;
; Build with the IDE/sjasmplus path, not CP/M ASM.COM.
;
; Result:
;   - black background
;   - white court, dashed net, score digits
;   - left paddle, right paddle, and half-size ball as TMS sprites
;   - self-playing Pong with scoring, games, and small anti-pattern nudges
;   - each game gets strong-but-not-perfect paddle/ball specs
;   - game counter runs 00000 through 99999, then resets
;   - only the paddle whose "turn" it is moves:
;       ball moving left  = left paddle moves
;       ball moving right = right paddle moves
;   - press any CP/M console key to exit
;
; Needed REV8 Libs:
;   include "tms.asm"
;   include "z180.asm"
;   include "utility.asm"

        org     100h

Start:
        ld      (OldSP),sp
        ld      sp,Stack

        ; Set safe TMS wait timing on fast Z180 systems.
        call    z180detect
        ld      e,0
        jp      nz,NoZ180
        call    z180getclk
NoZ180:
        call    TmsSetWait

        ; Find TMSEMU3 / TMS9918A.
        call    TmsProbe
        jp      z,NoTms

        ; Tile graphics mode with black background.
        call    TmsTile
        ld      a,TmsBlack
        call    TmsBackground

        ; Make every tile white-on-black.
        call    SetTileColors

        ; Load court/score tile patterns and sprite patterns.
        call    LoadTilePatterns
        call    LoadSpritePatterns

        ; 16x16 sprites, normal size.
        ld      a,TmsSprite32
        call    TmsSpriteConfig

        ; Draw the court once, score, game counter, and first game specs.
        call    DrawCourt
        call    DrawScores
        call    DrawGameCounter
        call    NewGameSpecs

        ; Initial ball.
        ld      a,2
        call    StartServe

MainLoop:
        call    WaitFrame

        ld      a,(FrameTick)
        inc     a
        ld      (FrameTick),a
        call    Rand8                   ; keep pseudo-random stream moving

        ; Only the active side tracks the ball.
        call    MovePaddles

        ; Short pause after each point.
        ld      a,(ScorePause)
        or      a
        jp      z,LiveBall
        dec     a
        ld      (ScorePause),a
        jp      DrawFrame

LiveBall:
        call    MoveBall

DrawFrame:
        call    WriteSprites

        call    keypress
        jp      z,MainLoop

Exit:
        call    HideSprites
        ld      sp,(OldSP)
        rst     0

NoTms:
        ld      de,NoTmsMsg
        call    strout
        ld      sp,(OldSP)
        rst     0

; ------------------------------------------------------------
; Wait for a clean vertical blank edge.
; This makes motion steady instead of running wild.

WaitFrame:
WaitNotV:
        call    TmsRegIn
        jp      m,WaitNotV
WaitV:
        call    TmsRegIn
        jp      p,WaitV
        ret

; ------------------------------------------------------------
; Tile setup.

SetTileColors:
        ld      de,(TmsColorAddr)
        ld      bc,TmsTileColorLen
        ld      a,0f1h                  ; white foreground, black background
        jp      TmsFill

LoadTilePatterns:
        ld      hl,TilePatterns
        ld      de,(TmsPatternAddr)
        ld      bc,TilePatternsEnd-TilePatterns
        jp      TmsWrite

LoadSpritePatterns:
        ld      hl,SpritePatterns
        ld      de,(TmsSpritePatternAddr)
        ld      bc,SpritePatternsEnd-SpritePatterns
        jp      TmsWrite

; ------------------------------------------------------------
; Draw court in the TMS name table.
; 32 columns x 24 rows.

DrawCourt:
        ; Clear the whole name table to blank tile 0.
        ld      de,(TmsNameAddr)
        ld      bc,TmsTileNameLen
        xor     a
        call    TmsFill

        ; Top border row.
        ld      de,(TmsNameAddr)
        ld      a,TileBorder
        call    FillNameRow

        ; Bottom border row.
        ld      hl,(TmsNameAddr)
        ld      de,736                  ; 23 * 32
        add     hl,de
        ex      de,hl
        ld      a,TileBorder
        call    FillNameRow

        ; Center dashed line, two tiles wide.
        ld      hl,(TmsNameAddr)
        ld      de,79                   ; row 2 * 32 + col 15
        add     hl,de
        ld      b,10
CenterLoop:
        push    bc
        push    hl
        ex      de,hl
        call    TmsWriteAddr
        ld      a,TileDash
        call    TmsRamOut
        ld      a,TileDash
        call    TmsRamOut
        pop     hl
        ld      de,64                   ; skip one row each dash
        add     hl,de
        pop     bc
        djnz    CenterLoop

        ret

; A = tile value, DE = start address, writes 32 tiles.
FillNameRow:
        push    af
        call    TmsWriteAddr
        pop     af
        ld      b,32
FillNameRowLoop:
        call    TmsRamOut
        djnz    FillNameRowLoop
        ret

DrawScores:
        ; Left score at row 1, col 12.
        ld      hl,(TmsNameAddr)
        ld      de,44                   ; row 1 * 32 + col 12
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      a,(LeftScore)
        add     a,DigitBase
        call    TmsRamOut

        ; Right score at row 1, col 19.
        ld      hl,(TmsNameAddr)
        ld      de,51                   ; row 1 * 32 + col 19
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      a,(RightScore)
        add     a,DigitBase
        call    TmsRamOut
        ret

; Draw bottom game counter as: GAMES 00000
; It is total completed games. 99999 rolls back to 00000.
DrawGameCounter:
        ld      hl,(TmsNameAddr)
        ld      de,714                  ; row 22 * 32 + col 10
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr

        ld      a,TileG
        call    TmsRamOut
        ld      a,TileA
        call    TmsRamOut
        ld      a,TileM
        call    TmsRamOut
        ld      a,TileE
        call    TmsRamOut
        ld      a,TileS
        call    TmsRamOut
        ld      a,TileBlank
        call    TmsRamOut

        ld      a,(Game10000)
        add     a,DigitBase
        call    TmsRamOut
        ld      a,(Game1000)
        add     a,DigitBase
        call    TmsRamOut
        ld      a,(Game100)
        add     a,DigitBase
        call    TmsRamOut
        ld      a,(Game10)
        add     a,DigitBase
        call    TmsRamOut
        ld      a,(Game1)
        add     a,DigitBase
        call    TmsRamOut
        ret

; ------------------------------------------------------------
; Sprite attributes: Y, X, pattern, color.
; Only 3 sprites are used to avoid TMS9918A per-scanline sprite trouble.

WriteSprites:
        ld      de,(TmsSpriteAttrAddr)
        call    TmsWriteAddr

        ; Ball first. The sprite cell is still 16x16, but the visible ball
        ; pattern is centered and only about 8x8 pixels.
        ld      a,(BallY)
        call    TmsRamOut
        ld      a,(BallX)
        call    TmsRamOut
        ld      a,BallPattern
        call    TmsRamOut
        ld      a,TmsWhite
        call    TmsRamOut

        ; Left paddle.
        ld      a,(LeftY)
        call    TmsRamOut
        ld      a,LeftX
        call    TmsRamOut
        ld      a,PaddlePattern
        call    TmsRamOut
        ld      a,TmsLightGreen
        call    TmsRamOut

        ; Right paddle.
        ld      a,(RightY)
        call    TmsRamOut
        ld      a,RightX
        call    TmsRamOut
        ld      a,PaddlePattern
        call    TmsRamOut
        ld      a,TmsLightBlue
        call    TmsRamOut

        ; End-of-sprite list.
        ld      a,208
        jp      TmsRamOut

HideSprites:
        ld      de,(TmsSpriteAttrAddr)
        call    TmsWriteAddr
        ld      a,208
        jp      TmsRamOut

; ------------------------------------------------------------
; Paddle AI.
; BallDX positive: right paddle moves.
; BallDX negative: left paddle moves.
; The inactive paddle stays still, so it really looks turn-based.
;
; Each game gives the players different specs:
;   Speed  = pixels moved per active AI update
;   React  = frames skipped between updates
;   Aim    = signed target offset, kept small so players are good, not dumb

MovePaddles:
        ld      a,(BallDX)
        cp      80h
        jp      nc,LeftTurnAI

RightTurnAI:
        ld      hl,RightDelay
        ld      a,(hl)
        or      a
        jp      z,RightAIAct
        dec     (hl)
        ret

RightAIAct:
        ld      a,(RightReact)
        ld      (RightDelay),a
        ld      a,(RightSpeed)
        ld      b,a
        ld      a,(RightAim)
        ld      c,a
        ld      a,(BallY)
        call    MakeTarget
        ld      hl,RightY
        jp      TrackPaddleVar

LeftTurnAI:
        ld      hl,LeftDelay
        ld      a,(hl)
        or      a
        jp      z,LeftAIAct
        dec     (hl)
        ret

LeftAIAct:
        ld      a,(LeftReact)
        ld      (LeftDelay),a
        ld      a,(LeftSpeed)
        ld      b,a
        ld      a,(LeftAim)
        ld      c,a
        ld      a,(BallY)
        call    MakeTarget
        ld      hl,LeftY
        jp      TrackPaddleVar

; A = ball Y, C = signed aim offset.
; Returns A = clamped target Y.
MakeTarget:
        ld      d,a                     ; original ball Y
        ld      a,c
        cp      80h
        jp      nc,TargetNegative

TargetPositive:
        ld      a,d
        add     a,c
        cp      BallYMax+1
        jp      c,TargetDone
        ld      a,BallYMax
        ret

TargetNegative:
        xor     a
        sub     c                       ; magnitude of negative offset
        ld      e,a
        ld      a,d
        cp      e
        jp      nc,TargetSubOk
        ld      a,BallYMin
        ret

TargetSubOk:
        sub     e
        cp      BallYMin
        jp      nc,TargetDone
        ld      a,BallYMin

TargetDone:
        ret

; A = target Y, B = speed, HL = paddle Y byte.
TrackPaddleVar:
        ld      d,a
        ld      a,(hl)
        cp      d
        ret     z
        jp      c,PaddleDownVar

PaddleUpVar:
        ld      a,(hl)
        sub     b
        cp      PaddleMin
        jp      nc,PaddleStoreVar
        ld      a,PaddleMin
        ld      (hl),a
        ret

PaddleDownVar:
        ld      a,(hl)
        add     a,b
        cp      PaddleMax+1
        jp      c,PaddleStoreVar
        ld      a,PaddleMax

PaddleStoreVar:
        ld      (hl),a
        ret

; ------------------------------------------------------------
; Ball movement, wall bounce, paddle bounce, and scoring.

MoveBall:
        call    MoveBallY
        call    MoveBallX

        ld      a,(BallDX)
        cp      80h
        jp      nc,CheckLeftPaddle
        jp      CheckRightPaddle

MoveBallY:
        ld      a,(BallY)
        ld      c,a
        ld      a,(BallDY)
        add     a,c
        ld      b,a                     ; new Y candidate

        ld      a,b
        cp      BallYMin
        jp      c,BallYUnder
        cp      BallYMax+1
        jp      c,StoreBallY

        ; Wrapped or went too far. Decide direction by DY sign.
        ld      a,(BallDY)
        cp      80h
        jp      nc,BallYUnder

BallYOver:
        ld      b,BallYMax
        call    FlipBallDY
        jp      StoreBallY

BallYUnder:
        ld      b,BallYMin
        call    FlipBallDY

StoreBallY:
        ld      a,b
        ld      (BallY),a
        ret

FlipBallDY:
        ld      a,(BallDY)
        ld      c,a
        xor     a
        sub     c
        ld      (BallDY),a
        ret

MoveBallX:
        ld      a,(BallX)
        ld      c,a
        ld      a,(BallDX)
        add     a,c
        ld      (BallX),a
        ret

CheckLeftPaddle:
        ; If X wrapped high, it missed the left side.
        ld      a,(BallX)
        cp      241
        jp      nc,PointRight

        ; Has the ball reached the left paddle plane?
        cp      LeftHitX+1
        ret     nc

        call    CheckLeftOverlap
        jp      nc,PointRight

        ; Bounce off left paddle.
        ld      a,LeftHitX+1
        ld      (BallX),a
        ld      a,(BallSpeed)
        ld      (BallDX),a
        ld      a,(LeftY)
        ld      c,a
        call    SetDYFromHit
        call    NudgeAfterHit
        ret

CheckRightPaddle:
        ld      a,(BallX)
        cp      RightHitX
        ret     c

        call    CheckRightOverlap
        jp      nc,PointLeft

        ; Bounce off right paddle.
        ld      a,RightHitX-1
        ld      (BallX),a
        ld      a,(BallSpeed)
        ld      c,a
        xor     a
        sub     c
        ld      (BallDX),a
        ld      a,(RightY)
        ld      c,a
        call    SetDYFromHit
        call    NudgeAfterHit
        ret

; Carry set = overlap.
CheckLeftOverlap:
        ld      a,(BallY)
        ld      b,a
        ld      a,(LeftY)
        ld      c,a
        ld      a,b
        sub     c                       ; BallY - PaddleY
        cp      16
        ret     c
        cp      241
        jp      nc,OverlapYes
        or      a                       ; clear carry
        ret

CheckRightOverlap:
        ld      a,(BallY)
        ld      b,a
        ld      a,(RightY)
        ld      c,a
        ld      a,b
        sub     c                       ; BallY - PaddleY
        cp      16
        ret     c
        cp      241
        jp      nc,OverlapYes
        or      a                       ; clear carry
        ret

OverlapYes:
        scf
        ret

; C = paddle Y.
; Ball hit position changes DY so the angle feels alive.
SetDYFromHit:
        ld      a,(BallY)
        sub     c                       ; BallY - PaddleY

        ; Ball is a little above paddle: sharp upward bounce.
        cp      128
        jp      nc,HitUpper

        cp      4
        jp      c,HitUpper
        cp      8
        jp      c,HitMidUpper
        cp      12
        jp      c,HitMidLower

HitLower:
        ld      a,2
        ld      (BallDY),a
        ret
HitMidLower:
        ld      a,1
        ld      (BallDY),a
        ret
HitMidUpper:
        ld      a,255                   ; -1
        ld      (BallDY),a
        ret
HitUpper:
        ld      a,254                   ; -2
        ld      (BallDY),a
        ret

; ------------------------------------------------------------
; Anti-pattern nudge.
;
; Because both paddles are computer-controlled, the ball can fall into
; a very repeatable loop. Every 8 paddle hits, gently force a new
; vertical angle. It is not random, so it works the same on every build,
; but it looks much more alive on screen.

NudgeAfterHit:
        ld      hl,RallyCount
        inc     (hl)

        ; Every 4 paddle hits, the ball may change practical speed.
        ; This is the main REV4 way to create exciting misses without
        ; making either player look bad.
        ld      a,(hl)
        and     3
        call    z,ChangeBallSpeedKeepDirection

        ; Every 8 paddle hits, force a small vertical nudge.
        ld      hl,RallyCount
        ld      a,(hl)
        and     7
        ret     nz

        ld      a,(hl)
        and     08h
        jp      z,NudgeUp

NudgeDown:
        ld      a,2
        ld      (BallDY),a
        ret

NudgeUp:
        ld      a,254                   ; -2
        ld      (BallDY),a
        ret

ChangeBallSpeedKeepDirection:
        call    Rand8
        and     7
        ld      hl,BallSpeedTable
        call    Table8
        ld      (BallSpeed),a
        ld      b,a
        ld      a,(BallDX)
        cp      80h
        jp      nc,ChangeBallSpeedLeft

ChangeBallSpeedRight:
        ld      a,b
        ld      (BallDX),a
        ret

ChangeBallSpeedLeft:
        xor     a
        sub     b
        ld      (BallDX),a
        ret

; ------------------------------------------------------------
; Scoring, game counter, pseudo-random strong-player specs, and serve reset.

PointLeft:
        call    IncLeftScore
        ld      a,2                     ; serve toward right
        call    StartServe
        ret

PointRight:
        call    IncRightScore
        ld      a,254                   ; serve toward left
        call    StartServe
        ret

IncLeftScore:
        ld      a,(LeftScore)
        inc     a
        ld      (LeftScore),a
        call    DrawScores
        ld      a,(LeftScore)
        cp      GamePoint
        ret     c
        call    GameWon
        ret

IncRightScore:
        ld      a,(RightScore)
        inc     a
        ld      (RightScore),a
        call    DrawScores
        ld      a,(RightScore)
        cp      GamePoint
        ret     c
        call    GameWon
        ret

; A game ends when either side reaches GamePoint.
; Then both point scores reset, a new game is counted, and new specs are made.
GameWon:
        call    IncGameCounter
        xor     a
        ld      (LeftScore),a
        ld      (RightScore),a
        call    DrawScores
        call    NewGameSpecs
        ret

IncGameCounter:
        ld      hl,Game1
        call    IncDecDigit
        jp      nc,GameCounterDone
        ld      hl,Game10
        call    IncDecDigit
        jp      nc,GameCounterDone
        ld      hl,Game100
        call    IncDecDigit
        jp      nc,GameCounterDone
        ld      hl,Game1000
        call    IncDecDigit
        jp      nc,GameCounterDone
        ld      hl,Game10000
        call    IncDecDigit
        ; carry after this means 99999 became 00000.

GameCounterDone:
        call    DrawGameCounter
        ret

; Increment decimal digit at (HL).
; Carry set = digit rolled from 9 to 0.
IncDecDigit:
        inc     (hl)
        ld      a,(hl)
        cp      10
        jp      c,IncDecNoCarry
        xor     a
        ld      (hl),a
        scf
        ret

IncDecNoCarry:
        or      a                       ; clear carry
        ret

; ------------------------------------------------------------
; Game spec generator.
; This is pseudo-random, not hardware random, so it is repeatable and safe.
; REV4 tuning: both players are usually excellent.  Misses mostly happen
; when ball speed climbs and one player has a tiny human-like imperfection.

NewGameSpecs:
        ; Reset reaction delays so new specs start immediately.
        xor     a
        ld      (LeftDelay),a
        ld      (RightDelay),a

        call    Rand8
        and     7
        ld      hl,SpeedTable
        call    Table8
        ld      (LeftSpeed),a

        call    Rand8
        and     7
        ld      hl,SpeedTable
        call    Table8
        ld      (RightSpeed),a

        call    Rand8
        and     7
        ld      hl,ReactTable
        call    Table8
        ld      (LeftReact),a

        call    Rand8
        and     7
        ld      hl,ReactTable
        call    Table8
        ld      (RightReact),a

        call    Rand8
        and     7
        ld      hl,AimTable
        call    Table8
        ld      (LeftAim),a

        call    Rand8
        and     7
        ld      hl,AimTable
        call    Table8
        ld      (RightAim),a

        call    Rand8
        and     7
        ld      hl,BallSpeedTable
        call    Table8
        ld      (BallSpeed),a

        ; Rarely put one or both players under mild pressure.
        ; Nobody is terrible now; this just keeps the match from being perfect.
        call    Rand8
        and     0fh
        cp      0
        jp      z,WeakLeft
        cp      1
        jp      z,WeakRight
        cp      2
        jp      z,WeakBoth
        ret

WeakBoth:
        call    WeakLeftCore
        jp      WeakRightCore

WeakLeft:
        jp      WeakLeftCore

WeakRight:
        jp      WeakRightCore

WeakLeftCore:
        ; Mild pro-level imperfection: still quick, just not perfect.
        ld      a,2
        ld      (LeftSpeed),a
        ld      a,1
        ld      (LeftReact),a
        call    Rand8
        and     1
        jp      z,WeakLeftAimUp
        ld      a,10
        ld      (LeftAim),a
        ret
WeakLeftAimUp:
        ld      a,0f6h                  ; -10
        ld      (LeftAim),a
        ret

WeakRightCore:
        ; Mild pro-level imperfection: still quick, just not perfect.
        ld      a,2
        ld      (RightSpeed),a
        ld      a,1
        ld      (RightReact),a
        call    Rand8
        and     1
        jp      z,WeakRightAimUp
        ld      a,10
        ld      (RightAim),a
        ret
WeakRightAimUp:
        ld      a,0f6h                  ; -10
        ld      (RightAim),a
        ret

; A = index 0..7, HL = table base, returns table byte in A.
Table8:
        ld      e,a
        ld      d,0
        add     hl,de
        ld      a,(hl)
        ret

; 8-bit Galois-style pseudo-random step.
Rand8:
        ld      a,(RandomSeed)
        rrca
        jp      nc,RandStore
        xor     0b8h
RandStore:
        ld      (RandomSeed),a
        ret

; A = desired serve direction. Positive serves right; negative serves left.
StartServe:
        cp      80h
        jp      nc,StartServeLeft

StartServeRight:
        ld      a,(BallSpeed)
        jp      StoreServeDX

StartServeLeft:
        ld      a,(BallSpeed)
        ld      c,a
        xor     a
        sub     c

StoreServeDX:
        ld      (BallDX),a
        ld      a,120
        ld      (BallX),a

        ; Use pseudo-random serve Y and angle so every point is less samey.
        call    Rand8
        and     3
        cp      0
        jp      z,ServeY0
        cp      1
        jp      z,ServeY1
        cp      2
        jp      z,ServeY2

ServeY3:
        ld      a,120
        ld      (BallY),a
        ld      a,2
        ld      (BallDY),a
        jp      ServeDone
ServeY2:
        ld      a,88
        ld      (BallY),a
        ld      a,254                   ; -2
        ld      (BallDY),a
        jp      ServeDone
ServeY1:
        ld      a,104
        ld      (BallY),a
        ld      a,1
        ld      (BallDY),a
        jp      ServeDone
ServeY0:
        ld      a,72
        ld      (BallY),a
        ld      a,255                   ; -1
        ld      (BallDY),a

ServeDone:
        xor     a
        ld      (RallyCount),a
        ld      a,ScorePauseFrames
        ld      (ScorePause),a
        ret

; ------------------------------------------------------------
; Constants.

TileBlank:          equ 0
TileDash:           equ 1
TileBorder:         equ 2
DigitBase:          equ 4
TileG:              equ 14
TileA:              equ 15
TileM:              equ 16
TileE:              equ 17
TileS:              equ 18

PaddlePattern:      equ 0
BallPattern:        equ 4

LeftX:              equ 16
RightX:             equ 224
LeftHitX:           equ 22
RightHitX:          equ 218

PaddleMin:          equ 16
PaddleMax:          equ 160
PaddleSpeed:        equ 2

BallYMin:           equ 8
BallYMax:           equ 176

ScorePauseFrames:   equ 28
GamePoint:          equ 9

; ------------------------------------------------------------
; Game state.

OldSP:          defw 0

LeftScore:      defb 0
RightScore:     defb 0
FrameTick:      defb 0
ScorePause:     defb 0
RallyCount:     defb 0

Game10000:      defb 0
Game1000:       defb 0
Game100:        defb 0
Game10:         defb 0
Game1:          defb 0

RandomSeed:     defb 0a7h

LeftSpeed:      defb 2
RightSpeed:     defb 2
LeftReact:      defb 0
RightReact:     defb 0
LeftDelay:      defb 0
RightDelay:     defb 0
LeftAim:        defb 0
RightAim:       defb 0
BallSpeed:      defb 2

LeftY:          defb 88
RightY:         defb 88

BallX:          defb 120
BallY:          defb 88
BallDX:         defb 2
BallDY:         defb 1

; Specs are strong now. Most games have sharp players with only tiny
; aim/reaction differences. Ball speed ranges from slow/practical to fast.
SpeedTable:     defb 2,2,3,3,2,3,3,2
ReactTable:     defb 0,0,0,1,0,1,0,1
AimTable:       defb 0,2,0feh,4,0fch,6,0fah,8
BallSpeedTable: defb 1,2,2,2,3,3,4,2

NoTmsMsg:
        defb    "TMSEMU3 / TMS9918A not found, aborting!$"

; ------------------------------------------------------------
; Tile patterns, 8 bytes each.
; Pattern 0 blank, 1 dashed net, 2 border, 4-13 digits 0-9, 14-18 GAMES.

TilePatterns:
        ; 0 blank
        defb    00h,00h,00h,00h,00h,00h,00h,00h

        ; 1 vertical net tile
        defb    18h,18h,18h,18h,18h,18h,18h,18h

        ; 2 horizontal border
        defb    00h,00h,0ffh,0ffh,0ffh,0ffh,00h,00h

        ; 3 unused spacer
        defb    00h,00h,00h,00h,00h,00h,00h,00h

        ; 4 digit 0
        defb    3ch,66h,6eh,76h,66h,66h,3ch,00h
        ; 5 digit 1
        defb    18h,38h,18h,18h,18h,18h,7eh,00h
        ; 6 digit 2
        defb    3ch,66h,06h,0ch,18h,30h,7eh,00h
        ; 7 digit 3
        defb    3ch,66h,06h,1ch,06h,66h,3ch,00h
        ; 8 digit 4
        defb    0ch,1ch,3ch,6ch,7eh,0ch,0ch,00h
        ; 9 digit 5
        defb    7eh,60h,7ch,06h,06h,66h,3ch,00h
        ; 10 digit 6
        defb    1ch,30h,60h,7ch,66h,66h,3ch,00h
        ; 11 digit 7
        defb    7eh,66h,06h,0ch,18h,18h,18h,00h
        ; 12 digit 8
        defb    3ch,66h,66h,3ch,66h,66h,3ch,00h
        ; 13 digit 9
        defb    3ch,66h,66h,3eh,06h,0ch,38h,00h

        ; 14 G
        defb    3eh,60h,60h,6eh,66h,66h,3eh,00h
        ; 15 A
        defb    18h,3ch,66h,66h,7eh,66h,66h,00h
        ; 16 M
        defb    63h,77h,7fh,6bh,63h,63h,63h,00h
        ; 17 E
        defb    7eh,60h,60h,7ch,60h,60h,7eh,00h
        ; 18 S
        defb    3eh,60h,60h,3ch,06h,06h,7ch,00h

TilePatternsEnd:

; ------------------------------------------------------------
; 16x16 sprite patterns.
; TMS 16x16 sprite order:
;   upper-left 8 bytes, lower-left 8, upper-right 8, lower-right 8.

SpritePatterns:
        ; Pattern 0: narrow 16x16 paddle, centered in sprite cell.
        ; upper-left
        defb    07h,07h,07h,07h,07h,07h,07h,07h
        ; lower-left
        defb    07h,07h,07h,07h,07h,07h,07h,07h
        ; upper-right
        defb    0e0h,0e0h,0e0h,0e0h,0e0h,0e0h,0e0h,0e0h
        ; lower-right
        defb    0e0h,0e0h,0e0h,0e0h,0e0h,0e0h,0e0h,0e0h

        ; Pattern 4: half-size centered round ball.
        ; The TMS is still in 16x16 sprite mode for the paddles,
        ; so this pattern draws only the middle 8x8 area.
        ; upper-left
        defb    00h,00h,00h,00h,00h,03h,07h,0fh
        ; lower-left
        defb    0fh,07h,03h,00h,00h,00h,00h,00h
        ; upper-right
        defb    00h,00h,00h,00h,00h,0c0h,0e0h,0f0h
        ; lower-right
        defb    0f0h,0e0h,0c0h,00h,00h,00h,00h,00h

SpritePatternsEnd:

; ------------------------------------------------------------
; Private program stack.
; SP is moved here while running, then restored before CP/M exit.

StackSpace:
        defs    256,0
Stack:

        include "tms.asm"
        include "z180.asm"
        include "utility.asm"

        end
