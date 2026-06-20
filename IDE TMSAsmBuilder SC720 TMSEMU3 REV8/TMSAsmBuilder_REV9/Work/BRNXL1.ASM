; BRNXL1.ASM
; SC700 / Z8S180-N + RomWBW HBIOS + TMSEMU3/TMS9918A + 3x SC719 "brain" demo
;
; Safe replacement after the too-fancy race dashboard crash.
;
; Hardware target:
;   SC700 Z180 @ 18.432 MHz, RomWBW HBIOS v3.5.1
;   SC727 RTC / DSRTC present through HBIOS
;   SC719 Digital I/O cards at 00h, 01h, 02h
;   TMSEMU3 / TMS9918A video
;
; What it does:
;   - Text/tile-only GPU display. No sprites. No LCD. Very safe TMS path.
;   - Reads the RTC through RomWBW HBIOS and uses seconds/minutes as time input.
;   - Reads all three SC719 input ports as "sensors".
;   - Runs a small simulated Z180 brain: target, guess, error, confidence,
;     neuron firing bits, status state, memory hash, and a simple solver loop.
;   - Writes all three SC719 output LED ports:
;       00h = neuron firing bits
;       01h = confidence LED bar
;       02h = status/thinking bits
;   - Press any CP/M console key to exit.
;
; SAFETY:
;   SC719 outputs are real output pins. This program writes LED/output bytes
;   to ports 00h, 01h, and 02h. If external hardware is wired to the output
;   headers, inspect it first or set SC719_WRITE_LEDS to 0.
;
; Build with TMSAsmBuilder REV8 / sjasmplus, not CP/M ASM.COM.
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

        ; Safe TMS timing on fast Z180 systems.
        call    z180detect
        ld      e,0
        jp      nz,NoZ180
        call    z180getclk
NoZ180:
        call    TmsSetWait

        call    TmsProbe
        jp      z,NoTms

        call    TmsTile
        ld      a,TmsBlack
        call    TmsBackground

        call    LoadAsciiPatterns
        call    SetTileColors
        call    DrawStaticScreen

        call    ReadRTC
        call    SeedBrainFromRTC
        call    ReadSC719
        call    BrainStep
        call    DrawDynamic

MainLoop:
        call    WaitFrame

        ld      a,(FrameTick)
        inc     a
        ld      (FrameTick),a

        ; RTC refresh about twice per second.
        and     1Fh
        call    z,ReadRTC

        call    ReadSC719

        ; Brain runs every 4 frames so the numbers are readable.
        ld      a,(FrameTick)
        and     03h
        call    z,BrainStep

        call    DrawDynamic
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
; TMS setup and text helpers.

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

; DE = name table offset. Selects the TMS write address.
SetNameOffset:
        ld      hl,(TmsNameAddr)
        add     hl,de
        ex      de,hl
        jp      TmsWriteAddr

; HL = zero-terminated string. DE = screen offset.
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

; A = char, B = count, DE = screen offset.
FillCharsAt:
        push    af
        push    bc
        call    SetNameOffset
        pop     bc
        pop     af
FillCharsLoop:
        call    TmsRamOut
        djnz    FillCharsLoop
        ret

DrawStaticScreen:
        ; Clear screen with ASCII space.
        ld      de,(TmsNameAddr)
        ld      bc,TmsTileNameLen
        ld      a,' '
        call    TmsFill

        ld      hl,TitleText
        ld      de,32*1+4
        call    DrawStringAt
        ld      hl,SubText
        ld      de,32*2+2
        call    DrawStringAt

        ld      hl,TimeLine
        ld      de,32*4+2
        call    DrawStringAt
        ld      hl,DateLine
        ld      de,32*5+2
        call    DrawStringAt

        ld      hl,InputLine
        ld      de,32*7+2
        call    DrawStringAt
        ld      hl,SolveLine
        ld      de,32*8+2
        call    DrawStringAt
        ld      hl,ModeLine
        ld      de,32*9+2
        call    DrawStringAt

        ld      hl,NeuronLine
        ld      de,32*11+2
        call    DrawStringAt
        ld      hl,FireBarLine
        ld      de,32*12+2
        call    DrawStringAt
        ld      hl,ConfBarLine
        ld      de,32*13+2
        call    DrawStringAt
        ld      hl,MemLine
        ld      de,32*14+2
        call    DrawStringAt

        ld      hl,Out0Line
        ld      de,32*16+2
        call    DrawStringAt
        ld      hl,Out1Line
        ld      de,32*17+2
        call    DrawStringAt
        ld      hl,Out2Line
        ld      de,32*18+2
        call    DrawStringAt

        ld      hl,StatusLine
        ld      de,32*20+2
        call    DrawStringAt
        ld      hl,Footer
        ld      de,32*22+5
        call    DrawStringAt
        ret

