-- ============================================================
-- Migração: esconder também os DADOS DOS COLEGAS dentro de um
-- lançamento compartilhado (mascaramento por coluna)
-- ============================================================
-- Pré-requisito: supabase_security_migration.sql e
-- supabase_row_access_migration.sql já rodados.
--
-- PROBLEMA QUE ISTO CORRIGE
-- A migração anterior filtrava LINHAS: a pessoa só via os lançamentos
-- em que o nome dela aparecia. Só que um mesmo lançamento pode ter até
-- 3 vendedores + colaborador na MESMA linha. Então, num contrato
-- dividido, quem participava enxergava o nome e a % de comissão dos
-- colegas daquele contrato — exatamente o que se queria evitar.
--
-- COMO FICA AGORA
-- A leitura das tabelas com dados de várias pessoas passa a ser feita
-- por views "_safe", que:
--   1. filtram as linhas (só o que é da pessoa), e
--   2. zeram, coluna a coluna, o vendedor/percentual que não é dela.
-- Para admin, as views devolvem tudo, sem máscara.
--
-- POR QUE VIEW E NÃO SÓ RLS
-- RLS decide quais LINHAS aparecem, não quais COLUNAS. As views são
-- criadas pelo dono do banco (postgres, que tem bypassrls) e aplicam o
-- filtro por dentro; em paralelo, a leitura das tabelas base é fechada
-- só para admin. Assim o mascaramento não é cosmético: mesmo chamando a
-- API REST na mão, uma conta restrita não alcança a tabela base.
--
-- IMPORTANTE: depois desta migração o app PRECISA ler pelas views
-- (o index.html desta versão já faz isso). Um front antigo, apontando
-- para as tabelas base, mostraria tudo vazio para contas restritas.
-- ============================================================

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
   or lancamento_has_extra_vendedor(id, current_user_person_name());

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
  pago, mes_pagamento, parcela_label, created_at, updated_at
from vendas
where current_user_is_admin()
   or name_matches(vendedor2, current_user_person_name())
   or name_matches(vendedor3, current_user_person_name())
   or name_matches(colaborador, current_user_person_name())
   or exists (
     select 1 from vendas_comissoes vc join sellers s on s.key = vc.seller_key
     where vc.venda_id = vendas.id and name_matches(s.label, current_user_person_name())
   );

grant select on lancamentos_safe, lancamentos_extra_vendedores_safe, vendas_safe to authenticated;

-- Fecha a porta dos fundos: as tabelas base só podem ser lidas por admin.
-- (Admin precisa manter SELECT na base porque UPDATE/DELETE com WHERE
-- exige privilégio de leitura nas colunas do filtro.)
drop policy if exists "select own or admin" on lancamentos;
drop policy if exists "select admin only" on lancamentos;
create policy "select admin only" on lancamentos for select to authenticated
  using (current_user_is_admin());

drop policy if exists "select own or admin" on lancamentos_extra_vendedores;
drop policy if exists "select admin only" on lancamentos_extra_vendedores;
create policy "select admin only" on lancamentos_extra_vendedores for select to authenticated
  using (current_user_is_admin());

drop policy if exists "select own or admin" on vendas;
drop policy if exists "select admin only" on vendas;
create policy "select admin only" on vendas for select to authenticated
  using (current_user_is_admin());

-- vendas_comissoes continua com filtro por linha: cada linha já é de um
-- vendedor só, então a pessoa vê apenas a própria comissão do contrato.
