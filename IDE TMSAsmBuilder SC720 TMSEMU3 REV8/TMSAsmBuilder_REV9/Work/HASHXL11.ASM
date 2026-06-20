; HASHXL11.ASM
; Small Computer Z80/Z180 + RomWBW HBIOS + TMSEMU3/TMS9918A
; Ultimate toy hash-brain cracker demo for 3x SC719 digital I/O cards.
; REV11: real/proper CPU-scaled brute force.
;        Z80 sets a real 20-bit maximum. Z180 sets a real 24-bit maximum.
;        BITS and KEY now match, and the candidate range is truly 2^BITS.
;        No fake 32/50-bit display on a 24-bit search.
;
; Hardware target:
;   SC700 Z180 @ 18.432 MHz, RomWBW HBIOS v3.5.1
;   SC727 RTC / DSRTC present through HBIOS
;   SC719 Digital I/O cards at 00h, 01h, 02h
;   TMSEMU3 / TMS9918A video
;
; What it does:
;   - Generates its own hidden toy challenge inside the real CPU limit.
;   - Computes a 56-bit toy hash from that secret.
;   - Brute-force searches the real selected key space until it finds a candidate whose
;     toy hash matches the selected target size.
;   - Z80: +/- adjusts 1..20 real bits.  Z180: +/- adjusts 1..24 real bits.
;   - Uses the RTC only for start/end timestamps and elapsed-time report.
;   - Keeps last completed elapsed time visible while the next crack runs.
;   - Auto-units final elapsed from the live run timer as MS, SEC, MIN, HRS, or DAY.
;   - Uses all three SC719 cards as thinking/data outputs:
;       00h = live hash/neuron activity bits
;       01h = live candidate/hash activity bits
;       02h = live search-work / upper-candidate activity bits
;   - No LCD. No sprites. Text/tile-only GPU path for stability.
;   - Q exits.  +/- changes real hash/key size live.
;
; This is a self-contained toy demo. It does not crack real passwords,
; accounts, files, or outside hashes.
;
; SAFETY:
;   SC719 outputs are real output pins. This program writes to ports
;   00h, 01h, and 02h. If external hardware is attached to the output
;   headers, inspect it first or set SC719_WRITE_LEDS to 0.
;
; Build with TMSAsmBuilder REV9 / sjasmplus, not CP/M ASM.COM.
;
; Needed Libs:
;   include "tms.asm"
;   include "z180.asm"
;   include "utility.asm"

        org     100h

SC719_WRITE_LEDS:       equ 1

SC719_PORT0:            equ 00h
SC719_PORT1:            equ 01h
SC719_PORT2:            equ 02h

HBIOS_INVOKE:           equ 0FFF0h
HBIOS_RTC_GETTIME:      equ 020h       ; HL -> 6 BCD bytes: YY MM DD HH MM SS

CANDIDATES_PER_FRAME:   equ 64         ; 64 tries per video frame, readable but serious
REPORT_PAUSE_FRAMES:    equ 240        ; hold final report before next challenge
HASH_ROUNDS:            equ 12

STATE_SEARCH:           equ 0
STATE_FOUND:            equ 1

Start:
        ld      (OldSP),sp
        ld      sp,Stack

        ; Detect CPU and clock before setting TMS wait timing.
        ; DetectCpuAndSpeed leaves E ready for TmsSetWait:
        ;   Z80        -> E=0
        ;   Z180 slow  -> E=0
        ;   Z180 norm  -> E=1
        ;   Z180 fast  -> E=2
        call    DetectCpuAndSpeed
        call    InitCpuLimits
        call    TmsSetWait

        call    TmsProbe
        jp      z,NoTms

        call    TmsTile
        ld      a,TmsBlack
        call    TmsBackground

        call    LoadAsciiPatterns
        call    SetTileColors
        call    DrawStaticScreen

        call    ReadSC719
        call    NewChallenge
        call    DrawDynamic

MainLoop:
        call    WaitFrame

        ld      a,(FrameTick)
        inc     a
        ld      (FrameTick),a

        call    ReadSC719
        call    BrainRunFrame
        call    BuildOutputs
        call    WriteSC719LEDs
        call    DrawDynamic

        call    CheckKeys
        or      a
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
; Runtime CPU/speed detection for the header.
; z180detect sets Z when a Z180 is found, NZ for plain Z80.
; z180getclk returns the Z180 clock mode in E:
;   E=0: /2 clock, E=1: normal crystal, E=2: x2 clock.
; On the Small Computer systems used here that means:
;   Z80 path  = SC720 Z80  @ 7.372MHz
;   Z180 E=0  = SC700 Z180 @ 9.216MHz
;   Z180 E=1  = SC700 Z180 @ 18.432MHz
;   Z180 E=2  = SC700 Z180 @ 36.864MHz

DetectCpuAndSpeed:
        call    z180detect
        jp      nz,DetectPlainZ80

DetectZ180:
        ld      a,1
        ld      (CpuType),a
        call    z180getclk
        ld      a,e
        ld      (CpuClockMode),a
        ret

DetectPlainZ80:
        xor     a
        ld      (CpuType),a
        ld      (CpuClockMode),a
        ld      e,0
        ret

; Set a real key-space limit from the detected CPU.
; Z80 keeps the demo practical at 20 real bits.
; Z180 gets the full 24-bit candidate engine.
InitCpuLimits:
        ld      a,(CpuType)
        or      a
        jp      z,InitZ80Limits
InitZ180Limits:
        ld      a,24
        ld      (MaxBits),a
        ld      (TargetBits),a
        ret
InitZ80Limits:
        ld      a,20
        ld      (MaxBits),a
        ld      (TargetBits),a
        ret

; ------------------------------------------------------------
; Keyboard control.
;   + or = raises real hash/key size to the CPU maximum.
;   - or _ lowers real hash/key size, min 1 bit.
;   Q/q exits.  Other keys are ignored so the display does not quit
;   accidentally while tuning difficulty.

