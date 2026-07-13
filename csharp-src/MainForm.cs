using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Net.Http;
using System.Windows.Forms;

namespace DarkwoodCoopLauncher
{
    // Janela sem moldura nativa do Windows (barra de titulo propria, arrastavel)
    // + navegacao lateral em vez de abas padrao - visual mais "parte do jogo",
    // menos generico. Sem assets do jogo em si (direitos autorais) - so
    // cor/tipografia/layout (ver Theme.cs).
    public sealed class MainForm : Form
    {
        private const string RepoRaw = "https://raw.githubusercontent.com/felipescoutfx/darkwood-coop-launcher/main";
        private const string DarkwoodAppId = "274520";

        private readonly Config _cfg;
        private readonly Dictionary<string, Panel> _navPanels = new Dictionary<string, Panel>();
        private readonly Dictionary<string, Button> _navButtons = new Dictionary<string, Button>();

        private TextBox _txtPath, _txtPeer, _txtOut;
        private Label _lblStatus, _lblUpdate;
        private Panel _titleBar, _sidebar, _content;
        private bool _dragging;
        private Point _dragOffset;

        public MainForm()
        {
            _cfg = Config.Load();
            if (string.IsNullOrWhiteSpace(_cfg.Lang))
            {
                // Primeira vez sem preferencia salva: detecta pelo idioma do Windows.
                string sysLang = System.Globalization.CultureInfo.CurrentCulture.TwoLetterISOLanguageName;
                _cfg.Lang = sysLang == "pt" ? "pt" : "en";
            }
            Strings.Lang = _cfg.Lang;

            // Auto-deteccao: tenta sozinho sempre que o caminho salvo estiver
            // vazio OU invalido - so sobra pro botao manual se falhar.
            if (string.IsNullOrWhiteSpace(_cfg.DarkwoodPath) || !File.Exists(Path.Combine(_cfg.DarkwoodPath, "Darkwood.exe")))
            {
                string auto = DarkwoodPathFinder.Find();
                if (!string.IsNullOrWhiteSpace(auto)) _cfg.DarkwoodPath = auto;
            }

            BuildUi();
            Shown += (s, e) => { Activate(); CheckModVersionLabel(); };
        }

        private string T(string key) => Strings.T(key);

        private void BuildUi()
        {
            Text = T("WindowTitle");
            ClientSize = new Size(660, 640);
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.None;
            BackColor = Theme.Bg;
            MaximizeBox = false;
            ShowInTaskbar = true;

            Paint += (s, e) =>
            {
                using (var pen = new Pen(Theme.Border, 1))
                    e.Graphics.DrawRectangle(pen, 0, 0, ClientSize.Width - 1, ClientSize.Height - 1);
            };

            BuildTitleBar();
            BuildPathPanel();
            BuildNavAndContent();
            BuildStatusBar();
        }

        private void BuildTitleBar()
        {
            _titleBar = new Panel { Location = new Point(0, 0), Size = new Size(660, 38), BackColor = Theme.SidebarBg };
            Controls.Add(_titleBar);

            var lblTitle = Theme.MakeLabel(T("TitleBar"), 16, 8, 400, 22, Theme.TextMain, Theme.FontTitle);
            _titleBar.Controls.Add(lblTitle);

            var btnClose = Theme.StyledButton("X", 624, 0, 36, 38, Theme.SidebarBg, Theme.Danger, Theme.TextMuted, Theme.FontClose);
            btnClose.Click += (s, e) => Close();
            _titleBar.Controls.Add(btnClose);

            var btnMin = Theme.StyledButton("-", 588, 0, 36, 38, Theme.SidebarBg, Theme.BtnHover, Theme.TextMuted, Theme.FontClose);
            btnMin.Click += (s, e) => WindowState = FormWindowState.Minimized;
            _titleBar.Controls.Add(btnMin);

            // Botao de idioma - mostra o idioma que vai VIRAR ao clicar. Troca =
            // salva preferencia + reabre o launcher (mais simples/confiavel que
            // re-traduzir controles ja criados ao vivo).
            var btnLang = Theme.StyledButton(T("LangToggle"), 548, 0, 36, 38, Theme.SidebarBg, Theme.BtnHover, Theme.TextMuted, Theme.FontLangBtn);
            btnLang.Click += (s, e) =>
            {
                _cfg.Lang = Strings.Lang == "en" ? "pt" : "en";
                _cfg.Save();
                Process.Start(Application.ExecutablePath);
                Close();
            };
            _titleBar.Controls.Add(btnLang);

            MouseEventHandler downHandler = (s, e) => { if (e.Button == MouseButtons.Left) { _dragging = true; _dragOffset = e.Location; } };
            MouseEventHandler moveHandler = (s, e) =>
            {
                if (!_dragging) return;
                var p = PointToScreen(e.Location);
                Location = new Point(p.X - _dragOffset.X, p.Y - _dragOffset.Y);
            };
            MouseEventHandler upHandler = (s, e) => _dragging = false;
            _titleBar.MouseDown += downHandler; _titleBar.MouseMove += moveHandler; _titleBar.MouseUp += upHandler;
            lblTitle.MouseDown += downHandler; lblTitle.MouseMove += moveHandler; lblTitle.MouseUp += upHandler;
        }

