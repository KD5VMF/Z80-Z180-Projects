# Why the Source is Stripped

`HWTTERM3S.ASM` is the stripped source version.

It has comments and extra blank lines removed on purpose. The reason is practical: CP/M `ED` can run out of space when editing or holding larger source files on real retro systems.

The stripped file is easier to:

- paste over serial
- edit with `ED`
- store on small CP/M disks
- assemble with `ASM.COM`
- keep under the available TPA and editor workspace limits

Do not treat the stripped source as poor documentation. The documentation is separated into Markdown files so the real machine gets the compact source, while GitHub gets readable explanation.

Important documentation files:

- `README.md` gives the project overview
- `PORTS_AND_CODE.md` explains ports, HBIOS, and packet use
- `CODE_WALKTHROUGH.md` explains the source structure
- `WIRING.txt` explains the sensor wiring

The stripped source is the file to put on the CP/M machine:

```text
HWTTERM3S.ASM
```
