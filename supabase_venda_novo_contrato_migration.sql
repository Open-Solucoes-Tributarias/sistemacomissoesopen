-- ============================================================
-- Migração 19: tag de "contrato novo"
-- ============================================================
-- O oposto da tag de renovação. Uma venda pode ser uma coisa OU outra —
-- a tela cuida de não deixar as duas ligadas — e pode não ser nenhuma: o
-- contrato mensal que se repete todo mês não é conta nova nem renovação.
--
-- Diferente da renovação, contrato novo NÃO muda cálculo nenhum. É venda
-- nova: conta no ranking e nas comissões como sempre contou. A marca serve
-- para ver e filtrar quantas contas novas entraram no mês, que é a
-- pergunta que a diretoria faz.
--
-- Como na migração 18: a coluna precisa entrar na view vendas_safe, senão
-- o app grava e nunca mais lê.
-- ============================================================

alter table vendas add column if not exists novo_contrato boolean not null default false;

create or replace view vendas_safe as
 select id, ano, mes, cliente, venda, valor, parceiro, participacao,
        forma_pagamento, observacoes,
        case when current_user_is_admin() or name_matches(colaborador, current_user_person_name())
             then colaborador else null::text end as colaborador,
        case when current_user_is_admin() or name_matches(vendedor2, current_user_person_name())
             then vendedor2 else null::text end as vendedor2,
        case when current_user_is_admin() or name_matches(vendedor3, current_user_person_name())
             then vendedor3 else null::text end as vendedor3,
        pago, mes_pagamento, parcela_label, created_at, updated_at,
        case when current_user_is_admin() or name_matches(vendedor_responsavel, current_user_person_name())
             then vendedor_responsavel else null::text end as vendedor_responsavel,
        renovacao, novo_contrato
   from vendas
  where current_user_is_admin()
     or name_matches(vendedor2, current_user_person_name())
     or name_matches(vendedor3, current_user_person_name())
     or name_matches(colaborador, current_user_person_name())
     or name_matches(vendedor_responsavel, current_user_person_name())
     or exists (select 1 from vendas_comissoes vc
                  join sellers s on s.key = vc.seller_key
                 where vc.venda_id = vendas.id and vc.valor is not null
                   and name_matches(s.label, current_user_person_name()));

revoke all on vendas_safe from anon;
grant select on vendas_safe to authenticated;
