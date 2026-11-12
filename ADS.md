# Anúncios (AdMob)

O jogo já vem com anúncios premiados funcionando em **modo de teste** (IDs de teste do Google).
Anúncio de teste não paga nada. Para ganhar dinheiro de verdade:

1. Crie a conta em https://admob.google.com (mesma conta Google da Play Console).
2. **Apps → Adicionar app → Android**. Se o jogo ainda não está na loja, marque "não" e dê o nome SkyPort Tycoon.
3. Copie o **ID do app** (formato `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`) e cole em `admob_app_id.txt`.
4. No app, **Blocos de anúncios → Adicionar → Premiado**. Copie o **ID do bloco**
   (formato `ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ`) e cole em `lib/core/ads/ads_config.dart`, no campo `rewardedAndroid`.
5. Faça um build novo.

Onde aparece anúncio (sempre opcional, a pessoa escolhe assistir):
minijogos a partir da 2ª partida, Lucro x2, dobrar ganhos offline, giro extra da roleta,
baú antes da hora, cofrinho e oferta relâmpago. A primeira vez de cada um é livre.

Importante: nunca clique nos seus próprios anúncios reais; use os de teste enquanto estiver testando.
