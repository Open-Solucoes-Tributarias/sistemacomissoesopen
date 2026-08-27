-- Vendedores(as) dinâmicos do Sistema
create table sellers (
  id bigserial primary key,
  key text unique not null,
  label text not null,
  color text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- Parceiros cadastrados (usados em todas as abas)
create table partners (
  id bigserial primary key,
  name text unique not null,
  created_at timestamptz not null default now()
);

-- Catálogo de produtos da aba Sistema
create table venda_products (
  id bigserial primary key,
  name text unique not null,
  created_at timestamptz not null default now()
);

-- Listas de vendedores(as) por aba (consultoria / publicos / cursos)
create table entity_vendors (
  id bigserial primary key,
  -- 'painel' não é aba de lançamento: guarda quem aparece no Painel da Equipe
  entidade text not null check (entidade in ('consultoria','publicos','cursos','painel','painel_contratos')),
  vendor_name text not null,
  unique(entidade, vendor_name)
);

-- Lançamentos da aba Sistema
create table vendas (
  id bigserial primary key,
  ano int not null,
  mes text not null,
  cliente text default '',
  venda text default '',
  valor numeric,
  parceiro text default '',
  participacao numeric,
  forma_pagamento text default '',
  colaborador text default '',
  observacoes text default '',
  vendedor2 text default '',
  vendedor3 text default '',
  -- quem EFETIVAMENTE fez a venda (≠ quem ganha comissão nela)
  vendedor_responsavel text,
  pago boolean not null default false,
  mes_pagamento text,
  parcela_label text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Comissão de cada vendedor(a) por lançamento do Sistema (modelo dinâmico, 1 linha por vendedor com valor)
create table vendas_comissoes (
  id bigserial primary key,
  venda_id bigint not null references vendas(id) on delete cascade,
  seller_key text not null,
  valor numeric,
  unique(venda_id, seller_key)
);

-- Lançamentos das abas Consultoria / Órgãos Públicos / Cursos (estrutura compartilhada)
create table lancamentos (
  id bigserial primary key,
  entidade text not null check (entidade in ('consultoria','publicos','cursos')),
  ano int not null,
  mes text not null,
  nome text default '',
  valor_contrato numeric,
  tipo text,
  parceiro text default '',
  participacao numeric,
  forma_pagamento text default '',
  colaborador text default '',
  observacoes text default '',
  comissao_percent numeric,
  vendedor text default '',
  comissao_percent2 numeric,
  vendedor2 text default '',
  comissao_percent3 numeric,
  vendedor3 text default '',
  pago boolean not null default false,
  mes_pagamento text,
  parcela_label text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Vendedores(as) extras (4º em diante) por lançamento
create table lancamentos_extra_vendedores (
  id bigserial primary key,
  lancamento_id bigint not null references lancamentos(id) on delete cascade,
  vendedor text default '',
  percent numeric
);

-- Divisão do faturamento de um curso entre quem realmente vendeu.
-- O lançamento guarda o total; aqui fica quanto cada vendedora trouxe.
-- Não tem relação com comissão.
create table lancamento_vendas (
  id bigserial primary key,
  lancamento_id bigint not null references lancamentos(id) on delete cascade,
  vendedor text not null,
  valor numeric,
  created_at timestamptz not null default now(),
  unique(lancamento_id, vendedor)
);
create index on lancamento_vendas (lancamento_id);

-- Bônus e metas batidas
create table bonus (
  id bigserial primary key,
  ano int not null,
  mes text not null,
  vendedor text default '',
  descricao text default '',
  valor numeric,
  -- preenchido quando o bônus veio de uma meta batida; o índice único
  -- mais abaixo garante que a mesma meta nunca pague duas vezes
  meta_id bigint,
  created_at timestamptz not null default now()
);

-- Metas: gatilho da EMPRESA que premia uma pessoa.
-- "quando a empresa faturar R$ <alvo> em <origem> no mês,
--  <vendedor> ganha <prêmio>", onde o prêmio é um valor fixo ou uma
-- % sobre o TOTAL faturado (não sobre o que passou do alvo).
create table metas (
  id bigserial primary key,
  ano int not null,
  mes text not null,
  vendedor text not null,                        -- quem recebe o prêmio
  origem text not null
    check (origem in ('sistema','consultoria','publicos','cursos','todas')),
  alvo numeric not null check (alvo > 0),
  premio_tipo text not null
    check (premio_tipo in ('fixo','percentual_total')),
  premio_valor numeric not null check (premio_valor > 0),
  descricao text default '',
  created_at timestamptz not null default now()
);

-- Meses fechados (trava edição)
create table closed_months (
  id bigserial primary key,
  ano int not null,
  mes text not null,
  unique(ano, mes)
);

-- Anos extras criados manualmente (ex: virada de ano)
create table extra_years (
  id bigserial primary key,
  ano int unique not null
);

create index on vendas (ano, mes);
create index on lancamentos (entidade, ano, mes);
create index on bonus (ano, mes);
create index on metas (ano, mes);
alter table bonus add constraint bonus_meta_fk foreign key (meta_id) references metas(id) on delete set null;
create unique index bonus_meta_unico on bonus (meta_id) where meta_id is not null;
create index on vendas_comissoes (venda_id);
create index on lancamentos_extra_vendedores (lancamento_id);

-- ============================================================
-- Segurança: login obrigatório + acesso por pessoa
-- ============================================================
-- O sistema exige login (Supabase Auth). Além disso, nem todo mundo
-- autenticado vê tudo: existem duas categorias de conta —
--   • admin (full_access = true): lê e escreve em todos os dados.
--   • restrita (full_access = false, com um person_name): só
--     enxerga (somente leitura) os lançamentos onde esse nome
--     aparece como vendedor/colaborador — nunca edita nada.
-- Isso é controlado pela tabela app_user_access abaixo. Veja o
-- README para instruções de como cadastrar cada pessoa da equipe.

create table app_user_access (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  full_access boolean not null default false,
  person_name text,
  created_at timestamptz not null default now()
);
alter table app_user_access enable row level security;

-- Cada pessoa só consegue ler a própria linha (o app usa isso pra saber
-- se deve abrir em modo admin ou somente leitura). Não existe política
-- de insert/update/delete pra "authenticated" nesta tabela de propósito:
-- só quem tem acesso direto ao banco pode conceder acesso.
create policy "self read access" on app_user_access for select to authenticated
  using (auth_user_id = auth.uid());

-- Funções auxiliares (security definer: leem app_user_access ignorando a
-- RLS dela mesma, senão viraria referência circular).
create or replace function public.current_user_is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce((select full_access from app_user_access where auth_user_id = auth.uid()), false);
$$;

create or replace function public.current_user_person_name()
returns text
language sql
security definer
set search_path = public
stable
as $$
  select person_name from app_user_access where auth_user_id = auth.uid();
$$;

-- Compara nomes ignorando maiúsculas/minúsculas e espaços nas pontas
-- (os dados têm digitação inconsistente, ex: "Gustavo" vs "Gustavo ").
create or replace function public.name_matches(a text, b text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select a is not null and b is not null and btrim(a) <> '' and lower(btrim(a)) = lower(btrim(b));
$$;

-- Responde apenas sobre a PESSOA LOGADA. Não recebe nome por parâmetro de
-- propósito: assim ninguém consegue usá-la via /rest/v1/rpc/ como oráculo
-- ("fulano participa do lançamento X?").
create or replace function public.lancamento_tem_extra_vendedor_meu(lanc_id bigint)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from lancamentos_extra_vendedores ev
    where ev.lancamento_id = lanc_id
      and name_matches(ev.vendedor, current_user_person_name())
  );
$$;

-- Nada disso deve ser alcançável sem login (papel `anon`).
revoke all on function public.current_user_is_admin() from public, anon;
revoke all on function public.current_user_person_name() from public, anon;
revoke all on function public.name_matches(text,text) from public, anon;
revoke all on function public.lancamento_tem_extra_vendedor_meu(bigint) from public, anon;
-- `authenticated` precisa destas: as políticas de RLS as avaliam no
-- contexto de quem está consultando.
grant execute on function public.current_user_is_admin() to authenticated;
grant execute on function public.current_user_person_name() to authenticated;
grant execute on function public.name_matches(text,text) to authenticated;
grant execute on function public.lancamento_tem_extra_vendedor_meu(bigint) to authenticated;

alter table sellers enable row level security;
alter table partners enable row level security;
alter table venda_products enable row level security;
alter table entity_vendors enable row level security;
alter table vendas enable row level security;
alter table vendas_comissoes enable row level security;
alter table lancamentos enable row level security;
alter table lancamentos_extra_vendedores enable row level security;
alter table lancamento_vendas enable row level security;
alter table bonus enable row level security;
alter table metas enable row level security;
alter table closed_months enable row level security;
alter table extra_years enable row level security;

-- Tabelas de catálogo/referência (não são "de uma pessoa"): qualquer
-- autenticado lê, só admin escreve.
do $$
declare t text;
begin
  foreach t in array array['sellers','partners','venda_products','entity_vendors','closed_months','extra_years'] loop
    execute format('create policy "catalog read" on %I for select to authenticated using (true)', t);
    execute format('create policy "catalog admin insert" on %I for insert to authenticated with check (current_user_is_admin())', t);
    execute format('create policy "catalog admin update" on %I for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin())', t);
    execute format('create policy "catalog admin delete" on %I for delete to authenticated using (current_user_is_admin())', t);
  end loop;
end $$;

-- bonus
create policy "select own or admin" on bonus for select to authenticated
  using (current_user_is_admin() or name_matches(vendedor, current_user_person_name()));
create policy "admin insert" on bonus for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on bonus for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on bonus for delete to authenticated using (current_user_is_admin());

-- lancamento_vendas: divisão do faturamento de um curso. É um dado de
-- gestão da equipe inteira, então só admin lê e escreve; cada vendedora
-- vê o próprio total pelo Painel da Equipe, que passa por view agregada.
create policy "select admin only" on lancamento_vendas for select to authenticated using (current_user_is_admin());
create policy "admin insert" on lancamento_vendas for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on lancamento_vendas for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on lancamento_vendas for delete to authenticated using (current_user_is_admin());

-- metas: dependem do faturamento da empresa inteira, que conta restrita
-- não pode ver, então configurar e acompanhar é exclusivo de admin.
-- (A premiada vê o resultado na aba Bônus, que leva o nome dela.)
create policy "select admin only" on metas for select to authenticated
  using (current_user_is_admin());
create policy "admin insert" on metas for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on metas for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on metas for delete to authenticated using (current_user_is_admin());

-- lancamentos (consultoria / publicos / cursos)
-- Leitura das tabelas com dados de varias pessoas na mesma linha e
-- exclusiva de admin: as contas restritas leem pelas views "_safe"
-- definidas mais abaixo, que mascaram coluna a coluna.
create policy "select admin only" on lancamentos for select to authenticated
  using (current_user_is_admin());
create policy "admin insert" on lancamentos for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on lancamentos for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on lancamentos for delete to authenticated using (current_user_is_admin());

-- lancamentos_extra_vendedores
create policy "select admin only" on lancamentos_extra_vendedores for select to authenticated
  using (current_user_is_admin());
create policy "admin insert" on lancamentos_extra_vendedores for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on lancamentos_extra_vendedores for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on lancamentos_extra_vendedores for delete to authenticated using (current_user_is_admin());

-- vendas (aba Sistema)
create policy "select admin only" on vendas for select to authenticated
  using (current_user_is_admin());
create policy "admin insert" on vendas for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on vendas for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on vendas for delete to authenticated using (current_user_is_admin());

-- vendas_comissoes
create policy "select own or admin" on vendas_comissoes for select to authenticated
  using (
    current_user_is_admin()
    or exists (
      select 1 from sellers s where s.key = seller_key and name_matches(s.label, current_user_person_name())
    )
  );
create policy "admin insert" on vendas_comissoes for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on vendas_comissoes for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on vendas_comissoes for delete to authenticated using (current_user_is_admin());

-- ============================================================
-- Views "_safe": leitura das contas restritas (mascaramento por coluna)
-- ============================================================
-- RLS controla quais LINHAS aparecem, mas nao quais COLUNAS. Como um
-- lancamento pode ter 3 vendedores + colaborador na mesma linha, sem
-- isto quem participa de um contrato dividido veria o nome e a % dos
-- colegas daquele contrato. Estas views sao criadas pelo dono do banco
-- (postgres, com bypassrls) e aplicam o filtro por dentro; o app le por
-- elas, nunca pelas tabelas base.

create or replace view lancamentos_safe with (security_barrier = true) as
select
  id, entidade, ano, mes, nome, valor_contrato, tipo, parceiro, participacao,
  forma_pagamento, observacoes,
  case when current_user_is_admin() or name_matches(colaborador, current_user_person_name()) then colaborador else null end as colaborador,
  case when current_user_is_admin() or name_matches(vendedor,  current_user_person_name()) then vendedor          else null end as vendedor,
  case when current_user_is_admin() or name_matches(vendedor,  current_user_person_name()) then comissao_percent  else null end as comissao_percent,
  case when current_user_is_admin() or name_matches(vendedor2, current_user_person_name()) then vendedor2         else null end as vendedor2,
  case when current_user_is_admin() or name_matches(vendedor2, current_user_person_name()) then comissao_percent2 else null end as comissao_percent2,
  case when current_user_is_admin() or name_matches(vendedor3, current_user_person_name()) then vendedor3         else null end as vendedor3,
  case when current_user_is_admin() or name_matches(vendedor3, current_user_person_name()) then comissao_percent3 else null end as comissao_percent3,
  pago, mes_pagamento, parcela_label, created_at, updated_at
from lancamentos
where current_user_is_admin()
   or name_matches(vendedor,  current_user_person_name())
   or name_matches(vendedor2, current_user_person_name())
   or name_matches(vendedor3, current_user_person_name())
   or name_matches(colaborador, current_user_person_name())
   or lancamento_tem_extra_vendedor_meu(id);

create or replace view lancamentos_extra_vendedores_safe with (security_barrier = true) as
select id, lancamento_id, vendedor, percent
from lancamentos_extra_vendedores
where current_user_is_admin()
   or name_matches(vendedor, current_user_person_name());

create or replace view vendas_safe with (security_barrier = true) as
select
  id, ano, mes, cliente, venda, valor, parceiro, participacao,
  forma_pagamento, observacoes,
  case when current_user_is_admin() or name_matches(colaborador, current_user_person_name()) then colaborador else null end as colaborador,
  case when current_user_is_admin() or name_matches(vendedor2,   current_user_person_name()) then vendedor2   else null end as vendedor2,
  case when current_user_is_admin() or name_matches(vendedor3,   current_user_person_name()) then vendedor3   else null end as vendedor3,
  pago, mes_pagamento, parcela_label, created_at, updated_at,
  case when current_user_is_admin() or name_matches(vendedor_responsavel, current_user_person_name()) then vendedor_responsavel else null end as vendedor_responsavel
from vendas
where current_user_is_admin()
   or name_matches(vendedor2, current_user_person_name())
   or name_matches(vendedor3, current_user_person_name())
   or name_matches(colaborador, current_user_person_name())
   or name_matches(vendedor_responsavel, current_user_person_name())
   or exists (
     -- valor nulo = linha em branco que o app cria pra toda vendedora em
     -- toda venda; não significa que a pessoa participou daquela venda.
     select 1 from vendas_comissoes vc join sellers s on s.key = vc.seller_key
     where vc.venda_id = vendas.id
       and vc.valor is not null
       and name_matches(s.label, current_user_person_name())
   );

revoke all on lancamentos_safe, lancamentos_extra_vendedores_safe, vendas_safe from anon;
grant select on lancamentos_safe, lancamentos_extra_vendedores_safe, vendas_safe to authenticated;

-- Depois de rodar isto, cadastre cada pessoa em app_user_access, ex:
--   insert into app_user_access (auth_user_id, full_access, person_name)
--   select id, true, null from auth.users where email = 'admin@empresa.com.br';
--   insert into app_user_access (auth_user_id, full_access, person_name)
--   select id, false, 'Nome Como Aparece Nos Lançamentos' from auth.users where email = 'vendedor@empresa.com.br';
