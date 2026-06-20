using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;

namespace TMSAsmBuilder;

public sealed partial class MainForm : Form
{
    private const string AppTitle = "TMS ASM Builder REV10";
    private const int LargeFileThresholdBytes = 64 * 1024;
    private const int MaxAutoColorizeChars = 180 * 1024;
    private const int MaxAutoColorizeLines = 3500;
    private const int IntelHexBaseAddress = 0x0100;

    private readonly string _repoRoot;
    private readonly string _toolsDir;
    private readonly string _libsDir;
    private readonly string _templatesDir;
    private readonly string _workDir;
    private readonly string _buildsDir;
    private readonly string _outDir;

    private readonly RichTextBox _asmEditor = new();
    private readonly RichTextBox _hexViewer = new();
    private readonly RichTextBox _logBox = new();
    private readonly TextBox _programNameBox = new();
    private readonly Label _statusLabel = new();
    private readonly ProgressBar _buildProgress = new();
    private readonly System.Windows.Forms.Timer _colorizeTimer = new();

    private readonly Button _newButton = new();
    private readonly Button _openButton = new();
    private readonly Button _saveButton = new();
    private readonly Button _buildButton = new();
    private readonly Button _cancelButton = new();
    private readonly Button _copyHexButton = new();
    private readonly Button _openOutButton = new();
    private readonly Button _openBuildsButton = new();
    private readonly Button _openWorkButton = new();
    private readonly Button _openLibsButton = new();
    private readonly Button _templateButton = new();
    private readonly Button _clearLogButton = new();

    private string? _currentFile;
    private bool _dirty;
    private bool _suppressTextChanged;
    private CancellationTokenSource? _buildCancellation;

    private static readonly Regex TokenRegex = new(
        @"(?<comment>;.*$)|(?<string>""(?:[^""]|"")*"")|(?<label>^[A-Za-z_.$@?][A-Za-z0-9_.$@?]*:)|(?<directive>\b(org|end|include|equ|db|dw|ds|defb|defw|defs|macro|endm|if|else|endif)\b)|(?<number>\b(?:[0-9A-Fa-f]+h|0x[0-9A-Fa-f]+|[01]+b|\d+)\b)",
        RegexOptions.Compiled | RegexOptions.Multiline | RegexOptions.IgnoreCase);

    public MainForm()
    {
        _repoRoot = LocateRepoRoot();
        _toolsDir = Path.Combine(_repoRoot, "Tools");
        _libsDir = Path.Combine(_repoRoot, "Libs");
        _templatesDir = Path.Combine(_repoRoot, "Templates");
        _workDir = Path.Combine(_repoRoot, "Work");
        _buildsDir = Path.Combine(_repoRoot, "Builds");
        _outDir = Path.Combine(_repoRoot, "Out");

        EnsureRepoFolders();
        BuildUi();
        WireEvents();

        _colorizeTimer.Interval = 450;
        _colorizeTimer.Tick += (_, _) =>
        {
            _colorizeTimer.Stop();
            ColorizeAsmEditorSafe();
        };

        Shown += async (_, _) => await LoadStartupTemplateAsync();
    }

