; ------------------------------------------------------------
; RWBANK.ASM  FIXED2
; RomWBW/HBIOS Application Bank RAM Library
;
; Use this for SC700 / RomWBW banked application RAM.
; Do NOT use raw Z180 CBR/BBR/CBAR for the chess brain.
;
; Proven on user's SC700:
;   SYSGET/APPBNKS returned:
;     start = 89h
;     count = 03h
;     size  = 80h pages = 32K per bank
;   Official app banks:
;     89h, 8Ah, 8Bh
;
; API:
; FIXED2:
;   Replaced illegal Z80 `ld (addr),d` with `ld a,d / ld (addr),a`.
;
;   call RWBK_Init
;       returns A=0 if app banks are available
;       returns A=1 if no usable app banks
;
;   call RWBK_GetInfo
;       returns:
;         A = last APPBNKS status
;         H = first app Bank ID
;         L = app bank count
;         E = app bank size in 256-byte pages
;
;   call RWBK_Peek
;       input:
;         D  = Bank ID
;         HL = address inside bank
;       output:
;         A  = HBIOS status
;         E  = byte read
;
;   call RWBK_Poke
;       input:
;         D  = Bank ID
;         HL = address inside bank
;         E  = byte to write
;       output:
;         A  = HBIOS status
;
;   call RWBK_IsAppBank
;       input:
;         A = Bank ID
;       output:
;         A = 0 if bank is inside official APPBNKS range
;         A = 1 if not
;
;   call RWBK_WriteSig4
;       input:
;         D  = Bank ID
;         HL = address
;       writes:
;         A5, BankID, BankID XOR FF, BankID + 3C
;       output:
;         A = OR of all poke status bytes
;
;   call RWBK_Read4
;       input:
;         D  = Bank ID
;         HL = address
;         IX = destination buffer, 4 bytes
;       output:
;         A = OR of all peek status bytes
;
;   call RWBK_Write4
;       input:
;         D  = Bank ID
;         HL = address
;         IX = source buffer, 4 bytes
;       output:
;         A = OR of all poke status bytes
;
; Notes:
;   Uses RomWBW HBIOS proxy CALL FFF0h.
;   No raw MMU writes.
;   No SYSSETBNK.
;   Safe for CP/M apps.
; ------------------------------------------------------------

RWBK_HB_INVOKE       equ 0FFF0h

RWBK_SYSGET          equ 0F8h
RWBK_SYSPEEK         equ 0FAh
RWBK_SYSPOKE         equ 0FBh

RWBK_SG_APPBNKS      equ 0F5h

; ------------------------------------------------------------
; Initialize app bank info.

RWBK_Init:
        ld      b,RWBK_SYSGET
        ld      c,RWBK_SG_APPBNKS
        call    RWBK_HB_INVOKE

        ld      (RWBK_StApp),a
        ld      a,h
        ld      (RWBK_AppStart),a
        ld      a,l
        ld      (RWBK_AppCount),a
        ld      a,e
        ld      (RWBK_AppSizePg),a

        xor     a
        ld      (RWBK_OK),a

        ld      a,(RWBK_StApp)
        or      a
        jp      nz,RWBK_InitFail

        ld      a,(RWBK_AppCount)
        or      a
        jp      z,RWBK_InitFail

        ld      a,1
        ld      (RWBK_OK),a
        xor     a
        ret

RWBK_InitFail:
        ld      a,1
        ret

; ------------------------------------------------------------
; Return info from last RWBK_Init.
;
; A = last APPBNKS status
; H = first app bank
; L = count
; E = size pages

RWBK_GetInfo:
        ld      a,(RWBK_AppStart)
        ld      h,a
        ld      a,(RWBK_AppCount)
        ld      l,a
        ld      a,(RWBK_AppSizePg)
        ld      e,a
        ld      a,(RWBK_StApp)
        ret

; ------------------------------------------------------------
; Check if A is in app-bank range.
; Return A=0 if valid, A=1 if not valid.

RWBK_IsAppBank:
        ld      (RWBK_TmpBank),a

        ld      a,(RWBK_OK)
        or      a
        jp      z,RWBK_NotAppBank

        ld      a,(RWBK_TmpBank)
        ld      b,a

        ld      a,(RWBK_AppStart)
        cp      b
        jp      z,RWBK_AtOrAbove
        jp      nc,RWBK_NotAppBank

RWBK_AtOrAbove:
        ; end-exclusive = AppStart + AppCount
        ld      a,(RWBK_AppStart)
        ld      c,a
        ld      a,(RWBK_AppCount)
        add     a,c
        ld      c,a

        ld      a,(RWBK_TmpBank)
        cp      c
        jp      nc,RWBK_NotAppBank

        xor     a
        ret

RWBK_NotAppBank:
        ld      a,1
        ret

