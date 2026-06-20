; CHESSAUTO_REV5.ASM
; SC720 / Z80-Z180 + TMSEMU3 / TMS9918A
; Pretty self-playing sprite chess show for the TMSAsmBuilder REV8 IDE.
;
; Build with the IDE/sjasmplus path, not CP/M ASM.COM.
;
; What this REV5 does:
;   - black background
;   - tiled 8x8 chess board with tan and darker-tan squares plus a bright frame
;   - all chess men are TMS sprites, one 16x16 sprite per piece
;   - white and black use the same clean solid glyph sprite shapes in bright white and deep black
;   - one piece animates smoothly from square to square
;   - stronger thinking self-play line loops forever
;   - captures remove the captured sprite
;   - REV5 cleanly restarts after each game and keeps the side score panels protected
;   - press any CP/M console key to exit
;
; Important TMS9918A note:
;   The real TMS9918A only displays 4 sprites on the same scanline.
;   This demo is intentionally "all-sprite" because it looks neat in motion.
;   REV5 keeps the captured-piece 208 terminator fix and prioritizes
;   the active mover so black pieces do not vanish behind the sprite list.
;
; Needed REV8 Libs:
;   include "tms.asm"
;   include "z180.asm"
;   include "utility.asm"

        org     100h

Start:
        ld      (OldSP),sp
        ld      sp,Stack

        ; Safe TMS wait timing on fast Z180 systems.
        call    z180detect
        ld      e,0
        jp      nz,NoZ180
        call    z180getclk
NoZ180:
        call    TmsSetWait

        ; Find TMSEMU3 / TMS9918A.
        call    TmsProbe
        jp      z,NoTms

        ; Tile mode, black background.
        call    TmsTile
        ld      a,TmsBlack
        call    TmsBackground

        call    LoadTileColors
        call    LoadTilePatterns
        call    LoadSpritePatterns

        ; 16x16 sprites, normal size.
        ld      a,TmsSprite32
        call    TmsSpriteConfig

        call    DrawScreen
        call    ResetPieces
        call    ResetMoveList
        call    WriteSprites

MainLoop:
        call    WaitFrame
        call    TickStars
        call    ChessThink
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
; Stable frame wait.

WaitFrame:
WaitNotV:
        call    TmsRegIn
        jp      m,WaitNotV
WaitV:
        call    TmsRegIn
        jp      p,WaitV
        ret

; ------------------------------------------------------------
; VRAM loading.

LoadTileColors:
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
; Draw the static tile screen.

DrawScreen:
        ; Clear screen.
        ld      de,(TmsNameAddr)
        ld      bc,TmsTileNameLen
        xor     a
        call    TmsFill

        call    DrawTitle
        call    DrawBoardFrame
        call    DrawBoard
        call    DrawCoordinates
        call    DrawSideLabels
        call    DrawSideScores
        call    DrawFooter
        ret

DrawTitle:
        ; Row 1, col 7: SPRITE CHESS REV5, centered
        ld      hl,(TmsNameAddr)
        ld      de,39                   ; row 1 * 32 + col 7
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      hl,TitleText
        jp      WriteTextTiles

DrawFooter:
        ; Row 22, col 4: SELF PLAY - ANY KEY EXITS
        ld      hl,(TmsNameAddr)
        ld      de,708                  ; row 22 * 32 + col 4
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      hl,FooterText
        jp      WriteTextTiles

DrawSideLabels:
        ; Left score panel.
        ld      hl,(TmsNameAddr)
        ld      de,129                  ; row 4 col 1
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      hl,WhiteText
        call    WriteTextTiles

        ld      hl,(TmsNameAddr)
        ld      de,193                  ; row 6 col 1
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      hl,ScoreText
        call    WriteTextTiles

        ; Right score panel.
        ld      hl,(TmsNameAddr)
        ld      de,154                  ; row 4 col 26
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      hl,BlackText
        call    WriteTextTiles

        ld      hl,(TmsNameAddr)
        ld      de,218                  ; row 6 col 26
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      hl,ScoreText
        call    WriteTextTiles
        ret