; ------------------------------------------------------------
; RomWBW RTC. Buffer order: YY MM DD HH MM SS, all BCD.

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

SeedBrainFromRTC:
        ; Mix RTC bytes into the LFSR seed. If RTC fails, the default seed stays fine.
        ld      a,(RTCBuf+3)            ; HH BCD
        ld      b,a
        ld      a,(RTCBuf+4)            ; MM BCD
        xor     b
        ld      b,a
        ld      a,(RTCBuf+5)            ; SS BCD
        xor     b
        or      a
        jp      z,SeedDone
        ld      (RandomSeed),a
SeedDone:
        ret

; ------------------------------------------------------------
; SC719 digital I/O.

ReadSC719:
        ld      bc,0000h + SC719_PORT0
        in      a,(c)
        ld      b,a
        ld      a,(In0)
        xor     b
        ld      (Change0),a
        ld      a,b
        ld      (In0),a

        ld      bc,0000h + SC719_PORT1
        in      a,(c)
        ld      b,a
        ld      a,(In1)
        xor     b
        ld      (Change1),a
        ld      a,b
        ld      (In1),a

        ld      bc,0000h + SC719_PORT2
        in      a,(c)
        ld      b,a
        ld      a,(In2)
        xor     b
        ld      (Change2),a
        ld      a,b
        ld      (In2),a
        ret

WriteSC719LEDs:
        ; Port 00h: raw neuron firing pattern.
        ld      a,(NodeBits)
        ld      (Out0),a

        ; Port 01h: confidence LED bar.
        ld      a,(Confidence)
        call    MakeLEDBar8
        ld      (Out1),a

        ; Port 02h: status/thought bits.
        call    BuildStatusBits
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

; A = 0..255, return LED bar in A.
MakeLEDBar8:
        cp      224
        jp      nc,LEDBarFull
        and     0E0h
        rrca
        rrca
        rrca
        rrca
        rrca                            ; A = 0..7
        ld      e,a
        ld      d,0
        ld      hl,LEDBarTable
        add     hl,de
        ld      a,(hl)
        ret
LEDBarFull:
        ld      a,0FFh
        ret

BuildStatusBits:
        xor     a
        ld      b,a

        ; bit 0 = searching/adjusting
        ld      a,(Decision)
        cp      0
        jp      nz,StatusNotSearch
        set     0,b
StatusNotSearch:
        ; bit 1 = tracking/close
        ld      a,(Decision)
        cp      1
        jp      nz,StatusNotTrack
        set     1,b
StatusNotTrack:
        ; bit 2 = locked/exact solve
        ld      a,(Decision)
        cp      2
        jp      nz,StatusNotLock
        set     2,b
StatusNotLock:
        ; bit 3 = input changed
        ld      a,(Change0)
        ld      c,a
        ld      a,(Change1)
        or      c
        ld      c,a
        ld      a,(Change2)
        or      c
        jp      z,StatusNoChange
        set     3,b
StatusNoChange:
        ; bit 4 = RTC good
        ld      a,(RTCStatus)
        cp      'Y'
        jp      nz,StatusRtcBad
        set     4,b
StatusRtcBad:
        ; bit 5 = solver moved this step
        ld      a,(MovedFlag)
        or      a
        jp      z,StatusNoMove
        set     5,b
StatusNoMove:
        ; bit 6 = heartbeat slow
        ld      a,(FrameTick)
        and     20h
        jp      z,StatusNoHB
        set     6,b
StatusNoHB:
        ; bit 7 = high confidence
        ld      a,(Confidence)
        cp      0E0h
        jp      c,StatusDone
        set     7,b