; ------------------------------------------------------------
; SYSPEEK wrapper.
; input D=Bank ID, HL=address
; output A=status, E=byte read

RWBK_Peek:
        ld      b,RWBK_SYSPEEK
        ld      c,0
        call    RWBK_HB_INVOKE
        ret

; ------------------------------------------------------------
; SYSPOKE wrapper.
; input D=Bank ID, HL=address, E=byte
; output A=status

RWBK_Poke:
        ld      b,RWBK_SYSPOKE
        ld      c,0
        call    RWBK_HB_INVOKE
        ret

; ------------------------------------------------------------
; Read four bytes from bank/address into IX buffer.
; input D=Bank ID, HL=address, IX=dest
; output A=OR of status bytes.

RWBK_Read4:
        xor     a
        ld      (RWBK_StatusOR),a
        ld      a,d
        ld      (RWBK_TmpBank),a
        ld      (RWBK_TmpAddr),hl
        ld      (RWBK_TmpPtr),ix

        ld      a,4
        ld      (RWBK_LoopCount),a

RWBK_Read4Loop:
        ld      a,(RWBK_TmpBank)
        ld      d,a
        ld      hl,(RWBK_TmpAddr)
        call    RWBK_Peek
        call    RWBK_OrStatus

        push    de                  ; E = byte read
        ld      ix,(RWBK_TmpPtr)
        pop     de
        ld      (ix+0),e

        ld      hl,(RWBK_TmpAddr)
        inc     hl
        ld      (RWBK_TmpAddr),hl

        ld      ix,(RWBK_TmpPtr)
        inc     ix
        ld      (RWBK_TmpPtr),ix

        ld      hl,RWBK_LoopCount
        dec     (hl)
        jp      nz,RWBK_Read4Loop

        ld      a,(RWBK_StatusOR)
        ret

; ------------------------------------------------------------
; Write four bytes from IX buffer to bank/address.
; input D=Bank ID, HL=address, IX=source
; output A=OR of status bytes.

RWBK_Write4:
        xor     a
        ld      (RWBK_StatusOR),a
        ld      a,d
        ld      (RWBK_TmpBank),a
        ld      (RWBK_TmpAddr),hl
        ld      (RWBK_TmpPtr),ix

        ld      a,4
        ld      (RWBK_LoopCount),a

RWBK_Write4Loop:
        ld      ix,(RWBK_TmpPtr)
        ld      e,(ix+0)

        ld      a,(RWBK_TmpBank)
        ld      d,a
        ld      hl,(RWBK_TmpAddr)
        call    RWBK_Poke
        call    RWBK_OrStatus

        ld      hl,(RWBK_TmpAddr)
        inc     hl
        ld      (RWBK_TmpAddr),hl

        ld      ix,(RWBK_TmpPtr)
        inc     ix
        ld      (RWBK_TmpPtr),ix

        ld      hl,RWBK_LoopCount
        dec     (hl)
        jp      nz,RWBK_Write4Loop

        ld      a,(RWBK_StatusOR)
        ret

; ------------------------------------------------------------
; Write signature:
;   A5, BankID, BankID XOR FF, BankID + 3C
; input D=Bank ID, HL=address
; output A=OR status

RWBK_WriteSig4:
        ld      a,d
        ld      (RWBK_TmpBank),a
        ld      (RWBK_TmpAddr),hl

        ld      a,0A5h
        ld      (RWBK_Sig0),a

        ld      a,(RWBK_TmpBank)
        ld      (RWBK_Sig1),a

        xor     0FFh
        ld      (RWBK_Sig2),a

        ld      a,(RWBK_TmpBank)
        add     a,03Ch
        ld      (RWBK_Sig3),a

        ld      a,(RWBK_TmpBank)
        ld      d,a
        ld      hl,(RWBK_TmpAddr)
        ld      ix,RWBK_Sig0
        jp      RWBK_Write4

; ------------------------------------------------------------
; OR status into status accumulator.

RWBK_OrStatus:
        push    af
        ld      c,a
        ld      a,(RWBK_StatusOR)
        or      c
        ld      (RWBK_StatusOR),a
        pop     af
        ret

; ------------------------------------------------------------
; Library data.

RWBK_OK:            defb 0
RWBK_StApp:         defb 0
RWBK_AppStart:      defb 0
RWBK_AppCount:      defb 0
RWBK_AppSizePg:     defb 0

RWBK_StatusOR:      defb 0
RWBK_TmpBank:       defb 0
RWBK_TmpAddr:       defw 0
RWBK_TmpPtr:        defw 0
RWBK_LoopCount:     defb 0

RWBK_Sig0:          defb 0
RWBK_Sig1:          defb 0
RWBK_Sig2:          defb 0
RWBK_Sig3:          defb 0

; ------------------------------------------------------------
; End RWBANK.ASM
; ------------------------------------------------------------
