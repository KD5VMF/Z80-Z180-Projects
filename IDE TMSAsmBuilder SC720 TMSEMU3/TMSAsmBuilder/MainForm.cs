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
        var btnTemplate = Btn("Load Bounce Demo", (_, _) => LoadBounceDemo());
        var btnBuild = Btn("Build .COM + .HEX", async (_, _) => await BuildAsync());
        var btnLibs = Btn("Download J.B. Langston Libs", async (_, _) => await DownloadLibsAsync());
        var btnImportLibs = Btn("Import Lib Folder", (_, _) => ImportLibFolder());
        var btnOpenLibs = Btn("Open Lib Folder", (_, _) => OpenFolder(_libs));
        var btnAsm = Btn("Find sjasmplus.exe", (_, _) => PickAssembler());
        var btnFolders = Btn("Open Project Folder", (_, _) => OpenFolder(_root));
        var btnBuilds = Btn("Open Builds Folder", (_, _) => OpenFolder(_builds));
        var btnClear = Btn("Clear Log", (_, _) => _logBox.Clear());

        _fileBox.Width = 350;
        _fileBox.Text = string.Empty;
        _outBox.Width = 170;
        _outBox.Text = "OUTPUT.COM";
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
        _asmBox.Text = string.Empty;
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
        _status.Text = "Ready. No ASM loaded. Click New ASM, Open ASM, or Load Bounce Demo.";
        _status.BorderStyle = BorderStyle.Fixed3D;

        Controls.Add(split);
        Controls.Add(_status);
        Controls.Add(top);
        Log("This builds J.B. Langston-style Z80 source on Windows, then makes a CP/M .COM and Intel HEX for your SC720.");
        Log("No program is loaded on startup. Click New ASM, Open ASM, or Load Bounce Demo.");
        Log("Build folders stay clean with only final .ASM + .HEX; .COM goes to Out for XMODEM.");
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
            "Libs folder\r\n" +
            "===========\r\n\r\n" +
            "Shared ASM support files live here. Demo/user programs can include them by name:\r\n\r\n" +
            "  include \"tms.asm\"\r\n" +
            "  include \"z180.asm\"\r\n" +
            "  include \"utility.asm\"\r\n\r\n" +
            "Important files:\r\n" +
            "  tms.asm       TMS9918A/TMSEMU3 probe, setup, color, VRAM, sprite, tile, and text helpers.\r\n" +
            "  tmsfont.asm   Font data for text-mode programs.\r\n" +
            "  z180.asm      Z180 detection, clock, and TMS wait timing helpers.\r\n" +
            "  utility.asm   CP/M BDOS console, string, key, and small utility helpers.\r\n\r\n" +
            "The IDE copies these files only into a private temporary build folder so sjasmplus can resolve include statements.\r\n" +
            "Timestamped public build folders get only the generated .ASM and .HEX files.\r\n", Encoding.ASCII);

        File.WriteAllText(Path.Combine(_tools, "README.txt"),
            "Tools folder\r\n" +
            "============\r\n\r\n" +
            "This folder contains the assembler used by the IDE.\r\n\r\n" +
            "Bundled tool:\r\n" +
            "  sjasmplus.exe\r\n\r\n" +
            "Default IDE args:\r\n" +
            "  --raw=\"{out}\" \"{src}\"\r\n\r\n" +
            "Upstream:\r\n" +
            "  https://github.com/z00m128/sjasmplus/releases/latest\r\n", Encoding.ASCII);
    }

    private void NewAsm()
    {
        var result = MessageBox.Show(this,
            "Clear the editor and start a new ASM program?\n\nUnsaved text will be lost.",
            "New ASM", MessageBoxButtons.OKCancel, MessageBoxIcon.Question);
        if (result != DialogResult.OK) return;

        _asmBox.Clear();
        _fileBox.Text = Path.Combine(_work, "NEWPROG.ASM");
        _outBox.Text = "NEWPROG.COM";
        _logBox.Clear();
        Log("New blank ASM started. Type or paste your program, then Build .COM + .HEX.");
        _status.Text = "New blank ASM ready.";
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

    private void LoadBounceDemo()
    {
        var templatePath = Path.Combine(_root, "Templates", "BOUNCE.ASM");
        if (File.Exists(templatePath))
            _asmBox.Text = ToWinLines(File.ReadAllText(templatePath));
        else
            _asmBox.Text = ToWinLines(BounceTemplate());

        _fileBox.Text = Path.Combine(_work, "BOUNCE.ASM");
        _outBox.Text = "BOUNCE.COM";
        Log("Loaded Bounce Demo: four colored 16x16 sprites bouncing on a black TMS9918A/TMSEMU3 screen.");
        _status.Text = "Bounce Demo loaded. Click Build .COM + .HEX.";
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
            if (string.IsNullOrWhiteSpace(_asmBox.Text))
            {
                MessageBox.Show(this,
                    "No ASM program is loaded. Click New ASM and type/paste code, Open ASM, or Load Bounce Demo first.",
                    "No ASM loaded", MessageBoxButtons.OK, MessageBoxIcon.Information);
                _status.Text = "No ASM loaded.";
                return;
            }

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

    private static string NewTemplate() => string.Empty;

    private static string BounceTemplate() => @"; BOUNCE.ASM
; SC720 / Z80-Z180 + TMSEMU3 TMS9918A color sprite demo
;
; Paste/load this in ASM IDE.
;
; Needed LIB files in the same build folder or ASMIDE\Libs:
;   tms.asm
;   z180.asm
;   utility.asm
;
; No tmsfont.asm is needed. This uses sprite/tile mode only.
;
; Result: black screen with four colored 16x16 bouncing shapes.
; Press any CP/M console key to exit.
;
; NOTE: The TMS library files are Z80/sjasm-style source. This is not
;       for CP/M ASM.COM. Build it with the IDE/sjasmplus path.

        org     100h

Start:
        ld      (OldSP),sp
        ld      sp,Stack

        ; Set TMS wait timing correctly on a fast Z180.
        call    z180detect
        ld      e,0
        jp      nz,NoZ180
        call    z180getclk
NoZ180:
        call    TmsSetWait

        ; Find the TMS9918A / TMSEMU3 VDP.
        call    TmsProbe
        jp      z,NoTms

        ; Graphics I tile mode, blank black screen, sprites on top.
        call    TmsTile
        ld      a,TmsBlack
        call    TmsBackground
        call    ClearTileColors

        ; 16x16 sprites, not magnified.
        ld      a,TmsSprite32
        call    TmsSpriteConfig

        call    LoadSpritePatterns
        call    WriteSprites

MainLoop:
        call    WaitFrame
        call    MoveAll
        call    WriteSprites
        call    keypress
        jp      z,MainLoop

Exit:
        call    HideSprites
        ld      sp,(OldSP)
        rst     0

NoTms:
        ld      de,NoTmsMsg
        call    strout
        ld      sp,(OldSP)
        rst     0

; ------------------------------------------------------------
; Wait for a vertical blank edge. This keeps motion steady.
WaitFrame:
WaitNotV:
        call    TmsRegIn
        jp      m,WaitNotV
WaitV:
        call    TmsRegIn
        jp      p,WaitV
        ret

; ------------------------------------------------------------
; Color table black foreground / black background.
ClearTileColors:
        ld      de,(TmsColorAddr)
        ld      bc,TmsTileColorLen
        ld      a,11h                   ; black on black
        jp      TmsFill

; ------------------------------------------------------------
; Copy all 16x16 sprite pattern bytes into VRAM.
LoadSpritePatterns:
        ld      hl,SpritePatterns
        ld      de,(TmsSpritePatternAddr)
        ld      bc,SpritePatternsEnd-SpritePatterns
        jp      TmsWrite

; ------------------------------------------------------------
; Sprite attribute table format is Y, X, pattern, color.
WriteSprites:
        ld      de,(TmsSpriteAttrAddr)
        call    TmsWriteAddr

        ld      hl,Objects
        ld      b,ObjCount
WriteLoop:
        push    bc
        push    hl

        inc     hl                      ; object Y
        ld      a,(hl)
        call    TmsRamOut

        pop     hl                      ; object X
        ld      a,(hl)
        call    TmsRamOut

        push    hl
        ld      de,4                    ; object pattern number
        add     hl,de
        ld      a,(hl)
        call    TmsRamOut
        inc     hl                      ; object color
        ld      a,(hl)
        call    TmsRamOut
        pop     hl

        ld      de,ObjSize
        add     hl,de
        pop     bc
        djnz    WriteLoop

        ; 208 marks end-of-sprite list on TMS9918A.
        ld      a,208
        jp      TmsRamOut

HideSprites:
        ld      de,(TmsSpriteAttrAddr)
        call    TmsWriteAddr
        ld      a,208
        jp      TmsRamOut

; ------------------------------------------------------------
; Move every object in the object table.
MoveAll:
        ld      hl,Objects
        ld      b,ObjCount
MoveLoop:
        push    bc
        push    hl
        call    MoveOne
        pop     hl
        ld      de,ObjSize
        add     hl,de
        pop     bc
        djnz    MoveLoop
        ret

; ------------------------------------------------------------
; Move one object.
; Object bytes: X,Y,DX,DY,PATTERN,COLOR
; DX/DY are signed bytes: 1,2 forward and 255,254 = -1,-2.
;
; Entry: HL points to object X.
; Uses:  AF,BC,DE,HL.
MoveOne:
        ; ----- X -----
        ld      a,(hl)                  ; A = X
        inc     hl
        inc     hl                      ; HL = DX
        ld      c,(hl)                  ; C = DX
        add     a,c                     ; A = X + DX
        ld      b,a                     ; B = new X candidate
        cp      XMax+1
        jp      c,StoreX

        ; Out of range. Decide if it went under or over by DX sign.
        ld      a,c
        cp      80h
        jp      nc,XUnder
XOver:
        ld      b,XMax
        jp      FlipDX
XUnder:
        ld      b,0
FlipDX:
        xor     a
        sub     c                       ; A = -DX
        ld      (hl),a                  ; store flipped DX
StoreX:
        dec     hl
        dec     hl                      ; HL = X
        ld      (hl),b

        ; ----- Y -----
        inc     hl                      ; HL = Y
        ld      a,(hl)                  ; A = Y
        inc     hl
        inc     hl                      ; HL = DY
        ld      c,(hl)                  ; C = DY
        add     a,c                     ; A = Y + DY
        ld      b,a
        cp      YMax+1
        jp      c,StoreY

        ld      a,c
        cp      80h
        jp      nc,YUnder
YOver:
        ld      b,YMax
        jp      FlipDY
YUnder:
        ld      b,0
FlipDY:
        xor     a
        sub     c                       ; A = -DY
        ld      (hl),a                  ; store flipped DY
StoreY:
        dec     hl
        dec     hl                      ; HL = Y
        ld      (hl),b
        ret

; ------------------------------------------------------------
; Constants and object table.
XMax:   equ     240                     ; 256 - 16
YMax:   equ     176                     ; 192 - 16
ObjSize:equ     6
ObjCount:equ    4

Objects:
        ;  X    Y    DX   DY   PAT  COLOR
        defb    18,  20,   2,   1,   0, TmsCyan
        defb    80,  42,   1,   2,   4, TmsLightRed
        defb   150,  88, 255,   1,   8, TmsLightYellow
        defb   218, 138, 254, 255,  12, TmsMagenta

NoTmsMsg:
        defb    ""TMS9918A not found, aborting!$""

OldSP:  defw    0

; ------------------------------------------------------------
; 16x16 sprite patterns.
; Each 16x16 sprite uses four 8-byte patterns in this order:
; upper-left, lower-left, upper-right, lower-right.
;
; Pattern numbers for 16x16 sprites must start on 0,4,8,12...
SpritePatterns:

; Pattern 0: round ball
        defb    03h,0fh,1fh,3fh,7fh,7fh,0ffh,0ffh
        defb    0ffh,0ffh,7fh,7fh,3fh,1fh,0fh,03h
        defb    0c0h,0f0h,0f8h,0fch,0feh,0feh,0ffh,0ffh
        defb    0ffh,0ffh,0feh,0feh,0fch,0f8h,0f0h,0c0h

; Pattern 4: square box
        defb    0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
        defb    0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
        defb    0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
        defb    0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh

; Pattern 8: diamond
        defb    01h,03h,07h,0fh,1fh,3fh,7fh,0ffh
        defb    0ffh,7fh,3fh,1fh,0fh,07h,03h,01h
        defb    80h,0c0h,0e0h,0f0h,0f8h,0fch,0feh,0ffh
        defb    0ffh,0feh,0fch,0f8h,0f0h,0e0h,0c0h,80h

; Pattern 12: X shape
        defb    0c0h,0e0h,70h,38h,1ch,0eh,07h,03h
        defb    03h,07h,0eh,1ch,38h,70h,0e0h,0c0h
        defb    03h,07h,0eh,1ch,38h,70h,0e0h,0c0h
        defb    0c0h,0e0h,70h,38h,1ch,0eh,07h,03h

SpritePatternsEnd:

        defs    256,0
Stack:

        include ""tms.asm""
        include ""z180.asm""
        include ""utility.asm""

        end
";
}
