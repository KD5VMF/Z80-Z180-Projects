using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Drawing;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace TMSAsmBuilder;

public sealed class MainForm : Form
{
    private readonly string _root;
    private readonly string _libs;
    private readonly string _tools;
    private readonly string _out;
    private readonly string _work;
    private readonly string _builds;

    private readonly RichTextBox _asmBox = new();
    private readonly TextBox _logBox = new();
    private readonly TextBox _fileBox = new();
    private readonly TextBox _outBox = new();
    private readonly TextBox _assemblerBox = new();
    private readonly TextBox _argsBox = new();
    private readonly Label _status = new();

    private readonly System.Windows.Forms.Timer _colorTimer = new() { Interval = 180 };
    private bool _isColorizing;

    private static readonly Color IdeBack = Color.FromArgb(30, 30, 30);
    private static readonly Color IdeText = Color.FromArgb(220, 220, 220);
    private static readonly Color IdeComment = Color.FromArgb(87, 166, 74);
    private static readonly Color IdeString = Color.FromArgb(206, 145, 120);
    private static readonly Color IdeNumber = Color.FromArgb(181, 206, 168);
    private static readonly Color IdeOpcode = Color.FromArgb(86, 156, 214);
    private static readonly Color IdeDirective = Color.FromArgb(197, 134, 192);
    private static readonly Color IdeLabel = Color.FromArgb(78, 201, 176);

    private static readonly Regex StringRegex = new("\"(?:\"\"|[^\"\r\n])*\"|'(?:''|[^'\r\n])*'", RegexOptions.Compiled);
    private static readonly Regex NumberRegex = new(@"(?<![A-Za-z0-9_])(\$[0-9A-Fa-f]+|%[01]+|[0-9][0-9A-Fa-f]*[Hh]|0x[0-9A-Fa-f]+|[0-9]+)(?![A-Za-z0-9_])", RegexOptions.Compiled);

    private static readonly HashSet<string> AsmDirectives = new(StringComparer.OrdinalIgnoreCase)
    {
        "org", "include", "incbin", "equ", "defs", "ds", "defb", "db", "defw", "dw", "defm", "dm",
        "end", "macro", "endm", "if", "else", "endif", "repeat", "endrepeat"
    };

    private static readonly HashSet<string> Z80Opcodes = new(StringComparer.OrdinalIgnoreCase)
    {
        "adc", "add", "and", "bit", "call", "ccf", "cp", "cpd", "cpdr", "cpi", "cpir", "cpl",
        "daa", "dec", "di", "djnz", "ei", "ex", "exx", "halt", "im", "in", "inc", "ind", "indr",
        "ini", "inir", "jp", "jr", "ld", "ldd", "lddr", "ldi", "ldir", "neg", "nop", "or", "otdr",
        "otir", "out", "outd", "outi", "pop", "push", "res", "ret", "reti", "retn", "rl", "rla", "rlc",
        "rlca", "rld", "rr", "rra", "rrc", "rrca", "rrd", "rst", "sbc", "scf", "set", "sla", "sra",
        "srl", "sub", "xor"
    };

