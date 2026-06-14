; PONGAUTO_REV13.ASM
; SC720 / Z80-Z180 + TMSEMU3 / TMS9918A
; Auto-playing Pong for the TMSAsmBuilder REV8 IDE.
; REV13: much stronger paddle AI with panic-save mode and no target overshoot.
;
; Build with the IDE/sjasmplus path, not CP/M ASM.COM.
;
; Result:
;   - black background
;   - black background with a bright-white chrome arcade border, colored text, dashed net, score digits
;   - matching bright-white left/right paddles, red half-size ball, and red trail as TMS sprites
;   - self-playing Pong with stronger prediction AI, panic-save defense, paddle-motion spin, balanced pro specs, and a ball trail
;   - each game gets fast strong-but-not-perfect balanced paddle/ball specs, safer trick aim, and no dumb missed balls
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

        ; Load tile color groups.  Bright-white border, colored text, and net.
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
        ld      hl,TileColorTable
        ld      de,(TmsColorAddr)
        ld      bc,TmsTileColorLen
        jp      TmsWrite

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

        ; Top border row: corner, 30 horizontal rail tiles, corner.
        ld      de,(TmsNameAddr)
        call    DrawBorderRow

        ; Bottom border row.
        ld      hl,(TmsNameAddr)
        ld      de,736                  ; 23 * 32
        add     hl,de
        ex      de,hl
        call    DrawBorderRow

        ; Left and right vertical border columns, rows 1 through 22.
        ; The score is now down on row 2, leaving breathing room under the top border.
        ld      hl,(TmsNameAddr)
        ld      de,32                   ; row 1 * 32
        add     hl,de
        ld      b,22
SideBorderLoop:
        push    bc
        push    hl

        ; Left side, column 0.
        ex      de,hl
        call    TmsWriteAddr
        ld      a,TileLeftVBorder
        call    TmsRamOut

        ; Right side, column 31.
        pop     hl
        push    hl
        ld      de,31
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      a,TileRightVBorder
        call    TmsRamOut

        ; Next row.
        pop     hl
        ld      de,32
        add     hl,de
        pop     bc
        djnz    SideBorderLoop

        ; Center dashed line, two tiles wide.
        ; Starts lower now so it does not crowd the top score.
        ld      hl,(TmsNameAddr)
        ld      de,111                  ; row 3 * 32 + col 15
        add     hl,de
        ld      b,9
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

; DE = row start address.  Draws a clean bright-white chrome arcade border row.
; Both halves are now the same color so the court feels balanced.
DrawBorderRow:
        call    TmsWriteAddr
        ld      a,TileLeftCorner
        call    TmsRamOut
        ld      a,TileLeftHBorder
        ld      b,15
DrawLeftBorderRowLoop:
        call    TmsRamOut
        djnz    DrawLeftBorderRowLoop
        ld      a,TileRightHBorder
        ld      b,15
DrawRightBorderRowLoop:
        call    TmsRamOut
        djnz    DrawRightBorderRowLoop
        ld      a,TileRightCorner
        jp      TmsRamOut

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
        ; Left score at row 2, col 12.
        ; This is one row lower than REV5 so it does not crowd the top border.
        ld      hl,(TmsNameAddr)
        ld      de,76                   ; row 2 * 32 + col 12
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      a,(LeftScore)
        add     a,DigitBase
        call    TmsRamOut

        ; Right score at row 2, col 19.
        ld      hl,(TmsNameAddr)
        ld      de,83                   ; row 2 * 32 + col 19
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
; Four sprites are used: ball, one ball trail, and two paddles.
; This stays within the TMS9918A four-sprites-per-scanline limit.

