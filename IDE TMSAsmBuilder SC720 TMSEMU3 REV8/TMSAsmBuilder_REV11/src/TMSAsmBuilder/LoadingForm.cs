using System;
using System.Drawing;
using System.Windows.Forms;

namespace TMSAsmBuilder;

public sealed class LoadingForm : Form
{
    private readonly Label _titleLabel;
    private readonly Label _detailLabel;
    private readonly ProgressBar _progressBar;

    public LoadingForm(string title, string detail)
    {
        Text = title;
        StartPosition = FormStartPosition.CenterParent;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MinimizeBox = false;
        MaximizeBox = false;
        ControlBox = false;
        ShowInTaskbar = false;
        Width = 520;
        Height = 170;
        BackColor = Color.FromArgb(24, 26, 30);
        ForeColor = Color.White;
        Font = new Font("Segoe UI", 10F);

        _titleLabel = new Label
        {
            Text = title,
            AutoSize = false,
            Left = 18,
            Top = 16,
            Width = 470,
            Height = 28,
            Font = new Font(Font, FontStyle.Bold),
            ForeColor = Color.White
        };

        _detailLabel = new Label
        {
            Text = detail,
            AutoSize = false,
            Left = 18,
            Top = 48,
            Width = 470,
            Height = 28,
            ForeColor = Color.Gainsboro
        };

        _progressBar = new ProgressBar
        {
            Left = 18,
            Top = 88,
            Width = 470,
            Height = 24,
            Minimum = 0,
            Maximum = 100,
            Value = 0,
            Style = ProgressBarStyle.Continuous
        };

        Controls.Add(_titleLabel);
        Controls.Add(_detailLabel);
        Controls.Add(_progressBar);
    }

    public void SetProgress(int percent, string? detail = null)
    {
        percent = Math.Clamp(percent, 0, 100);
        if (InvokeRequired)
        {
            BeginInvoke(() => SetProgress(percent, detail));
            return;
        }

        _progressBar.Value = percent;
        if (!string.IsNullOrWhiteSpace(detail))
        {
            _detailLabel.Text = detail;
        }
    }
}
