; BALLS.ASM
; SC720 / Z80-Z180 + TMSEMU3 TMS9918A color sprite demo
;
; Paste/load this in ASM IDE.
;
; Needed LIB files in the same build folder or ASMIDE\Libs:
;   tms.asm
;   z180.asm
;   utility.asm
;
; No tmsfont.asm is needed. This uses sprite/tile mode only.
;
; Result: black screen with four colored 16x16 bouncing shapes.
; Press any CP/M console key to exit.
;
; NOTE: The TMS library files are Z80/sjasm-style source. This is not
;       for CP/M ASM.COM. Build it with the IDE/sjasmplus path.

        org     100h

Start:
        ld      (OldSP),sp
        ld      sp,Stack

        ; Set TMS wait timing correctly on a fast Z180.
        call    z180detect
        ld      e,0
        jp      nz,NoZ180
        call    z180getclk
NoZ180:
        call    TmsSetWait

        ; Find the TMS9918A / TMSEMU3 VDP.
        call    TmsProbe
        jp      z,NoTms

        ; Graphics I tile mode, blank black screen, sprites on top.
        call    TmsTile
        ld      a,TmsBlack
        call    TmsBackground
        call    ClearTileColors

        ; 16x16 sprites, not magnified.
        ld      a,TmsSprite32
        call    TmsSpriteConfig

        call    LoadSpritePatterns
        call    WriteSprites

MainLoop:
        call    WaitFrame
        call    MoveAll
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
; Wait for a vertical blank edge. This keeps motion steady.
WaitFrame:
WaitNotV:
        call    TmsRegIn
        jp      m,WaitNotV
WaitV:
        call    TmsRegIn
        jp      p,WaitV
        ret

; ------------------------------------------------------------
; Color table black foreground / black background.
ClearTileColors:
        ld      de,(TmsColorAddr)
        ld      bc,TmsTileColorLen
        ld      a,11h                   ; black on black
        jp      TmsFill

; ------------------------------------------------------------
; Copy all 16x16 sprite pattern bytes into VRAM.
LoadSpritePatterns:
        ld      hl,SpritePatterns
        ld      de,(TmsSpritePatternAddr)
        ld      bc,SpritePatternsEnd-SpritePatterns
        jp      TmsWrite

; ------------------------------------------------------------
; Sprite attribute table format is Y, X, pattern, color.
WriteSprites:
        ld      de,(TmsSpriteAttrAddr)
        call    TmsWriteAddr

        ld      hl,Objects
        ld      b,ObjCount
WriteLoop:
        push    bc
        push    hl

        inc     hl                      ; object Y
        ld      a,(hl)
        call    TmsRamOut

        pop     hl                      ; object X
        ld      a,(hl)
        call    TmsRamOut

        push    hl
        ld      de,4                    ; object pattern number
        add     hl,de
        ld      a,(hl)
        call    TmsRamOut
        inc     hl                      ; object color
        ld      a,(hl)
        call    TmsRamOut
        pop     hl

        ld      de,ObjSize
        add     hl,de
        pop     bc
        djnz    WriteLoop

        ; 208 marks end-of-sprite list on TMS9918A.
        ld      a,208
        jp      TmsRamOut

HideSprites:
        ld      de,(TmsSpriteAttrAddr)
        call    TmsWriteAddr
        ld      a,208
        jp      TmsRamOut

; ------------------------------------------------------------
; Move every object in the object table.
MoveAll:
        ld      hl,Objects
        ld      b,ObjCount
MoveLoop:
        push    bc
        push    hl
        call    MoveOne
        pop     hl
        ld      de,ObjSize
        add     hl,de
        pop     bc
        djnz    MoveLoop
        ret