    private void BuildUi()
    {
        Text = AppTitle;
        Width = 1280;
        Height = 820;
        MinimumSize = new Size(980, 620);
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(18, 20, 24);
        ForeColor = Color.Gainsboro;
        Font = new Font("Segoe UI", 9.5F);

        TrySetIcon();

        var topPanel = new Panel
        {
            Dock = DockStyle.Top,
            Height = 84,
            BackColor = Color.FromArgb(28, 31, 36),
            Padding = new Padding(8)
        };

        var title = new Label
        {
            Text = "TMS ASM Builder REV10  •  SC720 / SC700 / Z80-Z180 / TMSEMU3",
            AutoSize = false,
            Left = 12,
            Top = 8,
            Width = 720,
            Height = 24,
            ForeColor = Color.White,
            Font = new Font("Segoe UI", 11F, FontStyle.Bold)
        };
        topPanel.Controls.Add(title);

        ConfigureButton(_newButton, "New", 12, 42, 72);
        ConfigureButton(_openButton, "Open ASM", 90, 42, 92);
        ConfigureButton(_saveButton, "Save", 188, 42, 72);
        ConfigureButton(_templateButton, "Template", 266, 42, 88);
        ConfigureButton(_buildButton, "Build COM+HEX", 360, 42, 126);
        ConfigureButton(_cancelButton, "Cancel", 492, 42, 76);
        ConfigureButton(_copyHexButton, "Copy HEX", 574, 42, 88);
        ConfigureButton(_openOutButton, "Out", 668, 42, 62);
        ConfigureButton(_openBuildsButton, "Builds", 736, 42, 76);
        ConfigureButton(_openWorkButton, "Work", 818, 42, 66);
        ConfigureButton(_openLibsButton, "Libs", 890, 42, 62);
        ConfigureButton(_clearLogButton, "Clear Log", 958, 42, 86);
        _cancelButton.Enabled = false;

        var programLabel = new Label
        {
            Text = "CP/M name:",
            AutoSize = false,
            Left = 750,
            Top = 9,
            Width = 76,
            Height = 23,
            TextAlign = ContentAlignment.MiddleRight,
            ForeColor = Color.Gainsboro
        };
        _programNameBox.Left = 832;
        _programNameBox.Top = 7;
        _programNameBox.Width = 110;
        _programNameBox.Height = 24;
        _programNameBox.CharacterCasing = CharacterCasing.Upper;
        _programNameBox.BackColor = Color.FromArgb(38, 42, 48);
        _programNameBox.ForeColor = Color.White;
        _programNameBox.BorderStyle = BorderStyle.FixedSingle;
        topPanel.Controls.Add(programLabel);
        topPanel.Controls.Add(_programNameBox);

        topPanel.Controls.AddRange(new Control[]
        {
            _newButton, _openButton, _saveButton, _templateButton, _buildButton, _cancelButton, _copyHexButton,
            _openOutButton, _openBuildsButton, _openWorkButton, _openLibsButton, _clearLogButton
        });

        var mainSplit = new SplitContainer
        {
            Dock = DockStyle.Fill,
            Orientation = Orientation.Vertical,
            SplitterDistance = 750,
            BackColor = Color.FromArgb(18, 20, 24)
        };

        var leftSplit = new SplitContainer
        {
            Dock = DockStyle.Fill,
            Orientation = Orientation.Horizontal,
            SplitterDistance = 500,
            BackColor = Color.FromArgb(18, 20, 24)
        };

        ConfigureEditor(_asmEditor, "Consolas");
        ConfigureViewer(_logBox, "Consolas");
        ConfigureViewer(_hexViewer, "Consolas");

        var asmPanel = WrapWithHeader("ASM SOURCE", _asmEditor);
        var logPanel = WrapWithHeader("BUILD LOG", _logBox);
        var hexPanel = WrapWithHeader("LATEST INTEL HEX", _hexViewer);

        leftSplit.Panel1.Controls.Add(asmPanel);
        leftSplit.Panel2.Controls.Add(logPanel);
        mainSplit.Panel1.Controls.Add(leftSplit);
        mainSplit.Panel2.Controls.Add(hexPanel);

        var bottomPanel = new Panel
        {
            Dock = DockStyle.Bottom,
            Height = 30,
            BackColor = Color.FromArgb(28, 31, 36),
            Padding = new Padding(8, 5, 8, 5)
        };
        _statusLabel.Dock = DockStyle.Fill;
        _statusLabel.Text = "Ready";
        _statusLabel.ForeColor = Color.Gainsboro;
        _buildProgress.Dock = DockStyle.Right;
        _buildProgress.Width = 180;
        _buildProgress.Minimum = 0;
        _buildProgress.Maximum = 100;
        _buildProgress.Value = 0;
        bottomPanel.Controls.Add(_statusLabel);
        bottomPanel.Controls.Add(_buildProgress);

        Controls.Add(mainSplit);
        Controls.Add(bottomPanel);
        Controls.Add(topPanel);
    }

    private static void ConfigureButton(Button button, string text, int left, int top, int width)
    {
        button.Text = text;
        button.Left = left;
        button.Top = top;
        button.Width = width;
        button.Height = 29;
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderColor = Color.FromArgb(78, 86, 100);
        button.FlatAppearance.MouseOverBackColor = Color.FromArgb(55, 64, 80);
        button.BackColor = Color.FromArgb(40, 45, 54);
        button.ForeColor = Color.White;
        button.UseVisualStyleBackColor = false;
    }

    private static void ConfigureEditor(RichTextBox box, string fontName)
    {
        box.Dock = DockStyle.Fill;
        box.BorderStyle = BorderStyle.None;
        box.BackColor = Color.FromArgb(12, 13, 16);
        box.ForeColor = Color.Gainsboro;
        box.Font = new Font(fontName, 10.5F);
        box.AcceptsTab = true;
        box.WordWrap = false;
        box.HideSelection = false;
        box.DetectUrls = false;
    }

