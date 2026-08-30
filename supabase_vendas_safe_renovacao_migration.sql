-- ============================================================
-- Migração 18: vendas_safe passa a devolver a coluna "renovacao"
-- ============================================================
-- Correção de um descuido da migração 17. A coluna renovacao foi criada na
-- tabela vendas, mas o aplicativo NÃO lê a tabela: ele lê a view
-- vendas_safe, que faz o mascaramento por coluna. Como a view não devolvia
-- o campo, a venda nascia marcada como renovação, o selo aparecia na tela
-- e sumia no primeiro recarregamento — o dado estava certo no banco, só
-- não voltava para a tela.
--
-- Vale como lembrete: toda coluna nova em vendas, lancamentos ou
-- lancamentos_extra_vendedores precisa entrar também na view _safe
-- correspondente, senão ela é gravada e nunca mais lida.
--
-- A coluna entra no FIM da lista porque "create or replace view" não
-- aceita inserir coluna no meio nem renomear as existentes.
-- ============================================================

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
        renovacao
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
