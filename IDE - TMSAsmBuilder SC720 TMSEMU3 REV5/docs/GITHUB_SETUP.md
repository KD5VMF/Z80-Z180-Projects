# GitHub Setup

## Suggested repository name

```text
TMSAsmBuilder-SC720-TMSEMU3
```

## Suggested description

```text
Windows IDE for building Z80/TMS9918A CP/M programs for SC720/TMSEMU3. Builds .COM and Intel HEX so you can PIP, LOAD, and run on real RomWBW CP/M hardware.
```

## Suggested topics

```text
z80
z180
cpm
romwbw
sc720
tms9918a
tmsemu3
rc2014
sjasmplus
intel-hex
winforms
retrocomputing
```

## First push with GitHub CLI

From the repo root:

```bat
git init
git add .
git commit -m "Initial TMS ASM Builder IDE release"
gh repo create KD5VMF/TMSAsmBuilder-SC720-TMSEMU3 --public --source=. --remote=origin --push
```

## First push without GitHub CLI

Create an empty GitHub repo in the browser, then run:

```bat
git init
git add .
git commit -m "Initial TMS ASM Builder IDE release"
git branch -M main
git remote add origin https://github.com/KD5VMF/TMSAsmBuilder-SC720-TMSEMU3.git
git push -u origin main
```

## Release zip idea

After testing on Windows, publish a portable folder:

```bat
publish_portable.bat
```

Zip this folder as a release asset:

```text
Release\TMSAsmBuilder_Portable
```

Then users can download the portable release instead of building the source.
