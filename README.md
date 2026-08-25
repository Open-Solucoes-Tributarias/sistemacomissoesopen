# Comissões — Open Soluções Tributárias

Sistema de controle de vendas, comissões, parceiros e pagamentos da equipe comercial.

## Stack

- **Frontend**: HTML + JavaScript puro (nenhum framework, nenhuma etapa de build).
- **Banco de dados**: [Supabase](https://supabase.com) (Postgres).
- **Hospedagem**: qualquer serviço de site estático (Vercel, Netlify, GitHub Pages...).

## Estrutura do projeto

```
.
├── index.html                       → aplicação inteira (HTML + CSS + JS em um único arquivo)
├── README.md                        → este arquivo
├── supabase_schema.sql              → script completo para recriar o banco do zero
├── supabase_security_migration.sql  → migração de segurança para um banco já existente (ver abaixo)
└── .gitignore
```

## Login e segurança

O sistema exige login (e-mail e senha) antes de mostrar qualquer dado. Não existe cadastro público pela tela — as contas da equipe são criadas manualmente por um administrador no painel do Supabase (veja "Criando contas da equipe" abaixo). Depois de logada, a pessoa continua com sessão salva no navegador até clicar em "Sair".

- **URL do projeto Supabase**: `https://ogkrrlssdrtctdyyvkql.supabase.co`
- **Chave pública (anon key)**: já está embutida no `index.html` (constante `SUPABASE_ANON_KEY`). Essa chave é **pública por padrão no Supabase** — sozinha, ela não abre porta nenhuma: quem decide o que pode ser lido/escrito são as políticas de RLS do banco, e elas agora exigem estar logado (`to authenticated`, não mais `to anon`).
- **Modelo de acesso**: como antes, não existe "dono" por lançamento — qualquer pessoa logada pode ver e editar qualquer registro (é assim que a equipe usa o sistema no dia a dia). A diferença é que agora é preciso ter uma conta válida pra entrar; só ter o link não basta mais.

### Criando contas da equipe

1. No painel do Supabase, vá em **Authentication → Users → Add user**.
2. Preencha e-mail e uma senha provisória para a pessoa (marque "Auto Confirm User" pra já liberar o acesso sem precisar confirmar e-mail).
3. Passe o e-mail e a senha provisória pra pessoa por um canal seguro; ela pode trocar a senha depois pelo link **"Esqueci minha senha"** na tela de login.
4. Repita para cada integrante da equipe.

Por padrão o Supabase também aceita auto-cadastro pela API (mesmo sem botão de cadastro na tela). Para bloquear isso, vá em **Authentication → Providers → Email** e desmarque **"Allow new users to sign up"**.

### Migrando um projeto já existente (importante!)

Se você já tem esse sistema rodando com o banco antigo (liberado por link, sem login), siga esta ordem pra não travar o acesso da equipe:

1. Crie a conta de cada pessoa da equipe (passo acima).
2. Rode o script `supabase_security_migration.sql` no **SQL Editor** do Supabase — ele troca as políticas de RLS de "qualquer um com a chave" para "só quem está logado".
3. Só depois publique esta versão atualizada do `index.html`.

Se pular o passo 1 antes do 2, ninguém consegue mais entrar até as contas serem criadas.

### Tabelas criadas

| Tabela | Conteúdo |
|---|---|
| `vendas` | Lançamentos da aba Sistema |
| `vendas_comissoes` | Comissão de cada vendedor(a) por lançamento do Sistema |
| `lancamentos` | Lançamentos de Consultoria, Consultoria Órgãos Públicos e Cursos (uma tabela só, filtrada pela coluna `entidade`) |
| `lancamentos_extra_vendedores` | Vendedores extras (4º em diante) por lançamento |
| `bonus` | Bônus e metas batidas |
| `metas` | Metas mensais por vendedor(a) |
| `partners` | Parceiros cadastrados |
| `venda_products` | Catálogo de produtos da aba Sistema |
| `sellers` | Vendedoras do Sistema (lista editável) |
| `entity_vendors` | Vendedores(as) cadastrados por aba (Consultoria / Órgãos Públicos / Cursos) |
| `closed_months` | Meses fechados para edição |
| `extra_years` | Anos adicionados manualmente |

Se precisar recriar o banco do zero em outro projeto Supabase, o script de criação das tabelas está em `supabase_schema.sql` (gerado junto com este projeto).

## Rodando localmente

Não precisa de nenhuma instalação. Basta abrir o `index.html` num navegador, ou servir a pasta com qualquer servidor estático:

```bash
npx serve .
```

## Deploy no Vercel

1. Suba este projeto pra um repositório no GitHub (veja passo a passo abaixo).
2. Entre em [vercel.com](https://vercel.com) → **Add New → Project**.
3. Selecione o repositório do GitHub.
4. Como é um site estático (sem build), deixe as configurações padrão — não precisa de "Build Command" nem "Output Directory".
5. Clique em **Deploy**.

Pronto — a Vercel te dá uma URL pública (tipo `seu-projeto.vercel.app`) que já é o site funcionando, direto conectado ao banco Supabase.

## Subindo pro GitHub (passo a passo)

1. Crie uma conta no [github.com](https://github.com) se ainda não tiver.
2. Clique em **New repository** (botão verde no canto superior direito).
3. Dê um nome (ex: `comissoes-open-tributarias`), marque como **Private** (recomendado, já que tem dados comerciais) e clique em **Create repository**.
4. Na tela que aparece, clique em **uploading an existing file** e arraste os arquivos deste projeto (`index.html`, `README.md`, `.gitignore`, `supabase_schema.sql`, `supabase_security_migration.sql`).
5. Clique em **Commit changes**.

Pronto, o código está no GitHub. Agora é só seguir o passo "Deploy no Vercel" acima.

## Backup manual

Dentro do próprio sistema, o botão **"⬇ Exportar dados"** (no topo da tela) gera um backup completo em texto — útil pra guardar uma cópia de segurança de vez em quando, independente do banco de dados.

## Segurança — revisão feita neste projeto

- **Login obrigatório**: o acesso deixou de ser "quem tem o link, edita" — agora é preciso login (Supabase Auth) e o banco só aceita requisições autenticadas. Veja "Login e segurança" acima.
- **Falha de XSS corrigida**: os nomes de vendedoras (aba Sistema) e de vendedores por aba eram inseridos em alguns lugares da tela sem escapar caracteres especiais, permitindo que um nome malicioso injetasse HTML/JavaScript na tela de outras pessoas da equipe. Todos os pontos foram corrigidos para escapar esse texto (ou usar atributos `data-*` em vez de montar o JavaScript do botão como texto).
- **Content-Security-Policy**: foi adicionada uma política restritiva (`script-src`, `connect-src` limitado ao domínio do Supabase, sem `object-src`, sem `form-action`) como camada extra de proteção contra XSS futuro.
- **Sessão com renovação automática**: o token de login é renovado sozinho antes de expirar; se a renovação falhar (ex: sessão revogada), a pessoa volta pra tela de login em vez de o sistema travar ou salvar dados sem permissão.
- **Recuperação de senha**: a tela de login tem "Esqueci minha senha", que usa o fluxo de recuperação por e-mail do Supabase — ninguém depende de admin pra trocar senha esquecida.
