; CHESSAUTO_REV7_SMARTDRAW.ASM
; SC720 / Z80-Z180 + TMSEMU3 / TMS9918A
; Pretty self-playing sprite chess show for the TMSAsmBuilder REV8 IDE.
;
; Build with the IDE/sjasmplus path, not CP/M ASM.COM.
;
; What this REV7 does:
;   - black background
;   - tiled 8x8 chess board with tan and darker-tan squares plus a bright frame
;   - all chess men are TMS sprites, one 16x16 sprite per piece
;   - white and black use the same clean solid glyph sprite shapes in bright white and deep black
;   - one piece animates smoothly from square to square
;   - bigger rule-aware chess brain chooses moves from the live board
;   - captures remove the captured sprite
;   - REV7 adds draw detection, promotion, bigger anti-loop memory, and large heuristic brain tables
;   - press any CP/M console key to exit
;
; Important TMS9918A note:
;   The real TMS9918A only displays 4 sprites on the same scanline.
;   This demo is intentionally "all-sprite" because it looks neat in motion.
;   REV7 keeps the captured-piece 208 terminator fix and prioritizes
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
        ; Row 1, col 7: SPRITE CHESS REV7, centered
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
        ; REV6: disabled the random background sparkles.
        ; They looked neat, but they could overwrite BLACK/SCORE/00 tiles
        ; and make the score panel look corrupted after a while.
        ret

; ------------------------------------------------------------
; Piece setup and rule-aware self-play engine.
;
; REV6 no longer replays a fixed move list.  It keeps a real 64-square
; board in RAM, scans the side-to-move pieces, tests rule-shaped moves,
; scores every legal candidate, and animates the best one.
;
; Implemented chess rules for this tiny show engine:
;   - board occupancy and own-piece blocking
;   - pawn one-step, two-step from home rank, and diagonal captures
;   - knight jumps
;   - bishop/rook/queen sliding with path blocking
;   - king one-square moves
;   - no king captures; long games restart cleanly
;
; Intentionally omitted for size/display simplicity:
;   - en passant
;   - castling
;   - full tournament-grade check/checkmate search
;
; The goal is a much smarter self-playing display that really follows the
; normal movement rules and fights for material/center/development.

ResetPieces:
        ld      hl,PieceXInit
        ld      de,PieceX
        ld      bc,32
        ldir
        ld      hl,PieceYInit
        ld      de,PieceY
        ld      bc,32
        ldir
        ld      hl,PieceFileInit
        ld      de,PieceFile
        ld      bc,32
        ldir
        ld      hl,PieceRankInit
        ld      de,PieceRank
        ld      bc,32
        ldir
        ld      hl,PieceTypeInit
        ld      de,PieceType
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
        ld      hl,BoardInit
        ld      de,Board
        ld      bc,64
        ldir
        xor     a
        ld      (ActiveFlag),a
        ld      (ThinkingFlag),a
        ld      (WhiteScore10),a
        ld      (WhiteScore1),a
        ld      (BlackScore10),a
        ld      (BlackScore1),a
        ld      (CurrentSide),a        ; white begins
        ld      (GamePly),a
        ld      (LastPiece),a
        ld      a,0ffh
        ld      (LastFromFile),a
        ld      (LastFromRank),a
        ld      (LastToFile),a
        ld      (LastToRank),a
        ld      (Last2Piece),a
        ld      (Last3Piece),a
        xor     a
        ld      (NoProgressPly),a
        ld      (DrawsPlayed),a
        ld      (BrainIndex),a
        call    DrawSideScores
        call    ClearThinkTags
        ret

ResetMoveList:
        ; Kept as a familiar entry point for the main program.
        xor     a
        ld      (ActiveFlag),a
        ld      (ThinkingFlag),a
        ld      (MovePause),a
        ld      (CurrentSide),a
        ld      (GamePly),a
        ld      (NoProgressPly),a
        ret

RestartGame:
        ; Clean full reset.  Used after a long game or no legal move.
        call    DrawScreen
        call    ResetPieces
        call    WriteSprites
        ld      a,30
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
        jp      nz,FinishLoadBestMove
        jp      BeginThinking

BeginThinking:
        call    ChooseBestMove
        ld      a,(BestFound)
        or      a
        jp      z,DrawGame
        ld      a,(BestPiece)
        ld      (ActivePiece),a
        call    DrawThinkingStatus
        call    Rand8
        and     31
        add     a,20                    ; 20..51 frames of visible thinking
        ld      (MovePause),a
        ld      a,1
        ld      (ThinkingFlag),a
        ret

FinishLoadBestMove:
        xor     a
        ld      (ThinkingFlag),a
        call    ClearThinkTags

        ; Move chosen by the engine: BestPiece -> BestFile/BestRank.
        ld      a,(BestPiece)
        ld      (ActivePiece),a
        ld      a,(BestFile)
        ld      (TargetFile),a
        call    FileToPixelX
        ld      (TargetX),a
        ld      a,(BestRank)
        ld      (TargetRank),a
        call    RankToPixelY
        ld      (TargetY),a

        ; Roll a 3-ply anti-loop memory before remembering this move.
        ld      a,(Last2Piece)
        ld      (Last3Piece),a
        ld      a,(LastPiece)
        ld      (Last2Piece),a

        ; Remember old square for anti-loop logic.
        ld      a,(BestPiece)
        call    PtrPieceFile
        ld      a,(hl)
        ld      (LastFromFile),a
        ld      a,(BestPiece)
        call    PtrPieceRank
        ld      a,(hl)
        ld      (LastFromRank),a
        ld      a,(BestPiece)
        ld      (LastPiece),a
        ld      a,(BestFile)
        ld      (LastToFile),a
        ld      a,(BestRank)
        ld      (LastToRank),a

        ; Remove a captured piece, if any.
        ld      a,(BestCapture)
        ld      (CapturePiece),a
        cp      0ffh
        jp      z,BestNoCapture
        call    ScoreCapture
        ld      a,(BestCapture)
        call    KillPiece
BestNoCapture:
        ; Update RAM board immediately.  Animation still uses old sprite X/Y.
        ld      a,(BestPiece)
        call    PtrPieceFile
        ld      a,(hl)
        ld      (FromFile),a
        ld      a,(BestPiece)
        call    PtrPieceRank
        ld      a,(hl)
        ld      (FromRank),a

        ld      a,(FromFile)
        ld      b,a
        ld      a,(FromRank)
        ld      c,a
        ld      a,b
        ld      b,c
        call    BoardPtrByFileRank
        ld      (hl),0ffh

        ld      a,(BestFile)
        ld      b,a
        ld      a,(BestRank)
        ld      c,a
        ld      a,b
        ld      b,c
        call    BoardPtrByFileRank
        ld      a,(BestPiece)
        ld      (hl),a

        ; Update logical file/rank now.  Pixel X/Y catches up in animation.
        ld      a,(BestPiece)
        call    PtrPieceFile
        ld      a,(BestFile)
        ld      (hl),a
        ld      a,(BestPiece)
        call    PtrPieceRank
        ld      a,(BestRank)
        ld      (hl),a

        ld      a,1
        ld      (ActiveFlag),a
        jp      AnimateActiveMove

; ------------------------------------------------------------
; Move chooser.

ChooseBestMove:
        xor     a
        ld      (BestFound),a
        ld      (BestScore),a

        ld      a,(CurrentSide)
        or      a
        jp      z,ChooseWhitePieces
ChooseBlackPieces:
        ld      a,16
        ld      (PieceLoop),a
        ld      a,32
        ld      (EndPiece),a
        jp      ChoosePieceLoop
ChooseWhitePieces:
        xor     a
        ld      (PieceLoop),a
        ld      a,16
        ld      (EndPiece),a

ChoosePieceLoop:
        ld      a,(PieceLoop)
        ld      b,a
        ld      a,(EndPiece)
        cp      b
        jp      z,ChooseDone

        ld      a,(PieceLoop)
        ld      (CandidatePiece),a
        call    PtrPieceAlive
        ld      a,(hl)
        or      a
        jp      z,ChooseNextPiece

        ld      a,(CandidatePiece)
        call    PtrPieceFile
        ld      a,(hl)
        ld      (FromFile),a
        ld      a,(CandidatePiece)
        call    PtrPieceRank
        ld      a,(hl)
        ld      (FromRank),a

        xor     a
        ld      (TargetRank),a
ChooseRankLoop:
        xor     a
        ld      (TargetFile),a
ChooseFileLoop:
        call    CheckLegalMove
        call    c,ScoreAndMaybeBest

        ld      hl,TargetFile
        inc     (hl)
        ld      a,(hl)
        cp      8
        jp      c,ChooseFileLoop

        ld      hl,TargetRank
        inc     (hl)
        ld      a,(hl)
        cp      8
        jp      c,ChooseRankLoop

ChooseNextPiece:
        ld      hl,PieceLoop
        inc     (hl)
        jp      ChoosePieceLoop

ChooseDone:
        ret

ScoreAndMaybeBest:
        call    ScoreCandidate
        jp      MaybeStoreBest

MaybeStoreBest:
        ld      a,(BestFound)
        or      a
        jp      z,StoreBestMove
        ld      a,(BestScore)
        ld      b,a
        ld      a,(CandScore)
        cp      b
        jp      c,MaybeBestDone
        jp      z,MaybeTieBest
        jp      StoreBestMove
MaybeTieBest:
        call    Rand8
        and     1
        jp      z,MaybeBestDone
StoreBestMove:
        ld      a,1
        ld      (BestFound),a
        ld      a,(CandScore)
        ld      (BestScore),a
        ld      a,(CandidatePiece)
        ld      (BestPiece),a
        ld      a,(TargetFile)
        ld      (BestFile),a
        ld      a,(TargetRank)
        ld      (BestRank),a
        ld      a,(TargetOccupant)
        ld      (BestCapture),a
