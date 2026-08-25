-- ============================================================
-- Migração: acesso por pessoa (admins x contas restritas)
-- ============================================================
-- Pré-requisito: já ter rodado supabase_security_migration.sql
-- (login obrigatório, políticas "authenticated full access").
--
-- Esta migração troca esse modelo "qualquer autenticado vê e edita
-- tudo" por dois níveis de acesso:
--   • admin (full_access = true): lê e escreve em todos os dados,
--     igual a antes.
--   • conta restrita (full_access = false, com um person_name):
--     só enxerga, em modo somente leitura, os lançamentos onde esse
--     nome aparece como vendedor/colaborador. Nunca edita nada.
--
-- Depois de rodar isto, TODA conta autenticada que ainda não estiver
-- cadastrada em app_user_access fica sem acesso a nenhum dado (a
-- política é "admin OU nome bate" — sem linha em app_user_access,
-- nenhuma das duas é verdadeira). Cadastre cada pessoa antes de
-- avisar a equipe que a mudança está no ar (veja o passo a passo no
-- final deste arquivo).
-- ============================================================

create table if not exists app_user_access (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  full_access boolean not null default false,
  person_name text,
  created_at timestamptz not null default now()
);
alter table app_user_access enable row level security;

drop policy if exists "self read access" on app_user_access;
create policy "self read access" on app_user_access for select to authenticated
  using (auth_user_id = auth.uid());

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

create or replace function public.name_matches(a text, b text)
returns boolean
language sql
immutable
as $$
  select a is not null and b is not null and trim(a) <> '' and lower(trim(a)) = lower(trim(b));
$$;

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

-- Tabelas de catálogo/referência: leitura livre pra qualquer autenticado,
-- escrita só pra admin.
do $$
declare t text;
begin
  foreach t in array array['sellers','partners','venda_products','entity_vendors','closed_months','extra_years'] loop
    execute format('drop policy if exists "authenticated full access" on %I', t);
    execute format('drop policy if exists "catalog read" on %I', t);
    execute format('drop policy if exists "catalog admin insert" on %I', t);
    execute format('drop policy if exists "catalog admin update" on %I', t);
    execute format('drop policy if exists "catalog admin delete" on %I', t);
    execute format('create policy "catalog read" on %I for select to authenticated using (true)', t);
    execute format('create policy "catalog admin insert" on %I for insert to authenticated with check (current_user_is_admin())', t);
    execute format('create policy "catalog admin update" on %I for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin())', t);
    execute format('create policy "catalog admin delete" on %I for delete to authenticated using (current_user_is_admin())', t);
  end loop;
end $$;

-- bonus
drop policy if exists "authenticated full access" on bonus;
drop policy if exists "select own or admin" on bonus;
create policy "select own or admin" on bonus for select to authenticated
  using (current_user_is_admin() or name_matches(vendedor, current_user_person_name()));
create policy "admin insert" on bonus for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on bonus for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on bonus for delete to authenticated using (current_user_is_admin());

-- metas
drop policy if exists "authenticated full access" on metas;
drop policy if exists "select own or admin" on metas;
create policy "select own or admin" on metas for select to authenticated
  using (current_user_is_admin() or name_matches(vendedor, current_user_person_name()));
create policy "admin insert" on metas for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on metas for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on metas for delete to authenticated using (current_user_is_admin());

-- lancamentos (consultoria / publicos / cursos)
drop policy if exists "authenticated full access" on lancamentos;
drop policy if exists "select own or admin" on lancamentos;
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
drop policy if exists "authenticated full access" on lancamentos_extra_vendedores;
drop policy if exists "select own or admin" on lancamentos_extra_vendedores;
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
drop policy if exists "authenticated full access" on vendas;
drop policy if exists "select own or admin" on vendas;
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
drop policy if exists "authenticated full access" on vendas_comissoes;
drop policy if exists "select own or admin" on vendas_comissoes;
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
-- Passo final (faça isso ANTES de avisar a equipe): cadastre cada
-- pessoa em app_user_access. Sem essa linha, a conta fica sem ver
-- nenhum dado, mesmo estando logada.
--
-- Admin (acesso total):
--   insert into app_user_access (auth_user_id, full_access, person_name)
--   select id, true, null from auth.users where email = 'admin@empresa.com.br';
--
-- Conta restrita (só o que tiver o nome dela como vendedor/colaborador):
--   insert into app_user_access (auth_user_id, full_access, person_name)
--   select id, false, 'Nome Como Aparece Nos Lançamentos' from auth.users where email = 'vendedor@empresa.com.br';
-- ============================================================
