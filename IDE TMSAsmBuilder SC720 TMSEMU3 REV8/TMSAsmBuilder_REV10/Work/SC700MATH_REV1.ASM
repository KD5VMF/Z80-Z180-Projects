; SC700MATH_REV1.ASM
; SC700 / Z8S180-N + RomWBW HBIOS + TMSEMU3/TMS9918A + 3x SC719 math lab
;
; Target from your boot log:
;   Small Computer SC700 [SCZ180_sc700_std] Z8S180-N @ 18.432MHz
;   RomWBW HBIOS v3.5.1
;   SC727 RTC / DSRTC detected at IO=0x0C
;   SC719 Digital I/O cards at 00h, 01h, and 02h
;
; What it does:
;   - Uses the TMS9918A/TMSEMU3 as a live math dashboard.
;   - Reads the RTC through RomWBW HBIOS.
;   - Reads SC719 ports 00h, 01h, and 02h as live 8-bit math inputs.
;   - Shows hex, binary, 16-bit sums, 8x8 multiply, XOR, Fibonacci, LFSR, and a mixed hash.
;   - Writes calculation results back to the three SC719 LED/output ports.
;   - Press any CP/M console key to exit.
;
; SAFETY:
;   SC719 output LEDs share real output pins. If external hardware is wired to
;   the output headers, inspect it first. To make this read-only, set:
;       SC719_WRITE_LEDS: equ 0
;
; Build with the TMSAsmBuilder REV8 / sjasmplus path, not CP/M ASM.COM.
;
; Needed REV8 Libs:
;   include "tms.asm"
;   include "z180.asm"
;   include "utility.asm"

        org     100h

SC719_WRITE_LEDS:   equ 1

SC719_PORT0:        equ 00h
SC719_PORT1:        equ 01h
SC719_PORT2:        equ 02h

HBIOS_INVOKE:       equ 0FFF0h
HBIOS_RTC_GETTIME:  equ 020h       ; HL -> 6 BCD bytes: YY MM DD HH MM SS

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

        call    TmsTile
        ld      a,TmsBlack
        call    TmsBackground

        call    LoadAsciiPatterns
        call    SetTileColors
        call    DrawStaticScreen

        call    ReadRTC
        call    ReadSC719
        call    AdvanceMath
        call    DrawDynamic

MainLoop:
        call    WaitFrame

        ld      a,(FrameTick)
        inc     a
        ld      (FrameTick),a

        call    ReadSC719

        ; RTC read about twice per second.
        ld      a,(FrameTick)
        and     1Fh
        call    z,ReadRTC

        ; Math engine runs every four frames so the screen is readable.
        ld      a,(FrameTick)
        and     03h
        call    z,AdvanceMath

        call    DrawDynamic
        call    DrawSpinner

        call    keypress
        jp      z,MainLoop

Exit:
        call    LEDsOff
        ld      sp,(OldSP)
        rst     0

NoTms:
        ld      de,NoTmsMsg
        call    strout
        ld      sp,(OldSP)
        rst     0

; ------------------------------------------------------------
; Frame sync.

WaitFrame:
WaitNotV:
        call    TmsRegIn
        jp      m,WaitNotV
WaitV:
        call    TmsRegIn
        jp      p,WaitV
        ret

; ------------------------------------------------------------
; TMS setup.

LoadAsciiPatterns:
        ld      hl,AsciiPatterns
        ld      de,(TmsPatternAddr)
        ld      bc,AsciiPatternsEnd-AsciiPatterns
        jp      TmsWrite

SetTileColors:
        ld      hl,TileColorTable
        ld      de,(TmsColorAddr)
        ld      bc,TmsTileColorLen
        jp      TmsWrite

; DE = name table offset.  Selects the TMS write address.
SetNameOffset:
        ld      hl,(TmsNameAddr)
        add     hl,de
        ex      de,hl
        jp      TmsWriteAddr

; HL = zero terminated string. DE = screen offset.
DrawStringAt:
        push    hl
        call    SetNameOffset
        pop     hl
DrawStringLoop:
        ld      a,(hl)
        or      a
        ret     z
        call    TmsRamOut
        inc     hl
        jp      DrawStringLoop

