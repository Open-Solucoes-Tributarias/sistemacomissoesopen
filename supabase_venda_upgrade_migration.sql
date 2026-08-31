-- ============================================================
-- Migração 20: tag de upgrade
-- ============================================================
-- Terceira natureza de venda: cliente que já era da casa e subiu de plano.
-- Não é conta nova, nem renovação de contrato igual.
--
-- Como contrato novo, upgrade É receita nova e CONTA no ranking e nas
-- comissões. Só renovação fica de fora do desempenho — é o único caso em
-- que o dinheiro entra sem ninguém ter conquistado nada de novo.
--
-- As três marcas se excluem: a tela liga uma e desliga as outras. Ficar
-- sem marca continua valendo (o contrato mensal que só se repete).
--
-- Como nas migrações 17/18: a coluna precisa entrar na view vendas_safe,
-- senão o app grava e nunca mais lê.
-- ============================================================

alter table vendas add column if not exists upgrade boolean not null default false;

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
        renovacao, novo_contrato, upgrade
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