    private static void ConfigureViewer(RichTextBox box, string fontName)
    {
        ConfigureEditor(box, fontName);
        box.ReadOnly = true;
        box.BackColor = Color.FromArgb(16, 18, 22);
    }

    private static Panel WrapWithHeader(string headerText, Control child)
    {
        var panel = new Panel { Dock = DockStyle.Fill, Padding = new Padding(0) };
        var header = new Label
        {
            Dock = DockStyle.Top,
            Height = 24,
            Text = "  " + headerText,
            BackColor = Color.FromArgb(35, 39, 46),
            ForeColor = Color.White,
            TextAlign = ContentAlignment.MiddleLeft,
            Font = new Font("Segoe UI", 9F, FontStyle.Bold)
        };
        panel.Controls.Add(child);
        panel.Controls.Add(header);
        return panel;
    }

    private void WireEvents()
    {
        _newButton.Click += async (_, _) => await NewFileAsync();
        _openButton.Click += async (_, _) => await OpenFileFromDialogAsync();
        _saveButton.Click += async (_, _) => await SaveFileAsync();
        _templateButton.Click += async (_, _) => await LoadTemplateFromDialogAsync();
        _buildButton.Click += async (_, _) => await BuildAsync();
        _cancelButton.Click += (_, _) => _buildCancellation?.Cancel();
        _copyHexButton.Click += (_, _) => CopyHexToClipboard();
        _openOutButton.Click += (_, _) => OpenFolder(_outDir);
        _openBuildsButton.Click += (_, _) => OpenFolder(_buildsDir);
        _openWorkButton.Click += (_, _) => OpenFolder(_workDir);
        _openLibsButton.Click += (_, _) => OpenFolder(_libsDir);
        _clearLogButton.Click += (_, _) => _logBox.Clear();

        _asmEditor.TextChanged += (_, _) =>
        {
            if (_suppressTextChanged) return;
            _dirty = true;
            UpdateTitle();
            ScheduleColorize();
        };
    }

    private void EnsureRepoFolders()
    {
        Directory.CreateDirectory(_toolsDir);
        Directory.CreateDirectory(_libsDir);
        Directory.CreateDirectory(_templatesDir);
        Directory.CreateDirectory(_workDir);
        Directory.CreateDirectory(_buildsDir);
        Directory.CreateDirectory(_outDir);
    }

    private async Task LoadStartupTemplateAsync()
    {
        var template = Path.Combine(_templatesDir, "NEWPROG.ASM");
        if (File.Exists(template))
        {
            await LoadTextIntoEditorAsync(template, markAsCurrentFile: false);
            _currentFile = null;
            _dirty = false;
            _programNameBox.Text = "NEWPROG";
            UpdateTitle();
            Log("REV10 ready. Large files load with a real progress screen. Builds run on a background task.", LogKind.Success);
        }
        else
        {
            _asmEditor.Text = DefaultTemplate();
            _programNameBox.Text = "NEWPROG";
            _dirty = false;
        }
    }

    private async Task NewFileAsync()
    {
        if (!ConfirmDiscardIfDirty()) return;
        _suppressTextChanged = true;
        _asmEditor.Text = DefaultTemplate();
        _suppressTextChanged = false;
        _currentFile = null;
        _dirty = false;
        _programNameBox.Text = "NEWPROG";
        _hexViewer.Clear();
        UpdateTitle();
        ScheduleColorize();
        await Task.CompletedTask;
    }

    private async Task OpenFileFromDialogAsync()
    {
        if (!ConfirmDiscardIfDirty()) return;

        using var dialog = new OpenFileDialog
        {
            Title = "Open ASM source",
            Filter = "ASM source (*.asm)|*.asm|All files (*.*)|*.*",
            InitialDirectory = Directory.Exists(_workDir) ? _workDir : _repoRoot,
            CheckFileExists = true
        };

        if (dialog.ShowDialog(this) != DialogResult.OK) return;
        await LoadTextIntoEditorAsync(dialog.FileName, markAsCurrentFile: true);
    }