MaybeBestDone:
        ret

; ------------------------------------------------------------
; Legal move test.
; Returns carry set if the candidate is legal enough for this tiny engine.

CheckLegalMove:
        ; Reject same square.
        ld      a,(TargetFile)
        ld      b,a
        ld      a,(FromFile)
        cp      b
        jp      nz,LegalNotSame
        ld      a,(TargetRank)
        ld      b,a
        ld      a,(FromRank)
        cp      b
        jp      z,LegalNo
LegalNotSame:
        call    ComputeDelta
        call    GetTargetOccupant

        ; Cannot land on your own piece.
        ld      a,(TargetOccupant)
        cp      0ffh
        jp      z,LegalTargetOpen
        ld      b,a
        ld      a,(CurrentSide)
        or      a
        jp      z,LegalWhiteOwnCheck
LegalBlackOwnCheck:
        ld      a,b
        cp      16
        jp      nc,LegalNo
        jp      LegalEnemyCheckKing
LegalWhiteOwnCheck:
        ld      a,b
        cp      16
        jp      c,LegalNo
LegalEnemyCheckKing:
        ; Kings are never captured.  This avoids non-chess king captures.
        ld      a,b
        call    PtrPieceType
        ld      a,(hl)
        cp      TypeKing
        jp      z,LegalNo
LegalTargetOpen:
        ; Anti-loop: do not immediately move the same piece back to its
        ; previous square unless it is making a capture.
        ld      a,(TargetOccupant)
        cp      0ffh
        jp      nz,LegalNoRepeatNeeded
        ld      a,(CandidatePiece)
        ld      b,a
        ld      a,(LastPiece)
        cp      b
        jp      nz,LegalNoRepeatNeeded
        ld      a,(TargetFile)
        ld      b,a
        ld      a,(LastFromFile)
        cp      b
        jp      nz,LegalNoRepeatNeeded
        ld      a,(TargetRank)
        ld      b,a
        ld      a,(LastFromRank)
        cp      b
        jp      z,LegalNo
LegalNoRepeatNeeded:
        ld      a,(CandidatePiece)
        call    PtrPieceType
        ld      a,(hl)
        cp      TypePawn
        jp      z,CheckPawnMove
        cp      TypeKnight
        jp      z,CheckKnightMove
        cp      TypeBishop
        jp      z,CheckBishopMove
        cp      TypeRook
        jp      z,CheckRookMove
        cp      TypeQueen
        jp      z,CheckQueenMove
        cp      TypeKing
        jp      z,CheckKingMove
        jp      LegalNo

ComputeDelta:
        ld      a,(TargetFile)
        ld      b,a
        ld      a,(FromFile)
        ld      c,a
        ld      a,b
        sub     c
        ld      (Dx),a
        call    AbsA
        ld      (AbsDX),a

        ld      a,(TargetRank)
        ld      b,a
        ld      a,(FromRank)
        ld      c,a
        ld      a,b
        sub     c
        ld      (Dy),a
        call    AbsA
        ld      (AbsDY),a
        ret

AbsA:
        cp      80h
        ret     c
        cpl
        inc     a
        ret

GetTargetOccupant:
        ld      a,(TargetFile)
        ld      b,a
        ld      a,(TargetRank)
        ld      c,a
        ld      a,b
        ld      b,c
        call    BoardPtrByFileRank
        ld      a,(hl)
        ld      (TargetOccupant),a
        ret

; A=file, B=rank. Returns HL = Board + rank*8 + file.
BoardPtrByFileRank:
        ld      c,a                     ; C = file
        ld      a,b                     ; A = rank
        ld      l,a
        ld      h,0
        add     hl,hl                   ; *2
        add     hl,hl                   ; *4
        add     hl,hl                   ; *8
        ld      e,c
        ld      d,0
        add     hl,de
        ld      de,Board
        add     hl,de
        ret

CheckPawnMove:
        ld      a,(CurrentSide)
        or      a
        jp      z,CheckWhitePawn

CheckBlackPawn:
        ; forward one: same file, dy=+1, empty target.
        ld      a,(AbsDX)
        or      a
        jp      nz,BlackPawnCaptureTest
        ld      a,(TargetOccupant)
        cp      0ffh
        jp      nz,LegalNo
        ld      a,(Dy)
        cp      1
        jp      z,LegalYes
        cp      2
        jp      nz,LegalNo
        ld      a,(FromRank)
        cp      1
        jp      nz,LegalNo
        ; Check square between source and target.
        ld      a,(FromFile)
        ld      b,a
        ld      a,2                     ; rank 2
        ld      c,a
        ld      a,b
        ld      b,c
        call    BoardPtrByFileRank
        ld      a,(hl)
        cp      0ffh
        jp      z,LegalYes
        jp      LegalNo
BlackPawnCaptureTest:
        ld      a,(AbsDX)
        cp      1
        jp      nz,LegalNo
        ld      a,(Dy)
        cp      1
        jp      nz,LegalNo
        ld      a,(TargetOccupant)
        cp      0ffh
        jp      nz,LegalYes
        jp      LegalNo

CheckWhitePawn:
        ; forward one: same file, dy=-1, empty target.
        ld      a,(AbsDX)
        or      a
        jp      nz,WhitePawnCaptureTest
        ld      a,(TargetOccupant)
        cp      0ffh
        jp      nz,LegalNo
        ld      a,(Dy)
        cp      0ffh
        jp      z,LegalYes
        cp      0feh
        jp      nz,LegalNo
        ld      a,(FromRank)
        cp      6
        jp      nz,LegalNo
        ; Check square between source and target.
        ld      a,(FromFile)
        ld      b,a
        ld      a,5                     ; rank 5
        ld      c,a
        ld      a,b
        ld      b,c
        call    BoardPtrByFileRank
        ld      a,(hl)
        cp      0ffh
        jp      z,LegalYes
        jp      LegalNo
WhitePawnCaptureTest:
        ld      a,(AbsDX)
        cp      1
        jp      nz,LegalNo
        ld      a,(Dy)
        cp      0ffh
        jp      nz,LegalNo
        ld      a,(TargetOccupant)
        cp      0ffh
        jp      nz,LegalYes
        jp      LegalNo

CheckKnightMove:
        ld      a,(AbsDX)
        cp      1
        jp      nz,KnightTryOther
        ld      a,(AbsDY)
        cp      2
        jp      z,LegalYes
        jp      LegalNo
KnightTryOther:
        cp      2
        jp      nz,LegalNo
        ld      a,(AbsDY)
        cp      1
        jp      z,LegalYes
        jp      LegalNo

CheckKingMove:
        ld      a,(AbsDX)
        cp      2
        jp      nc,LegalNo
        ld      a,(AbsDY)
        cp      2
        jp      nc,LegalNo
        jp      LegalYes

CheckBishopMove:
        ld      a,(AbsDX)
        or      a
        jp      z,LegalNo
        ld      b,a
        ld      a,(AbsDY)
        cp      b
        jp      nz,LegalNo
        jp      PathClear

CheckRookMove:
        ld      a,(AbsDX)
        or      a
        jp      z,RookLineMaybe
        ld      a,(AbsDY)
        or      a
        jp      z,RookLineMaybe
        jp      LegalNo
RookLineMaybe:
        jp      PathClear

CheckQueenMove:
        ; Queen can use either bishop or rook movement.
        ld      a,(AbsDX)
        ld      b,a
        ld      a,(AbsDY)
        cp      b
        jp      z,QueenBishopMaybe
        ld      a,(AbsDX)
        or      a
        jp      z,QueenRookMaybe
        ld      a,(AbsDY)
        or      a
        jp      z,QueenRookMaybe
        jp      LegalNo
QueenBishopMaybe:
        ld      a,(AbsDX)
        or      a
        jp      z,LegalNo
        jp      PathClear
QueenRookMaybe:
        jp      PathClear

PathClear:
        call    SetMoveSteps
        ld      a,(FromFile)
        ld      b,a
        ld      a,(StepFile)
        add     a,b
        ld      (PathFile),a
        ld      a,(FromRank)
        ld      b,a
        ld      a,(StepRank)
        add     a,b
        ld      (PathRank),a
PathLoop:
        ld      a,(PathFile)
        ld      b,a
        ld      a,(TargetFile)
        cp      b
        jp      nz,PathCheckSquare
        ld      a,(PathRank)
        ld      b,a
        ld      a,(TargetRank)
        cp      b
        jp      z,LegalYes
PathCheckSquare:
        ld      a,(PathFile)
        ld      b,a
        ld      a,(PathRank)
        ld      c,a
        ld      a,b
        ld      b,c
        call    BoardPtrByFileRank
        ld      a,(hl)
        cp      0ffh
        jp      nz,LegalNo
        ld      a,(PathFile)
        ld      b,a
        ld      a,(StepFile)
        add     a,b
        ld      (PathFile),a
        ld      a,(PathRank)
        ld      b,a
        ld      a,(StepRank)
        add     a,b
        ld      (PathRank),a
        jp      PathLoop

SetMoveSteps:
        xor     a
        ld      (StepFile),a
        ld      (StepRank),a
        ld      a,(Dx)
        or      a
        jp      z,StepRankPart
        cp      80h
        jp      nc,StepFileNeg
        ld      a,1
        ld      (StepFile),a
        jp      StepRankPart
StepFileNeg:
        ld      a,0ffh
        ld      (StepFile),a
StepRankPart:
        ld      a,(Dy)
        or      a
        ret     z
        cp      80h
        jp      nc,StepRankNeg
        ld      a,1
        ld      (StepRank),a
        ret
StepRankNeg:
        ld      a,0ffh
        ld      (StepRank),a
        ret

LegalYes:
        scf
        ret