DrawStaticScreen:
        ; Clear the screen with ASCII space.
        ld      de,(TmsNameAddr)
        ld      bc,TmsTileNameLen
        ld      a,' '
        call    TmsFill

        ld      hl,TitleText
        ld      de,32*1+4
        call    DrawStringAt

        ld      hl,SubText
        ld      de,32*2+3
        call    DrawStringAt

        ld      hl,TimeLine
        ld      de,32*4+2
        call    DrawStringAt
        ld      hl,DateLine
        ld      de,32*5+2
        call    DrawStringAt

        ld      hl,IO0Line
        ld      de,32*7+2
        call    DrawStringAt
        ld      hl,IO1Line
        ld      de,32*8+2
        call    DrawStringAt
        ld      hl,IO2Line
        ld      de,32*9+2
        call    DrawStringAt

        ld      hl,SumLine
        ld      de,32*11+2
        call    DrawStringAt
        ld      hl,MulLine
        ld      de,32*12+2
        call    DrawStringAt
        ld      hl,XorLine
        ld      de,32*13+2
        call    DrawStringAt
        ld      hl,FibLine
        ld      de,32*14+2
        call    DrawStringAt
        ld      hl,RandLine
        ld      de,32*15+2
        call    DrawStringAt
        ld      hl,MixLine
        ld      de,32*16+2
        call    DrawStringAt

        ld      hl,LedLine
        ld      de,32*18+2
        call    DrawStringAt
        ld      hl,FrameLine
        ld      de,32*19+2
        call    DrawStringAt

        ld      hl,Footer
        ld      de,32*22+5
        call    DrawStringAt
        ret

; ------------------------------------------------------------
; RomWBW RTC.
; Buffer order returned by HBIOS call: YY MM DD HH MM SS, all BCD.

ReadRTC:
        ld      hl,RTCBuf
        ld      b,HBIOS_RTC_GETTIME
        call    HBIOS_INVOKE
        or      a
        jp      z,RTCGood
RTCBad:
        ld      a,'N'
        ld      (RTCStatus),a
        ret
RTCGood:
        ld      a,'Y'
        ld      (RTCStatus),a
        ret

; ------------------------------------------------------------
; SC719 digital I/O.
; Each card occupies one I/O port. IN reads the switch/input byte.
; OUT writes the output latch and LED byte.

ReadSC719:
        ld      bc,0000h + SC719_PORT0
        in      a,(c)
        ld      (In0),a
        ld      bc,0000h + SC719_PORT1
        in      a,(c)
        ld      (In1),a
        ld      bc,0000h + SC719_PORT2
        in      a,(c)
        ld      (In2),a
        ret

WriteSC719LEDs:
        ; Always update software copies so the display is meaningful even
        ; when SC719_WRITE_LEDS is changed to 0.
        ld      a,(FibB)                ; low byte of Fibonacci
        ld      (Out0),a
        ld      a,(Mix16)               ; low byte of mixed hash
        ld      (Out1),a
        ld      a,(RandomSeed)
        ld      b,a
        ld      a,(Sum16)               ; low byte of sum
        xor     b
        ld      (Out2),a

        IF SC719_WRITE_LEDS
        ld      a,(Out0)
        ld      bc,0000h + SC719_PORT0
        out     (c),a
        ld      a,(Out1)
        ld      bc,0000h + SC719_PORT1
        out     (c),a
        ld      a,(Out2)
        ld      bc,0000h + SC719_PORT2
        out     (c),a
        ENDIF
        ret

LEDsOff:
        IF SC719_WRITE_LEDS
        xor     a
        ld      bc,0000h + SC719_PORT0
        out     (c),a
        ld      bc,0000h + SC719_PORT1
        out     (c),a
        ld      bc,0000h + SC719_PORT2
        out     (c),a
        ENDIF
        ret

; ------------------------------------------------------------
; Math engine.

AdvanceMath:
        call    Rand8

        ; SECVAL = binary version of RTC seconds BCD.
        ld      a,(RTCBuf+5)
        call    BCDToByte
        ld      (SecVal),a

        call    CalcSum16
        call    CalcMul16
        call    CalcXor8
        call    CalcFib16
        call    CalcMix16
        call    WriteSC719LEDs
        ret