WriteSprites:
        ld      de,(TmsSpriteAttrAddr)
        call    TmsWriteAddr

        ; Ball first so it has priority over the trail.
        ; The sprite cell is still 16x16, but the visible ball is about 8x8.
        ld      a,(BallY)
        call    TmsRamOut
        ld      a,(BallX)
        call    TmsRamOut
        ld      a,BallPattern
        call    TmsRamOut
        ld      a,9                     ; TMS light red
        call    TmsRamOut

        ; One-frame trail, medium red.
        ; Only one trail sprite is used so the TMS four-sprites-per-scanline rule stays safe.
        ld      a,(TrailY)
        call    TmsRamOut
        ld      a,(TrailX)
        call    TmsRamOut
        ld      a,BallPattern
        call    TmsRamOut
        ld      a,8                     ; TMS medium red
        call    TmsRamOut

        ; Left paddle, bright white.
        ld      a,(LeftY)
        call    TmsRamOut
        ld      a,LeftX
        call    TmsRamOut
        ld      a,PaddlePattern
        call    TmsRamOut
        ld      a,15                    ; TMS white
        call    TmsRamOut

        ; Right paddle, bright white.
        ld      a,(RightY)
        call    TmsRamOut
        ld      a,RightX
        call    TmsRamOut
        ld      a,PaddlePattern
        call    TmsRamOut
        ld      a,15                    ; TMS white
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
; REV13: stronger pro paddle AI.
;
; The old players could look dumb because the paddle target could overshoot
; and jitter around the correct spot.  REV13 fixes that with snap-to-target
; movement, safer aim tables, and a panic-save mode near the paddle face.
; The receiver still tries trick hits while the ball is far away, but when
; the ball is close it stops showing off and protects the center of the paddle.
;
; BallDX positive: right paddle is the receiver.
; BallDX negative: left paddle is the receiver.
;
; Speed = pixels moved per AI update.
; Aim   = desired hit spot on paddle: high/center/low for trick returns.

MovePaddles:
        ld      a,(BallDX)
        cp      80h
        jp      nc,LeftTurnSide

RightTurnSide:
        ; Ball is going right.  Right attacks, left gets ready.
        call    LeftReadyAI
        jp      RightTurnAI

LeftTurnSide:
        ; Ball is going left.  Left attacks, right gets ready.
        call    RightReadyAI
        jp      LeftTurnAI

; The off-side paddle no longer sits still.  It moves toward a good ready
; spot every frame so the match always looks alive.
LeftReadyAI:
        ld      a,(LeftY)
        ld      (LeftOldY),a
        ld      a,88
        ld      b,3
        ld      hl,LeftY
        call    TrackPaddleVar
        call    StoreLeftMove
        ret

RightReadyAI:
        ld      a,(RightY)
        ld      (RightOldY),a
        ld      a,88
        ld      b,3
        ld      hl,RightY
        call    TrackPaddleVar
        call    StoreRightMove
        ret

RightTurnAI:
        ; Always act.  No more delay counter causing the right player
        ; to pause at the worst moment.
        xor     a
        ld      (RightDelay),a
        ld      a,(RightY)
        ld      (RightOldY),a

        call    PredictRightTarget      ; A = predicted future ball Y
        ld      d,a                     ; keep prediction in D

        ; Far away: use the game aim table for trick returns.
        ; Close to the paddle: stop showing off and make the save.
        ld      a,(BallX)
        cp      RightPanicX
        jp      c,RightNormalAim

RightPanicAim:
        ld      a,d
        ld      c,8                     ; center-safe hit spot
        call    MakeTarget
        ld      d,a
        ld      b,7                     ; emergency paddle speed
        jp      RightMoveToTarget

RightNormalAim:
        ld      a,(RightAim)
        ld      c,a
        ld      a,d
        call    MakeTarget              ; choose paddle top for desired hit spot
        ld      d,a
        ld      a,(RightSpeed)
        ld      b,a

RightMoveToTarget:
        ld      a,d
        ld      hl,RightY
        call    TrackPaddleVar
        call    StoreRightMove
        ret

LeftTurnAI:
        ; Always act.  No more delay counter causing a player to freeze.
        xor     a
        ld      (LeftDelay),a
        ld      a,(LeftY)
        ld      (LeftOldY),a

        call    PredictLeftTarget       ; A = predicted future ball Y
        ld      d,a                     ; keep prediction in D

        ; Far away: use the game aim table for trick returns.
        ; Close to the paddle: stop showing off and make the save.
        ld      a,(BallX)
        cp      LeftPanicX
        jp      nc,LeftNormalAim

LeftPanicAim:
        ld      a,d
        ld      c,8                     ; center-safe hit spot
        call    MakeTarget
        ld      d,a
        ld      b,7                     ; emergency paddle speed
        jp      LeftMoveToTarget

LeftNormalAim:
        ld      a,(LeftAim)
        ld      c,a
        ld      a,d
        call    MakeTarget              ; choose paddle top for desired hit spot
        ld      d,a
        ld      a,(LeftSpeed)
        ld      b,a