LegalNo:
        or      a                       ; clear carry
        ret

; ------------------------------------------------------------
; Candidate scoring.  Higher wins.

ScoreCandidate:
        ld      a,18
        ld      (CandScore),a

        ; Captures dominate the score.
        ld      a,(TargetOccupant)
        cp      0ffh
        jp      z,ScoreNoCapture
        call    PtrPieceType
        ld      a,(hl)
        call    ValueForPieceType
        call    ScoreAddA
        ld      a,18
        call    ScoreAddA
ScoreNoCapture:
        ; Center control.
        ld      a,(TargetFile)
        cp      2
        jp      c,ScoreNoWideCenter
        cp      6
        jp      nc,ScoreNoWideCenter
        ld      a,(TargetRank)
        cp      2
        jp      c,ScoreNoWideCenter
        cp      6
        jp      nc,ScoreNoWideCenter
        ld      a,6
        call    ScoreAddA
ScoreNoWideCenter:
        ld      a,(TargetFile)
        cp      3
        jp      c,ScoreNoHotCenter
        cp      5
        jp      nc,ScoreNoHotCenter
        ld      a,(TargetRank)
        cp      3
        jp      c,ScoreNoHotCenter
        cp      5
        jp      nc,ScoreNoHotCenter
        ld      a,8
        call    ScoreAddA
ScoreNoHotCenter:
        ; Pawn advancement.
        ld      a,(CandidatePiece)
        call    PtrPieceType
        ld      a,(hl)
        cp      TypePawn
        jp      nz,ScoreNoPawnBonus
        ld      a,(CurrentSide)
        or      a
        jp      z,ScoreWhitePawnBonus
ScoreBlackPawnBonus:
        ld      a,(TargetRank)
        add     a,a
        call    ScoreAddA
        jp      ScoreNoPawnBonus
ScoreWhitePawnBonus:
        ld      a,7
        ld      b,a
        ld      a,(TargetRank)
        ld      c,a
        ld      a,b
        sub     c
        add     a,a
        call    ScoreAddA
ScoreNoPawnBonus:
        ; Develop knights and bishops away from home rank.
        ld      a,(CandidatePiece)
        call    PtrPieceType
        ld      a,(hl)
        cp      TypeKnight
        jp      z,ScoreMaybeDevelop
        cp      TypeBishop
        jp      nz,ScoreNoDevelop
ScoreMaybeDevelop:
        ld      a,(CurrentSide)
        or      a
        jp      z,ScoreWhiteDevelop
ScoreBlackDevelop:
        ld      a,(FromRank)
        or      a
        jp      nz,ScoreNoDevelop
        ld      a,10
        call    ScoreAddA
        jp      ScoreNoDevelop
ScoreWhiteDevelop:
        ld      a,(FromRank)
        cp      7
        jp      nz,ScoreNoDevelop
        ld      a,10
        call    ScoreAddA
ScoreNoDevelop:
        call    ScoreAdvancedBrain

        ; Small deterministic variety.
        call    Rand8
        and     7
        call    ScoreAddA
        ret

; ------------------------------------------------------------
; REV7 expanded heuristic brain.
; These routines are deliberately table-heavy so the final COM has a much
; larger real chess brain instead of just graphics and a tiny move picker.

ScoreAdvancedBrain:
        call    ScorePieceSquareBonus
        call    ScorePawnStructureBonus
        call    ScorePromotionBonus
        call    ScoreSafetyPenalty
        call    ScoreHistoryPenalty
        call    ScoreBrainHashBonus
        ret

ScorePieceSquareBonus:
        ld      a,(CandidatePiece)
        call    PtrPieceType
        ld      a,(hl)
        cp      TypePawn
        jp      z,ScorePawnSquare
        cp      TypeRook
        jp      z,ScoreRookSquare
        cp      TypeKnight
        jp      z,ScoreKnightSquare
        cp      TypeBishop
        jp      z,ScoreBishopSquare
        cp      TypeQueen
        jp      z,ScoreQueenSquare
        cp      TypeKing
        jp      z,ScoreKingSquare
        ret
ScorePawnSquare:
        ld      hl,PawnSquareTable
        jp      ScoreSquareFromHL
ScoreRookSquare:
        ld      hl,RookSquareTable
        jp      ScoreSquareFromHL
ScoreKnightSquare:
        ld      hl,KnightSquareTable
        jp      ScoreSquareFromHL
ScoreBishopSquare:
        ld      hl,BishopSquareTable
        jp      ScoreSquareFromHL
ScoreQueenSquare:
        ld      hl,QueenSquareTable
        jp      ScoreSquareFromHL
ScoreKingSquare:
        ld      hl,KingSquareTable
        jp      ScoreSquareFromHL

ScoreSquareFromHL:
        call    AddTargetIndexToHLAndRead
        call    ScoreAddA
        ret

ScorePawnStructureBonus:
        ld      a,(CandidatePiece)
        call    PtrPieceType
        ld      a,(hl)
        cp      TypePawn
        ret     nz
        ld      a,(TargetFile)
        cp      3
        jp      c,ScorePawnNotCenterFile
        cp      5
        jp      nc,ScorePawnNotCenterFile
        ld      a,10
        call    ScoreAddA
ScorePawnNotCenterFile:
        ld      a,(TargetFile)
        or      a
        jp      z,ScorePawnEdgePenalty
        cp      7
        jp      z,ScorePawnEdgePenalty
        ld      a,4
        call    ScoreAddA
        ret
ScorePawnEdgePenalty:
        ld      a,5
        jp      ScoreSubA

ScorePromotionBonus:
        ld      a,(CandidatePiece)
        call    PtrPieceType
        ld      a,(hl)
        cp      TypePawn
        ret     nz
        ld      a,(CurrentSide)
        or      a
        jp      z,ScoreWhitePromotion
ScoreBlackPromotion:
        ld      a,(TargetRank)
        cp      7
        jp      z,ScorePromotionNow
        cp      6
        jp      z,ScorePromotionNear
        ret
ScoreWhitePromotion:
        ld      a,(TargetRank)
        or      a
        jp      z,ScorePromotionNow
        cp      1
        jp      z,ScorePromotionNear
        ret
ScorePromotionNow:
        ld      a,90
        jp      ScoreAddA
ScorePromotionNear:
        ld      a,32
        jp      ScoreAddA

ScoreSafetyPenalty:
        ; Avoid obvious pawn traps. This prevents many dead locked trades
        ; where a side repeatedly walks valuable pieces into simple attacks.
        ld      a,(CurrentSide)
        or      a
        jp      z,ScoreWhiteSafety
ScoreBlackSafety:
        call    TargetAttackedByWhitePawn
        ret     nc
        ld      a,28
        jp      ScoreSubA
ScoreWhiteSafety:
        call    TargetAttackedByBlackPawn
        ret     nc
        ld      a,28
        jp      ScoreSubA

TargetAttackedByWhitePawn:
        ; White pawns move upward, so a white pawn attacking target sits one rank below it.
        ld      a,(TargetRank)
        cp      7
        jp      z,TargetNotAttacked
        inc     a
        ld      c,a
        ld      a,(TargetFile)
        or      a
        jp      z,WhitePawnTryRight
        dec     a
        call    CheckWhitePawnAtFileRankC
        ret     c
WhitePawnTryRight:
        ld      a,(TargetFile)
        cp      7
        jp      z,TargetNotAttacked
        inc     a
        call    CheckWhitePawnAtFileRankC
        ret

TargetAttackedByBlackPawn:
        ; Black pawns move downward, so a black pawn attacking target sits one rank above it.
        ld      a,(TargetRank)
        or      a
        jp      z,TargetNotAttacked
        dec     a
        ld      c,a
        ld      a,(TargetFile)
        or      a
        jp      z,BlackPawnTryRight
        dec     a
        call    CheckBlackPawnAtFileRankC
        ret     c
BlackPawnTryRight:
        ld      a,(TargetFile)
        cp      7
        jp      z,TargetNotAttacked
        inc     a
        call    CheckBlackPawnAtFileRankC
        ret

CheckWhitePawnAtFileRankC:
        ld      b,c
        call    BoardPtrByFileRank
        ld      a,(hl)
        cp      0ffh
        jp      z,TargetNotAttacked
        cp      16
        jp      nc,TargetNotAttacked
        call    PtrPieceType
        ld      a,(hl)
        cp      TypePawn
        jp      z,TargetAttacked
        jp      TargetNotAttacked

CheckBlackPawnAtFileRankC:
        ld      b,c
        call    BoardPtrByFileRank
        ld      a,(hl)
        cp      0ffh
        jp      z,TargetNotAttacked
        cp      16
        jp      c,TargetNotAttacked
        call    PtrPieceType
        ld      a,(hl)
        cp      TypePawn
        jp      z,TargetAttacked
TargetNotAttacked:
        or      a
        ret
TargetAttacked:
        scf
        ret

ScoreHistoryPenalty:
        ; Bigger anti-loop memory: discourage using the same piece again and
        ; again unless it is a capture. This allows draws before hard locks.
        ld      a,(TargetOccupant)
        cp      0ffh
        ret     nz
        ld      a,(CandidatePiece)
        ld      b,a
        ld      a,(LastPiece)
        cp      b
        jp      nz,ScoreCheckLast2
        ld      a,24
        call    ScoreSubA
ScoreCheckLast2:
        ld      a,(Last2Piece)
        cp      b
        jp      nz,ScoreCheckLast3
        ld      a,12
        call    ScoreSubA
ScoreCheckLast3:
        ld      a,(Last3Piece)
        cp      b
        ret     nz
        ld      a,8
        jp      ScoreSubA

