# Comissões — Open Soluções Tributárias

Sistema de controle de vendas, comissões, parceiros e pagamentos da equipe comercial.

## Stack

- **Frontend**: HTML + JavaScript puro (nenhum framework, nenhuma etapa de build).
- **Banco de dados**: [Supabase](https://supabase.com) (Postgres).
- **Hospedagem**: qualquer serviço de site estático (Vercel, Netlify, GitHub Pages...).

## Estrutura do projeto

```
.
├── index.html                          → aplicação inteira (HTML + CSS + JS em um único arquivo)
├── README.md                           → este arquivo
├── supabase_schema.sql                 → script completo para recriar o banco do zero
├── supabase_security_migration.sql     → migração 1: exige login (banco liberado por link → autenticado)
├── supabase_row_access_migration.sql   → migração 2: acesso por pessoa (admin x conta restrita)
├── supabase_column_masking_migration.sql → migração 3: esconde os dados dos colegas dentro de um lançamento compartilhado
├── supabase_hardening_migration.sql     → migração 4: correções da conferência (ver "Segurança")
└── .gitignore
```

## Login e segurança

O sistema exige login (e-mail e senha) antes de mostrar qualquer dado. Não existe cadastro público pela tela — as contas da equipe são criadas manualmente por um administrador no painel do Supabase (veja "Criando contas da equipe" abaixo). Depois de logada, a pessoa continua com sessão salva no navegador até clicar em "Sair".

- **URL do projeto Supabase**: `https://ogkrrlssdrtctdyyvkql.supabase.co`
- **Chave pública (anon key)**: já está embutida no `index.html` (constante `SUPABASE_ANON_KEY`). Essa chave é **pública por padrão no Supabase** — sozinha, ela não abre porta nenhuma: quem decide o que pode ser lido/escrito são as políticas de RLS do banco.
- **Modelo de acesso — duas categorias de conta**:
  - **Admin** (Soraya, Deborah, Open): vê e edita todos os dados do sistema, em todas as abas.
  - **Restrita** (Gustavo, Rios, Luciana, Angela): só **visualiza**, em modo somente leitura, os lançamentos onde o nome da pessoa aparece como vendedor(a) ou colaborador(a) — nunca vê nem edita o que é dos colegas. Isso existe pra ninguém comparar comissão de ninguém.

  Um mesmo contrato pode ter até 3 vendedores + colaborador na mesma linha. Nesses contratos divididos, a pessoa vê o lançamento e a **própria** comissão, mas o nome e a porcentagem dos colegas vêm em branco — o corte é feito coluna a coluna, pelas views `_safe` do banco (veja `supabase_column_masking_migration.sql`).
  
  Quem é admin e quem é restrito (e qual nome cada conta restrita representa) fica guardado na tabela `app_user_access`, ligada à conta de login de cada pessoa — não é algo que o próprio app deixa alguém mudar sozinho.

### Criando contas da equipe

1. No painel do Supabase, vá em **Authentication → Users → Add user**.
2. Preencha e-mail e uma senha provisória para a pessoa (marque "Auto Confirm User" pra já liberar o acesso sem precisar confirmar e-mail).
3. Passe o e-mail e a senha provisória pra pessoa por um canal seguro; ela pode trocar a senha depois pelo link **"Esqueci minha senha"** na tela de login.
4. Dê o nível de acesso pra ela rodando no **SQL Editor** do Supabase:

```sql
-- Admin: vê e edita tudo
insert into app_user_access (auth_user_id, full_access, person_name)
select id, true, null from auth.users where email = 'admin@empresa.com.br';

-- Restrita: só o que tiver o nome dela como vendedor/colaborador nos lançamentos
insert into app_user_access (auth_user_id, full_access, person_name)
select id, false, 'Nome Como Aparece Nos Lançamentos' from auth.users where email = 'vendedor@empresa.com.br';
```

O `person_name` precisa bater (sem diferenciar maiúscula/minúscula, ignorando espaço nas pontas) com o nome usado nos campos de vendedor/colaborador das abas Sistema, Consultoria, Órgãos Públicos, Cursos e Bônus. Se a pessoa aparecer com nomes diferentes em lugares diferentes (ex: "Rios" numa aba e "Ana Rios" em outra), só um desses nomes vai casar — vale a pena padronizar o nome nos lançamentos antes de cadastrar o acesso.

5. Repita para cada integrante da equipe. Sem uma linha em `app_user_access`, a conta consegue logar mas não vê nenhum dado.

Por padrão o Supabase também aceita auto-cadastro pela API (mesmo sem botão de cadastro na tela). Para bloquear isso, vá em **Authentication → Providers → Email** e desmarque **"Allow new users to sign up"**.

### Migrando um projeto já existente (importante!)

Se você já tem esse sistema rodando com o banco antigo (liberado por link, sem login), siga esta ordem pra não travar o acesso da equipe:

1. Crie a conta de cada pessoa da equipe (Authentication → Users → Add user).
2. Rode `supabase_security_migration.sql` no **SQL Editor** — exige login pra qualquer acesso ao banco.
3. Rode `supabase_row_access_migration.sql` — separa admin de conta restrita.
4. Rode `supabase_column_masking_migration.sql` — cria as views `_safe` e fecha a leitura direta das tabelas base.
5. Rode `supabase_hardening_migration.sql` — correções encontradas na conferência do banco.
6. Cadastre cada pessoa em `app_user_access` (passo 4 acima). **Faça isso antes do próximo passo**, ou a equipe toda fica sem ver dado nenhum.
7. Só depois publique esta versão atualizada do `index.html`.

⚠️ A partir da migração 3, o `index.html` lê pelas views `_safe`. Uma versão antiga do front, apontando para as tabelas base, mostraria tudo vazio para as contas restritas — publique o `index.html` desta versão junto.

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
| `app_user_access` | Nível de acesso de cada conta de login (admin ou restrita + nome pra filtrar) |

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
4. Na tela que aparece, clique em **uploading an existing file** e arraste os arquivos deste projeto (`index.html`, `README.md`, `.gitignore`, `supabase_schema.sql`, `supabase_security_migration.sql`, `supabase_row_access_migration.sql`, `supabase_column_masking_migration.sql`, `supabase_hardening_migration.sql`).
5. Clique em **Commit changes**.

Pronto, o código está no GitHub. Agora é só seguir o passo "Deploy no Vercel" acima.

## Backup manual

Dentro do próprio sistema, o botão **"⬇ Exportar dados"** (no topo da tela) gera um backup completo em texto — útil pra guardar uma cópia de segurança de vez em quando, independente do banco de dados.

## Segurança — revisão feita neste projeto

- **Login obrigatório**: o acesso deixou de ser "quem tem o link, edita" — agora é preciso login (Supabase Auth) e o banco só aceita requisições autenticadas. Veja "Login e segurança" acima.
- **Acesso por pessoa**: além de exigir login, o banco distingue admins (acesso total) de contas restritas (somente leitura, só dos próprios lançamentos) — a comparação de nomes é feita inteiramente no Postgres, então mesmo alguém manipulando as chamadas à API diretamente (sem passar pela tela) não consegue ver ou editar dado de outra pessoa.
- **Linha de comissão vazia não conta como participação**: o app grava uma linha em `vendas_comissoes` para cada vendedora em cada venda, quase sempre com valor nulo. Enquanto a regra checava só "existe linha", bastava alguém estar cadastrada como vendedora para enxergar todas as vendas da aba Sistema. Corrigido: agora exige valor preenchido.
- **Funções auxiliares fechadas para quem não fez login**: elas eram chamáveis pelo papel `anon` via `/rest/v1/rpc/`, e uma delas aceitava um nome qualquer — dava para perguntar "fulano participa do lançamento X?" sem ter conta. Acesso revogado e a função passou a responder só sobre quem está logado.
- **Mascaramento por coluna**: filtrar linhas não bastava, porque um contrato dividido guarda até 3 vendedores + colaborador na mesma linha — quem participava enxergava a % dos colegas daquele contrato. A leitura passou a ser feita por views `_safe`, que zeram coluna a coluna o que não é da pessoa, e a leitura direta das tabelas base ficou restrita a admin, pra que o mascaramento não seja contornável pela API.
- **Falha de XSS corrigida**: os nomes de vendedoras (aba Sistema) e de vendedores por aba eram inseridos em alguns lugares da tela sem escapar caracteres especiais, permitindo que um nome malicioso injetasse HTML/JavaScript na tela de outras pessoas da equipe. Todos os pontos foram corrigidos para escapar esse texto (ou usar atributos `data-*` em vez de montar o JavaScript do botão como texto).
- **Content-Security-Policy**: foi adicionada uma política restritiva (`script-src`, `connect-src` limitado ao domínio do Supabase, sem `object-src`, sem `form-action`) como camada extra de proteção contra XSS futuro.
- **Sessão com renovação automática**: o token de login é renovado sozinho antes de expirar; se a renovação falhar (ex: sessão revogada), a pessoa volta pra tela de login em vez de o sistema travar ou salvar dados sem permissão.
- **Recuperação de senha**: a tela de login tem "Esqueci minha senha", que usa o fluxo de recuperação por e-mail do Supabase — ninguém depende de admin pra trocar senha esquecida.