DrawSideScores:
        ; White capture score, row 5 col 3.
        ld      hl,(TmsNameAddr)
        ld      de,163                  ; row 5 col 3
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      a,(WhiteScore10)
        add     a,DigitBase
        call    TmsRamOut
        ld      a,(WhiteScore1)
        add     a,DigitBase
        call    TmsRamOut

        ; Black capture score, row 5 col 28.
        ld      hl,(TmsNameAddr)
        ld      de,188                  ; row 5 col 28
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      a,(BlackScore10)
        add     a,DigitBase
        call    TmsRamOut
        ld      a,(BlackScore1)
        add     a,DigitBase
        call    TmsRamOut
        ret

DrawThinkingStatus:
        ; Clear both side THINK tags, then mark the side that is choosing a move.
        call    ClearThinkTags
        ld      a,(ActivePiece)
        cp      16
        jp      c,DrawWhiteThinking
DrawBlackThinking:
        ld      hl,(TmsNameAddr)
        ld      de,346                  ; row 10 col 26
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      hl,ThinkText
        jp      WriteTextTiles
DrawWhiteThinking:
        ld      hl,(TmsNameAddr)
        ld      de,321                  ; row 10 col 1
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      hl,ThinkText
        jp      WriteTextTiles

ClearThinkTags:
        ld      hl,(TmsNameAddr)
        ld      de,321                  ; row 10 col 1
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      a,TileSpace
        ld      b,5
ClearWhiteThinkLoop:
        call    TmsRamOut
        djnz    ClearWhiteThinkLoop

        ld      hl,(TmsNameAddr)
        ld      de,346                  ; row 10 col 26
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      a,TileSpace
        ld      b,5
ClearBlackThinkLoop:
        call    TmsRamOut
        djnz    ClearBlackThinkLoop
        ret

; HL points to zero-terminated tile string already encoded as tile numbers.
WriteTextTiles:
        ld      a,(hl)
        or      a
        ret     z
        call    TmsRamOut
        inc     hl
        jp      WriteTextTiles

DrawBoardFrame:
        ; Frame around board. Board occupies tile rows 4..19, cols 8..23.
        ; Frame occupies rows 3..20, cols 7..24.
        ld      hl,(TmsNameAddr)
        ld      de,103                  ; row 3 col 7
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      a,TileCorner
        call    TmsRamOut
        ld      a,TileHFrame
        ld      b,16
TopFrameLoop:
        call    TmsRamOut
        djnz    TopFrameLoop
        ld      a,TileCorner
        call    TmsRamOut

        ld      hl,(TmsNameAddr)
        ld      de,647                  ; row 20 col 7
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      a,TileCorner
        call    TmsRamOut
        ld      a,TileHFrame
        ld      b,16
BotFrameLoop:
        call    TmsRamOut
        djnz    BotFrameLoop
        ld      a,TileCorner
        call    TmsRamOut

        ld      hl,(TmsNameAddr)
        ld      de,135                  ; row 4 col 7
        add     hl,de
        ld      b,16
SideFrameLoop:
        push    bc
        push    hl
        ex      de,hl
        call    TmsWriteAddr
        ld      a,TileVFrame
        call    TmsRamOut
        pop     hl
        push    hl
        ld      de,17
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      a,TileVFrame
        call    TmsRamOut
        pop     hl
        ld      de,32
        add     hl,de
        pop     bc
        djnz    SideFrameLoop
        ret

DrawBoard:
        ; 8x8 squares, each square is 2x2 tiles.
        ; Tile top-left is row 4 col 8.
        ld      b,8                     ; rank 0..7
        xor     a
        ld      (RankCounter),a
RankLoop:
        push    bc
        ld      b,8
        xor     a
        ld      (FileCounter),a
FileLoop:
        push    bc
        ld      a,(RankCounter)
        ld      b,a
        ld      a,(FileCounter)
        xor     b
        and     1
        jp      z,UseLightSquare
        ld      a,TileDarkSq
        jp      HaveSquareTile
UseLightSquare:
        ld      a,TileLightSq
HaveSquareTile:
        ld      (SquareTile),a
        call    DrawOneSquare
        ld      hl,FileCounter
        inc     (hl)
        pop     bc
        djnz    FileLoop
        ld      hl,RankCounter
        inc     (hl)
        pop     bc
        djnz    RankLoop
        ret