ScoreBrainHashBonus:
        call    MakeBrainIndex

        ld      a,(CandidatePiece)
        call    PtrPieceType
        ld      a,(hl)
        call    SelectBrainPlane0
        call    AddBrainIndexToHLAndRead
        and     15
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,53
        ld      (BrainIndex),a
        ld      a,(CandidatePiece)
        call    PtrPieceType
        ld      a,(hl)
        call    SelectBrainPlane1
        call    AddBrainIndexToHLAndRead
        and     7
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,97
        ld      (BrainIndex),a
        ld      a,(CandidatePiece)
        call    PtrPieceType
        ld      a,(hl)
        call    SelectBrainPlane2
        call    AddBrainIndexToHLAndRead
        and     7
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,131
        ld      (BrainIndex),a
        ld      a,(CandidatePiece)
        call    PtrPieceType
        ld      a,(hl)
        call    SelectBrainPlane3
        call    AddBrainIndexToHLAndRead
        and     3
        call    ScoreAddA
        ret

MakeBrainIndex:
        ld      a,(TargetRank)
        add     a,a
        add     a,a
        add     a,a
        ld      b,a
        ld      a,(TargetFile)
        add     a,b
        ld      b,a
        ld      a,(CandidatePiece)
        add     a,b
        ld      b,a
        ld      a,(GamePly)
        add     a,b
        ld      b,a
        ld      a,(RandomSeed)
        add     a,b
        ld      (BrainIndex),a
        ret

AddTargetIndexToHLAndRead:
        push    hl
        ld      a,(TargetRank)
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      a,(TargetFile)
        ld      e,a
        ld      d,0
        add     hl,de
        ex      de,hl
        pop     hl
        add     hl,de
        ld      a,(hl)
        ret

AddBrainIndexToHLAndRead:
        ld      a,(BrainIndex)
        ld      e,a
        ld      d,0
        add     hl,de
        ld      a,(hl)
        ret

ScoreSubA:
        ld      b,a
        ld      a,(CandScore)
        cp      b
        jp      c,ScoreSubFloor
        sub     b
        ld      (CandScore),a
        ret
ScoreSubFloor:
        ld      a,1
        ld      (CandScore),a
        ret

SelectBrainPlane0:
        cp      TypePawn
        jp      z,SelB0Pawn
        cp      TypeRook
        jp      z,SelB0Rook
        cp      TypeKnight
        jp      z,SelB0Knight
        cp      TypeBishop
        jp      z,SelB0Bishop
        cp      TypeQueen
        jp      z,SelB0Queen
        ld      hl,Brain0King
        ret
SelB0Pawn:   ld hl,Brain0Pawn
        ret
SelB0Rook:   ld hl,Brain0Rook
        ret
SelB0Knight: ld hl,Brain0Knight
        ret
SelB0Bishop: ld hl,Brain0Bishop
        ret
SelB0Queen:  ld hl,Brain0Queen
        ret

SelectBrainPlane1:
        cp      TypePawn
        jp      z,SelB1Pawn
        cp      TypeRook
        jp      z,SelB1Rook
        cp      TypeKnight
        jp      z,SelB1Knight
        cp      TypeBishop
        jp      z,SelB1Bishop
        cp      TypeQueen
        jp      z,SelB1Queen
        ld      hl,Brain1King
        ret
SelB1Pawn:   ld hl,Brain1Pawn
        ret
SelB1Rook:   ld hl,Brain1Rook
        ret
SelB1Knight: ld hl,Brain1Knight
        ret
SelB1Bishop: ld hl,Brain1Bishop
        ret
SelB1Queen:  ld hl,Brain1Queen
        ret

SelectBrainPlane2:
        cp      TypePawn
        jp      z,SelB2Pawn
        cp      TypeRook
        jp      z,SelB2Rook
        cp      TypeKnight
        jp      z,SelB2Knight
        cp      TypeBishop
        jp      z,SelB2Bishop
        cp      TypeQueen
        jp      z,SelB2Queen
        ld      hl,Brain2King
        ret
SelB2Pawn:   ld hl,Brain2Pawn
        ret
SelB2Rook:   ld hl,Brain2Rook
        ret
SelB2Knight: ld hl,Brain2Knight
        ret
SelB2Bishop: ld hl,Brain2Bishop
        ret
SelB2Queen:  ld hl,Brain2Queen
        ret

SelectBrainPlane3:
        cp      TypePawn
        jp      z,SelB3Pawn
        cp      TypeRook
        jp      z,SelB3Rook
        cp      TypeKnight
        jp      z,SelB3Knight
        cp      TypeBishop
        jp      z,SelB3Bishop
        cp      TypeQueen
        jp      z,SelB3Queen
        ld      hl,Brain3King
        ret
SelB3Pawn:   ld hl,Brain3Pawn
        ret
SelB3Rook:   ld hl,Brain3Rook
        ret
SelB3Knight: ld hl,Brain3Knight
        ret
SelB3Bishop: ld hl,Brain3Bishop
        ret
SelB3Queen:  ld hl,Brain3Queen
        ret

ValueForPieceType:
        ld      hl,PieceValueTable
        jp      AddAToHLAndRead

ScoreAddA:
        ld      b,a
        ld      a,(CandScore)
        add     a,b
        ld      (CandScore),a
        ret

AddAToHLAndRead:
        ld      e,a
        ld      d,0
        add     hl,de
        ld      a,(hl)
        ret

; ------------------------------------------------------------
; Animation and post-move turn handling.

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

        ; REV7: a no-capture / no-pawn-move clock allows real draws.
        ; Nobody gets a win for a draw. The board simply starts over.
        call    UpdateDrawClock
        ld      a,(NoProgressPly)
        cp      DrawPlyLimit
        jp      nc,DrawGame

        call    MaybePromoteBestPawn

        ld      a,(CurrentSide)
        xor     1
        ld      (CurrentSide),a
        ld      hl,GamePly
        inc     (hl)
        ld      a,(hl)
        cp      MaxGamePly             ; safety draw for very long games
        jp      nc,DrawGame
        ld      a,8
        ld      (MovePause),a
        ret

; REV7 draw / promotion handling.

DrawGame:
        ; Draws are neutral.  No side score is awarded.
        ld      hl,DrawsPlayed
        inc     (hl)
        jp      RestartGame

UpdateDrawClock:
        ; Reset draw clock on capture or any pawn move.
        ld      a,(BestCapture)
        cp      0ffh
        jp      nz,ResetDrawClock
        ld      a,(BestPiece)
        call    PtrPieceType
        ld      a,(hl)
        cp      TypePawn
        jp      z,ResetDrawClock
        ld      hl,NoProgressPly
        inc     (hl)
        ret
ResetDrawClock:
        xor     a
        ld      (NoProgressPly),a
        ret

MaybePromoteBestPawn:
        ; Tiny promotion rule: a pawn that reaches the far edge becomes a queen.
        ld      a,(BestPiece)
        call    PtrPieceType
        ld      a,(hl)
        cp      TypePawn
        ret     nz
        ld      a,(CurrentSide)
        or      a
        jp      z,MaybeWhitePromote
MaybeBlackPromote:
        ld      a,(BestRank)
        cp      7
        ret     nz
        jp      PromoteBestToQueen
MaybeWhitePromote:
        ld      a,(BestRank)
        or      a
        ret     nz
PromoteBestToQueen:
        ld      a,(BestPiece)
        call    PtrPieceType
        ld      (hl),TypeQueen
        ld      a,(BestPiece)
        call    PtrPiecePattern
        ld      (hl),PatQueen
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

        ; REV7: if a piece is thinking or moving, write it first in the
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
PtrPieceFile:
        ld      hl,PieceFile
        jp      AddAToHL
PtrPieceRank:
        ld      hl,PieceRank
        jp      AddAToHL
PtrPieceType:
        ld      hl,PieceType
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

; REV7 engine piece-type constants.
TypePawn:       equ 1
TypeRook:       equ 2
TypeKnight:     equ 3
TypeBishop:     equ 4
TypeQueen:      equ 5
TypeKing:       equ 6

DrawPlyLimit:   equ 80        ; 80 quiet plies = draw / reset
MaxGamePly:     equ 220       ; long game safety draw

WhiteColor:     equ 15        ; white
BlackColor:     equ 1         ; true black pieces on the tan board

; ------------------------------------------------------------
; State.

OldSP:          defw 0
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

; REV7 engine state.
CurrentSide:    defb 0       ; 0 white, 1 black
GamePly:        defb 0
BestFound:      defb 0
BestScore:      defb 0
BestPiece:      defb 0
BestFile:       defb 0
BestRank:       defb 0
BestCapture:    defb 0ffh
CandScore:      defb 0
CandidatePiece: defb 0
PieceLoop:      defb 0
EndPiece:       defb 0
FromFile:       defb 0
FromRank:       defb 0
Dx:             defb 0
Dy:             defb 0
AbsDX:          defb 0
AbsDY:          defb 0
StepFile:       defb 0
StepRank:       defb 0
PathFile:       defb 0
PathRank:       defb 0
TargetOccupant: defb 0ffh
LastPiece:      defb 0
LastFromFile:   defb 0ffh
LastFromRank:   defb 0ffh
LastToFile:     defb 0ffh
LastToRank:     defb 0ffh
Last2Piece:     defb 0ffh
Last3Piece:     defb 0ffh
NoProgressPly:  defb 0
DrawsPlayed:    defb 0
BrainIndex:     defb 0

; Index by type: 0, pawn, rook, knight, bishop, queen, king.
PieceValueTable:
        defb 0,22,95,62,64,150,0

; Piece order:
;   00-07 white back rank: R N B Q K B N R
;   08-15 white pawns:     a b c d e f g h
;   16-23 black back rank: R N B Q K B N R
;   24-31 black pawns:     a b c d e f g h

PieceX:
        defs 32,0
PieceY:
        defs 32,0
PieceFile:
        defs 32,0
