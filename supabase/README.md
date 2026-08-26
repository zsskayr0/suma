# Configurando o Supabase (rede familiar entre aparelhos)

Passo a passo pra deixar o Suma pronto pra contas cross-device (login em
qualquer celular/PC, redes familiares com convite). Nenhum desses passos eu
consigo fazer por você — precisa de uma conta sua.

## 1. Criar o projeto

1. Acesse [supabase.com](https://supabase.com) e crie uma conta (dá pra
   entrar com GitHub).
2. **New project** → escolha um nome (ex: `suma`), uma senha de banco (guarde
   num lugar seguro, é só pra emergência, o app não usa ela) e a região mais
   próxima de você.
3. Espere o projeto provisionar (leva 1-2 minutos).

## 2. Rodar o schema

1. No painel do projeto, vá em **SQL Editor** (ícone de terminal na barra
   lateral) → **New query**.
2. Cole o conteúdo inteiro de [`schema.sql`](./schema.sql) (deste mesmo
   diretório) e clique em **Run**.
3. Deve terminar sem erro. Se der algum erro, me manda a mensagem completa
   que eu ajusto o script.

## 3. Conferir a autenticação por e-mail

1. **Authentication → Providers** → confirme que **Email** está habilitado
   (vem habilitado por padrão).
2. **Authentication → Settings** → se quiser pular a confirmação por e-mail
   durante os testes (mais rápido pra você e sua família começarem a usar),
   desative **Confirm email**. Pode reativar depois se quiser mais segurança.

## 4. Pegar a URL e a chave do projeto

1. **Project Settings** (ícone de engrenagem) → **API**.
2. Copie:
   - **Project URL** (algo como `https://xxxxxxxxxxxx.supabase.co`)
   - **anon public** key (uma string longa - é segura pra colocar no app,
     é a chave pública protegida pelas regras de RLS que já estão no
     `schema.sql`)
3. Me manda os dois valores (pode ser aqui mesmo no chat) que eu já deixo o
   app conectado.

**Não me mande a `service_role` key** (essa é secreta, tem acesso total ao
banco ignorando as regras de privacidade - o app nunca precisa dela).

## O que muda no app

- Login passa a ser por e-mail + senha (em vez de usuário local
  predefinido), pra funcionar em qualquer aparelho.
- Tela inicial passa a oferecer duas opções: **Criar minha rede** (você vira
  admin de uma família nova, ganha um código de convite pra compartilhar) ou
  **Entrar com código de convite** (você digita o código de alguém que já
  tem uma rede e entra como membro).
- Cada pessoa só edita os próprios registros. O admin da família pode ver
  (não editar) os registros de todo mundo da mesma rede - igual funcionava
  localmente com a aba Usuários.
- Vai passar a precisar de internet pra entrar/sincronizar (igual WhatsApp).
