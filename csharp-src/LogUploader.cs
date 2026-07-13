using System.IO;
using System.Net.Http;
using System.Text;

namespace DarkwoodCoopLauncher
{
    // Sobe o log pra um link temporario. ACHADO NESTA REESCRITA: a versao antiga
    // (PowerShell) mandava pro 0x0.st, que ja tinha sido descoberto desativado
    // permanentemente pro save (ver Net/SaveRelay.cs no mod - por isso o mod ja
    // usa litterbox.catbox.moe) - o launcher ficou pra tras usando o servico
    // morto. Corrigido aqui pra usar o mesmo litterbox.catbox.moe (validade 1h,
    // sobra o suficiente pra colar o link e mandar pro desenvolvedor).
    public static class LogUploader
    {
        private const string UploadUrl = "https://litterbox.catbox.moe/resources/internals/api.php";
        private const int MaxChars = 2_000_000; // limita ao final se o log for enorme

        public static string Upload(string filePath)
        {
            if (!File.Exists(filePath)) return null;

            string content = File.ReadAllText(filePath);
            if (content.Length > MaxChars)
                content = "...(log truncado, mostrando o final)...\r\n" + content.Substring(content.Length - MaxChars);

            using (var http = new HttpClient())
            using (var form = new MultipartFormDataContent())
            {
                form.Add(new StringContent("fileupload"), "reqtype");
                form.Add(new StringContent("1h"), "time");
                var fileContent = new ByteArrayContent(Encoding.UTF8.GetBytes(content));
                fileContent.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("text/plain");
                form.Add(fileContent, "fileToUpload", "LogOutput.log");

                var resp = http.PostAsync(UploadUrl, form).GetAwaiter().GetResult();
                string url = resp.Content.ReadAsStringAsync().GetAwaiter().GetResult().Trim();
                return resp.IsSuccessStatusCode && url.StartsWith("http") ? url : null;
            }
        }
    }
}