PieceRank:
        defs 32,0
PieceType:
        defs 32,0
PiecePattern:
        defs 32,0
PieceColor:
        defs 32,0
PieceAlive:
        defs 32,0
Board:
        defs 64,0ffh

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
PieceFileInit:
        defb 0,1,2,3,4,5,6,7
        defb 0,1,2,3,4,5,6,7
        defb 0,1,2,3,4,5,6,7
        defb 0,1,2,3,4,5,6,7
PieceRankInit:
        defb 7,7,7,7,7,7,7,7
        defb 6,6,6,6,6,6,6,6
        defb 0,0,0,0,0,0,0,0
        defb 1,1,1,1,1,1,1,1
PieceTypeInit:
        defb TypeRook,TypeKnight,TypeBishop,TypeQueen,TypeKing,TypeBishop,TypeKnight,TypeRook
        defb TypePawn,TypePawn,TypePawn,TypePawn,TypePawn,TypePawn,TypePawn,TypePawn
        defb TypeRook,TypeKnight,TypeBishop,TypeQueen,TypeKing,TypeBishop,TypeKnight,TypeRook
        defb TypePawn,TypePawn,TypePawn,TypePawn,TypePawn,TypePawn,TypePawn,TypePawn
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

; Board is rank-major, rank 0 at the top / black home side.
BoardInit:
        defb 16,17,18,19,20,21,22,23
        defb 24,25,26,27,28,29,30,31
        defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
        defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
        defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
        defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
        defb 8,9,10,11,12,13,14,15
        defb 0,1,2,3,4,5,6,7

; ------------------------------------------------------------
; REV7 position tables and tactical hash planes.
; These add real COM size and feed the move scorer every turn.

PawnSquareTable:
        defb 7,7,7,10,10,7,7,7,6,6,6,9,9,6,6,6
        defb 5,5,5,8,8,5,5,5,4,4,4,7,7,4,4,4
        defb 4,4,4,7,7,4,4,4,5,5,5,8,8,5,5,5
        defb 6,6,6,9,9,6,6,6,7,7,7,10,10,7,7,7

RookSquareTable:
        defb 4,4,4,7,7,4,4,4,6,6,6,9,9,6,6,6
        defb 6,6,6,9,9,6,6,6,6,6,6,9,9,6,6,6
        defb 6,6,6,9,9,6,6,6,6,6,6,9,9,6,6,6
        defb 6,6,6,9,9,6,6,6,4,4,4,7,7,4,4,4

KnightSquareTable:
        defb 0,0,0,0,0,0,0,0,0,2,2,5,5,2,2,0
        defb 0,2,5,8,8,5,2,0,0,5,8,11,11,8,5,0
        defb 0,5,8,11,11,8,5,0,0,2,5,8,8,5,2,0
        defb 0,2,2,5,5,2,2,0,0,0,0,0,0,0,0,0

BishopSquareTable:
        defb 4,2,4,2,4,2,4,2,2,4,2,7,5,4,2,4
        defb 4,2,7,8,10,5,4,2,2,7,8,13,11,10,5,4
        defb 4,5,10,11,13,8,7,2,2,4,5,10,8,7,2,4
        defb 4,2,4,5,7,2,4,2,2,4,2,4,2,4,2,4

QueenSquareTable:
        defb 3,3,3,3,3,3,3,3,3,3,3,6,6,3,3,3
        defb 3,3,6,9,9,6,3,3,3,6,9,12,12,9,6,3
        defb 3,6,9,12,12,9,6,3,3,3,6,9,9,6,3,3
        defb 3,3,3,6,6,3,3,3,3,3,3,3,3,3,3,3

KingSquareTable:
        defb 8,10,10,8,8,10,10,8,8,8,8,5,5,8,8,8
        defb 8,8,5,2,2,5,8,8,8,5,2,0,0,2,5,8
        defb 8,5,2,0,0,2,5,8,8,8,5,2,2,5,8,8
        defb 8,8,8,5,5,8,8,8,8,10,10,8,8,10,10,8

Brain0Pawn:
        defb 0,12,13,31,26,18,27,1,12,8,1,11,14,22,23,21
        defb 24,4,5,7,2,26,19,25,20,16,9,3,6,14,31,29
        defb 16,28,29,15,10,2,11,17,28,24,17,27,30,6,7,5
        defb 8,20,21,23,18,10,3,9,4,0,25,19,22,30,15,13
        defb 0,12,13,31,26,18,27,1,12,8,1,11,14,22,23,21
        defb 24,4,5,7,2,26,19,25,20,16,9,3,6,14,31,29
        defb 16,28,29,15,10,2,11,17,28,24,17,27,30,6,7,5
        defb 8,20,21,23,18,10,3,9,4,0,25,19,22,30,15,13
        defb 0,12,13,31,26,18,27,1,12,8,1,11,14,22,23,21
        defb 24,4,5,7,2,26,19,25,20,16,9,3,6,14,31,29
        defb 16,28,29,15,10,2,11,17,28,24,17,27,30,6,7,5
        defb 8,20,21,23,18,10,3,9,4,0,25,19,22,30,15,13
        defb 0,12,13,31,26,18,27,1,12,8,1,11,14,22,23,21
        defb 24,4,5,7,2,26,19,25,20,16,9,3,6,14,31,29
        defb 16,28,29,15,10,2,11,17,28,24,17,27,30,6,7,5
        defb 8,20,21,23,18,10,3,9,4,0,25,19,22,30,15,13

Brain0Rook:
        defb 0,12,11,25,26,14,17,31,20,8,7,29,6,2,5,27
        defb 8,20,19,17,18,22,25,7,12,0,31,5,14,26,29,19
        defb 16,28,27,9,10,30,1,15,4,24,23,13,22,18,21,11
        defb 24,4,3,1,2,6,9,23,28,16,15,21,30,10,13,3
        defb 0,12,11,25,26,14,17,31,20,8,7,29,6,2,5,27
        defb 8,20,19,17,18,22,25,7,12,0,31,5,14,26,29,19
        defb 16,28,27,9,10,30,1,15,4,24,23,13,22,18,21,11
        defb 24,4,3,1,2,6,9,23,28,16,15,21,30,10,13,3
        defb 0,12,11,25,26,14,17,31,20,8,7,29,6,2,5,27
        defb 8,20,19,17,18,22,25,7,12,0,31,5,14,26,29,19
        defb 16,28,27,9,10,30,1,15,4,24,23,13,22,18,21,11
        defb 24,4,3,1,2,6,9,23,28,16,15,21,30,10,13,3
        defb 0,12,11,25,26,14,17,31,20,8,7,29,6,2,5,27
        defb 8,20,19,17,18,22,25,7,12,0,31,5,14,26,29,19
        defb 16,28,27,9,10,30,1,15,4,24,23,13,22,18,21,11
        defb 24,4,3,1,2,6,9,23,28,16,15,21,30,10,13,3

Brain0Knight:
        defb 0,13,3,26,26,11,9,20,30,19,17,24,0,25,15,10
        defb 28,9,15,6,6,7,5,16,10,31,13,20,28,5,27,22
        defb 24,5,27,18,18,3,1,12,22,11,9,16,24,17,7,2
        defb 20,1,7,30,30,31,29,8,2,23,5,12,20,29,19,14
        defb 0,13,3,26,26,11,9,20,30,19,17,24,0,25,15,10
        defb 28,9,15,6,6,7,5,16,10,31,13,20,28,5,27,22
        defb 24,5,27,18,18,3,1,12,22,11,9,16,24,17,7,2
        defb 20,1,7,30,30,31,29,8,2,23,5,12,20,29,19,14
        defb 0,13,3,26,26,11,9,20,30,19,17,24,0,25,15,10
        defb 28,9,15,6,6,7,5,16,10,31,13,20,28,5,27,22
        defb 24,5,27,18,18,3,1,12,22,11,9,16,24,17,7,2
        defb 20,1,7,30,30,31,29,8,2,23,5,12,20,29,19,14
        defb 0,13,3,26,26,11,9,20,30,19,17,24,0,25,15,10
        defb 28,9,15,6,6,7,5,16,10,31,13,20,28,5,27,22
        defb 24,5,27,18,18,3,1,12,22,11,9,16,24,17,7,2
        defb 20,1,7,30,30,31,29,8,2,23,5,12,20,29,19,14

Brain0Bishop:
        defb 0,14,3,3,30,4,13,5,4,26,7,15,10,24,25,9
        defb 8,22,27,27,22,12,21,29,28,18,15,23,18,16,17,17
        defb 16,30,19,19,14,20,29,21,20,10,23,31,26,8,9,25
        defb 24,6,11,11,6,28,5,13,12,2,31,7,2,0,1,1
        defb 0,14,3,3,30,4,13,5,4,26,7,15,10,24,25,9
        defb 8,22,27,27,22,12,21,29,28,18,15,23,18,16,17,17
        defb 16,30,19,19,14,20,29,21,20,10,23,31,26,8,9,25
        defb 24,6,11,11,6,28,5,13,12,2,31,7,2,0,1,1
        defb 0,14,3,3,30,4,13,5,4,26,7,15,10,24,25,9
        defb 8,22,27,27,22,12,21,29,28,18,15,23,18,16,17,17
        defb 16,30,19,19,14,20,29,21,20,10,23,31,26,8,9,25
        defb 24,6,11,11,6,28,5,13,12,2,31,7,2,0,1,1
        defb 0,14,3,3,30,4,13,5,4,26,7,15,10,24,25,9
        defb 8,22,27,27,22,12,21,29,28,18,15,23,18,16,17,17
        defb 16,30,19,19,14,20,29,21,20,10,23,31,26,8,9,25
        defb 24,6,11,11,6,28,5,13,12,2,31,7,2,0,1,1

