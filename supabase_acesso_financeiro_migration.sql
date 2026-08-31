-- ============================================================
-- Migração 21 — terceiro nível de acesso: financeiro
-- ============================================================
-- Aplicada no banco em duas partes:
--   20260831174018  acesso_financeiro
--   20260831174053  lancamentos_safe_financeiro
--
-- Para que serve: existe uma pessoa no financeiro que precisa conferir o
-- VALOR de todas as notas que entraram — sistema, renovações, consultoria,
-- órgãos públicos e cursos — e que não pode ver comissão de ninguém: nem
-- valor de comissão, nem percentual, nem bônus, nem meta, nem salário.
--
-- O corte é feito aqui, no banco, e não na tela. Esconder só na tela seria
-- fingimento: o dado continuaria vindo na resposta da API e bastaria abrir
-- o navegador para lê-lo. Aqui ele simplesmente não sai do banco.
--
-- Regra do projeto que vale de novo: coluna nova em vendas/lancamentos
-- precisa entrar TAMBÉM na view _safe correspondente, senão o sistema
-- grava e nunca lê de volta.

-- ------------------------------------------------------------
-- parte 1 — a marca do nível e quem pode ler as notas
-- ------------------------------------------------------------
alter table app_user_access add column if not exists financeiro boolean not null default false;

create or replace function public.current_user_is_financeiro()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select a.financeiro from app_user_access a
                    where a.auth_user_id = auth.uid()), false);
$$;
revoke all on function public.current_user_is_financeiro() from public, anon;
grant execute on function public.current_user_is_financeiro() to authenticated;

-- Leitura das notas: admin, dono da linha, ou financeiro.
drop policy if exists "select own or admin" on vendas;
create policy "select own or admin" on vendas for select to authenticated
  using (current_user_is_admin() or current_user_is_financeiro()
         or name_matches(vendedor2, current_user_person_name())
         or name_matches(vendedor3, current_user_person_name())
         or name_matches(colaborador, current_user_person_name())
         or name_matches(vendedor_responsavel, current_user_person_name())
         or exists (select 1 from vendas_comissoes vc join sellers s on s.key = vc.seller_key
                     where vc.venda_id = vendas.id and vc.valor is not null
                       and name_matches(s.label, current_user_person_name())));

drop policy if exists "select own or admin" on lancamentos;
create policy "select own or admin" on lancamentos for select to authenticated
  using (current_user_is_admin() or current_user_is_financeiro()
         or name_matches(vendedor, current_user_person_name())
         or name_matches(vendedor2, current_user_person_name())
         or name_matches(vendedor3, current_user_person_name())
         or name_matches(colaborador, current_user_person_name())
         or exists (select 1 from lancamentos_extra_vendedores ev
                     where ev.lancamento_id = lancamentos.id
                       and name_matches(ev.vendedor, current_user_person_name())));

drop policy if exists "select own or admin" on renovacoes;
create policy "select own or admin" on renovacoes for select to authenticated
  using (current_user_is_admin() or current_user_is_financeiro()
         or name_matches(pessoa, current_user_person_name()));

-- ------------------------------------------------------------
-- parte 2 — as views _safe: valor sim, percentual não
-- ------------------------------------------------------------
-- O financeiro passa a enxergar as linhas de todas as abas, com o VALOR do
-- contrato — mas os percentuais de comissão continuam vindo nulos para
-- ele. Percentual x valor é a comissão, então esconder só o valor não
-- adiantaria: o percentual também sai.
--
-- Os NOMES dos vendedores continuam visíveis: saber quem atendeu a conta
-- ajuda o financeiro a resolver a nota, e nome não é remuneração.
create or replace view lancamentos_safe as
 select id, entidade, ano, mes, nome, valor_contrato, tipo, parceiro,
        participacao, forma_pagamento, observacoes,
        case when current_user_is_admin() or current_user_is_financeiro()
                  or name_matches(colaborador, current_user_person_name())
             then colaborador else null::text end as colaborador,
        case when current_user_is_admin() or current_user_is_financeiro()
                  or name_matches(vendedor, current_user_person_name())
             then vendedor else null::text end as vendedor,
        case when current_user_is_admin()
                  or name_matches(vendedor, current_user_person_name())
             then comissao_percent else null::numeric end as comissao_percent,
        case when current_user_is_admin() or current_user_is_financeiro()
                  or name_matches(vendedor2, current_user_person_name())
             then vendedor2 else null::text end as vendedor2,
        case when current_user_is_admin()
                  or name_matches(vendedor2, current_user_person_name())
             then comissao_percent2 else null::numeric end as comissao_percent2,
        case when current_user_is_admin() or current_user_is_financeiro()
                  or name_matches(vendedor3, current_user_person_name())
             then vendedor3 else null::text end as vendedor3,
        case when current_user_is_admin()
                  or name_matches(vendedor3, current_user_person_name())
             then comissao_percent3 else null::numeric end as comissao_percent3,
        pago, mes_pagamento, parcela_label, created_at, updated_at
   from lancamentos
  where current_user_is_admin() or current_user_is_financeiro()
     or name_matches(vendedor, current_user_person_name())
     or name_matches(vendedor2, current_user_person_name())
     or name_matches(vendedor3, current_user_person_name())
     or name_matches(colaborador, current_user_person_name())
     or lancamento_tem_extra_vendedor_meu(id);

revoke all on lancamentos_safe from anon;
grant select on lancamentos_safe to authenticated;

-- vendas_safe: o financeiro vê a nota inteira; a comissão do Sistema mora
-- em vendas_comissoes, tabela à qual ele não tem acesso nenhum.
create or replace view vendas_safe as
 select id, ano, mes, cliente, venda, valor, parceiro, participacao,
        forma_pagamento, observacoes,
        case when current_user_is_admin() or current_user_is_financeiro()
                  or name_matches(colaborador, current_user_person_name())
             then colaborador else null::text end as colaborador,
        case when current_user_is_admin() or current_user_is_financeiro()
                  or name_matches(vendedor2, current_user_person_name())
             then vendedor2 else null::text end as vendedor2,
        case when current_user_is_admin() or current_user_is_financeiro()
                  or name_matches(vendedor3, current_user_person_name())
             then vendedor3 else null::text end as vendedor3,
        pago, mes_pagamento, parcela_label, created_at, updated_at,
        case when current_user_is_admin() or current_user_is_financeiro()
                  or name_matches(vendedor_responsavel, current_user_person_name())
             then vendedor_responsavel else null::text end as vendedor_responsavel,
        renovacao, novo_contrato, upgrade
   from vendas
  where current_user_is_admin() or current_user_is_financeiro()
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
