# Suma

Suma é um app leve de monitoramento de peso, gordura corporal e hidratação,
com contas locais predefinidas (sem servidor, sem nuvem) e versões para
**Windows (desktop)** e **Android**.

## Principais recursos

- **Login predefinido, sem cadastro externo.** No primeiro uso o app pede
  para criar a conta administradora; todas as demais contas são criadas e
  geridas de dentro do próprio app (aba *Usuários*, visível só para admins).
- **Registro diário** de peso (kg), gordura corporal (%) e hidratação (%),
  com histórico por usuário.
- **Exportação completa em CSV**, um arquivo por usuário, com as colunas
  `date, weight_kg, body_fat_pct, hydration_pct`. Qualquer usuário exporta os
  próprios dados na aba *Conta*; o admin pode exportar os dados de qualquer
  usuário (ou de todos de uma vez) na aba *Usuários*.
- **100% local**: os dados ficam num banco SQLite no próprio dispositivo,
  nada é enviado para fora.

## Stack técnica

Um único codebase em [Flutter](https://flutter.dev), visando o menor
conjunto de dependências possível:

| Camada             | Solução                                   |
|---------------------|-------------------------------------------|
| UI / lógica         | Flutter (Material 3)                       |
| Estado              | `provider` (ChangeNotifier)                 |
| Persistência        | SQLite via `sqflite` (Android) / `sqflite_common_ffi` (Windows) |
| Autenticação        | Hash local salgado (SHA-256, 120k rounds) — sem serviços externos |
| Exportação CSV      | Geração manual de CSV + `share_plus` (Android) / abrir pasta no Explorer (Windows) |

## Estrutura

```
lib/
  models/     - User e WeightEntry (modelos de dados)
  db/         - DatabaseService (schema + CRUD SQLite)
  services/   - AuthService (hash de senha) e CsvExportService
  state/      - AppState (ChangeNotifier central da app)
  theme/      - AppTheme (tokens de design: cores, raios, tema claro/escuro)
  utils/      - Bmi, Units (kg/lb) e Responsive (breakpoints mobile/desktop)
  widgets/    - Componentes reutilizáveis (SumaCard, StatTile, StepperField, WeightLineChart, ...)
  screens/    - Telas: setup do admin, login, onboarding, painel, histórico,
                usuários, ajustes
```

## Rodando o projeto

Pré-requisitos: [Flutter SDK](https://docs.flutter.dev/get-started/install)
(canal stable) com suporte a Windows desktop e Android habilitados.

```bash
flutter pub get

# Desktop (Windows)
flutter run -d windows

# Android (emulador ou aparelho conectado via USB debugging)
flutter run -d android
```

Gerar instalável:

```bash
# Windows
flutter build windows --release --no-tree-shake-icons

# Android (APK)
flutter build apk --release --no-tree-shake-icons
```

> **`--no-tree-shake-icons` é necessário.** Sem essa flag, o build de release
> do Flutter remove do font de ícones qualquer glyph que sua análise estática
> não consiga provar como "usado" - e ela erra em ícones referenciados
> indiretamente (dentro de ternários, StepperField, etc.), fazendo alguns
> ícones somem silenciosamente (viram um espaço em branco). O app é pequeno,
> então o custo extra de alguns KB não importa.

## Contas e segurança

- A conta administradora é criada no primeiro uso, com nome e senha
  escolhidos ali mesmo (nada vem hardcoded no código-fonte).
- Administradores podem criar novas contas (usuário comum ou admin),
  redefinir senhas e remover contas — exceto remover o último admin
  restante, para nunca travar o acesso ao app.
- Todo usuário pode trocar a própria senha e exportar os próprios dados a
  qualquer momento pela aba *Conta*.

## Status

🚧 Alpha inicial — funcionalidades essenciais (contas, registro diário,
exportação CSV) implementadas; sem testes automatizados ainda.
