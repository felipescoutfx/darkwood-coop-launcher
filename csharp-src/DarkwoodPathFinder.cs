using System.IO;
using System.Text.RegularExpressions;

namespace DarkwoodCoopLauncher
{
    public static class DarkwoodPathFinder
    {
        // Tenta achar a pasta do Darkwood sozinho: caminhos padrao primeiro, depois
        // le o libraryfolders.vdf da Steam (formato texto simples, "path" "X:\\...")
        // pra achar bibliotecas Steam em outros discos.
        public static string Find()
        {
            string[] candidates =
            {
                @"C:\Program Files (x86)\Steam\steamapps\common\Darkwood",
                @"C:\Program Files\Steam\steamapps\common\Darkwood",
            };
            foreach (var c in candidates)
                if (File.Exists(Path.Combine(c, "Darkwood.exe"))) return c;

            string lf = @"C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf";
            if (File.Exists(lf))
            {
                foreach (Match m in Regex.Matches(File.ReadAllText(lf), "\"path\"\\s*\"([^\"]+)\""))
                {
                    string p = m.Groups[1].Value.Replace("\\\\", "\\");
                    string cand = Path.Combine(p, "steamapps", "common", "Darkwood");
                    if (File.Exists(Path.Combine(cand, "Darkwood.exe"))) return cand;
                }
            }
            return "";
        }
    }
}