LeftMoveToTarget:
        ld      a,d
        ld      hl,LeftY
        call    TrackPaddleVar
        call    StoreLeftMove
        ret

; Right side prediction: estimate where the ball will be when it reaches
; the right paddle.  The predictor simulates top/bottom wall bounces in
; coarse 8-pixel horizontal chunks, which is small and fast on Z80/Z180.
PredictRightTarget:
        ld      a,(BallX)
        cp      RightHitX
        jp      nc,PredictClose
        ld      b,a
        ld      a,RightHitX
        sub     b                       ; A = distance to right hit plane
        call    DistToPredictSteps
        jp      PredictBallYWithB

; Left side prediction.
PredictLeftTarget:
        ld      a,(BallX)
        cp      LeftHitX+1
        jp      c,PredictClose
        sub     LeftHitX
        call    DistToPredictSteps
        jp      PredictBallYWithB

PredictClose:
        ld      b,1
        jp      PredictBallYWithB

; A = horizontal distance, returns B = prediction steps.
; Use the current ball speed so prediction does not over/under shoot badly.
; Capped to keep it quick on the Z80/Z180.
DistToPredictSteps:
        ld      c,a                     ; C = remaining X distance
        ld      a,(BallSpeed)
        or      a
        jp      nz,DistHaveDivisor
        ld      a,2
DistHaveDivisor:
        ld      e,a                     ; E = pixels per frame
        ld      b,0
DistStepLoop:
        ld      a,c
        cp      e
        jp      c,DistStepsDone
        sub     e
        ld      c,a
        inc     b
        ld      a,b
        cp      80
        jp      c,DistStepLoop
        ld      b,80
        ret
DistStepsDone:
        ld      a,b
        or      a
        jp      nz,DistStepsStore
        inc     a
DistStepsStore:
        ld      b,a
        ret

; B = prediction steps.  Returns A = predicted Y.
PredictBallYWithB:
        ld      a,(BallY)
        ld      d,a
        ld      a,(BallDY)
        ld      e,a
PredictBallLoop:
        ld      a,d
        add     a,e
        ld      d,a

        ld      a,d
        cp      BallYMin
        jp      c,PredictUnder
        cp      BallYMax+1
        jp      c,PredictNext

        ; Outside the legal range.  The sign of DY tells whether this was
        ; an upper or lower wall hit, even when the byte wrapped.
        ld      a,e
        cp      80h
        jp      nc,PredictUnder

PredictOver:
        ld      d,BallYMax
        ld      a,e
        ld      c,a
        xor     a
        sub     c
        ld      e,a
        jp      PredictNext

PredictUnder:
        ld      d,BallYMin
        ld      a,e
        ld      c,a
        xor     a
        sub     c
        ld      e,a

PredictNext:
        djnz    PredictBallLoop
        ld      a,d
        ret

; A = predicted ball Y.
; C = desired hit spot on the paddle, 3..13.
;
; REV7 used a signed offset and accidentally let the target clamp against
; the BALL limits instead of the PADDLE limits.  That made paddles sit on
; the top/bottom rails and keep trying to move farther out.
;
; REV8 fixes it: choose where the ball should strike the paddle, then move
; the paddle top to predictedY - hitSpot, clamped to the legal paddle range.
MakeTarget:
        ld      d,a                     ; D = predicted ball Y
        ld      a,d
        cp      c
        jp      nc,TargetCanSubtract
        ld      a,PaddleMin
        ret

TargetCanSubtract:
        sub     c                       ; A = desired paddle top
        cp      PaddleMin
        jp      nc,TargetCheckMax
        ld      a,PaddleMin
        ret

TargetCheckMax:
        cp      PaddleMax+1
        ret     c
        ld      a,PaddleMax
        ret

; The side not currently hitting the ball drifts gently back to center.
; This keeps the game looking alive and stops both players from parking
; forever at the very top or bottom after a sharp spin shot.
DriftLeftHome:
        ld      a,(FrameTick)
        and     1
        ret     nz
        ld      a,88
        ld      b,2
        ld      hl,LeftY
        call    TrackPaddleVar
        xor     a
        ld      (LeftMove),a
        ret

DriftRightHome:
        ld      a,(FrameTick)
        and     1
        ret     nz
        ld      a,88
        ld      b,2
        ld      hl,RightY
        call    TrackPaddleVar
        xor     a
        ld      (RightMove),a
        ret

