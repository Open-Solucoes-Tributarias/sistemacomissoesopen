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

-- Segurança: acesso liberado só para usuários autenticados (login com
-- e-mail/senha via Supabase Auth). O sistema é de uso compartilhado pela
-- equipe, sem dono por linha, então qualquer pessoa logada pode ler e
-- escrever em qualquer registro — mas precisa estar logada. Veja o
-- README para instruções de como criar as contas da equipe.
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

create policy "authenticated full access" on sellers for all to authenticated using (true) with check (true);
create policy "authenticated full access" on partners for all to authenticated using (true) with check (true);
create policy "authenticated full access" on venda_products for all to authenticated using (true) with check (true);
create policy "authenticated full access" on entity_vendors for all to authenticated using (true) with check (true);
create policy "authenticated full access" on vendas for all to authenticated using (true) with check (true);
create policy "authenticated full access" on vendas_comissoes for all to authenticated using (true) with check (true);
create policy "authenticated full access" on lancamentos for all to authenticated using (true) with check (true);
create policy "authenticated full access" on lancamentos_extra_vendedores for all to authenticated using (true) with check (true);
create policy "authenticated full access" on bonus for all to authenticated using (true) with check (true);
create policy "authenticated full access" on metas for all to authenticated using (true) with check (true);
create policy "authenticated full access" on closed_months for all to authenticated using (true) with check (true);
create policy "authenticated full access" on extra_years for all to authenticated using (true) with check (true);