CalcSum16:
        ld      hl,0
        ld      a,(In0)
        call    AddByteToHL
        ld      a,(In1)
        call    AddByteToHL
        ld      a,(In2)
        call    AddByteToHL
        ld      a,(SecVal)
        call    AddByteToHL
        ld      (Sum16),hl
        ret

CalcMul16:
        ; MUL16 = IN00 * IN01, 8x8 -> 16-bit.
        ld      a,(In0)
        ld      e,a
        ld      d,0
        ld      a,(In1)
        or      a
        jp      z,MulZero
        ld      b,a
        ld      hl,0
MulLoop:
        add     hl,de
        djnz    MulLoop
        ld      (Mul16),hl
        ret
MulZero:
        ld      hl,0
        ld      (Mul16),hl
        ret

CalcXor8:
        ld      a,(In0)
        ld      b,a
        ld      a,(In1)
        xor     b
        ld      b,a
        ld      a,(In2)
        xor     b
        ld      (Xor8),a
        ret

CalcFib16:
        ; FibB becomes the new Fibonacci value. It rolls over naturally at 16 bits.
        ld      hl,(FibA)
        ld      de,(FibB)
        add     hl,de
        ld      (FibNext),hl
        ld      hl,(FibB)
        ld      (FibA),hl
        ld      hl,(FibNext)
        ld      (FibB),hl
        ret

CalcMix16:
        ; MIX = SUM + MUL + FIB + XOR + RNG.
        ld      hl,(Sum16)
        ld      de,(Mul16)
        add     hl,de
        ld      de,(FibB)
        add     hl,de
        ld      a,(Xor8)
        call    AddByteToHL
        ld      a,(RandomSeed)
        call    AddByteToHL
        ld      (Mix16),hl
        ret

; Add unsigned byte A to HL.
AddByteToHL:
        ld      e,a
        ld      d,0
        add     hl,de
        ret

; A = packed BCD 00-99. Returns binary A 0-99.
BCDToByte:
        ld      c,a
        and     0Fh
        ld      b,a                     ; B = low digit
        ld      a,c
        rrca
        rrca
        rrca
        rrca
        and     0Fh                     ; A = high digit
        ld      c,a
        add     a,a                     ; high * 2
        ld      d,a
        ld      a,c
        add     a,a
        add     a,a
        add     a,a                     ; high * 8
        add     a,d                     ; high * 10
        add     a,b
        ret

; 8-bit Galois-style pseudo-random step.
Rand8:
        ld      a,(RandomSeed)
        rrca
        jp      nc,RandStore
        xor     0B8h
RandStore:
        ld      (RandomSeed),a
        ret

; ------------------------------------------------------------
; Drawing dynamic data.

DrawDynamic:
        call    DrawRTC
        call    DrawIOState
        call    DrawMathState
        call    DrawLEDState
        ret

DrawRTC:
        ; TIME  HH:MM:SS  RTC=Y
        ld      de,32*4+8
        call    SetNameOffset
        ld      a,(RTCBuf+3)
        call    WriteBCD2
        ld      a,':'
        call    TmsRamOut
        ld      a,(RTCBuf+4)
        call    WriteBCD2
        ld      a,':'
        call    TmsRamOut
        ld      a,(RTCBuf+5)
        call    WriteBCD2
        ld      de,32*4+22
        call    SetNameOffset
        ld      a,(RTCStatus)
        call    TmsRamOut

        ; DATE  20YY-MM-DD
        ld      de,32*5+8
        call    SetNameOffset
        ld      a,'2'
        call    TmsRamOut
        ld      a,'0'
        call    TmsRamOut
        ld      a,(RTCBuf+0)
        call    WriteBCD2
        ld      a,'-'
        call    TmsRamOut
        ld      a,(RTCBuf+1)
        call    WriteBCD2
        ld      a,'-'
        call    TmsRamOut
        ld      a,(RTCBuf+2)
        call    WriteBCD2
        ret