DrawOneSquare:
        ; Address = name + (4 + rank*2)*32 + (8 + file*2).
        ld      a,(RankCounter)
        add     a,a                     ; rank * 2
        add     a,4
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; row * 32
        ld      a,(FileCounter)
        add     a,a
        add     a,8
        ld      e,a
        ld      d,0
        add     hl,de
        ld      de,(TmsNameAddr)
        add     hl,de

        push    hl
        ex      de,hl
        call    TmsWriteAddr
        ld      a,(SquareTile)
        call    TmsRamOut
        ld      a,(SquareTile)
        call    TmsRamOut
        pop     hl
        ld      de,32
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      a,(SquareTile)
        call    TmsRamOut
        ld      a,(SquareTile)
        jp      TmsRamOut

DrawCoordinates:
        ; REV5: keep board labels away from the side score panels.
        ; Top file labels A-H.
        ld      hl,(TmsNameAddr)
        ld      de,73                   ; row 2 col 9
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      hl,FileLabelText
        call    WriteTextTiles

        ; Bottom file labels A-H.
        ld      hl,(TmsNameAddr)
        ld      de,681                  ; row 21 col 9
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      hl,FileLabelText
        jp      WriteTextTiles

TickStars:
        ; REV5: disabled the random background sparkles.
        ; They looked neat, but they could overwrite BLACK/SCORE/00 tiles
        ; and make the score panel look corrupted after a while.
        ret

; ------------------------------------------------------------
; Piece setup and self-play move system.

ResetPieces:
        ld      hl,PieceXInit
        ld      de,PieceX
        ld      bc,32
        ldir
        ld      hl,PieceYInit
        ld      de,PieceY
        ld      bc,32
        ldir
        ld      hl,PiecePatternInit
        ld      de,PiecePattern
        ld      bc,32
        ldir
        ld      hl,PieceColorInit
        ld      de,PieceColor
        ld      bc,32
        ldir
        ld      hl,PieceAliveInit
        ld      de,PieceAlive
        ld      bc,32
        ldir
        xor     a
        ld      (ActiveFlag),a
        ld      (ThinkingFlag),a
        ld      (WhiteScore10),a
        ld      (WhiteScore1),a
        ld      (BlackScore10),a
        ld      (BlackScore1),a
        call    DrawSideScores
        call    ClearThinkTags
        ret

ResetMoveList:
        ld      hl,MoveList
        ld      (MovePtr),hl
        xor     a
        ld      (ActiveFlag),a
        ld      (ThinkingFlag),a
        ld      (MovePause),a
        ret

RestartGame:
        ; REV5: the end-of-move-list marker must restart the show.
        ; Earlier revisions jumped to this label without it being present,
        ; which could fall through to address 0000h and look like the
        ; program randomly exited after a few games.
        call    DrawScreen
        call    ResetPieces
        call    ResetMoveList
        call    WriteSprites
        ld      a,20
        ld      (MovePause),a
        ret

ChessThink:
        ld      a,(MovePause)
        or      a
        jp      z,ThinkNoPause
        dec     a
        ld      (MovePause),a
        ret

ThinkNoPause:
        ld      a,(ActiveFlag)
        or      a
        jp      nz,AnimateActiveMove
        ld      a,(ThinkingFlag)
        or      a
        jp      nz,FinishLoadNextMove
        jp      BeginThinking

BeginThinking:
        ; Peek the next move and show which side is thinking before it moves.
        ld      hl,(MovePtr)
        ld      a,(hl)
        cp      0ffh
        jp      z,RestartGame
        ld      (ActivePiece),a
        call    DrawThinkingStatus
        call    Rand8
        and     15
        add     a,22                    ; variable 22..37 frame think delay
        ld      (MovePause),a
        ld      a,1
        ld      (ThinkingFlag),a
        ret

FinishLoadNextMove:
        xor     a
        ld      (ThinkingFlag),a
        call    ClearThinkTags

LoadNextMove:
        ld      hl,(MovePtr)
        ld      a,(hl)
        cp      0ffh
        jp      z,RestartGame
        ld      (ActivePiece),a
        inc     hl
        ld      a,(hl)
        ld      (TargetFile),a
        inc     hl
        ld      a,(hl)
        ld      (TargetRank),a
        inc     hl
        ld      a,(hl)
        ld      (CapturePiece),a
        inc     hl
        ld      (MovePtr),hl

        ; TargetFile -> TargetX.
        ld      a,(TargetFile)
        call    FileToPixelX
        ld      (TargetX),a
        ld      a,(TargetRank)
        call    RankToPixelY
        ld      (TargetY),a

        ; Hide captured piece at the start of the move so the attacker slides in cleanly.
        ; REV5 also increments the side capture score.
        ld      a,(CapturePiece)
        cp      0ffh
        jp      z,NoCaptureThisMove
        call    ScoreCapture
        ld      a,(CapturePiece)
        call    KillPiece
