; CHXR29.ASM  REV29 BRN FILE STATUS + BEST BRAIN MASTER
; SC700 / SC720 Z80-Z180 + TMSEMU3 / TMS9918A
; Smart self-playing sprite chess show for the TMSAsmBuilder IDE.
;
; Build with the IDE/sjasmplus path, not CP/M ASM.COM.
;
; REV26 ROMWBW APP-BANK PROJECT NOTE:
;   This source now INCLUDES and USES RWBANK.ASM.
;   The SC700 verified official RomWBW application banks are 89h, 8Ah, 8Bh.
;   CHXR26 uses HBIOS SYSGET/APPBNKS + SYSPEEK/SYSPOKE through CALL FFF0h.
;   Raw Z180 MMU bank code is no longer used by the chess brain.
; Transfer the built CHXR29.COM by XMODEM after setting the console to 9600.
;
; What CHXR29 / ChessXR27 REV29 does:
;   - black background
;   - tiled 8x8 chess board with tan and darker-tan squares plus a bright frame
;   - resting chess men are tile-rendered 16x16 pieces, not crowded sprites
;   - the one moving piece uses a hardware sprite while sliding
;   - one piece animates smoothly from square to square
;   - diagonal moves now animate diagonally, not X first then Y
;   - bigger rule-aware chess brain chooses moves from the live board
;   - captures remove the captured tile piece
;   - stationary pieces are tile-rendered to avoid the TMS 4-sprites-per-scanline blink
;   - no full-screen redraw on game reset
;   - REV15 deeper scoring layer with exchange logic and mega-brain tables
;   - SC719 LEDs show real live thought: 00h black scan, 01h white scan, 02h game-data bus
;   - REV20 finds CP/M free RAM and uses it as a live move-plan buffer
;   - REV20 rejects moves that would leave the moving side king in check
;   - REV21 uses Z180-detected deep-brain mode and more free RAM planning
;   - REV21 adds wide neural tables to push the COM toward a much larger brain
;   - REV26 adds real reply-threat and win-threat scans for both sides
;   - REV26 stays inside normal CP/M .COM size limits instead of unsafe padding
;   - optional CHXR29.BRN external brain file loaded from CP/M disk
;   - REV29 shows the active/best brain on screen
;   - REV29 uses the best available brain path: RWBANK+BRN, RWBANK, BRN, RAM, INTERNAL
;   - OUT 02h high nibble shows best brain tier: F=RWBANK+BRN, E=RWBANK, C=BRN
;   - press any CP/M console key to exit
;
; Important TMS9918A note:
;   The real TMS9918A only displays 4 sprites on the same scanline.
;   CHXR29 / ChessXR27 REV29 keeps that by drawing resting pieces as tiles and using
;   one hardware sprite only for the active moving piece.
;
;
; REV26 note:
;   z180.asm is still included and used correctly:
;     z180detect -> z180getclk -> TmsSetWait -> TmsProbe/TmsTile
;   This build removes hardware sprite movement to isolate blinking.
; Needed IDE Libs:
;   include "tms.asm"
;   include "z180.asm"
;   include "utility.asm"
;   include "RWBANK.ASM"

        org     100h

Start:
        ld      (OldSP),sp
        ld      sp,Stack

        ; Safe TMS wait timing on fast Z180 systems.
        call    z180detect
        ld      e,0
        jp      nz,NoZ180
        call    z180getclk
        ; REV26: raw Z180 MMU bank code is no longer used here
NoZ180:
        call    TmsSetWait
        call    InitFreeRamPlanner
        call    LoadExternalBrain
        call    InitRomWBWBankBrain     ; REV26: verified 96K app-bank brain
        call    InitZ180BrainMode
        call    SelectBestBrainMode      ; REV29: visible best-brain tier

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
        call    DrawAllPieceTiles
        call    ResetMoveList
        call    WriteSprites

MainLoop:
        call    WaitFrame
        call    TickStars
        call    ChessThink
        call    WriteSpritesSmart

        call    keypress
        jp      z,MainLoop

Exit:
        call    HideSprites
        call    ShutdownRomWBWBankBrain ; REV26: no raw MMU restore needed
        ld      sp,(OldSP)
        rst     0

NoTms:
        call    ShutdownRomWBWBankBrain ; REV26: no raw MMU restore needed
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
        call    DrawBrainStatus          ; REV29 visible active brain line
        ret

DrawTitle:
        ; Row 1, col 11: CHESSXR11, centered
        ld      hl,(TmsNameAddr)
        ld      de,43                   ; row 1 * 32 + col 11
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


; ------------------------------------------------------------
; REV29 visible best-brain status line.
;
; Row 21 shows the strongest active brain path:
;   BRAIN RWBANK BRN D4  = official app banks + external BRN bonus
;   BRAIN RWBANK 96K D4  = official RomWBW 96K app-bank brain
;   BRAIN BRN FILE D3    = external CHXR29.BRN only
;   BRAIN CP/M RAM D2    = normal CP/M planner RAM
;   BRAIN INTERNAL D1    = built-in tables only

DrawBrainStatus:
        ; REV29: clear whole center status row, then write a short centered line.
        ; This avoids the brain text running into the side score panels.
        ld      hl,(TmsNameAddr)
        ld      de,672                  ; row 21 * 32 + col 0
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      a,TileSpace
        ld      b,32
DrawBrainStatusClearLoop:
        call    TmsRamOut
        djnz    DrawBrainStatusClearLoop

        ld      a,(BrainModeUsed)
        cp      4
        jp      z,DrawBrainTextRwbBrn
        cp      3
        jp      z,DrawBrainTextRwb
        cp      2
        jp      z,DrawBrainTextBrn
        cp      1
        jp      z,DrawBrainTextRam

        ; INTERNAL Dn, length 11 including digit.  Center at col 10.
        ld      de,682
        ld      hl,BrainTextInternal
        jp      DrawBrainTextAtDE

DrawBrainTextRwbBrn:
        ; RWBANK BRN Dn, length 13.  Center at col 9.
        ld      de,681
        ld      hl,BrainTextRwbBrn
        jp      DrawBrainTextAtDE

DrawBrainTextRwb:
        ; RWBANK 96K Dn, length 14.  Center at col 9.
        ld      de,681
        ld      hl,BrainTextRwb
        jp      DrawBrainTextAtDE

DrawBrainTextBrn:
        ; BRN FILE Dn, length 11.  Center at col 10.
        ld      de,682
        ld      hl,BrainTextBrn
        jp      DrawBrainTextAtDE

DrawBrainTextRam:
        ; CPM RAM Dn, length 10.  Center at col 11.
        ld      de,683
        ld      hl,BrainTextRam

DrawBrainTextAtDE:
        push    hl
        ld      hl,(TmsNameAddr)
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        pop     hl
        call    WriteTextTiles
        ld      a,(BrainDepthBudget)
        cp      10
        jp      c,DrawBrainDepthDigit
        ld      a,55                    ; X tile if somehow above 9
        jp      TmsRamOut
DrawBrainDepthDigit:
        add     a,DigitBase
        jp      TmsRamOut

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
        ; REV29: side scores are true HEX 00-FF.
        ; White capture score, row 5 col 3.
        ld      hl,(TmsNameAddr)
        ld      de,163                  ; row 5 col 3
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      a,(WhiteScore10)        ; high hex nibble
        call    HexNibbleToTile
        call    TmsRamOut
        ld      a,(WhiteScore1)         ; low hex nibble
        call    HexNibbleToTile
        call    TmsRamOut

        ; Black capture score, row 5 col 28.
        ld      hl,(TmsNameAddr)
        ld      de,188                  ; row 5 col 28
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      a,(BlackScore10)        ; high hex nibble
        call    HexNibbleToTile
        call    TmsRamOut
        ld      a,(BlackScore1)         ; low hex nibble
        call    HexNibbleToTile
        call    TmsRamOut
        ret

HexNibbleToTile:
        ; A = 0..15 -> tile for 0..9 or A..F.
        and     0fh
        cp      10
        jp      c,HexNibbleDigit
        sub     10
        add     a,TileTextBase          ; A..F use normal text tiles
        ret
HexNibbleDigit:
        add     a,DigitBase
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
        ; 8x8 squares, 0each square is 2x2 tiles.
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


; ------------------------------------------------------------
; REV2 tile-rendered stationary chess pieces.
;
; This is the real blink fix.  A TMS9918A can only show four sprites on
; the same scanline.  A full chess rank has eight 16x16 pieces on the
; same scanlines, so all-sprite chess must blink/drop pieces.  We now
; draw all resting pieces as background tiles and use exactly one sprite
; only while a piece is sliding to its new square.

DrawAllPieceTiles:
        call    DrawBoard
        xor     a
        ld      (DrawPieceIndex),a
DrawAllPieceLoop:
        ld      a,(DrawPieceIndex)
        call    DrawPieceTileByIndex
        ld      hl,DrawPieceIndex
        inc     (hl)
        ld      a,(hl)
        cp      32
        jp      c,DrawAllPieceLoop
        ret

DrawBestPieceTile:
        ld      a,(BestPiece)
        jp      DrawPieceTileByIndex

DrawPieceTileByIndex:
        ld      (DrawPieceIndex),a
        call    PtrPieceAlive
        ld      a,(hl)
        or      a
        ret     z
        ld      a,(DrawPieceIndex)
        call    PtrPieceFile
        ld      a,(hl)
        ld      (DrawFile),a
        ld      a,(DrawPieceIndex)
        call    PtrPieceRank
        ld      a,(hl)
        ld      (DrawRank),a
        jp      DrawPieceTileAtDrawFileRank

ClearMoveSquares:
        ld      a,(LastFromFile)
        ld      (DrawFile),a
        ld      a,(LastFromRank)
        ld      (DrawRank),a
        call    ClearSquareAtDrawFileRank
        ld      a,(BestFile)
        ld      (DrawFile),a
        ld      a,(BestRank)
        ld      (DrawRank),a
        jp      ClearSquareAtDrawFileRank

DrawPieceTileAtDrawFileRank:
        call    SelectPieceTileBase
        ld      (DrawTileBase),a
        call    CalcSquareNameAddr
        push    hl
        ex      de,hl
        call    TmsWriteAddr
        ld      a,(DrawTileBase)
        call    TmsRamOut
        ld      a,(DrawTileBase)
        inc     a
        call    TmsRamOut
        pop     hl
        ld      de,32
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      a,(DrawTileBase)
        add     a,2
        call    TmsRamOut
        ld      a,(DrawTileBase)
        add     a,3
        jp      TmsRamOut

ClearSquareAtDrawFileRank:
        call    GetSquareTileForDrawSquare
        ld      (DrawTileBase),a
        call    CalcSquareNameAddr
        push    hl
        ex      de,hl
        call    TmsWriteAddr
        ld      a,(DrawTileBase)
        call    TmsRamOut
        ld      a,(DrawTileBase)
        call    TmsRamOut
        pop     hl
        ld      de,32
        add     hl,de
        ex      de,hl
        call    TmsWriteAddr
        ld      a,(DrawTileBase)
        call    TmsRamOut
        ld      a,(DrawTileBase)
        jp      TmsRamOut

GetSquareTileForDrawSquare:
        call    IsDrawSquareDark
        or      a
        jp      nz,GetDarkDrawSquareTile
        ld      a,TileLightSq
        ret
GetDarkDrawSquareTile:
        ld      a,TileDarkSq
        ret

; Returns A=0 for light square, A=1 for dark square.
IsDrawSquareDark:
        ld      a,(DrawRank)
        ld      b,a
        ld      a,(DrawFile)
        xor     b
        and     1
        ret

SelectPieceTileBase:
        call    IsDrawSquareDark
        ld      b,a                     ; B = 0 light / 1 dark
        ld      a,(DrawPieceIndex)
        cp      16
        jp      c,SelectWhiteTileBase
SelectBlackTileBase:
        ld      a,b
        or      a
        jp      z,SelectBlackLightBase
        ld      b,TilePieceBlackDark
        jp      AddPieceTypeTileOffset
SelectBlackLightBase:
        ld      b,TilePieceBlackLight
        jp      AddPieceTypeTileOffset
SelectWhiteTileBase:
        ld      a,b
        or      a
        jp      z,SelectWhiteLightBase
        ld      b,TilePieceWhiteDark
        jp      AddPieceTypeTileOffset
SelectWhiteLightBase:
        ld      b,TilePieceWhiteLight

AddPieceTypeTileOffset:
        ld      a,(DrawPieceIndex)
        call    PtrPieceType
        ld      a,(hl)
        dec     a
        add     a,a
        add     a,a
        add     a,b
        ret

CalcSquareNameAddr:
        ; HL = name table + (4 + rank*2)*32 + (8 + file*2)
        ld      a,(DrawRank)
        add     a,a
        add     a,4
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      a,(DrawFile)
        add     a,a
        add     a,8
        ld      e,a
        ld      d,0
        add     hl,de
        ld      de,(TmsNameAddr)
        add     hl,de
        ret

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
        ; REV2 anti-blink reset.  Do not clear the whole screen.
        ; Only redraw the board area and rebuild tile pieces.
        call    ResetPieces
        call    DrawAllPieceTiles
        call    WriteSprites
        xor     a
        ld      (SpriteDirty),a
        ld      a,30
        ld      (MovePause),a
        ret

ChessThink:
        ld      a,(MovePause)
        or      a
        jp      z,ThinkNoPause
        ld      b,a
        ld      a,(ThinkingFlag)
        or      a
        push    bc
        call    nz,ShowThinkingHeartbeat
        pop     bc
        ld      a,b
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
        call    ShowThinkStart
        call    ChooseBestMove
        ld      a,(BestFound)
        or      a
        jp      z,DrawGame
        ld      a,(BestPiece)
        ld      (ActivePiece),a
        call    DrawThinkingStatus
        call    Rand8
        and     63
        add     a,32                    ; REV8: 32..95 frames of visible deep thinking
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

        ; REV11: configure clean square-to-square animation after the real
        ; source square has been saved in LastFromFile/LastFromRank.
        call    SetupMoveAnimation

        ; Remove a captured piece, if any.
        ld      a,(BestCapture)
        ld      (CapturePiece),a
        cp      0ffh
        jp      z,BestNoCapture
        call    ScoreCapture
        ld      a,(BestCapture)
        call    KillPiece
BestNoCapture:
        ; REV2 tile-piece display: clear the source and target board squares
        ; before animation.  The moving piece is shown by one hardware sprite.
        call    ClearMoveSquares

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

        ; REV17 stable tile mode:
        ; Do not use the hardware sprite mover at all.  We update the
        ; logical board and draw the final resting tile only.  This proves
        ; whether the blinky display is coming from sprite/VRAM animation
        ; instead of the Z180 timing library.
        jp      MoveArrived

; ------------------------------------------------------------
; Move chooser.

ChooseBestMove:
        xor     a
        ld      (BestFound),a
        ld      (BestScore),a
        call    ResetPlanRam

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
        call    ShowThoughtRaw
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
        call    SummarizePlanRam
        ret


; ------------------------------------------------------------
; REV20 CP/M free-RAM planner.
;
; CP/M .COM runs in one TPA.  Instead of padding the COM, REV20 finds the
; real RAM above ProgramEnd and below BDOS, then uses it as a temporary
; move-plan buffer.  Every legal scored candidate stores 4 bytes:
;   byte 0 = candidate piece index
;   byte 1 = target square, high nibble rank / low nibble file
;   byte 2 = candidate score
;   byte 3 = flags: bit7 capture, bit6 side, bits0..5 plan serial
;
; This gives the engine a real RAM-backed planning trace without risking
; a too-large flat COM image.

InitFreeRamPlanner:
        ld      hl,ProgramEnd
        ld      de,0100h               ; safety guard after the loaded program
        add     hl,de
        ld      (RamBase),hl
        ld      (RamCursor),hl

        ld      hl,(0006h)              ; CP/M BDOS entry target from JMP 0005h
        ld      de,0100h               ; keep a guard below BDOS/CCP area
        or      a
        sbc     hl,de
        ld      (RamEnd),hl

        ld      de,(RamBase)
        or      a
        sbc     hl,de                  ; HL = usable bytes, roughly
        jp      c,NoPlannerRam
        ld      a,h                    ; pages available
        cp      2
        jp      c,NoPlannerRam
        ld      (FreeRamPages),a
        ld      a,1
        ld      (RamEnabled),a
        ret
NoPlannerRam:
        xor     a
        ld      (RamEnabled),a
        ld      (FreeRamPages),a
        ret



; ------------------------------------------------------------
; REV26 RomWBW/HBIOS app-bank brain integration.
;
; RBKTST3 proved the correct safe path on the SC700:
;   APPBNKS status 00, start 89h, count 03h, size 80h pages.
;   Banks 89h, 8Ah, 8Bh each pass SYSPEEK/SYSPOKE verify/restore.
;
; CHXR26 therefore does not raw-write Z180 CBR/BBR/CBAR.
; It asks RomWBW for the official app-bank range through RWBANK.ASM.
;
; Bank use:
;   BankBrainBank0 = board/eval cache pattern       (normally 89h)
;   BankBrainBank1 = move ordering/history pattern  (normally 8Ah)
;   BankBrainBank2 = deeper planner/neural pattern  (normally 8Bh)

InitRomWBWBankBrain:
        xor     a
        ld      (BankBrainEnabled),a
        ld      (BankBrainStatusOR),a
        ld      (BankBrainLastStatus),a
        ld      (BankBrainLastByte),a

        call    RWBK_Init
        ld      (BankBrainInitStatus),a
        or      a
        ret     nz

        call    RWBK_GetInfo
        ld      (BankBrainInfoStatus),a
        ld      a,h
        ld      (BankBrainStart),a
        ld      a,l
        ld      (BankBrainCount),a
        ld      a,e
        ld      (BankBrainSizePg),a

        ld      a,(BankBrainCount)
        cp      3
        ret     c

        ld      a,(BankBrainStart)
        ld      (BankBrainBank0),a
        inc     a
        ld      (BankBrainBank1),a
        inc     a
        ld      (BankBrainBank2),a

        ld      a,1
        ld      (BankBrainEnabled),a

        call    SeedRomWBWBankBrain
        ld      a,(BankBrainStatusOR)
        or      a
        ret     z

        ; If any HBIOS write failed while seeding, disable the app-bank brain.
        xor     a
        ld      (BankBrainEnabled),a
        ret

ShutdownRomWBWBankBrain:
        ; RWBANK uses SYSPEEK/SYSPOKE only.  No visible bank is switched,
        ; so there is no raw MMU state to restore on exit.
        ret

SeedRomWBWBankBrain:
        xor     a
        ld      (BankBrainStatusOR),a
        ld      a,(BankBrainBank0)
        call    SeedOneRomWBWBrainBank
        ld      a,(BankBrainBank1)
        call    SeedOneRomWBWBrainBank
        ld      a,(BankBrainBank2)
        jp      SeedOneRomWBWBrainBank

SeedOneRomWBWBrainBank:
        ld      (BankBrainTempBank),a
        xor     a
        ld      (BankBrainSeedIndex),a
SeedOneBankLoop:
        call    MakeBankBrainSeedByte
        ld      a,(BankBrainTempBank)
        ld      d,a
        ld      h,070h                 ; table base 7000h
        ld      a,(BankBrainSeedIndex)
        ld      l,a
        call    RWBK_Poke
        call    BankBrainOrStatus
        ld      hl,BankBrainSeedIndex
        inc     (hl)
        jp      nz,SeedOneBankLoop
        ret

MakeBankBrainSeedByte:
        ; Output E = deterministic brain-table byte.
        ; Uses bank id, index, ply salt and three simple non-linear mixes.
        ld      a,(BankBrainSeedIndex)
        ld      b,a
        ld      a,(BankBrainTempBank)
        add     a,b
        xor     b
        rlca
        ld      c,a
        ld      a,b
        rrca
        xor     c
        add     a,031h
        ld      e,a
        ret

BankBrainOrStatus:
        push    af
        ld      c,a
        ld      a,(BankBrainStatusOR)
        or      c
        ld      (BankBrainStatusOR),a
        pop     af
        ret

; ------------------------------------------------------------
; REV26 external brain file loader.
;
; CP/M has no DLLs, so this uses a safe retro equivalent:
;   CHXR29.COM = main program
;   CHXR29.BRN = external brain/table data
;
; If CHXR29.BRN is present, it is loaded into free RAM found by
; InitFreeRamPlanner.  The RAM planner then starts after the loaded brain.
; If the file is missing or RAM is tight, the game falls back to the built-in
; COM-resident brain and still runs normally.

LoadExternalBrain:
        xor     a
        ld      (BrnLoaded),a
        ld      (BrnFilePresent),a
        ld      (BrnRecords),a
        dec     a
        ld      (BrnOpenStatus),a       ; FF until open attempted

        ; REV29: first prove the BRN exists.  Even if there is not enough
        ; normal CP/M free RAM to load much of it, a present BRN can still
        ; be used as a disk/file brain marker with RWBANK as primary brain.
        ld      de,BrnFcb
        ld      c,15                    ; BDOS OPEN FILE
        call    0005h
        ld      (BrnOpenStatus),a
        inc     a                       ; A=FFh means open failed
        ret     z
        ld      a,1
        ld      (BrnFilePresent),a

        ld      a,(RamEnabled)
        or      a
        ret     z

        ld      hl,(RamBase)
        ld      (BrnBase),hl
        ld      (BrnCursor),hl

LoadBrnLoop:
        ; Need room for another 128-byte record below RamEnd.
        ld      hl,(BrnCursor)
        ld      de,0080h
        add     hl,de
        ex      de,hl                   ; DE = cursor + 128
        ld      hl,(RamEnd)
        or      a
        sbc     hl,de
        jp      c,LoadBrnDone

        ld      de,(BrnCursor)
        ld      c,26                    ; BDOS SET DMA ADDRESS
        call    0005h

        ld      de,BrnFcb
        ld      c,20                    ; BDOS READ SEQUENTIAL
        call    0005h
        or      a
        jp      nz,LoadBrnDone

        ld      hl,(BrnCursor)
        ld      de,0080h
        add     hl,de
        ld      (BrnCursor),hl
        ld      hl,BrnRecords
        inc     (hl)
        ld      a,(hl)
        cp      0f0h                    ; avoid byte wrap
        jp      c,LoadBrnLoop

LoadBrnDone:
        ; Restore normal CP/M DMA buffer at 0080h.
        ld      de,0080h
        ld      c,26
        call    0005h

        ld      a,(BrnRecords)
        or      a
        ret     z
        ld      a,1
        ld      (BrnLoaded),a
        ld      hl,(BrnCursor)
        ld      (BrnEnd),hl

        ; Move normal planner RAM above the loaded external brain.
        ld      de,0100h
        add     hl,de
        ld      (RamBase),hl
        ld      (RamCursor),hl

        ; Recalculate remaining free pages for the planner.
        ld      de,(RamBase)
        ld      hl,(RamEnd)
        or      a
        sbc     hl,de
        jp      c,BrnNoPlannerSpace
        ld      a,h
        ld      (FreeRamPages),a
        or      a
        jp      z,BrnNoPlannerSpace
        ld      a,1
        ld      (RamEnabled),a
        ret
BrnNoPlannerSpace:
        xor     a
        ld      (FreeRamPages),a
        ld      (RamEnabled),a
        ret

; ------------------------------------------------------------
; REV21 Z180 deep-brain setup.
;
; The program still runs as a normal CP/M .COM, but on the SC700 Z180 it
; enables deeper scoring passes.  This uses the z180.asm detection/get-clock
; path instead of guessing from machine type.

InitZ180BrainMode:
        xor     a
        ld      (Z180BrainMode),a
        ld      (BrainDepthBudget),a
        ld      (BrainRamBudget),a
        call    z180detect
        ret     nz
        call    z180getclk
        ld      a,1
        ld      (Z180BrainMode),a
        ld      a,(BankBrainEnabled)
        or      a
        jp      nz,Z180BrainBanked
        ld      a,(FreeRamPages)
        cp      10
        jp      nc,Z180BrainLarge
        cp      5
        jp      nc,Z180BrainMedium
Z180BrainSmall:
        ld      a,1
        ld      (BrainDepthBudget),a
        ld      a,16
        ld      (BrainRamBudget),a
        ret
Z180BrainMedium:
        ld      a,2
        ld      (BrainDepthBudget),a
        ld      a,64
        ld      (BrainRamBudget),a
        ret
Z180BrainLarge:
        ld      a,3
        ld      (BrainDepthBudget),a
        ld      a,160
        ld      (BrainRamBudget),a
        ret
Z180BrainBanked:
        ld      a,4
        ld      (BrainDepthBudget),a
        ld      a,96
        ld      (BrainRamBudget),a
        ret

; ------------------------------------------------------------
; REV29 best-brain selector.
;
; BrainModeUsed:
;   4 = RWBANK app banks + CHXR29.BRN bonus loaded
;   3 = RWBANK app-bank brain only
;   2 = CHXR29.BRN external brain only
;   1 = normal CP/M free-RAM planner
;   0 = built-in internal brain only
;
; The scoring path always prefers the strongest safe mode.  RWBANK is
; considered strongest because RBKTST3 proved banks 89/8A/8B are official
; RomWBW app banks with SYSPEEK/SYSPOKE status 00.

SelectBestBrainMode:
        xor     a
        ld      (BrainModeUsed),a
        ld      a,(BankBrainEnabled)
        or      a
        jp      nz,SelectBestBrainBank
        ld      a,(BrnLoaded)
        or      a
        jp      nz,SelectBestBrainBrn
        ld      a,(RamEnabled)
        or      a
        jp      nz,SelectBestBrainRam
        ret
SelectBestBrainBank:
        ; REV29: RWBANK is primary and already proven.  If the BRN file is
        ; present on disk, show/use the combined best tier even when the old
        ; low-RAM loader could not load 36 records into normal CP/M RAM.
        ld      a,(BrnFilePresent)
        or      a
        jp      nz,SelectBestBrainBankBrnPresent
        ld      a,(BrnLoaded)
        or      a
        jp      z,SelectBestBrainBankOnly
        ld      a,(BrnRecords)
        cp      36
        jp      c,SelectBestBrainBankOnly
SelectBestBrainBankBrnPresent:
        ld      a,4
        ld      (BrainModeUsed),a
        ret
SelectBestBrainBankOnly:
        ld      a,3
        ld      (BrainModeUsed),a
        ret
SelectBestBrainBrn:
        ld      a,2
        ld      (BrainModeUsed),a
        ret
SelectBestBrainRam:
        ld      a,1
        ld      (BrainModeUsed),a
        ret

ResetPlanRam:
        ld      a,(RamEnabled)
        or      a
        ret     z
        ld      hl,(RamBase)
        ld      (RamCursor),hl
        xor     a
        ld      (PlanMoveCount),a
        ret

StoreCandidatePlan:
        call    StoreCandidateBankPlan
        ld      a,(RamEnabled)
        or      a
        ret     z
        ld      a,(PlanMoveCount)
        cp      220
        ret     nc
        ld      hl,(RamCursor)
        ld      de,(RamEnd)
        ld      a,h
        cp      d
        jp      c,StorePlanOK
        ret     nz
        ld      a,l
        cp      e
        ret     nc
StorePlanOK:
        ld      a,(CandidatePiece)
        ld      (hl),a
        inc     hl
        call    EncodeTargetSquareA
        ld      (hl),a
        inc     hl
        ld      a,(CandScore)
        ld      (hl),a
        inc     hl
        call    BuildPlanFlagA
        ld      (hl),a
        inc     hl
        ld      (RamCursor),hl
        ld      hl,PlanMoveCount
        inc     (hl)
        ret


StoreCandidateBankPlan:
        ; REV26: live legal-candidate planning trace in official RomWBW app RAM.
        ; Address 7100h + PlanMoveCount:
        ;   bank0 89h = candidate score
        ;   bank1 8Ah = target square encoding
        ;   bank2 8Bh = plan flags
        ld      a,(BankBrainEnabled)
        or      a
        ret     z
        ld      a,(PlanMoveCount)
        cp      0f0h
        ret     nc
        ld      (BankBrainPlanIndex),a

        ld      h,071h
        ld      a,(BankBrainPlanIndex)
        ld      l,a
        ld      a,(CandScore)
        ld      e,a
        ld      a,(BankBrainBank0)
        ld      d,a
        call    RWBK_Poke
        ld      (BankBrainLastStatus),a

        ld      h,071h
        ld      a,(BankBrainPlanIndex)
        ld      l,a
        call    EncodeTargetSquareA
        ld      e,a
        ld      a,(BankBrainBank1)
        ld      d,a
        call    RWBK_Poke
        ld      (BankBrainLastStatus),a

        ld      h,071h
        ld      a,(BankBrainPlanIndex)
        ld      l,a
        call    BuildPlanFlagA
        ld      e,a
        ld      a,(BankBrainBank2)
        ld      d,a
        call    RWBK_Poke
        ld      (BankBrainLastStatus),a
        ret

BuildPlanFlagA:
        ld      a,(PlanMoveCount)
        and     03fh
        ld      b,a
        ld      a,(CurrentSide)
        or      a
        ld      a,b
        jp      z,PlanFlagSideDone
        or      040h
PlanFlagSideDone:
        ld      b,a
        ld      a,(TargetOccupant)
        cp      0ffh
        ld      a,b
        ret     z
        or      080h
        ret

SummarizePlanRam:
        ; Port 02h gets a final true planning summary.  REV29 high nibble
        ; identifies the best brain in use:
        ;   F0h = RWBANK app banks + BRN bonus
        ;   E0h = RWBANK app banks
        ;   C0h = BRN external brain
        ;   normal XOR value = RAM/internal fallback
        ld      a,(BrainModeUsed)
        cp      4
        jp      z,SummarizeBrainModeF
        cp      3
        jp      z,SummarizeBrainModeE
        cp      2
        jp      z,SummarizeBrainModeC
        jp      SummarizeNormalPlanRam
SummarizeBrainModeF:
        ld      a,0f0h
        jp      SummarizeBrainModePage
SummarizeBrainModeE:
        ld      a,0e0h
        jp      SummarizeBrainModePage
SummarizeBrainModeC:
        ld      a,0c0h
SummarizeBrainModePage:
        ld      b,a
        ld      a,(PlanMoveCount)
        and     00fh
        or      b
        out     (02h),a
        ret
SummarizeNormalPlanRam:
        ld      a,(PlanMoveCount)
        ld      b,a
        ld      a,(FreeRamPages)
        xor     b
        out     (02h),a
        ret

; ------------------------------------------------------------
; REV20 CP/M free-RAM planner and SC719 LED thought display - REAL LIVE DATA.
;
; Port 00h = BLACK thinking data only.  Cleared while white thinks.
; Port 01h = WHITE thinking data only.  Cleared while black thinks.
; Port 02h = separate live game-data bus, not side-thought data.
;
; Raw candidate scan, before legality:
;   active side port bits:
;     bit 7 = 0 raw scan
;     bit 6 = 0 not yet legal/scored
;     bit 5 = target square is occupied
;     bits 4..0 = actual CandidatePiece index
;
; Legal candidate / deep scoring:
;   active side port bits:
;     bit 7 = 0 candidate, not final best
;     bit 6 = 1 legal candidate being scored
;     bit 5 = capture/occupied enemy target
;     bits 4..0 = actual CandidatePiece index
;
; New best move:
;   active side port bits:
;     bit 7 = 1 NEW BEST MOVE
;     bit 6 = 1 valid/best
;     bit 5 = capture
;     bits 4..0 = actual BestPiece index
;
; Visible think pause after scan:
;   active side port bits:
;     bit 7 = 1 chosen best move
;     bit 6 = real MovePause countdown bit, so it still pulses
;     bit 5 = capture
;     bits 4..0 = actual BestPiece index
;
; Port 02h all the time: separate game-data bus, page-coded by bits 7..6.
;   00xxxxxx = turn/ply page: bit5 side, bits4..0 GamePly
;   01xxxxxx = RAM plan page: bit5 RAM enabled, bits4..0 legal moves stored
;   10xxxxxx = score page: bit5 black capture lead, bits4..0 score delta
;   11xxxxxx = draw/best page: bit5 best found, bits4..0 quiet-ply clock

ShowThinkStart:
        ; Start of a real scan.  Clear the inactive side and put a real
        ; game-data bus on 02h right away.
        call    BuildGameDataLedA
        ld      b,a
        ld      a,(CurrentSide)
        or      a
        jp      z,ShowWhiteThinkStart
ShowBlackThinkStart:
        xor     a
        out     (01h),a                  ; white LEDs off while black thinks
        ld      a,b
        out     (02h),a                  ; live game-data bus, not a fake pattern
        ret
ShowWhiteThinkStart:
        xor     a
        out     (00h),a                  ; black LEDs off while white thinks
        ld      a,b
        out     (02h),a                  ; live game-data bus, not a fake pattern
        ret

ShowThinkingHeartbeat:
        ; During the visible after-scan think pause, keep the active side
        ; alive with the chosen best move plus the real MovePause countdown
        ; bit, and keep 02h showing the game-data bus.
        call    BuildPauseLedByteA
        ld      b,a
        call    BuildGameDataLedA
        ld      c,a
        ld      a,(CurrentSide)
        or      a
        jp      z,ShowWhiteHeartbeat
ShowBlackHeartbeat:
        xor     a
        out     (01h),a
        ld      a,b
        out     (00h),a
        ld      a,c
        out     (02h),a
        ret
ShowWhiteHeartbeat:
        xor     a
        out     (00h),a
        ld      a,b
        out     (01h),a
        ld      a,c
        out     (02h),a
        ret

ShowThoughtRaw:
        ; Real raw scan output for EVERY candidate square before legality.
        ; This is why LEDs move even while the engine is deep-searching.
        call    GetTargetOccupant       ; real occupancy for this target square
        call    BuildRawLedByteA
        ld      b,a
        call    BuildGameDataLedA
        ld      c,a
        ld      a,(CurrentSide)
        or      a
        jp      z,ShowWhiteRaw
ShowBlackRaw:
        ld      a,b
        out     (00h),a
        ld      a,c
        out     (02h),a
        ret
ShowWhiteRaw:
        ld      a,b
        out     (01h),a
        ld      a,c
        out     (02h),a
        ret

ShowThoughtCandidate:
        ; Real legal candidate: piece + legal/capture flags on side port,
        ; live game-data bus on 02h.
        call    BuildCandidateLedByteA
        ld      b,a
        call    BuildGameDataLedA
        ld      c,a
        ld      a,(CurrentSide)
        or      a
        jp      z,ShowWhiteCandidate
ShowBlackCandidate:
        ld      a,b
        out     (00h),a
        ld      a,c
        out     (02h),a
        ret
ShowWhiteCandidate:
        ld      a,b
        out     (01h),a
        ld      a,c
        out     (02h),a
        ret

ShowThoughtBest:
        ; Real new-best marker: bit 7 set, piece + capture flag on side port,
        ; live game-data bus on 02h.
        call    BuildBestLedByteA
        ld      b,a
        call    BuildGameDataLedA
        ld      c,a
        ld      a,(CurrentSide)
        or      a
        jp      z,ShowWhiteBest
ShowBlackBest:
        ld      a,b
        out     (00h),a
        ld      a,c
        out     (02h),a
        ret
ShowWhiteBest:
        ld      a,b
        out     (01h),a
        ld      a,c
        out     (02h),a
        ret

BuildRawLedByteA:
        ; bit 7 = 0 raw scan, bit 6 = 0 not yet legal,
        ; bit 5 = target occupied, bits 4..0 = actual CandidatePiece index.
        ld      a,(CandidatePiece)
        and     01fh
        ld      b,a
        ld      a,(TargetOccupant)
        cp      0ffh
        ld      a,b
        ret     z
        or      020h
        ret

BuildCandidateLedByteA:
        ; bit 6 = legal candidate, bit 5 = capture/occupied enemy,
        ; bits 4..0 = actual CandidatePiece index.
        ld      a,(CandidatePiece)
        and     01fh
        or      040h
        ld      b,a
        ld      a,(TargetOccupant)
        cp      0ffh
        ld      a,b
        ret     z
        or      020h
        ret

BuildBestLedByteA:
        ; bit 7 = new best marker, bit 6 = valid, bit 5 = capture,
        ; bits 4..0 = actual BestPiece index.
        ld      a,(BestPiece)
        and     01fh
        or      0c0h
        ld      b,a
        ld      a,(BestCapture)
        cp      0ffh
        ld      a,b
        ret     z
        or      020h
        ret

BuildPauseLedByteA:
        ; bit 7 = chosen best, bit 6 = real countdown bit,
        ; bit 5 = capture, bits 4..0 = actual BestPiece index.
        ld      a,(BestPiece)
        and     01fh
        or      080h
        ld      b,a
        ld      a,(BestCapture)
        cp      0ffh
        ld      a,b
        jp      z,BuildPauseNoCapture
        or      020h
BuildPauseNoCapture:
        ld      b,a
        ld      a,(MovePause)
        and     1
        ld      a,b
        ret     z
        or      040h
        ret

BuildGameDataLedA:
        ; REV20: port 02h is NOT another thought channel.
        ; It is a separate live game-data bus with page ID in bits 7..6.
        ; Page 0 = turn/ply, page 1 = RAM planner, page 2 = score lead,
        ; page 3 = draw/best status.  Every call advances the page so the
        ; LEDs keep moving with real game state while 00h/01h show thought.
        ld      hl,GameLedPage
        inc     (hl)
        ld      a,(hl)
        and     03h
        jp      z,BuildGameLedTurnPly
        cp      1
        jp      z,BuildGameLedRamPlan
        cp      2
        jp      z,BuildGameLedScoreLead
        jp      BuildGameLedDrawBest

BuildGameLedTurnPly:
        ; 00xxxxxx: bit5 = side to move, bits4..0 = live GamePly low 5.
        ld      a,(GamePly)
        and     01fh
        ld      b,a
        ld      a,(CurrentSide)
        or      a
        ld      a,b
        ret     z
        or      020h
        ret

BuildGameLedRamPlan:
        ; 01xxxxxx: bit5 = verified RomWBW bank-brain or RAM planner enabled,
        ; bits4..0 = stored legal moves.
        ld      a,(PlanMoveCount)
        and     01fh
        ld      b,a
        ld      a,(BankBrainEnabled)
        or      a
        jp      nz,BuildGameLedRamFlag
        ld      a,(RamEnabled)
        or      a
        ld      a,b
        jp      z,BuildGameLedRamNoFlag
BuildGameLedRamFlag:
        ld      a,b
        or      020h
BuildGameLedRamNoFlag:
        or      040h
        ret

BuildGameLedScoreLead:
        ; 10xxxxxx: bit5 = black leads in captures, bits4..0 = score delta.
        ; Uses the real displayed capture-score digits, separate from 00h/01h.
        call    GetWhiteScoreA
        ld      b,a
        call    GetBlackScoreA
        cp      b
        jp      nc,BuildGameLedBlackLead
BuildGameLedWhiteLead:
        ld      c,a                     ; black score
        ld      a,b                     ; white score
        sub     c
        and     01fh
        or      080h
        ret
BuildGameLedBlackLead:
        sub     b
        and     01fh
        or      0a0h
        ret

BuildGameLedDrawBest:
        ; 11xxxxxx: bit5 = a legal best exists, bits4..0 = quiet/draw clock.
        ld      a,(NoProgressPly)
        and     01fh
        ld      b,a
        ld      a,(BestFound)
        or      a
        ld      a,b
        jp      z,BuildGameLedDrawNoBest
        or      020h
BuildGameLedDrawNoBest:
        or      0c0h
        ret

GetWhiteScoreA:
        ; REV29: WhiteScore10/1 are high/low HEX nibbles, not decimal digits.
        ld      a,(WhiteScore10)
        and     0fh
        add     a,a
        add     a,a
        add     a,a
        add     a,a                     ; high nibble * 16
        ld      b,a
        ld      a,(WhiteScore1)
        and     0fh
        or      b
        ret

GetBlackScoreA:
        ; REV29: BlackScore10/1 are high/low HEX nibbles, not decimal digits.
        ld      a,(BlackScore10)
        and     0fh
        add     a,a
        add     a,a
        add     a,a
        add     a,a                     ; high nibble * 16
        ld      b,a
        ld      a,(BlackScore1)
        and     0fh
        or      b
        ret

EncodeTargetSquareA:
        ; A = rank/file packed as RRRRFFFF.  Kept for debug/use elsewhere.
        ld      a,(TargetRank)
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        ld      b,a
        ld      a,(TargetFile)
        or      b
        ret

ScoreAndMaybeBest:
        call    ScoreCandidate
        call    ShowThoughtCandidate
        call    StoreCandidatePlan
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
        call    ShowThoughtBest
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

        ; REV8: a king may not walk onto an enemy attack square.
        ; This also prevents the two kings from touching.
        call    TargetAttackedByEnemyDeep
        jp      c,LegalNo
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
        ; REV20: strict rule-safety gate.  A move is only legal if, after
        ; a real temporary board simulation, our own king is not attacked.
        jp      KingSafeAfterCandidate
LegalNo:
        or      a                       ; clear carry
        ret

; ------------------------------------------------------------
; REV20 strict king-safety simulation.
;
; The old show engine avoided illegal piece movement and illegal king moves,
; but non-king pieces could still uncover check.  REV20 temporarily applies
; the candidate move to the live board, scans enemy attacks against our king,
; then restores the board exactly.  This keeps the game chess-logical.

KingSafeAfterCandidate:
        ; Save the visible candidate target because the attack scan uses
        ; TargetFile/TargetRank as its query square.
        ld      a,(TargetFile)
        ld      (SavedTargetFile),a
        ld      a,(TargetRank)
        ld      (SavedTargetRank),a
        ld      a,(TargetOccupant)
        ld      (SavedTargetOccupant),a

        call    ApplyCandidateSim
        call    SetTargetToOwnKing
        ld      a,1
        ld      (AttackSimFlag),a
        call    TargetAttackedByEnemyDeep
        jp      c,KingSimUnsafe
KingSimSafe:
        xor     a
        ld      (KingUnsafeFlag),a
        jp      KingSimRestore
KingSimUnsafe:
        ld      a,1
        ld      (KingUnsafeFlag),a
KingSimRestore:
        xor     a
        ld      (AttackSimFlag),a
        call    RestoreCandidateSim
        ld      a,(SavedTargetFile)
        ld      (TargetFile),a
        ld      a,(SavedTargetRank)
        ld      (TargetRank),a
        ld      a,(SavedTargetOccupant)
        ld      (TargetOccupant),a
        ld      a,(KingUnsafeFlag)
        or      a
        jp      nz,KingSimNo
        scf
        ret
KingSimNo:
        or      a
        ret

ApplyCandidateSim:
        ; From square becomes empty.
        ld      a,(FromFile)
        ld      b,a
        ld      a,(FromRank)
        ld      c,a
        ld      a,b
        ld      b,c
        call    BoardPtrByFileRank
        ld      (hl),0ffh

        ; Target square now contains the candidate piece.
        ld      a,(TargetFile)
        ld      b,a
        ld      a,(TargetRank)
        ld      c,a
        ld      a,b
        ld      b,c
        call    BoardPtrByFileRank
        ld      a,(CandidatePiece)
        ld      (hl),a

        ; Candidate piece coordinates are temporarily moved.
        ld      a,(CandidatePiece)
        call    PtrPieceFile
        ld      a,(TargetFile)
        ld      (hl),a
        ld      a,(CandidatePiece)
        call    PtrPieceRank
        ld      a,(TargetRank)
        ld      (hl),a

        ; Captured piece is temporarily dead.
        ld      a,(SavedTargetOccupant)
        cp      0ffh
        ret     z
        call    PtrPieceAlive
        xor     a
        ld      (hl),a
        ret

RestoreCandidateSim:
        ; Restore target square to its old occupant, if any.
        ld      a,(SavedTargetFile)
        ld      b,a
        ld      a,(SavedTargetRank)
        ld      c,a
        ld      a,b
        ld      b,c
        call    BoardPtrByFileRank
        ld      a,(SavedTargetOccupant)
        ld      (hl),a

        ; Restore source square to the moving piece.
        ld      a,(FromFile)
        ld      b,a
        ld      a,(FromRank)
        ld      c,a
        ld      a,b
        ld      b,c
        call    BoardPtrByFileRank
        ld      a,(CandidatePiece)
        ld      (hl),a

        ; Restore candidate coordinates.
        ld      a,(CandidatePiece)
        call    PtrPieceFile
        ld      a,(FromFile)
        ld      (hl),a
        ld      a,(CandidatePiece)
        call    PtrPieceRank
        ld      a,(FromRank)
        ld      (hl),a

        ; Restore captured piece alive flag.
        ld      a,(SavedTargetOccupant)
        cp      0ffh
        ret     z
        call    PtrPieceAlive
        ld      (hl),1
        ret

SetTargetToOwnKing:
        ld      a,(CurrentSide)
        or      a
        jp      z,SetWhiteKingTarget
SetBlackKingTarget:
        ld      a,16
        ld      (KingScanPiece),a
        ld      a,32
        ld      (KingScanEnd),a
        jp      SetKingTargetLoop
SetWhiteKingTarget:
        xor     a
        ld      (KingScanPiece),a
        ld      a,16
        ld      (KingScanEnd),a
SetKingTargetLoop:
        ld      a,(KingScanPiece)
        ld      b,a
        ld      a,(KingScanEnd)
        cp      b
        ret     z
        ld      a,(KingScanPiece)
        call    PtrPieceAlive
        ld      a,(hl)
        or      a
        jp      z,SetKingTargetNext
        ld      a,(KingScanPiece)
        call    PtrPieceType
        ld      a,(hl)
        cp      TypeKing
        jp      nz,SetKingTargetNext
        ld      a,(KingScanPiece)
        call    PtrPieceFile
        ld      a,(hl)
        ld      (TargetFile),a
        ld      a,(KingScanPiece)
        call    PtrPieceRank
        ld      a,(hl)
        ld      (TargetRank),a
        ret
SetKingTargetNext:
        ld      hl,KingScanPiece
        inc     (hl)
        jp      SetKingTargetLoop

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
; REV8 expanded heuristic brain.
; These routines are deliberately table-heavy so the final COM has a much
; larger real chess brain instead of just graphics and a tiny move picker.

ScoreAdvancedBrain:
        call    ScorePieceSquareBonus
        call    ShowThoughtCandidate
        call    ScorePawnStructureBonus
        call    ShowThoughtCandidate
        call    ScorePromotionBonus
        call    ShowThoughtCandidate
        call    ScoreMobilityBonus
        call    ShowThoughtCandidate
        call    ScoreOpeningLogic
        call    ShowThoughtCandidate
        call    ScoreDefendedTargetBonus
        call    ShowThoughtCandidate
        call    ScoreDeepThreatLogic
        call    ShowThoughtCandidate
        call    ScoreKingDangerPenalty
        call    ShowThoughtCandidate
        call    ScoreExchangeLogic
        call    ShowThoughtCandidate
        call    ScoreEndgameLogic
        call    ShowThoughtCandidate
        call    ScoreCheckPressureBonus
        call    ShowThoughtCandidate
        call    ScoreOpponentReplyPenalty
        call    ShowThoughtCandidate
        call    ScoreWinningThreatBonus
        call    ShowThoughtCandidate
        call    ScoreRamPlanBonus
        call    ShowThoughtCandidate
        call    ScoreZ180RamDepthBonus
        call    ShowThoughtCandidate
        call    ScoreRuleLockBonus
        call    ShowThoughtCandidate
        call    ScoreZ180WideNeuroBonus
        call    ShowThoughtCandidate
        call    ScoreZ180BankStatusBonus
        call    ShowThoughtCandidate
        call    ScoreSafetyPenalty
        call    ShowThoughtCandidate
        call    ScoreHistoryPenalty
        call    ShowThoughtCandidate
        call    ScoreDeepBookBonus
        call    ShowThoughtCandidate
        call    ScoreMegaBrainBonus
        call    ShowThoughtCandidate
        call    ScoreBrainHashBonus
        call    ShowThoughtCandidate
        ret

; REV8 logic layer.  These routines make the engine look much more
; chess-like by mapping enemy attacks, friendly defenders, opening logic,
; and king danger before the final move is stored.

ScoreMobilityBonus:
        ; Reward useful movement without letting long queen moves dominate.
        ld      a,(AbsDX)
        ld      b,a
        ld      a,(AbsDY)
        add     a,b
        and     15
        call    ScoreAddA

        ; Prefer living away from the board edge.
        ld      a,(TargetFile)
        or      a
        ret     z
        cp      7
        ret     z
        ld      a,(TargetRank)
        or      a
        ret     z
        cp      7
        ret     z
        ld      a,3
        jp      ScoreAddA

ScoreOpeningLogic:
        ; Early game: develop minor pieces, do not fling the queen/king around.
        ld      a,(GamePly)
        cp      24
        ret     nc
        ld      a,(CandidatePiece)
        call    PtrPieceType
        ld      a,(hl)
        cp      TypeKnight
        jp      z,OpeningMinor
        cp      TypeBishop
        jp      z,OpeningMinor
        cp      TypeQueen
        jp      z,OpeningQueenPenalty
        cp      TypeKing
        jp      z,OpeningKingPenalty
        ret
OpeningMinor:
        ld      a,(FromRank)
        cp      0
        jp      z,OpeningMinorHome
        cp      7
        jp      z,OpeningMinorHome
        ret
OpeningMinorHome:
        ld      a,12
        jp      ScoreAddA
OpeningQueenPenalty:
        ld      a,18
        jp      ScoreSubA
OpeningKingPenalty:
        ld      a,30
        jp      ScoreSubA

ScoreDefendedTargetBonus:
        ; A defended destination is safer and looks like real chess.
        call    TargetDefendedByOwnDeep
        ret     nc
        ld      a,10
        call    ScoreAddA
        ld      a,(TargetOccupant)
        cp      0ffh
        ret     z
        ld      a,12
        jp      ScoreAddA

ScoreDeepThreatLogic:
        ; Penalize hanging moves using a full enemy attack scan, not only pawns.
        call    TargetAttackedByEnemyDeep
        ret     nc
        call    TargetDefendedByOwnDeep
        jp      c,DeepThreatDefended
        ld      a,(CandidatePiece)
        call    PtrPieceType
        ld      a,(hl)
        cp      TypePawn
        jp      z,DeepThreatPawn
        cp      TypeKnight
        jp      z,DeepThreatMinor
        cp      TypeBishop
        jp      z,DeepThreatMinor
        cp      TypeRook
        jp      z,DeepThreatRook
        cp      TypeQueen
        jp      z,DeepThreatQueen
        cp      TypeKing
        jp      z,DeepThreatKing
        ret
DeepThreatPawn:
        ld      a,12
        jp      ScoreSubA
DeepThreatMinor:
        ld      a,42
        jp      ScoreSubA
DeepThreatRook:
        ld      a,62
        jp      ScoreSubA
DeepThreatQueen:
        ld      a,95
        jp      ScoreSubA
DeepThreatKing:
        ld      a,180
        jp      ScoreSubA
DeepThreatDefended:
        ld      a,14
        jp      ScoreSubA

ScoreKingDangerPenalty:
        ; Extra protection: even after CheckKingMove, make scary king moves score bad.
        ld      a,(CandidatePiece)
        call    PtrPieceType
        ld      a,(hl)
        cp      TypeKing
        ret     nz
        call    TargetAttackedByEnemyDeep
        ret     nc
        ld      a,200
        jp      ScoreSubA

; ------------------------------------------------------------
; REV8 attack-map helpers.
; They scan all 32 pieces and answer: can this side attack/defend TargetFile/TargetRank?
; This is much more logical than the REV7 pawn-only danger check.

TargetAttackedByEnemyDeep:
        ld      a,(CurrentSide)
        or      a
        jp      z,TargetEnemyIsBlack
TargetEnemyIsWhite:
        xor     a
        ld      (AttackPiece),a
        ld      a,16
        ld      (AttackEndPiece),a
        jp      TargetEnemyScanLoop
TargetEnemyIsBlack:
        ld      a,16
        ld      (AttackPiece),a
        ld      a,32
        ld      (AttackEndPiece),a

TargetEnemyScanLoop:
        ld      a,(AttackPiece)
        ld      b,a
        ld      a,(AttackEndPiece)
        cp      b
        jp      z,TargetEnemyNoAttack
        ld      a,(AttackPiece)
        call    PtrPieceAlive
        ld      a,(hl)
        or      a
        jp      z,TargetEnemyNext
        call    TargetAttackedByAttackPiece
        ret     c
TargetEnemyNext:
        ld      hl,AttackPiece
        inc     (hl)
        jp      TargetEnemyScanLoop
TargetEnemyNoAttack:
        or      a
        ret

TargetDefendedByOwnDeep:
        ld      a,(CurrentSide)
        or      a
        jp      z,TargetOwnIsWhite
TargetOwnIsBlack:
        ld      a,16
        ld      (AttackPiece),a
        ld      a,32
        ld      (AttackEndPiece),a
        jp      TargetOwnScanLoop
TargetOwnIsWhite:
        xor     a
        ld      (AttackPiece),a
        ld      a,16
        ld      (AttackEndPiece),a

TargetOwnScanLoop:
        ld      a,(AttackPiece)
        ld      b,a
        ld      a,(AttackEndPiece)
        cp      b
        jp      z,TargetOwnNoDefender
        ld      a,(AttackPiece)
        ld      b,a
        ld      a,(CandidatePiece)
        cp      b
        jp      z,TargetOwnNext
        ld      a,(AttackPiece)
        call    PtrPieceAlive
        ld      a,(hl)
        or      a
        jp      z,TargetOwnNext
        call    TargetAttackedByAttackPiece
        ret     c
TargetOwnNext:
        ld      hl,AttackPiece
        inc     (hl)
        jp      TargetOwnScanLoop
TargetOwnNoDefender:
        or      a
        ret

TargetAttackedByAttackPiece:
        call    LoadAttackPieceState
        call    ComputeAttackDelta

        ; Same square is not an attack, and it prevents zero-step path loops.
        ld      a,(AttackAbsDX)
        ld      b,a
        ld      a,(AttackAbsDY)
        or      b
        jp      z,AttackNo

        ld      a,(AttackPiece)
        call    PtrPieceType
        ld      a,(hl)
        cp      TypePawn
        jp      z,AttackPawn
        cp      TypeKnight
        jp      z,AttackKnight
        cp      TypeBishop
        jp      z,AttackBishop
        cp      TypeRook
        jp      z,AttackRook
        cp      TypeQueen
        jp      z,AttackQueen
        cp      TypeKing
        jp      z,AttackKing
        jp      AttackNo

LoadAttackPieceState:
        ld      a,(AttackPiece)
        call    PtrPieceFile
        ld      a,(hl)
        ld      (AttackFile),a
        ld      a,(AttackPiece)
        call    PtrPieceRank
        ld      a,(hl)
        ld      (AttackRank),a
        ret

ComputeAttackDelta:
        ld      a,(TargetFile)
        ld      b,a
        ld      a,(AttackFile)
        ld      c,a
        ld      a,b
        sub     c
        ld      (AttackDX),a
        call    AbsA
        ld      (AttackAbsDX),a

        ld      a,(TargetRank)
        ld      b,a
        ld      a,(AttackRank)
        ld      c,a
        ld      a,b
        sub     c
        ld      (AttackDY),a
        call    AbsA
        ld      (AttackAbsDY),a
        ret

AttackPawn:
        ld      a,(AttackAbsDX)
        cp      1
        jp      nz,AttackNo
        ld      a,(AttackPiece)
        cp      16
        jp      c,AttackWhitePawn
AttackBlackPawn:
        ld      a,(AttackDY)
        cp      1
        jp      z,AttackYes
        jp      AttackNo
AttackWhitePawn:
        ld      a,(AttackDY)
        cp      0ffh
        jp      z,AttackYes
        jp      AttackNo

AttackKnight:
        ld      a,(AttackAbsDX)
        cp      1
        jp      nz,AttackKnightTryOther
        ld      a,(AttackAbsDY)
        cp      2
        jp      z,AttackYes
        jp      AttackNo
AttackKnightTryOther:
        cp      2
        jp      nz,AttackNo
        ld      a,(AttackAbsDY)
        cp      1
        jp      z,AttackYes
        jp      AttackNo

AttackKing:
        ld      a,(AttackAbsDX)
        cp      2
        jp      nc,AttackNo
        ld      a,(AttackAbsDY)
        cp      2
        jp      nc,AttackNo
        jp      AttackYes

AttackBishop:
        ld      a,(AttackAbsDX)
        ld      b,a
        ld      a,(AttackAbsDY)
        cp      b
        jp      nz,AttackNo
        jp      AttackPathClear

AttackRook:
        ld      a,(AttackAbsDX)
        or      a
        jp      z,AttackRookLineMaybe
        ld      a,(AttackAbsDY)
        or      a
        jp      z,AttackRookLineMaybe
        jp      AttackNo
AttackRookLineMaybe:
        jp      AttackPathClear

AttackQueen:
        ld      a,(AttackAbsDX)
        ld      b,a
        ld      a,(AttackAbsDY)
        cp      b
        jp      z,AttackQueenBishopMaybe
        ld      a,(AttackAbsDX)
        or      a
        jp      z,AttackQueenRookMaybe
        ld      a,(AttackAbsDY)
        or      a
        jp      z,AttackQueenRookMaybe
        jp      AttackNo
AttackQueenBishopMaybe:
        ld      a,(AttackAbsDX)
        or      a
        jp      z,AttackNo
        jp      AttackPathClear
AttackQueenRookMaybe:
        jp      AttackPathClear

AttackPathClear:
        call    SetAttackSteps
        ld      a,(AttackFile)
        ld      b,a
        ld      a,(AttackStepFile)
        add     a,b
        ld      (AttackPathFile),a
        ld      a,(AttackRank)
        ld      b,a
        ld      a,(AttackStepRank)
        add     a,b
        ld      (AttackPathRank),a
AttackPathLoop:
        ld      a,(AttackPathFile)
        ld      b,a
        ld      a,(TargetFile)
        cp      b
        jp      nz,AttackPathCheckSquare
        ld      a,(AttackPathRank)
        ld      b,a
        ld      a,(TargetRank)
        cp      b
        jp      z,AttackYes
AttackPathCheckSquare:
        ld      a,(AttackPathFile)
        ld      b,a
        ld      a,(AttackPathRank)
        ld      c,a
        ld      a,b
        ld      b,c
        call    BoardPtrByFileRank
        ld      a,(hl)
        cp      0ffh
        jp      z,AttackPathAdvance
        ld      b,a
        ld      a,(AttackSimFlag)
        or      a
        jp      nz,AttackNo            ; in simulated boards every piece blocks
        ld      a,(CandidatePiece)
        cp      b
        jp      nz,AttackNo
AttackPathAdvance:
        ld      a,(AttackPathFile)
        ld      b,a
        ld      a,(AttackStepFile)
        add     a,b
        ld      (AttackPathFile),a
        ld      a,(AttackPathRank)
        ld      b,a
        ld      a,(AttackStepRank)
        add     a,b
        ld      (AttackPathRank),a
        jp      AttackPathLoop

SetAttackSteps:
        xor     a
        ld      (AttackStepFile),a
        ld      (AttackStepRank),a
        ld      a,(AttackDX)
        or      a
        jp      z,AttackStepRankPart
        cp      80h
        jp      nc,AttackStepFileNeg
        ld      a,1
        ld      (AttackStepFile),a
        jp      AttackStepRankPart
AttackStepFileNeg:
        ld      a,0ffh
        ld      (AttackStepFile),a
AttackStepRankPart:
        ld      a,(AttackDY)
        or      a
        ret     z
        cp      80h
        jp      nc,AttackStepRankNeg
        ld      a,1
        ld      (AttackStepRank),a
        ret
AttackStepRankNeg:
        ld      a,0ffh
        ld      (AttackStepRank),a
        ret

AttackYes:
        scf
        ret
AttackNo:
        or      a
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


; REV15 deeper logic layer.
; Exchange logic makes captures more logical, and endgame logic helps the
; board keep looking like chess instead of random legal wandering.

ScoreExchangeLogic:
        ld      a,(TargetOccupant)
        cp      0ffh
        ret     z
        call    PtrPieceType
        ld      a,(hl)
        call    ValueForPieceType
        ld      (ExchangeVictimValue),a

        ld      a,(CandidatePiece)
        call    PtrPieceType
        ld      a,(hl)
        call    ValueForPieceType
        ld      (ExchangeAttackerValue),a

        call    TargetAttackedByEnemyDeep
        jp      nc,ExchangeSafeCapture
        call    TargetDefendedByOwnDeep
        jp      c,ExchangeContestedCapture

        ; Capturing into an undefended enemy attack is only okay when
        ; the captured piece is clearly worth more than the mover.
        ld      a,(ExchangeVictimValue)
        ld      b,a
        ld      a,(ExchangeAttackerValue)
        cp      b
        jp      c,ExchangeGoodRisk
        ld      a,36
        jp      ScoreSubA
ExchangeGoodRisk:
        ld      a,14
        jp      ScoreAddA

ExchangeContestedCapture:
        ld      a,(ExchangeAttackerValue)
        ld      b,a
        ld      a,(ExchangeVictimValue)
        cp      b
        jp      c,ExchangeBadTrade
        ld      a,20
        jp      ScoreAddA
ExchangeBadTrade:
        ld      a,10
        jp      ScoreSubA
ExchangeSafeCapture:
        ld      a,18
        jp      ScoreAddA

ScoreEndgameLogic:
        ; Late game: kings and pawns should become purposeful.
        ld      a,(GamePly)
        cp      80
        ret     c
        ld      a,(CandidatePiece)
        call    PtrPieceType
        ld      a,(hl)
        cp      TypeKing
        jp      z,EndgameKing
        cp      TypePawn
        jp      z,EndgamePawn
        ret
EndgameKing:
        ld      a,(TargetFile)
        cp      2
        jp      c,EndgameKingEdge
        cp      6
        jp      nc,EndgameKingEdge
        ld      a,(TargetRank)
        cp      2
        jp      c,EndgameKingEdge
        cp      6
        jp      nc,EndgameKingEdge
        ld      a,12
        jp      ScoreAddA
EndgameKingEdge:
        ld      a,6
        jp      ScoreSubA
EndgamePawn:
        ; Push pawns harder when the board is older.
        ld      a,(CurrentSide)
        or      a
        jp      z,EndgameWhitePawn
EndgameBlackPawn:
        ld      a,(TargetRank)
        add     a,a
        add     a,4
        jp      ScoreAddA
EndgameWhitePawn:
        ld      a,7
        ld      b,a
        ld      a,(TargetRank)
        ld      c,a
        ld      a,b
        sub     c
        add     a,a
        add     a,4
        jp      ScoreAddA

ScoreMegaBrainBonus:
        ld      a,(BankBrainEnabled)
        or      a
        jp      nz,ScoreRomWBWBankBrainBonus
        ld      a,(BrnLoaded)
        or      a
        jp      z,ScoreMegaBrainInternal
        ld      a,(BrnRecords)
        cp      36                      ; need planes through 1100h safely
        jp      c,ScoreMegaBrainInternal
        jp      ScoreExternalMegaBrainBonus

ScoreMegaBrainInternal:
        ; 24x256 byte built-in deep-brain book exists below.  We read a handful of
        ; planes every legal candidate.  The rest are reserve thinking mass
        ; for later revs and keep this source in the 150K class.
        call    MakeBrainIndex
        ld      hl,MegaBrain0
        call    AddBrainIndexToHLAndRead
        and     7
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,41
        ld      (BrainIndex),a
        ld      hl,MegaBrain5
        call    AddBrainIndexToHLAndRead
        and     7
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,73
        ld      (BrainIndex),a
        ld      hl,MegaBrain11
        call    AddBrainIndexToHLAndRead
        and     7
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,109
        ld      (BrainIndex),a
        ld      hl,MegaBrain17
        call    AddBrainIndexToHLAndRead
        and     3
        jp      ScoreAddA



ScoreRomWBWBankBrainBonus:
        ; REV26: official 96K RomWBW app-bank brain path.
        ; Tables were seeded at 7000h-70FF in banks 89/8A/8B.
        ; Each legal candidate reads three independent bank planes.
        call    MakeBrainIndex
        ld      a,(BankBrainBank0)
        call    ReadRomWBWBrainByteA
        and     7
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,41
        ld      (BrainIndex),a
        ld      a,(BankBrainBank1)
        call    ReadRomWBWBrainByteA
        and     7
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,73
        ld      (BrainIndex),a
        ld      a,(BankBrainBank2)
        call    ReadRomWBWBrainByteA
        and     7
        call    ScoreAddA

        ; Extra depth pass when the Z180 budget says the bank brain is available.
        ld      a,(BrainDepthBudget)
        cp      4
        jp      c,ScoreRomWBWMaybeExternalBonus
        ld      a,(BrainIndex)
        add     a,109
        ld      (BrainIndex),a
        ld      a,(BankBrainBank2)
        call    ReadRomWBWBrainByteA
        and     3
        call    ScoreAddA

ScoreRomWBWMaybeExternalBonus:
        ; REV29: when both verified app-bank RAM and a usable CHXR29.BRN are
        ; present, use both.  RWBANK remains primary; BRN adds extra book noise.
        ld      a,(BrnLoaded)
        or      a
        ret     z
        ld      a,(BrnRecords)
        cp      36
        ret     c
        jp      ScoreExternalMegaBrainBonus

ReadRomWBWBrainByteA:
        ; Input A = app Bank ID.  Output A = table byte or deterministic fallback.
        ld      (BankBrainTempBank),a
        ld      h,070h
        ld      a,(BrainIndex)
        ld      l,a
        ld      a,(BankBrainTempBank)
        ld      d,a
        call    RWBK_Peek
        ld      (BankBrainLastStatus),a
        or      a
        jp      nz,ReadRomWBWBrainFallback
        ld      a,e
        ld      (BankBrainLastByte),a
        ret
ReadRomWBWBrainFallback:
        ld      a,(BrainIndex)
        ld      b,a
        ld      a,(CandidatePiece)
        xor     b
        add     a,17
        ld      (BankBrainLastByte),a
        ret

ScoreExternalMegaBrainBonus:
        ; Same scoring idea as the built-in mega brain, but bytes are fetched
        ; from CHXR29.BRN loaded into free RAM.  This makes the brain upgradeable
        ; without growing the flat .COM beyond CP/M limits.
        call    MakeBrainIndex
        ld      hl,(BrnBase)
        call    AddBrainIndexToHLAndRead
        and     7
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,41
        ld      (BrainIndex),a
        ld      hl,(BrnBase)
        ld      de,0500h
        add     hl,de
        call    AddBrainIndexToHLAndRead
        and     7
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,73
        ld      (BrainIndex),a
        ld      hl,(BrnBase)
        ld      de,0b00h
        add     hl,de
        call    AddBrainIndexToHLAndRead
        and     7
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,109
        ld      (BrainIndex),a
        ld      hl,(BrnBase)
        ld      de,1100h
        add     hl,de
        call    AddBrainIndexToHLAndRead
        and     3
        jp      ScoreAddA


ScoreCheckPressureBonus:
        ; Bonus for moves that create real pressure on the enemy king after a
        ; temporary board simulation.  This is not fake table noise: it asks
        ; whether our side attacks the enemy king after the move is applied.
        ld      a,(TargetFile)
        ld      (SavedTargetFile),a
        ld      a,(TargetRank)
        ld      (SavedTargetRank),a
        ld      a,(TargetOccupant)
        ld      (SavedTargetOccupant),a
        call    ApplyCandidateSim
        call    SetTargetToEnemyKing
        ld      a,(CandidatePiece)
        ld      (AttackPiece),a
        call    TargetAttackedByAttackPiece
        jp      c,CheckPressureYes
        call    TargetDefendedByOwnDeep  ; also catches discovered checks
        jp      c,CheckPressureYes
CheckPressureNo:
        call    RestoreCandidateSim
        ld      a,(SavedTargetFile)
        ld      (TargetFile),a
        ld      a,(SavedTargetRank)
        ld      (TargetRank),a
        ld      a,(SavedTargetOccupant)
        ld      (TargetOccupant),a
        ret
CheckPressureYes:
        call    RestoreCandidateSim
        ld      a,(SavedTargetFile)
        ld      (TargetFile),a
        ld      a,(SavedTargetRank)
        ld      (TargetRank),a
        ld      a,(SavedTargetOccupant)
        ld      (TargetOccupant),a
        ld      a,22
        jp      ScoreAddA

SetTargetToEnemyKing:
        ld      a,(CurrentSide)
        or      a
        jp      z,SetEnemyBlackKingTarget
SetEnemyWhiteKingTarget:
        xor     a
        ld      (KingScanPiece),a
        ld      a,16
        ld      (KingScanEnd),a
        jp      SetEnemyKingTargetLoop
SetEnemyBlackKingTarget:
        ld      a,16
        ld      (KingScanPiece),a
        ld      a,32
        ld      (KingScanEnd),a
SetEnemyKingTargetLoop:
        ld      a,(KingScanPiece)
        ld      b,a
        ld      a,(KingScanEnd)
        cp      b
        ret     z
        ld      a,(KingScanPiece)
        call    PtrPieceAlive
        ld      a,(hl)
        or      a
        jp      z,SetEnemyKingTargetNext
        ld      a,(KingScanPiece)
        call    PtrPieceType
        ld      a,(hl)
        cp      TypeKing
        jp      nz,SetEnemyKingTargetNext
        ld      a,(KingScanPiece)
        call    PtrPieceFile
        ld      a,(hl)
        ld      (TargetFile),a
        ld      a,(KingScanPiece)
        call    PtrPieceRank
        ld      a,(hl)
        ld      (TargetRank),a
        ret
SetEnemyKingTargetNext:
        ld      hl,KingScanPiece
        inc     (hl)
        jp      SetEnemyKingTargetLoop


; ------------------------------------------------------------
; REV26 best-fit search layer.
;
; This is the real strength upgrade.  It does not pad the .COM.  For every
; legal candidate, the engine temporarily makes the move, then asks two
; practical 2-ply questions:
;   1. What is the most valuable friendly piece the opponent can attack next?
;   2. What is the most valuable enemy piece we attack after this move?
; The first answer is subtracted, the second is added.  Both are based on the
; live board, real attack maps, real piece values, and exact make/unmake.

ScoreOpponentReplyPenalty:
        ; Save target query, because the scan will use TargetFile/TargetRank.
        ld      a,(TargetFile)
        ld      (SavedTargetFile),a
        ld      a,(TargetRank)
        ld      (SavedTargetRank),a
        ld      a,(TargetOccupant)
        ld      (SavedTargetOccupant),a

        call    ApplyCandidateSim
        call    ScanOpponentBestThreat
        call    RestoreCandidateSim

        ld      a,(SavedTargetFile)
        ld      (TargetFile),a
        ld      a,(SavedTargetRank)
        ld      (TargetRank),a
        ld      a,(SavedTargetOccupant)
        ld      (TargetOccupant),a

        ld      a,(ReplyBestLoss)
        or      a
        ret     z
        call    ScoreSubA

        ; On real Z180/deeper RAM mode, punish very bad replies a little more.
        ld      a,(Z180BrainMode)
        or      a
        ret     z
        ld      a,(BrainDepthBudget)
        cp      3
        ret     c
        ld      a,(ReplyBestLoss)
        srl     a
        ret     z
        jp      ScoreSubA

ScanOpponentBestThreat:
        xor     a
        ld      (ReplyBestLoss),a
        ld      a,(CurrentSide)
        or      a
        jp      z,ReplyScanWhitePieces
ReplyScanBlackPieces:
        ld      a,16
        ld      (ReplyScanPiece),a
        ld      a,32
        ld      (ReplyScanEnd),a
        jp      ReplyScanLoop
ReplyScanWhitePieces:
        xor     a
        ld      (ReplyScanPiece),a
        ld      a,16
        ld      (ReplyScanEnd),a
ReplyScanLoop:
        ld      a,(ReplyScanPiece)
        ld      b,a
        ld      a,(ReplyScanEnd)
        cp      b
        ret     z
        ld      a,(ReplyScanPiece)
        call    PtrPieceAlive
        ld      a,(hl)
        or      a
        jp      z,ReplyScanNext

        ld      a,(ReplyScanPiece)
        call    PtrPieceFile
        ld      a,(hl)
        ld      (TargetFile),a
        ld      a,(ReplyScanPiece)
        call    PtrPieceRank
        ld      a,(hl)
        ld      (TargetRank),a

        call    TargetAttackedByEnemyDeep
        jp      nc,ReplyScanNext

        ld      a,(ReplyScanPiece)
        call    PtrPieceType
        ld      a,(hl)
        call    ValueForPieceType
        ld      (ReplyTempValue),a

        ; A defended piece is still a danger, but not as scary as a hanging one.
        call    TargetDefendedByOwnDeep
        ld      a,(ReplyTempValue)
        jp      nc,ReplyValueReady
        srl     a
ReplyValueReady:
        ld      b,a
        ld      a,(ReplyBestLoss)
        cp      b
        jp      nc,ReplyScanNext
        ld      a,b
        ld      (ReplyBestLoss),a
ReplyScanNext:
        ld      hl,ReplyScanPiece
        inc     (hl)
        jp      ReplyScanLoop

ScoreWinningThreatBonus:
        ; Save target query, because the scan will use TargetFile/TargetRank.
        ld      a,(TargetFile)
        ld      (SavedTargetFile),a
        ld      a,(TargetRank)
        ld      (SavedTargetRank),a
        ld      a,(TargetOccupant)
        ld      (SavedTargetOccupant),a

        call    ApplyCandidateSim
        call    ScanOurBestThreat
        call    RestoreCandidateSim

        ld      a,(SavedTargetFile)
        ld      (TargetFile),a
        ld      a,(SavedTargetRank)
        ld      (TargetRank),a
        ld      a,(SavedTargetOccupant)
        ld      (TargetOccupant),a

        ld      a,(ThreatBestGain)
        or      a
        ret     z
        ; Add about half the best future threat.  This pushes both sides to
        ; win material without letting a distant threat override immediate safety.
        srl     a
        call    ScoreAddA

        ld      a,(Z180BrainMode)
        or      a
        ret     z
        ld      a,(BrainDepthBudget)
        cp      2
        ret     c
        ld      a,(ThreatBestGain)
        srl     a
        srl     a
        ret     z
        jp      ScoreAddA

ScanOurBestThreat:
        xor     a
        ld      (ThreatBestGain),a
        ld      a,(CurrentSide)
        or      a
        jp      z,ThreatScanBlackPieces
ThreatScanWhitePieces:
        xor     a
        ld      (ThreatScanPiece),a
        ld      a,16
        ld      (ThreatScanEnd),a
        jp      ThreatScanLoop
ThreatScanBlackPieces:
        ld      a,16
        ld      (ThreatScanPiece),a
        ld      a,32
        ld      (ThreatScanEnd),a
ThreatScanLoop:
        ld      a,(ThreatScanPiece)
        ld      b,a
        ld      a,(ThreatScanEnd)
        cp      b
        ret     z
        ld      a,(ThreatScanPiece)
        call    PtrPieceAlive
        ld      a,(hl)
        or      a
        jp      z,ThreatScanNext

        ld      a,(ThreatScanPiece)
        call    PtrPieceFile
        ld      a,(hl)
        ld      (TargetFile),a
        ld      a,(ThreatScanPiece)
        call    PtrPieceRank
        ld      a,(hl)
        ld      (TargetRank),a

        call    TargetAttackedByOwnAll
        jp      nc,ThreatScanNext

        ld      a,(ThreatScanPiece)
        call    PtrPieceType
        ld      a,(hl)
        call    ValueForPieceType
        ld      (ThreatTempValue),a

        ; If the enemy piece is defended, it is a trade, not a free win.
        call    TargetAttackedByEnemyDeep
        ld      a,(ThreatTempValue)
        jp      nc,ThreatValueReady
        srl     a
ThreatValueReady:
        ld      b,a
        ld      a,(ThreatBestGain)
        cp      b
        jp      nc,ThreatScanNext
        ld      a,b
        ld      (ThreatBestGain),a
ThreatScanNext:
        ld      hl,ThreatScanPiece
        inc     (hl)
        jp      ThreatScanLoop

TargetAttackedByOwnAll:
        ; Same as TargetDefendedByOwnDeep, but it includes CandidatePiece.
        ; That lets the scan see attacks created directly by the move itself.
        ld      a,(CurrentSide)
        or      a
        jp      z,OwnAllWhite
OwnAllBlack:
        ld      a,16
        ld      (AttackPiece),a
        ld      a,32
        ld      (AttackEndPiece),a
        jp      OwnAllLoop
OwnAllWhite:
        xor     a
        ld      (AttackPiece),a
        ld      a,16
        ld      (AttackEndPiece),a
OwnAllLoop:
        ld      a,(AttackPiece)
        ld      b,a
        ld      a,(AttackEndPiece)
        cp      b
        jp      z,OwnAllNoAttack
        ld      a,(AttackPiece)
        call    PtrPieceAlive
        ld      a,(hl)
        or      a
        jp      z,OwnAllNext
        call    TargetAttackedByAttackPiece
        ret     c
OwnAllNext:
        ld      hl,AttackPiece
        inc     (hl)
        jp      OwnAllLoop
OwnAllNoAttack:
        or      a
        ret

ScoreRamPlanBonus:
        ; When enough free RAM exists, favor moves that survive in a larger
        ; plan pool.  More legal alternatives means better positional scanning.
        ld      a,(RamEnabled)
        or      a
        ret     z
        ld      a,(FreeRamPages)
        cp      4
        jp      c,RamPlanSmall
        ld      a,(PlanMoveCount)
        and     7
        add     a,3
        jp      ScoreAddA
RamPlanSmall:
        ld      a,1
        jp      ScoreAddA


ScoreZ180BankStatusBonus:
        ; REV26: bank-status tie breaker now uses the verified RomWBW
        ; app-bank brain state, not raw Z180 MMU registers.
        ld      a,(BankBrainEnabled)
        or      a
        ret     z
        ld      a,(BankBrainBank0)
        ld      b,a
        ld      a,(BankBrainBank1)
        xor     b
        ld      b,a
        ld      a,(BankBrainLastByte)
        xor     b
        and     3
        jp      ScoreAddA

ScoreZ180RamDepthBonus:
        ; REV21: if the machine is really a Z180 and free-RAM planner exists,
        ; reward moves that fit a wider planning pool.  This is real state:
        ; Z180BrainMode comes from z180.asm, FreeRamPages comes from CP/M BDOS.
        ld      a,(Z180BrainMode)
        or      a
        ret     z
        ld      a,(FreeRamPages)
        or      a
        ret     z
        cp      12
        jp      nc,Z180DepthLarge
        cp      6
        jp      nc,Z180DepthMedium
        ld      a,3
        jp      ScoreAddA
Z180DepthMedium:
        ld      a,8
        jp      ScoreAddA
Z180DepthLarge:
        ld      a,14
        jp      ScoreAddA

ScoreRuleLockBonus:
        ; REV21: scored moves already passed the strict king-safety gate.
        ; This bonus prefers legal moves that are both defended and not under
        ; immediate enemy attack, keeping play logical rather than random.
        call    TargetAttackedByEnemyDeep
        jp      c,RuleLockUnderFire
        ld      a,12
        call    ScoreAddA
        call    TargetDefendedByOwnDeep
        ret     nc
        ld      a,10
        jp      ScoreAddA
RuleLockUnderFire:
        call    TargetDefendedByOwnDeep
        jp      c,RuleLockContested
        ld      a,18
        jp      ScoreSubA
RuleLockContested:
        ld      a,4
        jp      ScoreSubA

ScoreZ180WideNeuroBonus:
        ; REV21: a wider table-driven layer.  It is not just filler: every
        ; legal candidate samples several 256-byte neural planes using real
        ; CandidatePiece/Target/GamePly/RandomSeed-derived BrainIndex.
        ld      a,(Z180BrainMode)
        or      a
        jp      z,ScoreWideNeuroLight
        call    MakeBrainIndex
        ld      hl,Z180Neuro00
        call    AddBrainIndexToHLAndRead
        and     15
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,17
        ld      (BrainIndex),a
        ld      hl,Z180Neuro07
        call    AddBrainIndexToHLAndRead
        and     15
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,29
        ld      (BrainIndex),a
        ld      hl,Z180Neuro19
        call    AddBrainIndexToHLAndRead
        and     15
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,43
        ld      (BrainIndex),a
        ld      hl,Z180Neuro31
        call    AddBrainIndexToHLAndRead
        and     7
        call    ScoreAddA

        ld      a,(BrainDepthBudget)
        cp      2
        ret     c
        ld      a,(BrainIndex)
        add     a,61
        ld      (BrainIndex),a
        ld      hl,Z180Neuro47
        call    AddBrainIndexToHLAndRead
        and     7
        call    ScoreAddA

        ld      a,(BrainDepthBudget)
        cp      3
        ret     c
        ld      a,(BrainIndex)
        add     a,89
        ld      (BrainIndex),a
        ld      hl,Z180Neuro63
        call    AddBrainIndexToHLAndRead
        and     7
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,113
        ld      (BrainIndex),a
        ld      hl,Z180Neuro79
        call    AddBrainIndexToHLAndRead
        and     3
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,151
        ld      (BrainIndex),a
        ld      hl,Z180Neuro95
        call    AddBrainIndexToHLAndRead
        and     3
        jp      ScoreAddA
ScoreWideNeuroLight:
        ; Non-Z180 fallback still gets a small deterministic positional taste.
        call    MakeBrainIndex
        ld      hl,Z180Neuro00
        call    AddBrainIndexToHLAndRead
        and     3
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

ScoreDeepBookBonus:
        ; Extra REV8 100KB-class tactical book.
        ; It is deliberately table-driven and keyed by target/candidate/ply/random seed.
        call    MakeBrainIndex
        ld      hl,DeepTacticBook0
        call    AddBrainIndexToHLAndRead
        and     15
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,37
        ld      (BrainIndex),a
        ld      hl,DeepTacticBook1
        call    AddBrainIndexToHLAndRead
        and     7
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,83
        ld      (BrainIndex),a
        ld      hl,DeepTacticBook2
        call    AddBrainIndexToHLAndRead
        and     7
        call    ScoreAddA

        ld      a,(BrainIndex)
        add     a,149
        ld      (BrainIndex),a
        ld      hl,DeepTacticBook3
        call    AddBrainIndexToHLAndRead
        and     3
        jp      ScoreAddA

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
; REV17 animation setup remains tile-stable.
;
; AnimMode 0 = legal line move: rook/bishop/queen/king/pawn square steps.
; AnimMode 1 = non-line jump, mainly knights.  Do not drag those diagonally.

SetupMoveAnimation:
        xor     a
        ld      (AnimMode),a
        ld      a,2
        ld      (AnimDelay),a

        ; AnimDXAbs = abs(BestFile - LastFromFile)
        ld      a,(BestFile)
        ld      b,a
        ld      a,(LastFromFile)
        ld      c,a
        ld      a,b
        sub     c
        call    AbsA
        ld      (AnimDXAbs),a

        ; AnimDYAbs = abs(BestRank - LastFromRank)
        ld      a,(BestRank)
        ld      b,a
        ld      a,(LastFromRank)
        ld      c,a
        ld      a,b
        sub     c
        call    AbsA
        ld      (AnimDYAbs),a

        ; Straight moves are safe.
        ld      a,(AnimDXAbs)
        or      a
        ret     z
        ld      a,(AnimDYAbs)
        or      a
        ret     z

        ; True diagonals are safe if both axes are same square count.
        ld      a,(AnimDXAbs)
        ld      b,a
        ld      a,(AnimDYAbs)
        cp      b
        ret     z

        ; Otherwise this is a jump shape.  Use direct jump animation.
        ld      a,1
        ld      (AnimMode),a
        ret

; ------------------------------------------------------------
; Animation and post-move turn handling.

AnimateActiveMove:
        ; REV17: hardware sprite animation is still bypassed for stability.
        ; The old diagonal pixel slide crossed between squares, so on a busy
        ; board the moving sprite overlapped nearby tile pieces and looked
        ; flashy/terrible.  This version moves only between legal square
        ; centers.  True diagonal pieces step one square diagonally at a time.
        ; Knights jump directly, because that is what a knight really does.
        ld      a,(AnimDelay)
        or      a
        jp      z,AnimDoStep
        dec     a
        ld      (AnimDelay),a
        ret

AnimDoStep:
        ld      a,2
        ld      (AnimDelay),a

        ld      a,(AnimMode)
        or      a
        jp      nz,AnimKnightJump

        call    AnimStepX16
        call    AnimStepY16
        jp      AnimCheckArrived

AnimKnightJump:
        ; Non-line moves, normally knights, should not crawl diagonally.
        ld      a,(ActivePiece)
        call    PtrPieceX
        ld      a,(TargetX)
        ld      (hl),a
        ld      a,(ActivePiece)
        call    PtrPieceY
        ld      a,(TargetY)
        ld      (hl),a
        jp      AnimCheckArrived

AnimStepX16:
        ld      a,(ActivePiece)
        call    PtrPieceX
        ld      a,(hl)
        ld      b,a
        ld      a,(TargetX)
        cp      b
        ret     z
        jp      nc,AnimStepXRight
AnimStepXLeft:
        ld      a,b
        sub     16
        ld      (hl),a
        ret
AnimStepXRight:
        ld      a,b
        add     a,16
        ld      (hl),a
        ret

AnimStepY16:
        ld      a,(ActivePiece)
        call    PtrPieceY
        ld      a,(hl)
        ld      b,a
        ld      a,(TargetY)
        cp      b
        ret     z
        jp      nc,AnimStepYDown
AnimStepYUp:
        ld      a,b
        sub     16
        ld      (hl),a
        ret
AnimStepYDown:
        ld      a,b
        add     a,16
        ld      (hl),a
        ret

AnimCheckArrived:
        ld      a,(ActivePiece)
        call    PtrPieceX
        ld      a,(hl)
        ld      b,a
        ld      a,(TargetX)
        cp      b
        ret     nz
        ld      a,(ActivePiece)
        call    PtrPieceY
        ld      a,(hl)
        ld      b,a
        ld      a,(TargetY)
        cp      b
        ret     nz
        jp      MoveArrived

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
        call    DrawBestPieceTile

        ; REV2: one final sprite rewrite after arrival hides the
        ; moving hardware sprite, then the main loop goes quiet.
        ld      a,1
        ld      (SpriteDirty),a

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
        ; REV29: increment one HEX nibble.  Low F carries to high nibble.
        ; High F carries out and is intentionally ignored, giving FF -> 00.
        inc     (hl)
        ld      a,(hl)
        cp      16
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
; REV9 anti-blink sprite writer gate.
;
; REV8 rewrote the full TMS sprite attribute table every frame, even
; while nothing moved.  On real hardware/TMSEMU3 that can look like
; shimmer/blink, especially during thinking pauses.  This routine writes
; sprites only while a piece is moving or when a final settled-state
; rewrite is requested by SpriteDirty.

WriteSpritesSmart:
        ld      a,(ActiveFlag)
        or      a
        jp      nz,WriteSprites
        ld      a,(SpriteDirty)
        or      a
        ret     z
        xor     a
        ld      (SpriteDirty),a
        jp      WriteSprites

; ------------------------------------------------------------
; Sprite writer.

WriteSprites:
        ; REV2 hard anti-flicker mode:
        ; Stationary pieces are now board tiles.  Only the one active moving
        ; piece is a hardware sprite, so we never exceed the TMS9918A
        ; 4-sprites-per-scanline limit.
        ld      de,(TmsSpriteAttrAddr)
        call    TmsWriteAddr
        ld      a,(ActiveFlag)
        or      a
        jp      z,WriteSpritesEndOnly
        ld      a,(ActivePiece)
        call    WriteOneSpriteIndex
WriteSpritesEndOnly:
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

; REV2 tile-rendered stationary pieces.
; Each 16x16 piece uses four 8x8 board tiles.
TilePieceWhiteLight: equ 80
TilePieceWhiteDark:  equ 104
TilePieceBlackLight: equ 128
TilePieceBlackDark:  equ 152

HiddenSpriteY:  equ 209       ; off-screen hide, not end marker

BoardPixX:      equ 64
BoardPixY:      equ 32

PatPawn:        equ 0
PatRook:        equ 4
PatKnight:      equ 8
PatBishop:      equ 12
PatQueen:       equ 16
PatKing:        equ 20

; REV9 engine piece-type constants.
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
SpriteDirty:    defb 0       ; request one final active-sprite rewrite
AnimMode:       defb 0       ; REV11: 0 line step, 1 knight/jump
AnimDelay:      defb 0       ; REV11: frames between square-center hops
AnimDXAbs:      defb 0
AnimDYAbs:      defb 0
DrawFile:       defb 0
DrawRank:       defb 0
DrawPieceIndex: defb 0
DrawTileBase:   defb 0
WhiteScore10:   defb 0       ; REV29 high hex nibble, 00-FF rollover
WhiteScore1:    defb 0       ; REV29 low hex nibble
BlackScore10:   defb 0       ; REV29 high hex nibble, 00-FF rollover
BlackScore1:    defb 0       ; REV29 low hex nibble

; REV9 engine state.
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
GameLedPage:    defb 0
Z180BrainMode:  defb 0
BrainDepthBudget: defb 0
BrainRamBudget: defb 0
BrainModeUsed:  defb 0
ExchangeVictimValue:   defb 0
ExchangeAttackerValue: defb 0

; REV20 free-RAM planner and strict legality state.
RamEnabled:     defb 0
FreeRamPages:   defb 0
PlanMoveCount:  defb 0
RamBase:        defw 0
RamEnd:         defw 0
RamCursor:      defw 0
BrnLoaded:      defb 0
BrnFilePresent: defb 0       ; REV29: BRN was found/opened even if not loaded to low RAM
BrnOpenStatus:  defb 0ffh    ; REV29: raw BDOS open result
BrnRecords:     defb 0
BrnBase:        defw 0
BrnEnd:         defw 0
BrnCursor:      defw 0
SavedTargetFile:      defb 0
SavedTargetRank:      defb 0
SavedTargetOccupant:  defb 0ffh
KingUnsafeFlag:       defb 0
KingScanPiece:        defb 0
KingScanEnd:          defb 0
AttackSimFlag:        defb 0

; REV26 RomWBW app-bank brain state.
BankBrainEnabled:    defb 0
BankBrainInitStatus: defb 0
BankBrainInfoStatus: defb 0
BankBrainStart:      defb 0
BankBrainCount:      defb 0
BankBrainSizePg:     defb 0
BankBrainBank0:      defb 0
BankBrainBank1:      defb 0
BankBrainBank2:      defb 0
BankBrainStatusOR:   defb 0
BankBrainLastStatus: defb 0
BankBrainLastByte:   defb 0
BankBrainTempBank:   defb 0
BankBrainSeedIndex:  defb 0
BankBrainPlanIndex:  defb 0

; CP/M FCB for CHXR29.BRN.  Drive 0 means current drive.
BrnFcb:
        defb 0,"CHXR29  ","BRN"
        defs 24,0

; REV26 reply-threat / win-threat search state.
ReplyBestLoss:        defb 0
ReplyTempValue:       defb 0
ReplyScanPiece:       defb 0
ReplyScanEnd:         defb 0
ThreatBestGain:       defb 0
ThreatTempValue:      defb 0
ThreatScanPiece:      defb 0
ThreatScanEnd:        defb 0

; REV9 attack-map scratch state.
AttackPiece:    defb 0
AttackEndPiece: defb 0
AttackFile:     defb 0
AttackRank:     defb 0
AttackDX:       defb 0
AttackDY:       defb 0
AttackAbsDX:    defb 0
AttackAbsDY:    defb 0
AttackStepFile: defb 0
AttackStepRank: defb 0
AttackPathFile: defb 0
AttackPathRank: defb 0

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
; REV8 position tables and tactical hash planes.
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


; REV8 100KB-class deep tactical book tables.
; These are used by ScoreDeepBookBonus and give the engine more weighted
; choices after the deterministic logic has removed bad moves.
DeepTacticBook0:
        defb 2,12,23,11,16,14,13,21,14,0,19,15,28,2,9,25
        defb 26,20,15,19,8,22,5,29,6,8,11,23,20,10,1,1
        defb 18,28,7,27,0,30,29,5,30,16,3,31,12,18,25,9
        defb 10,4,31,3,24,6,21,13,22,24,27,7,4,26,17,17
        defb 2,12,23,11,16,14,13,21,14,0,19,15,28,2,9,25
        defb 26,20,15,19,8,22,5,29,6,8,11,23,20,10,1,1
        defb 18,28,7,27,0,30,29,5,30,16,3,31,12,18,25,9
        defb 10,4,31,3,24,6,21,13,22,24,27,7,4,26,17,17
        defb 2,12,23,11,16,14,13,21,14,0,19,15,28,2,9,25
        defb 26,20,15,19,8,22,5,29,6,8,11,23,20,10,1,1
        defb 18,28,7,27,0,30,29,5,30,16,3,31,12,18,25,9
        defb 10,4,31,3,24,6,21,13,22,24,27,7,4,26,17,17
        defb 2,12,23,11,16,14,13,21,14,0,19,15,28,2,9,25
        defb 26,20,15,19,8,22,5,29,6,8,11,23,20,10,1,1
        defb 18,28,7,27,0,30,29,5,30,16,3,31,12,18,25,9
        defb 10,4,31,3,24,6,21,13,22,24,27,7,4,26,17,17

DeepTacticBook1:
        defb 28,22,17,21,10,24,7,31,8,10,13,25,22,12,3,3
        defb 20,30,9,29,2,0,31,7,0,18,5,1,14,20,27,11
        defb 12,6,1,5,26,8,23,15,24,26,29,9,6,28,19,19
        defb 4,14,25,13,18,16,15,23,16,2,21,17,30,4,11,27
        defb 28,22,17,21,10,24,7,31,8,10,13,25,22,12,3,3
        defb 20,30,9,29,2,0,31,7,0,18,5,1,14,20,27,11
        defb 12,6,1,5,26,8,23,15,24,26,29,9,6,28,19,19
        defb 4,14,25,13,18,16,15,23,16,2,21,17,30,4,11,27
        defb 28,22,17,21,10,24,7,31,8,10,13,25,22,12,3,3
        defb 20,30,9,29,2,0,31,7,0,18,5,1,14,20,27,11
        defb 12,6,1,5,26,8,23,15,24,26,29,9,6,28,19,19
        defb 4,14,25,13,18,16,15,23,16,2,21,17,30,4,11,27
        defb 28,22,17,21,10,24,7,31,8,10,13,25,22,12,3,3
        defb 20,30,9,29,2,0,31,7,0,18,5,1,14,20,27,11
        defb 12,6,1,5,26,8,23,15,24,26,29,9,6,28,19,19
        defb 4,14,25,13,18,16,15,23,16,2,21,17,30,4,11,27

DeepTacticBook2:
        defb 16,10,5,9,30,12,27,19,28,30,1,13,10,0,23,23
        defb 8,18,29,17,22,20,19,27,20,6,25,21,2,8,15,31
        defb 0,26,21,25,14,28,11,3,12,14,17,29,26,16,7,7
        defb 24,2,13,1,6,4,3,11,4,22,9,5,18,24,31,15
        defb 16,10,5,9,30,12,27,19,28,30,1,13,10,0,23,23
        defb 8,18,29,17,22,20,19,27,20,6,25,21,2,8,15,31
        defb 0,26,21,25,14,28,11,3,12,14,17,29,26,16,7,7
        defb 24,2,13,1,6,4,3,11,4,22,9,5,18,24,31,15
        defb 16,10,5,9,30,12,27,19,28,30,1,13,10,0,23,23
        defb 8,18,29,17,22,20,19,27,20,6,25,21,2,8,15,31
        defb 0,26,21,25,14,28,11,3,12,14,17,29,26,16,7,7
        defb 24,2,13,1,6,4,3,11,4,22,9,5,18,24,31,15
        defb 16,10,5,9,30,12,27,19,28,30,1,13,10,0,23,23
        defb 8,18,29,17,22,20,19,27,20,6,25,21,2,8,15,31
        defb 0,26,21,25,14,28,11,3,12,14,17,29,26,16,7,7
        defb 24,2,13,1,6,4,3,11,4,22,9,5,18,24,31,15

DeepTacticBook3:
        defb 20,14,9,13,2,16,31,23,0,2,5,17,14,4,27,27
        defb 12,22,1,21,26,24,23,31,24,10,29,25,6,12,19,3
        defb 4,30,25,29,18,0,15,7,16,18,21,1,30,20,11,11
        defb 28,6,17,5,10,8,7,15,8,26,13,9,22,28,3,19
        defb 20,14,9,13,2,16,31,23,0,2,5,17,14,4,27,27
        defb 12,22,1,21,26,24,23,31,24,10,29,25,6,12,19,3
        defb 4,30,25,29,18,0,15,7,16,18,21,1,30,20,11,11
        defb 28,6,17,5,10,8,7,15,8,26,13,9,22,28,3,19
        defb 20,14,9,13,2,16,31,23,0,2,5,17,14,4,27,27
        defb 12,22,1,21,26,24,23,31,24,10,29,25,6,12,19,3
        defb 4,30,25,29,18,0,15,7,16,18,21,1,30,20,11,11
        defb 28,6,17,5,10,8,7,15,8,26,13,9,22,28,3,19
        defb 20,14,9,13,2,16,31,23,0,2,5,17,14,4,27,27
        defb 12,22,1,21,26,24,23,31,24,10,29,25,6,12,19,3
        defb 4,30,25,29,18,0,15,7,16,18,21,1,30,20,11,11
        defb 28,6,17,5,10,8,7,15,8,26,13,9,22,28,3,19

; ------------------------------------------------------------
; REV21 Z180 wide neural planes.
; 96 x 256 bytes = 24KB of additional COM-resident chess brain.
; The scorer samples selected planes every legal candidate.  The
; rest are reserved as stable neural mass for later deeper search.
Z180Neuro00:
        defb 000h,00Ch,018h,024h,026h,008h,00Ah,011h,01Dh,00Ah,017h,024h,027h,00Ah,00Dh,010h
        defb 01Ah,028h,016h,024h,028h,02Ch,010h,014h,017h,026h,035h,024h,029h,02Eh,013h,018h
        defb 00Ah,01Ah,02Ah,01Ah,020h,026h,00Ch,012h,01Dh,00Eh,01Fh,030h,017h,01Eh,005h,00Ch
        defb 010h,022h,014h,026h,00Eh,016h,01Eh,00Bh,008h,016h,009h,01Ch,005h,00Eh,01Ch,00Ah
        defb 00Bh,017h,023h,00Fh,011h,013h,015h,01Ch,008h,015h,022h,02Fh,012h,015h,018h,01Bh
        defb 025h,013h,021h,02Fh,033h,017h,01Bh,01Fh,022h,031h,020h,02Fh,034h,019h,01Eh,023h
        defb 015h,025h,015h,025h,02Bh,011h,017h,01Dh,008h,019h,02Ah,01Bh,022h,029h,010h,017h
        defb 01Bh,00Dh,01Fh,011h,019h,021h,009h,016h,013h,001h,014h,027h,010h,019h,007h,015h
        defb 016h,022h,00Eh,01Ah,01Ch,01Eh,000h,007h,013h,020h,02Dh,01Ah,01Dh,020h,023h,006h
        defb 010h,01Eh,02Ch,01Ah,01Eh,022h,026h,00Ah,02Dh,01Ch,02Bh,03Ah,01Fh,024h,029h,00Eh
        defb 020h,010h,020h,030h,016h,01Ch,022h,008h,013h,024h,015h,026h,02Dh,014h,01Bh,002h
        defb 006h,018h,00Ah,01Ch,024h,00Ch,014h,001h,01Eh,00Ch,01Fh,012h,01Bh,004h,012h,000h
        defb 001h,00Dh,019h,025h,027h,009h,00Bh,012h,01Eh,00Bh,018h,025h,028h,00Bh,00Eh,011h
        defb 01Bh,029h,017h,025h,029h,02Dh,011h,015h,018h,027h,036h,025h,02Ah,02Fh,014h,019h
        defb 00Bh,01Bh,02Bh,01Bh,021h,027h,00Dh,013h,01Eh,00Fh,020h,031h,018h,01Fh,006h,00Dh
        defb 011h,023h,015h,027h,00Fh,017h,01Fh,00Ch,009h,017h,00Ah,01Dh,006h,00Fh,01Dh,00Bh

Z180Neuro01:
        defb 00Eh,01Ah,026h,012h,014h,016h,018h,01Fh,00Bh,018h,025h,032h,015h,018h,01Bh,01Eh
        defb 028h,016h,024h,032h,016h,01Ah,01Eh,022h,025h,014h,023h,032h,037h,01Ch,021h,026h
        defb 018h,028h,018h,028h,02Eh,014h,01Ah,020h,00Bh,01Ch,02Dh,01Eh,025h,00Ch,013h,01Ah
        defb 01Eh,010h,022h,014h,01Ch,024h,00Ch,019h,016h,004h,017h,00Ah,013h,01Ch,00Ah,018h
        defb 019h,005h,011h,01Dh,01Fh,021h,003h,00Ah,016h,023h,010h,01Dh,020h,023h,006h,009h
        defb 013h,021h,02Fh,01Dh,021h,025h,029h,00Dh,010h,01Fh,02Eh,03Dh,022h,027h,02Ch,011h
        defb 023h,013h,023h,033h,019h,01Fh,025h,00Bh,016h,027h,018h,029h,010h,017h,01Eh,005h
        defb 009h,01Bh,00Dh,01Fh,027h,00Fh,017h,004h,001h,00Fh,022h,015h,01Eh,007h,015h,003h
        defb 004h,010h,01Ch,028h,00Ah,00Ch,00Eh,015h,021h,00Eh,01Bh,028h,02Bh,00Eh,011h,014h
        defb 01Eh,02Ch,01Ah,028h,02Ch,010h,014h,018h,01Bh,02Ah,019h,028h,02Dh,032h,017h,01Ch
        defb 00Eh,01Eh,02Eh,01Eh,024h,02Ah,010h,016h,021h,012h,023h,014h,01Bh,022h,009h,010h
        defb 014h,006h,018h,02Ah,012h,01Ah,002h,00Fh,00Ch,01Ah,00Dh,020h,009h,012h,000h,00Eh
        defb 00Fh,01Bh,027h,013h,015h,017h,019h,000h,00Ch,019h,026h,033h,016h,019h,01Ch,01Fh
        defb 029h,017h,025h,033h,017h,01Bh,01Fh,023h,026h,015h,024h,033h,038h,01Dh,022h,027h
        defb 019h,029h,019h,029h,02Fh,015h,01Bh,021h,00Ch,01Dh,02Eh,01Fh,026h,00Dh,014h,01Bh
        defb 01Fh,011h,023h,015h,01Dh,005h,00Dh,01Ah,017h,005h,018h,00Bh,014h,01Dh,00Bh,019h

Z180Neuro02:
        defb 01Ch,008h,014h,020h,022h,024h,006h,00Dh,019h,026h,013h,020h,023h,026h,009h,00Ch
        defb 016h,024h,032h,020h,024h,028h,00Ch,010h,013h,022h,031h,020h,025h,02Ah,00Fh,014h
        defb 026h,016h,026h,036h,01Ch,022h,028h,00Eh,019h,00Ah,01Bh,02Ch,013h,01Ah,021h,008h
        defb 00Ch,01Eh,010h,022h,00Ah,012h,01Ah,007h,004h,012h,005h,018h,021h,00Ah,018h,006h
        defb 007h,013h,01Fh,02Bh,00Dh,00Fh,011h,018h,024h,011h,01Eh,02Bh,02Eh,011h,014h,017h
        defb 021h,00Fh,01Dh,02Bh,02Fh,013h,017h,01Bh,01Eh,02Dh,01Ch,02Bh,030h,015h,01Ah,01Fh
        defb 011h,021h,031h,021h,027h,02Dh,013h,019h,024h,015h,026h,017h,01Eh,025h,00Ch,013h
        defb 017h,009h,01Bh,02Dh,015h,01Dh,005h,012h,00Fh,01Dh,010h,023h,00Ch,015h,003h,011h
        defb 012h,01Eh,00Ah,016h,018h,01Ah,01Ch,003h,00Fh,01Ch,029h,016h,019h,01Ch,01Fh,002h
        defb 00Ch,01Ah,028h,036h,01Ah,01Eh,022h,006h,029h,018h,027h,036h,01Bh,020h,025h,00Ah
        defb 01Ch,02Ch,01Ch,02Ch,032h,018h,01Eh,024h,00Fh,020h,011h,022h,029h,010h,017h,01Eh
        defb 002h,014h,026h,018h,020h,008h,010h,01Dh,01Ah,008h,01Bh,00Eh,017h,000h,00Eh,01Ch
        defb 01Dh,009h,015h,021h,023h,005h,007h,00Eh,01Ah,027h,014h,021h,024h,027h,00Ah,00Dh
        defb 017h,025h,033h,021h,025h,029h,00Dh,011h,014h,023h,032h,021h,026h,02Bh,010h,015h
        defb 027h,017h,027h,037h,01Dh,023h,029h,00Fh,01Ah,00Bh,01Ch,02Dh,014h,01Bh,022h,009h
        defb 00Dh,01Fh,011h,023h,00Bh,013h,01Bh,008h,005h,013h,006h,019h,022h,00Bh,019h,007h

Z180Neuro03:
        defb 00Ah,016h,022h,02Eh,010h,012h,014h,01Bh,007h,014h,021h,02Eh,011h,014h,017h,01Ah
        defb 024h,012h,020h,02Eh,032h,016h,01Ah,01Eh,021h,030h,01Fh,02Eh,033h,018h,01Dh,022h
        defb 014h,024h,014h,024h,02Ah,010h,016h,01Ch,007h,018h,029h,01Ah,021h,028h,00Fh,016h
        defb 01Ah,00Ch,01Eh,010h,018h,020h,008h,015h,012h,000h,013h,026h,00Fh,018h,006h,014h
        defb 015h,021h,00Dh,019h,01Bh,01Dh,01Fh,006h,012h,01Fh,02Ch,019h,01Ch,01Fh,022h,005h
        defb 00Fh,01Dh,02Bh,019h,01Dh,021h,025h,009h,02Ch,01Bh,02Ah,039h,01Eh,023h,028h,00Dh
        defb 01Fh,00Fh,01Fh,02Fh,015h,01Bh,021h,007h,012h,023h,014h,025h,02Ch,013h,01Ah,001h
        defb 005h,017h,029h,01Bh,023h,00Bh,013h,000h,01Dh,00Bh,01Eh,011h,01Ah,003h,011h,01Fh
        defb 000h,00Ch,018h,024h,026h,008h,00Ah,011h,01Dh,00Ah,017h,024h,027h,00Ah,00Dh,010h
        defb 01Ah,028h,016h,024h,028h,02Ch,010h,014h,017h,026h,035h,024h,029h,02Eh,013h,018h
        defb 00Ah,01Ah,02Ah,01Ah,020h,026h,00Ch,012h,01Dh,00Eh,01Fh,030h,017h,01Eh,005h,00Ch
        defb 010h,022h,014h,026h,00Eh,016h,01Eh,00Bh,008h,016h,009h,01Ch,005h,00Eh,01Ch,00Ah
        defb 00Bh,017h,023h,00Fh,011h,013h,015h,01Ch,008h,015h,022h,02Fh,012h,015h,018h,01Bh
        defb 025h,013h,021h,02Fh,033h,017h,01Bh,01Fh,022h,031h,020h,02Fh,034h,019h,01Eh,023h
        defb 015h,025h,015h,025h,02Bh,011h,017h,01Dh,008h,019h,02Ah,01Bh,022h,029h,010h,017h
        defb 01Bh,00Dh,01Fh,011h,019h,021h,009h,016h,013h,001h,014h,027h,010h,019h,007h,015h

Z180Neuro04:
        defb 018h,024h,010h,01Ch,01Eh,020h,002h,009h,015h,022h,00Fh,01Ch,01Fh,022h,005h,008h
        defb 012h,020h,02Eh,01Ch,020h,024h,028h,00Ch,00Fh,01Eh,02Dh,03Ch,021h,026h,02Bh,010h
        defb 022h,012h,022h,032h,018h,01Eh,024h,00Ah,015h,026h,017h,028h,00Fh,016h,01Dh,004h
        defb 008h,01Ah,00Ch,01Eh,026h,00Eh,016h,003h,000h,00Eh,021h,014h,01Dh,006h,014h,002h
        defb 003h,00Fh,01Bh,027h,029h,00Bh,00Dh,014h,020h,00Dh,01Ah,027h,02Ah,00Dh,010h,013h
        defb 01Dh,02Bh,019h,027h,02Bh,00Fh,013h,017h,01Ah,029h,038h,027h,02Ch,031h,016h,01Bh
        defb 00Dh,01Dh,02Dh,01Dh,023h,029h,00Fh,015h,020h,011h,022h,033h,01Ah,021h,008h,00Fh
        defb 013h,005h,017h,029h,011h,019h,001h,00Eh,00Bh,019h,00Ch,01Fh,008h,011h,01Fh,00Dh
        defb 00Eh,01Ah,026h,012h,014h,016h,018h,01Fh,00Bh,018h,025h,032h,015h,018h,01Bh,01Eh
        defb 028h,016h,024h,032h,016h,01Ah,01Eh,022h,025h,014h,023h,032h,037h,01Ch,021h,026h
        defb 018h,028h,018h,028h,02Eh,014h,01Ah,020h,00Bh,01Ch,02Dh,01Eh,025h,00Ch,013h,01Ah
        defb 01Eh,010h,022h,014h,01Ch,024h,00Ch,019h,016h,004h,017h,00Ah,013h,01Ch,00Ah,018h
        defb 019h,005h,011h,01Dh,01Fh,021h,003h,00Ah,016h,023h,010h,01Dh,020h,023h,006h,009h
        defb 013h,021h,02Fh,01Dh,021h,025h,029h,00Dh,010h,01Fh,02Eh,03Dh,022h,027h,02Ch,011h
        defb 023h,013h,023h,033h,019h,01Fh,025h,00Bh,016h,027h,018h,029h,010h,017h,01Eh,005h
        defb 009h,01Bh,00Dh,01Fh,027h,00Fh,017h,004h,001h,00Fh,022h,015h,01Eh,007h,015h,003h

Z180Neuro05:
        defb 006h,012h,01Eh,02Ah,00Ch,00Eh,010h,017h,023h,010h,01Dh,02Ah,02Dh,010h,013h,016h
        defb 020h,02Eh,01Ch,02Ah,02Eh,012h,016h,01Ah,01Dh,02Ch,01Bh,02Ah,02Fh,014h,019h,01Eh
        defb 010h,020h,030h,020h,026h,02Ch,012h,018h,023h,014h,025h,016h,01Dh,024h,00Bh,012h
        defb 016h,008h,01Ah,02Ch,014h,01Ch,004h,011h,00Eh,01Ch,00Fh,022h,00Bh,014h,002h,010h
        defb 011h,01Dh,029h,015h,017h,019h,01Bh,002h,00Eh,01Bh,028h,015h,018h,01Bh,01Eh,001h
        defb 00Bh,019h,027h,035h,019h,01Dh,021h,005h,028h,017h,026h,035h,01Ah,01Fh,024h,029h
        defb 01Bh,02Bh,01Bh,02Bh,031h,017h,01Dh,023h,00Eh,01Fh,010h,021h,028h,00Fh,016h,01Dh
        defb 001h,013h,025h,017h,01Fh,007h,00Fh,01Ch,019h,007h,01Ah,00Dh,016h,01Fh,00Dh,01Bh
        defb 01Ch,008h,014h,020h,022h,024h,006h,00Dh,019h,026h,013h,020h,023h,026h,009h,00Ch
        defb 016h,024h,032h,020h,024h,028h,00Ch,010h,013h,022h,031h,020h,025h,02Ah,00Fh,014h
        defb 026h,016h,026h,036h,01Ch,022h,028h,00Eh,019h,00Ah,01Bh,02Ch,013h,01Ah,021h,008h
        defb 00Ch,01Eh,010h,022h,00Ah,012h,01Ah,007h,004h,012h,005h,018h,021h,00Ah,018h,006h
        defb 007h,013h,01Fh,02Bh,00Dh,00Fh,011h,018h,024h,011h,01Eh,02Bh,02Eh,011h,014h,017h
        defb 021h,00Fh,01Dh,02Bh,02Fh,013h,017h,01Bh,01Eh,02Dh,01Ch,02Bh,030h,015h,01Ah,01Fh
        defb 011h,021h,031h,021h,027h,02Dh,013h,019h,024h,015h,026h,017h,01Eh,025h,00Ch,013h
        defb 017h,009h,01Bh,02Dh,015h,01Dh,005h,012h,00Fh,01Dh,010h,023h,00Ch,015h,003h,011h

Z180Neuro06:
        defb 014h,020h,00Ch,018h,01Ah,01Ch,01Eh,005h,011h,01Eh,02Bh,018h,01Bh,01Eh,021h,004h
        defb 00Eh,01Ch,02Ah,038h,01Ch,020h,024h,008h,02Bh,01Ah,029h,038h,01Dh,022h,027h,00Ch
        defb 01Eh,02Eh,01Eh,02Eh,014h,01Ah,020h,006h,011h,022h,013h,024h,02Bh,012h,019h,000h
        defb 004h,016h,028h,01Ah,022h,00Ah,012h,01Fh,01Ch,00Ah,01Dh,010h,019h,002h,010h,01Eh
        defb 01Fh,00Bh,017h,023h,025h,007h,009h,010h,01Ch,029h,016h,023h,026h,029h,00Ch,00Fh
        defb 019h,027h,015h,023h,027h,02Bh,00Fh,013h,016h,025h,034h,023h,028h,02Dh,012h,017h
        defb 029h,019h,029h,019h,01Fh,025h,00Bh,011h,01Ch,00Dh,01Eh,02Fh,016h,01Dh,024h,00Bh
        defb 00Fh,021h,013h,025h,00Dh,015h,01Dh,00Ah,007h,015h,008h,01Bh,024h,00Dh,01Bh,009h
        defb 00Ah,016h,022h,02Eh,010h,012h,014h,01Bh,007h,014h,021h,02Eh,011h,014h,017h,01Ah
        defb 024h,012h,020h,02Eh,032h,016h,01Ah,01Eh,021h,030h,01Fh,02Eh,033h,018h,01Dh,022h
        defb 014h,024h,014h,024h,02Ah,010h,016h,01Ch,007h,018h,029h,01Ah,021h,028h,00Fh,016h
        defb 01Ah,00Ch,01Eh,010h,018h,020h,008h,015h,012h,000h,013h,026h,00Fh,018h,006h,014h
        defb 015h,021h,00Dh,019h,01Bh,01Dh,01Fh,006h,012h,01Fh,02Ch,019h,01Ch,01Fh,022h,005h
        defb 00Fh,01Dh,02Bh,019h,01Dh,021h,025h,009h,02Ch,01Bh,02Ah,039h,01Eh,023h,028h,00Dh
        defb 01Fh,00Fh,01Fh,02Fh,015h,01Bh,021h,007h,012h,023h,014h,025h,02Ch,013h,01Ah,001h
        defb 005h,017h,029h,01Bh,023h,00Bh,013h,000h,01Dh,00Bh,01Eh,011h,01Ah,003h,011h,01Fh

Z180Neuro07:
        defb 002h,00Eh,01Ah,026h,028h,00Ah,00Ch,013h,01Fh,00Ch,019h,026h,029h,00Ch,00Fh,012h
        defb 01Ch,02Ah,018h,026h,02Ah,02Eh,012h,016h,019h,028h,037h,026h,02Bh,030h,015h,01Ah
        defb 00Ch,01Ch,02Ch,01Ch,022h,028h,00Eh,014h,01Fh,010h,021h,032h,019h,020h,007h,00Eh
        defb 012h,024h,016h,028h,010h,018h,000h,00Dh,00Ah,018h,00Bh,01Eh,007h,010h,01Eh,00Ch
        defb 00Dh,019h,025h,011h,013h,015h,017h,01Eh,00Ah,017h,024h,031h,014h,017h,01Ah,01Dh
        defb 027h,015h,023h,031h,015h,019h,01Dh,021h,024h,033h,022h,031h,036h,01Bh,020h,025h
        defb 017h,027h,017h,027h,02Dh,013h,019h,01Fh,00Ah,01Bh,02Ch,01Dh,024h,00Bh,012h,019h
        defb 01Dh,00Fh,021h,013h,01Bh,023h,00Bh,018h,015h,003h,016h,029h,012h,01Bh,009h,017h
        defb 018h,024h,010h,01Ch,01Eh,020h,002h,009h,015h,022h,00Fh,01Ch,01Fh,022h,005h,008h
        defb 012h,020h,02Eh,01Ch,020h,024h,028h,00Ch,00Fh,01Eh,02Dh,03Ch,021h,026h,02Bh,010h
        defb 022h,012h,022h,032h,018h,01Eh,024h,00Ah,015h,026h,017h,028h,00Fh,016h,01Dh,004h
        defb 008h,01Ah,00Ch,01Eh,026h,00Eh,016h,003h,000h,00Eh,021h,014h,01Dh,006h,014h,002h
        defb 003h,00Fh,01Bh,027h,029h,00Bh,00Dh,014h,020h,00Dh,01Ah,027h,02Ah,00Dh,010h,013h
        defb 01Dh,02Bh,019h,027h,02Bh,00Fh,013h,017h,01Ah,029h,038h,027h,02Ch,031h,016h,01Bh
        defb 00Dh,01Dh,02Dh,01Dh,023h,029h,00Fh,015h,020h,011h,022h,033h,01Ah,021h,008h,00Fh
        defb 013h,005h,017h,029h,011h,019h,001h,00Eh,00Bh,019h,00Ch,01Fh,008h,011h,01Fh,00Dh

Z180Neuro08:
        defb 010h,01Ch,028h,014h,016h,018h,01Ah,001h,00Dh,01Ah,027h,014h,017h,01Ah,01Dh,000h
        defb 00Ah,018h,026h,034h,018h,01Ch,020h,024h,027h,016h,025h,034h,019h,01Eh,023h,028h
        defb 01Ah,02Ah,01Ah,02Ah,030h,016h,01Ch,022h,00Dh,01Eh,00Fh,020h,027h,00Eh,015h,01Ch
        defb 000h,012h,024h,016h,01Eh,006h,00Eh,01Bh,018h,006h,019h,00Ch,015h,01Eh,00Ch,01Ah
        defb 01Bh,007h,013h,01Fh,021h,023h,005h,00Ch,018h,025h,012h,01Fh,022h,025h,008h,00Bh
        defb 015h,023h,031h,01Fh,023h,027h,00Bh,00Fh,012h,021h,030h,01Fh,024h,029h,02Eh,013h
        defb 025h,015h,025h,035h,01Bh,021h,027h,00Dh,018h,029h,01Ah,02Bh,012h,019h,020h,007h
        defb 00Bh,01Dh,00Fh,021h,029h,011h,019h,006h,003h,011h,024h,017h,020h,009h,017h,005h
        defb 006h,012h,01Eh,02Ah,00Ch,00Eh,010h,017h,023h,010h,01Dh,02Ah,02Dh,010h,013h,016h
        defb 020h,02Eh,01Ch,02Ah,02Eh,012h,016h,01Ah,01Dh,02Ch,01Bh,02Ah,02Fh,014h,019h,01Eh
        defb 010h,020h,030h,020h,026h,02Ch,012h,018h,023h,014h,025h,016h,01Dh,024h,00Bh,012h
        defb 016h,008h,01Ah,02Ch,014h,01Ch,004h,011h,00Eh,01Ch,00Fh,022h,00Bh,014h,002h,010h
        defb 011h,01Dh,029h,015h,017h,019h,01Bh,002h,00Eh,01Bh,028h,015h,018h,01Bh,01Eh,001h
        defb 00Bh,019h,027h,035h,019h,01Dh,021h,005h,028h,017h,026h,035h,01Ah,01Fh,024h,029h
        defb 01Bh,02Bh,01Bh,02Bh,031h,017h,01Dh,023h,00Eh,01Fh,010h,021h,028h,00Fh,016h,01Dh
        defb 001h,013h,025h,017h,01Fh,007h,00Fh,01Ch,019h,007h,01Ah,00Dh,016h,01Fh,00Dh,01Bh

Z180Neuro09:
        defb 01Eh,00Ah,016h,022h,024h,006h,008h,00Fh,01Bh,028h,015h,022h,025h,028h,00Bh,00Eh
        defb 018h,026h,014h,022h,026h,02Ah,00Eh,012h,015h,024h,033h,022h,027h,02Ch,011h,016h
        defb 028h,018h,028h,038h,01Eh,024h,00Ah,010h,01Bh,00Ch,01Dh,02Eh,015h,01Ch,023h,00Ah
        defb 00Eh,020h,012h,024h,00Ch,014h,01Ch,009h,006h,014h,007h,01Ah,023h,00Ch,01Ah,008h
        defb 009h,015h,021h,02Dh,00Fh,011h,013h,01Ah,006h,013h,020h,02Dh,010h,013h,016h,019h
        defb 023h,011h,01Fh,02Dh,031h,015h,019h,01Dh,020h,02Fh,01Eh,02Dh,032h,017h,01Ch,021h
        defb 013h,023h,033h,023h,029h,00Fh,015h,01Bh,006h,017h,028h,019h,020h,027h,00Eh,015h
        defb 019h,00Bh,01Dh,00Fh,017h,01Fh,007h,014h,011h,01Fh,012h,025h,00Eh,017h,005h,013h
        defb 014h,020h,00Ch,018h,01Ah,01Ch,01Eh,005h,011h,01Eh,02Bh,018h,01Bh,01Eh,021h,004h
        defb 00Eh,01Ch,02Ah,038h,01Ch,020h,024h,008h,02Bh,01Ah,029h,038h,01Dh,022h,027h,00Ch
        defb 01Eh,02Eh,01Eh,02Eh,014h,01Ah,020h,006h,011h,022h,013h,024h,02Bh,012h,019h,000h
        defb 004h,016h,028h,01Ah,022h,00Ah,012h,01Fh,01Ch,00Ah,01Dh,010h,019h,002h,010h,01Eh
        defb 01Fh,00Bh,017h,023h,025h,007h,009h,010h,01Ch,029h,016h,023h,026h,029h,00Ch,00Fh
        defb 019h,027h,015h,023h,027h,02Bh,00Fh,013h,016h,025h,034h,023h,028h,02Dh,012h,017h
        defb 029h,019h,029h,019h,01Fh,025h,00Bh,011h,01Ch,00Dh,01Eh,02Fh,016h,01Dh,024h,00Bh
        defb 00Fh,021h,013h,025h,00Dh,015h,01Dh,00Ah,007h,015h,008h,01Bh,024h,00Dh,01Bh,009h

Z180Neuro10:
        defb 00Ch,018h,024h,010h,012h,014h,016h,01Dh,009h,016h,023h,030h,013h,016h,019h,01Ch
        defb 026h,014h,022h,030h,014h,018h,01Ch,020h,023h,032h,021h,030h,035h,01Ah,01Fh,024h
        defb 016h,026h,016h,026h,02Ch,012h,018h,01Eh,009h,01Ah,02Bh,01Ch,023h,00Ah,011h,018h
        defb 01Ch,00Eh,020h,012h,01Ah,022h,00Ah,017h,014h,002h,015h,028h,011h,01Ah,008h,016h
        defb 017h,023h,00Fh,01Bh,01Dh,01Fh,001h,008h,014h,021h,02Eh,01Bh,01Eh,021h,024h,007h
        defb 011h,01Fh,02Dh,01Bh,01Fh,023h,027h,00Bh,02Eh,01Dh,02Ch,03Bh,020h,025h,02Ah,00Fh
        defb 021h,011h,021h,031h,017h,01Dh,023h,009h,014h,025h,016h,027h,02Eh,015h,01Ch,003h
        defb 007h,019h,00Bh,01Dh,025h,00Dh,015h,002h,01Fh,00Dh,020h,013h,01Ch,005h,013h,001h
        defb 002h,00Eh,01Ah,026h,028h,00Ah,00Ch,013h,01Fh,00Ch,019h,026h,029h,00Ch,00Fh,012h
        defb 01Ch,02Ah,018h,026h,02Ah,02Eh,012h,016h,019h,028h,037h,026h,02Bh,030h,015h,01Ah
        defb 00Ch,01Ch,02Ch,01Ch,022h,028h,00Eh,014h,01Fh,010h,021h,032h,019h,020h,007h,00Eh
        defb 012h,024h,016h,028h,010h,018h,000h,00Dh,00Ah,018h,00Bh,01Eh,007h,010h,01Eh,00Ch
        defb 00Dh,019h,025h,011h,013h,015h,017h,01Eh,00Ah,017h,024h,031h,014h,017h,01Ah,01Dh
        defb 027h,015h,023h,031h,015h,019h,01Dh,021h,024h,033h,022h,031h,036h,01Bh,020h,025h
        defb 017h,027h,017h,027h,02Dh,013h,019h,01Fh,00Ah,01Bh,02Ch,01Dh,024h,00Bh,012h,019h
        defb 01Dh,00Fh,021h,013h,01Bh,023h,00Bh,018h,015h,003h,016h,029h,012h,01Bh,009h,017h

Z180Neuro11:
        defb 01Ah,006h,012h,01Eh,020h,022h,004h,00Bh,017h,024h,011h,01Eh,021h,024h,007h,00Ah
        defb 014h,022h,030h,01Eh,022h,026h,00Ah,00Eh,011h,020h,02Fh,01Eh,023h,028h,02Dh,012h
        defb 024h,014h,024h,034h,01Ah,020h,026h,00Ch,017h,028h,019h,02Ah,011h,018h,01Fh,006h
        defb 00Ah,01Ch,00Eh,020h,028h,010h,018h,005h,002h,010h,023h,016h,01Fh,008h,016h,004h
        defb 005h,011h,01Dh,029h,00Bh,00Dh,00Fh,016h,022h,00Fh,01Ch,029h,02Ch,00Fh,012h,015h
        defb 01Fh,02Dh,01Bh,029h,02Dh,011h,015h,019h,01Ch,02Bh,01Ah,029h,02Eh,033h,018h,01Dh
        defb 00Fh,01Fh,02Fh,01Fh,025h,02Bh,011h,017h,022h,013h,024h,015h,01Ch,023h,00Ah,011h
        defb 015h,007h,019h,02Bh,013h,01Bh,003h,010h,00Dh,01Bh,00Eh,021h,00Ah,013h,001h,00Fh
        defb 010h,01Ch,028h,014h,016h,018h,01Ah,001h,00Dh,01Ah,027h,014h,017h,01Ah,01Dh,000h
        defb 00Ah,018h,026h,034h,018h,01Ch,020h,024h,027h,016h,025h,034h,019h,01Eh,023h,028h
        defb 01Ah,02Ah,01Ah,02Ah,030h,016h,01Ch,022h,00Dh,01Eh,00Fh,020h,027h,00Eh,015h,01Ch
        defb 000h,012h,024h,016h,01Eh,006h,00Eh,01Bh,018h,006h,019h,00Ch,015h,01Eh,00Ch,01Ah
        defb 01Bh,007h,013h,01Fh,021h,023h,005h,00Ch,018h,025h,012h,01Fh,022h,025h,008h,00Bh
        defb 015h,023h,031h,01Fh,023h,027h,00Bh,00Fh,012h,021h,030h,01Fh,024h,029h,02Eh,013h
        defb 025h,015h,025h,035h,01Bh,021h,027h,00Dh,018h,029h,01Ah,02Bh,012h,019h,020h,007h
        defb 00Bh,01Dh,00Fh,021h,029h,011h,019h,006h,003h,011h,024h,017h,020h,009h,017h,005h

Z180Neuro12:
        defb 008h,014h,020h,02Ch,00Eh,010h,012h,019h,005h,012h,01Fh,02Ch,00Fh,012h,015h,018h
        defb 022h,010h,01Eh,02Ch,030h,014h,018h,01Ch,01Fh,02Eh,01Dh,02Ch,031h,016h,01Bh,020h
        defb 012h,022h,032h,022h,028h,02Eh,014h,01Ah,005h,016h,027h,018h,01Fh,026h,00Dh,014h
        defb 018h,00Ah,01Ch,02Eh,016h,01Eh,006h,013h,010h,01Eh,011h,024h,00Dh,016h,004h,012h
        defb 013h,01Fh,00Bh,017h,019h,01Bh,01Dh,004h,010h,01Dh,02Ah,017h,01Ah,01Dh,020h,003h
        defb 00Dh,01Bh,029h,037h,01Bh,01Fh,023h,007h,02Ah,019h,028h,037h,01Ch,021h,026h,00Bh
        defb 01Dh,02Dh,01Dh,02Dh,033h,019h,01Fh,005h,010h,021h,012h,023h,02Ah,011h,018h,01Fh
        defb 003h,015h,027h,019h,021h,009h,011h,01Eh,01Bh,009h,01Ch,00Fh,018h,001h,00Fh,01Dh
        defb 01Eh,00Ah,016h,022h,024h,006h,008h,00Fh,01Bh,028h,015h,022h,025h,028h,00Bh,00Eh
        defb 018h,026h,014h,022h,026h,02Ah,00Eh,012h,015h,024h,033h,022h,027h,02Ch,011h,016h
        defb 028h,018h,028h,038h,01Eh,024h,00Ah,010h,01Bh,00Ch,01Dh,02Eh,015h,01Ch,023h,00Ah
        defb 00Eh,020h,012h,024h,00Ch,014h,01Ch,009h,006h,014h,007h,01Ah,023h,00Ch,01Ah,008h
        defb 009h,015h,021h,02Dh,00Fh,011h,013h,01Ah,006h,013h,020h,02Dh,010h,013h,016h,019h
        defb 023h,011h,01Fh,02Dh,031h,015h,019h,01Dh,020h,02Fh,01Eh,02Dh,032h,017h,01Ch,021h
        defb 013h,023h,033h,023h,029h,00Fh,015h,01Bh,006h,017h,028h,019h,020h,027h,00Eh,015h
        defb 019h,00Bh,01Dh,00Fh,017h,01Fh,007h,014h,011h,01Fh,012h,025h,00Eh,017h,005h,013h

Z180Neuro13:
        defb 016h,022h,00Eh,01Ah,01Ch,01Eh,000h,007h,013h,020h,02Dh,01Ah,01Dh,020h,023h,006h
        defb 010h,01Eh,02Ch,01Ah,01Eh,022h,026h,00Ah,02Dh,01Ch,02Bh,03Ah,01Fh,024h,029h,00Eh
        defb 020h,010h,020h,030h,016h,01Ch,022h,008h,013h,024h,015h,026h,02Dh,014h,01Bh,002h
        defb 006h,018h,00Ah,01Ch,024h,00Ch,014h,001h,01Eh,00Ch,01Fh,012h,01Bh,004h,012h,000h
        defb 001h,00Dh,019h,025h,027h,009h,00Bh,012h,01Eh,00Bh,018h,025h,028h,00Bh,00Eh,011h
        defb 01Bh,029h,017h,025h,029h,02Dh,011h,015h,018h,027h,036h,025h,02Ah,02Fh,014h,019h
        defb 00Bh,01Bh,02Bh,01Bh,021h,027h,00Dh,013h,01Eh,00Fh,020h,031h,018h,01Fh,006h,00Dh
        defb 011h,023h,015h,027h,00Fh,017h,01Fh,00Ch,009h,017h,00Ah,01Dh,006h,00Fh,01Dh,00Bh
        defb 00Ch,018h,024h,010h,012h,014h,016h,01Dh,009h,016h,023h,030h,013h,016h,019h,01Ch
        defb 026h,014h,022h,030h,014h,018h,01Ch,020h,023h,032h,021h,030h,035h,01Ah,01Fh,024h
        defb 016h,026h,016h,026h,02Ch,012h,018h,01Eh,009h,01Ah,02Bh,01Ch,023h,00Ah,011h,018h
        defb 01Ch,00Eh,020h,012h,01Ah,022h,00Ah,017h,014h,002h,015h,028h,011h,01Ah,008h,016h
        defb 017h,023h,00Fh,01Bh,01Dh,01Fh,001h,008h,014h,021h,02Eh,01Bh,01Eh,021h,024h,007h
        defb 011h,01Fh,02Dh,01Bh,01Fh,023h,027h,00Bh,02Eh,01Dh,02Ch,03Bh,020h,025h,02Ah,00Fh
        defb 021h,011h,021h,031h,017h,01Dh,023h,009h,014h,025h,016h,027h,02Eh,015h,01Ch,003h
        defb 007h,019h,00Bh,01Dh,025h,00Dh,015h,002h,01Fh,00Dh,020h,013h,01Ch,005h,013h,001h

Z180Neuro14:
        defb 004h,010h,01Ch,028h,00Ah,00Ch,00Eh,015h,021h,00Eh,01Bh,028h,02Bh,00Eh,011h,014h
        defb 01Eh,02Ch,01Ah,028h,02Ch,010h,014h,018h,01Bh,02Ah,019h,028h,02Dh,032h,017h,01Ch
        defb 00Eh,01Eh,02Eh,01Eh,024h,02Ah,010h,016h,021h,012h,023h,014h,01Bh,022h,009h,010h
        defb 014h,006h,018h,02Ah,012h,01Ah,002h,00Fh,00Ch,01Ah,00Dh,020h,009h,012h,000h,00Eh
        defb 00Fh,01Bh,027h,013h,015h,017h,019h,000h,00Ch,019h,026h,033h,016h,019h,01Ch,01Fh
        defb 029h,017h,025h,033h,017h,01Bh,01Fh,023h,026h,015h,024h,033h,038h,01Dh,022h,027h
        defb 019h,029h,019h,029h,02Fh,015h,01Bh,021h,00Ch,01Dh,02Eh,01Fh,026h,00Dh,014h,01Bh
        defb 01Fh,011h,023h,015h,01Dh,005h,00Dh,01Ah,017h,005h,018h,00Bh,014h,01Dh,00Bh,019h
        defb 01Ah,006h,012h,01Eh,020h,022h,004h,00Bh,017h,024h,011h,01Eh,021h,024h,007h,00Ah
        defb 014h,022h,030h,01Eh,022h,026h,00Ah,00Eh,011h,020h,02Fh,01Eh,023h,028h,02Dh,012h
        defb 024h,014h,024h,034h,01Ah,020h,026h,00Ch,017h,028h,019h,02Ah,011h,018h,01Fh,006h
        defb 00Ah,01Ch,00Eh,020h,028h,010h,018h,005h,002h,010h,023h,016h,01Fh,008h,016h,004h
        defb 005h,011h,01Dh,029h,00Bh,00Dh,00Fh,016h,022h,00Fh,01Ch,029h,02Ch,00Fh,012h,015h
        defb 01Fh,02Dh,01Bh,029h,02Dh,011h,015h,019h,01Ch,02Bh,01Ah,029h,02Eh,033h,018h,01Dh
        defb 00Fh,01Fh,02Fh,01Fh,025h,02Bh,011h,017h,022h,013h,024h,015h,01Ch,023h,00Ah,011h
        defb 015h,007h,019h,02Bh,013h,01Bh,003h,010h,00Dh,01Bh,00Eh,021h,00Ah,013h,001h,00Fh

Z180Neuro15:
        defb 012h,01Eh,00Ah,016h,018h,01Ah,01Ch,003h,00Fh,01Ch,029h,016h,019h,01Ch,01Fh,002h
        defb 00Ch,01Ah,028h,036h,01Ah,01Eh,022h,006h,029h,018h,027h,036h,01Bh,020h,025h,00Ah
        defb 01Ch,02Ch,01Ch,02Ch,032h,018h,01Eh,024h,00Fh,020h,011h,022h,029h,010h,017h,01Eh
        defb 002h,014h,026h,018h,020h,008h,010h,01Dh,01Ah,008h,01Bh,00Eh,017h,000h,00Eh,01Ch
        defb 01Dh,009h,015h,021h,023h,005h,007h,00Eh,01Ah,027h,014h,021h,024h,027h,00Ah,00Dh
        defb 017h,025h,033h,021h,025h,029h,00Dh,011h,014h,023h,032h,021h,026h,02Bh,010h,015h
        defb 027h,017h,027h,037h,01Dh,023h,029h,00Fh,01Ah,00Bh,01Ch,02Dh,014h,01Bh,022h,009h
        defb 00Dh,01Fh,011h,023h,00Bh,013h,01Bh,008h,005h,013h,006h,019h,022h,00Bh,019h,007h
        defb 008h,014h,020h,02Ch,00Eh,010h,012h,019h,005h,012h,01Fh,02Ch,00Fh,012h,015h,018h
        defb 022h,010h,01Eh,02Ch,030h,014h,018h,01Ch,01Fh,02Eh,01Dh,02Ch,031h,016h,01Bh,020h
        defb 012h,022h,032h,022h,028h,02Eh,014h,01Ah,005h,016h,027h,018h,01Fh,026h,00Dh,014h
        defb 018h,00Ah,01Ch,02Eh,016h,01Eh,006h,013h,010h,01Eh,011h,024h,00Dh,016h,004h,012h
        defb 013h,01Fh,00Bh,017h,019h,01Bh,01Dh,004h,010h,01Dh,02Ah,017h,01Ah,01Dh,020h,003h
        defb 00Dh,01Bh,029h,037h,01Bh,01Fh,023h,007h,02Ah,019h,028h,037h,01Ch,021h,026h,00Bh
        defb 01Dh,02Dh,01Dh,02Dh,033h,019h,01Fh,005h,010h,021h,012h,023h,02Ah,011h,018h,01Fh
        defb 003h,015h,027h,019h,021h,009h,011h,01Eh,01Bh,009h,01Ch,00Fh,018h,001h,00Fh,01Dh

Z180Neuro16:
        defb 000h,00Ch,018h,024h,026h,008h,00Ah,011h,01Dh,00Ah,017h,024h,027h,00Ah,00Dh,010h
        defb 01Ah,028h,016h,024h,028h,02Ch,010h,014h,017h,026h,035h,024h,029h,02Eh,013h,018h
        defb 00Ah,01Ah,02Ah,01Ah,020h,026h,00Ch,012h,01Dh,00Eh,01Fh,030h,017h,01Eh,005h,00Ch
        defb 010h,022h,014h,026h,00Eh,016h,01Eh,00Bh,008h,016h,009h,01Ch,005h,00Eh,01Ch,00Ah
        defb 00Bh,017h,023h,00Fh,011h,013h,015h,01Ch,008h,015h,022h,02Fh,012h,015h,018h,01Bh
        defb 025h,013h,021h,02Fh,033h,017h,01Bh,01Fh,022h,031h,020h,02Fh,034h,019h,01Eh,023h
        defb 015h,025h,015h,025h,02Bh,011h,017h,01Dh,008h,019h,02Ah,01Bh,022h,029h,010h,017h
        defb 01Bh,00Dh,01Fh,011h,019h,021h,009h,016h,013h,001h,014h,027h,010h,019h,007h,015h
        defb 016h,022h,00Eh,01Ah,01Ch,01Eh,000h,007h,013h,020h,02Dh,01Ah,01Dh,020h,023h,006h
        defb 010h,01Eh,02Ch,01Ah,01Eh,022h,026h,00Ah,02Dh,01Ch,02Bh,03Ah,01Fh,024h,029h,00Eh
        defb 020h,010h,020h,030h,016h,01Ch,022h,008h,013h,024h,015h,026h,02Dh,014h,01Bh,002h
        defb 006h,018h,00Ah,01Ch,024h,00Ch,014h,001h,01Eh,00Ch,01Fh,012h,01Bh,004h,012h,000h
        defb 001h,00Dh,019h,025h,027h,009h,00Bh,012h,01Eh,00Bh,018h,025h,028h,00Bh,00Eh,011h
        defb 01Bh,029h,017h,025h,029h,02Dh,011h,015h,018h,027h,036h,025h,02Ah,02Fh,014h,019h
        defb 00Bh,01Bh,02Bh,01Bh,021h,027h,00Dh,013h,01Eh,00Fh,020h,031h,018h,01Fh,006h,00Dh
        defb 011h,023h,015h,027h,00Fh,017h,01Fh,00Ch,009h,017h,00Ah,01Dh,006h,00Fh,01Dh,00Bh

Z180Neuro17:
        defb 00Eh,01Ah,026h,012h,014h,016h,018h,01Fh,00Bh,018h,025h,032h,015h,018h,01Bh,01Eh
        defb 028h,016h,024h,032h,016h,01Ah,01Eh,022h,025h,014h,023h,032h,037h,01Ch,021h,026h
        defb 018h,028h,018h,028h,02Eh,014h,01Ah,020h,00Bh,01Ch,02Dh,01Eh,025h,00Ch,013h,01Ah
        defb 01Eh,010h,022h,014h,01Ch,024h,00Ch,019h,016h,004h,017h,00Ah,013h,01Ch,00Ah,018h
        defb 019h,005h,011h,01Dh,01Fh,021h,003h,00Ah,016h,023h,010h,01Dh,020h,023h,006h,009h
        defb 013h,021h,02Fh,01Dh,021h,025h,029h,00Dh,010h,01Fh,02Eh,03Dh,022h,027h,02Ch,011h
        defb 023h,013h,023h,033h,019h,01Fh,025h,00Bh,016h,027h,018h,029h,010h,017h,01Eh,005h
        defb 009h,01Bh,00Dh,01Fh,027h,00Fh,017h,004h,001h,00Fh,022h,015h,01Eh,007h,015h,003h
        defb 004h,010h,01Ch,028h,00Ah,00Ch,00Eh,015h,021h,00Eh,01Bh,028h,02Bh,00Eh,011h,014h
        defb 01Eh,02Ch,01Ah,028h,02Ch,010h,014h,018h,01Bh,02Ah,019h,028h,02Dh,032h,017h,01Ch
        defb 00Eh,01Eh,02Eh,01Eh,024h,02Ah,010h,016h,021h,012h,023h,014h,01Bh,022h,009h,010h
        defb 014h,006h,018h,02Ah,012h,01Ah,002h,00Fh,00Ch,01Ah,00Dh,020h,009h,012h,000h,00Eh
        defb 00Fh,01Bh,027h,013h,015h,017h,019h,000h,00Ch,019h,026h,033h,016h,019h,01Ch,01Fh
        defb 029h,017h,025h,033h,017h,01Bh,01Fh,023h,026h,015h,024h,033h,038h,01Dh,022h,027h
        defb 019h,029h,019h,029h,02Fh,015h,01Bh,021h,00Ch,01Dh,02Eh,01Fh,026h,00Dh,014h,01Bh
        defb 01Fh,011h,023h,015h,01Dh,005h,00Dh,01Ah,017h,005h,018h,00Bh,014h,01Dh,00Bh,019h

Z180Neuro18:
        defb 01Ch,008h,014h,020h,022h,024h,006h,00Dh,019h,026h,013h,020h,023h,026h,009h,00Ch
        defb 016h,024h,032h,020h,024h,028h,00Ch,010h,013h,022h,031h,020h,025h,02Ah,00Fh,014h
        defb 026h,016h,026h,036h,01Ch,022h,028h,00Eh,019h,00Ah,01Bh,02Ch,013h,01Ah,021h,008h
        defb 00Ch,01Eh,010h,022h,00Ah,012h,01Ah,007h,004h,012h,005h,018h,021h,00Ah,018h,006h
        defb 007h,013h,01Fh,02Bh,00Dh,00Fh,011h,018h,024h,011h,01Eh,02Bh,02Eh,011h,014h,017h
        defb 021h,00Fh,01Dh,02Bh,02Fh,013h,017h,01Bh,01Eh,02Dh,01Ch,02Bh,030h,015h,01Ah,01Fh
        defb 011h,021h,031h,021h,027h,02Dh,013h,019h,024h,015h,026h,017h,01Eh,025h,00Ch,013h
        defb 017h,009h,01Bh,02Dh,015h,01Dh,005h,012h,00Fh,01Dh,010h,023h,00Ch,015h,003h,011h
        defb 012h,01Eh,00Ah,016h,018h,01Ah,01Ch,003h,00Fh,01Ch,029h,016h,019h,01Ch,01Fh,002h
        defb 00Ch,01Ah,028h,036h,01Ah,01Eh,022h,006h,029h,018h,027h,036h,01Bh,020h,025h,00Ah
        defb 01Ch,02Ch,01Ch,02Ch,032h,018h,01Eh,024h,00Fh,020h,011h,022h,029h,010h,017h,01Eh
        defb 002h,014h,026h,018h,020h,008h,010h,01Dh,01Ah,008h,01Bh,00Eh,017h,000h,00Eh,01Ch
        defb 01Dh,009h,015h,021h,023h,005h,007h,00Eh,01Ah,027h,014h,021h,024h,027h,00Ah,00Dh
        defb 017h,025h,033h,021h,025h,029h,00Dh,011h,014h,023h,032h,021h,026h,02Bh,010h,015h
        defb 027h,017h,027h,037h,01Dh,023h,029h,00Fh,01Ah,00Bh,01Ch,02Dh,014h,01Bh,022h,009h
        defb 00Dh,01Fh,011h,023h,00Bh,013h,01Bh,008h,005h,013h,006h,019h,022h,00Bh,019h,007h

Z180Neuro19:
        defb 00Ah,016h,022h,02Eh,010h,012h,014h,01Bh,007h,014h,021h,02Eh,011h,014h,017h,01Ah
        defb 024h,012h,020h,02Eh,032h,016h,01Ah,01Eh,021h,030h,01Fh,02Eh,033h,018h,01Dh,022h
        defb 014h,024h,014h,024h,02Ah,010h,016h,01Ch,007h,018h,029h,01Ah,021h,028h,00Fh,016h
        defb 01Ah,00Ch,01Eh,010h,018h,020h,008h,015h,012h,000h,013h,026h,00Fh,018h,006h,014h
        defb 015h,021h,00Dh,019h,01Bh,01Dh,01Fh,006h,012h,01Fh,02Ch,019h,01Ch,01Fh,022h,005h
        defb 00Fh,01Dh,02Bh,019h,01Dh,021h,025h,009h,02Ch,01Bh,02Ah,039h,01Eh,023h,028h,00Dh
        defb 01Fh,00Fh,01Fh,02Fh,015h,01Bh,021h,007h,012h,023h,014h,025h,02Ch,013h,01Ah,001h
        defb 005h,017h,029h,01Bh,023h,00Bh,013h,000h,01Dh,00Bh,01Eh,011h,01Ah,003h,011h,01Fh
        defb 000h,00Ch,018h,024h,026h,008h,00Ah,011h,01Dh,00Ah,017h,024h,027h,00Ah,00Dh,010h
        defb 01Ah,028h,016h,024h,028h,02Ch,010h,014h,017h,026h,035h,024h,029h,02Eh,013h,018h
        defb 00Ah,01Ah,02Ah,01Ah,020h,026h,00Ch,012h,01Dh,00Eh,01Fh,030h,017h,01Eh,005h,00Ch
        defb 010h,022h,014h,026h,00Eh,016h,01Eh,00Bh,008h,016h,009h,01Ch,005h,00Eh,01Ch,00Ah
        defb 00Bh,017h,023h,00Fh,011h,013h,015h,01Ch,008h,015h,022h,02Fh,012h,015h,018h,01Bh
        defb 025h,013h,021h,02Fh,033h,017h,01Bh,01Fh,022h,031h,020h,02Fh,034h,019h,01Eh,023h
        defb 015h,025h,015h,025h,02Bh,011h,017h,01Dh,008h,019h,02Ah,01Bh,022h,029h,010h,017h
        defb 01Bh,00Dh,01Fh,011h,019h,021h,009h,016h,013h,001h,014h,027h,010h,019h,007h,015h

Z180Neuro20:
        defb 018h,024h,010h,01Ch,01Eh,020h,002h,009h,015h,022h,00Fh,01Ch,01Fh,022h,005h,008h
        defb 012h,020h,02Eh,01Ch,020h,024h,028h,00Ch,00Fh,01Eh,02Dh,03Ch,021h,026h,02Bh,010h
        defb 022h,012h,022h,032h,018h,01Eh,024h,00Ah,015h,026h,017h,028h,00Fh,016h,01Dh,004h
        defb 008h,01Ah,00Ch,01Eh,026h,00Eh,016h,003h,000h,00Eh,021h,014h,01Dh,006h,014h,002h
        defb 003h,00Fh,01Bh,027h,029h,00Bh,00Dh,014h,020h,00Dh,01Ah,027h,02Ah,00Dh,010h,013h
        defb 01Dh,02Bh,019h,027h,02Bh,00Fh,013h,017h,01Ah,029h,038h,027h,02Ch,031h,016h,01Bh
        defb 00Dh,01Dh,02Dh,01Dh,023h,029h,00Fh,015h,020h,011h,022h,033h,01Ah,021h,008h,00Fh
        defb 013h,005h,017h,029h,011h,019h,001h,00Eh,00Bh,019h,00Ch,01Fh,008h,011h,01Fh,00Dh
        defb 00Eh,01Ah,026h,012h,014h,016h,018h,01Fh,00Bh,018h,025h,032h,015h,018h,01Bh,01Eh
        defb 028h,016h,024h,032h,016h,01Ah,01Eh,022h,025h,014h,023h,032h,037h,01Ch,021h,026h
        defb 018h,028h,018h,028h,02Eh,014h,01Ah,020h,00Bh,01Ch,02Dh,01Eh,025h,00Ch,013h,01Ah
        defb 01Eh,010h,022h,014h,01Ch,024h,00Ch,019h,016h,004h,017h,00Ah,013h,01Ch,00Ah,018h
        defb 019h,005h,011h,01Dh,01Fh,021h,003h,00Ah,016h,023h,010h,01Dh,020h,023h,006h,009h
        defb 013h,021h,02Fh,01Dh,021h,025h,029h,00Dh,010h,01Fh,02Eh,03Dh,022h,027h,02Ch,011h
        defb 023h,013h,023h,033h,019h,01Fh,025h,00Bh,016h,027h,018h,029h,010h,017h,01Eh,005h
        defb 009h,01Bh,00Dh,01Fh,027h,00Fh,017h,004h,001h,00Fh,022h,015h,01Eh,007h,015h,003h

Z180Neuro21:
        defb 006h,012h,01Eh,02Ah,00Ch,00Eh,010h,017h,023h,010h,01Dh,02Ah,02Dh,010h,013h,016h
        defb 020h,02Eh,01Ch,02Ah,02Eh,012h,016h,01Ah,01Dh,02Ch,01Bh,02Ah,02Fh,014h,019h,01Eh
        defb 010h,020h,030h,020h,026h,02Ch,012h,018h,023h,014h,025h,016h,01Dh,024h,00Bh,012h
        defb 016h,008h,01Ah,02Ch,014h,01Ch,004h,011h,00Eh,01Ch,00Fh,022h,00Bh,014h,002h,010h
        defb 011h,01Dh,029h,015h,017h,019h,01Bh,002h,00Eh,01Bh,028h,015h,018h,01Bh,01Eh,001h
        defb 00Bh,019h,027h,035h,019h,01Dh,021h,005h,028h,017h,026h,035h,01Ah,01Fh,024h,029h
        defb 01Bh,02Bh,01Bh,02Bh,031h,017h,01Dh,023h,00Eh,01Fh,010h,021h,028h,00Fh,016h,01Dh
        defb 001h,013h,025h,017h,01Fh,007h,00Fh,01Ch,019h,007h,01Ah,00Dh,016h,01Fh,00Dh,01Bh
        defb 01Ch,008h,014h,020h,022h,024h,006h,00Dh,019h,026h,013h,020h,023h,026h,009h,00Ch
        defb 016h,024h,032h,020h,024h,028h,00Ch,010h,013h,022h,031h,020h,025h,02Ah,00Fh,014h
        defb 026h,016h,026h,036h,01Ch,022h,028h,00Eh,019h,00Ah,01Bh,02Ch,013h,01Ah,021h,008h
        defb 00Ch,01Eh,010h,022h,00Ah,012h,01Ah,007h,004h,012h,005h,018h,021h,00Ah,018h,006h
        defb 007h,013h,01Fh,02Bh,00Dh,00Fh,011h,018h,024h,011h,01Eh,02Bh,02Eh,011h,014h,017h
        defb 021h,00Fh,01Dh,02Bh,02Fh,013h,017h,01Bh,01Eh,02Dh,01Ch,02Bh,030h,015h,01Ah,01Fh
        defb 011h,021h,031h,021h,027h,02Dh,013h,019h,024h,015h,026h,017h,01Eh,025h,00Ch,013h
        defb 017h,009h,01Bh,02Dh,015h,01Dh,005h,012h,00Fh,01Dh,010h,023h,00Ch,015h,003h,011h

Z180Neuro22:
        defb 014h,020h,00Ch,018h,01Ah,01Ch,01Eh,005h,011h,01Eh,02Bh,018h,01Bh,01Eh,021h,004h
        defb 00Eh,01Ch,02Ah,038h,01Ch,020h,024h,008h,02Bh,01Ah,029h,038h,01Dh,022h,027h,00Ch
        defb 01Eh,02Eh,01Eh,02Eh,014h,01Ah,020h,006h,011h,022h,013h,024h,02Bh,012h,019h,000h
        defb 004h,016h,028h,01Ah,022h,00Ah,012h,01Fh,01Ch,00Ah,01Dh,010h,019h,002h,010h,01Eh
        defb 01Fh,00Bh,017h,023h,025h,007h,009h,010h,01Ch,029h,016h,023h,026h,029h,00Ch,00Fh
        defb 019h,027h,015h,023h,027h,02Bh,00Fh,013h,016h,025h,034h,023h,028h,02Dh,012h,017h
        defb 029h,019h,029h,019h,01Fh,025h,00Bh,011h,01Ch,00Dh,01Eh,02Fh,016h,01Dh,024h,00Bh
        defb 00Fh,021h,013h,025h,00Dh,015h,01Dh,00Ah,007h,015h,008h,01Bh,024h,00Dh,01Bh,009h
        defb 00Ah,016h,022h,02Eh,010h,012h,014h,01Bh,007h,014h,021h,02Eh,011h,014h,017h,01Ah
        defb 024h,012h,020h,02Eh,032h,016h,01Ah,01Eh,021h,030h,01Fh,02Eh,033h,018h,01Dh,022h
        defb 014h,024h,014h,024h,02Ah,010h,016h,01Ch,007h,018h,029h,01Ah,021h,028h,00Fh,016h
        defb 01Ah,00Ch,01Eh,010h,018h,020h,008h,015h,012h,000h,013h,026h,00Fh,018h,006h,014h
        defb 015h,021h,00Dh,019h,01Bh,01Dh,01Fh,006h,012h,01Fh,02Ch,019h,01Ch,01Fh,022h,005h
        defb 00Fh,01Dh,02Bh,019h,01Dh,021h,025h,009h,02Ch,01Bh,02Ah,039h,01Eh,023h,028h,00Dh
        defb 01Fh,00Fh,01Fh,02Fh,015h,01Bh,021h,007h,012h,023h,014h,025h,02Ch,013h,01Ah,001h
        defb 005h,017h,029h,01Bh,023h,00Bh,013h,000h,01Dh,00Bh,01Eh,011h,01Ah,003h,011h,01Fh

Z180Neuro23:
        defb 002h,00Eh,01Ah,026h,028h,00Ah,00Ch,013h,01Fh,00Ch,019h,026h,029h,00Ch,00Fh,012h
        defb 01Ch,02Ah,018h,026h,02Ah,02Eh,012h,016h,019h,028h,037h,026h,02Bh,030h,015h,01Ah
        defb 00Ch,01Ch,02Ch,01Ch,022h,028h,00Eh,014h,01Fh,010h,021h,032h,019h,020h,007h,00Eh
        defb 012h,024h,016h,028h,010h,018h,000h,00Dh,00Ah,018h,00Bh,01Eh,007h,010h,01Eh,00Ch
        defb 00Dh,019h,025h,011h,013h,015h,017h,01Eh,00Ah,017h,024h,031h,014h,017h,01Ah,01Dh
        defb 027h,015h,023h,031h,015h,019h,01Dh,021h,024h,033h,022h,031h,036h,01Bh,020h,025h
        defb 017h,027h,017h,027h,02Dh,013h,019h,01Fh,00Ah,01Bh,02Ch,01Dh,024h,00Bh,012h,019h
        defb 01Dh,00Fh,021h,013h,01Bh,023h,00Bh,018h,015h,003h,016h,029h,012h,01Bh,009h,017h
        defb 018h,024h,010h,01Ch,01Eh,020h,002h,009h,015h,022h,00Fh,01Ch,01Fh,022h,005h,008h
        defb 012h,020h,02Eh,01Ch,020h,024h,028h,00Ch,00Fh,01Eh,02Dh,03Ch,021h,026h,02Bh,010h
        defb 022h,012h,022h,032h,018h,01Eh,024h,00Ah,015h,026h,017h,028h,00Fh,016h,01Dh,004h
        defb 008h,01Ah,00Ch,01Eh,026h,00Eh,016h,003h,000h,00Eh,021h,014h,01Dh,006h,014h,002h
        defb 003h,00Fh,01Bh,027h,029h,00Bh,00Dh,014h,020h,00Dh,01Ah,027h,02Ah,00Dh,010h,013h
        defb 01Dh,02Bh,019h,027h,02Bh,00Fh,013h,017h,01Ah,029h,038h,027h,02Ch,031h,016h,01Bh
        defb 00Dh,01Dh,02Dh,01Dh,023h,029h,00Fh,015h,020h,011h,022h,033h,01Ah,021h,008h,00Fh
        defb 013h,005h,017h,029h,011h,019h,001h,00Eh,00Bh,019h,00Ch,01Fh,008h,011h,01Fh,00Dh

Z180Neuro24:
        defb 010h,01Ch,028h,014h,016h,018h,01Ah,001h,00Dh,01Ah,027h,014h,017h,01Ah,01Dh,000h
        defb 00Ah,018h,026h,034h,018h,01Ch,020h,024h,027h,016h,025h,034h,019h,01Eh,023h,028h
        defb 01Ah,02Ah,01Ah,02Ah,030h,016h,01Ch,022h,00Dh,01Eh,00Fh,020h,027h,00Eh,015h,01Ch
        defb 000h,012h,024h,016h,01Eh,006h,00Eh,01Bh,018h,006h,019h,00Ch,015h,01Eh,00Ch,01Ah
        defb 01Bh,007h,013h,01Fh,021h,023h,005h,00Ch,018h,025h,012h,01Fh,022h,025h,008h,00Bh
        defb 015h,023h,031h,01Fh,023h,027h,00Bh,00Fh,012h,021h,030h,01Fh,024h,029h,02Eh,013h
        defb 025h,015h,025h,035h,01Bh,021h,027h,00Dh,018h,029h,01Ah,02Bh,012h,019h,020h,007h
        defb 00Bh,01Dh,00Fh,021h,029h,011h,019h,006h,003h,011h,024h,017h,020h,009h,017h,005h
        defb 006h,012h,01Eh,02Ah,00Ch,00Eh,010h,017h,023h,010h,01Dh,02Ah,02Dh,010h,013h,016h
        defb 020h,02Eh,01Ch,02Ah,02Eh,012h,016h,01Ah,01Dh,02Ch,01Bh,02Ah,02Fh,014h,019h,01Eh
        defb 010h,020h,030h,020h,026h,02Ch,012h,018h,023h,014h,025h,016h,01Dh,024h,00Bh,012h
        defb 016h,008h,01Ah,02Ch,014h,01Ch,004h,011h,00Eh,01Ch,00Fh,022h,00Bh,014h,002h,010h
        defb 011h,01Dh,029h,015h,017h,019h,01Bh,002h,00Eh,01Bh,028h,015h,018h,01Bh,01Eh,001h
        defb 00Bh,019h,027h,035h,019h,01Dh,021h,005h,028h,017h,026h,035h,01Ah,01Fh,024h,029h
        defb 01Bh,02Bh,01Bh,02Bh,031h,017h,01Dh,023h,00Eh,01Fh,010h,021h,028h,00Fh,016h,01Dh
        defb 001h,013h,025h,017h,01Fh,007h,00Fh,01Ch,019h,007h,01Ah,00Dh,016h,01Fh,00Dh,01Bh

Z180Neuro25:
        defb 01Eh,00Ah,016h,022h,024h,006h,008h,00Fh,01Bh,028h,015h,022h,025h,028h,00Bh,00Eh
        defb 018h,026h,014h,022h,026h,02Ah,00Eh,012h,015h,024h,033h,022h,027h,02Ch,011h,016h
        defb 028h,018h,028h,038h,01Eh,024h,00Ah,010h,01Bh,00Ch,01Dh,02Eh,015h,01Ch,023h,00Ah
        defb 00Eh,020h,012h,024h,00Ch,014h,01Ch,009h,006h,014h,007h,01Ah,023h,00Ch,01Ah,008h
        defb 009h,015h,021h,02Dh,00Fh,011h,013h,01Ah,006h,013h,020h,02Dh,010h,013h,016h,019h
        defb 023h,011h,01Fh,02Dh,031h,015h,019h,01Dh,020h,02Fh,01Eh,02Dh,032h,017h,01Ch,021h
        defb 013h,023h,033h,023h,029h,00Fh,015h,01Bh,006h,017h,028h,019h,020h,027h,00Eh,015h
        defb 019h,00Bh,01Dh,00Fh,017h,01Fh,007h,014h,011h,01Fh,012h,025h,00Eh,017h,005h,013h
        defb 014h,020h,00Ch,018h,01Ah,01Ch,01Eh,005h,011h,01Eh,02Bh,018h,01Bh,01Eh,021h,004h
        defb 00Eh,01Ch,02Ah,038h,01Ch,020h,024h,008h,02Bh,01Ah,029h,038h,01Dh,022h,027h,00Ch
        defb 01Eh,02Eh,01Eh,02Eh,014h,01Ah,020h,006h,011h,022h,013h,024h,02Bh,012h,019h,000h
        defb 004h,016h,028h,01Ah,022h,00Ah,012h,01Fh,01Ch,00Ah,01Dh,010h,019h,002h,010h,01Eh
        defb 01Fh,00Bh,017h,023h,025h,007h,009h,010h,01Ch,029h,016h,023h,026h,029h,00Ch,00Fh
        defb 019h,027h,015h,023h,027h,02Bh,00Fh,013h,016h,025h,034h,023h,028h,02Dh,012h,017h
        defb 029h,019h,029h,019h,01Fh,025h,00Bh,011h,01Ch,00Dh,01Eh,02Fh,016h,01Dh,024h,00Bh
        defb 00Fh,021h,013h,025h,00Dh,015h,01Dh,00Ah,007h,015h,008h,01Bh,024h,00Dh,01Bh,009h

Z180Neuro26:
        defb 00Ch,018h,024h,010h,012h,014h,016h,01Dh,009h,016h,023h,030h,013h,016h,019h,01Ch
        defb 026h,014h,022h,030h,014h,018h,01Ch,020h,023h,032h,021h,030h,035h,01Ah,01Fh,024h
        defb 016h,026h,016h,026h,02Ch,012h,018h,01Eh,009h,01Ah,02Bh,01Ch,023h,00Ah,011h,018h
        defb 01Ch,00Eh,020h,012h,01Ah,022h,00Ah,017h,014h,002h,015h,028h,011h,01Ah,008h,016h
        defb 017h,023h,00Fh,01Bh,01Dh,01Fh,001h,008h,014h,021h,02Eh,01Bh,01Eh,021h,024h,007h
        defb 011h,01Fh,02Dh,01Bh,01Fh,023h,027h,00Bh,02Eh,01Dh,02Ch,03Bh,020h,025h,02Ah,00Fh
        defb 021h,011h,021h,031h,017h,01Dh,023h,009h,014h,025h,016h,027h,02Eh,015h,01Ch,003h
        defb 007h,019h,00Bh,01Dh,025h,00Dh,015h,002h,01Fh,00Dh,020h,013h,01Ch,005h,013h,001h
        defb 002h,00Eh,01Ah,026h,028h,00Ah,00Ch,013h,01Fh,00Ch,019h,026h,029h,00Ch,00Fh,012h
        defb 01Ch,02Ah,018h,026h,02Ah,02Eh,012h,016h,019h,028h,037h,026h,02Bh,030h,015h,01Ah
        defb 00Ch,01Ch,02Ch,01Ch,022h,028h,00Eh,014h,01Fh,010h,021h,032h,019h,020h,007h,00Eh
        defb 012h,024h,016h,028h,010h,018h,000h,00Dh,00Ah,018h,00Bh,01Eh,007h,010h,01Eh,00Ch
        defb 00Dh,019h,025h,011h,013h,015h,017h,01Eh,00Ah,017h,024h,031h,014h,017h,01Ah,01Dh
        defb 027h,015h,023h,031h,015h,019h,01Dh,021h,024h,033h,022h,031h,036h,01Bh,020h,025h
        defb 017h,027h,017h,027h,02Dh,013h,019h,01Fh,00Ah,01Bh,02Ch,01Dh,024h,00Bh,012h,019h
        defb 01Dh,00Fh,021h,013h,01Bh,023h,00Bh,018h,015h,003h,016h,029h,012h,01Bh,009h,017h

Z180Neuro27:
        defb 01Ah,006h,012h,01Eh,020h,022h,004h,00Bh,017h,024h,011h,01Eh,021h,024h,007h,00Ah
        defb 014h,022h,030h,01Eh,022h,026h,00Ah,00Eh,011h,020h,02Fh,01Eh,023h,028h,02Dh,012h
        defb 024h,014h,024h,034h,01Ah,020h,026h,00Ch,017h,028h,019h,02Ah,011h,018h,01Fh,006h
        defb 00Ah,01Ch,00Eh,020h,028h,010h,018h,005h,002h,010h,023h,016h,01Fh,008h,016h,004h
        defb 005h,011h,01Dh,029h,00Bh,00Dh,00Fh,016h,022h,00Fh,01Ch,029h,02Ch,00Fh,012h,015h
        defb 01Fh,02Dh,01Bh,029h,02Dh,011h,015h,019h,01Ch,02Bh,01Ah,029h,02Eh,033h,018h,01Dh
        defb 00Fh,01Fh,02Fh,01Fh,025h,02Bh,011h,017h,022h,013h,024h,015h,01Ch,023h,00Ah,011h
        defb 015h,007h,019h,02Bh,013h,01Bh,003h,010h,00Dh,01Bh,00Eh,021h,00Ah,013h,001h,00Fh
        defb 010h,01Ch,028h,014h,016h,018h,01Ah,001h,00Dh,01Ah,027h,014h,017h,01Ah,01Dh,000h
        defb 00Ah,018h,026h,034h,018h,01Ch,020h,024h,027h,016h,025h,034h,019h,01Eh,023h,028h
        defb 01Ah,02Ah,01Ah,02Ah,030h,016h,01Ch,022h,00Dh,01Eh,00Fh,020h,027h,00Eh,015h,01Ch
        defb 000h,012h,024h,016h,01Eh,006h,00Eh,01Bh,018h,006h,019h,00Ch,015h,01Eh,00Ch,01Ah
        defb 01Bh,007h,013h,01Fh,021h,023h,005h,00Ch,018h,025h,012h,01Fh,022h,025h,008h,00Bh
        defb 015h,023h,031h,01Fh,023h,027h,00Bh,00Fh,012h,021h,030h,01Fh,024h,029h,02Eh,013h
        defb 025h,015h,025h,035h,01Bh,021h,027h,00Dh,018h,029h,01Ah,02Bh,012h,019h,020h,007h
        defb 00Bh,01Dh,00Fh,021h,029h,011h,019h,006h,003h,011h,024h,017h,020h,009h,017h,005h

Z180Neuro28:
        defb 008h,014h,020h,02Ch,00Eh,010h,012h,019h,005h,012h,01Fh,02Ch,00Fh,012h,015h,018h
        defb 022h,010h,01Eh,02Ch,030h,014h,018h,01Ch,01Fh,02Eh,01Dh,02Ch,031h,016h,01Bh,020h
        defb 012h,022h,032h,022h,028h,02Eh,014h,01Ah,005h,016h,027h,018h,01Fh,026h,00Dh,014h
        defb 018h,00Ah,01Ch,02Eh,016h,01Eh,006h,013h,010h,01Eh,011h,024h,00Dh,016h,004h,012h
        defb 013h,01Fh,00Bh,017h,019h,01Bh,01Dh,004h,010h,01Dh,02Ah,017h,01Ah,01Dh,020h,003h
        defb 00Dh,01Bh,029h,037h,01Bh,01Fh,023h,007h,02Ah,019h,028h,037h,01Ch,021h,026h,00Bh
        defb 01Dh,02Dh,01Dh,02Dh,033h,019h,01Fh,005h,010h,021h,012h,023h,02Ah,011h,018h,01Fh
        defb 003h,015h,027h,019h,021h,009h,011h,01Eh,01Bh,009h,01Ch,00Fh,018h,001h,00Fh,01Dh
        defb 01Eh,00Ah,016h,022h,024h,006h,008h,00Fh,01Bh,028h,015h,022h,025h,028h,00Bh,00Eh
        defb 018h,026h,014h,022h,026h,02Ah,00Eh,012h,015h,024h,033h,022h,027h,02Ch,011h,016h
        defb 028h,018h,028h,038h,01Eh,024h,00Ah,010h,01Bh,00Ch,01Dh,02Eh,015h,01Ch,023h,00Ah
        defb 00Eh,020h,012h,024h,00Ch,014h,01Ch,009h,006h,014h,007h,01Ah,023h,00Ch,01Ah,008h
        defb 009h,015h,021h,02Dh,00Fh,011h,013h,01Ah,006h,013h,020h,02Dh,010h,013h,016h,019h
        defb 023h,011h,01Fh,02Dh,031h,015h,019h,01Dh,020h,02Fh,01Eh,02Dh,032h,017h,01Ch,021h
        defb 013h,023h,033h,023h,029h,00Fh,015h,01Bh,006h,017h,028h,019h,020h,027h,00Eh,015h
        defb 019h,00Bh,01Dh,00Fh,017h,01Fh,007h,014h,011h,01Fh,012h,025h,00Eh,017h,005h,013h

Z180Neuro29:
        defb 016h,022h,00Eh,01Ah,01Ch,01Eh,000h,007h,013h,020h,02Dh,01Ah,01Dh,020h,023h,006h
        defb 010h,01Eh,02Ch,01Ah,01Eh,022h,026h,00Ah,02Dh,01Ch,02Bh,03Ah,01Fh,024h,029h,00Eh
        defb 020h,010h,020h,030h,016h,01Ch,022h,008h,013h,024h,015h,026h,02Dh,014h,01Bh,002h
        defb 006h,018h,00Ah,01Ch,024h,00Ch,014h,001h,01Eh,00Ch,01Fh,012h,01Bh,004h,012h,000h
        defb 001h,00Dh,019h,025h,027h,009h,00Bh,012h,01Eh,00Bh,018h,025h,028h,00Bh,00Eh,011h
        defb 01Bh,029h,017h,025h,029h,02Dh,011h,015h,018h,027h,036h,025h,02Ah,02Fh,014h,019h
        defb 00Bh,01Bh,02Bh,01Bh,021h,027h,00Dh,013h,01Eh,00Fh,020h,031h,018h,01Fh,006h,00Dh
        defb 011h,023h,015h,027h,00Fh,017h,01Fh,00Ch,009h,017h,00Ah,01Dh,006h,00Fh,01Dh,00Bh
        defb 00Ch,018h,024h,010h,012h,014h,016h,01Dh,009h,016h,023h,030h,013h,016h,019h,01Ch
        defb 026h,014h,022h,030h,014h,018h,01Ch,020h,023h,032h,021h,030h,035h,01Ah,01Fh,024h
        defb 016h,026h,016h,026h,02Ch,012h,018h,01Eh,009h,01Ah,02Bh,01Ch,023h,00Ah,011h,018h
        defb 01Ch,00Eh,020h,012h,01Ah,022h,00Ah,017h,014h,002h,015h,028h,011h,01Ah,008h,016h
        defb 017h,023h,00Fh,01Bh,01Dh,01Fh,001h,008h,014h,021h,02Eh,01Bh,01Eh,021h,024h,007h
        defb 011h,01Fh,02Dh,01Bh,01Fh,023h,027h,00Bh,02Eh,01Dh,02Ch,03Bh,020h,025h,02Ah,00Fh
        defb 021h,011h,021h,031h,017h,01Dh,023h,009h,014h,025h,016h,027h,02Eh,015h,01Ch,003h
        defb 007h,019h,00Bh,01Dh,025h,00Dh,015h,002h,01Fh,00Dh,020h,013h,01Ch,005h,013h,001h

Z180Neuro30:
        defb 004h,010h,01Ch,028h,00Ah,00Ch,00Eh,015h,021h,00Eh,01Bh,028h,02Bh,00Eh,011h,014h
        defb 01Eh,02Ch,01Ah,028h,02Ch,010h,014h,018h,01Bh,02Ah,019h,028h,02Dh,032h,017h,01Ch
        defb 00Eh,01Eh,02Eh,01Eh,024h,02Ah,010h,016h,021h,012h,023h,014h,01Bh,022h,009h,010h
        defb 014h,006h,018h,02Ah,012h,01Ah,002h,00Fh,00Ch,01Ah,00Dh,020h,009h,012h,000h,00Eh
        defb 00Fh,01Bh,027h,013h,015h,017h,019h,000h,00Ch,019h,026h,033h,016h,019h,01Ch,01Fh
        defb 029h,017h,025h,033h,017h,01Bh,01Fh,023h,026h,015h,024h,033h,038h,01Dh,022h,027h
        defb 019h,029h,019h,029h,02Fh,015h,01Bh,021h,00Ch,01Dh,02Eh,01Fh,026h,00Dh,014h,01Bh
        defb 01Fh,011h,023h,015h,01Dh,005h,00Dh,01Ah,017h,005h,018h,00Bh,014h,01Dh,00Bh,019h
        defb 01Ah,006h,012h,01Eh,020h,022h,004h,00Bh,017h,024h,011h,01Eh,021h,024h,007h,00Ah
        defb 014h,022h,030h,01Eh,022h,026h,00Ah,00Eh,011h,020h,02Fh,01Eh,023h,028h,02Dh,012h
        defb 024h,014h,024h,034h,01Ah,020h,026h,00Ch,017h,028h,019h,02Ah,011h,018h,01Fh,006h
        defb 00Ah,01Ch,00Eh,020h,028h,010h,018h,005h,002h,010h,023h,016h,01Fh,008h,016h,004h
        defb 005h,011h,01Dh,029h,00Bh,00Dh,00Fh,016h,022h,00Fh,01Ch,029h,02Ch,00Fh,012h,015h
        defb 01Fh,02Dh,01Bh,029h,02Dh,011h,015h,019h,01Ch,02Bh,01Ah,029h,02Eh,033h,018h,01Dh
        defb 00Fh,01Fh,02Fh,01Fh,025h,02Bh,011h,017h,022h,013h,024h,015h,01Ch,023h,00Ah,011h
        defb 015h,007h,019h,02Bh,013h,01Bh,003h,010h,00Dh,01Bh,00Eh,021h,00Ah,013h,001h,00Fh

Z180Neuro31:
        defb 012h,01Eh,00Ah,016h,018h,01Ah,01Ch,003h,00Fh,01Ch,029h,016h,019h,01Ch,01Fh,002h
        defb 00Ch,01Ah,028h,036h,01Ah,01Eh,022h,006h,029h,018h,027h,036h,01Bh,020h,025h,00Ah
        defb 01Ch,02Ch,01Ch,02Ch,032h,018h,01Eh,024h,00Fh,020h,011h,022h,029h,010h,017h,01Eh
        defb 002h,014h,026h,018h,020h,008h,010h,01Dh,01Ah,008h,01Bh,00Eh,017h,000h,00Eh,01Ch
        defb 01Dh,009h,015h,021h,023h,005h,007h,00Eh,01Ah,027h,014h,021h,024h,027h,00Ah,00Dh
        defb 017h,025h,033h,021h,025h,029h,00Dh,011h,014h,023h,032h,021h,026h,02Bh,010h,015h
        defb 027h,017h,027h,037h,01Dh,023h,029h,00Fh,01Ah,00Bh,01Ch,02Dh,014h,01Bh,022h,009h
        defb 00Dh,01Fh,011h,023h,00Bh,013h,01Bh,008h,005h,013h,006h,019h,022h,00Bh,019h,007h
        defb 008h,014h,020h,02Ch,00Eh,010h,012h,019h,005h,012h,01Fh,02Ch,00Fh,012h,015h,018h
        defb 022h,010h,01Eh,02Ch,030h,014h,018h,01Ch,01Fh,02Eh,01Dh,02Ch,031h,016h,01Bh,020h
        defb 012h,022h,032h,022h,028h,02Eh,014h,01Ah,005h,016h,027h,018h,01Fh,026h,00Dh,014h
        defb 018h,00Ah,01Ch,02Eh,016h,01Eh,006h,013h,010h,01Eh,011h,024h,00Dh,016h,004h,012h
        defb 013h,01Fh,00Bh,017h,019h,01Bh,01Dh,004h,010h,01Dh,02Ah,017h,01Ah,01Dh,020h,003h
        defb 00Dh,01Bh,029h,037h,01Bh,01Fh,023h,007h,02Ah,019h,028h,037h,01Ch,021h,026h,00Bh
        defb 01Dh,02Dh,01Dh,02Dh,033h,019h,01Fh,005h,010h,021h,012h,023h,02Ah,011h,018h,01Fh
        defb 003h,015h,027h,019h,021h,009h,011h,01Eh,01Bh,009h,01Ch,00Fh,018h,001h,00Fh,01Dh

Z180Neuro32:
        defb 000h,00Ch,018h,024h,026h,008h,00Ah,011h,01Dh,00Ah,017h,024h,027h,00Ah,00Dh,010h
        defb 01Ah,028h,016h,024h,028h,02Ch,010h,014h,017h,026h,035h,024h,029h,02Eh,013h,018h
        defb 00Ah,01Ah,02Ah,01Ah,020h,026h,00Ch,012h,01Dh,00Eh,01Fh,030h,017h,01Eh,005h,00Ch
        defb 010h,022h,014h,026h,00Eh,016h,01Eh,00Bh,008h,016h,009h,01Ch,005h,00Eh,01Ch,00Ah
        defb 00Bh,017h,023h,00Fh,011h,013h,015h,01Ch,008h,015h,022h,02Fh,012h,015h,018h,01Bh
        defb 025h,013h,021h,02Fh,033h,017h,01Bh,01Fh,022h,031h,020h,02Fh,034h,019h,01Eh,023h
        defb 015h,025h,015h,025h,02Bh,011h,017h,01Dh,008h,019h,02Ah,01Bh,022h,029h,010h,017h
        defb 01Bh,00Dh,01Fh,011h,019h,021h,009h,016h,013h,001h,014h,027h,010h,019h,007h,015h
        defb 016h,022h,00Eh,01Ah,01Ch,01Eh,000h,007h,013h,020h,02Dh,01Ah,01Dh,020h,023h,006h
        defb 010h,01Eh,02Ch,01Ah,01Eh,022h,026h,00Ah,02Dh,01Ch,02Bh,03Ah,01Fh,024h,029h,00Eh
        defb 020h,010h,020h,030h,016h,01Ch,022h,008h,013h,024h,015h,026h,02Dh,014h,01Bh,002h
        defb 006h,018h,00Ah,01Ch,024h,00Ch,014h,001h,01Eh,00Ch,01Fh,012h,01Bh,004h,012h,000h
        defb 001h,00Dh,019h,025h,027h,009h,00Bh,012h,01Eh,00Bh,018h,025h,028h,00Bh,00Eh,011h
        defb 01Bh,029h,017h,025h,029h,02Dh,011h,015h,018h,027h,036h,025h,02Ah,02Fh,014h,019h
        defb 00Bh,01Bh,02Bh,01Bh,021h,027h,00Dh,013h,01Eh,00Fh,020h,031h,018h,01Fh,006h,00Dh
        defb 011h,023h,015h,027h,00Fh,017h,01Fh,00Ch,009h,017h,00Ah,01Dh,006h,00Fh,01Dh,00Bh

Z180Neuro33:
        defb 00Eh,01Ah,026h,012h,014h,016h,018h,01Fh,00Bh,018h,025h,032h,015h,018h,01Bh,01Eh
        defb 028h,016h,024h,032h,016h,01Ah,01Eh,022h,025h,014h,023h,032h,037h,01Ch,021h,026h
        defb 018h,028h,018h,028h,02Eh,014h,01Ah,020h,00Bh,01Ch,02Dh,01Eh,025h,00Ch,013h,01Ah
        defb 01Eh,010h,022h,014h,01Ch,024h,00Ch,019h,016h,004h,017h,00Ah,013h,01Ch,00Ah,018h
        defb 019h,005h,011h,01Dh,01Fh,021h,003h,00Ah,016h,023h,010h,01Dh,020h,023h,006h,009h
        defb 013h,021h,02Fh,01Dh,021h,025h,029h,00Dh,010h,01Fh,02Eh,03Dh,022h,027h,02Ch,011h
        defb 023h,013h,023h,033h,019h,01Fh,025h,00Bh,016h,027h,018h,029h,010h,017h,01Eh,005h
        defb 009h,01Bh,00Dh,01Fh,027h,00Fh,017h,004h,001h,00Fh,022h,015h,01Eh,007h,015h,003h
        defb 004h,010h,01Ch,028h,00Ah,00Ch,00Eh,015h,021h,00Eh,01Bh,028h,02Bh,00Eh,011h,014h
        defb 01Eh,02Ch,01Ah,028h,02Ch,010h,014h,018h,01Bh,02Ah,019h,028h,02Dh,032h,017h,01Ch
        defb 00Eh,01Eh,02Eh,01Eh,024h,02Ah,010h,016h,021h,012h,023h,014h,01Bh,022h,009h,010h
        defb 014h,006h,018h,02Ah,012h,01Ah,002h,00Fh,00Ch,01Ah,00Dh,020h,009h,012h,000h,00Eh
        defb 00Fh,01Bh,027h,013h,015h,017h,019h,000h,00Ch,019h,026h,033h,016h,019h,01Ch,01Fh
        defb 029h,017h,025h,033h,017h,01Bh,01Fh,023h,026h,015h,024h,033h,038h,01Dh,022h,027h
        defb 019h,029h,019h,029h,02Fh,015h,01Bh,021h,00Ch,01Dh,02Eh,01Fh,026h,00Dh,014h,01Bh
        defb 01Fh,011h,023h,015h,01Dh,005h,00Dh,01Ah,017h,005h,018h,00Bh,014h,01Dh,00Bh,019h

Z180Neuro34:
        defb 01Ch,008h,014h,020h,022h,024h,006h,00Dh,019h,026h,013h,020h,023h,026h,009h,00Ch
        defb 016h,024h,032h,020h,024h,028h,00Ch,010h,013h,022h,031h,020h,025h,02Ah,00Fh,014h
        defb 026h,016h,026h,036h,01Ch,022h,028h,00Eh,019h,00Ah,01Bh,02Ch,013h,01Ah,021h,008h
        defb 00Ch,01Eh,010h,022h,00Ah,012h,01Ah,007h,004h,012h,005h,018h,021h,00Ah,018h,006h
        defb 007h,013h,01Fh,02Bh,00Dh,00Fh,011h,018h,024h,011h,01Eh,02Bh,02Eh,011h,014h,017h
        defb 021h,00Fh,01Dh,02Bh,02Fh,013h,017h,01Bh,01Eh,02Dh,01Ch,02Bh,030h,015h,01Ah,01Fh
        defb 011h,021h,031h,021h,027h,02Dh,013h,019h,024h,015h,026h,017h,01Eh,025h,00Ch,013h
        defb 017h,009h,01Bh,02Dh,015h,01Dh,005h,012h,00Fh,01Dh,010h,023h,00Ch,015h,003h,011h
        defb 012h,01Eh,00Ah,016h,018h,01Ah,01Ch,003h,00Fh,01Ch,029h,016h,019h,01Ch,01Fh,002h
        defb 00Ch,01Ah,028h,036h,01Ah,01Eh,022h,006h,029h,018h,027h,036h,01Bh,020h,025h,00Ah
        defb 01Ch,02Ch,01Ch,02Ch,032h,018h,01Eh,024h,00Fh,020h,011h,022h,029h,010h,017h,01Eh
        defb 002h,014h,026h,018h,020h,008h,010h,01Dh,01Ah,008h,01Bh,00Eh,017h,000h,00Eh,01Ch
        defb 01Dh,009h,015h,021h,023h,005h,007h,00Eh,01Ah,027h,014h,021h,024h,027h,00Ah,00Dh
        defb 017h,025h,033h,021h,025h,029h,00Dh,011h,014h,023h,032h,021h,026h,02Bh,010h,015h
        defb 027h,017h,027h,037h,01Dh,023h,029h,00Fh,01Ah,00Bh,01Ch,02Dh,014h,01Bh,022h,009h
        defb 00Dh,01Fh,011h,023h,00Bh,013h,01Bh,008h,005h,013h,006h,019h,022h,00Bh,019h,007h

Z180Neuro35:
        defb 00Ah,016h,022h,02Eh,010h,012h,014h,01Bh,007h,014h,021h,02Eh,011h,014h,017h,01Ah
        defb 024h,012h,020h,02Eh,032h,016h,01Ah,01Eh,021h,030h,01Fh,02Eh,033h,018h,01Dh,022h
        defb 014h,024h,014h,024h,02Ah,010h,016h,01Ch,007h,018h,029h,01Ah,021h,028h,00Fh,016h
        defb 01Ah,00Ch,01Eh,010h,018h,020h,008h,015h,012h,000h,013h,026h,00Fh,018h,006h,014h
        defb 015h,021h,00Dh,019h,01Bh,01Dh,01Fh,006h,012h,01Fh,02Ch,019h,01Ch,01Fh,022h,005h
        defb 00Fh,01Dh,02Bh,019h,01Dh,021h,025h,009h,02Ch,01Bh,02Ah,039h,01Eh,023h,028h,00Dh
        defb 01Fh,00Fh,01Fh,02Fh,015h,01Bh,021h,007h,012h,023h,014h,025h,02Ch,013h,01Ah,001h
        defb 005h,017h,029h,01Bh,023h,00Bh,013h,000h,01Dh,00Bh,01Eh,011h,01Ah,003h,011h,01Fh
        defb 000h,00Ch,018h,024h,026h,008h,00Ah,011h,01Dh,00Ah,017h,024h,027h,00Ah,00Dh,010h
        defb 01Ah,028h,016h,024h,028h,02Ch,010h,014h,017h,026h,035h,024h,029h,02Eh,013h,018h
        defb 00Ah,01Ah,02Ah,01Ah,020h,026h,00Ch,012h,01Dh,00Eh,01Fh,030h,017h,01Eh,005h,00Ch
        defb 010h,022h,014h,026h,00Eh,016h,01Eh,00Bh,008h,016h,009h,01Ch,005h,00Eh,01Ch,00Ah
        defb 00Bh,017h,023h,00Fh,011h,013h,015h,01Ch,008h,015h,022h,02Fh,012h,015h,018h,01Bh
        defb 025h,013h,021h,02Fh,033h,017h,01Bh,01Fh,022h,031h,020h,02Fh,034h,019h,01Eh,023h
        defb 015h,025h,015h,025h,02Bh,011h,017h,01Dh,008h,019h,02Ah,01Bh,022h,029h,010h,017h
        defb 01Bh,00Dh,01Fh,011h,019h,021h,009h,016h,013h,001h,014h,027h,010h,019h,007h,015h

Z180Neuro36:
        defb 018h,024h,010h,01Ch,01Eh,020h,002h,009h,015h,022h,00Fh,01Ch,01Fh,022h,005h,008h
        defb 012h,020h,02Eh,01Ch,020h,024h,028h,00Ch,00Fh,01Eh,02Dh,03Ch,021h,026h,02Bh,010h
        defb 022h,012h,022h,032h,018h,01Eh,024h,00Ah,015h,026h,017h,028h,00Fh,016h,01Dh,004h
        defb 008h,01Ah,00Ch,01Eh,026h,00Eh,016h,003h,000h,00Eh,021h,014h,01Dh,006h,014h,002h
        defb 003h,00Fh,01Bh,027h,029h,00Bh,00Dh,014h,020h,00Dh,01Ah,027h,02Ah,00Dh,010h,013h
        defb 01Dh,02Bh,019h,027h,02Bh,00Fh,013h,017h,01Ah,029h,038h,027h,02Ch,031h,016h,01Bh
        defb 00Dh,01Dh,02Dh,01Dh,023h,029h,00Fh,015h,020h,011h,022h,033h,01Ah,021h,008h,00Fh
        defb 013h,005h,017h,029h,011h,019h,001h,00Eh,00Bh,019h,00Ch,01Fh,008h,011h,01Fh,00Dh
        defb 00Eh,01Ah,026h,012h,014h,016h,018h,01Fh,00Bh,018h,025h,032h,015h,018h,01Bh,01Eh
        defb 028h,016h,024h,032h,016h,01Ah,01Eh,022h,025h,014h,023h,032h,037h,01Ch,021h,026h
        defb 018h,028h,018h,028h,02Eh,014h,01Ah,020h,00Bh,01Ch,02Dh,01Eh,025h,00Ch,013h,01Ah
        defb 01Eh,010h,022h,014h,01Ch,024h,00Ch,019h,016h,004h,017h,00Ah,013h,01Ch,00Ah,018h
        defb 019h,005h,011h,01Dh,01Fh,021h,003h,00Ah,016h,023h,010h,01Dh,020h,023h,006h,009h
        defb 013h,021h,02Fh,01Dh,021h,025h,029h,00Dh,010h,01Fh,02Eh,03Dh,022h,027h,02Ch,011h
        defb 023h,013h,023h,033h,019h,01Fh,025h,00Bh,016h,027h,018h,029h,010h,017h,01Eh,005h
        defb 009h,01Bh,00Dh,01Fh,027h,00Fh,017h,004h,001h,00Fh,022h,015h,01Eh,007h,015h,003h

Z180Neuro37:
        defb 006h,012h,01Eh,02Ah,00Ch,00Eh,010h,017h,023h,010h,01Dh,02Ah,02Dh,010h,013h,016h
        defb 020h,02Eh,01Ch,02Ah,02Eh,012h,016h,01Ah,01Dh,02Ch,01Bh,02Ah,02Fh,014h,019h,01Eh
        defb 010h,020h,030h,020h,026h,02Ch,012h,018h,023h,014h,025h,016h,01Dh,024h,00Bh,012h
        defb 016h,008h,01Ah,02Ch,014h,01Ch,004h,011h,00Eh,01Ch,00Fh,022h,00Bh,014h,002h,010h
        defb 011h,01Dh,029h,015h,017h,019h,01Bh,002h,00Eh,01Bh,028h,015h,018h,01Bh,01Eh,001h
        defb 00Bh,019h,027h,035h,019h,01Dh,021h,005h,028h,017h,026h,035h,01Ah,01Fh,024h,029h
        defb 01Bh,02Bh,01Bh,02Bh,031h,017h,01Dh,023h,00Eh,01Fh,010h,021h,028h,00Fh,016h,01Dh
        defb 001h,013h,025h,017h,01Fh,007h,00Fh,01Ch,019h,007h,01Ah,00Dh,016h,01Fh,00Dh,01Bh
        defb 01Ch,008h,014h,020h,022h,024h,006h,00Dh,019h,026h,013h,020h,023h,026h,009h,00Ch
        defb 016h,024h,032h,020h,024h,028h,00Ch,010h,013h,022h,031h,020h,025h,02Ah,00Fh,014h
        defb 026h,016h,026h,036h,01Ch,022h,028h,00Eh,019h,00Ah,01Bh,02Ch,013h,01Ah,021h,008h
        defb 00Ch,01Eh,010h,022h,00Ah,012h,01Ah,007h,004h,012h,005h,018h,021h,00Ah,018h,006h
        defb 007h,013h,01Fh,02Bh,00Dh,00Fh,011h,018h,024h,011h,01Eh,02Bh,02Eh,011h,014h,017h
        defb 021h,00Fh,01Dh,02Bh,02Fh,013h,017h,01Bh,01Eh,02Dh,01Ch,02Bh,030h,015h,01Ah,01Fh
        defb 011h,021h,031h,021h,027h,02Dh,013h,019h,024h,015h,026h,017h,01Eh,025h,00Ch,013h
        defb 017h,009h,01Bh,02Dh,015h,01Dh,005h,012h,00Fh,01Dh,010h,023h,00Ch,015h,003h,011h

Z180Neuro38:
        defb 014h,020h,00Ch,018h,01Ah,01Ch,01Eh,005h,011h,01Eh,02Bh,018h,01Bh,01Eh,021h,004h
        defb 00Eh,01Ch,02Ah,038h,01Ch,020h,024h,008h,02Bh,01Ah,029h,038h,01Dh,022h,027h,00Ch
        defb 01Eh,02Eh,01Eh,02Eh,014h,01Ah,020h,006h,011h,022h,013h,024h,02Bh,012h,019h,000h
        defb 004h,016h,028h,01Ah,022h,00Ah,012h,01Fh,01Ch,00Ah,01Dh,010h,019h,002h,010h,01Eh
        defb 01Fh,00Bh,017h,023h,025h,007h,009h,010h,01Ch,029h,016h,023h,026h,029h,00Ch,00Fh
        defb 019h,027h,015h,023h,027h,02Bh,00Fh,013h,016h,025h,034h,023h,028h,02Dh,012h,017h
        defb 029h,019h,029h,019h,01Fh,025h,00Bh,011h,01Ch,00Dh,01Eh,02Fh,016h,01Dh,024h,00Bh
        defb 00Fh,021h,013h,025h,00Dh,015h,01Dh,00Ah,007h,015h,008h,01Bh,024h,00Dh,01Bh,009h
        defb 00Ah,016h,022h,02Eh,010h,012h,014h,01Bh,007h,014h,021h,02Eh,011h,014h,017h,01Ah
        defb 024h,012h,020h,02Eh,032h,016h,01Ah,01Eh,021h,030h,01Fh,02Eh,033h,018h,01Dh,022h
        defb 014h,024h,014h,024h,02Ah,010h,016h,01Ch,007h,018h,029h,01Ah,021h,028h,00Fh,016h
        defb 01Ah,00Ch,01Eh,010h,018h,020h,008h,015h,012h,000h,013h,026h,00Fh,018h,006h,014h
        defb 015h,021h,00Dh,019h,01Bh,01Dh,01Fh,006h,012h,01Fh,02Ch,019h,01Ch,01Fh,022h,005h
        defb 00Fh,01Dh,02Bh,019h,01Dh,021h,025h,009h,02Ch,01Bh,02Ah,039h,01Eh,023h,028h,00Dh
        defb 01Fh,00Fh,01Fh,02Fh,015h,01Bh,021h,007h,012h,023h,014h,025h,02Ch,013h,01Ah,001h
        defb 005h,017h,029h,01Bh,023h,00Bh,013h,000h,01Dh,00Bh,01Eh,011h,01Ah,003h,011h,01Fh

Z180Neuro39:
        defb 002h,00Eh,01Ah,026h,028h,00Ah,00Ch,013h,01Fh,00Ch,019h,026h,029h,00Ch,00Fh,012h
        defb 01Ch,02Ah,018h,026h,02Ah,02Eh,012h,016h,019h,028h,037h,026h,02Bh,030h,015h,01Ah
        defb 00Ch,01Ch,02Ch,01Ch,022h,028h,00Eh,014h,01Fh,010h,021h,032h,019h,020h,007h,00Eh
        defb 012h,024h,016h,028h,010h,018h,000h,00Dh,00Ah,018h,00Bh,01Eh,007h,010h,01Eh,00Ch
        defb 00Dh,019h,025h,011h,013h,015h,017h,01Eh,00Ah,017h,024h,031h,014h,017h,01Ah,01Dh
        defb 027h,015h,023h,031h,015h,019h,01Dh,021h,024h,033h,022h,031h,036h,01Bh,020h,025h
        defb 017h,027h,017h,027h,02Dh,013h,019h,01Fh,00Ah,01Bh,02Ch,01Dh,024h,00Bh,012h,019h
        defb 01Dh,00Fh,021h,013h,01Bh,023h,00Bh,018h,015h,003h,016h,029h,012h,01Bh,009h,017h
        defb 018h,024h,010h,01Ch,01Eh,020h,002h,009h,015h,022h,00Fh,01Ch,01Fh,022h,005h,008h
        defb 012h,020h,02Eh,01Ch,020h,024h,028h,00Ch,00Fh,01Eh,02Dh,03Ch,021h,026h,02Bh,010h
        defb 022h,012h,022h,032h,018h,01Eh,024h,00Ah,015h,026h,017h,028h,00Fh,016h,01Dh,004h
        defb 008h,01Ah,00Ch,01Eh,026h,00Eh,016h,003h,000h,00Eh,021h,014h,01Dh,006h,014h,002h
        defb 003h,00Fh,01Bh,027h,029h,00Bh,00Dh,014h,020h,00Dh,01Ah,027h,02Ah,00Dh,010h,013h
        defb 01Dh,02Bh,019h,027h,02Bh,00Fh,013h,017h,01Ah,029h,038h,027h,02Ch,031h,016h,01Bh
        defb 00Dh,01Dh,02Dh,01Dh,023h,029h,00Fh,015h,020h,011h,022h,033h,01Ah,021h,008h,00Fh
        defb 013h,005h,017h,029h,011h,019h,001h,00Eh,00Bh,019h,00Ch,01Fh,008h,011h,01Fh,00Dh

Z180Neuro40:
        defb 010h,01Ch,028h,014h,016h,018h,01Ah,001h,00Dh,01Ah,027h,014h,017h,01Ah,01Dh,000h
        defb 00Ah,018h,026h,034h,018h,01Ch,020h,024h,027h,016h,025h,034h,019h,01Eh,023h,028h
        defb 01Ah,02Ah,01Ah,02Ah,030h,016h,01Ch,022h,00Dh,01Eh,00Fh,020h,027h,00Eh,015h,01Ch
        defb 000h,012h,024h,016h,01Eh,006h,00Eh,01Bh,018h,006h,019h,00Ch,015h,01Eh,00Ch,01Ah
        defb 01Bh,007h,013h,01Fh,021h,023h,005h,00Ch,018h,025h,012h,01Fh,022h,025h,008h,00Bh
        defb 015h,023h,031h,01Fh,023h,027h,00Bh,00Fh,012h,021h,030h,01Fh,024h,029h,02Eh,013h
        defb 025h,015h,025h,035h,01Bh,021h,027h,00Dh,018h,029h,01Ah,02Bh,012h,019h,020h,007h
        defb 00Bh,01Dh,00Fh,021h,029h,011h,019h,006h,003h,011h,024h,017h,020h,009h,017h,005h
        defb 006h,012h,01Eh,02Ah,00Ch,00Eh,010h,017h,023h,010h,01Dh,02Ah,02Dh,010h,013h,016h
        defb 020h,02Eh,01Ch,02Ah,02Eh,012h,016h,01Ah,01Dh,02Ch,01Bh,02Ah,02Fh,014h,019h,01Eh
        defb 010h,020h,030h,020h,026h,02Ch,012h,018h,023h,014h,025h,016h,01Dh,024h,00Bh,012h
        defb 016h,008h,01Ah,02Ch,014h,01Ch,004h,011h,00Eh,01Ch,00Fh,022h,00Bh,014h,002h,010h
        defb 011h,01Dh,029h,015h,017h,019h,01Bh,002h,00Eh,01Bh,028h,015h,018h,01Bh,01Eh,001h
        defb 00Bh,019h,027h,035h,019h,01Dh,021h,005h,028h,017h,026h,035h,01Ah,01Fh,024h,029h
        defb 01Bh,02Bh,01Bh,02Bh,031h,017h,01Dh,023h,00Eh,01Fh,010h,021h,028h,00Fh,016h,01Dh
        defb 001h,013h,025h,017h,01Fh,007h,00Fh,01Ch,019h,007h,01Ah,00Dh,016h,01Fh,00Dh,01Bh

Z180Neuro41:
        defb 01Eh,00Ah,016h,022h,024h,006h,008h,00Fh,01Bh,028h,015h,022h,025h,028h,00Bh,00Eh
        defb 018h,026h,014h,022h,026h,02Ah,00Eh,012h,015h,024h,033h,022h,027h,02Ch,011h,016h
        defb 028h,018h,028h,038h,01Eh,024h,00Ah,010h,01Bh,00Ch,01Dh,02Eh,015h,01Ch,023h,00Ah
        defb 00Eh,020h,012h,024h,00Ch,014h,01Ch,009h,006h,014h,007h,01Ah,023h,00Ch,01Ah,008h
        defb 009h,015h,021h,02Dh,00Fh,011h,013h,01Ah,006h,013h,020h,02Dh,010h,013h,016h,019h
        defb 023h,011h,01Fh,02Dh,031h,015h,019h,01Dh,020h,02Fh,01Eh,02Dh,032h,017h,01Ch,021h
        defb 013h,023h,033h,023h,029h,00Fh,015h,01Bh,006h,017h,028h,019h,020h,027h,00Eh,015h
        defb 019h,00Bh,01Dh,00Fh,017h,01Fh,007h,014h,011h,01Fh,012h,025h,00Eh,017h,005h,013h
        defb 014h,020h,00Ch,018h,01Ah,01Ch,01Eh,005h,011h,01Eh,02Bh,018h,01Bh,01Eh,021h,004h
        defb 00Eh,01Ch,02Ah,038h,01Ch,020h,024h,008h,02Bh,01Ah,029h,038h,01Dh,022h,027h,00Ch
        defb 01Eh,02Eh,01Eh,02Eh,014h,01Ah,020h,006h,011h,022h,013h,024h,02Bh,012h,019h,000h
        defb 004h,016h,028h,01Ah,022h,00Ah,012h,01Fh,01Ch,00Ah,01Dh,010h,019h,002h,010h,01Eh
        defb 01Fh,00Bh,017h,023h,025h,007h,009h,010h,01Ch,029h,016h,023h,026h,029h,00Ch,00Fh
        defb 019h,027h,015h,023h,027h,02Bh,00Fh,013h,016h,025h,034h,023h,028h,02Dh,012h,017h
        defb 029h,019h,029h,019h,01Fh,025h,00Bh,011h,01Ch,00Dh,01Eh,02Fh,016h,01Dh,024h,00Bh
        defb 00Fh,021h,013h,025h,00Dh,015h,01Dh,00Ah,007h,015h,008h,01Bh,024h,00Dh,01Bh,009h

Z180Neuro42:
        defb 00Ch,018h,024h,010h,012h,014h,016h,01Dh,009h,016h,023h,030h,013h,016h,019h,01Ch
        defb 026h,014h,022h,030h,014h,018h,01Ch,020h,023h,032h,021h,030h,035h,01Ah,01Fh,024h
        defb 016h,026h,016h,026h,02Ch,012h,018h,01Eh,009h,01Ah,02Bh,01Ch,023h,00Ah,011h,018h
        defb 01Ch,00Eh,020h,012h,01Ah,022h,00Ah,017h,014h,002h,015h,028h,011h,01Ah,008h,016h
        defb 017h,023h,00Fh,01Bh,01Dh,01Fh,001h,008h,014h,021h,02Eh,01Bh,01Eh,021h,024h,007h
        defb 011h,01Fh,02Dh,01Bh,01Fh,023h,027h,00Bh,02Eh,01Dh,02Ch,03Bh,020h,025h,02Ah,00Fh
        defb 021h,011h,021h,031h,017h,01Dh,023h,009h,014h,025h,016h,027h,02Eh,015h,01Ch,003h
        defb 007h,019h,00Bh,01Dh,025h,00Dh,015h,002h,01Fh,00Dh,020h,013h,01Ch,005h,013h,001h
        defb 002h,00Eh,01Ah,026h,028h,00Ah,00Ch,013h,01Fh,00Ch,019h,026h,029h,00Ch,00Fh,012h
        defb 01Ch,02Ah,018h,026h,02Ah,02Eh,012h,016h,019h,028h,037h,026h,02Bh,030h,015h,01Ah
        defb 00Ch,01Ch,02Ch,01Ch,022h,028h,00Eh,014h,01Fh,010h,021h,032h,019h,020h,007h,00Eh
        defb 012h,024h,016h,028h,010h,018h,000h,00Dh,00Ah,018h,00Bh,01Eh,007h,010h,01Eh,00Ch
        defb 00Dh,019h,025h,011h,013h,015h,017h,01Eh,00Ah,017h,024h,031h,014h,017h,01Ah,01Dh
        defb 027h,015h,023h,031h,015h,019h,01Dh,021h,024h,033h,022h,031h,036h,01Bh,020h,025h
        defb 017h,027h,017h,027h,02Dh,013h,019h,01Fh,00Ah,01Bh,02Ch,01Dh,024h,00Bh,012h,019h
        defb 01Dh,00Fh,021h,013h,01Bh,023h,00Bh,018h,015h,003h,016h,029h,012h,01Bh,009h,017h

Z180Neuro43:
        defb 01Ah,006h,012h,01Eh,020h,022h,004h,00Bh,017h,024h,011h,01Eh,021h,024h,007h,00Ah
        defb 014h,022h,030h,01Eh,022h,026h,00Ah,00Eh,011h,020h,02Fh,01Eh,023h,028h,02Dh,012h
        defb 024h,014h,024h,034h,01Ah,020h,026h,00Ch,017h,028h,019h,02Ah,011h,018h,01Fh,006h
        defb 00Ah,01Ch,00Eh,020h,028h,010h,018h,005h,002h,010h,023h,016h,01Fh,008h,016h,004h
        defb 005h,011h,01Dh,029h,00Bh,00Dh,00Fh,016h,022h,00Fh,01Ch,029h,02Ch,00Fh,012h,015h
        defb 01Fh,02Dh,01Bh,029h,02Dh,011h,015h,019h,01Ch,02Bh,01Ah,029h,02Eh,033h,018h,01Dh
        defb 00Fh,01Fh,02Fh,01Fh,025h,02Bh,011h,017h,022h,013h,024h,015h,01Ch,023h,00Ah,011h
        defb 015h,007h,019h,02Bh,013h,01Bh,003h,010h,00Dh,01Bh,00Eh,021h,00Ah,013h,001h,00Fh
        defb 010h,01Ch,028h,014h,016h,018h,01Ah,001h,00Dh,01Ah,027h,014h,017h,01Ah,01Dh,000h
        defb 00Ah,018h,026h,034h,018h,01Ch,020h,024h,027h,016h,025h,034h,019h,01Eh,023h,028h
        defb 01Ah,02Ah,01Ah,02Ah,030h,016h,01Ch,022h,00Dh,01Eh,00Fh,020h,027h,00Eh,015h,01Ch
        defb 000h,012h,024h,016h,01Eh,006h,00Eh,01Bh,018h,006h,019h,00Ch,015h,01Eh,00Ch,01Ah
        defb 01Bh,007h,013h,01Fh,021h,023h,005h,00Ch,018h,025h,012h,01Fh,022h,025h,008h,00Bh
        defb 015h,023h,031h,01Fh,023h,027h,00Bh,00Fh,012h,021h,030h,01Fh,024h,029h,02Eh,013h
        defb 025h,015h,025h,035h,01Bh,021h,027h,00Dh,018h,029h,01Ah,02Bh,012h,019h,020h,007h
        defb 00Bh,01Dh,00Fh,021h,029h,011h,019h,006h,003h,011h,024h,017h,020h,009h,017h,005h

Z180Neuro44:
        defb 008h,014h,020h,02Ch,00Eh,010h,012h,019h,005h,012h,01Fh,02Ch,00Fh,012h,015h,018h
        defb 022h,010h,01Eh,02Ch,030h,014h,018h,01Ch,01Fh,02Eh,01Dh,02Ch,031h,016h,01Bh,020h
        defb 012h,022h,032h,022h,028h,02Eh,014h,01Ah,005h,016h,027h,018h,01Fh,026h,00Dh,014h
        defb 018h,00Ah,01Ch,02Eh,016h,01Eh,006h,013h,010h,01Eh,011h,024h,00Dh,016h,004h,012h
        defb 013h,01Fh,00Bh,017h,019h,01Bh,01Dh,004h,010h,01Dh,02Ah,017h,01Ah,01Dh,020h,003h
        defb 00Dh,01Bh,029h,037h,01Bh,01Fh,023h,007h,02Ah,019h,028h,037h,01Ch,021h,026h,00Bh
        defb 01Dh,02Dh,01Dh,02Dh,033h,019h,01Fh,005h,010h,021h,012h,023h,02Ah,011h,018h,01Fh
        defb 003h,015h,027h,019h,021h,009h,011h,01Eh,01Bh,009h,01Ch,00Fh,018h,001h,00Fh,01Dh
        defb 01Eh,00Ah,016h,022h,024h,006h,008h,00Fh,01Bh,028h,015h,022h,025h,028h,00Bh,00Eh
        defb 018h,026h,014h,022h,026h,02Ah,00Eh,012h,015h,024h,033h,022h,027h,02Ch,011h,016h
        defb 028h,018h,028h,038h,01Eh,024h,00Ah,010h,01Bh,00Ch,01Dh,02Eh,015h,01Ch,023h,00Ah
        defb 00Eh,020h,012h,024h,00Ch,014h,01Ch,009h,006h,014h,007h,01Ah,023h,00Ch,01Ah,008h
        defb 009h,015h,021h,02Dh,00Fh,011h,013h,01Ah,006h,013h,020h,02Dh,010h,013h,016h,019h
        defb 023h,011h,01Fh,02Dh,031h,015h,019h,01Dh,020h,02Fh,01Eh,02Dh,032h,017h,01Ch,021h
        defb 013h,023h,033h,023h,029h,00Fh,015h,01Bh,006h,017h,028h,019h,020h,027h,00Eh,015h
        defb 019h,00Bh,01Dh,00Fh,017h,01Fh,007h,014h,011h,01Fh,012h,025h,00Eh,017h,005h,013h

Z180Neuro45:
        defb 016h,022h,00Eh,01Ah,01Ch,01Eh,000h,007h,013h,020h,02Dh,01Ah,01Dh,020h,023h,006h
        defb 010h,01Eh,02Ch,01Ah,01Eh,022h,026h,00Ah,02Dh,01Ch,02Bh,03Ah,01Fh,024h,029h,00Eh
        defb 020h,010h,020h,030h,016h,01Ch,022h,008h,013h,024h,015h,026h,02Dh,014h,01Bh,002h
        defb 006h,018h,00Ah,01Ch,024h,00Ch,014h,001h,01Eh,00Ch,01Fh,012h,01Bh,004h,012h,000h
        defb 001h,00Dh,019h,025h,027h,009h,00Bh,012h,01Eh,00Bh,018h,025h,028h,00Bh,00Eh,011h
        defb 01Bh,029h,017h,025h,029h,02Dh,011h,015h,018h,027h,036h,025h,02Ah,02Fh,014h,019h
        defb 00Bh,01Bh,02Bh,01Bh,021h,027h,00Dh,013h,01Eh,00Fh,020h,031h,018h,01Fh,006h,00Dh
        defb 011h,023h,015h,027h,00Fh,017h,01Fh,00Ch,009h,017h,00Ah,01Dh,006h,00Fh,01Dh,00Bh
        defb 00Ch,018h,024h,010h,012h,014h,016h,01Dh,009h,016h,023h,030h,013h,016h,019h,01Ch
        defb 026h,014h,022h,030h,014h,018h,01Ch,020h,023h,032h,021h,030h,035h,01Ah,01Fh,024h
        defb 016h,026h,016h,026h,02Ch,012h,018h,01Eh,009h,01Ah,02Bh,01Ch,023h,00Ah,011h,018h
        defb 01Ch,00Eh,020h,012h,01Ah,022h,00Ah,017h,014h,002h,015h,028h,011h,01Ah,008h,016h
        defb 017h,023h,00Fh,01Bh,01Dh,01Fh,001h,008h,014h,021h,02Eh,01Bh,01Eh,021h,024h,007h
        defb 011h,01Fh,02Dh,01Bh,01Fh,023h,027h,00Bh,02Eh,01Dh,02Ch,03Bh,020h,025h,02Ah,00Fh
        defb 021h,011h,021h,031h,017h,01Dh,023h,009h,014h,025h,016h,027h,02Eh,015h,01Ch,003h
        defb 007h,019h,00Bh,01Dh,025h,00Dh,015h,002h,01Fh,00Dh,020h,013h,01Ch,005h,013h,001h

Z180Neuro46:
        defb 004h,010h,01Ch,028h,00Ah,00Ch,00Eh,015h,021h,00Eh,01Bh,028h,02Bh,00Eh,011h,014h
        defb 01Eh,02Ch,01Ah,028h,02Ch,010h,014h,018h,01Bh,02Ah,019h,028h,02Dh,032h,017h,01Ch
        defb 00Eh,01Eh,02Eh,01Eh,024h,02Ah,010h,016h,021h,012h,023h,014h,01Bh,022h,009h,010h
        defb 014h,006h,018h,02Ah,012h,01Ah,002h,00Fh,00Ch,01Ah,00Dh,020h,009h,012h,000h,00Eh
        defb 00Fh,01Bh,027h,013h,015h,017h,019h,000h,00Ch,019h,026h,033h,016h,019h,01Ch,01Fh
        defb 029h,017h,025h,033h,017h,01Bh,01Fh,023h,026h,015h,024h,033h,038h,01Dh,022h,027h
        defb 019h,029h,019h,029h,02Fh,015h,01Bh,021h,00Ch,01Dh,02Eh,01Fh,026h,00Dh,014h,01Bh
        defb 01Fh,011h,023h,015h,01Dh,005h,00Dh,01Ah,017h,005h,018h,00Bh,014h,01Dh,00Bh,019h
        defb 01Ah,006h,012h,01Eh,020h,022h,004h,00Bh,017h,024h,011h,01Eh,021h,024h,007h,00Ah
        defb 014h,022h,030h,01Eh,022h,026h,00Ah,00Eh,011h,020h,02Fh,01Eh,023h,028h,02Dh,012h
        defb 024h,014h,024h,034h,01Ah,020h,026h,00Ch,017h,028h,019h,02Ah,011h,018h,01Fh,006h
        defb 00Ah,01Ch,00Eh,020h,028h,010h,018h,005h,002h,010h,023h,016h,01Fh,008h,016h,004h
        defb 005h,011h,01Dh,029h,00Bh,00Dh,00Fh,016h,022h,00Fh,01Ch,029h,02Ch,00Fh,012h,015h
        defb 01Fh,02Dh,01Bh,029h,02Dh,011h,015h,019h,01Ch,02Bh,01Ah,029h,02Eh,033h,018h,01Dh
        defb 00Fh,01Fh,02Fh,01Fh,025h,02Bh,011h,017h,022h,013h,024h,015h,01Ch,023h,00Ah,011h
        defb 015h,007h,019h,02Bh,013h,01Bh,003h,010h,00Dh,01Bh,00Eh,021h,00Ah,013h,001h,00Fh

Z180Neuro47:
        defb 012h,01Eh,00Ah,016h,018h,01Ah,01Ch,003h,00Fh,01Ch,029h,016h,019h,01Ch,01Fh,002h
        defb 00Ch,01Ah,028h,036h,01Ah,01Eh,022h,006h,029h,018h,027h,036h,01Bh,020h,025h,00Ah
        defb 01Ch,02Ch,01Ch,02Ch,032h,018h,01Eh,024h,00Fh,020h,011h,022h,029h,010h,017h,01Eh
        defb 002h,014h,026h,018h,020h,008h,010h,01Dh,01Ah,008h,01Bh,00Eh,017h,000h,00Eh,01Ch
        defb 01Dh,009h,015h,021h,023h,005h,007h,00Eh,01Ah,027h,014h,021h,024h,027h,00Ah,00Dh
        defb 017h,025h,033h,021h,025h,029h,00Dh,011h,014h,023h,032h,021h,026h,02Bh,010h,015h
        defb 027h,017h,027h,037h,01Dh,023h,029h,00Fh,01Ah,00Bh,01Ch,02Dh,014h,01Bh,022h,009h
        defb 00Dh,01Fh,011h,023h,00Bh,013h,01Bh,008h,005h,013h,006h,019h,022h,00Bh,019h,007h
        defb 008h,014h,020h,02Ch,00Eh,010h,012h,019h,005h,012h,01Fh,02Ch,00Fh,012h,015h,018h
        defb 022h,010h,01Eh,02Ch,030h,014h,018h,01Ch,01Fh,02Eh,01Dh,02Ch,031h,016h,01Bh,020h
        defb 012h,022h,032h,022h,028h,02Eh,014h,01Ah,005h,016h,027h,018h,01Fh,026h,00Dh,014h
        defb 018h,00Ah,01Ch,02Eh,016h,01Eh,006h,013h,010h,01Eh,011h,024h,00Dh,016h,004h,012h
        defb 013h,01Fh,00Bh,017h,019h,01Bh,01Dh,004h,010h,01Dh,02Ah,017h,01Ah,01Dh,020h,003h
        defb 00Dh,01Bh,029h,037h,01Bh,01Fh,023h,007h,02Ah,019h,028h,037h,01Ch,021h,026h,00Bh
        defb 01Dh,02Dh,01Dh,02Dh,033h,019h,01Fh,005h,010h,021h,012h,023h,02Ah,011h,018h,01Fh
        defb 003h,015h,027h,019h,021h,009h,011h,01Eh,01Bh,009h,01Ch,00Fh,018h,001h,00Fh,01Dh

Z180Neuro48:
        defb 000h,00Ch,018h,024h,026h,008h,00Ah,011h,01Dh,00Ah,017h,024h,027h,00Ah,00Dh,010h
        defb 01Ah,028h,016h,024h,028h,02Ch,010h,014h,017h,026h,035h,024h,029h,02Eh,013h,018h
        defb 00Ah,01Ah,02Ah,01Ah,020h,026h,00Ch,012h,01Dh,00Eh,01Fh,030h,017h,01Eh,005h,00Ch
        defb 010h,022h,014h,026h,00Eh,016h,01Eh,00Bh,008h,016h,009h,01Ch,005h,00Eh,01Ch,00Ah
        defb 00Bh,017h,023h,00Fh,011h,013h,015h,01Ch,008h,015h,022h,02Fh,012h,015h,018h,01Bh
        defb 025h,013h,021h,02Fh,033h,017h,01Bh,01Fh,022h,031h,020h,02Fh,034h,019h,01Eh,023h
        defb 015h,025h,015h,025h,02Bh,011h,017h,01Dh,008h,019h,02Ah,01Bh,022h,029h,010h,017h
        defb 01Bh,00Dh,01Fh,011h,019h,021h,009h,016h,013h,001h,014h,027h,010h,019h,007h,015h
        defb 016h,022h,00Eh,01Ah,01Ch,01Eh,000h,007h,013h,020h,02Dh,01Ah,01Dh,020h,023h,006h
        defb 010h,01Eh,02Ch,01Ah,01Eh,022h,026h,00Ah,02Dh,01Ch,02Bh,03Ah,01Fh,024h,029h,00Eh
        defb 020h,010h,020h,030h,016h,01Ch,022h,008h,013h,024h,015h,026h,02Dh,014h,01Bh,002h
        defb 006h,018h,00Ah,01Ch,024h,00Ch,014h,001h,01Eh,00Ch,01Fh,012h,01Bh,004h,012h,000h
        defb 001h,00Dh,019h,025h,027h,009h,00Bh,012h,01Eh,00Bh,018h,025h,028h,00Bh,00Eh,011h
        defb 01Bh,029h,017h,025h,029h,02Dh,011h,015h,018h,027h,036h,025h,02Ah,02Fh,014h,019h
        defb 00Bh,01Bh,02Bh,01Bh,021h,027h,00Dh,013h,01Eh,00Fh,020h,031h,018h,01Fh,006h,00Dh
        defb 011h,023h,015h,027h,00Fh,017h,01Fh,00Ch,009h,017h,00Ah,01Dh,006h,00Fh,01Dh,00Bh

Z180Neuro49:
        defb 00Eh,01Ah,026h,012h,014h,016h,018h,01Fh,00Bh,018h,025h,032h,015h,018h,01Bh,01Eh
        defb 028h,016h,024h,032h,016h,01Ah,01Eh,022h,025h,014h,023h,032h,037h,01Ch,021h,026h
        defb 018h,028h,018h,028h,02Eh,014h,01Ah,020h,00Bh,01Ch,02Dh,01Eh,025h,00Ch,013h,01Ah
        defb 01Eh,010h,022h,014h,01Ch,024h,00Ch,019h,016h,004h,017h,00Ah,013h,01Ch,00Ah,018h
        defb 019h,005h,011h,01Dh,01Fh,021h,003h,00Ah,016h,023h,010h,01Dh,020h,023h,006h,009h
        defb 013h,021h,02Fh,01Dh,021h,025h,029h,00Dh,010h,01Fh,02Eh,03Dh,022h,027h,02Ch,011h
        defb 023h,013h,023h,033h,019h,01Fh,025h,00Bh,016h,027h,018h,029h,010h,017h,01Eh,005h
        defb 009h,01Bh,00Dh,01Fh,027h,00Fh,017h,004h,001h,00Fh,022h,015h,01Eh,007h,015h,003h
        defb 004h,010h,01Ch,028h,00Ah,00Ch,00Eh,015h,021h,00Eh,01Bh,028h,02Bh,00Eh,011h,014h
        defb 01Eh,02Ch,01Ah,028h,02Ch,010h,014h,018h,01Bh,02Ah,019h,028h,02Dh,032h,017h,01Ch
        defb 00Eh,01Eh,02Eh,01Eh,024h,02Ah,010h,016h,021h,012h,023h,014h,01Bh,022h,009h,010h
        defb 014h,006h,018h,02Ah,012h,01Ah,002h,00Fh,00Ch,01Ah,00Dh,020h,009h,012h,000h,00Eh
        defb 00Fh,01Bh,027h,013h,015h,017h,019h,000h,00Ch,019h,026h,033h,016h,019h,01Ch,01Fh
        defb 029h,017h,025h,033h,017h,01Bh,01Fh,023h,026h,015h,024h,033h,038h,01Dh,022h,027h
        defb 019h,029h,019h,029h,02Fh,015h,01Bh,021h,00Ch,01Dh,02Eh,01Fh,026h,00Dh,014h,01Bh
        defb 01Fh,011h,023h,015h,01Dh,005h,00Dh,01Ah,017h,005h,018h,00Bh,014h,01Dh,00Bh,019h

Z180Neuro50:
        defb 01Ch,008h,014h,020h,022h,024h,006h,00Dh,019h,026h,013h,020h,023h,026h,009h,00Ch
        defb 016h,024h,032h,020h,024h,028h,00Ch,010h,013h,022h,031h,020h,025h,02Ah,00Fh,014h
        defb 026h,016h,026h,036h,01Ch,022h,028h,00Eh,019h,00Ah,01Bh,02Ch,013h,01Ah,021h,008h
        defb 00Ch,01Eh,010h,022h,00Ah,012h,01Ah,007h,004h,012h,005h,018h,021h,00Ah,018h,006h
        defb 007h,013h,01Fh,02Bh,00Dh,00Fh,011h,018h,024h,011h,01Eh,02Bh,02Eh,011h,014h,017h
        defb 021h,00Fh,01Dh,02Bh,02Fh,013h,017h,01Bh,01Eh,02Dh,01Ch,02Bh,030h,015h,01Ah,01Fh
        defb 011h,021h,031h,021h,027h,02Dh,013h,019h,024h,015h,026h,017h,01Eh,025h,00Ch,013h
        defb 017h,009h,01Bh,02Dh,015h,01Dh,005h,012h,00Fh,01Dh,010h,023h,00Ch,015h,003h,011h
        defb 012h,01Eh,00Ah,016h,018h,01Ah,01Ch,003h,00Fh,01Ch,029h,016h,019h,01Ch,01Fh,002h
        defb 00Ch,01Ah,028h,036h,01Ah,01Eh,022h,006h,029h,018h,027h,036h,01Bh,020h,025h,00Ah
        defb 01Ch,02Ch,01Ch,02Ch,032h,018h,01Eh,024h,00Fh,020h,011h,022h,029h,010h,017h,01Eh
        defb 002h,014h,026h,018h,020h,008h,010h,01Dh,01Ah,008h,01Bh,00Eh,017h,000h,00Eh,01Ch
        defb 01Dh,009h,015h,021h,023h,005h,007h,00Eh,01Ah,027h,014h,021h,024h,027h,00Ah,00Dh
        defb 017h,025h,033h,021h,025h,029h,00Dh,011h,014h,023h,032h,021h,026h,02Bh,010h,015h
        defb 027h,017h,027h,037h,01Dh,023h,029h,00Fh,01Ah,00Bh,01Ch,02Dh,014h,01Bh,022h,009h
        defb 00Dh,01Fh,011h,023h,00Bh,013h,01Bh,008h,005h,013h,006h,019h,022h,00Bh,019h,007h

Z180Neuro51:
        defb 00Ah,016h,022h,02Eh,010h,012h,014h,01Bh,007h,014h,021h,02Eh,011h,014h,017h,01Ah
        defb 024h,012h,020h,02Eh,032h,016h,01Ah,01Eh,021h,030h,01Fh,02Eh,033h,018h,01Dh,022h
        defb 014h,024h,014h,024h,02Ah,010h,016h,01Ch,007h,018h,029h,01Ah,021h,028h,00Fh,016h
        defb 01Ah,00Ch,01Eh,010h,018h,020h,008h,015h,012h,000h,013h,026h,00Fh,018h,006h,014h
        defb 015h,021h,00Dh,019h,01Bh,01Dh,01Fh,006h,012h,01Fh,02Ch,019h,01Ch,01Fh,022h,005h
        defb 00Fh,01Dh,02Bh,019h,01Dh,021h,025h,009h,02Ch,01Bh,02Ah,039h,01Eh,023h,028h,00Dh
        defb 01Fh,00Fh,01Fh,02Fh,015h,01Bh,021h,007h,012h,023h,014h,025h,02Ch,013h,01Ah,001h
        defb 005h,017h,029h,01Bh,023h,00Bh,013h,000h,01Dh,00Bh,01Eh,011h,01Ah,003h,011h,01Fh
        defb 000h,00Ch,018h,024h,026h,008h,00Ah,011h,01Dh,00Ah,017h,024h,027h,00Ah,00Dh,010h
        defb 01Ah,028h,016h,024h,028h,02Ch,010h,014h,017h,026h,035h,024h,029h,02Eh,013h,018h
        defb 00Ah,01Ah,02Ah,01Ah,020h,026h,00Ch,012h,01Dh,00Eh,01Fh,030h,017h,01Eh,005h,00Ch
        defb 010h,022h,014h,026h,00Eh,016h,01Eh,00Bh,008h,016h,009h,01Ch,005h,00Eh,01Ch,00Ah
        defb 00Bh,017h,023h,00Fh,011h,013h,015h,01Ch,008h,015h,022h,02Fh,012h,015h,018h,01Bh
        defb 025h,013h,021h,02Fh,033h,017h,01Bh,01Fh,022h,031h,020h,02Fh,034h,019h,01Eh,023h
        defb 015h,025h,015h,025h,02Bh,011h,017h,01Dh,008h,019h,02Ah,01Bh,022h,029h,010h,017h
        defb 01Bh,00Dh,01Fh,011h,019h,021h,009h,016h,013h,001h,014h,027h,010h,019h,007h,015h

Z180Neuro52:
        defb 018h,024h,010h,01Ch,01Eh,020h,002h,009h,015h,022h,00Fh,01Ch,01Fh,022h,005h,008h
        defb 012h,020h,02Eh,01Ch,020h,024h,028h,00Ch,00Fh,01Eh,02Dh,03Ch,021h,026h,02Bh,010h
        defb 022h,012h,022h,032h,018h,01Eh,024h,00Ah,015h,026h,017h,028h,00Fh,016h,01Dh,004h
        defb 008h,01Ah,00Ch,01Eh,026h,00Eh,016h,003h,000h,00Eh,021h,014h,01Dh,006h,014h,002h
        defb 003h,00Fh,01Bh,027h,029h,00Bh,00Dh,014h,020h,00Dh,01Ah,027h,02Ah,00Dh,010h,013h
        defb 01Dh,02Bh,019h,027h,02Bh,00Fh,013h,017h,01Ah,029h,038h,027h,02Ch,031h,016h,01Bh
        defb 00Dh,01Dh,02Dh,01Dh,023h,029h,00Fh,015h,020h,011h,022h,033h,01Ah,021h,008h,00Fh
        defb 013h,005h,017h,029h,011h,019h,001h,00Eh,00Bh,019h,00Ch,01Fh,008h,011h,01Fh,00Dh
        defb 00Eh,01Ah,026h,012h,014h,016h,018h,01Fh,00Bh,018h,025h,032h,015h,018h,01Bh,01Eh
        defb 028h,016h,024h,032h,016h,01Ah,01Eh,022h,025h,014h,023h,032h,037h,01Ch,021h,026h
        defb 018h,028h,018h,028h,02Eh,014h,01Ah,020h,00Bh,01Ch,02Dh,01Eh,025h,00Ch,013h,01Ah
        defb 01Eh,010h,022h,014h,01Ch,024h,00Ch,019h,016h,004h,017h,00Ah,013h,01Ch,00Ah,018h
        defb 019h,005h,011h,01Dh,01Fh,021h,003h,00Ah,016h,023h,010h,01Dh,020h,023h,006h,009h
        defb 013h,021h,02Fh,01Dh,021h,025h,029h,00Dh,010h,01Fh,02Eh,03Dh,022h,027h,02Ch,011h
        defb 023h,013h,023h,033h,019h,01Fh,025h,00Bh,016h,027h,018h,029h,010h,017h,01Eh,005h
        defb 009h,01Bh,00Dh,01Fh,027h,00Fh,017h,004h,001h,00Fh,022h,015h,01Eh,007h,015h,003h

Z180Neuro53:
        defb 006h,012h,01Eh,02Ah,00Ch,00Eh,010h,017h,023h,010h,01Dh,02Ah,02Dh,010h,013h,016h
        defb 020h,02Eh,01Ch,02Ah,02Eh,012h,016h,01Ah,01Dh,02Ch,01Bh,02Ah,02Fh,014h,019h,01Eh
        defb 010h,020h,030h,020h,026h,02Ch,012h,018h,023h,014h,025h,016h,01Dh,024h,00Bh,012h
        defb 016h,008h,01Ah,02Ch,014h,01Ch,004h,011h,00Eh,01Ch,00Fh,022h,00Bh,014h,002h,010h
        defb 011h,01Dh,029h,015h,017h,019h,01Bh,002h,00Eh,01Bh,028h,015h,018h,01Bh,01Eh,001h
        defb 00Bh,019h,027h,035h,019h,01Dh,021h,005h,028h,017h,026h,035h,01Ah,01Fh,024h,029h
        defb 01Bh,02Bh,01Bh,02Bh,031h,017h,01Dh,023h,00Eh,01Fh,010h,021h,028h,00Fh,016h,01Dh
        defb 001h,013h,025h,017h,01Fh,007h,00Fh,01Ch,019h,007h,01Ah,00Dh,016h,01Fh,00Dh,01Bh
        defb 01Ch,008h,014h,020h,022h,024h,006h,00Dh,019h,026h,013h,020h,023h,026h,009h,00Ch
        defb 016h,024h,032h,020h,024h,028h,00Ch,010h,013h,022h,031h,020h,025h,02Ah,00Fh,014h
        defb 026h,016h,026h,036h,01Ch,022h,028h,00Eh,019h,00Ah,01Bh,02Ch,013h,01Ah,021h,008h
        defb 00Ch,01Eh,010h,022h,00Ah,012h,01Ah,007h,004h,012h,005h,018h,021h,00Ah,018h,006h
        defb 007h,013h,01Fh,02Bh,00Dh,00Fh,011h,018h,024h,011h,01Eh,02Bh,02Eh,011h,014h,017h
        defb 021h,00Fh,01Dh,02Bh,02Fh,013h,017h,01Bh,01Eh,02Dh,01Ch,02Bh,030h,015h,01Ah,01Fh
        defb 011h,021h,031h,021h,027h,02Dh,013h,019h,024h,015h,026h,017h,01Eh,025h,00Ch,013h
        defb 017h,009h,01Bh,02Dh,015h,01Dh,005h,012h,00Fh,01Dh,010h,023h,00Ch,015h,003h,011h

Z180Neuro54:
        defb 014h,020h,00Ch,018h,01Ah,01Ch,01Eh,005h,011h,01Eh,02Bh,018h,01Bh,01Eh,021h,004h
        defb 00Eh,01Ch,02Ah,038h,01Ch,020h,024h,008h,02Bh,01Ah,029h,038h,01Dh,022h,027h,00Ch
        defb 01Eh,02Eh,01Eh,02Eh,014h,01Ah,020h,006h,011h,022h,013h,024h,02Bh,012h,019h,000h
        defb 004h,016h,028h,01Ah,022h,00Ah,012h,01Fh,01Ch,00Ah,01Dh,010h,019h,002h,010h,01Eh
        defb 01Fh,00Bh,017h,023h,025h,007h,009h,010h,01Ch,029h,016h,023h,026h,029h,00Ch,00Fh
        defb 019h,027h,015h,023h,027h,02Bh,00Fh,013h,016h,025h,034h,023h,028h,02Dh,012h,017h
        defb 029h,019h,029h,019h,01Fh,025h,00Bh,011h,01Ch,00Dh,01Eh,02Fh,016h,01Dh,024h,00Bh
        defb 00Fh,021h,013h,025h,00Dh,015h,01Dh,00Ah,007h,015h,008h,01Bh,024h,00Dh,01Bh,009h
        defb 00Ah,016h,022h,02Eh,010h,012h,014h,01Bh,007h,014h,021h,02Eh,011h,014h,017h,01Ah
        defb 024h,012h,020h,02Eh,032h,016h,01Ah,01Eh,021h,030h,01Fh,02Eh,033h,018h,01Dh,022h
        defb 014h,024h,014h,024h,02Ah,010h,016h,01Ch,007h,018h,029h,01Ah,021h,028h,00Fh,016h
        defb 01Ah,00Ch,01Eh,010h,018h,020h,008h,015h,012h,000h,013h,026h,00Fh,018h,006h,014h
        defb 015h,021h,00Dh,019h,01Bh,01Dh,01Fh,006h,012h,01Fh,02Ch,019h,01Ch,01Fh,022h,005h
        defb 00Fh,01Dh,02Bh,019h,01Dh,021h,025h,009h,02Ch,01Bh,02Ah,039h,01Eh,023h,028h,00Dh
        defb 01Fh,00Fh,01Fh,02Fh,015h,01Bh,021h,007h,012h,023h,014h,025h,02Ch,013h,01Ah,001h
        defb 005h,017h,029h,01Bh,023h,00Bh,013h,000h,01Dh,00Bh,01Eh,011h,01Ah,003h,011h,01Fh

Z180Neuro55:
        defb 002h,00Eh,01Ah,026h,028h,00Ah,00Ch,013h,01Fh,00Ch,019h,026h,029h,00Ch,00Fh,012h
        defb 01Ch,02Ah,018h,026h,02Ah,02Eh,012h,016h,019h,028h,037h,026h,02Bh,030h,015h,01Ah
        defb 00Ch,01Ch,02Ch,01Ch,022h,028h,00Eh,014h,01Fh,010h,021h,032h,019h,020h,007h,00Eh
        defb 012h,024h,016h,028h,010h,018h,000h,00Dh,00Ah,018h,00Bh,01Eh,007h,010h,01Eh,00Ch
        defb 00Dh,019h,025h,011h,013h,015h,017h,01Eh,00Ah,017h,024h,031h,014h,017h,01Ah,01Dh
        defb 027h,015h,023h,031h,015h,019h,01Dh,021h,024h,033h,022h,031h,036h,01Bh,020h,025h
        defb 017h,027h,017h,027h,02Dh,013h,019h,01Fh,00Ah,01Bh,02Ch,01Dh,024h,00Bh,012h,019h
        defb 01Dh,00Fh,021h,013h,01Bh,023h,00Bh,018h,015h,003h,016h,029h,012h,01Bh,009h,017h
        defb 018h,024h,010h,01Ch,01Eh,020h,002h,009h,015h,022h,00Fh,01Ch,01Fh,022h,005h,008h
        defb 012h,020h,02Eh,01Ch,020h,024h,028h,00Ch,00Fh,01Eh,02Dh,03Ch,021h,026h,02Bh,010h
        defb 022h,012h,022h,032h,018h,01Eh,024h,00Ah,015h,026h,017h,028h,00Fh,016h,01Dh,004h
        defb 008h,01Ah,00Ch,01Eh,026h,00Eh,016h,003h,000h,00Eh,021h,014h,01Dh,006h,014h,002h
        defb 003h,00Fh,01Bh,027h,029h,00Bh,00Dh,014h,020h,00Dh,01Ah,027h,02Ah,00Dh,010h,013h
        defb 01Dh,02Bh,019h,027h,02Bh,00Fh,013h,017h,01Ah,029h,038h,027h,02Ch,031h,016h,01Bh
        defb 00Dh,01Dh,02Dh,01Dh,023h,029h,00Fh,015h,020h,011h,022h,033h,01Ah,021h,008h,00Fh
        defb 013h,005h,017h,029h,011h,019h,001h,00Eh,00Bh,019h,00Ch,01Fh,008h,011h,01Fh,00Dh

Z180Neuro56:
        defb 010h,01Ch,028h,014h,016h,018h,01Ah,001h,00Dh,01Ah,027h,014h,017h,01Ah,01Dh,000h
        defb 00Ah,018h,026h,034h,018h,01Ch,020h,024h,027h,016h,025h,034h,019h,01Eh,023h,028h
        defb 01Ah,02Ah,01Ah,02Ah,030h,016h,01Ch,022h,00Dh,01Eh,00Fh,020h,027h,00Eh,015h,01Ch
        defb 000h,012h,024h,016h,01Eh,006h,00Eh,01Bh,018h,006h,019h,00Ch,015h,01Eh,00Ch,01Ah
        defb 01Bh,007h,013h,01Fh,021h,023h,005h,00Ch,018h,025h,012h,01Fh,022h,025h,008h,00Bh
        defb 015h,023h,031h,01Fh,023h,027h,00Bh,00Fh,012h,021h,030h,01Fh,024h,029h,02Eh,013h
        defb 025h,015h,025h,035h,01Bh,021h,027h,00Dh,018h,029h,01Ah,02Bh,012h,019h,020h,007h
        defb 00Bh,01Dh,00Fh,021h,029h,011h,019h,006h,003h,011h,024h,017h,020h,009h,017h,005h
        defb 006h,012h,01Eh,02Ah,00Ch,00Eh,010h,017h,023h,010h,01Dh,02Ah,02Dh,010h,013h,016h
        defb 020h,02Eh,01Ch,02Ah,02Eh,012h,016h,01Ah,01Dh,02Ch,01Bh,02Ah,02Fh,014h,019h,01Eh
        defb 010h,020h,030h,020h,026h,02Ch,012h,018h,023h,014h,025h,016h,01Dh,024h,00Bh,012h
        defb 016h,008h,01Ah,02Ch,014h,01Ch,004h,011h,00Eh,01Ch,00Fh,022h,00Bh,014h,002h,010h
        defb 011h,01Dh,029h,015h,017h,019h,01Bh,002h,00Eh,01Bh,028h,015h,018h,01Bh,01Eh,001h
        defb 00Bh,019h,027h,035h,019h,01Dh,021h,005h,028h,017h,026h,035h,01Ah,01Fh,024h,029h
        defb 01Bh,02Bh,01Bh,02Bh,031h,017h,01Dh,023h,00Eh,01Fh,010h,021h,028h,00Fh,016h,01Dh
        defb 001h,013h,025h,017h,01Fh,007h,00Fh,01Ch,019h,007h,01Ah,00Dh,016h,01Fh,00Dh,01Bh

Z180Neuro57:
        defb 01Eh,00Ah,016h,022h,024h,006h,008h,00Fh,01Bh,028h,015h,022h,025h,028h,00Bh,00Eh
        defb 018h,026h,014h,022h,026h,02Ah,00Eh,012h,015h,024h,033h,022h,027h,02Ch,011h,016h
        defb 028h,018h,028h,038h,01Eh,024h,00Ah,010h,01Bh,00Ch,01Dh,02Eh,015h,01Ch,023h,00Ah
        defb 00Eh,020h,012h,024h,00Ch,014h,01Ch,009h,006h,014h,007h,01Ah,023h,00Ch,01Ah,008h
        defb 009h,015h,021h,02Dh,00Fh,011h,013h,01Ah,006h,013h,020h,02Dh,010h,013h,016h,019h
        defb 023h,011h,01Fh,02Dh,031h,015h,019h,01Dh,020h,02Fh,01Eh,02Dh,032h,017h,01Ch,021h
        defb 013h,023h,033h,023h,029h,00Fh,015h,01Bh,006h,017h,028h,019h,020h,027h,00Eh,015h
        defb 019h,00Bh,01Dh,00Fh,017h,01Fh,007h,014h,011h,01Fh,012h,025h,00Eh,017h,005h,013h
        defb 014h,020h,00Ch,018h,01Ah,01Ch,01Eh,005h,011h,01Eh,02Bh,018h,01Bh,01Eh,021h,004h
        defb 00Eh,01Ch,02Ah,038h,01Ch,020h,024h,008h,02Bh,01Ah,029h,038h,01Dh,022h,027h,00Ch
        defb 01Eh,02Eh,01Eh,02Eh,014h,01Ah,020h,006h,011h,022h,013h,024h,02Bh,012h,019h,000h
        defb 004h,016h,028h,01Ah,022h,00Ah,012h,01Fh,01Ch,00Ah,01Dh,010h,019h,002h,010h,01Eh
        defb 01Fh,00Bh,017h,023h,025h,007h,009h,010h,01Ch,029h,016h,023h,026h,029h,00Ch,00Fh
        defb 019h,027h,015h,023h,027h,02Bh,00Fh,013h,016h,025h,034h,023h,028h,02Dh,012h,017h
        defb 029h,019h,029h,019h,01Fh,025h,00Bh,011h,01Ch,00Dh,01Eh,02Fh,016h,01Dh,024h,00Bh
        defb 00Fh,021h,013h,025h,00Dh,015h,01Dh,00Ah,007h,015h,008h,01Bh,024h,00Dh,01Bh,009h

Z180Neuro58:
        defb 00Ch,018h,024h,010h,012h,014h,016h,01Dh,009h,016h,023h,030h,013h,016h,019h,01Ch
        defb 026h,014h,022h,030h,014h,018h,01Ch,020h,023h,032h,021h,030h,035h,01Ah,01Fh,024h
        defb 016h,026h,016h,026h,02Ch,012h,018h,01Eh,009h,01Ah,02Bh,01Ch,023h,00Ah,011h,018h
        defb 01Ch,00Eh,020h,012h,01Ah,022h,00Ah,017h,014h,002h,015h,028h,011h,01Ah,008h,016h
        defb 017h,023h,00Fh,01Bh,01Dh,01Fh,001h,008h,014h,021h,02Eh,01Bh,01Eh,021h,024h,007h
        defb 011h,01Fh,02Dh,01Bh,01Fh,023h,027h,00Bh,02Eh,01Dh,02Ch,03Bh,020h,025h,02Ah,00Fh
        defb 021h,011h,021h,031h,017h,01Dh,023h,009h,014h,025h,016h,027h,02Eh,015h,01Ch,003h
        defb 007h,019h,00Bh,01Dh,025h,00Dh,015h,002h,01Fh,00Dh,020h,013h,01Ch,005h,013h,001h
        defb 002h,00Eh,01Ah,026h,028h,00Ah,00Ch,013h,01Fh,00Ch,019h,026h,029h,00Ch,00Fh,012h
        defb 01Ch,02Ah,018h,026h,02Ah,02Eh,012h,016h,019h,028h,037h,026h,02Bh,030h,015h,01Ah
        defb 00Ch,01Ch,02Ch,01Ch,022h,028h,00Eh,014h,01Fh,010h,021h,032h,019h,020h,007h,00Eh
        defb 012h,024h,016h,028h,010h,018h,000h,00Dh,00Ah,018h,00Bh,01Eh,007h,010h,01Eh,00Ch
        defb 00Dh,019h,025h,011h,013h,015h,017h,01Eh,00Ah,017h,024h,031h,014h,017h,01Ah,01Dh
        defb 027h,015h,023h,031h,015h,019h,01Dh,021h,024h,033h,022h,031h,036h,01Bh,020h,025h
        defb 017h,027h,017h,027h,02Dh,013h,019h,01Fh,00Ah,01Bh,02Ch,01Dh,024h,00Bh,012h,019h
        defb 01Dh,00Fh,021h,013h,01Bh,023h,00Bh,018h,015h,003h,016h,029h,012h,01Bh,009h,017h

Z180Neuro59:
        defb 01Ah,006h,012h,01Eh,020h,022h,004h,00Bh,017h,024h,011h,01Eh,021h,024h,007h,00Ah
        defb 014h,022h,030h,01Eh,022h,026h,00Ah,00Eh,011h,020h,02Fh,01Eh,023h,028h,02Dh,012h
        defb 024h,014h,024h,034h,01Ah,020h,026h,00Ch,017h,028h,019h,02Ah,011h,018h,01Fh,006h
        defb 00Ah,01Ch,00Eh,020h,028h,010h,018h,005h,002h,010h,023h,016h,01Fh,008h,016h,004h
        defb 005h,011h,01Dh,029h,00Bh,00Dh,00Fh,016h,022h,00Fh,01Ch,029h,02Ch,00Fh,012h,015h
        defb 01Fh,02Dh,01Bh,029h,02Dh,011h,015h,019h,01Ch,02Bh,01Ah,029h,02Eh,033h,018h,01Dh
        defb 00Fh,01Fh,02Fh,01Fh,025h,02Bh,011h,017h,022h,013h,024h,015h,01Ch,023h,00Ah,011h
        defb 015h,007h,019h,02Bh,013h,01Bh,003h,010h,00Dh,01Bh,00Eh,021h,00Ah,013h,001h,00Fh
        defb 010h,01Ch,028h,014h,016h,018h,01Ah,001h,00Dh,01Ah,027h,014h,017h,01Ah,01Dh,000h
        defb 00Ah,018h,026h,034h,018h,01Ch,020h,024h,027h,016h,025h,034h,019h,01Eh,023h,028h
        defb 01Ah,02Ah,01Ah,02Ah,030h,016h,01Ch,022h,00Dh,01Eh,00Fh,020h,027h,00Eh,015h,01Ch
        defb 000h,012h,024h,016h,01Eh,006h,00Eh,01Bh,018h,006h,019h,00Ch,015h,01Eh,00Ch,01Ah
        defb 01Bh,007h,013h,01Fh,021h,023h,005h,00Ch,018h,025h,012h,01Fh,022h,025h,008h,00Bh
        defb 015h,023h,031h,01Fh,023h,027h,00Bh,00Fh,012h,021h,030h,01Fh,024h,029h,02Eh,013h
        defb 025h,015h,025h,035h,01Bh,021h,027h,00Dh,018h,029h,01Ah,02Bh,012h,019h,020h,007h
        defb 00Bh,01Dh,00Fh,021h,029h,011h,019h,006h,003h,011h,024h,017h,020h,009h,017h,005h

Z180Neuro60:
        defb 008h,014h,020h,02Ch,00Eh,010h,012h,019h,005h,012h,01Fh,02Ch,00Fh,012h,015h,018h
        defb 022h,010h,01Eh,02Ch,030h,014h,018h,01Ch,01Fh,02Eh,01Dh,02Ch,031h,016h,01Bh,020h
        defb 012h,022h,032h,022h,028h,02Eh,014h,01Ah,005h,016h,027h,018h,01Fh,026h,00Dh,014h
        defb 018h,00Ah,01Ch,02Eh,016h,01Eh,006h,013h,010h,01Eh,011h,024h,00Dh,016h,004h,012h
        defb 013h,01Fh,00Bh,017h,019h,01Bh,01Dh,004h,010h,01Dh,02Ah,017h,01Ah,01Dh,020h,003h
        defb 00Dh,01Bh,029h,037h,01Bh,01Fh,023h,007h,02Ah,019h,028h,037h,01Ch,021h,026h,00Bh
        defb 01Dh,02Dh,01Dh,02Dh,033h,019h,01Fh,005h,010h,021h,012h,023h,02Ah,011h,018h,01Fh
        defb 003h,015h,027h,019h,021h,009h,011h,01Eh,01Bh,009h,01Ch,00Fh,018h,001h,00Fh,01Dh
        defb 01Eh,00Ah,016h,022h,024h,006h,008h,00Fh,01Bh,028h,015h,022h,025h,028h,00Bh,00Eh
        defb 018h,026h,014h,022h,026h,02Ah,00Eh,012h,015h,024h,033h,022h,027h,02Ch,011h,016h
        defb 028h,018h,028h,038h,01Eh,024h,00Ah,010h,01Bh,00Ch,01Dh,02Eh,015h,01Ch,023h,00Ah
        defb 00Eh,020h,012h,024h,00Ch,014h,01Ch,009h,006h,014h,007h,01Ah,023h,00Ch,01Ah,008h
        defb 009h,015h,021h,02Dh,00Fh,011h,013h,01Ah,006h,013h,020h,02Dh,010h,013h,016h,019h
        defb 023h,011h,01Fh,02Dh,031h,015h,019h,01Dh,020h,02Fh,01Eh,02Dh,032h,017h,01Ch,021h
        defb 013h,023h,033h,023h,029h,00Fh,015h,01Bh,006h,017h,028h,019h,020h,027h,00Eh,015h
        defb 019h,00Bh,01Dh,00Fh,017h,01Fh,007h,014h,011h,01Fh,012h,025h,00Eh,017h,005h,013h

Z180Neuro61:
        defb 016h,022h,00Eh,01Ah,01Ch,01Eh,000h,007h,013h,020h,02Dh,01Ah,01Dh,020h,023h,006h
        defb 010h,01Eh,02Ch,01Ah,01Eh,022h,026h,00Ah,02Dh,01Ch,02Bh,03Ah,01Fh,024h,029h,00Eh
        defb 020h,010h,020h,030h,016h,01Ch,022h,008h,013h,024h,015h,026h,02Dh,014h,01Bh,002h
        defb 006h,018h,00Ah,01Ch,024h,00Ch,014h,001h,01Eh,00Ch,01Fh,012h,01Bh,004h,012h,000h
        defb 001h,00Dh,019h,025h,027h,009h,00Bh,012h,01Eh,00Bh,018h,025h,028h,00Bh,00Eh,011h
        defb 01Bh,029h,017h,025h,029h,02Dh,011h,015h,018h,027h,036h,025h,02Ah,02Fh,014h,019h
        defb 00Bh,01Bh,02Bh,01Bh,021h,027h,00Dh,013h,01Eh,00Fh,020h,031h,018h,01Fh,006h,00Dh
        defb 011h,023h,015h,027h,00Fh,017h,01Fh,00Ch,009h,017h,00Ah,01Dh,006h,00Fh,01Dh,00Bh
        defb 00Ch,018h,024h,010h,012h,014h,016h,01Dh,009h,016h,023h,030h,013h,016h,019h,01Ch
        defb 026h,014h,022h,030h,014h,018h,01Ch,020h,023h,032h,021h,030h,035h,01Ah,01Fh,024h
        defb 016h,026h,016h,026h,02Ch,012h,018h,01Eh,009h,01Ah,02Bh,01Ch,023h,00Ah,011h,018h
        defb 01Ch,00Eh,020h,012h,01Ah,022h,00Ah,017h,014h,002h,015h,028h,011h,01Ah,008h,016h
        defb 017h,023h,00Fh,01Bh,01Dh,01Fh,001h,008h,014h,021h,02Eh,01Bh,01Eh,021h,024h,007h
        defb 011h,01Fh,02Dh,01Bh,01Fh,023h,027h,00Bh,02Eh,01Dh,02Ch,03Bh,020h,025h,02Ah,00Fh
        defb 021h,011h,021h,031h,017h,01Dh,023h,009h,014h,025h,016h,027h,02Eh,015h,01Ch,003h
        defb 007h,019h,00Bh,01Dh,025h,00Dh,015h,002h,01Fh,00Dh,020h,013h,01Ch,005h,013h,001h

Z180Neuro62:
        defb 004h,010h,01Ch,028h,00Ah,00Ch,00Eh,015h,021h,00Eh,01Bh,028h,02Bh,00Eh,011h,014h
        defb 01Eh,02Ch,01Ah,028h,02Ch,010h,014h,018h,01Bh,02Ah,019h,028h,02Dh,032h,017h,01Ch
        defb 00Eh,01Eh,02Eh,01Eh,024h,02Ah,010h,016h,021h,012h,023h,014h,01Bh,022h,009h,010h
        defb 014h,006h,018h,02Ah,012h,01Ah,002h,00Fh,00Ch,01Ah,00Dh,020h,009h,012h,000h,00Eh
        defb 00Fh,01Bh,027h,013h,015h,017h,019h,000h,00Ch,019h,026h,033h,016h,019h,01Ch,01Fh
        defb 029h,017h,025h,033h,017h,01Bh,01Fh,023h,026h,015h,024h,033h,038h,01Dh,022h,027h
        defb 019h,029h,019h,029h,02Fh,015h,01Bh,021h,00Ch,01Dh,02Eh,01Fh,026h,00Dh,014h,01Bh
        defb 01Fh,011h,023h,015h,01Dh,005h,00Dh,01Ah,017h,005h,018h,00Bh,014h,01Dh,00Bh,019h
        defb 01Ah,006h,012h,01Eh,020h,022h,004h,00Bh,017h,024h,011h,01Eh,021h,024h,007h,00Ah
        defb 014h,022h,030h,01Eh,022h,026h,00Ah,00Eh,011h,020h,02Fh,01Eh,023h,028h,02Dh,012h
        defb 024h,014h,024h,034h,01Ah,020h,026h,00Ch,017h,028h,019h,02Ah,011h,018h,01Fh,006h
        defb 00Ah,01Ch,00Eh,020h,028h,010h,018h,005h,002h,010h,023h,016h,01Fh,008h,016h,004h
        defb 005h,011h,01Dh,029h,00Bh,00Dh,00Fh,016h,022h,00Fh,01Ch,029h,02Ch,00Fh,012h,015h
        defb 01Fh,02Dh,01Bh,029h,02Dh,011h,015h,019h,01Ch,02Bh,01Ah,029h,02Eh,033h,018h,01Dh
        defb 00Fh,01Fh,02Fh,01Fh,025h,02Bh,011h,017h,022h,013h,024h,015h,01Ch,023h,00Ah,011h
        defb 015h,007h,019h,02Bh,013h,01Bh,003h,010h,00Dh,01Bh,00Eh,021h,00Ah,013h,001h,00Fh

Z180Neuro63:
        defb 012h,01Eh,00Ah,016h,018h,01Ah,01Ch,003h,00Fh,01Ch,029h,016h,019h,01Ch,01Fh,002h
        defb 00Ch,01Ah,028h,036h,01Ah,01Eh,022h,006h,029h,018h,027h,036h,01Bh,020h,025h,00Ah
        defb 01Ch,02Ch,01Ch,02Ch,032h,018h,01Eh,024h,00Fh,020h,011h,022h,029h,010h,017h,01Eh
        defb 002h,014h,026h,018h,020h,008h,010h,01Dh,01Ah,008h,01Bh,00Eh,017h,000h,00Eh,01Ch
        defb 01Dh,009h,015h,021h,023h,005h,007h,00Eh,01Ah,027h,014h,021h,024h,027h,00Ah,00Dh
        defb 017h,025h,033h,021h,025h,029h,00Dh,011h,014h,023h,032h,021h,026h,02Bh,010h,015h
        defb 027h,017h,027h,037h,01Dh,023h,029h,00Fh,01Ah,00Bh,01Ch,02Dh,014h,01Bh,022h,009h
        defb 00Dh,01Fh,011h,023h,00Bh,013h,01Bh,008h,005h,013h,006h,019h,022h,00Bh,019h,007h
        defb 008h,014h,020h,02Ch,00Eh,010h,012h,019h,005h,012h,01Fh,02Ch,00Fh,012h,015h,018h
        defb 022h,010h,01Eh,02Ch,030h,014h,018h,01Ch,01Fh,02Eh,01Dh,02Ch,031h,016h,01Bh,020h
        defb 012h,022h,032h,022h,028h,02Eh,014h,01Ah,005h,016h,027h,018h,01Fh,026h,00Dh,014h
        defb 018h,00Ah,01Ch,02Eh,016h,01Eh,006h,013h,010h,01Eh,011h,024h,00Dh,016h,004h,012h
        defb 013h,01Fh,00Bh,017h,019h,01Bh,01Dh,004h,010h,01Dh,02Ah,017h,01Ah,01Dh,020h,003h
        defb 00Dh,01Bh,029h,037h,01Bh,01Fh,023h,007h,02Ah,019h,028h,037h,01Ch,021h,026h,00Bh
        defb 01Dh,02Dh,01Dh,02Dh,033h,019h,01Fh,005h,010h,021h,012h,023h,02Ah,011h,018h,01Fh
        defb 003h,015h,027h,019h,021h,009h,011h,01Eh,01Bh,009h,01Ch,00Fh,018h,001h,00Fh,01Dh

Z180Neuro64:
        defb 000h,00Ch,018h,024h,026h,008h,00Ah,011h,01Dh,00Ah,017h,024h,027h,00Ah,00Dh,010h
        defb 01Ah,028h,016h,024h,028h,02Ch,010h,014h,017h,026h,035h,024h,029h,02Eh,013h,018h
        defb 00Ah,01Ah,02Ah,01Ah,020h,026h,00Ch,012h,01Dh,00Eh,01Fh,030h,017h,01Eh,005h,00Ch
        defb 010h,022h,014h,026h,00Eh,016h,01Eh,00Bh,008h,016h,009h,01Ch,005h,00Eh,01Ch,00Ah
        defb 00Bh,017h,023h,00Fh,011h,013h,015h,01Ch,008h,015h,022h,02Fh,012h,015h,018h,01Bh
        defb 025h,013h,021h,02Fh,033h,017h,01Bh,01Fh,022h,031h,020h,02Fh,034h,019h,01Eh,023h
        defb 015h,025h,015h,025h,02Bh,011h,017h,01Dh,008h,019h,02Ah,01Bh,022h,029h,010h,017h
        defb 01Bh,00Dh,01Fh,011h,019h,021h,009h,016h,013h,001h,014h,027h,010h,019h,007h,015h
        defb 016h,022h,00Eh,01Ah,01Ch,01Eh,000h,007h,013h,020h,02Dh,01Ah,01Dh,020h,023h,006h
        defb 010h,01Eh,02Ch,01Ah,01Eh,022h,026h,00Ah,02Dh,01Ch,02Bh,03Ah,01Fh,024h,029h,00Eh
        defb 020h,010h,020h,030h,016h,01Ch,022h,008h,013h,024h,015h,026h,02Dh,014h,01Bh,002h
        defb 006h,018h,00Ah,01Ch,024h,00Ch,014h,001h,01Eh,00Ch,01Fh,012h,01Bh,004h,012h,000h
        defb 001h,00Dh,019h,025h,027h,009h,00Bh,012h,01Eh,00Bh,018h,025h,028h,00Bh,00Eh,011h
        defb 01Bh,029h,017h,025h,029h,02Dh,011h,015h,018h,027h,036h,025h,02Ah,02Fh,014h,019h
        defb 00Bh,01Bh,02Bh,01Bh,021h,027h,00Dh,013h,01Eh,00Fh,020h,031h,018h,01Fh,006h,00Dh
        defb 011h,023h,015h,027h,00Fh,017h,01Fh,00Ch,009h,017h,00Ah,01Dh,006h,00Fh,01Dh,00Bh

Z180Neuro65:
        defb 00Eh,01Ah,026h,012h,014h,016h,018h,01Fh,00Bh,018h,025h,032h,015h,018h,01Bh,01Eh
        defb 028h,016h,024h,032h,016h,01Ah,01Eh,022h,025h,014h,023h,032h,037h,01Ch,021h,026h
        defb 018h,028h,018h,028h,02Eh,014h,01Ah,020h,00Bh,01Ch,02Dh,01Eh,025h,00Ch,013h,01Ah
        defb 01Eh,010h,022h,014h,01Ch,024h,00Ch,019h,016h,004h,017h,00Ah,013h,01Ch,00Ah,018h
        defb 019h,005h,011h,01Dh,01Fh,021h,003h,00Ah,016h,023h,010h,01Dh,020h,023h,006h,009h
        defb 013h,021h,02Fh,01Dh,021h,025h,029h,00Dh,010h,01Fh,02Eh,03Dh,022h,027h,02Ch,011h
        defb 023h,013h,023h,033h,019h,01Fh,025h,00Bh,016h,027h,018h,029h,010h,017h,01Eh,005h
        defb 009h,01Bh,00Dh,01Fh,027h,00Fh,017h,004h,001h,00Fh,022h,015h,01Eh,007h,015h,003h
        defb 004h,010h,01Ch,028h,00Ah,00Ch,00Eh,015h,021h,00Eh,01Bh,028h,02Bh,00Eh,011h,014h
        defb 01Eh,02Ch,01Ah,028h,02Ch,010h,014h,018h,01Bh,02Ah,019h,028h,02Dh,032h,017h,01Ch
        defb 00Eh,01Eh,02Eh,01Eh,024h,02Ah,010h,016h,021h,012h,023h,014h,01Bh,022h,009h,010h
        defb 014h,006h,018h,02Ah,012h,01Ah,002h,00Fh,00Ch,01Ah,00Dh,020h,009h,012h,000h,00Eh
        defb 00Fh,01Bh,027h,013h,015h,017h,019h,000h,00Ch,019h,026h,033h,016h,019h,01Ch,01Fh
        defb 029h,017h,025h,033h,017h,01Bh,01Fh,023h,026h,015h,024h,033h,038h,01Dh,022h,027h
        defb 019h,029h,019h,029h,02Fh,015h,01Bh,021h,00Ch,01Dh,02Eh,01Fh,026h,00Dh,014h,01Bh
        defb 01Fh,011h,023h,015h,01Dh,005h,00Dh,01Ah,017h,005h,018h,00Bh,014h,01Dh,00Bh,019h

Z180Neuro66:
        defb 01Ch,008h,014h,020h,022h,024h,006h,00Dh,019h,026h,013h,020h,023h,026h,009h,00Ch
        defb 016h,024h,032h,020h,024h,028h,00Ch,010h,013h,022h,031h,020h,025h,02Ah,00Fh,014h
        defb 026h,016h,026h,036h,01Ch,022h,028h,00Eh,019h,00Ah,01Bh,02Ch,013h,01Ah,021h,008h
        defb 00Ch,01Eh,010h,022h,00Ah,012h,01Ah,007h,004h,012h,005h,018h,021h,00Ah,018h,006h
        defb 007h,013h,01Fh,02Bh,00Dh,00Fh,011h,018h,024h,011h,01Eh,02Bh,02Eh,011h,014h,017h
        defb 021h,00Fh,01Dh,02Bh,02Fh,013h,017h,01Bh,01Eh,02Dh,01Ch,02Bh,030h,015h,01Ah,01Fh
        defb 011h,021h,031h,021h,027h,02Dh,013h,019h,024h,015h,026h,017h,01Eh,025h,00Ch,013h
        defb 017h,009h,01Bh,02Dh,015h,01Dh,005h,012h,00Fh,01Dh,010h,023h,00Ch,015h,003h,011h
        defb 012h,01Eh,00Ah,016h,018h,01Ah,01Ch,003h,00Fh,01Ch,029h,016h,019h,01Ch,01Fh,002h
        defb 00Ch,01Ah,028h,036h,01Ah,01Eh,022h,006h,029h,018h,027h,036h,01Bh,020h,025h,00Ah
        defb 01Ch,02Ch,01Ch,02Ch,032h,018h,01Eh,024h,00Fh,020h,011h,022h,029h,010h,017h,01Eh
        defb 002h,014h,026h,018h,020h,008h,010h,01Dh,01Ah,008h,01Bh,00Eh,017h,000h,00Eh,01Ch
        defb 01Dh,009h,015h,021h,023h,005h,007h,00Eh,01Ah,027h,014h,021h,024h,027h,00Ah,00Dh
        defb 017h,025h,033h,021h,025h,029h,00Dh,011h,014h,023h,032h,021h,026h,02Bh,010h,015h
        defb 027h,017h,027h,037h,01Dh,023h,029h,00Fh,01Ah,00Bh,01Ch,02Dh,014h,01Bh,022h,009h
        defb 00Dh,01Fh,011h,023h,00Bh,013h,01Bh,008h,005h,013h,006h,019h,022h,00Bh,019h,007h

Z180Neuro67:
        defb 00Ah,016h,022h,02Eh,010h,012h,014h,01Bh,007h,014h,021h,02Eh,011h,014h,017h,01Ah
        defb 024h,012h,020h,02Eh,032h,016h,01Ah,01Eh,021h,030h,01Fh,02Eh,033h,018h,01Dh,022h
        defb 014h,024h,014h,024h,02Ah,010h,016h,01Ch,007h,018h,029h,01Ah,021h,028h,00Fh,016h
        defb 01Ah,00Ch,01Eh,010h,018h,020h,008h,015h,012h,000h,013h,026h,00Fh,018h,006h,014h
        defb 015h,021h,00Dh,019h,01Bh,01Dh,01Fh,006h,012h,01Fh,02Ch,019h,01Ch,01Fh,022h,005h
        defb 00Fh,01Dh,02Bh,019h,01Dh,021h,025h,009h,02Ch,01Bh,02Ah,039h,01Eh,023h,028h,00Dh
        defb 01Fh,00Fh,01Fh,02Fh,015h,01Bh,021h,007h,012h,023h,014h,025h,02Ch,013h,01Ah,001h
        defb 005h,017h,029h,01Bh,023h,00Bh,013h,000h,01Dh,00Bh,01Eh,011h,01Ah,003h,011h,01Fh
        defb 000h,00Ch,018h,024h,026h,008h,00Ah,011h,01Dh,00Ah,017h,024h,027h,00Ah,00Dh,010h
        defb 01Ah,028h,016h,024h,028h,02Ch,010h,014h,017h,026h,035h,024h,029h,02Eh,013h,018h
        defb 00Ah,01Ah,02Ah,01Ah,020h,026h,00Ch,012h,01Dh,00Eh,01Fh,030h,017h,01Eh,005h,00Ch
        defb 010h,022h,014h,026h,00Eh,016h,01Eh,00Bh,008h,016h,009h,01Ch,005h,00Eh,01Ch,00Ah
        defb 00Bh,017h,023h,00Fh,011h,013h,015h,01Ch,008h,015h,022h,02Fh,012h,015h,018h,01Bh
        defb 025h,013h,021h,02Fh,033h,017h,01Bh,01Fh,022h,031h,020h,02Fh,034h,019h,01Eh,023h
        defb 015h,025h,015h,025h,02Bh,011h,017h,01Dh,008h,019h,02Ah,01Bh,022h,029h,010h,017h
        defb 01Bh,00Dh,01Fh,011h,019h,021h,009h,016h,013h,001h,014h,027h,010h,019h,007h,015h

Z180Neuro68:
        defb 018h,024h,010h,01Ch,01Eh,020h,002h,009h,015h,022h,00Fh,01Ch,01Fh,022h,005h,008h
        defb 012h,020h,02Eh,01Ch,020h,024h,028h,00Ch,00Fh,01Eh,02Dh,03Ch,021h,026h,02Bh,010h
        defb 022h,012h,022h,032h,018h,01Eh,024h,00Ah,015h,026h,017h,028h,00Fh,016h,01Dh,004h
        defb 008h,01Ah,00Ch,01Eh,026h,00Eh,016h,003h,000h,00Eh,021h,014h,01Dh,006h,014h,002h
        defb 003h,00Fh,01Bh,027h,029h,00Bh,00Dh,014h,020h,00Dh,01Ah,027h,02Ah,00Dh,010h,013h
        defb 01Dh,02Bh,019h,027h,02Bh,00Fh,013h,017h,01Ah,029h,038h,027h,02Ch,031h,016h,01Bh
        defb 00Dh,01Dh,02Dh,01Dh,023h,029h,00Fh,015h,020h,011h,022h,033h,01Ah,021h,008h,00Fh
        defb 013h,005h,017h,029h,011h,019h,001h,00Eh,00Bh,019h,00Ch,01Fh,008h,011h,01Fh,00Dh
        defb 00Eh,01Ah,026h,012h,014h,016h,018h,01Fh,00Bh,018h,025h,032h,015h,018h,01Bh,01Eh
        defb 028h,016h,024h,032h,016h,01Ah,01Eh,022h,025h,014h,023h,032h,037h,01Ch,021h,026h
        defb 018h,028h,018h,028h,02Eh,014h,01Ah,020h,00Bh,01Ch,02Dh,01Eh,025h,00Ch,013h,01Ah
        defb 01Eh,010h,022h,014h,01Ch,024h,00Ch,019h,016h,004h,017h,00Ah,013h,01Ch,00Ah,018h
        defb 019h,005h,011h,01Dh,01Fh,021h,003h,00Ah,016h,023h,010h,01Dh,020h,023h,006h,009h
        defb 013h,021h,02Fh,01Dh,021h,025h,029h,00Dh,010h,01Fh,02Eh,03Dh,022h,027h,02Ch,011h
        defb 023h,013h,023h,033h,019h,01Fh,025h,00Bh,016h,027h,018h,029h,010h,017h,01Eh,005h
        defb 009h,01Bh,00Dh,01Fh,027h,00Fh,017h,004h,001h,00Fh,022h,015h,01Eh,007h,015h,003h

Z180Neuro69:
        defb 006h,012h,01Eh,02Ah,00Ch,00Eh,010h,017h,023h,010h,01Dh,02Ah,02Dh,010h,013h,016h
        defb 020h,02Eh,01Ch,02Ah,02Eh,012h,016h,01Ah,01Dh,02Ch,01Bh,02Ah,02Fh,014h,019h,01Eh
        defb 010h,020h,030h,020h,026h,02Ch,012h,018h,023h,014h,025h,016h,01Dh,024h,00Bh,012h
        defb 016h,008h,01Ah,02Ch,014h,01Ch,004h,011h,00Eh,01Ch,00Fh,022h,00Bh,014h,002h,010h
        defb 011h,01Dh,029h,015h,017h,019h,01Bh,002h,00Eh,01Bh,028h,015h,018h,01Bh,01Eh,001h
        defb 00Bh,019h,027h,035h,019h,01Dh,021h,005h,028h,017h,026h,035h,01Ah,01Fh,024h,029h
        defb 01Bh,02Bh,01Bh,02Bh,031h,017h,01Dh,023h,00Eh,01Fh,010h,021h,028h,00Fh,016h,01Dh
        defb 001h,013h,025h,017h,01Fh,007h,00Fh,01Ch,019h,007h,01Ah,00Dh,016h,01Fh,00Dh,01Bh
        defb 01Ch,008h,014h,020h,022h,024h,006h,00Dh,019h,026h,013h,020h,023h,026h,009h,00Ch
        defb 016h,024h,032h,020h,024h,028h,00Ch,010h,013h,022h,031h,020h,025h,02Ah,00Fh,014h
        defb 026h,016h,026h,036h,01Ch,022h,028h,00Eh,019h,00Ah,01Bh,02Ch,013h,01Ah,021h,008h
        defb 00Ch,01Eh,010h,022h,00Ah,012h,01Ah,007h,004h,012h,005h,018h,021h,00Ah,018h,006h
        defb 007h,013h,01Fh,02Bh,00Dh,00Fh,011h,018h,024h,011h,01Eh,02Bh,02Eh,011h,014h,017h
        defb 021h,00Fh,01Dh,02Bh,02Fh,013h,017h,01Bh,01Eh,02Dh,01Ch,02Bh,030h,015h,01Ah,01Fh
        defb 011h,021h,031h,021h,027h,02Dh,013h,019h,024h,015h,026h,017h,01Eh,025h,00Ch,013h
        defb 017h,009h,01Bh,02Dh,015h,01Dh,005h,012h,00Fh,01Dh,010h,023h,00Ch,015h,003h,011h

Z180Neuro70:
        defb 014h,020h,00Ch,018h,01Ah,01Ch,01Eh,005h,011h,01Eh,02Bh,018h,01Bh,01Eh,021h,004h
        defb 00Eh,01Ch,02Ah,038h,01Ch,020h,024h,008h,02Bh,01Ah,029h,038h,01Dh,022h,027h,00Ch
        defb 01Eh,02Eh,01Eh,02Eh,014h,01Ah,020h,006h,011h,022h,013h,024h,02Bh,012h,019h,000h
        defb 004h,016h,028h,01Ah,022h,00Ah,012h,01Fh,01Ch,00Ah,01Dh,010h,019h,002h,010h,01Eh
        defb 01Fh,00Bh,017h,023h,025h,007h,009h,010h,01Ch,029h,016h,023h,026h,029h,00Ch,00Fh
        defb 019h,027h,015h,023h,027h,02Bh,00Fh,013h,016h,025h,034h,023h,028h,02Dh,012h,017h
        defb 029h,019h,029h,019h,01Fh,025h,00Bh,011h,01Ch,00Dh,01Eh,02Fh,016h,01Dh,024h,00Bh
        defb 00Fh,021h,013h,025h,00Dh,015h,01Dh,00Ah,007h,015h,008h,01Bh,024h,00Dh,01Bh,009h
        defb 00Ah,016h,022h,02Eh,010h,012h,014h,01Bh,007h,014h,021h,02Eh,011h,014h,017h,01Ah
        defb 024h,012h,020h,02Eh,032h,016h,01Ah,01Eh,021h,030h,01Fh,02Eh,033h,018h,01Dh,022h
        defb 014h,024h,014h,024h,02Ah,010h,016h,01Ch,007h,018h,029h,01Ah,021h,028h,00Fh,016h
        defb 01Ah,00Ch,01Eh,010h,018h,020h,008h,015h,012h,000h,013h,026h,00Fh,018h,006h,014h
        defb 015h,021h,00Dh,019h,01Bh,01Dh,01Fh,006h,012h,01Fh,02Ch,019h,01Ch,01Fh,022h,005h
        defb 00Fh,01Dh,02Bh,019h,01Dh,021h,025h,009h,02Ch,01Bh,02Ah,039h,01Eh,023h,028h,00Dh
        defb 01Fh,00Fh,01Fh,02Fh,015h,01Bh,021h,007h,012h,023h,014h,025h,02Ch,013h,01Ah,001h
        defb 005h,017h,029h,01Bh,023h,00Bh,013h,000h,01Dh,00Bh,01Eh,011h,01Ah,003h,011h,01Fh

Z180Neuro71:
        defb 002h,00Eh,01Ah,026h,028h,00Ah,00Ch,013h,01Fh,00Ch,019h,026h,029h,00Ch,00Fh,012h
        defb 01Ch,02Ah,018h,026h,02Ah,02Eh,012h,016h,019h,028h,037h,026h,02Bh,030h,015h,01Ah
        defb 00Ch,01Ch,02Ch,01Ch,022h,028h,00Eh,014h,01Fh,010h,021h,032h,019h,020h,007h,00Eh
        defb 012h,024h,016h,028h,010h,018h,000h,00Dh,00Ah,018h,00Bh,01Eh,007h,010h,01Eh,00Ch
        defb 00Dh,019h,025h,011h,013h,015h,017h,01Eh,00Ah,017h,024h,031h,014h,017h,01Ah,01Dh
        defb 027h,015h,023h,031h,015h,019h,01Dh,021h,024h,033h,022h,031h,036h,01Bh,020h,025h
        defb 017h,027h,017h,027h,02Dh,013h,019h,01Fh,00Ah,01Bh,02Ch,01Dh,024h,00Bh,012h,019h
        defb 01Dh,00Fh,021h,013h,01Bh,023h,00Bh,018h,015h,003h,016h,029h,012h,01Bh,009h,017h
        defb 018h,024h,010h,01Ch,01Eh,020h,002h,009h,015h,022h,00Fh,01Ch,01Fh,022h,005h,008h
        defb 012h,020h,02Eh,01Ch,020h,024h,028h,00Ch,00Fh,01Eh,02Dh,03Ch,021h,026h,02Bh,010h
        defb 022h,012h,022h,032h,018h,01Eh,024h,00Ah,015h,026h,017h,028h,00Fh,016h,01Dh,004h
        defb 008h,01Ah,00Ch,01Eh,026h,00Eh,016h,003h,000h,00Eh,021h,014h,01Dh,006h,014h,002h
        defb 003h,00Fh,01Bh,027h,029h,00Bh,00Dh,014h,020h,00Dh,01Ah,027h,02Ah,00Dh,010h,013h
        defb 01Dh,02Bh,019h,027h,02Bh,00Fh,013h,017h,01Ah,029h,038h,027h,02Ch,031h,016h,01Bh
        defb 00Dh,01Dh,02Dh,01Dh,023h,029h,00Fh,015h,020h,011h,022h,033h,01Ah,021h,008h,00Fh
        defb 013h,005h,017h,029h,011h,019h,001h,00Eh,00Bh,019h,00Ch,01Fh,008h,011h,01Fh,00Dh

Z180Neuro72:
        defb 010h,01Ch,028h,014h,016h,018h,01Ah,001h,00Dh,01Ah,027h,014h,017h,01Ah,01Dh,000h
        defb 00Ah,018h,026h,034h,018h,01Ch,020h,024h,027h,016h,025h,034h,019h,01Eh,023h,028h
        defb 01Ah,02Ah,01Ah,02Ah,030h,016h,01Ch,022h,00Dh,01Eh,00Fh,020h,027h,00Eh,015h,01Ch
        defb 000h,012h,024h,016h,01Eh,006h,00Eh,01Bh,018h,006h,019h,00Ch,015h,01Eh,00Ch,01Ah
        defb 01Bh,007h,013h,01Fh,021h,023h,005h,00Ch,018h,025h,012h,01Fh,022h,025h,008h,00Bh
        defb 015h,023h,031h,01Fh,023h,027h,00Bh,00Fh,012h,021h,030h,01Fh,024h,029h,02Eh,013h
        defb 025h,015h,025h,035h,01Bh,021h,027h,00Dh,018h,029h,01Ah,02Bh,012h,019h,020h,007h
        defb 00Bh,01Dh,00Fh,021h,029h,011h,019h,006h,003h,011h,024h,017h,020h,009h,017h,005h
        defb 006h,012h,01Eh,02Ah,00Ch,00Eh,010h,017h,023h,010h,01Dh,02Ah,02Dh,010h,013h,016h
        defb 020h,02Eh,01Ch,02Ah,02Eh,012h,016h,01Ah,01Dh,02Ch,01Bh,02Ah,02Fh,014h,019h,01Eh
        defb 010h,020h,030h,020h,026h,02Ch,012h,018h,023h,014h,025h,016h,01Dh,024h,00Bh,012h
        defb 016h,008h,01Ah,02Ch,014h,01Ch,004h,011h,00Eh,01Ch,00Fh,022h,00Bh,014h,002h,010h
        defb 011h,01Dh,029h,015h,017h,019h,01Bh,002h,00Eh,01Bh,028h,015h,018h,01Bh,01Eh,001h
        defb 00Bh,019h,027h,035h,019h,01Dh,021h,005h,028h,017h,026h,035h,01Ah,01Fh,024h,029h
        defb 01Bh,02Bh,01Bh,02Bh,031h,017h,01Dh,023h,00Eh,01Fh,010h,021h,028h,00Fh,016h,01Dh
        defb 001h,013h,025h,017h,01Fh,007h,00Fh,01Ch,019h,007h,01Ah,00Dh,016h,01Fh,00Dh,01Bh

Z180Neuro73:
        defb 01Eh,00Ah,016h,022h,024h,006h,008h,00Fh,01Bh,028h,015h,022h,025h,028h,00Bh,00Eh
        defb 018h,026h,014h,022h,026h,02Ah,00Eh,012h,015h,024h,033h,022h,027h,02Ch,011h,016h
        defb 028h,018h,028h,038h,01Eh,024h,00Ah,010h,01Bh,00Ch,01Dh,02Eh,015h,01Ch,023h,00Ah
        defb 00Eh,020h,012h,024h,00Ch,014h,01Ch,009h,006h,014h,007h,01Ah,023h,00Ch,01Ah,008h
        defb 009h,015h,021h,02Dh,00Fh,011h,013h,01Ah,006h,013h,020h,02Dh,010h,013h,016h,019h
        defb 023h,011h,01Fh,02Dh,031h,015h,019h,01Dh,020h,02Fh,01Eh,02Dh,032h,017h,01Ch,021h
        defb 013h,023h,033h,023h,029h,00Fh,015h,01Bh,006h,017h,028h,019h,020h,027h,00Eh,015h
        defb 019h,00Bh,01Dh,00Fh,017h,01Fh,007h,014h,011h,01Fh,012h,025h,00Eh,017h,005h,013h
        defb 014h,020h,00Ch,018h,01Ah,01Ch,01Eh,005h,011h,01Eh,02Bh,018h,01Bh,01Eh,021h,004h
        defb 00Eh,01Ch,02Ah,038h,01Ch,020h,024h,008h,02Bh,01Ah,029h,038h,01Dh,022h,027h,00Ch
        defb 01Eh,02Eh,01Eh,02Eh,014h,01Ah,020h,006h,011h,022h,013h,024h,02Bh,012h,019h,000h
        defb 004h,016h,028h,01Ah,022h,00Ah,012h,01Fh,01Ch,00Ah,01Dh,010h,019h,002h,010h,01Eh
        defb 01Fh,00Bh,017h,023h,025h,007h,009h,010h,01Ch,029h,016h,023h,026h,029h,00Ch,00Fh
        defb 019h,027h,015h,023h,027h,02Bh,00Fh,013h,016h,025h,034h,023h,028h,02Dh,012h,017h
        defb 029h,019h,029h,019h,01Fh,025h,00Bh,011h,01Ch,00Dh,01Eh,02Fh,016h,01Dh,024h,00Bh
        defb 00Fh,021h,013h,025h,00Dh,015h,01Dh,00Ah,007h,015h,008h,01Bh,024h,00Dh,01Bh,009h

Z180Neuro74:
        defb 00Ch,018h,024h,010h,012h,014h,016h,01Dh,009h,016h,023h,030h,013h,016h,019h,01Ch
        defb 026h,014h,022h,030h,014h,018h,01Ch,020h,023h,032h,021h,030h,035h,01Ah,01Fh,024h
        defb 016h,026h,016h,026h,02Ch,012h,018h,01Eh,009h,01Ah,02Bh,01Ch,023h,00Ah,011h,018h
        defb 01Ch,00Eh,020h,012h,01Ah,022h,00Ah,017h,014h,002h,015h,028h,011h,01Ah,008h,016h
        defb 017h,023h,00Fh,01Bh,01Dh,01Fh,001h,008h,014h,021h,02Eh,01Bh,01Eh,021h,024h,007h
        defb 011h,01Fh,02Dh,01Bh,01Fh,023h,027h,00Bh,02Eh,01Dh,02Ch,03Bh,020h,025h,02Ah,00Fh
        defb 021h,011h,021h,031h,017h,01Dh,023h,009h,014h,025h,016h,027h,02Eh,015h,01Ch,003h
        defb 007h,019h,00Bh,01Dh,025h,00Dh,015h,002h,01Fh,00Dh,020h,013h,01Ch,005h,013h,001h
        defb 002h,00Eh,01Ah,026h,028h,00Ah,00Ch,013h,01Fh,00Ch,019h,026h,029h,00Ch,00Fh,012h
        defb 01Ch,02Ah,018h,026h,02Ah,02Eh,012h,016h,019h,028h,037h,026h,02Bh,030h,015h,01Ah
        defb 00Ch,01Ch,02Ch,01Ch,022h,028h,00Eh,014h,01Fh,010h,021h,032h,019h,020h,007h,00Eh
        defb 012h,024h,016h,028h,010h,018h,000h,00Dh,00Ah,018h,00Bh,01Eh,007h,010h,01Eh,00Ch
        defb 00Dh,019h,025h,011h,013h,015h,017h,01Eh,00Ah,017h,024h,031h,014h,017h,01Ah,01Dh
        defb 027h,015h,023h,031h,015h,019h,01Dh,021h,024h,033h,022h,031h,036h,01Bh,020h,025h
        defb 017h,027h,017h,027h,02Dh,013h,019h,01Fh,00Ah,01Bh,02Ch,01Dh,024h,00Bh,012h,019h
        defb 01Dh,00Fh,021h,013h,01Bh,023h,00Bh,018h,015h,003h,016h,029h,012h,01Bh,009h,017h

Z180Neuro75:
        defb 01Ah,006h,012h,01Eh,020h,022h,004h,00Bh,017h,024h,011h,01Eh,021h,024h,007h,00Ah
        defb 014h,022h,030h,01Eh,022h,026h,00Ah,00Eh,011h,020h,02Fh,01Eh,023h,028h,02Dh,012h
        defb 024h,014h,024h,034h,01Ah,020h,026h,00Ch,017h,028h,019h,02Ah,011h,018h,01Fh,006h
        defb 00Ah,01Ch,00Eh,020h,028h,010h,018h,005h,002h,010h,023h,016h,01Fh,008h,016h,004h
        defb 005h,011h,01Dh,029h,00Bh,00Dh,00Fh,016h,022h,00Fh,01Ch,029h,02Ch,00Fh,012h,015h
        defb 01Fh,02Dh,01Bh,029h,02Dh,011h,015h,019h,01Ch,02Bh,01Ah,029h,02Eh,033h,018h,01Dh
        defb 00Fh,01Fh,02Fh,01Fh,025h,02Bh,011h,017h,022h,013h,024h,015h,01Ch,023h,00Ah,011h
        defb 015h,007h,019h,02Bh,013h,01Bh,003h,010h,00Dh,01Bh,00Eh,021h,00Ah,013h,001h,00Fh
        defb 010h,01Ch,028h,014h,016h,018h,01Ah,001h,00Dh,01Ah,027h,014h,017h,01Ah,01Dh,000h
        defb 00Ah,018h,026h,034h,018h,01Ch,020h,024h,027h,016h,025h,034h,019h,01Eh,023h,028h
        defb 01Ah,02Ah,01Ah,02Ah,030h,016h,01Ch,022h,00Dh,01Eh,00Fh,020h,027h,00Eh,015h,01Ch
        defb 000h,012h,024h,016h,01Eh,006h,00Eh,01Bh,018h,006h,019h,00Ch,015h,01Eh,00Ch,01Ah
        defb 01Bh,007h,013h,01Fh,021h,023h,005h,00Ch,018h,025h,012h,01Fh,022h,025h,008h,00Bh
        defb 015h,023h,031h,01Fh,023h,027h,00Bh,00Fh,012h,021h,030h,01Fh,024h,029h,02Eh,013h
        defb 025h,015h,025h,035h,01Bh,021h,027h,00Dh,018h,029h,01Ah,02Bh,012h,019h,020h,007h
        defb 00Bh,01Dh,00Fh,021h,029h,011h,019h,006h,003h,011h,024h,017h,020h,009h,017h,005h

Z180Neuro76:
        defb 008h,014h,020h,02Ch,00Eh,010h,012h,019h,005h,012h,01Fh,02Ch,00Fh,012h,015h,018h
        defb 022h,010h,01Eh,02Ch,030h,014h,018h,01Ch,01Fh,02Eh,01Dh,02Ch,031h,016h,01Bh,020h
        defb 012h,022h,032h,022h,028h,02Eh,014h,01Ah,005h,016h,027h,018h,01Fh,026h,00Dh,014h
        defb 018h,00Ah,01Ch,02Eh,016h,01Eh,006h,013h,010h,01Eh,011h,024h,00Dh,016h,004h,012h
        defb 013h,01Fh,00Bh,017h,019h,01Bh,01Dh,004h,010h,01Dh,02Ah,017h,01Ah,01Dh,020h,003h
        defb 00Dh,01Bh,029h,037h,01Bh,01Fh,023h,007h,02Ah,019h,028h,037h,01Ch,021h,026h,00Bh
        defb 01Dh,02Dh,01Dh,02Dh,033h,019h,01Fh,005h,010h,021h,012h,023h,02Ah,011h,018h,01Fh
        defb 003h,015h,027h,019h,021h,009h,011h,01Eh,01Bh,009h,01Ch,00Fh,018h,001h,00Fh,01Dh
        defb 01Eh,00Ah,016h,022h,024h,006h,008h,00Fh,01Bh,028h,015h,022h,025h,028h,00Bh,00Eh
        defb 018h,026h,014h,022h,026h,02Ah,00Eh,012h,015h,024h,033h,022h,027h,02Ch,011h,016h
        defb 028h,018h,028h,038h,01Eh,024h,00Ah,010h,01Bh,00Ch,01Dh,02Eh,015h,01Ch,023h,00Ah
        defb 00Eh,020h,012h,024h,00Ch,014h,01Ch,009h,006h,014h,007h,01Ah,023h,00Ch,01Ah,008h
        defb 009h,015h,021h,02Dh,00Fh,011h,013h,01Ah,006h,013h,020h,02Dh,010h,013h,016h,019h
        defb 023h,011h,01Fh,02Dh,031h,015h,019h,01Dh,020h,02Fh,01Eh,02Dh,032h,017h,01Ch,021h
        defb 013h,023h,033h,023h,029h,00Fh,015h,01Bh,006h,017h,028h,019h,020h,027h,00Eh,015h
        defb 019h,00Bh,01Dh,00Fh,017h,01Fh,007h,014h,011h,01Fh,012h,025h,00Eh,017h,005h,013h

Z180Neuro77:
        defb 016h,022h,00Eh,01Ah,01Ch,01Eh,000h,007h,013h,020h,02Dh,01Ah,01Dh,020h,023h,006h
        defb 010h,01Eh,02Ch,01Ah,01Eh,022h,026h,00Ah,02Dh,01Ch,02Bh,03Ah,01Fh,024h,029h,00Eh
        defb 020h,010h,020h,030h,016h,01Ch,022h,008h,013h,024h,015h,026h,02Dh,014h,01Bh,002h
        defb 006h,018h,00Ah,01Ch,024h,00Ch,014h,001h,01Eh,00Ch,01Fh,012h,01Bh,004h,012h,000h
        defb 001h,00Dh,019h,025h,027h,009h,00Bh,012h,01Eh,00Bh,018h,025h,028h,00Bh,00Eh,011h
        defb 01Bh,029h,017h,025h,029h,02Dh,011h,015h,018h,027h,036h,025h,02Ah,02Fh,014h,019h
        defb 00Bh,01Bh,02Bh,01Bh,021h,027h,00Dh,013h,01Eh,00Fh,020h,031h,018h,01Fh,006h,00Dh
        defb 011h,023h,015h,027h,00Fh,017h,01Fh,00Ch,009h,017h,00Ah,01Dh,006h,00Fh,01Dh,00Bh
        defb 00Ch,018h,024h,010h,012h,014h,016h,01Dh,009h,016h,023h,030h,013h,016h,019h,01Ch
        defb 026h,014h,022h,030h,014h,018h,01Ch,020h,023h,032h,021h,030h,035h,01Ah,01Fh,024h
        defb 016h,026h,016h,026h,02Ch,012h,018h,01Eh,009h,01Ah,02Bh,01Ch,023h,00Ah,011h,018h
        defb 01Ch,00Eh,020h,012h,01Ah,022h,00Ah,017h,014h,002h,015h,028h,011h,01Ah,008h,016h
        defb 017h,023h,00Fh,01Bh,01Dh,01Fh,001h,008h,014h,021h,02Eh,01Bh,01Eh,021h,024h,007h
        defb 011h,01Fh,02Dh,01Bh,01Fh,023h,027h,00Bh,02Eh,01Dh,02Ch,03Bh,020h,025h,02Ah,00Fh
        defb 021h,011h,021h,031h,017h,01Dh,023h,009h,014h,025h,016h,027h,02Eh,015h,01Ch,003h
        defb 007h,019h,00Bh,01Dh,025h,00Dh,015h,002h,01Fh,00Dh,020h,013h,01Ch,005h,013h,001h

Z180Neuro78:
        defb 004h,010h,01Ch,028h,00Ah,00Ch,00Eh,015h,021h,00Eh,01Bh,028h,02Bh,00Eh,011h,014h
        defb 01Eh,02Ch,01Ah,028h,02Ch,010h,014h,018h,01Bh,02Ah,019h,028h,02Dh,032h,017h,01Ch
        defb 00Eh,01Eh,02Eh,01Eh,024h,02Ah,010h,016h,021h,012h,023h,014h,01Bh,022h,009h,010h
        defb 014h,006h,018h,02Ah,012h,01Ah,002h,00Fh,00Ch,01Ah,00Dh,020h,009h,012h,000h,00Eh
        defb 00Fh,01Bh,027h,013h,015h,017h,019h,000h,00Ch,019h,026h,033h,016h,019h,01Ch,01Fh
        defb 029h,017h,025h,033h,017h,01Bh,01Fh,023h,026h,015h,024h,033h,038h,01Dh,022h,027h
        defb 019h,029h,019h,029h,02Fh,015h,01Bh,021h,00Ch,01Dh,02Eh,01Fh,026h,00Dh,014h,01Bh
        defb 01Fh,011h,023h,015h,01Dh,005h,00Dh,01Ah,017h,005h,018h,00Bh,014h,01Dh,00Bh,019h
        defb 01Ah,006h,012h,01Eh,020h,022h,004h,00Bh,017h,024h,011h,01Eh,021h,024h,007h,00Ah
        defb 014h,022h,030h,01Eh,022h,026h,00Ah,00Eh,011h,020h,02Fh,01Eh,023h,028h,02Dh,012h
        defb 024h,014h,024h,034h,01Ah,020h,026h,00Ch,017h,028h,019h,02Ah,011h,018h,01Fh,006h
        defb 00Ah,01Ch,00Eh,020h,028h,010h,018h,005h,002h,010h,023h,016h,01Fh,008h,016h,004h
        defb 005h,011h,01Dh,029h,00Bh,00Dh,00Fh,016h,022h,00Fh,01Ch,029h,02Ch,00Fh,012h,015h
        defb 01Fh,02Dh,01Bh,029h,02Dh,011h,015h,019h,01Ch,02Bh,01Ah,029h,02Eh,033h,018h,01Dh
        defb 00Fh,01Fh,02Fh,01Fh,025h,02Bh,011h,017h,022h,013h,024h,015h,01Ch,023h,00Ah,011h
        defb 015h,007h,019h,02Bh,013h,01Bh,003h,010h,00Dh,01Bh,00Eh,021h,00Ah,013h,001h,00Fh

Z180Neuro79:
        defb 012h,01Eh,00Ah,016h,018h,01Ah,01Ch,003h,00Fh,01Ch,029h,016h,019h,01Ch,01Fh,002h
        defb 00Ch,01Ah,028h,036h,01Ah,01Eh,022h,006h,029h,018h,027h,036h,01Bh,020h,025h,00Ah
        defb 01Ch,02Ch,01Ch,02Ch,032h,018h,01Eh,024h,00Fh,020h,011h,022h,029h,010h,017h,01Eh
        defb 002h,014h,026h,018h,020h,008h,010h,01Dh,01Ah,008h,01Bh,00Eh,017h,000h,00Eh,01Ch
        defb 01Dh,009h,015h,021h,023h,005h,007h,00Eh,01Ah,027h,014h,021h,024h,027h,00Ah,00Dh
        defb 017h,025h,033h,021h,025h,029h,00Dh,011h,014h,023h,032h,021h,026h,02Bh,010h,015h
        defb 027h,017h,027h,037h,01Dh,023h,029h,00Fh,01Ah,00Bh,01Ch,02Dh,014h,01Bh,022h,009h
        defb 00Dh,01Fh,011h,023h,00Bh,013h,01Bh,008h,005h,013h,006h,019h,022h,00Bh,019h,007h
        defb 008h,014h,020h,02Ch,00Eh,010h,012h,019h,005h,012h,01Fh,02Ch,00Fh,012h,015h,018h
        defb 022h,010h,01Eh,02Ch,030h,014h,018h,01Ch,01Fh,02Eh,01Dh,02Ch,031h,016h,01Bh,020h
        defb 012h,022h,032h,022h,028h,02Eh,014h,01Ah,005h,016h,027h,018h,01Fh,026h,00Dh,014h
        defb 018h,00Ah,01Ch,02Eh,016h,01Eh,006h,013h,010h,01Eh,011h,024h,00Dh,016h,004h,012h
        defb 013h,01Fh,00Bh,017h,019h,01Bh,01Dh,004h,010h,01Dh,02Ah,017h,01Ah,01Dh,020h,003h
        defb 00Dh,01Bh,029h,037h,01Bh,01Fh,023h,007h,02Ah,019h,028h,037h,01Ch,021h,026h,00Bh
        defb 01Dh,02Dh,01Dh,02Dh,033h,019h,01Fh,005h,010h,021h,012h,023h,02Ah,011h,018h,01Fh
        defb 003h,015h,027h,019h,021h,009h,011h,01Eh,01Bh,009h,01Ch,00Fh,018h,001h,00Fh,01Dh

Z180Neuro80:
        defb 000h,00Ch,018h,024h,026h,008h,00Ah,011h,01Dh,00Ah,017h,024h,027h,00Ah,00Dh,010h
        defb 01Ah,028h,016h,024h,028h,02Ch,010h,014h,017h,026h,035h,024h,029h,02Eh,013h,018h
        defb 00Ah,01Ah,02Ah,01Ah,020h,026h,00Ch,012h,01Dh,00Eh,01Fh,030h,017h,01Eh,005h,00Ch
        defb 010h,022h,014h,026h,00Eh,016h,01Eh,00Bh,008h,016h,009h,01Ch,005h,00Eh,01Ch,00Ah
        defb 00Bh,017h,023h,00Fh,011h,013h,015h,01Ch,008h,015h,022h,02Fh,012h,015h,018h,01Bh
        defb 025h,013h,021h,02Fh,033h,017h,01Bh,01Fh,022h,031h,020h,02Fh,034h,019h,01Eh,023h
        defb 015h,025h,015h,025h,02Bh,011h,017h,01Dh,008h,019h,02Ah,01Bh,022h,029h,010h,017h
        defb 01Bh,00Dh,01Fh,011h,019h,021h,009h,016h,013h,001h,014h,027h,010h,019h,007h,015h
        defb 016h,022h,00Eh,01Ah,01Ch,01Eh,000h,007h,013h,020h,02Dh,01Ah,01Dh,020h,023h,006h
        defb 010h,01Eh,02Ch,01Ah,01Eh,022h,026h,00Ah,02Dh,01Ch,02Bh,03Ah,01Fh,024h,029h,00Eh
        defb 020h,010h,020h,030h,016h,01Ch,022h,008h,013h,024h,015h,026h,02Dh,014h,01Bh,002h
        defb 006h,018h,00Ah,01Ch,024h,00Ch,014h,001h,01Eh,00Ch,01Fh,012h,01Bh,004h,012h,000h
        defb 001h,00Dh,019h,025h,027h,009h,00Bh,012h,01Eh,00Bh,018h,025h,028h,00Bh,00Eh,011h
        defb 01Bh,029h,017h,025h,029h,02Dh,011h,015h,018h,027h,036h,025h,02Ah,02Fh,014h,019h
        defb 00Bh,01Bh,02Bh,01Bh,021h,027h,00Dh,013h,01Eh,00Fh,020h,031h,018h,01Fh,006h,00Dh
        defb 011h,023h,015h,027h,00Fh,017h,01Fh,00Ch,009h,017h,00Ah,01Dh,006h,00Fh,01Dh,00Bh

Z180Neuro81:
        defb 00Eh,01Ah,026h,012h,014h,016h,018h,01Fh,00Bh,018h,025h,032h,015h,018h,01Bh,01Eh
        defb 028h,016h,024h,032h,016h,01Ah,01Eh,022h,025h,014h,023h,032h,037h,01Ch,021h,026h
        defb 018h,028h,018h,028h,02Eh,014h,01Ah,020h,00Bh,01Ch,02Dh,01Eh,025h,00Ch,013h,01Ah
        defb 01Eh,010h,022h,014h,01Ch,024h,00Ch,019h,016h,004h,017h,00Ah,013h,01Ch,00Ah,018h
        defb 019h,005h,011h,01Dh,01Fh,021h,003h,00Ah,016h,023h,010h,01Dh,020h,023h,006h,009h
        defb 013h,021h,02Fh,01Dh,021h,025h,029h,00Dh,010h,01Fh,02Eh,03Dh,022h,027h,02Ch,011h
        defb 023h,013h,023h,033h,019h,01Fh,025h,00Bh,016h,027h,018h,029h,010h,017h,01Eh,005h
        defb 009h,01Bh,00Dh,01Fh,027h,00Fh,017h,004h,001h,00Fh,022h,015h,01Eh,007h,015h,003h
        defb 004h,010h,01Ch,028h,00Ah,00Ch,00Eh,015h,021h,00Eh,01Bh,028h,02Bh,00Eh,011h,014h
        defb 01Eh,02Ch,01Ah,028h,02Ch,010h,014h,018h,01Bh,02Ah,019h,028h,02Dh,032h,017h,01Ch
        defb 00Eh,01Eh,02Eh,01Eh,024h,02Ah,010h,016h,021h,012h,023h,014h,01Bh,022h,009h,010h
        defb 014h,006h,018h,02Ah,012h,01Ah,002h,00Fh,00Ch,01Ah,00Dh,020h,009h,012h,000h,00Eh
        defb 00Fh,01Bh,027h,013h,015h,017h,019h,000h,00Ch,019h,026h,033h,016h,019h,01Ch,01Fh
        defb 029h,017h,025h,033h,017h,01Bh,01Fh,023h,026h,015h,024h,033h,038h,01Dh,022h,027h
        defb 019h,029h,019h,029h,02Fh,015h,01Bh,021h,00Ch,01Dh,02Eh,01Fh,026h,00Dh,014h,01Bh
        defb 01Fh,011h,023h,015h,01Dh,005h,00Dh,01Ah,017h,005h,018h,00Bh,014h,01Dh,00Bh,019h

Z180Neuro82:
        defb 01Ch,008h,014h,020h,022h,024h,006h,00Dh,019h,026h,013h,020h,023h,026h,009h,00Ch
        defb 016h,024h,032h,020h,024h,028h,00Ch,010h,013h,022h,031h,020h,025h,02Ah,00Fh,014h
        defb 026h,016h,026h,036h,01Ch,022h,028h,00Eh,019h,00Ah,01Bh,02Ch,013h,01Ah,021h,008h
        defb 00Ch,01Eh,010h,022h,00Ah,012h,01Ah,007h,004h,012h,005h,018h,021h,00Ah,018h,006h
        defb 007h,013h,01Fh,02Bh,00Dh,00Fh,011h,018h,024h,011h,01Eh,02Bh,02Eh,011h,014h,017h
        defb 021h,00Fh,01Dh,02Bh,02Fh,013h,017h,01Bh,01Eh,02Dh,01Ch,02Bh,030h,015h,01Ah,01Fh
        defb 011h,021h,031h,021h,027h,02Dh,013h,019h,024h,015h,026h,017h,01Eh,025h,00Ch,013h
        defb 017h,009h,01Bh,02Dh,015h,01Dh,005h,012h,00Fh,01Dh,010h,023h,00Ch,015h,003h,011h
        defb 012h,01Eh,00Ah,016h,018h,01Ah,01Ch,003h,00Fh,01Ch,029h,016h,019h,01Ch,01Fh,002h
        defb 00Ch,01Ah,028h,036h,01Ah,01Eh,022h,006h,029h,018h,027h,036h,01Bh,020h,025h,00Ah
        defb 01Ch,02Ch,01Ch,02Ch,032h,018h,01Eh,024h,00Fh,020h,011h,022h,029h,010h,017h,01Eh
        defb 002h,014h,026h,018h,020h,008h,010h,01Dh,01Ah,008h,01Bh,00Eh,017h,000h,00Eh,01Ch
        defb 01Dh,009h,015h,021h,023h,005h,007h,00Eh,01Ah,027h,014h,021h,024h,027h,00Ah,00Dh
        defb 017h,025h,033h,021h,025h,029h,00Dh,011h,014h,023h,032h,021h,026h,02Bh,010h,015h
        defb 027h,017h,027h,037h,01Dh,023h,029h,00Fh,01Ah,00Bh,01Ch,02Dh,014h,01Bh,022h,009h
        defb 00Dh,01Fh,011h,023h,00Bh,013h,01Bh,008h,005h,013h,006h,019h,022h,00Bh,019h,007h

Z180Neuro83:
        defb 00Ah,016h,022h,02Eh,010h,012h,014h,01Bh,007h,014h,021h,02Eh,011h,014h,017h,01Ah
        defb 024h,012h,020h,02Eh,032h,016h,01Ah,01Eh,021h,030h,01Fh,02Eh,033h,018h,01Dh,022h
        defb 014h,024h,014h,024h,02Ah,010h,016h,01Ch,007h,018h,029h,01Ah,021h,028h,00Fh,016h
        defb 01Ah,00Ch,01Eh,010h,018h,020h,008h,015h,012h,000h,013h,026h,00Fh,018h,006h,014h
        defb 015h,021h,00Dh,019h,01Bh,01Dh,01Fh,006h,012h,01Fh,02Ch,019h,01Ch,01Fh,022h,005h
        defb 00Fh,01Dh,02Bh,019h,01Dh,021h,025h,009h,02Ch,01Bh,02Ah,039h,01Eh,023h,028h,00Dh
        defb 01Fh,00Fh,01Fh,02Fh,015h,01Bh,021h,007h,012h,023h,014h,025h,02Ch,013h,01Ah,001h
        defb 005h,017h,029h,01Bh,023h,00Bh,013h,000h,01Dh,00Bh,01Eh,011h,01Ah,003h,011h,01Fh
        defb 000h,00Ch,018h,024h,026h,008h,00Ah,011h,01Dh,00Ah,017h,024h,027h,00Ah,00Dh,010h
        defb 01Ah,028h,016h,024h,028h,02Ch,010h,014h,017h,026h,035h,024h,029h,02Eh,013h,018h
        defb 00Ah,01Ah,02Ah,01Ah,020h,026h,00Ch,012h,01Dh,00Eh,01Fh,030h,017h,01Eh,005h,00Ch
        defb 010h,022h,014h,026h,00Eh,016h,01Eh,00Bh,008h,016h,009h,01Ch,005h,00Eh,01Ch,00Ah
        defb 00Bh,017h,023h,00Fh,011h,013h,015h,01Ch,008h,015h,022h,02Fh,012h,015h,018h,01Bh
        defb 025h,013h,021h,02Fh,033h,017h,01Bh,01Fh,022h,031h,020h,02Fh,034h,019h,01Eh,023h
        defb 015h,025h,015h,025h,02Bh,011h,017h,01Dh,008h,019h,02Ah,01Bh,022h,029h,010h,017h
        defb 01Bh,00Dh,01Fh,011h,019h,021h,009h,016h,013h,001h,014h,027h,010h,019h,007h,015h

Z180Neuro84:
        defb 018h,024h,010h,01Ch,01Eh,020h,002h,009h,015h,022h,00Fh,01Ch,01Fh,022h,005h,008h
        defb 012h,020h,02Eh,01Ch,020h,024h,028h,00Ch,00Fh,01Eh,02Dh,03Ch,021h,026h,02Bh,010h
        defb 022h,012h,022h,032h,018h,01Eh,024h,00Ah,015h,026h,017h,028h,00Fh,016h,01Dh,004h
        defb 008h,01Ah,00Ch,01Eh,026h,00Eh,016h,003h,000h,00Eh,021h,014h,01Dh,006h,014h,002h
        defb 003h,00Fh,01Bh,027h,029h,00Bh,00Dh,014h,020h,00Dh,01Ah,027h,02Ah,00Dh,010h,013h
        defb 01Dh,02Bh,019h,027h,02Bh,00Fh,013h,017h,01Ah,029h,038h,027h,02Ch,031h,016h,01Bh
        defb 00Dh,01Dh,02Dh,01Dh,023h,029h,00Fh,015h,020h,011h,022h,033h,01Ah,021h,008h,00Fh
        defb 013h,005h,017h,029h,011h,019h,001h,00Eh,00Bh,019h,00Ch,01Fh,008h,011h,01Fh,00Dh
        defb 00Eh,01Ah,026h,012h,014h,016h,018h,01Fh,00Bh,018h,025h,032h,015h,018h,01Bh,01Eh
        defb 028h,016h,024h,032h,016h,01Ah,01Eh,022h,025h,014h,023h,032h,037h,01Ch,021h,026h
        defb 018h,028h,018h,028h,02Eh,014h,01Ah,020h,00Bh,01Ch,02Dh,01Eh,025h,00Ch,013h,01Ah
        defb 01Eh,010h,022h,014h,01Ch,024h,00Ch,019h,016h,004h,017h,00Ah,013h,01Ch,00Ah,018h
        defb 019h,005h,011h,01Dh,01Fh,021h,003h,00Ah,016h,023h,010h,01Dh,020h,023h,006h,009h
        defb 013h,021h,02Fh,01Dh,021h,025h,029h,00Dh,010h,01Fh,02Eh,03Dh,022h,027h,02Ch,011h
        defb 023h,013h,023h,033h,019h,01Fh,025h,00Bh,016h,027h,018h,029h,010h,017h,01Eh,005h
        defb 009h,01Bh,00Dh,01Fh,027h,00Fh,017h,004h,001h,00Fh,022h,015h,01Eh,007h,015h,003h

Z180Neuro85:
        defb 006h,012h,01Eh,02Ah,00Ch,00Eh,010h,017h,023h,010h,01Dh,02Ah,02Dh,010h,013h,016h
        defb 020h,02Eh,01Ch,02Ah,02Eh,012h,016h,01Ah,01Dh,02Ch,01Bh,02Ah,02Fh,014h,019h,01Eh
        defb 010h,020h,030h,020h,026h,02Ch,012h,018h,023h,014h,025h,016h,01Dh,024h,00Bh,012h
        defb 016h,008h,01Ah,02Ch,014h,01Ch,004h,011h,00Eh,01Ch,00Fh,022h,00Bh,014h,002h,010h
        defb 011h,01Dh,029h,015h,017h,019h,01Bh,002h,00Eh,01Bh,028h,015h,018h,01Bh,01Eh,001h
        defb 00Bh,019h,027h,035h,019h,01Dh,021h,005h,028h,017h,026h,035h,01Ah,01Fh,024h,029h
        defb 01Bh,02Bh,01Bh,02Bh,031h,017h,01Dh,023h,00Eh,01Fh,010h,021h,028h,00Fh,016h,01Dh
        defb 001h,013h,025h,017h,01Fh,007h,00Fh,01Ch,019h,007h,01Ah,00Dh,016h,01Fh,00Dh,01Bh
        defb 01Ch,008h,014h,020h,022h,024h,006h,00Dh,019h,026h,013h,020h,023h,026h,009h,00Ch
        defb 016h,024h,032h,020h,024h,028h,00Ch,010h,013h,022h,031h,020h,025h,02Ah,00Fh,014h
        defb 026h,016h,026h,036h,01Ch,022h,028h,00Eh,019h,00Ah,01Bh,02Ch,013h,01Ah,021h,008h
        defb 00Ch,01Eh,010h,022h,00Ah,012h,01Ah,007h,004h,012h,005h,018h,021h,00Ah,018h,006h
        defb 007h,013h,01Fh,02Bh,00Dh,00Fh,011h,018h,024h,011h,01Eh,02Bh,02Eh,011h,014h,017h
        defb 021h,00Fh,01Dh,02Bh,02Fh,013h,017h,01Bh,01Eh,02Dh,01Ch,02Bh,030h,015h,01Ah,01Fh
        defb 011h,021h,031h,021h,027h,02Dh,013h,019h,024h,015h,026h,017h,01Eh,025h,00Ch,013h
        defb 017h,009h,01Bh,02Dh,015h,01Dh,005h,012h,00Fh,01Dh,010h,023h,00Ch,015h,003h,011h

Z180Neuro86:
        defb 014h,020h,00Ch,018h,01Ah,01Ch,01Eh,005h,011h,01Eh,02Bh,018h,01Bh,01Eh,021h,004h
        defb 00Eh,01Ch,02Ah,038h,01Ch,020h,024h,008h,02Bh,01Ah,029h,038h,01Dh,022h,027h,00Ch
        defb 01Eh,02Eh,01Eh,02Eh,014h,01Ah,020h,006h,011h,022h,013h,024h,02Bh,012h,019h,000h
        defb 004h,016h,028h,01Ah,022h,00Ah,012h,01Fh,01Ch,00Ah,01Dh,010h,019h,002h,010h,01Eh
        defb 01Fh,00Bh,017h,023h,025h,007h,009h,010h,01Ch,029h,016h,023h,026h,029h,00Ch,00Fh
        defb 019h,027h,015h,023h,027h,02Bh,00Fh,013h,016h,025h,034h,023h,028h,02Dh,012h,017h
        defb 029h,019h,029h,019h,01Fh,025h,00Bh,011h,01Ch,00Dh,01Eh,02Fh,016h,01Dh,024h,00Bh
        defb 00Fh,021h,013h,025h,00Dh,015h,01Dh,00Ah,007h,015h,008h,01Bh,024h,00Dh,01Bh,009h
        defb 00Ah,016h,022h,02Eh,010h,012h,014h,01Bh,007h,014h,021h,02Eh,011h,014h,017h,01Ah
        defb 024h,012h,020h,02Eh,032h,016h,01Ah,01Eh,021h,030h,01Fh,02Eh,033h,018h,01Dh,022h
        defb 014h,024h,014h,024h,02Ah,010h,016h,01Ch,007h,018h,029h,01Ah,021h,028h,00Fh,016h
        defb 01Ah,00Ch,01Eh,010h,018h,020h,008h,015h,012h,000h,013h,026h,00Fh,018h,006h,014h
        defb 015h,021h,00Dh,019h,01Bh,01Dh,01Fh,006h,012h,01Fh,02Ch,019h,01Ch,01Fh,022h,005h
        defb 00Fh,01Dh,02Bh,019h,01Dh,021h,025h,009h,02Ch,01Bh,02Ah,039h,01Eh,023h,028h,00Dh
        defb 01Fh,00Fh,01Fh,02Fh,015h,01Bh,021h,007h,012h,023h,014h,025h,02Ch,013h,01Ah,001h
        defb 005h,017h,029h,01Bh,023h,00Bh,013h,000h,01Dh,00Bh,01Eh,011h,01Ah,003h,011h,01Fh

Z180Neuro87:
        defb 002h,00Eh,01Ah,026h,028h,00Ah,00Ch,013h,01Fh,00Ch,019h,026h,029h,00Ch,00Fh,012h
        defb 01Ch,02Ah,018h,026h,02Ah,02Eh,012h,016h,019h,028h,037h,026h,02Bh,030h,015h,01Ah
        defb 00Ch,01Ch,02Ch,01Ch,022h,028h,00Eh,014h,01Fh,010h,021h,032h,019h,020h,007h,00Eh
        defb 012h,024h,016h,028h,010h,018h,000h,00Dh,00Ah,018h,00Bh,01Eh,007h,010h,01Eh,00Ch
        defb 00Dh,019h,025h,011h,013h,015h,017h,01Eh,00Ah,017h,024h,031h,014h,017h,01Ah,01Dh
        defb 027h,015h,023h,031h,015h,019h,01Dh,021h,024h,033h,022h,031h,036h,01Bh,020h,025h
        defb 017h,027h,017h,027h,02Dh,013h,019h,01Fh,00Ah,01Bh,02Ch,01Dh,024h,00Bh,012h,019h
        defb 01Dh,00Fh,021h,013h,01Bh,023h,00Bh,018h,015h,003h,016h,029h,012h,01Bh,009h,017h
        defb 018h,024h,010h,01Ch,01Eh,020h,002h,009h,015h,022h,00Fh,01Ch,01Fh,022h,005h,008h
        defb 012h,020h,02Eh,01Ch,020h,024h,028h,00Ch,00Fh,01Eh,02Dh,03Ch,021h,026h,02Bh,010h
        defb 022h,012h,022h,032h,018h,01Eh,024h,00Ah,015h,026h,017h,028h,00Fh,016h,01Dh,004h
        defb 008h,01Ah,00Ch,01Eh,026h,00Eh,016h,003h,000h,00Eh,021h,014h,01Dh,006h,014h,002h
        defb 003h,00Fh,01Bh,027h,029h,00Bh,00Dh,014h,020h,00Dh,01Ah,027h,02Ah,00Dh,010h,013h
        defb 01Dh,02Bh,019h,027h,02Bh,00Fh,013h,017h,01Ah,029h,038h,027h,02Ch,031h,016h,01Bh
        defb 00Dh,01Dh,02Dh,01Dh,023h,029h,00Fh,015h,020h,011h,022h,033h,01Ah,021h,008h,00Fh
        defb 013h,005h,017h,029h,011h,019h,001h,00Eh,00Bh,019h,00Ch,01Fh,008h,011h,01Fh,00Dh

Z180Neuro88:
        defb 010h,01Ch,028h,014h,016h,018h,01Ah,001h,00Dh,01Ah,027h,014h,017h,01Ah,01Dh,000h
        defb 00Ah,018h,026h,034h,018h,01Ch,020h,024h,027h,016h,025h,034h,019h,01Eh,023h,028h
        defb 01Ah,02Ah,01Ah,02Ah,030h,016h,01Ch,022h,00Dh,01Eh,00Fh,020h,027h,00Eh,015h,01Ch
        defb 000h,012h,024h,016h,01Eh,006h,00Eh,01Bh,018h,006h,019h,00Ch,015h,01Eh,00Ch,01Ah
        defb 01Bh,007h,013h,01Fh,021h,023h,005h,00Ch,018h,025h,012h,01Fh,022h,025h,008h,00Bh
        defb 015h,023h,031h,01Fh,023h,027h,00Bh,00Fh,012h,021h,030h,01Fh,024h,029h,02Eh,013h
        defb 025h,015h,025h,035h,01Bh,021h,027h,00Dh,018h,029h,01Ah,02Bh,012h,019h,020h,007h
        defb 00Bh,01Dh,00Fh,021h,029h,011h,019h,006h,003h,011h,024h,017h,020h,009h,017h,005h
        defb 006h,012h,01Eh,02Ah,00Ch,00Eh,010h,017h,023h,010h,01Dh,02Ah,02Dh,010h,013h,016h
        defb 020h,02Eh,01Ch,02Ah,02Eh,012h,016h,01Ah,01Dh,02Ch,01Bh,02Ah,02Fh,014h,019h,01Eh
        defb 010h,020h,030h,020h,026h,02Ch,012h,018h,023h,014h,025h,016h,01Dh,024h,00Bh,012h
        defb 016h,008h,01Ah,02Ch,014h,01Ch,004h,011h,00Eh,01Ch,00Fh,022h,00Bh,014h,002h,010h
        defb 011h,01Dh,029h,015h,017h,019h,01Bh,002h,00Eh,01Bh,028h,015h,018h,01Bh,01Eh,001h
        defb 00Bh,019h,027h,035h,019h,01Dh,021h,005h,028h,017h,026h,035h,01Ah,01Fh,024h,029h
        defb 01Bh,02Bh,01Bh,02Bh,031h,017h,01Dh,023h,00Eh,01Fh,010h,021h,028h,00Fh,016h,01Dh
        defb 001h,013h,025h,017h,01Fh,007h,00Fh,01Ch,019h,007h,01Ah,00Dh,016h,01Fh,00Dh,01Bh

Z180Neuro89:
        defb 01Eh,00Ah,016h,022h,024h,006h,008h,00Fh,01Bh,028h,015h,022h,025h,028h,00Bh,00Eh
        defb 018h,026h,014h,022h,026h,02Ah,00Eh,012h,015h,024h,033h,022h,027h,02Ch,011h,016h
        defb 028h,018h,028h,038h,01Eh,024h,00Ah,010h,01Bh,00Ch,01Dh,02Eh,015h,01Ch,023h,00Ah
        defb 00Eh,020h,012h,024h,00Ch,014h,01Ch,009h,006h,014h,007h,01Ah,023h,00Ch,01Ah,008h
        defb 009h,015h,021h,02Dh,00Fh,011h,013h,01Ah,006h,013h,020h,02Dh,010h,013h,016h,019h
        defb 023h,011h,01Fh,02Dh,031h,015h,019h,01Dh,020h,02Fh,01Eh,02Dh,032h,017h,01Ch,021h
        defb 013h,023h,033h,023h,029h,00Fh,015h,01Bh,006h,017h,028h,019h,020h,027h,00Eh,015h
        defb 019h,00Bh,01Dh,00Fh,017h,01Fh,007h,014h,011h,01Fh,012h,025h,00Eh,017h,005h,013h
        defb 014h,020h,00Ch,018h,01Ah,01Ch,01Eh,005h,011h,01Eh,02Bh,018h,01Bh,01Eh,021h,004h
        defb 00Eh,01Ch,02Ah,038h,01Ch,020h,024h,008h,02Bh,01Ah,029h,038h,01Dh,022h,027h,00Ch
        defb 01Eh,02Eh,01Eh,02Eh,014h,01Ah,020h,006h,011h,022h,013h,024h,02Bh,012h,019h,000h
        defb 004h,016h,028h,01Ah,022h,00Ah,012h,01Fh,01Ch,00Ah,01Dh,010h,019h,002h,010h,01Eh
        defb 01Fh,00Bh,017h,023h,025h,007h,009h,010h,01Ch,029h,016h,023h,026h,029h,00Ch,00Fh
        defb 019h,027h,015h,023h,027h,02Bh,00Fh,013h,016h,025h,034h,023h,028h,02Dh,012h,017h
        defb 029h,019h,029h,019h,01Fh,025h,00Bh,011h,01Ch,00Dh,01Eh,02Fh,016h,01Dh,024h,00Bh
        defb 00Fh,021h,013h,025h,00Dh,015h,01Dh,00Ah,007h,015h,008h,01Bh,024h,00Dh,01Bh,009h

Z180Neuro90:
        defb 00Ch,018h,024h,010h,012h,014h,016h,01Dh,009h,016h,023h,030h,013h,016h,019h,01Ch
        defb 026h,014h,022h,030h,014h,018h,01Ch,020h,023h,032h,021h,030h,035h,01Ah,01Fh,024h
        defb 016h,026h,016h,026h,02Ch,012h,018h,01Eh,009h,01Ah,02Bh,01Ch,023h,00Ah,011h,018h
        defb 01Ch,00Eh,020h,012h,01Ah,022h,00Ah,017h,014h,002h,015h,028h,011h,01Ah,008h,016h
        defb 017h,023h,00Fh,01Bh,01Dh,01Fh,001h,008h,014h,021h,02Eh,01Bh,01Eh,021h,024h,007h
        defb 011h,01Fh,02Dh,01Bh,01Fh,023h,027h,00Bh,02Eh,01Dh,02Ch,03Bh,020h,025h,02Ah,00Fh
        defb 021h,011h,021h,031h,017h,01Dh,023h,009h,014h,025h,016h,027h,02Eh,015h,01Ch,003h
        defb 007h,019h,00Bh,01Dh,025h,00Dh,015h,002h,01Fh,00Dh,020h,013h,01Ch,005h,013h,001h
        defb 002h,00Eh,01Ah,026h,028h,00Ah,00Ch,013h,01Fh,00Ch,019h,026h,029h,00Ch,00Fh,012h
        defb 01Ch,02Ah,018h,026h,02Ah,02Eh,012h,016h,019h,028h,037h,026h,02Bh,030h,015h,01Ah
        defb 00Ch,01Ch,02Ch,01Ch,022h,028h,00Eh,014h,01Fh,010h,021h,032h,019h,020h,007h,00Eh
        defb 012h,024h,016h,028h,010h,018h,000h,00Dh,00Ah,018h,00Bh,01Eh,007h,010h,01Eh,00Ch
        defb 00Dh,019h,025h,011h,013h,015h,017h,01Eh,00Ah,017h,024h,031h,014h,017h,01Ah,01Dh
        defb 027h,015h,023h,031h,015h,019h,01Dh,021h,024h,033h,022h,031h,036h,01Bh,020h,025h
        defb 017h,027h,017h,027h,02Dh,013h,019h,01Fh,00Ah,01Bh,02Ch,01Dh,024h,00Bh,012h,019h
        defb 01Dh,00Fh,021h,013h,01Bh,023h,00Bh,018h,015h,003h,016h,029h,012h,01Bh,009h,017h

Z180Neuro91:
        defb 01Ah,006h,012h,01Eh,020h,022h,004h,00Bh,017h,024h,011h,01Eh,021h,024h,007h,00Ah
        defb 014h,022h,030h,01Eh,022h,026h,00Ah,00Eh,011h,020h,02Fh,01Eh,023h,028h,02Dh,012h
        defb 024h,014h,024h,034h,01Ah,020h,026h,00Ch,017h,028h,019h,02Ah,011h,018h,01Fh,006h
        defb 00Ah,01Ch,00Eh,020h,028h,010h,018h,005h,002h,010h,023h,016h,01Fh,008h,016h,004h
        defb 005h,011h,01Dh,029h,00Bh,00Dh,00Fh,016h,022h,00Fh,01Ch,029h,02Ch,00Fh,012h,015h
        defb 01Fh,02Dh,01Bh,029h,02Dh,011h,015h,019h,01Ch,02Bh,01Ah,029h,02Eh,033h,018h,01Dh
        defb 00Fh,01Fh,02Fh,01Fh,025h,02Bh,011h,017h,022h,013h,024h,015h,01Ch,023h,00Ah,011h
        defb 015h,007h,019h,02Bh,013h,01Bh,003h,010h,00Dh,01Bh,00Eh,021h,00Ah,013h,001h,00Fh
        defb 010h,01Ch,028h,014h,016h,018h,01Ah,001h,00Dh,01Ah,027h,014h,017h,01Ah,01Dh,000h
        defb 00Ah,018h,026h,034h,018h,01Ch,020h,024h,027h,016h,025h,034h,019h,01Eh,023h,028h
        defb 01Ah,02Ah,01Ah,02Ah,030h,016h,01Ch,022h,00Dh,01Eh,00Fh,020h,027h,00Eh,015h,01Ch
        defb 000h,012h,024h,016h,01Eh,006h,00Eh,01Bh,018h,006h,019h,00Ch,015h,01Eh,00Ch,01Ah
        defb 01Bh,007h,013h,01Fh,021h,023h,005h,00Ch,018h,025h,012h,01Fh,022h,025h,008h,00Bh
        defb 015h,023h,031h,01Fh,023h,027h,00Bh,00Fh,012h,021h,030h,01Fh,024h,029h,02Eh,013h
        defb 025h,015h,025h,035h,01Bh,021h,027h,00Dh,018h,029h,01Ah,02Bh,012h,019h,020h,007h
        defb 00Bh,01Dh,00Fh,021h,029h,011h,019h,006h,003h,011h,024h,017h,020h,009h,017h,005h

Z180Neuro92:
        defb 008h,014h,020h,02Ch,00Eh,010h,012h,019h,005h,012h,01Fh,02Ch,00Fh,012h,015h,018h
        defb 022h,010h,01Eh,02Ch,030h,014h,018h,01Ch,01Fh,02Eh,01Dh,02Ch,031h,016h,01Bh,020h
        defb 012h,022h,032h,022h,028h,02Eh,014h,01Ah,005h,016h,027h,018h,01Fh,026h,00Dh,014h
        defb 018h,00Ah,01Ch,02Eh,016h,01Eh,006h,013h,010h,01Eh,011h,024h,00Dh,016h,004h,012h
        defb 013h,01Fh,00Bh,017h,019h,01Bh,01Dh,004h,010h,01Dh,02Ah,017h,01Ah,01Dh,020h,003h
        defb 00Dh,01Bh,029h,037h,01Bh,01Fh,023h,007h,02Ah,019h,028h,037h,01Ch,021h,026h,00Bh
        defb 01Dh,02Dh,01Dh,02Dh,033h,019h,01Fh,005h,010h,021h,012h,023h,02Ah,011h,018h,01Fh
        defb 003h,015h,027h,019h,021h,009h,011h,01Eh,01Bh,009h,01Ch,00Fh,018h,001h,00Fh,01Dh
        defb 01Eh,00Ah,016h,022h,024h,006h,008h,00Fh,01Bh,028h,015h,022h,025h,028h,00Bh,00Eh
        defb 018h,026h,014h,022h,026h,02Ah,00Eh,012h,015h,024h,033h,022h,027h,02Ch,011h,016h
        defb 028h,018h,028h,038h,01Eh,024h,00Ah,010h,01Bh,00Ch,01Dh,02Eh,015h,01Ch,023h,00Ah
        defb 00Eh,020h,012h,024h,00Ch,014h,01Ch,009h,006h,014h,007h,01Ah,023h,00Ch,01Ah,008h
        defb 009h,015h,021h,02Dh,00Fh,011h,013h,01Ah,006h,013h,020h,02Dh,010h,013h,016h,019h
        defb 023h,011h,01Fh,02Dh,031h,015h,019h,01Dh,020h,02Fh,01Eh,02Dh,032h,017h,01Ch,021h
        defb 013h,023h,033h,023h,029h,00Fh,015h,01Bh,006h,017h,028h,019h,020h,027h,00Eh,015h
        defb 019h,00Bh,01Dh,00Fh,017h,01Fh,007h,014h,011h,01Fh,012h,025h,00Eh,017h,005h,013h

Z180Neuro93:
        defb 016h,022h,00Eh,01Ah,01Ch,01Eh,000h,007h,013h,020h,02Dh,01Ah,01Dh,020h,023h,006h
        defb 010h,01Eh,02Ch,01Ah,01Eh,022h,026h,00Ah,02Dh,01Ch,02Bh,03Ah,01Fh,024h,029h,00Eh
        defb 020h,010h,020h,030h,016h,01Ch,022h,008h,013h,024h,015h,026h,02Dh,014h,01Bh,002h
        defb 006h,018h,00Ah,01Ch,024h,00Ch,014h,001h,01Eh,00Ch,01Fh,012h,01Bh,004h,012h,000h
        defb 001h,00Dh,019h,025h,027h,009h,00Bh,012h,01Eh,00Bh,018h,025h,028h,00Bh,00Eh,011h
        defb 01Bh,029h,017h,025h,029h,02Dh,011h,015h,018h,027h,036h,025h,02Ah,02Fh,014h,019h
        defb 00Bh,01Bh,02Bh,01Bh,021h,027h,00Dh,013h,01Eh,00Fh,020h,031h,018h,01Fh,006h,00Dh
        defb 011h,023h,015h,027h,00Fh,017h,01Fh,00Ch,009h,017h,00Ah,01Dh,006h,00Fh,01Dh,00Bh
        defb 00Ch,018h,024h,010h,012h,014h,016h,01Dh,009h,016h,023h,030h,013h,016h,019h,01Ch
        defb 026h,014h,022h,030h,014h,018h,01Ch,020h,023h,032h,021h,030h,035h,01Ah,01Fh,024h
        defb 016h,026h,016h,026h,02Ch,012h,018h,01Eh,009h,01Ah,02Bh,01Ch,023h,00Ah,011h,018h
        defb 01Ch,00Eh,020h,012h,01Ah,022h,00Ah,017h,014h,002h,015h,028h,011h,01Ah,008h,016h
        defb 017h,023h,00Fh,01Bh,01Dh,01Fh,001h,008h,014h,021h,02Eh,01Bh,01Eh,021h,024h,007h
        defb 011h,01Fh,02Dh,01Bh,01Fh,023h,027h,00Bh,02Eh,01Dh,02Ch,03Bh,020h,025h,02Ah,00Fh
        defb 021h,011h,021h,031h,017h,01Dh,023h,009h,014h,025h,016h,027h,02Eh,015h,01Ch,003h
        defb 007h,019h,00Bh,01Dh,025h,00Dh,015h,002h,01Fh,00Dh,020h,013h,01Ch,005h,013h,001h

Z180Neuro94:
        defb 004h,010h,01Ch,028h,00Ah,00Ch,00Eh,015h,021h,00Eh,01Bh,028h,02Bh,00Eh,011h,014h
        defb 01Eh,02Ch,01Ah,028h,02Ch,010h,014h,018h,01Bh,02Ah,019h,028h,02Dh,032h,017h,01Ch
        defb 00Eh,01Eh,02Eh,01Eh,024h,02Ah,010h,016h,021h,012h,023h,014h,01Bh,022h,009h,010h
        defb 014h,006h,018h,02Ah,012h,01Ah,002h,00Fh,00Ch,01Ah,00Dh,020h,009h,012h,000h,00Eh
        defb 00Fh,01Bh,027h,013h,015h,017h,019h,000h,00Ch,019h,026h,033h,016h,019h,01Ch,01Fh
        defb 029h,017h,025h,033h,017h,01Bh,01Fh,023h,026h,015h,024h,033h,038h,01Dh,022h,027h
        defb 019h,029h,019h,029h,02Fh,015h,01Bh,021h,00Ch,01Dh,02Eh,01Fh,026h,00Dh,014h,01Bh
        defb 01Fh,011h,023h,015h,01Dh,005h,00Dh,01Ah,017h,005h,018h,00Bh,014h,01Dh,00Bh,019h
        defb 01Ah,006h,012h,01Eh,020h,022h,004h,00Bh,017h,024h,011h,01Eh,021h,024h,007h,00Ah
        defb 014h,022h,030h,01Eh,022h,026h,00Ah,00Eh,011h,020h,02Fh,01Eh,023h,028h,02Dh,012h
        defb 024h,014h,024h,034h,01Ah,020h,026h,00Ch,017h,028h,019h,02Ah,011h,018h,01Fh,006h
        defb 00Ah,01Ch,00Eh,020h,028h,010h,018h,005h,002h,010h,023h,016h,01Fh,008h,016h,004h
        defb 005h,011h,01Dh,029h,00Bh,00Dh,00Fh,016h,022h,00Fh,01Ch,029h,02Ch,00Fh,012h,015h
        defb 01Fh,02Dh,01Bh,029h,02Dh,011h,015h,019h,01Ch,02Bh,01Ah,029h,02Eh,033h,018h,01Dh
        defb 00Fh,01Fh,02Fh,01Fh,025h,02Bh,011h,017h,022h,013h,024h,015h,01Ch,023h,00Ah,011h
        defb 015h,007h,019h,02Bh,013h,01Bh,003h,010h,00Dh,01Bh,00Eh,021h,00Ah,013h,001h,00Fh

Z180Neuro95:
        defb 012h,01Eh,00Ah,016h,018h,01Ah,01Ch,003h,00Fh,01Ch,029h,016h,019h,01Ch,01Fh,002h
        defb 00Ch,01Ah,028h,036h,01Ah,01Eh,022h,006h,029h,018h,027h,036h,01Bh,020h,025h,00Ah
        defb 01Ch,02Ch,01Ch,02Ch,032h,018h,01Eh,024h,00Fh,020h,011h,022h,029h,010h,017h,01Eh
        defb 002h,014h,026h,018h,020h,008h,010h,01Dh,01Ah,008h,01Bh,00Eh,017h,000h,00Eh,01Ch
        defb 01Dh,009h,015h,021h,023h,005h,007h,00Eh,01Ah,027h,014h,021h,024h,027h,00Ah,00Dh
        defb 017h,025h,033h,021h,025h,029h,00Dh,011h,014h,023h,032h,021h,026h,02Bh,010h,015h
        defb 027h,017h,027h,037h,01Dh,023h,029h,00Fh,01Ah,00Bh,01Ch,02Dh,014h,01Bh,022h,009h
        defb 00Dh,01Fh,011h,023h,00Bh,013h,01Bh,008h,005h,013h,006h,019h,022h,00Bh,019h,007h
        defb 008h,014h,020h,02Ch,00Eh,010h,012h,019h,005h,012h,01Fh,02Ch,00Fh,012h,015h,018h
        defb 022h,010h,01Eh,02Ch,030h,014h,018h,01Ch,01Fh,02Eh,01Dh,02Ch,031h,016h,01Bh,020h
        defb 012h,022h,032h,022h,028h,02Eh,014h,01Ah,005h,016h,027h,018h,01Fh,026h,00Dh,014h
        defb 018h,00Ah,01Ch,02Eh,016h,01Eh,006h,013h,010h,01Eh,011h,024h,00Dh,016h,004h,012h
        defb 013h,01Fh,00Bh,017h,019h,01Bh,01Dh,004h,010h,01Dh,02Ah,017h,01Ah,01Dh,020h,003h
        defb 00Dh,01Bh,029h,037h,01Bh,01Fh,023h,007h,02Ah,019h,028h,037h,01Ch,021h,026h,00Bh
        defb 01Dh,02Dh,01Dh,02Dh,033h,019h,01Fh,005h,010h,021h,012h,023h,02Ah,011h,018h,01Fh
        defb 003h,015h,027h,019h,021h,009h,011h,01Eh,01Bh,009h,01Ch,00Fh,018h,001h,00Fh,01Dh


; REV29 short centered brain status tile strings.
; Final depth digit is appended dynamically.
; Text tile map: A=32..Z=57, dash=58, space=59, digits=60..69.
BrainTextRwbBrn:
        ; RWBANK BRN D
        defb 49,54,33,32,45,42,59,33,49,45,59,35,0
BrainTextRwb:
        ; RWBANK 96K D
        defb 49,54,33,32,45,42,59,69,66,42,59,35,0
BrainTextBrn:
        ; BRN FILE D
        defb 33,49,45,59,37,40,43,36,59,35,0
BrainTextRam:
        ; CPM RAM D
        defb 34,47,44,59,49,32,44,59,35,0
BrainTextInternal:
        ; INTERNAL D
        defb 40,45,51,36,49,45,32,43,59,35,0

NoTmsMsg:
        defb "TMSEMU3 / TMS9918A not found, aborting!$"

; Text tile strings.  Tiles 32..57 are A..Z, 58 is dash, 59 is space, 60..69 are 0..9.
TitleText:
        defb 34,39,55,49,62,69,0
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

; ------------------------------------------------------------
; REV15 mega-brain planes: 24 x 256 byte tactical bias tables.
; These are deliberately real bytes in the .COM and source, not comments.
; Only several planes are sampled each candidate now; the rest are reserved.

MegaBrain0:
        defb 0,14,28,14,29,11,25,11,26,4,22,4,23,1,19,1
        defb 20,26,8,26,1,23,5,23,14,16,2,16,27,13,31,13
        defb 8,6,20,6,21,3,17,3,2,28,14,28,15,25,11,25
        defb 28,18,0,18,25,15,29,15,22,8,26,8,19,5,23,5
        defb 16,30,12,30,13,27,9,27,10,20,6,20,7,17,3,17
        defb 4,10,24,10,17,7,21,7,30,0,18,0,11,29,15,29
        defb 24,22,4,22,5,19,1,19,18,12,30,12,31,9,27,9
        defb 12,2,16,2,9,31,13,31,6,24,10,24,3,21,7,21
        defb 0,14,28,14,29,11,25,11,26,4,22,4,23,1,19,1
        defb 20,26,8,26,1,23,5,23,14,16,2,16,27,13,31,13
        defb 8,6,20,6,21,3,17,3,2,28,14,28,15,25,11,25
        defb 28,18,0,18,25,15,29,15,22,8,26,8,19,5,23,5
        defb 16,30,12,30,13,27,9,27,10,20,6,20,7,17,3,17
        defb 4,10,24,10,17,7,21,7,30,0,18,0,11,29,15,29
        defb 24,22,4,22,5,19,1,19,18,12,30,12,31,9,27,9
        defb 12,2,16,2,9,31,13,31,6,24,10,24,3,21,7,21

MegaBrain1:
        defb 30,3,0,25,31,10,17,24,28,1,18,11,13,8,19,26
        defb 26,7,4,29,19,6,29,20,24,5,22,15,17,20,15,6
        defb 22,11,8,17,23,2,25,16,4,25,10,19,21,16,11,2
        defb 18,15,12,21,11,30,5,12,0,29,14,23,25,28,7,14
        defb 14,19,16,9,15,26,1,8,12,17,2,27,29,24,3,10
        defb 10,23,20,13,3,22,13,4,8,21,6,31,1,4,31,22
        defb 6,27,24,1,7,18,9,0,20,9,26,3,5,0,27,18
        defb 2,31,28,5,27,14,21,28,16,13,30,7,9,12,23,30
        defb 30,3,0,25,31,10,17,24,28,1,18,11,13,8,19,26
        defb 26,7,4,29,19,6,29,20,24,5,22,15,17,20,15,6
        defb 22,11,8,17,23,2,25,16,4,25,10,19,21,16,11,2
        defb 18,15,12,21,11,30,5,12,0,29,14,23,25,28,7,14
        defb 14,19,16,9,15,26,1,8,12,17,2,27,29,24,3,10
        defb 10,23,20,13,3,22,13,4,8,21,6,31,1,4,31,22
        defb 6,27,24,1,7,18,9,0,20,9,26,3,5,0,27,18
        defb 2,31,28,5,27,14,21,28,16,13,30,7,9,12,23,30

MegaBrain2:
        defb 28,16,16,20,9,13,13,1,6,26,26,30,19,23,23,11
        defb 8,4,4,0,21,17,17,29,18,14,14,10,31,27,27,7
        defb 20,24,24,28,1,5,5,9,30,2,2,6,11,15,15,19
        defb 0,12,12,8,13,9,9,5,10,22,22,18,23,19,19,15
        defb 12,0,0,4,25,29,29,17,22,10,10,14,3,7,7,27
        defb 24,20,20,16,5,1,1,13,2,30,30,26,15,11,11,23
        defb 4,8,8,12,17,21,21,25,14,18,18,22,27,31,31,3
        defb 16,28,28,24,29,25,25,21,26,6,6,2,7,3,3,31
        defb 28,16,16,20,9,13,13,1,6,26,26,30,19,23,23,11
        defb 8,4,4,0,21,17,17,29,18,14,14,10,31,27,27,7
        defb 20,24,24,28,1,5,5,9,30,2,2,6,11,15,15,19
        defb 0,12,12,8,13,9,9,5,10,22,22,18,23,19,19,15
        defb 12,0,0,4,25,29,29,17,22,10,10,14,3,7,7,27
        defb 24,20,20,16,5,1,1,13,2,30,30,26,15,11,11,23
        defb 4,8,8,12,17,21,21,25,14,18,18,22,27,31,31,3
        defb 16,28,28,24,29,25,25,21,26,6,6,2,7,3,3,31

MegaBrain3:
        defb 30,21,8,31,7,12,25,22,28,23,10,13,21,30,27,20
        defb 26,17,12,27,11,0,21,26,24,19,14,9,9,2,7,8
        defb 22,29,0,23,15,4,17,30,4,15,18,21,13,6,3,12
        defb 18,25,4,19,19,24,13,2,0,11,22,17,1,10,15,0
        defb 14,5,24,15,23,28,9,6,12,7,26,29,5,14,11,4
        defb 10,1,28,11,27,16,5,10,8,3,30,25,25,18,23,24
        defb 6,13,16,7,31,20,1,14,20,31,2,5,29,22,19,28
        defb 2,9,20,3,3,8,29,18,16,27,6,1,17,26,31,16
        defb 30,21,8,31,7,12,25,22,28,23,10,13,21,30,27,20
        defb 26,17,12,27,11,0,21,26,24,19,14,9,9,2,7,8
        defb 22,29,0,23,15,4,17,30,4,15,18,21,13,6,3,12
        defb 18,25,4,19,19,24,13,2,0,11,22,17,1,10,15,0
        defb 14,5,24,15,23,28,9,6,12,7,26,29,5,14,11,4
        defb 10,1,28,11,27,16,5,10,8,3,30,25,25,18,23,24
        defb 6,13,16,7,31,20,1,14,20,31,2,5,29,22,19,28
        defb 2,9,20,3,3,8,29,18,16,27,6,1,17,26,31,16

MegaBrain4:
        defb 24,18,28,10,29,7,17,31,2,24,6,16,7,13,27,5
        defb 12,6,8,30,1,27,13,3,22,12,18,4,11,1,23,9
        defb 16,26,20,2,21,15,25,23,26,0,30,8,31,21,3,29
        defb 4,14,0,22,25,3,21,27,14,20,10,28,3,9,31,1
        defb 8,2,12,26,13,23,1,15,18,8,22,0,23,29,11,21
        defb 28,22,24,14,17,11,29,19,6,28,2,20,27,17,7,25
        defb 0,10,4,18,5,31,9,7,10,16,14,24,15,5,19,13
        defb 20,30,16,6,9,19,5,11,30,4,26,12,19,25,15,17
        defb 24,18,28,10,29,7,17,31,2,24,6,16,7,13,27,5
        defb 12,6,8,30,1,27,13,3,22,12,18,4,11,1,23,9
        defb 16,26,20,2,21,15,25,23,26,0,30,8,31,21,3,29
        defb 4,14,0,22,25,3,21,27,14,20,10,28,3,9,31,1
        defb 8,2,12,26,13,23,1,15,18,8,22,0,23,29,11,21
        defb 28,22,24,14,17,11,29,19,6,28,2,20,27,17,7,25
        defb 0,10,4,18,5,31,9,7,10,16,14,24,15,5,19,13
        defb 20,30,16,6,9,19,5,11,30,4,26,12,19,25,15,17

MegaBrain5:
        defb 30,23,8,5,23,6,17,12,12,21,10,7,5,20,19,14
        defb 26,19,12,1,27,10,29,0,8,17,14,3,25,8,15,18
        defb 22,31,0,13,31,14,25,4,20,13,18,31,29,12,11,22
        defb 18,27,4,9,3,18,5,24,16,9,22,27,17,0,7,26
        defb 14,7,24,21,7,22,1,28,28,5,26,23,21,4,3,30
        defb 10,3,28,17,11,26,13,16,24,1,30,19,9,24,31,2
        defb 6,15,16,29,15,30,9,20,4,29,2,15,13,28,27,6
        defb 2,11,20,25,19,2,21,8,0,25,6,11,1,16,23,10
        defb 30,23,8,5,23,6,17,12,12,21,10,7,5,20,19,14
        defb 26,19,12,1,27,10,29,0,8,17,14,3,25,8,15,18
        defb 22,31,0,13,31,14,25,4,20,13,18,31,29,12,11,22
        defb 18,27,4,9,3,18,5,24,16,9,22,27,17,0,7,26
        defb 14,7,24,21,7,22,1,28,28,5,26,23,21,4,3,30
        defb 10,3,28,17,11,26,13,16,24,1,30,19,9,24,31,2
        defb 6,15,16,29,15,30,9,20,4,29,2,15,13,28,27,6
        defb 2,11,20,25,19,2,21,8,0,25,6,11,1,16,23,10

MegaBrain6:
        defb 28,4,0,0,1,25,5,5,6,14,10,10,11,3,15,15
        defb 8,16,20,20,29,5,25,25,18,26,30,30,7,15,3,3
        defb 20,12,8,8,9,17,13,13,30,22,18,18,19,27,23,23
        defb 0,24,28,28,5,29,1,1,10,2,6,6,15,7,11,11
        defb 12,20,16,16,17,9,21,21,22,30,26,26,27,19,31,31
        defb 24,0,4,4,13,21,9,9,2,10,14,14,23,31,19,19
        defb 4,28,24,24,25,1,29,29,14,6,2,2,3,11,7,7
        defb 16,8,12,12,21,13,17,17,26,18,22,22,31,23,27,27
        defb 28,4,0,0,1,25,5,5,6,14,10,10,11,3,15,15
        defb 8,16,20,20,29,5,25,25,18,26,30,30,7,15,3,3
        defb 20,12,8,8,9,17,13,13,30,22,18,18,19,27,23,23
        defb 0,24,28,28,5,29,1,1,10,2,6,6,15,7,11,11
        defb 12,20,16,16,17,9,21,21,22,30,26,26,27,19,31,31
        defb 24,0,4,4,13,21,9,9,2,10,14,14,23,31,19,19
        defb 4,28,24,24,25,1,29,29,14,6,2,2,3,11,7,7
        defb 16,8,12,12,21,13,17,17,26,18,22,22,31,23,27,27

MegaBrain7:
        defb 30,25,24,27,31,24,17,26,12,11,26,25,13,10,3,24
        defb 26,29,28,31,19,20,29,22,8,15,30,29,17,22,31,4
        defb 22,17,16,19,23,16,25,18,20,19,2,1,21,18,27,0
        defb 18,21,20,23,11,12,5,14,16,23,6,5,25,30,23,12
        defb 14,9,8,11,15,8,1,10,28,27,10,9,29,26,19,8
        defb 10,13,12,15,3,4,13,6,24,31,14,13,1,6,15,20
        defb 6,1,0,3,7,0,9,2,4,3,18,17,5,2,11,16
        defb 2,5,4,7,27,28,21,30,0,7,22,21,9,14,7,28
        defb 30,25,24,27,31,24,17,26,12,11,26,25,13,10,3,24
        defb 26,29,28,31,19,20,29,22,8,15,30,29,17,22,31,4
        defb 22,17,16,19,23,16,25,18,20,19,2,1,21,18,27,0
        defb 18,21,20,23,11,12,5,14,16,23,6,5,25,30,23,12
        defb 14,9,8,11,15,8,1,10,28,27,10,9,29,26,19,8
        defb 10,13,12,15,3,4,13,6,24,31,14,13,1,6,15,20
        defb 6,1,0,3,7,0,9,2,4,3,18,17,5,2,11,16
        defb 2,5,4,7,27,28,21,30,0,7,22,21,9,14,7,28

MegaBrain8:
        defb 16,22,12,6,13,19,9,3,26,28,22,12,23,25,19,9
        defb 4,2,24,18,17,15,21,31,14,8,2,24,27,21,31,5
        defb 24,30,4,14,5,27,1,11,2,4,14,20,15,1,11,17
        defb 12,10,16,26,9,23,13,7,22,16,26,0,19,29,23,13
        defb 0,6,28,22,29,3,25,19,10,12,6,28,7,9,3,25
        defb 20,18,8,2,1,31,5,15,30,24,18,8,11,5,15,21
        defb 8,14,20,30,21,11,17,27,18,20,30,4,31,17,27,1
        defb 28,26,0,10,25,7,29,23,6,0,10,16,3,13,7,29
        defb 16,22,12,6,13,19,9,3,26,28,22,12,23,25,19,9
        defb 4,2,24,18,17,15,21,31,14,8,2,24,27,21,31,5
        defb 24,30,4,14,5,27,1,11,2,4,14,20,15,1,11,17
        defb 12,10,16,26,9,23,13,7,22,16,26,0,19,29,23,13
        defb 0,6,28,22,29,3,25,19,10,12,6,28,7,9,3,25
        defb 20,18,8,2,1,31,5,15,30,24,18,8,11,5,15,21
        defb 8,14,20,30,21,11,17,27,18,20,30,4,31,17,27,1
        defb 28,26,0,10,25,7,29,23,6,0,10,16,3,13,7,29

MegaBrain9:
        defb 30,11,0,17,15,18,1,16,12,25,2,19,13,0,19,2
        defb 26,15,4,21,3,30,13,28,8,29,6,23,17,28,15,30
        defb 22,3,8,25,7,26,9,24,20,1,26,11,21,24,11,26
        defb 18,7,12,29,27,6,21,4,16,5,30,15,25,20,7,22
        defb 14,27,16,1,31,2,17,0,28,9,18,3,29,16,3,18
        defb 10,31,20,5,19,14,29,12,24,13,22,7,1,12,31,14
        defb 6,19,24,9,23,10,25,8,4,17,10,27,5,8,27,10
        defb 2,23,28,13,11,22,5,20,0,21,14,31,9,4,23,6
        defb 30,11,0,17,15,18,1,16,12,25,2,19,13,0,19,2
        defb 26,15,4,21,3,30,13,28,8,29,6,23,17,28,15,30
        defb 22,3,8,25,7,26,9,24,20,1,26,11,21,24,11,26
        defb 18,7,12,29,27,6,21,4,16,5,30,15,25,20,7,22
        defb 14,27,16,1,31,2,17,0,28,9,18,3,29,16,3,18
        defb 10,31,20,5,19,14,29,12,24,13,22,7,1,12,31,14
        defb 6,19,24,9,23,10,25,8,4,17,10,27,5,8,27,10
        defb 2,23,28,13,11,22,5,20,0,21,14,31,9,4,23,6

MegaBrain10:
        defb 28,24,16,12,9,21,29,25,22,18,10,6,3,15,23,19
        defb 8,12,4,24,21,9,1,5,2,6,30,18,15,3,27,31
        defb 20,16,24,4,1,29,21,17,14,10,18,30,27,23,15,11
        defb 0,4,12,16,13,17,25,29,26,30,6,10,7,11,19,23
        defb 12,8,0,28,25,5,13,9,6,2,26,22,19,31,7,3
        defb 24,28,20,8,5,25,17,21,18,22,14,2,31,19,11,15
        defb 4,0,8,20,17,13,5,1,30,26,2,14,11,7,31,27
        defb 16,20,28,0,29,1,9,13,10,14,22,26,23,27,3,7
        defb 28,24,16,12,9,21,29,25,22,18,10,6,3,15,23,19
        defb 8,12,4,24,21,9,1,5,2,6,30,18,15,3,27,31
        defb 20,16,24,4,1,29,21,17,14,10,18,30,27,23,15,11
        defb 0,4,12,16,13,17,25,29,26,30,6,10,7,11,19,23
        defb 12,8,0,28,25,5,13,9,6,2,26,22,19,31,7,3
        defb 24,28,20,8,5,25,17,21,18,22,14,2,31,19,11,15
        defb 4,0,8,20,17,13,5,1,30,26,2,14,11,7,31,27
        defb 16,20,28,0,29,1,9,13,10,14,22,26,23,27,3,7

MegaBrain11:
        defb 30,29,24,23,23,20,9,14,12,15,10,21,21,22,27,28
        defb 26,25,28,19,27,24,5,2,8,11,14,17,9,10,7,0
        defb 22,21,16,31,31,28,1,6,20,23,18,13,13,14,3,4
        defb 18,17,20,27,3,0,29,26,16,19,22,9,1,2,15,8
        defb 14,13,8,7,7,4,25,30,28,31,26,5,5,6,11,12
        defb 10,9,12,3,11,8,21,18,24,27,30,1,25,26,23,16
        defb 6,5,0,15,15,12,17,22,4,7,2,29,29,30,19,20
        defb 2,1,4,11,19,16,13,10,0,3,6,25,17,18,31,24
        defb 30,29,24,23,23,20,9,14,12,15,10,21,21,22,27,28
        defb 26,25,28,19,27,24,5,2,8,11,14,17,9,10,7,0
        defb 22,21,16,31,31,28,1,6,20,23,18,13,13,14,3,4
        defb 18,17,20,27,3,0,29,26,16,19,22,9,1,2,15,8
        defb 14,13,8,7,7,4,25,30,28,31,26,5,5,6,11,12
        defb 10,9,12,3,11,8,21,18,24,27,30,1,25,26,23,16
        defb 6,5,0,15,15,12,17,22,4,7,2,29,29,30,19,20
        defb 2,1,4,11,19,16,13,10,0,3,6,25,17,18,31,24

MegaBrain12:
        defb 24,26,28,2,13,15,1,23,18,16,22,24,7,5,27,13
        defb 12,14,8,22,17,19,29,11,6,4,2,12,11,9,23,1
        defb 16,18,20,10,5,7,9,31,10,8,14,0,31,29,3,21
        defb 4,6,0,30,9,11,5,19,30,28,26,20,3,1,31,9
        defb 8,10,12,18,29,31,17,7,2,0,6,8,23,21,11,29
        defb 28,30,24,6,1,3,13,27,22,20,18,28,27,25,7,17
        defb 0,2,4,26,21,23,25,15,26,24,30,16,15,13,19,5
        defb 20,22,16,14,25,27,21,3,14,12,10,4,19,17,15,25
        defb 24,26,28,2,13,15,1,23,18,16,22,24,7,5,27,13
        defb 12,14,8,22,17,19,29,11,6,4,2,12,11,9,23,1
        defb 16,18,20,10,5,7,9,31,10,8,14,0,31,29,3,21
        defb 4,6,0,30,9,11,5,19,30,28,26,20,3,1,31,9
        defb 8,10,12,18,29,31,17,7,2,0,6,8,23,21,11,29
        defb 28,30,24,6,1,3,13,27,22,20,18,28,27,25,7,17
        defb 0,2,4,26,21,23,25,15,26,24,30,16,15,13,19,5
        defb 20,22,16,14,25,27,21,3,14,12,10,4,19,17,15,25

MegaBrain13:
        defb 30,31,8,29,23,14,17,4,28,13,26,15,21,12,3,22
        defb 26,27,12,25,27,2,29,8,24,9,30,11,9,16,31,10
        defb 22,23,0,21,31,6,25,12,4,21,2,23,13,20,27,14
        defb 18,19,4,17,3,26,5,16,0,17,6,19,1,24,23,2
        defb 14,15,24,13,7,30,1,20,12,29,10,31,5,28,19,6
        defb 10,11,28,9,11,18,13,24,8,25,14,27,25,0,15,26
        defb 6,7,16,5,15,22,9,28,20,5,18,7,29,4,11,30
        defb 2,3,20,1,19,10,21,0,16,1,22,3,17,8,7,18
        defb 30,31,8,29,23,14,17,4,28,13,26,15,21,12,3,22
        defb 26,27,12,25,27,2,29,8,24,9,30,11,9,16,31,10
        defb 22,23,0,21,31,6,25,12,4,21,2,23,13,20,27,14
        defb 18,19,4,17,3,26,5,16,0,17,6,19,1,24,23,2
        defb 14,15,24,13,7,30,1,20,12,29,10,31,5,28,19,6
        defb 10,11,28,9,11,18,13,24,8,25,14,27,25,0,15,26
        defb 6,7,16,5,15,22,9,28,20,5,18,7,29,4,11,30
        defb 2,3,20,1,19,10,21,0,16,1,22,3,17,8,7,18

MegaBrain14:
        defb 28,12,16,24,17,1,21,29,22,6,10,18,11,27,15,23
        defb 8,24,4,12,13,29,9,1,2,18,30,6,7,23,3,27
        defb 20,4,24,16,25,9,29,21,14,30,18,10,19,3,23,15
        defb 0,16,12,4,21,5,17,25,26,10,6,30,15,31,11,19
        defb 12,28,0,8,1,17,5,13,6,22,26,2,27,11,31,7
        defb 24,8,20,28,29,13,25,17,18,2,14,22,23,7,19,11
        defb 4,20,8,0,9,25,13,5,30,14,2,26,3,19,7,31
        defb 16,0,28,20,5,21,1,9,10,26,22,14,31,15,27,3
        defb 28,12,16,24,17,1,21,29,22,6,10,18,11,27,15,23
        defb 8,24,4,12,13,29,9,1,2,18,30,6,7,23,3,27
        defb 20,4,24,16,25,9,29,21,14,30,18,10,19,3,23,15
        defb 0,16,12,4,21,5,17,25,26,10,6,30,15,31,11,19
        defb 12,28,0,8,1,17,5,13,6,22,26,2,27,11,31,7
        defb 24,8,20,28,29,13,25,17,18,2,14,22,23,7,19,11
        defb 4,20,8,0,9,25,13,5,30,14,2,26,3,19,7,31
        defb 16,0,28,20,5,21,1,9,10,26,22,14,31,15,27,3

MegaBrain15:
        defb 30,1,24,19,31,0,1,18,28,3,10,1,29,2,3,0
        defb 26,5,28,23,19,12,13,30,24,7,14,5,1,30,31,28
        defb 22,9,16,27,23,8,9,26,4,27,18,25,5,26,27,24
        defb 18,13,20,31,11,20,21,6,0,31,22,29,9,22,23,20
        defb 14,17,8,3,15,16,17,2,12,19,26,17,13,18,19,16
        defb 10,21,12,7,3,28,29,14,8,23,30,21,17,14,15,12
        defb 6,25,0,11,7,24,25,10,20,11,2,9,21,10,11,8
        defb 2,29,4,15,27,4,5,22,16,15,6,13,25,6,7,4
        defb 30,1,24,19,31,0,1,18,28,3,10,1,29,2,3,0
        defb 26,5,28,23,19,12,13,30,24,7,14,5,1,30,31,28
        defb 22,9,16,27,23,8,9,26,4,27,18,25,5,26,27,24
        defb 18,13,20,31,11,20,21,6,0,31,22,29,9,22,23,20
        defb 14,17,8,3,15,16,17,2,12,19,26,17,13,18,19,16
        defb 10,21,12,7,3,28,29,14,8,23,30,21,17,14,15,12
        defb 6,25,0,11,7,24,25,10,20,11,2,9,21,10,11,8
        defb 2,29,4,15,27,4,5,22,16,15,6,13,25,6,7,4

MegaBrain16:
        defb 0,30,28,30,29,27,25,27,26,20,22,20,23,17,19,17
        defb 20,10,8,10,1,7,5,7,14,0,2,0,27,29,31,29
        defb 8,22,20,22,21,19,17,19,2,12,14,12,15,9,11,9
        defb 28,2,0,2,25,31,29,31,22,24,26,24,19,21,23,21
        defb 16,14,12,14,13,11,9,11,10,4,6,4,7,1,3,1
        defb 4,26,24,26,17,23,21,23,30,16,18,16,11,13,15,13
        defb 24,6,4,6,5,3,1,3,18,28,30,28,31,25,27,25
        defb 12,18,16,18,9,15,13,15,6,8,10,8,3,5,7,5
        defb 0,30,28,30,29,27,25,27,26,20,22,20,23,17,19,17
        defb 20,10,8,10,1,7,5,7,14,0,2,0,27,29,31,29
        defb 8,22,20,22,21,19,17,19,2,12,14,12,15,9,11,9
        defb 28,2,0,2,25,31,29,31,22,24,26,24,19,21,23,21
        defb 16,14,12,14,13,11,9,11,10,4,6,4,7,1,3,1
        defb 4,26,24,26,17,23,21,23,30,16,18,16,11,13,15,13
        defb 24,6,4,6,5,3,1,3,18,28,30,28,31,25,27,25
        defb 12,18,16,18,9,15,13,15,6,8,10,8,3,5,7,5

MegaBrain17:
        defb 30,19,0,9,31,26,17,8,28,17,18,27,13,24,19,10
        defb 26,23,4,13,19,22,29,4,24,21,22,31,17,4,15,22
        defb 22,27,8,1,23,18,25,0,4,9,10,3,21,0,11,18
        defb 18,31,12,5,11,14,5,28,0,13,14,7,25,12,7,30
        defb 14,3,16,25,15,10,1,24,12,1,2,11,29,8,3,26
        defb 10,7,20,29,3,6,13,20,8,5,6,15,1,20,31,6
        defb 6,11,24,17,7,2,9,16,20,25,26,19,5,16,27,2
        defb 2,15,28,21,27,30,21,12,16,29,30,23,9,28,23,14
        defb 30,19,0,9,31,26,17,8,28,17,18,27,13,24,19,10
        defb 26,23,4,13,19,22,29,4,24,21,22,31,17,4,15,22
        defb 22,27,8,1,23,18,25,0,4,9,10,3,21,0,11,18
        defb 18,31,12,5,11,14,5,28,0,13,14,7,25,12,7,30
        defb 14,3,16,25,15,10,1,24,12,1,2,11,29,8,3,26
        defb 10,7,20,29,3,6,13,20,8,5,6,15,1,20,31,6
        defb 6,11,24,17,7,2,9,16,20,25,26,19,5,16,27,2
        defb 2,15,28,21,27,30,21,12,16,29,30,23,9,28,23,14

MegaBrain18:
        defb 28,0,16,4,9,29,13,17,6,10,26,14,19,7,23,27
        defb 8,20,4,16,21,1,17,13,18,30,14,26,31,11,27,23
        defb 20,8,24,12,1,21,5,25,30,18,2,22,11,31,15,3
        defb 0,28,12,24,13,25,9,21,10,6,22,2,23,3,19,31
        defb 12,16,0,20,25,13,29,1,22,26,10,30,3,23,7,11
        defb 24,4,20,0,5,17,1,29,2,14,30,10,15,27,11,7
        defb 4,24,8,28,17,5,21,9,14,2,18,6,27,15,31,19
        defb 16,12,28,8,29,9,25,5,26,22,6,18,7,19,3,15
        defb 28,0,16,4,9,29,13,17,6,10,26,14,19,7,23,27
        defb 8,20,4,16,21,1,17,13,18,30,14,26,31,11,27,23
        defb 20,8,24,12,1,21,5,25,30,18,2,22,11,31,15,3
        defb 0,28,12,24,13,25,9,21,10,6,22,2,23,3,19,31
        defb 12,16,0,20,25,13,29,1,22,26,10,30,3,23,7,11
        defb 24,4,20,0,5,17,1,29,2,14,30,10,15,27,11,7
        defb 4,24,8,28,17,5,21,9,14,2,18,6,27,15,31,19
        defb 16,12,28,8,29,9,25,5,26,22,6,18,7,19,3,15

MegaBrain19:
        defb 30,5,8,15,7,28,25,6,28,7,10,29,21,14,27,4
        defb 26,1,12,11,11,16,21,10,24,3,14,25,9,18,7,24
        defb 22,13,0,7,15,20,17,14,4,31,18,5,13,22,3,28
        defb 18,9,4,3,19,8,13,18,0,27,22,1,1,26,15,16
        defb 14,21,24,31,23,12,9,22,12,23,26,13,5,30,11,20
        defb 10,17,28,27,27,0,5,26,8,19,30,9,25,2,23,8
        defb 6,29,16,23,31,4,1,30,20,15,2,21,29,6,19,12
        defb 2,25,20,19,3,24,29,2,16,11,6,17,17,10,31,0
        defb 30,5,8,15,7,28,25,6,28,7,10,29,21,14,27,4
        defb 26,1,12,11,11,16,21,10,24,3,14,25,9,18,7,24
        defb 22,13,0,7,15,20,17,14,4,31,18,5,13,22,3,28
        defb 18,9,4,3,19,8,13,18,0,27,22,1,1,26,15,16
        defb 14,21,24,31,23,12,9,22,12,23,26,13,5,30,11,20
        defb 10,17,28,27,27,0,5,26,8,19,30,9,25,2,23,8
        defb 6,29,16,23,31,4,1,30,20,15,2,21,29,6,19,12
        defb 2,25,20,19,3,24,29,2,16,11,6,17,17,10,31,0

MegaBrain20:
        defb 24,2,28,26,29,23,17,15,2,8,6,0,7,29,27,21
        defb 12,22,8,14,1,11,13,19,22,28,18,20,11,17,23,25
        defb 16,10,20,18,21,31,25,7,26,16,30,24,31,5,3,13
        defb 4,30,0,6,25,19,21,11,14,4,10,12,3,25,31,17
        defb 8,18,12,10,13,7,1,31,18,24,22,16,23,13,11,5
        defb 28,6,24,30,17,27,29,3,6,12,2,4,27,1,7,9
        defb 0,26,4,2,5,15,9,23,10,0,14,8,15,21,19,29
        defb 20,14,16,22,9,3,5,27,30,20,26,28,19,9,15,1
        defb 24,2,28,26,29,23,17,15,2,8,6,0,7,29,27,21
        defb 12,22,8,14,1,11,13,19,22,28,18,20,11,17,23,25
        defb 16,10,20,18,21,31,25,7,26,16,30,24,31,5,3,13
        defb 4,30,0,6,25,19,21,11,14,4,10,12,3,25,31,17
        defb 8,18,12,10,13,7,1,31,18,24,22,16,23,13,11,5
        defb 28,6,24,30,17,27,29,3,6,12,2,4,27,1,7,9
        defb 0,26,4,2,5,15,9,23,10,0,14,8,15,21,19,29
        defb 20,14,16,22,9,3,5,27,30,20,26,28,19,9,15,1

MegaBrain21:
        defb 30,7,8,21,23,22,17,28,12,5,10,23,5,4,19,30
        defb 26,3,12,17,27,26,29,16,8,1,14,19,25,24,15,2
        defb 22,15,0,29,31,30,25,20,20,29,18,15,29,28,11,6
        defb 18,11,4,25,3,2,5,8,16,25,22,11,17,16,7,10
        defb 14,23,24,5,7,6,1,12,28,21,26,7,21,20,3,14
        defb 10,19,28,1,11,10,13,0,24,17,30,3,9,8,31,18
        defb 6,31,16,13,15,14,9,4,4,13,2,31,13,12,27,22
        defb 2,27,20,9,19,18,21,24,0,9,6,27,1,0,23,26
        defb 30,7,8,21,23,22,17,28,12,5,10,23,5,4,19,30
        defb 26,3,12,17,27,26,29,16,8,1,14,19,25,24,15,2
        defb 22,15,0,29,31,30,25,20,20,29,18,15,29,28,11,6
        defb 18,11,4,25,3,2,5,8,16,25,22,11,17,16,7,10
        defb 14,23,24,5,7,6,1,12,28,21,26,7,21,20,3,14
        defb 10,19,28,1,11,10,13,0,24,17,30,3,9,8,31,18
        defb 6,31,16,13,15,14,9,4,4,13,2,31,13,12,27,22
        defb 2,27,20,9,19,18,21,24,0,9,6,27,1,0,23,26

MegaBrain22:
        defb 28,20,0,16,1,9,5,21,6,30,10,26,11,19,15,31
        defb 8,0,20,4,29,21,25,9,18,10,30,14,7,31,3,19
        defb 20,28,8,24,9,1,13,29,30,6,18,2,19,11,23,7
        defb 0,8,28,12,5,13,1,17,10,18,6,22,15,23,11,27
        defb 12,4,16,0,17,25,21,5,22,14,26,10,27,3,31,15
        defb 24,16,4,20,13,5,9,25,2,26,14,30,23,15,19,3
        defb 4,12,24,8,25,17,29,13,14,22,2,18,3,27,7,23
        defb 16,24,12,28,21,29,17,1,26,2,22,6,31,7,27,11
        defb 28,20,0,16,1,9,5,21,6,30,10,26,11,19,15,31
        defb 8,0,20,4,29,21,25,9,18,10,30,14,7,31,3,19
        defb 20,28,8,24,9,1,13,29,30,6,18,2,19,11,23,7
        defb 0,8,28,12,5,13,1,17,10,18,6,22,15,23,11,27
        defb 12,4,16,0,17,25,21,5,22,14,26,10,27,3,31,15
        defb 24,16,4,20,13,5,9,25,2,26,14,30,23,15,19,3
        defb 4,12,24,8,25,17,29,13,14,22,2,18,3,27,7,23
        defb 16,24,12,28,21,29,17,1,26,2,22,6,31,7,27,11

MegaBrain23:
        defb 30,9,24,11,31,8,17,10,12,27,26,9,13,26,3,8
        defb 26,13,28,15,19,4,29,6,8,31,30,13,17,6,31,20
        defb 22,1,16,3,23,0,25,2,20,3,2,17,21,2,27,16
        defb 18,5,20,7,11,28,5,30,16,7,6,21,25,14,23,28
        defb 14,25,8,27,15,24,1,26,28,11,10,25,29,10,19,24
        defb 10,29,12,31,3,20,13,22,24,15,14,29,1,22,15,4
        defb 6,17,0,19,7,16,9,18,4,19,18,1,5,18,11,0
        defb 2,21,4,23,27,12,21,14,0,23,22,5,9,30,7,12
        defb 30,9,24,11,31,8,17,10,12,27,26,9,13,26,3,8
        defb 26,13,28,15,19,4,29,6,8,31,30,13,17,6,31,20
        defb 22,1,16,3,23,0,25,2,20,3,2,17,21,2,27,16
        defb 18,5,20,7,11,28,5,30,16,7,6,21,25,14,23,28
        defb 14,25,8,27,15,24,1,26,28,11,10,25,29,10,19,24
        defb 10,29,12,31,3,20,13,22,24,15,14,29,1,22,15,4
        defb 6,17,0,19,7,16,9,18,4,19,18,1,5,18,11,0
        defb 2,21,4,23,27,12,21,14,0,23,22,5,9,30,7,12

; REV15 extra reserved brain planes to push source size closer to 150K.
MegaBrain24:
        defb 8,9,11,6,14,15,21,16,4,5,7,26,18,19,25,28
        defb 16,17,19,30,22,23,13,8,28,29,31,2,10,11,1,4
        defb 24,25,27,22,30,31,5,0,20,21,23,10,2,3,9,12
        defb 0,1,3,14,6,7,29,24,12,13,15,18,26,27,17,20
        defb 8,9,11,6,14,15,21,16,4,5,7,26,18,19,25,28
        defb 16,17,19,30,22,23,13,8,28,29,31,2,10,11,1,4
        defb 24,25,27,22,30,31,5,0,20,21,23,10,2,3,9,12
        defb 0,1,3,14,6,7,29,24,12,13,15,18,26,27,17,20
        defb 8,9,11,6,14,15,21,16,4,5,7,26,18,19,25,28
        defb 16,17,19,30,22,23,13,8,28,29,31,2,10,11,1,4
        defb 24,25,27,22,30,31,5,0,20,21,23,10,2,3,9,12
        defb 0,1,3,14,6,7,29,24,12,13,15,18,26,27,17,20
        defb 8,9,11,6,14,15,21,16,4,5,7,26,18,19,25,28
        defb 16,17,19,30,22,23,13,8,28,29,31,2,10,11,1,4
        defb 24,25,27,22,30,31,5,0,20,21,23,10,2,3,9,12
        defb 0,1,3,14,6,7,29,24,12,13,15,18,26,27,17,20

MegaBrain25:
        defb 31,21,10,0,21,31,0,10,11,1,30,20,1,11,20,30
        defb 23,29,2,8,29,23,8,2,3,9,22,28,9,3,28,22
        defb 15,5,26,16,5,15,16,26,27,17,14,4,17,27,4,14
        defb 7,13,18,24,13,7,24,18,19,25,6,12,25,19,12,6
        defb 31,21,10,0,21,31,0,10,11,1,30,20,1,11,20,30
        defb 23,29,2,8,29,23,8,2,3,9,22,28,9,3,28,22
        defb 15,5,26,16,5,15,16,26,27,17,14,4,17,27,4,14
        defb 7,13,18,24,13,7,24,18,19,25,6,12,25,19,12,6
        defb 31,21,10,0,21,31,0,10,11,1,30,20,1,11,20,30
        defb 23,29,2,8,29,23,8,2,3,9,22,28,9,3,28,22
        defb 15,5,26,16,5,15,16,26,27,17,14,4,17,27,4,14
        defb 7,13,18,24,13,7,24,18,19,25,6,12,25,19,12,6
        defb 31,21,10,0,21,31,0,10,11,1,30,20,1,11,20,30
        defb 23,29,2,8,29,23,8,2,3,9,22,28,9,3,28,22
        defb 15,5,26,16,5,15,16,26,27,17,14,4,17,27,4,14
        defb 7,13,18,24,13,7,24,18,19,25,6,12,25,19,12,6

MegaBrain26:
        defb 22,25,9,22,8,31,23,0,10,21,5,10,20,3,27,12
        defb 14,1,17,14,16,7,15,24,18,13,29,18,12,27,3,20
        defb 6,9,25,6,24,15,7,16,26,5,21,26,4,19,11,28
        defb 30,17,1,30,0,23,31,8,2,29,13,2,28,11,19,4
        defb 22,25,9,22,8,31,23,0,10,21,5,10,20,3,27,12
        defb 14,1,17,14,16,7,15,24,18,13,29,18,12,27,3,20
        defb 6,9,25,6,24,15,7,16,26,5,21,26,4,19,11,28
        defb 30,17,1,30,0,23,31,8,2,29,13,2,28,11,19,4
        defb 22,25,9,22,8,31,23,0,10,21,5,10,20,3,27,12
        defb 14,1,17,14,16,7,15,24,18,13,29,18,12,27,3,20
        defb 6,9,25,6,24,15,7,16,26,5,21,26,4,19,11,28
        defb 30,17,1,30,0,23,31,8,2,29,13,2,28,11,19,4
        defb 22,25,9,22,8,31,23,0,10,21,5,10,20,3,27,12
        defb 14,1,17,14,16,7,15,24,18,13,29,18,12,27,3,20
        defb 6,9,25,6,24,15,7,16,26,5,21,26,4,19,11,28
        defb 30,17,1,30,0,23,31,8,2,29,13,2,28,11,19,4

MegaBrain27:
        defb 13,29,12,28,15,31,14,30,9,25,8,24,11,27,10,26
        defb 5,21,4,20,7,23,6,22,1,17,0,16,3,19,2,18
        defb 29,13,28,12,31,15,30,14,25,9,24,8,27,11,26,10
        defb 21,5,20,4,23,7,22,6,17,1,16,0,19,3,18,2
        defb 13,29,12,28,15,31,14,30,9,25,8,24,11,27,10,26
        defb 5,21,4,20,7,23,6,22,1,17,0,16,3,19,2,18
        defb 29,13,28,12,31,15,30,14,25,9,24,8,27,11,26,10
        defb 21,5,20,4,23,7,22,6,17,1,16,0,19,3,18,2
        defb 13,29,12,28,15,31,14,30,9,25,8,24,11,27,10,26
        defb 5,21,4,20,7,23,6,22,1,17,0,16,3,19,2,18
        defb 29,13,28,12,31,15,30,14,25,9,24,8,27,11,26,10
        defb 21,5,20,4,23,7,22,6,17,1,16,0,19,3,18,2
        defb 13,29,12,28,15,31,14,30,9,25,8,24,11,27,10,26
        defb 5,21,4,20,7,23,6,22,1,17,0,16,3,19,2,18
        defb 29,13,28,12,31,15,30,14,25,9,24,8,27,11,26,10
        defb 21,5,20,4,23,7,22,6,17,1,16,0,19,3,18,2


MegaBrain28:
        defb 21,16,30,27,3,14,8,21,25,28,2,7,15,18,20,25
        defb 13,8,6,3,27,22,16,13,1,4,26,31,23,10,12,1
        defb 5,0,14,11,19,30,24,5,9,12,18,23,31,2,4,9
        defb 29,24,22,19,11,6,0,29,17,20,10,15,7,26,28,17
        defb 21,16,30,27,3,14,8,21,25,28,2,7,15,18,20,25
        defb 13,8,6,3,27,22,16,13,1,4,26,31,23,10,12,1
        defb 5,0,14,11,19,30,24,5,9,12,18,23,31,2,4,9
        defb 29,24,22,19,11,6,0,29,17,20,10,15,7,26,28,17
        defb 21,16,30,27,3,14,8,21,25,28,2,7,15,18,20,25
        defb 13,8,6,3,27,22,16,13,1,4,26,31,23,10,12,1
        defb 5,0,14,11,19,30,24,5,9,12,18,23,31,2,4,9
        defb 29,24,22,19,11,6,0,29,17,20,10,15,7,26,28,17
        defb 21,16,30,27,3,14,8,21,25,28,2,7,15,18,20,25
        defb 13,8,6,3,27,22,16,13,1,4,26,31,23,10,12,1
        defb 5,0,14,11,19,30,24,5,9,12,18,23,31,2,4,9
        defb 29,24,22,19,11,6,0,29,17,20,10,15,7,26,28,17

TileColorTable:
        ; Graphics I has one color byte per 8 tile patterns.
        ; high nibble foreground, low nibble background.
        ; 0-79: original board/text patterns.
        defb 0f1h,0abh,0f1h,0f1h,0b1h,0b1h,0b1h,0b1h
        defb 0b1h,0f1h
        ; 80-103: white pieces on light tan squares.
        defb 0fbh,0fbh,0fbh
        ; 104-127: white pieces on dark tan squares.
        defb 0fah,0fah,0fah
        ; 128-151: black pieces on light tan squares.
        defb 01bh,01bh,01bh
        ; 152-175: black pieces on dark tan squares.
        defb 01ah,01ah,01ah
        ; 176-255 unused.
        defb 0f1h,0f1h,0f1h,0f1h,0f1h,0f1h,0f1h,0f1h
        defb 0f1h,0f1h

; ------------------------------------------------------------
; Tile patterns.

TilePatterns:
        ; 0 blank
        defb 00h,00h,00h,00h,00h,00h,00h,00h
        ; 1 horizontal frame - bold engraved rail
        defb 0ffh,0c3h,099h,0bdh,0bdh,099h,0c3h,0ffh
        ; 2 vertical frame - bold engraved pillar
        defb 0ffh,0dbh,0dbh,0c3h,0c3h,0dbh,0dbh,0ffh
        ; 3 corner jewel - ornate corner cap
        defb 0ffh,081h,0bdh,0a5h,099h,0bdh,081h,0ffh
        ; 4 star sparkle - diamond sparkle
        defb 00h,018h,03ch,07eh,03ch,018h,00h,00h
        ; 5 accent jewel - cross gem
        defb 018h,03ch,07eh,03ch,03ch,07eh,03ch,018h
        ; 6-7 unused
        defb 00h,00h,00h,00h,00h,00h,00h,00h
        defb 00h,00h,00h,00h,00h,00h,00h,00h
        ; 8 light square - parquet diamond grain
        defb 000h,022h,011h,088h,044h,022h,011h,088h
        ; 9 dark square - rich parquet weave
        defb 0AAh,055h,099h,066h,0AAh,055h,099h,066h
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

        ; REV13 tile piece set: WHITE LIGHT
        ; PAWN four 8x8 quadrants: UL UR LL LR
        defb 003h,007h,007h,003h,003h,007h,00Fh,00Dh
        defb 0C0h,0E0h,0E0h,0C0h,0C0h,0E0h,0F0h,0B0h
        defb 007h,007h,00Fh,01Fh,01Fh,03Fh,03Fh,000h
        defb 0E0h,0E0h,0F0h,0F8h,0F8h,0FCh,0FCh,000h
        ; ROOK four 8x8 quadrants: UL UR LL LR
        defb 01Dh,01Fh,01Fh,00Fh,00Fh,00Fh,00Fh,00Fh
        defb 0B8h,0F8h,0F8h,0F0h,0F0h,0F0h,0F0h,0F0h
        defb 00Fh,00Fh,01Fh,01Fh,03Fh,03Fh,03Fh,000h
        defb 0F0h,0F0h,0F8h,0F8h,0FCh,0FCh,0FCh,000h
        ; KNIGHT four 8x8 quadrants: UL UR LL LR
        defb 003h,007h,00Fh,00Fh,01Fh,01Fh,01Fh,01Fh
        defb 0E0h,0F0h,0F8h,0F0h,0F0h,0C0h,080h,0C0h
        defb 01Fh,01Fh,01Fh,01Fh,00Fh,03Fh,03Fh,000h
        defb 0F0h,0F8h,0F8h,0F8h,0F0h,0FCh,0FCh,000h
        ; BISHOP four 8x8 quadrants: UL UR LL LR
        defb 003h,007h,006h,003h,007h,007h,007h,00Fh
        defb 0C0h,0E0h,0E0h,0C0h,0E0h,0E0h,0E0h,0F0h
        defb 007h,007h,00Fh,00Fh,01Fh,03Fh,03Fh,000h
        defb 0E0h,0E0h,0F0h,0F0h,0F8h,0FCh,0FCh,000h
        ; QUEEN four 8x8 quadrants: UL UR LL LR
        defb 004h,00Fh,007h,00Fh,01Fh,00Fh,00Fh,00Fh
        defb 090h,0F8h,0E0h,0F0h,0F8h,0F0h,0F0h,0F0h
        defb 00Fh,01Fh,01Fh,03Fh,03Fh,03Fh,07Fh,000h
        defb 0F0h,0F8h,0F8h,0FCh,0FCh,0FCh,0FEh,000h
        ; KING four 8x8 quadrants: UL UR LL LR
        defb 001h,003h,001h,007h,00Fh,007h,007h,007h
        defb 080h,0C0h,080h,0E0h,0F0h,0E0h,0E0h,0E0h
        defb 00Fh,007h,007h,00Fh,01Fh,03Fh,03Fh,000h
        defb 0F0h,0E0h,0E0h,0F0h,0F8h,0FCh,0FCh,000h
        ; REV13 tile piece set: WHITE DARK
        ; PAWN four 8x8 quadrants: UL UR LL LR
        defb 003h,007h,007h,003h,003h,007h,00Fh,00Dh
        defb 0C0h,0E0h,0E0h,0C0h,0C0h,0E0h,0F0h,0B0h
        defb 007h,007h,00Fh,01Fh,01Fh,03Fh,03Fh,000h
        defb 0E0h,0E0h,0F0h,0F8h,0F8h,0FCh,0FCh,000h
        ; ROOK four 8x8 quadrants: UL UR LL LR
        defb 01Dh,01Fh,01Fh,00Fh,00Fh,00Fh,00Fh,00Fh
        defb 0B8h,0F8h,0F8h,0F0h,0F0h,0F0h,0F0h,0F0h
        defb 00Fh,00Fh,01Fh,01Fh,03Fh,03Fh,03Fh,000h
        defb 0F0h,0F0h,0F8h,0F8h,0FCh,0FCh,0FCh,000h
        ; KNIGHT four 8x8 quadrants: UL UR LL LR
        defb 003h,007h,00Fh,00Fh,01Fh,01Fh,01Fh,01Fh
        defb 0E0h,0F0h,0F8h,0F0h,0F0h,0C0h,080h,0C0h
        defb 01Fh,01Fh,01Fh,01Fh,00Fh,03Fh,03Fh,000h
        defb 0F0h,0F8h,0F8h,0F8h,0F0h,0FCh,0FCh,000h
        ; BISHOP four 8x8 quadrants: UL UR LL LR
        defb 003h,007h,006h,003h,007h,007h,007h,00Fh
        defb 0C0h,0E0h,0E0h,0C0h,0E0h,0E0h,0E0h,0F0h
        defb 007h,007h,00Fh,00Fh,01Fh,03Fh,03Fh,000h
        defb 0E0h,0E0h,0F0h,0F0h,0F8h,0FCh,0FCh,000h
        ; QUEEN four 8x8 quadrants: UL UR LL LR
        defb 004h,00Fh,007h,00Fh,01Fh,00Fh,00Fh,00Fh
        defb 090h,0F8h,0E0h,0F0h,0F8h,0F0h,0F0h,0F0h
        defb 00Fh,01Fh,01Fh,03Fh,03Fh,03Fh,07Fh,000h
        defb 0F0h,0F8h,0F8h,0FCh,0FCh,0FCh,0FEh,000h
        ; KING four 8x8 quadrants: UL UR LL LR
        defb 001h,003h,001h,007h,00Fh,007h,007h,007h
        defb 080h,0C0h,080h,0E0h,0F0h,0E0h,0E0h,0E0h
        defb 00Fh,007h,007h,00Fh,01Fh,03Fh,03Fh,000h
        defb 0F0h,0E0h,0E0h,0F0h,0F8h,0FCh,0FCh,000h
        ; REV13 tile piece set: BLACK LIGHT
        ; PAWN four 8x8 quadrants: UL UR LL LR
        defb 003h,007h,007h,003h,003h,007h,00Fh,00Dh
        defb 0C0h,0E0h,0E0h,0C0h,0C0h,0E0h,0F0h,0B0h
        defb 007h,007h,00Fh,01Fh,01Fh,03Fh,03Fh,000h
        defb 0E0h,0E0h,0F0h,0F8h,0F8h,0FCh,0FCh,000h
        ; ROOK four 8x8 quadrants: UL UR LL LR
        defb 01Dh,01Fh,01Fh,00Fh,00Fh,00Fh,00Fh,00Fh
        defb 0B8h,0F8h,0F8h,0F0h,0F0h,0F0h,0F0h,0F0h
        defb 00Fh,00Fh,01Fh,01Fh,03Fh,03Fh,03Fh,000h
        defb 0F0h,0F0h,0F8h,0F8h,0FCh,0FCh,0FCh,000h
        ; KNIGHT four 8x8 quadrants: UL UR LL LR
        defb 003h,007h,00Fh,00Fh,01Fh,01Fh,01Fh,01Fh
        defb 0E0h,0F0h,0F8h,0F0h,0F0h,0C0h,080h,0C0h
        defb 01Fh,01Fh,01Fh,01Fh,00Fh,03Fh,03Fh,000h
        defb 0F0h,0F8h,0F8h,0F8h,0F0h,0FCh,0FCh,000h
        ; BISHOP four 8x8 quadrants: UL UR LL LR
        defb 003h,007h,006h,003h,007h,007h,007h,00Fh
        defb 0C0h,0E0h,0E0h,0C0h,0E0h,0E0h,0E0h,0F0h
        defb 007h,007h,00Fh,00Fh,01Fh,03Fh,03Fh,000h
        defb 0E0h,0E0h,0F0h,0F0h,0F8h,0FCh,0FCh,000h
        ; QUEEN four 8x8 quadrants: UL UR LL LR
        defb 004h,00Fh,007h,00Fh,01Fh,00Fh,00Fh,00Fh
        defb 090h,0F8h,0E0h,0F0h,0F8h,0F0h,0F0h,0F0h
        defb 00Fh,01Fh,01Fh,03Fh,03Fh,03Fh,07Fh,000h
        defb 0F0h,0F8h,0F8h,0FCh,0FCh,0FCh,0FEh,000h
        ; KING four 8x8 quadrants: UL UR LL LR
        defb 001h,003h,001h,007h,00Fh,007h,007h,007h
        defb 080h,0C0h,080h,0E0h,0F0h,0E0h,0E0h,0E0h
        defb 00Fh,007h,007h,00Fh,01Fh,03Fh,03Fh,000h
        defb 0F0h,0E0h,0E0h,0F0h,0F8h,0FCh,0FCh,000h
        ; REV13 tile piece set: BLACK DARK
        ; PAWN four 8x8 quadrants: UL UR LL LR
        defb 003h,007h,007h,003h,003h,007h,00Fh,00Dh
        defb 0C0h,0E0h,0E0h,0C0h,0C0h,0E0h,0F0h,0B0h
        defb 007h,007h,00Fh,01Fh,01Fh,03Fh,03Fh,000h
        defb 0E0h,0E0h,0F0h,0F8h,0F8h,0FCh,0FCh,000h
        ; ROOK four 8x8 quadrants: UL UR LL LR
        defb 01Dh,01Fh,01Fh,00Fh,00Fh,00Fh,00Fh,00Fh
        defb 0B8h,0F8h,0F8h,0F0h,0F0h,0F0h,0F0h,0F0h
        defb 00Fh,00Fh,01Fh,01Fh,03Fh,03Fh,03Fh,000h
        defb 0F0h,0F0h,0F8h,0F8h,0FCh,0FCh,0FCh,000h
        ; KNIGHT four 8x8 quadrants: UL UR LL LR
        defb 003h,007h,00Fh,00Fh,01Fh,01Fh,01Fh,01Fh
        defb 0E0h,0F0h,0F8h,0F0h,0F0h,0C0h,080h,0C0h
        defb 01Fh,01Fh,01Fh,01Fh,00Fh,03Fh,03Fh,000h
        defb 0F0h,0F8h,0F8h,0F8h,0F0h,0FCh,0FCh,000h
        ; BISHOP four 8x8 quadrants: UL UR LL LR
        defb 003h,007h,006h,003h,007h,007h,007h,00Fh
        defb 0C0h,0E0h,0E0h,0C0h,0E0h,0E0h,0E0h,0F0h
        defb 007h,007h,00Fh,00Fh,01Fh,03Fh,03Fh,000h
        defb 0E0h,0E0h,0F0h,0F0h,0F8h,0FCh,0FCh,000h
        ; QUEEN four 8x8 quadrants: UL UR LL LR
        defb 004h,00Fh,007h,00Fh,01Fh,00Fh,00Fh,00Fh
        defb 090h,0F8h,0E0h,0F0h,0F8h,0F0h,0F0h,0F0h
        defb 00Fh,01Fh,01Fh,03Fh,03Fh,03Fh,07Fh,000h
        defb 0F0h,0F8h,0F8h,0FCh,0FCh,0FCh,0FEh,000h
        ; KING four 8x8 quadrants: UL UR LL LR
        defb 001h,003h,001h,007h,00Fh,007h,007h,007h
        defb 080h,0C0h,080h,0E0h,0F0h,0E0h,0E0h,0E0h
        defb 00Fh,007h,007h,00Fh,01Fh,03Fh,03Fh,000h
        defb 0F0h,0E0h,0E0h,0F0h,0F8h,0FCh,0FCh,000h

TilePatternsEnd:

; ------------------------------------------------------------
; 16x16 sprite piece glyphs.
; TMS 16x16 sprite pattern order:
;   upper-left 8 bytes, lower-left 8, upper-right 8, lower-right 8.

SpritePatterns:
        ; REV13 16x16 sprite piece glyphs, matching the board tiles.
        ; TMS 16x16 sprite pattern order:
        ;   upper-left 8 bytes, lower-left 8, upper-right 8, lower-right 8.

        ; Pattern 0 PAWN - classic pawn
        defb 003h,007h,007h,003h,003h,007h,00Fh,00Dh
        defb 007h,007h,00Fh,01Fh,01Fh,03Fh,03Fh,000h
        defb 0C0h,0E0h,0E0h,0C0h,0C0h,0E0h,0F0h,0B0h
        defb 0E0h,0E0h,0F0h,0F8h,0F8h,0FCh,0FCh,000h

        ; Pattern 4 ROOK - castle rook
        defb 01Dh,01Fh,01Fh,00Fh,00Fh,00Fh,00Fh,00Fh
        defb 00Fh,00Fh,01Fh,01Fh,03Fh,03Fh,03Fh,000h
        defb 0B8h,0F8h,0F8h,0F0h,0F0h,0F0h,0F0h,0F0h
        defb 0F0h,0F0h,0F8h,0F8h,0FCh,0FCh,0FCh,000h

        ; Pattern 8 KNIGHT - horse knight
        defb 003h,007h,00Fh,00Fh,01Fh,01Fh,01Fh,01Fh
        defb 01Fh,01Fh,01Fh,01Fh,00Fh,03Fh,03Fh,000h
        defb 0E0h,0F0h,0F8h,0F0h,0F0h,0C0h,080h,0C0h
        defb 0F0h,0F8h,0F8h,0F8h,0F0h,0FCh,0FCh,000h

        ; Pattern 12 BISHOP - mitre bishop
        defb 003h,007h,006h,003h,007h,007h,007h,00Fh
        defb 007h,007h,00Fh,00Fh,01Fh,03Fh,03Fh,000h
        defb 0C0h,0E0h,0E0h,0C0h,0E0h,0E0h,0E0h,0F0h
        defb 0E0h,0E0h,0F0h,0F0h,0F8h,0FCh,0FCh,000h

        ; Pattern 16 QUEEN - crowned queen
        defb 004h,00Fh,007h,00Fh,01Fh,00Fh,00Fh,00Fh
        defb 00Fh,01Fh,01Fh,03Fh,03Fh,03Fh,07Fh,000h
        defb 090h,0F8h,0E0h,0F0h,0F8h,0F0h,0F0h,0F0h
        defb 0F0h,0F8h,0F8h,0FCh,0FCh,0FCh,0FEh,000h

        ; Pattern 20 KING - cross king
        defb 001h,003h,001h,007h,00Fh,007h,007h,007h
        defb 00Fh,007h,007h,00Fh,01Fh,03Fh,03Fh,000h
        defb 080h,0C0h,080h,0E0h,0F0h,0E0h,0E0h,0E0h
        defb 0F0h,0E0h,0E0h,0F0h,0F8h,0FCh,0FCh,000h

SpritePatternsEnd:

; ------------------------------------------------------------
; Private program stack.

StackSpace:
        defs    256,0
Stack:

        include "tms.asm"
        include "z180.asm"
        include "utility.asm"
        include "RWBANK.ASM"        ; REV26: RomWBW/HBIOS app-bank brain library

ProgramEnd:

        end