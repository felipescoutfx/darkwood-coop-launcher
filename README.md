# Darkwood Co-op — Launcher

Instalador/atualizador do mod de co-op online do Darkwood (dev/teste entre 2 amigos).

## Como usar

1. Baixe este repositório (botão verde "Code" → "Download ZIP") e extraia em qualquer pasta.
2. Abra **"Iniciar Launcher.bat"** (duplo clique).
3. No campo "SteamID64 do HOST", confirme que está com o ID do host (já vem preenchido).
4. Clique **1) Instalar BepInEx + Mod** (só na primeira vez).
5. Clique **2) Baixar save inicial** (só na primeira vez — depois disso o save é seu, não
   sobrescreve mais sozinho).
6. Clique **4) Jogar**. Quando o Darkwood abrir e o save carregar, aperte **F8** dentro do
   jogo (você entra como cliente). O host aperta F7 do lado dele.
7. Quando o mod for atualizado (bug corrigido etc.), rode o launcher de novo e clique só em
   **3) Sincronizar mod**.

## O que cada botão faz

- **Instalar BepInEx + Mod**: baixa o runtime do BepInEx + o plugin do mod, extrai na pasta
  do jogo, e escreve a configuração (`Mode=Steam`, `PeerSteamId64`).
- **Baixar save inicial**: baixa um save compartilhado pra os dois começarem no mesmo mapa
  (o jogo ainda não sincroniza o mundo pela rede — o "mesmo mapa" vem de carregar o mesmo
  save nas duas máquinas).
- **Sincronizar mod**: baixa só a DLL mais nova do mod (não mexe no save).
- **Jogar**: abre o Darkwood pela Steam.

## Limitações atuais (é mod em desenvolvimento)

- Sem lobby por convite da Steam ainda — a conexão é P2P direto por SteamID64 (mas usa o
  relay da própria Steam, não precisa abrir porta nem VPN).
- Depois de conectar, cada um ainda aperta F7 (host) ou F8 (cliente) manualmente dentro do
  jogo.
- O save não sincroniza sozinho durante a partida — arquivos que saem do mundo (baú,
  corpo) sincronizam; o save em si é só o ponto de partida.
