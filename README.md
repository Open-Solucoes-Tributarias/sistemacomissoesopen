# Comissões — Open Soluções Tributárias

Sistema de controle de vendas, comissões, parceiros e pagamentos da equipe comercial.

## Stack

- **Frontend**: HTML + JavaScript puro (nenhum framework, nenhuma etapa de build).
- **Banco de dados**: [Supabase](https://supabase.com) (Postgres).
- **Hospedagem**: qualquer serviço de site estático (Vercel, Netlify, GitHub Pages...).

## Visual

O sistema segue o mesmo padrão do **Gestão de Logística da Open**: barra lateral fixa com o menu agrupado (Visão geral / Lançamentos / Equipe), faixa de título em degradê marinho→azul no topo de cada aba, fundo azulado claro e cartões brancos de borda azul com cantos arredondados. Os cartões de indicador ficam levemente tingidos com a cor da pessoa ou do indicador.

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
6. Rode `supabase_metas_migration.sql` — novo formato das metas (recria a tabela `metas`).
7. Rode `supabase_painel_equipe_migration.sql` — cria a tabela do Painel da Equipe, a view `painel_equipe_totais` (que calcula os indicadores de venda) e a lista de quem aparece no painel.
8. Rode `supabase_vendedor_responsavel_migration.sql` — cria a coluna "Quem vendeu" nas abas Sistema e Cursos, e faz o painel contar uma venda por pessoa.
9. Rode `supabase_vendas_curso_por_vendedora_migration.sql` — troca o "quem vendeu" do curso pela divisão do faturamento por vendedora.
10. Rode `supabase_contratos_reunioes_migration.sql` — cria a equipe de consultoria (contratos e reuniões).
11. Cadastre cada pessoa em `app_user_access` (passo 4 acima). **Faça isso antes do próximo passo**, ou a equipe toda fica sem ver dado nenhum.
12. Só depois publique esta versão atualizada do `index.html`.

⚠️ A partir da migração 3, o `index.html` lê pelas views `_safe`. Uma versão antiga do front, apontando para as tabelas base, mostraria tudo vazio para as contas restritas — publique o `index.html` desta versão junto.

### Tabelas criadas

| Tabela | Conteúdo |
|---|---|
| `vendas` | Lançamentos da aba Sistema (inclui `vendedor_responsavel` — quem efetivamente fez a venda) |
| `vendas_comissoes` | Comissão de cada vendedor(a) por lançamento do Sistema |
| `lancamentos` | Lançamentos de Consultoria, Consultoria Órgãos Públicos e Cursos (uma tabela só, filtrada pela coluna `entidade`) |
| `lancamentos_extra_vendedores` | Vendedores extras (4º em diante) por lançamento |
| `lancamento_vendas` | Divisão do faturamento de um curso entre quem vendeu (sem relação com comissão) |
| `bonus` | Bônus e metas batidas |
| `metas` | Regras de meta: gatilho da empresa + prêmio de quem bate |
| `relatorios_equipe` | Indicadores mensais digitados: andamento da equipe e contratos/reuniões (Painel da Equipe) |
| `partners` | Parceiros cadastrados |
| `venda_products` | Catálogo de produtos da aba Sistema |
| `sellers` | Vendedoras do Sistema (lista editável) |
| `entity_vendors` | Vendedores(as) por aba (Consultoria / Órgãos Públicos / Cursos), quem aparece no Painel da Equipe (`entidade='painel'`) e quem é acompanhado por contratos/reuniões (`entidade='painel_contratos'`) |
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

Cada vendedor(a) logado enxerga **apenas as próprias linhas** — é o mesmo corte de acesso do resto do sistema, feito no banco. Admin vê todo mundo, agrupado por pessoa e com subtotal.

> **Cursos não tem controle de pagamento.** As abas Sistema, Consultoria e Órgãos Públicos têm a coluna "Pago"; a de Cursos não, então lançamentos de curso não aparecem nesses dois quadros. Se a equipe de cursos também passar a receber só depois do pagamento, dá pra ativar o controle lá.

## Painel da Equipe

Aba própria, para acompanhar o **andamento** da equipe — o esforço, não só o resultado financeiro.

São nove indicadores por vendedora, por mês, divididos em dois grupos:

| Grupo | Indicadores | De onde vem |
|---|---|---|
| Andamento | Interação, Propostas, Prospecção zero, Prospecção, Negócios abertos, Reuniões realizadas | **digitado à mão** todo mês |
| Vendas | Vendas de cursos (R$), Vendas de sistemas (R$), Qtd. sistemas vendidos | **calculado sozinho** pelos lançamentos que já existem no sistema |

**Os três indicadores de venda não são mais digitados.** Quem faz a soma é a view `painel_equipe_totais` no banco:

Os três saem da coluna **"Quem vendeu"** dos lançamentos: cada venda conta para **uma pessoa só**, a que estiver marcada ali. Lançamento sem essa marcação não conta para ninguém, e o sistema avisa quantos estão assim.

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

O nome de quem vendeu no Sistema tem a mesma máscara dos outros vendedores: conta restrita só lê se for ela mesma. A divisão dos cursos é só de admin — cada vendedora vê o próprio total pelo Painel da Equipe.

A aba **Consultoria** e a de **Órgãos Públicos** não têm essa coluna — o painel não conta essas duas origens.

**Lançamento** — escolhe a vendedora, o mês e preenche os **seis** campos de andamento. Logo abaixo, um bloco cinza mostra os três indicadores de venda já calculados daquele mês, só para conferência. Se aquele mês já foi lançado, o formulário abre preenchido e o botão vira "Atualizar". Ao lado, cada vendedora tem um quadro com os meses já lançados, com atalhos para editar ou excluir.

**Dashboard** — cartões com o total do ano por pessoa, **ranking do mês**, gráfico de barras comparando as pessoas num indicador, evolução mensal em linhas ao longo dos 12 meses, e a tabela de totais anuais.

No ranking, cada indicador mostra quem liderou; **quem empata aparece junto**, com o valor uma vez só.

**A campeã do mês é quem liderou mais indicadores** — conta-se quantas vezes o nome da pessoa aparece na frente, e pronto. Não há pontuação por 2º ou 3º lugar.

- Empate num indicador conta **vitória para todas as empatadas**.
- Quem está **zerado** num indicador não vence nele.
- Se duas pessoas terminarem com o mesmo número de vitórias, o quadro mostra as duas como melhores do mês.

> **Por que não é uma soma de pontos.** A primeira versão dava N pontos ao 1º lugar, N−1 ao 2º e assim por diante. Num time de quatro, quatro segundos lugares (3+3+3+3 = 12) valiam mais que uma liderança isolada, e acabava campeã quem não tinha vencido nada — foi exatamente o que apareceu num mês real, com a segunda colocada de todos os indicadores no topo. Contar lideranças resolve isso.

> Os totais de venda são calculados pelo banco, e o painel os relê **depois de cada gravação** nas abas Sistema e Cursos, além de toda vez que a aba é aberta. Não precisa recarregar a página para o mês aparecer.

**Quem aparece** — o painel tem a **própria lista de pessoas**, separada da lista de vendedoras do sistema, porque ele acompanha só a equipe comercial que lança andamento. Hoje são **Angela, Rios, Uilma e Luciana**. Quem é admin muda isso pelo botão **"Quem aparece"** no topo do painel, marcando ou desmarcando nomes — desmarcar alguém só tira do painel, não mexe em lançamento, comissão nem em nenhuma outra aba. A lista fica no banco (`entity_vendors` com `entidade='painel'`), então vale para todo mundo.

O ano vem do filtro no topo da página — não é fixo.

> **Contas restritas veem o ranking e o comparativo**, com os números de todo mundo — foi uma escolha de quem administra o sistema, para o painel funcionar como placar da equipe. O que elas continuam **não** vendo é o que está por trás desses números: cliente, contrato, percentual e comissão dos colegas seguem escondidos, porque a view `painel_equipe_totais` devolve só os totais por pessoa/mês. Lançar e editar continua sendo exclusivo de admin.

### Equipe de consultoria

Nem todo mundo é medido pelos mesmos indicadores. A **equipe de consultoria** — o Davidson é o primeiro caso — não vende: assina contratos e faz reuniões. Por isso tem uma aba própria dentro do painel, chamada **"Equipe de consultoria"**.

É uma **lista separada** da de vendedoras, com **dois indicadores** por pessoa e por mês: *contratos assinados* e *reuniões realizadas*. Escolhe-se a pessoa, o mês, digita os dois números e salva. Ao lado, cada pessoa tem um quadro com os meses lançados e o total do ano.

Para incluir alguém, use **"Quem está na equipe"** no topo da aba: marque quem já existe no sistema, ou cadastre um nome novo pelo botão do fim da lista. A lista fica no banco (`entity_vendors` com `entidade='painel_contratos'`), então vale para todo mundo.

> Quem está nessa lista **não entra no ranking de vendas** e não aparece nos cartões do dashboard — o ranking mede quem vende, e essas pessoas são medidas por outra coisa. As duas listas são independentes: a mesma pessoa pode estar nas duas, se fizer sentido.

## Relatório mensal em PDF

O botão **"📄 Relatório do mês"**, no topo de qualquer aba, gera um documento único com **tudo o que aconteceu num mês**. Escolhe-se o mês e o sistema monta o relatório e abre a janela de impressão do navegador — para salvar em PDF, basta escolher **"Salvar como PDF"** no destino.

O que entra:

| Seção | Conteúdo |
|---|---|
| Faturamento do mês | total por origem (Sistema, Consultoria, Órgãos Públicos, Cursos) e o total geral, mais comissões, honorários, bônus e comissões liberadas |
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
| Equipe de consultoria | contratos assinados e reuniões realizadas |

Os gráficos são os mesmos do painel, desenhados em SVG dentro da própria página — saem no papel com as cores certas, sem depender de imagem nem de biblioteca.

O relatório usa o **ano selecionado** no topo da página. É exclusivo de admin — conta restrita não vê o botão, já que o documento mostra os números de toda a equipe.

O documento **não força quebra de página**: as seções correm uma atrás da outra e só evitam ser cortadas no meio de um bloco pequeno (um gráfico, o quadro da campeã, uma linha de tabela). Tabela que atravessa a página repete o cabeçalho.

> Não usa nenhuma biblioteca externa: o PDF sai pela impressão do próprio navegador. É de propósito — o sistema bloqueia carregar script de fora, por segurança.

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
