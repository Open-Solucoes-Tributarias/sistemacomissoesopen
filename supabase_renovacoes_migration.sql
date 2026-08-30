-- ============================================================
-- Migração 14: renovações do sistema
-- ============================================================
-- Renovar contrato não é vender: não tem prospecção, não tem proposta, não
-- entra no ranking de vendas nem nos totais de faturamento. É um processo
-- próprio, tocado por uma dupla (hoje Uilma e Luciana), e o que a diretoria
-- precisa saber é simples: quais empresas estão renovando, quem cuidou de
-- cada uma e quais não renovaram.
--
-- Daí uma tabela só com o essencial — mês, responsável e nome da empresa —
-- mais o desfecho:
--   renovado = true   → renovou
--   renovado = false  → não renovou
--   renovado = null   → em aberto, ainda sendo tratada
--
-- Nulo é o estado inicial de propósito: a empresa entra na lista quando a
-- renovação começa a ser tratada, e o desfecho vem depois. A taxa de
-- renovação só conta as decididas, para as em aberto não puxarem o número
-- para baixo.
--
-- Quem cuida das renovações fica em entity_vendors com
-- entidade='renovacoes' — a mesma tabela das outras listas de pessoas.
-- ============================================================

create table if not exists renovacoes (
  id bigserial primary key,
  ano int not null,
  mes text not null,
  pessoa text not null,
  empresa text not null default '',
  renovado boolean,              -- true = renovou, false = não renovou, null = em aberto
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists renovacoes_ano_mes on renovacoes (ano, mes);
create index if not exists renovacoes_pessoa on renovacoes (pessoa);

alter table renovacoes enable row level security;

-- Mesmo corte do resto do sistema: admin vê e edita tudo; conta restrita
-- enxerga só as renovações que estão no nome dela, e não edita.
drop policy if exists "select own or admin" on renovacoes;
drop policy if exists "admin insert" on renovacoes;
drop policy if exists "admin update" on renovacoes;
drop policy if exists "admin delete" on renovacoes;
create policy "select own or admin" on renovacoes for select to authenticated
  using (current_user_is_admin() or name_matches(pessoa, current_user_person_name()));
create policy "admin insert" on renovacoes for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on renovacoes for update to authenticated
  using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on renovacoes for delete to authenticated using (current_user_is_admin());

revoke all on renovacoes from anon;
grant select, insert, update, delete on renovacoes to authenticated;
grant usage, select on sequence renovacoes_id_seq to authenticated;

alter table entity_vendors drop constraint if exists entity_vendors_entidade_check;
alter table entity_vendors add constraint entity_vendors_entidade_check
  check (entidade in ('consultoria','publicos','cursos','painel','painel_contratos','fechamento_fora','renovacoes'));

insert into entity_vendors (entidade, vendor_name)
values ('renovacoes','Uilma'), ('renovacoes','Luciana')
on conflict (entidade, vendor_name) do nothing;
