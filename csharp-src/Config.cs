using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace DarkwoodCoopLauncher
{
    // Config simples (4 campos, sempre string) - JSON escrito/lido a mao pra nao
    // precisar de nenhuma dependencia externa (Newtonsoft.Json so existe do lado
    // do jogo, nao do launcher, que roda fora do processo do Darkwood - trazer
    // isso so pra 4 campos planos seria dependencia demais pra um exe que quer
    // continuar sendo um arquivo unico e autossuficiente).
    public sealed class Config
    {
        public string PeerSteamId64 = "";
        public string DarkwoodPath = "";
        public string InstalledModVersion = "";
        public string Lang = "";

        public static string ConfigDir => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "DarkwoodCoopLauncher");
        public static string ConfigFile => Path.Combine(ConfigDir, "config.json");

        public static Config Load()
        {
            Directory.CreateDirectory(ConfigDir);
            var cfg = new Config();
            if (!File.Exists(ConfigFile)) return cfg;
            try
            {
                string json = File.ReadAllText(ConfigFile, Encoding.UTF8);
                cfg.PeerSteamId64 = ExtractField(json, "PeerSteamId64") ?? "";
                cfg.DarkwoodPath = ExtractField(json, "DarkwoodPath") ?? "";
                cfg.InstalledModVersion = ExtractField(json, "InstalledModVersion") ?? "";
                cfg.Lang = ExtractField(json, "Lang") ?? "";
            }
            catch { /* config corrompido/ilegivel - segue com os padroes vazios */ }
            return cfg;
        }

        public void Save()
        {
            Directory.CreateDirectory(ConfigDir);
            string json = "{\n" +
                $"  \"PeerSteamId64\": \"{JsonEscape(PeerSteamId64)}\",\n" +
                $"  \"DarkwoodPath\": \"{JsonEscape(DarkwoodPath)}\",\n" +
                $"  \"InstalledModVersion\": \"{JsonEscape(InstalledModVersion)}\",\n" +
                $"  \"Lang\": \"{JsonEscape(Lang)}\"\n" +
                "}";
            File.WriteAllText(ConfigFile, json, Encoding.UTF8);
        }

        private static string ExtractField(string json, string name)
        {
            var m = Regex.Match(json, "\"" + Regex.Escape(name) + "\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"");
            return m.Success ? JsonUnescape(m.Groups[1].Value) : null;
        }

        private static string JsonEscape(string s) =>
            (s ?? "").Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", "\\r").Replace("\n", "\\n");

        private static string JsonUnescape(string s) =>
            s.Replace("\\r", "\r").Replace("\\n", "\n").Replace("\\\"", "\"").Replace("\\\\", "\\");
    }
}
