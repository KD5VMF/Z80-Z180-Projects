# Tera Term and CP/M transfer guide

This IDE gives you two ways to move a program to CP/M:

1. Send the `.COM` file directly with XMODEM.
2. Paste/send the `.HEX` file as text, then use CP/M `LOAD`.

## Method A: XMODEM `.COM` transfer

This is best when `XM.COM` or a compatible XMODEM receive program is available on CP/M.

### On CP/M

For the Balls demo:

```text
C>XM R BALLS.COM
```

The CP/M machine now waits for a file.

### In Tera Term

Use:

```text
File -> Transfer -> XMODEM -> Send...
```

Pick:

```text
TMSAsmBuilder/Out/BALLS.COM
```

or, if using the portable app folder:

```text
Portable_Windows_App/Out/BALLS.COM
```

### Run it

```text
C>BALLS
```

## Method B: Paste/send Intel HEX with PIP and LOAD

This is useful if XMODEM is not working yet.

### On CP/M

```text
C>PIP BALLS.HEX=CON:
```

CP/M is now accepting text from the console into `BALLS.HEX`.

### In the IDE

1. Build the program.
2. Click the **HEX Paste** tab.
3. Click **Copy HEX**.

### In Tera Term

Paste the HEX text, or send the `.HEX` file as a text file.

Recommended serial transmit delay:

```text
Setup -> Serial port -> Transmit delay: 5 ms/char and 50 ms/line
```

Some CP/M machines need more delay. If characters are missed, increase the delay.

### Finish the PIP input

When all HEX text has been sent, press:

```text
Ctrl-Z
```

That tells CP/M/PIP the console input file is finished.

### Convert HEX to COM

```text
C>LOAD BALLS
```

This should create:

```text
BALLS.COM
```

### Run it

```text
C>BALLS
```

## Which method should I use?

Use XMODEM when available. It is cleaner and transfers the exact binary.

Use HEX paste when:

- you do not have XMODEM on the CP/M disk,
- your serial transfer setup is not finished,
- you are debugging early file transfer,
- you want to copy/paste from the IDE quickly.

## Common CP/M commands

List files:

```text
C>DIR
```

Delete old output:

```text
C>ERA BALLS.COM
C>ERA BALLS.HEX
```

Run program:

```text
C>BALLS
```

Convert Intel HEX to COM:

```text
C>LOAD BALLS
```

Receive with XMODEM if `XM.COM` is present:

```text
C>XM R BALLS.COM
```

## Tera Term notes

Tera Term is just the terminal. The IDE does not control Tera Term directly.

For text paste to CP/M, slow down transmit speed with per-character and per-line delay. Old machines can lose characters if text is blasted too quickly.

For XMODEM, do not paste. Use Tera Term's XMODEM send menu.