        private void BuildPathPanel()
        {
            var pathPanel = new Panel { Location = new Point(0, 38), Size = new Size(660, 64), BackColor = Theme.PanelBg };
            Controls.Add(pathPanel);
            pathPanel.Controls.Add(Theme.MakeLabel(T("FolderLabel"), 16, 8, 300, 16, Theme.TextMuted, Theme.FontLabel));

            _txtPath = Theme.DarkTextBox(16, 28, 560, 26);
            _txtPath.Text = _cfg.DarkwoodPath;
            pathPanel.Controls.Add(_txtPath);

            var btnBrowse = Theme.StyledButton("...", 584, 28, 60, 26, Theme.BtnBg, Theme.BtnHover, Theme.TextMain, Theme.FontBody);
            btnBrowse.Click += (s, e) =>
            {
                using (var dlg = new FolderBrowserDialog())
                    if (dlg.ShowDialog() == DialogResult.OK) _txtPath.Text = dlg.SelectedPath;
            };
            pathPanel.Controls.Add(btnBrowse);
        }

        private void BuildNavAndContent()
        {
            _sidebar = new Panel { Location = new Point(0, 102), Size = new Size(150, 502), BackColor = Theme.SidebarBg };
            Controls.Add(_sidebar);
            _content = new Panel { Location = new Point(150, 102), Size = new Size(510, 502), BackColor = Theme.Bg };
            Controls.Add(_content);

            var panelMain = RegisterNavPanel("main", T("NavMain"));
            var panelAdv = RegisterNavPanel("adv", T("NavAdv"));
            BuildMainPanel(panelMain);
            BuildAdvancedPanel(panelAdv);
            ShowNavPanel("main");
        }

        private int _navY = 14;
        private Panel RegisterNavPanel(string key, string label)
        {
            var panel = new Panel { Location = new Point(0, 0), Size = new Size(510, 502), BackColor = Theme.Bg, Visible = false };
            _content.Controls.Add(panel);

            var btn = new Button
            {
                Text = "  " + label,
                Location = new Point(0, _navY),
                Size = new Size(150, 38),
                FlatStyle = FlatStyle.Flat,
                TextAlign = ContentAlignment.MiddleLeft,
                Font = Theme.FontNav,
                ForeColor = Theme.TextMuted,
                BackColor = Theme.SidebarBg,
                Cursor = Cursors.Hand,
                UseVisualStyleBackColor = false,
            };
            btn.FlatAppearance.BorderSize = 0;
            btn.Click += (s, e) => ShowNavPanel(key);
            _sidebar.Controls.Add(btn);

            _navButtons[key] = btn;
            _navPanels[key] = panel;
            _navY += 40;
            return panel;
        }

        private void ShowNavPanel(string key)
        {
            foreach (var k in _navPanels.Keys)
            {
                bool active = k == key;
                _navPanels[k].Visible = active;
                _navButtons[k].BackColor = active ? Theme.AccentDim : Theme.SidebarBg;
                _navButtons[k].ForeColor = active ? Theme.TextMain : Theme.TextMuted;
            }
        }

        private string GetDarkwoodPathOrWarn()
        {
            string p = _txtPath.Text.Trim();
            if (string.IsNullOrWhiteSpace(p) || !File.Exists(Path.Combine(p, "Darkwood.exe")))
            {
                MessageBox.Show(T("InvalidFolder"), T("ErrorTitle"));
                return null;
            }
            return p;
        }

