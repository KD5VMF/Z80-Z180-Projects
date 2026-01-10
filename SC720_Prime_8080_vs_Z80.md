# A Controlled Comparison of an 8080-Compatible and a Z80-Native Prime-Number LCD Demo on the SC720 Platform

**Date:** January 9, 2026  
**Platform:** SC720 (Z80 @ 7.3728 MHz)  
**Programs compared:** (1) 8080-compatible prime demo; (2) Z80-native prime demo  

---

## Abstract
This document presents a controlled, single-platform comparison between two functionally similar prime-number
demonstration programs that render results to an HD44780-compatible 16×2 LCD through the SC719/SC720-style 4-bit latch.
The first program is written in an 8080-compatible subset intended to run unmodified on multiple Intel-family 8-bit CPUs
(8080/8085) and the Z80. The second is a Z80-native implementation that leverages Z80-specific instructions to reduce
instruction count and improve loop efficiency. By executing both programs on the *same SC720 hardware* and *identical clock
frequency*, this study isolates differences attributable to instruction-set and code-structure choices rather than
hardware and oscillator variance. The document defines measurement methodology, normalization metrics, and threats to validity,
and provides reporting templates for reproducible performance characterization.

## 1. Introduction
Prime-number generation is a common microbenchmark for 8-bit systems because it exercises integer arithmetic, branching,
loop structure, and (when paired with display I/O) real-world latency constraints. The SC720 platform provides a stable test bed
for evaluating software choices: both an 8080-compatible program and a Z80-native program can execute on the same CPU and memory
subsystem, thereby removing confounds associated with cross-platform clocking and peripheral differences.

The central question is:

> **Given identical SC720 hardware and clock, how does a Z80-native implementation compare to an 8080-compatible implementation
for prime generation and LCD output?**

## 2. Hardware and Execution Environment
### 2.1 Hardware
- **Board:** SC720
- **CPU:** Z80
- **CPU clock:** **7.3728 MHz** (single-platform control condition)
- **Display:** HD44780-compatible LCD via SC719/SC720-style 4-bit latch

### 2.2 LCD electrical interface assumptions
Both programs assume the SC719/SC720 latch mapping:
- `PORT_LCD`: LCD control/data latch
- `bit2`: RS (0=command, 1=data)
- `bit3`: E (enable)
- `bit4..bit7`: D4..D7
- R/W tied low (write-only)

## 3. Software Artifacts
### 3.1 8080-compatible program (runs on Z80 for this comparison)
- Source: `LCDPRIME.ASM`
- Intel HEX: `LCDPRIME.HEX`
- Image address span: 0x0100..0x039B
- Image size (bytes): 668
- Source lines: 592

### 3.2 Z80-native program
- Source: `Z80-LCD-Primes.asm`
- Intel HEX: `Z80-LCD-Primes.hex`
- Image address span: 0x0100..0x03B8
- Image size (bytes): 697
- Source lines: 586

### 3.3 Tunable delay parameterization
Both programs include an explicit “speed knob” for human-readable updates (LCD pacing).
For benchmarking, this delay should be set to a minimal value or removed entirely (Section 5).

- 8080-compatible delay knob detected: PRIME_DELAY_OUTER = 01H
- Z80-native delay knob detected: PRIME_DELAY_OUTER = 01H

## 4. Architectural Differences: 8080-Compatible vs Z80-Native
### 4.1 Instruction-set capability (qualitative)
The Z80 is largely backward-compatible with the 8080 but extends it with additional instructions and addressing modes.
A Z80-native implementation can therefore reduce overhead in common patterns:
- Counted loops via **`DJNZ`**
- Short branches via **`JR`**
- Bit tests via **`BIT b,r`**
- 16-bit subtract/compare via **`SBC HL,DE`**
- More flexible register operations that reduce memory traffic

These improvements typically reduce static code size and dynamic instruction count for tight loops, particularly in:
- delay loops
- decimal conversion routines
- trial-division loops and divisor progression