NoCaptureThisMove:
        ld      a,1
        ld      (ActiveFlag),a
        jp      AnimateActiveMove

AnimateActiveMove:
        ld      a,(ActivePiece)
        call    PtrPieceX
        ld      a,(hl)
        ld      b,a
        ld      a,(TargetX)
        cp      b
        jp      z,MoveYPart
        jp      nc,MoveRightOne
MoveLeftOne:
        dec     b
        ld      (hl),b
        ret
MoveRightOne:
        inc     b
        ld      (hl),b
        ret

MoveYPart:
        ld      a,(ActivePiece)
        call    PtrPieceY
        ld      a,(hl)
        ld      b,a
        ld      a,(TargetY)
        cp      b
        jp      z,MoveArrived
        jp      nc,MoveDownOne
MoveUpOne:
        dec     b
        ld      (hl),b
        ret
MoveDownOne:
        inc     b
        ld      (hl),b
        ret

MoveArrived:
        xor     a
        ld      (ActiveFlag),a
        ld      a,6
        ld      (MovePause),a
        ret

; A = piece index. Mark not alive.
KillPiece:
        call    PtrPieceAlive
        xor     a
        ld      (hl),a
        ret

ScoreCapture:
        ; ActivePiece 0..15 is white, 16..31 is black.
        ld      a,(ActivePiece)
        cp      16
        jp      c,IncWhiteScore
        jp      IncBlackScore

IncWhiteScore:
        ld      hl,WhiteScore1
        call    IncScoreDigit
        jp      nc,WhiteScoreDone
        ld      hl,WhiteScore10
        call    IncScoreDigit
WhiteScoreDone:
        call    DrawSideScores
        ret

IncBlackScore:
        ld      hl,BlackScore1
        call    IncScoreDigit
        jp      nc,BlackScoreDone
        ld      hl,BlackScore10
        call    IncScoreDigit
BlackScoreDone:
        call    DrawSideScores
        ret

IncScoreDigit:
        inc     (hl)
        ld      a,(hl)
        cp      10
        jp      c,ScoreNoCarry
        xor     a
        ld      (hl),a
        scf
        ret
ScoreNoCarry:
        or      a                       ; clear carry
        ret

; A = file 0..7 -> sprite X.
FileToPixelX:
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        add     a,BoardPixX
        ret

; A = rank 0..7 -> sprite Y.
RankToPixelY:
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        add     a,BoardPixY
        ret

; ------------------------------------------------------------
; Sprite writer.

WriteSprites:
        ld      de,(TmsSpriteAttrAddr)
        call    TmsWriteAddr

        ; REV5: if a piece is thinking or moving, write it first in the
        ; TMS sprite attribute table.  This prevents the active black piece
        ; from being the 5th+ sprite on a crowded scanline.
        ld      a,(ActiveFlag)
        ld      b,a
        ld      a,(ThinkingFlag)
        or      b
        jp      z,WriteSpritesNormal

        ld      a,(ActivePiece)
        call    WriteOneSpriteIndex
        ld      c,0
WritePriorityLoop:
        ld      a,c
        ld      b,a
        ld      a,(ActivePiece)
        cp      b
        jp      z,NextPrioritySprite
        ld      a,b
        call    WriteOneSpriteIndex
NextPrioritySprite:
        inc     c
        ld      a,c
        cp      32
        jp      c,WritePriorityLoop
        ld      a,208
        jp      TmsRamOut

WriteSpritesNormal:
        ld      c,0
WriteSpriteLoop:
        ld      a,c
        call    WriteOneSpriteIndex
        inc     c
        ld      a,c
        cp      32
        jp      c,WriteSpriteLoop
        ld      a,208
        jp      TmsRamOut

; A = piece index. Writes one 4-byte sprite attribute entry.
WriteOneSpriteIndex:
        ld      (WriteIndex),a
        call    PtrPieceAlive
        ld      a,(hl)
        or      a
        jp      z,WriteHiddenSprite

        ld      a,(WriteIndex)
        call    PtrPieceY
        ld      a,(hl)
        call    TmsRamOut
        ld      a,(WriteIndex)
        call    PtrPieceX
        ld      a,(hl)
        call    TmsRamOut
        ld      a,(WriteIndex)
        call    PtrPiecePattern
        ld      a,(hl)
        call    TmsRamOut
        ld      a,(WriteIndex)
        call    PtrPieceColor
        ld      a,(hl)
        jp      TmsRamOut

