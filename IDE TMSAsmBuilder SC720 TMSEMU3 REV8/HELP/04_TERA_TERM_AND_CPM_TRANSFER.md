# Tera Term and CP/M HEX Transfer Guide

This IDE moves programs to CP/M by copying the generated Intel HEX text and sending it through Tera Term.

The normal workflow is:

1. Build the program in the IDE.
2. Open the **HEX Paste** tab.
3. Click **Copy HEX**.
4. Use CP/M `PIP` to capture the pasted HEX text.
5. Use CP/M `LOAD` to convert the HEX file into a `.COM` program.
6. Run the program.

---

## Recommended Tera Term setup

Before pasting HEX text into CP/M, set Tera Term transmit delays.

In Tera Term:

```text
Setup -> Serial port
```

Set both transmit delay values to:

```text
1 ms/char
1 ms/line
```

This is very important.

The SC720/Z80/Z180 CP/M system can miss characters if the HEX text is pasted too fast. The 1 ms delay gives CP/M enough time to receive and write the text correctly.

If a machine still misses characters, increase the delay slightly.

---

## Method A: Copy HEX from the IDE and use PIP

This is the main recommended method.

### On CP/M

For the Balls demo:

```text
C>PIP BALLS.HEX=CON:
```

CP/M is now accepting text from the console and saving it into:

```text
BALLS.HEX
```

### In the IDE

1. Build the program.
2. Click the **HEX Paste** tab.
3. Click **Copy HEX**.

### In Tera Term

Paste the HEX text into the CP/M console.

Because Tera Term has the transmit delay set, the HEX text should feed into CP/M safely instead of being sent too fast.

### Finish the PIP input

When all HEX text has been pasted, press:

```text
Ctrl-Z
```

That tells CP/M/PIP that the console input file is finished.

You should return to the CP/M prompt.

---

## Convert HEX to COM

After the HEX file is saved, use CP/M `LOAD`:

```text
C>LOAD BALLS
```

This reads:

```text
BALLS.HEX
```

and creates:

```text
BALLS.COM
```

---

## Run the program

```text
C>BALLS
```

---

## Method B: Use ED to create or edit the HEX file

You can also use CP/M `ED` to create the HEX file manually.

Start ED with:

```text
C>ED BALLS.HEX
```

Then enter insert mode:

```text
I
```

Paste the HEX text from the IDE into ED.

When finished, press:

```text
Ctrl-Z
```

Then save and exit ED with:

```text
E
```

Now convert the file with:

```text
C>LOAD BALLS
```

Then run it:

```text
C>BALLS
```

---

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

Capture HEX text from the console:

```text
C>PIP BALLS.HEX=CON:
```

Convert Intel HEX to COM:

```text
C>LOAD BALLS
```

Run program:

```text
C>BALLS
```

---

## Notes

Tera Term is only the terminal. The IDE does not control Tera Term directly.

The IDE makes the HEX text easy to copy. CP/M receives that text through the console and saves it as a `.HEX` file.

The important part is slowing down the paste in Tera Term. Use:

```text
1 ms/char
1 ms/line
```

That delay keeps the transfer reliable on older CP/M hardware.