Brain0Queen:
        defb 9,24,12,9,7,10,14,23,13,12,8,13,19,22,18,3
        defb 1,16,20,17,31,2,6,31,21,20,0,5,27,30,26,27
        defb 25,8,28,25,23,26,30,7,29,28,24,29,3,6,2,19
        defb 17,0,4,1,15,18,22,15,5,4,16,21,11,14,10,11
        defb 9,24,12,9,7,10,14,23,13,12,8,13,19,22,18,3
        defb 1,16,20,17,31,2,6,31,21,20,0,5,27,30,26,27
        defb 25,8,28,25,23,26,30,7,29,28,24,29,3,6,2,19
        defb 17,0,4,1,15,18,22,15,5,4,16,21,11,14,10,11
        defb 9,24,12,9,7,10,14,23,13,12,8,13,19,22,18,3
        defb 1,16,20,17,31,2,6,31,21,20,0,5,27,30,26,27
        defb 25,8,28,25,23,26,30,7,29,28,24,29,3,6,2,19
        defb 17,0,4,1,15,18,22,15,5,4,16,21,11,14,10,11
        defb 9,24,12,9,7,10,14,23,13,12,8,13,19,22,18,3
        defb 1,16,20,17,31,2,6,31,21,20,0,5,27,30,26,27
        defb 25,8,28,25,23,26,30,7,29,28,24,29,3,6,2,19
        defb 17,0,4,1,15,18,22,15,5,4,16,21,11,14,10,11

Brain0King:
        defb 0,0,1,2,13,13,12,5,6,10,11,8,15,11,10,7
        defb 4,12,13,14,1,1,0,1,2,14,15,12,11,7,6,11
        defb 8,8,9,10,5,5,4,13,14,2,3,0,7,3,2,15
        defb 12,4,5,6,9,9,8,9,10,6,7,4,3,15,14,3
        defb 0,0,1,2,13,13,12,5,6,10,11,8,15,11,10,7
        defb 4,12,13,14,1,1,0,1,2,14,15,12,11,7,6,11
        defb 8,8,9,10,5,5,4,13,14,2,3,0,7,3,2,15
        defb 12,4,5,6,9,9,8,9,10,6,7,4,3,15,14,3
        defb 0,0,1,2,13,13,12,5,6,10,11,8,15,11,10,7
        defb 4,12,13,14,1,1,0,1,2,14,15,12,11,7,6,11
        defb 8,8,9,10,5,5,4,13,14,2,3,0,7,3,2,15
        defb 12,4,5,6,9,9,8,9,10,6,7,4,3,15,14,3
        defb 0,0,1,2,13,13,12,5,6,10,11,8,15,11,10,7
        defb 4,12,13,14,1,1,0,1,2,14,15,12,11,7,6,11
        defb 8,8,9,10,5,5,4,13,14,2,3,0,7,3,2,15
        defb 12,4,5,6,9,9,8,9,10,6,7,4,3,15,14,3

Brain1Pawn:
        defb 0,8,31,9,14,14,1,27,20,20,19,21,26,18,29,31
        defb 24,16,7,1,6,6,9,3,28,12,11,29,2,26,21,23
        defb 16,24,15,25,30,30,17,11,4,4,3,5,10,2,13,15
        defb 8,0,23,17,22,22,25,19,12,28,27,13,18,10,5,7
        defb 0,8,31,9,14,14,1,27,20,20,19,21,26,18,29,31
        defb 24,16,7,1,6,6,9,3,28,12,11,29,2,26,21,23
        defb 16,24,15,25,30,30,17,11,4,4,3,5,10,2,13,15
        defb 8,0,23,17,22,22,25,19,12,28,27,13,18,10,5,7
        defb 0,8,31,9,14,14,1,27,20,20,19,21,26,18,29,31
        defb 24,16,7,1,6,6,9,3,28,12,11,29,2,26,21,23
        defb 16,24,15,25,30,30,17,11,4,4,3,5,10,2,13,15
        defb 8,0,23,17,22,22,25,19,12,28,27,13,18,10,5,7
        defb 0,8,31,9,14,14,1,27,20,20,19,21,26,18,29,31
        defb 24,16,7,1,6,6,9,3,28,12,11,29,2,26,21,23
        defb 16,24,15,25,30,30,17,11,4,4,3,5,10,2,13,15
        defb 8,0,23,17,22,22,25,19,12,28,27,13,18,10,5,7

Brain1Rook:
        defb 0,6,1,5,2,12,7,31,4,10,13,25,30,24,11,11
        defb 24,30,25,13,10,20,31,23,12,18,21,17,22,16,19,19
        defb 16,22,17,21,18,28,23,15,20,26,29,9,14,8,27,27
        defb 8,14,9,29,26,4,15,7,28,2,5,1,6,0,3,3
        defb 0,6,1,5,2,12,7,31,4,10,13,25,30,24,11,11
        defb 24,30,25,13,10,20,31,23,12,18,21,17,22,16,19,19
        defb 16,22,17,21,18,28,23,15,20,26,29,9,14,8,27,27
        defb 8,14,9,29,26,4,15,7,28,2,5,1,6,0,3,3
        defb 0,6,1,5,2,12,7,31,4,10,13,25,30,24,11,11
        defb 24,30,25,13,10,20,31,23,12,18,21,17,22,16,19,19
        defb 16,22,17,21,18,28,23,15,20,26,29,9,14,8,27,27
        defb 8,14,9,29,26,4,15,7,28,2,5,1,6,0,3,3
        defb 0,6,1,5,2,12,7,31,4,10,13,25,30,24,11,11
        defb 24,30,25,13,10,20,31,23,12,18,21,17,22,16,19,19
        defb 16,22,17,21,18,28,23,15,20,26,29,9,14,8,27,27
        defb 8,14,9,29,26,4,15,7,28,2,5,1,6,0,3,3

Brain1Knight:
        defb 0,1,1,0,6,15,3,2,30,7,7,14,12,29,1,8
        defb 12,13,13,28,2,27,15,14,26,3,3,26,24,25,29,4
        defb 24,25,25,24,30,7,27,26,22,31,31,6,4,21,25,0
        defb 4,5,5,20,26,19,7,6,18,27,27,18,16,17,21,28
        defb 0,1,1,0,6,15,3,2,30,7,7,14,12,29,1,8
        defb 12,13,13,28,2,27,15,14,26,3,3,26,24,25,29,4
        defb 24,25,25,24,30,7,27,26,22,31,31,6,4,21,25,0
        defb 4,5,5,20,26,19,7,6,18,27,27,18,16,17,21,28
        defb 0,1,1,0,6,15,3,2,30,7,7,14,12,29,1,8
        defb 12,13,13,28,2,27,15,14,26,3,3,26,24,25,29,4
        defb 24,25,25,24,30,7,27,26,22,31,31,6,4,21,25,0
        defb 4,5,5,20,26,19,7,6,18,27,27,18,16,17,21,28
        defb 0,1,1,0,6,15,3,2,30,7,7,14,12,29,1,8
        defb 12,13,13,28,2,27,15,14,26,3,3,26,24,25,29,4
        defb 24,25,25,24,30,7,27,26,22,31,31,6,4,21,25,0
        defb 4,5,5,20,26,19,7,6,18,27,27,18,16,17,21,28

Brain1Bishop:
        defb 0,0,29,3,6,10,15,9,20,28,17,23,18,14,11,21
        defb 24,24,5,11,14,2,7,1,28,4,9,15,10,22,19,29
        defb 16,16,13,19,22,26,31,25,4,12,1,7,2,30,27,5
        defb 8,8,21,27,30,18,23,17,12,20,25,31,26,6,3,13
        defb 0,0,29,3,6,10,15,9,20,28,17,23,18,14,11,21
        defb 24,24,5,11,14,2,7,1,28,4,9,15,10,22,19,29
        defb 16,16,13,19,22,26,31,25,4,12,1,7,2,30,27,5
        defb 8,8,21,27,30,18,23,17,12,20,25,31,26,6,3,13
        defb 0,0,29,3,6,10,15,9,20,28,17,23,18,14,11,21
        defb 24,24,5,11,14,2,7,1,28,4,9,15,10,22,19,29
        defb 16,16,13,19,22,26,31,25,4,12,1,7,2,30,27,5
        defb 8,8,21,27,30,18,23,17,12,20,25,31,26,6,3,13
        defb 0,0,29,3,6,10,15,9,20,28,17,23,18,14,11,21
        defb 24,24,5,11,14,2,7,1,28,4,9,15,10,22,19,29
        defb 16,16,13,19,22,26,31,25,4,12,1,7,2,30,27,5
        defb 8,8,21,27,30,18,23,17,12,20,25,31,26,6,3,13

Brain1Queen:
        defb 9,12,6,3,3,30,28,25,21,0,2,7,7,10,16,21
        defb 17,20,30,27,27,6,4,17,13,24,10,15,15,2,8,29
        defb 25,28,22,19,19,14,12,9,5,16,18,23,23,26,0,5
        defb 1,4,14,11,11,22,20,1,29,8,26,31,31,18,24,13
        defb 9,12,6,3,3,30,28,25,21,0,2,7,7,10,16,21
        defb 17,20,30,27,27,6,4,17,13,24,10,15,15,2,8,29
        defb 25,28,22,19,19,14,12,9,5,16,18,23,23,26,0,5
        defb 1,4,14,11,11,22,20,1,29,8,26,31,31,18,24,13
        defb 9,12,6,3,3,30,28,25,21,0,2,7,7,10,16,21
        defb 17,20,30,27,27,6,4,17,13,24,10,15,15,2,8,29
        defb 25,28,22,19,19,14,12,9,5,16,18,23,23,26,0,5
        defb 1,4,14,11,11,22,20,1,29,8,26,31,31,18,24,13
        defb 9,12,6,3,3,30,28,25,21,0,2,7,7,10,16,21
        defb 17,20,30,27,27,6,4,17,13,24,10,15,15,2,8,29
        defb 25,28,22,19,19,14,12,9,5,16,18,23,23,26,0,5
        defb 1,4,14,11,11,22,20,1,29,8,26,31,31,18,24,13

