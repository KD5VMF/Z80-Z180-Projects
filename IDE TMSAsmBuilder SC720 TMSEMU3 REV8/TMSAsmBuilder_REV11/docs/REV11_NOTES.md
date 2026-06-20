# REV11 implementation notes

REV11 restores ASM editor color in a safer way than the early live highlighter.

## Syntax color groups

The editor highlights:

- comments
- quoted strings
- labels
- assembler directives
- Z80/Z180 mnemonics
- registers
- numbers

## Scroll stability

The highlighter is debounced. It waits for typing to pause before recoloring, suspends redraw, remembers the caret/selection, remembers the RichTextBox scroll position, recolors, restores selection, restores the scroll position, then resumes redraw.

This is meant to keep the nice colors without bringing back the old problem where the code window jumped upward while scrolling or editing.

## Large files

Large ASM files still load with a progress screen. Full coloring is skipped above the configured size/line limits so the IDE stays responsive.

## Default startup

First start loads `Templates\HELLO.ASM`, which builds directly into `HELLO.COM` and `HELLO.HEX`.