DrawIOState:
        ld      de,32*7+9
        call    SetNameOffset
        ld      a,(In0)
        call    WriteHex2
        ld      de,32*7+14
        call    SetNameOffset
        ld      a,(In0)
        call    WriteBin8

        ld      de,32*8+9
        call    SetNameOffset
        ld      a,(In1)
        call    WriteHex2
        ld      de,32*8+14
        call    SetNameOffset
        ld      a,(In1)
        call    WriteBin8

        ld      de,32*9+9
        call    SetNameOffset
        ld      a,(In2)
        call    WriteHex2
        ld      de,32*9+14
        call    SetNameOffset
        ld      a,(In2)
        call    WriteBin8
        ret

DrawMathState:
        ld      de,32*11+10
        call    SetNameOffset
        ld      hl,(Sum16)
        call    WriteHex4

        ld      de,32*12+11
        call    SetNameOffset
        ld      hl,(Mul16)
        call    WriteHex4

        ld      de,32*13+11
        call    SetNameOffset
        ld      a,(Xor8)
        call    WriteHex2

        ld      de,32*14+10
        call    SetNameOffset
        ld      hl,(FibB)
        call    WriteHex4

        ld      de,32*15+10
        call    SetNameOffset
        ld      a,(RandomSeed)
        call    WriteHex2

        ld      de,32*16+10
        call    SetNameOffset
        ld      hl,(Mix16)
        call    WriteHex4

        ld      de,32*19+8
        call    SetNameOffset
        ld      a,(FrameTick)
        call    WriteHex2
        ld      de,32*19+19
        call    SetNameOffset
        ld      a,(SecVal)
        call    WriteHex2
        ret

DrawLEDState:
        ld      de,32*18+7
        call    SetNameOffset
        ld      a,(Out0)
        call    WriteHex2
        ld      de,32*18+16
        call    SetNameOffset
        ld      a,(Out1)
        call    WriteHex2
        ld      de,32*18+25
        call    SetNameOffset
        ld      a,(Out2)
        call    WriteHex2
        ret

DrawSpinner:
        ld      a,(SpinIdx)
        inc     a
        and     03h
        ld      (SpinIdx),a
        ld      e,a
        ld      d,0
        ld      hl,SpinChars
        add     hl,de
        ld      a,(hl)
        ld      de,32*22+26
        call    SetNameOffset
        jp      TmsRamOut

; A = byte. Writes binary bits MSB first.
WriteBin8:
        ld      c,a
        ld      b,8
WriteBinLoop:
        bit     7,c
        ld      a,'0'
        jp      z,WriteBinDigit
        ld      a,'1'
WriteBinDigit:
        call    TmsRamOut
        sla     c
        djnz    WriteBinLoop
        ret

; A = packed BCD. Writes two ASCII digits to current TMS address.
WriteBCD2:
        push    af
        rrca
        rrca
        rrca
        rrca
        and     0Fh
        call    WriteHexNibble
        pop     af
        and     0Fh
        jp      WriteHexNibble

; HL = word. Writes four hex digits to current TMS address.
WriteHex4:
        ld      a,h
        call    WriteHex2
        ld      a,l
        jp      WriteHex2

; A = byte. Writes two hex digits to current TMS address.
WriteHex2:
        push    af
        rrca
        rrca
        rrca
        rrca
        and     0Fh
        call    WriteHexNibble
        pop     af
        and     0Fh
        jp      WriteHexNibble

WriteHexNibble:
        cp      10
        jp      c,HexIsDigit
        add     a,'A'-10
        jp      TmsRamOut
HexIsDigit:
        add     a,'0'
        jp      TmsRamOut

; ------------------------------------------------------------
; Constants/state.

OldSP:          defw 0

FrameTick:      defb 0
SpinIdx:        defb 0
RTCStatus:      defb 'N'
RTCBuf:         defb 0,0,0,0,0,0
SecVal:         defb 0

In0:            defb 0
In1:            defb 0
In2:            defb 0
Out0:           defb 0
Out1:           defb 0
Out2:           defb 0