        // ===== PAINEL PRINCIPAL =====
        private void BuildMainPanel(Panel panelMain)
        {
            int my = 16;
            panelMain.Controls.Add(Theme.MakeLabel(T("Intro"), 0, my, 490, 60, Theme.TextMuted, Theme.FontLabel));
            my += 66;

            var btnInstall = Theme.StyledButton(T("BtnInstall"), 0, my, 490, 40, Theme.AccentDim, Theme.AccentHover, Theme.TextMain, Theme.FontNav);
            btnInstall.Click += (s, e) =>
            {
                string path = GetDarkwoodPathOrWarn(); if (path == null) return;
                try
                {
                    SetStatus(T("DownloadingBepInEx"));
                    string zip = Path.Combine(Path.GetTempPath(), "bepinex-bundle.zip");
                    DownloadFile($"{RepoRaw}/bepinex-bundle.zip", zip);
                    ZipFile.ExtractToDirectory(zip, path);
                    SetStatus(T("DownloadingMod"));
                    Directory.CreateDirectory(Path.Combine(path, "BepInEx", "plugins"));
                    DownloadFile($"{RepoRaw}/mod/DarkwoodCoopOnline.dll", Path.Combine(path, "BepInEx", "plugins", "DarkwoodCoopOnline.dll"));
                    WriteBepInExConfig(path, _txtPeer.Text.Trim());
                    _cfg.InstalledModVersion = GetLatestModVersion(); _cfg.Save();
                    SetStatus(T("Installed"));
                }
                catch (Exception ex) { SetStatus(string.Format(T("ErrorPrefix"), ex.Message)); }
            };
            panelMain.Controls.Add(btnInstall);
            my += 48;

            var btnSyncMod = Theme.StyledButton(T("BtnSyncMod"), 0, my, 490, 40, Theme.BtnBg, Theme.BtnHover, Theme.TextMain, Theme.FontBody);
            btnSyncMod.Click += (s, e) =>
            {
                string path = GetDarkwoodPathOrWarn(); if (path == null) return;
                try
                {
                    SetStatus(T("DownloadingLatestMod"));
                    DownloadFile($"{RepoRaw}/mod/DarkwoodCoopOnline.dll", Path.Combine(path, "BepInEx", "plugins", "DarkwoodCoopOnline.dll"));
                    _cfg.InstalledModVersion = GetLatestModVersion(); _cfg.Save();
                    SetStatus(string.Format(T("ModUpdated"), _cfg.InstalledModVersion));
                    // Confirmacao so na barra de status (embaixo, discreta) passava
                    // despercebida - o label grande (avisa versao nova) tambem
                    // confirma na hora, sem precisar reabrir o launcher.
                    _lblUpdate.ForeColor = Theme.Accent;
                    _lblUpdate.Font = Theme.FontNav;
                    _lblUpdate.Text = string.Format(T("ModUpdated"), _cfg.InstalledModVersion);
                }
                catch (Exception ex) { SetStatus(string.Format(T("ErrorPrefix"), ex.Message)); }
            };
            panelMain.Controls.Add(btnSyncMod);
            my += 48;

            var btnPlay = Theme.StyledButton(T("BtnPlay"), 0, my, 490, 46, Theme.Accent, Theme.AccentHover, Theme.PlayFg, Theme.FontNav);
            btnPlay.Click += (s, e) =>
            {
                _cfg.DarkwoodPath = _txtPath.Text.Trim();
                _cfg.PeerSteamId64 = _txtPeer.Text.Trim();
                _cfg.Save();
                Process.Start(new ProcessStartInfo("steam://rungameid/" + DarkwoodAppId) { UseShellExecute = true });
                SetStatus(T("OpeningSteam"));
            };
            panelMain.Controls.Add(btnPlay);
            my += 58;

            _lblUpdate = Theme.MakeLabel("", 0, my, 490, 40, Theme.TextMuted, Theme.FontLabel);
            panelMain.Controls.Add(_lblUpdate);
        }