    public MainForm()
    {
        _root = AppContext.BaseDirectory;
        _libs = Path.Combine(_root, "Libs");
        _tools = Path.Combine(_root, "Tools");
        _out = Path.Combine(_root, "Out");
        _work = Path.Combine(_root, "Work");
        _builds = Path.Combine(_root, "Builds");
        Directory.CreateDirectory(_libs);
        Directory.CreateDirectory(_tools);
        Directory.CreateDirectory(_out);
        Directory.CreateDirectory(_work);
        Directory.CreateDirectory(_builds);
        EnsureReadmes();

        Text = "TMS9918A ASM Builder IDE for SC720 / RomWBW CP/M";
        Width = 1280;
        Height = 860;
        StartPosition = FormStartPosition.CenterScreen;
        TryLoadAppIcon();

        _colorTimer.Tick += (_, _) =>
        {
            _colorTimer.Stop();
            ColorizeAsm();
        };

        var top = new FlowLayoutPanel
        {
            Dock = DockStyle.Top,
            Height = 118,
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents = true,
            Padding = new Padding(8)
        };

        var btnNew = Btn("New ASM", (_, _) => NewAsm());
        var btnOpen = Btn("Open ASM", (_, _) => OpenAsm());
        var btnSave = Btn("Save ASM", (_, _) => SaveAsm());
        var btnTemplate = Btn("Load Chess Template", (_, _) => LoadTemplate());
        var btnBuild = Btn("Build .COM + .HEX", async (_, _) => await BuildAsync());
        var btnLibs = Btn("Download J.B. Langston Libs", async (_, _) => await DownloadLibsAsync());
        var btnImportLibs = Btn("Import Lib Folder", (_, _) => ImportLibFolder());
        var btnOpenLibs = Btn("Open Lib Folder", (_, _) => OpenFolder(_libs));
        var btnAsm = Btn("Find sjasmplus.exe", (_, _) => PickAssembler());
        var btnFolders = Btn("Open Project Folder", (_, _) => OpenFolder(_root));
        var btnBuilds = Btn("Open Builds Folder", (_, _) => OpenFolder(_builds));
        var btnClear = Btn("Clear Log", (_, _) => _logBox.Clear());

        _fileBox.Width = 350;
        _fileBox.Text = Path.Combine(_work, "CHESLIB1.ASM");
        _outBox.Width = 170;
        _outBox.Text = "CHESLIB1.COM";
        _assemblerBox.Width = 280;
        _assemblerBox.Text = FindDefaultAssembler();
        _argsBox.Width = 370;
        _argsBox.Text = "--raw=\"{out}\" \"{src}\"";

        top.Controls.AddRange(new Control[]
        {
            btnNew, btnOpen, btnSave, btnTemplate, btnBuild, btnLibs, btnImportLibs,
            btnOpenLibs, btnAsm, btnFolders, btnBuilds, btnClear,
            Label("ASM file:"), _fileBox,
            Label("Output .COM:"), _outBox,
            Label("Assembler:"), _assemblerBox,
            Label("Args:"), _argsBox
        });

        var split = new SplitContainer
        {
            Dock = DockStyle.Fill,
            Orientation = Orientation.Horizontal,
            SplitterDistance = 560
        };

        _asmBox.Multiline = true;
        _asmBox.AcceptsTab = true;
        _asmBox.ScrollBars = RichTextBoxScrollBars.Both;
        _asmBox.WordWrap = false;
        _asmBox.DetectUrls = false;
        _asmBox.BorderStyle = BorderStyle.None;
        _asmBox.Font = new Font("Consolas", 10);
        _asmBox.BackColor = IdeBack;
        _asmBox.ForeColor = IdeText;
        _asmBox.Dock = DockStyle.Fill;
        _asmBox.Text = ToWinLines(DefaultTemplate());
        _asmBox.TextChanged += (_, _) => QueueColorize();
        ColorizeAsm();

        _logBox.Multiline = true;
        _logBox.ScrollBars = ScrollBars.Both;
        _logBox.WordWrap = false;
        _logBox.ReadOnly = true;
        _logBox.Font = new Font("Consolas", 9);
        _logBox.Dock = DockStyle.Fill;

        split.Panel1.Controls.Add(_asmBox);
        split.Panel2.Controls.Add(_logBox);

        _status.Dock = DockStyle.Bottom;
        _status.Height = 24;
        _status.Text = "Ready. Drop ASM here. Libs stay shared; each build folder gets only the final .ASM and .HEX.";
        _status.BorderStyle = BorderStyle.Fixed3D;

        Controls.Add(split);
        Controls.Add(_status);
        Controls.Add(top);
        Log("This builds J.B. Langston-style Z80 source on Windows, then makes a CP/M .COM and Intel HEX for your SC720.");
        Log("New in this revision: IDE icon, ASM syntax colors, and clean build folders with only final .ASM + .HEX.");
    }