Sum16:          defw 0
Mul16:          defw 0
FibA:           defw 1
FibB:           defw 1
FibNext:        defw 2
Mix16:          defw 0
Xor8:           defb 0
RandomSeed:     defb 0A7h

SpinChars:
        defb    '|','/','-',05Ch

TitleText:
        defb    "SC700 Z180 MATH LAB",0
SubText:
        defb    "GPU RTC SC719 LIVE CALCS",0
TimeLine:
        defb    "TIME  00:00:00  RTC=Y",0
DateLine:
        defb    "DATE  2000-00-00",0
IO0Line:
        defb    "IO00 H=00 B=00000000",0
IO1Line:
        defb    "IO01 H=00 B=00000000",0
IO2Line:
        defb    "IO02 H=00 B=00000000",0
SumLine:
        defb    "SUM16 = 0000  A+B+C+SEC",0
MulLine:
        defb    "MUL AB = 0000  IO00*IO01",0
XorLine:
        defb    "XORABC = 00",0
FibLine:
        defb    "FIB16 = 0000",0
RandLine:
        defb    "LFSR8 = 00",0
MixLine:
        defb    "MIX16 = 0000",0
LedLine:
        defb    "LED0=00  LED1=00  LED2=00",0
FrameLine:
        defb    "FRAME=00  SECBIN=00",0
Footer:
        defb    "PRESS ANY KEY TO EXIT",0

NoTmsMsg:
        defb    "TMSEMU3 / TMS9918A not found, aborting!$"

; ------------------------------------------------------------
; Tile color table.
; TMS Graphics I uses one color byte per 8 tile patterns.
; High nibble = foreground, low nibble = background.

TileColorTable:
        ; 00-1F mostly unused / blank
        defb    0F1h,0F1h,0F1h,0F1h
        ; 20-3F punctuation and digits
        defb    071h,0F1h,0E1h,0E1h
        ; 40-5F uppercase title/body
        defb    0B1h,0A1h,0F1h,0F1h
        ; 60-7F fallback
        defb    0F1h,0F1h,0F1h,0F1h
        defb    0F1h,0F1h,0F1h,0F1h
        defb    0F1h,0F1h,0F1h,0F1h
        defb    0F1h,0F1h,0F1h,0F1h
        defb    0F1h,0F1h,0F1h,0F1h

; ------------------------------------------------------------
; ASCII tile patterns, tile code = ASCII code.
; Only printable 20h-5Fh are intentionally drawn; unused tiles are blank.

