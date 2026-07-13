using System;
using System.Diagnostics;
using System.IO;
using System.Net.Http;

namespace DarkwoodCoopLauncher
{
    // Auto-atualizacao do PROPRIO launcher. Antes de mostrar a janela principal,
    // confere se ha uma versao mais nova publicada (launcher_version.txt no
    // repo) e, se houver, baixa o .exe novo, troca o arquivo por um processo
    // auxiliar OCULTO (o processo atual nao pode sobrescrever o proprio .exe em
    // uso) e reabre sozinho. Falha de rede aqui NUNCA bloqueia o uso - so segue
    // com a versao atual.
    public static class SelfUpdater
    {
        public const string LauncherVersion = "2026-07-13.1";
        private const string RepoRaw = "https://raw.githubusercontent.com/felipescoutfx/darkwood-coop-launcher/main";
        private const string LauncherExeUrl = "https://github.com/felipescoutfx/darkwood-coop-launcher/releases/latest/download/DarkwoodCoopLauncher.exe";

        // Retorna true se disparou a atualizacao (o chamador deve sair na hora,
        // sem mostrar janela nenhuma - o helper oculto vai reabrir sozinho).
        public static bool TryUpdate()
        {
            string markerPath = Path.Combine(Config.ConfigDir, ".just_updated");

            // TRAVA CONTRA LOOP INFINITO: se o launcher_version.txt publicado ficar
            // dessincronizado do .exe publicado de verdade, a instancia recem-
            // atualizada baixaria o MESMO exe de novo e reabriria em loop. Marcador
            // com timestamp (< 2 min = acabou de se atualizar) evita isso.
            if (File.Exists(markerPath))
            {
                var age = DateTime.UtcNow - File.GetLastWriteTimeUtc(markerPath);
                try { File.Delete(markerPath); } catch { }
                if (age.TotalMinutes < 2) return false;
            }

            string exePath = Process.GetCurrentProcess().MainModule.FileName;

            string latest;
            try
            {
                using (var http = new HttpClient { Timeout = TimeSpan.FromSeconds(5) })
                    latest = http.GetStringAsync($"{RepoRaw}/launcher_version.txt").GetAwaiter().GetResult().Trim();
            }
            catch { return false; }

            // So atualiza se a remota for ESTRITAMENTE MAIS NOVA (ordem lexicografica
            // normal funciona no formato AAAA-MM-DD.N) - nunca faz downgrade.
            if (string.IsNullOrEmpty(latest) || string.CompareOrdinal(latest, LauncherVersion) <= 0) return false;

            string newExePath = exePath + ".new";
            try
            {
                using (var http = new HttpClient())
                {
                    var bytes = http.GetByteArrayAsync(LauncherExeUrl).GetAwaiter().GetResult();
                    File.WriteAllBytes(newExePath, bytes);
                }

                // Se o arquivo baixado for IDENTICO (mesmo tamanho) ao atual, nao e
                // uma atualizacao de verdade - ignora.
                long curSize = new FileInfo(exePath).Length;
                long newSize = new FileInfo(newExePath).Length;
                if (curSize == newSize)
                {
                    TryDelete(newExePath);
                    return false;
                }

                // Marca ANTES de disparar o helper - a proxima instancia (recem
                // atualizada) le e apaga isso no proprio TryUpdate, acima.
                File.WriteAllText(markerPath, DateTime.UtcNow.Ticks.ToString());

                // cmd oculto: espera este processo soltar o arquivo, troca, reabre.
                string helperArgs = $"/c timeout /t 1 /nobreak >nul & move /y \"{newExePath}\" \"{exePath}\" >nul & start \"\" \"{exePath}\"";
                Process.Start(new ProcessStartInfo
                {
                    FileName = "cmd.exe",
                    Arguments = helperArgs,
                    WindowStyle = ProcessWindowStyle.Hidden,
                    CreateNoWindow = true,
                });
                return true;
            }
            catch
            {
                TryDelete(newExePath);
                TryDelete(markerPath);
                return false;
            }
        }

        private static void TryDelete(string path)
        {
            try { if (File.Exists(path)) File.Delete(path); } catch { }
        }
    }
}