    private static Button Btn(string text, EventHandler onClick)
    {
        var b = new Button { Text = text, AutoSize = true, Margin = new Padding(4) };
        b.Click += onClick;
        return b;
    }

    private static Label Label(string text) => new() { Text = text, AutoSize = true, Margin = new Padding(10, 8, 2, 2) };

    private void TryLoadAppIcon()
    {
        try
        {
            var iconPath = Path.Combine(AppContext.BaseDirectory, "Assets", "TMSAsmBuilder.ico");
            if (File.Exists(iconPath)) Icon = new Icon(iconPath);
        }
        catch
        {
            // Icon failure should never stop the IDE from opening.
        }
    }

    private void QueueColorize()
    {
        if (_isColorizing) return;
        _colorTimer.Stop();
        _colorTimer.Start();
    }

    private void ColorizeAsm()
    {
        if (_isColorizing || _asmBox.IsDisposed) return;
        _isColorizing = true;

        var oldStart = _asmBox.SelectionStart;
        var oldLen = _asmBox.SelectionLength;
        var text = _asmBox.Text;

        _asmBox.SuspendLayout();
        try
        {
            _asmBox.SelectAll();
            _asmBox.SelectionColor = IdeText;
            _asmBox.SelectionBackColor = IdeBack;

            var pos = 0;
            while (pos < text.Length)
            {
                var nextLf = text.IndexOf('\n', pos);
                var lineEnd = nextLf >= 0 ? nextLf : text.Length;
                var lineLen = lineEnd - pos;
                if (lineLen > 0 && text[pos + lineLen - 1] == '\r') lineLen--;

                var line = text.Substring(pos, lineLen);
                ColorizeAsmLine(pos, line);

                if (nextLf < 0) break;
                pos = nextLf + 1;
            }
        }
        finally
        {
            if (oldStart <= _asmBox.TextLength)
                _asmBox.Select(oldStart, Math.Min(oldLen, _asmBox.TextLength - oldStart));
            _asmBox.SelectionColor = IdeText;
            _asmBox.ResumeLayout();
            _isColorizing = false;
        }
    }

    private void ColorizeAsmLine(int absoluteStart, string line)
    {
        if (line.Length == 0) return;

        var commentAt = FindCommentStart(line);
        var codeLen = commentAt >= 0 ? commentAt : line.Length;
        var code = codeLen > 0 ? line[..codeLen] : string.Empty;

        if (commentAt >= 0)
            PaintAsm(absoluteStart + commentAt, line.Length - commentAt, IdeComment);

        foreach (Match m in StringRegex.Matches(code))
            PaintAsm(absoluteStart + m.Index, m.Length, IdeString);

        foreach (Match m in NumberRegex.Matches(code))
            PaintAsm(absoluteStart + m.Index, m.Length, IdeNumber);

        var scan = 0;
        while (scan < code.Length && char.IsWhiteSpace(code[scan])) scan++;

        // Label at start of line:  Label:
        var colon = code.IndexOf(':', scan);
        if (colon > scan)
        {
            var possibleLabel = code[scan..colon].Trim();
            if (possibleLabel.Length > 0 && possibleLabel.All(c => char.IsLetterOrDigit(c) || c == '_' || c == '.'))
            {
                PaintAsm(absoluteStart + scan, colon - scan + 1, IdeLabel);
                scan = colon + 1;
                while (scan < code.Length && char.IsWhiteSpace(code[scan])) scan++;
            }
        }

        if (scan >= code.Length) return;
        var tokenStart = scan;
        while (scan < code.Length && (char.IsLetterOrDigit(code[scan]) || code[scan] == '_' || code[scan] == '.')) scan++;
        var token = code[tokenStart..scan].TrimStart('.');
        if (token.Length == 0) return;

        if (AsmDirectives.Contains(token))
            PaintAsm(absoluteStart + tokenStart, scan - tokenStart, IdeDirective);
        else if (Z80Opcodes.Contains(token))
            PaintAsm(absoluteStart + tokenStart, scan - tokenStart, IdeOpcode);
    }