; ------------------------------------------------------------
; Move one object.
; Object bytes: X,Y,DX,DY,PATTERN,COLOR
; DX/DY are signed bytes: 1,2 forward and 255,254 = -1,-2.
;
; Entry: HL points to object X.
; Uses:  AF,BC,DE,HL.
MoveOne:
        ; ----- X -----
        ld      a,(hl)                  ; A = X
        inc     hl
        inc     hl                      ; HL = DX
        ld      c,(hl)                  ; C = DX
        add     a,c                     ; A = X + DX
        ld      b,a                     ; B = new X candidate
        cp      XMax+1
        jp      c,StoreX

        ; Out of range. Decide if it went under or over by DX sign.
        ld      a,c
        cp      80h
        jp      nc,XUnder
XOver:
        ld      b,XMax
        jp      FlipDX
XUnder:
        ld      b,0
FlipDX:
        xor     a
        sub     c                       ; A = -DX
        ld      (hl),a                  ; store flipped DX
StoreX:
        dec     hl
        dec     hl                      ; HL = X
        ld      (hl),b

        ; ----- Y -----
        inc     hl                      ; HL = Y
        ld      a,(hl)                  ; A = Y
        inc     hl
        inc     hl                      ; HL = DY
        ld      c,(hl)                  ; C = DY
        add     a,c                     ; A = Y + DY
        ld      b,a
        cp      YMax+1
        jp      c,StoreY

        ld      a,c
        cp      80h
        jp      nc,YUnder
YOver:
        ld      b,YMax
        jp      FlipDY
YUnder:
        ld      b,0
FlipDY:
        xor     a
        sub     c                       ; A = -DY
        ld      (hl),a                  ; store flipped DY
StoreY:
        dec     hl
        dec     hl                      ; HL = Y
        ld      (hl),b
        ret

; ------------------------------------------------------------
; Constants and object table.
XMax:   equ     240                     ; 256 - 16
YMax:   equ     176                     ; 192 - 16
ObjSize:equ     6
ObjCount:equ    4

Objects:
        ;  X    Y    DX   DY   PAT  COLOR
        defb    18,  20,   2,   1,   0, TmsCyan
        defb    80,  42,   1,   2,   4, TmsLightRed
        defb   150,  88, 255,   1,   8, TmsLightYellow
        defb   218, 138, 254, 255,  12, TmsMagenta

NoTmsMsg:
        defb    "TMS9918A not found, aborting!$"

OldSP:  defw    0

; ------------------------------------------------------------
; 16x16 sprite patterns.
; Each 16x16 sprite uses four 8-byte patterns in this order:
; upper-left, lower-left, upper-right, lower-right.
;
; Pattern numbers for 16x16 sprites must start on 0,4,8,12...
SpritePatterns:

; Pattern 0: round ball
        defb    03h,0fh,1fh,3fh,7fh,7fh,0ffh,0ffh
        defb    0ffh,0ffh,7fh,7fh,3fh,1fh,0fh,03h
        defb    0c0h,0f0h,0f8h,0fch,0feh,0feh,0ffh,0ffh
        defb    0ffh,0ffh,0feh,0feh,0fch,0f8h,0f0h,0c0h

; Pattern 4: square box
        defb    0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
        defb    0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
        defb    0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
        defb    0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh

; Pattern 8: diamond
        defb    01h,03h,07h,0fh,1fh,3fh,7fh,0ffh
        defb    0ffh,7fh,3fh,1fh,0fh,07h,03h,01h
        defb    80h,0c0h,0e0h,0f0h,0f8h,0fch,0feh,0ffh
        defb    0ffh,0feh,0fch,0f8h,0f0h,0e0h,0c0h,80h

; Pattern 12: X shape
        defb    0c0h,0e0h,70h,38h,1ch,0eh,07h,03h
        defb    03h,07h,0eh,1ch,38h,70h,0e0h,0c0h
        defb    03h,07h,0eh,1ch,38h,70h,0e0h,0c0h
        defb    0c0h,0e0h,70h,38h,1ch,0eh,07h,03h

SpritePatternsEnd:

        defs    256,0
Stack:

        include "tms.asm"
        include "z180.asm"
        include "utility.asm"

        end