CheckKeys:
        call    keypress
        ret     z
        cp      '+'
        jp      z,KeyPlus
        cp      '='
        jp      z,KeyPlus
        cp      '-'
        jp      z,KeyMinus
        cp      '_'
        jp      z,KeyMinus
        cp      'Q'
        jp      z,KeyExit
        cp      'q'
        jp      z,KeyExit
        xor     a
        ret

KeyExit:
        ld      a,1
        or      a
        ret

KeyPlus:
        ld      a,(TargetBits)
        ld      b,a
        ld      a,(MaxBits)
        cp      b                       ; carry clear when MaxBits >= TargetBits
        jp      z,KeyPlusDone
        jp      c,KeyPlusDone
        ld      a,b
        inc     a
        ld      (TargetBits),a
        call    NewChallenge
KeyPlusDone:
        xor     a
        ret

KeyMinus:
        ld      a,(TargetBits)
        cp      1
        jp      z,KeyMinusDone
        dec     a
        ld      (TargetBits),a
        call    NewChallenge
KeyMinusDone:
        xor     a
        ret

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

; HL = zero-terminated string. Writes at current TMS name-table address.
DrawStringCurrent:
        ld      a,(hl)
        or      a
        ret     z
        call    TmsRamOut
        inc     hl
        jp      DrawStringCurrent

; Writes the 3-byte last elapsed unit at current TMS address.
WriteLastElapsedUnit:
        ld      hl,LastElapsedUnit
        ld      b,3
WriteLastElapsedUnitLoop:
        ld      a,(hl)
        call    TmsRamOut
        inc     hl
        djnz    WriteLastElapsedUnitLoop
        ret

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

        ; REV4 layout: fewer crowded rows, section dividers, and cleaner
        ; spacing for a real 32x24 TMS9918A display.
        call    DrawCpuHeader
        ld      hl,DividerLine
        ld      de,32*3+2
        call    DrawStringAt

        ld      hl,TimeLine
        ld      de,32*5+2
        call    DrawStringAt
        ld      hl,ElapsedLine
        ld      de,32*6+2
        call    DrawStringAt
        ld      hl,DividerLine
        ld      de,32*8+2
        call    DrawStringAt

        ld      hl,TargetLine
        ld      de,32*10+2
        call    DrawStringAt
        ld      hl,CandidateLine
        ld      de,32*11+2
        call    DrawStringAt
        ld      hl,TriesLine
        ld      de,32*12+2
        call    DrawStringAt
        ld      hl,FoundLine
        ld      de,32*13+2
        call    DrawStringAt
        ld      hl,DividerLine
        ld      de,32*14+2
        call    DrawStringAt

        ld      hl,PipeLine
        ld      de,32*15+2
        call    DrawStringAt
        ld      hl,ProgressLine
        ld      de,32*16+2
        call    DrawStringAt
        ld      hl,NeuronLine
        ld      de,32*17+2
        call    DrawStringAt

        ld      hl,Out0Line
        ld      de,32*19+2
        call    DrawStringAt
        ld      hl,Out1Line
        ld      de,32*20+2
        call    DrawStringAt
        ld      hl,Out2Line
        ld      de,32*21+2
        call    DrawStringAt

        ld      hl,ReportLine
        ld      de,32*22+2
        call    DrawStringAt
        ld      hl,Footer
        ld      de,32*23+3
        call    DrawStringAt
        ret

DrawCpuHeader:
        ld      a,(CpuType)
        or      a
        jp      z,DrawCpuHeaderZ80

DrawCpuHeaderZ180:
        ld      hl,TitleZ180
        ld      de,32*1+3
        call    DrawStringAt

        ld      a,(CpuClockMode)
        or      a
        jp      z,DrawCpuHeaderZ180Slow
        cp      2
        jp      z,DrawCpuHeaderZ180Fast

DrawCpuHeaderZ180Norm:
        ld      hl,SubZ180Norm
        jp      DrawCpuHeaderSub

DrawCpuHeaderZ180Slow:
        ld      hl,SubZ180Slow
        jp      DrawCpuHeaderSub

DrawCpuHeaderZ180Fast:
        ld      hl,SubZ180Fast
        jp      DrawCpuHeaderSub

DrawCpuHeaderZ80:
        ld      hl,TitleZ80
        ld      de,32*1+3
        call    DrawStringAt
        ld      hl,SubZ80

DrawCpuHeaderSub:
        ld      de,32*2+3
        jp      DrawStringAt

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

CopyRTCToStart:
        ld      hl,RTCBuf
        ld      de,StartRTC
        ld      bc,6
        ldir
        ret

CopyRTCToEnd:
        ld      hl,RTCBuf
        ld      de,EndRTC
        ld      bc,6
        ldir
        ret

CaptureStartTime:
        call    ReadRTC
        call    CopyRTCToStart
        call    RTCBufToSeconds
        ld      (StartSeconds),hl
        ret

CaptureEndTime:
        call    ReadRTC
        call    CopyRTCToEnd
        call    RTCBufToSeconds
        ld      (EndSeconds),hl

        ; Elapsed = end - start modulo 65536 seconds.
        ld      de,(StartSeconds)
        or      a                       ; clear carry
        sbc     hl,de
        ld      (ElapsedSeconds),hl
        ret

; Store the completed benchmark time for the report line.
; This is the value that stays on screen while the next challenge runs.
; RTC has one-second resolution, so sub-second solves are estimated from
; video frames as milliseconds.  If RTC is not good, use frames directly.
FinalizeElapsed:
        ld      a,(RTCStatus)
        cp      'Y'
        jp      nz,FinalizeFrames

        ; REV9: elapsed display now comes from the live run timer, not
        ; from the RTC date/day byte. The RTC start/end stamps are still
        ; captured and saved in the background, but the visible benchmark
        ; time is calculated from frames so short solves cannot falsely
        ; display DAY.
        jp      FinalizeRunTimer

FinalizeFrames:
        ; RTC not required for elapsed anymore. Keep this as a safe fall-back
        ; label for older jumps/debug builds.
        jp      FinalizeRunTimer

