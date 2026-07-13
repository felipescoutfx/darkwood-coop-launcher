using System.Collections.Generic;

namespace DarkwoodCoopLauncher
{
    // Todo texto visivel pro usuario vive aqui, nunca hardcoded direto num
    // controle - troca de idioma = reiniciar com Lang diferente (mais simples e
    // confiavel que re-traduzir controles ja criados ao vivo). Placeholders
    // {0}/{1} pra valores dinamicos, usados com string.Format.
    public static class Strings
    {
        public static string Lang = "pt";

        public static string T(string key) => (Lang == "en" ? En : Pt)[key];

        public static readonly Dictionary<string, string> Pt = new Dictionary<string, string>
        {
            ["WindowTitle"] = "Darkwood Co-op - Launcher",
            ["TitleBar"] = "DARKWOOD  //  CO-OP LAUNCHER",
            ["FolderLabel"] = "PASTA DO DARKWOOD",
            ["NavMain"] = "PRINCIPAL",
            ["NavAdv"] = "AVANCADO",
            ["ErrorTitle"] = "Erro",
            ["ConfirmTitle"] = "Confirmar",
            ["InvalidFolder"] = "Pasta do Darkwood invalida. Escolha a pasta onde fica o Darkwood.exe.",
            ["Intro"] = "1) Instale o mod (primeira vez). 2) Abra o jogo. Para jogar juntos, o HOST\r\nabre o jogo, carrega o save e aperta F7 (ou clica HOST no menu). O amigo\r\nclica JOIN no menu ou entra pela lista de amigos da Steam - o resto e automatico.",
            ["BtnInstall"] = "INSTALAR BEPINEX + MOD (1a vez)",
            ["BtnSyncMod"] = "ATUALIZAR MOD (baixar versao mais nova)",
            ["BtnPlay"] = "JOGAR  (abre o Darkwood pela Steam)",
            ["DownloadingBepInEx"] = "Baixando BepInEx...",
            ["DownloadingMod"] = "Baixando mod...",
            ["Installed"] = "Instalado! Abra o jogo pelo botao Jogar.",
            ["ErrorPrefix"] = "Erro: {0}",
            ["DownloadingLatestMod"] = "Baixando ultima versao do mod...",
            ["ModUpdated"] = "Mod atualizado para a versao {0}.",
            ["OpeningSteam"] = "Abrindo o jogo pela Steam...",
            ["SteamIdLabel"] = "STEAMID64 DO HOST (so pro metodo manual F7/F8 - convite Steam e os botoes HOST/JOIN do menu nao precisam)",
            ["BtnUpdateCfg"] = "ATUALIZAR .cfg COM ESTE STEAMID64",
            ["FillSteamIdCfg"] = "Preencha o SteamID64 antes de atualizar o .cfg.",
            ["CfgUpdated"] = ".cfg atualizado com PeerSteamId64={0} e Mode=Steam. Reabra o jogo se ja estava aberto.",
            ["ErrorUpdatingCfg"] = "Erro atualizando .cfg: {0}",
            ["BtnSendLog"] = "ENVIAR LOG PRO DESENVOLVEDOR (gera um link)",
            ["LogNotFound"] = "Log nao encontrado em {0} (o jogo ja rodou com o mod?).",
            ["SendingLog"] = "Enviando log...",
            ["LogSendFailed"] = "Falha ao enviar o log.",
            ["LogLinkText"] = "Link do log (mande pro desenvolvedor):\r\n{0}\r\n",
            ["LogSent"] = "Log enviado! O link foi copiado - cole e mande pro desenvolvedor.",
            ["ErrorSendingLog"] = "Erro ao enviar log: {0}",
            ["Ready"] = "Pronto.",
            ["ModVersionInRepo"] = "Versao do mod no repo: {0} (instale/atualize pra registrar a sua).",
            ["NewModVersion"] = "NOVA VERSAO DO MOD ({0}) disponivel! Clique em Atualizar mod. (sua: {1})",
            ["ModUpToDate"] = "Mod atualizado (versao {0}).",
            ["LangToggle"] = "EN",
        };

        public static readonly Dictionary<string, string> En = new Dictionary<string, string>
        {
            ["WindowTitle"] = "Darkwood Co-op - Launcher",
            ["TitleBar"] = "DARKWOOD  //  CO-OP LAUNCHER",
            ["FolderLabel"] = "DARKWOOD FOLDER",
            ["NavMain"] = "MAIN",
            ["NavAdv"] = "ADVANCED",
            ["ErrorTitle"] = "Error",
            ["ConfirmTitle"] = "Confirm",
            ["InvalidFolder"] = "Invalid Darkwood folder. Choose the folder where Darkwood.exe is located.",
            ["Intro"] = "1) Install the mod (first time). 2) Open the game. To play together, the HOST\r\nopens the game, loads the save and presses F7 (or clicks HOST in the menu).\r\nYour friend clicks JOIN in the menu or their Steam friends list - the rest is automatic.",
            ["BtnInstall"] = "INSTALL BEPINEX + MOD (first time)",
            ["BtnSyncMod"] = "UPDATE MOD (download latest version)",
            ["BtnPlay"] = "PLAY  (opens Darkwood via Steam)",
            ["DownloadingBepInEx"] = "Downloading BepInEx...",
            ["DownloadingMod"] = "Downloading mod...",
            ["Installed"] = "Installed! Open the game with the Play button.",
            ["ErrorPrefix"] = "Error: {0}",
            ["DownloadingLatestMod"] = "Downloading latest mod version...",
            ["ModUpdated"] = "Mod updated to version {0}.",
            ["OpeningSteam"] = "Opening the game via Steam...",
            ["SteamIdLabel"] = "HOST'S STEAMID64 (only for the manual F7/F8 method - the Steam invite and the menu's HOST/JOIN buttons don't need this)",
            ["BtnUpdateCfg"] = "UPDATE .cfg WITH THIS STEAMID64",
            ["FillSteamIdCfg"] = "Fill in the SteamID64 before updating the .cfg.",
            ["CfgUpdated"] = ".cfg updated with PeerSteamId64={0} and Mode=Steam. Reopen the game if it was already open.",
            ["ErrorUpdatingCfg"] = "Error updating .cfg: {0}",
            ["BtnSendLog"] = "SEND LOG TO DEVELOPER (generates a link)",
            ["LogNotFound"] = "Log not found at {0} (has the game run with the mod yet?).",
            ["SendingLog"] = "Sending log...",
            ["LogSendFailed"] = "Failed to send the log.",
            ["LogLinkText"] = "Log link (send this to the developer):\r\n{0}\r\n",
            ["LogSent"] = "Log sent! The link was copied - paste it and send it to the developer.",
            ["ErrorSendingLog"] = "Error sending log: {0}",
            ["Ready"] = "Ready.",
            ["ModVersionInRepo"] = "Mod version in repo: {0} (install/update to register yours).",
            ["NewModVersion"] = "NEW MOD VERSION ({0}) available! Click Update mod. (yours: {1})",
            ["ModUpToDate"] = "Mod up to date (version {0}).",
            ["LangToggle"] = "PT",
        };
    }
}