WriteHiddenSprite:
        ; Do NOT use 208 here.  On TMS9918A, Y=208 terminates the entire
        ; sprite list, which was the black-piece disappearing bug.
        ld      a,HiddenSpriteY
        call    TmsRamOut
        xor     a
        call    TmsRamOut
        xor     a
        call    TmsRamOut
        xor     a
        jp      TmsRamOut

HideSprites:
        ld      de,(TmsSpriteAttrAddr)
        call    TmsWriteAddr
        ld      a,208
        jp      TmsRamOut

; Pointer helpers. A = piece index. Returns HL = array + A.
PtrPieceX:
        ld      hl,PieceX
        jp      AddAToHL
PtrPieceY:
        ld      hl,PieceY
        jp      AddAToHL
PtrPiecePattern:
        ld      hl,PiecePattern
        jp      AddAToHL
PtrPieceColor:
        ld      hl,PieceColor
        jp      AddAToHL
PtrPieceAlive:
        ld      hl,PieceAlive
        jp      AddAToHL

AddAToHL:
        ld      e,a
        ld      d,0
        add     hl,de
        ret

; ------------------------------------------------------------
; Small PRNG for stars only.

Rand8:
        ld      a,(RandomSeed)
        rrca
        jp      nc,RandStore
        xor     0b8h
RandStore:
        ld      (RandomSeed),a
        ret

; ------------------------------------------------------------
; Constants.

TileBlank:      equ 0
TileHFrame:     equ 1
TileVFrame:     equ 2
TileCorner:     equ 3
TileStar:       equ 4
TileAccent:     equ 5
TileLightSq:    equ 8
TileDarkSq:     equ 9
TileTextBase:   equ 32
TileSpace:      equ 59
DigitBase:      equ 60
HiddenSpriteY:  equ 209       ; off-screen hide, not end marker

BoardPixX:      equ 64
BoardPixY:      equ 32

PatPawn:        equ 0
PatRook:        equ 4
PatKnight:      equ 8
PatBishop:      equ 12
PatQueen:       equ 16
PatKing:        equ 20

WhiteColor:     equ 15        ; white
BlackColor:     equ 1         ; true black pieces on the tan board

; ------------------------------------------------------------
; State.

OldSP:          defw 0
MovePtr:        defw MoveList
ActiveFlag:     defb 0
ActivePiece:    defb 0
TargetFile:     defb 0
TargetRank:     defb 0
TargetX:        defb 0
TargetY:        defb 0
CapturePiece:   defb 0ffh
MovePause:      defb 0
RankCounter:    defb 0
FileCounter:    defb 0
SquareTile:     defb 0
StarTick:       defb 0
RandomSeed:     defb 0a7h
ThinkingFlag:   defb 0
WriteIndex:     defb 0
WhiteScore10:   defb 0
WhiteScore1:    defb 0
BlackScore10:   defb 0
BlackScore1:    defb 0

; Piece order:
;   00-07 white back rank: R N B Q K B N R
;   08-15 white pawns:     a b c d e f g h
;   16-23 black back rank: R N B Q K B N R
;   24-31 black pawns:     a b c d e f g h

PieceX:
        defs 32,0
PieceY:
        defs 32,0
PiecePattern:
        defs 32,0
PieceColor:
        defs 32,0
PieceAlive:
        defs 32,0

PieceXInit:
        defb 64,80,96,112,128,144,160,176
        defb 64,80,96,112,128,144,160,176
        defb 64,80,96,112,128,144,160,176
        defb 64,80,96,112,128,144,160,176
PieceYInit:
        defb 144,144,144,144,144,144,144,144
        defb 128,128,128,128,128,128,128,128
        defb 32,32,32,32,32,32,32,32
        defb 48,48,48,48,48,48,48,48
PiecePatternInit:
        defb PatRook,PatKnight,PatBishop,PatQueen,PatKing,PatBishop,PatKnight,PatRook
        defb PatPawn,PatPawn,PatPawn,PatPawn,PatPawn,PatPawn,PatPawn,PatPawn
        defb PatRook,PatKnight,PatBishop,PatQueen,PatKing,PatBishop,PatKnight,PatRook
        defb PatPawn,PatPawn,PatPawn,PatPawn,PatPawn,PatPawn,PatPawn,PatPawn