### 4.2 Evidence of Z80-specific instruction usage in the Z80 program (heuristic)
The Z80-native source contains the following mnemonic occurrences (simple textual count):
- DJNZ: 11
- JR: 32
- BIT: 18
- SBC HL: 0
- OUT (: 0
- RL: 2

*Note:* these counts are a rough indicator of Z80-specific style; they are not a substitute for cycle-accurate profiling.

## 5. Experimental Methodology
### 5.1 Controlled variables
To ensure a valid comparison, the following variables are held constant:
- identical SC720 hardware
- identical CPU clock frequency (7.3728 MHz)
- identical LCD and port wiring
- identical terminal/loader procedure and memory placement (as applicable)

### 5.2 Dependent variables (what is measured)
Two families of metrics are recommended:

1) **User-visible update throughput**
- primes displayed per second (with a fixed delay constant)
- stability of display output (no corruption, no missed characters)

2) **Compute throughput (benchmark mode)**
- primes tested per second (delay minimized/removed)
- time to compute a fixed workload

### 5.3 Recommended benchmark workloads
To avoid measurement noise, the programs should be modified (or configured) to execute a *fixed workload* and then stop.

Preferred workloads:
- **Workload A:** “Find the first N primes” (e.g., N=1000), then halt.
- **Workload B:** “Find all primes ≤ MAX” (e.g., MAX=60000), then halt.

### 5.4 Timing instrumentation options
Any of the following methods can produce robust timing:
- toggle an output pin/LED at start and end; measure with a scope/logic analyzer
- emit start/end markers over serial and time externally
- use a stopwatch only if no instrumentation is available (least precise)

### 5.5 LCD I/O considerations
LCD updates are slow relative to CPU execution (command/data strobes + post-write delays).
If the goal is *compute throughput*, LCD writes should be minimized or gated (e.g., print every K-th prime) during benchmarking.
If the goal is *end-to-end demo performance*, LCD writes remain enabled.

## 6. Reporting Template (Results Section)
### 6.1 Configuration
- CPU clock: 7.3728 MHz
- Loader method: ___________________________
- LCD delays (init/write): ___________________
- PRIME_DELAY_OUTER: 8080=____  Z80=____
- Workload: A / B (circle)  with N=____ or MAX=____

### 6.2 Results table
| Program | Workload | Time (s) | Primes found | Primes/s | Notes |
|---|---|---:|---:|---:|---|
| 8080-compatible | | | | | |
| Z80-native | | | | | |

### 6.3 Derived comparisons
- Speedup factor (Z80 / 8080): ______ ×
- Percent improvement: ______ %

## 7. Discussion
A Z80-native implementation is expected to outperform an 8080-compatible implementation on the same hardware due to reduced loop overhead
(`DJNZ`), more efficient short branching (`JR`), and improved 16-bit arithmetic utilities (`SBC HL,DE`). However, end-to-end demo speed may
be dominated by LCD I/O delays rather than compute time. In that regime, performance differences may shrink unless LCD pacing is reduced.

## 8. Threats to Validity
- **LCD I/O dominates:** if LCD delays are large, CPU differences can be masked.
- **Different algorithmic structure:** even small differences in divisor-loop structure or decimal conversion affect results.
- **Loader placement / memory wait states:** different placement in RAM/ROM could change effective speed if wait states exist.
- **Measurement method:** stopwatch timing introduces human reaction error; pin toggling is preferred.
- **Thermal/voltage effects:** typically minor on these systems but should be acknowledged in repeated trials.

## 9. Conclusion
This comparison framework enables a defensible evaluation of 8080-compatible versus Z80-native implementations on a single SC720 platform.
By holding clock and hardware constant and focusing on fixed workloads with reliable timing instrumentation, the resulting measurements
can be reported in a reproducible form suitable for future regression testing and performance tuning.

---

## Appendix A: Files Used
- 8080-compatible: `LCDPRIME.ASM`, `LCDPRIME.HEX`
- Z80-native: `Z80-LCD-Primes.asm`, `Z80-LCD-Primes.hex`
