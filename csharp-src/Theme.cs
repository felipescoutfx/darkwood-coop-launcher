using System.Drawing;
using System.Windows.Forms;

namespace DarkwoodCoopLauncher
{
    // Paleta inspirada no Darkwood: quase-preto de fundo, musgo/verde apagado
    // como acento primario (menus/hover do proprio jogo usam esse tom), vermelho
    // seco como acento de perigo/aviso. Sem assets do jogo em si (direitos
    // autorais) - so cor/tipografia/layout.
    public static class Theme
    {
        public static readonly Color Bg = Color.FromArgb(255, 13, 13, 12);
        public static readonly Color PanelBg = Color.FromArgb(255, 20, 20, 18);
        public static readonly Color SidebarBg = Color.FromArgb(255, 17, 17, 15);
        public static readonly Color Border = Color.FromArgb(255, 40, 40, 36);
        public static readonly Color Accent = Color.FromArgb(255, 122, 138, 92);
        public static readonly Color AccentDim = Color.FromArgb(255, 58, 66, 44);
        public static readonly Color AccentHover = Color.FromArgb(255, 84, 96, 62);
        public static readonly Color Danger = Color.FromArgb(255, 138, 58, 53);
        public static readonly Color DangerHover = Color.FromArgb(255, 168, 72, 64);
        public static readonly Color TextMain = Color.FromArgb(255, 214, 210, 199);
        public static readonly Color TextMuted = Color.FromArgb(255, 132, 128, 118);
        public static readonly Color BtnBg = Color.FromArgb(255, 30, 30, 27);
        public static readonly Color BtnHover = Color.FromArgb(255, 42, 42, 38);
        public static readonly Color PlayFg = Color.FromArgb(255, 14, 14, 12);

        public static readonly Font FontTitle = new Font("Segoe UI", 12, FontStyle.Bold);
        public static readonly Font FontNav = new Font("Segoe UI", 9.5f, FontStyle.Bold);
        public static readonly Font FontBody = new Font("Segoe UI", 9.5f, FontStyle.Regular);
        public static readonly Font FontLabel = new Font("Segoe UI", 8.5f, FontStyle.Regular);
        public static readonly Font FontMono = new Font("Consolas", 8.5f, FontStyle.Regular);
        public static readonly Font FontClose = new Font("Segoe UI", 11, FontStyle.Regular);
        public static readonly Font FontLangBtn = new Font("Segoe UI", 8, FontStyle.Bold);

        public static Button StyledButton(string text, int x, int y, int w, int h, Color bg, Color hoverBg, Color fg, Font font)
        {
            var btn = new Button
            {
                Text = text,
                Location = new Point(x, y),
                Size = new Size(w, h),
                FlatStyle = FlatStyle.Flat,
                BackColor = bg,
                ForeColor = fg,
                Font = font,
                Cursor = Cursors.Hand,
                TextAlign = ContentAlignment.MiddleCenter,
                UseVisualStyleBackColor = false,
            };
            btn.FlatAppearance.BorderSize = 0;
            btn.FlatAppearance.MouseOverBackColor = hoverBg;
            return btn;
        }

        public static Label MakeLabel(string text, int x, int y, int w, int h, Color fg, Font font) => new Label
        {
            Text = text,
            Location = new Point(x, y),
            Size = new Size(w, h),
            ForeColor = fg,
            Font = font,
            BackColor = Color.Transparent,
        };

        public static TextBox DarkTextBox(int x, int y, int w, int h) => new TextBox
        {
            Location = new Point(x, y),
            Size = new Size(w, h),
            BackColor = BtnBg,
            ForeColor = TextMain,
            BorderStyle = BorderStyle.FixedSingle,
            Font = FontBody,
        };
    }
}