; A = target Y, B = speed, HL = paddle Y byte.
; REV13 snaps to the target when it is within one move.  The older code
; could jump past the correct Y, reverse, jump past it again, and look like
; the paddle was drunk right when the ball arrived.
TrackPaddleVar:
        ld      d,a                     ; D = target paddle top
        ld      a,b
        or      a
        ret     z
        ld      a,(hl)
        cp      d
        ret     z
        jp      c,PaddleDownVar

PaddleUpVar:
        ; Current Y is below on screen?  Move up toward smaller Y.
        ld      a,(hl)
        sub     d                       ; distance = current - target
        cp      b
        jp      c,PaddleSnapVar
        jp      z,PaddleSnapVar
        ld      a,(hl)
        sub     b
        cp      PaddleMin
        jp      nc,PaddleStoreVar
        ld      a,PaddleMin
        jp      PaddleStoreVar

PaddleDownVar:
        ; Current Y is above target.  Move down toward larger Y.
        ld      a,d
        sub     (hl)                    ; distance = target - current
        cp      b
        jp      c,PaddleSnapVar
        jp      z,PaddleSnapVar
        ld      a,(hl)
        add     a,b
        cp      PaddleMax+1
        jp      c,PaddleStoreVar
        ld      a,PaddleMax
        jp      PaddleStoreVar

PaddleSnapVar:
        ld      a,d

PaddleStoreVar:
        ld      (hl),a
        ret

; Remember paddle motion.  A moving paddle adds spin at the moment of impact.
StoreRightMove:
        ld      a,(RightY)
        ld      b,a
        ld      a,(RightOldY)
        cp      b
        jp      z,RightNoMove
        jp      c,RightMovedDown
RightMovedUp:
        ld      a,0ffh                  ; -1, moving up
        ld      (RightMove),a
        ret
RightMovedDown:
        ld      a,1
        ld      (RightMove),a
        ret
RightNoMove:
        xor     a
        ld      (RightMove),a
        ret

StoreLeftMove:
        ld      a,(LeftY)
        ld      b,a
        ld      a,(LeftOldY)
        cp      b
        jp      z,LeftNoMove
        jp      c,LeftMovedDown
LeftMovedUp:
        ld      a,0ffh                  ; -1, moving up
        ld      (LeftMove),a
        ret
LeftMovedDown:
        ld      a,1
        ld      (LeftMove),a
        ret
LeftNoMove:
        xor     a
        ld      (LeftMove),a
        ret

; ------------------------------------------------------------
; Ball movement, wall bounce, paddle bounce, and scoring.

MoveBall:
        call    SaveBallTrail
        call    ApplySpinTicks
        call    MoveBallY
        call    MoveBallX

        ld      a,(BallDX)
        cp      80h
        jp      nc,CheckLeftPaddle
        jp      CheckRightPaddle

SaveBallTrail:
        ld      a,(BallX)
        ld      (TrailX),a
        ld      a,(BallY)
        ld      (TrailY),a
        ret

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

        ; REV12: left receiver is allowed to crack a little sooner.
        ; This corrects REV10 where the right/blue player kept losing.
        call    LongRallyMissLeft
        jp      c,PointRight

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
        call    ApplyLeftHitSpin
        call    NudgeAfterHit
        ret

CheckRightPaddle:
        ld      a,(BallX)
        cp      RightHitX
        ret     c

        ; REV12: right receiver gets a little more protection.
        ; This keeps the blue/right player from being the easy loser.
        call    LongRallyMissRight
        jp      c,PointLeft

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
        call    ApplyRightHitSpin
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
; Hitting high on the paddle sends the ball up.  Hitting low sends it down.
; The moving paddle then adds spin on top of this base angle.
SetDYFromHit:
        ld      a,(BallY)
        sub     c                       ; BallY - PaddleY

        ; Ball is a little above paddle: sharp upward bounce.
        cp      128
        jp      nc,HitVeryUpper

        cp      3
        jp      c,HitVeryUpper
        cp      6
        jp      c,HitUpper
        cp      8
        jp      c,HitMidUpper
        cp      10
        jp      c,HitMidLower
        cp      13
        jp      c,HitLower

HitVeryLower:
        ld      a,3
        ld      (BallDY),a
        ret
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
HitVeryUpper:
        ld      a,253                   ; -3
        ld      (BallDY),a
        ret

