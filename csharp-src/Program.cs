using System;
using System.Windows.Forms;

namespace DarkwoodCoopLauncher
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            // Auto-atualizacao roda ANTES de qualquer janela - se disparar, o
            // processo helper oculto ja cuida de reabrir a versao nova sozinho.
            if (SelfUpdater.TryUpdate()) return;

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }
}