AsciiPatterns:
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 00h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 01h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 02h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 03h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 04h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 05h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 06h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 07h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 08h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 09h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 0Ah
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 0Bh
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 0Ch
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 0Dh
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 0Eh
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 0Fh
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 10h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 11h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 12h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 13h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 14h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 15h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 16h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 17h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 18h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 19h
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 1Ah
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 1Bh
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 1Ch
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 1Dh
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 1Eh
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 1Fh
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 20h ' '
        defb    10h,10h,10h,10h,10h,00h,10h,00h        ; 21h '!'
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 22h '"'
        defb    28h,7Ch,28h,28h,7Ch,28h,00h,00h        ; 23h '#'
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 24h '$'
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 25h '%'
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 26h '&'
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 27h '''
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 28h '('
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 29h ')'
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 2Ah '*'
        defb    00h,10h,10h,7Ch,10h,10h,00h,00h        ; 2Bh '+'
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 2Ch ','
        defb    00h,00h,00h,7Ch,00h,00h,00h,00h        ; 2Dh '-'
        defb    00h,00h,00h,00h,00h,30h,30h,00h        ; 2Eh '.'
        defb    04h,08h,08h,10h,20h,20h,40h,00h        ; 2Fh '/'
        defb    38h,44h,4Ch,54h,64h,44h,38h,00h        ; 30h '0'
        defb    10h,30h,10h,10h,10h,10h,38h,00h        ; 31h '1'
        defb    38h,44h,04h,08h,10h,20h,7Ch,00h        ; 32h '2'
        defb    78h,04h,04h,38h,04h,04h,78h,00h        ; 33h '3'
        defb    08h,18h,28h,48h,7Ch,08h,08h,00h        ; 34h '4'
        defb    7Ch,40h,40h,78h,04h,04h,78h,00h        ; 35h '5'
        defb    18h,20h,40h,78h,44h,44h,38h,00h        ; 36h '6'
        defb    7Ch,04h,08h,10h,20h,20h,20h,00h        ; 37h '7'
        defb    38h,44h,44h,38h,44h,44h,38h,00h        ; 38h '8'
        defb    38h,44h,44h,3Ch,04h,08h,70h,00h        ; 39h '9'
        defb    00h,30h,30h,00h,30h,30h,00h,00h        ; 3Ah ':'
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 3Bh ';'
        defb    04h,08h,10h,20h,10h,08h,04h,00h        ; 3Ch '<'
        defb    00h,00h,7Ch,00h,7Ch,00h,00h,00h        ; 3Dh '='
        defb    40h,20h,10h,08h,10h,20h,40h,00h        ; 3Eh '>'
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 3Fh '?'
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 40h '@'
        defb    38h,44h,44h,7Ch,44h,44h,44h,00h        ; 41h 'A'
        defb    78h,44h,44h,78h,44h,44h,78h,00h        ; 42h 'B'
        defb    3Ch,40h,40h,40h,40h,40h,3Ch,00h        ; 43h 'C'
        defb    78h,44h,44h,44h,44h,44h,78h,00h        ; 44h 'D'
        defb    7Ch,40h,40h,78h,40h,40h,7Ch,00h        ; 45h 'E'
        defb    7Ch,40h,40h,78h,40h,40h,40h,00h        ; 46h 'F'
        defb    3Ch,40h,40h,5Ch,44h,44h,3Ch,00h        ; 47h 'G'
        defb    44h,44h,44h,7Ch,44h,44h,44h,00h        ; 48h 'H'
        defb    38h,10h,10h,10h,10h,10h,38h,00h        ; 49h 'I'
        defb    1Ch,08h,08h,08h,08h,48h,30h,00h        ; 4Ah 'J'
        defb    44h,48h,50h,60h,50h,48h,44h,00h        ; 4Bh 'K'
        defb    40h,40h,40h,40h,40h,40h,7Ch,00h        ; 4Ch 'L'
        defb    44h,6Ch,54h,54h,44h,44h,44h,00h        ; 4Dh 'M'
        defb    44h,64h,54h,4Ch,44h,44h,44h,00h        ; 4Eh 'N'
        defb    38h,44h,44h,44h,44h,44h,38h,00h        ; 4Fh 'O'
        defb    78h,44h,44h,78h,40h,40h,40h,00h        ; 50h 'P'
        defb    38h,44h,44h,44h,54h,48h,34h,00h        ; 51h 'Q'
        defb    78h,44h,44h,78h,50h,48h,44h,00h        ; 52h 'R'
        defb    3Ch,40h,40h,38h,04h,04h,78h,00h        ; 53h 'S'
        defb    7Ch,10h,10h,10h,10h,10h,10h,00h        ; 54h 'T'
        defb    44h,44h,44h,44h,44h,44h,38h,00h        ; 55h 'U'
        defb    44h,44h,44h,44h,44h,28h,10h,00h        ; 56h 'V'
        defb    44h,44h,44h,54h,54h,54h,28h,00h        ; 57h 'W'
        defb    44h,44h,28h,10h,28h,44h,44h,00h        ; 58h 'X'
        defb    44h,44h,28h,10h,10h,10h,10h,00h        ; 59h 'Y'
        defb    7Ch,04h,08h,10h,20h,40h,7Ch,00h        ; 5Ah 'Z'
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 5Bh '['
        defb    40h,20h,20h,10h,08h,08h,04h,00h        ; 5Ch '\'
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 5Dh ']'
        defb    00h,00h,00h,00h,00h,00h,00h,00h        ; 5Eh '^'
        defb    00h,00h,00h,00h,00h,00h,7Ch,00h        ; 5Fh '_'
AsciiPatternsEnd:

; ------------------------------------------------------------
; Private program stack.

StackSpace:
        defs    256,0
Stack:

        include "tms.asm"
        include "z180.asm"
        include "utility.asm"

        end