PieceColorInit:
        defb WhiteColor,WhiteColor,WhiteColor,WhiteColor,WhiteColor,WhiteColor,WhiteColor,WhiteColor
        defb WhiteColor,WhiteColor,WhiteColor,WhiteColor,WhiteColor,WhiteColor,WhiteColor,WhiteColor
        defb BlackColor,BlackColor,BlackColor,BlackColor,BlackColor,BlackColor,BlackColor,BlackColor
        defb BlackColor,BlackColor,BlackColor,BlackColor,BlackColor,BlackColor,BlackColor,BlackColor
PieceAliveInit:
        defb 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        defb 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

; Move list format: piece, toFile, toRank, capturedPiece-or-FF.
; REV5 is still tiny enough for this demo IDE, but the line is built as
; an attacking self-play game: both sides develop, castle, trade material,
; and take captures when they appear.  The THINK delay and side scores make
; the fight easier to follow on the real hardware.
MoveList:
        ; 1. e4 e5
        defb 12,4,4,0ffh       ; white e-pawn e2-e4
        defb 28,4,3,0ffh       ; black e-pawn e7-e5
        ; 2. Nf3 Nc6
        defb 6,5,5,0ffh
        defb 17,2,2,0ffh
        ; 3. Bc4 Nf6
        defb 5,2,4,0ffh
        defb 22,5,2,0ffh
        ; 4. d4 d6
        defb 11,3,4,0ffh
        defb 27,3,2,0ffh
        ; 5. Nc3 Be7
        defb 1,2,5,0ffh
        defb 21,4,1,0ffh
        ; 6. O-O style: king then rook
        defb 4,6,7,0ffh
        defb 7,5,7,0ffh
        ; 6... O-O style: king then rook
        defb 20,6,0,0ffh
        defb 23,5,0,0ffh
        ; 7. Re1 Bg4
        defb 7,4,7,0ffh
        defb 18,6,4,0ffh
        ; 8. h3 Bxf3
        defb 15,7,5,0ffh
        defb 18,5,5,6          ; black bishop captures white knight f3
        ; 9. Qxf3 Nxd4
        defb 3,5,5,18          ; white queen captures that bishop
        defb 22,3,4,11         ; black knight captures white d-pawn
        ; 10. Qd1 c6
        defb 3,3,7,0ffh
        defb 26,2,2,0ffh
        ; 11. Be3 b5
        defb 2,4,5,0ffh
        defb 25,1,3,0ffh
        ; 12. Bb3 a5
        defb 5,1,5,0ffh
        defb 24,0,3,0ffh
        ; 13. Bxd4 exd4
        defb 2,3,4,22          ; white bishop captures knight on d4
        defb 28,3,4,2          ; black e-pawn recaptures on d4
        ; Reset marker.
        defb 0ffh

NoTmsMsg:
        defb "TMSEMU3 / TMS9918A not found, aborting!$"

; Text tile strings.  Tiles 32..57 are A..Z, 58 is dash, 59 is space, 60..69 are 0..9.
TitleText:
        defb 50,47,49,40,51,36,59,34,39,36,50,50,59,49,36,53,65,0
FooterText:
        defb 50,36,43,37,59,47,43,32,56,59,58,59,32,45,56,59,42,36,56,59,36,55,40,51,50,0
WhiteText:
        defb 54,39,40,51,36,0
BlackText:
        defb 33,43,32,34,42,0
ScoreText:
        defb 50,34,46,49,36,0
ThinkText:
        defb 51,39,40,45,42,0
FileLabelText:
        defb 32,59,33,59,34,59,35,59,36,59,37,59,38,59,39,0

; ------------------------------------------------------------
; Tile colors. Graphics I has one color byte per 8 tile patterns.
; high nibble foreground, low nibble background.

