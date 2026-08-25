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
  entidade text not null check (entidade in ('consultoria','publicos','cursos')),
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

-- Bônus e metas batidas
create table bonus (
  id bigserial primary key,
  ano int not null,
  mes text not null,
  vendedor text default '',
  descricao text default '',
  valor numeric,
  created_at timestamptz not null default now()
);

-- Metas mensais por vendedor(a)
create table metas (
  id bigserial primary key,
  ano int not null,
  mes text not null,
  vendedor text not null,
  valor_meta numeric not null,
  unique(ano, mes, vendedor)
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
as $$
  select a is not null and b is not null and trim(a) <> '' and lower(trim(a)) = lower(trim(b));
$$;

-- Ajudam a evitar recursão de RLS entre lancamentos <-> lancamentos_extra_vendedores.
create or replace function public.lancamento_matches_person(lanc_id bigint, pname text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from lancamentos l
    where l.id = lanc_id
      and (
        name_matches(l.vendedor, pname)
        or name_matches(l.vendedor2, pname)
        or name_matches(l.vendedor3, pname)
        or name_matches(l.colaborador, pname)
      )
  );
$$;

create or replace function public.lancamento_has_extra_vendedor(lanc_id bigint, pname text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from lancamentos_extra_vendedores ev
    where ev.lancamento_id = lanc_id
      and name_matches(ev.vendedor, pname)
  );
$$;

revoke all on function public.current_user_is_admin() from public;
revoke all on function public.current_user_person_name() from public;
revoke all on function public.name_matches(text,text) from public;
revoke all on function public.lancamento_matches_person(bigint,text) from public;
revoke all on function public.lancamento_has_extra_vendedor(bigint,text) from public;
grant execute on function public.current_user_is_admin() to authenticated;
grant execute on function public.current_user_person_name() to authenticated;
grant execute on function public.name_matches(text,text) to authenticated;
grant execute on function public.lancamento_matches_person(bigint,text) to authenticated;
grant execute on function public.lancamento_has_extra_vendedor(bigint,text) to authenticated;

alter table sellers enable row level security;
alter table partners enable row level security;
alter table venda_products enable row level security;
alter table entity_vendors enable row level security;
alter table vendas enable row level security;
alter table vendas_comissoes enable row level security;
alter table lancamentos enable row level security;
alter table lancamentos_extra_vendedores enable row level security;
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

-- metas
create policy "select own or admin" on metas for select to authenticated
  using (current_user_is_admin() or name_matches(vendedor, current_user_person_name()));
create policy "admin insert" on metas for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on metas for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on metas for delete to authenticated using (current_user_is_admin());

-- lancamentos (consultoria / publicos / cursos)
create policy "select own or admin" on lancamentos for select to authenticated
  using (
    current_user_is_admin()
    or name_matches(vendedor, current_user_person_name())
    or name_matches(vendedor2, current_user_person_name())
    or name_matches(vendedor3, current_user_person_name())
    or name_matches(colaborador, current_user_person_name())
    or lancamento_has_extra_vendedor(id, current_user_person_name())
  );
create policy "admin insert" on lancamentos for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on lancamentos for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on lancamentos for delete to authenticated using (current_user_is_admin());

-- lancamentos_extra_vendedores
create policy "select own or admin" on lancamentos_extra_vendedores for select to authenticated
  using (
    current_user_is_admin()
    or name_matches(vendedor, current_user_person_name())
    or lancamento_matches_person(lancamento_id, current_user_person_name())
  );
create policy "admin insert" on lancamentos_extra_vendedores for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on lancamentos_extra_vendedores for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on lancamentos_extra_vendedores for delete to authenticated using (current_user_is_admin());

-- vendas (aba Sistema)
create policy "select own or admin" on vendas for select to authenticated
  using (
    current_user_is_admin()
    or name_matches(vendedor2, current_user_person_name())
    or name_matches(vendedor3, current_user_person_name())
    or name_matches(colaborador, current_user_person_name())
    or exists (
      select 1 from vendas_comissoes vc join sellers s on s.key = vc.seller_key
      where vc.venda_id = vendas.id and name_matches(s.label, current_user_person_name())
    )
  );
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

-- Depois de rodar isto, cadastre cada pessoa em app_user_access, ex:
--   insert into app_user_access (auth_user_id, full_access, person_name)
--   select id, true, null from auth.users where email = 'admin@empresa.com.br';
--   insert into app_user_access (auth_user_id, full_access, person_name)
--   select id, false, 'Nome Como Aparece Nos Lançamentos' from auth.users where email = 'vendedor@empresa.com.br';