FinalizeRunTimer:
        ; Day counter first. Only show DAY after the actual run timer reaches
        ; one or more full days.
        ld      hl,(RunDays)
        ld      a,h
        or      l
        jp      z,FinalizeCheckHours
        ld      (LastElapsedValue),hl
        ld      hl,UnitDAY
        call    CopyElapsedUnit
        jp      FinalizeElapsedDone

FinalizeCheckHours:
        ld      a,(RunHours)
        or      a
        jp      z,FinalizeCheckMinutes
        ld      l,a
        ld      h,0
        ld      (LastElapsedValue),hl
        ld      hl,UnitHRS
        call    CopyElapsedUnit
        jp      FinalizeElapsedDone

FinalizeCheckMinutes:
        ld      a,(RunMinutes)
        or      a
        jp      z,FinalizeCheckSeconds
        ld      l,a
        ld      h,0
        ld      (LastElapsedValue),hl
        ld      hl,UnitMIN
        call    CopyElapsedUnit
        jp      FinalizeElapsedDone

FinalizeCheckSeconds:
        ld      a,(RunSeconds8)
        or      a
        jp      z,FinalizeRunMillis
        ld      l,a
        ld      h,0
        ld      (LastElapsedValue),hl
        ld      hl,UnitSEC
        call    CopyElapsedUnit
        jp      FinalizeElapsedDone

FinalizeRunMillis:
        ld      a,(RunFramePart)
        or      a
        jp      nz,FinalizeRunMillisHave
        inc     a                       ; never report a solved run as 00000 MS
FinalizeRunMillisHave:
        ld      l,a
        ld      h,0
        call    FramesToMS
        ld      (LastElapsedValue),hl
        ld      hl,UnitMS
        call    CopyElapsedUnit

FinalizeElapsedDone:
        ld      a,1
        ld      (LastElapsedValid),a
        ret

; HL dividend, DE divisor.  Returns HL quotient, remainder discarded.
; Small and slow is fine here because it runs only after a crack completes.
DivHLByDE:
        ld      bc,0
DivHLByDELoop:
        call    CompareHLDE
        jp      c,DivHLByDEDone
        or      a
        sbc     hl,de
        inc     bc
        jp      DivHLByDELoop
DivHLByDEDone:
        ld      h,b
        ld      l,c
        ret

; HL = frame count.  Approximate NTSC/TMS vblank time as 17 ms/frame.
; Good enough for a watchable 8-bit benchmark display.
FramesToMS:
        ld      d,h
        ld      e,l
        add     hl,hl                   ; x2
        add     hl,hl                   ; x4
        add     hl,hl                   ; x8
        add     hl,hl                   ; x16
        add     hl,de                   ; x17
        ret

CopyElapsedUnit:
        ld      de,LastElapsedUnit
        ld      bc,3
        ldir
        ret

IncRunFrames:
        ; 16-bit frame counter kept for the live REPORT FRM field.
        ld      hl,(RunFrames)
        inc     hl
        ld      (RunFrames),hl

        ; REV9 elapsed timer: 60 frames ~= 1 second.  This is a stable
        ; benchmark timer independent of RTC date rollovers.  It lets the
        ; final elapsed result scale as MS/SEC/MIN/HRS/DAY correctly.
        ld      hl,RunFramePart
        inc     (hl)
        ld      a,(hl)
        cp      60
        ret     c
        xor     a
        ld      (hl),a

        ld      hl,RunSeconds8
        inc     (hl)
        ld      a,(hl)
        cp      60
        ret     c
        xor     a
        ld      (hl),a

        ld      hl,RunMinutes
        inc     (hl)
        ld      a,(hl)
        cp      60
        ret     c
        xor     a
        ld      (hl),a

        ld      hl,RunHours
        inc     (hl)
        ld      a,(hl)
        cp      24
        ret     c
        xor     a
        ld      (hl),a

        ld      hl,(RunDays)
        inc     hl
        ld      (RunDays),hl
        ret

; Convert RTCBuf HH:MM:SS to seconds-of-day modulo 65536 in HL.
RTCBufToSeconds:
        ld      hl,0

        ld      a,(RTCBuf+3)            ; hours BCD
        call    BCDToByte
        ld      b,a
        ld      de,0E10h                ; 3600
        call    AddDETimesB

        ld      a,(RTCBuf+4)            ; minutes BCD
        call    BCDToByte
        ld      b,a
        ld      de,003Ch                ; 60
        call    AddDETimesB

        ld      a,(RTCBuf+5)            ; seconds BCD
        call    BCDToByte
        call    AddByteToHL
        ret

AddDETimesB:
        ld      a,b
        or      a
        ret     z
AddDETimesBLoop:
        add     hl,de
        djnz    AddDETimesBLoop
        ret

; ------------------------------------------------------------
; SC719 digital I/O.

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

GetProgressByte:
        ; Return an active search-band byte from the upper/middle candidate.
        ; REV7 used only CandidateHi, which is a true top search byte but
        ; changes too slowly at 64 candidates/frame and can sit at 00h for
        ; a long time.  This is still valid cracker data, but it mixes the
        ; candidate middle byte with the top byte so the display and LEDs
        ; show the Z180 actually working.
        ld      hl,(Candidate)
        ld      a,h
        ld      b,a
        ld      a,(CandidateHi)
        xor     b
        ret

BuildOutputs:
        ; OUT00 = live hash/neuron activity.  This one already looked good,
        ; so keep it as the fast hash scan output.
        ld      a,(Hash0)
        ld      b,a
        ld      a,(Hash1)
        xor     b
        ld      b,a
        ld      a,(Hash2)
        xor     b
        ld      b,a
        ld      a,(Candidate)
        xor     b
        ld      b,a
        ld      a,(FrameTick)
        xor     b
        ld      (Out0),a

        ; OUT01 = candidate/hash activity.  This replaces the old status
        ; flags that only flip-flopped between values like 53h and 13h.
        ; It is live data from the current candidate and current hash.
        ld      hl,(Candidate)
        ld      a,l
        ld      b,a
        ld      a,(Hash0)
        xor     b
        ld      b,a
        ld      a,(FrameTick)
        xor     b
        ld      (Out1),a

        ; OUT02 = search work / upper candidate activity.  This replaces
        ; the old progress bar output that could stay at 00000000 because
        ; CandidateHi changes very slowly.  It uses the middle/top candidate
        ; bytes and current hash, so it is valid and visibly alive.
        ld      hl,(Candidate)
        ld      a,h
        ld      b,a
        ld      a,(CandidateHi)
        xor     b
        ld      b,a
        ld      a,(Hash1)
        xor     b
        ld      (Out2),a
        ret