TileColorTable:
        ; 0-7: white frame / stars / accents
        defb 0f1h
        ; 8-15: tan board squares (light tan background, darker-tan foreground)
        defb 0abh
        ; 16-23 unused
        defb 0f1h
        ; 24-31 unused
        defb 0f1h
        ; 32-39 A-H title/text gold
        defb 0b1h
        ; 40-47 I-P title/text gold
        defb 0b1h
        ; 48-55 Q-X title/text gold
        defb 0b1h
        ; 56-63 Y/Z/dash/space/0-3 gold
        defb 0b1h
        ; 64-71 4-9 gold
        defb 0b1h
        ; pad rest of color table
        defb 0f1h,0f1h,0f1h,0f1h,0f1h,0f1h,0f1h
        defb 0f1h,0f1h,0f1h,0f1h,0f1h,0f1h,0f1h,0f1h
        defb 0f1h,0f1h,0f1h,0f1h,0f1h,0f1h,0f1h,0f1h
        defb 0f1h,0f1h,0f1h,0f1h,0f1h,0f1h,0f1h

; ------------------------------------------------------------
; Tile patterns.

TilePatterns:
        ; 0 blank
        defb 00h,00h,00h,00h,00h,00h,00h,00h
        ; 1 horizontal frame - ornate chrome rail
        defb 0ffh,081h,0bdh,081h,081h,0bdh,081h,0ffh
        ; 2 vertical frame - ornate chrome pillar
        defb 0e7h,0a5h,099h,0bdh,0bdh,099h,0a5h,0e7h
        ; 3 corner jewel
        defb 0ffh,0c3h,099h,0a5h,0bdh,099h,0c3h,0ffh
        ; 4 star sparkle
        defb 00h,10h,38h,07ch,38h,10h,00h,00h
        ; 5 accent jewel
        defb 00h,66h,0ffh,066h,066h,0ffh,066h,00h
        ; 6-7 unused
        defb 00h,00h,00h,00h,00h,00h,00h,00h
        defb 00h,00h,00h,00h,00h,00h,00h,00h
        ; 8 light square - light tan with darker-tan accent specks
        defb 00h,024h,000h,081h,000h,024h,000h,081h
        ; 9 dark square - darker tan with a denser pattern
        defb 0aah,055h,0aah,0f7h,0deh,0aah,055h,0aah
        ; 10-31 unused
        defs 176,0

        ; 32 A
        defb 18h,3ch,66h,66h,7eh,66h,66h,00h
        ; 33 B
        defb 7ch,66h,66h,7ch,66h,66h,7ch,00h
        ; 34 C
        defb 3ch,66h,60h,60h,60h,66h,3ch,00h
        ; 35 D
        defb 78h,6ch,66h,66h,66h,6ch,78h,00h
        ; 36 E
        defb 7eh,60h,60h,7ch,60h,60h,7eh,00h
        ; 37 F
        defb 7eh,60h,60h,7ch,60h,60h,60h,00h
        ; 38 G
        defb 3eh,60h,60h,6eh,66h,66h,3eh,00h
        ; 39 H
        defb 66h,66h,66h,7eh,66h,66h,66h,00h
        ; 40 I
        defb 7eh,18h,18h,18h,18h,18h,7eh,00h
        ; 41 J
        defb 1eh,0ch,0ch,0ch,0ch,6ch,38h,00h
        ; 42 K
        defb 66h,6ch,78h,70h,78h,6ch,66h,00h
        ; 43 L
        defb 60h,60h,60h,60h,60h,60h,7eh,00h
        ; 44 M
        defb 63h,77h,7fh,6bh,63h,63h,63h,00h
        ; 45 N
        defb 66h,76h,7eh,7eh,6eh,66h,66h,00h
        ; 46 O
        defb 3ch,66h,66h,66h,66h,66h,3ch,00h
        ; 47 P
        defb 7ch,66h,66h,7ch,60h,60h,60h,00h
        ; 48 Q
        defb 3ch,66h,66h,66h,6eh,6ch,36h,00h
        ; 49 R
        defb 7ch,66h,66h,7ch,78h,6ch,66h,00h
        ; 50 S
        defb 3eh,60h,60h,3ch,06h,06h,7ch,00h
        ; 51 T
        defb 7eh,18h,18h,18h,18h,18h,18h,00h
        ; 52 U
        defb 66h,66h,66h,66h,66h,66h,3ch,00h
        ; 53 V
        defb 66h,66h,66h,66h,66h,3ch,18h,00h
        ; 54 W
        defb 63h,63h,63h,6bh,7fh,77h,63h,00h
        ; 55 X
        defb 66h,66h,3ch,18h,3ch,66h,66h,00h
        ; 56 Y
        defb 66h,66h,3ch,18h,18h,18h,18h,00h
        ; 57 Z
        defb 7eh,06h,0ch,18h,30h,60h,7eh,00h
        ; 58 dash
        defb 00h,00h,00h,7eh,00h,00h,00h,00h
        ; 59 space
        defb 00h,00h,00h,00h,00h,00h,00h,00h
        ; 60 digit 0
        defb 3ch,66h,6eh,76h,66h,66h,3ch,00h
        ; 61 digit 1
        defb 18h,38h,18h,18h,18h,18h,7eh,00h
        ; 62 digit 2
        defb 3ch,66h,06h,0ch,18h,30h,7eh,00h
        ; 63 digit 3
        defb 3ch,66h,06h,1ch,06h,66h,3ch,00h
        ; 64 digit 4
        defb 0ch,1ch,3ch,6ch,7eh,0ch,0ch,00h
        ; 65 digit 5
        defb 7eh,60h,7ch,06h,06h,66h,3ch,00h
        ; 66 digit 6
        defb 1ch,30h,60h,7ch,66h,66h,3ch,00h
        ; 67 digit 7
        defb 7eh,66h,06h,0ch,18h,18h,18h,00h
        ; 68 digit 8
        defb 3ch,66h,66h,3ch,66h,66h,3ch,00h
        ; 69 digit 9
        defb 3ch,66h,66h,3eh,06h,0ch,38h,00h
        ; 70-79 unused
        defs 80,0