ApplyLeftHitSpin:
        ld      a,(LeftMove)
        jp      ApplyHitSpinCommon

ApplyRightHitSpin:
        ld      a,(RightMove)
        jp      ApplyHitSpinCommon

; A = paddle movement: 0 = no spin, 1 = down spin, FF = up spin.
ApplyHitSpinCommon:
        or      a
        jp      z,ClearSpinOnHit
        cp      80h
        jp      nc,HitSpinUp

HitSpinDown:
        call    AddDownSpin
        ld      a,1
        ld      (BallSpin),a
        ld      a,SpinFrames
        ld      (SpinTicks),a
        ret

HitSpinUp:
        call    AddUpSpin
        ld      a,0ffh
        ld      (BallSpin),a
        ld      a,SpinFrames
        ld      (SpinTicks),a
        ret

ClearSpinOnHit:
        xor     a
        ld      (BallSpin),a
        ld      (SpinTicks),a
        ret

; A little curve remains after a spinning hit.  This is intentionally small:
; enough to be seen, not enough to make the ball go crazy or get stuck.
ApplySpinTicks:
        ld      a,(SpinTicks)
        or      a
        ret     z
        dec     a
        ld      (SpinTicks),a

        ld      a,(FrameTick)
        and     7
        ret     nz

        ld      a,(BallSpin)
        or      a
        ret     z
        cp      80h
        jp      nc,AddUpSpin
        jp      AddDownSpin

AddDownSpin:
        ld      a,(BallDY)
        cp      80h
        jp      nc,DownSpinFromNegative
        cp      3
        ret     nc
        inc     a
        ld      (BallDY),a
        ret

DownSpinFromNegative:
        inc     a
        or      a
        jp      nz,StoreSpinDY
        ld      a,1
StoreSpinDY:
        ld      (BallDY),a
        ret

AddUpSpin:
        ld      a,(BallDY)
        cp      80h
        jp      nc,UpSpinFromNegative
        dec     a
        or      a
        jp      nz,StoreSpinDY
        ld      a,255                   ; -1
        ld      (BallDY),a
        ret

UpSpinFromNegative:
        cp      253                     ; already at -3
        ret     z
        dec     a
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

        ; Every 8 paddle hits, refresh both aim spots.  This keeps the
        ; match from falling into a boring perfect loop without making
        ; either player deliberately whiff.
        ld      hl,RallyCount
        ld      a,(hl)
        and     7
        call    z,RefreshPlayerAims

        ; Every 16 paddle hits, force a small vertical nudge so the pattern
        ; keeps changing even when both players are defending well.
        ld      hl,RallyCount
        ld      a,(hl)
        and     0fh
        ret     nz

        ld      a,(hl)
        and     10h
        jp      z,NudgeUp

NudgeDown:
        ld      a,2
        ld      (BallDY),a
        ret

NudgeUp:
        ld      a,254                   ; -2
        ld      (BallDY),a
        ret

RefreshPlayerAims:
        ; Use safer pro aim spots while the rally is alive.  Both players
        ; can still add spin and trick shots, but they do not intentionally
        ; camp on the very edge of the paddle anymore.
        call    Rand8
        and     7
        ld      hl,LeftAimTable
        call    Table8
        ld      (LeftAim),a
        call    Rand8
        and     7
        ld      hl,RightAimTable
        call    Table8
        ld      (RightAim),a
        ret

; REV13 pressure handling.
;
; REV11 could look dumb because a long rally could force a receiver to miss
; even when the paddle was visibly in position.  REV13 still refuses to do that.
; Scores now come from real misses caused by speed, angle, and paddle motion,
; not from an invisible timer.
LongRallyMissLeft:
        or      a                       ; clear carry = no fake miss
        ret

LongRallyMissRight:
        or      a                       ; clear carry = no fake miss
        ret

LongRallyNoMiss:
        or      a                       ; clear carry
        ret

LongRallyForceMiss:
        or      a                       ; REV12 never forces a miss here
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
        call    BalanceAfterScore
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
        call    BalanceAfterScore
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