    private void PaintAsm(int start, int length, Color color)
    {
        if (length <= 0) return;
        if (start < 0 || start >= _asmBox.TextLength) return;
        length = Math.Min(length, _asmBox.TextLength - start);
        _asmBox.Select(start, length);
        _asmBox.SelectionColor = color;
    }

    private static int FindCommentStart(string line)
    {
        var inDouble = false;
        var inSingle = false;

        for (var i = 0; i < line.Length; i++)
        {
            var c = line[i];
            if (c == '"' && !inSingle)
            {
                if (inDouble && i + 1 < line.Length && line[i + 1] == '"')
                {
                    i++;
                    continue;
                }
                inDouble = !inDouble;
            }
            else if (c == '\'' && !inDouble)
            {
                if (inSingle && i + 1 < line.Length && line[i + 1] == '\'')
                {
                    i++;
                    continue;
                }
                inSingle = !inSingle;
            }
            else if (c == ';' && !inDouble && !inSingle)
            {
                return i;
            }
        }

        return -1;
    }

    private static string ToWinLines(string s) => s.Replace("\r\n", "\n").Replace("\r", "\n").Replace("\n", Environment.NewLine);

    private void OpenFolder(string path)
    {
        Directory.CreateDirectory(path);
        Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
    }

    private void EnsureReadmes()
    {
        File.WriteAllText(Path.Combine(_libs, "README.txt"),
            "Put all J.B. Langston / TMSEMU3 support ASM files here.\r\n\r\n" +
            "Typical files:\r\n" +
            "  tms.asm\r\n" +
            "  TmsFont.asm\r\n" +
            "  z180.asm\r\n" +
            "  utility.asm\r\n\r\n" +
            "Build uses this shared Libs folder as support input. Timestamped build folders stay clean and only receive the final .ASM and .HEX.\r\n", Encoding.ASCII);

        File.WriteAllText(Path.Combine(_tools, "README.txt"),
            "Put sjasmplus.exe here.\r\n\r\nDownload: https://github.com/z00m128/sjasmplus/releases/latest\r\n", Encoding.ASCII);
    }

    private void NewAsm()
    {
        var result = MessageBox.Show(this,
            "Clear the editor and start a new ASM program?\n\nUnsaved text will be lost.",
            "New ASM", MessageBoxButtons.OKCancel, MessageBoxIcon.Question);
        if (result != DialogResult.OK) return;

        _asmBox.Text = ToWinLines(NewTemplate());
        _fileBox.Text = Path.Combine(_work, "NEWPROG.ASM");
        _outBox.Text = "NEWPROG.COM";
        _logBox.Clear();
        Log("New ASM started. Paste or type your program, set Output .COM, then Build .COM + .HEX.");
        _status.Text = "New ASM ready.";
    }

    private void OpenAsm()
    {
        using var dlg = new OpenFileDialog { Filter = "ASM files (*.asm)|*.asm|All files (*.*)|*.*", InitialDirectory = _work };
        if (dlg.ShowDialog(this) != DialogResult.OK) return;
        _fileBox.Text = dlg.FileName;
        _asmBox.Text = ToWinLines(File.ReadAllText(dlg.FileName));
        _outBox.Text = MakeComName(Path.GetFileNameWithoutExtension(dlg.FileName));
        Log("Opened " + dlg.FileName);
    }