BuildStatusBits:
        xor     a
        ld      b,a

        ; bit 0 = searching
        ld      a,(SearchState)
        cp      STATE_SEARCH
        jp      nz,StatusNotSearching
        set     0,b
StatusNotSearching:
        ; bit 1 = hash engine alive
        set     1,b
        ; bit 2 = hash match/found
        ld      a,(SearchState)
        cp      STATE_FOUND
        jp      nz,StatusNotFound
        set     2,b
StatusNotFound:
        ; bit 3 = new challenge / report pause active
        ld      a,(ReportPause)
        or      a
        jp      z,StatusNoPause
        set     3,b
StatusNoPause:
        ; bit 4 = RTC good
        ld      a,(RTCStatus)
        cp      'Y'
        jp      nz,StatusRtcBad
        set     4,b
StatusRtcBad:
        ; bit 5 = candidate high-space bit
        ld      a,(CandidateHi)
        bit     3,a
        jp      z,StatusNotHigh
        set     5,b
StatusNotHigh:
        ; bit 6 = heartbeat
        ld      a,(FrameTick)
        and     20h
        jp      z,StatusNoHB
        set     6,b
StatusNoHB:
        ; bit 7 = lock/report
        ld      a,(SearchState)
        cp      STATE_FOUND
        jp      nz,StatusDone
        set     7,b
StatusDone:
        ld      a,b
        ret

; ------------------------------------------------------------
; Hash brain challenge and cracker.

NewChallenge:
        call    CaptureStartTime

        ; Generate a hidden secret from the local pseudo-random brain,
        ; SC719 inputs, and the challenge counter. Then mask it to the
        ; selected real key size. RTC is kept for timestamps/reporting only.
        call    Rand8
        ld      b,a
        ld      a,(In0)
        xor     b
        ld      l,a                     ; secret low byte

        call    Rand8
        ld      b,a
        ld      a,(In1)
        add     a,b
        ld      b,a
        ld      a,(In2)
        xor     b
        ld      h,a                     ; secret middle byte

        call    Rand8
        ld      b,a
        ld      a,(ChallengeCount)
        add     a,b
        xor     h                      ; secret high byte, 000000-FFFFFF
        ld      (SecretHi),a
        ld      (Secret),hl
        call    MaskSecretToTargetBits

        ; Compute the target hash from the hidden real-size secret.
        ld      (HashInput),hl
        ld      a,(SecretHi)
        ld      (HashInputHi),a
        call    ComputeHash
        ld      a,(Hash0)
        ld      (Target0),a
        ld      a,(Hash1)
        ld      (Target1),a
        ld      a,(Hash2)
        ld      (Target2),a
        ld      a,(Hash3)
        ld      (Target3),a
        ld      a,(Hash4)
        ld      (Target4),a
        ld      a,(Hash5)
        ld      (Target5),a
        ld      a,(Hash6)
        ld      (Target6),a

        ld      hl,0
        ld      (Candidate),hl
        ld      (FoundCandidate),hl
        ld      (RunFrames),hl
        ld      (RunDays),hl
        xor     a
        ld      (RunFramePart),a
        ld      (RunSeconds8),a
        ld      (RunMinutes),a
        ld      (RunHours),a
        ld      (CandidateHi),a
        ld      (FoundHi),a
        ld      (ReportPause),a
        ld      (EndValid),a
        ld      (SearchState),a
        ld      (BestError),a
        ld      (TriesHigh),a
        ld      a,'N'
        ld      (FoundFlag),a

        ld      hl,ChallengeCount
        inc     (hl)
        ret

BrainRunFrame:
        ld      a,(SearchState)
        cp      STATE_FOUND
        jp      z,BrainReportPause
        jp      BrainSearchFrame

BrainReportPause:
        ld      hl,ReportPause
        ld      a,(hl)
        or      a
        jp      z,BrainStartNext
        dec     (hl)
        ret
BrainStartNext:
        call    NewChallenge
        ret

BrainSearchFrame:
        call    IncRunFrames
        ld      a,CANDIDATES_PER_FRAME
        ld      (SearchWork),a
BrainSearchLoop:
        ld      hl,(Candidate)
        ld      (HashInput),hl
        ld      a,(CandidateHi)
        ld      (HashInputHi),a
        call    ComputeHash
        call    UpdateBestError
        call    CompareTargetHash
        jp      z,HashCracked

        call    AdvanceCandidate
        ld      hl,SearchWork
        dec     (hl)
        jp      nz,BrainSearchLoop
        ret

HashCracked:
        ld      hl,(Candidate)
        ld      (FoundCandidate),hl
        ld      a,(CandidateHi)
        ld      (FoundHi),a
        call    CaptureEndTime
        call    FinalizeElapsed
        ld      a,1
        ld      (EndValid),a
        ld      a,'Y'
        ld      (FoundFlag),a
        ld      a,STATE_FOUND
        ld      (SearchState),a
        ld      a,REPORT_PAUSE_FRAMES
        ld      (ReportPause),a
        ret

AdvanceCandidate:
        ld      hl,(Candidate)
        inc     hl
        ld      (Candidate),hl
        ld      a,h
        or      l
        jp      nz,AdvanceCheckLimit

        ; Carry into the high byte.  If the full 24-bit counter wraps,
        ; start a new challenge.  Smaller real key sizes are caught by
        ; CandidateExceededLimit below.
        ld      a,(CandidateHi)
        inc     a
        ld      (CandidateHi),a
        jp      z,AdvanceWrapped

AdvanceCheckLimit:
        call    CandidateExceededLimit
        ret     z

AdvanceWrapped:
        call    NewChallenge
        ret