StatusDone:
        ld      a,b
        ret

; ------------------------------------------------------------
; The simulated "brain".
;
; It is a little closed-loop solver:
;   RTC + SC719 inputs create a changing TARGET.
;   The Z180 BRAIN moves GUESS toward TARGET.
;   ERROR, CONFIDENCE, NODEBITS, MEMORY, and STATUS are displayed.
;   The three SC719 LED ports show what the brain is doing.

BrainStep:
        call    Rand8

        ld      hl,(BrainTick)
        inc     hl
        ld      (BrainTick),hl

        ld      a,(RTCBuf+5)
        call    BCDToByte
        ld      (SecVal),a
        ld      a,(RTCBuf+4)
        call    BCDToByte
        ld      (MinVal),a
        ld      a,(RTCBuf+3)
        call    BCDToByte
        ld      (HourVal),a

        call    CalcTarget
        call    SolveTowardTarget
        call    CalcConfidence
        call    CalcNeuronBits
        call    UpdateMemory
        call    WriteSC719LEDs
        ret

CalcTarget:
        ; TARGET = a stable one-second challenge from RTC + inputs.
        ld      a,(In0)
        ld      b,a
        ld      a,(In1)
        add     a,b
        ld      b,a
        ld      a,(In2)
        xor     b
        ld      b,a
        ld      a,(SecVal)
        add     a,b
        ld      b,a
        ld      a,(MinVal)
        xor     b
        ld      (Target),a
        ret

SolveTowardTarget:
        xor     a
        ld      (MovedFlag),a

        ld      a,(BrainTick)
        and     03h
        inc     a                       ; Step = 1..4
        ld      (StepSize),a

        ld      a,(Target)
        ld      b,a
        ld      a,(Guess)
        cp      b
        jp      z,SolveExact
        jp      c,SolveNeedUp

SolveNeedDown:
        ; If distance <= step, snap to target. Else subtract step.
        ld      a,(Guess)
        sub     b                       ; A = Guess - Target
        ld      c,a
        ld      a,(StepSize)
        cp      c
        jp      nc,SolveSnap
        ld      a,(Guess)
        ld      c,a
        ld      a,(StepSize)
        ld      b,a
        ld      a,c
        sub     b
        ld      (Guess),a
        ld      a,1
        ld      (MovedFlag),a
        jp      SolveMoved

SolveNeedUp:
        ; If distance <= step, snap to target. Else add step.
        ld      a,b                     ; Target
        ld      c,a
        ld      a,(Guess)
        ld      b,a
        ld      a,c
        sub     b                       ; A = Target - Guess
        ld      c,a
        ld      a,(StepSize)
        cp      c
        jp      nc,SolveSnap
        ld      a,(Guess)
        ld      c,a
        ld      a,(StepSize)
        add     a,c
        ld      (Guess),a
        ld      a,1
        ld      (MovedFlag),a
        jp      SolveMoved

SolveSnap:
        ld      a,(Target)
        ld      (Guess),a
        ld      a,1
        ld      (MovedFlag),a
        jp      SolveExact

SolveMoved:
        ld      a,0                     ; search/adjust
        ld      (Decision),a
        ret

SolveExact:
        ld      a,2                     ; lock/solved
        ld      (Decision),a
        ret

CalcConfidence:
        ; ERROR = abs(Target - Guess). CONF = FF - ERROR.
        ld      a,(Target)
        ld      b,a
        ld      a,(Guess)
        cp      b
        jp      c,ConfGuessLow

ConfGuessHigh:
        sub     b
        jp      StoreError
ConfGuessLow:
        ld      c,a                     ; Guess
        ld      a,b                     ; Target
        sub     c
StoreError:
        ld      (ErrorVal),a
        ld      c,a
        ld      a,0FFh
        sub     c
        ld      (Confidence),a

        ; If not exact but close, show TRACK mode.
        ld      a,(ErrorVal)
        or      a
        ret     z
        cp      08h
        ret     nc
        ld      a,1
        ld      (Decision),a
        ret

