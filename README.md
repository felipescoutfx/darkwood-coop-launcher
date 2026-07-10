# Darkwood Co-op — Launcher

Instalador/atualizador do mod de co-op online do Darkwood (dev/teste entre amigos).

## Primeira vez

1. Baixe **[DarkwoodCoopLauncher.exe](https://github.com/felipescoutfx/darkwood-coop-launcher/raw/main/DarkwoodCoopLauncher.exe)** (um arquivo só — sem zip, sem instalar nada) e dê duplo clique.
   - O Windows/SmartScreen pode avisar "editor desconhecido" (o `.exe` não é assinado digitalmente) — clique em **Mais informações → Executar assim mesmo**. É esperado num programa de teste entre amigos, não é vírus.
2. Confira a **Pasta do Darkwood** no topo (o launcher tenta achar sozinho).
3. Na aba **Principal**, clique **Instalar BepInEx + Mod**.
4. Clique **Jogar**.

**Host e cliente usam o mesmo launcher** — os dois instalam o mod do mesmo jeito.

O launcher se **atualiza sozinho**: toda vez que abre, confere se tem uma versão nova
publicada aqui e, se tiver, baixa e reabre automaticamente — nunca precisa baixar o `.exe`
nem o repositório de novo por causa de uma atualização do launcher em si.

## Como jogar juntos (fluxo novo, por convite da Steam)

- **HOST:** abre o jogo, carrega o save, aperta **F7** (hospedar). Depois convida o amigo
  pela **lista de amigos da Steam** (botão "Entrar no jogo" / "Convidar para o jogo").
- **CLIENTE:** clica em **"Entrar no jogo"** na Steam. **Não precisa fazer mais nada** — o
  mod baixa o save do host, carrega sozinho e conecta automaticamente.

O save do host é gravado como um **save novo** na sua lista de perfis (não apaga os seus).
Cada host ganha um slot fixo — reconectar no mesmo host sempre reusa o mesmo slot.

## Atualização do mod

Ao abrir o launcher, ele avisa (em laranja, na aba Principal) se tem uma **versão nova do
mod** publicada. Se avisar, clique **Atualizar mod**.

## Aba Avançado (só se precisar)

- **SteamID64 do host** + **Puxar save do host AGORA (P2P)**: baixa o save do host ANTES de
  abrir o jogo (o host precisa estar com o Darkwood aberto). Útil se não quiser usar o
  convite da Steam.
- **Sincronizar save (método antigo)**: baixa um save publicado manualmente no repo,
  SOBRESCREVENDO o seu. Só use se os outros métodos não servirem.
- **Enviar log pro desenvolvedor**: se algo der errado, este botão sobe o log do jogo e gera
  um **link** (copiado automaticamente). Mande esse link pro desenvolvedor pra ele ver o que
  aconteceu.

## Limitações atuais (mod em desenvolvimento)

- O host precisa apertar **F7** pra hospedar (decisão de design — o host controla quando
  abre pra co-op).
- Clima, hora do dia, eventos noturnos e flags de história ainda podem divergir durante a
  partida (trabalho futuro). O que já sincroniza ao vivo: posição, inimigos, portas, móveis,
  containers, itens largados, armadilhas, estado de "caído"/reanimar.
- Save de personagem por jogador (inventário/vida por SteamID) é novo e pouco testado.
