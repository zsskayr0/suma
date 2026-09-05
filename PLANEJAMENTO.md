# PLANEJAMENTO.md — Suma

> Plano de manutenção contínua. Atualizado a cada rodada do agente de manutenção.
> Última atualização: 2026-09-04

## Status da semana anterior

Primeira execução deste processo — não há semana anterior registrada. Estado do
repositório no início: `main` limpo, release mais recente v1.0.9 (`0d5ca67`),
feature de subperfis de pet recém-lançada (`c49d9ad`).

Trabalho feito hoje (2026-09-04):
- **[Corrigido]** `lib/screens/pet_edit_sheet.dart`: `_friendlyError` não tratava
  `PostgrestException`, então o erro do trigger de limite de pets (máx. 3) do
  Supabase aparecia como mensagem genérica em vez da mensagem real. Commit `8dddaa2`.
- **[Corrigido]** `test/widget_test.dart`: falhava desde sempre nesta sessão e
  vinha sendo tratado como "falha pré-existente/ambiental" sem nunca ser
  investigado. Causa real: o teste nunca chamava `Supabase.initialize()` antes
  de montar `SumaApp`, e `AppState` resolve `Supabase.instance.client` de forma
  eager no construtor. Commit `beb54ab`. `flutter test` completo agora passa
  100% (6/6) e `flutter analyze` está limpo — primeira vez confirmada nesta sessão.

## Bugs identificados (backlog priorizado)

- **[Média]** `lib/state/app_state.dart` — `addPetEntry`, `updatePetEntry` e
  `deletePetEntry` não chamam `notifyListeners()`, inconsistente com todo o
  resto do `AppState` (que sempre notifica após mutações). Hoje é inofensivo
  porque `PetHistoryScreen` mantém cache local próprio, mas qualquer tela nova
  que dependa do `AppState.pets`/watch não vai refletir mudanças de peso de
  pets automaticamente. Corrigir adicionando `notifyListeners()` nos 3 métodos,
  espelhando `addEntry`/`updateEntry`/`deleteEntry`.
- **[Baixa]** `lib/services/notification_service.dart` — `_nextInstanceOf` usa
  aritmética simples de `Duration(days: 1)` sobre `TZDateTime`, o que pode
  desalinhar o horário do lembrete em fusos com horário de verão (DST) no dia
  da transição. Prioridade baixa: o mercado atual do app é o Brasil, que
  aboliu o horário de verão em 2019 — sem impacto prático hoje, mas vale
  documentar/corrigir se o app ganhar usuários fora do Brasil.

## Melhorias de UI/UX propostas (não implementadas — só registro)

Nenhuma proposta nova hoje além do que já foi entregue (gráfico de peso,
insights, tela de IMC, subperfis de pet). Sem sugestões pendentes de UI/UX
neste momento.

## Plano dos próximos 5 dias úteis

1. Corrigir o `notifyListeners()` ausente em `addPetEntry`/`updatePetEntry`/`deletePetEntry`.
2. Revisar `lib/services/notification_service.dart` por completo (schedule,
   cancelamento, permissões Android 13+) em busca de bugs reais — só foi lido
   para o levantamento de hoje, sem varredura profunda ainda.
3. Revisar `lib/screens/admin_users_screen.dart` (arquivo que teve edições
   grandes recentes na feature de pets) linha a linha à procura de qualquer
   sobra da refatoração (já foi corrigido um bracket órfão durante a
   implementação, mas vale uma segunda leitura fria).
4. Avaliar adicionar 1-2 testes de widget cobrindo fluxos críticos hoje sem
   cobertura nenhuma (ex.: adicionar/editar pet, abrir tela de IMC) — repo
   tem muito pouca cobertura automatizada.
5. Ler `lib/screens/settings_screen.dart` e `lib/screens/dashboard_screen.dart`
   por completo (arquivos grandes, muito modificados nesta sessão) em busca
   de bugs reais introduzidos pelas últimas features.

## Riscos / observações

- O build Windows depende de um patch manual fora do repositório (CMakeLists.txt
  do `flutter_local_notifications_windows` no pub cache local, para resolver
  ATL/MSVC) — some se `pub cache repair` rodar, se a versão do plugin mudar, ou
  em uma máquina nova. Ver `build_windows_release.bat`/`build_windows_devenv.bat`
  no scratchpad da sessão para o wrapper `vcvars64.bat -vcvars_ver=14.44`
  necessário.
- Repo tem cobertura de teste automatizado mínima (2 arquivos de teste antes
  de hoje). A maior parte da verificação de bugs nesta sessão foi leitura
  manual de código + raciocínio, não testes automatizados — regressões silenciosas
  em áreas não lidas ainda são um risco real.
