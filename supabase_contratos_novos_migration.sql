-- ============================================================
-- Migração 10: Empresas com contrato assinado (equipe de consultoria)
-- ============================================================
-- A aba "Equipe de consultoria" media a pessoa só por dois números
-- digitados: contratos assinados e reuniões realizadas. O número não diz
-- QUAIS empresas entraram, nem se o negócio valeu a pena.
--
-- Esta tabela guarda, uma linha por empresa nova:
--   quem trouxe, em que mês, o nome da empresa, o CNPJ e se o negócio foi
--   rentável. "rentavel" é de propósito NULO por padrão: a empresa entra
--   assim que o contrato é assinado, e a avaliação de rentabilidade vem
--   depois, quando o gestor tem como julgar.
--
-- O campo "contratos assinados" continua existindo e continua digitado à
-- mão — não é calculado a partir daqui, para não mexer no histórico que
-- já está lançado. O sistema apenas mostra os dois lado a lado quando
-- divergem, como conferência.
-- ============================================================

create table if not exists contratos_consultoria (
  id bigserial primary key,
  ano int not null,
  mes text not null,
  pessoa text not null,
  empresa text not null default '',
  cnpj text not null default '',
  rentavel boolean,               -- true = rentável, false = não rentável, null = ainda não avaliado
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists contratos_consultoria_ano_mes on contratos_consultoria (ano, mes);
create index if not exists contratos_consultoria_pessoa on contratos_consultoria (pessoa);

alter table contratos_consultoria enable row level security;

-- Mesmo corte do resto do sistema: admin vê e edita tudo; conta restrita
-- enxerga só as empresas que ela mesma trouxe, e não edita.
drop policy if exists "select own or admin" on contratos_consultoria;
drop policy if exists "admin insert" on contratos_consultoria;
drop policy if exists "admin update" on contratos_consultoria;
drop policy if exists "admin delete" on contratos_consultoria;
create policy "select own or admin" on contratos_consultoria for select to authenticated
  using (current_user_is_admin() or name_matches(pessoa, current_user_person_name()));
create policy "admin insert" on contratos_consultoria for insert to authenticated
  with check (current_user_is_admin());
create policy "admin update" on contratos_consultoria for update to authenticated
  using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on contratos_consultoria for delete to authenticated
  using (current_user_is_admin());

revoke all on contratos_consultoria from anon;
grant select, insert, update, delete on contratos_consultoria to authenticated;
grant usage, select on sequence contratos_consultoria_id_seq to authenticated;