Brain1King:
        defb 0,1,12,12,9,8,11,5,6,7,6,2,11,10,9,15
        defb 12,13,0,0,5,4,7,9,10,11,2,14,15,14,13,11
        defb 8,9,4,4,1,0,3,13,14,15,14,10,3,2,1,7
        defb 4,5,8,8,13,12,15,1,2,3,10,6,7,6,5,3
        defb 0,1,12,12,9,8,11,5,6,7,6,2,11,10,9,15
        defb 12,13,0,0,5,4,7,9,10,11,2,14,15,14,13,11
        defb 8,9,4,4,1,0,3,13,14,15,14,10,3,2,1,7
        defb 4,5,8,8,13,12,15,1,2,3,10,6,7,6,5,3
        defb 0,1,12,12,9,8,11,5,6,7,6,2,11,10,9,15
        defb 12,13,0,0,5,4,7,9,10,11,2,14,15,14,13,11
        defb 8,9,4,4,1,0,3,13,14,15,14,10,3,2,1,7
        defb 4,5,8,8,13,12,15,1,2,3,10,6,7,6,5,3
        defb 0,1,12,12,9,8,11,5,6,7,6,2,11,10,9,15
        defb 12,13,0,0,5,4,7,9,10,11,2,14,15,14,13,11
        defb 8,9,4,4,1,0,3,13,14,15,14,10,3,2,1,7
        defb 4,5,8,8,13,12,15,1,2,3,10,6,7,6,5,3

Brain2Pawn:
        defb 0,4,9,3,6,6,3,9,4,16,13,7,2,10,15,21
        defb 8,28,1,27,14,14,27,1,28,24,21,15,26,2,23,29
        defb 16,20,25,19,22,22,19,25,20,0,29,23,18,26,31,5
        defb 24,12,17,11,30,30,11,17,12,8,5,31,10,18,7,13
        defb 0,4,9,3,6,6,3,9,4,16,13,7,2,10,15,21
        defb 8,28,1,27,14,14,27,1,28,24,21,15,26,2,23,29
        defb 16,20,25,19,22,22,19,25,20,0,29,23,18,26,31,5
        defb 24,12,17,11,30,30,11,17,12,8,5,31,10,18,7,13
        defb 0,4,9,3,6,6,3,9,4,16,13,7,2,10,15,21
        defb 8,28,1,27,14,14,27,1,28,24,21,15,26,2,23,29
        defb 16,20,25,19,22,22,19,25,20,0,29,23,18,26,31,5
        defb 24,12,17,11,30,30,11,17,12,8,5,31,10,18,7,13
        defb 0,4,9,3,6,6,3,9,4,16,13,7,2,10,15,21
        defb 8,28,1,27,14,14,27,1,28,24,21,15,26,2,23,29
        defb 16,20,25,19,22,22,19,25,20,0,29,23,18,26,31,5
        defb 24,12,17,11,30,30,11,17,12,8,5,31,10,18,7,13

Brain2Rook:
        defb 0,0,7,13,14,6,25,31,28,20,19,17,18,18,29,27
        defb 24,8,15,5,6,30,1,7,4,12,11,25,26,26,21,19
        defb 16,16,23,29,30,22,9,15,12,4,3,1,2,2,13,11
        defb 8,24,31,21,22,14,17,23,20,28,27,9,10,10,5,3
        defb 0,0,7,13,14,6,25,31,28,20,19,17,18,18,29,27
        defb 24,8,15,5,6,30,1,7,4,12,11,25,26,26,21,19
        defb 16,16,23,29,30,22,9,15,12,4,3,1,2,2,13,11
        defb 8,24,31,21,22,14,17,23,20,28,27,9,10,10,5,3
        defb 0,0,7,13,14,6,25,31,28,20,19,17,18,18,29,27
        defb 24,8,15,5,6,30,1,7,4,12,11,25,26,26,21,19
        defb 16,16,23,29,30,22,9,15,12,4,3,1,2,2,13,11
        defb 8,24,31,21,22,14,17,23,20,28,27,9,10,10,5,3
        defb 0,0,7,13,14,6,25,31,28,20,19,17,18,18,29,27
        defb 24,8,15,5,6,30,1,7,4,12,11,25,26,26,21,19
        defb 16,16,23,29,30,22,9,15,12,4,3,1,2,2,13,11
        defb 8,24,31,21,22,14,17,23,20,28,27,9,10,10,5,3

Brain2Knight:
        defb 0,1,7,10,14,11,17,16,30,31,29,8,4,17,15,6
        defb 28,29,3,22,26,23,13,12,10,11,9,4,0,13,27,18
        defb 24,25,31,2,6,3,9,8,22,23,21,0,28,9,7,30
        defb 20,21,27,14,18,15,5,4,2,3,1,28,24,5,19,10
        defb 0,1,7,10,14,11,17,16,30,31,29,8,4,17,15,6
        defb 28,29,3,22,26,23,13,12,10,11,9,4,0,13,27,18
        defb 24,25,31,2,6,3,9,8,22,23,21,0,28,9,7,30
        defb 20,21,27,14,18,15,5,4,2,3,1,28,24,5,19,10
        defb 0,1,7,10,14,11,17,16,30,31,29,8,4,17,15,6
        defb 28,29,3,22,26,23,13,12,10,11,9,4,0,13,27,18
        defb 24,25,31,2,6,3,9,8,22,23,21,0,28,9,7,30
        defb 20,21,27,14,18,15,5,4,2,3,1,28,24,5,19,10
        defb 0,1,7,10,14,11,17,16,30,31,29,8,4,17,15,6
        defb 28,29,3,22,26,23,13,12,10,11,9,4,0,13,27,18
        defb 24,25,31,2,6,3,9,8,22,23,21,0,28,9,7,30
        defb 20,21,27,14,18,15,5,4,2,3,1,28,24,5,19,10

Brain2Bishop:
        defb 0,6,7,11,18,16,13,9,4,2,3,31,30,20,17,21
        defb 8,14,15,3,10,24,21,17,28,26,27,7,6,12,9,13
        defb 16,22,23,27,2,0,29,25,20,18,19,15,14,4,1,5
        defb 24,30,31,19,26,8,5,1,12,10,11,23,22,28,25,29
        defb 0,6,7,11,18,16,13,9,4,2,3,31,30,20,17,21
        defb 8,14,15,3,10,24,21,17,28,26,27,7,6,12,9,13
        defb 16,22,23,27,2,0,29,25,20,18,19,15,14,4,1,5
        defb 24,30,31,19,26,8,5,1,12,10,11,23,22,28,25,29
        defb 0,6,7,11,18,16,13,9,4,2,3,31,30,20,17,21
        defb 8,14,15,3,10,24,21,17,28,26,27,7,6,12,9,13
        defb 16,22,23,27,2,0,29,25,20,18,19,15,14,4,1,5
        defb 24,30,31,19,26,8,5,1,12,10,11,23,22,28,25,29
        defb 0,6,7,11,18,16,13,9,4,2,3,31,30,20,17,21
        defb 8,14,15,3,10,24,21,17,28,26,27,7,6,12,9,13
        defb 16,22,23,27,2,0,29,25,20,18,19,15,14,4,1,5
        defb 24,30,31,19,26,8,5,1,12,10,11,23,22,28,25,29

Brain2Queen:
        defb 9,16,0,29,27,22,22,23,21,20,28,25,31,2,10,11
        defb 1,8,8,5,3,14,14,15,29,28,20,17,23,10,18,19
        defb 25,0,16,13,11,6,6,7,5,4,12,9,15,18,26,27
        defb 17,24,24,21,19,30,30,31,13,12,4,1,7,26,2,3
        defb 9,16,0,29,27,22,22,23,21,20,28,25,31,2,10,11
        defb 1,8,8,5,3,14,14,15,29,28,20,17,23,10,18,19
        defb 25,0,16,13,11,6,6,7,5,4,12,9,15,18,26,27
        defb 17,24,24,21,19,30,30,31,13,12,4,1,7,26,2,3
        defb 9,16,0,29,27,22,22,23,21,20,28,25,31,2,10,11
        defb 1,8,8,5,3,14,14,15,29,28,20,17,23,10,18,19
        defb 25,0,16,13,11,6,6,7,5,4,12,9,15,18,26,27
        defb 17,24,24,21,19,30,30,31,13,12,4,1,7,26,2,3
        defb 9,16,0,29,27,22,22,23,21,20,28,25,31,2,10,11
        defb 1,8,8,5,3,14,14,15,29,28,20,17,23,10,18,19
        defb 25,0,16,13,11,6,6,7,5,4,12,9,15,18,26,27
        defb 17,24,24,21,19,30,30,31,13,12,4,1,7,26,2,3