; Returns Z when CandidateHi:Candidate is still inside the selected
; real key space. Returns NZ when it has reached 2^TargetBits.
CandidateExceededLimit:
        ld      a,(TargetBits)
        cp      9
        jp      c,CandidateLimitLowByte
        cp      17
        jp      c,CandidateLimitWord

CandidateLimit24:
        ; TargetBits 17..24.  Low 16 bits are fully used; high byte is masked.
        sub     16
        call    GetLowBitMask
        cpl
        ld      c,a
        ld      a,(CandidateHi)
        and     c
        ret

CandidateLimitWord:
        ; TargetBits 9..16.  High candidate byte must be zero and H is masked.
        ld      a,(CandidateHi)
        or      a
        ret     nz
        ld      a,(TargetBits)
        sub     8
        call    GetLowBitMask
        cpl
        ld      c,a
        ld      hl,(Candidate)
        ld      a,h
        and     c
        ret

CandidateLimitLowByte:
        ; TargetBits 1..8.  H and high candidate byte must be zero; L is masked.
        ld      a,(CandidateHi)
        or      a
        ret     nz
        ld      hl,(Candidate)
        ld      a,h
        or      a
        ret     nz
        ld      a,(TargetBits)
        call    GetLowBitMask
        cpl
        ld      c,a
        ld      a,l
        and     c
        ret

; Mask SecretHi:Secret so a generated target is guaranteed to exist in the
; same selected real key space the machine will brute force.
MaskSecretToTargetBits:
        ld      a,(TargetBits)
        cp      9
        jp      c,MaskSecretLowByte
        cp      17
        jp      c,MaskSecretWord

MaskSecret24:
        sub     16
        call    GetLowBitMask
        ld      c,a
        ld      a,(SecretHi)
        and     c
        ld      (SecretHi),a
        ret

MaskSecretWord:
        xor     a
        ld      (SecretHi),a
        ld      a,(TargetBits)
        sub     8
        call    GetLowBitMask
        ld      c,a
        ld      hl,(Secret)
        ld      a,h
        and     c
        ld      h,a
        ld      (Secret),hl
        ret

MaskSecretLowByte:
        xor     a
        ld      (SecretHi),a
        ld      h,a
        ld      a,(TargetBits)
        call    GetLowBitMask
        ld      c,a
        ld      a,(Secret)
        and     c
        ld      l,a
        ld      (Secret),hl
        ret

CompareTargetHash:
        ; Compare selected low bits of the expanded 56-bit toy hash.
        ; TargetBits is CPU-limited and matches the real key size.
        ld      a,(TargetBits)
        cp      9
        jp      c,CompareBitsLowByte
        cp      17
        jp      c,CompareBitsTwoBytes
        cp      25
        jp      c,CompareBitsThreeBytes
        cp      33
        jp      c,CompareBitsFourBytes
        cp      41
        jp      c,CompareBitsFiveBytes
        cp      49
        jp      c,CompareBitsSixBytes
        jp      CompareBitsSevenBytes

CompareBitsSevenBytes:
        call    CompareFirstSixBytes
        ret     nz
        ld      a,(TargetBits)
        sub     48                      ; 1..2 bits of Hash6 for max 50
        call    GetLowBitMask
        ld      c,a
        ld      a,(Hash6)
        ld      b,a
        ld      a,(Target6)
        xor     b
        and     c
        ret

CompareBitsSixBytes:
        call    CompareFirstFiveBytes
        ret     nz
        ld      a,(TargetBits)
        sub     40                      ; 1..8 bits of Hash5
        call    GetLowBitMask
        ld      c,a
        ld      a,(Hash5)
        ld      b,a
        ld      a,(Target5)
        xor     b
        and     c
        ret

CompareBitsFiveBytes:
        call    CompareFirstFourBytes
        ret     nz
        ld      a,(TargetBits)
        sub     32                      ; 1..8 bits of Hash4
        call    GetLowBitMask
        ld      c,a
        ld      a,(Hash4)
        ld      b,a
        ld      a,(Target4)
        xor     b
        and     c
        ret

CompareBitsFourBytes:
        call    CompareFirstThreeBytes
        ret     nz
        ld      a,(TargetBits)
        sub     24                      ; 1..8 bits of Hash3
        call    GetLowBitMask
        ld      c,a
        ld      a,(Hash3)
        ld      b,a
        ld      a,(Target3)
        xor     b
        and     c
        ret

CompareBitsThreeBytes:
        call    CompareFirstTwoBytes
        ret     nz
        ld      a,(TargetBits)
        sub     16                      ; 1..8 bits of Hash2
        call    GetLowBitMask
        ld      c,a
        ld      a,(Hash2)
        ld      b,a
        ld      a,(Target2)
        xor     b
        and     c
        ret

CompareBitsTwoBytes:
        ld      a,(Hash0)
        ld      b,a
        ld      a,(Target0)
        cp      b
        ret     nz
        ld      a,(TargetBits)
        sub     8                       ; 1..8 bits of Hash1
        call    GetLowBitMask
        ld      c,a
        ld      a,(Hash1)
        ld      b,a
        ld      a,(Target1)
        xor     b
        and     c
        ret

CompareBitsLowByte:
        ld      a,(TargetBits)          ; 1..8 bits of Hash0
        call    GetLowBitMask
        ld      c,a
        ld      a,(Hash0)
        ld      b,a
        ld      a,(Target0)
        xor     b
        and     c
        ret

CompareFirstSixBytes:
        call    CompareFirstFiveBytes
        ret     nz
        ld      a,(Hash5)
        ld      b,a
        ld      a,(Target5)
        cp      b
        ret

CompareFirstFiveBytes:
        call    CompareFirstFourBytes
        ret     nz
        ld      a,(Hash4)
        ld      b,a
        ld      a,(Target4)
        cp      b
        ret

CompareFirstFourBytes:
        call    CompareFirstThreeBytes
        ret     nz
        ld      a,(Hash3)
        ld      b,a
        ld      a,(Target3)
        cp      b
        ret

CompareFirstThreeBytes:
        call    CompareFirstTwoBytes
        ret     nz
        ld      a,(Hash2)
        ld      b,a
        ld      a,(Target2)
        cp      b
        ret

