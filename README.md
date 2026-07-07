# Darkwood Co-op — Launcher

Instalador/atualizador do mod de co-op online do Darkwood (dev/teste entre 2 amigos).

## Como usar

1. Baixe este repositório (botão verde "Code" → "Download ZIP") e extraia em qualquer pasta.
2. Abra **"Iniciar Launcher.bat"** (duplo clique).
3. No campo "SteamID64 do HOST", confirme que está com o ID do host (já vem preenchido).
4. Clique **1) Instalar BepInEx + Mod** (só na primeira vez).
5. Clique **2) Sincronizar save** (baixa o save mais recente do host).
6. Clique **4) Jogar**. Quando o Darkwood abrir e o save carregar, aperte **F8** dentro do
   jogo (você entra como cliente). O host aperta F7 do lado dele.

## Antes de CADA sessão nova

Sempre que forem jogar de novo (não só na primeira vez):

1. Rode o launcher e clique **2) Sincronizar save** de novo — isso baixa o estado mais
   recente que o host jogou da última vez.
2. Se o mod tiver sido atualizado (bug corrigido), clique também **3) Sincronizar mod**.
3. Clique **4) Jogar**.

Isso garante que vocês sempre partem do mesmo ponto. **Importante:** não avance sozinha no
save fora da sessão de co-op — se fizer isso, seu save diverge do host e a sincronização vai
descartar seu progresso solo na próxima vez que clicar "Sincronizar save".

## O que cada botão faz

- **Instalar BepInEx + Mod**: baixa o runtime do BepInEx + o plugin do mod, extrai na pasta
  do jogo, e escreve a configuração (`Mode=Steam`, `PeerSteamId64`).
- **Sincronizar save**: baixa o save mais recente que o host compartilhou, SOBRESCREVENDO o
  seu local — rodar isso antes de CADA sessão, não só na primeira vez.
- **Sincronizar mod**: baixa só a DLL mais nova do mod (não mexe no save).
- **Jogar**: abre o Darkwood pela Steam.

## Limitações atuais (é mod em desenvolvimento)

- Sem lobby por convite da Steam ainda — a conexão é P2P direto por SteamID64 (mas usa o
  relay da própria Steam, não precisa abrir porta nem VPN).
- Depois de conectar, cada um ainda aperta F7 (host) ou F8 (cliente) manualmente dentro do
  jogo.
- **O save só sincroniza ENTRE sessões (arquivo compartilhado), não durante a partida.**
  Coisas que JÁ sincronizam ao vivo enquanto jogam juntos: posição, inimigos, portas,
  móveis, containers (baú/guarda-roupa/corpo), itens largados, armadilhas. Coisas que
  **ainda NÃO sincronizam ao vivo** (podem divergir mesmo jogando juntos, não é bug):
  clima, hora do dia, eventos noturnos, flags de progressão de história. É trabalho futuro
  do mod (M5), não uma falha do save.
- **"Sincronizar save" copia o save INTEIRO do host, inclusive o inventário/personagem dele.**
  O Darkwood nativo só guarda 1 personagem por save — ainda não existe save de personagem
  separado por jogador (planejado, não implementado). Na prática: toda vez que você clicar
  "Sincronizar save", seu inventário/equipamento vira uma cópia do que o HOST tinha salvo
  naquele momento, não preserva o que você pegou/equipou sozinha da sessão anterior. Não é
  bug — é limitação conhecida, aceita por enquanto pra focar em achar bugs de sincronização
  (portas, containers, etc.), não de progressão de personagem.