Brain2King:
        defb 0,2,11,8,11,5,0,5,10,8,5,6,1,7,6,7
        defb 4,6,7,4,7,9,4,1,6,4,9,10,5,3,2,11
        defb 8,10,3,0,3,13,8,13,2,0,13,14,9,15,14,15
        defb 12,14,15,12,15,1,12,9,14,12,1,2,13,11,10,3
        defb 0,2,11,8,11,5,0,5,10,8,5,6,1,7,6,7
        defb 4,6,7,4,7,9,4,1,6,4,9,10,5,3,2,11
        defb 8,10,3,0,3,13,8,13,2,0,13,14,9,15,14,15
        defb 12,14,15,12,15,1,12,9,14,12,1,2,13,11,10,3
        defb 0,2,11,8,11,5,0,5,10,8,5,6,1,7,6,7
        defb 4,6,7,4,7,9,4,1,6,4,9,10,5,3,2,11
        defb 8,10,3,0,3,13,8,13,2,0,13,14,9,15,14,15
        defb 12,14,15,12,15,1,12,9,14,12,1,2,13,11,10,3
        defb 0,2,11,8,11,5,0,5,10,8,5,6,1,7,6,7
        defb 4,6,7,4,7,9,4,1,6,4,9,10,5,3,2,11
        defb 8,10,3,0,3,13,8,13,2,0,13,14,9,15,14,15
        defb 12,14,15,12,15,1,12,9,14,12,1,2,13,11,10,3

Brain3Pawn:
        defb 0,16,15,9,26,2,5,23,20,12,11,13,6,6,9,3
        defb 24,24,23,17,18,26,29,31,28,4,3,5,14,14,17,27
        defb 16,0,31,25,10,18,21,7,4,28,27,29,22,22,25,19
        defb 8,8,7,1,2,10,13,15,12,20,19,21,30,30,1,11
        defb 0,16,15,9,26,2,5,23,20,12,11,13,6,6,9,3
        defb 24,24,23,17,18,26,29,31,28,4,3,5,14,14,17,27
        defb 16,0,31,25,10,18,21,7,4,28,27,29,22,22,25,19
        defb 8,8,7,1,2,10,13,15,12,20,19,21,30,30,1,11
        defb 0,16,15,9,26,2,5,23,20,12,11,13,6,6,9,3
        defb 24,24,23,17,18,26,29,31,28,4,3,5,14,14,17,27
        defb 16,0,31,25,10,18,21,7,4,28,27,29,22,22,25,19
        defb 8,8,7,1,2,10,13,15,12,20,19,21,30,30,1,11
        defb 0,16,15,9,26,2,5,23,20,12,11,13,6,6,9,3
        defb 24,24,23,17,18,26,29,31,28,4,3,5,14,14,17,27
        defb 16,0,31,25,10,18,21,7,4,28,27,29,22,22,25,19
        defb 8,8,7,1,2,10,13,15,12,20,19,21,30,30,1,11

Brain3Rook:
        defb 0,14,9,9,22,16,27,31,28,2,5,5,10,12,15,19
        defb 8,6,1,1,30,24,19,23,20,10,13,13,2,4,23,27
        defb 16,30,25,25,6,0,11,15,12,18,21,21,26,28,31,3
        defb 24,22,17,17,14,8,3,7,4,26,29,29,18,20,7,11
        defb 0,14,9,9,22,16,27,31,28,2,5,5,10,12,15,19
        defb 8,6,1,1,30,24,19,23,20,10,13,13,2,4,23,27
        defb 16,30,25,25,6,0,11,15,12,18,21,21,26,28,31,3
        defb 24,22,17,17,14,8,3,7,4,26,29,29,18,20,7,11
        defb 0,14,9,9,22,16,27,31,28,2,5,5,10,12,15,19
        defb 8,6,1,1,30,24,19,23,20,10,13,13,2,4,23,27
        defb 16,30,25,25,6,0,11,15,12,18,21,21,26,28,31,3
        defb 24,22,17,17,14,8,3,7,4,26,29,29,18,20,7,11
        defb 0,14,9,9,22,16,27,31,28,2,5,5,10,12,15,19
        defb 8,6,1,1,30,24,19,23,20,10,13,13,2,4,23,27
        defb 16,30,25,25,6,0,11,15,12,18,21,21,26,28,31,3
        defb 24,22,17,17,14,8,3,7,4,26,29,29,18,20,7,11

Brain3Knight:
        defb 0,13,9,20,18,23,7,2,6,27,31,18,0,29,5,8
        defb 28,25,21,16,14,19,19,14,18,23,27,30,12,9,1,4
        defb 24,5,1,12,10,15,31,26,30,19,23,10,24,21,29,0
        defb 20,17,13,8,6,11,11,6,10,15,19,22,4,1,25,28
        defb 0,13,9,20,18,23,7,2,6,27,31,18,0,29,5,8
        defb 28,25,21,16,14,19,19,14,18,23,27,30,12,9,1,4
        defb 24,5,1,12,10,15,31,26,30,19,23,10,24,21,29,0
        defb 20,17,13,8,6,11,11,6,10,15,19,22,4,1,25,28
        defb 0,13,9,20,18,23,7,2,6,27,31,18,0,29,5,8
        defb 28,25,21,16,14,19,19,14,18,23,27,30,12,9,1,4
        defb 24,5,1,12,10,15,31,26,30,19,23,10,24,21,29,0
        defb 20,17,13,8,6,11,11,6,10,15,19,22,4,1,25,28
        defb 0,13,9,20,18,23,7,2,6,27,31,18,0,29,5,8
        defb 28,25,21,16,14,19,19,14,18,23,27,30,12,9,1,4
        defb 24,5,1,12,10,15,31,26,30,19,23,10,24,21,29,0
        defb 20,17,13,8,6,11,11,6,10,15,19,22,4,1,25,28

Brain3Bishop:
        defb 0,12,13,19,10,10,3,5,20,16,9,7,6,6,23,17
        defb 24,4,5,27,18,18,27,29,28,24,17,31,30,30,31,25
        defb 16,28,29,3,26,26,19,21,4,0,25,23,22,22,7,1
        defb 8,20,21,11,2,2,11,13,12,8,1,15,14,14,15,9
        defb 0,12,13,19,10,10,3,5,20,16,9,7,6,6,23,17
        defb 24,4,5,27,18,18,27,29,28,24,17,31,30,30,31,25
        defb 16,28,29,3,26,26,19,21,4,0,25,23,22,22,7,1
        defb 8,20,21,11,2,2,11,13,12,8,1,15,14,14,15,9
        defb 0,12,13,19,10,10,3,5,20,16,9,7,6,6,23,17
        defb 24,4,5,27,18,18,27,29,28,24,17,31,30,30,31,25
        defb 16,28,29,3,26,26,19,21,4,0,25,23,22,22,7,1
        defb 8,20,21,11,2,2,11,13,12,8,1,15,14,14,15,9
        defb 0,12,13,19,10,10,3,5,20,16,9,7,6,6,23,17
        defb 24,4,5,27,18,18,27,29,28,24,17,31,30,30,31,25
        defb 16,28,29,3,26,26,19,21,4,0,25,23,22,22,7,1
        defb 8,20,21,11,2,2,11,13,12,8,1,15,14,14,15,9

Brain3Queen:
        defb 9,20,22,27,23,10,24,21,21,24,10,23,27,22,20,9
        defb 17,28,30,19,15,18,0,29,13,16,2,31,3,14,12,1
        defb 25,4,6,11,7,26,8,5,5,8,26,7,11,6,4,25
        defb 1,12,14,3,31,2,16,13,29,0,18,15,19,30,28,17
        defb 9,20,22,27,23,10,24,21,21,24,10,23,27,22,20,9
        defb 17,28,30,19,15,18,0,29,13,16,2,31,3,14,12,1
        defb 25,4,6,11,7,26,8,5,5,8,26,7,11,6,4,25
        defb 1,12,14,3,31,2,16,13,29,0,18,15,19,30,28,17
        defb 9,20,22,27,23,10,24,21,21,24,10,23,27,22,20,9
        defb 17,28,30,19,15,18,0,29,13,16,2,31,3,14,12,1
        defb 25,4,6,11,7,26,8,5,5,8,26,7,11,6,4,25
        defb 1,12,14,3,31,2,16,13,29,0,18,15,19,30,28,17
        defb 9,20,22,27,23,10,24,21,21,24,10,23,27,22,20,9
        defb 17,28,30,19,15,18,0,29,13,16,2,31,3,14,12,1
        defb 25,4,6,11,7,26,8,5,5,8,26,7,11,6,4,25
        defb 1,12,14,3,31,2,16,13,29,0,18,15,19,30,28,17

Brain3King:
        defb 0,5,8,6,7,6,9,9,2,3,10,8,13,0,15,15
        defb 12,1,12,10,11,2,5,5,6,7,6,4,9,4,3,3
        defb 8,13,0,14,15,14,1,1,10,11,2,0,5,8,7,7
        defb 4,9,4,2,3,10,13,13,14,15,14,12,1,12,11,11
        defb 0,5,8,6,7,6,9,9,2,3,10,8,13,0,15,15
        defb 12,1,12,10,11,2,5,5,6,7,6,4,9,4,3,3
        defb 8,13,0,14,15,14,1,1,10,11,2,0,5,8,7,7
        defb 4,9,4,2,3,10,13,13,14,15,14,12,1,12,11,11
        defb 0,5,8,6,7,6,9,9,2,3,10,8,13,0,15,15
        defb 12,1,12,10,11,2,5,5,6,7,6,4,9,4,3,3
        defb 8,13,0,14,15,14,1,1,10,11,2,0,5,8,7,7
        defb 4,9,4,2,3,10,13,13,14,15,14,12,1,12,11,11
        defb 0,5,8,6,7,6,9,9,2,3,10,8,13,0,15,15
        defb 12,1,12,10,11,2,5,5,6,7,6,4,9,4,3,3
        defb 8,13,0,14,15,14,1,1,10,11,2,0,5,8,7,7
        defb 4,9,4,2,3,10,13,13,14,15,14,12,1,12,11,11

NoTmsMsg:
        defb "TMSEMU3 / TMS9918A not found, aborting!$"

; Text tile strings.  Tiles 32..57 are A..Z, 58 is dash, 59 is space, 60..69 are 0..9.
TitleText:
        defb 50,47,49,40,51,36,59,34,39,36,50,50,59,49,36,53,67,0
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