    private async Task LoadTemplateFromDialogAsync()
    {
        if (!ConfirmDiscardIfDirty()) return;

        using var dialog = new OpenFileDialog
        {
            Title = "Open template",
            Filter = "ASM source (*.asm)|*.asm|All files (*.*)|*.*",
            InitialDirectory = Directory.Exists(_templatesDir) ? _templatesDir : _repoRoot,
            CheckFileExists = true
        };

        if (dialog.ShowDialog(this) != DialogResult.OK) return;
        await LoadTextIntoEditorAsync(dialog.FileName, markAsCurrentFile: false);
        _currentFile = null;
        _dirty = false;
        UpdateTitle();
    }

    private async Task LoadTextIntoEditorAsync(string path, bool markAsCurrentFile)
    {
        var info = new FileInfo(path);
        var large = info.Length >= LargeFileThresholdBytes;
        LoadingForm? loading = null;

        try
        {
            if (large)
            {
                loading = new LoadingForm("Loading large ASM file", $"Reading {info.Name}...");
                loading.Show(this);
                await Task.Yield();
            }

            var progress = new Progress<int>(p => loading?.SetProgress(p, $"Reading {info.Name}... {p}%"));
            var text = large
                ? await ReadFileWithProgressAsync(path, progress, CancellationToken.None)
                : await File.ReadAllTextAsync(path);

            _suppressTextChanged = true;
            _asmEditor.Text = text;
            _suppressTextChanged = false;

            if (markAsCurrentFile)
            {
                _currentFile = path;
                _programNameBox.Text = SanitizeProgramName(Path.GetFileNameWithoutExtension(path));
            }
            else
            {
                _programNameBox.Text = SanitizeProgramName(Path.GetFileNameWithoutExtension(path));
            }

            _dirty = false;
            UpdateTitle();
            ScheduleColorize();
            SetStatus($"Loaded {info.Name} ({info.Length:N0} bytes).", false);
            Log($"Loaded: {path}", LogKind.Info);
        }
        catch (Exception ex)
        {
            Log("Load failed: " + ex.Message, LogKind.Error);
            MessageBox.Show(this, ex.Message, "Load failed", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            if (loading is not null)
            {
                loading.SetProgress(100, "Done.");
                loading.Close();
                loading.Dispose();
            }
        }
    }

    private static async Task<string> ReadFileWithProgressAsync(string path, IProgress<int> progress, CancellationToken cancellationToken)
    {
        const int bufferSize = 64 * 1024;
        var info = new FileInfo(path);
        var totalBytes = Math.Max(info.Length, 1L);
        var bytesReadTotal = 0L;
        var buffer = new byte[bufferSize];

        await using var stream = new FileStream(
            path,
            FileMode.Open,
            FileAccess.Read,
            FileShare.ReadWrite,
            bufferSize,
            FileOptions.Asynchronous | FileOptions.SequentialScan);

        using var memory = new MemoryStream(info.Length > int.MaxValue ? bufferSize : (int)info.Length);
        while (true)
        {
            var bytesRead = await stream.ReadAsync(buffer.AsMemory(0, buffer.Length), cancellationToken);
            if (bytesRead == 0) break;
            await memory.WriteAsync(buffer.AsMemory(0, bytesRead), cancellationToken);
            bytesReadTotal += bytesRead;
            progress.Report((int)Math.Min(100, bytesReadTotal * 100 / totalBytes));
        }

        progress.Report(100);
        return Encoding.UTF8.GetString(memory.ToArray());
    }

    private async Task SaveFileAsync()
    {
        if (string.IsNullOrWhiteSpace(_currentFile))
        {
            using var dialog = new SaveFileDialog
            {
                Title = "Save ASM source",
                Filter = "ASM source (*.asm)|*.asm|All files (*.*)|*.*",
                InitialDirectory = Directory.Exists(_workDir) ? _workDir : _repoRoot,
                FileName = MakeAsmFileName()
            };

            if (dialog.ShowDialog(this) != DialogResult.OK) return;
            _currentFile = dialog.FileName;
        }

        try
        {
            await File.WriteAllTextAsync(_currentFile, _asmEditor.Text, Encoding.UTF8);
            _dirty = false;
            _programNameBox.Text = SanitizeProgramName(Path.GetFileNameWithoutExtension(_currentFile));
            UpdateTitle();
            Log("Saved: " + _currentFile, LogKind.Success);
            SetStatus("Saved.", false);
        }
        catch (Exception ex)
        {
            Log("Save failed: " + ex.Message, LogKind.Error);
            MessageBox.Show(this, ex.Message, "Save failed", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private async Task BuildAsync()
    {
        if (_buildCancellation is not null) return;

        _buildCancellation = new CancellationTokenSource();
        SetBusy(true, "Building on background thread...");
        _logBox.Clear();

        try
        {
            var programName = SanitizeProgramName(_programNameBox.Text);
            if (string.IsNullOrWhiteSpace(programName)) programName = "PROGRAM";
            _programNameBox.Text = programName;

            var sourceText = _asmEditor.Text;
            if (string.IsNullOrWhiteSpace(sourceText))
            {
                Log("No ASM source to build.", LogKind.Error);
                return;
            }

            Log($"REV10 build started for {programName}. UI remains responsive.", LogKind.Info);
            var result = await Task.Run(() => BuildOnWorkerThread(programName, sourceText, _currentFile, _buildCancellation.Token));
            ShowBuildResult(result);
        }
        catch (OperationCanceledException)
        {
            Log("Build canceled.", LogKind.Warning);
            SetStatus("Build canceled.", false);
        }
        catch (Exception ex)
        {
            Log("Build failed: " + ex.Message, LogKind.Error);
            MessageBox.Show(this, ex.ToString(), "Build failed", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            _buildCancellation?.Dispose();
            _buildCancellation = null;
            SetBusy(false, _statusLabel.Text);
        }
    }

    private BuildResult BuildOnWorkerThread(string programName, string sourceText, string? currentFile, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        var sjasm = Path.Combine(_toolsDir, "sjasmplus.exe");
        if (!File.Exists(sjasm))
        {
            return BuildResult.Fail($"Assembler not found: {sjasm}");
        }

        var stamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
        var tempDir = Path.Combine(_workDir, $"_build_tmp_{programName}_{stamp}");
        var buildDir = Path.Combine(_buildsDir, $"{programName}_{stamp}");
        Directory.CreateDirectory(tempDir);
        Directory.CreateDirectory(buildDir);

        try
        {
            CopySupportFilesForBuild(tempDir, currentFile);

            var asmPath = Path.Combine(tempDir, programName + ".ASM");
            var comTempPath = Path.Combine(tempDir, programName + ".COM");
            var finalAsmPath = Path.Combine(buildDir, programName + ".ASM");
            var finalComPath = Path.Combine(buildDir, programName + ".COM");
            var finalHexPath = Path.Combine(buildDir, programName + ".HEX");
            var outAsmPath = Path.Combine(_outDir, programName + ".ASM");
            var outComPath = Path.Combine(_outDir, programName + ".COM");
            var outHexPath = Path.Combine(_outDir, programName + ".HEX");

            File.WriteAllText(asmPath, sourceText, Encoding.UTF8);
            File.WriteAllText(finalAsmPath, sourceText, Encoding.UTF8);

            var args = $"--raw=\"{comTempPath}\" \"{asmPath}\"";
            var processInfo = new ProcessStartInfo
            {
                FileName = sjasm,
                Arguments = args,
                WorkingDirectory = tempDir,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using var process = new Process { StartInfo = processInfo };
            var output = new StringBuilder();
            process.OutputDataReceived += (_, e) => { if (e.Data is not null) output.AppendLine(e.Data); };
            process.ErrorDataReceived += (_, e) => { if (e.Data is not null) output.AppendLine(e.Data); };

            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();

            try
            {
                while (!process.WaitForExit(50))
                {
                    cancellationToken.ThrowIfCancellationRequested();
                }

                // Give asynchronous output readers a final chance to flush.
                process.WaitForExit();
            }
            catch (OperationCanceledException)
            {
                try
                {
                    if (!process.HasExited) process.Kill(entireProcessTree: true);
                }
                catch
                {
                    // Best effort only.
                }

                throw;
            }

            cancellationToken.ThrowIfCancellationRequested();
            var assemblerLog = output.ToString();

            if (process.ExitCode != 0)
            {
                return BuildResult.Fail(
                    $"Assembler returned exit code {process.ExitCode}.\r\n\r\nArgs: {args}\r\n\r\n{assemblerLog}",
                    buildDir);
            }

            if (!File.Exists(comTempPath))
            {
                return BuildResult.Fail(
                    $"Assembler reported success but did not create {Path.GetFileName(comTempPath)}.\r\n\r\nArgs: {args}\r\n\r\n{assemblerLog}",
                    buildDir);
            }

            File.Copy(comTempPath, finalComPath, overwrite: true);
            var comBytes = File.ReadAllBytes(finalComPath);
            var hexText = ConvertBinaryToIntelHex(comBytes, IntelHexBaseAddress);
            File.WriteAllText(finalHexPath, hexText, Encoding.ASCII);

            Directory.CreateDirectory(_outDir);
            File.Copy(finalAsmPath, outAsmPath, overwrite: true);
            File.Copy(finalComPath, outComPath, overwrite: true);
            File.Copy(finalHexPath, outHexPath, overwrite: true);

            var message = new StringBuilder();
            message.AppendLine($"SUCCESS: {programName}.COM built ({comBytes.Length:N0} bytes) and converted to Intel HEX.");
            message.AppendLine();
            message.AppendLine("Clean project folder contains:");
            message.AppendLine("  " + finalAsmPath);
            message.AppendLine("  " + finalHexPath);
            message.AppendLine("  " + finalComPath);
            message.AppendLine();
            message.AppendLine("Latest quick outputs copied to:");
            message.AppendLine("  " + outAsmPath);
            message.AppendLine("  " + outHexPath);
            message.AppendLine("  " + outComPath);
            message.AppendLine();
            message.AppendLine("XMODEM method:");
            message.AppendLine($"  C>XM R {programName}.COM");
            message.AppendLine("  Tera Term: File -> Transfer -> XMODEM -> Send...");
            message.AppendLine();
            message.AppendLine("PIP/LOAD method for smaller HEX:");
            message.AppendLine($"  C>PIP {programName}.HEX=CON:");
            message.AppendLine("  Paste with 1 ms per character and 1 ms per line, then Ctrl+Z.");
            message.AppendLine($"  C>LOAD {programName}.HEX");
            message.AppendLine($"  C>{programName}");

            if (!string.IsNullOrWhiteSpace(assemblerLog))
            {
                message.AppendLine();
                message.AppendLine("Assembler output:");
                message.AppendLine(assemblerLog.TrimEnd());
            }

            return BuildResult.Success(message.ToString(), buildDir, finalHexPath, finalComPath, hexText);
        }
        finally
        {
            TryDeleteDirectory(tempDir);
        }
    }

    private void CopySupportFilesForBuild(string tempDir, string? currentFile)
    {
        var tempLibsDir = Path.Combine(tempDir, "Libs");
        Directory.CreateDirectory(tempLibsDir);

        foreach (var file in Directory.EnumerateFiles(_libsDir, "*.asm", SearchOption.TopDirectoryOnly))
        {
            var fileName = Path.GetFileName(file);
            File.Copy(file, Path.Combine(tempDir, fileName), overwrite: true);
            File.Copy(file, Path.Combine(tempLibsDir, fileName), overwrite: true);
        }

        if (!string.IsNullOrWhiteSpace(currentFile) && File.Exists(currentFile))
        {
            var sourceDir = Path.GetDirectoryName(currentFile);
            if (!string.IsNullOrWhiteSpace(sourceDir) && Directory.Exists(sourceDir))
            {
                foreach (var file in Directory.EnumerateFiles(sourceDir, "*.asm", SearchOption.TopDirectoryOnly))
                {
                    var dest = Path.Combine(tempDir, Path.GetFileName(file));
                    if (!File.Exists(dest)) File.Copy(file, dest, overwrite: false);
                }
            }
        }
    }

    private void ShowBuildResult(BuildResult result)
    {
        if (result.Succeeded)
        {
            Log(result.Message, LogKind.Success);
            if (!string.IsNullOrWhiteSpace(result.HexText))
            {
                _hexViewer.Text = result.HexText;
            }
            SetStatus($"Build complete: {Path.GetFileName(result.ComPath ?? string.Empty)}", false);
        }
        else
        {
            Log(result.Message, LogKind.Error);
            SetStatus("Build failed. See log.", true);
        }
    }

    private static string ConvertBinaryToIntelHex(byte[] data, int baseAddress)
    {
        var sb = new StringBuilder(data.Length * 3);
        const int recordSize = 16;

        for (var offset = 0; offset < data.Length; offset += recordSize)
        {
            var count = Math.Min(recordSize, data.Length - offset);
            var address = baseAddress + offset;
            var checksum = count + ((address >> 8) & 0xFF) + (address & 0xFF);

            sb.Append(':');
            sb.Append(count.ToString("X2"));
            sb.Append(address.ToString("X4"));
            sb.Append("00");

            for (var i = 0; i < count; i++)
            {
                var value = data[offset + i];
                checksum += value;
                sb.Append(value.ToString("X2"));
            }

            var finalChecksum = ((~checksum + 1) & 0xFF);
            sb.AppendLine(finalChecksum.ToString("X2"));
        }

        sb.AppendLine(":00000001FF");
        return sb.ToString();
    }

    private void ScheduleColorize()
    {
        if (_asmEditor.TextLength > MaxAutoColorizeChars) return;
        _colorizeTimer.Stop();
        _colorizeTimer.Start();
    }

    private void ColorizeAsmEditorSafe()
    {
        if (_asmEditor.TextLength == 0) return;
        if (_asmEditor.TextLength > MaxAutoColorizeChars)
        {
            SetStatus("Large file loaded. Syntax colorizing skipped to keep editing fast.", false);
            return;
        }

        var text = _asmEditor.Text;
        var lineCount = text.Count(c => c == '\n') + 1;
        if (lineCount > MaxAutoColorizeLines)
        {
            SetStatus("Large file loaded. Syntax colorizing skipped to keep editing fast.", false);
            return;
        }

        var selectionStart = _asmEditor.SelectionStart;
        var selectionLength = _asmEditor.SelectionLength;

        try
        {
            SuspendDrawing(_asmEditor);
            _asmEditor.SelectAll();
            _asmEditor.SelectionColor = Color.Gainsboro;

            foreach (Match match in TokenRegex.Matches(text))
            {
                Color color;
                if (match.Groups["comment"].Success) color = Color.FromArgb(90, 210, 110);
                else if (match.Groups["string"].Success) color = Color.FromArgb(230, 210, 120);
                else if (match.Groups["label"].Success) color = Color.FromArgb(120, 180, 255);
                else if (match.Groups["directive"].Success) color = Color.FromArgb(210, 160, 255);
                else color = Color.FromArgb(120, 225, 225);

                _asmEditor.Select(match.Index, match.Length);
                _asmEditor.SelectionColor = color;
            }
        }
        catch
        {
            // Coloring is helpful, not critical. Never let it interrupt editing.
        }
        finally
        {
            _asmEditor.Select(Math.Min(selectionStart, _asmEditor.TextLength), Math.Min(selectionLength, Math.Max(0, _asmEditor.TextLength - selectionStart)));
            ResumeDrawing(_asmEditor);
        }
    }

    private bool ConfirmDiscardIfDirty()
    {
        if (!_dirty) return true;
        var result = MessageBox.Show(
            this,
            "The current ASM source has unsaved changes. Continue and discard those changes?",
            "Unsaved ASM source",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Warning,
            MessageBoxDefaultButton.Button2);
        return result == DialogResult.Yes;
    }

    private void CopyHexToClipboard()
    {
        if (string.IsNullOrWhiteSpace(_hexViewer.Text))
        {
            SetStatus("No HEX text to copy yet.", true);
            return;
        }

        Clipboard.SetText(_hexViewer.Text);
        SetStatus("HEX copied to clipboard.", false);
        Log("HEX copied to clipboard.", LogKind.Success);
    }

    private static void OpenFolder(string path)
    {
        Directory.CreateDirectory(path);
        Process.Start(new ProcessStartInfo
        {
            FileName = path,
            UseShellExecute = true
        });
    }

    private void Log(string text, LogKind kind)
    {
        if (InvokeRequired)
        {
            BeginInvoke(() => Log(text, kind));
            return;
        }

        var oldStart = _logBox.SelectionStart;
        var color = kind switch
        {
            LogKind.Success => Color.FromArgb(110, 235, 140),
            LogKind.Warning => Color.FromArgb(250, 210, 105),
            LogKind.Error => Color.FromArgb(255, 120, 120),
            _ => Color.Gainsboro
        };

        _logBox.SelectionStart = _logBox.TextLength;
        _logBox.SelectionLength = 0;
        _logBox.SelectionColor = color;
        _logBox.AppendText($"[{DateTime.Now:HH:mm:ss}] {text.TrimEnd()}\r\n");
        _logBox.SelectionColor = _logBox.ForeColor;
        _logBox.SelectionStart = _logBox.TextLength;
        _logBox.ScrollToCaret();
    }

    private void SetBusy(bool busy, string status)
    {
        if (InvokeRequired)
        {
            BeginInvoke(() => SetBusy(busy, status));
            return;
        }

        _newButton.Enabled = !busy;
        _openButton.Enabled = !busy;
        _saveButton.Enabled = !busy;
        _templateButton.Enabled = !busy;
        _buildButton.Enabled = !busy;
        _cancelButton.Enabled = busy;
        _programNameBox.Enabled = !busy;

        _buildProgress.Style = busy ? ProgressBarStyle.Marquee : ProgressBarStyle.Continuous;
        _buildProgress.Value = busy ? 100 : 0;
        SetStatus(status, false);
    }

    private void SetStatus(string message, bool isError)
    {
        if (InvokeRequired)
        {
            BeginInvoke(() => SetStatus(message, isError));
            return;
        }

        _statusLabel.Text = message;
        _statusLabel.ForeColor = isError ? Color.FromArgb(255, 130, 130) : Color.Gainsboro;
    }

    private void UpdateTitle()
    {
        var name = _currentFile is null ? "Untitled" : Path.GetFileName(_currentFile);
        Text = $"{AppTitle} - {name}{(_dirty ? " *" : string.Empty)}";
    }

    private string MakeAsmFileName() => SanitizeProgramName(_programNameBox.Text) + ".ASM";

    private static string SanitizeProgramName(string? rawName)
    {
        var name = string.IsNullOrWhiteSpace(rawName) ? "PROGRAM" : rawName.Trim();
        name = Path.GetFileNameWithoutExtension(name).ToUpperInvariant();
        var chars = name.Where(ch => char.IsLetterOrDigit(ch) || ch == '_' || ch == '$' || ch == '-').ToArray();
        name = new string(chars);
        if (string.IsNullOrWhiteSpace(name)) name = "PROGRAM";
        if (name.Length > 8) name = name[..8];
        return name;
    }

    private static string DefaultTemplate() =>
        "        org     100h\r\n" +
        "\r\n" +
        "Start:\r\n" +
        "        ; Your CP/M Z80/Z180 code goes here.\r\n" +
        "\r\n" +
        "Exit:\r\n" +
        "        rst     0\r\n" +
        "\r\n" +
        "        include \"utility.asm\"\r\n" +
        "        end\r\n";

    private void TrySetIcon()
    {
        var iconPath = Path.Combine(_repoRoot, "Assets", "TMSAsmBuilder.ico");
        if (!File.Exists(iconPath)) return;
        try { Icon = new Icon(iconPath); }
        catch { /* Ignore bad icon data. */ }
    }

    private static string LocateRepoRoot()
    {
        var candidates = new List<string>();
        var baseDir = AppContext.BaseDirectory;
        var current = Directory.GetCurrentDirectory();
        candidates.Add(baseDir);
        candidates.Add(current);

        var dir = new DirectoryInfo(baseDir);
        for (var i = 0; i < 8 && dir is not null; i++, dir = dir.Parent)
        {
            candidates.Add(dir.FullName);
        }

        dir = new DirectoryInfo(current);
        for (var i = 0; i < 8 && dir is not null; i++, dir = dir.Parent)
        {
            candidates.Add(dir.FullName);
        }

        foreach (var candidate in candidates.Distinct(StringComparer.OrdinalIgnoreCase))
        {
            if (File.Exists(Path.Combine(candidate, "Tools", "sjasmplus.exe")) &&
                Directory.Exists(Path.Combine(candidate, "Libs")))
            {
                return candidate;
            }
        }

        return baseDir;
    }

    private static void TryDeleteDirectory(string path)
    {
        try
        {
            if (Directory.Exists(path)) Directory.Delete(path, recursive: true);
        }
        catch
        {
            // Temp folders are not worth failing a successful build over.
        }
    }

    private static void SuspendDrawing(Control control)
    {
        if (!control.IsHandleCreated) return;
        SendMessage(control.Handle, WM_SETREDRAW, IntPtr.Zero, IntPtr.Zero);
    }

    private static void ResumeDrawing(Control control)
    {
        if (!control.IsHandleCreated) return;
        SendMessage(control.Handle, WM_SETREDRAW, new IntPtr(1), IntPtr.Zero);
        control.Invalidate();
    }

    private const int WM_SETREDRAW = 0x000B;

    [DllImport("user32.dll")]
    private static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);

    private enum LogKind
    {
        Info,
        Success,
        Warning,
        Error
    }

    private sealed record BuildResult(
        bool Succeeded,
        string Message,
        string? BuildDirectory = null,
        string? HexPath = null,
        string? ComPath = null,
        string? HexText = null)
    {
        public static BuildResult Success(string message, string buildDirectory, string hexPath, string comPath, string hexText) =>
            new(true, message, buildDirectory, hexPath, comPath, hexText);

        public static BuildResult Fail(string message, string? buildDirectory = null) =>
            new(false, message, buildDirectory);
    }
}
