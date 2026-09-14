# Comissões — Open Soluções Tributárias

HUB Comercial de controle de vendas, comissões, parceiros e pagamentos da equipe comercial.

## Stack

- **Frontend**: HTML + JavaScript puro (nenhum framework, nenhuma etapa de build).
- **Banco de dados**: [Supabase](https://supabase.com) (Postgres).
- **Hospedagem**: qualquer serviço de site estático (Vercel, Netlify, GitHub Pages...).

## Visual

O HUB Comercial usa a **identidade da Open Soluções Tributárias**, a mesma do mapa de produto:

- **A marca** — o globo de meridianos com "OPEN" e a assinatura — aparece na barra lateral, na faixa de título, na tela de login e no cabeçalho do relatório em PDF. É desenhada em **SVG dentro do próprio arquivo** (função `marcaOpenHtml`), então acompanha o tamanho pedido, imprime nítida e não depende de carregar imagem de fora (o que o CSP bloqueia).
- **O nome do produto** — a etiqueta **HUB** em degradê ao lado da palavra **Comercial** (função `hubMarcaHtml`) — fica no topo da barra lateral, na faixa de título de toda aba, na tela de login e no cabeçalho do relatório em PDF, para o aplicativo se apresentar pelo nome em qualquer tela. Tem uma versão clara, para os fundos marinhos, e uma escura, para a barra lateral branca.
- **Faixa de título** em degradê marinho com dois halos suaves da própria paleta, a marca à esquerda, um filete divisor, o nome do produto e o nome da aba; à direita o exercício e o indicador de "salvo". Um globo d'água discreto no canto e um **filete azul claro** fechando embaixo, com o degradê correndo devagar.
- **Cartões** brancos com **filete azul no topo**, borda azul clara e cantos suaves. Nos indicadores o filete vem na cor da pessoa, com um halo na mesma cor que cresce quando o mouse passa; o cartão de total é marinho cheio.
- **Rótulos em caixa alta bem espaçada** (`letter-spacing`) nos títulos de painel, grupos do menu e cabeçalhos de tabela — é a assinatura tipográfica da identidade.
- **Movimento com parcimônia**: a troca de aba faz o conteúdo entrar com um leve deslize (a marcação `animarEntrada` só vale nesse render — filtro e busca redesenham a tela a cada tecla e piscariam), cartões e botões sobem alguns pixels no hover, e quem pede menos movimento no sistema operacional (`prefers-reduced-motion`) não vê nenhum.
- Paleta: marinho `#0A2540`, azul do degradê `#14508C`, azul de destaque `#4FA3E3`, azul de ação `#1C6FBF`, fundo `#F4F7FB`.

Em telas estreitas (celular) a barra lateral vira uma faixa de atalhos que rola na horizontal, e o conteúdo ocupa a largura toda. Na impressão o menu some e a faixa sai em preto no branco.

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
├── supabase_metas_migration.sql         → migração 5: metas viram regras configuráveis
├── supabase_painel_equipe_migration.sql → migração 6: painel de relatórios mensais da equipe
├── supabase_vendedor_responsavel_migration.sql → migração 7: quem efetivamente vendeu (Sistema e Cursos)
├── supabase_vendas_curso_por_vendedora_migration.sql → migração 8: divide o faturamento do curso entre as vendedoras
├── supabase_contratos_reunioes_migration.sql → migração 9: equipe de consultoria (contratos e reuniões)
├── supabase_contratos_novos_migration.sql → migração 10: empresas com contrato assinado (nome, CNPJ e rentabilidade)
├── supabase_salario_fixo_migration.sql → migração 11: salário fixo do colaborador na aba Bônus e Metas
├── supabase_fechamento_fora_migration.sql → migração 12: quem fica de fora do fechamento para a contabilidade
├── supabase_pesos_ranking_migration.sql → migração 13: pesos dos indicadores no ranking da equipe
├── supabase_renovacoes_migration.sql   → migração 14: renovações do sistema (empresa, responsável e desfecho)
├── supabase_renovacoes_valor_migration.sql → migração 15: valor do contrato nas renovações
├── supabase_renovacoes_venda_migration.sql → migração 16: liga a renovação à venda que ela gera no Sistema
├── supabase_venda_renovacao_migration.sql → migração 17: venda de renovação fica fora do ranking
├── supabase_vendas_safe_renovacao_migration.sql → migração 18: a view vendas_safe devolve a coluna renovacao
├── supabase_venda_novo_contrato_migration.sql → migração 19: tag de contrato novo na aba Sistema
├── supabase_venda_upgrade_migration.sql → migração 20: tag de upgrade na aba Sistema
├── supabase_acesso_financeiro_migration.sql → migração 21: nível de acesso financeiro (vê o valor das notas, nenhuma comissão)
├── supabase_renovacao_upgrade_migration.sql → migração 22: upgrade de plano na aba Renovações
├── supabase_nota_emitida_migration.sql → migração 23: o visto de "nota emitida" e a função que o grava
├── supabase_marketing_metricas_migration.sql → migração 24: crescimento das redes sociais (aba Marketing)
├── supabase_curso_in_company_migration.sql → migração 25: curso In Company como indicador próprio do ranking
├── supabase_marketing_indicadores_migration.sql → migração 26: indicadores configuráveis por rede + RD Station (aba Marketing)
├── supabase_marketing_trafego_pago_migration.sql → migração 27: Tráfego pago — campanhas de anúncio (aba Marketing)
├── supabase_renovacoes_venda_fk_migration.sql → migração 28: índice único em renovacoes.venda_id (e por que não há foreign key)
├── supabase_marketing_leads_migration.sql → migração 29: lista de leads do LinkedIn (nome, cargo, empresa, órgão público)
└── .gitignore
```

## Resumo Geral

É a aba que abre **assim que o HUB Comercial carrega** — de propósito: os totais aparecem direto, sem precisar navegar até achá-los. Dois gráficos no topo, os 12 meses do `yearFilter`:

- **Faturamento total da empresa** — todos os produtos somados (Sistema, Consultoria, Órgãos Públicos, Cursos), o valor do contrato, não a comissão. É o mesmo gráfico que sai na primeira página do Relatório do mês.
- **Evolução mensal das comissões** — o que a equipe ganha (comissões de todas as origens, mais bônus), não o faturamento dos contratos. Salário fixo fica de fora.

Os dois respeitam o botão **"Mostrar valores" / "Ocultar valores"**: por padrão os números ficam escondidos (a barra aparece, o valor não), e só mostram ao clicar — o mesmo cuidado que o resto do Resumo Geral já tinha.

## Login e segurança

O HUB Comercial exige login (e-mail e senha) antes de mostrar qualquer dado. Não existe cadastro público pela tela — as contas da equipe são criadas manualmente por um administrador no painel do Supabase (veja "Criando contas da equipe" abaixo). Depois de logada, a pessoa continua com sessão salva no navegador até clicar em "Sair".

- **URL do projeto Supabase**: `https://ogkrrlssdrtctdyyvkql.supabase.co`
- **Chave pública (anon key)**: já está embutida no `index.html` (constante `SUPABASE_ANON_KEY`). Essa chave é **pública por padrão no Supabase** — sozinha, ela não abre porta nenhuma: quem decide o que pode ser lido/escrito são as políticas de RLS do banco.
- **Modelo de acesso — três categorias de conta**:
  - **Admin** (Soraya, Deborah, Open): vê e edita todos os dados do HUB Comercial, em todas as abas.
  - **Financeiro**: vê o **valor de contrato de todas as notas** que entraram — Sistema, Renovações, Consultoria, Consultoria Órgãos Públicos e Cursos — e **nenhuma comissão de ninguém**: nem valor, nem percentual, nem bônus, nem meta, nem salário, nem a divisão dos cursos. Marca cada nota como **emitida** conforme emite a nota fiscal, e isso é a **única coisa** que essa conta escreve. Não leva nome de pessoa, porque a conta não é de ninguém em particular. Veja "Nível financeiro" abaixo.
  - **Restrita** (Gustavo, Rios, Luciana, Angela): só **visualiza**, em modo somente leitura, os lançamentos onde o nome da pessoa aparece como vendedor(a) ou colaborador(a) — nunca vê nem edita o que é dos colegas. Isso existe pra ninguém comparar comissão de ninguém.

  Um mesmo contrato pode ter até 3 vendedores + colaborador na mesma linha. Nesses contratos divididos, a pessoa vê o lançamento e a **própria** comissão, mas o nome e a porcentagem dos colegas vêm em branco — o corte é feito coluna a coluna, pelas views `_safe` do banco (veja `supabase_column_masking_migration.sql`).
  
  Quem é admin e quem é restrito (e qual nome cada conta restrita representa) fica guardado na tabela `app_user_access`, ligada à conta de login de cada pessoa — não é algo que o próprio app deixa alguém mudar sozinho.

### Contas cadastradas

| E-mail | Acesso | Vê o quê |
|---|---|---|
| soraya.sa@opensolucoestributarias.com.br | Admin | tudo, e edita |
| financeiro@opensolucoestributarias.com.br | Admin | tudo, e edita |
| open@opensolucoestributarias.com.br | Admin | tudo, e edita |
| ana.rios@opensolucoestributarias.com.br | Restrita · **Rios** | só o que tem o nome dela, sem editar |
| angela@opensolucoestributarias.com.br | Restrita · **Angela** | idem |
| uilma@opensolucoestributarias.com.br | Restrita · **Uilma** | idem |
| luciana@opensolucoestributarias.com.br | Restrita · **Luciana** | idem |
| gustavo.reis@opensolucoestributarias.com.br | Restrita · **Gustavo** | idem |

As senhas não ficam aqui nem em lugar nenhum do código — só no Supabase, em hash. Para trocar a de alguém: **Authentication → Users**, os três pontinhos na linha da pessoa → *Reset password*.

### Criando contas da equipe

Pelo próprio HUB Comercial: aba **Usuários e Acessos** (só aparece para admin).

1. Preencha o **e-mail** e clique em **Gerar** para uma senha provisória forte — ela evita caracteres que se confundem ao ditar por telefone (0/O, 1/l/I).
2. Escolha o **nível de acesso**: **Administrador** (vê e edita tudo), **Financeiro** (vê o valor das notas e nenhuma comissão) ou **Restrita**. Só a conta restrita pede o **nome como aparece nos lançamentos** (ex: `Rios`) — é por ele que o HUB Comercial decide o que ela enxerga.
3. **Criar conta.** A senha aparece **uma única vez**, num quadro destacado: copie e repasse por um canal seguro. Depois disso nem o HUB Comercial consegue mostrá-la de novo, só definir outra.

Na lista abaixo do formulário dá para **redefinir a senha** (🔑) e **mudar o nível de acesso** (✎) de qualquer conta, além de ver quem nunca entrou.

> **Por que isso não roda no navegador.** Criar conta e trocar senha exigem a *chave de serviço* do Supabase, que passa por cima de todas as regras de acesso do banco. Se ela estivesse no `index.html`, qualquer pessoa abriria o código-fonte da página e a copiaria. Por isso essa parte vive numa **função no servidor** (`supabase/functions/admin-usuarios`): a chave fica só lá, o navegador manda apenas o token de quem está logado, e o servidor confere **de novo** se essa pessoa é admin antes de fazer qualquer coisa.

Duas travas embutidas: se a conta for criada mas o registro de acesso falhar, a função **desfaz a conta** (nada de usuário órfão); e não deixa rebaixar a **última conta de administrador**, senão ninguém mais administraria o HUB Comercial.

### Nível financeiro — vê o valor das notas, nenhuma comissão

Existe quem precise conferir **faturamento** sem ter acesso a remuneração: alguém do financeiro que fecha as notas do mês e não pode saber quanto cada pessoa ganhou. É para isso que serve o nível **Financeiro** (migração 21).

**O que essa conta vê:**

- as abas **Resumo Geral**, **Sistema**, **Renovações**, **Consultoria**, **Consultoria Órgãos Públicos** e **Cursos**;
- de cada lançamento: mês, cliente/empresa, produto ou contrato, **valor de contrato**, forma de pagamento, se está pago e o mês do pagamento;
- o **nome de quem atendeu** a conta — saber de quem é a nota ajuda a resolvê-la, e nome não é remuneração;
- no lugar do painel de parceiros, um **Resumo do financeiro**: faturamento por origem, faturamento mês a mês e a lista de todas as notas do ano;
- o botão **"Emitir" / "✓ Emitida"** em cada nota — veja "O visto de nota emitida" logo abaixo.

**O que essa conta não vê, em lugar nenhum:**

- percentual de comissão, valor de comissão, comissão liberada;
- bônus, metas, salário fixo, fechamento para a contabilidade;
- divisão das vendas de cursos por vendedora;
- as abas Bônus e Metas, Relatório de Desempenho, Equipe de Consultoria e Usuários e Acessos;
- honorários de parceiros.

**Por que dá para confiar nisso.** O corte não é feito na tela: é feito no banco. As views `_safe` devolvem `null` no lugar dos percentuais para essa conta, e as tabelas de comissão (`vendas_comissoes`, `bonus`, `metas`, `curso_vendas`) não têm nenhuma política de leitura que aceite o nível financeiro — a resposta vem vazia. Esconder só no navegador seria fingimento: o dado viajaria junto na resposta da API e bastaria abrir o console para lê-lo. Aqui ele não sai do banco.

Isso foi conferido de verdade, simulando a sessão dessa conta direto no Postgres: 205 notas de Sistema, 175 lançamentos das outras abas e 419 renovações visíveis, com **zero** comissões, bônus, metas, percentuais e divisões de curso.

**Como criar:** aba **Usuários e Acessos** → escolha **Financeiro** no nível de acesso. Essa conta não pede nome nos lançamentos, porque não é de ninguém em particular.

### O visto de "nota emitida"

Ver o valor das notas não bastava: quem emite precisa saber **quais já saíram**. Cada linha do quadro **"Notas lançadas"** tem um botão que alterna entre **"Emitir"** e **"✓ Emitida"**, com a data em que o visto foi dado. Acima do quadro, três pílulas — *Todas · A emitir · ✓ Emitidas* — e uma linha em âmbar dizendo quantas faltam e quanto somam; quando não falta nenhuma, ela vira verde: *"✓ Todas as notas de Agosto estão emitidas."*

**É o mesmo quadro para os dois lados.** Ele aparece no Resumo do financeiro e também no **Resumo Geral de quem administra** — o visto que o financeiro dá aparece na hora para a administração, sem ninguém precisar perguntar. Quem administra também pode marcar e desmarcar.

**Por que isso não abriu uma brecha.** A conta financeira é de leitura: ela não tem permissão de escrita em `vendas` nem em `lancamentos`, e não podia ganhar. RLS filtra **linha**, não **coluna** — uma política de update na tabela deixaria essa conta alterar *qualquer* campo pela API, inclusive o valor do contrato. Por isso o visto não vai pelo caminho normal de gravação: ele passa por uma função do banco (`marcar_nota_emitida`, migração 23) que confere quem está chamando e mexe em **exatamente uma coluna**. Conferido: a conta do financeiro grava o visto e **não** consegue alterar o valor de uma venda; uma conta restrita recebe *"Sem permissão para marcar nota emitida."*

Na tela, o visto muda na hora e **se desfaz se a gravação falhar**, com um aviso. Um visto que aparece marcado sem ter sido gravado seria pior do que visto nenhum — a pessoa passaria para a próxima nota achando que aquela estava resolvida.

### Criando contas pelo painel do Supabase (alternativa)

1. No painel do Supabase, vá em **Authentication → Users → Add user**.
2. Preencha e-mail e uma senha provisória para a pessoa (marque "Auto Confirm User" pra já liberar o acesso sem precisar confirmar e-mail).
3. Passe o e-mail e a senha provisória pra pessoa por um canal seguro; ela pode trocar a senha depois pelo link **"Esqueci minha senha"** na tela de login.
4. Dê o nível de acesso pra ela rodando no **SQL Editor** do Supabase:

```sql
-- Admin: vê e edita tudo
insert into app_user_access (auth_user_id, full_access, person_name)
select id, true, null from auth.users where email = 'admin@empresa.com.br';

-- Financeiro: vê o valor de todas as notas e nenhuma comissão (sem nome)
insert into app_user_access (auth_user_id, full_access, financeiro, person_name)
select id, false, true, null from auth.users where email = 'financeiro@empresa.com.br';

-- Restrita: só o que tiver o nome dela como vendedor/colaborador nos lançamentos
insert into app_user_access (auth_user_id, full_access, person_name)
select id, false, 'Nome Como Aparece Nos Lançamentos' from auth.users where email = 'vendedor@empresa.com.br';
```

O `person_name` precisa bater (sem diferenciar maiúscula/minúscula, ignorando espaço nas pontas) com o nome usado nos campos de vendedor/colaborador das abas Sistema, Consultoria, Órgãos Públicos, Cursos e Bônus. Se a pessoa aparecer com nomes diferentes em lugares diferentes (ex: "Rios" numa aba e "Ana Rios" em outra), só um desses nomes vai casar — vale a pena padronizar o nome nos lançamentos antes de cadastrar o acesso.

5. Repita para cada integrante da equipe. Sem uma linha em `app_user_access`, a conta consegue logar mas não vê nenhum dado.

Por padrão o Supabase também aceita auto-cadastro pela API (mesmo sem botão de cadastro na tela). Para bloquear isso, vá em **Authentication → Providers → Email** e desmarque **"Allow new users to sign up"**.

### Migrando um projeto já existente (importante!)

Se você já tem esse HUB Comercial rodando com o banco antigo (liberado por link, sem login), siga esta ordem pra não travar o acesso da equipe:

1. Crie a conta de cada pessoa da equipe (Authentication → Users → Add user).
2. Rode `supabase_security_migration.sql` no **SQL Editor** — exige login pra qualquer acesso ao banco.
3. Rode `supabase_row_access_migration.sql` — separa admin de conta restrita.
4. Rode `supabase_column_masking_migration.sql` — cria as views `_safe` e fecha a leitura direta das tabelas base.
5. Rode `supabase_hardening_migration.sql` — correções encontradas na conferência do banco.
6. Rode `supabase_metas_migration.sql` — novo formato das metas (recria a tabela `metas`).
7. Rode `supabase_painel_equipe_migration.sql` — cria a tabela do Relatório de Desempenho, a view `painel_equipe_totais` (que calcula os indicadores de venda) e a lista de quem aparece no painel.
8. Rode `supabase_vendedor_responsavel_migration.sql` — cria a coluna "Quem vendeu" nas abas Sistema e Cursos, e faz o painel contar uma venda por pessoa.
9. Rode `supabase_vendas_curso_por_vendedora_migration.sql` — troca o "quem vendeu" do curso pela divisão do faturamento por vendedora.
10. Rode `supabase_contratos_reunioes_migration.sql` — cria a equipe de consultoria (contratos e reuniões).
11. Rode `supabase_contratos_novos_migration.sql` — cria a lista de empresas que assinaram contrato, com CNPJ e avaliação de rentabilidade.
12. Rode `supabase_salario_fixo_migration.sql` — permite lançar o salário fixo do colaborador sem misturá-lo com bônus e comissões.
13. Rode `supabase_fechamento_fora_migration.sql` — permite tirar pessoas do fechamento para a contabilidade.
14. Rode `supabase_pesos_ranking_migration.sql` — cria os pesos dos indicadores do ranking.
15. Rode `supabase_renovacoes_migration.sql` — cria a aba de renovações do sistema.
16. Rode `supabase_renovacoes_valor_migration.sql` — acrescenta o valor do contrato nas renovações.
17. Rode `supabase_renovacoes_venda_migration.sql` — liga a renovação à venda lançada na aba Sistema.
18. Rode `supabase_venda_renovacao_migration.sql` — tira as vendas de renovação do ranking de desempenho.
19. Rode `supabase_vendas_safe_renovacao_migration.sql` — faz a view `vendas_safe` devolver a coluna `renovacao` (sem isso o selo some ao recarregar).
20. Rode `supabase_venda_novo_contrato_migration.sql` — cria a tag de contrato novo.
21. Rode `supabase_venda_upgrade_migration.sql` — cria a tag de upgrade.
11. Cadastre cada pessoa em `app_user_access` (passo 4 acima). **Faça isso antes do próximo passo**, ou a equipe toda fica sem ver dado nenhum.
12. Só depois publique esta versão atualizada do `index.html`.

⚠️ A partir da migração 3, o `index.html` lê pelas views `_safe`. Uma versão antiga do front, apontando para as tabelas base, mostraria tudo vazio para as contas restritas — publique o `index.html` desta versão junto.

### Tabelas criadas

| Tabela | Conteúdo |
|---|---|
| `vendas` | Lançamentos da aba Sistema (inclui `vendedor_responsavel` — quem efetivamente fez a venda — e `renovacao`, que tira a venda do ranking) |
| `vendas_comissoes` | Comissão de cada vendedor(a) por lançamento do Sistema (valor e, opcionalmente, a % que o gerou) |
| `lancamentos` | Lançamentos de Consultoria, Consultoria Órgãos Públicos e Cursos (uma tabela só, filtrada pela coluna `entidade`) |
| `lancamentos_extra_vendedores` | Vendedores extras (4º em diante) por lançamento |
| `lancamento_vendas` | Divisão do faturamento de um curso entre quem vendeu (sem relação com comissão) |
| `bonus` | Bônus, metas batidas e salário fixo dos colaboradores (separados pela coluna `tipo`) |
| `metas` | Regras de meta: gatilho da empresa + prêmio de quem bate |
| `relatorios_equipe` | Indicadores mensais digitados: andamento da equipe e contratos/reuniões (Relatório de Desempenho) |
| `contratos_consultoria` | Empresas que assinaram contrato: quem trouxe, mês, nome, CNPJ e se o negócio foi rentável |
| `painel_pesos` | Peso de cada indicador no ranking da equipe |
| `renovacoes` | Empresas renovando o sistema: mês, responsável, nome, valor, se renovou e a venda que gerou |
| `partners` | Parceiros cadastrados |
| `venda_products` | Catálogo de produtos da aba Sistema |
| `sellers` | Vendedoras do Sistema (lista editável) |
| `entity_vendors` | Vendedores(as) por aba (Consultoria / Órgãos Públicos / Cursos), quem aparece no Relatório de Desempenho (`entidade='painel'`), quem é acompanhado por contratos/reuniões (`entidade='painel_contratos'`) e quem fica de fora do fechamento (`entidade='fechamento_fora'`) |
| `closed_months` | Meses fechados para edição |
| `extra_years` | Anos adicionados manualmente |
| `app_user_access` | Nível de acesso de cada conta de login (admin, financeiro ou restrita + nome pra filtrar) |
| `marketing_metricas` | Crescimento das redes sociais: mês, conta (Open/Foco Tributário), rede, e `valores` — um jsonb com um número (ou texto) por indicador daquela rede (migração 24, virou jsonb na migração 26) |
| `marketing_indicadores` | Catálogo de quais indicadores cada rede tem — chave, rótulo, se é número ou texto, se é moeda. É nela que o botão "Editar indicadores" mexe (migração 26) |
| `marketing_campanhas` | Tráfego pago: uma linha por campanha de anúncio, com os números brutos (gasto, alcance, impressões, cliques, leads...). CPC, CPL, CTR, CPM, Connect rate e Custo/MQL não são colunas — são calculados na tela (migração 27) |
| `marketing_leads` | Lista de leads: uma pessoa por linha, com nome, cargo, empresa e se a empresa é órgão público (`orgao_publico` é boolean NULL — três estados). `rede` permite leads de outra origem sem migração nova (migração 29) |

As colunas `nota_emitida` e `nota_emitida_em` de `vendas` e `lancamentos` guardam o visto do financeiro (migração 23); só a função `marcar_nota_emitida` escreve nelas.

A coluna `in_company` de `lancamentos` marca o curso ministrado dentro da empresa cliente (migração 25) — só tem sentido para `entidade='cursos'`, e alimenta o indicador "Vendas de curso In Company" do ranking.

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
4. Na tela que aparece, clique em **uploading an existing file** e arraste os arquivos deste projeto (`index.html`, `README.md`, `.gitignore`, `supabase_schema.sql`, `supabase_security_migration.sql`, `supabase_row_access_migration.sql`, `supabase_column_masking_migration.sql`, `supabase_hardening_migration.sql`, `supabase_metas_migration.sql`, `supabase_painel_equipe_migration.sql`).
5. Clique em **Commit changes**.

Pronto, o código está no GitHub. Agora é só seguir o passo "Deploy no Vercel" acima.

## Ordenação dos lançamentos

Em todas as abas de lançamento — **Sistema**, **Consultoria**, **Órgãos Públicos** e **Cursos** — o cabeçalho do painel tem um seletor **"Ordenar"**:

| Opção | Efeito |
|---|---|
| Mês de lançamento | ordem padrão, como foi digitado |
| Nome — A a Z / Z a A | alfabética pelo cliente, empresa, órgão ou curso (o rótulo acompanha a aba) |
| Maior / menor valor de contrato | ordem por valor |

A ordenação é só de exibição — não muda nada no banco, e cada pessoa escolhe a sua. Acentos e maiúsculas são tratados pela regra do português: "ácua" vem antes de "alfa", que vem antes de "Beta", e "Ômega" ordena como "O". Um lançamento recém-criado, ainda sem nome, fica no topo para não sumir de vista.

### Largura das colunas

As tabelas de lançamento são largas e rolam na horizontal. Para o que mais se lê não ficar espremido:

- a coluna do **nome** (cliente, empresa, órgão ou curso) tem largura mínima garantida, então o nome inteiro aparece em vez de ser cortado no meio;
- a coluna do **mês** mostra o número e o nome curto — `08 Ago` —, o que evita confundir `03` com `05` de relance;
- a coluna de **valor** ficou mais estreita: o cabeçalho é só "Valor" (o nome completo aparece ao passar o mouse) e o valor continua com o `R$` na frente.

O que sobra continua acessível rolando a tabela para o lado, como já era.

## Comissão liberada x a receber

A equipe de consultoria só recebe quando o **cliente paga a nota** — contrato fechado e nota emitida ainda não valem. A aba **Pagamentos Realizados** abre com os pagamentos que entraram e, logo abaixo, separa a comissão em dois casos, por pessoa:

| Quadro | O que mostra |
|---|---|
| 💰 **Comissões liberadas** | O cliente já pagou. Lista, por vendedor(a), qual cliente pagou, em que mês, o valor pago e quanto ele(a) recebe disso. |
| ⏳ **A receber** | Nota emitida mas ainda não paga. Mesma quebra, serve como previsão do que entra quando o cliente pagar. |

O que move um lançamento de um quadro para o outro é a caixinha **"Pago"** na aba de origem (Sistema, Consultoria ou Órgãos Públicos). Marcou como pago, a comissão sai de "a receber" e entra em "liberadas".

Cada quadro tem seu **próprio filtro de mês**, e eles filtram por coisas diferentes — o que é proposital:

- **Liberadas** filtra pelo **mês em que o cliente pagou**, porque é quando o dinheiro entrou.
- **A receber** filtra pelo **mês da venda**, porque ainda não existe pagamento para filtrar.

Os dois são independentes: dá pra ver o que foi pago em setembro e, ao mesmo tempo, o que ainda está em aberto das vendas de agosto. Quando o filtro de "a receber" está num mês, a dica embaixo das pills mostra também o total do ano todo, pra não perder a visão geral.

Os dois quadros já descontam a participação do parceiro antes de calcular a comissão: contrato de R$ 60.000 com 10% de parceiro e 20% de comissão paga R$ 10.800, não R$ 12.000.

Cada vendedor(a) logado enxerga **apenas as próprias linhas** — é o mesmo corte de acesso do resto do HUB Comercial, feito no banco. Admin vê todo mundo, agrupado por pessoa e com subtotal.

> **Cursos não tem controle de pagamento.** As abas Sistema, Consultoria e Órgãos Públicos têm a coluna "Pago"; a de Cursos não, então lançamentos de curso não aparecem nesses dois quadros. Se a equipe de cursos também passar a receber só depois do pagamento, dá pra ativar o controle lá.

## Relatório de Desempenho

Aba própria, para acompanhar o **andamento** da equipe — o esforço, não só o resultado financeiro.

São nove indicadores por vendedora, por mês, divididos em dois grupos:

| Grupo | Indicadores | De onde vem |
|---|---|---|
| Andamento | Interação, Propostas, Prospecção zero, Prospecção, Negócios abertos, Reuniões realizadas | **digitado à mão** todo mês |
| Vendas | Vendas de cursos (R$), Vendas de sistemas (R$), Qtd. sistemas vendidos | **calculado sozinho** pelos lançamentos que já existem no HUB Comercial |

**Os três indicadores de venda não são mais digitados.** Quem faz a soma é a view `painel_equipe_totais` no banco:

Os três saem da coluna **"Quem vendeu"** dos lançamentos: cada venda conta para **uma pessoa só**, a que estiver marcada ali. Lançamento sem essa marcação não conta para ninguém, e o HUB Comercial avisa quantos estão assim.

### Quando o banco não responde

Cada aba carrega os lançamentos numa consulta principal e mais algumas secundárias (vendedores extras, divisão das vendas, catálogo de vendedoras). Antes, se **qualquer uma** delas falhasse, a aba inteira ficava vazia — igualzinho a "não há nada lançado", sem nenhum aviso.

Agora as consultas secundárias falham sozinhas, sem derrubar os lançamentos, e se a consulta principal falhar a aba mostra um **aviso amarelo** pedindo para recarregar a página. A divisão das vendas (dado só de admin) nem é pedida por conta restrita.

### Comissão por percentual (aba Sistema)

Na aba Sistema, cada coluna de vendedora tem **dois campos**: a **%** em cima e o **valor em R$** embaixo.

- Preencheu a **%**? O valor sai calculado na hora, e fica em azul para você saber que veio de uma taxa. Se o valor do contrato ou a participação do parceiro mudarem depois, a comissão **se refaz sozinha**.
- Prefere digitar o **valor** direto? Digite embaixo — a % é limpa e aquele valor fica fixo.

A base do cálculo é a mesma das outras abas: o valor do contrato **menos a parte do parceiro**. Num contrato de R$ 10.000 com parceiro de 20%, uma comissão de 5% dá R$ 400 (5% de R$ 8.000), não R$ 500.

> Lançamentos antigos não mudaram: continuam com o valor que já tinha e a % vazia. O valor em R$ segue sendo o que alimenta todos os relatórios — a % só serve para calcular.

### Quem vendeu ≠ quem ganha comissão

Essa é a distinção que faz o painel bater com a realidade.

Nas abas **Sistema** e **Cursos**, a comissão de uma venda é **dividida entre várias pessoas** — mas quem fez a venda foi uma só. Os campos de vendedor desses lançamentos dizem quem **ganha comissão**, não quem vendeu. Antes o painel tratava as duas coisas como a mesma, e creditava o contrato inteiro a cada nome que aparecia:

| Aba | O painel contava | O real |
|---|---|---|
| Sistema | R$ 4.336.963,30 · 123 sistemas | **R$ 984.411,80 · 36 vendas** |
| Cursos | R$ 386.166 contados em dobro nos lançamentos divididos | — |

As duas abas resolvem isso, cada uma do jeito que o dado pede:

**Sistema — coluna "Quem vendeu"**, depois de "Venda". Cada venda é o contrato de um cliente, feito por uma pessoa: escolhe-se um nome. A coluna fica amarela enquanto estiver vazia.

**Cursos — coluna "Vendas por vendedora"**, depois de "Nome do Curso". Aqui um nome só não serve: o lançamento é o **faturamento total do curso**, e esse total vem de várias vendedoras — parte uma trouxe, parte outra. O botão abre um quadro onde se informa **quanto cada uma vendeu, em reais**, com uma conferência ao vivo ("Somado: R$ X de R$ Y — falta R$ Z"). O atalho ⤵ joga o que falta na linha escolhida. O botão fica verde quando a divisão fecha com o valor do contrato.

> **A comissão não muda em nada.** Ela continua saindo dos campos "Vendedor / % Comissão" do lançamento. Uma pessoa pode ganhar 1% do total de cursos sem ter vendido nenhum — e vai continuar ganhando, apareça ela na divisão ou não. São duas leituras do mesmo lançamento: **quem ganha** × **quem vendeu**.

> **Nada foi preenchido automaticamente, de propósito.** No Sistema, nenhuma venda tinha uma vendedora única — todas eram divididas entre 2 e 6 pessoas. Em Cursos, a mesma pessoa aparece como vendedora em 10 dos 12 lançamentos, com 1% em todos: é o papel dela na comissão, não a venda. Copiar esses campos repetiria exatamente o erro que a coluna existe para corrigir.

O nome de quem vendeu no Sistema tem a mesma máscara dos outros vendedores: conta restrita só lê se for ela mesma. Na divisão dos cursos vale o mesmo: **cada vendedora vê a própria linha** — na coluna "Sua venda" aparece quanto ela vendeu daquele curso — e as linhas das colegas ficam invisíveis. Editar a divisão continua sendo só de admin.

A aba **Consultoria** e a de **Órgãos Públicos** não têm essa coluna — o painel não conta essas duas origens.

A aba abre direto no **Dashboard** — é o que o dono da empresa quer ver primeiro, o placar da equipe, não um formulário. Ao lado dele fica o pill **"Lançamento"**, para quem precisa digitar o andamento do mês.

**Dashboard** — no topo tem o **filtro de período**: *Ano inteiro* ou um mês. Ele vale para **todos os quadros de uma vez** — ranking, totais por vendedora, comparativo e tabela de indicadores —, então não existe um filtro em cada quadro dizendo coisa diferente. O único que não muda é a **evolução mensal**, que é a linha do tempo e mostra sempre os 12 meses.

Abre pelo **ranking**, que é o que essa aba tem de mais importante: um quadro em degradê marinho com a campeã e a classificação, e abaixo um cartão por indicador mostrando quem liderou cada quesito, na cor da pessoa. Depois vêm os cartões de total do ano, o gráfico de barras comparando as pessoas num indicador, a evolução mensal em linhas ao longo dos 12 meses e a tabela de totais anuais.

**Lançamento** — escolhe a vendedora, o mês e preenche os **seis** campos de andamento. Logo abaixo, um bloco cinza mostra os três indicadores de venda já calculados daquele mês, só para conferência. Se aquele mês já foi lançado, o formulário abre preenchido e o botão vira "Atualizar". Ao lado, cada vendedora tem um quadro com os meses já lançados, com atalhos para editar ou excluir.

No ranking, cada indicador mostra quem liderou; **quem empata aparece junto**, com o valor uma vez só.

**A campeã é quem soma mais peso liderando.** Cada indicador vale um **peso**, e quem lidera aquele indicador no período leva o **peso inteiro** pra si — não importa a margem, só liderar conta. Quem não lidera não leva nada daquele indicador. O placar lê-se direto: *"de cada 100 pontos do ano, Angela ficou com 37,9"* — mas, diferente de uma fatia, a soma de todo mundo **pode passar de 100** quando há empate (cada empatado leva o peso inteiro, não dividido).

Pesos definidos pela diretoria comercial:

| Peso | Indicadores | Por quê |
|---|---|---|
| **5** | Reuniões realizadas, Vendas de cursos, Vendas de curso In Company, Vendas de sistemas, Qtd. sistemas vendidos | é o que vira contrato |
| **2** | Propostas, Prospecção, Prospecção zero, Negócios abertos | é caminho para o contrato, não o contrato |
| **1** | Interação | volume de contato, o mais fácil de inflar |

**Vendas de curso In Company** (migração 25) é um indicador à parte de "Vendas de cursos" — não substitui, soma junto. Curso in company é ministrado dentro da empresa cliente, sob medida, e a diretoria quis reconhecer isso separado de um curso aberto qualquer. A marca é por lançamento: na aba **Cursos**, o botão **🏢** nas ações da linha marca ou desmarca, e o curso marcado ganha um selo **"🏢 In Company"** ao lado do nome. Os cursos que já seguiam a convenção de digitar "IN COMPANY" no nome vieram marcados automaticamente na migração — não precisou re-lançar nada.

- **Só liderar conta, a margem não.** Liderar por 1 vale o mesmo que liderar pelo dobro — o peso do indicador inteiro vai pra quem ficou na frente.
- **Empate leva o peso inteiro pra cada um dos empatados** — não divide. Três pessoas empatadas num indicador de peso 5 rendem 5 pontos pra cada uma, não 5 ÷ 3.
- **Indicador em que a equipe inteira está zerada sai da conta**, em vez de dar zero a todas.
- **Peso 0** tira o indicador da pontuação, mas ele continua aparecendo no painel.
- Empate no ponto (diferença menor que 0,1) coloca as duas como melhores do período.

Os cartões por indicador continuam mostrando **quem liderou cada quesito**, agora com o peso ao lado, e o quadro da campeã mostra também quantos indicadores ela liderou — para o dono da empresa ver as duas leituras.

**Mudar os pesos** — o botão **"⚖️ Pesos do ranking"**, no cabeçalho do quadro, abre a lista com um seletor de 0 a 5 por indicador. Mudar recalcula o ranking na hora, do mês e do ano, e vale para todo mundo (`painel_pesos`, migração 13). Só admin edita; o botão *"Restaurar os pesos padrão"* volta à tabela acima.

> **Por que não é fatia, nem soma de colocações.** A primeira versão dava N pontos ao 1º lugar, N−1 ao 2º e assim por diante: num time de quatro, quatro segundos lugares valiam mais que uma liderança isolada, e acabava campeã quem não tinha vencido nada. A segunda versão passou a contar lideranças com peso, mas dividindo por **fatia** — a pessoa levava o peso proporcional ao quanto fez do total da equipe naquele indicador, não só por ter liderado. Isso deixava alguém virar campeã sem ter liderado o indicador de maior peso nenhuma vez, só por nunca zerar em nada: foi o que aconteceu em agosto/2026, quando a Rios liderou 5 dos 10 indicadores — dois deles os de venda mais forte — e mesmo assim ficou em 3º lugar. A versão atual corrige isso: só liderar conta, o peso vai inteiro pra quem ficou na frente.

> Os totais de venda são calculados pelo banco, e o painel os relê **depois de cada gravação** nas abas Sistema e Cursos, além de toda vez que a aba é aberta. Não precisa recarregar a página para o mês aparecer.

**Quem aparece** — o painel tem a **própria lista de pessoas**, separada da lista de vendedoras do sistema, porque ele acompanha só a equipe comercial que lança andamento. Hoje são **Angela, Rios, Uilma e Luciana**. Quem é admin muda isso pelo botão **"Quem aparece"** no topo do painel, marcando ou desmarcando nomes — desmarcar alguém só tira do painel, não mexe em lançamento, comissão nem em nenhuma outra aba. A lista fica no banco (`entity_vendors` com `entidade='painel'`), então vale para todo mundo.

O ano vem do filtro no topo da página — não é fixo.

> **Contas restritas veem o ranking e o comparativo**, com os números de todo mundo — foi uma escolha de quem administra o HUB Comercial, para o painel funcionar como placar da equipe. O que elas continuam **não** vendo é o que está por trás desses números: cliente, contrato, percentual e comissão dos colegas seguem escondidos, porque a view `painel_equipe_totais` devolve só os totais por pessoa/mês. Lançar e editar continua sendo exclusivo de admin.

### Equipe de consultoria

Nem todo mundo é medido pelos mesmos indicadores. A **equipe de consultoria** — o Davidson é o primeiro caso — não vende: assina contratos e faz reuniões. Por isso tem uma **aba própria no menu**, "Equipe de consultoria", no grupo "Equipe", logo abaixo de Marketing — não é mais um pill escondido dentro do Relatório de Desempenho.

É uma **lista separada** da de vendedoras, com **dois indicadores** por pessoa e por mês: *contratos assinados* e *reuniões realizadas*. Escolhe-se a pessoa, o mês, digita os dois números e salva. Ao lado, cada pessoa tem um quadro com os meses lançados e o total do ano.

Para incluir alguém, use **"👤 Quem está na equipe"** no topo da aba — ou o botão **"+ Incluir mais pessoas na equipe de consultoria"** no fim da página, que abre a mesma lista e leva a tela até ela (o topo fica longe de quem está lendo os painéis de empresas lá embaixo). Marque quem já existe no HUB Comercial, ou cadastre um nome novo pelo botão do fim da lista. A lista fica no banco (`entity_vendors` com `entidade='painel_contratos'`), então vale para todo mundo.

> Quem está nessa lista **não entra no ranking de vendas** e não aparece nos cartões do dashboard — o ranking mede quem vende, e essas pessoas são medidas por outra coisa. As duas listas são independentes: a mesma pessoa pode estar nas duas, se fizer sentido.

## Renovações do sistema

Renovar contrato não é vender: não tem prospecção, não tem proposta, não gera comissão de venda nova. É um **processo próprio**, tocado por uma dupla — hoje **Uilma e Luciana** —, com lista de gente própria.

Fica em **aba própria no menu lateral, em Lançamentos, logo abaixo de Sistema**. É um cadastro de contratos por mês, com valor e responsável, igual em natureza a Consultoria e Cursos — e é para a aba Sistema que as renovações confirmadas vão. Ela morou por um tempo dentro do Relatório de Desempenho, mas ali era leitura de indicadores, não lançamento: com quase 200 empresas por ano, o cadastro estava a dois cliques de profundidade dentro da aba cujo assunto (o ranking) justamente não conta renovação.

O cadastro é o mínimo que responde à pergunta do mês:

| Campo | O que é |
|---|---|
| Mês | o mês da renovação |
| Empresa | só o nome mesmo |
| Valor | o valor do contrato |
| Responsável | quem cuidou (só quem está na lista de renovações aparece aqui) |
| Situação | **Renovado**, **Upgrade** ou **Não renovado** — um clique escolhe, clicar de novo volta para *em aberto* |

A carteira fica grande depressa — são quase 200 empresas por ano —, então a aba tem **filtro por mês** (com a contagem em cada pílula), **filtro por situação** e uma **busca por nome**, que ignora acentos e maiúsculas. Os três se combinam, e os cartões do topo acompanham o recorte: filtrando Março, os números são os de Março, e o cabeçalho do quadro diz *"17 empresas em Março de 2026 de 199 no ano"*.

A situação começa **em aberto** de propósito: a empresa entra na lista quando a renovação começa a ser tratada, e o desfecho vem depois. Os cartões do topo contam renovadas, upgrades, não renovadas, em aberto e a **taxa de renovação** — que só considera as decididas, então as em aberto não puxam o número para baixo —, cada um com a soma dos valores: quanto foi renovado, quanto se perdeu e quanto ainda está em jogo. As pílulas abaixo filtram a lista por situação, e o quadro **"Por responsável"** fecha o ano de cada uma, com a taxa individual.

### Upgrade de plano

Nem toda conta da carteira renova pelo mesmo valor. Às vezes o cliente **não renova o plano em que estava: ele migra para um plano bem maior**. Marcar isso como "Não renovado" seria mentir — o cliente ficou, e a taxa de renovação registraria como perda uma conta que na verdade cresceu. Marcar como "Renovado" também: o valor mudou, e subir o plano de um cliente é venda de verdade, não repetição de contrato.

Por isso a situação tem um terceiro botão, **Upgrade**, que se comporta diferente dos outros dois:

1. Ao clicar, o HUB Comercial **pergunta o valor do plano novo** — mostra o valor da carteira ao lado e calcula na hora quanto a conta subiu (*"a conta sobe R$ 39.564,00 — de R$ 8.388,00 para R$ 47.952,00"*). Se o valor digitado for **menor** que o da carteira, ele avisa: plano que diminuiu não é upgrade.
2. O valor da carteira **não é apagado**. A linha guarda os dois — o antigo em `valor`, o novo em `valor_upgrade` —, e a tabela mostra o novo logo abaixo do antigo, na etiqueta âmbar **⬆ R$ 47.952,00** (clicar nela corrige o valor).
3. Na **taxa de renovação**, upgrade conta como renovação: o cliente ficou.
4. Um cartão **"Upgrades"** aparece no topo com **quanto a carteira cresceu no total** — a soma de todas as diferenças. É o número para levar para a diretoria.
5. Ao ir para a aba Sistema, a venda nasce com a etiqueta **⬆️ Upgrade** (não ♻️ Renovação), pelo **valor novo**, com a observação *"Upgrade de plano"* — e, por isso, é a única linha vinda das renovações que **conta no ranking da equipe**.
6. Na **carteira do ano seguinte**, a empresa é copiada já com o **valor novo**: é por ele que ela vai renovar no ano que vem.

Enquanto a linha ainda não foi lançada no Sistema, clicar de novo em **Upgrade** desfaz tudo e volta para *em aberto*. Depois de lançada, o HUB Comercial pede que a venda seja excluída na aba Sistema primeiro — comissão já lançada não some sozinha.

### Da renovação para a aba Sistema

A renovação que se confirma é faturamento do mês e precisa entrar na lista de comissões como qualquer outra venda. O botão **"📤 Lançar N no Sistema"** faz essa ponte:

1. Marque as empresas como **Renovado** (ou **Upgrade**);
2. Clique em *Lançar no Sistema* — abre uma conferência com o que vai ser lançado, quantas são e quanto somam;
3. Opcionalmente escolha o **produto** que essas vendas terão na aba Sistema;
4. Confirme. Cada renovação vira uma **venda do mês**, com o nome da empresa como cliente, o valor do contrato, o mês da renovação e **"Quem vendeu" = quem cuidou da renovação**.

As vendas nascem com a observação **"Renovação"** — ou **"Upgrade de plano"**, no caso dos upgrades —, para se distinguirem na aba Sistema, e **sem percentual de comissão** — esse você preenche por lá, como em qualquer venda.

- **Nunca lança duas vezes.** A renovação guarda o id da venda que gerou, então some da fila e ganha a etiqueta **"no Sistema"**, que ao ser clicada leva direto à venda correspondente. Isso vale mesmo depois de recarregar a página.
- **Só entram as marcadas como Renovado ou Upgrade** que ainda não foram lançadas, respeitando o filtro de mês.
- **Mês fechado é pulado**, e o HUB Comercial avisa quais ficaram de fora.
- **Desmarcar depois não apaga a venda.** O HUB Comercial avisa: mexer na situação aqui não desfaz nada na aba Sistema; se a venda não valer mais, exclua também por lá. Comissão já lançada não some sozinha.

### Renovação não conta no ranking

Isto vale para a **renovação comum**; o upgrade é a exceção descrita acima, e conta. A venda que nasce de uma renovação vale **comissão como qualquer outra** e entra no Resumo Geral, no faturamento do mês e no fechamento para a contabilidade. O que ela **não** faz é contar no **ranking de desempenho**: renovar um contrato que já era da casa não é a mesma coisa que trazer cliente novo, e a carteira de renovação é grande o bastante para decidir sozinha quem é campeã do ano.

Na aba Sistema, essas vendas aparecem com o selo verde **"♻️ Renovação"** ao lado do cliente, e o botão **♻️** nas ações da linha marca ou desmarca qualquer venda — inclusive uma que você tenha digitado à mão e queira tirar do ranking.

#### A natureza da venda: contrato novo, upgrade e renovação

A aba Sistema tem três marcas, e cada venda pode ter no máximo uma:

| Marca | O que significa | Conta no ranking? |
|---|---|---|
| **✨ Contrato novo** | conta nova que entrou no mês | **sim** |
| **⬆️ Upgrade** | cliente que já era da casa e subiu de plano | **sim** |
| **♻️ Renovação** | contrato que já era da casa, renovado igual | **não** |
| *(sem marca)* | o resto — o contrato mensal que só se repete | sim |

Só a **renovação** sai do ranking: é o único caso em que o dinheiro entra sem ninguém ter conquistado nada de novo. Contrato novo e upgrade são receita conquistada e contam no desempenho como qualquer venda.

Os botões **✨**, **⬆️** e **♻️** nas ações da linha marcam e desmarcam. **As três se excluem**: ligar uma desliga as outras, porque nenhuma venda é duas coisas ao mesmo tempo. Clicar na marca que já está ligada desliga e volta a venda para "sem marcação".

Acima da tabela, uma linha de filtros mostra a contagem no recorte que está na tela — *"Todas · 9 · ✨ Contratos novos · 4 · ⬆️ Upgrades · 1 · ♻️ Renovações · 3 · Sem marcação · 1"* — e clicar em qualquer uma filtra a lista. Combina com o filtro de mês e o de vendedora, então dá para responder na hora quantas contas novas cada pessoa trouxe num mês.

> **Upgrade não entra na carteira do ano seguinte.** Só o contrato novo entra, porque o cliente que fez upgrade provavelmente já está na carteira pelo contrato original — o que muda na renovação é o valor, não a existência da linha. Ajuste o valor na carteira quando fizer a virada de ano.

> **Atenção para quem for mexer no banco:** o aplicativo não lê a tabela `vendas`, e sim a view `vendas_safe`, que faz o mascaramento por coluna. Toda coluna nova precisa entrar também na view — senão ela é gravada e nunca mais lida. Foi o que aconteceu com `renovacao` na primeira versão: o selo aparecia e sumia no recarregamento (corrigido na migração 18).

> O corte é uma **coluna do banco** (`vendas.renovacao`), não a palavra "Renovação" escrita na observação. Um critério que mexe em desempenho não pode depender de alguém digitar o texto certo. A view `painel_equipe_totais` ignora essas vendas nos indicadores *Vendas de sistemas* e *Qtd. sistemas vendidos*.

Enquanto não são lançadas, as renovações não entram em lugar nenhum — a lista sozinha é acompanhamento de carteira. As renovações do mês também saem em seção própria do relatório em PDF.

### Montar a carteira do ano seguinte

Aqui o ciclo se fecha: **o que é contrato novo num ano vence no seguinte e vira renovação**. O botão **"📅 Montar carteira de 2027"** monta o ano que vem a partir de duas fontes:

1. as **renovações do ano**, que vencem de novo doze meses depois;
2. as vendas marcadas com **✨ Contrato novo** no ano — a conta que entrou agora é a renovação do ano que vem.

Nos dois casos a cópia mantém **empresa, valor e mês**, e zera o que é do ano anterior: a situação volta para **em aberto** e o vínculo com a venda é desfeito, senão o ano novo nasceria com renovações já dadas como resolvidas e lançadas. Empresas que já existam no ano de destino (mesmo nome e mês) são puladas, então clicar duas vezes não duplica nada, e o ano é criado no filtro se ainda não existir.

> **O responsável do contrato novo nem sempre é aproveitado.** Quem cuida das renovações é a dupla da aba; se quem vendeu não estiver nessa lista, o campo fica em branco para você escolher. Melhor um campo vazio do que um responsável errado na folha.

### O lembrete de virada de ano

Depender de alguém lembrar disso em janeiro é depender de esquecer. Por isso, **ao abrir a aba num ano, o HUB Comercial mostra sozinho o que ficou para trás**:

> 🔔 Faltam na carteira de **2027**: **12** contratos novos de 2026 e **187** renovações de 2026. O que foi contrato novo num ano vence no seguinte — é renovação de 2027. **[Trazer para 2027]**

O aviso só aparece quando há algo faltando, e some assim que a carteira fica completa. Não é preciso lembrar de nada: basta abrir o ano.

### Importar a planilha de renovações

São muitas empresas, e elas já viviam numa planilha. O botão **"📄 Importar planilha"** lê o arquivo — ler é trabalho do HUB Comercial, não de quem digita.

Três caminhos, todos no mesmo lugar:

1. **Arquivo `.xlsx`** — o Excel direto, sem converter nada;
2. **Arquivo `.csv`** — inclusive o que o Excel do Windows salva em latin-1, que é detectado sozinho;
3. **Colar** — selecionar as células no Excel, Ctrl+C e colar na caixa.

As colunas esperadas são **empresa · valor · mês de renovação**, nessa ordem. Se a primeira linha for cabeçalho, ele é reconhecido pelos nomes (*empresa/cliente/razão*, *valor/preço/mensalidade*, *mês/renovação/vencimento*) e a ordem deixa de importar.

O HUB Comercial entende o mês escrito de várias formas — `Agosto`, `ago`, `08`, `8`, `09/2026`, `2026-08-15` e a data do Excel (aquele número serial) —, e o valor tanto como número quanto como `R$ 1.234,56`. Quando o mês traz o ano e ele ainda não existe no HUB Comercial, o ano é criado junto, para a linha não ficar gravada e invisível.

Antes de gravar aparece uma **prévia** com tudo o que foi lido, linha a linha, e um seletor para atribuir um responsável a todas de uma vez (pode ficar em branco). Duas coisas ficam de fora, sinalizadas em âmbar: **empresas já cadastradas** no mesmo mês e ano, e **linhas cujo mês não foi reconhecido** — nada é importado pela metade sem você ver.

> Nenhuma biblioteca externa é usada para isso: a política de segurança da página bloqueia scripts de fora, então o `.xlsx` (que é um ZIP de XMLs) é aberto com o `DecompressionStream` do próprio navegador. Se algum navegador não tiver esse recurso, o HUB Comercial avisa e sugere o CSV ou o colar.

Para mudar quem cuida, use **"👤 Quem cuida das renovações"** no topo da aba (`entity_vendors` com `entidade='renovacoes'`). Como no resto do HUB Comercial, admin vê e edita tudo; uma conta restrita veria apenas as renovações no nome dela, sem editar (`renovacoes`, migração 14).

#### Empresas com contrato assinado

O número de contratos assinados não diz **quais** empresas entraram, nem se o negócio valeu a pena. Embaixo dos quadros de cada pessoa há um painel **"Empresas com contrato assinado — <Pessoa>"**, com uma linha por empresa nova:

| Campo | O que é |
|---|---|
| Mês | em que mês o contrato foi assinado |
| Empresa | nome da empresa que entrou |
| CNPJ | preenchido com máscara automática (`00.000.000/0000-00`) |
| O negócio foi | **Rentável** ou **Não rentável** — um clique escolhe, clicar de novo desmarca |

Só entram empresas com **contrato já assinado**. A avaliação de rentabilidade começa em branco de propósito: a empresa é cadastrada quando o contrato é fechado, e o julgamento vem depois, quando há como julgar. O rodapé do painel conta quantas são rentáveis, não rentáveis e quantas ainda estão sem avaliação.

O CNPJ é conferido pelos dois dígitos verificadores. Quando não fecha, aparece um **"CNPJ incompleto"** discreto embaixo do campo — é só um aviso, nunca impede de salvar.

> **Conferência com o número digitado.** O campo *"contratos assinados"* continua sendo digitado à mão e **não** é calculado a partir desta lista — mudar isso apagaria o histórico já lançado. O que o HUB Comercial faz é mostrar os dois lado a lado: quando o número do mês não bate com a quantidade de empresas cadastradas, aparece um aviso âmbar dizendo exatamente qual mês e quais os dois números. Corrigir (ou não) é decisão de quem administra.

**O aviso é acionável.** Quando **faltam** empresas (lançado > cadastradas), cada mês divergente ganha um **"+ cadastrar N que faltam"**: cria as N linhas em branco já no mês certo e com o cursor no campo *Empresa* da primeira — resta digitar os nomes. Antes era preciso clicar em "+ Empresa", trocar o mês na linha, e repetir a cada uma.

O atalho **só aparece quando faltam**. Quando há mais empresas cadastradas do que o número lançado, o aviso continua, mas sem botão: ali o errado é o número digitado ou uma linha sobrando, e adivinhar qual dos dois seria pior do que avisar. Acima de 6 linhas o sistema pergunta antes, e cria no máximo 50 de uma vez — "contratos assinados" é campo digitado à mão, e um `500` por engano não pode despejar 500 linhas em branco na tela.

No cabeçalho do painel, o botão **"📊 Baixar lista (CSV)"** baixa a relação daquela pessoa no ano aberto — mês, empresa, CNPJ (com máscara) e a avaliação —, para abrir no Excel ou colar em outro lugar. Um arquivo por pessoa, como o painel mostra (`empresas-contrato-<pessoa>-<ano>.csv`). O botão só aparece quando há empresa cadastrada, para não oferecer arquivo vazio.

> O separador do CSV é `;` e nome de empresa é texto livre — pode ter ponto e vírgula, aspas ou quebra de linha. Por isso o texto passa por `csvTexto()`, que põe aspas quando precisa; sem isso a coluna escorregaria no Excel. E o arquivo sai com BOM (`﻿`), senão o Excel abre em UTF-8 sem saber e o acento vira caractere estranho.

As empresas do mês também saem no **relatório mensal em PDF**, numa seção própria com empresa, CNPJ, quem trouxe e a avaliação.

Como no resto do HUB Comercial, quem administra vê e edita tudo; uma conta restrita só enxergaria as empresas que ela mesma trouxe, e sem editar (`contratos_consultoria`, migração 10).

## Importar a planilha de Consultoria

Notas de antes do HUB Comercial existir não precisam ser digitadas uma por uma. O botão **"📄 Importar planilha"**, na aba Consultoria, lê o arquivo — mesmo mecanismo já usado pela planilha de renovações (`linhasDoXlsx`, `linhasDeTexto`, leitura de `.xlsx` sem biblioteca externa), só que reconhecendo as colunas do lançamento de consultoria em vez de empresa/valor/mês.

Três caminhos, todos no mesmo lugar: **arquivo `.xlsx`**, **arquivo `.csv`** (inclusive o que o Excel do Windows salva em latin-1) ou **colar** as células copiadas do Excel.

Colunas reconhecidas pelo nome do cabeçalho (com ou sem acento, em qualquer ordem): **Mês**, **Empresa**, **Valor**, **Tipo de contrato**, **Parceiro**, **Participação**, **Forma de pagamento**, **Colaborador**, **Vendedor** e **% Comissão**. Sem cabeçalho reconhecido, assume essa mesma ordem. O **tipo de contrato** cai em "Recuperação" quando o texto da planilha não bate com nenhuma das três opções válidas (Recuperação/Mensal/Personalizado); mês e valor aceitam os mesmos formatos livres da planilha de renovações.

Antes de gravar aparece uma **prévia** com todas as colunas lidas, linha a linha. Ficam de fora, sinalizadas em âmbar: **lançamentos já cadastrados** (mesma empresa, mês, ano e valor) e **linhas cujo mês não foi reconhecido**. O lançamento entra só com **um vendedor** (o campo Vendedor 2 e 3 ficam em branco, editáveis depois na tela) — igual a um lançamento novo criado na mão, dá pra editar qualquer campo depois de importado.

Por enquanto é só para a aba **Consultoria**; as outras abas de lançamento continuam sem importador de planilha.

## Relatório mensal em PDF

O botão **"📄 Relatório do mês"**, no topo de qualquer aba, gera um documento único com **tudo o que aconteceu num mês**. Ele abre com a **mesma faixa do HUB Comercial** — marca, degradê marinho, globo d'água e o filete azul —, então o papel sai com a cara da empresa. Escolhe-se o mês e o HUB Comercial monta o relatório e abre a janela de impressão do navegador — para salvar em PDF, basta escolher **"Salvar como PDF"** no destino.

O que entra:

| Seção | Conteúdo |
|---|---|
| Faturamento do mês | total por origem (Sistema, Consultoria, Órgãos Públicos, Cursos) e o total geral, mais comissões, honorários, bônus e comissões liberadas — e logo abaixo, um gráfico com o faturamento total da empresa (todos os produtos somados) mês a mês, os 12 meses do ano |
| Ganhos por vendedora | quanto cada uma ganhou em cada origem, mais bônus e total |
| Comissões liberadas | o que já pode ser pago, por vendedora (cliente já pagou a nota) |
| Sistema, Consultoria, Órgãos Públicos, Cursos | os lançamentos do mês, com valor, quem vendeu, situação do pagamento e as comissões de cada linha |
| Parceiros | honorários do mês, lançamento a lançamento |
| Bônus e metas | bônus lançados e a situação de cada meta configurada |
| Desempenho da equipe | o ranking completo — quem liderou cada indicador (com os empates) e o quadro da campeã do mês |
| Indicadores do mês | os nove indicadores, pessoa por pessoa |
| Comparativo do mês | gráficos de barras de vendas de sistemas, vendas de cursos e reuniões |
| Evolução do ano | gráficos de linha das vendas de sistemas e de cursos ao longo dos 12 meses |
| Totais do ano por vendedora | volume vendido no ano (não comissão) |
| Equipe de consultoria | cartão com o total de contratos assinados e de reuniões realizadas no mês (soma da equipe toda), e a tabela pessoa a pessoa |
| Marketing | uma linha por rede com lançamento no ano, com o mesmo resumo automático da aba Marketing — melhor crescimento e maior recuo do mês, comparado ao mês anterior que tiver lançamento —, seguida de um gráfico de evolução por rede (indicador numérico principal dela, 12 meses) e do gráfico de campanhas do Tráfego pago no mês |

Os gráficos são os mesmos do painel, desenhados em SVG dentro da própria página — saem no papel com as cores certas, sem depender de imagem nem de biblioteca.

O relatório usa o **ano selecionado** no topo da página. É exclusivo de admin — conta restrita não vê o botão, já que o documento mostra os números de toda a equipe.

O documento **não força quebra de página**: as seções correm uma atrás da outra e só evitam ser cortadas no meio de um bloco pequeno (um gráfico, o quadro da campeã, uma linha de tabela). Tabela que atravessa a página repete o cabeçalho.

> Não usa nenhuma biblioteca externa: o PDF sai pela impressão do próprio navegador. É de propósito — o HUB Comercial bloqueia carregar script de fora, por segurança.

## Metas e bônus

Uma meta é um **gatilho da empresa que premia uma pessoa**, não uma cota individual:

> Quando a empresa faturar **R$ 200.000 em Cursos** no mês, **Soraya** ganha **1% do total faturado**.

Cada meta tem quatro partes, configuráveis por regra (em **Resumo Geral → Metas**, escolhendo um mês no filtro):

| Parte | O que é |
|---|---|
| Quem recebe | a vendedora premiada |
| Onde é medido | Sistema, Consultoria, Órgãos Públicos, Cursos ou todas somadas |
| Alvo | quanto a empresa precisa faturar no mês (valor cheio dos contratos, antes de comissões e parceiros) |
| Prêmio | um valor fixo em R$, ou uma % **sobre o total faturado** |

A porcentagem incide sobre o **total faturado**, independente de quanto passou do alvo, e o prêmio fixo é somado **uma única vez** (não multiplica se o faturamento for o dobro do alvo).

A mesma pessoa pode ter mais de uma regra para o mesmo gatilho, e elas se somam. A regra em vigor hoje, por exemplo:

| Quem | Gatilho | Prêmio |
|---|---|---|
| Soraya | Cursos ≥ R$ 200.000 no mês | 1% do total vendido |
| Soraya | Cursos ≥ R$ 200.000 no mês | + R$ 750 |
| Angela | Cursos ≥ R$ 200.000 no mês | R$ 500 |

Faturando R$ 400.000 em Cursos: Soraya recebe R$ 4.000 (1% de 400 mil) **mais** R$ 750, e Angela recebe R$ 500.

Como as metas são mensais mas as regras costumam valer o ano todo, o botão 🔁 no card repete a mesma regra nos meses seguintes do ano, pulando os que já tiverem uma regra igual.

**Como o prêmio vira bônus:** ao bater, o card fica verde e aparece o botão *"Lançar bônus de R$ X"*. Alguém confirma e a linha vai para a aba **Bônus e Metas**, onde pode ser editada como qualquer outra. A linha guarda de qual meta veio, então a mesma meta nunca paga duas vezes — depois de lançada, o card passa a mostrar *"✓ bônus lançado"*.

Como a meta depende do faturamento da empresa inteira, **só admin configura e acompanha**. A vendedora premiada vê o resultado normalmente na aba Bônus, porque a linha leva o nome dela.

### Salário fixo do colaborador

Nem todo mundo é pago por comissão. Quem recebe **salário fixo** é lançado na mesma aba, no painel **"Salário fixo dos colaboradores"**, embaixo dos bônus:

| Campo | O que é |
|---|---|
| Mês | o mês de competência |
| Colaborador | qualquer pessoa conhecida do HUB Comercial — inclui quem não é vendedora, como a equipe de consultoria |
| Cargo / observação | texto livre (ex.: *Consultor comercial*) |
| Salário | o valor do mês |

O botão **🔁** repete o salário nos meses seguintes até dezembro, pulando meses fechados e meses que já tenham um salário lançado para a mesma pessoa — assim não é preciso digitar doze vezes.

> **O salário nunca entra nas somas de comissão.** Ele fica de fora do total em bônus/metas, da coluna "Bônus" do Resumo Geral e do gráfico de faturamento do ano. É despesa fixa da empresa, não prêmio por desempenho nem venda — misturar distorceria justamente o número que o HUB Comercial existe para medir. O total aparece num cartão próprio, **"Salários fixos"**, e numa seção própria do relatório mensal em PDF.

O acesso segue a mesma regra do resto: quem administra vê e lança tudo; uma conta restrita vê apenas o próprio salário, porque a linha leva o nome da pessoa (`bonus`, migração 11).

### Fechamento para a contabilidade

Entre os bônus e os salários há o quadro que responde a pergunta do fim do mês: **quanto mandar pagar para cada pessoa**. Ele acompanha o filtro de mês da aba — escolhendo "Todos", mostra o ano.

| Coluna | Entra no "Total a pagar"? |
|---|---|
| Sistema | sim |
| Órgãos Públicos | sim |
| Cursos | sim |
| Bônus | sim |
| Salário fixo | sim |
| **Total a pagar** | a soma das cinco — é o valor que vai para a contabilidade |
| Consultoria | **não** — fica à parte, em cinza |
| Com Consultoria | o total cheio, só para referência |

> **Por que a Consultoria fica fora.** A comissão de Consultoria só se realiza quando o cliente paga; enquanto isso é expectativa, não dinheiro do mês. Mandar pagar antes disso seria adiantar um valor que pode não ter entrado. Ela continua visível nas duas últimas colunas, e o **Resumo Geral** segue mostrando o total com tudo somado, como sempre.

A lista **não é só das vendedoras**: quem só recebe salário fixo — a equipe de consultoria, por exemplo — aparece também, senão faltaria gente na folha. Quem não tem nada no período fica fora, para o quadro não encher de linhas zeradas.

O botão **"📊 Baixar CSV"** gera o arquivo do período, uma linha por pessoa e o total no fim, pronto para mandar. O mesmo fechamento sai também no **relatório mensal em PDF**, em seção própria.

**Quem entra na folha** — o botão **"👥 Quem entra"** abre a lista de todas as pessoas que o HUB Comercial conhece, com uma caixa marcada para cada uma. Desmarcar alguém tira essa pessoa da tabela, do total, do CSV e do PDF. Não apaga lançamento nenhum: é só o que vai para a contabilidade, e o cabeçalho do painel avisa quantas estão de fora.

> O HUB Comercial guarda **quem fica de fora**, não quem fica dentro. É de propósito: assim uma pessoa cadastrada depois aparece na folha sozinha, em vez de sumir calada. Esquecer alguém num relatório de pagamento é bem pior do que ter uma linha a mais para tirar. A lista fica no banco (`entity_vendors` com `entidade='fechamento_fora'`), então vale para todo mundo, e só admin edita.

## Marketing

Marketing também é equipe — fica ao lado de **Relatório de Desempenho** e **Bônus e Metas**, no grupo "Equipe" do menu. Acompanha o crescimento das redes que a empresa mantém, para apresentar ao dono da empresa: **Instagram, YouTube, LinkedIn, TikTok, PodTributar e RD Station**, em **duas contas** — **Open** e **Foco Tributário**.

Um seletor de rede no topo da aba escolhe qual delas está em foco. **Nem toda rede tem as duas contas** — **YouTube é só Foco Tributário** (a Open não tem canal), e **TikTok e RD Station são só Open** (a Foco Tributário não usa nenhum dos dois). Em cada uma dessas redes, os cartões, o gráfico e a tabela só mostram a conta certa. É configurado em `MARKETING_REDES` (campo `contas`); de fábrica só essas três redes têm a restrição, mas o mesmo campo serve pra qualquer rede que só exista numa das duas contas.

**Os indicadores são configuráveis, por rede** (migração 26). Cada plataforma tem seu próprio conjunto de números — o YouTube tem "Receita estimada", o RD Station nem se parece com rede social — e quem administra **inclui e retira indicador pela própria tela**, sem precisar de migração de banco:

- O botão **"⚙️ Editar indicadores"**, no quadro de cartões, abre a lista dos indicadores daquela rede, cada um com um ✕ para retirar.
- **"+ Novo indicador em [rede]"** cadastra um indicador novo (só pede o nome) — passa a aparecer nos cartões, na tabela e no gráfico daquela rede.
- Retirar um indicador só tira ele da tela; os números já lançados continuam guardados no banco (`marketing_indicadores` define o catálogo, `marketing_metricas.valores` — um jsonb — guarda os valores por lançamento).
- Um indicador pode ser **texto** em vez de número (o caso de fábrica é "Vídeo popular" no YouTube — o nome do vídeo que mais rendeu no mês). Indicador de texto aparece no cartão e na tabela, mas fica de fora do gráfico e das contas de crescimento, que só fazem sentido para número.

De fábrica, cada rede já vem com um conjunto pensado para o que a diretoria quer acompanhar:

| Rede | Indicadores de fábrica |
|---|---|
| Instagram | Contas alcançadas, Impressões, Seguidores, Visitas, Interações |
| YouTube | Visualizações, Total de impressões, Novos inscritos, Receita estimada, Horas exibidas, Vídeo popular (texto), Interações |
| LinkedIn | Seguidores, Impressões, Interações |
| TikTok | Visualizações, Visitas, Seguidores, Total de espectadores, Novos espectadores, Compartilhamentos, Interações |
| PodTributar | Visualizações, Tempo de exibição (horas), Receita estimada — hospedado no YouTube, os números são os do YouTube Analytics |
| RD Station | Busca orgânica, YouTube, Sites (Foco/Open), Conversões, Visitas |

Cada indicador numérico vira um **cartão por conta**, com o valor do mês e a variação contra o mês anterior **que tiver lançamento** (não precisa ser o mês imediatamente anterior — se pular Junho, Julho compara com Maio), em número absoluto e em %.

**Resumo do mês** — logo abaixo dos cartões, um quadro em texto aponta o que mais vale a pena olhar naquela rede, sem precisar ler cartão por cartão: o indicador que **mais cresceu** e o que **mais caiu** no período, cada um com a conta, o valor e o %. Se algum indicador ainda não tem mês anterior pra comparar, o quadro avisa quantos estão nessa situação. Não é IA — é a mesma conta de crescimento dos cartões, só que a tela já escolhe os dois extremos em vez de a pessoa comparar todos. Sem um segundo mês lançado na rede, o quadro avisa que ainda não dá pra comparar.

**Gráfico de evolução mensal** — abaixo dos cartões, mostra o ano inteiro em barras (sempre os 12 meses de `yearFilter`, não muda com o filtro de mês) de um indicador escolhido no seletor "Indicador", uma barra por conta lado a lado em cada mês (Open e Foco Tributário, cada uma numa cor). Era gráfico de linha, mas com só 1 ou 2 meses lançados a linha virava um traço fino sem contexto — barra lê melhor um ano ainda incompleto. Mês sem lançamento simplesmente não tem barra ali, não é barra de altura zero.

Um filtro de mês (Todos + os 12 meses) recorta a tabela de lançamentos e os cartões ao mesmo tempo, igual ao resto do HUB Comercial. A tabela também segue os indicadores da rede: as colunas mudam sozinhas quando um indicador é incluído ou retirado.

### Leads do LinkedIn

As redes guardam "um número por mês". **Lead é outra natureza**: uma pessoa por linha. Por isso a pill do **LinkedIn** tem um painel próprio, **"Leads — LinkedIn"**, com tabela própria (`marketing_leads`, migração 29):

| Campo | O que é |
|---|---|
| Mês | em que mês o lead entrou |
| Nome | o nome da pessoa |
| Cargo | o cargo dela — é o que diz o poder de decisão |
| Empresa | onde ela trabalha |
| É órgão público? | **Órgão público** ou **Privado** — um clique escolhe, clicar de novo desmarca |

**Por que "órgão público" tem coluna própria:** a carteira da Open é cheia de MP, TRE, TRT, INPI. Órgão público compra por licitação, com ciclo e interlocutor diferentes de empresa privada — saber isso na origem muda como o lead é trabalhado. Pills no topo do painel filtram por **Órgão público / Privado / Sem classificar**, e o rodapé conta os três.

Como `rentavel` em contratos e `renovado` em renovações, a classificação tem **três estados**: `null` é "ainda não classificado" — é assim que o lead nasce na importação. Sem o `null`, "não classificado" e "não é órgão público" virariam a mesma coisa.

**Importar a lista** — o botão **"📄 Importar lista de leads"** lê `.xlsx` e `.csv`, ou aceita as células coladas do Excel (mesmo mecanismo das planilhas de renovações e de consultoria: `linhasDoXlsx`, `linhasDeTexto`, leitura de `.xlsx` sem biblioteca externa). Reconhece as colunas **Nome**, **Cargo**, **Empresa**, **Órgão público** e **Mês**, com ou sem acento, em qualquer ordem; sem cabeçalho reconhecido usa a ordem *nome, cargo, empresa* — que é como o LinkedIn exporta.

- Se a planilha traz a classificação, ela é aproveitada: `Sim`/`Público`/`Governo` → órgão público, `Não`/`Privado`/`Empresa` → privado. **Texto que não dá para interpretar não vira palpite** — fica em branco para a pessoa decidir.
- **Não importa duas vezes**: mesmo nome e mesma empresa já na lista do ano entra como *"já está na lista"* e fica de fora. Reimportar a planilha não dobra a lista.
- Sem mês na planilha, o lead entra no mês selecionado nas pills (ou no mês corrente, se o filtro está em "Todos").

O botão **"📊 Baixar lista (CSV)"** devolve a lista com mês, nome, cargo, empresa e a classificação.

`rede` está na tabela mesmo a tela só oferecendo LinkedIn hoje: lead de outra origem cabe sem migração nova — é trocar a condição em `renderMarketingSection`.

### Tráfego pago

Uma pill própria, na mesma barra das redes, ao lado de RD Station. Diferente delas, tráfego pago não é "um número por mês" — é uma **campanha de anúncio por vez**, com o conjunto de métricas que o gestor de tráfego já usa (Meta Ads e afins). Por isso é tabela separada (`marketing_campanhas`, migração 27), fora do sistema de indicadores configuráveis das redes.

Cada linha é uma campanha, num mês, numa conta, com os números **brutos** lançados à mão:

| Campo | O que é |
|---|---|
| Mês / Conta / Campanha | quando, em qual conta (Open ou Foco Tributário) e o nome da campanha |
| Valor investido / Orçamento diário | quanto foi gasto e o teto diário configurado |
| Alcance / Impressões | quantas contas o anúncio alcançou e quantas vezes apareceu |
| Cliques no link / Visitas na LP | quem clicou e quem de fato chegou na landing page |
| Leads / MQL | quantos converteram e quantos viraram lead qualificado |

E seis colunas **calculadas na hora**, nunca digitadas — mudam sozinhas se o gasto, os cliques ou os leads mudarem:

| Calculado | Fórmula |
|---|---|
| CPC | Valor investido ÷ Cliques no link |
| CPL | Valor investido ÷ Leads |
| CTR | Cliques no link ÷ Impressões |
| CPM | Valor investido ÷ Impressões × 1.000 |
| Connect rate | Visitas na LP ÷ Cliques no link |
| Custo/MQL | Valor investido ÷ MQL |

Denominador zero ou vazio dá **"—"**, nunca um erro ou um zero enganoso. Um filtro de mês recorta a tabela; o cabeçalho do quadro soma o total investido e o total de leads do que estiver visível. Lançar é só de admin, a leitura é aberta a qualquer conta logada — mesma regra do resto da aba Marketing.

**Gráfico de campanhas** — abaixo da tabela, uma barra por campanha do período filtrado, no indicador escolhido no seletor "Indicador" (qualquer um dos números brutos ou calculados — Valor investido, Leads, CPL, CTR...). Cada barra pega uma cor de uma paleta fixa, na ordem; o nome da campanha aparece truncado e inclinado embaixo, com o nome inteiro no balão ao passar o mouse. Some sozinho quando o filtro de mês não tem nenhuma campanha.

**Quem edita, quem vê.** Lançar e mexer nos indicadores é só de admin — a mesma regra em vigor no banco (RLS), não só na tela: uma conta restrita que tentasse gravar direto pela API seria barrada. A leitura é aberta pra qualquer conta logada, porque isso não é dado de comissão nem de contrato — é o placar que a equipe toda pode acompanhar. A conta financeira não vê a aba (ela só lida com valor de nota).

## Leitura em páginas (limite de 1.000 linhas)

O PostgREST devolve no máximo **1.000 linhas por chamada** — é o "Max rows" do projeto no Supabase. Passar disso **não dá erro**: ele simplesmente corta o resultado e devolve o que coube.

Foi o que aconteceu quando `vendas_comissoes` passou de 1.200 linhas (174 vendas × 7 vendedoras). O HUB Comercial recebia parte das comissões, os totais na tela ficavam **menores que a realidade**, e — pior — a gravação seguinte devolvia ao banco como vazio aquilo que não tinha sido lido.

Por isso **toda coleção que cresce é lida em páginas**, por `sbSelectTudo()`, até vir uma página incompleta. Duas regras ao mexer nisso:

- a consulta **precisa ter `order`**, senão o `offset` embaralha as páginas e linhas se repetem ou somem;
- ao criar uma coleção nova que possa passar de mil linhas, use `sbSelectTudo` (ou `sbSelectOpcional`, que já pagina), nunca `sbSelect` direto.

## O id de venda que era reaproveitado (e trocava a venda da renovação)

Este é o estrago maior, e ele se esconde atrás do anterior.

O id de uma venda nova é calculado **no navegador**, como `max(ids) + 1`. O banco tem uma sequence (`vendas_id_seq`), mas o app manda o `id` junto no upsert, então ela nunca avança — nos dados reais a sequence estava em **40** enquanto o maior id era **275**.

Consequência: **excluir a venda de maior id devolvia aquele número para a fila**, e a próxima venda criada nascia com o id da que foi excluída. Quando a venda excluída era a de uma renovação, o `venda_id` guardado nela passava a apontar para uma venda **nova e sem relação nenhuma** — outra empresa, outro mês, outro valor. Aconteceu duas vezes:

| Renovação | Passou a apontar para |
|---|---|
| INPI · Jan/2026 · R$ 14.388 | venda 76 = **PRODAP** · Abr/2026 · R$ 8.663,97 |
| MP RR · Out/2026 · R$ 14.388 | venda 268 = **TRE PA** · Set/**2027** · R$ 40.680 |

E cada uma dessas vendas ficou **reivindicada por duas renovações** — a dona legítima e a antiga, cujo ponteiro foi herdado. Foi o que fez a renovação do MP RR recusar virar upgrade sem ter saída: a trava perguntava "essa venda existe?", e existia — só não era dela.

Duas correções:

- **`reservarNextIdVendas()`** — o próximo id fica acima do maior id de venda existente **e** do maior id ainda referenciado por alguma renovação, e só cresce, nunca diminui (por isso é seguro chamar de vários pontos de carga, em qualquer ordem).
- **`supabase_renovacoes_venda_fk_migration.sql`** — cria um **índice único parcial** em `renovacoes(venda_id)`, para que uma venda nunca mais possa ser reivindicada por duas renovações sem o banco reclamar.

### A foreign key que não deu para manter

A primeira versão dessa migração criava também `foreign key (venda_id) references vendas(id) on delete set null` — a solução certa no lugar certo, que dispensaria o app lembrar de soltar a renovação. **Ela foi aplicada, testada e revertida.**

O app grava vendas e renovações em **duas requisições independentes**, cada uma com seu debounce de 450ms e sem transação em comum. No lançamento (`confirmarLancarNoSistema`) a renovação já sai apontando para a venda nova, e as duas gravações partem quase juntas — mas a de renovações é **uma** chamada, enquanto a de vendas escreve ~275 vendas **mais** ~1.900 linhas de `vendas_comissoes`. A das renovações chega primeiro, a venda ainda não existe no banco, e a FK rejeita: **"erro ao salvar" em todo lançamento de renovação**, com o vínculo perdido. Pior que o bug que ela evitava.

`DEFERRABLE` não resolve: cada requisição é sua própria transação, e o check adiado acontece no commit dela. Para voltar a FK é preciso antes tornar a gravação **sequencial** — venda confirmada no banco, e só então a renovação.

> Duas lições. **Id de linha calculado no cliente não pode ser reaproveitado se alguém guarda referência a ele** — o `max+1` parece inofensivo até a primeira exclusão do topo. E **integridade referencial no banco pressupõe escrita transacional**: num app que salva tabela por tabela, com debounce e sem transação, uma FK entre elas vira uma corrida — a restrição correta no modelo errado. Onde não houver transação, prefira a trava que não depende de ordem (aqui, o índice único).

## A renovação presa numa venda que não existe mais

Marcar uma renovação como **Upgrade** respondia *"já foi lançada como venda na aba Sistema — exclua a venda por lá primeiro"*. Excluía a venda, tentava de novo, e a mesma resposta voltava. Sem saída pela tela.

A renovação guarda o id da venda que gerou (`renovacoes.venda_id`), e `deleteRow` — que exclui a venda na aba HUB Comercial — **nunca limpava essa marca**. A renovação ficava órfã, apontando para uma venda que já não existia, e nesse estado:

- continuava com a etiqueta **"no Sistema"**;
- ficava **fora** da fila de "Lançar no Sistema", que exige `!vendaId`;
- **recusava virar upgrade**, pedindo para excluir uma venda já excluída.

Pior: o sistema **já detectava** o problema — clicar na etiqueta avisava *"a venda desta renovação não está mais na aba Sistema"* — e mesmo assim não fazia nada com essa informação.

A correção tem três frentes:

- **Na origem** — excluir a venda solta a renovação que apontava para ela (`soltarRenovacoesOrfas` dentro de `deleteRow`). Excluir a venda é justamente o que deveria liberar a renovação.
- **Na trava** — as travas de upgrade e de situação perguntavam só *"tem `vendaId`?"*. Agora perguntam *"a venda ainda existe?"* (`renovacaoPresaNaVenda`), e um vínculo morto é soltado na hora em vez de barrar para sempre.
- **No que já quebrou** — ao terminar de carregar, o sistema solta as renovações que ficaram apontando para vendas excluídas antes desta correção existir. Quem estava travado é destravado só de recarregar a página.

> **A trava que torna isso seguro** é `carregouDoBanco.vendas`. Antes de as vendas voltarem do banco, `rows` está vazio — e sem essa checagem *todo* vínculo legítimo pareceria morto e seria apagado. A regra vale para qualquer limpeza de dado derivado: **nunca concluir que algo não existe antes de ter lido**. É a mesma regra que já protege `persistEntityVendors` ("nunca apagar sem ter lido antes").

## O campo que morria no meio da digitação

Digitar o nome de um curso (ou o nome do cliente no HUB Comercial), parar um instante para pensar e voltar a escrever: o resto do texto não entrava mais. Não era o teclado — era o campo, que tinha perdido o foco sozinho.

A cadeia: cada tecla agenda a gravação (`persistEntityRows`, com 450ms de espera); ao gravar, as duas abas que alimentam o Relatório de Desempenho — **Cursos** e **HUB Comercial** — chamam `agendarRefreshPainel()`, que 700ms depois relê os totais e chamava `render()`. E `render()` troca o `innerHTML` **inteiro**: o campo em que a pessoa estava digitando era destruído e recriado, sem foco. Ou seja: cerca de **1,2s depois da última tecla**, o campo morria. Consultoria e Órgãos Públicos não sofriam disso, porque não alimentam o painel — o que fazia o bug parecer intermitente.

A correção tem duas camadas:

- **A causa** — o refresh dos totais só redesenha a tela **se o painel estiver aberto** (`activeTab === 'painel'`). Fora dele basta guardar os números na memória: o Relatório de Desempenho e o relatório em PDF leem de lá na hora em que são montados.
- **A rede de segurança** — `render()` agora **anota o campo em foco antes e devolve o foco depois**, com a posição do cursor (`focoParaRestaurar` / `devolverFoco`). O campo é reencontrado pelos mesmos atributos com que foi montado (`data-entity`, `data-id`, `data-field`). Se um modal estiver aberto, nada é devolvido — o foco é dele. Isso protege qualquer campo de qualquer render assíncrono, não só desses dois.

> Ao mexer em `render()`, lembre que **todo render é uma troca completa de DOM**. Qualquer coisa que redesenhe a tela sozinha (resposta do banco, timer, refresh) pode cair no meio de alguém digitando. A pergunta certa antes de chamar `render()` num caminho assíncrono é: *esse dado está na tela agora?* Se não estiver, guardar na memória basta.

## Backup manual

Dentro do próprio HUB Comercial, o botão **"⬇ Exportar dados"** (no topo da tela) gera um backup completo em texto — útil pra guardar uma cópia de segurança de vez em quando, independente do banco de dados.

## Segurança — revisão feita neste projeto

- **Login obrigatório**: o acesso deixou de ser "quem tem o link, edita" — agora é preciso login (Supabase Auth) e o banco só aceita requisições autenticadas. Veja "Login e segurança" acima.
- **Nível financeiro**: um terceiro nível de conta, para quem confere faturamento e não pode ver remuneração — enxerga o valor de todas as notas e nenhuma comissão, bônus, meta ou salário. Feito no banco (RLS + views `_safe`), não na tela. Veja "Nível financeiro" acima.
- **Escrita por porta estreita**: essa conta precisa marcar as notas emitidas, mas dar-lhe update em `vendas`/`lancamentos` abriria a tabela inteira — RLS filtra linha, não coluna. O visto passa por uma função `security definer` que confere o nível de acesso e altera uma única coluna; a conta continua sem nenhuma permissão de escrita direta.
- **Acesso por pessoa**: além de exigir login, o banco distingue admins (acesso total) de contas restritas (somente leitura, só dos próprios lançamentos) — a comparação de nomes é feita inteiramente no Postgres, então mesmo alguém manipulando as chamadas à API diretamente (sem passar pela tela) não consegue ver ou editar dado de outra pessoa.
- **Linha de comissão vazia não conta como participação**: o app grava uma linha em `vendas_comissoes` para cada vendedora em cada venda, quase sempre com valor nulo. Enquanto a regra checava só "existe linha", bastava alguém estar cadastrada como vendedora para enxergar todas as vendas da aba Sistema. Corrigido: agora exige valor preenchido.
- **Funções auxiliares fechadas para quem não fez login**: elas eram chamáveis pelo papel `anon` via `/rest/v1/rpc/`, e uma delas aceitava um nome qualquer — dava para perguntar "fulano participa do lançamento X?" sem ter conta. Acesso revogado e a função passou a responder só sobre quem está logado.
- **Mascaramento por coluna**: filtrar linhas não bastava, porque um contrato dividido guarda até 3 vendedores + colaborador na mesma linha — quem participava enxergava a % dos colegas daquele contrato. A leitura passou a ser feita por views `_safe`, que zeram coluna a coluna o que não é da pessoa, e a leitura direta das tabelas base ficou restrita a admin, pra que o mascaramento não seja contornável pela API.
- **Falha de XSS corrigida**: os nomes de vendedoras (aba Sistema) e de vendedores por aba eram inseridos em alguns lugares da tela sem escapar caracteres especiais, permitindo que um nome malicioso injetasse HTML/JavaScript na tela de outras pessoas da equipe. Todos os pontos foram corrigidos para escapar esse texto (ou usar atributos `data-*` em vez de montar o JavaScript do botão como texto).
- **Content-Security-Policy**: foi adicionada uma política restritiva (`script-src`, `connect-src` limitado ao domínio do Supabase, sem `object-src`, sem `form-action`) como camada extra de proteção contra XSS futuro.
- **Sessão com renovação automática**: o token de login é renovado sozinho antes de expirar; se a renovação falhar (ex: sessão revogada), a pessoa volta pra tela de login em vez de o HUB Comercial travar ou salvar dados sem permissão.
- **Recuperação de senha**: a tela de login tem "Esqueci minha senha", que usa o fluxo de recuperação por e-mail do Supabase — ninguém depende de admin pra trocar senha esquecida.