        // ===== PAINEL AVANCADO =====
        private void BuildAdvancedPanel(Panel panelAdv)
        {
            int ay = 16;
            panelAdv.Controls.Add(Theme.MakeLabel(T("SteamIdLabel"), 0, ay, 490, 16, Theme.TextMuted, Theme.FontLabel));
            ay += 20;

            _txtPeer = Theme.DarkTextBox(0, ay, 490, 26);
            _txtPeer.Text = _cfg.PeerSteamId64;
            panelAdv.Controls.Add(_txtPeer);
            ay += 34;

            var btnUpdateCfg = Theme.StyledButton(T("BtnUpdateCfg"), 0, ay, 490, 34, Theme.AccentDim, Theme.AccentHover, Theme.TextMain, Theme.FontBody);
            btnUpdateCfg.Click += (s, e) =>
            {
                string path = GetDarkwoodPathOrWarn(); if (path == null) return;
                string peerId = _txtPeer.Text.Trim();
                if (string.IsNullOrWhiteSpace(peerId) || peerId == "0")
                {
                    MessageBox.Show(T("FillSteamIdCfg"), T("ErrorTitle"));
                    return;
                }
                try
                {
                    WriteBepInExConfig(path, peerId);
                    _cfg.PeerSteamId64 = peerId; _cfg.Save();
                    SetStatus(string.Format(T("CfgUpdated"), peerId));
                }
                catch (Exception ex) { SetStatus(string.Format(T("ErrorUpdatingCfg"), ex.Message)); }
            };
            panelAdv.Controls.Add(btnUpdateCfg);
            ay += 42;

            var btnSendLog = Theme.StyledButton(T("BtnSendLog"), 0, ay, 490, 34, Theme.Danger, Theme.DangerHover, Theme.TextMain, Theme.FontBody);
            btnSendLog.Click += (s, e) =>
            {
                string path = _txtPath.Text.Trim();
                string logPath = Path.Combine(path, "BepInEx", "LogOutput.log");
                if (!File.Exists(logPath)) { SetStatus(string.Format(T("LogNotFound"), logPath)); return; }
                try
                {
                    SetStatus(T("SendingLog"));
                    string url = LogUploader.Upload(logPath);
                    if (string.IsNullOrWhiteSpace(url)) { SetStatus(T("LogSendFailed")); return; }
                    _txtOut.Text = string.Format(T("LogLinkText"), url);
                    Clipboard.SetText(url);
                    SetStatus(T("LogSent"));
                }
                catch (Exception ex) { SetStatus(string.Format(T("ErrorSendingLog"), ex.Message)); }
            };
            panelAdv.Controls.Add(btnSendLog);
            ay += 42;

            _txtOut = new TextBox
            {
                Multiline = true,
                ScrollBars = ScrollBars.Vertical,
                ReadOnly = true,
                Location = new Point(0, ay),
                Size = new Size(490, 140),
                BackColor = Theme.BtnBg,
                ForeColor = Theme.TextMain,
                BorderStyle = BorderStyle.FixedSingle,
                Font = Theme.FontMono,
            };
            panelAdv.Controls.Add(_txtOut);
        }

        private void BuildStatusBar()
        {
            var statusPanel = new Panel { Location = new Point(0, 604), Size = new Size(660, 36), BackColor = Theme.SidebarBg };
            Controls.Add(statusPanel);
            _lblStatus = Theme.MakeLabel(T("Ready"), 16, 8, 620, 20, Theme.TextMuted, Theme.FontLabel);
            statusPanel.Controls.Add(_lblStatus);
        }

        private void SetStatus(string msg)
        {
            _lblStatus.Text = msg;
            Refresh();
        }

        private void CheckModVersionLabel()
        {
            string latest = GetLatestModVersion();
            if (string.IsNullOrWhiteSpace(latest)) return;

            if (string.IsNullOrWhiteSpace(_cfg.InstalledModVersion))
            {
                _lblUpdate.ForeColor = Theme.TextMuted;
                _lblUpdate.Text = string.Format(T("ModVersionInRepo"), latest);
            }
            else if (_cfg.InstalledModVersion != latest)
            {
                _lblUpdate.ForeColor = Theme.Accent;
                _lblUpdate.Text = string.Format(T("NewModVersion"), latest, _cfg.InstalledModVersion);
            }
            else
            {
                _lblUpdate.ForeColor = Theme.TextMuted;
                _lblUpdate.Text = string.Format(T("ModUpToDate"), latest);
            }
        }

        private static void DownloadFile(string url, string destPath)
        {
            using (var http = new HttpClient())
            {
                var bytes = http.GetByteArrayAsync(url).GetAwaiter().GetResult();
                File.WriteAllBytes(destPath, bytes);
            }
        }

        private static string GetLatestModVersion()
        {
            try
            {
                using (var http = new HttpClient())
                    return http.GetStringAsync($"{RepoRaw}/mod_version.txt").GetAwaiter().GetResult().Trim();
            }
            catch { return ""; }
        }

        private static void WriteBepInExConfig(string darkwoodPath, string peerId)
        {
            string cfgDir = Path.Combine(darkwoodPath, "BepInEx", "config");
            Directory.CreateDirectory(cfgDir);
            string cfgPath = Path.Combine(cfgDir, "com.felipe.darkwoodcooponline.cfg");
            if (string.IsNullOrWhiteSpace(peerId)) peerId = "0";
            string content =
                "## Settings file was created by plugin Darkwood Co-op Online v0.1.0\n" +
                "## Plugin GUID: com.felipe.darkwoodcooponline\n\n" +
                "[Loopback]\n" +
                "LocalPort = 7777\n" +
                "RemotePort = 7778\n\n" +
                "[Steam]\n" +
                $"PeerSteamId64 = {peerId}\n\n" +
                "[Transport]\n" +
                "Mode = Steam\n";
            File.WriteAllText(cfgPath, content);
        }
    }
}