; Keep long runs interesting without making either side act broken.
; Right/blue still gets a tiny help when left leads, but neither player is
; made slow enough to look stupid.
BalanceAfterScore:
        ; Left leads by 1 or more?  Favor right/blue gently.
        ld      a,(LeftScore)
        ld      b,a
        ld      a,(RightScore)
        cp      b
        jp      c,FavorRightSide

        ; Right leads by 2 or more?  Give left a gentle correction.
        ld      a,(RightScore)
        ld      b,a
        ld      a,(LeftScore)
        inc     a
        cp      b
        jp      c,FavorLeftSide
        ret

FavorRightSide:
        ld      a,7
        ld      (RightSpeed),a
        xor     a
        ld      (RightReact),a
        ld      a,6
        ld      (LeftSpeed),a
        xor     a
        ld      (LeftReact),a
        call    Rand8
        and     7
        ld      hl,RightComebackAimTable
        call    Table8
        ld      (RightAim),a
        ret

FavorLeftSide:
        ld      a,7
        ld      (LeftSpeed),a
        xor     a
        ld      (LeftReact),a
        ld      a,6
        ld      (RightSpeed),a
        xor     a
        ld      (RightReact),a
        call    Rand8
        and     7
        ld      hl,ComebackAimTable
        call    Table8
        ld      (LeftAim),a
        ret

; ------------------------------------------------------------
; Game spec generator.
; This is pseudo-random, not hardware random, so it is repeatable and safe.
; REV13 tuning: both players are quicker and smarter.  No player is allowed
; to freeze, overshoot, or make a fake timer miss.  Misses come from real
; speed, angle, and motion.

NewGameSpecs:
        ; Reset reaction delays so new specs start immediately.
        xor     a
        ld      (LeftDelay),a
        ld      (RightDelay),a

        call    Rand8
        and     7
        ld      hl,LeftSpeedTable
        call    Table8
        ld      (LeftSpeed),a

        call    Rand8
        and     7
        ld      hl,RightSpeedTable
        call    Table8
        ld      (RightSpeed),a

        call    Rand8
        and     7
        ld      hl,LeftReactTable
        call    Table8
        ld      (LeftReact),a

        call    Rand8
        and     7
        ld      hl,RightReactTable
        call    Table8
        ld      (RightReact),a

        call    Rand8
        and     7
        ld      hl,LeftAimTable
        call    Table8
        ld      (LeftAim),a

        call    Rand8
        and     7
        ld      hl,RightAimTable
        call    Table8
        ld      (RightAim),a

        call    Rand8
        and     7
        ld      hl,BallSpeedTable
        call    Table8
        ld      (BallSpeed),a

        ; Rarely put a player under mild pressure.
        ; REV12 mostly pressures the left side because the right/blue side
        ; was losing too often in real watching.
        call    Rand8
        and     0fh
        cp      0
        jp      z,WeakLeft
        cp      1
        jp      z,WeakLeft
        cp      2
        jp      z,WeakBoth
        cp      3
        jp      z,WeakRightSoft
        ret

WeakBoth:
        call    WeakLeftCore
        jp      WeakRightCore

WeakLeft:
        jp      WeakLeftCore

WeakRight:
        jp      WeakRightCore

WeakRightSoft:
        ; A very small right-side flaw: still fast and alert.
        ld      a,6
        ld      (RightSpeed),a
        xor     a
        ld      (RightReact),a
        ld      a,8
        ld      (RightAim),a
        ret

WeakLeftCore:
        ; Mild pro-level imperfection: still quick, never frozen.
        ld      a,5
        ld      (LeftSpeed),a
        xor     a
        ld      (LeftReact),a
        call    Rand8
        and     1
        jp      z,WeakLeftAimUp
        ld      a,10                    ; safer low paddle hit
        ld      (LeftAim),a
        ret
WeakLeftAimUp:
        ld      a,6                     ; safer high paddle hit
        ld      (LeftAim),a
        ret

WeakRightCore:
        ; Right/blue imperfection is soft: still quick, never frozen.
        ld      a,6
        ld      (RightSpeed),a
        xor     a
        ld      (RightReact),a
        call    Rand8
        and     1
        jp      z,WeakRightAimUp
        ld      a,10                    ; safer low paddle hit
        ld      (RightAim),a
        ret
WeakRightAimUp:
        ld      a,6                     ; safer high paddle hit
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
        ; Keep the trail on the served ball so there is no long red streak
        ; from the previous point.
        ld      a,(BallX)
        ld      (TrailX),a
        ld      a,(BallY)
        ld      (TrailY),a

        xor     a
        ld      (RallyCount),a
        ld      (BallSpin),a
        ld      (SpinTicks),a
        ld      a,ScorePauseFrames
        ld      (ScorePause),a
        ret