    private string SaveAsm()
    {
        var path = _fileBox.Text.Trim();
        if (string.IsNullOrWhiteSpace(path))
        {
            using var dlg = new SaveFileDialog { Filter = "ASM files (*.asm)|*.asm|All files (*.*)|*.*", InitialDirectory = _work };
            if (dlg.ShowDialog(this) != DialogResult.OK) throw new OperationCanceledException("Save cancelled.");
            path = dlg.FileName;
            _fileBox.Text = path;
        }

        path = Path.GetFullPath(path);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, ToWinLines(_asmBox.Text), Encoding.ASCII);
        Log("Saved working ASM: " + path);
        return path;
    }

    private void LoadTemplate()
    {
        _asmBox.Text = ToWinLines(DefaultTemplate());
        _fileBox.Text = Path.Combine(_work, "CHESLIB1.ASM");
        _outBox.Text = "CHESLIB1.COM";
        Log("Loaded chess-board text template.");
    }

    private void PickAssembler()
    {
        using var dlg = new OpenFileDialog { Filter = "Assembler exe (*.exe)|*.exe|All files (*.*)|*.*", InitialDirectory = _tools };
        if (dlg.ShowDialog(this) != DialogResult.OK) return;
        _assemblerBox.Text = dlg.FileName;
        Log("Assembler set to: " + dlg.FileName);
    }

    private void ImportLibFolder()
    {
        using var dlg = new FolderBrowserDialog { Description = "Select a folder containing .ASM library files" };
        if (dlg.ShowDialog(this) != DialogResult.OK) return;

        var copied = 0;
        foreach (var f in Directory.GetFiles(dlg.SelectedPath, "*.asm", SearchOption.TopDirectoryOnly))
        {
            File.Copy(f, Path.Combine(_libs, Path.GetFileName(f)), true);
            copied++;
        }

        Log($"Imported {copied} ASM library file(s) into Libs from {dlg.SelectedPath}");
        foreach (var f in Directory.GetFiles(_libs, "*.asm").OrderBy(Path.GetFileName))
            Log("  Lib: " + Path.GetFileName(f));
    }

    private string FindDefaultAssembler()
    {
        string[] names = { "sjasmplus.exe", "sjasm.exe" };
        foreach (var n in names)
        {
            var local = Path.Combine(_tools, n);
            if (File.Exists(local)) return local;
        }
        var path = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
        foreach (var dir in path.Split(Path.PathSeparator).Where(Directory.Exists))
        {
            foreach (var n in names)
            {
                var p = Path.Combine(dir, n);
                if (File.Exists(p)) return p;
            }
        }
        return Path.Combine(_tools, "sjasmplus.exe");
    }

    private async Task DownloadLibsAsync()
    {
        try
        {
            _status.Text = "Downloading GitHub master zip...";
            Log("Downloading J.B. Langston TMS9918A examples from GitHub...");
            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(60) };
            var url = "https://github.com/jblang/TMS9918A/archive/refs/heads/master.zip";
            var zipBytes = await http.GetByteArrayAsync(url);
            var zipPath = Path.Combine(_root, "jblang_TMS9918A_master.zip");
            await File.WriteAllBytesAsync(zipPath, zipBytes);

            var temp = Path.Combine(_root, "_github_extract");
            if (Directory.Exists(temp)) Directory.Delete(temp, true);
            Directory.CreateDirectory(temp);
            ZipFile.ExtractToDirectory(zipPath, temp);

            var examples = Directory.GetDirectories(temp, "examples", SearchOption.AllDirectories).FirstOrDefault();
            if (examples == null) throw new InvalidOperationException("Could not find examples folder in downloaded zip.");

            var copied = 0;
            foreach (var f in Directory.GetFiles(examples, "*.asm", SearchOption.TopDirectoryOnly))
            {
                File.Copy(f, Path.Combine(_libs, Path.GetFileName(f)), true);
                copied++;
            }

            Directory.Delete(temp, true);
            Log($"Copied {copied} ASM files to Libs:");
            foreach (var f in Directory.GetFiles(_libs, "*.asm").OrderBy(Path.GetFileName)) Log("  " + Path.GetFileName(f));
            _status.Text = "Libs downloaded into Libs folder. Now build or put sjasmplus.exe in Tools.";
        }
        catch (Exception ex)
        {
            Log("DOWNLOAD FAILED: " + ex.Message);
            MessageBox.Show(this,
                "Download failed. You can still use the program: manually copy tms.asm, TmsFont.asm, z180.asm, and utility.asm into the Libs folder.",
                "Download failed", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            _status.Text = "Download failed. Manually copy libs into Libs folder.";
        }
    }

    private async Task BuildAsync()
    {
        string? tempDir = null;
        try
        {
            SaveAsm();
            var outName = SanitizeOutName(_outBox.Text.Trim());
            var baseName = Path.GetFileNameWithoutExtension(outName);
            var stamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
            var buildDir = Path.Combine(_builds, baseName + "_" + stamp);
            tempDir = Path.Combine(_work, "_build_tmp_" + baseName + "_" + stamp);
            var assembler = _assemblerBox.Text.Trim();

            if (!File.Exists(assembler))
            {
                MessageBox.Show(this, "Assembler not found. Put sjasmplus.exe in Tools, install it in PATH, or click Find sjasmplus.exe.",
                    "Missing assembler", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
            Directory.CreateDirectory(buildDir);
            Directory.CreateDirectory(_out);
            Directory.CreateDirectory(tempDir);

            // Support libraries are copied only into this private temp folder so include statements work.
            // The public timestamped build/project folder stays clean: final .ASM + final .HEX only.
            foreach (var f in Directory.GetFiles(_libs, "*.asm"))
                File.Copy(f, Path.Combine(tempDir, Path.GetFileName(f)), true);

            var publicAsm = Path.Combine(buildDir, Path.GetFileNameWithoutExtension(outName) + ".ASM");
            File.WriteAllText(publicAsm, ToWinLines(_asmBox.Text), Encoding.ASCII);

            var tempAsm = Path.Combine(tempDir, Path.GetFileName(publicAsm));
            File.Copy(publicAsm, tempAsm, true);

            var tempCom = Path.Combine(tempDir, outName);
            if (File.Exists(tempCom)) File.Delete(tempCom);

            var args = _argsBox.Text.Replace("{src}", tempAsm).Replace("{out}", tempCom);
            Log("--- BUILD START ---");
            Log("Clean build folder: " + buildDir);
            Log("Final ASM: " + publicAsm);
            Log("Internal assembler work folder: " + tempDir);
            Log("Temp COM: " + tempCom);
            Log("Assembler: " + assembler);
            Log("Args: " + args);

            var psi = new ProcessStartInfo(assembler, args)
            {
                WorkingDirectory = tempDir,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using var p = Process.Start(psi)!;
            var stdout = await p.StandardOutput.ReadToEndAsync();
            var stderr = await p.StandardError.ReadToEndAsync();
            await p.WaitForExitAsync();
            if (!string.IsNullOrWhiteSpace(stdout)) Log(stdout.TrimEnd());
            if (!string.IsNullOrWhiteSpace(stderr)) Log(stderr.TrimEnd());
            Log("Exit code: " + p.ExitCode);

            if (!File.Exists(tempCom))
            {
                var rawOut = Directory.GetFiles(tempDir, "*.out").FirstOrDefault();
                if (rawOut != null) File.Copy(rawOut, tempCom, true);
            }

            if (File.Exists(tempCom))
            {
                var hexName = Path.GetFileNameWithoutExtension(outName).ToUpperInvariant() + ".HEX";
                var publicHex = Path.Combine(buildDir, hexName);
                WriteIntelHexFromCom(tempCom, publicHex);

                var latestCom = Path.Combine(_out, outName);
                var latestHex = Path.Combine(_out, hexName);
                var latestAsm = Path.Combine(_out, Path.GetFileName(publicAsm));
                File.Copy(tempCom, latestCom, true);
                File.Copy(publicHex, latestHex, true);
                File.Copy(publicAsm, latestAsm, true);

                var len = new FileInfo(tempCom).Length;
                Log("SUCCESS: temp .COM built (" + len + " bytes) and converted to Intel HEX.");
                Log("Clean project folder contains only:");
                Log("  " + publicAsm);
                Log("  " + publicHex);
                Log("Latest .COM for XMODEM was copied to Out: " + latestCom);
                Log("PIP method: PIP " + hexName + "=CON:  then LOAD " + Path.GetFileNameWithoutExtension(outName).ToUpperInvariant());
                Log("XM method:  XM R " + outName.ToUpperInvariant() + " using the Out folder copy");
                _status.Text = "Built clean .ASM + .HEX folder " + Path.GetFileName(buildDir) + "; .COM is in Out.";
                MessageBox.Show(this,
                    "Built clean .ASM + .HEX output.\n\nBuild folder only contains the new ASM and HEX files:\n" + buildDir + "\n\nLatest .COM copy is in Out for XM if needed.\n\nPIP/LOAD commands:\nPIP " + hexName + "=CON:\nLOAD " + Path.GetFileNameWithoutExtension(outName).ToUpperInvariant(),
                    "Build complete", MessageBoxButtons.OK, MessageBoxIcon.Information);
                OpenFolder(buildDir);
            }
            else
            {
                Log("FAILED: no .COM output was created in the internal assembler work folder. Check the log and assembler argument template.");
                _status.Text = "Build failed. See log.";
            }
            Log("--- BUILD END ---");
        }
        catch (OperationCanceledException)
        {
            Log("Build cancelled.");
        }
        catch (Exception ex)
        {
            Log("BUILD ERROR: " + ex);
            MessageBox.Show(this, ex.Message, "Build error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            _status.Text = "Build error.";
        }
        finally
        {
            if (!string.IsNullOrWhiteSpace(tempDir))
            {
                try
                {
                    if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
                }
                catch (Exception cleanupEx)
                {
                    Log("Temp cleanup warning: " + cleanupEx.Message);
                }
            }
        }
    }

    private static void WriteIntelHexFromCom(string comPath, string hexPath)
    {
        var data = File.ReadAllBytes(comPath);
        var sb = new StringBuilder();
        const int baseAddress = 0x0100;
        const int recordSize = 16;

        if (data.Length > 0xFF00)
            throw new InvalidOperationException("COM file is too large to fit in a normal CP/M Intel HEX image starting at 0100h.");

        for (var offset = 0; offset < data.Length; offset += recordSize)
        {
            var count = Math.Min(recordSize, data.Length - offset);
            var address = baseAddress + offset;
            byte checksum = 0;
            checksum += (byte)count;
            checksum += (byte)((address >> 8) & 0xFF);
            checksum += (byte)(address & 0xFF);
            checksum += 0x00;

            sb.Append(':');
            sb.Append(count.ToString("X2"));
            sb.Append(address.ToString("X4"));
            sb.Append("00");

            for (var i = 0; i < count; i++)
            {
                var b = data[offset + i];
                checksum += b;
                sb.Append(b.ToString("X2"));
            }

            var finalChecksum = (byte)(0 - checksum);
            sb.Append(finalChecksum.ToString("X2"));
            sb.Append("\r\n");
        }

        sb.Append(":00000001FF\r\n");
        File.WriteAllText(hexPath, sb.ToString(), Encoding.ASCII);
    }

    private static string SanitizeOutName(string name)
    {
        if (string.IsNullOrWhiteSpace(name)) name = "OUTPUT.COM";
        name = Path.GetFileName(name).ToUpperInvariant();
        foreach (var bad in Path.GetInvalidFileNameChars()) name = name.Replace(bad, '_');
        if (!name.EndsWith(".COM", StringComparison.OrdinalIgnoreCase)) name += ".COM";

        var stem = Path.GetFileNameWithoutExtension(name);
        var ext = Path.GetExtension(name).TrimStart('.');
        stem = new string(stem.Where(c => char.IsLetterOrDigit(c) || c == '_').ToArray());
        if (stem.Length == 0) stem = "OUTPUT";
        if (stem.Length > 8) stem = stem[..8];
        return stem.ToUpperInvariant() + "." + ext.ToUpperInvariant();
    }

    private static string MakeComName(string stem)
    {
        stem = new string(stem.ToUpperInvariant().Where(c => char.IsLetterOrDigit(c) || c == '_').ToArray());
        if (stem.Length == 0) stem = "OUTPUT";
        if (stem.Length > 8) stem = stem[..8];
        return stem + ".COM";
    }

    private void Log(string msg)
    {
        _logBox.AppendText(msg + Environment.NewLine);
    }

    private static string NewTemplate() => @"; NEWPROG.ASM
; Paste a J.B. Langston-style Z80/TMS9918A program here.
; Keep support files in the Libs folder.
; Build .COM + .HEX makes a fresh folder under Builds with only final .ASM and .HEX.

        org 100h

Start:
        ; your code here
        rst     0
";

    private static string DefaultTemplate() => @"; CHESLIB1.ASM
; Simple J.B. Langston TMS9918A-library test for CP/M .COM.
; Build on Windows with sjasmplus, then send CHESLIB1.HEX by PIP/LOAD or CHESLIB1.COM by XM.

        org 100h

        ld      (OldSP),sp
        ld      sp,Stack

        call    z180detect
        ld      e,0
        jp      nz,NoZ180
        call    z180getclk
NoZ180:
        call    TmsSetWait
        call    TmsProbe
        jp      z,NoTms

        ld      hl,TmsFont
        call    TmsTextMode
        ld      a,TmsDarkBlue
        call    TmsBackground
        ld      a,TmsWhite
        call    TmsTextColor

        call    DrawScreen
Hold:
        jp      Hold

DrawScreen:
        ld      a,9
        ld      e,1
        call    TmsTextPos
        ld      hl,Title
        call    TmsStrOut

        ld      a,14
        ld      e,4
        call    TmsTextPos
        ld      hl,Row8
        call    TmsStrOut
        ld      a,14
        ld      e,5
        call    TmsTextPos
        ld      hl,Row7
        call    TmsStrOut
        ld      a,14
        ld      e,6
        call    TmsTextPos
        ld      hl,Row6
        call    TmsStrOut
        ld      a,14
        ld      e,7
        call    TmsTextPos
        ld      hl,Row5
        call    TmsStrOut
        ld      a,14
        ld      e,8
        call    TmsTextPos
        ld      hl,Row4
        call    TmsStrOut
        ld      a,14
        ld      e,9
        call    TmsTextPos
        ld      hl,Row3
        call    TmsStrOut
        ld      a,14
        ld      e,10
        call    TmsTextPos
        ld      hl,Row2
        call    TmsStrOut
        ld      a,14
        ld      e,11
        call    TmsTextPos
        ld      hl,Row1
        call    TmsStrOut

        ld      a,11
        ld      e,13
        call    TmsTextPos
        ld      hl,Files
        call    TmsStrOut

        ld      a,7
        ld      e,18
        call    TmsTextPos
        ld      hl,Note
        call    TmsStrOut
        ret

NoTmsMessage:
        defb    ""TMS9918A not found, aborting!$""
NoTms:
        ld      de,NoTmsMessage
        call    strout
        ld      sp,(OldSP)
        rst     0

TmsFont:
        include ""TmsFont.asm""
        include ""tms.asm""
        include ""z180.asm""
        include ""utility.asm""

Title:  defb    ""SC720 TMSEMU3 CHESS TEST"",0
Row8:   defb    ""8  r n b q k b n r"",0
Row7:   defb    ""7  p p p p p p p p"",0
Row6:   defb    ""6  . . . . . . . ."",0
Row5:   defb    ""5  . . . . . . . ."",0
Row4:   defb    ""4  . . . . . . . ."",0
Row3:   defb    ""3  . . . . . . . ."",0
Row2:   defb    ""2  P P P P P P P P"",0
Row1:   defb    ""1  R N B Q K B N R"",0
Files:  defb    ""   a b c d e f g h"",0
Note:   defb    ""Library build OK. Next: animate pieces."",0

OldSP:  defw    0
        defs    128
Stack:
";
}