CompareFirstTwoBytes:
        ld      a,(Hash0)
        ld      b,a
        ld      a,(Target0)
        cp      b
        ret     nz
        ld      a,(Hash1)
        ld      b,a
        ld      a,(Target1)
        cp      b
        ret

GetLowBitMask:
        ; A = 1..8, returns mask 01,03,07,0F,1F,3F,7F,FF.
        dec     a
        ld      e,a
        ld      d,0
        ld      hl,LowBitMaskTable
        add     hl,de
        ld      a,(hl)
        ret

UpdateBestError:
        ; Quick visible error score from target/current hash difference.
        ld      a,(Hash0)
        ld      b,a
        ld      a,(Target0)
        xor     b
        ld      b,a
        ld      a,(Hash1)
        ld      c,a
        ld      a,(Target1)
        xor     c
        add     a,b
        ld      b,a
        ld      a,(Hash2)
        ld      c,a
        ld      a,(Target2)
        xor     c
        add     a,b
        ld      (BestError),a
        ret

; ------------------------------------------------------------
; 24-bit toy hash.
; Input:  HashInputHi:HashInput = 24-bit candidate.
; Output: Hash0/Hash1/Hash2.
;
; This is intentionally a toy mixer for an on-screen brute-force demo.
; It is not a real secure cryptographic hash.

ComputeHash:
        ld      hl,(HashInput)
        ld      a,(HashInputHi)
        and     0Fh
        xor     h
        xor     0A5h
        ld      d,a                     ; D = lane 0
        ld      a,l
        xor     05Ah
        ld      e,a                     ; E = lane 1
        ld      a,(HashInputHi)
        and     0Fh
        add     a,h
        add     a,l
        xor     03Ch
        ld      c,a                     ; C = lane 2

        ld      b,HASH_ROUNDS
HashRoundLoop:
        ; D = ROL8(D + E + 11h) XOR C
        ld      a,d
        add     a,e
        add     a,011h
        rlca
        xor     c
        ld      d,a

        ; E = ROR8(E + C + candidate-low) XOR D
        ld      a,e
        add     a,c
        add     a,l
        rrca
        xor     d
        ld      e,a

        ; C = ROL2(C + D + candidate-high) XOR E
        ld      a,c
        add     a,d
        add     a,h
        rlca
        rlca
        xor     e
        ld      c,a

        djnz    HashRoundLoop

        ld      a,d
        ld      (Hash0),a
        ld      a,e
        ld      (Hash1),a
        ld      a,c
        ld      (Hash2),a

        ; Extra mixed lanes let the display compare up to 50 toy hash bits.
        ; They are derived from the same 24-bit candidate and final lanes.
        ld      a,d
        add     a,h
        xor     c
        ld      (Hash3),a
        ld      a,e
        add     a,l
        xor     d
        ld      (Hash4),a
        ld      a,c
        ld      b,a
        ld      a,(HashInputHi)
        add     a,b
        xor     e
        ld      (Hash5),a
        ld      a,d
        xor     e
        xor     c
        ld      b,a
        ld      a,(HashInput)
        xor     b
        ld      (Hash6),a
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
; Drawing dynamic data.

DrawDynamic:
        call    DrawTimes
        call    DrawElapsed
        call    DrawHashLines
        call    DrawBrainBars
        call    DrawOutputs
        call    DrawReport
        call    DrawSpinner
        ret

DrawTimes:
        ; START time at row 4 col 8.
        ld      de,32*5+8
        call    SetNameOffset
        ld      a,(StartRTC+3)
        call    WriteBCD2
        ld      a,':'
        call    TmsRamOut
        ld      a,(StartRTC+4)
        call    WriteBCD2
        ld      a,':'
        call    TmsRamOut
        ld      a,(StartRTC+5)
        call    WriteBCD2

        ; END time at row 4 col 22, or -------- while searching.
        ld      de,32*5+22
        call    SetNameOffset
        ld      a,(EndValid)
        or      a
        jp      z,DrawEndDashes
        ld      a,(EndRTC+3)
        call    WriteBCD2
        ld      a,':'
        call    TmsRamOut
        ld      a,(EndRTC+4)
        call    WriteBCD2
        ld      a,':'
        call    TmsRamOut
        ld      a,(EndRTC+5)
        call    WriteBCD2
        ret
DrawEndDashes:
        ld      b,8
        ld      a,'-'
DrawEndDashLoop:
        call    TmsRamOut
        djnz    DrawEndDashLoop
        ret

DrawElapsed:
        ; Row 5 is LAST, not current.  It stays on screen while the next
        ; challenge is cracking and is replaced only after a new solve.
        ld      a,(LastElapsedValid)
        or      a
        jp      z,DrawElapsedDashes

        ld      de,32*6+7
        call    SetNameOffset
        ld      hl,(LastElapsedValue)
        call    WriteDec16
        ld      de,32*6+13
        call    SetNameOffset
        call    WriteLastElapsedUnit
        jp      DrawElapsedCycle

DrawElapsedDashes:
        ld      de,32*6+7
        call    SetNameOffset
        ld      b,5
        ld      a,'-'
DrawElapsedDashDigits:
        call    TmsRamOut
        djnz    DrawElapsedDashDigits
        ld      de,32*6+13
        call    SetNameOffset
        ld      b,3
        ld      a,'-'
DrawElapsedDashUnit:
        call    TmsRamOut
        djnz    DrawElapsedDashUnit

DrawElapsedCycle:
        ld      de,32*6+24
        call    SetNameOffset
        ld      a,(ChallengeCount)
        call    WriteHex2
        ret