; ------------------------------------------------------------
; Constants.

TileBlank:          equ 0
TileLeftCorner:     equ 1
TileLeftHBorder:    equ 2
TileLeftVBorder:    equ 3
DigitBase:          equ 8
TileG:              equ 18
TileA:              equ 19
TileM:              equ 20
TileE:              equ 21
TileS:              equ 22
TileRightCorner:    equ 24
TileRightHBorder:   equ 25
TileRightVBorder:   equ 26
TileDash:           equ 32

PaddlePattern:      equ 0
BallPattern:        equ 4

LeftX:              equ 16
RightX:             equ 224
LeftHitX:           equ 22
RightHitX:          equ 218
LeftPanicX:         equ 52
RightPanicX:        equ 188

PaddleMin:          equ 16
PaddleMax:          equ 160
PaddleSpeed:        equ 2

BallYMin:           equ 8
BallYMax:           equ 176

ScorePauseFrames:   equ 12
SpinFrames:         equ 18
GamePoint:          equ 9
LongRallyLeftSoft:  equ 200
LongRallyLeftHard:  equ 220
LongRallyRightSoft: equ 200
LongRallyRightHard: equ 220

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

LeftSpeed:      defb 5
RightSpeed:     defb 6
LeftReact:      defb 0
RightReact:     defb 0
LeftDelay:      defb 0
RightDelay:     defb 0
LeftAim:        defb 0
RightAim:       defb 0
LeftMove:       defb 0
RightMove:      defb 0
LeftOldY:       defb 88
RightOldY:      defb 88
BallSpeed:      defb 4

LeftY:          defb 88
RightY:         defb 88

BallX:          defb 120
BallY:          defb 88
TrailX:         defb 120
TrailY:         defb 88
BallDX:         defb 4
BallDY:         defb 1
BallSpin:       defb 0
SpinTicks:      defb 0

; Specs are much faster now, but still less robotic.
; AimTable is no longer signed.  It is the desired paddle hit spot:
;   4/5    = high hit, sharp upward return
;   8      = center hit
;   11/12  = low hit, sharp downward return
; This makes trick shots without making the paddles pin themselves to rails.
LeftSpeedTable:     defb 5,6,6,6,5,6,7,6
RightSpeedTable:    defb 5,6,6,6,5,6,7,6
LeftReactTable:     defb 0,0,0,0,0,0,0,0
RightReactTable:    defb 0,0,0,0,0,0,0,0
LeftAimTable:       defb 8,7,9,6,10,8,7,9
RightAimTable:      defb 8,7,9,6,10,8,7,9
ComebackAimTable:   defb 8,7,9,6,10,8,7,9
RightComebackAimTable: defb 8,7,9,6,10,8,7,9
BallSpeedTable:     defb 3,4,4,5,5,4,3,5

NoTmsMsg:
        defb    "TMSEMU3 / TMS9918A not found, aborting!$"

; ------------------------------------------------------------
; Tile color table.
; TMS Graphics I uses one color byte per 8 tile patterns.
; High nibble = foreground, low nibble = background.
;   group 0, tiles 00-07: left-side border, bright white on black
;   group 1, tiles 08-15: score digits 0-7, yellow on black
;   group 2, tiles 16-23: score digits 8-9 and GAMES text, yellow on black
;   group 3, tiles 24-31: right-side border, bright white on black
;   group 4, tiles 32-39: center net, gray on black

TileColorTable:
        defb    0f1h,0b1h,0b1h,0f1h
        defb    0e1h,0f1h,0f1h,0f1h
        defb    0f1h,0f1h,0f1h,0f1h
        defb    0f1h,0f1h,0f1h,0f1h
        defb    0f1h,0f1h,0f1h,0f1h
        defb    0f1h,0f1h,0f1h,0f1h
        defb    0f1h,0f1h,0f1h,0f1h
        defb    0f1h,0f1h,0f1h,0f1h

; ------------------------------------------------------------
; Tile patterns, 8 bytes each.
; Pattern 0 blank.
; 1-3 left border.
; 8-17 digits 0-9. 18-22 GAMES.
; 24-26 right border. 32 dashed net.