CalcNeuronBits:
        ; NODEBITS = visible firing bits from sensors, solver, time, and RNG.
        ld      a,(In0)
        ld      b,a
        ld      a,(In1)
        rlca
        xor     b
        ld      b,a
        ld      a,(In2)
        rrca
        xor     b
        ld      b,a
        ld      a,(SecVal)
        xor     b
        ld      b,a
        ld      a,(Guess)
        add     a,b
        ld      b,a
        ld      a,(RandomSeed)
        xor     b
        ld      (NodeBits),a

        ; ENERGY is a noisy-looking but deterministic byte.
        ld      b,a
        ld      a,(Confidence)
        add     a,b
        ld      b,a
        ld      a,(FrameTick)
        xor     b
        ld      (Energy),a
        ret

UpdateMemory:
        ; MEMORY = MEMORY + TARGET + GUESS + NODEBITS + current seconds.
        ld      hl,(Memory16)
        ld      a,(Target)
        call    AddByteToHL
        ld      a,(Guess)
        call    AddByteToHL
        ld      a,(NodeBits)
        call    AddByteToHL
        ld      a,(SecVal)
        call    AddByteToHL
        ld      (Memory16),hl
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
        ld      b,a
        ld      a,c
        rrca
        rrca
        rrca
        rrca
        and     0Fh
        ld      c,a
        add     a,a
        ld      d,a
        ld      a,c
        add     a,a
        add     a,a
        add     a,a
        add     a,d
        add     a,b
        ret

Rand8:
        ld      a,(RandomSeed)
        rrca
        jp      nc,RandStore
        xor     0B8h
RandStore:
        ld      (RandomSeed),a
        ret

; ------------------------------------------------------------
; Drawing dynamic brain data.

DrawDynamic:
        call    DrawRTC
        call    DrawInputs
        call    DrawSolver
        call    DrawBrainState
        call    DrawOutputs
        call    DrawStatus
        call    DrawSpinner
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

DrawInputs:
        ld      de,32*7+7
        call    SetNameOffset
        ld      a,(In0)
        call    WriteHex2
        ld      de,32*7+16
        call    SetNameOffset
        ld      a,(In1)
        call    WriteHex2
        ld      de,32*7+25
        call    SetNameOffset
        ld      a,(In2)
        call    WriteHex2
        ret

DrawSolver:
        ld      de,32*8+9
        call    SetNameOffset
        ld      a,(Target)
        call    WriteHex2
        ld      de,32*8+18
        call    SetNameOffset
        ld      a,(Guess)
        call    WriteHex2
        ld      de,32*8+25
        call    SetNameOffset
        ld      a,(ErrorVal)
        call    WriteHex2

        ld      de,32*9+7
        call    SetNameOffset
        ld      a,(Confidence)
        call    WriteHex2
        call    DrawModeName
        ret

DrawModeName:
        ; Clear field at row 9 col 18, then draw mode string.
        ld      de,32*9+18
        ld      b,8
        ld      a,' '
        call    FillCharsAt

        ld      a,(Decision)
        cp      2
        jp      z,DrawModeLock
        cp      1
        jp      z,DrawModeTrack
DrawModeSearch:
        ld      hl,ModeSearch
        ld      de,32*9+18
        jp      DrawStringAt
DrawModeTrack:
        ld      hl,ModeTrack
        ld      de,32*9+18
        jp      DrawStringAt
DrawModeLock:
        ld      hl,ModeLock
        ld      de,32*9+18
        jp      DrawStringAt

DrawBrainState:
        ld      de,32*11+10
        call    SetNameOffset
        ld      a,(NodeBits)
        call    WriteBin8
        ld      de,32*11+27
        call    SetNameOffset
        ld      a,(Energy)
        call    WriteHex2

        ld      de,32*12+9
        call    SetNameOffset
        ld      a,(NodeBits)
        call    WriteBitBar16

        ld      de,32*13+9
        call    SetNameOffset
        ld      a,(Confidence)
        call    WriteValueBar16

        ld      de,32*14+8
        call    SetNameOffset
        ld      hl,(Memory16)
        call    WriteHex4
        ld      de,32*14+20
        call    SetNameOffset
        ld      hl,(BrainTick)
        call    WriteHex4
        ret