DrawHashLines:
        ; B= selected hash bits. K= real key bits.
        ; They now match, so the brute force is real and proper for the CPU.
        ld      de,32*10+4
        call    SetNameOffset
        ld      a,(TargetBits)
        call    WriteDec2
        ld      de,32*10+9
        call    SetNameOffset
        ld      a,(TargetBits)
        call    WriteDec2
        ld      de,32*10+14
        call    SetNameOffset
        ld      a,(Target0)
        call    WriteHex2
        ld      a,(Target1)
        call    WriteHex2
        ld      a,(Target2)
        call    WriteHex2
        ld      a,(Target3)
        call    WriteHex2
        ld      a,(Target4)
        call    WriteHex2
        ld      a,(Target5)
        call    WriteHex2
        ld      a,(Target6)
        call    WriteHex2

        ; Candidate and current 7-byte toy hash row.
        ld      de,32*11+4
        call    SetNameOffset
        ld      a,(CandidateHi)
        ld      hl,(Candidate)
        call    WriteHex6
        ld      de,32*11+13
        call    SetNameOffset
        ld      a,(Hash0)
        call    WriteHex2
        ld      a,(Hash1)
        call    WriteHex2
        ld      a,(Hash2)
        call    WriteHex2
        ld      a,(Hash3)
        call    WriteHex2
        ld      a,(Hash4)
        call    WriteHex2
        ld      a,(Hash5)
        call    WriteHex2
        ld      a,(Hash6)
        call    WriteHex2

        ; Tries/progress and state row.  This is hex so the full 24-bit
        ; search space fits cleanly on a 32-column screen.
        ld      de,32*12+8
        call    SetNameOffset
        ld      a,(CandidateHi)
        ld      hl,(Candidate)
        call    WriteHex6
        call    DrawStateName

        ; Found row 10.
        ld      de,32*13+8
        call    SetNameOffset
        ld      a,(FoundFlag)
        cp      'Y'
        jp      z,DrawFoundCandidate
        ld      a,'X'
        call    TmsRamOut
        call    TmsRamOut
        call    TmsRamOut
        call    TmsRamOut
        call    TmsRamOut
        call    TmsRamOut
        ret
DrawFoundCandidate:
        ld      a,(FoundHi)
        ld      hl,(FoundCandidate)
        call    WriteHex6
        ret

DrawStateName:
        ; clear state field row 9 col 24
        ld      de,32*12+21
        ld      b,7
        ld      a,' '
        call    FillCharsAt
        ld      a,(SearchState)
        cp      STATE_FOUND
        jp      z,DrawStateFound
        ld      hl,StateSearchText
        ld      de,32*12+21
        jp      DrawStringAt
DrawStateFound:
        ld      hl,StateFoundText
        ld      de,32*12+21
        jp      DrawStringAt

DrawBrainBars:
        ld      de,32*15+13
        call    SetNameOffset
        ld      a,(Out0)
        call    WriteBitBar16

        ld      de,32*16+13
        call    SetNameOffset
        call    GetProgressByte
        call    WriteValueBar16

        ld      de,32*17+9
        call    SetNameOffset
        ld      a,(Out0)
        call    WriteBin8
        ld      de,32*17+23
        call    SetNameOffset
        ld      a,(BestError)
        call    WriteHex2
        ret

DrawOutputs:
        ld      de,32*19+8
        call    SetNameOffset
        ld      a,(Out0)
        call    WriteHex2
        ld      de,32*19+12           ; binary field starts after OUT00=xx space
        call    SetNameOffset
        ld      a,(Out0)
        call    WriteBin8

        ld      de,32*20+8
        call    SetNameOffset
        ld      a,(Out1)
        call    WriteHex2
        ld      de,32*20+12           ; binary field starts after OUT01=xx space
        call    SetNameOffset
        ld      a,(Out1)
        call    WriteBin8

        ld      de,32*21+8
        call    SetNameOffset
        ld      a,(Out2)
        call    WriteHex2
        ld      de,32*21+12           ; binary field starts after OUT02=xx space
        call    SetNameOffset
        ld      a,(Out2)
        call    WriteBin8
        ret

DrawReport:
        ld      de,32*22+9
        ld      b,22
        ld      a,' '
        call    FillCharsAt
        ld      a,(SearchState)
        cp      STATE_FOUND
        jp      z,DrawFinalReport

        ; Live/current run uses frame ticks so the RTC is still only used
        ; for final start/end timestamps.  This lets the screen show motion
        ; without destroying the previous final elapsed result.
        ld      hl,ReportCracking
        ld      de,32*22+9
        call    DrawStringAt
        ld      de,32*22+18
        call    SetNameOffset
        ld      hl,(RunFrames)
        call    WriteDec16
        ld      de,32*22+24
        call    SetNameOffset
        ld      hl,UnitFRM
        jp      DrawStringCurrent

DrawFinalReport:
        ld      hl,ReportSolved
        ld      de,32*22+9
        call    DrawStringAt
        ld      de,32*22+16
        call    SetNameOffset
        ld      hl,(LastElapsedValue)
        call    WriteDec16
        ld      de,32*22+22
        call    SetNameOffset
        call    WriteLastElapsedUnit
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
        ld      de,32*23+27
        call    SetNameOffset
        jp      TmsRamOut

; ------------------------------------------------------------
; Numeric/text writers.

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

; A = 0..99. Writes two decimal digits to current TMS address.
WriteDec2:
        ld      b,0
WriteDec2Tens:
        cp      10
        jp      c,WriteDec2Digits
        sub     10
        inc     b
        jp      WriteDec2Tens
WriteDec2Digits:
        ld      c,a
        ld      a,b
        add     a,'0'
        call    TmsRamOut
        ld      a,c
        add     a,'0'
        jp      TmsRamOut

; A = high byte, HL = low 16 bits. Writes six hex digits.
WriteHex6:
        push    hl
        call    WriteHex2
        pop     hl
        jp      WriteHex4

; A = high nibble, HL = low 16 bits. Writes five hex digits.
WriteHex5:
        push    hl
        and     0Fh
        call    WriteHexNibble
        pop     hl
        jp      WriteHex4

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

; HL = 0..65535. Writes fixed five-digit decimal.
WriteDec16:
        ld      de,10000
        call    WriteDecDigit
        ld      de,1000
        call    WriteDecDigit
        ld      de,100
        call    WriteDecDigit
        ld      de,10
        call    WriteDecDigit
        ld      a,l
        add     a,'0'
        jp      TmsRamOut

; HL value, DE divisor. Writes one digit and leaves remainder in HL.
WriteDecDigit:
        ld      b,0