TilePatterns:
        ; 0 blank
        defb    00h,00h,00h,00h,00h,00h,00h,00h

        ; 1 left corner / white chrome diamond block
        defb    0ffh,0c3h,099h,0bdh,0bdh,099h,0c3h,0ffh

        ; 2 left horizontal white chrome rail
        defb    0ffh,000h,07eh,042h,05ah,042h,07eh,0ffh

        ; 3 left vertical white chrome rail
        defb    0e7h,0a5h,0bdh,099h,099h,0bdh,0a5h,0e7h

        ; 4-7 unused, kept blank so digits start at tile 8/color group 1
        defb    00h,00h,00h,00h,00h,00h,00h,00h
        defb    00h,00h,00h,00h,00h,00h,00h,00h
        defb    00h,00h,00h,00h,00h,00h,00h,00h
        defb    00h,00h,00h,00h,00h,00h,00h,00h

        ; 8 digit 0
        defb    3ch,66h,6eh,76h,66h,66h,3ch,00h
        ; 9 digit 1
        defb    18h,38h,18h,18h,18h,18h,7eh,00h
        ; 10 digit 2
        defb    3ch,66h,06h,0ch,18h,30h,7eh,00h
        ; 11 digit 3
        defb    3ch,66h,06h,1ch,06h,66h,3ch,00h
        ; 12 digit 4
        defb    0ch,1ch,3ch,6ch,7eh,0ch,0ch,00h
        ; 13 digit 5
        defb    7eh,60h,7ch,06h,06h,66h,3ch,00h
        ; 14 digit 6
        defb    1ch,30h,60h,7ch,66h,66h,3ch,00h
        ; 15 digit 7
        defb    7eh,66h,06h,0ch,18h,18h,18h,00h
        ; 16 digit 8
        defb    3ch,66h,66h,3ch,66h,66h,3ch,00h
        ; 17 digit 9
        defb    3ch,66h,66h,3eh,06h,0ch,38h,00h

        ; 18 G
        defb    3eh,60h,60h,6eh,66h,66h,3eh,00h
        ; 19 A
        defb    18h,3ch,66h,66h,7eh,66h,66h,00h
        ; 20 M
        defb    63h,77h,7fh,6bh,63h,63h,63h,00h
        ; 21 E
        defb    7eh,60h,60h,7ch,60h,60h,7eh,00h
        ; 22 S
        defb    3eh,60h,60h,3ch,06h,06h,7ch,00h

        ; 23 unused spacer
        defb    00h,00h,00h,00h,00h,00h,00h,00h

        ; 24 right corner / white chrome diamond block
        defb    0ffh,0c3h,099h,0bdh,0bdh,099h,0c3h,0ffh

        ; 25 right horizontal white chrome rail
        defb    0ffh,000h,07eh,042h,05ah,042h,07eh,0ffh

        ; 26 right vertical white chrome rail
        defb    0e7h,0a5h,0bdh,099h,099h,0bdh,0a5h,0e7h

        ; 27-31 unused, kept blank so net starts at tile 32/color group 4
        defb    00h,00h,00h,00h,00h,00h,00h,00h
        defb    00h,00h,00h,00h,00h,00h,00h,00h
        defb    00h,00h,00h,00h,00h,00h,00h,00h
        defb    00h,00h,00h,00h,00h,00h,00h,00h
        defb    00h,00h,00h,00h,00h,00h,00h,00h

        ; 32 vertical dashed net tile
        defb    18h,18h,00h,00h,18h,18h,00h,00h

TilePatternsEnd:

; ------------------------------------------------------------
; 16x16 sprite patterns.
; TMS 16x16 sprite order:
;   upper-left 8 bytes, lower-left 8, upper-right 8, lower-right 8.

SpritePatterns:
        ; Pattern 0: bright-white 16x16 chrome paddle, centered in sprite cell.
        ; upper-left
        defb    03h,07h,0fh,0fh,0fh,0fh,0fh,0fh
        ; lower-left
        defb    0fh,0fh,0fh,0fh,0fh,0fh,07h,03h
        ; upper-right
        defb    0c0h,0e0h,0f0h,0f0h,0f0h,0f0h,0f0h,0f0h
        ; lower-right
        defb    0f0h,0f0h,0f0h,0f0h,0f0h,0f0h,0e0h,0c0h

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
