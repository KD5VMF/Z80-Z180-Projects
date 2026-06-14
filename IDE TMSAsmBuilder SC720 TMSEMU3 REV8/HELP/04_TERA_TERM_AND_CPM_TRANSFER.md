## Recommended Tera Term setup

Before pasting HEX text into CP/M, set Tera Term transmit delays.

In Tera Term:

```text
Setup -> Serial port
```

Set both transmit delay values to:

<p>
<span style="color:red; font-size:1.5em; font-weight:bold;">
1 ms/char<br>
1 ms/line
</span>
</p>

<p>
<span style="color:red; font-size:1.35em; font-weight:bold;">
IMPORTANT: If these 1 ms transmit delays are not set, the copy/paste HEX transfer will likely fail.
</span>
</p>

The SC720/Z80/Z180 CP/M system can miss characters if the HEX text is pasted too fast.
The 1 ms delay gives CP/M enough time to receive and write the text correctly.

If a machine still misses characters, increase the delay slightly.