DrawOutputs:
        ld      de,32*16+8
        call    SetNameOffset
        ld      a,(Out0)
        call    WriteHex2
        ld      de,32*16+15
        call    SetNameOffset
        ld      a,(Out0)
        call    WriteBin8

        ld      de,32*17+8
        call    SetNameOffset
        ld      a,(Out1)
        call    WriteHex2
        ld      de,32*17+15
        call    SetNameOffset
        ld      a,(Out1)
        call    WriteBin8

        ld      de,32*18+8
        call    SetNameOffset
        ld      a,(Out2)
        call    WriteHex2
        ld      de,32*18+15
        call    SetNameOffset
        ld      a,(Out2)
        call    WriteBin8
        ret

DrawStatus:
        ; Row 20 flags: S T L C R M H K
        ld      de,32*20+10
        call    SetNameOffset
        ld      a,(Out2)
        call    WriteBin8
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

; A = byte. Writes 16 chars based on the 8 bits, doubled wide.
WriteBitBar16:
        ld      c,a
        ld      b,8
BitBarLoop:
        bit     7,c
        ld      a,'.'
        jp      z,BitBarWrite
        ld      a,'#'
BitBarWrite:
        call    TmsRamOut
        call    TmsRamOut
        sla     c
        djnz    BitBarLoop
        ret

; A = byte. Writes 16-char value bar based on high nibble.
WriteValueBar16:
        rrca
        rrca
        rrca
        rrca
        and     0Fh
        ld      c,a                     ; filled count 0..15
        ld      b,16
ValueBarLoop:
        ld      a,c
        or      a
        jp      z,ValueBarEmpty
        ld      a,'#'
        call    TmsRamOut
        dec     c
        djnz    ValueBarLoop
        ret
ValueBarEmpty:
        ld      a,'.'
        call    TmsRamOut
        djnz    ValueBarLoop
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

; HL = word. Writes four hex digits.
WriteHex4:
        ld      a,h
        call    WriteHex2
        ld      a,l
        jp      WriteHex2

; A = byte. Writes two hex digits.
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
MinVal:         defb 0
HourVal:        defb 0

In0:            defb 0
In1:            defb 0
In2:            defb 0
Change0:        defb 0
Change1:        defb 0
Change2:        defb 0
Out0:           defb 0
Out1:           defb 0
Out2:           defb 0

BrainTick:      defw 0
Memory16:       defw 0
Target:         defb 0
Guess:          defb 055h
ErrorVal:       defb 0
Confidence:     defb 0
Decision:       defb 0             ; 0=search, 1=track, 2=lock
MovedFlag:      defb 0
StepSize:       defb 1
NodeBits:       defb 0
Energy:         defb 0
RandomSeed:     defb 0A7h

LEDBarTable:
        defb    00h,01h,03h,07h,0Fh,1Fh,3Fh,7Fh

SpinChars:
        defb    '|','/','-',05Ch

TitleText:
        defb    "SC700 Z180 BRAIN ENGINE",0
SubText:
        defb    "RTC GPU 3XSC719 THINK DEMO",0
TimeLine:
        defb    "TIME  00:00:00  RTC=Y",0
DateLine:
        defb    "DATE  2000-00-00",0
InputLine:
        defb    "IN00=00  IN01=00  IN02=00",0
SolveLine:
        defb    "TARGET=00 GUESS=00 ERR=00",0
ModeLine:
        defb    "CONF=00  MODE=SEARCH",0
NeuronLine:
        defb    "NEURONS=00000000 ENERGY=00",0
FireBarLine:
        defb    "FIRE   ................",0
ConfBarLine:
        defb    "CONF   ................",0
MemLine:
        defb    "MEM16=0000 TICK=0000",0
Out0Line:
        defb    "OUT00=00 00000000 NODES",0
Out1Line:
        defb    "OUT01=00 00000000 CONF",0
Out2Line:
        defb    "OUT02=00 00000000 STATUS",0
StatusLine:
        defb    "STATUS=00000000 STRLCMHK",0
Footer:
        defb    "PRESS ANY KEY TO EXIT",0

ModeSearch:
        defb    "SEARCH",0
ModeTrack:
        defb    "TRACK",0
ModeLock:
        defb    "LOCK",0

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