WriteDecDigitLoop:
        call    CompareHLDE
        jp      c,WriteDecDigitDone
        or      a                       ; clear carry
        sbc     hl,de
        inc     b
        jp      WriteDecDigitLoop
WriteDecDigitDone:
        ld      a,b
        add     a,'0'
        jp      TmsRamOut

; Compare HL with DE. Carry set if HL < DE.
CompareHLDE:
        ld      a,h
        cp      d
        ret     nz
        ld      a,l
        cp      e
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

; Add unsigned byte A to HL.
AddByteToHL:
        ld      e,a
        ld      d,0
        add     hl,de
        ret

; ------------------------------------------------------------
; Constants/state.

OldSP:              defw 0
CpuType:            defb 0               ; 0=Z80, 1=Z180
CpuClockMode:       defb 0               ; Z180: 0=/2, 1=normal, 2=x2
MaxBits:            defb 24              ; CPU-selected real maximum

FrameTick:          defb 0
SpinIdx:            defb 0
RTCStatus:          defb 'N'
RTCBuf:             defb 0,0,0,0,0,0
StartRTC:           defb 0,0,0,0,0,0
EndRTC:             defb 0,0,0,0,0,0
StartSeconds:       defw 0
EndSeconds:         defw 0
ElapsedSeconds:     defw 0
LastElapsedValue:   defw 0
LastElapsedUnit:    defb '-','-','-'
LastElapsedValid:   defb 0
RunFrames:          defw 0               ; live frame display, may wrap on very long runs
RunFramePart:       defb 0               ; 0..59 frames inside current second
RunSeconds8:        defb 0               ; 0..59 seconds
RunMinutes:         defb 0               ; 0..59 minutes
RunHours:           defb 0               ; 0..23 hours
RunDays:            defw 0               ; full elapsed days from run timer
EndValid:           defb 0

In0:                defb 0
In1:                defb 0
In2:                defb 0
Out0:               defb 0
Out1:               defb 0
Out2:               defb 0

RandomSeed:         defb 0A7h
TargetBits:         defb 24              ; set at startup: Z80=20, Z180=24
ChallengeCount:     defb 0
SearchState:        defb 0
SearchWork:         defb 0
ReportPause:        defb 0
FoundFlag:          defb 'N'
TriesHigh:          defb 0

Secret:             defw 0
SecretHi:           defb 0
HashInput:          defw 0
HashInputHi:        defb 0
Candidate:          defw 0
CandidateHi:        defb 0
FoundCandidate:     defw 0
FoundHi:            defb 0
Target0:            defb 0
Target1:            defb 0
Target2:            defb 0
Target3:            defb 0
Target4:            defb 0
Target5:            defb 0
Target6:            defb 0
Hash0:              defb 0
Hash1:              defb 0
Hash2:              defb 0
Hash3:              defb 0
Hash4:              defb 0
Hash5:              defb 0
Hash6:              defb 0
BestError:          defb 0

LEDBarTable:
        defb    00h,01h,03h,07h,0Fh,1Fh,3Fh,7Fh

LowBitMaskTable:
        defb    01h,03h,07h,0Fh,1Fh,3Fh,7Fh,0FFh

SpinChars:
        defb    '|','/','-',05Ch

TitleZ180:
        defb    "SC700 Z180 HASH BRAIN XL11",0
TitleZ80:
        defb    "SC720 Z80 HASH BRAIN XL11",0
SubZ180Slow:
        defb    "9.216MHZ  MAX24 RTC SC719",0
SubZ180Norm:
        defb    "18.432MHZ MAX24 RTC SC719",0
SubZ180Fast:
        defb    "36.864MHZ MAX24 RTC SC719",0
SubZ80:
        defb    "7.372MHZ  MAX20 RTC SC719",0
DividerLine:
        defb    "----------------------------",0
TimeLine:
        defb    "START 00:00:00  END --:--:--",0
ElapsedLine:
        defb    "LAST 00000 ---  CYCLE 00",0
TargetLine:
        defb    "B=00 K=24 T=00000000000000",0
CandidateLine:
        defb    "C=000000 H=00000000000000",0
TriesLine:
        defb    "TRIES 000000 STATE SEARCH",0
FoundLine:
        defb    "FOUND XXXXXX SECRET HIDDEN",0
PipeLine:
        defb    "HASH PIPE   ................",0
ProgressLine:
        defb    "SCAN BAND   ................",0
NeuronLine:
        defb    "NEURON 00000000  ERR 00",0
Out0Line:
        defb    "OUT00 00  00000000 HASH",0
Out1Line:
        defb    "OUT01 00  00000000 CAND",0
Out2Line:
        defb    "OUT02 00  00000000 WORK",0
ReportLine:
        defb    "REPORT WAITING",0
Footer:
        defb    "Q EXIT +/- REAL CPU BITS",0

StateSearchText:
        defb    "SEARCH",0
StateFoundText:
        defb    "FOUND",0
ReportCracking:
        defb    "CRACKING ",0
ReportSolved:
        defb    "SOLVED ",0
UnitSEC:
        defb    "SEC"
UnitMIN:
        defb    "MIN"
UnitHRS:
        defb    "HRS"
UnitDAY:
        defb    "DAY"
UnitMS:
        defb    "MS "
UnitFRM:
        defb    "FRM",0

NoTmsMsg:
        defb    "TMSEMU3 / TMS9918A not found, aborting!$"

; ------------------------------------------------------------
; Tile color table and ASCII tile font.
; TMS Graphics I uses one color byte per 8 tile patterns.
; High nibble = foreground, low nibble = background.

TileColorTable:
        ; REV4 calmer color plan for real screens:
        ;   20-27: cyan bars (#)
        ;   28-2F: gray dividers/punctuation (- . /)
        ;   30-3F: light-yellow numbers/hex digits
        ;   40-5F: clean white uppercase text
        ; High nibble = foreground, low nibble = black background.
        defb    0F1h,0F1h,0F1h,0F1h
        defb    071h,0E1h,0B1h,0B1h
        defb    0F1h,0F1h,0F1h,0F1h
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