TilePatternsEnd:

; ------------------------------------------------------------
; 16x16 sprite piece glyphs.
; TMS 16x16 sprite pattern order:
;   upper-left 8 bytes, lower-left 8, upper-right 8, lower-right 8.

SpritePatterns:
        ; Pattern 0 PAWN - solid rounded pawn
        defb 00h,00h,03h,07h,07h,07h,07h,07h
        defb 0fh,0fh,1fh,1fh,1fh,1fh,00h,00h
        defb 00h,00h,0c0h,0e0h,0e0h,0e0h,0e0h,0e0h
        defb 0f0h,0f0h,0f8h,0f8h,0f8h,0f8h,00h,00h

        ; Pattern 4 ROOK - solid castle tower
        defb 00h,1fh,1fh,1fh,0fh,0fh,0fh,0fh
        defb 0fh,1fh,1fh,3fh,3fh,3fh,00h,00h
        defb 00h,0f8h,0f8h,0f8h,0f0h,0f0h,0f0h,0f0h
        defb 0f0h,0f8h,0f8h,0fch,0fch,0fch,00h,00h

        ; Pattern 8 KNIGHT - solid horse head
        defb 00h,03h,07h,0fh,0fh,0fh,0fh,07h
        defb 07h,0fh,1fh,1fh,3fh,3fh,00h,00h
        defb 00h,0c0h,0e0h,0f0h,0f8h,0f8h,0f8h,0f0h
        defb 0f0h,0f8h,0fch,0fch,0fch,0fch,00h,00h

        ; Pattern 12 BISHOP - solid bishop with pointed top
        defb 00h,03h,07h,07h,07h,07h,07h,07h
        defb 0fh,0fh,1fh,1fh,3fh,3fh,00h,00h
        defb 00h,0c0h,0e0h,0e0h,0e0h,0e0h,0e0h,0e0h
        defb 0f0h,0f0h,0f8h,0f8h,0fch,0fch,00h,00h

        ; Pattern 16 QUEEN - solid crowned queen
        defb 00h,07h,0fh,1fh,1fh,0fh,0fh,0fh
        defb 1fh,1fh,3fh,3fh,3fh,3fh,00h,00h
        defb 00h,0e0h,0f0h,0f8h,0fch,0f8h,0f8h,0f8h
        defb 0fch,0fch,0feh,0feh,0feh,0feh,00h,00h

        ; Pattern 20 KING - solid king with cross top
        defb 00h,03h,03h,07h,07h,07h,07h,07h
        defb 0fh,0fh,1fh,1fh,3fh,3fh,00h,00h
        defb 00h,0c0h,0c0h,0e0h,0e0h,0e0h,0e0h,0e0h
        defb 0f0h,0f0h,0f8h,0f8h,0fch,0fch,00h,00h

SpritePatternsEnd:

; ------------------------------------------------------------
; Private program stack.

StackSpace:
        defs    256,0
Stack:

        include "tms.asm"
        include "z180.asm"
        include "utility.asm"

        end
