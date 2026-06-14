# Quick start

## 1. Install .NET

Install the .NET 8 SDK or newer on the Windows PC that will run the IDE.

## 2. Start the IDE

Double-click:

```text
FIRST_RUN.bat
```

or:

```text
run_gui.bat
```

## 3. Build the included template

Inside the IDE:

1. Click **Load Chess Template**.
2. Confirm the output name is `CHESLIB1.COM`.
3. Click **Build .COM + .HEX**.

## 4. Find your output

Latest output:

```text
TMSAsmBuilder/Out/
```

Clean timestamped project/build folder:

```text
TMSAsmBuilder/Builds/CHESLIB1_YYYYMMDD_HHMMSS/
```

That clean folder should contain only:

```text
CHESLIB1.ASM
CHESLIB1.HEX
```

## 5. Run on CP/M

Fast XMODEM way:

```text
C>XM R CHESLIB1.COM
C>CHESLIB1
```

Text HEX way:

```text
C>PIP CHESLIB1.HEX=CON:
```

Send the HEX file as text, press `Ctrl-Z`, then:

```text
C>LOAD CHESLIB1
C>CHESLIB1
```
